# Applied Anthropology Knowledge Base

**AI-powered secular dharma & evolutionary anthropology expert with 777K+ scholarly segments from leading researchers.**

---

## Overview

The **Applied Anthropology Knowledge Base** is a comprehensive AI-powered semantic search system specialized in **secular dharma studies, evolutionary anthropology, and human behavioral biology**. Built using the CustomKB framework, it serves as an expert resource (DrAA - Doctor of Applied Anthropology) for understanding dharma as ethical pathways adopted by individuals and groups from a scientific, anthropological perspective.

This cutting-edge system represents a convergence of AI technology, rigorous academic research, and secular dharma studies, built upon **777,553 document segments** from over **500 scholarly works** by leading anthropologists, evolutionary biologists, and philosophers including David Graeber, Robert Sapolsky, Christopher Boehm, Stephen Batchelor, Richard Wrangham, Rutger Bregman, and other distinguished scholars.

### Key Characteristics

- **Scale**: 777,553 document segments from 500+ scholarly works (fully embedded)
- **Database Size**: 2.2GB SQLite database + 7.9GB FAISS vector index  
- **Citations**: 15,143 AI-generated contextual citations
- **Text Cache**: 94 processed directories from diverse academic sources
- **Specialization**: Secular dharma, evolutionary anthropology, human behavioral biology
- **AI Role**: World expert in Applied Anthropology with dharma specialization
- **Last Updated**: July 18-19, 2025 (recent full system rebuild)

---

## Problem Statement & Mission

This project addresses the critical need for:

- **Evidence-based exploration** of human ethical systems and cultural evolution
- **Secular academic perspective** on dharma concepts traditionally associated with religious contexts
- **Interdisciplinary synthesis** of anthropology, evolutionary biology, philosophy, and psychology
- **Objective analysis** of human nature, cooperation, and cultural development

### Philosophical Framework

The knowledge base specializes in secular dharma studies, conceptualizing **dharma not as a single universal truth** but as diverse ethical pathways that individuals and groups adapt to their specific environments. Drawing from evolutionary biology, human behavioral biology, cultural anthropology, philosophy, and psychology, it maintains that **secular dharmas are equally valid** and scientifically grounded as religious interpretations.

---

## Target Audience

### Primary Demographics

- **Academic Researchers & Scholars**: Graduate students, faculty, postdocs in anthropology, evolutionary biology, philosophy (ages 22-65)
- **Philosophical Practitioners**: Secular Buddhists, humanists, contemplative practice communities (ages 25-65)
- **Applied Professionals**: Policy researchers, educators, mental health professionals (ages 25-55)
- **Technology Workers**: AI researchers, data scientists interested in human behavior (ages 25-45)
- **Writers & Public Intellectuals**: Science writers, public intellectuals covering human evolution and ethics (ages 28-65)

### Geographic Distribution

- **Primary Markets**: North America, Europe, Australia/New Zealand (academic institutions, secular communities)
- **Secondary Markets**: Asia (English-speaking academics), Global South (international scholars)
- **Online Communities**: Global digital communities focused on secular philosophy and applied anthropology

### Psychographic Profile

Advanced degree holders valuing scientific rationalism, cultural pluralism, and interdisciplinary synthesis. Early technology adopters seeking comprehensive, well-sourced information for academic research, professional development, and personal growth through secular approaches to ethical living.

---

## Core Architecture

### Technology Stack

- **Knowledge Base System**: CustomKB framework with Python backend
- **Vector Search Engine**: FAISS (7.9GB index) with OpenAI text-embedding-3-large (1024 dimensions)
- **AI Query Processing**: GPT-4o with specialized anthropology expertise (temperature: 0.2335)
- **Data Storage**: SQLite database (2.2GB) with 777,553 document segments
- **Search Enhancement**: Cross-encoder reranking model for improved relevance
- **Hybrid Search**: Semantic vector search with optional BM25 keyword search

### Data Sources & Content

- **Primary Data**: Symlinked to `/ai/datasets/sd/sd_gpt/` containing scholarly materials
- **Key Authors**: David Graeber, Robert Sapolsky, Christopher Boehm, Stephen Batchelor, Richard Wrangham, and 100+ others
- **Content Areas**: Evolutionary biology, anthropology, philosophy, psychology, cultural studies, secular dharma
- **Text Cache**: 94 processed directories with structured academic materials

