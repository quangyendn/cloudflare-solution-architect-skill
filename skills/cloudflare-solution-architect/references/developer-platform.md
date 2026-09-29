# Cloudflare Developer Platform — Reference Architecture Distillation

Scope: serverless, storage, AI, image delivery, IoT reference architectures (developers.cloudflare.com/reference-architecture). Facts are from the docs unless marked `(general knowledge)`.

## Contents
- Building blocks
- Patterns
  - A/B testing using Workers
  - Fullstack applications
  - Programmable Platforms
  - Serverless ETL pipelines
  - Serverless global APIs
  - Serverless image content management
  - Optimizing image delivery with image resizing and R2
  - Control and data plane pattern for Durable Objects
  - Egress-free object storage in multi-cloud setups
  - Event notifications for storage
  - On-demand object storage migration
  - Storing user generated content
  - Connected transportation systems (IoT)
  - Content-based asset creation
  - Composable AI architecture
  - Multi-vendor AI observability and control
  - Retrieval Augmented Generation (RAG)
  - AI Vibe Coding Platform
  - Automatic captioning for video uploads
  - Ingesting BigQuery data into Workers AI
  - Enterprise AI agent workspace
  - Enterprise AI Vibe Coding Platform
- Cross-cutting principles
- Decision hints

## Building blocks

