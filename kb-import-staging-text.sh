#!/bin/bash
# import-staging-text — collect source text files into staging.text/ for KB build
#
# Dual-purpose: executed for a KB build, or sourced by a test harness to reach the
# functions. Everything above the source fence only declares; strict mode, PATH
# pinning, root escalation and the library load are script-mode only, below it.

# Idempotent initialisation: the globals are readonly, so a second `source` in the
# same shell must skip this block rather than trip over them.
[[ -v KB_IMPORT_STAGING_LOADED ]] || {
  declare -r KB_IMPORT_STAGING_LOADED=1
  declare -r VERSION=1.0.0
  # PATH is scoped to this one command: the script-wide `declare -rx PATH` has to stay
  # below the source fence (setting it here would replace a sourcing caller's PATH),
  # yet realpath must not be looked up through whatever PATH the caller supplied.
  #shellcheck disable=SC2155  # realpath of this file's own path cannot fail
  declare -r SCRIPT_PATH=$(PATH=/usr/bin:/bin realpath -- "${BASH_SOURCE[0]}")
  declare -r SCRIPT_DIR=${SCRIPT_PATH%/*} SCRIPT_NAME=${SCRIPT_PATH##*/}

  declare -i VERBOSE=1

  if [[ -t 1 && -t 2 ]]; then
    declare -r RED=$'\033[0;31m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
  else
    declare -r RED='' YELLOW='' CYAN='' NC=''
  fi

  declare -r VECTORDBS=${VECTORDBS:-/var/lib/vectordbs}
  declare -r WORKSHOPS="$SCRIPT_DIR"/workshops
  declare -r STAGING_TEXT="$SCRIPT_DIR"/staging.text
  # Read transcripts from the canonical pool, NOT channels/. The channels/ tree is a
  # graph of slug/cross-ref symlinks into this pool; `find -L` over it follows
  # self-referential links (`<id> -> videos/<id>`) and detects filesystem loops, while
  # revisiting the same ~1.6k transcripts ~73x. The pool holds one real dir per video.
  declare -r TRANSCRIPTS_DIR=/ai/media/youtube/videos
  declare -r TRANSDIR="$WORKSHOPS"/yt_transcripts
  # Resolved and made readonly in script mode, below the source fence.
  declare -- KB_STAMP_LIB=''
}

# Define Messaging Functions (add/remove as required by the specific script)
_msg() { >&2 printf "$SCRIPT_NAME: $1 %s\n" "${@:2}"; }
error()   { _msg "$RED✗$NC" "$@"; }
die()     { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }
warn()    { _msg "$YELLOW▲$NC" "$@"; }
info()    { ((VERBOSE)) || return 0; _msg "$CYAN◉$NC" "$@"; }

show_help() {
  cat <<HELP
$SCRIPT_NAME $VERSION - Collect source text files into staging.text/ for KB build

Usage: $SCRIPT_NAME [OPTIONS]

Options:
  -v    Increase verbosity
  -q    Quiet mode
  -V    Show version
  -h    Show this help

Collects .txt and .md files from workshops/ and YouTube transcripts
from $TRANSCRIPTS_DIR into staging.text/ for knowledgebase embedding.
HELP
}

