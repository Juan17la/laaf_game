"""Exterior prop pack: street furniture, forest dressing, hiding grass. Auto-loaded by build_assets.
Smooth SA-era versions; shared smooth helpers (tube, bezier, xloft, lens, wheel) come from models_hd_street."""
import math
import random

import build_assets as B
import models_hd_street as H

tube, bezier, xloft, lens = H.tube, H.bezier, H.xloft, H.lens

_BLADES = [(random.Random(7 + i).uniform(2, 62), random.Random(90 + i).uniform(-1, 1),
            random.Random(40 + i).uniform(1.5, 3.2), random.Random(60 + i).uniform(0.55, 1.0)) for i in range(18)]


def t_ext_grasscard(x, y, a, b, r):
    """Alpha card of dry grass blades, base at the bottom of the image."""
    t = (63 - y) / 63
    for x0, lean, w, h in _BLADES:
        if t < h:
            cx = x0 + lean * 14 * t * t
            if abs(x - cx) < w * (1 - t / h) + 0.4:
                c = B.mix((0.16, 0.18, 0.08), (0.52, 0.5, 0.3), min(1, t * 1.4 + 0.2 * a))
                return (*B.mul(c, 0.85 + 0.25 * b), 1.0)
    return (0, 0, 0, 0.0)


def t_ext_leafcard(x, y, a, b, r):
    d = math.hypot(x - 32, y - 32) / 32
    if d < 1 and a + 0.35 * (1 - d) > 0.62 and r > 0.12:
        return (*B.mul((0.12, 0.17, 0.08), 0.6 + 0.7 * b), 1.0)
    return (0, 0, 0, 0.0)


def t_ext_poster(x, y, a, b, r):
    """Faded, peeling bus-shelter ad: a face-shaped blotch and headline bars."""
    c = B.mul((0.55, 0.5, 0.42), 0.7 + 0.35 * a)
    if 8 < y < 14 and 6 < x < 58:
        c = (0.35, 0.08, 0.06)
    if math.hypot(x - 32, y - 36) < 13:
        c = B.mix(c, (0.45, 0.33, 0.28), 0.8)
    if b > 0.68:
        c = B.mul(c, 0.4)  # torn off
    return c


B.TEXTURES.update({"ext_grasscard": t_ext_grasscard, "ext_leafcard": t_ext_leafcard, "ext_poster": t_ext_poster})
B.ALPHA_TEX.update({"ext_grasscard", "ext_leafcard"})
B.MATS.update({
    "ext_blade": B.M("grass", (1.1, 1.05, 0.8), 0.5),
    "ext_char": B.M("rust", (0.3, 0.28, 0.26)),
    "ext_fuel": B.M("rust", (1.0, 0.45, 0.4)),
    "ext_grasscard": B.M("ext_grasscard", fit=True), "ext_leafcard": B.M("ext_leafcard", fit=True),
    "ext_poster": B.M("ext_poster", fit=True, emit=0.25),
    "ext_green": B.M("metal", (0.35, 0.5, 0.38), 1.5), "ext_galv": B.M("metal", (1.1, 1.1, 1.05), 0.8),
    "ext_redpaint": B.M("rust", (1.2, 0.35, 0.3), 1.0), "ext_ceramic": B.M("plain", (0.5, 0.55, 0.5), 1, rough=0.3),
})


# ============================================================== helpers

def blob(m, mat, r, pos, rng, squash=(1, 1, 1), seg=9, rings=6, jit=0.15):
    """Lumpy smooth sphere (bush clumps, boulders)."""
    rows = []
    for k in range(rings + 1):
        phi = math.pi * k / rings
        ring = []
        for j in range(seg):
            a = -2 * math.pi * j / seg
            f = 1 + (rng.uniform(-jit, jit) if 0 < k < rings else 0)
            ring.append((math.sin(phi) * math.cos(a) * r * f * squash[0], -math.cos(phi) * r * squash[1] * f,
                         math.sin(phi) * math.sin(a) * r * f * squash[2]))
        rows.append(ring)
    with m.push(pos):
        m.surface(mat, rows, wrap=True)


def prism(m, mat, poly, depth, pos=(0, 0, 0), rot=(0, 0, 0)):
    """Extrude a convex 2D polygon [(x, y)] along local Z (flat shaded)."""
    d = depth / 2
    with m.push(pos, rot):
        f = [(x, y, d) for x, y in poly]
        b = [(x, y, -d) for x, y in poly]
        cx, cy = sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly)
        c = (cx, cy, 0)
        m.emit(mat, f, c)
        m.emit(mat, b, c)
        for i in range(len(poly)):
            j = (i + 1) % len(poly)
            m.emit(mat, [f[i], f[j], b[j], b[i]], c)


def card(m, mat, w, h, pos, yaw, bend=0.15, rows=3):
    """Curved alpha card (double-sided via the alpha material), base at pos."""
    with m.push(pos, (0, yaw, 0)):
        grid = []
        for k in range(rows + 1):
            t = k / rows
            z = bend * t * t
            grid.append([(w / 2, h * t, z), (-w / 2, h * t, z)])
        m.surface(mat, grid, uv=lambda p: (0.5 - p[0] / w, 1 - p[1] / h))


# ============================================================== nature

