# Cloudflare Network Services: Reference Architecture Distillation

Scope: L3/L4 network protection and connectivity (Magic Transit, Cloudflare WAN, Cloudflare Network Firewall, CNI, BYOIP, Network Flow, Gateway as network egress). Distilled from the Cloudflare Reference Architecture docs (Magic Transit RA + the "Network" diagrams section). Product renames to be aware of: Magic WAN -> **Cloudflare WAN**, Magic Firewall -> **Cloudflare Network Firewall**, Magic Network Monitoring -> **Network Flow**. Diagrams in the docs may still show old names.

## Contents
- Building blocks
- Patterns
  - 1. Magic Transit Reference Architecture
  - 2. Bring your own IP space to Cloudflare
  - 3. Optimizing device roaming experience with geolocated IPs
  - 4. Protect data center networks
  - 5. Protect hybrid cloud networks with Cloudflare Magic Transit
  - 6. Protect public networks with Cloudflare
  - 7. Protect ISP and telecommunications networks from DDoS attacks
  - 8. Network (diagrams index)
- Decision hints
- Docs taxonomy

## Building blocks

| Product/feature | Role | Choose it when | Key constraints/gotchas |
| --- | --- | --- | --- |
| **Magic Transit** | BGP-based, in-line DDoS protection + traffic acceleration for whole Internet-facing IP prefixes (on-prem, cloud, hybrid). Cloudflare announces your prefixes via anycast from all data centers, scrubs, then hands clean traffic to you over tunnels or CNI. | You must protect entire networks/IP ranges (any L3/L4 protocol), not just HTTP hostnames; attacks can exceed your links or on-prem appliances. | Min advertisable prefix is **/24** (ISPs reject longer). You must stop advertising the exact same prefixes from your own border routers (optionally keep a less-specific as failover). Needs an LOA for BYOIP prefixes. Mitigation avg under 3 s globally; hundreds of Tbps capacity. Not available in China Network for the tunnel anycast. |
| MT **always-on** | Traffic always routed via Cloudflare. | Default for most enterprises; want zero time-to-mitigate and no manual action. | Docs claim no latency penalty because anycast ingests at the nearest DC (no "trombone" to distant scrubbing centers); often faster than public Internet. |
| MT **on-demand** | Traffic goes direct in peacetime; Cloudflare advertises the prefix only when an attack is detected. | ISPs/telcos or orgs that want peacetime traffic untouched; supplement/replace on-prem scrubbers. | Relies on flow monitoring (Network Flow) for detection; auto-advertisement can be enabled, otherwise manual action increases response time. Onboard **more-specific** prefixes to Cloudflare than you advertise upstream (e.g. /24 at Cloudflare vs /23 upstream) so only the attacked prefix is pulled. |
| MT **Direct Server Return (DSR)** (default, ingress only) | Only Internet->customer traffic traverses Cloudflare; return traffic leaves via your own ISP default route. | Simplest; you own the IP space and can originate it from your ISP/cloud. | **Asymmetric routing**: breaks stateful firewalls / NAT in the path; must verify. In cloud, DSR requires BYOIP with the cloud provider. Not possible with Cloudflare-leased IPs. |
| MT **Egress** option | Return and server-to-Internet traffic also routed back through Cloudflare over the same tunnels/CNI (symmetric). | Stateful devices in path; leased Cloudflare IPs; want Network Firewall on outbound; want to avoid paying cloud provider BYOIP fees. | Source IP must be inside MT-protected prefixes and destination must be public (non-RFC1918). Requires policy-based routing (PBR) at sites to steer return traffic into tunnels. |
| **Leased Cloudflare IPs** (MT) | Cloudflare-owned addresses assigned to you, advertised by Cloudflare. | You own no /24 or larger; small cloud VPCs (e.g. /28s). | Return traffic **must** use MT Egress (can't originate Cloudflare IPs from your routers). |
| **GRE tunnel** | Anycast on-ramp over Internet. Cloudflare end is a Cloudflare-owned anycast IPv4; one tunnel reaches all DCs and fails over automatically. | Easiest on-ramp; no encryption required. | Customer end must be a public IP (router WAN). Use /31 RFC1918 inner interface addresses, unique per service instance. For customer-side redundancy build two tunnels from separate routers. Encapsulation overhead reduces MTU (general knowledge). |
| **IPsec tunnel** | Same anycast model, encrypted. | Need encryption over the Internet; cloud VPC on-ramps. | Check device compatibility matrix. MTU overhead (general knowledge). |
| **Cloudflare Network Interconnect (CNI)** | Private L2 cross-connect / direct connection to Cloudflare, BGP-peered, bypassing Internet. Cloudflare allocates a /31-style IP pair from its own space per link. | Performance, reliability, security; ISPs needing full **1500-byte MTU**; separate public vs private traffic onto separate links. | Physical presence at interconnection facilities (PeeringDB). Recommended redundant. Tunnels can also run over CNI (needed for Egress over CNI in the RA figures). |
| **Cloudflare Network Firewall** (ex-Magic Firewall) | Cloud-native L3/L4 firewall included/configured with Magic Transit; applies to ingress to MT prefixes, MT Egress, and Cloudflare WAN traffic. Supports IDS and packet capture. | Replace/reduce perimeter firewalls; geo-block; filter unwanted non-DDoS traffic before it hits your links. | Matches 5-tuple plus packet length, IP header length, TTL, and Cloudflare colo/region/country. Packet filter, not app-aware (use Gateway for L7). |
| **Cloudflare WAN** (ex-Magic WAN) | Any-to-any private (RFC1918) connectivity between sites, DCs, clouds over Cloudflare; east-west traffic. | Replace MPLS/legacy WAN; site-to-site; private-network Internet breakout. | Can share a service instance with Magic Transit or be separate (separate anycast endpoint) to keep external vs internal admin/traffic apart. Same GRE/IPsec/CNI on-ramps. |
| **Cloudflare Gateway** (SWG) | L3-L7 proxy with DNS, network and HTTP policies; TLS decryption, AV, sandboxing. | Control outbound Internet access from servers/private networks; app-level policy on selected east-west traffic. | Proxied traffic egresses from Cloudflare-owned Gateway IPs (source changes). Dedicated egress IPs available (paid), including geolocated IPs. |
| **Dedicated / geolocated egress IPs** | Fixed or country-specific source IPs for Gateway egress. | Partners allowlist your IPs; roaming devices need locale-correct egress. | Purchased add-on. |
| **BYOIP** | Cloudflare announces your own prefixes for proxy services (CDN/WAF) or Magic Transit. | Partners/B2B attest traffic by your IP range; hostnames must resolve into your space; network DDoS protection on your IPs. | LOA required; BYOIP range used for proxy must be **dedicated** to Cloudflare and not used elsewhere in your environment. For proxy, origin sees Cloudflare source IPs. |
| **Network Flow** (ex-Magic Network Monitoring) | Ingests NetFlow/IPFIX/sFlow from your routers, detects volumetric DDoS, alerts (email/webhook), can trigger MT auto-advertisement. | On-demand Magic Transit; visibility into traffic that doesn't transit Cloudflare. | Detection only; mitigation needs MT advertisement. |
| **Cloudflare DDoS Protection** | Automated in-line mitigation at every DC; underpins MT and proxy. | Always part of the path. | - |
| Spectrum, Argo for packets, Address Maps, Regional Services | Not covered by these network docs. | Spectrum = L4 proxy per application/port for TCP/UDP on Cloudflare IPs; Address Maps = which IPs a BYOIP/static zone answers with (general knowledge). | Verify in product docs before relying on specifics. |

## Patterns

### 1. Magic Transit Reference Architecture
**Problem:** Volumetric DDoS overwhelms hardware appliances and bandwidth-limited links; centralized scrubbing centers add latency.
**Components & traffic flow:** Connect (BGP announce customer prefixes from anycast) -> Protect/Process (DDoS mitigation, Network Firewall; optionally LB, caching, compute) -> Accelerate (Cloudflare backbone, hand-off via GRE/IPsec/CNI). Deployment variants:
- Default DSR: GRE tunnel, Cloudflare anycast endpoint (e.g. 192.0.2.1) to customer router WAN IP; /31 RFC1918 inner addresses; static route prefix -> tunnel in MT config; return via ISP default route.
- Egress enabled: symmetric flow through Cloudflare.
- MT over CNI: BGP over L2 cross-connects; DSR or Egress (Egress uses tunnels over CNI).
- Multi-cloud: split a /24+ into /26s across VPCs in different clouds/regions; routes managed centrally (API/dashboard); Egress lets you skip cloud BYOIP services (tunnel encapsulation hides BYOIP addresses from cloud provider).
- MT + Cloudflare WAN: north-south (MT) plus east-west (WAN), same or separate service instances with distinct anycast endpoints.
- Network Firewall filtering at the edge.
**Key design decisions & trade-offs:** DSR vs Egress (simplicity vs symmetry/security/cost-avoidance of cloud BYOIP); tunnels vs CNI; always-on vs on-demand (always-on = most comprehensive, no response delay; on-demand = peacetime direct path but slower response); single vs separate MT/WAN instances.
**When to use / not use:** Use for protecting IP networks and non-HTTP services at prefix scale. Not needed when only HTTP(S) hostnames need protection (use proxied CDN/WAF, general knowledge); not possible for prefixes smaller than /24 unless leasing Cloudflare IPs.
**Source:** https://developers.cloudflare.com/reference-architecture/architectures/magic-transit/

### 2. Bring your own IP space to Cloudflare
**Problem:** Proxied services appear from Cloudflare IP space; partners may validate by customer-owned IP ranges.
**Components & traffic flow:**
- Scenario 1 (proxy): LOA -> Cloudflare advertises a dedicated customer range (e.g. 152.3.15.0/24); DNS answers for proxied hostnames return IPs from that range; Cloudflare uses SNI to find origin (in a separate customer range), applies DDoS/WAF/Bot Management, cache; origin receives Cloudflare source IPs.
- Scenario 2 (network DDoS): LOA -> Cloudflare advertises prefixes via Magic Transit -> mitigated -> clean traffic delivered via tunnels (Cloudflare WAN) or CNI.
**Key design decisions & trade-offs:** Split IP space: one range dedicated to Cloudflare, another for origins. Proxy BYOIP keeps L7 features but origin still sees Cloudflare IPs; MT BYOIP protects whole network.
**When to use / not use:** Use when IP ownership/attestation matters, or to use MT on your own space. Skip if default Cloudflare anycast IPs are acceptable.
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/network/bring-your-own-ip-space-to-cloudflare/

### 3. Optimizing device roaming experience with geolocated IPs
**Problem:** IoT/roaming devices (vehicles, containers, medical devices, drones) on private APNs break out to the Internet from a regional breakout in the wrong country, so sites serve wrong language/region restrictions.
**Components & traffic flow:** Devices -> carrier private APN -> regional Internet breakout; breakout assigns each country a dedicated RFC1918 subnet -> connects to Cloudflare via GRE, IPsec or CNI -> Cloudflare WAN + Gateway with dedicated egress IPs geolocated per country (policy maps source subnet to egress IP) -> Internet. Optional: DNS filtering, network firewall policies (e.g. only allow telemetry endpoints), full TLS inspection with AV/sandboxing.
**Key design decisions & trade-offs:** Per-country subnet tagging at breakout is the key to selecting the right egress; GRE (ease) vs IPsec (encryption) vs CNI (performance). Dedicated egress IPs are a paid add-on.
**When to use / not use:** Fleets, global enterprises, telcos needing region-correct egress and device lockdown. Not needed if breakouts are already in-country.
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/network/optimizing-roaming-experience-with-geolocated-ips/

### 4. Protect data center networks
**Problem:** Perimeter and DMZ/core firewalls are costly, complex, hard to scale, need constant patching; must protect both public-facing and private inter-DC traffic.
**Components & traffic flow:** Two DCs, each with a public prefix (MT) and a private prefix (WAN), each DC on two Direct CNIs (one public, one private; single CNI possible). Four flows:
1. Inbound to public nets: anycast BGP -> DDoS -> Network Firewall -> CNI. Return via DSR (asymmetric, stateful/NAT risk) or MT Egress over the same CNI via PBR, filtered by Network Firewall.
2. Internet access from public servers: PBR -> CNI -> Network Firewall -> Gateway (DNS/HTTP policies, anti-malware) -> Internet with Gateway IPs (optionally dedicated egress); return reverse path.
3. Site-to-site private: PBR -> Cloudflare WAN -> Network Firewall -> back out to destination CNI. Variant with Gateway for L3-L7 app policy: Network Firewall -> Gateway (proxies, source becomes Gateway IP) -> Network Firewall again -> destination CNI.
4. Outbound Internet from private nets: same as 2 but via Cloudflare WAN instead of MT.
**Key design decisions & trade-offs:** Separate CNIs for external vs internal traffic (security practice) vs one shared; DSR vs Egress; plain WAN routing vs Gateway proxy for selected east-west traffic (more control, source IP changes).
**When to use / not use:** On-prem DC operators consolidating firewalls/WAN into a cloud service. Requires PBR capability on DC routers.
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/network/protect-data-center-networks/

### 5. Protect hybrid cloud networks with Cloudflare Magic Transit
**Problem:** Protect Internet-facing networks spread across on-prem and multiple clouds without distant scrubbing centers.
**Components & traffic flow:** Common steps: BGP anycast advertisement -> ingest -> DDoS scrub -> Network Firewall -> CNI or GRE/IPsec to each location.
- Scenario 1, BYOIP everywhere (/24s, sub-prefixes like /26 and /25 per site): return via DSR; DSR in cloud requires BYOIP with the cloud provider. Relocating a network between clouds = change MT route, protection uninterrupted.
- Scenario 2, leased Cloudflare IPs (e.g. /28 per site): return **must** use MT Egress via PBR, filtered by Network Firewall.
- Scenario 3, mixed: BYOIP /24s on-prem (DSR) + leased /28s in cloud (Egress). Optionally also send on-prem return via Egress for Network Firewall outbound control (block destinations/countries).
**Key design decisions & trade-offs:** Own IPs vs lease (prefix size, egress obligation); DSR vs Egress per site; keep less-specific announcements on your routers as failover.
**When to use / not use:** Multi-cloud/hybrid public services; organizations lacking /24s (lease). 
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/network/protect-hybrid-cloud-networks-with-cloudflare-magic-transit/

### 6. Protect public networks with Cloudflare
**Problem:** Same appliance limits as above, for public-facing networks across 5 locations (3 clouds, 2 on-prem).
**Components & traffic flow:** Inbound: anycast BGP -> DDoS -> Network Firewall -> CNI or GRE/IPsec; return via **MT Egress** (symmetric) via PBR, Network Firewall on egress. Outbound: PBR -> Network Firewall -> Gateway policies -> Internet from Gateway IPs; return traffic Gateway -> Network Firewall -> CNI/tunnels.
**Key design decisions & trade-offs:** Symmetric Egress chosen by default in this diagram; layering Network Firewall (L3/4) and Gateway (L3-7) for outbound.
**When to use / not use:** Full inbound + outbound protection for public networks. If only inbound DDoS needed, pattern 5 with DSR is simpler.
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/network/protect-public-networks-with-cloudflare/

### 7. Protect ISP and telecommunications networks from DDoS attacks
**Problem:** ISPs/telcos rely on on-prem mitigation with finite capacity and open-ended upgrade costs against hyper-volumetric attacks targeting their end customers.
**Components & traffic flow:** Peacetime: onboard prefixes to Magic Transit **on-demand** (no traffic change); routers export NetFlow/IPFIX/sFlow to Network Flow; connect via redundant CNI (preferred, 1500-byte MTU) or GRE; traffic flows normally via upstream transit/peers. Attack: Network Flow alerts (email/webhook) and can auto-advertise the more-specific protected prefix from all Cloudflare PoPs -> only that prefix's traffic reroutes -> mitigated -> delivered over CNI. Outbound traffic, other prefixes, and private peering (e.g. with large content providers) are unaffected.
**Key design decisions & trade-offs:** Onboard more-specific prefixes than advertised upstream (/24 vs /23) so longest-match pulls only attacked traffic; CNI vs GRE (MTU); auto vs manual advertisement.
**When to use / not use:** Service providers wanting peacetime-direct paths and cloud burst mitigation, as supplement or replacement for on-prem scrubbing. Enterprises wanting zero response time should prefer always-on.
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/network/protecting-sp-networks-from-ddos/

### 8. Network (diagrams index)
Index page listing the six network diagrams above. **Source:** https://developers.cloudflare.com/reference-architecture/diagrams/network/

## Decision hints

- If you need to protect **whole IP prefixes or non-HTTP protocols at L3** -> prefer **Magic Transit** over proxied HTTP because MT scrubs all packets to the prefix; if only web hostnames need protection -> proxied CDN/WAF is simpler and adds L7 features (general knowledge). For a single TCP/UDP app on Cloudflare IPs without owning a /24 -> Spectrum (general knowledge; not covered here).
- If you own **no /24** -> lease Cloudflare IPs for MT, and plan for **MT Egress** because DSR isn't possible with leased IPs.
- If you have a **/24 or larger** -> BYOIP with LOA; announce the exact prefix only from Cloudflare, keep a **less-specific** announcement from your routers as failover.
- If on-demand (ISP) -> onboard **more-specific** prefixes to Cloudflare than you advertise upstream so only the attacked prefix is rerouted.
- If there are **stateful firewalls or NAT** between servers and Internet -> prefer **Egress** over DSR because DSR causes asymmetric routing.
- If services run in **public cloud with your own IPs** -> prefer MT Egress over tunnels because you can skip the cloud provider's BYOIP service and fees; DSR in cloud requires cloud BYOIP.
- If you want **outbound filtering / geo-blocking** of server traffic -> Egress + Network Firewall; add **Gateway** for DNS/HTTP/TLS-inspection policies.
- If you want **zero response time / hands-off** -> always-on over on-demand; if peacetime traffic must stay on your own paths -> on-demand + Network Flow auto-advertisement.
- On-ramp choice: **GRE** for simplicity; **IPsec** when encryption over Internet is needed; **CNI** for performance, reliability, private path and full **1500-byte MTU** (recommended redundant for ISPs). Tunnels can run over CNI when Egress is needed.
- Tunnel redundancy: Cloudflare side is anycast (auto failover); build **two tunnels from separate customer routers** for your side.
- Internal east-west (RFC1918) traffic -> **Cloudflare WAN**, not Magic Transit; use separate service instances if external/internal admin must be isolated.
- Site-to-site traffic needing **app-level control** -> route through Gateway (accept source IP becoming Gateway IP); otherwise plain WAN + Network Firewall.
- Partners allowlist **your** IPs for proxied hostnames -> BYOIP for proxy services (dedicated range); for outbound, use dedicated egress IPs.
- Roaming/IoT devices exiting in wrong country -> Cloudflare WAN + Gateway with **geolocated dedicated egress IPs**, keyed on per-country source subnets.
- Separate public vs private traffic onto **different CNIs** when security policy demands physical separation.

## Docs taxonomy

Four doc types, from high level to hands-on:
- **Reference Architectures**: conceptual, broad technology area; how Cloudflare is built and where it integrates with your infrastructure. Read first for foundations.
- **Reference Architecture Diagrams**: one specific use case, diagram-first with short text; quick answer to "how would Cloudflare solve X". Grouped as AI, Bots, Content Delivery, IoT, Network, SASE, Security, Serverless, Storage.
- **Design Guides**: prescriptive best practices for a specific solution subset (e.g. Zero Trust for startups); no product commands.
- **Implementation Guides**: step-by-step configuration for a concrete job (mostly Learning Paths).

By-solution mapping (condensed):
- **Connectivity Cloud (platform)**: Security RA, Multi-vendor RA, Magic Transit RA, Hybrid cloud MT diagram, ISP DDoS diagram; design guide Extend benefits to SaaS providers' end customers.
- **Zero Trust / SASE**: SASE RA, SASE with Microsoft RA; diagrams for clientless private access, data at rest/in transit/in use, ZTNA with serverless authz, ISP DNS filtering, Cloudflare One Appliance deployment, self-hosted VoIP; design guides for ZTNA policies, ZT for startups, VPN migration, ZT for SaaS; implementation guides Secure Internet traffic, Replace VPN, Clientless access, Email security.
- **Networking**: diagrams Protect public networks, BYOIP, Hybrid cloud MT, ISP DDoS.
- **Application Performance**: CDN RA, Load Balancing RA; distributed web performance diagram.
- **Application Security**: Bot management diagram; Secure application delivery design guide; mTLS implementation guide.
- **Developer Platform**: AI diagrams (video captioning, composable AI, asset creation, multi-vendor AI observability, RAG, BigQuery to Workers AI), Serverless (image resizing + R2, A/B testing, fullstack, ETL, global APIs, image content management, programmable platforms), Storage (egress-free multi-cloud, on-demand migration, event notifications, UGC, Durable Objects control/data plane).


Full document list with URLs: see catalog.md.
