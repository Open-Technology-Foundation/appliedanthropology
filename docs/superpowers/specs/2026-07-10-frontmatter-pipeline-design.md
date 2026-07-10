# Frontmatter Pipeline Integration — Design

**Date:** 2026-07-10
**Status:** Approved (user: "proceed in that order, include transcript coverage")
**Depends on:** `workshops/corpus-metadata.db` (built by `workshops/kb-metadata.sh`, spec 2026-07-09)

## Purpose

Carry per-document metadata (categories, author, title, year, src_url) from
`corpus-metadata.db` into the customkb ingestion pipeline via YAML frontmatter
stamped onto staged copies, so that `docs.primary_category` / `docs.categories`
are populated at import time and the per-chunk metadata JSON carries
title/author/year. Retires the half-working `customkb categorize` populate path.

## Approved execution order

1. **Corpus run** — `kb-metadata.sh .` over all 6,821 workshops .md files
   (RUNNING: pid file `logs/kb-metadata-corpus-run.pid`, log
   `logs/kb-metadata-corpus-run.log`; resumable if interrupted).
2. **Change B** — customkb.bash: parse + strip frontmatter at `customkb database`
   ingest. MUST land before Change A: stamping without stripping embeds YAML
   into the first chunk of every matched file.
3. **Change A** — `kb-import-staging-text.sh`: stamp frontmatter onto staged
   copies (md from corpus-metadata.db; transcripts from video_info.sh +
   channel_info.sh, LLM-free).
4. **Retire** — remove the `customkb categorize` populate subcommand; keep the
   working query-side `--categories` filter.

## Verified facts this design rests on

- `docs` schema already has `primary_category TEXT`, `categories TEXT`,
  `metadata TEXT` (lib/database.sh `ckb_db_create_tables`); import INSERT
  (customkb ~:887) currently populates neither category column.
- Query-side category filtering already works end-to-end:
  `customkb query --categories …` → engine `/query` →
  `filter_by_categories` (engine/customkb/query/search.py:106-170;
  `primary_category` exact OR `categories LIKE`).
- No frontmatter handling exists anywhere in customkb.bash ingest
  (ckb_read_file / ckb_clean_text have no `---` logic).
- `staging.text/` is wiped and rebuilt on every `kb-import-staging-text.sh`
  run (`rm -rf` + full re-copy) — staged copies are safe to mutate; workshops/
  sources stay pristine.
- `docs.sourcedoc` = realpath of the staged file; corpus-metadata.db keys by
  basename; basenames are verified unique corpus-wide.
- video_info.sh (uniform across sampled 200): `video_title`, `video_url`,
  `video_id`, `video_name_slug`, `video_dir`, description/duration/views.
  NO upload date anywhere in the media tree → transcript `year` is omitted.
  Channel name comes from `${video_dir%%/videos/*}/channel_info.sh`
  (`channel_name`).
- customkb.bash house style differs from workshops scripts: `#!/usr/bin/env
  bash`; libraries have version guards and NO strict mode; `ckb_`/`_ckb_`
  prefixes; `declare -fx` exports; integers use `local -i` + standalone
  `i+=1` (never `((i+=1))`); tests = `./run_tests.sh`, 10 suites / 201 checks.

## Frontmatter format (the contract between A and B)

```yaml
---
title: "Imagining a World with No Bullshit Jobs"
authors:
  - "Chris Brooks"
  - "David Graeber"
year: 2018
categories:
  - political-economy
  - inequality-poverty
source_url: "https://roarmag.org/essays/graeber-bullshit-jobs-interview/"
provenance: { author: text, title: text, year: text, model: claude-sonnet-5 }
---
```

Rules:
- Block starts at byte 0 with a line exactly `---`; ends at the next line
  exactly `---`. No opener at byte 0 → file has no frontmatter.
- Scalars are double-quoted with `\` and `"` backslash-escaped; `year` is a
  bare number. Blank fields are omitted entirely (never `key: ""`).
- Lists use `  - item` block form.
- Parsers ignore unknown keys (`provenance`, future additions).
- Transcript variant: `title`, `authors` (channel name), `source_url`
  (video_url), `type: video-transcript`; no year, no categories.

## Change B — customkb.bash (ingest side)

### New: `ckb_parse_frontmatter` (lib/text_utils.sh)

- Input: file content (arg). Output: `_rv` = content with the block stripped;
  globals `CKB_FM_TITLE`, `CKB_FM_AUTHOR` (comma-joined), `CKB_FM_YEAR`,
  `CKB_FM_CATEGORIES` (comma-joined, list order preserved) — all reset to ''
  on every call.
- Recognised keys: `title`, `author`, `authors` (scalar or block list),
  `year`, `categories` (block list or comma scalar), `source_url`/`src_url`.
  Everything else skipped. Quoted scalars unquoted (strip surrounding `"`,
  unescape `\"` and `\\`).
- Malformed/unterminated block (no closing `---` within 100 lines): treat as
  NO frontmatter — return content unchanged. Never destroy content.
