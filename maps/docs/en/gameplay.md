# Gameplay — LAAF

Genre: **3D third‑person action / survival horror** (Godot 4.7, Jolt physics).
The game is **not** a "collect good items / avoid bad items" loop. The core is: **explore → get hunted → hide or escape → fight when forced → decide the fate of each hunter.**

## 1. Core loop

```
 Day (explore, minigames, shop)
        │
        ▼
 Enter a zone ──► Stealth (avoid the owner) ──► Seen? ──► Chase ──► Escape / hide / stun
        │                                                     │
        ▼                                                     ▼
 Objectives (key part, evidence, weakness)              Caught → damage / Mark ↑
        │
        ▼
 Boss arena ──► Fight ──► Hunter defeated ──► SPARE or KILL
        │
        └──► FLEE (exit opens during fight) ──► hunter stays alive and roams later
        │
        ▼
 Back to hub (safe house) ──► spend tokens ──► next zone
```

Session target: 1 zone ≈ 30–45 min including boss. Full game ≈ 5–7 hours.

## 2. Player controls

| Action | Keyboard / Mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Camera | Mouse | Right stick |
| Sprint | Shift | L3 |
| Jump / climb low wall | Space (coyote time + buffered) | A / Cross |
| Dodge roll (i‑frames: arrows and swings pass through) | Ctrl | LB / L1 |
| Crouch / sneak (hide in tall grass) | C | B / Circle |
| Slide (crouch while sprinting; jump out of it keeps the momentum) | C while sprinting | B while sprinting |
| Interact / hide | E | X / Square |
| Aim | Hold RMB | LT |
| Shoot (also while jumping, rolling or sliding, with more spread) | LMB | RT |
| Reload | R | RB / R1 |
| Swap weapon | Q / mouse wheel / 1‑6 (the HUD lists what you carry) | Y / Triangle |
| Strike (fists, gun butt, axe, bat; fire does it too with nothing to shoot) | B / middle mouse | RT with an empty gun / melee weapon |
| Draw the bow | Hold RMB (fire looses; a full draw hits hardest) | LT |
| **Double tap** | Shoot, then swap and shoot again within 0.45 s: the swap is instant and that shot deals +50% | same |
| Flashlight | F | D‑pad up |
| Swap shoulder | V | R3 |
| Skip dialogue line (cinematics) | Enter / E | A / X |
| Pause menu (resume · save game · main menu) | Esc | Start |

