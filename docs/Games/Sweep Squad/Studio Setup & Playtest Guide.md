---
tags: [studio, setup, qa]
updated: 2026-09-24
---
# Studio setup and playtest guide (Windows)

These are the steps that need your local Roblox Studio. The cloud session could not run Studio.

## One-time setup (about 10 minutes)
1. Install **Roblox Studio** and sign in.
2. Install **Rokit**: download the Windows installer from https://github.com/rojo-rbx/rokit/releases, then open a new terminal.
3. `git clone https://github.com/NoodyB/roblox-game` and `cd roblox-game`. Check out the development branch, or `main` once it is merged.
4. Run `rokit install`. This installs rojo, lune, selene and stylua.
5. Install the Rojo Studio plugin: `rojo plugin install`, or get it from the Creator Store.
6. Optional: `lune run tests/run` should report `104 passed, 0 failed`.

## Open the game
**Option 0: prebuilt file (no tools at all).** Download `release/SweepSquad.rbxl` from the GitHub repo (branch `claude/kind-brahmagupta-hqjve7`, or `main` once merged) and double-click it. This skips the one-time setup above. You only need that setup to edit code.

**Option A: build the place file yourself**
1. `rojo build default.project.json -o build/SweepSquad.rbxl`
2. Double-click `build/SweepSquad.rbxl`.

**Option B: live sync (for development)**
1. `rojo serve`
2. In Studio, create a new Baseplate, **delete the Baseplate part and the default SpawnLocation**, open the Rojo plugin and click **Connect**.

## Required Studio settings
- *Home → Game Settings → Security*: turn on **Enable Studio Access to API Services** so DataStores work. Without it the game still runs, but saves are temporary.
- The game must be **published** (File → Publish to Roblox) before DataStores, passes and products work, even in Studio.
- To test passes without buying them: select ServerScriptService, add a Boolean attribute `GrantAllPasses = true`. This works in Studio only.

## Playtest checklist
Press **F5 (Play)**. For multiplayer, use *Test → Clients and Servers → 2 players → Start*. Tick each item and note FPS.

### Boot
- [ ] The loading screen appears and fades. No red errors in Output (*View → Output*).
- [ ] Output shows `[Sweep Squad] server ready`.
- [ ] The map exists: the hub, 8 zones going east, and gates on zones 2-8.
- [ ] HUD: coins pill, bag meter, zone bar, left menu buttons.
- [ ] The tutorial card says "Walk into the leaves…" and a gold beam points the way.

### Core loop
- [ ] Walk into Backyard Lane. Leaf piles shrink, bits fly into the vacuum, and the bag meter rises.
- [ ] The bag fills, "FULL! Sell at 💰" shows, and collection stops.
- [ ] Stepping on a green SELL pad plays the coin burst and "+X", and coins go up.
- [ ] The shop opens from the button, from B, and from the Vacuum Shop building prompt. Buying Twig Broom increases reach, and the vacuum model changes.
- [ ] The zone 2 gate shows its price. With enough coins, holding E unlocks it: confetti plays, the gate disappears and you can walk through.
- [ ] Trying to walk into zone 3 while it's locked: the gate blocks you (and the server teleports you back if you noclip).

### Systems
- [ ] A critter is found within about 30 seconds of the first collecting. The pop-up shows, the critter follows you, and it appears in the Critters window.
- [ ] Equip, Unequip and Equip Best work. Five copies enable "Gold (5)".
- [ ] The Quests window shows 3 quests and the streak. Claiming the streak adds coins.
- [ ] Travel teleports to unlocked zones.
- [ ] Settings: each toggle works and persists after rejoining. Low Graphics removes the accent parts on debris.
- [ ] Rebirth: set `DebugCoins` high (see the helpers below), rebirth, and confirm the reset and the multiplier.
- [ ] Two clients in the same zone: both see debris disappear, the squad bonus applies, and clearing the zone gives both players the bonus and starts the golden wave.

### Persistence (published place, API access on)
- [ ] Earn coins, stop, then Play again. Coins, upgrades, critters and settings are kept.
- [ ] Two quick Play sessions in a row load correctly (session lock handover).

### Mobile and PC
- [ ] *Test → Device emulator* at iPhone SE / iPhone 14 / iPad / 1080p / 4K. Nothing is cut off, the buttons are reachable, and the text is readable.
- [ ] The touch thumbstick and jump button don't overlap the HUD.
- [ ] **Real device:** publish privately and play on an actual phone. Emulation is not a substitute.

### Performance (record the numbers in [[Testing & QA]])
- [ ] *View → Stats* (Ctrl+F12 / Shift+F5): FPS, memory and network while in zones 1, 4 and 8.
- [ ] *View → MicroProfiler* (Ctrl+F6): note server step time with 2-4 test clients.
- [ ] On a real mid-range phone: FPS in Backyard Lane with other players around.

## Studio test helpers (no code needed)
During a Play session, switch the Explorer to the **Server** view, select *Players → (you)*, and add an attribute:

| Attribute | Type | Effect |
|---|---|---|
| `DebugCoins` | number | Sets your coins, e.g. `1e12` |
| `DebugMaxZone` | number | Unlocks zones up to this ID (1-8) |
| `DebugCritters` | boolean | Grants one of every critter |
| `DebugTokens` | number | Sets rebirth tokens |

These helpers only work in Studio (`src/server/Services/DebugService.luau`). Live servers ignore them.

## Reporting issues
Copy the red Output errors, including the stack trace, into [[Known Issues]] or a GitHub issue. The next Claude session can fix them directly from the trace.
