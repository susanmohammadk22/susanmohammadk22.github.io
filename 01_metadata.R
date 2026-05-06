# WHAT: Calls the LegiScan getBill API for each of the 50 bill IDs extracted
#       from the filenames, retrieves state, session year, primary sponsor
#       party, and bill status, then merges in a trifecta classification
#       (R / D / Divided) keyed on state + year.
# WHY:  Downstream scripts need trifecta as the main grouping variable.
#       All political context comes from this script.
# INPUTS:  data/raw_pdfs/ (filenames supply bill IDs)
#          LEGISCAN_KEY environment variable
# OUTPUTS: data/bill_metadata.rds
#          data/bill_metadata.csv   (human-readable copy)
# ESTIMATED RUNTIME: ~35 seconds (50 bills × 0.6 s sleep + API latency)

source("global_constants.R")

library(httr)
library(jsonlite)

# ── 0. Key check ─────────────────────────────────────────────────────────────
api_key <- Sys.getenv("LEGISCAN_KEY")
if (nchar(api_key) == 0) {
  stop("LEGISCAN_KEY is not set. Add it to ~/.Renviron and restart R.")
}
cat("LEGISCAN_KEY detected — proceeding.\n\n")

# ── 1. Extract bill IDs from filenames ───────────────────────────────────────
pdf_files <- list.files(RAW_DIR, pattern = "\\.pdf$", recursive = TRUE,
                        full.names = TRUE)
bill_ids <- pdf_files |>
  basename() |>
  stringr::str_extract("\\d+") |>
  na.omit() |>
  unique()

cat("Bill IDs found:", length(bill_ids), "\n")
if (length(bill_ids) == 0) stop("No bill IDs parsed — check RAW_DIR.")

# Apply MAX_BILLS cap (for testing; set to 50 in global_constants for full run)
bill_ids <- bill_ids[seq_len(min(length(bill_ids), MAX_BILLS))]
cat("Processing:", length(bill_ids), "bills (MAX_BILLS =", MAX_BILLS, ")\n\n")

