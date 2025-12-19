# PURPOSE-FUNCTIONALITY-USAGE

## Project Overview

The Applied Anthropology Knowledgebase is an AI-powered semantic search system that serves as **DrAA (Doctor of Applied Anthropology)** - a world-leading expert in secular dharma studies, evolutionary anthropology, and human behavioral biology. It provides evidence-based insights into human nature, cultural evolution, and ethical frameworks from a rigorously scientific, non-religious perspective.

### Core Purpose

**Problem Solved:**
- Bridges the gap between academic anthropological research and practical applications
- Provides secular, evidence-based perspectives on ethics, human behavior, and cultural evolution
- Synthesizes insights from 500+ scholarly works across multiple disciplines
- Offers scientific alternatives to religious interpretations of dharma and ethical living

**Target Audience:**
- Academic researchers and scholars (anthropology, philosophy, evolutionary biology)
- Secular Buddhist practitioners and humanists
- Policy researchers and educators
- Mental health professionals
- Technology workers interested in human behavior
- The "spiritual but not religious" community

## Architecture & Components

### Directory Structure
```
appliedanthropology/
├── appliedanthropology.cfg               # Main configuration
├── appliedanthropology.db                # SQLite database (2.2GB, 777K segments)
├── appliedanthropology.faiss             # Vector search index (7.9GB)
├── appliedanthropology_primary_prompt.md # AI personality definition
├── appliedanthropology.build.conf        # Build configuration
├── build.sh                              # Symlink to build/build.sh
├── build/                                # Build scripts and utilities
│   ├── build.sh                          # 6-stage build orchestrator
│   ├── version.sh                        # Version tracking
│   ├── create_staging.text.sh            # Text preprocessing
│   ├── add_version_tracking.sql          # Version schema
│   └── staging.text.zip                  # Cached text data
├── docs/                                 # Documentation
├── logs/                                 # Application logs
├── staging.text/                         # Processed text cache (94 dirs)
└── workshops/                            # Symlink to source data
```

### Technology Stack
- **Core Framework**: CustomKB (`/usr/local/bin/customkb`)
- **Vector Search**: FAISS with OpenAI text-embedding-3-large (1024 dimensions)
- **AI Model**: GPT-4o with specialized anthropology expertise
- **Database**: SQLite with 777,553 document segments
- **Search Enhancement**: Cross-encoder reranking (ms-marco-MiniLM-L-6-v2)
- **Processing**: Python-based with virtual environment support

## Key Functionality

### 1. Semantic Search Engine
- **Vector-based retrieval** across 777K+ scholarly document segments
- **Hybrid search** combining semantic (FAISS) and keyword (BM25) approaches
- **Context-aware responses** with 5-segment scope for comprehensive understanding
- **Reranking optimization** for improved relevance
- **Query enhancement** with spelling correction and semantic expansion

### 2. AI Expert System (DrAA)
Specialized expertise in:
- **Secular Dharma Studies**: Evidence-based ethical frameworks
- **Applied Anthropology**: Human behavioral evolution and cultural sociology
- **Evolutionary Biology**: Human nature, cooperation, and social organization
- **Cross-disciplinary Synthesis**: Philosophy, psychology, neuroscience
- **Comparative Ethics**: Secular vs. religious approaches to morality

### 3. Build & Maintenance Pipeline
Six-stage automated build process:
1. **Text Caching** (`-0`): Process source materials
2. **Citation Generation** (`-1`): AI-enhanced metadata (GPT-4.1-mini)
3. **Citation Integration** (`-2`): Append to database
4. **Database Import** (`-3`): Import processed texts
5. **Vector Embedding** (`-4`): Generate FAISS index
6. **Testing** (`-5`): Automated query validation

### 4. Knowledge Content
- **500+ scholarly works** from leading thinkers
- **Key authors**: David Graeber, Robert Sapolsky, Christopher Boehm, Stephen Batchelor, Richard Wrangham, Rutger Bregman
- **15,143 AI-generated contextual citations**
- **94 processed text directories** from diverse academic sources

## Usage Guide

### Common Workflows

#### 1. Query the Knowledgebase
```bash
# Interactive query mode
customkb query appliedanthropology.cfg

# Direct query
customkb query appliedanthropology.cfg "What is dharma in secular context?"

# Context-only (no AI response)
customkb query appliedanthropology.cfg "dharma" --context-only
```

