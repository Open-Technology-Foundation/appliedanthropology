# kb-metadata.sh — Corpus Metadata Extraction Design

**Date:** 2026-07-09
**Status:** Approved (design), pending implementation
**Template:** `workshops/llm-categorize.sh` v1.2.0

## Purpose

Extract per-document metadata (categories, author, title, year, source URL)
from the ~6,800 `.md` files in the workshops corpus, using one Anthropic API
call per document, and persist results in a SQLite database keyed by filename.

Replaces nothing; complements `llm-categorize.sh` (which remains a multi-model
comparison tool). `kb-metadata.sh` writes one canonical row per document.

## Empirical grounding (measured 2026-07-09)

- 6,821 `.md` files under `workshops/`; **zero duplicate basenames**.
- ~48% of filenames contain `_`, but not all follow the
  `{author}_{title}[_{subtitle}][_{year}]` convention (some use `_` as word
  separators, e.g. `Moores_Law_for_Everything.md`).
- ~20% of files have an H1 in the first 5 lines.
- ~1% have any URL in the first 15 lines; only 14 files corpus-wide contain a
  YouTube URL. `src_url` will therefore be sparse — blank is the honest value.
- YouTube-derived `.md` files typically carry channel name + upload date in
  the lines after the H1, but no URL.
- `transcripts/` and `yt_transcripts/` contain `.transcript.txt` files —
  outside `*.md` scope for v1.

## Decisions (user-approved)

1. **Primary key:** basename (`filename`). Unique today; survives directory
   reorganisation. Script must fail loudly on a future basename collision
   within a single run.
2. **LLM internal knowledge:** allowed for author/year, but **tagged and
   gated** — every LLM-derived field carries a source tag
   (`text|filename|knowledge`), and the prompt instructs: blank the field
   rather than guess. No websearch in v1.
3. **Model:** single tier per run, default **sonnet** (`claude-sonnet-5`);
   `-m` overrides (haiku|sonnet|opus).
4. **Year semantics:** first-publication year of the work (upload date for
   YouTube transcripts). Stored as TEXT; blank when unknown or ancient.
5. **Response shape:** forced tool-use ("shape A") — the API's `tool_choice`
   forces a `record_metadata` tool call whose `input_schema` defines the
   output fields, guaranteeing schema-valid JSON. No text parsing.

## Database

Default path: `$SCRIPT_DIR/corpus-metadata.db` (beside `topics.list`);
`-d FILE` overrides.

```sql
CREATE TABLE IF NOT EXISTS metadata (
  filename   TEXT PRIMARY KEY,  -- basename
  filepath   TEXT NOT NULL,     -- relative path at scan time (informational)
  categories TEXT NOT NULL,     -- comma-separated; never empty ('misc' floor)
  author     TEXT DEFAULT '',
  title      TEXT DEFAULT '',
  year       TEXT DEFAULT '',   -- first-publication year; TEXT, blank ok
  src_url    TEXT DEFAULT '',   -- bash-extracted only, never model-generated
  author_src TEXT DEFAULT '',   -- 'text'|'filename'|'knowledge'|''
  title_src  TEXT DEFAULT '',
  year_src   TEXT DEFAULT '',
  model      TEXT DEFAULT '',   -- model id that produced the row
  updated_at TEXT DEFAULT ''    -- ISO-8601 UTC
);
```

The five audit columns beyond the user's six fields exist to: (a) filter the
hallucination-risk tier in SQL (`WHERE author_src='knowledge'`); (b) enable a
selective second pass (e.g. opus over rows with blank author) via `model` +
`updated_at`; (c) relocate rows after reorganisation via `filepath`.

## Per-document flow

1. **Skip check** — row for basename exists → skip (resumable). `-f/--force`
   re-extracts. In-run basename collision (two paths, same basename) → die.
