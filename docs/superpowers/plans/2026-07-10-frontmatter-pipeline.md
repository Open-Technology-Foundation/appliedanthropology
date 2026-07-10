# Frontmatter Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stamp corpus metadata as YAML frontmatter onto staged copies (Change A), parse + strip it at `customkb database` ingest into `docs.primary_category`/`docs.categories`/chunk metadata JSON (Change B), and retire the `customkb categorize` populate subcommand.

**Architecture:** Two repos. `/ai/scripts/customkb.bash` (Change B + retirement — tracked git repo, its own house style) and `/var/lib/vectordbs/appliedanthropology/kb-import-staging-text.sh` (Change A). Order is B before A (stamping without stripping embeds YAML). The frontmatter format contract is fixed in the spec.

**Spec:** `docs/superpowers/specs/2026-07-10-frontmatter-pipeline-design.md` — read it first; the format contract and verified-facts sections govern.

**Tech Stack:** Bash 5.2, sqlite3, jq, customkb engine daemon (FastAPI, port 8200) for `/chunk`.

## Global Constraints

- **NO git commits in either repo.** In `/ai/scripts/customkb.bash` run `checkpoint -q` BEFORE the first edit (house rollback mechanism). Never mention AI tooling anywhere.
- **customkb.bash house style** (differs from workshops scripts!): `#!/usr/bin/env bash`; libraries have version guards and NO `set -euo pipefail`; `ckb_` public / `_ckb_` private prefixes; `declare -fx` exports; 2-space indent; integers via `local -i` + standalone `i+=1` (NEVER `((i+=1))` or `((i++))`); single quotes for literals; files end `#fin`.
- **kb-import-staging-text.sh house style**: strict mode, `((int+=1))`-style... no — this script uses `warnings+=1` standalone with `local -i`; match the file's existing conventions exactly.
- **Frontmatter contract** (spec): block opens with `---` as the very first line, closes at next `---` line; scalars double-quoted with `\`/`"` backslash-escaped; `year` bare; blank fields omitted; lists as `  - item`; unknown keys ignored; unterminated block = not frontmatter (content untouched).
- shellcheck clean on every modified file at the end of every task (customkb.bash files already carry targeted disables — do not add broad ones). `bcscheck` only in the final task.
- Tests: `./run_tests.sh` (repo root) must end `ALL PHASES OK`. Some suites skip (rc 77) without the engine daemon or live keys — record which ran in the baseline and keep that set green.
- The metadata DB is `$VECTORDBS/appliedanthropology/workshops/corpus-metadata.db`; schema: `metadata(filename PK, filepath, categories, author, title, year, src_url, author_src, title_src, year_src, model, updated_at)`. A corpus run is writing rows to it concurrently — never write to it, and never run `kb-metadata.sh`.
- Full `kb-import-staging-text.sh` runs are FORBIDDEN in this plan (sudo self-escalation + wipes a shared build artifact). Change A is verified against temp directories by driving individual functions.

---

### Task 1: Baseline

**Files:** none modified.

**Interfaces:**
- Produces: recorded baseline — checkpoint id, `run_tests.sh` outcome + which suites skipped, engine daemon status. Later tasks compare against this.

- [ ] **Step 1:** `cd /ai/scripts/customkb.bash && checkpoint -q` — record output.
- [ ] **Step 2:** `systemctl is-active customkb-engine || true` — record (determines whether phase2/4 e2e paths run live).
- [ ] **Step 3:** `./run_tests.sh 2>&1 | tail -40` — record final aggregate line and each phase's pass/fail/skip counts. Expected: `ALL PHASES OK`. If NOT ok, STOP and report BLOCKED (pre-existing breakage is not ours to fix silently).

---

### Task 2: `ckb_parse_frontmatter` in lib/text_utils.sh + phase0 unit tests

**Files:**
- Modify: `/ai/scripts/customkb.bash/lib/text_utils.sh` (add two functions + globals before the closing `declare -fx` block; extend that block)
- Modify: `/ai/scripts/customkb.bash/tests/test_phase0.sh` (add tests, following the existing `test_*()` + `_run_test` pattern)