| Product | Role in an architecture | Choose it when | Key constraints / gotchas (stated or implied) |
|---|---|---|---|
| **Workers** | Stateless edge compute: routing, auth, API, middleware, transformation, glue to every other product via bindings | Any dynamic request handling; API gateway/router; orchestrating AI, storage and external calls | Stateless; keep large payloads out of the Worker path (use presigned R2 URLs instead). Supports `fetch()` (HTTP) and `connect()` (TCP) for external integration. Secrets via Workers secrets. |
| **Named-only products** (Workflows, Pipelines, Stream, Realtime, Static Assets) | Workflows = durable multi-step orchestration incl. human approvals; Pipelines = managed high-volume streaming ingest; Stream = VOD/live video; Realtime = RTC; Static Assets = serve SSR/CSR frameworks from Workers | Listed in the fullstack layer map | No dedicated pattern in these docs. |
| **Misc** (Cron Triggers, Transform Rules, Email Service, Artifacts, Resource tagging) | Scheduled Workers (free); URL rewrites for image-CDN migration; email from Workers; git-compatible storage for agent code; tags for owner/cost attribution | As named | — |
| **Service Bindings** | Worker-to-Worker calls | Splitting an API into separately deployed microservice Workers behind a router Worker (separation of concerns) | Router does validation/auth once, then forwards enriched calls. |
| **Workers for Platforms (dispatch namespace, dynamic dispatch Worker, user Workers, outbound Worker)** | Multi-tenant hosting of customer- or AI-generated code | Programmable SaaS, vibe-coding hosting, "unlimited" per-tenant apps | Each tenant = isolated user Worker with only explicitly attached bindings. Dispatch Worker does routing (typically via KV metadata by hostname), can set custom limits (max processing time, subrequests) per invocation; exceeding throws an exception the dispatcher can handle. Outbound Worker intercepts all tenant `fetch()` for policy, audit, credential injection. Scales to zero. |
| **Dynamic Workers** | Ephemeral isolate for bounded code evaluation ("Code Mode") | Fast validation of AI-generated scripts/functions, tool composition, no container overhead | Lightweight, ephemeral; has its own egress control. Not a full shell/build environment. |
| **Durable Objects (DO)** | Stateful, single-threaded compute with its own durable (SQLite) storage and in-memory state | Coordination, strong consistency, real-time, per-resource/per-user/per-workspace state, agent state | Single instance has finite throughput/storage limits → shard by resource. Location set by first access or Location Hint. Address by `idFromName` (deterministic, no mapping table) or `newUniqueId` (random ID returned to client). Can scale to millions of instances. |
| **Agents SDK** | Framework on DOs for stateful AI agents (state, tools, scheduling, workflows, human-in-the-loop, real-time) | Chat agents, enterprise agent workspaces | One DO per agent/workspace is the durable authority; work continues after client disconnect. |
| **KV** | Global, eventually consistent key-value store | Read-heavy, rarely changing data: config, feature flags, A/B config, tenant metadata, product info, image metadata | Eventually consistent; write limits apply ("perform writes as needed keeping limits in mind"). Not for strongly consistent state. |
| **D1** | Serverless SQLite relational DB | Relational data: users, products, document text for RAG, upload metadata, app registry | Per-tenant D1 per user Worker possible in WfP. Single-database size/throughput limits `(general knowledge)`. |
| **Hyperdrive** | Connection pooling + query caching to existing external databases | Worker must talk to an existing Postgres/MySQL and migration is out of scope | Caching helps only where applicable (read queries). |
| **R2** | S3-compatible object storage, zero egress fees | Blobs, UGC, originals for image transforms, video/subtitles, ETL output, telemetry logs, multi-cloud shared data lake, sandbox backups, skills/context library | Access via Workers binding API or S3 API (S3 API for portability); public buckets for CDN origin; presigned URLs for direct client upload. No egress fees from Workers or external clouds. |
| **R2 Event Notifications** | Emit a Queue message on object create/delete | Post-processing after upload/delete (ETL, AI, moderation, metadata cleanup, audit log) | Delivered via Queues only; consumer can be a push Worker or pull HTTP consumer. |
| **Sippy** | On-demand (lazy) migration from another object store into R2 | Avoid a large upfront transfer bill; migrate hot data as it is read | Miss → fetched from source and copied simultaneously; large objects may need several requests (multipart copy). |
| **Super Slurper** | Bulk one-time migration into R2 | Move remaining/cold data, often after Sippy | One-time, large-scale. |
| **Queues** | Durable async messaging; batching consumers; ack/retry | Decouple ingest from processing, absorb spikes, protect downstream, per-message retry | Push consumer = Worker; pull consumer = HTTP from any environment (consumer controls rate, must explicitly ack). |
| **Workers AI** | Serverless GPU inference (text gen, embeddings, classification, text-to-image, ASR, image classification) | Inference close to users with no model hosting; via binding or REST | Binding abstracts auth. Model catalog-dependent. |
| **Vectorize** | Globally distributed vector DB | Similarity search: RAG, recommendations, personalization | Store vectors only; keep source documents in D1/R2 and join by ID. |
| **AI Search** (formerly AutoRAG `(general knowledge)`) | Fully managed RAG (ingest, index, query) | You want RAG without building the Queue→embed→Vectorize→D1 pipeline | Less control than the DIY pattern. |
| **AI Gateway** | Forward proxy between app and any inference provider | Multi-vendor LLM usage, caching, rate limiting, retries/fallback, logs, cost tracking/attribution, DLP guardrails | Single control point; keeps provider routing and credentials out of app/workspace code. |
| **Sandbox SDK** | Managed container sandbox with pre-built exec/file/dev APIs, preview URLs, streaming output | Running untrusted AI-generated code; full shell/build/preview env | Fully managed; start here for most AI code-exec cases. Egress via outbound handler. |
| **Containers** | Docker-compatible workloads on Cloudflare | Custom runtimes/languages, resource-heavy jobs beyond Worker limits | The RA doc cited up to 4 GB RAM; current instance types are larger — verify `/containers/platform/limits/`. Supports placement/jurisdiction constraints (verify). Outbound handler intercepts HTTP egress. |
| **Browser Run** (Browser Rendering `(general knowledge)`) | Isolated headless browser sessions | Agent web navigation, screenshots, PDF rendering | Session-scoped. |
| **Images / image resizing** | On-the-fly resize/format/quality via `/cdn-cgi/image/<opts>/<path>` URL | Responsive images without storing variants | Store only originals in R2; variants cached at edge. Format negotiation (WebP/AVIF), Polish. |
| **Cache / CDN** | Edge cache in front of R2, Workers, origins | Static assets, transformed images, videos/subtitles | Cache HIT short-circuits storage + compute. |
| **Workers Analytics Engine** | Custom high-cardinality metrics from Workers | Per-tenant/per-app usage metrics, lifecycle events | Query via SQL/GraphQL `(general knowledge for SQL)`. |
| **Tail Workers / Workers Trace Events Logpush / Workers Logs / GraphQL Analytics** | Observability | WfP platform-wide logs (Logpush on dispatch Worker covers namespace), per-app logs (Tail Worker), aggregate metrics (GraphQL by `dispatchNamespaceName`) | Export to Datadog/Splunk/Grafana. |
| **Secrets Store** | Central secret storage | Inject credentials at platform layer (outbound Worker/handler) so untrusted code never sees them | — |
| **Workers VPC + Cloudflare Tunnel** | Private connectivity from Workers to on-prem/internal systems | Reach internal systems without Internet exposure | — |
| **MCP server portals** (Cloudflare One) | Single governed MCP endpoint; Access policies, tool curation, per-user credential routing, logging | Agents using enterprise tools | Build per team to limit tool surface. |
| **Cloudflare Access** | Identity-aware access (SAML/OIDC SSO) | Protect platform UI, CLI harness, deployed internal apps (via dispatch Worker), Worker endpoints | — |
| **App-services edge (WAF, DDoS, Bot Mgmt, API Shield, rate limiting, mTLS, Argo, Load Balancing, CNI)** | Security/perf in front of compute | Every public entrypoint; mTLS for device identity (IoT) | Not dev-platform products but present in most diagrams. |

