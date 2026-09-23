# Shared West Bengal source preparation and explicit model inference.
# Writes typed analysis inputs and identifier/quality audits to the caller's wb/.

wb_key <- function(x) gsub("[^A-Z0-9]", "", toupper(trimws(x)))

wb_assert_key <- function(x, key) {
  stopifnot(all(stats::complete.cases(x[key])), !anyDuplicated(x[key]))
  invisible(x)
}

wb_join <- function(x, y, by, relationship = "many-to-one") {
  n <- nrow(x)
  out <- dplyr::left_join(x, y, by = by, relationship = relationship)
  stopifnot(nrow(out) == n)
  out
}

wb_yes <- function(x) {
  x <- as.numeric(x)
  ifelse(x == 1, 1L, ifelse(x == 2, 0L, NA_integer_))
}

wb_quantity <- function(gate, amount) {
  gate <- as.numeric(gate)
  amount <- as.numeric(amount)
  valid <- !is.na(amount) & amount >= 0 & !amount %in% c(999, -999)
  out <- rep(NA_real_, length(amount))
  no <- !is.na(gate) & gate == 2 & (is.na(amount) | amount == 0)
  yes <- !is.na(gate) & gate == 1 & valid
  out[no] <- 0
  out[yes] <- amount[yes]
  out
}

wb_save <- function(x, stem, out) {
  path <- file.path(out, "data", stem)
  arrow::write_parquet(x, paste0(path, ".parquet"))
  utils::write.csv(x, paste0(path, ".csv"), row.names = FALSE, na = "")
  stopifnot(isTRUE(all.equal(
    as.data.frame(x), as.data.frame(arrow::read_parquet(paste0(path, ".parquet"))),
    check.attributes = FALSE
  )))
}

wb_profile <- function(datasets, out) {
  rows <- list()
  for (nm in names(datasets)) {
    d <- datasets[[nm]]
    for (col in names(d)) {
      x <- d[[col]]
      counts <- sort(table(as.character(x), useNA = "always"), decreasing = TRUE)
      lab <- attr(x, "label")
      values <- attr(x, "labels")
      rows[[length(rows) + 1L]] <- data.frame(
        source = nm, variable = col,
        label = if (is.null(lab)) "" else lab,
        value_labels = as.character(jsonlite::toJSON(as.list(values), auto_unbox = TRUE)),
        rows = length(x), missing = sum(is.na(x)),
        distinct = dplyr::n_distinct(x, na.rm = TRUE),
        common_values = paste(names(head(counts, 3)), head(counts, 3), collapse = "; "),
        stringsAsFactors = FALSE
      )
    }
  }
  utils::write.csv(dplyr::bind_rows(rows), file.path(out, "data", "source_dictionary.csv"),
    row.names = FALSE, na = ""
  )
}

