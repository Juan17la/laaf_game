"""Shared humanoid rig for every LAAF character (built ones segmented PS2-style; tools/psx_chars.py ones skinned on it).

All characters face +Z, Y up, feet on y=0. The character's LEFT side is +X.
Each joint is a glTF node; geometry added after m.use("<Joint>") is in that
joint's local space (origin = the joint pivot). scripts/humanoid_anim.gd drives
these exact node names, so never rename them; proportions may change freely.

    Hips ─ Spine ─ (Neck ─) Head
         │       ├ UpperArmL ─ ForearmL ─ HandL
         │       └ UpperArmR ─ ForearmR ─ HandR
         ├ ThighL ─ ShinL ─ FootL
         └ ThighR ─ ShinR ─ FootR

Neck is optional and made for you: every character's head is still built on m.use("Head") (pivot at the
collar, as before); when the model is written, split_neck() moves the skin below the chin onto a Neck joint
at the old pivot and re-pivots Head at the top of the neck, so a turn or nod bends the neck instead of
swinging it from the collar like a block. humanoid_anim.gd shares head rotation between the two.

Limbs hang straight down from their joint (-Y). The foot pivot is the ankle;
toes point +Z. Hands hang down from the wrist.

Limbs are modelled on RIG's lengths; write time stretches them (below each pivot) to STRETCH's anatomical ones:
longer upper arm (elbow ~0.63 H, fingertips at mid-thigh), knee up to ~0.28 H. Overridden joints keep theirs.

SkirtL / SkirtR are optional too (skirt_joints): Hips children on the thigh pivots that humanoid_anim.gd swings
at ~0.6x the thigh, for long coats, robes and skirts (half_skirts) so a stride doesn't stab through the cloth.
"""
import build_assets as B

# name, parent, offset from parent pivot (1.78 m adult)
RIG = [
    ("Hips", None, (0, 0.95, 0)),
    ("Spine", "Hips", (0, 0.08, 0)),
    ("Head", "Spine", (0, 0.55, 0)),
    ("UpperArmL", "Spine", (0.2, 0.47, 0)),
    ("ForearmL", "UpperArmL", (0, -0.29, 0)),
    ("HandL", "ForearmL", (0, -0.26, 0)),
    ("UpperArmR", "Spine", (-0.2, 0.47, 0)),
    ("ForearmR", "UpperArmR", (0, -0.29, 0)),
    ("HandR", "ForearmR", (0, -0.26, 0)),
    ("ThighL", "Hips", (0.1, -0.05, 0)),
    ("ShinL", "ThighL", (0, -0.43, 0)),
    ("FootL", "ShinL", (0, -0.42, 0)),
    ("ThighR", "Hips", (-0.1, -0.05, 0)),
    ("ShinR", "ThighR", (0, -0.43, 0)),
    ("FootR", "ShinR", (0, -0.42, 0)),
]

STRETCH = {"ForearmL": (0, -0.33, 0), "ForearmR": (0, -0.33, 0), "ShinL": (0, -0.41, 0), "ShinR": (0, -0.41, 0),
           "FootL": (0, -0.44, 0), "FootR": (0, -0.44, 0)}


def skeleton(name, scale=1.0, overrides=None):
    """New Model with all joints created. overrides: {joint: offset} replaces the default
    offset (unscaled). Use scale ~0.93 for shorter adults; keep leg offsets summing to the
    Hips height so feet land on y=0."""
    m = B.Model(name)
    m.smooth = m.ao = True  # trilinear textures + baked occlusion for every character
    m.finish = finish  # run by write_glb once the body is built
    m.stretch = {}
    for joint, parent, off in RIG:
        if joint in (overrides or {}):
            off = overrides[joint]
        elif joint in STRETCH:
            m.stretch[parent] = STRETCH[joint][1] / off[1]
            off = STRETCH[joint]
        m.node(joint, parent, tuple(v * scale for v in off))
    return m


def skirt_joints(m):
    """Add SkirtL / SkirtR (on the thigh pivots) once; build each half of a long garment on them."""
    by = {nd["name"]: nd for nd in m.nodes}
    for side in "LR":
        if "Skirt" + side not in by:
            m.node("Skirt" + side, "Hips", by["Thigh" + side]["t"])


