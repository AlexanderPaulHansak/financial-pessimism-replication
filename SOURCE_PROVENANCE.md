# Evidence and source provenance

**The four distinct verification lines must not be conflated.**

1. **Original archival Python source and its stored results.** The original source is the unmodified `canonical_original_20261016.zip`, which contains `analysis/prepare_pilot.py`, `analysis/checks/prepare_checks.py`, `complete_equivalence.py`, the two-way FE/PSU engine `check_stats.py`, robustness, transitions, attrition, and `analysis/checks/results/` aggregate files. Its `manifest.json` pins member-level SHA-256. The archive is copied verbatim; no source or result is silently corrected.
2. **Exact canonical Python replay (`20261016_140555`).** The portable Julia wrapper executes archived code and `verify_canonical_headline.py` on licensed local data, producing 21 matched comparisons across BHPS, UKHLS prospective, and UKHLS strict samples. The frozen BHPS sample has 104,848 interview pairs, 12,644 people, 1,511 PSUs and 122 strata. The replay stores model-ready respondent records only under the local UKDS data drive.
3. **Independent R verification (`20261016_144150`).** R/`fixest` independently fits the same canonical model-ready rows; its score covariance is stratified and clustered at PSU level, with independently computed absorbed-FE rank. All 21 point estimates and design SEs passed. This establishes computational equivalence of the estimators on a fixed sample, not independent validation of the data construction or of causal assumptions.
4. **Supplementary inference (`20261019_204702`).** The supplementary R code first re-estimated the nine BHPS headline contrasts and their design SEs on all frozen BHPS rows. It then examined real reported saving amounts (98,054 pairs), ongoing savers (30,296 pairs), gross personal/household resources (104,828 pairs), employment transitions (79,205 at risk), and age-band/continuous-age comparisons (104,848 pairs). All nine stages passed, but the *new* models have not been replicated independently in a second language.

**Additional branches:** Optimism `20261019_100019` reports nine contrasts on the same BHPS sample, with the original design. The separate forecast–realization diagnostic uses different controls and respondent-clustered inference and is explicitly exploratory. Questionnaires were source-page audited over 89 item–wave combinations; publication of metadata does not redistribute the instruments.

## Inferential contract

- Forecast categories: pessimistic (expects worse), optimistic (expects better), with unchanged as reference.
- Current saving and next-interview saving: separate outcomes on identical BHPS observations for the canonical contrast.
- Canonical regressions: weighted two-way FE, individual person and wave-by-actual-year time cells, original forecast controls; longitudinal endpoint weights normalized by source/forecast wave.
- Inference: strata-centered PSU estimating scores; survey reference degrees of freedom PSUs minus strata; finite-sample FE-rank correction.
- The original BHPS -9.34962 percentage-point timing contrast is a difference between **conditional slopes**, not a within-person probability of exiting saving.
- Income and employment measured after the forecast are not predetermined; conditioning on them is **descriptive**, not mediation. Gross personal and gross household income are **not** disposable household income.
- Respondent-level data are restricted and not contained in this archive.
