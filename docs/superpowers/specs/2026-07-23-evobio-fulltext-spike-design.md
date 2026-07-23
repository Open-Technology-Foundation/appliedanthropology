# Design: Evolutionary-Biology Full-Text Ingestion — Feasibility Spike

- **Date**: 2026-07-23
- **Status**: design (awaiting review)
- **Origin**: `docs/hf-import-candidates.md` §"Bottom line" — *"the highest ceiling
  is a q-bio filter over `common-pile/pubmed` or `arxiv_abstracts`, which would add
  primary evolutionary-biology depth the corpus currently gets only through
  secondary popular authors."*

## Purpose

Test — cheaply and in isolation — whether **modern full-text human-behavioural
evolutionary-biology articles** are a useful addition to the corpus, *before*
committing to any scale ingestion. The report proposed abstracts; discussion
reframed the target to **complete texts** (abstracts are too short and read as
terse jargon). This spike stages a small, curated sample as a standalone
throwaway knowledgebase and measures retrieval quality against realistic probes.

The spike answers one question: **does dense primary-literature prose, filtered
to its narrative sections, retrieve as coherent, on-topic, substantive passages
in this KB's embedding + reranker stack — or does it surface as noise?** That
verdict gates whether (and how) to scale up.

## Scope decisions (settled)

| Dimension | Decision | Rationale |
|---|---|---|
| Modality | Full-text articles, **not** abstracts | Full text segments cleanly into 300–500-tok chunks; abstracts (150–250 tok) fall below `db_min_tokens=300` and read as jargon |
| Topical slice | **Human-behavioural core** | Cooperation, morality, social behaviour, primatology, human evolution, behavioural ecology — the only evo-bio slice on the corpus's human-nature/ethics axis |
| Source | **PMC Open-Access subset** via NCBI E-utilities (Approach A) | Cleanest, reproducible, bash/`curl`-scriptable; no 50 GB download; OA restriction is irrelevant to *what the spike measures* |
| Extraction | **Narrative sections only** | Keep Abstract / Introduction / Discussion / Conclusion; drop Methods, Results-statistics, tables, figures, reference lists — the structural noise that pollutes retrieval |
| Isolation | Standalone mini-KB at `/var/lib/vectordbs/evobio-spike/` | Zero risk to the 170k-segment shared AA/SD production corpus; trivially deletable |
| Copyright | **Non-gating** (private research system) | Removes the `hf-rights.tsv` licence gate; irrelevant to the spike itself, decisive at scale-up |

## Non-goals

- **Not** touching `appliedanthropology.db` / `.faiss` (or the byte-identical
  seculardharma copies). The spike is fully self-contained.
- **Not** the scale-up ingestion, journal-broadening, or corpus fold-in.
- **Not** resolving the public-exposure question (see *Parked*).
- **Not** producing `hf-rights.tsv` rows — rights are non-gating here.

## Approaches considered

- **A — surgical PMC-OA fetch by topic+journal (chosen).** E-utilities
  `esearch`→`efetch` for ~30–50 OA full-text articles. Reproducible, light,
  scriptable.
- **B — slice the 50 GB `common-pile/pubmed` HF dump.** Exercises the eventual
  production path but far too heavy for a spike; the licence-laundering noise it
  carries is moot now that copyright isn't gating.
- **C — broad in-copyright pull regardless of licence.** Closer to the real
  scale-up, but messy to source cleanly/reproducibly — deferred to scale-up,
  once the spike has proven the register is worth it.

## Design — four stages

### 1. Fetch (`fetch.sh`)

- NCBI E-utilities (`https://eutils.ncbi.nlm.nih.gov/entrez/eutils/`).
- `esearch` on `db=pmc` with a human-behavioural-evolution term set AND the
  open-access filter, e.g.:
  `("human cooperation"[tiab] OR "reciprocal altruism"[tiab] OR "primate social"[tiab]
   OR "human evolution"[tiab] OR "behavioral ecology"[tiab] OR "evolution of morality"[tiab])
   AND "open access"[filter]`, `retmax≈60`.
