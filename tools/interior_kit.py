"""Interior kit: partitions with real doorways, stair flights (walkable), floor slabs with stairwells, and the
furniture / dressing the enterable buildings are furnished with (school, clinic, church).

Not a models_* pack: the building models import it. Geometry goes onto the Model's current node unless a
helper says otherwise; walls and big furniture belong in a "-col" node, dressing in "detail". Stairs put
their visible steps on the current node and an invisible ramp in "stairs-colonly" (Godot's importer turns
"-colonly" nodes into collision only), so they're walked like a slope.
"""
import math

import build_assets as B

mul, mix = B.mul, B.mix


# ============================================================== textures

def t_ik_chalk(x, y, a, b, r):
    c = mul((0.16, 0.26, 0.2), 0.8 + 0.3 * a)
    if 6 < y < 40 and y % 7 in (0, 1) and (x * 7 + y * 3) % 11 > 3 and 4 < x < 60 - (y * 5) % 23:
        return mix(c, (0.85, 0.85, 0.8), 0.7)  # lines of chalk writing
    if (x - 46) ** 2 + (y - 48) ** 2 in range(60, 90) or (y == 48 and 36 < x < 58):
        return mix(c, (0.85, 0.85, 0.8), 0.8)  # a chalk sun over a line
    return mix(c, (0.5, 0.55, 0.5), 0.25) if b > 0.7 else c  # half-wiped smears


def t_ik_cork(x, y, a, b, r):
    c = mul((0.6, 0.42, 0.25), 0.7 + 0.4 * r)
    for px, py, pw, ph, col in ((6, 8, 16, 20, (0.9, 0.88, 0.8)), (28, 4, 14, 12, (0.95, 0.8, 0.4)),
                                (44, 10, 14, 22, (0.85, 0.9, 0.95)), (10, 36, 20, 14, (0.95, 0.6, 0.6)),
                                (36, 40, 20, 18, (0.9, 0.9, 0.85))):
        if px <= x < px + pw and py <= y < py + ph:
            if x == px + pw // 2 and y == py + 1:
                return (0.8, 0.1, 0.1)  # pin
            return mul(col, 0.75 + 0.2 * a) if (y - py) % 4 else mul(col, 0.55)
    return c


def t_ik_exit(x, y, a, b, r):
    if 8 < y < 56 and any(x0 <= x < x0 + 10 for x0 in (6, 20, 34, 48)) and not (y % 16 < 3 and x % 10 > 5):
        return (0.9, 1.0, 0.9)
    return (0.05, 0.55, 0.2)


