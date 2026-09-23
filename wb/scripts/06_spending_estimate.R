# Estimates specified in spending_pap.md (frozen in spending_plan_freeze.json).
# Every family below is reported whatever its sign; nothing is chosen by result.

wb_spending_secondary <- c(
  "spend_connectivity", "spend_water", "spend_land_dev", "spend_sanitation_childcare", "works"
)

wb_spending_check_freeze <- function(module_root) {
  freeze <- jsonlite::fromJSON(file.path(module_root, "spending_plan_freeze.json"))
  actual <- digest::digest(file = file.path(module_root, freeze$plan), algo = "sha256")
  if (actual != freeze$sha256) stop("spending_pap.md differs from the frozen plan; add a dated amendment")
  invisible(freeze)
}

# One row per GP-term: means over the fiscal years of the term the GP appears in.
wb_spending_gp_terms <- function(panel) {
  panel$spend_water <- rowSums(panel[c(
    "spend_water_conserve", "spend_water_trad", "spend_drinking_water",
    "spend_micro_irrig", "spend_flood", "spend_drought"
  )])
  panel$spend_sanitation_childcare <- panel$spend_sanitation + panel$spend_childcare
  measures <- c("spend_total", wb_spending_secondary)
  keys <- c("district", "term", "block", "gram_panchayat", "gp_key", "caste_reservation", "woman_reserved")
  groups <- split(panel, panel[c("term", "gp_key")], drop = TRUE)
  out <- do.call(rbind, lapply(groups, function(g) {
    row <- g[1, keys]
    for (m in measures) row[[m]] <- mean(g[[m]])
    row$fiscal_years <- nrow(g)
    row
  }))
  window <- vapply(as.character(out$term), function(t) length(wb_spending_windows[[t]]), integer(1))
  out$complete_window <- out$fiscal_years == window
  out$spend <- out$spend_total
  out$log_spend <- log1p(out$spend)
  out$women <- as.integer(out$woman_reserved)
  out$block_id <- paste(out$district, out$block, sep = "|")
  out$cq_dt <- paste(out$caste_reservation, out$district, out$term, sep = "|")
  out$block_term <- paste(out$block_id, out$term, sep = "|")
  rownames(out) <- NULL
  out
}

wb_spending_primary_rhs <- "women + factor(cq_dt) + factor(block_term)"

wb_spending_family <- function(data, outcomes, rhs, model, cluster = "block_id", se_type = NULL) {
  rows <- dplyr::bind_rows(lapply(outcomes, function(y) {
    wb_estimate(data, y, rhs, "women", model, cluster, se_type)
  }))
  rows$p_holm <- stats::p.adjust(rows$p.value, method = "holm")
  rows$treated_gps <- vapply(outcomes, function(y) sum(data$women[!is.na(data[[y]])]), numeric(1))
  rows$control_mean <- vapply(outcomes, function(y) mean(data[[y]][data$women == 0], na.rm = TRUE), numeric(1))
  rows
}

wb_spending_estimate <- function(prepared, module_root) {
  wb_spending_check_freeze(module_root)
  d <- wb_spending_gp_terms(prepared$panel)
  primary_outcomes <- c("spend", "log_spend")

  primary <- wb_spending_family(d, primary_outcomes, wb_spending_primary_rhs, "Primary: six district-terms")

  nadia <- d[d$district == "Nadia", ]
  both <- names(which(table(nadia$gp_key) == 2))
  nadia <- nadia[nadia$gp_key %in% both, ]
  nadia$cq_t <- paste(nadia$caste_reservation, nadia$term, sep = "|")
  within <- wb_spending_family(
    nadia, primary_outcomes, "women + factor(gp_key) + factor(cq_t) + factor(block_term)",
    "Within-GP: Nadia 2013 and 2018"
  )
  switchers <- sum(tapply(nadia$women, nadia$gp_key, function(x) length(unique(x)) == 2))
  within$gps <- length(both)
  within$switching_gps <- switchers

  secondary <- wb_spending_family(d, wb_spending_secondary, wb_spending_primary_rhs, "Secondary outcomes")
  secondary$outcome_note <- ifelse(secondary$outcome == "works", "number of works", "lakh rupees per year")

  sensitivity <- dplyr::bind_rows(
    wb_spending_family(d, primary_outcomes, wb_spending_primary_rhs, "HC2 instead of CR2", cluster = NULL),
    wb_spending_family(d[d$complete_window, ], primary_outcomes, wb_spending_primary_rhs, "Complete windows only"),
    wb_spending_family(d[d$term == 2018, ], primary_outcomes, wb_spending_primary_rhs, "2018 term only"),
    wb_spending_family(
      d[d$district != "Alipurduar", ], primary_outcomes, wb_spending_primary_rhs, "Excluding Alipurduar"
    ),
    dplyr::bind_rows(lapply(split(d, paste(d$district, d$term)), function(x) {
      wb_spending_family(x, primary_outcomes, "women + factor(caste_reservation) + factor(block)",
        paste(x$district[1], x$term[1])
      )
    }))
  )

  # previous-term spending for the 2018 districts; a diagnostic, not a placebo
  r6 <- prepared$r6
  prior <- stats::aggregate(spend_total ~ gp_key, r6[r6$fy %in% 2014:2017, ], mean)
  names(prior)[2] <- "prior_spend"
  d18 <- merge(d[d$term == 2018, ], prior, by = "gp_key", all.x = TRUE)
  d18$log_prior_spend <- log1p(d18$prior_spend)
  diagnostic <- wb_spending_family(
    d18, c("prior_spend", "log_prior_spend"), wb_spending_primary_rhs,
    "Diagnostic: FY2014-17 spending on 2018 reservation"
  )
  diagnostic$gps_with_prior <- sum(!is.na(d18$prior_spend))

  main <- primary[primary$outcome == "spend", ]
  power <- wb_power(main$estimate, main$std.error, scenarios = c(0.1, 0.2) * main$control_mean)
  power$assumed_effect_share_of_control_mean <- c(0.1, 0.2)

  results <- list(
    primary = primary, within = within, secondary = secondary,
    sensitivity = sensitivity, diagnostic = diagnostic, power = power, gp_terms = d
  )
  for (name in c("primary", "within", "secondary", "sensitivity", "diagnostic", "power")) {
    wb_table(results[[name]], paste0("spending_", name), module_root)
  }
  wb_save(d, "spending_gp_terms", module_root)
  shown <- dplyr::bind_rows(primary, within, sensitivity)
  wb_plot(shown, "spending_estimates", module_root,
    "Women's Pradhan reservation and MNREGA works spending, West Bengal",
    "Difference, reserved minus not (95% CI)"
  )
  results
}
