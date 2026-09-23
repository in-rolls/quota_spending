# Run the WB preparation, checks and analysis from any working directory.
main <- function() {
  invocation <- grep("^--file=", commandArgs(), value = TRUE)
  root <- dirname(normalizePath(sub("^--file=", "", invocation[1])))
  source_root <- Sys.getenv("WB_LOCAL_ELECTIONS", unset = file.path(root, "../../local_elections"))
  shared_root <- root
  packages <- c("haven", "arrow", "dplyr", "digest", "jsonlite", "estimatr", "broom", "knitr", "ggplot2")
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Install R packages: ", paste(missing, collapse = ", "))
  dir.create(file.path(root, "logs"), showWarnings = FALSE)
  sink(file.path(root, "logs", "run.log"), split = TRUE)
  on.exit(sink(), add = TRUE)
  cat("Started:", format(Sys.time(), tz = "UTC"), "UTC\n")
  source(file.path(shared_root, "scripts", "00_common.R"))
  d <- wb_prepare(normalizePath(source_root), root, shared_root)
  d <- wb_outcomes(d, root)
  source(file.path(shared_root, "tests", "contracts.R"))
  wb_test_contracts(d)
  source(file.path(root, "scripts", "02_nadia_demand.R"))
  source(file.path(root, "tests", "nadia_contracts.R"))
  wb_test_nadia_synthetic()
  wb_test_nadia_contracts(wb_nadia_prepare(normalizePath(source_root), root))
  if (!"--prepare-only" %in% commandArgs(trailingOnly = TRUE)) {
    source(file.path(root, "scripts", "01_public_goods.R"))
    wb_public_goods(d, root)
    nadia <- wb_nadia_demand(normalizePath(source_root), root)
    source(file.path(root, "scripts", "03_nadia_report.R"))
    wb_nadia_report(nadia, root)
  }
  capture.output(sessionInfo(), file = file.path(root, "logs", "sessionInfo.txt"))
  cat("Completed:", format(Sys.time(), tz = "UTC"), "UTC\n")
}
main()
