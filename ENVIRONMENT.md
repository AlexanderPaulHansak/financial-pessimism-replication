# Software environment and repeatability

- **Original source:** Python >=3.9, `numpy`, `pandas`; see archived `README.txt` and archived `manifest.json`. The exact successful original Python versions are not pinned by this package.
- **Independent R audit:** successful author execution on R 4.6.1, `fixest` 0.14.2 and `data.table` 1.18.6.1. `R/Portable/VERIFY_CANONICAL_R_PORTABLE.R` is preserved unchanged.
- **Supplementary amount, resource and age checks:** R 4.6.1, `fixest` 0.14.2, `data.table` 1.18.6.1; Julia wrapper invokes the R script. Code contains a deterministic synthetic smoke test, but reproducing it does not substitute for licensed-data analysis.
- **Julia upstream builder:** Julia 1.11/1.12 with `CSV` and `DataFrames`; see shipped `code/julia_long_extract/Project.toml`.
- **Freeze builder/manifest verifier:** Python 3.9 or newer, **stdlib only**. Does not import econometric packages or read microdata.

The release retains archived source, tables and execution reports rather than pretending that every dependency is byte-for-byte pinned in a portable environment. Exact environmental reconstruction beyond the documented interpreter/package versions is not certified. For methodological interpretation, consult the Appendix F replication statement and `SOURCE_PROVENANCE.md`.