**Interfaces:**
- Produces: `ckb_parse_frontmatter CONTENT` — sets `_rv` = content with block stripped (or unchanged), and globals `CKB_FM_TITLE`, `CKB_FM_AUTHOR` (", "-joined), `CKB_FM_YEAR`, `CKB_FM_CATEGORIES` (","-joined), `CKB_FM_SRC_URL` — all reset each call. Private helper `_ckb_fm_unquote`.
- Consumes: `_rv` convention already used throughout text_utils.sh.

- [ ] **Step 1: Add failing tests to tests/test_phase0.sh**

Insert these test functions after the last existing `test_*` function body, and register each with `_run_test <name>` in the runner section where the other text_utils tests are registered (search for the existing `_run_test test_bm25_tokenize` line and add after it):

```bash
test_fm_passthrough_no_block() {
  source "$LIB_DIR"/text_utils.sh
  local -- doc=$'# Title\n\nBody text.'
  ckb_parse_frontmatter "$doc"
  _assert_eq "$doc" "$_rv" 'content unchanged without frontmatter'
  _assert_eq '' "$CKB_FM_TITLE" 'no title captured'
}

test_fm_full_block() {
  source "$LIB_DIR"/text_utils.sh
  local -- doc=$'---\ntitle: "A \\"Quoted\\" Title: with colon"\nauthors:\n  - "Jane Doe"\n  - "Li Wei"\nyear: 2021\ncategories:\n  - alpha-topic\n  - beta-topic\nsource_url: "https://example.org/x"\nprovenance: { author: text }\n---\nBody starts here.\n'
  ckb_parse_frontmatter "$doc"
  _assert_eq 'Body starts here.' "${_rv%$'\n'}" 'block stripped'
  _assert_eq 'A "Quoted" Title: with colon' "$CKB_FM_TITLE" 'title unquoted+unescaped'
  _assert_eq 'Jane Doe, Li Wei' "$CKB_FM_AUTHOR" 'authors list joined'
  _assert_eq '2021' "$CKB_FM_YEAR" 'year'
  _assert_eq 'alpha-topic,beta-topic' "$CKB_FM_CATEGORIES" 'categories list joined'
  _assert_eq 'https://example.org/x' "$CKB_FM_SRC_URL" 'source_url'
}

test_fm_scalar_forms() {
  source "$LIB_DIR"/text_utils.sh
  local -- doc=$'---\nauthor: Solo Author\ncategories: alpha-topic,beta-topic\n---\nX'
  ckb_parse_frontmatter "$doc"
  _assert_eq 'Solo Author' "$CKB_FM_AUTHOR" 'scalar author'
  _assert_eq 'alpha-topic,beta-topic' "$CKB_FM_CATEGORIES" 'comma-scalar categories'
  _assert_eq 'X' "$_rv" 'body after scalar block'
}

test_fm_unterminated_is_content() {
  source "$LIB_DIR"/text_utils.sh
  local -- doc=$'---\ntitle: "Dashes but no close"\nBody line.'
  ckb_parse_frontmatter "$doc"
  _assert_eq "$doc" "$_rv" 'unterminated block left untouched'
  _assert_eq '' "$CKB_FM_TITLE" 'no capture from unterminated block'
}

test_fm_midfile_dashes_ignored() {
  source "$LIB_DIR"/text_utils.sh
  local -- doc=$'Intro.\n---\ntitle: "Not frontmatter"\n---\nMore.'
  ckb_parse_frontmatter "$doc"
  _assert_eq "$doc" "$_rv" 'mid-file --- is not frontmatter'
}

test_fm_state_reset_between_calls() {
  source "$LIB_DIR"/text_utils.sh
  ckb_parse_frontmatter $'---\ntitle: "First"\n---\nA'
  ckb_parse_frontmatter $'no frontmatter here'
  _assert_eq '' "$CKB_FM_TITLE" 'globals reset on next call'
}
```

- [ ] **Step 2:** `bash tests/test_phase0.sh` — new tests FAIL (`ckb_parse_frontmatter: command not found`), existing tests still pass.

- [ ] **Step 3: Implement in lib/text_utils.sh**

Add before the existing `declare -fx` export block:

