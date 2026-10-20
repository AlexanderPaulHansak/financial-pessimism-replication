# Financial pessimism: canonical code replay

Generated: 2026-10-16T14:08:31+02:00

**Canonical replay: PASS**

- Comparisons: 21 coefficients (three contrasts per outcome).
- This replay uses the actual Codex sample builder and weighted FE/stratified PSU estimator.
- Baseline panel extract and all licensed data remained on the local Windows data drive.
- This does NOT establish independent R equivalence yet: the private model-ready CSV files are the inputs for that next check.

## Model sample sizes

| Model | Observations | Individuals | PSUs | Strata |
|---|---:|---:|---:|---:|
| BHPS_gross_published_lw | 104,848 | 12,644 | 1,511 | 122 |
| UKHLS_gross_published_lw | 85,514 | 23,166 | 5,663 | 1,875 |
| UKHLS_gross_timing_published_lw | 55,186 | 17,639 | 4,806 | 1,846 |

- Maximum point-estimate discrepancy: 1.8735014e-14 percentage points.
- Maximum SE discrepancy: 9.7144515e-15 percentage points.

## Next
Compare independent R estimation on the exact locally saved canonical sample.
Do not publish or upload any file ending `_LOCAL.csv`.
