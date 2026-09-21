#!/bin/bash
# import-staging-text — collect source text files into staging.text/ for KB build
set -euo pipefail
shopt -s inherit_errexit

declare -rx PATH=/usr/local/bin:/usr/bin:/bin

declare -r VERSION=1.0.0
#shellcheck disable=SC2155
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*} SCRIPT_NAME=${SCRIPT_PATH##*/}

# Root escalation (required for /ai/media/ access)
((EUID)) && [[ ${KIST_TEST_SOURCE:-} != 1 ]] && { sudo "$0" "$@"; exit $?; } ||:

# Messaging
declare -i VERBOSE=1

if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' YELLOW='' CYAN='' NC=''
fi

# Define Messaging Functions (add/remove as required by the specific script)
_msg() { >&2 printf "$SCRIPT_NAME: $1 %s\n" "${@:2}"; }
error()   { _msg "$RED✗$NC" "$@"; }
die()     { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }
warn()    { _msg "$YELLOW▲$NC" "$@"; }
info()    { ((VERBOSE)) || return 0; _msg "$CYAN◉$NC" "$@"; }

# Frontmatter metadata stamping — shared machinery (load_metadata, yaml_quote,
# emit_frontmatter, write_stamped + META/_rv globals) lives in the dual-mode
# kb-stamp-frontmatter tool; sourcing it defines functions only.
KB_STAMP_LIB=$(command -v kb-stamp-frontmatter) || KB_STAMP_LIB=/ai/scripts/customkb.bash/kb-stamp-frontmatter
[[ -f $KB_STAMP_LIB ]] || { >&2 echo "$SCRIPT_NAME: kb-stamp-frontmatter not found"; exit 3; }
#shellcheck source=/ai/scripts/customkb.bash/kb-stamp-frontmatter
source "$KB_STAMP_LIB"
declare -r KB_STAMP_LIB

# Globals
declare -r VECTORDBS=${VECTORDBS:-/var/lib/vectordbs}
declare -r WORKSHOPS="$SCRIPT_DIR"/workshops
declare -r STAGING_TEXT="$SCRIPT_DIR"/staging.text
# Read transcripts from the canonical pool, NOT channels/. The channels/ tree is a
# graph of slug/cross-ref symlinks into this pool; `find -L` over it follows
# self-referential links (`<id> -> videos/<id>`) and detects filesystem loops, while
# revisiting the same ~1.6k transcripts ~73x. The pool holds one real dir per video.
declare -r TRANSCRIPTS_DIR=/ai/media/youtube/videos
declare -r TRANSDIR="$WORKSHOPS"/yt_transcripts

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
  cd "$WORKSHOPS"
  rm -rf "${TRANSDIR:?}"
  mkdir -p "$TRANSDIR"

  local -a files=()
  readarray -t files < <(
    find "$TRANSCRIPTS_DIR" -mindepth 2 -maxdepth 2 -type f -name '*.transcript.txt' | sort -u
  )
  local -i total_files=${#files[@]}
  >&2 printf '%d transcript files\n' "$total_files"

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
      # Source in a subshell with strict mode off so its vars never leak into ours
      # and a malformed file degrades to an empty slug rather than aborting the run.
      # video_dir comes from video_info.sh itself (it declares its own video_dir,
      # e.g. .../channels/<id>/videos/<vid>), not from our canonical-pool file_dir.
      vals=$(
        set +euo pipefail
        # shellcheck source=/dev/null
        source "$file_dir"/video_info.sh 2>/dev/null
        # shellcheck disable=SC2154  # video_dir: set by the sourced video_info.sh above
        ch="${video_dir%%/videos/*}"/channel_info.sh
        # shellcheck source=/dev/null
        [[ ! -f $ch ]] || source "$ch" 2>/dev/null
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
      } > "$TRANSDIR"/"$newfile"
      touch -r "$file" -- "$TRANSDIR"/"$newfile"
    else
      cp -p -- "$file" "$TRANSDIR"/"$newfile"
    fi
  done
}

collect_files() {
  cd "$WORKSHOPS"
  #shellcheck disable=SC2155
  local -r REAL_WORKSHOPS=$(realpath -- "$PWD")

  >&2 printf 'Finding md and txt files in %s/\n' "$PWD"
  local -a files=()
  # .transcripts/ dirs hold untranslated source-language originals kept beside their
  # translations (e.g. sumarah/lia); only the translations are corpus content.
  # -L is INTENTIONAL: workshops/ may hold required symlinks to content that must be
  # collected. `readlink -f` canonicalises each hit and `sort -u` dedupes, so symlink
  # aliases collapse to a single real file — do NOT strip -L to "fix duplicates".
  readarray -t files < <(
    find -L . -type f \( -name '*.txt' -o -name '*.md' \) ! -name 'README.md' \
        ! -path '*/.transcripts/*' \
        -exec readlink -f -- {} + \
      | sort -u
  )
  >&2 printf '%d embed files\n' "${#files[@]}"

  local -- file rel base
  local -i file_count=0
  for file in "${files[@]}"; do
    rel=${file#"$REAL_WORKSHOPS"/}
    if [[ $rel == */* ]]; then
      mkdir -p "$STAGING_TEXT"/"${rel%/*}"
    fi
    base=${file##*/}
    if [[ $base == *.md && -n ${META[$base]:-} ]]; then
      write_stamped "$file" "$STAGING_TEXT"/"$rel" "${META[$base]}"
    else
      cp -p -- "$file" "$STAGING_TEXT"/"$rel"
    fi
    file_count+=1
    [[ -t 2 ]] && >&2 printf '\r%d files ' "$file_count" ||:
  done
  [[ -t 2 ]] && >&2 echo ||:
}

cleanup_staging() {
  cd "$STAGING_TEXT"
  >&2 printf 'Data cleanup in %s/\n' "$STAGING_TEXT"
  find "$STAGING_TEXT" -type f -size -10c -delete
  find-dupes "$STAGING_TEXT" --delete --force

  # Count real staged files only. NO -L: create_symlinks() later plants cross-KB
  # symlinks here (prosocial.world, wayang.net, docs_research); following them would
  # miscount foreign files and risk filesystem loops if an external tree links back.
  local -i total
  total=$(find "$STAGING_TEXT"/ -type f | wc -l)
  >&2 printf '%d total files in %s\n' "$total" "$STAGING_TEXT"
}

create_symlinks() {
  cd "$STAGING_TEXT"
  ln -fs "$VECTORDBS"/prosocial.world/staging.text/ prosocial.world
  ln -fs "$VECTORDBS"/wayang.net/staging.text/mdfiles/ wayang.net
  ln -fs "$VECTORDBS"/appliedanthropology/docs/ docs_research
  ln -fs "$VECTORDBS"/appliedanthropology/README.md .
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

  cd "$WORKSHOPS" || die 3 "Directory ${WORKSHOPS@Q} not found"

  # Clear staging area
  rm -rf "${STAGING_TEXT:?}"
  mkdir -p "$STAGING_TEXT"

  load_metadata "$WORKSHOPS"/corpus-metadata.db

  process_transcripts

  collect_files

  cleanup_staging

  create_symlinks
}

[[ ${KIST_TEST_SOURCE:-} == 1 ]] || main "$@"
#fin
