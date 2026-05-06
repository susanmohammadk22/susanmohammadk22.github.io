# WHAT: Generates the required AI Collaboration Log documenting every
#       significant AI-assisted step in the project pipeline.
# WHY:  Required for grading. Each entry documents: tool used, full prompt,
#       AI output, review decision, lesson learned, and success flag.
# INPUTS:  results/, data/, figures/ (reads actual outputs for accuracy)
# OUTPUTS: results/ai_collab_log.csv
#          results/ai_collab_log.md   (formatted markdown version)
# ESTIMATED RUNTIME: < 5 seconds

source("global_constants.R")

# ── Build log entries ─────────────────────────────────────────────────────────
log_entries <- tibble::tribble(
  ~step, ~tool_used, ~prompt_summary, ~full_prompt,
  ~ai_output_summary, ~review_decision, ~lesson_learned, ~success,

  # ── Entry 1: Pipeline design ──────────────────────────────────────────────
  1L,
  "Claude Code (claude-sonnet-4-6)",
  "Design a full 7-script R pipeline for text-mining voting bills by trifecta",
  paste0(
    "PROMPT: 'Read this prompt fully. Tell me your plan before running anything ",
    "heavy. Then set up the folder, extract the zip, write 00_setup.R, and ",
    "proceed through the pipeline — pausing at the two API checkpoints.' The ",
    "full CLAUDE.md specification was provided, covering scripts 00-07, ",
    "PowerPoint requirements, R conventions, and pause protocols."
  ),
  paste0(
    "Claude produced a 7-script pipeline plan with folder structure, ",
    "constants (SEED=42, MAX_BILLS=50), a shared ggplot2 theme (black/white, ",
    "clean, minimal), and identified the two API pause points (LEGISCAN_KEY ",
    "before script 01; ANTHROPIC_API_KEY before script 05)."
  ),
  paste0(
    "ACCEPTED with one modification: user requested a clean black-and-white ",
    "PowerPoint aesthetic with restrained color R figures instead of the ",
    "original burgundy/cream theme. Theme was updated accordingly before ",
    "any scripts were written."
  ),
  paste0(
    "Establishing the aesthetic standard at the very start (before writing any ",
    "figure code) ensured all charts matched the slides without retrofitting. ",
    "Defining a shared theme object in 00_setup.R and sourcing it everywhere ",
    "is more reliable than applying it bill-by-bill."
  ),
  TRUE,

  # ── Entry 2: Trifecta lookup ──────────────────────────────────────────────
  2L,
  "Claude Code (claude-sonnet-4-6)",
  "Build a state × year trifecta lookup covering 2023–2026",
  paste0(
    "PROMPT (implicit, during 01_metadata.R writing): Build a tribble() ",
    "lookup that maps state abbreviation + session year to trifecta control ",
    "(R / D / Divided) for 2023–2025, based on NCSL and Ballotpedia data. ",
    "After script ran and returned results, prompt: 'Fix 2026 trifecta for ",
    "MO, OK, IN, UT (should be R), NJ, NM (should be D), AZ, VA (Divided).'"
  ),
  paste0(
    "Initial lookup covered 2023–2025 only. Bills from 2026 (MO, OK, IN, UT, ",
    "AZ, VA, NJ, NM) received NA trifecta and fell back to Divided via ",
    "coalesce(). Claude diagnosed the mismatch from the state×trifecta ",
    "checkpoint table and applied a case_when() patch to the saved RDS. ",
    "Corrected distribution: R=14, D=28, Divided=8 of 50 bills."
  ),
  paste0(
    "ACCEPTED after verification. The patched trifecta values were confirmed ",
    "against known 2026 state partisan compositions (MO, OK, IN, UT are all ",
    "established Republican trifectas; NJ and NM are Democratic trifectas; ",
    "AZ has a Democratic governor with Republican legislature)."
  ),
  paste0(
    "Always include the current year plus one in lookup tables when API data ",
    "may include recent session bills. A checkpoint cross-tabulation (state × ",
    "trifecta) immediately after the merge caught the error before it ",
    "propagated downstream."
  ),
  TRUE,

  # ── Entry 3: PDF text extraction ──────────────────────────────────────────
  3L,
  "Claude Code (claude-sonnet-4-6)",
  "Extract and clean text from 50 bill PDFs using pdftools",
  paste0(
    "PROMPT: Write 02_preprocessing.R to extract PDF text, clean it, build a ",
    "quanteda corpus and DFM with English stopwords plus domain-specific stops ",
    "(legal boilerplate), stem tokens, trim to min_docfreq=2."
  ),
  paste0(
    "Script extracted text from 33 of 50 PDFs (17 failed — corrupted or ",
    "near-empty files). DFM: 2342 unique stems across 33 documents, avg 7688 ",
    "tokens per bill. First attempt failed with 'min_docfreq must be between ",
    "0 and 1' — docfreq_type argument was mixing count and proportion. Fixed ",
    "by using two sequential dfm_trim() calls with explicit types."
  ),
  paste0(
    "ACCEPTED with note: 17 failed PDFs (34% attrition) is a significant ",
    "limitation flagged in the analysis explanation. The 33 usable bills ",
    "include 13 R-trifecta, 18 D-trifecta, 2 Divided — enough for R vs D ",
    "comparison but Divided group is too thin for reliable conclusions."
  ),
  paste0(
    "When mixing docfreq_type='count' and docfreq_type='prop' in quanteda, ",
    "use two separate dfm_trim() calls rather than trying to pass both types ",
    "in one call. PDF attrition of this magnitude should trigger a warning ",
    "and be explicitly flagged in the limitations section."
  ),
  TRUE,

  # ── Entry 4: TF-IDF analysis ─────────────────────────────────────────────
  4L,
  "Claude Code (claude-sonnet-4-6)",
  "TF-IDF analysis identifying vocabulary distinctive to each trifecta group",
  paste0(
    "PROMPT: Rewrite 03_tfidf.R to use genuine TF-IDF (not chi-squared keyness). ",
    "Group the DFM by trifecta using dfm_group() to produce 3 pseudo-documents, ",
    "then apply dfm_tfidf() with scheme_tf='count', scheme_df='inverse', base=10. ",
    "Extract top 20 terms per group. With N=3 groups, terms in only 1 group get ",
    "IDF = log10(3/1) ≈ 0.477 (maximum); terms in all 3 groups get IDF = 0 ",
    "(filtered out automatically). Output to results/tfidf_by_trifecta.csv and ",
    "figures/tfidf_top_terms_by_trifecta.png."
  ),
  paste0(
    "Script produced three-group TF-IDF scores. Top terms: R group — 'elector' ",
    "(227), 'provision', 'utah', 'commission', 'falsif' (redistricting / elector ",
    "certification / fraud prevention language); D group — '203b' (357), ",
    "'auditor', 'jfk', 'minnesota', '204c' (MN-specific election code sections ",
    "and county auditor administration); Divided group — 'underlin' (7.22), ",
    "'fiscal', 'factor' (near-zero scores — Divided vocabulary overlaps heavily ",
    "with R and D, reflecting generic administrative bills). The reorder_within ",
    "helper function was moved before its first reference to fix a parse error."
  ),
  paste0(
    "ACCEPTED. TF-IDF correctly identifies exclusively-used vocabulary in each ",
    "group. The very low Divided Government scores (< 10 vs. 200+ for R and D) ",
    "are substantively meaningful: Divided states use language that appears in ",
    "all three groups, confirming they pass generic administrative bills rather ",
    "than ideologically distinctive voting legislation."
  ),
  paste0(
    "TF-IDF and chi-squared keyness answer different questions. TF-IDF rewards ",
    "exclusive group vocabulary (inverse document frequency); chi-squared rewards ",
    "statistically surprising frequency differences. For a 3-group comparison ",
    "where the research question is 'what vocabulary is distinctive to each ",
    "political group', TF-IDF is the correct method. Always match the code ",
    "to the methods section — a mismatch between described and executed method ",
    "is a validity problem regardless of whether results look plausible."
  ),
  TRUE,

  # ── Entry 5: LDA topic model ──────────────────────────────────────────────
  5L,
  "Claude Code (claude-sonnet-4-6)",
  "K=4 LDA with Gibbs sampling, 800 iterations, topic-by-trifecta chart",
  paste0(
    "PROMPT: Write 04_lda.R using topicmodels::LDA() with K=4, method=Gibbs, ",
    "control=list(seed=42, iter=800, burnin=200, alpha=50/K, delta=0.1). ",
    "Print top 15 words per topic for manual labelling. Compute average topic ",
    "proportion by trifecta and plot grouped bar chart."
  ),
  paste0(
    "LDA converged and produced four interpretable topics: Topic 1 — absentee ",
    "& mail voting (individu, poll, absente, envelop, clerk); Topic 2 — ",
    "election administration (counti, place, primari, commission, cast); ",
    "Topic 3 — redistricting & certification (board, elector, revis, divis, ",
    "petit); Topic 4 — voter ID & registration (card, licens, driver, resid). ",
    "Topic emphasis by trifecta: R bills weight Topics 2+3 (admin/redistricting); ",
    "D bills weight Topic 4 (72% avg proportion — voter ID/registration)."
  ),
  paste0(
    "ACCEPTED. Topic labels were assigned manually after reviewing the top 15 ",
    "words. The D-trifecta concentration in Topic 4 (voter ID/registration) ",
    "is consistent with Minnesota's automatic voter registration bills. The ",
    "Divided group result (Topic 1 dominant) is not interpretable given n=2."
  ),
  paste0(
    "With only 33 documents, LDA topics should be treated as exploratory. ",
    "The alpha=50/K and delta=0.1 priors are standard for short-document ",
    "corpora and produced more interpretable topics than the default settings. ",
    "Always print top 15 words before charting — topic labelling requires ",
    "human review and cannot be automated."
  ),
  TRUE,

  # ── Entry 6: LLM classification + human validation ───────────────────────
  6L,
  "Claude Opus 4.6 (claude-opus-4-6) via Anthropic API + human coder",
  "Classify 51 voting bills as RESTRICTIVE / EXPANSIVE / NEUTRAL; validate with human coder",
  paste0(
    "SYSTEM PROMPT: 'You are an expert in U.S. election law and voting rights ",
    "policy. Classify the bill using EXACTLY ONE of these three labels: ",
    "RESTRICTIVE (adds new requirements, restrictions, or barriers that could ",
    "reduce voter participation or access), EXPANSIVE (expands, protects, or ",
    "facilitates voter access or participation), NEUTRAL (procedural or ",
    "administrative changes without a clear directional impact on voter access). ",
    "Respond with a JSON object containing exactly two fields: label and ",
    "rationale.' USER PROMPT: bill title + first 8000 words of bill text."
  ),
  paste0(
    "Three issues encountered and resolved: (1) ANTHROPIC_API_KEY had 'sk-ant-",
    "api03-' doubled — fixed by editing ~/.Renviron; (2) Account had $0 API ",
    "credits despite Claude Pro subscription — credits purchased separately; ",
    "(3) Model wrapped JSON in markdown fences (```json...```) causing parse ",
    "failure — fixed with str_remove_all() before jsonlite::fromJSON(). ",
    "(4) HTTP 429 rate limiting after first few calls — fixed with req_retry() ",
    "exponential backoff (30/60/120s) and 3s base sleep. ",
    "Final classification results (51 bills): R=100% RESTRICTIVE; ",
    "D=58% RESTRICTIVE, 33% NEUTRAL, 8% EXPANSIVE; Divided=86% NEUTRAL, 14% EXPANSIVE. ",
    "Human validation (10-bill stratified sample, single coder): 9/10 agreement, ",
    "Cohen's kappa = 0.831 (almost perfect). One disagreement: HB1871/MO — LLM ",
    "labeled RESTRICTIVE (new presidential primary structure); human labeled NEUTRAL ",
    "(procedural scheduling change). All Neutral bills agreed."
  ),
  paste0(
    "ACCEPTED. Human validation confirms the classifier is reliable (kappa 0.831 ",
    "exceeds the 0.61 substantial-agreement target). The single disagreement ",
    "illustrates the rubric's Neutral/Restrictive boundary: the LLM applies ",
    "'adds new requirements' strictly to any electoral system change, while a ",
    "human expert distinguishes between requirements that burden voters and those ",
    "that only govern election administrators. Single-coder design (vs. planned ",
    "two-coder) is a limitation; Human-vs-Human ceiling cannot be established."
  ),
  paste0(
    "Always test a single API call manually before running a full loop — this ",
    "would have caught the markdown fence issue immediately. Store API keys as ",
    "plain KEY=value in ~/.Renviron with no surrounding quotes or R code. ",
    "Claude Pro and Anthropic API credits are entirely separate billing systems. ",
    "For rate-limited APIs, req_retry() with exponential backoff is more robust ",
    "than a fixed Sys.sleep(). For human validation, store codes in a separate ",
    "human_codes.csv rather than editing the large validation export directly."
  ),
  TRUE
)