```bash
# Frontmatter capture globals — reset on every ckb_parse_frontmatter call
declare -- CKB_FM_TITLE='' CKB_FM_AUTHOR='' CKB_FM_YEAR=''
declare -- CKB_FM_CATEGORIES='' CKB_FM_SRC_URL=''

# Unquote a YAML scalar: trim whitespace; if double-quoted, strip the quotes
# and unescape \\ and \" (placeholder swap keeps one-pass semantics correct).
# Sets _rv.
_ckb_fm_unquote() {
  local -- s=${1-}
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  if (( ${#s} >= 2 )) && [[ $s == \"*\" ]]; then
    s=${s:1:${#s}-2}
    s=${s//\\\\/$'\x01'}
    s=${s//\\\"/\"}
    s=${s//$'\x01'/\\}
  fi
  _rv=$s
}

# Parse and strip a leading YAML frontmatter block (spec 2026-07-10 contract).
# Args: CONTENT. Sets _rv to content minus the block (unchanged when no valid
# block) and fills the CKB_FM_* globals. Recognised keys: title,
# author/authors (scalar or "- " list), year, categories (list or comma
# scalar), source_url/src_url. Unknown keys skipped. A block that does not
# close with a bare --- line within 100 lines is treated as content.
ckb_parse_frontmatter() {
  local -- content=${1-}
  CKB_FM_TITLE='' CKB_FM_AUTHOR='' CKB_FM_YEAR=''
  CKB_FM_CATEGORIES='' CKB_FM_SRC_URL=''
  _rv=$content
  [[ $content == '---'$'\n'* ]] || return 0

  local -- rest=${content:4} line key val list_key=''
  local -- title='' author='' year='' cats='' url=''
  local -i offset=4 end_found=0 lineno=0

  while [[ -n $rest || $lineno -eq 0 ]]; do
    line=${rest%%$'\n'*}
    if [[ $rest == *$'\n'* ]]; then rest=${rest#*$'\n'}; else rest=''; fi
    lineno+=1
    (( lineno <= 100 )) || break
    offset+=$(( ${#line} + 1 ))
    [[ $line != '---' ]] || { end_found=1; break; }

    if [[ $line =~ ^[[:space:]]+-[[:space:]] ]]; then
      [[ -n $list_key ]] || continue
      _ckb_fm_unquote "${line#*- }"; val=$_rv
      case $list_key in
        author|authors) author+="${author:+, }$val" ;;
        categories)     cats+="${cats:+,}$val" ;;
      esac
      continue
    fi

    key=${line%%:*}
    [[ $key != "$line" ]] || { list_key=''; continue; }
    [[ $key =~ ^[a-z_]+$ ]] || { list_key=''; continue; }
    val=${line#*:}
    if [[ -z ${val//[[:space:]]/} ]]; then
      case $key in
        author|authors|categories) list_key=$key ;;
        *)                         list_key='' ;;
      esac
      continue
    fi
    list_key=''
    _ckb_fm_unquote "$val"; val=$_rv
    case $key in
      title)              title=$val ;;
      author|authors)     author=$val ;;
      year)               year=$val ;;
      categories)         cats=$val ;;
      source_url|src_url) url=$val ;;
    esac
  done

  (( end_found )) || return 0
  (( offset <= ${#content} )) || offset=${#content}
  CKB_FM_TITLE=$title CKB_FM_AUTHOR=$author CKB_FM_YEAR=$year
  CKB_FM_CATEGORIES=$cats CKB_FM_SRC_URL=$url
  _rv=${content:offset}
}
```

Extend the file's `declare -fx` list with `ckb_parse_frontmatter _ckb_fm_unquote`.

- [ ] **Step 4:** `bash tests/test_phase0.sh` — all pass (old count + 6 new).
- [ ] **Step 5:** `shellcheck lib/text_utils.sh tests/test_phase0.sh` — no new findings.

---

### Task 3: Wire frontmatter into the `customkb database` import loop + phase4 tests

**Files:**
- Modify: `/ai/scripts/customkb.bash/customkb` (import loop, ~lines 830-890) and `lib/text_utils.sh` (`ckb_build_metadata` gains 3 optional args)
- Modify: `/ai/scripts/customkb.bash/tests/test_phase4.sh`

**Interfaces:**
- Consumes: `ckb_parse_frontmatter` + `CKB_FM_*` from Task 2.
- Produces: INSERT now includes `primary_category, categories` via `NULLIF('…','')`; `ckb_build_metadata SOURCE TEXT FILE_TYPE [TITLE AUTHOR YEAR]` appends `"title"/"author"/"year"` to chunk JSON when non-empty.

- [ ] **Step 1: Failing phase4 tests** (register with `_run_test` alongside the other metadata/database tests):

