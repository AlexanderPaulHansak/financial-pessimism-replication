# FINANCIAL PESSIMISM -- FINAL EMPIRICAL CHECKS v1.0
# Run through RUN_FINAL_EMPIRICAL_CHECKS.jl (standard Windows/Julia entry point).
# INPUTS: frozen canonical model-ready BHPS CSV + original local long extract.
# NO canonical scripts or existing files are modified.
# ALL licensed row-level data remain in memory, or on C:/Hansak/Data only.
# ONLY aggregate results are written under project/05_Supplementary_Analyses/Final_Empirical_Checks.

checks_dir <- Sys.getenv("FP_FINAL_CHECKS_DIR", unset = getwd())
source(file.path(checks_dir, "FINAL_CHECKS_CORE.R"), local = TRUE)

project <- Sys.getenv("FP_PROJECT_ROOT", unset = normalizePath(file.path(checks_dir, "..", ".."), mustWork = FALSE))
local_root <- Sys.getenv("FP_UK_DERIVED", unset = "C:/Hansak/Data/UKHLS_derived")
source_tag <- Sys.getenv("FP_CANONICAL_REPLAY_TAG", unset = "20261016_140555")
run_tag <- Sys.getenv("FP_FINAL_CHECKS_TAG", unset = format(Sys.time(), "%Y%m%d_%H%M%S"))
fp_assert(grepl("^[A-Za-z0-9_-]+$", source_tag) && grepl("^[A-Za-z0-9_-]+$", run_tag),
          "Unsafe source or result run tag")
fp_screen_private(local_root)

private <- file.path(local_root, "pessimism_canonical_replay_v1", source_tag,
                     "private_model_ready_samples")
sample_file <- file.path(private, "BHPS_CANONICAL_SAMPLE_LOCAL.csv")
long_file <- file.path(local_root, "bhps_ukhls_cohort_long_raw.csv")
reference_dir <- file.path(project, "04_Verified_Results", paste0("Canonical_Python_", source_tag))
ref_results_file <- file.path(reference_dir, "CANONICAL_REPLAY_COEFFICIENT_COMPARISON.csv")
ref_samples_file <- file.path(reference_dir, "CANONICAL_REPLAY_SAMPLE_SUMMARY.csv")
outdir <- file.path(project, "05_Supplementary_Analyses", "Final_Empirical_Checks", paste0("Results_", run_tag))
fp_assert(!dir.exists(outdir) || !length(list.files(outdir, all.files=TRUE, no..=TRUE)),
          "Result folder already contains files: use a new FP_FINAL_CHECKS_TAG")
dir.create(outdir, recursive=TRUE, showWarnings=FALSE)
fp_assert(dir.exists(outdir), "Cannot create aggregate results folder")

store <- fp_new_store()
stages <- data.table(stage=character(), status=character(), elapsed_seconds=numeric(), note=character())
original_rhs <- NULL
baseline <- NULL
joined <- NULL

NON_RHS <- c("pidp", "timecell", "source", "wave", "psu", "strata", "w_fit",
             "next_published_pair_weight", "next_published_trip_weight",
             "save", "next_save", "next_minus_current", "previous_save", "next_minus_previous")
EXPECTED <- "BHPS_gross_published_lw"

fp_log(strrep("=", 95))
fp_log("FINAL CHECKS | immutable canonical baseline: ", source_tag)
fp_log("PROJECT: ", project)
fp_log("Private files are READ-ONLY and never exported to Dropbox")
fp_log("AGGREGATE output folder: ", outdir)
fp_log("R ", as.character(getRversion()), "; fixest ", as.character(packageVersion("fixest")),
       "; data.table ", as.character(packageVersion("data.table")))
fp_log(strrep("=", 95))

