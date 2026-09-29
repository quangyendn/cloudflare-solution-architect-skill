# SASE / Zero Trust on Cloudflare (Cloudflare One)

Distilled from Cloudflare Reference Architecture docs (SASE architecture, ZTNA policy design, Zero Trust for startups, Zero Trust for SaaS, VPN migration, Zero Trust implementation guides). Naming note: the docs use current names. **Cloudflare One Client** = WARP / "device agent". **Cloudflare Mesh** = formerly WARP Connector. **Cloudflare WAN** = formerly Magic WAN. **Cloudflare One Appliance / WAN Connector** = formerly Magic WAN Connector. **Access** = ZTNA. **Gateway** = SWG.

## Contents
- Building blocks
- Patterns
  - 1. SASE reference architecture (progressive adoption)
  - 2. Designing ZTNA access policies
  - 3. Zero Trust for startups (greenfield)
  - 4. Zero Trust for SaaS
  - 5. Network-focused VPN concentrator → ZTNA migration
  - 6. Zero Trust implementation guides (index)
- Policy design rules
- Migration & rollout playbooks
  - VPN concentrators → ZTNA (network-focused, 3 phases)
  - Startup greenfield rollout
- Decision hints

## Building blocks

| Product/feature | Role | Choose it when | Key constraints/gotchas |
|---|---|---|---|
| **Access – self-hosted app** | ZTNA reverse proxy. A public hostname fronts a private app reached through a tunnel. Every request is authenticated and checked against policy. | Browser-based internal web apps. Also SSH/VNC rendered in the browser. Contractors or partners who cannot install software. | Needs an active domain on Cloudflare (full DNS or partial/CNAME setup). Clientless mode supports only HTTP(S) and browser-rendered SSH/VNC. Only `cloudflared` can proxy public hostnames (Mesh cannot). Apps get the edge's WAF, CDN, DDoS and bot protection. |
| **Access – private IP app** | ZTNA for private IPs/CIDRs, ports and protocols (arbitrary TCP/UDP/ICMP) | Non-HTTP protocols (RDP, databases, thick clients). Admin or network-level access. | The user must run the Cloudflare One Client or sit on a network already connected to Cloudflare. Policies show up as Gateway **network policies**, so the MFA and external-evaluation selectors are not available; verify those at client login instead. You can enforce a client session duration (for example 60m) to force re-authentication. Agentless alternative: browser isolation plus private DNS. |
| **Access – SaaS app** | Cloudflare acts as SSO/identity proxy (SAML/OIDC/OAuth) in front of your IdP | You want one policy engine and posture checks for SaaS. You want to decouple SaaS SSO from a single IdP vendor, or support multiple IdPs for one app. | No tunnel needed. A "require Gateway" check runs only **at login** for SaaS; pair it with a dedicated egress IP allowlist for continuous enforcement. Also works for self-hosted apps that ship SSO connectors (for example self-hosted Sentry). |
| **Access – infrastructure app** | Targets (servers, clusters, DBs) proxied over `cloudflared`. Several machines can share one target. | Many servers need one shared access policy and a compliance audit trail | Built-in access and **command logging**. |
| **Access policies** | Allow / Block / Bypass / Service Auth. Include (OR), Require (AND), Exclude (NOT). | Every Access app | Deny by default. Policies are evaluated in order. Use the policy tester. Block is rarely needed. Bypass turns off enforcement, so use it only for endpoints that must be public. |
| **Access Groups** | Reusable, nestable sets of identity, device and network criteria | Always. Define "Employees", "Secure Admins" and similar once. | Managed via API/Terraform. The same group can drive device-client settings, such as stopping admins from disabling the client. |
| **Service tokens / mTLS / SSH certs** | Machine identity for non-human callers | APIs, IoT, service-to-service calls | Used with the Service Auth action. No login page. Storage and lifecycle are centralized in Cloudflare. |
| **Additional Access settings** | Isolate application (RBI), purpose justification, temporary authentication (approver sign-off), session duration, external evaluation (Worker API) | Sensitive apps, third parties, time-of-day rules | Isolation needs a **matching Gateway HTTP isolate policy** scoped to the same users. Without that scope, RBI applies to everyone. |
| **Gateway DNS policies** | DNS filtering (security categories, content categories, shadow-IT blocking) | First control to switch on. Also the only option for agentless sites (DNS locations by source IP, DoH or DoT). | Sees DNS only: no L4/HTTP policies. No identity unless you use DoH with a service token or the client in DoH mode. Cloudflare recommends DoH over DoT because more OSes support it. |
| **Gateway resolver policies** | Send internal domains to internal DNS servers (for example `example.local` → 10.10.10.123) | Private hostnames behind tunnels or WAN | The internal DNS server needs a route, usually a `cloudflared` private network route. |
| **Gateway network policies** | L3/L4 firewall on identity, posture, IP and port | Private IP access. Replacing 5-tuple ACLs with identity-based rules. | Not available for the DNS-only on-ramp. |
| **Gateway HTTP policies** | L7 SWG: allow/block/isolate, file-type controls, DLP, tenant control (header injection) | SaaS data protection, shadow IT, upload/download controls | HTTPS filtering needs **TLS inspection**, which means installing and trusting the Cloudflare root cert on devices. The client can automate this. Read the TLS decryption guidance before rolling out. |
| **Dedicated egress IPs + egress policies** | Org-unique source IPs, assigned by policy on IdP group and posture | SaaS IP allowlists. Legacy "trusted source IP" controls. | Can be geolocated to chosen Cloudflare DCs. Traffic that does not match falls back to the shared Cloudflare IP range and fails the allowlist. Enforcement is near real-time (L3/L4): when posture changes, SaaS access is lost at once. |
| **Cloudflare One Client (WARP)** | Device on-ramp and posture collector | Preferred method for users off-network | Modes: full L4 proxy, DNS-only, HTTP proxy, posture-only. Split tunnels can be set per group, OS or network. By default RFC1918 ranges are **excluded** (they go to the local gateway). Private DNS domains can be sent to local resolvers. Client traffic to private networks is sourced from **100.96.0.0/12** (CGNAT), so add a return route at the DC. Uses device enrollment policies, device profiles and managed networks. Deploy with MDM/UEM. |
| **Device posture** | Client checks (app, file, firewall, disk encryption, domain joined, OS version, device UUID, serial number, client cert, "gateway", WARP), plus 3rd-party (CrowdStrike, SentinelOne, Intune, Tanium, Carbon Black) | Any sensitive app | Evaluated on every request. Some 3rd-party integrations work **without** the client (matched by email). Agentless access gives identity only, with no posture. |
| **Cloudflare Tunnel (`cloudflared`)** | Outbound-only QUIC tunnel from the app network. Supports public hostnames and private network (CIDR) routes. | Default connector for user→app ZTNA and VPN replacement | **Inbound only.** Server-initiated traffic uses the host's default route, not the tunnel. Run 2+ replicas (for example 3 in K8s). Connections spread across several Cloudflare DCs with automatic failover. Can sit on the app host (strict per-app isolation) or on dedicated hosts/containers. Prometheus metrics endpoint. Pair with Load Balancing when you need fine traffic steering. Can be packaged into customer-environment deployments. |
| **Cloudflare Mesh (ex-WARP Connector)** | Linux gateway for bidirectional, site-to-site and mesh traffic. Uses a CGNAT overlay (100.96.0.0/12). | Server-initiated flows (AD, SCCM, VoIP/SIP, CI/CD), overlapping IP ranges, no router changes allowed | Per the VPN migration guide, failover and ease of configuration are weaker than `cloudflared`. Cannot proxy public hostnames. |
| **Cloudflare WAN (ex-Magic WAN)** | Anycast IPsec/GRE tunnels from routers, firewalls and cloud VPN gateways. "Light branch, heavy cloud." | Whole-site on-ramp: branch/HQ/DC, site-to-site, SWG and branch-firewall replacement, gear where no agent can be installed | Uses static routes. ECMP across tunnels for throughput and failover. Endpoints keep their RFC1918 IPs. Use GRE when traffic is already TLS or IPsec throughput is the bottleneck. The throughput of the old appliance limits scale. Network Analytics is sampled. |
| **Cloudflare One Appliance (WAN Connector)** | Plug-and-play hardware or virtual appliance that auto-builds IPsec to Cloudflare WAN | Small and medium sites (retail, small offices) | Managed centrally. Per the doc (2023), best for SMB-size sites. |
| **Cloudflare Network Interconnect (CNI)** | Private direct link (Direct, Cloud, Classic CNI, or peering via IX/PNI) | Networks in colo facilities shared with Cloudflare | Classic CNI is for Magic Transit only. |
| **PAC / proxy endpoint** | Agentless HTTP forwarding | You cannot install the client on the device | Needs the root cert for HTTPS. Only proxies traffic from **admin-specified source IPs** (for example site NAT IPs). No identity or posture. |
| **Remote Browser Isolation (RBI)** | Headless browser at the edge. Sends draw commands to the local browser. | Risky or uncategorized sites, contractors/BYOD, read-only access to sensitive apps, clientless access to private apps | Controls: copy/paste, print, upload/download, keyboard. Carries identity but **no device posture**. Always passes through Gateway. Can be triggered by a Gateway policy, a prefixed link, or an Access "isolate" setting. |
| **CASB (API)** | Scans SaaS (Google Workspace, M365, Salesforce, Box, Dropbox…) for misconfig, oversharing and risky 3rd-party apps | Data at rest, SaaS posture management | Separate from inline access controls. DLP scanning of stored files is supported for GWS, M365, Box and Dropbox. |
| **DLP** | Predefined profiles (financial, PII, API keys, source code), custom regex, exact-data datasets, Microsoft Purview labels | Upload/download control in Gateway, CASB, outbound email | Tune with **match count** and **context analysis** (keywords within about 1000 chars) to cut false positives. The usual action is block. |
| **Email security** | Inbound anti-phishing and BEC/VEC protection, link rewrite and isolation, outbound DLP (M365 add-in) | Any org on M365 or Google Workspace | **Inline (MX)** can quarantine, tag and modify messages and works with any SMTP service. **API** (journaling/BCC) catches mail only after delivery, can only retract, and supports fewer providers. Run both together to retract phishing that is weaponized after delivery. Also provides SMTP spike queuing (DoS/outage buffer). |
| **SaaS tenant control** | Gateway injects HTTP headers that limit M365/GWS logins to your own tenant | Compliance: block personal or other tenants | Needs HTTP inspection. |
| **Identity providers** | SAML/OIDC, Okta, Entra ID, Google Workspace, GitHub, LinkedIn, Facebook, one-time PIN | Always. Several IdPs can run at once. | OTP is built in, but a real IdP is strongly recommended. The IdP passes groups, amr (MFA type), and SAML attributes or OIDC claims for use in policy. |
| **SCIM** | Imports IdP groups for use in policy | IdP supports SCIM. You want group changes to apply automatically. | Groups can also come from SAML/OIDC claims at login. |
| **Digital Experience Monitoring (DEM)** | Synthetic tests from devices, with fleet-wide and per-device drill-down | Troubleshooting user experience (ISP versus SaaS versus Cloudflare) | Needs the client. |
| **Logs & analytics** | Gateway activity logs, network session logs, Access and admin audit logs, Network Analytics (GraphQL), Logpush to SIEM (S3, GCS, Splunk, Datadog, Sumo, Azure) | Always. Also used for shadow-IT discovery and private network discovery. | Notifications cover tunnel and IPsec health. |
| **Virtual networks** | (general knowledge) Separate routing tables in Zero Trust so overlapping private CIDRs can coexist behind different tunnels | Overlapping RFC1918 ranges across VPCs or customers | Not covered in these docs. The docs suggest Mesh's CGNAT overlay for overlapping IPs. |
| **API / Terraform** | The whole platform is manageable as code | Startups/DevSecOps. Wanting to avoid config drift. | Access Groups, policies and tunnels can all be managed in Terraform. |

