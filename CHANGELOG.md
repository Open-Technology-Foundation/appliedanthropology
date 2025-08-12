# Changelog - Applied Anthropology Knowledgebase

All notable changes to this knowledgebase will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2025-07-29

### Changed
- Test automatic table creation

## [1.1.0] - 2025-07-29

### Changed
- Test minor version bump

## [1.0.1] - 2025-07-29

### Changed
- Testing version system

## [1.0.0] - 2025-07-19

### Initial Release
- 777,553 document segments from 500+ scholarly works
- 15,143 AI-generated contextual citations
- Advanced LLM query model with DrAA (Doctor of Applied Anthropology) persona
- OpenAI text-embedding-3-large vector model (1024 dimensions)
- 7.9GB FAISS index optimized for CPU-based semantic search
- Cross-encoder reranking with ms-marco-MiniLM-L-6-v2

### Sources
- Major authors: David Graeber, Robert Sapolsky, Christopher Boehm, Stephen Batchelor, Richard Wrangham
- Content domains: Evolutionary biology, anthropology, philosophy, psychology, cultural studies, secular dharma
- 94 processed directories in text cache
- Symlinked to /ai/datasets/sd/sd_gpt/ for source materials

### Features
- Hybrid search capability (FAISS semantic search, BM25 disabled)
- Query result caching (30-day TTL)
- Spelling correction and semantic query expansion
- WAHID integration enabled
- Build pipeline with staged processing (0_build.sh)

### Technical Details
- SQLite database: 2.2GB with docs and citations tables
- Vector index: 7.9GB FAISS index (CPU-based due to GPU memory constraints)
- Memory cache: 250MB limit with 100K item capacity
- API concurrency: 12-24 concurrent requests with intelligent backoff
- Build date: July 18-19, 2025 (recent full system rebuild)
