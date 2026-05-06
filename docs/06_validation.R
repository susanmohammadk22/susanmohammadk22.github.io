# WHAT: Exports a stratified random sample of 10 bills for human coding,
#       then computes Cohen's Kappa for LLM-vs-human agreement once the
#       single coder returns their ratings.
# WHY:  Validates the LLM classifier against human judgement. Required for
#       grading and for assessing whether the headline finding is reliable.
#       Note: One human coder was used (not two). Human-vs-Human inter-rater
#       reliability is therefore not computed; only LLM-vs-Human kappa is
#       reported.
# INPUTS:  data/llm_labels.rds
#          validation/human_codes.csv  (coder1_label filled in by human coder)
# OUTPUTS: validation/llm_validation_sample.csv   (10 bills + human labels)
#          results/validation_kappa.csv            (LLM-vs-Human kappa)
#          figures/validation_agreement.png
# ESTIMATED RUNTIME: < 1 minute (excluding time for human coding)

source("global_constants.R")
library(irr)      # Cohen's Kappa

# ── 1. Load LLM labels ────────────────────────────────────────────────────────
llm <- readRDS("data/llm_labels.rds") |>
  dplyr::filter(!is.na(llm_label))

cat("Bills with LLM labels:", nrow(llm), "\n")
cat("Trifecta breakdown:\n")
print(table(llm$trifecta, useNA = "ifany"))

if (nrow(llm) < 3) {
  stop("Too few classified bills for validation. Run 05_llm_classification.R first.")
}

# ── 2. Stratified sample of 10 bills ─────────────────────────────────────────
# Check if sample already exported; if so, use the existing sample to ensure
# consistency with already-completed human coding.
sample_file <- "validation/llm_validation_sample.csv"

if (file.exists(sample_file)) {
  cat("\nExisting validation sample found — loading to preserve human codes.\n")
  validation_export <- readr::read_csv(sample_file, show_col_types = FALSE)
} else {
  set.seed(SEED)

  group_sizes <- llm |>
    dplyr::count(trifecta) |>
    dplyr::mutate(n_draw = pmax(1L, round(10 * n / nrow(llm))))

  sample_ids <- llm |>
    dplyr::left_join(group_sizes |> dplyr::select(trifecta, n_draw),
                     by = "trifecta") |>
    dplyr::group_by(trifecta) |>
    dplyr::group_modify(~ dplyr::slice_sample(.x, n = .x$n_draw[1])) |>
    dplyr::ungroup() |>
    dplyr::slice_sample(n = 10)

  validation_export <- sample_ids |>
    dplyr::left_join(
      readRDS("data/bill_text.rds") |>
        dplyr::mutate(bill_id = as.character(bill_id)) |>
        dplyr::select(bill_id, clean_text),
      by = "bill_id"
    ) |>
    dplyr::mutate(
      text_preview = vapply(clean_text, function(t) {
        words <- strsplit(t, " ")[[1]]
        paste(words[seq_len(min(length(words), 1500))], collapse = " ")
      }, character(1)),
      coder1_label = NA_character_
    ) |>
    dplyr::select(bill_id, bill_number, state, year, trifecta, title,
                  text_preview, llm_label, coder1_label)

  readr::write_csv(validation_export, sample_file)
  cat("\nSaved new validation sample:", sample_file, "\n")
}

cat("Sample size:", nrow(validation_export), "bills\n")
cat("Trifecta distribution in sample:\n")
print(table(validation_export$trifecta))

# ── 3. Load and merge human codes ─────────────────────────────────────────────
human_file <- "validation/human_codes.csv"

if (!file.exists(human_file)) {
  cat("\nHuman codes file not found:", human_file, "\n")
  cat("Create this file with columns: bill_id, coder1_label\n")
  cat("Use labels: RESTRICTIVE, EXPANSIVE, or NEUTRAL\n")
  message("06_validation.R complete (kappa pending human codes).")
  quit(save = "no")
}

human_codes <- readr::read_csv(human_file, show_col_types = FALSE) |>
  dplyr::mutate(bill_id = as.character(bill_id))

has_codes <- !all(is.na(human_codes$coder1_label))

if (!has_codes) {
  cat("\nHuman codes not yet entered in", human_file, "— skipping kappa computation.\n")
  message("06_validation.R complete (kappa pending human codes).")
  quit(save = "no")
}

# Merge human codes onto validation sample
coded <- validation_export |>
  dplyr::mutate(bill_id = as.character(bill_id)) |>
  dplyr::left_join(human_codes, by = "bill_id", suffix = c("_old", "")) |>
  dplyr::mutate(
    coder1_label = dplyr::coalesce(coder1_label, coder1_label_old)
  ) |>
  dplyr::select(-dplyr::any_of("coder1_label_old"))

# Save updated sample with labels filled in
readr::write_csv(coded, sample_file)
cat("\nUpdated validation sample with human codes saved:", sample_file, "\n")

# ── 4. Compute LLM-vs-Human kappa ─────────────────────────────────────────────
complete_rows <- coded |>
  dplyr::filter(!is.na(coder1_label), !is.na(llm_label))

cat("\nBills with both LLM and human labels:", nrow(complete_rows), "\n")

if (nrow(complete_rows) < 3) {
  stop("Too few coded rows for kappa. Ensure human_codes.csv is complete.")
}

# Print raw comparison table
cat("\nLLM vs. Human label comparison:\n")
complete_rows |>
  dplyr::select(bill_number, state, trifecta, llm_label, coder1_label) |>
  dplyr::mutate(agrees = llm_label == coder1_label) |>
  print(n = Inf)

