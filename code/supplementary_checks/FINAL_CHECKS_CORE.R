# Shared estimator used ONLY for exploratory checks.
# Faithfully mirrors the already verified 2026-10-16 R/fixest convention:
#   two-way FE, normalized original w_fit, stratum-centered PSU scores,
#   singleton stratum outer product, FE-rank finite-sample correction,
#   survey df = PSU count minus stratum count.
# The frozen canonical Python and independent R code are NEVER modified.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

fp_log <- function(...) {
  cat(sprintf("[%s] ", format(Sys.time(), "%H:%M:%S")), ..., "\n", sep = "")
  flush.console()
}

fp_assert <- function(ok, message) {
  if (!isTRUE(ok)) stop(message, call. = FALSE)
}

fp_safe_id <- function(x) {
  x <- as.character(x)
  ix <- !is.na(x) & grepl("^[0-9]+\\.0+$", x)
  x[ix] <- sub("\\.0+$", "", x[ix])
  x
}

fp_fe_rank <- function(person, timecell) {
  p <- match(person, unique(person))
  t <- match(timecell, unique(timecell))
  np <- max(p)
  nt <- max(t)
  parent <- seq_len(np + nt)
  sz <- rep.int(1L, np + nt)
  root <- function(j) {
    while (parent[j] != j) j <- parent[j]
    j
  }
  for (i in seq_along(p)) {
    a <- root(p[i]); b <- root(np + t[i])
    if (a != b) {
      if (sz[a] < sz[b]) {z <- a; a <- b; b <- z}
      parent[b] <- a
      sz[a] <- sz[a] + sz[b]
    }
  }
  ncomp <- length(unique(vapply(seq_along(parent), root, integer(1))))
  np + nt - ncomp
}

fp_survey_vcov <- function(fit, d, fe_rank) {
  beta <- coef(fit)
  nm <- names(beta)
  X <- fit$X_demeaned
  y <- fit$y_demeaned
  fp_assert(!is.null(X) && !is.null(y), "fixest did not retain demeaned matrices")
  X <- as.matrix(X)
  fp_assert(all(nm %in% colnames(X)), "Demeaned columns differ from named fitted coefficients")
  X <- X[, nm, drop = FALSE]
  y <- as.numeric(y)
  w <- as.numeric(d$w_fit)
  fp_assert(nrow(X) == nrow(d) && length(y) == nrow(d), "Model fit changed rows")
  fp_assert(all(is.finite(w) & w > 0), "Invalid fixed-sample weights")
  sw <- sqrt(w)
  wx <- X * sw
  resid_dm <- y - as.numeric(X %*% beta)
  score <- wx * (sw * resid_dm)
  bread <- solve(crossprod(wx))
  key <- paste(d$strata, d$psu, sep = "__PSU__")
  sums <- rowsum(score, group = key, reorder = FALSE)
  psu_strata <- as.character(d$strata[match(rownames(sums), key)])
  fp_assert(!anyNA(psu_strata), "Cannot align PSU scores to strata")
  fp_assert(nrow(sums) == uniqueN(key), "PSU count changed during aggregation")
  K <- length(beta)
  meat <- matrix(0, K, K)
  singleton <- 0L
  for (h in unique(psu_strata)) {
    j <- which(psu_strata == h)
    m <- length(j)
    s <- sums[j, , drop = FALSE]
    if (m > 1L) {
      s <- sweep(s, 2L, colMeans(s), FUN = "-")
      meat <- meat + (m / (m - 1)) * crossprod(s)
    } else {
      singleton <- singleton + 1L
      meat <- meat + crossprod(s)
    }
  }
  N <- nrow(d)
  fp_assert(N > fe_rank + K, "Residual degrees of freedom nonpositive")
  V <- bread %*% meat %*% bread * (N - 1) / (N - fe_rank - K)
  V <- (V + t(V)) / 2
  dimnames(V) <- list(nm, nm)
  fp_assert(all(is.finite(V)) && all(diag(V) > -1e-9), "Invalid survey covariance")
  df <- nrow(sums) - uniqueN(psu_strata)
  fp_assert(df > 2, "Insufficient survey design degrees of freedom")
  list(V = V, df = df, psus = nrow(sums), strata = uniqueN(psu_strata),
       singletons = singleton, K = K, fe_rank = fe_rank)
}

fp_fit <- function(d, y, rhs, fe_rank = NULL, verbose = TRUE) {
  fp_assert(y %in% names(d), paste("Missing outcome:", y))
  fp_assert(length(rhs) > 3 && !anyDuplicated(rhs), "Invalid RHS term set")
  fp_assert(all(rhs %in% names(d)), paste("Missing RHS columns for", y))
  needed <- c("pidp", "timecell", "psu", "strata", "w_fit", y, rhs)
  fp_assert(!anyNA(d[, ..needed]), paste("Unintended missing estimation data for", y))
  fp_assert(all(is.finite(as.matrix(d[, ..rhs]))), paste("Nonfinite RHS term for", y))
  fp_assert(all(is.finite(d[[y]])), paste("Nonfinite outcome:", y))
  if (is.null(fe_rank)) fe_rank <- fp_fe_rank(d$pidp, d$timecell)
  if (verbose) fp_log("FIT ", y, " | N=", nrow(d), " people=", uniqueN(d$pidp),
                       " RHS=", length(rhs), " FE_rank=", fe_rank)
  f <- as.formula(paste0(y, " ~ ", paste(rhs, collapse = " + "), " | pidp + timecell"))
  t0 <- Sys.time()
  fit <- feols(f, data = d, weights = ~w_fit, vcov = ~pidp,
               fixef.rm = "none", fixef.tol = 1e-10, fixef.iter = 20000,
               collin.tol = 1e-10, demeaned = TRUE,
               nthreads = 2, notes = FALSE, warn = TRUE)
  fp_assert(nobs(fit) == nrow(d), "R fit silently changed estimation N")
  design <- fp_survey_vcov(fit, d, fe_rank)
  if (verbose) fp_log("  DONE ", y, " | design PSU=", design$psus,
                      " strata=", design$strata, " df=", design$df,
                      " | sec=", round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1))
  list(fit = fit, design = design, people = uniqueN(d$pidp))
}