### Core Components

```
appliedanthropology/
├── appliedanthropology.cfg                 # Main configuration file
├── appliedanthropology.db                  # SQLite database (777K+ segments)
├── appliedanthropology.faiss               # Vector search index (7.9GB)
├── appliedanthropology_primary_prompt.md   # AI assistant personality
├── appliedanthropology.build.conf          # Build process configuration
├── 0_build.sh                             # Comprehensive build automation
├── build.sh                               # Legacy build script
├── embed_data -> /ai/datasets/sd/sd_gpt/  # Source data symlink
├── embed_data.text/                       # Processed text cache
├── docs/                                  # Documentation
├── logs/                                  # Application logs
└── backups/                               # Configuration backups
```

---

## Key Functionality

### 1. Semantic Search Capabilities

- **Vector-based search** across 777,553 document segments
- **Context-aware retrieval** with 5-segment scope for comprehensive understanding
- **Reranking optimization** using cross-encoder models for improved relevance
- **Multi-language support** with Indonesian, French, German, Swedish stopwords
- **Query enhancement** with spelling correction and semantic expansion

### 2. AI Expert System (DrAA)

**You are DrAA (Doctor of Applied Anthropology)**, a world-leading expert specializing in secular dharma studies, evolutionary anthropology, and human behavioral biology.

#### Core Expertise & Specializations:
- **Secular Dharma Studies**: Evidence-based exploration of ethical pathways, cultural evolution, and moral frameworks
- **Applied Anthropology**: Human behavioral evolution, cultural sociology, biological anthropology with practical applications
- **Evolutionary Biology**: Human nature, behavioral genetics, cooperation dynamics, and group social organization
- **Cross-Disciplinary Synthesis**: Philosophy, psychology, neuroscience, cultural studies, and consciousness research
- **Comparative Ethics**: Religious vs. secular approaches to human organization, cooperation, and ethical living

#### Methodological Approach:
- Maintain rigorous scientific objectivity while remaining intellectually accessible
- Draw comprehensively from both provided contextual segments AND internal knowledge base
- Emphasize evidence-based analysis rooted in empirical research and cross-cultural data
- Avoid privileging religious or metaphysical interpretations over secular, naturalistic approaches
- Provide nuanced analysis that bridges academic rigor with practical, actionable insights

### 3. Dharma-Centric Definitions

The system operates with specific definitions:

- **dharma**: A way, path, culture, or outlook adopted by individuals or groups that defines ethical living within their specific environmental and cultural context. NOT a universal "The Dharma" but diverse, adaptive ethical systems.
- **dharmas**: Multiple, pluralistic forms that evolve and adapt to specific contexts and environments. Secular dharmas are equally valid and scientifically grounded as religious interpretations.
- **dharmic**: (noun) A person who adheres to a dharma; (adjective) Exhibiting qualities characteristic of an ethical path or way of being.
- **applied anthropology**: Biology-grounded understanding of human culture, behavior, and social organization with direct practical applications to contemporary challenges.

### 4. Build and Maintenance Pipeline

**6-Stage Build Process (`0_build.sh`):**

1. **Text Caching** (`-0`): Process source materials into structured cache
2. **Citation Generation** (`-1`): AI-enhanced metadata using GPT-4.1-mini
3. **Citation Integration** (`-2`): Append generated citations to database
4. **Database Import** (`-3`): Import processed texts to SQLite
5. **Vector Embedding** (`-4`): Generate embeddings and build FAISS index
6. **Testing** (`-5`): Automated query validation

---

## Knowledge Repository Content

### Key Subject Areas

- **Secular Dharma**: Ethical pathways, cultural evolution, moral philosophy
- **Evolutionary Biology**: Human behavioral evolution, primatology, genetics
- **Anthropological Theory**: Political anthropology, cultural sociology, applied anthropology
- **Philosophy**: Ethics, existentialism, stoicism, Buddhist philosophy (secular interpretations)
- **Psychology**: Human behavioral biology, neuroscience, consciousness studies
- **Cultural Studies**: Civilization development, social organization, group dynamics

### Major Authors and Works Included

