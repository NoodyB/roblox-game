# 🍂 Sweep Squad

**Sweep Squad** is a co-op cleaning incremental game for Roblox, built for mobile and PC. Players vacuum up leaves, snow, sprinkles and stardust across 8 themed zones. They sell their full bags, upgrade vacuums, bags and boots, and find collectible **Critters** hidden in the debris. When everyone in a zone cleans it together, a **Golden Gust** refills the zone with debris worth triple.

The whole game is code. The world, props, critters, UI and effects are generated from Luau using Roblox primitives, so there are no external assets to upload. The project uses [Rojo](https://rojo.space).

> Status: **complete Roblox-compatible implementation, not yet playtested in Roblox Studio.** See [PROJECT_STATUS.md](PROJECT_STATUS.md) and the [Studio Setup & Playtest Guide](docs/Games/Sweep%20Squad/Studio%20Setup%20%26%20Playtest%20Guide.md).

## Quick start on Windows

1. Install the toolchain with [Rokit](https://github.com/rojo-rbx/rokit): run `rokit install` in this folder. This installs Rojo, Lune, Selene and StyLua at the versions pinned in `rokit.toml`.
2. Build a place file with `rojo build default.project.json -o build/SweepSquad.rbxl`.
3. Open `build/SweepSquad.rbxl` in Roblox Studio and press **Play** (F5).
4. For live development instead, install the Rojo Studio plugin, run `rojo serve`, and click **Connect** in the plugin.

To test saving in Studio, open *Game Settings → Security* and enable **Studio Access to API Services**. Without it the game runs with temporary data and says so in Settings.

## Commands

| Command | What it does |
|---|---|
| `lune run tests/run` | Runs all 104 automated tests: logic, server, world build and client UI |
| `lune run tests/run economy` | Runs only the spec files whose name contains "economy" |
| `./tools/check.sh` | Runs format check, lint, tests, place build and place validation |
| `./tools/build.sh` | Builds `build/SweepSquad.rbxl` |
| `lune run tools/simulate_economy.luau [vip]` | Simulates player progression with the real config |
| `stylua src tests tools` | Formats the code |
| `selene src` | Lints the code |

## Layout

```
src/shared/   → ReplicatedStorage.Shared     config, pure game logic, world/model builders
src/server/   → ServerScriptService.Server   authoritative services (data, gameplay, purchases)
src/client/   → StarterPlayerScripts.Client  UI, rendering, effects, input
src/first/    → ReplicatedFirst              loading screen
tests/        Lune test harness, engine mocks, specs
tools/        build/check scripts, economy simulator, place validator
docs/         Obsidian-compatible business + design vault (start at docs/00 Dashboard.md)
```

## Documentation

- [Dashboard](docs/00%20Dashboard.md), the entry point for the vault
- [Game Design Document](docs/Games/Sweep%20Squad/Game%20Design%20Document.md)
- [Technical Architecture](docs/Games/Sweep%20Squad/Technical%20Architecture.md)
- [Monetization setup](docs/Games/Sweep%20Squad/Monetization.md), including how to create passes and products and paste their IDs
- [Market Research](docs/Business/Market%20Research%202026-09.md) · [Financial Model](docs/Business/Financial%20Model.md) · [Marketing & Launch](docs/Business/Marketing%20%26%20Launch%20Plan.md)
