# WHAT: Sends each bill's text to Claude (claude-opus-4-6) via the Anthropic
#       API and classifies it as RESTRICTIVE, EXPANSIVE, or NEUTRAL.
#       Includes a rationale field for every bill. After classification,
#       computes the cross-tabulation of label × trifecta (headline finding).
# WHY:  Automated classification at scale with a consistent rubric enables the
#       project's core comparison: do red vs. blue vs. purple states pass
#       different types of voting legislation?
# INPUTS:  data/bill_text.rds      (cleaned bill text)
#          data/bill_metadata.rds  (trifecta lookup)
#          ANTHROPIC_API_KEY environment variable
# OUTPUTS: data/llm_labels.rds
#          results/llm_labels.csv
#          results/labels_by_trifecta.csv
#          figures/labels_by_trifecta.png
# ESTIMATED RUNTIME: 5–15 minutes (50 API calls with retry pauses)

source("global_constants.R")
library(httr2)
library(jsonlite)

# ── 0. API key check ──────────────────────────────────────────────────────────
api_key <- Sys.getenv("ANTHROPIC_API_KEY")
if (nchar(api_key) == 0) {
  stop("ANTHROPIC_API_KEY is not set. Add it to ~/.Renviron and restart R.")
}
cat("ANTHROPIC_API_KEY detected — proceeding.\n\n")

# ── 1. Load data ──────────────────────────────────────────────────────────────
bill_text <- readRDS("data/bill_text.rds")
meta      <- readRDS("data/bill_metadata.rds") |>
  dplyr::mutate(bill_id = as.character(bill_id))

cat("Bills to classify:", nrow(bill_text), "\n\n")

# ── 2. Classification prompt ──────────────────────────────────────────────────
SYSTEM_PROMPT <- "You are an expert in U.S. election law and voting rights policy.
You will be given the text of a state legislative bill related to voting or elections.

Classify the bill using EXACTLY ONE of these three labels:
- RESTRICTIVE: The bill adds new requirements, restrictions, or barriers that
  could reduce voter participation or access (e.g., stricter ID requirements,
  reduced polling hours, shortened registration windows, increased signature
  requirements).
- EXPANSIVE: The bill expands, protects, or facilitates voter access or
  participation (e.g., automatic voter registration, extended early voting,
  vote-by-mail expansion, restoring voting rights).
- NEUTRAL: The bill makes procedural or administrative changes without a clear
  directional impact on voter access (e.g., updating forms, renaming offices,
  clarifying existing definitions, adjusting filing deadlines for officials).

Respond with a JSON object containing exactly two fields:
  {
    \"label\": \"RESTRICTIVE\" | \"EXPANSIVE\" | \"NEUTRAL\",
    \"rationale\": \"One to two sentences explaining the key provision(s) that
                   determined this classification.\"
  }

Do not include any text outside the JSON object."

classify_bill <- function(bill_id, bill_text_str, title = "") {
  Sys.sleep(3)   # base rate limiting — Anthropic tier 1 is ~20 RPM

  # Truncate very long bills to ~8000 words to stay within context/cost limits
  words      <- strsplit(bill_text_str, " ")[[1]]
  text_trunc <- paste(words[seq_len(min(length(words), 8000))], collapse = " ")

  user_msg <- paste0("Bill title: ", title, "\n\nBill text:\n", text_trunc)

  # Inner call with retry on 429
  do_call <- function() {
    httr2::request("https://api.anthropic.com/v1/messages") |>
      httr2::req_headers(
        "x-api-key"         = api_key,
        "anthropic-version" = "2023-06-01",
        "content-type"      = "application/json"
      ) |>
      httr2::req_body_json(list(
        model      = "claude-opus-4-6",
        max_tokens = 300,
        system     = SYSTEM_PROMPT,
        messages   = list(list(role = "user", content = user_msg))
      )) |>
      httr2::req_timeout(60) |>
      httr2::req_retry(
        max_tries   = 5,
        is_transient = function(resp) httr2::resp_status(resp) == 429,
        backoff      = function(i) min(30 * 2^(i - 1), 120)  # 30, 60, 120s
      ) |>
      httr2::req_perform()
  }

  result <- tryCatch({
    req <- do_call()

    resp_body <- httr2::resp_body_json(req)
    raw_text  <- resp_body$content[[1]]$text

    # Strip markdown code fences if present (model sometimes wraps in ```json)
    clean_json <- stringr::str_remove_all(raw_text, "```(?:json)?\\s*|```\\s*")
    clean_json <- trimws(clean_json)

    # Parse JSON from response
    parsed <- jsonlite::fromJSON(clean_json)

    label <- toupper(trimws(parsed$label))
    if (!label %in% c("RESTRICTIVE", "EXPANSIVE", "NEUTRAL")) {
      warning("Unexpected label '", label, "' for bill ", bill_id,
              " — setting to NA")
      label <- NA_character_
    }

    tibble::tibble(
      bill_id        = as.character(bill_id),
      llm_label      = label,
      llm_rationale  = as.character(parsed$rationale)
    )
  },
  error = function(e) {
    cat("  [ERROR]", e$message, "\n")
    tibble::tibble(
      bill_id       = as.character(bill_id),
      llm_label     = NA_character_,
      llm_rationale = paste("ERROR:", e$message)
    )
  })

  result
}

