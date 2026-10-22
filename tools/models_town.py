"""Town density pack: extra houses, shops, apartments, gas station, street furniture, street lamps,
power lines and the sickly green accents. Auto-loaded by build_assets; place() fills the streets."""
import math
import random

import build_assets as B


# ------------------------------------------------------------------ textures & materials

def t_poster(x, y, a, b, r):
    torn = x + (63 - y) * 0.6 > 88 + 10 * b or (y < 3 and x > 40 + 20 * a)
    c = B.mul((0.78, 0.75, 0.64), 0.75 + 0.25 * a)
    if 5 < y < 12 and 6 < x < 58 and (x // 3) % 4:
        c = (0.12, 0.1, 0.09)                              # "MISSING"
    elif 15 < y < 40 and 16 < x < 48:
        face = ((x - 32) / 8) ** 2 + ((y - 27) / 10) ** 2 < 1
        c = B.mul((0.35, 0.33, 0.3) if face else (0.14, 0.14, 0.14), 0.7 + 0.5 * a)
    elif 44 < y < 60 and 6 < x < 58 and y % 4 < 2 and (x * 7 + y) % 11 > 2:
        c = (0.2, 0.18, 0.16)
    if b > 0.62:
        c = B.mul(c, 0.65)                                  # water stains
    return (*c, 0.0 if torn else 1.0)


def t_graffiti(x, y, a, b, r):
    s1 = abs(y - (30 + 12 * math.sin(x * 0.19) + 4 * math.sin(x * 0.5))) < 2.6
    s2 = abs(y - (38 - 10 * math.cos(x * 0.13 + 1))) < 2.0 and 8 < x < 56
    s3 = abs(x - (20 + 6 * math.sin(y * 0.3))) < 1.8 and 14 < y < 50
    drip = x % 6 == 2 and 30 < y < 44 + 14 * b
    on = (s1 or s2 or s3 or drip) and r > 0.1
    v = 0.75 + 0.25 * a
    return (v, v, v, 1.0 if on else 0.0)


def t_rollup(x, y, a, b, r):
    v = (0.42 + 0.18 * a) * (0.6 if y % 6 == 0 else 1.0)
    return B.mix((v, v, v * 1.02), (0.35, 0.2, 0.1), 0.6 if b > 0.66 else 0.0)


B.TEXTURES.update({"town_poster": t_poster, "town_graffiti": t_graffiti, "town_rollup": t_rollup})
B.ALPHA_TEX.update({"town_poster", "town_graffiti"})
B.MATS.update({
    "town_trim": B.M("paint", (0.9, 0.88, 0.82), 3), "town_trim_dk": B.M("paint", (0.35, 0.3, 0.26), 3),
    "town_siding_y": B.M("siding", (1.0, 0.88, 0.6)), "town_siding_g": B.M("siding", (0.72, 0.72, 0.72)),
    "town_siding_r": B.M("siding", (0.85, 0.55, 0.5)), "town_stucco": B.M("paint", (0.62, 0.7, 0.62), 3),
    "town_stucco_b": B.M("paint", (0.8, 0.72, 0.6), 3),
    "town_shingle": B.M("roof", (0.62, 0.64, 0.68)), "town_shingle_r": B.M("roof", (0.75, 0.55, 0.5)),
    "town_gutter": B.M("metal", (0.75, 0.75, 0.72)), "town_foundation": B.M("concrete", (0.7, 0.7, 0.68), 2),
    "town_hedge": B.M("pine", (0.7, 0.9, 0.55), 1.5), "town_moss": B.M("grass", (0.6, 0.9, 0.5), 1.5),
    "town_neon": B.M("plain", (0.3, 0.95, 0.4), 1, emit=1.6), "town_fungus": B.M("plain", (0.3, 0.9, 0.35), 1, emit=1.2),
    "town_fungus_stem": B.M("plain", (0.5, 0.52, 0.42), 1),
    "town_win_fluor": B.M("window_lit", (0.5, 1.0, 0.85), fit=True, emit=1.1),
    "town_canopy_light": B.M("plain", (0.85, 0.95, 1.0), 1, emit=1.6),
    "town_poster": B.M("town_poster", fit=True), "town_graffiti": B.M("town_graffiti", (0.35, 0.8, 0.35), fit=True),
    "town_graffiti_r": B.M("town_graffiti", (0.6, 0.12, 0.1), fit=True),
    "town_rollup": B.M("town_rollup", fit=True), "town_bag": B.M("plain", (0.07, 0.07, 0.08), 1, rough=0.35),
    "town_hydrant": B.M("paint", (0.75, 0.2, 0.12), 1), "town_sign": B.M("plain", (0.12, 0.3, 0.16), 1),
    "town_stop": B.M("plain", (0.5, 0.06, 0.05), 1), "town_wire": B.M("plain", (0.03, 0.03, 0.03), 1),
    "town_pump": B.M("paint", (0.55, 0.14, 0.1), 2), "town_lamp_dead": B.M("plain", (0.25, 0.24, 0.2), 1),
})

GREEN = (0.45, 1.0, 0.5)


# ------------------------------------------------------------------ shared building parts

def window(m, x, y, z, w, h, mat="window", trim="town_trim", rot=0, shutters=None, boarded=False):
    """Framed window on a wall plane facing local +Z (rot turns it around Y: 90 = faces +X)."""
    with m.push((x, y, z), (0, rot, 0)):
        m.box(mat, (w, h, 0.06), (0, 0, 0.0))
        m.box(trim, (w + 0.26, 0.12, 0.1), (0, h / 2 + 0.06, 0.03))
        m.box(trim, (w + 0.34, 0.07, 0.2), (0, -h / 2 - 0.035, 0.06))
        for s in (-1, 1):
            m.box(trim, (0.1, h, 0.08), (s * (w / 2 + 0.05), 0, 0.03))
            if shutters:
                m.box(shutters, (w * 0.42, h + 0.05, 0.05), (s * (w * 0.71 + 0.12), 0, 0.04))
        m.box(trim, (0.05, h, 0.05), (0, 0, 0.04))
        if boarded:
            for k, a in ((0, 22), (1, -18)):
                m.box("planks", (w * 1.15, 0.18, 0.04), (0, (k - 0.5) * h * 0.3, 0.1), (0, 0, a))


def door(m, x, z, w=1.0, h=2.1, y=0.0, trim="town_trim", rot=0):
    with m.push((x, y, z), (0, rot, 0)):
        m.box("door", (w, h, 0.08), (0, h / 2, 0))
        m.box(trim, (w + 0.3, 0.14, 0.12), (0, h + 0.07, 0.03))
        for s in (-1, 1):
            m.box(trim, (0.12, h, 0.1), (s * (w / 2 + 0.06), h / 2, 0.03))
        m.cyl("metal", 0.03, 0.03, 0.06, (w * 0.35, h * 0.47, 0.04), (90, 0, 0), seg=5)


def gable_roof(m, mat, w, d, rise, y, zc=0.0, over=0.45, t=0.14, end=None):
    """Roof slabs with thickness, ridge along Z; end = material for the gable triangles (None: skip)."""
    a = math.atan2(rise, w / 2)
    L = (w / 2 + over) / math.cos(a)
    ridge = (0.0, y + rise)
    for s in (-1, 1):
        dx, dy = s * math.cos(a), -math.sin(a)
        nx, ny = s * math.sin(a), math.cos(a)
        cx = ridge[0] + dx * L / 2 + nx * t / 2
        cy = ridge[1] + dy * L / 2 + ny * t / 2
        m.box(mat, (L, t, d + 2 * over), (cx, cy, zc), (0, 0, -s * math.degrees(a)))
        ex, ey = s * (w / 2 + over), y - over * math.tan(a)
        m.cyl("town_gutter", 0.07, 0.07, d + 2 * over, (ex + s * 0.05, ey - 0.05, zc - d / 2 - over), (90, 0, 0), seg=6)
    m.box(mat, (0.3, 0.12, d + 2 * over + 0.02), (0, y + rise + t + 0.02, zc))
    if end:
        for z in (zc - d / 2, zc + d / 2):
            m.emit(end, [(-w / 2, y, z), (w / 2, y, z), (0, y + rise, z)], (0, y + rise / 3, zc))


def hip_roof(m, mat, w, d, rise, y, over=0.5, fascia="town_trim"):
    W2, D2 = w / 2 + over, d / 2 + over
    r = max(W2 - D2, 0.1)
    A, Bp, C, D = (-W2, y, -D2), (W2, y, -D2), (W2, y, D2), (-W2, y, D2)
    R1, R2 = (-r, y + rise, 0), (r, y + rise, 0)
    c = (0, y + rise * 0.3, 0)
    for f in ([D, C, R2, R1], [Bp, A, R1, R2], [C, Bp, R2], [A, D, R1], [A, Bp, C, D]):
        m.emit(mat, f, c)
    for sz in (-1, 1):
        m.box(fascia, (2 * W2 + 0.04, 0.2, 0.06), (0, y - 0.05, sz * D2))
        m.box(fascia, (0.06, 0.2, 2 * D2), (sz * W2, y - 0.05, 0))
        m.cyl("town_gutter", 0.07, 0.07, 2 * W2, (-W2, y - 0.1, sz * (D2 + 0.06)), (0, 0, -90), seg=6)


def post(m, x, z, h=2.5, y=0.0, mat="town_trim"):
    m.lathe(mat, [(0.1, 0), (0.1, 0.25), (0.065, 0.35), (0.06, h - 0.35), (0.085, h - 0.2), (0.085, h)],
            (x, y, z), seg=8)


def ac_unit(m, x, z, rot=0):
    with m.push((x, 0, z), (0, rot, 0)):
        m.box("town_foundation", (1.0, 0.1, 0.8), (0, 0.05, 0))
        m.loft("metal", [(0.1, 0.42, 0.34), (0.8, 0.42, 0.34), (0.82, 0.38, 0.3), (0.82, 0, 0)], seg=12, power=5)
        m.cyl("rubber", 0.26, 0.26, 0.02, (0, 0.82, 0), seg=10)


def downspout(m, x, z, h):
    m.cyl("town_gutter", 0.05, 0.05, h, (x, 0.15, z), seg=5, caps=False)
    m.cyl("town_gutter", 0.05, 0.05, 0.35, (x, 0.2, z), (70, 0, 0), seg=5, caps=False)


def antenna(m, x, y, z):
    m.cyl("metal", 0.025, 0.02, 2.0, (x, y, z), seg=4)
    for k in range(4):
        m.box("metal", (1.1 - k * 0.2, 0.03, 0.03), (x, y + 1.3 + k * 0.2, z), (0, 20, 0))


# ------------------------------------------------------------------ houses

def m_house_tall(name="town_house_d", siding="town_siding_y", roof="town_shingle", lit=True, seed=11, boarded=False):
    """Two-storey front-gable house with porch. Footprint ~8.4 x 10.6 (fits a 5.5 half-extent slot)."""
    m = B.Model(name)
    rng = random.Random(seed)
    w, d, h, zc = 7.6, 8.2, 5.6, -0.9
    zf = zc + d / 2
    m.node("shell-col")
    m.box(siding, (w, h, d), (0, h / 2 + 0.3, zc))
    m.box("town_foundation", (w + 0.2, 0.4, d + 0.2), (0, 0.2, zc))
    m.box("planks", (w, 0.3, 2.0), (0, 0.15, zf + 1.0))
    m.box("planks", (1.4, 0.15, 0.4), (-1.6, 0.075, zf + 2.2))
    m.node("detail")
    gable_roof(m, roof, w, d, 2.8, h + 0.3, zc, end=siding)
    m.box("town_trim", (w + 0.1, 0.2, d + 0.1), (0, 3.2, zc))            # floor band
    for x in (-w / 2, w / 2):
        for z in (zc - d / 2, zf):
            m.box("town_trim", (0.18, h, 0.18), (x, h / 2 + 0.3, z))    # corner boards
    # porch: shed roof, turned posts, railings
    m.box(roof, (w + 0.4, 0.12, 2.4), (0, 3.0, zf + 1.1), (-12, 0, 0))
    m.box("town_trim", (w + 0.3, 0.22, 0.1), (0, 2.72, zf + 2.2))
    for x in (-w / 2 + 0.2, -0.8, 2.4 - 0.1, w / 2 - 0.2):
        post(m, x, zf + 1.95, 2.45, 0.3)
    for x0, x1 in ((-w / 2 + 0.2, -0.8), (-0.8 + 1.6, w / 2 - 0.2)):
        if x0 < -1 or x1 > 0:
            L = abs(x1 - x0)
            m.box("town_trim", (L, 0.08, 0.1), ((x0 + x1) / 2, 1.2, zf + 1.95))
            for k in range(int(L / 0.28)):
                m.box("town_trim", (0.05, 0.85, 0.05), (x0 + 0.14 + k * 0.28, 0.75, zf + 1.95))
    door(m, -1.6, zf + 0.02, y=0.3)
    wl = "window_lit" if lit else "window"
    window(m, 1.7, 1.75, zf + 0.03, 1.7, 1.3, wl if rng.random() < 0.5 else "window", shutters="town_trim_dk", boarded=boarded)
    for x in (-1.7, 1.7):
        window(m, x, 4.5, zf + 0.03, 1.0, 1.3, "window", shutters="town_trim_dk", boarded=boarded and x > 0)
    window(m, 0, h + 1.3, zf + 0.03, 0.6, 0.8, "window")                 # attic
    for s in (-1, 1):
        for z in (zc - 2.0, zc + 1.8):
            for y in (1.8, 4.5):
                window(m, s * (w / 2 + 0.01), y, z, 0.9, 1.2, wl if (lit and y < 3 and z > 0 and s > 0) else "window",
                       rot=90 * s, boarded=boarded and y < 3)
    window(m, 1.3, 1.8, zc - d / 2 - 0.01, 0.9, 1.1, "window", rot=180)
    door(m, -1.8, zc - d / 2 - 0.02, y=0.3, rot=180)
    # chimney, gutters, AC, porch light
    m.box("brick", (0.9, h + 3.6, 0.9), (-w / 2 - 0.35, (h + 3.6) / 2, zc - 1.2))
    m.box("town_foundation", (1.05, 0.15, 1.05), (-w / 2 - 0.35, h + 3.6, zc - 1.2))
    downspout(m, w / 2 + 0.55, zc - d / 2 - 0.3, h)
    downspout(m, -w / 2 - 0.55, zf + 0.3, h)
    ac_unit(m, w / 2 + 0.7, zc - 1.0, 90)
    m.box("bulb" if lit else "town_lamp_dead", (0.16, 0.22, 0.12), (-0.7, 2.4, zf + 0.08))
    if boarded:
        m.decal("town_graffiti_r", 2.2, 1.4, (0.9, 1.3, zc - d / 2 - 0.06), (0, 180, 0))
    return m


def m_duplex(name="town_duplex", wall="town_stucco_b", roof="town_shingle_r", seed=21):
    """Single-storey duplex/ranch with hip roof, two entries and an attached carport. Footprint 13 x 9.6."""
    m = B.Model(name)
    rng = random.Random(seed)
    w, d, h = 10.0, 7.2, 3.0
    m.node("shell-col")
    m.box(wall, (w, h, d), (-1.2, h / 2 + 0.25, -0.8))
    m.box("town_foundation", (w + 0.2, 0.3, d + 0.2), (-1.2, 0.15, -0.8))
    for x in (-4.4, 2.0):
        m.box("town_foundation", (1.6, 0.25, 1.0), (x, 0.125, 3.3))
    for z in (-4.0, 2.4):
        m.cyl("metal", 0.07, 0.07, 2.6, (5.9, 0, z), seg=6)
    m.node("detail")
    with m.push((-1.2, 0, -0.8)):
        hip_roof(m, roof, w, d, 1.9, h + 0.25)
    m.box("metal", (2.7, 0.12, 7.4), (5.15, 2.65, -0.8), (0, 0, -4))       # carport roof
    m.box("town_trim", (0.1, 0.2, 7.4), (6.45, 2.55, -0.8))
    m.box("town_foundation", (2.6, 0.04, 7.0), (5.15, 0.02, -0.8))
    for x, lit in ((-4.4, True), (2.0, False)):
        door(m, x, 2.82, y=0.25)
        m.gable("town_trim", 1.8, 1.2, 0.6, (x, 2.75, 3.3), (0, 90, 0))
        m.box("bulb" if lit else "town_lamp_dead", (0.14, 0.2, 0.1), (x + 0.75, 2.2, 2.86))
    for x in (-2.4, 0.0):
        window(m, x, 1.75, 2.83, 1.4, 1.1, "window_lit" if rng.random() < 0.4 else "window", shutters="town_trim_dk")
        m.box("planks", (1.5, 0.3, 0.35), (x, 0.95, 3.0))
        m.ellipsoid("town_hedge", (0.7, 0.25, 0.16), (x, 1.12, 3.0), seg=8, rings=4)
    window(m, -5.6 + 0.3, 1.75, 2.83, 0.8, 1.1, "window")
    for z in (-3.0, 0.8):
        window(m, -6.21, 1.75, z, 1.1, 1.1, "window", rot=-90)
        window(m, 3.81, 1.75, z, 1.1, 1.1, "window", rot=90)
    for x in (-4.0, 1.5):
        window(m, x, 1.75, -4.41, 1.3, 1.1, "window", rot=180)
    antenna(m, -3.0, h + 1.8, -0.8)
    m.lathe("white", [(0, 0), (0.35, 0.05), (0.42, 0.18), (0.0, 0.16)], (1.8, h + 0.9, 1.6), (70, 20, 0), seg=10)  # dish
    downspout(m, -6.4, 2.95, h)
    ac_unit(m, -1.2, -5.2, 180)
    m.box("rubber", (0.05, 0.05, 6.0), (5.9, 2.4, -0.8))
    m.loft("rubber", [(0, 0.35, 0.35), (0.25, 0.35, 0.35)], (4.6, 0.02, -3.8), (90, 0, 0), seg=10)  # dumped tire
    return m


def m_garage():
    """Detached front-gable garage, roll-up door on +Z. Footprint 4.6 x 6.6."""
    m = B.Model("town_garage")
    w, d, h = 4.2, 6.0, 2.7
    m.node("shell-col")
    m.box("planks", (w, h, d), (0, h / 2, 0))
    m.node("detail")
    gable_roof(m, "town_shingle", w, d, 1.3, h, over=0.25, end="planks")
    m.box("town_rollup", (3.0, 2.3, 0.06), (0, 1.15, d / 2 + 0.02))
    m.box("town_trim", (3.3, 0.14, 0.1), (0, 2.37, d / 2 + 0.04))
    for s in (-1, 1):
        m.box("town_trim", (0.12, 2.3, 0.1), (s * 1.56, 1.15, d / 2 + 0.04))
    window(m, w / 2 + 0.01, 1.6, 0.5, 0.8, 0.7, "window", rot=90)
    m.box("metal", (0.4, 0.3, 0.2), (1.2, 2.7 + 0.35, d / 2 + 0.2))   # floodlight (dead)
    m.decal("town_graffiti", 2.4, 1.2, (0, 1.2, -d / 2 - 0.02), (0, 180, 0))
    return m


# ------------------------------------------------------------------ commercial

def m_shop(name="town_laundromat", wall="town_stucco", glass="town_win_fluor", neon=True):
    """Flat-roofed corner shop, storefront on +Z with awning and a sign board. Footprint 10.4 x 9.6."""
    m = B.Model(name)
    w, d, h = 10.0, 8.0, 4.2
    m.node("shell-col")
    m.box(wall, (w, h, d), (0, h / 2, -0.8))
    m.box("town_foundation", (w + 0.2, 0.2, d + 0.2), (0, 0.1, -0.8))
    m.node("detail")
    zf = 3.2
    m.box(wall, (w + 0.3, 1.3, 0.3), (0, h + 0.65, zf - 0.05))          # parapet / sign band
    m.box(wall, (0.3, 0.7, d), (w / 2, h + 0.35, -0.8))
    m.box(wall, (0.3, 0.7, d), (-w / 2, h + 0.35, -0.8))
    m.box(wall, (w, 0.7, 0.3), (0, h + 0.35, -4.7))
    m.box("town_trim_dk", (w + 0.5, 0.14, 0.4), (0, h + 1.35, zf))       # cornice
    m.box("glass", (7.0, 1.0, 0.06), (0, h + 0.62, zf + 0.12))           # sign board
    if neon:
        for y in (h + 0.1, h + 1.14):
            m.box("town_neon", (7.1, 0.05, 0.05), (0, y, zf + 0.17))
        for x in (-3.55, 3.55):
            m.box("town_neon", (0.05, 1.05, 0.05), (x, h + 0.62, zf + 0.17))
    # storefront: two big panes + glass door, aluminium mullions
    for x in (-2.9, 2.9):
        m.box(glass, (3.4, 2.2, 0.06), (x, 1.55, zf + 0.02))
        m.box("town_foundation", (3.6, 0.45, 0.2), (x, 0.22, zf + 0.08))
    m.box("glass", (1.2, 2.3, 0.06), (0, 1.15, zf + 0.02))
    for x in (-4.65, -1.2, -0.6, 0.6, 1.2, 4.65):
        m.box("metal", (0.1, 2.7, 0.12), (x, 1.35, zf + 0.06))
    m.box("metal", (w - 0.4, 0.12, 0.14), (0, 2.7, zf + 0.06))
    m.box("metal", (0.08, 0.3, 0.05), (0.45, 1.1, zf + 0.08))
    m.decal("town_poster", 0.6, 0.85, (-2.0, 1.45, zf + 0.06))
    m.decal("town_poster", 0.6, 0.85, (3.6, 1.2, zf + 0.06), (0, 0, 8))
    # awning: sloped fabric with scalloped valance
    m.box("fabric", (w - 0.2, 0.06, 1.6), (0, 3.25, zf + 0.75), (-22, 0, 0))
    m.box("fabric", (w - 0.2, 0.35, 0.05), (0, 2.82, zf + 1.5))
    # side/back
    window(m, w / 2 + 0.01, 1.8, -2.5, 1.0, 1.0, "window", rot=90, boarded=True)
    door(m, 3.0, -4.82, rot=180, trim="town_trim_dk")
    m.box("bulb_cold", (0.3, 0.1, 0.15), (3.0, 2.45, -4.9))
    m.decal("town_graffiti", 3.0, 1.6, (-w / 2 - 0.02, 1.6, -1.0), (0, -90, 0))
    for x, z in ((-2.5, -2.5), (2.2, -1.0)):
        with m.push((x, h, z)):
            m.loft("metal", [(0, 0.55, 0.45), (0.6, 0.55, 0.45), (0.62, 0.5, 0.4), (0.62, 0, 0)], seg=12, power=5)
    m.cyl("metal", 0.12, 0.12, 1.1, (-4.0, h, -3.5), seg=6)
    m.cyl("metal", 0.2, 0.2, 0.15, (-4.0, h + 1.1, -3.5), seg=6)
    m.cyl("town_gutter", 0.06, 0.06, h, (w / 2 + 0.12, 0, -4.6), seg=5, caps=False)
    return m


def m_apartments():
    """Three-storey brick apartment block, entrance on +Z, fire escape on +X. Footprint 17 x 11.4."""
    m = B.Model("town_apartments")
    rng = random.Random(33)
    w, d, h = 15.0, 9.6, 9.6
    m.node("shell-col")
    m.box("brick", (w, h, d), (0, h / 2, -0.4))
    m.box("town_foundation", (w + 0.3, 0.5, d + 0.3), (0, 0.25, -0.4))
    m.box("town_foundation", (2.6, 0.2, 1.4), (0, 0.1, 4.9))
    m.node("detail")
    zf = 4.4
    for y in (3.2, 6.4):
        m.box("town_foundation", (w + 0.2, 0.22, d + 0.2), (0, y, -0.4))
    m.loft("town_foundation", [(0, 7.65, 5.0), (0.3, 7.75, 5.1), (0.5, 7.75, 5.1), (0.55, 7.6, 4.95)],
           (0, h, -0.4), seg=24, power=12)                                  # cornice
    m.box("brick", (w, 0.6, 0.25), (0, h + 0.8, zf - 0.1))                 # parapet
    m.box("brick", (w, 0.6, 0.25), (0, h + 0.8, -5.1))
    for s in (-1, 1):
        m.box("brick", (0.25, 0.6, d), (s * (w / 2 - 0.1), h + 0.8, -0.4))
    # entrance
    door(m, -0.45, zf + 0.02, 0.85, 2.3, trim="town_foundation")
    door(m, 0.45, zf + 0.02, 0.85, 2.3, trim="town_foundation")
    m.box("metal", (2.8, 0.15, 1.6), (0, 2.75, zf + 0.8))
    m.box("town_trim_dk", (3.8, 0.56, 0.06), (0, 3.62, zf + 0.04))  # name board over the canopy (world Label3D)
    for x in (-1.3, 1.3):
        m.cyl("metal", 0.04, 0.04, 2.1, (x, 0.6, zf + 1.5), (0, 0, 0), seg=5)
    m.box("bulb", (0.3, 0.06, 0.3), (0, 2.66, zf + 0.8))
    for fl, y in enumerate((1.7, 4.9, 8.1)):
        for x in (-6.0, -3.4, 3.4, 6.0) + ((-1.0, 1.0) if fl else ()):
            wm = "window_lit" if rng.random() < 0.15 else "window"
            window(m, x, y, zf + 0.01, 1.2 if fl else 1.6, 1.5, wm, trim="town_foundation",
                   boarded=fl == 0 and rng.random() < 0.3)
            window(m, x, y, -5.21, 1.2, 1.5, "window", trim="town_foundation", rot=180, boarded=rng.random() < 0.2)
        for z in (-3.2, 0.0, 2.6):
            window(m, -w / 2 - 0.01, y, z, 1.1, 1.5, "window_lit" if rng.random() < 0.1 else "window",
                   trim="town_foundation", rot=-90)
            window(m, w / 2 + 0.01, y, z, 1.1, 1.5, "window", trim="town_foundation", rot=90)
    # fire escape (+X side)
    with m.push((w / 2 + 0.7, 0, -0.5)):
        for y in (3.3, 6.5):
            m.box("iron", (1.3, 0.06, 4.4), (0, y, 0))
            m.box("iron", (0.05, 0.05, 4.4), (0.63, y + 1.0, 0))
            for z in (-2.15, 2.15):
                m.box("iron", (1.3, 0.05, 0.05), (0, y + 1.0, z))
            for k in range(12):
                m.box("iron", (0.03, 1.0, 0.03), (0.63, y + 0.5, -2.1 + k * 0.38))
            m.box("iron", (0.7, 0.05, 3.9), (0.0, y + 1.6, 0), (math.degrees(math.atan2(3.2, 3.9)), 0, 0))
        m.box("iron", (0.5, 3.0, 0.05), (0.3, 1.95 + 3.3, 1.9))
        for k in range(8):
            m.box("iron", (0.5, 0.04, 0.04), (0.3, 3.3 - 3.0 + 0.3 + k * 0.35, 1.9))
    # roof: water tank, vents, AC
    with m.push((-4.0, h, -2.0)):
        for x in (-0.8, 0.8):
            for z in (-0.8, 0.8):
                m.cyl("planks", 0.08, 0.08, 1.4, (x, 0, z), seg=4)
        m.lathe("planks", [(1.2, 1.4), (1.25, 1.5), (1.25, 3.5), (1.3, 3.6), (0.1, 4.4), (0, 4.45)], seg=12)
    for x, z in ((2.5, -3.0), (5.0, 1.0)):
        with m.push((x, h, z)):
            m.loft("metal", [(0, 0.6, 0.5), (0.7, 0.6, 0.5), (0.72, 0.55, 0.45), (0.72, 0, 0)], seg=12, power=5)
    antenna(m, 1.0, h, -1.0)
    m.decal("town_graffiti", 4.0, 1.8, (-3.4, 1.4, -5.27), (0, 180, 0))
    m.decal("town_poster", 0.7, 1.0, (2.0, 1.3, zf + 0.04))
    m.decal("town_poster", 0.7, 1.0, (2.8, 1.25, zf + 0.04), (0, 0, -6))
    return m


def m_gas_station():
    """Canopy over two pump islands with a kiosk behind. Forecourt faces +Z. Footprint 15 x 13."""
    m = B.Model("town_gas_station")
    m.node("shell-col")
    m.box("town_stucco_b", (7.0, 3.2, 4.4), (0, 1.6, -4.0))
    for x in (-3.5, 3.5):
        for z in (-0.2, 4.2):
            m.loft("town_trim", [(0, 0.2, 0.2), (4.2, 0.2, 0.2)], (x, 0, z), seg=8, power=4)
    for x in (-3.5, 3.5):
        m.box("town_foundation", (1.2, 0.2, 4.0), (x, 0.1, 2.0))
        for z in (1.1, 2.9):
            m.loft("town_pump", [(0.2, 0.3, 0.2), (1.5, 0.3, 0.2), (1.62, 0.26, 0.16), (1.65, 0, 0)], (x, 0, z), seg=10, power=4)
    m.node("detail")
    m.box("town_trim", (10.8, 0.7, 6.8), (0, 4.55, 2.0))                                       # canopy
    m.box("town_trim_dk", (11.0, 0.12, 7.0), (0, 4.95, 2.0))
    m.box("fabric", (10.9, 0.3, 0.02), (0, 4.55, 5.42))
    for x in (-2.0, 2.0):
        m.box("town_canopy_light", (1.2, 0.03, 0.6), (x, 4.19, 2.0))
    m.box("town_lamp_dead", (1.2, 0.03, 0.6), (0, 4.19, 2.0))
    for x in (-3.5, 3.5):
        for z in (1.1, 2.9):
            m.box("screen", (0.36, 0.25, 0.02), (x, 1.25, z + (0.21 if z > 2 else -0.21)), (0, 0 if z > 2 else 180, 0))
            m.cyl("rubber", 0.03, 0.03, 0.9, (x + 0.3, 0.55, z), (0, 0, 20), seg=4)
    # kiosk front: window wall, door, sign band
    m.box("town_win_fluor", (4.2, 1.6, 0.06), (-1.0, 1.5, -1.78))
    m.box("glass", (1.0, 2.2, 0.06), (2.2, 1.1, -1.78))
    m.box("town_trim_dk", (7.2, 0.6, 0.2), (0, 3.0, -1.72))
    m.box("town_trim", (7.4, 0.2, 4.6), (0, 3.3, -4.0))
    for x in (-3.1, 1.2, 1.7, 2.7):
        m.box("metal", (0.08, 2.4, 0.1), (x, 1.2, -1.74))
    m.box("town_foundation", (7.2, 0.5, 0.2), (0, 0.25, -1.72))
    m.decal("town_poster", 0.6, 0.85, (-2.2, 1.4, -1.72))
    m.box("metal", (1.0, 0.1, 1.0), (-2.5, 3.2, -5.5))
    m.decal("town_graffiti_r", 3.0, 1.4, (0, 1.4, -6.22), (0, 180, 0))
    # price sign on a pole
    m.cyl("metal", 0.12, 0.12, 5.0, (6.4, 0, 5.4), seg=6)
    m.box("town_trim_dk", (2.0, 1.6, 0.3), (6.4, 5.4, 5.4))
    m.box("town_win_fluor", (1.8, 0.4, 0.32), (6.4, 5.8, 5.4))
    for y in (5.0, 5.35):
        m.box("white", (1.5, 0.22, 0.32), (6.4, y, 5.4))
    # air/water machine, ice chest, tires
    m.box("red", (0.5, 1.2, 0.4), (-4.0, 0.6, -1.5))
    m.box("white", (1.3, 0.9, 0.7), (3.0, 0.45, -1.45), faces={"+z": "town_trim_dk"})
    for k in range(3):
        m.loft("rubber", [(0, 0.34, 0.34), (0.22, 0.34, 0.34)], (4.8, 0.02 + k * 0.23, -2.0), seg=10)
    return m


# ------------------------------------------------------------------ street furniture & decoration

def m_picket_fence():
    """3 m picket segment along X; a couple of pickets missing or leaning."""
    m = B.Model("town_picket_fence")
    rng = random.Random(4)
    m.node("fence-col")
    for x in (-1.5, 1.5):
        m.box("town_trim", (0.1, 1.0, 0.1), (x, 0.5, 0))
    for y in (0.3, 0.72):
        m.box("town_trim", (3.0, 0.08, 0.04), (0, y, 0.05))
    m.node("detail")
    for k in range(11):
        if rng.random() < 0.1:
            continue
        x = -1.35 + k * 0.27
        lean = rng.uniform(-6, 6) if rng.random() < 0.25 else 0
        m.tbox("town_trim", (0.09, 0.025), (0.09, 0.025), 0.82, (x, 0.02, 0.09), (0, 0, lean))
        m.tbox("town_trim", (0.09, 0.025), (0.0, 0.025), 0.1, (x, 0.84, 0.09), (0, 0, lean))
    return m


def m_hedge():
    """Overgrown 3 m hedge along X."""
    m = B.Model("town_hedge")
    m.node("hedge-col")
    m.box("town_hedge", (2.9, 1.1, 0.8), (0, 0.55, 0))
    m.node("leaves")
    m.loft("town_hedge", [(0, 1.45, 0.45), (0.5, 1.6, 0.55), (1.1, 1.55, 0.52), (1.35, 1.2, 0.35),
                          (1.42, 0.0, 0.0)], (0, 0, 0), seg=14, power=3)
    for x, s in ((-0.9, 0.35), (0.3, 0.42), (1.1, 0.3)):
        m.ellipsoid("town_hedge", (s * 1.4, s, s), (x, 1.25 + s * 0.3, 0.05), seg=8, rings=5)
    return m


def m_hydrant():
    m = B.Model("town_hydrant")
    m.node("body-col")
    m.lathe("town_hydrant", [(0.17, 0), (0.17, 0.08), (0.13, 0.1), (0.13, 0.55), (0.16, 0.58), (0.15, 0.64),
                             (0.1, 0.72), (0.03, 0.78), (0, 0.8)], seg=10)
    m.node("detail")
    for a in (0, 180):
        m.cyl("town_hydrant", 0.055, 0.055, 0.12, (0, 0.45, 0), (0, a, 90), seg=6)
    m.cyl("town_hydrant", 0.07, 0.07, 0.14, (0, 0.42, 0), (90, 0, 0), seg=6)
    m.cyl("metal", 0.035, 0.035, 0.05, (0, 0.78, 0), seg=5)
    return m


STREET_BLADES = ((0, 2.84), (90, 3.1))  # (turn, centre height) of the street sign's two name blades


def m_street_sign():
    """Stop sign with two street-name blades on top."""
    m = B.Model("town_street_sign")
    m.node("pole-col")
    m.cyl("metal", 0.035, 0.035, 2.74, seg=6)  # (stops under the blades: never across their lettering)
    m.node("detail")
    m.cyl("metal", 0.025, 0.025, 0.06, (0, 2.94, 0), seg=6)  # the bracket between the two blades
    m.cyl("town_stop", 0.38, 0.38, 0.03, (0, 2.2, 0.05), (90, 0, 0), seg=8, phase=0.5)
    m.cyl("white", 0.4, 0.4, 0.02, (0, 2.2, 0.035), (90, 0, 0), seg=8, phase=0.5)
    m.box("white", (0.5, 0.1, 0.035), (0, 2.2, 0.075))
    for a, y in STREET_BLADES:  # name blades: the names are world Label3Ds on both faces (place())
        m.box("town_sign", (1.0, 0.2, 0.03), (0, y, 0), (0, a, 0))
        for s in (-1, 1):
            m.box("white", (0.98, 0.012, 0.032), (0, y + s * 0.094, 0), (0, a, 0))  # white edge lines
    return m


def m_trash_bags():
    m = B.Model("town_trash_bags")
    rng = random.Random(9)
    m.node("detail")
    for x, z, r in ((0, 0, 0.36), (0.55, 0.2, 0.3), (-0.2, 0.5, 0.28), (0.3, -0.45, 0.25)):
        m.ellipsoid("town_bag", (r, r * 0.8, r * 1.1), (x, r * 0.75, z), (0, rng.uniform(0, 90), rng.uniform(-15, 15)),
                    seg=8, rings=5)
        m.cyl("town_bag", 0.05, 0.02, 0.14, (x, r * 1.45, z), seg=4)
    m.decal("town_poster", 0.3, 0.4, (0.9, 0.02, 0.4), (-90, 30, 0))
    return m


def m_pallets():
    m = B.Model("town_pallets")
    m.node("stack-col")
    for k, a in enumerate((0, 8, -5)):
        with m.push((0, k * 0.16, 0), (0, a, 0)):
            for x in (-0.5, 0, 0.5):
                m.box("planks", (0.1, 0.1, 1.2), (x, 0.05, 0))
            for z in (-0.5, -0.2, 0.1, 0.4):
                m.box("planks", (1.2, 0.03, 0.12), (0, 0.12, z + 0.05))
    m.node("detail")
    m.box("planks", (1.2, 0.03, 1.2), (0.7, 0.55, -0.3), (0, 20, 68))       # one leaning against
    return m


def m_powerline():
    """Three sagging wires from a pole crossbar (x = -0.9, 0, 0.9, y = 8.3) to the next pole 22 m along +Z."""
    m = B.Model("town_powerline")
    m.node("wires")
    n, L = 8, 22.0
    for x in (-0.9, 0.0, 0.9):
        pts = [(x, 8.3 - 0.9 * math.sin(math.pi * k / n), L * k / n) for k in range(n + 1)]
        for p, q in zip(pts, pts[1:]):
            dz, dy = q[2] - p[2], q[1] - p[1]
            m.box("town_wire", (0.03, 0.03, math.hypot(dz, dy) + 0.02), ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, (p[2] + q[2]) / 2),
                  (-math.degrees(math.atan2(dy, dz)), 0, 0))
    return m


