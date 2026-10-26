"""Hollowmere Memorial Park: the Town Square hub as an abandoned old-town park. A dry, cracked fountain under the
festival lantern pole, a rusty bandstand, a mourning statue, wrought-iron fence + entrance arch, a rusted
playground, a refreshment kiosk, overgrowth, leaf litter, drifting ground fog, dripping water and falling leaves.
Auto-loaded by build_assets; place() dresses the square (lawns / paths are LOTS in build_assets).

Scripted spots kept clear (scripts/*.gd): Grady's door (14, -17.6) + camera shots in front of the store, the bar
door (-18, -18.5), the tin-moth range (-4..4, -10), the (6,-2) -> (14,-16) walk, ch3 patrols z=8 (x -12..12) and
x=6 (z -6..26), the south entrance (0, 30) and the W/E lanes (|z| < 3.5)."""
import math
import random

import build_assets as B
import models_hd_street as H

tube, bezier = H.tube, H.bezier

FOUNTAIN = (0.0, 14.0)  # centre of the festival ring; the lantern pole rises out of the bowl
GAZEBO = (-22.5, 17.0)


# ------------------------------------------------------------------ textures & materials

_R = random.Random(11)
_LEAVES = [(_R.uniform(0, 64), _R.uniform(0, 64), _R.uniform(2.2, 4.6), _R.uniform(0, math.pi), _R.randrange(4))
           for _ in range(48)]
_LEAF_C = ((0.36, 0.2, 0.08), (0.46, 0.3, 0.1), (0.22, 0.13, 0.07), (0.3, 0.26, 0.12))
_WEEDS = [(_R.uniform(6, 58), _R.uniform(-1, 1), _R.uniform(1.2, 2.6), _R.uniform(0.35, 0.95)) for _ in range(16)]


def _crack_segs(rng):
    segs = []
    for _ in range(3):
        x, y, a = rng.uniform(8, 56), rng.uniform(8, 56), rng.uniform(0, math.tau)
        for _ in range(5):
            a += rng.uniform(-0.9, 0.9)
            L = rng.uniform(4, 9)
            nx, ny = x + L * math.cos(a), y + L * math.sin(a)
            segs.append((x, y, nx, ny))
            x, y = nx, ny
    return segs


_CRACKS = _crack_segs(random.Random(12))


def t_park_leafcard(x, y, a, b, r):
    """Scatter of fallen leaves, alpha elsewhere."""
    for cx, cy, s, ang, k in _LEAVES:
        dx, dy = x - cx, y - cy
        u = dx * math.cos(ang) + dy * math.sin(ang)
        v = -dx * math.sin(ang) + dy * math.cos(ang)
        if (u / s) ** 2 + (v / (s * 0.5)) ** 2 < 1:
            return (*B.mul(_LEAF_C[k], 0.7 + 0.5 * a - (0.3 if abs(v) < 0.45 else 0)), 1.0)  # midrib
    return (0, 0, 0, 0.0)


def t_park_weedcard(x, y, a, b, r):
    t = (63 - y) / 63
    for x0, lean, w, h in _WEEDS:
        if t < h:
            cx = x0 + lean * 16 * t * t
            if abs(x - cx) < w * (1 - t / h) + 0.3:
                c = B.mix((0.1, 0.15, 0.06), (0.34, 0.38, 0.17), min(1, t * 1.3 + 0.2 * a))
                return (*B.mul(c, 0.8 + 0.3 * b), 1.0)
    return (0, 0, 0, 0.0)


def t_park_crack(x, y, a, b, r):
    if min(B.seg_dist(x, y, *s) for s in _CRACKS) < 0.6 + 0.6 * a:
        return (0.05, 0.05, 0.04, 1.0)
    return (0, 0, 0, 0.0)


_STREAKS = [(_R.uniform(2, 62), _R.uniform(1.5, 5), _R.uniform(20, 64)) for _ in range(9)]


def t_park_streak(x, y, a, b, r):
    """Grime running down a wall: dark vertical drips, ragged ends."""
    for x0, w, L in _STREAKS:
        if abs(x - x0 - 2 * math.sin(y * 0.15 + x0)) < w * (1 - 0.6 * y / L) and y < L * (0.8 + 0.3 * a) and r > y / L * 0.6:
            return (*B.mul((0.08, 0.1, 0.07), 0.6 + 0.7 * b), 1.0)
    return (0, 0, 0, 0.0)


def t_park_canopycard(x, y, a, b, r):
    d = math.hypot(x - 32, y - 32) / 32
    if d < 1 and a + 0.45 * (1 - d) > 0.55 and r > 0.18:
        return (*B.mul((0.1, 0.14, 0.07), 0.5 + 0.8 * b), 1.0)
    return (0, 0, 0, 0.0)


B.TEXTURES.update({"park_leafcard": t_park_leafcard, "park_weedcard": t_park_weedcard,
                   "park_crack": t_park_crack, "park_canopycard": t_park_canopycard, "park_streak": t_park_streak})
B.ALPHA_TEX.update({"park_leafcard", "park_weedcard", "park_crack", "park_canopycard", "park_streak"})
B.MATS.update({
    "park_stone": B.M("stone", (0.92, 0.92, 0.84), 1.2), "park_rough": B.M("rock", (0.85, 0.85, 0.8), 2),
    "park_moss": B.M("grass", (0.55, 0.9, 0.42), 0.8), "park_bronze": B.M("metal", (0.42, 0.72, 0.6), 0.8),
    "park_water": B.M("water", (0.6, 0.85, 0.55), 3, rough=0.08), "park_scum": B.M("grass", (0.45, 0.7, 0.3), 1, rough=0.5),
    "park_stain": B.M("plain", (0.1, 0.12, 0.08), 1), "park_iron": B.M("rust", (0.6, 0.55, 0.52), 1),
    "park_wood": B.M("planks", (0.8, 0.76, 0.7)), "park_green": B.M("paint", (0.34, 0.48, 0.38), 2),
    "park_roof": B.M("rust", (0.55, 0.62, 0.55), 1.5), "park_foliage": B.M("pine", (1.2, 1.1, 0.8), 1.5),
    "park_leafcard": B.M("park_leafcard", fit=True), "park_weedcard": B.M("park_weedcard", fit=True),
    "park_crack": B.M("park_crack", fit=True), "park_streak": B.M("park_streak", fit=True), "park_canopy": B.M("park_canopycard", fit=True),
    "park_deadflower": B.M("plain", (0.25, 0.16, 0.1), 1), "park_paper": B.M("plain", (0.42, 0.4, 0.34), 1),
    "park_bottle": B.M("plain", (0.1, 0.2, 0.12), 1, rough=0.2), "park_sign": B.M("paint", (0.28, 0.34, 0.28), 1.5),
    "park_dark": B.M("plain", (0.03, 0.03, 0.03), 1),
})


# ------------------------------------------------------------------ helpers

def P(r, a, y):
    return (r * math.cos(math.radians(a)), y, r * math.sin(math.radians(a)))