# ── 3. Classify all bills (skip already-classified ones) ─────────────────────
existing_labels <- if (file.exists("data/llm_labels.rds")) {
  readRDS("data/llm_labels.rds") |>
    dplyr::mutate(bill_id = as.character(bill_id)) |>
    dplyr::filter(!is.na(llm_label))
} else {
  NULL
}

already_done <- if (!is.null(existing_labels)) existing_labels$bill_id else character(0)
cat("Already classified:", length(already_done), "bills — skipping these.\n")

# Join text to metadata to get title for the prompt
classify_input <- dplyr::left_join(
  bill_text |> dplyr::mutate(bill_id = as.character(bill_id)),
  meta       |> dplyr::select(bill_id, title),
  by = "bill_id"
) |>
  dplyr::filter(!bill_id %in% already_done)

n_bills <- nrow(classify_input)
label_list <- vector("list", n_bills)

cat("Classifying", n_bills, "bills via Claude claude-opus-4-6...\n\n")

for (i in seq_len(n_bills)) {
  cat(sprintf("[%d/%d] bill_id %s ... ",
              i, n_bills, classify_input$bill_id[i]))

  label_list[[i]] <- classify_bill(
    bill_id       = classify_input$bill_id[i],
    bill_text_str = classify_input$clean_text[i],
    title         = classify_input$title[i]
  )

  cat(label_list[[i]]$llm_label, "\n")
}

new_labels_df <- dplyr::bind_rows(label_list)

# Merge with previously classified bills
labels_df <- dplyr::bind_rows(existing_labels, new_labels_df) |>
  dplyr::distinct(bill_id, .keep_all = TRUE)

# CHECKPOINT: how many failed?
n_fail <- sum(is.na(labels_df$llm_label))
cat("\nClassification complete.\n")
cat("Successful:", n_bills - n_fail, "/", n_bills, "\n")
if (n_fail > 0) warning(n_fail, " bills returned NA label.")

# ── 4. Merge with metadata ────────────────────────────────────────────────────
llm_labels <- labels_df |>
  dplyr::select(bill_id, llm_label, llm_rationale) |>   # drop any stale metadata cols
  dplyr::left_join(
    meta |> dplyr::select(bill_id, state, year, trifecta,
                           sponsor_party, bill_number, title),
    by = "bill_id"
  ) |>
  dplyr::mutate(
    llm_label = factor(llm_label,
                       levels = c("RESTRICTIVE", "EXPANSIVE", "NEUTRAL")),
    trifecta  = factor(as.character(trifecta), levels = c("R", "D", "Divided"))
  )

saveRDS(llm_labels, "data/llm_labels.rds")
readr::write_csv(llm_labels, "results/llm_labels.csv")
cat("Saved: data/llm_labels.rds\n")
cat("Saved: results/llm_labels.csv\n")