def finish(m):
    for nd in m.nodes:  # limbs modelled on RIG's lengths reach the STRETCH pivots
        k = getattr(m, "stretch", {}).get(nd["name"])
        if k:
            for pos, nrm, _ in nd["prims"].values():
                nrm[:] = [_unit((a, b / k, c)) if p[1] < 0 else (a, b, c) for p, (a, b, c) in zip(pos, nrm)]
                pos[:] = [(x, y * k if y < 0 else y, z) for x, y, z in pos]
    split_neck(m)


def mirror(fn):
    """Call fn(side, sign) for 'L' (+1, +X) and 'R' (-1, -X) so limbs are built once."""
    for side, sign in (("L", 1), ("R", -1)):
        fn(side, sign)


def split_neck(m):
    """Give the head a real neck: Head-node skin below the chin (the lowest face / mask vertex; triangles crossing
    it are clipped) moves to a new Neck joint at Head's old pivot; Head re-pivots on the neck's axis at that cut,
    with a skin ball there so no gap opens as it turns. Heads without a face material (creatures) are left alone."""
    by = {nd["name"]: nd for nd in m.nodes}
    head = by.get("Head")
    if not head or "Neck" in by:
        return
    chin = [p[1] for mat, (pos, _, _) in head["prims"].items() if "face" in mat or "mask" in mat for p in pos]
    if not chin:
        return
    top = min(chin) + 0.004
    moved, kept = {}, {}
    for mat, (pos, nrm, uv) in head["prims"].items():
        if "skin" not in mat:
            continue
        for i in range(0, len(pos), 3):
            tri = [(pos[i + k], nrm[i + k], uv[i + k]) for k in range(3)]
            for dst, poly in ((moved, _clip(tri, top, True)), (kept, _clip(tri, top, False))):
                for j in range(1, len(poly) - 1):  # fan
                    d = dst.setdefault(mat, ([], [], []))
                    for v in (poly[0], poly[j], poly[j + 1]):
                        d[0].append(v[0])
                        d[1].append(v[1])
                        d[2].append(v[2])
    # the neck's axis and girth from its vertices clear of the cut (the jaw's underside hugs the cut)
    low = [p for pos, _, _ in moved.values() for p in pos if p[1] < top - 0.015]
    if not low:
        return
    cx = sum(p[0] for p in low) / len(low)
    cz = sum(p[2] for p in low) / len(low)
    near = [p for p in low if p[1] > top - 0.07] or low
    r = sum(((p[0] - cx) ** 2 + (p[2] - cz) ** 2) ** 0.5 for p in near) / len(near)
    for mat in [k for k in head["prims"] if "skin" in k]:
        if mat in kept:
            head["prims"][mat] = kept[mat]
        else:
            del head["prims"][mat]
    neck = {"name": "Neck", "parent": head["parent"], "t": head["t"], "prims": moved}
    m.nodes.insert(m.nodes.index(head), neck)
    head["parent"], head["t"] = "Neck", (cx, top, cz)
    for pos, _, _ in head["prims"].values():
        pos[:] = [(x - cx, y - top, z - cz) for x, y, z in pos]
    m.use("Neck")
    m.ellipsoid(max(moved, key=lambda k: len(moved[k][0])), (r, r * 0.8, r * 0.95), (cx, top, cz), seg=12, rings=8)


def _unit(v):
    n = sum(c * c for c in v) ** 0.5 or 1.0
    return tuple(c / n for c in v)


def _clip(tri, y0, below):
    """The part of triangle [(pos, nrm, uv)] below (or above) the plane y = y0, as a polygon (Sutherland-Hodgman)."""
    inside = (lambda v: v[0][1] <= y0) if below else (lambda v: v[0][1] >= y0)
    out = []
    for i, cur in enumerate(tri):
        prev = tri[i - 1]
        if inside(cur) != inside(prev):
            t = (y0 - prev[0][1]) / (cur[0][1] - prev[0][1])
            out.append(tuple(tuple(a + (b - a) * t for a, b in zip(prev[k], cur[k])) for k in range(3)))
        if inside(cur):
            out.append(cur)
    return out
