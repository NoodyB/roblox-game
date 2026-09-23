---
tags: [concept, decision]
date: 2026-09-23
status: decided
---
# Concept selection

Inputs: [[Market Research 2026-09]]. Constraints for this studio: a single AI-assisted developer, no paid asset pipeline, everything built from code and Roblox primitives, and no in-Studio playtesting during the first build.

## Concept A: **Sweep Squad**, a co-op cleaning incremental (SELECTED)

| Field | Detail |
|---|---|
| Genre | Casual co-op incremental / simulator |
| Audience | 8-16, mobile-heavy, plays with friends |
| Core loop | Walk into debris to vacuum it up → bag fills → sell at the Compost Bin → buy better vacuums, bags and boots → unlock the next themed zone → rebirth for permanent multipliers |
| USP | (1) **Real co-op:** each zone has a server-wide "Clean %" goal. Clearing it triggers a Golden Gust bonus wave for everyone who helped, plus a squad bonus for cleaning near other players. (2) **Collectible Critters** found in debris. Free drops only, with odds displayed and no paid gacha. (3) A polished, pop-up-free UI, in contrast to the "slop" incrementals |
| Progression | 8 themed zones (Backyard → Moon Base), about 10 tiers each of Vacuums, Bags and Boots, 24 Critters with Golden versions, rebirths plus a permanent perk tree |
| Retention | Daily quests, daily streak reward, zone-clear co-op events, critter collection book, rebirth goals, global leaderboards |
| Monetization | Passes: VIP, 2x Coins, Auto-Sell, +2 Critter Slots. Products: scaled coin packs, 30-minute boosts, a server-wide Golden Storm. Creator Rewards from 10+ minute sessions |
| Dev difficulty | **Low-medium.** Primitives fit the art style, and systems are standard simulator systems |
| Dev cost | $0 in assets. All code and procedural geometry |
| Maintenance | Low. Content updates are data-driven (add a zone, critters or tiers in config) |
| Mobile/PC | Ideal: the only required input is movement. Collection is automatic |
| Technical needs | Grid-based debris with server authority and compact buffer replication, DataStore sessions, receipt processing |
| Competitive risk | **High clone density** in "cleaning" games this month. Mitigated by co-op depth, a long zone path and quality |
| Expansion | New zones and debris types, seasonal events (Halloween, Winter), trading of critters, cosmetics for vacuums |

## Concept B: **Egg Vault**, a steal-and-defend collection tycoon

| Field | Detail |
|---|---|
| Loop | Hatch and collect creatures on a base plot, steal from other players' bases, defend your own |
| Evidence | #1 chart game (Steal An Egg, about 1.87M CCU), following the Steal a Brainrot trend |
| Dev difficulty | **High.** Needs dozens of appealing creature models, PvP netcode for theft, base defense and anti-grief systems |
| Risks | The genre leader was **pulled by Roblox in Aug 2026**. PvP theft attracts toxicity reports. Heavy dependence on creature art. The market is very crowded with direct clones |
| Verdict | Rejected: highest demand, but also the highest art, policy and moderation risk for a small team |

## Concept C: **+1 Glide Escape**, an incremental obby

| Field | Detail |
|---|---|
| Loop | A stat grows every second → go further along an obby course → rebirth |
| Evidence | Several of the top 50 games (Keyboard, Monkey, Superhero variants) |
| Dev difficulty | **Low** |
| Risks | Developers publicly call the format oversaturated. A published example shows D1 of about 4.6% and 8.9 min playtime. Shallow loops hurt 28-day signals. There is little room to differentiate |
| Verdict | Rejected: cheap, but weak long-term retention, and it is the most commoditized option |

## Scoring

Scores are 1-5, where 5 is best. For risk rows, higher means lower risk.

| Criterion (weight) | A Sweep Squad | B Egg Vault | C +1 Escape |
|---|---|---|---|
| Player demand (3) | 4 | 5 | 4 |
| Saturation, inverse (2) | 3 | 2 | 1 |
| Build feasibility for us (3) | 5 | 2 | 5 |
| Maintenance cost (1) | 4 | 2 | 4 |
| Long-term retention potential (3) | 4 | 4 | 2 |
| Monetization fit (2) | 4 | 5 | 3 |
| Mobile fit (2) | 5 | 3 | 4 |
| Policy/moderation safety (2) | 5 | 2 | 4 |
| Expansion (1) | 5 | 4 | 3 |
| **Weighted total (max 95)** | **82** | **63** | **64** |

## Decision

**Build Sweep Squad as one well-made game on a reusable framework.** Research does not support shipping many small games. Distribution is driven by per-game long-term retention, so one strong game compounds and many weak ones do not. The code is structured so that DataService, Monetization, UI kit, Net and the test harness can be reused for a second game once this one has real metrics.

Title for the store listing (A/B test later): **"🍂 Sweep Squad: Clean Up Everything!"**
