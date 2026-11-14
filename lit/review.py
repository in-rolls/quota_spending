"""Review the audit proposals in lit/studies/*.yaml.

Review (browser app; writes decision/final/comment into the YAML; needs poppler's pdftotext):
    uv run --python 3.13 --with-requirements lit/requirements.txt \
        streamlit run lit/review.py --server.enableStaticServing true

Apply accepted decisions to `value` (only when the author says so):
    uv run --python 3.13 --with-requirements lit/requirements.txt python lit/review.py --apply
"""

import difflib
import html
import io
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import quote

from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import LiteralScalarString

LIT = Path(__file__).resolve().parent
STUDIES = LIT / "studies"
PAPERS = LIT / "papers"
FLAGGED = ("mismatch", "unverifiable")
DECISIONS = ("undecided", "accept", "reject", "study")

yaml = YAML()
yaml.preserve_quotes = True
yaml.width = 10**6
# Keep explicit nulls so a save changes only the fields it touches.
yaml.representer.add_representer(
    type(None), lambda r, d: r.represent_scalar("tag:yaml.org,2002:null", "null")
)


def load(key):
    return yaml.load((STUDIES / f"{key}.yaml").read_text())


def dump(key, data):
    buf = io.StringIO()
    yaml.dump(data, buf)
    (STUDIES / f"{key}.yaml").write_text(buf.getvalue())


def text(v):
    v = "" if v is None else str(v)
    return LiteralScalarString(v) if "\n" in v else v


def cells(study):
    """Yield (path, label, cell) for every cell; path locates the cell in the YAML."""
    for i, p in enumerate(study.get("preferences") or []):
        for col, c in p["codes"].items():
            row = f"{p['row']} · " if p["row"] else ""
            yield ("preferences", i, col), f"Table 1 · {row}{col}", c
    for col, c in (study.get("summary") or {}).items():
        yield ("summary", col), f"Table 2 · {col}", c


def get_cell(study, path):
    if path[0] == "preferences":
        return study["preferences"][path[1]]["codes"][path[2]]
    return study["summary"][path[1]]


def study_order():
    tables = yaml.load((LIT / "tables.yaml").read_text())
    order = [k for sec in tables["what_women_want"]["sections"] for k in sec["studies"]]
    order += [k for k in tables["literature_summary"]["studies"] if k not in order]
    return order


# ---------------------------------------------------------------- apply


def apply():
    changed = Counter()
    for key in study_order():
        study = load(key)
        touched = False
        for path, label, c in cells(study):
            if c.get("status") not in FLAGGED:
                continue
            if c.get("decision") == "accept":
                c["previous"] = c["value"]
                c["value"] = text(c.get("final", c.get("proposed", "")))
                c["status"] = "corrected"
                print(f"{key} {label}: {c['previous']!r} -> {c['value']!r}")
                changed["corrected"] += 1
                touched = True
            elif c.get("decision") == "reject":
                c["status"] = "confirmed-by-author"
                changed["confirmed-by-author"] += 1
                touched = True
        if touched:
            dump(key, study)
    print(dict(changed) or "nothing to apply")


# ---------------------------------------------------------------- PDF pages


def page_texts(pdf):
    """Text of each page, via poppler's pdftotext (more robust than pure-Python parsers
    on the malformed PDFs publishers ship)."""
    out = subprocess.run(
        ["pdftotext", str(pdf), "-"], capture_output=True, text=True, check=True
    ).stdout
    return out.split("\f")[:-1] or [out]


def norm(s):
    for a, b in {
        "\u201c": '"',
        "\u201d": '"',
        "\u2018": "'",
        "\u2019": "'",
        "\ufb00": "ff",
        "\ufb01": "fi",
        "\ufb02": "fl",
        "\ufb03": "ffi",
        "\u2013": "-",
        "\u2014": "-",
        "\u00ad": "",
    }.items():
        s = s.replace(a, b)
    # Hyphens are dropped on both sides: PDFs break "t-tests" across lines as "ttests".
    s = s.replace("-", "")
    return re.sub(r"\s+", " ", s).strip().lower()


