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

health_var <- list(
  "phc" = "Primary Health Ctr.",
  "chc" = "Community Health Ctr.",
  "availability_of_mother_child_hea" = "Maternal Health Ctr.",
  "total_anemic_pregnant_women" = "Anemic Preg. Women",
  "total_childs_categorized_non_stu" = "Non-Stunted Children"
)

# Load dat
raj_elex_shrug <- read_parquet(here("data/raj/shrug_lgd_raj_elex_05_10.parquet"))
stopifnot(
  !anyNA(raj_elex_shrug$local_body_code),
  !anyDuplicated(raj_elex_shrug$shrid2),
  !anyDuplicated(distinct(
    raj_elex_shrug, local_body_code,
    caste_res_2005, caste_res_2010
  )$local_body_code)
)
ay <- read_csv(
  shrug_path("shrug-antyodaya-csv/antyodaya_shrid.csv.zip"),
  col_select = any_of(c("shrid2", names(health_var))),
  col_types = cols(.default = col_double(), shrid2 = col_character())
)

raj_elex_ay <- raj_elex_shrug %>%
  inner_join(ay, by = "shrid2", relationship = "one-to-one")


# Let's create a GP Level dataset
raj_elex_ay_total <- raj_elex_ay %>%
  group_by(local_body_code, caste_res_2005, caste_res_2010) %>%
  summarise(across(
    .cols = all_of(names(health_var)),
    .fns = sum,
    .names = "{.col}"
  ))

# Model Names
model_names <- paste0("lm_", names(health_var))
models <- set_names(names(health_var), names(health_var)) %>%
  map(~ lm(as.formula(paste(.x, "~ caste_res_2005 + caste_res_2010")), data = raj_elex_ay_total))

# Tidy and Glance
model_tidies <- map(models, tidy)
model_glances <- map(models, glance)

label_mapping <- c(
  "caste_res_2005OBC" = "2005 OBC",
  "caste_res_2005SC" = "2005 SC",
  "caste_res_2005ST" = "2005 ST",
  "caste_res_2010OBC" = "2010 OBC",
  "caste_res_2010SC" = "2010 SC",
  "caste_res_2010ST" = "2010 ST"
)

coef_names <- names(coef(models[[1]]))
covariate_names <- coef_names[-1]
cov_labels <- label_mapping[covariate_names]

custom_stargazer(models,
  title = "Effects of Caste Reservations on Long-term Outcomes Concerning Health",
  covariate.labels = cov_labels,
  column.labels = unlist(unname(health_var)),
  add.lines = list(c("Covariates", rep("No", length(health_var)))),
  label = "raj_caste_shrug_health_05_10",
  notes = paste(cons_term, "The outcomes are from the Mission Antyodaya Facilities Survey from 2019. The village level outcomes have been aggregated to a GP level. The outcomes are:
                    (i) Primary Health Ctr.: Is there a primary health center?;
                    (ii) Community Health Ctr.: Is there a community health center?;
                    (iii) Maternal Health Ctr.: Is there a maternal health facility?;
                    (iv) Anemic Preg. Women: The number of anemic pregnant women;
                    (v) Non-Stunted Children: The number of children categorized as non-stunted as per ICDS."),
  out = here("tabs/shrug_caste_raj_05_10_health.tex"),
  float.env = "sidewaystable"
)
