library(arrow)
library(purrr)
library(stargazer)
library(dplyr)
library(readr)
library(broom)
library(here)
library(kableExtra)
library(tidyr)

mnrega_elex_up_05_10 <- read_parquet(
  here("data/up/mnrega_elex_up_05_10.parquet")
)

source(here("scripts/00_utils.R"))

stopifnot(
  !anyNA(mnrega_elex_up_05_10$key_2005),
  !anyDuplicated(mnrega_elex_up_05_10$key_2005),
  !anyNA(mnrega_elex_up_05_10$key_2010),
  !anyDuplicated(mnrega_elex_up_05_10$key_2010),
  !anyNA(mnrega_elex_up_05_10$gp_res_status_fin_eng_2005),
  !anyNA(mnrega_elex_up_05_10$gp_res_status_fin_eng_2010)
)
mnrega_elex_up_05_10 <- mnrega_elex_up_05_10 |>
  mutate(
    female_res_2005 = grepl("Female", gp_res_status_fin_eng_2005),
    female_res_2010 = grepl("Female", gp_res_status_fin_eng_2010)
  )

bases <- c(
  "total", "connectivity", "sanitation", "water_conserve", "water_trad",
  "drinking_water"
)
components <- c(
  "comp_project", "comp_expenditure", "ongoing_project", "ongoing_expenditure"
)
column_groups <- as.vector(outer(bases, components, paste, sep = "_"))

mnrega_elex_up_05_10 <- mnrega_elex_up_05_10 |>
  mutate(
    map_dfc(
      set_names(column_groups, paste0(column_groups, "_tot_11_14")),
      ~ {
        col_pattern <- paste0(.x, "_201[1-4]$")
        rowSums(
          select(mnrega_elex_up_05_10, matches(col_pattern)),
          na.rm = TRUE
        )
      }
    )
  )

mod_cols <- paste0(column_groups, "_tot_11_14")

models <- set_names(mod_cols) |>
  map(\(outcome) {
    lm(
      reformulate(c("female_res_2005", "female_res_2010"), response = outcome),
      data = mnrega_elex_up_05_10
    )
  })

# Tidy and Glance
model_tidies <- map(models, tidy)
model_glances <- map(models, glance)

main_outcome_caption <- "They are:
(i) All: The total number of completed projects, including areas not listed here
like Fisheries, Drought Proofing, etc.;
(ii) Rural Roads: The number of projects to improve connectivity and roads;
(iii) Sanitation: The number of projects to improve sanitation facilities;
(iv) Water Conservation: The number of projects to improve water conservation;
(v) Trad. Water: The number of projects to maintain traditional water bodies."

# Number of projects
# All Rural Roads Sanitation Water Conservation Traditional Water
selected_model_names <- paste0(c(
  "total_comp_project",
  "connectivity_comp_project",
  "childcare_comp_project",
  "sanitation_comp_project",
  "water_conserve_comp_project",
  "water_trad_comp_project"
), "_tot_11_14")

selected_models <- models[names(models) %in% selected_model_names]

custom_stargazer(selected_models,
  title = paste(
    "Effects of Reservations on the Number of Completed MNREGA Projects,",
    "2011--2014 (UP)"
  ),
  covariate.labels = c("2005", "2010", "Constant"),
  column.labels = c(
    "All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"
  ),
  add.lines = list(c("Covariates", rep("No", 5))),
  label = "main_mnrega_up_2005_2010",
  notes = paste(
    cons_term,
    "The outcomes are from MNREGA administrative data for years 2011--2014.",
    main_outcome_caption
  ),
  out = "tabs/mnrega_up_05_10_main.tex"
)

# Caste-quota controls (appendix robustness). Women's seats are drawn within
# caste-reservation strata, so condition on both years' caste category. ST has
# 11-12 GPs a year and is pooled with SC to avoid near-singleton cells.
caste_category <- function(status) {
  caste <- sub(" - Female$", "", status)
  caste[caste %in% c("Female", "Unreserved")] <- "Unreserved"
  caste[caste == "Scheduled Tribe"] <- "Scheduled Caste"
  caste
}
caste_data <- mnrega_elex_up_05_10 |>
  mutate(
    caste_2005 = caste_category(gp_res_status_fin_eng_2005),
    caste_2010 = caste_category(gp_res_status_fin_eng_2010)
  )
stopifnot(
  setequal(caste_data$caste_2005, c("Unreserved", "Other Backward Class", "Scheduled Caste")),
  setequal(caste_data$caste_2010, c("Unreserved", "Other Backward Class", "Scheduled Caste"))
)
caste_models <- set_names(mod_cols) |>
  map(\(outcome) {
    lm(
      reformulate(
        c("female_res_2005", "female_res_2010", "factor(caste_2005)", "factor(caste_2010)"),
        response = outcome
      ),
      data = caste_data
    )
  })

