"""SA-era civic buildings & cemetery/playground props: school, clinic, church, veil chapel, mausoleum,
graves, iron fence, swing set, slide, flagpole. Replaces the core versions (same names, footprints,
doors, room shells and interior props). Auto-loaded by build_assets._load_packs(): MODELS only.
"""
import math
import random

import build_assets as B
import interior_kit as K

mul, mix = B.mul, B.mix


# ============================================================== textures

def t_civ_brick(x, y, a, b, r):
    """Grimy red brick with soot streaks running down from the top."""
    off = 8 if (y // 8) % 2 else 0
    streak = 0.75 + 0.25 * math.sin(x * 0.7 + a * 5)
    if y % 8 == 0 or (x + off) % 16 == 0:
        c = mul((0.36, 0.34, 0.31), 0.75 + 0.3 * a)
    else:
        k = ((x + off) // 16 * 5 + y // 8 * 3) % 4
        c = mul([(0.34, 0.16, 0.12), (0.29, 0.14, 0.11), (0.36, 0.2, 0.15), (0.25, 0.13, 0.1)][k],
                0.6 + 0.45 * a + 0.08 * r)
    if b > 0.5:
        c = mix(c, (0.08, 0.08, 0.07), min(0.7, (b - 0.5) * 2.5 * streak))
    return c


def t_civ_panel(x, y, a, b, r):
    """70s precast aggregate panels: beige, speckled, water stains, vertical joints."""
    if x % 32 == 0 or y % 64 == 0:
        return mul((0.2, 0.19, 0.17), 0.8 + 0.3 * a)
    v = 0.5 + 0.2 * a + (0.12 if r > 0.9 else -0.06 if r < 0.1 else 0)
    c = (v, v * 0.95, v * 0.83)
    stain = max(0.0, b - 0.5) * 2 * (1 - (y % 64) / 90)
    return mix(c, (0.18, 0.17, 0.12), min(0.7, stain))


def t_civ_ashlar(x, y, a, b, r):
    """Big weathered ashlar blocks, uneven lengths per course, soot and damp patches."""
    row = y // 16
    off = (row * 23) % 32
    L = 32 if row % 2 else 21
    col = (x + off) // L
    if y % 16 == 0 or (x + off) % L == 0:
        return mul((0.15, 0.15, 0.14), 0.8 + 0.3 * a)
    k = (row * 7 + col * 5) % 5
    v = (0.42, 0.37, 0.45, 0.34, 0.4)[k] * (0.6 + 0.5 * a + 0.06 * r)
    c = (v, v * 0.98, v * 0.93)
    if b > 0.55:
        c = mix(c, (0.1, 0.11, 0.08), min(0.65, (b - 0.55) * 2.5))
    return c


def t_civ_granite(x, y, a, b, r):
    v = 0.4 + 0.18 * a + (0.14 if r > 0.93 else -0.1 if r < 0.08 else 0)
    c = (v, v * 0.99, v * 0.95)
    if b > 0.6:  # lichen / moss
        c = mix(c, (0.2, 0.25, 0.12), min(0.7, (b - 0.6) * 3))
    return c


def _pane(x, y, a, b, r, broken):
    if x < 3 or x > 60 or y < 3 or y > 60:
        return mul((0.16, 0.16, 0.15), 0.8 + 0.3 * a)
    refl = 0.08 if abs((x + y * 0.6) % 40 - 12) < 4 else 0.0
    c = mul((0.07, 0.08, 0.09), 0.7 + 0.6 * a)
    c = (c[0] + refl, c[1] + refl, c[2] + refl * 1.1)
    dirt = max(0.0, (y - 40) / 24) * 0.4 + max(0.0, b - 0.55)
    c = mix(c, (0.2, 0.18, 0.13), min(0.6, dirt))
    if broken:
        hole = math.hypot((x - 26) * 0.9, (y - 30) * 1.2) < 12 + 8 * a
        if hole:
            return (0.01, 0.01, 0.012)
        ang = math.atan2(y - 30, x - 26)
        if abs(math.sin(ang * 5 + 0.4)) < 0.05 + 0.02 * r:
            return (0.3, 0.32, 0.33)
    return c


def t_civ_win(x, y, a, b, r):
    return _pane(x, y, a, b, r, False)


def t_civ_win_broken(x, y, a, b, r):
    return _pane(x, y, a, b, r, True)


def t_civ_stained(x, y, a, b, r):
    """Gothic lancet glazing: diamond quarries with a saint's halo, lead came, soot."""
    u, v = x + y, x - y + 64
    if u % 12 < 1 or v % 12 < 1 or x < 2 or x > 61:
        return (0.02, 0.02, 0.02)
    d = math.hypot(x - 32, y - 18)
    if abs(d - 10) < 1:
        return (0.02, 0.02, 0.02)
    if d < 10:
        c = (0.75, 0.55, 0.15)
    else:
        k = ((u // 12) * 7 + (v // 12) * 3) % 5
        c = [(0.4, 0.06, 0.06), (0.08, 0.1, 0.3), (0.08, 0.22, 0.13), (0.36, 0.28, 0.08), (0.2, 0.07, 0.22)][k]
    c = mul(c, 0.45 + 0.6 * a)
    return mix(c, (0.03, 0.03, 0.03), 0.5) if b > 0.66 else c


def t_civ_rose(x, y, a, b, r):
    dx, dy = x - 31.5, y - 31.5
    d, ang = math.hypot(dx, dy), math.atan2(dy, dx)
    if d > 31 or abs(d - 9) < 1.2 or abs(d - 21) < 1.2 or (d > 9 and abs(math.sin(ang * 6)) < 0.09):
        return (0.02, 0.02, 0.02)
    petal = int((ang + math.pi) / (math.pi / 3))
    c = (0.5, 0.38, 0.1) if d < 9 else [(0.36, 0.05, 0.06), (0.07, 0.1, 0.3)][(petal + (d > 21)) % 2]
    return mix(mul(c, 0.5 + 0.6 * a), (0.02, 0.02, 0.02), 0.6 if b > 0.64 else 0)


def t_civ_clock(x, y, a, b, r):
    dx, dy = x - 31.5, y - 31.5
    d = math.hypot(dx, dy)
    if d > 31:
        return (0.1, 0.1, 0.1)
    if d > 28:
        return mul((0.25, 0.22, 0.16), 0.8 + 0.3 * a)
    ang = math.atan2(dy, dx)
    tick = d > 22 and abs(math.sin(ang * 6)) < 0.12
    hands = B.seg_dist(x, y, 32, 32, 20, 20) < 1.4 or B.seg_dist(x, y, 32, 32, 38, 55) < 1.0
    if tick or hands:
        return (0.05, 0.05, 0.05)
    c = mul((0.72, 0.68, 0.55), 0.7 + 0.3 * a)
    return mix(c, (0.25, 0.2, 0.1), 0.5) if b > 0.58 else c


def t_civ_redcross(x, y, a, b, r):
    if x < 3 or x > 60 or y < 3 or y > 60:
        return (0.12, 0.12, 0.12)
    cross = (24 <= x <= 39 and 10 <= y <= 53) or (10 <= x <= 53 and 24 <= y <= 39)
    c = (0.62, 0.05, 0.04) if cross else (0.78, 0.76, 0.7)
    c = mul(c, 0.75 + 0.3 * a)
    if b > 0.6 or (y > 50 and x % 7 == 2):
        c = mix(c, (0.2, 0.15, 0.08), 0.5)
    return c


def t_civ_epitaph(x, y, a, b, r):
    """Engraved lines of a worn inscription on granite."""
    base = t_civ_granite(x, y, a, b, r)
    line = y in (14, 15, 24, 25, 34, 42, 50) and 12 + (y % 5) < x < 52 - (y % 7) and r > 0.25
    cross = (30 <= x <= 33 and 2 <= y <= 10) or (27 <= x <= 36 and 4 <= y <= 5)
    return mul(base, 0.45) if line or cross else base


def t_civ_chipped(x, y, a, b, r):
    """Chipped playground paint over rust; tinted per material."""
    if b > 0.66 or (r > 0.985):
        return mix((0.42, 0.22, 0.12), (0.3, 0.2, 0.14), a)
    return mul((0.8, 0.8, 0.78), 0.55 + 0.3 * a)


def t_civ_grille(x, y, a, b, r):
    c = mul((0.36, 0.37, 0.36), 0.6 + 0.4 * a)
    if y % 4 < 2:
        c = mul(c, 0.35)
    return mix(c, (0.35, 0.18, 0.08), 0.6) if b > 0.62 else c


B.TEXTURES.update({k[2:]: v for k, v in dict(globals()).items() if k.startswith("t_civ_")})

B.MATS.update({
    "civ_brick": B.M("civ_brick", scale=2.2), "civ_panel": B.M("civ_panel", scale=4),
    "civ_band": B.M("concrete", (0.85, 0.83, 0.78), 3), "civ_trim": B.M("concrete", (1.05, 1.02, 0.95), 2),
    "civ_win": B.M("civ_win", fit=True, rough=0.3), "civ_win_broken": B.M("civ_win_broken", fit=True, rough=0.3),
    "civ_frame": B.M("plain", (0.2, 0.2, 0.19), 1), "civ_alu": B.M("metal", (0.55, 0.55, 0.52), 1),
    "civ_stained": B.M("civ_stained", fit=True, emit=0.4), "civ_rose": B.M("civ_rose", fit=True, emit=0.4),
    "civ_ashlar": B.M("civ_ashlar", scale=3), "civ_louvre": B.M("planks", (0.45, 0.45, 0.45), 1.5),
    "civ_clock": B.M("civ_clock", fit=True), "civ_sign": B.M("civ_redcross", fit=True, emit=0.35),
    "civ_granite": B.M("civ_granite", scale=1.0), "civ_granite_d": B.M("civ_granite", (0.7, 0.7, 0.7), 1.0),
    "civ_marble": B.M("civ_granite", (1.1, 1.08, 1.02), 1.5), "civ_dressed": B.M("civ_granite", (0.95, 0.93, 0.88), 1.5), "civ_epitaph": B.M("civ_epitaph", fit=True),
    "civ_red": B.M("civ_chipped", (0.6, 0.18, 0.13), 1), "civ_blue": B.M("civ_chipped", (0.28, 0.38, 0.55), 1),
    "civ_yellow": B.M("civ_chipped", (0.75, 0.6, 0.25), 1), "civ_grille": B.M("civ_grille", scale=0.6),
    "civ_canopy": B.M("plain", (0.12, 0.16, 0.15), 1, rough=0.15),
    "civ_stripe": B.M("plain", (0.6, 0.5, 0.15), 1), "civ_slate": B.M("roof", (0.75, 0.78, 0.85), 1.5),
    "civ_moss": B.M("grass", (0.8, 0.9, 0.7), 1),
})


# ============================================================== geometry helpers

def v3(p):
    return p if len(p) == 3 else (p[0], p[1], 0.0)


def emit_to(m, mat, pts, target):
    """Flat polygon whose normal points toward `target`."""
    c = tuple(sum(p[i] for p in pts) / len(pts) for i in range(3))
    m.emit(mat, pts, tuple(2 * c[i] - target[i] for i in range(3)))


def rect_pts(w, h, y0=0.0):
    return [(-w / 2, y0), (w / 2, y0), (w / 2, y0 + h), (-w / 2, y0 + h)]


def arch_pts(w, h, pointed=0.0, n=4, y0=0.0):
    """Opening outline (CCW, facing +Z): straight jambs up to the springing, then an arch.
    pointed 0 = round, 1 = equilateral gothic. h = total height to the apex."""
    r = w / 2 + pointed * w / 2
    cx = w / 2 - r
    amax = math.acos(max(-1.0, min(1.0, -cx / r)))
    rise = r * math.sin(amax)
    ys = y0 + max(0.0, h - rise)
    right = [(cx + r * math.cos(amax * i / n), ys + r * math.sin(amax * i / n)) for i in range(n + 1)]
    left = [(-x, y) for x, y in reversed(right)]
    return [(-w / 2, y0), (w / 2, y0)] + right + left[1:]


def surround(m, mat, inner, outer, zf, zi=0.0, zo=0.0):
    """Moulded frame between two outlines (same point count): front face at z=zf, reveal back to zi,
    outer edge back to zo (all in the wall's local frame, wall face at z=0, +Z outward)."""
    n = len(inner)
    cx = sum(p[0] for p in inner) / n
    cy = sum(p[1] for p in inner) / n
    for i in range(n):
        j = (i + 1) % n
        a, b, c, d = inner[i], inner[j], outer[j], outer[i]
        if a == b and c == d:
            continue
        emit_to(m, mat, [(a[0], a[1], zf), (b[0], b[1], zf), (c[0], c[1], zf), (d[0], d[1], zf)], (cx, cy, zf + 1))
        if zi != zf and a != b:
            emit_to(m, mat, [(a[0], a[1], zf), (b[0], b[1], zf), (b[0], b[1], zi), (a[0], a[1], zi)], (cx, cy, zf))
        if zo != zf and c != d:
            m.emit(mat, [(d[0], d[1], zf), (c[0], c[1], zf), (c[0], c[1], zo), (d[0], d[1], zo)], (cx, cy, zf))


def pane(m, mat, pts, z, back=None):
    """Glazing polygon at z facing +Z; `back` also emits a copy facing -Z (inside of the wall)."""
    emit_to(m, mat, [(x, y, z) for x, y in pts], (0, pts[0][1], z + 5))
    if back is not None:
        emit_to(m, mat, [(x, y, back) for x, y in pts], (0, pts[0][1], back - 5))


def offset(pts, d):
    """Grow a convex outline by d (miter)."""
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        e1 = B.v_norm((p1[0] - p0[0], p1[1] - p0[1], 0))
        e2 = B.v_norm((p2[0] - p1[0], p2[1] - p1[1], 0))
        n1, n2 = (e1[1], -e1[0]), (e2[1], -e2[0])
        bx, by = n1[0] + n2[0], n1[1] + n2[1]
        L = math.hypot(bx, by) or 1
        k = d / max(0.3, (bx * n1[0] + by * n1[1]) / L)
        out.append((p1[0] + bx / L * k, p1[1] + by / L * k))
    return out


def wall(m, side, w, d, u=0.0):
    """Local frame on a wall's outer face: +Z outward, +X along the wall, y up. u = position along."""
    return {"s": m.push((u, 0, d / 2)), "n": m.push((-u, 0, -d / 2), (0, 180, 0)),
            "e": m.push((w / 2, 0, -u), (0, 90, 0)), "w": m.push((-w / 2, 0, u), (0, -90, 0))}[side]


def window(m, y, ww, wh, t=0.2, state="ok", frame="civ_frame", sill="civ_trim", mull=True, head=None):
    """Framed window in a wall's local frame (see wall()). y = centre height."""
    inner = rect_pts(ww, wh, y - wh / 2)
    glass = "civ_win_broken" if state in ("broken", "boarded") else "civ_win"
    pane(m, glass, inner, 0.015, back=-t - 0.015)
    surround(m, frame, inner, offset(inner, 0.08), 0.07, 0.015, 0.0)
    m.box(sill, (ww + 0.3, 0.07, 0.24), (0, y - wh / 2 - 0.1, 0.1))
    if head:
        m.box(head, (ww + 0.3, 0.2, 0.08), (0, y + wh / 2 + 0.18, 0.04))
    if mull and state != "boarded":
        m.box(frame, (0.05, wh, 0.05), (0, y, 0.04))
        m.box(frame, (ww, 0.05, 0.05), (0, y + wh * 0.15, 0.04))
    if state == "boarded":
        rng = random.Random(int(y * 100 + ww * 10 + wh))
        for k in range(3):
            m.box("planks", (ww + 0.3, 0.22, 0.03), (0, y - wh * 0.3 + k * wh * 0.3, 0.1),
                  (0, 0, rng.uniform(-14, 14)))


def tube(m, mat, pts, r, seg=8, caps=True):
    """Smooth pipe through a polyline (rotation-minimising frames)."""
    P = [tuple(map(float, p)) for p in pts]
    n = len(P)
    T = []
    for i in range(n):
        a, b = P[max(0, i - 1)], P[min(n - 1, i + 1)]
        T.append(B.v_norm(B.v_sub(b, a)))
    ref = (0, 0, 1) if abs(T[0][2]) < 0.9 else (1, 0, 0)
    N = B.v_norm(B.v_sub(ref, tuple(T[0][k] * B.v_dot(ref, T[0]) for k in range(3))))
    rows = []
    for i in range(n):
        t = T[i]
        N = B.v_norm(B.v_sub(N, tuple(t[k] * B.v_dot(N, t) for k in range(3))))
        Bn = B.v_cross(N, t)
        row = []
        for j in range(seg):
            a = -2 * math.pi * j / seg
            c, s = math.cos(a) * r, math.sin(a) * r
            row.append(tuple(P[i][k] + c * N[k] + s * Bn[k] for k in range(3)))
        rows.append(row)
    if caps:
        rows = [[P[0]] * seg] + rows + [[P[-1]] * seg]
    m.surface(mat, rows, wrap=True)


def bend(a, b, c, r=0.15, k=3):
    """Polyline a -> b -> c with the corner at b rounded (quadratic bezier), for bent pipes."""
    def lerp(p, q, t):
        return tuple(p[i] + (q[i] - p[i]) * t for i in range(3))
    ab, bc = math.dist(a, b), math.dist(b, c)
    p = lerp(b, a, min(0.45, r / ab))
    q = lerp(b, c, min(0.45, r / bc))
    pts = [a]
    for i in range(k + 1):
        t = i / k
        pts.append(lerp(lerp(p, b, t), lerp(b, q, t), t))
    return pts + [c]


def spandrels(m, mat, arch, top, half, zf, zb):
    """Fill the wall between an arch outline (arch_pts/offset order) and a flat top at y=top, out to
    x=+-half; front face at zf, back face at zb."""
    arc = arch[2:]
    k = len(arc) // 2
    for side in (arc[:k + 1], arc[k:][::-1]):
        sx = 1 if side[0][0] > 0 else -1
        poly = [(sx * half, top), (side[-1][0], top)] + side[::-1] + [(sx * half, side[0][1])]
        for z, t in ((zf, zf + 5), (zb, zb - 5)):
            emit_to(m, mat, [(x, y, z) for x, y in poly], (poly[0][0], poly[0][1], t))


def steps(m, mat, w, n, rise, run, pos=(0, 0, 0), rot=(0, 0, 0)):
    """Flight rising toward -Z, top tread ending at z=0; bottom step front edge at z = n*run."""
    with m.push(pos, rot):
        for i in range(n):
            h = rise * (n - i)
            m.box(mat, (w, h, run), (0, h / 2, run * (i + 0.5)))


def handrail(m, mat, a, b, h=0.9, posts=2, r=0.03):
    """Rail from a to b (ground points), posts included."""
    top = [(p[0], p[1] + h, p[2]) for p in (a, b)]
    tube(m, mat, [(a[0], a[1], a[2]), top[0], top[1], (b[0], b[1], b[2])], r, seg=6)
    for i in range(1, posts):
        t = i / posts
        p = tuple(a[k] + (b[k] - a[k]) * t for k in range(3))
        m.cyl(mat, r * 0.8, r * 0.8, h, p, seg=5, caps=False)


def column(m, mat, h, r, pos, base=True, cap=True, seg=10):
    """Classical column with entasis, torus base and capital."""
    prof = []
    if base:
        prof += [(r * 1.35, 0), (r * 1.35, 0.12 * r), (r * 1.2, 0.3 * r), (r * 1.05, 0.45 * r)]
    else:
        prof += [(r, 0)]
    prof += [(r, h * 0.3), (r * 0.9, h - 0.6 * r)]
    if cap:
        prof += [(r * 1.0, h - 0.45 * r), (r * 1.25, h - 0.2 * r), (r * 1.3, h)]
    else:
        prof += [(r * 0.9, h)]
    m.lathe(mat, prof, pos, seg=seg)
    if cap:
        m.box(mat, (r * 2.8, 0.14, r * 2.8), (pos[0], pos[1] + h + 0.07, pos[2]))


def hvac(m, x, y, z, yaw=0, s=1.0):
    with m.push((x, y, z), (0, yaw, 0), (s, s, s)):
        m.box("metal", (2.2, 0.12, 1.4), (0, 0.06, 0))
        m.box("civ_grille", (2.0, 1.0, 1.2), (0, 0.62, 0), faces={"+y": "metal", "-y": "metal"})
        m.box("metal", (2.1, 0.06, 1.3), (0, 1.15, 0))
        m.lathe("iron", [(0.42, 0), (0.45, 0.1), (0.4, 0.12), (0, 0.13)], (0.45, 1.18, 0), seg=10)
        m.box("rust", (0.9, 0.04, 0.9), (-0.5, 1.2, 0))
        tube(m, "rust", bend((1.0, 0.5, 0), (1.6, 0.5, 0), (1.6, -0.3, 0), 0.3), 0.18, seg=8, caps=False)


def downpipe(m, x, z, h, mat="rust"):
    m.cyl(mat, 0.06, 0.06, h, (x, 0.05, z), seg=6, caps=False)
    m.box(mat, (0.14, 0.18, 0.14), (x, h - 0.1, z))


# ============================================================== school

def m_school():
    m = B.Model("school")
    w, d, h = 36, 14, 7
    rng = random.Random(21)
    m.node("shell-col")
    B.room(m, w, d, 3.6, "civ_brick", door=(0, 2.4, 2.6), floor="ik_lino", ceil=None)
    _school_structure(m, w, d, h)
    m.box("civ_band", (w + 0.5, 0.3, d + 0.5), (0, h + 0.15, 0))  # roof slab / cornice
    m.box("civ_brick", (w + 0.3, 0.6, 0.25), (0, h + 0.6, d / 2 + 0.1))  # parapets
    m.box("civ_brick", (w + 0.3, 0.6, 0.25), (0, h + 0.6, -d / 2 - 0.1))
    m.box("civ_brick", (0.25, 0.6, d), (w / 2 + 0.1, h + 0.6, 0))
    m.box("civ_brick", (0.25, 0.6, d), (-w / 2 - 0.1, h + 0.6, 0))
    # central entrance bay (projects, rises above the parapet with the clock)
    m.box("civ_brick", (5.6, h + 1.6 - 3.0, 0.5), (0, 3.0 + (h + 1.6 - 3.0) / 2, d / 2 + 0.25))
    m.box("civ_brick", (1.4, 3.0, 0.5), (-2.1, 1.5, d / 2 + 0.25))
    m.box("civ_brick", (1.4, 3.0, 0.5), (2.1, 1.5, d / 2 + 0.25))
    # entrance canopy on two round columns
    m.box("civ_band", (5.2, 0.35, 2.6), (0, 3.3, d / 2 + 1.8))
    for x in (-2.3, 2.3):
        column(m, "civ_trim", 3.12, 0.13, (x, 0, d / 2 + 2.8), cap=False)
    m.node("props-col")
    _school_furniture(m, rng)
    m.use("detail")  # made by _school_structure (the stair steps)
    _school_dressing(m, w, d, rng)
    # plinth, floor band, sill band, cornice
    for side, L in (("s", w), ("n", w)):
        with wall(m, side, w, d):
            if side == "s":
                for sx in (-1, 1):
                    m.box("civ_band", (L / 2 - 2.8, 0.5, 0.12), (sx * (L / 4 + 1.4), 0.25, 0.06))
            else:
                m.box("civ_band", (L, 0.5, 0.12), (0, 0.25, 0.06))
            m.box("civ_band", (L + 0.1, 0.3, 0.14), (0, 3.75, 0.07))
            m.box("civ_band", (L + 0.1, 0.12, 0.2), (0, h - 0.3, 0.1))
    for side in ("e", "w"):
        with wall(m, side, w, d):
            m.box("civ_band", (d, 0.5, 0.12), (0, 0.25, 0.06))
            m.box("civ_band", (d + 0.1, 0.3, 0.14), (0, 3.75, 0.07))
            m.box("civ_band", (d + 0.1, 0.12, 0.2), (0, h - 0.3, 0.1))
    # pilasters between window pairs
    for side in ("s", "n"):
        with wall(m, side, w, d):
            for u in (-17.75, -11.5, -5.5, 5.5, 11.5, 17.75):
                m.box("civ_brick", (0.5, h - 0.5, 0.16), (u, 0.5 + (h - 0.5) / 2, 0.08))
                m.box("civ_band", (0.62, 0.2, 0.22), (u, h - 0.1, 0.11))
    xs = [x for x in range(-16, 17, 3) if abs(x) > 2]
    for side in ("s", "n"):
        for x in xs:
            for y in (1.8, 5.3):
                st = rng.random()
                state = "boarded" if st < 0.15 and y < 3 else "broken" if st < 0.35 else "ok"
                with wall(m, side, w, d, x):
                    window(m, y, 1.8, 1.4, state=state, head="civ_band")
    for side in ("e", "w"):
        for u in (-3, 3):
            with wall(m, side, w, d, u):
                window(m, 5.3, 1.6, 1.4, state="broken" if u > 0 else "ok", head="civ_band")
    with wall(m, "e", w, d, 0):
        m.decal("eye", 1.8, 1.8, (0, 2.2, 0.02))
    # entrance bay trim: door frame, fanlight, clock, parapet coping, name band
    with m.push((0, 0, d / 2 + 0.5)):
        door = rect_pts(2.4, 2.6)
        surround(m, "civ_trim", door, offset(door, 0.18)[:2] + offset(door, 0.18)[2:], 0.08, -0.52, 0.0)
        m.box("civ_band", (5.8, 0.25, 0.14), (0, 3.75, 0.07))
        m.box("civ_band", (5.9, 0.2, 0.7), (0, h + 1.7, -0.25))
        m.box("civ_band", (3.8, 0.5, 0.06), (0, 4.4, 0.03))
        m.lathe("civ_trim", [(0.78, 0), (0.78, 0.12), (0.68, 0.14), (0, 0.14)], (0, 6.8, 0), (90, 0, 0), seg=16)
        m.lathe("civ_clock", [(0.7, 0.0), (0.0, 0.0)], (0, 6.8, 0.12), (90, 0, 0), seg=16)
        m.box("iron", (0.06, 0.4, 0.04), (0.08, 6.95, 0.16), (0, 0, -30))
        window(m, 5.3, 2.4, 1.4, state="broken", head="civ_band")
    # canopy fascia + soffit light
    m.box("civ_trim", (5.3, 0.14, 2.7), (0, 3.52, d / 2 + 1.8))
    m.box("bulb_cold", (0.5, 0.04, 0.3), (0, 3.11, d / 2 + 1.6))
    # steps + handrails (decorative; no collision)
    m.box("civ_band", (4.0, 0.12, 1.6), (0, 0.06, d / 2 + 1.3))
    steps(m, "civ_band", 4.0, 1, 0.06, 0.4, (0, 0, d / 2 + 2.1))
    for x in (-1.7, 1.7):
        handrail(m, "iron", (x, 0.12, d / 2 + 0.7), (x, 0.0, d / 2 + 2.5), 0.9)
    # roof: HVAC, vents, ducts, hatch
    hvac(m, -9, h + 0.3, -2)
    hvac(m, 8, h + 0.3, 1.5, 180)
    hvac(m, 14, h + 0.3, -3, 90, 0.8)
    for x, z in ((-14, 3), (3, -4), (-3, 4)):
        m.cyl("rust", 0.18, 0.18, 1.0, (x, h + 0.3, z), seg=8)
        m.lathe("rust", [(0.3, 0), (0.32, 0.05), (0.05, 0.25)], (x, h + 1.3, z), seg=8)
    m.box("metal", (1.0, 0.5, 1.0), (-5, h + 0.55, -4))
    for x in (-w / 2 + 0.2, w / 2 - 0.2):
        for z in (d / 2 + 0.15, -d / 2 - 0.15):
            downpipe(m, x, z, h)
    return m


# School interior (model space: X along the 36 m front, +Z the entrance side, door at x = 0). Ground floor: the
# corridor runs along the entrance wall (z 2.4..6.8); behind it, west to east, the utility room (breaker,
# boiler, basement hatch), classroom 1, the stair hall, the office (Nora's PA), classroom 3 (the art room).
# Upstairs: a north corridor off the stairwell gallery; library, staff room, music room. Scripted spots
# (scripts/chapter2.gd) sit on this plan: breaker, desks #3 / #4, Lily's drawing, key part 2, the patrols.
SC_WALL = 2.4  # corridor | rooms
SC_X = (-13.8, -4.0, 0.4, 4.0)  # utility | classroom 1 | stair hall | office | classroom 3
SC_STAIR = (-2.75, 1.8, 2.1, 6.4)  # flight centre x, bottom z, width, run (climbs toward -Z)
SC_HOLE = (-3.85, -4.65, -1.65, 0.3)
SC_UP = -4.4  # upper corridor (north) | upper rooms
SC_ROWS = (-5.6, -4.1, -2.6, -1.1, 0.4)  # desk rows (z), both classrooms: the aisle z 1.0..2.4 stays clear
SC_DESKS_1 = (-11.0, -9.4, -7.8, -6.2)  # classroom 1 desk columns (x), pupils face -X
SC_DESKS_3 = (10.6, 12.2, 13.8, 15.4)  # classroom 3, pupils face +X


def _school_structure(m, w, d, h):
    hw, hd = w / 2 - 0.2, d / 2 - 0.2
    # upper storey: outer walls from the ground ceiling to the roof, the floor between with its stairwell
    for z in (d / 2 - 0.1, -d / 2 + 0.1):
        m.box("civ_brick", (w, h - 3.6, 0.2), (0, 3.6 + (h - 3.6) / 2, z))
    for x in (w / 2 - 0.1, -w / 2 + 0.1):
        m.box("civ_brick", (0.2, h - 3.6, d - 0.4), (x, 3.6 + (h - 3.6) / 2, 0))
    K.slab(m, "tile", -hw, -hd, hw, hd, 3.8, 0.2, SC_HOLE)
    # ground floor walls
    wall = "ik_wall_cream"
    K.partition(m, wall, (-hw, SC_WALL), (hw, SC_WALL), 0.05, 3.55, trim="ik_wain_school", doors=[
        (-15.3 + hw, 1.3, 2.2, 75), (-5.2 + hw, 1.6, 2.2, 80), (-2.0 + hw, 4.2, 3.0, None),
        (2.2 + hw, 1.1, 2.2, 60), (6.2 + hw, 1.6, 2.2, 85), (15.0 + hw, 1.6, 2.2, 70)])
    for x in SC_X:
        K.partition(m, wall, (x, -hd), (x, SC_WALL), 0.05, 3.55, trim="ik_wain_school")
    # upper floor walls: rooms on the south, the corridor on the north, the stairwell gallery open between
    up = 3.8
    K.partition(m, wall, (-hw, SC_UP), (SC_X[1], SC_UP), up, 3.2, trim="ik_wain_school", swing=1,
                doors=[(-8.5 + hw, 1.6, 2.2, 80)])
    K.partition(m, wall, (SC_X[2], SC_UP), (hw, SC_UP), up, 3.2, trim="ik_wain_school", swing=1,
                doors=[(3.0 - SC_X[2], 1.1, 2.2, 70), (12.5 - SC_X[2], 1.6, 2.2, 85)])
    for x in (SC_X[1], SC_X[2], 8.0):
        K.partition(m, wall, (x, SC_UP), (x, hd), up, 3.2, trim="ik_wain_school")
    # the flight itself (steps are dressing, the ramp is its collision)
    with K._On(m, "detail"):
        x, z0, sw, run = SC_STAIR
        K.stairs(m, (x, 0.05, z0), 0, sw, run, 3.75, mat="civ_band", tread="ik_lino", walls=(False, True),
                 block=(False, True))
        hx0, hz0, hx1, hz1 = SC_HOLE
        K.guard(m, "ik_rail", [(hx1, hz0 + 0.9), (hx1, hz1), (hx0, hz1)], up)


def _school_furniture(m, rng):
    # utility room: boiler, the breaker panel (BREAKER), shelves, the hatch down to the basement
    m.cyl("rust", 0.6, 0.6, 2.2, (-16.4, 0.05, -5.4), seg=10)
    m.box("metal", (0.35, 0.8, 0.6), (-17.62, 1.3, 0.0))  # breaker panel on the west wall
    K.shelf_unit(m, -14.5, -6.75, 0, 1.4, 1.9, 0.45, "ik_bottles")
    # classroom 1 (a normal classroom): board on the west wall, the teacher's desk (#3) before it, pupils in
    # 4 x 5 rows facing it (-X); the door at the back (east end) of the corridor wall, and a clear aisle along
    # that wall (z 1.0..2.4) from the door to the front
    K.teacher_desk(m, -12.4, -2.2, -90)
    for x in SC_DESKS_1:
        for z in SC_ROWS:
            K.student_desk(m, x, z, 90, tipped=rng.random() < 0.06)
    K.shelf_unit(m, -4.6, -6.75, 0, 1.0, 1.5, 0.35)
    # office: the principal's desk with the PA console, filing, a bookcase
    K.teacher_desk(m, 2.2, -4.2, 180)
    K.shelf_unit(m, 3.5, -1.0, -90, 1.4, 2.0, 0.35)
    # classroom 3: the art corner by the west door (the drawing table: Lily's drawing, easels, paint), then
    # 4 x 5 rows facing the board on the east wall (+X); the same aisle along the corridor wall, and a lane
    # at x ~8.6 between the art corner and the rows
    B.table(m, 6.6, -3.0, 1.6, 1.0, 0.72, "ik_wood")
    for dx in (-0.5, 0.5):
        K.chair(m, 6.6 + dx, -3.75, 180)
        K.chair(m, 6.6 + dx, -2.25, 0)
    for x in SC_DESKS_3:
        for z in SC_ROWS:
            K.student_desk(m, x, z, -90, tipped=rng.random() < 0.06)
    K.teacher_desk(m, 16.6, -2.2, 90)
    K.shelf_unit(m, 9.0, -6.75, 0, 1.4, 1.6, 0.4, "ik_bottles")  # paint pots
    # corridor: lockers along the classroom wall between the doors
    for x0, x1 in ((-13.8, -7.0), (8.0, 13.4)):  # two banks, a metre clear of every door
        K.lockers(m, x0, x1, SC_WALL + 0.08, 0)
    # upstairs: library stacks + reading tables, staff room, music room
    for x in (-16.6, -14.6, -12.6):
        K.shelf_unit(m, x, -1.0, 90, 3.2, 2.2, 0.45)
        K.shelf_unit(m, x + 0.95, -1.0, -90, 3.2, 2.2, 0.45)
    for x, z in ((-9.0, 1.5), (-6.2, 1.5), (-9.0, 4.6)):
        with m.push((0, 3.8, 0)):
            B.table(m, x, z, 1.8, 0.9, 0.74, "ik_wood")
            for dx in (-0.5, 0.5):
                K.chair(m, x + dx, z - 0.7, 180)
                K.chair(m, x + dx, z + 0.7, 0)
    with m.push((0, 3.8, 0)):
        B.table(m, 4.2, 2.0, 2.2, 1.0, 0.74, "ik_wood_dark")
        for dx in (-0.7, 0.0, 0.7):
            K.chair(m, 4.2 + dx, 1.3, 180, "ik_blue")
            K.chair(m, 4.2 + dx, 2.7, 0, "ik_blue")
        K.counter(m, 7.3, 5.8, 90, 1.8, 0.6, 0.9)
        m.box("ik_black", (1.5, 1.2, 0.6), (13.0, 0.6, 5.9))  # upright piano
        for k in range(8):
            a = math.radians(-60 + k * 17)
            K.chair(m, 12.5 + math.sin(a) * 3.0, 1.2 - math.cos(a) * 3.0 + 3.0, -math.degrees(a) + 180)


def _school_dressing(m, w, d, rng):
    hw, hd = w / 2 - 0.2, d / 2 - 0.2
    K.lining(m, "ik_wall_cream", hw, hd, 0.05, 3.55, (0, 2.4, 2.6), "ik_wain_school")
    K.lining(m, "ik_wall_cream", hw, hd, 3.82, 3.18, None, "ik_wain_school")
    xs = [x for x in range(-16, 17, 3) if abs(x) > 2]
    for y in (1.8, 5.3):
        K.inner_windows(m, "civ_win", -hw, hw, -hd, y, xs, 1.7, 1.3, 1)
        K.inner_windows(m, "civ_win", -hw, hw, hd, y, xs, 1.7, 1.3, -1)
    m.box("tile", (w - 0.4, 0.04, d - 0.4), (0, h_school_ceiling() - 0.02, 0))
    K.slab(m, "ik_wood", -hw, -hd, hw, hd, 3.82, 0.02, SC_HOLE)  # upstairs floorboards
    # ceiling lights: corridor strip, classrooms in rows, upstairs dimmer and half dead
    for x in range(-16, 17, 3):
        K.lamp(m, x, 3.58, 4.6, lit=rng.random() > 0.3)
        K.lamp(m, x, 6.98, -5.6, lit=rng.random() > 0.6)
    for x in (-11.5, -7.5, 8.0, 12.0, 15.5):
        for z in (-4.5, -0.5):
            K.lamp(m, x, 3.58, z, lit=rng.random() > 0.4)
    # corridor: boards over the lockers, drawings, exits, extinguishers, a clock, a water fountain, bins
    for x in (-11.5, -5.6, 9.5, 12.8):
        K.board(m, "ik_cork", x, 2.45, SC_WALL + 0.08, 0, 1.4, 0.8)
    K.board(m, "ik_drawings", 16.7, 2.4, SC_WALL + 0.08, 0, 1.4, 0.5)
    for x in (-15.0, -9.2, 5.2, 9.2):
        K.board(m, "ik_drawings", x, 2.5, hd, 180, 1.1, 0.45)
    K.exit_sign(m, 0, 2.85, hd - 0.02, 180)
    K.exit_sign(m, -hw + 0.02, 2.6, 4.6, 90)
    K.extinguisher(m, -16.5, SC_WALL + 0.08, 0)
    K.extinguisher(m, 17.7, 4.0, -90)
    K.clock(m, -2.0, 3.0, SC_WALL + 0.1, 0)
    with m.push((1.2, 0, SC_WALL + 0.1)):  # water fountain
        m.box("ik_steel", (0.45, 0.2, 0.35), (0, 0.9, 0.17))
        m.box("ik_steel", (0.1, 0.8, 0.1), (0, 0.4, 0.08))
    for x in (-10.0, 4.8, 16.5):
        K.bin_(m, x, 6.3)
    # stair hall: trophy case, notice board, bench
    with m.push((SC_X[2] - 0.25, 0, -3.0)):
        m.box("ik_wood_dark", (0.45, 0.9, 1.8), (0, 0.45, 0))
        m.box("glass", (0.4, 1.2, 1.7), (0, 1.5, 0))
        for k in range(4):
            m.cyl("ik_brass", 0.05, 0.08, 0.3, (0, 1.0, -0.6 + k * 0.4), seg=6)
    K.board(m, "ik_poster_a", SC_X[2] - 0.08, 2.0, 0.5, -90, 1.6, 0.6)
    # utility room: pipes up the wall, mop bucket, the basement hatch, the breaker's cable run
    for z in (-6.2, -5.9):
        m.cyl("rust", 0.05, 0.05, 3.5, (-17.5, 0.05, z), seg=6)
    m.box("rust", (1.2, 0.04, 0.05), (-17.0, 3.2, -5.9))
    m.box("metal", (1.2, 0.03, 1.2), (-15.8, 0.07, -2.4))  # basement hatch
    m.box("iron", (0.3, 0.05, 0.05), (-15.8, 0.1, -1.95))
    m.cyl("ik_blue", 0.18, 0.2, 0.32, (-14.6, 0.05, 1.6), seg=8)
    m.box("metal", (0.06, 1.6, 0.06), (-17.62, 2.3, 0.0))  # conduit from the breaker
    m.box("ik_red", (0.3, 0.12, 0.02), (-17.44, 1.8, 0.0))  # DANGER plate
    # classroom 1: board, alphabet frieze, drawings, clock, radiators, coat hooks
    K.blackboard(m, SC_X[0] + 0.1, 1.55, -2.4, 90, 3.6)
    K.board(m, "ik_poster_a", SC_X[0] + 0.1, 2.75, -2.4, 90, 3.6, 0.35)
    K.board(m, "ik_drawings", -9.0, 2.2, -hd, 0, 2.4, 0.6)
    K.clock(m, SC_X[1] - 0.1, 2.8, -2.0, -90)
    for x in (-10.0, -7.0):
        K.radiator(m, x, -hd, 0, 1.0)
    for z in (-6.2, -5.6, -5.0, -4.4):
        m.box("ik_brass", (0.04, 0.04, 0.12), (SC_X[1] - 0.12, 1.5, z))
        m.box(rng.choice(("jacket", "ik_blue", "ik_red")), (0.08, 0.5, 0.28), (SC_X[1] - 0.2, 1.2, z))
    m.box("ik_blue", (0.3, 0.4, 0.05), (-12.5, 0.84, -2.7))  # globe stand's base on the teacher's desk
    m.ellipsoid("ik_map", (0.14, 0.14, 0.14), (-12.5, 1.12, -2.7), seg=8, rings=6)
    # office: the PA console, the flag, certificates
    with m.push((2.2, 0.81, -4.4)):
        m.box("ik_black", (0.5, 0.1, 0.3), (0, 0.05, 0))
        m.cyl("ik_steel", 0.01, 0.01, 0.25, (0.15, 0.1, 0), (20, 0, 0), seg=4)
        m.ellipsoid("ik_black", (0.03, 0.04, 0.03), (0.15, 0.36, 0.04), seg=6, rings=4)
    for k in range(3):
        K.board(m, "white", 0.7 + k * 0.6, 2.1, -hd, 0, 0.4, 0.3, "ik_brass")
    # classroom 3: easels by the windows, drying rack, drawings everywhere, board + frieze
    K.blackboard(m, hw - 0.02, 1.55, -2.4, -90, 3.6)
    K.board(m, "ik_poster_a", hw - 0.02, 2.75, -2.4, -90, 3.6, 0.35)
    for x in (5.2, 8.0, 11.0, 14.0):
        K.board(m, "ik_drawings", x, 2.3, -hd, 0, 2.2, 0.6)
    for x in (5.2, 7.2):  # easels in the art corner, by the windows
        with m.push((x, 0, -5.9), (0, 15 * (x - 6.2), 0)):
            for sx in (-1, 1):
                m.box("ik_wood", (0.04, 1.6, 0.04), (sx * 0.3, 0.8, 0.1), (-10, 0, 0))
            m.box("ik_wood", (0.04, 1.5, 0.04), (0, 0.75, -0.25), (15, 0, 0))
            m.box("ik_drawings", (0.6, 0.45, 0.02), (0, 1.25, 0.14), (-10, 0, 0))
    for z in (-6.0, -5.4):
        K.radiator(m, 11.0, -hd, 0, 1.2)
    # upstairs: library signs + posters, staff room noticeboard, music stands, the corridor's benches
    K.board(m, "ik_map", -5.0, 5.5, SC_UP - 0.08, 180, 1.4, 0.9)
    K.board(m, "ik_cork", 6.0, 5.4, hd, 180, 1.6, 0.9)
    for x in (-12.0, 6.0, 14.0):
        with m.push((x, 3.8, SC_UP - 0.35)):
            m.box("ik_wood", (1.6, 0.05, 0.4), (0, 0.45, 0))
            for sx in (-0.7, 0.7):
                m.box("ik_steel", (0.05, 0.45, 0.35), (sx, 0.225, 0))
    for k in range(5):
        with m.push((10.5 + k * 1.1, 3.8, 3.5 - abs(k - 2) * 0.4)):
            m.cyl("ik_black", 0.012, 0.012, 1.1, (0, 0, 0), seg=4)
            m.box("ik_black", (0.45, 0.3, 0.02), (0, 1.15, 0), (-25, 0, 0))
    K.exit_sign(m, -1.0, 6.3, -hd + 0.02, 0)


def h_school_ceiling():
    return 3.6


# ============================================================== clinic

def m_clinic():
    m = B.Model("clinic")
    w, d, h = 28, 14, 7.5
    rng = random.Random(33)
    m.node("shell-col")
    B.room(m, w, d, 3.6, "civ_panel", door=(0, 2.4, 2.6), floor="ik_lino", ceil=None)
    _clinic_structure(m, w, d, h)
    m.box("civ_band", (w + 0.8, 0.9, d + 0.8), (0, h - 0.35, 0))  # deep 70s fascia
    # glass entrance canopy: steel posts
    for x in (-3.2, 3.2):
        for z in (d / 2 + 1.0, d / 2 + 3.6):
            m.box("civ_alu", (0.16, 3.2, 0.16), (x, 1.6, z))
    # ambulance bay porte-cochere on the +X end
    for z in (-3.2, 3.2):
        m.box("civ_band", (0.4, 3.9, 0.4), (w / 2 + 5.0, 1.95, z))
    m.box("civ_band", (5.6, 0.5, 7.4), (w / 2 + 2.6, 4.15, 0))
    m.node("props-col")
    for i, x in enumerate(range(3, 13, 3)):  # the ward's beds (hiding beside them: scripts/chapter2.gd)
        with m.push((x, 0, -2 + (i % 2) * 0.6), (0, 90 + i * 7, 0)):
            m.box("metal", (0.7, 0.08, 2.0), (0, 0.8, 0))
            m.box("sheet", (0.65, 0.1, 1.9), (0, 0.88, 0))
            m.box("white", (0.5, 0.1, 0.3), (0, 0.97, -0.75))
            m.box("metal", (0.72, 0.5, 0.04), (0, 1.05, -1.0))
            for lx in (-0.3, 0.3):
                for lz in (-0.9, 0.9):
                    m.cyl("metal", 0.02, 0.02, 0.8, (lx, 0, lz), seg=4)
    _clinic_furniture(m, rng)
    m.use("detail")  # made by _clinic_structure (the stair steps)
    _clinic_dressing(m, w, d, rng)
    # plinth + spandrel bands
    for side, L in (("s", w), ("n", w), ("e", d), ("w", d)):
        with wall(m, side, w, d):
            if side == "s":
                for sx in (-1, 1):
                    m.box("civ_band", (L / 2 - 1.2, 0.45, 0.1), (sx * (L / 4 + 0.6), 0.225, 0.05))
            else:
                m.box("civ_band", (L, 0.45, 0.1), (0, 0.225, 0.05))
            m.box("civ_frame", (L, 0.5, 0.06), (0, 3.85, 0.03))
    # ribbon windows: aluminium frames, continuous sills
    xs = [x for x in range(-12, 13, 3) if abs(x) > 2]
    for side in ("s", "n"):
        with wall(m, side, w, d):
            for y in (1.8, 5.2):
                m.box("civ_band", (w - 1.0, 0.1, 0.3), (0, y - 0.82, 0.15))
        for x in xs:
            for y in (1.8, 5.2):
                st = rng.random()
                state = "boarded" if st < 0.2 else "broken" if st < 0.4 else "ok"
                with wall(m, side, w, d, x):
                    window(m, y, 2.4, 1.4, state=state, frame="civ_alu", sill="civ_alu", mull=False)
                    if state != "boarded":
                        m.box("civ_alu", (0.05, 1.4, 0.05), (-0.4, y, 0.04))
                        m.box("civ_alu", (0.05, 1.4, 0.05), (0.4, y, 0.04))
    # entrance: aluminium door frame + transom, glass canopy roof, red-cross sign board
    with wall(m, "s", w, d):
        door = rect_pts(2.4, 2.6)
        surround(m, "civ_alu", door, offset(door, 0.12), 0.06, -0.2, 0.0)
        pane(m, "civ_win", rect_pts(2.4, 0.6, 2.75), 0.02)
        m.box("civ_alu", (2.7, 0.08, 0.1), (0, 2.68, 0.05))
    m.box("civ_alu", (6.8, 0.18, 0.18), (0, 3.2, d / 2 + 3.6))
    m.box("civ_alu", (6.8, 0.18, 0.18), (0, 3.2, d / 2 + 1.0))
    for x in (-3.2, -1.1, 1.1, 3.2):
        m.box("civ_alu", (0.1, 0.14, 3.8), (x, 3.35, d / 2 + 1.9))
    m.box("civ_canopy", (6.6, 0.04, 3.9), (0, 3.45, d / 2 + 1.95), (-4, 0, 0))
    m.box("glass", (1.8, 1.2, 0.04), (2.1, 3.4, d / 2 + 2.3), (-4, 0, 0))  # a smashed pane
    m.box("bulb_cold", (0.6, 0.04, 0.3), (0, 3.08, d / 2 + 2.0))
    with m.push((0, 0, d / 2 + 0.42)):
        m.box("civ_frame", (2.3, 2.3, 0.12), (0, 5.3, 0))
        m.box("civ_sign", (2.1, 2.1, 0.04), (0, 5.3, 0.07), faces={"-z": "civ_frame"})
        for x in (-0.9, 0.9):
            m.box("iron", (0.06, 0.06, 0.4), (x, 6.5, -0.2))
    # free-standing sign pylon by the path
    m.node("sign-col")
    with m.push((-5.5, 0, d / 2 + 5.5)):
        for x in (-0.55, 0.55):
            m.box("civ_alu", (0.1, 2.4, 0.1), (x, 1.2, 0))
        m.box("civ_frame", (1.3, 1.3, 0.1), (0, 1.9, 0))
        m.box("civ_sign", (1.2, 1.2, 0.04), (0, 1.9, 0.06), faces={"-z": "civ_frame"})
        m.box("civ_band", (1.4, 0.3, 0.4), (0, 0.15, 0))
    m.use("detail")
    # entrance apron with handrails (flush, 5 cm lip)
    m.box("civ_band", (3.4, 0.05, 1.2), (0, 0.025, d / 2 + 0.6))
    for x in (-1.6, 1.6):
        handrail(m, "civ_alu", (x, 0.0, d / 2 + 0.3), (x, 0.0, d / 2 + 3.4), 0.9, posts=3)
    # ambulance bay: wide doors, canopy fascia, stripes, bollards
    with wall(m, "e", w, d):
        m.box("metal", (3.0, 2.8, 0.08), (0, 1.4, 0.04))
        m.box("iron", (0.04, 2.8, 0.1), (0, 1.4, 0.06))
        for x in (-0.75, 0.75):
            pane(m, "civ_win_broken" if x > 0 else "civ_win", rect_pts(0.5, 0.6, 1.6), 0.09)
            pane(m, "civ_win", rect_pts(0.5, 0.6, 1.6), 0.09)
        m.box("civ_alu", (3.3, 0.15, 0.15), (0, 2.88, 0.08))
        m.box("bulb_red", (0.25, 0.2, 0.12), (0, 3.25, 0.1))
    m.box("civ_stripe", (4.6, 0.4, 7.5), (w / 2 + 2.6, 4.6, 0), faces={"+y": "metal", "-y": "civ_band"})
    m.box("bulb_cold", (0.4, 0.04, 1.2), (w / 2 + 2.6, 3.89, 0))
    for z in (-2.2, 2.2):
        m.box("civ_stripe", (4.5, 0.01, 0.12), (w / 2 + 2.6, 0.005, z))
    m.box("civ_stripe", (0.12, 0.01, 4.4), (w / 2 + 4.8, 0.005, 0))
    for z in (-3.2, -1.2, 1.2, 3.2):
        m.cyl("civ_yellow", 0.1, 0.1, 0.9, (w / 2 + 5.8, 0, z), seg=8)
    # roof: HVAC units, big exhaust ducts (as before, upgraded)
    for x in (-8, 0, 8):
        hvac(m, x, h + 0.1, -2.5, rng.choice((0, 180)))
        m.cyl("rust", 0.3, 0.3, 1.6, (x + 2, h + 0.1, 2.5), seg=10)
        m.lathe("rust", [(0.45, 0), (0.45, 0.06), (0.1, 0.35)], (x + 2, h + 1.7, 2.5), seg=10)
    for x in (-w / 2 - 0.2, w / 2 + 0.2):
        for z in (d / 2 - 0.3, -d / 2 + 0.3):
            downpipe(m, x, z, h - 0.8)
    return m


# Clinic interior (model space: X along the 28 m front, +Z the entrance side, door at x = 0). Ground floor:
# the hall along the entrance (reception, waiting, the nurses' station with key part 3, the main stair up
# beside the door); behind it, west to east: morgue & records (freezer, Sam's file) walled off at CL_X[0], the
# exam room, the pharmacy, and the open ward (curtained bays, the triage bay). Upstairs: patient rooms, the
# records archive, the staff room and the operating theatre off a central corridor; the roof hatch lands on
# the west landing. Scripted spots (scripts/chapter2.gd) sit on this plan.
CL_X = (-9.4, -2.4, 3.2)  # morgue | exam | pharmacy | ward
CL_BACK = -1.2  # hall | back rooms
CL_STAIR = (-3.5, 5.8, 1.6, 5.8)  # bottom x, centre z, width, run (climbs toward -X)
CL_HOLE = (-9.45, 4.95, -5.1, 6.8)
CL_UP = (-1.0, 1.0)  # upper corridor walls (z)


def _clinic_structure(m, w, d, h):
    hw, hd = w / 2 - 0.2, d / 2 - 0.2
    for z in (d / 2 - 0.1, -d / 2 + 0.1):
        m.box("civ_panel", (w, h - 4.4, 0.2), (0, 3.6 + (h - 4.4) / 2, z))
    for x in (w / 2 - 0.1, -w / 2 + 0.1):
        m.box("civ_panel", (0.2, h - 4.4, d - 0.4), (x, 3.6 + (h - 4.4) / 2, 0))
    K.slab(m, "tile", -hw, -hd, hw, hd, 3.8, 0.2, CL_HOLE)
    wall = "ik_wall_mint"
    # ground floor
    K.partition(m, wall, (CL_X[0], -hd), (CL_X[0], hd), 0.05, 3.55, trim="ik_wain", doors=[(hd + 4.5, 2.0, 2.3, 80)])
    K.partition(m, wall, (CL_X[0], CL_BACK), (CL_X[1], CL_BACK), 0.05, 3.55, trim="ik_wain", doors=[(3.4, 1.2, 2.2, 70)])
    K.partition(m, wall, (CL_X[1], -hd), (CL_X[1], CL_BACK), 0.05, 3.55, trim="ik_wain")
    K.partition(m, wall, (CL_X[1], CL_BACK), (CL_X[2], CL_BACK), 0.05, 3.55, trim="ik_wain", doors=[(2.8, 1.2, 2.2, 60)])
    K.partition(m, wall, (CL_X[2], -hd), (CL_X[2], CL_BACK), 0.05, 3.55, trim="ik_wain")
    m.box("glass", (1.2, 0.8, 0.04), (0.9, 1.6, CL_BACK))  # pharmacy hatch window (sealed)
    # upstairs: corridor between the room rows, a landing at the west end over the morgue
    up, uh = 3.8, 2.88
    K.partition(m, wall, (CL_X[0], CL_UP[0]), (hw, CL_UP[0]), up, uh, trim="ik_wain",
                doors=[(3.7, 1.2, 2.2, 70), (10.9, 1.2, 2.2, 80), (18.8, 1.6, 2.2, 85)])
    K.partition(m, wall, (-5.1, CL_UP[1]), (hw, CL_UP[1]), up, uh, trim="ik_wain", swing=1,
                doors=[(3.5, 1.2, 2.2, 75), (10.1, 1.2, 2.2, 60), (16.1, 1.8, 2.2, 88)])
    for x in (CL_X[0], -2.0, 5.0):
        K.partition(m, wall, (x, -hd), (x, CL_UP[0]), up, uh, trim="ik_wain")
    for x in (-5.1, 2.0, 8.0):
        K.partition(m, wall, (x, CL_UP[1]), (x, hd), up, uh, trim="ik_wain")
    with K._On(m, "detail"):
        x0, zc, sw, run = CL_STAIR
        K.stairs(m, (x0, 0.05, zc), 90, sw, run, 3.75, mat="civ_band", tread="ik_lino", walls=(True, True),
                 block=(False, True))  # right = the hall side
        hx0, hz0, hx1, hz1 = CL_HOLE
        K.guard(m, "ik_rail", [(hx0 + 0.6, hz0), (hx1, hz0)], up)


def _clinic_furniture(m, rng):
    hw, hd = 13.8, 6.8
    # hall: reception by the door, the nurses' station (KEY3 on its counter), waiting seats, a gurney
    K.counter(m, 4.5, 5.45, 180, 2.6, 0.7, 1.05)
    K.counter(m, -3.0, 2.8, 0, 3.4, 0.8, 1.05)
    K.counter(m, -4.35, 2.0, 90, 0.8, 0.8, 1.05)
    K.chair_row(m, 7.5, 12.5, 6.2, 180)
    K.chair_row(m, 8.0, 12.0, 3.1, 0)
    with m.push((-7.5, 0, 3.2), (0, 90, 0)):  # gurney parked against the stair's side
        m.box("ik_steel", (0.7, 0.06, 2.0), (0, 0.85, 0))
        m.box("sheet", (0.65, 0.12, 1.9), (0, 0.93, 0))
        for lx in (-0.3, 0.3):
            for lz in (-0.9, 0.9):
                m.box("ik_steel", (0.03, 0.85, 0.03), (lx, 0.425, lz))
    # morgue & records: the freezer on the south wall (the "morgue freezer" marker), an autopsy table, a sink
    with m.push((-11.7, 0, 0.3)):
        m.cyl("ik_steel", 0.15, 0.2, 0.85, (0, 0, 0), seg=8)
        m.box("ik_steel", (0.8, 0.08, 2.1), (0, 0.9, 0))
        m.box("ik_steel", (0.85, 0.06, 0.05), (0, 0.96, 1.05))
    K.sink(m, -13.3, -2.5, 90)
    # exam room: couch, desk, screen, cabinets
    with m.push((-8.0, 0, -4.8)):
        m.box("ik_beige", (0.7, 0.65, 1.9), (0, 0.33, 0))
        m.box("ik_blue", (0.68, 0.1, 1.9), (0, 0.7, 0))
        m.box("ik_blue", (0.68, 0.35, 0.5), (0, 0.85, -0.7), (25, 0, 0))
    K.teacher_desk(m, -4.2, -5.6, 180)
    K.shelf_unit(m, -6.0, -6.75, 0, 1.2, 1.9, 0.4, "ik_bottles")
    # pharmacy: glass cabinets on every wall (the lockpicked one on the north wall), a dispensing bench
    for x in (-1.6, 0.4, 2.4):
        K.shelf_unit(m, x, -6.75, 0, 1.6 if x < 2 else 1.2, 2.0, 0.4, "ik_bottles")
    K.shelf_unit(m, 3.0, -4.0, -90, 1.8, 2.0, 0.35, "ik_bottles")
    B.table(m, 0.4, -3.3, 2.2, 0.7, 0.9, "ik_beige")
    # ward: bedside cabinets between the beds, the triage bay's monitor
    for x in (4.5, 7.5, 10.5):
        K.bedside(m, x, -3.6, 0)
    # upstairs (floor at 3.8): patient rooms north, archive / staff room / theatre south
    with m.push((0, 3.8, 0)):
        for x in (-8.2, -4.6, -0.6, 3.4, 6.4, 11.6):
            with m.push((x, 0, -5.4)):
                m.box("ik_steel", (0.95, 0.5, 2.0), (0, 0.25, 0.3))
                m.box("sheet", (0.9, 0.14, 1.9), (0, 0.57, 0.3))
                m.box("white", (0.55, 0.1, 0.3), (0, 0.67, -0.5))
        for x in (-4.5, -3.3, -2.1, -0.9, 0.3, 1.5):
            K.shelf_unit(m, x, 3.2, 0, 1.0, 2.2, 0.5, "int_books")
        B.table(m, 5.0, 4.0, 1.8, 0.9, 0.74, "ik_wood")
        for dx in (-0.5, 0.5):
            K.chair(m, 5.0 + dx, 3.3, 180, "ik_blue")
            K.chair(m, 5.0 + dx, 4.7, 0, "ik_blue")
        K.counter(m, 7.4, 5.9, 90, 1.6, 0.6, 0.9)
        with m.push((11.0, 0, 4.0)):  # the theatre: table, lamp, instrument trolley
            m.box("ik_steel", (0.2, 0.9, 0.2), (0, 0.45, 0))
            m.box("ik_steel", (0.7, 0.1, 2.0), (0, 0.95, 0))
            m.box("ik_green", (0.72, 0.04, 1.9), (0, 1.02, 0))
            B.table(m, 1.2, 0.8, 0.7, 0.4, 0.9, "ik_steel")


def _clinic_dressing(m, w, d, rng):
    hw, hd = w / 2 - 0.2, d / 2 - 0.2
    K.lining(m, "ik_wall_mint", hw, hd, 0.05, 3.55, (0, 2.4, 2.6), "ik_wain")
    K.lining(m, "ik_wall_mint", hw, hd, 3.82, 2.86, None, "ik_wain")
    xs = [x for x in range(-12, 13, 3) if abs(x) > 2]
    for y in (1.8, 5.2):
        K.inner_windows(m, "civ_win", -hw, hw, -hd, y, xs, 1.9, 1.2, 1)
        K.inner_windows(m, "civ_win", -hw, hw, hd, y, xs, 1.9, 1.2, -1)
    K.slab(m, "ik_lino", -hw, -hd, hw, hd, 3.82, 0.02, CL_HOLE)
    m.box("tile", (w - 0.4, 0.04, d - 0.4), (0, 6.68, 0))
    for x in range(-12, 13, 3):  # hall strip, ward, upstairs corridor; a third are dead
        K.lamp(m, x, 3.58, 4.2, lit=rng.random() > 0.35)
        K.lamp(m, x + 1.5, 6.66, 0.0, lit=rng.random() > 0.6)
    for x in (-11.6, -6.0, 0.4, 6.0, 9.0, 12.0):
        K.lamp(m, x, 3.58, -3.5, lit=rng.random() > 0.4)
    # ward: bay curtains, headwalls, the bays' numbers
    for x in (4.5, 7.5, 10.5):
        K.curtain(m, x, -6.6, -2.2, 2.3, 0.55 + 0.15 * rng.random())
    for x in (3.0, 6.0, 9.0, 12.0):
        K.headwall(m, x, -hd, 0)
    K.curtain(m, CL_BACK + 0.4, 3.4, 13.6, 2.3, 0.3, along_z=False)
    # hall: signage, posters, the red cross, exits, extinguishers, a clock, a vending machine, bins
    K.board(m, "civ_sign", 0.0, 3.0, CL_BACK - 0.02, 180, 0.8, 0.8)
    for x, mat in ((-7.2, "ik_poster_b"), (-5.8, "ik_cork"), (6.6, "ik_poster_b"), (12.8, "ik_chart")):
        K.board(m, mat, x, 1.8, hd, 180, 0.9, 1.2)
    K.board(m, "ik_poster_b", 1.6, 1.7, CL_BACK - 0.08, 180, 0.8, 1.0)
    K.exit_sign(m, 0.0, 2.85, hd - 0.02, 180)
    K.exit_sign(m, hw - 0.02, 2.6, 3.0, -90)
    K.extinguisher(m, CL_X[0] + 0.08, 1.8, 90)
    K.extinguisher(m, hw - 0.02, 5.0, -90)
    K.clock(m, -3.0, 2.9, CL_BACK - 0.1, 180)
    with m.push((2.2, 0, 6.3)):  # vending machine by the entrance
        m.box("hh_vend", (0.9, 1.85, 0.8), (0, 0.93, 0))
    for x in (2.5, 13.0):
        K.bin_(m, x, 6.3)
    # morgue & records: tag rack, the cold light, records boxes on the cabinets, a body bag on the table
    m.box("sheet", (0.55, 0.2, 1.7), (-11.7, 1.04, 0.3))
    for z in (-6.0, -5.2, -4.4):
        m.box("ik_beige", (0.4, 0.3, 0.35), (-13.2, 1.45, z))
    K.board(m, "ik_chart", -9.52, 1.6, -3.0, -90, 0.7, 0.9)
    # exam room: eye chart, privacy screen, a sink, the scales
    K.board(m, "ik_chart", CL_X[1] - 0.08, 1.6, -3.0, -90, 0.6, 0.9)
    K.sink(m, -9.3, -3.5, 90)
    with K._On(m, "curtain_cloth"):  # (cloth, by the back door: no collision, like the bay curtains)
        for k in range(3):
            m.box("ik_curtain", (0.9, 1.6, 0.03), (-6.5 + k * 0.85, 0.95, -2.2), (0, 20 - 20 * k, 0))
    # pharmacy: order sheets, a fallen tray of pills
    K.board(m, "ik_cork", CL_X[2] - 0.08, 1.7, -2.4, -90, 0.8, 0.6)
    for k in range(9):
        m.box(rng.choice(("white", "ik_red", "ik_blue")), (0.03, 0.02, 0.05),
              (0.2 + rng.uniform(-0.6, 0.6), 0.07, -2.2 + rng.uniform(-0.4, 0.4)))
    # upstairs: room numbers, a crash cart, the theatre's lamp and green tiles, archive boxes
    for x in (-5.2, 0.9, 7.4):
        K.board(m, "white", x, 5.9, CL_UP[0] + 0.08, 0, 0.3, 0.15, "ik_black")
    with m.push((11.0, 3.8, 4.0)):
        m.cyl("ik_steel", 0.02, 0.02, 1.2, (0, 1.7, 0), seg=4)
        m.cyl("ik_steel", 0.45, 0.2, 0.2, (0, 1.6, 0), seg=10)
        m.cyl("ik_lamp", 0.35, 0.35, 0.02, (0, 1.58, 0), seg=10)
    m.box("ik_green", (5.6, 1.6, 0.02), (10.9, 4.65, hd - 0.03))
    # the roof hatch over the west landing (the way down from the vents: HATCH in chapter2.gd)
    m.box("metal", (1.0, 0.05, 1.0), (-10.0, 6.64, -6.1))
    for k in range(6):
        m.box("ik_rail", (0.5, 0.03, 0.03), (-10.0, 4.2 + k * 0.42, -6.72))
    for sx in (-0.25, 0.25):
        m.box("ik_rail", (0.04, 2.85, 0.04), (-10.0 + sx, 5.25, -6.72))


# ============================================================== church

def m_church():
    m = B.Model("church")
    w, d, h = 12, 24, 8
    tx, tz, tw = -8.5, -9, 5.0  # bell tower centre / width
    m.node("shell-col")
    B.room(m, w, d, h, "civ_ashlar", door=(0, 2.0, 3.2), floor="stone", ceil="planks")
    with m.push((tx, 0, tz)):
        m.box("civ_ashlar", (tw, 12, tw), (0, 6, 0))
        m.box("civ_ashlar", (tw + 0.3, 0.5, tw + 0.3), (0, 12.25, 0))
        for x in (-2.2, 2.2):
            for z in (-2.2, 2.2):
                m.box("civ_ashlar", (0.6, 3.5, 0.6), (x, 14.25, z))
        m.box("civ_ashlar", (tw + 0.3, 0.5, tw + 0.3), (0, 16.25, 0))
    # buttresses (nave sides + tower corners)
    for sx in (-1, 1):
        for z in (-10, -6, -2, 2, 6, 10):
            if sx < 0 and z < -5:
                continue
            with m.push((sx * (w / 2), 0, z), (0, 90 * sx, 0)):
                m.tbox("civ_ashlar", (0.8, 1.3), (0.7, 1.0), 3.2, (0, 0, 0.65))
                m.tbox("civ_ashlar", (0.7, 1.0), (0.6, 0.6), 2.6, (0, 3.2, 0.5), shift=(0, -0.2))
                m.tbox("civ_ashlar", (0.6, 0.6), (0.6, 0.05), 0.6, (0, 5.8, 0.3), shift=(0, -0.28))
    for x in (-w / 2 + 0.3, w / 2 - 0.3):
        m.tbox("civ_ashlar", (0.7, 1.3), (0.6, 0.9), 4.2, (x, 0, d / 2 + 0.6))
        m.tbox("civ_ashlar", (0.6, 0.9), (0.5, 0.5), 2.2, (x, 4.2, d / 2 + 0.4), shift=(0, -0.2))
        m.tbox("civ_ashlar", (0.5, 0.5), (0.5, 0.05), 0.6, (x, 6.4, d / 2 + 0.2), shift=(0, -0.22))
    m.node("props-col")
    # pews: two banks either side of the aisle, every one facing the altar (-Z); the kneelers under the seats
    for row in range(8):
        for x in (-2.8, 2.8):
            K.pew(m, x, -6 + row * 2.1, 3.6, facing=-1)
    m.box("stone", (3, 1.1, 1.2), (0, 0.55, -9.8))
    m.box("fabric", (3.1, 0.05, 1.3), (0, 1.12, -9.8))
    # communion rail across the chancel (open at the aisle), the pulpit (left) and the lectern (right); the
    # rail and lectern are dressing (Marcus fights around here: nothing low to snag on)
    prev = m.cur
    m.node("chancel")
    for sx in (-1, 1):
        with m.push((sx * 3.4, 0, -7.9)):
            m.box("ik_wood_dark", (4.4, 0.08, 0.2), (0, 0.85, 0))
            for k in range(12):
                m.box("ik_wood_dark", (0.05, 0.8, 0.05), (-2.1 + k * 0.38, 0.42, 0))
            m.box("ik_velvet", (4.2, 0.1, 0.35), (0, 0.06, 0.35))
    with m.push((-4.4, 0, -9.4)):
        m.cyl("ik_wood_dark", 0.75, 0.8, 1.15, (0, 0, 0), seg=8)
        m.cyl("ik_wood_dark", 0.85, 0.85, 0.1, (0, 1.15, 0), seg=8)
        m.box("ik_wood_dark", (0.6, 0.06, 0.45), (0.2, 1.35, 0.5), (-20, 0, 0))
    m.cur = prev
    with K._On(m, "chancel"), m.push((4.2, 0, -9.0)):
        m.cyl("ik_brass", 0.25, 0.08, 0.1, (0, 0, 0), seg=8)
        m.cyl("ik_brass", 0.05, 0.05, 1.1, (0, 0.1, 0), seg=6)
        m.box("ik_brass", (0.55, 0.05, 0.4), (0, 1.25, 0.05), (-25, 0, 0))
        m.box("white", (0.45, 0.04, 0.32), (0, 1.29, 0.05), (-25, 0, 0))
    m.use("detail")  # made by the pews' kneelers
    # roof: slate gable with stone copings on the gable ends, ridge crest
    m.gable("civ_slate", w + 0.8, d + 0.8, 5.0, (0, h + 0.2, 0), end="civ_ashlar")
    for z in (-d / 2 - 0.45, d / 2 + 0.45):
        for sx in (-1, 1):
            a, b = (sx * (w / 2 + 0.5), h + 0.1, z), (0, h + 5.35, z)
            ln = math.dist(a, b)
            ang = math.degrees(math.atan2(b[1] - a[1], -a[0]))
            m.box("civ_dressed", (ln, 0.3, 0.5), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 + 0.1, z), (0, 0, ang))
    m.box("iron", (0.1, 0.1, d + 0.8), (0, h + 5.25, 0))
    # plinth / string courses around the nave
    for side, L in (("s", w), ("n", w), ("e", d), ("w", d)):
        with wall(m, side, w, d):
            if side == "s":
                for sx in (-1, 1):
                    m.tbox("civ_dressed", (L / 2 - 1.6, 0.35), (L / 2 - 1.6, 0.14), 0.6, (sx * (L / 4 + 0.8), 0, 0.1))
            else:
                m.tbox("civ_dressed", (L, 0.35), (L, 0.14), 0.6, (0, 0, 0.1))
            m.box("civ_dressed", (L + 0.2, 0.16, 0.2), (0, 2.6, 0.1))
            m.box("civ_dressed", (L + 0.4, 0.3, 0.35), (0, h - 0.15, 0.1))  # eaves cornice
    # lancet windows with stained glass, hood moulds and sills
    for side in ("e", "w"):
        for i, u in enumerate(range(-8, 9, 4)):
            if side == "w" and u > 5:  # hidden behind the tower
                continue
            with wall(m, side, w, d, u):
                inner = arch_pts(1.1, 3.6, pointed=0.6, n=3, y0=2.7)
                glass = "civ_win_broken" if (i + (side == "e")) % 4 == 0 else "civ_stained"
                pane(m, glass, inner, 0.02, back=-0.22)
                surround(m, "civ_dressed", inner, offset(inner, 0.18), 0.12, 0.02, 0.0)
                m.box("civ_dressed", (1.6, 0.12, 0.3), (0, 2.62, 0.15))
                m.box("iron", (0.04, 3.2, 0.04), (0, 4.3, 0.06))
    # west (front, +Z) facade: pointed portal with stepped jambs, rose window, gable cross
    with wall(m, "s", w, d):
        arch_in = arch_pts(2.0, 4.3, pointed=0.5, n=4)
        o1, o2 = offset(arch_in, 0.25), offset(arch_in, 0.5)
        surround(m, "civ_dressed", arch_in, o1, 0.25, 0.0, 0.0)
        surround(m, "civ_dressed", o1, o2, 0.12, 0.25, 0.0)
        tymp = arch_pts(2.0, 4.3, pointed=0.5, n=4, y0=0)[2:]
        pane(m, "civ_dressed", [(-1.0, 3.2), (1.0, 3.2)] + tymp[1:-1], 0.05)
        m.box("civ_dressed", (2.3, 0.2, 0.3), (0, 3.3, 0.15))
        for sx in (-1, 1):  # gablet hood over the portal + flanking pinnacles
            a0, a1 = (sx * 1.9, 3.5), (0, 5.0)
            ang = math.degrees(math.atan2(a1[1] - a0[1], -a0[0]))
            m.box("civ_dressed", (math.dist(a0, a1) + 0.2, 0.2, 0.3), ((a0[0] + a1[0]) / 2, (a0[1] + a1[1]) / 2, 0.3),
                  (0, 0, ang))
            m.box("civ_dressed", (0.3, 5.0, 0.35), (sx * 2.05, 2.5, 0.18))
            m.cyl("civ_dressed", 0.24, 0, 0.8, (sx * 2.05, 5.0, 0.18), seg=4, phase=0.5, caps=False)
        m.box("iron", (0.06, 0.45, 0.06), (0, 5.3, 0.3))
        m.box("iron", (0.28, 0.06, 0.06), (0, 5.38, 0.3))
        # rose window
        ro = [(math.cos(2 * math.pi * k / 16) * 1.3, 6.3 + math.sin(2 * math.pi * k / 16) * 1.3) for k in range(16)]
        pane(m, "civ_rose", ro, 0.02, back=-0.22)
        surround(m, "civ_dressed", ro, offset(ro, 0.25), 0.15, 0.02, 0.0)
        # stone steps down to the path (landing flush with the nave floor)
        m.box("civ_dressed", (4.4, 0.05, 1.6), (0, 0.025, 0.8))
        for sx in (-1, 1):
            m.tbox("civ_dressed", (0.35, 1.6), (0.35, 0.4), 0.9, (sx * 2.4, 0, 0.8), shift=(0, -0.6))
            handrail(m, "iron", (sx * 1.9, 0.05, 0.2), (sx * 1.9, 0.05, 1.8), 0.85)
    # gable-end cross + a leaning iron cross
    m.box("iron", (0.15, 1.6, 0.15), (0, h + 5.9, d / 2 + 0.45))
    m.box("iron", (0.8, 0.15, 0.15), (0, h + 6.3, d / 2 + 0.45))
    # bell tower: string courses, louvred lancet belfry openings, pinnacles, octagonal spire
    with m.push((tx, 0, tz)):
        for y in (0.6, 4.0, 8.0):
            m.box("civ_dressed", (tw + 0.25, 0.25, tw + 0.25), (0, y, 0))
        m.tbox("civ_dressed", (tw + 0.5, tw + 0.5), (tw + 0.2, tw + 0.2), 0.6)
        for yaw in (0, 90, 180, 270):
            with m.push((0, 0, 0), (0, yaw, 0)):
                with m.push((0, 0, tw / 2)):
                    # small lancet on the shaft
                    inner = arch_pts(0.5, 1.6, pointed=0.6, n=2, y0=5.2)
                    pane(m, "civ_win", inner, 0.02)
                    surround(m, "civ_dressed", inner, offset(inner, 0.12), 0.08, 0.02, 0.0)
                    # clock-less blind panel + belfry louvres (between the corner piers)
                    for k in range(6):
                        m.box("civ_louvre", (3.6, 0.07, 0.4), (0, 12.9 + k * 0.5, -0.35), (35, 0, 0))
                    bel = arch_pts(3.8, 3.5, pointed=0.5, n=3, y0=12.5)
                    ob = offset(bel, 0.12)
                    surround(m, "civ_dressed", bel, ob, 0.1, -0.4, 0.0)
                    spandrels(m, "civ_ashlar", ob, 16.0, 2.0, 0.0, -0.45)
                    # gable-ish crocket over each face
                    m.tbox("civ_dressed", (1.0, 0.3), (0.05, 0.3), 1.4, (0, 16.5, -0.05))
        for x in (-2.35, 2.35):
            for z in (-2.35, 2.35):
                m.box("civ_dressed", (0.6, 1.4, 0.6), (x, 17.2, z))
                m.cyl("civ_dressed", 0.35, 0, 1.6, (x, 17.9, z), seg=4, phase=0.5, caps=False)
        m.cyl("civ_slate", 2.3, 0.05, 9.0, (0, 16.5, 0), seg=8, phase=0.5, caps=False)
        for k in range(4):  # spire lucarnes
            with m.push((0, 0, 0), (0, 45 + k * 90, 0)):
                m.gable("civ_slate", 0.7, 0.9, 0.6, (0, 18.2, 1.7), end="planks")
        m.box("iron", (0.08, 1.4, 0.08), (0, 26.0, 0))
        m.box("iron", (0.6, 0.08, 0.08), (0, 26.3, 0))
        m.lathe("metal", [(0.05, 1.1), (0.25, 1.0), (0.55, 0.55), (0.75, 0.05), (0.8, 0)], (0, 12.1, 0), seg=12)
        m.lathe("metal", [(0, 0), (0.8, 0), (0.75, 0.05), (0, 0.06)], (0, 12.1, 0), seg=12)
        m.box("planks", (0.2, 0.2, 2.6), (0, 13.3, 0))
        # tower door on its outer side
        with m.push((-tw / 2, 0, 0), (0, -90, 0)):
            m.box("door", (1.0, 2.2, 0.06), (0, 1.1, 0.03))
            dr = arch_pts(1.0, 2.5, pointed=0.5, n=2)
            surround(m, "civ_dressed", dr, offset(dr, 0.18), 0.1, -0.02, 0.0)
    # altar crucifix, candles, photos of the lost
    m.box("planks", (0.25, 3.0, 0.2), (0, 3.2, -11.7))
    m.box("planks", (1.6, 0.25, 0.2), (0, 3.9, -11.7))
    for x in range(-1, 2):
        m.cyl("white", 0.04, 0.04, 0.3, (x * 0.5, 1.1, -9.8), seg=6)
        m.cyl("bulb", 0.015, 0.0, 0.06, (x * 0.5, 1.4, -9.8), seg=3)
    for i in range(5):  # photos of the lost, propped against the pew backs
        m.box("white", (0.2, 0.25, 0.02), (-2.5 + i * 1.3, 0.6, -5.8 + i * 2.1), (-18, i * 7, 0))
    _church_dressing(m, w, d, h)
    return m


def _church_dressing(m, w, d, h):
    hw, hd = w / 2 - 0.2, d / 2 - 0.2
    # chancel: a low dais, reredos panels and flowers behind the altar, the red runner up the aisle
    m.box("civ_dressed", (7.0, 0.06, 3.6), (0, 0.08, -10.0))
    m.box("ik_carpet", (1.4, 0.02, 20.0), (0, 0.06, 1.3))
    m.box("ik_carpet", (3.4, 0.02, 1.6), (0, 0.12, -8.9))
    for k in range(5):
        x = -2.4 + k * 1.2
        m.box("ik_wood_dark", (1.0, 2.2 if k != 2 else 2.8, 0.1), (x, 1.9 if k != 2 else 2.2, -11.78))
        m.box("ik_brass", (0.8, 0.06, 0.04), (x, 3.05 if k != 2 else 3.65, -11.72))
    for x in (-1.3, 1.3):
        m.cyl("ik_brass", 0.1, 0.14, 0.4, (x, 1.12, -9.5), seg=6)
        for k in range(5):  # dead lilies
            a = k * 1.25
            m.box("burnt", (0.02, 0.4, 0.02), (x + math.cos(a) * 0.05, 1.7, -9.5 + math.sin(a) * 0.05), (math.cos(a) * 15, 0, math.sin(a) * 15))
    # stations of the cross between the lancets, the hymn boards, iron chandeliers over the pews
    for sx in (-1, 1):
        for z in (-6, -2, 2, 6):
            K.board(m, "civ_dressed", sx * (hw - 0.02), 1.9, z, -90 * sx, 0.5, 0.6, "ik_wood_dark")
            m.box("iron", (0.02, 0.2, 0.08), (sx * (hw - 0.07), 2.35, z))
        K.board(m, "ik_hymn", sx * (hw - 0.02), 2.3, -7.2, -90 * sx, 0.6, 0.9, "ik_wood_dark")
    for z in (-3.0, 4.0):
        for x in (-2.8, 2.8):
            m.cyl("iron", 0.015, 0.015, h - 4.6, (x, 4.6, z), seg=4)
            with m.push((x, 4.6, z)):
                m.lathe("iron", [(0.7, 0.0), (0.72, 0.04), (0.68, 0.06)], (0, 0, 0), seg=12)
                for k in range(6):
                    a = k * math.pi / 3
                    m.cyl("white", 0.03, 0.03, 0.18, (math.cos(a) * 0.68, 0.06, math.sin(a) * 0.68), seg=5)
    # roof trusses: tie beams, king posts, wall posts on corbels
    for z in range(-10, 11, 4):
        m.box("ik_wood_dark", (w - 0.4, 0.3, 0.25), (0, h - 0.3, z))
        m.box("ik_wood_dark", (0.2, 1.6, 0.2), (0, h + 0.5, z))
        for sx in (-1, 1):
            m.box("ik_wood_dark", (0.25, 2.2, 0.25), (sx * (hw - 0.1), h - 1.4, z))
            m.box("civ_dressed", (0.35, 0.3, 0.35), (sx * (hw - 0.1), h - 2.6, z))
    # the candle holders on the five families' pews (Empty Chairs: the flames light there), the memorial table
    for x, z in ((-1.2, -3.9), (1.2, -1.8), (-1.2, 2.4), (1.2, 4.5), (-1.2, 8.7)):
        m.box("iron", (0.18, 0.03, 0.18), (x, 0.88, z - 0.1))
        m.box("iron", (0.03, 0.4, 0.03), (x, 0.68, z - 0.1))
        m.cyl("white", 0.03, 0.03, 0.1, (x, 0.9, z - 0.1), seg=6)
    with m.push((-4.4, 0, 8.2)):
        B.table(m, 0, 0, 1.4, 0.6, 0.85, "ik_wood_dark")
        m.box("ik_velvet", (1.45, 0.02, 0.65), (0, 0.87, 0))
        for k in range(7):
            m.box("white", (0.14, 0.19, 0.02), (-0.55 + k * 0.18, 0.97, -0.15 + (k % 2) * 0.12), (-15, 0, 0))
            m.cyl("white", 0.02, 0.02, 0.08 + 0.04 * (k % 3), (-0.55 + k * 0.18, 0.88, 0.2), seg=5)
    # holy water stoups by the door, the notice board, the poor box
    for sx in (-1, 1):
        with m.push((sx * 1.9, 0, hd - 0.4)):
            m.cyl("civ_dressed", 0.08, 0.1, 0.9, (0, 0, 0), seg=6)
            m.lathe("civ_dressed", [(0.08, 0.0), (0.25, 0.1), (0.27, 0.18), (0.2, 0.16), (0.0, 0.12)], (0, 0.9, 0), seg=8)
    K.board(m, "ik_cork", hw - 0.02, 1.6, 10.8, -90, 0.9, 0.7, "ik_wood_dark")
    m.box("iron", (0.3, 0.4, 0.25), (-hw + 0.15, 1.1, 10.8))


# ============================================================== veil chapel (carved into the quarry)

def m_veil_chapel():
    m = B.Model("veil_chapel")
    w, d, h = 8, 10, 5
    m.node("shell-col")
    B.room(m, w, d, h, "rock", door=(0, 1.6, 2.8), floor="stone", ceil="rock", leaf=False)
    with m.push((0, 0, d / 2 + 0.3)):  # carved facade, cut by the pointed doorway
        m.box("civ_ashlar", (4.2, 6.5, 0.6), (-2.9, 3.25, 0))
        m.box("civ_ashlar", (4.2, 6.5, 0.6), (2.9, 3.25, 0))
        m.box("civ_ashlar", (1.6, 3.7, 0.6), (0, 2.8 + 3.7 / 2, 0))
    m.node("props-col")
    m.box("stone", (2.4, 1.0, 1.0), (0, 0.5, -3.6))
    for z in (-1, 1):
        m.box("stone", (2.4, 0.45, 0.5), (-1.8, 0.22, z))
        m.box("stone", (2.4, 0.45, 0.5), (1.8, 0.22, z))
    m.node("detail")
    m.rock("rock", 9, 11, (0, 0, -3), rng=random.Random(11), seg=10, rings=4, jit=0.2)
    with m.push((0, 0, d / 2 + 0.6)):
        door = arch_pts(1.6, 2.8, pointed=0.6, n=3)
        o1, o2 = offset(door, 0.2), offset(door, 0.45)
        surround(m, "civ_dressed", door, o1, 0.12, -0.6, 0.0)
        surround(m, "civ_dressed", o1, o2, 0.06, 0.12, 0.0)
        spandrels(m, "civ_ashlar", door, 2.8, 0.8, 0.0, -0.6)
        for x in (-1.6, 1.6):
            column(m, "civ_dressed", 4.0, 0.3, (x, 0, 0.3), seg=10)
        m.box("civ_dressed", (4.8, 0.35, 0.9), (0, 4.4, 0.3))
        m.gable("civ_dressed", 5.0, 1.0, 1.4, (0, 4.57, 0.3))
        m.decal("eye", 1.0, 1.0, (0, 5.05, 0.82))
        steps(m, "civ_dressed", 3.4, 2, 0.04, 0.45, (0, 0, 0.0))
        for x in (-2.8, 2.8):  # headless statues in niches
            nich = arch_pts(0.9, 2.0, pointed=0.5, n=2, y0=0.9)
            pane(m, "iron", nich, 0.02)
            surround(m, "civ_dressed", nich, offset(nich, 0.15), 0.1, 0.02, 0.0)
            m.lathe("civ_dressed", [(0.25, 0.9), (0.28, 1.2), (0.2, 1.9), (0.17, 2.3), (0.05, 2.35)], (x, 0, 0.25), seg=8)
    m.decal("eye", 2.6, 2.6, (0, 2.8, -d / 2 + 0.21))
    for x in (-2.5, 2.5):
        for z in (-3, 0, 3):
            B.lantern(m, x, 4.6, z)
    return m


# ============================================================== mausoleum

def m_mausoleum():
    m = B.Model("mausoleum")
    m.node("shell-col")
    m.box("civ_marble", (3.6, 0.3, 4.6), (0, 0.15, 0.2))  # plinth
    m.box("civ_marble", (3.0, 3.2, 3.5), (0, 1.6 + 0.3, 0))
    steps(m, "civ_marble", 2.6, 2, 0.1, 0.3, (0, 0, 2.5))
    m.node("detail")
    m.box("civ_marble", (3.3, 0.3, 4.5), (0, 3.55, 0.3))  # entablature
    m.box("civ_marble", (3.45, 0.12, 4.65), (0, 3.76, 0.3))
    m.gable("civ_marble", 3.5, 4.7, 1.0, (0, 3.82, 0.3), end="civ_marble")
    with m.push((0, 0, 2.66)):
        emit_to(m, "civ_granite_d", [(-1.4, 3.84, 0), (1.4, 3.84, 0), (0, 4.62, 0)], (0, 4, 1))
    for x in (-1.2, 1.2):
        column(m, "civ_marble", 3.1, 0.17, (x, 0.3, 2.1), seg=10)
    # corner pilasters + base course
    for x in (-1.5, 1.5):
        m.box("civ_marble", (0.25, 3.2, 0.25), (x, 1.9, 1.65))
    m.box("civ_granite_d", (3.1, 0.35, 3.6), (0, 0.47, 0))
    # iron gate (bars) in a dark doorway, name plaque, urns, acroterion
    m.box("iron", (1.3, 2.3, 0.04), (0, 1.45, 1.76))
    for i in range(7):
        m.cyl("rust", 0.02, 0.02, 2.2, (-0.54 + i * 0.18, 0.35, 1.84), seg=4)
    for y in (0.6, 1.5, 2.45):
        m.box("rust", (1.2, 0.05, 0.03), (0, y, 1.84))
    m.box("civ_trim", (1.6, 0.3, 0.04), (0, 3.1, 1.77))
    for x in (-1.6, 1.6):
        m.lathe("civ_marble", [(0.12, 0), (0.22, 0.12), (0.2, 0.3), (0.1, 0.38), (0.14, 0.44), (0, 0.46)],
                (x, 4.0 - 0.1, 2.3), seg=8)
    m.box("civ_marble", (0.14, 0.5, 0.1), (0, 4.8, 2.62))
    m.box("civ_marble", (0.4, 0.12, 0.1), (0, 4.9, 2.62))
    m.box("civ_moss", (3.4, 0.02, 1.0), (0, 3.73, -1.6))
    return m


# ============================================================== graves (instanced: keep < 250 tris)

def slab(m, mat, outline, t, face=None, pos=(0, 0, 0), rot=(0, 0, 0)):
    """Extruded 2D outline (x, y) along Z, thickness t, front at +t/2. face: front material."""
    with m.push(pos, rot):
        n = len(outline)
        front = [(x, y, t / 2) for x, y in outline]
        back = [(x, y, -t / 2) for x, y in outline]
        emit_to(m, face or mat, front, (0, 0.5, 5))
        emit_to(m, mat, back, (0, 0.5, -5))
        for i in range(n):
            j = (i + 1) % n
            m.emit(mat, [front[i], front[j], back[j], back[i]], (0, outline[0][1] + 0.3, 0))


def mound(m, length=1.8, w=0.8, h=0.18, z=1.1, mat="mud"):
    m.lathe(mat, [(0.5, -0.05), (0.45, h * 0.6), (0.3, h), (0.0, h * 1.1)], (0, 0, z),
            scale=(w, 1, length), seg=8)


def m_grave_a():
    """Rounded-top headstone with a raised panel and inscription."""
    m = B.Model("grave_a")
    m.node("stone-col")
    m.box("civ_granite_d", (0.8, 0.18, 0.34), (0, 0.09, 0))
    top = arch_pts(0.62, 0.95, pointed=0.0, n=6, y0=0.18)
    slab(m, "civ_granite", top, 0.14, pos=(0, 0, 0), rot=(-3, 0, 2))
    with m.push((0, 0, 0.07), (-3, 0, 2)):
        pan = arch_pts(0.46, 0.7, pointed=0.0, n=4, y0=0.28)
        pane(m, "civ_epitaph", pan, 0.02)
        surround(m, "civ_granite", pan, offset(pan, 0.035), 0.02, 0.0, 0.0)
    m.node("detail")
    mound(m, 1.6, 0.75, 0.12, 1.0, "civ_moss")
    return m


def m_grave_b():
    """Leaning Celtic cross on a stepped base."""
    m = B.Model("grave_b")
    m.node("stone-col")
    m.box("civ_granite_d", (0.7, 0.2, 0.45), (0, 0.1, 0))
    m.tbox("civ_granite", (0.5, 0.32), (0.38, 0.24), 0.25, (0, 0.2, 0))
    with m.push((0, 0.45, 0), (0, 0, 6)):
        m.tbox("civ_granite", (0.17, 0.13), (0.14, 0.11), 1.05)
        m.box("civ_granite", (0.62, 0.14, 0.11), (0, 0.78, 0))
        m.tbox("civ_granite", (0.14, 0.11), (0.1, 0.1), 0.06, (0, 1.05, 0))
        prof = [(0.2 + 0.035 * math.cos(a), 0.035 * math.sin(a) * 1.4)
                for a in [math.pi * 2 * k / 5 for k in range(6)]]
        m.lathe("civ_granite", [(r, y) for r, y in prof], (0, 0.78, 0), (90, 0, 0), seg=12)
        m.box("civ_epitaph", (0.13, 0.35, 0.005), (0, 0.4, 0.068))
    m.node("detail")
    mound(m, 1.6, 0.7, 0.15, 1.05)
    return m


def m_grave_c():
    """Weeping angel on a pedestal over a fresh, unsettled grave."""
    m = B.Model("grave_c")
    m.node("stone-col")
    m.box("civ_granite_d", (0.7, 0.2, 0.6), (0, 0.1, 0))
    m.box("civ_marble", (0.5, 0.55, 0.42), (0, 0.475, 0), faces={"+z": "civ_epitaph"})
    m.box("civ_marble", (0.6, 0.08, 0.52), (0, 0.79, 0))
    with m.push((0, 0.83, 0), (0, 0, 0)):
        m.lathe("civ_marble", [(0.2, 0), (0.19, 0.3), (0.13, 0.7), (0.12, 0.85), (0.07, 0.95), (0.0, 0.96)], seg=8,
                scale=(1, 1, 0.8))
        m.ellipsoid("civ_marble", (0.08, 0.1, 0.09), (0, 1.0, 0.07), (35, 0, 0), seg=6, rings=4)
        for s in (-1, 1):  # wings
            wing = [(0, 0), (0.28, 0.12), (0.38, 0.42), (0.3, 0.55), (0.12, 0.45), (0.0, 0.2)]
            slab(m, "civ_marble", [(s * x, y) for x, y in (wing if s > 0 else wing[::-1])], 0.04,
                 pos=(s * 0.06, 0.45, -0.14), rot=(0, -s * 25, 0))
        m.tbox("civ_marble", (0.16, 0.08), (0.12, 0.08), 0.3, (0, 0.62, 0.13), (-35, 0, 0))  # hands to face
    m.node("detail")
    m.box("mud", (0.8, 0.12, 1.7), (0, 0.04, 1.2), (2, 0, 0))
    m.box("mud", (0.25, 0.1, 0.3), (0.3, 0.12, 1.8), (10, 30, 0))
    return m


# ============================================================== iron fence (instanced: < 250 tris)

def m_fence_iron():
    m = B.Model("fence_iron")
    rng = random.Random(9)
    m.node("fence-col")
    m.box("iron", (0.12, 1.9, 0.12), (-1.5, 0.95, 0))
    m.tbox("iron", (0.18, 0.18), (0.01, 0.01), 0.22, (-1.5, 1.9, 0))
    for y in (0.15, 1.6):
        m.box("iron", (3.0, 0.05, 0.04), (0, y, 0))
    for i in range(15):
        x = -1.33 + i * 0.19
        lean = rng.uniform(-4, 4) if rng.random() < 0.15 else 0
        top = 1.8 + (0.06 if i % 2 else 0)
        with m.push((x, 0, 0), (lean, 0, 0)):
            m.cyl("iron", 0.013, 0.013, top, seg=4, caps=False, phase=0.5)
            m.cyl("iron", 0.03, 0.0, 0.14, (0, top, 0), seg=4, caps=False, phase=0.5)
    return m


# ============================================================== playground

def m_swing_set():
    m = B.Model("swing_set")
    m.node("frame-col")
    top = 2.55
    for x in (-2, 2):
        for s in (-1, 1):
            tube(m, "civ_red", [(x, 0, s * 0.8), (x, top - 0.1, s * 0.03)], 0.05, seg=8)
        m.box("civ_red", (0.08, 0.06, 1.1), (x, 0.9, 0))
    tube(m, "civ_blue", [(-2.15, top, 0), (2.15, top, 0)], 0.06, seg=10)
    for x in (-2.1, 2.1):
        m.lathe("civ_blue", [(0.07, -0.1), (0.07, 0.08), (0, 0.1)], (x, top, 0), seg=8)
    m.node("detail")
    for x, tilt, broken in ((-0.8, 0, False), (0.8, 12, True)):
        with m.push((x, top, 0), (tilt, 0, 0)):
            for cx in (-0.22, 0.22):
                if broken and cx > 0:
                    m.cyl("iron", 0.01, 0.01, 1.2, (cx, -1.2, 0), seg=3, caps=False)
                    continue
                m.cyl("iron", 0.01, 0.01, 2.0, (cx, -2.0, 0), seg=3, caps=False)
            seat_rot = (0, 0, 55) if broken else (0, 0, 0)
            with m.push((-0.22 if broken else 0, -2.0, 0), seat_rot):
                sx = 0.22 if broken else 0
                m.loft("rubber", [(-0.25, 0.0, 0.0), (-0.24, 0.02, 0.1), (0.24, 0.02, 0.1), (0.25, 0, 0)],
                       (sx, 0, 0), (0, 0, -90), seg=8, power=3)
            m.box("rust", (0.03, 0.06, 0.03), (-0.22, -0.02, 0))
            m.box("rust", (0.03, 0.06, 0.03), (0.22, -0.02, 0))
    return m


def m_slide():
    m = B.Model("slide")
    m.node("frame-col")
    m.box("civ_blue", (1.0, 0.08, 1.0), (0, 1.8, 0))
    for x in (-0.45, 0.45):
        for z in (-0.45, 0.45):
            tube(m, "civ_red", [(x, 0, z), (x, 2.7, z)] if z < 0 else [(x, 0, z), (x, 1.84, z)], 0.04, seg=8)
    # safety hoop around the top (back + sides)
    for x in (-0.45, 0.45):
        tube(m, "civ_red", bend((x, 1.84, 0.45), (x, 2.7, 0.45), (x, 2.7, -0.45), 0.2) , 0.035, seg=6, caps=False)
        m.cyl("civ_red", 0.03, 0.03, 0.01, (x, 2.3, 0), seg=4)
        tube(m, "civ_red", [(x, 2.25, 0.45), (x, 2.25, -0.45)], 0.025, seg=6)
    tube(m, "civ_red", [(-0.45, 2.7, -0.45), (0.45, 2.7, -0.45)], 0.035, seg=6, caps=False)
    # chute: U-channel with a rolled lip, rising toward -Z
    L, ang = 3.2, 32
    rows = []
    for k in range(7):
        t = k / 6
        zz = t * L
        run_off = 0.25 if k == 6 else 0
        row = []
        for j, (px, py) in enumerate([(0.34, 0.2), (0.3, 0.0), (0.2, -0.05), (-0.2, -0.05), (-0.3, 0.0), (-0.34, 0.2)]):
            row.append((px, py, zz))
        rows.append(row)
    with m.push((0, 1.84, 0.5), (ang, 0, 0)):
        m.surface("metal", [[(p[0], p[1], p[2]) for p in r] for r in rows])
        m.surface("metal", [[(p[0] * 1.08, p[1] - 0.03, p[2]) for p in r[::-1]] for r in rows])
        for s in (-1, 1):
            tube(m, "civ_yellow", [(s * 0.35, 0.22, 0), (s * 0.35, 0.22, L)], 0.035, seg=6)
    # end runout, flattened
    m.box("metal", (0.66, 0.04, 0.5), (0, 0.18, 0.5 + L * math.cos(math.radians(ang)) + 0.2))
    # ladder: two rails + rungs
    for x in (-0.3, 0.3):
        tube(m, "civ_yellow", [(x, 0, -1.0), (x, 1.9, -0.47)], 0.035, seg=6)
    for i in range(1, 7):
        t = i / 7
        tube(m, "rust", [(-0.3, 1.9 * t, -1.0 + 0.53 * t), (0.3, 1.9 * t, -1.0 + 0.53 * t)], 0.022, seg=5, caps=False)
    return m


# ============================================================== flagpole

def m_flagpole():
    m = B.Model("flagpole")
    m.node("pole-col")
    m.tbox("civ_band", (0.9, 0.9), (0.7, 0.7), 0.35)
    m.lathe("metal", [(0.08, 0.35), (0.065, 4), (0.045, 8), (0.05, 8.02), (0.0, 8.03)], seg=8)
    m.node("detail")
    m.ellipsoid("civ_yellow", (0.09, 0.09, 0.09), (0, 8.1, 0), seg=8, rings=5)
    m.box("metal", (0.03, 0.2, 0.06), (0.07, 1.4, 0))
    m.cyl("iron", 0.006, 0.006, 6.7, (0.06, 1.4, 0), seg=3, caps=False)
    # half-mast, tattered flag (double-sided cloth grid)
    rng = random.Random(4)
    cols, rows_n = 7, 4
    grid = []
    for i in range(rows_n + 1):
        y = 6.2 + 0.9 * i / rows_n
        row = []
        for j in range(cols + 1):
            u = j / cols
            ln = 1.4 * (1 - (0.35 * rng.random() if j == cols else 0))
            z = 0.05 + u * ln
            x = 0.12 * math.sin(u * 5 + i * 0.3) * u
            row.append((x, y - u * u * 0.35, z))
        grid.append(row)
    m.surface("fabric", [r[::-1] for r in grid])
    m.surface("fabric", grid)
    return m


MODELS = [m_school, m_clinic, m_church, m_veil_chapel, m_mausoleum, m_grave_a, m_grave_b, m_grave_c,
          m_fence_iron, m_swing_set, m_slide, m_flagpole]
