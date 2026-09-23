# WB analysis audit: Nadia demand extension and Birbhum reproduction

Scope: separate WB analyses in this folder. The parent quota paper and its
Rajasthan/UP pipelines are not audited or modified here. Original Birbhum
source preparation, selected replication rows and 2003 public-goods estimates
were rerun independently before this addition; their numerical results remain
unchanged. Nadia is a separate district, exposure year and outcome construct.

## Claims and their limits

The Nadia estimand is the equally weighted association of 2013 women's Pradhan
reservation with FY2014–15 reported work demand, among 100 source-linked GPs in
13 blocks outside singleton caste strata. Two OLS models adjust for the same
outcome in FY2012–13, source caste category and block. Each GP is one row; years
occupy wide columns. Neither a GP-year pooled regression nor DiD is estimated.

Primary household-month demand: -212.513 (HC2 SE 733.261; 95% interval
-1670.938 to +1245.913). Primary person-month demand: -771.628 (SE 1129.890;
interval -3018.933 to +1475.677). Both primary Holm p-values are 0.993114.
Marginal intervals are not simultaneous confidence intervals. Household-month
and person-month counts are sums of twelve monthly demand counts, not annual
unique households/people, employment days, spending or completed works.

These calculations answer a descriptive administrative-outcome question. A
pre-election outcome and contemporaneous allocation strata are reasonable
adjustments for this comparison, but do not establish exchangeability under
rotation or eliminate reporting/geographic selection. Correct computation does
not make the estimate causal. The intervals allow large associations in either
direction; they are not evidence of no effect.

## Check matrix

| Check | Evidence and disposition |
|---|---|
| Tier 1: units/denominators | Source187 offices, bridge161, two-year demand links101, model100; household/person-month units explicit. No household denominator for a person share. |
| Tier 1: missing as zero | Blank head category stays NA; unknown reservation codes rejected; twelve observed nonnegative monthly values required. No skipped-missing sum. |
| Tier 1: row conservation | All187 office rows and187 demand GP rows retained in separate audits. Every model uses the same100GP IDs; joins assert uniqueness. |
| Tier 1: provenance | Parsed office/bridge hashes, originalPDF, raw-subset hashes and frozen plan verified before analysis. Archive/Git identifiers document extraction without restoring deleted files. |
| Tier 1: consistency | Source key sets agree across both years; unknown head code never inherited from deputy; duplicate office/membership names excluded from matching. |
| Tier 2 A: EDA | Linked demand levels, support by block/caste, all exclusions and influence exported. Household mean7896.82 and person mean11156 in the non-women-reserved group provide scale. |
| Tier 2 B: joins | Case/separator normalization only; suffixes retained. Unique office→printed membership→district/block/GP demand joins. All nine punctuation-only membership gains exported. No fuzzy matches or block assignment from model values. |
| Tier 2 C: construction | R3 demand endpoint and monthly headers support work-demand interpretation. FY2012–13 precedes2013 election; FY2014–15 follows it. Later archive retrieval is not outcome year. |
| Tier 2 D: estimand | Equal-GP association in the selected linked non-singleton-caste sample. No all-Nadia/WB population claim, gender-of-winner inference or causal leadership effect. |
| Tier 2 E: inference | Explicit HC2 primary, HC3 and administrative-block CR2 sensitivities. CR2 has13 blocks and coefficient-specific df about10.49; all13 contain treated GPs. No presumed block lottery. |
| Tier 2 F: skew | Household-month range946–20134, person-month1261–42546. No winsorization. Leave-one-GP-out household coefficient ranges-522.768 to+103.531; person-1256.090 to-409.722. Sign stability is not significance. |
| Tier 3: significance/forking | Initial plan archived before outcome estimation. A dated outcome-blind support amendment excluded singleton caste categories; exposure/design had already been inspected. All four specification families/two outcomes reported, with Holm per family. |
| Tier 3: measurement/attrition | Full source classifications, explicit blank and exact-link exclusions visible. Only100/187 enter models; external validity is limited and unidentified outcomes/links are not imputed. |
| Tier 3: assignment/covariates | Prior demand and source caste/block adjustment are disclosed. Contemporary assignment list/order and previous reservations are absent. No independence-test p-value validates assignment. |
| Tier 3: simulation/permutation | Synthetic negative/NA/duplicate/tamper tests validate construction, not causal sampling coverage. Unrestricted permutation is inapplicable without a justified assignment mechanism. |
| Tier 3: comparisons/multilevel | Same-sample unadjusted and adjusted estimates reported. Block CR2 models within-block dependence. No claim from significance differences between outcomes or district studies. |
| Tier 4: design matrix | Initial101-GP plan had one STGP with leverage1. Support amendment retains it in audit and excludes it from every model. Final design rank17, df83; max leverage0.511 household/0.517 person. |
| Tier 4: relevant branches | Observational cross-section, selection, clustered inference and measurement apply. IV/RD/DiD/event-study/prediction branches are inapplicable. No estimated treatment score or generated causal mediator is used. |
| Tier 4: robustness | HC3/CR2 intervals include zero; all leave-one-out estimates recorded. No influential GP is deleted because of its outcome. Inference remains conditional on chosen identities and reported demand. |