def m_tall_grass():
    """Hiding spot: no collision. Crossed curved alpha cards of dry grass."""
    m = B.Model("ext_tall_grass")
    rng = random.Random(5)
    m.node("blades")
    for i in range(9):
        a = i * 137.5
        r = rng.uniform(0, 0.55)
        x, z = r * math.cos(math.radians(a)), r * math.sin(math.radians(a))
        card(m, "ext_grasscard", rng.uniform(0.9, 1.3), rng.uniform(1.1, 1.6), (x, 0, z), rng.uniform(0, 180),
             rng.uniform(0.1, 0.3))
    for i in range(10):  # a few solid stems so the clump reads at distance / grazing angles
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0, 0.5)
        x, z = r * math.cos(a), r * math.sin(a)
        h = rng.uniform(0.9, 1.4)
        lx, lz = rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25)
        tube(m, "ext_blade", [(x, 0, z), (x + lx * 0.3, h * 0.5, z + lz * 0.3), (x + lx, h, z + lz)], [0.025, 0.015, 0.0], 3, cap=False)
    return m


def m_bush():
    m = B.Model("ext_bush")
    rng = random.Random(8)
    m.node("leaves")
    for x, z, r in ((0, 0, 0.8), (0.55, 0.3, 0.55), (-0.5, 0.35, 0.5), (0.1, -0.5, 0.55)):
        blob(m, "pine", r, (x, r * 0.55, z), rng, (1, 0.85, 1), seg=8, rings=5, jit=0.2)
    for i in range(7):
        a = i * 51
        r = rng.uniform(0.3, 0.7)
        card(m, "ext_leafcard", 0.9, 0.9, (r * math.cos(math.radians(a)), rng.uniform(0.1, 0.5), r * math.sin(math.radians(a))),
             a + 90, 0.2)
    for i in range(3):  # dead twigs poking out
        a = rng.uniform(0, math.tau)
        tube(m, "bark", [(0.3 * math.cos(a), 0.4, 0.3 * math.sin(a)), (0.8 * math.cos(a), 1.05, 0.8 * math.sin(a))],
             [0.02, 0.0], 3, cap=False)
    return m


def m_boulder():
    m = B.Model("ext_boulder")
    rng = random.Random(4)
    m.node("rock-col")
    blob(m, "rock", 1.2, (0, 0.35, 0), rng, (1.1, 0.8, 0.9), seg=11, rings=7, jit=0.14)
    blob(m, "rock", 0.5, (0.95, 0.1, 0.6), rng, (1, 0.7, 1), seg=8, rings=5, jit=0.2)
    return m


# ============================================================== street furniture


def post(m, mat, x, z, h, w=0.05, y=0.0, power=4, seg=8):
    """Rounded square post (vertical superellipse loft) with capped ends."""
    m.loft(mat, [(0, 0, 0), (0, w, w), (h, w, w), (h, 0, 0)], (x, y, z), seg=seg, power=power)


def m_phone_booth():
    """Open front (+Z): red frame, glass sides with mullions, domed roof, payphone on the back wall."""
    m = B.Model("ext_phone_booth")
    m.node("booth-col")
    m.box("concrete", (1.2, 0.1, 1.2), (0, 0.05, 0))
    for x in (-0.5, 0.5):
        for z in (-0.5, 0.5):
            post(m, "ext_redpaint", x, z, 2.3, 0.055, 0.1)
    m.box("ext_redpaint", (1.0, 0.9, 0.04), (0, 0.55, -0.5))
    for x in (-0.5, 0.5):
        m.box("ext_redpaint", (0.04, 0.9, 0.9), (x, 0.55, 0))
    m.node("detail")
    m.loft("ext_redpaint", [(0, 0.6, 0.6), (0.14, 0.6, 0.6), (0.2, 0.57, 0.57), (0.3, 0.42, 0.42), (0.34, 0.2, 0.2),
                            (0.35, 0, 0)], (0, 2.3, 0), seg=16, power=4)
    m.loft("hs_dark", [(0, 0, 0), (0, 0.56, 0.56)], (0, 2.3, 0), seg=16, power=4)  # ceiling underside
    m.box("bulb_cold", (0.4, 0.03, 0.4), (0, 2.29, 0))
    for sd in (-1, 1):  # sign band "PHONE" boxes on the sides
        m.box("white", (0.02, 0.14, 0.7), (sd * 0.6, 2.38, 0))
        m.box("white", (0.7, 0.14, 0.02), (0, 2.38, sd * 0.6))
    # glass: back + sides, with mullions
    m.box("glass", (0.95, 1.3, 0.02), (0, 1.65, -0.5))
    for x in (-0.5, 0.5):
        m.box("glass", (0.02, 1.3, 0.95), (x, 1.65, 0))
    for y in (1.0, 1.43, 1.87, 2.3):
        m.box("ext_redpaint", (1.0, 0.04, 0.05), (0, y, -0.5))
        for x in (-0.5, 0.5):
            m.box("ext_redpaint", (0.05, 0.04, 1.0), (x, y, 0))
    m.decal("hs_crack", 0.5, 0.4, (0.515, 1.55, 0.1), (0, 90, 0))
    # payphone: rounded body, keypad, coin slot, handset dangling on its cord
    with m.push((0, 1.45, -0.44)):
        m.loft("hs_chrome", [(0, 0, 0), (0, 0.15, 0.06), (0.5, 0.15, 0.06), (0.5, 0, 0)], (0, -0.25, 0), seg=10, power=5)
        m.box("hs_dark", (0.1, 0.12, 0.02), (0, -0.02, 0.06))
        m.box("hs_dark", (0.06, 0.015, 0.02), (0.07, 0.17, 0.06))
        m.box("hs_dark", (0.03, 0.2, 0.05), (-0.12, 0.02, 0.06))  # hook
    tube(m, "hs_dark", bezier((-0.12, 1.3, -0.4), (-0.15, 0.6, -0.3), (-0.05, 0.75, -0.25), 6), 0.012, 3, cap=False)
    m.capsule("hs_dark", 0.03, 0.03, 0.2, (-0.05, 0.85, -0.25), (10, 0, 5), seg=6)
    m.box("hs_wood", (0.5, 0.03, 0.2), (0, 0.95, -0.38))  # shelf
    m.box("sheet", (0.2, 0.05, 0.14), (0.1, 0.99, -0.38), (0, 10, 0))  # directory
    return m


