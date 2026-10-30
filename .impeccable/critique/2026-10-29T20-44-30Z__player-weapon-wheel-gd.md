---
target: weapon/item selection wheel
total_score: 18
max_score: 40
na_heuristics: 
p0_count: 1
p1_count: 3
target_identity: "file:/home/jud1714/Projects/diseno_interfaces/laaf_game/player/weapon_wheel.gd"
target_fingerprint: "sha256:69037bc45a3893a2364ff5f2cc3365c3b983dd436d231ed537574f050621e0d3"
target_path: /home/jud1714/Projects/diseno_interfaces/laaf_game/player/weapon_wheel.gd
timestamp: 2026-10-29T20-44-30Z
slug: player-weapon-wheel-gd
closed: true
---
Method: design review only (detector not applicable, native platform: Godot _draw UI)

Assessed: player/weapon_wheel.gd as first shipped (fallback font, 6-8px text, weapon-colour selection).

| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 2 | No pointer feedback; weapon in hand not marked; empty guns read "0 · 0" like a normal state |
| 2 | Match System / Real World | 3 | Wheel metaphor is genre-standard; "6 · 18" differs from the HUD's "6 / 18" |
| 3 | User Control and Freedom | 1 | No cancel: every release applied the highlighted slot |
| 4 | Consistency and Standards | 1 | Fallback system font, weapon-colour highlight; ignores DESIGN.md fonts, Lantern Amber, keycaps, 7px floor |
| 5 | Error Prevention | 2 | Tea when the Mark is clear only dimmed; empty guns not flagged |
| 6 | Recognition Rather Than Recall | 2 | Non-selected slots carry icon + tiny count only; quick keys never shown |
| 7 | Flexibility and Efficiency | 2 | Does not teach the hotkeys (1-6, G T H X F) it duplicates |
| 8 | Aesthetic and Minimalist Design | 2 | "WEAPON / ITEM" label and "Melee" carry no decision value; weapons/items not grouped |
| 9 | Error Recovery | 2 | Only "The Mark is already clear." as a why-line |
| 10 | Help and Documentation | 1 | One 8px hint; no cancel or controls shown |
| **Total** | | **18/40** | Poor |

Priority issues: P0 text below the 7px floor and pixelated (viewport scale); P1 icons too small/dim on dark wedges; P1 no cancel; P1 off-system type and colour; P2 missing in-hand, empty, quick-key and pointer info; P3 redundant WEAPON/ITEM label and "Melee".
