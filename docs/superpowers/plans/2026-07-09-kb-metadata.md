# kb-metadata.sh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `workshops/kb-metadata.sh`, which extracts categories/author/title/year/src_url from `.md` corpus documents via one forced-tool-use Anthropic API call per document and upserts rows into `workshops/corpus-metadata.db` (SQLite, basename PK).

**Architecture:** Single BCS-compliant bash script adapted from `workshops/llm-categorize.sh` v1.2.0 (auth, sampling, messaging, CLI skeleton reused). Deterministic bash pre-pass (filename parse, URL grep) feeds hints into a prompt; the API's `tool_choice` forces a `record_metadata` tool call whose `input_schema` guarantees schema-valid JSON; bash validates categories/year and upserts via the sqlite3 CLI. Offline test suite stubs `curl`.

**Tech Stack:** Bash 5.2, jq, curl (Anthropic Messages API `2023-06-01`), sqlite3 3.45.

**Spec:** `docs/superpowers/specs/2026-07-09-kb-metadata-design.md` (approved). Read it before starting.

## Global Constraints

- BCS compliance (see `/usr/local/share/yatti/BCS/data/`): strict mode first, `while (($#)); do case $1 in … esac; shift; done` CLI loop, type-specific `declare`, descriptive heredoc delimiters, scripts end with `#fin`, 2-space indent.
- `set -e` arithmetic house style: `((i+=1))` never `((i++))`; `((!flag)) || cmd` never `((flag)) && cmd`; `[[ -z $x ]] || cmd` never `[[ -n $x ]] && cmd` as a statement.
- Git commits authored `Biksu-Okusi <biksu@okusi.id>`; NEVER mention "claude"/"cl" in messages; never commit `CLAUDE.md` or `.claude/`.
- ▲ The user has historically kept `workshops/*.sh` scripts **uncommitted**. Before the first commit step, ask the user whether these two files should be committed; if declined, skip ALL commit steps and leave the files untracked.
- `shellcheck` must pass on both files at the end of every task; `bcscheck` (slow, ~10–17 min) runs once in the final task.
- Never commit credentials. Tests use the fake key `test-key-not-real`.
- Model IDs (exact): haiku=`claude-haiku-4-5`, sonnet=`claude-sonnet-5`, opus=`claude-opus-4-8`. Default tier: sonnet.
- Default paths: topics `$SCRIPT_DIR/topics.list`, database `$SCRIPT_DIR/corpus-metadata.db`.
- Quiet-mode TSV column order (exact): `filename	categories	author	title	year	src_url`.

## File Structure

- `workshops/kb-metadata.sh` — the deliverable (single script; ~450 lines).
- `workshops/tests/test-kb-metadata.sh` — offline test suite (stub `curl`, no network, no credentials). Grows a section per task; every task ends by running the whole suite.

The suite sources the script with `KBMD_TEST_SOURCE=1` for unit tests (a guard on the `main "$@"` line makes the script source-safe) and executes it as a subprocess for integration tests.

---

### Task 1: Test harness scaffold + script skeleton (CLI, config, sampling)

**Files:**
- Create: `workshops/kb-metadata.sh`
- Create: `workshops/tests/test-kb-metadata.sh`

**Interfaces:**
- Produces (used by every later task):
  - Script globals: `VERSION=1.0.0`, `TOOL_SCHEMA` (JSON string), `MODELS[]`, `DEFAULT_TIER`, `TOPICS_FILE`, `DB_FILE`, `MODEL_TIER`, `MODEL_ID`, `VERBOSE`/`FORCE`/`DRY_RUN` (int flags), `FAIL_COUNT` (int), `_rv` (string return), `TOPIC_SET` (assoc), `QM_*` result globals, `FN_AUTHOR`/`FN_TITLE`/`FN_YEAR`.
  - Script functions: `_msg error warn info success die noarg usage timer_start timer_stop resolve_auth select_model collect_docs _emit_span _emit_elision _emit_char_sample sample_doc main`.
  - Source guard: `[[ ${KBMD_TEST_SOURCE:-} == 1 ]] || main "$@"`.
  - Harness helpers: `ok(desc)`, `bad(desc)`, `assert_eq(desc, expected, actual)`, `assert_match(desc, needle, haystack)`, `assert_rc(desc, expected, actual)`; `$TMP` (tmpdir), `$STUB_DIR` (stub bookkeeping: `calls` counter file, `last-body.json`, `response.json`), fixture corpus under `$TMP/corpus`, `$TMP/topics.list`.
- Consumes: `llm-categorize.sh` v1.2.0 as reference only (code is repeated below; do not source it).