## Patterns


### A/B testing using Workers
- **Problem:** Same-URL server-side A/B tests, no client changes, config independent of deploys.
- **Flow:** 1) Request → Worker. 2) Read experiment config from KV. 3) Read group cookie or assign randomly; route to origin A or B. 4) Return response, set cookie for affinity.
- **Decisions/trade-offs:** KV config = change without redeploy, but eventually consistent `(general knowledge)`.
- **Use / not:** Origin-level routing experiments; not for metrics collection (add Analytics Engine).
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/serverless/a-b-testing-using-workers/

### Fullstack applications
- **Problem:** Map a complete web stack onto one composable platform.
- **Flow (layers):** 1) Client → 2) Security (TLS, DDoS, WAF, bots, API Shield) → 3) CDN cache + Argo → 4) Compute: Workers (+Static Assets for SSR/CSR), WfP (customer code), DOs (stateful), Containers (Docker, bigger resources) → 5) Data: R2, D1, KV, DO → 6) Media: Realtime, Images, Stream → 7) AI: Workers AI, Vectorize, Agents SDK → 8) Queues, Workflows, Pipelines → 9) Logpush, Workers Logs, Analytics Engine, AI Gateway → 10) external log/analytics sinks, GraphQL → 11) Terraform/Pulumi/Wrangler/API in CI/CD → 12) outbound integrations.
- **Decisions/trade-offs:** Serve static from cache before compute; choose storage per access pattern; Containers only when a Worker is not enough.
- **Use / not:** Checklist for greenfield designs; not a detailed flow.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/serverless/fullstack-application/

### Programmable Platforms
- **Problem:** Customers run custom code safely: untrusted execution, abuse, resource contention, cost of millions of single-tenant apps (scale-to-zero), governance.
- **Flow:** 1) Custom hostname / wildcard route → dispatch Worker. 2) Tenant metadata from KV (by hostname). 3) Invoke user Worker in dispatch namespace with context. 4) Tenant `fetch()` goes through Outbound Worker (policy, audit). 5) Per-script D1/DO/KV/R2 bindings. 6) Tail Worker + Trace Events Logpush, Analytics Engine + GraphQL, export to Datadog/Splunk/Grafana. 7) Deploys: your GUI/API/CLI bundles code, runs security checks, deploys via Cloudflare REST API.
- **Decisions/trade-offs:** Hard isolation per tenant; central egress control; you build the deploy control plane.
- **Use / not:** SaaS extensibility, hosting generated apps; overkill for single-tenant apps.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/serverless/programmable-platforms/

### Serverless ETL pipelines
- **Problem:** ETL without managing infrastructure.
- **Flow (HTTP ingest, e.g. click-stream):** 1) POST → Worker. 2) Enqueue. 3) Queue consumer transforms in batches. 4) Write to R2. 5) Per-message ack/retry. 6) External tools query results. **Variant (logs/docs):** upload to R2 via S3 API → event notification → Queue → same steps.
- **Decisions/trade-offs:** Batching protects downstream and raises efficiency; per-message ack isolates failures.
- **Use / not:** Async ingest/transform; sink is object storage, not a query-serving warehouse.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/serverless/serverless-etl/

