#!/usr/bin/env python3
"""Extract narrative-section prose (Abstract/Intro/Discussion/Conclusion) from PMC
JATS XML into staging-ready .md for the evobio fold-in. Drops Methods, Results,
tables, figures, reference lists. Inline citation handling keeps author names.

Adapted from the 2026-07-23 spike extract.py with the three EVAL.md fixes:
  1. Preserve author text inside citation xrefs — drop <xref ref-type="bibr"> only
     when its rendered text is a pure numeric/bracket citation; otherwise flatten
     (so "Smith (2020) found" keeps "Smith ... found").
  2. Collapse comma-runs anywhere (fixes page-cites like "(Langlitz,, p. 127)").
  3. De-dup a block whose (heading, first-paragraph) repeats the previous block
     (fixes the observed "## Introduction" doubling).

Layout: reads workshops/evobio/raw/*.xml, writes workshops/evobio/PMC<id>-<slug>.md.
"""
import re
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / 'workshops' / 'evobio' / 'raw'
OUT = HERE / 'workshops' / 'evobio'
MIN_WORDS = 400

KEEP_SECTYPE = ('intro', 'background', 'discussion', 'conclusion')
KEEP_TITLE = re.compile(
    r'\b(introduction|background|discussion|conclusion|conclusions|general discussion)\b', re.I)
DROP_BLOCK = {'table-wrap', 'fig', 'ref-list', 'table', 'disp-formula', 'graphic',
              'supplementary-material'}
DROP_INLINE = {'inline-formula', 'label'}
# A pure citation marker: optional bracket, then only digits/commas/semicolons/
# whitespace/dashes, optional closer. "[12]", "(3, 4)", "5-7" -> drop; "Smith 2020" stays.
CITE_RE = re.compile(r'^[\[(]?[\d,;\s–—-]+[\])]?$')


def norm(s):
  # Order matters: structure-removing passes (empty citation shells) run BEFORE
  # the punctuation-tidying passes, because removing an empty [] can itself create
  # a fresh dangling "(x, )" that the comma-before-closer rule must then catch.
  s = re.sub(r'\s+', ' ', s or '').strip()
  s = re.sub(r',(\s*,)+', ',', s)                 # fix 2: collapse comma runs
  # Empty citation shells left by dropped numeric xrefs: "[]", "[–]" (from a
  # dropped "[4–6]" range), "[, ]". Excludes digits so a real interval "[0, 1]"
  # is never removed.
  s = re.sub(r'\[[\s,;–—-]*\]', '', s)
  s = re.sub(r'\(\s*[;,\s–—-]*\)', '', s)  # empty "( )"/"(, )" shells
  s = re.sub(r'[,;]\s*([)\]])', r'\1', s)         # dangling comma/semicolon before a closer
  s = re.sub(r'\s+([,.;:])', r'\1', s)            # no space before punctuation
  s = re.sub(r'\s+([)\]])', r'\1', s)             # no space before a closer
  s = re.sub(r'([(\[])\s+', r'\1', s)             # no space after an opener
  s = re.sub(r'\s{2,}', ' ', s).strip()
  return s


def text_of(el):
  tag = el.tag
  if tag in DROP_INLINE:
    return ''
  if tag == 'xref':
    inner = ''.join([el.text or ''] + [text_of(c) + (c.tail or '') for c in el])
    if el.get('ref-type') == 'bibr' and CITE_RE.match(inner.strip()):
      return ''                                   # fix 1: drop numeric-only citation
    return inner                                  # flatten — keep author name / label text
  parts = [el.text or '']
  for c in el:
    parts.append(text_of(c))
    parts.append(c.tail or '')
  return ''.join(parts)


def prune_block(root):
  parents = {c: p for p in root.iter() for c in p}
  for el in list(root.iter()):
    if el.tag in DROP_BLOCK:
      p = parents.get(el)
      if p is not None and el in list(p):
        p.remove(el)


def slug(s):
  s = re.sub(r'[^A-Za-z0-9]+', '-', (s or '').lower())
  return re.sub(r'-+', '-', s).strip('-')[:60] or 'x'


