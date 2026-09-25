# West Bengal: public-goods replication and administrative demand analysis

This folder reconstructs selected Chattopadhyay–Duflo results in R and extends
the public-goods question to the Beaman project's named Birbhum 2003-term data.
Read [RESULTS.md](RESULTS.md) for generated estimates and intervals. The released
archive does not exactly reproduce every published benchmark; disagreements
are retained and tabulated. This is not a complete paper replication.

The 1998 analysis compares women-reserved versus unreserved offices among161
non-pretest GPs, using322 randomly sampled villages for village outcomes. The
2003 extension relates office reservation to goods reported since 2003 in the
2006 current-officeholder survey. Rotation, self-reporting and selection make
these later estimates exploratory associations.

A separate [Nadia analysis](NADIA_RESULTS.md) links the newly recovered 2013
Pradhan reservation roster to reported MNREGA work demand in FY2012–13 and
FY2014–15. The strict model sample has 100 GPs in 13 blocks. Demand counts are
not employment provided or expenditure; the estimates are exploratory
associations. See the [plan and support amendment](nadia_pap.md),
[join contract](nadia_join_contract.md), [dictionary](nadia_dictionary.csv),
and [audit](NADIA_AUDIT.md).

## Broader source availability

The Birbhum and Nadia exercises address different outcomes and were not chosen
under an exhaustive statewide sampling rule. The [WB source availability audit](../../local_elections/data/wb/vintage_search/head_outcome_availability.md)
now inventories the acquired research and official records and a substantial
six-district election-package lead. That package is the next acquisition
priority for the sibling `quota_representation` persistence question; its metadata counts
are not yet verified GP counts. Nadia's roster supplies office reservation,
not observed Pradhan sex. No new source has been pooled into these analyses.

Source URLs, original documents where acquired, retrieval metadata, hashes and
page-level review records are retained in `local_elections`; these analyses
pin their actual inputs with source manifests. Original readings and unresolved
conflicts remain available for independent checking.

## Run

From the quota root:

```sh
Rscript --vanilla wb/run.R
Rscript --vanilla wb/tests/run_tests.R
```

`--prepare-only` runs source preparation and data contracts without estimation.
The scripts locate their own folder, so they also work from other directories.
By default the raw sources are read from the sibling `../local_elections`.
Set `WB_LOCAL_ELECTIONS` to override that path. No network download runs during
analysis. Every raw source must match [source_manifest.csv](source_manifest.csv).

Required R packages: haven, arrow, dplyr, digest, jsonlite, estimatr, broom,
knitr, ggplot2; sandwich is also used by the independent covariance test.
[renv.lock](renv.lock) records the versions used; restore in an isolated library
if the parent project's environment differs. `logs/sessionInfo.txt` records
the actual runtime environment. No existing parent pipeline is invoked.

## Files and provenance

- `scripts/00_common.R`: shared R source reader, recodes, joins and inference;
  also used by the sibling quota_representation WB extension.
- `scripts/01_public_goods.R`: released-data benchmark comparisons, exploratory
  current/prior-quota models, missingness, support and sensitivity tables.
- `data/cd_gp_identifiers.*`:166 raw GP names/block names linked by `gpnum`.
- `data/cd_village_identifiers.*`:498 survey village records,483 named;
  `villnum` identifies a village only within GP. `jlnum` is not a district-wide
  unique ID or an established Census/LGD crosswalk.
- `data/beaman_gp_identifiers.*`:165 named GPs and both raw reservation IDs.
- `data/gp_1998.parquet`, `villages_1998.parquet`, `gp_2003_followup.parquet`:
  typed, unpooled source analysis tables. CSV copies facilitate inspection.
- [dictionary.csv](dictionary.csv): every column in the three analysis tables.
  `data/source_dictionary.csv` preserves Stata labels, value labels and profiles.
- `data/*audit*`, `data/validation.json`, `tabs/selection_by_reservation_history.csv`:
  join, recode, source-conflict, temporal-eligibility and selection records.
- [pap.md](pap.md): pre-estimation choices and known unblinding; retrospective,
  not a preregistration. `logs/design_review.md` records independent review.

The CD ZIP matches the four main DTA files already in `data/c_d_rep/` byte for
byte. Part A has research GP IDs; Part B supplies GP/block names; Part D supplies
village names and JL numbers. Current Beaman respondents link through `temp_id`
to reservation `AA0_2b`; Ganpur (named Gonpur in the survey) has a conflicting
survey code and is excluded in the
main sample and retained in an explicit sensitivity. These are research IDs,
not verified official geographic codes.

## Interpretation and inference

The target of the original comparison is the effect of reservation, which may
change experience, selection and competition as well as leader gender. GP-level
models use explicit HC2; repeated village observations use GP-clustered CR2.
SE comparisons are separate from the printed historical standard errors.
Holm-adjusted p-values accompany each three-outcome extension family. Confidence
intervals and all sample sizes are exported; there is no significance-selected
sample, fuzzy identity fill, or global conversion of missing codes to zero.

A gate reporting No can imply zero for an unconditional quantity when the
amount is missing or zero. Positive contradictory amounts and unknown answers
remain missing. Current absence of a school does not by itself establish no
creation since 2003. Quantities have distinct units and appear in separate plot
panels. The 1998 and 2003 surveys have different recall horizons; this is not a
pooled before/after or difference-in-differences estimator.

Long-run Birbhum MNREGA/SHRUG questions still need a verified historical
GP-to-Census/LGD crosswalk. Nadia uses printed source blocks and exact normalized
names for a separate near-term demand analysis; it does not establish national
GP codes, unchanged boundaries or continuity with the Birbhum surveys.

Sources: [Chattopadhyay–Duflo, NBER w8615](https://www.nber.org/system/files/working_papers/w8615/w8615.pdf),
[Beaman public mirror](https://github.com/in-rolls/beaman), and
[estimatr inference documentation](https://declaredesign.org/r/estimatr/reference/lm_robust.html).

Nadia raw subsets live in `data/nadia_raw/`; their original archive/Git
provenance is retained. `nadia_source_manifest.csv` pins inputs and the frozen
plan. `data/nadia_demand_join_audit.*` retains all 187 offices, including every
exclusion; `data/nadia_demand_analysis.*` contains the 100 model observations.
The driver regenerates both projects within this folder without restoring
deleted national source files or running the parent analysis pipeline.