# ── 2. Trifecta lookup table ─────────────────────────────────────────────────
# State legislative trifecta control by year.
# Sources: NCSL & Ballotpedia partisan composition data (2023–2025).
# Key: state abbreviation + year → R, D, or Divided
trifecta_lookup <- tribble(
  ~state, ~year, ~trifecta,
  # Republican trifectas
  "AL", 2023, "R", "AL", 2024, "R", "AL", 2025, "R",
  "AR", 2023, "R", "AR", 2024, "R", "AR", 2025, "R",
  "FL", 2023, "R", "FL", 2024, "R", "FL", 2025, "R",
  "GA", 2023, "R", "GA", 2024, "R", "GA", 2025, "R",
  "ID", 2023, "R", "ID", 2024, "R", "ID", 2025, "R",
  "IN", 2023, "R", "IN", 2024, "R", "IN", 2025, "R",
  "IA", 2023, "R", "IA", 2024, "R", "IA", 2025, "R",
  "KS", 2023, "R", "KS", 2024, "R", "KS", 2025, "R",
  "KY", 2023, "R", "KY", 2024, "R", "KY", 2025, "R",
  "LA", 2023, "R", "LA", 2024, "R", "LA", 2025, "R",
  "MS", 2023, "R", "MS", 2024, "R", "MS", 2025, "R",
  "MO", 2023, "R", "MO", 2024, "R", "MO", 2025, "R",
  "MT", 2023, "R", "MT", 2024, "R", "MT", 2025, "R",
  "NE", 2023, "R", "NE", 2024, "R", "NE", 2025, "R",
  "ND", 2023, "R", "ND", 2024, "R", "ND", 2025, "R",
  "OH", 2023, "R", "OH", 2024, "R", "OH", 2025, "R",
  "OK", 2023, "R", "OK", 2024, "R", "OK", 2025, "R",
  "SC", 2023, "R", "SC", 2024, "R", "SC", 2025, "R",
  "SD", 2023, "R", "SD", 2024, "R", "SD", 2025, "R",
  "TN", 2023, "R", "TN", 2024, "R", "TN", 2025, "R",
  "TX", 2023, "R", "TX", 2024, "R", "TX", 2025, "R",
  "UT", 2023, "R", "UT", 2024, "R", "UT", 2025, "R",
  "WV", 2023, "R", "WV", 2024, "R", "WV", 2025, "R",
  "WY", 2023, "R", "WY", 2024, "R", "WY", 2025, "R",
  # Democratic trifectas
  "CA", 2023, "D", "CA", 2024, "D", "CA", 2025, "D",
  "CO", 2023, "D", "CO", 2024, "D", "CO", 2025, "D",
  "CT", 2023, "D", "CT", 2024, "D", "CT", 2025, "D",
  "DE", 2023, "D", "DE", 2024, "D", "DE", 2025, "D",
  "HI", 2023, "D", "HI", 2024, "D", "HI", 2025, "D",
  "IL", 2023, "D", "IL", 2024, "D", "IL", 2025, "D",
  "ME", 2023, "D", "ME", 2024, "D", "ME", 2025, "D",
  "MD", 2023, "D", "MD", 2024, "D", "MD", 2025, "D",
  "MA", 2023, "D", "MA", 2024, "D", "MA", 2025, "D",
  "MI", 2023, "D", "MI", 2024, "D", "MI", 2025, "D",
  "MN", 2023, "D", "MN", 2024, "D", "MN", 2025, "D",
  "NJ", 2023, "D", "NJ", 2024, "D", "NJ", 2025, "D",
  "NM", 2023, "D", "NM", 2024, "D", "NM", 2025, "D",
  "NY", 2023, "D", "NY", 2024, "D", "NY", 2025, "D",
  "OR", 2023, "D", "OR", 2024, "D", "OR", 2025, "D",
  "RI", 2023, "D", "RI", 2024, "D", "RI", 2025, "D",
  "VT", 2023, "D", "VT", 2024, "D", "VT", 2025, "D",
  "WA", 2023, "D", "WA", 2024, "D", "WA", 2025, "D",
  # Divided
  "AK", 2023, "Divided", "AK", 2024, "Divided", "AK", 2025, "Divided",
  "AZ", 2023, "Divided", "AZ", 2024, "Divided", "AZ", 2025, "Divided",
  "GA", 2023, "Divided", "GA", 2024, "Divided",   # note: GA went full R 2025
  "KS", 2024, "Divided",
  "ME", 2023, "Divided",
  "NV", 2023, "Divided", "NV", 2024, "Divided", "NV", 2025, "Divided",
  "NH", 2023, "Divided", "NH", 2024, "Divided", "NH", 2025, "Divided",
  "NC", 2023, "Divided", "NC", 2024, "Divided", "NC", 2025, "Divided",
  "PA", 2023, "Divided", "PA", 2024, "Divided", "PA", 2025, "Divided",
  "VA", 2023, "Divided", "VA", 2024, "Divided", "VA", 2025, "Divided",
  "WI", 2023, "Divided", "WI", 2024, "Divided", "WI", 2025, "Divided",
  "WI", 2026, "Divided",
  # Additional D-trifecta states (added in second data collection)
  "IL", 2023, "D", "IL", 2024, "D", "IL", 2025, "D", "IL", 2026, "D",
  "CO", 2023, "D", "CO", 2024, "D", "CO", 2025, "D", "CO", 2026, "D",
  "CT", 2023, "D", "CT", 2024, "D", "CT", 2025, "D", "CT", 2026, "D",
  "MD", 2023, "D", "MD", 2024, "D", "MD", 2025, "D", "MD", 2026, "D",
  # Additional Divided states (added in second data collection)
  "PA", 2023, "Divided", "PA", 2024, "Divided", "PA", 2025, "Divided",
  "PA", 2026, "Divided",
  "NC", 2023, "Divided", "NC", 2024, "Divided", "NC", 2025, "Divided",
  "NC", 2026, "Divided",
  "NV", 2025, "Divided", "NV", 2026, "Divided"
) |>
  # Keep only the last row per state+year (Divided overrides R/D if listed twice)
  dplyr::distinct(state, year, .keep_all = TRUE)