def m_planter():
    """Concrete planter overgrown with a scraggly shrub."""
    m = B.Model("town_planter")
    rng = random.Random(3)
    m.node("planter-col")
    m.box("town_foundation", (1.4, 0.6, 1.4), (0, 0.3, 0))
    m.node("detail")
    m.box("mud", (1.2, 0.02, 1.2), (0, 0.6, 0))
    for k in range(4):
        m.ellipsoid("town_hedge", (0.45, 0.4, 0.45), (rng.uniform(-0.3, 0.3), 0.85 + k * 0.08, rng.uniform(-0.3, 0.3)),
                    seg=7, rings=4)
    m.ellipsoid("town_moss", (0.35, 0.12, 0.1), (0.5, 0.45, 0.62), seg=6, rings=3)
    for a in (0, 70, 150, 230):
        m.cyl("bark", 0.02, 0.005, 0.9, (0, 0.6, 0), (30, a, 0), seg=3)
    return m


def m_notice_board():
    """Wall-less alley notice board covered in missing posters, faces +Z."""
    m = B.Model("town_notice_board")
    rng = random.Random(6)
    m.node("board-col")
    for x in (-1.1, 1.1):
        m.box("planks", (0.12, 2.2, 0.12), (x, 1.1, 0))
    m.box("planks", (2.4, 1.3, 0.06), (0, 1.45, 0.02))
    m.node("detail")
    m.box("town_shingle", (2.7, 0.08, 0.5), (0, 2.25, 0.1), (-15, 0, 0))
    for k in range(7):
        m.decal("town_poster", 0.42, 0.6, (-0.9 + k * 0.3 + rng.uniform(-0.05, 0.05), 1.45 + rng.uniform(-0.3, 0.3), 0.06 + k * 0.004),
                (0, 0, rng.uniform(-10, 10)))
    return m


