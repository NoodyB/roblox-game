# Project status: Sweep Squad

_Last updated: 2026-09-24 (end of cloud session 1)_

## Current objective
Ship **Sweep Squad**, a co-op cleaning incremental for Roblox (mobile and PC), as the first product of an AI-assisted Roblox studio.

## Selected concept
Co-op cleaning incremental with 8 themed zones, collectible critters, zone-clear Golden Gusts, rebirths and perks, and a non-gacha store. Rationale: [docs/Games/Sweep Squad/Concept Selection.md](docs/Games/Sweep%20Squad/Concept%20Selection.md).

## Phase
**Milestone 7 (QA).** The implementation is complete and has passed automated tests. **It has not been playtested inside Roblox Studio**; that needs the owner's machine.

## Completed features (code + offline tests)
- Server-authoritative core loop: collect → sell → upgrade → unlock, across 8 zones plus the hub town.
- Procedural world: 1,556 parts, props, landmarks, gates, sell stations, leaderboards.
- Critters: 24 species, free drops with pity, equip slots, golden merge, followers, and a book showing odds.
- Co-op: zone clears with contributor bonuses, alternating golden waves, squad bonus, server-wide Golden Storm.
- Rebirth (multiplier and tokens) plus 5 perks. Daily quests, a 7-day streak, and a tutorial with a guide beam that doubles as a debris radar.
- Persistence: session-locked DataStore profiles, autosave, shutdown save, migration and sanitizing.
- Monetization: 4 passes and 6 products. Idempotent receipts, save-before-grant. IDs still need configuring.
- Client: HUD, 7 windows, responsive scaling for phone to PC, effects, sounds, loading screen, PC hotkeys.
- Analytics: onboarding funnel, economy, progression and custom events.
- Seasonal events: Haunted Hollow (Halloween 2026) and Snow Day (Winter 2026), each with event critters, palette, hub decor and a toast; Snow Day adds local snowfall (Frosty Peaks snows all year). Promo codes. Invite button, squad chip, VIP chat tags.
- Badges (6 milestones) and a Roblox group bonus (+10%); auto Low Graphics on slow devices; a prebuilt `release/SweepSquad.rbxl`.
- Tooling: 122 tests, lint, format, place build and validator, economy simulator, geometry preview renderer and UI layout previews for phone, tablet and PC (`tools/preview`, `docs/previews/`), promo art including real-render thumbnails.

## Remaining work
| Item | Owner | Notes |
|---|---|---|
| Studio playtest checklist | **You** | [Studio Setup & Playtest Guide](docs/Games/Sweep%20Squad/Studio%20Setup%20%26%20Playtest%20Guide.md) |
| Fix issues found in Studio | Claude (next session) | Paste Output errors into Known Issues or an issue |
| Real-device performance check | **You** | Mid-range phone; record FPS in Testing & QA |
| Create passes, products and badges; set the group ID | **You** | [Monetization](docs/Games/Sweep%20Squad/Monetization.md) checklist (the IDs go in `Config/Products`, `Config/Badges` and `GameConfig.GroupId`) |
| Licensed music and nicer SFX | **You** or Claude | [Assets & Audio](docs/Games/Sweep%20Squad/Assets%20%26%20Audio.md) |
| Real screenshots for thumbnails | **You** | Concepts are in `marketing/` |
| Publish publicly | **You (approval)** | After a private test |
| Halloween event | ✅ Done | Runs automatically 2026-10-01 to 11-04 UTC |
| Winter event "Snow Day" | ✅ Done | Runs automatically 2026-12-12 to 2027-01-06 UTC (snowfall, 3 critters, snowmen) |

## Known issues
See [Known Issues](docs/Games/Sweep%20Squad/Known%20Issues.md). There are no known failing tests. The main risks are in-engine visual offsets (gear, followers) and real-device performance.

## Last successful test results (2026-09-24)
- `./tools/check.sh` passes all steps: stylua ✅, selene 0/0 ✅, **122 passed / 0 failed** ✅, rojo build ✅, place validation ✅.

## Development environment
- Cloud: Ubuntu 24.04. Toolchain built from crates.io (GitHub downloads are blocked): Rojo 7.7.0, Lune 0.10.5, Selene 0.31.0, StyLua 2.5.2.
- Local (Windows): `rokit install` from `rokit.toml`.

## Important commands
```
lune run tests/run                      # all tests
./tools/check.sh                        # full gate
rojo build default.project.json -o build/SweepSquad.rbxl
rojo serve                              # live sync to Studio
lune run tools/simulate_economy.luau    # balance check
```

## Next implementation task
1. Apply fixes from the owner's Studio playtest, starting with any Output errors.
2. A new zone ("Underwater Reef") or the Spring event, chosen from the retention data after launch.