fp_report <- function() {
  fp_write_store(store, outdir)
  fwrite(stages, file.path(outdir, "STAGE_STATUS.csv"))
  n_ok <- sum(stages$status == "PASS")
  n_fail <- sum(stages$status == "FAILED")
  lines <- c(
    "# Financial pessimism: final supplementary empirical checks",
    "",
    paste0("Run tag: `",run_tag,"`"),
    paste0("Source frozen canonical sample tag: `",source_tag,"`"),
    "",
    paste0("**Completed stages: ",n_ok,"; failed stages: ",n_fail,".**"),
    "",
    "## Stage results",
    "",
    "| Stage | Status | Seconds | Note |",
    "|---|---|---:|---|"
  )
  if (nrow(stages)) for (i in seq_len(nrow(stages))) {
    r <- stages[i]
    lines <- c(lines, sprintf("| %s | %s | %.1f | %s |",
                               r$stage, r$status, r$elapsed_seconds, r$note))
  }
  lines <- c(lines, "", "## Files", "",
             "- `REGRESSION_CONTRASTS.csv`: estimates, stratified-PSU SEs, confidence intervals and sample sizes.",
             "- `COVERAGE_AUDIT.csv`: aggregate availability and missing-data audits.",
             "- `RESOURCE_SOURCE_AUDIT.csv`: wave-by-wave source-column and gross-income coverage checks (v1.1).",
             "- `HETEROGENEITY_TESTS.csv`: age-split Wald tests, if estimated.",
             "- `BASELINE_CANONICAL_REPLICATION.csv`: preflight comparison to the frozen Python regression.",
             "- `STAGE_STATUS.csv`: stage-specific pass/fail status.",
             "",
             "## Interpretation and limitations", "",
             "- Every new result is exploratory. All benchmark regressions use exact canonical observation rows and covariates *before* selecting the corresponding new-outcome sample.",
             "- Restricted-sample benchmark and enriched regressions share the same respondents, weights and original RHS; they are descriptive comparisons, NOT causal mediation analyses.",
             "- Employment outcomes are transitions between two self-reported economic-activity categories, NOT dated involuntary layoffs or verified job loss.",
             "- The original extensive-margin regression remains the paper's frozen main result. New amount regressions are based on respondents with valid amounts at both interviews and are potentially selected.",
             "- `saved_monthly` is an amount reported by current savers in the upstream extract; explicit non-savers are coded zero, while top-coded/invalid and missing amounts remain unavailable.",
             "- Saving amounts and newly extracted gross personal/household incomes are converted to approximate 2015-GBP using annual UK CPI (ONS D7BT). Annual indices are a coarse price adjustment for interview-month data.",
             "- The original upstream personal_net_income column was empty for historical BHPS; resource estimates use explicitly labelled gross (not net/disposable) income from local official TAB files.",
             "- No person-level records were written to the project folder or to this results directory.",
             "- Source: ONS Consumer Price Inflation time series, D7BT (all-items CPI, 2015=100), https://www.ons.gov.uk/economy/inflationandpriceindices/timeseries/d7bt",
             "")
  writeLines(lines, file.path(outdir, "FINAL_CHECKS_REPORT.md"), useBytes=TRUE)
}

fp_stage <- function(name, fn) {
  fp_log("\n", strrep("-", 92))
  fp_log("START: ", name)
  t0 <- Sys.time()
  # A failed exploratory stage must never leave partial estimates in an aggregate CSV.
  n_est <- length(store$estimates)
  n_cov <- length(store$coverage)
  n_test <- length(store$tests)
  ok <- TRUE
  val <- tryCatch(fn(), error = function(e) {
    fp_log("ERROR ", name, ": ", conditionMessage(e))
    ok <<- FALSE
    NULL
  })
  if (!ok) {
    length(store$estimates) <- n_est
    length(store$coverage) <- n_cov
    length(store$tests) <- n_test
  }
  dt <- as.numeric(difftime(Sys.time(), t0, units="secs"))
  stages <<- rbind(stages, data.table(stage=name, status=if (ok) "PASS" else "FAILED",
                                        elapsed_seconds=dt, note=if (ok) "completed" else "see console"))
  fp_report()
  fp_log(if (ok) "PASS: " else "FAILED: ", name, " (",round(dt,1)," seconds)")
  if (ok) val else NULL
}

