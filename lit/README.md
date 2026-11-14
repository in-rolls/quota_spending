# Literature tables

Source for the SI tables "Summary of Studies on Reservation and Outcomes" and "What Women Want".

- `studies/<bibkey>.yaml` — one file per study; this is the source of truth. Edit content here.
- `tables.yaml` — captions, columns, study order, section headings and table notes.
- `quota_tables.bib` — references for the studies.
- `Literature_Review_Quotas_Allocation.docx` — the original Word review the YAML was imported from. Frozen; edits to it do not reach the tables.
- `papers/` — PDFs of the cited studies, git-ignored (third-party copyright).

Each cell records its audit trail:

```yaml
value: F            # what the table prints
status: confirmed   # unchecked | confirmed | mismatch | unverifiable | corrected | confirmed-by-author
source: p. 1421, Table 2
note: why the value holds, with a quote for mismatches
proposed: M         # auditor's suggestion, on mismatches
decision: accept    # author's call: accept | reject | study
final: NS           # what to apply on accept (the proposal, as edited by the author)
comment: free text
previous: F         # the value before an accepted change was applied
```

## Reviewing proposals

```bash
uv run --python 3.13 --with-requirements lit/requirements.txt \
    streamlit run lit/review.py --server.enableStaticServing true
```

The app lists every `mismatch`/`unverifiable` cell with the evidence, a button per cited page that opens the PDF at that page, and a check of whether each quoted passage actually occurs in the PDF. Accept (optionally editing the value), reject or mark for further study; saving writes `decision`/`final`/`comment` into the study's YAML and changes nothing else. It needs poppler's `pdftotext` and a `lit/static` symlink to `papers/` (git-ignored): `ln -s papers lit/static`.

Decisions take effect only when applied:

```bash
uv run --python 3.13 --with-requirements lit/requirements.txt python lit/review.py --apply
Rscript scripts/lit_tables.R
```

Render with `Rscript scripts/lit_tables.R`, which writes `tabs/01_table_what_women_want.tex` and `tabs/02_table_literature_summary.tex`. The script only typesets; it changes no content.

The review environment is tested with Python 3.13. `lit/requirements.in` declares its
Python dependencies, and `lit/requirements.txt` pins the resolved environment.
Regenerate the pins with
`uv pip compile --python-version 3.13 lit/requirements.in -o lit/requirements.txt`.
