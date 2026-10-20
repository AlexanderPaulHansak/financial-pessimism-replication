# FINANCIAL PESSIMISM -- RESOURCE/EMPLOYMENT REPAIR v1.1
# This file is sourced by FINAL_EMPIRICAL_CHECKS.R, after the frozen sample
# has been verified and joined to the local BHPS cohort extract.
# The upstream cohort extractor asked BHPS for fimnnet_dv, which is unavailable
# in the harmonised historical waves. BHPS provides fimngrs_dv (gross monthly
# personal income); household gross income fihhmngrs_dv is obtained from
# HHRESP by wave-specific hidp when present.
# Read-only UKDS 6614 TAB input; NO respondent-level output to Dropbox.

resource_joined <- NULL

fp_bhps_income_from_raw <- function() {
  tab_bhps <- Sys.getenv("FP_BHPS_TAB_ROOT", unset = file.path(dirname(local_root),
                        "UKDA-6614-tab", "tab", "bhps"))
  fp_screen_private(tab_bhps)
  fp_assert(dir.exists(tab_bhps), paste0("BHPS raw TAB folder not found: ", tab_bhps,
            ". Set FP_BHPS_TAB_ROOT to its local nonsynced directory."))
  # Needed at either side of the original forecast-follow-up pair.
  wanted <- unique(rbind(joined[, .(pidp,wave)],
                         joined[, .(pidp,wave=wave+1L)]))
  per_wave <- vector("list", 18L)
  aud <- vector("list", 18L)
  for (wv in seq_len(18L)) {
    prefix <- paste0("b", letters[wv])
    indpath <- file.path(tab_bhps, paste0(prefix, "_indresp.tab"))
    hhpath  <- file.path(tab_bhps, paste0(prefix, "_hhresp.tab"))
    expected_ids <- wanted[wave==wv,pidp]
    n_need <- length(expected_ids)
    fp_log("  BHPS wave ", sprintf("%02d",wv), " | frozen pairs requiring this wave=",n_need)
    valid_ind <- FALSE
    valid_hh <- FALSE
    from_ind <- FALSE
    missing_or_problem <- character()
    person_col <- paste0(prefix, "_fimngrs_dv")
    household_col <- paste0(prefix, "_fihhmngrs_dv")
    hid_col <- paste0(prefix, "_hidp")
    d <- data.table(pidp=character(),wave=integer(),personal_gross=double(),household_gross=double())
    if (!file.exists(indpath)) {
      missing_or_problem <- c(missing_or_problem,"missing_indresp_file")
    } else {
      hdr <- names(fread(indpath,nrows=0L,showProgress=FALSE))
      if (!("pidp" %in% hdr)) {
        missing_or_problem <- c(missing_or_problem,"missing_pidp_in_indresp")
      } else {
        if (!(person_col %in% hdr)) missing_or_problem <- c(missing_or_problem,"missing_person_gross_variable")
        if (!(hid_col %in% hdr)) missing_or_problem <- c(missing_or_problem,"missing_hidp_in_indresp")
        keep <- unique(c("pidp",intersect(c(person_col,hid_col,household_col),hdr)))
        x <- fread(indpath,select=keep,showProgress=FALSE,integer64="character",
                   colClasses=list(character=intersect(c("pidp",hid_col), keep)))
        x[, pidp := fp_safe_id(pidp)]
        x <- x[pidp %in% expected_ids]
        fp_assert(!anyDuplicated(x$pidp),paste0("Duplicate BHPS PIDP in ",basename(indpath)))
        x[, wave := wv]
        x[, personal_gross := if (person_col %in% names(x))
                fp_income_clean(x[[person_col]]) else rep(NA_real_, .N)]
        x[, household_gross := if (household_col %in% names(x))
                fp_income_clean(x[[household_col]]) else rep(NA_real_, .N)]
        valid_ind <- person_col %in% hdr
        from_ind <- household_col %in% hdr
        if (hid_col %in% names(x) && file.exists(hhpath)) {
          hhdr <- names(fread(hhpath,nrows=0L,showProgress=FALSE))
          hh_hid <- if (hid_col %in% hhdr) hid_col else if ("hidp" %in% hhdr) "hidp" else ""
          if (nzchar(hh_hid) && household_col %in% hhdr) {
            hh <- fread(hhpath,select=c(hh_hid, household_col),showProgress=FALSE,
                        integer64="character",colClasses=list(character=hh_hid))
            setnames(hh,hh_hid,"_hh_join_id")
            hh[, `_hh_join_id` := as.character(`_hh_join_id`)]
            hh <- hh[`_hh_join_id` %in% as.character(x[[hid_col]])]
            fp_assert(!anyDuplicated(hh[["_hh_join_id"]]),
                      paste0("Duplicate HHID in ",basename(hhpath)))
            hh[, `_hh_gross` := fp_income_clean(get(household_col))]
            x[, `_hh_join_id` := as.character(get(hid_col))]
            x <- merge(x,hh[, .(`_hh_join_id`,`_hh_gross`)],by="_hh_join_id",all.x=TRUE,sort=FALSE)
            x[, household_gross := fifelse(is.finite(`_hh_gross`),`_hh_gross`,household_gross)]
            valid_hh <- TRUE
            rm(hh)
          } else {
            missing_or_problem <- c(missing_or_problem,"hhresp_hidp_or_gross_column_missing")
          }
        } else if (hid_col %in% names(x)) {
          missing_or_problem <- c(missing_or_problem,"hhresp_file_missing")
        }
        d <- x[, .(pidp,wave,personal_gross,household_gross)]
        rm(x)
      }
    }
    per_wave[[wv]] <- d
    n_valid_p <- sum(is.finite(d$personal_gross))
    n_valid_h <- sum(is.finite(d$household_gross))
    aud[[wv]] <- data.table(wave=wv,prefix=prefix,canonical_endpoint_rows_needed=n_need,
                            matched_indresp_rows=nrow(d),
                            gross_person_col_in_indresp=valid_ind,
                            gross_household_col_in_indresp=from_ind,
                            gross_household_col_in_hhresp=valid_hh,
                            valid_gross_person_income=n_valid_p,
                            valid_gross_household_income=n_valid_h,
                            source_notes=paste(missing_or_problem,collapse=";"))
    fp_log("    matched=",nrow(d)," | gross person=",n_valid_p,
           " | gross household=",n_valid_h)
  }
  all_raw <- rbindlist(per_wave,fill=TRUE)
  fp_assert(nrow(all_raw)>0L,"No matching raw BHPS indresp observations")
  fp_assert(!anyDuplicated(all_raw,by=c("pidp","wave")),"Duplicated raw income keys")
  new_audit <- rbindlist(aud)
  fwrite(new_audit,file.path(outdir,"RESOURCE_SOURCE_AUDIT.csv"))
  # No respondent-level file is written. Only the aggregate source audit above.
  current <- all_raw[, .(pidp,wave, personal_gross_t=personal_gross,
                         household_gross_t=household_gross)]
  future <- all_raw[, .(pidp,wave=wave-1L,personal_gross_t1=personal_gross,
                        household_gross_t1=household_gross)]
  d <- merge(joined,current,by=c("pidp","wave"),all.x=TRUE,sort=FALSE)
  d <- merge(d,future,by=c("pidp","wave"),all.x=TRUE,sort=FALSE)
  fp_assert(nrow(d)==nrow(joined),"Raw income join altered frozen canonical sample size")
  fp_assert(!anyDuplicated(d,by=c("pidp","wave")),"Income join duplicated canonical rows")
  d
}

