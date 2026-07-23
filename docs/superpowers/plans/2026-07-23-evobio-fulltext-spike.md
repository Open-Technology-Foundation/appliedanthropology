# Evolutionary-Biology Full-Text Spike — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. This is a
> data-pipeline spike: "tests" are concrete run/expect verifications, not unit tests.

**Goal:** Prove (or disprove) that modern full-text human-behavioural
evolutionary-biology articles, filtered to their narrative sections, retrieve as
coherent on-topic prose in this KB's bge-m3 + reranker stack — in an isolated
throwaway KB that never touches production.

**Architecture:** Fetch ~40 PMC Open-Access JATS-XML articles via NCBI E-utilities
→ extract Abstract/Intro/Discussion/Conclusion prose to plain `.md` → build a
standalone `evobio-spike` customkb KB mirroring production's embedding/reranker
config → run retrieval probes and judge against measurable criteria.

**Tech Stack:** bash + `curl` + `jq` + `xmllint` (fetch); Python 3 stdlib
`xml.etree` (extract); `customkb` (build/query); bge-m3 + bge-reranker-v2-m3.

## Global Constraints

- Spike dir: `/var/lib/vectordbs/evobio-spike/` — a **sibling** KB, deliberately
  outside `appliedanthropology/` and outside `workshops/` (so the AA importer's
  `find` sweep never picks it up).
- **Never** run `customkb database/embed/bm25` against `appliedanthropology.cfg`
  or `seculardharma.cfg`. Only ever against `evobio-spike.cfg`.
- Config is derived from the **live `appliedanthropology.cfg`**, not the docs
  (CLAUDE.md flags stale OpenAI/GPT-4o values in `long_desc`).
- Copyright is non-gating (private system); no `hf-rights.tsv` rows this pass.
- **Commits deferred** — user commits when the spike is complete. No per-task
  commits. `.sh` files still get `shellcheck` + `bash -n` before "done".
- Topical scope: human-behavioural core only (cooperation, morality, social
  behaviour, primatology, human evolution, behavioural ecology).

---

### Task 1: Scaffold + config + backend pre-check

**Files:**
- Create: `/var/lib/vectordbs/evobio-spike/` (dir), `evobio-spike.cfg`
- Read: `/var/lib/vectordbs/appliedanthropology/appliedanthropology.cfg`

**Interfaces:**
- Produces: `evobio-spike.cfg` at repo-standard location with `vector_model`,
  `vector_dimensions`, reranker, `db_min_tokens=300`, `db_max_tokens=500`,
  `bm25_enabled=true` copied verbatim from the live AA cfg; paths pointed at the
  spike dir.

- [ ] **Step 1: Verify toolchain present**

Run: `command -v curl jq xmllint python3 customkb`
Expected: a path printed for each. If `jq`/`xmllint` missing, install
`jq`/`libxml2-utils` before proceeding.

- [ ] **Step 2: Read the live AA cfg and capture the embedding/reranker block**

Run: `sed -n '1,60p' /var/lib/vectordbs/appliedanthropology/appliedanthropology.cfg`
Expected: see the real `vector_model` / `vector_dimensions` / reranker /
`db_min_tokens` values to copy. (bge-m3, 1024-dim per CLAUDE.md — but the cfg is
authoritative.)

- [ ] **Step 3: Create the spike dir and cfg**

```bash
mkdir -p /var/lib/vectordbs/evobio-spike/{raw,text}
```

Write `evobio-spike.cfg` as a copy of the AA cfg with: the KB name/description
changed to `evobio-spike`, any absolute AA paths repointed to the spike dir, and
the embedding/reranker/segmenter values left identical. Keep `[DEFAULT]`,
`[API]`, `[LIMITS]`, `[PERFORMANCE]`, `[ALGORITHMS]` sections intact.

- [ ] **Step 4: Embedding-backend smoke test (spike blocker check)**

Run: `customkb --help` then confirm from the cfg whether `vector_model` is a
local model (bge-m3 via sentence-transformers) or an API. If local, confirm the
model is resolvable (HF cache under `/ai` or `~/.cache/huggingface`, or a GPU is
present). Expected: a clear yes/no on "can this environment run `customkb embed`".
If **no**, record it: the spike still delivers fetched+extracted prose and a
manual retrieval inspection, and the build/eval steps get run where the model
lives (okusi3). Do not fake a pass.

---

### Task 2: Fetch (`fetch.sh`)