process_transcripts() {
  cd -- "$WORKSHOPS" || die 3 "Directory ${WORKSHOPS@Q} not found"

  # List BEFORE wiping TRANSDIR: a failed find must not be mistaken for "no
  # transcripts" after the previous set has already been removed.
  local -- found
  local -a files=()
  found=$(find -- "$TRANSCRIPTS_DIR" -mindepth 2 -maxdepth 2 -type f -name '*.transcript.txt' | sort -u) \
    || die 1 "Failed to list transcripts in ${TRANSCRIPTS_DIR@Q}"
  [[ -z $found ]] || readarray -t files <<<"$found"
  local -i total_files=${#files[@]}
  info "$total_files transcript files"

  rm -rf -- "${TRANSDIR:?}" || die 1 "Failed to clear ${TRANSDIR@Q}"
  mkdir -p -- "$TRANSDIR" || die 1 "Failed to create ${TRANSDIR@Q}"

  local -- file newfile file_dir video_name_slug
  local -- vals vtitle vurl vchannel
  local -i warnings=0
  for file in "${files[@]}"; do
    newfile=${file##*/}
    file_dir=${file%/*}
    video_name_slug=''
    vtitle='' vurl='' vchannel=''
    if [[ -f "$file_dir"/video_info.sh ]]; then
      # video_info.sh is a sourceable bash file (`declare -- video_name_slug=...`).
      # Source in a subshell so its vars never leak into ours. A malformed file
      # aborts only the subshell; `|| true` then degrades it to an empty slug rather
      # than aborting the run.
      # video_dir comes from video_info.sh itself (it declares its own video_dir,
      # e.g. .../channels/<id>/videos/<vid>), not from our canonical-pool file_dir.
      vals=$(
        # shellcheck source=/dev/null
        source -- "$file_dir"/video_info.sh 2>/dev/null
        ch=${video_dir:-}
        ch="${ch%%/videos/*}"/channel_info.sh
        # shellcheck source=/dev/null
        [[ ! -f $ch ]] || source -- "$ch" 2>/dev/null
        printf '%s\x1f%s\x1f%s\x1f%s' \
          "${video_name_slug:-}" "${video_title:-}" "${video_url:-}" "${channel_name:-}"
      ) || true
      IFS=$'\x1f' read -r video_name_slug vtitle vurl vchannel <<<"$vals"
      video_name_slug=${video_name_slug//[^a-zA-Z0-9._-]/}
    fi
    if [[ -n $video_name_slug ]]; then
      newfile="$video_name_slug".transcript.txt
    else
      warnings+=1
      warn "$warnings/$total_files: No video name slug for $newfile"
    fi
    if [[ -n $vtitle || -n $vchannel || -n $vurl ]]; then
      { emit_frontmatter '' "$vchannel" "$vtitle" '' "$vurl" 'video-transcript'
        cat -- "$file"
      } > "$TRANSDIR"/"$newfile" || die 1 "Failed to write ${newfile@Q}"
      touch -r "$file" -- "$TRANSDIR"/"$newfile" || die 1 "Failed to set mtime on ${newfile@Q}"
    else
      cp -p -- "$file" "$TRANSDIR"/"$newfile" || die 1 "Failed to copy ${file@Q}"
    fi
  done
}

collect_files() {
  cd -- "$WORKSHOPS" || die 3 "Directory ${WORKSHOPS@Q} not found"
  local -- real_workshops
  real_workshops=$(realpath -- "$PWD") || die 1 "Cannot resolve ${WORKSHOPS@Q}"

  info "Finding md and txt files in $PWD/"
  local -- found
  local -a files=()
  # .transcripts/ dirs hold untranslated source-language originals kept beside their
  # translations (e.g. sumarah/lia); only the translations are corpus content.
  # -L is INTENTIONAL: workshops/ may hold required symlinks to content that must be
  # collected. `readlink -f` canonicalises each hit and `sort -u` dedupes, so symlink
  # aliases collapse to a single real file — do NOT strip -L to "fix duplicates".
  # Captured, not fed through <( ): a failed or partial find must abort the build
  # rather than be staged as if the short list were complete.
  found=$(
    find -L . -type f \( -name '*.txt' -o -name '*.md' \) ! -name 'README.md' \
        ! -path '*/.transcripts/*' \
        -exec readlink -f -- {} + \
      | sort -u
  ) || die 1 "Failed to list source files in ${WORKSHOPS@Q}"
  [[ -z $found ]] || readarray -t files <<<"$found"
  info "${#files[@]} embed files"

  local -- file rel base
  local -i file_count=0
  for file in "${files[@]}"; do
    rel=${file#"$real_workshops"/}
    if [[ $rel == */* ]]; then
      mkdir -p -- "$STAGING_TEXT"/"${rel%/*}" || die 1 "Failed to create directory for ${rel@Q}"
    fi
    base=${file##*/}
    if [[ $base == *.md && -n ${META[$base]:-} ]]; then
      write_stamped "$file" "$STAGING_TEXT"/"$rel" "${META[$base]}"
    else
      cp -p -- "$file" "$STAGING_TEXT"/"$rel" || die 1 "Failed to copy ${file@Q}"
    fi
    file_count+=1
    #bcscheck disable=BCS0705  # \r progress meter: info() always appends a newline
    ((VERBOSE)) && [[ -t 2 ]] && >&2 printf '\r%d files ' "$file_count" ||:
  done
  #bcscheck disable=BCS0705  # terminates the \r progress meter above
  ((VERBOSE)) && [[ -t 2 ]] && >&2 echo ||:
}

cleanup_staging() {
  cd -- "$STAGING_TEXT" || die 3 "Directory ${STAGING_TEXT@Q} not found"
  info "Data cleanup in $STAGING_TEXT/"
  find -- "$STAGING_TEXT" -type f -size -10c -delete \
    || die 1 "Failed to prune near-empty files in ${STAGING_TEXT@Q}"
  find-dupes --delete --force -- "$STAGING_TEXT" \
    || die 1 "find-dupes failed in ${STAGING_TEXT@Q}"

  # Count real staged files only. NO -L: create_symlinks() later plants cross-KB
  # symlinks here (prosocial.world, wayang.net, docs_research); following them would
  # miscount foreign files and risk filesystem loops if an external tree links back.
  local -i total
  total=$(find -- "$STAGING_TEXT"/ -type f | wc -l) || die 1 "Failed to count files in ${STAGING_TEXT@Q}"
  info "$total total files in $STAGING_TEXT"
}

create_symlinks() {
  cd -- "$STAGING_TEXT" || die 3 "Directory ${STAGING_TEXT@Q} not found"
  ln -fs -- "$VECTORDBS"/prosocial.world/staging.text/ prosocial.world
  ln -fs -- "$VECTORDBS"/wayang.net/staging.text/mdfiles/ wayang.net
  ln -fs -- "$VECTORDBS"/appliedanthropology/docs/ docs_research
  ln -fs -- "$VECTORDBS"/appliedanthropology/README.md .
}

main() {
  while (($#)); do
    case $1 in
      -v|--verbose)  VERBOSE+=1 ;;
      -q|--quiet)    VERBOSE=0 ;;
      -V|--version)  printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"; exit 0 ;;
      -h|--help)     show_help; exit 0 ;;
      -[vqVh]?*)     set -- "${1:0:2}" "-${1:2}" "${@:2}"; continue ;;
      -*)            die 22 "Invalid option ${1@Q}" ;;
      *)             die 2 "Invalid argument ${1@Q}" ;;
    esac
    shift
  done
  readonly VERBOSE

  cd -- "$WORKSHOPS" || die 3 "Directory ${WORKSHOPS@Q} not found"

  rm -rf -- "${STAGING_TEXT:?}" || die 1 "Failed to clear ${STAGING_TEXT@Q}"
  mkdir -p -- "$STAGING_TEXT" || die 1 "Failed to create ${STAGING_TEXT@Q}"

  load_metadata "$WORKSHOPS"/corpus-metadata.db

  process_transcripts

  collect_files

  cleanup_staging

  create_symlinks
}

