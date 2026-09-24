---
tags: [gdd, sweep-squad]
status: v0.1 implemented (not yet Studio-playtested)
updated: 2026-09-24
---
# Sweep Squad: Game Design Document

## 1. Overview
- **Pitch:** "Vacuum up everything, together." A cozy co-op cleaning incremental. Every zone is a big field of debris that the whole server cleans at once. A full clear triggers a Golden Gust that pays everyone.
- **Genre:** casual simulator / incremental with light co-op.
- **Audience:** ages 8-16, mobile-first, playing solo or with friends. Sessions are 10-30 minutes.
- **Platforms:** phone, tablet and PC at launch. Gamepad works for movement; menus are pointer-first.
- **Why it can win:** it rides a proven, currently hot loop (see [[Market Research 2026-09]]). It differentiates with real co-op payoffs, a long zone path, collectible critters with shown odds, and polish without pop-up spam.

## 2. Core loop (seconds to minutes)
1. **Walk into debris.** The vacuum pulls in every cell within reach, automatically. There's no button to hold, which suits mobile.
2. The **bag fills**, shown in the HUD meter and on the character's backpack model, which swells.
3. **Walk onto a 💰 SELL pad.** Every zone has two. The bag converts to coins at the current multiplier.
4. **Buy an upgrade.** The Vacuum (reach and power), Bag (capacity) and Boots (speed) tracks each have 8-12 tiers.
5. **Unlock the next zone** at its gate. Its debris is worth about 3.5x more.

## 3. Mid and long loops
- **Critters (collection, minutes to weeks).** 24 species, 3 per zone, from Common to Mythic. They are found randomly while cleaning, for free, and the odds appear in the Critter Book. Each gives a bonus: coins %, reach, bag size %, walk speed, or critter luck. Equip 3 (up to 6 with passes). Five duplicates merge into a Golden critter worth 2.5x the bonus. Pity rules guarantee a first critter within about 24 seconds of collecting, and one at least every 900 collecting ticks.
- **Zone waves (co-op, minutes).** Every zone shows a server-wide "% clean" bar. At 97%, every contributor gets 50% of what they contributed as a bonus. The zone then refills. Waves alternate normal → Golden (x3 value) → normal.
- **Squad bonus.** +10% value per other player within 40 studs in the same zone, up to +30%. This rewards cleaning side by side and feeds the "intentional co-play days" discovery signal.
- **Rebirth (hours).** It resets coins, tiers and zones, and keeps critters, perks, passes and stats. Each rebirth grants +50% permanent coins and 1 Rebirth Token, with +1 bonus token every 5th rebirth. Cost starts at 5M and grows 2.6x per rebirth.
- **Perks (tokens).** Golden Touch (+5% coins per level, 20 levels), Deep Pockets (+10% bag), Quick Feet (+1 speed), Critter Whisperer (+10% luck), and Head Start (keep +1 vacuum and bag tier per level after rebirth).
- **Daily systems.** Three daily quests (collect, sell, earn, find a critter, help clear, golden debris, play minutes, upgrade) reset at 00:00 UTC and are generated deterministically per player per day. After the first rebirth, finishing all three earns a Rebirth Token. A 7-day login streak escalates rewards, and day 7 adds 15 minutes of 2x Coins.
- **Leaderboards.** Global boards in the hub: top cleaners by lifetime debris, and top rebirths.
- **Seasonal events** (`Config/Events.luau`). **Haunted Hollow** runs 2026-10-01 to 11-04 UTC. 20% of critter finds become one of 3 free event critters: Candy Bat, Ghost Pup and Jack-o'-Kitten. Backyard Lane gets a purple and orange palette, jack-o'-lanterns ring the hub, and the Critter Book shows the event odds.
- **Promo codes** (`Config/Codes.luau`). Each code is redeemable once per player in Settings, for coins, boosts or a critter. They power creator videos and social posts (`SWEEPSQUAD`, `LAUNCH`, `SQUIRREL`).
- **Social:** an "👋 Invite" button (Roblox invite prompt), a live "👥 Squad +X%" chip when teammates are close, and `[VIP]` / `[♻️N]` chat tags.

## 4. World
| # | Zone | Debris | Coins/unit | Unlock | Signature props |
|---|---|---|---|---|---|
| 0 | Maple Hollow (hub) | none | none | none | Fountain, 5 shop buildings, leaderboards |
| 1 | 🍂 Backyard Lane | Leaves | 1 | Free | Autumn trees, benches, lamps, houses |
| 2 | 🎃 Pumpkin Patch Park | Acorns & Leaves | 3 | 1.5K | Pumpkins, hay bales, scarecrows, barn |
| 3 | 🌲 Pinecone Forest | Pinecones | 10 | 30K | Pines, stumps, mushrooms, cabin |
| 4 | 🏖️ Sunny Shores | Seaweed & Shells | 35 | 450K | Palms, umbrellas, sandcastles, huts |
| 5 | ❄️ Frosty Peaks | Snow | 120 | 8M | Snowy pines, snowmen, ice, igloo |
| 6 | 🍭 Candy Canyon | Sprinkles | 450 | 120M | Lollipops, candy canes, gumdrops |
| 7 | 🌋 Volcano Vents | Ash | 1.7K | 1.5B | Lava rocks, smoking vents, volcano |
| 8 | 🌙 Moon Base | Stardust | 6.5K | 12B | Moon rocks, antennae, rockets, dome |

