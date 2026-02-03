#!/usr/bin/env python3
"""
Process Google Keep notes export:
1. Filter notes by relevance to specified domains
2. Transform JSON structure (remove status fields)
3. Convert HTML to markdown
4. Augment labels from inline hashtags
5. Output to new directory

Usage:
  ./process-keep-notes.py [--dry-run] [--verbose]

Domains: behavioral biology, dharma, politics, anthropology, and related fields
"""

import json
import os
import re
import sys
import argparse
from pathlib import Path
from html import unescape
from datetime import datetime

# === Configuration ===

# Default paths - override with command line args if needed
DEFAULT_SOURCE = Path("/home/sysadmin/takeout-20241108/Takeout/Keep")
DEFAULT_OUTPUT = Path("/var/lib/vectordbs/appliedanthropology/research/keep-notes")

SOURCE_DIR = DEFAULT_SOURCE
OUTPUT_DIR = DEFAULT_OUTPUT

# Labels that indicate relevance (case-insensitive)
RELEVANT_LABELS = {
    # Dharma/spirituality
    'dharma', 'mydharma', 'zen', 'buddhism', 'buddhist', 'meditation',
    'mindfulness', 'spirituality', 'contemplative', 'awakening',
    # Social/political
    'tribalism', 'civilisation', 'civilization', 'culture', 'politics',
    'political', 'discourse', 'groups', 'society', 'social',
    # Psychology/biology
    'psychology', 'biology', 'evolution', 'behavior', 'behaviour',
    'neuroscience', 'brain', 'mind', 'consciousness',
    # Anthropology
    'anthropology', 'ethnography', 'ritual', 'kinship',
    # Philosophy/ethics
    'philosophy', 'ethics', 'morality', 'compassion', 'prosocial',
    # Indonesia-specific
    'indonesia', 'indonesian', 'javanese', 'balinese',
    # Other relevant
    'human', 'humanity', 'nature', 'suffering', 'impermanence',
    'religion', 'secular', 'rationality', 'wisdom', 'insight',
    'legacy', 'meaning', 'purpose', 'flow', 'creativity',
}

# Keyword patterns to search in content (case-insensitive)
RELEVANT_PATTERNS = [
    # Behavioral biology / evolutionary psychology
    r'\b(evolution|evolutionary|darwin|sapolsky|neuroscien|hormone|cortisol|testosterone|dopamine|serotonin|oxytocin|amygdala|prefrontal|limbic|primate|ape|chimp|bonobo|homo.?sapiens|behavioral.?biology|behavioural.?biology|sociobiology|evolutionary.?psychology)\b',
    
    # Dharma / Buddhism / contemplative
    r'\b(dharma|buddha|buddhis|zen|meditat|mindful|imperma|suffering|dukkha|anatta|anicca|samsara|nirvana|nibbana|enlighten|gotama|sangha|sutra|sutta|vipassana|samadhi|jhana|bodhi|metta|karuna|mudita|upekkha|eightfold|four.?noble|middle.?way|dependent.?origination)\b',
    
    # Politics / governance
    r'\b(politic|democra|authorit|totalitar|govern|state.?power|corrupt|oligarch|elite|populis|ideolog|left.?wing|right.?wing|conserv|liberal|socialist|capitalis|marxis|fascis|nationalism|globalis)\b',
    
    # Anthropology / ethnography
    r'\b(anthropolog|ethnograph|kinship|ritual|tribe|tribal|indigenous|hunter.?gather|pastoral|agricultur|cross.?cultural|fieldwork|participant.?observ|emic|etic|cultural.?relativ|ethnocentr)\b',
    
    # Social psychology / group dynamics
    r'\b(prosocial|antisocial|cooperat|altruism|reciproc|group.?selection|kin.?selection|social.?construct|in.?group|out.?group|us.?vs.?them|conformity|obedience|bystander|groupthink|social.?identity|intergroup)\b',
    
    # Philosophy / ethics
    r'\b(epistemolog|ontolog|metaphysic|phenomen|existential|stoic|epicur|utilitarian|deontolog|virtue.?ethics|moral.?philosophy|free.?will|determinism|consciousness|qualia|mind.?body)\b',
    
    # Human nature / meaning
    r'\b(human.?nature|human.?condition|meaning.?of.?life|existential|mortality|death|impermanence|transience|purpose|flourishing|eudaimonia|wellbeing|well.?being|happiness|contentment)\b',
    
    # Key thinkers (Gary's influences)
    r'\b(sapolsky|gotama|buddha|greer|germaine|dawkins|dennett|pinker|haidt|kahneman|tversky|dunbar|de.?waal|tomasello|henrich|diamond|harari)\b',
]

