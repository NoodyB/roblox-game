---
tags: [qa, testing]
updated: 2026-09-24
---
# Testing and QA

## What has been verified (cloud, automated)
Run on 2026-09-24 in the cloud environment (Linux) with Rojo 7.7.0, Lune 0.10.5, Selene 0.31.0 and StyLua 2.5.2.

| Check | Command | Result |
|---|---|---|
| Formatting | `stylua --check src tests tools` | ✅ clean |
| Lint | `selene src` (custom `roblox_min` std) | ✅ 0 errors, 0 warnings |
| Unit + integration tests | `lune run tests/run` | ✅ **105 passed, 0 failed** |
| Place build | `rojo build … -o build/SweepSquad.rbxl` | ✅ builds |
| Place validation | `lune run tools/validate_place.luau` | ✅ 1 server script, 2 client scripts, 60+ modules, all compile |

### Test coverage by spec
| Spec | Covers |
|---|---|
| `modules.spec` | Every script and module compiles; every shared module loads |
| `logic.spec` (53) | Config integrity, schema migration and sanitizing, stats stacking, economy (buy, unlock, rebirth, perks, packs), DebrisGrid, ZoneLayout, NetCodec, critter odds, pity, golden and equip rules, quests and streaks, formatting, RNG, rate limiter, signals |
| `server.spec` (32) | DataService (create, load, migrate, save, release, live-lock wait and takeover, stale lock, stolen-lock kick, load-failure kick, save retries, shutdown), the collection loop (collect, capacity, sell, locked zones, speed hack, auto-sell, squad bonus, zone clear and golden refill), critters, action dispatcher (whitelist, payload validation, rate limit, upgrade, unlock, quest claim once, rebirth), receipts (grant once, save-before-grant, unknown product or player, storm), event wiring |
| `world.spec` (11) | Full map build against the Roblox API: gates, prompts, part budget (1,556), anchoring, leaderboards, spawn, sell-pad alignment with server logic; every prop, critter (normal and golden) and gear tier |
| `client.spec` (11) | The whole HUD and all 7 windows built with validated properties (2,215 instances); handshake; state refresh; button clicks send actions; unconfigured products never prompt; debris rendering (876 parts per zone), deltas, golden waves, low-graphics mode; every effect; critter followers |
| `debug.spec` (1) | Studio-only debug attributes |

## What has NOT been verified (needs Roblox Studio or devices)
These are **not** claimed as tested:
- Actual gameplay in the Roblox engine: physics, character rig and gear welding, camera, ProximityPrompt behaviour, UI layout at real resolutions, tween visuals, sounds.
- Real DataStore, MarketplaceService and AnalyticsService behaviour (only mocks were tested).
- Performance: FPS, memory and network on PC and phones.
- Multiplayer replication timing with several real clients.
- Whether the built-in `rbxasset://sounds/*` files exist on every platform.

Follow [[Studio Setup & Playtest Guide]] and record results below.

## Performance measurements
| Date | Device | Location | FPS | Memory | Server step | Notes |
|---|---|---|---|---|---|---|
| (pending) | | | | | | |

Offline structural measurements: map 1,556 parts (346 colliding); debris per rendered zone 876 parts (about 440 in Low Graphics); UI 2,215 instances total across all windows (only the open window is visible).

## Bug triage rules
- **P0:** data loss, purchase not granted or double-granted, crash on join. Fix immediately.
- **P1:** core loop blocked (can't collect, sell or unlock). Fix before any release.
- **P2:** visual or UX issues. Batch into the next update.
