# Load libs.
library(readr)
library(arrow)
library(tidyverse)
library(stringi)
library(kableExtra)
library(here)
library(purrr)
library(broom)
library(stargazer)

# Load dat
mnrega_elex_raj_05_10 <- read_parquet(here("data/raj/mnrega_elex_raj_05_10.parquet"))
mnrega_elex_raj_05_20 <- read_parquet(here("data/raj/mnrega_elex_raj_05_20.parquet"))

# Random or not
#------------------
with(mnrega_elex_raj_05_10, summary(lm(female_res_2010 ~ female_res_2005)))
with(mnrega_elex_raj_05_10, chisq.test(table(female_res_2005, female_res_2010)))

# Phase 1/2/1 and 2
with(mnrega_elex_raj_05_10[mnrega_elex_raj_05_10$phase_1 == 1, ], chisq.test(table(female_res_2005, female_res_2010)))
with(mnrega_elex_raj_05_10[mnrega_elex_raj_05_10$phase_2 == 1, ], chisq.test(table(female_res_2005, female_res_2010)))
with(mnrega_elex_raj_05_10[mnrega_elex_raj_05_10$phase_1 == 1 | mnrega_elex_raj_05_10$phase_2 == 1, ], chisq.test(table(female_res_2005, female_res_2010)))

# Output Table
rand_or_not    <- with(mnrega_elex_raj_05_10, lm(female_res_2010 ~ female_res_2005))
rand_or_not_p1 <- with(mnrega_elex_raj_05_10[mnrega_elex_raj_05_10$phase_1 == 1  | mnrega_elex_raj_05_10$phase_2 == 1, ], lm(female_res_2010 ~ female_res_2005))
rand_or_not_fe <- with(mnrega_elex_raj_05_10, lm(female_res_2010 ~ female_res_2005 + as.factor(dist_name_new_2010)))

## Run within district regressions and calculate sig. p-values

get_p_value <- function(df) {
     model <- lm(female_res_2010 ~ female_res_2005, data = df)
     p_value <- summary(model)$coefficients["female_res_2005", "Pr(>|t|)"]
     return(p_value)
}

p_values <- mnrega_elex_raj_05_10 %>%
     group_by(dist_name_new_2010) %>%
     summarize(p_value = get_p_value(pick(everything()))) %>%
     ungroup()

count_below_threshold <- p_values %>%
     summarize(count = sum(p_value < 0.05))

custom_stargazer(list(rand_or_not, rand_or_not_fe, rand_or_not_p1),
          title = "Predicting 2010 GP Reservation Status Using the 2005 Reservation Status in Rajasthan.",
          covariate.labels = c("2005", "Constant"),
          column.labels = c("All", "With District FE", "Phase 1 and 2"),
          omit = "as\\.factor\\(dist_name_new_2010\\)",
          add.lines = list(c("District FE", "No", "Yes", "No")),
          label = "rand_or_no_raj",
          digits = 2,
          notes = c("Statistical significance symbols for the constant terms are suppressed.
                     Phase 1 and 2 limits regression to districts covered in the first two phases of MNREGA.
                     Within district regressions yield 1 significant coefficient which is what we expect by chance."),
          out = here("tabs/rand_or_not_2010_on_2005_raj.tex"))

## Effect of Reservation on Women Being Elected When Seat is Unreserved
elect_05_10    <- with(mnrega_elex_raj_05_10[mnrega_elex_raj_05_10$female_res_2010 == 0, ], lm(I(sex_2010 == 'F')~ female_res_2005))
elect_05_10_phase_1_2 <- with(mnrega_elex_raj_05_10[mnrega_elex_raj_05_10$female_res_2010 == 0 & (mnrega_elex_raj_05_10$phase_1 == 1  | mnrega_elex_raj_05_10$phase_2 == 1), ], lm(I(sex_2010 == 'F') ~ female_res_2005))
elect_05_20 <- with(mnrega_elex_raj_05_20[mnrega_elex_raj_05_20$female_res_2015 == 0, ], lm(sex_2015 ~ female_res_2005 + female_res_2010))

custom_stargazer(list(elect_05_10, elect_05_20),
                 title = "Effect of Reserving GP For Women on the Probability of Women Being Elected.",
                 covariate.labels = c("2005", "2010", "Constant"),
                 column.labels = c("2010", "2015"),
                 label = "unreserved_women",
                 notes = "",
                 out = here("tabs/elect_woman_unreserved_raj.tex"))
