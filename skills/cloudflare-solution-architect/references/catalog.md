# Cloudflare Reference Architecture Catalog

All documents under https://developers.cloudflare.com/reference-architecture/ (synced 2026-09-29), grouped by solution area. Every page has a Markdown version: append `index.md` to the URL.

## Navigation
- [Design Guides list](https://developers.cloudflare.com/reference-architecture/design-guides/) — prescriptive guides (SaaS, Zero Trust, VPN migration, secure app delivery, guest Wi-Fi, WAF rollout).
- [Find by solution](https://developers.cloudflare.com/reference-architecture/by-solution/) — map a solution area to relevant docs.
- [How to use](https://developers.cloudflare.com/reference-architecture/how-to-use/) — explains the four doc types and when to read each.
- [Implementation Guides list](https://developers.cloudflare.com/reference-architecture/implementation-guides/) — step-by-step Learning Paths (Zero Trust, mTLS).
- [Reference Architecture Diagrams list](https://developers.cloudflare.com/reference-architecture/diagrams/) — browse diagrams by category.
- [Reference Architectures (home)](https://developers.cloudflare.com/reference-architecture/) — top-level entry to all architecture content.
- [Reference Architectures list](https://developers.cloudflare.com/reference-architecture/architectures/) — list of the 11 broad RAs (Security, CDN, SASE, LB, MT, Multi-vendor, CrowdStrike, SentinelOne, Microsoft, AI Security for Apps, Email Security).

## Developer Platform — AI
- [AI Vibe Coding Platform](https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-vibe-coding-platform/) — generate, sandbox, host AI-built apps.
- [Automatic captioning for video uploads](https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-video-caption/) — ASR subtitles in R2.
- [Composable AI architecture](https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-composable/) — mixing Cloudflare and external AI layers.
- [Content-based asset creation](https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-asset-creation/) — chained text → safety → image.
- [Enterprise AI Vibe Coding Platform](https://developers.cloudflare.com/reference-architecture/diagrams/ai/enterprise-ai-vibe-coding-platform/) — dev/deploy/prod planes with enterprise controls.
- [Enterprise AI agent workspace](https://developers.cloudflare.com/reference-architecture/diagrams/ai/enterprise-ai-agent-workspace/) — governed stateful agents on DOs.
- [Ingesting BigQuery Data into Workers AI](https://developers.cloudflare.com/reference-architecture/diagrams/ai/bigquery-workers-ai/) — interactive vs cron enrichment.
- [Multi-vendor AI observability and control](https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-multivendor-observability-control/) — AI Gateway as forward proxy.
- [Retrieval Augmented Generation (RAG)](https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-rag/) — DIY RAG; AI Search pointer.

## Developer Platform — Serverless
- [A/B-testing using Workers](https://developers.cloudflare.com/reference-architecture/diagrams/serverless/a-b-testing-using-workers/) — server-side experiments with KV config.
- [Fullstack applications](https://developers.cloudflare.com/reference-architecture/diagrams/serverless/fullstack-application/) — layer map of the whole platform.
- [Programmable Platforms](https://developers.cloudflare.com/reference-architecture/diagrams/serverless/programmable-platforms/) — multi-tenant customer code on WfP.
- [Serverless ETL pipelines](https://developers.cloudflare.com/reference-architecture/diagrams/serverless/serverless-etl/) — HTTP/R2 ingest via Queues to R2.
- [Serverless global APIs](https://developers.cloudflare.com/reference-architecture/diagrams/serverless/serverless-global-apis/) — router Worker + KV/D1/Hyperdrive.
- [Serverless image content management](https://developers.cloudflare.com/reference-architecture/diagrams/serverless/serverless-image-content-management/) — signed images with AI moderation.

## Developer Platform — Storage
- [Control and data plane pattern for Durable Objects](https://developers.cloudflare.com/reference-architecture/diagrams/storage/durable-object-control-data-plane-pattern/) — scaling DOs by sharding.
- [Egress-free object storage in multi-cloud setups](https://developers.cloudflare.com/reference-architecture/diagrams/storage/egress-free-storage-multi-cloud/) — R2 as shared multi-cloud store.
- [Event notifications for storage](https://developers.cloudflare.com/reference-architecture/diagrams/storage/event-notifications-for-storage/) — push vs pull on R2 changes.
- [On-demand Object Storage Data Migration](https://developers.cloudflare.com/reference-architecture/diagrams/storage/on-demand-object-storage-migration/) — Sippy + Super Slurper.
- [Storing user generated content](https://developers.cloudflare.com/reference-architecture/diagrams/storage/storing-user-generated-content/) — presigned uploads, AI output to R2.

## Content delivery & IoT
- [Designing a distributed web performance architecture](https://developers.cloudflare.com/reference-architecture/diagrams/content-delivery/distributed-web-performance-architecture/): read when the goal is Core Web Vitals, TTFB or CHR improvement. Layer-by-layer optimization checklist and measurement tooling.
- [Optimizing image delivery with image resizing and R2](https://developers.cloudflare.com/reference-architecture/diagrams/content-delivery/optimizing-image-delivery-with-cloudflare-image-resizing-and-r2/) — URL transforms over R2 originals.
- [Optimizing and securing connected transportation systems](https://developers.cloudflare.com/reference-architecture/diagrams/iot/optimizing-and-securing-connected-transportation-systems/) — IoT fleets with mTLS and edge compute.

## Application Performance & SaaS providers
- [Content Delivery Network (CDN) Reference Architecture](https://developers.cloudflare.com/reference-architecture/architectures/cdn/): read when designing caching layers: anycast vs DNS CDNs, Tiered Cache topologies, Regional Tier, Cache Reserve, Argo, China delivery.
- [Load Balancing Reference Architecture](https://developers.cloudflare.com/reference-architecture/architectures/load-balancing/): read for any multi-origin, failover or geo-steering design: steering methods, weights, monitors, L7/DNS-only/Spectrum models, affinity, Tunnel/private endpoints.
- [Multi-vendor Application Security and Performance Reference Architecture](https://developers.cloudflare.com/reference-architecture/architectures/multi-vendor/): read when a customer requires multi-CDN or multi-DNS: onboarding modes, active-active designs, DNS sync options, anti-stacking guidance, origin connectivity.
- [Leveraging Cloudflare for your SaaS applications](https://developers.cloudflare.com/reference-architecture/design-guides/leveraging-cloudflare-for-your-saas-applications/): read when building a multi-tenant SaaS: custom hostnames/DCV, per-tenant metadata, Workers for Platforms tiers.
- [Extending Cloudflare's benefits to SaaS providers' end customers](https://developers.cloudflare.com/reference-architecture/design-guides/extending-cloudflares-benefits-to-saas-providers-end-customers/): read for concrete SaaS DNS/origin topologies: fallback origin, Regional Services, Tunnel, LB as custom origin, apex proxying, O2O.

## Application & Data Security
- [Cloudflare Security Architecture](https://developers.cloudflare.com/reference-architecture/architectures/security/) — threat-to-product map, public vs private resources, Workers as security. Read first.
- [AI Security for Apps Reference Architecture](https://developers.cloudflare.com/reference-architecture/architectures/ai-security-for-apps/) — protecting LLM apps: discovery, PII, unsafe topics, and prompt injection detections, plus WAF-based mitigation.
- [Securely deliver applications with Cloudflare](https://developers.cloudflare.com/reference-architecture/design-guides/secure-application-delivery/) — origin connectivity options and a worked Tunnel + Access + WAF onboarding.
- [Streamlined WAF deployment across zones and applications](https://developers.cloudflare.com/reference-architecture/design-guides/streamlined-waf-deployment-across-zones-and-applications/) — account-level WAF, multiple ruleset instances, Lists, exceptions, and Log-first rollout for many zones.
- [Bot management](https://developers.cloudflare.com/reference-architecture/diagrams/bots/bot-management/) — detection engines, bot score semantics, plan tiers, and the bot traffic and analytics flow.
- [Bots (diagrams index)](https://developers.cloudflare.com/reference-architecture/diagrams/bots/) — index only.
- [FIPS 140 level 3 compliance with Cloudflare Application Services](https://developers.cloudflare.com/reference-architecture/diagrams/security/fips-140-3/) — Keyless SSL plus Tunnel plus HSM when keys must stay in a FIPS L3 HSM.
- [Securing data at rest](https://developers.cloudflare.com/reference-architecture/diagrams/security/securing-data-at-rest/) — CASB with DLP for SaaS oversharing and misconfiguration, and IP-locking SaaS through egress IPs.
- [Securing data in transit](https://developers.cloudflare.com/reference-architecture/diagrams/security/securing-data-in-transit/) — TLS to edge and origin, tunnels, and the Gateway DLP inspection and block flow.
- [Securing data in use](https://developers.cloudflare.com/reference-architecture/diagrams/security/securing-data-in-use/) — RBI/NVR controls (copy/paste, print, upload) for GenAI tools, SaaS, and contractors.
- [Security (diagrams index)](https://developers.cloudflare.com/reference-architecture/diagrams/security/) — index for the FIPS and data at rest, in transit, and in use diagrams.
- [Application Security (implementation guides)](https://developers.cloudflare.com/reference-architecture/implementation-guides/application-security/) — index. Currently points to the mTLS implementation guide.

## SASE / Zero Trust
- [Evolving to a SASE architecture with Cloudflare](https://developers.cloudflare.com/reference-architecture/architectures/sase/) — Read first for any Cloudflare One design. It covers on-ramp selection tables, the capability matrix by forwarding method, identity and posture, email, and unified policy examples.
- [CrowdStrike and Cloudflare: a unified security ecosystem](https://developers.cloudflare.com/reference-architecture/architectures/cloudflare-sase-with-crowdstrike/): read for ZTA-gated access, Next-Gen SIEM log flows, and Fusion SOAR automated remediation.
- [Enhancing security posture with SentinelOne and Cloudflare One](https://developers.cloudflare.com/reference-architecture/architectures/cloudflare-sase-with-sentinelone/): read for SentinelOne posture-check setup and policy design.
- [Reference Architecture using Cloudflare SASE with Microsoft](https://developers.cloudflare.com/reference-architecture/architectures/cloudflare-sase-with-microsoft/): read for Entra ID, Intune, M365 CASB, SWG, and email integration in Microsoft estates.
- [Understanding Email Security Deployments](https://developers.cloudflare.com/reference-architecture/architectures/email-security-deployments/): read when choosing between MX/Inline, API, BCC/Journaling, and Mixed email deployments.
- [Designing ZTNA access policies for Cloudflare Access](https://developers.cloudflare.com/reference-architecture/design-guides/designing-ztna-access-policies/) — Read when writing Access policies: app types, actions, Include/Require/Exclude, selectors, and blueprints for wiki, Salesforce, DB and RDP.
- [Building zero trust architecture into your startup](https://developers.cloudflare.com/reference-architecture/design-guides/zero-trust-for-startups/) — Read for greenfield or small-team designs: asset inventory, identity and posture foundations, mesh vs traditional networking, JWT/SSO for internal tools, third-party access, and IaC.
- [Using a zero trust framework to secure SaaS applications](https://developers.cloudflare.com/reference-architecture/design-guides/zero-trust-for-saas/) — Read for SaaS access (egress IPs vs identity proxy), DLP in transit and at rest, CASB, tenant control, email inline vs API, and shadow IT.
- [Network-focused migration from VPN concentrators to ZTNA](https://developers.cloudflare.com/reference-architecture/design-guides/network-vpn-migration/) — Read when replacing VPN hardware quickly with Cloudflare WAN IPsec, then moving in phases to `cloudflared` and per-app segmentation.
- [Securing guest wireless networks](https://developers.cloudflare.com/reference-architecture/design-guides/securing-guest-wireless-networks/): read when protecting guest or public Wi-Fi with agentless DNS filtering and optional tunnel-based enforcement.
- [Access to private apps without having to deploy client agents](https://developers.cloudflare.com/reference-architecture/diagrams/sase/sase-clientless-access-private-dns/): read when third parties need agentless access to internal web apps by private hostname.
- [Cloudflare One Appliance deployment options](https://developers.cloudflare.com/reference-architecture/diagrams/sase/cloudflare-one-appliance-deployment/): read when planning branch on-ramp placement, HA, LIBO, PBR split, or local segmentation.
- [DNS filtering solution for Internet service providers](https://developers.cloudflare.com/reference-architecture/diagrams/sase/gateway-dns-for-isp/): read when an ISP or telco wants to resell DNS security or parental and enterprise filtering tiers.
- [Deploy self-hosted VoIP services for hybrid users](https://developers.cloudflare.com/reference-architecture/diagrams/sase/deploying-self-hosted-voip-services-for-hybrid-users/): read when private apps need bidirectional or server-initiated traffic (SIP/RTP) over Mesh.
- [Extend ZTNA with external authorization and serverless computing](https://developers.cloudflare.com/reference-architecture/diagrams/sase/augment-access-with-serverless/): read when access needs custom AuthZ logic (Workers or OPA) or JWT validation at the origin.
- [Protective DNS for governments](https://developers.cloudflare.com/reference-architecture/diagrams/sase/gateway-for-protective-dns/): read when designing protective DNS with threat feeds, remote-user DoH or client, and a path to a full SWG.
- [Secure Access Service Edge (SASE) diagrams index](https://developers.cloudflare.com/reference-architecture/diagrams/sase/): read to find the list of SASE scenario diagrams.
- [Secure access to SaaS applications with SASE](https://developers.cloudflare.com/reference-architecture/diagrams/sase/secure-access-to-saas-applications-with-sase/): read when gating SaaS with posture, dedicated egress IPs, DLP, and approval workflows.
- [Zero Trust and Virtual Desktop Infrastructure](https://developers.cloudflare.com/reference-architecture/diagrams/sase/zero-trust-and-virtual-desktop-infrastructure/): read when replacing VDI with RBI or securing access to and egress from the VDI that remains.
- [Zero Trust implementation guides](https://developers.cloudflare.com/reference-architecture/implementation-guides/zero-trust/) — Read for step-by-step learning paths (SWG/SaaS, VPN replacement, clientless web access, email security) after the architecture is chosen.

## Network Services
- [Magic Transit Reference Architecture](https://developers.cloudflare.com/reference-architecture/architectures/magic-transit/) — read for MT fundamentals: anycast tunnels, DSR vs Egress, CNI, multi-cloud, MT + WAN, Network Firewall, always-on vs on-demand.
- [Bring your own IP space to Cloudflare](https://developers.cloudflare.com/reference-architecture/diagrams/network/bring-your-own-ip-space-to-cloudflare/) — when IP ownership/attestation matters for proxy or MT.
- [Network (diagrams index)](https://developers.cloudflare.com/reference-architecture/diagrams/network/) — entry point listing all network diagrams.
- [Optimizing device roaming experience with geolocated IPs](https://developers.cloudflare.com/reference-architecture/diagrams/network/optimizing-roaming-experience-with-geolocated-ips/) — IoT/APN roaming, country-correct egress, device lockdown.
- [Protect ISP and telecommunications networks from DDoS attacks](https://developers.cloudflare.com/reference-architecture/diagrams/network/protecting-sp-networks-from-ddos/) — on-demand MT with Network Flow for service providers.
- [Protect data center networks](https://developers.cloudflare.com/reference-architecture/diagrams/network/protect-data-center-networks/) — on-prem DCs: MT + WAN + Network Firewall + Gateway over separate CNIs, four traffic flows.
- [Protect hybrid cloud networks with Cloudflare Magic Transit](https://developers.cloudflare.com/reference-architecture/diagrams/network/protect-hybrid-cloud-networks-with-cloudflare-magic-transit/) — BYOIP vs leased IP vs mixed across clouds and on-prem.
- [Protect public networks with Cloudflare](https://developers.cloudflare.com/reference-architecture/diagrams/network/protect-public-networks-with-cloudflare/) — symmetric inbound + outbound protection for public networks.
