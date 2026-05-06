# WHAT: Computes TF-IDF scores to find the terms most characteristic of each
#       trifecta group (R / D / Divided). The DFM is first collapsed by trifecta
#       using dfm_group() so each group becomes one pseudo-document, then
#       dfm_tfidf() is applied. This surfaces terms that are both frequent
#       within a group and rare across the other groups.
# WHY:  TF-IDF distinctiveness reveals the vocabulary that separates
#       Republican-controlled states from Democratic-controlled states in their
#       voting legislation — the central research question — and matches the
#       method described in the methods section.
# INPUTS:  data/bill_dfm.rds  (document-feature matrix from script 02)
# OUTPUTS: results/tfidf_by_trifecta.csv
#          figures/tfidf_top_terms_by_trifecta.png
# ESTIMATED RUNTIME: < 1 minute

source("global_constants.R")
library(quanteda)

# ── 1. Load data ──────────────────────────────────────────────────────────────
dfm <- readRDS("data/bill_dfm.rds")
cat("DFM loaded:", ndoc(dfm), "docs,", nfeat(dfm), "features\n")
cat("Trifecta counts:\n")
print(table(docvars(dfm, "trifecta")))

# ── 2. Collapse DFM by trifecta, then compute TF-IDF ─────────────────────────
# dfm_group() sums token counts across all bills in the same trifecta group,
# producing a 3-row DFM (one pseudo-document per group). dfm_tfidf() is then
# applied to this grouped matrix so the IDF component rewards terms that appear
# in only one or two of the three groups.
#
# TF-IDF settings (quanteda defaults, chosen intentionally):
#   scheme_tf = "count"   — raw term frequency within each group's pseudo-doc
#   scheme_df = "inverse" — IDF = log(N / df), where N = 3 groups
#
# With N = 3 groups, IDF values are:
#   term in 1 group  → log(3/1) ≈ 1.099  (highest reward — exclusive terms)
#   term in 2 groups → log(3/2) ≈ 0.405  (moderate reward)
#   term in 3 groups → log(3/3) = 0      (no reward — universal boilerplate)

dfm_grouped <- dfm |>
  quanteda::dfm_group(groups = docvars(dfm, "trifecta"))

cat("\nGrouped DFM dimensions:", ndoc(dfm_grouped), "groups ×",
    nfeat(dfm_grouped), "features\n")

# Apply TF-IDF to the grouped matrix
dfm_tfidf <- quanteda::dfm_tfidf(
  dfm_grouped,
  scheme_tf = "count",    # raw count within pseudo-document
  scheme_df = "inverse",  # standard IDF: log(N/df)
  base      = 10          # log base 10 — conventional for TF-IDF in IR
)

# ── 3. Extract top terms per group ────────────────────────────────────────────
n_terms <- 20   # terms per group to retain

tfidf_list <- lapply(rownames(dfm_tfidf), function(grp) {
  scores <- as.numeric(dfm_tfidf[grp, ])
  names(scores) <- colnames(dfm_tfidf)

  top_idx <- order(scores, decreasing = TRUE)[seq_len(n_terms)]

  tibble::tibble(
    trifecta = grp,
    term     = names(scores)[top_idx],
    tf_idf   = scores[top_idx]
  )
})

tfidf_df <- dplyr::bind_rows(tfidf_list) |>
  dplyr::mutate(
    trifecta = factor(trifecta, levels = c("R", "D", "Divided")),
    trifecta_label = dplyr::recode(trifecta,
      R       = "Unified Republican",
      D       = "Unified Democratic",
      Divided = "Divided Government"
    )
  )

# CHECKPOINT: top 5 per group
cat("\nTF-IDF results — top 5 per group:\n")
tfidf_df |>
  dplyr::group_by(trifecta) |>
  dplyr::slice_head(n = 5) |>
  dplyr::select(trifecta, term, tf_idf) |>
  print()

# ── 4. Save CSV ───────────────────────────────────────────────────────────────
readr::write_csv(tfidf_df, "results/tfidf_by_trifecta.csv")
cat("\nSaved: results/tfidf_by_trifecta.csv\n")

# ── 5. Plot ───────────────────────────────────────────────────────────────────
# Top 15 terms per group, horizontal bars, faceted by trifecta group

# Helpers (tidytext-style within-group reordering — defined before use)
reorder_within <- function(x, by, within, ...) {
  new_x <- paste(x, within, sep = "___")
  stats::reorder(new_x, by, ...)
}
scale_x_reordered <- function(..., sep = "___") {
  reg <- paste0(sep, ".+$")
  ggplot2::scale_x_discrete(labels = function(x) gsub(reg, "", x), ...)
}

plot_df <- tfidf_df |>
  dplyr::group_by(trifecta_label) |>
  dplyr::slice_head(n = 15) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    term_ordered = reorder_within(term, tf_idf, trifecta_label)
  )

p <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = term_ordered, y = tf_idf, fill = trifecta_label)
  ) +
  ggplot2::geom_col(width = 0.75, show.legend = FALSE) +
  scale_x_reordered() +
  ggplot2::coord_flip() +
  ggplot2::facet_wrap(~ trifecta_label, scales = "free_y", ncol = 3) +
  ggplot2::scale_fill_manual(
    values = c(
      "Unified Republican" = TRIFECTA_COLORS["R"],
      "Unified Democratic" = TRIFECTA_COLORS["D"],
      "Divided Government" = TRIFECTA_COLORS["Divided"]
    )
  ) +
  ggplot2::labs(
    title    = "Most Distinctive Words by State Political Control",
    subtitle = "TF-IDF scores on a trifecta-grouped corpus — terms exclusive to one group score highest",
    x        = NULL,
    y        = "TF-IDF score",
    caption  = "Stems shown. TF-IDF rewards terms frequent within a group and rare across other groups."
  )

ggplot2::ggsave(
  "figures/tfidf_top_terms_by_trifecta.png",
  plot   = p,
  width  = 12,
  height = 6,
  dpi    = 180,
  bg     = "white"
)
cat("Saved: figures/tfidf_top_terms_by_trifecta.png\n")

message("03_tfidf.R complete.")

# ── COMMON ERRORS AND FIXES ──────────────────────────────────────────────────
# ERROR: "there is no package called 'quanteda'"
#   FIX:  install.packages("quanteda")
#
# ERROR: dfm_tfidf() returns all-zero scores
#   FIX:  Confirm dfm_group() produced > 1 group. If all bills share the same
#         trifecta label, IDF will be 0 for every term (log(1/1) = 0).
#         Check: rownames(dfm_grouped)
#
# ERROR: "reorder_within not found"
#   FIX:  The helper is defined inline above. Ensure it runs before ggplot().
#
# NOTE:  With N = 3 pseudo-documents, terms appearing in all three groups
#        always receive a TF-IDF score of 0 regardless of frequency. This is
#        intentional — it filters universal boilerplate automatically.
#
# NOTE:  The Divided group (14 bills in this corpus) has fewer bills than R or D.
#        Its TF-IDF scores are based on the combined word counts of those 14
#        bills treated as a single pseudo-document. Results are interpretable
#        but should be read alongside the n_bills caveat.