### Serverless global APIs
- **Problem:** Single-region serverless sends all global traffic to one place; distribute compute and data.
- **Flow:** 1) Request → router Worker (validate, auth, enrich). 2) Service Bindings to domain Workers. 3) KV for read-heavy static data (mind write limits). 4) D1 for relational. 5) Hyperdrive (with caching) for existing external DBs.
- **Decisions/trade-offs:** Compute distribution alone does not help without cached/replicated data; Hyperdrive avoids a migration.
- **Use / not:** Global APIs; write-heavy central DB still bounds latency.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/serverless/serverless-global-apis/

### Serverless image content management
- **Problem:** Scalable image storage/delivery with moderation and abuse protection.
- **Flow:** 1) Client requests HMAC-signed URL with transform params. 2) Rate limiting + DDoS. 3) Worker validates signature/expiry. 4) Cache or fetch; serve WebP/AVIF, compressed. 5) Edge resizing. 6) On upload, Worker runs Workers AI image classification, enforces policy, stores image + metadata in R2 (metadata also KV).
- **Decisions/trade-offs:** Expiring signatures stop tampering and hotlinking; AI classification reduces manual review.
- **Use / not:** UGC image platforms; for plain optimization use the next pattern.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/serverless/serverless-image-content-management/

### Optimizing image delivery with image resizing and R2
- **Problem:** Images dominate page weight; serve per-device variants cheaply.
- **Flow:** 1) Request `/cdn-cgi/image/width=80,quality=75/uploads/image.jpg`. 2) Edge cache hit → return. 3) Optional Transform Rules rewrite legacy URL syntax. 4) Miss → R2 (originals only). 5) Images transforms, caches, returns.
- **Decisions/trade-offs:** No stored variants → no lifecycle rules; URL-driven so minimal app refactor.
- **Use / not:** Default web image optimization and image-CDN migrations; add signing/moderation for UGC.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/content-delivery/optimizing-image-delivery-with-cloudflare-image-resizing-and-r2/

### Control and data plane pattern for Durable Objects
- **Problem:** One DO has finite capacity; scale to millions of resources with data near users.
- **Flow:** 1) Create request → Worker. 2) Worker reaches control DO by `idFromName` (placed at first access or Location Hint). 3) Control DO creates a data-plane DO near the user (Location Hint), optionally `init()` with metadata; ID via `idFromName` or `newUniqueId`. 4) Control DO stores the ID (for list/delete), returns it. 5–9) All later reads/writes go Worker → owning data-plane DO directly.
- **Decisions/trade-offs:** High-volume data ops bypass the control plane; control DO can itself be sharded (e.g. per region). Requires a data model split into self-contained resources; cross-resource queries get harder `(implied)`.
- **Use / not:** Wikis, collaborative docs, per-user DBs; not for global cross-resource transactions.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/storage/durable-object-control-data-plane-pattern/

### Egress-free object storage in multi-cloud setups
- **Problem:** Egress fees when data moves between clouds, notably for AI training, query engines, data science.
- **Flow:** 1) Workers use R2 Workers API (or S3 API for portability). 2) External clouds use S3 API. No R2 egress fees either way.
- **Decisions/trade-offs:** R2 as neutral data layer; compute stays wherever it runs best.
- **Use / not:** Several clouds reading the same large datasets.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/storage/egress-free-storage-multi-cloud/

### Event notifications for storage
- **Problem:** React to R2 data changes.
- **Flow (push):** upload → notification → Queue → consumer Worker → action (e.g. log to another bucket, AI on image). **Pull:** delete → Queue → external service POSTs to pull when ready → acks.
- **Decisions/trade-offs:** Push for Cloudflare-native processing; pull when consumer is outside Cloudflare and must control rate.
- **Use / not:** Admin alerts on delete, ASR subtitles on upload, deleting related DB rows.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/storage/event-notifications-for-storage/

