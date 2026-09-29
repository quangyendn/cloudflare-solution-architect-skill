# Application Performance, Delivery & SaaS-Provider Patterns (Cloudflare Reference Architecture digest)

## Contents
- Building blocks
- Patterns
  - 1. Cloudflare CDN with tiered caching
  - 2. Distributed L7 web performance architecture
  - 3. Load Balancing: GTM + private network LB in one configuration
  - 4. Leveraging Cloudflare for your SaaS applications (Cloudflare for Platforms)
  - 5. Extending Cloudflare's benefits to SaaS providers' end customers
  - 6. Multi-vendor application security & performance (multi-CDN / multi-DNS)
- Cross-cutting principles
- Decision hints

## Building blocks

| Product / feature | Role | Choose it when | Key constraints / gotchas |
|---|---|---|---|
| Anycast reverse proxy ("orange cloud", proxied DNS record) | Every request lands at the nearest Cloudflare DC; all services (CDN, WAF, DDoS, LB) run on every server | Default for any HTTP(S) app you want to accelerate or protect | Only proxied traffic gets L7 services. Anycast beats DNS-unicast CDNs: routing uses the client IP (not the resolver), no TTL dependency, failover through BGP, and attack load is spread across many DCs |
| Standard caching | Each DC acts as a direct reverse proxy to origin | Always on once a site is onboarded | A miss in any DC goes straight to origin, so origin load stays high. Enable Tiered Cache |
| Tiered Cache: Smart topology (all plans) | Lower tiers fetch from one upper tier chosen with Argo latency data | Most deployments. Aim: minimize origin requests and bandwidth | Tiered Cache is off by default; once turned on, Smart is the default topology. A single upper tier can sit far from some lower tiers, which adds latency |
| Tiered Cache: Generic Global (Ent) | All Tier-1 DCs act as upper tiers | High, globally spread traffic that needs top cache usage and performance | Upper tiers sit closer to users, but each one fills from origin, so origin load goes up |
| Tiered Cache: Custom (Ent) | Upper tiers chosen by you, built with the account team | You know where your users are and want upper tiers in specific regions | Needs the account team |
| Regional Tiered Cache | Adds a regional hub layer between lower and upper tiers | Globally used apps on Smart or Custom topology | Brings no benefit with Generic Global, which already has many upper tiers |
| Cache Reserve | Persistent top cache tier backed by R2. Reduces origin egress and LRU eviction | Large, rarely requested but long-lived assets: images, archived video, software updates, AI models | Keeps objects 30 days from last read, whatever the TTL. TTL still controls freshness (expired objects are revalidated). Eligible only if cacheable, TTL ≥ 10h and a `Content-Length` header is present (chunked transfer blocks it). Tiered Cache is recommended alongside it (dashboard warns without it). Resized images are not stored in it |
| Argo Smart Routing | Fastest measured path across Cloudflare to origin. Also picks the upper tier for Smart Tiered Cache | Cache misses and dynamic/uncacheable traffic (APIs) where TTFB matters | Paid add-on. Without it, routing to origin is reliable but not always the fastest. Docs cite about 30% faster web assets on average. Also used by Spectrum and LB paths |
| China Network / Global Acceleration | In-China caching through JD Cloud DCs / faster origin-to-China path for dynamic content | Material user base in mainland China | Separate offerings |
| Cache Rules, Cache Key, Origin Cache-Control, Prefetch URLs | Control TTLs, query-string handling and cache key normalization | Raising CHR, for example by merging marketing/SEO query-param variants into one key | Check the default caching behavior and limits |
| Instant Purge | Global purge in about 150 ms by URL, tag, prefix or hostname | Content that must refresh immediately | — |
| Edge optimization: HTTP/3, TLS 1.3, 0-RTT, HSTS, Early Hints, Speed Brain, Compression Rules, Polish / Image Transformations, Cloudflare Fonts, Zaraz, Google Tag Gateway | Speed up connection setup and rendering (LCP/INP/CLS) | Front-end CWV work | Zaraz moves third-party tags off the browser main thread (INP). Fonts removes extra DNS/TLS round trips to Google Fonts |
| Rules / Snippets / Workers (+ Service Bindings) | Redirects, transforms, URL normalization, custom cache logic at the edge | When standard rules cannot express the logic | — |
| Waiting Room | Queues users during traffic surges | Launches, sales, spikes | — |
| Workers + R2 / D1 / Static Assets ("originless") | Runs the app fully at the edge | Best TTFB. Large-file distribution without a backend | Requires refactoring the app |
| Origin connectivity: HTTP/2 to origin + connection reuse, CNI, Cloudflare Tunnel, Workers VPC, Cloud Connector, Bandwidth Alliance | Faster and more secure origin fetches, private origins, lower egress fees | Traditional origins that cannot become originless | CNI connects via PNI, IX or partner. Tunnel is outbound-only with no inbound ports |
| Dedicated CDN Egress IPs (Smart Shield Advanced) / BYOIP | Customer-specific egress or announced prefixes | Origin allowlisting | Pair with Full (Strict) TLS or mTLS |
| Authenticated Origin Pulls (mTLS) | Proves a request came through Cloudflare | Any public origin, especially one behind WAF | For FIPS, upload your own cert. Works per zone or per hostname. LB health monitors need Simulate Zone |
| Load Balancing: monitors → endpoint pools → load balancer | GTM plus private network LB in one SaaS configuration | Multi-origin, multi-region, failover | Endpoints must be reachable on 80/443, or be mapped there with a proxy or Tunnel. Health monitors are account-level objects |
| LB deployment model: L7 HTTP(S) proxied | Public, proxied, full L7 stack. Supports WebSockets | Web apps and APIs | HTTP(S)/WS only. LB is the last step in the L7 pipeline, and nothing else runs after it picks an endpoint |
| LB deployment model: DNS-only | Returns endpoint IP(s) in a DNS answer | Any non-HTTP IP traffic that must not be proxied | Exposes endpoint IPs. No cache/WAF/DDoS (beyond DNS DDoS)/Zero Trust. Public endpoints only. Fixed 30s TTL. Affinity only `ip_cookie`. LORS falls back to random |
| LB deployment model: Spectrum (L4) | Proxied TCP/UDP LB | SSH, FTP, SMTP, games, any TCP/UDP | Always proxied. Ingress port equals endpoint port. Affinity only through hash steering. No LB Custom Rules. Access control only via IP Access Rules (allow/block by IP, CIDR, country, ASN) |
| Private Network LB (Tunnel + virtual network) | Balances across private IPs reached over cloudflared | Endpoints with no public IP | Needs a virtual network whose route covers the IP. Host-header override ignored for private IP and Spectrum |
| Cloudflare Tunnel (cloudflared) | Outbound-only connector: 4 connections to 2+ DCs per instance. Replicas add more ingress | Hiding origins, no firewall holes | Replicas do no traffic steering (use LB for that). As an LB endpoint, you must use `<UUID>.cfargotunnel.com`, not a CNAME. Non-80/443 services need a catch-all ingress rule. Traffic must pass through the DC where the tunnel ends |
| Cloudflare for SaaS (SSL for SaaS) / Custom Hostnames | Handles certificates and DCV for tenant domains inside one zone, and applies L7 features to them | SaaS where tenants bring their own domain (`shop.customer.com`) | Tenant sets a CNAME to your fallback origin. DCV is automated by Cloudflare answering the token. Phase the migration and watch DCV status |
| Fallback origin / Custom origin | Default origin for custom hostnames / per-hostname override (for example an LB) | Custom origin to steer some tenants elsewhere | Custom origin has specific SNI rules (see docs) |
| Custom Metadata (+ WAF for SaaS) | Per-hostname JSON tags (`WAF: On`, `Performance: Premium`) read by WAF, rules and Workers | Tiered feature plans per tenant | — |
| Apex proxying (Static IPs) | A-record target for tenants whose DNS cannot CNAME the apex | Tenant wants the root domain on your SaaS | Paid static IPs. Same mechanism for partial zones on DNS providers without CNAME flattening |
| O2O (Orange-to-Orange) | Tenant's own Cloudflare zone proxies in front of your SaaS zone | Tenant is already on Cloudflare and insists on proxying | Generally advise tenants not to proxy the SaaS hostname. Check product compatibility |
| Workers for Platforms (Dispatch Worker, User Workers, Outbound Workers) | Runs per-tenant code, routed by a dispatcher, with egress controlled | Tenants write or generate their own code, or need deep per-tenant logic | Works with D1, KV, Queues |
| Regional Services (Data Localization Suite) | Limits TLS termination and L7 processing to a region | Data residency compliance | Applied through a regionalized hostname or LB in the CNAME chain |
| DNS: full, secondary (+ Secondary DNS override), partial/CNAME, hidden primary | Ways to put traffic on Cloudflare | See Decision hints | Partial setup on an apex needs Static IPs if the external DNS cannot flatten CNAMEs |

