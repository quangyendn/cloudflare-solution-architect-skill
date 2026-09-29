# Application & Data Security on Cloudflare (reference)

Distilled from Cloudflare Reference Architecture docs. Anything marked `(general knowledge)` does not come from them.

Core model: an anycast reverse proxy where every server runs every service, so security and performance products act on a request in one pass near the user. Config reaches the whole network in seconds, and everything is API/Terraform-manageable. Protection applies only to traffic routed through Cloudflare (proxied DNS: authoritative, secondary, or CNAME; Spectrum; Magic Transit).

## Contents
- Building blocks
- Patterns
  - 1. Cloudflare Security Architecture: platform model and threat-to-product map
  - 2. Secure application delivery: origin connectivity + Tunnel + Access + WAF/CDN
  - 3. Streamlined WAF deployment across zones and applications (account-level WAF)
  - 4. AI Security for Apps (securing LLM-powered apps)
  - 5. Bot management
  - 6. FIPS 140 Level 3 compliance with Application Services
  - 7. Securing data in transit
  - 8. Securing data in use (RBI)
  - 9. Securing data at rest (CASB)
- Cross-cutting principles
- Decision hints
- Security baseline checklist

## Building blocks

| Product/feature | Role | Choose it when | Key constraints/gotchas |
|---|---|---|---|
| WAF Managed Rules (Cloudflare Managed Ruleset, OWASP Core Ruleset, Leaked/Exposed Credentials Check) | Rulesets Cloudflare maintains and pushes automatically: zero-days, OWASP Top 10, stolen credentials, sensitive-data extraction | Any internet-facing HTTP app, as the baseline | Tuned to keep false positives low, so Default mode suits most apps. Handle legacy apps with rule overrides or exceptions. At zone level, only one instance of each ruleset can be deployed |
| WAF Attack Score | ML score from 1 to 99 per request, with sub-scores for SQLi, XSS and RCE; catches attack variants and fuzzing that bypass signatures | Complementing managed rules against obfuscated or novel payloads | Lower score means more likely malicious (<50 = malicious or likely malicious in the doc's example). Use in custom-rule expressions |
| WAF Custom Rules | Expressions on request attributes, headers, bot/attack scores, AI fields, scan results | Site-specific policy; combining signals | Phase `http_request_firewall_custom`; log/block/challenge |
| Rate Limiting Rules | Count requests that match an expression, keyed on chosen characteristics (IP, headers, session, API token), then act | Brute force, credential stuffing, scraping, volumetric/DoS abuse, API quotas | Two behaviors: block for a fixed duration once exceeded, or throttle only the excess (sliding window). Phase `http_ratelimit` |
| HTTP DDoS Attack Protection (L7 DDoS) | Managed ruleset for known L7 attack tools, protocol violations, origin-error floods | Always on for proxied HTTP | L4 uses Spectrum; L3 (whole subnets) uses Magic Transit |
| Sensitive Data Detection | WAF rules that match and log sensitive data (PII, financial) in responses; integrates with API Shield | Detecting data exfiltration | Detects and logs; it is not an inline DLP for workforce traffic (that role is Gateway DLP) |
| Uploaded Content Scanning | Scans uploaded files for malware and exposes the results as WAF fields | Apps that accept file uploads | Mitigation still requires a custom rule on the scan fields. Enterprise add-on; scans only through the proxied zone with a size cap — not an AV solution for large/direct-to-R2 uploads (verify) |
| Bot Management (Enterprise) | Bot score from 1 to 99 per request, built from Heuristics (score 1 or 29), ML (2 to 99), JS Detections, and Anomaly Detection (deprecated); adds detection IDs, bot tags, score source, and a Verified Bots list | Scraping, price scraping, inventory hoarding, credential stuffing, ATO | Scores below 30 are commonly bots. Act through WAF rules or Workers. AD has no new onboarding. JSD injects invisible JS and can be turned off |
| Bot Fight Mode / Super Bot Fight Mode | Reduced bot feature sets on Free (BFM) and Pro/Business (SBFM) | Smaller plans without Enterprise BM | Only a subset of Enterprise capabilities |
| Challenges / Turnstile | Managed Challenge picks non-interactive, interactive, or Private Access Tokens. Turnstile is a CAPTCHA replacement embeddable in any site | Friction for suspect clients without CAPTCHA UX | Turnstile works **without proxying traffic through Cloudflare** |
| API Shield (API Gateway) | API Discovery (ML), Endpoint Management, positive security model (schema validation, mTLS, JWT validation), volumetric abuse detection, sequence mitigation, GraphQL protections | Public APIs, mobile/partner APIs, fuzzing, and broken authentication against APIs | Save endpoints to Endpoint Management before applying policies. Adds risk labels such as `cf-risk-missing-auth` |
| mTLS for hostnames/APIs | Only clients with valid certificates get access; certs managed from the dashboard or API | IoT, B2B, and mobile API clients you control | Needs client certificate lifecycle management (general knowledge). An implementation guide exists |
| Client-side security (formerly Page Shield) | Report-only CSP inventories scripts, connections, cookies; threat feeds + ML JS Integrity Score; change alerts; content security rules | Magecart and card skimming, third-party JS supply chain, PCI-style script control | Enforcement uses content security rules (a positive model). Visibility alone does not block anything |
| Security Analytics / Security Overview / Events / Log Explorer / Logpush | One view of mitigated and unmitigated traffic, bots, uploads, ATO; create rules from it; export to SIEM | Always. Also used to tune from log mode to block | Bots dashboard keeps 30 days and has a feedback loop for FP/FN |
| AI Security for Apps (Firewall for AI) | LLM Discovery (endpoints labeled `cf-llm`), detections for PII exposure, unsafe topics, and prompt injection/jailbreak, surfaced as WAF fields; prompt logging encrypted with a customer key | Protecting public LLM/GenAI apps whether hosted on Cloudflare, another cloud, or on-prem | Prompt detection handles only `application/json` bodies. Injection score <20 = attack. Detections run even without policies. Mitigate with custom or rate limiting rules |
| AI Gateway guardrails | Not covered in these docs | — | (general knowledge) AI Gateway can apply content guardrails on the app-to-model-provider path. Use it when you control the outbound LLM calls, and AI Security for Apps for inbound user traffic |
| SSL/TLS edge + origin certs, encryption modes | Edge cert for clients and origin cert for the Cloudflare-to-origin leg; modes set how both are used; post-quantum crypto | Always | Use **Full (Strict)** to verify the origin. Weaker modes leave the origin leg unverified or unencrypted (general knowledge for the specifics of Off/Flexible/Full) |
| Authenticated Origin Pulls (AOP) | mTLS from Cloudflare to the origin, so the origin can verify requests came through Cloudflare | Public-IP origins | Combine with an IP allowlist. The doc calls it "mTLS auth" to origin |
| Dedicated CDN Egress IPs | Customer-specific IPs Cloudflare uses to reach origins | Tight origin firewall allowlist | Recommended allowlist source |
| BYOIP | Cloudflare announces the customer's own prefixes for L7 services | Existing allowlists or partner firewalls are tied to your IPs | Needs your own IP prefixes |
| Cloudflare Tunnel (cloudflared) | Outbound-only encrypted connections: 4 connections to at least 2 data centers per connector; no inbound ports; DNS CNAME to `<uuid>.cfargotunnel.com` | **The recommended origin connection**. Also private apps (SSH, RDP) and connectivity to a Keyless/HSM server | Protect the token (anyone holding it can run the tunnel). Only same-account DNS records can use it. Run replicas for HA |
| Cloudflare Network Interconnect (CNI) | Private direct links through PNI, IX, or partners | Origins co-located with Cloudflare; no public internet path wanted | Physical or partner provisioning required |
| Cloudflare Access (ZTNA) | Identity, device posture, and network-aware authentication in front of apps; service tokens or mTLS for machines | Internal or admin apps exposed on public hostnames; SaaS SSO enforcement | Pair it with Tunnel so the origin is reachable only through Cloudflare |
| Keyless SSL | Cloudflare terminates TLS while the private key stays on the customer's key server or HSM; only the public cert is uploaded | Keys must never leave customer custody; FIPS 140 Level 3 | Each handshake needs a key operation on the customer's keyless module (general knowledge: adds latency). HSMs: AWS, Azure, Google, IBM, Entrust, Fortanix |
| Geo Key Manager | Not covered in these docs | — | (general knowledge) Restricts which regions' data centers can hold TLS private keys |
| Data Localization Suite (Regional Services, Customer Metadata Boundary) | The docs mention only "choose geographic locations for inspection and storage of data" | Data residency requirements | (general knowledge) Regional Services limits TLS termination and inspection to a region. CMB keeps logs and metadata in the EU or US |
| DLP (Gateway) | Predefined profiles, custom profiles, and Exact Data Match; used in Gateway (SWG) policies to allow, block, or isolate | Stopping sensitive data from leaving through workforce traffic | Needs TLS inspection: the device agent installs the Cloudflare root cert on managed devices |
| CASB (API-driven) | Out-of-band API scans of SaaS configs, users, and files; applies DLP profiles to shared or public files and produces findings | Data at rest in SaaS (misconfigured shares, exposed PII) | Detects and recommends. It does not act inline |
| Remote Browser Isolation (RBI) | Headless browser at the edge streams Network Vector Rendering (NVR) to the client; blocks copy/paste, print, upload/download, and keyboard input | Data in use: GenAI tools, contractors on SaaS, risky categories | Clientless options exist. Can be combined with dedicated egress IPs for SaaS IP allowlisting |
| Spectrum / Magic Transit | L4 proxy for TCP/UDP apps; L3 subnet DDoS | Non-HTTP apps or whole networks | — |
| Workers as a security layer | Custom logic on `request.cf`, response redaction, bot honeypots, custom Access checks | Logic WAF expressions cannot express | Cost, latency, developer upkeep |

## Patterns

### 1. Cloudflare Security Architecture: platform model and threat-to-product map
**Problem:** Protect public resources (sites, APIs) and private resources (internal apps, SaaS, data) on one platform instead of separate point products.
**Components & flow:** Anycast ingress, a single-pass inspection, then Smart Routing to the origin. Private resources join through on-ramps (WAN, cloudflared, Mesh, WARP, CNI) under Access, Gateway, DLP, CASB, and RBI.
**Threat → product:** DDoS → L7 DDoS / Spectrum / Magic Transit (+rate limiting, bots). Zero-day → Managed Rules + Attack Score. Unauthorized access → mTLS, JWT validation, Exposed Credentials Check. Magecart/skimming → client-side security + content security rules. Exfiltration → Sensitive Data Detection. Credential stuffing/brute force → bots + challenges + credentials ruleset + rate limiting. Hoarding → bots + WAF. Fuzzing → Attack Score + API Shield schema/sequence. XSS/RCE/SQLi → Attack Score sub-scores. Malware uploads → Uploaded Content Scanning.
**Key design decisions & trade-offs:** Put WAF in front of private apps too, because a trusted device can be compromised. Workers allow testable, code-level security logic and response rewriting, at the cost of money, latency, and developer upkeep. Centralizing identity at Cloudflare (several IdPs, SAML/OIDC, SCIM) means an IdP migration touches one integration.
**When to use / not use:** Use it for scoping and product mapping. It is not a configuration guide.
**Source:** https://developers.cloudflare.com/reference-architecture/architectures/security/

### 2. Secure application delivery: origin connectivity + Tunnel + Access + WAF/CDN
**Problem:** Onboard an app hosted in any cloud or on-prem so that it gets DNS, CDN, WAF, and authentication, and cannot be reached around Cloudflare.
**Components & flow (options for the origin link):**
1. *Public internet*: the proxied A record returns a Cloudflare anycast IP. The origin still has a public IP, so it can be **bypassed if the IP is known**. Mitigate with a firewall allowlist (preferably Dedicated CDN Egress IPs), **Full (Strict)** TLS, or AOP/mTLS. BYOIP helps when existing allowlists are tied to your own IPs.
2. *Tunnel (recommended)*: cloudflared opens outbound-only connections to nearby data centers, and the DNS CNAME points to the tunnel UUID. All inbound ports are closed, so direct attacks and volumetric DDoS on the origin are dropped. Also carries SSH/RDP. Dashboard-managed tunnels are recommended over CLI-managed ones.
3. *CNI*: a private physical or IX link, for origins co-located with Cloudflare.
Then layer on Access (Access groups: IdP group + MFA + device/network), CDN (Tiered Cache, Cache Reserve, Argo), WAF (custom, rate limiting, managed), bots, API Shield, and client-side security. All apply inline once traffic is proxied.
**Key design decisions & trade-offs:** Tunnel removes firewall changes and the risk of misconfiguring them, but the tunnel token must be guarded and connectors run with redundancy. A public-IP origin is simpler but needs several layers of lockdown. The doc's example starter rule *logs* requests with bot score <30 AND attack score <50 before any enforcement.
**When to use / not use:** The default blueprint for onboarding a web app. CNI only for co-located infrastructure.
**Source:** https://developers.cloudflare.com/reference-architecture/design-guides/secure-application-delivery/

### 3. Streamlined WAF deployment across zones and applications (account-level WAF)
**Problem:** Many zones and FQDNs, often backed by shared infrastructure, plus legacy apps prone to false positives and third-party apps. Zone-by-zone WAF leads to duplicated, drifting policy.
**Components & flow:** WAF phases (`http_request_firewall_custom`, `http_ratelimit`, `http_request_firewall_managed`) exist at both account and zone level. **Account rulesets are evaluated before zone rulesets.** Deploy several instances of the Managed Ruleset at account level, each scoped by a hostname filter expression (ideally a **hostname List**):
- Standard apps: Default configuration.
- Legacy app: Default with rule overrides that turn off the rules causing false positives.
- New or third-party app: Log mode.
- A final catch-all instance: Default for any host not in the lists.
**Key design decisions & trade-offs:**
- When only a few apps deviate, it is simpler to run one Default instance plus managed exceptions (skip) per FQDN.
- Zone level allows only one instance per ruleset, so special cases may be impossible there. Do not mix account and zone configuration. Use zone level only for config that belongs to a single zone.
- Onboard new apps into the Log instance first, then promote them.
- Reuse the same Lists across managed, OWASP, and rate-limit rules. Manage everything with the API or Terraform.
**When to use / not use:** Enterprise accounts with many zones or apps. A single small zone can stay at zone level.
**Source:** https://developers.cloudflare.com/reference-architecture/design-guides/streamlined-waf-deployment-across-zones-and-applications/

### 4. AI Security for Apps (securing LLM-powered apps)
**Problem:** LLM apps are probabilistic. Regex cannot catch prompt injection, and users can leak PII to the model or elicit unsafe output, which creates liability.
**Components & flow:**
1. LLM Discovery heuristics (slow responses of >1 s at <4 KB/s, with GraphQL, heartbeats, and generators filtered out) label endpoints `cf-llm` through API Shield.
2. Detections (PII exposure, unsafe topics, prompt injection/jailbreak score) run on all traffic to `cf-llm` endpoints **even when no policy exists**. Results appear in Security Analytics and Security Overview.
3. Mitigation uses ordinary WAF custom and rate limiting rules on the AI fields, applied to all discovered LLM endpoints or scoped by any request attribute.
4. Sensitive Data Detection logs PII in responses. Blocking PII inbound keeps the model from learning it and exposing it later.
Detections run in parallel, each on its own model on Workers AI, so adding detections adds little latency. Prompt logging stores the payload encrypted, and only holders of the customer's private key can decrypt it.
**Key design decisions & trade-offs:** Same operating model as WAF, no new dashboard. Works with any model or host. Maps to the OWASP Top 10 for LLM Applications. Limit: JSON bodies only. Also fix API Shield risk labels such as `cf-risk-missing-auth`.
**When to use / not use:** Use it for public chatbots and GenAI APIs behind the Cloudflare proxy. For *employee* use of public AI tools, use Gateway, DLP, and RBI instead (Pattern 8).
**Source:** https://developers.cloudflare.com/reference-architecture/architectures/ai-security-for-apps/

### 5. Bot management
**Problem:** Automated abuse (scraping, credential stuffing, hoarding, AI crawlers) mixed in with humans and good bots.
**Components & flow:** Anycast ingress. Layered engines (Heuristics, ML, JSD, and Anomaly Detection, which is being deprecated) produce a bot score from 1 to 99 plus source, detection IDs, and tags. Security policies (WAF custom rules, rate limiting, Workers) then act on it: block, allow, rate limit, or challenge. Analytics: Bots dashboard (30 days, FP/FN feedback), Security Analytics, Events, Log Explorer, Logpush.
**Key design decisions & trade-offs:** Exempt Verified Bots such as search engines from blocks. Turn on AI bot blocking if AI crawling is unwanted. Plan tier matters: BFM on Free, SBFM on Pro/Business, full BM with the score on Enterprise. JSD is optional and invisible.
**When to use / not use:** Enterprise BM when you need a score in rules. For forms or login on sites *not* proxied through Cloudflare, use Turnstile.
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/bots/bot-management/ (index: https://developers.cloudflare.com/reference-architecture/diagrams/bots/)

### 6. FIPS 140 Level 3 compliance with Application Services
**Problem:** Regulated sectors (government, HIPAA healthcare, finance, defense) need TLS keys in FIPS 140-3 L3 HSMs (tamper-resistant, keys leave only encrypted).
**Components & flow:**
1. The client connects with SNI `keyless.example.com`, whose certificate is declared keyless (only the public cert is uploaded).
2. cloudflared in private infrastructure opens an outbound tunnel. Only egress is allowed, and it can be narrowed by the firewall.
3. Cloudflare SSL sends the key operations through the tunnel.
4. The keyless module (a proxy) forwards them.
5. The HSM performs the operation over PKCS#11. The private key never leaves the HSM.
**Key design decisions & trade-offs:** You keep full WAF, DDoS, and CDN on the edge while key custody stays with you. Running the keyless module inside a Tunnel avoids exposing a public keyserver.
**When to use / not use:** Only when compliance or policy forbids giving Cloudflare the key. Otherwise use standard edge certificates.
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/security/fips-140-3/

### 7. Securing data in transit
**Problem:** Data moving between users and apps can be intercepted, or can leave to risky destinations.
**Components & flow:** TLS from client to edge and from edge to origin (post-quantum). Tunnels plus the device agent for private apps. For DLP: the user uploads through the agent or clientless mode. Gateway checks that the user may use the app, then scans for malware and sensitive data (predefined, custom, or EDM profiles). On a match (for example SSNs), it blocks, logs, and shows a block page.
**Trade-offs:** Content inspection needs TLS decryption on managed devices. Scope DLP with other attributes (for example, uploads to unapproved storage only).
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/security/securing-data-in-transit/

### 8. Securing data in use (RBI)
**Problem:** Sensitive data in the browser can be copied, downloaded, printed, or pasted into GenAI tools.
**Components & flow:** Gateway authorizes the request. An edge headless browser renders the page and streams encrypted NVR draw commands to the local browser. Policies turn off copy/paste, upload/download, printing, and keyboard input (AI apps, social networks, read-only SaaS for contractors).
**Trade-offs:** No reliance on signatures. Traffic still passes through Gateway and DLP.
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/security/securing-data-in-use/

### 9. Securing data at rest (CASB)
**Problem:** Files and configurations stored in SaaS can be overshared or misconfigured.
**Components & flow:** Access acts as the SAML/OIDC gate in front of SaaS. RBI plus dedicated egress IPs, combined with SaaS-side IP restrictions, keep SaaS reachable only from Cloudflare. CASB makes out-of-band API scans of configurations, users, and shared files against DLP profiles and produces findings.
**Trade-offs:** Detection and recommendations only. Pair with Gateway to cover data in transit.
**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/security/securing-data-at-rest/ (index: https://developers.cloudflare.com/reference-architecture/diagrams/security/)

## Cross-cutting principles
- **Lock down the origin so that only Cloudflare can reach it.** Order of preference: Tunnel (no inbound ports) or CNI. For public-IP origins: firewall allowlist (Dedicated CDN Egress IPs) plus Full (Strict) plus AOP/mTLS. A proxied DNS record alone does not prevent bypass.
- **Single-pass layered defense:** combine signals (bot score, attack score, AI fields, JWT/mTLS status) in rule expressions rather than chaining separate products.
- **Evaluation order:** account rulesets run before zone rulesets. Put a catch-all Default managed instance last. (General knowledge: phases run custom → rate limit → managed.)
- **Scale with account-level rulesets, hostname Lists, and Terraform/API.** Avoid mixing account and zone configuration. Use zone level only for truly zone-specific config.
- **Log or monitor before block:** deploy new apps and new rules in Log mode, check Security Analytics, Events, and Bots feedback, then promote to Default or Block. Tune false positives with overrides or exceptions instead of turning rulesets off.
- **Positive security models where possible:** schema validation, mTLS/JWT, sequence mitigation, content security rules.
- **Zero Trust even inside:** WAF in front of private apps, and Access (identity, MFA, device posture) in front of admin or internal hostnames.
- **Visibility always on:** AI detections, bot scores, and attack scores are computed whether or not a policy exists. Ship logs to a SIEM with Logpush.

## Decision hints
- Origin must not be directly reachable → prefer **Cloudflare Tunnel** over an IP allowlist, because it needs no inbound ports, cannot be proxied by DNS in another account, and drops direct DDoS at the origin. If the origin must keep a public IP → Dedicated CDN Egress IPs allowlist plus Full (Strict) plus AOP.
- Partners or firewalls already allowlist your IPs → **BYOIP** instead of re-issuing allowlists.
- Many zones or apps with shared baseline and a few exceptions → **account-level WAF** with hostname Lists over per-zone rulesets, because zone level allows one instance per ruleset and duplicates config.
- Obfuscated or novel injection attempts → add **Attack Score** rules on top of managed rules, because signatures miss variants produced by fuzzing.
- API abuse or fuzzing → **API Shield** (discovery, then schema validation, JWT/mTLS, sequence mitigation, volumetric abuse detection) over generic WAF alone.
- Login attacks → **Bot Management** plus the exposed/leaked credentials ruleset plus **rate limiting** on login paths plus challenges.
- Human verification on a site not proxied by Cloudflare, or on specific forms → **Turnstile** over CAPTCHA.
- Public LLM app (prompt injection, PII leakage, unsafe content) → **AI Security for Apps** with WAF rules on `cf-llm` endpoints over regex-based WAF rules, because injections are semantic. Make sure bodies are `application/json`.
- Employees pasting sensitive data into ChatGPT or other public AI → **Gateway DLP plus RBI** (copy/paste block), not AI Security for Apps.
- Magecart, card skimming, PCI script inventory → **client-side security** plus content security rules.
- FIPS 140-3 L3 or "private key must never leave our HSM" → **Keyless SSL plus Tunnel plus HSM** over standard edge certificates.
- Data residency or sovereignty → choose geographic locations for inspection and storage (docs). (General knowledge: Regional Services for in-region TLS termination, Customer Metadata Boundary for logs, Geo Key Manager for key location.)
- Internal or admin app on a public hostname → **Tunnel plus Access** (IdP group plus MFA plus device posture).
- SaaS data at rest oversharing → **CASB** plus DLP profiles. Also lock the SaaS to Cloudflare egress IPs.

## Security baseline checklist
1. **Onboard DNS** (authoritative preferred) and set records to **Proxied** for all web hostnames. Inventory assets in **Security Center**.
2. **Connect the origin securely:** Cloudflare Tunnel (redundant cloudflared replicas, token protected) or CNI. If the origin has a public IP, allowlist Dedicated CDN Egress IPs or Cloudflare ranges at the firewall.
3. **TLS:** SSL mode **Full (Strict)** with a valid origin cert. Turn on **Authenticated Origin Pulls** for public-IP origins. Use Keyless SSL/HSM if key custody is required.
4. **DDoS:** confirm HTTP DDoS protection; add Spectrum/Magic Transit for non-HTTP.
5. **WAF managed rules at account level:** Cloudflare Managed Ruleset plus OWASP Core plus Leaked Credentials Check, scoped with hostname Lists. Put new apps in Log mode, then promote. Add a catch-all Default instance.
6. **WAF custom rules:** use Attack Score (SQLi, XSS, RCE) thresholds, geo/ASN/path restrictions, and admin-path lockdown.
7. **Rate limiting** on login, signup, password reset, search, and API endpoints (keyed by IP, session, or API token).
8. **Bots:** SBFM or Enterprise Bot Management with score-based rules (<30 treated as automated), allow Verified Bots, decide on AI crawler blocking, and use Turnstile or Managed Challenge on sensitive forms.
9. **APIs:** API Discovery, then Endpoint Management, then schema validation, JWT validation or mTLS, volumetric abuse detection, sequence mitigation, and GraphQL protections. Fix the `cf-risk-*` labels.
10. **Client-side security:** monitor scripts and connections, alert on changes and malicious code, and enforce content security rules on checkout and login pages.
11. **Data exposure:** turn on Sensitive Data Detection. Add Uploaded Content Scanning plus rules if you accept files through the proxied zone (Enterprise add-on, size-capped, blind to direct-to-R2 presigned uploads; see volatile-facts.md).
12. **AI apps:** turn on AI Security for Apps, check the `cf-llm` endpoints, add rules for prompt injection (score <20), PII, and unsafe topics, and set up encrypted prompt logging.
13. **Internal/admin surfaces:** put them behind **Access** (IdP groups, MFA, device posture). Use service tokens or mTLS for machine clients.
14. **Observability:** Security Analytics, notifications, Logpush to SIEM, bot FP/FN feedback.
15. **Compliance/residency:** choose inspection and storage geographies. Consider FIPS (Keyless plus HSM) if regulated.


Full document list with URLs: see catalog.md.