**Files:**
- Create: `/var/lib/vectordbs/evobio-spike/fetch.sh`
- Output: `/var/lib/vectordbs/evobio-spike/raw/PMC<id>.xml` (~40 files)

**Interfaces:**
- Produces: well-formed JATS XML files named `PMC<uid>.xml` under `raw/`.

- [ ] **Step 1: Write `fetch.sh`**

```bash
#!/bin/bash
# fetch.sh — pull OA full-text JATS XML from PMC for the evobio spike
set -euo pipefail
shopt -s inherit_errexit

declare -r EUTILS='https://eutils.ncbi.nlm.nih.gov/entrez/eutils'
declare -r SELF_DIR=${0%/*}
declare -r RAWDIR="$SELF_DIR/raw"
declare -ri RETMAX=60
declare -r QUERY='("human cooperation"[tiab] OR "reciprocal altruism"[tiab] OR "primate social"[tiab] OR "human evolution"[tiab] OR "behavioral ecology"[tiab] OR "evolution of morality"[tiab] OR "cooperative breeding"[tiab]) AND "open access"[filter] AND "fulltext"[filter]'

warn() { >&2 printf 'fetch.sh: %s\n' "$*"; }

mkdir -p "$RAWDIR"

declare -a ids=()
mapfile -t ids < <(
  curl -sG "$EUTILS/esearch.fcgi" \
    --data-urlencode 'db=pmc' \
    --data-urlencode "term=$QUERY" \
    --data-urlencode "retmax=$RETMAX" \
    --data-urlencode 'retmode=json' \
  | jq -r '.esearchresult.idlist[]?'
)
(( ${#ids[@]} )) || { warn 'no ids returned'; exit 1; }
warn "${#ids[@]} PMC ids"

declare -i ok=0 fail=0
declare -- id out
for id in "${ids[@]}"; do
  out="$RAWDIR/PMC$id.xml"
  if [[ -s $out ]] && xmllint --noout "$out" 2>/dev/null; then
    ok+=1; continue
  fi
  if curl -s "$EUTILS/efetch.fcgi?db=pmc&id=$id&rettype=full&retmode=xml" -o "$out" \
     && xmllint --noout "$out" 2>/dev/null; then
    ok+=1
  else
    fail+=1; warn "fetch/parse failed for PMC$id"; rm -f "$out"
  fi
  sleep 0.4
done
warn "fetched=$ok failed=$fail into $RAWDIR"
#fin
```

- [ ] **Step 2: Lint**

Run: `bash -n fetch.sh && shellcheck fetch.sh`
Expected: no syntax errors; shellcheck clean (0 notes).

- [ ] **Step 3: Run the fetch**

Run: `cd /var/lib/vectordbs/evobio-spike && ./fetch.sh`
Expected: stderr reports `N PMC ids` then `fetched=~40 failed=<small>`.

- [ ] **Step 4: Verify the harvest**

Run: `ls raw/*.xml | wc -l` and
`for f in raw/*.xml; do xmllint --xpath 'count(//body)' "$f" 2>/dev/null; echo " $f"; done | sort | uniq -c | head`
Expected: ~40 files; most with a `//body` count of 1 (full text present, not just
front matter). Files lacking `<body>` are metadata-only and get dropped in Task 3.

---

### Task 3: Extract narrative sections (`extract.py`)

**Files:**
- Create: `/var/lib/vectordbs/evobio-spike/extract.py`
- Output: `/var/lib/vectordbs/evobio-spike/text/PMC<id>-<slug>.md`

**Interfaces:**
- Consumes: `raw/*.xml` from Task 2.
- Produces: one `.md` per article with ≥400 words of narrative prose + a
  provenance header. Articles below the word floor are skipped and logged.

- [ ] **Step 1: Write `extract.py`**