def ring_seg(m, mat, r0, r1, y0, y1, a0, a1):
    """Block of a round wall between angles a0..a1 (degrees): inner radius r0, outer r1, heights y0..y1."""
    ib0, ib1, ob0, ob1 = P(r0, a0, y0), P(r0, a1, y0), P(r1, a0, y0), P(r1, a1, y0)
    it0, it1, ot0, ot1 = P(r0, a0, y1), P(r0, a1, y1), P(r1, a0, y1), P(r1, a1, y1)
    c = P((r0 + r1) / 2, (a0 + a1) / 2, (y0 + y1) / 2)
    for f in ([ob0, ob1, ot1, ot0], [ib0, ib1, it1, it0], [it0, it1, ot1, ot0], [ib0, ib1, ob1, ob0],
              [ib0, ob0, ot0, it0], [ib1, ob1, ot1, it1]):
        m.emit(mat, f, c)


def disc(m, mat, r, y, seg=16, pos=(0, 0)):
    m.emit(mat, [(pos[0] + r * math.cos(math.tau * i / seg), y, pos[1] + r * math.sin(math.tau * i / seg))
                 for i in range(seg)], (pos[0], y - 1, pos[1]))


def blob(m, mat, pos, radii, rng, seg=6, rings=3):
    m.ellipsoid(mat, radii, pos, (0, rng.uniform(0, 360), 0), seg=seg, rings=rings)


def flat(m, mat, w, d, pos, yaw=0.0):
    """Ground decal quad facing up."""
    m.decal(mat, w, d, pos, (-90, yaw, 0))


def outward(m, mat, w, h, r, a, y):
    """Decal on a round wall at angle a (degrees), facing out."""
    m.decal(mat, w, h, P(r, a, y), (0, 90 - a, 0))


def ring_pts(c, r, n, y):
    return [(c[0] + r * math.cos(math.tau * k / n), y, c[1] + r * math.sin(math.tau * k / n)) for k in range(n + 1)]


# ------------------------------------------------------------------ fountain (< 2k tris)

def m_fountain():
    """Dry-ish three-level fountain; the festival lantern pole (placed at the same spot) rises out of its collar."""
    m = B.Model("park_fountain")
    rng = random.Random(21)
    broken = 5  # rim segment (112.5..135 deg, facing the south-west lawn) broken down to the water line
    m.node("fountain-col")
    m.cyl("park_rough", 3.85, 3.75, 0.1, seg=16, phase=0.5)  # paved apron
    disc(m, "park_rough", 2.96, 0.14)  # basin floor
    for i in range(16):
        a0, a1 = i * 22.5, i * 22.5 + 22.5
        if i == broken:
            ring_seg(m, "park_stone", 2.95, 3.3, 0.1, 0.3, a0, a1)
            ring_seg(m, "park_stone", 2.95, 3.3, 0.3, 0.46, a0, a0 + 7)
            ring_seg(m, "park_stone", 2.95, 3.3, 0.3, 0.38, a1 - 5, a1)
            continue
        ring_seg(m, "park_stone", 2.95, 3.3, 0.1, 0.5, a0, a1)
        sink = rng.uniform(-0.02, 0.015) - (0.05 if i == broken + 1 else 0)  # settled coping stones
        ring_seg(m, "park_stone", 2.86, 3.42, 0.5 + sink, 0.6 + sink, a0 + 0.4, a1 - 0.4)
    m.lathe("park_stone", [(0.8, 0.14), (0.66, 0.28), (0.48, 0.4), (0.36, 0.52), (0.3, 0.9), (0.36, 0.98), (0.3, 1.02)], seg=12)
    m.lathe("park_stone", [(0.3, 0.98), (0.8, 1.1), (1.25, 1.26), (1.46, 1.38), (1.48, 1.46), (1.38, 1.48), (0.95, 1.36),
                           (0.45, 1.3), (0.24, 1.3)], seg=16)  # the bowl
    m.lathe("park_stone", [(0.26, 1.28), (0.25, 1.6), (0.29, 1.64), (0.23, 1.72), (0.17, 1.74)], seg=10)  # pole collar
    m.node("detail")
    disc(m, "park_water", 2.95, 0.27)
    disc(m, "park_water", 1.18, 1.42)
    for _ in range(6):  # scum rafts on the basin water
        a, rr, s = rng.uniform(0, 360), rng.uniform(1.0, 2.5), rng.uniform(0.2, 0.5)
        c = P(rr, a, 0.275)
        m.emit("park_scum", [(c[0] + s * rng.uniform(0.6, 1.2) * math.cos(math.tau * k / 6), 0.275,
                              c[2] + s * rng.uniform(0.6, 1.2) * math.sin(math.tau * k / 6)) for k in range(6)], (c[0], 0, c[2]))
    for _ in range(4):
        a, rr = rng.uniform(0, 360), rng.uniform(1.0, 2.6)
        flat(m, "park_leafcard", 0.8, 0.8, P(rr, a, 0.28), rng.uniform(0, 360))
    flat(m, "park_leafcard", 0.7, 0.7, (0.3, 1.43, 0.5), 40)
    # a paper festival lantern drowned in the basin
    with m.push(P(1.9, 70, 0.26), (80, 30, 10)):
        m.lathe("park_paper", [(0.06, -0.2), (0.16, -0.12), (0.19, 0.0), (0.15, 0.12), (0.06, 0.19)], seg=7)
    # lion-head spouts on the pedestal (the south one still trickles: see place())
    for a in (45, 90, 135, 225, 315):
        with m.push(P(0.33, a, 0.72), (0, 90 - a, 0)):
            m.box("park_stone", (0.2, 0.2, 0.12), (0, 0, 0.02))
            m.ellipsoid("park_stone", (0.1, 0.11, 0.06), (0, 0.02, 0.09), seg=6, rings=3)
            m.cyl("park_iron", 0.03, 0.02, 0.14, (0, -0.02, 0.1), (90, 0, 0), seg=5)
    # moss on the coping, round the pedestal foot and hanging under the bowl lip
    for i in range(10):
        a = rng.uniform(0, 360)
        blob(m, "park_moss", P(3.15, a, 0.6), (rng.uniform(0.2, 0.4), 0.05, rng.uniform(0.14, 0.24)), rng)
    for a in (20, 150, 260):
        blob(m, "park_moss", P(0.72, a, 0.18), (0.3, 0.08, 0.22), rng)
    for a in (10, 100, 200, 290):
        blob(m, "park_moss", P(1.4, a, 1.3), (0.12, 0.16, 0.1), rng)
    # streaks down the outer wall, cracks on the apron and coping
    for i in range(16):
        if i != broken and i % 2:
            outward(m, "park_streak", rng.uniform(0.2, 0.4), rng.uniform(0.2, 0.35), 3.3 * 0.9808 + 0.006,
                    i * 22.5 + 11.25, 0.34)
    for a in (30, 118, 200, 300):
        flat(m, "park_crack", 1.1, 1.1, P(3.55, a, 0.103), a)
    for a in (60, 250):
        flat(m, "park_crack", 0.5, 0.5, P(3.14, a, 0.605), a)
    # the broken coping stone lies on the apron, rubble on both sides of the break
    with m.push(P(4.25, 126, 0.12), (6, rng.uniform(0, 90), 14)):
        m.box("park_stone", (1.15, 0.1, 0.55), (0, 0, 0))
    for rr, a, s in ((3.7, 118, 0.14), (4.0, 132, 0.1), (2.7, 124, 0.12), (4.6, 115, 0.08)):
        m.rock("park_stone", s, s * 1.1, P(rr, a, 0.08), (0, rng.uniform(0, 360), 0), rng, seg=5, rings=2)
    return m