wb_prepare <- function(source_root, out, shared_root) {
  for (p in c("data", "tabs", "figs", "logs")) {
    dir.create(file.path(out, p), recursive = TRUE, showWarnings = FALSE)
  }
  manifest <- utils::read.csv(file.path(shared_root, "source_manifest.csv"),
    colClasses = "character"
  )
  paths <- stats::setNames(file.path(source_root, manifest$path), manifest$role)
  for (i in seq_len(nrow(manifest))) {
    stopifnot(file.exists(paths[i]))
    if (digest::digest(file = paths[i], algo = "sha256") != manifest$sha256[i]) {
      stop("Source checksum mismatch: ", paths[i])
    }
  }
  tmp <- tempfile("wb_stata_")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  members <- paste0("womenpolicymakers_part", letters[1:4], ".dta")
  utils::unzip(paths[["cd_survey"]], files = members, exdir = tmp)
  original <- stats::setNames(
    lapply(file.path(tmp, members), haven::read_dta),
    c("cd_a", "cd_b", "cd_c", "cd_d")
  )
  original$reservations <- haven::read_dta(paths[["beaman_reservations"]])
  original$survey <- haven::read_dta(paths[["beaman_pradhan_survey"]])
  wb_profile(original, out)
  raw <- lapply(original, function(x) as.data.frame(haven::zap_labels(x)))
  a <- raw$cd_a
  b <- raw$cd_b
  c <- raw$cd_c
  d <- raw$cd_d
  r <- raw$reservations
  s <- raw$survey
  stopifnot(
    nrow(a) == 166, nrow(b) == 166, nrow(c) == 498, nrow(d) == 498,
    nrow(r) == 165, nrow(s) == 316
  )
  wb_assert_key(a, "gpnum")
  wb_assert_key(b, "gpnum")
  wb_assert_key(c, c("gpnum", "villnum"))
  wb_assert_key(d, c("gpnum", "villnum"))
  wb_assert_key(r, "AA0_2b")
  stopifnot(setequal(a$gpnum, b$gpnum))
  gp_ids <- b[c("gpnum", "gpnamep", "blockp")]
  gp_ids$gpnum <- as.character(gp_ids$gpnum)
  wb_save(gp_ids, "cd_gp_identifiers", out)
  village_ids <- d[c("gpnum", "villnum", "villname", "jlnum", "blckp", "dubdiv")]
  village_ids$gpnum <- as.character(village_ids$gpnum)
  village_ids$villnum <- as.character(village_ids$villnum)
  village_ids <- wb_join(village_ids, gp_ids, "gpnum")
  village_ids$missing_village_name <- trimws(village_ids$villname) == ""
  wb_save(village_ids, "cd_village_identifiers", out)
  beaman_ids <- r[c("res_id", "AA0_2b", "block", "gp")]
  beaman_ids[c("res_id", "AA0_2b")] <- lapply(
    beaman_ids[c("res_id", "AA0_2b")], as.character
  )
  wb_save(beaman_ids, "beaman_gp_identifiers", out)

  gp98 <- wb_join(a, b, "gpnum", "one-to-one")
  gp98$gp_id <- as.character(gp98$gpnum)
  gp98$gp <- gp98$gpnamep
  gp98$block <- gp98$blockp
  gp98$q98 <- wb_yes(gp98$womres)
  gp98$sc98 <- wb_yes(gp98$scres)
  gp98$st98 <- wb_yes(gp98$stres)
  gp98$female98 <- ifelse(gp98$prsex %in% c(1, 2), as.integer(gp98$prsex == 2), NA)
  gp98$source_complete <- stats::complete.cases(gp98[c("q98", "sc98", "st98")])
  gp98$caste_contradiction <- !is.na(gp98$sc98) & !is.na(gp98$st98) &
    gp98$sc98 == 1 & gp98$st98 == 1
  gp98$strict <- gp98$source_complete & !gp98$caste_contradiction

  gp03 <- data.frame(
    gp_id = as.character(r$AA0_2b), reservation_id = as.character(r$res_id),
    gp = r$gp, block = r$block, q03 = wb_yes(r$res_woman),
    sc03 = wb_yes(r$res_sc), st03 = wb_yes(r$res_st),
    q98 = wb_yes(r$prev_res_woman), sc98 = wb_yes(r$prev_res_sc),
    st98 = wb_yes(r$prev_res_st), explicit03 = r$year == 1,
    explicit98 = r$prev_year == 1,
    current_year_raw = r$year, current_other_year_raw = r$year_2,
    current_other_year_888_raw = r$year_888,
    previous_year_raw = r$prev_year, previous_start_raw = r$prev_year_888_1,
    previous_end_raw = r$prev_year_888_2, stringsAsFactors = FALSE
  )
  gp03$explicit03[is.na(gp03$explicit03)] <- FALSE
  gp03$explicit98[is.na(gp03$explicit98)] <- FALSE
  gp03$previous_within_1998_term <- gp03$explicit98 | (
    !is.na(gp03$previous_start_raw) & !is.na(gp03$previous_end_raw) &
      gp03$previous_start_raw >= 1998 & gp03$previous_start_raw < 2003 &
      gp03$previous_end_raw >= gp03$previous_start_raw & gp03$previous_end_raw <= 2003
  )
  gp03$previous_within_1998_term[is.na(gp03$previous_within_1998_term)] <- FALSE
  gp03$q98[!gp03$previous_within_1998_term] <- NA
  gp03$sc98[!gp03$previous_within_1998_term] <- NA
  gp03$st98[!gp03$previous_within_1998_term] <- NA

  left <- data.frame(
    key = paste(wb_key(gp98$block), wb_key(gp98$gp), sep = "|"),
    cd_gp_id = gp98$gp_id, q98_cd = gp98$q98, sc98_cd = gp98$sc98, st98_cd = gp98$st98
  )
  right <- data.frame(
    key = paste(wb_key(gp03$block), wb_key(gp03$gp), sep = "|"),
    beaman_gp_id = gp03$gp_id, q98_beaman = gp03$q98,
    sc98_beaman = gp03$sc98, st98_beaman = gp03$st98
  )
  audit <- dplyr::full_join(left, right, by = "key", relationship = "one-to-one")
  audit$conflict <- FALSE
  for (v in c("q98", "sc98", "st98")) {
    x <- audit[[paste0(v, "_cd")]]
    y <- audit[[paste0(v, "_beaman")]]
    audit$conflict <- audit$conflict | (!is.na(x) & !is.na(y) & x != y)
  }
  gp98$cross_source_conflict <- gp98$gp_id %in% audit$cd_gp_id[audit$conflict]
  gp98$strict <- gp98$strict & !gp98$cross_source_conflict
  gp03$cross_source_conflict98 <- gp03$gp_id %in% audit$beaman_gp_id[audit$conflict]
  gp03$history_strict <- gp03$explicit98 & !gp03$cross_source_conflict98
  wb_save(audit, "cross_source_name_audit", out)

  current <- s[!is.na(s$A0_9) & s$A0_9 == 1, ]
  wb_assert_key(current, "temp_id")
  current$gp_id <- as.character(current$temp_id)
  current$survey_gp <- current$AA0_2a
  current$survey_block <- current$AA0_1a
  current$id_consistent <- !is.na(current$AA0_2b) & current$AA0_2b == current$temp_id
  current$female_a0 <- ifelse(current$A0_5 %in% c(1, 2),
    as.integer(current$A0_5 == 2), NA
  )
  current$female_a1 <- ifelse(current$A1_2 %in% c(1, 2),
    as.integer(current$A1_2 == 2), NA
  )
  current$female_a8 <- wb_yes(current$A8_13_chk)
  conflict_a0 <- !is.na(current$female_a0) & !is.na(current$female_a8) &
    current$female_a0 != current$female_a8
  conflict_a1 <- !is.na(current$female_a1) & !is.na(current$female_a8) &
    current$female_a1 != current$female_a8
  current$sex_conflict <- conflict_a0 | conflict_a1
  current$female_followup <- ifelse(current$sex_conflict, NA, current$female_a8)
  current$survey_observed <- TRUE
  gp03 <- wb_join(gp03, current, "gp_id", "one-to-one")
  gp03$survey_observed[is.na(gp03$survey_observed)] <- FALSE
  gp03$strict03 <- gp03$explicit03 & gp03$survey_observed &
    !is.na(gp03$id_consistent) & gp03$id_consistent
  gp03$exact_gp_name <- !is.na(gp03$survey_gp) & wb_key(gp03$survey_gp) == wb_key(gp03$gp)
  survey_audit <- gp03[c(
    "gp_id", "reservation_id", "gp", "block", "survey_gp", "survey_block",
    "pradhanhh_uniqueid", "temp_id", "AA0_2b", "id_consistent", "survey_observed",
    "exact_gp_name", "explicit03", "history_strict", "pradhan_spouse",
    "female_a0", "female_a1", "female_a8", "sex_conflict", "female_followup"
  )]
  wb_save(survey_audit, "beaman_survey_join_audit", out)
  village98 <- wb_join(c, d, c("gpnum", "villnum"), "one-to-one")
  village98$gp_id <- as.character(village98$gpnum)
  village98 <- wb_join(village98, gp98[c(
    "gp_id", "gp", "block", "q98", "sc98", "st98", "source_complete", "strict"
  )], "gp_id")
  list(
    gp98 = gp98, village98 = village98, gp03 = gp03,
    audit = audit, raw = raw, manifest = manifest
  )
}

