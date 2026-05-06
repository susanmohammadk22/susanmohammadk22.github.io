# Script 02: Preprocessing — Plain-English Explanation

## What this step did

This step converted bill PDF files into clean, analyzable text. Think of it as turning a stack of legal documents into a structured dataset of words that a computer can work with.

The project collected bills in two rounds: an original set of 50 bills, and a second round of 33 additional bills pulled from new states to improve geographic balance (adding IL, CO, CT, MD for Democratic-trifecta coverage and PA, WI, NC, NV for Divided-government coverage). That brings the starting total to 83 PDFs.

For each PDF, the script:
1. Extracted all printed text from every page
2. Cleaned up formatting artifacts (page numbers, hyphenated line breaks, special characters)
3. Split the text into individual words and removed common filler words ("the", "and", "shall", "enacted") that appear everywhere and would mask meaningful differences
4. Condensed words to their root form ("voters", "voting", "voted" → "vote") so the same concept isn't counted as three separate words
5. Assembled all cleaned words into a structured format ready for analysis

## What the output files contain

- **`data/bill_text.rds`** — One row per bill: cleaned full text, state, year, trifecta group
- **`data/bill_corpus.rds`** — The same text in a format designed for text-analysis software
- **`data/bill_tokens.rds`** — Each bill broken into its individual cleaned word stems
- **`data/bill_dfm.rds`** — A word-count matrix: rows = bills, columns = unique words. This is the input for both the distinctive-word analysis (script 03) and the topic grouping (script 04)

## Top-line numbers from the actual run

- **Bills started with: 83** (50 original + 33 added in round 2)
- **Bills with usable text: 51** (62%)
- **Bills excluded: 32** — unreadable PDFs (corrupted files or PDFs with no embedded text)
- **Unique word stems in vocabulary: 2,589** (after removing stopwords and rare/universal terms)
- **Total words processed: 268,589** across all 51 bills
- **Average bill length: 5,266 words** per document

State distribution of the 51 usable bills:

| State | n | Trifecta |
|-------|---|----------|
| MN | 14 | D |
| PA | 5 | Divided |
| MO | 4 | D→R (2026) |
| NV | 3 | Divided |
| OH | 3 | R |
| WA | 3 | D |
| AK | 2 | Divided |
| CT | 2 | D |
| IL | 2 | D |
| MD | 2 | D |
| NC | 2 | Divided |
| NE | 2 | R |
| UT | 2 | R |
| KS, MO, NM, OK, WI | 1–2 each | mixed |

Trifecta breakdown of the 51 usable bills:
- **Unified Republican: 13 bills** (MO, OH, NE, UT, KS, OK, IN)
- **Unified Democratic: 24 bills** (MN, WA, IL, CT, MD, NJ, NM)
- **Divided Government: 14 bills** (PA, NV, NC, AK, VA, WI)

## Anything surprising or worth flagging

**39% attrition is high.** Losing 32 of 83 bills to PDF extraction failure is significant. The failures appear to be a data quality issue in the source files — several PDFs were extremely small (98 bytes, essentially empty placeholder files). Whether the excluded bills are systematically different from the included ones is unknown; this remains a study limitation.

**Minnesota is still the largest single-state contributor.** MN accounts for 14 of 24 Democratic-trifecta bills (58%). This is a significant improvement over the first data collection round (where MN was 78% of Democratic bills), but it means Democratic findings still partly reflect Minnesota's distinctive legislative style. This is flagged consistently throughout the analysis.

**Divided Government is now a viable group.** Adding PA, WI, NC, and NV brought the Divided group from 2 bills to 14 — enough to draw cautious conclusions. Findings for this group should still be treated as exploratory given the sample size, but patterns can now be meaningfully discussed.

## What the next script uses this for

Script 03 reads `data/bill_dfm.rds` and finds which words are most uniquely associated with each trifecta group using a statistical comparison test.

Script 04 also reads `data/bill_dfm.rds` and discovers latent policy themes running through the full corpus.
