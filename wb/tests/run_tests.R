# Unit tests use synthetic data; the driver also checks acquired-data contracts.
invocation <- grep("^--file=", commandArgs(), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", invocation[1]))))
source(file.path(root, "scripts", "00_common.R"))
source(file.path(root, "tests", "contracts.R"))
stopifnot(is.na(wb_quantity(2, 5)), is.na(wb_quantity(1, 999)), wb_quantity(2, NA) == 0)
x <- data.frame(id = c("01", "02"), y = c(3, 4))
y <- data.frame(id = c("01", "01"), z = c(1, 2))
stopifnot(inherits(try(wb_join(x, y, "id"), silent = TRUE), "try-error"))
set.seed(3401)
toy <- data.frame(gp = rep(1:80, each = 2), treat = rep(rep(0:1, each = 40), each = 2))
toy$y <- 3 * toy$treat + rep(stats::rnorm(80), each = 2) + stats::rnorm(160)
fit <- wb_estimate(toy, "y", "treat", "treat", "Synthetic", "gp")
delta <- with(toy, mean(y[treat == 1]) - mean(y[treat == 0]))
stopifnot(
  abs(fit$estimate - delta) < 1e-10, fit$units == 80, fit$treated_units == 40,
  fit$se_type == "CR2", fit$conf.low < fit$conf.high
)
manual <- sandwich::vcovCL(stats::lm(y ~ treat, data = toy),
  cluster = toy$gp,
  type = "HC0", cadjust = FALSE
)
cr0 <- wb_estimate(toy, "y", "treat", "treat", "Synthetic", "gp", "CR0")
stopifnot(abs(cr0$std.error - sqrt(manual["treat", "treat"])) < 1e-10)
power <- wb_power(0.01, 0.05)
stopifnot(
  all(power$normal_model_power > 0 & power$normal_model_power < 1),
  all(power$type_s > 0 & power$type_s < 0.5), all(power$type_m > 1)
)
cat("Synthetic estimator, covariance, key and recode tests passed.\n")

source(file.path(root, "scripts", "02_nadia_demand.R"))
source(file.path(root, "tests", "nadia_contracts.R"))
source_root <- Sys.getenv("WB_LOCAL_ELECTIONS", unset = file.path(root, "../../local_elections"))
wb_test_nadia_synthetic()
wb_test_nadia_contracts(wb_nadia_prepare(normalizePath(source_root), root))
cat("Nadia source, identity, missingness and design-support tests passed.\n")
wb_test_nadia_rederivation(root)