Layout: the hub sits at X=0. Zone *k* is centred at X = 200·k, and each is a 150×150 walled yard with a 132×132 debris field of 22×22 cells, 6 studs each. Corridors join the zones. Gates are per-player: they are invisible and passable only for players who unlocked them, and the server enforces access. The **Travel** menu teleports to any unlocked zone.

## 5. Economy
The numbers live in `src/shared/Config/*`. Pacing is checked with `tools/simulate_economy.luau`; see [[Economy Balance]]. Free-player model targets: zone 2 in about 5 minutes, zone 3 in about 15, zone 4 in about 45, the first rebirth in about 1.5-2 hours, and zones 7-8 as multi-week goals.

## 6. Monetization (summary; details in [[Monetization]])
- **Passes:** VIP (+20% coins, chat tag, +1 critter slot), 2x Coins, Auto Sell, +2 Critter Slots.
- **Products:** coin packs sized to 3, 12 or 40 bags of the player's best zone; 30-minute 2x Coins and Super Suction boosts that tick down only during play; Golden Storm (2x coins for the whole server for 5 minutes, crediting the buyer).
- Nothing randomized is sold. Everything can be earned free. The store says so.

## 7. UI and UX
- **HUD:** coins pill and bag meter at top centre, zone cleanliness bar with a Golden badge, storm banner, boost chips at bottom centre, and a left column of big menu buttons with notification badges.
- **Windows:** Shop, Critters (with 3D previews), Quests and streak, Rebirth and perks, Travel, Store, Settings. One opens at a time over a dimmed backdrop.
- **Onboarding:** a four-step tutorial (collect → sell → upgrade → unlock zone 2) with a glowing guide beam to the next objective. The server advances it from real events.
- **Feedback:** debris flies into the vacuum, a coin burst plus "+X" on sell, a 3D spinning pop-up for critter finds, and confetti banners for unlocks, clears, rebirths and storms.
- **Accessibility:** chunky text with outlines, high contrast, and no required keyboard input. Low Graphics mode halves the debris parts.

## 8. Visual direction
Cozy "autumn candy" low-poly: saturated primitive shapes, SmoothPlastic, Grass, Sand and Snow materials, warm ShadowMap lighting with atmosphere, bloom and colour correction. The atmosphere shifts to each zone's palette as the player enters. Critters are round and big-eyed. No external meshes or textures are needed.

## 9. Audio
Built-in `rbxasset://sounds/*` effects need no upload. Collect sounds are throttled and pitch-randomized. Music is off until a licensed track ID is added (see [[Assets & Audio]]).

## 10. Controls
- **Mobile:** thumbstick to move and jump button (Roblox default). All menus are on-screen buttons at least 44pt tall. Collection is automatic.
- **PC:** WASD and mouse, plus hotkeys B (Shop), C (Critters), Q (Quests), R (Rebirth), T (Travel) and G (Store). E interacts with prompts.
- **Gamepad:** movement, prompts, and B closes windows.

## 11. Technical summary (details in [[Technical Architecture]])
The server simulates everything at 5 Hz. Debris lives as a byte buffer per zone. Deltas replicate as 4-byte entries every 0.1 s. Profiles are session-locked in DataStores. Receipts are idempotent. Remotes are rate-limited.

## 12. MVP acceptance criteria
| Criterion | Status |
|---|---|
| Core loop (collect → sell → upgrade → unlock) implemented server-side | ✅ Unit and integration tested offline |
| 8 zones generated with gates, sell pads and props | ✅ Map build validated against the Roblox API (1,556 parts) |
| Persistence with session locking, autosave and shutdown save | ✅ Tested against mocks |
| Critters: drops, equip, golden merge, followers, book with odds | ✅ Tested offline |
| Quests, streak, rebirth, perks, leaderboards | ✅ Tested offline (leaderboards untested) |
| Mobile and PC UI for every system | ✅ Built in the validating test environment (2,325 instances) |
| Monetization infrastructure (passes, products, receipts) | ✅ Tested against mocks; product IDs pending |
| Playable end to end in Roblox Studio | ⏳ Needs a local Studio session ([[Studio Setup & Playtest Guide]]) |
| 60 FPS on mid-range phones | ⏳ Needs device testing |

## 13. Expansion roadmap
1. **Seasonal events:** the framework and Halloween "Haunted Hollow" are ✅ implemented. Next is Winter "Snow Day" (add an entry to `Config/Events.luau` plus 3 critters).
2. **Trading of critters** between players, with anti-scam confirmation.
3. **Vacuum cosmetics** (skins and trails), sold directly and never randomized.
4. **New zones** (Underwater Reef, Cloud Kingdom), added through config plus a prop set.
5. **Clans / squad goals:** weekly shared cleaning targets.