```bash
test_build_metadata_fm_fields() {
  source "$LIB_DIR"/text_utils.sh
  ckb_build_metadata '/tmp/x.md' 'Some text' 'markdown' 'A Title' 'An Author' '1999'
  [[ $_rv == *'"title":"A Title"'* ]] || { >&2 echo "missing title: $_rv"; return 1; }
  [[ $_rv == *'"author":"An Author"'* ]] || { >&2 echo "missing author: $_rv"; return 1; }
  [[ $_rv == *'"year":"1999"'* ]] || { >&2 echo "missing year: $_rv"; return 1; }
  jq -e . <<<"$_rv" >/dev/null || { >&2 echo "invalid JSON: $_rv"; return 1; }
}

test_build_metadata_fm_absent() {
  source "$LIB_DIR"/text_utils.sh
  ckb_build_metadata '/tmp/x.md' 'Some text' 'markdown'
  [[ $_rv != *'"title"'* ]] || { >&2 echo "unexpected title key: $_rv"; return 1; }
  jq -e . <<<"$_rv" >/dev/null
}
```

Plus an import-path test if (and only if) the phase4 suite already has a live-import test pattern using the engine daemon — mirror that pattern: write a temp .md whose content is the Task-2 `test_fm_full_block` document, import it into the fixture KB with `--force`, then assert via sqlite3: `primary_category='alpha-topic'`, `categories='alpha-topic,beta-topic'`, `originaltext NOT LIKE '---%'`, `embedtext NOT LIKE '%source_url%'`, and metadata JSON contains `"title"`. If the suite has no live-import pattern (daemon-gated with rc 77), add the test with the same gating.

- [ ] **Step 2:** Run phase4 — new tests fail (build_metadata lacks args / import lacks columns).

- [ ] **Step 3a: Extend `ckb_build_metadata`** — add after the existing `file_type` local:

```bash
  local -- fm_title=${4:-} fm_author=${5:-} fm_year=${6:-}
```

and change the JSON assembly tail: build an `extra` string before the final printf:

```bash
  local -- extra=''
  if [[ -n $fm_title ]]; then
    _json_esc_v "$fm_title";  extra+=",\"title\":\"$_rv\""
  fi
  if [[ -n $fm_author ]]; then
    _json_esc_v "$fm_author"; extra+=",\"author\":\"$_rv\""
  fi
  if [[ -n $fm_year ]]; then
    _json_esc_v "$fm_year";   extra+=",\"year\":\"$_rv\""
  fi
  printf -v _rv '{"source":"%s","char_length":%d,"word_count":%d,"file_type":"%s","heading":"%s","section_type":"%s"%s}' \
    "$es" "$char_length" "$word_count" "$file_type" "$eh" "$section_type" "$extra"
```

(replacing the existing final printf — note `%s` for `$extra` inside the braces).

- [ ] **Step 3b: Wire the import loop in `customkb`.** In the pre-declare block add:

```bash
  local -- fm_title fm_author fm_year fm_cats fm_primary esc_primary esc_cats
```

Immediately after the `content` read + empty check (after `[[ -n $content ]] || { debug "Empty file…`):

```bash
    # Frontmatter: parse and strip BEFORE chunking/BM25 so metadata never
    # reaches embeddings (spec 2026-07-10)
    ckb_parse_frontmatter "$content"; content=$_rv
    fm_title=$CKB_FM_TITLE fm_author=$CKB_FM_AUTHOR fm_year=$CKB_FM_YEAR
    fm_cats=$CKB_FM_CATEGORIES
    fm_primary=${fm_cats%%,*}
    [[ -n ${content//[[:space:]]/} ]] || { debug "Empty after frontmatter: ${file@Q}"; files_skipped+=1; continue; }
```

Change the `ckb_build_metadata` call to pass the three fields, and extend the INSERT (both the escape block and the statement):

```bash
      esc_primary=${fm_primary//\'/\'\'}
      esc_cats=${fm_cats//\'/\'\'}
```

```bash
      insert_sql+="INSERT INTO docs (sid,sourcedoc,originaltext,embedtext,embedded,language,metadata,bm25_tokens,doc_length,keyphrase_processed,primary_category,categories) VALUES ($sid,'$esc_sourcedoc','$esc_chunk','$esc_embedtext',0,'$esc_language','$esc_metadata','$esc_bm25',$doc_length,$keyphrase_processed,NULLIF('$esc_primary',''),NULLIF('$esc_cats',''));"
```

