#!/bin/bash
# mk-hf-catalogue.sh - Build the Hugging Face catalogue config (catalogue.jsonl)
#
# Joins three existing artefacts into one bibliographic record per source doc:
#   appliedanthropology.db        docs table: sourcedoc list + segment counts
#   workshops/corpus-metadata.db  kb-metadata extraction: author/title/year/url/topics
#   cats/categorization.csv       legacy category labels + confidence
# Rights tier per record comes from hf-rights.tsv (longest path-prefix wins,
# unknown => copyrighted => text never exported).
#
# text_included is decided by an explicit allowlist of exportable tiers, not by
# "anything that is not copyrighted". Tiers are open-ended — new licences get new
# names — and a negative test silently grants export to every name nobody has
# considered yet, which is the wrong way round for a rights decision.
#
# Output: hf-dataset/catalogue.jsonl (one JSON object per line, sorted by sourcedoc)
set -euo pipefail
shopt -s inherit_errexit

declare -rx PATH=/usr/local/bin:/usr/bin:/bin

declare -r VERSION='0.1.0'

declare -- SCRIPT_PATH
SCRIPT_PATH=$(realpath -- "$0") || exit 1
declare -r SCRIPT_PATH
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*}

declare -r MAIN_DB="$SCRIPT_DIR/appliedanthropology.db"
declare -r META_DB="$SCRIPT_DIR/workshops/corpus-metadata.db"
declare -r CATS_CSV="$SCRIPT_DIR/cats/categorization.csv"
declare -r RIGHTS_TSV="$SCRIPT_DIR/hf-rights.tsv"
declare -r STAGING_PREFIX="$SCRIPT_DIR/staging.text/"

# Tiers whose full text may be exported. Everything else is metadata-only.
# NC/ND/SA are deliberately absent: they are redistributable only under terms the
# dataset release does not currently carry.
declare -r EXPORTABLE_TIERS='["original","public-domain","cc0","cc-by"]'

declare -- OUT_DIR="$SCRIPT_DIR/hf-dataset"
declare -g TMP_DIR=''

error() {
  local -- msg
  for msg in "$@"; do
    >&2 echo "✗ ${0##*/}: $msg"
  done
}

