library(arrow)
library(dplyr)
library(here)
library(janitor)
library(purrr)
library(readr)
library(stringi)
library(stringr)
library(tidyr)

source(here("scripts/00_utils.R"))
source(here("scripts/00_linkage.R"))

# SHRIDs can contain multiple Census villages. Use the supplied crosswalk,
# retaining missing constituent mappings until their completeness is checked.
census_keys <- read_csv(
  shrug_path("shrug-pc-keys-csv/pc11r_shrid_key.csv"),
  col_types = cols(.default = col_character())
) |>
  filter(pc11_state_id %in% c("08", "09")) |>
  select(
    shrid2, pc11_state_id, pc11_district_id,
    pc11_subdistrict_id, pc11_village_id
  )
stopifnot(!anyDuplicated(census_keys[c("pc11_state_id", "pc11_village_id")]))

# Retain the original analysis universe with observed Census 2001 data.
census_2001 <- read_csv(
  shrug_path("shrug-pca01-csv/pc01_pca_clean_shrid.csv.zip"),
  col_select = shrid2, col_types = cols(shrid2 = col_character())
)
census_keys <- semi_join(census_keys, census_2001, by = "shrid2")

for (state in c("raj", "up")) {
  state_id <- if (state == "raj") "08" else "09"
  lgd_file <- if (state == "raj") {
    raj_path("data/reference/geography/raj_village_gp_mapping_2024.csv")
  } else {
    sibling_path("data/external/lgd/up_village_gp_mapping_2024.csv")
  }
  lgd <- read_csv(lgd_file, col_types = cols(.default = col_character())) |>
    clean_names() |>
    mutate(
      district_key = normalize_string(district_name),
      lgd_name = str_remove_all(
        normalize_string(str_c(
          district_name, subdistrict_name, local_body_name
        )),
        " "
      ),
      valid_gp = if_all(c(
        district_name, subdistrict_name, local_body_name,
        local_body_code
      ), ~ !is.na(.x) & str_trim(.x) != "")
    )
  gp_catalog <- lgd |>
    filter(valid_gp) |>
    distinct(local_body_code, district_key, lgd_name)

  # Numeric Census codes identify villages; names are used only for elections.
  village_gps <- lgd |>
    transmute(
      pc11_village_id = village_census_2011_code,
      local_body_code = if_else(valid_gp, local_body_code, NA_character_)
    ) |>
    filter(!is.na(pc11_village_id), pc11_village_id != "000000") |>
    distinct()
  # A village can have several LGD mappings. Retain this explicit relation to
  # detect ambiguity, rather than selecting one mapping before the check.
  geography <- census_keys |>
    filter(pc11_state_id == state_id) |>
    left_join(village_gps,
      by = "pc11_village_id", relationship = "many-to-many",
      na_matches = "never"
    ) |>
    group_by(shrid2) |>
    mutate(geography_status = case_when(
      any(is.na(local_body_code)) ~ "missing_constituent_gp",
      n_distinct(local_body_code) > 1 ~ "multiple_constituent_gps",
      TRUE ~ "resolved"
    )) |>
    ungroup()
  unresolved_gps <- geography |>
    filter(geography_status != "resolved", !is.na(local_body_code)) |>
    distinct(local_body_code)
  gp_villages <- geography |>
    filter(geography_status == "resolved") |>
    anti_join(unresolved_gps, by = "local_body_code") |>
    distinct(local_body_code, shrid2)
  stopifnot(!anyDuplicated(gp_villages$shrid2))
  geography <- geography |>
    mutate(gp_withheld = local_body_code %in% unresolved_gps$local_body_code) |>
    arrange(shrid2, pc11_village_id, local_body_code)
  write_parquet(geography, here("data", state, "shrug_lgd_geography.parquet"))

  if (state == "raj") {
    # Rajasthan's election-to-LGD links are built and reviewed in the state repository.
    elections <- read_parquet(here("data/raj/elex_raj_05_10.parquet")) |>
      mutate(
        election_id = key_2010,
        district_key = dist_name_new_2010,
        election_name = match_name
      )
    matched <- elections |>
      inner_join(
        read_parquet(raj_path("data/release/linkage/gp_lgd_crosswalk.parquet")),
        by = "match_key", relationship = "one-to-one"
      ) |>
      transmute(
        election_id,
        local_body_code = as.character(as.integer(lgd_gp_code)),
        dist_elex_lgd_match = match_distance,
        match_status = match_type
      )
    unmatched_status <- "no_state_link"
  } else {
    elections <- read_parquet(here("data/up/up_05_10.parquet")) |>
      mutate(
        election_id = key_2010,
        valid_election = if_all(
          c(
            district_name_eng_2010, block_name_eng_2010,
            gp_name_eng_2010
          ),
          ~ !is.na(.x) & str_trim(.x) != ""
        ),
        district_key = normalize_string(district_name_eng_2010),
        election_name = str_remove_all(normalize_string(str_c(
          district_name_eng_2010, block_name_eng_2010, gp_name_eng_2010
        )), " ")
      )
  }
  stopifnot(
    !anyDuplicated(elections$election_id), !anyNA(elections$election_id)
  )
  if (state == "up") {
    eligible_elections <- elections |>
      filter(
        valid_election, !is.na(election_name), election_name != "",
        !is.na(district_key),
        !is.na(female_res_2005), !is.na(female_res_2010)
      )
    matched <- eligible_elections |>
      group_split(district_key) |>
      map(function(district_elections) {
        catalog <- filter(
          gp_catalog, district_key == unique(district_elections$district_key)
        )
        match_panchayats(district_elections, catalog)
      }) |>
      list_rbind()
    unmatched_status <- "missing_election_fields"
  }
  accepted_status <- c("exact", "fuzzy", "exact_other_block")
  links <- elections |>
    select(
      election_id, key_2005, district_key, election_name,
      female_res_2005, female_res_2010
    ) |>
    left_join(matched, by = "election_id", relationship = "one-to-many") |>
    mutate(
      match_status = coalesce(match_status, unmatched_status),
      match_status = case_when(
        match_status %in% accepted_status &
          local_body_code %in% unresolved_gps$local_body_code ~
          "unresolved_geography",
        match_status %in% accepted_status &
          !local_body_code %in% gp_villages$local_body_code ~
          "no_census_2001_mapping",
        TRUE ~ match_status
      )
    ) |>
    arrange(election_id, local_body_code)
  write_parquet(links, here("data", state, "lgd_election_links.parquet"))
  print(count(links, match_status), n = Inf)
  coverage <- links |>
    distinct(election_id, female_res_2005, female_res_2010, match_status) |>
    count(female_res_2005, female_res_2010, match_status)
  print(coverage, n = Inf)

  accepted <- links |>
    filter(match_status %in% accepted_status) |>
    select(election_id, local_body_code, dist_elex_lgd_match, match_status)
  stopifnot(
    !anyDuplicated(accepted$election_id),
    !anyDuplicated(accepted$local_body_code)
  )
  analytical <- accepted |>
    inner_join(select(elections, -district_key),
      by = "election_id",
      relationship = "one-to-one"
    ) |>
    inner_join(
      gp_villages,
      by = "local_body_code", relationship = "one-to-many"
    ) |>
    arrange(local_body_code, shrid2)
  stopifnot(
    !anyDuplicated(analytical$shrid2),
    !anyNA(analytical$local_body_code)
  )
  write_parquet(analytical, here(
    "data", state, paste0("shrug_lgd_", state, "_elex_05_10.parquet")
  ))
  write_parquet(filter(analytical, match_status == "exact"), here(
    "data", state, paste0("shrug_lgd_", state, "_elex_05_10_strict.parquet")
  ))
  message(
    state, ": ", n_distinct(analytical$local_body_code),
    " panchayats; ", nrow(analytical), " unique SHRIDs"
  )
}