# Fields to remove from output
REMOVE_FIELDS = ['color', 'isTrashed', 'isPinned', 'isArchived']


def html_to_markdown(html_content: str) -> str:
    """Convert Google Keep HTML to clean markdown."""
    if not html_content:
        return ""
    
    text = unescape(html_content)
    
    # Remove style attributes
    text = re.sub(r'\s+style="[^"]*"', '', text)
    text = re.sub(r'\s+dir="[^"]*"', '', text)
    
    # Line breaks
    text = re.sub(r'<br\s*/?>', '\n', text)
    
    # Paragraphs
    text = re.sub(r'<p[^>]*>', '', text)
    text = re.sub(r'</p>', '\n\n', text)
    
    # Bold
    text = re.sub(r'<b>|<strong>', '**', text)
    text = re.sub(r'</b>|</strong>', '**', text)
    
    # Italic
    text = re.sub(r'<i>|<em>', '*', text)
    text = re.sub(r'</i>|</em>', '*', text)
    
    # Lists
    text = re.sub(r'<ul[^>]*>', '', text)
    text = re.sub(r'</ul>', '\n', text)
    text = re.sub(r'<li[^>]*>', '- ', text)
    text = re.sub(r'</li>', '\n', text)
    
    # Links (preserve URL)
    text = re.sub(r'<a[^>]*href="([^"]*)"[^>]*>([^<]*)</a>', r'[\2](\1)', text)
    
    # Remove remaining tags (spans, divs, etc.)
    text = re.sub(r'<[^>]+>', '', text)
    
    # Clean up whitespace
    text = re.sub(r'[ \t]+', ' ', text)  # Collapse horizontal whitespace
    text = re.sub(r'\n{3,}', '\n\n', text)  # Max 2 newlines
    text = text.strip()
    
    return text


def extract_hashtags(content: str) -> list[str]:
    """Extract hashtags from content."""
    if not content:
        return []
    # Match #word but not ## (markdown headers)
    tags = re.findall(r'(?<![#\w])#(\w+)', content)
    return list(set(tags))


def is_relevant(note_data: dict) -> tuple[bool, list[str]]:
    """
    Check if note is relevant based on labels and content.
    Returns (is_relevant, matched_reasons).
    """
    reasons = []
    
    # Check existing labels
    labels = note_data.get('labels', [])
    label_names = {l.get('name', '').lower() for l in labels}
    
    matched_labels = label_names & RELEVANT_LABELS
    if matched_labels:
        reasons.append(f"labels: {', '.join(matched_labels)}")
    
    # Check content + title
    content = note_data.get('textContent', '') or ''
    title = note_data.get('title', '') or ''
    full_text = f"{title} {content}".lower()
    
    # Check hashtags in content
    hashtags = {t.lower() for t in extract_hashtags(content)}
    matched_hashtags = hashtags & RELEVANT_LABELS
    if matched_hashtags:
        reasons.append(f"hashtags: {', '.join(matched_hashtags)}")
    
    # Check keyword patterns
    for pattern in RELEVANT_PATTERNS:
        matches = re.findall(pattern, full_text, re.IGNORECASE)
        if matches:
            unique_matches = list(set(m.lower() if isinstance(m, str) else m[0].lower() for m in matches))[:3]
            reasons.append(f"keywords: {', '.join(unique_matches)}")
            break  # One pattern match is enough
    
    return bool(reasons), reasons


def transform_note(note_data: dict) -> dict:
    """Transform note to target format."""
    result = {}
    
    # Copy fields, excluding remove list
    for key, value in note_data.items():
        if key not in REMOVE_FIELDS:
            result[key] = value
    
    # Add textContentMD
    result['textContentMD'] = html_to_markdown(note_data.get('textContentHtml', ''))
    
    # Augment labels with hashtags from content
    existing_labels = {l.get('name', '').lower() for l in result.get('labels', [])}
    content_hashtags = extract_hashtags(note_data.get('textContent', ''))
    
    if 'labels' not in result:
        result['labels'] = []
    
    for tag in content_hashtags:
        if tag.lower() not in existing_labels:
            result['labels'].append({'name': tag})
            existing_labels.add(tag.lower())
    
    return result


