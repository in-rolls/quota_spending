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

# Year wise (2005, 2010, 2015, 2020) --- plausible future
mnrega_elex_raj_10_strict <- read_parquet(here("data/raj/mnrega_elex_raj_10_strict.parquet"))
mnrega_elex_raj_15_strict <- read_parquet(here("data/raj/mnrega_elex_raj_15_strict.parquet"))
mnrega_elex_raj_20_strict <- read_parquet(here("data/raj/mnrega_elex_raj_20_strict.parquet"))

# Two Big Files
mnrega_elex_raj_05_10 <- read_parquet(here("data/raj/mnrega_elex_raj_05_10.parquet"))
mnrega_elex_raj_05_20 <- read_parquet(here("data/raj/mnrega_elex_raj_05_20.parquet"))

mnrega_elex_raj_05_10_strict <- read_parquet(here("data/raj/mnrega_elex_raj_05_10_strict.parquet"))
mnrega_elex_raj_05_20_strict <- read_parquet(here("data/raj/mnrega_elex_raj_05_20_strict.parquet"))

# Areas
# "childcare", "infrastructure", 
bases <- c("total", "connectivity", "sanitation", "water_conserve", "water_trad", "drinking_water")
components <- c("comp_project", "comp_expenditure", "ongoing_project", "ongoing_expenditure")
column_groups <- as.vector(outer(bases, components, paste, sep = "_"))

mnrega_elex_raj_05_10 <- mnrega_elex_raj_05_10 %>%
     mutate(
          # Create columns for the 2011 to 2014 range
          map_dfc(set_names(column_groups, paste0(column_groups, "_tot_11_14")), 
                  ~ {
                       col_pattern_11_14 <- paste0(.x, "_201[1-4]$")
                       new_col_11_14 <- rowSums(select(mnrega_elex_raj_05_10, matches(col_pattern_11_14)), na.rm = TRUE)
                       return(new_col_11_14)
                  }),
          
          map_dfc(set_names(column_groups, paste0(column_groups, "_tot_11_13")), 
                  ~ {
                       col_pattern_11_13 <- paste0(.x, "_201[1-3]$")
                       new_col_11_13 <- rowSums(select(mnrega_elex_raj_05_10, matches(col_pattern_11_13)), na.rm = TRUE)
                       return(new_col_11_13)
                  }),
          ds_bl = paste(dist_name_2005, samiti_name_2010)
     )

mnrega_elex_raj_05_10_strict <- mnrega_elex_raj_05_10_strict %>%
     mutate(
          map_dfc(set_names(column_groups, paste0(column_groups, "_tot_11_14")), 
                  ~ {
                       col_pattern <- paste0(.x, "_201[1-4]$")
                       new_col <- rowSums(select(mnrega_elex_raj_05_10_strict, matches(col_pattern)), na.rm = TRUE)
                       return(new_col)
                  })
     )

mnrega_elex_raj_05_20 <- mnrega_elex_raj_05_20 %>%
     mutate(
          map_dfc(set_names(column_groups, paste0(column_groups, "_tot_11_23")), 
                  ~ {
                       col_pattern <- paste0(.x, "_20(1[1-9]|2[0-3])$")
                       new_col <- rowSums(select(mnrega_elex_raj_05_20, matches(col_pattern)), na.rm = TRUE)
                       return(new_col)
                  }),
          
          map_dfc(set_names(column_groups, paste0(column_groups, "_tot_11_13")), 
                  ~ {
                       col_pattern_11_13 <- paste0(.x, "_201[1-3]$")
                       new_col_11_13 <- rowSums(select(mnrega_elex_raj_05_20, matches(col_pattern_11_13)), na.rm = TRUE)
                       return(new_col_11_13)
                  }),
          
          map_dfc(set_names(column_groups, paste0(column_groups, "_tot_16_18")), 
                  ~ {
                       col_pattern_16_18 <- paste0(.x, "_201[6-8]$")
                       new_col_16_18 <- rowSums(select(mnrega_elex_raj_05_20, matches(col_pattern_16_18)), na.rm = TRUE)
                       return(new_col_16_18)
                  }),
          
          map_dfc(set_names(column_groups, paste0(column_groups, "_tot_21_23")), 
                  ~ {
                       col_pattern_21_23 <- paste0(.x, "_202[1-3]$")
                       new_col_21_23 <- rowSums(select(mnrega_elex_raj_05_20, matches(col_pattern_21_23)), na.rm = TRUE)
                       return(new_col_21_23)
                  })
     )

