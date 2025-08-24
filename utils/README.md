# Applied Anthropology Utils

This directory contains knowledgebase-specific files for the Applied Anthropology KB.

## Categorization System

The universal KB categorization system has been moved to:
```
/ai/scripts/customkb/utils/categorize/
```

### Usage

To categorize this knowledgebase:
```bash
# Using the system command
categorize_kb appliedanthropology --sample 10

# Or directly
/ai/scripts/customkb/utils/categorize/categorize_kb appliedanthropology --full
```

### Files in this directory

- `categories.yaml` - Category definitions for this KB
- `reports/` - Categorization results and reports

### See Also

- Main categorizer: `/ai/scripts/customkb/utils/categorize/README.md`
- Test script: `/ai/scripts/customkb/utils/categorize/test_kb_categorizer.sh`

#fin