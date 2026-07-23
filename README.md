# Applied Anthropology Knowledgebase

What if you could query 500+ scholarly works on human nature, cultural evolution, and ethics in seconds? **DrAA** (Doctor of Applied Anthropology) is an AI expert built on 777,000+ document segments from leading thinkers including David Graeber, Robert Sapolsky, Christopher Boehm, Stephen Batchelor, and Richard Wrangham. It provides evidence-based insights into secular dharma, evolutionary anthropology, and the science of human behavior.

---

## Access DrAA

### Web Interface

Query DrAA directly at [wah.id](https://wah.id) with no installation required.

### Command-Line via yatti-api

For programmatic access, install [yatti-api](https://github.com/Open-Technology-Foundation/yatti-api):

```bash
# Clone and install
git clone https://github.com/Open-Technology-Foundation/yatti-api.git
cd yatti-api && ./install.sh

# Configure your API key (contact admin@yatti.id to request access)
yatti-api configure

# Query DrAA
yatti-api query appliedanthropology "What distinguishes secular dharma from religious dharma?"
```

See the [yatti-api repository](https://github.com/Open-Technology-Foundation/yatti-api) for prerequisites and detailed documentation.

---

## Example: DrAA in Action

**Query**: "What distinguishes secular dharma from religious dharma?"

**Response**:

> Key distinctions:
>
> - **Non-metaphysical frame**: Secular dharma brackets claims like rebirth, karmic law as cosmic justice, other realms, and final nirvana; it grounds practice in this life, here-and-now experience, and evidence (Batchelor; Bodhi College materials).
>
> - **Tasks over truths**: Recasts the Four Noble Truths as four practical tasks--embrace dukkha, let go of reactivity, behold its ceasing, cultivate an integrated ethical life--rather than assent to doctrinal truth-claims.
>
> - **Human-centered and contextual**: Oriented to human flourishing in specific societies, adapting teachings to contemporary issues (AI, climate, social justice) using psychology, neuroscience, and evolutionary anthropology.
>
> - **Inclusivity and pluralism**: Open to people of any or no religion; acknowledges many dharmas, not one "The Dharma," and invites personal interpretation and local adaptation.
>
> - **Practice-first pragmatism**: Emphasizes mindfulness, ethical action, and civic responsibility as verifiable skills and social practices, not ritual or hierarchy as gatekeepers.
>
> - **Non-authoritarian ethos**: Minimizes reliance on sacred canons, priestly authority, or ritual orthodoxy; legitimizes claims via critical inquiry, shared practice, and publicly checkable outcomes.
>
> - **Dialogue with science**: Integrates empirical research on mind and behavior; treats dharma as an evolving cultural technology rather than a revealed cosmology.
>
> In short: religious dharma orients around metaphysical truths and soteriological ends; secular dharma orients around practical tasks for ethical flourishing in this world, updated by critical inquiry and science.

---

## What is DrAA?

DrAA (Doctor of Applied Anthropology) is a specialized AI expert system trained on a curated corpus of scholarly works spanning evolutionary biology, cultural anthropology, philosophy, psychology, and secular dharma studies.

### Core Expertise

- **Secular Dharma Studies**: Evidence-based exploration of ethical pathways, cultural evolution, and moral frameworks without metaphysical commitments
- **Applied Anthropology**: Human behavioral evolution, cultural sociology, and biological anthropology with practical applications
- **Evolutionary Biology**: Human nature, behavioral genetics, cooperation dynamics, and group social organization
- **Cross-Disciplinary Synthesis**: Philosophy, psychology, neuroscience, cultural studies, and consciousness research
- **Comparative Ethics**: Religious vs. secular approaches to human organization, cooperation, and ethical living

### Scholarly Foundation

The knowledgebase draws from 500+ works by leading scholars:

| Author | Focus Areas |
|--------|-------------|
| David Graeber | *Dawn of Everything*, *Debt*, political anthropology |
| Robert Sapolsky | Behavioral biology, stress, neuroscience |
| Christopher Boehm | *Hierarchy in the Forest*, egalitarianism |
| Stephen Batchelor | Secular Buddhism, *After Buddhism* |
| Richard Wrangham | Human evolution, violence, self-domestication |
| Rutger Bregman | *Humankind*, human cooperation |
| James C. Scott | Political anthropology, state formation |
| Matthew Walker | Sleep science, neuroscience |
| Lisa Feldman Barrett | Emotion, consciousness, neuroscience |

Plus 100+ additional scholars across anthropology, philosophy, psychology, and related fields.

---

## Who This Is For

### Academic Researchers
Graduate students, faculty, and postdocs in anthropology, evolutionary biology, philosophy, religious studies, and psychology seeking scholarly synthesis and literature discovery.

### Secular Practitioners
Secular Buddhists, humanists, and contemplative practice communities looking for evidence-based approaches to mindfulness and ethical living.

### Applied Professionals
Policy researchers, educators, and mental health professionals integrating anthropological insights into their work.

### Technology Workers
AI researchers and data scientists exploring human behavioral patterns, cooperation dynamics, and cultural evolution.

### Writers and Public Intellectuals
Science writers and communicators covering human evolution, ethics, and the intersection of ancient wisdom with modern science.

---

## Key Concepts

The knowledgebase operates with specific definitions that distinguish it from traditional approaches:

**dharma**: A way, path, culture, or outlook adopted by individuals or groups that defines ethical living within their specific environmental and cultural context. Not a universal "The Dharma" but diverse, adaptive ethical systems.

**dharmas**: Multiple, pluralistic forms that evolve and adapt to specific contexts and environments. Secular dharmas are equally valid and scientifically grounded as religious interpretations.

**dharmic**: (noun) A person who adheres to a dharma; (adjective) Exhibiting qualities characteristic of an ethical path or way of being.

**applied anthropology**: Biology-grounded understanding of human culture, behavior, and social organization with direct practical applications to contemporary challenges.

---

## Example Queries

### Academic Research
```bash
yatti-api query appliedanthropology "What do evolutionary anthropologists say about the origins of human cooperation?"
yatti-api query appliedanthropology "Compare Graeber and Boehm on hierarchy and egalitarianism"
yatti-api query appliedanthropology "How do cultural and biological evolution interact in ethical systems?"
```

### Comparative Analysis
```bash
yatti-api query appliedanthropology "What are the evolutionary origins of human ethical behavior?"
yatti-api query appliedanthropology "Compare Buddhist and secular humanist ethical frameworks"
yatti-api query appliedanthropology "How do dharmas emerge and adapt to environmental pressures?"
```

### Applied Understanding
```bash
yatti-api query appliedanthropology "What can anthropology teach us about sustainable social organization?"
yatti-api query appliedanthropology "How can secular dharma principles inform contemporary social policy?"
```

### Context-Only Retrieval
```bash
# Return source segments without AI synthesis
yatti-api query appliedanthropology "dharma" --context-only
```

---

## Technical Architecture

### Scale and Storage
- **Document Segments**: 777,553 segments from 500+ scholarly works
- **Database**: 2.2GB SQLite with full-text indexing
- **Vector Index**: 7.9GB FAISS index with 1024-dimensional embeddings
- **AI Citations**: 15,143 contextual citations generated by AI
- **Text Cache**: 94 processed directories from diverse academic sources

### Technology Stack
- **Knowledgebase Framework**: CustomKB with Python backend
- **Embeddings**: OpenAI text-embedding-3-large (1024 dimensions)
- **Query Model**: GPT-5 with specialized anthropology expertise
- **Vector Search**: FAISS semantic search with cross-encoder reranking
- **Search Enhancement**: Spelling correction and semantic expansion

### Performance
- **Query Processing**: Context-only queries complete in ~11-13 seconds
- **Temperature**: 0.2335 for consistent, objective responses
- **Context Window**: 30 relevant segments with 5-segment scope
- **Query Cache**: 30-day TTL for repeated queries
- **API Concurrency**: 12-24 concurrent requests

---

## Local Development

For contributors and developers who want to work with the knowledgebase directly.

### Directory Structure

```
appliedanthropology/
├── appliedanthropology.cfg               # Main configuration
├── appliedanthropology.db                # SQLite database (777K+ segments)
├── appliedanthropology.faiss             # Vector search index (7.9GB)
├── appliedanthropology_primary_prompt.md # AI assistant personality
├── appliedanthropology.build.conf        # Build configuration
├── build.sh                              # Symlink to build/build.sh
├── build/                                # Build scripts and utilities
│   ├── build.sh                          # Main build orchestrator
│   ├── version.sh                        # Version tracking
│   ├── create_staging.text.sh            # Text preprocessing
│   └── staging.text.zip                  # Cached text data
├── docs/                                 # Documentation
├── logs/                                 # Application logs
└── staging.text/                         # Processed text cache
```

### Build Pipeline

The knowledgebase uses a 6-stage build process:

```bash
# Full rebuild (all stages)
./build.sh -a -y

# Individual stages
./build.sh -0    # Create text cache from source data
./build.sh -1    # Generate AI citations (GPT-4.1-mini)
./build.sh -2    # Append citations to database
./build.sh -3    # Import text to database
./build.sh -4    # Create vector embeddings
./build.sh -5    # Run test query
```

### Direct Query Commands

```bash
# Interactive query mode
customkb query appliedanthropology.cfg

# Direct query
customkb query appliedanthropology.cfg "What is dharma in secular context?"

# Context-only (no AI response)
customkb query appliedanthropology.cfg "dharma" --context-only
```

### Database Management

```bash
# Check segment count
sqlite3 appliedanthropology.db "SELECT COUNT(*) FROM docs;"

# Check citation count
sqlite3 appliedanthropology.db "SELECT COUNT(*) FROM citations;"

# Verify indexes
customkb verify-indexes appliedanthropology.cfg

# Optimize performance
customkb optimize appliedanthropology.cfg

# Version management
./build/version.sh show      # Display current version
./build/version.sh bump      # Increment version
./build/version.sh history   # Show version history
```

### Adding New Content

1. Add source materials from the workshops/ to staging.text/
2. Run `./build.sh -0` to update text cache
3. Complete rebuild with `./build.sh -1 -2 -3 -4` or full `./build.sh -a`

### Configuration Files

- **appliedanthropology.cfg**: System parameters, API settings, search configuration
- **appliedanthropology.build.conf**: Build pipeline settings, citation model parameters
- **appliedanthropology_primary_prompt.md**: AI assistant personality and response guidelines

### System Requirements

- **CPU**: Multi-core processor for FAISS operations
- **Memory**: Minimum 16GB RAM (32GB recommended)
- **Storage**: 12GB+ available space
- **Software**: CustomKB framework, Python 3.x, SQLite, FAISS, OpenAI API access

---

## System Status

| Component | Status |
|-----------|--------|
| Database | 777,553 segments loaded and indexed |
| Citations | 15,143 AI-generated citations integrated |
| Vector Search | FAISS index optimized for CPU processing |
| AI Expert | DrAA role active with dharma specialization |
| Reranking | Cross-encoder optimization enabled |
| Query Enhancement | Spelling correction and semantic expansion |
| Performance | CPU-optimized with 250MB cache limit |
| Web Access | Available at wah.id |

**Last Updated**: July 2025

---

## Related Resources

### Related Knowledgebases
- **prosocial.world**: Prosocial behavior and social evolution
- **wayang.net**: Indonesian wayang culture and traditional arts
- **seculardharma**: Secular Buddhist philosophy and mindfulness

### Integration
- Shared caching infrastructure across the vectordbs ecosystem
- Cross-referencing capabilities with other anthropological resources
- Query caching with 30-day TTL for performance optimization

---

## Contributing

Areas for contribution:

- Additional source material for inclusion in the dataset
- Enhanced search algorithms and relevance tuning
- Cross-cultural wisdom tradition integrations
- Performance optimizations and caching improvements
- New analytical frameworks and methodological approaches

---

The Applied Anthropology Knowledgebase bridges ancient wisdom traditions with contemporary scientific understanding, providing rigorous academic frameworks grounded in peer-reviewed research for the growing global community seeking evidence-based approaches to ethics, meaning-making, and human flourishing.