## Patterns

### 1. SASE reference architecture (progressive adoption)
- **Problem:** Castle-and-moat model with VPN concentrators, MPLS and hardware firewalls. Traffic is backhauled, browsing is slow, users find workarounds, and policy is inconsistent across a hybrid workforce and multiple clouds.
- **Components & flow:** Build in four layers. (1) Connect apps: `cloudflared` for self-hosted, SWG + Access for SaaS + CASB for SaaS. (2) Connect networks: `cloudflared`, Mesh, Cloudflare WAN (IPsec/GRE/Appliance), CNI. (3) Forward device traffic: client, PAC, RBI, DNS. (4) Verify users and devices: IdPs, posture, service tokens/mTLS. Then add email security and unified management: Lists, DLP, Access Groups, logs, DEM. Anycast means every service runs in every DC, traffic is inspected near its source in a single pass, and the policy engine is shared across SWG and ZTNA.
- **Key design decisions & trade-offs:** The on-ramp decides which policy data is available. Only the client provides identity **and** posture. WAN tunnels provide L3–L7 filtering and egress IP but no identity. Services can be combined, for example a Gateway HTTP + DLP policy on a private app behind Access, which blocks sensitive downloads from internally hosted apps.
- **When to use / not use:** Use as the master map for any "replace VPN/MPLS/firewall appliances" or "unify security" brief. It is not a per-product configuration guide.
- **Source:** https://developers.cloudflare.com/reference-architecture/architectures/sase/

