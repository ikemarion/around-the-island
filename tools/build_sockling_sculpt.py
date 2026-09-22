"""Reproducible Blender source for the Sockling's continuous fabric forms.
Run with Blender --background --python tools/build_sockling_sculpt.py.
Coordinates in helpers are Godot-local (Y up, face +Z), in metres.
"""
import bpy
from mathutils import Vector
from math import sin, cos
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "characters" / "sockling"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def coord(p):
    return (p[0], -p[2], p[1])

def material(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = .9
    return m

fleece = material("Fleece", (.72, .43, .07))
mouth = material("Mouth", (.055, .014, .008))
sock_foot = material("SockFoot", (.58,.22,.17))

def ellipsoid(name, center, radius):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, location=coord(center))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (radius[0], radius[2], radius[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj

def tube(name, points, radius):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 20
    curve.bevel_depth = radius
    curve.bevel_resolution = 5
    curve.use_fill_caps = True
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points)-1)
    for bp, point in zip(spline.bezier_points, points):
        bp.co = coord(point)
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object

def fuse(name, parts, voxel=.009):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    # Identity transforms are important: gameplay uses the same local anchors.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mod = obj.modifiers.new("Continuous fabric volume", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    mod.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Stuffed softness", "SMOOTH")
    mod.factor = 1.1
    mod.iterations = 5
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.clear()
    obj.data.materials.append(fleece)
    return obj

def finish(obj, ratio=.42):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Game topology", "DECIMATE")
    mod.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.update()
    return obj

# Continuous shoulder/neck/head volume. The mouth is actually cut into it,
# leaving a connected fabric cheek and thick lower lip, not stacked pancakes.
body = fuse("Body", [
    ellipsoid("Torso", (0,-.065,-.035), (.222,.435,.192)),
    ellipsoid("Neck", (0,.22,-.050), (.225,.31,.190)),
    ellipsoid("Skull", (0,.405,.045), (.282,.288,.262)),
    ellipsoid("Upper snout", (0,.472,.145), (.290,.185,.205)),
    ellipsoid("Chin", (0,.223,.092), (.265,.145,.245)),
], .008)
body.data.materials.append(mouth)
cutter = ellipsoid("Mouth opening", (0,.382,.320), (.264,.128,.367))
cutter.data.materials.append(mouth)
bpy.context.view_layer.objects.active = body
mod = body.modifiers.new("Puppet mouth cavity", "BOOLEAN")
mod.operation = "DIFFERENCE"
mod.solver = "EXACT"
mod.object = cutter
bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.data.objects.remove(cutter, do_unlink=True)
# A small rolled edge prevents a razor-thin lip silhouette.
mod = body.modifiers.new("Rolled cloth lips", "BEVEL")
mod.width = .013
mod.segments = 3
mod.limit_method = "ANGLE"
mod.angle_limit = .42
bpy.ops.object.modifier_apply(modifier=mod.name)
finish(body, .46)

def smoothstep(a, b, x):
    t = max(0, min(1, (x-a)/(b-a)))
    return t*t*(3-2*t)

def soft_joint(obj, name, hinge, angle, start, end):
    """A cloth elbow/knee fold, with a smooth bend instead of a hard seam."""
    obj.shape_key_add(name="Basis")
    key = obj.shape_key_add(name=name)
    for v in key.data:
        x, z, y = v.co.x, -v.co.y, v.co.z
        weight = smoothstep(start, end, -y)
        a = angle*weight
        dy, dz = y-hinge[1], z-hinge[2]
        v.co.z = hinge[1]+dy*cos(a)-dz*sin(a)
        v.co.y = -(hinge[2]+dy*sin(a)+dz*cos(a))

body.shape_key_add(name="Basis")
jaw_key = body.shape_key_add(name="JawOpen")
for v in jaw_key.data:
    x, z, y = v.co.x, -v.co.y, v.co.z
    weight = smoothstep(.04,.21,y)*(1-smoothstep(.285,.36,y))*smoothstep(-.02,.15,z)
    angle = .24*weight
    dy, dz = y-.20, z+.10
    v.co.z = .20+dy*cos(angle)-dz*sin(angle)
    v.co.y = -(-.10+dy*sin(angle)+dz*cos(angle))

for side, name in [(-1,"LeftArm"),(1,"RightArm")]:
    wrist = Vector((side*.32,-.36,.075))
    def hand_point(offset):
        angle = .95 if side == 1 else 0
        x,y,z = offset
        return wrist+Vector((x*cos(angle)-y*sin(angle),x*sin(angle)+y*cos(angle),z))
    parts = [tube("Soft elbow", [(0,0,0),(side*.17,-.06,0),(side*.29,-.20,.020),tuple(wrist)], .064)]
    parts.append(ellipsoid("Mitten palm", tuple(wrist), (.102,.098,.059)))
    # Three softly merged lobes and a short thumb; no bead-like knuckles.
    for finger in range(3):
        x = (finger-1)*.062
        start = hand_point((x,-.028,0))
        end = hand_point((x*1.45,-.134+abs(finger-1)*.018,.015))
        parts.append(tube("Finger", [tuple(start),tuple((start+end)/2),tuple(end)], .036))
        parts.append(ellipsoid("Finger tip", tuple(end), (.036,.038,.036)))
    thumb = hand_point((.131,-.010,.027))
    parts.append(tube("Thumb", [tuple(hand_point((.055,.017,0))),tuple(thumb)], .041))
    parts.append(ellipsoid("Thumb tip",tuple(thumb),(.042,.041,.041)))
    arm = finish(fuse(name,parts,.0065),.36)
    soft_joint(arm, "ElbowFlex", (side*.23,-.14,.012), -.90, .075, .225)

for side, name in [(-1,"LeftLeg"),(1,"RightLeg")]:
    leg = fuse(name,[
        tube("Bent knee",[(0,0,0),(side*.055,-.13,-.045),(side*.060,-.23,.025)],.080),
        ellipsoid("Padded sock foot",(side*.050,-.305,.09),(.132,.105,.20)),
    ],.007)
    leg.data.materials.append(sock_foot)
    for poly in leg.data.polygons:
        if poly.center.z < -.230:
            poly.material_index = 1
    finish(leg,.43)
    soft_joint(leg, "KneeFlex", (side*.055,-.13,-.045), .90, .08, .20)

foot = ellipsoid("Foot", (0,0,0), (.137,.10,.205))
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
foot.data.materials.append(fleece)
finish(foot,.8)

bpy.ops.object.select_all(action="SELECT")
# Keep authoring source as well as engine-ready geometry.
source = ROOT / "tools" / "sculpt-source"
source.mkdir(exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(source / "sockling-sculpt.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "sockling-sculpt.glb"), export_format="GLB", use_selection=True, export_materials="EXPORT", export_yup=True)
for obj in bpy.context.selected_objects:
    if obj.type == "MESH":
        obj.data.calc_loop_triangles()
        print("SOCKLING_MESH", obj.name, len(obj.data.loop_triangles), "triangles")
print("SOCKLING_SCULPT_BAKE PASS", OUT)
