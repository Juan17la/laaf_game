# Product

<!-- impeccable:product-schema 1 -->

## Platform

desktop — a native Windows game built in Godot 4.7 (Forward+). None of web / ios / android apply; the UI is drawn in Godot (Control nodes and `_draw`) at a 640×360 base viewport scaled up with `stretch/mode="viewport"`, `aspect="expand"`.

## Users

PC players of story-driven survival horror, playing **keyboard and mouse first**. Gamepad is supported (RNF-03), but layout and prompts are tuned for KB/M. The audience knows and loves Silent Hill (PSX/PS2 era) and Cry of Fear. In play they are tense, moving through fog, and glance at the HUD between threats. They need their state in a split second, not a dashboard to read.

## Product Purpose

LAAF is a third-person action / survival horror game. An outsider looking for their missing sister is marked in the isolated town of Hollowmere. Five childhood friends serve The Veil, and each one guards a zone. The game has three chapters of about 10 minutes each: stealth, hunters, the Mark meter, firearms and melee, bosses with Spare / Kill / Flee choices, minigames and five endings. Full design docs are in `maps/docs/` (EN and ES).

The UI succeeds when the player always knows the mission, their weapon and ammo, and their vitals, and nothing else pulls their eyes from the fog.

## Positioning

The game recreates the PSX/PS2 Silent Hill and Cry of Fear feel on purpose: fog, grain and dither (`shaders/ps2_post.gdshader`), CRT scanlines on the menu (`shaders/menu_crt.gdshader`), and low-poly models with painted textures. It is meant to feel nostalgic without feeling old or dated: "nostalgic, but not back in time."

## Operating Context

- The game boots into `maps/main_menu.tscn` (`scripts/main_menu.gd`, drawn with `scripts/menu_draw.gd`; the in-game pause menu is `scripts/pause_menu.gd`, sharing the Options page `scripts/options_page.gd`). Behind the menu, the real town plays staged story scenes in heavy fog with captions.
- The in-game HUD is `player/hud.gd`, with `hud_eyes.gd` (visibility eye), `threat_arcs.gd` (off-screen threats), `screen_fx.gd` (Mark and pain effects) and `guide.gd` (minimap). Settings are in `scripts/settings.gd`.
- Main menu pages: Continue, New Game, Load Game, Extra (achievements), Dev Mode, Quit, plus Difficulty (Story / Normal / Hard).
- Minigame overlays: lockpick, fishing, radio tuning, hi-lo, moth run, music box.

## Capabilities and Constraints

- The HUD must always show four things: **current objective**, **weapon + ammo**, **health + stamina**, **minimap + clock**. Everything else appears only when it matters: Mark rise, interaction prompts, subtitles, boss bar, item belt, QTEs, gas-mask filter, notes.
- The menu flow is open to change. Its structure and page flow can be rethought, not only restyled.
- Requirements in scope: RF-16 (HUD: health, stamina, Mark, clock, tokens, objective hint), RF-17 (menus: main, settings, pause, journal, map, inventory, shop, minigame overlays, ending stats), RF-18 (difficulty).
- The 640×360 base resolution means every glyph, icon and stroke must read at that size after scaling.
- Content rating target: mature horror.

## Brand Commitments

- The name is **LAAF**. The setting is Hollowmere. The terms are the Mark, The Veil, Lantern Tokens, the Harvester, and Moth (Elena).
- The vibe of Silent Hill and Cry of Fear must stay: dread, fog, grain, analog texture.
- **Binding (from the user):** the UI must not be only squares and text. It needs icons, figures, rounded and modern forms that fit the game, and it shows only the information the player needs right now: the mission, guns, weapons. It should evoke nostalgia without looking outdated. The menu should be a clear jump in quality.
- The existing per-speaker subtitle colours in `player/hud.gd` (`SPEAKERS`) identify the characters.

## Evidence on Hand

- Story-scene captions and lines for the menu are in `scripts/main_menu.gd` (`SCENES`).
- Design docs are in `maps/docs/en/*.md` and `maps/docs/es/*.md`.
- Art: low-poly GLB models in `models/`, the town map image `maps/hollowmere_map.png`, and audio in `audio/`.
- The game has no external marketing, store page, press or testimonials. Do not invent any.

## Product Principles

1. **Glance, don't read.** Each HUD element should register in under a second, with shape and icon before words.
2. **Quiet until it matters.** Contextual information enters on its event and leaves afterwards. Fog and silence are part of the design.
3. **Nostalgia through texture, modernity through craft.** Keep the grain, fog and analog feel, but the UI itself should have current-generation clarity, motion and polish.
4. **One world.** The menu, HUD, overlays and minigames share one visual language.

## Accessibility & Inclusion

From RNF-04 and RNF-05: English and Spanish localization (text and subtitles), subtitles, a colorblind-safe HUD (no meaning conveyed by colour alone), a toggle-or-hold option, a camera-shake-off option, and a hint toggle.
