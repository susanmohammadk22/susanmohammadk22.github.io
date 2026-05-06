# Script 04: Topic Grouping — Plain-English Explanation

## What this step did

This step asked: **"What policy areas do these bills naturally cluster into?"** — without telling the algorithm anything about politics or trifecta groups in advance.

The method reads all 51 bills simultaneously and looks for groups of words that tend to co-occur across documents. If bills that mention "elector" also tend to mention "revis" and "divis", the algorithm infers these words belong to the same underlying policy theme. It does this for all words at once, discovering the set of themes that best explains the patterns it sees.

The number of themes (K=4) was set by the research team. The algorithm ran 800 iterations, with the first 200 treated as a warm-up before results were recorded. The random seed (42) ensures fully reproducible results.

The algorithm produces two outputs:
- **Word-topic probabilities**: how central each word is to each theme
- **Document-topic proportions**: what fraction of each bill belongs to each theme (bills can partially belong to multiple themes)

## What the output files contain

- **`data/lda_model.rds`** — The full fitted topic model
- **`data/bill_topics.rds`** — Per-bill topic proportions merged with trifecta metadata
- **`figures/topic_top_words.png`** — Top 10 words per theme (lollipop chart, used for manual labelling)
- **`figures/topic_distribution_by_trifecta.png`** — Average theme proportion by trifecta group

## Top-line numbers from the actual run (51 bills)

**Theme labels (assigned manually after reading top 15 words):**

| Theme | Human Label | Top words |
|-------|-------------|-----------|
| Topic 1 | Election Administration | elect, ballot, voter, vote, counti, offic, poll, place, clerk |
| Topic 2 | Voter ID & Registration | voter, ballot, identif, card, number, minnesota, auditor, licens |
| Topic 3 | Redistricting & Certification | elect, voter, board, elector, revis, registr, divis, petit, secretari |
| Topic 4 | Local Government & Procedures | individu, author, describ, mean, govern, inform, local, tax, district |

**Average theme proportion by trifecta group:**

| Group | n | Topic 1 (Admin) | Topic 2 (Voter ID) | Topic 3 (Redistricting) | Topic 4 (Local Gov) |
|-------|---|-----------------|--------------------|--------------------------|--------------------|
| Unified Republican | 13 | **52%** | 7% | **31%** | 11% |
| Unified Democratic | 24 | 20% | **56%** | 4% | 20% |
| Divided Government | 14 | 21% | 12% | 12% | **55%** |

**Overall mean topic proportions across all 51 bills:**
- Topic 1: 28% · Topic 2: 31% · Topic 3: 13% · Topic 4: 27%

## Anything surprising or worth flagging

**Republican bills split between Administration and Redistricting.** R-trifecta states concentrate on Topic 1 (election administration, 52%) and Topic 3 (redistricting/elector certification, 31%). This suggests their 2025–26 legislative agenda focused on the mechanics and structure of elections — who certifies results, how districts are drawn, what petitions require.

**Democratic bills are dominated by Topic 2 (Voter ID & Registration, 56%).** This is largely driven by Minnesota's automatic voter registration bills and voter ID card expansion legislation. The topic captures both "restrictive" ID requirements and "expansive" registration access bills, because both share the same vocabulary — the language of voter ID and registration is similar regardless of whether the bill expands or restricts access.

**Divided-Government states cluster heavily in Topic 4 (Local Government & Procedures, 55%).** PA, WI, NC, and NV bills emphasize local government authority, administrative procedures, and institutional structures rather than taking a strong position on voter access. This is consistent with divided-government states being unable to pass bold policy in either direction.

**Topic 3 (redistricting) is nearly absent from Democratic bills** (4%). This likely reflects that redistricting cycles were already complete in most D-trifecta states by 2025, whereas some R-trifecta states were still processing post-2020 cycle adjustments.

**A note on the expanded corpus:** Adding 33 bills in round 2 meaningfully changed the topic structure compared to the first run on 33 bills. The Divided Government signal is now interpretable and coherent (local/procedural focus) rather than being noise from 2 documents.

## What the next script uses this for

Script 05 (AI classification) reads the raw bill text independently and makes classifications without using the topic model. However, the topic themes provide context for interpreting why certain bills receive Restrictive labels even in Democratic states — Topic 2 bills often add ID requirements that trigger the "Restrictive" criterion regardless of political intent.
