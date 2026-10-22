"""Interior survival-horror props (hiding spots, clinic/school/church dressing).

Auto-loaded by build_assets._load_packs(): exposes MODELS and place(W, rng).
"""
import math

import build_assets as B


def t_int_books(x, y, a, b, r):
    """Book spines: coloured columns with dark bands top and bottom."""
    col = (x * 7 // 40 + (y // 16) * 3) % 5
    c = [(0.35, 0.08, 0.06), (0.1, 0.16, 0.3), (0.18, 0.25, 0.12), (0.4, 0.33, 0.2), (0.12, 0.1, 0.08)][col]
    if (x * 7) % 40 < 3 or y % 16 in (2, 13):
        c = B.mul(c, 0.4)
    return B.mul(c, 0.6 + 0.5 * a)


B.TEXTURES["int_books"] = t_int_books
B.MATS["int_books"] = B.M("int_books", scale=0.6)


# ============================================================== models

def cabinet(name, mat, w, h, d, doors, ajar, slits=False):
    """Hollow cabinet facing +Z (walk-in hiding spot); the left door hangs open by `ajar` degrees."""
    m = B.Model(name)
    t = 0.04
    m.node("body-col")
    m.box(mat, (w, h, t), (0, h / 2, -d / 2 + t / 2))
    for x in (-w / 2 + t / 2, w / 2 - t / 2):
        m.box(mat, (t, h, d), (x, h / 2, 0))
    m.box(mat, (w, t, d), (0, h - t / 2, 0))
    m.box(mat, (w, t, d), (0, t / 2, 0))
    m.node("detail")
    dw = w / doors
    with m.push((-w / 2, 0, d / 2), (0, -ajar, 0)):
        m.box(mat, (dw - 0.02, h - 0.04, 0.03), (dw / 2, h / 2, 0.015))
        if slits:
            for i in range(4):
                m.box("iron", (dw * 0.6, 0.02, 0.01), (dw / 2, h - 0.35 - i * 0.06, 0.035))
        m.box("iron", (0.03, 0.12, 0.03), (dw - 0.1, h / 2, 0.04))
    if doors == 2:
        m.box(mat, (dw - 0.02, h - 0.04, 0.03), (w / 4, h / 2, d / 2 + 0.015))
        m.box("iron", (0.03, 0.12, 0.03), (0.08, h / 2, d / 2 + 0.04))
    return m


def m_locker():
    return cabinet("int_locker", "locker", 0.9, 2.1, 0.55, 1, 35, slits=True)


def m_wardrobe():
    m = cabinet("int_wardrobe", "planks", 1.0, 2.0, 0.6, 2, 50)
    m.box("planks", (1.1, 0.1, 0.66), (0, 2.03, 0))
    return m


def m_morgue_freezer():
    m = B.Model("int_morgue_freezer")
    w, h, d = 2.4, 1.9, 0.9
    m.node("body-col")
    m.box("metal", (w, h, d), (0, h / 2, 0))
    m.node("detail")
    for x in (-0.8, 0, 0.8):
        for y in (0.5, 1.4):
            if (x, y) == (0, 1.4):
                m.box("iron", (0.66, 0.76, 0.02), (x, y, d / 2 + 0.005))  # open drawer, dark hole
                m.box("metal", (0.6, 0.05, 1.4), (x, y - 0.3, d / 2 + 0.7))
                m.box("sheet", (0.45, 0.2, 1.3), (x, y - 0.17, d / 2 + 0.7))
                continue
            m.box("white", (0.7, 0.8, 0.03), (x, y, d / 2 + 0.015))
            m.box("iron", (0.2, 0.04, 0.05), (x, y + 0.25, d / 2 + 0.05))
    return m


def m_wheelchair():
    m = B.Model("int_wheelchair")
    m.node("chair-col")
    m.box("red", (0.45, 0.05, 0.45), (0, 0.5, 0))
    m.box("red", (0.45, 0.45, 0.04), (0, 0.78, -0.24), (-10, 0, 0))
    m.node("detail")
    for x in (0.29, -0.25):
        m.cyl("rubber", 0.3, 0.3, 0.04, (x, 0.3, -0.05), (0, 0, 90), seg=10)
        m.cyl("rubber", 0.07, 0.07, 0.03, (x * 0.8, 0.07, 0.3), (0, 0, 90), seg=6)
    for x in (-0.22, 0.22):
        m.box("metal", (0.03, 0.03, 0.55), (x, 0.52, 0))
        m.box("metal", (0.03, 0.55, 0.03), (x, 0.8, -0.27))
        m.box("rubber", (0.03, 0.03, 0.12), (x, 1.08, -0.33))
        m.box("metal", (0.03, 0.4, 0.03), (x, 0.3, 0.25), (20, 0, 0))
    m.box("metal", (0.4, 0.02, 0.15), (0, 0.12, 0.38))
    return m


def m_iv_stand():
    m = B.Model("int_iv_stand")
    m.node("detail")
    for yaw in (0, 90):
        m.box("metal", (0.5, 0.03, 0.04), (0, 0.05, 0), (0, yaw + 45, 0))
    m.cyl("metal", 0.015, 0.015, 1.9, (0, 0.05, 0), seg=4, caps=False)
    m.box("metal", (0.35, 0.02, 0.02), (0, 1.93, 0))
    m.box("sheet", (0.14, 0.24, 0.04), (0.15, 1.72, 0))
    m.cyl("white", 0.004, 0.004, 1.1, (0.15, 0.5, 0), (0, 0, 8), seg=3, caps=False)
    return m


def m_hospital_bed():
    m = B.Model("int_hospital_bed")
    m.node("bed-col")
    m.box("metal", (0.95, 0.12, 2.1), (0, 0.55, 0))
    m.box("sheet", (0.9, 0.14, 1.3), (0, 0.68, 0.38))
    m.box("sheet", (0.9, 0.14, 0.8), (0, 0.9, -0.6), (35, 0, 0))
    m.box("metal", (0.95, 0.9, 0.05), (0, 0.8, -1.05))
    m.box("metal", (0.95, 0.6, 0.05), (0, 0.65, 1.05))
    m.node("detail")
    for x in (-0.5, 0.5):
        m.box("metal", (0.03, 0.25, 1.1), (x, 0.85, 0.1))
        for z in (-0.95, 0.95):
            m.cyl("metal", 0.025, 0.025, 0.5, (x * 0.9, 0.05, z), seg=4, caps=False)
            m.cyl("rubber", 0.05, 0.05, 0.03, (x * 0.9 + 0.015, 0.05, z), (0, 0, 90), seg=6)
    m.box("white", (0.5, 0.1, 0.3), (0, 1.14, -0.85), (35, 0, 0))
    return m


def m_mannequin():
    m = B.Model("int_mannequin")
    m.node("body-col")
    m.box("mannequin", (0.36, 0.55, 0.2), (0, 1.3, 0))
    for x in (-0.08, 0.08):
        m.box("mannequin", (0.12, 0.85, 0.14), (x, 0.55, 0))
    m.node("detail")
    m.cyl("iron", 0.25, 0.25, 0.04, seg=8)
    m.cyl("iron", 0.02, 0.02, 0.15, (0, 0.04, 0), seg=4, caps=False)
    m.box("mannequin", (0.08, 0.08, 0.08), (0, 1.62, 0))
    m.box("mannequin", (0.2, 0.26, 0.22), (0.03, 1.78, 0), (0, 0, 18))  # head tilted, watching
    m.box("mannequin", (0.1, 0.6, 0.1), (0.24, 1.22, 0.02), (0, 0, 6))  # the other arm is missing
    return m


def m_music_box():
    m = B.Model("int_music_box")
    m.node("detail")
    m.box("planks", (0.24, 0.1, 0.16), (0, 0.05, 0))
    m.box("red", (0.22, 0.005, 0.14), (0, 0.1, 0))
    with m.push((0, 0.1, -0.08), (-105, 0, 0)):
        m.box("planks", (0.24, 0.02, 0.16), (0, 0.01, 0.08))
    m.cyl("white", 0.008, 0.008, 0.06, (0, 0.1, 0), seg=4)
    m.cyl("white", 0.028, 0.0, 0.03, (0, 0.12, 0), seg=6)
    return m


def m_radio():
    """Old shortwave / ham receiver. Origin bottom centre, front panel faces +Z, ~0.4 x 0.25 x 0.15."""
    import models_items as I  # registers the itm_* materials and lathe helpers
    m = B.Model("int_radio")
    m.node("detail")
    zf = 0.075  # front face
    for x in (-0.17, 0.17):
        for z in (-0.055, 0.055):
            m.cyl("rubber", 0.012, 0.012, 0.012, (x, 0, z), seg=6)
    m.box("itm_veneer", (0.4, 0.238, 0.15), (0, 0.131, 0))  # cabinet
    m.box("itm_veneer", (0.41, 0.012, 0.16), (0, 0.244, 0))  # lid overhang
    for k in range(6):  # top louvres
        m.box("iron", (0.012, 0.002, 0.08), (-0.1 + k * 0.022, 0.2505, -0.02))
    m.box("itm_panel", (0.38, 0.215, 0.006), (0, 0.128, zf + 0.003))
    zp = zf + 0.006  # panel face
    # speaker grille + bezel, nameplate
    m.box("itm_grille", (0.12, 0.14, 0.002), (-0.115, 0.125, zp + 0.001))
    for y in (0.054, 0.196):
        m.box("itm_chrome", (0.128, 0.004, 0.004), (-0.115, y, zp + 0.002))
    for x in (-0.177, -0.053):
        m.box("itm_chrome", (0.004, 0.146, 0.004), (x, 0.125, zp + 0.002))
    m.box("itm_brass", (0.08, 0.014, 0.002), (-0.115, 0.218, zp + 0.001))
    # tuning scale window: lit dial, chrome bezel, red needle
    m.box("itm_dial", (0.19, 0.06, 0.002), (0.07, 0.1825, zp + 0.001))
    for y in (0.151, 0.214):
        m.box("itm_chrome", (0.198, 0.005, 0.006), (0.07, y, zp + 0.003))
    for x in (-0.027, 0.167):
        m.box("itm_chrome", (0.005, 0.068, 0.006), (x, 0.1825, zp + 0.003))
    m.box("red", (0.0025, 0.056, 0.002), (0.045, 0.1825, zp + 0.003))
    # magic-eye tuning bulb (green) and amber pilot jewel
    for x, mat, r in ((0.0, "itm_bulb_green", 0.011), (0.09, "itm_bulb_amber", 0.008)):
        I.turn(m, "itm_chrome", [(r + 0.004, 0), (r + 0.004, 0.004), (r, 0.005)], (x, 0.128, zp), (90, 0, 0), 12)
        I.turn(m, mat, [(r, 0.003), (r * 0.7, 0.008), (0, 0.009)], (x, 0.128, zp), (90, 0, 0), 12, smooth=True)
    # knobs: three small bakelite, one big tuning knob with a finger dimple
    for x in (-0.015, 0.035, 0.085):
        I.turn(m, "itm_chrome", [(0.016, 0), (0.016, 0.003), (0.012, 0.004)], (x, 0.08, zp), (90, 0, 0), 12)
        I.turn(m, "itm_bakelite", [(0.011, 0.003), (0.011, 0.016), (0.009, 0.019), (0, 0.02)], (x, 0.08, zp), (90, 0, 0), 10)
        m.box("white", (0.002, 0.008, 0.002), (x, 0.087, zp + 0.02))
    I.turn(m, "itm_chrome", [(0.028, 0), (0.028, 0.004), (0.024, 0.006)], (0.145, 0.085, zp), (90, 0, 0), 14)
    I.turn(m, "itm_bakelite", [(0.022, 0.005), (0.022, 0.022), (0.019, 0.026), (0, 0.027)], (0.145, 0.085, zp), (90, 0, 0), 14)
    m.cyl("itm_chrome", 0.004, 0.004, 0.004, (0.157, 0.094, zp + 0.025), (90, 0, 0), seg=6)
    # toggles, headphone jack
    for x in (-0.015, 0.025, 0.065):
        m.cyl("itm_chrome", 0.006, 0.006, 0.004, (x, 0.038, zp), (90, 0, 0), seg=8)
        m.cyl("itm_chrome", 0.0018, 0.0012, 0.016, (x, 0.038, zp + 0.004), (70, 0, 0), seg=4)
    m.cyl("itm_chrome", 0.006, 0.006, 0.004, (0.14, 0.038, zp), (90, 0, 0), seg=8)
    m.cyl("itm_bore", 0.003, 0.003, 0.0045, (0.14, 0.038, zp), (90, 0, 0), seg=6)
    # rack handles
    for x in (-0.186, 0.186):
        for y in (0.045, 0.21):
            m.box("itm_chrome", (0.01, 0.01, 0.026), (x, y, zp + 0.013))
        I.rod(m, "itm_chrome", (x, 0.04, zp + 0.024), (x, 0.215, zp + 0.024), 0.005, 8)
    # telescopic antenna from the back right corner
    I.turn(m, "itm_chrome", [(0.012, 0), (0.012, 0.012), (0.008, 0.016)], (0.16, 0.25, -0.055), seg=10)
    with m.push((0.16, 0.262, -0.055), (-8, 0, -25)):
        y = 0.0
        for k, (r, L) in enumerate(((0.0045, 0.14), (0.0035, 0.13), (0.0026, 0.12), (0.0018, 0.1))):
            I.turn(m, "itm_chrome", [(r, y), (r, y + L), (r + 0.001, y + L - 0.004), (r + 0.001, y + L)], seg=6)
            y += L - 0.006
        m.ellipsoid("itm_chrome", (0.0045, 0.0045, 0.0045), (0, y + 0.004, 0), seg=6, rings=4)
    return m


def m_pa_speaker():
    """Wall mounted: origin on the wall, horn points +Z."""
    m = B.Model("int_pa_speaker")
    m.node("detail")
    m.box("iron", (0.08, 0.08, 0.15), (0, 0, 0.075))
    m.cyl("metal", 0.03, 0.18, 0.3, (0, 0, 0.1), (90, 0, 0), seg=8, caps=False)
    m.cyl("iron", 0.17, 0.17, 0.01, (0, 0, 0.39), (90, 0, 0), seg=8)
    return m


def m_bookshelf():
    m = B.Model("int_bookshelf")
    w, h, d = 1.8, 2.0, 0.35
    m.node("shelf-col")
    m.box("planks", (w, h, 0.03), (0, h / 2, -d / 2 + 0.015))
    for x in (-w / 2 + 0.02, w / 2 - 0.02):
        m.box("planks", (0.04, h, d), (x, h / 2, 0))
    for y in (0.05, 0.5, 0.95, 1.4, 1.97):
        m.box("planks", (w, 0.04, d), (0, y, 0))
    m.node("detail")
    for i, y in enumerate((0.07, 0.52, 0.97, 1.42)):
        gap = 0.25 + 0.2 * (i % 3)
        m.box("int_books", (w - 0.1 - gap, 0.33, 0.25), (-gap / 2, y + 0.165, 0.02))
        m.box("int_books", (0.05, 0.33, 0.25), (w / 2 - gap + 0.02, y + 0.16, 0.02), (0, 0, -22))
    return m


def m_filing_cabinet():
    m = B.Model("int_filing_cabinet")
    m.node("body-col")
    m.box("metal", (0.5, 1.3, 0.6), (0, 0.65, 0))
    m.node("detail")
    for i in range(4):
        y = 0.17 + i * 0.31
        if i == 2:
            m.box("metal", (0.44, 0.26, 0.5), (0, y, 0.55))
            m.box("white", (0.38, 0.04, 0.44), (0, y + 0.12, 0.55))
            continue
        m.box("metal", (0.46, 0.28, 0.02), (0, y, 0.31))
        m.box("iron", (0.14, 0.03, 0.03), (0, y + 0.06, 0.33))
    for k, (x, z) in enumerate(((0.3, 0.9), (-0.2, 1.1), (0.1, 1.35))):
        m.box("white", (0.21, 0.005, 0.3), (x, 0.005, z), (0, k * 37, 0))
    return m


def m_debris():
    m = B.Model("int_debris")
    m.node("debris-col")
    with m.push((0, 0.81, 0), (180, 20, 0)):
        B.table(m, 0, 0, 1.2, 0.8)
    m.node("detail")
    with m.push((1.1, 0.23, 0.6), (0, 40, 90)):
        B.chair(m, 0, 0)
    for i in range(3):
        m.box("planks", (1.4, 0.04, 0.14), (-0.6 + i * 0.3, 0.1 + i * 0.05, 0.7), (0, 30 + i * 50, 8 * i))
    for k in range(4):
        m.box("white", (0.21, 0.005, 0.3), (-0.8 + k * 0.5, 0.005, -0.7 + (k % 2) * 0.3), (0, k * 53, 0))
    return m


def m_candle_stand():
    m = B.Model("int_candle_stand")
    m.node("detail")
    m.cyl("iron", 0.2, 0.2, 0.04, seg=6)
    m.cyl("iron", 0.02, 0.02, 1.3, (0, 0.04, 0), seg=4, caps=False)
    for y, r, n in ((0.9, 0.3, 5), (1.1, 0.18, 3), (1.3, 0.0, 1)):
        if r:
            m.cyl("iron", r, r, 0.02, (0, y, 0), seg=8, caps=False)
        for i in range(n):
            a = 2 * math.pi * i / n
            x, z = r * math.cos(a), r * math.sin(a)
            m.cyl("white", 0.02, 0.02, 0.18 - 0.03 * (i % 2), (x, y, z), seg=5)
            m.cyl("bulb", 0.012, 0.0, 0.05, (x, y + 0.19 - 0.03 * (i % 2), z), seg=3)
    return m


def m_confession_booth():
    """Three bays across X, facing +Z; the curtained side bays are walk-in hiding spots."""
    m = B.Model("int_confession_booth")
    w, h, d, t = 2.4, 2.5, 1.2, 0.06
    m.node("booth-col")
    m.box("planks", (w, h, t), (0, h / 2, -d / 2 + t / 2))
    for x in (-1.2, -0.4, 0.4, 1.2):
        m.box("planks", (t, h, d), (x - math.copysign(t / 2, x), h / 2, 0))
    m.box("planks", (w, t, d), (0, h - t / 2, 0))
    m.box("door", (0.74, 2.0, 0.05), (0, 1.0, d / 2 - 0.03))
    m.node("detail")
    m.gable("planks", w + 0.1, d + 0.1, 0.5, (0, h, 0), (0, 90, 0))
    for x in (-0.8, 0.8):
        m.box("red", (0.72, 1.7, 0.03), (x, 1.35, d / 2 - 0.02))
        m.box("planks", (0.6, 0.15, 0.3), (x, 0.08, -0.3))
    m.box("iron", (0.03, 0.4, 0.4), (-0.4, 1.4, -0.1))  # screen grilles
    m.box("iron", (0.03, 0.4, 0.4), (0.4, 1.4, -0.1))
    return m


def m_eye_door():
    """Sealed door marked with the Veil's Eye. Wall mounted: origin on the wall, faces +Z."""
    m = B.Model("int_eye_door")
    m.node("detail")
    for x in (-0.6, 0.6):
        m.box("planks", (0.12, 2.3, 0.14), (x, 1.15, 0.07))
    m.box("planks", (1.32, 0.12, 0.14), (0, 2.3, 0.07))
    m.box("door", (1.08, 2.2, 0.06), (0, 1.1, 0.03))
    m.decal("eye", 0.7, 0.7, (0, 1.4, 0.065))
    return m


MODELS = [m_locker, m_wardrobe, m_morgue_freezer, m_wheelchair, m_iv_stand, m_hospital_bed, m_mannequin,
          m_music_box, m_radio, m_pa_speaker, m_bookshelf, m_filing_cabinet, m_debris, m_candle_stand,
          m_confession_booth, m_eye_door]


# ============================================================== placement

# (x, z, yaw) as used in build_assets.build_world()
CLINIC, SCHOOL, CHURCH = (72, -100, -90), (108, 0, -90), (-72, -100, 90)
MOTEL, GRADY, BAR = (-100, 62, 90), (14, -24, 0), (-15, -24, 0)
CABIN, OWEN_CABIN = (-105, -28, 0), (-150, 22, 90)

# (building, model, local x, local z, local yaw, y): interior floor top is 0.05
INTERIOR = [
    (CLINIC, "int_morgue_freezer", -12.0, 6.35, 180, 0.05),  # south wall of the morgue: the freezer marker
    (CLINIC, "int_hospital_bed", 9.0, -5.4, 0, 3.85),  # upstairs, patient room 3
    (CLINIC, "int_filing_cabinet", -13.1, -6.45, 0, 0.05),  # records: Sam's file
    (CLINIC, "int_filing_cabinet", -12.5, -6.45, 0, 0.05),
    (CLINIC, "int_iv_stand", 4.6, -3.4, 0, 0.05),
    (CLINIC, "int_iv_stand", 10.4, -1.2, 40, 0.05),
    (CLINIC, "int_iv_stand", 13.2, 3.2, 0, 0.05),
    (CLINIC, "int_wheelchair", 13.0, 1.6, 200, 0.05),  # by the waiting seats, off Julian's beat
    (CLINIC, "int_filing_cabinet", -13.5, 2.0, 90, 0.05),
    (CLINIC, "int_filing_cabinet", -13.5, 2.6, 90, 0.05),
    (CLINIC, "int_locker", 13.5, -0.5, -90, 0.05),
    (CLINIC, "int_eye_door", 13.78, -4.0, -90, 0.05),
    (CLINIC, "int_debris", -0.6, -4.2, 15, 0.05),  # (its tipped chair is solid: clear of the pharmacy door)
    (CLINIC, "int_pa_speaker", 0, -6.8, 0, 3.0),
    (SCHOOL, "int_pa_speaker", 2.2, -6.8, 0, 2.9),  # the office: Nora's PA
    (SCHOOL, "int_pa_speaker", -8.0, 6.8, 180, 3.0),  # corridor
    (SCHOOL, "int_pa_speaker", 10.0, 6.8, 180, 3.0),
    (SCHOOL, "int_music_box", 12.2, 0.4, 200, 0.76),  # on the desk key part 2 is taped under
    (SCHOOL, "int_radio", -12.5, -1.8, 10, 0.81),  # on the teacher's desk (#3)
    (SCHOOL, "int_mannequin", 17.0, -6.2, -150, 0.05),
    (SCHOOL, "int_eye_door", -17.8, 3, 90, 0.05),
    (SCHOOL, "int_debris", -4, 4, 40, 0.05),
    (SCHOOL, "int_filing_cabinet", 4.45, -6.45, 0, 0.05),
    (CHURCH, "int_candle_stand", -2.4, -10.4, 0, 0.05),
    (CHURCH, "int_candle_stand", 2.4, -10.4, 30, 0.05),
    (CHURCH, "int_confession_booth", -5.2, 10.3, 90, 0.05),
    (CHURCH, "int_eye_door", 5.8, -6, -90, 0.05),
    (CHURCH, "int_bookshelf", 5.62, 9.5, -90, 0.05),
    (MOTEL, "int_wardrobe", 10.8, -3.0, 0, 0.05),
    (CABIN, "int_wardrobe", 0.1, -2.0, 0, 0.05),
    (OWEN_CABIN, "int_bookshelf", -0.3, -2.12, 0, 0.05),
    (GRADY, "int_filing_cabinet", -6.5, -1.5, 90, 0.05),
    (GRADY, "int_radio", -1.8, -2, 160, 1.0),
    (BAR, "int_radio", 3, -3, 0, 1.1),
]

# outdoor strays, placed only where free
OUTDOOR = [("int_debris", -18, 8, 1.5), ("int_mannequin", 100, 24, 0.6), ("int_wheelchair", 58, -104, 0.6),
           ("int_debris", -110, -34, 1.5), ("int_mannequin", -8, -190, 0.6)]


def to_world(b, lx, lz):
    bx, bz, yaw = b
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    return bx + lx * c + lz * s, bz - lx * s + lz * c


# dim interior lights (building, local x, y, local z, colour, energy, range, flicker); the school's die with
# its power cut (Chapter2Director.power_cut → lights_out)
LIGHTS = [
    (SCHOOL, -12, 2.9, 4.6, B.COLD, 0.5, 8, False), (SCHOOL, 0, 2.9, 4.6, B.COLD, 0.6, 8, True),
    (SCHOOL, 12, 2.9, 4.6, B.COLD, 0.5, 8, False), (SCHOOL, -9, 2.9, -2.5, B.COLD, 0.45, 7, False),
    (SCHOOL, 11, 2.9, -2.0, B.COLD, 0.45, 8, True), (SCHOOL, -10, 6.2, 1.0, B.WARM, 0.3, 7, False),
    (SCHOOL, 10, 6.2, 1.0, B.WARM, 0.3, 7, True), (SCHOOL, -2, 6.2, -5.6, B.COLD, 0.35, 7, False),
    (CLINIC, -6, 2.9, 4.0, B.SICK, 0.5, 8, True), (CLINIC, 6, 2.9, 4.0, B.COLD, 0.5, 8, False),
    (CLINIC, 8, 2.9, -3.5, B.SICK, 0.45, 7, True), (CLINIC, -11.6, 2.9, 0.0, B.COLD, 0.4, 6, False),
    (CLINIC, 0, 2.9, -4.0, B.COLD, 0.35, 5, True), (CLINIC, 0, 6.1, 0.0, B.COLD, 0.3, 8, False),
    (CLINIC, 11, 6.1, 4.0, B.SICK, 0.4, 5, True), (CLINIC, -11.5, 6.1, -2.0, B.COLD, 0.3, 6, False),
]


def place(W, rng):
    for b, lx, y, lz, col, e, r, fl in LIGHTS:
        x, z = to_world(b, lx, lz)
        W.light(x, y, z, col, e, r, flicker=fl)
    for b, name, lx, lz, lyaw, y in INTERIOR:
        x, z = to_world(b, lx, lz)
        W.inst(name, x, z, b[2] + lyaw, y=y)
        if name == "int_candle_stand":
            W.light(x, 1.4, z, B.WARM, 0.6, 5, flicker=True)
    for name, x, z, gap in OUTDOOR:
        if not W.blocked(x, z, gap):
            W.inst(name, x, z, rng.uniform(0, 360), block=gap)
