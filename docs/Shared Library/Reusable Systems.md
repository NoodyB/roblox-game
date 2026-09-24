---
tags: [library, reuse]
updated: 2026-09-24
---
# Reusable systems (studio library)

These modules were written to carry over to future games with little change. Copy them together with their tests.

| System | Files | Reuse notes |
|---|---|---|
| Session-locked persistence | `server/Services/DataService.luau`, `shared/Logic/DataSchema.luau` | Swap in the new game's schema and `MIGRATIONS`. Tests: `server.spec` DataService block |
| Receipt processing | `server/Services/MonetizationService.luau`, `shared/Config/Products.luau` | Replace `grant()` kinds. The idempotency pattern stays |
| Pass ownership | `server/Services/PassService.luau` | Generic. Includes the Studio `GrantAllPasses` switch |
| Action networking | `server/Services/Net.luau`, `shared/Net/Remotes.luau`, `client/Controllers/ClientState.luau` | Whitelist, rate limit, handshake, `request()` |
| Internal events | `server/Services/Events.luau`, `shared/Util/Signal.luau` | Acyclic service graph |
| UI kit | `client/UI/Components.luau`, `Responsive.luau`, `WindowManager.luau`, `Notifications.luau` | Theme-driven (`shared/Config/Theme.luau`) |
| Geometry helpers | `shared/World/Build.luau` | Primitive builders in the "base CFrame + offset" style |
| Daily quests and streaks | `shared/Logic/QuestLogic.luau` | Templates in config. Deterministic per player per day |
| Analytics wrapper | `server/Services/Analytics.luau` | pcall-safe funnel, economy, progression and custom events |
| Studio debug helpers | `server/Services/DebugService.luau` | Attribute-driven, inert in live servers |
| Test harness | `tests/harness.luau`, `tests/mocks.luau`, `tests/clientenv.luau`, `tests/run.luau` | Works for any Rojo project that follows this layout |
| Tooling | `tools/check.sh`, `tools/validate_place.luau`, `rokit.toml`, `roblox_min.yml` | Offline-friendly CI gate |

**Rule:** don't force reuse at the expense of a game's own feel. Copy, then adapt.