# -----------------------------------------------------------------------------
# GATE: independently re-estimate the 9 published BHPS contrasts and SEs first.
# ----------------------------------------------------------------------------
fp_stage("01_CANONICAL_PRECHECK", function() {
  needed_files <- c(sample_file, ref_results_file, ref_samples_file)
  fp_assert(all(file.exists(needed_files)),
            "Missing canonical input/reference: run/read portable canonical replay first")
  fp_log("Read frozen model-ready BHPS sample")
  d <- fread(sample_file, showProgress=FALSE, integer64="character",
             colClasses=list(character=c("pidp", "timecell", "strata", "psu")))
  d[, pidp := fp_safe_id(pidp)]
  for (v in c("pidp", "timecell", "strata", "psu")) set(d, j=v, value=as.character(d[[v]]))
  d[, wave := as.integer(wave)]
  fp_assert(all(d$source == "BHPS"), "The frozen sample is not exclusively BHPS")
  fp_assert(!anyDuplicated(d, by=c("pidp", "source", "wave")), "Duplicated canonical individual/wave key")
  fp_assert(all(is.finite(d$w_fit) & d$w_fit > 0), "Invalid canonical weights")
  fp_assert(abs(mean(d$w_fit)-1) < 1e-8, "Canonical weight normalization changed")
  ref <- fread(ref_results_file, showProgress=FALSE)
  refsum <- fread(ref_samples_file, showProgress=FALSE)
  fp_assert(!anyDuplicated(ref[,.(model,outcome,contrast)]), "Duplicate reference contrast keys")
  fp_assert(!anyDuplicated(refsum$model), "Duplicate reference sample keys")
  s <- refsum[model == EXPECTED]
  fp_assert(nrow(s) == 1L, "Frozen BHPS model name missing in sample summary")
  fp_assert(nrow(d) == s$N && uniqueN(d$pidp) == s$people,
            "Model-ready BHPS sample differs from frozen baseline")
  rhs <- setdiff(names(d), NON_RHS)
  fp_assert(all(c("pess", "optim", "pess_young", "optim_young") %in% rhs),
            "Missing canonical pessimism/optimism indicators")
  npsu <- uniqueN(paste(d$strata, d$psu, sep="__PSU__"))
  fp_assert(npsu == s$psus && uniqueN(d$strata) == s$strata,
            "Survey PSU/strata counts changed")
  rank <- fp_fe_rank(d$pidp, d$timecell)
  comparisons <- list()
  fits <- list()
  for (outcome in c("save", "next_save", "next_minus_current")) {
    model <- fp_fit(d, outcome, rhs, rank)
    fp_assert(length(coef(model$fit)) == s$n_terms, "Canonical fitted term count differs")
    fits[[outcome]] <- model
    fp_add_three(store, "01_CANONICAL_PRECHECK", "frozen_identical_rows", outcome, model)
    for (nm in names(fp_standard_weights("pess"))) {
      z <- fp_linear_contrast(model, fp_standard_weights("pess")[[nm]])
      # Avoid data.table column/scalar scoping ambiguity by ordinary vector indices.
      idx <- which(ref[["model"]] == EXPECTED & ref[["outcome"]] == outcome &
                   ref[["contrast"]] == nm)
      fp_assert(length(idx) == 1L, "Reference estimate is not uniquely identified")
      rr <- ref[idx]
      diff_pp <- 100 * (unname(z["estimate"]) - rr$ref_effect)
      diff_se_pp <- 100 * (unname(z["se"]) - rr$ref_se)
      pass <- abs(diff_pp) <= 0.001 && abs(diff_se_pp) <= 0.003
      comparisons[[length(comparisons)+1L]] <- data.table(
        model=EXPECTED, outcome=outcome, contrast=nm,
        N=nrow(d), people=uniqueN(d$pidp), psus=model$design$psus,
        strata=model$design$strata,
        calculated_pp=100*unname(z["estimate"]), frozen_pp=100*rr$ref_effect,
        difference_pp=diff_pp,
        calculated_SE_pp=100*unname(z["se"]), frozen_SE_pp=100*rr$ref_se,
        difference_SE_pp=diff_se_pp, pass=pass)
      fp_log("  CHECK ",outcome," / ",nm,": ",sprintf("%.5f",100*z["estimate"]),
             " pp (ref ",sprintf("%.5f",100*rr$ref_effect),"); SE delta=",
             sprintf("%.3g",diff_se_pp)," pp | ",if (pass) "OK" else "MISMATCH")
    }
  }
  for (t in c("pess", "optim", "pess_young", "optim_young")) {
    beta0 <- coef(fits[["save"]]$fit)[[t]]
    beta1 <- coef(fits[["next_save"]]$fit)[[t]]
    betad <- coef(fits[["next_minus_current"]]$fit)[[t]]
    fp_assert(abs(betad-(beta1-beta0)) < 1e-7, "Canonical timing identity failed")
  }
  checks <- rbindlist(comparisons)
  fwrite(checks, file.path(outdir, "BASELINE_CANONICAL_REPLICATION.csv"))
  fp_assert(nrow(checks) == 9L && all(checks$pass),
            "FROZEN CANONICAL CHECK FAILED: all subsequent analyses have been blocked")
  fp_log("Frozen baseline VERIFIED: N=",nrow(d)," people=",uniqueN(d$pidp),
         " PSU=",npsu," strata=",uniqueN(d$strata))
  baseline <<- d
  original_rhs <<- rhs
  rm(ref,refsum,fits,checks)
  invisible(gc(verbose=FALSE))
  TRUE
})

