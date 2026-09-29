---
name: cloudflare-solution-architect
description: Use when designing, reviewing, or choosing a system architecture that runs on or is fronted by Cloudflare — e.g. "design this on Cloudflare", "which Cloudflare products should we use", migrating from AWS/GCP/Azure or a legacy VPN/CDN/WAF to Cloudflare, multi-tenant SaaS with custom domains, serverless apps on Workers/Durable Objects/D1/R2/Queues, AI/RAG/agent platforms, Zero Trust/SASE/VPN replacement, WAF/bot/API/DDoS protection, load balancing/CDN performance, Magic Transit/WAN/BYOIP network designs, data residency on Cloudflare. Not for writing Worker code or wrangler config (use the cloudflare/wrangler skills for that).
---

# Cloudflare Solution Architect

## Overview
Turns a business/technical problem into a Cloudflare architecture grounded in Cloudflare's official Reference Architectures (all 75 documents distilled under `references/`). The design must be traceable: every product choice cites a pattern or decision rule, every volatile fact (limit, price, plan, GA status) is verified, and every assumption is written down.

## Workflow

1. **Capture requirements.** Fill the "Context & requirements" section of `assets/design-doc-template.md`: functional needs, scale, latency, availability (RPO/RTO), security, compliance/residency, budget, team size/skills, systems that cannot move, current Cloudflare plan.
   - If a missing answer would change the architecture (e.g. residency scope, must the DB stay put, managed vs unmanaged devices, apex domains, Enterprise contract acceptable), **ask before designing** — up to 5 targeted questions.
   - If the user wants a design now or cannot answer (including when you run as a subagent), write those questions in the template's **Open questions** block, then proceed with each answer as a labelled assumption.
2. **Classify the problem** into one or more solution areas (table below) and read the matching reference file(s). The files are large (3–5k words): run `grep -n '^##' <file>` first, then Read only the relevant sections with offset/limit. Always read `references/volatile-facts.md`.
3. **Pick patterns.** Start from the closest documented pattern; combine patterns for composite problems (e.g. SaaS = app-performance-saas + app-data-security + developer-platform). Note which reference architecture each part comes from.
4. **Choose products with the decision rules** in each reference file's "Decision hints". State the rejected alternative and why for each major choice.
5. **Verify volatile facts** before stating them: limits, pricing, plan/Enterprise-only availability, residency support, GA vs beta, current product names. `references/volatile-facts.md` lists which pages to check and the caveats most often missed. Use the Cloudflare docs MCP tool (`mcp__plugin_cloudflare_cloudflare__docs` / `search`) if available, otherwise fetch `https://developers.cloudflare.com/<product>/…/index.md`. If you cannot verify, write "(unverified — check current docs)". Never present a remembered limit as fact. For residency, always build the data-class table (processed / stored / logged) against `/data-localization/compatibility/`.
6. **Review** the design against `references/review-checklist.md` (security, reliability/DR, performance, cost, operations, compliance, rollout). Fix gaps or record them as open decisions.
7. **Deliver** using `assets/design-doc-template.md`: Mermaid diagram, numbered flows, component table (product · why · plan · limits), cost estimate, trade-offs/open decisions, phased rollout, references (URLs from `references/catalog.md`). Match the user's language for prose; keep product names in English.
   - **Short form** (user asks for brief, or a word budget applies): keep Open questions + assumptions, diagram, component table, top risks/open decisions, rollout phases; fold the other sections into one "Security, reliability & cost notes" list that still names every ⚠ item from the checklist.

## Solution-area routing

