# Vendor Terms Rules

**NEVER expose third-party vendor or infrastructure names in public-facing code, docs, or API specs.** All integrations must appear as Aitronos-built.

## Forbidden Terms (case-insensitive)

| Term | Replace With |
|------|-------------|
| Composio | "connector platform", "integration service", or "Aitronos" |
| Airbyte | "data pipeline", "pipeline platform" |
| Fivetran | "data pipeline", "pipeline platform" |
| Qdrant / Quadrant | "vector database", "vector store" |
| Vexa | "bot service", "meeting bot service", "meeting assistant" |
| AssemblyAI | "transcription service", "speech-to-text engine" |
| Deepgram | "transcription service", "speech-to-text engine" |
| CalDAV | "calendar protocol", "calendar sync" |
| Redis | "cache", "caching layer", "session store" |
| Celery | "task queue", "background worker", "async job processor" |
| RabbitMQ | "message broker", "event bus" |
| MinIO | "object storage", "file storage" |
| Supabase | "database", "managed database" |
| Flower | "task monitor", "worker dashboard" |
| Whisper | "transcription model", "speech model" |
| faster-whisper | "transcription model", "speech model" |
| CTranslate2 | "inference engine", "model runtime" |
| PyAnnote | "diarization engine", "speaker separation engine" |
| pyannote | "diarization engine", "speaker separation engine" |
| ECAPA-TDNN | "speaker identification model", "voice recognition model" |
| SpeechBrain | "audio ML framework", "speech processing engine" |
| emotion2vec | "emotion detection model", "sentiment analysis model" |
| FunASR | "speech processing engine", "audio ML framework" |
| BERTopic | "topic segmentation model", "topic analysis engine" |
| sentence-transformers | "embedding model", "text embedding engine" |
| MiniLM | "embedding model", "text embedding engine" |
| Orpheus | "text-to-speech model", "voice synthesis model" |
| OpenAudio | "text-to-speech model", "voice synthesis model" |
| FishAudio | "text-to-speech model", "voice synthesis model" |
| vLLM | "inference engine", "model runtime" |
| RunPod | "GPU compute platform", "inference platform" |
| HuggingFace / Hugging Face | "model registry", "model repository" |
| ModelScope | "model registry", "model repository" |
| NVIDIA CUDA | "GPU acceleration", "hardware acceleration" |
| PyTorch | "ML framework", "deep learning framework" |
| canopylabs | "Aitronos", "voice synthesis" |
| fishaudio | "Aitronos", "voice synthesis" |
| iic/emotion2vec | "emotion detection model" |
| Nova-3 | "streaming transcription model" |

Projects can add extra terms via `project.config.yaml` → `compliance.vendor_terms.extra_terms`.

## Where Forbidden

- **Public docs** — `docs/public-docs/`, OpenAPI specs (`.json`, `.yaml`)
- **API-facing code** — route handler docstrings, Pydantic `Field(description=...)`, route decorator `summary=`/`description=`, schema class names, schema field names
- **Customer-facing content** — any text end users see

## Where Allowed

- **Internal code** — imports, variable names, inline `#` comments, logger calls, service logic
- **Internal docs** — `docs/app/`, `docs/.specs/`, architecture docs
- **Admin-only endpoints** — endpoints behind admin auth (e.g., `routes/admin/`)
- **Legitimate protocols** — CalDAV in Apple Calendar user instructions (it's a standard the user interacts with)
- **AI provider names** — OpenAI, Anthropic, Claude, GPT, Gemini, Mistral, Cohere are fine

## Enforcement

Two validators enforce this rule:
1. **Doc scanner** — scans public docs for vendor terms in markdown/YAML/JSON/HTML
2. **Code scanner** — AST-based scan of API-facing code for vendor terms in docstrings, Field descriptions, decorator params, class names, schema field names

See `guides/vendor-terms-validators.md` for implementation details and setup instructions.