def repair_glyphs(s):
    """Ligatures that old TeX Type 1 fonts extract as stray symbols (e.g. Ban & Rao)."""
    for a, b in {
        "\u00a2 ": "ffi",
        "\u00a2": "ffi",
        "\u00a4": "ff",
        "\u2026": "fi",
    }.items():
        s = s.replace(a, b)
    return s


def printed_numbers(texts):
    """Page numbers printed in each page's first and last three lines."""
    out = []
    for t in texts:
        lines = [ln.strip() for ln in t.splitlines() if ln.strip()]
        found = set()
        for ln in lines[:3] + lines[-3:]:
            found.update(int(n) for n in re.findall(r"(?:^|\s)(\d{1,4})(?:\s|$)", ln))
        out.append(found)
    return out


def physical_page(p, numbers, appendix):
    """Physical page printing number p; the offset that most pages agree on breaks ties,
    and an appendix citation prefers the later match (appendices restart numbering).
    Returns (page, exact)."""
    n = len(numbers)
    votes = Counter(i + 1 - k for i, ks in enumerate(numbers) for k in ks)
    offset = votes.most_common(1)[0][0] if votes else 0
    hits = [i + 1 for i, ks in enumerate(numbers) if p in ks]
    if hits:
        return (
            hits[-1] if appendix else min(hits, key=lambda h: abs(h - p - offset))
        ), True
    for guess in (p + offset, p):
        if 1 <= guess <= n:
            return guess, False
    return None, False


def pdf_index(pdf_name):
    import streamlit as st

    @st.cache_data
    def build(path, mtime):
        texts = page_texts(path)
        return printed_numbers(texts), [norm(repair_glyphs(t)) for t in texts]

    path = PAPERS / pdf_name
    return build(str(path), path.stat().st_mtime)


def cited_pages(source, numbers):
    """[(label, physical page, exact)] for every page cited in `source`."""
    out, seen = [], set()
    for clause in re.split(r";", source or ""):
        for m in re.finditer(r"pdf pp?\. ?(\d+)", clause):
            p = int(m.group(1))
            if p not in seen and 1 <= p <= len(numbers):
                out.append((f"pdf p. {p}", p, True))
                seen.add(p)
        rest = re.sub(r"pdf pp?\. ?[\d\s,\u2013-]+", "", clause)
        for m in re.finditer(r"pp?\. ?(\d+)((?:\s*[,\u2013-]\s*\d+)*)", rest):
            appendix = "appendix" in rest[: m.start()][-12:].lower()
            for p in [int(m.group(1))] + [
                int(x) for x in re.findall(r"\d+", m.group(2))
            ]:
                phys, exact = physical_page(p, numbers, appendix)
                if phys and phys not in seen:
                    out.append((f"p. {p}", phys, exact))
                    seen.add(phys)
    return out


def quotes(note):
    """Quoted passages of 25+ characters: curly pairs, then alternating straight quotes."""
    note = note or ""
    found = re.findall(r"\u201c([^\u201c\u201d]+)\u201d", note)
    found += re.sub(r"\u201c[^\u201c\u201d]*\u201d", " ", note).split('"')[1::2]
    return [q for q in found if len(q.strip()) >= 25]


def quote_hits(note, texts):
    """Page on which each quote occurs (elisions and [editorial inserts] may span text
    in between; a quote may run onto the next page), or None if not found."""
    hits = []
    for q in quotes(note):
        segs = [
            norm(x).strip(" .,;:") for x in re.split(r"\.\.\.|\u2026|\[[^\]]*\]", q)
        ]
        segs = [x[:80] for x in segs if len(x) >= 15]
        page = None
        for i, t in enumerate(texts):
            window = t + " " + (texts[i + 1] if i + 1 < len(texts) else "")
            if segs and all(x in window for x in segs):
                page = i + 1
                break
        hits.append((q, page))
    return hits


