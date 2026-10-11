class_name Feel
extends RefCounted
## Game feel in one place: how enemies notice Alex (awareness, ? / ! icons, off-screen arcs), what the Mark does to
## the screen and the ears, and the combat juice (hitstop, camera trauma, recoil, impacts, hurt edges).
## The `static var`s are the player-facing knobs a settings menu drives (0 / false = off, 1 = as designed);
## the constants under them are tuning. Read everywhere as Feel.<name>.


# ------------------------------------------------------------------ settings (menu knobs)

static var shake := 1.0  ## camera shake (trauma) intensity
static var hitstop := 1.0  ## hitstop length scale
static var mark_fx := 1.0  ## the Mark's screen effects (vignette, pulse, aberration, warp)
static var whispers := true  ## the Mark's whispers (Voice bus)
static var hallucinations := true  ## the Mark's Harvester sightings (Apparition)
static var hurt_fx := 1.0  ## red / blurred edges when hurt
static var detection_icons := true  ## ? / ! over enemies
static var threat_arcs := true  ## off-screen arcs toward enemies that are onto Alex
static var visibility_eye := true  ## the HUD eye showing how visible Alex is


# ------------------------------------------------------------------ detection (Enemy.awareness)

const AWARE_NEAR := 3.0  ## m: a seen player this close is noticed at once
const AWARE_TIME_NEAR := 0.3  ## s to fill the meter just outside AWARE_NEAR, dead ahead
const AWARE_TIME_FAR := 2.6  ## s to fill it at the far edge of sight
const AWARE_EDGE_MULT := 0.5  ## at the edge of the view cone it fills this much slower
const AWARE_ALERT_MULT := 2.0  ## already suspicious / searching: fills this much faster
const AWARE_LIGHT_MULT := 4.0  ## the flashlight on: almost at once
const AWARE_DECAY := 0.35  ## per s while the player is out of sight
const AWARE_LOOK_AT := 0.5  ## a patroller this aware walks over to look (SUSPICIOUS)
const ICON_SHOW_DIST := 32.0  ## m: icons further than this stay hidden
const ICON_ALERT_HOLD := 2.0  ## s the "!" stays up after a hunter spots Alex
const ICON_POP := 1.9  ## scale the "!" pops in from
const ICON_POP_TIME := 0.18
const ICON_GAP := 0.45  ## m between the head (capsule top) and the icon
const ICON_PX := 2  ## screen pixels per glyph pixel
const AMBER := Color(1.0, 0.72, 0.2)
const ALERT_RED := Color(1.0, 0.16, 0.1)
const SPOT_DB := -6.0  ## the "!" sting
const SPOT_GAP := 0.6  ## s: two hunters spotting Alex at once sting once
const ARC_MARGIN := 16.0  ## px from the screen edge
const ARC_SPAN := 0.5  ## rad of arc per enemy
const ARC_WIDTH := 3.0  ## px


# ------------------------------------------------------------------ the Mark: how it grows (the one table)
## A normal run: Chapter 1 ends ~20-30 %, Chapter 2 ~40-60 %, only the end of Chapter 3 (or playing badly) 90-100 %.
## Every hit that marks (Player.hurt's mark_gain) goes through add_mark(): up to the running chapter's soft cap it
## counts in full, past it only MARK_OVER_CAP of it. Elena's jacket multiplies all gains (player.mark_resist).

const MARK_START := 10.0  ## % when Alex wakes up marked (C1.2)
const MARK_SOFT_CAP := {1: 30.0, 2: 58.0, 3: 100.0}  ## % per chapter (Player.mark_cap, set by each director)
const MARK_OVER_CAP := 0.25  ## past the cap a hit marks this fraction of its gain
const MARK_GAIN := {  ## % per hit that lands, by who / what (Enemy.mark_gain; arrows and sweeps too)
	"marked": 1.0,  ## a Marked One's blow (any chapter)
	"arrow": 0.5,  ## Owen's arrows (hunt + boss)
	"owen_hunt": 4.0,  ## Owen catching Alex in the first hunt (was 15: the hunt alone could fill half the meter)
	"owen": 1.5, "nora": 2.0, "julian_hunt": 2.0, "julian": 2.0, "marcus": 2.0,  ## the bosses
	"member": 1.5,  ## unresolved members fighting for the Shepherd (C3 finale)
	"harvester": 3.0,  ## a Harvester blow or sweep
}
const MARK_CREEP := 0.06  ## %/s Chapter 3 nights in control (already ×1.5 for after Elena; was 0.075)
const MARK_CREEP_MAX := 99.0  ## the creep alone never reaches 100 (the Taken sequence isn't in this build)
const MARK_TEA := 15.0  ## % Elena's tea takes off
const MARK_CANDLES := 20.0  ## % "Empty Chairs" takes off