def m_mailbox():
    """Rural mailbox on a wooden post, flag up, door hanging open (faces +Z)."""
    m = B.Model("ext_mailbox")
    m.node("post-col")
    post(m, "hs_wood", 0, 0, 1.1, 0.05, power=6, seg=6)
    m.node("detail")
    m.box("hs_wood", (0.08, 0.05, 0.5), (0, 1.08, 0.1))
    tube(m, "hs_wood", [(0, 0.8, 0.0), (0, 1.05, 0.25)], 0.025, 4)
    m.loft("rust", [(0, 0, 0), (0, 0.125, 0.14), (0.5, 0.125, 0.14), (0.5, 0, 0)],
           (0, 1.25, -0.15), (90, 0, 0), seg=14, power=3)
    m.loft("hs_dark", [(0, 0.11, 0.125), (0.001, 0, 0)], (0, 1.25, 0.351), (90, 0, 0), seg=14, power=3)
    with m.push((0, 1.13, 0.36), (100, 0, 0)):  # door, dropped open
        m.loft("rust", [(0, 0, 0), (0, 0.125, 0.14), (0.02, 0.125, 0.14), (0.02, 0, 0)], (0, 0, -0.12), (90, 0, 0), seg=14, power=3)
    m.box("ext_redpaint", (0.015, 0.3, 0.03), (0.135, 1.35, -0.05))
    m.box("ext_redpaint", (0.012, 0.1, 0.16), (0.14, 1.45, 0.0))
    m.box("sheet", (0.14, 0.01, 0.22), (0, 1.14, 0.1), (0, 8, 0))  # soggy letters
    return m


def m_dumpster():
    m = B.Model("ext_dumpster")
    m.node("body-col")
    m.tbox("ext_green", (1.8, 1.0), (2.0, 1.2), 1.1, (0, 0.15, 0))
    m.node("detail")
    y = 1.25
    tube(m, "ext_green", [(-1.0, y, -0.6), (1.0, y, -0.6), (1.0, y, 0.6), (-1.0, y, 0.6), (-1.0, y, -0.6)], 0.04, 5)
    for x in (-0.6, 0, 0.6):
        for sd in (-1, 1):
            m.tbox("ext_green", (0.08, 0.05), (0.08, 0.05), 1.05, (x, 0.18, sd * (0.52 + 0.04)), (sd * 5.2, 0, 0))
    for sd in (-1, 1):
        m.box("rust", (0.3, 0.14, 1.26), (sd * 0.55, 0.45, 0))  # fork pockets
        m.box("rust", (0.05, 0.3, 0.1), (sd * 1.0, 1.0, 0))  # lift pins
    for x in (-0.75, 0.75):
        for z in (-0.4, 0.4):
            m.box("iron", (0.1, 0.05, 0.1), (x, 0.13, z))
            m.cyl("rubber", 0.07, 0.07, 0.06, (x, 0.07, z - 0.03), (90, 0, 0), seg=8)
    # lids: one shut at a slant, one flipped back over the rear
    with m.push((-0.5, 1.28, -0.6), (-8, 0, 0)):
        m.loft("rubber", [(0, 0, 0), (0, 0.49, 0.62), (0.05, 0.49, 0.62), (0.07, 0.45, 0.58), (0.071, 0, 0)],
               (0, 0, 0.62), seg=10, power=6)
    with m.push((0.5, 1.28, -0.6), (-150, 0, 0)):
        m.loft("rubber", [(0, 0, 0), (0, 0.49, 0.62), (0.05, 0.49, 0.62), (0.07, 0.45, 0.58), (0.071, 0, 0)],
               (0, 0, 0.62), seg=10, power=6)
    rng = random.Random(3)
    for x, y, z, r in ((0.45, 1.25, 0.0, 0.32), (0.75, 1.2, 0.2, 0.28), (1.35, 0.25, 0.45, 0.3), (1.2, 0.2, -0.1, 0.25)):
        blob(m, "hs_dark", r, (x, y, z), rng, (1, 0.75, 1.1), seg=7, rings=5, jit=0.2)  # trash bags
        tube(m, "hs_dark", [(x, y + r * 0.65, z), (x + 0.03, y + r * 0.95, z)], [0.05, 0.02], 4)
    return m


