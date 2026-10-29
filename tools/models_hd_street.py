"""HD street pack: SA-era cars (car_wreck, ambulance) and street furniture (lamp posts, utility pole, bench).
Replaces the core versions in build_assets.py (same model names). Cars point along +X; exports hs_* helpers
used by models_exterior.py (burnt car, props)."""
import math
import random

import build_assets as B

mix, mul = B.mix, B.mul


# ============================================================== textures

def _paint(base):
    def fn(x, y, a, b, r):
        c = mul(base, 0.82 + 0.25 * a + 0.04 * r)
        if b > 0.66:  # rust blooms
            c = mix(c, mul((0.36, 0.17, 0.07), 0.6 + 0.7 * a), min(1.0, (b - 0.66) * 6))
        elif b > 0.62:
            c = mul(c, 0.8)  # bubbling paint edge
        if r < 0.015:
            c = mul(c, 0.75)  # grime specks
        return c
    return fn


def t_hs_plate(x, y, a, b, r):
    if y < 5 or y > 58 or x < 3 or x > 60:
        return (0.2, 0.2, 0.2)
    c = mul((0.78, 0.76, 0.62), 0.85 + 0.2 * a)
    if 16 < y < 46 and 8 < x < 56 and (x - 8) % 8 < 5 and ((y - 16) % 15 < 3 or (x - 8) % 8 < 2):
        c = (0.12, 0.14, 0.25)  # stamped characters
    return mul(c, 0.8) if b > 0.6 else c


def t_hs_crack(x, y, a, b, r):
    """Shattered-glass overlay (alpha): radial cracks + a punched hole around (40, 26)."""
    dx, dy = x - 40, y - 26
    d = math.hypot(dx, dy)
    if d < 6 + 3 * a:
        return (0.02, 0.02, 0.02, 1.0)
    ang = math.atan2(dy, dx)
    k = (ang / (2 * math.pi) * 11 + 0.3 * a) % 1.0
    ring = abs((d + 4 * b) % 9 - 4.5) < 0.6 and d < 30
    if min(k, 1 - k) < 0.045 or ring:
        return (0.7, 0.72, 0.72, 1.0)
    return (0, 0, 0, 0.0)


def t_hs_soot(x, y, a, b, r):
    return mul((0.07, 0.065, 0.06), 0.6 + 0.8 * a + 0.2 * r)


def t_hs_lens(x, y, a, b, r):
    return mul((0.75, 0.72, 0.6), 0.7 + 0.3 * a)


B.TEXTURES.update({
    "hs_paint_sedan": _paint((0.3, 0.42, 0.36)), "hs_paint_amb": _paint((0.7, 0.7, 0.66)),
    "hs_paint_wagon": _paint((0.42, 0.33, 0.2)),
    "hs_plate": t_hs_plate, "hs_crack": t_hs_crack, "hs_soot": t_hs_soot, "hs_lens": t_hs_lens,
})
B.ALPHA_TEX.add("hs_crack")
B.MATS.update({
    "hs_sedan": B.M("hs_paint_sedan", scale=1.6, rough=0.6), "hs_amb": B.M("hs_paint_amb", scale=1.6, rough=0.6),
    "hs_wagon": B.M("hs_paint_wagon", scale=1.6, rough=0.6),
    "hs_chrome": B.M("metal", (1.3, 1.3, 1.35), 1.0, rough=0.35), "hs_dark": B.M("plain", (0.03, 0.03, 0.03), 1),
    "hs_tire": B.M("plain", (0.07, 0.07, 0.07), 1, rough=0.9), "hs_plate": B.M("hs_plate", fit=True),
    "hs_crack": B.M("hs_crack", fit=True), "hs_soot": B.M("hs_soot", scale=1.5),
    "hs_lens": B.M("hs_lens", scale=0.3, rough=0.2), "hs_amber": B.M("plain", (0.6, 0.3, 0.05), 1, rough=0.3),
    "hs_seat": B.M("fabric", (0.35, 0.3, 0.26)), "hs_pole": B.M("metal", (0.85, 0.88, 0.85), 1.5),
    "hs_wood": B.M("planks", (0.6, 0.55, 0.5), 1.0), "hs_burnt": B.M("rust", (0.45, 0.38, 0.33), 1.0),
})
B.MATS["hs_crack"]["alpha"] = True


# ============================================================== smooth helpers

def _sp(c, p):
    return math.copysign(abs(c) ** (2 / p), c)


