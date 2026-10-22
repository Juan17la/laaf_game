---
version: 1
slug: "scripts-main-menu-gd"
primary_target: "scripts/main_menu.gd"
related_targets: ["maps/main_menu.tscn"]
---

# Main menu (maps/main_menu.tscn · scripts/main_menu.gd)

Mode: Experience. The game's first screen. KB/M first (pad works through ui_* actions).
Audience and job: a returning player resumes in one keypress. A new player starts a case, picks a difficulty and is in. Options, Load, Extra and Quit are each a single tab away.
Constraints: Godot 4.7, 640×360 base coordinates. The live fog-town story scenes stay behind the menu. Everything shown is real save, achievement and settings data, with no invented values.

## Direction contract

THESIS: The menu is the case file on Alex's missing sister, set down in the fog. The fog scene owns the left; the dossier owns the right. This replaces the centred column of grey words that every PSX homage ships.

OWN-WORLD: Near-black folder (#141110→#211d19), rounded 10px. Bone type (#e9e2d3), rust red (#9e140f) for the one primary action, lantern amber (#ffb84d) for selection and focus. Rounded index tabs on the folder's left edge with drawn stroke icons. Pill chips for facts. A pinned "photo" (map crop with a red pin, or a white-bordered print). IM Fell English for the title and headings, Barlow Semi Condensed for UI. Film grain and CRT pass over everything.

STORY: The player sees where they left off (chapter, objective, place, time, Mark, weapons) and resumes. Or they open a new case and pick how hard Hollowmere is. Or they adjust, load, review achievements or leave.

FIRST VIEWPORT: The title screen shows the LAAF logo centred over the fog and a "Press any key" keycap pill. Then the logo moves top-left at 52px, and the scene caption sits bottom-left. A 220×276 folder sits at the right (x 380, y 42) with 7 tabs down its left edge. Continue is open: a map photo of the save point, the chapter heading, chips (time · difficulty · Mark), weapon icons, the NEXT objective, and a rust RESUME bar with an ENTER keycap at the folder's foot.

FORM: Case dossier with tabbed pages, structure 7 of 7 on my ordered list (dealt, user-locked). seed:721c15a9cb7b9a14

SIGNATURE INTERACTION: switching tabs slides the page out and the new page in (folder leaf turn, 0.18s ease-out). The selected tab pulls 4px out of the folder in amber. Code-led.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