# ------------------------------------------------------------------ the Mark: what it does

const MARK_WHISPER_AT := 25.0  ## % where each effect is centred: it fades in over MARK_RAMP around it
const MARK_VIGNETTE_AT := 50.0
const MARK_DISTORT_AT := 75.0  ## the base colour split / wobble
const MARK_RAMP := 10.0  ## % over which an effect fades in (no hard switch)
const WHISPER_EVERY := Vector2(8.0, 22.0)  ## s between whispers: at full strength / just past 25 %
const WHISPER_DB := Vector2(-6.0, -16.0)  ## loud / faint end
const WHISPER_DIST := 1.6  ## m from Alex, behind and to a side
const MARK_VIGNETTE := 0.55  ## extra vignette at full strength (the base is 0.6)
const MARK_PULSE := 0.35  ## vignette pulse on each heartbeat
const PULSE_DECAY := 2.5  ## per s
const MARK_BEAT_EVERY := Vector2(1.4, 0.8)  ## s between Mark heartbeats: at 50 % / at 100 %
const MARK_BEAT_DB := -14.0
const MARK_ABERRATION := 0.0015  ## base colour split at 100 % (a quarter of the first pass: a hint, never in the way)
const MARK_WARP := 0.0008  ## base wobble at 100 %
## Spikes: distortion that flares and fades (SPIKE_FADE s) on top of the base, 0..1 each, the strongest wins
const SPIKE_ABERRATION := 0.006  ## colour split of a full spike
const SPIKE_WARP := 0.003  ## wobble of a full spike
const SPIKE_FADE := 2.0  ## s from a spike's peak back to the base
const SPIKE_HIT := 0.7  ## a hit that marks Alex (scaled by how much it marked, see SPIKE_HIT_FULL)
const SPIKE_HIT_FULL := 3.0  ## % of Mark that makes a full SPIKE_HIT
const SPIKE_CHASE := 0.45  ## an enemy starts hunting Alex
## Near a boss / the Harvester: not a spike but a steady ambience (in spike units), always there while one is within
## SPIKE_BOSS_NEAR, fading out over the next BOSS_AMBIENCE_FADE m, eased in and out over BOSS_AMBIENCE_EASE s.
## Low enough to read as the air going wrong, never as a hit (0.3 / 0.5 before: a fight's worth of wobble).
const SPIKE_BOSS := 0.1
const SPIKE_HARVESTER := 0.14
const SPIKE_BOSS_NEAR := 14.0  ## m
const BOSS_AMBIENCE_FADE := 8.0  ## m past SPIKE_BOSS_NEAR over which it thins out (no hard edge)
const BOSS_AMBIENCE_EASE := 1.2  ## s (time constant) it takes to settle to a new level
const SPIKE_SCRIPT := 1.0  ## story beats (the eye on the door, the Harvester's reveals, the bell, its phases)
const SPIKE_SCALE := 1.0  ## all spikes (0 = only the base)
const COMBAT_DISTORT := 0.35  ## in a fight (aiming or anyone hunting Alex) the Mark's base + spikes are scaled to this
const COMBAT_EASE := 1.5  ## s for that hold to let go after the fight (it clamps down at once when one starts)
## ...and whatever stacks up, the total in a fight never passes these (the wobble moves the crosshair's picture:
## kept under ~0.2 px; the colour split only shows toward the edges)
const COMBAT_MAX_ABERRATION := 0.0015
const COMBAT_MAX_WARP := 0.0005
## Apparitions: the Harvester standing far off in the dark for a moment (scripts/apparition.gd). Cosmetic only.
const APPARITION_AT := 70.0  ## % Mark from which it can show
const APPARITION_EVERY := Vector2(180.0, 300.0)  ## s between sightings (only counted while one could happen)
const APPARITION_FIRST := 45.0  ## s after the Mark first crosses APPARITION_AT
const APPARITION_RETRY := 8.0  ## s before trying again when no good spot was found
const APPARITION_DIST := Vector2(20.0, 40.0)  ## m from Alex
const APPARITION_SIDE := Vector2(25.0, 65.0)  ## degrees off the camera's forward (in view, never straight ahead)
const APPARITION_TIME := Vector2(1.0, 2.0)  ## s it stands there
const APPARITION_LOOK := 8.0  ## degrees: looked at straight on, it's gone
const APPARITION_CLOSER := 4.0  ## m: walk this much toward it and it's gone
const APPARITION_DARK := 0.35  ## light energy above which a lamp in range makes a spot too lit
const APPARITION_DB := -14.0  ## the whisper it comes with
## The HUD's "MARK +N%" notice (top right, under the clock) whenever the Mark rises; rises while one is up add to it
const MARK_NOTICE_RED := Color(0.85, 0.12, 0.08)
const MARK_NOTICE_HOLD := 1.0  ## s at full strength (after the flash), then...
const MARK_NOTICE_FADE := 1.5  ## ...s fading out
const MARK_NOTICE_CREEP := 2.0  ## % of slow creep (Chapter 3 nights) gathered into one notice