- [ ] **Step 4:** `bash tests/test_phase4.sh` all pass; then `./run_tests.sh` — same green set as baseline plus new tests.
- [ ] **Step 5:** `shellcheck customkb lib/text_utils.sh tests/test_phase4.sh` — no new findings.

---

### Task 4: Change A — stamping in kb-import-staging-text.sh (md + transcripts)

**Files:**
- Modify: `/var/lib/vectordbs/appliedanthropology/kb-import-staging-text.sh`

**Interfaces:**
- Consumes: `corpus-metadata.db` (read-only!), `video_info.sh`/`channel_info.sh` conventions (spec Verified Facts).
- Produces: `load_metadata()` (fills `META` assoc keyed by basename, US-joined `categories␟author␟title␟year␟src_url`), `yaml_quote()` (sets `_rv`), `emit_frontmatter()` (prints a contract-conformant block from field args), `write_stamped()` (dest = frontmatter + source content). `collect_files` stamps matched `.md`; `process_transcripts` stamps transcripts with title/channel/url.

- [ ] **Step 1: Add the functions** (after the existing messaging functions, matching file style; note this script runs as root and uses `set -euo pipefail`):

```bash
declare -A META=()
declare -- _rv=''

# Load corpus metadata once: basename -> categories␟author␟title␟year␟src_url
load_metadata() {
  local -r db="$WORKSHOPS"/corpus-metadata.db
  local -r us=$'\x1f'
  [[ -f $db ]] || { warn "no corpus-metadata.db — staging md will be unstamped"; return 0; }
  local -- row
  while IFS= read -r row; do
    META["${row%%"$us"*}"]=${row#*"$us"}
  done < <(sqlite3 -readonly -separator "$us" "$db" \
    'SELECT filename, categories, author, title, year, src_url FROM metadata;')
  info "${#META[@]} metadata rows loaded"
}

# Double-quoted YAML scalar with \ and " escaped. Sets _rv.
yaml_quote() {
  local -- s=${1//\\/\\\\}
  _rv=\"${s//\"/\\\"}\"
}

# Print a frontmatter block. Args: categories author title year src_url [type]
# Blank fields are omitted; empty categories+title+author+url+type prints nothing.
emit_frontmatter() {
  local -- cats=$1 author=$2 title=$3 year=$4 url=$5 doctype=${6:-}
  [[ -n $cats$author$title$url$doctype ]] || return 0
  printf -- '---\n'
  if [[ -n $title ]]; then yaml_quote "$title"; printf 'title: %s\n' "$_rv"; fi
  if [[ -n $author ]]; then
    printf 'authors:\n'
    local -- a
    while IFS= read -r a; do
      a=${a#"${a%%[![:space:]]*}"}; a=${a%"${a##*[![:space:]]}"}
      [[ -z $a ]] || { yaml_quote "$a"; printf '  - %s\n' "$_rv"; }
    done <<<"${author//, /$'\n'}"
  fi
  [[ -z $year ]] || printf 'year: %s\n' "$year"
  if [[ -n $cats ]]; then
    printf 'categories:\n'
    local -- c
    while IFS= read -r c; do
      [[ -z $c ]] || printf '  - %s\n' "$c"
    done <<<"${cats//,/$'\n'}"
  fi
  if [[ -n $url ]]; then yaml_quote "$url"; printf 'source_url: %s\n' "$_rv"; fi
  [[ -z $doctype ]] || printf 'type: %s\n' "$doctype"
  printf -- '---\n'
}

# Copy src -> dest with a frontmatter block from a META record.
# Args: src dest us_record. Preserves the source mtime.
write_stamped() {
  local -- src=$1 dest=$2 rec=$3
  local -a f=()
  IFS=$'\x1f' read -r -a f <<<"$rec"
  { emit_frontmatter "${f[0]:-}" "${f[1]:-}" "${f[2]:-}" "${f[3]:-}" "${f[4]:-}"
    cat -- "$src"
  } > "$dest"
  touch -r "$src" -- "$dest"
}
```

- [ ] **Step 2: Wire `collect_files`.** Replace the plain `cp -p -- "$file" "$STAGING_TEXT"/"$rel"` with:

