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
| Unit + integration tests | `lune run tests/run` | ✅ **123 passed, 0 failed** |
| Place build | `rojo build … -o build/SweepSquad.rbxl` | ✅ builds |
| Place validation | `lune run tools/validate_place.luau` | ✅ 1 server script, 2 client scripts, 60+ modules, all compile |

### Test coverage by spec
| Spec | Covers |
|---|---|
| `modules.spec` (2) | Every script and module compiles; every shared module loads |
| `logic.spec` (58) | Config integrity, schema migration and sanitizing, stats stacking, economy (buy, unlock, rebirth, perks, packs), DebrisGrid, ZoneLayout, NetCodec, critter odds, pity, golden and equip rules, quests and streaks, formatting, RNG, rate limiter, signals, promo codes, seasonal event windows, odds and drop share |
| `server.spec` (29) | DataService (create, load, migrate, save, release, live-lock wait and takeover, stale lock, stolen-lock kick, load-failure kick, save retries, shutdown), the collection loop (collect, capacity, sell, locked zones, speed hack, auto-sell, squad bonus, zone clear and golden refill), critters, action dispatcher (whitelist, payload validation, rate limit, upgrade, unlock, quest claim once, rebirth), receipts (grant once, save-before-grant, unknown product or player, storm), event wiring |
| `world.spec` (13) | Full map build against the Roblox API: gates, prompts, part budget (1,556), anchoring, leaderboards, spawn, sell-pad alignment with server logic; seasonal hub decor; every prop, critter (normal and golden, including event critters) and gear tier |
| `client.spec` (14) | The whole HUD and all 7 windows built with validated properties (2,325 instances); handshake; state refresh; button clicks send actions; unconfigured products never prompt; debris rendering (876 parts per zone), deltas, golden waves, low-graphics mode; every effect; chat tags; critter followers; the per-frame loops (zone streaming, ambience, tutorial beam and radar, followers) with a character moving between zones |
| `debug.spec` (1) | Studio-only debug attributes |

## Visual verification without Studio (geometry previews)
`tools/preview/` exports the real generated world through the same modules the game uses: MapBuilder, DebrisRenderer, GearModels and CritterModels. It then renders the scenes with three.js in headless Chromium, following Roblox conventions (Y-up, X-axis cylinders, the wedge profile, sphere meshes). The output is in `docs/previews/`.

| Preview | What it showed and fixed |
|---|---|
| `zone1_squad`, `thumb_squad` | Debris was a grid of flat discs → redesigned into an overlapping, varied carpet with visible cleaned trails |
| `overview` | Coherent layout (hub → corridors → gated zones). Every zone sat on the same green meadow → themed biome ground per zone |
| `beach_golden` | The golden wave reads clearly. The umbrella canopy looked like a pinwheel → rebuilt as a striped dome |
| `critters` | All 30 critters (24 zone and 6 event) are readable and cute. The hedgehog's spikes looked like fence planks → rebuilt as quills. The Aurora Reindeer's aurora-green belly looked wrong → cream body accent, and only the nose glows |
| `hub`, `candy`, `volcano` | Shops, fountain, seasonal jack-o'-lanterns and themed props render as intended |

This is **not** the Roblox renderer: lighting, materials and text differ. It checks shapes, placement, proportions and colours only.

**Engine rule found during this pass:** Roblox forces `Ball` parts to a uniform size. Non-uniform spheres now use a Block part with a Sphere `SpecialMesh`, and `world.spec` and `client.spec` enforce the Ball and Cylinder size rules.

## UI layout previews (phone, tablet, PC)
`tools/preview/export_ui.luau` builds the **real** client UI: HUD, toasts, tutorial and all 7 windows. It runs inside the Lune client environment at three device sizes: phone 844×390 touch, tablet 1180×820 touch, and PC 1920×1080 with the Roblox top bar. It exports the GUI trees. `ui.html` / `render_ui.js` then lay them out with an emulation of Roblox GUI rules: UDim2, AnchorPoint, UIListLayout, UIGridLayout, UIPadding, UISizeConstraint, UIScale, AutomaticSize, and TextScaled with word wrap. The 24 images are in `docs/previews/ui/`.

```
lune run tools/preview/export_ui.luau
NODE_PATH=$(npm root -g) node tools/preview/render_ui.js
```

| Finding | Fix |
|---|---|
| On phones the UIScale hit its 0.55 floor, which made menu labels and toast text unreadable | Touch devices use a 640px design height. Phones are now 0.67 and the floor is 0.6 (`UI/Responsive.luau`) |
| Notification badges covered the menu button labels | Badges moved inside the button corner |
| PC hotkey suffixes truncated labels ("Critters (C") | Hotkeys are now small keycaps in the button corner |
| Toasts were narrow, unwrapped, and covered the open window's header | Toasts are wider and wrap. While a window is open they dock to the bottom of the screen (`Notifications.dock`) |

This is an emulation, **not** the Roblox renderer. Fonts are close substitutes (Fredoka, Montserrat), and emoji use the browser's font, not Roblox's. It checks layout, overlap and legibility. Final sign-off still needs the Studio device emulator.

## What has NOT been verified (needs Roblox Studio or devices)
These are **not** claimed as tested:
- Actual gameplay in the Roblox engine: physics, character rig and gear welding, camera, ProximityPrompt behaviour, UI in the real renderer (layout has only been emulated, see above), tween visuals, sounds.
- Real DataStore, MarketplaceService and AnalyticsService behaviour (only mocks were tested).
- Performance: FPS, memory and network on PC and phones.
- Multiplayer replication timing with several real clients.
- Whether the built-in `rbxasset://sounds/*` files exist on every platform.

Follow [[Studio Setup & Playtest Guide]] and record results below.

## Performance measurements
### Server script cost (measured offline, `lune run tools/bench_server.luau <players> <ticks>`)
This runs the real `DebrisService.step` and replication encode for players roaming zone 3 with zone-appropriate gear. Lune runs the same Luau VM as Roblox (without native codegen). Engine costs (physics, network transport) are excluded.

| Date | Players | Avg per 0.2 s tick | p99 | Share of tick budget | Debris replication per client | Waves cleared per 100 s |
|---|---|---|---|---|---|---|
| 2026-09-24 | 12 | 0.113 ms | 0.320 ms | 0.06% | ≈ 338 B/s | 9 |
| 2026-09-24 | 30 | 0.574 ms | 1.690 ms | 0.29% | ≈ 822 B/s | 26 |

**Finding → change:** crowded zones clear roughly every 11 seconds, which would have made Golden Gusts (x3) near-constant. A `GoldenCooldown` of 180 s per zone now limits them (tested in `server.spec`).

### Client and device (needs Studio or real hardware)
| Date | Device | Location | FPS | Memory | Notes |
|---|---|---|---|---|---|
| (pending) | | | | | |

Offline structural measurements: map 1,556 parts (346 colliding); debris per rendered zone 876 parts (about 440 in Low Graphics); UI 2,325 instances total across all windows (only the open window is visible).

## Bug triage rules
- **P0:** data loss, purchase not granted or double-granted, crash on join. Fix immediately.
- **P1:** core loop blocked (can't collect, sell or unlock). Fix before any release.
- **P2:** visual or UX issues. Batch into the next update.