# Year wise
mnrega_elex_raj_10_strict <- mnrega_elex_raj_10_strict  %>%
     mutate(
          map_dfc(set_names(column_groups, paste0(column_groups, "_tot_11_13")), 
                  ~ {
                       col_pattern_11_13 <- paste0(.x, "_201[1-3]$")
                       new_col_11_13 <- rowSums(select(mnrega_elex_raj_10_strict, matches(col_pattern_11_13)), na.rm = TRUE)
                       return(new_col_11_13)
                  })
          )

mnrega_elex_raj_15_strict <- mnrega_elex_raj_15_strict  %>%
     mutate(
          map_dfc(set_names(column_groups, paste0(column_groups, "_tot_16_18")), 
                  ~ {
                       col_pattern_16_18 <- paste0(.x, "_201[6-8]$")
                       new_col_16_18 <- rowSums(select(mnrega_elex_raj_15_strict, matches(col_pattern_16_18)), na.rm = TRUE)
                       return(new_col_16_18)
                  })
          )

mnrega_elex_raj_20_strict <- mnrega_elex_raj_20_strict  %>%
     mutate(
          map_dfc(set_names(column_groups, paste0(column_groups, "_tot_21_23")), 
                  ~ {
                       col_pattern_21_23 <- paste0(.x, "_202[1-3]$")
                       new_col_21_23 <- rowSums(select(mnrega_elex_raj_20_strict, matches(col_pattern_21_23)), na.rm = TRUE)
                       return(new_col_21_23)
                  })
          )

# Main
main_outcome_caption <- "They are: 
(i) All: The total number of completed projects, including areas not listed here like Fisheries, Drought Proofing, etc.;
(ii) Rural Roads: The number of projects to improve connectivity and roads;
(iii) Sanitation: The number of projects to improve sanitation facilities;
(iv) Water Conservation: The number of projects to improve water conservation;
(v) Trad. Water: The number of projects to maintain traditional water bodies."

# Model Names
model_names <- paste0("lm_", column_groups)
mod_cols <- paste0(column_groups, "_tot_11_14")

# Just a dist/sam fe model to see how much variance it explains
#dist_sam_models <- set_names(mod_cols, mod_cols) %>% 
#     map(~ lm(as.formula(paste(.x, "~ dist_sam")), data = dist_name_2010))

# Actual 
main_models <- set_names(mod_cols, mod_cols) %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2005 + female_res_2010")), data = mnrega_elex_raj_05_10))

# Print
map(main_models, ~ tidy(.x) %>% mutate(across(where(is.numeric), ~ round(.x, 3))))
map(main_models, glance)
proportion_significant_pvalues(main_models)

# Number of completed projects
n_comp_proj <- paste0(
                         c("total", "connectivity", "childcare", "sanitation", "water_conserve", "water_trad"), 
                         "_comp_project_tot_11_14"
                         )

n_comp_main_models <- main_models[names(main_models) %in% n_comp_proj]

custom_stargazer(n_comp_main_models,
          title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2011--2014",
          covariate.labels = c("2005", "2010", "Constant"),
          column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
          add.lines = list(c("Covariates", rep("No", 5))),
          label = "main_mnrega",
          notes = paste(cons_term, "The outcomes are from MNREGA administrative data for years 2011--2014.", main_outcome_caption),
          out = here("tabs/mnrega_raj_05_10_main.tex"))