#### 2. Build or Rebuild the System
```bash
# Full rebuild (all stages)
./build.sh -a -y

# Individual stages
./build.sh -0    # Create text cache
./build.sh -1    # Generate citations
./build.sh -2    # Append citations
./build.sh -3    # Import to database
./build.sh -4    # Create embeddings
./build.sh -5    # Run test query
```

#### 3. Version Management
```bash
# Check current version
./build/version.sh show

# Bump version
./build/version.sh bump [major|minor|patch]

# View history
./build/version.sh history
```

#### 4. Database Operations
```bash
# Check statistics
sqlite3 appliedanthropology.db "SELECT COUNT(*) FROM docs;"
sqlite3 appliedanthropology.db "SELECT COUNT(*) FROM citations;"

# Verify indexes
customkb verify-indexes appliedanthropology.cfg

# Optimize performance
customkb optimize appliedanthropology.cfg
```

### Example Queries

**Academic Research:**
- "Explain dharma's anthropological significance across cultures"
- "What do evolutionary anthropologists say about human cooperation?"
- "How do cultural and biological evolution interact?"

**Comparative Analysis:**
- "Compare Graeber's and Boehm's views on hierarchy"
- "What are the evolutionary origins of ethics?"
- "How do dharmas adapt to environmental pressures?"

**Applied Understanding:**
- "What can anthropology teach about sustainable social organization?"
- "How do behavioral patterns influence modern governance?"
- "How can secular dharma inform social policy?"

## Configuration & Customization

### Key Configuration Files

1. **appliedanthropology.cfg**
   - Vector model settings (OpenAI text-embedding-3-large)
   - Query parameters (GPT-4o, temperature 0.2335)
   - Performance tuning (batch sizes, concurrency)
   - API settings and rate limits

2. **appliedanthropology.build.conf**
   - Citation generation model (GPT-4.1-mini)
   - Processing parallelism (43 threads)
   - Context definitions
   - Test query specifications

3. **appliedanthropology_primary_prompt.md**
   - AI personality and expertise definition
   - Response framework and methodology
   - Target audience specifications

## Dependencies & Requirements

### System Requirements
- **CPU**: Multi-core processor for FAISS operations
- **Memory**: 16GB minimum (32GB recommended)
- **Storage**: 12GB+ for database and indexes
- **GPU**: Optional CUDA support (requires >8GB VRAM)

### Software Dependencies
- **CustomKB framework** (main query/build tool)
- **Python 3.x** with virtual environment
- **SQLite3** for database operations
- **FAISS** for vector similarity search
- **OpenAI API** access for embeddings and queries
- **Supporting tools**: gen-citations, append-citations

### API Keys Required
- OpenAI API key for embeddings and query processing
- Configured through environment variables

## Performance Characteristics

- **Database Size**: 2.2GB with 777,553 segments
- **Vector Index**: 7.9GB FAISS index
- **Query Speed**: ~11-13 seconds for context-only queries
- **API Concurrency**: 12-24 concurrent requests
- **Cache TTL**: 30 days for query results
- **Memory Cache**: 100K items with 250MB limit

## Maintenance & Development

### Adding New Content
1. Add source materials to `workshops/` (symlinked directory)
2. Run `./build.sh -0` to update text cache
3. Complete rebuild with `./build.sh -a`

### Monitoring
- Check logs in `logs/appliedanthropology.log`
- Monitor database growth and query performance
- Review version history for changes

### Best Practices
- Run full rebuilds (`-a`) for major content updates
- Use individual stages for targeted updates
- Maintain version tracking for all significant changes
- Test queries after each rebuild

## Key Concepts & Definitions

The system operates with specific anthropological definitions:
- **dharma**: Adaptive ethical pathways specific to cultural contexts
- **dharmas**: Multiple, pluralistic forms (secular equally valid as religious)
- **dharmic**: Person adhering to dharma or exhibiting dharma-like qualities
- **applied anthropology**: Biology-grounded understanding of human culture

This knowledgebase represents a sophisticated integration of AI technology with rigorous academic research, providing evidence-based insights into human nature, cultural evolution, and ethical living from an applied anthropological perspective.