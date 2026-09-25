# Source-data contracts; no outcome regression is run by these checks.
wb_test_contracts <- function(d) {
  stopifnot(nrow(d$gp98) == 166, nrow(d$village98) == 498, nrow(d$gp03) == 165)
  stopifnot(sum(d$gp98$source_complete) == 161, sum(d$gp98$strict) == 158)
  stopifnot(sum(d$village98$prvill == "NO") == 322)
  stopifnot(sum(d$gp03$explicit03) == 163, sum(d$gp03$survey_observed) == 161)
  stopifnot(sum(d$gp03$history_strict) == 151)
  wb_assert_key(d$gp03, "gp_id")
  wb_assert_key(d$village98, c("gpnum", "villnum"))
  missing <- d$gp03$gp[!d$gp03$survey_observed]
  stopifnot(setequal(missing, c("Mongaldihi", "Labhpur-II", "Chandrapur", "Ayas")))
  bad_id <- d$gp03$gp[which(!d$gp03$id_consistent)]
  stopifnot(identical(bad_id, "Ganpur"))
  bad_sex <- d$gp03$gp[which(d$gp03$sex_conflict)]
  stopifnot(setequal(bad_sex, c("Kasba", "Gohaliara")))
  stopifnot(all(is.na(d$gp03$female_followup[which(d$gp03$sex_conflict)])))
  stopifnot(all(!d$gp03$strict03[!d$gp03$explicit03 | !d$gp03$survey_year_valid]))
  stopifnot(identical(wb_yes(c(1, 2, NA, 9, 999)), c(1L, 0L, NA_integer_, NA_integer_, NA_integer_)))
  gate <- c(1, 1, 2, 2, 2, NA, 999, 1, 1)
  amount <- c(5, NA, NA, 0, 7, 4, 0, 999, -999)
  stopifnot(isTRUE(all.equal(wb_quantity(gate, amount), c(5, NA, 0, 0, NA, NA, NA, NA, NA))))
  stopifnot(identical(wb_or(c(1, 0, NA), c(NA, 0, 0)), c(1L, 0L, NA_integer_)))
  observed <- d$gp03$water[!is.na(d$gp03$water)]
  stopifnot(all(observed >= 0), all(is.finite(observed)))
  cat("Source, join, timing, sentinel and missingness contracts passed.\n")
  invisible(TRUE)
}
