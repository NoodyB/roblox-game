---
tags: [research, market, roblox]
date: 2026-09-23
status: complete (initial pass)
---
# Roblox market research: September 2026

This is a working snapshot collected on **2026-09-23** from public web sources. Concurrent-player (CCU) counts change hourly. Treat them as one reading, not as trends. Each claim below is marked **[V]** for verified from a primary or official source, **[R]** for reported by a third-party tracker or press, or **[A]** for our own assumption or inference.

## 1. What is being played right now

The rblxdb "Most Played" chart gave one hourly reading on 2026-09-23 **[R]**. See [rblxdb.com/charts/most-played](https://rblxdb.com/charts/most-played).

| # | Game | CCU | Notes |
|---|---|---|---|
| 1 | Steal An Egg | 1,868,988 | Created 2026-07-25 (Rolimon's). "Steal-and-defend" plus pet collection. Briefly pulled by Roblox in Aug 2026 over a progression feature described as too addictive (Polygon, LinkedIn posts) **[R]** |
| 2 | Brookhaven RP | 437,930 | Social roleplay, evergreen |
| 3 | Blox Fruits | 347,538 | Anime RPG, large studio |
| 4 | +1 Speed Keyboard Escape | 266,870 | "+1 stat per second" incremental obby |
| 5 | Murder Mystery 2 | 255,887 | Evergreen social deduction |
| 6 | RIVALS | 234,039 | Competitive FPS |
| 7 | 99 Nights in the Forest | 224,802 | Co-op survival horror |
| 9 | Fish It! | 113,689 | Fishing collection |
| 13 | Animal Hospital | 73,844 | Casual management |
| 14 | Jump for Animals! | 68,680 | Incremental |
| 16 | **Clean all the Leaves** | 67,475 | **Co-op cleaning incremental, ~1 month old** |
| 19 | Fisch | 60,685 | Fishing |
| 23 | +1 Speed Monkey Escape | 48,793 | Incremental obby |
| 36 | Grow a Garden | 31,569 | Idle-grow, far below its 2025 peak |
| 41 | +1 Cut Grass Adventure | 27,788 | Cleaning/mowing incremental |
| 42 | Kick a Lucky Block | 27,752 | Incremental |
| 43 | Greedy Growers | 26,896 | Idle-grow |
| 50 | +1 Superhero Evolution | 24,371 | Incremental |

The "People also join" list for Clean all the Leaves shows a cluster of cleaning games **[R]**: Wash The House, Dig & Clean (28.2K), +1 Cut Grass Adventure, and Clean the WORLD! [PRESTIGE!]. Source: [roblox.com game page](https://www.roblox.com/games/92637789841354/Clean-all-the-Leaves).

### Clean all the Leaves: closest reference game

- Developer: Muffin Interactive, a community group. Created about 1 month before 2026-09-23. **198M+ visits.** 12-player servers. Source: [Rolimon's](https://www.rolimons.com/game/92637789841354). **[R]**
- Loop: clean leaves in time → buy and upgrade tools → unlock new map areas → reach 100% for a "secret ending". Co-op with friends, with a light story hook.
- Monetization visible on Rolimon's: VIP pass at 50 R$ and an "L33FBOT" helper-robot pass at 599 R$ **[R]**. Revenue figures are **not public**, and we do not estimate them.

## 2. Genre patterns in 2025-2026

- Third-party genre write-ups name the fastest-growing categories as steal-and-defend tycoons, idle-grow simulators, co-op horror, anime fighters and fashion social games **[R]**. Source: [kitsblox](https://kitsblox.com/blog/popular-roblox-game-genres-2026).
- Tycoons in 2026 borrow from idle games, factory builders and prestige systems. That write-up quotes "~38% avg. day-7 retention for prestige tycoons" **[R, unverified methodology, do not rely on it]**. Source: [endsights.com](https://endsights.com/roblox-tycoon-games).
- **Incremental "+1" games dominate the new-release charts, but developers call the format oversaturated.** One developer published their own numbers for "+1 Speed Minecart Escape": 8.9 min average playtime, D1 retention ~4.6%, conversion 0.44% **[R, self-reported]**. Replies criticized low-quality "engagement slop", too many pop-ups and poor UI. Source: [DevForum](https://devforum.roblox.com/t/looking-for-honest-feedback-to-improve-the-d1-retention-and-avg-playtime-of-my-game/4620762).
- The chart-toppers share **a one-sentence premise readable from the title** ("Clean all the Leaves", "Kick a Lucky Block", "Steal an Egg"), plus co-op or social play and short, satisfying feedback loops **[A, from the chart above]**.

## 3. How Roblox discovery works now

From the Roblox Creator Hub Discovery docs and the June 2026 DevForum announcement **[V]**:
- Recommended For You has two stages, Retrieval then Ranking. Ranking uses **only** the behaviour of users who arrived through Recommended For You. Ad, search and friend traffic can *seed* consideration but do not count in ranking.
- Most important signals: **play-through rate**, **play days per user** (D1, D2-7 and D8-28), **playtime per user** (capped at 60 min/day), and **qualified play sessions**.
- June 2026 change: the retention window grew from 7 to 28 days. Intentional co-play days, spend days and Robux spend are secondary signals. QPTR was replaced by PTR plus a first-play bounce rate.
- **Implication [A]:** games that keep players returning for weeks now get more distribution than games that spike and die. A good first 60 seconds (low bounce), strong D2-D28 reasons to return, and intentional co-play are directly rewarded.

Sources: [create.roblox.com/docs/discovery](https://create.roblox.com/docs/discovery), [DevForum: RFY improvements](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575).

## 4. Monetization rules and economics

- **Marketplace fee:** creators receive **70%** of Robux spent on passes and developer products; Roblox keeps 30% **[V]**. Source: [Creator Hub: How do I make money?](https://create.roblox.com/docs/get-started/monetization)
- **DevEx:** $0.0038 per earned Robux at the standard rate, effective 2025-09-05 (previously $0.0035). An enhanced **$0.0054** rate applies to eligible spend from age-verified US 18+ users, effective 2026-06-08 **[V]**. Source: [Creator Hub: DevEx](https://create.roblox.com/docs/production/monetization/developer-exchange)
- **Creator Rewards:** replaced Premium Payouts on 2025-07-24. It pays **5 Robux per qualified user per day**. A user qualifies when the game is one of the first three they visit that day and they spend at least 10 minutes in it **[R, multiple consistent sources]**. Source: [Creator Hub: Creator Rewards](https://create.roblox.com/docs/creator-rewards). **Implication [A]:** a game that reliably holds players for more than 10 minutes earns from free players too.
- **Paid random items** (loot boxes paid with Robux or with currency bought with Robux) are "highly regulated". Roblox requires displayed odds summing to 100%. Updates in May 2026 aligned the rules globally with South Korean law, and paid random items are legally prohibited for some users **[V]**. Source: [Creator Hub: paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items). **Decision:** Sweep Squad sells **no randomized items for Robux**. Random critter drops come only from free gameplay, and their odds are shown in-game anyway.
- **Ads:** Sponsored Experiences charge per play. DevForum reports say search-sponsor placements got much better click-through and play rates than generic sponsors, and ad-acquired players show 20-30% weaker stats than organic ones **[R, anecdotal]**. Source: [DevForum ads thread](https://devforum.roblox.com/t/should-i-use-sponsored-experiences-or-search-experiences-for-advertising/3264428).

## 5. Risks observed in the market

- **Policy risk:** Steal An Egg reached #1 and was then pulled over an addictive progression mechanic **[R]**. We avoid manipulative loops, fake timers and "watch to progress" mechanics.
- **Trend decay:** Grow a Garden fell from multi-million CCU in 2025 to about 31K **[R]**. Trends burn out, so long-term retention (the 28-day signals) is the defence.
- **Clone saturation:** every hit spawns dozens of copies within weeks. A copy with no differentiation competes for "leftovers" (DevForum reply).

## 6. Where a small AI-assisted team can compete (conclusion)

1. **Cheap-to-build, highly readable casual loops.** Cleaning, collecting and incremental games need no large art pipeline. Primitive-built stylized worlds look intentional.
2. **Quality gap:** many chart incrementals are criticized for pop-up spam, ugly UI and shallow loops. A polished, fair and genuinely co-op version stands out on play-through rate and retention.
3. **Long-term structure is rewarded:** zones, prestige, collection, daily quests and co-op events map directly onto the D2-7 and D8-28 play-days signals.
4. **Avoid regulated or controversial mechanics** (paid gacha, PvP stealing). They add compliance and moderation risk that a small team cannot absorb.

See [[Concept Selection]] for how these findings became the chosen game.
