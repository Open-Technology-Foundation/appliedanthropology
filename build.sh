#!/bin/bash
set -Eeuo pipefail

declare -- cfgname=appliedanthropology
declare -- dbdir="$VECTORDBS"/"$cfgname"
cd "$dbdir"

cln -Nq

declare -- dbname="$cfgname".db 

if [[ -f "$dbname" ]]; then
	echo "$(basename -- "$dbname").docs will need to be dropped before proceeding."
	read -r -p "Remove $dbname.docs? y/n " yn
	[[ ${yn,,} == 'y' ]] || exit 1
  sqlite3 "$dbname" "DROP TABLE IF EXISTS docs;"
  rm -f "$cfgname".{faiss,bm25}
fi

"$PWD"/create_text_cache.sh

customkb database "$cfgname" embed_data.text/*

customkb categorize "$cfgname" --full --import --max-concurrent 42 --sampling 3-5-3

customkb embed "$cfgname"

customkb query "$cfgname" \
    'Explain "dharma" as it is understood and embedded within contemporary Balinese Hinduism by Balinese who identify as Hindu Bali.' \
    -q --prompt-template instructive

#fin
