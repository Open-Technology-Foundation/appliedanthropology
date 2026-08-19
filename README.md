# Applied Anthropology Knowledgebase

What if you could query a curated library on human nature, cultural evolution, and ethics in seconds? **DrAA** (Doctor of Applied Anthropology) is an AI expert built on 264,512 document segments drawn from 16,282 source works by leading thinkers including David Graeber, Robert Sapolsky, Christopher Boehm, Stephen Batchelor, and Richard Wrangham. It provides evidence-based insights into secular dharma, evolutionary anthropology, and the science of human behavior.

▲ **This repository does not contain the corpus, and the corpus is not distributed.** What is published here is the configuration, tooling, and documentation. The underlying data — the source text, the SQLite database, and the FAISS and BM25 indexes — includes copyrighted material and is not publicly available in any form. Access is granted to approved researchers through the yatti-api interface only. See [Corpus Availability and Rights](#corpus-availability-and-rights).

---

## Access DrAA

### Web Interface

Query DrAA directly at [wah.id](https://wah.id) with no installation required.

### Command-Line via yatti-api

For programmatic access, install [yatti-api](https://github.com/Open-Technology-Foundation/yatti-api):

```bash
# Clone and install
git clone https://github.com/Open-Technology-Foundation/yatti-api.git
cd yatti-api && ./install.sh

# Configure your API key (contact admin@yatti.id to request access)
yatti-api configure

# Query DrAA
yatti-api query appliedanthropology "What distinguishes secular dharma from religious dharma?"
```

See the [yatti-api repository](https://github.com/Open-Technology-Foundation/yatti-api) for prerequisites and detailed documentation.

---

## Corpus Availability and Rights

The corpus is **not downloadable, not redistributable, and not published** — not here, not as a dataset release, and not on request as a bulk copy.

A substantial part of it is in-copyright: books, articles, and transcripts held under standard commercial terms. They were assembled for research use, and nothing in that assembly grants any right to redistribute them. This applies to every derived artefact as well. A FAISS index and a set of BM25 token counts are not a loophole — they are computed from the source text, and a segment database reconstitutes it directly.

### What access exists

Query access is mediated, and mediation is the point. Both routes return synthesised answers and bounded reference segments, never bulk text:

- **[wah.id](https://wah.id)** — open web interface, no installation
- **[yatti-api](https://github.com/Open-Technology-Foundation/yatti-api)** — programmatic access for approved researchers; request credentials from admin@yatti.id

There is no third route. Requests for the database, the index files, or the staging text cannot be granted regardless of affiliation or intended use.

### How rights are tracked

Rights are recorded per source group in `hf-rights.tsv` and resolved by longest-matching path prefix. An unrecognised prefix resolves to `copyrighted`, so the failure mode of an incomplete register is to withhold text rather than leak it.

Two decisions are kept deliberately separate. The register records **what the licence is**; `mk-hf-catalogue.sh` holds a short allowlist deciding **which licences may be exported** — currently `original`, `public-domain`, `cc0`, and `cc-by`. Naming a new tier in the register therefore grants nothing on its own. This matters because the earlier rule exported anything that was merely "not copyrighted", which quietly authorises every tier nobody has thought of yet.

| Tier | Meaning | Text exported |
|---|---|:--|
| `original` | Gary Dean's own work, or AI-generated | Yes |
| `public-domain` | Work *and* translation verified out of copyright | Yes |
| `cc0` | Dedicated to the public domain by the rights holder | Yes |
| `cc-by` | Creative Commons Attribution | Yes, with attribution |
| `cc-by-nc`, `cc-by-nc-nd`, `cc-by-nc-sa` | Non-commercial variants | No |
| `copyrighted` | In copyright, or unverified | No |

The non-commercial variants are withheld because this release carries no NC terms. NoDerivatives is withheld for a second, independent reason: extracted articles store narrative sections only, so the stored text is an abridgement, and distributing it would be making a derivative.

`mk-hf-catalogue.sh` builds a bibliographic catalogue from the register, carrying the tier into every record and setting `text_included` from the allowlist. The catalogue is generated locally and has **not** been published; the dataset export remains pending. As generated from the 2026-08-09 register snapshot, its 16,157 records break down as:

| Rights tier | Records | Text included |
|---|---:|:---|
| `copyrighted` | 12,309 | No |
| `original` | 3,840 | Yes |
| `public-domain` | 8 | Yes |

That is 13,432 segments carrying text against 249,115 held as metadata only — around 5%.

The translation behind each of the eight public-domain documents is identified: Montaigne (Cotton, 1877), Kropotkin's *Mutual Aid* (English original), Spinoza's *Ethics* (Elwes, 1883), Plato's *Republic* and *Apology* (Jowett), Schopenhauer's *The World As Will And Idea* (Haldane and Kemp) and *The Wisdom of Life* (Saunders, 1890), and Machiavelli's *The Prince* (Marriott, 1908).

Seven of the eight name their translator in the file. *The Wisdom of Life* does not, and was confirmed externally instead: its title and the opening of its Introduction match the Project Gutenberg edition of Saunders' translation verbatim, and its Translator's Notes date themselves by referring to the 1800s as "the present century".

▲ `hf-rights.tsv` began as a machine-guessed skeleton and every permissive tier has now been checked against the source documents. That review is what taught the register that a directory named for a philosopher can hold a podcast transcript, that a file whose metadata says 1755 can be a translation published in 1985, and that an article can carry a licence which expired with the WHO pandemic declaration.

Two items are held at `copyrighted` by decision rather than by evidence of infringement, and could move if someone resolves them: the Urantia text (public domain in the US on the 2003 Tenth Circuit ruling, contested elsewhere, so a global release cannot rely on it) and Joseph Ratner's 1926 Spinoza edition (public domain in the US, but his editorial apparatus runs to 2049 in the UK and EU).

The working rule is that a permissive tier must be earned by evidence in the document itself. Filenames and metadata years both mislead, absence of a licence is not permission, and a public-domain *work* never implies a public-domain *translation*.

---

## Example: DrAA in Action

**Query**: "What distinguishes secular dharma from religious dharma?"

**Response**:

> Key distinctions:
>
> - **Non-metaphysical frame**: Secular dharma brackets claims like rebirth, karmic law as cosmic justice, other realms, and final nirvana; it grounds practice in this life, here-and-now experience, and evidence (Batchelor; Bodhi College materials).
>
> - **Tasks over truths**: Recasts the Four Noble Truths as four practical tasks--embrace dukkha, let go of reactivity, behold its ceasing, cultivate an integrated ethical life--rather than assent to doctrinal truth-claims.
>
> - **Human-centered and contextual**: Oriented to human flourishing in specific societies, adapting teachings to contemporary issues (AI, climate, social justice) using psychology, neuroscience, and evolutionary anthropology.
>
> - **Inclusivity and pluralism**: Open to people of any or no religion; acknowledges many dharmas, not one "The Dharma," and invites personal interpretation and local adaptation.
>
> - **Practice-first pragmatism**: Emphasizes mindfulness, ethical action, and civic responsibility as verifiable skills and social practices, not ritual or hierarchy as gatekeepers.
>
> - **Non-authoritarian ethos**: Minimizes reliance on sacred canons, priestly authority, or ritual orthodoxy; legitimizes claims via critical inquiry, shared practice, and publicly checkable outcomes.
>
> - **Dialogue with science**: Integrates empirical research on mind and behavior; treats dharma as an evolving cultural technology rather than a revealed cosmology.
>
> In short: religious dharma orients around metaphysical truths and soteriological ends; secular dharma orients around practical tasks for ethical flourishing in this world, updated by critical inquiry and science.

---

## What is DrAA?

DrAA (Doctor of Applied Anthropology) is a specialized AI expert system grounded in a curated corpus of scholarly works spanning evolutionary biology, cultural anthropology, philosophy, psychology, and secular dharma studies.

### Core Expertise

- **Secular Dharma Studies**: Evidence-based exploration of ethical pathways, cultural evolution, and moral frameworks without metaphysical commitments
- **Applied Anthropology**: Human behavioral evolution, cultural sociology, and biological anthropology with practical applications
- **Evolutionary Biology**: Human nature, behavioral genetics, cooperation dynamics, and group social organization
- **Cross-Disciplinary Synthesis**: Philosophy, psychology, neuroscience, cultural studies, and consciousness research
- **Comparative Ethics**: Religious vs. secular approaches to human organization, cooperation, and ethical living

### Scholarly Foundation

| Author | Focus Areas |
|--------|-------------|
| David Graeber | *Dawn of Everything*, *Debt*, political anthropology |
| Robert Sapolsky | Behavioral biology, stress, neuroscience |
| Christopher Boehm | *Hierarchy in the Forest*, egalitarianism |
| Stephen Batchelor | Secular Buddhism, *After Buddhism* |
| Richard Wrangham | Human evolution, violence, self-domestication |
| Rutger Bregman | *Humankind*, human cooperation |
| James C. Scott | Political anthropology, state formation |
| Matthew Walker | Sleep science, neuroscience |
| Lisa Feldman Barrett | Emotion, consciousness, neuroscience |

Plus 100+ additional scholars across anthropology, philosophy, psychology, and related fields.

---

## Who This Is For

### Academic Researchers
Graduate students, faculty, and postdocs in anthropology, evolutionary biology, philosophy, religious studies, and psychology seeking scholarly synthesis and literature discovery.

### Secular Practitioners
Secular Buddhists, humanists, and contemplative practice communities looking for evidence-based approaches to mindfulness and ethical living.

### Applied Professionals
Policy researchers, educators, and mental health professionals integrating anthropological insights into their work.

### Technology Workers
AI researchers and data scientists exploring human behavioral patterns, cooperation dynamics, and cultural evolution.

### Writers and Public Intellectuals
Science writers and communicators covering human evolution, ethics, and the intersection of ancient wisdom with modern science.

---

## Key Concepts

The knowledgebase operates with specific definitions that distinguish it from traditional approaches:

**dharma**: A way, path, culture, or outlook adopted by individuals or groups that defines ethical living within their specific environmental and cultural context. Not a universal "The Dharma" but diverse, adaptive ethical systems.

**dharmas**: Multiple, pluralistic forms that evolve and adapt to specific contexts and environments. Secular dharmas are equally valid and scientifically grounded as religious interpretations.

**dharmic**: (noun) A person who adheres to a dharma; (adjective) Exhibiting qualities characteristic of an ethical path or way of being.

**applied anthropology**: Biology-grounded understanding of human culture, behavior, and social organization with direct practical applications to contemporary challenges.

---

## Example Queries

### Academic Research
```bash
yatti-api query appliedanthropology "What do evolutionary anthropologists say about the origins of human cooperation?"
yatti-api query appliedanthropology "Compare Graeber and Boehm on hierarchy and egalitarianism"
yatti-api query appliedanthropology "How do cultural and biological evolution interact in ethical systems?"
```

### Comparative Analysis
```bash
yatti-api query appliedanthropology "What are the evolutionary origins of human ethical behavior?"
yatti-api query appliedanthropology "Compare Buddhist and secular humanist ethical frameworks"
yatti-api query appliedanthropology "How do dharmas emerge and adapt to environmental pressures?"
```

### Applied Understanding
```bash
yatti-api query appliedanthropology "What can anthropology teach us about sustainable social organization?"
yatti-api query appliedanthropology "How can secular dharma principles inform contemporary social policy?"
```

### Context-Only Retrieval
```bash
# Return source segments without AI synthesis
yatti-api query appliedanthropology "dharma" --context-only
```

---

## Technical Architecture

### Scale and Storage

Figures verified against the live database on 2026-08-18.

| Measure | Value |
|---------|-------|
| Document segments | 264,512 |
| Source works | 16,282 |
| Embedded segments | 264,512 (100%) |
| FAISS vectors | 253,744 (10,768 duplicate-text segments share a vector) |
| BM25-indexed segments | 264,404 |
| SQLite database | 1.7GB apparent |
| FAISS index | 998MB apparent |
| BM25 index | 272MB apparent |

▲ Apparent sizes. The pool is ZFS with compression enabled, so `du` without `--apparent-size` reports considerably less (roughly 515MB and 693MB for the database and index respectively).

◉ The 108 segments missing from the BM25 index are degenerate chunks that tokenise to nothing — stopword runs, bare list numerals, OCR residue, and non-Latin-script fragments. Their exclusion is by design, not a gap. (The former pandoc `:::` div-fence junk was purged from the corpus entirely.)

### Technology Stack

- **Knowledgebase Framework**: CustomKB
- **Embeddings**: BAAI bge-m3, 1024 dimensions
- **Vector Index**: FAISS `IndexIDMap`
- **Query Model**: claude-sonnet-5
- **Lexical Search**: BM25 (k1 1.2, b 0.75)
- **Hybrid Fusion**: Reciprocal rank fusion, vector weight 0.7 / BM25 weight 0.3
- **Reranking**: BAAI bge-reranker-v2-m3 cross-encoder, CPU
- **Query Enhancement**: Spelling correction enabled, synonym expansion disabled

### Retrieval Settings

- **Top-K**: 30 segments per query, context scope 3
- **Temperature**: 0.420
- **Max Response Tokens**: 16,384
- **Query Cache**: 30-day TTL
- **FAISS nprobe**: 32

---

## Repository Layout

```
appliedanthropology/
├── appliedanthropology.cfg               # Main configuration (persona, retrieval, WAHID)
├── appliedanthropology.build.conf        # Legacy, unread — see note below
├── appliedanthropology.faiss.meta        # Index provenance (model, dimensions, vectors)
├── appliedanthropology.context.md        # Query-time context file
├── appliedanthropology_primary_prompt.md # DrAA persona prompt
├── secular_dharma_primary_prompt.md      # Sibling seculardharma persona prompt
├── cats/categories.yaml                  # Category taxonomy
├── create_text_cache.sh                  # Assemble staging text from source repositories
├── kb-import-staging-text.sh             # Import staging text into the database
├── mk-hf-catalogue.sh                    # Generate the Hugging Face dataset catalogue
├── evobio-fetch.sh                       # Fetch PMC full text for the evobio corpus
├── evobio-extract.py                     # Extract and normalise PMC full text
├── hf-rights.tsv                         # Source rights and licensing register
├── docs/                                 # Documentation, research notes, design specs
├── research/                             # Research scripts
└── projects/                             # Ad-hoc query scripts
```

Build outputs (`*.db`, `*.faiss`, `*.bm25.*`), `staging.text/`, `logs/`, and `backups/` are excluded from version control. They are not merely untracked for tidiness — they carry the corpus, and publishing them would redistribute copyrighted source material.

---

## Working with the Knowledgebase

◉ This section is for maintainers who already hold the source material. The commands below operate on a local corpus; they will not fetch or reconstruct one, and running them without the source text produces an empty knowledgebase.

### Build Pipeline

Builds are orchestrated by `customkb build`, which runs numbered stages. Stage 0
invokes the `staging_script` named in the `[BUILD]` section of the config — for this
knowledgebase, `kb-import-staging-text.sh`.

```bash
# Full incremental update (all stages, non-interactive)
customkb build appliedanthropology -a -y

# Full rebuild from scratch (deletes DB, FAISS and BM25 first)
customkb build appliedanthropology --fresh -a -y

# Typical partial run: stage, import, embed
customkb build appliedanthropology -0 -3 -5 -y
```

| Stage | Action |
|-------|--------|
| `-0` | Data staging (runs `kb-import-staging-text.sh`) |
| `-3` | Database import, including BM25 when hybrid search is enabled |
| `-5` | Generate embeddings |
| `-6` | Run the configured test query |

▲ Stages `-1` and `-2` generate and append AI citations. They are **not** used here — this knowledgebase has no `citations` table. Stage `-4` (categorisation) is retired and is a no-op; categories now come from document frontmatter.

Individual operations can also be driven directly:

```bash
customkb database appliedanthropology staging.text/*   # Import staged text
customkb embed appliedanthropology                     # Generate embeddings
customkb bm25 appliedanthropology                      # Rebuild the BM25 index
```

`create_text_cache.sh` is a separate helper that assembles `staging.text/` from the
sibling knowledgebase repositories before a build.

### Direct Query Commands

```bash
# Interactive query mode
customkb query appliedanthropology

# Direct query
customkb query appliedanthropology "What is dharma in secular context?"

# Context-only (no AI response)
customkb query appliedanthropology "dharma" --context-only
```

### Database Management

```bash
# Segment and source counts
sqlite3 appliedanthropology.db "SELECT COUNT(*) FROM docs;"
sqlite3 appliedanthropology.db "SELECT COUNT(DISTINCT sourcedoc) FROM docs;"

# Embedding coverage
sqlite3 appliedanthropology.db "SELECT COUNT(*) total, SUM(embedded) embedded FROM docs;"

# Verify indexes
customkb verify-indexes appliedanthropology

# Optimize performance
customkb optimize appliedanthropology
```

The database exposes two tables: `docs` (segments, metadata, BM25 tokens) and `file_metadata`, which is present but currently unused.

### Configuration Files

- **appliedanthropology.cfg**: The single source of truth — retrieval parameters, DrAA persona, WAHID catalogue entry, and the `[BUILD]` section that drives `customkb build`
- **appliedanthropology_primary_prompt.md**: AI assistant personality and response guidelines

▲ **appliedanthropology.build.conf is legacy and unread.** It was configuration for the retired `0_build.sh`; nothing in customkb references it. Build settings live in the `[BUILD]` section of the `.cfg`. Because that section currently sets only `staging_script`, stage `-6` warns and skips rather than running the test query written in `.build.conf`.

### System Requirements

- **CPU**: Multi-core processor; reranking runs on CPU by default
- **Memory**: Minimum 16GB RAM (32GB recommended)
- **Storage**: 4GB+ for the database and indexes, plus space for staging text
- **Software**: CustomKB, Python 3.12+, SQLite 3.45+, FAISS

---

## Related Resources

### Related Knowledgebases
- **seculardharma**: The same corpus under a different persona — a Secular Dharma Research Assistant rather than DrAA
- **prosocial.world**: Prosocial behavior and social evolution
- **wayang.net**: Indonesian wayang culture and traditional arts

### Integration
- Shared caching infrastructure across the vectordbs ecosystem
- Cross-referencing capabilities with other anthropological resources
- Query caching with 30-day TTL

---

## Contributing

Areas for contribution:

- Additional source material for inclusion in the dataset
- Enhanced search algorithms and relevance tuning
- Cross-cultural wisdom tradition integrations
- Performance optimizations and caching improvements
- New analytical frameworks and methodological approaches

Shell scripts follow the Bash Coding Standard (BCS) and are checked with `shellcheck` in CI.

---

## License

GPL-3.0 covers **the contents of this repository** — the configuration, scripts, and documentation. See [LICENSE](LICENSE).

▲ It does not cover the corpus. The source material carries the rights of its respective publishers and authors, is not licensed under GPL-3.0 or any other open licence, and is not distributed with this repository. See [Corpus Availability and Rights](#corpus-availability-and-rights).

---

The Applied Anthropology Knowledgebase bridges ancient wisdom traditions with contemporary scientific understanding, providing rigorous academic frameworks grounded in peer-reviewed research for the growing global community seeking evidence-based approaches to ethics, meaning-making, and human flourishing.
