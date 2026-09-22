"""Rebuild the approved Score Ribbons' rounded, recessed game meshes.

Blender --background --python tools/build_score_ribbons.py
Authoring coordinates use Godot's Y-up, +Z-front convention. No collision.
"""
from math import cos, sin, pi
from pathlib import Path

import bpy
import bmesh


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "scoreboards"
OUT.mkdir(parents=True, exist_ok=True)


def coord(p):
    return (p[0], -p[2], p[1])


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def mat(name, color, roughness=.32, metallic=0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return material


# Linear-light material values; Godot imports GLTF colors in the same space.
cream = mat("Warm ceramic", (.70, .59, .42), .48)
well = mat("Recess shadow", (.53, .43, .29), .56)
mint = mat("Mint enamel", (.15, .42, .31), .38)
gold = mat("Honey gold", (.93, .59, .10), .24, .32)


def rounded_rect(width, height, radius, center=(0, 0), steps=12):
    points = []
    for x, y, start in [(width/2-radius, height/2-radius, 0),
                         (-width/2+radius, height/2-radius, pi/2),
                         (-width/2+radius, -height/2+radius, pi),
                         (width/2-radius, -height/2+radius, 3*pi/2)]:
        for i in range(steps+1):
            angle = start + i*pi/(2*steps)
            points.append((center[0]+x+radius*cos(angle), center[1]+y+radius*sin(angle)))
    return points


def solid(name, contour, back, front, material, bevel=.06):
    n = len(contour)
    vertices = [coord((x, y, z)) for z in [back, front] for x, y in contour]
    faces = [tuple(reversed(range(n))), tuple(range(n, n*2))]
    faces.extend((i, (i+1) % n, (i+1) % n+n, i+n) for i in range(n))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    if bevel:
        soften(obj, bevel)
    return obj


def soften(obj, radius):
    bpy.context.view_layer.objects.active = obj
    bevel = obj.modifiers.new("Soft ceramic edges", "BEVEL")
    bevel.width = radius
    bevel.segments = 5
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = .35
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for face in obj.data.polygons:
        face.use_smooth = True
    weighted = obj.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL")
    weighted.keep_sharp = True
    weighted.weight = 50
    bpy.ops.object.modifier_apply(modifier=weighted.name)


def export(name):
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name+".glb")),
        export_format="GLB", export_animations=False, export_cameras=False,
        export_lights=False, export_yup=True)


clear()
# A rounded pennant with a shallow, soft V at the foot.
outline = []
def bezier(a, b, c, d, count=12):
    for i in range(count):
        t = i/count
        outline.append(tuple((1-t)**3*a[j] + 3*(1-t)**2*t*b[j]
                             + 3*(1-t)*t*t*c[j] + t**3*d[j] for j in range(2)))

bezier((0,.30), (-.25,.24), (-.80,-.03), (-1.02,.04))
bezier((-1.02,.04), (-1.20,.09), (-1.20,.31), (-1.20,.60))
outline.append((-1.20,7.18))
bezier((-1.20,7.18), (-1.20,7.70), (-.88,7.86), (-.50,7.88))
bezier((-.50,7.88), (-.18,7.91), (.18,7.91), (.50,7.88))
bezier((.50,7.88), (.88,7.86), (1.20,7.70), (1.20,7.18))
outline.append((1.20,.60))
bezier((1.20,.60), (1.20,.31), (1.20,.09), (1.02,.04))
bezier((1.02,.04), (.80,-.03), (.25,.24), (0,.30))
panel = solid("RibbonShell", outline, -.24, .24, cream, 0)
slot = rounded_rect(1.12, 4.65, .54, (0, 4.20))
cutter = solid("PocketCutter", slot, -.025, .65, cream, 0)
bpy.context.view_layer.objects.active = panel
cut = panel.modifiers.new("True recessed score channel", "BOOLEAN")
cut.operation = "DIFFERENCE"
cut.solver = "EXACT"
cut.object = cutter
bpy.ops.object.modifier_apply(modifier=cut.name)
bpy.data.objects.remove(cutter, do_unlink=True)
soften(panel, .085)
solid("RecessFloor", rounded_rect(.98,4.49,.47,(0,4.20)), -.025, -.012, well, .004)
export("score-ribbon")

clear()
solid("MintTimerRim", rounded_rect(7.55,2.65,1.12), -.28,.22,mint,.11)
solid("CreamTimerFace", rounded_rect(7.19,2.28,.99), .16,.32,cream,.075)
for side in [-1,1]:
    for up in [-1,1]:
        ray = solid("TimerAccent", rounded_rect(.42,.095,.045), -.035,.035,gold,.02)
        ray.location = coord((side*3.01,up*.22,.38))
        ray.rotation_euler.y = -side*up*.38
export("score-timer")

clear()
# A small hollow crown with rounded lobes and toy-like ball tips.
count = 100
vertices = []
for ring in range(4):
    for i in range(count):
        angle = 2*pi*i/count
        radius = [.48,.68,.57,.38][ring]
        y = .08 if ring in [0,3] else .60 + .20*cos(5*angle)
        vertices.append(coord((radius*sin(angle),y,radius*cos(angle))))
faces = []
for ring in range(4):
    for i in range(count):
        faces.append((ring*count+i,ring*count+(i+1)%count,
                      ((ring+1)%4)*count+(i+1)%count,((ring+1)%4)*count+i))
mesh = bpy.data.meshes.new("Rounded crown")
mesh.from_pydata(vertices,[],faces)
bm = bmesh.new()
bm.from_mesh(mesh)
bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
bm.to_mesh(mesh)
bm.free()
crown = bpy.data.objects.new("Crown",mesh)
bpy.context.collection.objects.link(crown)
crown.data.materials.append(gold)
soften(crown,.045)
for i in range(5):
    angle = 2*pi*i/5
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=.11,
        location=coord((.62*sin(angle),.80,.62*cos(angle))))
    tip = bpy.context.object
    tip.name = "RoundedTip"
    tip.data.materials.append(gold)
    for face in tip.data.polygons:
        face.use_smooth = True
export("score-crown")
print("SCORE_RIBBONS_ASSETS built ribbon, timer, crown")