fp_linear_contrast <- function(model, weights) {
  b <- coef(model$fit)
  V <- model$design$V
  nm <- names(weights)
  fp_assert(all(nm %in% names(b)), paste("Contrast not identified:", paste(setdiff(nm,names(b)),collapse=",")))
  l <- setNames(rep(0, length(b)), names(b))
  l[nm] <- weights
  est <- sum(l * b)
  variance <- drop(crossprod(l, V %*% l))
  fp_assert(is.finite(variance) && variance > -1e-9, "Contrast variance invalid")
  se <- sqrt(max(0, variance))
  df <- model$design$df
  crit <- qt(0.975, df = df)
  p <- if (se > 0) 2 * pt(-abs(est / se), df = df) else NA_real_
  c(estimate = est, se = se, ci_low = est-crit*se,
    ci_high = est+crit*se, p = p, df = df)
}

fp_standard_weights <- function(type = c("pess", "optim")) {
  type <- match.arg(type)
  list(ages18_34 = setNames(c(1,1),c(type,paste0(type,"_young"))),
       ages35_59 = setNames(1, type),
       young_minus_older = setNames(1, paste0(type,"_young")))
}

fp_wald_test <- function(model, names_terms) {
  b <- coef(model$fit)
  V <- model$design$V
  fp_assert(all(names_terms %in% names(b)), "Terms unavailable in Wald test")
  theta <- as.numeric(b[names_terms])
  vv <- V[names_terms, names_terms, drop = FALSE]
  Fstat <- drop(crossprod(theta, solve(vv, theta))) / length(theta)
  p <- pf(Fstat, df1 = length(theta), df2 = model$design$df, lower.tail = FALSE)
  c(F = Fstat, df1 = length(theta), df2 = model$design$df, p = p)
}

fp_new_store <- function() {
  env <- new.env(parent = emptyenv())
  env$estimates <- list()
  env$coverage <- list()
  env$tests <- list()
  env
}

fp_add_est <- function(store, stage, spec, outcome, comparison, model,
                       weights, scale = "probability", extra_note = "") {
  z <- fp_linear_contrast(model, weights)
  mult <- if (scale == "probability") 100 else 1
  store$estimates[[length(store$estimates)+1L]] <- data.table(
    stage = stage, specification = spec, outcome = outcome,
    comparison = comparison, outcome_scale = scale,
    estimate = unname(z["estimate"]), se = unname(z["se"]),
    lo95 = unname(z["ci_low"]), hi95 = unname(z["ci_high"]),
    estimate_display = unname(z["estimate"]) * mult,
    se_display = unname(z["se"]) * mult,
    lo95_display = unname(z["ci_low"]) * mult,
    hi95_display = unname(z["ci_high"]) * mult,
    unit_display = if (scale == "probability") "percentage points" else scale,
    p_two_sided = unname(z["p"]),
    N = nobs(model$fit), people = model$people, psus = model$design$psus,
    strata = model$design$strata, survey_df = model$design$df,
    note = extra_note)
  invisible(z)
}

fp_add_three <- function(store, stage, spec, outcome, model,
                         type = "pess", scale = "probability", note = "") {
  w <- fp_standard_weights(type)
  for (lab in names(w)) fp_add_est(store, stage, spec, outcome,
                                   paste0(type,"_",lab), model, w[[lab]], scale, note)
}

fp_add_coverage <- function(store, stage, measure, group, n, n_valid, weighted_valid_share = NA_real_, note = "") {
  fp_assert(n >= n_valid && n_valid >= 0, "Invalid coverage counts")
  store$coverage[[length(store$coverage)+1L]] <- data.table(
    stage = stage, measure = measure, group = group, n = as.integer(n),
    valid_n = as.integer(n_valid), valid_share = if (n > 0) n_valid/n else NA_real_,
    valid_weight_share = weighted_valid_share, note = note)
}

fp_write_store <- function(store, directory) {
  if (length(store$estimates)) fwrite(rbindlist(store$estimates, fill = TRUE),
                                      file.path(directory, "REGRESSION_CONTRASTS.csv"))
  if (length(store$coverage)) fwrite(rbindlist(store$coverage, fill = TRUE),
                                     file.path(directory, "COVERAGE_AUDIT.csv"))
  if (length(store$tests)) fwrite(rbindlist(store$tests, fill = TRUE),
                                  file.path(directory, "HETEROGENEITY_TESTS.csv"))
}

fp_screen_private <- function(path) {
  p <- tolower(gsub("\\\\", "/", normalizePath(path, winslash = "/", mustWork = FALSE)))
  fp_assert(!grepl("(^|/)(dropbox|onedrive|google drive|google_drive)(/|$)", p),
            "Licensed data root appears to be cloud-synced: set FP_UK_DERIVED to C:/Hansak/Data/UKHLS_derived")
}
