---
name: LAAF
description: The case file on a missing sister, set down in the fog. A dark folder of drawn, rounded UI under grain and scanlines.
colors:
  bone: "#e9e2d3"
  muted: "#b3ab9c"
  faint: "#8f877a"
  rust: "#9e140f"
  rust-hi: "#c4291c"
  rust-deep: "#770f0b"
  rust-ink: "#f5bdad"
  amber: "#ffb84d"
  folder: "#13100e"
  folder-hi: "#211d19"
  tab-back: "#0f0d0b"
  tab-back-hover: "#1a1613"
  print: "#dbd4c2"
  print-ink: "#33261a"
  caption: "#d1c9b8"
  letterbox: "#000000"
typography:
  logo:
    fontFamily: "IM Fell English"
    fontSize: "52px"
    fontWeight: 400
    letterSpacing: "16px"
  headline:
    fontFamily: "IM Fell English"
    fontSize: "17px"
    fontWeight: 400
  headline-chapter:
    fontFamily: "IM Fell English"
    fontSize: "16px"
    fontWeight: 400
  lede:
    fontFamily: "IM Fell English Italic"
    fontSize: "10px"
    fontWeight: 400
  caption:
    fontFamily: "IM Fell English Italic"
    fontSize: "11px"
    fontWeight: 400
  print-label:
    fontFamily: "IM Fell English Italic"
    fontSize: "9px"
    fontWeight: 400
  action:
    fontFamily: "Barlow Semi Condensed"
    fontSize: "9px"
    fontWeight: 700
    letterSpacing: "1px"
  title:
    fontFamily: "Barlow Semi Condensed"
    fontSize: "8px"
    fontWeight: 700
  title-caps:
    fontFamily: "Barlow Semi Condensed"
    fontSize: "8px"
    fontWeight: 700
    letterSpacing: "1px"
  body:
    fontFamily: "Barlow Semi Condensed"
    fontSize: "8px"
    fontWeight: 500
  label:
    fontFamily: "Barlow Semi Condensed"
    fontSize: "7px"
    fontWeight: 500
  label-caps:
    fontFamily: "Barlow Semi Condensed"
    fontSize: "7px"
    fontWeight: 700
    letterSpacing: "1px"
  label-wide:
    fontFamily: "Barlow Semi Condensed"
    fontSize: "7px"
    fontWeight: 700
    letterSpacing: "4px"
rounded:
  print: "3px"
  keycap: "3px"
  thumb: "5px"
  cell: "6px"
  row: "7px"
  tab: "7px"
  chip: "7px"
  bar: "8px"
  panel: "8px"
  folder: "11px"
  pill: "9999px"
spacing:
  hairline: "1px"
  chip-gap: "4px"
  tab-pull: "4px"
  page-shift: "14px"
  pad: "15px"
  letterbox: "18px"
  line: "17px"
  gutter-left: "32px"
  gutter-right: "36px"
components:
  folder:
    backgroundColor: "{colors.folder}"
    rounded: "{rounded.folder}"
    padding: "15px"
    width: "222px"
    height: "292px"
  index-tab:
    backgroundColor: "{colors.tab-back}"
    textColor: "{colors.muted}"
    typography: "{typography.label-caps}"
    rounded: "{rounded.tab}"
    width: "40px"
    height: "28px"
  index-tab-hover:
    backgroundColor: "{colors.tab-back-hover}"
    textColor: "{colors.muted}"
  index-tab-open:
    backgroundColor: "{colors.folder-hi}"
    textColor: "{colors.bone}"
    width: "41px"
    height: "28px"
  list-row:
    textColor: "{colors.bone}"
    typography: "{typography.title}"
    rounded: "{rounded.row}"
    height: "32px"
  list-row-line:
    textColor: "{colors.muted}"
    typography: "{typography.label}"
    rounded: "{rounded.row}"
    height: "16px"
  bar-primary:
    backgroundColor: "{colors.rust}"
    textColor: "{colors.bone}"
    typography: "{typography.action}"
    rounded: "{rounded.bar}"
    height: "26px"
  bar-primary-armed:
    backgroundColor: "{colors.rust-hi}"
    textColor: "{colors.bone}"
  keycap:
    textColor: "{colors.bone}"
    typography: "{typography.label-caps}"
    rounded: "{rounded.keycap}"
    height: "11px"
    padding: "0 4px"
  chip:
    textColor: "{colors.muted}"
    typography: "{typography.label}"
    rounded: "{rounded.chip}"
    height: "14px"
  chip-mark:
    backgroundColor: "{colors.rust}"
    textColor: "{colors.rust-ink}"
    rounded: "{rounded.chip}"
    height: "14px"
  meter:
    backgroundColor: "{colors.bone}"
    rounded: "{rounded.pill}"
    height: "3px"
  switch:
    backgroundColor: "{colors.bone}"
    rounded: "{rounded.pill}"
    width: "18px"
    height: "9px"
  switch-on:
    backgroundColor: "{colors.amber}"
  objective-panel:
    textColor: "{colors.bone}"
    typography: "{typography.body}"
    rounded: "{rounded.panel}"
    height: "30px"
  map-print:
    backgroundColor: "{colors.print}"
    textColor: "{colors.print-ink}"
    typography: "{typography.print-label}"
    rounded: "{rounded.print}"
    padding: "4px"
  help-bar:
    textColor: "{colors.muted}"
    typography: "{typography.label}"
    height: "18px"
