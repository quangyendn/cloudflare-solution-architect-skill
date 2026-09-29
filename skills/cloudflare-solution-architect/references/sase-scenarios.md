# SASE Scenarios, Vendor Integrations, Email Security, Guest Wi-Fi

Distilled from Cloudflare Reference Architecture docs. Product names: Cloudflare One Client = device agent (formerly WARP); Cloudflare Mesh = formerly WARP Connector; Cloudflare One Appliance = formerly Magic WAN Connector; Cloudflare WAN = formerly Magic WAN. Items marked `(general knowledge)` are not from the source docs.

## Contents
- Patterns
  - 1. Extend ZTNA with external authorization and serverless computing
  - 2. Cloudflare One Appliance deployment options
  - 3. Deploy self-hosted VoIP services for hybrid users
  - 4. DNS filtering solution for Internet service providers
  - 5. Protective DNS for governments
  - 6. Access to private apps without deploying client agents
  - 7. Secure access to SaaS applications with SASE
  - 8. Zero Trust and Virtual Desktop Infrastructure
  - 9. Cloudflare SASE with Microsoft
  - 10. CrowdStrike and Cloudflare: automated, risk-based protection
  - 11. SentinelOne and Cloudflare One
  - 12. Understanding Email Security deployments
  - 13. Securing guest wireless networks
- Integration notes
- Email security deployment modes
- Decision hints

## Patterns

### 1. Extend ZTNA with external authorization and serverless computing

**Problem:** IdP groups and posture checks aren't enough when the access decision depends on data held elsewhere (for example, whether security training is complete). Origins also have to confirm that Access actually authenticated the request.

**Components & flow:** An Access policy includes an **External Evaluation** rule that calls a Worker with user data (the username). The Worker queries D1 or an external API and returns True/False, which is combined with the rest of the policy. On success, Access forwards the request with a signed **JWT**, which the origin validates and can use for its own authorization.

**Key design decisions & trade-offs:** External evaluation returns only a boolean. Use cases in the doc: custom AuthZ (for example OPA on Workers), adding posture data to the JWT, and ZTNA for serverless apps. If the origin doesn't validate the JWT, direct access to the origin bypasses Access. The Worker call also adds latency and a dependency to the access path `(general knowledge)`.

**When to use / not use:** Use it when authorization inputs live in HR, LMS, or entitlement systems, or for policy-as-code. Skip it when native groups and posture already cover the requirement.

**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/sase/augment-access-with-serverless/

### 2. Cloudflare One Appliance deployment options

**Problem:** On-ramping branch traffic to Cloudflare and replacing hard-to-manage edge hardware, given existing CPE, HA needs, MPLS, and segmentation.

**Components & flow:** The appliance (physical or VM) uses zero-touch provisioning and builds one IPsec tunnel per WAN port. It handles DHCP, DNS, NAT, 802.1Q, IP ACLs, and breakout. Placement options:
- **Replace the CPE:** for an MPLS→Internet move, an EoL CPE, or a redundant device.
- **North of the CPE:** keep a firewall for defense-in-depth or L7 inter-segment rules. The appliance segments only at L3/L4.
- **South of the CPE:** when the CPE can't be removed (RJ-11 or PPPoE, an ISP-locked ONT, a managed service, a firewall under contract).

**Key design decisions & trade-offs:**
- **Uplink HA:** one appliance with 2+ ISP uplinks, load-balanced. Fine for small sites.
- **Full HA:** two appliances active/passive with heartbeat over a shared VLAN, each on both ISPs (4 tunnels). No preemption. Each ISP must provide multiple NTU ports.
- **Protected LIBO:** MPLS stays for private traffic (RFC1918 learned via BGP on the CE). The CE's static default route sends Internet/SaaS traffic to the appliance. Suits MPLS still under contract or apps with SLAs.
- **PBR split:** the firewall stays the default gateway and sends only TCP 80/443 to the appliance. Needs at least 2 public IPs.
- **Segmentation:** traffic between LAN ports is denied by default. Explicitly allowed traffic hairpins locally, so it keeps working during WAN outages (printers, NAS, IoT). The WAN ports accept no inbound traffic.

**When to use / not use:** Use it for branch on-ramp without a router or firewall fleet. Keep a firewall for L7 segmentation.

**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/sase/cloudflare-one-appliance-deployment/

