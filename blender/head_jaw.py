"""A talking jaw for a head made apart from its body (vault Build/Character Creator and Layered Figures.md, 3.5b).

Tripo's heads are one closed, unrigged mesh with the face painted on, so nothing can open the mouth. This cuts the
mesh along the lip line between the mouth's corners (so the lips can part), puts a small dark mouth inside behind them,
and gives the head a two-bone armature, Root and Jaw (its hinge in front of the ears), with the chin and lower lip
weighted to the jaw and fading out over the cheeks and above the neck. Godot opens the jaw with the voice
(TalkMotion's JawOpen). Run headless, no render:

  blender -b --factory-startup --python blender/head_jaw.py -- <in.glb> <out.glb> <mouth z> <left x> <right x> <chin z>

All lengths are the head's own units as Tripo exports it (y up, about one unit tall, facing +z; Blender reads it as z up
facing -y). The mouth is found by eye once per head from the picture the head was made from (tools/art/figures.py's
manifest keeps the numbers beside the head).
"""
import bmesh
import bpy
import math
import sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]
mouth_z, left_x, right_x, chin_z = (float(a) for a in args[2:6])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
head = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
bpy.context.view_layer.objects.active = head
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = head.data
cx = (left_x + right_x) / 2.0
half = (right_x - left_x) / 2.0

# The face's front at the mouth: the most forward point of the skin near the lip line (Blender's front is -y).
near = [v.co for v in me.vertices if abs(v.co.x - cx) < half and abs(v.co.z - mouth_z) < 0.03]
front_y = min(v.y for v in near)
chin = [v.co for v in me.vertices if abs(v.co.x - cx) < half and abs(v.co.z - chin_z) < 0.03]
chin_y = min(v.y for v in chin) if chin else front_y

# 1. The lip line: a cut across the front of the face at the mouth's height, opened between the corners only.
bm = bmesh.new()
bm.from_mesh(me)
region = [f for f in bm.faces if all(abs(v.co.z - mouth_z) < 0.04 and v.co.y < front_y + 0.09 and abs(v.co.x - cx) < half + 0.03 for v in f.verts)]
geom = list({v for f in region for v in f.verts}) + list({e for f in region for e in f.edges}) + region
cut = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0.0, 0.0, mouth_z), plane_no=(0.0, 0.0, 1.0))
lip_edges = [e for e in cut["geom_cut"] if isinstance(e, bmesh.types.BMEdge)
             and abs((e.verts[0].co.x + e.verts[1].co.x) / 2.0 - cx) < half * 0.92]
bmesh.ops.split_edges(bm, edges=lip_edges)
bm.to_mesh(me)
bm.free()

# 2. The inside of the mouth: a flattened dark pocket just behind the lips.
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0, location=(cx, front_y + 0.045, mouth_z - 0.008))
inside = bpy.context.active_object
inside.name = "mouth_inside"
inside.scale = (half * 1.05, 0.04, 0.03)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
dark = bpy.data.materials.new("mouth_inside")
dark.use_nodes = True
bsdf = dark.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = (0.09, 0.02, 0.03, 1.0)
bsdf.inputs["Roughness"].default_value = 1.0
inside.data.materials.append(dark)

# 3. The armature: Root at the head's base, Jaw hinged in front of the ears a little above the mouth, reaching to the chin.
hinge = Vector((cx, front_y + 0.20, mouth_z + 0.05))
arm_data = bpy.data.armatures.new("HeadRig")
rig = bpy.data.objects.new("HeadRig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
root = arm_data.edit_bones.new("Root")
root.head = (cx, front_y + 0.25, 0.0)
root.tail = (cx, front_y + 0.25, 0.1)
jaw = arm_data.edit_bones.new("Jaw")
jaw.head = hinge
jaw.tail = (cx, chin_y, chin_z)
jaw.parent = root
jaw.roll = 0.0
bpy.ops.object.mode_set(mode='OBJECT')


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


# 4. Weights: the jaw takes what lies below the lip line, in front of the hinge, within the jaw's width, above the neck.
jaw_w = max(half * 2.4, 0.12)
neck_z = chin_z - 0.05
for ob, pocket in ((head, False), (inside, True)):
    g_root = ob.vertex_groups.new(name="Root")
    g_jaw = ob.vertex_groups.new(name="Jaw")
    for v in ob.data.vertices:
        p = v.co
        if pocket:
            w = 1.0 if p.z < mouth_z - 0.008 else 0.0
        elif p.z >= mouth_z:
            w = 0.0
        else:
            ahead = smooth((hinge.y - p.y) / max(hinge.y - front_y, 0.01) * 1.4)
            inward = smooth(1.0 - (abs(p.x - cx) - half) / max(jaw_w - half, 0.01))
            above_neck = smooth((p.z - neck_z) / max(chin_z - neck_z, 0.01))
            # Just under the lip line the lower lip moves whole; higher up the cheeks it fades.
            w = ahead * inward * above_neck
        g_root.add([v.index], 1.0 - w, 'REPLACE')
        g_jaw.add([v.index], w, 'REPLACE')
    ob.parent = rig
    mod = ob.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig

bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_skins=True, export_animations=False, export_yup=True)
print(f"JAW {dst}: mouth z {mouth_z} x {left_x}..{right_x}, chin z {chin_z}, front y {front_y:.3f}, lip edges {len(lip_edges)}")