def xloft(m, mat, stations, seg=16, power=5.0, uv=None):
    """Loft along +X. stations: (x, y0, y1, w0, w1): bottom/top heights and half-widths at bottom/top
    (w1 < w0 gives tumblehome). y0 == y1 and w == 0 closes an end."""
    if stations[0][0] < stations[-1][0]:
        stations = stations[::-1]  # rings must run toward -X for outward normals
    rows = []
    for x, y0, y1, w0, w1 in stations:
        yc, hh = (y0 + y1) / 2, (y1 - y0) / 2
        row = []
        for j in range(seg):
            a = 2 * math.pi * (j + 0.5) / seg
            cy, cz = _sp(math.cos(a), power), _sp(-math.sin(a), power)
            w = w0 + (w1 - w0) * (cy + 1) / 2
            row.append((x, yc + hh * cy, w * cz))
        rows.append(row)
    m.surface(mat, rows, wrap=True, uv=uv)


def _basis(t):
    t = B.v_norm(t)
    ref = (0, 1, 0) if abs(t[1]) < 0.9 else (1, 0, 0)
    u = B.v_norm(B.v_cross(ref, t))
    v = B.v_cross(t, u)
    return u, v


def tube(m, mat, pts, r, seg=6, cap=True):
    """Smooth tube through a polyline. r: float or per-point list. cap closes both ends."""
    rs = r if isinstance(r, (list, tuple)) else [r] * len(pts)
    rows, n = [], len(pts)
    for i, p in enumerate(pts):
        t = B.v_sub(pts[min(i + 1, n - 1)], pts[max(i - 1, 0)])
        u, v = _basis(t)
        rows.append([B.v_add(p, B.v_add(B.mul(u, rs[i] * math.cos(2 * math.pi * j / seg)),
                                        B.mul(v, rs[i] * math.sin(2 * math.pi * j / seg)))) for j in range(seg)])
    if cap:
        rows = [[pts[0]] * seg] + rows + [[pts[-1]] * seg]
    m.surface(mat, rows, wrap=True)


def arc(c, r, a0, a1, n, plane="xy", z=0.0):
    """Points on a circular arc (degrees) in the XY plane at depth z (or 'zy' plane at x=z)."""
    out = []
    for k in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        if plane == "xy":
            out.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a), z))
        else:
            out.append((z, c[1] + r * math.sin(a), c[0] + r * math.cos(a)))
    return out


def bezier(p0, p1, p2, n):
    return [tuple((1 - t) ** 2 * p0[i] + 2 * (1 - t) * t * p1[i] + t * t * p2[i] for i in range(3))
            for t in (k / n for k in range(n + 1))]


def wheel(m, x, y, z, r=0.33, w=0.22, rim="hs_chrome", tire=True, spokes=5, outward=1):
    """Tire + dished rim with spokes and hubcap; axis along Z, outer face toward outward*Z."""
    with m.push((x, y, z), (90 if outward > 0 else -90, 0, 0)):
        hw = w / 2
        if tire:
            m.lathe("hs_tire", [(r * 0.62, -hw), (r * 0.9, -hw * 1.05), (r * 0.98, -hw * 0.8), (r, -hw * 0.3),
                                (r, hw * 0.3), (r * 0.98, hw * 0.8), (r * 0.9, hw * 1.05), (r * 0.62, hw)], seg=12)
        rr = r * 0.62
        if rim is None:
            return
        m.lathe(rim, [(rr, hw * 0.9), (rr * 0.92, hw * 0.55), (rr * 0.45, hw * 0.4), (rr * 0.3, hw * 0.75),
                      (0, hw * 0.85)], seg=8)
        m.lathe("hs_dark", [(rr * 1.01, -hw * 0.9), (rr * 1.01, hw * 0.9)], seg=8)
        for k in range(spokes):
            a = 360 * k / spokes
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            tube(m, rim, [(ca * rr * 0.3, hw * 0.62, sa * rr * 0.3), (ca * rr * 0.9, hw * 0.5, sa * rr * 0.9)],
                 0.018, seg=4, cap=False)


def lens(m, mat, size, pos, face="+x"):
    """Rounded light lens: a flat superellipse pad facing +X or -X (or +z/-z)."""
    w, h = size if face[1] == "z" else size[::-1]
    rot = {"+x": (0, 0, -90), "-x": (0, 0, 90), "+z": (90, 0, 0), "-z": (-90, 0, 0)}[face]
    m.loft(mat, [(0, w / 2, h / 2), (0.02, w / 2, h / 2), (0.03, w / 2 * 0.8, h / 2 * 0.7), (0.031, 0, 0)],
           pos, rot, seg=8, power=4)


def body_stations(keys, xs, arches, bottom=0.3):
    """Sample piecewise-linear keys [(x, top, w)] at xs; body bottom rises into wheel arches."""
    out = []
    for x in xs:
        for (xa, ta, wa), (xb, tb, wb) in zip(keys, keys[1:]):
            if xa >= x >= xb:
                k = (x - xa) / (xb - xa) if xb != xa else 0
                top, w = ta + (tb - ta) * k, wa + (wb - wa) * k
                break
        y0 = bottom
        for ax, ay, ar in arches:
            if abs(x - ax) < ar:
                y0 = max(y0, ay + math.sqrt(ar * ar - (x - ax) ** 2))
        out.append((x, y0, top, w, w * 0.97))
    return out