## Patterns

### 1. Cloudflare CDN with tiered caching
**Problem.** A central or few-region origin gives distant users high RTT (latency grows with distance; China is especially slow). Origin load, egress cost and DDoS exposure all rise with traffic, and an origin outage takes everything down.

**Components & traffic flow.** Client → nearest anycast DC (lower tier) → on MISS, upper-tier DC (Smart: one upper tier, closest to origin per Argo data) → on MISS, origin. The upper tier caches and returns the object, and the lower tier caches it too. A later request at a different DC is served by the upper tier without an origin trip. Optional layers: Regional Tiered Cache (a hub between lower and upper tiers), Cache Reserve (R2-backed tier above the upper tier), and Argo Smart Routing on the upper-tier→origin leg for misses and dynamic content.

**Key design decisions & trade-offs.**
- Smart topology: highest hit ratio and least origin load, but some lower tiers pay extra latency to reach a distant upper tier. Adding Regional Tiered Cache reduces that cost.
- Generic Global: lowest lower→upper latency, more origin fills. Regional adds nothing here.
- Custom: tailor upper tiers to where users are (Enterprise, via account team).
- Cache Reserve: 30-day retention from last read cuts egress and avoids LRU eviction. Only objects with Content-Length and TTL ≥ 10h qualify. Put Tiered Cache in front to avoid redundant reads and storage.
- Argo applies only to misses and uncacheable requests.