# --- source fence ---
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0

# --- Script mode only ---
set -euo pipefail
shopt -s inherit_errexit

declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# Root escalation (required for /ai/media/ access)
((EUID)) && { sudo -- "$0" "$@"; exit $?; } ||:

# Frontmatter metadata stamping — shared machinery (load_metadata, yaml_quote,
# emit_frontmatter, write_stamped + META/_rv globals) lives in the dual-mode
# kb-stamp-frontmatter tool; sourcing it defines functions only.
KB_STAMP_LIB=$(command -v kb-stamp-frontmatter) || KB_STAMP_LIB=/ai/scripts/customkb.bash/kb-stamp-frontmatter
[[ -f $KB_STAMP_LIB ]] || die 3 "kb-stamp-frontmatter not found at ${KB_STAMP_LIB@Q}"
#shellcheck source=/ai/scripts/customkb.bash/kb-stamp-frontmatter
source -- "$KB_STAMP_LIB"
readonly KB_STAMP_LIB

# sqlite3 runs inside < <( ) in load_metadata(), so without this check a missing
# binary would stage the whole corpus unstamped and say nothing.
declare -- cmd
for cmd in find-dupes sqlite3; do
  command -v "$cmd" >/dev/null || die 18 "Required: ${cmd@Q}"
done

main "$@"
#fin
