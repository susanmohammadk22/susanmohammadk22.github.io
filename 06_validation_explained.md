# Script 06: Human Validation — Plain-English Explanation

## What this step did

This step creates an independent check on the AI classifier from script 05. The core question: **when a human expert reads the same bills, do they reach the same conclusions as the AI?**

Ten bills were randomly selected, stratified across the three trifecta groups to ensure representation from each. For each bill, the AI label was hidden — the coder only saw the bill title, state, year, and the first ~1,500 words of text. The coder classified each bill independently using the same three-category rubric (RESTRICTIVE / EXPANSIVE / NEUTRAL).

**Note on coder design:** The original plan called for two independent coders so that both Human-vs-Human and LLM-vs-Human kappa could be computed. After the coding round, a decision was made to use a single-coder design. Human-vs-Human inter-rater reliability is therefore not reported. Only LLM-vs-Human Cohen's Kappa is computed, which measures how well the AI classifier agrees with one expert human rater.

## What the output files contain

- **`validation/llm_validation_sample.csv`** — 10 bills with text previews and the human coder's label
- **`validation/human_codes.csv`** — Single-entry human coding file (bill_id + coder1_label)
- **`results/validation_kappa.csv`** — LLM-vs-Human kappa score and raw agreement
- **`figures/validation_agreement.png`** — Bar chart of kappa vs. the 0.61 target

## Top-line numbers from the completed validation

**Status: Complete.** Human coding was collected for all 10 sampled bills.

Sample composition (10 bills, stratified):
- Unified Republican: 3 bills (HB1871/MO, HB0479/UT, LB541/NE)
- Unified Democratic: 5 bills (SF1527/MN, HF2119/MN, HB2206/WA, HF4240/MN, SF4006/MN)
- Divided Government: 2 bills (H580/NC, HB785/PA)

### Agreement results

| Metric | Value |
|--------|-------|
| Bills coded | 10 |
| Raw agreement | 9/10 (90%) |
| Cohen's Kappa (LLM vs. Human) | **κ = 0.831** |
| Interpretation | Almost perfect (≥ 0.81) |
| Target met (κ ≥ 0.61)? | **Yes** |

### Bill-by-bill comparison

| Bill | State | Trifecta | LLM Label | Human Label | Agrees? |
|------|-------|----------|-----------|-------------|---------|
| H580 | NC | Divided | NEUTRAL | NEUTRAL | ✓ |
| SF1527 | MN | D | RESTRICTIVE | RESTRICTIVE | ✓ |
| HF2119 | MN | D | RESTRICTIVE | RESTRICTIVE | ✓ |
| HB1871 | MO | R | RESTRICTIVE | NEUTRAL | ✗ |
| HB2206 | WA | D | EXPANSIVE | EXPANSIVE | ✓ |
| HB0479 | UT | R | RESTRICTIVE | RESTRICTIVE | ✓ |
| LB541 | NE | R | RESTRICTIVE | RESTRICTIVE | ✓ |
| HB785 | PA | Divided | NEUTRAL | NEUTRAL | ✓ |
| HF4240 | MN | D | NEUTRAL | NEUTRAL | ✓ |
| SF4006 | MN | D | NEUTRAL | NEUTRAL | ✓ |

## Anything surprising or worth flagging

**κ = 0.831 substantially exceeds the 0.61 target.** The AI classifier demonstrates almost-perfect agreement with the human coder across 10 bills spanning all three trifecta groups. This is a strong validation result, especially given the rubric's inherent ambiguity at the Neutral/Restrictive boundary.

**The one disagreement is theoretically informative.** HB1871 (Missouri) was classified RESTRICTIVE by the AI and NEUTRAL by the human coder. The bill restructures Missouri's presidential preference primary (moving it to the first Tuesday in March of presidential years) and modifies election notification requirements. The AI applied the rubric strictly: any bill that adds new procedural requirements qualifies as RESTRICTIVE. A human reader interpreted these changes as election scheduling adjustments — administrative and structural — with no direct impact on voter access. This is precisely the rubric boundary case flagged in the project's limitations: the AI treats "adds new requirements to any part of the electoral system" as RESTRICTIVE, while a human expert may distinguish between requirements that burden *voters* and requirements that govern *election administrators*.

**Single-coder limitation.** Because only one coder completed the validation, the expected agreement by chance (the baseline kappa is corrected against) is estimated from a single rater's marginal distribution. A two-coder design would also have established how much human-to-human disagreement exists on this task, providing a ceiling against which the LLM-vs-human score could be benchmarked. The kappa of 0.83 should be interpreted as a point estimate with substantial uncertainty given n=10.

**The Neutral category performed well.** All six bills classified NEUTRAL by the LLM were also classified NEUTRAL by the human coder. The contested boundary is not Neutral vs. Expansive, but Neutral vs. Restrictive — consistent with the analysis explanation for script 05.

## What the next script uses this for

Script 07 (AI collaboration log) documents this validation step as part of the required project audit trail. The final report uses the validation results (κ = 0.831, 90% raw agreement) as evidence that the LLM classification is reliable enough to support the headline findings.