```python
#!/usr/bin/env python3
"""Extract narrative-section prose (Abstract/Intro/Discussion/Conclusion) from
PMC JATS XML into staging-ready .md for the evobio spike. Drops Methods, Results,
tables, figures, reference lists; strips inline citation xrefs (keeps their tails).
"""
import re
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW, OUT = HERE / 'raw', HERE / 'text'
MIN_WORDS = 400

KEEP_SECTYPE = ('intro', 'background', 'discussion', 'conclusion')
KEEP_TITLE = re.compile(r'\b(introduction|background|discussion|conclusion|conclusions|general discussion)\b', re.I)
DROP_BLOCK = {'table-wrap', 'fig', 'ref-list', 'table', 'disp-formula', 'graphic', 'supplementary-material'}
DROP_INLINE = {'xref', 'inline-formula', 'label'}


def norm(s):
  s = re.sub(r'\s+', ' ', s or '').strip()
  s = re.sub(r'[\(\[]\s*[\);\],]*\s*[\)\]]', '', s)   # empty () [] left by dropped xrefs
  s = re.sub(r'\s+([,.;:])', r'\1', s)
  return s


def text_of(el):
  if el.tag in DROP_INLINE:
    return ''
  parts = [el.text or '']
  for c in el:
    parts.append(text_of(c))
    parts.append(c.tail or '')
  return ''.join(parts)


def prune_block(root):
  parents = {c: p for p in root.iter() for c in p}
  for el in list(root.iter()):
    if el.tag in DROP_BLOCK:
      p = parents.get(el)
      if p is not None and el in list(p):
        p.remove(el)


def slug(s):
  s = re.sub(r'[^A-Za-z0-9]+', '-', (s or '').lower())
  return re.sub(r'-+', '-', s).strip('-')[:60] or 'x'


def first_text(root, path):
  el = root.find(path)
  return norm(text_of(el)) if el is not None else ''


def section_blocks(body):
  blocks = []
  for sec in body.findall('sec'):
    st = (sec.get('sec-type') or '').lower()
    title_el = sec.find('title')
    tt = norm(text_of(title_el)) if title_el is not None else ''
    if not (any(k in st for k in KEEP_SECTYPE) or KEEP_TITLE.search(tt)):
      continue
    if title_el is not None and title_el in list(sec):
      sec.remove(title_el)
    paras = [norm(text_of(p)) for p in sec.iter('p')]
    paras = [p for p in paras if len(p) > 1]
    if paras:
      blocks.append((tt or 'Section', '\n\n'.join(paras)))
  return blocks


def extract(path):
  root = ET.parse(path).getroot()
  art = root.find('.//article') if root.tag != 'article' else root
  if art is None:
    return None
  prune_block(art)
  title = first_text(art, './/article-meta//article-title') or first_text(art, './/article-title')
  journal = first_text(art, './/journal-title')
  year = first_text(art, './/article-meta//pub-date/year') or first_text(art, './/pub-date/year')
  pmcid = first_text(art, './/article-id[@pub-id-type="pmc"]') or path.stem.replace('PMC', '')
  abstract_el = art.find('.//article-meta//abstract') or art.find('.//abstract')
  blocks = []
  if abstract_el is not None:
    ab = norm(text_of(abstract_el))
    if ab:
      blocks.append(('Abstract', ab))
  body = art.find('.//body')
  if body is not None:
    blocks.extend(section_blocks(body))
  words = sum(len(b.split()) for _, b in blocks)
  if words < MIN_WORDS or not title:
    return {'skip': True, 'pmcid': pmcid, 'words': words, 'title': title}
  header = (f'# {title}\n\n'
            f'- Journal: {journal} ({year})\n'
            f'- PMCID: PMC{pmcid}\n'
            f'- Source: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC{pmcid}/\n'
            f'- License: PMC Open Access\n'
            f'- Ingested: evobio-spike (narrative sections only)\n')
  body_md = '\n\n'.join(f'## {h}\n\n{t}' for h, t in blocks)
  fname = f'PMC{pmcid}-{slug(title)}.md'
  (OUT / fname).write_text(header + '\n' + body_md + '\n', encoding='utf-8')
  return {'skip': False, 'file': fname, 'words': words}


def main():
  OUT.mkdir(exist_ok=True)
  kept = skipped = 0
  for path in sorted(RAW.glob('*.xml')):
    try:
      r = extract(path)
    except ET.ParseError as e:
      print(f'  ! parse error {path.name}: {e}')
      continue
    if r is None or r.get('skip'):
      skipped += 1
      w = r.get('words', 0) if r else 0
      print(f'  - skip {path.name} ({w} words)')
    else:
      kept += 1
      print(f"  ok {r['file']} ({r['words']} words)")
  print(f'\nkept={kept} skipped={skipped} -> {OUT}')


if __name__ == '__main__':
  main()
#fin
```

- [ ] **Step 2: Run the extractor**

Run: `cd /var/lib/vectordbs/evobio-spike && python3 extract.py`
Expected: per-file `ok`/`skip` lines, then `kept=~30 skipped=<rest>`. At least
~20 kept files is enough signal for the spike; if far fewer, loosen the section
matcher or lower `MIN_WORDS` and re-run.

- [ ] **Step 3: Eyeball one extracted file for noise**

