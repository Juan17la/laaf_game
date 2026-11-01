#!/usr/bin/env python3
"""Recorded audio for LAAF: CC0 samples and music (credits in audio/CREDITS.md) cut, mixed down and leveled into
res://audio/sfx_*.wav and music_*.ogg, replacing the synthesized ones from tools/make_audio.py (which skips every
name made here). Levels go by loudness (the loudest 50 ms), not peak: a recorded gunshot's spike is 15 dB over its body.
    python3 -m venv .venv && .venv/bin/pip install numpy scipy soundfile
    .venv/bin/python tools/import_sfx.py <sources dir>
<sources dir> holds the packs unpacked as audio/CREDITS.md lists them (kenney/impact-sounds/Audio/..., oga/...).
Variants are name_0..n (Audio._pick plays a random one). Loops are cross-faded on themselves so they wrap seamlessly."""
import glob, os, sys
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
SRC = sys.argv[1] if len(sys.argv) > 1 else "."
K = "kenney/"
IMP, RPG, IFC, UI, SCI = K + "impact-sounds/Audio/", K + "rpg-audio/Audio/", K + "interface-sounds/Audio/", \
    K + "ui-audio/Audio/", K + "sci-fi-sounds/Audio/"
FF = "oga/ffsl/Prepared SFX Library/"
CAR = "oga/car/"


