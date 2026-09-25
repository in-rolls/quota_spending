## New Evidence on the Effects of Randomly Assigned Reservations for Women Leaders in Indian Local Government

### Replication Materials

* [Data](data/)
	* SHRUG 2.0 can be downloaded from: https://www.devdatalab.org/shrug. 
	* MNREGA data can be downloaded from: https://doi.org/10.7910/DVN/ZHF9WC
	* UP Local Election data repository: https://github.com/in-rolls/local_elections_up
* [Scripts](scripts/)
	* Please get started with the [India Reservations.Rproj](India Reservations.Rproj) file. Restore the packages in `renv.lock`, then run the script groups described below.
* [Outputs](tabs/)

### UP compliance and CDM appendix tables

Run `Rscript scripts/07b_up_main_mnrega_outcomes.R` for the
reservation regressions and `tabs/up_reservation_compliance.tex`. Compliance
is the recorded female-winner percentage among reserved GPs with known winner
sex in the linked MNREGA sample; missing sex is reported separately.

Run `Rscript scripts/07d_up_cdm_fuzzy_rd.R` for
`tabs/mnrega_up_cdm_fuzzy_rd.tex` and full-precision estimates in
`output/cdm_mnrega_fuzzy_rd.csv`. This reproduces Table C15 of Chaturvedi,
Das and Mahajan (September 2023), *When Do Gender Quotas Change Policy? Evidence
from Household Toilet Provision in India*: overall and Muslim-share interaction
specifications at bandwidths 0.100, 0.075 and 0.050. The outcome is FY 2016–17
NREGS expenditure in thousands of rupees per person. Estimation uses
`estimatr::iv_robust`, triangular weights, separate slopes, and HC0 standard
errors matching the source code. The tables use `knitr` and `kableExtra`.

The source merge retains `runningvar2_norm_std` from `SBM_panel.dta`; the GP
file contains a different version. The cache stores the panel version as
`running_variable_cdm` for `07d`, alongside the GP version used by `07c`.
Rebuild the cache with `Rscript scripts/06c_prepare_cdm.R`, setting
`CDM_DATA_DIR` to the directory containing `SBM_panel.dta` and
`final election caste sbm.dta` (default: `../tolet/data`). The extract is shared
by both analyses; running the tables does not require the source files.

`07c_up_cdm_mnrega_spending.R` supplies separate unadjusted, district-adjusted,
and local common-slope OLS associations; these are not the source paper's fuzzy
RD. The main tables assume an absent spending category means zero expenditure
when both total-expenditure components are recorded for that GP-year. Both category
components must be absent; a partially missing amount remains missing. This is an
assumption about categories with no projects, not a verified coding correction.
Observed amounts are retained. Entirely unavailable total spending remains missing.
Period totals sum available annual amounts, including partially observed periods.
All spending measures are thousands of rupees per person. The earlier period
includes FY 2015–16, which spans the October 2015 election.

The existing output CSVs retain both `absent_category_zero` (main tables) and
`recorded_only` (exclude absent categories) under `assumption`.
`output/cdm_mnrega_summary.csv` distinguishes source-observed coverage (`observed`),
coverage under each assumption (`available`), and GPs with any assumed-zero year
(`with_assumed_zero`). Of 9,203 GPs with known reservation, post-period sanitation
and water amounts are recorded for 2,643 and 107, respectively; the main assumption
makes both outcomes available for 8,688 GPs. The remaining 515 have no reported
total spending in the post period.

At bandwidth 0.10, this changes the sanitation coefficient from −0.64 to −0.19
rupees per person (N 2,131 to 6,852) and the water coefficient from −12.79 to −0.17
(N 83 to 6,852); both 95% intervals include zero under either assumption.
These comparisons depend on how absent categories are interpreted. Total-spending
estimates and the Table C15 fuzzy-RD replication are unchanged. Full-precision
results are in `cdm_mnrega_local_ols.csv` and `cdm_mnrega_ols.csv` under `output/`.

