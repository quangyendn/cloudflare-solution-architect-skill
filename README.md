# cloudflare-solution-architect

An agent skill for Claude Code that turns a business/technical problem into a Cloudflare architecture, grounded in the official [Cloudflare Reference Architectures](https://developers.cloudflare.com/reference-architecture/) (all 75 documents distilled, synced 2026-09-29).

It covers:
- **Developer Platform**: Workers, Durable Objects, D1, KV, R2, Queues, Workflows, Hyperdrive, Containers, AI Gateway, Workers AI, Vectorize, AI Search, Workers for Platforms
- **Application performance & SaaS**: CDN, tiered cache, load balancing, Cloudflare for SaaS
- **Application & data security**: WAF, bots, API Shield, AI Security for Apps, data protection, FIPS
- **SASE / Zero Trust**: Access, Gateway, Tunnel, Mesh, DLP/CASB, email security, VPN migration
- **Network services**: Magic Transit, Cloudflare WAN, BYOIP, CNI

## What the skill does
1. Captures requirements, and asks the questions that would change the architecture
2. Routes the problem to the right reference patterns
3. Picks products using documented decision rules
4. Verifies volatile facts (limits, pricing, plan tiers, residency) against live docs
5. Reviews the design against a security, reliability, performance, cost, ops and compliance checklist
6. Delivers a design doc: Mermaid diagram, component table, cost estimate, risks, phased rollout, references

## Install

As a Claude Code plugin:

```
/plugin marketplace add quangyendn/cloudflare-solution-architect-skill
/plugin install cloudflare-solution-architect@cloudflare-solution-architect-skill
```

Or as a personal skill:

```bash
git clone git@github.com:quangyendn/cloudflare-solution-architect-skill.git
ln -s "$PWD/cloudflare-solution-architect-skill/skills/cloudflare-solution-architect" ~/.claude/skills/cloudflare-solution-architect
```

Pick one method. Installing both loads the skill twice.

It works best together with the official Cloudflare plugin (`/plugin install cloudflare@cloudflare`). The official plugin provides the docs MCP server this skill uses to verify facts.

## Layout
```
skills/cloudflare-solution-architect/
  SKILL.md                      workflow, routing table, core decision rules, common mistakes
  references/                   distilled reference architectures by solution area
    volatile-facts.md           what to verify and where (limits, pricing, plans, residency)
    review-checklist.md         design review checklist
    catalog.md                  all source documents with URLs
  assets/design-doc-template.md deliverable template
  scripts/check_new_docs.sh     detects Reference Architecture pages added or removed upstream
```

## Keeping it current

```bash
bash skills/cloudflare-solution-architect/scripts/check_new_docs.sh
```

Fold any new pages into the matching reference file and `catalog.md`, then bump `version` in `.claude-plugin/plugin.json`.

## Attribution
Content is a paraphrased distillation of Cloudflare's public documentation. Cloudflare product names are trademarks of Cloudflare, Inc. This project is not affiliated with Cloudflare.