#### 1a. Connecting users to self-hosted/private apps (tunnels)
- **Problem:** Give remote users access to internal apps without inbound firewall holes or a VPN.
- **Components & flow:** `cloudflared` opens outbound QUIC connections to several Cloudflare DCs. Then either (a) **public hostname**: DNS → Cloudflare → Access policy → tunnel → `localhost:port`, one hostname per service; or (b) **private network**: a CIDR route with the client on the user device, giving L4 TCP/UDP/ICMP access.
- **Key design decisions & trade-offs:** Put `cloudflared` on the app host when you need per-app tunnels for high-risk or compliance workloads. Put it on dedicated hosts or containers for shared network access. Deploy several replicas. Public hostnames give narrow per-port exposure. Private networks give flexibility but broader reach. `cloudflared` never becomes an egress on-ramp for the servers behind it.
- **When to use / not use:** This is the default for VPN replacement. Do not use it when servers must initiate connections to users or other sites; use Mesh or WAN instead.
- **Source:** https://developers.cloudflare.com/reference-architecture/architectures/sase/

#### 1b. Connecting networks (on-ramp selection)
- **Problem:** Branches, DCs and clouds need to send traffic through SASE, including east-west traffic.
- **Components & flow:** Software agents (`cloudflared` for client→server, Mesh for bidirectional or mesh), Cloudflare WAN anycast IPsec/GRE with ECMP (Appliance, 3rd-party routers, cloud VPN gateways), and CNI. These can run side by side at any location. Client and Mesh endpoints get IPs in 100.96.0.0/12. WAN endpoints keep RFC1918 addresses.
- **Key design decisions & trade-offs:** Recommended/alternative table:
  - Remote users → private apps: **Tunnel**, alternative WAN.
  - Site-to-site: **WAN**, alternative Mesh when perimeter routing cannot change.
  - Site egress to SWG/FW: **WAN**.
  - Service-initiated traffic to users (AD, SCCM, VoIP, DevOps): **Mesh**, alternative WAN if inbound source-IP fidelity is not needed.
  - Mesh/device-to-device: **Mesh**.