- **David Graeber** (*Dawn of Everything*, *Debt*, *Bullshit Jobs*)
- **Christopher Boehm** (*Hierarchy in the Forest*)
- **Robert Sapolsky** (*Behave*, behavioral biology lectures)
- **Stephen Batchelor** (secular Buddhism, *After Buddhism*)
- **Richard Wrangham** (human evolution, violence studies)
- **Rutger Bregman** (*Humankind*)
- And 100+ other scholars in anthropology, philosophy, and related fields

---

## Usage Guide

### Common Commands

#### Query Operations
```bash
# Interactive query mode
customkb query appliedanthropology.cfg

# Direct queries
customkb query appliedanthropology.cfg "What is dharma in secular context?"
customkb query appliedanthropology.cfg "How do evolutionary perspectives inform ethics?"

# Context-only (no AI response)
customkb query appliedanthropology.cfg "dharma" --context-only
```

#### Build and Maintenance
```bash
# Full rebuild (all stages)
./0_build.sh -a -y

# Individual stages
./0_build.sh -0    # Create text cache from source data
./0_build.sh -1    # Generate AI citations (GPT-4.1-mini)
./0_build.sh -2    # Append citations to database
./0_build.sh -3    # Import text to database
./0_build.sh -4    # Create vector embeddings
./0_build.sh -5    # Run test query

# Simple rebuild (legacy)
./build.sh
```

#### Database Management
```bash
# Check database stats
sqlite3 appliedanthropology.db "SELECT COUNT(*) FROM docs;"
sqlite3 appliedanthropology.db "SELECT COUNT(*) FROM citations;"

# Verify indexes
customkb verify-indexes appliedanthropology.cfg

# Optimize performance
customkb optimize appliedanthropology.cfg
```

### Example Queries & Use Cases

#### Academic Research
- "Explain dharma's anthropological significance across cultures"
- "What do evolutionary anthropologists say about human cooperation?"
- "How do cultural and biological evolution interact in ethical systems?"
- "Compare secular and religious approaches to moral philosophy"

#### Comparative Analysis
- "Analyze differences between Graeber's and Boehm's views on hierarchy"
- "What are the evolutionary origins of human ethical behavior?"
- "How do dharmas emerge and adapt to environmental pressures?"
- "Compare Buddhist and secular humanist ethical frameworks"

#### Applied Understanding
- "What can anthropology teach us about sustainable social organization?"
- "How do human behavioral patterns influence modern governance?"
- "What role does culture play in shaping individual ethical choices?"
- "How can secular dharma principles inform contemporary social policy?"

---

## Technical Architecture

### Vector Search System
- **Model**: OpenAI text-embedding-3-large (1024 dimensions)
- **Index**: FAISS with CPU processing (7.9GB index size)
- **Reranking**: cross-encoder/ms-marco-MiniLM-L-6-v2 (CPU-based)
- **Hybrid Search**: FAISS semantic search (BM25 disabled)
- **GPU Status**: Available but index too large (7.9GB > 3.6GB GPU limit)

### AI Query Processing
- **Model**: GPT-4o with anthropology specialization
- **Temperature**: 0.2335 for consistent, objective responses
- **Context**: 30 relevant segments with 5-segment scope
- **Query Cache**: 30-day TTL for performance optimization
- **API Concurrency**: 12-24 concurrent requests
- **Role**: Maintains objectivity while drawing from scientific perspectives

### Performance Characteristics
- **Search Speed**: CPU-based FAISS with reranking optimization
- **Query Processing**: Context-only queries complete in ~11-13 seconds
- **Memory Usage**: 250MB cache limit with 100K item memory cache
- **Batch Processing**: Optimized for large-scale document processing (24 concurrent threads)
- **API Rate Limiting**: 12-24 concurrent requests with intelligent backoff

---

## System Requirements & Dependencies

### Hardware Requirements
- **CPU**: Multi-core processor for FAISS operations
- **Memory**: Minimum 16GB RAM (32GB recommended for full GPU support)
- **Storage**: 12GB+ available space for database and indexes
- **GPU**: Optional CUDA-compatible GPU (requires >8GB VRAM for full index)

### Software Dependencies
- **CustomKB framework**: `/usr/local/bin/customkb`
- **Python environment**: Virtual environment with ML libraries
- **SQLite**: Database engine for document storage
- **FAISS**: Vector similarity search library
- **OpenAI API**: Text embedding and query processing
- **Cross-encoder models**: For search result reranking

