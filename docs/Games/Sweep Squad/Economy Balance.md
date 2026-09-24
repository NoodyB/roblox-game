---
tags: [economy, balance]
updated: 2026-09-24
---
# Economy balance

Source of truth: `src/shared/Config/{Zones,Upgrades,Progression,Products}.luau`. After changing any number, check it with `lune run tools/simulate_economy.luau` and `... vip`.

## Design targets (active free-to-play player)
| Milestone | Target | Why |
|---|---|---|
| First sell | < 20 s | Instant payoff (first-play bounce) |
| First critter | < 30 s of collecting | "Wow" moment in session 1 (guaranteed by pity) |
| Zone 2 unlocked | ~4-6 min | First big goal inside session 1 |
| Zone 3 | ~15 min | Session 1 ends mid-progress, which is a reason to return (D1) |
| Zone 4 | ~45 min | Sessions 2-3 |
| First rebirth | ~1.5-2 h | First "prestige" moment in week 1 |
| Zone 6-7 | ~13-26 h | Weeks 2-4 (D8-28 play days) |
| Zone 8 and max tiers | 35 h+ | Long tail, plus rebirth stacking and golden critters |

## Simulation results (2026-09-24, current config)
Model: power- and sweep-limited collection × 0.45 efficiency; 45-stud average walk to sell; greedy upgrades; rebirth when affordable after zone 4. It **excludes** quest and streak rewards, golden waves (x3), squad bonus (up to +30%), zone-clear bonuses and perks. **Real pacing should therefore be somewhat faster.**

| Milestone | Free-to-play | VIP + 2x Coins |
|---|---|---|
| Zone 2 | 4:50 | 2:05 |
| Zone 3 | 13:23 | 5:47 |
| Zone 4 | 45:06 | 19:51 |
| Rebirth #1 | 1:39:34 | 56:53 |
| Zone 5 | 3:20:32 | 1:39:57 |
| Zone 6 | 13:12:10 | not measured |
| Zone 7 | 26:08:12 | not measured |

Buying VIP + 2x Coins speeds progress about 2.3x. It saves time without locking any content.

## Key formulas
- **Sale value** = Σ(units × zone value × golden×3 × (1 + squad bonus)) × coinMultiplier.
- **coinMultiplier** = (1 + 0.5 × rebirths) × (1 + critter coin % + Golden Touch) × 2 (2x pass) × 1.2 (VIP) × 2 (boost) × 2 (storm).
- **Rebirth cost** = 5M × 2.6^rebirths.
- **Quest reward** = incomeUnit × reward weight, where incomeUnit = max(150 × zone value, bag capacity × zone value × 0.75) × rebirth multiplier.
- **Coin pack** = bag capacity × best zone value × bags × rebirth multiplier.

## Levers if live data disagrees
| Symptom | Lever |
|---|---|
| First-session drop-off before zone 2 | Lower `Zones[2].unlockCost`, or raise early bag capacity |
| Long flat stretches mid-game | Add an intermediate tier, or reduce the tier cost growth (currently 1.35^tier baked into costs) |
| Rebirth feels pointless | Raise `MultiplierPerRebirth` or add perk power |
| Late game too slow | Lower zone 7-8 costs; add golden-wave frequency |
| Passes feel mandatory | Reduce `DoubleCoinsMultiplier`; never gate content |
