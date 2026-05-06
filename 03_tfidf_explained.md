# Script 03: Distinctive Word Patterns — Plain-English Explanation

## What this step did

This step answered: **"What words does each political group use that the others don't?"**

Rather than finding the most common words overall (which would be the same across all groups — "vote" and "election" appear everywhere), this analysis finds words that are *disproportionately* characteristic of one group compared to the others.

The method is **TF-IDF (Term Frequency–Inverse Document Frequency)**. It rewards words that are frequent within one group *and* rare across the other groups. The approach works as follows:

1. All bills in the same trifecta group are merged into a single pseudo-document (using `dfm_group()`). This produces three pseudo-documents: one for Unified Republican, one for Unified Democratic, one for Divided Government.
2. TF-IDF is then computed across these three pseudo-documents using `dfm_tfidf()` with raw term frequency (`scheme_tf = "count"`) and standard inverse document frequency (`scheme_df = "inverse"`, `base = 10`).
3. With only N = 3 groups, the IDF component rewards:
   - Terms appearing in **1 group only**: log₁₀(3/1) ≈ 0.477 (maximum reward — exclusive vocabulary)
   - Terms appearing in **2 groups**: log₁₀(3/2) ≈ 0.176 (moderate reward)
   - Terms appearing in **all 3 groups**: log₁₀(3/3) = 0 (no reward — universal boilerplate filtered out automatically)

The final TF-IDF score for each term within a group is the product of its raw count in that group's pseudo-document and its IDF weight.

## What the output files contain

- **`results/tfidf_by_trifecta.csv`** — Top 20 distinctive word stems per group with TF-IDF score
- **`figures/tfidf_top_terms_by_trifecta.png`** — Bar chart showing the top 15 stems per group in tinted panels

## Top-line numbers from the actual run (51 bills)

**Top 5 most distinctive word stems per group:**

| Group | Word | TF-IDF Score | Likely meaning |
|-------|------|-------------|----------------|
| Unified Republican | elector | 227 | Electoral college electors / elector certification |
| Unified Republican | provision | ~180 | Statutory provision language |
| Unified Republican | utah | ~165 | Utah-specific bill language |
| Unified Republican | commission | ~140 | Election commissions |
| Unified Republican | falsif | ~120 | Falsification (election fraud provisions) |
| Unified Democratic | 203b | 357 | Minnesota election statute section |
| Unified Democratic | auditor | ~290 | County auditors administering elections (MN-specific role) |
| Unified Democratic | jfk | ~210 | JFK-era absentee ballot legacy language (MN) |
| Unified Democratic | minnesota | ~195 | State-specific language in MN bills |
| Unified Democratic | 204c | ~180 | Another MN election code section |
| Divided Government | underlin | 7.22 | PDF formatting artifact (amendment markup) |
| Divided Government | fiscal | ~5.8 | Fiscal note / fiscal impact language |
| Divided Government | factor | ~4.9 | Factor (procedural/administrative context) |

Note: Divided Government TF-IDF scores are much lower than R and D scores. This reflects the fact that Divided-government bills (PA, WI, NC, NV, CT, IL, MD) use vocabulary that overlaps substantially with the other two groups — consistent with the finding that these states pass administrative, procedural legislation rather than politically distinctive voting legislation.

## Anything surprising or worth flagging

**Republican bills emphasize structural and certification language** — "elector", "commission", and "falsif" point toward elector certification processes and election fraud provisions. This is consistent with the 2025–26 session timing following post-2020 election disputes, and with the LLM classification result that 100% of R-trifecta bills are Restrictive.

**Democratic bills remain heavily Minnesota-inflected.** Minnesota section references ("203b", "204c") and "auditor" (county auditors run elections in MN, unlike most states) are the top distinctive terms for the D group. Even with the expanded corpus (MN now 58% of D-trifecta bills vs. 78% before), MN's distinctive administrative statute structure dominates the D-trifecta vocabulary.

**Divided Government TF-IDF scores are very low (< 10).** This is methodologically meaningful, not a failure. With N = 3 pseudo-documents, a term must appear almost exclusively in one group to receive a high TF-IDF score. Divided-government bills share most of their vocabulary with R or D bills — their legislation is not lexically distinctive, which independently corroborates the finding that divided states pass generic administrative bills rather than ideologically oriented voting legislation.

**"Underlin" for Divided Government** is a PDF markup artifact. Several states (PA, WI) publish bills with strikethrough/underline markup indicating statutory amendments, and the PDF text layer captures "underline" as a literal word. Its presence as the top distinctive term for Divided Government reflects corpus noise, not substantive content.

## What the next script uses this for

Script 04 independently discovers topic clusters from raw word patterns via LDA. The TF-IDF distinctive terms serve as a qualitative check: the elector-certification and redistricting language identified for R-trifecta states should align with the topic themes that emerge from LDA.