- **Source:** https://developers.cloudflare.com/reference-architecture/architectures/sase/

#### 1c. Forwarding device traffic (client vs agentless)
- **Problem:** Users off the corporate network still need filtering and app access.
- **Components & flow:** The client is preferred. Agentless options are the PAC/proxy endpoint, RBI (link-, Gateway- or Access-triggered) and DNS locations (source IP, DoH, DoT).
- **Key design decisions & trade-offs (capability matrix):**
  - WAN: TCP/UDP. DNS, HTTP and network policies. No identity, no posture. RBI and egress IP yes.
  - Client: TCP/UDP. All policy types. Identity and posture yes.
  - RBI: HTTP. All policy types. Identity yes, posture no.
  - PAC: HTTP. DNS, HTTP and network policies. No identity, no posture.
  - DNS: DNS policies only. No identity unless DoH with a service token.
- **Source:** https://developers.cloudflare.com/reference-architecture/architectures/sase/

### 2. Designing ZTNA access policies
- **Problem:** Turning identity, device and network signals into least-privilege, maintainable Access policies.
- **Components & flow:** Prerequisites: an active domain, a network route (`cloudflared`/Mesh/WAN/CNI), an IdP (with SCIM), and posture providers. Then build the app (self-hosted, private IP, SaaS or infrastructure) → pick the IdPs allowed → add ordered policies (action, Include/Require/Exclude rules, session duration) → add settings (isolate, justification, temporary auth).
- **Key design decisions & trade-offs:** "Require Gateway" is more flexible than "require WARP" because it also accepts RBI and WAN-site on-ramps. It is enforced continuously for self-hosted apps but only at login for SaaS. Short session durations for sensitive apps mean more re-verification. One Access app can cover several endpoints that share a policy (an RDP IP range, or wiki.domain.com plus wiki.domain.co.uk).
- **Blueprints:**
  - **Company wiki:** Policy 1: Secure Employees (group + training + OS posture) with MFA and Gateway get full access. Policy 2: All Employees with MFA get Isolate, paired with a Gateway HTTP isolate policy on the wiki domain when the WARP-check posture fails (copy/paste, transfer, keyboard and print disabled). BYOD gets read-only access.
  - **Salesforce:** An egress policy gives employees a dedicated IP, which Salesforce allowlists. Policy 1: Sales/Execs with MFA, Gateway and CrowdStrike >80. Policy 2: All Employees with the same checks plus justification and temporary authentication.
  - **DB admin tool (no layering):** IT Admins, MFA, Gateway, serial-number list, latest OS, domain-joined. SMS MFA is excluded. Purpose justification is on.
  - **RDP:** Self-hosted hostname option: IT Admins, MFA, Gateway, WARP, serial list, and external evaluation (a Worker that enforces time-of-day). Private IP option: a Gateway network policy on destination IP:3389 for Server Admins with posture checks and a 60 m client session.
