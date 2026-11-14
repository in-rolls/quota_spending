# Coding brief: mechanisms, normative claims, measurement, estimates

This brief is for coders filling one file per study, `lit/coding/<key>.yaml`, for the literature-review note. Do not edit `lit/studies/*.yaml`. Those hold the author's own codes and stay as they are.

## Why we are coding these
The note reports:
1. what each paper says is the mechanism, meaning why women leaders do or don't change outcomes, and how that claim changes between its versions;
2. what normative case, if any, the paper makes for or against quotas;
3. how the paper measures what women and men want, and how it measures outcomes, which we use to draw a timeline of measurement;
4. its estimates, for a meta-analysis.

Every claim must carry a **verbatim quote** and the **printed page** of the version it comes from. If you can't find support for a field, write `null` and say so in `note`. Do not infer.

## Sources
- The study's own audit file `lit/studies/<key>.yaml` gives the `pdf:` field and the author's codes. Use it for context only.
- PDFs are in `lit/papers/`. Use **every version** we hold, matching on surname and year. For example, Gajwani & Zhang has `gajwani_zhang_2008_ifpri_dp807.pdf`, `_2014_wb_wps6854.pdf` and `_2015_wber.pdf`.
- `lit/version_diffs/<name>.md` already documents what changed between versions for nine papers. Read it first when it exists.
- Two PDFs are image scans. Their OCR text, one file per page (`p-NN.txt`, NN = pdf page), is under `/private/tmp/claude-501/-Users-soodoku-Documents-GitHub-in-rolls-quota-spending/ea638557-6e3b-4ac4-a867-7fc0a23f057a/scratchpad/ocr/`:
  - `ban_rao_2008_edcc/`: printed page = pdf page + 500.
  - `deininger_jin_nagarajan_singh_2022_jds/`: printed page = pdf page + 1771.
- Extract text with `pdftotext -layout -f N -l N file.pdf -`. Work out the printed-page offset from the running heads and record it.

## Output: `lit/coding/<key>.yaml`

```yaml
key: <key>
versions:                       # every version we hold, oldest first
  - id: wp2008                  # short id you choose; referenced below
    file: gajwani_zhang_2008_ifpri_dp807.pdf
    citation: "IFPRI DP 807, Oct 2008"
    year: 2008
    page_offset: "printed = pdf - 7"
meta:
  year_first: 2008              # first public version we can document
  year_published: 2015          # null if never published
  setting: "Tamil Nadu, 144 GPs, 2005 survey"
  design: "random/rotational reservation, cross-section | DID | RD | panel | other"

mechanism:                      # one entry per distinct claim per version
  - version: wp2008
    claim: "One sentence in plain words: why outcomes do/don't differ under women leaders."
    type: proxy_husband         # preferences | identity_caste | knowledge_capacity | contact_networks |
                                # proxy_husband | patriarchy_backlash | discretion_institutions |
                                # voice_demand | corruption_rents | experience_learning | selection_who_runs | other
    status: tested              # tested (the paper estimates it) | asserted (stated, not tested) | speculated (offered as one possibility)
    direction: explains_null    # explains_effect | explains_null | explains_negative
    quote: "verbatim"
    page: "18"
    note: ""

normative:                      # the paper's own case for or against quotas, if any
  - version: wbr2015
    claim: "One sentence."
    stance: conditional         # pro_quota | conditional (pro if X, e.g. training) | skeptical | none_stated
    quote: "verbatim"
    page: "257"
# If the paper makes no normative claim: normative: [{version: ..., stance: none_stated, claim: null, quote: null, page: null}]

measurement:
  preferences:                  # how the paper learns what women/men want (null if it doesn't)
    method: hh_survey_rank      # complaints_requests | meeting_talk_share | pra_focus_group | hh_survey_rank |
                                # allocation_question | wtp_game | usage_behavior | assumed_from_literature | none
    unit_of_gap: individual     # where the men-women gap is estimated: individual | village | gp | district | state | national
    gap_assumption: constant    # constant (one gap applies everywhere) | varies_by_place (district/village-specific) |
                                # varies_by_group (e.g., religion, caste) | not_applicable
    tested_gap: yes             # yes (a significance test of men vs women) | no (descriptive only) | not_applicable
    quote: "verbatim describing the measure"
    page: ""
  outcomes:
    source: villager_survey     # villager_survey | own_audit_or_pra | gp_staff_or_records | admin_mis | census_or_shrug | other
    units: "GP-level counts of facilities built/repaired"
    n_units: 144                # number of independently assigned units (GPs, or villages if that's the assignment unit)
    assignment_unit: gp
    quote: "verbatim"
    page: ""

estimates:                      # main estimates of the effect of women's reservation (provision) and of preference gaps
  - version: wbr2015
    estimand: provision         # provision (effect of reservation/female leader) | pref_gap (women minus men preference)
    outcome: "number of schools"
    outcome_family: schools     # drinking_water | roads | schools | sanitation | health | irrigation | electricity |
                                # transport | housing | mnrega_jobcards | mnrega_demand | mnrega_women_days |
                                # total_spending | public_works_other | child_outcomes | participation | other
    diff: -0.693                # coefficient on reservation/female, in outcome units (for pref_gap: women - men)
    se: 0.187
    se_source: reported         # reported | from_t (se = |diff/t|) | from_ci | computed (from shares and n) | stars_only
    p_or_stars: "***"
    control_mean: null          # mean of the outcome in unreserved/male-led units, if reported
    control_sd: null
    n_units: 144
    n_obs: 286
    adjusted: false             # false = raw difference / basic DID; true = with covariates
    table: "Table 7"
    page: "251"
    preferred: true             # the paper's headline specification for this outcome
    note: ""
```

## Rules
- **Quote word for word.** Never paraphrase into `quote`. Keep each quote to about 60 words or fewer.
- **Mechanism.** Code every distinct mechanism the paper offers, in every version. Mark it `tested` only if the paper estimates something about it, such as a knowledge test, a contact measure or an interaction. When the mechanism changes between versions, the change goes in the record. Gajwani & Zhang is the model case: husbands in 2008, knowledge and contact in 2015.
- **Normative.** Record only claims the authors themselves make about quota policy, such as "supports reservation", "training needed" or "lengthen reservation terms". Do not count summaries of other people's views.
- **Estimates.**
  - Prefer the paper's headline table. Take at most about 8 estimates per paper: one per outcome family, choosing the preferred specification.
  - Record pref_gap estimates only when the paper reports men's and women's numbers or their difference.
  - If only stars are reported, use `se_source: stars_only` and `se: null`.
  - Record signs exactly as printed. Beware PDF text extraction that renders a minus sign as "2" (WBER) or drops it (OCR).
- **Pages.** Give printed page numbers. If the version has no printed pages, use `pdf p. N`.
- **Scope.** If a study's design means a block does not apply (e.g. Bhalotra & Clots-Figueras studies state legislators), still fill it and explain in `note`.
- When done, also return a 5-line summary per study: its mechanisms with types, its normative stance, its preference method and gap assumption, how many estimates you extracted, and any problems.
