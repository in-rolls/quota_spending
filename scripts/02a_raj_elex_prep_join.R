# Load libs.
library(readr)
library(arrow)
library(tidyverse)
library(stringi)
library(here)

# Load util
source(here("scripts/00_utils.R"))

# Load dat

## Excluding Baran because they did not follow any reservation recommendations -
## Have added a footnote in the paper

#MGNREGA came to force on 2006 in Rajasthan and implemented in a phased manner.
#In Rajasthan, out of total 33 districts, 
# 6 districts namely Banswara, Dungarpur, Jhalawar, Karauli, Sirohi, Udaipur were covered in Phase I 
# of MGNREGA (2006-2007); another 6 districts
#comprising of Barmer, Chittorgarh, Jaisalmer, Jalore, Sawai Madhopur and Tonk were covered
#in Phase II of MGNREGA (2007-2008) and from April 1, 2008, remaining 21 districts, including
#Jaipur, Dausa and Sikar, were covered in Phase III of MGNREGA.
# https://www.ijamtes.org/gallery/156.aug%20ijmte%20%20-%20879.pdf
# https://www.inspirajournals.com/uploads/Issues/136293092.pdf

## The seat links come from the state repository, which builds them from one reviewed
## crosswalk per election pair. What stays here is this study's sample: no Baran, and
## the MNREGA rollout phase of each district.
study_panel <- function(file, years) {
     panel <- read_parquet(raj_path(file)) %>%
          filter(district_std_2010 != "BARAN")
     for (year in years) {
          caste <- panel[[paste0("reserved_caste_", year)]]
          woman <- panel[[paste0("reserved_woman_", year)]]
          panel[[paste0("female_res_", year)]] <- woman
          panel[[paste0("caste_res_", year)]] <- caste
          panel[[paste0("reservation_", year)]] <- paste0(caste, ifelse(woman == 1, "W", ""))
     }
     panel %>%
          mutate(dist_name_new_2010 = tolower(district_std_2010),
                 samiti_name_new_2010 = samiti_std_2010,
                 gp_new_2010 = gp_std_2010,
                 dist_name_2005 = district_std_2005,
                 dist_name_2010 = district_std_2010,
                 samiti_name_2010 = samiti_std_2010,
                 key_2005 = source_id_2005,
                 key_2010 = source_id_2010,
                 sex_2010 = ifelse(winner_woman_2010 == 1, "F", "M"),
                 match_name = normalize_string(paste(dist_name_new_2010, samiti_name_new_2010, gp_new_2010)),
                 phase_1 = dist_name_new_2010 %in% c("banswara", "dungarpur", "jhalawar", "karauli", "sirohi", "udaipur"),
                 phase_2 = dist_name_new_2010 %in% c("barmer", "chittaurgarh", "jaisalmer", "jalor", "sawai madhopur", "tonk"))
}

elex_raj_05_10 <- study_panel("data/release/linkage/sarpanch_2005_2010.parquet", c(2005, 2010)) %>%
     mutate(case = paste0(female_res_2005, female_res_2010, sep = "_"))
stopifnot(!anyDuplicated(elex_raj_05_10$match_name))

write_parquet(elex_raj_05_10, sink = here("data/raj/elex_raj_05_10.parquet"))

# 05_10_15_20
elex_raj_05_20 <- study_panel("data/release/linkage/sarpanch_2005_2020.parquet", c(2005, 2010, 2015, 2020)) %>%
     mutate(case = paste(female_res_2005, female_res_2010, female_res_2015, female_res_2020, sep = "_"),
            sex_2015 = winner_woman_2015,
            dist_name_new_2015 = district_std_2015,
            samiti_name_2015 = samiti_std_2015,
            gp_new_2015 = gp_std_2015,
            district_2020 = district_std_2020,
            ps_2020 = samiti_std_2020,
            gp_2020 = gp_std_2020)
stopifnot(!anyDuplicated(elex_raj_05_20$match_name))

write_parquet(elex_raj_05_20, sink = here("data/raj/elex_raj_05_20.parquet"))
