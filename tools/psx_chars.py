"""PSX pack characters (Characters_psx_02, Mixamo-rigged FBX) → models/char_*.glb, skinned, with the shared rig's joints.

    flatpak run org.blender.Blender -b --python tools/psx_chars.py [-- char_alex ...]

humanoid_anim.gd drives joint nodes (tools/rig.py names), so each FBX is posed to the rig's rest (faces +Z, left
+X, arms hanging straight down, palms in, fingers loosely curled) and that pose becomes the skin's bind pose. The
GLB holds the skinned mesh on its Mixamo skeleton (bones renamed "m_<bone>") plus an empty per rig joint (identity
rotation, pivot at the bone head); humanoid_anim.gd poses the bones from those joints every frame (_skin), so the
shoulders, elbows and knees bend in the skin instead of cracking open between rigid pieces. Scaled so the shoulder
pivots land where the old model had them: aim / grip constants stay valid.
"""
import math
import os
import re
import sys

import tempfile

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "Characters_psx_02")

# game character → (pack model, old shoulder height (UpperArmL pivot, m) to scale to)
CAST = {
    "char_alex": ("Male/Character_04", 1.495),
    "char_lucia": ("Female/Character_45_Female", 1.41),
    "char_elena": ("Female/Character_34_Female", 1.44),
    "char_grady": ("Male/Character_Male_42", 1.44),
    "char_julian": ("Male/Character_25_Doctor", 1.5),
    "char_nora": ("Female/Character_29_Female", 1.395),
    "char_owen": ("Male/Character_Male_34", 1.53),
    "char_silas": ("Male/Character_Male_43", 1.44),
    "char_marcus": ("Male/Character_Male_47", 1.56),
    "char_shepherd": ("Killer_M/Character_Killer_09", 1.44),
    "char_marked_man": ("Killer_M/Character_Killer", 1.5),
    "char_marked_woman": ("Female/Character_51_Female", 1.41),
    "char_boss": ("Killer_M/Character_Monster_07", 2.13),
}

FINGERS = ("Index", "Middle", "Ring", "Pinky")  # mitten rigs have Index only; the thumb stays along the grip

# Mixamo bone (prefix stripped) → rig joint; parent of each joint
BONES = {"Hips": "Hips", "Spine": "Spine", "Spine1": "Spine", "Spine2": "Spine", "Neck": "Neck", "Head": "Head",
         "HeadTop_End": "Head"}
for s, side in (("L", "Left"), ("R", "Right")):
    BONES.update({side + "Shoulder": "Spine", side + "Arm": "UpperArm" + s, side + "ForeArm": "Forearm" + s,
                  side + "Hand": "Hand" + s, side + "UpLeg": "Thigh" + s, side + "Leg": "Shin" + s,
                  side + "Foot": "Foot" + s, side + "ToeBase": "Foot" + s, side + "Toe_End": "Foot" + s})
    for f in FINGERS + ("Thumb",):
        for i in range(1, 5):
            BONES[side + "Hand%s%d" % (f, i)] = "Hand" + s
PARENT = {"Hips": None, "Spine": "Hips", "Neck": "Spine", "Head": "Neck"}
for s in "LR":
    PARENT.update({"UpperArm" + s: "Spine", "Forearm" + s: "UpperArm" + s, "Hand" + s: "Forearm" + s,
                   "Thigh" + s: "Hips", "Shin" + s: "Thigh" + s, "Foot" + s: "Shin" + s})
PIVOT = {"Hips": "Hips", "Spine": "Spine", "Neck": "Neck", "Head": "Head"}  # joint → bone whose head is its pivot
for s, side in (("L", "Left"), ("R", "Right")):
    PIVOT.update({"UpperArm" + s: side + "Arm", "Forearm" + s: side + "ForeArm", "Hand" + s: side + "Hand",
                  "Thigh" + s: side + "UpLeg", "Shin" + s: side + "Leg", "Foot" + s: side + "Foot"})
CURL = (0.12, 0.15, 0.1)  # rad per finger joint (Index1..3): a relaxed hand (humanoid_anim.gd GRIP closes it)
ROUND = 5  # round_shoulders passes
ROUND_BELOW = 0.06  # m (unscaled) under the shoulder pivot the rounding reaches: the armpit stays
THUMB = 0.9  # rad a mitten's thumb folds down along the finger (tuck_thumbs)
TUCK = {"char_alex"}  # mitten rigs whose thumb tuck_thumbs finds cleanly (checked by eye: other meshes split it unevenly)
THUMB_FORWARD = 0.012  # m (unscaled) forward of the finger's base knuckle that marks the thumb's skin
PAD = 8  # px each texture's islands grow into the gaps between them (padded)
HAND_MAT = re.compile("skin|glove|claw|bandage|brand|^Character_")  # the hand's own surfaces, not what it holds
SOLE = 0.05  # m (1.78 m rig): the foot pivot sits this far over the ground (humanoid_anim.gd SOLE)