- **When to use / not use:** Use whenever you write Access policies. For Gateway SWG policy it only covers the isolation pairing.
- **Source:** https://developers.cloudflare.com/reference-architecture/design-guides/designing-ztna-access-policies/

### 3. Zero Trust for startups (greenfield)
- **Problem:** A startup with nothing to migrate from wants a Zero Trust foundation that scales with growth and compliance (SOC 2, PCI).
- **Components & flow:** Identity and posture as the base, then the client, `cloudflared`, Mesh, Access and Gateway added in stages (see the startup playbook below).
- **Key design decisions & trade-offs:**
  - Two overlay tunnel types: "network" tunnels replace a bastion for admin access, and "application" micro-tunnels reach a single service.
  - Mesh/micro-tunnels reduce lateral movement but mean more agents and per-path policies. Cloudflare recommends a **blend** of traditional and mesh networking.
  - Authorization: apps can consume the Access JWT (identity claims plus an app-specific tag), or use Cloudflare as SSO via Access for SaaS, which makes a later IdP switch easier. Both can be combined, as in the self-hosted Sentry example.
  - "Your definition of a secure endpoint is the new perimeter." Source IP can be a signal, but never the primary control.
- **When to use / not use:** Use for greenfield, cloud-native or remote-first teams. For migration from legacy appliances use pattern 5.
- **Source:** https://developers.cloudflare.com/reference-architecture/design-guides/zero-trust-for-startups/

#### 3a. Third-party access (contractors, vendors, customers)
- **Problem:** People outside your directory need scoped access.
- **Components & flow:** First define what they need, what authentication level and for how long. For web access, use a secondary IdP (theirs, GitHub, or OTP to email) scoped per app, with justification. For network access, give them the client with a dedicated **device profile** and tight split-tunnel routes, to avoid clashes with other agents they run. For customer environments, a `cloudflared` one-way tunnel shipped inside the deployment package, or Mesh for bidirectional needs, instead of site-to-site VPNs.
- **Source:** https://developers.cloudflare.com/reference-architecture/design-guides/zero-trust-for-startups/

