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

def tube(name, points, radius, radii=None):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 20
    curve.bevel_depth = radius
    curve.bevel_resolution = 5
    curve.use_fill_caps = True
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points)-1)
    for index, (bp, point) in enumerate(zip(spline.bezier_points, points)):
        bp.co = coord(point)
        if radii is not None:
            bp.radius = radii[index]
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
    ellipsoid("Torso", (0,-.045,-.035), (.238,.435,.195)),
    ellipsoid("Sock heel under cuff", (0,-.405,-.035), (.227,.150,.190)),
    ellipsoid("Neck", (0,.24,-.015), (.249,.325,.206)),
    ellipsoid("Skull", (0,.435,.055), (.314,.270,.254)),
    # Broad upper lip projects past the lower lip: a floppy sock muzzle,
    # not a spherical head with a tall, circular hole cut through it.
    ellipsoid("Upper snout", (0,.500,.205), (.335,.135,.280)),
    ellipsoid("Chin", (0,.277,.140), (.305,.103,.265)),
], .008)
body.data.materials.append(mouth)
cutter = ellipsoid("Mouth opening", (0,.390,.365), (.285,.104,.420))
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
finish(body, .42)

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
    # A relaxed hanging arm is a useful bind pose, unlike the old poster-like
    # permanent reach. Runtime shoulder/elbow/wrist bones supply the action.
    wrist = Vector((side*.16,-.575,.055))
    def hand_point(offset):
        x,y,z = offset
        x *= side
        angle = side*.48
        return wrist+Vector((x*cos(angle)+z*sin(angle),y,-x*sin(angle)+z*cos(angle)))
    parts = [tube("Tapered soft arm", [(0,0,0),(side*.080,-.15,-.022),
        (side*.135,-.30,-.025),(side*.155,-.445,.012),tuple(wrist)],
        .070,[1.10,1.02,.92,.84,.80])]
    parts.append(ellipsoid("Shoulder cap",(0,-.014,0),(.081,.090,.080)))
    parts.append(ellipsoid("Mitten palm",tuple(wrist),(.094,.104,.065)))
    # Three broad rounded lobes, slightly cupped, with an inward-facing thumb.
    # Both hands have the same relaxed orientation instead of a fixed wave.
    for finger in range(2):
        x = (finger-.5)*.080
        start = hand_point((x,-.025,0))
        end = hand_point((x*1.16,-.141+finger*.020,.025))
        middle = hand_point((x*1.09,-.095,.006))
        parts.append(tube("Mitten finger",[tuple(start),tuple(middle),tuple(end)],.045))
        parts.append(ellipsoid("Mitten tip",tuple(end),(.047,.050,.045)))
    thumb = hand_point((-.111,-.020,.036))
    parts.append(tube("Thumb",[tuple(hand_point((-.050,.010,.008))),tuple(thumb)],.046))
    parts.append(ellipsoid("Thumb tip",tuple(thumb),(.049,.049,.046)))
    arm = finish(fuse(name,parts,.0065),.32)
    # No arm shape-key interpolation: the runtime rig bends a fixed-length
    # chain and skins the continuous surface with soft joint weights.

for side, name in [(-1,"LeftLeg"),(1,"RightLeg")]:
    leg = fuse(name,[
        tube("Bent knee",[(0,0,0),(side*.120,-.105,-.055),(side*.100,-.24,.020)],.087),
        ellipsoid("Padded sock foot",(side*.110,-.320,.070),(.177,.081,.179)),
    ],.007)
    leg.data.materials.append(sock_foot)
    for poly in leg.data.polygons:
        if poly.center.z < -.230:
            poly.material_index = 1
    finish(leg,.34)
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