| Problem signals | Read |
|---|---|
| Serverless app/API, storage choice, uploads, ETL, queues, image pipeline, multi-tenant platform hosting customer code, AI/RAG/agents, LLM gateway, IoT | `references/developer-platform.md` |
| CDN/caching, slow TTFB, load balancing/failover/GSLB, DNS setup, multi-CDN/multi-vendor, **SaaS provider custom domains** (Cloudflare for SaaS) | `references/app-performance-saas.md` |
| WAF, bots, credential stuffing, API protection, DDoS L7, origin lockdown, securing LLM apps, data at rest/in transit/in use, FIPS, PCI | `references/app-data-security.md` |
| Replace VPN, ZTNA/Access policies, SWG/Gateway, DLP/CASB, SaaS security, contractors/BYOD, startup Zero Trust rollout | `references/sase-zero-trust.md` |
| Microsoft/CrowdStrike/SentinelOne integration, email security, VDI replacement, VoIP, protective DNS/ISP, branch appliance, guest Wi‑Fi | `references/sase-scenarios.md` |
| L3 DDoS for IP prefixes, Magic Transit, BYOIP, WAN/site-to-site, CNI, ISP/telco, geolocated egress | `references/network-services.md` |
| Limits, pricing, plan tiers, residency support, renamed products | `references/volatile-facts.md` (always) |
| Need the source document / a pattern not listed above | `references/catalog.md` (fetch the page's `index.md`) |

## Core decision rules (most-used; details in references)

| Need | Prefer | Over / because |
|---|---|---|
| Read-heavy config, tenant/hostname → metadata lookup | KV | D1/DO — fast global reads; accept eventual consistency |
| Strong consistency, coordination, realtime, per-entity state | Durable Objects (shard per entity; control/data-plane split) | KV — eventual; one DO for everything = bottleneck |
| Relational data (new) / existing Postgres-MySQL that can't move | D1 / Hyperdrive | Direct TCP from Workers without pooling |
| Large file upload | Presigned URL → R2 direct (S3 endpoint + CORS; validate at issuance — bypasses WAF) | Proxying bytes through a Worker |
| Post-upload / async / bursty work | R2 event notifications (or explicit "complete" call) → Queues → Workflow or per-job DO | Synchronous processing in the request |
| Heavy/custom runtime jobs (AV scan, PDF, media); untrusted code | Containers (driven by Queue/DO/Workflow); Sandbox SDK (Workers for Platforms for tenant code) | Stretching Worker limits; WAF upload scanning as "antivirus" |
| Any production LLM call, multi-provider, spend control | AI Gateway (fallback, logs, cost; Dynamic Routing / Spend Limits — verify) | Calling providers directly. Exception: no cache/rate limit on the gateway used by AI Search indexing |
| RAG with group ACLs | AI Search / Vectorize with an instance or namespace per group + D1 ACL re-check | Array metadata filters (limited) or letting the model enforce access |
| SSH / RDP / DB access for staff | Access for Infrastructure (short-lived certs, command logs) / private IP via client | Long-lived keys; VPN |
| Tenant custom domains | Cloudflare for SaaS custom hostnames (+ apex proxying for apex) | One zone per tenant / multi-SAN certs |
| Origin must not be reachable directly | Cloudflare Tunnel (≥2 replicas) | IP allowlist alone; DNS-only records |
| Traffic spikes / flash sales / scalper bots | Cache + Waiting Room (sized to tested origin capacity) + Bot Management + Turnstile pre-clearance + session/account rate limits | Autoscaling the origin alone; IP-only rate limits |
| Many zones sharing a WAF baseline | Account-level WAF + hostname lists, Log mode first | Per-zone copies |
| Users → private web apps | `cloudflared` + Access self-hosted apps | Magic/Cloudflare WAN or legacy VPN |
| Server-initiated / bidirectional private traffic (VoIP, AD, CI) | Cloudflare Mesh (ex-WARP Connector) | `cloudflared` (inbound-only) |
| Contractors / BYOD, no agent | Public hostname + Access + Isolate; if internal names must stay out of public DNS → clientless RBI + private DNS resolver policies | Forcing the client; network-level access |
| Protect whole IP prefixes / non-HTTP at L3 | Magic Transit (Egress if stateful FW/NAT) | Proxied CDN (HTTP only) |
| Data residency | Data-class table checked product-by-product against `/data-localization/compatibility/`: Regional Services, CMB (account-wide), R2/DO jurisdictions; IDs only through non-regional services; no placement hints on regional paths | "Turn on DLS and it's solved" — KV, D1, Queues, Workflows etc. may not be covered |

## Common mistakes
- Designing before asking about residency, "can the DB move", device management, or plan tier — these flip the architecture.
- Stating limits/prices/GA status from memory. Verify (step 5) or mark unverified.
- Not flagging Enterprise-only / add-on features (DLS, apex proxying, WAF for SaaS custom rulesets, Bot Management, AI Security for Apps, Browser Isolation…) — the plan column decides feasibility and cost.
- Forgetting the origin is still reachable (no Tunnel/allowlist/AOP) — WAF becomes optional for attackers.
- Omitting cost estimate, backups/RPO-RTO, observability, and a break-glass path — reviewers always ask.
- Chaining two CDN/WAF vendors in series "for defense in depth" — run vendors in parallel instead.
- Using Access **Bypass** for machine clients — use service tokens or mTLS.
- Enforcing document ACLs inside the LLM prompt — filter at retrieval (instance/namespace per group + ACL re-check).
- Enabling new WAF/DLP rules straight in Block mode — start in Log/monitor, tune, then enforce.
- Using old names inconsistently. Current: Cloudflare One Client (WARP), Cloudflare Mesh (WARP Connector), Cloudflare WAN (Magic WAN), Cloudflare Network Firewall (Magic Firewall), AI Search (AutoRAG), Browser Run (Browser Rendering), AI Security for Apps (Firewall for AI). Mention the old name once in parentheses.

## Keeping the skill current
Distilled from https://developers.cloudflare.com/reference-architecture/ on 2026-09-29. Run `bash scripts/check_new_docs.sh` to list pages added or removed since then; read new pages via their `index.md` and fold them into the matching reference file and `catalog.md`.
