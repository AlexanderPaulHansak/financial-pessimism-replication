# Financial pessimism: final supplementary empirical checks

Run tag: `20261019_204702`
Source frozen canonical sample tag: `20261016_140555`

**Completed stages: 9; failed stages: 0.**

## Stage results

| Stage | Status | Seconds | Note |
|---|---|---:|---|
| 01_CANONICAL_PRECHECK | PASS | 3.6 | completed |
| 02_LOCAL_LONG_PANEL_JOIN | PASS | 0.6 | completed |
| 03A_RAW_BHPS_INCOME_JOIN | PASS | 5.4 | completed |
| 03B_GROSS_PERSONAL_INCOME | PASS | 6.4 | completed |
| 03C_GROSS_HOUSEHOLD_INCOME | PASS | 5.0 | completed |
| 03D_EMPLOYMENT_TRANSITIONS | PASS | 2.0 | completed |
| 04_MONTHLY_SAVING_AMOUNTS | PASS | 3.1 | completed |
| 05_AMOUNTS_CONTINUING_SAVERS | PASS | 0.5 | completed |
| 06_AGE_HETEROGENEITY | PASS | 6.2 | completed |

## Files

- `REGRESSION_CONTRASTS.csv`: estimates, stratified-PSU SEs, confidence intervals and sample sizes.
- `COVERAGE_AUDIT.csv`: aggregate availability and missing-data audits.
- `RESOURCE_SOURCE_AUDIT.csv`: wave-by-wave source-column and gross-income coverage checks (v1.1).
- `HETEROGENEITY_TESTS.csv`: age-split Wald tests, if estimated.
- `BASELINE_CANONICAL_REPLICATION.csv`: preflight comparison to the frozen Python regression.
- `STAGE_STATUS.csv`: stage-specific pass/fail status.

## Interpretation and limitations

- Every new result is exploratory. All benchmark regressions use exact canonical observation rows and covariates *before* selecting the corresponding new-outcome sample.
- Restricted-sample benchmark and enriched regressions share the same respondents, weights and original RHS; they are descriptive comparisons, NOT causal mediation analyses.
- Employment outcomes are transitions between two self-reported economic-activity categories, NOT dated involuntary layoffs or verified job loss.
- The original extensive-margin regression remains the paper's frozen main result. New amount regressions are based on respondents with valid amounts at both interviews and are potentially selected.
- `saved_monthly` is an amount reported by current savers in the upstream extract; explicit non-savers are coded zero, while top-coded/invalid and missing amounts remain unavailable.
- Saving amounts and newly extracted gross personal/household incomes are converted to approximate 2015-GBP using annual UK CPI (ONS D7BT). Annual indices are a coarse price adjustment for interview-month data.
- The original upstream personal_net_income column was empty for historical BHPS; resource estimates use explicitly labelled gross (not net/disposable) income from local official TAB files.
- No person-level records were written to the project folder or to this results directory.
- Source: ONS Consumer Price Inflation time series, D7BT (all-items CPI, 2015=100), https://www.ons.gov.uk/economy/inflationandpriceindices/timeseries/d7bt