def load(path, pitch=1.0):
    """Mono float at SR; pitch > 1 plays it faster / higher (and shorter)."""
    x, sr = sf.read(os.path.join(SRC, path), always_2d=True)
    x = x.mean(1)
    sr2 = int(round(SR / pitch))
    g = np.gcd(sr, sr2)
    return resample_poly(x, sr2 // g, sr // g) if sr != sr2 else x


def trim(x, start_db=-45.0, end_db=-50.0, max_s=None, pre=0.004):
    """Cut the silence before the onset and the tail under end_db (from the peak), cap at max_s, short fade out."""
    a = np.abs(x)
    p = a.max() + 1e-12
    on = np.argmax(a > p * 10 ** (start_db / 20))
    on = max(0, on - int(pre * SR))
    above = np.nonzero(a > p * 10 ** (end_db / 20))[0]
    end = above[-1] + 1 if len(above) else len(x)
    if max_s:
        end = min(end, on + int(max_s * SR))
    y = x[on:end].copy()
    f = min(len(y) // 4, int(0.03 * SR))
    if f:
        y[-f:] *= np.linspace(1, 0, f) ** 2
    return y


def shots(path, n, max_s, pitch=1.0, gap=0.25):
    """The separate hits in a take (gun recordings hold several shots): onsets that jump to near the peak."""
    x = load(path, pitch)
    a = np.abs(x)
    p = a.max()
    hits, i = [], 0
    while len(hits) < n:
        k = np.nonzero(a[i:] > p * 0.35)[0]
        if not len(k):
            break
        on = i + k[0]
        hits.append(trim(x[on:on + int(max_s * SR) + int(gap * SR)], max_s=max_s))
        i = on + int(max(max_s, gap) * SR)
    return hits


def mix(*parts):
    """(signal, gain, offset_s) layers summed."""
    n = max(len(s) + int(o * SR) for s, _, o in parts)
    y = np.zeros(n)
    for s, g, o in parts:
        k = int(o * SR)
        y[k:k + len(s)] += s * g
    return y


def loop(x, xfade=0.4):
    """Seamless loop: the tail fades into the head."""
    f = int(xfade * SR)
    y = x[:-f].copy()
    t = np.linspace(0, 1, f)
    y[:f] = x[:f] * np.sqrt(t) + x[-f:] * np.sqrt(1 - t)
    return y


def loud(x):
    """dB of the loudest 50 ms."""
    w = int(0.05 * SR)
    r = max(np.sqrt(np.mean(x[i:i + w] ** 2)) for i in range(0, max(1, len(x) - w), w // 2))
    return 20 * np.log10(r + 1e-12)


def limit(x, t=0.8):
    """Soft knee over t: spikes squeezed under 1.0 instead of the whole sound turned down to fit them."""
    a = np.abs(x)
    return np.where(a < t, x, np.sign(x) * (t + (1 - t) * np.tanh((a - t) / (1 - t)))) * 0.97


def write(name, x, level=0.8):
    """level: the old peak scale, now a loudness target (0.5 = footsteps ~-12 dB, 0.9 = guns ~-6.5 dB)."""
    x = x - x.mean()
    x = limit(x * 10 ** ((20 * np.log10(level) - 5.5 - loud(x)) / 20))
    sf.write(os.path.join(OUT, name + ".wav"), x.astype(np.float32), SR, subtype="PCM_16")
    print("wrote", name, "%.2fs" % (len(x) / SR), flush=True)


def variants(name, clips, level=0.8):
    for f in glob.glob(os.path.join(OUT, "sfx_%s.wav" % name)) + glob.glob(os.path.join(OUT, "sfx_%s_[0-9].wav" % name)):
        os.remove(f)  # old synthesized takes (a plain sfx_name.wav would shadow nothing but would linger)
        if os.path.exists(f + ".import"):
            os.remove(f + ".import")
    if len(clips) == 1:
        write("sfx_" + name, clips[0], level)
    else:
        for i, c in enumerate(clips[:8]):
            write("sfx_%s_%d" % (name, i), c, level)


def kn(prefix, n=5, start=0, **kw):
    """Kenney numbered takes: prefix_000.ogg ..."""
    return [trim(load(IMP + "%s_%03d.ogg" % (prefix, i)), **kw) for i in range(start, start + n)]


def rpg(stem, idx, **kw):
    return [trim(load(RPG + "%s%s.ogg" % (stem, i)), **kw) for i in idx]


MUSIC = {  # name: (file, seamless already?)  Audio.music(name)
    "menu": ("oga/music/menu.ogg", True), "explore": ("oga/music/explore.ogg", True),
    "chase": ("oga/music/chase.ogg", False), "safe": ("oga/music/safe.mp3", False),
    "melancholy": ("oga/music/melancholy.flac", False), "boss": ("oga/music/boss.wav", True)}


def music():
    for name, (path, seamless) in MUSIC.items():
        x, sr = sf.read(os.path.join(SRC, path), always_2d=True)
        if sr != SR:
            g = np.gcd(sr, SR)
            x = resample_poly(x, SR // g, sr // g, axis=0)
        if not seamless:  # cut the silence at both ends, fold the last 3 s onto the start
            a = np.abs(x).max(1)
            on, end = np.argmax(a > 0.003), len(a) - np.argmax(a[::-1] > 0.003)
            x = x[on:end]
            f = 3 * SR
            t = np.linspace(0, 1, f)[:, None]
            head = x[:f] * np.sqrt(t) + x[-f:] * np.sqrt(1 - t)
            x = np.concatenate([head, x[f:-f]])
        x = x - x.mean(0)
        x = limit(x * 10 ** ((-12.0 - loud(x.mean(1))) / 20))  # music sits ~6 dB under the sfx
        for f in glob.glob(os.path.join(OUT, "music_%s.*" % name)):
            os.remove(f)
        with sf.SoundFile(os.path.join(OUT, "music_%s.ogg" % name), "w", SR, 2, format="OGG", subtype="VORBIS") as o:
            for i in range(0, len(x), 8192):  # in blocks: one big Vorbis write crashes libsndfile
                o.write(x[i:i + 8192].astype(np.float32))
        print("wrote music_%s %.0fs" % (name, len(x) / SR), flush=True)


# Every sfx name made here; tools/make_audio.py leaves these (and the MUSIC) alone.
NAMES = ["step_concrete", "step_grass", "step_wood", "step_gravel", "step_metal", "jump", "land", "door_open",
         "door_close", "door_slam", "door_locked", "pickup", "item_use", "click", "move", "notify", "save",
         "melee_hit", "punch", "enemy_hit", "gun_revolver", "gun_shotgun", "dry", "reload", "arrow_hit", "glass",
         "explosion", "scrape", "thud", "pick_set", "pick_snap", "pick_open", "car_engine", "car_stall", "car_door",
         "generator", "harvester", "swing", "fish_cast", "fish_splash", "fish_reel", "growl", "enemy_alert",
         "enemy_death", "hurt", "heartbeat", "radio_static", "radio_tune", "hiss", "gun_flare"]


def build():
    # footsteps: surfaces the player walks on (Snd.step), ~-6 dB under the rest
    variants("step_concrete", kn("footstep_concrete"), 0.5)
    variants("step_grass", kn("footstep_grass"), 0.5)
    variants("step_wood", kn("footstep_wood"), 0.5)
    variants("step_gravel", rpg("footstep0", range(5)), 0.5)
    metal = [trim(load(IMP + "impactMetal_light_%03d.ogg" % i, 1.15), max_s=0.25) for i in range(5)]
    variants("step_metal", [mix((c, 1.0, 0), (m, 0.35, 0)) for c, m in zip(kn("footstep_concrete"), metal)], 0.5)
    variants("jump", rpg("cloth", (1, 2, 3, 4)), 0.5)
    variants("land", [mix((s, 1.0, 0), (c, 0.7, 0)) for s, c in zip(kn("impactSoft_heavy", 3), kn("footstep_concrete", 3))], 0.7)

    # doors and locks
    variants("door_open", rpg("doorOpen_", (1, 2)), 0.7)
    variants("door_close", rpg("doorClose_", (1, 2, 3, 4)), 0.8)
    variants("door_slam", [mix((w, 1.0, 0), (d, 0.8, 0)) for w, d in zip(kn("impactWood_heavy", 3), rpg("doorClose_", (1, 2, 3)))], 0.9)
    variants("door_locked", [mix((trim(load(RPG + "metalLatch.ogg")), 1.0, 0), (trim(load(RPG + "metalClick.ogg")), 0.6, 0.12))], 0.7)
    variants("pick_set", [trim(load(UI + "switch%d.ogg" % i)) for i in (3, 7, 12, 18)], 0.6)
    variants("pick_snap", [trim(load(IMP + "impactTin_medium_%03d.ogg" % i, 1.3), max_s=0.3) for i in range(3)], 0.7)
    variants("pick_open", [mix((trim(load(RPG + "metalLatch.ogg")), 1.0, 0), (trim(load(RPG + "metalClick.ogg"), max_s=0.3), 0.8, 0.18))], 0.7)

    # items and menus
    variants("pickup", rpg("handleSmallLeather", ("", "2")), 0.6)
    variants("item_use", rpg("beltHandle", (1, 2)), 0.6)
    variants("click", [trim(load(IFC + "select_00%d.ogg" % i)) for i in (1, 2)], 0.3)
    variants("move", [trim(load(UI + "rollover%d.ogg" % i)) for i in (2, 3)], 0.22)
    variants("notify", [trim(load(IFC + "question_001.ogg"))], 0.55)
    variants("save", [trim(load(IFC + "confirmation_002.ogg"))], 0.6)

    # fighting
    variants("punch", kn("impactPunch_medium"), 0.6)
    variants("melee_hit", kn("impactPunch_heavy"), 0.85)
    variants("enemy_hit", [mix((p, 1.0, 0), (s, 0.6, 0)) for p, s in
                           zip([trim(load(IMP + "impactPunch_heavy_%03d.ogg" % i, 0.8)) for i in range(5)], kn("impactSoft_medium"))], 0.8)
    variants("gun_revolver", shots(FF + "Smith & Wesson 642/V_22P.wav", 2, 1.3) +
             shots(FF + "Smith & Wesson 642/V_27P.wav", 2, 1.0), 0.9)
    variants("gun_shotgun", shots(FF + "Nova/O_21P.wav", 2, 1.5) + shots(FF + "Model 12/K_22P.wav", 2, 1.5), 0.95)
    variants("dry", [trim(load("oga/residue/residue-sfx/emptyclip.ogg")), trim(load(RPG + "metalClick.ogg"), max_s=0.2)], 0.6)
    variants("reload", [trim(load("oga/gunreload1.wav")), trim(load("oga/shotguncock_0.wav"))], 0.7)
    variants("arrow_hit", kn("impactWood_medium"), 0.7)

    # the world
    variants("glass", kn("impactGlass_heavy"), 0.7)
    variants("explosion", [mix((trim(load(SCI + "lowFrequency_explosion_000.ogg")), 1.0, 0),
                               (trim(load(SCI + "explosionCrunch_00%d.ogg" % i)), 0.7, 0.0)) for i in (0, 2)], 0.95)
    variants("scrape", rpg("creak", (1, 2, 3)), 0.6)
    variants("thud", kn("impactSoft_heavy"), 0.7)

    # engines: the intro's car, the floodlight generator, the Harvester
    eng = load(CAR + "Car_Engine_Loop_2.ogg")
    variants("car_engine", [loop(eng[int(0.2 * SR):])], 0.6)
    variants("car_stall", [trim(load(CAR + "Car_Engine_Turning_Off.ogg"))], 0.7)
    variants("car_door", [trim(load(CAR + "Car_Door_Close.ogg"))], 0.7)
    variants("generator", [loop(load(CAR + "Car_Engine_Loop.ogg", 0.8)[int(0.2 * SR):])], 0.6)
    deep = load(CAR + "Car_Engine_Loop_2.ogg", 0.55)[int(0.3 * SR):]
    hum = load(SCI + "spaceEngineLow_000.ogg", 0.7)
    hum = np.tile(hum, int(np.ceil(len(deep) / len(hum))))[:len(deep)]
    variants("harvester", [loop(mix((deep, 1.0, 0), (hum, 0.5, 0)), 0.6)], 0.7)

    # swings and fishing
    X = "oga/x/"
    variants("swing", [trim(load(X + "swishes/swishes/swish-%d.wav" % i)) for i in (5, 6, 7, 8, 9)], 0.6)
    variants("fish_cast", [trim(load(X + "swishes/swishes/swish-%d.wav" % i, 0.8)) for i in (1, 3)], 0.5)
    variants("fish_splash", [trim(load(X + "water/splash_%02d.ogg" % i)) for i in (2, 3, 8, 12)], 0.6)
    click = trim(load(UI + "switch20.ogg"))
    variants("fish_reel", [mix(*[(click, 1.0 - 0.04 * k, 0.07 * k) for k in range(11)])], 0.45)

    # creatures and Alex
    variants("growl", shots(X + "monster-snarls_0.ogg", 4, 1.3, 0.85), 0.8)
    variants("enemy_alert", shots(X + "monster-snarl-attack.ogg", 3, 1.3), 0.9)
    variants("enemy_death", shots(X + "darsycho__zombie-moans.ogg", 3, 2.2, 0.8), 0.85)
    variants("hurt", shots(X + "death pain grunts.wav", 5, 0.6), 0.75)
    variants("heartbeat", shots(X + "heartbeat_slow_reverb.wav", 1, 1.0), 0.9)

    # radio, gas, flare
    st = load(X + "static1.wav")
    variants("radio_static", [loop(st[10 * SR:14 * SR], 0.3)], 0.45)
    variants("radio_tune", [trim(load(X + "static2.wav")[20 * SR:int(21.4 * SR)])], 0.5)
    variants("hiss", [loop(load(X + "compressed_gas_leak.ogg"), 0.3)], 0.45)
    variants("gun_flare", [mix((shots("oga/22 Pistol.wav", 1, 0.8, 0.7)[0], 1.0, 0),
                               (trim(load(X + "ignition.flac")), 0.6, 0.05))], 0.85)


if __name__ == "__main__":
    build()
    music()