### On-demand object storage migration
- **Problem:** Migrate without missing new writes or paying a large one-time transfer.
- **Flow:** 1) Client requests via Workers, S3 API or public bucket. 2) Hit in R2 → serve. 3) Miss → Sippy serves from source and copies to R2 at the same time (large objects may take several requests, multipart).
- **Decisions/trade-offs:** Migration egress rides on reads already paid for; hot data moves first; Super Slurper finishes the rest.
- **Use / not:** Gradual migration; use Super Slurper alone for one-shot cutover.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/storage/on-demand-object-storage-migration/

### Storing user generated content
- **Problem:** Secure, cheap UGC uploads and persisting AI output.
- **Flow A:** 1) Frontend sends file metadata to Worker. 2) Worker authenticates, checks permissions, size/MIME. 3) Returns time-limited presigned PUT URL scoped to a key. 4) Client streams to R2. 5) Optional event notification → Queue → scan/moderate/transform, metadata to D1, notify user.
- **Flow B:** Worker → Workers AI → output PUT to R2 via binding → return key or signed download URL.
- **Decisions/trade-offs:** Bytes bypass the Worker (latency, cost); validation before URL issuance.
- **Use / not:** Default for uploads; add Images/Stream for media processing.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/storage/storing-user-generated-content/

### Connected transportation systems (IoT)
- **Problem:** Secure, low-latency data for fixed devices (CCTV, signals via gateways) and roaming devices (trucks, drones, emergency vehicles).
- **Flow:** 1) mTLS device auth. 2) Anycast to nearest DC. 3) API Shield, WAF, DDoS L3–L7, DNS security, TLS. 4) CDN, Load Balancing, Workers with KV (config), D1 (SQL), DOs (real-time consistency); Workers AI for anomaly detection/predictive maintenance; Argo; R2 for telemetry. 5) Origins anywhere via DNS, CNI (private) or cloudflared Tunnel (no public exposure).
- **Decisions/trade-offs:** Process at edge, lazily update core services; origin-agnostic keeps legacy backends.
- **Use / not:** Device fleets needing strong identity and edge processing.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/iot/optimizing-and-securing-connected-transportation-systems/

### Content-based asset creation
- **Problem:** Generate images from text safely.
- **Flow:** 1) POST content. 2) Workers AI text-gen writes image prompt. 3) Text-classification safety check (e.g. Llama Guard). 4) Text-to-image.
- **Decisions/trade-offs:** Model chaining with moderation between stages.
- **Use / not:** Marketing/publishing assets; persist output per UGC pattern.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-asset-creation/

### Composable AI architecture
- **Problem:** Avoid AI vendor lock-in via composability, data portability, standard APIs.
- **Flow:** Compute (Workers; `fetch()`/`connect()`) ↔ Inference (Workers AI or self-hosted) ↔ Vector search (Vectorize or other) ↔ Data (D1, R2 or other).
- **Decisions/trade-offs:** REST APIs for use from anywhere vs bindings for simpler auth inside Workers.
- **Use / not:** Justifies hybrid designs mixing Cloudflare and external layers.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-composable/

### Multi-vendor AI observability and control
- **Problem:** Fragmented providers, uneven availability, logging, security and cost control.
- **Flow:** 1) Service POSTs to AI Gateway. 2) Gateway serves cache or forwards; logs, analytics, rate limits. 3) On error, retry or fall back to another provider.
- **Decisions/trade-offs:** Cross-cutting concerns moved to one proxy with uniform config.
- **Use / not:** Any production LLM traffic.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-multivendor-observability-control/

### Retrieval Augmented Generation (RAG)
- **Problem:** Ground LLM answers in a knowledge base.
- **Seeding:** POST docs → Worker → Queue → batched consumer → Workers AI embeddings → Vectorize (vectors) + D1 (documents) → ack/retry.
- **Query:** embed query → Vectorize search → fetch docs from D1 → Workers AI generation with query + docs.
- **Decisions/trade-offs:** Queue shields embedding model from bursts; vectors and text stored separately. Managed alternative: AI Search.
- **Use / not:** DIY for control over chunking/storage; AI Search for speed.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-rag/