# ---------------------------------------------------------------- app

KINDS = {
    "change": "Change to the printed table",
    "fill": "Fill an empty cell in the printed table",
    "judgement": "No proposal: the auditor could not verify this; your call",
    "same": "Value unchanged: the note raises a separate point",
    "extra": "New audit field, not printed in the table",
}


def md(s):
    return re.sub(r"([\\`*_\[\]#<>$|])", r"\\\1", "" if s is None else str(s))


def link(pdf, page):
    return f"app/static/{quote(pdf)}#page={page}"


def printed_columns():
    tables = yaml.load((LIT / "tables.yaml").read_text())
    return {c["key"] for c in tables["literature_summary"]["columns"]}


def kind(path, c, printed):
    if path[0] == "summary" and path[1] not in printed:
        return "extra"
    if c.get("proposed") is None:
        return "judgement"
    if str(c.get("proposed")) == str(c.get("value") or ""):
        return "same"
    return "fill" if c.get("value") in ("", None) else "change"


def diff_html(old, new):
    """Word-level diff: deletions struck through in red, insertions in green."""
    a = re.findall(r"\S+|\s+", old or "")
    b = re.findall(r"\S+|\s+", new or "")
    out = []
    ops = difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes()
    for op, i1, i2, j1, j2 in ops:
        if op == "equal":
            out.append(html.escape("".join(a[i1:i2])))
        if op in ("delete", "replace"):
            out.append(
                "<del style='background:#fde2e2;color:#a00'>"
                + html.escape("".join(a[i1:i2]))
                + "</del>"
            )
        if op in ("insert", "replace"):
            out.append(
                "<ins style='background:#dcf5dc;color:#060;text-decoration:none'>"
                + html.escape("".join(b[j1:j2]))
                + "</ins>"
            )
    return (
        "<div style='white-space:pre-wrap;border:1px solid #ddd;padding:8px;"
        "border-radius:4px'>" + ("".join(out) or "<i>(blank)</i>") + "</div>"
    )