wb_estimate <- function(data, outcome, rhs, term, model, cluster = NULL, se_type = NULL) {
  formula <- stats::as.formula(paste(outcome, "~", rhs))
  fields <- unique(c(all.vars(formula), cluster))
  data <- data[stats::complete.cases(data[fields]), , drop = FALSE]
  if (nrow(data) < 10 || length(unique(data[[term]])) < 2) {
    stop("Insufficient variation for ", model, ": ", outcome)
  }
  if (is.null(cluster)) {
    fit <- estimatr::lm_robust(
      formula,
      data = data,
      se_type = if (is.null(se_type)) "HC2" else se_type
    )
  } else {
    fit <- estimatr::lm_robust(formula,
      data = data,
      clusters = data[[cluster]],
      se_type = if (is.null(se_type)) "CR2" else se_type
    )
  }
  result <- broom::tidy(fit, conf.int = TRUE)
  result$model <- model
  result$outcome <- outcome
  result$n <- nrow(data)
  result$units <- if (is.null(cluster)) nrow(data) else dplyr::n_distinct(data[[cluster]])
  result$treated_units <- if (is.null(cluster)) {
    sum(data[[term]] == 1)
  } else {
    dplyr::n_distinct(data[[cluster]][data[[term]] == 1])
  }
  result$se_type <- fit$se_type
  result <- result[result$term == term, ]
  if (nrow(result) != 1 || !is.finite(result$std.error)) {
    stop("Unidentified model: ", model, ": ", outcome)
  }
  result
}