### Configuration Files
- **Main config**: `appliedanthropology.cfg` - System parameters and API settings
- **Build config**: `appliedanthropology.build.conf` - Processing pipeline settings
- **AI prompt**: `appliedanthropology_primary_prompt.md` - Assistant personality
- **Environment**: Shell environment variables for API keys and paths

---

## Development Guidelines

### Adding New Content
1. Add source materials to symlinked embed_data directory
2. Run `./0_build.sh -0` to update text cache
3. Complete rebuild with `./0_build.sh -1 -2 -3 -4` or full `./0_build.sh -a`

### Configuration Updates
- Edit `appliedanthropology.cfg` for search parameters
- Modify `appliedanthropology_primary_prompt.md` for AI behavior
- Update `appliedanthropology.build.conf` for build settings

### Quality Assurance
- Test queries are automatically run during build process
- Default test: "Explain the meaning of the word 'dharma' as expressed within contemporary Balinese Hinduism"
- Monitor logs in `logs/appliedanthropology.log`
- Database indexes verified and optimized
- Query performance monitored with 30-day cache TTL

---

## Integration & Extensibility

### Related Knowledge Bases
- Links to `prosocial.world` and `wayang.net` knowledge bases
- Shared caching infrastructure across vectordbs ecosystem
- Cross-referencing capabilities with other anthropological resources

### API Integration
- **OpenAI Models**: GPT-4o for queries, text-embedding-3-large for vectors
- **Query caching**: 30-day TTL for performance optimization
- **Rate limiting**: Configurable API call management
- **Batch processing**: Optimized for high-throughput operations

### AI Assistant Behavior
- Maintains objective, reflective approach
- Emphasizes scientific and evidence-based perspectives
- Avoids privileging religious over secular interpretations
- Responds in GitHub markdown format
- Draws from both provided context and internal knowledge

---

## Current System Status (July 2025)

✅ **Fully Operational**: All components initialized and functional  
✅ **Database**: 777,553 document segments loaded and indexed  
✅ **Citations**: 15,143 AI-generated contextual citations integrated  
✅ **Vector Search**: FAISS index optimized for CPU-based semantic queries  
✅ **AI Expert**: DrAA role active with dharma specialization  
✅ **Reranking**: Cross-encoder optimization for improved relevance  
✅ **Query Enhancement**: Spelling correction and semantic expansion enabled  
✅ **Performance**: CPU-optimized processing with 250MB cache limit  
✅ **WAHID Integration**: Enabled and available for system queries  

### Storage and Indexing
- **Database Tables**: `docs` (777,553 records) and `citations` (15,143 records)
- **Vector Index**: 7.9GB FAISS index with 1024-dimensional embeddings
- **Cache Management**: Query results cached for 30 days, embedding cache shared across knowledge bases

---

## Contemporary Applications

### Primary Use Cases
1. **Academic Research**: Scholarly content generation for secular ethics and philosophy
2. **Educational Content**: Course materials and workshop resources on human behavioral evolution
3. **Professional Development**: Evidence-based approaches to policy and program development
4. **Personal Growth**: Secular approaches to ethical living and personal development
5. **Applied Research**: Real-world applications of anthropological insights to contemporary challenges

### Research Applications
- Literature reviews for thesis/dissertation research
- Cross-disciplinary exploration of human behavior and culture
- Theoretical framework development for applied research
- Comparative cultural and philosophical studies
- Understanding cultural factors in professional practice
- Integration of contemplative practice with rational inquiry

---

## Contributing & Support

This knowledge base represents a sophisticated intersection of AI technology, anthropological research, and secular dharma studies, providing evidence-based insights into human nature, cultural evolution, and ethical living from an applied anthropological perspective. The system has been recently updated (July 2025) with comprehensive coverage and optimized performance characteristics.

### Areas for Contribution
- Additional source material for inclusion in the dataset
- Enhanced search algorithms and relevance tuning
- Cross-cultural wisdom tradition integrations
- Performance optimizations and caching improvements
- New analytical frameworks and methodological approaches

---

**The Applied Anthropology Knowledge Base serves as a bridge between ancient wisdom traditions and contemporary scientific understanding, providing rigorous academic frameworks grounded in peer-reviewed research while addressing contemporary challenges in ethical living, meaning-making, and human flourishing.**