def arch_xs(x0, x1, step, arches):
    xs = set(round(x0 + (x1 - x0) * k / round((x0 - x1) / step), 4) for k in range(round((x0 - x1) / step) + 1))
    for ax, ay, ar in arches:
        for k in range(9):
            xs.add(round(ax + ar * math.cos(math.pi * k / 8) * 0.999, 4))
        xs.add(round(ax + ar * 1.02, 4))
        xs.add(round(ax - ar * 1.02, 4))
    return sorted(xs, reverse=True)


# ============================================================== sedan

def body_col(m, spec, burnt=False):
    """Collision for a sedan / wagon built by sedan() with the same spec, into the current ("-col") node: the lower
    body from just over the road to the belt, out to the bumpers' tips and the flanks' trim, and the greenhouse
    (full height under the roof, half height over the windshield / rear glass slopes), so nobody walks into the
    hood, a bumper or a door. Boxes, so they stand proud of the curves here and there: a "-colonly" node."""
    drop = spec["wr"] * 0.38 if burnt else 0.0
    L, hw, belt, ry = spec["L"], spec["hw"], spec["belt"] - drop, spec["roof_y"] - drop
    lo = 0.12
    m.box("hs_dark", (L + 0.2, belt + 0.02 - lo, 2 * hw + 0.1), (0, (belt + 0.02 + lo) / 2, 0))
    cab = spec["cabin"]
    roof = [x for x, top in cab if top >= spec["roof_y"] - 0.01]
    xf, xr = roof[0], roof[-1]
    gw = 2 * hw * 0.93
    m.box("hs_dark", (xf - xr, ry + 0.03 - belt, gw), ((xf + xr) / 2, (ry + 0.03 + belt) / 2, 0))
    mid = belt + (ry - belt) / 2
    for a, b in ((cab[0][0], xf), (xr, cab[-1][0])):
        if abs(a - b) > 0.05:
            m.box("hs_dark", (abs(a - b), mid - belt, gw), ((a + b) / 2, (mid + belt) / 2, 0))


def sedan(m, paint, spec, rng, burnt=False):
    """Boxy late-70s sedan / wagon. spec keys: L, hw, wx, wr, keys (body profile), cabin (x, top) list,
    roof_w. Adds geometry to the current node. burnt: tires gone, sits on its rims, windows blown out."""
    with m.push((0, -spec["wr"] * 0.38 if burnt else 0, 0)):
        _sedan(m, paint, spec, rng, burnt)


