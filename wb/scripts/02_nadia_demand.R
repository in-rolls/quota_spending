# Nadia source-linked administrative demand associations, specified in nadia_pap.md.

wb_nadia_key <- function(x) gsub("[^A-Z0-9]", "", toupper(trimws(x)))

wb_nadia_unique <- function(x) !duplicated(x) & !duplicated(x, fromLast = TRUE)

wb_nadia_reservation <- function(x) {
  raw <- toupper(trimws(ifelse(is.na(x), "", x)))
  allowed <- c("", "UR", "WOMEN", "W", "SC", "SCW", "ST", "STW", "OBC", "OBCW")
  if (any(!raw %in% allowed)) stop("Unexpected Nadia Pradhan reservation code")
  data.frame(
    q13 = ifelse(raw == "", NA_real_, as.numeric(raw %in% c("WOMEN", "W", "SCW", "STW", "OBCW"))),
    caste13 = ifelse(raw == "", NA_character_,
      ifelse(grepl("^SC", raw), "SC", ifelse(grepl("^ST", raw), "ST",
        ifelse(grepl("^OBC", raw), "OBC", "unrestricted")
      ))
    )
  )
}

wb_nadia_months <- function(x, unit) {
  months <- c(
    "April", "May", "June", "July", "August", "September", "October",
    "November", "December", "January", "February", "March"
  )
  fields <- paste("Month wise Household and Persons", months, unit, sep = "|")
  if (!all(fields %in% names(x))) stop("Expected twelve monthly demand fields")
  value <- as.matrix(x[fields])
  if (!is.numeric(value)) stop("Monthly demand fields must be numeric")
  if (any(value < 0, na.rm = TRUE) || any(!is.finite(value) & !is.na(value))) {
    stop("Invalid monthly demand quantity")
  }
  rowSums(value, na.rm = FALSE)
}

wb_nadia_read_manifest <- function(source_root, module_root) {
  manifest <- read.csv(file.path(module_root, "nadia_source_manifest.csv"),
    colClasses = "character", check.names = FALSE
  )
  expected <- c("office_roster", "block_membership", "demand_2012", "demand_2014", "analysis_plan")
  stopifnot(!anyDuplicated(manifest$role), setequal(manifest$role, expected))
  paths <- setNames(character(nrow(manifest)), manifest$role)
  for (i in seq_len(nrow(manifest))) {
    base <- switch(manifest$root[i],
      local_elections = source_root,
      module = module_root,
      stop("Unknown source root")
    )
    paths[i] <- file.path(base, manifest$path[i])
    if (digest::digest(file = paths[i], algo = "sha256") != manifest$sha256[i]) {
      stop("Nadia manifest checksum mismatch: ", manifest$role[i])
    }
  }
  paths
}

wb_nadia_verify_pdf <- function(rows, source_root) {
  sources <- unique(rows[c("source_path", "source_sha256")])
  for (i in seq_len(nrow(sources))) {
    if (digest::digest(
      file = file.path(source_root, sources$source_path[i]),
      algo = "sha256"
    ) != sources$source_sha256[i]) {
      stop("Nadia PDF checksum mismatch")
    }
  }
  invisible(TRUE)
}