### 3. Deploy self-hosted VoIP services for hybrid users

**Problem:** VPNs add latency and jitter to SIP/RTP and break NAT traversal. Remote users must reach an on-prem SIP server that has no public IP, in both directions.

**Components & flow:** The SIP server is on a private subnet with no public IP. **Cloudflare Mesh** runs on a host in that subnet as a virtual router. The LAN gateway gets a static route for `100.96.0.0/12` (the client CGNAT range) pointing at the Mesh host, so server-initiated calls also work. Gateway network rules filter both directions. Remote users run the Cloudflare One Client and register with the SIP server using their CGNAT IP.
- **Remote ↔ remote:** SIP goes through the server via Mesh. Direct-media RTP goes client-to-client through Cloudflare (enable "Allow all Cloudflare One traffic to reach enrolled devices").
- **Remote ↔ on-prem:** both SIP and RTP traverse Mesh.

**Key design decisions & trade-offs:** Mesh is bidirectional and keeps source IPs, so there are no NAT-traversal problems. Users connect to the nearest data center, avoiding a VPN hairpin. It needs a CGNAT route on the LAN gateway. Direct and indirect media are both supported.

**When to use / not use:** Use it for server-initiated or peer-to-peer private protocols. cloudflared only proxies inbound to the origin `(general knowledge)`. Not needed for hosted UCaaS `(general knowledge)`.

**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/sase/deploying-self-hosted-voip-services-for-hybrid-users/

### 4. DNS filtering solution for Internet service providers

**Problem:** ISPs want to resell DNS security and filtering without running on-prem appliances.

**Components & flow:** Subscribers → ISP recursive DNS → forwards to the ISP's Cloudflare Gateway tenant over anycast (built on 1.1.1.1) → DNS policies → answer. A **DNS location** identifies the ISP's queries. Gateway assigns IPv4/IPv6 resolver addresses plus DoT/DoH hostnames, and the location is keyed on the ISP resolvers' public source IPs. If the source IPs aren't stable, use per-location destination endpoints instead: a unique DoH/DoT hostname, a unique IPv6 address, and a dedicated IPv4 address on request.

**Key design decisions & trade-offs:** **Block** returns `0.0.0.0`/`::` or a Cloudflare block page. **Override** or redirect sends users to an ISP-hosted page. Allow and block lists (managed through the API) placed above Security Risks handle exceptions. Use **one location per product tier** (security, parental, education/CIPA, enterprise), each with its own endpoint. Logs go out through Logpush, and miscategorized domains can be reported with a change request.

**When to use / not use:** Use it for ISP or telco DNS security products. It enforces per location, not per user (for per-user control, see pattern 5).

**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/sase/gateway-dns-for-isp/

### 5. Protective DNS for governments

**Problem:** Agencies need protective DNS for office and remote users, with their own threat intel, visibility, and PII controls.

**Components & flow:**
- **Sites:** DNS servers or routers forward to Gateway, with locations keyed by source IP (as in pattern 4).
- **Threat intel:** Cloudflare categories plus **custom indicator feeds** (the agency or a third party as provider). Public feeds are free for eligible orgs.
- **Remote users:** either MDM-pushed DoH to the location hostname, with optional **per-user DoH tokens** for attribution, or the client in **DNS-only mode** with IdP login for group-based policies. The client works on managed and unmanaged devices, for example personal devices of high-risk staff.
- **Visibility:** logs mapped to users, with PII visibility gated by role. Logpush, built-in analytics, and the GraphQL API.

**Key design decisions & trade-offs:** The upgrade path to a full SWG adds HTTP policies (AV, sandboxing, RBI, DLP, upload controls). The client moves to **Traffic and DNS mode**, and sites use IPsec/GRE (Cloudflare WAN) or PAC files. **Regional Services** (DLS) pins where decryption happens, and **BYOPKI** lets you use your own certificate. DNS-only needs no certificates but covers only name resolution.

**When to use / not use:** Use it for national or multi-agency protective DNS. Add DLS when data residency is required.

**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/sase/gateway-for-protective-dns/

### 6. Access to private apps without deploying client agents

**Problem:** Third parties need private web apps without installing agents, publishing internal hostnames, or being given raw IPs.

