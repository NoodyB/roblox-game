---
tags: [devlog]
---
# Dev log

## Session 1: 2026-09-23 → 2026-09-24 (Claude Code cloud session)
**Environment:** Ubuntu 24.04 container with no Roblox Studio. GitHub release downloads are blocked, so the toolchain was compiled from crates.io: Rojo 7.7.0, Lune 0.10.5, Selene 0.31.0 and StyLua 2.5.2. The Roblox Studio MCP server is not available.

**Completed**
- Market research: live charts, discovery algorithm, monetization rules → [[Market Research 2026-09]].
- Concept evaluation (3 concepts, weighted scoring) → **Sweep Squad** ([[Concept Selection]]).
- Full Rojo project: shared config and logic, 13 server services, client controllers, UI kit, 7 windows, loading screen.
- Procedural world (hub plus 8 themed zones), props, critters and gear.
- Persistence with session locking; idempotent receipts; passes; Golden Storm.
- Economy simulator; costs retuned for multi-week progression.
- Test harness plus 105 tests (logic, server, world, client UI). Place builder plus validator.
- Docs vault, promo concept art, launch plan, financial model.

- Later in the session: promo codes, VIP and rebirth chat tags, invite button and squad chip, seasonal event framework plus Haunted Hollow (Halloween), NaN-teleport hardening, and loop-body tests. 115 tests pass.
- UI preview pipeline: the real UI is exported from Lune at 3 device sizes and laid out by an HTML emulation of Roblox GUI rules. It found 4 phone/PC layout problems, all fixed (bigger touch scale, badge placement, keycap hotkeys, docked wrapped toasts). Followers use HipHeight. 120 tests pass.
- Winter event "Snow Day" (12 Dec to 6 Jan): 3 critters including an antlered Aurora Reindeer, a snowy palette, snowmen around the hub, and local snowfall. The event weather system also gives Frosty Peaks year-round snow. Event toasts now use a per-event tagline. 122 tests pass.

**Important decisions**
- Server-authoritative collection from positions, with no client collect remote.
- No paid random items anywhere.
- Runtime-generated map (the code is the source of truth, and Lune validates it offline).
- The Lune proxy environment validates UI properties without Studio.

**Next priorities** (see `PROJECT_STATUS.md`)
1. Studio playtest on your machine using the checklist, then fix whatever it finds.
2. Create the passes and products, then configure their IDs.
3. Private friends test, then public soft launch (needs your approval).