die() {
  (($# < 2)) || error "${@:2}"
  exit "${1:-0}"
}

success() {
  >&2 echo "✓ ${0##*/}: $1"
}

usage() {
  cat <<-USAGE
	${0##*/} $VERSION - build hf-dataset/catalogue.jsonl for the HF dataset export

	Usage: ${0##*/} [-o output_dir]

	Options:
	  -o, --output output_dir  Write catalogue.jsonl into output_dir
	                           (default: $OUT_DIR)
	  -V, --version            Print version and exit
	  -h, --help               Show this help and exit

	Examples:
	  ./${0##*/}                # regenerate hf-dataset/catalogue.jsonl
	  ./${0##*/} -o /tmp/hf     # alternate output directory
	USAGE
  exit "${1:-0}"
}

noarg() {
  (($# > 1)) || die 22 "option ${1@Q} requires an argument"
}

main() {
  local -- opt
  local -a new_args=()
  while (($#)); do case $1 in
    -o|--output)  noarg "$@"; shift; OUT_DIR=$1 ;;
    -V|--version) echo "${0##*/} $VERSION"; exit 0 ;;
    -h|--help)    usage 0 ;;
    -[oVh]*)      opt=${1:1}; new_args=()
                  while [[ -n $opt ]]; do
                    new_args+=("-${opt:0:1}"); opt=${opt:1}
                  done
                  set -- '' "${new_args[@]}" "${@:2}" ;;
    -*)           usage 22 ;;
    *)            die 22 "unexpected argument: ${1@Q}" ;;
  esac; shift; done
  readonly OUT_DIR

  local -- cmd
  for cmd in sqlite3 jq; do
    command -v "$cmd" >/dev/null || die 18 "required command not found: ${cmd@Q}"
  done
  local -- f
  for f in "$MAIN_DB" "$META_DB" "$CATS_CSV" "$RIGHTS_TSV"; do
    [[ -r $f ]] || die 3 "required file not readable: ${f@Q}"
  done

  trap '[[ -z $TMP_DIR ]] || rm -rf "$TMP_DIR"' EXIT
  TMP_DIR=$(mktemp -d) || die 1 'Failed to create temp dir'

  # Source docs
  sqlite3 -json "$MAIN_DB" \
    'SELECT sourcedoc, COUNT(*) AS segments FROM docs GROUP BY sourcedoc ORDER BY sourcedoc;' \
    > "$TMP_DIR/docs.json" || die 1 'docs query failed'

  # Metadata bibliography
  sqlite3 -json "$META_DB" \
    'SELECT filename, author, title, year, src_url, categories AS topics FROM metadata;' \
    > "$TMP_DIR/meta.json" || die 1 'metadata query failed'

  # Legacy categorization
  sqlite3 :memory: <<-SQL > "$TMP_DIR/cats.json" || die 1 'categorization import failed'
	.mode csv
	.import '$CATS_CSV' cats
	.mode json
	SELECT article, primary_category, all_categories, confidence FROM cats;
	SQL

  # Rights map
  jq -Rn '[inputs
           | sub("[[:space:]]*#.*$"; "")
           | select(length > 0)
           | split("\t")
           | {prefix: .[0], tier: .[1]}]' \
    < "$RIGHTS_TSV" > "$TMP_DIR/rights.json" || die 1 'rights map parse failed'

  # Join records
  jq -c --arg prefix "$STAGING_PREFIX" \
      --argjson exportable "$EXPORTABLE_TIERS" \
      --slurpfile meta "$TMP_DIR/meta.json" \
      --slurpfile cats "$TMP_DIR/cats.json" \
      --slurpfile rights "$TMP_DIR/rights.json" '
    def nn: if . == null or . == "" then null else . end;
    INDEX($meta[0][]; .filename) as $m
    | INDEX($cats[0][]; (.article | sub(".*/"; ""))) as $c
    | $rights[0] as $r
    | .[]
    | (.sourcedoc | ltrimstr($prefix)) as $rel
    | ($rel | sub(".*/"; "")) as $base
    | ($rel | split("/")[0]) as $group
    | ([ $r[] | . as $e
        | select(($rel == $e.prefix) or ($rel | startswith($e.prefix + "/"))) ]
       | sort_by(-(.prefix | length))
       | (.[0].tier // "copyrighted")) as $tier
    | $m[$base] as $mm
    | $c[$base] as $cc
    | {
        sourcedoc: $rel,
        source_group: $group,
        title: (($mm.title | nn)
                // ($base | sub("\\.(md|txt|text)$"; "") | gsub("[-_]+"; " "))),
        author: ($mm.author | nn),
        year: ($mm.year | nn),
        src_url: ($mm.src_url | nn),
        topics: (($mm.topics | nn) | if . then split(",") else [] end),
        primary_category: ($cc.primary_category | nn),
        categories: (($cc.all_categories | nn)
                     | if . then split(",") | map(gsub("^ +| +$"; "")) else [] end),
        category_confidence: (($cc.confidence | nn) | if . then tonumber else null end),
        segments: .segments,
        rights_tier: $tier,
        text_included: (($exportable | index($tier)) != null)
      }' "$TMP_DIR/docs.json" > "$TMP_DIR/catalogue.jsonl" || die 1 'catalogue join failed'

  mkdir -p -- "$OUT_DIR" || die 1 "Failed to create output dir: ${OUT_DIR@Q}"
  mv -- "$TMP_DIR/catalogue.jsonl" "$OUT_DIR/catalogue.jsonl" \
    || die 1 'Failed to install catalogue.jsonl'

  # Print summary
  local -i total
  total=$(wc -l < "$OUT_DIR/catalogue.jsonl") || die 1 'summary count failed'
  success "wrote $OUT_DIR/catalogue.jsonl ($total records)"
  jq -rs 'group_by(.rights_tier)
          | map("  \(.[0].rights_tier): \(length) docs, \(map(.segments) | add) segments")
          | .[]' "$OUT_DIR/catalogue.jsonl" >&2
  jq -rs '"  bibliographic coverage: \(map(select(.author != null)) | length) with author, "
          + "\(map(select(.topics != [])) | length) with topics, of \(length)"' \
    "$OUT_DIR/catalogue.jsonl" >&2
}

main "$@"

#fin
