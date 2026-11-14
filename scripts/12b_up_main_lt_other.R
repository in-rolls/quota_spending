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

other_var <- list(
  "total_female_child_age_bw_0_6" = "Female Children",
  "total_hhd_having_bpl_cards" = "BPL Cards",
  "total_no_of_eligible_beneficiari" = "Maternity Benefit",
  "wall_mat_solid_share" = "Solid Wall",
  "roof_mat_solid_share" = "Solid Roof"
)

housing_vars <- c("wall_mat_solid_share", "roof_mat_solid_share")

# Load dat
up_elex_shrug <- read_parquet(
  here("data/up/shrug_lgd_up_elex_05_10.parquet")
)
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
  col_select = any_of(c("shrid2", names(other_var))),
  col_types = cols(.default = col_double(), shrid2 = col_character())
)
secc <- read_csv(
  shrug_path("shrug-secc-mord-rural-csv/secc_rural_shrid.csv.zip"),
  col_select = all_of(c("shrid2", "secc_hh", housing_vars)),
  col_types = cols(.default = col_double(), shrid2 = col_character())
)

up_elex_ay <- up_elex_shrug |>
  inner_join(ay, by = "shrid2", relationship = "one-to-one") |>
  inner_join(secc, by = "shrid2", relationship = "one-to-one")

stopifnot(
  !anyNA(up_elex_ay$secc_hh), all(up_elex_ay$secc_hh > 0)
)

# Household weights aggregate shares; missing shares remain missing.
# Let's create a GP Level dataset
up_elex_ay_total <- up_elex_ay |>
  group_by(local_body_code, female_res_2005, female_res_2010) |>
  summarise(
    across(all_of(setdiff(names(other_var), housing_vars)), sum),
    across(all_of(housing_vars), ~ weighted.mean(.x, w = secc_hh)),
    .groups = "drop"
  )

# Model Names
model_names <- paste0("lm_", names(other_var))
models <- set_names(names(other_var), names(other_var)) |>
  map(~ lm(
    reformulate(c("female_res_2005", "female_res_2010"), .x),
    data = up_elex_ay_total
  ))

# Tidy and Glance
model_tidies <- map(models, tidy)
model_glances <- map(models, glance)

custom_stargazer(models,
  digits = 3,
  title = "Effects of Reservations on Other Short- and Long-term Outcomes (UP)",
  covariate.labels = c("2005", "2010", "Constant"),
  column.labels = unlist(unname(other_var)),
  add.lines = list(c("Covariates", rep("No", length(other_var)))),
  label = "up_shrug_other_05_10",
  notes = paste(
    cons_term,
    "The first three outcomes are from the Mission Antyodaya Survey from
    2019; housing shares are from SECC (2012). Counts are summed to GP
    level; shares use SECC household counts as weights. A GP housing
    share is missing if any linked village share is missing. The outcomes
    are: (i) Female Children: The number of female children (0-6 years);
    (ii) BPL Cards: The number of households with a BPL ration card;
    (iii) Maternity Benefit: The number of eligible beneficiaries under
    Pradhan Mantri Matru Vandana Yojana (PMMVY); (iv) Solid Wall: Share
    of households with solid wall - wood/stone/sheets/burnt
    brick/concrete; (v) Solid Roof: Share of households with solid roof -
    stone/slate sheets/concrete burned brick."
  ),
  out = "tabs/shrug_up_05_10_other.tex"
)
