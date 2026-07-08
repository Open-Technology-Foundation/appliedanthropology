# Design: workshops.new/ Restructure

**Date**: 2026-07-08
**Status**: Draft — awaiting approval
**Scope**: Reorganise raw source data for the appliedanthropology KB from the
chaotic `workshops/` tree into a clean `workshops.new/` tree with a
topic-symlink classification layer.

## Problem

`workshops/` holds the raw data for the appliedanthropology KB (~14,000+
documents when fully processed). Its 87 top-level directories mix three
incompatible organising axes — author (`Sapolsky/`), topic (`anarchy/`),
single-work (`Enlightenment_Now/`) — plus ~71 loose top-level files.
Filenames only partially follow the `{author}_{title}[_{subtitle}][_{year}]`
convention; many docs have no clear author (YouTube channels, seminars,
scraped pieces). Nothing has one obvious home; classification judgment calls
multiply.

## Decisions (agreed in brainstorming)

1. **Flat topic vocabulary, ~25 labels, multi-tag.** Topics are *tags*, not
   filing-cabinet slots. A document may carry 1..N topics.
2. **Classification is a symlink layer, not file placement.** Real files
   never move to express topic membership. `topics/<label>/` directories
   contain only symlinks into `corpus/`.
3. **Canonical unit = the processing bundle.** Many existing subdirs are
   processing dirs: original `.epub`/`.pdf`/`.text` sources plus the
   `.md`/`.txt` files derived from them. Bundles move intact — originals are
   never separated from their derived text. Existing internal structure and
   dir names are preserved as-is (they carry no classification meaning).
4. **Topic assignments live in `topics.tsv`** (file path → comma-separated
   topics). This is the single source of truth *now*; the later
   frontmatter-scan project consumes it (writes `topics[]` into frontmatter)
   rather than re-classifying — no drift between the two passes.
5. **Excluded from this restructure**: `theanarchistlibrary.org/`,
   `websearch_data/`, `yt_transcripts/` (raw scrape dumps, not curated).
6. **KB ingestion is unaffected by design**: staging aggregation ingests only
   `.md`/`.txt` and ignores symlinks, so originals alongside derived text are
   skipped and topic symlinks cause no duplication. (Symlink behaviour of the
   importer must be verified — see Risks.)

## Target Structure

```
workshops.new/
  corpus/          # REAL files. Bundles moved intact from workshops/.
                   # Paths carry no classification meaning. KB ingests this.
    Enlightenment_Now/            # epub + derived md together
    Graeber/                      # multi-doc bundle, internal layout untouched
    A-97-Year-Old-Philosopher-Faces-His-Own-Death/   # grouped loose files
    ...
  topics/          # GENERATED symlink views — regenerable, disposable
    secular-dharma/
      what-is-dharma.md -> ../../corpus/.../what-is-dharma.md
    evolutionary-anthropology/
      ...
  topics.tsv       # source of truth: <corpus-relative-path> <TAB> <topic1,topic2,...>
  authors/         # FUTURE: generated from frontmatter after the metadata scan
```

- `corpus/` mirrors current `workshops/` groupings: each existing subdir moves
  wholesale; each loose top-level file (or stem-sharing group, e.g.
  `X.md` + `X.text`) is grouped into its own bundle dir.
- `topics/` is generated from `topics.tsv` by an idempotent script; deleting
  and regenerating the whole tree is always safe.
- Tagging granularity is the individual `.md`/`.txt` file, regardless of
  bundle size — a 10-doc bundle yields 10 independently-tagged files.
- Untagged files simply have no symlinks yet; no `misc/` dump exists.

## Topic Vocabulary (25 labels, flat)

