#!/usr/bin/env python3
"""Procedural audio for LAAF: every sample is synthesized here (stdlib only), nothing is sampled or downloaded.
Writes 16-bit mono 22.05 kHz .wav files into res://audio/ (music_*, sfx_*, voice_*).
    python3 tools/make_audio.py            # everything
    python3 tools/make_audio.py music      # only names starting with the prefix / containing the word
Music loops are seamless: beds are cross-faded, notes/reverb tails are folded back onto the start."""
import math, os, random, struct, sys, wave

SR = 22050
TAU = math.tau
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")


# ------------------------------------------------------------------ basics

def hz(m): return 440.0 * 2 ** ((m - 69) / 12)
def zeros(n): return [0.0] * int(n)
def secs(s): return int(s * SR)


def add(dst, src, start=0, gain=1.0):
    start = int(start)
    end = min(len(dst), start + len(src))
    for i in range(max(0, start), end):
        dst[i] += src[i - start] * gain


def noise(n, rng): return [rng.uniform(-1, 1) for _ in range(int(n))]


def lp(x, fc):
    a = 1 - math.exp(-TAU * fc / SR)
    y, s = [], 0.0
    for v in x:
        s += a * (v - s)
        y.append(s)
    return y


def hp(x, fc):
    l = lp(x, fc)
    return [a - b for a, b in zip(x, l)]


def bp(x, f, q=4.0):
    """RBJ biquad band-pass (constant 0 dB peak)."""
    w = TAU * f / SR
    al = math.sin(w) / (2 * q)
    b0, b2, a0, a1, a2 = al, -al, 1 + al, -2 * math.cos(w), 1 - al
    b0, b2, a1, a2 = b0 / a0, b2 / a0, a1 / a0, a2 / a0
    y, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for v in x:
        o = b0 * v + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y.append(o)
    return y


def bp_sweep(x, f0, f1, q=4.0):
    """Band-pass with a (list or linear) moving centre frequency: state-variable filter."""
    n = len(x)
    y, lo, band = [], 0.0, 0.0
    for i, v in enumerate(x):
        f = f0[i] if isinstance(f0, list) else f0 + (f1 - f0) * i / max(1, n - 1)
        k = 2 * math.sin(math.pi * min(f, SR * 0.2) / SR)
        hi = v - lo - band / q
        band += k * hi
        lo += k * band
        y.append(band)
    return y


def env_exp(n, tau, attack=0.002):
    a = max(1, secs(attack))
    return [min(1.0, i / a) * math.exp(-i / SR / tau) for i in range(int(n))]


def env_ar(n, a, r):
    a, r = max(1, secs(a)), max(1, secs(r))
    return [min(1.0, i / a, (n - i) / r) for i in range(int(n))]


def mul(x, e): return [a * b for a, b in zip(x, e)]
def scale(x, g): return [a * g for a in x]
def mix(*xs):
    n = max(len(x) for x in xs)
    o = zeros(n)
    for x in xs:
        add(o, x)
    return o


def lfo(n, f, ph=0.0): return [math.sin(TAU * (f * i / SR + ph)) for i in range(int(n))]


def osc(kind, f, n, ph=0.0):
    """f: Hz or per-sample list (glides). kinds: sin, saw, sqr, tri."""
    out, p = [], ph
    for i in range(int(n)):
        fi = f[i] if isinstance(f, list) else f
        p += fi / SR
        p -= math.floor(p)
        if kind == "sin": v = math.sin(TAU * p)
        elif kind == "saw": v = 2 * p - 1
        elif kind == "sqr": v = 1.0 if p < 0.5 else -1.0
        else: v = 4 * abs(p - 0.5) - 1
        out.append(v)
    return out


def glide(a, b, n, curve=1.0): return [a + (b - a) * (i / max(1, n - 1)) ** curve for i in range(int(n))]


def sat(x, drive=2.0): return [math.tanh(v * drive) for v in x]


def echo(x, t, fb, wet=1.0):
    d = secs(t)
    y = list(x)
    for i in range(d, len(y)):
        y[i] += y[i - d] * fb
    return [a + (b - a) * wet for a, b in zip(x, y)] if wet < 1 else y


def reverb(x, wet=0.3, size=1.0, damp=2500.0):
    """Schroeder-ish: 4 damped combs + 2 allpasses."""
    n = len(x)
    out = zeros(n)
    a = 1 - math.exp(-TAU * damp / SR)
    for t, fb in ((0.0297, 0.80), (0.0371, 0.82), (0.0411, 0.83), (0.0437, 0.84)):
        d = max(1, secs(t * size))
        buf = zeros(n)
        s = 0.0
        for i in range(n):
            fbv = buf[i - d] if i >= d else 0.0
            s += a * (fbv - s)
            buf[i] = x[i] + s * fb
        for i in range(n):
            out[i] += buf[i]
    for t, g in ((0.005, 0.7), (0.0017, 0.7)):
        d = max(1, secs(t * size))
        buf = list(out)
        for i in range(d, n):
            buf[i] = -g * out[i] + out[i - d] + g * buf[i - d]
        out = buf
    return [a_ + b * wet * 0.25 for a_, b in zip(x, out)]


def peak(x): return max(1e-9, max(abs(v) for v in x))


def write(name, x, level=0.8):
    os.makedirs(OUT, exist_ok=True)
    n = len(x)
    m = sum(x) / n
    x = [v - m for v in x]  # no DC offset (generator / harvester loops had up to 9%)
    loop = name.startswith(("music_", "sfx_generator", "sfx_harvester", "sfx_hiss", "sfx_radio_static"))
    if loop and n > 600:
        d = x[0] - x[-1]  # loops: close the seam with a tiny ramp so the wrap-around has no step
        for i in range(300):
            x[n - 300 + i] += d * (i + 1) / 300
    level = min(level, 0.9)  # guns / slams were hitting full scale
    p = level / peak(x)
    if name.startswith("voice_"):  # radio-filtered voices were 5-8 dB hotter than the rest
        r = math.sqrt(sum(v * v for v in x) / n) * p
        p *= min(1.0, 0.21 / max(r, 1e-9))  # rms cap ~ -13.5 dB
    fade = min(60, n // 4)  # no clicks at either end of one-shots; loops are already seamless
    data = bytearray()
    for i, v in enumerate(x):
        g = p
        if not loop and name.startswith(("sfx_", "voice_")):
            g *= min(1.0, (n - i) / fade) if fade else 1.0
        data += struct.pack("<h", int(max(-1, min(1, v * g)) * 32767))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(data))


# ------------------------------------------------------------------ instruments

def bell(f, dur, amp=1.0, ratio=3.5, index=2.5, tau=None):
    """FM bell: inharmonic modulator, index decays with the note."""
    n = secs(dur)
    tau = tau or dur * 0.35
    out, cp, mp = [], 0.0, 0.0
    for i in range(n):
        t = i / SR
        e = math.exp(-t / tau)
        cp += f / SR
        mp += f * ratio / SR
        out.append(math.sin(TAU * cp + index * e * math.sin(TAU * mp)) * e * min(1.0, i / 40))
    return scale(out, amp)


