#!/bin/bash
# evobio-fetch.sh — harvest PMC Open-Access full-text JATS XML for the
# evolutionary-biology fold-in, fetched per human-behavioural-evolution subtopic
# so coverage spans the whole map (closing the alloparenting gap the spike found).
#
# For each subtopic: esearch db=pmc on (journal-allowlist) AND (subtopic terms)
# AND "open access"[filter], then efetch rettype=full retmode=xml per new PMCID
# into workshops/evobio/raw/PMC<id>.xml. PMCIDs are de-duplicated across subtopics
# (a hit in two subtopics is fetched once). Well-formedness is validated with
# xmllint and retried once; a 0.4s politeness delay separates efetch calls.
#
# Env (optional): NCBI_API_KEY — raises the E-utilities rate ceiling; the delay
# is kept regardless so we stay well-mannered.
set -euo pipefail
# Bash version guard — inherit_errexit (4.4+), ${var@Q} (4.4+) and associative
# arrays (4.0+) below need a modern Bash; fail early with a clear message.
(( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 2) )) \
  || { >&2 echo "${0##*/}: requires Bash >= 5.2"; exit 2; }
shopt -s inherit_errexit

declare -r SCRIPT_NAME=${0##*/}
declare -r EUTILS='https://eutils.ncbi.nlm.nih.gov/entrez/eutils'
declare -r SELF_DIR=${0%/*}
declare -r RAWDIR="$SELF_DIR/workshops/evobio/raw"
# Per-subtopic quota. The plan's estimate was ~100–140, but at 130 the finite OA
# pool yielded only 475 kept — below the 600–900 target. Lifted to 250 (env-
# overridable) so the two capped subtopics (alloparenting: 318 available;
# cultural-evolution) can contribute more, clearing the locked ≥500 kept floor.
declare -ri RETMAX=${RETMAX:-250}
declare -ri MAX_TRIES=2
declare -ri CONNECT_TIMEOUT=10 MAX_TIME=120

# Journal allowlist — the spike's set, moderately widened. Precision is protected
# by the AND'd subtopic terms, so a slightly wider net is safe. Built into a
# "(...[journal] OR ...)" clause by journals_clause() to keep lines within 120c.
declare -ra JOURNAL_LIST=(
  'Evol Hum Sci' 'Evol Hum Behav' 'Hum Nat' 'Behav Ecol Sociobiol'
  'Am J Biol Anthropol' 'Evol Psychol' 'Adapt Human Behav Physiol'
  'Philos Trans R Soc Lond B Biol Sci' 'Proc Biol Sci'
)

# 8 subtopics spanning the human-behavioural-evolution map: 'label|term-clause'.
# The term clauses are long search-query data literals; BCS1201 (>120c) is an
# accepted local deviation here — breaking a clause mid-string harms clarity.
declare -ra SUBTOPICS=(
  'cooperation-reciprocity|"human cooperation"[tiab] OR "reciprocal altruism"[tiab] OR "reciprocity"[tiab] OR "cooperative behavior"[tiab]'
  'punishment-norms|"altruistic punishment"[tiab] OR "third-party punishment"[tiab] OR "social norms"[tiab] OR "norm enforcement"[tiab]'
  'primate-sociality|"primate social"[tiab] OR "coalition"[tiab] OR "dominance hierarchy"[tiab] OR "social bond"[tiab]'
  'human-origins|"human evolution"[tiab] OR "hominin"[tiab] OR "hunter-gatherer"[tiab] OR "paleolithic"[tiab]'
  'life-history-alloparenting|"life history"[tiab] OR "cooperative breeding"[tiab] OR "alloparent"[tiab] OR "allomaternal"[tiab]'
  'costly-signalling-morality|"costly signaling"[tiab] OR "costly signalling"[tiab] OR "evolution of morality"[tiab] OR "moral behavior"[tiab]'
  'empathy-social-emotion|"empathy"[tiab] OR "prosocial behavior"[tiab] OR "social emotion"[tiab] OR "compassion"[tiab]'
  'cultural-evolution|"cultural evolution"[tiab] OR "social learning"[tiab] OR "cultural transmission"[tiab] OR "gene-culture coevolution"[tiab]'
)

# Messaging — canonical _msg()/error()/warn()/info()/die() (icons per house style).
if [[ -t 2 ]]; then
  declare -r RED=$'\033[0;31m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' YELLOW='' CYAN='' NC=''
fi
_msg()  { >&2 printf '%s: %s %s\n' "$SCRIPT_NAME" "$1" "${*:2}"; }
error() { _msg "${RED}✗${NC}" "$@"; }
warn()  { _msg "${YELLOW}▲${NC}" "$@"; }
info()  { _msg "${CYAN}◉${NC}" "$@"; }
die()   { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }

# Build the "(\"J1\"[journal] OR \"J2\"[journal] ...)" allowlist clause.
journals_clause() {
  local -- out='' j=''
  for j in "${JOURNAL_LIST[@]}"; do
    out+="${out:+ OR }\"$j\"[journal]"
  done
  printf '(%s)' "$out"
}

# esearch db=pmc for one term; prints PMC UIDs one per line. Returns non-zero if
# the curl call fails, so callers can surface (not silently swallow) a network error.
esearch_ids() {
  local -- term=$1 resp=''
  local -a args=(
    --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME"
    -sG "$EUTILS/esearch.fcgi"
    --data-urlencode 'db=pmc'
    --data-urlencode "term=$term"
    --data-urlencode "retmax=$RETMAX"
    --data-urlencode 'retmode=json'
  )
  [[ -n ${NCBI_API_KEY:-} ]] && args+=(--data-urlencode "api_key=$NCBI_API_KEY") ||:
  resp=$(curl "${args[@]}") || return 1
  jq -r '.esearchresult.idlist[]?' <<<"$resp"
}

# efetch one numeric PMCID with a well-formedness retry; returns 0 on a valid file.
# $id is validated numeric by the caller, so $out (always PMC-prefixed) is a safe
# pathname operand; -- guards are used where the tool supports them.
fetch_one() {
  local -- id=$1 out=$2 keyarg=''
  [[ -n ${NCBI_API_KEY:-} ]] && keyarg="&api_key=$NCBI_API_KEY" ||:
  local -i try=0
  for ((try=1; try<=MAX_TRIES; try+=1)); do
    if curl -s --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
         "$EUTILS/efetch.fcgi?db=pmc&id=$id&rettype=full&retmode=xml$keyarg" -o "$out" \
       && [[ -s $out ]] && xmllint --noout "$out" 2>/dev/null; then
      return 0
    fi
    sleep 0.4
  done
  rm -f -- "$out"
  return 1
}

main() {
  local -- t='' curl_missing='' journals='' ids_raw=''
  for t in curl jq xmllint; do
    command -v "$t" >/dev/null || curl_missing+="$t "
  done
  [[ -z ${curl_missing:-} ]] || die 18 "missing tools: $curl_missing"

  mkdir -p "$RAWDIR" || die 1 "cannot create ${RAWDIR@Q}"
  journals=$(journals_clause)

  local -A SEEN=()
  local -i ok=0 fail=0 skip_seen=0
  local -- entry='' label='' term='' id='' out=''
  local -a ids=()

  for entry in "${SUBTOPICS[@]}"; do
    label=${entry%%|*}
    term="$journals AND (${entry#*|}) AND \"open access\"[filter]"
    if ! ids_raw=$(esearch_ids "$term"); then
      warn "esearch failed for $label; skipping subtopic"
      continue
    fi
    ids=()
    [[ -n $ids_raw ]] && mapfile -t ids <<<"$ids_raw" ||:
    info "subtopic=$label ids=${#ids[@]}"
    for id in "${ids[@]}"; do
      [[ -n $id ]] || continue
      # $id is external (from the esearch JSON) — validate before it reaches a URL
      # or a pathname. PMC UIDs are always digits.
      [[ $id =~ ^[0-9]+$ ]] || { warn "skipping non-numeric id ${id@Q}"; continue; }
      if [[ -n ${SEEN[$id]:-} ]]; then
        skip_seen+=1; continue
      fi
      SEEN[$id]=1
      out="$RAWDIR/PMC$id.xml"
      if [[ -s $out ]] && xmllint --noout "$out" 2>/dev/null; then
        ok+=1; continue          # already harvested in a prior run
      fi
      if fetch_one "$id" "$out"; then
        ok+=1
      else
        fail+=1; warn "fetch/parse failed for PMC$id"
      fi
      sleep 0.4
    done
    info "done $label — running totals ok=$ok fail=$fail dup=$skip_seen"
  done

  info "TOTAL unique=${#SEEN[@]} fetched=$ok failed=$fail cross-subtopic-dups=$skip_seen into $RAWDIR"
}

main "$@"
#fin