def _sedan(m, paint, spec, rng, burnt):
    L, hw, wr = spec["L"], spec["hw"], spec["wr"]
    wy = wr
    ch = "hs_burnt" if burnt else "hs_chrome"
    arches = [(x, wy, wr + 0.1) for x in spec["wx"]]
    fx, rx = L / 2, -L / 2
    bot = wy - 0.03
    st = body_stations(spec["keys"], arch_xs(fx - 0.06, rx + 0.06, 0.3, arches), arches, bot)
    x0, y0a, y1a, w0a, w1a = st[0]
    x1, y0b, y1b, w0b, w1b = st[-1]
    st = ([(fx + 0.001, y0a + 0.12, y1a - 0.08, 0, 0), (fx, y0a + 0.1, y1a - 0.06, w0a * 0.92, w1a * 0.92)] + st +
          [(rx, y0b + 0.1, y1b - 0.06, w0b * 0.92, w1b * 0.92), (rx - 0.001, y0b + 0.12, y1b - 0.08, 0, 0)])
    xloft(m, paint, st, seg=14, power=6)
    belt = spec["belt"]

    # greenhouse: glass (or soot when burnt out) loft, painted roof skin + pillars on top
    cab = spec["cabin"]  # [(x, top)] front to back
    rw = spec["roof_w"]
    gl = "hs_soot" if burnt else "glass"
    cst = [(x, belt - 0.12, top, hw * 0.93, rw) for x, top in cab]
    cst = [(cab[0][0] + 0.001, belt - 0.12, belt - 0.1, 0, 0)] + cst + [(cab[-1][0] - 0.001, belt - 0.12, belt - 0.1, 0, 0)]
    xloft(m, gl, cst, seg=14, power=5)
    roof = [(x, top) for x, top in cab if top >= spec["roof_y"] - 0.01]
    rf = [(roof[0][0] + 0.12, spec["roof_y"] - 0.06, spec["roof_y"] - 0.05, 0, 0)]
    rf += [(x, spec["roof_y"] - 0.06, spec["roof_y"] + 0.025, rw * 1.03, rw * 1.0) for x, _ in roof]
    rf += [(roof[-1][0] - 0.12, spec["roof_y"] - 0.06, spec["roof_y"] - 0.05, 0, 0)]
    xloft(m, paint, [(roof[0][0] + 0.12, rf[1][1], rf[1][2], rw * 0.96, rw * 0.9)] + rf[1:-1] +
          [(roof[-1][0] - 0.1, rf[1][1], rf[1][2], rw * 0.96, rw * 0.9)], seg=14, power=6)
    ry = spec["roof_y"]
    wb = hw * 0.93  # glass half-width at belt
    xa, xr = cab[0][0], cab[-1][0]
    xf_roof, xr_roof = roof[0][0], roof[-1][0]
    for s in (-1, 1):
        # A pillar, B pillar(s), C pillar
        tube(m, paint, [(xa - 0.02, belt, s * wb * 0.98), (xf_roof + 0.04, ry, s * rw * 0.99)], 0.045, 5)
        for bx in spec["bpillars"]:
            wbx = wb + (rw - wb) * 0.0
            tube(m, paint, [(bx, belt, s * (wb + 0.005)), (bx, ry, s * (rw + 0.01))], 0.05, 5)
        cx = spec.get("cpillar", (xr, xr_roof))
        m.emit(paint, [(cx[0] + 0.02, belt, s * (wb + 0.01)), (cx[0] + 0.32, belt, s * (wb + 0.01)),
                       (cx[1] + 0.1, ry, s * (rw + 0.02)), (cx[1] - 0.02, ry, s * (rw + 0.02))],
               (0, belt, 0))
        # drip rail / window trim along the belt
        tube(m, ch, [(xa, belt + 0.01, s * wb), (xr, belt + 0.01, s * wb)], 0.018, 4)
    # front/back roof rails
    for x in (xf_roof, xr_roof):
        tube(m, paint, [(x, ry, -rw), (x, ry + 0.01, 0), (x, ry, rw)], 0.04, 5)

    # wheels + arch lips + dark wells
    for ax, ay, ar in arches:
        for s in (-1, 1):
            if burnt:
                wheel(m, ax, ay, s * (hw - 0.14), wr, 0.2, ch, tire=False, outward=s)
            else:
                wheel(m, ax, ay + rng.uniform(-0.03, 0.0), s * (hw - 0.13), wr, 0.22, outward=s)
            tube(m, paint, arc((ax, ay), ar + 0.015, 5, 175, 8, z=s * (hw - 0.02)), 0.035, 4, cap=False)
            with m.push((ax, ay, s * (hw - 0.3)), (0, 0 if s > 0 else 180, 0)):
                pts = arc((0, 0), ar, 0, 180, 8)
                m.emit("hs_dark", pts, (0, 0, -1))

    # bumpers (chrome, rounded), grille, lights, plate
    fb, rb = fx + 0.06, rx - 0.06
    by = bot + 0.18
    for x, sgn in ((fb, 1), (rb, -1)):
        xloft(m, ch, [(x - sgn * 0.12, by - 0.08, by + 0.08, 0, 0), (x - sgn * 0.1, by - 0.09, by + 0.09, hw + 0.04, hw + 0.04),
                               (x + sgn * 0.02, by - 0.08, by + 0.08, hw + 0.03, hw + 0.03),
                               (x + sgn * 0.03, by - 0.06, by + 0.06, 0, 0)][::sgn], seg=12, power=4)
    ft = spec["keys"][0][1]
    gy0, gy1 = by + 0.1, ft - 0.08
    m.box("hs_dark", (0.04, gy1 - gy0, hw * 1.1), (fx + 0.005, (gy0 + gy1) / 2, 0))
    for k in range(4):
        m.box(ch, (0.03, 0.018, hw * 0.9), (fx + 0.025, gy0 + 0.03 + k * (gy1 - gy0 - 0.06) / 3, 0))
    m.box(ch, (0.04, gy1 - gy0 + 0.04, 0.03), (fx + 0.02, (gy0 + gy1) / 2, 0))
    lit = spec.get("lit_headlight")
    for s in (-1, 1):
        for k, off in enumerate((0.62, 0.8)):
            mat = "hs_soot" if burnt else ("bulb" if lit and s > 0 and k == 0 else "hs_lens")
            lens(m, mat, (0.14, 0.15), (fx + 0.005, (gy0 + gy1) / 2, s * hw * off), "+x")
        lens(m, "hs_soot" if burnt else "red", (0.2, 0.12), (rx - 0.005, spec["keys"][-1][1] - 0.12, s * hw * 0.72), "-x")
        lens(m, "hs_soot" if burnt else "hs_amber", (0.08, 0.12), (fx + 0.07, by, s * hw * 0.8), "+x")
    for x, sgn in ((fb + 0.035, 1), (rb - 0.035, -1)):
        m.decal("hs_soot" if burnt else "hs_plate", 0.42, 0.16, (x, by, 0), (0, 90 * sgn, 0))
    # door seams, handles, mirrors
    for s in (-1, 1):
        z = s * (hw + 0.004)
        for x in spec["seams"]:
            m.box("hs_dark", (0.012, belt - bot - 0.12, 0.01), (x, (belt + bot) / 2 + 0.03, z))
        for x in spec["seams"][:-1]:
            m.box(ch, (0.14, 0.03, 0.03), (x - 0.18, belt - 0.14, z))
        tube(m, ch, [(xa - 0.05, belt + 0.03, s * wb), (xa - 0.08, belt + 0.12, s * (hw + 0.12))], 0.015, 4)
        m.ellipsoid(paint, (0.07, 0.06, 0.05), (xa - 0.09, belt + 0.14, s * (hw + 0.14)), seg=8, rings=5)
        # chrome side trim
        ty = arches[0][1] + arches[0][2] + 0.06
        tube(m, ch, [(fx - 0.1, ty, s * (hw + 0.004)), (rx + 0.1, ty, s * (hw + 0.004))], 0.012, 4)