# ------------------------------------------------------------------ bandstand

def m_gazebo():
    """Octagonal bandstand on a stone plinth, entry ramp on +X, rusted roof with a panel missing."""
    m = B.Model("park_gazebo")
    rng = random.Random(33)
    R, H0, HP = 3.0, 0.45, 2.9
    ang = [22.5 + 45 * i for i in range(8)]
    ap = R * math.cos(math.radians(22.5))
    m.node("gazebo-col")
    m.cyl("park_stone", R + 0.06, R, H0 - 0.04, seg=8, phase=0.5)
    m.cyl("park_wood", R - 0.06, R - 0.06, 0.04, (0, H0 - 0.04, 0), seg=8, phase=0.5)
    A, Bq, C, D = (ap, 0, -0.8), (ap, 0, 0.8), (ap, H0, 0.8), (ap, H0, -0.8)
    E, F, E2, F2 = (ap + 1.5, 0, -0.8), (ap + 1.5, 0, 0.8), (ap + 1.5, 0.08, -0.8), (ap + 1.5, 0.08, 0.8)
    c = (ap + 0.6, 0.12, 0)
    for f in ([D, C, F2, E2], [A, D, E2, E], [Bq, F, F2, C], [E, E2, F2, F]):
        m.emit("park_stone", f, c)  # entry ramp (walkable: no step-up in the controller)
    for a in ang:
        tube(m, "park_iron", [P(2.8, a, H0), P(2.8, a, HP)], 0.06, 6)
    for k in range(8):
        a0, a1 = ang[k], ang[(k + 1) % 8]
        if k == 7:
            continue  # entry side
        if k == 2:  # railing knocked in: top rail sags
            tube(m, "park_iron", [P(2.8, a0, H0 + 0.9), P(2.5, (a0 + a1) / 2, H0 + 0.35), P(2.8, a1, H0 + 0.9)], 0.03, 4)
            continue
        tube(m, "park_iron", [P(2.8, a0, H0 + 0.9), P(2.8, a1, H0 + 0.9)], 0.03, 4)
    m.node("detail")
    for k in range(8):
        a0, a1 = ang[k], ang[(k + 1) % 8]
        if k == 7:
            continue
        p0, p1 = P(2.8, a0, 0), P(2.8, a1, 0)
        tube(m, "park_iron", [(p0[0], H0 + 0.12, p0[2]), (p1[0], H0 + 0.12, p1[2])], 0.02, 4, cap=False)
        for j in range(1, 7):
            if k == 2 and j not in (1, 5):
                continue
            t = j / 7
            x, z = p0[0] + (p1[0] - p0[0]) * t, p0[2] + (p1[2] - p0[2]) * t
            m.cyl("park_iron", 0.012, 0.012, 0.78, (x, H0 + 0.12, z), seg=3, caps=False)
    m.cyl("park_iron", 0.012, 0.012, 0.78, (0.9, H0 + 0.02, -2.2), (0, 20, 88), seg=3, caps=False)  # snapped baluster
    for a in ang:  # scroll brackets under the eave
        tube(m, "park_iron", bezier(P(2.8, a, HP - 0.5), P(2.75, a, HP - 0.05), P(2.3, a, HP), 4), 0.02, 4, cap=False)
    tube(m, "park_iron", [P(2.82, a, HP) for a in ang + ang[:1]], 0.045, 4, cap=False)  # eave ring
    apex = (0, HP + 1.5, 0)
    for k in range(8):
        e0, e1 = P(3.35, ang[k], HP + 0.05), P(3.35, ang[(k + 1) % 8], HP + 0.05)
        if k == 5:  # panel blown off: bare rafters
            for e in (e0, e1):
                tube(m, "park_iron", [e, apex], 0.03, 4, cap=False)
            continue
        m.emit("park_roof", [e0, e1, apex], (0, HP, 0))
        m.emit("park_green", [e0, e1, apex], (0, HP + 3, 0))
    m.lathe("park_iron", [(0.09, HP + 1.45), (0.06, HP + 1.7), (0.1, HP + 1.76), (0.0, HP + 1.92)], seg=6)
    m.box("park_iron", (0.5, 0.04, 0.02), (0.1, HP + 1.95, 0), (0, 0, -8))  # bent weathervane
    tube(m, "park_iron", [(0, HP + 1.45, 0), (0, 2.95, 0)], 0.008, 3, cap=False)  # chain
    B.lantern(m, 0, 2.55, 0)
    for _ in range(4):
        flat(m, "park_leafcard", 1.2, 1.2, (rng.uniform(-1.8, 1.8), H0 + 0.005 + _ * 0.002, rng.uniform(-1.8, 1.8)),
             rng.uniform(0, 360))
    # music stand toppled on the deck, a folding chair still standing
    with m.push((-0.8, H0 + 0.04, 0.9), (0, 30, 86)):
        m.cyl("park_iron", 0.012, 0.012, 1.1, seg=3, caps=False)
        m.box("park_iron", (0.5, 0.35, 0.02), (0, 1.15, 0.03), (-15, 0, 0))
    with m.push((0, H0, 0)):
        B.chair(m, -1.4, -0.6, 30, "park_wood")
    return m


# ------------------------------------------------------------------ memorial statue