## Independent validation and adversarial checks

Base R lm plus sandwich HC2 independently reproduces both primary coefficients
and standard errors. A separate computational reviewer recovered both national archives, verified
their hashes, independently filtered the Nadia subsets and matched every raw
cell. Independent matrix algebra reproduced all monthly sums, join counts,
primary coefficients and HC2 intervals. Removing the saturated singleton leaves
the q13 coefficients unchanged to 1.6e-12 while making robust inference defined.
Source preparation and synthetic tests check ambiguous names, Roman/numeric
suffix preservation, blank-category coding, missing monthly fields, negative
counts, source tampering and full-rank residual support. The drivers/tests and
R lint run locally. Generated figures are visually inspected.

The mechanical data-audit helper is applied to the 100-GP analytical file;
its optional Python leverage routine is replaced by the explicitly calculated
R leverage output. Markdown numerical provenance is checked against generated
CSV tables because the skill's LaTeX resolver does not support these reports.
No parent-paper prose or result was changed.

The original Birbhum checks reproduce161 complete1998GP records and322 sampled
village observations. Selected released-archive estimates differ from some
published benchmarks and remain labeled as reconstructions, not an exact full
paper replication. The2003 public-goods outcomes are reported at the2006 visit
for the period since2003; their exploratory estimates and varying sample sizes
remain in RESULTS.md. The projects are not pooled into a common panel or index.

Rejected concerns: the national MNREGA files are not exclusively Rajasthan/UP;
those states characterize previously prepared extracts, while raw national
archives contain Nadia. A deleted2012 working file is recoverable from Git and
does not imply an absent baseline. R3 demand is not actual employment supplied.
A singleton caste dummy is a real inferential support issue, not evidence that
ST is equivalent to another category. A null coefficient is not proof of no
association. Exact normalization does not establish historical GP boundaries.

Untestable here: actual allocation/rotation order, unrecorded demand, changes
in report coverage, boundary continuity, remaining ambiguous GP identities,
latent work need and employment actually delivered. The linked sample may be
selected on determinants of both quota status and demand. More precise causal
claims need additional history/identity evidence and a separate design.

Source construct evidence: the archived national extraction was produced by
[the R3 scraper](https://raw.githubusercontent.com/in-rolls/mnrega/main/scripts/mnrega_r3.py),
which requests the government demand report with financial-year parameters.
The raw monthly Household/Persons columns and full extraction provenance are
retained under data/nadia_raw/. The [estimatr mathematical notes](https://declaredesign.org/r/estimatr/articles/mathematical-notes.html)
document HC2/HC3 and CR2 inference used here.