if (is.null(baseline)) {
  fp_log("STOP: frozen canonical gate failed; no new coefficients can be trusted.")
  quit(save="no", status=2L)
}

# -----------------------------------------------------------------------------
# Add the authoritative upstream *local* cohort data (no re-extraction).
# Validate both observed saving outcomes EXACTLY match canonical values.
# -----------------------------------------------------------------------------
fp_stage("02_LOCAL_LONG_PANEL_JOIN", function() {
  fp_assert(file.exists(long_file),
            "Local cohort extract missing: run the existing Julia_Upstream/11_bhps_ukhls_long_extract.jl only if necessary")
  fp_log("Read existing private longitudinal extract (selected columns only)")
  cols <- c("pidp","source","wave","interview_year","age","save",
            "saved_monthly","personal_net_income","employment_status")
  header <- names(fread(long_file, nrows=0, showProgress=FALSE))
  fp_assert(all(cols %in% header),
            paste("Missing columns from canonical upstream cohort extract:", paste(setdiff(cols,header),collapse=", ")))
  long <- fread(long_file, select=cols, showProgress=FALSE, integer64="character",
                colClasses=list(character="pidp"))
  long <- long[source == "BHPS" & wave >= 1L & wave <= 18L]
  long[, pidp := fp_safe_id(pidp)]
  long[, wave := as.integer(wave)]
  fp_assert(nrow(long) > nrow(baseline), "BHPS cohort source unexpectedly small")
  fp_assert(!anyDuplicated(long, by=c("pidp","wave")),
            "Duplicate individual-wave in the upstream BHPS long extract")
  for (v in setdiff(cols,c("pidp","source","wave"))) {
    set(long,j=v,value=suppressWarnings(as.numeric(long[[v]])))
  }
  current <- long[, .(pidp,wave,cohort_age=age,year_t=interview_year,
                      cohort_save_t=save,amt_t=saved_monthly,
                      income_t=personal_net_income,job_t=employment_status)]
  followup <- long[, .(pidp,wave=wave-1L,year_t1=interview_year,
                   cohort_save_t1=save,amt_t1=saved_monthly,
                   income_t1=personal_net_income,job_t1=employment_status)]
  d <- merge(baseline, current, by=c("pidp","wave"),all.x=TRUE,sort=FALSE)
  d <- merge(d, followup, by=c("pidp","wave"),all.x=TRUE,sort=FALSE)
  fp_assert(nrow(d) == nrow(baseline), "Joining cohort data changed the canonical sample size")
  fp_assert(all(!is.na(d$cohort_save_t) & !is.na(d$cohort_save_t1)),
            "Missing cohort-saving matches at one or both interviews")
  fp_assert(all(abs(d$cohort_save_t-d$save)<1e-8) &&
            all(abs(d$cohort_save_t1-d$next_save)<1e-8),
            "Upstream matched saving status differs from frozen canonical saving status")
  fp_assert(all(is.finite(d$cohort_age) & d$cohort_age >= 18 & d$cohort_age <= 59),
            "Upstream age is incomplete or outside canonical 18-59 range")
  young <- as.numeric(d$cohort_age <= 34)
  fp_assert(all(abs(d$pess_young - d$pess*young)<1e-7) &&
            all(abs(d$optim_young-d$optim*young)<1e-7),
            "Age cutoff mapping differs from frozen canonical interactions")
  for (nm in c("saved_monthly", "personal_net_income", "employment_status")) {
    for (suffix in c("t","t1")) {
      vv <- switch(nm,
                   saved_monthly = if (suffix=="t") d$amt_t else d$amt_t1,
                   personal_net_income = if (suffix=="t") d$income_t else d$income_t1,
                   employment_status = if (suffix=="t") d$job_t else d$job_t1)
      fp_add_coverage(store, "02_LOCAL_LONG_PANEL_JOIN",paste(nm,suffix,sep="_"),"ALL",
                      nrow(d),sum(is.finite(vv)),sum(d$w_fit[is.finite(vv)])/sum(d$w_fit))
    }
  }
  joined <<- d
  fp_log("Joined private panel to ALL ",nrow(d)," frozen canonical observations; saving and age mapping PASS")
  rm(d,current,followup,long)
  invisible(gc(verbose=FALSE))
  TRUE
})