def m_statue():
    """Hooded mourner holding a lantern out, verdigris bronze on a stone plinth (faces +Z; plaque Label3D in place())."""
    m = B.Model("park_statue")
    rng = random.Random(5)
    m.node("plinth-col")
    m.box("park_stone", (1.9, 0.25, 1.9), (0, 0.125, 0))
    m.box("park_stone", (1.5, 0.12, 1.5), (0, 0.31, 0))
    m.box("park_stone", (1.2, 1.2, 1.2), (0, 0.97, 0))
    m.box("park_stone", (1.45, 0.14, 1.45), (0, 1.64, 0))
    m.node("figure")
    with m.push((0, 1.71, 0)):
        m.loft("park_bronze", [(0, 0.36, 0.3), (0.06, 0.37, 0.31), (0.5, 0.3, 0.24), (1.0, 0.24, 0.18), (1.3, 0.25, 0.18),
                               (1.44, 0.2, 0.15), (1.5, 0.0, 0.0)], seg=10, power=2.2)
        m.ellipsoid("park_bronze", (0.12, 0.15, 0.13), (0, 1.6, 0.06), (20, 0, 0), seg=8, rings=5)  # bowed head
        m.ellipsoid("park_bronze", (0.17, 0.2, 0.18), (0, 1.63, -0.01), (25, 0, 0), seg=8, rings=5)  # hood
        tube(m, "park_bronze", [(-0.24, 1.38, 0.0), (-0.22, 1.14, 0.2), (0.06, 1.18, 0.24)], [0.065, 0.055, 0.05], 6)
        tube(m, "park_bronze", [(0.25, 1.4, 0.0), (0.3, 1.36, 0.26), (0.28, 1.33, 0.5)], [0.065, 0.055, 0.045], 6)
        tube(m, "park_bronze", [(0.28, 1.31, 0.5), (0.28, 1.24, 0.5)], 0.008, 3, cap=False)
        m.cyl("park_bronze", 0.07, 0.09, 0.18, (0.28, 1.05, 0.5), seg=6)
        m.cyl("park_bronze", 0.03, 0.03, 0.04, (0.28, 1.23, 0.5), seg=5)
    m.node("detail")
    m.box("park_bronze", (0.8, 0.42, 0.02), (0, 1.0, 0.605))  # plaque
    for x in (-0.45, 0.2, 0.42):
        m.decal("park_streak", 0.18, 0.55, (x, 0.9, 0.603))
    for i in range(5):
        blob(m, "park_moss", (rng.uniform(-0.6, 0.6), 1.72, rng.choice((-0.62, 0.62))), (0.22, 0.05, 0.08), rng)
    for x, z in ((-0.9, 0.5), (0.8, -0.7), (0.9, 0.9)):
        blob(m, "park_moss", (x, 0.25, z), (0.25, 0.07, 0.2), rng)
    # withered wreath leaning on the plinth, dead flowers at its foot
    with m.push((0.25, 0.68, 0.7), (-20, 0, 0)):
        tube(m, "park_deadflower", [(0.28 * math.cos(math.tau * k / 10), 0.28 * math.sin(math.tau * k / 10), 0)
                                    for k in range(11)], 0.05, 5, cap=False)
    for x in (-0.3, -0.18, -0.4):
        tube(m, "park_deadflower", [(x, 0.26, 0.75), (x + 0.1, 0.28, 1.05)], 0.012, 3)
    return m


# ------------------------------------------------------------------ entrance pillars + iron arch

def m_pillar():
    m = B.Model("park_pillar")
    rng = random.Random(6)
    m.node("pillar-col")
    m.box("park_stone", (0.72, 0.3, 0.72), (0, 0.15, 0))
    m.box("park_stone", (0.6, 2.0, 0.6), (0, 1.3, 0))
    m.box("park_stone", (0.78, 0.14, 0.78), (0, 2.37, 0))
    m.node("detail")
    m.lathe("park_stone", [(0.16, 2.44), (0.21, 2.5), (0.23, 2.62), (0.18, 2.74), (0.06, 2.8), (0.0, 2.8)], seg=8)
    for side in ((0, 0, 0.301), (0, 90, 0.301), (0, 180, 0.301), (0, 270, 0.301)):
        with m.push((0, 0, 0), (0, side[1], 0)):
            m.decal("park_streak", 0.22, 0.9, (rng.uniform(-0.15, 0.15), 1.7, side[2]))
    blob(m, "park_moss", (0.2, 2.45, 0.1), (0.25, 0.06, 0.2), rng)
    blob(m, "park_moss", (-0.3, 0.3, 0.2), (0.2, 0.08, 0.3), rng)
    return m


def m_arch():
    """Wrought-iron arch over a 7.6 m gateway (pillar centres at x = +-3.8); sign plate faces +Z."""
    m = B.Model("park_arch")
    m.node("iron")
    for x in (-3.8, 3.8):
        tube(m, "park_iron", [(x, 2.44, 0), (x, 3.95, 0)], 0.045, 6)
        m.cyl("park_iron", 0.05, 0.0, 0.2, (x, 3.95, 0), seg=4)
    m.box("park_iron", (6.9, 0.56, 0.05), (0, 3.02, 0))
    for y in (2.72, 3.32):
        m.box("park_iron", (7.0, 0.05, 0.08), (0, y, 0))
    tube(m, "park_iron", bezier((-3.8, 3.34, 0), (0, 4.75, 0), (3.8, 3.34, 0), 10), 0.035, 4, cap=False)
    for x in (-2.4, -1.2, 0.0, 1.2, 2.4):
        top = 3.34 + 2 * (0.5 - abs(x) / 7.6) * (0.5 + abs(x) / 7.6) * 1.41  # under the arch band
        cy = (3.34 + top) / 2
        rr = min(0.14, (top - 3.34) / 2 - 0.02)
        tube(m, "park_iron", [(x + rr * math.cos(math.tau * k / 8), cy + rr * math.sin(math.tau * k / 8), 0)
                              for k in range(9)], 0.012, 3, cap=False)
        m.cyl("park_iron", 0.012, 0.012, top - 3.34, (x, 3.34, 0), seg=3, caps=False)
    m.decal("park_streak", 1.2, 0.3, (-1.6, 2.85, 0.028))
    m.decal("park_streak", 0.8, 0.25, (2.1, 3.15, 0.028))
    return m


def m_gate():
    """Pedestrian gate: two short pillars (x = +-0.95), one leaf hanging open off a hinge, the other fallen flat."""
    m = B.Model("park_gate")
    m.node("pillars-col")
    for x in (-0.95, 0.95):
        m.box("park_stone", (0.4, 1.7, 0.4), (x, 0.85, 0))
        m.box("park_stone", (0.5, 0.1, 0.5), (x, 1.75, 0))
    m.node("detail")

    def leaf(w=0.72, h=1.45):
        for y in (0.1, h - 0.05):
            m.box("park_iron", (w, 0.04, 0.03), (w / 2, y, 0))
        for k in range(5):
            x = 0.04 + k * (w - 0.08) / 4
            m.cyl("park_iron", 0.012, 0.012, h + 0.08, (x, 0.08, 0), seg=3, caps=False)
            m.cyl("park_iron", 0.025, 0.0, 0.08, (x, h + 0.14, 0), seg=4)
        tube(m, "park_iron", bezier((0.05, 0.12, 0), (w * 0.5, h * 0.55, 0), (w - 0.05, h - 0.07, 0), 4), 0.012, 3, cap=False)

    with m.push((-0.75, 0.05, -0.05), (0, 105, 4)):  # hanging open inward, dropped off its top hinge
        leaf()
    with m.push((0.1, 0.03, -0.9), (-90, 20, 0)):  # the other one lying in the grass
        leaf()
    return m


# ------------------------------------------------------------------ small park props

