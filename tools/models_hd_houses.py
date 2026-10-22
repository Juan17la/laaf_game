"""SA-era rebuilds of the town's core buildings: house_a/b/c, cabin, motel, diner, grady_store, bar.

Same names, footprints, doors, enterable room() shells and interior props as the old core versions in
build_assets.py (these overwrite them: packs run after core MODELS). Pack: MODELS only, no place().
Front = +Z. Collision lives in "*-col" nodes; all dressing sits in "detail" (no collision).
"""
import math
import random

import build_assets as B
import interior_kit as K

mix, mul = B.mix, B.mul


# ============================================================== textures

def _h(*k):
    """Stable hash -> 0..1 (per shingle tab, per board...)."""
    n = 2166136261
    for v in k:
        n = ((n ^ (v & 0xffff)) * 16777619) & 0xffffffff
    return (n >> 8) % 1000 / 1000


def t_shingle(x, y, a, b, r):
    row = y // 8
    off = 8 if row % 2 else 0
    col = (x + off) // 16
    hv = _h(row, col)
    c = mul((0.25, 0.23, 0.22), (0.55 + 0.55 * a + 0.08 * r) * (0.8 + 0.4 * hv))
    if hv < 0.07:
        c = mul((0.07, 0.06, 0.05), 0.8 + 0.4 * a)  # missing tab: tar paper
    elif b > 0.62:
        c = mix(c, mul((0.13, 0.17, 0.08), 0.7 + 0.5 * a), min(1.0, (b - 0.62) * 5))  # moss
    k = y % 8
    if k == 7 or ((x + off) % 16 == 0 and k > 1):
        return mul(c, 0.3)
    return mul(c, 0.75 + 0.04 * k)


