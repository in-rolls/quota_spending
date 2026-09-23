# Run after sourcing 00_common.R and 05_spending_prep.R; no source file is modified.
wb_test_spending_synthetic <- function() {
  scratch <- tempfile("spending_manifest_")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  writeLines("a", file.path(scratch, "input.txt"))
  manifest <- data.frame(
    role = "input", root = "module", path = "input.txt",
    sha256 = digest::digest(file = file.path(scratch, "input.txt"), algo = "sha256")
  )
  utils::write.csv(manifest, file.path(scratch, "spending_source_manifest.csv"), row.names = FALSE)
  stopifnot(identical(unname(wb_spending_manifest(scratch, scratch)), file.path(scratch, "input.txt")))
  writeLines("tampered", file.path(scratch, "input.txt"))
  stopifnot(inherits(try(wb_spending_manifest(scratch, scratch), silent = TRUE), "try-error"))
  cat("Spending manifest tamper test passed.\n")
}

wb_test_spending_contracts <- function(result, source_root) {
  panel <- result$panel
  audit <- result$audit
  checks <- jsonlite::fromJSON(file.path(source_root, "data/wb/derived/pradhan_gp/checks.json"))

  # every reserved GP is in every fiscal year of its term, or its absence is recorded
  stopifnot(all(audit$in_r6 | nzchar(audit$exclusion_reason)))
  stopifnot(sum(audit$in_r6) == nrow(panel))

  # each GP x fiscal year once; fiscal years lie inside the term's window
  stopifnot(!anyDuplicated(panel[c("term", "gp_key", "fy")]), is.logical(panel$woman_reserved))
  for (term in names(wb_spending_windows)) {
    stopifnot(all(panel$fy[panel$term == as.integer(term)] %in% wb_spending_windows[[term]]))
  }

  # the reservation carried into the panel still reproduces the printed totals
  for (i in seq_len(nrow(checks))) {
    rows <- panel$district == checks$district[i] & panel$term == checks$term[i]
    gps <- unique(panel[rows, c("gp_key", "woman_reserved", "caste_reservation")])
    stopifnot(
      nrow(gps) == checks$printed$offices[i],
      sum(gps$woman_reserved) == checks$printed$women[i],
      sum(gps$caste_reservation == "SC") == checks$printed$SC[i],
      sum(gps$caste_reservation == "ST") == checks$printed$ST[i],
      sum(gps$caste_reservation == "BC") == checks$printed$BC[i]
    )
  }

  # total spending is the sum of its two parts, and never negative
  stopifnot(isTRUE(all.equal(panel$spend_total, panel$spend_completed + panel$spend_ongoing)))
  stopifnot(all(panel$spend_total >= 0, na.rm = TRUE))

  # the measure moves with employment: across GPs every year, and in the freeze
  v <- result$validation
  stopifnot(all(v$gp_rank_correlation > 0.5))
  stopifnot(v$spend_crore[v$fy == 2022] < 0.2 * v$spend_crore[v$fy == 2021])
  cat("Spending contracts passed:", nrow(panel), "GP-years.\n")
}
