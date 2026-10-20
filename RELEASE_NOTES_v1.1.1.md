# Replication release v1.1.1 — licensing correction

**20 October 2026 · documentation-only update**

## Why this version exists

Release v1.1.0 was created before the author chose a reuse license. It
therefore contained an outdated rights statement. Version **1.1.1** adds the
author's MIT license and makes the wording inside the ZIP consistent with the
license selected on GitHub and for the forthcoming Zenodo deposit.

## Files added

- `LICENSE` — full MIT License, copyright 2026 Alexander Hansak.
- `RELEASE_NOTES_v1.1.1.md` — this change record.

## Files updated

- `COPYRIGHT_AND_REUSE.md` — distinguishes author-owned code/documentation from
  licensed UKDS data and other third-party materials.
- `CITATION.cff` — version 1.1.1, MIT metadata and repository URL.
- `README_START_HERE.md` — current release, licensing and deposit instructions.
- `REPRODUCE_FROM_UKDS.md` — folder name for v1.1.1.
- `RELEASE_PROVENANCE.json` — record of this documentation-only successor.
- `SHA256_MANIFEST.csv` — refreshed file sizes and SHA-256 hashes.

## Explicitly unchanged

- All `code/` files, including the original archived Python ZIP.
- All `aggregate_results/` data and numerical verification reports.
- All `questionnaire/` audit metadata.
- The numerical checker `tools/VERIFY_AGGREGATES.py`.
- The historical appendix source under `documentation/`, pending later
  manuscript revision as requested by the author.
- The historical naming migration memo `NAMING_AND_VERSION_CHANGE.md`.

No regressions were rerun. The validated empirical and questionnaire records
remain unchanged. Earlier release **v1.1.0** is preserved in the publication
history.

## Parent release

`Financial_Pessimism_Replication_v1.1.0.zip`  
SHA-256: `8a17dc52632a261eec25b757b2c65b7687438daf3c31793bfa4d867b9c2db15e`

## Public repository

https://github.com/AlexanderPaulHansak/financial-pessimism-replication

No Zenodo DOI is assigned or claimed in this version's metadata before the
corrected deposit is actually published.
