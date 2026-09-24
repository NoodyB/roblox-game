---
tags: [marketing, launch]
updated: 2026-09-24
---
# Marketing and launch plan

## How players will find the game
Roblox's Recommended For You ranking uses only players who arrived through Recommended For You. It rewards play-through rate, low first-play bounce, playtime, and play days across D1, D2-7 and D8-28. Ads, search, friends and social traffic can **seed** consideration but don't count in ranking ([[Market Research 2026-09]] §3). The strategy follows from that:
1. Make the thumbnail and title win the click (play-through rate).
2. Make the first 60 seconds pay off instantly: debris flies into the vacuum, the first sell happens within about 20 seconds, the first critter within about 30 (low bounce).
3. Give daily reasons to return: quests, streak, zone waves and critters (D2-28 play days).
4. Use cheap seeding (friends, short videos, small search-ads tests) to get an initial sample of players.

## Store listing (ready to paste)
**Title (A/B candidates):**
1. `🍂 Sweep Squad: Clean Up Everything!`
2. `🍂 Clean the Whole World! [Sweep Squad]`
3. `🌪️ Vacuum Everything! (Sweep Squad)`

**Description:**
```
🍂 Vacuum up leaves, snow, candy sprinkles and STARDUST with your friends!

🌪️ Walk into the mess and watch it fly into your vacuum
💰 Sell your bag, upgrade your vacuum, bag and boots
🗺️ Unlock 8 worlds: from Backyard Lane to the Moon Base
🐿️ Find 24 adorable Critters hiding in the debris (make them GOLDEN!)
✨ Clean a whole zone together to summon a GOLDEN GUST worth 3x
♻️ Rebirth for permanent coin boosts
📜 Daily quests and login streak rewards

Everything can be earned for free. Clean together, get a Squad Bonus!
👍 Like and ⭐ favorite for updates!
```
**Genre:** Simulation. **Max players:** 12 (suggested; cleaning a zone needs company but shouldn't feel crowded). **Maturity:** answer the questionnaire honestly. The content is minimal: no violence, blood or romance.

## Icon and thumbnails
Concept images are in `marketing/`. `thumbnail_1-3` are illustrated concepts. `thumbnail_4_real_squad` and `thumbnail_5_real_golden` are composed from **renders of the real game geometry** (`docs/previews/`). A/B test the two groups against each other, and against real Studio screenshots with real avatars once available.
- **Icon:** a big cartoon vacuum sucking up a swirl of orange leaves, the "SWEEP SQUAD" logo, and a warm gradient.
- **Thumbnail 1 (loop):** 3-4 avatars vacuuming a leaf-covered yard with a coin burst. Text: "CLEAN EVERYTHING!"
- **Thumbnail 2 (collection):** a critter lineup (fox, unicorn, whale) with the Golden versions glowing. Text: "24 CRITTERS!"
- **Thumbnail 3 (progression):** a strip of the 8 worlds. Text: "8 WORLDS".
- Use Roblox thumbnail personalization and A/B testing (Creator Dashboard → Places → Thumbnails) once the place is public.

## Short-form video plan (free)
| # | Hook (first 2 seconds) | Content |
|---|---|---|
| 1 | "I vacuumed an ENTIRE volcano" | A speed-up of the Volcano Vents clear and the Golden Gust |
| 2 | "Rating every critter" | A tour of the Critter Book, ending on a golden reveal |
| 3 | "Noob vs Pro vacuum" | Rusty Rake compared with Cosmic Cleaner |
| 4 | "12 players, 1 zone" | Co-op clear with the squad bonus |
Record in Studio with the Recorder, or ask a friend. Post on TikTok, YouTube Shorts and Instagram Reels with #roblox, #robloxgames and #sweepsquad. **Only post footage of your own account and game.**

## Promo codes
Codes are live in `src/shared/Config/Codes.luau` and redeemed in Settings: `SWEEPSQUAD` (5 bags of coins), `LAUNCH` (15 minutes of 2x Coins) and `SQUIRREL` (a free critter). Add a new code per video or creator. Codes let you see which channel brings players, because every redemption logs a `CodeRedeemed` analytics event.

## Creator outreach (free first)
Approach small Roblox YouTubers (1k-50k subscribers) who cover simulators. Offer early access and a shout-out code system later. Do not pay for promotion without approval. Don't buy fake visits, likes or bots; that is against the Terms of Use and poisons the recommendation signals.

## Launch timeline
| Phase | Duration | Exit criteria | Owner actions needed |
|---|---|---|---|
| 1. Internal Studio test | 1-2 days | Checklist in [[Studio Setup & Playtest Guide]] passes; no errors in Output | Run Studio and report errors |
| 2. Private test (friends, 5-10 people) | 3-5 days | No blocking bugs; median first session over 10 minutes | Publish as private or friends-only |
| 3. Bug fix and optimization | 2-4 days | 60 FPS on a mid-range phone; no data loss | Test on a real phone |
| 4. Monetization setup | 1 day | Passes and products created and IDs configured | Create products in the Creator Dashboard |
| 5. Public soft launch | 7-14 days | Collect D1, D7, session length and conversion | Make public (**needs your approval**) |
| 6. Retention iteration | ongoing | D1 ≥ 20%, D7 ≥ 7% | Review analytics weekly |
| 7. Ads test (optional) | 5-7 days | Gate met; $10-20/day | **Needs your approval and budget** |
| 8. Content cadence | every 2-3 weeks | Halloween event (Oct 2026), new zone, Winter event | |

## Event calendar
- **October 2026: "Haunted Hollow"** Halloween reskin of Backyard Lane (purple fog, jack-o-lantern debris), plus 3 spooky critters. This is the first update after launch.
- **December 2026: "Snow Day"**, a snow wave across all zones.
- Update badges and titles ("[🎃 HALLOWEEN]") help click-through on the charts.