def m_graffiti_wall():
    """Free-standing cracked concrete alley wall (4 m) with graffiti both sides."""
    m = B.Model("town_graffiti_wall")
    m.node("wall-col")
    m.box("concrete", (4.0, 2.2, 0.25), (0, 1.1, 0))
    m.node("detail")
    m.box("town_foundation", (4.1, 0.1, 0.32), (0, 2.25, 0))
    m.decal("town_graffiti", 3.2, 1.5, (0, 1.0, 0.13))
    m.decal("town_graffiti_r", 3.0, 1.4, (0.2, 1.1, -0.13), (0, 180, 0))
    m.decal("town_poster", 0.5, 0.7, (-1.4, 1.5, 0.135), (0, 0, 7))
    return m


def m_glow_fungus():
    """Clump of faintly glowing green fungus on a mossy stump (no collision)."""
    m = B.Model("town_glow_fungus")
    rng = random.Random(12)
    m.node("detail")
    m.cyl("bark", 0.35, 0.3, 0.45, seg=7)
    m.ellipsoid("town_moss", (0.6, 0.12, 0.55), (0.1, 0.02, 0.1), seg=8, rings=4)
    for k in range(9):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0.25, 0.7)
        x, z, s = rr * math.cos(a), rr * math.sin(a), rng.uniform(0.6, 1.3)
        y = 0.45 if rr < 0.33 else 0.0
        m.cyl("town_fungus_stem", 0.035 * s, 0.025 * s, 0.26 * s, (x, y, z), seg=5, caps=False)
        m.lathe("town_fungus", [(0.03, 0), (0.15 * s, 0.015), (0.13 * s, 0.06 * s), (0, 0.09 * s)], (x, y + 0.25 * s, z), seg=8)
    for k in range(4):  # glowing moss blobs
        a = k * 1.7
        m.ellipsoid("town_fungus", (0.22, 0.03, 0.16), (0.8 * math.cos(a), 0.0, 0.8 * math.sin(a)), (0, k * 40, 0), seg=7, rings=3)
    for k in range(3):  # shelf brackets on the stump
        m.ellipsoid("town_fungus", (0.12, 0.025, 0.08), (0.3 * math.cos(k * 2.1), 0.15 + k * 0.1, 0.3 * math.sin(k * 2.1)),
                    (0, -math.degrees(k * 2.1), 0), seg=7, rings=3)
    return m


