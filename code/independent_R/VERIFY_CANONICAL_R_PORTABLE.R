# Exact-sample, independent R verification of the canonical BHPS/UKHLS estimates.
# Requires only the installed R packages data.table and fixest.
# PRIVATE: Reads model-ready observations from C:/Hansak/Data only.
# PUBLIC: Writes aggregate contrasts and diagnostics to Dropbox. NEVER person-level rows.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

project <- Sys.getenv("FP_PROJECT_ROOT", unset = getwd())
source_tag <- Sys.getenv("FP_CANONICAL_REPLAY_TAG", unset = "20261016_140555")
run_tag <- Sys.getenv("FP_R_CANONICAL_VERIFY_TAG", unset = format(Sys.time(), "%Y%m%d_%H%M%S"))
local_root <- Sys.getenv("FP_UK_DERIVED", unset = "C:/Hansak/Data/UKHLS_derived")
if (!grepl("^[A-Za-z0-9_-]+$", source_tag) || !grepl("^[A-Za-z0-9_-]+$", run_tag)) {
  stop("Unsafe replay/run tag")
}
private <- file.path(local_root, "pessimism_canonical_replay_v1", source_tag,
                     "private_model_ready_samples")
ref_dir <- file.path(project, "04_Verified_Results", paste0("Canonical_Python_", source_tag))
public <- file.path(project, "04_Verified_Results", paste0("Independent_R_", run_tag))

private_slash <- tolower(gsub("\\\\", "/", normalizePath(private, winslash = "/", mustWork = FALSE)))
if (grepl("/(dropbox|onedrive|google drive|google_drive)(/|$)", private_slash)) {
  stop("Canonical respondent-level input directory must not be in cloud storage")
}
dir.create(public, showWarnings = FALSE, recursive = TRUE)
ref_file <- file.path(ref_dir, "CANONICAL_REPLAY_COEFFICIENT_COMPARISON.csv")
summary_file <- file.path(ref_dir, "CANONICAL_REPLAY_SAMPLE_SUMMARY.csv")
if (!file.exists(ref_file) || !file.exists(summary_file)) {
  stop("Canonical replay aggregate files missing. First check the successful canonical replay output.")
}
reference <- fread(ref_file, showProgress = FALSE)
reference_summary <- fread(summary_file, showProgress = FALSE)

# Both aggregate reference files were produced by the successful Python
# canonical replay. Assert their one-to-one keys before reading private data.
if (anyDuplicated(reference_summary[["model"]]))
  stop("Canonical reference sample summary contains duplicate models")
if (anyDuplicated(reference[, .(model, outcome, contrast)]))
  stop("Canonical reference coefficient file contains duplicate model/outcome/contrast keys")

cat("FINANCIAL PESSIMISM | INDEPENDENT R VERIFICATION ON EXACT CANONICAL SAMPLES\n")
cat("Canonical source run: ", source_tag, "\n", sep = "")
cat("PRIVATE input: ", private, "\n", sep = "")
cat("AGGREGATE output: ", public, "\n", sep = "")
cat("R=", as.character(getRversion()), "; fixest=", as.character(packageVersion("fixest")),
    "; data.table=", as.character(packageVersion("data.table")), "\n", sep = "")

specs <- data.table(
  model = c("BHPS_gross_published_lw", "UKHLS_gross_published_lw",
            "UKHLS_gross_timing_published_lw"),
  file = c("BHPS_CANONICAL_SAMPLE_LOCAL.csv", "UKHLS_CANONICAL_SAMPLE_LOCAL.csv",
           "UKHLS_STRICT_CANONICAL_SAMPLE_LOCAL.csv")
)
outcomes <- list(
  BHPS_gross_published_lw = c("save", "next_save", "next_minus_current"),
  UKHLS_gross_published_lw = "next_save",
  UKHLS_gross_timing_published_lw = c("previous_save", "next_save", "next_minus_previous")
)
needed <- c("pess", "optim", "pess_young", "optim_young")
non_rhs <- c("pidp", "timecell", "source", "wave", "psu", "strata", "w_fit",
             "next_published_pair_weight", "next_published_trip_weight",
             "save", "next_save", "next_minus_current", "previous_save", "next_minus_previous")

# Exact FE rank: rank of the bipartite person-by-time dummy incidence matrix.
# Union by component size guarantees that the root search remains inexpensive.
fe_dummy_rank <- function(person, timecell) {
  p <- match(person, unique(person))
  t <- match(timecell, unique(timecell))
  np <- max(p)
  nt <- max(t)
  parent <- seq_len(np + nt)
  component_size <- rep.int(1L, np + nt)
  root <- function(j) {
    while (parent[j] != j) j <- parent[j]
    j
  }
  for (i in seq_along(p)) {
    a <- root(p[i]); b <- root(np + t[i])
    if (a != b) {
      if (component_size[a] < component_size[b]) {
        z <- a; a <- b; b <- z
      }
      parent[b] <- a
      component_size[a] <- component_size[a] + component_size[b]
    }
  }
  ncomponents <- length(unique(vapply(seq_along(parent), root, integer(1))))
  np + nt - ncomponents
}