- Pure bash, zero forks, library style (no strict mode, `declare -fx`).

### Import-loop changes (`customkb` database command, ~:830-887)

- After `ckb_read_file` (and before size/chunk logic that uses content):
  `ckb_parse_frontmatter "$content"; content=$_rv` + capture the four fields.
- INSERT column list gains `primary_category, categories` populated as
  `NULLIF('<esc>','')`:
  - `primary_category` ← first element of categories (kb-metadata puts
    best-fit first by design);
  - `categories` ← full comma-joined list.
- `ckb_build_metadata` gains three optional trailing args (title, author,
  year), appended to the chunk JSON only when non-empty:
  `"title":"…","author":"…","year":"…"`.
- Stripping happens BEFORE the engine `/chunk` call and before
  `ckb_bm25_tokenize` — frontmatter must never reach embeddings or BM25.

### Tests (extend existing suites; run_tests.sh must stay green)

- test_phase0.sh (unit): no-frontmatter passthrough; full block parse
  (lists + quoted scalars + escapes); unknown keys ignored; unterminated
  block → unchanged; `---` mid-file (not byte 0) → unchanged; authors
  scalar vs list; categories comma-scalar vs list.
- test_phase4.sh (import): stamped fixture file → docs row has
  primary_category/categories populated, metadata JSON carries
  title/author/year, and originaltext/embedtext do NOT contain `---` or
  the YAML keys. Unstamped fixture → columns NULL, behaviour unchanged.

## Change A — kb-import-staging-text.sh (stamp side)

### md stamping (collect_files)

- Preload the whole metadata table once into an assoc array keyed by
  filename (one sqlite3 fork, US-separated fields:
  `SELECT filename,categories,author,title,year,src_url FROM metadata`).
  DB path: `$SCRIPT_DIR/workshops/corpus-metadata.db`. DB absent → warn
  once, stamp nothing, behave exactly as today.
- In the copy loop: `.md` with a DB row → write frontmatter + original
  content to the staging destination (preserve mtime semantics with
  `touch -r`); no row or non-md → `cp -p` as now.
- Frontmatter emission = the format contract above (shared emitter
  function; blank fields omitted; YAML escaping for `"` and `\`).

### Transcript stamping (process_transcripts)

- For each transcript with a resolvable `video_info.sh`: source it in the
  existing strict-off subshell pattern, ALSO pulling `video_title` and
  `video_url`; resolve `channel_info.sh` via `${video_dir%%/videos/*}` and
  pull `channel_name` the same way.
- Write staged transcript as frontmatter (`title`, `authors`: channel_name,
  `source_url`: video_url, `type: video-transcript`) + original transcript
  text. Missing/malformed info files → plain copy (current behaviour).
- Note: transcripts are `.txt`; customkb ingests them; Change B parses
  frontmatter regardless of extension (byte-0 `---` rule), so they get
  title/author metadata but NULL categories. When the user later converts
  txt→md, kb-metadata.sh takes over and adds categories.

## Retirement — customkb categorize

- Remove: the `categorize` dispatch case, `show_categorize_help`,
  `_categorize_article`, the sampling/checkpoint/import/list helpers
  (customkb ~:935-1360 region), and README/CLAUDE.md references to the
  subcommand.
- Keep: query-side `--categories` filter (CLI + engine), the
  `primary_category`/`categories` columns and index, and
  `cats/` artifacts on disk (historical data; not deleted).
- `customkb categorize` afterwards: unknown command via the normal
  dispatcher error path (no stub).
- tests/test_phase5.sh (categorize suite): retire/replace with a minimal
  check that the command is gone and the dispatcher errors cleanly; adjust
  run_tests.sh suite list and expected totals.

## Verification

- Baseline `./run_tests.sh` BEFORE any change (record count ~201); full
  suite after each change; report counts.
- End-to-end (requires customkb-engine daemon): temp KB fixture, import one
  stamped md + one stamped transcript + one plain file; assert category
  columns, metadata JSON, and clean embedtext; then
  `customkb query --context-only --categories <cat>` returns the stamped
  doc and excludes the plain one.
- shellcheck on every modified file; bcscheck on customkb +
  kb-import-staging-text.sh as the final gate (slow).
- `checkpoint -q` in /ai/scripts/customkb.bash BEFORE first edit (house
  rollback mechanism). NO git commits in either repo without explicit user
  approval.
- Full `kb-import-staging-text.sh` staging rebuild is deliberately LEFT TO
  THE USER (sudo self-escalation + full wipe of a shared build artifact);
  the plan verifies stamping against a temp directory instead.

## Out of scope

- Contextual chunk headers (prepending `[Title — Author, Year]` to
  embedtext) — a later, re-embed-costing enhancement.
- Backfilling categories for already-imported docs in appliedanthropology.db
  (a one-off UPDATE join; trivial once staging+ingest land, listed as a
  follow-up, not part of these changes).
- txt→md transcript conversion (user, later).