# -----------------------------------------------------------------------------
# PUBLIC annual CPI from ONS D7BT; no auto-download or extrapolation.
# -----------------------------------------------------------------------------
fp_cpi <- fread(file.path(checks_dir,"ONS_CPI_D7BT_annual_1990_2010.csv"),showProgress=FALSE)
fp_assert(all(c("year","cpi_2015_100") %in% names(fp_cpi)), "CPI file schema changed")
fp_assert(!anyDuplicated(fp_cpi$year) && all(fp_cpi$cpi_2015_100>0), "Invalid CPI observations")
fp_real_2015 <- function(nominal, year) {
  cpi <- fp_cpi$cpi_2015_100[match(as.integer(year),fp_cpi$year)]
  ans <- nominal * 100/cpi
  ans[!is.finite(ans)] <- NA_real_
  ans
}
fp_income_clean <- function(x) {
  x <- as.numeric(x)
  # Original upstream raw extractor preserves some numeric special-missing codes.
  x[x %in% c(-1,-2,-3,-4,-5,-6,-7,-8,-9)] <- NA_real_
  x[!is.finite(x) | abs(x) > 1e8] <- NA_real_
  x
}
fp_job_clean <- function(x) {
  x <- suppressWarnings(as.integer(x))
  x[!(x %in% c(1L:15L,97L))] <- NA_integer_
  x
}
fp_amount_clean <- function(x, savestatus) {
  x <- as.numeric(x)
  x[!is.finite(x) | x < 0] <- NA_real_
  # BHPS SAVED has a 9997-or-above topcode in its public data dictionary.
  # Do not mistake 9997 for an exact observed monthly saving amount.
  x[x >= 9997] <- NA_real_
  x[!is.na(savestatus) & savestatus == 0] <- 0
  x
}
fp_coverage_groups <- function(d, flag, measure, stage) {
  for (g in c("young_pess", "young_unchanged", "older_pess", "older_unchanged",
              "young_optim", "older_optim", "all")) {
    a <- switch(g,
      young_pess= d$cohort_age<=34 & d$pess==1,
      young_unchanged=d$cohort_age<=34 & d$pess==0 & d$optim==0,
      older_pess=d$cohort_age>=35 & d$pess==1,
      older_unchanged=d$cohort_age>=35 & d$pess==0 & d$optim==0,
      young_optim=d$cohort_age<=34 & d$optim==1,
      older_optim=d$cohort_age>=35 & d$optim==1,
      all=rep(TRUE,nrow(d)))
    a[is.na(a)] <- FALSE
    n <- sum(a)
    nv <- sum(a & flag)
    # Aggregate disclosure safeguard: suppress detailed cells < 30 observations.
    if (n < 30L) next
    ww <- d$w_fit[a]
    pct <- if (sum(ww)>0) sum(d$w_fit[a & flag])/sum(ww) else NA_real_
    fp_add_coverage(store,stage,measure,g,n,nv,pct)
  }
}