### 4. Zero Trust for SaaS
- **Problem:** Backhauling traffic for SaaS IP allowlists is slow. Split tunneling is fast but blind. On top of that come shadow IT, oversharing, misconfiguration and phishing.
- **Components & flow:**
  - Managed SaaS: (1) secure access via dedicated egress IPs and/or Access for SaaS as identity proxy (MFA, posture, country, client-cert check); (2) data in transit via Gateway HTTP (per-group download or file-type limits, DLP); (3) data at rest via API CASB with DLP plus risk scores; (4) config monitoring via CASB (2FA disabled, exposed keys, rogue 3rd-party apps); (5) email via Access for the mailbox, tenant control, inline and/or API email security, outbound DLP with Purview labels.
  - Unmanaged SaaS: shadow-IT discovery, then for each app choose allow, allow with DLP/RBI, adopt as managed, or block (DNS/HTTP). The focus shifts from downloads to **uploads**. After adopting an app, block its consumer or other tenants by domain or tenant-control headers.
- **Key design decisions & trade-offs:** Egress IPs are the simplest option for apps without SSO or already on IP allowlists, and they migrate gradually because old and new IPs can sit in the allowlist in parallel. Access for SaaS gives uniform policy and automatic on/offboarding: a group change in the IdP immediately changes access, which also frees licenses. Even with full SSO, add egress IP allowlists for critical apps, because enforcement is continuous.
- **When to use / not use:** Use for SaaS-heavy organisations and M365/GWS email protection.
- **Source:** https://developers.cloudflare.com/reference-architecture/design-guides/zero-trust-for-saas/

### 5. Network-focused VPN concentrator → ZTNA migration
- **Problem:** Vulnerable VPN hardware (CVEs) needs to go quickly. The network team knows IPsec, not server agents, and change control makes deploying server software slow.
- **Components & flow:** The client replaces the VPN client. Existing DC firewalls terminate Cloudflare WAN IPsec, and `cloudflared` provides internal DNS. Needs Cloudflare One plus Cloudflare WAN licences. Phases are in the playbook below.
- **Key design decisions & trade-offs:** Fast (days, not weeks) and low-risk, and server-initiated traffic keeps flowing over IPsec. But the throughput of the old appliance caps scale, and enforcement is still at the perimeter. Treat phase 1 as a pilot. Anycast removes the "pick a VPN region" step for users.
- **When to use / not use:** Use when an urgent VPN replacement meets a network-centric team. Skip it when app owners can deploy `cloudflared` directly (go straight to tunnels).
- **Source:** https://developers.cloudflare.com/reference-architecture/design-guides/network-vpn-migration/

### 6. Zero Trust implementation guides (index)
- Index of four learning paths (secure internet traffic and SaaS, replace VPN, clientless web access, email security). Use it for step-by-step execution after the design is chosen.
- **Source:** https://developers.cloudflare.com/reference-architecture/implementation-guides/zero-trust/

## Policy design rules