def first_text(root, path):
  el = root.find(path)
  return norm(text_of(el)) if el is not None else ''


def authors(art):
  names = []
  for contrib in art.findall('.//contrib-group//contrib'):
    if contrib.get('contrib-type') not in (None, 'author'):
      continue
    surname = first_text(contrib, './/surname')
    given = first_text(contrib, './/given-names')
    full = ' '.join(p for p in (given, surname) if p)
    if full:
      names.append(full)
  return names[:12]


def section_blocks(body):
  blocks = []
  for sec in body.findall('sec'):
    st = (sec.get('sec-type') or '').lower()
    title_el = sec.find('title')
    tt = norm(text_of(title_el)) if title_el is not None else ''
    if not (any(k in st for k in KEEP_SECTYPE) or KEEP_TITLE.search(tt)):
      continue
    if title_el is not None and title_el in list(sec):
      sec.remove(title_el)
    paras = [norm(text_of(p)) for p in sec.iter('p')]
    paras = [p for p in paras if len(p) > 1]
    if paras:
      blocks.append((tt or 'Section', '\n\n'.join(paras)))
  return blocks


def dedup_blocks(blocks):
  """fix 3: drop a block whose (heading, first-paragraph) repeats the previous."""
  out = []
  prev_key = None
  for h, t in blocks:
    key = (h, t.split('\n\n', 1)[0])
    if key == prev_key:
      continue
    out.append((h, t))
    prev_key = key
  return out


def extract(path):
  root = ET.parse(path).getroot()
  art = root.find('.//article') if root.tag != 'article' else root
  if art is None:
    return None
  prune_block(art)
  title = first_text(art, './/article-meta//article-title') or first_text(art, './/article-title')
  journal = first_text(art, './/journal-title')
  year = first_text(art, './/article-meta//pub-date/year') or first_text(art, './/pub-date/year')
  pmcid = first_text(art, './/article-id[@pub-id-type="pmc"]') or path.stem.replace('PMC', '')
  who = authors(art)
  blocks = []
  abstract_el = art.find('.//article-meta//abstract') or art.find('.//abstract')
  if abstract_el is not None:
    ab = norm(text_of(abstract_el))
    if ab:
      blocks.append(('Abstract', ab))
  body = art.find('.//body')
  if body is not None:
    blocks.extend(section_blocks(body))
  blocks = dedup_blocks(blocks)
  words = sum(len(b.split()) for _, b in blocks)
  if words < MIN_WORDS or not title:
    return {'skip': True, 'pmcid': pmcid, 'words': words, 'title': title}
  header = [f'# {title}', '']
  if who:
    header.append(f'- Authors: {", ".join(who)}')
  header += [
    f'- Journal: {journal} ({year})',
    f'- Year: {year}',
    f'- PMCID: PMC{pmcid}',
    f'- Source URL: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC{pmcid}/',
    '- License: PMC Open Access',
    '- Ingested: evobio (narrative sections only)',
    '',
  ]
  body_md = '\n\n'.join(f'## {h}\n\n{t}' for h, t in blocks)
  fname = f'PMC{pmcid}-{slug(title)}.md'
  (OUT / fname).write_text('\n'.join(header) + '\n' + body_md + '\n', encoding='utf-8')
  return {'skip': False, 'file': fname, 'words': words}


def main():
  OUT.mkdir(parents=True, exist_ok=True)
  kept = skipped = 0
  for path in sorted(RAW.glob('*.xml')):
    try:
      r = extract(path)
    except ET.ParseError as e:
      print(f'  ! parse error {path.name}: {e}')
      continue
    if r is None or r.get('skip'):
      skipped += 1
      w = r.get('words', 0) if r else 0
      print(f'  - skip {path.name} ({w} words)')
    else:
      kept += 1
      print(f"  ok {r['file']} ({r['words']} words)")
  print(f'\nkept={kept} skipped={skipped} -> {OUT}')


if __name__ == '__main__':
  main()
#fin