**When to use / not use.** Any publicly served web content. Smart Tiered Cache is the baseline recommendation. Skip Cache Reserve for short-TTL or chunked/streamed responses. For China, add China Network (cache) and Global Acceleration (dynamic).

**Source:** https://developers.cloudflare.com/reference-architecture/architectures/cdn/

### 2. Distributed L7 web performance architecture
**Problem.** Improve Core Web Vitals, cache hit ratio and uptime while keeping the cost of security controls (WAF, bots, DDoS) in check. In high-risk cases, latency saved elsewhere is spent on security.

**Targets.** p75: LCP < 2.5s, INP < 200ms, CLS < 0.1, TTFB < 800ms. Watch server-side latency (TTFB) at p99 or higher, because a session makes dozens of requests and almost every user hits the tail.

**Components & traffic flow (four layers).**
1. *Client*: anycast DNS; HTTP/3 + TLS 1.3 (PQC-capable), 0-RTT resumption, HSTS/Always HTTPS; Speed Brain (speculation prefetch), Early Hints; Zaraz to offload third-party tags (INP); Web Analytics RUM.
2. *Edge network & optimization*: URL normalization, Redirect/Transform Rules, Waiting Room; Snippets/Workers for custom logic (Service Bindings between Workers); Compression Rules (Brotli/Gzip), Polish/Image Transformations (AVIF/WebP) for LCP/CLS; Cloudflare Fonts, Google Tag Gateway; per-connection congestion-control tuning; Argo for uncacheable requests; Custom Errors.
3. *Cache & storage*: Cache Rules/Cache Key normalization, Prefetch URLs, Smart + Regional (or Custom) Tiered Cache, Cache Reserve, Instant Purge (~150ms; by URL/tag/prefix/hostname), Cloud Connector (route to S3/Azure/GCS), Workers VPC, static assets in R2 / Workers Static Assets.
4. *Origin*: either (a) **originless**: full-stack on Workers + R2/D1, the optimal tier for TTFB and large-file distribution, or (b) **traditional origin**: HTTP/2 to origin with connection reuse, CNI, Bandwidth Alliance egress savings, Tunnel/Workers VPC for private origins, Cloudflare Load Balancing (or round-robin DNS for simple cases).