def m_green_lantern():
    """Crooked post with a hanging lantern of sickly green glass."""
    m = B.Model("town_green_lantern")
    m.node("post-col")
    m.cyl("bark", 0.08, 0.06, 2.6, seg=5)
    m.node("detail")
    m.box("planks", (0.08, 0.08, 0.8), (0, 2.5, 0.35))
    m.cyl("iron", 0.01, 0.01, 0.3, (0, 2.2, 0.7), seg=3, caps=False)
    m.lathe("iron", [(0.0, 1.88), (0.1, 1.9), (0.1, 1.92)], (0, 0, 0.7), seg=6)
    m.lathe("town_neon", [(0.08, 1.92), (0.11, 2.0), (0.11, 2.12), (0.06, 2.2)], (0, 0, 0.7), seg=6)
    m.lathe("iron", [(0.07, 2.19), (0.12, 2.2), (0.0, 2.28)], (0, 0, 0.7), seg=6)
    return m


def m_lamp_dead():
    import models_hd_street
    return models_hd_street.m_lamp_post("town_lamp_dead", "town_lamp_dead")


MODELS = [m_house_tall, lambda: m_house_tall("town_house_e", "town_siding_g", "town_shingle", False, 12, True),
          lambda: m_house_tall("town_house_f", "town_siding_r", "town_shingle_r", True, 13),
          m_duplex, lambda: m_duplex("town_duplex_b", "town_stucco", "town_shingle", 22),
          m_garage, m_shop, lambda: m_shop("town_pawnshop", "brick", "window_lit", False),
          m_apartments, m_gas_station, m_picket_fence, m_hedge, m_hydrant, m_street_sign, m_trash_bags,
          m_pallets, m_powerline, m_planter, m_notice_board, m_graffiti_wall, m_glow_fungus, m_green_lantern,
          m_lamp_dead]


