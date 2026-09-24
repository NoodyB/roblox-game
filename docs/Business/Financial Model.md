---
tags: [finance, model]
updated: 2026-09-24
status: pre-launch estimates (no real data yet)
---
# Financial model: Sweep Squad

> **Every revenue figure here is a scenario estimate built on the assumptions below. None of it is a forecast or guarantee.** Replace the assumptions with Creator Analytics data after launch. Verified platform facts are marked [V]. Our assumptions are marked [A].

## Platform economics
| Item | Value | Source |
|---|---|---|
| Creator share of pass and product sales | 70% (30% marketplace fee) | [V] Creator Hub |
| DevEx rate, standard | $0.0038 per earned Robux | [V] Creator Hub (since 2025-09-05) |
| DevEx rate, eligible US 18+ spend | $0.0054 per earned Robux | [V] since 2026-06-08 (not used below, which keeps the model conservative) |
| DevEx minimum cash-out | 30,000 earned Robux (about $114) | [V] |
| Creator Rewards | 5 R$ per qualified user per day | [R] multiple consistent sources |
| Hosting, servers and storage | $0 (Roblox provides them) | [V] |

## Costs
| Cost | Amount | Notes |
|---|---|---|
| Development (this build) | $0 cash | Built with promotional Claude Code credits; the owner's time is not counted |
| Assets | $0 | All primitives. Optional licensed music or icons cost $0-50 |
| Publishing | $0 | |
| Advertising | $0 until approved | Suggested test: $10-20/day for 5-7 days, **only after** retention gates are met (see [[Marketing & Launch Plan]]) |
| Ongoing | Owner time for updates and moderation | No cash infrastructure cost |

## Assumptions per scenario [A]
| Assumption | Conservative | Moderate | Optimistic |
|---|---|---|---|
| Average CCU, 24h mean (not peak) | 15 | 250 | 3,000 |
| Average play minutes per DAU per day | 25 | 25 | 25 |
| DAU ≈ CCU × 1440 / minutes | 864 | 14,400 | 172,800 |
| Share of DAU qualifying for Creator Rewards | 25% | 35% | 45% |
| Gross Robux spend per DAU per day (ARPDAU) | 0.5 R$ | 1.5 R$ | 3.0 R$ |

Why these ARPDAU values: this is a young, mobile-heavy audience with a non-gacha catalogue, so we deliberately assume modest spending. The only public data point we found for a comparable incremental game was a self-reported **0.44% conversion** (see [[Market Research 2026-09]]). That supports keeping these low.

## Monthly results (30 days)
| | Conservative | Moderate | Optimistic |
|---|---|---|---|
| Gross Robux from purchases | 12,960 | 648,000 | 15,552,000 |
| Creator share (70%) | 9,072 | 453,600 | 10,886,400 |
| Creator Rewards | 32,400 | 756,000 | 11,664,000 |
| **Earned Robux per month** | **41,472** | **1,209,600** | **22,550,400** |
| **DevEx value at $0.0038** | **≈ $158** | **≈ $4,596** | **≈ $85,700** |
| Minus ad spend (if the $10/day test runs for 7 days) | −$70 once | −$70 once | −$70 once |

## Break-even
- There is no cash investment, so any DevEx-eligible month is operating profit, apart from optional ad tests.
- If the $100 promotional credit is counted as notional cost, break-even takes about **26,300 net earned Robux** (≈ $100 / 0.0038). The conservative scenario passes that in its first month.
- An ad test at $10/day for 7 days ($70) pays back in the moderate scenario within about 1 day. In the conservative scenario it takes about 2 weeks, which is exactly why ads wait for retention data.

## What drives the outcome (sensitivity)
1. **CCU / DAU.** This is set almost entirely by Recommended For You distribution, which depends on D1, D2-7 and D8-28 play days, playtime, and first-play bounce. Moving from 15 to 250 CCU is a 17x revenue change; nothing else comes close.
2. **Creator Rewards qualification share.** Sessions must reach 10+ minutes. The tutorial and zone pacing aim for a first session of 15-25 minutes.
3. **ARPDAU.** A secondary lever, tuned with prices and bundles later.

## Metrics to collect after launch (Creator Analytics)
DAU, MAU, D1/D7/D30 retention, average session length, playtime per DAU, payer conversion, ARPDAU, ARPPU, spend days, Creator Rewards earned, and ad CTR and cost per play (only if ads run). The onboarding funnel events are already logged with `AnalyticsService` (Joined → FirstCollect → FirstSell → FirstUpgrade → UnlockedZone2 → FirstCritter → FirstQuestClaim → FirstRebirth).

## Decision gates
| Gate | Metric (first 14 days) | Action |
|---|---|---|
| Keep iterating | D1 < 15% or average session < 8 minutes | Fix onboarding and the first 10 minutes before spending anything |
| Small ad test (needs approval) | D1 ≥ 20% and D7 ≥ 7% | $10-20/day for 5-7 days on search sponsors |
| Scale content and ads | D7 ≥ 10% and growing organic RFY impressions | Seasonal event, new zone, larger campaigns |