wb_nadia_prepare <- function(source_root, module_root) {
  paths <- wb_nadia_read_manifest(source_root, module_root)
  office <- read.csv(paths[["office_roster"]], check.names = FALSE, na.strings = c("", "NA"))
  office <- office[office$tier == "gp_head", ]
  bridge <- read.csv(paths[["block_membership"]],
    check.names = FALSE,
    na.strings = c("", "NA")
  )
  stopifnot(nrow(office) == 187, !anyDuplicated(office$row_id))
  stopifnot(all(office$source_list_scope == "complete_office_synopsis_with_explicit_UR"))
  wb_nadia_verify_pdf(office, source_root)
  wb_nadia_verify_pdf(bridge, source_root)
  stopifnot(setequal(unique(office$source_sha256), unique(bridge$source_sha256)))
  demand <- lapply(c("2012", "2014"), function(year) {
    x <- read.csv(paths[[paste0("demand_", year)]],
      check.names = FALSE,
      na.strings = c("", "NA")
    )
    stopifnot(nrow(x) == 187, all(x$state == "WEST BENGAL"), all(x$district == "NADIA"))
    stopifnot(all(complete.cases(x[c("district", "block", "Panchayat")])))
    key <- paste(wb_nadia_key(x$district), wb_nadia_key(x$block), wb_nadia_key(x$Panchayat), sep = "|")
    if (anyDuplicated(key)) stop("Demand geography keys are not unique")
    data.frame(
      key = key, demand_block_raw = x$block, demand_gp_raw = x$Panchayat,
      household_months = wb_nadia_months(x, "Household"),
      person_months = wb_nadia_months(x, "Persons")
    )
  })
  names(demand) <- c("2012", "2014")
  stopifnot(setequal(demand[[1]]$key, demand[[2]]$key))
  post <- demand[[2]][match(demand[[1]]$key, demand[[2]]$key), ]
  panel <- demand[[1]][c("key", "demand_block_raw", "demand_gp_raw")]
  for (unit in c("household_months", "person_months")) {
    panel[[paste0(unit, "_2012")]] <- demand[[1]][[unit]]
    panel[[paste0(unit, "_2014")]] <- post[[unit]]
  }
  stopifnot(nrow(panel) == 187)
  office_name <- wb_nadia_key(office$gram_panchayat)
  bridge_name <- wb_nadia_key(bridge$gram_panchayat_printed)
  unique_office <- wb_nadia_unique(office_name)
  unique_bridge <- wb_nadia_unique(bridge_name)
  j <- match(office_name, bridge_name)
  bridge_ok <- !is.na(j) & unique_office & unique_bridge[j]
  bridge_ok[is.na(bridge_ok)] <- FALSE
  j[!bridge_ok] <- NA_integer_
  block <- bridge$block_printed[j]
  key <- paste(wb_nadia_key(office$district), wb_nadia_key(block), office_name, sep = "|")
  key[!bridge_ok] <- NA_character_
  k <- match(key, panel$key)
  audit <- office
  audit$office_name_normalized <- office_name
  audit$office_name_unique <- unique_office
  audit$membership_matched <- bridge_ok
  audit$membership_row_id <- bridge$row_id[j]
  audit$membership_gp_printed <- bridge$gram_panchayat_printed[j]
  audit$membership_requires_separator_normalization <- bridge_ok &
    tolower(trimws(office$gram_panchayat)) != tolower(trimws(bridge$gram_panchayat_printed[j]))
  audit$membership_source_page <- bridge$source_page[j]
  audit$membership_source_bbox <- bridge$source_bbox[j]
  audit$block_printed <- block
  audit$demand_key <- key
  audit$demand_matched <- !is.na(k)
  audit$demand_block_raw <- panel$demand_block_raw[k]
  audit$demand_gp_raw <- panel$demand_gp_raw[k]
  audit <- cbind(audit, wb_nadia_reservation(audit$reservation))
  for (col in names(panel)[grepl("_201[24]$", names(panel))]) audit[[col]] <- panel[[col]][k]
  complete <- complete.cases(audit[c(
    "q13", "caste13", "block_printed",
    "household_months_2012", "household_months_2014", "person_months_2012", "person_months_2014"
  )])
  audit$linked_complete_eligible <- bridge_ok & audit$demand_matched & complete
  caste_counts <- table(audit$caste13[audit$linked_complete_eligible])
  singleton_caste <- names(caste_counts)[caste_counts < 2]
  audit$singleton_caste_no_residual_support <- audit$linked_complete_eligible &
    audit$caste13 %in% singleton_caste
  audit$analysis_eligible <- audit$linked_complete_eligible & !audit$singleton_caste_no_residual_support
  audit$exclusion_reason <- ifelse(!unique_office, "office_name_nonunique",
    ifelse(!bridge_ok, "membership_missing_or_nonunique",
      ifelse(!audit$demand_matched, "exact_block_gp_unmatched",
        ifelse(is.na(audit$q13), "Pradhan_category_unknown",
          ifelse(!complete, "outcome_or_covariate_missing", "included")
        )
      )
    )
  )
  audit$exclusion_reason[audit$singleton_caste_no_residual_support] <- "singleton_caste_no_residual_support"
  stopifnot(nrow(audit) == 187, !anyDuplicated(audit$row_id))
  list(
    audit = audit, demand_panel = panel, bridge = bridge,
    inputs = data.frame(role = names(paths), path = unname(paths))
  )
}

wb_nadia_fit <- function(data, outcome, rhs, model, cluster = NULL, se_type = NULL) {
  result <- wb_estimate(data, outcome, rhs, "q13", model, cluster, se_type)
  result$blocks <- length(unique(data$block_printed))
  result$blocks_with_treated_gp <- length(unique(data$block_printed[data$q13 == 1]))
  result$estimand <- "Equal-GP conditional association in explicitly linked Nadia GPs"
  result$outcome_unit <- if (grepl("household", outcome)) "household-month demand" else "person-month demand"
  result
}