def t_clap(x, y, a, b, r):
    k = y % 8
    c = mul((0.74, 0.72, 0.66), 0.62 + 0.3 * a + 0.03 * r)
    if b > 0.7 or (b > 0.64 and _h(x // 4, y // 8) > 0.7):
        c = mul((0.32, 0.29, 0.25), 0.6 + 0.4 * a)  # peeled to grey wood
    if _h(x // 2, 3) > 0.86:
        c = mul(c, 0.72 + 0.2 * a)  # rain streak
    c = mul(c, 0.72 + 0.045 * k)
    return mul(c, 0.4) if k == 0 else c


def t_trim(x, y, a, b, r):
    c = mul((0.72, 0.7, 0.64), 0.66 + 0.3 * a + 0.03 * r)
    if b > 0.74:
        c = mix(c, (0.3, 0.27, 0.22), 0.8)
    return c


def t_block(x, y, a, b, r):
    off = 8 if (y // 8) % 2 else 0
    if y % 8 == 0 or (x + off) % 16 == 0:
        return mul((0.22, 0.21, 0.2), 0.8 + 0.3 * a)
    v = 0.36 + 0.22 * a + 0.05 * r - (0.1 if b > 0.6 else 0)
    return (v, v * 0.98, v * 0.93)


def t_stucco(x, y, a, b, r):
    c = mul((0.72, 0.72, 0.68), 0.62 + 0.3 * a + 0.06 * r)
    if b > 0.72:
        return t_block(x, y, a, b, r)
    if abs(math.sin(x * 0.21 + a * 9) * 20 - (y - 32)) < 0.8 and b > 0.45:
        c = mul(c, 0.5)  # crack
    return mul(c, 0.85 + 0.15 * (1 - b))


def _dirty_edge(c, x, y, s=64, k=6, dirt=(0.16, 0.14, 0.11)):
    e = min(x, y, s - 1 - x, s - 1 - y)
    return mix(c, dirt, 0.6 * (1 - e / k)) if e < k else c


def t_glass(x, y, a, b, r):
    c = mul((0.06, 0.075, 0.09), 0.7 + 0.6 * a)
    d = (x + y * 0.6) % 64
    if 16 < d < 25 or 29 < d < 31:
        c = mix(c, (0.34, 0.38, 0.42), 0.3)
    if b > 0.62:
        c = mix(c, (0.2, 0.18, 0.14), 0.5)
    return _dirty_edge(c, x, y)


def _lit(x, y, a, b, r, glow=(1.0, 0.7, 0.36)):
    c = mul(glow, 0.55 + 0.5 * a)
    fold = 0.6 + 0.4 * math.sin(x * 1.3)
    if x < 13 + 3 * math.sin(y * 0.2) or x > 51 + 3 * math.sin(y * 0.25 + 1):
        c = mul((0.55, 0.22, 0.12), fold * (0.6 + 0.4 * a))  # curtains
    if y < 6:
        c = mul((0.4, 0.16, 0.1), 0.6 + 0.4 * a)  # valance
    return _dirty_edge(c, x, y, k=4)


def t_glass_lit(x, y, a, b, r):
    return _lit(x, y, a, b, r)


def t_glass_fig(x, y, a, b, r):
    """Lit window with somebody standing behind the curtain."""
    c = _lit(x, y, a, b, r, (1.0, 0.62, 0.3))
    head = (x - 32) ** 2 + ((y - 22) * 0.8) ** 2 < 49
    body = y > 28 and abs(x - 32) < 7 + (y - 28) * 0.55
    return mul(c, 0.12) if head or body else c


def t_glass_broken(x, y, a, b, r):
    c = t_glass(x, y, a, b, r)
    dx, dy = x - 38, y - 26
    ang = math.atan2(dy, dx)
    rad = 13 + 6 * math.sin(ang * 5 + 1) + 4 * math.sin(ang * 11)
    d = math.hypot(dx, dy)
    if d < rad:
        return (0.01, 0.01, 0.012)
    if d < rad + 26 and abs(math.sin(ang * 4.5)) < 0.06 + 0.02 * a:
        return (0.5, 0.52, 0.55)  # cracks
    return c


def t_shop_lit(x, y, a, b, r):
    """Store window: lit shelves of cans and a faded poster."""
    c = mul((0.95, 0.78, 0.45), 0.5 + 0.4 * a)
    if 6 < x < 22 and 6 < y < 28:
        c = mul((0.7, 0.2, 0.15) if y < 16 else (0.8, 0.75, 0.6), 0.5 + 0.4 * a)  # poster
    elif y % 16 in (14, 15):
        c = (0.12, 0.08, 0.05)
    elif y % 16 > 6:
        k = _h(x // 4, y // 16)
        c = mul([(0.6, 0.12, 0.1), (0.2, 0.3, 0.55), (0.75, 0.65, 0.25), (0.3, 0.5, 0.25)][int(k * 4)], 0.45 + 0.4 * a)
    return _dirty_edge(c, x, y, k=8, dirt=(0.25, 0.2, 0.12))


def t_mesh(x, y, a, b, r):
    torn = (x - 44) ** 2 / 90 + (y - 18) ** 2 / 260 < 1 + a * 0.5
    on = (x % 2 == 0 or y % 2 == 0) and not torn
    return (0.1, 0.1, 0.1, 1.0 if on else 0.0)


def t_tin(x, y, a, b, r):
    v = 0.5 + 0.5 * math.sin(x * 2 * math.pi / 8)
    c = mul((0.46, 0.46, 0.47), 0.5 + 0.35 * v + 0.2 * a)
    if b > 0.52:
        c = mix(c, mul((0.36, 0.17, 0.08), 0.6 + 0.4 * v), min(1.0, (b - 0.52) * 4))
    if x % 32 == 0:
        c = mul(c, 0.5)
    return c


def t_log(x, y, a, b, r):
    g = 0.5 + 0.5 * math.sin(y * 1.1 + a * 10)
    c = mul((0.3, 0.25, 0.19), 0.6 + 0.25 * g + 0.25 * a)
    if abs(math.sin(y * 0.45 + a * 14)) < 0.05:
        c = (0.06, 0.05, 0.04)
    return mix(c, (0.33, 0.33, 0.31), 0.35 * b)  # silvered


def t_rib(x, y, a, b, r):
    k = x % 6
    c = mul((0.56, 0.57, 0.6), 0.65 + 0.35 * a + (0.25 if k < 2 else -0.2 if k == 5 else 0))
    return mix(c, (0.22, 0.15, 0.09), 0.6 * max(0.0, (b - 0.55) * 2.5))


def t_chrome(x, y, a, b, r):
    c = mul((0.72, 0.74, 0.78), 0.45 + 0.35 * (0.5 + 0.5 * math.sin(y * 0.5 + a * 3)) + 0.25 * a)
    return mix(c, (0.3, 0.2, 0.12), 0.7) if b > 0.7 else c


def t_enamel(x, y, a, b, r):
    c = mul((0.82, 0.8, 0.74), 0.72 + 0.26 * a + 0.03 * r)
    if b > 0.76 and r > 0.3:
        c = mul((0.2, 0.19, 0.18), 0.7 + 0.4 * a)  # chipped to metal
    return mul(c, 0.8 + 0.2 * (1 - b))


def t_sign(x, y, a, b, r):
    c = mul((0.7, 0.68, 0.62), 0.6 + 0.3 * a)
    e = min(x, y, 63 - x, 63 - y)
    if 2 < e < 6:
        c = mul((0.85, 0.8, 0.65), 0.7 + 0.3 * a)
    return mix(c, (0.15, 0.12, 0.1), 0.5 * max(0.0, (b - 0.5) * 2))


def t_grille(x, y, a, b, r):
    c = mul((0.5, 0.5, 0.48), 0.6 + 0.4 * a)
    if y % 4 == 0:
        c = mul(c, 0.25)
    return mix(c, (0.3, 0.18, 0.1), 0.6) if b > 0.66 else c


def t_louver(x, y, a, b, r):
    k = y % 6
    c = mul((0.8, 0.8, 0.78), (0.62 + 0.3 * a) * (0.55 + 0.1 * k))
    return mix(c, (0.25, 0.22, 0.18), 0.6) if b > 0.66 else c


def t_ply(x, y, a, b, r):
    g = 0.5 + 0.5 * math.sin(x * 0.35 + a * 12)
    c = mul((0.5, 0.4, 0.28), 0.6 + 0.2 * g + 0.2 * a)
    c = mix(c, (0.3, 0.3, 0.29), 0.5 * b)
    if min(abs(x - y), abs(63 - x - y)) < 3 + 2 * a and 6 < x < 58:
        c = mul((0.4, 0.05, 0.04), 0.7 + 0.3 * a)  # spray-painted X
    return c


def t_vend(x, y, a, b, r):
    if 6 < x < 40 and 6 < y < 50:
        return mul((0.95, 0.9, 0.75), 0.5 + 0.5 * a) if (y // 8) % 2 else mul((0.8, 0.2, 0.15), 0.6 + 0.4 * a)
    if 46 < x < 58 and 20 < y < 34:
        return (0.1, 0.1, 0.1)
    return mul((0.55, 0.08, 0.07), 0.6 + 0.4 * a)


FONT = {
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
    "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "I": "111010010010111",
    "C": "111100100100111", "E": "111100110100111", "O": "111101101101111", "F": "111100110100100",
    "A": "010101111101101", "T": "111010010010010", "B": "110101110101110", "R": "110101110101101",
    "P": "110101110100100", "N": "101111111101101", "L": "100100100100111", "D": "110101101101110",
    "S": "111100111001111", "G": "111100101101111", "Y": "101101010010010", " ": "000000000000000",
}
TEXT_COLS = {}


def text_tex(name, text, fg, bg, size=64):
    cols, rows = 4 * len(text) + 1, 7
    TEXT_COLS[name] = cols / rows

    def fn(x, y, a, b, r):
        u, v = x * cols // size, y * rows // size
        ch, cx, cy = (u - 1) // 4, (u - 1) % 4, v - 1
        on = 0 <= ch < len(text) and cx < 3 and 0 <= cy < 5 and FONT[text[ch]][cy * 3 + cx] == "1"
        return mul(fg if on else bg, 0.75 + 0.35 * a)
    B.TEXTURES[name] = fn
    if size != 64:
        B.TEX_SIZE[name] = size


B.TEXTURES.update({
    "hh_shingle": t_shingle, "hh_clap": t_clap, "hh_trim": t_trim, "hh_block": t_block, "hh_stucco": t_stucco,
    "hh_glass": t_glass, "hh_glass_lit": t_glass_lit, "hh_glass_fig": t_glass_fig, "hh_glass_broken": t_glass_broken,
    "hh_shop_lit": t_shop_lit, "hh_mesh": t_mesh, "hh_tin": t_tin, "hh_log": t_log, "hh_rib": t_rib,
    "hh_chrome": t_chrome, "hh_enamel": t_enamel, "hh_sign": t_sign, "hh_grille": t_grille, "hh_louver": t_louver,
    "hh_ply": t_ply, "hh_vend": t_vend,
})
B.ALPHA_TEX.add("hh_mesh")
BRASS, CREAM = (0.75, 0.6, 0.3), (0.85, 0.8, 0.65)
for _i in range(1, 7):
    text_tex("hh_tx_%d" % _i, str(_i), (0.1, 0.08, 0.05), BRASS)
text_tex("hh_tx_ice", "ICE", (0.15, 0.35, 0.75), CREAM)
text_tex("hh_tx_office", "OFFICE", (0.9, 0.85, 0.7), (0.08, 0.1, 0.12), 128)
text_tex("hh_tx_eat", "EAT", (1.0, 0.3, 0.2), (0.05, 0.03, 0.03))
text_tex("hh_tx_beer", "BEER", (1.0, 0.25, 0.15), (0.02, 0.02, 0.02))
text_tex("hh_tx_open", "OPEN", (0.25, 0.1, 0.1), (0.02, 0.02, 0.02))
text_tex("hh_tx_grady", "GRADYS FEED", (0.62, 0.55, 0.45), (0.36, 0.17, 0.12), 128)

B.MATS.update({
    "hh_shingle": B.M("hh_shingle", scale=1.6), "hh_shingle_red": B.M("hh_shingle", (1.0, 0.72, 0.62), 1.6),
    "hh_clap_white": B.M("hh_clap", scale=1.6), "hh_clap_blue": B.M("hh_clap", (0.66, 0.78, 0.92), 1.6),
    "hh_clap_green": B.M("hh_clap", (0.5, 0.68, 0.52), 1.6), "hh_trim": B.M("hh_trim", scale=1.0),
    "hh_trim_dark": B.M("hh_trim", (0.3, 0.36, 0.3), 1.0), "hh_block": B.M("hh_block", scale=1.6),
    "hh_stucco": B.M("hh_stucco", (0.62, 0.82, 0.84), 2.0), "hh_stucco_cream": B.M("hh_stucco", (1.0, 0.92, 0.75), 2.0),
    "hh_glass": B.M("hh_glass", fit=True, rough=0.25), "hh_glass_broken": B.M("hh_glass_broken", fit=True, rough=0.25),
    "hh_glass_lit": B.M("hh_glass_lit", fit=True, emit=1.6), "hh_glass_fig": B.M("hh_glass_fig", fit=True, emit=1.6),
    "hh_shop_lit": B.M("hh_shop_lit", fit=True, emit=1.3), "hh_mesh": B.M("hh_mesh", scale=0.5),
    "hh_tin": B.M("hh_tin", scale=1.2), "hh_log": B.M("hh_log", scale=1.5), "hh_rib": B.M("hh_rib", scale=0.8),
    "hh_chrome": B.M("hh_chrome", scale=1.0, rough=0.3), "hh_enamel_cream": B.M("hh_enamel", (1.0, 0.95, 0.8), 2.0),
    "hh_enamel_red": B.M("hh_enamel", (0.62, 0.13, 0.1), 2.0), "hh_enamel_teal": B.M("hh_enamel", (0.35, 0.6, 0.58), 2.0),
    "hh_door_motel": B.M("hh_enamel", (0.5, 0.2, 0.14), 2.0), "hh_sign_green": B.M("hh_sign", (0.3, 0.42, 0.3), fit=True),
    "hh_sign_red": B.M("hh_sign", (0.55, 0.16, 0.12), fit=True), "hh_sign_cream": B.M("hh_sign", (1.0, 0.95, 0.85), fit=True),
    "hh_grille": B.M("hh_grille", scale=0.6), "hh_louver": B.M("hh_louver", scale=0.6), "hh_ply": B.M("hh_ply", fit=True),
    "hh_shutter": B.M("hh_louver", (0.28, 0.36, 0.3), 0.6), "hh_shutter_red": B.M("hh_louver", (0.45, 0.18, 0.14), 0.6),
    "hh_gutter": B.M("metal", (0.8, 0.8, 0.78), 1.0), "hh_clay": B.M("plain", (0.42, 0.22, 0.14), 1),
    "hh_brass": B.M("plain", (0.45, 0.36, 0.18), 1, rough=0.4), "hh_copper": B.M("plain", (0.4, 0.22, 0.12), 1),
    "hh_dish": B.M("plain", (0.6, 0.6, 0.58), 1), "hh_vend": B.M("hh_vend", fit=True, emit=0.9),
})
for _k in list(B.TEXTURES):
    if _k.startswith("hh_tx_"):
        glow = {"hh_tx_eat": 2.5, "hh_tx_beer": 2.5}.get(_k, 0.0)
        B.MATS[_k] = B.M(_k, fit=True, emit=glow)


# ============================================================== helpers

def beam(m, mat, p0, p1, w, h=None, r=None, seg=6):
    """Box (w x h cross-section) or cylinder (radius r) between two points."""
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    L = math.sqrt(dx * dx + dy * dy + dz * dz)
    e = math.degrees(math.atan2(dy, math.hypot(dx, dz)))
    yaw = math.degrees(math.atan2(dx, dz))
    if r:
        m.cyl(mat, r, r, L, p0, (90 - e, yaw, 0), seg=seg, caps=False)
    else:
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
        m.box(mat, (w, h or w, L), mid, (-e, yaw, 0))


def window(m, pos, yaw, w, h, glass="hh_glass", kind="", shutter=None, grid=(2, 2), trim="hh_trim", d=0.07,
           droop=False):
    """Framed window on a wall surface; local +Z = out of the wall. glass=None for through-wall glass boxes."""
    with m.push(pos, (0, yaw, 0)):
        if glass:
            m.decal(glass, w, h, (0, 0, 0.006))
        m.box(trim, (w + 0.28, 0.12, d), (0, h / 2 + 0.06, d / 2))
        m.box(trim, (w + 0.38, 0.05, d + 0.04), (0, h / 2 + 0.145, d / 2 + 0.01))
        for s in (-1, 1):
            m.box(trim, (0.1, h, d), (s * (w / 2 + 0.05), 0, d / 2))
        m.box(trim, (w + 0.36, 0.06, d + 0.12), (0, -h / 2 - 0.03, (d + 0.12) / 2))
        m.box(trim, (w + 0.08, 0.12, 0.03), (0, -h / 2 - 0.12, 0.015))
        nx, ny = grid
        for i in range(1, nx):
            m.box(trim, (0.035, h, 0.04), (-w / 2 + w * i / nx, 0, 0.02))
        for j in range(1, ny):
            m.box(trim, (w, 0.05, 0.045), (0, -h / 2 + h * j / ny, 0.022))
        if kind == "boarded":
            for k, (y, a) in enumerate(((0.3, 8), (0.0, -5), (-0.28, 12))):
                m.box("planks", (w + 0.3, 0.2, 0.03), (0, y * h, d + 0.02 + k * 0.01), (0, 0, a))
        elif kind == "ply":
            m.decal("hh_ply", w + 0.12, h + 0.1, (0, 0, d + 0.01))
        if shutter:
            for s in (-1, 1):
                sw = w * 0.48
                if droop and s > 0:
                    m.box(shutter, (sw, h, 0.04), (s * (w / 2 + 0.14 + sw / 2) + 0.06, -0.12, 0.03), (0, 0, -14))
                else:
                    m.box(shutter, (sw, h, 0.04), (s * (w / 2 + 0.14 + sw / 2), 0, 0.03))


def sconce(m, pos, lit=True):
    """Porch/wall lantern at pos (local +Z = out of wall)."""
    x, y, z = pos
    m.box("iron", (0.13, 0.26, 0.03), (x, y, z + 0.015))
    m.box("iron", (0.03, 0.03, 0.12), (x, y + 0.02, z + 0.08))
    m.box("iron", (0.17, 0.03, 0.17), (x, y - 0.11, z + 0.15))
    m.box("bulb" if lit else "glass", (0.12, 0.18, 0.12), (x, y, z + 0.15))
    m.tbox("iron", (0.2, 0.2), (0.04, 0.04), 0.09, (x, y + 0.09, z + 0.15))


def door(m, pos, yaw, w=1.0, h=2.1, mat="door", leaf=True, screen=0, lamp=None, trim="hh_trim", knob=True):
    """Door casing on a wall surface. leaf=False when room() already cut the opening (and hung the leaf).
    screen: open angle of a screen door (0 = none). lamp: None / True (lit) / False (dead bulb)."""
    with m.push(pos, (0, yaw, 0)):
        if leaf:
            m.box(mat, (w, h, 0.05), (0, h / 2, 0.0))
            if knob:
                m.cyl("hh_brass", 0.035, 0.035, 0.07, (w / 2 - 0.12, 1.0, 0.02), (90, 0, 0), seg=6)
        for s in (-1, 1):
            m.box(trim, (0.12, h + 0.1, 0.08), (s * (w / 2 + 0.06), (h + 0.1) / 2, 0.04))
        m.box(trim, (w + 0.4, 0.16, 0.1), (0, h + 0.13, 0.05))
        m.box(trim, (w + 0.5, 0.05, 0.14), (0, h + 0.235, 0.07))
        if screen:
            with m.push((-w / 2, 0, 0.1), (0, -screen, 0)):
                for x in (0.03, w - 0.03):
                    m.box(trim, (0.06, h - 0.02, 0.04), (x, h / 2, 0))
                for y in (0.1, 1.0, h - 0.06):
                    m.box(trim, (w, 0.08, 0.04), (w / 2, y, 0))
                m.decal("hh_mesh", w - 0.08, h - 0.2, (w / 2, h / 2 + 0.03, 0))
        if lamp is not None:
            sconce(m, (w / 2 + 0.38, h - 0.1, 0), lamp)


def gable_roof(m, W, D, H, ph, over=0.45, side=0.35, mat="hh_shingle", end="hh_clap_white", trim="hh_trim",
               pipes=(), gutters=True, broken_gutter=False):
    """Pitched roof, ridge along X, walls top at H. Returns eave height."""
    t = ph / (D / 2)
    a = math.degrees(math.atan(t))
    s0 = D / 2 + over
    L = s0 / math.cos(math.atan(t))
    Wr, T = W + 2 * side, 0.1
    faces = {"-y": trim, "+x": trim, "-x": trim, "+z": trim, "-z": trim}
    for s in (1, -1):
        with m.push((0, H + ph - s0 / 2 * t, s * s0 / 2), (s * a, 0, 0)):
            m.box(mat, (Wr, T, L), (0, T / 2, 0), faces=faces)
            for sx in (-1, 1):  # rake boards
                m.box(trim, (0.06, 0.26, L + 0.03), (sx * (Wr / 2 + 0.03), T / 2 - 0.05, 0))
    for sx in (-1, 1):
        x = sx * W / 2
        m.emit(end, [(x, H, -D / 2), (x, H, D / 2), (x, H + ph, 0)], (0, H + ph / 3, 0))
    yr = H + ph + T / math.cos(math.atan(t))
    m.box(mat, (Wr + 0.06, 0.2, 0.2), (0, yr - 0.1, 0), (45, 0, 0))  # ridge cap
    ye = H - over * t
    for s in (1, -1):
        m.box(trim, (Wr, 0.22, 0.05), (0, ye + 0.02, s * (s0 + 0.03)))
        if gutters:
            gz = s * (s0 + 0.12)
            if broken_gutter and s > 0:  # one length has come down and hangs off its end
                m.cyl("hh_gutter", 0.08, 0.08, Wr * 0.55, (-Wr / 2, ye - 0.05, gz), (0, 0, -90), seg=6)
                beam(m, "hh_gutter", (-Wr / 2 + Wr * 0.55, ye - 0.05, gz), (Wr * 0.35, ye - 1.6, gz + 0.2), 0, r=0.08)
            else:
                m.cyl("hh_gutter", 0.08, 0.08, Wr, (-Wr / 2, ye - 0.05, gz), (0, 0, -90), seg=6)
    for px, s, y1 in pipes:
        downpipe(m, px, s * (s0 + 0.12), s * (D / 2 + 0.08), ye - 0.05, y1)
    return ye


def downpipe(m, x, zg, zw, ytop, ybot=0.15):
    """Downpipe from a gutter at zg bending back to the wall at zw, then down to ybot (a gap = broken pipe)."""
    beam(m, "hh_gutter", (x, ytop, zg), (x, ytop - 0.35, zw), 0, r=0.05)
    m.cyl("hh_gutter", 0.05, 0.05, ytop - 0.35 - ybot, (x, ybot, zw), seg=6, caps=False)
    for y in (ybot + 0.4, (ytop + ybot) / 2):
        m.box("hh_gutter", (0.14, 0.03, 0.1), (x, y, zw - math.copysign(0.03, zw)))
    if ybot < 0.5:
        beam(m, "hh_gutter", (x, ybot, zw), (x, 0.03, zw + math.copysign(0.35, zw)), 0, r=0.05)


def chimney(m, x, z, y0, y1, w=0.8, d=0.8, mat="brick", pot=True):
    m.box(mat, (w, y1 - y0, d), (x, (y0 + y1) / 2, z))
    m.box(mat, (w + 0.14, 0.14, d + 0.14), (x, y1 - 0.3, z))
    m.box("concrete", (w + 0.1, 0.08, d + 0.1), (x, y1 + 0.04, z))
    if pot:
        m.cyl("hh_clay", 0.12, 0.1, 0.4, (x + w * 0.2, y1 + 0.08, z), seg=8)
        m.cyl("hh_clay", 0.1, 0.09, 0.3, (x - w * 0.2, y1 + 0.08, z), seg=8)


def ac_unit(m, pos, yaw, line_to=None):
    """Ground condenser on a pad; line_to=(x, y, z) runs the copper line into the wall."""
    with m.push(pos, (0, yaw, 0)):
        m.box("concrete", (1.0, 0.08, 1.0), (0, 0.04, 0))
        m.box("hh_grille", (0.8, 0.7, 0.8), (0, 0.43, 0), faces={"+y": "metal"})
        m.cyl("iron", 0.3, 0.3, 0.03, (0, 0.78, 0), seg=10)
        m.box("metal", (0.25, 0.18, 0.04), (0.2, 0.55, 0.42))
    if line_to:
        beam(m, "hh_copper", (pos[0], 0.3, pos[2]), line_to, 0, r=0.025, seg=4)


def window_ac(m, pos, yaw):
    with m.push(pos, (0, yaw, 0)):
        m.box("hh_grille", (0.62, 0.4, 0.55), (0, 0, 0.18), faces={"+y": "metal", "-y": "metal"})
        m.box("metal", (0.66, 0.44, 0.06), (0, 0, 0.45))
        m.box("hh_louver", (0.5, 0.3, 0.02), (0, 0, 0.485))
        beam(m, "iron", (0, -0.2, 0.35), (0, -0.55, 0.0), 0.03)


def sat_dish(m, pos, yaw):
    with m.push(pos, (0, yaw, 0)):
        m.box("metal", (0.2, 0.3, 0.03), (0, 0, 0.015))
        beam(m, "metal", (0, 0, 0.02), (0, 0.15, 0.4), 0.05)
        with m.push((0, 0.2, 0.45), (65, 0, 0)):
            prof = [(0.02, -0.01), (0.2, 0.012), (0.34, 0.05), (0.42, 0.09)]
            m.lathe("hh_dish", prof, seg=10)
            rows = [[(r * math.cos(-2 * math.pi * j / 10), y + 0.012, r * math.sin(-2 * math.pi * j / 10))
                     for j in range(10)] for r, y in prof]
            m.surface("hh_dish", rows[::-1], wrap=True)
            beam(m, "metal", (0, -0.02, -0.4), (0, 0.38, -0.05), 0.025)
            m.box("iron", (0.07, 0.1, 0.07), (0, 0.4, 0))


def mailbox(m, pos, yaw, flag=True):
    with m.push(pos, (0, yaw, 0)):
        m.box("planks", (0.1, 1.05, 0.1), (0, 0.52, 0))
        m.box("planks", (0.22, 0.05, 0.5), (0, 1.07, 0))
        m.loft("metal", [(-0.25, 0.12, 0.12), (-0.24, 0.13, 0.13), (0.24, 0.13, 0.13), (0.25, 0.12, 0.12)],
               (0, 1.21, 0), (90, 0, 0), seg=10, power=3)
        if flag:
            m.box("red", (0.02, 0.2, 0.05), (0.14, 1.3, -0.1), (0, 0, -60))


def post(m, x, z, y0, y1, mat="hh_trim", s=0.13):
    m.box(mat, (s + 0.08, 0.2, s + 0.08), (x, y0 + 0.1, z))
    m.box(mat, (s, y1 - y0 - 0.35, s), (x, (y0 + y1 - 0.15) / 2 + 0.1, z))
    m.box(mat, (s + 0.06, 0.08, s + 0.06), (x, y1 - 0.2, z))
    m.box(mat, (s + 0.12, 0.12, s + 0.12), (x, y1 - 0.06, z))


def railing(m, p0, p1, y0, rng, mat="hh_trim", hgt=0.85, gap=0.24):
    x0, z0 = p0
    x1, z1 = p1
    beam(m, mat, (x0, y0 + hgt, z0), (x1, y0 + hgt, z1), 0.1, 0.05)
    beam(m, mat, (x0, y0 + 0.1, z0), (x1, y0 + 0.1, z1), 0.07, 0.05)
    n = max(1, int(math.hypot(x1 - x0, z1 - z0) / gap))
    yaw = math.degrees(math.atan2(x1 - x0, z1 - z0))
    for i in range(n):
        k = rng.random()
        if k < 0.08:
            continue  # kicked out
        f = (i + 0.5) / n
        m.box(mat, (0.045, hgt - 0.12, 0.045), (x0 + (x1 - x0) * f, y0 + hgt / 2 + 0.03, z0 + (z1 - z0) * f),
              (0, yaw, 14 if k > 0.93 else 0))


def attic_vent(m, pos, yaw, w=0.6, h=0.5):
    with m.push(pos, (0, yaw, 0)):
        m.box("hh_louver", (w, h, 0.05), (0, 0, 0.03), faces={"+z": "hh_louver"})
        m.box("hh_trim", (w + 0.16, 0.08, 0.08), (0, h / 2 + 0.04, 0.04))
        m.box("hh_trim", (w + 0.16, 0.08, 0.1), (0, -h / 2 - 0.04, 0.05))


def trim_skin(m, W, D, y0, y1, trim="hh_trim", corners=True, bands=True):
    """Corner boards + skirt/frieze boards around a W x D wall box."""
    if corners:
        for sx in (-1, 1):
            for sz in (-1, 1):
                m.box(trim, (0.16, y1 - y0, 0.16), (sx * W / 2, (y0 + y1) / 2, sz * D / 2))
    if bands:
        for y, hh in ((y0 + 0.08, 0.16), (y1 - 0.12, 0.24)):
            m.box(trim, (W + 0.08, hh, 0.05), (0, y, D / 2 + 0.025))
            m.box(trim, (W + 0.08, hh, 0.05), (0, y, -D / 2 - 0.025))
            m.box(trim, (0.05, hh, D + 0.08), (W / 2 + 0.025, y, 0))
            m.box(trim, (0.05, hh, D + 0.08), (-W / 2 - 0.025, y, 0))


def sign_text(m, mat, h, pos, rot=(0, 0, 0)):
    m.decal(mat, h * TEXT_COLS[mat], h, pos, rot)


# ============================================================== houses (not enterable: solid shells)

W_, D_ = 9, 7


def m_house_a():
    """Single-storey clapboard, gable roof, full-width front porch, exterior brick chimney."""
    m = B.Model("house_a")
    rng = random.Random(11)
    F, H, ph, sid = 0.5, 3.4, 2.0, "hh_clap_white"
    m.node("shell-col")
    m.box("hh_block", (W_ + 0.1, F, D_ + 0.1), (0, F / 2, 0))
    m.box(sid, (W_, H - F, D_), (0, (F + H) / 2, 0))
    m.box("planks", (7.4, F - 0.05, 1.5), (0, (F - 0.05) / 2, D_ / 2 + 0.75), faces={"+z": "hh_trim_dark", "-x": "hh_trim_dark", "+x": "hh_trim_dark"})
    m.box("planks", (1.6, 0.3, 0.25), (0, 0.15, 5.125))
    m.box("planks", (1.6, 0.15, 0.25), (0, 0.075, 5.375))
    m.box("brick", (1.4, 2.4, 0.9), (-W_ / 2 - 0.45, 1.2, 0))
    m.node("detail")
    trim_skin(m, W_, D_, F, H)
    ye = gable_roof(m, W_, D_, H, ph, end=sid, pipes=((W_ / 2 + 0.2, -1, 0.15),), broken_gutter=True)
    m.tbox("brick", (1.4, 0.9), (0.8, 0.6), 0.6, (-W_ / 2 - 0.45, 2.4, 0))
    chimney(m, -W_ / 2 - 0.35, 0, 3.0, H + ph + 0.8, 0.8, 0.6)
    # porch: posts, rails, shed roof
    pz, yd = 4.85, F - 0.05
    xs = (-3.55, -0.85, 0.85, 3.55)
    for x in xs:
        post(m, x, pz, yd, 2.85)
    railing(m, (-3.55, pz), (-0.85, pz), yd, rng)
    railing(m, (0.85, pz), (3.55, pz), yd, rng)
    for x in (-3.55, 3.55):
        railing(m, (x, D_ / 2 + 0.05), (x, pz), yd, rng)
    for x in (-0.85, 0.85):  # stair rails
        beam(m, "hh_trim", (x, yd + 0.85, pz), (x, 0.85, 5.5), 0.06, 0.05)
    beam(m, "hh_trim", (-3.7, 2.8, pz), (3.7, 2.8, pz), 0.14, 0.2)
    pr = math.degrees(math.atan2(0.4, 1.85))
    with m.push((0, 2.9 + 0.2, D_ / 2 + 0.92), (pr, 0, 0)):
        m.box("hh_shingle", (7.8, 0.08, 1.95), faces={"-y": "hh_trim", "+z": "hh_trim", "-z": "hh_trim",
                                                      "+x": "hh_trim", "-x": "hh_trim"})
    m.box("hh_trim", (7.8, 0.18, 0.05), (0, 2.9, 5.39))
    m.cyl("hh_gutter", 0.07, 0.07, 7.8, (-3.9, 2.85, 5.5), (0, 0, -90), seg=6)
    downpipe(m, 3.8, 5.5, 5.2, 2.85, 0.15)
    # front: door with screen, flanking windows with shutters
    door(m, (0, F, D_ / 2), 0, screen=35, lamp=True)
    window(m, (-2.4, F + 1.45, D_ / 2), 0, 1.1, 1.35, "hh_glass", shutter="hh_shutter", droop=True)
    window(m, (2.4, F + 1.45, D_ / 2), 0, 1.1, 1.35, "hh_glass_lit", shutter="hh_shutter")
    for z, g, k in ((-1.5, "hh_glass", "boarded"), (1.6, "hh_glass_broken", "")):
        window(m, (W_ / 2, F + 1.45, z), 90, 0.95, 1.3, g, k)
    for z in (-2.1, 2.1):
        window(m, (-W_ / 2, F + 1.45, z), -90, 0.9, 1.3, "hh_glass")
    window(m, (-2.6, F + 1.6, -D_ / 2), 180, 0.9, 0.9, "hh_glass")
    window(m, (2.4, F + 1.45, -D_ / 2), 180, 1.1, 1.3, "hh_glass", "ply")
    door(m, (-0.6, F, -D_ / 2), 180, lamp=False)
    m.box("concrete", (1.4, F, 0.9), (-0.6, F / 2, -D_ / 2 - 0.45))
    for sx in (-1, 1):
        attic_vent(m, (sx * W_ / 2, H + 0.95, 0), sx * 90, 0.5, 0.45)
    ac_unit(m, (3.4, 0, -D_ / 2 - 0.8), 10, (3.4, 0.9, -D_ / 2))
    mailbox(m, (4.3, 0, 5.25), 0)
    B.chair(m, -2.6, 4.3, 160)
    # TV antenna on the ridge
    m.cyl("metal", 0.03, 0.03, 1.6, (2.5, H + ph, 0), seg=4)
    for y, w in ((1.2, 1.2), (1.45, 0.9), (1.6, 0.6)):
        m.cyl("metal", 0.015, 0.015, w, (2.5 - w / 2, H + ph + y, 0), (0, 0, -90), seg=3, caps=False)
    return m


def bay(m, x, F, zf, depth, ww, fw, h, lit):
    """Canted bay window on the front wall (zf = wall face), with a little hipped roof."""
    a, b = ww / 2, fw / 2
    plan = [(x - a, zf), (x - b, zf + depth), (x + b, zf + depth), (x + a, zf)]
    y0, y1 = F - 0.1, F + 0.35 + h + 0.15
    for i in range(3):
        (x0, z0), (x1, z1) = plan[i], plan[i + 1]
        c = (x, 0, zf)
        m.emit("brick", [(x0, y0, z0), (x1, y0, z1), (x1, F + 0.35, z1), (x0, F + 0.35, z0)], c)
        m.emit("hh_trim", [(x0, F + 0.35, z0), (x1, F + 0.35, z1), (x1, y1, z1), (x0, y1, z0)], c)
        yaw = math.degrees(math.atan2(-(z1 - z0), x1 - x0))  # outward normal (-dz, dx)
        mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        L = math.hypot(x1 - x0, z1 - z0)
        window(m, (mx, F + 0.35 + 0.1 + h / 2, mz), yaw, L - 0.3, h - 0.1,
               "hh_glass_lit" if lit and i == 1 else "hh_glass", grid=(1, 2), d=0.05)
    m.emit("brick", [(p[0], y0, p[1]) for p in plan], (x, y0 + 1, zf))
    # hipped cap
    o = 0.12
    top = [(x - a, zf), (x - b - o * 0.6, zf + depth + o), (x + b + o * 0.6, zf + depth + o), (x + a, zf)]
    ry = y1 + 0.45
    P = [(p[0], y1, p[1]) for p in top]
    Lp, Rp = (x - a * 0.55, ry, zf), (x + a * 0.55, ry, zf)
    c = (x, y1 - 1, zf - 0.5)
    m.emit("hh_shingle_red", [P[0], P[1], Lp], c)
    m.emit("hh_shingle_red", [P[1], P[2], Rp, Lp], c)
    m.emit("hh_shingle_red", [P[2], P[3], Rp], c)
    m.emit("hh_trim", [(p[0], y1, p[1]) for p in top], (x, y1 + 1, zf))
    for i in range(3):
        (x0, z0), (x1, z1) = top[i], top[i + 1]
        beam(m, "hh_trim", (x0, y1 - 0.05, z0), (x1, y1 - 0.05, z1), 0.05, 0.16)


def m_house_b():
    """Single-storey brick bungalow, hipped roof, canted bay window, gabled door hood, window AC, dish."""
    m = B.Model("house_b")
    F, H, ph = 0.35, 3.3, 1.8
    m.node("shell-col")
    m.box("hh_block", (W_ + 0.1, F, D_ + 0.1), (0, F / 2, 0))
    m.box("brick", (W_, H - F, D_), (0, (F + H) / 2, 0))
    m.box("concrete", (2.0, F, 1.2), (0, F / 2, D_ / 2 + 0.6))
    m.box("concrete", (2.0, F / 2, 0.35), (0, F / 4, D_ / 2 + 1.37))
    m.box("concrete", (1.6, F, 0.9), (1.8, F / 2, -D_ / 2 - 0.45))
    m.node("detail")
    for sx in (-1, 1):  # soldier-course lintel band + white corners
        m.box("hh_trim", (0.14, H - F, 0.14), (sx * W_ / 2, (F + H) / 2, D_ / 2))
        m.box("hh_trim", (0.14, H - F, 0.14), (sx * W_ / 2, (F + H) / 2, -D_ / 2))
    o, t = 0.45, ph / (D_ / 2)
    ye = H - o * t
    Wo, Do = W_ + 2 * o, D_ + 2 * o
    m.tbox("hh_shingle_red", (Wo, Do), (Wo - Do + 0.02, 0.02), Do / 2 * t, (0, ye, 0), faces={"-y": "hh_trim"})
    rl = Wo - Do
    m.box("hh_shingle_red", (rl + 0.1, 0.16, 0.16), (0, ye + Do / 2 * t + 0.02, 0), (45, 0, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            beam(m, "hh_shingle_red", (sx * Wo / 2, ye + 0.06, sz * Do / 2), (sx * rl / 2, ye + Do / 2 * t + 0.06, 0), 0.16, 0.08)
    for sz in (-1, 1):
        m.box("hh_trim", (Wo, 0.2, 0.05), (0, ye - 0.05, sz * (Do / 2 + 0.02)))
        m.cyl("hh_gutter", 0.08, 0.08, Wo, (-Wo / 2, ye - 0.1, sz * (Do / 2 + 0.12)), (0, 0, -90), seg=6)
    for sx in (-1, 1):
        m.box("hh_trim", (0.05, 0.2, Do), (sx * (Wo / 2 + 0.02), ye - 0.05, 0))
        m.cyl("hh_gutter", 0.08, 0.08, Do, (sx * (Wo / 2 + 0.12), ye - 0.1, -Do / 2), (90, 0, 0), seg=6)
    downpipe(m, W_ / 2 + 0.1, Do / 2 + 0.12, D_ / 2 + 0.08, ye - 0.1)
    downpipe(m, -W_ / 2 - 0.1, -Do / 2 - 0.12, -D_ / 2 - 0.08, ye - 0.1, 1.2)  # rotted off
    chimney(m, -2.0, -1.2, H, H + ph + 0.9, 0.9, 0.7)
    # bay window left, door hood centre, AC window right
    bay(m, -2.5, F, D_ / 2, 0.55, 2.2, 1.3, 1.45, True)
    door(m, (0, F, D_ / 2), 0, screen=0, lamp=False, knob=True)
    m.decal("hh_glass", 0.9, 0.3, (0, F + 2.3 + 0.28, D_ / 2 + 0.01))
    m.gable("hh_shingle_red", 1.8, 1.3, 0.5, (0, F + 2.55, D_ / 2 + 0.65), end="hh_trim")
    for sx in (-1, 1):
        beam(m, "hh_trim", (sx * 0.8, F + 1.9, D_ / 2), (sx * 0.8, F + 2.52, D_ / 2 + 1.1), 0.08)
    sconce(m, (0.9, F + 1.9, D_ / 2), True)
    window(m, (2.6, F + 1.5, D_ / 2), 0, 1.2, 1.35, "hh_glass", shutter="hh_shutter_red")
    window_ac(m, (2.6, F + 1.05, D_ / 2), 0)
    for z, g, k in ((-1.6, "hh_glass", ""), (1.6, "hh_glass", "ply")):
        window(m, (W_ / 2, F + 1.5, z), 90, 0.95, 1.2, g, k)
    for z, g in ((-1.6, "hh_glass_broken"), (1.6, "hh_glass")):
        window(m, (-W_ / 2, F + 1.5, z), -90, 0.95, 1.2, g)
    window(m, (-2.2, F + 1.5, -D_ / 2), 180, 1.2, 1.2, "hh_glass")
    door(m, (1.8, F, -D_ / 2), 180, lamp=False, screen=20)
    m.box("metal", (0.35, 0.5, 0.18), (W_ / 2 + 0.09, 1.2, -2.8))  # electric meter
    m.cyl("glass", 0.1, 0.1, 0.06, (W_ / 2 + 0.18, 1.25, -2.8), (0, 0, -90), seg=8)
    sat_dish(m, (W_ / 2, H - 0.5, 2.3), 90)
    ac_unit(m, (-W_ / 2 - 0.8, 0, -1.8), 80, (-W_ / 2, 0.8, -1.8))
    mailbox(m, (-4.2, 0, 5.3), 0, flag=False)
    return m


def dormer(m, x, H, ph, D, w=1.5, ww=0.8, wh=0.95, glass="hh_glass", roof="hh_shingle", wall="hh_clap_blue"):
    t = ph / (D / 2)
    zf = D / 2 - 0.35
    yb = H + ph - zf * t - 0.15
    yw = yb + 0.25 + wh / 2
    ytop = yw + wh / 2 + 0.2
    zb = 0.7
    m.box(wall, (w, ytop - yb, zf - zb), (x, (yb + ytop) / 2, (zf + zb) / 2))
    for sx in (-1, 1):
        m.box("hh_trim", (0.1, ytop - yb, 0.1), (x + sx * w / 2, (yb + ytop) / 2, zf))
    m.gable(roof, w + 0.3, zf - zb + 0.35, 0.55, (x, ytop, (zf + zb) / 2 + 0.17), end=wall)
    for sx in (-1, 1):
        a = math.degrees(math.atan2(0.55, (w + 0.3) / 2))
        m.box("hh_trim", (math.hypot(0.55, (w + 0.3) / 2) + 0.04, 0.16, 0.05),
              (x + sx * (w + 0.3) / 4, ytop + 0.27, zf + 0.37), (0, 0, -sx * a))
    window(m, (x, yw, zf), 0, ww, wh, glass, grid=(2, 3), d=0.06)


def m_house_c():
    """Two-storey clapboard, steep gable, twin dormers, shed-roofed porch; somebody's upstairs."""
    m = B.Model("house_c")
    rng = random.Random(33)
    F, H, ph, sid = 0.5, 6.2, 3.0, "hh_clap_blue"
    m.node("shell-col")
    m.box("hh_block", (W_ + 0.1, F, D_ + 0.1), (0, F / 2, 0))
    m.box(sid, (W_, H - F, D_), (0, (F + H) / 2, 0))
    m.box("planks", (6.6, F - 0.05, 1.5), (0, (F - 0.05) / 2, D_ / 2 + 0.75), faces={"+z": "hh_trim_dark", "-x": "hh_trim_dark", "+x": "hh_trim_dark"})
    m.box("planks", (1.6, 0.3, 0.25), (0, 0.15, 5.125))
    m.box("planks", (1.6, 0.15, 0.25), (0, 0.075, 5.375))
    m.box("concrete", (1.4, F, 0.9), (-2.0, F / 2, -D_ / 2 - 0.45))
    m.node("detail")
    trim_skin(m, W_, D_, F, H)
    for sz in (-1, 1):  # belt course between storeys
        m.box("hh_trim", (W_ + 0.08, 0.18, 0.06), (0, 3.35, sz * (D_ / 2 + 0.03)))
    for sx in (-1, 1):
        m.box("hh_trim", (0.06, 0.18, D_ + 0.08), (sx * (W_ / 2 + 0.03), 3.35, 0))
    gable_roof(m, W_, D_, H, ph, over=0.4, end=sid,
               pipes=((-W_ / 2 - 0.2, 1, 3.3), (W_ / 2 + 0.2, -1, 0.15), (-W_ / 2 - 0.2, -1, 0.15)))
    chimney(m, 3.0, -0.4, H + 1.5, H + ph + 0.7, 0.7, 0.7)
    dormer(m, -2.2, H, ph, D_, glass="hh_glass")
    dormer(m, 2.2, H, ph, D_, glass="hh_glass_broken")
    # porch with shed roof (upstairs porch roof sits under the belt course)
    pz, yd = 4.85, F - 0.05
    for x in (-3.2, -0.85, 0.85, 3.2):
        post(m, x, pz, yd, 2.95)
    railing(m, (-3.2, pz), (-0.85, pz), yd, rng)
    railing(m, (0.85, pz), (3.2, pz), yd, rng)
    for x in (-3.2, 3.2):
        railing(m, (x, D_ / 2 + 0.05), (x, pz), yd, rng)
    beam(m, "hh_trim", (-3.35, 2.9, pz), (3.35, 2.9, pz), 0.14, 0.2)
    pr = math.degrees(math.atan2(0.3, 1.85))
    with m.push((0, 3.15, D_ / 2 + 0.92), (pr, 0, 0)):
        m.box("hh_shingle", (7.0, 0.08, 1.95), faces={"-y": "hh_trim", "+z": "hh_trim", "-z": "hh_trim",
                                                      "+x": "hh_trim", "-x": "hh_trim"})
    m.box("hh_trim", (7.0, 0.18, 0.05), (0, 3.0, 5.39))
    door(m, (0, F, D_ / 2), 0, screen=70, lamp=False)
    m.decal("eye", 0.7, 0.7, (1.05, 2.2, D_ / 2 + 0.03))  # the Veil has been here
    window(m, (-2.3, F + 1.4, D_ / 2), 0, 1.1, 1.4, "hh_glass", "boarded")
    window(m, (2.3, F + 1.4, D_ / 2), 0, 1.1, 1.4, "hh_glass_broken")
    window(m, (-2.3, 4.7, D_ / 2), 0, 1.0, 1.3, "hh_glass", shutter="hh_shutter", droop=True)
    window(m, (2.3, 4.7, D_ / 2), 0, 1.0, 1.3, "hh_glass_fig", shutter="hh_shutter")
    window(m, (0, 4.7, D_ / 2), 0, 0.7, 1.1, "hh_glass", grid=(1, 2))
    for sx in (-1, 1):
        for z in (-1.7, 1.7):
            window(m, (sx * W_ / 2, F + 1.4, z), sx * 90, 0.9, 1.3, "hh_glass",
                   "ply" if (sx > 0 and z > 0) else "")
            window(m, (sx * W_ / 2, 4.7, z), sx * 90, 0.9, 1.2, "hh_glass_lit" if (sx < 0 and z < 0) else "hh_glass")
        m.box("hh_trim", (0.1, 0.9, 0.9), (sx * W_ / 2, H + 1.1, 0))  # attic
        window(m, (sx * W_ / 2, H + 1.1, 0), sx * 90, 0.55, 0.7, "hh_glass", grid=(1, 1))
    window(m, (1.8, F + 1.5, -D_ / 2), 180, 1.1, 1.2, "hh_glass")
    window(m, (-2.3, 4.7, -D_ / 2), 180, 0.9, 1.2, "hh_glass")
    window(m, (2.0, 4.7, -D_ / 2), 180, 0.9, 1.2, "hh_glass", "boarded")
    door(m, (-2.0, F, -D_ / 2), 180, lamp=True)
    ac_unit(m, (-3.4, 0, -D_ / 2 - 0.8), -5, (-3.4, 0.9, -D_ / 2))
    mailbox(m, (-4.1, 0, 5.3), 0)
    m.cyl("metal", 0.03, 0.03, 1.8, (3.2, H + ph + 0.7, -0.4), seg=4)
    for y, w in ((1.3, 1.1), (1.55, 0.8), (1.75, 0.5)):
        m.cyl("metal", 0.015, 0.015, w, (3.2 - w / 2, H + ph + 0.7 + y, -0.4), (0, 0, -90 + (8 if y > 1.5 else 0)), seg=3, caps=False)
    return m


# ============================================================== cabin (enterable)

def log_run(m, axis, fixed, a0, a1, y, holes, r=0.15, over=0.25):
    """Horizontal log along X (axis 'x', z=fixed) or Z, split around (c0, c1, y0, y1) openings."""
    segs = [(a0 - over, a1 + over)]
    for c0, c1, y0, y1 in holes:
        if y0 - r < y < y1 + r:
            out = []
            for s0, s1 in segs:
                if c1 <= s0 or c0 >= s1:
                    out.append((s0, s1))
                else:
                    if c0 > s0:
                        out.append((s0, c0))
                    if c1 < s1:
                        out.append((c1, s1))
            segs = out
    for s0, s1 in segs:
        if s1 - s0 < 0.05:
            continue
        if axis == "x":
            m.cyl("hh_log", r, r, s1 - s0, (s0, y, fixed), (0, 0, -90), seg=6)
        else:
            m.cyl("hh_log", r, r, s1 - s0, (fixed, y, s0), (90, 0, 0), seg=6)


def m_cabin():
    m = B.Model("cabin")
    w, d, h = 6, 5, 2.8
    m.node("shell-col")
    B.room(m, w, d, h, "hh_log", door=(-1.5, 1.0, 2.1), floor="planks", ceil="planks")
    m.box("stone", (1.2, 2.6, 0.7), (-w / 2 - 0.35, 1.3, 0.2))
    m.node("props-col")
    B.bed(m, 1.8, -1.3, 0)
    B.table(m, -1.6, -1.2, 1.0, 0.8)
    m.box("metal", (0.6, 0.7, 0.6), (2.4, 0.35, 1.6))  # safe
    m.node("detail")
    front = [(-2.0, -1.0, 0, 2.1), (1.0, 1.8, 1.1, 1.9)]
    east = [(-0.4, 0.4, 1.1, 1.9)]
    west = [(-0.15, 0.55, 0, 2.6)]
    for k in range(10):
        y = 0.15 + k * 0.28
        log_run(m, "x", d / 2, -w / 2, w / 2, y, front)
        log_run(m, "x", -d / 2, -w / 2, w / 2, y, [])
        log_run(m, "z", w / 2, -d / 2, d / 2, y + 0.14, east)
        log_run(m, "z", -w / 2, -d / 2, d / 2, y + 0.14, west)
    B.windows(m, "hh_glass", "e", w, d, (0,), 1.5, 0.8, 0.8)
    B.windows(m, "hh_glass", "s", w, d, (1.4,), 1.5, 0.8, 0.8)
    window(m, (1.4, 1.5, d / 2 + 0.15), 0, 0.8, 0.8, None, grid=(2, 2), trim="planks")
    window(m, (w / 2 + 0.15, 1.5, 0), 90, 0.8, 0.8, None, grid=(2, 2), trim="planks")
    m.box("planks", (0.8, 0.8, 0.04), (w / 2 + 0.3, 1.5, 0.62), (0, 80, 0))  # shutter swung open
    door(m, (-1.5, 0, d / 2 + 0.15), 0, leaf=False, trim="planks")
    ye = gable_roof(m, w, d, h + 0.2, 1.7, over=0.4, side=0.4, mat="hh_tin", end="planks", trim="planks", gutters=False)
    chimney(m, -w / 2 - 0.35, 0.2, 2.6, h + 1.7 + 0.6, 0.7, 0.5, mat="stone", pot=False)
    m.tbox("stone", (1.2, 0.7), (0.7, 0.5), 0.4, (-w / 2 - 0.35, 2.6, 0.2))
    # porch: plank deck flush with the floor, lean-to on two log posts
    m.box("planks", (w + 0.4, 0.06, 1.1), (0, 0.03, d / 2 + 0.7))
    for x in (-w / 2, w / 2):
        m.cyl("hh_log", 0.11, 0.1, 2.1, (x, 0, 3.6), seg=6)
    m.cyl("hh_log", 0.12, 0.12, w + 0.6, (-w / 2 - 0.3, 2.1, 3.6), (0, 0, -90), seg=6)
    with m.push((0, 2.36, d / 2 + 0.95), (math.degrees(math.atan2(0.35, 1.45)), 0, 0)):
        m.box("hh_tin", (w + 0.8, 0.05, 1.5), faces={"-y": "planks"})
    sconce(m, (-0.8, 1.95, d / 2 + 0.15), False)
    # woodpile + chopping block + axe
    for i in range(9):
        m.cyl("hh_log", 0.12, 0.12, 0.6, (w / 2 + 0.35 + (i % 3) * 0.02, 0.12 + (i // 3) * 0.22, -1.8 + (i % 3) * 0.25),
              (0, 90 + (i * 7) % 11, 90), seg=6)
    m.cyl("hh_log", 0.25, 0.25, 0.5, (1.8, 0, 3.3), seg=7)
    beam(m, "planks", (1.8, 0.5, 3.3), (2.1, 1.1, 3.45), 0.04)
    m.box("iron", (0.2, 0.12, 0.03), (1.8, 0.52, 3.3), (0, 26, 60))
    return m


# ============================================================== motel (room 6 enterable)

def m_motel():
    """Six rooms along X, doors on +Z. Room 6 (x=+12.5) is enterable (Alex's room)."""
    m = B.Model("motel")
    w, d, h = 30, 7, 3
    m.node("shell-col")
    B.room(m, w, d, h, "hh_stucco", door=(13.0, 1.0, 2.1), floor="planks", ceil="paint")
    m.box("hh_stucco", (0.2, h, d - 0.4), (10.0, h / 2, 0))  # room 6 partition
    m.box("concrete", (w + 6, 0.05, 2.4), (-3, 0.025, d / 2 + 1.2))  # walkway
    m.box("hh_stucco_cream", (6, 3, 6), (-18, 1.5, -0.5))  # office
    m.node("props-col")
    B.bed(m, 13.5, -1.8)
    B.table(m, 11.2, 1.5, 0.9, 0.7)
    B.chair(m, 11.2, 2.3, 180)
    m.box("planks", (0.5, 0.6, 0.45), (14.6, 0.3, -2.9))  # nightstand
    m.node("detail")
    rng = random.Random(44)
    zf = d / 2
    # canopy roof: slab + deep fascia with enamel stripe, gutter, posts with base plates
    m.box("paint", (w + 6.4, 0.25, d + 3.2), (-3, h + 0.13, 1.2), faces={"-y": "hh_stucco_cream", "+y": "hh_tin"})
    m.box("hh_enamel_teal", (w + 6.5, 0.5, 0.08), (-3, h + 0.1, d / 2 + 2.84))
    m.box("hh_enamel_red", (w + 6.55, 0.1, 0.1), (-3, h + 0.02, d / 2 + 2.86))
    m.box("hh_enamel_teal", (0.08, 0.5, d + 3.2), (-21.24, h + 0.1, 1.2))
    m.box("hh_enamel_teal", (0.08, 0.5, d + 3.2), (15.24, h + 0.1, 1.2))
    m.cyl("hh_gutter", 0.08, 0.08, w + 6.4, (-21.2, h - 0.05, d / 2 + 2.95), (0, 0, -90), seg=6)
    downpipe(m, 15.1, d / 2 + 2.95, d / 2 + 2.95, h - 0.05)
    beam(m, "metal", (-20.2, h - 0.12, d / 2 + 2.2), (15.2, h - 0.12, d / 2 + 2.2), 0.14, 0.2)
    for x in range(-20, 17, 5):
        with K._On(m, "props-col"):  # canopy posts on the walkway: walked into (too thin for auto collision)
            m.box("metal", (0.1, h - 0.2, 0.1), (x, (h - 0.2) / 2, d / 2 + 2.2))
        m.box("metal", (0.24, 0.02, 0.24), (x, 0.06, d / 2 + 2.2))
    m.box("concrete", (w + 6, 0.12, 0.12), (-3, 0.06, d / 2 + 2.4))  # curb
    # kick band along the front
    m.box("hh_enamel_teal", (w, 0.35, 0.04), (0, 0.23, zf + 0.02))
    for i in range(6):
        x = -15 + 5 * (i + 0.5)
        dx = x + 0.5
        if i < 5:
            door(m, (dx, 0, zf), 0, 1.0, 2.1, "hh_door_motel")
            m.decal("hh_tx_%d" % (i + 1), 0.16, 0.2, (dx, 1.65, zf + 0.06))
            m.cyl("hh_brass", 0.02, 0.02, 0.03, (dx, 1.5, zf + 0.02), (90, 0, 0), seg=5)
        else:
            dx = 13.0
            door(m, (dx, 0, zf), 0, 1.0, 2.1, leaf=False)
            m.decal("hh_tx_6", 0.16, 0.2, (dx + 0.72, 1.65, zf + 0.02))
        wx = x - 1.2
        kind = "ply" if i == 3 else ""
        glass = "hh_glass_broken" if i == 1 else None
        B.windows(m, "hh_glass_lit" if i == 5 else "hh_glass", "s", w, d, (wx,), 1.6, 1.2, 1.0)
        window(m, (wx, 1.6, zf + 0.03), 0, 1.2, 1.0, glass, kind, grid=(2, 1), trim="hh_enamel_cream")
        if i != 3:
            window_ac(m, (wx, 0.7, zf), 0)
        m.box("bulb" if rng.random() < 0.5 or i == 5 else "glass", (0.3, 0.06, 0.3), (dx, h - 0.03, zf + 1.0))
        window(m, (x, 2.2, -zf), 180, 0.6, 0.4, "hh_glass", grid=(1, 1), trim="hh_enamel_cream")  # bathroom
    # office: lit window, door, OFFICE board, ice + vending machines
    oz = 2.5
    door(m, (-18, 0, oz), 0, 1.0, 2.1, "hh_door_motel", lamp=True)
    window(m, (-16.5, 1.6, oz), 0, 2.0, 1.2, "hh_glass_lit", grid=(3, 1), trim="hh_enamel_cream")
    m.box("hh_sign_cream", (2.6, 0.5, 0.06), (-18, 2.62, oz + 0.05))
    sign_text(m, "hh_tx_office", 0.34, (-18, 2.62, oz + 0.085))
    m.box("hh_enamel_cream", (6.1, 0.2, 6.1), (-18, 3.1, -0.5))
    with m.push((-20.25, 0, oz + 0.38)):
        m.box("hh_enamel_cream", (0.8, 1.7, 0.7), (0, 0.85, 0), faces={"+z": "hh_rib"})
        m.box("metal", (0.84, 0.12, 0.74), (0, 1.72, 0))
        sign_text(m, "hh_tx_ice", 0.28, (0, 1.35, 0.36))
        m.box("iron", (0.5, 0.35, 0.03), (0, 0.6, 0.36))
    with m.push((-19.2, 0, oz + 0.4)):
        m.box("hh_enamel_red", (0.9, 1.85, 0.75), (0, 0.93, 0), faces={"+z": "hh_vend"})
    # rooftop: vent stacks + a swamp cooler over the office
    for x in (-10, -2, 6, 12):
        m.cyl("metal", 0.08, 0.08, 0.5, (x, h + 0.25, -1.5), seg=6)
        m.cyl("metal", 0.14, 0.14, 0.06, (x, h + 0.75, -1.5), seg=6)
    m.box("hh_grille", (1.1, 0.8, 1.1), (-18, 3.6, -1.5), faces={"+y": "metal"})
    # room 6 props (the radio itself is Chapter 1's, on the table: Ch1ScenesA._room_props; the nightstand has the lamp)
    m.decal("moth", 0.8, 0.8, (12.5, 1.8, -d / 2 + 0.21))
    m.decal("eye", 0.7, 0.7, (-15 + 5 * 3.5 + 0.5, 1.6, d / 2 + 0.12))  # room 4
    _motel_room6(m)
    return m


# ============================================================== diner (enterable)

def arch(m, mat, L, D, y0, rise, n=10, cap="hh_enamel_cream"):
    """Barrel roof along X: half-ellipse profile over depth D."""
    rows = []
    for x in (-L / 2, L / 2):
        rows.append([(x, y0 + rise * math.sin(math.pi * j / n), D / 2 * math.cos(math.pi * j / n)) for j in range(n + 1)])
    m.surface(mat, rows[::-1])
    for x in (-L / 2, L / 2):
        pts = [(x, y0 + rise * math.sin(math.pi * j / n), D / 2 * math.cos(math.pi * j / n)) for j in range(n + 1)]
        m.emit(cap, pts, (0, y0 + rise * 0.3, 0))


def m_diner():
    m = B.Model("diner")
    w, d, h = 14, 9, 3.5
    m.node("shell-col")
    B.room(m, w, d, h, "hh_enamel_cream", door=(-4.5, 1.2, 2.3), floor="tile")
    m.node("props-col")
    m.box("paint", (8, 1.05, 0.7), (1.5, 0.52, -2.2))
    for x in (-5.5, -2.5):
        B.table(m, x, -2.6, 1.0, 1.2)
        m.box("red", (1.0, 0.9, 0.5), (x, 0.45, -3.8))
        m.box("red", (1.0, 0.9, 0.5), (x, 0.45, -1.5))
    with m.push((5.8, 0, 3.2), (0, 200, 0)):  # arcade cabinet
        m.box("iron", (0.8, 1.8, 0.8), (0, 0.9, 0))
    m.node("detail")
    with K._On(m, "props-col"):  # counter stools: furniture, walked into (seat and post too thin for auto boxes)
        for x in range(6):
            m.cyl("red", 0.2, 0.2, 0.06, (x * 1.3 - 1.5, 0.7, -1.5), seg=6)
            m.cyl("metal", 0.04, 0.04, 0.7, (x * 1.3 - 1.5, 0, -1.5), seg=4)
    B.windows(m, "hh_glass", "s", w, d, (-1, 1.5, 4), 1.6, 2.2, 1.4)
    with m.push((5.8, 0, 3.2), (0, 200, 0)):
        m.decal("screen", 0.6, 0.45, (0, 1.35, 0.41), (-10, 0, 0))
    hw, hd, top = w / 2, d / 2, h + 0.45
    # exterior skin: stainless lower band, chrome strips, red stripe, fascia band; rounded corner drums
    front_gap = (-5.1, -3.9)

    def band(mat, y0, y1, off, sides=True):
        yc, hh = (y0 + y1) / 2, y1 - y0
        for a, b in ((-hw, front_gap[0]), (front_gap[1], hw)) if y0 < 2.3 else ((-hw, hw),):
            m.box(mat, (b - a, hh, off), ((a + b) / 2, yc, hd + off / 2))
        m.box(mat, (w, hh, off), (0, yc, -hd - off / 2))
        if sides:
            for sx in (-1, 1):
                m.box(mat, (off, hh, d), (sx * (hw + off / 2), yc, 0))

    band("hh_rib", 0.0, 0.85, 0.04)
    band("hh_chrome", 0.85, 0.95, 0.07)
    band("hh_enamel_red", 2.45, 2.75, 0.03)
    band("hh_chrome", 2.42, 2.47, 0.06)
    band("hh_chrome", 2.73, 2.78, 0.06)
    m.box("hh_enamel_cream", (w, 0.45, d), (0, h + 0.225, 0), faces={"-y": "paint"})
    band("hh_chrome", top - 0.06, top, 0.06)
    for sx in (-1, 1):
        for sz in (-1, 1):
            p = (sx * hw, 0, sz * hd)
            m.cyl("hh_rib", 0.31, 0.31, 0.85, p, seg=12, caps=False)
            m.cyl("hh_chrome", 0.34, 0.34, 0.1, (p[0], 0.85, p[2]), seg=12)
            m.cyl("hh_enamel_cream", 0.3, 0.3, top - 0.95, (p[0], 0.95, p[2]), seg=12, caps=False)
            m.cyl("hh_enamel_red", 0.315, 0.315, 0.3, (p[0], 2.45, p[2]), seg=12, caps=False)
            m.cyl("hh_chrome", 0.33, 0.33, 0.06, (p[0], top - 0.06, p[2]), seg=12)
    arch(m, "hh_tin", w + 0.4, d + 0.5, top, 0.7)
    # ribbon windows: chrome frames + mullions; door frame
    for x in (-1, 1.5, 4):
        window(m, (x, 1.6, hd + 0.03), 0, 2.2, 1.4, None, grid=(2, 1), trim="hh_chrome", d=0.05)
    door(m, (-4.5, 0, hd), 0, 1.2, 2.3, leaf=False, trim="hh_chrome")
    m.decal("hh_glass", 0.9, 0.35, (-4.5, 2.68, hd + 0.045))
    # sign board on the fascia (world Label3D "DINER" floats 5cm in front) + neon border
    m.box("hh_sign_red", (3.4, 0.5, 0.05), (0, 3.65, hd + 0.045))
    for y in (3.38, 3.92):
        m.cyl("bulb_cold", 0.02, 0.02, 3.4, (-1.7, y, hd + 0.08), (0, 0, -90), seg=4, caps=False)
    # side windows (dark), back door, kitchen exhaust, roof AC
    for z in (-2.5, 1.5):
        window(m, (-hw - 0.04, 1.6, z), -90, 1.6, 1.2, "hh_glass" if z > 0 else "hh_glass_broken", grid=(2, 1), trim="hh_chrome")
    window(m, (hw + 0.04, 1.6, 1.5), 90, 1.6, 1.2, "hh_glass", "ply", grid=(2, 1), trim="hh_chrome")
    door(m, (4.5, 0, -hd - 0.04), 180, 0.9, 2.1, "hh_door_motel", lamp=True, trim="hh_chrome")
    m.cyl("metal", 0.3, 0.3, 0.9, (3.0, top + 0.4, -2.5), seg=10)
    m.cyl("metal", 0.45, 0.2, 0.3, (3.0, top + 1.3, -2.5), seg=10)
    m.box("hh_grille", (1.2, 0.8, 1.0), (-3.0, top + 0.9, -1.2), faces={"+y": "metal"})
    # pole sign by the road: "EAT" in red neon on a cream arrow board
    px, pz = 6.9, 3.9
    m.cyl("metal", 0.12, 0.12, 5.2, (px, 0, pz), seg=8)
    m.cyl("concrete", 0.3, 0.35, 0.4, (px, 0, pz), seg=8)
    with m.push((px, 5.6, pz)):
        m.box("hh_sign_cream", (2.0, 0.9, 0.2), (0, 0, 0), faces={"+z": "hh_sign_cream"})
        m.tbox("hh_sign_cream", (0.9, 0.2), (0.02, 0.2), 0.5, (-1.0, 0, 0), (0, 0, 90))
        sign_text(m, "hh_tx_eat", 0.55, (0.1, 0, 0.11))
        sign_text(m, "hh_tx_eat", 0.55, (0.1, 0, -0.11), (0, 180, 0))
        for y in (-0.48, 0.48):
            m.cyl("hh_chrome", 0.04, 0.04, 2.0, (-1.0, y, 0), (0, 0, -90), seg=5)
    _diner_inside(m)
    return m


# ============================================================== Grady's store (enterable)

GRADY_BOARD = (10.0, 0.8)  # the store's name board (w, h), centred at SIGN_Y, front at z = 5.06
SIGN_Y = 4.05  # over the awning frames (3.58), under the string course


def m_grady_store():
    m = B.Model("grady_store")
    w, d, h = 14, 10, 4.2
    m.node("shell-col")
    B.room(m, w, d, h, "brick", door=(0, 1.6, 2.4), floor="tile")
    m.box("brick", (w + 0.2, 0.8, 0.3), (0, h + 0.4, d / 2 - 0.15))  # parapet
    m.node("props-col")
    m.box("planks", (4, 1.0, 0.8), (-3, 0.5, -2))
    for x in (1.5, 4.0):
        m.box("metal", (0.5, 2.0, 4.0), (x, 1.0, -1.5))
    m.box("rust", (1.2, 0.7, 0.7), (-5.8, 0.35, -4.0))  # storage box
    m.node("detail")
    B.windows(m, "hh_shop_lit", "s", w, d, (-4.2, 4.2), 1.6, 3.0, 1.8)
    for x in (1.5, 4.0):
        for y in (0.5, 1.1, 1.7):
            for z in (-3, -2, -1, 0):
                m.box("red" if (x + y + z) % 2 else "white", (0.3, 0.3, 0.25), (x + 0.1, y + 0.18, z - 0.5))
    m.box("metal", (0.5, 0.3, 0.4), (-2.5, 1.15, -2))  # register
    m.decal("moth", 0.9, 0.9, (-1.6, 1.8, d / 2 + 0.02))
    hd = d / 2
    # storefront: dark frames, bulkheads, transoms, pilasters
    for x in (-4.2, 4.2):
        window(m, (x, 1.6, hd + 0.03), 0, 3.0, 1.8, None, grid=(3, 1), trim="hh_trim_dark", d=0.08)
        m.box("hh_trim_dark", (3.2, 0.6, 0.08), (x, 0.3, hd + 0.04))
        for k in (-1, 0, 1):
            m.box("hh_trim_dark", (0.8, 0.35, 0.03), (x + k * 1.0, 0.3, hd + 0.095))
        m.decal("hh_glass", 3.0, 0.4, (x, 2.95, hd + 0.01))
        window(m, (x, 2.95, hd + 0.01), 0, 3.0, 0.4, None, grid=(3, 1), trim="hh_trim_dark", d=0.06)
    for x in (-6.9, -1.25, 1.25, 6.9):  # pilasters: capped under the sign band (they used to run across it)
        top = SIGN_Y - GRADY_BOARD[1] / 2 - 0.02
        m.box("brick", (0.5, top, 0.12), (x, top / 2, hd + 0.06))
        m.box("stone", (0.6, 0.25, 0.18), (x, 0.12, hd + 0.08))
        m.box("stone", (0.6, 0.2, 0.18), (x, top - 0.1, hd + 0.08))
    door(m, (0, 0, hd), 0, 1.6, 2.4, leaf=False, trim="hh_trim_dark")
    m.decal("hh_glass", 1.5, 0.4, (0, 2.95, hd + 0.01))
    # cornice + the sign band between the awning frames and the cornice (its world Label3D: build_assets, on
    # GRADY_BOARD; nothing stands proud of it)
    m.box("stone", (w + 0.5, 0.16, 0.5), (0, h + 0.88, hd - 0.1))
    m.box("stone", (w + 0.36, 0.12, 0.4), (0, h + 0.74, hd - 0.1))
    m.box("stone", (w + 0.3, 0.14, 0.32), (0, SIGN_Y + GRADY_BOARD[1] / 2 + 0.09, hd + 0.02))  # string course
    m.box("hh_sign_green", (GRADY_BOARD[0], GRADY_BOARD[1], 0.06), (0, SIGN_Y, hd + 0.03))
    for s in (-1, 1):
        m.box("hh_trim", (0.08, GRADY_BOARD[1] + 0.08, 0.1), (s * (GRADY_BOARD[0] / 2 + 0.04), SIGN_Y, hd + 0.05))
    for k, x in enumerate((-3.5, 0, 3.5)):  # gooseneck lamps, one still working
        beam(m, "iron", (x, h + 0.55, hd - 0.02), (x, h + 0.75, hd + 0.35), 0, r=0.025, seg=4)
        beam(m, "iron", (x, h + 0.75, hd + 0.35), (x, h + 0.62, hd + 0.62), 0, r=0.025, seg=4)
        m.lathe("iron", [(0.04, 0.12), (0.12, 0.05), (0.2, -0.05), (0.18, -0.06)], (x, h + 0.55, hd + 0.66), seg=8)
        m.cyl("bulb" if k == 1 else "glass", 0.06, 0.06, 0.06, (x, h + 0.46, hd + 0.66), seg=6)
    # striped awning over the storefront: three bays, the right one torn off its frame
    aw = math.degrees(math.atan2(0.6, 1.4))
    for k, x in enumerate((-4.2, 0, 4.2)):
        ww = 3.4 if k != 1 else 2.4
        for sx in (-1, 1):
            beam(m, "iron", (x + sx * ww / 2, 3.55, hd), (x + sx * ww / 2, 2.95, hd + 1.4), 0, r=0.025, seg=4)
        m.cyl("iron", 0.025, 0.025, ww, (x - ww / 2, 2.95, hd + 1.4), (0, 0, -90), seg=4, caps=False)
        if k == 2:
            with m.push((x - 0.4, 3.25, hd + 0.7), (aw + 22, 0, 8)):
                m.box("fabric", (ww - 0.9, 0.03, 1.55))
            m.box("fabric", (0.7, 0.03, 1.5), (x + 1.2, 3.25, hd + 0.7), (aw, 0, 0))
            continue
        with m.push((x, 3.25, hd + 0.7), (aw, 0, 0)):
            m.box("fabric", (ww, 0.03, 1.55))
        m.box("fabric", (ww, 0.28, 0.02), (x, 2.82, hd + 1.42))
    # east wall ghost sign, downpipes, back door, rooftop AC
    sign_text(m, "hh_tx_grady", 0.9, (w / 2 + 0.01, 3.1, -0.5), (0, 90, 0))
    for sx in (-1, 1):
        m.cyl("hh_gutter", 0.06, 0.06, h + 0.3, (sx * (w / 2 + 0.08), 0.1, -hd + 0.4), seg=6)
        m.box("hh_gutter", (0.3, 0.12, 0.3), (sx * (w / 2 + 0.08), h + 0.35, -hd + 0.4))
    door(m, (3.0, 0, -hd), 180, 1.0, 2.1, "hh_door_motel", lamp=True)
    m.box("hh_grille", (1.6, 1.0, 1.2), (-2.5, h + 0.9, -1.5), faces={"+y": "metal"})
    m.cyl("metal", 0.1, 0.1, 0.8, (3, h + 0.4, -3), seg=6)
    # front: ice chest, soda machine
    with m.push((-6.2, 0, hd + 0.3)):
        m.box("hh_enamel_cream", (1.3, 1.0, 0.55), (0, 0.5, 0), faces={"+y": "hh_rib"})
        sign_text(m, "hh_tx_ice", 0.3, (0, 0.62, 0.28))
    with m.push((6.3, 0, hd + 0.38)):
        m.box("hh_enamel_red", (0.9, 1.85, 0.7), (0, 0.93, 0), faces={"+z": "hh_vend"})
    _store_inside(m)
    return m


# ============================================================== bar (enterable)

def m_bar():
    m = B.Model("bar")
    w, d, h = 12, 10, 3.8
    m.node("shell-col")
    B.room(m, w, d, h, "hh_clap_green", door=(-3, 1.2, 2.3), floor="planks")
    m.node("props-col")
    m.box("planks", (6, 1.1, 0.7), (1, 0.55, -3))
    m.box("planks", (6, 2.2, 0.4), (1, 1.4, -4.6))  # back shelf
    for i, (x, z) in enumerate(((-3.5, 0), (0, 1.5), (3.5, 0.5))):
        m.cyl("planks", 0.55, 0.55, 0.06, (x, 0.72, z), seg=8)
        m.cyl("metal", 0.06, 0.06, 0.72, (x, 0, z), seg=5)
        for k in range(3):
            B.chair(m, x + math.cos(k * 2.1 + i) * 0.9, z + math.sin(k * 2.1 + i) * 0.9, k * 120 + i * 30)
    B.table(m, -4, -3, 1.4, 1.4)  # Silas' card table
    m.node("detail")
    with K._On(m, "props-col"):  # bar stools: furniture, walked into (seat and post too thin for auto boxes)
        for x in range(-1, 4):
            m.cyl("metal", 0.18, 0.18, 0.05, (x * 1.4 - 0.5, 0.75, -2.1), seg=6)
            m.cyl("metal", 0.03, 0.03, 0.7, (x * 1.4 - 0.5, 0, -2.1), seg=4)
    for x in range(12):
        m.cyl("glass", 0.05, 0.05, 0.28, (-1.8 + x * 0.5, 1.6, -4.3), seg=5)
    B.windows(m, "hh_glass_lit", "s", w, d, (1.0, 4.0), 1.6, 1.4, 1.2)
    hd = d / 2
    for sz in (-1, 1):  # block skirt
        m.box("hh_block", (w + 0.1, 0.35, 0.05), (0, 0.175, sz * (hd + 0.025)))
    for sx in (-1, 1):
        m.box("hh_block", (0.05, 0.35, d + 0.1), (sx * (w / 2 + 0.025), 0.175, 0))
    trim_skin(m, w, d, 0.35, h, bands=False)
    trim_skin(m, w + 0.02, d + 0.02, h - 0.1, h + 0.2, corners=False)
    gable_roof(m, w, d, h + 0.2, 2.2, over=0.35, end="hh_clap_green",
               pipes=((w / 2 + 0.2, 1, 0.15), (-w / 2 - 0.2, -1, 0.15)))
    for sx in (-1, 1):
        attic_vent(m, (sx * w / 2, h + 0.9, 0), sx * 90, 0.7, 0.6)
    m.cyl("metal", 0.12, 0.12, 1.6, (3.5, h + 0.9, -3.0), seg=8)  # stovepipe
    m.cyl("metal", 0.25, 0.02, 0.15, (3.5, h + 2.55, -3.0), seg=8)
    # front: sign board (world Label3D at z=+5.1), window frames, neon, bars, hanging lantern
    m.box("hh_sign_red", (7.6, 0.72, 0.05), (0.2, 3.12, hd + 0.03))
    for x in (1.0, 4.0):
        window(m, (x, 1.6, hd + 0.03), 0, 1.4, 1.2, None, grid=(2, 2), trim="hh_trim_dark")
    sign_text(m, "hh_tx_beer", 0.28, (4.0, 1.78, hd + 0.045))
    sign_text(m, "hh_tx_open", 0.22, (1.0, 1.35, hd + 0.045))
    for k in range(6):
        m.cyl("iron", 0.015, 0.015, 1.3, (0.4 + k * 0.24, 0.95, hd + 0.12), seg=4)
    m.box("iron", (1.5, 0.04, 0.04), (1.0, 1.6, hd + 0.12))
    door(m, (-3, 0, hd), 0, 1.2, 2.3, leaf=False, trim="hh_trim_dark")
    beam(m, "iron", (-4.15, 2.45, hd), (-4.15, 2.45, hd + 0.6), 0.04)
    beam(m, "iron", (-4.15, 2.1, hd), (-4.15, 2.45, hd + 0.35), 0.03)
    m.cyl("iron", 0.01, 0.01, 0.25, (-4.15, 2.2, hd + 0.55), seg=3)
    with m.push((-4.15, 1.95, hd + 0.55)):
        m.box("bulb_red", (0.14, 0.2, 0.14))
        for sx in (-1, 1):
            for sz in (-1, 1):
                m.box("iron", (0.02, 0.24, 0.02), (sx * 0.075, 0, sz * 0.075))
        m.tbox("iron", (0.2, 0.2), (0.04, 0.04), 0.1, (0, 0.1, 0))
    # sides + back
    window(m, (w / 2, 1.6, 1.5), 90, 1.2, 1.1, "hh_glass", "ply")
    window(m, (-w / 2, 1.6, -1.5), -90, 1.2, 1.1, "hh_glass_broken", shutter="hh_shutter_red", droop=True)
    window(m, (-w / 2, 1.6, 2.0), -90, 1.2, 1.1, "hh_glass", "boarded")
    door(m, (-2.0, 0, -hd), 180, 1.0, 2.1, "hh_door_motel", lamp=True, trim="hh_trim_dark")
    with m.push((1.8, 0, -hd - 0.75), (0, 0, 0)):  # dumpster, lid propped open
        m.tbox("rust", (1.8, 1.0), (1.9, 1.2), 1.1, (0, 0.08, 0))
        m.box("iron", (1.9, 0.06, 1.2), (0, 1.35, -0.8), (-70, 0, 0))
        for sx in (-1, 1):
            m.cyl("rubber", 0.08, 0.08, 0.06, (sx * 0.7, 0.08, 0.35), (0, 0, 90), seg=6)
    for k, (x, z) in enumerate(((4.0, -hd - 0.5), (4.6, -hd - 0.45), (4.3, -hd - 0.95))):
        m.lathe("metal", [(0.0, 0), (0.2, 0), (0.24, 0.05), (0.26, 0.3), (0.24, 0.55), (0.2, 0.6), (0.0, 0.6)],
                (x, 0, z), seg=8)
    _bar_inside(m)
    return m


def m_motel_sign():
    """Lakeview Motel's pole sign by the road: a lettered board on two steel posts, the VACANCY box hung under it;
    both read from either side (front +Z). The lettering is world Label3Ds (build_assets: faces at z = +-0.1 and
    +-0.08)."""
    m = B.Model("motel_sign")
    m.node("posts-col")
    for x in (-1.6, 1.6):
        m.cyl("metal", 0.08, 0.08, 6.3, (x, 0, 0), seg=8)
    m.node("detail")
    for x in (-1.6, 1.6):
        m.box("concrete", (0.5, 0.3, 0.5), (x, 0.15, 0))
    m.box("hh_enamel_teal", (4.5, 1.25, 0.16), (0, 5.6, 0))
    m.box("hh_sign_cream", (4.2, 1.0, 0.2), (0, 5.6, 0))
    m.box("hh_enamel_red", (4.6, 0.1, 0.22), (0, 6.27, 0))
    for k in range(9):
        m.cyl("bulb" if k % 3 else "glass", 0.035, 0.035, 0.06, (-2.0 + k * 0.5, 6.32, 0), seg=5)
    for x in (-0.95, 0.95):  # the VACANCY box hangs off the board on two brackets
        m.box("metal", (0.05, 0.3, 0.05), (x, 4.97, 0))
    m.box("hh_enamel_teal", (2.4, 0.52, 0.14), (0, 4.6, 0))
    m.box("iron", (2.2, 0.4, 0.16), (0, 4.6, 0))
    return m


MODELS = [m_house_a, m_house_b, m_house_c, m_cabin, m_motel, m_diner, m_grady_store, m_bar, m_motel_sign]


# ============================================================== furnished interiors (interior_kit)

def _motel_room6(m):
    """Alex's room (x 10.1..14.8, z -3.3..3.3, door at x 13 on +Z): dresser + TV, rug, lamp and phone on the
    nightstand, the bathroom door, a painting over the bed, a suitcase, the wall heater, curtains."""
    with K._On(m, "props-col"):
        m.box("planks", (0.45, 0.8, 1.3), (10.4, 0.4, -1.1))
    m.box("ik_black", (0.4, 0.35, 0.45), (10.45, 1.0, -1.1))  # television
    m.box("ik_steel", (0.02, 0.28, 0.36), (10.68, 1.0, -1.1))
    m.box("ik_carpet", (1.8, 0.01, 1.5), (12.6, 0.06, 0.4))
    with m.push((14.6, 0.6, -2.9)):
        m.cyl("ik_brass", 0.06, 0.08, 0.3, (0, 0, 0), seg=6)
        m.cyl("ik_beige", 0.12, 0.2, 0.22, (0, 0.3, 0), seg=8, caps=False)
        m.box("ik_black", (0.18, 0.07, 0.12), (-0.1, 0.03, 0.12))  # phone
    m.box("door", (0.05, 2.0, 0.8), (14.77, 1.0, 1.6))  # bathroom (locked)
    m.box("ik_brass", (0.04, 0.04, 0.06), (14.72, 1.0, 1.3))
    K.board(m, "ik_map", 13.5, 1.6, -3.28, 0, 0.9, 0.6, "ik_wood_dark")
    with m.push((12.2, 0, 0.9), (0, 20, 0)):  # suitcase, half unpacked
        m.box("ik_red", (0.7, 0.22, 0.45), (0, 0.11, 0))
        m.box("ik_red", (0.7, 0.03, 0.45), (0, 0.35, -0.22), (-70, 0, 0))
        m.box("ca_tee", (0.4, 0.05, 0.3), (0.05, 0.24, 0.02))
    K.radiator(m, 11.2, 3.28, 180, 0.9)
    for x in (10.6, 11.8):
        m.box("ik_curtain", (0.5, 1.9, 0.03), (x, 1.25, 3.25))
    m.box("ik_rail", (1.8, 0.03, 0.03), (11.2, 2.25, 3.25))
    m.box("ik_steel", (0.35, 0.05, 0.35), (12.5, 2.93, 0.0))  # ceiling light
    m.cyl("ik_lamp_dead", 0.15, 0.15, 0.06, (12.5, 2.86, 0.0), seg=8)
    m.cyl("ik_brass", 0.06, 0.05, 0.03, (11.4, 0.785, 1.8), seg=6)  # ashtray on the table


def _diner_inside(m):
    """Back bar with the coffee machines and the pie case, menu boards, jukebox, a register, napkins and
    ketchup on the booths, a clock, ceiling lamps over the counter."""
    with K._On(m, "props-col"):
        m.box("ik_steel", (8.0, 0.9, 0.6), (1.5, 0.45, -4.15))  # back counter
        with m.push((6.3, 0, -1.2)):  # jukebox
            m.box("ik_wood_dark", (0.8, 1.4, 0.55), (0, 0.7, 0))
    m.box("ik_steel", (0.5, 0.55, 0.45), (-1.0, 1.18, -4.15))  # coffee machine
    for x in (-1.2, -0.8):
        m.cyl("glass", 0.08, 0.08, 0.2, (x, 0.92, -3.9), seg=6)
    m.box("glass", (1.2, 0.45, 0.5), (2.5, 1.13, -4.15))  # pie case
    for k in range(3):
        m.cyl("ik_beige", 0.14, 0.14, 0.05, (2.1 + k * 0.4, 0.95, -4.15), seg=8)
    m.box("ik_steel", (0.35, 0.3, 0.3), (4.5, 1.2, -2.2))  # register on the counter
    for k in range(3):
        K.board(m, "ik_chalk", -0.5 + k * 2.0, 2.3, -4.47, 0, 1.6, 0.7, "ik_wood_dark")
    K.clock(m, 5.8, 2.5, -4.45, 0)
    for x in (-5.5, -2.5):
        m.box("ik_steel", (0.12, 0.14, 0.08), (x, 0.84, -2.6))
        m.cyl("ik_red", 0.03, 0.03, 0.18, (x + 0.2, 0.77, -2.55), seg=6)
    m.box("ik_lamp", (0.6, 0.5, 0.05), (6.3, 1.05, -0.92))  # jukebox front
    m.box("ik_brass", (0.7, 0.08, 0.05), (6.3, 1.38, -0.92))
    for x in (-1.0, 1.5, 4.0):
        m.cyl("ik_steel", 0.01, 0.01, 0.9, (x, 2.6, -2.2), seg=4)
        m.cyl("ik_red", 0.05, 0.25, 0.2, (x, 2.45, -2.2), seg=8, caps=False)


def _store_inside(m):
    """Wall shelving, the register and the rifle rack behind the counter, a glass-door fridge, feed sacks,
    fishing gear, a rack of festival lanterns, stock boxes, a calendar and a hanging lamp."""
    with K._On(m, "props-col"):
        for z in (-3.0, -0.5, 2.0):
            K.shelf_unit(m, 6.75, z, -90, 2.2, 2.2, 0.45, "ik_bottles" if z < 0 else "int_books")
        with m.push((-6.4, 0, 1.8)):  # fridge
            m.box("ik_steel", (0.7, 2.0, 1.4), (0, 1.0, 0))
    m.box("glass", (0.02, 1.7, 1.3), (-6.04, 1.05, 1.8))
    for y in (0.6, 1.1, 1.6):
        for k in range(5):
            m.cyl(("ik_red", "ik_blue", "ik_green", "white", "ik_red")[k], 0.035, 0.035, 0.2,
                  (-6.2, y, 1.3 + k * 0.25), seg=5)
    m.box("ik_steel", (0.4, 0.3, 0.35), (-2.2, 1.15, -2.0))  # register on the counter
    m.box("ik_black", (0.3, 0.02, 0.2), (-3.4, 1.01, -2.0))
    with m.push((-3.0, 1.4, -4.93)):  # rifle rack (empty slots, one old shotgun)
        m.box("ik_wood_dark", (1.6, 0.08, 0.12), (0, 0, 0.06))
        m.box("ik_wood_dark", (1.6, 0.08, 0.12), (0, 0.9, 0.06))
        m.box("ik_black", (0.05, 1.0, 0.05), (-0.4, 0.45, 0.1), (0, 0, 10))
    for k in range(3):
        m.box("hd_canvas", (0.5, 0.7, 0.3), (-5.6 + k * 0.55, 0.35, 4.3), (0, k * 17, 4 * k))
    for k in range(4):
        m.cyl("ik_black", 0.008, 0.008, 2.2, (6.2, 0, 4.2 - k * 0.1), (8 - k * 3, 0, 0), seg=4)  # fishing rods
    for k in range(5):
        m.box("lantern", (0.2, 0.3, 0.2), (-1.5 + k * 0.35, 2.4, 4.7))
    m.box("ik_wood", (2.0, 0.05, 0.05), (-0.8, 2.6, 4.75))
    for k in range(6):
        m.box("ik_beige", (0.5, 0.35, 0.4), (4.8 + (k % 2) * 0.55, 0.18 + (k // 2) * 0.36, -4.6))
    K.board(m, "ik_cork", -5.5, 1.7, -4.93, 0, 0.5, 0.7, "ik_wood")
    m.cyl("ik_steel", 0.01, 0.01, 1.2, (0, 3.6, 0), seg=4)
    m.cyl("ik_green", 0.08, 0.35, 0.25, (0, 3.35, 0), seg=8, caps=False)


def _bar_inside(m):
    """Beer taps and bottles, neon signs, a dartboard, a mounted fish, lamps over the tables, a jukebox, the
    coat rack by the door, framed photos of the harbor, ashtrays and glasses on the tables."""
    with K._On(m, "props-col"):
        with m.push((5.3, 0, 4.0)):  # jukebox
            m.box("ik_wood_dark", (0.8, 1.4, 0.55), (0, 0.7, 0))
    m.box("ik_lamp", (0.6, 0.5, 0.05), (5.3, 1.05, 3.72))
    for k in range(4):  # taps
        m.box("ik_brass", (0.05, 0.3, 0.05), (0.2 + k * 0.3, 1.25, -3.0))
        m.box("ik_black", (0.04, 0.12, 0.04), (0.2 + k * 0.3, 1.45, -3.0))
    for k in range(10):
        m.cyl(("glass", "ik_brass", "ik_green")[k % 3], 0.04, 0.04, 0.3, (-1.6 + k * 0.5, 2.08, -4.4), seg=5)
    for x, mat in ((-1.0, "hh_tx_beer"), (3.2, "hh_tx_open")):
        m.box(mat, (1.2, 0.4, 0.02), (x, 2.9, -4.97))
    with m.push((5.97, 1.7, -1.0), (0, -90, 0)):  # dartboard
        m.cyl("ik_black", 0.24, 0.24, 0.04, (0, 0, 0), (90, 0, 0), seg=10)
        m.cyl("ik_beige", 0.2, 0.2, 0.01, (0, 0, 0.04), (90, 0, 0), seg=10)
        m.cyl("ik_red", 0.03, 0.03, 0.01, (0, 0, 0.05), (90, 0, 0), seg=6)
    with m.push((-5.95, 2.3, 1.0), (0, 90, 0)):  # a mounted catfish
        m.box("ik_wood_dark", (0.9, 0.35, 0.03), (0, 0, 0))
        m.ellipsoid("rust", (0.35, 0.1, 0.06), (0, 0, 0.05), seg=8, rings=4)
    for x, z in ((-3.5, 0), (0, 1.5), (3.5, 0.5)):
        m.cyl("ik_steel", 0.01, 0.01, 1.4, (x, 2.4, z), seg=4)
        m.cyl("ik_green", 0.08, 0.3, 0.2, (x, 2.2, z), seg=8, caps=False)
        m.cyl("glass", 0.04, 0.035, 0.12, (x + 0.2, 0.75, z - 0.1), seg=5)
        m.cyl("ik_brass", 0.06, 0.05, 0.02, (x - 0.15, 0.75, z + 0.15), seg=6)
    with m.push((-5.5, 0, 4.4)):  # coat rack
        m.cyl("ik_wood_dark", 0.02, 0.02, 1.8, (0, 0, 0), seg=5)
        m.box("ca_parka", (0.35, 0.8, 0.15), (0, 1.2, 0.08))
    for k in range(3):
        K.board(m, "ik_map", -2.0 + k * 1.3, 2.0, 4.97, 180, 0.6, 0.45, "ik_wood_dark")
    for k in range(4):  # cards and chips on Silas' table
        m.box("white", (0.06, 0.005, 0.09), (-4.2 + k * 0.12, 0.79, -3.1), (0, k * 25, 0))
        m.cyl("ik_red", 0.02, 0.02, 0.03 + 0.02 * k, (-3.6, 0.785, -2.8 + k * 0.05), seg=6)
