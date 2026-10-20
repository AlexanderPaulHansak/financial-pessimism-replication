# Financial Pessimism and the Timing of Saving — replication materials

**Release series:** `Financial_Pessimism_Replication_v1.1.1`  
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

## Release v1.1.1: licensing clarification only

The research software and author-created documentation are distributed under
the **MIT License** (`LICENSE`), with third-party rights and licensed UKDS
microdata restrictions specified in `COPYRIGHT_AND_REUSE.md`. This corrects
v1.1.0's historical statement that a license had not been selected.

**No empirical analysis was modified.** The archived original Python ZIP, all
other executable source files, published aggregate results, questionnaire
metadata, appendix source snapshot, and verification code are byte-identical
to the successful v1.1.0 release. The earlier v1.1.0 release is retained for
provenance; `NAMING_AND_VERSION_CHANGE.md` documents that earlier migration.
No regressions were rerun for this licensing change.

The public code repository is:
https://github.com/AlexanderPaulHansak/financial-pessimism-replication

Licensed respondent-level data are not included. A permanent Zenodo DOI will
be added once this corrected version is published there. See
`REPRODUCE_FROM_UKDS.md` for the complete data and software requirements.

## What the final assembled ZIP contains

- `code/original_codex/` — original unchanged source/archive, including the archived Python estimation and robustness scripts.
- `code/canonical_replay/` and `code/julia_long_extract/` — sample reconstruction and the verification helper/launcher.
- `code/independent_R/` — independently implemented main estimator and design-based SEs.
- `code/supplementary_checks/`, `code/optimism/`, `code/realization_diagnostic/` — remaining appendix analyses.
- `aggregate_results/` — immutable successful output snapshots for all pipelines, including the exploratory diagnostic.
- `questionnaire/` — the source-page and wave audit records for the included paper.
- `LICENSE` and `COPYRIGHT_AND_REUSE.md` — MIT rights notice and third-party restrictions.
- `RELEASE_NOTES_v1.1.1.md` — auditable documentation-only change record.
- `TABLE_PROVENANCE.csv` — correspondence between main-text and appendix tables and files/estimators.
- `REPRODUCE_FROM_UKDS.md` — raw-data prerequisites, dependency conventions, exact commands, known path restrictions, and how to rerun.
- `SHA256_MANIFEST.csv` and `RELEASE_PROVENANCE.json` — immutable release integrity and evidence provenance.

### Verifying a finished public ZIP

On a machine with Python 3.9+, unpack the release, then run:

```text
python tools/VERIFY_AGGREGATES.py . --full
```

Run this **from inside the unpacked release folder**. `PASS` verifies the published aggregate evidence, internal original-archive hashes and the whole release manifest. It does **not** rerun econometric estimates; consult `REPRODUCE_FROM_UKDS.md` for the licensed-data analysis.

## Before publishing this release

- The public GitHub repository is available at
  https://github.com/AlexanderPaulHansak/financial-pessimism-replication .
- Upload this **v1.1.1** archive as a new GitHub Release asset and replace the
  older ZIP in the **unpublished** Zenodo draft. The first Zenodo public deposit
  should cite v1.1.1, not the superseded pre-licensing archive.
- Keep previous GitHub release v1.1.0 as part of the version history.
- Run `python tools/VERIFY_AGGREGATES.py . --full` on an extracted copy to
  recheck the exact source and aggregate evidence plus this release's manifest.
- The included `documentation/WP_appendix_FROZEN.tex` is an earlier manuscript
  snapshot; its version reference is **intentionally not edited** in this
  licensing-only release. Update Appendix F later during working-paper polish.
- After Zenodo publication, add the actual DOI to the GitHub repository and
  working-paper appendix (neither is claimed here).

Version **1.1.1** preserves the empirical record of the verified 16 and 19
October 2026 runs. Any subsequent empirical change requires a new version.