wb_table <- function(x, stem, out) {
  utils::write.csv(x, file.path(out, "tabs", paste0(stem, ".csv")),
    row.names = FALSE, na = ""
  )
  if (all(c("estimate", "conf.low", "conf.high", "outcome", "model") %in% names(x))) {
    show <- x[c("model", "outcome", "estimate", "conf.low", "conf.high", "n", "se_type")]
    text <- knitr::kable(show, format = "latex", booktabs = TRUE, digits = 3)
    writeLines(text, file.path(out, "tabs", paste0(stem, ".tex")))
  }
}

wb_plot <- function(x, stem, out, title, xlab) {
  x$label <- x$model
  p <- ggplot2::ggplot(x, ggplot2::aes(x = estimate, y = label)) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = conf.low, xmax = conf.high),
      orientation = "y", width = 0.15
    ) +
    ggplot2::geom_point(size = 2) +
    ggplot2::theme_bw(base_size = 10) +
    ggplot2::labs(title = title, x = xlab, y = NULL)
  if (length(unique(x$outcome)) > 1) {
    p <- p + ggplot2::facet_wrap(~outcome, scales = "free", ncol = 1)
  }
  ggplot2::ggsave(file.path(out, "figs", paste0(stem, ".pdf")), p,
    width = 9, height = max(3, 0.32 * nrow(x) + 1.5)
  )
  ggplot2::ggsave(file.path(out, "figs", paste0(stem, ".png")), p,
    width = 9, height = max(3, 0.32 * nrow(x) + 1.5), dpi = 160
  )
}

wb_or <- function(x, y) {
  ifelse(x == 1 | y == 1, 1L, ifelse(x == 0 & y == 0, 0L, NA_integer_))
}