# Stage 03A: independent raw source join and strict audit. Does not modify
# canonical or upstream private data, so no costly Julia re-extraction.
fp_stage("03A_RAW_BHPS_INCOME_JOIN",function() {
  resource_joined <<- fp_bhps_income_from_raw()
  d <- resource_joined
  fp_coverage_groups(d,is.finite(d$personal_gross_t) & is.finite(d$personal_gross_t1),
                     "gross_person_income_both_waves","03A_RAW_BHPS_INCOME_JOIN")
  fp_coverage_groups(d,is.finite(d$household_gross_t) & is.finite(d$household_gross_t1),
                     "gross_household_income_both_waves","03A_RAW_BHPS_INCOME_JOIN")
  p <- sum(is.finite(d$personal_gross_t)&is.finite(d$personal_gross_t1))
  h <- sum(is.finite(d$household_gross_t)&is.finite(d$household_gross_t1))
  fp_log("Gross personal-income pairs: ",p, "; gross household-income pairs: ",h)
  fp_assert(p>2500 || h>2500,
            "Insufficient raw personal AND household gross-income observations: inspect RESOURCE_SOURCE_AUDIT.csv")
  TRUE
})

fp_run_resource_model <- function(kind=c("personal","household"),stage) {
  kind <- match.arg(kind)
  fp_assert(!is.null(resource_joined),"Raw BHPS income join failed; inspect earlier stage")
  d <- copy(resource_joined)
  first <- paste0(kind,"_gross_t")
  last <- paste0(kind,"_gross_t1")
  fp_assert(all(c(first,last) %in% names(d)),"New raw income columns unavailable")
  d[, real_income_t := fp_real_2015(get(first),year_t)]
  d[, real_income_t1 := fp_real_2015(get(last),year_t1)]
  d[, income_ihs_change := asinh(real_income_t1/1000)-asinh(real_income_t/1000)]
  d[, job_start := fp_job_clean(job_t)]
  d[, job_end := fp_job_clean(job_t1)]
  d[, to_unemployed := as.numeric(job_start %in% c(1L,2L) & job_end==3L)]
  complete <- is.finite(d$income_ihs_change) & !is.na(d$job_start) & !is.na(d$job_end)
  fp_coverage_groups(d,complete,paste0(kind,"_gross_income_and_activity_both"),stage)
  sub <- d[complete]
  fp_assert(nrow(sub)>2500 && uniqueN(sub$pidp)>500,
            paste0("Insufficient valid ",kind,"-income pairs; inspect RESOURCE_SOURCE_AUDIT.csv"))
  fp_log("Gross ",kind," resource sample: ",nrow(sub)," pairs; ",uniqueN(sub$pidp)," people")
  rank <- fp_fe_rank(sub$pidp,sub$timecell)
  stage_spec <- paste0("observed_gross_",kind,"_income")
  income_fit <- fp_fit(sub,"income_ihs_change",original_rhs,rank)
  fp_add_three(store,stage,paste0(stage_spec,"_forecast_information"),"income_ihs_change",
               income_fit,scale="change in asinh(real gross monthly GBP/1000)")
  fp_add_three(store,stage,paste0(stage_spec,"_forecast_information"),"income_ihs_change",
               income_fit,type="optim",scale="change in asinh(real gross monthly GBP/1000)")
  controls <- c(original_rhs,"income_ihs_change","to_unemployed")
  for (y in c("next_save","next_minus_current")) {
    original <- fp_fit(sub,y,original_rhs,rank)
    adjusted <- fp_fit(sub,y,controls,rank)
    fp_assert(nobs(original$fit)==nobs(adjusted$fit),"Post-forecast controls altered rows")
    fp_add_three(store,stage,paste0(stage_spec,"_same_rows_unadjusted"),y,original,
                 note="Same restricted observed-resource sample as adjusted model")
    fp_add_three(store,stage,paste0(stage_spec,"_same_rows_post_controls"),y,adjusted,
                 note="Conditioned on POST-forecast gross income change and employment-to-unemployment; descriptive only, not mediation")
  }
  TRUE
}

