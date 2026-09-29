# Volatile Facts: What to Verify and Where

Limits, prices, plan tiers, residency support and product names change often. Do not state them from memory. This file lists **what to check** and **where**, plus caveats that design tests showed are easy to miss (observed 2026-09-29; re-verify before relying on them).

Fetch any docs page as Markdown by appending `index.md` to its URL, or use the Cloudflare docs MCP tool when it is available.

## Contents
- Where to verify
- Data residency caveats
- Plan / add-on gates frequently missed
- Product caveats frequently missed
- AI / RAG specifics
- Cost estimation sources

## Where to verify
| Fact type | Source |
|---|---|
| Workers / DO / KV / D1 / Queues / Hyperdrive / Workflows / Vectorize / Workers AI limits | `https://developers.cloudflare.com/<product>/platform/limits/` |
| Containers limits and placement | `/containers/platform/limits/`, `/containers/concepts/placement/` |
| Developer Platform pricing | `/workers/platform/pricing/`, `/r2/pricing/`, `/containers/pricing/`, `/durable-objects/platform/pricing/`, `/d1/platform/pricing/`, `/kv/platform/pricing/`, `/queues/platform/pricing/`, `/hyperdrive/platform/pricing/`, `/workflows/reference/pricing/`, `/workers-ai/platform/pricing/`, `/vectorize/platform/pricing/`, `/ai-gateway/reference/pricing/`, `/ai-search/platform/limits-pricing/`, `/browser-run/pricing/` |
| Application services / Zero Trust plan tiers and seat pricing | `https://www.cloudflare.com/plans/`, `https://www.cloudflare.com/plans/zero-trust-services/` (not on developers.cloudflare.com; Enterprise prices are contract-only → say "quote from sales") |
| Cloudflare for SaaS quotas and pricing | `/cloudflare-for-platforms/cloudflare-for-saas/plans/` |
| Data residency per product | `/data-localization/compatibility/` (the source of truth; per-product ✅/✘/🚧 for Regional Services, CMB, jurisdictions) |
| Storage location controls | `/r2/reference/data-location/`, `/durable-objects/reference/data-location/`, `/d1/configuration/data-location/` |
| Renames / GA status | product changelog: `https://developers.cloudflare.com/changelog/` |

## Data residency caveats
Residency is never solved by one switch. Build a **data-class table** (processed / stored / logged, per data class) and check every product in the path against `/data-localization/compatibility/`.
- Regional Services scopes where HTTP traffic is decrypted and processed for a hostname. It does not automatically cover every downstream product (e.g. Queues, Cron Triggers, outbound subrequests). Check the compatibility table.
- Customer Metadata Boundary is **account-wide**. With CMB outside the US, many dashboard analytics are empty and you rely on Logpush. Some features stop working (e.g. API Shield discovery, volumetric abuse detection and sequence analytics with CMB=EU).
- Jurisdictions: R2 buckets and Durable Objects support jurisdictions. KV and D1 did not support jurisdictional storage at last check. Workflows, Queues and Hyperdrive residency was undocumented. For non-jurisdictional services, pass **opaque IDs only**, never personal data.
- Placement features (Smart Placement, placement hints) can move execution out of the region. Do not use them on regional paths.
- **Existing DB cannot move + residency required:** split by data class. Blobs, jobs, edge processing and logs go in-region now. Relational rows stay put under a documented legal basis, or a regional DB shard is planned. Make this an explicit open decision, not a hidden assumption.

## Plan / add-on gates frequently missed
Mark these "Enterprise / add-on — verify" in the component table:
- Data Localization Suite (Regional Services, CMB, Geo Key Manager)
- Apex proxying for Cloudflare for SaaS
- Per-tenant custom WAF rulesets (WAF for SaaS)
- Uploaded content (malicious upload) scanning
- Enterprise Bot Management
- Advanced load-balancing steering options
- Cache Reserve and custom Tiered Cache topologies
- AI Security for Apps (Enterprise add-on)
- Waiting Room: basic on Business; scheduled events, random queueing, multiple paths need Waiting Room Advanced
- Client-side security (ex-Page Shield): monitoring on lower tiers; malicious-script detection and content security rules (blocking) need the Advanced add-on
- Rate limiting: rule count, counting expressions and keys on bot-management fields depend on plan / Bot Management
- Browser Isolation (Zero Trust add-on; clientless isolation included)
- DLP / CASB entitlements
- Dedicated egress IPs
- Magic Transit / Cloudflare WAN / CNI