# -----------------------------------------------------------------------------
# CHECK 1 (v1.1): independently reconstruct observed BHPS gross incomes from
# official local TAB files; estimate resources and employment in separate stages.
# Original cohort personal_net_income column is wholly empty for historical BHPS.
# -----------------------------------------------------------------------------
source(file.path(checks_dir, "FINAL_RESOURCES_REPAIR.R"), local = TRUE)

# -----------------------------------------------------------------------------
# CHECK 2: real monthly saving amounts, zero for explicit non-savers.
# 9997 top-code and invalid reported amounts are missing, NOT zero.
# -----------------------------------------------------------------------------
fp_stage("04_MONTHLY_SAVING_AMOUNTS", function() {
  fp_assert(!is.null(joined), "Canonical/long extract join unavailable")
  d <- copy(joined)
  d[, a_t := fp_amount_clean(amt_t,cohort_save_t)]
  d[, a_t1 := fp_amount_clean(amt_t1,cohort_save_t1)]
  d[, amount_real_t := fp_real_2015(a_t,year_t)]
  d[, amount_real_t1 := fp_real_2015(a_t1,year_t1)]
  valid <- is.finite(d$amount_real_t) & is.finite(d$amount_real_t1)
  fp_coverage_groups(d,valid,"saving_amount_both_waves","04_MONTHLY_SAVING_AMOUNTS")
  fp_coverage_groups(d,is.finite(d$amount_real_t),"saving_amount_at_forecast","04_MONTHLY_SAVING_AMOUNTS")
  fp_coverage_groups(d,is.finite(d$amount_real_t1),"saving_amount_at_followup","04_MONTHLY_SAVING_AMOUNTS")
  # Missing reported amounts conditional on an affirmative saving report.
  for (which_wave in c("t","t1")) {
    sav <- if (which_wave=="t") d$cohort_save_t else d$cohort_save_t1
    amt <- if (which_wave=="t") d$amount_real_t else d$amount_real_t1
    ii <- sav==1
    fp_add_coverage(store,"04_MONTHLY_SAVING_AMOUNTS",
                    paste0("amount_reported_among_savers_",which_wave),"ALL",
                    sum(ii),sum(ii & is.finite(amt)),
                    if (sum(d$w_fit[ii])>0) sum(d$w_fit[ii & is.finite(amt)])/sum(d$w_fit[ii]) else NA_real_)
  }
  sub <- d[valid]
  fp_assert(nrow(sub)>2500 && uniqueN(sub$pidp)>500, "Too few observed monthly saving-amount pairs")
  fp_log("Complete amount pairs: ",nrow(sub)," from ",uniqueN(sub$pidp)," respondents")
  # IHS/100: interpretable intensity scale (100 real GBP = one unit). Not log(1+x) percentages.
  sub[, amt_ihs_t := asinh(amount_real_t/100)]
  sub[, amt_ihs_t1 := asinh(amount_real_t1/100)]
  sub[, amt_ihs_change := amt_ihs_t1-amt_ihs_t]
  rank <- fp_fe_rank(sub$pidp, sub$timecell)
  m <- list()
  for (y in c("amt_ihs_t","amt_ihs_t1","amt_ihs_change")) {
    m[[y]] <- fp_fit(sub,y,original_rhs,rank)
    fp_add_three(store,"04_MONTHLY_SAVING_AMOUNTS","exact_same_amount_valid_pairs",y,m[[y]],
                 scale="asinh(real monthly GBP/100)")
  }
  for (term in c("pess","optim","pess_young","optim_young")) {
    gap <- coef(m[["amt_ihs_change"]]$fit)[[term]] -
           (coef(m[["amt_ihs_t1"]]$fit)[[term]]-coef(m[["amt_ihs_t"]]$fit)[[term]])
    fp_assert(abs(gap)<1e-7, paste("Amount outcome timing identity failed for",term))
  }
  fp_log("Saving-amount intensity timing identity PASS")
  invisible(gc(verbose=FALSE))
  TRUE
})

