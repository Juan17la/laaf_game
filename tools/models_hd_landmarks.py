"""HD landmarks pack: SA-era rebuilds of the core harbor / forest / quarry / bridge models.

Same model names, footprints, collision node names and light-anchor heights as the originals in
build_assets.py (packs run after core MODELS, so these .glb files win). Smooth lathe/loft/tube
surfaces for anything round, flat shading for hard architecture. Auto-loaded; MODELS only.
"""
import math
import random

import build_assets as B

mix, mul = B.mix, B.mul
add, sub, dot, cross, norm = B.v_add, B.v_sub, B.v_dot, B.v_cross, B.v_norm


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


# ============================================================== textures

def t_hd_corr(x, y, a, b, r):
    rib = 0.5 + 0.5 * math.cos(x * 2 * math.pi / 8)
    c = mix((0.33, 0.33, 0.32), (0.34, 0.16, 0.07), clamp((b - 0.38) * 2.6))
    drip = 0.8 if math.sin(x * 0.61 + a * 3.0) > 0.86 else 1.0
    return mul(c, (0.5 + 0.3 * rib + 0.3 * a) * drip)


def t_hd_needles(x, y, a, b, r):
    s = 128
    tooth = abs(((x / 5.0 + a * 0.9) % 1.0) - 0.5) * 2
    edge = s - 1 - (3 + 20 * tooth + 10 * b)
    hole = y > 50 and b > 0.7 and r > 0.3
    strand = 0.5 + 0.5 * math.sin(x * 2.3 + y * 0.12 + a * 9)
    c = mul((0.07, 0.12, 0.075), (0.45 + 0.7 * a + 0.3 * strand) * (0.55 + 0.45 * y / s))
    return (*c, 0.0 if y > edge or hole else 1.0)


def t_hd_logend(x, y, a, b, r):
    d = math.hypot(x - 31.5, y - 31.5)
    if d > 29:
        return mul((0.16, 0.11, 0.07), 0.6 + 0.5 * a)
    ring = 0.5 + 0.5 * math.sin(d * 1.3 + a * 3)
    c = mul((0.5, 0.38, 0.24), 0.55 + 0.25 * ring + 0.2 * a)
    return mul(c, 0.55) if abs(math.atan2(y - 31.5, x - 31.5) - 0.7) < 0.04 else c


def t_hd_girder(x, y, a, b, r):
    c = mix((0.3, 0.29, 0.28), (0.36, 0.17, 0.08), clamp((b - 0.3) * 2.2))
    c = mul(c, 0.55 + 0.45 * a)
    if x % 32 == 0:
        return mul(c, 0.5)
    for ry in (5, 26, 37, 58):
        d = math.hypot((x % 8) - 4, y - ry)
        if d < 1.6:
            return mul(c, 1.35 if (x % 8) < 4 and y < ry else 0.7)
    return c


def t_hd_hull(x, y, a, b, r):
    if y % 11 == 0:
        return (0.07, 0.06, 0.05)
    paint = mul((0.4, 0.42, 0.4), 0.6 + 0.35 * a)
    if b > 0.68:
        paint = mul((0.22, 0.15, 0.1), 0.7 + 0.5 * a)
    if math.sin(x * 0.9 + a * 4) > 0.9:
        paint = mix(paint, (0.3, 0.14, 0.06), 0.6)
    return paint


def t_hd_lh(x, y, a, b, r):
    c = mul((0.72, 0.7, 0.64), 0.55 + 0.4 * a + 0.05 * r)
    if math.sin(x * 0.7 + a * 5) > 0.8:
        c = mul(c, 0.72)
    if b > 0.66:
        c = mix(c, (0.2, 0.22, 0.14), 0.5)
    return c


def t_hd_glaze(x, y, a, b, r):
    if x < 4 or x > 59 or y < 3 or y > 60 or 30 <= y <= 33:
        return (0.05, 0.05, 0.05)
    c = mul((1.0, 0.86, 0.58), 0.55 + 0.45 * a)
    return mul(c, 0.45) if b > 0.62 else c