Run: `sed -n '1,40p' text/$(ls text | head -1)`
Expected: clean provenance header + readable Abstract/Introduction prose — **no**
`[1,2]`-style citation clutter, no table/figure debris, no methods/stats. If
methods or citation residue leaked in, note it and tighten before the build.

---

### Task 4: Build the isolated mini-KB

**Files:**
- Uses: `evobio-spike.cfg`, `text/*.md`
- Output: `evobio-spike.db`, `.faiss`, `.bm25*` in the spike dir

**Interfaces:**
- Consumes: `text/*.md` from Task 3, `evobio-spike.cfg` from Task 1.
- Produces: a queryable standalone KB.

- [ ] **Step 1: Import text → db**

Run: `cd /var/lib/vectordbs/evobio-spike && customkb database evobio-spike.cfg text/*.md`
Expected: reports rows/segments created (hundreds of segments across ~20–30
files). Confirm: `sqlite3 evobio-spike.db "SELECT COUNT(*) FROM docs;"` > 0.

- [ ] **Step 2: Embed**

Run: `customkb embed evobio-spike.cfg`
Expected: embeddings generated for all segments (bge-m3). Confirm:
`sqlite3 evobio-spike.db "SELECT COUNT(embedding) FROM docs;"` equals the segment
count. If the backend pre-check (Task 1 Step 4) said "no", stop here and hand the
built `text/` + cfg to an environment that can embed; record it plainly.

- [ ] **Step 3: BM25 index**

Run: `customkb bm25 evobio-spike.cfg`
Expected: BM25 index built over all rows (hybrid search parity with production).

---

### Task 5: Evaluate + verdict

**Files:**
- Create: `/var/lib/vectordbs/evobio-spike/EVAL.md`

**Interfaces:**
- Consumes: the built KB from Task 4.
- Produces: probe outputs + a PASS/MARGINAL/FAIL verdict against the spec's
  success criteria.

- [ ] **Step 1: Run retrieval probes (context-only)**

```bash
cd /var/lib/vectordbs/evobio-spike
for q in \
  "reciprocal altruism and the evolution of human fairness" \
  "primate coalition formation and egalitarian social structure" \
  "costly signalling and the evolution of moral behaviour" \
  "alloparenting and cooperative breeding in human evolution" \
  "punishment and the enforcement of social norms in small-scale societies" \
  "the evolution of empathy and prosocial emotion"; do
  echo "=== $q ==="
  customkb query evobio-spike.cfg "$q" --context-only
done | tee EVAL.raw.txt
```
Expected: each probe returns retrieved chunks; capture to `EVAL.raw.txt`.

- [ ] **Step 2: Score against the spec criteria**

Read `EVAL.raw.txt` and judge, per the design's measurable criteria:
1. ≳70% of retrieved chunks are substantive narrative prose (not methods/stats/
   citation residue)?
2. Chunks coherent at 300–500 tokens and on-topic?
3. At least one probe surfaces primary content adding depth beyond the popular-
   author layer?

- [ ] **Step 3: Write `EVAL.md` with the verdict**

Record: probe set, the three scores, and the gate outcome —
**PASS** → write the scale-up design next; **MARGINAL** → tighten the section
filter (Task 3) and re-eval; **FAIL** → primary full-text is the wrong modality,
reconsider (PD foundational books, or review/synthesis articles only).

---

### Task 6: Report (commit deferred)

- [ ] **Step 1: Summarise to the user**

Report: how many articles fetched/kept, whether the build ran locally or needs
okusi3, and the eval verdict with the recommended next step. Do **not** commit —
surface `git status` and let the user commit when they're satisfied.

## Self-Review

**Spec coverage:** Fetch (§Design 1)→Task 2; narrative extraction (§Design 2)→
Task 3; isolated mini-KB (§Design 3)→Tasks 1+4; eval + gate (§Design 4)→Task 5;
isolation/non-goals (§Non-goals)→Global Constraints; backend-feasibility risk→
Task 1 Step 4 + Task 4 Step 2; parked public-exposure item→out of scope, noted in
spec. No uncovered requirements.

**Placeholder scan:** All code steps carry full, runnable code; all run steps
carry exact commands + expected output. No TBD/TODO.

**Type/name consistency:** `evobio-spike.cfg`, `raw/`, `text/`, `PMC<id>.xml`,
`text/PMC<id>-<slug>.md` used consistently across Tasks 1–5; `fetch.sh` produces
exactly what `extract.py` consumes; `extract.py` output feeds `customkb database`
unchanged.

#fin