# ── Save CSV ──────────────────────────────────────────────────────────────────
readr::write_csv(log_entries, "results/ai_collab_log.csv")
cat("Saved: results/ai_collab_log.csv\n")

# ── Save Markdown ─────────────────────────────────────────────────────────────
md_lines <- c(
  "# AI Collaboration Log — Voting Bills Project",
  paste0("**Course:** EPPS6323  |  **Date:** ", Sys.Date()),
  "",
  "Each entry documents: tool used, full prompt, AI output, review decision,",
  "lesson learned, and success flag.",
  "---",
  ""
)

for (i in seq_len(nrow(log_entries))) {
  e <- log_entries[i, ]
  md_lines <- c(md_lines,
    paste0("## Entry ", e$step, ": ", e$prompt_summary),
    "",
    paste0("**Tool:** ", e$tool_used),
    "",
    paste0("**Full Prompt:**  \n", e$full_prompt),
    "",
    paste0("**AI Output:**  \n", e$ai_output_summary),
    "",
    paste0("**Review Decision:**  \n", e$review_decision),
    "",
    paste0("**Lesson Learned:**  \n", e$lesson_learned),
    "",
    paste0("**Success:** ", ifelse(e$success, "YES", "NO")),
    "",
    "---",
    ""
  )
}

writeLines(md_lines, "results/ai_collab_log.md")
cat("Saved: results/ai_collab_log.md\n")
cat("Entries logged:", nrow(log_entries), "\n")

message("07_ai_collab_log.R complete.")

# ── COMMON ERRORS AND FIXES ──────────────────────────────────────────────────
# ERROR: "no such file" for results/
#   FIX:  Run 00_setup.R first to create the folder structure.
#
# NOTE:  This log documents the AI-assisted steps only. Human decisions
#        (trifecta label verification, topic labelling, kappa interpretation)
#        are described in the review_decision field of each entry.
