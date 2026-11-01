"""Arms straight out to the sides in a body's rest T-pose (vault Build/Character Creator and Layered Figures.md).

A Tripo body made from a side sheet drawn three-quarter comes out with its T-pose arms swung round the body: Phillip's
left hand sat 0.3 ahead of his shoulders and his right 0.3 behind. Each clip is keyed against that rest, so the arms
bend from a crooked start: shoulders and armpits blend wrong. This turns each upper arm (forearm and hand with it)
about the vertical through its shoulder joint until it points straight out to its side, bakes the skin into that
shape and makes it the rest pose. Tripo keyed the clips against the old rest, so each clip's upper-arm keys are
re-keyed against the new one: every clip poses the arms exactly as before. Then it writes the body back out with
every clip. Run headless, no render:

  blender -b --factory-startup --python blender/arm_level.py -- <in.glb> <out.glb>

Prints each arm's swing before and after (degrees off straight out, seen from above).
"""
import bpy
import math
import sys
from mathutils import Matrix, Quaternion, Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
body = [o for o in arm.children if o.type == 'MESH'][0]


def bone(name: str) -> str:
    return [b.name for b in arm.data.bones if b.name.endswith(name)][0]


def swing(side: str) -> float:
    """How far `side`'s arm points off straight out, seen from above, in degrees (the hand from the arm's joint)."""
    pb = arm.pose.bones
    v = pb[bone(side + "Hand")].head - pb[bone(side + "Arm")].head
    want = 0.0 if side == "Left" else math.pi   # Blender's left is +x
    d = math.atan2(v.y, v.x) - want
    return math.degrees(math.atan2(math.sin(d), math.cos(d)))


def local_rest(name: str) -> Matrix:
    b = arm.data.bones[name]
    return (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local.copy()


arm_bones = [bone("LeftArm"), bone("RightArm")]
was = {n: local_rest(n) for n in arm_bones}

# Hold the rest pose still: no action or clip track drives it while it is turned.
ad = arm.animation_data
active = ad.action if ad else None
if ad:
    ad.action = None
    for t in ad.nla_tracks:
        t.mute = True
for pb in arm.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)   # a clip's last frame stays on the bones after its action is taken off
bpy.context.view_layer.update()

for side in ("Left", "Right"):
    before = swing(side)
    pb = arm.pose.bones[bone(side + "Arm")]
    at = pb.head.copy()
    turn = Matrix.Translation(at) @ Matrix.Rotation(math.radians(-before), 4, 'Z') @ Matrix.Translation(-at)
    pb.matrix = turn @ pb.matrix
    bpy.context.view_layer.update()
    print("ARM %s swing %.1f -> %.1f degrees" % (side, before, swing(side)))

# The skin into the new shape: a copy of its armature modifier, first in the stack, applied.
bpy.context.view_layer.objects.active = body
for o in bpy.context.scene.objects:
    o.select_set(o == body)
skin = [m for m in body.modifiers if m.type == 'ARMATURE'][0]
bpy.ops.object.modifier_copy(modifier=skin.name)
copy = body.modifiers[-1].name
bpy.ops.object.modifier_move_to_index(modifier=copy, index=0)
bpy.ops.object.modifier_apply(modifier=copy)

# That pose becomes the rest.
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode='OBJECT')

def curves_of(action) -> list:
    """An action's curves: Blender 4.4 on keeps them in layers of strips, one bag per slot."""
    if hasattr(action, "fcurves"):
        return list(action.fcurves)
    return [c for layer in action.layers for strip in layer.strips for bag in strip.channelbags for c in bag.fcurves]


# Each clip poses the upper arms as before: a key against the old rest K becomes (old rest -> new rest)^-1 K.
for n in arm_bones:
    fix = (was[n].inverted() @ local_rest(n)).to_quaternion().inverted()
    rot = 'pose.bones["%s"].rotation_quaternion' % n
    loc = 'pose.bones["%s"].location' % n
    for action in bpy.data.actions:
        for path, size in ((rot, 4), (loc, 3)):
            have = {(c.data_path, c.array_index): c for c in curves_of(action)}
            curves = [have.get((path, i)) for i in range(size)]
            if any(c is None for c in curves):
                continue
            frames = sorted({k.co[0] for c in curves for k in c.keyframe_points})
            values = [[c.evaluate(f) for c in curves] for f in frames]
            ip = curves[0].keyframe_points[0].interpolation if curves[0].keyframe_points else 'LINEAR'
            for f_i, f in enumerate(frames):
                v = values[f_i]
                if size == 4:
                    q = fix @ Quaternion(v)
                    values[f_i] = [q.w, q.x, q.y, q.z]
                else:
                    values[f_i] = list(fix @ Vector(v))
            for i, c in enumerate(curves):
                c.keyframe_points.clear()
                c.keyframe_points.add(len(frames))
                for k, f in zip(c.keyframe_points, frames):
                    k.co = (f, values[frames.index(f)][i])
                    k.interpolation = ip
                c.update()
    print("REKEYED %s in %d clips" % (n, len(bpy.data.actions)))

if ad:
    for t in ad.nla_tracks:
        t.mute = False
    ad.action = active

bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
body.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_image_format='AUTO')
print("WROTE", dst)
