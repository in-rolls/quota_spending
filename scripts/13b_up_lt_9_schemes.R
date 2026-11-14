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
  "total_hhd_having_bpl_cards" = "BPL",
  "total_hhd_registered_under_pmjay" = "PMJAY",
  "total_hhd_availing_pension_under" = "NSAP",
  "total_hhd_availing_pmuy_benefits" = "PMUY",
  "total_hhd_having_pmsbhgy_benefit" = "Saubhagya",
  "total_no_of_eligible_beneficiari" = "PMMVY",
  "total_hhd_have_got_pmay_house" = "PMAY",
  "total_hhd_availing_pmjdy_bank_ac" = "PMJD"
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
secc <- read_csv(
  shrug_path("shrug-secc-mord-rural-csv/secc_rural_shrid.csv.zip"),
  col_select = any_of(c("shrid2", names(children_var))),
  col_types = cols(.default = col_double(), shrid2 = col_character())
)

up_elex_ay <- up_elex_shrug %>%
  inner_join(ay, by = "shrid2", relationship = "one-to-one") %>%
  inner_join(secc, by = "shrid2", relationship = "one-to-one")

## Antyodya
## From Antyodya, they use data on 9 schemes: (Narasimhan/Weaver) -- seems like 8
# (i) BPL ration cards, which entitle the holders to purchase subsidized grains from government ration shops;
# (ii) publicly provided health insurance through the Pradhan Mantri Jan Arogya Yojana;
# (iii) pensions for the elderly, widows, and the disabled under the National Social Assistance Programme;
# (iv) household electricity connections through the Saubhagya scheme (Pradhan Mantri Sahaj Bijli Har Ghar Yojana);
# (v) receipt of a liquified petroleum gas (LPG) connection through the Pradhan Mantri Ujjwala scheme;
# (vi) receipt of a Rs5,000 cash transfer for pregnant women and mothers through the Pradhan Mantri Matru Vandana Yojana (PMMVY) scheme;
# (vii) receiving housing subsidies (or being on the waiting list for subsidies) through the Pradhan Mantri Awaas Yojana or state-specific schemes;
# and (viii) having a ­ zero-balance bank account (Pradhan Mantri Jan Dhan initiative).


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
  title = "Effects of Reservations on Long-term Outcomes Concerning 8 Key Gov. Schemes (UP)",
  covariate.labels = c("2005", "2010", "Constant"),
  column.labels = unlist(unname(children_var)),
  add.lines = list(c("Covariates", rep("No", length(children_var)))),
  label = "up_shrug_schemes_05_10",
  notes = paste(cons_term, "The outcomes are from the Mission Antyodaya Survey from 2019.
                   The village level outcomes have been aggregated to a GP level. The outcomes are:
                   (i) BPL: The number of households with BPL Cards;
                   (ii) PMJAY: The number of households registered under PM Jan Arogya Yojana;
                   (iii) NSAP: The number of households with pensions under National Social Assistance Programme;
                   (iv) PMUY: The number of households with LPG connection under PM Ujjwala Yojana;
                   (v) Saubhagya: The number of households with electricity connection under Saubhagya;
                   (vi) PMMVY: The number of beneficiaries under PM Matru Vandana Yojana;
                   (vii) PMAY: HH receiving subsidies under PM Awaas Yojana;
                   (viii) PMJD: HH with zero-balance bank account under PM Jan Dhan"),
  out = here("tabs/shrug_up_05_10_schemes.tex")
)
