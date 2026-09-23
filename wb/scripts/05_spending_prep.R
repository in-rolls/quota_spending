# West Bengal MNREGA spending panel: GP x fiscal year, joined to Pradhan reservation.
#
# Outcome: r6 works expenditure, completed plus ongoing, in lakh rupees. r6
# reports the works of each fiscal year with their status at the time of the
# scrape, so the completed/ongoing split moves with scrape timing while their
# sum does not. r6 file year Y is FY Y-(Y+1) (fiscal year start).
#
# Parsing goes through ../scripts/00_mnrega.R, the same code the UP/Rajasthan
# prep uses. Before any join to treatment, the series is checked against r3
# employment, which shares no code with it: statewide by year, and across GPs
# within each year (wb_spending_validation).

wb_spending_districts <- c(
  "South 24 Parganas" = "24 PARGANAS SOUTH", "Nadia" = "NADIA",
  "Purulia" = "PURULIA", "Alipurduar" = "ALIPURDUAR", "Malda" = "MALDAH"
)

# Fiscal years each elected term governs. The 2018 term stops at FY2021-22
# because central MNREGA funds to the state stopped in March 2022.
wb_spending_windows <- list("2013" = 2013:2017, "2018" = 2018:2021)

wb_spending_manifest <- function(source_root, module_root) {
  manifest <- utils::read.csv(file.path(module_root, "spending_source_manifest.csv"),
    colClasses = "character"
  )
  base <- ifelse(manifest$root == "local_elections", source_root, module_root)
  paths <- file.path(base, manifest$path)
  actual <- vapply(paths, function(p) digest::digest(file = p, algo = "sha256"), "")
  bad <- manifest$path[actual != manifest$sha256]
  if (length(bad)) stop("Spending inputs differ from spending_source_manifest.csv: ", paste(bad, collapse = ", "))
  stats::setNames(paths, manifest$role)
}

wb_spending_read_raw <- function(module_root, report, year) {
  utils::read.csv(
    gzfile(file.path(module_root, "data", "spending_raw", sprintf("%s_wb_%d.csv.gz", report, year))),
    colClasses = "character", check.names = FALSE, na.strings = ""
  )
}

wb_spending_r6_year <- function(module_root, year) {
  raw <- janitor::clean_names(wb_spending_read_raw(module_root, "r6", year))
  if ("pancayata" %in% names(raw)) raw$panchayat <- dplyr::coalesce(raw$panchayat, raw$pancayata)
  # FY2013 prints every column twice, Hindi headers (blank for WB) and English;
  # both clean to one name and coalesce keeps whichever is filled
  raw <- coalesce_columns(replace_column_names(raw))
  if ("nan_in_lakhs_completed" %in% names(raw)) {
    raw$total_in_lakhs_completed <- dplyr::coalesce(raw$total_in_lakhs_completed, raw$nan_in_lakhs_completed)
  }
  invisible(utils::capture.output(raw <- split_r6_cells(raw)))
  categories <- unique(vapply(columns_to_clean, `[`, "", 2))
  out <- data.frame(
    fy = year,
    district = toupper(trimws(raw$district)),
    block = toupper(trimws(raw$block)),
    gram_panchayat = toupper(trimws(raw$panchayat))
  )
  total_reported <- !is.na(raw$total_comp_expenditure) & !is.na(raw$total_ongoing_expenditure)
  for (category in categories) {
    parts <- paste0(category, c("_comp_expenditure", "_ongoing_expenditure"))
    column <- function(p) if (p %in% names(raw)) raw[[p]] else rep(NA_real_, nrow(raw))
    values <- vapply(parts, column, numeric(nrow(raw)))
    both_absent <- rowSums(is.na(values)) == 2
    spend <- rowSums(values)
    # 07c's rule: a category with no works is zero only when the GP-year's totals
    # are reported; a partly reported category stays missing
    spend[both_absent & total_reported] <- 0
    out[[paste0("spend_", category)]] <- spend
  }
  out$spend_completed <- raw$total_comp_expenditure
  out$spend_ongoing <- raw$total_ongoing_expenditure
  out$works <- raw$total_comp_project + raw$total_ongoing_project
  out
}

wb_spending_r3_year <- function(module_root, year) {
  raw <- wb_spending_read_raw(module_root, "r3", year)
  persons <- raw[grepl("\\|Persons$", names(raw))]
  if (ncol(persons) != 12) stop("Expected twelve monthly persons columns in r3 ", year)
  data.frame(
    fy = year,
    district = toupper(trimws(dplyr::coalesce(raw$district, raw$District))),
    block = toupper(trimws(dplyr::coalesce(raw$block, raw$Block))),
    gram_panchayat = toupper(trimws(raw$Panchayat)),
    person_months = rowSums(vapply(persons, as.numeric, numeric(nrow(raw))))
  )[!is.na(raw$Panchayat), ]
}