```bash
    base=${file##*/}
    if [[ $base == *.md && -n ${META[$base]:-} ]]; then
      write_stamped "$file" "$STAGING_TEXT"/"$rel" "${META[$base]}"
    else
      cp -p -- "$file" "$STAGING_TEXT"/"$rel"
    fi
```

(declare `local -- base` with the other locals; call `load_metadata` in `main()` after the staging wipe, before `process_transcripts`).

- [ ] **Step 3: Wire `process_transcripts`.** Extend the existing strict-off subshell to also emit title/url/channel (single US-joined printf; keep the existing slug sanitisation exactly as-is afterwards):

```bash
      vals=$(
        set +euo pipefail
        # shellcheck source=/dev/null
        source "$file_dir"/video_info.sh 2>/dev/null
        ch="${video_dir%%/videos/*}"/channel_info.sh
        [[ ! -f $ch ]] || source "$ch" 2>/dev/null
        printf '%s\x1f%s\x1f%s\x1f%s' \
          "${video_name_slug:-}" "${video_title:-}" "${video_url:-}" "${channel_name:-}"
      ) || true
      IFS=$'\x1f' read -r video_name_slug vtitle vurl vchannel <<<"$vals"
      video_name_slug=${video_name_slug//[^a-zA-Z0-9._-]/}
```

and replace the final `cp -p -- "$file" "$TRANSDIR"/"$newfile"` with:

```bash
    if [[ -n $vtitle || -n $vchannel || -n $vurl ]]; then
      { emit_frontmatter '' "$vchannel" "$vtitle" '' "$vurl" 'video-transcript'
        cat -- "$file"
      } > "$TRANSDIR"/"$newfile"
      touch -r "$file" -- "$TRANSDIR"/"$newfile"
    else
      cp -p -- "$file" "$TRANSDIR"/"$newfile"
    fi
```

(declare `local -- vals vtitle vurl vchannel` alongside the existing loop locals.)

- [ ] **Step 4: Verify WITHOUT running the script** (no sudo, no staging wipe). Drive the functions directly in a sandbox:

```bash
cd /var/lib/vectordbs/appliedanthropology
bash -n kb-import-staging-text.sh
tmp=$(mktemp -d)
# Extract functions by sourcing with main disabled is not available (script
# calls main unconditionally) — so test via bash -c with the functions
# copy-pasted OR add a guard: [[ ${KIST_TEST_SOURCE:-} == 1 ]] || main "$@"
# PREFERRED: add that source-guard (mirrors kb-metadata.sh) as part of this task.
KIST_TEST_SOURCE=1 source ./kb-import-staging-text.sh
WORKSHOPS=$PWD/workshops   # readonly already set by script — verify value instead
load_metadata
echo "META rows: ${#META[@]}"                     # expect >0 (corpus run in progress)
emit_frontmatter 'a,b' 'X Y, Z W' 'T "q": t' '2020' 'https://u' | head -20
rec="a,b"$'\x1f'"Auth"$'\x1f'"Title"$'\x1f'"2020"$'\x1f'""
printf 'body\n' > "$tmp/in.md"; write_stamped "$tmp/in.md" "$tmp/out.md" "$rec"
cat "$tmp/out.md"
python3 - <<'PY'
import yaml, pathlib
t = pathlib.Path("'"$tmp"'/out.md").read_text().split('---\n')
print(yaml.safe_load(t[1]))
PY
rm -rf "$tmp"
```

Requirements: the source-guard line `[[ ${KIST_TEST_SOURCE:-} == 1 ]] || main "$@"` replaces the bare `main "$@"` (note: the root self-escalation at the top must also be skipped when sourced — guard it with the same variable: `((EUID)) && [[ ${KIST_TEST_SOURCE:-} != 1 ]] && { sudo "$0" "$@"; exit $?; }` — verify this exact semantics carefully; when sourced non-root, it must NOT sudo). Frontmatter output must parse as YAML (python check above) and `write_stamped` output must be block + verbatim body.

- [ ] **Step 5:** `shellcheck kb-import-staging-text.sh` — clean (this script currently is; keep it so).

---

### Task 5: Retire `customkb categorize`