custom_stargazer(caste_models[names(caste_models) %in% selected_model_names],
  title = paste(
    "Effects of Reservations on the Number of Completed MNREGA Projects,",
    "2011--2014 (UP, Controlling for Caste Reservation)"
  ),
  covariate.labels = c("2005", "2010", "Constant"),
  column.labels = c(
    "All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"
  ),
  add.lines = list(c("Caste reservation controls", rep("Yes", 5))),
  label = "main_mnrega_up_2005_2010_caste_ctrl",
  omit = "^factor\\(caste",
  notes = paste(
    cons_term,
    "All models include indicators for the 2005 and 2010 caste reservation",
    "of the Pradhan office (OBC; SC or ST, pooled because ST has 11-12 GPs",
    "a year; unreserved omitted).",
    "The outcomes are from MNREGA administrative data for years 2011--2014.",
    main_outcome_caption
  ),
  out = "tabs/mnrega_up_05_10_main_caste_ctrl.tex"
)

# Bose and Das Districts

bose_das_sample <- mnrega_elex_up_05_10 |>
  filter(phase_1_bose_2005 == 1 | phase_2_bose_2005 == 1)
models <- set_names(mod_cols) |>
  map(\(outcome) {
    lm(
      reformulate(c("female_res_2005", "female_res_2010"), response = outcome),
      data = bose_das_sample
    )
  })

# Tidy and Glance
model_tidies <- map(models, tidy)
model_glances <- map(models, glance)

# Number of projects
# All Rural Roads Sanitation Water Conservation Traditional Water
selected_model_names <- paste0(c(
  "total_comp_project",
  "connectivity_comp_project",
  "childcare_comp_project",
  "sanitation_comp_project",
  "water_conserve_comp_project",
  "water_trad_comp_project"
), "_tot_11_14")

selected_models <- models[names(models) %in% selected_model_names]

custom_stargazer(selected_models,
  title = paste(
    "Effects of Reservations on the Number of Completed MNREGA Projects,",
    "2011--2014 (Bose and Das Districts; UP)"
  ),
  covariate.labels = c("2005", "2010", "Constant"),
  column.labels = c(
    "All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"
  ),
  add.lines = list(c("Covariates", rep("No", 5))),
  label = "mnrega_up_bd_districts_05_10",
  notes = paste(
    cons_term,
    "The outcomes are from MNREGA administrative data for years 2011--2014.",
    main_outcome_caption
  ),
  out = here("tabs/mnrega_up_05_10_main_bd_districts.tex")
)

# Female-winner share among reserved GPs with known winner sex.
compliance <- mnrega_elex_up_05_10 |>
  transmute(
    reserved_2005 = female_res_2005, reserved_2010 = female_res_2010,
    winner_2005 = cand_sex_fin_2005, winner_2010 = cand_sex_fin_2010
  ) |>
  pivot_longer(
    everything(),
    names_to = c(".value", "year"), names_pattern = "(.*)_(.*)"
  ) |>
  filter(reserved) |>
  mutate(female_winner = case_when(
    winner == "महिला" ~ TRUE,
    winner == "पुरुष" ~ FALSE,
    TRUE ~ NA
  )) |>
  summarise(
    reserved_gps = n(),
    female_winners = sum(female_winner, na.rm = TRUE),
    known_winners = sum(!is.na(female_winner)),
    missing_winners = sum(is.na(female_winner)),
    compliance_percent = 100 * female_winners / known_winners,
    .by = year
  )
stopifnot(
  all(
    compliance$reserved_gps ==
      compliance$known_winners + compliance$missing_winners
  )
)
write_csv(compliance, here("output/up_reservation_compliance.csv"))
compliance |>
  select(
    year, reserved_gps, female_winners, known_winners,
    missing_winners, compliance_percent
  ) |>
  knitr::kable(
    format = "latex", booktabs = TRUE, digits = 1,
    col.names = c(
      "Election", "Reserved GPs", "Female winners", "Known sex", "Missing sex",
      "Compliance (\\%)"
    ),
    escape = FALSE, format.args = list(big.mark = ","),
    caption = "Compliance with female reservation in the UP MNREGA sample",
    label = "up-reservation-compliance"
  ) |>
  kable_styling(font_size = 9, latex_options = "hold_position") |>
  footnote(
    general = paste(
      "Compliance is the percentage of winners recorded as female among",
      "female-reserved panchayats with known winner sex, using the cleaned",
      "election fields. Missing winner sex is excluded from the denominator",
      "and reported separately. The sample comprises panchayats linked to",
      "MNREGA data; these are descriptive rates, not reservation-effect",
      "estimates. Recorded male winners may reflect election-record errors."
    ),
    general_title = "", threeparttable = TRUE
  ) |>
  save_kable(here("tabs/up_reservation_compliance.tex"))
print(compliance)
