# WHAT: Extracts plain text from the 50 bill PDFs, cleans and normalises the
#       text, builds a document-feature matrix (DFM) using quanteda, and saves
#       a tidy corpus ready for TF-IDF (script 03) and LDA (script 04).
# WHY:  All text-analysis methods in this project share the same cleaned
#       tokens; centralising preprocessing avoids inconsistencies downstream.
# INPUTS:  data/raw_pdfs/  (PDF files)
#          data/bill_metadata.rds  (bill_id → trifecta mapping)
# OUTPUTS: data/bill_corpus.rds      (quanteda corpus object with docvars)
#          data/bill_dfm.rds         (document-feature matrix, trimmed)
#          data/bill_tokens.rds      (quanteda tokens object)
#          data/bill_text.rds        (tibble: bill_id + raw cleaned text)
# ESTIMATED RUNTIME: 1–3 minutes (PDF extraction is the bottleneck)

source("global_constants.R")

library(pdftools)     # PDF text extraction
library(quanteda)     # Corpus / DFM / tokenisation
library(quanteda.textstats)

# ── 1. Load metadata ──────────────────────────────────────────────────────────
meta <- readRDS("data/bill_metadata.rds")
cat("Metadata loaded:", nrow(meta), "bills\n")

# ── 2. Extract text from PDFs ─────────────────────────────────────────────────
cat("\nExtracting text from PDFs...\n")

# Map bill_id → PDF path
pdf_paths <- list.files(RAW_DIR, pattern = "\\.pdf$", recursive = TRUE,
                        full.names = TRUE)
# Build a named vector: bill_id (character) → path
pdf_ids <- stringr::str_extract(basename(pdf_paths), "\\d+")
names(pdf_paths) <- pdf_ids

extract_pdf_text <- function(bill_id) {
  path <- pdf_paths[as.character(bill_id)]
  if (is.na(path) || !file.exists(path)) {
    warning("PDF not found for bill_id ", bill_id)
    return(NA_character_)
  }
  tryCatch({
    pages <- pdftools::pdf_text(path)
    paste(pages, collapse = "\n")
  }, error = function(e) {
    warning("PDF read error for bill_id ", bill_id, ": ", e$message)
    NA_character_
  })
}

meta$raw_text <- vapply(meta$bill_id, extract_pdf_text, character(1))

n_empty <- sum(is.na(meta$raw_text) | nchar(trimws(meta$raw_text)) < 50)
cat("PDFs with usable text:", nrow(meta) - n_empty, "/", nrow(meta), "\n")
if (n_empty > 0) {
  warning(n_empty, " bills have very short or missing text and will be excluded.")
  meta <- dplyr::filter(meta, !is.na(raw_text) & nchar(trimws(raw_text)) >= 50)
}

# CHECKPOINT: confirm text was extracted
cat("Characters extracted (sample bill 1):",
    nchar(meta$raw_text[1]), "\n")

# ── 3. Basic text cleaning ────────────────────────────────────────────────────
clean_text <- function(txt) {
  txt |>
    stringr::str_replace_all("\\f",            " ") |>   # form feeds
    stringr::str_replace_all("-\\s*\n\\s*",    "")  |>   # hyphenated line breaks
    stringr::str_replace_all("\\s+",           " ") |>   # collapse whitespace
    stringr::str_replace_all("(?i)page\\s+\\d+", "") |>  # page numbers
    stringr::str_replace_all("[^[:print:]]",   " ") |>   # non-printable chars
    trimws()
}

meta$clean_text <- vapply(meta$raw_text, clean_text, character(1))

# Save the text tibble
bill_text <- dplyr::select(meta, bill_id, state, year, trifecta,
                           sponsor_party, clean_text)
saveRDS(bill_text, "data/bill_text.rds")
cat("Saved: data/bill_text.rds\n")

# ── 4. Build quanteda corpus ──────────────────────────────────────────────────
corp <- quanteda::corpus(
  meta$clean_text,
  docnames  = meta$bill_id,
  docvars   = dplyr::select(meta, bill_id, state, year, trifecta, sponsor_party,
                             bill_number, title, status)
)

