# Financial pessimism — final supplementary empirical checks (v1.1)

**Scope:** Three focused empirical checks motivated by the JoEP/referee discussion: (1) subsequent personal income and employment changes, and the sensitivity of the saving coefficients to conditioning on those realised circumstances; (2) real monthly saving amounts rather than only the saving-participation indicator; and (3) a finer, explicitly exploratory age profile.

These scripts are **new supplementary code**. They do not modify the manuscript, the frozen canonical Python estimates, the independent R verification, or the originally archived scripts. **No new empirical results are claimed until this code has run successfully on the licensed local dataset.**

## Install — correct project location

Extract the ZIP so that all R/Julia source files and the CPI file are located in:

`C:\path\to\Financial_Pessimism\05_Supplementary_Analyses\Final_Empirical_Checks\`

Keep the filenames and folder structure unchanged. This is the relocated **Financial_Pessimism** project, not `predecessor modeling project` and not the deprecated `old_DELETE` project.

## Execute — Julia REPL

```julia
include(raw"C:\path\to\Financial_Pessimism\05_Supplementary_Analyses\Final_Empirical_Checks\RUN_FINAL_EMPIRICAL_CHECKS.jl")
```

The Julia runner first performs a short deterministic **synthetic R/fixest smoke test**, and then executes the empirical checks. No Julia packages are needed for this runner. R must have `data.table` and `fixest`, as it did for the successful October 16 independent verification.

If the runner cannot discover R, set its path first in the Julia REPL, e.g.:

```julia
ENV["FP_RSCRIPT"] = raw"C:\Users\hansakal\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe"
include(raw"C:\path\to\Financial_Pessimism\05_Supplementary_Analyses\Final_Empirical_Checks\RUN_FINAL_EMPIRICAL_CHECKS.jl")
```

If you re-ran the canonical replay with a different run tag, also set:

```julia
ENV["FP_CANONICAL_REPLAY_TAG"] = "20261016_140555" # replace only if you generated a newer verified replay
```

The expected private inputs remain:

- `C:\Hansak\Data\UKHLS_derived\pessimism_canonical_replay_v1\20261016_140555\private_model_ready_samples\BHPS_CANONICAL_SAMPLE_LOCAL.csv`;
- `C:\Hansak\Data\UKHLS_derived\bhps_ukhls_cohort_long_raw.csv`.

The canonical reference aggregate tables are read from the existing `04_Verified_Results/Canonical_Python_20261016_140555` folder. If either private file is missing, **do not copy respondent data to Dropbox**: first use the existing portable canonical replay/Julia upstream instructions in the project root's `README_START_HERE.md`.

To change the local private data location, set `ENV["FP_UK_DERIVED"]` to a **non-cloud-synced** directory. No data need to be redownloaded if the two private files already exist.


## v1.1 repair of the realised-resources stage

The first licensed-data run on 19 October 2026 successfully verified all nine frozen BHPS coefficients and estimated the saving-amount and age checks. It found **0 nonmissing values** for `personal_net_income` in the historical BHPS cohort extract, while `employment_status` was observed on all 104,848 canonical pairs. This is because the original Julia upstream extractor requested BHPS `fimnnet_dv`; the harmonised historical BHPS provides gross monthly personal income as `fimngrs_dv` instead.

Version 1.1 **does not modify the upstream extractor, frozen canonical rows, or earlier result folders**. After the original canonical and saving-status joins pass, the new `FINAL_RESOURCES_REPAIR.R` reads only selected columns from local `C:\Hansak\Data\UKDA-6614-tab\tab\bhps\b[a-r]_indresp.tab` (and matching `hhresp.tab`, when present). It matches the income variables to the 104,848 frozen BHPS rows in memory, audits coverage for both personal and household gross income, and fits the resource specifications on an identical complete-case sample for each measure. The missing income variables are never silently replaced with zero, and gross incomes are not mislabeled net income.

Employment transitions are now an independent stage and run **even if income extraction fails**. The separate stage labels are `03A_RAW_BHPS_INCOME_JOIN`, `03B_GROSS_PERSONAL_INCOME`, `03C_GROSS_HOUSEHOLD_INCOME`, and `03D_EMPLOYMENT_TRANSITIONS`; the saving and age stages remain unchanged. The `RESOURCE_SOURCE_AUDIT.csv` file reports which source columns were actually present, by survey wave. If the licensed raw files are stored in a different *local, non-cloud* folder, set in Julia before execution:

```julia
ENV["FP_BHPS_TAB_ROOT"] = raw"C:\Hansak\Data\UKDA-6614-tab\tab\bhps"
```

As the new raw extraction has not been executed against the licensed files in this environment, its completed status must be established from the local run, not inferred from the fact that the independent canonical verification passed.

## What runs (and in what order)

1. **Frozen-baseline gate.** On the original 104,848 BHPS pairs, re-estimate the nine pessimism contrasts for current saving, subsequent saving, and their difference, using the existing two-way FE weights and stratified-PSU covariance. Require sample/design counts, RHS term count, point estimates and design SEs to agree with the frozen Python results. Tolerances: 0.001 percentage point for estimates and 0.003 percentage point for SEs. If this **fails**, the run **stops** before any new empirical analysis.
2. **Exact local join.** Link the existing private cohort extract by respondent ID and survey wave, at `t` and `t+1`. Assert that observed saving at *both* dates exactly matches the canonical model-ready sample. Assert that age and young/older interactions agree. A mismatch blocks dependent analyses instead of silently creating a new sample.
3. **Realised resources.** Read observed monthly gross personal income (`fimngrs_dv`) from original local BHPS `indresp` and gross household income (`fihhmngrs_dv`) from `hhresp`, then convert to 2015 pounds using annual ONS CPI; estimate the association between forecasts and subsequent income change on the appropriately observed sample. Separately, even if income is unavailable, estimate transitions from employment/self-employment (`jbstat` 1/2) to unemployment (`jbstat` 3) or other nonemployment, explicitly recognising that these are **interview-to-interview transitions, not dated layoffs**. Re-estimate the original saving coefficients on *exactly the same complete-case sample*, both **without** and **with** observed income changes and employment-to-unemployment indicators. **The adjusted comparison is not a causal mediation decomposition**: conditioning on post-forecast variables may introduce selection/collider bias.
4. **Saving amounts.** Use the upstream `saved_monthly` variable from `saved`; explicit non-savers are **zero**, but missing values for savers and the public-codebook `9997-or-above` top-code are **not zero**. Convert recorded amounts to approximate real 2015 pounds and estimate inverse-hyperbolic-sine amount levels and the next-minus-current difference on identical complete-amount pairs, under the original regressors, FE, and survey covariance. Report missingness by expectations category and age. A supplementary within-continuing-saver log-amount model is distinctly labelled as **selected on positive saving at both interviews**.
5. **Age gradients.** On the original canonical BHPS sample, compare slopes for ages 18–24, 25–34, 35–44 and 45–59; add within-original-age-group interaction terms, preserving all original controls and the published age split. Conduct a design-based Wald test of the two within-group additional interactions. Separately estimate a linear age-by-expectations interaction (without the original under-35 forecast interaction), reporting gradients at 20, 30, 40 and 50. Age heterogeneity is **exploratory**, not prespecified.

The script performs a **continue-on-error** run for the new resource, amount, conditional-saver, and age analyses, but **never bypasses the frozen-baseline gate**. If a later stage fails, the other independent stages still run. Failed stages do not write partial coefficient rows.

## Where outputs appear

Only aggregate results are written to a new run-specific folder:

`C:\path\to\Financial_Pessimism\05_Supplementary_Analyses\Final_Empirical_Checks\Results_YYYYMMDD_HHMMSS\`

- **`FINAL_CHECKS_REPORT.md`**: status summary and interpretive limitations.
- **`STAGE_STATUS.csv`**: each stage's success/failure; inspect it before interpreting any coefficients.
- **`BASELINE_CANONICAL_REPLICATION.csv`**: the nine preflight contrasts against frozen reference values.
- **`REGRESSION_CONTRASTS.csv`**: all successful new models, SEs, confidence intervals, N, PSUs/strata and outcome units.
- **`COVERAGE_AUDIT.csv`**: count and weight-share availability by outlook and age (only aggregate cells).
- **`RESOURCE_SOURCE_AUDIT.csv`**: per-wave raw column availability and income coverage; contains no person-level records.
- **`HETEROGENEITY_TESTS.csv`**: joint age interaction tests.

No `pidp` or row-level outcome is written to this folder, including on stage failure.

## Interpretation and checks before publication

- **First**, inspect the baseline gate. If it fails, no new findings should be used.
- **Second**, inspect `COVERAGE_AUDIT.csv`. Complete-case differences by pessimism status may materially affect amount and income results; compare restricted-sample *unadjusted* and *adjusted* coefficients, not a restricted-sample coefficient against the frozen full-sample coefficient.
- **Third**, distinguish gross personal and gross household income from **disposable** household resources. The new source check extracts observed monthly gross-income variables only; it **does not establish net changes in household disposable resources**, and further analysis would require net-income data.
- **Fourth**, saving amounts have a different missingness and top-coding structure from participation. Conditional-saver regressions are especially selected. Interpreting an inverse-hyperbolic-sine coefficient as a percentage change is inappropriate near zero; report it in transformation units or translate it to representative levels under explicit assumptions.
- **Finally**, do not update the main text or appendices until results and coverage have been reviewed. These checks are intended to determine whether the additional empirical work genuinely strengthens the paper, not to generate mechanically significant findings.

### Price source and historical coding

- ONS CPI all-items index, series **D7BT**, annual 2015=100 index, valid for the 1991–2009 BHPS period: https://www.ons.gov.uk/economy/inflationandpriceindices/timeseries/d7bt . The bundled CSV contains the publicly reported historical series and requires no network access on the research PC.
- BHPS variable `saved` is recorded as monthly saving amount; the UKDS BHPS Wave 7 data dictionary labels **9997 as “9997 or above”**. Right-coded or unknown amounts must not be treated as exact monthly amounts. See https://doc.ukdataservice.ac.uk/doc/5151/mrdoc/pdf/5151_bhps_w07_ukda_data_dictionary.pdf .
- `jbstat` coding for current activity: 1 self-employed, 2 in paid employment, 3 unemployed (as documented in the Understanding Society/BHPS-derived instruments). The code **never labels an employed-to-nonemployed transition a confirmed involuntary job loss**.

## Optional synthetic smoke test

If Rscript is already installed, you can run the deterministic **synthetic** test independently of private data:

```julia
ENV["FP_RSCRIPT"] = raw"C:\Users\hansakal\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe"
root = raw"C:\path\to\Financial_Pessimism"
test = joinpath(root, "05_Supplementary_Analyses", "Final_Empirical_Checks", "SELFTEST_FINAL_CHECKS.R")
run(`$(ENV["FP_RSCRIPT"]) --vanilla $test`)
```

The main Julia launcher already runs this smoke test automatically (unless `ENV["FP_FINAL_CHECKS_SKIP_SYNTHETIC"] = "yes"`). The test uses generated observations; it cannot validate codebook reconciliation or real-data coverage. **The main run's frozen-baseline gate is the critical check.**

## Files contained in the ZIP

- `RUN_FINAL_EMPIRICAL_CHECKS.jl` — Julia REPL entry point.
- `FINAL_EMPIRICAL_CHECKS.R` — staged empirical analysis.
- `FINAL_CHECKS_CORE.R` — independent R/fixest/survey covariance and reporting routines.
- `ONS_CPI_D7BT_annual_1990_2010.csv` — publicly sourced annual deflator.
- `SELFTEST_FINAL_CHECKS.R` — synthetic estimator smoke test.
- `FINAL_RESOURCES_REPAIR.R` — read-only raw-source income reconstruction and independent employment models.
- `README_FIRST.md` — this file.