def m_trash_can():
    """Ribbed galvanized can, lid knocked off and trash spilled toward +Z."""
    m = B.Model("ext_trash_can")
    m.node("can-col")
    prof = [(0.26, 0.0), (0.27, 0.03)]
    for k in range(3):
        y = 0.18 + k * 0.25
        prof += [(0.28 + k * 0.006, y), (0.295 + k * 0.006, y + 0.02), (0.28 + k * 0.006, y + 0.04)]
    prof += [(0.3, 0.86), (0.315, 0.88), (0.315, 0.9), (0.29, 0.9), (0.285, 0.75), (0, 0.72)]
    m.lathe("ext_galv", prof, seg=12)
    m.node("detail")
    for sd in (-1, 1):
        tube(m, "ext_galv", [(sd * 0.3, 0.72, -0.08), (sd * 0.36, 0.74, -0.06), (sd * 0.36, 0.74, 0.06), (sd * 0.3, 0.72, 0.08)],
             0.012, 4, cap=False)
    rng = random.Random(6)
    blob(m, "hs_dark", 0.22, (0.05, 0.8, 0.0), rng, (1.1, 0.5, 1.1), seg=7, rings=4)  # overflowing bag
    with m.push((0.25, 0.03, 0.68), (-6, 25, 4)):  # lid on the ground
        m.lathe("ext_galv", [(0, -0.02), (0.31, -0.02), (0.32, 0.0), (0.3, 0.03), (0.2, 0.05), (0, 0.07)], seg=12)
        tube(m, "ext_galv", [(-0.08, 0.07, 0), (-0.06, 0.12, 0), (0.06, 0.12, 0), (0.08, 0.07, 0)], 0.012, 4, cap=False)
    for i in range(5):
        a = rng.uniform(-0.8, 0.8)
        d = rng.uniform(0.35, 0.9)
        m.box(rng.choice(("sheet", "hs_seat", "white")), (rng.uniform(0.08, 0.2), 0.02, rng.uniform(0.08, 0.2)),
              (d * math.sin(a), 0.01, d * math.cos(a)), (0, rng.uniform(0, 90), 0))
    m.cyl("hs_chrome", 0.035, 0.035, 0.12, (-0.4, 0.035, 0.4), (90, 30, 0), seg=6)  # can
    return m


def m_bus_stop():
    """Open side faces +Z."""
    m = B.Model("ext_bus_stop")
    m.node("shelter-col")
    for x in (-1.5, 1.5):
        for z in (-0.6, 0.45):
            tube(m, "hs_pole", [(x, 0, z), (x, 2.42, z)], 0.045, 6)
        m.box("glass", (0.02, 1.8, 1.0), (x, 1.2, -0.08))
    m.box("glass", (2.95, 1.8, 0.02), (0, 1.2, -0.6))
    for x in (-0.5, 0.5):
        tube(m, "hs_pole", [(x, 0, -0.6), (x, 2.42, -0.6)], 0.035, 6)
    with m.push((0, 0, -0.08)):
        xloft(m, "hs_pole", [(-1.72, 2.42, 2.46, 0, 0), (-1.7, 2.4, 2.5, 0.72, 0.7), (1.7, 2.4, 2.5, 0.72, 0.7),
                             (1.72, 2.42, 2.46, 0, 0)], seg=12, power=6)
    for k in range(3):
        m.box("hs_wood", (2.6, 0.04, 0.12), (0, 0.46, -0.48 + k * 0.13))
    m.node("detail")
    for x in (-1.1, 1.1):
        tube(m, "hs_pole", [(x, 0, -0.35), (x, 0.44, -0.35)], 0.025, 5)
    for y in (0.3, 2.1, 2.36):
        m.box("hs_pole", (3.0, 0.05, 0.04), (0, y, -0.59))
        for x in (-1.5, 1.5):
            m.box("hs_pole", (0.04, 0.05, 1.05), (x, y, -0.08))
    # backlit ad panel on the right end, cracked glass on the left
    m.box("hs_pole", (0.14, 1.4, 1.0), (1.58, 1.25, -0.08))
    m.box("ext_poster", (0.01, 1.2, 0.85), (1.656, 1.25, -0.08))
    m.decal("ext_poster", 0.85, 1.2, (1.656, 1.25, -0.08), (0, 90, 0))
    m.decal("hs_crack", 0.8, 0.6, (-1.515, 1.4, -0.2), (0, -90, 0))
    m.decal("hs_crack", 0.9, 0.7, (-0.9, 1.2, -0.585), (0, 0, 0))
    # bus stop sign
    tube(m, "hs_pole", [(2.0, 0, 0.3), (2.0, 2.8, 0.3)], 0.035, 6)
    m.lathe("white", [(0, -0.015), (0.28, -0.015), (0.3, 0), (0.28, 0.015), (0, 0.015)], (2.0, 2.65, 0.34), (90, 0, 0), seg=14)
    m.lathe("red", [(0, 0.016), (0.2, 0.016), (0.2, 0.018), (0, 0.018)], (2.0, 2.65, 0.34), (90, 0, 0), seg=14)
    m.box("hs_plate", (0.4, 0.28, 0.02), (2.0, 2.2, 0.33))  # timetable
    return m


def picket(m, x, h, lean=0.0, y=0.0, z=0.06, rot=None):
    poly = [(-0.05, 0), (0.05, 0), (0.05, h - 0.08), (0, h), (-0.05, h - 0.08)]
    prism(m, "hs_wood", poly, 0.025, (x, y, z), rot or (0, 0, lean))


def m_broken_fence():
    """Picket fence section along X, rotting: gaps, a leaning post, pickets fallen in the grass."""
    m = B.Model("ext_broken_fence")
    rng = random.Random(12)
    m.node("fence-col")
    for x, lean in ((-2, 0), (0, 18)):
        with m.push((x, 0, 0), (0, 0, lean)):
            m.loft("hs_wood", [(0, 0.06, 0.06), (1.15, 0.06, 0.06), (1.25, 0.0, 0.0)], seg=4, power=8)
    for y in (0.35, 0.9):
        m.box("hs_wood", (2.1, 0.09, 0.05), (-1, y, 0.04))
    for i in range(9):
        x = -1.9 + i * 0.21
        if i in (3, 6):
            continue
        picket(m, x, rng.uniform(1.0, 1.15), rng.uniform(-4, 4))
    m.node("detail")
    m.box("hs_wood", (2.1, 0.09, 0.05), (1.1, 0.35, 0.3), (0, 25, -8))  # rail hanging off the leaning post
    for i in range(4):
        picket(m, 0.3 + i * 0.35, rng.uniform(0.8, 1.1), 0, 0.02, 0.3 + rng.uniform(0, 0.6),
               (90, rng.uniform(-60, 60), 0))
    picket(m, 1.2, 1.1, -35, 0.0, 0.1)
    picket(m, -1.9 + 3 * 0.21, 0.5, 0, 0, 0.06)  # snapped stub
    for x in (-2, 0):
        m.box("iron", (0.02, 0.02, 0.06), (x + 0.02, 0.9, 0.08))
    return m