### Linkage and validation

`scripts/04_lgd_shrug_elex_join.R` links the Rajasthan and Uttar Pradesh
reservation histories prepared by `02a` and `02b` to outcome geography.

Each row in `data/{raj,up}/shrug_lgd_{raj,up}_elex_05_10.parquet` is one unique
SHRUG location (`shrid2`) assigned to one LGD panchayat (`local_body_code`, stored
as a character identifier) and one election history (`election_id`). Several
SHRIDs may belong to one panchayat. Downstream scripts aggregate these once per
panchayat, retaining its 2005 and 2010 reservation indicators.

The join uses the SHRUG Census 2011 village crosswalk and the supplied LGD 2024
village-to-panchayat mapping. The analysis uses the Census 2001-covered SHRUG
universe. Every constituent village of a SHRID must map to the same GP. A known
GP touching an unresolved SHRID is withheld entirely to avoid partial totals.
Missing GP names and codes cannot form a panchayat.

Election names are compared within normalized districts using `stringdist`'s
Jaro distance (`method = "jw", p = 0`) with a cutoff of less than 0.15. A link must be the unique nearest match in both directions, across
distinct GP IDs; name aliases for the same GP do not create competing candidates.
Ties and competing election histories are left unresolved. When both names contain
numbers, their numeric sequences must agree, including Devanagari numerals. Matching precedes
geographic exclusions so an unusable target does not redirect an election to
its second-best candidate. The `_strict.parquet` files contain accepted exact
normalized-name matches.

These are conservative linkage choices, not verified identities. In particular,
2024 LGD geography need not equal election-year boundaries. Exact-name estimates
are a sensitivity analysis on a different sample, not a validation of fuzzy links.
UP cross-election linkage is produced upstream, with ties and competing identities left unresolved.

Two compact intermediate files per state make exclusions inspectable:

- `shrug_lgd_geography.parquet`: one row per distinct Census village–GP mapping
  within a SHRID, including unavailable mappings. `geography_status` records
  missing or conflicting constituent mappings; `gp_withheld` flags affected GPs.
- `lgd_election_links.parquet`: every election and its nearest GP candidate(s),
  Jaro distance, tie counts, reservation history, and final `match_status`.
  Rejected elections without candidates retain missing target fields. Candidates
  tied for nearest are retained separately; accepted links are one-to-one.
  `election_margin` is the second-smallest minus smallest Jaro distance across
  distinct GP IDs; `gp_margin` is the corresponding gap across eligible election
  IDs. Both are computed within district before the distance cutoff and geographic
  exclusions. Zero indicates a tie; `NA` means no runner-up exists (or no
  candidates exist). For a rejected non-best candidate, `gp_margin` describes
  that GP's best two elections, not the candidate's distance from the best.

