# v1.1 — repaired realised-resources checks (19 October 2026)

## Why the prior run stopped at stage 03

The run `20261019_201532` verified the 104,848-row canonical baseline, saving amounts, and age heterogeneity. Its `COVERAGE_AUDIT.csv` shows 0 valid values for `personal_net_income` at both BHPS interview dates. The upstream historical cohort builder requested `fimnnet_dv`, although the harmonised BHPS provides `fimngrs_dv` for **gross** monthly personal income. The previously bundled stage required complete income **and** activity observations, so it also prevented estimation of employment transitions despite complete employment-status coverage.

## What changed

- Added `FINAL_RESOURCES_REPAIR.R` and sourced it in `FINAL_EMPIRICAL_CHECKS.R` in place of the original stage 03.
- Reads selected columns *directly* from local UKDS BHPS `b[a-r]_indresp.tab` and `b[a-r]_hhresp.tab` in memory. Uses `fimngrs_dv` for **gross** personal income, and `fihhmngrs_dv` (linked by wave-specific household ID) for **gross** household income when present. No silent substitutions, no net/disposable labels.
- Separates raw-source audit, personal-income regressions, household-income regressions, and employment transitions into independent stages. Each can fail independently; earlier successful stages and the frozen source are untouched.
- Adds aggregate `RESOURCE_SOURCE_AUDIT.csv` identifying available columns, matched rows, and valid values wave by wave. Licensed microdata are neither written to Dropbox nor included in this package.
- Renames the four age bands' internal specification label from `four_prespecified_age_bands` to `four_exploratory_age_bands` (no mathematical change; the bands were not registered in advance).
- Keeps the original fixed-effects estimator, exact canonical rows, weights, PSU-stratum covariance, saving-amount transformations, and age models otherwise unchanged.

## Run

Extract the `Final_Empirical_Checks/` folder **over the existing folder** under:

`C:\path\to\Financial_Pessimism\05_Supplementary_Analyses\`

Run in Julia:

```julia
include(raw"C:\path\to\Financial_Pessimism\05_Supplementary_Analyses\Final_Empirical_Checks\RUN_FINAL_EMPIRICAL_CHECKS.jl")
```

This reruns the successful smoke/canonical/saving/age stages; the original results folder remains unchanged and a new dated aggregate results folder is created automatically. Check the new `STAGE_STATUS.csv` and `RESOURCE_SOURCE_AUDIT.csv`. The gross household-income analysis is independent of the personal one and may be unavailable for waves in which the relevant HHRESP field is absent; such noncoverage is explicitly audited.

**Validation scope:** Static syntax/delimiter/source-contract checks passed in the authoring environment; raw TAB extraction cannot be executed without the licensed local files and should not be treated as verified until the PC run completes.