def m_kiosk():
    """Refreshment kiosk, 2.4 m square; serving hatch faces +Z behind a half-dropped shutter."""
    m = B.Model("park_kiosk")
    rng = random.Random(8)
    m.node("kiosk-col")
    m.box("park_green", (2.4, 2.3, 0.1), (0, 1.15, -1.15))
    for x in (-1.15, 1.15):
        m.box("park_green", (0.1, 2.3, 2.4), (x, 1.15, 0))
    m.box("park_green", (2.4, 0.95, 0.1), (0, 0.475, 1.15))
    m.box("park_green", (2.4, 0.3, 0.1), (0, 2.15, 1.15))
    m.box("park_wood", (2.5, 0.06, 0.4), (0, 0.98, 1.25))  # counter
    m.box("park_dark", (2.2, 1.05, 0.05), (0, 1.5, -0.6))  # dark inside
    m.node("detail")
    m.box("park_iron", (2.2, 0.62, 0.03), (0, 1.72, 1.12), (4, 0, 2))  # roll shutter, jammed half down
    m.tbox("park_roof", (2.9, 2.9), (0.2, 0.2), 0.75, (0, 2.3, 0))
    m.box("park_sign", (2.2, 0.36, 0.05), (0, 2.52, 1.23))
    m.decal("park_paper", 0.4, 0.55, (0.85, 0.6, 1.201), (0, 0, 5))  # menu, peeling
    m.decal("park_paper", 0.3, 0.4, (-0.8, 0.55, 1.201), (0, 0, -8))
    m.cyl("bulb_cold", 0.04, 0.04, 0.08, (0, 2.08, 1.3), seg=5)
    for i in range(3):
        m.decal("park_streak", rng.uniform(0.2, 0.4), 0.9, (rng.uniform(-1, 1), 1.6, -1.201), (0, 180, 0))
    for x in (-0.9, 0.3):
        m.cyl("metal", 0.035, 0.035, 0.12, (x, 1.01, 1.3), seg=5)  # cups left on the counter
    return m


def m_drinking_fountain():
    m = B.Model("park_drinking_fountain")
    rng = random.Random(9)
    m.node("body-col")
    m.lathe("park_rough", [(0.2, 0), (0.2, 0.05), (0.14, 0.1), (0.12, 0.85), (0.2, 0.9), (0.26, 0.95), (0.27, 1.0),
                           (0.0, 1.0)], seg=8)
    m.node("detail")
    disc(m, "park_stain", 0.19, 1.003, 8)
    tube(m, "metal", [(0, 1.0, 0.1), (0, 1.09, 0.1), (0, 1.1, 0.03)], 0.015, 4)
    m.box("metal", (0.06, 0.06, 0.03), (0, 0.93, 0.27))
    m.decal("park_streak", 0.12, 0.6, (0.0, 0.55, 0.125))
    blob(m, "park_moss", (0.1, 0.06, 0.12), (0.22, 0.06, 0.16), rng)
    return m


def m_birdbath():
    m = B.Model("park_birdbath")
    rng = random.Random(10)
    m.node("body-col")
    m.lathe("park_stone", [(0.3, 0), (0.28, 0.08), (0.14, 0.15), (0.1, 0.6), (0.14, 0.68), (0.42, 0.78), (0.46, 0.84),
                           (0.4, 0.85), (0.2, 0.8), (0.0, 0.8)], seg=10)
    m.node("detail")
    disc(m, "park_water", 0.36, 0.82, 10)
    blob(m, "park_moss", (0.3, 0.83, 0.2), (0.15, 0.04, 0.1), rng)
    blob(m, "park_moss", (0.0, 0.1, 0.25), (0.2, 0.08, 0.12), rng)
    with m.push((0.05, 0.84, -0.08), (0, 40, 70)):  # a dead bird on its side in the green water
        m.ellipsoid("park_dark", (0.05, 0.1, 0.045), seg=6, rings=4)
        m.ellipsoid("park_dark", (0.035, 0.035, 0.035), (0, 0.11, 0.01), seg=5, rings=3)
        m.cyl("park_paper", 0.008, 0.0, 0.04, (0, 0.14, 0.02), (80, 0, 0), seg=3)
    return m


def m_bench_broken():
    """Park bench with the seat snapped in two and the right iron end collapsed (no collision)."""
    m = B.Model("park_bench_broken")
    m.node("detail")
    x = -0.78
    tube(m, "park_iron", [(x, 0, 0.22), (x, 0.2, 0.2), (x, 0.42, 0.18)], 0.025, 5, cap=False)
    tube(m, "park_iron", bezier((x, 0.0, -0.2), (x, 0.45, -0.16), (x, 0.95, -0.3), 5), 0.025, 5, cap=False)
    with m.push((0.78, 0.03, 0.1), (0, 0, 84)):  # right end lying on its side
        tube(m, "park_iron", [(0, 0, 0.22), (0, 0.2, 0.2), (0, 0.42, 0.18)], 0.025, 5, cap=False)
        tube(m, "park_iron", bezier((0, 0.0, -0.2), (0, 0.45, -0.16), (0, 0.95, -0.3), 5), 0.025, 5, cap=False)
    with m.push((-0.85, 0.46, 0), (0, 0, -22)):  # left half of the seat slopes to the ground
        for k in range(4):
            m.box("park_wood", (1.0, 0.035, 0.07), (0.5, 0, 0.2 - k * 0.09))
    with m.push((0.15, 0.06, 0.05), (0, 12, 6)):
        for k in range(3):
            m.box("park_wood", (0.85, 0.035, 0.07), (0.42, 0, 0.2 - k * 0.1 - (0.04 if k == 2 else 0)), (0, k * 4, 0))
    with m.push((-0.85, 0.72, -0.2), (-14, 0, -30)):  # one back slat hanging off the upright end
        m.box("park_wood", (1.1, 0.09, 0.03), (0.55, 0, 0))
    m.box("park_wood", (0.9, 0.09, 0.03), (0.2, 0.05, -0.55), (90, 25, 0))
    return m