SEDAN = dict(L=4.4, hw=0.88, wr=0.33, wx=(1.35, -1.4), belt=0.98, roof_y=1.42, roof_w=0.74,
             keys=[(2.2, 0.86, 0.86), (1.5, 0.9, 0.88), (0.85, 0.96, 0.88), (-1.2, 0.98, 0.88), (-2.2, 0.94, 0.86)],
             cabin=[(0.85, 0.99), (0.55, 1.16), (0.22, 1.36), (0.05, 1.42), (-0.9, 1.42), (-1.12, 1.3), (-1.45, 1.0)],
             bpillars=(-0.4,), seams=(0.72, -0.4, -1.2), cpillar=(-1.35, -0.92), lit_headlight=True)


WAGON = dict(L=4.5, hw=0.87, wr=0.32, wx=(1.4, -1.35), belt=0.95, roof_y=1.38, roof_w=0.74,
             keys=[(2.25, 0.84, 0.85), (1.6, 0.88, 0.87), (0.95, 0.94, 0.87), (-2.0, 0.95, 0.87), (-2.25, 0.92, 0.85)],
             cabin=[(0.95, 0.96), (0.62, 1.14), (0.3, 1.33), (0.15, 1.38), (-1.95, 1.38), (-2.12, 1.25), (-2.2, 0.97)],
             bpillars=(-0.35, -1.25), seams=(0.8, -0.35, -1.25), cpillar=(-2.18, -1.95))


def dents(m, rng, paint, hw, n, xr=(-2.0, 2.0), yr=(0.45, 0.85)):
    """Dark crumple patches on the flanks."""
    for _ in range(n):
        s = rng.choice((-1, 1))
        x, y = rng.uniform(*xr), rng.uniform(*yr)
        m.ellipsoid("hs_soot", (rng.uniform(0.15, 0.3), rng.uniform(0.06, 0.12), 0.02), (x, y, s * (hw + 0.005)),
                    (0, 0, rng.uniform(-30, 30)), seg=8, rings=4)


def m_car_wreck():
    m = B.Model("car_wreck")
    rng = random.Random(11)
    m.node("body-colonly")  # (collision only: the boxes stand proud of the curved body)
    body_col(m, SEDAN)
    m.node("detail")
    sedan(m, "hs_sedan", SEDAN, rng)
    # shattered side window + windshield
    m.decal("hs_crack", 0.5, 0.3, (-0.75, 1.2, 0.795), (-8, 0, 0))
    m.decal("hs_crack", 0.7, 0.4, (0.4, 1.262, -0.2), (-59, 90, 0))
    return m


