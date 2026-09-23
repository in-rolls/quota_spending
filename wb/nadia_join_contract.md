# Nadia identity, row-unit and outcome contract

`nadia_demand_source_panel` contains 187 GP rows from two raw administrative
report years. Its key is normalized district + block + Panchayat name. Two
annual measures occupy separate columns, so this is a wide GP table, not 374
independent observations. Original demand names are retained. Each annual
measure sums twelve monthly counts without skipping missing values.

`nadia_demand_join_audit` retains all 187 source Pradhan office rows keyed by
`row_id`, with source GP serial, original reservation code, PDF hash/page/bbox,
raw names and explicit eligibility flags. The head/deputy pair is not the unit
of this model. The one source-blank head category remains unknown. Only this
complete office synopsis permits coding women reservation as zero for explicit
non-women categories; positive-list nonappearance never supplies a zero.

The membership bridge is printed in the same 2013 handbook, PDF pages 71–74.
Matching removes case and non-alphanumeric separators only. Roman numerals and
Arabic numerals remain distinct. The office name must be unique in the office
roster and its membership name must have one printed occurrence. Repeated
membership text is not silently deduplicated. The bridge supplies block; demand
is then matched by district + block + GP in both years. There is no fuzzy join,
spelling alias, name-only demand join, or use of quota/outcome values to resolve
identity. The nine membership matches gained by separator normalization are
exported separately, six of which enter the analysis.

The path is 187 offices → 161 unambiguous membership matches → 101 matched
complete demand records → 100 model records. Six source office rows have
nonunique names, 20 have absent/nonunique membership, and 60 lack an exact
block/GP demand match. The final excluded record is Gobindapur, the sole linked
ST-category GP. Its category dummy gives leverage one in the planned model.
The outcome-blind support amendment excludes this singleton category from all
same-sample comparisons; the original 101 linked cases remain in the audit.
It changes the target population and is not an innocuous relabeling of ST.

Source hashes pin both parsed inputs and original handbook. Raw demand subsets
and the analysis plan are pinned in `nadia_source_manifest.csv`. The original
2012 national archive is retained in quota's Git objects even though its working
file is deleted; extraction reads that object without restoring user deletions.
`data/nadia_raw/extraction_provenance.json` records full-archive hashes, commit
and blob identifiers, subset hashes and extraction predicates. The 2014 source
is already on disk. Historical financial year is not the archive collection date.

Exact geographic names and source-supported blocks are inspectable links, not
proof that administrative boundaries stayed fixed. National GP codes and dated
boundary histories are not established by this join. The reported associations
are conditional on the selected links; standard errors do not propagate linkage
uncertainty or identify a reservation lottery. No statewide inference is made.