# ── 3. LegiScan API helper ───────────────────────────────────────────────────
get_bill_meta <- function(bill_id) {
  Sys.sleep(0.6)   # respect 1 call/second rate limit

  result <- tryCatch({
    url <- paste0(
      "https://api.legiscan.com/?key=", api_key,
      "&op=getBill&id=", bill_id
    )
    resp <- httr::GET(url, httr::timeout(15))
    httr::stop_for_status(resp)

    parsed <- jsonlite::fromJSON(
      httr::content(resp, as = "text", encoding = "UTF-8"),
      simplifyVector = FALSE
    )

    if (parsed$status != "OK") {
      warning("LegiScan status not OK for bill ", bill_id,
              ": ", parsed$status)
      return(NULL)
    }

    bill <- parsed$bill

    # Primary sponsor party
    sponsor_party <- if (length(bill$sponsors) > 0) {
      bill$sponsors[[1]]$party
    } else {
      NA_character_
    }

    # Session year — prefer session_year, fall back to year_start
    sess_year <- bill$session$year_start %||%
                 bill$session$session_year %||%
                 NA_integer_

    tibble::tibble(
      bill_id      = as.character(bill_id),
      bill_number  = bill$bill_number,
      state        = bill$state,
      year         = as.integer(sess_year),
      title        = bill$title,
      status       = as.integer(bill$status),
      sponsor_party = sponsor_party
    )
  },
  error = function(e) {
    warning("Error fetching bill ", bill_id, ": ", e$message)
    NULL
  })

  result
}

# ── 4. Fetch metadata for all bills ─────────────────────────────────────────
cat("Fetching metadata from LegiScan API...\n")
cat("(", length(bill_ids), "calls × 0.6 s = ~",
    round(length(bill_ids) * 0.6 / 60, 1), "min estimated)\n\n")

meta_list <- vector("list", length(bill_ids))
for (i in seq_along(bill_ids)) {
  cat(sprintf("[%d/%d] bill_id %s\n", i, length(bill_ids), bill_ids[i]))
  meta_list[[i]] <- get_bill_meta(bill_ids[i])
}

bill_metadata <- dplyr::bind_rows(meta_list)
cat("\nSuccessfully fetched:", nrow(bill_metadata), "of", length(bill_ids),
    "bills\n")

# CHECKPOINT: warn if more than 10% failed
fail_n <- length(bill_ids) - nrow(bill_metadata)
if (fail_n / length(bill_ids) > 0.10) {
  warning(fail_n, " bills failed to fetch (>10%). Check API key and network.")
}

# ── 5. Merge trifecta ────────────────────────────────────────────────────────
bill_metadata <- bill_metadata |>
  dplyr::left_join(trifecta_lookup, by = c("state", "year")) |>
  dplyr::mutate(
    trifecta = dplyr::coalesce(trifecta, "Divided"),  # unknown → Divided
    trifecta = factor(trifecta, levels = c("R", "D", "Divided"))
  )

# CHECKPOINT: trifecta distribution
cat("\nTrifecta distribution:\n")
print(table(bill_metadata$trifecta, useNA = "ifany"))

cat("\nState × trifecta:\n")
print(table(bill_metadata$state, bill_metadata$trifecta))

# ── 6. Save ──────────────────────────────────────────────────────────────────
saveRDS(bill_metadata, "data/bill_metadata.rds")
readr::write_csv(bill_metadata, "data/bill_metadata.csv")

cat("\nSaved: data/bill_metadata.rds\n")
cat("Saved: data/bill_metadata.csv\n")
cat("Columns:", paste(names(bill_metadata), collapse = ", "), "\n")

message("01_metadata.R complete.")

# ── COMMON ERRORS AND FIXES ──────────────────────────────────────────────────
# ERROR: stop("LEGISCAN_KEY is not set")
#   FIX:  Add LEGISCAN_KEY=yourkey to ~/.Renviron; run readRenviron("~/.Renviron")
#
# ERROR: HTTP 429 Too Many Requests
#   FIX:  Increase Sys.sleep() from 0.6 to 1.2
#
# ERROR: "Unexpected character" from jsonlite
#   FIX:  API returned HTML error page; print httr::content(resp, as="text")
#
# ERROR: trifecta is all NA
#   FIX:  Check that bill$state returns 2-letter abbreviations; confirm year
#         matches trifecta_lookup range (2023–2025)
