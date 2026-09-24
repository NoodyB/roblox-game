---
tags: [monetization]
updated: 2026-09-24
---
# Monetization

## Principles
1. **Everything is earnable for free.** Purchases save time or add social fun. The store says this on screen.
2. **No paid random items.** Critters, the only random rewards, drop from free gameplay, and their odds are shown in the Critter Book. This sidesteps the 2026 paid-random-item rules and age restrictions ([[Market Research 2026-09]] §4).
3. **Exact descriptions before the prompt.** Every card states what the item does and its price. Coin packs preview the exact amount ("≈ 1.2M coins right now").
4. **No pressure tactics.** No pop-up offers, fake timers or "last chance" banners. Boosts count down only while playing.
5. **Social purchases are positive-sum.** A Golden Storm helps everyone in the server and credits the buyer.

## Catalogue (config: `src/shared/Config/Products.luau`)
| Type | Key | Suggested price (R$) | Effect |
|---|---|---|---|
| Pass | VIP | 199 | ×1.2 coins, VIP chat tag, +1 critter slot |
| Pass | DoubleCoins | 399 | ×2 coins from selling, forever |
| Pass | AutoSell | 149 | The bag sells itself when full, anywhere |
| Pass | CritterSlots | 249 | +2 equipped critters |
| Product | CoinsSmall | 49 | Coins = 3 full bags × best zone value × rebirth multiplier |
| Product | CoinsMedium | 149 | 12 bags |
| Product | CoinsLarge | 399 | 40 bags |
| Product | BoostCoins | 59 | 2x coins for 30 minutes of play (stacks) |
| Product | BoostCollect | 59 | 2x power and +3 reach for 30 minutes of play (stacks) |
| Product | GoldenStorm | 99 | Server-wide 2x coins for 5 minutes; the buyer is named |

Prices are hints for the store UI; the real price is fetched from Roblox. Review them after launch against conversion data (see *Price testing* below). Roblox's Price Optimization tool can A/B test prices later.

## Setup checklist (you: needs your Roblox account)
1. Publish the place: Studio → File → Publish to Roblox.
2. Go to Creator Dashboard → your experience → **Monetization → Passes**. Create the 4 passes with icons. Placeholder icons are fine; see [[Marketing & Launch Plan]] for icon ideas. Copy each pass ID.
3. **Monetization → Developer Products:** create the 6 products and copy each product ID.
4. Paste the IDs into `src/shared/Config/Products.luau`, replacing `id = 0`. Commit and push, then rebuild or resync.
5. Test in Studio. Test purchases there don't charge Robux: buy each product and pass, and confirm the grant plus the "✓ Owned" state. Studio purchase prompts are simulated.
6. **Badges (free):** Creator Dashboard → Badges. Create the 6 milestone badges listed in `src/shared/Config/Badges.luau` and paste their IDs.
7. **Group bonus (free):** create a Roblox group for the studio and put its ID in `GameConfig.GroupId`. Members get +10% coins, and the group gives you an audience for update announcements.
8. Optional: enable **Private Servers** in Experience settings. A free or low-priced private server option helps friend groups play together (co-op). *Decide the price: suggested free or 50 R$/month.*

## Technical guarantees (tested offline in `tests/specs/server.spec.luau`)
- `ProcessReceipt` looks up the product, waits up to 10 s for the profile, and checks the PurchaseId history (the last 100 purchases are kept per profile).
- A grant is applied → the PurchaseId is recorded → the profile is **saved** → only then is `PurchaseGranted` returned. If the save fails, it returns `NotProcessedYet`. The in-memory receipt prevents a double grant in this server, and Roblox's retry takes the "already granted" path.
- Unknown products and absent players return `NotProcessedYet`, which never loses a purchase.
- Pass ownership comes from `UserOwnsGamePassAsync` at join, with retries, and is re-verified after `PromptGamePassPurchaseFinished`.
- Buttons for unconfigured items (`id = 0`) are disabled and show "Coming soon".

## Other revenue
- **Creator Rewards:** 5 R$ per qualified user whose session is 10+ minutes and among their first 3 games that day. The game is designed for 10-30 minute sessions and daily returns. See [[Financial Model]].
- **Not implemented, deliberately:** rewarded video ads (eligibility and policy for a young audience need review first), UGC items, and subscriptions. Revisit once real retention data exists.

## Price testing plan (after launch)
Track the conversion rate per product, ARPPU, and spend days in Creator Analytics → Monetization. Change one price at a time for at least 7 days. Keep the Golden Storm cheap, because it drives the social spend signal.