**Key design decisions & trade-offs.** Serve as much as possible from cache or the edge. Normalize cache keys. Move rarely requested large objects into Cache Reserve. Refactor to originless where you can, otherwise optimize origin connectivity. Measure with Observatory (synthetic + RUM), Cache Analytics, GraphQL timing (`originResponseDurationMs` vs `edgeDnsResponseTimeMs`), Logpush, NEL, plus external tools.

**When to use.** Performance-sensitive sites: e-commerce conversion, SEO, large downloads (software, AI models, video). Establish security and compliance baselines (residency, PQC) before tuning for speed.

**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/content-delivery/distributed-web-performance-architecture/

### 3. Load Balancing: GTM + private network LB in one configuration
**Problem.** Handle spikes, keep the app available through failures and maintenance, cut RTT for global users, scale across regions, and resist DDoS. The traditional approach needs a DNS GSLB in front of per-DC hardware SLBs.

**Components & traffic flow.** Entrypoint (a DNS hostname, i.e. the "VIP") → **traffic steering** picks an endpoint pool (GTM role) → **endpoint steering** picks an endpoint (SLB role) → request goes straight to the endpoint (public IP, proxied or unproxied hostname, external hostname, or private IP via Tunnel + virtual network). Health monitors (HTTP/HTTPS/TCP/UDP-ICMP/ICMP/SMTP/LDAP) probe from selected regions. Pool state is healthy, degraded (still at or above the health threshold) or critical (removed from steering). A fallback pool serves as last resort and ignores health. Cloudflare merges GTM and SLB, so you do not chain a GSLB to local LBs.

**Key design decisions & trade-offs.**
- **Deployment model**: L7 proxied (HTTP/WS, full security stack, all affinity modes, Custom Rules), DNS-only (any IP protocol, endpoint IPs exposed, 30s TTL, weaker features), or Spectrum L4 (any TCP/UDP, proxied, no port remap, hash-only affinity).
- **Steering (traffic level)**: Off-Failover (priority order, active/passive), Random (weighted split, active/active), Geo (pin countries/regions to pools; residency), Dynamic (lowest RTT from health-probe data; ignores geography; ~10 min warm-up; falls back to failover order when there is no data), Proximity (GPS coordinates per pool; locates client by ECS → resolver geo → DC location), LORS (fewest open requests × weight; L7 proxied only, otherwise acts as random).
- **Steering (endpoint level)**: Random, Hash (source IP → same endpoint; changes if the endpoint list changes), LORS. Hash and LORS endpoint steering need Enterprise. Enterprise traffic-steering methods can also be bought as a self-service add-on.
- **Weights** (0–1, normalized by sum) express capacity. They are probabilistic, so short-window skew is expected, and session affinity overrides them after the first request.
- **Session affinity** (L7 only): `cookie`, `ip_cookie`, `header`. TTL is 30 min–7 days (default 23h). Cookie timers never reset; header timers reset on activity. Endpoint draining (needs affinity) supports graceful maintenance.
- **Resilience extras**: zero-downtime failover retries once on 521/522/523/525/526 if another healthy endpoint exists (modes Off/Temporary/Sticky; Sticky not available with header affinity). Adaptive routing extends failover across pools. Load shedding moves new traffic, then optionally affinity traffic, off a pool that is degrading.
- **Health-check fidelity**: probes skip the L7 stack by default and can report healthy while real traffic fails. Enable **Simulate Zone** when using AOP, Origin CA, Argo or Dedicated Egress IPs.
- **Host header override** per endpoint when the origin (for example a SaaS/cloud app) only answers its own hostname. L7 only.
- **Custom Rules**: override steering by request fields, for example send POSTs to a write pool or extend affinity TTL on a checkout path.
- **Tunnel endpoints** force traffic through the DC where the tunnel terminates, which changes the path.