# ------------------------------------------------------------------ placement

# half extents (x, z) of each building model at yaw 0 (door on +Z)
FOOT = {"house_a": (5.5, 5.5), "house_b": (5.5, 5.5), "house_c": (5.5, 5.5), "town_house_d": (4.6, 5.3),
        "town_house_e": (4.6, 5.3), "town_house_f": (4.6, 5.3), "town_duplex": (6.6, 4.8), "town_duplex_b": (6.6, 4.8),
        "town_garage": (2.4, 3.3), "town_laundromat": (5.2, 4.8), "town_pawnshop": (5.2, 4.8),
        "town_apartments": (8.6, 5.7), "town_gas_station": (7.5, 6.5)}
HOUSES = ["house_a", "house_b", "house_c", "town_house_d", "town_house_e", "town_house_f", "town_duplex",
          "town_duplex_b", "town_house_d", "town_house_f"]


def _fits(W, x0, z0, x1, z1):
    return not any(a < x1 and x0 < c and b < z1 and z0 < d for a, b, c, d in W.rects) and \
        not any(x0 - r < cx < x1 + r and z0 - r < cz < z1 + r for cx, cz, r in W.circles)


def _rot(x, z, yaw):
    a = math.radians(yaw)
    return x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a)


def building(W, model, x, z, yaw):
    """Place with the model's footprint if the lot is free. Returns True on success."""
    hw, hd = FOOT[model]
    if yaw % 180:
        hw, hd = hd, hw
    if not _fits(W, x - hw, z - hd, x + hw, z + hd):
        return False
    W.building(model, x, z, yaw, hw, hd)
    return True


