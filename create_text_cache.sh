#!/bin/bash
#shellcheck disable=SC1091,SC2155
set -euo pipefail
((EUID)) && { sudo "$0" "$@"; exit; }
#shellcheck disable=SC2155
readonly -- PRG0="$(realpath -e -- "$0")"
readonly -- PRGDIR="${PRG0%/*}"

# workshops is the base directory 
# from where target .txt and .md files 
# are contained and found
readonly -- workshops="$PRGDIR"/workshops
cd "$workshops" # sanity check and rehoming dir # HOMING DIR
readonly -- real_workshops=$(realpath -e -- "$PWD")

readonly -- staging_text="$PRGDIR"/staging.text
#readonly -- real_staging_text=$(readlink -en -- "$staging_text")
# create and clear out the staging_text dir
rm -rf "${staging_text:?}"
mkdir -p "$staging_text"

declare -a files
declare -- file 

# TRANSCRIPTS
# create and clearout the transcripts dir
readonly -- transcripts_dir=/ai/media/youtube/channels
declare -- transdir="$workshops"/yt_transcripts
rm -rf "${transdir:?}"
mkdir -p "$transdir"

# -------------------------------------------------------------------------
# find and process all the transcript files (*.transcript.txt)
cd "$workshops" 
readarray -t files < <(
  find "$transcripts_dir" -type f -name '*.transcript.txt' | sort -u
  )
echo "${#files[@]} transcript files"
for file in "${files[@]}"; do
  newfile=$(basename -- "$file")
  dirname=$(dirname -- "$file")
  if source "$dirname"/video_info.sh 2>/dev/null; then
    if [[ -n "${video_name_slug:-}" ]]; then
      newfile="$video_name_slug".transcript.txt
    else
      >&2 echo "   !!! No video name slug for $newfile"
    fi
  else
    >&2 echo "   !!! No video info for $newfile"
  fi
  video_name_slug=''
	cp -p -- "$file" "$transdir"/"$newfile"
done
# clean up
find-dupes "$staging_text" -dP

# -------------------------------------------------------------------------
cd "$workshops" 
declare -i ccc=0
echo "Finding md and txt files in $PWD/"
readarray -t files < <(
  find -L . -type f \( -name '*.txt' -o -name '*.md' \) \
      -exec readlink -f -- {} \; \
    | sort -u
  )
echo "${#files[@]} embed files"
for file in "${files[@]}"; do
  subdir="$(dirname -- "$file")"
  subdir="${file/"$real_workshops/"/}"
  mkdir -p "$staging_text"/"$subdir"
  cp -p -- "$file" "$staging_text"/"$subdir"/"$(basename -- "$file")"
  ccc+=1
  echo -en "\r$ccc files "
done
echo

# locate into the staging_text
cd "$staging_text"

# data cleanup =======================================================================
echo "Data cleanup in $staging_text/"
find "$staging_text" -type f -size -10c -delete
find-dupes "$staging_text" -dP
echo "$(find -L "$staging_text"/ -type f |wc -l) total files in $staging_text"

# add repositories from other locations ==============================================
ln -fs "$VECTORDBS"/prosocial.world/embed_data.text/ prosocial.world
ln -fs "$VECTORDBS"/wayang.net/embed_data/mdfiles/ wayang.net
ln -fs "$VECTORDBS"/appliedanthropology/docs/ docs_research
ln -fs "$VECTORDBS"/appliedanthropology/README.md

# create staging.text zip file for yatti.id ==========================================
cd "$PRGDIR"
echo "Create staging.text.zip file for yatti.id"
rm -f staging.text.zip
zip -r -9 staging.text.zip "$staging_text"/

#fin