def bare(name):
    return name.split(":")[-1]


def update():
    bpy.context.view_layer.update()


def turn_bone(arm, pb, rot, about):
    """Rotate pose bone pb (and so its children) by world rotation `rot` about world point `about`."""
    w = arm.matrix_world
    m = w.inverted() @ Matrix.Translation(about) @ rot.to_matrix().to_4x4() @ Matrix.Translation(-about) @ w
    pb.matrix = m @ pb.matrix
    update()


def head(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].head


def tail(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].tail


def box_centre(points):
    pts = list(points)
    if not pts:
        return Vector()
    return Vector([(min(p[i] for p in pts) + max(p[i] for p in pts)) / 2 for i in range(3)])


def held_props(path):
    """Prop meshes (hand-local) the current model's hands hold: every face on HandL / HandR that isn't the hand
    itself (the built characters modelled sledgehammer, sword, lantern... into the hand). Grafted onto the new
    hands, which keep the same frame (wrist pivot, fingers -Y), so a rebuild keeps them too."""
    props = {}  # "HandL" → ([meshes], centre of the hand that held them)
    if not os.path.exists(path):
        return props
    bpy.ops.import_scene.gltf(filepath=path)
    skin = next((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature()), None)
    for s in "LR":
        hand = bpy.data.objects.get("Hand" + s)
        centre = None
        if skin and hand:  # a skinned model: the hand is the skin its hand and finger bones carry
            names = {g.index: BONES.get(bare(g.name)[2:]) for g in skin.vertex_groups}
            centre = box_centre(skin.matrix_world @ v.co - hand.matrix_world.translation for v in skin.data.vertices
                                if v.groups and names.get(max(v.groups, key=lambda g: g.weight).group) == "Hand" + s)
        for ob in [hand] + list(hand.children) if hand else []:  # a rebuilt model keeps them on a "prop" child
            if ob.type != "MESH":
                continue
            bm = bmesh.new()
            bm.from_mesh(ob.data)
            mats = ob.data.materials
            own = [f for f in bm.faces if not mats or HAND_MAT.search(mats[f.material_index].name)]
            if ob == hand:
                centre = box_centre(v.co for f in own for v in f.verts)
            bmesh.ops.delete(bm, geom=own, context="FACES")
            if bm.faces:
                me = ob.data.copy()
                bm.to_mesh(me)
                props.setdefault("Hand" + s, ([], centre))[0].append(me)
            bm.free()
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    return props


