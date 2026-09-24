---
tags: [assets, audio]
updated: 2026-09-24
---
# Assets and audio

## Current state
- **3D:** 100% procedural primitives: 26 prop kinds, 8 landmarks, 24 critters, 12 vacuum tiers and 12 bag tiers. **No uploads are needed** and there are no licensing questions.
- **UI:** code-built frames plus emoji glyphs. No image assets.
- **Sounds:** built-in `rbxasset://sounds/*` client files (placeholders that ship with Roblox).
- **Music:** none (`Config/Sounds.luau` → `Music.id = ""`).
- **Promo art:** concept icon and thumbnails in `marketing/`, generated from `marketing/src/assets.html` with `NODE_PATH=$(npm root -g) node marketing/src/render.js`.

## Recommended upgrades (need your Roblox account)
| Asset | Why | How |
|---|---|---|
| Background music | Cozy loop; big effect on feel and session length | Creator Store → Audio, filtered to "Music" and licensed for Roblox use. Paste the ID into `Sounds.Music.id` |
| Collect "pop" and sell "cha-ching" sounds | More satisfying feedback | Creator Store sound effects. Test the volume on phones |
| Game icon | Required to publish | `marketing/icon_512.png`, or commission art later |
| Thumbnails | Click-through rate is the #1 discovery signal | Take in-game screenshots in Studio. To hide the HUD during Play, set `Players → you → PlayerGui → SweepHUD → Enabled = false` in the Explorer. Add a title in any image editor, or use the concepts in `marketing/` |
| Pass and product icons | Nicer store cards | 512×512 images with one emoji-style symbol each |

**Only use assets you own, or that the Creator Store marks as usable in experiences.** Do not copy art, logos or music from other games.