### AI Vibe Coding Platform
- **Problem:** Natural-language app builder: untrusted generated code, instant previews, hosting millions of apps.
- **Flow:** 1) Prompt → AI Gateway (multi-provider, response cache, observability, cost) → LLM; improve output with Workers Prompt and Docs MCP server. 2) Run code in Sandbox SDK (managed, default) or Containers (custom image, dedicated vCPU; check current instance sizes): isolation, fast start, streamed logs, preview URLs. 3) Deploy to WfP: one Worker per app, outbound Worker, custom limits, per-app KV/DB. 4) Analytics on usage/cost. Starter: `cloudflare/vibesdk`.
- **Decisions/trade-offs:** Dev sandbox separate from production hosting; Sandbox = convenience, Containers = runtime control.
- **Use / not:** Product-grade builders; internal governed use → enterprise version.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-vibe-coding-platform/

### Automatic captioning for video uploads
- **Problem:** Automatic, multilingual subtitles.
- **Flow:** 1) POST video+audio. 2) Workers AI ASR → timestamped text → Worker converts to subtitle format. 3–4) Subtitles and video to R2. 5) GET via cache. 6) Miss → R2 public bucket.
- **Decisions/trade-offs:** Inference sits in the upload path; for large files event notifications are the async option `(implied)`.
- **Use / not:** Simple video sites; heavy delivery may call for Stream.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-video-caption/

### Ingesting BigQuery data into Workers AI
- **Problem:** Enrich warehouse data with AI (sentiment, tags).
- **Flow (user):** Worker (optionally behind Access) → JWT from GCP service account in Workers secrets → BigQuery → reshape → Workers AI binding → return data + AI output. **Flow (cron):** Cron Trigger → same → store to D1, Vectorize, KV or R2 → notify via email or webhook.
- **Decisions/trade-offs:** Interactive for ad-hoc reports, cron for periodic/long batches.
- **Use / not:** Trialing models on existing data; for large continuous volume prefer Queue-based ETL `(implied)`.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/ai/bigquery-workers-ai/

### Enterprise AI agent workspace
- **Problem:** Persistent, governed AI workspaces producing durable outputs using org knowledge and skills.
- **Flow:** 1) Invoke from web, chat, email, webhooks, schedules; Access for browsers, signature/token checks for async channels. 2) Stateless Worker routes to per-workspace DO (Agents SDK) holding conversation, tasks, schedules, consent, event queue; per-user DO holds profile, workspace registry, integrations, grants. 3) Execution per task: Dynamic Workers (Code Mode), Sandbox container (shell/builds/previews), Browser Run (browse, screenshot, PDF). 4) Models via AI Gateway; tools via MCP server portal. 5) Outputs to versioned file service with sharing grants stored apart from bytes; skills/context library and sandbox backups in R2; usage in Analytics Engine.
- **Decisions/trade-offs:** All channels share one workspace history; work survives disconnects; skills layered platform → org → workspace and loaded on demand; read-only curated library; model/tool output and code treated as untrusted, credentials never in model context.
- **Use / not:** Internal agents with outputs beyond code; always-an-app → enterprise vibe coding.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/ai/enterprise-ai-agent-workspace/

### Enterprise AI Vibe Coding Platform
- **Problem:** Governed internal app building: data leaks in prompts, unapproved LLMs, unknown code quality, cost attribution, discoverability, audit.
- **Flow:** 1) **Dev plane:** Access (SSO) on UI and CLI harness; metadata (users, sessions, cost tags, permissions) in D1/KV/R2; execution in Sandbox containers (full previews) and/or Dynamic Workers (instant checks); local harnesses can use AI Gateway + MCP portals; AI Gateway does routing, per-team/user cost, prompt logs, DLP; egress through container outbound handler / Dynamic Worker egress control with Secrets Store injection; Workers VPC for internal systems. 2) **Deploy pipeline:** code in enterprise git or Artifacts; existing review, scans, CI/CD, human approval. 3) **Prod plane:** WfP with Access on the domain enforced in dispatch Worker (RBAC); outbound Worker injects secrets and gates bindings, Hyperdrive, Workers VPC + Tunnel; per-app D1/KV/R2; custom limits by tier; Logpush on dispatcher, GraphQL by `dispatchNamespaceName`, Tail Workers per app, Analytics Engine by script tag; metadata store as app registry; resource tagging.
- **Decisions/trade-offs:** Security enforced at the platform, not in code; allowlisted bindings prevent privilege escalation.
- **Use / not:** Internal citizen-developer platforms with compliance needs.
- **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/ai/enterprise-ai-vibe-coding-platform/