def m_oak():
    """Living (barely) deciduous tree: thick trunk, five limbs, clumped dark canopy with leaf cards."""
    m = B.Model("park_oak")
    rng = random.Random(44)
    m.node("trunk-col")
    tube(m, "bark", [(0, -0.2, 0), (0.05, 0.8, 0.03), (0.12, 1.8, -0.05), (0.1, 2.6, 0.05)], [0.46, 0.34, 0.29, 0.25], 7)
    m.node("branches")
    for i in range(4):  # root flare
        a = math.radians(i * 90 + 30)
        tube(m, "bark", [(0.2 * math.cos(a), 0.3, 0.2 * math.sin(a)), (0.75 * math.cos(a), -0.05, 0.75 * math.sin(a))],
             [0.16, 0.05], 5)
    ends = []
    for i in range(5):
        a = math.radians(i * 72 + rng.uniform(-15, 15))
        y0 = rng.uniform(2.1, 2.6)
        L = rng.uniform(2.0, 2.8)
        mid = (0.5 * L * math.cos(a), y0 + 0.9, 0.5 * L * math.sin(a))
        end = (L * math.cos(a), y0 + rng.uniform(1.4, 2.2), L * math.sin(a))
        tube(m, "bark", [(0.1 * math.cos(a), y0, 0.1 * math.sin(a)), mid, end], [0.18, 0.11, 0.04], 5)
        ends.append(end)
    m.node("canopy")
    for k, e in enumerate(ends + [(0.1, 5.0, 0.0)]):
        if k == 3:
            continue  # a bare, dead limb
        r = rng.uniform(1.0, 1.45)
        m.ellipsoid("park_foliage", (r, r * 0.7, r), (e[0], e[1] + 0.2, e[2]), (0, rng.uniform(0, 90), 0), seg=7, rings=5)
        for j in range(3):
            yaw = rng.uniform(0, 180)
            m.decal("park_canopy", 2.2 * r, 1.8 * r, (e[0] + rng.uniform(-0.4, 0.4), e[1] + 0.3, e[2] + rng.uniform(-0.4, 0.4)),
                    (rng.uniform(-20, 20), yaw, 0))
    return m


def m_leaves():
    """Ground patch of leaf litter (~3 m across, no collision). Sits above the lot surface (y 0.07)."""
    m = B.Model("park_leaves")
    rng = random.Random(55)
    m.node("litter")
    for i in range(6):
        s = rng.uniform(0.9, 1.5)
        flat(m, "park_leafcard", s, s, (rng.uniform(-1.1, 1.1), 0.085 + i * 0.003, rng.uniform(-1.1, 1.1)), rng.uniform(0, 360))
    for _ in range(2):
        a = rng.uniform(0, math.tau)
        tube(m, "bark", [(0, 0.1, 0), (0.6 * math.cos(a), 0.09, 0.6 * math.sin(a))], [0.015, 0.005], 3, cap=False)
    return m


def m_weeds():
    """Weed tuft pushing out of the paving cracks (no collision)."""
    m = B.Model("park_weeds")
    m.node("blades")
    for yaw in (0, 60, 120):
        m.decal("park_weedcard", 0.55, 0.4, (0, 0.2, 0), (0, yaw, 0))
    flat(m, "park_leafcard", 0.5, 0.5, (0, 0.012, 0), 30)  # (placed on the paving: just over it at any scale)
    return m


def m_litter():
    """Newspapers, cans, a bottle and a paper cup (no collision)."""
    m = B.Model("park_litter")
    rng = random.Random(66)
    m.node("litter")
    for x, z, yaw in ((0.0, 0.0, 20), (0.5, 0.4, 70)):
        with m.push((x, 0.085, z), (0, yaw, 0)):
            m.emit("park_paper", [(-0.3, 0, -0.2), (0, 0.02, -0.2), (0, 0.02, 0.2), (-0.3, 0, 0.2)], (0, -1, 0))
            m.emit("park_paper", [(0, 0.02, -0.2), (0.3, 0.05, -0.2), (0.3, 0.05, 0.2), (0, 0.02, 0.2)], (0, -1, 0))
    for x, z in ((-0.6, 0.3), (0.2, -0.5)):
        m.cyl("metal", 0.033, 0.033, 0.12, (x, 0.11, z), (0, rng.uniform(0, 180), 90), seg=6)
    with m.push((0.7, 0.12, -0.3), (0, 30, 90)):
        m.lathe("park_bottle", [(0.0, 0.0), (0.04, 0.0), (0.04, 0.18), (0.015, 0.25), (0.015, 0.3), (0.0, 0.3)], seg=6)
    m.cyl("park_paper", 0.03, 0.04, 0.1, (-0.3, 0.12, -0.4), (80, 40, 0), seg=6, caps=False)
    return m


def m_slabs():
    """Lifted, cracked paving slabs heaved up by a root, weeds in the joints (no collision)."""
    m = B.Model("park_slabs")
    rng = random.Random(77)
    m.node("slabs")
    for x, z, rx, rz in ((0, 0, 9, 3), (0.75, 0.05, -4, 11), (-0.1, 0.78, 6, -7), (0.7, 0.8, -2, -3)):
        m.box("flagstone", (0.72, 0.08, 0.72), (x, 0.08, z), (rx, rng.uniform(-6, 6), rz))
    tube(m, "bark", [(-0.8, 0.05, 0.3), (-0.2, 0.1, 0.4), (0.4, 0.11, 0.38), (1.3, 0.05, 0.5)], [0.04, 0.07, 0.06, 0.03], 5)
    flat(m, "park_crack", 1.4, 1.4, (0.3, 0.13, 0.3), 25)
    for x, z, yaw in ((0.37, 0.4, 0), (-0.4, 0.4, 50)):
        m.decal("park_weedcard", 0.45, 0.3, (x, 0.2, z), (0, yaw, 0))
    return m


def m_sign():
    """Park rules board on two posts, facing +Z (text is a Label3D in place())."""
    m = B.Model("park_sign")
    rng = random.Random(88)
    m.node("posts-col")
    for x in (-0.8, 0.8):
        m.box("park_wood", (0.1, 1.7, 0.1), (x, 0.85, -0.06))
    m.node("detail")
    with m.push((0, 1.28, 0), (0, 0, 3)):
        m.box("park_sign", (1.9, 0.8, 0.04), (0, 0, 0))
        for y in (-0.42, 0.42):
            m.box("park_wood", (2.0, 0.06, 0.06), (0, y, 0))
        m.decal("park_streak", 0.5, 0.6, (0.6, 0.0, 0.021))
    blob(m, "park_moss", (-0.8, 1.72, -0.06), (0.08, 0.03, 0.08), rng)
    return m


MODELS = [m_fountain, m_gazebo, m_statue, m_pillar, m_arch, m_gate, m_kiosk, m_drinking_fountain, m_birdbath,
          m_bench_broken, m_oak, m_leaves, m_weeds, m_litter, m_slabs, m_sign]


# ------------------------------------------------------------------ placement

def tf(x, y, z, rot=(0, 0, 0), s=(1, 1, 1)):
    R = B.rot3(*rot)
    return "Transform3D(%s, %g, %g, %g)" % (", ".join("%.5g" % (R[i][j] * s[j]) for i in range(3) for j in range(3)), x, y, z)


def put(W, model, x, z, rot=(0, 0, 0), y=0.0, s=(1, 1, 1)):
    """Instance with a full rotation (pitch, yaw, roll degrees) / non-uniform scale: toppled and squashed props."""
    W.add(model, "Props", instance=W.res("res://models/%s.glb" % model, "PackedScene"), transform=tf(x, y, z, rot, s))


def fence(W, axis, fixed, centres, lean=()):
    """fence_iron (3 m, -col) along x (axis 'x', at z=fixed) or z (at x=fixed); `lean` centres are knocked askew."""
    for c in centres:
        x, z, yaw = (c, fixed, 0) if axis == "x" else (fixed, c, 90)
        if c in lean:
            put(W, "fence_iron", x, z, (-16, yaw, 3))
        else:
            W.inst("fence_iron", x, z, yaw)