def t_ik_lino(x, y, a, b, r):
    c = (0.72, 0.7, 0.62) if (x // 16 + y // 16) % 2 else (0.6, 0.62, 0.58)
    c = mul(c, 0.85 + 0.2 * a)
    if r > 0.93:
        c = mul(c, 0.7)  # speckle
    if x % 16 == 0 or y % 16 == 0:
        c = mul(c, 0.8)
    return mix(c, (0.35, 0.3, 0.22), 0.4) if b > 0.72 else c  # grime


def t_ik_poster_a(x, y, a, b, r):
    """School: an alphabet frieze, faded."""
    c = (0.92, 0.9, 0.82)
    cols = ((0.85, 0.25, 0.2), (0.25, 0.45, 0.8), (0.95, 0.75, 0.2), (0.3, 0.65, 0.35))
    if 12 < y < 52 and x % 16 in range(2, 14):
        k = x // 16
        if (x % 16 - 8) ** 2 + (y - 32) ** 2 < 30 or (y % 12 < 3 and x % 16 in range(4, 12)):
            return mul(cols[k % 4], 0.7 + 0.2 * a)
    return mul(c, 0.8 + 0.2 * a)


def t_ik_poster_b(x, y, a, b, r):
    """Clinic: a health poster, a figure and a red cross."""
    c = mul((0.88, 0.9, 0.92), 0.8 + 0.2 * a)
    if (x - 22) ** 2 + (y - 14) ** 2 < 30 or (18 < x < 26 and 18 < y < 44) or (12 < x < 32 and 22 < y < 26):
        return (0.3, 0.45, 0.6)
    if (abs(x - 46) < 3 and 12 < y < 30) or (abs(y - 21) < 3 and 37 < x < 55):
        return (0.8, 0.1, 0.1)
    if y > 50 and x % 5 and 6 < x < 58 and y % 4 < 2:
        return (0.3, 0.3, 0.32)
    return c


def t_ik_map(x, y, a, b, r):
    c = mul((0.55, 0.7, 0.85), 0.8 + 0.2 * a)
    if b > 0.52:
        c = mul((0.55, 0.7, 0.4), 0.8 + 0.3 * a)
    if x % 16 == 0 or y % 16 == 0:
        c = mul(c, 0.85)
    return c


def t_ik_hymn(x, y, a, b, r):
    c = mul((0.2, 0.13, 0.08), 0.8 + 0.3 * a)
    for row in range(4):
        if 4 + row * 15 < y < 14 + row * 15 and 10 < x < 54 and x % 11 in range(2, 8):
            return (0.9, 0.88, 0.8)
    return c


def t_ik_carpet(x, y, a, b, r):
    c = mul((0.45, 0.07, 0.07), 0.7 + 0.35 * a)
    if x % 32 in (2, 3, 28, 29):
        c = (0.6, 0.45, 0.15)  # gold border
    return mix(c, (0.25, 0.2, 0.15), 0.5) if b > 0.7 else c


def t_ik_chart(x, y, a, b, r):
    """Clipboard chart / eye chart."""
    c = mul((0.92, 0.92, 0.88), 0.85 + 0.15 * a)
    size = 12 - y // 8
    if y % 8 < max(size // 2, 1) and 32 - size * 2 < x < 32 + size * 2 and x % max(size, 2) < max(size - 1, 1):
        return (0.1, 0.1, 0.1)
    return c


def t_ik_bottles(x, y, a, b, r):
    """Pharmacy shelf front: rows of bottles and boxes."""
    if y % 16 < 2:
        return (0.35, 0.36, 0.38)  # shelf edge
    k = (x // 6 + (y // 16) * 3) % 5
    col = ((0.55, 0.3, 0.1), (0.85, 0.85, 0.8), (0.3, 0.5, 0.35), (0.8, 0.25, 0.2), (0.25, 0.35, 0.6))[k]
    if x % 6 == 0 or (y % 16 < 5 and x % 6 in (1, 5)):
        return (0.08, 0.08, 0.08)
    return mul(col, 0.7 + 0.3 * a)


def t_ik_drawings(x, y, a, b, r):
    """A strip of children's crayon drawings."""
    k = x // 16
    c = (0.95, 0.93, 0.85)
    if x % 16 in (0, 15) or y in (0, 63):
        return (0.6, 0.55, 0.45)
    cols = ((0.9, 0.3, 0.2), (0.2, 0.5, 0.9), (0.95, 0.75, 0.1), (0.3, 0.7, 0.3))
    cx = k * 16 + 8
    if (x - cx) ** 2 + (y - 22) ** 2 < 14 or (abs(x - cx) < 1 and 26 < y < 44) or (y == 34 and abs(x - cx) < 5):
        return cols[k % 4]
    if y > 52 and (x * 3 + k) % 4 == 0:
        return (0.3, 0.6, 0.25)  # grass
    return c


def t_ik_plaster(x, y, a, b, r):
    """Painted plaster (tinted by the material): faint mottling, water stains running down from the top,
    scuffs and grime toward the floor (v runs top → bottom)."""
    c = 0.86 + 0.1 * a + 0.03 * r
    if b > 0.66 and y < 40 - 30 * (b - 0.66) / 0.34 * 0:  # stain runs from the ceiling
        c *= 0.78 + 0.1 * (y / 64)
    if y > 52 and a > 0.55:
        c *= 0.82  # grime above the skirting
    if r > 0.985:
        c *= 0.7  # chips
    return (c, c * 0.98, c * 0.94)


B.TEXTURES.update({k[2:]: v for k, v in dict(globals()).items() if k.startswith("t_ik_")})

B.MATS.update({
    "ik_chalk": B.M("ik_chalk", fit=True), "ik_cork": B.M("ik_cork", fit=True),
    "ik_exit": B.M("ik_exit", fit=True, emit=1.2), "ik_lino": B.M("ik_lino", scale=2.5),
    "ik_poster_a": B.M("ik_poster_a", fit=True), "ik_poster_b": B.M("ik_poster_b", fit=True),
    "ik_map": B.M("ik_map", fit=True), "ik_hymn": B.M("ik_hymn", fit=True), "ik_carpet": B.M("ik_carpet", scale=1.2),
    "ik_chart": B.M("ik_chart", fit=True), "ik_bottles": B.M("ik_bottles", scale=0.8),
    "ik_drawings": B.M("ik_drawings", fit=True),
    "ik_wall_cream": B.M("ik_plaster", (0.95, 0.9, 0.78), 3.6), "ik_wall_mint": B.M("ik_plaster", (0.7, 0.86, 0.78), 3.6),
    "ik_wain": B.M("paint", (0.45, 0.55, 0.5), 2), "ik_wain_school": B.M("paint", (0.55, 0.4, 0.3), 2),
    "ik_wood": B.M("planks", (0.8, 0.6, 0.42), 1.2), "ik_wood_dark": B.M("planks", (0.45, 0.3, 0.2), 1.2),
    "ik_steel": B.M("metal", (0.8, 0.82, 0.85), 1), "ik_green": B.M("plain", (0.2, 0.4, 0.3), 1),
    "ik_beige": B.M("plain", (0.78, 0.72, 0.6), 1), "ik_blue": B.M("fabric", (0.55, 0.7, 0.85), 1),
    "ik_curtain": B.M("fabric", (0.6, 0.78, 0.8), 0.8), "ik_black": B.M("plain", (0.05, 0.05, 0.05), 1),
    "ik_lamp": B.M("plain", (0.95, 0.97, 1.0), 1, emit=1.6), "ik_lamp_dead": B.M("plain", (0.6, 0.62, 0.6), 1),
    "ik_brass": B.M("plain", (0.75, 0.58, 0.25), 1, rough=0.35), "ik_red": B.M("plain", (0.6, 0.1, 0.08), 1),
    "ik_flame": B.M("plain", (1.0, 0.7, 0.3), 1, emit=3.0), "ik_velvet": B.M("fabric", (0.45, 0.08, 0.1), 0.8),
    "ik_rail": B.M("metal", (0.6, 0.6, 0.62), 1),
})


# ============================================================== structure

class _On:
    """Temporarily add geometry to another node (created on first use): with _On(m, "stairs-colonly"): ..."""

    def __init__(self, m, name, parent=None):
        self.m, self.name, self.parent = m, name, parent

    def __enter__(self):
        self.prev = self.m.cur
        if any(nd["name"] == self.name for nd in self.m.nodes):
            self.m.use(self.name)
        else:
            self.m.node(self.name, self.parent)
        return self.m

    def __exit__(self, *exc):
        self.m.cur = self.prev


def partition(m, mat, a, b, y0, h, doors=(), t=0.15, frame="ik_wood", leaf="door", trim=None, swing=-1):
    """Straight wall from a=(x, z) to b=(x, z) (axis aligned), floor at y0, h tall, with door openings:
    doors = [(centre along the wall from a, width, height, ajar_deg or None)]. Frames + lintels, an open leaf
    swung to the `swing` side (-1 / +1 across the wall; dressing, never blocking), and an optional skirting /
    dado trim material on both faces."""
    ax, az = a
    bx, bz = b
    along_x = abs(bx - ax) > abs(bz - az)
    L = abs(bx - ax) if along_x else abs(bz - az)
    sgn = 1 if (bx - ax if along_x else bz - az) > 0 else -1
    cuts = sorted((c - w / 2, c + w / 2, dh, ajar) for c, w, dh, ajar in doors)

    def seg(u0, u1, v0, v1, material=mat, thick=t):
        if u1 - u0 < 0.01 or v1 - v0 < 0.01:
            return
        u = (u0 + u1) / 2 * sgn
        if along_x:
            m.box(material, (u1 - u0, v1 - v0, thick), (ax + u, y0 + (v0 + v1) / 2, az))
        else:
            m.box(material, (thick, v1 - v0, u1 - u0), (ax, y0 + (v0 + v1) / 2, az + u))

    u = 0.0
    for c0, c1, dh, _ in cuts:
        seg(u, c0, 0, h)
        seg(c0, c1, dh, h)  # lintel
        u = c1
    seg(u, L, 0, h)
    for c0, c1, dh, ajar in cuts:  # frames (proud of both faces) + leaf
        for cu in (c0, c1):
            seg(cu - 0.05, cu + 0.05, 0, dh + 0.05, frame, t + 0.06)
        seg(c0 - 0.05, c1 + 0.05, dh, dh + 0.1, frame, t + 0.06)
        if ajar is not None and leaf:
            w = c1 - c0
            hinge = c0 * sgn
            ang = math.radians(ajar)
            with _On(m, "ajar_leaves"):  # (build_assets PASSABLE_NODES: no auto collision for dressing)
                if along_x:
                    p = (ax + hinge + math.cos(ang) * w / 2 * sgn, y0 + dh / 2, az + swing * math.sin(ang) * w / 2)
                    m.box(leaf, (w - 0.04, dh - 0.02, 0.04), p, (0, -ajar * sgn * swing, 0))
                else:
                    p = (ax + swing * math.sin(ang) * w / 2, y0 + dh / 2, az + hinge + math.cos(ang) * w / 2 * sgn)
                    m.box(leaf, (0.04, dh - 0.02, w - 0.04), p, (0, ajar * sgn * swing, 0))
    if trim:
        for v0, v1 in ((0, 0.12), (0.95, 1.02)):  # skirting, dado rail
            u = 0.0
            for c0, c1, _, _ in cuts:
                seg(u, c0, v0, v1, trim, t + 0.03)
                u = c1
            seg(u, L, v0, v1, trim, t + 0.03)


def slab(m, mat, x0, z0, x1, z1, y, t=0.2, hole=None):
    """Floor / ceiling slab, top at y, with an optional rectangular stairwell hole (hx0, hz0, hx1, hz1)."""
    rects = [(x0, z0, x1, z1)]
    if hole:
        hx0, hz0, hx1, hz1 = hole
        rects = [(x0, z0, x1, hz0), (x0, hz1, x1, z1), (x0, hz0, hx0, hz1), (hx1, hz0, x1, hz1)]
    for a0, b0, a1, b1 in rects:
        if a1 - a0 > 0.01 and b1 - b0 > 0.01:
            m.box(mat, (a1 - a0, t, b1 - b0), ((a0 + a1) / 2, y - t / 2, (b0 + b1) / 2))


def stairs(m, pos, yaw, width, run, rise, n=None, mat="concrete", tread="ik_lino", rail="ik_rail", walls=(True, True),
           block=(False, False)):
    """Flight climbing toward local -Z from pos (bottom front edge, floor level) by `rise` over `run`. Visible
    treads + risers + stringers on the current node; the walkable ramp in "stairs-colonly"; handrails on the
    sides listed in walls=(left, right) (left = -X); block=(left, right) closes an open side with an invisible
    wall so nobody walks in under the flight (or off its edge)."""
    n = n or max(int(rise / 0.18 + 0.5), 2)
    r, d = rise / n, run / n
    with m.push(pos, (0, yaw, 0)):
        for i in range(n):
            y = r * (i + 1)
            m.box(mat, (width, r, d), (0, y - r / 2, -d * (i + 0.5)))  # riser block
            m.box(tread, (width + 0.02, 0.03, d + 0.03), (0, y + 0.012, -d * (i + 0.5)))  # nosing tread
            if i:
                m.box(mat, (width, y - r, d), (0, (y - r) / 2, -d * (i + 0.5)))  # solid under
        ang = math.degrees(math.atan2(rise, run))
        L = math.hypot(rise, run)
        for sx, on in ((-1, walls[0]), (1, walls[1])):
            m.box(mat, (0.08, 0.3, L), (sx * (width / 2 + 0.04), rise / 2 + 0.12, -run / 2), (ang, 0, 0))
            if on:
                a = (sx * (width / 2 - 0.05), 0.0, 0.0)
                b = (sx * (width / 2 - 0.05), rise, -run)
                _rail(m, rail, a, b, 0.9, 4)
        with _On(m, "stairs-colonly"):
            m.box("concrete", (width, 0.1, L + 0.05), (0, rise / 2 - 0.05, -run / 2), (ang, 0, 0))
            for sx, on in ((-1, block[0]), (1, block[1])):
                if on:  # from a step in to the top, a rail's height above the treads
                    m.box("concrete", (0.05, rise + 1.0, run - 0.5), (sx * (width / 2 + 0.03), (rise + 1.0) / 2,
                                                                      -run / 2 - 0.25))


def _rail(m, mat, a, b, h, posts):
    top = [(p[0], p[1] + h, p[2]) for p in (a, b)]
    _tube(m, mat, top[0], top[1], 0.025)
    for i in range(posts + 1):
        t = i / posts
        p = tuple(a[k] + (b[k] - a[k]) * t for k in range(3))
        m.box(mat, (0.03, h, 0.03), (p[0], p[1] + h / 2, p[2]))


def _tube(m, mat, a, b, r):
    d = [b[i] - a[i] for i in range(3)]
    L = math.sqrt(sum(v * v for v in d))
    rx = math.degrees(math.acos(max(-1.0, min(1.0, d[1] / L))))
    ry = math.degrees(math.atan2(d[0], d[2]))
    m.cyl(mat, r, r, L, a, (rx, ry, 0), seg=5)


def guard(m, mat, pts, y, h=1.0):
    """Railing along a polyline of (x, z) points at floor height y (stairwell edges, galleries)."""
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        L = math.hypot(bx - ax, bz - az)
        _rail(m, mat, (ax, y, az), (bx, y, bz), h, max(int(L / 0.9), 1))
        mid = ((ax + bx) / 2, y + h * 0.5, (az + bz) / 2)
        m.box(mat, (abs(bx - ax) + 0.02 if abs(bx - ax) > 0.01 else 0.02, 0.02, abs(bz - az) + 0.02 if abs(bz - az) > 0.01 else 0.02), mid)


def inner_windows(m, mat, x0, x1, z, y, xs, ww, wh, face=1):
    """Glazing + sill on the inside face of an outer wall (the outside panes only read from outside)."""
    for x in xs:
        if x0 < x < x1:
            m.box(mat, (ww, wh, 0.02), (x, y, z + face * 0.035))
            m.box("ik_wood", (ww + 0.12, 0.05, 0.16), (x, y - wh / 2 - 0.03, z + face * 0.1))
            m.box("ik_rail", (0.04, wh, 0.03), (x, y, z + face * 0.045))


def lining(m, mat, hw, hd, y0, h, door=None, trim=None):
    """Plaster the inside faces of a building's outer walls (a storey from y0, h tall), with a gap for the
    front door (x centre, width, height) in the +Z wall."""
    e = 0.012
    doors = [(hw + door[0], door[1], door[2], None)] if door else ()
    partition(m, mat, (-hw, hd - e), (hw, hd - e), y0, h, doors, t=0.02, leaf=None, trim=trim)
    partition(m, mat, (-hw, -hd + e), (hw, -hd + e), y0, h, t=0.02, trim=trim)
    for x in (-hw + e, hw - e):
        partition(m, mat, (x, -hd), (x, hd), y0, h, t=0.02, trim=trim)


# ============================================================== furniture

def student_desk(m, x, z, yaw=0, tipped=False):
    """Desk + chair pair, the pupil faces local -Z (yaw turns the pair)."""
    with m.push((x, 0, z), (0, yaw, 0)):
        with m.push((0, 0, 0), (0, 0, 80) if tipped else (0, 0, 0)):
            m.box("ik_wood", (0.65, 0.04, 0.48), (0, 0.72, 0))
            m.box("ik_steel", (0.6, 0.12, 0.42), (0, 0.63, 0))  # book tray
            for lx in (-0.29, 0.29):
                m.box("ik_steel", (0.03, 0.7, 0.03), (lx, 0.35, -0.2))
                m.box("ik_steel", (0.03, 0.7, 0.03), (lx, 0.35, 0.2))
        m.box("ik_wood", (0.4, 0.035, 0.38), (0, 0.44, 0.52))
        m.box("ik_wood", (0.4, 0.28, 0.03), (0, 0.72, 0.72))
        for lx in (-0.17, 0.17):
            for lz in (0.36, 0.68):
                m.box("ik_steel", (0.025, 0.44, 0.025), (lx, 0.22, lz))


def teacher_desk(m, x, z, yaw=0):
    with m.push((x, 0, z), (0, yaw, 0)):
        m.box("ik_wood_dark", (1.5, 0.05, 0.75), (0, 0.76, 0))
        m.box("ik_wood_dark", (0.45, 0.72, 0.7), (-0.5, 0.37, 0))  # drawer pedestal
        m.box("ik_wood_dark", (0.05, 0.72, 0.7), (0.72, 0.37, 0))
        m.box("ik_wood_dark", (1.45, 0.4, 0.03), (0, 0.5, 0.33))  # modesty panel
        for y in (0.2, 0.42, 0.62):
            m.box("ik_brass", (0.1, 0.02, 0.02), (-0.5, y, -0.37))
        m.box("white", (0.3, 0.02, 0.22), (0.3, 0.8, -0.05), (0, 12, 0))  # papers
        m.box("int_books", (0.25, 0.12, 0.18), (-0.4, 0.84, 0.1))
        m.box("ik_red", (0.08, 0.1, 0.08), (0.55, 0.84, 0.15))  # an apple, of course
    chair(m, x, z, yaw, mat="ik_wood_dark", back=0.35)


def chair(m, x, z, yaw=0, mat="ik_wood", back=0.3):
    """Chair facing local +Z... sitter faces -Z (back toward +Z)."""
    with m.push((x, 0, z), (0, yaw, 0)):
        m.box(mat, (0.42, 0.04, 0.42), (0, 0.45, back))
        m.box(mat, (0.42, 0.42, 0.03), (0, 0.7, back + 0.2))
        for lx in (-0.18, 0.18):
            for lz in (-0.18, 0.18):
                m.box("ik_steel", (0.025, 0.45, 0.025), (lx, 0.225, back + lz))


def blackboard(m, x, y, z, yaw, w=3.6):
    """Wall board (faces local +Z after yaw), chalk ledge, and a map pulled down beside it."""
    with m.push((x, y, z), (0, yaw, 0)):
        m.box("ik_wood", (w + 0.12, 1.32, 0.04), (0, 0, 0.02))
        m.box("ik_chalk", (w, 1.2, 0.02), (0, 0, 0.05))
        m.box("ik_wood", (w, 0.04, 0.08), (0, -0.62, 0.08))
        for k in range(4):
            m.box("white", (0.08, 0.015, 0.015), (-w / 2 + 0.3 + k * 0.15, -0.59, 0.09))
        m.box("ik_black", (0.14, 0.05, 0.06), (w / 2 - 0.3, -0.58, 0.09))  # eraser
        m.box("ik_map", (1.0, 0.8, 0.01), (w / 2 + 0.7, 0.1, 0.03))
        m.cyl("ik_wood", 0.02, 0.02, 1.05, (w / 2 + 0.18, 0.52, 0.04), (0, 0, 90), seg=5)


def board(m, mat, x, y, z, yaw, w, h, frame="ik_wood"):
    """Framed wall panel (notice board, poster, chart) facing local +Z after yaw."""
    with m.push((x, y, z), (0, yaw, 0)):
        m.box(frame, (w + 0.06, h + 0.06, 0.03), (0, 0, 0.015))
        m.box(mat, (w, h, 0.01), (0, 0, 0.035))


def clock(m, x, y, z, yaw):
    with m.push((x, y, z), (0, yaw, 0)):
        m.cyl("ik_black", 0.17, 0.17, 0.05, (0, 0, 0), (90, 0, 0), seg=12)
        m.cyl("civ_clock", 0.15, 0.15, 0.01, (0, 0, 0.05), (90, 0, 0), seg=12)


def lamp(m, x, y, z, w=1.2, lit=True):
    """Ceiling fluorescent troffer (bottom face at y)."""
    m.box("ik_steel", (w + 0.1, 0.08, 0.36), (x, y + 0.04, z))
    m.box("ik_lamp" if lit else "ik_lamp_dead", (w, 0.02, 0.28), (x, y - 0.01, z))


def exit_sign(m, x, y, z, yaw):
    with m.push((x, y, z), (0, yaw, 0)):
        m.box("white", (0.42, 0.18, 0.08), (0, 0, 0.04))
        m.box("ik_exit", (0.38, 0.14, 0.01), (0, 0, 0.085))


def extinguisher(m, x, z, yaw, y=0.9):
    with m.push((x, 0, z), (0, yaw, 0)):
        m.box("white", (0.35, 0.3, 0.02), (0, y + 0.55, 0.01))
        m.cyl("ik_red", 0.08, 0.08, 0.5, (0, y, 0.12), seg=8)
        m.cyl("ik_black", 0.025, 0.025, 0.08, (0, y + 0.5, 0.12), seg=5)
        m.box("ik_black", (0.03, 0.03, 0.12), (0.04, y + 0.56, 0.12))


def radiator(m, x, z, yaw, w=1.0):
    with m.push((x, 0, z), (0, yaw, 0)):
        for k in range(int(w / 0.08)):
            m.box("ik_beige", (0.05, 0.6, 0.1), (-w / 2 + 0.04 + k * 0.08, 0.45, 0.08))
        m.box("ik_beige", (w, 0.04, 0.1), (0, 0.13, 0.08))
        m.box("ik_steel", (0.03, 0.18, 0.03), (-w / 2 - 0.03, 0.09, 0.08))


def bin_(m, x, z, mat="ik_steel"):
    m.cyl(mat, 0.16, 0.18, 0.45, (x, 0, z), seg=8)
    m.box("white", (0.1, 0.02, 0.12), (x + 0.05, 0.46, z), (0, 30, 20))


def lockers(m, x0, x1, z, yaw, h=1.9):
    """A run of steel lockers from x0 to x1 against a wall at z (doors face +Z after yaw)."""
    n = int((x1 - x0) / 0.4)
    for k in range(n):
        x = x0 + 0.2 + k * 0.4
        with m.push((x, 0, z), (0, yaw, 0)):
            m.box("locker", (0.39, h, 0.45), (0, h / 2 + 0.1, 0.225))
            m.box("ik_black", (0.3, 0.03, 0.01), (0, h - 0.1, 0.455))  # vents
            m.box("ik_black", (0.3, 0.03, 0.01), (0, h - 0.18, 0.455))
            if k % 7 == 3:
                with m.push((0.19, 0, 0.45), (0, 70, 0)):  # one hanging open
                    m.box("locker", (0.37, h - 0.1, 0.02), (-0.19, h / 2 + 0.1, 0))
    m.box("ik_beige", (x1 - x0, 0.1, 0.46), ((x0 + x1) / 2, 0.05, z))  # plinth


def shelf_unit(m, x, z, yaw, w=1.2, h=2.0, d=0.4, fill="int_books"):
    """Open shelving: uprights + 5 boards, stocked (books / bottles)."""
    with m.push((x, 0, z), (0, yaw, 0)):
        for sx in (-1, 1):
            m.box("ik_steel", (0.04, h, d), (sx * (w / 2 - 0.02), h / 2, d / 2))
        m.box("ik_steel", (w, h, 0.02), (0, h / 2, 0.01))
        for k in range(5):
            y = 0.08 + k * (h - 0.1) / 4.5
            m.box("ik_steel", (w - 0.04, 0.03, d), (0, y, d / 2))
            if k < 4:
                gap = 0.1 + 0.3 * ((k * 7) % 3) / 3
                m.box(fill, (w - 0.1 - gap, 0.3, d - 0.08), (-gap / 2, y + 0.17, d / 2))


def counter(m, x, z, yaw, w, d=0.7, h=1.05, top="ik_beige", body="ik_wood"):
    """Service counter (reception, nurses' station): the staff side is local -Z."""
    with m.push((x, 0, z), (0, yaw, 0)):
        m.box(body, (w, h - 0.05, d), (0, (h - 0.05) / 2, 0))
        m.box(top, (w + 0.06, 0.05, d + 0.1), (0, h - 0.02, 0.03))
        m.box(top, (w, 0.03, 0.4), (0, 0.76, -d / 2 - 0.18))  # desk shelf behind
        m.box("ik_black", (0.35, 0.3, 0.05), (-w / 4, h + 0.18, -0.1), (-10, 0, 0))  # monitor
        m.box("ik_black", (0.08, 0.15, 0.08), (-w / 4, h + 0.03, -0.1))
        m.box("white", (0.25, 0.02, 0.3), (w / 4, h + 0.02, 0.05), (0, 20, 0))
        m.box("ik_black", (0.2, 0.08, 0.15), (w / 4 + 0.35, h + 0.05, -0.05))  # phone


def chair_row(m, x0, x1, z, yaw, mat="ik_blue", gap=0.55):
    """Linked waiting-room seats on a steel beam; the sitters face +Z after yaw."""
    n = int((x1 - x0) / gap)
    with m.push(((x0 + x1) / 2, 0, z), (0, yaw, 0)):
        m.box("ik_steel", (n * gap, 0.05, 0.06), (0, 0.3, 0))
        for k in range(n):
            x = -n * gap / 2 + gap * (k + 0.5)
            m.box(mat, (gap - 0.06, 0.07, 0.45), (x, 0.44, 0.05))
            m.box(mat, (gap - 0.06, 0.45, 0.06), (x, 0.72, -0.18), (-8, 0, 0))
        for x in (-n * gap / 2 + 0.1, n * gap / 2 - 0.1):
            m.box("ik_steel", (0.05, 0.3, 0.4), (x, 0.15, 0))


def curtain(m, x, z0, z1, top=2.3, drawn=0.6, along_z=True):
    """Hospital bay curtain on a ceiling track: drawn = fraction of the track the folds cover."""
    L = abs(z1 - z0)
    c = (z0 + z1) / 2
    if along_z:
        m.box("ik_rail", (0.04, 0.03, L), (x, top + 0.1, c))
        with _On(m, "curtain_cloth"):  # (build_assets PASSABLE_NODES: cloth is pushed through, never a wall)
            m.box("ik_curtain", (0.03, top - 0.25, L * drawn), (x, 0.25 + (top - 0.25) / 2, min(z0, z1) + L * drawn / 2))
            for k in range(int(L * drawn / 0.2)):
                m.box("ik_curtain", (0.08, top - 0.3, 0.05), (x + (0.03 if k % 2 else -0.03), 0.28 + (top - 0.3) / 2,
                                                              min(z0, z1) + 0.1 + k * 0.2))
    else:
        m.box("ik_rail", (L, 0.03, 0.04), (c, top + 0.1, x))
        with _On(m, "curtain_cloth"):
            m.box("ik_curtain", (L * drawn, top - 0.25, 0.03), (min(z0, z1) + L * drawn / 2, 0.25 + (top - 0.25) / 2, x))


def bedside(m, x, z, yaw):
    """Bedside cabinet + the monitor on its pole."""
    with m.push((x, 0, z), (0, yaw, 0)):
        m.box("ik_beige", (0.45, 0.8, 0.45), (0, 0.4, 0))
        m.box("ik_steel", (0.1, 0.02, 0.35), (0, 0.55, 0.23))
        m.box("white", (0.08, 0.14, 0.08), (0.1, 0.87, 0.05))  # cup
        m.cyl("ik_steel", 0.02, 0.02, 1.6, (-0.3, 0, 0), seg=5)
        m.box("ik_black", (0.3, 0.25, 0.12), (-0.3, 1.45, 0.05))
        m.box("ik_green", (0.24, 0.16, 0.01), (-0.3, 1.46, 0.115))


def headwall(m, x, z, yaw):
    """Medical gas / light panel over a bed head."""
    with m.push((x, 0, z), (0, yaw, 0)):
        m.box("ik_beige", (1.4, 0.25, 0.08), (0, 1.55, 0.04))
        for k, col in enumerate(("ik_green", "white", "ik_blue")):
            m.cyl(col, 0.035, 0.035, 0.04, (-0.4 + k * 0.15, 1.55, 0.1), (90, 0, 0), seg=6)
        m.box("ik_lamp", (0.5, 0.05, 0.05), (0.35, 1.62, 0.09))


def sink(m, x, z, yaw):
    with m.push((x, 0, z), (0, yaw, 0)):
        m.box("white", (0.5, 0.18, 0.4), (0, 0.82, 0.2))
        m.box("ik_steel", (0.03, 0.2, 0.03), (0, 0.98, 0.05))
        m.box("ik_steel", (0.03, 0.03, 0.12), (0, 1.08, 0.1))
        m.box("ik_steel", (0.4, 0.5, 0.02), (0, 1.4, 0.01))  # mirror
        m.box("ik_steel", (0.05, 0.7, 0.05), (0, 0.35, 0.15))


def pew(m, x, z, w, facing=-1, kneeler=True):
    """Church pew: the congregation faces `facing` along Z (-1 = toward -Z). Seat, backrest on the far side,
    book ledge on the back, kneeler under the seat in front, carved ends."""
    s = -facing  # backrest side
    with m.push((x, 0, z)):
        m.box("ik_wood_dark", (w, 0.06, 0.45), (0, 0.45, 0))
        m.box("ik_wood_dark", (w, 0.55, 0.05), (0, 0.78, s * 0.24), (s * -8, 0, 0))
        m.box("ik_wood_dark", (w, 0.04, 0.16), (0, 1.02, s * 0.3))  # top rail / book ledge
        m.box("int_books", (0.22, 0.05, 0.15), (-w / 4, 1.07, s * 0.3))
        for sx in (-1, 1):
            m.box("ik_wood_dark", (0.07, 1.0, 0.52), (sx * (w / 2 - 0.035), 0.5, s * 0.04))
            m.cyl("ik_wood_dark", 0.06, 0.06, 0.08, (sx * (w / 2 - 0.035), 1.0, s * 0.18), (0, 0, 90), seg=6)
        if kneeler:  # dressing only: nothing ankle-high to snag on between the rows
            with _On(m, "detail"):
                m.box("ik_velvet", (w - 0.2, 0.1, 0.2), (0, 0.1, -s * 0.52))
