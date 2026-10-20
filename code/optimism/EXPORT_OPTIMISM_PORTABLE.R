# Canonical-sample BHPS optimism reporting only. Frozen headline values untouched.
# Requires only the installed R packages data.table and fixest.
# PRIVATE: Reads model-ready observations from C:/Hansak/Data only.
# PUBLIC: Writes aggregate contrasts and diagnostics to Dropbox. NEVER person-level rows.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

project <- Sys.getenv("FP_PROJECT_ROOT", unset = getwd())
source_tag <- Sys.getenv("FP_CANONICAL_REPLAY_TAG", unset = "20261016_140555")
run_tag <- Sys.getenv("FP_OPTIMISM_TAG", unset = format(Sys.time(), "%Y%m%d_%H%M%S"))
local_root <- Sys.getenv("FP_UK_DERIVED", unset = "C:/Hansak/Data/UKHLS_derived")
if (!grepl("^[A-Za-z0-9_-]+$", source_tag) || !grepl("^[A-Za-z0-9_-]+$", run_tag)) {
  stop("Unsafe replay/run tag")
}
private <- file.path(local_root, "pessimism_canonical_replay_v1", source_tag,
                     "private_model_ready_samples")
ref_dir <- file.path(project, "04_Verified_Results", paste0("Canonical_Python_", source_tag))
public <- file.path(project, "04_Verified_Results", paste0("Canonical_Optimism_", run_tag))

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

cat("FINANCIAL PESSIMISM | CANONICAL OPTIMISM SUPPLEMENTAL OUTPUT\n")
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


# Reporting-only fit of three outcomes in the archived canonical BHPS sample.
model_name <- "BHPS_gross_published_lw"
input <- file.path(private, "BHPS_CANONICAL_SAMPLE_LOCAL.csv")
if (!file.exists(input)) stop("Missing private canonical sample: ", input)
d <- fread(input, showProgress=FALSE, integer64="character")
for (nm in c("pidp","timecell","psu","strata")) d[[nm]] <- as.character(d[[nm]])
ref_rows <- which(reference_summary[["model"]] == model_name)
stopifnot(length(ref_rows) == 1L)
refsum <- reference_summary[ref_rows]
stopifnot(nrow(d) == 104848L, uniqueN(d$pidp) == 12644L,
          abs(mean(d$w_fit)-1) < 1e-8, all(d$w_fit>0))