def clear_of(x, z, keep):
    return all((x - kx) ** 2 + (z - kz) ** 2 > kr * kr for kx, kz, kr in keep)


def mat(W, typ, **props):
    return W.sub(typ, **props)


def fx(W):
    """Fog, drips, leaves: GPUParticles3D + FogVolume (project renders Forward+, same setup as the player's Ash)."""
    root = W.add("ParkFX", "Props", "Node3D")
    fx0, fz0 = FOUNTAIN
    drop_mat = mat(W, "StandardMaterial3D", transparency=1, shading_mode=0, albedo_color="Color(0.55, 0.64, 0.6, 0.6)",
                   billboard_mode=2, billboard_keep_scale="true")
    drop = mat(W, "QuadMesh", material=drop_mat, size="Vector2(0.018, 0.09)")
    lip = mat(W, "ParticleProcessMaterial", emission_shape=6, emission_ring_axis="Vector3(0, 1, 0)",
              emission_ring_height=0.0, emission_ring_radius=1.47, emission_ring_inner_radius=1.43,
              direction="Vector3(0, -1, 0)", spread=4.0, initial_velocity_min=0.0, initial_velocity_max=0.15,
              gravity="Vector3(0, -9.8, 0)")
    W.add("BowlDrips", root, "GPUParticles3D", transform=B.xform(fx0, 1.44, fz0), amount=14, lifetime=0.5, randomness=0.6,
          cast_shadow=0, visibility_aabb="AABB(-2, -1.5, -2, 4, 2, 4)", process_material=lip, draw_pass_1=drop)
    spout = mat(W, "ParticleProcessMaterial", direction="Vector3(0, 0, 1)", spread=3.0, initial_velocity_min=0.45,
                initial_velocity_max=0.55, gravity="Vector3(0, -9.8, 0)")
    W.add("SpoutTrickle", root, "GPUParticles3D", transform=B.xform(fx0, 0.7, fz0 + 0.52), amount=16, lifetime=0.3,
          cast_shadow=0, visibility_aabb="AABB(-0.5, -0.6, -0.2, 1, 0.8, 1)", process_material=spout, draw_pass_1=drop)

    # drifting ground fog: soft radial billboards fading in and out, plus a low FogVolume over the park
    soft = mat(W, "Gradient", offsets="PackedFloat32Array(0, 1)", colors="PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)")
    soft_tex = mat(W, "GradientTexture2D", gradient=soft, fill=1, fill_from="Vector2(0.5, 0.5)",
                   fill_to="Vector2(0.5, 0)", width=64, height=64)
    wisp_mat = mat(W, "StandardMaterial3D", transparency=1, shading_mode=0, vertex_color_use_as_albedo="true",
                   albedo_color="Color(0.6, 0.68, 0.64, 0.14)", albedo_texture=soft_tex, billboard_mode=3,
                   particles_anim_h_frames=1, particles_anim_v_frames=1, proximity_fade_enabled="true",
                   proximity_fade_distance=1.5)
    wisp = mat(W, "QuadMesh", material=wisp_mat, size="Vector2(7, 3)")
    fade = mat(W, "Gradient", offsets="PackedFloat32Array(0, 0.25, 0.75, 1)",
               colors="PackedColorArray(1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0)")
    wisp_proc = mat(W, "ParticleProcessMaterial", emission_shape=3, emission_box_extents="Vector3(27, 0.4, 16)",
                    direction="Vector3(1, 0, 0.3)", spread=25.0, initial_velocity_min=0.15, initial_velocity_max=0.4,
                    gravity="Vector3(0, 0, 0)", scale_min=0.7, scale_max=1.4,
                    color_ramp=mat(W, "GradientTexture1D", gradient=fade))
    W.add("FogWisps", root, "GPUParticles3D", transform=B.xform(0, 0.9, 8), amount=20, lifetime=30.0, preprocess=30.0,
          cast_shadow=0, visibility_aabb="AABB(-36, -2, -22, 72, 6, 44)", process_material=wisp_proc, draw_pass_1=wisp)
    fog = mat(W, "FogMaterial", density=0.07, albedo="Color(0.7, 0.76, 0.72, 1)", height_falloff=0.9, edge_fade=0.5)
    W.add("GroundFog", root, "FogVolume", transform=B.xform(0, 0.3, 8), size="Vector3(64, 3, 48)", shape=0, material=fog)

    # leaves drifting down under the trees
    browns = mat(W, "Gradient", offsets="PackedFloat32Array(0, 0.5, 1)",
                 colors="PackedColorArray(0.42, 0.26, 0.1, 1, 0.3, 0.22, 0.1, 1, 0.2, 0.13, 0.07, 1)")
    leaf_mat = mat(W, "StandardMaterial3D", vertex_color_use_as_albedo="true", billboard_mode=3,
                   particles_anim_h_frames=1, particles_anim_v_frames=1, cull_mode=2)
    leaf = mat(W, "QuadMesh", material=leaf_mat, size="Vector2(0.12, 0.08)")
    leaf_proc = mat(W, "ParticleProcessMaterial", emission_shape=3, emission_box_extents="Vector3(26, 1.5, 15)",
                    direction="Vector3(0, -1, 0)", spread=25.0, initial_velocity_min=0.6, initial_velocity_max=0.9,
                    gravity="Vector3(0.15, -0.05, 0.05)", angle_min=0.0, angle_max=360.0, angular_velocity_min=-140.0,
                    angular_velocity_max=140.0, turbulence_enabled="true", turbulence_noise_strength=1.5,
                    turbulence_noise_scale=4.0, turbulence_influence_min=0.05, turbulence_influence_max=0.15,
                    color_initial_ramp=mat(W, "GradientTexture1D", gradient=browns))
    W.add("FallingLeaves", root, "GPUParticles3D", transform=B.xform(0, 7.0, 10), amount=36, lifetime=9.0, preprocess=9.0,
          cast_shadow=0, visibility_aabb="AABB(-30, -8, -18, 60, 10, 36)", process_material=leaf_proc, draw_pass_1=leaf)


