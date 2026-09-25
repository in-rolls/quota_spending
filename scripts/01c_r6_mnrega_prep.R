# Load libs
library(stringr)
library(dplyr)
library(janitor)
library(stringi)
library(readr)
library(reshape)
library(tidyr)
library(purrr)
library(here)
library(arrow)

source(here("scripts/00_utils.R"))
source(here("scripts/00_mnrega.R"))

# Filter, add year, clean names
process_r6_files <- function(file_path, year) {
     
     year <- as.numeric(sub(".*/r6-all-(\\d{4})\\.csv\\.gz", "\\1", file_path))
     
     df <- read_csv(file_path) %>%
          filter(state %in% c("UTTAR PRADESH", "RAJASTHAN")) %>%
          clean_names()
     
     if ("pancayata" %in% names(df)) {
          df <- df %>%
               mutate(panchayat = coalesce(panchayat, pancayata))
     }

     df <- df %>%
          mutate(year = year,
                 key = normalize_string(paste(district, block, panchayat)),
                 state_key = normalize_string(paste(state, district, block, panchayat))) %>%
          drop_na(district, block, panchayat) %>%
          filter(!(duplicated(state_key) | duplicated(state_key, fromLast = TRUE))) %>%
          remove_na_columns() %>%
          replace_column_names() %>%
          coalesce_columns() %>%
          remove_na_columns()
     
     return(df)
}

# Directory containing the R6 files
file_directory <- here("data/mnrega/r6")
files <- list.files(path = file_directory, 
                    pattern = "\\.csv\\.gz$", 
                    full.names = TRUE)
data_list <- Map(process_r6_files, files)
# map_int(data_list, count_duplicate_colnames)

# Combine
cdf <- bind_rows(data_list, .id = "id") %>%
     mutate(total_in_lakhs_completed  = coalesce(total_in_lakhs_completed, nan_in_lakhs_completed))

missing_by_year <- function(df) {
     df %>%
          group_by(year) %>%
          summarise(
               total_observations = n(),
               across(everything(), list(missing = ~ sum(is.na(.))), .names = "{.fn}_{.col}")
          )
}

write_csv(missing_by_year(cdf), file = here("data/mnrega/mnrega_r6_missing_by_year.csv"))

# 2017 needs ifelse

cdf <- split_r6_cells(cdf)

# mnrega_r6_wide$micro_irrigation_works_in_lakhs_completed_2011

## To wide
mnrega_r6_wide <- cdf %>%
     group_by(state_key) %>%
     filter(n() == length(unique(year))) %>%  # Keep only ids with all years present
     ungroup() %>%
     pivot_wider(id_cols = c(state_key, state, district, block, panchayat),
                 names_from = year, 
                 values_from = c(anganwadi_other_rural_infrastructure_in_lakhs_completed:total_in_lakhs_approved_not_in_progress, 
                                 works_on_individuals_land_category_iv_in_lakhs_completed:flood_ongoing_expenditure),
                 names_sep = "_")

write_parquet(mnrega_r6_wide, here("data/mnrega/mnrega_r6.parquet"))