def t_hd_awning(x, y, a, b, r):
    c = (0.42, 0.08, 0.06) if (x // 8) % 2 else (0.6, 0.55, 0.44)
    c = mul(c, 0.5 + 0.45 * a)
    return mul(c, 0.55) if b > 0.62 else c


def t_hd_clear(x, y, a, b, r):
    return (0.0, 0.0, 0.0, 0.0)


def t_hd_hazard(x, y, a, b, r):
    c = (0.5, 0.07, 0.05) if ((x + y) // 11) % 2 else (0.66, 0.64, 0.58)
    return mul(c, 0.45 + 0.45 * a) if b < 0.66 else mul(c, 0.3)


def t_hd_stain(x, y, a, b, r):
    v = 0.4 + 0.18 * a + 0.04 * r
    if math.sin(x * 1.1 + a * 6) > 0.75:
        v *= 0.62 + 0.3 * y / 64
    if b > 0.64:
        v *= 0.75
    if y % 32 == 0:
        v *= 0.7
    return (v, v * 0.98, v * 0.93)


B.TEXTURES.update({k[2:]: v for k, v in list(globals().items()) if k.startswith("t_hd_")})
B.ALPHA_TEX.update({"hd_needles", "hd_clear"})
B.TEX_SIZE["hd_needles"] = 128

B.MATS.update({
    "hd_corr": B.M("hd_corr", scale=2.0), "hd_needles": B.M("hd_needles", fit=True),
    "hd_logend": B.M("hd_logend", fit=True), "hd_girder": B.M("hd_girder", scale=1.2),
    "hd_hull": B.M("hd_hull", scale=1.5), "hd_lh_white": B.M("hd_lh", scale=3),
    "hd_lh_red": B.M("hd_lh", (0.62, 0.12, 0.09), 3), "hd_glaze": B.M("hd_glaze", fit=True, emit=1.6),
    "hd_awning": B.M("hd_awning", scale=1.4), "hd_clear": B.M("hd_clear", fit=True),
    "hd_hazard": B.M("hd_hazard", fit=True), "hd_stain": B.M("hd_stain", scale=4),
    "hd_paper": B.M("lantern", (1.0, 0.82, 0.6), 0.5, emit=0.45),
    "hd_dark": B.M("plain", (0.03, 0.03, 0.03), 1), "hd_rope": B.M("fabric", (0.55, 0.47, 0.33), 0.5),
    "hd_drum": B.M("rust", (0.45, 0.55, 0.52), 1.0), "hd_bottom": B.M("rust", (0.45, 0.2, 0.15), 1.5),
    "hd_sawdust": B.M("plain", (0.42, 0.33, 0.21), 1), "hd_line": B.M("plain", (0.5, 0.42, 0.14), 1),
    "hd_timber": B.M("burnt", (0.85, 0.8, 0.75)), "hd_lumber": B.M("planks", (0.95, 0.9, 0.8), 1.2),
    "hd_canvas": B.M("fabric", (0.45, 0.43, 0.36)),
})


# ============================================================== helpers

def beam(m, mat, a, b, w, h=None, caps=False):
    """Rectangular member between points a and b; w is the horizontal width, h the vertical depth."""
    h = h or w
    T = sub(b, a)
    if dot(T, T) < 1e-10:
        return
    t = norm(T)
    up = (1, 0, 0) if abs(t[1]) > 0.9 else (0, 1, 0)
    n = norm(cross(up, t))
    bn = cross(t, n)
    c = tuple((a[i] + b[i]) / 2 for i in range(3))
    cs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    P = lambda o, u, v: tuple(o[i] + n[i] * u * w / 2 + bn[i] * v * h / 2 for i in range(3))
    A, Q = [P(a, u, v) for u, v in cs], [P(b, u, v) for u, v in cs]
    for i in range(4):
        j = (i + 1) % 4
        m.emit(mat, [A[i], A[j], Q[j], Q[i]], c)
    if caps:
        m.emit(mat, A, c)
        m.emit(mat, Q, c)


def tube(m, mat, path, radii, seg=6):
    """Smooth tube along a polyline (parallel-transported frame, so no twisting)."""
    if isinstance(radii, (int, float)):
        radii = [radii] * len(path)
    rows, n = [], None
    for i, p in enumerate(path):
        t = norm(sub(path[min(i + 1, len(path) - 1)], path[max(i - 1, 0)]))
        if n is None:
            up = (1, 0, 0) if abs(t[1]) > 0.7 else (0, 1, 0)
            n = norm(cross(up, t))
        else:
            n = norm(sub(n, mul(t, dot(n, t))))
        bn = cross(t, n)
        r = radii[i]
        rows.append([tuple(p[k] + r * (math.cos(2 * math.pi * j / seg) * n[k] + math.sin(2 * math.pi * j / seg) * bn[k])
                           for k in range(3)) for j in range(seg)])
    m.surface(mat, rows, wrap=True)


def torus(m, mat, R, r, pos=(0, 0, 0), rot=(0, 0, 0), seg=12, rseg=6):
    prof = [(R + r * math.cos(math.radians(-90 + 360 * k / rseg)), r * math.sin(math.radians(-90 + 360 * k / rseg)))
            for k in range(rseg + 1)]
    m.lathe(mat, prof, pos, rot, seg=seg)


def sheet(m, mat, grid):
    """Two-sided smooth sheet (cloth, canopies, thin metal)."""
    m.surface(mat, grid)
    m.surface(mat, grid[::-1])


def dbl(m, mat, pts):
    m.emit(mat, pts)
    m.emit(mat, pts[::-1])


def corrugated(m, mat, O, U, V, nout, period=0.34, amp=0.035, cpp=3):
    """Corrugated sheet: ribs run along V; ripple across U. Visible from both sides."""
    Lu = math.sqrt(dot(U, U))
    if dot(cross(U, V), nout) < 0:
        O, U = add(O, U), mul(U, -1)
    cols = max(2, int(Lu / period * cpp))
    rows = []
    for t in (0.0, 1.0):
        rows.append([add(add(add(O, mul(U, j / cols)), mul(V, t)), mul(nout, amp * math.sin(2 * math.pi * j / cols * Lu / period)))
                     for j in range(cols + 1)])
    sheet(m, mat, rows)


def lantern(m, x, y, z, s=1.0):
    """Paper festival lantern hanging from a hook at (x, y, z)."""
    beam(m, "iron", (x, y, z), (x, y - 0.1 * s, z), 0.012)
    m.cyl("iron", 0.05 * s, 0.06 * s, 0.04 * s, (x, y - 0.13 * s, z), seg=6)
    prof = [(0.05, -0.2), (0.12, -0.18), (0.17, -0.1), (0.185, 0.0), (0.17, 0.1), (0.12, 0.17), (0.05, 0.19)]
    m.lathe("hd_paper", [(r * s, yy * s) for r, yy in prof], (x, y - 0.33 * s, z), seg=8)
    m.cyl("iron", 0.06 * s, 0.05 * s, 0.03 * s, (x, y - 0.55 * s, z), seg=6)


def log(m, a, b, r, rng, seg=8, bark="bark"):
    """Round log between two points with bark sides and ring-textured end caps."""
    t = norm(sub(b, a))
    up = (1, 0, 0) if abs(t[1]) > 0.9 else (0, 1, 0)
    n = norm(cross(up, t))
    bn = cross(t, n)
    L = math.sqrt(dot(sub(b, a), sub(b, a)))
    wob = [1 + rng.uniform(-0.07, 0.07) for _ in range(seg)]
    rows = []
    for f in (0.0, 0.02, 0.5, 0.98, 1.0):
        c = add(a, mul(t, L * f))
        rr = r * (0.92 if f in (0.0, 1.0) else 1.0) * (1 + 0.04 * math.sin(f * 9))
        rows.append([add(c, add(mul(n, rr * wob[j] * math.cos(2 * math.pi * j / seg)),
                                mul(bn, rr * wob[j] * math.sin(2 * math.pi * j / seg)))) for j in range(seg)])
    m.surface(bark, rows, wrap=True)
    m.emit("hd_logend", rows[0], add(a, t))
    m.emit("hd_logend", rows[-1], a)


# ============================================================== trees (instanced ~900x: keep < 450 tris)

def m_pine_tree():
    m = B.Model("pine_tree")
    rng = random.Random(3)
    m.node("trunk-col")
    m.lathe("bark", [(0.5, -0.15), (0.36, 0.1), (0.27, 0.5), (0.21, 2.5), (0.14, 5.5), (0.04, 8.3)], seg=6)
    m.node("needles")
    seg = 9
    tiers = ((1.4, 2.7, 2.3), (2.5, 2.3, 2.2), (3.6, 1.95, 2.1), (4.7, 1.55, 2.0), (5.8, 1.15, 1.8), (6.8, 0.72, 1.7))
    prof = ((1.0, 0.0), (0.84, 0.3), (0.48, 0.66), (0.0, 1.0))
    for k, (y0, R, h) in enumerate(tiers):
        ph = k * 0.37
        jit = [1 + rng.uniform(-0.15, 0.1) for _ in range(seg)]
        dro = [rng.uniform(-0.14, 0.06) for _ in range(seg)]
        rows = []
        for i, (fr, fy) in enumerate(prof):
            row = []
            for j in range(seg):
                a = -2 * math.pi * (j + ph) / seg
                rr = R * fr * (jit[j] if i < 2 else 1.0)
                row.append((rr * math.cos(a), y0 + h * fy + (dro[j] * h if i == 0 else 0), rr * math.sin(a)))
            rows.append(row)
        m.surface("hd_needles", rows, wrap=True)
    return m


def _branch(m, base, d, length, r0, depth, rng):
    seg, n = (5, 3) if depth == 0 else (4, 2) if depth == 1 else (3, 2)
    pts, rads = [base], [r0]
    for i in range(1, n + 1):
        d = norm((d[0] + rng.uniform(-0.3, 0.3), d[1] + rng.uniform(-0.15, 0.2), d[2] + rng.uniform(-0.3, 0.3)))
        pts.append(add(pts[-1], mul(d, length / n)))
        rads.append(r0 * (1 - 0.8 * i / n) + 0.005)
    tube(m, "bark", pts, rads, seg)
    if depth < 2:
        for k in range(2 if depth == 0 else 1):
            i = n - 1 if k == 0 else n
            side = norm(cross(d, (0, 1, 0))) if abs(d[1]) < 0.95 else (1, 0, 0)
            s = 1 if k == 0 else -1
            nd = norm(add(d, mul(side, s * rng.uniform(0.5, 0.9))))
            _branch(m, pts[i - (1 if k else 0)], nd, length * 0.55, rads[i - (1 if k else 0)] * 0.8, depth + 1, rng)


def m_dead_tree():
    m = B.Model("dead_tree")
    rng = random.Random(7)
    m.node("trunk-col")
    path, rads = [], []
    for i, y in enumerate((-0.2, 0.3, 1.2, 2.4, 3.6, 4.8, 6.0)):
        path.append((0.12 * math.sin(y * 0.9), y, 0.1 * math.sin(y * 0.6 + 1)))
        rads.append((0.5, 0.33, 0.27, 0.22, 0.17, 0.11, 0.035)[i])
    tube(m, "bark", path, rads, 6)
    m.node("branches")
    for i, (y, yaw, up, L) in enumerate(((2.6, 20, 0.35, 2.6), (3.4, 150, 0.55, 2.3), (4.1, 260, 0.6, 2.0), (4.9, 80, 0.95, 1.6))):
        a = math.radians(yaw)
        d = norm((math.cos(a), up, math.sin(a)))
        k = min(range(len(path)), key=lambda q: abs(path[q][1] - y))
        _branch(m, (path[k][0], y, path[k][2]), d, L, rads[k] * 0.62, 0, rng)
    return m


# ============================================================== small props

def m_barrel():
    m = B.Model("barrel")
    m.node("barrel-col")
    m.lathe("hd_drum", [(0.0, 0.0), (0.27, 0.0), (0.285, 0.015), (0.288, 0.05), (0.29, 0.26), (0.298, 0.29),
                        (0.29, 0.32), (0.292, 0.58), (0.3, 0.61), (0.292, 0.64), (0.288, 0.85), (0.285, 0.885),
                        (0.27, 0.87), (0.265, 0.86), (0.0, 0.86)], seg=16)
    m.node("detail")
    for y in (0.012, 0.888):
        torus(m, "rust", 0.286, 0.016, (0, y, 0), seg=16, rseg=4)
    m.cyl("rust", 0.04, 0.04, 0.02, (0.16, 0.86, 0.05), seg=6)
    m.cyl("rust", 0.025, 0.025, 0.02, (-0.17, 0.86, -0.08), seg=6)
    return m


def m_crate():
    m = B.Model("crate")
    m.node("crate-col")
    m.box("planks", (0.94, 0.94, 0.94), (0, 0.5, 0))
    m.node("detail")
    s, t, h = 0.5, 0.035, 0.09
    for yaw in (0, 90, 180, 270):
        with m.push((0, 0.5, 0), (0, yaw, 0)):
            z = 0.47 + t / 2
            m.box("hd_lumber", (1.0, h, t), (0, s - h / 2, z))
            m.box("hd_lumber", (1.0, h, t), (0, -s + h / 2, z))
            m.box("hd_lumber", (h, 1.0 - 2 * h, t), (s - h / 2 - 0.005, 0, z))
            m.box("hd_lumber", (h, 1.0 - 2 * h, t), (-s + h / 2 + 0.005, 0, z))
            d = math.degrees(math.atan2(1.0 - 2 * h, 1.0 - 2 * h))
            m.box("hd_lumber", (1.12, h * 0.85, t), (0, 0, z + 0.004), (0, 0, d))
    for x in (-0.3, 0.0, 0.3):
        m.box("hd_lumber", (0.27, t, 0.98), (x, 1.0 + t / 2 - 0.01, 0))
    m.box("iron", (0.2, 0.012, 0.004), (0.18, 0.35, 0.51))  # stencil bar
    m.box("iron", (0.12, 0.012, 0.004), (0.14, 0.31, 0.51))
    return m


def m_fence_wood():
    m = B.Model("fence_wood")
    rng = random.Random(4)
    m.node("fence-col")
    for x in (-2, 0, 2):
        m.loft("hd_timber", [(0, 0.07, 0.07), (1.1, 0.06, 0.065)], (x, 0, 0), (0, rng.uniform(-6, 6), 0), seg=6, power=3.5)
        m.tbox("hd_timber", (0.12, 0.13), (0.02, 0.02), 0.14, (x, 1.1, 0))
    for y, tilt in ((0.4, 1.5), (0.95, -2.0)):
        beam(m, "planks", (-2.05, y, 0.1), (0.0, y + 0.02, 0.1), 0.045, 0.15)
        beam(m, "planks", (0.0, y + 0.01, 0.1), (2.05, y - 0.03 + tilt * 0.01, 0.1), 0.045, 0.15)
    m.node("detail")
    for x in (-2, 0, 2):  # nail heads
        for y in (0.4, 0.95):
            m.box("rust", (0.025, 0.025, 0.01), (x + 0.03, y, 0.128))
    pts = [(-2.0, 1.16, 0.0), (-1.0, 1.1, 0.0), (0.0, 1.17, 0.0), (1.0, 1.09, 0.0), (2.0, 1.16, 0.0)]
    for a, b in zip(pts, pts[1:]):
        beam(m, "iron", a, b, 0.012)
    for i in range(12):  # barbs
        p = (-1.8 + i * 0.33, 1.13 - 0.03 * math.sin(i), 0)
        beam(m, "iron", add(p, (-0.03, -0.03, -0.02)), add(p, (0.03, 0.03, 0.02)), 0.01)
    return m


# ============================================================== festival

def m_festival_lantern():
    m = B.Model("festival_lantern")
    m.node("detail")
    with m.push((0, 0.17, 0), (90, 0, 12), (1.0, 1.0, 0.9)):  # lying on its side, crushed a bit
        prof = [(0.06, -0.21), (0.13, -0.19), (0.18, -0.1), (0.2, 0.0), (0.17, 0.1), (0.11, 0.18), (0.06, 0.2)]
        m.lathe("hd_paper", prof, seg=8)
        m.cyl("iron", 0.065, 0.07, 0.04, (0, 0.19, 0), seg=6)
        m.cyl("iron", 0.07, 0.065, 0.04, (0, -0.23, 0), seg=6)
        tube(m, "iron", [(-0.06, 0.23, 0), (-0.04, 0.33, 0), (0.04, 0.33, 0), (0.06, 0.23, 0)], 0.006, 3)
    return m


def m_lantern_pole():
    m = B.Model("lantern_pole")
    m.node("pole-col")
    m.lathe("hd_timber", [(0.19, -0.2), (0.16, 0.3), (0.14, 4.0), (0.11, 7.9), (0.06, 8.05), (0.0, 8.1)], seg=8)
    m.node("detail")
    for y in (0.6, 3.0, 6.0):
        torus(m, "rust", 0.15 - y * 0.004, 0.02, (0, y, 0), seg=8, rseg=4)
    for i in range(4):
        a = math.radians(i * 45)
        c, s = math.cos(a), math.sin(a)
        y = 6.5 - i * 0.2
        beam(m, "hd_timber", (-2.5 * c, y, 2.5 * s), (2.5 * c, y, -2.5 * s), 0.1, 0.12, caps=True)
        for k in (-1, 1):
            lantern(m, k * 2.3 * c, y - 0.06, -k * 2.3 * s)
            beam(m, "hd_rope", (0, 8.0, 0), (k * 2.45 * c, y + 0.06, -k * 2.45 * s), 0.015)
    m.box("moth", (0.6, 0.6, 0.01), (0, 2.1, 0.17))
    return m


def m_festival_stall():
    m = B.Model("festival_stall")
    rng = random.Random(9)
    m.node("frame-col")
    for x in (-1.2, 1.2):
        for z in (-0.8, 0.8):
            h = 2.4 if z > 0 else 2.15
            m.loft("hd_timber", [(0, 0.06, 0.06), (h, 0.05, 0.05)], (x, 0, z), seg=6, power=3.5)
    m.box("planks", (2.4, 0.9, 0.06), (0, 0.45, 0.83))  # counter front
    for x in (-1.15, 1.15):
        m.box("planks", (0.06, 0.9, 0.35), (x, 0.45, 0.66))
    m.node("detail")
    m.box("hd_lumber", (2.6, 0.06, 0.5), (0, 0.93, 0.72))  # counter top
    for i in range(9):
        beam(m, "hd_timber", (-1.18 + i * 0.295, 0.05, 0.87), (-1.18 + i * 0.295, 0.88, 0.87), 0.05, 0.02)
    m.box("hd_awning", (2.3, 0.4, 0.03), (0, 1.2, 0.88), faces={"+y": "hd_timber", "-y": "hd_timber"})  # sign board
    m.box("moth", (0.36, 0.36, 0.01), (0.8, 1.2, 0.9))
    m.use("frame-col")  # back shelf: the stall's back is open, so it's walked into (too thin for auto collision)
    m.box("hd_lumber", (2.3, 0.04, 0.35), (0, 1.1, -0.72))
    m.use("detail")
    for i in range(7):
        x = -1.0 + i * 0.33
        hh = rng.uniform(0.14, 0.22)
        m.lathe("glass", [(0.0, 0.0), (0.05, 0.0), (0.055, hh * 0.8), (0.03, hh), (0.03, hh + 0.02), (0.0, hh + 0.02)],
                (x, 1.12, -0.72), seg=6)
        if i % 2:
            m.lathe("hd_paper", [(0.0, 0.0), (0.06, 0.02), (0.06, 0.1), (0.0, 0.12)], (x + 0.1, 0.96, 0.7), seg=6)
    # canvas roof: two sagging slopes (ridge along X) and a scalloped valance at the front
    nx, ridge = 8, 2.75
    for side in (1, -1):
        rows = []
        for k in range(4):
            f = k / 3
            z = side * (0.02 + 1.05 * f)
            row = []
            for i in range(nx + 1):
                x = -1.35 + 2.7 * i / nx
                sag = 0.07 * math.sin(math.pi * i / nx) * math.sin(math.pi * f)
                row.append((x, ridge - 0.45 * f - sag, z))
            rows.append(row if side > 0 else row[::-1])
        sheet(m, "hd_awning", rows)
    for i in range(nx):
        x0, x1 = -1.35 + 2.7 * i / nx, -1.35 + 2.7 * (i + 1) / nx
        pts = [(x0, 2.3, 1.07), (x1, 2.3, 1.07), (x1, 2.14, 1.07), ((x0 + x1) / 2, 2.06, 1.07), (x0, 2.14, 1.07)]
        dbl(m, "hd_awning", pts)
    beam(m, "hd_timber", (-1.3, ridge + 0.03, 0), (1.3, ridge + 0.03, 0), 0.06, caps=True)
    for x in (-1.2, 1.2):
        beam(m, "hd_timber", (x, 2.4, 0.8), (x, ridge, 0), 0.05)
        beam(m, "hd_timber", (x, 2.15, -0.8), (x, ridge, 0), 0.05)
    for x in (-0.9, -0.3, 0.3, 0.9):
        lantern(m, x, 2.27, 0.9)
    tube(m, "hd_canvas", [(-1.2, 2.05, 0.95), (-0.6, 1.93, 0.97), (0.0, 1.9, 0.98), (0.6, 1.93, 0.97), (1.2, 2.05, 0.95)], 0.02, 4)
    return m


# ============================================================== harbor

def m_dock():
    """Walkway toward -X from the shore at x=0, deck top at y=0.05."""
    m = B.Model("dock")
    rng = random.Random(12)
    m.node("deck-col")
    m.box("hd_dark", (26, 0.14, 3), (-11, -0.09, 0))
    m.box("hd_dark", (3, 0.14, 10), (-22.5, -0.09, 0))
    m.node("detail")
    x = 2.0
    while x > -21.0:  # boards across the walkway
        w = rng.uniform(0.24, 0.3)
        if rng.random() > 0.04:
            m.box("planks", (w - 0.025, 0.07, 3.0 + rng.uniform(-0.08, 0.06)), (x - w / 2, 0.015 + rng.uniform(-0.012, 0.0), rng.uniform(-0.04, 0.04)),
                  (rng.uniform(-1.2, 1.2), rng.uniform(-0.8, 0.8), 0))
        x -= w
    z = -5.0
    while z < 5.0:  # T-head boards run along X
        w = rng.uniform(0.24, 0.3)
        m.box("planks", (3.0, 0.07, w - 0.025), (-22.5, 0.015, z + w / 2), (0, 0, rng.uniform(-0.8, 0.8)))
        z += w
    for zz in (-1.45, 1.45):  # stringers
        beam(m, "hd_timber", (1.8, -0.22, zz), (-21.0, -0.22, zz), 0.14, 0.26, caps=True)
    for xx in (-21.2, -23.8):
        beam(m, "hd_timber", (xx, -0.22, -5.0), (xx, -0.22, 5.0), 0.14, 0.26, caps=True)
    piles = [(xp, zp) for xp in range(-21, 2, 3) for zp in (-1.4, 1.4)] + [(-23.8, zp) for zp in (-4.5, -1.5, 1.5, 4.5)] + [(-21.2, zp) for zp in (-4.5, 4.5)]
    for i, (xp, zp) in enumerate(piles):
        tip = rng.uniform(0.2, 0.5)
        m.lathe("bark", [(0.15, -2.6), (0.15, -0.4), (0.14, tip - 0.08), (0.1, tip), (0.0, tip + 0.02)],
                (xp, 0, zp), seg=7, phase=rng.random())
        torus(m, "hd_rope", 0.155, 0.025, (xp, rng.uniform(-0.35, -0.1), zp), seg=7, rseg=3)
    for xp in range(-21, 1, 6):  # cross bracing under the deck
        beam(m, "hd_timber", (xp, -0.3, -1.4), (xp, -1.6, 1.4), 0.08, 0.16)
    for xp in (-6, -14):  # bollards
        m.lathe("rust", [(0.0, 0.05), (0.13, 0.05), (0.11, 0.1), (0.09, 0.3), (0.12, 0.36), (0.12, 0.42), (0.0, 0.43)],
                (xp, 0, 1.25), seg=10)
        tube(m, "hd_rope", [(xp + 0.1, 0.3, 1.25), (xp + 0.35, 0.18, 1.45), (xp + 0.8, 0.02, 1.52), (xp + 1.2, -0.3, 1.6)], 0.022, 4)
    for xp, zp in ((-21, 1.3), (-17, -1.3)):  # cleats
        beam(m, "iron", (xp - 0.2, 0.11, zp), (xp + 0.2, 0.11, zp), 0.05, 0.05, caps=True)
        m.box("iron", (0.06, 0.08, 0.05), (xp, 0.07, zp))
    for xp, zp in ((-9, 1.55), (-20, 1.55), (-24.05, 2.5)):  # tyre fenders
        torus(m, "rubber", 0.24, 0.08, (xp, -0.4, zp), (90, 90 if xp < -24 else 0, 0), seg=10, rseg=5)
        beam(m, "hd_rope", (xp, -0.16, zp), (xp, 0.06, zp - 0.1 if xp > -24 else zp), 0.015)
    for xp, zp in ((-11, 1.35), (-21, -1.35)):  # lamp posts under the harbor lights
        beam(m, "hd_timber", (xp, 0.05, zp), (xp, 2.9, zp), 0.12, caps=True)
        beam(m, "hd_timber", (xp, 2.85, zp), (xp, 2.85, zp + (0.5 if zp < 0 else -0.5)), 0.08, caps=True)
        zl = zp + (0.45 if zp < 0 else -0.45)
        m.cyl("iron", 0.02, 0.14, 0.12, (xp, 2.62, zl), seg=8)
        m.ellipsoid("bulb_cold", (0.06, 0.06, 0.06), (xp, 2.6, zl), seg=6, rings=4)
    torus(m, "red", 0.3, 0.05, (-11.08, 1.7, 1.35), (0, 0, 90), seg=12, rseg=4)  # life ring
    return m


def _hull_station(z):
    b = 1.3 * math.sqrt(max(0.0, 1 - ((z + 0.3) / 3.75) ** 2)) if z > -0.3 else 1.3 - 0.15 * ((-0.3 - z) / 2.7) ** 2
    yg = 0.8 + 0.3 * max(0.0, (z - 0.5) / 2.95) ** 2
    yk = 0.02 + 0.5 * max(0.0, (z - 1.1) / 2.35) ** 2
    return b, yg, yk


def m_boat():
    m = B.Model("boat")
    rng = random.Random(21)
    m.node("hull-col")
    zs = [-3.0, -2.6, -1.9, -1.0, -0.1, 0.8, 1.6, 2.2, 2.7, 3.05, 3.3, 3.44]
    ts = [-1.0, -0.84, -0.66, -0.58, -0.36, -0.12, 0.0, 0.12, 0.36, 0.58, 0.66, 0.84, 1.0]
    grid = []
    for z in zs:
        b, yg, yk = _hull_station(z)
        row = []
        for t in ts:
            ph = t * math.pi / 2
            x = b * math.copysign(abs(math.sin(ph)) ** 0.75, t)
            y = yk + (yg - yk) * (1 - math.cos(ph)) ** 1.1
            row.append((x, y, z))
        grid.append(row)
    for c0, c1, mat in ((0, 2, "hd_hull"), (2, 3, "red"), (3, 10, "hd_bottom"), (10, 11, "red"), (11, 13, "hd_hull")):
        m.surface(mat, [row[c0:c1 + 1] for row in grid])
    m.emit("hd_hull", grid[0][::-1], (0, 0.4, 0))  # transom
    deck = [[(0.93 * r[-1][0], r[-1][1] - 0.12, r[-1][2]), (0.93 * r[0][0], r[0][1] - 0.12, r[0][2])] for r in grid[:-1]]
    m.surface("planks", deck)
    m.node("detail")
    for side in (0, -1):  # bulwark inside + cap rail
        strip = [[r[side], (0.93 * r[side][0], r[side][1] - 0.12, r[side][2])] for r in grid]
        sheet(m, "hd_hull", strip)
        tube(m, "hd_timber", [(r[side][0] * 1.01, r[side][1] + 0.02, r[side][2]) for r in grid], 0.045, 4)
    # wheelhouse
    m.loft("hd_hull", [(0.66, 0.78, 0.62), (1.4, 0.76, 0.6), (1.42, 0.7, 0.55)], (0, 0, -1.25), seg=16, power=5)
    m.loft("hd_hull", [(1.9, 0.7, 0.55), (2.08, 0.74, 0.59), (2.2, 0.78, 0.66), (2.26, 0.7, 0.58), (2.28, 0.0, 0.0)],
           (0, 0, -1.25), seg=16, power=5)
    for i in range(4):  # window posts
        a = (i + 0.5) * math.pi / 2
        x, z = 0.72 * math.copysign(abs(math.cos(a)) ** 0.4, math.cos(a)), -1.25 + 0.57 * math.copysign(abs(math.sin(a)) ** 0.4, math.sin(a))
        beam(m, "hd_hull", (x, 1.4, z), (x, 1.92, z), 0.08)
    m.loft("glass", [(1.4, 0.71, 0.54), (1.92, 0.69, 0.53)], (0, 0, -1.25), seg=16, power=5)
    for x in (-0.36, 0.36):
        beam(m, "iron", (x, 1.42, -0.69), (x, 1.9, -0.69), 0.05)
    m.box("door", (0.6, 1.1, 0.04), (0, 1.12, -1.82))
    torus(m, "red", 0.2, 0.045, (0.76, 1.45, -1.2), (0, 0, 90), seg=10, rseg=4)
    beam(m, "hd_timber", (0, 2.2, -1.5), (0, 3.4, -1.55), 0.07, caps=True)  # mast
    beam(m, "hd_timber", (-0.4, 3.0, -1.53), (0.4, 3.0, -1.53), 0.05, caps=True)
    m.ellipsoid("glass", (0.07, 0.09, 0.07), (0, 3.45, -1.55), seg=6, rings=4)
    tube(m, "rust", [(0.4, 1.9, -1.7), (0.42, 2.4, -1.72), (0.42, 2.75, -1.72)], 0.06, 6)  # exhaust
    for side in (-1, 1):
        for z in (-1.8, 0.6):
            b, yg, _ = _hull_station(z)
            torus(m, "rubber", 0.2, 0.07, (side * (b + 0.07), yg - 0.3, z), (90, 90, 0), seg=10, rseg=5)
            beam(m, "hd_rope", (side * (b + 0.05), yg - 0.1, z), (side * (b - 0.02), yg + 0.03, z), 0.015)
    for k in range(3):  # rope coil
        torus(m, "hd_rope", 0.25 - k * 0.02, 0.035, (0.45, 0.72 + k * 0.06, 1.5), seg=10, rseg=4)
    m.ellipsoid("hd_rope", (0.55, 0.18, 0.7), (-0.35, 0.73, 1.2), (0, 20, 0), seg=10, rings=4)  # net pile
    m.box("hd_lumber", (0.5, 0.35, 0.4), (0.4, 0.86, 0.5), (0, 12, 0))  # fish box
    for side in (-1, 1):
        beam(m, "iron", (side * 0.3, 0.78, 3.2), (side * 0.3, 0.98, 3.25), 0.04)
    m.box("iron", (0.7, 0.05, 0.06), (0, 0.98, 3.2))
    return m


def m_boathouse():
    m = B.Model("boathouse")
    rng = random.Random(31)
    w, d, h = 8, 10, 4
    m.node("shell-col")
    B.room(m, w, d, h, "planks", door=(0, 6.0, 3.3), floor="planks", ceil=None, leaf=False)
    # hinged barn door leaf, swung open towards the water
    with m.push((3.0, 0, d / 2 + 0.05), (0, 105, 0)):
        m.box("planks", (3.0, 3.2, 0.08), (-1.5, 1.62, 0))
        for y in (0.4, 1.6, 2.8):
            m.box("hd_timber", (2.9, 0.16, 0.06), (-1.5, y, 0.07))
        beam(m, "hd_timber", (-0.1, 0.4, 0.07), (-2.9, 2.8, 0.07), 0.14, 0.06)
    m.node("detail")
    for side in (1, -1):  # battens
        for i in range(21):
            z = -d / 2 + 0.25 + i * 0.475
            beam(m, "hd_timber", (side * (w / 2 + 0.02), 0.0, z), (side * (w / 2 + 0.02), h, z), 0.05, 0.07)
    for i in range(17):
        x = -w / 2 + 0.25 + i * 0.47
        beam(m, "hd_timber", (x, 0, -d / 2 - 0.02), (x, h, -d / 2 - 0.02), 0.07, 0.05)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box("hd_timber", (0.22, h + 0.1, 0.22), (sx * (w / 2 - 0.05), (h + 0.1) / 2, sz * (d / 2 - 0.05)))
    beam(m, "hd_timber", (-3.1, 3.4, d / 2 + 0.05), (3.1, 3.4, d / 2 + 0.05), 0.2, 0.25, caps=True)  # door header
    # gable ends (both faces) with vertical boards
    rh, ov = 2.0, 0.45
    for z, s in ((d / 2, 1), (-d / 2, -1)):
        tri = [(-w / 2, h, z), (w / 2, h, z), (0, h + rh, z)]
        dbl(m, "planks", tri)
    # corrugated roof, ridge along Z, a few sheets missing
    ridge, ey = h + rh, h - 0.15
    for side in (1, -1):
        e = (side * (w / 2 + ov), ey, 0)
        Vd = sub((0, ridge + 0.05, 0), e)
        nout = norm(cross((0, 0, 1), Vd)) if side > 0 else norm(cross(Vd, (0, 0, 1)))
        if nout[1] < 0:
            nout = mul(nout, -1)
        z = -d / 2 - ov
        k = 0
        while z < d / 2 + ov - 0.1:
            L = min(1.05, d / 2 + ov - z)
            if not (side == 1 and k == 6):
                corrugated(m, "hd_corr", add(add(e, (0, 0, z)), mul(nout, 0.01 * (k % 2))), (0, 0, L), Vd, nout)
            z += 1.0
            k += 1
        for f in (0.15, 0.55, 0.9):  # purlins
            p = add(e, mul(Vd, f))
            beam(m, "hd_timber", (p[0], p[1] - 0.1, -d / 2 - ov), (p[0], p[1] - 0.1, d / 2 + ov), 0.1, 0.14, caps=True)
        # fascia + gutter
        beam(m, "hd_timber", (e[0], e[1] - 0.05, -d / 2 - ov), (e[0], e[1] - 0.05, d / 2 + ov), 0.04, 0.2, caps=True)
        tube(m, "rust", [(e[0] + side * 0.1, e[1] - 0.12, -d / 2 - ov + 0.05 * i) if i < 2 else
                         (e[0] + side * 0.1, e[1] - 0.12 - (0.25 if side > 0 else 0.0), d / 2 + ov) for i in range(3)], 0.07, 5)
    for z in (d / 2 + ov, -d / 2 - ov):  # barge boards
        beam(m, "hd_timber", (-w / 2 - ov, ey - 0.02, z), (0, ridge + 0.02, z), 0.05, 0.22)
        beam(m, "hd_timber", (w / 2 + ov, ey - 0.02, z), (0, ridge + 0.02, z), 0.05, 0.22)
    tube(m, "rust", [(-w / 2 - ov - 0.1, ey - 0.12, d / 2 + ov), (-w / 2 - 0.3, ey - 0.4, d / 2 + 0.2), (-w / 2 - 0.2, 0.3, d / 2 + 0.2), (-w / 2 - 0.45, 0.05, d / 2 + 0.5)], 0.06, 5)
    for i in range(5):  # rafters / tie beams inside
        z = -d / 2 + 0.3 + i * (d - 0.6) / 4
        beam(m, "hd_timber", (-w / 2 + 0.2, h - 0.1, z), (w / 2 - 0.2, h - 0.1, z), 0.12, 0.18, caps=True)
        for side in (1, -1):
            beam(m, "hd_timber", (side * (w / 2 - 0.1), h, z), (0, ridge - 0.1, z), 0.1, 0.16)
    # windows (east wall) with frames and a cracked pane
    B.windows(m, "window", "e", w, d, (-2, 2), 2.0, 1.0, 0.8)
    for zc in (-2, 2):
        x = w / 2 + 0.11
        for dz in (-0.55, 0.55):
            beam(m, "white", (x, 1.5, zc + dz), (x, 2.5, zc + dz), 0.07)
        for y in (1.55, 2.45):
            beam(m, "white", (x, y, zc - 0.58), (x, y, zc + 0.58), 0.07)
        beam(m, "white", (x, 2.0, zc - 0.5), (x, 2.0, zc + 0.5), 0.04)
        m.box("hd_timber", (0.18, 0.06, 1.3), (x + 0.03, 1.5, zc))
    m.box("hd_timber", (0.06, 1.1, 1.3), (w / 2 + 0.2, 2.0, 2), (0, 0, -8))  # boarded-up window
    # interior clutter
    m.box("hd_lumber", (3.0, 0.08, 0.8), (-1.2, 0.95, -d / 2 + 0.6))
    for x in (-2.5, 0.1):
        m.box("hd_timber", (0.08, 0.95, 0.7), (x, 0.47, -d / 2 + 0.6))
    for i in range(3):
        m.ellipsoid("red" if i % 2 else "white", (0.18, 0.24, 0.18), (-3.4, 2.6 - i * 0.5, -1.5 + i * 0.3), seg=8, rings=5)
    sheet(m, "hd_canvas", [[(-3.85, 3.4, -4.0 + i * 0.6), (-3.85 + 0.1 * math.sin(i), 1.6 + 0.3 * math.sin(i * 2.1), -4.0 + i * 0.6)] for i in range(6)][::1])
    for i in range(3):  # oars against the wall
        beam(m, "hd_timber", (3.6, 0.0, -3.5 + i * 0.4), (3.85, 2.6, -3.3 + i * 0.4), 0.05, caps=True)
        m.box("hd_timber", (0.02, 0.6, 0.16), (3.62 + 0.02, 0.35, -3.5 + i * 0.4), (0, 0, -5))
    m.box("fabric", (2.5, 0.3, 1.5), (-2, 0.2, -3), (0, 20, 0))  # nets
    beam(m, "iron", (0, h - 0.1, 0.5), (0, 3.1, 0.5), 0.015)
    m.cyl("metal", 0.05, 0.3, 0.2, (0, 2.9, 0.5), seg=10)
    m.ellipsoid("bulb", (0.07, 0.07, 0.07), (0, 2.88, 0.5), seg=6, rings=4)
    return m


def _lh_r(y):
    return 2.4 + 0.8 * max(0.0, 1 - y / 16) ** 1.25


def m_lighthouse():
    m = B.Model("lighthouse")
    m.node("tower-col")
    m.cyl("stone", 3.75, 3.55, 0.75, (0, -0.4, 0), seg=12)
    for i in range(3):
        m.box("stone", (1.6, 0.12 * (i + 1), 0.35), (0, 0.06 * (i + 1) - 0.0, 3.65 + 0.35 * (2 - i) + 0.05))
    bands = 6
    for i in range(bands):
        y0, y1 = 0.3 + i * (15.7 / bands), 0.3 + (i + 1) * (15.7 / bands)
        prof = [(_lh_r(y0 + (y1 - y0) * f), y0 + (y1 - y0) * f) for f in (0, 0.5, 1)]
        m.lathe("hd_lh_white" if i % 2 == 0 else "hd_lh_red", prof, seg=24)
    m.lathe("hd_lh_white", [(_lh_r(15.99), 15.99), (2.6, 15.45), (3.05, 15.75), (3.35, 15.95), (3.4, 16.3), (0.0, 16.3)], seg=24)
    m.node("detail")
    # door, hood and moth
    rd = _lh_r(1.4)
    m.box("door", (1.1, 2.1, 0.12), (0, 1.4, rd + 0.02))
    m.box("stone", (1.5, 0.18, 0.3), (0, 2.55, rd + 0.05))
    for x in (-0.66, 0.66):
        m.box("stone", (0.2, 2.2, 0.26), (x, 1.4, rd - 0.02))
    m.gable("hd_lh_red", 1.7, 0.7, 0.45, (0, 2.64, rd + 0.12), (0, 90, 0))
    xm = 1.35
    zm = math.sqrt(_lh_r(1.9) ** 2 - xm * xm) + 0.02
    m.box("moth", (0.8, 0.8, 0.01), (xm, 1.9, zm), (0, math.degrees(math.atan2(xm, zm)), 0))
    # tower windows
    for y, th in ((5.0, 180), (8.3, 35), (11.6, 200), (13.8, 320)):
        r = _lh_r(y)
        a = math.radians(th)
        with m.push((r * math.sin(a), y, r * math.cos(a)), (0, th, 0)):
            m.box("glass", (0.45, 0.8, 0.12), (0, 0, 0.0))
            m.box("hd_lh_white", (0.65, 0.1, 0.2), (0, -0.46, 0.05))
            m.box("hd_lh_white", (0.6, 0.12, 0.16), (0, 0.46, 0.03))
            for x in (-0.28, 0.28):
                m.box("hd_lh_white", (0.08, 0.9, 0.15), (x, 0, 0.03))
    # drainpipe down the tower
    th = math.radians(115)
    tube(m, "rust", [((_lh_r(yy) + 0.12) * math.sin(th), yy, (_lh_r(yy) + 0.12) * math.cos(th)) for yy in (0.2, 4, 8, 12, 15.3)], 0.06, 5)
    # gallery railing
    for i in range(28):
        a = 2 * math.pi * i / 28
        beam(m, "iron", (3.28 * math.cos(a), 16.3, 3.28 * math.sin(a)), (3.28 * math.cos(a), 17.4, 3.28 * math.sin(a)), 0.045)
    torus(m, "iron", 3.28, 0.04, (0, 17.4, 0), seg=28, rseg=4)
    torus(m, "iron", 3.28, 0.022, (0, 16.85, 0), seg=28, rseg=4)
    # lantern room
    m.lathe("hd_lh_red", [(1.95, 16.3), (1.95, 16.95), (1.85, 17.02), (0.0, 17.02)], seg=16)
    seg = 10
    ring = lambda r, yy: [(r * math.cos(2 * math.pi * (k + 0.5) / seg), yy, r * math.sin(2 * math.pi * (k + 0.5) / seg)) for k in range(seg)]
    lo, hi = ring(1.8, 17.02), ring(1.8, 18.6)
    for k in range(seg):
        j = (k + 1) % seg
        m.emit("hd_glaze", [lo[k], lo[j], hi[j], hi[k]], (0, 17.8, 0))
        beam(m, "iron", lo[k], hi[k], 0.08)
    torus(m, "iron", 1.83, 0.05, (0, 17.8, 0), seg=seg * 2, rseg=4)
    m.ellipsoid("lamp_glass", (0.5, 0.6, 0.5), (0, 17.7, 0), seg=10, rings=6)
    m.lathe("hd_lh_red", [(1.78, 18.55), (2.15, 18.6), (2.18, 18.72), (2.0, 18.82), (1.55, 19.35), (0.9, 19.85),
                          (0.35, 20.2), (0.0, 20.28)], seg=20)
    m.ellipsoid("iron", (0.22, 0.2, 0.22), (0, 20.45, 0), seg=8, rings=5)
    beam(m, "iron", (0, 20.6, 0), (0, 21.5, 0), 0.03)
    return m


# ============================================================== forest / sawmill

def m_log_pile():
    m = B.Model("log_pile")
    rng = random.Random(17)
    m.node("logs-col")
    for row, n in enumerate((4, 3, 2)):
        for i in range(n):
            z = (i - (n - 1) / 2) * 0.62
            x0, x1 = -2.0 + rng.uniform(-0.15, 0.15), 2.0 + rng.uniform(-0.15, 0.15)
            y = 0.3 + row * 0.53
            log(m, (x0, y, z), (x1, y + rng.uniform(-0.03, 0.03), z + rng.uniform(-0.05, 0.05)), 0.3 + rng.uniform(-0.03, 0.02), rng, seg=8)
    m.node("detail")
    for x in (-1.3, 1.3):
        for s in (-1, 1):
            beam(m, "hd_timber", (x, 0.0, s * 1.3), (x + 0.05, 1.4, s * 1.28), 0.1, caps=True)
    m.cyl("bark", 0.34, 0.32, 0.45, (2.9, 0, 0.8), seg=8)
    m.cyl("hd_logend", 0.32, 0.32, 0.001, (2.9, 0.45, 0.8), seg=8)
    beam(m, "hd_timber", (2.9, 0.47, 0.8), (2.7, 1.1, 0.9), 0.05, caps=True)  # axe handle
    m.box("metal", (0.2, 0.12, 0.02), (2.93, 0.5, 0.78), (0, 20, 30))
    return m


def m_sawmill():
    m = B.Model("sawmill")
    rng = random.Random(41)
    w, d, h = 20, 12, 6
    m.node("frame-col")
    for x in range(-10, 11, 5):
        for z in (-6, 6):
            m.loft("hd_timber", [(0, 0.19, 0.19), (h, 0.17, 0.17)], (x, 0, z), seg=8, power=4)
    m.box("burnt", (w, 1.2, 0.2), (0, 0.6, -6))
    m.box("burnt", (0.2, 1.2, d), (-10, 0.6, 0))
    m.box("burnt", (0.2, 1.2, d), (10, 0.6, 0))
    m.box("planks", (w, 0.05, d), (0, 0.025, 0))
    m.box("hd_clear", (14, 0.9, 1.2), (0, 0.9, 0))  # saw bench collision (drawn below)
    m.node("detail")
    # upper back wall weatherboards, a few missing
    for bx in range(4):
        x0 = -10 + bx * 5
        for r in range(12):
            y = 1.35 + r * 0.33
            if rng.random() < 0.12:
                continue
            beam(m, "burnt", (x0 + 0.15, y, -6.05), (x0 + 4.85, y + rng.uniform(-0.03, 0.03), -6.05), 0.05, 0.3)
    # frames: tie beams, knee braces, king-post trusses
    ridge = h + 2.5
    for z in (-6, 6):
        beam(m, "hd_timber", (-10.3, h, z), (10.3, h, z), 0.3, 0.35, caps=True)
    for x in range(-10, 11, 5):
        beam(m, "hd_timber", (x, h - 0.1, -6.3), (x, h - 0.1, 6.3), 0.25, 0.3, caps=True)
        beam(m, "hd_timber", (x, h, 0), (x, ridge - 0.15, 0), 0.2, caps=True)
        for s in (-1, 1):
            beam(m, "hd_timber", (x, h, s * 6.6), (x, ridge - 0.1, 0), 0.2, 0.25)
            beam(m, "hd_timber", (x, h, s * 0.1), (x, h + 1.2, s * 3.4), 0.12)
            beam(m, "hd_timber", (x, h - 1.2, s * 6), (x, h - 0.1, s * 4.8), 0.14)
        for z in (-6, 6):
            for s in (-1, 1):
                if -10 <= x + s * 1.2 <= 10:
                    beam(m, "hd_timber", (x, h - 1.2, z), (x + s * 1.2, h - 0.05, z), 0.14)
    # corrugated roof, ridge along X
    for side in (1, -1):
        e = (0, h - 0.1, side * 6.9)
        Vd = sub((0, ridge + 0.05, 0), e)
        nout = norm(cross(Vd, (1, 0, 0)))
        if nout[1] < 0:
            nout = mul(nout, -1)
        for f in (0.1, 0.4, 0.7, 0.95):
            p = add(e, mul(Vd, f))
            beam(m, "hd_timber", (-10.5, p[1] - 0.12, p[2]), (10.5, p[1] - 0.12, p[2]), 0.12, 0.16, caps=True)
        x, k = -10.6, 0
        while x < 10.5:
            if (side, k) not in ((1, 4), (1, 13), (-1, 9)):
                sag = mul(nout, -0.25) if (side, k) == (-1, 16) else (0, 0, 0)
                corrugated(m, "hd_corr", add(add(e, (x, 0, 0)), add(mul(nout, 0.012 * (k % 2)), sag)), (1.1, 0, 0), Vd, nout,
                           period=0.36, cpp=3)
            x += 1.05
            k += 1
        beam(m, "rust", (-10.6, ridge + 0.12, 0), (10.6, ridge + 0.12, 0), 0.5, 0.05)  # ridge cap
    # gable end boards (x = +-10)
    for x in (-10.05, 10.05):
        z = -6.4
        while z < 6.4:
            top = ridge - 2.5 * abs(z) / 6.9 - 0.2
            if rng.random() > 0.15:
                beam(m, "burnt", (x, h + 0.15, z), (x, top, z), 0.05, 0.28)
            z += 0.31
    # saw bench: channel rails, rollers, legs
    for z in (-0.6, 0.6):
        beam(m, "rust", (-7, 1.22, z), (7, 1.22, z), 0.1, 0.26, caps=True)
    for i in range(24):
        x = -6.8 + i * 0.59
        if abs(x) < 0.4:
            continue
        tube(m, "metal", [(x, 1.3, -0.58), (x, 1.3, 0.58)], 0.07, 6)
    for x in (-6.5, -3.3, 3.3, 6.5):
        for z in (-0.55, 0.55):
            beam(m, "rust", (x, 0.05, z * 1.3), (x, 1.1, z), 0.1)
        beam(m, "rust", (x, 0.4, -0.65), (x, 0.4, 0.65), 0.06)
    # the blade: toothed disc
    teeth = 32
    pts = []
    for i in range(teeth):
        a0 = 2 * math.pi * i / teeth
        pts.append((1.02 * math.cos(a0), 1.4 + 1.02 * math.sin(a0), 0.03))
        pts.append((1.12 * math.cos(a0 + 0.08), 1.4 + 1.12 * math.sin(a0 + 0.08), 0.03))
    dbl(m, "metal", pts)
    m.cyl("rust", 0.18, 0.18, 0.14, (0, 1.4, -0.04), (90, 0, 0), seg=8)
    hood = []
    for k in range(9):
        a = math.radians(15 + 150 * k / 8)
        hood.append([(1.25 * math.cos(a), 1.4 + 1.25 * math.sin(a), zz) for zz in (-0.14, 0.2)])
    sheet(m, "rust", hood)
    m.box("rust", (0.9, 0.7, 0.8), (0.2, 0.35, -1.3))  # motor
    m.cyl("metal", 0.3, 0.3, 0.3, (0.2, 0.5, -0.9), (90, 0, 0), seg=10)
    beam(m, "rubber", (0.2, 0.8, -0.85), (0, 1.55, -0.1), 0.12, 0.02)
    beam(m, "rubber", (0.2, 0.2, -0.85), (0, 1.25, -0.1), 0.12, 0.02)
    log(m, (-5.8, 1.72, 0.0), (-2.2, 1.7, 0.02), 0.34, rng)
    for x in (-4.9, -3.1):  # carriage dogs
        m.box("rust", (0.12, 0.5, 0.12), (x, 1.62, -0.48))
    # overhead line shaft with pulleys
    tube(m, "rust", [(-10, 5.3, 1.2), (10, 5.3, 1.2)], 0.05, 6)
    for x in (-5, 0, 5):
        m.cyl("rust", 0.35, 0.35, 0.12, (x, 5.3, 1.14), (90, 0, 0), seg=10)
        beam(m, "iron", (x, 5.3, 1.2), (x, 5.8, 1.2), 0.06)
    beam(m, "rubber", (0.1, 5.2, 1.2), (0.1, 1.5, 0.2), 0.12, 0.02)
    # log deck on skids behind the bench
    for x in (-6.5, -2.5):
        beam(m, "hd_timber", (x, 0.1, -1.5), (x, 0.1, -5.2), 0.2, 0.2, caps=True)
    for row, n in enumerate((3, 2)):
        for i in range(n):
            z = -2.4 - i * 0.66 - row * 0.33
            log(m, (-7.2, 0.52 + row * 0.55, z), (-1.8, 0.5 + row * 0.55, z + rng.uniform(-0.1, 0.1)), 0.31, rng)
    # stickered lumber stacks
    for sx, sz, n in ((4.5, 3.4, 5), (-7.0, 3.2, 4)):
        for lay in range(n):
            y = 0.1 + lay * 0.11
            for i in range(7):
                m.box("hd_lumber", (3.6, 0.06, 0.2), (sx + rng.uniform(-0.05, 0.05), y + 0.04, sz - 0.75 + i * 0.25))
            for xx in (-1.4, 0.0, 1.4):
                m.box("hd_timber", (0.05, 0.05, 1.8), (sx + xx, y - 0.015, sz))
    # sawdust
    for x, z, r in ((0.6, 1.2, 1.1), (-1.5, 0.9, 0.7), (1.8, -1.0, 0.8)):
        m.ellipsoid("hd_sawdust", (r, 0.22 * r, r * 0.8), (x, 0.0, z), seg=10, rings=4)
    # hanging work lamp under the light anchor (local 0, 4, 2)
    beam(m, "iron", (0, h - 0.25, 2.0), (0, 4.45, 2.0), 0.015)
    m.lathe("metal", [(0.05, 4.45), (0.12, 4.4), (0.35, 4.2), (0.42, 4.15), (0.38, 4.17), (0.0, 4.4)], seg=12)
    m.ellipsoid("bulb", (0.09, 0.09, 0.09), (0, 4.2, 2.0), seg=6, rings=4)
    # Owen's parents' memorial
    m.box("planks", (1.0, 0.8, 0.6), (8, 0.4, -4.5))
    m.lathe("glass", [(0.0, 0.8), (0.1, 0.8), (0.1, 1.05), (0.07, 1.12), (0.0, 1.12)], (7.8, 0, -4.5), seg=6)
    m.cyl("white", 0.03, 0.03, 0.1, (7.8, 0.82, -4.5), seg=5)
    m.ellipsoid("bulb", (0.02, 0.035, 0.02), (7.8, 0.96, -4.5), seg=5, rings=3)
    m.box("white", (0.2, 0.25, 0.02), (8.2, 0.93, -4.4), (-20, -10, 0))
    m.box("hd_timber", (0.24, 0.29, 0.015), (8.2, 0.93, -4.415), (-20, -10, 0))
    for i in range(4):
        beam(m, "hd_timber", (8.35 + i * 0.04, 0.8, -4.3), (8.45 + i * 0.06, 1.05, -4.25 + i * 0.03), 0.012)
        m.ellipsoid("red", (0.03, 0.02, 0.03), (8.45 + i * 0.06, 1.06, -4.25 + i * 0.03), seg=5, rings=3)
    return m


# ============================================================== quarry

def m_crane():
    m = B.Model("crane")
    m.node("tower-col")
    m.box("concrete", (3.2, 0.4, 3.2), (0, 0.2, 0))
    m.tbox("concrete", (2.6, 2.6), (2.0, 2.0), 0.3, (0, 0.4, 0))
    for x in (-0.8, 0.8):
        for z in (-0.8, 0.8):
            beam(m, "hd_girder", (x, 0.6, z), (x, 18.0, z), 0.18, caps=True)
    m.node("detail")
    bay = 1.45
    for k in range(12):
        y0, y1 = 0.7 + k * bay, 0.7 + (k + 1) * bay
        C = [(-0.8, -0.8), (0.8, -0.8), (0.8, 0.8), (-0.8, 0.8)]
        for i in range(4):
            (ax, az), (bx, bz) = C[i], C[(i + 1) % 4]
            beam(m, "hd_girder", (ax, y0, az), (bx, y0, bz), 0.08)
            if k % 2:
                beam(m, "hd_girder", (ax, y0, az), (bx, y1, bz), 0.07)
            else:
                beam(m, "hd_girder", (bx, y0, bz), (ax, y1, az), 0.07)
    # slewing ring + cab
    m.cyl("rust", 1.3, 1.3, 0.35, (0, 17.9, 0), seg=14)
    m.box("metal", (2.2, 0.15, 2.2), (0, 18.3, 0))
    m.loft("metal", [(16.3, 0.75, 0.7), (17.6, 0.72, 0.68), (17.8, 0.62, 0.58), (17.85, 0.0, 0.0)], (0, 0, 1.45), seg=16, power=5)
    m.loft("glass", [(16.9, 0.76, 0.71), (17.5, 0.74, 0.69)], (0, 0, 1.45), seg=16, power=5)
    beam(m, "metal", (0, 16.6, 1.45), (0, 16.3, 0.8), 0.3, 0.2)
    # A-frame apex and jib (triangular lattice along +X)
    for z in (-0.45, 0.45):
        beam(m, "hd_girder", (-0.5, 18.4, z), (0, 22.0, 0), 0.14)
        beam(m, "hd_girder", (0.5, 18.4, z), (0, 22.0, 0), 0.14)
    jb, jt = 18.4, 19.3
    for z in (-0.45, 0.45):
        beam(m, "hd_girder", (-0.8, jb, z), (17.0, jb, z), 0.14, caps=True)
    beam(m, "hd_girder", (-0.8, jt, 0), (16.2, jt, 0), 0.14, caps=True)
    beam(m, "hd_girder", (16.2, jt, 0), (17.0, jb, 0), 0.1)
    x = 0.8
    while x < 16.0:
        x1 = x + 1.2
        for z in (-0.45, 0.45):
            beam(m, "hd_girder", (x, jb, z), (x + 0.6, jt, 0), 0.06)
            beam(m, "hd_girder", (x + 0.6, jt, 0), (x1, jb, z), 0.06)
        beam(m, "hd_girder", (x, jb, -0.45), (x, jb, 0.45), 0.06)
        x = x1
    # counter-jib walkway + concrete weights
    for z in (-0.5, 0.5):
        beam(m, "hd_girder", (-0.8, 18.3, z), (-6.0, 18.3, z), 0.16, 0.3, caps=True)
    m.box("metal", (5.0, 0.05, 1.0), (-3.4, 18.45, 0))
    for i in range(3):
        m.box("concrete", (0.55, 1.6, 1.4), (-4.2 - i * 0.6, 17.6, 0))
    for p in ((17.0, jb, 0), (-5.9, 18.4, 0)):  # pendant ties
        beam(m, "iron", (0, 22.0, 0), p, 0.035)
    beam(m, "iron", (0, 22.0, 0), (9.0, jt, 0), 0.035)
    # trolley, hoist ropes, hook block
    m.box("rust", (0.8, 0.3, 1.1), (12, 18.2, 0))
    for z in (-0.12, 0.12):
        beam(m, "iron", (12, 18.1, z), (12, 8.4, z), 0.02)
    m.box("rust", (0.35, 0.65, 0.3), (12, 8.1, 0))
    m.cyl("metal", 0.2, 0.2, 0.3, (12, 8.2, -0.15), (90, 0, 0), seg=10)
    tube(m, "iron", [(12, 7.75, 0), (12, 7.45, 0), (12.1, 7.2, 0), (12.3, 7.15, 0), (12.4, 7.3, 0), (12.35, 7.45, 0)], 0.045, 6)
    for i in range(6):  # dangling chain
        y = 7.25 - i * 0.14
        m.box("iron", (0.03, 0.14, 0.08 if i % 2 else 0.03), (12.2, y, 0))
    return m


def m_cage():
    m = B.Model("cage")
    rng = random.Random(51)
    m.node("cage-col")
    m.box("rust", (2.06, 0.1, 2.06), (0, 0.05, 0))
    m.box("rust", (2.06, 0.08, 2.06), (0, 2.2, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            beam(m, "rust", (sx * 0.98, 0.1, sz * 0.98), (sx * 0.98, 2.16, sz * 0.98), 0.07, caps=True)
    for i in range(9):
        t = -0.9 + i * 0.225
        for k, (x, z) in enumerate(((t, -0.97), (t, 0.97), (-0.97, t), (0.97, t))):
            if k == 1 and 1 <= i <= 4:
                continue  # door opening, bars on the leaf below
            bend = 0.12 if (k == 2 and i == 5) else 0.0
            tube(m, "iron", [(x, 0.1, z), (x - bend, 1.1, z), (x, 2.16, z)], 0.02, 5)
    with m.push((-0.73, 0, 0.97), (0, -25, 0)):  # door leaf ajar
        for i in range(4):
            tube(m, "iron", [(0.12 + i * 0.225, 0.16, 0.0), (0.12 + i * 0.225, 2.08, 0.0)], 0.02, 5)
        for y in (0.2, 1.1, 2.05):
            beam(m, "rust", (0.02, y, 0), (0.9, y, 0), 0.04, caps=True)
    m.node("detail")
    for y in (1.1,):
        for sx in (-1, 1):
            beam(m, "rust", (sx * 0.98, y, -0.98), (sx * 0.98, y, 0.98), 0.04)
        beam(m, "rust", (-0.98, y, -0.98), (0.98, y, -0.98), 0.04)
    m.box("iron", (0.12, 0.14, 0.05), (0.21, 1.05, 1.02))  # padlock hanging off the latch
    tube(m, "iron", [(0.18, 1.12, 1.02), (0.18, 1.2, 1.02), (0.24, 1.2, 1.02), (0.24, 1.12, 1.02)], 0.01, 3)
    torus(m, "iron", 0.12, 0.025, (0, 2.3, 0), seg=10, rseg=4)
    for i in range(8):  # chain up to the crane hook
        m.box("iron", (0.03 if i % 2 else 0.08, 0.14, 0.08 if i % 2 else 0.03), (0, 2.46 + i * 0.13, 0))
    m.box("hd_canvas", (0.9, 0.02, 0.7), (0.3, 0.11, -0.3), (0, 30, 0))  # rag on the floor
    m.box("red", (0.35, 0.005, 0.25), (-0.3, 0.103, 0.4), (0, 70, 0))
    return m


def m_tunnel_gate():
    m = B.Model("tunnel_gate")
    m.node("shell-col")
    R, spring, zf, zb, top, hw = 3.2, 3.4, 0.6, -12.6, 9.0, 7.0
    arch = [(R * math.cos(math.pi * k / 12), spring + R * math.sin(math.pi * k / 12)) for k in range(13)]  # +x -> -x
    c = (0, 4.5, -5)
    for x0, x1 in ((-hw, -R), (R, hw)):
        m.emit("hd_stain", [(x0, 0, zf), (x1, 0, zf), (x1, top, zf), (x0, top, zf)], c)
    for (xa, ya), (xb, yb) in zip(arch, arch[1:]):
        m.emit("hd_stain", [(xb, yb, zf), (xa, ya, zf), (xa, top, zf), (xb, top, zf)], c)
    for x in (-hw, hw):
        m.emit("hd_stain", [(x, 0, zf), (x, 0, -0.6), (x, top, -0.6), (x, top, zf)], (0, 4.5, 0))
    m.emit("concrete", [(-hw, top, zf), (hw, top, zf), (hw, top, -0.6), (-hw, top, -0.6)], (0, 0, 0))
    prof = [(R, 0.0)] + arch + [(-R, 0.0)]
    rows = [[(x, y, z) for x, y in prof] for z in (zf, -4.0, zb)]
    m.surface("concrete", rows)
    m.emit("rock", [(-R, 0, zb), (R, 0, zb), (R, spring, zb)] + [(x, y, zb) for x, y in arch[1:]], (0, 3, 0))
    m.rect("asphalt", -R, zb, R, zf, 0.02)
    m.emit("hd_clear", [(-R, 0, 0.3), (R, 0, 0.3)] + [(x, y, 0.3) for x, y in arch], (0, 3, -2))  # gate blocker
    m.node("detail")
    m.rock("rock", 12, 16, (0, -1, -13.5), rng=random.Random(21), seg=9, rings=3, jit=0.2)
    # arch ring voussoirs + keystone, coping, pilasters, name panel
    for (xa, ya), (xb, yb) in zip(arch, arch[1:]):
        dx, dy = xa / R, (ya - spring) / R
        ex, ey = xb / R, (yb - spring) / R
        pts = [(xa, ya, zf + 0.12), (xb, yb, zf + 0.12), (xb + ex * 0.6, yb + ey * 0.6, zf + 0.12), (xa + dx * 0.6, ya + dy * 0.6, zf + 0.12)]
        m.emit("stone", pts, (0, spring, 0))
        m.emit("stone", [(xa, ya, zf), (xb, yb, zf), (xb, yb, zf + 0.12), (xa, ya, zf + 0.12)], (0, spring, zf + 0.06))
        m.emit("stone", [(xa + dx * 0.6, ya + dy * 0.6, zf), (xa + dx * 0.6, ya + dy * 0.6, zf + 0.12),
                         (xb + ex * 0.6, yb + ey * 0.6, zf + 0.12), (xb + ex * 0.6, yb + ey * 0.6, zf)], (0, spring, zf + 0.06))
    m.box("stone", (0.7, 1.0, 0.3), (0, spring + R + 0.35, zf + 0.12))
    for x in (-R - 0.35, R + 0.35):
        m.box("stone", (0.7, spring, 0.24), (x, spring / 2, zf + 0.1))
        m.box("stone", (0.9, 0.25, 0.32), (x, spring + 0.1, zf + 0.12))
    m.box("concrete", (hw * 2 + 0.4, 0.4, 1.6), (0, top + 0.2, 0), faces={"+z": "hd_stain"})
    for x in (-hw + 0.4, hw - 0.4):
        m.box("hd_stain", (0.8, top, 0.4), (x, top / 2, zf + 0.2))
    m.box("hd_dark", (7.4, 1.0, 0.05), (0, 7.8, zf + 0.02))
    m.box("concrete", (7.7, 0.12, 0.12), (0, 7.24, zf + 0.06))
    m.box("concrete", (7.7, 0.12, 0.12), (0, 8.36, zf + 0.06))
    for s in (-1, 1):  # wing walls
        with m.push((s * hw, 0, 0), (0, s * -25, 0)):
            m.box("hd_stain", (3.5, 5.0, 0.8), (s * 1.75, 2.5, 0))
            m.box("concrete", (3.6, 0.3, 1.0), (s * 1.75, 5.1, 0))
    # iron gate: two barred leaves, chained
    for i in range(15):
        x = -R + 0.2 + i * (2 * R - 0.4) / 14
        yt = spring + math.sqrt(max(0.0, R * R - x * x)) - 0.08
        beam(m, "iron", (x, 0.0, 0.3), (x, yt, 0.3), 0.05)
        m.cyl("rust", 0.0, 0.05, 0.12, (x, yt - 0.02, 0.3), (180, 0, 0), seg=4)
    for y in (0.4, 2.6, 4.6):
        half = math.sqrt(max(0.0, R * R - max(0.0, y - spring) ** 2)) - 0.05
        beam(m, "rust", (-half, y, 0.34), (-0.05, y, 0.34), 0.06, 0.1, caps=True)
        beam(m, "rust", (0.05, y, 0.34), (half, y, 0.34), 0.06, 0.1, caps=True)
    for i in range(7):
        m.box("iron", (0.1 if i % 2 else 0.03, 0.03, 0.03 if i % 2 else 0.1), (-0.35 + i * 0.11, 2.45 + 0.08 * math.sin(i), 0.42))
    m.box("metal", (0.2, 0.26, 0.1), (0.25, 2.3, 0.45))
    # red warning lamp housing
    m.box("metal", (0.2, 0.5, 0.12), (4.5, 7.15, zf + 0.06))
    m.cyl("metal", 0.22, 0.22, 0.25, (4.5, 6.8, zf + 0.05), (90, 0, 0), seg=10)
    m.ellipsoid("bulb_red", (0.17, 0.17, 0.12), (4.5, 6.8, 0.8), seg=8, rings=5)
    for a in range(4):
        beam(m, "iron", (4.5 + 0.2 * math.cos(a * math.pi / 2), 6.8 + 0.2 * math.sin(a * math.pi / 2), 0.62),
             (4.5 + 0.1 * math.cos(a * math.pi / 2), 6.8 + 0.1 * math.sin(a * math.pi / 2), 0.98), 0.02)
    tube(m, "rubber", [(4.5, 7.4, 0.65), (4.8, 7.8, 0.66), (5.6, 8.1, 0.66), (6.8, 8.85, 0.66)], 0.025, 4)
    m.box("hd_hazard", (1.2, 0.8, 0.04), (-5.0, 2.2, zf + 0.04))  # warning plate
    for x, z, r in ((-4.5, 1.8, 0.5), (5.2, 2.3, 0.35), (-2.0, 3.0, 0.3)):  # rubble
        m.rock("concrete", r, r * 0.8, (x, -0.1, z), rng=random.Random(int(x * 10)), seg=5, rings=2, jit=0.35)
    return m


# ============================================================== bridge

def _slab(m, outline, top, bot, center):
    cx, cz = center
    n = len(outline)
    for i in range(n):
        (x0, z0), (x1, z1) = outline[i], outline[(i + 1) % n]
        m.emit("asphalt", [(cx, top, cz), (x0, top, z0), (x1, top, z1)], (cx, top - 1, cz))
        m.emit("concrete", [(cx, bot, cz), (x0, bot, z0), (x1, bot, z1)], (cx, bot + 1, cz))
        m.emit("hd_stain", [(x0, bot, z0), (x1, bot, z1), (x1, top, z1), (x0, top, z0)], (cx, (top + bot) / 2, cz))


def m_bridge():
    """Collapsed through-truss bridge along +Z from the cliff edge at z=0. Deck top y=0.05.
    Walkable up to the invisible wall at z 12.5; the broken end is jagged past it."""
    m = B.Model("bridge")
    rng = random.Random(61)
    m.node("deck-col")
    jag_n = [(3.5, 12.9), (2.8, 13.5), (2.1, 12.8), (1.4, 14.0), (0.6, 13.2), (-0.2, 14.2), (-1.0, 13.3),
             (-1.9, 13.9), (-2.6, 12.9), (-3.5, 13.3)]
    _slab(m, [(-3.5, 0.0), (3.5, 0.0)] + jag_n, 0.05, -0.45, (0, 6))
    jag_f = [(-3.5, 25.8), (-2.7, 25.1), (-1.8, 25.9), (-0.9, 24.8), (0.0, 25.6), (0.9, 24.6), (1.9, 25.4),
             (2.7, 24.9), (3.5, 25.6)]
    _slab(m, jag_f + [(3.5, 40.0), (-3.5, 40.0)], 0.05, -0.45, (0, 32))
    for x in (-3.35, 3.35):
        z1 = 12.8 if x > 0 else 11.8
        m.box("concrete", (0.3, 0.8, z1), (x, 0.45, z1 / 2), faces={"+x": "hd_stain", "-x": "hd_stain"})
        m.box("concrete", (0.3, 0.8, 14.0), (x, 0.45, 26.0 + 7.0), faces={"+x": "hd_stain", "-x": "hd_stain"})
    m.node("detail")
    for x in (-3.35, 3.35):  # coping
        z1 = 12.8 if x > 0 else 11.8
        m.tbox("stone", (0.42, z1), (0.34, z1), 0.1, (x, 0.85, z1 / 2))
        m.tbox("stone", (0.42, 14.0), (0.34, 14.0), 0.1, (x, 0.85, 33.0))
    with m.push((-3.35, 0.2, 12.4), (25, 15, 30)):  # broken parapet chunk hanging off
        m.box("concrete", (0.3, 0.8, 1.2), (0, 0, 0))
    # trusses
    nodes_n = [0.0, 2.6, 5.2, 7.8, 10.4, 13.0]
    for side in (-1, 1):
        x = side * 3.75
        beam(m, "hd_girder", (x, -0.05, 0.0), (x, -0.05, 12.6 + 0.4 * side), 0.3, 0.4, caps=True)
        beam(m, "hd_girder", (x, -0.05, 0.0), (x, 4.4, 2.6), 0.34, 0.36, caps=True)
        beam(m, "hd_girder", (x, 4.4, 2.6), (x, 4.4, 10.4), 0.34, 0.36, caps=True)
        for i, z in enumerate(nodes_n[1:5]):
            beam(m, "hd_girder", (x, -0.05, z), (x, 4.4, z), 0.22, 0.14)
            m.box("rust", (0.05, 0.6, 0.7), (x + side * 0.02, 0.2, z))
            m.box("rust", (0.05, 0.6, 0.7), (x + side * 0.02, 4.2, z))
            if i < 3:
                zn = nodes_n[i + 2]
                beam(m, "hd_girder", (x, 4.4, z) if i < 1 else (x, -0.05, z), (x, -0.05, zn) if i < 1 else (x, 4.4, zn), 0.18, 0.12)
        # torn top chord drooping over the gap
        tip = (x + side * 0.3, 1.0 + 0.8 * side, 14.2 + 0.5 * side)
        beam(m, "hd_girder", (x, 4.4, 10.4), (x + side * 0.15, 3.3, 12.6), 0.3, 0.3)
        beam(m, "hd_girder", (x + side * 0.15, 3.3, 12.6), tip, 0.26, 0.26)
        beam(m, "hd_girder", (x, -0.05, 10.4), (x - side * 0.2, 2.2, 12.9), 0.18, 0.12)
        # far span: end post at 40, torn start near the gap
        beam(m, "hd_girder", (x, -0.05, 25.3), (x, -0.05, 40.0), 0.3, 0.4, caps=True)
        beam(m, "hd_girder", (x, -0.05, 40.0), (x, 4.4, 37.4), 0.34, 0.36, caps=True)
        beam(m, "hd_girder", (x, 4.4, 37.4), (x, 4.4, 29.6), 0.34, 0.36, caps=True)
        beam(m, "hd_girder", (x, 4.4, 29.6), (x + side * 0.4, 2.5, 27.2 - 0.6 * side), 0.3, 0.3)
        for i, z in enumerate((29.6, 32.2, 34.8, 37.4)):
            beam(m, "hd_girder", (x, -0.05, z), (x, 4.4, z), 0.22, 0.14)
            if i < 3:
                zn = z + 2.6
                beam(m, "hd_girder", (x, -0.05, z) if i < 1 else (x, 4.4, z), (x, 4.4, zn) if i < 1 else (x, -0.05, zn), 0.18, 0.12)
        beam(m, "hd_girder", (x, -0.05, 27.0), (x - side * 0.1, 3.0, 28.2), 0.22, 0.14)
    for z in (2.6, 5.2, 7.8, 10.4, 29.6, 32.2, 34.8, 37.4):  # top struts + lateral X bracing
        beam(m, "hd_girder", (-3.75, 4.4, z), (3.75, 4.4, z), 0.2, 0.3)
    for za, zb in ((2.6, 5.2), (5.2, 7.8), (7.8, 10.4), (29.6, 32.2), (32.2, 34.8), (34.8, 37.4)):
        beam(m, "hd_girder", (-3.75, 4.5, za), (3.75, 4.5, zb), 0.08)
        beam(m, "hd_girder", (3.75, 4.5, za), (-3.75, 4.5, zb), 0.08)
    for z in (2.6, 37.4):  # portal knee braces
        for s in (-1, 1):
            beam(m, "hd_girder", (s * 3.75, 3.4, z), (s * 2.6, 4.4, z), 0.14)
    m.box("hd_dark", (2.4, 0.5, 0.04), (0, 4.4, 2.42))
    # stringers, floor beams, piers
    for x in (-2.4, 0.0, 2.4):
        beam(m, "hd_girder", (x, -0.75, 0.0), (x, -0.75, 12.4 + 0.3 * x), 0.26, 0.6, caps=True)
        beam(m, "hd_girder", (x, -0.75, 25.6), (x, -0.75, 40.0), 0.26, 0.6, caps=True)
    beam(m, "hd_girder", (2.4, -0.75, 13.1), (2.1, -2.8, 15.2), 0.26, 0.6, caps=True)  # dangling stringer
    for z in (1.3, 3.9, 6.5, 9.1, 11.7, 27.0, 29.6, 32.2, 34.8, 37.4):
        beam(m, "hd_girder", (-3.8, -0.8, z), (3.8, -0.8, z), 0.22, 0.5)
    for z in (8, 32):
        for x in (-2.4, 2.4):
            m.loft("concrete", [(-17.0, 0.9, 0.9), (-3.0, 0.72, 0.72), (-1.8, 0.72, 0.72)], (x, 0, z), seg=12, power=3.5)
        beam(m, "hd_stain", (-3.9, -1.55, z), (3.9, -1.55, z), 1.3, 0.75, caps=True)
        for ya, yb in ((-12.0, -5.0), (-5.0, -12.0)):
            beam(m, "concrete", (-2.0, ya, z), (2.0, yb, z), 0.3, 0.3)
    # collapsed slabs hanging into the gap, with rebar
    with m.push((0.4, -1.6, 15), (35, 4, 0)):
        m.box("concrete", (6, 0.5, 5), faces={"+y": "asphalt"})
    with m.push((-0.5, -2.2, 23), (-40, -6, 0)):
        m.box("concrete", (5, 0.5, 4), faces={"+y": "asphalt"})
    for (xa, za), (xb, zb) in zip(jag_n, jag_n[1:]):
        for f in (0.3, 0.7):
            x, z = xa + (xb - xa) * f, za + (zb - za) * f
            L = rng.uniform(0.5, 1.2)
            tube(m, "rust", [(x, -0.2, z - 0.1), (x + rng.uniform(-0.1, 0.1), -0.2 - L * 0.2, z + L * 0.5),
                             (x + rng.uniform(-0.3, 0.3), -0.3 - L * 0.9, z + L * 0.7)], 0.02, 3)
    for (xa, za), (xb, zb) in zip(jag_f, jag_f[1:]):
        x, z = (xa + xb) / 2, (za + zb) / 2
        tube(m, "rust", [(x, -0.2, z + 0.1), (x, -0.4, z - 0.5), (x + rng.uniform(-0.2, 0.2), -1.1, z - 0.7)], 0.02, 3)
    # road paint + a dead street lamp
    for z in range(1, 12, 3):
        m.rect("hd_line", -0.06, z, 0.06, z + 1.5, 0.056)
    for x in (-2.9, 2.9):
        m.rect("hd_line", x - 0.05, 0.2, x + 0.05, 12.4, 0.056)
    tube(m, "metal", [(3.1, 0.9, 5.0), (3.1, 5.8, 5.0), (2.9, 6.3, 5.0), (2.2, 6.4, 5.0)], [0.08, 0.07, 0.06, 0.05], 6)
    m.box("metal", (0.7, 0.15, 0.3), (2.0, 6.35, 5.0))
    m.box("glass", (0.6, 0.04, 0.24), (2.0, 6.27, 5.0))
    # barricade + BRIDGE OUT sign board (label at z 11.4 faces -Z)
    for x in (-1.5, 0.0, 1.5):
        for s in (-1, 1):
            beam(m, "hd_timber", (x + s * 0.55, 0.05, 11.3), (x + s * 0.5, 1.0, 11.5), 0.06)
            beam(m, "hd_timber", (x + s * 0.55, 0.05, 11.7), (x + s * 0.5, 1.0, 11.5), 0.06)
        m.box("hd_hazard", (1.3, 0.22, 0.05), (x, 0.9, 11.47))
        m.box("hd_hazard", (1.3, 0.18, 0.05), (x, 0.45, 11.47))
    for x in (-1.3, 1.3):
        beam(m, "hd_timber", (x, 0.9, 11.58), (x, 1.9, 11.58), 0.08)
    m.box("hd_timber", (3.2, 0.65, 0.05), (0, 1.5, 11.64))
    m.cyl("rust", 0.1, 0.1, 0.12, (0, 1.0, 11.5), seg=8)
    m.ellipsoid("bulb_red", (0.09, 0.09, 0.09), (0, 1.18, 11.5), seg=8, rings=4)
    return m


MODELS = [m_pine_tree, m_dead_tree, m_barrel, m_crate, m_fence_wood, m_festival_lantern, m_lantern_pole,
          m_festival_stall, m_dock, m_boat, m_boathouse, m_lighthouse, m_log_pile, m_sawmill, m_crane, m_cage,
          m_tunnel_gate, m_bridge]
