# Extract the GP outcomes and the panel variables used in CDM Table C15.
library(arrow)
library(dplyr)
library(haven)
library(here)

source_dir <- Sys.getenv("CDM_DATA_DIR", here("../../tolet/data"))
spending_columns <- as.vector(outer(
  c(
    "water_Labour_exp_Lakhs", "water_Material_exp_Lakhs",
    "sanitation_Labour_exp_Lakhs", "sanit_Material_exp_Lakhs",
    "Labour_exp_disbursed_Lakhs", "Material_exp_disbursed_Lakhs"
  ),
  2011:2018, paste0
))

gp_data <- read_dta(
  file.path(source_dir, "final election caste sbm.dta"),
  col_select = c(
    eleid, districtname, blockname, grampanchayatname, winner, female,
    runningvar2_norm_std, femaleinstrument, tot_new,
    district, block, grampanchayat, all_of(spending_columns)
  )
)
panel_data <- read_dta(
  file.path(source_dir, "SBM_panel.dta"),
  col_select = c(
    eleid, post, muslim_share, femalereservation, runningvar2_norm_std
  )
) |>
  filter(post == 1) |>
  transmute(
    eleid, muslim_share, femalereservation,
    running_variable_cdm = runningvar2_norm_std
  ) |>
  distinct()

# The original merge retains the panel's running variable, not the GP version.
stopifnot(
  !anyNA(gp_data$eleid), !anyDuplicated(gp_data$eleid),
  !anyNA(panel_data), !anyDuplicated(panel_data$eleid)
)
cdm_data <- gp_data |>
  left_join(panel_data, by = "eleid", relationship = "one-to-one") |>
  mutate(
    female_x_muslim = femalereservation * muslim_share,
    inst_x_muslim = femaleinstrument * muslim_share,
    running_x_inst = runningvar2_norm_std * femaleinstrument,
    running_x_muslim = runningvar2_norm_std * muslim_share,
    running_x_inst_x_muslim =
      runningvar2_norm_std * femaleinstrument * muslim_share
  )
stopifnot(nrow(cdm_data) == nrow(gp_data))
write_parquet(cdm_data, here("data/cdm/up_gp_mnrega_2015.parquet"))