wb_spending_validation <- function(r6, r3, module_root) {
  key <- function(d) wb_key(paste(d$fy, d$district, d$block, d$gram_panchayat))
  both <- merge(transform(r6, k = key(r6)), transform(r3, k = key(r3))[c("k", "person_months")], by = "k")
  if (nrow(both) != nrow(r6)) stop("r3 does not cover every r6 GP-year")
  table <- do.call(rbind, lapply(split(both, both$fy), function(d) {
    data.frame(
      fy = d$fy[1], gps = nrow(d),
      spend_crore = sum(d$spend_total, na.rm = TRUE) / 100,
      person_months_million = sum(d$person_months, na.rm = TRUE) / 1e6,
      gp_rank_correlation = stats::cor(d$spend_total, d$person_months, method = "spearman", use = "complete.obs")
    )
  }))
  utils::write.csv(table, file.path(module_root, "tabs", "spending_validation.csv"), row.names = FALSE)
  long <- rbind(
    data.frame(fy = table$fy, series = "r6 works expenditure (crore rupees)", value = table$spend_crore),
    data.frame(fy = table$fy, series = "r3 employment (million person-months)", value = table$person_months_million)
  )
  plot <- ggplot2::ggplot(long, ggplot2::aes(x = fy, y = value)) +
    ggplot2::geom_col(fill = "grey40") +
    ggplot2::facet_wrap(~series, ncol = 1, scales = "free_y") +
    ggplot2::scale_x_continuous(breaks = table$fy, labels = sprintf("%d-%02d", table$fy, (table$fy + 1) %% 100)) +
    ggplot2::labs(x = "Fiscal year", y = NULL, title = "West Bengal MNREGA, all GPs") +
    ggplot2::theme_bw(base_size = 10)
  for (ext in c("pdf", "png")) {
    ggplot2::ggsave(file.path(module_root, "figs", paste0("spending_validation.", ext)), plot, width = 7, height = 5)
  }
  table
}

wb_spending_prepare <- function(source_root, module_root) {
  source(file.path(module_root, "..", "scripts", "00_mnrega.R"))
  inputs <- wb_spending_manifest(source_root, module_root)
  years <- 2013:2022
  r6 <- do.call(rbind, lapply(years, function(y) wb_spending_r6_year(module_root, y)))
  r6$spend_total <- r6$spend_completed + r6$spend_ongoing
  r3 <- do.call(rbind, lapply(years, function(y) wb_spending_r3_year(module_root, y)))
  validation <- wb_spending_validation(r6, r3, module_root)

  reservation <- utils::read.csv(inputs[["pradhan_gp"]], colClasses = c(term = "integer"))
  for (flag in c("named_in_order", "woman_reserved")) {
    if (!all(reservation[[flag]] %in% c("True", "False"))) stop("Unexpected value in ", flag)
    reservation[[flag]] <- reservation[[flag]] == "True"
  }
  reservation$mnrega_district <- wb_spending_districts[reservation$district]
  if (anyNA(reservation$mnrega_district)) stop("A reservation district has no MNREGA name")
  reservation$gp_key <- wb_key(paste(reservation$mnrega_district, reservation$block, reservation$gram_panchayat))
  wb_assert_key(reservation, c("term", "gp_key"))
  r6$gp_key <- wb_key(paste(r6$district, r6$block, r6$gram_panchayat))
  wb_assert_key(r6, c("fy", "gp_key"))

  panel <- list()
  audit <- list()
  for (term in names(wb_spending_windows)) {
    fys <- wb_spending_windows[[term]]
    held <- reservation[reservation$term == as.integer(term), ]
    for (fy in fys) {
      spend <- r6[r6$fy == fy, ]
      found <- held$gp_key %in% spend$gp_key
      audit[[length(audit) + 1]] <- data.frame(
        district = held$district, term = held$term, fy = fy,
        block = held$block, gram_panchayat = held$gram_panchayat,
        in_r6 = found, exclusion_reason = ifelse(found, "", "GP name not in r6 for this fiscal year")
      )
      joined <- merge(held[found, ], spend[setdiff(names(spend), c("district", "block", "gram_panchayat"))],
        by = "gp_key"
      )
      panel[[length(panel) + 1]] <- joined
    }
  }
  panel <- do.call(rbind, panel)
  audit <- do.call(rbind, audit)
  panel <- panel[order(panel$district, panel$term, panel$block, panel$gram_panchayat, panel$fy), ]
  wb_assert_key(panel, c("term", "gp_key", "fy"))
  wb_save(panel, "spending_panel", module_root)
  wb_save(audit, "spending_join_audit", module_root)
  list(panel = panel, audit = audit, validation = validation, r6 = r6)
}

if (sys.nframe() == 0) {
  invocation <- grep("^--file=", commandArgs(), value = TRUE)
  module_root <- dirname(dirname(normalizePath(sub("^--file=", "", invocation[1]))))
  source(file.path(module_root, "scripts", "00_common.R"))
  source_root <- Sys.getenv("WB_LOCAL_ELECTIONS", unset = file.path(module_root, "../../local_elections"))
  result <- wb_spending_prepare(normalizePath(source_root), module_root)
  print(result$validation, row.names = FALSE)
  audit <- result$audit
  print(stats::aggregate(in_r6 ~ district + term, data = audit, FUN = function(x) sprintf("%d/%d", sum(x), length(x))))
}