wb_nadia_demand <- function(source_root, out, module_root = out, estimate = TRUE) {
  prepared <- wb_nadia_prepare(source_root, module_root)
  for (folder in c("data", "tabs", "logs")) dir.create(file.path(out, folder), recursive = TRUE, showWarnings = FALSE)
  wb_save(prepared$audit, "nadia_demand_join_audit", out)
  wb_save(prepared$demand_panel, "nadia_demand_source_panel", out)
  x <- prepared$audit[prepared$audit$analysis_eligible, ]
  x$gp_id <- x$row_id
  x$block <- x$block_printed
  stopifnot(nrow(x) > 20, !anyDuplicated(x$demand_key), length(unique(x$q13)) == 2)
  wb_save(x, "nadia_demand_analysis", out)
  counts <- prepared$audit |>
    dplyr::group_by(reservation, exclusion_reason) |>
    dplyr::summarise(rows = dplyr::n(), .groups = "drop")
  wb_table(counts, "nadia_demand_attrition", out)
  normalization_rows <- which(
    prepared$audit$membership_matched &
      prepared$audit$membership_requires_separator_normalization
  )
  normalization_gains <- prepared$audit[normalization_rows, ]
  wb_table(normalization_gains, "nadia_demand_normalization_gains", out)
  by_block <- x |>
    dplyr::group_by(block_printed, caste13) |>
    dplyr::summarise(rows = dplyr::n(), treated = sum(q13), .groups = "drop")
  wb_table(by_block, "nadia_demand_support", out)
  validation <- list(
    source_office_rows = 187, baseline_gp_rows = 187, post_gp_rows = 187,
    membership_matched = sum(prepared$audit$membership_matched),
    demand_matched = sum(prepared$audit$demand_matched),
    linked_complete_gps = sum(prepared$audit$linked_complete_eligible),
    singleton_caste_excluded = sum(prepared$audit$singleton_caste_no_residual_support),
    analysis_gps = nrow(x),
    treated_gps = sum(x$q13), blocks = length(unique(x$block)),
    blank_source_category = sum(is.na(prepared$audit$q13)),
    normalization = "case and separators only; Roman and numeric suffixes preserved",
    analysis_plan_sha256 = digest::digest(file = file.path(module_root, "nadia_pap.md"), algo = "sha256"),
    interpretation = "Model-based demand association; not a randomized effect or employment/spending outcome"
  )
  jsonlite::write_json(
    validation, file.path(out, "data/nadia_demand_validation.json"),
    pretty = TRUE, auto_unbox = TRUE
  )
  if (!estimate) {
    return(invisible(prepared))
  }
  results <- sensitivity <- influence <- list()
  for (unit in c("household_months", "person_months")) {
    post <- paste0(unit, "_2014")
    pre <- paste0(unit, "_2012")
    adj <- paste("q13 +", pre, "+ factor(block_printed) + factor(caste13)")
    strata <- "q13 + factor(block_printed) + factor(caste13)"
    results <- c(results, list(
      wb_nadia_fit(x, post, adj, "Primary baseline-adjusted"),
      wb_nadia_fit(x, post, "q13", "Same-sample unadjusted"),
      wb_nadia_fit(x, post, strata, "Post-only block/caste adjusted"),
      wb_nadia_fit(x, pre, strata, "Prior-demand selection diagnostic")
    ))
    sensitivity <- c(sensitivity, list(
      wb_nadia_fit(x, post, adj, "Primary HC3 sensitivity", se_type = "HC3"),
      wb_nadia_fit(x, post, adj, "Primary block CR2 sensitivity", cluster = "block_printed", se_type = "CR2")
    ))
    formula <- as.formula(paste(post, "~", adj))
    fit <- lm(formula, data = x)
    support <- wb_support(x, post, adj, "q13", unit)
    stopifnot(support$rank[1] == length(coef(fit)), support$residual_df[1] > 0)
    loo <- vapply(seq_len(nrow(x)), function(i) {
      reduced <- lm(formula, data = x[-i, ])
      unname(coef(reduced)["q13"])
    }, numeric(1))
    stopifnot(all(is.finite(loo)))
    support$estimate_without_gp <- loo
    support$full_estimate <- unname(coef(fit)["q13"])
    influence[[unit]] <- support
  }
  results <- dplyr::bind_rows(results) |>
    dplyr::group_by(model) |>
    dplyr::mutate(p_holm = p.adjust(p.value, method = "holm")) |>
    dplyr::ungroup()
  sensitivity <- dplyr::bind_rows(sensitivity) |>
    dplyr::group_by(model) |>
    dplyr::mutate(p_holm = p.adjust(p.value, method = "holm")) |>
    dplyr::ungroup()
  wb_table(results, "nadia_demand", out)
  wb_table(sensitivity, "nadia_demand_inference_sensitivity", out)
  wb_table(dplyr::bind_rows(influence), "nadia_demand_influence", out)
  invisible(list(results = results, sensitivity = sensitivity, validation = validation, prepared = prepared))
}