# Confusion matrix
cat("\nConfusion matrix (rows = LLM, cols = Human):\n")
print(table(LLM = complete_rows$llm_label,
            Human = complete_rows$coder1_label))

# Kappa
ratings_lh <- complete_rows |>
  dplyr::select(llm_label, coder1_label) |>
  as.matrix()

kappa_lh <- irr::kappa2(ratings_lh, weight = "unweighted")

kappa_interp <- dplyr::case_when(
  kappa_lh$value >= 0.81 ~ "Almost perfect",
  kappa_lh$value >= 0.61 ~ "Substantial (target met)",
  kappa_lh$value >= 0.41 ~ "Moderate — acceptable for exploratory use",
  kappa_lh$value >= 0.21 ~ "Fair",
  TRUE                   ~ "Slight or worse — revisit script 05 prompt"
)

cat("\nLLM-vs-Human Agreement (Cohen's Kappa):\n")
cat("  n bills:          ", nrow(complete_rows), "\n")
cat("  Raw agreement:    ", round(mean(complete_rows$llm_label == complete_rows$coder1_label), 3), "\n")
cat("  Cohen's Kappa:    ", round(kappa_lh$value, 3), "\n")
cat("  Interpretation:   ", kappa_interp, "\n")

if (kappa_lh$value < 0.41) {
  warning("LLM-vs-human kappa < 0.41. Consider revising the classification ",
          "prompt in 05_llm_classification.R before reporting results.")
}

# ── 5. Save kappa results ─────────────────────────────────────────────────────
n_agree <- sum(complete_rows$llm_label == complete_rows$coder1_label)

kappa_results <- tibble::tibble(
  comparison     = "LLM vs Human Coder",
  n_bills        = nrow(complete_rows),
  n_agree        = n_agree,
  raw_agreement  = round(n_agree / nrow(complete_rows), 3),
  cohens_kappa   = round(kappa_lh$value, 3),
  interpretation = kappa_interp,
  target_met     = kappa_lh$value >= 0.61
)

readr::write_csv(kappa_results, "results/validation_kappa.csv")
cat("\nSaved: results/validation_kappa.csv\n")

# Disagreements detail
disagreements <- complete_rows |>
  dplyr::filter(llm_label != coder1_label) |>
  dplyr::select(bill_id, bill_number, state, trifecta, title,
                llm_label, coder1_label)

if (nrow(disagreements) > 0) {
  cat("\nDisagreements (", nrow(disagreements), "bill(s)):\n", sep = "")
  print(disagreements)
} else {
  cat("\nNo disagreements — perfect agreement.\n")
}

# ── 6. Figure: agreement bar chart ───────────────────────────────────────────
bar_color <- if (kappa_lh$value >= 0.61) ACCENT_COLOR else "#999999"

plot_df <- tibble::tibble(
  comparison = paste0("LLM vs Human Coder\n(n = ", nrow(complete_rows), " bills)"),
  kappa      = round(kappa_lh$value, 3),
  bar_color  = bar_color
)

p <- ggplot2::ggplot(plot_df,
    ggplot2::aes(x = comparison, y = kappa, fill = bar_color)) +
  ggplot2::geom_col(width = 0.4, show.legend = FALSE) +
  ggplot2::geom_hline(yintercept = 0.61, linetype = "dashed",
                      color = GRAY_MID, linewidth = 0.6) +
  ggplot2::annotate("text", x = 0.55, y = 0.63,
                    label = "Target: κ = 0.61 (substantial)",
                    hjust = 0, color = GRAY_MID, size = 3.5) +
  ggplot2::annotate("text", x = 1, y = kappa_lh$value + 0.03,
                    label = paste0("κ = ", round(kappa_lh$value, 3)),
                    hjust = 0.5, color = "white", size = 5, fontface = "bold") +
  ggplot2::scale_fill_identity() +
  ggplot2::scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
  ggplot2::labs(
    title    = "Human Spot-Check: LLM vs. Human Coder Agreement",
    subtitle = paste0(n_agree, " of ", nrow(complete_rows),
                      " bills classified identically — ",
                      round(mean(complete_rows$llm_label == complete_rows$coder1_label) * 100),
                      "% raw agreement"),
    x        = NULL,
    y        = "Cohen's Kappa (0–1)",
    caption  = paste0("Single coder design. Target κ ≥ 0.61 for substantial agreement.\n",
                      "Disagreement: ", paste(disagreements$bill_number, collapse = ", "),
                      " (", paste(disagreements$llm_label, "→", disagreements$coder1_label), ")")
  ) +
  bills_theme

ggplot2::ggsave(
  "figures/validation_agreement.png",
  plot   = p,
  width  = 7,
  height = 5,
  dpi    = 180,
  bg     = "white"
)
cat("Saved: figures/validation_agreement.png\n")

message("06_validation.R complete.")

# ── COMMON ERRORS AND FIXES ──────────────────────────────────────────────────
# ERROR: "there is no package called 'irr'"
#   FIX:  install.packages("irr")
#
# ERROR: "Too few classified bills for validation"
#   FIX:  Run 05_llm_classification.R successfully before this script.
#
# ERROR: kappa is NA or NaN
#   FIX:  Check that labels are spelled identically in human_codes.csv
#         (e.g., "RESTRICTIVE" not "Restrictive"). Labels are case-sensitive.
#
# NOTE:  Single-coder design. Human-vs-Human inter-rater reliability is not
#        computed because only one coder completed the validation. LLM-vs-Human
#        kappa is the sole validity metric. This is a limitation to acknowledge
#        in the methods section.
#
# NOTE:  If LLM-vs-human kappa < 0.41, revisit the system prompt in
#        05_llm_classification.R — add examples or tighten definitions.
