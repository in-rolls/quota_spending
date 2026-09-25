# Run after sourcing 00_common.R and 02_nadia_demand.R; no source file is modified.
wb_test_nadia_synthetic <- function() {
  code <- wb_nadia_reservation(c("UR", "Women", "SC", "SCW", "OBCW", "ST", NA, ""))
  stopifnot(identical(code$q13, c(0, 1, 0, 1, 1, 0, NA_real_, NA_real_)))
  stopifnot(all(is.na(code$caste13[7:8])))
  stopifnot(inherits(try(wb_nadia_reservation("unexpected"), silent = TRUE), "try-error"))
  stopifnot(identical(
    wb_nadia_key(c("Ramnagar-I", "ramnagar i", "Ramnagar-1")),
    c("RAMNAGARI", "RAMNAGARI", "RAMNAGAR1")
  ))
  stopifnot(identical(wb_nadia_unique(c("A", "B", "A", "C")), c(FALSE, TRUE, FALSE, TRUE)))
  months <- c(
    "April", "May", "June", "July", "August", "September", "October",
    "November", "December", "January", "February", "March"
  )
  x <- as.data.frame(matrix(1, nrow = 3, ncol = 12))
  names(x) <- paste("Month wise Household and Persons", months, "Household", sep = "|")
  x[2, 3] <- NA_real_
  x[3, ] <- 0
  stopifnot(identical(wb_nadia_months(x, "Household"), c(12, NA_real_, 0)))
  x[1, 2] <- -1
  stopifnot(inherits(try(wb_nadia_months(x, "Household"), silent = TRUE), "try-error"))
  stopifnot(inherits(try(wb_nadia_months(x[, -1], "Household"), silent = TRUE), "try-error"))
  scratch <- tempfile("nadia_manifest_")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  roles <- c("office_roster", "block_membership", "demand_2012", "demand_2014", "analysis_plan")
  files <- paste0(roles, ".txt")
  for (file in files) writeLines(file, file.path(scratch, file))
  manifest <- data.frame(
    role = roles, root = "module", path = files,
    sha256 = vapply(file.path(scratch, files), function(f) {
      digest::digest(
        file = f,
        algo = "sha256"
      )
    }, character(1))
  )
  write.csv(manifest, file.path(scratch, "nadia_source_manifest.csv"), row.names = FALSE)
  stopifnot(length(wb_nadia_read_manifest(scratch, scratch)) == 5)
  writeLines("changed evidence", file.path(scratch, files[1]))
  stopifnot(inherits(try(wb_nadia_read_manifest(scratch, scratch), silent = TRUE), "try-error"))
  invisible(TRUE)
}

wb_test_nadia_contracts <- function(prepared) {
  x <- prepared$audit
  stopifnot(nrow(x) == 187, !anyDuplicated(x$row_id), nrow(prepared$demand_panel) == 187)
  stopifnot(sum(x$membership_matched) == 161, sum(x$demand_matched) == 101)
  stopifnot(sum(x$linked_complete_eligible) == 101, sum(x$analysis_eligible) == 100)
  stopifnot(sum(x$q13[x$analysis_eligible]) == 50)
  stopifnot(all(!x$analysis_eligible[!x$office_name_unique]))
  unknown <- x$gram_panchayat == "Taldaha Majdia"
  stopifnot(sum(unknown) == 1, is.na(x$q13[unknown]), !x$analysis_eligible[unknown])
  excluded <- x$singleton_caste_no_residual_support
  stopifnot(sum(excluded) == 1, x$gram_panchayat[excluded] == "Gobindapur")
  stopifnot(all(complete.cases(x[
    x$analysis_eligible,
    c("membership_row_id", "membership_source_page", "membership_source_bbox", "demand_key")
  ])))
  stopifnot(!anyDuplicated(x$demand_key[x$analysis_eligible]))
  for (unit in c("household_months", "person_months")) {
    f <- as.formula(paste(
      "~ q13 +", paste0(unit, "_2012"),
      "+ factor(block_printed) + factor(caste13)"
    ))
    design <- model.matrix(f, x[x$analysis_eligible, ])
    qr_design <- qr(design)
    h <- rowSums(qr.Q(qr_design)[, seq_len(qr_design$rank), drop = FALSE]^2)
    stopifnot(qr_design$rank == ncol(design), max(h) < 1 - 1e-10)
  }
  invisible(TRUE)
}

wb_test_nadia_rederivation <- function(root) {
  x <- utils::read.csv(file.path(root, "data", "nadia_demand_analysis.csv"))
  estimates <- utils::read.csv(file.path(root, "tabs", "nadia_demand.csv"))
  primary <- subset(estimates, model == "Primary baseline-adjusted")
  stopifnot(nrow(primary) == 2L)
  for (unit in c("household_months", "person_months")) {
    outcome <- paste0(unit, "_2014")
    formula <- stats::as.formula(paste(
      outcome, "~ q13 +", paste0(unit, "_2012"), "+ factor(block_printed) + factor(caste13)"
    ))
    fit <- stats::lm(formula, data = x)
    reference <- primary[primary$outcome == outcome, ]
    se <- sqrt(sandwich::vcovHC(fit, type = "HC2")["q13", "q13"])
    stopifnot(nrow(reference) == 1L, abs(stats::coef(fit)["q13"] - reference$estimate) < 1e-7)
    stopifnot(abs(se - reference$std.error) < 1e-7, stats::df.residual(fit) == reference$df)
    interval <- stats::coef(fit)["q13"] + c(-1, 1) * stats::qt(0.975, reference$df) * se
    stopifnot(max(abs(interval - c(reference$conf.low, reference$conf.high))) < 1e-7)
  }
  stopifnot(max(abs(primary$p_holm - stats::p.adjust(primary$p.value, "holm"))) < 1e-12)
  cat("Independent Nadia OLS, HC2, interval and multiplicity checks passed.\n")
}
