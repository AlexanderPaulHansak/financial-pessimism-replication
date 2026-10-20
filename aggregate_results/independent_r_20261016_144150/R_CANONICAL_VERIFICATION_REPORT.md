# Exact-canonical-sample independent R verification

**Status: PASS**

Canonical Python source run: `20261016_140555`
R  4.6.1 / fixest 0.14.2 / data.table 1.18.6.1
Models completed: 3 / 3; comparisons: 21 / 21
Largest absolute coefficient gap: 1.9359514e-13 percentage points
Largest absolute survey-SE gap: 3.409658e-10 percentage points
Prespecified coefficient tolerance: 0.001 pp; survey-SE tolerance: 0.003 pp

## Design verification
- The respondent-level inputs are the three exactly matched model-ready canonical CSVs on the local data drive.
- R/fixest estimates two-way weighted fixed effects independently of the original Python alternating-absorption algorithm.
- Stratified PSU covariance is computed from R residualized scores, using the canonical finite-sample correction and singleton-stratum convention.
- The FE dummy rank is calculated independently as a bipartite incidence-matrix rank.
- This establishes numerical cross-implementation agreement only if every reported check passes; it does not establish causality or survey design validity beyond the agreed convention.
- No person-level microdata are written into Dropbox. Only this report and aggregate summary tables are public.

## Model statuses
- BHPS_gross_published_lw: PASS
- UKHLS_gross_published_lw: PASS
- UKHLS_gross_timing_published_lw: PASS