---

# Design System: LAAF

## Overview

**Creative North Star: "The Case File in the Fog"**

The interface is a dossier on Alex's missing sister, set down on a table in Hollowmere's fog. The live town (low-res, dithered, grainy) owns the left of the screen. A near-black folder with rounded index tabs owns the right. Everything the player touches is drawn: rounded rectangles, pill chips, stroke icons on one grid, a pinned map print with a red pin. Nothing is a bare square of text. The PSX/PS2 texture (grain, Bayer dither, scanlines, vignette) comes from the shaders, and it passes over the UI as well as the world. The craft underneath is current-generation: crisp type, soft layered shadows, a leaf-turn page transition.

Density is low and deliberate. Each page shows one heading, the facts that matter as chips or meters, and at most one rust action bar at the foot. Secondary text steps down to muted bone, never to a faint grey that has to be squinted at. Amber is the lantern: it marks what is chosen right now.

All measurements are in the game's 640×360 base units. The menu draws in Godot's `canvas_items` content scale, so type and strokes rasterise at the window's real resolution while the layout stays in base units. The 3D town behind it renders into its own 640×360 SubViewport with nearest filtering, so it keeps its chunky pixels under crisp type. The window goes back to `viewport` scale when the menu exits.

**Key Characteristics:**
- A dark folder (222×292, 11px radius) with seven icon index tabs down its left edge.
- Two faces only: IM Fell English for the voice (logo, headings, italic ledes and captions) and Barlow Semi Condensed for the controls.
- One rust primary bar per page, with a drawn icon, a tracked caps label and an ENTER keycap.
- Amber marks the chosen. Bone at low alpha builds every surface tier.
- A hand-drawn icon set on a 24-unit grid with a 2-unit stroke.
- Grain, dither, scanlines and vignette over everything, UI included.

## Colors

Warm bone on near-black folder, one blood-rust action color and one lantern-amber selection color. Everything else is bone at a lowered alpha.