# ------------------------------------------------------------------ combat

const HITSTOP := {"revolver": 0.05, "flare": 0.045, "shotgun": 0.08, "bow": 0.06, "axe": 0.08, "bat": 0.065,
	"jab": 0.04, "bash": 0.05}  ## s the struck enemy (and a melee swing) freeze, by weapon / strike style
const TRAUMA_DECAY := 1.6  ## trauma lost per s
const SHAKE_OFFSET := 0.08  ## m of camera offset at full trauma
const SHAKE_ROLL := 0.03  ## rad of camera roll at full trauma
const SHAKE_FREQ := 21.0  ## Hz-ish of the shake
const TRAUMA_SHOT := {"revolver": 0.22, "flare": 0.16, "shotgun": 0.45, "bow": 0.08}
const TRAUMA_MELEE := {"jab": 0.12, "bash": 0.18, "swing": 0.3, "chop": 0.38}  ## on a landed blow
const TRAUMA_HURT := 0.012  ## per point of damage taken
const TRAUMA_HURT_MAX := 0.6
const KICK_PITCH := {"revolver": 0.025, "flare": 0.025, "shotgun": 0.07, "bow": 0.025}  ## rad of muzzle climb
const KICK_FOV := {"revolver": 2.0, "flare": 1.5, "shotgun": 4.5, "bow": 0.0}  ## degrees of FOV punch
const RECOIL := {"revolver": 1.0, "flare": 0.9, "shotgun": 1.5, "bow": 0.4}  ## arms kick (HumanoidAnim.recoil)
const PITCH_VAR := 0.08  ## ± random pitch on shots, blows and impacts
const ENEMY_FLASH := 0.55  ## white overlay on a struck enemy
const ENEMY_FLASH_TIME := 0.12
const ENEMY_POP := 1.06  ## model scale on a hit, eased back
const ENEMY_POP_TIME := 0.14
const HURT_EDGE := 0.5  ## edge strength of a hit at full health (it grows as health drops)
const HURT_EDGE_TIME := 0.6  ## s it takes to fade
const HURT_EDGE_LOW := 0.3  ## under this health fraction the edges stay
const HURT_EDGE_PERSIST := 0.45  ## how strong they stay at 0 health


static func pitch() -> float:
	return randf_range(1.0 - PITCH_VAR, 1.0 + PITCH_VAR)


static func add_mark(mark: float, gain: float, cap: float) -> float:
	## The Mark after a gain: in full up to `cap` (MARK_SOFT_CAP of the chapter), MARK_OVER_CAP of it past it.
	if gain <= 0.0:
		return clampf(mark + gain, 0.0, 100.0)
	var under := clampf(cap - mark, 0.0, gain)
	return clampf(mark + under + (gain - under) * MARK_OVER_CAP, 0.0, 100.0)


static func ramp(mark: float, at: float) -> float:
	## 0..1: how far into the effect centred at `at` the Mark is (smooth, MARK_RAMP wide).
	return smoothstep(at - MARK_RAMP * 0.5, at + MARK_RAMP * 0.5, mark)