def musicbox(f, dur=2.5, amp=1.0, rng=None):
    """Tine: two slightly detuned inharmonic partials, soft click, a bit flat as the spring runs down."""
    n = secs(dur)
    d = 1 + (rng.uniform(-0.007, 0.004) if rng else 0)
    out = zeros(n)
    for k, (r, a, tau) in enumerate(((1.0, 1.0, 0.9), (2.76, 0.35, 0.35), (5.4, 0.15, 0.15), (1.003, 0.5, 0.8))):
        ph = 0.0
        for i in range(n):
            ph += f * d * r / SR
            out[i] += math.sin(TAU * ph) * a * math.exp(-i / SR / tau)
    return scale(mul(out, [min(1.0, i / 30) for i in range(n)]), amp)


def pad(freqs, dur, amp=1.0, det=(-8, 0, 7), attack=2.0, release=2.0, bright=0.5, rng=None):
    """Detuned additive pad (fundamental + 2 weak harmonics per detuned copy)."""
    n = secs(dur)
    out = zeros(n)
    for f in freqs:
        for c in det:
            ff = f * 2 ** (c / 1200)
            ph = rng.random() if rng else 0.0
            inc = ff / SR
            for i in range(n):
                p = ph + inc * i
                out[i] += math.sin(TAU * p) + bright * 0.5 * math.sin(TAU * 2 * p) + bright * 0.25 * math.sin(TAU * 3 * p)
    return scale(mul(out, env_ar(n, attack, release)), amp / (len(freqs) * len(det)))


def saw_voice(f, dur, amp=1.0, cutoff=900.0, det=(-6, 6), vib=0.0, a=0.05, r=0.3):
    n = secs(dur)
    out = zeros(n)
    for c in det:
        fr = [f * 2 ** (c / 1200) * (1 + vib * math.sin(TAU * 5.2 * i / SR)) for i in range(n)] if vib else f * 2 ** (c / 1200)
        add(out, osc("saw", fr, n), 0, 1.0)
    return scale(mul(lp(out, cutoff), env_ar(n, a, r)), amp / len(det))


def kick(amp=1.0, f0=130, f1=42, dur=0.35):
    n = secs(dur)
    fr = [f1 + (f0 - f1) * math.exp(-i / SR / 0.035) for i in range(n)]
    return scale(mul(osc("sin", fr, n), env_exp(n, 0.14, 0.001)), amp)


def clang(f, dur, amp, rng):
    n = secs(dur)
    out = zeros(n)
    for r in (1.0, 1.47, 2.09, 2.56, 3.3, 4.12):
        ph = rng.random()
        a = rng.uniform(0.3, 1.0)
        out = [o + a * math.sin(TAU * (ph + f * r * i / SR)) * math.exp(-i / SR / (dur * 0.3 / r)) for i, o in enumerate(out)]
    return scale(out, amp)


def hat(rng, dur=0.05, amp=1.0):
    n = secs(dur)
    return scale(mul(hp(noise(n, rng), 5000), env_exp(n, dur * 0.3, 0.0005)), amp)