# Independently implement the canonical published design covariance on the R
# fixest-demeaned regressors. Same target formula, separate FE/score computation.
# In the canonical Python definition:
# score_g = sum_i Xtilde_i * w_i * e_i over PSU g;
# meat = sum_h [m_h/(m_h-1)] sum_{g in h} (score_g - mean_h)'(...)
# singleton stratum: score_g' score_g.
# finite-sample multiplier: (N-1)/(N - FE_rank - number_of_slopes).
stratified_psu_covariance <- function(est, d, fe_rank) {
  beta <- coef(est)
  nm <- names(beta)
  X <- est$X_demeaned
  y <- est$y_demeaned
  if (is.null(X) || is.null(y)) {
    stop("fixest did not retain the demeaned model matrices")
  }
  X <- as.matrix(X)
  if (!all(nm %in% colnames(X))) {
    stop("Demeaned RHS columns do not match named fitted coefficients")
  }
  X <- X[, nm, drop = FALSE]
  y <- as.numeric(y)
  w <- as.numeric(d$w_fit)
  if (length(y) != nrow(d) || nrow(X) != nrow(d) || any(!is.finite(w)) || any(w <= 0)) {
    stop("Mismatched model rows or invalid canonical weights")
  }
  sw <- sqrt(w)
  wx <- X * sw
  resid_dm <- y - as.numeric(X %*% beta)
  score <- wx * (sw * resid_dm)
  bread <- solve(crossprod(wx))
  key <- paste(d$strata, d$psu, sep = "__PSU__")
  psu_scores <- rowsum(score, group = key, reorder = FALSE)
  psu_strata <- as.character(d$strata[match(rownames(psu_scores), key)])
  if (anyNA(psu_strata)) stop("Failed to map PSU scores to strata")
  if (nrow(psu_scores) != uniqueN(key)) stop("Lost PSU during score aggregation")
  K <- length(beta)
  meat <- matrix(0, nrow = K, ncol = K)
  singleton_strata <- 0L
  for (h in unique(psu_strata)) {
    which_h <- which(psu_strata == h)
    m <- length(which_h)
    s <- psu_scores[which_h, , drop = FALSE]
    if (m > 1L) {
      s <- sweep(s, 2, colMeans(s), FUN = "-")
      meat <- meat + (m / (m - 1)) * crossprod(s)
    } else {
      singleton_strata <- singleton_strata + 1L
      meat <- meat + crossprod(s)
    }
  }
  N <- nrow(d)
  nparam <- fe_rank + K
  if (N <= nparam) stop("Nonpositive residual degrees of freedom")
  V <- bread %*% meat %*% bread * (N - 1) / (N - nparam)
  V <- (V + t(V)) / 2
  dimnames(V) <- list(nm, nm)
  if (any(!is.finite(V)) || any(diag(V) < -1e-10)) {
    stop("Invalid independent stratified-PSU covariance")
  }
  list(vcov = V,
       n_psus = nrow(psu_scores), n_strata = uniqueN(psu_strata),
       df = nrow(psu_scores) - uniqueN(psu_strata),
       singleton_strata = singleton_strata, fe_rank = fe_rank, K = K,
       max_weighted_score_per_obs = max(abs(colSums(score))) / N)
}

extract_contrast <- function(est, V, type) {
  beta <- coef(est)
  cvec <- setNames(rep(0, length(beta)), names(beta))
  if (type == "ages18_34") {
    cvec["pess"] <- 1
    cvec["pess_young"] <- 1
  } else if (type == "ages35_59") {
    cvec["pess"] <- 1
  } else if (type == "young_minus_older") {
    cvec["pess_young"] <- 1
  } else stop("Unrecognized contrast: ", type)
  c(estimate = sum(beta * cvec), se = sqrt(max(0, drop(crossprod(cvec, V %*% cvec)))))
}

results <- list(); diagnostics <- list(); stages <- list(); result_i <- 0L; diag_i <- 0L
point_tol_pp <- 0.001     # predetermined: one thousandth of a percentage point
se_tol_pp <- 0.003        # predetermined: three thousandths of a percentage point