fp_stage("05_AMOUNTS_CONTINUING_SAVERS", function() {
  fp_assert(!is.null(joined), "Canonical/long extract join unavailable")
  d <- copy(joined)
  d[, a_t := fp_amount_clean(amt_t,cohort_save_t)]
  d[, a_t1 := fp_amount_clean(amt_t1,cohort_save_t1)]
  d[, r_t := fp_real_2015(a_t,year_t)]
  d[, r_t1 := fp_real_2015(a_t1,year_t1)]
  ii <- d$save==1 & d$next_save==1 & is.finite(d$r_t) & is.finite(d$r_t1) &
        d$r_t>0 & d$r_t1>0
  fp_coverage_groups(d,ii,"positive_amount_continuing_savers","05_AMOUNTS_CONTINUING_SAVERS")
  sub <- d[ii]
  fp_assert(nrow(sub)>2500 && uniqueN(sub$pidp)>500, "Insufficient continuing-saver amount pairs")
  sub[, log_saving_change := log(r_t1)-log(r_t)]
  rank <- fp_fe_rank(sub$pidp,sub$timecell)
  model <- fp_fit(sub,"log_saving_change",original_rhs,rank)
  fp_add_three(store,"05_AMOUNTS_CONTINUING_SAVERS","selected_savers_only", "log_saving_change",model,
               scale="change in log monthly amount",
               note="Selected on saving at both interviews; not an unconditional amount effect")
  TRUE
})