## Ongoing Proj
n_ongoing_proj <- paste0(
                       c("total", "connectivity", "childcare", "sanitation", "water_conserve", "water_trad"), 
                       "_ongoing_project_tot_11_14"
                       )

n_ongoing_models <- main_models[names(main_models) %in% n_ongoing_proj]

custom_stargazer(n_ongoing_models,
          title = "Effects of Reservations on the Number of Ongoing MNREGA Projects, 2011--2014",
          covariate.labels = c("2005", "2010", "Constant"),
          column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
          add.lines = list(c("Covariates", rep("No", 5))),
          label = "main_mnrega_ongoing",
          notes = 
               paste(cons_term, "The outcomes are from MNREGA administrative data for years 2011--2014.", 
                     "They are: 
                     (i) All: The total number of ongoing projects, including areas not listed here like Fisheries, Drought Proofing, etc.;
                     (ii) Rural Roads: The number of projects to improve connectivity and roads;
                     (iii) Sanitation: The number of projects to improve sanitation facilities;
                     (iv) Water Conservation: The number of projects to improve water conservation;
                     (v) Trad. Water: The number of projects to maintain traditional water bodies."),
          out = here("tabs/mnrega_raj_05_10_main_ongoing.tex"))

## Expenditure
comp_expenditure <- paste0(
     c("total", "connectivity", "childcare", "sanitation", "water_conserve", "water_trad"), 
     "_comp_expenditure_tot_11_14"
)

comp_expenditure_models <- main_models[names(main_models) %in% comp_expenditure]

custom_stargazer(comp_expenditure_models,
                 title = "Effects of Reservations on the Expenditure on Completed MNREGA Projects, 2011-2014",
                 covariate.labels = c("2005", "2010", "Constant"),
                 column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
                 add.lines = list(c("Covariates", rep("No", 5))),
                 label = "main_mnrega_expenditure",
                 notes = paste(cons_term, "The outcomes are from MNREGA administrative data for years 2011--2014; expenditure is in lakh rupees.",
                               "They are: 
                     (i) All: The expenditure on all the projects, including areas not listed here like Fisheries, Drought Proofing, etc.;
                     (ii) Rural Roads: The expenditure on projects to improve connectivity and roads;
                     (iii) Sanitation: The expenditure on projects to improve sanitation facilities;
                     (iv) Water Conservation: The expenditure on projects to improve water conservation;
                     (v) Trad. Water: The expenditure on projects to maintain traditional water bodies."),
                 out = here("tabs/mnrega_raj_05_10_main_comp_expenditure.tex"))

## Caste-quota controls (appendix robustness)
# Women's seats are drawn within caste-reservation strata, so women's and caste
# reservation are correlated by construction; condition on both years' caste
# category (GEN/OBC/SC/ST).
caste_models <- set_names(mod_cols, mod_cols) %>%
     map(~ lm(as.formula(paste(.x, "~ female_res_2005 + female_res_2010 + factor(caste_res_2005) + factor(caste_res_2010)")),
              data = mnrega_elex_raj_05_10))

caste_note <- "All models include indicators for the 2005 and 2010 caste reservation of the Pradhan office (OBC, SC, ST; GEN omitted)."

custom_stargazer(caste_models[names(caste_models) %in% n_comp_proj],
                 title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2011--2014 (Controlling for Caste Reservation)",
                 covariate.labels = c("2005", "2010", "Constant"),
                 column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
                 add.lines = list(c("Caste reservation controls", rep("Yes", 5))),
                 label = "main_mnrega_caste_ctrl",
                 omit = "^factor\\(caste",
                 notes = paste(cons_term, caste_note, "The outcomes are from MNREGA administrative data for years 2011--2014.", main_outcome_caption),
                 out = here("tabs/mnrega_raj_05_10_main_comp_caste_ctrl.tex"))

custom_stargazer(caste_models[names(caste_models) %in% n_ongoing_proj],
                 title = "Effects of Reservations on the Number of Ongoing MNREGA Projects, 2011--2014 (Controlling for Caste Reservation)",
                 covariate.labels = c("2005", "2010", "Constant"),
                 column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
                 add.lines = list(c("Caste reservation controls", rep("Yes", 5))),
                 label = "main_mnrega_ongoing_caste_ctrl",
                 omit = "^factor\\(caste",
                 notes = paste(cons_term, caste_note, "The outcomes are from MNREGA administrative data for years 2011--2014.",
                               "They are the number of ongoing projects in each area; All includes areas not listed here."),
                 out = here("tabs/mnrega_raj_05_10_main_ongoing_caste_ctrl.tex"))

custom_stargazer(caste_models[names(caste_models) %in% comp_expenditure],
                 title = "Effects of Reservations on the Expenditure on Completed MNREGA Projects, 2011-2014 (Controlling for Caste Reservation)",
                 covariate.labels = c("2005", "2010", "Constant"),
                 column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
                 add.lines = list(c("Caste reservation controls", rep("Yes", 5))),
                 label = "main_mnrega_expenditure_caste_ctrl",
                 omit = "^factor\\(caste",
                 notes = paste(cons_term, caste_note, "The outcomes are from MNREGA administrative data for years 2011--2014; expenditure is in lakh rupees."),
                 out = here("tabs/mnrega_raj_05_10_main_comp_expenditure_caste_ctrl.tex"))

## Let's do district/block FE

# Actual 
fe_models <- set_names(mod_cols, mod_cols) %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2005 + female_res_2010 + ds_bl")), data = mnrega_elex_raj_05_10))

# Print
map(fe_models, ~ tidy(.x) %>% mutate(across(where(is.numeric), ~ round(.x, 3))))
map(fe_models, glance)

# Number of completed projects
n_comp_proj <- paste0(
     c("total", "connectivity", "childcare", "sanitation", "water_conserve", "water_trad"), 
     "_comp_project_tot_11_14"
)

n_comp_fe_models <- fe_models[names(fe_models) %in% n_comp_proj]

custom_stargazer(n_comp_fe_models,
                 title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2011--2014 (With District-Block Fixed Effects)",
                 covariate.labels = c("2005", "2010", "Constant"),
                 column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
                 add.lines = list(c("Covariates", rep("Yes", 5))),
                 label = "main_mnrega_fe",
                 omit = "^ds_bl",
                 notes = paste(cons_term, "The outcomes are from MNREGA administrative data for years 2011--2014.", main_outcome_caption),
                 out = here("tabs/mnrega_raj_05_10_main_fe.tex"))

## Interaction
int_models <- set_names(mod_cols, mod_cols)  %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2005*female_res_2010")), data = mnrega_elex_raj_05_10))

# Tidy and Glance
map(int_models, tidy)
map(int_models, glance)
proportion_significant_pvalues(int_models)

n_comp_int_models <- int_models[names(int_models) %in% n_comp_proj]

custom_stargazer(n_comp_int_models,
          title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2011--2014. (With Interaction Term).",
          covariate.labels = c("2005", "2010", "2005 * 2010", "Constant"),
          column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
          add.lines = list(c("Covariates", rep("No", 5))),
          label = "main_mnrega_interaction",
          notes = paste(cons_term, 
                        "The outcomes are from MNREGA administrative data for years 2011--2014.", 
                        main_outcome_caption),
          out = here("tabs/mnrega_raj_05_10_main_interaction.tex"))

## Limit to Phase 1 and 2
raj_p12 <- mnrega_elex_raj_05_10 %>%
     filter(phase_1 == 1 | phase_2 == 1)

p12_models <- set_names(mod_cols, mod_cols) %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2005 + female_res_2010")), data = raj_p12))

# Tidy and Glance
map(p12_models, tidy)
map(p12_models, glance)
proportion_significant_pvalues(p12_models)

# Filter to comp.
n_comp_p12_mods <- p12_models[names(p12_models) %in% n_comp_proj]

custom_stargazer(n_comp_p12_mods,
          title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2011--2014. (Phase 1 and 2 Only.)",
          covariate.labels = c("2005", "2010", "Constant"),
          column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
          add.lines = list(c("Covariates", rep("No", 5))),
          label = "main_mnrega_phase_1_2",
          notes = paste(cons_term, 
                        "The outcomes are from MNREGA administrative data for years 2011--2014.", 
                        main_outcome_caption),
          out = here("tabs/mnrega_raj_05_10_main_phase_1_2.tex"))

### Limit to ST
raj_st = mnrega_elex_raj_05_10 %>%
     filter(reservation_2005 %in% c("ST", "STW") | reservation_2010 %in% c("ST", "STW"))

# Apply the model fitting function across all specified column groups
st_models <- set_names(mod_cols, mod_cols) %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2005 + female_res_2010")), data = raj_st))

# Tidy and Glance
map(st_models, tidy)
map(st_models, glance)
n_comp_st_models <- st_models[names(st_models) %in% n_comp_proj]

custom_stargazer(n_comp_st_models,
          title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2011--2014. (ST Only.)",
          covariate.labels = c("2005", "2010", "Constant"),
          column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
          add.lines = list(c("Covariates", rep("No", 5))),
          label = "main_mnrega_phase_st",
          notes = paste(cons_term, 
                        "The outcomes are from MNREGA administrative data for years 2011--2014.", 
                        main_outcome_caption),
          out = here("tabs/mnrega_raj_05_10_main_st.tex"))

## Limit to Strict
strict_models <- set_names(mod_cols, mod_cols) %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2005 + female_res_2010")), data = mnrega_elex_raj_05_10_strict))

# Tidy and Glance
map(strict_models, tidy)
map(strict_models, glance)
n_comp_strict_models <- strict_models[names(strict_models) %in% n_comp_proj]

custom_stargazer(n_comp_strict_models,
          title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2011--2014. (Strict Matching.)",
          covariate.labels = c("2005", "2010", "Constant"),
          column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
          add.lines = list(c("Covariates", rep("No", 5))),
          label = "main_mnrega_strict",
          notes = paste(cons_term, 
                        "The outcomes are from MNREGA administrative data for years 2011--2014.", 
                        main_outcome_caption),
          out = here("tabs/mnrega_raj_05_10_main_strict.tex"))

### Extreme
raj_extreme <- mnrega_elex_raj_05_20 %>%
     filter(case == '1_1_1_1' | case == '0_0_0_0')

# Model Names
model_names <- paste0("lm_", column_groups)
mod_cols <- paste0(column_groups, "_tot_21_23")

# Apply the model fitting function across all specified column groups
extreme_models <- set_names(mod_cols, mod_cols) %>% 
     map(~ lm(as.formula(paste(.x, "~ case")), data = raj_extreme))

# Tidy and Glance
map(extreme_models, tidy)
map(extreme_models, glance)

# Number of projects: All Rural Roads Sanitation Water Conservation Traditional Water
n_comp_proj_21_23 <- paste0(
                    c("total", "connectivity", "childcare", "sanitation", "water_conserve", "water_trad"), 
                    "_comp_project_tot_21_23"
                    )

n_comp_extreme_models <- extreme_models[names(extreme_models) %in% n_comp_proj_21_23]

custom_stargazer(n_comp_extreme_models,
          title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2021--2023.",
          covariate.labels = c("T-T-T-T", "Constant"),
          column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
          add.lines = list(c("Covariates", rep("No", 5))),
          label = "main_mnrega_2011_2023",
          notes = paste(cons_term, "The outcomes are from MNREGA administrative data for years 2021--2023.", main_outcome_caption),
          out = here("tabs/mnrega_raj_05_20_main_extreme.tex"))

### All
model_names <- paste0("lm_", column_groups)
mod_cols <- paste0(column_groups, "_tot_21_23")

all_models <- set_names(mod_cols, mod_cols)  %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2005*female_res_2010*female_res_2015*female_res_2020")), data = mnrega_elex_raj_05_20))

# Tidy and Glance
map(all_models, tidy)
map(all_models, glance)

n_comp_all_models <- all_models[names(all_models) %in% n_comp_proj_21_23]

custom_stargazer(n_comp_all_models,
          title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2021--2023.",
          covariate.labels = c("2005", "2010", "2015", "2020", 
                               "2005*2010", "2005*2015", "2010*2015", 
                               "2005*2020", "2010*2020", "2015*2020", "2005*2010*2015",
                               "2005*2010*2020", "2005*2015*2020", "2010*2015*2020", "2005*2010*2015*2020",
                               "Constant"),
          column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
          add.lines = list(c("Covariates", rep("No", 5))),
          label = "main_mnrega_2011_2023_all",
          notes = paste(cons_term, 
                        "The outcomes are from MNREGA administrative data for years 2021--2023.", 
                        main_outcome_caption),
          out = here("tabs/mnrega_raj_05_20_main_all.tex"))

### Dosage
mnrega_elex_raj_05_20 <- mnrega_elex_raj_05_20 %>%
     mutate(female_res_sum = rowSums(select(., female_res_2005, female_res_2010, female_res_2015, female_res_2020)),
            female_res_sum_factor = factor(female_res_sum, levels = 0:max(female_res_sum)))
# Model Names
model_names <- paste0("lm_", column_groups)
mod_cols <- paste0(column_groups, "_tot_21_23")

dosage_models <- set_names(mod_cols, mod_cols)  %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_sum_factor")), data = mnrega_elex_raj_05_20))

# Tidy and Glance
map(dosage_models, tidy)
map(dosage_models, glance)

n_comp_dosage_models <- dosage_models[names(dosage_models) %in% n_comp_proj_21_23]

custom_stargazer(n_comp_dosage_models,
          title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2021--2023.",
          covariate.labels = c("Reserved Once", "Reserved Twice", "Reserved Thrice", "Reserved Four Times", "Constant"),
          column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
          add.lines = list(c("Covariates", rep("No", 5))),
          label = "main_mnrega_2011_2023_dosage",
          notes = paste(cons_term,
                        "The outcomes are from MNREGA administrative data for years 2021--2023.", 
                        main_outcome_caption),
          out = here("tabs/mnrega_raj_05_20_main_dosage.tex"))

# Regular additive across years
add_models <- set_names(mod_cols, mod_cols)  %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2005 + female_res_2010 + female_res_2015 + female_res_2020")), data = mnrega_elex_raj_05_20))

# Tidy and Glance
map(add_models, tidy)
map(add_models, glance)

n_comp_add_models <- add_models[names(add_models) %in% n_comp_proj_21_23]

custom_stargazer(n_comp_add_models,
                 title = "Effects of Reservations on the Number of Completed MNREGA Projects, 2021--2023.",
                 covariate.labels = c("2005", "2010", "2015", "2020", "Constant"),
                 column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
                 add.lines = list(c("Covariates", rep("No", 5))),
                 label = "main_mnrega_2011_2023_additive",
                 notes = paste(cons_term,
                               "The outcomes are from MNREGA administrative data for years 2021--2023.", 
                               main_outcome_caption),
                 out = here("tabs/mnrega_raj_05_20_main_additive.tex"))

# Let's do by year
# -----------

model_names <- paste0("lm_", column_groups)
mod_cols <- paste0(column_groups, "_tot_11_13")

# Just a dist/sam fe model to see how much variance it explains
#dist_sam_models <- set_names(mod_cols, mod_cols) %>% 
#     map(~ lm(as.formula(paste(.x, "~ dist_sam")), data = mnrega_elex_raj_05_10))

# Actual 
main_models <- set_names(mod_cols, mod_cols) %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2010")), data = mnrega_elex_raj_05_20))

# Print
map(main_models, ~ tidy(.x) %>% mutate(across(where(is.numeric), ~ round(.x, 3))))
map(main_models, glance)
proportion_significant_pvalues(main_models)

# Number of completed projects
n_comp_proj <- paste0(
     c("total", "connectivity", "childcare", "sanitation", "water_conserve", "water_trad"), 
     "_comp_project_tot_11_13"
)

n_comp_main_models <- main_models[names(main_models) %in% n_comp_proj]

custom_stargazer(n_comp_main_models,
                 title = "Effects of 2010 Reservations on the Number of Completed MNREGA Projects, 2011--2013",
                 covariate.labels = c("2010", "Constant"),
                 column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
                 add.lines = list(c("Covariates", rep("No", 5))),
                 label = "main_mnrega_10",
                 notes = paste(cons_term, 
                               "The outcomes are from MNREGA administrative data for years 2011--2013.", 
                               main_outcome_caption),
                 out = here("tabs/mnrega_raj_10_main.tex"))

# 2015
model_names <- paste0("lm_", column_groups)
mod_cols <- paste0(column_groups, "_tot_16_18")

# Just a dist/sam fe model to see how much variance it explains
#dist_sam_models <- set_names(mod_cols, mod_cols) %>% 
#     map(~ lm(as.formula(paste(.x, "~ dist_sam")), data = mnrega_elex_raj_05_10))

# Actual 
main_models <- set_names(mod_cols, mod_cols) %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2015")), data = mnrega_elex_raj_05_20))

# Print
map(main_models, ~ tidy(.x) %>% mutate(across(where(is.numeric), ~ round(.x, 3))))
map(main_models, glance)
proportion_significant_pvalues(main_models)

# Number of completed projects
n_comp_proj <- paste0(
     c("total", "connectivity", "childcare", "sanitation", "water_conserve", "water_trad"), 
     "_comp_project_tot_16_18"
)

n_comp_main_models <- main_models[names(main_models) %in% n_comp_proj]

custom_stargazer(n_comp_main_models,
                 title = "Effects of 2015 Reservations on the Number of Completed MNREGA Projects, 2016--2018",
                 covariate.labels = c("2015", "Constant"),
                 column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Trad. Water"),
                 add.lines = list(c("Covariates", rep("No", 5))),
                 label = "main_mnrega_15",
                 notes = paste(cons_term,
                               "The outcomes are from MNREGA administrative data for years 2016--2018.", 
                               main_outcome_caption),
                 out = here("tabs/mnrega_raj_15_main.tex"))


# 2021
model_names <- paste0("lm_", column_groups)
mod_cols <- paste0(column_groups, "_tot_21_23")

# Just a dist/sam fe model to see how much variance it explains
#dist_sam_models <- set_names(mod_cols, mod_cols) %>% 
#     map(~ lm(as.formula(paste(.x, "~ dist_sam")), data = mnrega_elex_raj_05_10))

# Actual 
main_models <- set_names(mod_cols, mod_cols) %>% 
     map(~ lm(as.formula(paste(.x, "~ female_res_2020")), data = mnrega_elex_raj_05_20))

# Print
map(main_models, ~ tidy(.x) %>% mutate(across(where(is.numeric), ~ round(.x, 3))))
map(main_models, glance)
proportion_significant_pvalues(main_models)

# Number of completed projects
n_comp_proj <- paste0(
     c("total", "connectivity", "childcare", "sanitation", "water_conserve", "water_trad"), 
     "_comp_project_tot_21_23"
)

n_comp_main_models <- main_models[names(main_models) %in% n_comp_proj]

custom_stargazer(n_comp_main_models,
                 title = "Effects of 2020 Reservations on the Number of Completed MNREGA Projects, 2021-2023",
                 covariate.labels = c("2020", "Constant"),
                 column.labels = c("All", "Rural Roads", "Sanitation", "Water Conservation", "Traditional Water"),
                 add.lines = list(c("Covariates", rep("No", 5))),
                 label = "main_mnrega_20",
                 notes = paste(cons_term,
                               "The outcomes are from MNREGA administrative data for years 2021--2023.", 
                               main_outcome_caption),
                 out = here("tabs/mnrega_raj_20_main.tex"))