psu_count <- uniqueN(paste(d$strata,d$psu,sep="__PSU__"))
stopifnot(psu_count == 1511L, uniqueN(d$strata) == 122L)
rhs <- setdiff(names(d), non_rhs)
stopifnot(all(needed %in% rhs))
fe_rank <- fe_dummy_rank(d$pidp,d$timecell)
result <- list()
i <- 0L
pess_check <- list()
for (outcome in c("save", "next_save", "next_minus_current")) {
  # Evaluate the reference-key comparison in ordinary R scope, BEFORE
  # data.table's [i] expression can mask the local 'outcome' variable.
  # This also catches missing/duplicate archived rows before fitting the model.
  reference_index <- which(
    reference[["model"]] == model_name &
    reference[["outcome"]] == outcome &
    reference[["contrast"]] == "ages18_34"
  )
  if (length(reference_index) != 1L) {
    stop(sprintf("Reference mismatch for model '%s' and outcome '%s': expected 1 row, found %d",
                 model_name, outcome, length(reference_index)))
  }
  old <- reference[reference_index]
  cat("Estimating ", outcome, " on canonical BHPS sample ...\n", sep="")
  form <- as.formula(paste0(outcome," ~ ",paste(rhs,collapse=" + ")," | pidp + timecell"))
  f <- feols(form,data=d,weights=~w_fit,vcov=~pidp,
             fixef.rm="none", fixef.tol=1e-10, fixef.iter=20000,
             collin.tol=1e-10, demeaned=TRUE, nthreads=2, notes=TRUE, warn=TRUE)
  stopifnot(nobs(f)==104848L, all(needed %in% names(coef(f))))
  design <- stratified_psu_covariance(f,d,fe_rank)
  stopifnot(design$K==50L, design$n_psus==1511L, design$n_strata==122L,
            design$df==1389L)
  # The archived pessimism coefficients are a built-in guard: we only write an
  # optimism table if the same run reproduces the frozen BHPS expectations.
  stopifnot(nrow(old) == 1L)  # Reference row was selected before estimation.
  zold <- extract_contrast(f,design$vcov,"ages18_34")
  stopifnot(abs(100*zold[["estimate"]]-100*old$ref_effect)<0.001,
            abs(100*zold[["se"]]-100*old$ref_se)<0.003)
  pess_check[[outcome]] <- c(zold[["estimate"]],zold[["se"]])
  beta <- coef(f)
  for (group in c("young","older","young_minus_older")) {
    terms <- if (group=="young") c("optim","optim_young") else
             if (group=="older") "optim" else "optim_young"
    weights <- setNames(rep(0,length(beta)),names(beta))
    weights[terms] <- 1
    est <- sum(weights*beta)
    se <- sqrt(max(0,as.numeric(crossprod(weights,design$vcov%*%weights))))
    tstat <- est/se
    pval <- 2*pt(-abs(tstat),df=design$df)
    ccrit <- qt(0.975,df=design$df)
    i <- i+1L
    result[[i]] <- data.table(outcome=outcome, group=group, N=nrow(d),people=uniqueN(d$pidp),
       estimate_pp=100*est,se_pp=100*se,ci_lo_pp=100*(est-ccrit*se),
       ci_hi_pp=100*(est+ccrit*se),t_stat=tstat,p_value=pval,
       design_psus=design$n_psus,design_strata=design$n_strata,design_df=design$df)
  }
}
out <- rbindlist(result)
fwrite(out,file.path(public,"BHPS_CANONICAL_OPTIMISM.csv"))
# Write a LaTeX table, ready to copy into WP_optimism_canonical.tex in Overleaf.
# No stars: planned exploration is reported through intervals and exact p values.
label_outcome <- c(save="Saving at forecast",next_save="Saving at next interview",
                   next_minus_current="Next minus forecast")
fmt <- function(x) sprintf("%+.2f",x)
rows <- c()
for (o in names(label_outcome)) {
  a <- out[outcome==o]
  y <- a[group=="young"]; old <- a[group=="older"]; delta <- a[group=="young_minus_older"]
  ci <- function(z) paste0("[",fmt(z$ci_lo_pp),", ",fmt(z$ci_hi_pp),"]")
  entry <- function(z) paste0("\\ci{",fmt(z$estimate_pp),"}{",ci(z),"}")
  rows <- c(rows,paste0(label_outcome[[o]]," & ",entry(y)," & ",entry(old)," & ",entry(delta)," \\\\"))
}
tex <- c(
 "% Auto-generated from exact canonical BHPS sample; no manual coefficient entry.",
 "\\begin{table}[!htbp]",
 "\\centering",
 "\\begin{threeparttable}",
 "\\small",
 "\\begin{tabular}{@{}lccc@{}}",
 "\\toprule",
 " & Ages 18--34 & Ages 35--59 & Young minus older \\\\",
 "\\midrule",
 rows,
 "\\bottomrule",
 "\\end{tabular}",
 "\\caption{Financial optimism and saving at different horizons: BHPS}",
 "\\label{tab:optimism_canonical}",
 "\\begin{tablenotes}[flushleft]\\footnotesize",
 "\\item \\textit{Notes:} Coefficients for expecting better rather than unchanged finances, in percentage points; brackets give survey-design 95\\% confidence intervals. Models use the same 104,848 pairs, 12,644 respondents, covariates and weights as the main BHPS timing table. The age interaction is the difference between age groups; these are additional descriptive associations. ",
 "\\end{tablenotes}",
 "\\end{threeparttable}",
 "\\end{table}",
 "\\FloatBarrier"
)
writeLines(tex,file.path(public,"WP_optimism_canonical.tex"),useBytes=TRUE)
cat("\nCANONICAL OPTIMISM EXPORT PASS; rows=", nrow(out),"; frozen headline guard PASS\n")
cat("Aggregate outputs: ",public,"\n")