### Primary
- **Case Rust** (#9e140f): the one primary action on a page (the RESUME / BEGIN / NEW CASE / QUIT TO DESKTOP bar), the logo's underline, and the Mark chip's tint at 32% alpha. The bar runs a vertical gradient from a 35% mix toward Rust Hi at the top down to **Dried Rust** (#770f0b) at the foot.
- **Rust Hi** (#c4291c): the armed or hovered bar's top, the map print's pin, and the pin dot on load thumbnails.
- **Rust Ink** (#f5bdad): text and icon ink on a rust-tinted chip.

### Secondary
- **Lantern Amber** (#ffb84d): the chosen thing. The focused row's 1px outline (85% alpha), the open tab's icon, a setting's live value (meter fill, switch on), the difficulty flames of the picked row, earned achievement rings and the progress track, and the NEXT objective panel (label at full strength, panel fill at 8%).

### Neutral
- **Bone** (#e9e2d3): primary text, headings, the logo, selected labels, and, at low alpha, every surface tier on the folder: rest row 4%, chip 8%, inactive cell 4%, current cell and meter track 10%, selected row 9.5%.
- **Muted Bone** (#b3ab9c): all secondary text that the player still needs (blurbs, row meta, help text, chip ink, unselected tab labels, ledes, option labels).
- **Faint Bone** (#8f877a): non-text marks only. Unchosen difficulty flames, locked achievement icons and their rings at 40%.
- **Folder** (#13100e) and **Folder Hi** (#211d19): the folder's fill, a vertical gradient from Folder Hi at the top to Folder at the foot, at 97% alpha. Folder is also the knob of an ON switch.
- **Tab Back** (#0f0d0b) / **Tab Back Hover** (#1a1613): closed index tabs behind the folder, at 94% and 96% alpha.
- **Print** (#dbd4c2) and **Print Ink** (#33261a): the photo print's white border and its italic handwritten label.
- **Caption Bone** (#d1c9b8): the italic scene line printed straight on the fog.
- **Letterbox Black** (#000000): the 18px FMV bars top and bottom.

### Named Rules
**The One Rust Rule.** A page has at most one rust surface that acts: its primary bar. Rust appears elsewhere only as a signal (the Mark chip tint, the map pin, the logo underline), never as a second button.

**The Lantern Rule.** Amber marks what is chosen or live right now: focus, the open tab, a set value, an earned thing, the next objective. It is never a decoration, never an action fill and never body-text color.

**The Muted, Not Faint Rule.** Text the player needs is Bone or Muted Bone. Faint Bone is for marks that mean "not yet" (locked, unchosen) and never carries words.

## Typography

**Display Font:** IM Fell English (regular and italic), bundled as `fonts/IMFeENrm28P.ttf` / `fonts/IMFeENit28P.ttf`
**UI Font:** Barlow Semi Condensed, Medium (500) and Bold (700), bundled in `fonts/`

**Character:** A 17th-century printed serif with ink spread for the voice of the case file, against a narrow, sturdy grotesque that reads at 7px for every control and fact. SemiBold ships in `fonts/` but no role uses it.

### Hierarchy
- **Logo** (IM Fell 52px, tracking +16, drawn at 1.12×): "LAAF" only. 1.35 × 1.12 and centred at y 150 + 4% of H on the title screen, 1.12× at top left (32, 70 + 4% of H) on the dossier and the pause menu, with a 1.2px Rust Hi rule under 80% of its width and HOLLOWMERE in Label Wide below (all three scale and move together).
- **Headline** (IM Fell 17px): the page heading at the page's top (baseline +16). An optional right-aligned Muted label (7px) on the same line carries a count ("3 saved", "4 of 13").
- **Chapter heading** (IM Fell 16px): the Continue page's "Chapter I — The Mark" under the print.
- **Lede** (IM Fell Italic 10px, Muted Bone, up to 3 lines): the in-world sentence under a heading.
- **Caption** (IM Fell Italic 11px, Caption Bone): the scene line on the fog, bottom left at (32, H−36), with a Barlow 7px source line in a rust-pink below.
- **Print label** (IM Fell Italic 9px, Print Ink): the place name written on a photo print.
- **Action** (Barlow Bold 9px, tracking +1, caps): the primary bar's label.
- **Title** (Barlow Bold 8px; caps and +1 tracking for the difficulty names): a list row's main line.
- **Body** (Barlow Medium 8px): the objective text and ammo counts.
- **Label** (Barlow Medium 7px): row meta, chip text, help text, option labels, keycap help words. This is the floor.
- **Label Caps** (Barlow Bold 7px, +1, caps): tab labels (untracked Bold), options group headers, the NEXT label, keycaps.
- **Label Wide** (Barlow Bold 7px, +4, caps): HOLLOWMERE under the logo and the title screen's town line.

### Named Rules
**The 7px Floor Rule.** No functional text is smaller than 7 base pixels. The 640×360 base is the design surface; anything below 7 does not survive the scale-down to a laptop window.

**The Two Voices Rule.** IM Fell speaks in the world (names, headings, ledes, captions, handwriting). Barlow operates the UI (labels, values, keys). A control is never set in IM Fell and a heading is never set in Barlow.

## Layout

The screen is 640×360 base units, with aspect `expand` (extra width grows the canvas and the right-anchored folder keeps its gutter).

- **Letterbox:** black bars 18px tall at the top and bottom. The bottom bar holds the keycap help bar.
- **Left field:** the fog scene. The logo sits at (32, 70 + 4% of H). The scene caption sits at (32, H−36) and its source line at (32, H−25). Left gutter 32.
- **Folder:** 222 wide, from y 34 to H−34 (292 tall at 360), right edge 36 from the screen's right. Inner padding 15 on all sides, so a page is 192 wide.
- **Index tabs:** seven, 40×28, starting 18 below the folder top with a 32 pitch, overlapping the folder by 4 and tucked behind it. The open tab is drawn over the folder, 41 wide and 4 further left: it pulls out of the folder.
- **Page rhythm:** heading baseline at +16. Lede at +34 to +36. Primary bar pinned to the page foot (26 tall, full page width). Load rows 32 tall at a 36 pitch (6 visible). Difficulty rows 30 tall at a 34 pitch. Options and Dev lines 16 tall at a 17 pitch (12 visible), with the row's highlight bleeding 4 past the text column. Chips 14 tall with a 4 gap. Weapon cells 29×22 at a 32 pitch. Achievements in 4 columns, 36 tall at a 38 pitch.
- **Help bar:** right-aligned to the folder's right edge (W−36), baseline in the bottom letterbox at H−9. Pairs are spaced 12 apart and the word sits 4 after its keycap.

**The Fog Owns the Left Rule.** Nothing but the logo and the scene caption sits on the fog. Every control lives on the folder or in the letterbox.

## Elevation & Depth

A hybrid: one soft ambient shadow lifts the folder and the photo print off the fog, and inside the folder depth is tonal, stepped by Bone at rising alpha. Gradients are vertical and light from above.

### Shadow Vocabulary
- **Folder shadow:** three stacked rounded fills of black at 16% (times the dossier fade), grown 2, 5 and 8 px with the top edge pulled back by the same amount, at radii 12, 15 and 18. It falls soft and mostly downward.
- **Print shadow:** one rounded fill of black at 45%, offset (1, 3), radius 3, under the rotated print.
- **Type on fog:** a copy of the text 1px lower in black at 70% of the text's alpha.
- **Pin shadow:** a 4.6 radius black circle at 40%, 1px below the pin head.

### Named Rules
**The Shadow or Line Rule.** A shadowed surface (folder, print) never also gets a 1px border. Outlines belong to unshadowed things: keycaps, the focused row, the closed tabs' faint 8% edge, the load thumbnail's frame.

**The Texture Over Everything Rule.** The world's material is applied last and to the whole frame. `ps2_post` (grain 0.07, vignette 0.6, 32 levels with 4×4 Bayer dither) passes over the town. `menu_crt` (scanlines 16% on every second physical row, a slow 5% rolling band, grain 0.07, vignette 1.1, a 0.0006 UV colour fringe) passes over the town and the UI together. UI is never drawn above the CRT pass.

## Shapes

Every surface is a rounded rectangle traced with 5 points per corner (`Icons.round_rect`), and every stroke is antialiased. Radii scale with the surface: 3 for keycaps and prints, 5 for thumbnails, 6 for weapon cells, 7 for rows, tabs and chips, 8 for the bar and the objective panel, 11 for the folder. Anything 14 or less tall that holds a fact (chip, switch, meter track, the title keycap pill) is a full pill. Index tabs are rounded only on their outside (left) edge and square where they meet the folder. The photo print is the one tilted shape (−0.025 to +0.03 rad).

### Icons
The drawn set in `scripts/icons.gd` is the only icon source. Icons sit on a 24-unit grid with a 2-unit stroke and a 1px minimum, built from lines, closed outlines, filled shapes, circles, dots, arcs and rounded boxes. Weapons are drawn side-on facing right. In use: tab 12 at 1.3 stroke, chip 9 at 1.1, bar 10 at 1.4, weapon cell 16 at 1.2, achievement 13 at 1.2, difficulty flame 10 at 1.1. A new icon is added to `Icons.SET` on the same grid, never as a glyph or a font character.

## Components

### Folder
The dossier itself. A Folder Hi to Folder vertical gradient at 97% with an 11 radius, the three-layer shadow and no border. It slides in 260 from the right as the title screen fades to the dossier.

### Index Tab
- **Closed:** Tab Back at 94%, tucked behind the folder, a faint Bone 8% edge on its rounded side. Icon 12 in Muted Bone at 75%, label Barlow Bold 7 in Muted Bone, centred under it.
- **Hover:** Tab Back Hover at 96%.
- **Open:** the folder's own leaf. Same gradient as the folder at that height, no stroke, pulled 4 further out. Icon in Lantern Amber, label in Bone.

### Primary Bar (with keycap)
The page's one action, pinned to the page foot at full width and 26 tall with an 8 radius. A Rust to Dried Rust vertical gradient, Rust Hi at the top when armed (keyboard focus can fire it) or hovered. A Bone icon 10 at 15 from the left, the label in Action caps at 27, and an ENTER keycap 9 from the right in Bone at 90%. No border, no shadow.

### Keycap
A key name in a 3-radius outline, 11 tall, its width the label plus 4 each side. Outline at 55% of the ink, label in Bone Label Caps. The title screen's PRESS ANY KEY is the large form: a 19-tall pill on black at 45%, a Bone 35% outline and Bold 8 +1 caps, pulsing between 55% and 100%.

### Pause Menu
The dossier set down over the paused game (`scripts/pause_menu.gd`). The frozen frame behind it is blurred and dimmed (`shaders/pause_blur.gdshader`), with the letterbox bars, the logo at its dossier place and `menu_crt` over everything. The folder holds "Paused", the chapter as a lede, time / difficulty / Mark chips (the Mark exact to a tenth), the NEXT panel, three list rows (Save game, Options, Main menu; a greyed row is a fainter slip with a lock and says why) and the RESUME bar. Main menu asks first on its own leaf, with the map print of where you'd leave off. Options is the very same page as the dossier's OPTIONS tab (`scripts/options_page.gd`). Both menus draw with `scripts/menu_draw.gd`.

### Mouse
### Inventory
The pause menu's dossier, wider, over the same blurred frozen frame (`scripts/inventory.gd`, opened by I / the pad's Back, M on its Map tab). Index tabs on the folder's left edge like the main menu's (WEAPONS, ITEMS, KEYS, EVIDENCE, MAP; `MenuDraw.index_tab` / `tab_face`), INVENTORY in Label caps over the folder's top right. List pages: rows with the item's rendered icon (`ui/icons/*.png`, made by `tools/shot.gd -- --icons` from the item models in the PS2 look) and a detail card (big icon, name in the serif, chips, the line, and the rust bar for what Enter does: EQUIP, DRINK, PUT ON...; a fainter slip says why not). Evidence: a 6 × 2 grid of slips, ??? where one is missing, the x / 12 track like Extra's. Map: the town print (`player/guide.gd draw_paper_map`) under one line of NEXT. The folder takes the width the screen has beside the logo (300-420 px).

One selection for keys and mouse: pointing at a row selects it (the same amber outline), a left click acts like Enter, a right click goes back like Esc, and the ESC / ENTER pairs of the help bar click too (brightening under the pointer). The wheel scrolls lists and adjusts a meter or multiplier under it; a meter's track is clicked or dragged, a multiplier dragged sideways. On New a card shows while pointed at and is picked by a click. In the pause menu, whatever resumes the game acts on the release. The pointer is a small bone arrow with a black edge in chunky pixels while a menu is open, the system arrow otherwise.

### Selection Wheel
Hold Tab (or the pad's Y) in play: `player/weapon_wheel.gd`. The game slows to 25% and the frame behind goes grey, softly blurred and vignetted (`shaders/wheel_grey.gdshader`); it fades in over 90 ms of real time and draws in the crisp canvas_items scale, like the menus. A ring of wedges (radius 56-140, Folder Hi at 94%): fists at the top, then each weapon clockwise in number-key order, a faint Bone 30% rule, then the items Alex holds. Each wedge: the rendered icon (40 px, 46 when picked) on a Bone 7% disc, its count under it in Barlow Bold 10 (ammo `loaded / reserve` as on the HUD, ×n, On / Off; EMPTY in Rust Hi). The picked wedge stands out 8 px, warmer, with the focused-row 1 px Lantern Amber outline and a 3 px amber outer edge; the weapon in hand carries the inventory's amber dot. The hub: the verb in Label Caps 8 amber (EQUIP, IN HAND, THROW, DRINK, PUT ON...; Faint when it can't), the name in IM Fell 17 stepping down to 11, the quick-key keycap (keyboard only), and an amber needle on its rim where the mouse or stick points. Under the ring one Barlow 9 line: why not (Rust Hi) or what the item does (Bone). Bottom centre, the help pair for the last device: `[TAB] Release to pick · [RIGHT CLICK] Cancel`, or `[Y]` / `[B]`.

### Help Bar
The keys that work right now, in the bottom letterbox, right-aligned: keycap then a Muted 7 word ("Tabs", "Select", "Back", "Adjust"). It changes with focus and page.

### Chip
A fact as a 14-tall pill: Bone 8% fill, a 9 icon at 9.5 in, Muted Label text at 16.5. The **Mark chip** is the one tinted variant: Rust at 32% with Rust Ink text and icon. Chips sit in a row 4 apart.

### List Row
A rounded 7 box. At rest Bone 4% (load and difficulty rows) or no fill (options and dev lines). Selected: Bone 9.5% and a 1px Lantern Amber outline at 85%. Main line in Title (Bone), meta in Label (Muted). Load rows lead with a 36×24 map thumbnail (Bone 25% 1px frame, Rust Hi pin dot) or, for old saves, the chapter numeral in IM Fell 14 on Bone 7%.

### Meter
A 3 to 3.5 tall pill track in Bone 10 to 12%, filled in Lantern Amber for a live setting or an earned total, or in Bone 70% for a fixed difficulty value. The number sits right-aligned in Label or Label Caps.

### Switch
An 18×9 pill. Off: Bone 15% with a Bone 60% knob (radius 3.2) on the left. On: Lantern Amber with a Folder knob on the right.

### Objective Panel
The NEXT line on Continue. A 30-tall rounded 8 panel in Amber 8% with "NEXT" in Amber Label Caps at the left and the objective in Bone Body, wrapped to 2 lines.

### Map Print
A photo of the town map, pinned. A Print border (4 on three sides, 15 at the foot when labelled), radius 3, a slight tilt, the print shadow, the map crop tinted warm with a 18% brown age wash, a Rust Hi teardrop pin with a Print centre where the save was made, and the place name handwritten in Print Label at the foot. With no position it shows the whole town and no pin.

### Weapon Cell
A 29×22 rounded 6 cell, Bone 10% for the current weapon and 4% for the rest. Icon 16 in Bone (current) or Muted, with loaded·reserve in Body Muted under guns. Melee has no count.

### Motion
- **Title to dossier:** 0.45s (rate 2.2/s) on an in-out ease. The logo drifts from centre to top left as it scales 1.35 to 1 (times its 1.12), its rule and HOLLOWMERE slide from centred to flush left, and the folder slides in from +260.
- **Leaf turn:** 0.18s with an ease-out curve. The outgoing page slides 14 left and fades while the incoming one slides in from 14 right. The outgoing page cannot be clicked.
- **Scenes:** each shot runs 11s with a 1.5s fade from and to black over a 20% floor. The caption fades in 2s after the shot starts and leaves 2s before it ends. The camera drifts linearly and rolls ±0.01 rad like a held camera.
- **Pulse:** PRESS ANY KEY breathes at 2.6 rad/s.

## Do's and Don'ts

### Do:
- **Do** draw menus in `canvas_items` content scale so type is crisp, keep the 3D in its 640×360 SubViewport with nearest filtering, and restore `viewport` scale on exit.
- **Do** keep every functional label at 7 base pixels or larger, in Bone or Muted Bone.
- **Do** give each page at most one rust primary bar, pinned to its foot, with its icon and ENTER keycap.
- **Do** use Lantern Amber for exactly what is chosen or live: focus outline, open tab, set values, earned items, the next objective.
- **Do** build surface tiers from Bone at low alpha (4%, 8%, 9.5%, 10%) on the folder rather than new greys.
- **Do** draw every icon from `Icons.SET` on its 24-unit grid with the 2-unit stroke, and every surface with `Icons.round_rect` / `fill_round`.
- **Do** show only real save, settings and achievement data. Show an honest empty state ("No case open", "Nothing saved yet") over an invented value.
- **Do** let the grain, dither, scanline and vignette passes cover the UI too.

### Don't:
- **Don't** put an eyebrow or kicker label above a heading. The heading and its lede carry the page.
- **Don't** set needed text in Faint Bone.
- **Don't** add a 1px border to a shadowed surface (folder, print).
- **Don't** use amber as decoration, as an action fill or for body text, and don't add a second rust button to a page.
- **Don't** use glyph or font icons, system fonts, or square unrounded panels; the brand commitment is that the UI is never only squares and text.
- **Don't** place controls on the fog. The left of the screen belongs to the scene, the logo and the caption.

### Known drift (not part of the system)
- The in-game HUD (`player/hud.gd` and its helpers) has not been migrated to this system and still renders in the project's `viewport` stretch scale (`project.godot`: `stretch/mode="viewport"`). It is recorded here as drift, not as precedent. (The pause menu, `scripts/pause_menu.gd`, now draws with the dossier's pieces in `canvas_items` scale while it is open.)
- Keycap labels are currently drawn at 6px (`main_menu.gd` `_key`), below the 7px floor. Label Caps 7px is the system value.
- The Extra page marks the focused achievement with a Bone 90% ring (r 17) where the Lantern Rule calls for amber.
- The scene caption's source line uses a one-off rust-pink (#d98070) outside the palette.