**Sub-patterns.**
- *Active-passive*: Off-Failover across ordered pools plus a fallback pool.
- *Active-active*: Random with weights, or LORS for backends that slow down under concurrent load.
- *Latency-optimized global*: Dynamic (measured RTT) or Proximity (geographic distance).
- *Regulatory/geo pinning*: Geo steering.
- *Private-only backends*: pools of private IPs on a virtual network via cloudflared (Private Network LB). Zero Trust policies can be applied to L7 LBs.

**When to use / not use.** L7 for web and APIs; Spectrum for non-HTTP TCP/UDP that should be proxied; DNS-only only when traffic cannot or must not be proxied (you lose origin hiding and L7 protection).

**Source:** https://developers.cloudflare.com/reference-architecture/architectures/load-balancing/

### 4. Leveraging Cloudflare for your SaaS applications (Cloudflare for Platforms)
**Problem.** Tenants want the SaaS served on their own domain (`shop.example.com`, even `www.example.com`). Multi-domain certificates and one zone per tenant break down at thousands to millions of tenants. DCV and renewals normally need the domain owner every time.

**Components & traffic flow.** One Cloudflare for SaaS zone. Each tenant hostname is added as a Custom Hostname and CNAMEs to the provider. Cloudflare answers DCV tokens itself, so the tenant does a one-time setup and renewals run automatically. Traffic then passes through the shared L7 config (DDoS, WAF, Bot Mgmt, Rate Limiting, Cache, Argo, Early Hints) to the origin.

**Three maturity tiers.**
1. *SSL issuance at scale*: same L7 config for all tenants. Defaults cover most needs. For stronger origin security use Authenticated Origin Pulls, Dedicated CDN Egress IPs or Tunnel.
2. *Per-tenant feature customization*: Custom Metadata tags per hostname drive WAF for SaaS (different managed rulesets or custom rulesets per tier) and performance add-ons (Argo, cache, Early Hints) for premium tenants.
3. *Serverless platform*: Workers for Platforms. A Dispatch Worker routes each request (for example after security checks or by a user-ID header) to that tenant's User Worker. Outbound Workers restrict what tenant code can reach. D1/KV/Queues complete the backend.

**Trade-offs.** Rules and metadata are enough for configuration-level variation. Choose Workers for Platforms only when tenants need their own code.

**Source:** https://developers.cloudflare.com/reference-architecture/design-guides/leveraging-cloudflare-for-your-saas-applications/

### 5. Extending Cloudflare's benefits to SaaS providers' end customers
**Problem.** Protect and accelerate tenant traffic on vanity (`cust.myapp.com`) and custom (`app.cust.com`) domains with minimal downtime, automatic certificate renewal, healthy-endpoint steering and regional processing. Assumes the provider zone uses Cloudflare as authoritative DNS. Create vanity subdomains through the API when a tenant signs up.

**Variants (simplest → most complex).**
- **5a. Standard fallback origin**: `custom.example.com` CNAME → `fallback.myapp.com` (A → origin public IP). The tenant's DNS can live anywhere. The origin identifies the tenant from Host/SNI. Enables WAF, Access policies, caching, Early Hints, Image Transformations, Waiting Room and Workers for Platforms on every request. The most common and easiest option.
- **5b. + Regional Services**: custom hostname CNAME → regionalized hostname (`eu-customers.myapp.com`) → CNAME fallback → origin. TLS termination and L7 processing stay inside the region.
- **5c. Tunnel as fallback origin (+ regional)**: the fallback origin CNAMEs to a Tunnel public hostname, so there is no public origin IP and Cloudflare is the only way in. Good when you do not need granular or geo LB, and for test/dev.
- **5d. GTM + Private Network LB as custom origin**: custom hostname CNAME → regionalized LB (`eu-lb.myapp.com`), set as the hostname's **custom origin**. Pool 1: Tunnel public hostname `<UUID>.cfargotunnel.com` (must set the host header to the tunnel's public hostname). Pool 2: private IP (for example `10.0.0.5`) in a virtual network. **Prefer private IPs**: the original host header is preserved, whereas public-hostname endpoints need a fixed host-header override (one public hostname per LB endpoint).