wb_outcomes <- function(d, out) {
  water <- c(
    "wwprrt", "wwprbt", "wwpurt", "wwpubt", "twprrt", "twprbt",
    "twpurt", "twpubt", "twgprt", "twgpbt"
  )
  schools <- c("pspurt", "pspubt", "pskurt", "pskubt", "secsrt", "secsbt")
  d$village98$water <- rowSums(d$village98[water], na.rm = FALSE)
  d$village98$school_buildings <- rowSums(d$village98[schools], na.rm = FALSE)
  d$village98$schools_all <- d$village98$school_buildings +
    d$village98$psnbrt + d$village98$psnbbt
  road <- d$village98$vroad
  d$village98$road_good_moderate <- ifelse(road %in% 1:3, as.integer(road <= 2), NA)
  d$village98$road_good_only <- ifelse(road %in% 1:3, as.integer(road == 1), NA)
  d$gp98$water_built <- wb_yes(d$gp98$gtubb)
  d$gp98$metal_road <- wb_or(wb_yes(d$gp98$gmetb), wb_yes(d$gp98$gmetr))
  d$gp98$ssk_present <- wb_yes(d$gp98$gssk)
  d$gp03$water <- wb_quantity(d$gp03$F3_4a, d$gp03$F3_4a_q) +
    wb_quantity(d$gp03$F3_4b, d$gp03$F3_4b_q)
  d$gp03$metal_road_km <- wb_quantity(d$gp03$F3_11a, d$gp03$F3_11a_q) +
    wb_quantity(d$gp03$F3_11b, d$gp03$F3_11b_q)
  d$gp03$ssk_new <- wb_quantity(d$gp03$F2_8, d$gp03$F2_8b)
  d$gp03$survey_year_valid <- !is.na(d$gp03$AA0_8_3) & d$gp03$AA0_8_3 == 2006
  d$gp03$strict03 <- d$gp03$strict03 & d$gp03$survey_year_valid
  d$gp03$strict_history03 <- d$gp03$strict03 & d$gp03$history_strict
  gp98_cols <- c(
    "gp_id", "gp", "block", "q98", "sc98", "st98", "female98",
    "source_complete", "caste_contradiction", "cross_source_conflict",
    "strict", "water_built", "metal_road", "ssk_present"
  )
  village_cols <- c(
    "gp_id", "gpnum", "villnum", "villname", "jlnum.x", "jlnum.y",
    "prvill", "gp", "block", "q98", "sc98", "st98",
    "source_complete", "strict", "water", "school_buildings",
    "schools_all", "road_good_moderate", "road_good_only"
  )
  gp03_cols <- c(
    "gp_id", "reservation_id", "gp", "block", "q98", "sc98", "st98",
    "q03", "sc03", "st03", "explicit98", "explicit03",
    "previous_within_1998_term", "history_strict", "cross_source_conflict98",
    "current_year_raw", "current_other_year_raw", "current_other_year_888_raw",
    "previous_year_raw", "previous_start_raw", "previous_end_raw",
    "survey_observed", "id_consistent", "exact_gp_name", "survey_year_valid",
    "AA0_8_3", "pradhan_spouse", "female_a0", "female_a1", "female_a8",
    "sex_conflict", "female_followup", "strict03", "strict_history03",
    "water", "metal_road_km", "ssk_new"
  )
  wb_save(d$gp98[gp98_cols], "gp_1998", out)
  wb_save(d$village98[village_cols], "villages_1998", out)
  wb_save(d$gp03[gp03_cols], "gp_2003_followup", out)
  quantities <- list(
    water_built = c("F3_4a", "F3_4a_q"), water_repaired = c("F3_4b", "F3_4b_q"),
    road_built = c("F3_11a", "F3_11a_q"), road_repaired = c("F3_11b", "F3_11b_q"),
    ssk_new = c("F2_8", "F2_8b")
  )
  recodes <- dplyr::bind_rows(lapply(names(quantities), function(v) {
    f <- quantities[[v]]
    data.frame(
      gp_id = d$gp03$gp_id, component = v,
      gate = d$gp03[[f[1]]], amount = d$gp03[[f[2]]],
      recoded = wb_quantity(d$gp03[[f[1]]], d$gp03[[f[2]]])
    )
  }))
  wb_save(recodes, "quantity_recode_audit", out)
  counts <- list(
    cd_gp_rows = nrow(d$gp98), cd_complete = sum(d$gp98$source_complete),
    cd_strict = sum(d$gp98$strict), cd_village_rows = nrow(d$village98),
    cd_random_villages = sum(d$village98$prvill == "NO"),
    beaman_gp_rows = nrow(d$gp03), explicit_2003 = sum(d$gp03$explicit03),
    survey_observed = sum(d$gp03$survey_observed),
    valid_2006_visits = sum(d$gp03$survey_year_valid),
    beaman_strict_2003 = sum(d$gp03$strict03),
    beaman_strict_history = sum(d$gp03$strict_history03),
    sex_conflicts = sum(d$gp03$sex_conflict, na.rm = TRUE),
    pooled_with_official_data = FALSE
  )
  jsonlite::write_json(counts, file.path(out, "data", "validation.json"),
    pretty = TRUE, auto_unbox = TRUE
  )
  missing <- dplyr::bind_rows(lapply(
    c("water", "metal_road_km", "ssk_new", "female_followup"),
    function(v) {
      d$gp03 |>
        dplyr::group_by(block, q03) |>
        dplyr::summarise(
          rows = dplyr::n(), observed_survey = sum(survey_observed),
          observed_outcome = sum(!is.na(.data[[v]])),
          strict_rows = sum(strict03), .groups = "drop"
        ) |>
        dplyr::mutate(outcome = v)
    }
  ))
  wb_table(missing, "missingness_by_block_quota", out)
  d
}