def padded(path):
    """The pack texture with its UV islands' edge colours grown PAD px out into the black between them: mipmaps and
    filtering average across a seam, and with black there every seam drew as a dark crack (it read as holes in the
    body). The islands themselves are untouched."""
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    filled = px[:, :, :3].max(axis=2) > 2.0 / 255.0
    for _ in range(PAD):
        acc = np.zeros_like(px)
        cnt = np.zeros((h, w), dtype=np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            m = np.roll(filled, (dy, dx), axis=(0, 1))
            acc += np.roll(px, (dy, dx), axis=(0, 1)) * m[:, :, None]
            cnt += m
        grow = ~filled & (cnt > 0)
        px[grow] = acc[grow] / cnt[grow][:, None]
        filled |= grow
    img.pixels[:] = px.ravel()
    img.filepath_raw = os.path.join(tempfile.mkdtemp(), os.path.basename(path))
    img.file_format = "PNG"
    img.save()
    return img


def round_shoulders(body, arm, B):
    """The low-poly jackets end the shoulder in a box corner: relax the skin over each shoulder cap (the arm's and
    collarbone's, above the armpit) toward its neighbours a little, so it rounds over like a deltoid. Positions only:
    the UVs, and so the texture, stay where the artist put them."""
    ids = {g.index for g in body.vertex_groups if bare(g.name) in ("LeftArm", "RightArm", "LeftShoulder", "RightShoulder")}
    pit = min(head(arm, B("LeftArm")).z, head(arm, B("RightArm")).z) - ROUND_BELOW
    w = body.matrix_world
    cap = {v.index for v in body.data.vertices if (w @ v.co).z > pit and sum(g.weight for g in v.groups if g.group in ids) > 0.3}
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    for _ in range(ROUND):
        bmesh.ops.smooth_vert(bm, verts=[bm.verts[i] for i in cap], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()


def tuck_thumbs(body, arm, B):
    """Mitten rigs (no thumb bones) weight the thumb to the finger's base, so it hooked over whenever the fingers
    curled, and it stands well out from the palm. Its skin (the base-knuckle skin forward of the finger) goes to the
    hand instead, and folds down by THUMB about its root, along the finger, where a relaxed thumb lies."""
    w = body.matrix_world
    for side in ("Left", "Right"):
        knuckle = body.vertex_groups.get(B(side + "HandIndex1"))
        palm = body.vertex_groups.get(B(side + "Hand"))
        if not knuckle or not palm:
            continue
        base = head(arm, B(side + "HandIndex1"))
        thumb = [v for v in body.data.vertices if v.groups and max(v.groups, key=lambda g: g.weight).group == knuckle.index
                 and (w @ v.co - base).y < -THUMB_FORWARD]  # forward is -Y
        if not thumb:
            continue
        pts = sorted((w @ v.co for v in thumb), key=lambda p: (p - head(arm, B(side + "Hand"))).length)
        root = (pts[0] + pts[1]) / 2
        down = Matrix.Rotation((1 if side == "Right" else -1) * THUMB, 4, "Y")  # the tip (pointing in, at the thigh) swings down
        turn = Matrix.Translation(root) @ down @ Matrix.Rotation(0.3, 4, "X") @ Matrix.Translation(-root)
        for v in thumb:
            v.co = w.inverted() @ (turn @ (w @ v.co))
            for g in list(v.groups):
                body.vertex_groups[g.group].remove([v.index])
            palm.add([v.index], 1.0, "REPLACE")
        print("thumb", side, len(thumb), "verts")
    body.data.update()


def convert(key, model, shoulder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    out = os.path.join(ROOT, "models", key + ".glb")
    props = held_props(out)
    group, name = model.split("/")
    bpy.ops.import_scene.fbx(filepath=os.path.join(PACK, "Models", "Rig", group, name + ".fbx"))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = next(o for o in bpy.data.objects if o.type == "MESH")
    pre = arm.pose.bones[0].name[:-len(bare(arm.pose.bones[0].name))]  # "mixamorig:" (varies)
    B = lambda n: pre + n
    for mat in body.data.materials:  # the FBX points at the artist's C: drive
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                n.image = padded(os.path.join(PACK, "Textures", os.path.basename(n.image.filepath.replace("\\", "/"))))
    update()
    # the FBX's action holds a T-pose; the mesh itself was modelled arms down: start there (its shoulder height in the
    # T-pose still sets the scale, as it always has)
    tall = head(arm, B("LeftArm")).z
    palm = {side: (arm.matrix_world @ arm.pose.bones[B(side + "Hand")].matrix).to_3x3().inverted() @ Vector((0, 0, -1))
            for side in ("Left", "Right")}  # hand-local: Mixamo's T-pose has the palms down
    # ...but the fingers keep the T-pose's: some models' hands were modelled already clenched, and curled on from
    # there they fold through the palm
    keep = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones if "Hand" in bare(pb.name) and bare(pb.name)[-1].isdigit()}
    arm.animation_data_clear()
    for pb in arm.pose.bones:
        pb.matrix_basis = keep.get(pb.name, Matrix())
    update()

    # face -Y (glTF +Z) with the left hip on +X: some pack models stand side-on
    lat = head(arm, B("LeftUpLeg")) - head(arm, B("RightUpLeg"))
    arm.matrix_world = Matrix.Rotation(-math.atan2(lat.y, lat.x), 4, "Z") @ arm.matrix_world
    update()

    # from the modelled pose (arms already hanging: the shoulders keep the artist's shape, unlike a T-pose bent down),
    # arms straight down, palms in, fingers loosely curled
    for side, sign in (("Left", 1), ("Right", -1)):
        for b in ("Arm", "ForeArm", "Hand"):
            h = head(arm, B(side + b))
            turn_bone(arm, arm.pose.bones[B(side + b)], (tail(arm, B(side + b)) - h).rotation_difference(Vector((0, 0, -1))), h)
        # palm toward the thigh: the whole arm turns about its own length at the shoulder, where the skin takes a twist
        # best (the modelled hands hang every which way; humanoid_anim.gd closes them toward the thigh)
        if B(side + "HandPinky1") in arm.pose.bones:  # a full hand: the knuckle line (pinky → index) shows which way it faces
            down = (head(arm, B(side + "HandMiddle1")) - head(arm, B(side + "Hand"))).normalized()
            n = down.cross(head(arm, B(side + "HandIndex1")) - head(arm, B(side + "HandPinky1"))) * sign
        else:  # a mitten: by the T-pose (not every pack model's has its palms down, but the mittens' do)
            n = (arm.matrix_world @ arm.pose.bones[B(side + "Hand")].matrix).to_3x3() @ palm[side]
        turn = math.atan2(sign * n.y, -sign * n.x)  # from n.xy round to inward, (-sign, 0)
        turn_bone(arm, arm.pose.bones[B(side + "Arm")], Matrix.Rotation(turn, 3, "Z").to_quaternion(), head(arm, B(side + "Arm")))
        for f in FINGERS:
            for i, a in enumerate(CURL):
                bn = B(side + "Hand%s%d" % (f, i + 1))
                if bn in arm.pose.bones:
                    turn_bone(arm, arm.pose.bones[bn], Matrix.Rotation(sign * a, 3, "Y").to_quaternion(), head(arm, bn))

    pivots = {j: head(arm, B(b)) for j, b in PIVOT.items() if B(b) in arm.pose.bones}
    k = shoulder / tall
    base = Vector((pivots["Hips"].x, pivots["Hips"].y, 0))
    # the posed skin becomes the bind pose: arms down is the rest humanoid_anim.gd rotates from
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=next(m.name for m in body.modifiers if m.type == "ARMATURE"))
    round_shoulders(body, arm, B)
    if key in TUCK and B("LeftHandThumb1") not in arm.pose.bones:
        tuck_thumbs(body, arm, B)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply()
    bpy.ops.object.mode_set(mode="OBJECT")
    body.modifiers.new("Armature", "ARMATURE").object = arm
    update()
    lift = -k * min((body.matrix_world @ v.co).z for v in body.data.vertices)  # soles on the ground
    arm.matrix_world = Matrix.Translation((0, 0, lift)) @ Matrix.Scale(k, 4) @ Matrix.Translation(-base) @ arm.matrix_world
    update()
    pivots = {j: (p - base) * k + Vector((0, 0, lift)) for j, p in pivots.items()}
    for s in "LR":  # foot pivot at the rig's ankle height, limbs straight under their joints
        pivots["Foot" + s].z = SOLE * shoulder / 1.495
        for j, up in (("Forearm", "UpperArm"), ("Hand", "Forearm"), ("Shin", "Thigh"), ("Foot", "Shin")):
            pivots[j + s].xy = pivots[up + s].xy

    # where each hand's skin sits (its props are moved by how far that is from the old hand's)
    names = {g.index: BONES.get(bare(g.name)) for g in body.vertex_groups}
    grip = {}
    for v in body.data.vertices:
        if v.groups:
            j = names.get(max(v.groups, key=lambda g: g.weight).group)
            if j in ("HandL", "HandR"):
                grip.setdefault(j, []).append(body.matrix_world @ v.co - pivots[j])
    for b in arm.data.bones:  # "Hips" etc. are the joint empties' names
        b.name = "m_" + bare(b.name)

    objs = {}
    for j in PARENT:  # parents before children
        if j not in pivots:
            continue
        ob = bpy.data.objects.new(j, None)
        bpy.context.scene.collection.objects.link(ob)
        p = PARENT[j]
        while p and p not in objs:  # no Neck bone: the head sits on the spine
            p = PARENT[p]
        ob.parent = objs.get(p)
        ob.location = pivots[j] - (pivots[p] if p in objs else Vector())
        objs[j] = ob
        meshes, was = props.get(j, ([], None))
        for me in meshes:  # into this hand, shifted by how far its centre moved from the old one
            me.transform(Matrix.Translation(box_centre(grip.get(j, [])) - was))
            pr = bpy.data.objects.new("prop", me)
            bpy.context.scene.collection.objects.link(pr)
            pr.parent = ob
    update()
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_animations=False,
                              export_skins=True, export_apply=False)
    print("WROTE", out, "scale %.3f" % k, "props", list(props), "bones", len(arm.data.bones))


if __name__ == "__main__":
    want = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(CAST)
    for key in want:
        convert(key, *CAST[key])