1. **Deny by default.** Access blocks anything that matches no policy, so do not write catch-all Block policies. Use Block only for testing or to short-circuit evaluation (a matching Block placed higher stops all further evaluation).
2. **Order matters.** Policies are evaluated top-down. Put the strictest or most-privileged policy (full access on a trusted device) first and fallbacks (isolated or read-only) below it. Check with the policy tester.
3. **Include = OR, Require = AND, Exclude = NOT (overrides).** Think of a funnel: Include builds the candidate pool, Require narrows it, Exclude removes from it. Every policy needs at least one Include.
4. **Put identity into Access Groups, not individual policies.** Define "Employees", "Secure Employees", "IT Admins", "Contractors" once, nest groups (for example OS-latest + disk-encryption groups inside "Secure Administrators"), and reuse them everywhere. Changing the IdP or a definition then touches one object. Login-method and IdP-group selectors belong in groups.
5. **Use a consistent naming scheme** across apps ("Allow all full-time employees", "Block high-risk users") so access reviews are easy.
6. **Layer MFA strength by sensitivity.** Require MFA via the amr selector. For crown-jewel apps require FIDO2/hardware keys and **Exclude SMS**.
7. **Require Gateway** to guarantee inspected, logged traffic and to blunt phishing and credential theft. Require **WARP** specifically only when a client-connected device is mandatory. For SaaS, back "Gateway" with a dedicated egress IP allowlist, because the Gateway check applies only at login.
8. **Posture by risk tier.** Tier 1 (prod DB, customer PII) needs a corporate device (serial list or client cert), latest OS, domain-joined or EDR score, and strong MFA. Tier 3 can allow BYOD with identity checks only. For "latest OS" posture, define the version the company considers stable, not necessarily the newest release.
9. **Give BYOD a fallback instead of a hard deny:** a lower-priority Allow + Isolate, paired with a Gateway HTTP isolate policy **scoped to the same users/domain**, with controls disabled.
10. **Session duration:** 24h is typical. Use short or immediate expiry for sensitive apps. For private IP apps, enforce the client session duration (for example 60m).
11. **Machine access** uses Service Auth (service tokens or mTLS), never Bypass. Use Bypass only for endpoints that must be fully public.
12. **Use Lists** for contractor emails, managed serials and office IPs, synced by API. Use an Exclude with a high-risk email list to cut off a subset of users.
13. **Justification and temporary authentication** for sensitive or out-of-role access (auditable, with a human approver).
14. **Gateway specifics:** Start with DNS security-category blocks right away. Replace 5-tuple ACLs with identity-based network policies. Put DLP in HTTP policies (block is the usual action) with match counts and context analysis. For unmanaged SaaS focus on uploads, for managed SaaS on downloads. Isolate high-risk categories (for example social media) with download and copy/paste restrictions.
15. **Egress policies** should assign dedicated IPs only when the IdP group and posture match. Non-compliant devices silently lose SaaS access but keep internet access.

## Migration & rollout playbooks

### VPN concentrators → ZTNA (network-focused, 3 phases)
- **Phase 1 – Connectivity and network policies (pilot, days):**
  1. Integrate the IdP. Set device enrollment policies, device profiles and managed networks.
  2. Roll out the client in place of the VPN client. Prefer sending internet traffic through Gateway, but split-tunnel bandwidth-heavy traffic (video calls) if needed.
  3. Build Cloudflare WAN IPsec tunnels from existing DC firewalls or routers with static routes. Add a route for **100.96.0.0/12** at each DC for return traffic.
  4. Deploy `cloudflared` on dedicated, automated hosts (Docker/VMware + Ansible/Terraform/K8s, 2+ replicas, Prometheus/Grafana). Point resolver policies for internal domains at the internal DNS through the tunnel.
  5. Turn on DNS security policies and identity- and posture-based network policies.
  6. Set up logging: Network Analytics (sampled), network session logs, Gateway activity logs, Logpush to SIEM, and Notifications for tunnel health. Use them to map application traffic.
- **Phase 2 – Scale and offload IPsec (ongoing):** Pick heavy apps that do not depend on server-initiated traffic. Deploy 2+ `cloudflared` in that DC and advertise more specific routes (/24 via the tunnel versus /16 via IPsec). Longest-prefix match moves the traffic off IPsec. Once a DC is fully covered (for example its whole /16 is on `cloudflared`), decommission the IPsec tunnel and its hardware.
- **Phase 3 – Application-based policies:** Give each app or segment its own connector and firewall off the segment so the connector is the only way in (outbound internet access is the only requirement). Restrict access to specific ports and protocols (HTTPS only, not SSH). Add public hostnames for clientless access by contractors and partners (HTTP, browser SSH/VNC) with Access policies. One-to-one connector per app is optional; several connectors can serve one network.