**Other decisions.** Apex tenants → Static IPs (apex proxying). Tenants already proxied on Cloudflare → recommend they do not proxy, or use O2O after checking compatibility. Custom origin + LB gives session affinity per tenant. Automate with API/SDK/Terraform. Migrate in phases, watching DCV and validation status. Publish a tenant-facing runbook (Salesforce and Shopify are cited as examples). Check Tunnel limits, SaaS connection request details and custom-origin SNI rules.

**Source:** https://developers.cloudflare.com/reference-architecture/design-guides/extending-cloudflares-benefits-to-saas-providers-end-customers/

### 6. Multi-vendor application security & performance (multi-CDN / multi-DNS)
**Problem.** Compliance ("no single vendor"), resilience, regional performance differences, or cost (mostly high-volume media) push teams toward two or more reverse-proxy vendors. The costs: extra complexity, several dashboards, and a lowest-common-denominator feature set. Weigh this with stakeholders before committing.

**Onboarding options that make it possible.** Full DNS (Cloudflare authoritative). Secondary DNS with **Secondary DNS override** (zone transfer from the primary, then rewrite selected A/AAAA records to Cloudflare's proxy). Partial/CNAME setup (external DNS; apex needs Static IPs if the provider cannot flatten CNAMEs). Using Cloudflare WAF behind another CDN (CNAME with caching disabled via Cache Rules) is possible but not recommended.

**Deployments.**
- **6a. Active-active, third-party DNS**: an external authoritative DNS load-balances `www` between vendor CNAMEs (or static IPs for the apex). It can be driven by real-user or synthetic HTTP metrics (ThousandEyes, Catchpoint). Shifting traffic depends on record TTL. The single DNS provider is a SPOF. Configs are synced via Terraform against each vendor's API.
- **6b. Active-active, multi-vendor DNS from the same vendors** (recommended as the most resilient): both vendors are authoritative (primary + secondary via AXFR/IXFR). The secondary overrides proxy records to point at itself. Resolvers choose a nameserver by speed and availability, so they steer traffic and handle failover automatically, at the cost of predictability. Adding DNS-based LB at each vendor gives a more predictable split. Alternative: pin specific hostnames to a specific vendor.

**Multi-DNS options.**
1. *Primary + secondary*: standard zone transfer, simple. Records cannot change if the primary's management or transfer pipeline is down.
2. *Both primary*: most resilient and flexible (edit at either). You own sync (OctoDNS/Terraform/API).
3. *Hidden primary + secondaries*: unlisted source of truth, hides the primary and allows primary maintenance. Same pipeline risk as option 1.

**Key considerations.** Routing (DNS decides everything), configuration (API-first vendors, Terraform/CI, parity mapping, a shared SIEM, alerting), connectivity (Internet by default + Dedicated Egress IPs/BYOIP + Full (Strict)/mTLS; Tunnel; CNI via PNI/IX/partner; Argo; Authenticated Origin Pulls), operations (unified UI, analytics, log export, support, staff skills). **Avoid stacking** Cloudflare behind another proxy. It hides client signals (bots, rate limiting, DDoS, IP reputation), adds a second network hop and adds operational overhead. Exception: specific point solutions (a bot tool, an API gateway) or a temporary migration state. Plan for full-vendor outage with redundancy in DNS, network and origin connectivity. Cloudflare's anycast "every service on every server" design and seconds-fast API changes make it well suited to active-active.

**Source:** https://developers.cloudflare.com/reference-architecture/architectures/multi-vendor/

## Cross-cutting principles

- **Proxy everything you want to protect or accelerate.** L7 features only apply to proxied (orange-cloud) traffic. DNS-only exposes origins.
- **Anycast + every service in every DC**: the nearest DC handles caching, security and LB, and attack traffic is absorbed across the whole network.
- **Order of the L7 pipeline matters**: cache, WAF, DDoS and bots run before load balancing. LB is the final step, and requests go straight to the chosen endpoint with no further processing. Cache hits never reach the LB or origin.
- **Offload the origin in layers**: edge cache → regional tier → upper tier → Cache Reserve → origin (or originless Workers/R2).
- **Lock down the origin**: Tunnel (no inbound ports) or allowlisted Dedicated Egress IPs, plus Full (Strict) TLS and/or Authenticated Origin Pulls. Remember Simulate Zone for health checks.
- **Health checks should match the real traffic path**, or they will say "healthy" while users fail.
- **Measure before optimizing**: CWV at p75, server latency at p99. Separate origin time from network time. Track CHR.
- **Automate through APIs and Terraform**, especially for SaaS hostname onboarding and multi-vendor config parity.

## Decision hints

- **Tiered Cache topology**: most sites → Smart (+ Regional if users are global) because it minimizes origin fetches. Heavy, globally spread traffic that can tolerate more origin fills → Generic Global (Ent) for lower lower→upper latency, without Regional. Known regional user concentration → Custom (Ent).
- **Long-tail large objects evicted by LRU, or high egress bills** → add Cache Reserve (with Tiered Cache). It does not help objects with TTL < 10h or responses without Content-Length.
- **Dynamic, API or cache-miss-heavy traffic with TTFB issues** → Argo Smart Routing. Caching does not help there.
- **Can refactor the app** → originless Workers + R2/D1 rather than optimizing a distant origin, because it gives the best TTFB and needs no backend for large files.
- **Active/passive DR** → Off-Failover plus a fallback pool. **Active/active with unequal capacity** → Random with capacity weights.
- **Backends overwhelmed by concurrent slow requests** → LORS (L7 proxied only), not Random.
- **Lowest latency regardless of borders** → Dynamic steering (measured RTT). **Nearest by distance** → Proximity (needs pool GPS). **Legal or regional pinning** → Geo steering (plus Regional Services for processing location).
- **Stateful app without shared session store** → session affinity: `cookie` by default, `header` for API clients / idle-based expiry, `ip_cookie` for DNS-only. Use endpoint draining for maintenance.
- **Non-HTTP protocols**: need proxying/DDoS/origin hiding → Spectrum LB. Must not proxy → DNS-only LB (accepting exposed IPs, 30s TTL and no L7 security).
- **Origin answers only its own hostname** → host-header override on the endpoint (L7 only). With private IP endpoints the original host header is preserved.
- **Origin must not be publicly reachable** → Tunnel. For multiple private backends → Private Network LB (private IP + virtual network). Tunnel replicas give HA but no load balancing.
- **Non-80/443 service behind LB** → put it behind Tunnel with a catch-all rule, and use the `cfargotunnel.com` hostname as the endpoint, not a CNAME.
- **Full vs secondary vs partial DNS**: want one dashboard and all features → full setup. Must keep the existing primary DNS but want zone-transfer sync → secondary + Secondary DNS override. Cannot touch nameservers → partial/CNAME (apex needs Static IPs unless the provider flattens CNAMEs).
- **Multi-vendor routing**: need predictable percentage splits or performance-driven steering → external/DNS LB fed by RUM or synthetic data (6a), but avoid a single DNS SPOF. Need maximum resilience → multi-vendor authoritative DNS (6b). Pick primary+secondary for simplicity, dual-primary if you must edit records during a vendor control-plane outage, hidden primary to protect the source of truth.
- **"Defense in depth" by chaining CDN/WAF vendors** → avoid it. Run vendors in parallel. Stack only for point solutions or during migration.
- **SaaS tenant custom domains** → Cloudflare for SaaS custom hostnames, not one zone per tenant or multi-domain certificates. Apex tenants → Static IPs (apex proxying). Tenant already on Cloudflare → ask them not to proxy, otherwise O2O.
- **Per-tenant plans (Basic/Advanced)** → Custom Metadata + WAF for SaaS. **Tenant-supplied code** → Workers for Platforms (dispatch + outbound workers).
- **SaaS routing complexity**: single origin → fallback origin. Residency → insert a regionalized hostname. No public IP → Tunnel as fallback. Multi-origin, geo or private backends → regional LB as custom origin with private-IP pools.


Full document list with URLs: see catalog.md.