# -----------------------------------------------------------------------------
# CHECK 3: age heterogeneity with survey-design CI, same frozen sample.
# Within-original-age-group departures (18-24 vs 25-34, 35-44 vs 45-59),
# plus a separate continuous interaction model as robustness.
# -----------------------------------------------------------------------------
fp_stage("06_AGE_HETEROGENEITY", function() {
  fp_assert(!is.null(joined), "Canonical/long extract join unavailable")
  d <- copy(joined)
  a <- d$cohort_age
  fp_assert(all(is.finite(a) & a >= 18 & a <= 59), "Age not valid on every canonical row")
  d[, pess_age18_24 := pess*as.numeric(cohort_age<=24)]
  d[, pess_age35_44 := pess*as.numeric(cohort_age>=35 & cohort_age<=44)]
  d[, optim_age18_24 := optim*as.numeric(cohort_age<=24)]
  d[, optim_age35_44 := optim*as.numeric(cohort_age>=35 & cohort_age<=44)]
  bands <- c("18_24","25_34","35_44","45_59")
  n <- c(sum(a<=24),sum(a>=25&a<=34),sum(a>=35&a<=44),sum(a>=45))
  for (i in seq_along(bands)) {
    fp_assert(n[i]>=100, paste("Insufficient sample in age band",bands[i]))
    fp_add_coverage(store,"06_AGE_HETEROGENEITY","canonical_sample_by_age",bands[i],n[i],n[i],1)
  }
  fp_log("Age bands: ",paste(paste0(bands,"=",n),collapse="; "))
  r_age <- c(original_rhs, "pess_age18_24", "pess_age35_44",
             "optim_age18_24", "optim_age35_44")
  rank <- fp_fe_rank(d$pidp,d$timecell)
  for (y in c("save","next_save","next_minus_current")) {
    model <- fp_fit(d,y,r_age,rank)
    weights <- list(
      `18_24` = c(pess=1,pess_young=1,pess_age18_24=1),
      `25_34` = c(pess=1,pess_young=1),
      `35_44` = c(pess=1,pess_age35_44=1),
      `45_59` = c(pess=1))
    for (lab in names(weights)) fp_add_est(store,"06_AGE_HETEROGENEITY",
                  "four_exploratory_age_bands",y,paste0("pess_age_",lab),model,weights[[lab]])
    fp_add_est(store,"06_AGE_HETEROGENEITY","four_exploratory_age_bands",y,
               "pess_18_24_minus_25_34",model,c(pess_age18_24=1))
    fp_add_est(store,"06_AGE_HETEROGENEITY","four_exploratory_age_bands",y,
               "pess_35_44_minus_45_59",model,c(pess_age35_44=1))
    test <- fp_wald_test(model,c("pess_age18_24","pess_age35_44"))
    store$tests[[length(store$tests)+1L]] <- data.table(
      stage="06_AGE_HETEROGENEITY", spec="four_exploratory_age_bands", outcome=y,
      null="no within-original-age-group difference", F=unname(test["F"]),
      df1=unname(test["df1"]), df2=unname(test["df2"]), p=unname(test["p"]))
    fp_log("Age-bin Wald test ",y," p=",sprintf("%.5g",test["p"]))
  }

  # Separate continuous-interaction specification WITHOUT the original
  # under-35 EXPECTATION interaction. Original age controls remain included.
  d[, pess_age_decade := pess * (cohort_age-40)/10]
  d[, optim_age_decade := optim * (cohort_age-40)/10]
  r_slope <- c(setdiff(original_rhs,c("pess_young","optim_young")),
               "pess_age_decade","optim_age_decade")
  for (y in c("save","next_save","next_minus_current")) {
    model <- fp_fit(d,y,r_slope,rank)
    for (eval_age in c(20,30,40,50)) {
      w <- c(pess=1,pess_age_decade=(eval_age-40)/10)
      fp_add_est(store,"06_AGE_HETEROGENEITY","continuous_linear_age_gradient",y,
                 paste0("pess_age_",eval_age),model,w)
    }
    fp_add_est(store,"06_AGE_HETEROGENEITY","continuous_linear_age_gradient",y,
               "pess_difference_per_10_years",model,c(pess_age_decade=1))
  }
  TRUE
})

fp_report()
fp_log(strrep("=",95))
fp_log("FINISHED | ",sum(stages$status=="PASS")," successful stages of ",nrow(stages))
fp_log("REGRESSION_CONTRASTS.csv and FINAL_CHECKS_REPORT.md: ",outdir)
fp_log("NO RESPONDENT-LEVEL OUTPUT WAS WRITTEN TO DROPBOX")
fp_log(strrep("=",95))
if (any(stages$status=="FAILED")) quit(save="no",status=1L)
quit(save="no",status=0L)
