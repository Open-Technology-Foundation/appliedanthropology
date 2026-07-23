# HuggingFace Dataset Import Candidates

Candidate HuggingFace **datasets to incorporate into** the `appliedanthropology`
(secular dharma) corpus. This is the *import* direction — pulling external text
*into* the corpus — as distinct from `docs/hugging-face.md` and
`mk-hf-catalogue.sh`, which cover the *export* direction (publishing this corpus
*to* HuggingFace).

- **Generated**: 2026-07-23, via a 49-agent survey→verify→synthesise workflow.
- **Scope**: 42 unique datasets discovered across 6 domain angles. Every one was
  independently re-fetched from the HF API during verification — **none were
  hallucinated or 404** (a real risk with LLM-suggested dataset ids).

## Gating criteria (in order)

Candidates are ranked by the project's two hard gates, in this order:

1. ◉ **Redistributable licence** — full text is only ingestible under
   public-domain / CC0 / CC-BY / CC-BY-SA / MIT / Apache / AFL / ODC-BY.
   Non-commercial (`CC-BY-NC*`), `other`, or unknown-licence text is **not**
   ingestible (metadata only). This mirrors the `hf-rights.tsv` discipline.
2. ◉ **On-topic prose modality** — the corpus is plain UTF-8 prose → `customkb`
   → bge-m3. Image / audio / tabular / embedding-vector / knowledge-graph-only
   datasets are excluded.

Several genuinely on-topic datasets rank only *conditional* — not for lack of
relevance, but because their on-topic core is buried in large off-topic bulk
(all of arXiv, all of PubMed, 48k Gutenberg books) that would swamp the
~170k-segment corpus if loaded wholesale.

---

## 1. STRONG — ingest (permissive licence, on-topic, real prose)

Seven datasets clear both gates. The **top 6** for extraction are these minus
`garydean/defining-dharma` (see caveat).

