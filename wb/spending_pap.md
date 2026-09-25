# Women's Pradhan reservation and MNREGA works spending in West Bengal

This plan was written after the spending panel was built and validated, and
before any spending outcome was compared by reservation status. At the time of
writing, the authors had seen:
- the statewide r6 and r3 series by fiscal year (`tabs/spending_validation.csv`)
- the distribution of GP spending by district-term, pooled over reservation status
- the design counts in "Sample" below, which use treatment only

No coefficient or outcome contrast by reservation had been computed. This is an
exploratory, unregistered analysis. The specification below is reported whatever
its sign or significance.

**Question.** Does reserving a gram panchayat's Pradhan office for a woman change
the MNREGA works expenditure the GP incurs during that elected term?

## Sources, units and timing

**Treatment.** The treatment is the women's reservation of the Pradhan office,
taken from `local_elections` `data/wb/derived/pradhan_gp/pradhan_gp.csv`, pinned
by SHA-256 in `spending_source_manifest.csv`.
- Six district-terms: South 24 Parganas, Nadia, Purulia and Alipurduar for the
  2018 term; Malda and Nadia for the 2013 term.
- In each district-term, the parsed counts equal the totals printed in the
  District Magistrate's Form 1B order.
- Offices the order does not name are unreserved on both axes.
- The blank Nadia 2013 handbook code (Taldaha Majdia) is resolved differently
  from `nadia_pap.md`, where it stayed unknown. Here it is coded unreserved,
  because the other 186 codes already use up every printed total. It is kept in
  the sample.

**Outcome.** The outcome is MNREGA r6 works expenditure, completed plus ongoing,
in lakh rupees per GP and fiscal year.
- It is extracted from doi:10.7910/DVN/ZHF9WC and parsed by
  `scripts/00_mnrega.R`, the same parser the UP and Rajasthan analyses use.
- r6 file year Y is fiscal year Y–(Y+1).
- r6 reports each fiscal year's works with their status at the time of the
  scrape. Completed plus ongoing is used because the split between them depends
  on scrape timing.

**Validation.** Before this plan was written, r6 was checked against r3
employment:
- The rank correlation across GPs is 0.70–0.90 in every year.
- Both series jump in FY2020–21 and collapse in FY2022–23, when central funds
  stopped.

**Terms and fiscal years.** Each term is linked to the fiscal years it governs:
- 2013 term: FY2013–14 to FY2017–18
- 2018 term: FY2018–19 to FY2021–22. FY2022–23 is excluded because of the
  funding freeze.

**Outcomes per GP-term.**
- `spend`: mean annual expenditure over the term's fiscal years in which the GP
  appears in r6.
- `log_spend`: log(1 + spend).
- The mean, rather than the total, makes five-year and four-year terms
  comparable.
- A fiscal year missing from r6 is not treated as zero. Haringhata-I and -II
  (Nadia) are absent from FY2016–17, so they have three of five years.

## Sample

The sample has 1,064 GP-terms in 88 blocks:

| District | Term | GPs | Women-reserved |
|---|---|---:|---:|
| South 24 Parganas | 2018 | 310 | 155 |
| Nadia | 2018 | 185 | 92 |
| Purulia | 2018 | 170 | 85 |
| Alipurduar | 2018 | 66 | 33 |
| Nadia | 2013 | 187 | 93 |
| Malda | 2013 | 146 | 73 |

Support:
- Every caste-quota × district-term cell contains both women-reserved and other
  GPs. The smallest is South 24 Parganas ST: 4 GPs, 1 reserved.
- The smallest block-term cell has 4 GPs.
- 178 Nadia GPs link across both terms by MNREGA name. Their women's reservation
  in 2013 and 2018 is close to independent: 45 GPs in neither term, 44 in 2013
  only, 45 in 2018 only, 44 in both.

## Assignment, and what it justifies

Under Rule 2A of the WB Panchayat (Constitution) Rules 1975, each District
Magistrate serially numbers the district's GPs (ordered by assembly
constituency) and reserves offices by a statutory roster over those numbers.
Women's reservations are drawn first from within the SC and ST reserved
offices.

So women's reservation is not random. The design assumes it is unrelated to
potential spending **within caste-quota × district-term cells and within
blocks**. The serial order follows geography, and block fixed effects absorb
geography at the block level. What remains is roster position within a block.
This assumption is argued, not tested.

## Models and inference

**Primary: all six district-terms, one row per GP-term.**
`y = β·women + FE(caste quota × district-term) + FE(block × term)`

- There are two primary outcomes, `spend` and `log_spend`.
- Each GP-term has equal weight.
- Standard errors are CR2 clustered by block (88 clusters), via `wb_estimate`.
- Report 95% intervals, and Holm-adjust across the two primary outcomes.
- Report the number of clusters, the number of treated clusters, and the
  treated/untreated GP counts.

**Within-GP: Nadia, the 178 GPs observed in both terms.**
`y = β·women + FE(GP) + FE(caste quota × term) + FE(block × term)`

- β is identified from the 89 GPs whose status changes between terms.
- CR2 standard errors clustered by block, with the number of blocks reported.
- This is a secondary specification. It does not replace the primary.

**Secondary outcomes** (exploratory; Holm within this family of five), using the
primary specification with mean annual expenditure on:
- connectivity
- water: water conservation, traditional water bodies, drinking water, micro
  irrigation, flood control, drought proofing
- works on individual land
- sanitation and childcare
- the number of works

**Sensitivity** (primary outcomes, reported in full):
- HC2 instead of CR2
- excluding GP-terms with an incomplete window (Haringhata-I and -II)
- each district-term estimated separately
- 2018 term only
- excluding Alipurduar, whose tea-garden GPs have unusually high spending

These do not replace the primary estimate. No influential-observation
deletion, winsorising or outcome-based trimming.

**Diagnostic.** For the four 2018 districts, estimate the primary model with
mean FY2014–17 spending (the previous term) as the outcome.
- A reservation that is unrelated to potential spending should show no
  association.
- This is not a clean placebo. If 2013 reservation affected spending and the
  roster links 2013 and 2018 reservations, a nonzero diagnostic is possible
  even under the assumption. Report it as a diagnostic.

**Power.** Report the minimum detectable effect at 80% power, and Type S/M
errors, from `wb_power` for the primary estimate.

## Interpretation and limits

- The estimand is the effect of the reservation, not of a woman Pradhan. Winner
  sex is not observed.
- r6 records expenditure on works attributed to a GP. It is not labour
  person-days or wages, and not the GP's own discretionary budget.
- The six district-terms were chosen because their Form 1B orders survive
  online, not by design. Results describe these districts.
- The 2008 term is absent, pending RTI (right to information) requests.
- A null result is not evidence of no effect. Report intervals and the minimum
  detectable effect.

## Deviations

Any change after the freeze is added below as a dated amendment, saying whether
outcomes had been seen. The frozen text stays in `spending_plan_freeze.json`
by hash.
