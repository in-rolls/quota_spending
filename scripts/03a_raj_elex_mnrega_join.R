# Load libs
library(readr)
library(tidyverse)
library(stringi)
library(stringdist)
library(dplyr)
library(purrr)
library(progress)
library(here)
library(arrow)
library(fuzzyjoin)

source(here("scripts/00_utils.R"))

# Let's load elex data
elex_raj <- read_parquet(raj_path("data/release/sarpanch_source_records.parquet"))

elex_raj_05_10 <- read_parquet(here("data/raj/elex_raj_05_10.parquet"))
elex_raj_05_20 <- read_parquet(here("data/raj/elex_raj_05_20.parquet"))

# Prep. Elex. for MNREGA Merge
# Get Elex data PS/Block Mapping
# Caveat = a bunch of PS are simply missing from the elex. data
# Options = 1-many match or this may reflect Gehlot's 2023 announcement of 19 new districts
elex_mnrega_ps_block <- read_csv(here("data/raj/elex_mnrega_ps_block_crosswalk.csv"))

mnrega_match_name <- function(data, district, samiti, gp) {
     data %>%
          left_join(elex_mnrega_ps_block, by = setNames(c("district_std", "samiti_std"), c(district, samiti))) %>%
          mutate(match_name = normalize_string(gsub(" ", "", paste0(.data[[district]], mnrega_block_name, .data[[gp]])))) %>%
          filter(!is.na(mnrega_block_name)) %>%
          filter(!match_name %in% match_name[duplicated(match_name)])
}

# Year wise
elex_raj_10_r <- elex_raj %>% filter(year == 2010) %>% mnrega_match_name("district_std", "samiti_std", "gp_std")
elex_raj_15_r <- elex_raj %>% filter(year == 2015) %>% mnrega_match_name("district_std", "samiti_std", "gp_std")
elex_raj_20_r <- elex_raj %>% filter(year == 2020) %>% mnrega_match_name("district_std", "samiti_std", "gp_std")

# Multi-year
elex_raj_05_10_r <- elex_raj_05_10 %>% mnrega_match_name("district_std_2010", "samiti_std_2010", "gp_std_2010")
elex_raj_05_20_r <- elex_raj_05_20 %>% mnrega_match_name("district_std_2010", "samiti_std_2010", "gp_std_2010")

# Load dat
mnrega_r1 <- read_parquet(here("data/mnrega/mnrega_r1.parquet"))
mnrega_r3 <- read_parquet(here("data/mnrega/mnrega_r3.parquet"))
mnrega_r5 <- read_parquet(here("data/mnrega/mnrega_r5.parquet"))
mnrega_r6 <- read_parquet(here("data/mnrega/mnrega_r6.parquet"))

# Join MNREGA Reports
mnrega_raj_dupes <- mnrega_r6 %>%
     inner_join(mnrega_r1, by = "state_key") %>%
     inner_join(mnrega_r3, by = "state_key") %>%
     inner_join(mnrega_r5, by = "state_key") %>%
     filter(state.x == "RAJASTHAN")

mnrega_raj <- mnrega_raj_dupes %>%
     select(-contains(".y"), -contains(".x.x"), -contains(".y.y")) %>%
     rename_with(~ str_remove(., "\\..*$"))

# pratapgarh is not present in election- 
mnrega_raj <- mnrega_raj %>% 
     mutate(
          district = tolower(district),
          district = case_when(
               district == "chittorgarh" ~ "chittaurgarh",
               district == "dholpur" ~ "dhaulpur",
               district == "jalore" ~ "jalor",
               district == "jhunjhunu" ~ "jhunjhunun",
               district == "sri ganganagar" ~ "ganganagar",
               TRUE ~ district
          )
     )

# Add transliteration
transliterate = read_csv(here("data/mnrega/raj_mnrega_transliteration.csv"))