def m_ambulance():
    """Box-van ambulance: cab + hood at +X, square patient module behind, lightbar on the cab roof."""
    m = B.Model("ambulance")
    rng = random.Random(3)
    m.node("body-col")
    m.box("hs_dark", (4.4, 1.6, 1.9), (-0.55, 1.5, 0))
    m.box("hs_dark", (1.2, 0.5, 1.6), (2.5, 0.7, 0))
    m.node("detail")
    P, hw, wr = "hs_amb", 1.0, 0.38
    fa = [(2.55, wr, wr + 0.1)]
    ra = [(-1.55, wr, wr + 0.1)]
    # cab lower body + hood
    keys = [(3.3, 1.0, hw * 0.96), (2.6, 1.12, hw), (1.7, 1.18, hw)]
    st = body_stations(keys, arch_xs(3.28, 1.72, 0.3, fa), fa, wr - 0.02)
    st = [(3.301, 0.5, 0.9, 0, 0), (3.3, 0.48, 0.94, hw * 0.9, hw * 0.88)] + st
    xloft(m, P, st + [(1.7, 0.4, 1.1, 0, 0)], seg=14, power=6)
    # cab greenhouse (glass) + roof + pillars
    cab = [(2.3, 1.2), (2.05, 1.72), (1.95, 1.95), (1.8, 2.05)]
    xloft(m, "glass", [(2.301, 1.1, 1.12, 0, 0)] + [(x, 1.1, t, hw * 0.95, hw * 0.88) for x, t in cab] +
          [(1.75, 1.1, 2.05, 0, 0)], seg=14, power=6)
    xloft(m, P, [(2.02, 1.9, 1.95, 0, 0), (2.0, 1.9, 2.08, hw * 0.9, hw * 0.88), (1.8, 1.9, 2.1, hw * 0.92, hw * 0.9),
                 (1.75, 1.9, 2.05, 0, 0)], seg=12, power=6)
    for sd in (-1, 1):
        tube(m, P, [(2.32, 1.18, sd * hw * 0.93), (2.0, 2.02, sd * hw * 0.87)], 0.05, 5)
        tube(m, P, [(1.98, 1.18, sd * hw * 0.95), (1.98, 2.02, sd * hw * 0.88)], 0.04, 5)
        m.box("hs_dark", (0.012, 0.75, 0.01), (1.85, 0.8, sd * (hw + 0.003)))
        m.box("hs_chrome", (0.14, 0.03, 0.03), (1.95, 1.05, sd * (hw + 0.005)))
        tube(m, "hs_chrome", [(2.25, 1.35, sd * hw * 0.95), (2.3, 1.45, sd * (hw + 0.2))], 0.015, 4)
        m.box("hs_dark", (0.05, 0.28, 0.16), (2.3, 1.5, sd * (hw + 0.22)))
    # patient module: rounded box with rear wheel arch
    mx = 1.74
    mk = [(mx, 2.62, 1.07), (-2.85, 2.62, 1.07)]
    st = body_stations(mk, arch_xs(mx, -2.85, 0.6, ra), ra, 0.5)
    st = [(mx + 0.001, 0.9, 2.2, 0, 0), (mx, 0.52, 2.6, 1.05, 1.05)] + st[1:-1] + \
         [(-2.85, 0.52, 2.6, 1.05, 1.05), (-2.851, 0.9, 2.2, 0, 0)]
    xloft(m, P, st, seg=16, power=10)
    # red stripe band + cross on the sides and back
    xloft(m, "red", [(mx + 0.01, 1.35, 1.55, 0, 0), (mx + 0.01, 1.35, 1.55, 1.078, 1.078), (-2.86, 1.35, 1.55, 1.078, 1.078),
                     (-2.86, 1.35, 1.55, 0, 0)], seg=16, power=12)
    for sd in (-1, 1):
        z = sd * 1.08
        m.box("red", (0.55, 0.16, 0.01), (-1.9 + 0.0, 2.05, z))
        m.box("red", (0.16, 0.55, 0.01), (-1.9, 2.05, z))
        m.box("glass", (0.7, 0.45, 0.02), (0.8, 2.0, z))  # side window
        m.box("hs_chrome", (0.74, 0.03, 0.03), (0.8, 1.76, z))
        for x in (1.3, 0.3):
            m.box("hs_dark", (0.012, 1.5, 0.012), (x, 1.5, z))  # side door seam
        m.box("hs_chrome", (0.16, 0.03, 0.04), (0.5, 1.2, z))
    # rear: doors, windows, step bumper, lights
    xr = -2.86
    m.box("hs_dark", (0.01, 1.8, 0.012), (xr - 0.004, 1.55, 0))
    for sd in (-1, 1):
        m.box("glass", (0.02, 0.45, 0.55), (xr, 2.0, sd * 0.45))
        m.box("hs_chrome", (0.04, 0.03, 0.14), (xr - 0.01, 1.35, sd * 0.12))
        lens(m, "red", (0.14, 0.3), (xr - 0.005, 0.9, sd * 0.85), "-x")
        lens(m, "red", (0.12, 0.12), (xr - 0.005, 2.45, sd * 0.85), "-x")
        lens(m, "red", (0.12, 0.12), (mx + 0.005, 2.45, sd * 0.85), "+x")
        lens(m, "hs_amber", (0.12, 0.12), (-1.0, 2.45, sd * 1.075), "+z" if sd > 0 else "-z")
    m.decal("red", 1.2, 0.12, (xr - 0.012, 1.45, 0), (0, -90, 0))
    xloft(m, "hs_chrome", [(xr - 0.06, 0.5, 0.64, 0, 0), (xr - 0.05, 0.5, 0.64, 1.0, 1.0),
                           (xr + 0.25, 0.5, 0.64, 1.0, 1.0), (xr + 0.26, 0.5, 0.64, 0, 0)][::-1], seg=12, power=6)
    m.decal("hs_plate", 0.42, 0.16, (xr - 0.065, 0.57, 0), (0, -90, 0))
    # front: grille, headlights, bumper, plate
    fx = 3.3
    m.box("hs_dark", (0.04, 0.3, 1.1), (fx + 0.01, 0.75, 0))
    for k in range(5):
        m.box("hs_chrome", (0.03, 0.015, 1.0), (fx + 0.03, 0.63 + k * 0.06, 0))
    for sd in (-1, 1):
        lens(m, "hs_lens", (0.2, 0.18), (fx + 0.005, 0.76, sd * 0.72), "+x")
        lens(m, "hs_amber", (0.1, 0.1), (fx - 0.1, 0.85, sd * 0.97), "+z" if sd > 0 else "-z")
    xloft(m, "hs_chrome", [(fx - 0.08, 0.38, 0.54, 0, 0), (fx - 0.07, 0.38, 0.54, hw + 0.04, hw + 0.04),
                           (fx + 0.08, 0.38, 0.54, hw + 0.02, hw + 0.02), (fx + 0.09, 0.39, 0.53, 0, 0)], seg=12, power=6)
    m.decal("hs_plate", 0.42, 0.16, (fx + 0.095, 0.46, 0), (0, 90, 0))
    # lightbar on the cab roof: one lamp still glowing
    xloft(m, "hs_dark", [(1.72, 2.6, 2.66, 0, 0), (1.7, 2.6, 2.68, 0.8, 0.8), (1.45, 2.6, 2.68, 0.8, 0.8),
                         (1.43, 2.6, 2.66, 0, 0)], seg=10, power=6)
    for k, zc in enumerate((-0.55, -0.19, 0.19, 0.55)):
        mat = "bulb_red" if k == 0 else ("red" if k % 3 == 0 else "hs_lens")
        with m.push((1.58, 2.68, zc)):
            m.loft(mat, [(0, 0.11, 0.16), (0.1, 0.11, 0.16), (0.14, 0.09, 0.13), (0.15, 0, 0)], seg=10, power=3)
    # wheels (dual rear), arch lips, wells
    for sd in (-1, 1):
        wheel(m, fa[0][0], wr, sd * (hw - 0.14), wr, 0.24, outward=sd)
        wheel(m, ra[0][0], wr, sd * 0.92, wr, 0.22, outward=sd)
        wheel(m, ra[0][0], wr, sd * 0.68, wr, 0.22, rim=None, outward=sd)
        for (ax, ay, ar), zz in ((fa[0], hw), (ra[0], 1.07)):
            tube(m, P, arc((ax, ay), ar + 0.015, 5, 175, 8, z=sd * (zz - 0.02)), 0.035, 4, cap=False)
    m.decal("hs_crack", 0.6, 0.35, (2.18, 1.5, -0.3), (-62, 90, 0))
    return m