**Components & flow:** (1) The user authenticates to clientless **RBI** at `<team>.cloudflareaccess.com/browser`, which renders to the user as encrypted vector streams. (2) The user browses to an internal hostname such as `app.company.internal`. (3) **Gateway resolver policies** resolve it against internal DNS inside Cloudflare. (4) Gateway **network policies** authorize the user for the destination IP. (5) Traffic reaches the app over a cloudflared QUIC tunnel.

**Key design decisions & trade-offs:** No public DNS records and no client software. Policy is written in the SWG (network policies), not in Access apps. HTTP only (SSH and VNC need browser rendering).

**When to use / not use:** Use it for third-party or BYOD web access. For non-HTTP apps or when posture is required, use the client.

**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/sase/sase-clientless-access-private-dns/

### 7. Secure access to SaaS applications with SASE

**Problem:** SaaS apps can't see device posture or how the user authenticated, can't track where downloaded data goes, and accept connections from anywhere. Office-IP allowlists don't cover remote users.

**Components & flow:** SaaS SSO redirects to Access, which acts as an identity proxy for existing IdPs. Unmanaged devices use RBI, managed devices tunnel with the client (posture included), and offices connect over IPsec. The SWG applies DNS, HTTP, and DLP policies to uploads and downloads. Traffic leaves from a **dedicated egress IP** that the SaaS tenant allowlists, so traffic that doesn't come through Cloudflare is denied even when the user is authenticated.

**Key design decisions & trade-offs:** Salesforce example: an egress policy maps "All Employees" to dedicated IP `203.0.113.88`, and Salesforce is IP-restricted to it. Sales and Executives are allowed with MFA, Gateway On, and a CrowdStrike score above 80. Other employees need the same plus purpose justification and temporary authentication with a named approver, which puts a human check on out-of-role access. XDR posture (CrowdStrike, SentinelOne, Intune) is matched to the authenticated user.

**When to use / not use:** Use it for sensitive SaaS such as CRM or M365. The IP lock requires the SaaS to support source-IP allowlisting.

**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/sase/secure-access-to-saas-applications-with-sase/

### 8. Zero Trust and Virtual Desktop Infrastructure

**Problem:** VDI is costly and often exists only to provide a secure browser. Legacy desktops that remain still need secure access and egress.

**Components & flow:**
- **Replace VDI with RBI:** start with *clientless RBI* (no agent, URL protected by Access, good for contractors). The end state is *RBI through the agent*, which adds posture, split tunneling, SWG, and UX metrics.
- **Secure access to remaining VDI:** client → Access policies (identity, posture, context) → VDI.
- **Secure VDI egress:** DNS config (resolver IPs, DoH, DoT) supports only DNS policies. **PAC files** support DNS, network, and HTTP policies and suit non-persistent VDI.

**Key design decisions & trade-offs:** Clientless is fast to roll out but gives fewer controls. The agent is the full-control option. PAC files avoid installing an agent on each golden image.

**When to use / not use:** Use RBI when VDI exists mainly for web or SaaS access. Keep VDI plus ZTNA and Gateway for legacy thick-client apps.

**Source:** https://developers.cloudflare.com/reference-architecture/diagrams/sase/zero-trust-and-virtual-desktop-infrastructure/

### 9. Cloudflare SASE with Microsoft

**Problem:** Microsoft-centric estates (M365, Azure, mixed SaaS, self-hosted, and non-web apps) replacing legacy VPN want Zero Trust built on their Microsoft identity and device tooling.

**Components & flow / decisions:** Entra ID (with SCIM groups), Intune posture (requires the client), CASB for M365, the SWG in front of M365 with IP restriction, and Email Security. Details are in Integration notes.

**When to use / not use:** Use it for any Microsoft-centric VPN replacement.

**Source:** https://developers.cloudflare.com/reference-architecture/architectures/cloudflare-sase-with-microsoft/

### 10. CrowdStrike and Cloudflare: automated, risk-based protection

**Problem:** Identity alone isn't enough to trust a request, endpoint and network telemetry are in separate systems, and manual response is too slow.

**Components & flow:** The Cloudflare One Client and the Falcon agent run on the endpoint. The Falcon **ZTA score** (1–100) is checked by Access through a service-to-service API. Logpush sends Gateway, WAF, and Email logs to **Next-Gen SIEM**. **Fusion SOAR** calls the Cloudflare API. Cloudflare also computes a UEBA user risk score.

