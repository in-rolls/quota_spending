library(arrow)
library(dplyr)
library(here)
library(stringr)
library(stringi)
source(here("scripts/00_utils.R"))

# MNREGA rollout groups are study-specific; election linkage lives upstream.
phase_1 <- unlist(strsplit("Azamgarh, Banda, Barabanki, Chandauli, Chitrakoot, Fatehpur, Gorakhpur, Hamirpur, Hardoi, Jalaun, Jaunpur, Kaushambi, Kushinagar, Lakimpur Khiri, Lalitpur, Mahoba, Mirzapur, Pratapgarh, Rae bareli, Sitapur, Sonbhadra, Unnao", ", "))
phase_2 <- unlist(strsplit("Ambedkar Nagar, Bahraich, Baliya, Balrampur, Basti, Budaun, Eta, Farrukhabad, Gonda, Jhanshi, Maharajganj, Mau, Kanpur Dehat, Sant Kabeer Nagar, Shrawasti, Siddharth Nagar, Sultanpur", ", "))
phase_3 <- unlist(strsplit("Agra, Allahabad, Aligarh, Auraiya, Bagpat, Bareilly, Bijnaur, Bulandshahr, Devaria, Faizabad, Firozabad, Gautam Buddha Nagar, Ghaziabad, Ghazipur, Hathras, Jyotiba Phule Nagar, Itawah, Kanpur Nagar, Kannauj, Kanshiram Nagar, Lucknow, Mathura, Mainpuri, Meerut, Muradabad, Muzaffarnagar, Pilibhit, Rampur, Saharanpur, Shahjahanpur, Sant Ravidas Nagar, Varanasi", ", "))


panels <- list(
  `05_10` = c(2005L, 2010L), `10_15` = c(2010L, 2015L),
  `05_21` = c(2005L, 2010L, 2015L, 2021L)
)
for (name in names(panels)) {
  years <- panels[[name]]
  panel <- read_parquet(up_path(paste0("panels/gp_panel_", paste(years, collapse = "_"), ".parquet"))) |>
    filter(if_all(all_of(paste0("women_reserved_", years)), ~ !is.na(.x))) |>
    mutate(
      district_name_eng_2010 = recode(district_name_eng_2010, "Ramabai Nagar" = "Kanpur Dehat"),
      district_name_2010 = recode(district_name_2010, "रमाबाई नगर" = "कानपुर देहात")
    )
  for (year in years) {
    panel <- panel |> mutate(
      !!paste0("female_res_", year) := .data[[paste0("women_reserved_", year)]] == 1L,
      !!paste0("eng_key_", year) := normalize_string(str_c(
        .data[[paste0("district_name_eng_", year)]], .data[[paste0("block_name_eng_", year)]],
        .data[[paste0("gp_name_eng_", year)]],
        sep = " "
      )),
      !!paste0("phase_1_", year) := .data[[paste0("district_name_eng_", year)]] %in% phase_1,
      !!paste0("phase_2_", year) := .data[[paste0("district_name_eng_", year)]] %in% phase_2,
      !!paste0("phase_3_", year) := .data[[paste0("district_name_eng_", year)]] %in% phase_3
    )
  }
  if (2005L %in% years) {
    panel <- panel |> mutate(
      phase_1_bose_2005 = district_name_eng_2005 %in%
        c("Barabanki", "Chitrakoot", "Fatehpur", "Hardoi", "Lakimpur Khiri"),
      phase_2_bose_2005 = district_name_eng_2005 %in% c("Ambedkar Nagar", "Basti", "Eta", "Jhanshi")
    )
  }
  stopifnot(!anyNA(panel$key_2010), !anyDuplicated(panel$key_2010))
  write_parquet(panel, here("data/up", paste0("up_", name, ".parquet")))
  message("up_", name, ": ", nrow(panel), " linked GPs with observed reservation")
}