def app():
    import streamlit as st

    st.set_page_config(page_title="Lit table audit", layout="wide")
    order = study_order()
    studies = {k: load(k) for k in order}
    printed = printed_columns()

    flagged = [
        (k, path, label, c, kind(path, c, printed))
        for k in order
        for path, label, c in cells(studies[k])
        if c.get("status") in FLAGGED
    ]
    decided = sum(c.get("decision") in DECISIONS[1:] for *_, c, _ in flagged)

    with st.sidebar:
        st.header("Audit review")
        st.progress(
            decided / max(len(flagged), 1), f"{decided} / {len(flagged)} decided"
        )
        labels = {k: studies[k]["label"] for k in order}
        pick = st.selectbox(
            "Study", ["All"] + order, format_func=lambda k: labels.get(k, k)
        )
        table = st.radio("Table", ["Both", "Table 1", "Table 2"], horizontal=True)
        by_kind = Counter(kd for *_, kd in flagged)
        kinds = st.multiselect(
            "Show",
            list(KINDS),
            default=["change", "fill", "judgement", "same"],
            format_func=lambda kd: f"{KINDS[kd]} ({by_kind.get(kd, 0)})",
        )
        states = st.multiselect("Decision", DECISIONS, default=["undecided", "study"])
        counts = Counter(c.get("decision", "undecided") for *_, c, _ in flagged)
        st.caption(" · ".join(f"{d}: {counts.get(d, 0)}" for d in DECISIONS))

    st.markdown(
        "Each card is one cell. **Accept** replaces the current value with the text "
        "in the box (edit it first if you like); **Reject** keeps the current value. "
        "Nothing reaches the tables until the accepted decisions are applied."
    )

    for key in order if pick == "All" else [pick]:
        s = studies[key]
        rows = [
            (path, label, c, kd)
            for k, path, label, c, kd in flagged
            if k == key
            and (table == "Both" or label.startswith(table))
            and kd in kinds
            and c.get("decision", "undecided") in states
        ]
        if not rows and pick == "All":
            continue
        st.header(s["label"])
        pdf = s.get("pdf")
        st.caption(
            f"{key} · PDF: {pdf or 'none'} · {s.get('pdf_version') or ''}"
            + (
                f" · Table 2 label: {s['table2_label']}"
                if s.get("table2_label")
                else ""
            )
        )
        if pdf and (PAPERS / pdf).exists():
            numbers, texts = pdf_index(pdf)
            st.link_button("Open paper", link(pdf, 1))
        else:
            numbers, texts = [], []
            st.warning("No PDF in lit/papers — cells cannot be checked here.")
        if s.get("audit_notes"):
            with st.expander("Auditor's study-level notes"):
                st.markdown(md(s["audit_notes"]).replace("\n", "  \n"))
        with st.form(f"study-{key}"):
            comment = st.text_area(
                "Study-level comment (structural decisions, e.g. which version the row describes)",
                s.get("review_comment") or "",
                height=68,
            )
            if st.form_submit_button("Save study comment"):
                fresh = load(key)
                fresh["review_comment"] = text(comment) if comment.strip() else None
                dump(key, fresh)
                st.rerun()

        for path, label, c, kd in rows:
            cid = f"{key}-{'-'.join(map(str, path))}"
            with st.container(border=True):
                st.subheader(label)
                st.caption(KINDS[kd].upper())
                why = re.split(
                    r"(?<=[.!?])\s", (c.get("note") or "").strip(), maxsplit=1
                )[0]
                st.markdown(f"**Why:** {md(why[:400])}")
                if kd == "judgement":
                    st.markdown("**Current value**")
                    st.text(c.get("value") or "(blank)")
                else:
                    st.markdown("**Proposed change** (red = removed, green = added)")
                    st.markdown(
                        diff_html(str(c.get("value") or ""), str(c.get("proposed"))),
                        unsafe_allow_html=True,
                    )
                st.markdown(f"**Source:** {md(c.get('source'))}")
                pages = cited_pages(c.get("source"), numbers) if texts else []
                if pages:
                    cols = st.columns(min(len(pages), 8))
                    for i, (lab, phys, exact) in enumerate(pages):
                        arrow = "→" if exact else "≈"
                        cols[i % len(cols)].link_button(
                            f"{lab} {arrow} pdf {phys}", link(pdf, phys)
                        )
                for q, page in quote_hits(c.get("note"), texts) if any(texts) else []:
                    short = md(q[:70]) + ("…" if len(q) > 70 else "")
                    if page:
                        st.markdown(f"✅ quote found on pdf p. {page}: “{short}”")
                    else:
                        st.markdown(f"⚠️ quote not found in PDF text: “{short}”")
                with st.expander("Full evidence"):
                    st.markdown(md(c.get("note")).replace("\n", "  \n"))

                with st.form(cid):
                    current = c.get("decision", "undecided")
                    options = {
                        "undecided": "Undecided",
                        "accept": "Accept: use the text below",
                        "reject": "Reject: keep the current value",
                        "study": "Study further",
                    }
                    decision = st.radio(
                        "Decision",
                        DECISIONS,
                        index=DECISIONS.index(current),
                        format_func=options.get,
                        horizontal=True,
                    )
                    final = st.text_area(
                        "Text to apply if accepted (edit freely)",
                        c.get("final", c.get("proposed")) or "",
                    )
                    note = st.text_area("Comment", c.get("comment") or "", height=68)
                    if st.form_submit_button("Save"):
                        fresh = load(key)
                        cell = get_cell(fresh, path)
                        for k in ("decision", "final", "comment"):
                            cell.pop(k, None)
                        if decision != "undecided":
                            cell["decision"] = decision
                        if decision == "accept":
                            cell["final"] = text(final)
                        if note.strip():
                            cell["comment"] = text(note)
                        dump(key, fresh)
                        st.rerun()


if "--apply" in sys.argv:
    apply()
else:
    app()
