# Applied Anthropology Research

Research materials for applied anthropology, human behavioral biology, dharma, and related fields.

## Structure

```
research/
├── keep-notes/          # Extracted Google Keep notes (JSON)
│   └── *.json           # 696 relevant notes
├── scripts/             # Processing tools
│   ├── process-keep-notes.py
│   └── CLAUDE.md        # Context for AI-assisted refinement
└── README.md
```

## Keep Notes

Extracted from Google Takeout export.

**Domains covered:**
- Human behavioral biology (evolution, neuroscience, Sapolsky)
- Dharma (Buddhism, meditation, mindfulness, impermanence)
- Politics (governance, power, ideology)
- Anthropology (culture, ethnography, tribalism)
- Philosophy (ethics, meaning, consciousness)

**JSON format:**
```json
{
  "title": "Note title",
  "textContent": "Plain text content",
  "textContentHtml": "HTML formatted content",
  "textContentMD": "Markdown version",
  "createdTimestampUsec": 1658269519743000,
  "userEditedTimestampUsec": 1658269532126000,
  "labels": [{"name": "dharma"}, {"name": "biology"}],
  "annotations": [...]
}
```

## Processing

### Re-extract from Keep export

```bash
# Default paths
python3 scripts/process-keep-notes.py

# Custom source/output
python3 scripts/process-keep-notes.py \
  --source /path/to/Takeout/Keep \
  --output /path/to/output

# Dry run (preview without writing)
python3 scripts/process-keep-notes.py --dry-run

# Verbose output
python3 scripts/process-keep-notes.py --verbose
```

### Default paths
- **Source:** `/home/sysadmin/takeout-20241108/Takeout/Keep/`
- **Output:** `/var/lib/vectordbs/appliedanthropology/research/keep-notes/`

### AI-assisted refinement
See `scripts/CLAUDE.md` for context and instructions for using Claude Code to review/classify notes.
