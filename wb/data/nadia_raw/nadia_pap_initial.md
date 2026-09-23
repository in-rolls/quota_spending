# Nadia 2013 reservations and later reported work demand

This exploratory plan was written after reviewing source coverage, spelling and
missingness, and before estimating any Nadia reservation–demand association.
The existing Birbhum public-goods results were known. This is not a registered,
blinded, or confirmatory study. No outcome-dependent matching, trimming or
choice of the reported specification is permitted.

The question is whether women's 2013 Pradhan reservation is associated with
reported MGNREGA work demand in FY2014–15, conditional on pre-election demand
in FY2012–13. This is a new demand analysis, not an extension of the survey's
public-goods measurement and not an effect of employment provided or spending.

## Sources, units and timing

The 187-GP Nadia 2013 handbook office synopsis supplies a complete Pradhan
classification with explicit unrestricted categories and one genuinely blank
category. The blank, Taldaha Majdia, stays unknown and is excluded from models.
Separate ZP constituency descriptions in the same handbook, PDF pages71–74,
provide printed block membership. Constituency mistakes, duplicate GP names,
and absent membership cannot be repaired from reservation patterns or row order.

The R3 archive for2012 is recovered from an existing quota Git object without
restoring the deleted working file. The2014 archive is already local. Full
archive SHA256, Git commit/blob ID and subset SHA256 identify the raw provenance.
Both Nadia subsets have187 GP rows and24 monthly quantity fields. The scraper
requests demand_emp_demand.aspx with file1=dmd and fin_year=year-(year+1):2012
means April2012–March2013 and2014 means April2014–March2015. The official report
is R3.1 Work Demand Pattern. These are administrative reports of demand, not a
verified measure of latent need or actual employment supplied. The historical
financial year and the archive's later collection date are distinct.

A monthly count is a household or person recorded as demanding work that month.
Summing twelve household counts gives household-months; summing twelve person
counts gives person-months. It does not yield unique annual households/persons,
workdays or expenditure. Each annual sum requires all twelve values observed
and nonnegative; missing values are never converted to zero.

## Identity and sample

Normalize only case and non-alphanumeric separators, retaining Roman numerals
and numeric suffixes. Join unique office-name keys to unique printed membership
name keys, then use district+printed-block+GP keys for both demand years. No fuzzy
matching, spelling aliases, automatic I-to-1 conversion, or assignment of block
based on demand/reservation values. A name with multiple office identities or
multiple printed membership occurrences is unresolved. All187 office rows remain
in an exclusion ledger. The analysis target is the resulting explicitly linked,
known-reservation, complete-outcome GP sample; it is not all Nadia or West Bengal.

Raw demand keys must be unique and the pre/post join must conserve all187 GP
rows. Name-only candidates are an audit output and never an analysis join.
Report exclusions and retained counts by reservation category and source block.
No imputation, winsorization, population weighting or outcome-based deletion.

## Models and inference

The two primary outcomes are FY2014–15 household-month demand and person-month
demand. For each, estimate the women's-reservation coefficient in OLS including
that same outcome in FY2012–13, block fixed effects and source2013 caste category
(SC, ST, OBC or unrestricted). The unit and weight are one GP and equal weight.
Use HC2 standard errors and95% model-based intervals, and Holm-adjust p-values
across these two outcomes within the primary specification.

Report unadjusted contrasts on the identical primary complete-case sample and
post-only block/caste-adjusted associations as secondary specifications; apply
Holm within each two-outcome family. Report the2012 baseline association with
later women's reservation as a selection/rotation diagnostic, not a causal
placebo test. All four specification families are shown regardless of sign.

Report rank, residual degrees of freedom, treatment counts, maximum leverage,
HC3 intervals and block-clustered CR2 intervals for the primary model, and
the range of leave-one-GP-out primary
coefficients. These diagnose sampling sensitivity; they do not authorize dropping
influential GPs. Do not treat a null as proof of no meaningful association.
The block-clustered CR2 sensitivity allows model-based dependence within
administrative blocks; it does not claim reservation was assigned at block level.
Report the number of blocks, blocks containing treated GPs, and coefficient-specific
degrees of freedom alongside CR2 intervals.
Do not run permutation inference without the contemporary allocation mechanism.

## Interpretation and limits

Contemporaneous reservation categories and a baseline outcome do not establish
random assignment. Rotation history, selection into linked identities, changing
boundaries, reporting and latent work demand may confound the associations.
This is neither a difference-in-differences claim nor an instrumental-variable
estimate of women's leadership. A later quota can be associated with prior
demand through the rotation rules, so baseline differences are descriptive.
Results cannot by themselves establish changes in employment, wages, works,
spending or women's political representation.

The main comparison uses household/person-month levels. No per-capita or worker
share is defined because verified population/eligible-worker denominators are
absent. FY2018–19/FY2019–20 R5 employment/personday data are outside this plan:
they cross a later election and require a separate design. Their women's-worker
counts must never be divided by household counts to construct a share.

Source definitions:
- https://raw.githubusercontent.com/in-rolls/mnrega/main/scripts/mnrega_r3.py
- https://www.indiaspend.com/wp-content/uploads/2020/08/2-Rajasthan-MGNREGS-2019-20.pdf
