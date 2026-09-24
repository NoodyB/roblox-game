# CLAUDE.md: Sweep Squad

Roblox co-op cleaning incremental, managed with Rojo. Read `PROJECT_STATUS.md` first. It holds the current phase and the next task.

## Commands
- Tests: `lune run tests/run` (filter: `lune run tests/run <substring>`). Must stay green.
- Full gate: `./tools/check.sh`. It runs stylua --check, selene, tests, rojo build and the place validator.
- Format: `stylua src tests tools`. Lint: `selene src` (uses `roblox_min.yml`, a local std; see below).
- Economy balance: `lune run tools/simulate_economy.luau [vip]` after any change to costs or values.
- Toolchain in the cloud: built from crates.io into `~/.cargo/bin` (`cargo install --locked rojo lune selene stylua`). GitHub release downloads are blocked there.

## Architecture rules
- **The server is authoritative.** Clients only send `Action(name, payload)` through the one RemoteFunction. Every action must be declared in `src/shared/Net/Remotes.luau` and validated in its handler. Collection is computed server-side from character positions; there is no collect remote.
- Config (`src/shared/Config`) is the single source of truth for tuning. Logic (`src/shared/Logic`) is pure and unit-tested.
- Services live in `src/server/Services`, are initialized in `Main.server.luau` order, and use `Init` (wiring) then `Start` (loops). To avoid require cycles, publish on `Services/Events.luau` instead of requiring upward.
- Build world and UI geometry through `src/shared/World/Build.luau` helpers. Set `CFrame`, never `Position`. Anchor parts and turn off collision and shadows on decorative parts.
- Money: never sell random items for Robux. Receipts must record the `PurchaseId` and save before returning `PurchaseGranted`.
- Product IDs stay `0` in `Config/Products.luau` until the owner creates them. A `0` ID disables the buy button.

## Testing conventions
- `tests/harness.luau` mounts the Rojo tree so modules `require` exactly as in Roblox. `tests/mocks.luau` fakes engine services. `tests/clientenv.luau` wraps real Lune instances so every UI and world property is validated against the Roblox API.
- Lune does not model runtime-only properties (`Position` on parts, `ViewportSize`). Read `CFrame.Position` in shared code.
- Add a spec for every new service or action. Do not weaken tests to get them passing.

## Docs
Obsidian vault in `docs/`, starting at `docs/00 Dashboard.md`. At the end of a session, update `PROJECT_STATUS.md` and `docs/Games/Sweep Squad/Dev Log.md`. Never write secrets or credentials into docs.