## Cross-cutting principles

- **Stateless Workers, state behind bindings.** Workers route/auth/validate; state lives in KV, D1, DO, R2, Vectorize; agents keep state in DOs.
- **Distribute data, not just compute.** KV for read-heavy data, DO Location Hints, Hyperdrive caching, edge cache.
- **Shard into self-contained units.** One DO per resource/user/workspace; separate control-plane DO for metadata; data traffic goes straight to the owning DO.
- **Match storage to access pattern.** KV eventual/read-heavy; D1 relational; DO strongly consistent; R2 blobs; Vectorize vectors with source text elsewhere.
- **R2 as egress-free data layer** for originals, UGC, media, ETL output, multi-cloud data, telemetry, backups.
- **Keep bulk bytes off compute.** Presigned uploads; cache + public buckets / image transforms for downloads; derive variants at the edge.
- **Decouple with Queues.** Batch, ack/retry, protect downstream; R2 notifications turn storage changes into messages.
- **Per-tenant isolation.** WfP user Worker per tenant, explicit bindings, per-tenant D1/KV/R2, custom limits, outbound Worker.
- **Security at the platform boundary.** Generated code and model output are untrusted; inject secrets outside the code; Access and MCP portals for identity and tools.
- **One AI control point.** AI Gateway for every model call keeps apps vendor-portable.
- **Composability.** REST/S3 APIs for outside use, bindings for simpler internal use.
- **Two-level observability** for multi-tenant: platform-wide plus per-tenant, with resource tags for cost.

## Decision hints

- Read-heavy config/tenant metadata → **KV** over D1/DO (fast reads, deploy-independent); accept eventual consistency.
- Strong consistency, coordination, real-time, per-entity state → **Durable Objects** over KV.
- Relational app data → **D1**; existing Postgres/MySQL you cannot migrate → **Hyperdrive**.
- One DO is a bottleneck → **control/data-plane split**; shard the control DO per region if needed. Stable business key → `idFromName`; opaque ID → `newUniqueId`.
- File uploads → **Worker-issued presigned R2 URL** over proxying bytes through a Worker.
- Post-upload work → **R2 event notifications → Queue** over synchronous processing; external consumer controlling rate → **pull consumer**.
- Bursty ingest → **Worker → Queue → batched consumer** over direct writes.
- Responsive images → **Images URL transforms + originals in R2 + cache** over pre-generated variants; migrating image CDN → **Transform Rules**; UGC images → add **HMAC signing + AI classification**.
- Multi-cloud or analytics/training reads of large data → **R2 via S3 API** to avoid egress fees.
- Migration: hot data, no upfront bill → **Sippy**; bulk/cutover → **Super Slurper**.
- RAG with control → **Queues + embeddings + Vectorize + D1**; managed → **AI Search**.
- Any production LLM calls, especially multi-provider → **AI Gateway**.
- Untrusted code: default → **Sandbox SDK**; custom runtime/heavy → **Containers**; instant small scripts → **Dynamic Workers**; browsing/PDF → **Browser Run**.
- Hosting many customer/AI apps → **Workers for Platforms**; credentials for tenant code → **Secrets Store via outbound Worker**.
- Internal/on-prem reach → **Workers VPC / Tunnel** (CNI for private network links) over public origins.
- Stateful multi-channel agent → **Agents SDK on a per-workspace DO** + per-user DO; enterprise tools → **MCP server portals**.
- Periodic batch → **Cron Triggers**; API microservices → **Service Bindings** behind a router Worker.
- IoT device identity → **mTLS + API Shield**; telemetry → **R2**; edge anomaly detection → **Workers AI**.


Full document list with URLs: see catalog.md.
