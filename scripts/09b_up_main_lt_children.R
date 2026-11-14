# Load libs
library(arrow)
library(broom)
library(dplyr)
library(here)
library(purrr)
library(readr)
library(stargazer)

# Source utils
source(here("scripts/00_utils.R"))

children_var <- list(
  "total_childs_aged_0_to_3_years_i" = "Immunized",
  "total_underweight_child_age_unde" = "Underweight",
  "no_of_children_not_attending_sch" = "Truant",
  "total_childs_aged_0_to_3_years_r" = "Anganwadi",
  "total_minority_children_getting_" = "SC/ST"
)

# Load dat
up_elex_shrug <- read_parquet(here("data/up/shrug_lgd_up_elex_05_10.parquet"))
stopifnot(
  !anyNA(up_elex_shrug$local_body_code),
  !anyDuplicated(up_elex_shrug$shrid2),
  !anyDuplicated(distinct(
    up_elex_shrug, local_body_code,
    female_res_2005, female_res_2010
  )$local_body_code)
)
ay <- read_csv(
  shrug_path("shrug-antyodaya-csv/antyodaya_shrid.csv.zip"),
  col_select = any_of(c("shrid2", names(children_var))),
  col_types = cols(.default = col_double(), shrid2 = col_character())
)

up_elex_ay <- up_elex_shrug %>%
  inner_join(ay, by = "shrid2", relationship = "one-to-one")

## Antyodya


# Let's create a GP Level dataset
up_elex_ay_total <- up_elex_ay %>%
  group_by(local_body_code, female_res_2005, female_res_2010) %>%
  summarise(across(
    .cols = all_of(names(children_var)),
    .fns = sum,
    .names = "{.col}"
  ))

# Model Names
model_names <- paste0("lm_", names(children_var))

fit_model_for_group <- function(column_name, data) {
  sufficient_data <- complete.cases(data[[column_name]], data$female_res_2005, data$female_res_2010)
  if (sum(sufficient_data) > 0) {
    lm(as.formula(paste(column_name, "~ female_res_2005 + female_res_2010")), data = data)
  } else {
    NULL # Indicate failure to fit the model due to insufficient data
  }
}

# Apply the model fitting function across all specified column groups
models <- set_names(names(children_var), names(children_var)) %>%
  map(~ lm(as.formula(paste(.x, "~ female_res_2005 + female_res_2010")), data = up_elex_ay_total))

# Tidy and Glance
model_tidies <- map(models, tidy)
model_glances <- map(models, glance)

custom_stargazer(models,
  title = "Effects of Reservations on Long-term Outcomes Concerning Children (UP)",
  covariate.labels = c("2005", "2010", "Constant"),
  column.labels = unlist(unname(children_var)),
  add.lines = list(c("Covariates", rep("No", length(children_var)))),
  label = "up_shrug_children_05_10",
  notes = paste(cons_term, "The outcome variables are from Antyodaya Survey from 2019.
                   The village level outcomes have been aggregated to a GP level. The outcomes are:
                   (i) Immunized: Percent of 0--3 year old children who are immunized.
                   (ii) Underweight: Percent underweight children under 6.
                   (iii) Truant: Percent children not attending school.
                   (iv) Anganwadi: Percent of children under 6 registered in Anganwadis.
                   (v) SC/ST: Number of SC/ST/OBC/minority children getting scholarship."),
  out = here("tabs/shrug_up_05_10_children.tex")
)
