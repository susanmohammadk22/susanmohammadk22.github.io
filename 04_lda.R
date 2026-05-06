# WHAT: Fits a Latent Dirichlet Allocation (LDA) topic model with K=4 topics
#       on the bill corpus using Gibbs sampling. Prints the top 15 words per
#       topic for manual labelling, then computes the average topic proportion
#       within each trifecta group and visualises the result.
# WHY:  LDA surfaces latent policy themes across the bills independent of
#       political grouping — it answers "what kinds of voting bills exist?"
#       and "do red/blue/purple states concentrate on different themes?"
# INPUTS:  data/bill_dfm.rds
#          data/bill_metadata.rds
# OUTPUTS: data/lda_model.rds
#          data/bill_topics.rds        (per-bill topic proportions + trifecta)
#          figures/topic_top_words.png
#          figures/topic_distribution_by_trifecta.png
# ESTIMATED RUNTIME: 2–5 minutes (Gibbs, 800 iterations, 33 docs × 2342 terms)

source("global_constants.R")
library(quanteda)
library(topicmodels)

# ── 1. Load and convert DFM → DTM ────────────────────────────────────────────
dfm  <- readRDS("data/bill_dfm.rds")
meta <- readRDS("data/bill_metadata.rds") |>
  dplyr::mutate(bill_id = as.character(bill_id))

cat("DFM:", ndoc(dfm), "docs,", nfeat(dfm), "features\n")

# topicmodels requires a DocumentTermMatrix; convert via quanteda
dtm <- quanteda::convert(dfm, to = "topicmodels")

# Remove empty documents (rows that sum to zero after conversion)
empty_rows <- slam::row_sums(dtm) == 0
if (any(empty_rows)) {
  warning(sum(empty_rows), " empty document(s) removed before LDA.")
  dtm <- dtm[!empty_rows, ]
}
cat("DTM ready:", nrow(dtm), "documents,", ncol(dtm), "terms\n")

# ── 2. Fit LDA ───────────────────────────────────────────────────────────────
K    <- 4
ITER <- 800

set.seed(SEED)
cat("\nFitting LDA (K =", K, ", iter =", ITER, ")... this may take a few minutes.\n")

lda_model <- topicmodels::LDA(
  dtm,
  k       = K,
  method  = "Gibbs",
  control = list(
    seed  = SEED,
    iter  = ITER,
    thin  = 1,
    burnin = 200,
    alpha  = 50 / K,   # standard symmetric Dirichlet prior
    delta  = 0.1
  )
)

saveRDS(lda_model, "data/lda_model.rds")
cat("Saved: data/lda_model.rds\n")

# ── 3. Print top 15 words per topic ──────────────────────────────────────────
cat("\n── Top 15 words per topic (for manual labelling) ──────────────────\n")
top_terms <- topicmodels::terms(lda_model, 15)
print(top_terms)
cat("\nAssign human labels above before interpreting topic distribution plot.\n")

# ── 4. Per-document topic proportions ────────────────────────────────────────
# gamma matrix: rows = documents, cols = topics (proportions sum to 1 per doc)
gamma_df <- tidyr::as_tibble(lda_model@gamma, .name_repair = "minimal") |>
  stats::setNames(paste0("Topic_", seq_len(K))) |>
  dplyr::mutate(doc_id = rownames(dtm)) |>
  dplyr::left_join(
    meta |> dplyr::select(bill_id, state, year, trifecta, sponsor_party),
    by = c("doc_id" = "bill_id")
  )

saveRDS(gamma_df, "data/bill_topics.rds")
cat("Saved: data/bill_topics.rds\n")

# CHECKPOINT: mean proportion per topic overall
cat("\nMean topic proportions across all documents:\n")
gamma_df |>
  dplyr::summarise(dplyr::across(dplyr::starts_with("Topic_"), mean)) |>
  print()

# ── 5. Figure A: top words per topic ─────────────────────────────────────────
# Build tidy data frame of top N words × their beta (word-topic probability)
beta_df <- tidyr::as_tibble(exp(lda_model@beta), .name_repair = "minimal") |>
  stats::setNames(lda_model@terms) |>
  dplyr::mutate(topic = paste0("Topic ", seq_len(K))) |>
  tidyr::pivot_longer(-topic, names_to = "term", values_to = "beta") |>
  dplyr::group_by(topic) |>
  dplyr::slice_max(beta, n = 12) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    term_ordered = tidytext::reorder_within(term, beta, topic)
  )