def lot_dressing(W, rng, x, z, yaw, model):
    """Front yard: fence or hedge by the sidewalk, mailbox, sometimes a garage or car out back."""
    def at(lx, lz):
        dx, dz = _rot(lx, lz, yaw)
        return x + dx, z + dz
    front = FOOT[model][1] + 0.4
    kind = rng.random()
    for lx in (-3.4, 3.4):
        fx, fz = at(lx, front)
        if kind < 0.45:
            W.inst("town_picket_fence", fx, fz, yaw)
        elif kind < 0.7:
            W.inst("town_hedge", fx, fz, yaw, s=rng.uniform(0.9, 1.1))
    mx, mz = at(-1.0, front + 0.3)
    if rng.random() < 0.7:
        W.inst("ext_mailbox", mx, mz, yaw + rng.uniform(-10, 10))
    gx, gz = at(rng.choice((-3.0, 3.0)), -FOOT[model][1] - 4.0)
    if rng.random() < 0.45:
        building(W, "town_garage", gx, gz, yaw + 180 if rng.random() < 0.5 else yaw)
    elif rng.random() < 0.3:
        tx, tz = at(4.0, -1.0)
        W.inst("town_trash_bags", tx, tz, rng.uniform(0, 360))


def street(W, rng, road_axis, c, a0, a1, off, step, models=None, dress=True):
    """Row of lots along a road. road_axis 'x': road runs along x at z=c, lots at z=c+off (both signs
    passed separately); 'z': road runs along z at x=c. Houses face the road."""
    placed = []
    a = a0
    while (a <= a1) if a1 >= a0 else (a >= a1):
        model = rng.choice(models or HOUSES)
        if road_axis == "x":
            x, z, yaw = a, c + off, 0 if off < 0 else 180
        else:
            x, z, yaw = c + off, a, 90 if off < 0 else -90
        if building(W, model, x, z, yaw):
            placed.append((model, x, z, yaw))
            if dress:
                lot_dressing(W, rng, x, z, yaw, model)
        a += step if a1 >= a0 else -step
    return placed