**Files:**
- Modify: `/ai/scripts/customkb.bash/customkb` (remove the subcommand implementation + dispatch case + usage mentions)
- Modify: `/ai/scripts/customkb.bash/tests/test_phase5.sh` (replace suite), `/ai/scripts/customkb.bash/run_tests.sh` (only if suite list needs adjusting), `README.md` + `CLAUDE.md` (remove/adjust categorize references)

**Interfaces:**
- Consumes: nothing new. Produces: `customkb categorize` → the dispatcher's normal unknown-command error. Query-side `--categories` filter, the DB columns, the `idx_primary_category` index, and `cats/` artifacts all REMAIN.

- [ ] **Step 1:** Locate the removal region: `grep -n 'categorize' customkb` — the help function (`show_categorize_help`), `_categorize_article`, the main categorize command function(s) (~lines 935-1360), and the dispatch `case` arm. Remove the implementation functions and the dispatch arm; remove `categorize` from the top-level usage/help text. Do NOT touch `--categories` handling in the query command, `filter_by_categories` (engine), or `ckb_db_*` functions.
- [ ] **Step 2:** Rewrite `tests/test_phase5.sh` as a minimal suite (same harness pattern) with two tests: (a) `customkb categorize x 2>&1` exits non-zero and the error mentions unknown/invalid command; (b) `customkb --help` output does not mention categorize. Keep the rc-77 skip convention if the suite previously gated on anything.
- [ ] **Step 3:** Update `README.md` and `CLAUDE.md`: remove `customkb categorize` from command lists; in CLAUDE.md's storage-structure note keep `cats/` but mark it historical. Search: `grep -rn 'categorize' README.md CLAUDE.md`.
- [ ] **Step 4:** `./run_tests.sh` — `ALL PHASES OK` (phase5 now small). `bash -n customkb && shellcheck customkb` — no new findings.
- [ ] **Step 5:** Confirm nothing else referenced the removed functions: `grep -rn '_categorize_article\|show_categorize_help' . --include='*.sh' --include='customkb'` → empty.

---

### Task 6: End-to-end verification + gates

**Files:** none modified (fix regressions only).

- [ ] **Step 1 (e2e, requires engine daemon; skip with a clear report note if inactive):** Create a temp KB fixture (follow `tests/bootstrap-fixture.sh` / phase4 fixture conventions): three files — (1) md with full frontmatter (alpha/beta categories), (2) transcript-style txt with title/author/type frontmatter but no categories, (3) plain md without frontmatter. `customkb database <fixture> <files>`, then assert via sqlite3:
  - file 1 rows: `primary_category='alpha-topic'`, `categories='alpha-topic,beta-topic'`, metadata JSON has title/author/year, `originaltext` does NOT begin `---`, embedtext contains no YAML keys;
  - file 2 rows: categories NULL, metadata has title/author;
  - file 3 rows: categories NULL, no title key in metadata.
  Then `customkb query <fixture> 'anything' --context-only --categories alpha-topic` (if the fixture KB supports query without embeddings, otherwise verify `filter_by_categories` indirectly via sqlite predicate parity) — report exactly what was and wasn't exercised.
- [ ] **Step 2:** Full `./run_tests.sh` — record final counts vs Task-1 baseline.
- [ ] **Step 3:** `shellcheck` sweep over every file modified in this plan.
- [ ] **Step 4:** `bcscheck` on `customkb`, `lib/text_utils.sh`, and `kb-import-staging-text.sh` (slow, ~10-17 min each — run sequentially in the background; triage findings against actual BCS rule text; apply only genuine ones; document rejections with cause).
- [ ] **Step 5:** Report: baseline vs final test counts, e2e assertions, shellcheck/bcscheck outcomes, explicitly note (a) NO commits were made in either repo, (b) checkpoint id from Task 1, (c) full staging rebuild deliberately not run — hand the user the command for when the corpus run finishes.

## Deviations & Notes

- The corpus metadata run writes `corpus-metadata.db` concurrently throughout this plan — Change A's `load_metadata` uses `sqlite3 -readonly` and tolerates partial data (stamping coverage grows as the run progresses; a staging rebuild after completion picks up everything).
- Task 4's source-guard addition (`KIST_TEST_SOURCE`) is a real interface change to kb-import-staging-text.sh justified by testability; keep the sudo self-escalation semantics for normal execution identical.
- If any brief text conflicts with the two repos' differing house styles, the repo's own CLAUDE.md wins for files in that repo.

#fin