### Startup greenfield rollout
1. Take an asset inventory: VPCs, public IPs/SSH, how users reach each service. Use Private Network Discovery if the estate is already large.
2. Risk-tier every service (L1 to L3) and set goals, including 6-month goals (for example restricting BYOD to L3 apps).
3. Pick one IdP as the source of truth. Enforce phishing-resistant MFA from day one. Plan for third-party identities (GitHub, OTP, partner IdPs).
4. Define the posture strategy (MDM, corp cert, EDR) and deploy the client.
5. Remove public ingress. Publish internal tools through `cloudflared` + Access. Add network routes for admin access. Use Mesh where flows are bidirectional.
6. Handle authorization with the Access JWT or Access for SaaS as SSO.
7. Turn on Gateway DNS filtering **early** (it gets harder as the fleet grows). Add HTTP, TLS decryption and DLP later, after reading the TLS guidance.
8. Put sanctioned SaaS behind Access for SaaS. Connect CASB. Run shadow-IT discovery and decide per app.
9. Manage everything via Terraform/API from the start.

## Decision hints

- **If** remote users need private web apps and app owners can run software → prefer **`cloudflared` + Access self-hosted** over Cloudflare WAN, because it is simpler, granular per app, portable, scales by adding replicas, and blocks lateral movement.
- **If** you must kill a vulnerable VPN this week and the team is network-centric → prefer **Cloudflare WAN IPsec from existing firewalls + client** over a tunnel-first rollout, then move to `cloudflared` in phases.
- **If** servers initiate connections to users or other sites (AD, SCCM, VoIP/SIP, CI/CD) → prefer **Cloudflare Mesh** over `cloudflared`, because `cloudflared` is inbound-only. Use WAN if you do not need inbound source-IP fidelity.
- **If** you need whole-site routing or branch firewall/SWG replacement → prefer **Cloudflare WAN** (One Appliance for small sites, 3rd-party IPsec for others, CNI in colo) over agents.
- **If** site traffic is already TLS or IPsec throughput is the bottleneck → prefer **GRE** over IPsec on-ramps.
- **If** users are contractors or on BYOD without the client → prefer **clientless Access (public hostname) + RBI isolation** over requiring the client. You lose posture but keep identity and data controls.
- **If** the app is non-HTTP (RDP, DB, thick client) → you need a **private IP app + client**. Otherwise use **browser-rendered SSH/VNC** or **RBI with private DNS** for agentless access.
- **If** the policy must use device posture → the **client** (or a 3rd-party posture integration matched by email) is required. PAC, DNS and WAN on-ramps carry no posture, and PAC, DNS and WAN also carry no identity.
- **If** a SaaS app lacks SSO or already uses IP allowlists → prefer **dedicated egress IPs + egress policies** over Access for SaaS.
- **If** you want uniform policy and automatic on/offboarding across SaaS and self-hosted apps → prefer **Access for SaaS (Cloudflare as IdP proxy)** over per-app IdP SSO. It also reduces IdP lock-in and supports several IdPs.
- **If** the SaaS app is critical → use **both** Access for SaaS and an egress IP allowlist, because the Gateway requirement is checked only at login while egress enforcement is continuous.
- **If** internal tools need authorization without building OAuth → **validate the Access JWT** in the app. If the tool ships an SSO connector → use **Access for SaaS** as its IdP.
- **If** the concern is data at rest or SaaS misconfiguration → **API CASB (+DLP)**. For data in transit → **Gateway HTTP + DLP** (needs TLS inspection).
- **If** email protection must quarantine or modify messages → **inline MX** mode. If mail flow cannot change → **API** mode (retract only). Best is both, for post-delivery retraction.
- **If** a site cannot run agents and only DNS control is feasible → use **DNS locations with DoH** (preferred over DoT). Add a service token to get identity.
- **If** private CIDRs overlap across networks → **Mesh CGNAT overlay** (docs), or virtual networks (general knowledge).
- **If** an app needs strict isolation or compliance → run **`cloudflared` on the same host** (per-app tunnel) rather than on a shared connector host.
- **If** under 50 users → many Cloudflare One capabilities are free (per SASE RA).


Full document list with URLs: see catalog.md.