> Implemented in `player/player.gd` + `player/weapons.gd`: revolver, flare gun, shotgun (Tom's, at the boathouse, ch2), Owen's bow (after his fight), fire axe (sawmill yard), nail bat (inside the school), and bare fists (alternating jabs; every third landed punch hooks harder). Axe and bat stagger what they hit. The arms hold every weapon on its real grips (arm IK). Quick heal, radio key and journal are not implemented yet.

Camera: over‑the‑shoulder, switches shoulder with a key (V / R3). Camera pulls in when hiding and shakes when a hunter is near.

## 3. Player stats

| Stat | Base | Upgradable | Notes |
|---|---|---|---|
| Health | 100 | +20 per tier (3 tiers) | Regenerates only to 30% on its own; heal with bandages/medkits |
| Stamina | 100 | +15 per tier (3 tiers) | Sprint, dodge, heavy attack. Recovers when walking |
| Stealth | 1 | 3 tiers | Reduces footstep noise radius (−15% per tier) |
| Mark resistance | 1 | 3 tiers | Mark grows −10% slower per tier |
| Melee | 10 dmg | 3 tiers | Weapon mods also add damage |
| Aim | 1 | trained in shooting gallery | Reduces sway and reticle bloom |
| Ammo capacity | 6 | +3 per tier (3 tiers) | Ammo is rare by design |
| Inventory slots | 6 | +2 per tier (2 tiers) | Throwables and heals share slots |

## 4. Stealth

- **Noise:** each action has a noise radius (walk 4 m, sprint 12 m, crouch 1.5 m, dodge 6 m, gunshot 40 m, minigames with sound 8–15 m). Surfaces modify it (wood creaks, grass silent, water splashes).
- **Visibility:** light level + movement + distance + cover. A **visibility eye** in the HUD shows how visible the player is.
- **Hiding spots:** lockers/closets, under beds/tables, tall grass, shadows, mausoleums, morgue freezers. Hunters may check hiding spots they **saw** the player use (Julian always does).
- **Distractions:** throw bottles/bricks, noise‑makers, turn on radios, break windows.
- **Footprints:** in mud/snow (forest zone), Owen can follow them. Water erases them.

## 5. Hunters (enemy AI)

Hunters are **persistent** — one per zone, can't be killed until their boss fight.

**State machine:**

| State | Behavior | Exit condition |
|---|---|---|
| Patrol | Follows zone route, talks to themself | Hears noise / sees something → Suspicious |
| Suspicious | Walks to last noise, looks around, "Who's there?" | Confirms player → Chase; nothing in 10 s → Patrol |
| Hunt | (night/blackout) Actively searches player's likely area, checks hiding spots | Sees player → Chase |
| Chase | Runs to player, attacks, calls others (Marcus bell / Owen whistle) | Line of sight lost 8 s → Search; stunned → Stunned |
| Search | Checks nearby hiding spots, remembers last known position | 30 s nothing → Patrol / Hunt |
| Stunned | Weakness triggered or heavy hit; 3–8 s | Timer ends → Search |

- **Catch:** a hunter that reaches the player deals heavy damage and raises the Mark +15%. It is not instant death, except during a blackout with Mark at 100%.
- **Director:** a light "tension director" limits how often a hunter finds the player (avoid frustration): after an escape, the hunter goes to the wrong area for a short time.
- **After Act III:** all surviving hunters can appear in any zone (roamers), one at a time.

## 6. Combat

- **Melee:** light (fast, low stamina), heavy (slow, stuns regular enemies, opens hunters for a counter), dodge with i‑frames.
- **Weapons:** found in the world or bought: pipe, hatchet, crowbar (melee); revolver, flare gun, shotgun (late). Ammo is scarce.
- **Throwables:** bottle (noise), brick (stun short), flare (light + fire, Owen weakness), noise‑maker (distraction), smoke can (break line of sight).
- **Regular enemies:** **Marked Ones** — recruited townspeople in masks, used to fill fights and patrols. They can be killed or knocked out freely; they drop tokens and supplies.
- **Hunter boss fights:** 2–3 phases, each hunter's weakness is the key mechanic. A visible **escape exit** opens after phase 1 (flee option).

## 7. Boss resolution — Spare / Kill / Flee

When a hunter's health reaches 0 they fall to their knees. A prompt appears:

- **Spare** (hold interact): the hunter surrenders. Requires having found their **personal item** (Lily's drawing, Sam's file, Clara's photo, Owen's parents' lantern) to get the full "redeemed" scene; otherwise they survive but stay broken (count as spared, no ally in finale).
- **Kill** (press attack): execution scene; hunter removed from the game.
- **Flee** (during the fight, through the escape exit): no resolution; the hunter remains a roaming threat. Key items can still be stolen from their stash with stealth.

No choice is signaled as "right". Consequences appear in the world: Grady's lines, graffiti, how the remaining hunters talk about the player ("You killed Owen. You're one of us now.").

## 8. The Mark meter

- Range 0–100%. No permanent gauge: when it rises, a small red "MARK +N%" flashes under the clock and fades (rises close together merge into one notice); the exact value is in the pause menu.
- **Raises:** +1% per in‑game minute at night, +15% when caught, +5% when seen, faster after Act III.
- **Lowers:** resting in a safe room (−30%, once per night), consumables (Elena's tea −15%), sleeping in the motel (reset to 20% each morning).
- **Effects:**
  - 25%: whispers audio.
  - 50%: hunters sense the player's approximate direction when close.
  - 75%: vision vignette, hallucinated figures (fake hunters) appear.
  - 100%: during the blackout, the player is taken → **Taken sequence** (wake up in the quarry cells, escape segment, lose 50% of carried tokens). On Hard difficulty = game over.

## 9. Day / night and blackout

- **Day (06:00–19:00):** hunters patrol less (only in their zone, slower). Shops and minigames available.
- **Night (19:00–06:00):** hunters in Hunt state, more Marked Ones.
- **Blackout (03:00–04:00):** power cut in the whole town; only flashlight and fires. The marked are collected. Safe rooms still work.
- Time passes in real time (1 in‑game hour = 2.5 real minutes) and when sleeping in the motel (skip to morning).

## 10. HUD

- Health and stamina bars (bottom left), minimal.
- Mark: a brief "MARK +N%" notice under the clock when it rises (top right); the exact value in the pause menu.
- Visibility eye and noise ring around the character (optional).
- Tokens counter (only in hub/when changing).
- Clock (in‑game time, top center, turns red near 03:00).
- Objective hint (can be disabled).
- Diegetic radio: subtitles for Elena/Shepherd calls.

## 11. Menus and UI screens

- Main menu, settings (graphics, audio, controls rebinding, subtitles, language EN/ES, accessibility).
- Pause menu: journal (notes, evidence 0/12, characters, memories), map with zones and owners, inventory.
- **Shop screen** (Grady): tabs for Supplies, Weapons, Upgrades, Lore. Shows price, current tier, next tier effect.
- **Minigame UI:** each minigame has its own overlay (see [minigames.md](minigames.md)), with a clear exit button and the noise it generates.
- Boss choice prompt (Spare / Kill), no timer.
- Ending screen with stats (tokens earned, members spared/killed/fled, evidence found, time).

## 12. Saving

- Manual save in safe rooms and at Grady's store; autosave when entering a zone and after bosses.
- 3 save slots. Saved: position, time, Mark, stats/upgrades, inventory, tokens, flags (see [progression.md](progression.md)).

## 13. Difficulty

| Setting | Story | Normal | Hard |
|---|---|---|---|
| Hunter detection | −40% | base | +25% |
| Mark growth | −50% | base | +30% |
| Mark 100% at blackout | Taken, keep tokens | Taken, −50% tokens | Game over |
| Ammo found | +50% | base | −30% |
| Minigame rewards | +25% | base | base |