- `efetch` `db=pmc rettype=full` (JATS XML) per PMCID → `raw/<PMCID>.xml`.
- **Robustness**: respect the anonymous 3-req/s limit (polite delay; use
  `NCBI_API_KEY` if set); verify each file is well-formed (`xmllint --noout`) and
  retry on truncation — the same defensive pattern the earlier HF downloads
  needed.

### 2. Extract narrative sections (`extract.py`)

- Parse JATS (Python stdlib `xml.etree`, mirroring the existing
  `workshops/hf/extract.py` precedent — XML→prose is the one legitimate
  non-bash step).
- **Keep**: `<abstract>`; `<body>` `<sec>` whose `@sec-type` or `<title>` matches
  *Introduction / Background / Discussion / General Discussion / Conclusion(s)*.
- **Drop**: Methods/Materials, Results (statistics), `<table-wrap>`, `<fig>`,
  `<ref-list>`, acknowledgements, funding, author-contributions; flatten inline
  `<xref>` citations to readable text.
  - *Judgment call to note in the plan*: "Results" sections in behavioural
    articles sometimes carry narrative — default is **drop**; revisit only if the
    eval shows we lost signal.
- Output one `.md` per article to `text/<PMCID>-<slug>.md`, each with a plain
  provenance header (title, journal, year, PMCID, source URL). Plain UTF-8,
  paragraphs preserved.

### 3. Build the isolated mini-KB

- Dir `/var/lib/vectordbs/evobio-spike/`, `evobio-spike.cfg` **derived from the
  live `appliedanthropology.cfg`** (bge-m3 embeddings, bge-reranker-v2-m3,
  `db_min_tokens=300`, `db_max_tokens=500`, `bm25_enabled=true`) — copied from
  the *actual config, not the docs* (CLAUDE.md notes `long_desc` doc-drift citing
  stale OpenAI/GPT-4o values; the cfg is canonical).
- Build: `customkb database evobio-spike.cfg text/*.md` → `customkb embed
  evobio-spike.cfg` → `customkb bm25 evobio-spike.cfg`.
- Fully standalone: shares nothing with the AA/SD corpus.

### 4. Evaluate + decision gate

- Run 6–8 `customkb query evobio-spike.cfg "<probe>" --context-only` probes that
  *should* hit the new layer, e.g.:
  - "reciprocal altruism and the evolution of human fairness"
  - "primate coalition formation and egalitarian social structure"
  - "costly signalling and the evolution of moral behaviour"
  - "alloparenting and cooperative breeding in human evolution"
- **Success criteria (measurable):**
  1. ≳70% of retrieved chunks across probes are substantive narrative prose (not
     methods/stats/citation residue).
  2. Chunks read coherently at 300–500 tokens and are on-topic.
  3. Spot-check: does at least one probe surface *primary* content that adds
     depth beyond the popular-author layer already in the corpus?
- **Gate:**
  - **PASS** → proceed to a scale-up design (broaden journals, relax the OA
    restriction using the copyright-freedom, decide fold-in-vs-separate-KB, and
    address public exposure).
  - **MARGINAL** → tighten the section filter and re-evaluate.
  - **FAIL** → primary-literature full text is the wrong modality; reconsider
    (e.g. PD foundational books, or curated review/synthesis articles only).

## Parked (revisit only at scale-up, not now)

The AA `.db`/`.faiss` are **byte-shared** with the seculardharma KB, which serves
the **public** `wah.id` frontend on okusi3; RAG can surface source passages
verbatim. So "private corpus" has a public-facing edge for *in-copyright* full
text — but this bites only at the fold-into-shared-corpus step, never during the
isolated spike. Flag it at the scale-up decision.

## Deliverables

- `/var/lib/vectordbs/evobio-spike/` — `fetch.sh`, `extract.py`, `raw/`, `text/`,
  `evobio-spike.cfg`, built `.db`/`.faiss`/`.bm25` (all throwaway).
- A short eval write-up (probe outputs + verdict against the criteria above) that
  becomes the input to the scale-up go/no-go.

#fin