def m_hanging_trap():
    """Two posts, a crossbar and a swinging spiked log, bear trap underneath."""
    m = B.Model("ext_hanging_trap")
    m.node("posts-col")
    for x in (-1.6, 1.6):
        m.lathe("bark", [(0.16, 0), (0.14, 0.4), (0.13, 2.5), (0.12, 3.5), (0.09, 3.62), (0, 3.64)], (x, 0, 0), seg=7)
    m.node("detail")
    tube(m, "bark", [(-1.85, 3.38, 0), (0, 3.44, 0), (1.85, 3.38, 0)], 0.1, 7)
    for x in (-1.6, 1.6):  # lashings
        m.lathe("hs_seat", [(0.15, 3.25), (0.16, 3.3), (0.16, 3.5), (0.15, 3.55)], (x, 0, 0), seg=7)
    for x in (-0.5, 0.5):
        tube(m, "hs_seat", [(x, 3.42, 0), (x * 0.9, 2.7, 0.02), (x * 0.85, 2.2, 0)], 0.015, 4, cap=False)
    m.lathe("bark", [(0, -0.85), (0.2, -0.84), (0.25, -0.75), (0.26, 0), (0.25, 0.75), (0.2, 0.84), (0, 0.85)],
            (0, 2.0, 0), (0, 0, 90), seg=9)
    rng = random.Random(9)
    for i in range(12):
        x = -0.65 + (i // 2) * 0.26
        a = (i % 2) * 180 + (i // 2) * 35 + rng.uniform(-15, 15) - 90
        with m.push((x, 2.0, 0), (a, 0, 0)):
            m.lathe("rust", [(0.04, 0.2), (0.025, 0.35), (0, 0.5)], seg=5)
    # bear trap: two sprung jaws with teeth on a base plate, chain to the left post
    with m.push((0.1, 0.03, 0.9)):
        m.lathe("rust", [(0.08, 0), (0.08, 0.02), (0, 0.02)], seg=8)
        for sd in (-1, 1):
            pts = [(0.22 * math.cos(math.radians(a)), 0.02 + 0.05 * math.sin(math.radians(a)) ** 2 * 0,
                    sd * 0.22 * abs(math.sin(math.radians(a))) * 0.9) for a in range(0, 181, 30)]
            tube(m, "rust", pts, 0.012, 4, cap=False)
            for p in pts[1:-1]:
                tube(m, "rust", [p, (p[0] * 0.9, 0.08, p[2] * 0.9)], [0.012, 0.0], 3, cap=False)
    tube(m, "iron", [(0.1, 0.03, 0.9), (-0.7, 0.02, 0.6), (-1.5, 0.1, 0.1)], 0.01, 3, cap=False)
    return m


def drum(m, mat, pos, rot=(0, 0, 0), seg=8):
    """55-gallon drum: chimes + two rolling hoops, bung on the lid."""
    prof = [(0, 0.0), (0.28, 0.0), (0.3, 0.02), (0.29, 0.04), (0.29, 0.28), (0.305, 0.3), (0.29, 0.32),
            (0.29, 0.58), (0.305, 0.6), (0.29, 0.62), (0.29, 0.86), (0.3, 0.88), (0.28, 0.9), (0.26, 0.88), (0, 0.88)]
    with m.push(pos, rot):
        m.lathe(mat, prof, seg=seg)
        m.cyl("hs_dark", 0.03, 0.03, 0.02, (0.15, 0.88, 0.05), seg=5)


def m_fuel_barrels():
    m = B.Model("ext_fuel_barrels")
    m.node("barrels-col")
    for x, z in ((0, 0), (0.65, 0.1), (0.3, 0.6), (-0.4, 0.55)):
        drum(m, "ext_fuel", (x, 0, z))
    drum(m, "ext_fuel", (-0.9, 0.3, -0.5), (0, 20, 90))
    m.node("detail")
    m.ellipsoid("hs_dark", (0.6, 0.01, 0.45), (-1.3, 0.005, -0.3), seg=10, rings=3)  # leaked puddle
    m.box("white", (0.2, 0.2, 0.005), (0.65, 0.55, 0.395), (0, 0, 45))  # hazard diamond
    return m


def m_generator():
    """Diesel generator on a skid: rounded housing, louvers facing +Z, exhaust stack, control box."""
    m = B.Model("ext_generator")
    m.node("box-col")
    m.box("concrete", (2.0, 0.2, 1.6), (0, 0.1, 0))
    xloft(m, "ext_green", [(-0.81, 0.3, 1.7, 0, 0), (-0.8, 0.22, 1.78, 0.6, 0.58), (0.8, 0.22, 1.78, 0.6, 0.58),
                           (0.81, 0.3, 1.7, 0, 0)], seg=16, power=8)
    m.node("detail")
    for sd in (-1, 1):
        m.box("iron", (1.9, 0.1, 0.08), (0, 0.25, sd * 0.62))  # skid rails
    for i in range(8):
        m.box("hs_dark", (0.9, 0.035, 0.03), (-0.2, 0.55 + i * 0.13, 0.61), (-25, 0, 0))  # louvers
    m.box("iron", (0.95, 1.1, 0.01), (-0.2, 1.0, 0.598))
    # control box + gauges + one red indicator still on
    m.box("hs_pole", (0.45, 0.5, 0.12), (0.5, 1.2, 0.66))
    for k, x in enumerate((0.38, 0.52)):
        lens(m, "white", (0.1, 0.1), (x, 1.3, 0.72), "+z")
    m.box("bulb_red", (0.06, 0.06, 0.04), (0.6, 1.1, 0.73))
    m.box("hs_dark", (0.04, 0.1, 0.05), (0.42, 1.08, 0.73))
    # exhaust: stack, muffler, rain cap
    m.lathe("rust", [(0.12, 0), (0.14, 0.05), (0.14, 0.45), (0.12, 0.5), (0.05, 0.52)], (0.45, 1.78, -0.3), seg=8)
    tube(m, "rust", [(0.45, 2.2, -0.3), (0.45, 2.55, -0.3), (0.5, 2.62, -0.3)], 0.05, 6)
    m.box("rust", (0.16, 0.02, 0.14), (0.52, 2.66, -0.3), (0, 0, -20))
    # insulator posts + cable snaking off
    for x in (-0.45, -0.2):
        m.lathe("ext_ceramic", [(0.05, 0), (0.08, 0.04), (0.08, 0.08), (0.05, 0.12), (0.07, 0.16), (0.07, 0.2), (0, 0.24)],
                (x, 1.78, 0.25), seg=8)
    tube(m, "hs_dark", bezier((-0.8, 0.9, 0.4), (-1.5, 0.4, 0.9), (-2.2, 0.05, 1.2), 8), 0.03, 4)
    m.box("hs_amber", (0.3, 0.2, 0.01), (-0.6, 1.5, 0.61))  # warning sticker
    return m


def m_warning_sign():
    """Board faces +Z at y=1.6 (front at z~0.03); text comes from a Label3D."""
    m = B.Model("ext_warning_sign")
    m.node("post-col")
    for x in (-0.5, 0.5):
        post(m, "hs_wood", x, -0.06, 2.05, 0.045, power=6, seg=6)
    m.node("detail")
    m.loft("white", [(-0.015, 0, 0), (-0.015, 0.7, 0.4), (0.015, 0.7, 0.4), (0.015, 0, 0)], (0, 1.6, 0), (90, 0, 0),
           seg=16, power=8)
    for y in (1.26, 1.94):
        m.box("red", (1.36, 0.08, 0.01), (0, y, 0.018))
    for x in (-0.5, 0.5):
        for y in (1.3, 1.9):
            m.cyl("rust", 0.018, 0.018, 0.02, (x, y, 0.012), (90, 0, 0), seg=6)  # bolts
    rng = random.Random(2)
    for _ in range(5):
        m.cyl("hs_dark", 0.02, 0.02, 0.004, (rng.uniform(-0.6, 0.6), rng.uniform(1.3, 1.9), 0.016), (90, 0, 0), seg=6)
    return m


def m_town_sign():
    """The welcome board on the bridge road: faces +Z, board centred at y=2.2 with its front at z=0 (the text,
    "HOLLOWMERE  POP. 1413", is a Label3D just in front of it: build_assets.build_world)."""
    m = B.Model("ext_town_sign")
    m.node("post-col")
    for x in (-2.55, 2.55):
        post(m, "hs_wood", x, -0.1, 2.75, 0.06, power=6, seg=6)
    m.box("planks", (5.6, 0.75, 0.08), (0, 2.2, -0.04))
    m.node("detail")
    for y in (1.8, 2.6):
        m.box("hs_wood", (5.7, 0.07, 0.05), (0, y, 0.005))  # top and bottom rails
    for x in (-2.55, 2.55):
        for y in (1.95, 2.45):
            m.cyl("rust", 0.02, 0.02, 0.02, (x, y, 0.01), (90, 0, 0), seg=6)  # bolts
    return m


def m_well():
    """Dry-stone ring, shingled gable, crank + rope + bucket."""
    m = B.Model("ext_well")
    rng = random.Random(10)
    m.node("ring-col")
    for course in range(3):
        n = 11
        for i in range(n):
            a = (i + 0.5 * (course % 2)) * 360 / n
            w = 2 * math.pi * 0.8 / n * 0.95
            m.box("stone", (w, 0.26, 0.24), (0.8 * math.cos(math.radians(a)), 0.13 + course * 0.27,
                                               0.8 * math.sin(math.radians(a))),
                  (rng.uniform(-3, 3), -a + 90, rng.uniform(-3, 3)))
    m.lathe("hs_dark", [(0.68, 0.78), (0.68, 0.2), (0, 0.2)], seg=12)  # dark inner throat
    m.node("detail")
    m.lathe("stone", [(0.7, 0.8), (0.95, 0.8), (0.95, 0.86), (0.7, 0.86)], seg=12)  # cap ring
    m.lathe("water", [(0, 0.25), (0.68, 0.25)], seg=12)
    for x in (-0.85, 0.85):
        post(m, "hs_wood", x, 0, 2.05, 0.06, power=6, seg=6)
    with m.push((0, 2.0, 0), (0, 90, 0)):
        m.gable("roof", 2.1, 1.3, 0.75, end="hs_wood")
    tube(m, "bark", [(-0.95, 1.55, 0), (0.95, 1.55, 0)], 0.07, 7)
    tube(m, "iron", [(0.95, 1.55, 0), (1.05, 1.55, 0), (1.05, 1.35, 0.05), (1.15, 1.35, 0.05)], 0.018, 4)  # crank
    m.lathe("hs_seat", [(0.09, -0.12), (0.09, 0.12)], (0, 1.55, 0), (0, 0, 90), seg=8)  # rope wound
    tube(m, "hs_seat", [(0.05, 1.47, 0), (0.05, 1.05, 0)], 0.012, 3, cap=False)
    m.lathe("hs_wood", [(0, 0.0), (0.12, 0.0), (0.15, 0.25), (0.14, 0.26), (0.11, 0.02), (0, 0.02)], (0.05, 0.8, 0), seg=8)
    tube(m, "iron", [(-0.1, 1.05, 0), (0.05, 1.12, 0), (0.2, 1.05, 0)], 0.008, 3, cap=False)
    return m


def m_rowboat():
    """Clinker rowboat, bow toward +Z: smooth hull skin inside and out, thwarts, oar."""
    m = B.Model("ext_rowboat")
    stations = [(-1.6, 0.58, 0.42, 0.52), (-1.2, 0.68, 0.48, 0.5), (-0.4, 0.74, 0.52, 0.5), (0.4, 0.7, 0.52, 0.52),
                (1.0, 0.52, 0.5, 0.56), (1.4, 0.3, 0.46, 0.6), (1.7, 0.02, 0.4, 0.66)]  # z, half-width, depth, gunwale y
    n = 10

    def section(w, d, gy, k):
        return [(w * k * math.sin(t), gy - d * k * math.cos(t) ** 0.7, 0) for t in
                (-math.pi / 2 + math.pi * i / n for i in range(n + 1))]

    def hull(k, flip):
        rows = []
        for z, w, d, gy in stations:
            rows.append([(x, y, z) for x, y, _ in section(w, d, gy, k)])
        grid = [list(col) for col in zip(*rows)]
        if flip:
            grid = grid[::-1]
        m.surface("planks", grid)

    m.node("hull-col")
    hull(1.0, False)
    m.node("detail")
    hull(0.94, True)
    for sd in (-1, 1):  # gunwale rails
        tube(m, "hs_wood", [(sd * w, gy + 0.01, z) for z, w, d, gy in stations], 0.03, 4)
    z, w, d, gy = stations[0]
    tr = section(w, d, gy, 1.0)
    m.emit("hs_wood", [(x, y, z) for x, y, _ in tr], (0, 0.3, z + 0.3))
    m.emit("hs_wood", [(x * 0.94, y + 0.02, z + 0.02) for x, y, _ in tr], (0, 0.3, z - 0.3))
    tube(m, "hs_wood", [(0, 0.03, -1.62), (0, -0.02, 0.4), (0, 0.18, 1.3), (0, 0.66, 1.72)], 0.03, 4)  # keel/stem
    for z, w in ((-0.9, 0.62), (0.2, 0.66)):
        m.box("hs_wood", (w * 2 - 0.1, 0.04, 0.25), (0, 0.42, z))  # thwarts
    for sd in (-1, 1):
        tube(m, "iron", [(sd * 0.72, 0.72, -0.35), (sd * 0.72, 0.8, -0.35)], 0.012, 3)  # oarlocks
    with m.push((-0.3, 0.45, -0.8), (0, 20, 0)):
        tube(m, "hs_wood", [(0, 0, -1.2), (0, 0, 1.0)], 0.025, 5)
        m.loft("hs_wood", [(0, 0, 0), (0, 0.06, 0.012), (0.5, 0.08, 0.01), (0.52, 0, 0)], (0, 0, 1.0), (90, 0, 0), seg=8, power=4)
    m.ellipsoid("water", (0.4, 0.01, 0.8), (0, 0.1, -0.2), seg=10, rings=3)  # rainwater in the bilge
    return m


def m_watchtower():
    """Hunter's tower: log legs with X-bracing, plank deck + half-walls, tin roof, ladder on +Z."""
    m = B.Model("ext_watchtower")
    m.node("frame-col")
    for x in (-1.3, 1.3):
        for z in (-1.3, 1.3):
            m.lathe("bark", [(0.13, 0), (0.12, 3), (0.1, 6.0), (0, 6.02)], (x, 0, z), seg=7)
    m.box("hs_wood", (3.0, 0.15, 3.0), (0, 4.5, 0))
    m.node("detail")
    for sd in (-1, 1):
        for y0, y1 in ((0.3, 2.2), (2.3, 4.2)):
            tube(m, "bark", [(-1.3, y0, sd * 1.3), (1.3, y1, sd * 1.3)], 0.06, 5)
            tube(m, "bark", [(sd * 1.3, y0, -1.3), (sd * 1.3, y1, 1.3)], 0.06, 5)
        m.box("hs_wood", (2.9, 0.12, 0.12), (0, 4.38, sd * 1.3))
        # half-walls of separate boards, some missing
        for k in range(4):
            if (k, sd) in ((1, 1), (2, -1)):
                continue
            y = 4.65 + k * 0.2
            m.box("hs_wood", (2.9, 0.18, 0.04), (0, y, sd * 1.45), (0, 0, (k - 1.5) * 0.6))
            m.box("hs_wood", (0.04, 0.18, 2.9), (sd * 1.45, y, 0), (0.5 * k, 0, 0))
    for x in range(-6, 7):
        m.box("hs_wood", (0.2, 0.03, 3.0), (x * 0.22, 4.59, 0))  # deck planks
    with m.push((0, 6.0, 0)):
        m.gable("rust", 3.6, 3.6, 1.1)
        m.gable("hs_dark", 3.4, 3.5, 1.0, (0, -0.02, 0))
    for x in (-0.3, 0.3):
        tube(m, "bark", [(x, 0, 2.3), (x, 4.9, 1.35)], 0.04, 5)
    for i in range(9):
        t = (i + 1) / 10
        tube(m, "bark", [(-0.3, 4.9 * t, 2.3 - 0.95 * t), (0.3, 4.9 * t, 2.3 - 0.95 * t)], 0.025, 4, cap=False)
    return m


def m_burnt_car():
    """Torched station wagon: charred shell on bare rims, windows blown out (soot inside)."""
    m = B.Model("ext_burnt_car")
    m.node("body-col")
    m.box("hs_dark", (4.1, 0.4, 1.2), (0, 0.45, 0))
    m.box("hs_dark", (2.4, 0.35, 1.2), (-0.8, 0.95, 0))
    m.node("detail")
    rng = random.Random(21)
    H.sedan(m, "ext_char", H.WAGON, rng, burnt=True)
    H.dents(m, rng, "ext_char", H.WAGON["hw"], 5, yr=(0.3, 0.7))
    return m


MODELS = [m_tall_grass, m_bush, m_boulder, m_phone_booth, m_mailbox, m_dumpster, m_trash_can, m_bus_stop,
          m_broken_fence, m_hanging_trap, m_fuel_barrels, m_generator, m_warning_sign, m_well, m_rowboat,
          m_watchtower, m_burnt_car, m_town_sign]


def place(W, rng):
    def put(model, x, z, yaw=0, gap=0.0, s=1.0, y=None):
        W.inst(model, x, z, yaw, s, y, block=gap)

    def sign(text, x, z, yaw):
        put("ext_warning_sign", x, z, yaw, 0.5)  # lettered between its red stripes, inside the oval
        W.board_label(text, (x, z, yaw), (0, 1.6, 0.015), (1.2, 0.5), (0.6, 0.08, 0.06), 36, localize=True)

    # hiding grass: forest, cemetery, lake shore
    W.scatter(rng, ["ext_tall_grass"], 260, -163, -68, -76, 44, 1.0, (0.8, 1.3))
    W.scatter(rng, ["ext_tall_grass"], 40, -112, -142, -47, -60, 0.8, (0.8, 1.2))
    cx, cz, rx, rz = B.LAKE
    for _ in range(70):
        a = rng.uniform(0, math.tau)
        k = rng.uniform(1.02, 1.3)
        x, z = cx + rx * k * math.cos(a), cz + rz * k * math.sin(a)
        if x < -8 and not W.blocked(x, z, 0.5):
            put("ext_tall_grass", x, z, rng.uniform(0, 360), 0.8, rng.uniform(0.8, 1.3))

    # town: plaza edges and hub roads
    put("ext_phone_booth", -4, -27, 0, 0.8)
    put("ext_phone_booth", 5, 48, -90, 0.8)
    for x, z, yaw in ((-5, 40, 90), (5, 56, -90), (5, 76, -90), (-5, 80, 90), (-5, -45, 90), (5, -48, -90),
                      (-42, -5, 180), (58, -5, 180), (42, 5, 0)):
        put("ext_mailbox", x, z, yaw, 0.3)
    put("ext_dumpster", 23, -24, 90, 1.5)
    put("ext_dumpster", -23, -26, -90, 1.5)
    put("ext_dumpster", -92, 83, 0, 1.5)
    for x, z in ((24, -18), (-24, -18), (12, 28), (-12, 28), (6, -60), (-35, 4)):
        put("ext_trash_can", x, z, rng.uniform(0, 360), 0.4)
    put("ext_bus_stop", 35, 5, 180, 2)
    put("ext_bus_stop", 5.5, 30, -90, 2)

    # forest & sawmill
    for x, z, yaw in ((-118, -28, 20), (-142, -25, 70), (-112, 16, -30), (-146, 10, 5), (-95, 20, 50)):
        if not W.blocked(x, z, 2):
            put("ext_hanging_trap", x, z, yaw, 2)
    for x, z in ((-122, -11), (-123, 7), (-138, 9)):
        put("ext_fuel_barrels", x, z, rng.uniform(0, 360), 1.2)
    put("ext_watchtower", -150, -50, 30, 2.5)
    put("ext_watchtower", -90, 32, -20, 2.5)
    put("ext_well", -106, -40, 0, 1.2)
    for x, z, yaw in ((-80, -40, 80), (-88, 38, 10), (-155, -10, 95), (-78, 14, 100), (-108, 40, 0)):
        put("ext_broken_fence", x, z, yaw, 2)

    # generators behind the clinic and the school
    put("ext_generator", 82, -108, 90, 1.5)
    put("ext_generator", 118, 12, 90, 1.5)

    # rowboats pulled up on the lake shore, bow toward the water
    for deg in (150, 200, 245, 290):
        a = math.radians(deg)
        x, z = cx + rx * 1.02 * math.cos(a), cz + rz * 1.02 * math.sin(a)
        put("ext_rowboat", x, z, math.degrees(math.atan2(cx - x, cz - z)), 1.5, y=max(B.height(x, z), -0.25) - 0.05)

    # warnings
    sign("DANGER", -96.5, 143, 180)
    sign("KEEP OUT", 6, -140, 0)
    sign("PRIVATE LAND", -77, -6, 90)

    # burnt cars
    for x, z, yaw in ((-6, -80, 10), (25, -104, 80), (-88, 6, 30)):
        put("ext_burnt_car", x, z, yaw, 2.5)

    # wilderness dressing
    W.scatter(rng, ["ext_bush", "ext_bush", "ext_boulder"], 110, B.X0, B.Z0, B.X1, B.Z1, 1.5, (0.7, 1.4))