mnrega_raj <- mnrega_raj %>%
     left_join(transliterate[, c("hindi", "chat_gpt_fin")], by = c("panchayat" = "hindi")) %>%
     mutate(ascii_panchayat = stri_trans_general(chat_gpt_fin, "Latin-ASCII"),
            ascii_panchayat = ifelse(
                 is.na(ascii_panchayat) & !is.na(panchayat),
                 panchayat,
                 ascii_panchayat
            ),
     district = tolower(district),
     match_name =  gsub(" ", "", normalize_string(paste0(district, block, ascii_panchayat)))
     ) %>%
     filter(!match_name %in% match_name[duplicated(match_name)])

# Strict joins
mnrega_elex_raj_10_strict <- elex_raj_10_r %>%
     inner_join(mnrega_raj, by = "match_name")

mnrega_elex_raj_15_strict <- elex_raj_15_r %>%
     inner_join(mnrega_raj, by = "match_name")

mnrega_elex_raj_20_strict <- elex_raj_20_r %>%
     inner_join(mnrega_raj, by = "match_name")

mnrega_elex_raj_05_10_strict <- elex_raj_05_10_r %>%
     inner_join(mnrega_raj, by = "match_name")

mnrega_elex_raj_05_20_strict <- elex_raj_05_20_r %>%
     inner_join(mnrega_raj, by = "match_name")

process_row <- function(row, right_table) {
     
     right_table_subset <- right_table %>%
          filter(
               (tolower(row$dist_name_new_2010) == tolower(district)) &
                    (tolower(row$mnrega_block_name) == tolower(block)))
     
     # If no matching district found, return NULL
     if (nrow(right_table_subset) == 0) return(NULL)
     
     match_result <- stringdist_left_join(
          row,
          right_table_subset,
          by = "match_name",
          method = "jw",
          ignore_case = TRUE,
          distance_col = "dist_mnrega_match"
     ) %>%
          slice_min(dist_mnrega_match)
     
     return(match_result)
}

mnrega_elex_raj_05_10 <- elex_raj_05_10_r %>%
     split(seq(nrow(.))) %>%
     map_dfr(~ process_row(.x, mnrega_raj))

mnrega_elex_raj_05_20 <- elex_raj_05_20_r %>%
     split(seq(nrow(.))) %>%
     map_dfr(~ process_row(.x, mnrega_raj))

# Remove duplicates and filter down to where dist_mnrega_match < .1
mnrega_elex_raj_05_10_dedupe <- mnrega_elex_raj_05_10 %>%
     filter(dist_mnrega_match < .1) %>%
     group_by(match_name.x) %>%
     filter(n() == 1) %>%
     ungroup() %>%
     group_by(match_name.y) %>%
     filter(n() == 1) %>%
     ungroup()

mnrega_elex_raj_05_20_dedupe <- mnrega_elex_raj_05_20 %>%
     filter(dist_mnrega_match < .1)%>%
     group_by(match_name.x) %>%
     filter(n() == 1) %>%
     ungroup() %>%
     group_by(match_name.y) %>%
     filter(n() == 1) %>%
     ungroup()

write_parquet(mnrega_elex_raj_10_strict, sink = here("data/raj/mnrega_elex_raj_10_strict.parquet"))
write_parquet(mnrega_elex_raj_15_strict, sink = here("data/raj/mnrega_elex_raj_15_strict.parquet"))
write_parquet(mnrega_elex_raj_20_strict, sink = here("data/raj/mnrega_elex_raj_20_strict.parquet"))

write_parquet(mnrega_elex_raj_05_10_strict, sink = here("data/raj/mnrega_elex_raj_05_10_strict.parquet"))
write_parquet(mnrega_elex_raj_05_20_strict, sink = here("data/raj/mnrega_elex_raj_05_20_strict.parquet"))

write_parquet(mnrega_elex_raj_05_10_dedupe, sink = here("data/raj/mnrega_elex_raj_05_10.parquet"))
write_parquet(mnrega_elex_raj_05_20_dedupe, sink = here("data/raj/mnrega_elex_raj_05_20.parquet"))
