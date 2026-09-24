---
tags: [bugs]
updated: 2026-09-24
---
# Known issues and risks

No gameplay has run inside Roblox yet, so the items below are **risks to verify first** in Studio, ordered by likelihood.

| # | Area | Risk | How to verify / fix |
|---|---|---|---|
| 1 | Gear | The vacuum or bag offset on the hand or back may look wrong for some avatar scales or R6 rigs | Play with an R15 and an R6 avatar. Tweak the `grip` and `back` offsets in `World/GearModels.luau` |
| 2 | Critters | Followers now derive ground height from the R15 `HipHeight` (R6 falls back to 2 studs). This is untested on unusual avatar scales | Watch followers with a tall avatar and a small one (`Controllers/CritterFollowers.luau`) |
| 3 | UI | Layout has been checked in an HTML emulation at phone, tablet and PC sizes (`docs/previews/ui/`), not in the Roblox renderer | Studio device emulator, then a real phone. Adjust `UI/Responsive.luau` if needed |
| 4 | Audio | `rbxasset://sounds/clickfast.wav`, `swoosh.wav` and `uuhhh.mp3` are assumed built-ins | If Output warns that assets failed to load, swap the IDs in `Config/Sounds.luau` |
| 5 | Analytics | `AnalyticsService` method signatures may differ slightly | Calls are pcall-wrapped. Check Creator Dashboard → Analytics → Funnels after a test |
| 6 | Debris | 876 parts per zone may be heavy on low-end phones | Measure. Reduce `BUILD_PER_FRAME`, drop accent parts, or use Low Graphics by default on mobile |
| 7 | Anti-cheat | Speed-check tolerance may flag legitimate players (e.g. falling off ledges, lag spikes) | Watch `session.flags`. The tolerance is `GameConfig.SpeedTolerance` |
| 8 | Leaderboards | OrderedDataStore needs a published place; boards show "Be the first" until then | Publish, then wait 2 minutes |
| 9 | UI | Labels use emoji (🪙 🎒 🐿️ 📜). Roblox renders most emoji, but newer ones (e.g. 🪙, Unicode 13) may show as a box on older devices | Check in the device emulator. Swap any that fail for older emoji (`grep -rn "🪙" src` finds each use) |

## Resolved
- 2026-09-24: UI previews found that phone UI was too small (scale 0.55), badges covered labels, PC hotkey suffixes truncated labels, and toasts covered window headers. All four are fixed (see [[Testing & QA]]).
- 2026-09-24: critter followers now use HipHeight for ground height instead of a fixed `root.Y - 3`.
- 2026-09-24: roof wedges were upside down (WedgePart's tall face is at +Z). Fixed and covered by the world build test.
- 2026-09-24: UI helper keys (`StrokeThickness`, `CornerRadius`) were leaking into instance properties. Fixed and caught by the client validation test.