| Dataset | Licence | Size | Fills |
|---|---|---|---|
| [OEvortex/Bhagavad_Gita](https://huggingface.co/datasets/OEvortex/Bhagavad_Gita) | MIT | 700 verses | **Hindu-scripture gap** in comparative wisdom literature |
| [joyboseroy/emptiness-graph](https://huggingface.co/datasets/joyboseroy/emptiness-graph) | CC-BY-4.0 | ~1,126 passages | Deepens **Madhyamaka / anattā** beyond the Dhammapada/Batchelor layer |
| [demelin/moral_stories](https://huggingface.co/datasets/demelin/moral_stories) | MIT | ~12k narratives | Grounds prosociality in concrete **norm→action→consequence** vignettes |
| [kiranz38/wisdom-spark-philosophical-wisdom](https://huggingface.co/datasets/kiranz38/wisdom-spark-philosophical-wisdom) | MIT | 77 entries / 17 traditions | Breadth beyond the Western/Buddhist axis (Ubuntu, Sufism, Advaita, Taoism) |
| [m-ric/english_historical_quotes](https://huggingface.co/datasets/m-ric/english_historical_quotes) | MIT | 24,022 rows | Largest clean, de-duplicated philosophy/ethics **quote** set |
| [Abirate/english_quotes](https://huggingface.co/datasets/Abirate/english_quotes) | CC-BY-4.0 | ~2,508 quotes | Aphorism complement (relevance moderate — generic tags) |
| [garydean/defining-dharma](https://huggingface.co/datasets/garydean/defining-dharma) | CC-BY-4.0 | ~44 notes + 9 essays | ▲ **See caveat** |

▲ **Caveat on `garydean/defining-dharma`.** The survey ranked this #1 for being
maximally on-mission — correctly: it is this project's own author/persona (Gary
Dean / DrAA). But its claim of "zero dedup risk" is **wrong**: `hf-rights.tsv`
already lists a `DD` source group (**110 docs, `original` tier**) in this corpus,
and the HF dataset is the polished export of that same DD material. Re-ingesting
the notes would largely duplicate what is already held; only the 9 final essays
are plausibly net-new, and even those overlap. **Excluded from the top-6
extraction** for this reason.

> **Dedup note for the quote sets**: `english_historical_quotes`,
> `english_quotes`, and the conditional quote sets overlap each other *and* the
> existing aphorism layer (Stoicism/Buddhism/Epicureanism ~1,218 docs; zenquotes
> ~5,948 docs). Dedupe across all before embedding.

---

## 2. CONDITIONAL — ingestible only after specific work/checks

### 2a. On-topic, but structured (QA / tabular / DPO) → flatten-to-prose first

| Dataset | Licence | Size | Caveat → verify before ingest |
|---|---|---|---|
| [hendrycks/ethics](https://huggingface.co/datasets/hendrycks/ethics) | MIT | ~72k items | Short labelled snippets, not prose; strip labels, **batch to ≥300-token chunks** or the segmenter drops them |
| [wassname/social_chemistry_101](https://huggingface.co/datasets/wassname/social_chemistry_101) | CC-BY-SA-4.0 | ~356k RoTs / 104k situations | Keep only `situation`+`rot`; heavy duplication; **share-alike obligation** |
| [wassname/moral_stories_foundations](https://huggingface.co/datasets/wassname/moral_stories_foundations) | CC-BY-SA-4.0 | ~12k pairs | DPO table; flatten narrative fields; share-alike; overlaps `moral_stories` |
| [metaeval/scruples](https://huggingface.co/datasets/metaeval/scruples) | Apache-2.0 | ~32.8k | Extract `title`+`text` only; casual Reddit register/UGC |
| [ninoscherrer/moralchoice](https://huggingface.co/datasets/ninoscherrer/moralchoice) | CC-BY-4.0 | ~1.4k dilemmas | Ingest the 2 scenario CSVs only; skip survey/template tables |
| [11-47/high_priest_Buddhism_100k](https://huggingface.co/datasets/11-47/high_priest_Buddhism_100k) | MIT | ~100k QA | `output` field only; **devotional voice cuts against secular framing**; sample-check |
| [AlbertoB12/Stoicism1](https://huggingface.co/datasets/AlbertoB12/Stoicism1) | CC-BY-4.0 | ~2.5k | Extract `output`; dedupe near-identical passages |
| [AlbertoB12/Stoicism2](https://huggingface.co/datasets/AlbertoB12/Stoicism2) | CC-BY-4.0 | ~10k | Synthetic coaching-voice QA; dedupe vs Stoicism1 |
| [Abhaykoul/Ancient-Indian-Wisdom](https://huggingface.co/datasets/Abhaykoul/Ancient-Indian-Wisdom) | MIT | 616 | Synthetic/unverified, traditional-religious framing; tag as such |
| [WithinUsAI/Psychology_25k](https://huggingface.co/datasets/WithinUsAI/Psychology_25k) | CC-BY-4.0 | ~25k | Mostly TRUE/FALSE QA; only ~8k salvageable — skip-leaning; OpenStax Psych 2e is cleaner |

### 2b. On-topic core buried in large off-topic bulk → aggressive pre-filter mandatory

| Dataset | Licence | Size | Caveat → verify before ingest |
|---|---|---|---|
| [sedthh/gutenberg_english](https://huggingface.co/datasets/sedthh/gutenberg_english) | MIT | 48,284 books | Filter by METADATA to canon authors (Aurelius, Epictetus, Seneca, Plato, Spinoza…); dedupe vs existing PD |
| [common-pile/project_gutenberg_filtered](https://huggingface.co/datasets/common-pile/project_gutenberg_filtered) | Public Domain | ~75k books | Title-filter to Sacred Books of the East / PD scripture / classical philosophy |
| [LisaMegaWatts/philosophy-corpus](https://huggingface.co/datasets/LisaMegaWatts/philosophy-corpus) | MIT | ~66 MB of 549 MB | **89% is WikiText-103 (and CC-BY-SA, not MIT)** — use only the per-author humanities files |
| [common-pile/pubmed](https://huggingface.co/datasets/common-pile/pubmed) | CC-BY/SA/CC0 | 5.3M docs / 50 GB | Journal/MeSH filter to evolutionary biology/primatology/behavioural ecology; upstream licence-laundering warning |
| [common-pile/arxiv_abstracts](https://huggingface.co/datasets/common-pile/arxiv_abstracts) | CC0 | 1–2M+ | Filter to `q-bio.PE`/`q-bio.NC` + select cs/stat cooperation papers; abstracts-only |
| [jmhb/pubmed_bioasq_2022](https://huggingface.co/datasets/jmhb/pubmed_bioasq_2022) | CC0 | ~16M | MeSH allowlist (Biological Evolution, Hominidae, Social Behavior…); clinical skew |
| [BrainGPT/…pmc_neuroscience](https://huggingface.co/datasets/BrainGPT/train_valid_split_pmc_neuroscience_2002-2022_filtered_subset) | Apache-2.0 | 445k / 5 GB | Filter to behavioural/affective/consciousness neuro; bulk is neuropathology/oncology |
| [sydonayrex/fineweb-edu-neuroscience](https://huggingface.co/datasets/sydonayrex/fineweb-edu-neuroscience) | ODC-BY | 25,944 web docs | Threshold `int_score` 4–5 + topical filter; CommonCrawl SEO/listicle noise |
| [gfissore/arxiv-abstracts-2021](https://huggingface.co/datasets/gfissore/arxiv-abstracts-2021) | CC0 | ~2M | Same q-bio filter; low-priority fallback |
| [brainchalov/pubmed_arxiv_abstracts_data](https://huggingface.co/datasets/brainchalov/pubmed_arxiv_abstracts_data) | Apache-2.0 | 100k–1M / 7.3 GB | Weak fit; field-filter to biology + keyword; low priority |

### 2c. Format / language / quality caveats

| Dataset | Licence | Size | Caveat → verify before ingest |
|---|---|---|---|
| [ospx1u/buddhist-classics-vol14-20](https://huggingface.co/datasets/ospx1u/buddhist-classics-vol14-20-pali-tibetan-ja-ko) | CC-BY-4.0 | ~157 MB | **AI machine-translation (Gemini), not scholarly**; extract `*.en.txt` from .7z/.zip; tag as MT |
| [renjiezhang/buddhist-classics-vol1-12](https://huggingface.co/datasets/renjiezhang/buddhist-classics-vol1-12) | CC-BY-4.0 | 8.36 GB archives | Non-text as shipped (28 .7z + 2 .iso); only minority English MT (Vol 10) |
| [joyboseroy/bengal-dharma-corpus](https://huggingface.co/datasets/joyboseroy/bengal-dharma-corpus) | CC-BY-4.0 | 75 docs | Non-English (Sanskrit/Bengali) majority, devotional; supplementary only |
| [merve/folk-mythology-tales](https://huggingface.co/datasets/merve/folk-mythology-tales) | CC0 | ~247k lines / 12.5 MB | **Line-fragmented** — reassemble per-tale before embedding; folklore, not core |
| [ykorlk/The_Analects…In_Chinese](https://huggingface.co/datasets/ykorlk/The_Analects_of_Confucius.In_Chinese) | WTFPL | ~500 passages | Classical Chinese only; pair with a PD English Analects (Legge) |
| [mertbozkurt/quotes_philosophers](https://huggingface.co/datasets/mertbozkurt/quotes_philosophers) | AFL-3.0 | ~1,860 | Scraped from azquotes.com — verify a sample of attributions |
| [c2p-cmd/Famous_Quotes](https://huggingface.co/datasets/c2p-cmd/Famous_Quotes) | MIT | ~11.8k | Broad general quotes; filter `category` to wisdom/philosophy/stoic |
| [JDRJ/kjv-bible](https://huggingface.co/datasets/JDRJ/kjv-bible) | No card licence (KJV = US PD) | 31,103 verses | Ingest on **public-domain grounds only**; reflow verses→paragraphs |

### 2d. Rights NOT yet clear — do NOT ingest until resolved

| Dataset | Licence | Size | Blocker |
|---|---|---|---|
| [LLMsForHepth/q-bio_primary](https://huggingface.co/datasets/LLMsForHepth/q-bio_primary) | Mixed per-row (incl. `CC-BY-NC-*`, null) | 28.6k | **Not uniformly ingestible.** Keep only `CC0-1.0`/`CC-BY-4.0` rows in `q-bio.PE`/`NC`; drop the rest |
| [asuender/motivational-quotes](https://huggingface.co/datasets/asuender/motivational-quotes) | Bare `cc` (variant unspecified) | ~4.2k | Unknown CC tier + copyrighted Goodreads scrape; resolve first — low value |

---

## 3. Skipped (5) — and why

None hallucinated/404 (all 42 verified live). Rejected on merit:

- ✗ **Wrong modality (not prose)**:
  [joyboseroy/buddhist-philosophy-graph](https://huggingface.co/datasets/joyboseroy/buddhist-philosophy-graph)
  (knowledge-graph triples) and
  [google-research-datasets/go_emotions](https://huggingface.co/datasets/google-research-datasets/go_emotions)
  (one-line Reddit comments as classification substrate).
- ✗ **Off-topic synthetic/boilerplate QA**:
  [11-47/linguistic_anthropology_25k](https://huggingface.co/datasets/11-47/linguistic_anthropology_25k)
  (templated PIE reconstruction) and
  [learningarena/Anthropology](https://huggingface.co/datasets/learningarena/Anthropology)
  (exam QA, rows flagged `noise`).
- ✗ **Non-permissive licence + upstream copyright**:
  [sweatSmile/buddha-taught-qa](https://huggingface.co/datasets/sweatSmile/buddha-taught-qa)
  — "research/educational" only, derived from Walpola Rahula's in-copyright 1959 book.

---

## 4. How to incorporate

1. ◉ **Rights first, every time.** For each dataset that clears the gate, record
   a row in `hf-rights.tsv` capturing tier + obligations: CC0 / PD (none) →
   CC-BY / AFL / ODC-BY (attribution) → **CC-BY-SA** (attribution + share-alike:
   `social_chemistry_101`, `moral_stories_foundations`). Do not stage the 2d
   datasets until their licence is resolved.
2. ◉ **Extract to prose, then stage.** All ingestion lands as plain UTF-8 under
   `staging.text/<dataset>/…`, then flows through the standard
   `customkb database → embed → bm25` pipeline. For structured sources
   (QA/DPO/tabular/JSONL/graph) pull only the prose fields and flatten; for the
   large corpora, **pre-filter before writing anything**.
3. ▲ **Respect the segmenter.** Many candidates yield sub-`db_min_tokens` (300)
   fragments (quotes, ethics snippets, abstracts, aphorisms) — batch related
   items into paragraph-sized files so they survive segmentation.
4. ▲ **Dedup risk is real.** Quote sets overlap each other and the existing
   Stoicism/zenquotes layer; Gutenberg/PD philosophy sets overlap PD canon
   already held; `moral_stories_foundations` re-uses `moral_stories`; `Stoicism2`
   overlaps `Stoicism1`. Dedupe on text before embedding.
5. ▲ **Flag framing mismatches in metadata.** Devotional / religious-voice /
   AI-MT sources (`high_priest_Buddhism_100k`, `Ancient-Indian-Wisdom`,
   `Bhagavad_Gita`, the AI-MT Buddhist canons) should be tagged
   traditional/synthetic/MT so the secular DrAA persona contextualises rather
   than asserts them as secular-dharma canon.

## Bottom line

Start with the **top 6** (all small, high-signal, low dedup risk except the
quote overlap) — `Bhagavad_Gita` and `emptiness-graph` are the highest-value
additions. Treat §2a/2b/2c as a filtered second wave; the highest *ceiling* is a
q-bio filter over `common-pile/pubmed` or `arxiv_abstracts`, which would add
primary evolutionary-biology depth the corpus currently gets only through
secondary popular authors. Hold §2d until licences are cleared.

Extracted working copies of the top 6 live under `workshops/hf/`.

#fin