class Track:
    """A seamless loop: `bed` is cross-faded, `note` events may run past the end and wrap round onto the start."""
    def __init__(self, seconds, tail=4.0, seed=1):
        self.N = secs(seconds)
        self.T = secs(tail)
        self.buf = zeros(self.N + self.T)
        self.rng = random.Random(seed)
        self.dur = seconds

    def bed(self, x, gain=1.0):
        N, L = self.N, min(secs(2.0), self.N // 2)
        x = list(x) + zeros(max(0, N + L - len(x)))
        for i in range(L):
            w = i / L
            x[i] = x[i] * w + x[N + i] * (1 - w)
        add(self.buf, x[:N], 0, gain)

    def note(self, x, t, gain=1.0):
        add(self.buf, x, secs(t), gain)

    def render(self, wet=0.0, size=1.0, damp=2500.0, level=0.7):
        b = reverb(self.buf, wet, size, damp) if wet else self.buf
        out = b[:self.N]
        for i in range(self.T):
            out[i % self.N] += b[self.N + i] if self.N + i < len(b) else 0.0
        return out


def q(f, seconds): return round(f * seconds) / seconds  # whole cycles per loop


def wind(n, rng, lo=300.0, hi=1400.0, loop_s=40.0, q_=2.0, cycles=(1, 3)):
    """Filtered-noise wind with slow gusts (LFO periods divide the loop)."""
    x = noise(n, rng)
    m1, m2 = lfo(n, cycles[0] / loop_s), lfo(n, cycles[1] / loop_s, 0.3)
    fc = [lo + (hi - lo) * (0.5 + 0.35 * a + 0.15 * b) for a, b in zip(m1, m2)]
    y = bp_sweep(x, fc, 0, q_)
    return mul(y, [0.55 + 0.45 * (0.5 + 0.5 * a) for a in m2])


# ------------------------------------------------------------------ music

def music_menu():
    T = 32.0
    t = Track(T, seed=11)
    n = t.N
    r = t.rng
    t.bed(scale(osc("sin", q(36.7, T), n), 0.6))
    t.bed(scale(osc("sin", q(73.4, T), n), 0.28))
    swell = [0.55 + 0.45 * v for v in lfo(n, 1 / T)]
    for f, g in ((146.8, 0.12), (155.6, 0.1), (220.0, 0.08), (207.7, 0.07)):  # D / Eb, A / Ab: minor seconds
        t.bed(mul(scale(osc("sin", q(f, T), n), g), swell if f < 200 else [1.1 - s for s in swell]))
    t.bed(scale(wind(n + secs(2), r, 250, 900, T, 3.0, (1, 2)), 0.25))
    mel = [(0, 74), (4, 77), (8, 76), (11, 75), (14, 76), (16, 69), (20, 70), (24, 72), (27, 73), (29, 74)]
    for beat, m in mel:  # 1 beat = 1 s
        t.note(bell(hz(m), 6.0, 0.28, 3.5, 2.0), beat)
        if beat % 8 == 0:
            t.note(bell(hz(m - 24), 6.0, 0.2, 2.0, 1.2), beat)
    for beat in (6, 22):  # distant sub pulse
        t.note(kick(0.45, 60, 36, 0.8), beat)
    return t.render(wet=1.0, size=1.6, damp=2200)


def music_explore():
    T = 40.0
    t = Track(T, seed=22)
    n = t.N
    r = t.rng
    t.bed(scale(wind(n + secs(2), r, 260, 1500, T, 2.0, (1, 3)), 0.55))
    t.bed(scale(wind(n + secs(2), r, 700, 2600, T, 5.0, (2, 5)), 0.12))
    for f, g in ((55.0, 0.5), (55.2, 0.35), (82.4, 0.12), (116.6, 0.07)):  # A1 beating on itself, E2, Bb2
        t.bed(scale(osc("sin", q(f, T), n), g))
    sub = scale(lp(osc("saw", q(55.0, T), n), 160), 0.28)
    t.bed(mul(sub, [0.6 + 0.4 * v for v in lfo(n, 2 / T)]))
    # distant metal groans: FM glides through a resonant band
    for at, f0, f1, ln in ((4, 180, 140, 4.0), (15, 230, 170, 3.0), (27, 130, 105, 5.0), (35, 300, 240, 3.0)):
        m = secs(ln)
        g = bp_sweep(osc("saw", glide(f0, f1, m), m), 420, 360, 8.0)
        g = mul(g, env_ar(m, ln * 0.4, ln * 0.5))
        t.note(g, at, 0.35)
    t.note(bell(hz(57), 8.0, 0.2, 2.76, 1.6), 9.0)  # a far-off bell
    t.note(bell(hz(50), 9.0, 0.18, 2.76, 1.6), 31.0)
    for at in (12.5, 22.0, 38.0):  # something heavy, far away
        t.note(kick(0.35, 70, 30, 0.9), at)
    return t.render(wet=1.0, size=2.0, damp=1800)


def music_chase():
    BPM = 144
    B = 60 / BPM
    beats = 64
    T = beats * B
    t = Track(T, tail=2.0, seed=33)
    r = t.rng
    n = t.N
    for b in range(beats):
        tt = b * B
        t.note(kick(1.0, 150, 40, 0.28), tt)
        if b % 2 == 1:
            t.note(clang(r.choice((420, 560, 700)), 0.3, 0.25, r), tt)
        for k in (0.5, 0.25, 0.75):
            if (b + int(k * 4)) % 3 != 0:
                t.note(hat(r, 0.05, 0.35 if k == 0.5 else 0.18), tt + k * B)
        if b % 4 == 3:
            t.note(mul(hp(noise(secs(B * 0.5), r), 2500), env_ar(secs(B * 0.5), B * 0.45, 0.01)), tt + B * 0.5, 0.25)
    # dissonant ostinato: E - F (minor second) with tritone B-flat stabs
    pat = [(0, 28), (0.75, 29), (1.5, 28), (2, 34), (3, 29)]
    for bar in range(beats // 4):
        for off, m in pat:
            f = hz(m + (1 if bar % 8 >= 6 else 0))
            tt = bar * 4 * B + off * B
            t.note(sat(saw_voice(f, B * 0.6, 0.6, 600 + 200 * (bar % 4), (-9, 9), a=0.005, r=0.1), 3.0), tt, 0.5)
        if bar % 2 == 1:
            for m in (52, 58, 53):  # stab cluster
                t.note(sat(saw_voice(hz(m), B * 0.9, 0.5, 2200, (-12, 12), a=0.003, r=0.25), 2.0), bar * 4 * B + 2 * B, 0.16)
    for k in range(beats // 16):  # screeching descending tone over the last bars of each phrase
        m = secs(B * 8)
        f = [hz(88) * 2 ** (-i / m / 6) + 6 * math.sin(i / 700) for i in range(m)]
        t.note(mul(osc("sin", f, m), env_ar(m, B * 6, B * 1.5)), k * 16 * B + B * 8, 0.1)
    t.bed(scale(wind(n, r, 500, 2200, T, 3.0, (1, 4)), 0.1))
    return t.render(wet=0.5, size=0.8, damp=3500)


def music_safe():
    BPM = 76
    B = 60 / BPM
    bars = 12
    T = bars * 3 * B
    t = Track(T, seed=44)
    r = t.rng
    n = t.N
    # 3/4 music-box melody in A minor (one chromatic wobble per phrase)
    mel = [(0, 76), (1, 72), (2, 69), (3, 71), (4, 72), (5, 74), (6, 76), (8, 79), (9, 76), (10, 72), (12, 71),
           (13, 68), (14, 69), (18, 76), (19, 77), (20, 76), (21, 72), (22, 69), (24, 71), (25, 70), (26, 69),
           (27, 64), (30, 72), (31, 74), (32, 76), (33, 79), (34, 77), (35, 76)]
    for beat, m in mel:
        t.note(musicbox(hz(m), 3.0, 0.5, r), beat * B)
    for bar in range(0, bars, 2):  # sparse accompaniment: low tines
        for k, m in enumerate((57, 64, 60)):
            t.note(musicbox(hz(m - 12), 3.0, 0.3, r), (bar * 3 + k * 1.0) * B)
    chords = [(45, 52, 60), (41, 48, 57), (43, 50, 59), (40, 47, 56)]
    seg = T / 4
    for i, ch in enumerate(chords):
        t.note(pad([hz(m) for m in ch], seg + 4.0, 0.35, (-9, 8), seg * 0.4, 4.0, 0.2, r), i * seg)
    t.bed(scale(osc("sin", q(55.0, T), n), 0.18))
    t.bed(scale(lp(noise(n + secs(2), r), 900), 0.015))
    return t.render(wet=0.9, size=1.3, damp=3000)


def music_melancholy():
    B = 0.75
    T = 64 * B
    t = Track(T, seed=55)
    r = t.rng
    n = t.N
    prog = [((45, 52, 57, 60, 64), 69), ((41, 48, 53, 57, 60), 72), ((38, 45, 50, 53, 57), 74), ((40, 47, 52, 56, 59), 76)]
    for ci, (ch, top) in enumerate(prog):
        t0 = ci * 16 * B
        t.note(pad([hz(m) for m in ch[:3]], 16 * B + 3, 0.5, (-10, 0, 9), 3.0, 3.0, 0.7, r), t0)
        t.note(saw_voice(hz(ch[0] - 12), 16 * B + 1, 0.55, 380, (-5, 5), 4.5, 1.2, 1.5), t0)
        arp = [ch[1], ch[2], ch[3], ch[4], ch[3], ch[2], ch[1], ch[2]]
        for k in range(32):  # eighth-note e-piano
            m = arp[k % 8] + (12 if k % 16 == 15 else 0)
            t.note(bell(hz(m), 2.2, 0.17 + 0.05 * (k % 4 == 0), 1.0, 1.1, 0.8), t0 + k * B / 2)
        for k, off in enumerate((0, 6, 8, 12)):  # a lonely top line
            m = top + (-2 if k == 1 else 0) + (1 if (ci == 3 and k == 2) else 0)
            t.note(saw_voice(hz(m), 3 * B, 0.5, 1800, (-4, 4), 5.0, 0.4, 0.8), t0 + off * B, 0.5)
    t.bed(scale(wind(n + secs(2), r, 300, 900, T, 3.0, (1, 2)), 0.08))
    return t.render(wet=0.9, size=1.5, damp=3200)


def music_boss():
    BPM = 168
    B = 60 / BPM
    beats = 64
    T = beats * B
    t = Track(T, tail=2.5, seed=66)
    r = t.rng
    n = t.N
    for b in range(beats):
        tt = b * B
        t.note(kick(1.1, 160, 38, 0.3), tt)
        if b % 4 == 2:
            t.note(clang(300, 0.5, 0.5, r), tt)
            t.note(mul(hp(noise(secs(0.25), r), 1500), env_exp(secs(0.25), 0.08)), tt, 0.5)
        if b % 8 == 7:
            t.note(kick(0.7, 90, 35, 0.2), tt + B * 0.5)
        t.note(hat(r, 0.04, 0.3), tt + B * 0.5)
    for k in range(beats * 2):  # sixteenth-ish bass in E / F with a tritone leap
        m = (28, 28, 29, 28, 34, 28, 29, 27)[k % 8]
        t.note(sat(saw_voice(hz(m), B * 0.45, 0.8, 520, (-8, 8), a=0.004, r=0.08), 4.0), k * B / 2, 0.45)
    for ph in range(beats // 16):  # choir-ish cluster 'oh' with minor seconds, and a rising scream
        t0 = ph * 16 * B
        notes = [hz(m) for m in (52, 53, 59, 64)]
        d = 16 * B + 1.5
        p = pad(notes, d, 0.6, (-14, -4, 6, 15), 4.0, 2.5, 1.0, r)
        t.note(bp(p, 700, 1.5), t0, 0.7)
        t.note(bp(p, 1100, 2.0), t0, 0.4)
        m = secs(8 * B)
        f = glide(hz(70), hz(94), m, 2.0)
        sc = mul(bp(osc("saw", f, m), 1400, 1.5), env_ar(m, 7 * B, 0.2))
        t.note(sat(sc, 2.0), t0 + 8 * B, 0.18)
        t.note(clang(110, 2.0, 0.6, r), t0)
    t.bed(scale(wind(n, r, 400, 2000, T, 4.0, (1, 4)), 0.1))
    return t.render(wet=0.55, size=1.0, damp=3000)


def stinger(kind):
    r = random.Random(7)
    if kind == "reveal":  # reversed-ish swell into a heavy hit
        n = secs(4.5)
        sw = mul(bp_sweep(noise(n, r), 200, 3000, 2.0), [(i / n) ** 3 for i in range(n)])
        cluster = mix(*[mul(osc("saw", hz(m), n), [(i / n) ** 2 for i in range(n)]) for m in (47, 48, 53, 59)])
        x = zeros(n + secs(2))
        add(x, mix(sw, scale(lp(cluster, 1200), 0.4)), 0, 0.7)
        add(x, kick(1.4, 90, 28, 1.6), secs(3.4))
        add(x, clang(150, 3.0, 0.7, r), secs(3.4))
        return reverb(x, 0.8, 1.5)
    if kind == "dread":  # bowed metal + sub drop
        n = secs(3.5)
        x = bp_sweep(osc("saw", glide(180, 150, n), n), 600, 520, 10.0)
        x = mul(x, env_ar(n, 1.2, 1.8))
        x = mix(scale(x, 0.5), scale(mul(osc("sin", glide(60, 34, n), n), env_ar(n, 0.5, 2.0)), 0.8))
        return reverb(x + zeros(secs(1.5)), 0.7, 1.4)
    n = secs(4.0)  # "boss": giant impact + choir cluster
    x = zeros(n)
    add(x, kick(1.5, 100, 26, 2.0), 0)
    add(x, clang(95, 3.5, 1.0, r), 0)
    add(x, mul(bp(pad([hz(m) for m in (40, 41, 47, 52)], 4.0, 1.0, (-12, 0, 12), 0.05, 3.0, 1.0, r), 800, 1.5), env_exp(n, 1.5)), 0, 0.6)
    return reverb(x, 0.7, 1.4)


# ------------------------------------------------------------------ sfx

def thump(f0=110, f1=45, dur=0.18, amp=1.0): return kick(amp, f0, f1, dur)


def sfx_step(surface, v):
    r = random.Random(sum(map(ord, surface)) * 7 + v)
    p = r.uniform(0.9, 1.15)
    if surface == "concrete":
        n = secs(0.16)
        x = mix(scale(mul(bp(noise(n, r), 1700 * p, 1.2), env_exp(n, 0.03)), 0.8), scale(thump(120 * p, 60, 0.12), 0.6))
    elif surface == "grass":
        n = secs(0.22)
        x = mix(scale(mul(lp(noise(n, r), 2200 * p), env_ar(n, 0.04, 0.12)), 0.8), scale(thump(90, 50, 0.1), 0.25))
    elif surface == "wood":
        n = secs(0.25)
        x = mix(scale(thump(150 * p, 70, 0.14), 0.8), scale(mul(bp(noise(n, r), 600 * p, 6), env_exp(n, 0.08)), 0.6),
                scale(mul(osc("sin", 310 * p, n), env_exp(n, 0.05)), 0.2))
    elif surface == "metal":
        n = secs(0.5)
        x = mix(scale(mul(bp(noise(n, r), 2500, 1.5), env_exp(n, 0.02)), 0.5), scale(thump(130, 60, 0.1), 0.5),
                scale(clang(r.uniform(700, 900) * p, 0.5, 0.35, r), 0.6))
    else:  # gravel
        n = secs(0.3)
        x = zeros(n)
        for k in range(14):
            c = mul(hp(noise(secs(0.012), r), 2500), env_exp(secs(0.012), 0.004))
            add(x, c, secs(r.uniform(0, 0.2)) , r.uniform(0.3, 0.9))
        x = mix(x, scale(thump(100, 55, 0.1), 0.3))
    return x


def sfx_door_open(rng):
    n = secs(1.3)
    f = [150 + 70 * math.sin(i / n * 2.4) ** 2 + 8 * math.sin(i / 300) for i in range(n)]
    cr = bp_sweep(osc("saw", f, n), 700, 1100, 9.0)
    cr = mul(cr, env_ar(n, 0.15, 0.4))
    x = zeros(secs(1.6))
    add(x, cr, secs(0.1), 0.6)
    add(x, mul(hp(noise(secs(0.02), rng), 1500), env_exp(secs(0.02), 0.006)), 0, 0.7)  # latch
    add(x, thump(160, 90, 0.08), 0, 0.4)
    return x


def sfx_door_close(rng):
    n = secs(0.9)
    x = zeros(n)
    add(x, thump(110, 50, 0.3), 0, 1.0)
    add(x, mul(bp(noise(secs(0.3), rng), 400, 1.5), env_exp(secs(0.3), 0.07)), 0, 0.8)
    add(x, mul(hp(noise(secs(0.02), rng), 1800), env_exp(secs(0.02), 0.005)), secs(0.12), 0.6)  # latch
    return reverb(x, 0.25, 0.8)


def sfx_door_slam(rng):
    n = secs(2.2)
    x = zeros(n)
    add(x, thump(90, 30, 0.7, 1.5), 0)
    add(x, mul(lp(noise(secs(0.5), rng), 1500), env_exp(secs(0.5), 0.12)), 0, 1.0)
    add(x, clang(210, 1.0, 0.25, rng), 0)
    return reverb(x, 0.6, 1.4)


def sfx_door_locked(rng):
    x = zeros(secs(0.8))
    for t in (0.0, 0.12, 0.3):
        add(x, mix(mul(bp(noise(secs(0.08), rng), 900, 3), env_exp(secs(0.08), 0.02)), scale(thump(130, 80, 0.06), 0.6)), secs(t), 0.9)
        add(x, clang(1800, 0.25, 0.2, rng), secs(t))
    return x


def sfx_pickup(rng):
    n = secs(0.5)
    x = zeros(n)
    add(x, mul(bp(noise(secs(0.18), rng), 3500, 1.0), env_ar(secs(0.18), 0.02, 0.15)), 0, 0.4)  # rustle
    add(x, bell(hz(84), 0.45, 0.3, 3.0, 1.0, 0.12), secs(0.05))
    return x


def sfx_item_use(rng):
    x = zeros(secs(1.2))
    add(x, bell(hz(60), 1.2, 0.5, 2.0, 1.2, 0.5), 0)
    add(x, bell(hz(67), 1.1, 0.35, 2.0, 1.2, 0.4), secs(0.12))
    add(x, mul(lp(noise(secs(0.3), rng), 1200), env_ar(secs(0.3), 0.1, 0.2)), 0, 0.2)
    return x


def sfx_click(f=1400, dur=0.05, amp=1.0):
    n = secs(dur)
    return scale(mul(mix(osc("sqr", f, n), osc("sin", f * 2, n)), env_exp(n, dur * 0.25, 0.0005)), amp * 0.5)


def sfx_notify(rng):
    x = zeros(secs(1.6))
    add(x, bell(hz(62), 1.6, 0.5, 2.0, 1.4, 0.6), 0)
    add(x, bell(hz(63), 1.4, 0.4, 2.0, 1.4, 0.5), secs(0.22))  # minor second: unsettled
    return x


def sfx_save(rng):
    x = zeros(secs(3.0))
    for k, m in enumerate((69, 72, 76, 81)):
        add(x, musicbox(hz(m), 2.2, 0.5, rng), secs(k * 0.2))
    add(x, pad([hz(57), hz(64), hz(69)], 3.0, 0.5, (-8, 7), 0.8, 1.6, 0.3, rng), 0, 0.6)
    return reverb(x, 0.6, 1.3)


def sfx_swing(rng):
    n = secs(0.3)
    return mul(bp_sweep(noise(n, rng), 300, 1800, 1.8), [math.sin(math.pi * i / n) ** 2 for i in range(n)])


def sfx_hit(rng, heavy=False):
    n = secs(0.35)
    x = zeros(n)
    add(x, thump(130 if not heavy else 90, 40, 0.25, 1.0), 0)
    add(x, mul(lp(noise(n, rng), 2500), env_exp(n, 0.05)), 0, 0.8)
    add(x, mul(hp(noise(secs(0.03), rng), 2000), env_exp(secs(0.03), 0.008)), 0, 0.5)
    return x


def sfx_gun(rng, kind):
    if kind == "revolver":
        n = secs(1.4)
        x = zeros(n)
        add(x, mul(lp(noise(secs(0.5), rng), 5000), env_exp(secs(0.5), 0.05, 0.0003)), 0, 1.0)
        add(x, kick(1.4, 200, 50, 0.25), 0)
        add(x, mul(hp(noise(secs(0.01), rng), 3000), env_exp(secs(0.01), 0.003)), 0, 1.0)
        return reverb(x, 0.5, 1.2)
    if kind == "shotgun":
        n = secs(1.8)
        x = zeros(n)
        add(x, mul(lp(noise(secs(0.8), rng), 3500), env_exp(secs(0.8), 0.14, 0.0003)), 0, 1.2)
        add(x, kick(1.8, 150, 32, 0.5), 0)
        return reverb(x, 0.6, 1.5)
    n = secs(1.5)  # flare gun: pop + hiss
    x = zeros(n)
    add(x, kick(0.9, 160, 60, 0.15), 0)
    add(x, mul(bp_sweep(noise(n, rng), 1500, 5000, 1.0), env_ar(n, 0.02, 1.2)), 0, 0.5)
    return reverb(x, 0.3, 1.0)


def sfx_dry(rng):
    x = zeros(secs(0.25))
    add(x, sfx_click(900, 0.04, 1.0), 0)
    add(x, clang(1500, 0.15, 0.2, rng), 0)
    add(x, sfx_click(600, 0.03, 0.6), secs(0.1))
    return x


def sfx_reload(rng):
    x = zeros(secs(1.6))
    for t, f in ((0.0, 700), (0.35, 500), (0.55, 520), (0.7, 540), (1.15, 800), (1.4, 450)):
        add(x, sfx_click(f, 0.06, 1.0), secs(t))
        add(x, clang(f * 2, 0.15, 0.15, rng), secs(t))
    add(x, thump(150, 90, 0.08, 0.5), secs(1.4))
    return x


def sfx_bow(rng):
    n = secs(0.9)
    x = zeros(n)
    d = secs(1 / 190)  # Karplus-Strong twang
    ks = [rng.uniform(-1, 1) for _ in range(d)]
    out = []
    for i in range(secs(0.7)):
        v = ks[i % d]
        ks[i % d] = 0.5 * (v + ks[(i + 1) % d]) * 0.997
        out.append(v)
    add(x, out, 0, 0.7)
    add(x, mul(bp_sweep(noise(secs(0.3), rng), 4000, 1200, 1.5), env_ar(secs(0.3), 0.02, 0.28)), secs(0.03), 0.35)
    return x


def sfx_arrow_hit(rng):
    x = zeros(secs(0.6))
    add(x, thump(190, 100, 0.12, 1.0), 0)
    add(x, mul(hp(noise(secs(0.03), rng), 2500), env_exp(secs(0.03), 0.01)), 0, 0.5)
    d = secs(1 / 330)
    ks = [rng.uniform(-1, 1) for _ in range(d)]
    out = []
    for i in range(secs(0.4)):
        v = ks[i % d]
        ks[i % d] = 0.5 * (v + ks[(i + 1) % d]) * 0.99
        out.append(v)
    add(x, out, secs(0.01), 0.25)
    return x


def growl(rng, dur=1.0, f0=85, rough=30.0, pitch_drop=0.0, amp=1.0):
    n = secs(dur)
    f = [f0 * (1 + 0.04 * math.sin(i / SR * 7)) * (1 - pitch_drop * i / n) for i in range(n)]
    src = mix(osc("saw", f, n), scale(osc("saw", [v * 0.5 for v in f], n), 0.7), scale(noise(n, rng), 0.25))
    trem = [0.55 + 0.45 * math.sin(TAU * rough * i / SR) for i in range(n)]
    src = mul(src, trem)
    y = mix(bp(src, 450, 3.0), scale(bp(src, 1100, 3.0), 0.6), scale(bp(src, 2300, 4.0), 0.3))
    return scale(mul(sat(y, 2.0), env_ar(n, dur * 0.15, dur * 0.4)), amp)


def sfx_heartbeat():
    n = secs(1.0)
    x = zeros(n)
    add(x, kick(1.0, 75, 38, 0.22), 0)
    add(x, kick(0.7, 70, 34, 0.2), secs(0.28))
    return x


def sfx_static(rng, dur=2.5):
    n = secs(dur)
    x = bp(noise(n, rng), 1800, 0.5)
    x = [v * (0.6 + 0.4 * math.sin(i / 900)) for i, v in enumerate(x)]
    for _ in range(int(dur * 14)):
        add(x, mul(noise(secs(0.004), rng), env_exp(secs(0.004), 0.001)), secs(rng.uniform(0, dur - 0.01)), rng.uniform(1, 4))
    return x


def sfx_tune(rng):
    n = secs(2.0)
    f = [500 + 900 * (0.5 + 0.5 * math.sin(i / n * 9)) for i in range(n)]
    x = mix(scale(mul(osc("sin", f, n), [0.2 + 0.2 * math.sin(i / 400) for i in range(n)]), 0.5),
            scale(bp_sweep(noise(n, rng), f, 0, 1.0), 0.6))
    return x


def sfx_lock_beep():
    x = zeros(secs(0.9))
    add(x, mul(osc("sin", 880, secs(0.18)), env_ar(secs(0.18), 0.01, 0.1)), 0, 0.5)
    add(x, mul(osc("sin", 1175, secs(0.4)), env_ar(secs(0.4), 0.01, 0.35)), secs(0.2), 0.5)
    return x


def sfx_bell_toll():
    x = zeros(secs(7.0))
    for r_, a, tau in ((0.5, 0.6, 3.5), (1.0, 1.0, 3.0), (1.2, 0.5, 2.5), (1.5, 0.4, 2.0), (2.0, 0.5, 1.6), (2.5, 0.25, 1.2), (2.76, 0.3, 1.0), (4.07, 0.15, 0.6)):
        n = len(x)
        add(x, [a * math.sin(TAU * 196 * r_ * i / SR) * math.exp(-i / SR / tau) for i in range(n)])
    add(x, thump(200, 100, 0.08, 0.8), 0)
    return reverb(x, 0.5, 1.2)


def sfx_pick_set(rng):
    x = zeros(secs(0.15))
    add(x, sfx_click(2000, 0.03, 1.0), 0)
    add(x, clang(2600, 0.1, 0.2, rng), 0)
    return x


def sfx_pick_snap(rng):
    x = zeros(secs(0.7))
    add(x, mul(hp(noise(secs(0.02), rng), 3000), env_exp(secs(0.02), 0.005)), 0, 1.0)
    add(x, clang(3200, 0.6, 0.5, rng), 0)
    return x


def sfx_pick_open(rng):
    x = zeros(secs(0.7))
    add(x, sfx_click(900, 0.05), 0)
    add(x, sfx_click(650, 0.05), secs(0.12))
    add(x, thump(120, 70, 0.1, 0.6), secs(0.22))
    add(x, clang(1500, 0.3, 0.25, rng), secs(0.22))
    return x


def sfx_cast(rng):
    x = zeros(secs(1.1))
    add(x, mul(bp_sweep(noise(secs(0.4), rng), 600, 3000, 1.5), [math.sin(math.pi * i / secs(0.4)) for i in range(secs(0.4))]), 0, 0.5)
    add(x, mul(lp(noise(secs(0.4), rng), 1800), env_exp(secs(0.4), 0.1)), secs(0.5), 0.6)
    add(x, bell(380, 0.3, 0.2, 2.0, 0.5, 0.06), secs(0.5))
    return x


def sfx_splash(rng):
    n = secs(1.0)
    x = mul(bp_sweep(noise(n, rng), 2500, 600, 0.9), env_ar(n, 0.01, 0.9))
    add(x, [math.sin(TAU * 140 * i / SR) * math.exp(-i / SR / 0.1) for i in range(secs(0.3))], 0, 0.6)
    return x


def sfx_reel(rng):
    x = zeros(secs(0.8))
    for k in range(10):
        add(x, sfx_click(1100 + 90 * (k % 2), 0.025, 0.8), secs(k * 0.08))
    return x


def sfx_engine(rng, dur=2.0, f=48.0, heavy=False):
    n = secs(dur)
    f = round(f * dur) / dur
    pulse = [max(0.0, math.sin(TAU * f * i / SR)) ** (6 if heavy else 12) for i in range(n)]
    x = mix(lp(scale(pulse, 2.0), 260), scale(osc("saw", q(f * 2, dur), n), 0.15), scale(lp(noise(n, rng), 700), 0.25),
            scale(osc("sin", q(f / 2, dur), n), 0.4))
    cl = mul(bp(noise(n, rng), 3200 if heavy else 2200, 3), [0.5 + 0.5 * v for v in lfo(n, 12 / dur)])
    x = mix(x, scale(cl, 0.12))
    if heavy:
        x = mix(x, scale(bp(osc("saw", q(1300, dur), n), 1300, 12), 0.04))
    return x


def sfx_hiss(rng, dur=2.0):
    n = secs(dur)
    return mul(hp(noise(n, rng), 3000), [0.7 + 0.3 * math.sin(TAU * 3 * i / n) for i in range(n)])


def sfx_glass(rng):
    n = secs(1.2)
    x = zeros(n)
    add(x, mul(hp(noise(secs(0.15), rng), 3000), env_exp(secs(0.15), 0.04)), 0, 1.0)
    for _ in range(18):
        add(x, bell(rng.uniform(2500, 6000), 0.2, 0.1, 3.0, 1.0, 0.05), secs(rng.uniform(0.02, 0.6)))
    return x


def sfx_explosion(rng):
    """Fuel drum bursting: a sub thump, a roar of low noise that rolls off, the drum's metal tearing and a
    crackle of burning fuel in the tail."""
    n = secs(3.0)
    x = zeros(n)
    add(x, kick(2.0, 110, 26, 0.9), 0)
    add(x, mul(lp(noise(n, rng), 900), env_exp(n, 0.45, 0.004)), 0, 1.3)
    add(x, mul(lp(noise(secs(0.6), rng), 3500), env_exp(secs(0.6), 0.09, 0.001)), 0, 0.9)
    add(x, mul(bp_sweep(noise(secs(0.5), rng), 2200, 700, 3.0), env_exp(secs(0.5), 0.12)), secs(0.02), 0.5)  # metal
    for _ in range(40):  # burning fuel crackle
        t = rng.uniform(0.25, 2.6)
        add(x, mul(hp(noise(secs(0.012), rng), 2500), env_exp(secs(0.012), 0.004)), secs(t), rng.uniform(0.1, 0.35) * (1.2 - t / 3))
    return reverb(sat(x, 1.4), 0.45, 1.6)


def sfx_scrape(rng):
    n = secs(2.0)
    return mul(bp_sweep(osc("saw", glide(90, 70, n), n), 800, 500, 6), env_ar(n, 0.8, 0.9))


def sfx_hurt(rng, v=0):
    return voice_clip(PROFILES["alex"], "o" if v else "a", rng, dur=0.28, f0_mul=1.3 if v else 1.15, contour=-0.35, rough=0.7)


def sfx_enemy_alert(rng):
    return growl(rng, 1.3, 120, 18.0, -0.5, 1.0)


def sfx_death(rng):
    return reverb(growl(rng, 2.2, 95, 22.0, 0.55, 1.0), 0.3, 1.0)


def sfx_land(rng):
    n = secs(0.25)
    return mix(scale(thump(100, 45, 0.2), 0.9), scale(mul(lp(noise(n, rng), 1500), env_exp(n, 0.04)), 0.5))


def sfx_jump(rng):
    n = secs(0.18)
    return scale(mul(bp_sweep(noise(n, rng), 800, 1500, 1.2), env_ar(n, 0.04, 0.12)), 0.5)


def sfx_ladder_thud(rng): return thump(110, 70, 0.1, 1.0)


# ------------------------------------------------------------------ voices

VOWELS = {"a": (730, 1090, 2440), "e": (530, 1840, 2480), "i": (300, 2200, 3000), "o": (450, 800, 2500), "u": (320, 800, 2400)}
# f0 Hz, formant scale, roughness 0..1, breath 0..1, vibrato Hz-depth, style, syllable seconds
PROFILES = {
    "alex": dict(f0=122, fs=1.0, rough=0.12, breath=0.1, vib=0.01, style="", syl=0.095),
    "elena": dict(f0=208, fs=1.17, rough=0.05, breath=0.22, vib=0.012, style="", syl=0.1),
    "marcus": dict(f0=92, fs=0.9, rough=0.4, breath=0.1, vib=0.006, style="", syl=0.12),
    "owen": dict(f0=108, fs=0.95, rough=0.15, breath=0.28, vib=0.004, style="", syl=0.11),
    "nora": dict(f0=238, fs=1.2, rough=0.03, breath=0.3, vib=0.02, style="", syl=0.13),
    "julian": dict(f0=138, fs=1.02, rough=0.02, breath=0.05, vib=0.0, style="mono", syl=0.085),
    "shepherd": dict(f0=78, fs=0.86, rough=0.25, breath=0.1, vib=0.004, style="radio_dark", syl=0.14),
    "lucia": dict(f0=265, fs=1.27, rough=0.05, breath=0.15, vib=0.01, style="", syl=0.09),
    "tomas": dict(f0=310, fs=1.38, rough=0.05, breath=0.2, vib=0.008, style="", syl=0.085),
    "grady": dict(f0=84, fs=0.9, rough=0.6, breath=0.15, vib=0.005, style="", syl=0.12),
    "silas": dict(f0=150, fs=1.0, rough=0.3, breath=0.3, vib=0.03, style="slur", syl=0.14),
    "tom": dict(f0=112, fs=0.97, rough=0.35, breath=0.1, vib=0.006, style="", syl=0.12),
    "pa": dict(f0=190, fs=1.1, rough=0.05, breath=0.1, vib=0.0, style="pa", syl=0.11),
    "radio": dict(f0=150, fs=1.05, rough=0.05, breath=0.1, vib=0.0, style="radio", syl=0.095),
    "patient": dict(f0=170, fs=1.08, rough=0.3, breath=0.65, vib=0.03, style="", syl=0.15),
    "moth": dict(f0=208, fs=1.17, rough=0.05, breath=0.22, vib=0.012, style="radio", syl=0.1),  # Elena over the radio
    "marked": dict(f0=62, fs=0.8, rough=0.8, breath=0.3, vib=0.01, style="growl", syl=0.16),
    "boss": dict(f0=46, fs=0.72, rough=0.9, breath=0.2, vib=0.004, style="growl", syl=0.18),
}


def voice_clip(p, vowel, rng, dur=None, f0_mul=1.0, contour=0.0, rough=None, consonant=None):
    dur = dur or p["syl"] * rng.uniform(0.85, 1.25)
    n = secs(dur)
    rough = p["rough"] if rough is None else rough
    f0 = p["f0"] * f0_mul
    f = [f0 * (1 + contour * (i / n - 0.4) * 0.35) * (1 + p["vib"] * math.sin(TAU * 5.5 * i / SR)) for i in range(n)]
    if p["style"] == "mono":
        f = [f0 * (1 + 0.01 * math.sin(TAU * 4 * i / SR)) for i in range(n)]
    src, ph, amp_j = [], 0.0, 1.0
    for i in range(n):
        prev = ph
        ph += f[i] / SR * (1 + rng.uniform(-0.03, 0.03) * rough)
        if int(ph) != int(prev):
            amp_j = 1 - rough * 0.6 * rng.random()
        ph -= math.floor(ph)
        src.append((2 * ph - 1) * amp_j)
    src = lp(src, 5000)
    src = [s + p["breath"] * 0.5 * rng.uniform(-1, 1) for s in src]
    fm = VOWELS[vowel]
    y = zeros(n)
    for k, (fr, g, qq) in enumerate(zip(fm, (1.0, 0.6, 0.25), (7, 9, 11))):
        add(y, bp(src, min(fr * p["fs"] * rng.uniform(0.97, 1.03), SR * 0.45), qq), 0, g)
    if p["style"] == "growl":
        y = mul(y, [0.5 + 0.5 * math.sin(TAU * 38 * i / SR) for i in range(n)])
        y = mix(y, scale(osc("saw", [v * 0.5 for v in f], n), 0.25))
        y = sat(y, 2.5)
    e = [min(1.0, i / secs(0.012)) * min(1.0, (n - i) / secs(0.03)) * (0.75 + 0.25 * math.sin(math.pi * i / n)) for i in range(n)]
    y = mul(y, e)
    c = consonant
    if c:
        cn = secs(0.022)
        f_c = {"s": 6500, "k": 2200, "p": 900, "t": 4000}[c]
        burst = mul(hp(bp(noise(cn, rng), f_c, 1.5), 700), env_exp(cn, 0.007, 0.0005))
        y = mix(y, scale(burst, 2.0 * peak(y) / peak(burst)))
    y = scale(y, 1 / peak(y))
    style = p["style"]
    if style in ("radio", "radio_dark", "pa"):
        y = hp(lp(y, 3000), 400)
        y = sat(scale(y, 3.0), 1.5)
        hiss = scale(noise(n, rng), 0.08 if style != "pa" else 0.03)
        y = mix(y, hiss)
        if style == "radio_dark":
            y = mix(y, scale(mul(y, osc("sin", 55, n)), 0.7))  # ring-mod growl under the radio filter
        if style == "pa":
            y = mix(y, scale(osc("sin", 120, n), 0.04))
            y = echo(y + zeros(secs(0.2)), 0.07, 0.35)
    if style == "slur":
        y = lp(y, 1800)
    return y


def sfx_whisper(rng, syllables=7):
    """The Mark's whispers (Voice bus): unvoiced syllables, the voices' vowel formants on breath noise instead of a
    pitch, with s / t bursts; a slow swell, dark and roomy. Nothing in them is a word."""
    parts = []
    for _ in range(syllables):
        vowel = rng.choice("aeiou")
        n = secs(rng.uniform(0.09, 0.2))
        src = noise(n, rng)
        y = zeros(n)
        for fr, g, qq in zip(VOWELS[vowel], (1.0, 0.7, 0.35), (6, 8, 10)):
            add(y, bp(src, fr * rng.uniform(0.85, 1.05), qq), 0, g)
        y = mul(y, env_ar(n, 0.025, 0.06))
        if rng.random() < 0.45:
            cn = secs(0.05)
            hiss = mul(hp(noise(cn, rng), 3500), env_exp(cn, 0.02, 0.003))
            add(y, scale(hiss, 0.6 * peak(y) / peak(hiss)))  # the burst rides the syllable's onset
        parts.append(y + zeros(secs(rng.uniform(0.02, 0.12))))
    x = [v for p in parts for v in p]
    n = len(x)
    x = mul(x, [math.sin(math.pi * i / n) ** 0.7 for i in range(n)])  # swells in and out
    x = lp(x, 3200)
    return reverb(x + zeros(secs(0.6)), 0.35, 1.2, 1800.0)


def sfx_spotted(rng):
    """The "!" sting: a short bright metallic stab with a hiss under it."""
    n = secs(0.45)
    stab = mix(bell(hz(86), 0.45, 1.0, 2.76, 3.0, 0.08), scale(bell(hz(91), 0.45, 0.6, 3.1, 2.0, 0.06), 0.7))
    hiss = mul(hp(noise(n, rng), 2500), env_exp(n, 0.05, 0.002))
    return mix(stab, scale(hiss, 0.25))


def voice_set(name):
    p = PROFILES[name]
    rng = random.Random(sum(map(ord, name)))
    clips = []
    plan = [("a", "", 0.0), ("e", "k", 0.0), ("o", "", -0.4), ("i", "t", 0.5), ("u", "", 0.0), ("a", "s", -0.3),
            ("e", "", 0.3), ("o", "p", 0.0)]
    for i, (v, c, ct) in enumerate(plan):
        clips.append(voice_clip(p, v, rng, f0_mul=rng.uniform(0.92, 1.1), contour=ct, consonant=c or None))
    return clips


# ------------------------------------------------------------------ build

def build():
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    jobs = {}

    def job(name, fn, level=0.8):
        if only in name:
            jobs[name] = (fn, level)

    # music (-3 dB so they sit under sfx)
    for nm, fn in (("menu", music_menu), ("explore", music_explore), ("chase", music_chase), ("safe", music_safe),
                   ("melancholy", music_melancholy), ("boss", music_boss)):
        job("music_" + nm, fn, 0.7)
    for k in ("reveal", "dread", "boss"):
        job("sfx_stinger_" + k, lambda k=k: stinger(k), 0.9)

    R = lambda s: random.Random(s)
    for surf in ("concrete", "grass", "wood", "metal", "gravel"):
        for v in range(3):
            job("sfx_step_%s_%d" % (surf, v), lambda s=surf, v=v: sfx_step(s, v), 0.5)
    job("sfx_jump", lambda: sfx_jump(R(1)), 0.5)
    job("sfx_land", lambda: sfx_land(R(2)), 0.7)
    job("sfx_door_open", lambda: sfx_door_open(R(3)), 0.7)
    job("sfx_door_close", lambda: sfx_door_close(R(4)), 0.8)
    job("sfx_door_slam", lambda: sfx_door_slam(R(5)), 1.0)
    job("sfx_door_locked", lambda: sfx_door_locked(R(6)), 0.7)
    job("sfx_pickup", lambda: sfx_pickup(R(7)), 0.6)
    job("sfx_item_use", lambda: sfx_item_use(R(8)), 0.6)
    job("sfx_click", lambda: sfx_click(1400, 0.05), 0.5)
    job("sfx_move", lambda: sfx_click(900, 0.035, 0.7), 0.35)
    job("sfx_notify", lambda: sfx_notify(R(9)), 0.6)
    job("sfx_save", lambda: sfx_save(R(10)), 0.7)
    job("sfx_swing", lambda: sfx_swing(R(11)), 0.6)
    for v in range(2):
        job("sfx_melee_hit_%d" % v, lambda v=v: sfx_hit(R(20 + v), v == 1), 0.85)
    job("sfx_punch", lambda: sfx_hit(R(30)), 0.6)
    job("sfx_gun_revolver", lambda: sfx_gun(R(31), "revolver"), 1.0)
    job("sfx_gun_shotgun", lambda: sfx_gun(R(32), "shotgun"), 1.0)
    job("sfx_gun_flare", lambda: sfx_gun(R(33), "flare"), 0.8)
    job("sfx_dry", lambda: sfx_dry(R(34)), 0.6)
    job("sfx_reload", lambda: sfx_reload(R(35)), 0.7)
    job("sfx_bow", lambda: sfx_bow(R(36)), 0.7)
    job("sfx_arrow_hit", lambda: sfx_arrow_hit(R(37)), 0.7)
    for v in range(3):
        job("sfx_growl_%d" % v, lambda v=v: growl(R(40 + v), 1.0 + 0.2 * v, 70 + 18 * v, 24 + 6 * v, 0.2), 0.85)
    job("sfx_enemy_alert", lambda: sfx_enemy_alert(R(45)), 0.9)
    job("sfx_enemy_hit", lambda: sfx_hit(R(46), True), 0.8)
    job("sfx_enemy_death", lambda: sfx_death(R(47)), 0.9)
    for v in range(2):
        job("sfx_hurt_%d" % v, lambda v=v: sfx_hurt(R(50 + v), v), 0.8)
    job("sfx_heartbeat", sfx_heartbeat, 0.9)
    job("sfx_radio_static", lambda: sfx_static(R(60)), 0.5)
    job("sfx_radio_tune", lambda: sfx_tune(R(61)), 0.5)
    job("sfx_radio_lock", sfx_lock_beep, 0.6)
    job("sfx_bell", sfx_bell_toll, 0.9)
    for k, m in enumerate((72, 75, 79, 77)):
        job("sfx_musicbox_%d" % k, lambda m=m, k=k: musicbox(hz(m), 2.5, 1.0, R(70 + k)), 0.6)
    job("sfx_pick_set", lambda: sfx_pick_set(R(80)), 0.6)
    job("sfx_pick_snap", lambda: sfx_pick_snap(R(81)), 0.7)
    job("sfx_pick_open", lambda: sfx_pick_open(R(82)), 0.7)
    job("sfx_fish_cast", lambda: sfx_cast(R(83)), 0.6)
    job("sfx_fish_splash", lambda: sfx_splash(R(84)), 0.6)
    job("sfx_fish_reel", lambda: sfx_reel(R(85)), 0.5)
    job("sfx_generator", lambda: sfx_engine(R(86), 2.0, 48.0), 0.6)
    job("sfx_harvester", lambda: sfx_engine(R(87), 2.0, 34.0, True), 0.7)
    job("sfx_hiss", lambda: sfx_hiss(R(88)), 0.5)
    job("sfx_glass", lambda: sfx_glass(R(89)), 0.7)
    job("sfx_scrape", lambda: sfx_scrape(R(90)), 0.6)
    job("sfx_thud", lambda: sfx_ladder_thud(R(91)), 0.7)
    for v in range(4):  # the Mark (python3 tools/make_audio.py whisper)
        job("sfx_whisper_%d" % v, lambda v=v: sfx_whisper(R(100 + v), 5 + v), 0.6)
    job("sfx_spotted", lambda: sfx_spotted(R(110)), 0.7)  # the "!" (python3 tools/make_audio.py spotted)
    job("sfx_explosion", lambda: sfx_explosion(R(111)), 1.0)  # a fuel drum bursting (FuelBarrel)

    for ch in PROFILES:
        for i in range(8):
            job("voice_%s_%d" % (ch, i), lambda ch=ch, i=i: voice_set(ch)[i], 0.7)

    cache = {}
    for name in sorted(jobs):
        fn, level = jobs[name]
        if name.startswith("voice_"):  # build a character's whole set once
            ch = name.split("_")[1]
            if ch not in cache:
                cache[ch] = voice_set(ch)
            x = cache[ch][int(name.split("_")[2])]
        else:
            x = fn()
        write(name, x, level)
        print("wrote", name, "%.2fs" % (len(x) / SR), flush=True)


if __name__ == "__main__":
    build()