# ── 5. Cross-tabulation: label × trifecta (headline finding) ─────────────────
cat("\n── Label distribution by trifecta ──────────────────────────────────\n")

labels_by_trifecta <- llm_labels |>
  dplyr::filter(!is.na(llm_label), !is.na(trifecta)) |>
  dplyr::count(trifecta, llm_label) |>
  dplyr::group_by(trifecta) |>
  dplyr::mutate(
    total = sum(n),
    pct   = round(100 * n / total, 1),
    trifecta_label = dplyr::recode(as.character(trifecta),
      R       = "Unified Republican",
      D       = "Unified Democratic",
      Divided = "Divided Government"
    )
  ) |>
  dplyr::ungroup()

print(labels_by_trifecta |>
  dplyr::select(trifecta_label, llm_label, n, total, pct) |>
  dplyr::arrange(trifecta_label, llm_label))

readr::write_csv(labels_by_trifecta, "results/labels_by_trifecta.csv")
cat("Saved: results/labels_by_trifecta.csv\n")

# ── 6. Figure: label split by trifecta ───────────────────────────────────────
label_colors <- c(
  "RESTRICTIVE" = "#B0281A",   # muted red
  "EXPANSIVE"   = ACCENT_COLOR, # navy
  "NEUTRAL"     = "#999999"    # gray
)

plot_df <- labels_by_trifecta |>
  dplyr::mutate(
    trifecta_label = factor(trifecta_label,
      levels = c("Unified Republican", "Unified Democratic",
                 "Divided Government")),
    llm_label = factor(llm_label,
      levels = c("RESTRICTIVE", "EXPANSIVE", "NEUTRAL"))
  )

p <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = trifecta_label, y = pct,
                 fill = llm_label, label = paste0(pct, "%"))
  ) +
  ggplot2::geom_col(position = "stack", width = 0.6) +
  ggplot2::geom_text(
    position = ggplot2::position_stack(vjust = 0.5),
    size     = 3.5,
    color    = "white",
    fontface = "bold"
  ) +
  ggplot2::scale_fill_manual(
    values = label_colors,
    name   = "Bill type"
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::percent_format(scale = 1),
    expand = ggplot2::expansion(mult = c(0, 0.02))
  ) +
  ggplot2::labs(
    title    = "Voting Bill Types by State Political Control",
    subtitle = paste0("AI-assisted classification of ", n_bills,
                      " state voting bills"),
    x        = NULL,
    y        = "Share of bills (%)",
    caption  = paste0(
      "Each bill classified as Restrictive (adds barriers), ",
      "Expansive (expands access), or Neutral (procedural).\n",
      "Divided Government group (n=2) — interpret with caution."
    )
  ) +
  ggplot2::theme(
    legend.position = "right",
    panel.grid.major.y = ggplot2::element_line(
      color = GRAY_LIGHT, linewidth = 0.3
    )
  )

ggplot2::ggsave(
  "figures/labels_by_trifecta.png",
  plot   = p,
  width  = 9,
  height = 6,
  dpi    = 180,
  bg     = "white"
)
cat("Saved: figures/labels_by_trifecta.png\n")

message("05_llm_classification.R complete.")

# ── COMMON ERRORS AND FIXES ──────────────────────────────────────────────────
# ERROR: stop("ANTHROPIC_API_KEY is not set")
#   FIX:  Add ANTHROPIC_API_KEY=sk-ant-... to ~/.Renviron; readRenviron("~/.Renviron")
#
# ERROR: HTTP 401 Unauthorized
#   FIX:  Key is wrong or expired. Check at console.anthropic.com
#
# ERROR: HTTP 429 Too Many Requests
#   FIX:  Increase Sys.sleep() from 0.5 to 2; you've hit the rate limit.
#
# ERROR: "unexpected label" warnings
#   FIX:  The model returned a non-standard label. The tryCatch sets it to NA.
#         Increase max_tokens or tighten the system prompt.
#
# ERROR: jsonlite parse failure
#   FIX:  Model returned text outside the JSON. Print raw_text to diagnose.
#         Add: tryCatch(jsonlite::fromJSON(raw_text), error = function(e) ...)
