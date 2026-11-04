# LAAF — Project Documentation

| | |
|---|---|
| Product | LAAF |
| Type | Desktop video game, third-person action / survival horror |
| Version | 1.1.0 (see `build/`) |
| Engine | Godot 4.7, Forward+ renderer, Jolt physics, GDScript |
| Platforms | Windows 10/11 (x86-64), Linux (x86-64) |
| Languages | English, Spanish |
| Document status | Living document. It describes the game **as built** and marks every requirement that is not yet met |

Related documents: [README](../README.md) · [Product brief](../PRODUCT.md) · [Design system](../DESIGN.md) · [Game design docs](../maps/docs/requirements.md) · [UI design planning](design-planning/mockups.html)

---

## Contents

1. [Introduction](#1-introduction)
2. [Product overview](#2-product-overview)
3. [Users and stakeholders](#3-users-and-stakeholders)
4. [Features](#4-features)
5. [Functional requirements](#5-functional-requirements)
6. [Non-functional requirements](#6-non-functional-requirements)
7. [Use cases](#7-use-cases)
8. [Screens and navigation](#8-screens-and-navigation)
9. [Architecture](#9-architecture)
10. [Data and persistence](#10-data-and-persistence)
11. [Quality assurance](#11-quality-assurance)
12. [Build and distribution](#12-build-and-distribution)
13. [Known gaps and roadmap](#13-known-gaps-and-roadmap)
14. [Glossary](#14-glossary)

---

## 1. Introduction

### 1.1 Purpose

This document is the main reference for LAAF. It explains what the game is, which features it has, which functional and non-functional requirements it must meet, and how players use it. It is written for:

- **Developers**, who need to know where each feature lives and what it must do.
- **Designers and reviewers**, who check the interface and the experience against the requirements.
- **Testers**, who turn the use cases into test scenarios.
- **Course evaluators and new contributors**, who need a fast, complete picture of the project.

### 1.2 Scope

The scope is the shipped game: the main menu, the in-game interface (HUD, pause menu, inventory, selection wheel, minigame overlays), the three playable chapters, saving, settings, localization and accessibility. The original design called for an 8-chapter campaign with a free day/night cycle and a shop. That design is kept in `maps/docs/` for reference. Where the shipped game differs from it, this document says so.

### 1.3 Conventions

- **RF-nn** is a functional requirement and **RNF-nn** a non-functional one. The IDs match `maps/docs/requirements.md`, so requirements stay traceable. Requirements added for the interface are numbered from RF-19 and RNF-09.
- **UC-nn** is a use case.
- **Status:** ✅ Implemented · 🟡 Partial or adapted (the note says how) · ⏳ Planned (not in the build).
- **Priority (MoSCoW):** Must, Should, Could.
- Measurements for the interface are in **base pixels** of the game's 640×360 design canvas (see RNF-10).

---

## 2. Product overview

### 2.1 Concept

Alex drives into the isolated lake town of **Hollowmere** looking for their missing sister, **Lucía**. On the first night a shape at the motel window brands Alex's hand with the **Veil's Eye**: Alex is *marked*. Five childhood friends serve a cult called **The Veil**, and each one hunts a part of the town. One of them, **Elena ("Moth")**, secretly helps Alex over the radio until the group executes her. At the end Alex reaches the quarry chapel where the marked are taken, and faces **The Harvester**, the Veil's executioner.

### 2.2 The core loop

```
Explore ─► get hunted ─► hide or escape ─► fight when forced ─► decide each hunter's fate
   ▲                                                                       │
   └──────────── new mission step, new zone, new mechanic ◄────────────────┘
```

The game is not about collecting good items and avoiding bad ones. Tension comes from being watched. The **Mark meter** rises at night and when Alex is seen or caught, and the higher it climbs, the more the town turns against Alex.

### 2.3 Structure

| Chapter | Title | Zones | Main mission | Hunters and bosses | Closes with |
|---|---|---|---|---|---|
| I | **The Mark** | Bridge, motel, forest edge, square, sawmill | Survive the first night, get key part 1 | Owen (hunt, then boss) | The 03:00 blackout and the first sight of The Harvester |
| II | **Moth** | Harbor, lighthouse, school, clinic | Meet Elena, get key parts 2 and 3 | Nora and Julian (either order) | Elena's execution at the church |
| III | **The Veil** | Cemetery, church, lighthouse, quarry, chapel | Escape the group, take the chapel key, reach Lucía | Marcus, **The Harvester** | One of five endings, then the epilogue *Pop. 1413* |

Each chapter follows the same pattern: an opening cinematic, then main missions, then optional side missions and minigames, then a hunter or boss encounter, then a closing cinematic with a chapter card.

### 2.4 What makes it distinct

- **The PSX/PS2 horror look, done on purpose.** Fog, film grain, 4×4 Bayer dither, a vignette and low-poly models with painted textures, applied as a post-process (`shaders/ps2_post.gdshader`).
- **A case-file interface.** Every menu is a dark dossier folder with index tabs, set down over the live, foggy town. The interface is drawn (rounded shapes and stroke icons), never just squares of text.
- **Moral choices with consequences.** Each defeated hunter can be spared or killed. The choices decide which allies show up in the final fight and which of the five endings plays.
- **Short and replayable.** About 30 minutes on the critical path. Achievements and endings reward replaying.

---

## 3. Users and stakeholders

### 3.1 Target audience

PC players of story-driven survival horror, aged 18 and over, who know and love the PSX/PS2 *Silent Hill* games and *Cry of Fear*. They play with keyboard and mouse first. They want dread and atmosphere more than action, and they appreciate a short game they can finish in one evening. The full audience profile is in [product-vision.html](design-planning/product-vision.html).

### 3.2 Personas

| Persona | Profile | Needs from LAAF |
|---|---|---|
| **The Nostalgic Fan** (28, plays on PC since the PS2 era) | Replays classic horror games, notices fog and sound design | An authentic retro mood without dated controls or an unreadable UI |
| **The Story Seeker** (24, plays narrative indies) | Plays on Easy, reads every note, wants all the endings | Clear objectives, subtitles, a forgiving difficulty, the evidence log, achievements |
| **The Challenge Player** (31, speedruns and plays on hard) | Plays on Hard, wants mechanics to master | Weak points, the double tap, no-damage runs, the Nightmare achievement |
| **The Accessibility-Dependent Player** (35, sensitive to motion, hard of hearing) | Needs comfort options before playing | Shake, hit-stop and screen effects that can be turned off, large subtitles with a backing, toggle instead of hold |

### 3.3 Stakeholders

| Stakeholder | Interest |
|---|---|
| Players | A complete, stable, readable and frightening game |
| Developer (Juan17la) | A maintainable codebase, a clear design system and tests that stay green |
| Course evaluators (Interface Design) | A documented, well-reasoned UI with mockups, a design system and a navigation flow |
| Translators | A clean `.pot` catalogue and a glossary (`locale/glossary.md`) |

---

## 4. Features

### 4.1 Main menu (title screen and dossier)

- **Title screen.** The LAAF logo over the live town, which plays staged story scenes (11 s each) with italic captions under a CRT scanline pass. A pulsing *PRESS ANY KEY* pill.
- **The dossier.** Any key slides a folder in from the right, and the logo drifts to the top left. Seven index tabs:

| Tab | Page | What it does |
|---|---|---|
| CONTINUE | The latest save as a case file | A pinned map print showing where you left off, the chapter, chips for time, difficulty and Mark, the weapons carried, the NEXT objective, and a **RESUME** bar. With no save, an honest empty state and a **NEW CASE** bar |
| NEW | A new case | Three difficulty rows (flames 1–3) with blurbs and live meters for *damage you take*, *enemy toughness* and *ammo you find*. **BEGIN** starts Chapter I |
| LOAD | Every save, newest first | Rows with a map thumbnail and pin, chapter and objective, save kind, difficulty, play time and date. Six visible, then a scroll |
| EXTRA | Achievements | 13 achievement rings in a 4-column grid, a progress track and the selected achievement's name and condition |
| OPTIONS | Settings | The shared Options page (see 4.7) |
| DEV | Developer jumps | Start any step of any chapter, optionally with all evidence or a set Mark. Nothing is saved |
| QUIT | Leave Hollowmere? | A photo print of where you'd be leaving off and a **QUIT TO DESKTOP** bar |

- **Leaf-turn transition** between pages (0.18 s), a keycap help bar in the bottom letterbox that changes with focus, full mouse support (point, click, right-click back, wheel), keyboard and gamepad.

### 4.2 In-game HUD

The HUD always shows four things and shows everything else only when it matters.

| Always on | Where | Detail |
|---|---|---|
| Objective | Top left | A panel with an amber edge. The new objective is shown in full for 6 s, then fades to shadowed text |
| Health and stamina | Bottom left | A heart with a 5px pill health track and a trail that drains after hits (the heart beats under 30%). A stamina pill shown only while stamina is spent |
| Weapon and ammo | Bottom right | A 150×36 card with the rendered icon, name, magazine pips and `loaded / reserve` |
| Minimap and clock | Top right | Compass, minimap (`player/guide.gd`) and the in-game clock |

| Contextual | Appears when |
|---|---|
| Visibility eye | Stealth matters (can be turned off) |
| *MARK +N%* notice | The Mark rises. Rises close together merge |
| Interaction prompt | Something can be used (*E Talk to Grady*) |
| Subtitles | A line is spoken. Each speaker has a colour **and** a name |
| Toasts / notes | Pickups, saves, tips |
| Item belt | Bottles, smoke cans and tea are carried (with quick-key keycaps) |
| Gas-mask filter | The mask is owned |
| Boss bar | During a boss fight |
| QTE prompt | Cranks, struggles and similar scripted actions |
| Off-screen threat arcs, alert icons (? and !) | Enemies notice Alex (both can be turned off) |
| Screen effects | Mark vignette and pulse, red hurt edges (both have intensity sliders) |

### 4.3 Pause menu

Esc or Start. The game freezes behind a blur and the dossier shows *Paused*: the chapter, chips for time, difficulty and the exact Mark (to a tenth), the NEXT objective, and three rows: **Save game**, **Options**, **Main menu**. The **RESUME** bar sits at the foot. Save game is greyed out with a reason when saving is not allowed (dev runs, cinematics). Main menu asks for confirmation first on its own page, which shows the map print of where you'd leave off.

### 4.4 Inventory

I or Back opens the inventory; M opens it on the Map tab. It pauses the game. It has five index tabs:

- **Weapons:** fists and every weapon carried, with a description, damage and rounds. **EQUIP** puts one in hand.
- **Items:** bottles, smoke cans, Elena's tea (**DRINK**), the gas mask (**PUT ON / TAKE OFF**) and its filter, the headlamp, Lantern Tokens.
- **Key items:** gate key parts (x / 3), the chapel key, each hunter's keepsake, Elena's jacket and tea tins.
- **Evidence:** a 6 × 2 grid of the 12 pieces. Missing ones show as ???. Progress x / 12.
- **Map:** the town on paper, where Alex is, the objective and how far it is.

### 4.5 Selection wheel

Hold Tab (or Y). Time slows to 25% and the screen goes grey and blurred. A ring of wedges holds the fists at the top, every weapon clockwise in number-key order, then the items Alex holds. Point with the mouse or stick and release to equip or use. Right click or B cancels. The hub shows the verb (EQUIP, DRINK, THROW…), the name and the quick key. A line underneath explains what the item does or why it can't be used.

### 4.6 Minigames

| Minigame | Where | Mechanic | Script |
|---|---|---|---|
| Radio tuning | Motel Room 6, lighthouse | Turn the dial until the static clears and hold the signal | `scripts/radio_tuning.gd` |
| Lockpicking | Doors, lockers, pharmacy, cages | Find each pin's sweet spot and lift it to the shear line before the tension breaks the pick | `scripts/lockpick.gd` |
| Shooting gallery | Town square | Knock down the 5 tin moths | `scripts/chapter1.gd` |
| Fishing | Harbor dock | Charge the cast, hook on the bite, reel while managing the line's tension | `scripts/fishing.gd` |
| Lantern Hi-Lo | The Drowned Lantern bar, vs Silas | Bet, then call higher or lower. Chains multiply the stake; the Veil card loses it. 10 hands a night | `scripts/hilo.gd` |
| Moth Run | Diner arcade cabinet | A 2D runner: steer the moth to lanterns and away from hands. A hidden message from Elena appears at 10,000 points | `scripts/moth_run.gd` |

Every minigame is an overlay drawn in the same visual language, and every one can be quit at any time with Esc or B.

### 4.7 Options

One page, shared by the main menu and the pause menu. Every change applies immediately and is saved to `user://settings.cfg`. *Reset to defaults* asks for confirmation first.

| Group | Settings |
|---|---|
| General | Language (English / Español, defaulting to the OS language), control tips |
| Audio | Master, music, sound effects, voices (0–100%) |
| Subtitles | Subtitles on/off, size (Normal / Large / Larger), backing opacity |
| Controls | Mouse and gamepad look sensitivity (×0.2–×3.0), invert Y, run toggle, aim toggle |
| Gameplay & accessibility | Camera shake, hit-stop, Mark screen effects, hurt screen edges (0–100%); Mark whispers, Mark sightings, enemy alert icons, off-screen threat arcs, visibility eye (on/off) |
| Video | Display (window, borderless, exclusive fullscreen), VSync, render resolution (100 / 75 / 50%), brightness, film grain and vignette |

### 4.8 Gameplay systems

- **Movement:** walk, sprint, crouch and sneak, a dodge roll with invulnerability frames, a slide, jumping and climbing low walls (with coyote time and input buffering), and a shoulder swap.
- **Stealth:** noise radii per action and surface, visibility from light, movement and distance, hiding in tall grass, bottle distractions, smoke clouds that block sight.
- **Enemies:** a state machine (patrol, suspicious, chase, search, stunned, down, dead), alert icons, enemies that adapt to repeated tactics (*THEY ADAPT* notes), Marked Ones as regular enemies.
- **Combat:** fists (combo jabs), fire axe, nail bat, revolver, flare gun, shotgun and Owen's bow. Arm IK aims at the crosshair. The **double tap** (swap and fire within 0.45 s) deals +50%.
- **Bosses:** Owen (fire stuns him), Nora (fight her in the dark), Julian (reversed gas), Marcus (drop the bells on him) and The Harvester (a 900 HP, 3-phase fight against light). After each hunter, the player chooses **Spare** or **Kill**.
- **The Mark:** 0–100%. It rises at night and when Alex is seen or caught. Whispers start past 25%, hunters sense Alex past 50%, sightings appear past 70%. Elena's tea lowers it by 15%.
- **Endings:** *Run*, *Signal*, *Unveiled*, *The New Eye*, *Mixed*, decided by the flags (`Chapter3Director.pick_ending`).
- **Achievements:** 13, kept across runs in `user://achievements.cfg`.

---

## 5. Functional requirements

### 5.1 Game systems (from the game design)

| ID | Requirement | Priority | Status | Notes / where |
|---|---|---|---|---|
| RF-01 | Third-person controller: walk, sprint, crouch, dodge, climb low walls | Must | ✅ | Also slide, jump with coyote time, shoulder swap. `player/player.gd` |
| RF-02 | Stealth: noise radius, visibility by light and movement, hiding spots, distractions | Must | ✅ | Hiding in tall grass, bottles, smoke cans. `player.gd` `noise`, `player/hud_eyes.gd` |
| RF-03 | Hunter AI state machine: patrol, suspicious, hunt, chase, search, stunned | Must | ✅ | `scripts/enemy.gd` `State` (*hunt* is folded into chase and search by night) |
| RF-04 | Each zone has exactly one owner hunter with a unique weakness | Must | ✅ | Owen: fire · Nora: darkness and the power room · Julian: reversed vents · Marcus: bells |
| RF-05 | Melee, firearms, throwables; regular enemies (Marked Ones) | Must | ✅ | `player/weapons.gd` |
| RF-06 | Boss fights with a Spare / Kill resolution and a Flee exit | Must | 🟡 | Spare and Kill are in. The mid-fight Flee exit is not built yet |
| RF-07 | Mark meter (0–100%) with effects and the *Taken* sequence | Must | ✅ | Effects at 25/50/70/100%. In Chapter III it is capped at 99% while Alex is in control |
| RF-08 | Day/night cycle with the nightly blackout at 03:00 | Should | 🟡 | Adapted to the 3-chapter structure: each chapter runs on fixed clock beats and the 03:00 blackout is scripted |
| RF-09 | Traitor storyline: radio calls, notes, meetings, scripted execution | Must | ✅ | Executed at the end of Chapter II (originally Chapter 6) |
| RF-10 | Six minigames: lockpicking, fishing, arcade, card game, shooting gallery, radio tuning | Should | ✅ | See 4.6 |
| RF-11 | Currency (Lantern Tokens) with daily minigame limits | Should | 🟡 | Tokens are earned and shown in the inventory. Only Hi-Lo enforces a limit (10 hands a night) |
| RF-12 | Shop with permanent upgrades, weapons, mods and supplies | Could | ⏳ | Grady hands Alex the story items. There is no shop screen |
| RF-13 | 12 evidence collectibles and a journal | Should | 🟡 | All 12 pieces are in the inventory's Evidence tab. There is no separate journal |
| RF-14 | Five endings evaluated from flags | Must | ✅ | Priority: Run > Signal > Unveiled > New Eye > Mixed |
| RF-15 | Save system: slots, manual saves in safe places, autosave on zone entry and after bosses | Must | 🟡 | Manual saves from the pause menu (one new file per save, no slot limit) and a 6-file autosave ring at mission steps. See §10 |
| RF-16 | HUD: health, stamina, Mark, clock, tokens, objective hint | Must | ✅ | The Mark shows as a notice (exact value in pause). Tokens are in the inventory |
| RF-17 | Menus: main, settings, pause, journal, map, inventory, shop, minigame overlays, ending stats | Must | 🟡 | Built: main, settings, pause, map, inventory, overlays. Planned: journal, shop, ending stats screen |
| RF-18 | Three difficulty levels | Must | ✅ | Easy / Normal / Hard (named *Story / Normal / Hard* in the design) |

### 5.2 Interface requirements

| ID | Requirement | Priority | Status |
|---|---|---|---|
| RF-19 | The game shall boot into a title screen that plays live story scenes of the town behind the logo and waits for any key | Must | ✅ |
| RF-20 | The main menu shall offer Continue, New, Load, Extra, Options, Dev and Quit as index tabs of one folder | Must | ✅ |
| RF-21 | Continue shall resume the newest save in one action and show where, when, the difficulty, the Mark, the weapons and the next objective | Must | ✅ |
| RF-22 | With no saves, Continue and Load shall show an honest empty state and Continue shall offer to start a new case | Must | ✅ |
| RF-23 | New shall let the player pick a difficulty and see its effect (damage taken, enemy toughness, ammo found) before starting | Must | ✅ |
| RF-24 | Load shall list every save, newest first, with a map thumbnail, chapter, objective, save kind, difficulty, play time and date | Must | ✅ |
| RF-25 | Extra shall show every achievement, locked or earned, with its condition and the overall progress | Should | ✅ |
| RF-26 | Quit shall ask for confirmation and say that saves are kept | Must | ✅ |
| RF-27 | Pause shall freeze the game and offer Resume, Save game, Options and Main menu. A save that is not allowed shall be greyed out with the reason | Must | ✅ |
| RF-28 | Leaving a run for the main menu shall ask first and warn that unsaved progress is lost | Must | ✅ |
| RF-29 | Options shall apply every change immediately, persist it, and offer a confirmed reset to defaults | Must | ✅ |
| RF-30 | The inventory shall let the player equip weapons and use items (drink, put on, switch) under the same rules as the hotkeys | Must | ✅ |
| RF-31 | The selection wheel shall slow time, list weapons and items, and equip or use the pointed one on release, with a cancel | Should | ✅ |
| RF-32 | Every menu shall work with mouse, keyboard and gamepad: pointing selects, a click acts like Enter, a right click goes back like Esc | Must | ✅ |
| RF-33 | A help bar shall always show the keys that work on the current page and focus, for the device used last | Must | ✅ |
| RF-34 | The HUD shall show the objective, the weapon and ammo, health and stamina, and the minimap and clock at all times during play, and everything else only on its event | Must | ✅ |
| RF-35 | Every minigame shall be quittable at any time without other penalty | Must | ✅ |
| RF-36 | Interaction prompts shall name the action and the key (*E Talk to Grady*) | Must | ✅ |

---

## 6. Non-functional requirements

| ID | Category | Requirement | Measure / acceptance | Status |
|---|---|---|---|---|
| RNF-01 | Technology | Godot 4.7, Forward+ renderer, Jolt physics | `project.godot` | ✅ |
| RNF-02 | Performance | 60 FPS at 1080p on mid-range hardware; at least 30 FPS on low-end | A render-scale option (100/75/50%) keeps the UI crisp at lower 3D resolutions | ✅ (target) |
| RNF-03 | Input | Keyboard/mouse and gamepad, with full rebinding | Both devices work everywhere. **Rebinding is not built** | 🟡 |
| RNF-04 | Localization | English and Spanish, text and subtitles | `locale/es.po` (~1,180 strings), `tests/l10n_test.gd`; the OS language is the default | ✅ |
| RNF-05 | Accessibility | Subtitles, colour-blind-safe HUD, toggle vs hold, camera shake off, hint toggle | See 4.7. No meaning carried by colour alone: every state also has an icon, shape or word | ✅ |
| RNF-06 | Loading | Zone loading under 10 s on SSD; smooth transitions | One world scene (`maps/hollowmere.tscn`); chapters and zones are steps inside it | ✅ |
| RNF-07 | Persistence | Save files human-readable and versioned | Saves are Godot binary (`store_var`) and not versioned. **Deviation**; settings and achievements are readable `ConfigFile`s | 🟡 |
| RNF-08 | Content | Mature rating (violence, horror); no gore close-ups in executions | Executions cut away | ✅ |
| RNF-09 | Usability | Glance, don't read: each HUD element registers in under a second, shape and icon before words | Design principle 1 (PRODUCT.md) | ✅ |
| RNF-10 | Legibility | All UI is designed on a 640×360 base canvas. No functional text below 7 base px | Menus draw in `canvas_items` scale so type stays sharp at any window size | 🟡 (keycaps at 6px, see DESIGN.md *Known drift*) |
| RNF-11 | Consistency | Menu, HUD, wheel and overlays share one visual language (palette, two typefaces, one icon set) | `scripts/menu_draw.gd`, `scripts/icons.gd` | ✅ |
| RNF-12 | Responsiveness | Menus respond to input within one frame; page transitions are 0.18 s and never block input | Leaf turn and title transition timings in DESIGN.md | ✅ |
| RNF-13 | Robustness | Menus never crash on missing data (no saves, no player, no game in tests); they show empty states instead | Null-safe pause and inventory menus; `tests/menu_mouse_test.gd` | ✅ |
| RNF-14 | Maintainability | Settings are one data table (`Settings.ROWS`): adding a setting is one row plus one line in `apply()` | `scripts/settings.gd` | ✅ |
| RNF-15 | Testability | Core systems are covered by headless tests that run in CI or locally | 30+ tests in `tests/` | ✅ |
| RNF-16 | Portability | Installable on Windows (setup.exe) and Linux (tarball + script) | `installer/` | ✅ |
| RNF-17 | Privacy | No telemetry, no accounts. All data stays in the user's folder. The one network call is the final report's: with a Groq key set, as it is in release builds, it sends that run's numbers (no identity, no saves) to Groq for its closing text | `scripts/groq.gd`; with no key the game never touches the network | ✅ |
| RNF-18 | Licensing | Bundled fonts are OFL; licences ship with them | `fonts/OFL_*.txt` | ✅ |

---

## 7. Use cases

### 7.1 Actors

| Actor | Description |
|---|---|
| **Player** | The person playing the game, with keyboard and mouse or a gamepad |
| **Developer** | A team member using the Dev tab or command-line jumps to test content |
| **Game system** | The engine and the game's directors (autosave, cinematics, enemy AI) acting on their own |

### 7.2 Use case diagram (summary)

```
                    ┌───────────────────────── LAAF ─────────────────────────┐
                    │  UC-01 Start a new game        UC-09 Use the wheel      │
                    │  UC-02 Continue                UC-10 Play a minigame    │
     Player ───────►│  UC-03 Load a save             UC-11 Hide from a hunter │
                    │  UC-04 Change settings         UC-12 Resolve a boss     │
                    │  UC-05 View achievements       UC-13 Lower the Mark     │
                    │  UC-06 Pause and save          UC-14 Quit the game      │
                    │  UC-07 Leave for main menu                              │
                    │  UC-08 Use the inventory/map                            │
   Developer ──────►│  UC-15 Jump to a chapter step                           │
 Game system ──────►│  UC-16 Autosave                                         │
                    └─────────────────────────────────────────────────────────┘
```

### 7.3 Use case specifications

#### UC-01 — Start a new game
| | |
|---|---|
| Actor | Player |
| Goal | Begin the story from Chapter I at a chosen difficulty |
| Preconditions | The game is on the title screen or the dossier |
| Trigger | The player opens the **NEW** tab |
| Main flow | 1. The system shows *A new case*, its lede and three difficulty rows, with the current difficulty selected. 2. The player moves between rows; the meters update live. 3. The player confirms **BEGIN** (Enter, a click or A). 4. The system stores the difficulty, starts a story run at the *intro* step and loads the town. 5. The opening cinematic *Last Postcard* plays |
| Alternative flows | 2a. Esc or a right click returns focus to the tabs without starting |
| Postconditions | A story run is active; saves and achievements are enabled |
| Requirements | RF-18, RF-23 |

#### UC-02 — Continue the latest game
| | |
|---|---|
| Actor | Player |
| Preconditions | At least one save exists |
| Main flow | 1. The system opens on **CONTINUE**, showing the newest save as a case file (map print, chapter, time, difficulty, Mark, weapons, NEXT). 2. The player confirms **RESUME**. 3. The system restores the save's step, difficulty, player state and position |
| Alternative flows | 1a. **No save exists:** the page shows *No case open* and a **NEW CASE** bar; confirming it opens the NEW tab with the difficulty rows focused (UC-01) |
| Postconditions | The run continues where it was saved |
| Requirements | RF-21, RF-22 |

#### UC-03 — Load a save
| | |
|---|---|
| Actor | Player |
| Preconditions | At least one save exists |
| Main flow | 1. The player opens **LOAD**. 2. The system lists every save, newest first, with a map thumbnail, title and meta line. 3. The player selects a row (keys, mouse or wheel to scroll). 4. The player confirms. 5. The system loads that save as in UC-02 step 3 |
| Alternative flows | 2a. No saves: *Nothing saved yet…* and no list |
| Requirements | RF-15, RF-24 |

#### UC-04 — Change a setting
| | |
|---|---|
| Actor | Player |
| Preconditions | The player is on **OPTIONS** in the main menu, or on *Options* in the pause menu |
| Main flow | 1. The system lists the settings under group headers, with their current values. 2. The player selects a row; the help bar shows what A/D does to it. 3. The player adjusts it (A/D, Enter, a click, dragging a meter, or the wheel). 4. The system applies the value at once (volume, language, display…) and writes `settings.cfg` |
| Alternative flows | 3a. **Reset to defaults:** the first press arms it and asks; the second press resets everything |
| Postconditions | The setting is in effect now and on the next launch |
| Requirements | RF-29, RNF-04, RNF-05 |

#### UC-05 — View achievements
| | |
|---|---|
| Actor | Player |
| Main flow | 1. The player opens **EXTRA**. 2. The system shows *Extra*, *n of 13* and the progress track. 3. The player moves over the rings; the system shows the name (or *Locked*) and the condition |
| Requirements | RF-25 |

#### UC-06 — Pause and save
| | |
|---|---|
| Actor | Player |
| Preconditions | A run is active and Alex is in control |
| Main flow | 1. The player presses Esc or Start. 2. The system freezes the game, blurs it, and shows the pause dossier with RESUME selected. 3. The player chooses **Save game**. 4. The system writes a new manual save and shows *Saved.* 5. The player chooses **RESUME** (or Esc); the game continues on the release of the button |
| Alternative flows | 3a. Saving is not allowed (dev run, no control): the row is greyed out, says why, and is skipped by the selection |
| Requirements | RF-15, RF-27 |

#### UC-07 — Leave a run for the main menu
| | |
|---|---|
| Actor | Player |
| Preconditions | The pause menu is open |
| Main flow | 1. The player chooses **Main menu**. 2. The system turns to *Leave this run?*, which warns that anything since the last save is lost and shows the map print of the current place. 3. The player confirms **MAIN MENU**. 4. The system unpauses, stops the music and loads the title screen |
| Alternative flows | 3a. Esc returns to the pause page |
| Requirements | RF-28 |

#### UC-08 — Use the inventory and map
| | |
|---|---|
| Actor | Player |
| Preconditions | Alex is in control (not in a cinematic, a minigame or death) |
| Main flow | 1. The player presses I (or M for the map). 2. The system pauses and opens the inventory on Weapons (or Map). 3. The player changes tabs with Q/E, LB/RB or a click. 4. The player selects an entry; the detail card shows its icon, name, chips, description and action. 5. The player confirms the action (EQUIP, DRINK, PUT ON…). 6. The system applies it under the hotkeys' rules |
| Alternative flows | 5a. The action is not possible (*The Mark is already clear*): a fainter slip says why. 6a. Esc, I, B or a right click closes and resumes |
| Requirements | RF-13, RF-30 |

#### UC-09 — Pick a weapon or item with the wheel
| | |
|---|---|
| Actor | Player |
| Main flow | 1. The player holds Tab (or Y). 2. Time slows to 25% and the wheel fades in over a grey frame. 3. The player points at a wedge; the hub shows the verb, name and quick key. 4. The player releases; the system equips or uses it |
| Alternative flows | 3a. Right click or B cancels and nothing changes. 3b. The item can't be used: the line under the ring says why in rust |
| Requirements | RF-31 |

#### UC-10 — Play a minigame
| | |
|---|---|
| Actor | Player |
| Preconditions | Alex stands at a minigame spot (radio, lock, dock, bar table, cabinet) |
| Main flow | 1. The prompt names it; the player presses E. 2. The system opens the minigame overlay with its instructions. 3. The player plays. 4. On success the system grants the reward (story progress, evidence, tokens, an achievement) and closes the overlay |
| Alternative flows | 3a. The player quits with Esc or B: the round is lost, nothing else. 3b. Failure (a broken pick, a snapped line, a lost stake) follows the game's rules |
| Requirements | RF-10, RF-35 |

#### UC-11 — Hide from a hunter
| | |
|---|---|
| Actor | Player; Game system (enemy AI) |
| Main flow | 1. A hunter patrols nearby; the visibility eye shows how exposed Alex is. 2. The player crouches into tall grass or the shadows and moves quietly. 3. The enemy loses track and returns to patrol |
| Alternative flows | 2a. The enemy notices: a "?" icon, then it investigates. 2b. Alex is seen: a "!" icon, threat arcs and a chase. Escape by breaking line of sight, a smoke can or a bottle thrown elsewhere. 2c. Alex is caught: damage and Mark +15% (never death in the Chapter I hunt) |
| Requirements | RF-02, RF-03 |

#### UC-12 — Resolve a boss
| | |
|---|---|
| Actor | Player |
| Main flow | 1. The boss bar shows the hunter's name and health. 2. The player exploits the weakness (fire, the dark, gas, bells, light). 3. At 0 HP the hunter kneels; prompts offer **Spare** (hold interact) or **Kill**. 4. The system records the choice, plays the scene and gives the rewards (key part, chapel key) |
| Postconditions | The hunter's flag is *spared* or *killed*; it changes allies in the finale and the ending |
| Requirements | RF-04, RF-06, RF-14 |

#### UC-13 — Lower the Mark
| | |
|---|---|
| Actor | Player |
| Preconditions | Alex carries Elena's tea and the Mark is above 0 |
| Main flow | 1. The player presses H, or chooses DRINK in the inventory or the wheel. 2. The system lowers the Mark by 15% and plays the effect |
| Alternative flows | 1a. The Mark is already clear: the action is refused with that reason |
| Requirements | RF-07 |

#### UC-14 — Quit the game
| | |
|---|---|
| Actor | Player |
| Main flow | 1. The player opens **QUIT**. 2. The system shows *Leave Hollowmere?* and where you'd leave off. 3. The player confirms **QUIT TO DESKTOP**; the application closes |
| Alternative flows | 2a. Esc returns to the tabs |
| Requirements | RF-26 |

#### UC-15 — Jump to a chapter step (developer)
| | |
|---|---|
| Actor | Developer |
| Main flow | 1. The developer opens **DEV**. 2. They toggle *All 12 evidence* or cycle *Start Mark* if needed. 3. They pick a step (*II · Zones*). 4. The system starts a dev run on Normal at that step |
| Postconditions | The run is not saved and unlocks nothing |

#### UC-16 — Autosave
| | |
|---|---|
| Actor | Game system |
| Trigger | A mission step begins (`Game.at_step`) in a story run |
| Main flow | 1. The system takes a snapshot (step, difficulty, run, player, weapons, position, flags). 2. It writes the oldest of the 6 autosave files. 3. No notification is shown |
| Requirements | RF-15 |

---

## 8. Screens and navigation

The full interactive map, with every transition and its key, is in [navigation-flow.html](design-planning/navigation-flow.html). In summary:

```
Boot ─► Title (PRESS ANY KEY) ─► Dossier [CONTINUE | NEW | LOAD | EXTRA | OPTIONS | DEV | QUIT]
                                     │ RESUME / BEGIN / load / dev step            └─► Desktop
                                     ▼
                                Gameplay (HUD) ──Esc──► Pause [Save · Options · Main menu ─► Leave? ─► Title]
                                     │  ├──I / M──► Inventory [WEAPONS | ITEMS | KEYS | EVIDENCE | MAP]
                                     │  ├──hold Tab──► Selection wheel
                                     │  ├──E at a spot──► Minigame overlay
                                     │  └──story──► Cinematics, boss choice, endings, epilogue
```

---

## 9. Architecture

### 9.1 Overview

```
            ┌────────────── Autoloads (always alive) ──────────────┐
            │ Game (scripts/game.gd)  runs, saves, pause, inventory │
            │ Snd / Audio             music and sound effects       │
            └───────────────────────────────────────────────────────┘
   main_menu.tscn ──Game.start()──► hollowmere.tscn ──Game.to_menu()──► main_menu.tscn
                                         │
                       Chapter director (chapter1/2/3.gd): steps, objectives, cinematics
                       Player (player/player.gd): movement, weapons, Mark, HUD
                       Enemies (enemy.gd, harvester.gd), interactables, minigames
```

### 9.2 Main modules

| Module | Files | Responsibility |
|---|---|---|
| Game flow | `scripts/game.gd` | Starts runs, saves and loads, pause and inventory layers, achievements, difficulty |
| Chapters | `scripts/chapter1.gd`–`chapter3.gd`, `ch*_scenes_*.gd` | Mission steps, objectives, cinematics, flags, endings |
| Player | `player/player.gd`, `weapons.gd` | Controls, combat, stealth noise, the Mark, items |
| HUD | `player/hud.gd`, `hud_eyes.gd`, `threat_arcs.gd`, `screen_fx.gd`, `guide.gd`, `weapon_wheel.gd` | Everything drawn over play |
| Menus | `scripts/main_menu.gd`, `pause_menu.gd`, `inventory.gd`, `options_page.gd` | The dossier screens |
| UI kit | `scripts/menu_draw.gd`, `icons.gd` | The palette, fonts, shared components (bar, chip, row, tab, photo print), the icon set |
| Settings | `scripts/settings.gd` | The settings table, persistence and application |
| Enemies | `scripts/enemy.gd`, `harvester.gd`, `bell.gd`, `floodlight.gd` | AI, bosses, boss mechanics |
| Minigames | `lockpick.gd`, `fishing.gd`, `radio_tuning.gd`, `hilo.gd`, `moth_run.gd` | The overlays |
| Rendering | `shaders/*.gdshader` | PS2 post-process, CRT, pause blur, wheel grey |

### 9.3 Design decisions

- **Drawn UI instead of themed Control nodes.** Menus draw with `_draw()` through `MenuDraw`, so rounded shapes, icons and motion stay consistent across every screen.
- **Two scales.** The 3D world renders at 640×360 with nearest filtering (chunky pixels), while menus render in `canvas_items` scale (crisp type) on the same base layout.
- **One Options page.** `OptionsPage` is a plain object that both menus draw and feed input to, so they can never drift apart.
- **Data-driven settings.** `Settings.ROWS` holds each row's label, kind, default, range and help text in one table.

---

## 10. Data and persistence

| Data | Location | Format | Written |
|---|---|---|---|
| Manual saves | `user://saves/manual_<n>.sav` | Godot binary (`store_var`) | Pause → Save game (a new file each time) |
| Autosaves | `user://saves/auto_<0-5>.sav` | Godot binary | On each mission step (ring of 6, oldest overwritten) |
| Settings | `user://settings.cfg` | `ConfigFile` (INI-like), one section per group | On every change |
| Achievements | `user://achievements.cfg` | `ConfigFile` | On unlock |

A save holds the step, chapter, difficulty, kind, timestamp, run (play time, damage taken), player state (health, Mark, items), weapons (owned, current, loaded and reserve rounds), position and the chapter flags.

`user://` is `%APPDATA%\Godot\app_userdata\LAAF` on Windows and `~/.local/share/godot/app_userdata/LAAF` on Linux.

---

## 11. Quality assurance

- **Automated:** headless tests in `tests/` cover chapters 1–3, combat, aiming, enemies, saves and respawns, the inventory, items, the headlamp, minigames, menu mouse handling, localization, collisions and doorways. `tests/drivers/ch1_drive.gd` plays Chapter I end to end.
- **Localization check:** `tests/l10n_test.gd` and `tools/l10n.py` keep `laaf.pot` and `es.po` in sync.
- **Manual acceptance:** each use case in §7 is a test scenario. Run it with mouse, with keyboard, and with a gamepad.
- **Design review:** DESIGN.md lists the rules (the One Rust Rule, the Lantern Rule, the 7px floor…) and a *Known drift* section for violations still open.

---

## 12. Build and distribution

`installer/build.sh` exports the Windows and Linux builds with Godot's export templates and packages them:

- `build/LAAF-<version>-windows-setup.exe`, an NSIS installer (`installer/laaf.nsi`).
- `build/LAAF-<version>-linux.tar.gz`, which the user extracts and installs with `./install.sh`.

The version comes from `git describe`.

---

## 13. Known gaps and roadmap

| Item | Requirement | Note |
|---|---|---|
| Flee exit in boss fights | RF-06 | Design in `maps/docs/en/gameplay.md` §7 |
| Grady's shop screen and upgrades | RF-12, RF-17 | Design in `maps/docs/en/minigames.md` §4 |
| Journal (notes, characters, memories) | RF-13, RF-17 | Evidence already lives in the inventory |
| Ending statistics screen | RF-17 | Tokens, members spared/killed/fled, evidence, time |
| Daily minigame limits | RF-11 | Only Hi-Lo has one |
| Key rebinding | RNF-03 | Would be a new Controls rows type in `Settings.ROWS` |
| Readable, versioned saves | RNF-07 | Move from `store_var` to JSON with a `version` key |
| Design drift | RNF-10 | Keycaps at 6px; subtitles, banners, prompt and boss bar on the fallback font (DESIGN.md) |

---

## 14. Glossary

| Term | Meaning |
|---|---|
| **Alex** | The player character, searching for their sister |
| **Lucía** | Alex's missing sister, held in the quarry chapel |
| **Hollowmere** | The isolated lake town where the game takes place (*Pop. 1413*) |
| **The Veil** | The cult that rules the town |
| **The Mark / Veil's Eye** | The brand on Alex's hand, and the meter (0–100%) of how far the Veil has hold of Alex |
| **Hunters** | Owen, Nora, Julian, Marcus (and Elena): the friends who serve the Veil, one per zone |
| **Moth / Elena** | The hunter who secretly helps Alex over radio channel 7 |
| **Marked Ones** | Masked townspeople, the regular enemies |
| **The Harvester** | The Veil's executioner and the final boss. Its weakness is light |
| **The Shepherd** | The voice behind the Veil (Elias Morrow) |
| **Lantern Tokens** | Brass festival tokens used as currency |
| **Blackout** | 03:00, when every light in town goes out |
| **Dossier** | The case-file folder that every menu is drawn as |
| **Leaf turn** | The page transition between dossier pages |
| **Rust bar** | The single primary action button on a menu page |
| **Base px** | A pixel of the 640×360 design canvas |