**Key design decisions & trade-offs (six use cases):**
1. Posture-gated access: below the ZTA threshold, the user gets a block page telling them to remediate.
2. Threat hunting: an analyst pivots from an endpoint alert to that device's HTTP, DNS, and firewall logs in the SIEM.
3. Edge remediation: a Falcon IOC triggers SOAR, which adds the IP to a WAF or Gateway blocklist.
4. Compromised user: the ZTA score drops to Critical and Access blocks the next request. SOAR isolates the host and adds the user to a Cloudflare custom list.
5. Insider exfiltration: DLP blocks a source-code upload. The SIEM correlates it with USB activity, and SOAR forces step-up authentication or RBI.
6. App defense: WAF SQLi logs are enriched with CrowdStrike threat intel, then SOAR raises Bot Fight Mode sensitivity and blocks the ASN.

**When to use / not use:** Use it for Falcon customers who want closed-loop response. The SIEM and SOAR value requires those Falcon modules.

**Source:** https://developers.cloudflare.com/reference-architecture/architectures/cloudflare-sase-with-crowdstrike/

### 11. SentinelOne and Cloudflare One

**Problem:** Only healthy managed devices should reach sensitive resources, and the organization wants to advance on the CISA Zero Trust maturity model.

**Components & flow:** The SentinelOne agent and the Cloudflare One Client run on the device. SentinelOne is added as a Zero Trust **service provider** (API token, REST URL, polling frequency), and devices are **matched by serial number**. The Posture Engine queries S1, then the Access Policy Engine decides, then the SWG filters. A posture change triggers re-evaluation.

**Key design decisions & trade-offs:** Start with basic hygiene checks and tighten over time. Make policies role-aware with fallbacks. Plan for credential handling and polling latency. S1 EDR signals feed user risk scores.

**When to use / not use:** Use it for SentinelOne estates. It's posture only, with no SIEM or SOAR loop described.

**Source:** https://developers.cloudflare.com/reference-architecture/architectures/cloudflare-sase-with-sentinelone/

### 12. Understanding Email Security deployments

**Problem:** Choosing how Email Security fits into the mail flow.

**Components & flow:** Modes are Inline/MX (including the Cisco connector variant), M365 Graph API, BCC/Journaling with auto-move, and Mixed. Dispositions are Malicious, Spam, Bulk, Suspicious, Spoof, and Clean. Inline adds the `X-CFEmailSecurity-Disposition` header for downstream handling. Post-delivery auto-moves go to Inbox, Junk, Trash, Soft Delete, or Hard Delete, and a failed move is retried every 5 minutes. See the comparison table below.

**Key design decisions & trade-offs:** MX/Inline is the best practice when Cloudflare is the primary protection. You can switch modes without repurchasing, but **Advantage/CyberSafe are Inline-only**. Admin-verified false-positive and false-negative submissions retrain the models.

**When to use / not use:** See the table below.

**Source:** https://developers.cloudflare.com/reference-architecture/architectures/email-security-deployments/

### 13. Securing guest wireless networks

**Problem:** Guest Wi-Fi carries legal and reputational risk (piracy lawsuits, illegal activity). It needs acceptable-use enforcement and visibility without agents on guest devices.

**Components & flow:**
- **Basic router with a static IP:** set the WAN DNS to the location resolver IPs, block other port-53 traffic, and block DoH/DoT if the router supports it.
- **Enterprise network:** a guest SSID on its own VLAN. DNS reaches Cloudflare through DHCP settings or a proxy (internal DNS can forward). Allow port 53 only to Cloudflare. A **dedicated PAT public IP** for the guest subnet identifies the location.
- **Dynamic IPs:** use **dedicated resolver endpoints**. IPv6 is free, while IPv4 requires Enterprise.
- **Locations and policies:** use a CIDR for a shared policy across sites, or /32 for per-site policy (useful for local laws). Name policies Who-What-Action (for example `Guest-Security-Block`). Use security and content categories (Malware, P2P, crypto, adult), application types, and custom or government indicator feeds. Logpush to a SIEM covers retention and alerting.
- **Beyond DNS:** DNS filtering can be bypassed (manual resolver, direct IP or hosts file, VPNs). PBR sends the guest subnet (destination ANY) into an IPsec tunnel via Cloudflare WAN or an appliance. Traffic then passes Cloudflare Network Firewall (L3/L4 rules, blocking non-Cloudflare DNS, IDS, managed IP threat lists), followed by Gateway network policies that mirror the DNS rules. RFC1918 addresses are SNATed to shared Cloudflare egress IPs by default, so no PAT is needed at the edge. Dedicated egress IPs are optional.