The margin diagnostics draw on
[preclink's ambiguity filter](https://github.com/finite-sample/preclink/blob/c0389af4acb38a314039073752d6f2bb4e81c368/src/preclink/filter/margin.py),
extended to both directions here. They describe ambiguity without determining
which links are accepted.
A gap below .01 in either direction flags 169/1,608 accepted fuzzy links in
Rajasthan and 1,581/6,930 in UP; no accepted exact link meets this flag.
This is an illustrative review threshold, not a calibrated error probability or
an exclusion rule. The validation script reproduces these counts. The analysis
continues to run entirely in R.

The linked files contain 3,411 panchayats / 12,637 SHRIDs in Rajasthan and
9,014 panchayats / 14,758 SHRIDs in Uttar Pradesh. Accepted exact-name links
account for 1,803 and 2,084 panchayats, respectively. Of prepared election
histories, the accepted proportions by sequence (2005, 2010) are:

| State | 0,0 | 0,1 | 1,0 | 1,1 |
|---|---:|---:|---:|---:|
| Rajasthan | 1,178/2,784 | 1,096/2,553 | 593/1,398 | 544/1,282 |
| Uttar Pradesh | 3,204/14,665 | 1,587/7,650 | 2,842/13,345 | 1,381/6,230 |

Here 1 denotes reservation for women. Similar acceptance proportions do not
establish accurate matching or random assignment in the retained sample.

To rebuild the linkage with the cached sources listed in `data/manifest.yaml`,
run from the repository root:

```sh
Rscript scripts/04_lgd_shrug_elex_join.R
Rscript scripts/validate_linkage.R a8f5cca
```

The validation script uses `testthat` (install it with
`install.packages("testthat")` if needed). It checks ambiguous and competing
matches, row-order invariance, uniqueness, geographic exclusions, and Parquet
round trips. It also writes `tabs/linkage_comparison.csv` with historical,
repaired, and exact-name estimates for four selected outcomes, including sample
sizes, outcome means, standard errors, confidence intervals, and p-values.
A fourth diagnostic, `historical_reversed`, reverses the historical rows to
reproduce the original order dependence; it is not an alternative analysis.
`a8f5cca` identifies the historical analytical files in Git; it has not been
established as the manuscript's version. The comparison holds outcome definitions,
equal-GP weighting, and conventional OLS inference fixed.

Regenerate balance tables with `05a` and `05b`, the long-term tables with `09a`
through `13b`, and the Rajasthan caste-health table with `16a`. Outputs overwrite
`tabs/`. The lockfile records R 4.6.0 and the package versions used in local
validation. Restore them with `Rscript -e 'renv::restore()'`.

### Social Audit

https://mnregaweb4.nic.in/netnrega/SocialAuditFindings/SA-GPReport.aspx?page=S&lflag=eng

### Authors

Don Green, Manu Singh, and Gaurav Sood

## 🔗 Adjacent Repositories

- [in-rolls/mnrega_social](https://github.com/in-rolls/mnrega_social) — MNREGA Social Audit Data
- [in-rolls/electoral_rolls_up_2023](https://github.com/in-rolls/electoral_rolls_up_2023)
- [in-rolls/local_elections_kerala](https://github.com/in-rolls/local_elections_kerala) — Kerala Local Government Seat Reservation Data and Winner Attributes
- [in-rolls/local_elections_up](https://github.com/in-rolls/local_elections_up) — UP Local Election Data --- GP and ULB. Seat reservation, winner, and candidates for some elections
- [in-rolls/local_elections_bihar](https://github.com/in-rolls/local_elections_bihar) — Candidate Info. + Valid Votes Won by Cands. in the 2016 Bihar Panchayat Elections

Rajasthan election sources and historical manual election linkages are consumed from a pinned commit of `local_elections_rajasthan`, with SHA-256 checks in `data/manifest.yaml`. Files resolve from the versioned cache, a sibling checkout, or the pinned GitHub source. The migration preserves source values and historical links; study-specific exclusions and election-to-outcome joins remain here. These Rajasthan manual-history inputs are a separate upstream vintage from the one-to-one panels used by `quota_representation`. They retain older link decisions and 2020 reservation values; sharing the provider does not make those panels interchangeable.


UP cross-election panels and Weaver preparations are produced in
`local_elections_up`. This repository and `quota_representation` pin the same commit and
SHA-256 values in their manifests. Adjacent-year links are built independently,
then composed through identical intermediate source-election IDs. Name
normalization preserves Hindi vowel marks and rejects conflicting numeric
sequences, including GP 45 versus GP 44. Shared raw inputs and historical fuzzy
panels are not duplicated here. `02b` adds MNREGA rollout flags and study variables;
`03b` and `04` join the resulting election histories to outcomes. Unknown
reservation is excluded after linkage. Weaver vintages remain separate upstream;
`99_narasimhan_weaver.R` retains its explicitly pinned earlier source vintage.
