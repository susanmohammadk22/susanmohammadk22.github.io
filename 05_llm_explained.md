# Script 05: AI-Assisted Classification — Plain-English Explanation

## What this step did

This step sent each bill's text to an AI language model (Claude Opus 4.6) and asked it to classify the bill into one of three categories:

- **RESTRICTIVE** — adds new requirements, restrictions, or barriers that could reduce voter participation or access (stricter ID requirements, shorter registration windows, reduced polling hours, increased signature thresholds)
- **EXPANSIVE** — expands, protects, or facilitates voter access or participation (automatic voter registration, extended early voting, vote-by-mail expansion, restoring voting rights)
- **NEUTRAL** — procedural or administrative changes without a clear directional impact on voter access (updating forms, renaming offices, clarifying definitions, adjusting deadlines for election officials)

The AI received each bill's title and up to the first 8,000 words of text, then returned a label and a one-to-two sentence rationale explaining the key provision(s) that drove its decision.

The classification was run in two rounds: 33 bills in the first round, then 18 new bills added in round 2 — existing labels were preserved and only the new bills were sent to the API. Every API call included error-handling and exponential backoff for rate limiting (up to 2-minute waits between retries).

## What the output files contain

- **`data/llm_labels.rds`** — Full results: bill ID, label, rationale, state, year, trifecta
- **`results/llm_labels.csv`** — Human-readable version of the same
- **`results/labels_by_trifecta.csv`** — Cross-tabulation of label × trifecta with counts and percentages
- **`figures/labels_by_trifecta.png`** — Horizontal stacked bar chart showing the label split per group

## Top-line numbers from the actual run (51 bills)

**All 51 bills were successfully classified.**

| Group | n bills | RESTRICTIVE | NEUTRAL | EXPANSIVE |
|-------|---------|-------------|---------|-----------|
| Unified Republican | 13 | **100%** | 0% | 0% |
| Unified Democratic | 24 | **58%** | 33% | 8% |
| Divided Government | 14 | 0% | **86%** | 14% |

Overall: 27 Restrictive (53%), 20 Neutral (39%), 4 Expansive (8%)

## Anything surprising or worth flagging

**100% of Republican-trifecta bills are Restrictive.** Every one of the 13 R-trifecta bills was classified as adding new requirements or restrictions — covering redistricting, elector certification steps, petition signature thresholds, and absentee ballot procedures. The rubric applies strictly: any bill that adds a new requirement, even a minor procedural one, qualifies as Restrictive.

**58% of Democratic-trifecta bills are also Restrictive.** This is counterintuitive but explainable. Most come from Minnesota, which in 2025 passed multiple absentee ballot reform bills. Many of these add new administrative steps — new envelope verification requirements, updated timeline rules, new audit procedures — that trigger the "adds new requirements" criterion even though the political intent was to modernize and standardize voting, not restrict it. The remaining 33% are Neutral (procedural changes with no directional impact) and only 8% are Expansive.

**Divided Government states are overwhelmingly Neutral (86%).** This is the clearest finding from the expanded corpus: states where no single party has full control pass procedural, administrative bills rather than taking strong access positions. Only 14% of Divided-government bills are Expansive, and none are Restrictive — consistent with the political dynamic where neither party can impose major access changes unilaterally.

**The Neutral category grew substantially in round 2.** The 18 new bills (CT, IL, MD, PA, WI, NC, NV) were all classified as Neutral. This shifted the overall distribution from the first run (which was 82% Restrictive) to a more balanced picture (53% Restrictive, 39% Neutral) — suggesting the original 33-bill corpus was not representative of the full range of voting legislation.

**Important caveat on the rubric:** The AI applies the three-category rubric literally. A bill that modernizes absentee voting by both expanding access (new drop boxes) and adding requirements (new ID verification step) must receive a single label. The rationale field for each bill documents which specific provision drove the decision. For full transparency, `results/llm_labels.csv` contains the rationale for all 51 bills.

## What the next script uses this for

Script 06 exports 10 randomly selected bills for independent human coding to check whether the AI's classifications match expert human judgment. The validation sample is stratified across the three trifecta groups.
