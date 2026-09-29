# Architecture Review Checklist (Cloudflare)

Run this against every design before handing it over. Each item is a question you must answer in the design doc, even if the answer is "not applicable because…". Items marked ⚠ are the ones unaided designs most often miss.

## Contents
- Security
- Reliability & disaster recovery
- Performance
- Cost
- Operations & observability
- Compliance & data residency
- Delivery plan

## Security
- Is every public hostname **proxied** (orange cloud)? DNS-only records get no L7 protection and expose the origin.
- Can the origin be reached **without** going through Cloudflare? Preferred: Tunnel or CNI. Otherwise allowlist Cloudflare/Dedicated Egress IPs + Full (Strict) TLS + Authenticated Origin Pulls.
- WAF: account-level managed rulesets (Cloudflare Managed + OWASP + leaked credentials) scoped by hostname lists; new rules start in Log mode.
- Rate limiting on login, signup, password reset, search, expensive API endpoints.
- Bot strategy (SBFM / Bot Management / Turnstile) and AI-crawler policy decided.
- APIs: discovery → schema validation → JWT/mTLS → volumetric abuse / sequence rules.
- Admin and internal surfaces behind **Access** (IdP group + MFA + device posture). Machine clients use service tokens or mTLS, never Bypass.
- Tenant isolation: where is the tenant ID derived (never from client input)? Per-tenant resources or row-level scoping?
- Secrets: Workers secrets / Secrets Store; untrusted code (tenant or AI-generated) never sees credentials — inject via outbound Worker.
- LLM features: authorization enforced **before** retrieval/model call, never by the model; AI Security for Apps / AI Gateway guardrails; model output treated as untrusted.
- ⚠ Break-glass: how do admins get in if the IdP or Access is down or misconfigured?

## Reliability & disaster recovery
- Single points of failure: one Tunnel connector, one origin, one DO for everything, one region DB? Run ≥2 `cloudflared` replicas; shard DOs; LB pools with health monitors that match the real traffic path.
- ⚠ Backups and restore: D1 (Time Travel), R2 (versioning/replication strategy), external DBs behind Hyperdrive, DO storage export. State RPO/RTO.
- Retry and idempotency for Queues consumers and Workflows steps; dead-letter queue defined.
- Failure mode of every external dependency (third-party API, LLM provider → AI Gateway fallback).
- Load-balancing steering + failover policy (active/passive vs active/active) chosen explicitly.

## Performance
- Cache strategy: what is cacheable, TTLs, Tiered Cache topology, Cache Reserve for long-tail.
- Data placement: where does the data live relative to compute? Smart Placement / DO location hints / Hyperdrive caching for distant databases.
- Bulk bytes off compute: presigned R2 uploads, image transformations at the edge.
- Measure: Core Web Vitals p75, server latency p99, cache hit ratio, origin vs network time.

## Cost
- ⚠ Rough monthly estimate by component with the main cost drivers (requests, CPU ms, storage GB, operations, egress, seats, custom hostnames, LLM tokens). Mark every number "verify on current pricing page".
- Which plan tier each feature needs (Free / Pro / Business / Enterprise, Workers Paid, Zero Trust seats). Flag Enterprise-only features explicitly.
- Cost guards: AI Gateway caching + rate limits, per-tenant quotas, Queue batching, cache before compute.

## Operations & observability
- ⚠ Logs: Workers Logs / Tail Workers / Logpush to SIEM or storage; Access/Gateway/DLP logs; log retention and PII in logs.
- Metrics and alerts: Analytics Engine for custom metrics, notifications for security events, health-check alerts. SLOs stated.
- Infrastructure as code: Wrangler config + Terraform for zones, WAF, Access, LB, custom hostnames. Environments (dev/staging/prod).
- Multi-tenant: per-tenant observability and cost attribution (tags, dispatch namespace metrics).

## Compliance & data residency
- Residency requirement per data class: request processing (Regional Services), logs/metadata (Customer Metadata Boundary), keys (Geo Key Manager / Keyless SSL), storage (R2 jurisdiction, DO jurisdiction, D1 location — verify current support).
- ⚠ Data subject rights: export and deletion per tenant/user.
- Regulated requirements: FIPS 140-3 (Keyless + HSM), PCI (client-side security), TLS inspection legality/works-council notice for SWG.

## Delivery plan
- Phased rollout with a safe first phase (monitor/log-only modes, DNS filtering, pilot group).
- Migration strategy for existing data/traffic (Sippy/Super Slurper, partial CNAME setup, parallel VPN, LB traffic shift).
- Team fit: what the team must learn/operate; what is managed vs self-built.
