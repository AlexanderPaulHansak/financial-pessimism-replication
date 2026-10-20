# Synthetic smoke test of the supplementary covariance implementation.
# Does NOT read licensed survey files or create empirical results.
# From the package folder: Rscript --vanilla SELFTEST_FINAL_CHECKS.R
args <- commandArgs(trailingOnly=FALSE)
farg <- grep("^--file=", args, value=TRUE)
here <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1L]))) else getwd()
source(file.path(here,"FINAL_CHECKS_CORE.R"), local=TRUE)
set.seed(26019)
NID <- 160L
TT <- 5L
n <- NID*TT
sample <- data.table(
 pidp=as.character(rep(seq_len(NID),each=TT)),
 timecell=as.character(rep(seq_len(TT),NID)),
 w_fit=exp(rnorm(n,0,0.25)),
 psu=as.character(rep(ceiling(seq_len(NID)/4),each=TT)),
 strata=as.character(rep(ceiling(seq_len(NID)/40),each=TT)),
 age=rep(sample(18:59,NID,replace=TRUE),each=TT)
)
sample[, w_fit := w_fit / mean(w_fit)]
sample[, pessimism_raw := rbinom(.N,1L,.38)]
sample[, optimism_raw := rbinom(.N,1L,.20)]
sample[, pess := as.numeric(pessimism_raw)]
sample[, optim := as.numeric((optimism_raw==1L)&(pessimism_raw==0L))]
sample[, pess_young := pess*as.numeric(age<=34)]
sample[, optim_young := optim*as.numeric(age<=34)]
sample[, baseline_term := rnorm(.N)]
sample[, y0 := 0.25 + 0.15*pess + 0.05*optim + 0.03*baseline_term + rnorm(.N,0,0.2)]
sample[, y1 := 0.25 - 0.10*pess - 0.02*optim - 0.03*baseline_term + rnorm(.N,0,0.2)]
sample[, yd := y1-y0]
rhs <- c("pess","optim","pess_young","optim_young","baseline_term")
rank <- fp_fe_rank(sample$pidp,sample$timecell)
a <- fp_fit(sample,"y0",rhs,rank)
b <- fp_fit(sample,"y1",rhs,rank)
c <- fp_fit(sample,"yd",rhs,rank)
for (nm in rhs) {
  err <- coef(c$fit)[[nm]] - (coef(b$fit)[[nm]]-coef(a$fit)[[nm]])
  fp_assert(is.finite(err) && abs(err)<1e-7,"Synthetic timing coefficient identity failed")
}
for (fit in list(a,b,c)) {
  z <- fp_linear_contrast(fit,c(pess=1,pess_young=1))
  fp_assert(all(is.finite(z)) && z[["se"]]>0,"Synthetic survey CI invalid")
  fp_assert(fit$design$df == 40L - 4L,"Synthetic PSU-minus-strata df invalid")
}
cat("SYNTHETIC CHECKS PASS: two-way FE, stratified-PSU covariance, CI, timing identity.\n")