**Key design decisions & trade-offs:** DNS-only is the recommended starting point because it needs no agent or certificate, but it can be bypassed. Adding tunnels gives layered enforcement.

**When to use / not use:** Use it for any guest or public network. Don't use HTTP inspection there, because it would need certificates on guest devices `(general knowledge)`.

**Source:** https://developers.cloudflare.com/reference-architecture/design-guides/securing-guest-wireless-networks/

## Integration notes

**Identity**
- **Entra ID:** the IdP for every Cloudflare-protected app, with groups synced via **SCIM**. Conditional Access controls (user and sign-in risk, platform, location, client app) are defined in Entra and enforced per request by Cloudflare ZTNA.
- Any IdP can back Access (SaaS identity proxy) and client enrollment. With the client, IdP groups drive DNS, HTTP, and network policies. Non-IdP attributes come from Worker external evaluation.

**Device posture**
- **Intune:** compliance and security state, for devices that run the Cloudflare One Client.
- **CrowdStrike:** ZTA score (1–100) via a service-to-service API, for example "Overall Score above 80". Checked on each request.
- **SentinelOne:** API token, REST URL, and polling interval. Devices matched by **serial number**. Attributes are infection status, active threats, agent active, network status, and operational state.
- XDR posture is matched to the authenticated user, so it also applies to SaaS identity-proxy flows. Native signals: Gateway On, MFA method, UEBA user risk.

**Logs / SIEM / SOAR**
- **Logpush** exports Gateway (DNS, HTTP, network), WAF, and Email logs to a SIEM. The GraphQL API supports dashboards. PII visibility is controlled by role.
- **CrowdStrike:** Logpush feeds Next-Gen SIEM. Fusion SOAR calls the Cloudflare API to update blocklists, add users to custom lists, force step-up authentication or RBI, and tune WAF or Bot Fight Mode.
- **Microsoft Sentinel / Defender for Endpoint:** not covered in these docs (the only mention is that M365 Defender/ATP scans a message before Cloudflare in API mode). Treat Sentinel as a generic Logpush SIEM destination `(general knowledge)`. SentinelOne: posture only, no log flow described.

**SaaS / M365:** CASB scans M365 via API for misconfigurations, exposed or sensitive files, and user and third-party access. The SWG in front of M365 adds DLP, and M365 is IP-restricted to Cloudflare egress IPs.

**Email:** Email Security can sit in front of M365 as MX (it can use Microsoft quarantine rules) or scan through the Graph API with no DNS change. Gmail needs an SMTP compliance (BCC) rule for scanning plus API remediation. On-prem Exchange has no auto-move API (needs PowerShell).

## Email security deployment modes

| Mode | Ingest | Timing | Strengths | Limitations | Best for |
|---|---|---|---|---|---|
| **Inline / MX** (recommended default) | MX points to Cloudflare | Pre-delivery | No dwell time. Subject and body banners, URL rewriting to link isolation. Queues mail if downstream is down. `X-CFEmailSecurity-Disposition` header. Protects mail-ingesting systems. Works with any MTA | DNS change in every zone | Cloudflare as primary anti-phishing control |
| **Inline behind an SEG** | SEG forwards to Cloudflare | Pre-delivery | Layered with Mimecast or Barracuda, which can only be MX | Complex SMTP chain, allow-policies duplicated. Disable Mimecast URL rewriting, or link analysis drops to domain reputation and age | Keeping an incumbent SEG |
| **Inline via Cisco connector** | Cisco as MX, or a supported hairpin | Pre-delivery | Same as Inline | Same as Inline | Cisco estates |
| *Anti-pattern:* M365 → Cloudflare → M365 via mail-flow rules | Redirect | — | — | Not supported by Microsoft. Attribution and delivery problems | Avoid |
| **API (M365 Graph)** | Mailbox subscription (Inbox or All Folders) | Post-delivery (~2–3 s move, no SLA) | No mail-flow change, agentless. Defender acts first. Proof of value with remediation off | Dwell time during outages. Graph throttling (10k requests/10 min, 4 concurrent, 150 MB/5 min) can be abused. Needs read/write mailbox access. No message modification | Fast layered deployment on M365 |
| **BCC / Journaling + auto-move** | SMTP copy (M365 journal, Google compliance rule) | Post-delivery | API used only for remediation, so less throttling risk. Scope can be internal, external, or both. Proof of value behind any platform, no API needed | Same dwell-time and no-modification limits. Relies on M365 or Google SMTP. May need an M365 connector | API-like benefits, Google Workspace |
| **Mixed** | Inline for external mail, BCC/Journal for internal | Both | One product and one policy set for external blocking and internal phishing | Internal detections are content-only (no authentication or path data). More false positives with the impersonation registry | Mail-ingesting systems plus concern about internal compromise |