def place(W, rng):
    rng = random.Random(1851)  # own stream: the shared one drives the rest of the map
    fx0, fz0 = FOUNTAIN
    gx, gz = GAZEBO

    # --- fountain under the festival pole (build_assets keeps the lantern scatter out of it)
    W.inst("park_fountain", fx0, fz0)
    W.light(fx0 + 2.3, 6.1, fz0, (1.0, 0.55, 0.28), 0.9, 10, flicker=True)  # one festival lantern still burning
    fx(W)

    # --- bandstand (entry ramp faces the dirt path), memorial statue, kiosk, drinking fountain, bird bath
    W.inst("park_gazebo", gx, gz)
    W.light(gx, 2.3, gz, B.WARM, 0.7, 6, flicker=True)
    W.inst("park_statue", -19, -7.3)
    W.board_label("FOR THE NINE\nWHO NEVER\nCAME HOME", (-19, -7.3, 0), (0, 1.0, 0.615), (0.8, 0.42), (0.55, 0.62, 0.5),
                  12, localize=True)
    W.inst("park_kiosk", 23, -7.5, -90)
    W.board_label("REFRESHMENTS", (23, -7.5, -90), (0, 2.555, 1.255), (2.2, 0.29), (0.75, 0.7, 0.55), 28)  # (above
    #                                                                       the shutter box hiding its lower edge)
    W.light(21.6, 2.05, -7.5, B.SICK, 0.6, 5, flicker=True)
    W.inst("park_drinking_fountain", 16.5, -5.2, 200)
    W.inst("park_birdbath", -13.9, 17.5)

    # --- entrances: west arch (the sawmill road), east pillars, the south rules board, a broken side gate
    for z in (-3.8, 3.8):
        W.inst("park_pillar", -29.3, z)
        W.inst("park_pillar", 29.3, z)
    W.inst("park_arch", -29.3, 0, -90)
    W.board_label("HOLLOWMERE MEMORIAL PARK", (-29.3, 0, -90), (0, 3.02, 0.025), (6.9, 0.52), (0.62, 0.6, 0.5), 34)
    W.inst("park_sign", -4.8, 28.3)
    W.board_label("HOLLOWMERE MEMORIAL PARK\nCLOSED AT DUSK", (-4.8, 28.3, 0), (0, 1.28, 0.02), (1.8, 0.72),
                  (0.7, 0.68, 0.58), 16, localize=True)
    W.inst("park_gate", -17.25, 29.3)

    # --- wrought-iron fence round the lawns: gaps for the lanes, planters and a pulled-out panel
    fence(W, "x", 29.3, (-5.8, -8.8, -14.8, -19.7, -22.7, -25.7, -27.8), lean=(-22.7, -27.8))  # south, west of the
    # entry (the corner panel overlaps its neighbour by 0.9 m: knocked askew, so their rails don't z-fight)
    fence(W, "x", 29.3, (8.8, 11.8, 14.8, 17.8, 20.8, 23.8, 26.8), lean=(20.8,))          # south, east of the bus stop
    fence(W, "z", -29.3, (-10.2, -5.8, 5.8, 8.8, 11.8, 14.8, 17.8, 22.3, 25.3, 28.3))       # west (planter at z=20)
    fence(W, "z", 29.3, (-8.8, -5.8, 5.8, 10.2, 13.2, 19.2, 22.2, 25.2, 28.2), lean=(10.2,))  # east (gap: dirt path)

    # --- hedges along the promenade; the east ones were ploughed through by the wreck
    for x, z, yaw in ((-27.2, 4.6, 0), (-22.5, 4.6, 0), (-13.9, 4.6, 0), (23.4, 4.6, 0), (27.2, 4.6, 0),
                      (-24.5, -10.2, 0), (-13.5, -10.2, 0)):
        W.inst("town_hedge", x, z, yaw)
    put(W, "town_hedge", 14.4, 4.4, (0, 18, 7), s=(0.8, 0.45, 1.0))
    put(W, "town_hedge", 20.9, 3.9, (0, -25, -9), s=(0.6, 0.35, 0.9))

    # --- trees: two living oaks, dead ones on the lawns
    W.inst("park_oak", -26, 9.5, 30)
    W.inst("park_oak", 15.5, 24.5, 200, 0.9)
    for x, z, s in ((-22, 26.5, 1.0), (-11, -6.8, 0.9), (15, 9.8, 1.1), (27.5, 20.5, 0.85)):
        W.inst("dead_tree", x, z, rng.uniform(0, 360), s)

    # --- rusted playground on the east lawn, a toppled street lamp
    W.inst("swing_set", 22.5, 24)
    W.inst("slide", 26.3, 11.5, 180)
    put(W, "lamp_post", 18.6, 12.2, (0, 10, -90), y=0.22)

    # --- benches: some sound, one snapped, one tipped on its back
    for x, z, yaw in ((-6.2, 14, 90), (-19, -4.4, 180), (-22.5, 11.6, 200)):
        W.inst("bench", x, z, yaw)
    W.inst("park_bench_broken", -4.4, 18.4, 135)
    W.inst("park_bench_broken", -20.8, 23.8, 190)
    put(W, "bench", -5.8, 11.9, (-80, 250, 0), y=0.27)

    # --- trash and festival leftovers
    for x, z in ((24.8, -5.4), (-7.2, 28.1), (10.5, -27.5)):
        W.inst("town_trash_bags", x, z, rng.uniform(0, 360))

    # --- overgrowth: hiding grass (ext_tall_grass = hiding spot for the player), weeds, leaves, litter, heaved slabs
    for x, z in ((-28.2, 12.6), (-27.6, 14.2), (-28.3, 22.0), (-25.8, 23.6), (-19.4, 27.6), (-13.3, 24.2),
                 (-13.2, 12.8), (-27.2, -9.3), (-9.6, -9.5), (28.2, 23.5), (28.0, 18.8), (13.4, 13.0),
                 (24.8, 28.2), (17.4, 28.2), (13.2, 20.8), (27.6, 7.2)):
        W.inst("ext_tall_grass", x, z, rng.uniform(0, 360), rng.uniform(0.9, 1.25))
    keep = [(14, -16, 4.5), (-18, -16, 3.0), (0, -10, 5.5), (fx0, fz0, 4.0), (gx, gz, 3.4), (-19, -7.3, 1.3),
            (23, -7.5, 1.8)]
    placed = 0
    while placed < 44:
        x, z = rng.uniform(-29, 29), rng.uniform(-29, 29)
        if clear_of(x, z, keep):
            W.inst("park_weeds", x, z, rng.uniform(0, 360), rng.uniform(0.7, 1.4), y=0.07)  # (on the lots' top)
            placed += 1
    for _ in range(22):
        x, z = rng.uniform(-29, 29), rng.uniform(-11, 29)
        if clear_of(x, z, [(fx0, fz0, 3.9), (gx, gz, 3.2)]):
            W.inst("park_leaves", x, z, rng.uniform(0, 360), rng.uniform(0.8, 1.3))
    for x, z in ((-26, 9.5), (15.5, 24.5), (-22, 26.5), (-11, -6.8)):  # thicker under the trees
        W.inst("park_leaves", x + 1.2, z - 0.8, rng.uniform(0, 360), 1.3)
    for _ in range(14):
        x, z = rng.uniform(-28, 28), rng.uniform(-28, 28)
        if clear_of(x, z, keep):
            W.inst("park_litter", x, z, rng.uniform(0, 360))
    for x, z in ((-9.5, 24.5), (9.8, 5.5), (-3.5, -22.5), (20.5, -1.8), (-22.5, 1.9), (5.5, 27.0), (-10.5, -14.5)):
        W.inst("park_slabs", x, z, rng.uniform(0, 360))