p_words <- ggplot2::ggplot(
    beta_df,
    ggplot2::aes(x = term_ordered, y = beta, fill = topic)
  ) +
  ggplot2::geom_col(show.legend = FALSE, width = 0.75) +
  tidytext::scale_x_reordered() +
  ggplot2::coord_flip() +
  ggplot2::facet_wrap(~ topic, scales = "free_y", ncol = 2) +
  ggplot2::scale_fill_manual(
    values = c(
      "Topic 1" = "#2C4770",
      "Topic 2" = "#4A6FA5",
      "Topic 3" = "#8DADD4",
      "Topic 4" = "#C5D5E8"
    )
  ) +
  ggplot2::labs(
    title    = "Key Words Within Each Policy Theme",
    subtitle = paste0("Topic model with ", K, " groups — ",
                      ITER, " sampling iterations"),
    x        = NULL,
    y        = "Word importance within topic",
    caption  = "Stems shown. Word importance = probability of word given topic."
  )

ggplot2::ggsave(
  "figures/topic_top_words.png",
  plot   = p_words,
  width  = 10,
  height = 7,
  dpi    = 180,
  bg     = "white"
)
cat("Saved: figures/topic_top_words.png\n")

# ── 6. Figure B: topic emphasis by trifecta ───────────────────────────────────
topic_by_trifecta <- gamma_df |>
  dplyr::filter(!is.na(trifecta)) |>
  dplyr::group_by(trifecta) |>
  dplyr::summarise(
    dplyr::across(dplyr::starts_with("Topic_"), mean),
    n_bills = dplyr::n(),
    .groups = "drop"
  ) |>
  tidyr::pivot_longer(
    dplyr::starts_with("Topic_"),
    names_to  = "topic",
    values_to = "mean_proportion"
  ) |>
  dplyr::mutate(
    topic = stringr::str_replace(topic, "Topic_", "Topic "),
    trifecta_label = dplyr::recode(as.character(trifecta),
      R       = "Unified Republican",
      D       = "Unified Democratic",
      Divided = "Divided Government"
    ),
    trifecta_label = factor(trifecta_label,
      levels = c("Unified Republican", "Unified Democratic",
                 "Divided Government"))
  )

# CHECKPOINT
cat("\nAverage topic proportion by trifecta:\n")
print(topic_by_trifecta |>
  dplyr::select(trifecta_label, topic, mean_proportion, n_bills))

p_dist <- ggplot2::ggplot(
    topic_by_trifecta,
    ggplot2::aes(x = topic, y = mean_proportion,
                 fill = trifecta_label, group = trifecta_label)
  ) +
  ggplot2::geom_col(position = "dodge", width = 0.7) +
  ggplot2::scale_fill_manual(
    values = c(
      "Unified Republican" = TRIFECTA_COLORS["R"],
      "Unified Democratic" = TRIFECTA_COLORS["D"],
      "Divided Government" = TRIFECTA_COLORS["Divided"]
    ),
    name = "State control"
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::percent_format(accuracy = 1),
    expand = ggplot2::expansion(mult = c(0, 0.05))
  ) +
  ggplot2::labs(
    title    = "Policy Theme Emphasis by State Political Control",
    subtitle = "Average share of each topic within trifecta group",
    x        = NULL,
    y        = "Average topic proportion",
    caption  = paste0("Based on ", ndoc(dfm), " bills across ",
                      length(unique(gamma_df$state[!is.na(gamma_df$state)])),
                      " states. Divided group = ", sum(gamma_df$trifecta == "Divided", na.rm = TRUE),
                      " bills — interpret with caution.")
  ) +
  ggplot2::theme(legend.position = "bottom")

ggplot2::ggsave(
  "figures/topic_distribution_by_trifecta.png",
  plot   = p_dist,
  width  = 9,
  height = 6,
  dpi    = 180,
  bg     = "white"
)
cat("Saved: figures/topic_distribution_by_trifecta.png\n")

message("04_lda.R complete.")

# ── COMMON ERRORS AND FIXES ──────────────────────────────────────────────────
# ERROR: "there is no package called 'topicmodels'"
#   FIX:  install.packages("topicmodels")
#         On Mac, may also need: brew install gsl
#
# ERROR: "there is no package called 'slam'"
#   FIX:  install.packages("slam")  — installed as topicmodels dependency
#
# ERROR: "there is no package called 'tidytext'"
#   FIX:  install.packages("tidytext")
#
# ERROR: "there is no package called 'scales'"
#   FIX:  install.packages("scales")
#
# ERROR: LDA produces identical topics across runs
#   FIX:  set.seed() is called before LDA() — this is expected behaviour.
#         Different seeds will give different (equally valid) solutions.
#
# NOTE:  The Divided group has only 2 documents. Topic proportions for that
#        group are unreliable and should be treated as illustrative only.