def light(W, x, y, z, color, energy, rng_, flicker=False, atten=0.4):
    """W.light with a flatter falloff (Godot's default inverse-square makes 4 m high lamps leave no pool)."""
    W.light(x, y, z, color, energy, rng_, flicker)
    W.nodes[-1] += "omni_attenuation = %g\nlight_volumetric_fog_energy = 0.35\n" % atten


def lamps(W, rng, road, every=30.0, cut=()):
    """Street lamps on the sidewalk, alternating sides, pools of light with dark gaps between them."""
    (ax, az), (bx, bz), w, mat = road
    n = max(1, int(math.hypot(bx - ax, bz - az) // every))
    out = []
    for k in range(n + 1):
        t = (k + 0.5) / (n + 1)
        x, z = ax + (bx - ax) * t, az + (bz - az) * t
        s = 1 if k % 2 else -1
        if ax == bx:
            x += s * (w / 2 + 1.0)
        else:
            z += s * (w / 2 + 1.0)
        if any(x0 < x < x1 and z0 < z < z1 for x0, z0, x1, z1 in cut) or W.blocked(x, z, 0.6):
            continue
        yaw = math.degrees(math.atan2(ax - x if ax == bx else 0, az - z if az == bz else 0))
        roll = rng.random()
        if roll < 0.2:
            W.inst("town_lamp_dead", x, z, yaw + rng.uniform(-6, 6), block=0.5)
            continue
        cold = roll > 0.72
        W.inst("lamp_post_cold" if cold else "lamp_post", x, z, yaw, block=0.5)
        a = math.radians(yaw)
        light(W, x + 1.1 * math.sin(a), 4.2, z + 1.1 * math.cos(a), B.COLD if cold else B.WARM,
                3.6 if cold else 4.5, 11, flicker=rng.random() < 0.3)
        out.append((x, z))
    return out


def powerline(W, x, z, axis, n):
    """n spans of wire between n + 1 utility poles, 22 m apart, starting at (x, z)."""
    for k in range(n + 1):
        px, pz = (x + 22 * k, z) if axis == "x" else (x, z + 22 * k)
        W.inst("utility_pole", px, pz, 90 if axis == "x" else 0, block=0.4)
        if k < n:
            W.inst("town_powerline", px, pz, 90 if axis == "x" else 0)


def place(W, rng):
    rng = random.Random(2024)
    G = GREEN

    # --- commercial frontage around the square and on the east road
    if building(W, "town_apartments", 40, -28, -90):
        W.board_label("HOLLOWMERE ARMS", (40, -28, -90), (0, 3.62, 4.47), (3.8, 0.56), (0.75, 0.66, 0.48), 40)
    if building(W, "town_laundromat", -38, -26, 90):
        W.board_label("LAUNDROMAT  24H", (-38, -26, 90), (0, 4.82, 3.35), (7.0, 1.0), (0.5, 1.0, 0.55), 52)
    light(W, -33, 3.2, -26, G, 2.2, 8, flicker=True)
    if building(W, "town_pawnshop", -38, 24, 90):  # (its lot is taken: no shop, so no sign hanging in the air)
        W.board_label("PAWN & LOAN", (-38, 24, 90), (0, 4.82, 3.35), (7.0, 1.0), (0.85, 0.6, 0.35), 52)
    light(W, -33.5, 2.8, 24, B.WARM, 2.0, 7)
    building(W, "town_duplex", 40, 26, -90)
    if building(W, "town_gas_station", 76, -14, 0):
        W.board_label("GAS - FOOD - ICE", (76, -14, 0), (0, 3.0, -1.62), (7.2, 0.6), (0.75, 0.95, 0.8), 40)
    light(W, 76, 3.9, -12, (0.8, 0.95, 1.0), 2.4, 10, flicker=True)
    for x, z, yaw in ((73, -9.5, 90), (79.5, -8.8, 95)):
        W.inst("car_wreck", x, z, yaw, block=2.4)

    # --- residential streets (houses face the road on both sides)
    for off in (-12, 12):
        street(W, rng, "x", -58, 28, 40, off, 12)          # Elm St, east
        street(W, rng, "x", -58, -28, -40, off, 12)        # Elm St, west
        street(W, rng, "x", 60, 26, 54, off, 14)           # Maple Ave
        street(W, rng, "x", 60, -28, -70, off, 14)         # Lake Rd
    street(W, rng, "z", 0, 90, 90, 14, 1)
    street(W, rng, "z", 0, -86, -86, 14, 1)
    street(W, rng, "z", 0, -86, -86, -14, 1)
    street(W, rng, "z", 0, 92, 92, -14, 1, ["town_garage"], dress=False)
    street(W, rng, "x", 0, 74, 74, 12, 1)
    street(W, rng, "x", 0, -70, -70, -12, 1, ["town_garage"])
    street(W, rng, "x", 0, 88, 88, -13, 1, ["town_duplex_b"])
    # yard dressing for the original house slots too
    for x, z, yaw in ((-42, -12, 0), (-58, -12, 0), (-42, 12, 180), (-58, 13, 180), (42, -12, 0), (58, -12, 0),
                      (42, 12, 180), (60, 12, 180), (-14, 40, 90), (14, 40, -90), (14, 76, -90), (-14, 80, 90),
                      (-14, -45, 90), (14, -48, -90), (-14, -66, 90), (14, -70, -90)):
        lot_dressing(W, rng, x, z, yaw, "house_a")

    # --- street lamps along every paved town road (skip the lit square)
    square = [(-31, -31, 31, 31)]
    for road in B.ROADS:
        if road[3] == "asphalt":
            lamps(W, rng, road, 30 if road[2] >= 7 else 26, square)

    # --- power lines on the main roads
    powerline(W, 5.5, -90, "z", 8)
    powerline(W, -70, -5.5, "x", 1)
    powerline(W, 40, -5.5, "x", 2)
    powerline(W, -80, 54.5, "x", 3)
    powerline(W, 8, 54.5, "x", 2)

    # --- hydrants, stop signs, parked cars
    for x, z in ((-5.2, 36), (5.2, 70), (-5.2, -40), (5.2, -78), (-40, 5.3), (50, -5.3), (-30, 55.3), (-60, 65.3),
                 (30, 55.3), (20, -52.8), (-26, -63.2), (-5.2, 96)):
        W.inst("town_hydrant", x, z, rng.uniform(0, 360), block=0.3)
    for x, z, yaw in ((-4.8, 55, 0), (4.8, -53, 180), (-4.8, -62, 0), (4.8, 64.5, 180), (-81, 55, 90),
                      (-5, -95.5, 0), (5, -95.5, 180)):
        W.inst("town_street_sign", x, z, yaw, block=0.3)
    for x, z, yaw in ((-40, 57.7, 0), (-66, 62.3, 180), (32, 57.7, 0), (2.3, 84, 90),
                      (-2.4, -76, -90), (22, -60.3, 180), (-34, -55.8, 0), (-50, 2.3, 180)):
        W.inst("car_wreck", x, z, yaw)
    # street names on the blades, both faces (the low blade runs along the sign's x, the high one across it)
    for name, (x, z, yaw), high in (("ELM ST", (4.8, -53, 180), False), ("MAPLE AVE", (4.8, 64.5, 180), True),
                                    ("LAKE RD", (-4.8, 55, 0), False)):
        W.board_label(name, (x, z, yaw + (90 if high else 0)), (0, STREET_BLADES[high][1], 0.015), (0.96, 0.17),
                      (0.88, 0.88, 0.82), 18, back=-0.015)

    # --- alleys: dumpsters, bags, pallets, graffiti, sickly green light
    for x, z, yaw in ((-35, -12, 90), (35, -12, 90), (-50, 12.5, 90), (21, 48, 90), (-21, 72, 90), (47, -46, 90),
                      (-47.5, -46, 90)):
        W.inst("town_graffiti_wall", x, z, yaw)
    for x, z, yaw, green in ((-35, -18, 0, True), (47, -34, 0, True), (-21, 67, 0, True), (21, 43, 0, False),
                             (-45, -32, 0, False), (84, -20, 0, True), (-44, 30, 0, True)):
        if not W.blocked(x, z, 1.0):
            W.inst(rng.choice(("ext_dumpster", "town_pallets")), x, z, yaw + rng.uniform(-20, 20), block=1.2)
        W.inst("town_trash_bags", x + 1.5, z + 1.2, rng.uniform(0, 360))
        if green:
            light(W, x, 2.6, z + 0.5, G, 1.5, 6, flicker=rng.random() < 0.5)
    for x, z, yaw in ((-3.8, -33, 0), (22, 32, 180), (-24.5, 31.5, 180), (56, 5.2, 180)):
        W.inst("town_notice_board", x, z, yaw)
    for x, z in ((-8, -30), (8, -30), (-30, -8), (30, 8), (-20, 30.5), (20, 30.5), (-29.5, 20), (29.5, -20)):
        W.inst("town_planter", x, z, rng.uniform(0, 90), block=0.9)

    # --- green accents at the edges: glowing fungus and lanterns by the forest and cemetery
    for x, z in ((-76, -30), (-77, 20), (-75, -52), (-78, 34), (-112, -60), (-46, -138), (-60, -143),
                 (-109, -110), (-80, -58), (-44, -70), (-120, 20), (-135, 5), (-95, -55)):
        if not W.blocked(x, z, 0.8):
            W.inst("town_glow_fungus", x, z, rng.uniform(0, 360), rng.uniform(0.8, 1.3))
    for x, z in ((-76, -30), (-111, -100), (-46, -138), (-120, 20)):
        light(W, x, 0.8, z, G, 1.3, 4.5)
    for x, z, yaw in ((-73.5, 4.5, 90), (-44.5, -104.5, -90), (-44.5, -95.5, -90), (-102, 4.5, 90), (-97.5, 104, 0)):
        W.inst("town_green_lantern", x, z, yaw, block=0.3)
        a = math.radians(yaw)
        light(W, x + 0.7 * math.sin(a), 2.0, z + 0.7 * math.cos(a), G, 1.5, 6, flicker=rng.random() < 0.4)