- [ ] **Step 1: Write the test harness with Task-1 assertions (they must fail: script doesn't exist yet)**

Create `workshops/tests/test-kb-metadata.sh`:

```bash
#!/bin/bash
# test-kb-metadata.sh — offline test suite for kb-metadata.sh.
# Stubs curl with canned Anthropic responses: no network, no credentials.
# Run: ./tests/test-kb-metadata.sh
set -uo pipefail   # deliberately NOT -e: tests assert on failure exit codes

#shellcheck disable=SC2155
declare -r TESTS_DIR=$(realpath -- "${0%/*}")
declare -r SCRIPT=$TESTS_DIR/../kb-metadata.sh
declare -i PASS=0 FAIL=0

# Assertion helpers
ok()  { PASS+=1; printf '  \342\234\223 %s\n' "$1"; }
bad() { FAIL+=1; printf '  \342\234\227 %s\n' "$1"; }
assert_eq()    { if [[ $2 == "$3" ]]; then ok "$1"; else bad "$1 (expected ${2@Q}, got ${3@Q})"; fi; }
assert_match() { if [[ $3 == *"$2"* ]]; then ok "$1"; else bad "$1 (needle ${2@Q} not in ${3@Q})"; fi; }
assert_rc()    { if (( $2 == $3 )); then ok "$1"; else bad "$1 (expected rc $2, got rc $3)"; fi; }

# Sandbox
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
declare -rx STUB_DIR=$TMP/stub
declare -rx ANTHROPIC_API_KEY=test-key-not-real
mkdir -p "$STUB_DIR" "$TMP/bin" "$TMP/corpus" "$TMP/coll/a" "$TMP/coll/b"

# Stub curl: record request body, bump call counter, emit canned response
cat >"$TMP/bin/curl" <<'CURLSTUB'
#!/bin/bash
cat >"$STUB_DIR/last-body.json"
declare -i n=0
[[ -f $STUB_DIR/calls ]] && n=$(<"$STUB_DIR/calls")
echo $(( n + 1 )) >"$STUB_DIR/calls"
cat "$STUB_DIR/response.json"
CURLSTUB
chmod +x "$TMP/bin/curl"
export PATH=$TMP/bin:$PATH

# Fixture topics list (same format as workshops/topics.list)
cat >"$TMP/topics.list" <<'TOPICS'
# label | scope
alpha-topic | test scope a
beta-topic | test scope b
misc | No category found
TOPICS

# Fixture corpus
cat >"$TMP/corpus/Test-Author_Great-Work_2021.md" <<'DOC'
# Great Work

Test Author

A modest document about alpha things and beta things.
DOC
cat >"$TMP/corpus/plain-note.md" <<'DOC'
Just a note with no title header and no byline.
DOC
cat >"$TMP/corpus/url-doc.md" <<'DOC'
# A Video Transcript

Some Channel

https://www.youtube.com/watch?v=abc123xyz

Transcript body text.
DOC
cat >"$TMP/corpus/O'Brien_Quote-Test.md" <<'DOC'
# Quote Test

O'Brien

Body with 'quotes' everywhere.
DOC
echo '# X' >"$TMP/coll/a/x.md"
echo '# X' >"$TMP/coll/b/x.md"

# Source the script for unit tests (guard prevents main from running).
# The sourced strict mode turns -e on; turn it back off for the harness.
KBMD_TEST_SOURCE=1 source "$SCRIPT"
set +e

# ---- Task 1: CLI and structure ------------------------------------------
printf '\n== CLI and structure ==\n'

out=$("$SCRIPT" -V 2>&1); rc=$?
assert_rc 'version exits 0' 0 "$rc"
assert_eq 'version format' 'kb-metadata.sh 1.0.0' "$out"

out=$("$SCRIPT" -h 2>&1); rc=$?
assert_rc 'help exits 0' 0 "$rc"
assert_match 'help shows usage' 'Usage:' "$out"

out=$("$SCRIPT" -Z 2>&1); rc=$?
assert_rc 'invalid option rc 22' 22 "$rc"

out=$("$SCRIPT" -m bogus -t "$TMP/topics.list" "$TMP/corpus/plain-note.md" 2>&1); rc=$?
assert_rc 'unknown model tier rc 22' 22 "$rc"

out=$("$SCRIPT" -t "$TMP/nonexistent.list" "$TMP/corpus/plain-note.md" 2>&1); rc=$?
assert_rc 'missing topics rc 3' 3 "$rc"

out=$("$SCRIPT" -t "$TMP/topics.list" 2>&1); rc=$?
assert_rc 'no input documents rc 2' 2 "$rc"

select_model ''
assert_eq 'default tier is sonnet' 'sonnet' "$MODEL_TIER"
assert_eq 'default model id' 'claude-sonnet-5' "$MODEL_ID"

# ==== [append new test sections above this summary] =======================
printf '\nPASS: %d  FAIL: %d\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
#fin
```

Then `chmod +x workshops/tests/test-kb-metadata.sh`.

- [ ] **Step 2: Run the suite to verify it fails**

Run: `cd /var/lib/vectordbs/appliedanthropology/workshops && ./tests/test-kb-metadata.sh`
Expected: FAIL — `source` of a nonexistent `kb-metadata.sh` errors out (exit non-zero).

- [ ] **Step 3: Create the script skeleton**

Create `workshops/kb-metadata.sh` (complete file):

```bash
#!/bin/bash
# kb-metadata.sh — Extract corpus metadata (categories, author, title, year,
# src_url) from .md documents via one Anthropic API call per document, and
# upsert rows into a SQLite database keyed by basename.
#
# Design spec: docs/superpowers/specs/2026-07-09-kb-metadata-design.md
# Template:    llm-categorize.sh v1.2.0 (auth, sampling, messaging reused).
#
# Usage:
#   ./kb-metadata.sh [-t topics.list] [-d corpus-metadata.db] [-m tier]
#                    [-f] [-n] [-q] file-or-dir [...]
set -euo pipefail
shopt -s inherit_errexit

# Script metadata
declare -r VERSION=1.0.0
#shellcheck disable=SC2155
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*} SCRIPT_NAME=${SCRIPT_PATH##*/}

# Configuration
declare -r API_URL='https://api.anthropic.com/v1/messages'
declare -r API_VERSION='2023-06-01'
declare -ir MAX_TOKENS=1024
# Character budget for the document body. Files larger than this are sampled
# head/middle/tail (~4 chars/token). Override via env; 0 sends whole files.
declare -ir SAMPLE_BUDGET="${SAMPLE_BUDGET:-16000}"
# tier:model_id
declare -ra MODELS=(
  'haiku:claude-haiku-4-5'
  'sonnet:claude-sonnet-5'
  'opus:claude-opus-4-8'
)
declare -r DEFAULT_TIER=sonnet

# Output contract for the forced tool call. The API validates the model's
# output against this schema server-side, so the response is always
# schema-valid JSON — no text parsing. src_url is deliberately absent: it is
# bash-extracted only (a model could only fabricate a URL the file lacks).
declare -r TOOL_SCHEMA='{
  "name": "record_metadata",
  "description": "Record catalogue metadata extracted from the document.",
  "input_schema": {
    "type": "object",
    "properties": {
      "categories": {
        "type": "array", "minItems": 1, "maxItems": 4,
        "items": {"type": "string"},
        "description": "1-4 category labels from the provided list, best fit first, exact label names."
      },
      "title":  {"type": "string", "description": "Canonical title of the work; empty string if undeterminable."},
      "author": {"type": "string", "description": "Author name(s) comma-separated; a channel name for video transcripts; empty string rather than a guess."},
      "year":   {"type": "string", "description": "Year of first publication of the work (upload year for transcripts), e.g. 2021; empty string if unknown."},
      "title_src":  {"type": "string", "enum": ["text", "filename", "knowledge", ""]},
      "author_src": {"type": "string", "enum": ["text", "filename", "knowledge", ""]},
      "year_src":   {"type": "string", "enum": ["text", "filename", "knowledge", ""]}
    },
    "required": ["categories", "title", "author", "year", "title_src", "author_src", "year_src"]
  }
}'

# Runtime state
declare -i VERBOSE=1 FORCE=0 DRY_RUN=0
declare -- TOPICS_FILE='' DB_FILE=''
declare -- MODEL_TIER='' MODEL_ID=''
declare -a AUTH_HEADER=()     # curl auth arguments, set by resolve_auth()
declare -A TOPIC_SET=()       # valid category labels, set by load_topics()
declare -i FAIL_COUNT=0       # documents that failed this run
declare -- _rv=''             # generic fork-free function return value
declare -i _T0=0              # stopwatch epoch, microseconds
# query_model() results (fork-free returns; QM_ERR non-empty on failure)
declare -- QM_ERR=''
declare -- QM_CATS='' QM_TITLE='' QM_AUTHOR='' QM_YEAR=''
declare -- QM_TSRC='' QM_ASRC='' QM_YSRC=''
declare -i QM_IN=0 QM_OUT=0
# parse_filename() hint results ('' = no convention match)
declare -- FN_AUTHOR='' FN_TITLE='' FN_YEAR=''

# Messaging functions
if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi
_msg()    { >&2 printf '%s: %s %s\n' "$SCRIPT_NAME" "$1" "${*:2}"; }
error()   { _msg "$RED✗$NC" "$@"; }
warn()    { _msg "$YELLOW▲$NC" "$@"; }
info()    { ((VERBOSE)) || return 0; _msg "$CYAN◉$NC" "$@"; }
success() { ((VERBOSE)) || return 0; _msg "$GREEN✓$NC" "$@"; }
die()     { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }
noarg()   { (($# > 1)) || die 22 "Option ${1@Q} requires an argument"; }

usage() {
  cat <<USAGE
$SCRIPT_NAME $VERSION
Extract corpus metadata (categories, author, title, year, src_url) from .md
documents into a SQLite database, using one Anthropic API call per document.

Usage: $SCRIPT_NAME [OPTIONS] file-or-dir [file-or-dir ...]

Each document gets one row in the metadata table, keyed by basename.
Documents already in the database are skipped (runs are resumable);
use -f to re-extract.

Arguments:
  file-or-dir ...    One or more .md files, shell globs (e.g. *.md), or
                     directories (recursed for *.md). At least one required.

Options:
  -t, --topics FILE  Category list (default: $SCRIPT_DIR/topics.list)
  -d, --db FILE      SQLite database (default: $SCRIPT_DIR/corpus-metadata.db)
  -m, --model TIER   haiku|sonnet|opus (default: $DEFAULT_TIER)
  -f, --force        Re-extract documents already in the database
  -n, --dry-run      Extract and print, but write nothing to the database
  -v, --verbose      Full per-document report (default)
  -q, --quiet        One TSV line per document to stdout:
                     filename, categories, author, title, year, src_url
                     (tab-separated); errors still go to stderr.
  -V, --version      Print version and exit
  -h, --help         Print this help and exit

Large documents are sampled head/middle/tail down to SAMPLE_BUDGET characters
(default 16000, ~4K tokens). SAMPLE_BUDGET=0 always sends the whole file.

Credentials: uses \$ANTHROPIC_API_KEY if set, otherwise an active
ant auth login profile (via: ant auth print-credentials).
USAGE
}

# Stopwatch: EPOCHREALTIME is "sec.usec"; strip the locale decimal separator
# (. or ,) to get integer microseconds.
timer_start() { _T0=${EPOCHREALTIME//[.,]/}; }
timer_stop() {
  local -i us=$(( ${EPOCHREALTIME//[.,]/} - _T0 ))
  printf -v _rv '%d.%02d' $(( us / 1000000 )) $(( us % 1000000 / 10000 ))
}

# Resolve API credentials, preferring an explicit key over an OAuth profile.
resolve_auth() {
  local -- token
  if [[ -n ${ANTHROPIC_API_KEY:-} ]]; then
    AUTH_HEADER=(-H "x-api-key: $ANTHROPIC_API_KEY")
  elif command -v ant &>/dev/null \
       && token="$(ant auth print-credentials --access-token 2>/dev/null)" \
       && [[ -n $token ]]; then
    AUTH_HEADER=(-H "Authorization: Bearer $token" \
                 -H 'anthropic-beta: oauth-2025-04-20')
  else
    die 1 'no credentials: set ANTHROPIC_API_KEY or run: ant auth login'
  fi
}

# Resolve one requested tier ('' = DEFAULT_TIER) into MODEL_TIER/MODEL_ID.
select_model() {
  local -- want=${1:-$DEFAULT_TIER} entry
  for entry in "${MODELS[@]}"; do
    if [[ ${entry%%:*} == "$want" ]]; then
      MODEL_TIER=$want MODEL_ID=${entry#*:}
      return 0
    fi
  done
  die 22 "unknown model ${want@Q} (choose: haiku, sonnet, opus)"
}

# Expand positional targets (files, globs, directories) into a NUL-delimited
# document list on stdout. Directories are recursed for *.md; missing targets warn.
collect_docs() {
  local -- target
  local -a found=()
  for target in "$@"; do
    if [[ -d $target ]]; then
      # Guard find against option injection from '-'-leading directory names
      # (find has no reliable '--' support; bfs/GNU parse '-x' as an expression).
      [[ $target == -* ]] && target=./$target
      found=()
      mapfile -d '' -t found < <(find "$target" -type f -name '*.md' -print0 | sort -z)
      (( ${#found[@]} )) || { warn "no .md files under ${target@Q}"; continue; }
      printf '%s\0' "${found[@]}"
    elif [[ -f $target ]]; then
      printf '%s\0' "$target"
    else
      warn "not a file or directory: ${target@Q}"
    fi
  done
}

# Helpers for sample_doc(). Bash locals are dynamically scoped, so these read
# the caller's paras[] array directly.
_emit_span() {  # $1=from $2=to(exclusive) — print whole paragraphs
  local -i i
  for (( i = $1; i < $2; i+=1 )); do printf '%s\n\n' "${paras[i]}"; done
}
_emit_elision() {  # $1=paragraph count skipped (no-op when 0)
  (( $1 > 0 )) && printf '[... %d paragraph(s) elided ...]\n\n' "$1" ||:
}
# Character-level head/middle/tail of a string, guaranteeing <= budget chars.
# Used when paragraphs are too coarse to honour the budget. Args: content, budget.
_emit_char_sample() {
  local -- content=$1
  local -i budget=$2 len=${#content}
  local -i h=$(( budget * 60 / 100 )) m=$(( budget * 20 / 100 ))
  local -i t=$(( budget - h - m )) off=$(( (len - m) / 2 ))
  printf '%s\n\n[... content elided ...]\n\n%s\n\n[... content elided ...]\n\n%s\n' \
    "${content:0:h}" "${content:off:m}" "${content:len-t}"
}

# Emit the document body, sampling head/middle/tail when it exceeds `budget`
# characters. Whole paragraphs are preferred, but a single paragraph larger
# than its budget slice would blow the budget (and the argv limit), so when
# the whole-paragraph selection captures too little we fall back to character
# sampling. A budget of 0 always emits the whole file. Skipped spans are
# marked so the model knows it is seeing a sample.
sample_doc() {
  local -- file=$1
  local -i budget=$2
  (( budget <= 0 )) && { cat -- "$file"; return; }

  local -- content; content=$(<"$file")
  local -i len=${#content}
  (( len <= budget )) && { printf '%s\n' "$content"; return; }

  # Split on blank lines (awk paragraph mode); NUL-delimit so paragraphs with
  # internal newlines survive into the array. Drop any empty records.
  local -a raw=() paras=()
  mapfile -d '' -t raw < <(awk 'BEGIN{RS="";ORS="\0"}{print}' "$file")
  local -- p
  for p in "${raw[@]}"; do
    [[ -z $p ]] || paras+=("$p")
  done
  local -i n=${#paras[@]}

  # Budget split 60/20/20 across head/middle/tail.
  local -i head_b=$(( budget * 60 / 100 ))
  local -i mid_b=$(( budget * 20 / 100 ))
  local -i tail_b=$(( budget - head_b - mid_b ))

  # Select whole paragraphs per region WITHOUT exceeding that region's budget:
  # head [0,hi), tail [ti,n), middle [ms,me) centred in the remaining gap.
  local -i i acc hi ti ms me
  acc=0; hi=0
  while (( hi < n )) && (( acc + ${#paras[hi]} <= head_b )); do
    acc+=${#paras[hi]}; hi+=1
  done
  acc=0; ti=$n
  while (( ti > hi )) && (( acc + ${#paras[ti-1]} <= tail_b )); do
    ti=$(( ti - 1 )); acc+=${#paras[ti]}
  done
  ms=$hi; me=$hi
  if (( hi < ti )); then
    ms=$(( (hi + ti) / 2 )); me=$ms; acc=0
    while (( me < ti )) && (( acc + ${#paras[me]} <= mid_b )); do
      acc+=${#paras[me]}; me+=1
    done
  fi

  # If whole-paragraph selection captured a meaningful share of the budget,
  # use it. Otherwise paragraphs are too coarse (one exceeds a region) — fall
  # back to character sampling, which always honours the budget.
  local -i got=0
  for (( i = 0;  i < hi; i+=1 )); do got+=${#paras[i]}; done
  for (( i = ms; i < me; i+=1 )); do got+=${#paras[i]}; done
  for (( i = ti; i < n;  i+=1 )); do got+=${#paras[i]}; done
  if (( got < budget / 2 )); then
    _emit_char_sample "$content" "$budget"
    return
  fi

  _emit_span 0 "$hi"
  _emit_elision $(( ms - hi ))
  _emit_span "$ms" "$me"
  _emit_elision $(( ti - me ))
  _emit_span "$ti" "$n"
}

main() {
  local -a FILES=()
  local -- selected=''
  TOPICS_FILE="$SCRIPT_DIR"/topics.list
  DB_FILE="$SCRIPT_DIR"/corpus-metadata.db

  # Standard BCS command-line loop (BCS0801)
  while (($#)); do case $1 in
    -t|--topics)    noarg "$@"; shift; TOPICS_FILE=$1 ;;
    -d|--db)        noarg "$@"; shift; DB_FILE=$1 ;;
    -m|--model)     noarg "$@"; shift; selected=$1 ;;
    -f|--force)     FORCE=1 ;;
    -n|--dry-run)   DRY_RUN=1 ;;
    -v|--verbose)   VERBOSE=1 ;;
    -q|--quiet)     VERBOSE=0 ;;
    -V|--version)   printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"; exit 0 ;;
    -h|--help)      usage; exit 0 ;;
    --)             shift; FILES+=("$@"); break ;;
    -[tdmfnvqVh]?*) set -- "${1:0:2}" "-${1:2}" "${@:2}"; continue ;;
    -*)             die 22 "Invalid option ${1@Q}" ;;
    *)              FILES+=("$1") ;;
  esac; shift; done
  # Guard sqlite3 against option-like database paths
  [[ $DB_FILE != -* ]] || DB_FILE=./$DB_FILE
  readonly VERBOSE FORCE DRY_RUN
  readonly -- TOPICS_FILE DB_FILE
  readonly -a FILES

  command -v jq      &>/dev/null || die 18 'jq is required'
  command -v curl    &>/dev/null || die 18 'curl is required'
  command -v sqlite3 &>/dev/null || die 18 'sqlite3 is required'
  [[ -f $TOPICS_FILE ]] || die 3 "topics list not found: ${TOPICS_FILE@Q}"
  ((${#FILES[@]})) || die 2 'no input documents specified (see --help)'

  select_model "$selected"
  readonly -- MODEL_TIER MODEL_ID
  load_topics

  # Resolve positional targets (files/globs/dirs) into a concrete document list.
  local -a docs=()
  mapfile -d '' -t docs < <(collect_docs "${FILES[@]}")
  ((${#docs[@]})) || die 2 'no documents to process'

  # In-run basename collision check: basename is the DB primary key, so two
  # different paths with one basename would silently overwrite each other.
  local -- doc base
  local -A seen_base=()
  for doc in "${docs[@]}"; do
    base=${doc##*/}
    [[ -z ${seen_base[$base]:-} ]] \
      || die 1 "basename collision: ${doc@Q} vs ${seen_base[$base]@Q} (filename is the primary key)"
    seen_base[$base]=$doc
  done

  resolve_auth
  ((DRY_RUN)) || db_init

  local -- run_note=''
  ((!DRY_RUN)) || run_note=' (dry-run: no database writes)'
  info "extracting metadata for ${#docs[@]} document(s) using $MODEL_TIER$run_note"

  for doc in "${docs[@]}"; do
    process_doc "$doc"
  done

  if ((FAIL_COUNT)); then
    error "$FAIL_COUNT document(s) failed (re-run to retry; successes are stored)"
    exit 1
  fi
  success 'done'
}

[[ ${KBMD_TEST_SOURCE:-} == 1 ]] || main "$@"

#fin
```

Then `chmod +x workshops/kb-metadata.sh`.

Note: `main` references `load_topics`, `db_init`, and `process_doc`, which Tasks 3, 4, and 6 define. Bash resolves function names at call time, so every Task-1 test path (which dies before reaching them) works now.

- [ ] **Step 4: Run the suite to verify Task-1 assertions pass**

Run: `cd /var/lib/vectordbs/appliedanthropology/workshops && ./tests/test-kb-metadata.sh`
Expected: `PASS: 10  FAIL: 0`, exit 0.

- [ ] **Step 5: shellcheck both files**

Run: `shellcheck workshops/kb-metadata.sh workshops/tests/test-kb-metadata.sh`
Expected: no output (clean). If SC2317 (unreachable) fires on sourced-only functions in the harness context, it is a false positive — but expect clean as written.

- [ ] **Step 6: Commit (only if the user approved committing these files — see Global Constraints)**

```bash
cd /var/lib/vectordbs/appliedanthropology
git add workshops/kb-metadata.sh workshops/tests/test-kb-metadata.sh
git -c user.name='Biksu-Okusi' -c user.email='biksu@okusi.id' \
  commit -m 'feat(workshops): add kb-metadata.sh skeleton with offline test harness'
```

---

### Task 2: Filename and content pre-pass (parse_filename, extract_src_url)

**Files:**
- Modify: `workshops/kb-metadata.sh` (insert the two functions immediately AFTER the `sample_doc()` function, before `main()`)
- Modify: `workshops/tests/test-kb-metadata.sh` (insert section above the `[append new test sections above this summary]` marker)

**Interfaces:**
- Produces: `parse_filename(basename)` — sets globals `FN_AUTHOR`, `FN_TITLE`, `FN_YEAR` (all `''` when the basename doesn't match the `{author}_{title}[_{subtitle}][_{year}]` convention). `extract_src_url(file)` — sets `_rv` to the first http(s) URL in the first 30 lines, `''` when none.
- Consumes: `_rv` convention from Task 1.

- [ ] **Step 1: Add failing unit tests**

Insert into the harness above the summary marker:

```bash
# ---- Task 2: filename and content pre-pass -------------------------------
printf '\n== pre-pass ==\n'

parse_filename 'Test-Author_Great-Work_2021.md'
assert_eq 'fn author'     'Test Author' "$FN_AUTHOR"
assert_eq 'fn title'      'Great Work'  "$FN_TITLE"
assert_eq 'fn year'       '2021'        "$FN_YEAR"

parse_filename 'Dr-Aidan_Good-People_Machiavellis-Prince.md'
assert_eq 'fn subtitle joined' 'Good People: Machiavellis Prince' "$FN_TITLE"

parse_filename 'Josh-Chin+Liza-Lin_Surveillance-State.md'
assert_eq 'fn multi-author' 'Josh Chin, Liza Lin' "$FN_AUTHOR"
assert_eq 'fn no year'      ''                    "$FN_YEAR"

parse_filename 'plain-note.md'
assert_eq 'fn no convention: author blank' '' "$FN_AUTHOR"
assert_eq 'fn no convention: title blank'  '' "$FN_TITLE"

extract_src_url "$TMP/corpus/url-doc.md"
assert_eq 'src_url found' 'https://www.youtube.com/watch?v=abc123xyz' "$_rv"

extract_src_url "$TMP/corpus/plain-note.md"
assert_eq 'src_url absent' '' "$_rv"
```

- [ ] **Step 2: Run suite — new assertions must fail**

Run: `./tests/test-kb-metadata.sh`
Expected: Task-1 assertions pass; the new section errors ("command not found: parse_filename" surfaces as bad assertions or shell errors), `FAIL > 0` or non-zero exit.

- [ ] **Step 3: Implement the two functions**

Insert after `sample_doc()` in `workshops/kb-metadata.sh`:

```bash
# Parse a basename against {author}_{title}[_{subtitle}][_{year}] into hint
# globals FN_AUTHOR/FN_TITLE/FN_YEAR (all '' when no convention match).
# Hints only: many filenames use _ as a word separator, not a delimiter, so
# the prompt tells the model to trust the document text over these.
parse_filename() {
  local -- stem=${1%.md}
  FN_AUTHOR='' FN_TITLE='' FN_YEAR=''
  [[ $stem == *_* ]] || return 0
  if [[ $stem =~ _([12][0-9]{3})$ ]]; then
    FN_YEAR=${BASH_REMATCH[1]}
    stem=${stem%_*}
    [[ $stem == *_* ]] || { FN_TITLE=${stem//-/ }; return 0; }
  fi
  FN_AUTHOR=${stem%%_*}
  local -- rest=${stem#*_}
  FN_AUTHOR=${FN_AUTHOR//+/, }    # A+B collaborations
  FN_AUTHOR=${FN_AUTHOR//-/ }
  FN_TITLE=${rest//_/: }          # further _ separates a subtitle
  FN_TITLE=${FN_TITLE//-/ }
}

# First http(s) URL in the first 30 lines of file $1. Sets _rv ('' if none).
extract_src_url() {
  local -- top='' re='https?://[^[:space:])>"'\'']+'
  top=$(head -n 30 -- "$1") ||:
  _rv=''
  [[ $top =~ $re ]] || return 0
  _rv=${BASH_REMATCH[0]}
  while [[ $_rv == *[.,\;] ]]; do _rv=${_rv%?}; done   # trim trailing punctuation
}
```

- [ ] **Step 4: Run suite — all pass**

Run: `./tests/test-kb-metadata.sh`
Expected: `PASS: 20  FAIL: 0`, exit 0.

- [ ] **Step 5: shellcheck, then commit**

Run: `shellcheck workshops/kb-metadata.sh workshops/tests/test-kb-metadata.sh` (clean), then:

```bash
cd /var/lib/vectordbs/appliedanthropology
git add workshops/kb-metadata.sh workshops/tests/test-kb-metadata.sh
git -c user.name='Biksu-Okusi' -c user.email='biksu@okusi.id' \
  commit -m 'feat(workshops): kb-metadata filename and src_url pre-pass'
```

---

### Task 3: Topics loading and validation (load_topics, validate_cats, validate_year)

**Files:**
- Modify: `workshops/kb-metadata.sh` (insert the three functions immediately AFTER `extract_src_url()`)
- Modify: `workshops/tests/test-kb-metadata.sh` (new section above the summary marker)

**Interfaces:**
- Produces: `load_topics()` — fills global assoc `TOPIC_SET` from `$TOPICS_FILE` (label = first `|`-field per non-`#` line; dies 3 when nothing parses). `validate_cats(comma_joined)` — sets `_rv`: unknown labels dropped (with `warn`), duplicates collapsed, empty result becomes `misc`. `validate_year(string)` — sets `_rv`: value kept only when it matches `^-?[0-9]{1,4}$`, else `''`.
- Consumes: `TOPIC_SET`, `TOPICS_FILE`, `warn`, `die`, `_rv` from Task 1.

- [ ] **Step 1: Add failing unit tests**

```bash
# ---- Task 3: topics and validation ----------------------------------------
printf '\n== validation ==\n'

TOPICS_FILE=$TMP/topics.list
load_topics
assert_eq 'topics parsed' '3' "${#TOPIC_SET[@]}"

validate_cats 'alpha-topic, bogus-cat'
assert_eq 'unknown category dropped' 'alpha-topic' "$_rv"

validate_cats 'nope-1,nope-2' 2>/dev/null
assert_eq 'all unknown falls back to misc' 'misc' "$_rv"

validate_cats 'beta-topic,beta-topic,alpha-topic'
assert_eq 'duplicates collapsed, order kept' 'beta-topic,alpha-topic' "$_rv"

validate_cats ''
assert_eq 'empty input becomes misc' 'misc' "$_rv"

validate_year '2021';        assert_eq 'year plain'    '2021' "$_rv"
validate_year '-375';        assert_eq 'year negative' '-375' "$_rv"
validate_year 'circa 2020';  assert_eq 'year fuzzy blanked' '' "$_rv"
validate_year '';            assert_eq 'year empty stays empty' '' "$_rv"
```

- [ ] **Step 2: Run suite — new assertions fail**

Run: `./tests/test-kb-metadata.sh`
Expected: previous 19 pass; new section fails/errors.

- [ ] **Step 3: Implement the three functions**

Insert after `extract_src_url()`:

```bash
# Load category labels (first |-field of each non-comment line) from
# TOPICS_FILE into TOPIC_SET. Dies when no labels parse.
load_topics() {
  local -- line label
  while IFS= read -r line; do
    [[ $line != '#'* ]] || continue
    label=${line%%|*}
    label=${label#"${label%%[![:space:]]*}"}   # trim leading whitespace
    label=${label%"${label##*[![:space:]]}"}   # trim trailing whitespace
    [[ -z $label ]] || TOPIC_SET[$label]=1
  done < "$TOPICS_FILE"
  ((${#TOPIC_SET[@]})) || die 3 "no category labels parsed from ${TOPICS_FILE@Q}"
}

# Validate a comma-joined category list against TOPIC_SET: unknowns dropped
# (warned), duplicates collapsed, empty result becomes 'misc'. Sets _rv.
validate_cats() {
  local -a parts=()
  local -A seen=()
  local -- cat out='' dropped=''
  IFS=',' read -r -a parts <<<"$1" ||:
  for cat in "${parts[@]}"; do
    cat=${cat#"${cat%%[![:space:]]*}"}
    cat=${cat%"${cat##*[![:space:]]}"}
    [[ -n $cat ]] || continue
    [[ -n ${TOPIC_SET[$cat]:-} ]] || { dropped+="${dropped:+,}$cat"; continue; }
    [[ -z ${seen[$cat]:-} ]] || continue
    seen[$cat]=1
    out+="${out:+,}$cat"
  done
  [[ -z $dropped ]] || warn "dropped unknown categor(y/ies): $dropped"
  _rv=${out:-misc}
}

# A year is a 1-4 digit number, optionally negative (ancient works); anything
# else — 'circa 2020', prose, ranges — is blanked. Sets _rv.
validate_year() {
  _rv=$1
  [[ $_rv =~ ^-?[0-9]{1,4}$ ]] || _rv=''
}
```

- [ ] **Step 4: Run suite — all pass**

Run: `./tests/test-kb-metadata.sh`
Expected: `PASS: 29  FAIL: 0`, exit 0.

- [ ] **Step 5: shellcheck, then commit**

shellcheck both files (clean), then:

```bash
cd /var/lib/vectordbs/appliedanthropology
git add workshops/kb-metadata.sh workshops/tests/test-kb-metadata.sh
git -c user.name='Biksu-Okusi' -c user.email='biksu@okusi.id' \
  commit -m 'feat(workshops): kb-metadata topics loading and field validation'
```

---

### Task 4: Database layer (sql_escape, db_init, db_has, db_upsert)

**Files:**
- Modify: `workshops/kb-metadata.sh` (insert the four functions immediately AFTER `validate_year()`)
- Modify: `workshops/tests/test-kb-metadata.sh` (new section above the summary marker)

**Interfaces:**
- Produces:
  - `sql_escape(string)` — sets `_rv` with `'` doubled for SQL string literals.
  - `db_init()` — creates the `metadata` table in `$DB_FILE` (idempotent); dies 5 on failure.
  - `db_has(basename)` — returns 0 when a row exists for that filename.
  - `db_upsert(filename filepath categories author title year src_url author_src title_src year_src model)` — exactly 11 args in that order; `updated_at` stamped by SQLite in UTC; dies 5 on write failure.
- Consumes: `DB_FILE`, `_rv`, `die` from Task 1.

- [ ] **Step 1: Add failing unit tests**

```bash
# ---- Task 4: database layer ------------------------------------------------
printf '\n== database ==\n'

sql_escape "O'Brien's"
assert_eq 'sql_escape doubles quotes' "O''Brien''s" "$_rv"

DB_FILE=$TMP/unit.db
db_init
out=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' AND name='metadata';")
assert_eq 'db_init creates table' 'metadata' "$out"
db_init
assert_rc 'db_init idempotent' 0 $?

db_has 'nope.md'
assert_rc 'db_has misses absent row' 1 $?

db_upsert "O'Brien_Quote-Test.md" "corpus/O'Brien_Quote-Test.md" 'alpha-topic' \
  "O'Brien" 'Quote Test' '2020' '' 'text' 'text' 'knowledge' 'claude-sonnet-5'
db_has "O'Brien_Quote-Test.md"
assert_rc 'db_has finds inserted row' 0 $?
out=$(sqlite3 "$DB_FILE" "SELECT author FROM metadata WHERE title='Quote Test';")
assert_eq 'hostile quotes stored intact' "O'Brien" "$out"

db_upsert "O'Brien_Quote-Test.md" "corpus/O'Brien_Quote-Test.md" 'beta-topic' \
  "O'Brien" 'Quote Test' '2021' '' 'text' 'text' 'text' 'claude-opus-4-8'
out=$(sqlite3 "$DB_FILE" "SELECT COUNT(*), year, model FROM metadata;")
assert_eq 'upsert overwrites, one row' "1|2021|claude-opus-4-8" "$out"
out=$(sqlite3 "$DB_FILE" "SELECT updated_at FROM metadata;")
assert_match 'updated_at is ISO-8601 UTC' 'T' "$out"
```

- [ ] **Step 2: Run suite — new assertions fail**

Run: `./tests/test-kb-metadata.sh`
Expected: previous 28 pass; new section errors.

- [ ] **Step 3: Implement the DB layer**

Insert after `validate_year()`:

```bash
# SQL string-literal escape: double every single quote. Sets _rv.
sql_escape() { _rv=${1//\'/\'\'}; }

# Create the metadata table (idempotent). Schema per the design spec:
# six user-facing fields + provenance/audit columns.
db_init() {
  sqlite3 "$DB_FILE" <<'SQL' || die 5 "cannot initialise database ${DB_FILE@Q}"
CREATE TABLE IF NOT EXISTS metadata (
  filename   TEXT PRIMARY KEY,
  filepath   TEXT NOT NULL,
  categories TEXT NOT NULL,
  author     TEXT DEFAULT '',
  title      TEXT DEFAULT '',
  year       TEXT DEFAULT '',
  src_url    TEXT DEFAULT '',
  author_src TEXT DEFAULT '',
  title_src  TEXT DEFAULT '',
  year_src   TEXT DEFAULT '',
  model      TEXT DEFAULT '',
  updated_at TEXT DEFAULT ''
);
SQL
}

# True when a row exists for basename $1.
db_has() {
  local -- q
  sql_escape "$1"; q=$_rv
  [[ -n $(sqlite3 "$DB_FILE" "SELECT 1 FROM metadata WHERE filename='$q' LIMIT 1;") ]]
}

# Upsert one row. Args (11, in column order): filename filepath categories
# author title year src_url author_src title_src year_src model.
# updated_at is stamped UTC by SQLite.
db_upsert() {
  local -a v=()
  local -- arg
  for arg in "$@"; do
    sql_escape "$arg"
    v+=("'$_rv'")
  done
  sqlite3 "$DB_FILE" "
    INSERT INTO metadata (filename, filepath, categories, author, title, year,
                          src_url, author_src, title_src, year_src, model, updated_at)
    VALUES (${v[0]}, ${v[1]}, ${v[2]}, ${v[3]}, ${v[4]}, ${v[5]},
            ${v[6]}, ${v[7]}, ${v[8]}, ${v[9]}, ${v[10]},
            strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    ON CONFLICT(filename) DO UPDATE SET
      filepath   = excluded.filepath,
      categories = excluded.categories,
      author     = excluded.author,
      title      = excluded.title,
      year       = excluded.year,
      src_url    = excluded.src_url,
      author_src = excluded.author_src,
      title_src  = excluded.title_src,
      year_src   = excluded.year_src,
      model      = excluded.model,
      updated_at = excluded.updated_at;" \
    || die 5 "database write failed for ${1@Q}"
}
```

▲ Note the die message inside `db_init` uses `${DB_FILE@Q}` on the command line (before the heredoc body), which is valid bash.

- [ ] **Step 4: Run suite — all pass**

Run: `./tests/test-kb-metadata.sh`
Expected: `PASS: 37  FAIL: 0`, exit 0.

- [ ] **Step 5: shellcheck, then commit**

shellcheck both files (clean), then:

```bash
cd /var/lib/vectordbs/appliedanthropology
git add workshops/kb-metadata.sh workshops/tests/test-kb-metadata.sh
git -c user.name='Biksu-Okusi' -c user.email='biksu@okusi.id' \
  commit -m 'feat(workshops): kb-metadata sqlite layer with upsert'
```

---

### Task 5: Prompt assembly and forced-tool query (build_prompt, query_model)

**Files:**
- Modify: `workshops/kb-metadata.sh` (insert the two functions immediately AFTER `db_upsert()`)
- Modify: `workshops/tests/test-kb-metadata.sh` (new section above the summary marker)

**Interfaces:**
- Produces:
  - `build_prompt(doc_file)` — prints the full prompt to stdout: extraction rules, topics list (`$TOPICS_FILE`), basename, `FN_*` hints (caller must run `parse_filename` first), sampled document body.
  - `query_model(prompt)` — returns 0 with `QM_CATS QM_TITLE QM_AUTHOR QM_YEAR QM_TSRC QM_ASRC QM_YSRC QM_IN QM_OUT` set, or 1 with `QM_ERR` set. Uses `MODEL_ID`, `AUTH_HEADER`, `TOOL_SCHEMA`. Payloads stay off argv (`jq --rawfile` + `curl --data-binary @-`, MAX_ARG_STRLEN is 128KB).
- Consumes: `sample_doc`, `TOOL_SCHEMA`, `MODEL_ID`, `AUTH_HEADER`, `FN_*` globals, `QM_*` globals from earlier tasks.

- [ ] **Step 1: Add failing unit tests**

```bash
# ---- Task 5: prompt and query ----------------------------------------------
printf '\n== prompt and query ==\n'

parse_filename 'Test-Author_Great-Work_2021.md'
out=$(build_prompt "$TMP/corpus/Test-Author_Great-Work_2021.md")
assert_match 'prompt has categories section' '--- CATEGORIES ---' "$out"
assert_match 'prompt has topic labels'       'alpha-topic'        "$out"
assert_match 'prompt has filename'           'Test-Author_Great-Work_2021.md' "$out"
assert_match 'prompt has author hint'        'author: Test Author' "$out"
assert_match 'prompt has document body'      'alpha things'        "$out"

# Canned good response for the stub
cat >"$STUB_DIR/response.json" <<'RESPONSE'
{"id":"msg_test","type":"message","role":"assistant","stop_reason":"tool_use",
 "usage":{"input_tokens":1234,"output_tokens":56},
 "content":[{"type":"tool_use","id":"tu_1","name":"record_metadata",
   "input":{"categories":["alpha-topic","beta-topic"],"title":"Great Work",
            "author":"Test Author","year":"2021",
            "title_src":"text","author_src":"filename","year_src":"knowledge"}}]}
RESPONSE

MODEL_ID='claude-sonnet-5'
AUTH_HEADER=(-H 'x-api-key: test-key-not-real')
query_model 'test prompt content'
assert_rc 'query_model succeeds' 0 $?
assert_eq 'qm categories' 'alpha-topic,beta-topic' "$QM_CATS"
assert_eq 'qm title'  'Great Work'  "$QM_TITLE"
assert_eq 'qm author' 'Test Author' "$QM_AUTHOR"
assert_eq 'qm year'   '2021'        "$QM_YEAR"
assert_eq 'qm srcs'   'text/filename/knowledge' "$QM_TSRC/$QM_ASRC/$QM_YSRC"
assert_eq 'qm tokens' '1234/56' "$QM_IN/$QM_OUT"

out=$(jq -r '.tool_choice.name' "$STUB_DIR/last-body.json")
assert_eq 'body forces record_metadata' 'record_metadata' "$out"
out=$(jq -r '.model' "$STUB_DIR/last-body.json")
assert_eq 'body model id' 'claude-sonnet-5' "$out"
out=$(jq -r '.tools[0].input_schema.required | length' "$STUB_DIR/last-body.json")
assert_eq 'body schema requires 7 fields' '7' "$out"
out=$(jq -r '.messages[0].content' "$STUB_DIR/last-body.json")
assert_eq 'body carries the prompt' 'test prompt content' "$out"

# API error response
cat >"$STUB_DIR/response.json" <<'RESPONSE'
{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}
RESPONSE
query_model 'test prompt content'
assert_rc 'query_model fails on API error' 1 $?
assert_eq 'qm error message' 'Overloaded' "$QM_ERR"

# Response with no tool_use block
cat >"$STUB_DIR/response.json" <<'RESPONSE'
{"type":"message","usage":{"input_tokens":1,"output_tokens":1},
 "content":[{"type":"text","text":"I refuse to call tools"}]}
RESPONSE
query_model 'test prompt content'
assert_rc 'query_model fails without tool_use' 1 $?
assert_eq 'qm no-tool error' 'no tool_use block in response' "$QM_ERR"
```

- [ ] **Step 2: Run suite — new assertions fail**

Run: `./tests/test-kb-metadata.sh`
Expected: previous 36 pass; new section errors.

- [ ] **Step 3: Implement the two functions**

Insert after `db_upsert()`:

```bash
# Assemble the extraction prompt: rules, category list, filename + parsed
# hints, and the (possibly sampled) document body. Caller must have run
# parse_filename for the same document first.
build_prompt() {
  local -- doc_file=$1 base=${doc_file##*/}
  cat <<'PROMPT'
You are extracting catalogue metadata for a document in a knowledgebase
corpus. Call the record_metadata tool with the extracted fields.

Field rules:
- categories: 1 to 4 labels from the CATEGORIES list below, best fit FIRST.
  Use label names exactly as listed. If more than one genuinely applies you
  MUST include the secondary ones. If nothing fits, use ["misc"].
- title: the canonical title of the work (book, article, essay, or video).
  Prefer the document text (H1, byline area) over the filename hint.
- author: the person(s) who authored the work, comma-separated. For video
  transcripts the channel name is acceptable.
- year: year of FIRST publication of the work (for video transcripts, the
  upload year), as a 1-4 digit string, e.g. "2021".
- The *_src fields state where each value came from: "text" (stated in the
  document), "filename" (from the filename hint), "knowledge" (your own
  knowledge of this specific work, only when you are certain of it).
- Accuracy over completeness: set a field to "" (and its *_src to "")
  rather than guess. A plausible wrong answer is worse than a blank.

The FILENAME HINTS below were parsed mechanically from the filename and are
unreliable — many filenames do not follow the author_title_year convention.
Trust the document text over the hints.

--- CATEGORIES ---
PROMPT
  cat -- "$TOPICS_FILE"
  printf '\n--- FILENAME ---\n%s\n\n' "$base"
  printf -- '--- FILENAME HINTS (unreliable) ---\nauthor: %s\ntitle: %s\nyear: %s\n' \
    "${FN_AUTHOR:-?}" "${FN_TITLE:-?}" "${FN_YEAR:-?}"
  printf '\n--- DOCUMENT ---\n'
  sample_doc "$doc_file" "$SAMPLE_BUDGET"
}

# Query the model with a forced record_metadata tool call. Args: prompt.
# Returns 0 with QM_CATS/QM_TITLE/QM_AUTHOR/QM_YEAR/QM_*SRC/QM_IN/QM_OUT set,
# or 1 with QM_ERR set. One jq pass renders the response as unit-separator
# (US, 0x1f) delimited fields:
#   OK<US>in<US>out<US>cats<US>title<US>author<US>year<US>tsrc<US>asrc<US>ysrc
# or ERR<US>message. clean() strips separators/newlines from model strings so
# the record always splits correctly (and keeps TSV output single-line).
query_model() {
  local -- prompt=$1 body resp parsed
  QM_ERR='' QM_CATS='' QM_TITLE='' QM_AUTHOR='' QM_YEAR=''
  QM_TSRC='' QM_ASRC='' QM_YSRC=''
  QM_IN=0; QM_OUT=0

  # Pass the prompt via --rawfile (a pipe fd) and POST via stdin: both keep
  # large payloads off argv (MAX_ARG_STRLEN caps one argument at 128 KB).
  body="$(jq -n --arg m "$MODEL_ID" --argjson mt "$MAX_TOKENS" \
    --argjson tool "$TOOL_SCHEMA" \
    --rawfile p <(printf '%s' "$prompt") \
    '{model:$m, max_tokens:$mt, tools:[$tool],
      tool_choice:{type:"tool", name:"record_metadata"},
      messages:[{role:"user", content:$p}]}')" \
    || { QM_ERR='failed to build request body'; return 1; }

  resp="$(printf '%s' "$body" | curl -sS "$API_URL" \
    -H 'content-type: application/json' \
    -H "anthropic-version: $API_VERSION" \
    "${AUTH_HEADER[@]}" \
    --data-binary @-)" || { QM_ERR='curl request failed'; return 1; }

  local -- us=$'\x1f'
  parsed="$(jq -r --arg us "$us" '
    def clean: (. // "") | tostring | gsub("[\n\r\t]"; " ") | gsub($us; " ");
    if .type == "error" then
      ["ERR", ((.error.message // "unknown error") | clean)] | join($us)
    else
      ([.content[]? | select(.type == "tool_use") | .input][0]) as $in
      | if $in == null then ["ERR", "no tool_use block in response"] | join($us)
        else
          ["OK",
           ((.usage.input_tokens  // 0) | tostring),
           ((.usage.output_tokens // 0) | tostring),
           (($in.categories // []) | map(clean) | join(",")),
           ($in.title      | clean),
           ($in.author     | clean),
           ($in.year       | clean),
           ($in.title_src  | clean),
           ($in.author_src | clean),
           ($in.year_src   | clean)]
          | join($us)
        end
    end' <<<"$resp")" || { QM_ERR='unparseable API response'; return 1; }

  local -a f=()
  IFS=$us read -r -a f <<<"$parsed" ||:
  case ${f[0]:-} in
    OK)  QM_IN=${f[1]:-0}     QM_OUT=${f[2]:-0}
         QM_CATS=${f[3]:-}    QM_TITLE=${f[4]:-} QM_AUTHOR=${f[5]:-}
         QM_YEAR=${f[6]:-}    QM_TSRC=${f[7]:-}
         QM_ASRC=${f[8]:-}    QM_YSRC=${f[9]:-} ;;
    ERR) QM_ERR=${f[1]:-unknown error} ;;
    *)   QM_ERR='unexpected API response' ;;
  esac
  [[ -z $QM_ERR ]]
}
```

- [ ] **Step 4: Run suite — all pass**

Run: `./tests/test-kb-metadata.sh`
Expected: `PASS: 57  FAIL: 0`, exit 0.

- [ ] **Step 5: shellcheck, then commit**

shellcheck both files (clean), then:

```bash
cd /var/lib/vectordbs/appliedanthropology
git add workshops/kb-metadata.sh workshops/tests/test-kb-metadata.sh
git -c user.name='Biksu-Okusi' -c user.email='biksu@okusi.id' \
  commit -m 'feat(workshops): kb-metadata forced-tool query and prompt assembly'
```

---

### Task 6: Per-document orchestration (process_doc) + end-to-end integration

**Files:**
- Modify: `workshops/kb-metadata.sh` (insert `process_doc()` immediately AFTER `query_model()`, before `main()`)
- Modify: `workshops/tests/test-kb-metadata.sh` (new section above the summary marker)

**Interfaces:**
- Produces: `process_doc(doc_file)` — full per-document pipeline: skip-check → pre-pass → prompt → query → validate → upsert (unless `DRY_RUN`) → report (verbose) or TSV (quiet). Per-document failure warns, bumps `FAIL_COUNT`, returns 0 (a long run must never abort on one bad document).
- Consumes: everything from Tasks 1–5; called by `main()` (already wired in Task 1).

- [ ] **Step 1: Add failing integration tests**

```bash
# ---- Task 6: end-to-end integration -----------------------------------------
printf '\n== integration ==\n'

# Good response fixture back in place
cat >"$STUB_DIR/response.json" <<'RESPONSE'
{"id":"msg_test","type":"message","role":"assistant","stop_reason":"tool_use",
 "usage":{"input_tokens":1234,"output_tokens":56},
 "content":[{"type":"tool_use","id":"tu_1","name":"record_metadata",
   "input":{"categories":["alpha-topic","beta-topic"],"title":"Great Work",
            "author":"Test Author","year":"2021",
            "title_src":"text","author_src":"filename","year_src":"knowledge"}}]}
RESPONSE
rm -f "$STUB_DIR/calls"
DB=$TMP/int.db
echo 'Another plain note.' >"$TMP/corpus/plain-note2.md"

# Happy path: quiet TSV + DB row
out=$("$SCRIPT" -q -t "$TMP/topics.list" -d "$DB" \
  "$TMP/corpus/Test-Author_Great-Work_2021.md" 2>/dev/null); rc=$?
assert_rc 'happy path exits 0' 0 "$rc"
expected=$'Test-Author_Great-Work_2021.md\talpha-topic,beta-topic\tTest Author\tGreat Work\t2021\t'
assert_eq 'quiet TSV line' "$expected" "$out"
row=$(sqlite3 "$DB" "SELECT categories, author, title, year, title_src, model FROM metadata WHERE filename='Test-Author_Great-Work_2021.md';")
assert_eq 'db row written' 'alpha-topic,beta-topic|Test Author|Great Work|2021|text|claude-sonnet-5' "$row"
assert_eq 'one API call made' '1' "$(<"$STUB_DIR/calls")"

# Skip on re-run (resumability)
out=$("$SCRIPT" -q -t "$TMP/topics.list" -d "$DB" \
  "$TMP/corpus/Test-Author_Great-Work_2021.md" 2>&1); rc=$?
assert_rc 'skip run exits 0' 0 "$rc"
assert_eq 'skip run makes no API call' '1' "$(<"$STUB_DIR/calls")"

# Force re-extracts
"$SCRIPT" -q -f -t "$TMP/topics.list" -d "$DB" \
  "$TMP/corpus/Test-Author_Great-Work_2021.md" >/dev/null 2>&1
assert_eq 'force makes an API call' '2' "$(<"$STUB_DIR/calls")"

# Dry-run writes nothing
out=$("$SCRIPT" -q -n -t "$TMP/topics.list" -d "$TMP/dry.db" \
  "$TMP/corpus/plain-note.md" 2>/dev/null); rc=$?
assert_rc 'dry-run exits 0' 0 "$rc"
assert_match 'dry-run still prints TSV' $'\t' "$out"
[[ ! -e $TMP/dry.db ]]; assert_rc 'dry-run creates no db' 0 $?

# src_url column from bash pre-pass
"$SCRIPT" -q -t "$TMP/topics.list" -d "$DB" "$TMP/corpus/url-doc.md" >/dev/null 2>&1
row=$(sqlite3 "$DB" "SELECT src_url FROM metadata WHERE filename='url-doc.md';")
assert_eq 'src_url stored' 'https://www.youtube.com/watch?v=abc123xyz' "$row"

# Hostile filename end-to-end
"$SCRIPT" -q -t "$TMP/topics.list" -d "$DB" "$TMP/corpus/O'Brien_Quote-Test.md" >/dev/null 2>&1
row=$(sqlite3 "$DB" "SELECT filename FROM metadata WHERE filename LIKE 'O%';")
assert_eq 'hostile filename row' "O'Brien_Quote-Test.md" "$row"

# Unknown category dropped; all-unknown becomes misc; fuzzy year blanked
cat >"$STUB_DIR/response.json" <<'RESPONSE'
{"type":"message","usage":{"input_tokens":9,"output_tokens":9},
 "content":[{"type":"tool_use","id":"t","name":"record_metadata",
   "input":{"categories":["totally-bogus"],"title":"T","author":"A",
            "year":"circa 2020","title_src":"text","author_src":"text","year_src":"text"}}]}
RESPONSE
out=$("$SCRIPT" -q -f -t "$TMP/topics.list" -d "$DB" \
  "$TMP/corpus/plain-note.md" 2>/dev/null)
row=$(sqlite3 "$DB" "SELECT categories, year FROM metadata WHERE filename='plain-note.md';")
assert_eq 'bogus cat -> misc, fuzzy year blanked' 'misc|' "$row"

# API error: warn, no row, exit 1
cat >"$STUB_DIR/response.json" <<'RESPONSE'
{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}
RESPONSE
out=$("$SCRIPT" -q -t "$TMP/topics.list" -d "$DB" \
  "$TMP/corpus/plain-note2.md" 2>&1); rc=$?
assert_rc 'API error run exits 1' 1 "$rc"
assert_match 'API error reported' 'Overloaded' "$out"
row=$(sqlite3 "$DB" "SELECT COUNT(*) FROM metadata WHERE filename='plain-note2.md';")
assert_eq 'no row on API error' '0' "$row"

# Basename collision dies before any API call
rm -f "$STUB_DIR/calls"
out=$("$SCRIPT" -q -t "$TMP/topics.list" -d "$TMP/coll.db" "$TMP/coll" 2>&1); rc=$?
assert_rc 'collision dies rc 1' 1 "$rc"
assert_match 'collision names the problem' 'basename collision' "$out"
[[ ! -f $STUB_DIR/calls ]]; assert_rc 'collision made no API calls' 0 $?

# -m haiku reaches the request body
cat >"$STUB_DIR/response.json" <<'RESPONSE'
{"type":"message","usage":{"input_tokens":1,"output_tokens":1},
 "content":[{"type":"tool_use","id":"t","name":"record_metadata",
   "input":{"categories":["alpha-topic"],"title":"","author":"","year":"",
            "title_src":"","author_src":"","year_src":""}}]}
RESPONSE
"$SCRIPT" -q -f -m haiku -t "$TMP/topics.list" -d "$DB" \
  "$TMP/corpus/plain-note.md" >/dev/null 2>&1
out=$(jq -r '.model' "$STUB_DIR/last-body.json")
assert_eq 'haiku tier reaches body' 'claude-haiku-4-5' "$out"
```

- [ ] **Step 2: Run suite — new assertions fail**

Run: `./tests/test-kb-metadata.sh`
Expected: previous 55 pass; integration section fails (`process_doc: command not found` via stderr, bad assertions).

- [ ] **Step 3: Implement process_doc**

Insert after `query_model()`, before `main()`:

```bash
# Full per-document pipeline. Args: doc_file.
# A document failure warns and counts, but never aborts the run: successes
# are already stored, and a re-run retries only the missing rows.
process_doc() {
  local -- doc_file=$1 base=${doc_file##*/}
  local -- prompt elapsed cats src_url note=''
  local -i doc_bytes

  if ((!FORCE)) && [[ -f $DB_FILE ]] && db_has "$base"; then
    info "skip ${base@Q} (already in database; use -f to re-extract)"
    return 0
  fi

  parse_filename "$base"
  extract_src_url "$doc_file"; src_url=$_rv

  prompt="$(build_prompt "$doc_file")" \
    || { error "$base: failed to build prompt"; FAIL_COUNT+=1; return 0; }
  doc_bytes=$(wc -c < "$doc_file") \
    || { error "cannot read ${doc_file@Q}"; FAIL_COUNT+=1; return 0; }

  if ((VERBOSE)); then
    if (( SAMPLE_BUDGET > 0 && doc_bytes > SAMPLE_BUDGET )); then
      note=" — sampled head/middle/tail to ~$SAMPLE_BUDGET chars"
    fi
    printf '=== %s (%s bytes)%s ===\n' "$doc_file" "$doc_bytes" "$note"
  fi

  timer_start
  if ! query_model "$prompt"; then
    timer_stop
    error "$base: $MODEL_TIER: $QM_ERR"
    FAIL_COUNT+=1
    return 0
  fi
  timer_stop; elapsed=$_rv

  validate_cats "$QM_CATS"; cats=$_rv
  validate_year "$QM_YEAR"; QM_YEAR=$_rv
  [[ -n $QM_YEAR ]] || QM_YSRC=''

  ((DRY_RUN)) || db_upsert "$base" "$doc_file" "$cats" "$QM_AUTHOR" "$QM_TITLE" \
                   "$QM_YEAR" "$src_url" "$QM_ASRC" "$QM_TSRC" "$QM_YSRC" "$MODEL_ID"

  if ((VERBOSE)); then
    printf '  categories : %s\n' "$cats"
    printf '  title      : %s%s\n' "$QM_TITLE"  "${QM_TSRC:+  [$QM_TSRC]}"
    printf '  author     : %s%s\n' "$QM_AUTHOR" "${QM_ASRC:+  [$QM_ASRC]}"
    printf '  year       : %s%s\n' "$QM_YEAR"   "${QM_YSRC:+  [$QM_YSRC]}"
    printf '  src_url    : %s\n' "$src_url"
    printf '  [tokens in/out: %s/%s, %ss]\n\n' "$QM_IN" "$QM_OUT" "$elapsed"
  else
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$base" "$cats" "$QM_AUTHOR" "$QM_TITLE" "$QM_YEAR" "$src_url"
  fi
}
```

- [ ] **Step 4: Run suite — all pass**

Run: `./tests/test-kb-metadata.sh`
Expected: `PASS: 77  FAIL: 0`, exit 0. (If the count differs slightly, every line must still read `✓` and `FAIL: 0`.)

- [ ] **Step 5: shellcheck, then commit**

shellcheck both files (clean), then:

```bash
cd /var/lib/vectordbs/appliedanthropology
git add workshops/kb-metadata.sh workshops/tests/test-kb-metadata.sh
git -c user.name='Biksu-Okusi' -c user.email='biksu@okusi.id' \
  commit -m 'feat(workshops): kb-metadata per-document pipeline and integration tests'
```

---

### Task 7: Lint gate, full-suite verification, and live smoke test

**Files:**
- Verify: `workshops/kb-metadata.sh`, `workshops/tests/test-kb-metadata.sh` (no planned edits; fix anything the gates surface)

**Interfaces:**
- Consumes: everything. Produces: the verified deliverable.

- [ ] **Step 1: Syntax + shellcheck gate**

Run: `bash -n workshops/kb-metadata.sh && shellcheck workshops/kb-metadata.sh workshops/tests/test-kb-metadata.sh`
Expected: silence. Fix any finding and re-run the whole suite after.

- [ ] **Step 2: Full offline suite**

Run: `./tests/test-kb-metadata.sh`
Expected: `FAIL: 0`, exit 0. Report the exact PASS count to the user (org verification rule).

- [ ] **Step 3: bcscheck (org policy; slow)**

Run: `bcscheck workshops/kb-metadata.sh`
Expected: ~10–17 minutes; evaluate each finding against the actual BCS rule text before acting (past reports have contained false positives, e.g. BCS0606 on AND-list `-e` exemptions). Fix genuine findings, re-run suite + shellcheck.

- [ ] **Step 4: Live smoke test (requires real credentials — confirm with the user first)**

Three representative documents, verbose then quiet, real sonnet:

```bash
cd /var/lib/vectordbs/appliedanthropology/workshops
./kb-metadata.sh -n Judaism-Unpacked_Why-So-Many-Jews-Fall-In-Love-With-Buddhism.md   # YT-derived
./kb-metadata.sh -n Cory-Doctorow_How-to-Destroy-Surveillance-Capitalism_2021.md      # book, big file (sampling)
./kb-metadata.sh -n what-is-dharma.md                                                 # bare note, no convention
```

Expected: dry-run reports with plausible categories; author/title/year populated for the first two with sensible `*_src` tags; blanks (not guesses) tolerated on the third. Then one REAL write + skip check:

```bash
./kb-metadata.sh what-is-dharma.md
./kb-metadata.sh what-is-dharma.md        # must print the skip info line
sqlite3 corpus-metadata.db 'SELECT * FROM metadata;'
```

- [ ] **Step 5: Report**

State explicitly to the user: offline suite pass count, shellcheck/bcscheck status, which live paths were and were not exercised, and (if the user approved commits) `git log --oneline -n 3` with the pushed/committed SHA.

---

## Deviations & Notes

- `src_url` never enters the model round-trip (spec: bash-only field).
- `main()` was written complete in Task 1; Tasks 2–6 only add the functions it calls. Any change to `main` in later tasks is a plan deviation — flag it.
- The harness sources the script once; unit tests mutate globals (`TOPICS_FILE`, `DB_FILE`, `MODEL_ID`, `AUTH_HEADER`) directly. That's intentional — `readonly` for those happens only inside `main`, which sourcing never runs.
- Assertion counts (10/20/29/37/57/77) are the expected running totals; if an implementer adds an assert, the totals shift — `FAIL: 0` is the invariant.

#fin