wb_ladder <- function(data, outcome, rhs, term, model, cluster = NULL) {
  choices <- if (is.null(cluster)) {
    c("classical", "HC1", "HC2", "HC3")
  } else {
    c("CR0", "stata", "CR2")
  }
  dplyr::bind_rows(lapply(choices, function(se) {
    wb_estimate(data, outcome, rhs, term, paste(model, se), cluster, se)
  }))
}

wb_power <- function(estimate, se, scenarios = c(0.05, 0.1)) {
  z <- stats::qnorm(0.975)
  dplyr::bind_rows(lapply(scenarios, function(delta) {
    upper <- stats::pnorm(-z + delta / se)
    lower <- stats::pnorm(-z - delta / se)
    power <- upper + lower
    magnitude <- (
      delta * (upper - lower) +
        se * (stats::dnorm(z - delta / se) + stats::dnorm(z + delta / se))
    ) / power
    data.frame(
      observed_estimate = estimate, assumed_effect = delta, se = se,
      normal_model_power = power, type_s = lower / power,
      type_m = magnitude / abs(delta), mde80 = (z + stats::qnorm(0.8)) * se,
      assumption = "Normal estimator with fixed observed SE; not randomization inference"
    )
  }))
}

wb_support <- function(data, outcome, rhs, term, model) {
  formula <- stats::as.formula(paste(outcome, "~", rhs))
  data <- data[stats::complete.cases(data[all.vars(formula)]), ]
  design <- stats::model.matrix(formula, data)
  q <- qr(design)
  h <- rowSums(qr.Q(q)[, seq_len(q$rank), drop = FALSE]^2)
  j <- match(term, colnames(design))
  stopifnot(!is.na(j), qr(design[, -j, drop = FALSE])$rank == q$rank - 1L)
  data.frame(
    model = model, gp_id = data$gp_id, block = data$block,
    exposure = data[[term]], leverage = h, n = nrow(data),
    design_columns = ncol(design), rank = q$rank,
    residual_df = nrow(data) - q$rank
  )
}

wb_selection_audit <- function(d, out) {
  x <- d$gp03
  x$history_evidence <- ifelse(x$explicit98, "explicit_1998",
    ifelse(x$previous_within_1998_term, "inferred_1998", "other_or_unknown")
  )
  counts <- x |>
    dplyr::group_by(history_evidence, q98, q03) |>
    dplyr::summarise(
      source_rows = dplyr::n(), current_year_explicit = sum(explicit03),
      survey_observed = sum(survey_observed),
      consistent_ids = sum(id_consistent, na.rm = TRUE),
      visit_2006 = sum(survey_year_valid),
      previous_source_conflicts = sum(cross_source_conflict98),
      sex_conflicts = sum(sex_conflict, na.rm = TRUE),
      primary_followup_eligible = sum(strict_history03),
      primary_sex_observed = sum(strict_history03 & !is.na(female_followup)),
      .groups = "drop"
    )
  wb_table(counts, "selection_by_reservation_history", out)
  invisible(counts)
}