for (ix in seq_len(nrow(specs))) {
  model <- specs$model[ix]
  input <- file.path(private, specs$file[ix])
  cat("\n", strrep("-", 76), "\nMODEL ", model, "\n", sep = "")
  status <- tryCatch({
    if (!file.exists(input)) stop("Canonical PRIVATE sample missing: ", input)
    d <- fread(input, showProgress = FALSE, integer64 = "character")
    for (nm in c("pidp", "timecell", "strata", "psu")) d[[nm]] <- as.character(d[[nm]])
    if (anyNA(d[, .(pidp, timecell, strata, psu, w_fit)])) stop("Missing essential canonical fields")
    if (any(d$w_fit <= 0) || abs(mean(d$w_fit) - 1) > 1e-8) {
      stop("Canonical sample weight is nonpositive or not mean-normalized")
    }
    # Use an ordinary R vector lookup. Inside DT[i], `model` would resolve
    # to the table column, so `model == model` accidentally selects all rows.
    refsum_rows <- which(reference_summary[["model"]] == model)
    if (length(refsum_rows) != 1L) {
      stop(sprintf("Reference summary lookup returned %d rows for model '%s'", 
                   length(refsum_rows), model))
    }
    refsum <- reference_summary[refsum_rows]
    N <- nrow(d)
    people <- uniqueN(d$pidp)
    psus <- uniqueN(paste(d$strata, d$psu, sep = "__PSU__"))
    strata <- uniqueN(d$strata)
    if (N != refsum$N || people != refsum$people ||
        psus != refsum$psus || strata != refsum$strata) {
      stop(sprintf("Canonical sample counts mismatch: N=%d people=%d PSU=%d strata=%d", N, people, psus, strata))
    }
    rhs <- setdiff(names(d), non_rhs)
    if (!all(needed %in% rhs)) stop("Essential expectations RHS term missing")
    oy <- outcomes[[model]]
    fe_rank <- fe_dummy_rank(d$pidp, d$timecell)
    cat(sprintf("  Canonical sample OK: N=%d, people=%d, PSU=%d, strata=%d; FE rank=%d; RHS=%d\n",
                N, people, psus, strata, fe_rank, length(rhs)))
    fits <- list()
    for (outcome in oy) {
      cat("  Fitting ", outcome, " with fixest ...\n", sep = "")
      formula <- as.formula(paste0(outcome, " ~ ", paste(rhs, collapse = " + "),
                                   " | pidp + timecell"))
      fit <- feols(formula, data = d, weights = ~w_fit, vcov = ~pidp,
                   fixef.rm = "none", fixef.tol = 1e-10,
                   fixef.iter = 20000, collin.tol = 1e-10,
                   demeaned = TRUE, nthreads = 2,
                   notes = TRUE, warn = TRUE)
      if (nobs(fit) != N) stop("R model changed canonical sample size")
      if (!all(needed %in% names(coef(fit)))) stop("Essential expectation coefficient collinear/unidentified")
      fits[[outcome]] <- fit
      design <- stratified_psu_covariance(fit, d, fe_rank)
      if (design$n_psus != psus || design$n_strata != strata) stop("Survey design counts mismatched")
      diag_i <- diag_i + 1L
      diagnostics[[diag_i]] <- data.table(model = model, outcome = outcome, N = N,
        people = people, psus = psus, strata = strata,
        terms_python = refsum$n_terms, terms_R = design$K,
        fixest_dropped = paste(fit$collin.var, collapse = ";"),
        fe_rank = fe_rank, survey_df = design$df,
        singleton_strata = design$singleton_strata,
        max_weighted_score_per_obs = design$max_weighted_score_per_obs,
        expected_term_count_match = (design$K == refsum$n_terms))
      for (contrast in c("ages18_34", "ages35_59", "young_minus_older")) {
        # Keep loop scalars outside data.table's column-name lookup scope.
        ref_rows <- which(reference[["model"]] == model &
                          reference[["outcome"]] == outcome &
                          reference[["contrast"]] == contrast)
        if (length(ref_rows) != 1L) {
          stop(sprintf("Reference coefficient lookup returned %d rows for %s / %s / %s",
                       length(ref_rows), model, outcome, contrast))
        }
        r <- reference[ref_rows]
        z <- extract_contrast(fit, design$vcov, contrast)
        result_i <- result_i + 1L
        d_est <- 100 * (z[["estimate"]] - r$ref_effect)
        d_se <- 100 * (z[["se"]] - r$ref_se)
        results[[result_i]] <- data.table(model = model, outcome = outcome, contrast = contrast,
          N = N, people = people,
          r_estimate_pp = 100 * z[["estimate"]], python_estimate_pp = 100 * r$ref_effect,
          estimate_difference_pp = d_est,
          r_survey_se_pp = 100 * z[["se"]], python_survey_se_pp = 100 * r$ref_se,
          se_difference_pp = d_se,
          point_pass = abs(d_est) <= point_tol_pp,
          survey_se_pass = abs(d_se) <= se_tol_pp,
          complete_term_count_pass = design$K == refsum$n_terms)
        cat(sprintf("    %-18s R=%+9.5f pp  original=%+9.5f pp  SE R=%.5f original=%.5f\n",
                    contrast, 100 * z[["estimate"]], 100 * r$ref_effect,
                    100 * z[["se"]], 100 * r$ref_se))
      }
    }
    if (length(oy) == 3L) {
      c0 <- coef(fits[[oy[1L]]]); c1 <- coef(fits[[oy[2L]]]); cd <- coef(fits[[oy[3L]]])
      terms <- intersect(needed, Reduce(intersect, list(names(c0), names(c1), names(cd))))
      if (length(terms) != 4L) stop("Could not check the four primary timing coefficients")
      gap <- max(abs(cd[terms] - (c1[terms] - c0[terms])))
      if (gap > 1e-7) stop(sprintf("Timing identity failed: %.8g", gap))
      cat(sprintf("  Four-coefficient timing identity: max %.3e (PASS)\n", gap))
    }
    "PASS"
  }, error = function(e) {
    cat("  ERROR: ", conditionMessage(e), "\n", sep = "")
    paste0("FAILED: ", conditionMessage(e))
  })
  stages[[model]] <- status
  rm(list = intersect(c("d", "fits"), ls()))
  invisible(gc(verbose = FALSE))
}

