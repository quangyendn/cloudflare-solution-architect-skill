# <System name> — Cloudflare Solution Architecture

## 0. Open questions
<questions whose answers would change the architecture; if unanswered, each maps to an assumption below>

## 1. Context & requirements
- **Problem:** <one paragraph>
- **Functional requirements:** <bullets>
- **Non-functional requirements:** scale (users, RPS, data volume), latency, availability (SLA, RPO/RTO), security, compliance/residency, budget, team size & skills
- **Constraints:** <existing systems that cannot move, contracts, plan tier>
- **Assumptions:** <every assumption made instead of asking — each one is a question for the stakeholder>

## 2. Solution overview
<3–5 sentences: the shape of the solution and why>

```mermaid
flowchart LR
  %% one diagram showing users, Cloudflare edge services, compute, data stores, external systems
```

## 3. Request / data flows
1. <numbered steps for each critical flow: read path, write path, async/background path, admin path>

## 4. Component choices
| Component | Cloudflare product | Why this (vs. alternative) | Plan / availability | Key limits to respect |
|---|---|---|---|---|

## 5. Security design
<edge protection, origin lockdown, identity & access, tenant isolation, secrets, data protection>

## 6. Reliability, performance & operations
<failover, backups/RPO-RTO, caching, observability, IaC>

## 7. Compliance & data residency
<per data class: where processed, where stored, where logged>

## 8. Cost estimate
| Component | Driver | Estimate / month | Notes |
|---|---|---|---|
_All figures are estimates; verify on current Cloudflare pricing pages._

## 9. Trade-offs, risks & open decisions
| # | Decision / risk | Options | Recommendation | Owner |
|---|---|---|---|---|

## 10. Rollout plan
<phases, each with scope, exit criteria, rollback>

## 11. References
<links to the Cloudflare reference architectures and product docs this design is based on>
