# Financial Pessimism and the Timing of Saving — replication materials

**Release series:** `Financial_Pessimism_Replication_v1.1.0`  
**Paper:** *Financial Pessimism and the Timing of Saving* — combined working paper with Appendix A–F  
**Investigator:** Alexander Hansak (University of Graz)  
**Evidence cut-off:** 19 October 2026. Packaging prepared 20 October 2026.  
**Distribution state:** archival preparation. **No DOI or public repository is claimed.**

## What is reproduced, and how strong is the evidence?

| Component | Verified run | Assessment |
|---|---|---|
| BHPS and UKHLS headline results | Python `20261016_140555` | Original estimator replay, 21 coefficient/SE checks PASS |
| Same samples, independent estimator | R/`fixest` `20261016_144150` | Independent implementation and stratified-PSU sandwich, 21/21 PASS |
| BHPS optimistic-forecast coefficients | `20261019_100019` | Re-estimated on frozen BHPS sample, nine reported contrasts |
| Saving amounts, income, employment, ages | R `20261019_204702` | Nine supplementary stages PASS; nine BHPS coefficient/SE prechecks PASS; **not** independently cross-implemented |
| Forecast–realization diagnostic | Earlier exploratory Julia run | Different controls and respondent-clustered inference; **not** comparable to the canonical inference standard |
| Questionnaire source mapping | 89 item–wave audit | Audited PDF-page register; original questionnaire PDFs not redistributed |

**Crucial distinction:** An exact numerical match across estimators checks computation under the agreed model specification; it cannot establish causal identification, survey-design validity, or the correctness of respondents' answers. The post-forecast income-adjusted models are **descriptive**, not mediation estimates.

## What changed in this naming-only release

This is the complete, assembled version 1.1.0 of the replication archive. It is made from the verified version 1.0.0 with cleaner active code interfaces and a neutral display name for the original source ZIP. The original Python source ZIP is *byte-for-byte unchanged*. All regression tables, questionnaire registers, and verification aggregates are identical to the certified earlier release.

The old release is retained for archival integrity. The local migration script performs the complete evidence and file-integrity checks before it creates this version.

**Licensed respondent-level data are not included.** No regression is rerun by the naming change; see `REPRODUCE_FROM_UKDS.md` for the complete model execution path.

## What the final assembled ZIP contains

- `code/original_codex/` — original unchanged source/archive, including the archived Python estimation and robustness scripts.
- `code/canonical_replay/` and `code/julia_long_extract/` — sample reconstruction and the verification helper/launcher.
- `code/independent_R/` — independently implemented main estimator and design-based SEs.
- `code/supplementary_checks/`, `code/optimism/`, `code/realization_diagnostic/` — remaining appendix analyses.
- `aggregate_results/` — immutable successful output snapshots for all pipelines, including the exploratory diagnostic.
- `questionnaire/` — the source-page and wave audit records for the included paper.
- `TABLE_PROVENANCE.csv` — correspondence between main-text and appendix tables and files/estimators.
- `REPRODUCE_FROM_UKDS.md` — raw-data prerequisites, dependency conventions, exact commands, known path restrictions, and how to rerun.
- `SHA256_MANIFEST.csv` and `RELEASE_PROVENANCE.json` — immutable release integrity and evidence provenance.

### Verifying a finished public ZIP

On a machine with Python 3.9+, unpack the release, then run:

```text
python tools/VERIFY_AGGREGATES.py . --full
```

Run this **from inside the unpacked release folder**. `PASS` verifies the published aggregate evidence, internal original-archive hashes and the whole release manifest. It does **not** rerun econometric estimates; consult `REPRODUCE_FROM_UKDS.md` for the licensed-data analysis.

## Before a public deposit

- Verify the assembled release with `python tools/VERIFY_AGGREGATES.py . --full`. The naming-only release was assembled after the earlier successful Windows results, without re-estimation.
- Confirm that the latest Overleaf Appendix F matches the included `documentation/WP_appendix_FROZEN.tex`.
- Choose a public repository and select code/documentation reuse terms. **No open-source license or public DOI is presumed.**
- Deposit only the verified public-code/archive ZIP; record its exact SHA-256 and stable URL/DOI in the paper after deposit.

The frozen v1.1.0 package refers only to the observed 16 and 19 October 2026 runs. Future analyses, if any, should receive a new version, with a separate manifest and updated Appendix F.
