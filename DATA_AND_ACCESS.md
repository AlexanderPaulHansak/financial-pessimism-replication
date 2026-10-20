# Data and access

## Source study

**UK Data Service study 6614**: *Understanding Society: Waves 1–15, 2009–2024, and harmonised British Household Panel Survey: Waves 1–18, 1991–2009*, 21st edition. DOI: **10.5255/UKDA-SN-6614-22**. The paper used the accessible distribution's TAB data and official questionnaires. Researchers must register and satisfy the End User Licence terms before downloading the respondent-level data. The author cannot redistribute it.

UK Data Service catalogue: https://datacatalogue.ukdataservice.ac.uk/studies/study/6614

## Required licensed local files

The original verified author's machine used:

```text
C:\Hansak\Data\UKDA-6614-tab\tab\bhps\b[a-r]_indresp.tab
C:\Hansak\Data\UKDA-6614-tab\tab\bhps\b[a-r]_hhresp.tab
C:\Hansak\Data\UKDA-6614-tab\tab\ukhls\[a-o]_indresp.tab
C:\Hansak\Data\UKDA-6614-tab\mrdoc\ukda_data_dictionaries.zip
```

Some canonical scripts also use `indall`, roster and/or derived household files, as their source comments indicate. Check the source code and the supplied dataset's official dictionary for the exact versions before re-running.

## Private derived files (never publish)

```text
C:\Hansak\Data\UKHLS_derived\bhps_ukhls_cohort_long_raw.csv
C:\Hansak\Data\UKHLS_derived\pessimism_canonical_replay_v1\<run-tag>\private_model_ready_samples\*.csv
```

The upstream Julia script `11_bhps_ukhls_long_extract.jl` can create/overwrite the cohort file. The canonical Python replay builds private model-ready samples; both must stay on the non-cloud local data drive. Independent R and supplementary analyses read these samples, and archive **only aggregate outputs**.

## Survey questionnaire documentation

The release includes a page/variable crosswalk and source-page audit but **not** full copyrighted questionnaire PDFs. `questionnaire/QUESTIONNAIRE_WAVE_REGISTER.csv` and `questionnaire/QUESTIONNAIRE_SOURCE_AUDIT.csv` are documentation of the audit used in Appendix A.1, not a replacement for the source questionnaires. Source links and pages should be followed back to the official UKDS materials. The official text should not be treated as identically worded in every survey mode/wave.

## Excluded by design

No private TAB/DTA/SAV/Pickle/Parquet files, respondent-level CSVs, IDs, proprietary microdata, or questionnaires in full are distributed. Code that refers to `pidp`, `hidp`, or local paths is expected; including actual **records** would be a violation of the release contract.

## External public deflator

Supplementary saving-amount and income checks use UK ONS CPI annual D7BT (2015=100) observations in `code/supplementary_checks/ONS_CPI_D7BT_annual_1990_2010.csv`. The original citation is recorded in the paper, and the CPI values are public. Annual deflation is an approximation for interview-month data.