# Different sources of resources are independent and can pass/fail separately.
fp_stage("03B_GROSS_PERSONAL_INCOME",function() {
  fp_run_resource_model("personal","03B_GROSS_PERSONAL_INCOME")
})
fp_stage("03C_GROSS_HOUSEHOLD_INCOME",function() {
  fp_run_resource_model("household","03C_GROSS_HOUSEHOLD_INCOME")
})

# Employment uses the already verified BHPS longitudinal join, not income.
# Runs even when the raw source folder or income stages are unavailable.
fp_stage("03D_EMPLOYMENT_TRANSITIONS",function() {
  fp_assert(!is.null(joined),"Canonical/long extract join unavailable")
  d <- copy(joined)
  d[, job_start := fp_job_clean(job_t)]
  d[, job_end := fp_job_clean(job_t1)]
  status_valid <- !is.na(d$job_start) & !is.na(d$job_end)
  fp_coverage_groups(d,status_valid,"valid_employment_status_both_waves","03D_EMPLOYMENT_TRANSITIONS")
  at_risk <- status_valid & d$job_start %in% c(1L,2L)
  fp_coverage_groups(d,at_risk,"employed_at_forecast_with_followup","03D_EMPLOYMENT_TRANSITIONS")
  sub <- d[at_risk]
  fp_assert(nrow(sub)>2500 && uniqueN(sub$pidp)>500,"Too few employed-at-risk observations")
  sub[, to_unemployed := as.numeric(job_end==3L)]
  sub[, out_of_employment := as.numeric(!(job_end %in% c(1L,2L)))]
  fp_log("Employed-at-risk sample: ",nrow(sub)," pairs; ",uniqueN(sub$pidp),
         " people; to-unemployment events=",sum(sub$to_unemployed),
         "; all exit-employment events=",sum(sub$out_of_employment))
  fp_assert(sum(sub$to_unemployed)>=30 && sum(sub$out_of_employment)>=30,
            "Too few transitions for stable employment outcome estimates")
  rank <- fp_fe_rank(sub$pidp,sub$timecell)
  for (y in c("to_unemployed","out_of_employment")) {
    fit <- fp_fit(sub,y,original_rhs,rank)
    fp_add_three(store,"03D_EMPLOYMENT_TRANSITIONS","forecast_employment_transition",y,fit,
                 note="Conditioned on employed/self-employed at forecast. Self-reported states; no layoff dates or involuntary separation observed")
  }
  TRUE
})
