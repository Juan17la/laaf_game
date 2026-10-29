#!/usr/bin/env python3
"""Builds LAAF's PS2/SA-era assets: models/*.glb and maps/hollowmere.tscn.

Stdlib only (no Blender). Textures are 64-128px procedural PNGs embedded in each .glb.
Architecture is flat-shaded boxes, organic/rounded parts use the smooth lathe/loft primitives;
most models live in the tools/models_*.py packs. glTF nodes named "<x>-col" get trimesh collision
from Godot's scene importer.

    python3 tools/build_assets.py

Re-running overwrites models/ and maps/hollowmere.tscn: hand edits there are lost,
change this script instead.
"""
import json
import math
import os
import random
import struct
import unicodedata
import zlib
from contextlib import contextmanager

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 64  # texture size (PS2-era budget)


# ============================================================== textures

def png(rows, alpha, size=S):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    head = struct.pack(">IIBBBBB", size, size, 8, 6 if alpha else 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", head) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def value_noise(rng, cells, size=S):
    g = [[rng.random() for _ in range(cells)] for _ in range(cells)]
    out = []
    for y in range(size):
        fy = y * cells / size
        y0 = int(fy)
        ty = fy - y0
        ty = ty * ty * (3 - 2 * ty)
        y1 = (y0 + 1) % cells
        row = []
        for x in range(size):
            fx = x * cells / size
            x0 = int(fx)
            tx = fx - x0
            tx = tx * tx * (3 - 2 * tx)
            x1 = (x0 + 1) % cells
            a = g[y0][x0] + (g[y0][x1] - g[y0][x0]) * tx
            b = g[y1][x0] + (g[y1][x1] - g[y1][x0]) * tx
            row.append(a + (b - a) * ty)
        out.append(row)
    return out


def fbm(rng, size=S):
    layers = [(value_noise(rng, c, size), w) for c, w in ((4, 0.5), (8, 0.25), (16, 0.15), (32, 0.1))]
    return [[sum(n[y][x] * w for n, w in layers) for x in range(size)] for y in range(size)]


def mix(c1, c2, t):
    return tuple(p + (q - p) * t for p, q in zip(c1, c2))


def mul(c, k):
    return tuple(v * k for v in c)


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def t_asphalt(x, y, a, b, r):
    v = 0.2 + 0.13 * a + 0.05 * r
    if b > 0.7:
        v *= 0.8  # tar patches
    return mul((v, v, v * 1.03), 0.5 if abs(b - 0.5) < 0.015 else 1)


def t_sidewalk(x, y, a, b, r):
    if x % 32 == 0 or y % 32 == 0:
        return (0.2, 0.25, 0.14) if a > 0.62 else (0.24, 0.24, 0.23)  # joints, weeds
    v = 0.44 + 0.2 * a + 0.04 * r
    if abs(b - 0.45) < 0.012:
        v *= 0.55  # cracks
    return (v, v * 0.98, v * 0.94)


def t_roadline(x, y, a, b, r):
    if b > 0.6 or r < 0.1:
        return (0.22, 0.22, 0.22)  # worn through to asphalt
    v = 0.6 + 0.3 * a
    return (v, v, v)


def t_concrete(x, y, a, b, r):
    v = 0.42 + 0.2 * a + 0.05 * r
    if b > 0.62:
        v *= 0.72
    if x % 32 == 0 or y % 32 == 0:
        v *= 0.75
    return (v, v * 0.98, v * 0.93)


def t_brick(x, y, a, b, r):
    off = 8 if (y // 8) % 2 else 0
    if y % 8 == 0 or (x + off) % 16 == 0:
        return mul((0.4, 0.38, 0.35), 0.8 + 0.3 * a)
    return mul((0.4, 0.16, 0.11), 0.65 + 0.5 * a + 0.1 * r - (0.25 if b > 0.64 else 0))


def t_planks(x, y, a, b, r):
    if x % 16 == 0:
        return (0.08, 0.06, 0.04)
    g = 0.5 + 0.5 * math.sin(y * 0.35 + a * 9 + (x // 16) * 2)
    return mul((0.34, 0.24, 0.15), 0.6 + 0.3 * a + 0.15 * g + 0.05 * r)


def t_burnt(x, y, a, b, r):
    return mix(t_planks(x, y, a, b, r), (0.03, 0.03, 0.03), min(1.0, max(0.3, (b - 0.3) * 3)))


def t_siding(x, y, a, b, r):
    if y % 8 == 7:
        return mul((0.2, 0.2, 0.18), 0.8 + 0.3 * a)
    if b > 0.66:
        return t_planks(x, y, a, b, r)  # peeled paint
    return mul((0.62, 0.6, 0.54), 0.7 + 0.35 * a + 0.04 * r)


def t_roof(x, y, a, b, r):
    off = 4 if (y // 8) % 2 else 0
    if y % 8 == 7 or (x + off) % 8 == 0:
        return (0.06, 0.06, 0.07)
    return mul((0.2, 0.19, 0.2), 0.6 + 0.6 * a + 0.1 * r)


def t_grass(x, y, a, b, r):
    c = mix((0.22, 0.2, 0.12), (0.3, 0.29, 0.18), a)
    if b > 0.6:
        c = mix(c, (0.2, 0.16, 0.1), 0.6)
    return mul(c, 1.25 if r > 0.85 else 0.85 + 0.2 * r)


def t_forest(x, y, a, b, r):
    c = mix((0.13, 0.1, 0.07), (0.24, 0.18, 0.1), a)
    return (0.3, 0.22, 0.12) if r > 0.92 else c


def t_mud(x, y, a, b, r):
    return mul((0.2, 0.16, 0.11), 0.6 + 0.6 * a + 0.1 * r)


def t_gravel(x, y, a, b, r):
    v = 0.25 + 0.35 * r * (0.5 + a)
    return (v, v * 0.96, v * 0.9)


def t_rock(x, y, a, b, r):
    c = mul((0.34, 0.33, 0.31), 0.45 + 0.8 * a + 0.05 * r)
    return mul(c, 0.4) if abs(b - 0.5) < 0.02 else c


def t_bark(x, y, a, b, r):
    v = 0.5 + 0.5 * math.sin(x * 1.3 + a * 7)
    return mul((0.2, 0.15, 0.1), 0.55 + 0.45 * v + 0.1 * r)


def t_pine(x, y, a, b, r):
    return mul((0.07, 0.13, 0.08), 0.5 + 0.9 * a + 0.3 * r)


def t_metal(x, y, a, b, r):
    return mul((0.36, 0.37, 0.38), 0.65 + 0.4 * a + 0.05 * r)


def t_rust(x, y, a, b, r):
    return mix(t_metal(x, y, a, b, r), mul((0.38, 0.18, 0.08), 0.6 + 0.6 * a), min(1.0, max(0.0, (b - 0.4) * 4)))


def t_tile(x, y, a, b, r):
    if x % 16 == 0 or y % 16 == 0:
        return (0.35, 0.35, 0.33)
    c = mul((0.76, 0.77, 0.73), 0.8 + 0.2 * a)
    return mix(c, (0.4, 0.36, 0.2), 0.5) if b > 0.58 else c


def t_paint(x, y, a, b, r):
    c = mul((0.68, 0.68, 0.64), 0.7 + 0.3 * a)
    return mix(c, (0.3, 0.26, 0.2), 0.5) if b > 0.6 else c


def t_stone(x, y, a, b, r):
    off = 8 if (y // 8) % 2 else 0
    if y % 8 == 0 or (x + off) % 16 == 0:
        return (0.2, 0.2, 0.19)
    return mul((0.46, 0.45, 0.42), 0.55 + 0.5 * a + 0.05 * r)


def t_water(x, y, a, b, r):
    return mul((0.05, 0.07, 0.08), 0.7 + 0.6 * a)


def t_flagstone(x, y, a, b, r):
    """Old park paving: offset flags, mossy joints, cracks, moss creeping over."""
    off = 8 if (y // 16) % 2 else 0
    if y % 16 == 0 or (x + off) % 16 == 0:
        return (0.12, 0.16, 0.08) if a > 0.55 else (0.15, 0.15, 0.14)
    v = 0.36 + 0.18 * a + 0.04 * r - (0.07 if ((x + off) // 16 + y // 16) % 3 == 0 else 0)
    if abs(b - 0.5) < 0.014:
        v *= 0.5
    c = (v, v * 0.97, v * 0.9)
    return mix(c, (0.18, 0.22, 0.12), 0.45) if b > 0.7 else c


def _window(x, y, a, pane):
    if x < 4 or x > 59 or y < 4 or y > 59 or x in (31, 32) or y in (31, 32):
        return mul((0.3, 0.28, 0.25), 0.8 + 0.3 * a)
    return mul(pane, 0.6 + 0.6 * a)


def t_window(x, y, a, b, r):
    return _window(x, y, a, (0.05, 0.06, 0.07))


def t_window_lit(x, y, a, b, r):
    return _window(x, y, a, (1.0, 0.72, 0.38))


def t_stained(x, y, a, b, r):
    if x % 8 == 0 or y % 8 == 0:
        return (0.03, 0.03, 0.03)
    k = ((x // 8) * 7 + (y // 8) * 13) % 4
    return mul([(0.6, 0.1, 0.1), (0.1, 0.15, 0.5), (0.6, 0.45, 0.1), (0.1, 0.4, 0.2)][k], 0.6 + 0.6 * a)


def t_door(x, y, a, b, r):
    if (x - 50) ** 2 + (y - 34) ** 2 < 6:
        return (0.5, 0.45, 0.3)
    c = mul((0.3, 0.2, 0.13), 0.6 + 0.4 * a + 0.05 * r)
    frame = x < 3 or x > 60 or y < 3
    panel = (8 < x < 28 or 36 < x < 56) and (8 < y < 28 or 36 < y < 58)
    return mul(c, 0.6) if frame else mul(c, 0.8) if panel else c


def t_fabric(x, y, a, b, r):
    c = (0.42, 0.12, 0.1) if (x // 8) % 2 else (0.55, 0.5, 0.42)
    return mul(c, (0.55 + 0.5 * a) * (0.3 if b > 0.65 else 1))


def t_plain(x, y, a, b, r):
    v = 0.82 + 0.18 * a + 0.04 * r
    return (v, v, v)


def t_lantern(x, y, a, b, r):
    c = mul((0.55, 0.36, 0.18), 0.6 + 0.5 * a)
    return mul(c, 0.25) if b > 0.55 else c


def t_screen(x, y, a, b, r):
    if y % 3 == 0:
        return (0.02, 0.05, 0.03)
    return mul((0.2, 0.8, 0.4), 0.3 + 0.7 * (1 if (x // 8 + y // 8) % 3 == 0 else a))


def t_moth(x, y, a, b, r):
    dx, dy = abs(x - 32), y - 32
    wing = ((dx - 13) / 13) ** 2 + ((dy + 5) / 11) ** 2 < 1 or ((dx - 9) / 8) ** 2 + ((dy - 10) / 8) ** 2 < 1
    body = dx < 2.5 and abs(dy) < 15
    drip = x % 7 == 3 and 0 < dy < 12 + 14 * b and ((dx - 13) / 13) ** 2 < 1
    on = (wing or body or drip) and r > 0.08
    return (0.86 * (0.8 + 0.2 * a), 0.83 * (0.8 + 0.2 * a), 0.7, 1.0 if on else 0.0)


def t_eye(x, y, a, b, r):
    dx, dy = (x - 32) / 28, (y - 32) / 16
    lid = 1 - dx * dx
    ring = lid > 0 and abs(dy) < lid and not (abs(dy) < lid - 0.3 and abs(dx) < 0.88)
    pupil = (x - 32) ** 2 + (y - 32) ** 2 < 49
    drip = x % 9 == 3 and lid > 0 and 32 < y < 32 + 16 * lid + 12 * b
    on = (ring or pupil or drip) and r > 0.06
    return (0.45 * (0.7 + 0.3 * a), 0.04, 0.03, 1.0 if on else 0.0)


def t_drawing(x, y, a, b, r):
    lines = [(32, 27, 32, 44), (22, 33, 42, 33), (32, 44, 24, 56), (32, 44, 40, 56)]
    if abs(math.hypot(x - 32, y - 20) - 7) < 1.5 or any(seg_dist(x, y, *s) < 1.4 for s in lines):
        return (0.6, 0.1, 0.1)
    if math.hypot(x - 54, y - 9) < 6:
        return (0.8, 0.6, 0.1)
    if y > 59 and x % 3:
        return (0.2, 0.45, 0.15)
    return mul((0.85, 0.83, 0.76), 0.85 + 0.15 * a)


TEXTURES = {k[2:]: v for k, v in globals().items() if k.startswith("t_")}
ALPHA_TEX = {"moth", "eye"}
TEX_SIZE = {}  # texture name -> size in px (default S); faces use 256
HEIGHT = {}  # texture name -> fn(x, y, a, b, r) -> relief (any scale); default: the colour's luminance
BUMPED = set()  # textures some bumped material uses (only these keep a relief field)
_tex_cache = {}
_height_cache = {}


def texture_png(name):
    if name not in _tex_cache:
        rng = random.Random(name)
        size = TEX_SIZE.get(name, S)
        n1, n2 = fbm(rng, size), fbm(rng, size)
        fn, alpha, hfn = TEXTURES[name], name in ALPHA_TEX, HEIGHT.get(name)
        keep = name in BUMPED
        rows, hts = [], []
        for y in range(size):
            row, hrow = [], []
            for x in range(size):
                a, b, r = n1[y][x], n2[y][x], rng.random()
                px = fn(x, y, a, b, r)
                row += [max(0, min(255, int(v * 255))) for v in (px if alpha else px[:3])]
                if keep:
                    hrow.append(hfn(x, y, a, b, r) if hfn else 0.3 * px[0] + 0.59 * px[1] + 0.11 * px[2])
            rows.append(row)
            hts.append(hrow)
        _tex_cache[name] = png(rows, alpha, size)
        _height_cache[name] = hts
    return _tex_cache[name]


def normal_png(name, strength):
    """Tangent-space normal map (OpenGL +Y up) from a texture's relief; tiles seamlessly. strength ~ px height gain."""
    texture_png(name)
    h = _height_cache[name]
    size = len(h)
    rows = []
    for y in range(size):
        up, dn, row = h[(y - 1) % size], h[(y + 1) % size], []
        for x in range(size):
            dx = (h[y][(x + 1) % size] - h[y][x - 1]) * strength
            dy = (up[x] - dn[x]) * strength
            ln = math.sqrt(dx * dx + dy * dy + 1.0)
            row += [int((-dx / ln * 0.5 + 0.5) * 255), int((dy / ln * 0.5 + 0.5) * 255), int((1 / ln * 0.5 + 0.5) * 255)]
        rows.append(row)
    return png(rows, False, size)


# ============================================================== materials

def M(tex, color=(1, 1, 1), scale=2.0, fit=False, emit=0.0, rough=1.0, bump=0.0, wrinkle=0.0):
    """bump: normal-map strength from the texture's relief (0 = none). wrinkle: cloth-fold displacement in metres
    (surface() subdivides and bulges the mesh, so creases show in silhouette, light and baked occlusion)."""
    if bump:
        BUMPED.add(tex)
    return dict(tex=tex, color=color, scale=scale, fit=fit, emit=emit, rough=rough, alpha=tex in ALPHA_TEX,
                bump=bump, wrinkle=wrinkle)


def _hash(n):
    return (n * 2654435761 % 4294967296) / 4294967296.0


# cloth structure at texel scale -> relief 0..1 (period >= 3 px, so the normal map's central differences see it).
# A texel is ~2-5 mm here, coarser than real thread, so the relief is fibrous noise with only a hint of pattern.
WEAVES = {
    "twill": lambda x, y, r: 0.2 * ((x + y) % 4 < 2) + 0.1 * _hash(x * 7 + 3) + 0.5 * r,  # denim, canvas
    "plain": lambda x, y, r: 0.1 * ((x // 2 + y // 2) % 2) + 0.06 * (_hash(x // 2) + _hash(y // 2 + 999)) + 0.5 * r,
    "knit": lambda x, y, r: 0.3 * abs(math.sin((x + 0.5) * math.pi / 3)) + 0.2 * _hash(x * 5 + y // 3) + 0.4 * r,
    "felt": lambda x, y, r: 0.6 * r + 0.3 * _hash(x * 31 + y * 17),  # wool coats: fuzzy, no thread lines
    "nylon": lambda x, y, r: 0.2 * r + 0.15 * _hash(x // 3 * 13 + y // 3 * 7),  # smooth coated shell
    "leather": lambda x, y, r: 0.45 * r + 0.3 * _hash((x // 3) * 13 + (y // 3) * 7),  # pebbled grain
}


def fabric(kind, *mats, bump=0.8, wrinkle=0.004, damp=0.45):
    """Make painted cloth materials read as real fabric: the texture is resampled at twice the resolution with
    its blotchy low-frequency shading damped, the weave `kind` (WEAVES) is woven into colour and relief (normal
    map), and tiling (non-fit) materials get geometric folds. Stains, seams and patterns of the base survive."""
    for name in mats:
        m = MATS[name]
        tex = m["tex"]
        if tex not in HEIGHT:
            base, wv = TEXTURES[tex], WEAVES[kind]
            TEXTURES[tex] = lambda x, y, a, b, r, base=base, wv=wv: \
                mul(base(x // 2, y // 2, 0.5 + damp * (a - 0.5), b, r), 0.96 + 0.07 * wv(x, y, r))
            HEIGHT[tex] = lambda x, y, a, b, r, wv=wv: wv(x, y, r) + 0.6 * a
            TEX_SIZE[tex] = min(256, 2 * TEX_SIZE.get(tex, S))
        BUMPED.add(tex)
        m["bump"] = bump
        if not m["fit"] and wrinkle:
            m["wrinkle"] = wrinkle


MATS = {
    "asphalt": M("asphalt", scale=4), "concrete": M("concrete", scale=4),
    "sidewalk": M("sidewalk", scale=2), "curb": M("concrete", (0.85, 0.85, 0.8), 2),
    "line_yellow": M("roadline", (0.85, 0.68, 0.3), 3), "line_white": M("roadline", (0.75, 0.75, 0.72), 3), "brick": M("brick"),
    "planks": M("planks"), "burnt": M("burnt"), "siding": M("siding"),
    "siding_blue": M("siding", (0.7, 0.82, 1.0)), "siding_green": M("siding", (0.72, 0.9, 0.72)),
    "roof": M("roof"), "grass": M("grass", scale=4), "forest": M("forest", scale=4), "mud": M("mud", scale=4),
    "gravel": M("gravel", scale=3), "rock": M("rock", scale=6), "bark": M("bark", scale=1.5),
    "pine": M("pine"), "metal": M("metal"), "rust": M("rust"), "tile": M("tile"), "paint": M("paint", scale=3),
    "stone": M("stone"), "water": M("water", scale=8, rough=0.15),
    "window": M("window", fit=True), "window_lit": M("window_lit", fit=True, emit=1.8),
    "stained": M("stained", fit=True, emit=0.8), "door": M("door", fit=True),
    "fabric": M("fabric"), "lantern": M("lantern", scale=0.5), "screen": M("screen", fit=True, emit=1.2),
    "moth": M("moth", fit=True), "eye": M("eye", fit=True), "drawing": M("drawing", fit=True),
    "iron": M("plain", (0.08, 0.08, 0.09), 1), "jacket": M("plain", (0.26, 0.2, 0.14), 1),
    "jeans": M("plain", (0.14, 0.17, 0.24), 1), "skin": M("plain", (0.62, 0.47, 0.38), 1),
    "hair": M("plain", (0.07, 0.05, 0.04), 1), "shoe": M("plain", (0.06, 0.06, 0.06), 1),
    "white": M("plain", (0.7, 0.7, 0.68), 1), "red": M("plain", (0.35, 0.06, 0.05), 1),
    "rubber": M("plain", (0.05, 0.05, 0.05), 1), "glass": M("plain", (0.04, 0.05, 0.06), 1, rough=0.2),
    "sheet": M("plain", (0.55, 0.53, 0.48), 1), "mannequin": M("plain", (0.75, 0.7, 0.62), 1),
    "locker": M("metal", (0.45, 0.55, 0.7)),
    "bulb": M("plain", (1.0, 0.8, 0.5), 1, emit=3.0), "bulb_cold": M("plain", (0.6, 0.75, 1.0), 1, emit=3.0),
    "bulb_red": M("plain", (1.0, 0.15, 0.1), 1, emit=3.0), "lamp_glass": M("plain", (1.0, 0.95, 0.8), 1, emit=4.0),
}
MATS["flagstone"] = M("flagstone", scale=3)  # Hollowmere Memorial Park paving (town square)


# ============================================================== geometry

def v_add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def v_sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def v_dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def v_cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def v_norm(a):
    ln = math.sqrt(v_dot(a, a)) or 1.0
    return (a[0] / ln, a[1] / ln, a[2] / ln)


def m_mul(A, B): return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
def m_vec(A, v): return tuple(A[i][0] * v[0] + A[i][1] * v[1] + A[i][2] * v[2] for i in range(3))


def rot3(rx, ry, rz):
    """Degrees; applied Z, then X, then Y (yaw last)."""
    cx, sx = math.cos(math.radians(rx)), math.sin(math.radians(rx))
    cy, sy = math.cos(math.radians(ry)), math.sin(math.radians(ry))
    cz, sz = math.cos(math.radians(rz)), math.sin(math.radians(rz))
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return m_mul(m_mul(Ry, Rx), Rz)


def newell(pts):
    n = [0.0, 0.0, 0.0]
    for i, p in enumerate(pts):
        q = pts[(i + 1) % len(pts)]
        n[0] += (p[1] - q[1]) * (p[2] + q[2])
        n[1] += (p[2] - q[2]) * (p[0] + q[0])
        n[2] += (p[0] - q[0]) * (p[1] + q[1])
    return tuple(n)


def face_uvs(pts, n, mat):
    u = (1.0, 0.0, 0.0) if abs(n[1]) > 0.9 else v_norm(v_cross((0, 1, 0), n))
    v = v_cross(n, u)
    P = [(v_dot(p, u), v_dot(p, v)) for p in pts]
    if mat["fit"]:
        u0, u1 = min(p[0] for p in P), max(p[0] for p in P)
        v0, v1 = min(p[1] for p in P), max(p[1] for p in P)
        return [((a - u0) / ((u1 - u0) or 1), 1 - (b - v0) / ((v1 - v0) or 1)) for a, b in P]
    s = mat["scale"]
    return [(a / s, -b / s) for a, b in P]


# ---- grid helpers for surface(): smooth normals, Catmull-Rom subdivision, cloth folds

FOLD_STEP = 0.04  # target quad size (m) of wrinkled cloth


def grid_normals(W, cols):
    """Area-weighted smooth vertex normals of a quad grid + the list of non-degenerate quads."""
    R, C = len(W), len(W[0])
    acc = [[[0.0, 0.0, 0.0] for _ in range(C)] for _ in range(R)]
    quads = []
    for i in range(R - 1):
        for j in range(cols):
            k = (j + 1) % C
            q = ((i, j), (i, k), (i + 1, k), (i + 1, j))
            n = newell([W[a][b] for a, b in q])
            if v_dot(n, n) < 1e-14:
                continue
            quads.append((i, j))
            for a, b in q:
                s = acc[a][b]
                s[0] += n[0]; s[1] += n[1]; s[2] += n[2]
    return [[v_norm(tuple(s)) for s in row] for row in acc], quads


def _cr(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return tuple(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (3 * (b - c) + d - a) * t3)
                 for a, b, c, d in zip(p0, p1, p2, p3))


def _lerp(p, q, t):
    return tuple(a + (b - a) * t for a, b in zip(p, q))


def refine_grid(grid, wrap, step):
    """Subdivide a quad grid with Catmull-Rom splines until cells are about `step` metres (segments with
    a sharp turn, like a collar edge or hem, stay linear so nothing overshoots)."""
    R, C = len(grid), len(grid[0])
    mid = C // 2

    def sharp(ps):  # polyline p0..p3 bends hard at p1 or p2
        vs = [v_norm(v_sub(b, a)) for a, b in zip(ps, ps[1:])]
        return v_dot(vs[0], vs[1]) < 0.75 or v_dot(vs[1], vs[2]) < 0.75

    rows = []
    for i in range(R - 1):
        ln = sum(math.dist(grid[i][j], grid[i + 1][j]) for j in range(0, C, max(1, C // 6))) / len(range(0, C, max(1, C // 6)))
        k = max(1, min(4, math.ceil(ln / step - 0.2)))
        a, b = grid[max(i - 1, 0)], grid[i]
        c, d = grid[i + 1], grid[min(i + 2, R - 1)]
        lin = sharp((a[mid], b[mid], c[mid], d[mid])) if ln > 1e-6 else True
        for s_ in range(k):
            t = s_ / k
            rows.append(b if s_ == 0 else [_lerp(q, r, t) for q, r in zip(b, c)] if lin else
                        [_cr(pa, pb, pc, pd, t) for pa, pb, pc, pd in zip(a, b, c, d)])
    rows.append(grid[-1])
    big = [r for r in rows if max(math.dist(r[0], p) for p in r) > 0.02] or rows
    ln = sum(math.dist(r[j], r[(j + 1) % C]) for r in big for j in range(C - (0 if wrap else 1))) / (len(big) * (C if wrap else C - 1))
    kc = max(1, min(3, math.ceil(ln / step - 0.2)))
    if kc == 1:
        return rows
    out = []
    for row in rows:
        new = []
        for j in range(C if wrap else C - 1):
            ix = lambda n: row[n % C] if wrap else row[min(max(n, 0), C - 1)]
            a, b, c, d = ix(j - 1), ix(j), ix(j + 1), ix(j + 2)
            lin = sharp((a, b, c, d)) if math.dist(b, c) > 1e-6 else True
            for s_ in range(kc):
                new.append(b if s_ == 0 else _lerp(b, c, s_ / kc) if lin else _cr(a, b, c, d, s_ / kc))
        if not wrap:
            new.append(row[-1])
        out.append(new)
    return out


def fold_grid(W, N, amp, seed):
    """Push cloth vertices along their normals by a crease field: gathered horizontal folds, diagonal pulls and
    vertical drape lines, in patches (not rings everywhere). seed varies it per node and material."""
    ph = (seed % 6283) / 1000.0
    out = []
    for row, nrow in zip(W, N):
        cx = [sum(p[i] for p in row) / len(row) for i in range(3)]
        k = min(1.0, max(math.dist(cx, p) for p in row) / 0.035)  # rings pinching to a pole stay closed
        o = []
        for p, n in zip(row, nrow):
            x, y, z = p
            w = math.sin(x * 23 + z * 19 + y * 7 + ph)
            f = 0.45 * math.sin(y * 47 + 1.7 * w + ph) + 0.3 * math.sin((y * 0.6 + x * 0.8) * 61 + 2.0 * w + 1.3 + ph * 2) \
                + 0.25 * math.sin(x * 53 - z * 41 + y * 9 + 3.0 * w - ph)
            patch = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(x * 9 + z * 7 + y * 12 + ph * 3))
            h = amp * k * patch * (f - 0.1)
            o.append((x + n[0] * h, y + n[1] * h, z + n[2] * h))
        out.append(o)
    return out


class Model:
    def __init__(self, name):
        self.name = name
        self.smooth = False  # trilinear textures instead of PS1-style nearest (characters)
        self.ao = False  # bake ambient occlusion into vertex colours when written (characters)
        self.nodes = []
        self.stack = [([[1, 0, 0], [0, 1, 0], [0, 0, 1]], (0.0, 0.0, 0.0))]

    def node(self, name, parent=None, t=(0, 0, 0)):
        self.nodes.append({"name": name, "parent": parent, "t": t, "prims": {}})
        self.cur = self.nodes[-1]
        return self

    def use(self, name):
        """Select an existing node; following geometry is added to it (node-local coords)."""
        self.cur = next(nd for nd in self.nodes if nd["name"] == name)
        return self

    @contextmanager
    def push(self, pos=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
        Mx, t = self.stack[-1]
        R = rot3(*rot)
        L = [[R[i][j] * scale[j] for j in range(3)] for i in range(3)]
        self.stack.append((m_mul(Mx, L), v_add(m_vec(Mx, pos), t)))
        try:
            yield
        finally:
            self.stack.pop()

    def emit(self, mat, pts, center=None):
        """Flat-shaded polygon. With `center`, winding is fixed to face away from it."""
        pts = [p for i, p in enumerate(pts) if p != pts[i - 1]]
        if len(pts) < 3:
            return
        if center is not None:
            c = tuple(sum(p[i] for p in pts) / len(pts) for i in range(3))
            if v_dot(newell(pts), v_sub(c, center)) < 0:
                pts = pts[::-1]
        Mx, t = self.stack[-1]
        pts = [v_add(m_vec(Mx, p), t) for p in pts]
        n = newell(pts)
        if v_dot(n, n) < 1e-12:
            return
        n = v_norm(n)
        uvs = face_uvs(pts, n, MATS[mat])
        pos, nrm, uv = self.cur["prims"].setdefault(mat, ([], [], []))
        for i in range(1, len(pts) - 1):
            for k in (0, i, i + 1):
                pos.append(pts[k])
                nrm.append(n)
                uv.append(uvs[k])

    def box(self, mat, size, pos=(0, 0, 0), rot=(0, 0, 0), faces=None):
        """faces: optional per-face material override, keys "+x" "-x" "+y" "-y" "+z" "-z"."""
        h = (size[0] / 2, size[1] / 2, size[2] / 2)
        with self.push(pos, rot):
            for axis in range(3):
                a1, a2 = (axis + 1) % 3, (axis + 2) % 3
                for sgn in (-1, 1):
                    pts = []
                    for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                        p = [0.0, 0.0, 0.0]
                        p[axis], p[a1], p[a2] = sgn * h[axis], u * h[a1], v * h[a2]
                        pts.append(tuple(p))
                    key = ("+" if sgn > 0 else "-") + "xyz"[axis]
                    self.emit((faces or {}).get(key, mat), pts, (0, 0, 0))

    def tbox(self, mat, bot, top, h, pos=(0, 0, 0), rot=(0, 0, 0), faces=None, shift=(0.0, 0.0)):
        """Tapered box (frustum): bot=(w, d) at local y=0, top=(w, d) at y=h, top offset by shift=(x, z).
        Limbs hanging from a joint: pos=(0, -length, 0). faces: same keys as box()."""
        bw, bd, tw, td = bot[0] / 2, bot[1] / 2, top[0] / 2, top[1] / 2
        sx, sz = shift
        B = [(-bw, 0, -bd), (bw, 0, -bd), (bw, 0, bd), (-bw, 0, bd)]
        T = [(sx - tw, h, sz - td), (sx + tw, h, sz - td), (sx + tw, h, sz + td), (sx - tw, h, sz + td)]
        c = (sx / 2, h / 2, sz / 2)
        f = faces or {}
        with self.push(pos, rot):
            self.emit(f.get("-z", mat), [B[0], B[1], T[1], T[0]], c)
            self.emit(f.get("+x", mat), [B[1], B[2], T[2], T[1]], c)
            self.emit(f.get("+z", mat), [B[2], B[3], T[3], T[2]], c)
            self.emit(f.get("-x", mat), [B[3], B[0], T[0], T[3]], c)
            self.emit(f.get("-y", mat), B, c)
            self.emit(f.get("+y", mat), T, c)

    def cyl(self, mat, r1, r2, h, pos=(0, 0, 0), rot=(0, 0, 0), seg=8, caps=True, phase=0.0):
        with self.push(pos, rot):
            ring = lambda r, y: [(r * math.cos(2 * math.pi * (i + phase) / seg), y,
                                  r * math.sin(2 * math.pi * (i + phase) / seg)) for i in range(seg)]
            b, t, c = ring(r1, 0.0), ring(r2, h), (0, h / 2, 0)
            for i in range(seg):
                j = (i + 1) % seg
                self.emit(mat, [b[i], b[j], t[j], t[i]], c)
            if caps:
                self.emit(mat, b, c)
                self.emit(mat, t, c)

    def gable(self, mat, w, d, h, pos=(0, 0, 0), rot=(0, 0, 0), end=None):
        """Roof prism, ridge along Z."""
        x, z = w / 2, d / 2
        A, B, C, D = (-x, 0, -z), (x, 0, -z), (x, 0, z), (-x, 0, z)
        E, F = (0, h, -z), (0, h, z)
        c = (0, h / 3, 0)
        with self.push(pos, rot):
            self.emit(mat, [A, D, F, E], c)
            self.emit(mat, [B, E, F, C], c)
            self.emit(end or mat, [A, E, B], c)
            self.emit(end or mat, [D, C, F], c)
            self.emit(mat, [A, B, C, D], c)

    def rock(self, mat, r, h, pos=(0, 0, 0), rot=(0, 0, 0), rng=None, seg=7, rings=3, jit=0.3):
        rng = rng or random.Random(1)
        rows = []
        for k in range(rings + 1):
            y = h * k / rings + (rng.uniform(-jit, jit) * h / rings * 0.5 if k else 0)
            rr = r * (1 - 0.75 * (k / rings) ** 1.5)
            rows.append([(rr * (1 + rng.uniform(-jit, jit)) * math.cos(2 * math.pi * i / seg), y,
                          rr * (1 + rng.uniform(-jit, jit)) * math.sin(2 * math.pi * i / seg)) for i in range(seg)])
        top = (rng.uniform(-0.2, 0.2) * r, h * (1 + rng.uniform(0, 0.2)), rng.uniform(-0.2, 0.2) * r)
        with self.push(pos, rot):
            for k in range(rings):
                for i in range(seg):
                    j = (i + 1) % seg
                    a, b, c, d = rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i]
                    cy = (a[1] + c[1]) / 2
                    self.emit(mat, [a, b, c], (0, cy, 0))
                    self.emit(mat, [a, c, d], (0, cy, 0))
            for i in range(seg):
                self.emit(mat, [rows[-1][i], rows[-1][(i + 1) % seg], top], (0, h * 0.5, 0))
            self.emit(mat, rows[0], (0, h, 0))

    # ---- smooth-shaded primitives (organic shapes: bodies, heads, car panels, tree trunks)

    def surface(self, mat, grid, wrap=False, uv=None):
        """Smooth-shaded quad grid. grid: rows of local points; row k+1 sits "above" row k and each row
        runs counter-clockwise seen from above (lathe/loft already do this), so faces point outward.
        wrap closes every row into a ring. uv: None (spans by length / mat scale, or 0..1 for fit
        materials) or fn(local_point) -> (u, v), e.g. a planar front projection for painted faces.
        Materials with wrinkle > 0 (tiling cloth) are subdivided and bulged into folds first."""
        m = MATS[mat]
        folds = m.get("wrinkle", 0) and not (m["fit"] or uv)
        if folds:
            grid = refine_grid(grid, wrap, FOLD_STEP)
        Mx, t = self.stack[-1]
        W = [[v_add(m_vec(Mx, p), t) for p in row] for row in grid]
        R, C = len(W), len(W[0])
        cols = C if wrap else C - 1
        N, quads = grid_normals(W, cols)
        if uv:
            UV = [[uv(p) for p in row + row[:1]] for row in grid]
        elif m["fit"]:
            UV = [[(j / cols, 1 - i / (R - 1)) for j in range(C + 1)] for i in range(R)]
        else:
            s, us = m["scale"], [0.0]
            for j in range(C):
                us.append(us[-1] + math.dist(W[R // 2][j], W[R // 2][(j + 1) % C]) / s)
            vs = [0.0]
            for i in range(R - 1):
                vs.append(vs[-1] + math.dist(W[i][C // 2], W[i + 1][C // 2]) / s)
            UV = [[(us[j], -vs[i]) for j in range(C + 1)] for i in range(R)]
        if folds:
            W = fold_grid(W, N, m["wrinkle"], zlib.crc32(("%s/%s" % (self.cur["name"], mat)).encode()))
            N, quads = grid_normals(W, cols)
        pos, nrm, uvs = self.cur["prims"].setdefault(mat, ([], [], []))
        for i, j in quads:
            k = j + 1  # UV has one extra column so a wrapped ring's seam doesn't smear the texture
            q = ((i, j, j), (i, k % C, k), (i + 1, k % C, k), (i + 1, j, j))
            for tri in ((0, 1, 2), (0, 2, 3)):
                P = [W[q[t][0]][q[t][1]] for t in tri]
                cr = v_cross(v_sub(P[1], P[0]), v_sub(P[2], P[0]))
                if v_dot(cr, cr) < 1e-16:
                    continue
                for t in tri:
                    a, b, u = q[t]
                    pos.append(W[a][b])
                    nrm.append(N[a][b])
                    uvs.append(UV[a][u])

    def lathe(self, mat, profile, pos=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), seg=12, uv=None, phase=0.0):
        """Surface of revolution around local Y. profile: [(radius, y), ...] bottom to top; radius 0 closes
        a pole. scale=(sx, 1, sz) squashes the rings into ellipses (e.g. a flat chest, an oval skull)."""
        rows = [[(r * math.cos(-2 * math.pi * (j + phase) / seg), y, r * math.sin(-2 * math.pi * (j + phase) / seg))
                 for j in range(seg)] for r, y in profile]
        with self.push(pos, rot, scale):
            self.surface(mat, rows, wrap=True, uv=uv)

    def loft(self, mat, sections, pos=(0, 0, 0), rot=(0, 0, 0), seg=16, power=2.0, uv=None):
        """Smooth skin through superellipse rings. sections: [(y, rx, rz), ...] or (y, rx, rz, ox, oz) with a
        ring offset, bottom to top. power 2 = ellipse, 3-5 = rounded box (car bodies, jackets, buildings'
        soft edges). Rings of rx=rz=0 close the ends."""
        rows = []
        for sec in sections:
            y, rx, rz = sec[:3]
            ox, oz = sec[3:5] if len(sec) > 3 else (0.0, 0.0)
            row = []
            for j in range(seg):
                a = -2 * math.pi * j / seg
                c, s = math.cos(a), math.sin(a)
                row.append((ox + rx * math.copysign(abs(c) ** (2 / power), c), y,
                            oz + rz * math.copysign(abs(s) ** (2 / power), s)))
            rows.append(row)
        with self.push(pos, rot):
            self.surface(mat, rows, wrap=True, uv=uv)

    def ellipsoid(self, mat, radii, pos=(0, 0, 0), rot=(0, 0, 0), seg=12, rings=8, uv=None):
        """Smooth ellipsoid centred on pos. radii=(rx, ry, rz)."""
        prof = [(math.sin(math.pi * k / rings), -math.cos(math.pi * k / rings)) for k in range(rings + 1)]
        self.lathe(mat, prof, pos, rot, radii, seg, uv)

    def capsule(self, mat, r1, r2, length, pos=(0, 0, 0), rot=(0, 0, 0), seg=10, squash=(1.0, 1.0)):
        """Smooth limb hanging DOWN from pos: radius r1 at the top, r2 at the bottom, rounded ends.
        squash=(sx, sz) flattens the cross-section. Ideal for arm/leg segments on rig joints."""
        prof = [(0, -length - r2 * 0.9), (r2 * 0.6, -length - r2 * 0.7), (r2, -length),
                (r2 + (r1 - r2) * 0.35, -length * 0.62), (r1, -length * 0.2), (r1 * 0.85, 0), (r1 * 0.45, r1 * 0.55), (0, r1 * 0.7)]
        self.lathe(mat, prof, pos, rot, (squash[0], 1, squash[1]), seg)

    def decal(self, mat, w, h, pos=(0, 0, 0), rot=(0, 0, 0)):
        """Single quad facing local +Z."""
        with self.push(pos, rot):
            self.emit(mat, [(-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0)])

    def rect(self, mat, x0, z0, x1, z1, y):
        """Upward-facing ground quad."""
        self.emit(mat, [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], (0, y - 10, 0))


# ============================================================== baked occlusion

AO_RADIUS, AO_GAIN, AO_FLOOR = 0.14, 1.5, 0.3


def bake_ao(model, radius=None, gain=None, floor=None):
    """Per-vertex ambient occlusion in the rest pose -> {(node, mat): [(v, v, v), ...]} for COLOR_0.
    Point-based: every triangle is a small disc, a vertex is shadowed by discs that sit above its tangent
    plane and face it (disc-to-point form factor). Convex surfaces stay white; armpits, collars, folds,
    hat brims and sleeve cuffs darken. Segmented rigs bake their rest pose: it stays put when limbs swing."""
    radius, gain, floor = radius or AO_RADIUS, gain or AO_GAIN, AO_FLOOR if floor is None else floor
    off, by_name = {}, {nd["name"]: nd for nd in model.nodes}

    def offset(nd):
        if nd["name"] not in off:
            o = nd["t"] if nd["parent"] is None else v_add(offset(by_name[nd["parent"]]), nd["t"])
            off[nd["name"]] = tuple(o)
        return off[nd["name"]]

    cell = radius / 2
    grid = {}
    for nd in model.nodes:
        ox, oy, oz = offset(nd)
        for mat, (pos, _, _) in nd["prims"].items():
            if MATS[mat]["emit"]:
                continue  # lamps and eyes don't catch shadow
            for i in range(0, len(pos), 3):
                a, b, c = pos[i], pos[i + 1], pos[i + 2]
                n = v_cross(v_sub(b, a), v_sub(c, a))
                area2 = math.sqrt(v_dot(n, n))
                if area2 < 1e-9:
                    continue
                cx = (a[0] + b[0] + c[0]) / 3 + ox
                cy = (a[1] + b[1] + c[1]) / 3 + oy
                cz = (a[2] + b[2] + c[2]) / 3 + oz
                grid.setdefault((int(cx // cell), int(cy // cell), int(cz // cell)), []).append(
                    (cx, cy, cz, n[0] / area2, n[1] / area2, n[2] / area2, area2 / 2))
    reach = int(math.ceil(radius / cell)) + 0
    near = [(i, j, k) for i in range(-reach, reach + 1) for j in range(-reach, reach + 1) for k in range(-reach, reach + 1)
            if math.sqrt(max(0, abs(i) - 1) ** 2 + max(0, abs(j) - 1) ** 2 + max(0, abs(k) - 1) ** 2) * cell <= radius]
    r2, memo, out = radius * radius, {}, {}
    for nd in model.nodes:
        ox, oy, oz = offset(nd)
        for mat, (pos, nrm, _) in nd["prims"].items():
            col = []
            for p, n in zip(pos, nrm):
                key = (round(p[0], 4), round(p[1], 4), round(p[2], 4), round(n[0], 2), round(n[1], 2), round(n[2], 2))
                v = memo.get((nd["name"], key))
                if v is None:
                    px, py, pz = p[0] + ox + n[0] * 0.003, p[1] + oy + n[1] * 0.003, p[2] + oz + n[2] * 0.003
                    nx, ny, nz = n
                    ci, cj, ck = int(px // cell), int(py // cell), int(pz // cell)
                    occ = 0.0
                    for i, j, k in near:
                        for sx, sy, sz, tx, ty, tz, area in grid.get((ci + i, cj + j, ck + k), ()):
                            dx, dy, dz = sx - px, sy - py, sz - pz
                            d2 = dx * dx + dy * dy + dz * dz
                            if d2 > r2 or d2 < 1e-8:
                                continue
                            d = math.sqrt(d2)
                            cr = (nx * dx + ny * dy + nz * dz) / d
                            ce = -(tx * dx + ty * dy + tz * dz) / d
                            if cr > 0.1 and ce > 0.1:
                                f = 1 - d2 / r2
                                occ += area * cr * ce / (math.pi * d2 + area) * f * f
                    a = 1.0 - min(1.0, occ * gain)
                    v = memo[(nd["name"], key)] = (floor + (1 - floor) * a,) * 3
                col.append(v)
            out[(nd["name"], mat)] = col
    return out


# ============================================================== collision pass
# Godot turns a "-col" node into trimesh collision of its own mesh, so a model only blocks where its author put
# geometry in such a node. auto_collision() (every map model, before writing) closes the gaps found by
# tools/collision_audit.gd, all in one "auto-colonly" node:
#   box   a piece (connected triangles) of a visible-only node that the player can walk into and no collider covers:
#         a closed box around it (oriented to the piece, at least COL_THICK thick); one too big for a box (a rock
#         mass, a roof) gets a copy of its own triangles instead ("mesh")
#   slab  a collider piece thinner than COL_THIN (a door leaf, a floor, a sheet with no back side): a COL_THICK slab
#   back  an open collider surface (a quad, a lathe's tube: one-sided, so walkable from behind or from inside once
#         past it): its triangles again, facing the other way
#   group small pieces that touch (a stack of stock boxes, sacks, a woodpile, a stump and its axe) judged as one,
#         one box round them all
# "Covered" means inside the collision that is already there: a compact collider piece (a box, a cylinder) by its
# bounding box, a hollow one (a room's walls joined at the corners: its bounding box is the whole room) only where a
# point really is inside its solid (_Solids), so the furniture standing in a room is not taken for part of the walls.
# Foliage and decals (PASSABLE_TEX, PASSABLE_NODES) stay passable.

PASSABLE_TEX = {"moth", "eye", "ext_grasscard", "ext_leafcard", "hd_needles", "park_leafcard", "park_weedcard",
                "park_crack", "park_canopycard", "park_streak", "town_poster", "town_graffiti", "hs_crack"}
PASSABLE_NODES = ("needles", "branches", "leaves", "litter", "wires", "water", "smoke", "slabs", "AoFlags",
                  "ajar_leaves", "curtain_cloth")  # (interior_kit: open door leaves, bay curtains: never blocking)
COL_REACH = 2.0  # m over the floor under it: a piece starting higher is out of the player's reach
COL_MIN_H = 0.45  # m: pieces reaching no higher over the floor are stepped over / through (curbs, rubble, stone
#                   slabs); a piece hanging higher (a window AC unit at hip height) is walked into however thin it is
COL_MIN_FACE = 0.35  # m² of width x height for a piece to stop the player
COL_PROTRUDE = 0.15  # m a piece may stand proud of the colliders around it before it gets its own
COL_THIN = 0.12  # m: collider pieces thinner than this get a slab...
COL_THICK = 0.3  # ...this thick (sideways: centred; floors: downward, so the walked surface stays put), when the
COL_SHEET = 0.8  # piece is a sheet (both its larger sides at least this): smaller thin parts (a chair back, a sign)
COL_THIN_SMALL = 0.12  # only get this much, so furniture doesn't swell into the walkways
COL_GIANT = 40.0  # m³: a bigger loose piece is reported, not boxed (an OBB that big could plug a passage)
COL_COMPACT = 0.4  # a collider piece enclosing at least this fraction of its bounding box covers by that box
COL_REST = 0.3  # m: a piece with collision this close under it rests on it (it doesn't hang in the air)
COL_HEAD = 1.7  # m: a piece hanging higher than this is over Alex's head (an IV stand's hook bar): own height only
COL_TOUCH = 0.02  # m: small loose pieces closer than this form one group...
COL_GROUP_THIN = 0.05  # m: ...unless thinner than this (a rug, a board, a stair tread, a rail post: never a group)...
COL_GROUP_MAX = 2.6  # m: ...boxed only while no side of it is longer (a chain of trim along a facade is not a prop)
COL_GAP = 0.7  # m: ...and while no opening this wide runs through it over the walking band (a door's casing: two
COL_GAP_BAND = (0.3, 1.7)  # jambs and a header touch, but the doorway between them is walked through)


def _is_col(name):
    return name.endswith("-col") or name.endswith("-colonly")


def _node_offsets(model):
    by_name, off = {nd["name"]: nd for nd in model.nodes}, {}

    def get(nd):
        if nd["name"] not in off:
            p = by_name.get(nd["parent"]) if nd["parent"] else None
            off[nd["name"]] = v_add(get(p), tuple(nd["t"])) if p else tuple(nd["t"])
        return off[nd["name"]]
    for nd in model.nodes:
        get(nd)
    return off


def _pieces(nd, off):
    """Connected pieces of a node's triangles (sharing a corner, any material): [(tris, textures), ...] in model
    space, tris as (a, b, c) tuples."""
    tris, texs = [], []
    for mat, (pos, _, _) in nd["prims"].items():
        for i in range(0, len(pos) - 2, 3):
            tris.append(tuple(v_add(pos[i + k], off) for k in range(3)))
            texs.append(MATS[mat]["tex"])
    parent = list(range(len(tris)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    seen = {}
    for t, tri in enumerate(tris):
        for v in tri:
            key = (round(v[0] * 500), round(v[1] * 500), round(v[2] * 500))
            if key in seen:
                a, b = find(t), find(seen[key])
                if a != b:
                    parent[a] = b
            else:
                seen[key] = t
    groups = {}
    for t in range(len(tris)):
        g = groups.setdefault(find(t), ([], set()))
        g[0].append(tris[t])
        g[1].add(texs[t])
    return list(groups.values())


def _aabb(tris):
    pts = [v for tri in tris for v in tri]
    return tuple(min(p[i] for p in pts) for i in range(3)), tuple(max(p[i] for p in pts) for i in range(3))


def _obb(tris):
    """Oriented box around a piece: axes from its dominant face normals (exact for boxes, close for the rest), or
    the world axes when those hug it tighter. Returns (centre, [axis, ...], [half extent, ...])."""
    acc = {}
    for a, b, c in tris:
        n = v_cross(v_sub(b, a), v_sub(c, a))
        ln = math.sqrt(v_dot(n, n))
        if ln < 1e-9:
            continue
        n = tuple(x / ln for x in n)
        lead = next(x for x in n if abs(x) > 1e-6)
        if lead < 0:
            n = tuple(-x for x in n)
        key = tuple(round(x, 2) for x in n)
        acc[key] = (acc[key][0] + ln, n) if key in acc else (ln, n)
    normals = [n for _, n in sorted(acc.values(), reverse=True)]
    frames = [[(1, 0, 0), (0, 1, 0), (0, 0, 1)]]
    if normals:
        A = normals[0]
        B = next((n for n in normals[1:] if abs(v_dot(A, n)) < 0.1), None)
        if B is None:  # a flat (or round) piece: its longest edge across the normal
            a, b, c = max(tris, key=lambda t: max(math.dist(t[0], t[1]), math.dist(t[1], t[2])))
            B = v_sub(b, a) if math.dist(a, b) >= math.dist(b, c) else v_sub(c, b)
            if abs(v_dot(v_norm(B), A)) > 0.99:
                B = (0, 1, 0) if abs(A[1]) < 0.9 else (1, 0, 0)
        B = v_norm(v_sub(B, tuple(x * v_dot(A, B) for x in A)))
        frames.append([A, B, v_cross(A, B)])
    pts = [v for t in tris for v in t]
    best = None
    for ax in frames:
        lo = [min(v_dot(p, a) for p in pts) for a in ax]
        hi = [max(v_dot(p, a) for p in pts) for a in ax]
        vol = (hi[0] - lo[0] + 0.01) * (hi[1] - lo[1] + 0.01) * (hi[2] - lo[2] + 0.01)
        if best is None or vol < best[0] - 1e-9:
            mid = [(lo[i] + hi[i]) / 2 for i in range(3)]
            centre = tuple(sum(ax[i][k] * mid[i] for i in range(3)) for k in range(3))
            best = (vol, centre, ax, [(hi[i] - lo[i]) / 2 for i in range(3)])
    return best[1:]


def _open(tris):
    """True when some edge of the piece borders only one triangle (a sheet, a tube: not a closed solid)."""
    edges = {}
    for tri in tris:
        keys = [(round(v[0] * 500), round(v[1] * 500), round(v[2] * 500)) for v in tri]
        for i in range(3):
            e = tuple(sorted((keys[i], keys[(i + 1) % 3])))
            edges[e] = edges.get(e, 0) + 1
    return any(n == 1 for n in edges.values())


def _overlap(lo, hi, boxes):
    """Volume of (lo, hi) inside the union of boxes (summed: boxes rarely overlap each other much)."""
    total = 0.0
    for blo, bhi in boxes:
        d = [min(hi[i], bhi[i]) - max(lo[i], blo[i]) for i in range(3)]
        if min(d) > 0:
            total += d[0] * d[1] * d[2]
    return total


def _thick(h):
    """Collision thickness for a piece of half extents h: COL_THICK for a sheet, COL_THIN_SMALL for a small part."""
    return COL_THICK if sorted(h)[1] * 2 >= COL_SHEET else COL_THIN_SMALL


def _compact(tris):
    """A piece that covers by its bounding box: one box (even tilted: a stair's ramp covers its steps, as authored),
    or a piece enclosing most of that box (a cylinder), unlike a room's walls joined at the corners. Volume by the
    divergence theorem over the closed, outward-wound piece."""
    if len(tris) <= 12:
        return True
    lo, hi = _aabb(tris)
    vol = abs(sum(v_dot(a, v_cross(b, c)) for a, b, c in tris)) / 6.0
    return vol >= COL_COMPACT * math.prod(hi[i] - lo[i] + 0.01 for i in range(3))


def _touching(pieces):
    """Groups of 2+ pieces [(tris, lo, hi), ...] whose bounding boxes come within COL_TOUCH of each other:
    [(tris, lo, hi, [(member lo, member hi), ...]), ...] per group."""
    parent = list(range(len(pieces)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    grid = {}
    for i, (_, lo, hi) in enumerate(pieces):
        cells = [(gx, gy, gz) for gx in range(math.floor(lo[0] * 2), math.floor(hi[0] * 2) + 1)
                 for gy in range(math.floor(lo[1] * 2), math.floor(hi[1] * 2) + 1)
                 for gz in range(math.floor(lo[2] * 2), math.floor(hi[2] * 2) + 1)]
        near = {j for cell in cells for j in grid.get(cell, ())}
        for j in near:
            jlo, jhi = pieces[j][1], pieces[j][2]
            if all(lo[k] <= jhi[k] + COL_TOUCH and jlo[k] <= hi[k] + COL_TOUCH for k in range(3)):
                parent[find(i)] = find(j)
        for cell in cells:
            grid.setdefault(cell, []).append(i)
    groups = {}
    for i in range(len(pieces)):
        groups.setdefault(find(i), []).append(i)
    out = []
    for members in groups.values():
        if len(members) > 1:
            tris = [t for i in members for t in pieces[i][0]]
            out.append((tris,) + _aabb(tris) + ([pieces[i][1:] for i in members],))
    return out


def _passage(lo, hi, members):
    """A group with an opening the player walks through: seen along X or Z, the members standing in the walking
    band (COL_GAP_BAND over the group's foot) leave a gap of COL_GAP or more (a door casing's jambs either side of
    the doorway, a pergola's posts)."""
    y0, y1 = lo[1] + COL_GAP_BAND[0], lo[1] + COL_GAP_BAND[1]
    for k in (0, 2):
        spans = sorted((mlo[k], mhi[k]) for mlo, mhi in members if mlo[1] < y1 and mhi[1] > y0)
        edge = lo[k]
        for a, b in spans:
            if a - edge >= COL_GAP:
                return True
            edge = max(edge, b)
        if hi[k] - edge >= COL_GAP:
            return True
    return False


class _Solids:
    """Point-in-collider test for a model's collider triangles: straight up from a point inside a closed solid, the
    first face met is one of its top faces (facing up); from outside it is an underside, or nothing."""
    CELL = 1.0

    def __init__(self, tris):
        self.grid = {}
        for a, b, c in tris:
            n = v_cross(v_sub(b, a), v_sub(c, a))
            ln = math.sqrt(v_dot(n, n))
            if ln < 1e-9 or abs(n[1]) / ln < 1e-3:
                continue  # (a wall face: a vertical ray never crosses it)
            lo, hi = _aabb([(a, b, c)])
            for gx in range(math.floor(lo[0] / self.CELL), math.floor(hi[0] / self.CELL) + 1):
                for gz in range(math.floor(lo[2] / self.CELL), math.floor(hi[2] / self.CELL) + 1):
                    self.grid.setdefault((gx, gz), []).append((a, b, c, n[1] > 0))

    def inside(self, p):
        return self._first(p, 1)[1]

    def below(self, p):
        """Height of the first collider face straight under p, or None."""
        return self._first(p, -1)[0]

    def _first(self, p, way):
        """(height, facing up) of the first collider face met going straight up (way 1) or down (-1) from p."""
        best, up = None, False
        for a, b, c, facing_up in self.grid.get((math.floor(p[0] / self.CELL), math.floor(p[2] / self.CELL)), ()):
            # where the vertical line through p crosses the triangle (barycentric in XZ)
            d = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
            if abs(d) < 1e-12:
                continue
            w0 = ((b[2] - c[2]) * (p[0] - c[0]) + (c[0] - b[0]) * (p[2] - c[2])) / d
            w1 = ((c[2] - a[2]) * (p[0] - c[0]) + (a[0] - c[0]) * (p[2] - c[2])) / d
            w2 = 1.0 - w0 - w1
            if min(w0, w1, w2) < -1e-6:
                continue
            y = w0 * a[1] + w1 * b[1] + w2 * c[1]
            if (y - p[1]) * way > 0 and (best is None or (best - y) * way > 0):
                best, up = y, facing_up
        return best, up

    def fraction(self, lo, hi):
        """Share of a 3 x 2 x 3 grid of points in the box (lo, hi) that are inside a collider."""
        pts = [(lo[0] + (hi[0] - lo[0]) * fx, lo[1] + (hi[1] - lo[1]) * fy, lo[2] + (hi[2] - lo[2]) * fz)
               for fx in (0.17, 0.5, 0.83) for fy in (0.25, 0.75) for fz in (0.17, 0.5, 0.83)]
        return sum(1 for p in pts if self.inside(p)) / len(pts)


def auto_collision(model):
    """Adds the "auto-colonly" node (see the section comment). Returns a report: [(kind, piece box), ...]."""
    off = _node_offsets(model)
    col, loose = [], []
    for nd in model.nodes:
        if not nd["prims"] or nd["name"].startswith(PASSABLE_NODES):
            continue
        for tris, texs in _pieces(nd, off[nd["name"]]):
            if _is_col(nd["name"]):
                col.append(tris)
            elif not texs <= PASSABLE_TEX:  # (foliage, decals: passable)
                loose.append(tris)
    # floors the player can stand on (up-facing collider faces): reach is measured from the one under a piece
    area = {}
    for tris in col:
        for a, b, c in tris:
            n = v_cross(v_sub(b, a), v_sub(c, a))
            ln = math.sqrt(v_dot(n, n))
            if ln > 1e-9 and n[1] / ln > 0.9:
                area[round(a[1] * 20) / 20] = area.get(round(a[1] * 20) / 20, 0.0) + ln / 2
    floors = sorted({0.0} | {y for y, ar in area.items() if ar >= 3.0})  # (a wall top is no floor)
    grow = lambda lo, hi: (tuple(x - 0.05 for x in lo), tuple(x + 0.05 for x in hi))
    grown = [grow(*_aabb(t)) for t in col if _compact(t)]
    grown_all = [grow(*_aabb(t)) for t in col]  # (giant pieces: a foundation, a plinth round the walls)
    solids = _Solids([tri for t in col for tri in t])

    def ground(lo):
        return max((f for f in floors if f <= lo[1] + 0.1), default=lo[1])

    def reach(lo, hi, floor=False):
        return lo[1] - ground(lo) < COL_REACH and (floor or hi[1] > ground(lo) + 0.15)

    def big(lo, hi):
        """Walked into: reaching COL_MIN_H over its floor, with COL_MIN_FACE of width x height up to that. A piece
        resting on collision (a stair tread on its ramp, a TV on its dresser) only counts its own height."""
        under = solids.below(((lo[0] + hi[0]) / 2, lo[1] + 0.01, (lo[2] + hi[2]) / 2))
        rests = under is not None and lo[1] - under < COL_REST
        tall = hi[1] - lo[1]
        if not rests and lo[1] - ground(lo) <= COL_HEAD:
            tall = max(tall, hi[1] - ground(lo))
        return tall >= COL_MIN_H and max(hi[0] - lo[0], hi[2] - lo[2]) * min(tall, COL_REACH) >= COL_MIN_FACE \
            and reach(lo, hi)

    def covered(lo, hi, giant=False):
        """Stands within the model's colliders: its core (the allowed protrusion trimmed off the sides, never
        below 2 cm) mostly inside compact collider boxes, or inside the colliders' solid. A giant piece (a building's
        base) only has to be inside any collider's box, as it always did: it is no prop to walk into."""
        core_lo, core_hi = list(lo), list(hi)
        for i in (0, 2):
            cut = min(COL_PROTRUDE, max(hi[i] - lo[i] - 0.02, 0.0) / 2)
            core_lo[i] += cut
            core_hi[i] -= cut
        core_lo = [x - 0.01 for x in core_lo]
        core_hi = [x + 0.01 for x in core_hi]
        vol = (core_hi[0] - core_lo[0]) * (core_hi[1] - core_lo[1]) * (core_hi[2] - core_lo[2])
        if giant:
            return _overlap(core_lo, core_hi, grown_all) >= 0.5 * vol
        return _overlap(core_lo, core_hi, grown) >= 0.5 * vol or solids.fraction(core_lo, core_hi) >= 0.5

    boxes, copies, report = [], [], []

    def add(tris, lo, hi, kind="box"):
        c, ax, h = _obb(tris)
        if 8 * h[0] * h[1] * h[2] > COL_GIANT:
            copies.append((tris, True, _open(tris)))
            report.append(("mesh", (lo, hi)))
            return
        boxes.append((c, ax, [max(x, _thick(h) / 2) for x in h]))
        report.append((kind, (lo, hi)))

    small = []
    for tris in loose:
        lo, hi = _aabb(tris)
        if not big(lo, hi):
            if min(v_sub(hi, lo)) >= COL_GROUP_THIN:  # (a rug would join the suitcase on it, a tread its rail post)
                small.append((tris, lo, hi))
            continue
        c, ax, h = _obb(tris)
        if not covered(lo, hi, 8 * h[0] * h[1] * h[2] > COL_GIANT):
            add(tris, lo, hi)
    for tris, lo, hi, members in _touching(small):  # a stack of boxes, a stool's seat on its post...
        size = v_sub(hi, lo)
        if max(size) <= COL_GROUP_MAX and big(lo, hi) and not _passage(lo, hi, members) and not covered(lo, hi):
            add(tris, lo, hi, "group")
    if not col and not boxes and not copies and loose:  # a prop of thin parts (an IV stand): one box round it all
        tris = [t for p in loose for t in p]
        lo, hi = _aabb(tris)
        size = v_sub(hi, lo)
        if size[1] >= COL_MIN_H and max(size[0], size[2]) * min(size[1], COL_REACH) >= COL_MIN_FACE and reach(lo, hi):
            c, ax, h = _obb(tris)
            boxes.append((c, ax, [max(x, _thick(h) / 2) for x in h]))
            report.append(("box", (lo, hi)))
    for tris in col:
        lo, hi = _aabb(tris)
        c, ax, h = _obb(tris)
        thin = min(range(3), key=lambda i: h[i])
        n = ax[thin]
        level = abs(n[1]) > 0.7  # a floor / a shelf / a ramp
        if sorted(h)[1] * 2 < COL_MIN_H or not reach(lo, hi, level):
            continue
        if h[thin] * 2 >= COL_THIN:
            if _open(tris):
                copies.append((tris, False, True))
                report.append(("back", (lo, hi)))
            continue
        t = _thick(h)
        h = list(h)
        if level:  # thickened downward: its top stays where it's walked on
            up = 1 if n[1] > 0 else -1
            c = v_add(c, tuple(x * up * (h[thin] - t / 2) for x in n))
        h[thin] = t / 2
        boxes.append((c, ax, h))
        report.append(("slab", (lo, hi)))
    if boxes or copies:
        mat = next(iter(next(nd for nd in model.nodes if nd["prims"])["prims"]))  # (dropped on import: any will do)
        cur = model.cur
        model.node("auto-colonly")
        pos, nrm, uv = model.cur["prims"].setdefault(mat, ([], [], []))
        for tris, front, back in copies:  # a piece's own triangles: as they are and / or turned around
            for a, b, c in tris:
                for tri in ([(a, b, c)] if front else []) + ([(a, c, b)] if back else []):
                    n = v_norm(v_cross(v_sub(tri[1], tri[0]), v_sub(tri[2], tri[0])))
                    for v in tri:
                        pos.append(v)
                        nrm.append(n)
                        uv.append((0.0, 0.0))
        for c, ax, h in boxes:
            corner = lambda s: tuple(c[k] + sum(s[i] * h[i] * ax[i][k] for i in range(3)) for k in range(3))
            for i in range(3):
                j, k = (i + 1) % 3, (i + 2) % 3
                for sgn in (-1, 1):
                    quad = []
                    for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                        s = [0, 0, 0]
                        s[i], s[j], s[k] = sgn, u, v
                        quad.append(corner(s))
                    model.emit(mat, quad, c)
        model.cur = cur
    return report


# ============================================================== z-fighting pass
# Two faces in the same plane, facing the same way and overlapping, flicker as the depth test picks either one
# (a skirting flush with its wall, a band or a poster laid on a wall, a beam flush with a ceiling). unfight()
# moves the smaller piece (connected triangles of one material) of each such pair ZFIGHT_OFFSET out along the
# shared normal, so it reads as laid on top; a piece caught on opposite sides (a slab running flush into both
# outer walls) instead has those faces drawn in by ZFIGHT_OFFSET, behind the bigger surface. The offset is off
# the round-centimetre steps the models are authored in, so a moved face doesn't land on another one.

ZFIGHT_OFFSET = 0.0125  # m
ZFIGHT_PLANE = 0.0015  # m: faces closer than this to one plane are coplanar
ZFIGHT_CELL = 2.0  # m: spatial grid for the pair search


def unfight(model, passes=4):
    """Returns how many pieces were moved (a stack of three flush layers takes two passes to pull apart)."""
    total = 0
    for _ in range(passes):
        n = _unfight_pass(model)
        total += n
        if not n:
            break
    return total


def _unfight_pass(model):
    tris = []  # (piece key, normal, plane offset, bbox lo, bbox hi, area)
    pieces = {}  # piece key -> [(node, mat, first vertex index), ...]
    for nd in model.nodes:
        if not nd["prims"] or nd["name"].endswith("-colonly"):
            continue
        flat = []
        for mat, (pos, _, _) in nd["prims"].items():
            flat.extend((mat, i) for i in range(0, len(pos) - 2, 3))
        parent = list(range(len(flat)))

        def find(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i
        seen = {}
        for t, (mat, i) in enumerate(flat):
            for v in nd["prims"][mat][0][i:i + 3]:
                # (per material: a skirting touching its wall at a corner is still a piece of its own)
                key = (mat, round(v[0] * 500), round(v[1] * 500), round(v[2] * 500))
                if key in seen:
                    a, b = find(t), find(seen[key])
                    if a != b:
                        parent[a] = b
                else:
                    seen[key] = t
        for t, (mat, i) in enumerate(flat):
            a, b, c = nd["prims"][mat][0][i:i + 3]
            n = v_cross(v_sub(b, a), v_sub(c, a))
            ln = math.sqrt(v_dot(n, n))
            if ln < 1e-8:
                continue
            n = tuple(x / ln for x in n)
            key = (nd["name"], find(t))
            pieces.setdefault(key, []).append((nd["name"], mat, i))
            lo, hi = _aabb([(a, b, c)])
            tris.append((key, n, v_dot(n, a), lo, hi, ln / 2))
    area = {}
    for key, _, _, _, _, ar in tris:
        area[key] = area.get(key, 0.0) + ar
    planes = {}
    for k, t in enumerate(tris):
        n = t[1]
        planes.setdefault((round(n[0], 2), round(n[1], 2), round(n[2], 2), math.floor(t[2] / ZFIGHT_PLANE)), []).append(k)
    push, checked = {}, set()
    for (nx, ny, nz, d), ks in planes.items():
        if ny < -0.9 and abs(d * ZFIGHT_PLANE) < 0.02:
            continue  # undersides on the ground: never seen
        cand = ks + planes.get((nx, ny, nz, d + 1), [])
        if len(cand) < 2:
            continue
        grid = {}
        for k in cand:
            lo, hi = tris[k][3], tris[k][4]
            for gx in range(math.floor(lo[0] / ZFIGHT_CELL), math.floor(hi[0] / ZFIGHT_CELL) + 1):
                for gy in range(math.floor(lo[1] / ZFIGHT_CELL), math.floor(hi[1] / ZFIGHT_CELL) + 1):
                    for gz in range(math.floor(lo[2] / ZFIGHT_CELL), math.floor(hi[2] / ZFIGHT_CELL) + 1):
                        grid.setdefault((gx, gy, gz), []).append(k)
        for cell in grid.values():
            for i in range(len(cell)):
                a = tris[cell[i]]
                for j in range(i + 1, len(cell)):
                    pair = (min(cell[i], cell[j]), max(cell[i], cell[j]))
                    if pair in checked:
                        continue
                    checked.add(pair)
                    b = tris[cell[j]]
                    if a[0] == b[0] or abs(a[2] - b[2]) > ZFIGHT_PLANE or v_dot(a[1], b[1]) < 0.999:
                        continue
                    o = sorted(min(a[4][x], b[4][x]) - max(a[3][x], b[3][x]) for x in range(3))
                    if o[0] < -ZFIGHT_PLANE or o[1] < 0.01 or o[2] < 0.01:
                        continue  # (edge to edge, or apart)
                    small = a if area[a[0]] <= area[b[0]] else b
                    push.setdefault(small[0], {})[(nx, ny, nz)] = (small[1], small[2])
    by_name = {nd["name"]: nd for nd in model.nodes}
    for key, planes_hit in push.items():
        d, shrink = (0.0, 0.0, 0.0), []
        for (nx, ny, nz), (n, off) in planes_hit.items():
            if (round(-nx, 2), round(-ny, 2), round(-nz, 2)) in planes_hit:
                shrink.append((n, off))
            else:
                d = v_add(d, tuple(x * ZFIGHT_OFFSET for x in n))
        for node, mat, i in pieces[key]:
            pos = by_name[node]["prims"][mat][0]
            for j in range(i, i + 3):
                v = v_add(pos[j], d)
                for n, off in shrink:
                    if abs(v_dot(n, pos[j]) - off) < ZFIGHT_PLANE:
                        v = v_sub(v, tuple(x * ZFIGHT_OFFSET for x in n))
                pos[j] = v
    return len(push)


# ============================================================== glb writer

def write_glb(model, path):
    if getattr(model, "finish", None):  # last touches that need the whole model (rig.split_neck)
        model.finish(model)
        model.finish = None
    bin_ = bytearray()
    views, accessors, meshes, nodes = [], [], [], []
    materials, mat_idx, images, tex_idx = [], {}, [], {}
    uses_strength = False

    def view(data, target=None):
        while len(bin_) % 4:
            bin_.append(0)
        v = {"buffer": 0, "byteOffset": len(bin_), "byteLength": len(data)}
        if target:
            v["target"] = target
        views.append(v)
        bin_.extend(data)
        return len(views) - 1

    def accessor(data, count, ctype, typ, mn=None, mx=None, target=34962):
        a = {"bufferView": view(data, target), "componentType": ctype, "count": count, "type": typ}
        if mn is not None:
            a["min"], a["max"] = mn, mx
        accessors.append(a)
        return len(accessors) - 1

    def material(name):
        nonlocal uses_strength
        if name in mat_idx:
            return mat_idx[name]
        m = MATS[name]
        if m["tex"] not in tex_idx:
            # named: Godot extracts images by name, so a texture keeps its own file (and import settings) when
            # the list changes; by index, an albedo could inherit a former normal map's compression
            images.append({"bufferView": view(texture_png(m["tex"])), "mimeType": "image/png", "name": m["tex"]})
            tex_idx[m["tex"]] = len(images) - 1
        ti = {"index": tex_idx[m["tex"]]}
        mat = {"name": name, "pbrMetallicRoughness": {
            "baseColorTexture": ti, "baseColorFactor": [*m["color"], 1.0],
            "metallicFactor": 0.0, "roughnessFactor": m["rough"]}}
        if m.get("bump"):
            key = (m["tex"], m["bump"])
            if key not in tex_idx:
                images.append({"bufferView": view(normal_png(m["tex"], m["bump"])), "mimeType": "image/png",
                               "name": "%s_normal%g" % (m["tex"], m["bump"] * 10)})
                tex_idx[key] = len(images) - 1
            mat["normalTexture"] = {"index": tex_idx[key]}
        if m["emit"]:
            uses_strength = True
            mat["emissiveTexture"] = ti
            mat["emissiveFactor"] = list(m["color"])
            mat["extensions"] = {"KHR_materials_emissive_strength": {"emissiveStrength": m["emit"]}}
        if m["alpha"]:
            mat.update(alphaMode="MASK", alphaCutoff=0.5, doubleSided=True)
        materials.append(mat)
        mat_idx[name] = len(materials) - 1
        return mat_idx[name]

    names = {nd["name"]: i for i, nd in enumerate(model.nodes)}
    vcol = bake_ao(model) if model.ao else {}
    for nd in model.nodes:
        prims = []
        for mat, (pos, nrm, uv) in nd["prims"].items():
            n = len(pos)
            flat = lambda vs: [c for v in vs for c in v]
            pa = accessor(struct.pack("<%df" % (n * 3), *flat(pos)), n, 5126, "VEC3",
                          [min(p[i] for p in pos) for i in range(3)], [max(p[i] for p in pos) for i in range(3)])
            na = accessor(struct.pack("<%df" % (n * 3), *flat(nrm)), n, 5126, "VEC3")
            ua = accessor(struct.pack("<%df" % (n * 2), *flat(uv)), n, 5126, "VEC2")
            ia = accessor(struct.pack("<%dI" % n, *range(n)), n, 5125, "SCALAR", target=34963)
            attrs = {"POSITION": pa, "NORMAL": na, "TEXCOORD_0": ua}
            if (nd["name"], mat) in vcol:
                attrs["COLOR_0"] = accessor(struct.pack("<%df" % (n * 3), *flat(vcol[(nd["name"], mat)])), n, 5126, "VEC3")
            prims.append({"attributes": attrs, "indices": ia, "material": material(mat)})
        node = {"name": nd["name"]}
        if tuple(nd["t"]) != (0, 0, 0):
            node["translation"] = list(nd["t"])
        if prims:
            node["mesh"] = len(meshes)
            meshes.append({"name": nd["name"], "primitives": prims})
        nodes.append(node)
    for i, nd in enumerate(model.nodes):
        if nd["parent"] is not None:
            nodes[names[nd["parent"]]].setdefault("children", []).append(i)
    if vcol:
        # Godot's importer only switches a material to vertex-colour albedo from a mesh's 2nd primitive on, so
        # materials that only ever lead a mesh would lose their occlusion: park a 1 mm triangle of every material
        # (first one repeated at the end) in a throwaway mesh inside the root joint (buried in the pelvis).
        order = list(mat_idx)
        tri = [(0.0, 0.0, 0.0), (0.001, 0.0, 0.0), (0.0, 0.001, 0.0)]
        flags = []
        for name in order + order[:1]:
            fa = {"POSITION": accessor(struct.pack("<9f", *[c for v in tri for c in v]), 3, 5126, "VEC3",
                                       [0.0, 0.0, 0.0], [0.001, 0.001, 0.0]),
                  "NORMAL": accessor(struct.pack("<9f", 0, 0, 1, 0, 0, 1, 0, 0, 1), 3, 5126, "VEC3"),
                  "TEXCOORD_0": accessor(struct.pack("<6f", 0, 0, 0, 0, 0, 0), 3, 5126, "VEC2"),
                  "COLOR_0": accessor(struct.pack("<9f", *[1.0] * 9), 3, 5126, "VEC3")}
            flags.append({"attributes": fa, "indices": accessor(struct.pack("<3I", 0, 1, 2), 3, 5125, "SCALAR", target=34963),
                          "material": mat_idx[name]})
        root = next(i for i, nd in enumerate(model.nodes) if nd["parent"] is None)
        meshes.append({"name": "AoFlags", "primitives": flags})
        nodes.append({"name": "AoFlags", "mesh": len(meshes) - 1})
        nodes[root].setdefault("children", []).append(len(nodes) - 1)

    gltf = {
        "asset": {"version": "2.0", "generator": "LAAF build_assets.py"},
        "scene": 0,
        "scenes": [{"nodes": [i for i, nd in enumerate(model.nodes) if nd["parent"] is None]}],
        "nodes": nodes, "meshes": meshes, "materials": materials, "images": images,
        "textures": [{"sampler": 0, "source": i} for i in range(len(images))],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497} if model.smooth else
                     {"magFilter": 9728, "minFilter": 9986, "wrapS": 10497, "wrapT": 10497}],
        "accessors": accessors, "bufferViews": views,
    }
    if uses_strength:
        gltf["extensionsUsed"] = ["KHR_materials_emissive_strength"]
    while len(bin_) % 4:
        bin_.append(0)
    gltf["buffers"] = [{"byteLength": len(bin_)}]
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(bin_))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(bin_), 0x004E4942) + bin_
    with open(path, "wb") as f:
        f.write(out)


# ============================================================== building helpers

def room(m, w, d, h, mat, t=0.2, door=None, floor="concrete", ceil="paint", leaf=True):
    """Enterable shell on the current node. door=(x, width, height) is cut in the +Z wall."""
    hw, hd, z = w / 2, d / 2, d / 2 - t / 2
    m.box(mat, (w, h, t), (0, h / 2, -hd + t / 2))
    m.box(mat, (t, h, d - 2 * t), (hw - t / 2, h / 2, 0))
    m.box(mat, (t, h, d - 2 * t), (-hw + t / 2, h / 2, 0))
    if door:
        x, dw, dh = door
        a, b = x - dw / 2, x + dw / 2
        if a > -hw:
            m.box(mat, (a + hw, h, t), ((a - hw) / 2, h / 2, z))
        if b < hw:
            m.box(mat, (hw - b, h, t), ((b + hw) / 2, h / 2, z))
        if dh < h:
            m.box(mat, (dw, h - dh, t), (x, (h + dh) / 2, z))
        if leaf:
            phi = math.radians(85)
            m.box("door", (dw, dh, 0.06),
                  (a + math.cos(phi) * dw / 2, dh / 2, z - t / 2 - 0.03 - math.sin(phi) * dw / 2), (0, 85, 0))
    else:
        m.box(mat, (w, h, t), (0, h / 2, z))
    if floor:
        m.box(floor, (w, 0.05, d), (0, 0.025, 0))
    if ceil:
        m.box(ceil, (w, 0.2, d), (0, h + 0.1, 0))


def windows(m, mat, side, w, d, xs, y, ww, wh, t=0.2):
    """Window boxes through a wall so they read from both sides."""
    for x in xs:
        if side == "s":
            m.box(mat, (ww, wh, t + 0.06), (x, y, d / 2 - t / 2))
        elif side == "n":
            m.box(mat, (ww, wh, t + 0.06), (x, y, -d / 2 + t / 2))
        elif side == "e":
            m.box(mat, (t + 0.06, wh, ww), (w / 2 - t / 2, y, x))
        else:
            m.box(mat, (t + 0.06, wh, ww), (-w / 2 + t / 2, y, x))


def chair(m, x, z, yaw=0, mat="planks"):
    with m.push((x, 0, z), (0, yaw, 0)):
        m.box(mat, (0.45, 0.05, 0.45), (0, 0.45, 0))
        m.box(mat, (0.45, 0.5, 0.05), (0, 0.7, -0.2))
        for lx, lz in ((-0.2, -0.2), (0.2, -0.2), (-0.2, 0.2), (0.2, 0.2)):
            m.box("metal", (0.04, 0.45, 0.04), (lx, 0.225, lz))


def table(m, x, z, w=1.2, d=0.8, h=0.75, mat="planks", yaw=0):
    with m.push((x, 0, z), (0, yaw, 0)):
        m.box(mat, (w, 0.06, d), (0, h, 0))
        for lx in (-w / 2 + 0.06, w / 2 - 0.06):
            for lz in (-d / 2 + 0.06, d / 2 - 0.06):
                m.box(mat, (0.06, h, 0.06), (lx, h / 2, lz))


def bed(m, x, z, yaw=0):
    with m.push((x, 0, z), (0, yaw, 0)):
        m.box("planks", (1.0, 0.35, 2.0), (0, 0.175, 0))
        m.box("sheet", (0.95, 0.15, 1.9), (0, 0.42, 0.02))
        m.box("white", (0.6, 0.1, 0.35), (0, 0.54, -0.7))
        m.box("planks", (1.0, 0.8, 0.08), (0, 0.4, -1.0))


def lantern(m, x, y, z, s=1.0):
    m.cyl("iron", 0.01, 0.01, 0.4 * s, (x, y, z), seg=3, caps=False)
    m.cyl("lantern", 0.14 * s, 0.18 * s, 0.35 * s, (x, y - 0.35 * s, z), seg=6)


# ============================================================== models

def m_cliff(name, seed):
    m = Model(name)
    m.node("rock-col")
    m.rock("rock", 6, 14, rng=random.Random(seed), seg=7, rings=4, jit=0.25)
    return m


# ============================================================== map layout

X0, X1, Z0, Z1 = -165, 135, -220, 185  # walkable bounds
LAKE = (-35, 120, 32, 26)  # cx, cz, rx, rz
RAVINE_X, RAVINE_Z = -45, 150
TUNNEL = (22, 38, -240)  # notch in the north mountain for the gate


def height(x, z):
    h = 0.0
    cx, cz, rx, rz = LAKE
    e = ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2
    if e < 1:
        h = -1.3 * min(1.0, (1 - e) / 0.35)
    if x < RAVINE_X and z > RAVINE_Z:
        h = -14 * min(1.0, (z - RAVINE_Z) / 5)
    if TUNNEL[0] < x < TUNNEL[1] and z > TUNNEL[2] and z < Z0 + 1:
        return 0.0
    d = max(X0 - x, x - X1, Z0 - z, z - Z1)
    if d > 0:
        hn = math.sin(x * 0.13) + math.sin(z * 0.11 + x * 0.05) + math.sin((x + z) * 0.07)
        h = max(h, 0.0) + d * (1.7 + 0.25 * hn)
    return h


def ground_mat(x, z, h):
    if h > 1.2 or h < -1.5:
        return "rock"
    if h < -0.05:
        return "mud"
    if z < -145 and -50 < x < 50:
        return "gravel"
    if x < -72 and -70 < z < 45:
        return "forest"
    return "grass"


# (start, end, width, material): axis-aligned road segments
ROADS = [
    ((0, -30), (0, -100), 8, "asphalt"), ((-4, -100), (-58, -100), 7, "asphalt"),
    ((4, -100), (44, -100), 7, "asphalt"), ((0, -104), (0, -150), 6, "gravel"),
    ((-30, 0), (-75, 0), 7, "asphalt"), ((-75, 0), (-120, 0), 4, "mud"),
    ((30, 0), (96, 0), 7, "asphalt"), ((0, 30), (0, 104), 7, "asphalt"),
    ((0, 60), (-85, 60), 7, "asphalt"), ((-85, 60), (-85, 100), 7, "asphalt"),
    ((-85, 100), (-100, 100), 7, "asphalt"), ((-100, 100), (-100, 147), 7, "asphalt"),
    ((-100, 45), (-100, 4), 4, "mud"), ((6, 126), (6, 136), 3, "gravel"),
    ((4, -58), (44, -58), 6, "asphalt"), ((-4, -58), (-44, -58), 6, "asphalt"),  # Elm St
    ((4, 60), (64, 60), 7, "asphalt"),  # Maple Ave
]
LOTS = [  # (x0, z0, x1, z1, material): plazas and parking
    # town square = Hollowmere Memorial Park (tools/models_park.py): shop frontage, lawns, dirt paths, old paving
    (-30, -30, 30, -11, "concrete"), (-30, -11, -8, -3.5, "grass"), (-8, -11, 30, -3.5, "flagstone"),
    (-30, -3.5, 30, 3.5, "flagstone"), (-30, 3.5, -18, 30, "grass"), (-18, 3.5, -16.5, 30, "mud"),
    (-16.5, 3.5, -12, 30, "grass"), (-12, 3.5, 12, 30, "flagstone"), (12, 3.5, 30, 15, "grass"),
    (12, 15, 30, 16.5, "mud"), (12, 16.5, 30, 30, "grass"),
    (-94, 44, -78, 82, "asphalt"), (44, -118, 64, -82, "asphalt"),
    (90, -10, 101, 10, "concrete"), (-6, 100, 20, 128, "gravel"), (-66, -103, -47, -97, "concrete"),
]


FLOOR_CUTS = []  # world XZ rects (x0, z0, x1, z1) of building floors: no road / lot / street is drawn under them
FLOOR_TOP = (0.02, 0.12)  # m: an up-facing collider face this high in a building model is its ground floor


def _floor_rects(model):
    """XZ rects (model space) of a building model's ground floor: its up-facing collider faces at FLOOR_TOP height.
    Roads and lots run at 3-10 cm, so under a floor they either z-fight with it or poke through it."""
    off = _node_offsets(model)
    out = []
    for nd in model.nodes:
        if not nd["prims"] or not _is_col(nd["name"]):
            continue
        for tris, _ in _pieces(nd, off[nd["name"]]):
            for a, b, c in tris:
                n = v_cross(v_sub(b, a), v_sub(c, a))
                ln = math.sqrt(v_dot(n, n))
                if ln > 1e-9 and n[1] / ln > 0.99 and FLOOR_TOP[0] <= a[1] <= FLOOR_TOP[1]:
                    lo, hi = _aabb([(a, b, c)])
                    out.append((lo[0], lo[2], hi[0], hi[2]))
    return out


def _placed_rects(rects, x, z, yaw):
    """Model-space XZ rects of a building placed at (x, z) turned by yaw (a multiple of 90 deg), in world XZ."""
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    out = []
    for x0, z0, x1, z1 in rects:
        pts = [(x + c * px + s * pz, z - s * px + c * pz) for px in (x0, x1) for pz in (z0, z1)]
        out.append((min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts), max(p[1] for p in pts)))
    return out


def _subtract(r, holes):
    """Rect r (x0, z0, x1, z1) minus the hole rects: the rects left (UVs are world-projected, so pieces still tile)."""
    out = [r]
    for hx0, hz0, hx1, hz1 in holes:
        nxt = []
        for x0, z0, x1, z1 in out:
            if hx0 >= x1 or hx1 <= x0 or hz0 >= z1 or hz1 <= z0:
                nxt.append((x0, z0, x1, z1))
                continue
            if z0 < hz0:
                nxt.append((x0, z0, x1, hz0))
            if hz1 < z1:
                nxt.append((x0, hz1, x1, z1))
            mz0, mz1 = max(z0, hz0), min(z1, hz1)
            if x0 < hx0:
                nxt.append((x0, mz0, hx0, mz1))
            if hx1 < x1:
                nxt.append((hx1, mz0, x1, mz1))
        out = [q for q in nxt if q[2] - q[0] > 0.01 and q[3] - q[1] > 0.01]
    return out


def _ground_rect(m, mat, x0, z0, x1, z1, y):
    """A road / lot / street quad, with the building floors (FLOOR_CUTS) cut out of it."""
    for r in _subtract((x0, z0, x1, z1), FLOOR_CUTS):
        m.rect(mat, *r, y)


def _under_floor(x, z):
    return any(x0 < x < x1 and z0 < z < z1 for x0, z0, x1, z1 in FLOOR_CUTS)


def m_terrain():
    m = Model("terrain")
    m.node("ground-col")
    step = 4
    for gx in range(-212, 184, step):
        for gz in range(-268, 232, step):
            c = [(gx, height(gx, gz), gz), (gx + step, height(gx + step, gz), gz),
                 (gx + step, height(gx + step, gz + step), gz + step), (gx, height(gx, gz + step), gz + step)]
            mat = ground_mat(gx + step / 2, gz + step / 2, max(p[1] for p in c) if max(p[1] for p in c) > 1.2 else min(p[1] for p in c))
            below = (gx + step / 2, -100, gz + step / 2)
            m.emit(mat, [c[0], c[1], c[2]], below)
            m.emit(mat, [c[0], c[2], c[3]], below)
    m.node("water")
    cx, cz, rx, rz = LAKE
    m.emit("water", [(cx + rx * math.cos(a / 32 * math.tau), -0.25, cz + rz * math.sin(a / 32 * math.tau))
                     for a in range(32)], (cx, -10, cz))
    m.node("roads")  # (never under a building's floor: FLOOR_CUTS)
    for i, ((ax, az), (bx, bz), w, mat) in enumerate(ROADS):
        _ground_rect(m, mat, min(ax, bx) - w / 2, min(az, bz) - w / 2, max(ax, bx) + w / 2, max(az, bz) + w / 2,
                     0.03 + i * 0.002)
    for x0, z0, x1, z1, mat in LOTS:
        _ground_rect(m, mat, x0, z0, x1, z1, 0.07)
    m.node("streets")
    rects = [_road_rect(r) for r in ROADS] + [l[:4] for l in LOTS]
    for i, road in enumerate(ROADS):
        (ax, az), (bx, bz), w, mat = road
        if mat != "asphalt":
            continue
        x0, z0, x1, z1 = R = _road_rect(road)
        k = 0 if az == bz else 1  # axis the road runs along
        others = [q for q in rects if q != R]
        y = 0.08 + i * 0.001
        # sidewalks with a curb face toward the road
        for side in (-1, 1):
            if k == 0:
                strip = (x0, z0 - SIDEWALK, x1, z0) if side < 0 else (x0, z1, x1, z1 + SIDEWALK)
            else:
                strip = (x0 - SIDEWALK, z0, x0, z1) if side < 0 else (x1, z0, x1 + SIDEWALK, z1)
            for a0, a1 in _cut(strip, k, others):
                sx0, sz0, sx1, sz1 = (a0, strip[1], a1, strip[3]) if k == 0 else (strip[0], a0, strip[2], a1)
                _ground_rect(m, "sidewalk", sx0, sz0, sx1, sz1, y)
                if k == 0:
                    ez = sz1 if side < 0 else sz0
                    if not _under_floor((sx0 + sx1) / 2, ez):
                        m.emit("curb", [(sx0, 0.0, ez), (sx1, 0.0, ez), (sx1, y, ez), (sx0, y, ez)], (0, 0, ez + side))
                else:
                    ex = sx1 if side < 0 else sx0
                    if not _under_floor(ex, (sz0 + sz1) / 2):
                        m.emit("curb", [(ex, 0.0, sz0), (ex, 0.0, sz1), (ex, y, sz1), (ex, y, sz0)], (ex + side, 0, 0))
        # faded markings: white edge lines, dashed yellow centre line
        c = (az if k == 0 else ax)
        for off, mat_, dash in ((-(w / 2 - 0.35), "line_white", 0), (w / 2 - 0.35, "line_white", 0), (0, "line_yellow", 1)):
            band = (x0, c + off - 0.07, x1, c + off + 0.07) if k == 0 else (c + off - 0.07, z0, c + off + 0.07, z1)
            for a0, a1 in _cut(band, k, others):
                spans = [(a0, a1)] if not dash else [(t, min(t + 3.0, a1)) for t in _frange(a0 + 1.0, a1, 7.0)]
                for t0, t1 in spans:
                    if k == 0:
                        _ground_rect(m, mat_, t0, band[1], t1, band[3], 0.068)
                    else:
                        _ground_rect(m, mat_, band[0], t0, band[2], t1, 0.068)
    return m


SIDEWALK = 2.0


def _road_rect(road):
    (ax, az), (bx, bz), w, _ = road
    return (min(ax, bx) - w / 2, min(az, bz) - w / 2, max(ax, bx) + w / 2, max(az, bz) + w / 2)


def _frange(a, b, step):
    while a < b:
        yield a
        a += step


def _cut(strip, k, obstacles):
    """Intervals along axis k (0 = x, 1 = z) of `strip` left after removing overlapping obstacle rects."""
    lo, hi = (strip[0], strip[2]) if k == 0 else (strip[1], strip[3])
    spans = [(lo, hi)]
    for q in obstacles:
        if not (q[0] < strip[2] and strip[0] < q[2] and q[1] < strip[3] and strip[1] < q[3]):
            continue
        q0, q1 = (q[0], q[2]) if k == 0 else (q[1], q[3])
        spans = [p for a, b in spans for p in ((a, min(b, q0)), (max(a, q1), b)) if p[1] - p[0] > 0.3]
    return spans


class World:
    def __init__(self):
        self.ext, self.subs, self.nodes, self.names = {}, [], [], {}
        self.ext_named = {}
        self.rects = [(min(a[0], b[0]) - w / 2, min(a[1], b[1]) - w / 2, max(a[0], b[0]) + w / 2, max(a[1], b[1]) + w / 2)
                      for a, b, w, _ in ROADS] + [l[:4] for l in LOTS]
        self.circles = []
        self.buildings = []  # (model, x, z, yaw) of every building(): their floors are cut out of the roads

    def res(self, path, typ, rid=None):
        """An ext_resource's reference. rid: a fixed id, written after the numbered ones (a resource added later
        then doesn't renumber every other one)."""
        if rid:
            self.ext_named[path] = (typ, rid)
            return 'ExtResource("%s")' % rid
        if path not in self.ext:
            self.ext[path] = (typ, "r%d" % (len(self.ext) + 1))
        return 'ExtResource("%s")' % self.ext[path][1]

    def sub(self, typ, **props):
        sid = "s%d" % (len(self.subs) + 1)
        self.subs.append('[sub_resource type="%s" id="%s"]\n%s' % (typ, sid, "".join("%s = %s\n" % kv for kv in props.items())))
        return 'SubResource("%s")' % sid

    def uniq(self, parent, base):
        k = (parent, base)
        self.names[k] = self.names.get(k, 0) + 1
        return base if self.names[k] == 1 else "%s%d" % (base, self.names[k])

    def add(self, name, parent=".", typ=None, instance=None, groups=None, **props):
        name = self.uniq(parent, name)
        head = '[node name="%s"' % name
        if typ:
            head += ' type="%s"' % typ
        if parent is not None:
            head += ' parent="%s"' % parent
        if instance:
            head += " instance=%s" % instance
        if groups:
            head += " groups=[%s]" % ", ".join('"%s"' % g for g in groups)
        self.nodes.append(head + "]\n" + "".join("%s = %s\n" % kv for kv in props.items()))
        return name if parent in (None, ".") else parent + "/" + name

    def blocked(self, x, z, gap):
        return any(x0 - gap < x < x1 + gap and z0 - gap < z < z1 + gap for x0, z0, x1, z1 in self.rects) or \
            any((x - cx) ** 2 + (z - cz) ** 2 < (r + gap) ** 2 for cx, cz, r in self.circles)

    def inst(self, model, x, z, yaw=0, s=1.0, y=None, block=0.0, parent="Props"):
        if block:
            self.circles.append((x, z, block))
        y = height(x, z) if y is None else y
        self.add(model, parent, instance=self.res("res://models/%s.glb" % model, "PackedScene"),
                 transform=xform(x, y, z, yaw, (s, s, s)))

    def building(self, model, x, z, yaw, hw, hd):
        """Axis-aligned footprint half extents (hw, hd) in world axes, used to keep trees out."""
        self.rects.append((x - hw, z - hd, x + hw, z + hd))
        self.buildings.append((model, x, z, yaw))
        self.inst(model, x, z, yaw, parent="Buildings")

    def light(self, x, y, z, color, energy, rng_, flicker=False, parent="Lights"):
        props = dict(transform=xform(x, y, z), light_color=color4(color), light_energy=energy, omni_range=rng_)
        if flicker:
            props["script"] = self.res("res://scripts/flicker.gd", "Script")
        self.add("Omni", parent, "OmniLight3D", **props)

    def label(self, text, x, y, z, yaw=0, size=64, color=(0.8, 0.78, 0.7), board=None, localize=False):
        """World text (a Label3D, single-sided, facing yaw). board=(w, h): the board it is painted on, centred on
        (x, y) just behind it: the text is sized to fit inside it with LABEL_MARGIN to spare (and never above `size`
        px at 1 cm a pixel). Rasterised at about LABEL_TEXEL a texel, filtered with mipmaps: chunky up close,
        still whole letters across the square at 640x360 (tests/signs_test.gd checks every sign).
        localize: a notice the player has to read (a warning, a plaque): it reads in the player's language, the
        English text being the message id (locale/es.po), sized per language by scripts/sign_label.gd (`ems`).
        Anything else (a shop, a street, a brand) is the town's own English and never translates."""
        em = size * 0.01
        if board:
            em = min(em, label_em(text, *board))
        fs = max(12, min(96, round(em / LABEL_TEXEL)))
        props = {}
        if localize:
            es = sign_translations().get(text, text)
            em_es = min(size * 0.01, label_em(es, *board)) if board else em
            props = dict(script=self.res("res://scripts/sign_label.gd", "Script", "sign_label"),
                         ems='{"en": %.5f, "es": %.5f}' % (em, em_es))
        else:
            props = dict(auto_translate_mode=2)
        self.add("Sign", "Signs", "Label3D", transform=xform(x, y, z, yaw), text=json.dumps(text),
                 font_size=fs, pixel_size="%.5f" % (em / fs), modulate=color4(color), outline_size=0,
                 double_sided="false", texture_filter=3, **props)

    def board_label(self, text, inst, at, board, color=(0.8, 0.78, 0.7), size=96, back=None, localize=False):
        """Text on a board of a placed model: inst = (x, z, yaw) of the instance, at = (x, y, z) of the middle of
        the board's front face in model space (front facing +Z), board = (w, h) of its lettering area. back = the
        model-space z of its back face, for a board lettered on both sides (it reads from behind too)."""
        ix, iz, iyaw = inst
        c, s_ = math.cos(math.radians(iyaw)), math.sin(math.radians(iyaw))
        faces = [(at[2], 0, LABEL_GAP)] + ([(back, 180, -LABEL_GAP)] if back is not None else [])
        for face, turn, off in faces:
            px, pz = at[0], face + off
            self.label(text, ix + c * px + s_ * pz, at[1], iz - s_ * px + c * pz, iyaw + turn, size, color, board,
                       localize)

    def zone(self, name, x0, z0, x1, z1):
        n = self.add("Zone", "Zones", "Area3D", script=self.res("res://scripts/zone.gd", "Script"),
                     zone_name=json.dumps(name), monitorable="false")
        self.add("Shape", n, "CollisionShape3D", transform=xform((x0 + x1) / 2, 10, (z0 + z1) / 2),
                 shape=self.sub("BoxShape3D", size="Vector3(%g, 30, %g)" % (x1 - x0, z1 - z0)))

    def wall(self, x0, z0, x1, z1, h=40):
        self.add("Wall", "Bounds", "CollisionShape3D", transform=xform((x0 + x1) / 2, h / 2 - 16, (z0 + z1) / 2),
                 shape=self.sub("BoxShape3D", size="Vector3(%g, %g, %g)" % (max(x1 - x0, 1), h, max(z1 - z0, 1))))

    def scatter(self, rng, models, n, x0, z0, x1, z1, gap, scale=(0.8, 1.3), maxh=0.3):
        for _ in range(n):
            for _ in range(20):
                x, z = rng.uniform(x0, x1), rng.uniform(z0, z1)
                if abs(height(x, z)) <= maxh and not self.blocked(x, z, gap):
                    self.inst(rng.choice(models), x, z, rng.uniform(0, 360), rng.uniform(*scale), block=gap)
                    break

    def text(self):
        out = ["[gd_scene format=3]\n"]
        for path, (typ, rid) in list(self.ext.items()) + list(self.ext_named.items()):
            out.append('[ext_resource type="%s" path="%s" id="%s"]\n' % (typ, path, rid))
        out += [""] + self.subs + self.nodes
        return "\n".join(out)


# world signs (World.label): the default font's advance per character in ems (measured in Godot 4.7), its line
# height (a Label3D's box per line) in ems
FONT_ADV = {" ": 0.26, "A": 0.66, "B": 0.66, "C": 0.63, "D": 0.73, "E": 0.56, "F": 0.53, "G": 0.73, "H": 0.75,
            "I": 0.31, "J": 0.30, "K": 0.64, "L": 0.54, "M": 0.92, "N": 0.78, "O": 0.79, "P": 0.61, "Q": 0.79,
            "R": 0.64, "S": 0.55, "T": 0.57, "U": 0.74, "V": 0.62, "W": 0.95, "X": 0.62, "Y": 0.59, "Z": 0.58,
            "'": 0.24, ".": 0.27, "-": 0.32, "&": 0.74, ",": 0.27, "!": 0.28, "?": 0.45}
FONT_DIGIT = 0.57
FONT_LINE = 1.45  # (1.37 at large sizes; small integer sizes round each line up)
LABEL_MARGIN = (0.02, 0.12, 0.08)  # m of board kept clear round the text: this share of its height, within min / max
LABEL_GAP = 0.03  # m the text floats off its board (no z-fighting)
LABEL_TEXEL = 0.012  # m per font texel (the raster size follows from it)


def label_em(text, w, h):
    """The largest em (m) at which text fits a w x h board with LABEL_MARGIN (and 15 % slack) round it."""
    lines = text.split(chr(10))
    adv = max(sum(FONT_DIGIT if ch.isdigit() else FONT_ADV.get(_base_letter(ch.upper()), 0.7) for ch in ln)
              for ln in lines)
    m = min(max(LABEL_MARGIN[1] * h, LABEL_MARGIN[0]), LABEL_MARGIN[2]) * 1.15
    return min((w - 2 * m) / adv / 1.03, (h - 2 * m) / (FONT_LINE * len(lines)))


def _base_letter(ch):
    """An accented capital measures as its letter (the accent sits above it): Á -> A, Ñ -> N."""
    return unicodedata.normalize("NFD", ch)[0] if ch.isalpha() else ch


_SIGN_ES = None


def sign_translations():
    """{English sign text: Spanish} from locale/es.po (the localized signs are sized for both)."""
    global _SIGN_ES
    if _SIGN_ES is None:
        import l10n
        _SIGN_ES = {msgid: e["str"][0] for (ctx, msgid), e in l10n.read_po(l10n.PO).items() if not ctx and e["str"][0]}
    return _SIGN_ES


def xform(x, y, z, yaw=0.0, s=(1, 1, 1)):
    c, sn = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    rows = ((c * s[0], 0, sn * s[2]), (0, s[1], 0), (-sn * s[0], 0, c * s[2]))
    return "Transform3D(%s, %g, %g, %g)" % (", ".join("%.5g" % v for r in rows for v in r), x, y, z)


def color4(c):
    return "Color(%g, %g, %g, 1)" % c


WARM, COLD, SICK, RED = (1.0, 0.68, 0.38), (0.55, 0.68, 1.0), (0.7, 1.0, 0.75), (1.0, 0.15, 0.1)


def build_world():
    W = World()
    rng = random.Random(1413)
    # (the night's look: a wall of cold fog the dark melts into, lamps haloed in it (forward-scattering
    # volumetrics), contact shadows (SSAO). SSR is off here: scripts/weather.gd turns it on for wet ground)
    env = W.sub("Environment", background_mode=1, background_color="Color(0.075, 0.085, 0.088, 1)",
                ambient_light_source=2, ambient_light_color="Color(0.4, 0.5, 0.58, 1)", ambient_light_energy=0.8,
                tonemap_mode=2, tonemap_white=6.0, ssr_max_steps=48, ssr_fade_out=1.5, ssr_depth_tolerance=0.4,
                ssao_enabled="true", ssao_radius=1.4, ssao_intensity=1.8, ssao_power=1.6,
                fog_enabled="true", fog_light_color="Color(0.17, 0.19, 0.2, 1)",
                fog_density=0.038, fog_sky_affect=1.0, volumetric_fog_enabled="true",
                volumetric_fog_density=0.03, volumetric_fog_albedo="Color(0.7, 0.74, 0.72, 1)",
                volumetric_fog_anisotropy=0.55, volumetric_fog_length=64.0, volumetric_fog_detail_spread=1.5,
                volumetric_fog_ambient_inject=0.45, glow_enabled="true", glow_intensity=0.7, glow_bloom=0.05,
                glow_hdr_threshold=0.9, adjustment_enabled="true", adjustment_contrast=1.18,
                adjustment_saturation=0.55)
    W.add("Hollowmere", None, "Node3D")
    W.add("WorldEnvironment", typ="WorldEnvironment", environment=env)
    W.add("Moon", typ="DirectionalLight3D", transform="Transform3D(0.8, 0.35, -0.48, 0, 0.81, 0.59, 0.6, -0.47, 0.64, 0, 30, 0)",
          light_color=color4((0.55, 0.66, 0.8)), light_energy=0.3, shadow_enabled="true", shadow_blur=1.5,
          directional_shadow_max_distance=50.0)
    for group in ("Terrain", "Buildings", "Props", "Lights", "Signs", "Zones"):
        W.add(group, typ="Node3D")
    W.add("Bounds", typ="StaticBody3D")
    W.inst("terrain", 0, 0, y=0, parent="Terrain")

    # --- Town Square (hub)
    W.building("grady_store", 14, -24, 0, 7.5, 5.5)
    W.board_label("GRADY'S GENERAL STORE", (14, -24, 0), (0, 4.05, 5.06), (10.0, 0.8), size=56)  # (models_hd_houses
    #                                                                                      GRADY_BOARD, SIGN_Y)
    W.light(14, 2.8, -24, WARM, 1.6, 9)
    W.building("bar", -15, -24, 0, 6.5, 5.5)
    W.board_label("THE DROWNED LANTERN", (-15, -24, 0), (0.2, 3.12, 5.055), (7.6, 0.72), (0.8, 0.35, 0.25), 48)
    W.light(-14, 2.6, -25, (1.0, 0.45, 0.25), 1.2, 8, flicker=True)
    for x, z, yaw in ((-42, -12, 0), (-58, -12, 0), (-42, 12, 180), (-58, 13, 180), (42, -12, 0), (58, -12, 0),
                      (42, 12, 180), (60, 12, 180), (-14, 40, 90), (14, 40, -90), (14, 76, -90), (-14, 80, 90),
                      (-14, -45, 90), (14, -48, -90), (-14, -66, 90), (14, -70, -90)):
        sideways = yaw in (90, -90)
        W.building(rng.choice(("house_a", "house_b", "house_c")), x, z, yaw, 5.5 if sideways else 5.5, 5.5)
    W.inst("lantern_pole", 0, 14, block=1)
    for i in range(6):
        a = math.radians(i * 60 + 30)
        W.inst("festival_stall", 10 * math.cos(a), 14 + 10 * math.sin(a), 90 - i * 60 - 30 + 180, block=2)
    for _ in range(30):  # same rng draws as ever; skip the park fountain (0, 14) and bandstand (-22.5, 17)
        x, z, yaw, s = rng.uniform(-24, 24), rng.uniform(0, 28), rng.uniform(0, 360), rng.uniform(0.8, 1.2)
        if math.hypot(x, z - 14) > 4.2 and math.hypot(x + 22.5, z - 17) > 3.6:
            W.inst("festival_lantern", x, z, yaw, s)
    for x, z in ((-27, -27), (27, -27), (-27, 27), (27, 27), (-27, -5), (27, -5)):
        W.inst("lamp_post", x, z, 45 if x < 0 else -45, block=0.5)
        W.light(x + (0.7 if x < 0 else -0.7), 4.2, z + (0.7 if z <= 0 else -0.7), WARM, 1.4, 11, flicker=rng.random() < 0.3)
    for x, z, yaw in ((18, 6, 30), (-8, -52, 80), (4, 88, 170), (-60, 4, 95), (70, -5, 10)):
        W.inst("car_wreck", x, z, yaw, block=2.5)
    for x, z, yaw in ((-8, -26, 0), (8, -26, 0), (26, -12, -90)):
        W.inst("bench", x, z, yaw)
    # utility poles + wires: tools/models_town.py place(); park dressing: tools/models_park.py place()
    W.zone("Town Square", -35, -35, 35, 35)

    # --- Lakeview Motel (start) + diner
    W.building("motel", -100, 62, 90, 4.5, 21)
    W.building("diner", -100, 92, 90, 5, 7.5)
    W.inst("motel_sign", -82, 44, 90, block=1.0)  # the pole sign by the road (models_hd_houses m_motel_sign)
    W.board_label("LAKEVIEW MOTEL", (-82, 44, 90), (0, 5.6, 0.1), (4.2, 1.0), (0.85, 0.22, 0.18), 72, back=-0.1)
    W.board_label("VACANCY", (-82, 44, 90), (0, 4.6, 0.08), (2.2, 0.4), (0.95, 0.2, 0.18), 40, back=-0.08)
    W.light(-83, 5.2, 44, RED, 1.0, 7, flicker=True)
    W.board_label("DINER", (-100, 92, 90), (0, 3.65, 4.57), (3.4, 0.5), (0.6, 0.8, 0.9), 64)
    # (room numbers: the brass plates on the motel doors, models_hd_houses m_motel)
    W.light(-99.5, 2.4, 49.5, WARM, 1.3, 6)
    W.light(-98, 2.8, 92, SICK, 0.7, 9, flicker=True)
    W.inst("car_wreck", -86, 52, 5, block=2.5)
    W.inst("car_wreck", -89, 70, 175, block=2.5)
    W.zone("Lakeview Motel", -135, 40, -75, 105)

    # --- Pinewood Forest & Sawmill (Owen)
    W.building("sawmill", -132, -5, 90, 7, 11)
    W.light(-130, 4, -5, COLD, 1.0, 14)
    for x, z, yaw in ((-105, -28, 0), (-116, -38, 20), (-96, -42, -15), (-150, 22, 90)):
        W.building("cabin", x, z, yaw, 3.8, 3.8)
    W.light(-150, 2, 22, COLD, 0.6, 6, flicker=True)
    for x, z, yaw in ((-120, -18, 10), (-121, 12, -20), (-100, -34, 80)):
        W.inst("log_pile", x, z, yaw, block=2.5)
    for z in range(-60, 46, 4):
        if not -8 < z < 8:
            W.inst("fence_wood", -73, z, 90)
    W.scatter(rng, ["pine_tree"], 430, -163, -68, -76, 44, 2.6, (0.8, 1.5))
    W.scatter(rng, ["dead_tree"], 30, -163, -68, -76, 44, 2.6)
    W.zone("Pinewood Forest & Sawmill", -165, -70, -75, 45)

    # --- Church & Cemetery (Marcus)
    W.building("church", -72, -100, 90, 13, 13)
    W.light(-80, 2, -100, WARM, 0.9, 7, flicker=True)
    W.light(-65, 3, -100, COLD, 0.6, 12)
    graves = ["grave_a", "grave_b", "grave_c"]
    for gz0, gz1 in ((-138, -116), (-86, -63)):
        for x in range(-108, -50, 3):
            for z in range(gz0, gz1, 3):
                if rng.random() < 0.75 and not W.blocked(x, z, 0.6):
                    W.inst(rng.choice(graves), x + rng.uniform(-0.3, 0.3), z, rng.uniform(-8, 8) + 90)
    for x, z in ((-104, -127), (-104, -74), (-56, -130), (-56, -72)):
        W.inst("mausoleum", x, z, 90, block=3)
    # the cemetery fence: each side exactly corner to corner (panels stretched a hair to fit), so the
    # corners meet instead of overrunning and crossing
    x0, x1, z0, z1 = -111.0, -47.0, -142.0, -60.0
    nx, nz = round((x1 - x0) / 3), round((z1 - z0) / 3)
    for i in range(nx):
        cx = x0 + (i + 0.5) * (x1 - x0) / nx
        W.inst("fence_iron", cx, z0, 0, (x1 - x0) / nx / 3)
        W.inst("fence_iron", cx, z1, 0, (x1 - x0) / nx / 3)
    for i in range(nz):
        cz = z0 + (i + 0.5) * (z1 - z0) / nz
        W.inst("fence_iron", x0, cz, 90, (z1 - z0) / nz / 3)
        if not -105 < cz < -95:  # the gate on the church path
            W.inst("fence_iron", x1, cz, 90, (z1 - z0) / nz / 3)
    W.scatter(rng, ["dead_tree"], 10, -108, -140, -50, -62, 2)
    W.zone("Church & Cemetery", -113, -145, -45, -58)

    # --- St. Agnes Clinic (Julian)
    W.building("clinic", 72, -100, -90, 7.5, 15)
    W.board_label("ST. AGNES CLINIC", (72, -100, -90), (0, 3.88, 7.12), (3.3, 0.48), (0.7, 0.8, 0.75), 64)
    W.inst("ambulance", 55, -92, 20, block=3)
    W.inst("car_wreck", 50, -112, 90, block=2.5)
    for x, z in ((46, -116), (46, -84), (62, -116), (62, -84)):
        W.inst("lamp_post_cold", x, z, 90, block=0.5)
        W.light(x + 1, 4.2, z, SICK, 1.2, 10, flicker=True)
    W.light(72, 2.5, -100, SICK, 0.8, 12, flicker=True)
    W.zone("St. Agnes Clinic", 44, -130, 110, -70)

    # --- Hollowmere Elementary (Nora)
    W.building("school", 108, 0, -90, 7.5, 18.5)
    W.board_label("HOLLOWMERE ELEMENTARY", (108, 0, -90), (0, 4.4, 7.56), (3.8, 0.5), (0.3, 0.27, 0.22), 64)
    W.inst("flagpole", 95, -8)
    W.inst("swing_set", 88, 28, 0)
    W.inst("slide", 95, 34, 60)
    for x in range(81, 102, 3):
        W.inst("fence_iron", x + 1.5, 42)
    for z in range(18, 42, 3):
        W.inst("fence_iron", 81, z + 1.5, 90)
    W.light(108, 2.5, 0, COLD, 0.8, 14, flicker=True)
    W.light(92, 3.5, 30, COLD, 0.6, 10)
    W.circles += [(88, 28, 3), (95, 34, 3)]
    W.zone("Hollowmere Elementary", 78, -35, 135, 45)

    # --- Harbor & Lighthouse (Elena)
    W.inst("dock", -1, 116, y=0)
    W.building("boathouse", 12, 108, -90, 5.5, 4.5)
    W.inst("lighthouse", 6, 140, 180, block=4)  # door south, onto the harbor road
    beam = W.add("Beam", "Lights", "Node3D", transform=xform(6, 17.6, 140),
                 script=W.res("res://scripts/spin.gd", "Script"))
    for yaw in (0, 180):
        W.add("Spot", beam, "SpotLight3D", transform=xform(0, 0, 0, yaw),
              light_color=color4((1.0, 0.95, 0.8)), light_energy=10.0, light_volumetric_fog_energy=3.0,
              spot_range=80.0, spot_angle=7.0)
    W.light(6, 18, 140, (1.0, 0.95, 0.8), 2.0, 8)
    for x, z, yaw in ((-10, 112, 90), (-18, 121, 80), (-26, 110, 100)):
        W.inst("boat", x, z, yaw, y=-0.45)
    for x, z in ((4, 104), (5, 105), (14, 120), (-2, 124)):
        W.inst("crate", x, z, rng.uniform(0, 90), block=0.8)
    for x, z in ((3, 102), (16, 118), (17, 119)):
        W.inst("barrel", x, z, block=0.5)
    for x, z in ((0, 112), (-12, 118.5), (-22, 114)):
        W.light(x, 3, z, COLD, 0.8, 9, flicker=x == -12)
    W.zone("Harbor & Lighthouse", -70, 90, 40, 150)

    # --- Collapsed Bridge
    W.inst("bridge", -100, RAVINE_Z - 4, y=0)
    # (on the barricade board's ravine side, z 11.615 in the bridge's space: between its two posts, over the lamp)
    W.label("BRIDGE OUT", -100, 1.56, RAVINE_Z - 4 + 11.615 - LABEL_GAP, 180, 48, (0.9, 0.85, 0.7), board=(2.5, 0.52),
            localize=True)
    W.inst("ext_town_sign", -104.6, 140, 90)  # (the board the welcome text stands on, not floating in the air)
    W.board_label("HOLLOWMERE  POP. 1413", (-104.6, 140, 90), (0, 2.2, 0.0), (4.9, 0.68), size=40, localize=True)
    W.light(-100, 2, RAVINE_Z + 6, RED, 0.7, 8, flicker=True)
    W.zone("Collapsed Bridge", -125, 128, -75, 190)

    # --- Quarry & Veil's Chapel (The Shepherd) + Old Pass Tunnel
    for x in range(-44, 45, 8):
        if abs(x) > 8:
            W.inst("cliff_" + "abc"[x % 3], x, -148, rng.uniform(0, 360), rng.uniform(0.9, 1.3), y=-1)
    for z in range(-150, -222, -8):
        for x in (-48, 48):
            W.inst("cliff_" + "abc"[z % 3], x, z, rng.uniform(0, 360), rng.uniform(0.9, 1.3), y=-1)
    W.building("veil_chapel", -22, -210, 0, 6, 7)
    W.light(-22, 3, -210, (1.0, 0.3, 0.2), 1.0, 8, flicker=True)
    boss = W.add("Boss", "Props", instance=W.res("res://models/char_boss.glb", "PackedScene"),
                 transform=xform(-22, height(-22, -199), -199))  # guards the chapel door, facing the quarry
    W.add("Anim", boss, "Node", script=W.res("res://scripts/humanoid_anim.gd", "Script"))
    body = W.add("Body", boss, "StaticBody3D")  # (a character model has no collision of its own; Chapter 3 switches
    W.add("Shape", body, "CollisionShape3D", transform=xform(0, 1.4, 0),  # it off while the prop is away)
          shape=W.sub("CapsuleShape3D", radius=0.6, height=2.8))
    W.light(-22, 4.5, -196, RED, 0.8, 6, flicker=True)
    W.building("tunnel_gate", 30, -222.5, 0, 7, 2)
    W.board_label("OLD PASS TUNNEL", (30, -222.5, 0), (0, 7.8, 0.645), (7.4, 1.0), size=72)
    W.light(34.5, 6.8, -220.5, RED, 1.5, 8, flicker=True)
    for x, z, yaw in ((15, -175, 30), (-28, -168, -60)):
        W.inst("crane", x, z, yaw, block=2)
    for x, z in ((-4, -198), (2, -201), (8, -197)):
        W.inst("cage", x, z, rng.uniform(-20, 20), block=1.5)
    for x, z in ((-10, -185), (12, -190), (0, -163)):
        W.inst("lantern_pole", x, z, rng.uniform(0, 90), block=1)
        W.light(x, 5.5, z, (1.0, 0.55, 0.25), 0.9, 9, flicker=True)
    W.scatter(rng, ["barrel", "crate"], 14, -40, -215, 40, -155, 1.5, (1, 1))
    W.scatter(rng, ["cliff_a", "cliff_b"], 6, -40, -215, 40, -160, 4, (0.15, 0.3))
    W.zone("Quarry & Veil's Chapel", -50, -225, 50, -145)

    # --- extra prop packs (tools/models_*.py), placed before the random fill
    for pack in EXTRA_PACKS:
        if hasattr(pack, "place"):
            pack.place(W, rng)

    # --- wilderness fill
    W.scatter(rng, ["pine_tree", "pine_tree", "dead_tree"], 90, -44, -142, 44, -35, 3)
    W.scatter(rng, ["pine_tree", "dead_tree"], 60, 25, -140, 135, -35, 3)
    W.scatter(rng, ["pine_tree", "dead_tree"], 50, 25, 45, 135, 185, 3)
    W.scatter(rng, ["pine_tree", "dead_tree"], 60, -70, 30, -5, 95, 3)
    W.scatter(rng, ["pine_tree"], 50, -163, -218, -52, -146, 3, (0.9, 1.6))
    W.scatter(rng, ["pine_tree"], 30, 52, -218, 133, -146, 3, (0.9, 1.6))
    W.scatter(rng, ["pine_tree", "dead_tree"], 40, -163, 105, -46, 148, 3)
    W.scatter(rng, ["pine_tree", "dead_tree"], 30, -40, 150, 133, 183, 3)

    # --- invisible bounds: map edge, ravine lip, bridge sides and broken end
    W.wall(X0 - 2, Z0 - 2, X0, Z1 + 2)
    W.wall(X1, Z0 - 2, X1 + 2, Z1 + 2)
    W.wall(X0, Z0 - 2, X1, Z0)
    W.wall(X0, Z1, X1, Z1 + 2)
    W.wall(X0, RAVINE_Z - 0.5, -103.6, RAVINE_Z + 0.5)
    W.wall(-96.4, RAVINE_Z - 0.5, RAVINE_X, RAVINE_Z + 0.5)
    W.wall(RAVINE_X - 0.5, RAVINE_Z, RAVINE_X + 0.5, Z1)
    W.wall(-104.6, RAVINE_Z - 4, -103.6, RAVINE_Z + 10)
    W.wall(-96.4, RAVINE_Z - 4, -95.4, RAVINE_Z + 10)
    W.wall(-104, RAVINE_Z + 8.5, -96, RAVINE_Z + 9.5)

    # --- Chapter 1 director (scripts/chapter1.gd); the player wakes in room 6 at the motel
    W.add("Chapter1", typ="Node3D", script=W.res("res://scripts/chapter1.gd", "Script"))
    W.add("Chapter2", typ="Node3D", script=W.res("res://scripts/chapter2.gd", "Script"))  # dormant until ch1 hands over
    W.add("Chapter3", typ="Node3D", script=W.res("res://scripts/chapter3.gd", "Script"))  # dormant until ch2 hands over
    W.add("Player", instance=W.res("res://player/player.tscn", "PackedScene"), transform=xform(-100.2, 0.1, 49.6))
    W.add("Weather", typ="Node3D", script=W.res("res://scripts/weather.gd", "Script"))  # rain, wind, rolling fog
    return W


MODELS = [lambda: m_cliff("cliff_a", 1), lambda: m_cliff("cliff_b", 2), lambda: m_cliff("cliff_c", 3), m_terrain]


def _load_packs():
    """Each tools/models_*.py exposes MODELS (list of callables -> Model) and place(W, rng)."""
    import importlib, sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.modules.setdefault("build_assets", sys.modules[__name__])
    names = sorted(f[:-3] for f in os.listdir(os.path.dirname(os.path.abspath(__file__)))
                   if f.startswith("models_") and f.endswith(".py"))
    return [importlib.import_module(n) for n in names]


EXTRA_PACKS = []


def main():
    EXTRA_PACKS[:] = _load_packs()
    MODELS.extend(fn for pack in EXTRA_PACKS for fn in pack.MODELS)
    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "maps"), exist_ok=True)
    world = build_world()  # first: the terrain (built last) cuts its roads out of the placed buildings' floors
    placed = {b[0] for b in world.buildings}
    floors = {}

    def build(fn):
        m = fn()
        if m.name in placed:
            floors[m.name] = _floor_rects(m)
        moved = unfight(m) if not m.name.startswith("char_") else 0
        cols = auto_collision(m) if not m.name.startswith(("char_", "item_")) and m.name != "terrain" else []
        write_glb(m, os.path.join(ROOT, "models", m.name + ".glb"))
        tris = sum(len(p[0]) for nd in m.nodes if not _is_col(nd["name"]) or nd["name"].endswith("-col")
                   for p in nd["prims"].values()) // 3
        kinds = {k: sum(1 for c in cols if c[0] == k) for k in ("box", "group", "slab", "back", "mesh")}
        print("%-18s %6d tris" % (m.name, tris) + ("   + collision %s" % ", ".join(
            "%d %s" % (n, k) for k, n in kinds.items() if n) if cols else "") + ("   %d z-fights" % moved if moved else ""))
    for fn in MODELS:
        if fn is not m_terrain:
            build(fn)
    FLOOR_CUTS[:] = [r for model, x, z, yaw in world.buildings for r in _placed_rects(floors.get(model, []), x, z, yaw)]
    build(m_terrain)
    with open(os.path.join(ROOT, "maps", "hollowmere.tscn"), "w", newline=chr(10)) as f:  # (LF on any OS: the repo's line endings)
        f.write(world.text())
    print("maps/hollowmere.tscn written")
    chars = sorted(m for m in (os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "models")))
                   if m.startswith("char_") and m + ".glb" in os.listdir(os.path.join(ROOT, "models")))
    with open(os.path.join(ROOT, "maps", "character_gallery.tscn"), "w", newline=chr(10)) as f:
        f.write(build_gallery(chars).text())
    print("maps/character_gallery.tscn written (%d characters)" % len(chars))


def build_gallery(chars):
    """Line-up of every char_* model looping idle/walk/run; walk around them as Alex."""
    W = World()
    env = W.sub("Environment", background_mode=1, background_color="Color(0.08, 0.08, 0.09, 1)",
                ambient_light_source=2, ambient_light_color="Color(0.5, 0.5, 0.55, 1)", ambient_light_energy=0.6,
                tonemap_mode=2, fog_enabled="true", fog_light_color="Color(0.16, 0.16, 0.17, 1)", fog_density=0.03)
    W.add("CharacterGallery", None, "Node3D")
    W.add("WorldEnvironment", typ="WorldEnvironment", environment=env)
    W.add("Key", typ="DirectionalLight3D", light_energy=0.5,
          transform="Transform3D(0.8, 0.35, -0.48, 0, 0.81, 0.59, 0.6, -0.47, 0.64, 0, 10, 0)")
    floor = W.add("Floor", typ="StaticBody3D")
    W.add("Shape", floor, "CollisionShape3D", transform=xform(0, -0.5, 0),
          shape=W.sub("BoxShape3D", size="Vector3(80, 1, 80)"))
    W.add("Mesh", floor, "MeshInstance3D", mesh=W.sub("PlaneMesh", size="Vector2(80, 80)"))
    W.add("Signs", typ="Node3D")
    anim = W.res("res://scripts/humanoid_anim.gd", "Script")
    x0 = -(len(chars) - 1) * 1.25
    for i, name in enumerate(chars):
        x = x0 + i * 2.5
        W.add(name, instance=W.res("res://models/%s.glb" % name, "PackedScene"), transform=xform(x, 0, 0))
        W.add("Anim", name, "Node", script=anim, demo="true")
        W.label(name[5:].replace("_", " ").title(), x, 2.3, 0, size=32)
        W.light(x, 3, 2, (1.0, 0.85, 0.7), 1.2, 6, parent=".")
    W.add("Player", instance=W.res("res://player/player.tscn", "PackedScene"), transform=xform(0, 0.1, 7))
    return W


if __name__ == "__main__":
    main()