# ============================================================== street furniture

def m_lamp_post(name="lamp_post", bulb="bulb"):
    """Cobra-head street light: head at ~(0, 4.35, 1.05), lamp faces +Z (build_world lights sit there)."""
    m = B.Model(name)
    m.node("pole-col")
    m.lathe("hs_pole", [(0.17, 0), (0.17, 0.35), (0.13, 0.42), (0.1, 0.5), (0.085, 1.2), (0.07, 4.0),
                        (0.06, 4.2), (0.0, 4.26)], seg=10)
    m.node("detail")
    m.lathe("hs_pole", [(0.2, 0), (0.2, 0.08), (0.18, 0.12), (0, 0.12)], seg=10)  # base collar
    for a in (45, 135, 225, 315):
        c, sn = math.cos(math.radians(a)), math.sin(math.radians(a))
        m.cyl("rust", 0.02, 0.02, 0.05, (c * 0.14, 0.1, sn * 0.14), seg=5)  # anchor bolts
    m.box("hs_pole", (0.02, 0.2, 0.12), (0, 0.8, 0.09))  # access hatch
    arm = bezier((0, 3.9, 0.0), (0, 4.45, 0.05), (0, 4.42, 0.85), 8)
    tube(m, "hs_pole", arm, [0.05] * len(arm), 6, cap=False)
    tube(m, "hs_pole", bezier((0, 3.5, 0.06), (0, 3.75, 0.45), (0, 4.36, 0.5), 5), 0.02, 4)  # brace
    # cobra head: rounded shell + glass bowl underneath
    with m.push((0, 0, 0), (0, -90, 0)):  # loft along +X == world +Z
        xloft(m, "hs_pole", [(0.78, 4.36, 4.4, 0, 0), (0.8, 4.34, 4.44, 0.08, 0.07), (0.95, 4.33, 4.5, 0.17, 0.15),
                             (1.2, 4.33, 4.49, 0.2, 0.17), (1.38, 4.34, 4.44, 0.16, 0.13), (1.46, 4.36, 4.4, 0.08, 0.07),
                             (1.47, 4.37, 4.39, 0, 0)], seg=12, power=3)
        xloft(m, bulb, [(0.92, 4.34, 4.35, 0, 0), (0.94, 4.28, 4.36, 0.12, 0.13), (1.2, 4.25, 4.36, 0.15, 0.16),
                        (1.38, 4.29, 4.36, 0.1, 0.11), (1.4, 4.34, 4.35, 0, 0)], seg=10, power=2.5)
    return m