def format_timestamp(usec: int) -> str:
    """Convert microsecond timestamp to readable date."""
    if not usec:
        return "unknown"
    return datetime.fromtimestamp(usec / 1_000_000).strftime('%Y-%m-%d %H:%M')


def process_notes(dry_run: bool = False, verbose: bool = False):
    """Main processing function."""
    
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    json_files = sorted(SOURCE_DIR.glob('*.json'))
    
    stats = {
        'processed': 0,
        'relevant': 0,
        'skipped_empty': 0,
        'skipped_irrelevant': 0,
    }
    
    relevant_notes = []
    
    for json_file in json_files:
        with open(json_file, 'r', encoding='utf-8') as f:
            try:
                note_data = json.load(f)
            except json.JSONDecodeError:
                if verbose:
                    print(f"  ⚠ JSON error: {json_file.name}")
                continue
        
        stats['processed'] += 1
        
        # Skip empty notes
        content = note_data.get('textContent', '') or ''
        if len(content.strip()) < 5:
            stats['skipped_empty'] += 1
            continue
        
        # Check relevance
        relevant, reasons = is_relevant(note_data)
        
        if relevant:
            stats['relevant'] += 1
            transformed = transform_note(note_data.copy())
            
            # Add metadata for reporting
            title = note_data.get('title', '') or '(untitled)'
            created = format_timestamp(note_data.get('createdTimestampUsec', 0))
            preview = content[:60].replace('\n', ' ') + ('...' if len(content) > 60 else '')
            
            relevant_notes.append({
                'file': json_file.name,
                'title': title,
                'created': created,
                'reasons': reasons,
                'preview': preview,
                'char_count': len(content),
            })
            
            if not dry_run:
                output_file = OUTPUT_DIR / json_file.name
                with open(output_file, 'w', encoding='utf-8') as f:
                    json.dump(transformed, f, ensure_ascii=False, indent=2)
            
            if verbose:
                print(f"  ✓ {json_file.name}: {', '.join(reasons)}")
        else:
            stats['skipped_irrelevant'] += 1
            if verbose and len(content) > 200:  # Show skipped substantial notes
                print(f"  ✗ {json_file.name}: {content[:50]}...")
    
    # Summary
    print(f"\n{'='*60}")
    print(f"PROCESSING COMPLETE {'(DRY RUN)' if dry_run else ''}")
    print(f"{'='*60}")
    print(f"Total processed:    {stats['processed']}")
    print(f"Relevant (saved):   {stats['relevant']}")
    print(f"Skipped (empty):    {stats['skipped_empty']}")
    print(f"Skipped (off-topic): {stats['skipped_irrelevant']}")
    print(f"Output directory:   {OUTPUT_DIR}")
    
    # Show sample of relevant notes
    print(f"\n{'='*60}")
    print("SAMPLE RELEVANT NOTES")
    print(f"{'='*60}")
    for note in relevant_notes[:20]:
        print(f"\n{note['title'][:50]}")
        print(f"  Created: {note['created']} | {note['char_count']} chars")
        print(f"  Matched: {', '.join(note['reasons'])}")
        print(f"  Preview: {note['preview']}")
    
    if len(relevant_notes) > 20:
        print(f"\n... and {len(relevant_notes) - 20} more")
    
    return stats, relevant_notes


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Process Google Keep notes export')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without writing files')
    parser.add_argument('--verbose', '-v', action='store_true', help='Show detailed progress')
    parser.add_argument('--source', '-s', type=Path, default=DEFAULT_SOURCE, help='Source directory containing Keep JSON files')
    parser.add_argument('--output', '-o', type=Path, default=DEFAULT_OUTPUT, help='Output directory for processed notes')
    args = parser.parse_args()
    
    # Update globals with any overrides
    SOURCE_DIR = args.source
    OUTPUT_DIR = args.output
    
    process_notes(dry_run=args.dry_run, verbose=args.verbose)