## Product caveats frequently missed
- **Presigned R2 URLs** work on the S3 endpoint (`<account>.r2.cloudflarestorage.com`, or the jurisdiction endpoint such as `<account>.eu.r2.cloudflarestorage.com`), not custom domains. They need bucket CORS for browser uploads. They **bypass the zone WAF**, so validate at URL issuance: auth, size, type, key prefix, short expiry.
- **Uploaded content scanning** (WAF) only sees traffic through the proxied zone and has a scan-size cap. It is not a virus-scanning solution for large or direct-to-R2 uploads. Use a scanning job (e.g. a container running an AV engine) triggered after upload.
- **Containers** instance sizes have grown beyond earlier figures. Check current instance types, placement/jurisdiction constraints and cold-start behaviour before sizing heavy jobs.
- **Background jobs:** Queue → (Workflow or per-job Durable Object) → Container / Browser Run. A Durable Object gives jurisdiction control and alarms for retries. Workflows gives durable steps but check its residency and limits. Always use idempotent job IDs and a DLQ.
- **Hyperdrive** has a per-config origin connection cap. Size the database `max_connections`. It can reach private databases via Tunnel / Workers VPC.
- **SSH / infrastructure access:** Access for Infrastructure gives short-lived certificates and command logging. Prefer it over long-lived keys over private IPs.
- **Contractor access tie-breaker:** internal hostnames may be published publicly → Access self-hosted app + Isolate. Internal hostnames must stay out of public DNS → clientless Browser Isolation + resolver policies to private DNS. Non-HTTP apps need the client either way.
- **Flash sales / drops:** Waiting Room sized to *tested* origin capacity (not the peak), plus cache for catalog pages, Bot Management score rules, Turnstile **pre-clearance** (challenge pages break SPA fetch/XHR calls; pre-clearance does not), rate limits keyed by session/account rather than IP, and per-account purchase limits in the app. Hot-stock contention → consider a Durable Object per SKU for reservations.
- **PCI DSS:** keep card fields in the payment provider's hosted iframe/redirect to shrink scope. Client-side security covers script inventory and change detection (PCI DSS v4 6.4.3 / 11.6.1). Do not log payment request bodies. Get Cloudflare's AOC for the responsibility matrix.
- **Cloud origins (AWS/GCP/Azure):** run `cloudflared` on VMs/containers inside the VPC reaching an internal LB. Alternative: allowlist Cloudflare IPs at the cloud LB/WAF (e.g. security groups, Cloud Armor) + Authenticated Origin Pulls.
- **Gmail outbound DLP** is not covered by the Microsoft-only outbound email DLP add-in. Use Google Workspace native DLP or a Gateway/CASB approach.

## AI / RAG specifics
- **AI Gateway in front of AI Search:** do **not** enable caching or rate limiting on the gateway used by AI Search indexing (breaks indexing). Use a **separate** gateway for generation calls.
- **AI Gateway cost control:** Dynamic Routing (route by metadata/complexity, fallback) and Spend Limits exist; verify current behaviour. Spend limits are eventually consistent.
- **Per-group document ACLs:** metadata filtering in AI Search / Vectorize is limited (few custom fields, no filtering on string arrays at last check). For department/group ACLs prefer **an instance or namespace per group** plus a D1 ACL re-check. Page-level ACLs → DIY Vectorize with per-document ACL filtering in the Worker.
- AI Search has per-file size and per-instance file-count limits, and a cap on instances per cross-instance query. Verify before sizing.
- AI Gateway also offers DLP and guardrails (verify current status). AI Security for Apps protects public LLM endpoints at the WAF layer (JSON bodies).

## Cost estimation sources
1. Get volumes from requirements (requests, CPU-ms, GB stored, operations, messages, container seconds, tokens, seats, hostnames).
2. Pull unit prices from the pages above at design time. Show the arithmetic.
3. Enterprise-only or add-on items → "contract / quote from sales". Usually the biggest line, so call it out.
4. Label the table: "Estimates; verify on current Cloudflare pricing pages."
