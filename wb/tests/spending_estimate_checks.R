# Independent re-fit of exported estimates with lm and sandwich; run after 06.
wb_test_spending_estimates <- function(estimates) {
  d <- estimates$gp_terms
  for (y in c("spend", "log_spend")) {
    fit <- stats::lm(stats::as.formula(paste(y, "~", wb_spending_primary_rhs)), data = d)
    primary <- estimates$primary[estimates$primary$outcome == y, ]
    stopifnot(abs(stats::coef(fit)[["women"]] - primary$estimate) < 1e-8)
    hc2 <- sqrt(sandwich::vcovHC(fit, type = "HC2")["women", "women"])
    sens <- estimates$sensitivity
    exported <- sens[sens$model == "HC2 instead of CR2" & sens$outcome == y, ]
    stopifnot(abs(hc2 - exported$std.error) < 1e-8)
    stopifnot(primary$n == nrow(d), primary$units == length(unique(d$block_id)))
  }
  stopifnot(nrow(d) == 1064, sum(d$women) == 155 + 92 + 85 + 33 + 93 + 73)
  cat("Independent spending OLS and HC2 checks passed.\n")
}