Auto-move also handles retroactive detections and phish submissions. Admins should verify user submissions and resubmit them through the dashboard.

## Decision hints

- If **access depends on data outside the IdP or EDR**, use **Access External Evaluation backed by a Worker** rather than syncing that data into IdP groups, because it's checked live on every request.
- If the **origin can be reached directly**, have it **validate the Access JWT**.
- If **contractors** need private **web** apps with no agent, use **clientless RBI + resolver policies + cloudflared**. It also keeps internal hostnames out of public DNS. For non-HTTP apps, use the client.
- If traffic is **bidirectional or server-initiated** (VoIP), use **Mesh + a CGNAT static route** rather than cloudflared.
- If **SaaS must only be reachable through your controls**, use **dedicated egress IPs + a SaaS IP allowlist + Access posture policies**, because the SaaS app can't check posture itself. For **out-of-role users**, add **purpose justification + temporary authentication with an approver** rather than a flat deny.
- If the device is **unmanaged**, use **RBI** rather than full-tunnel client access.
- If **VDI exists mainly for browser access**, replace it with **RBI** (clientless first, then the agent). For legacy desktops that remain, put **Access** in front, and use **PAC files** (all policy types) rather than DNS config (DNS only) for egress.
- If you're an **ISP/telco** selling filtering tiers, create **one DNS location per tier**, each with its own endpoint.
- If **source IPs are dynamic**, identify the location by **destination endpoint** (free unique IPv6 or DoH/DoT hostname; dedicated IPv4 is Enterprise-only) rather than by source IP.
- If you need **per-user DNS**, use **DoH user tokens** (no agent) or the **client in DNS-only mode** (IdP groups). Upgrade to **Traffic and DNS mode** when you want HTTP controls.
- If **decryption location** matters, use **Regional Services (DLS)** and optionally **BYOPKI**.
- For **guest Wi-Fi**, start with **agentless DNS filtering + a port-53 lockdown**. If bypass is a concern, add an **IPsec tunnel via PBR + Network Firewall + Gateway network policies**.
- Branch placement: put the appliance **south** of a CPE that can't be removed (ONT, PPPoE, contract). Put it **north** when a firewall must keep L7 inter-segment rules (the appliance only segments at L3/L4). Otherwise **replace the CPE**. **Critical sites** get active/passive pairs with dual ISPs (4 tunnels). **Small sites** get one appliance with dual uplinks.
- If **MPLS is still under contract**, use **protected LIBO** rather than a big-bang cutover. If **only web traffic** should go to Cloudflare, use **PBR for TCP 80/443** (needs at least 2 public IPs). If **LAN devices must survive WAN outages**, use the **local inter-port allow rules**.
- If Cloudflare is the **primary email protection**, choose **MX/Inline** over API: it blocks before delivery, supports banners and link isolation, and protects mail-ingesting systems.
- If you need **no mail-flow change or a proof of value**, use **API** or **BCC/Journaling**. Prefer **BCC/Journaling** when **Graph throttling** is a concern or the platform is **Google**.
- If **Mimecast or Barracuda must stay MX**, deploy **Inline behind them** and **disable Mimecast URL rewriting**.
- If **CRM, ticketing, or archive mailboxes** ingest email **and** internal compromise is a worry, choose **Mixed**. Customers on **Advantage/CyberSafe** can only use **Inline**.
- For **CrowdStrike** (with SIEM and SOAR), design a **closed loop**: ZTA-gated Access, Logpush to the SIEM, and SOAR actions. For **SentinelOne**, design **serial-matched posture checks** with a chosen polling frequency.
- For **SIEM, compliance, or alerting** requirements, enable **Logpush** and restrict **PII log visibility** through roles.


Full document list with URLs: see catalog.md.