def m_lamp_post_cold():
    return m_lamp_post("lamp_post_cold", "bulb_cold")


def m_utility_pole():
    """9 m creosote pole: crossarm with braces + insulators, transformer can, climbing steps."""
    m = B.Model("utility_pole")
    m.node("pole-col")
    m.lathe("bark", [(0.16, 0), (0.15, 3), (0.12, 8.8), (0.1, 9.0), (0, 9.05)], seg=8)
    m.node("detail")
    m.box("hs_wood", (2.4, 0.12, 0.14), (0, 8.2, 0.17))
    m.box("hs_wood", (1.6, 0.1, 0.12), (0, 7.5, 0.17))
    for sd in (-1, 1):
        tube(m, "iron", [(sd * 0.05, 7.75, 0.14), (sd * 0.75, 8.14, 0.14)], 0.018, 4)
    for x in (-1.1, -0.45, 0.45, 1.1):
        m.lathe("white", [(0.03, 0), (0.07, 0.03), (0.07, 0.06), (0.04, 0.08), (0.065, 0.11), (0.065, 0.13),
                          (0.03, 0.17), (0, 0.18)], (x, 8.26, 0.17), seg=8)
        tube(m, "iron", [(x, 8.4, 0.17), (x + 0.4 * (1 if x > 0 else -1), 8.1, 0.17), (x + 0.9 * (1 if x > 0 else -1), 7.85, 0.17)],
             0.012, 3, cap=False)  # cut wire dangling
    for x in (-0.6, 0.6):
        m.lathe("white", [(0.025, 0), (0.05, 0.03), (0.05, 0.08), (0, 0.1)], (x, 7.55, 0.17), seg=6)
    # transformer can on a bracket
    m.box("iron", (0.1, 0.5, 0.25), (0, 6.4, -0.17))
    m.lathe("hs_pole", [(0, 5.9), (0.24, 5.9), (0.26, 5.95), (0.26, 6.8), (0.28, 6.85), (0.22, 6.95), (0, 6.98)],
            (0, 0, -0.45), seg=10)
    for y in (6.1, 6.6):
        m.lathe("iron", [(0.265, y), (0.265, y + 0.04)], (0, 0, -0.45), seg=10)
    for x in (-0.1, 0.1):
        m.lathe("white", [(0.03, 0), (0.04, 0.05), (0.03, 0.1), (0, 0.12)], (x, 6.98, -0.45), seg=6)
        tube(m, "iron", [(x, 7.1, -0.45), (x * 3, 7.6, -0.2), (x * 5, 7.55, 0.17)], 0.01, 3, cap=False)
    m.lathe("rubber", [(0.03, 0), (0.03, 6)], (0.1, 0, 0.12), seg=5)  # ground wire molding
    for i in range(10):
        y, sd = 2.4 + i * 0.45, (1 if i % 2 else -1)
        tube(m, "iron", [(sd * 0.1, y, 0), (sd * 0.3, y, 0), (sd * 0.3, y + 0.05, 0)], 0.015, 4, cap=False)
    m.box("hs_plate", (0.14, 0.1, 0.01), (0, 1.8, 0.15))  # pole tag
    return m


def m_bench():
    """Park bench: cast-iron S-curved ends, five seat slats, three back slats."""
    m = B.Model("bench")
    m.node("detail")
    for x in (-0.78, 0.78):
        tube(m, "iron", [(x, 0, 0.22), (x, 0.2, 0.2), (x, 0.42, 0.18)], 0.025, 5, cap=False)  # front leg
        back = bezier((x, 0.0, -0.2), (x, 0.45, -0.16), (x, 0.95, -0.3), 6)
        tube(m, "iron", back, 0.025, 5, cap=False)
        tube(m, "iron", [(x, 0.42, 0.24), (x, 0.43, -0.16)], 0.022, 5)  # seat rail
        tube(m, "iron", bezier((x, 0.62, -0.22), (x, 0.66, 0.1), (x, 0.6, 0.26), 5) + [(x, 0.42, 0.24)], 0.02, 5)
    m.node("bench-col")  # slats double as the collision
    for k in range(5):
        z = 0.2 - k * 0.09
        m.box("hs_wood", (1.8, 0.035, 0.07), (0, 0.46, z))
    for k, y in enumerate((0.6, 0.72, 0.84)):
        z = -0.18 - (y - 0.6) * 0.23
        m.box("hs_wood", (1.8, 0.09, 0.03), (0, y, z), (-14, 0, 0))
    m.box("hs_wood", (0.35, 0.035, 0.07), (0.6, 0.44, 0.02), (0, 12, -6))  # a slat has dropped
    return m


MODELS = [m_car_wreck, m_ambulance, m_lamp_post, m_lamp_post_cold, m_utility_pole, m_bench]
