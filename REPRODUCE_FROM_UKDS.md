# Reproduction instructions: licensed BHPS / UKHLS data

This document distinguishes verifying the **released results** (no licensed data) from *re-estimation* (licensed files required). These scripts have distinct origins, dates and designs; do not combine their estimates without noting the differences.

## A. Check archive integrity and published numerical evidence (no data)

Inside the assembled/unpacked `Financial_Pessimism_Replication_v1.1.1` folder, use:

```text
python tools/VERIFY_AGGREGATES.py . --full
```

Checks 21 original Python comparisons, 21 independent R comparisons, the nine exact BHPS supplement prechecks, all nine successful supplementary stages, 96 supplementary contrast rows, confidence-interval arithmetic, amount timing identities, original archive embedded hashes and all release file hashes. **This is NOT a statistical re-estimation.**

## B. Re-estimate the canonical main results on the author's validated directory layout

Prerequisites: Julia 1.11/1.12 with `CSV`/`DataFrames`; Python 3.9+ with `numpy`/`pandas`; R 4.6.1 with `data.table` 1.18.6.1 and `fixest` 0.14.2. These were the versions for the *successful independent R verification*; version pinning for the original Python dependencies was not fully recorded, so the current archive does not claim bitwise environment reproduction. Keep the same source data edition and survey-weight interpretation.

Project root for the author's run:

```julia
root = raw"C:\path\to\Financial_Pessimism"
```

**Step B1: Only if the original local derived longitudinal extract is missing.** This stage overwrites that *private local* derived file, so don't do it if the frozen copy already exists.

```julia
import Pkg
Pkg.activate(joinpath(root,"02_Canonical_Replication","Julia_Upstream"))
Pkg.instantiate()
include(joinpath(root,"02_Canonical_Replication","Julia_Upstream",
                 "scripts","empirics","11_bhps_ukhls_long_extract.jl"))
```

**Step B2: Replay the unchanged archived Python estimator and its exact-sample benchmark checks.** The portable Julia runner extracts the frozen Python ZIP under `C:\Hansak\Data\UKHLS_derived`, uses the unchanged analysis routines and an additive verification helper, and writes only aggregate output to the project tree. The replay creates a new run tag; do NOT overwrite the archived 16 October verification folder.

```julia
ENV["FP_PYTHON"] = raw"C:\path\to\python.exe"  # only if not autodetected
include(joinpath(root,"02_Canonical_Replication","Portable",
                 "RUN_CANONICAL_REPLAY_PORTABLE.jl"))
```

Check `04_Verified_Results/Canonical_Python_<run-tag>/CANONICAL_REPLAY_REPORT.md` for the actual PASS result. Static source verification alone does not certify the relocated portable launcher.

**Step B3: Independently verify the same canonical samples in R.** Pass the matching successful replay tag from B2. This uses independent two-way FE and a separately coded stratified-PSU sandwich.

```julia
ENV["FP_CANONICAL_REPLAY_TAG"] = "<new successful tag from B2>"
ENV["FP_RSCRIPT"] = raw"C:\Users\hansakal\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe"
include(joinpath(root,"03_Independent_R_Verification","Portable",
                 "RUN_CANONICAL_R_VERIFY_PORTABLE.jl"))
```

Check the new `Independent_R_<run-tag>/R_CANONICAL_VERIFICATION_REPORT.md` for **21/21 PASS**; do not infer this from a process exit alone.

## C. Supplementary saving amounts, incomes, employment and age profile

These analyses require the **frozen BHPS model-ready sample** and the original local cohort extract. If both files remain available, the benchmark replay does not need to be repeated. The R launcher first checks the nine canonical BHPS coefficients/SEs against the archived Python aggregates, before any extended model runs.

```julia
ENV["FP_CANONICAL_REPLAY_TAG"] = "20261016_140555"  # if using the verified original sample
include(joinpath(root,"05_Supplementary_Analyses","Final_Empirical_Checks",
                 "RUN_FINAL_EMPIRICAL_CHECKS.jl"))
```

Inspect all nine stages in the new `Results_<run-tag>/STAGE_STATUS.csv`, the coverage audit and the coefficients. Supplementary extensions are **not** independently implemented in Python; the benchmark regression check does not extend to those additional outcomes. The post-forecast adjustments are not causal mediation estimates. The original successful historical run is **`20261019_204702`**, supplied under `aggregate_results/supplementary_final_20261019_204702`.

## D. Canonical optimism and exploratory realization diagnostic

Canonical optimism uses the same private BHPS model-ready sample, under the `Canonical_Optimism_Tools/Portable` launcher:

```julia
ENV["FP_CANONICAL_REPLAY_TAG"] = "20261016_140555"
include(joinpath(root,"05_Supplementary_Analyses","Canonical_Optimism_Tools",
                 "Portable","RUN_OPTIMISM_PORTABLE.jl"))
```

The earlier realization diagnostic is **not** a canonical replay. To rerun, first activate the Julia upstream project with `CSV`, `DataFrames`, `Statistics` and `LinearAlgebra`, set `ENV["FP_PESSIMISM_OUTPUT"]` to a **non-respondent-level output folder** (its outputs include aggregate tables; review source before publishing), and run:

```julia
include(joinpath(root,"05_Supplementary_Analyses","Realization_Diagnostic",
                 "RUN_BHPS_FORECAST_REALIZATION_SAVING.jl"))
```

It uses *respondent-clustered* rather than design-stratified PSU inference, a nonidentical covariate specification, and retrospective subjective realizations. Those results are exploratory and should not be presented as independently verified versions of the canonical model.

## E. Third-party researchers and path portability

The **original Python archive** is supplied unchanged. Some original source files contain absolute Windows paths (such as `C:\Hansak\Data`) and require path-only edits in a *working copy* or an equivalent local alias when used by external researchers. Do not edit the frozen archived ZIP; keep a separate patch/diff of path substitutions. The R and supplementary launchers accept data-path environment variables including `FP_UK_DERIVED` and `FP_BHPS_TAB_ROOT`. The shipped code is therefore a documented archival reproduction, **not a one-click, operating-system-independent container**.

Keep all private files outside any publicly synchronized tree, including temporary caches. If recreating the canonical data from scratch, preserve study edition, interview-month eligibility, category codings, longitudinal weights, PSU/stratum matching, and repeated-person/two-way FE handling. A failure to match the original 21 coefficients **and** standard errors is a failed replication until diagnosed, not evidence that the source data are interchangeable.

## F. Output status and versioning

All reference aggregate files correspond to October 2026 runs. Do not overwrite them. New replications should have new tags and their own logs. Update the version number and SHA256 manifest before changing the appendix's frozen replication description. Once deposited in a public repository, record the stable location/DOI separately; none is represented as currently available.