2. **Bash pre-pass (deterministic):**
   - Parse basename against `{author}_{title}[_{subtitle}][_{year}]`
     (first `_` splits author; trailing `_YYYY` splits year; `-` → space).
     Result is a *hint*, not authoritative.
   - Grep first ~30 lines for the first `https?://` URL → `src_url`.
     This field is bash-only; it is not in the model's output schema.
3. **API call** — request body assembled with `jq --rawfile` (off-argv, per
   v1.2.0), POSTed via `curl --data-binary @-`. Prompt contains: topics list,
   filename + parsed hints, and the `sample_doc` head/middle/tail excerpt
   (SAMPLE_BUDGET machinery reused verbatim from llm-categorize.sh).
   `tools` + `tool_choice:{type:"tool",name:"record_metadata"}` force a
   schema-valid response: `{categories[], title, author, year, title_src,
   author_src, year_src}`. Schema descriptions carry the gating rules
   (blank over guess; year = first publication; author may be a channel name).
4. **Bash validation:**
   - Each returned category checked against `topics.list`; unknowns dropped;
     empty result → `misc`.
   - Year must match `^-?[0-9]{1,4}$` or be blanked.
   - Source tags constrained by the JSON schema enum; anything else blanked.
5. **Upsert** — `INSERT ... ON CONFLICT(filename) DO UPDATE` via sqlite3 CLI;
   values single-quote-escaped (`'` → `''`) by a helper.
6. **Output** — verbose: per-file report block (categories, metadata, source
   tags, tokens, timing). Quiet (`-q`): one TSV line
   `filename\tcategories\tauthor\ttitle\tyear\tsrc_url` to stdout.
   Dry-run (`-n`): extraction + output, no DB write.

## CLI

```
kb-metadata.sh [OPTIONS] file-or-dir [file-or-dir ...]

-t, --topics FILE   Category list (default: SCRIPT_DIR/topics.list)
-m, --model TIER    haiku|sonnet|opus (default: sonnet)
-d, --db FILE       Database (default: SCRIPT_DIR/corpus-metadata.db)
-f, --force         Re-extract documents already in the DB
-n, --dry-run       Extract and print, but do not write to the DB
-v, --verbose       Full report (default)
-q, --quiet         TSV to stdout only; errors to stderr
-V, --version       Version; -h, --help  Help
SAMPLE_BUDGET env   Document sampling budget in chars (default 16000; 0=whole file)
```

Auth, sampling, messaging, BCS structure: inherited from llm-categorize.sh
v1.2.0 unchanged (ANTHROPIC_API_KEY, else `ant auth print-credentials`).

## Error handling

- Per-file API/parse failure → `warn`, continue; no DB row written (re-run
  retries naturally). Failure count reported at end; exit 1 if any failed.
- Missing deps (jq, curl, sqlite3) → die 18. Missing topics/db-dir → die 3.
- DB write failure → die (a broken DB should stop a long run immediately).

## Performance honesty

Sequential, ~2–4 s/document → full corpus ≈ 4–7 hours. Acceptable because
runs are resumable and interruptible (skip-existing). No parallelism in v1;
a `-j` job pool is a possible v2.

## Expected field accuracy (honest assessment)

| Field | Fill rate | Accuracy | Notes |
|---|---|---|---|
| filename, categories | 100% | high | categories proven by llm-categorize.sh |
| title | ~90%+ | high | grounded extraction (H1/filename/body) |
| author | ~60–75% | high when text/filename; audit `knowledge` tier | channel names accepted for YT content |
| year | ~50–60% | medium | definitional rule fixes most ambiguity |
| src_url | ~1% | exact | bash grep; sparse by nature of the corpus |

## Testing

- Stubbed-`curl` harness (as used for llm-categorize.sh): schema creation,
  skip/force/upsert, dry-run, quiet TSV, category validation (unknown→misc),
  quoting with hostile filenames (`O'Brien_...md`), collision detection.
- Live smoke test on 3 representative files (YT-derived, book, bare note)
  before a corpus run.
- shellcheck + bcscheck before declaring done.