| label | scope |
|---|---|
| `evolutionary-anthropology` | evolution of behaviour, primatology |
| `human-origins-prehistory` | deep history, archaeology, migrations |
| `neuroscience-brain` | brain, cognition |
| `consciousness` | self, awareness, philosophy of mind |
| `dreams-sleep` | sleep science, lucid dreaming |
| `psychology-therapy` | trauma, emotion, therapy modalities |
| `health-body` | diet–brain, nutrition, physical wellbeing |
| `secular-dharma` | dharma theory/definitions, post-religious ethics |
| `buddhism` | Zen, Theravada, canonical texts |
| `mysticism-spirituality` | mystical experience, integral, syncretic |
| `contemplative-practice` | meditation, monasticism, practice methods |
| `philosophy-ethics` | stoicism, wisdom literature, ethics |
| `political-philosophy` | classical political thought, sovereignty |
| `anarchism` | statelessness, mutual aid, commons |
| `cooperation-prosociality` | group selection, social capital |
| `tribalism-belonging` | in/out-groups, subcultures, community |
| `political-economy` | capitalism, debt, work, merit |
| `inequality-poverty` | class, homelessness, precarity |
| `surveillance-privacy` | surveillance state/capitalism |
| `media-propaganda` | social-media harm, information ecosystems |
| `ai-machine-intelligence` | AI, AGI, singularity |
| `futurism-tech-change` | accelerating tech, network-state, energy |
| `history-civilisation` | big history, macro-narratives |
| `myth-religion-culture` | comparative religion, myth, narrative |
| `indonesia-nusantara` | Indonesian/Java/Bali society and ethnography |

Vocabulary may be extended later; renames/merges are cheap (edit
`topics.tsv`, regenerate `topics/`).

## Implementation Phases

1. **P1 — Inventory.** Enumerate curated content in `workshops/` (excluding
   the three dump dirs). Classify each top-level entry: bundle-dir |
   loose-file group. Emit machine-readable manifest. Sanity-check counts.
2. **P2 — Corpus move.** Move bundle dirs intact and group loose files into
   `workshops.new/corpus/`. Name-collision rule: suffix with `-2`, `-3`
   (expected to be rare; manifest flags them for review).
3. **P3 — Importer symlink-safety check.** Verify the staging aggregation
   (`import-staging-text.sh` / `kb-import-staging-text.sh`) does **not**
   follow symlinks (`find -L`, `-follow`, glob traversal). BLOCKER for P5:
   the entire no-duplication guarantee rests on this.
4. **P4 — Tag pass.** LLM-classify every `.md`/`.txt` in `corpus/` against
   the 25-label vocabulary → `topics.tsv`. Batched and resumable
   (checkpointing; 14k docs). Multi-tag, 1..N labels; low-confidence docs
   left untagged rather than mis-tagged.
5. **P5 — Generate `topics/`.** Idempotent script: read `topics.tsv`, build
   relative symlinks. Full-regenerate semantics (wipe + rebuild).
6. **P6 — Verify.** Spot-check tag quality per topic; report untagged count;
   confirm a staging dry-run over `workshops.new/` produces no duplicate
   ingestion and identical `.md`/`.txt` file counts vs manifest.

All scripts: BCS-compliant Bash, shellcheck + bcscheck before done.

## Out of Scope (future projects)

- **Frontmatter scan** across all docs (author/title/year/source_type +
  absorb `topics.tsv` → `topics[]`).
- **`authors/` symlink view**, generated from frontmatter once it exists.
- Any change to the three excluded dump dirs.
- Retiring old `workshops/` (only after `workshops.new/` verified; whether it
  is deleted, archived, or kept is a later user decision).

## Risks

| risk | mitigation |
|---|---|
| Importer follows symlinks → KB duplication | P3 hard gate before any symlink generation |
| LLM mis-tagging at 14k scale | multi-tag reduces cost of misses; low-confidence → untag; P6 spot-checks; symlinks regenerable |
| Name collisions when grouping loose files | manifest flags; deterministic suffix rule |
| Two classification sources drifting (tags now, frontmatter later) | `topics.tsv` is the bridge — frontmatter scan consumes it, never re-classifies |
| Partial move leaves split state | P2 move script is manifest-driven and resumable; verify counts before P4 |

#fin