saveRDS(corp, "data/bill_corpus.rds")
cat("Saved: data/bill_corpus.rds\n")
cat("Corpus size:", ndoc(corp), "documents\n")

# ── 5. Tokenise and build DFM ─────────────────────────────────────────────────
set.seed(SEED)

# Standard English stopwords + domain-specific additions
domain_stops <- c(
  # Legal boilerplate
  "section", "shall", "act", "bill", "law", "state", "code", "chapter",
  "subsection", "paragraph", "subdivision", "amended", "amend", "amendment",
  "article", "statute", "provided", "pursuant", "thereof", "therein",
  "herein", "hereafter", "heretofore", "aforesaid", "aforementioned",
  "effective", "enact", "enacted", "hereby", "whereas", "following",
  "upon", "within", "without", "under", "pursuant", "per", "set",
  # Numbers and generic words that add no semantic content
  "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
  "ten", "hundred", "thousand", "million", "percent",
  # Common procedural words
  "may", "must", "also", "including", "include", "includes", "included",
  "apply", "applies", "applied", "application", "provide", "provides",
  "provided", "related", "required", "require", "requires", "requirement",
  "new", "current", "date", "year", "years", "days", "day", "time"
)

toks <- corp |>
  quanteda::tokens(
    remove_punct    = TRUE,
    remove_symbols  = TRUE,
    remove_numbers  = TRUE,
    remove_url      = TRUE,
    split_hyphens   = FALSE,
    padding         = FALSE
  ) |>
  quanteda::tokens_tolower() |>
  quanteda::tokens_remove(
    pattern = c(quanteda::stopwords("en"), domain_stops),
    padding = FALSE
  ) |>
  quanteda::tokens_wordstem(language = "en") |>
  quanteda::tokens_select(min_nchar = 3)   # drop very short tokens

saveRDS(toks, "data/bill_tokens.rds")
cat("Saved: data/bill_tokens.rds\n")

# Document-feature matrix
dfm_raw <- quanteda::dfm(toks)

# Trim: keep features appearing in at least 2 documents, drop top 0.5% most
# common (usually residual boilerplate not caught by stopwords)
# Trim in two steps: first by min count, then by max proportion
dfm_trim <- dfm_raw |>
  quanteda::dfm_trim(min_docfreq = 2,   docfreq_type = "count") |>
  quanteda::dfm_trim(max_docfreq = 0.99, docfreq_type = "prop")

saveRDS(dfm_trim, "data/bill_dfm.rds")
cat("Saved: data/bill_dfm.rds\n")

# CHECKPOINT: report vocabulary stats
cat("\n── Preprocessing summary ───────────────────────────────────\n")
cat("Documents:           ", ndoc(dfm_trim), "\n")
cat("Vocabulary (trimmed):", nfeat(dfm_trim), "unique stems\n")
cat("Total tokens (raw):  ", sum(ntoken(toks)), "\n")
cat("Avg tokens / doc:    ", round(mean(ntoken(toks))), "\n")
cat("\nTrifecta distribution in corpus:\n")
print(table(quanteda::docvars(corp, "trifecta")))
cat("\nTop 20 most frequent stems:\n")
top20 <- quanteda::topfeatures(dfm_trim, 20)
print(top20)

message("02_preprocessing.R complete.")

# ── COMMON ERRORS AND FIXES ──────────────────────────────────────────────────
# ERROR: "there is no package called 'pdftools'"
#   FIX:  install.packages("pdftools")
#         On Mac you may also need: brew install poppler
#
# ERROR: "there is no package called 'quanteda'"
#   FIX:  install.packages(c("quanteda", "quanteda.textstats"))
#
# ERROR: PDF text is garbled / 0 chars extracted
#   FIX:  Some PDFs are image-based (scanned). pdftools can't OCR them.
#         Flag with warning() and exclude from corpus. Check n_empty above.
#
# ERROR: DFM has 0 features after trimming
#   FIX:  Lower min_docfreq to 1 (include hapax legomena) or increase
#         max_docfreq threshold.