rdat <- if (length(results)) rbindlist(results, fill = TRUE) else data.table()
ddat <- if (length(diagnostics)) rbindlist(diagnostics, fill = TRUE) else data.table()
if (nrow(rdat)) fwrite(rdat, file.path(public, "R_CANONICAL_COEFFICIENT_CHECK.csv"))
if (nrow(ddat)) fwrite(ddat, file.path(public, "R_CANONICAL_DESIGN_AUDIT.csv"))
fwrite(data.table(model = names(stages), status = unlist(stages, use.names = FALSE)),
       file.path(public, "R_CANONICAL_STAGE_STATUS.csv"))

all_models_pass <- length(stages) == 3L && all(unlist(stages, use.names = FALSE) == "PASS")
all_contrasts_pass <- nrow(rdat) == 21L &&
  all(rdat$point_pass) && all(rdat$survey_se_pass) && all(rdat$complete_term_count_pass)
gate <- isTRUE(all_models_pass && all_contrasts_pass)
fmtmax <- function(x) if (!length(x)) "not available" else sprintf("%.8g", max(abs(x)))
report <- c(
  "# Exact-canonical-sample independent R verification",
  "",
  sprintf("**Status: %s**", if (gate) "PASS" else "UNVERIFIED — examine diagnostics"),
  "",
  sprintf("Canonical Python source run: `%s`", source_tag),
  sprintf("R  %s / fixest %s / data.table %s", as.character(getRversion()),
          packageVersion("fixest"), packageVersion("data.table")),
  sprintf("Models completed: %d / 3; comparisons: %d / 21", sum(unlist(stages) == "PASS"), nrow(rdat)),
  sprintf("Largest absolute coefficient gap: %s percentage points", fmtmax(rdat$estimate_difference_pp)),
  sprintf("Largest absolute survey-SE gap: %s percentage points", fmtmax(rdat$se_difference_pp)),
  sprintf("Prespecified coefficient tolerance: %.3g pp; survey-SE tolerance: %.3g pp", point_tol_pp, se_tol_pp),
  "",
  "## Design verification",
  "- The respondent-level inputs are the three exactly matched model-ready canonical CSVs on the local data drive.",
  "- R/fixest estimates two-way weighted fixed effects independently of the original Python alternating-absorption algorithm.",
  "- Stratified PSU covariance is computed from R residualized scores, using the canonical finite-sample correction and singleton-stratum convention.",
  "- The FE dummy rank is calculated independently as a bipartite incidence-matrix rank.",
  "- This establishes numerical cross-implementation agreement only if every reported check passes; it does not establish causality or survey design validity beyond the agreed convention.",
  "- No person-level microdata are written into Dropbox. Only this report and aggregate summary tables are public.",
  "",
  "## Model statuses",
  paste0("- ", names(stages), ": ", unlist(stages, use.names = FALSE)),
  ""
)
writeLines(report, con = file.path(public, "R_CANONICAL_VERIFICATION_REPORT.md"), useBytes = TRUE)
cat("\n", paste(report, collapse = "\n"), "\n", sep = "")
cat("Aggregate output: ", public, "\n", sep = "")
if (!gate) quit(save = "no", status = 2L)
