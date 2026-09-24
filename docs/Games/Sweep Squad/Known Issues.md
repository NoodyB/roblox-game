---
tags: [bugs]
updated: 2026-09-24
---
# Known issues and risks

No gameplay has run inside Roblox yet, so the items below are **risks to verify first** in Studio, ordered by likelihood.

| # | Area | Risk | How to verify / fix |
|---|---|---|---|
| 1 | Gear | The vacuum or bag offset on the hand or back may look wrong for some avatar scales or R6 rigs | Play with an R15 and an R6 avatar. Tweak the `grip` and `back` offsets in `World/GearModels.luau` |
| 2 | Critters | Followers use `root.Y - 3` as ground height, so they may float or sink on scaled avatars | Use the Humanoid HipHeight if needed (`Controllers/CritterFollowers.luau`) |
| 3 | UI | Text sizes and spacing at phone resolutions were designed, not seen | Device emulator, then real phone. Adjust `UI/Responsive.luau` scale bounds |
| 4 | Audio | `rbxasset://sounds/clickfast.wav`, `swoosh.wav` and `uuhhh.mp3` are assumed built-ins | If Output warns that assets failed to load, swap the IDs in `Config/Sounds.luau` |
| 5 | Analytics | `AnalyticsService` method signatures may differ slightly | Calls are pcall-wrapped. Check Creator Dashboard → Analytics → Funnels after a test |
| 6 | Debris | 876 parts per zone may be heavy on low-end phones | Measure. Reduce `BUILD_PER_FRAME`, drop accent parts, or use Low Graphics by default on mobile |
| 7 | Anti-cheat | Speed-check tolerance may flag legitimate players (e.g. falling off ledges, lag spikes) | Watch `session.flags`. The tolerance is `GameConfig.SpeedTolerance` |
| 8 | Leaderboards | OrderedDataStore needs a published place; boards show "Be the first" until then | Publish, then wait 2 minutes |

## Resolved
- 2026-09-24: roof wedges were upside down (WedgePart's tall face is at +Z). Fixed and covered by the world build test.
- 2026-09-24: UI helper keys (`StrokeThickness`, `CornerRadius`) were leaking into instance properties. Fixed and caught by the client validation test.
