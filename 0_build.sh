#!/bin/bash
set -Eeuo pipefail
((EUID)) && { sudo "$0" "$@"; exit; }
declare -- PRG0 PRGDIR PRG
PRG0=$(readlink -fn -- "$0")
PRGDIR=$(dirname -- "$PRG0")
PRG=$(basename -s .sh -- "$0")

# Logging functions
#shellcheck disable=SC2015
[[ -t 2 ]] && declare -r RED=$'\033[0;31m' YELLOW=$'\033[0;33m' GREEN=$'\033[0;32m' NOCOLOR=$'\033[0m' || declare -r RED='' YELLOW='' GREEN='' NOCOLOR=''
declare -i VERBOSE=1 DEBUG=0
vecho() { ((VERBOSE)) || return 0; local msg; for msg in "$@"; do >&2 printf '%s: %s\n' "$PRG" "$msg"; done; }
vwarn() { ((VERBOSE)) || return 0; local msg; for msg in "$@"; do >&2 printf '%s: %swarn%s: %s\n' "$PRG" "$YELLOW" "$NOCOLOR" "$msg"; done; }
error() { local msg; for msg in "$@"; do >&2 printf '%s: %serror%s: %s\n' "$PRG" "$RED" "$NOCOLOR" "$msg"; done; }
success() { local msg; for msg in "$@"; do >&2 printf '%s: %ssuccess%s: %s\n' "$PRG" "$GREEN" "$NOCOLOR" "$msg"; done; }
debug() { ((DEBUG)) || return 0; local msg; for msg in "$@"; do >&2 printf '%s: %sdebug%s: %s\n' "$PRG" "$YELLOW" "$NOCOLOR" "$msg"; done; }
die() { (($# < 2)) || error "${@:2}"; (($# < 1)) || exit "$1"; exit 1; }
decp() { ((DEBUG)) || return 0; >&2 declare -p "$@"; }
trim() { local v="$*"; v="${v#"${v%%[![:blank:]]*}"}"; echo -n "${v%"${v##*[![:blank:]]}"}"; }
chownsysadmin() { cd "$1"; sudo chown sysadmin:www-data "$1"/* -R || true; }

declare -- KB=appliedanthropology
declare -- KBdir="$VECTORDBS"/"$KB"
cd "$KBdir"
KBdir=$PWD
declare -- staging_text="$KBdir"/staging.text/ #embed_data.text
declare -- real_staging_text=$(readlink -en -- "$staging_text")/
declare -- workshops="$KBdir"/workshops/
declare -- real_workshops=$(readlink -en -- "$workshops")/ #embed_data

declare -- dbname="$KB".db
declare -- bm25name="$KB".bm25
declare -- faissname="$KB".faiss
declare -- cfgname="$KB".cfg
>&2 declare -p cfgname dbname faissname bm25name

# Configuration Variables - Default values
declare -- KB_CONTEXT='Biology, Evolution, Anthropology, Culture, Dharma, Human Behavioural Evolution'
declare -- GEN_MODEL='gpt-4.1-mini'
declare -- GEN_TEMPERATURE='0.2'
declare -i GEN_MAX_TOKENS=200
declare -i GEN_PARALLEL=42
declare -- TEST_QUERY='Explain the meaning of the word "dharma" as expressed within contemporary Balinese Hinduism.'

# Load configuration file if it exists
declare -- build_config="$KBdir"/"$KB".build.conf
if [[ -f "$build_config" ]]; then
  vecho "Loading configuration from $build_config"
  # Simple configuration parser - reads KEY=VALUE lines
  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    # Trim whitespace
    key=$(trim "$key")
    value=$(trim "$value")
    # Remove quotes if present
    value="${value#\"}"; value="${value%\"}"
    value="${value#\'}"; value="${value%\'}"
    
    case "$key" in
      context) KB_CONTEXT="$value" ;;
      model) GEN_MODEL="$value" ;;
      temperature) GEN_TEMPERATURE="$value" ;;
      max_tokens) GEN_MAX_TOKENS="$value" ;;
      parallel) GEN_PARALLEL="$value" ;;
      test_query) TEST_QUERY="$value" ;;
      preserve_embed_data_text) preserve_embed_data_text="$value" ;;
      remove_database) remove_database="$value" ;;
    esac
  done < "$build_config"
fi

# Set defaults only if not already set by config file
declare -ix preserve_embed_data_text=${preserve_embed_data_text:-1}
declare -i remove_database=${remove_database:-0}

declare -i  do_create_text_cache=0 \
            do_gen_citations=0 \
            do_append_citations=0 \
            do_import_text_database=0 \
            do_embed=0 \
            do_test_query=0

declare -i REPROCESS_BLANK=0 FORCE=0

# Default values for command line options
declare -- MODEL=""
declare -i MAX_TOKENS=0
declare -- TEMPERATURE=""
declare -- BROAD_CONTEXT=""
declare -i DRY_RUN=0
declare -i VERBOSE=1
declare -i DEBUG=0
declare -i ASSUME_YES=0

show_help() {
  cat <<EOT
usage: $PRG [OPTIONS]

Stage Options:
  -0|--do-create-text-cache      Create text cache from source files
  -1|--do-gen-citations          Generate citations for text chunks
  -2|--do-append-citations       Append citations to text database
  -3|--do-import-text-database   Import text into database
  -4|--do-embed                  Create vector embeddings
  -5|--do-test-query            Run test query
  -a|--all                      Run all stages (0-5) [default if no stage specified]

Processing Options:
  -y|--yes                      Assume yes to all prompts (non-interactive)
  -f|--force                    Force regeneration of citations
  -r|--reprocess-blank          Reprocess entries with blank citations

Configuration Options:
  -m|--model MODEL              Override citation model (unused currently)
  -M|--max-tokens TOKENS        Override max tokens (unused currently)
  -t|--temperature TEMP         Override temperature (unused currently)
  -c|--context CONTEXT          Override context (unused currently)

Other Options:
  -v|--verbose                  Increase verbosity
  -q|--quiet                    Decrease verbosity
  -D|--debug                    Enable debug mode
  -h|--help                     Show this help message

Configuration:
  Settings can be customized in okusiassociates.build.conf
  See $KB.build.conf.example for format

Examples:
  $PRG                          # Run all stages (same as -a)
  $PRG -0                       # Only create text cache
  $PRG -1 -2                    # Only generate and append citations
  $PRG -a -y                    # Run all stages non-interactively
  $PRG -4 -5 -y                 # Embed and test query, no prompts
EOT
  exit
}

# Parse command line arguments
while (($#)); do
  case "$1" in
    -0|--do-create-text-cache) do_create_text_cache=1 ;;
    -1|--do-gen-citations) do_gen_citations=1 ;;
    -2|--do-append-citations) do_append_citations=1 ;;
    -3|--do-import-text-database) do_import_text_database=1 ;;
    -4|--do-embed) do_embed=1 ;;
    -5|--do-test-query) do_test_query=1 ;;

    -a|--all)
      do_create_text_cache=1
      do_gen_citations=1
      do_append_citations=1
      do_import_text_database=1
      do_embed=1
      do_test_query=1
      ;;
    -y|--yes|--assume-yes)
      ASSUME_YES=1
      ;;
    -f|--force|--force-update)
      FORCE=1
      ;;
    -r|--reprocess-blank)
      REPROCESS_BLANK=1
      ;;
    -m|--model)
      shift; MODEL="${1:-$MODEL}"
      ;;
    -M|--max-tokens)
      shift; MAX_TOKENS=${1:-$MAX_TOKENS}
      ;;
    -t|--temperature)
      shift; TEMPERATURE="${1:-$TEMPERATURE}"
      ;;
    -c|--context)
      shift; BROAD_CONTEXT="${1:-$BROAD_CONTEXT}"
      ;;

    -N|--not-dry-run|--no-dry-run|--notdryrun|--nodryrun) DRY_RUN=0 ;;
    -n|--dry-run|--dryrun) DRY_RUN=1 ;;
    -q|--quiet) VERBOSE=0 ;;
    -v|--verbose) VERBOSE+=1 ;;
    -D|--debug) DEBUG=1; VERBOSE=2 ;;
    -h|--help) show_help; exit 0 ;;
    -[012345ayfrMmtcNnqvDh]*) #shellcheck disable=SC2046 #split up single options
      set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}"
      ;;
    -*) die 22 "Invalid option '$1'" ;;
    *) die 2 "Invalid argument '$1'"
      ;;
  esac
  shift
done

# If no specific stage flags provided, run all stages
if (( !(do_create_text_cache || do_gen_citations || do_append_citations || do_import_text_database || do_embed || do_test_query) )); then
  do_create_text_cache=1
  do_gen_citations=1
  do_append_citations=1
  do_import_text_database=1
  do_embed=1
  do_test_query=1
fi

# Validation checks
validate_tools() {
  local -a required_tools=()
  ((do_gen_citations)) && required_tools+=("gen-citations")
  ((do_append_citations)) && required_tools+=("append-citations")
  ((do_import_text_database || do_embed || do_test_query)) && required_tools+=("customkb")
  
  local tool
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      die 1 "Required tool '$tool' not found in PATH"
    fi
  done
  
  # Check staging_text directory exists if needed
  if ((do_gen_citations || do_append_citations || do_import_text_database)); then
    if [[ ! -d "$staging_text" ]]; then
      error "Directory '$staging_text' not found"
      error "Run with -0 flag first to create text cache"
      exit 1
    fi
  fi
}

validate_tools


if ((do_create_text_cache)); then
  cd "$KBdir"
  time "$PRGDIR"/create_text_cache.sh
  chownsysadmin "$KBdir"
fi

if ((do_gen_citations)); then
  cd "$KBdir"
  declare -a genopts=()
  ((REPROCESS_BLANK)) && genopts+=(--reprocess-blank)
  ((FORCE)) && genopts+=(--force)

  gen-citations  \
      --database "$dbname" \
      --context "$KB_CONTEXT" \
      --model "$GEN_MODEL" \
      --temperature "$GEN_TEMPERATURE" \
      --max-tokens "$GEN_MAX_TOKENS" \
      --verbose --verbose \
      --parallel "$GEN_PARALLEL" \
      "${genopts[@]}" \
      "$staging_text"
  chownsysadmin "$KBdir"
fi

if ((do_append_citations)); then
  cd "$KBdir"
  append-citations  \
    --database "$dbname" \
    --no-backup \
    --context "$KB_CONTEXT" \
    $( ((VERBOSE)) || echo '\--verbose') \
    "$staging_text"
  chownsysadmin "$KBdir"
fi

if ((do_import_text_database)); then
  cd "$KBdir"
  if (( ! remove_database)); then
    if [[ -f "$dbname" ]]; then
      if ((ASSUME_YES)); then
        vecho "$dbname exists. Removing it due to --yes flag."
        remove_database=1
      else
        vecho "$dbname may need to be deleted before proceeding."
        read -rp "$PRG: Remove $dbname? y/n " yn
        if [[ ${yn,,} != 'y' ]]; then
          remove_database=0
          read -rp "$PRG: Continue processing with existing database '$dbname'? y/n " yn
          [[ ${yn,,} == 'y' ]] || exit 1
        else
          remove_database=1
        fi
      fi
    fi
  fi
  (( ! remove_database)) || {
    sqlite3 "$dbname" "DROP TABLE IF EXISTS docs;"
    rm -f "$faissname" "$bm25name"
  }
  time customkb database "$cfgname" "$staging_text"
  chownsysadmin "$KBdir"
fi


declare -i remove_faiss=0

if ((do_embed)); then
  cd "$KBdir"

    if [[ -f "$faissname" ]]; then
      if ((ASSUME_YES)); then
        vecho "$faissname exists. Removing it due to --yes flag."
        remove_faiss=1
      else
        vecho "$faissname may need to be deleted before proceeding."
        read -rp "Remove $faissname? y/n " yn
        if [[ ${yn,,} != 'y' ]]; then
          remove_faiss=0
          read -rp "Continue processing with existing vector database '$faissname'? y/n " yn
          [[ ${yn,,} == 'y' ]] || exit 1
        else
          remove_faiss=1
        fi
      fi
    fi
    (( ! remove_faiss)) || rm -f "$faissname"

  time customkb embed "$cfgname"
  chownsysadmin "$KBdir"
fi

if ((do_test_query)); then
  cd "$KBdir"
  # test kb
  #customkb query "$cfgname" 'What is a PMA?'
  time customkb query "$cfgname" "$TEST_QUERY"
fi

#fin
