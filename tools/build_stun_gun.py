"""Approved cartoon zapper, built as reusable collision-free Godot art.

Blender --background --python tools/build_stun_gun.py
Authoring coordinates: Godot Y-up; muzzle faces -X; badges on both Z sides.
The approved concept is in docs/art/stun-gun-concept/approved-concept.png.
"""
from math import cos, sin, pi, sqrt
from pathlib import Path

import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "pickups" / "stun-gun"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def coord(p):
    return (p[0], -p[2], p[1])


def linear(value):
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


def material(name, hex_color, roughness=.28, metallic=0, emission=0):
    rgb = tuple(linear(int(hex_color[i:i+2], 16)/255) for i in (0, 2, 4))
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Coat Weight"].default_value = .3
    shader.inputs["Coat Roughness"].default_value = .2
    if emission:
        shader.inputs["Emission Color"].default_value = (*rgb, 1)
        shader.inputs["Emission Strength"].default_value = emission
    return mat


mint = material("Mint enamel", "639f8e", .26)
mint_edge = material("Inset teal edge", "4e978b", .32)
cream = material("Warm cream enamel", "dfceb0", .3)
coral = material("Coral molded grip", "cb7158", .3)
gold = material("Honey gold", "deb04a", .25, .32)
gasket = material("Deep teal lens gasket", "31796e", .4)
lens = material("Cyan charged lens", "32c5df", .2, .05, .12)
glint = material("Lens cartoon glint", "c7ffff", .25, 0, .5)


def mesh_object(name, vertices, faces, mat, smooth=True):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([coord(p) for p in vertices], [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for face in mesh.polygons:
        face.use_smooth = smooth
    return obj


def soften(obj, radius, segments=4):
    bpy.context.view_layer.objects.active = obj
    bevel = obj.modifiers.new("Soft toy edges", "BEVEL")
    bevel.width = radius
    bevel.segments = segments
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = .3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for face in obj.data.polygons:
        face.use_smooth = True
    normals = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    normals.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=normals.name)
    return obj


def spline(points, steps=4):
    """Catmull-Rom interpolation for continuous molded profiles."""
    result = []
    for i in range(len(points)-1):
        p0, p1 = points[max(0, i-1)], points[i]
        p2, p3 = points[i+1], points[min(len(points)-1, i+2)]
        for j in range(steps):
            t = j / steps
            result.append(tuple(.5*((2*p1[k]) + (-p0[k]+p2[k])*t
                + (2*p0[k]-5*p1[k]+4*p2[k]-p3[k])*t*t
                + (-p0[k]+3*p1[k]-3*p2[k]+p3[k])*t*t*t)
                for k in range(len(p1))))
    result.append(points[-1])
    return result


def revolution(name, profile, mat, axis="x", center=(0, .22, 0), segments=48):
    vertices = []
    for at, radius in profile:
        radius = max(.00001, radius)
        for i in range(segments):
            angle = i*2*pi/segments
            if axis == "x":
                p = (at, radius*cos(angle), radius*sin(angle))
            else:
                p = (radius*cos(angle), at, radius*sin(angle))
            vertices.append(tuple(p[k]+center[k] for k in range(3)))
    faces = []
    for row in range(len(profile)-1):
        for i in range(segments):
            a = row*segments+i
            b = row*segments+(i+1)%segments
            faces.append((a, b, b+segments, a+segments))
    faces += [tuple(reversed(range(segments))),
              tuple(range((len(profile)-1)*segments, len(profile)*segments))]
    return mesh_object(name, vertices, faces, mat)


def solid(name, contour, back, front, mat, bevel=.018):
    n = len(contour)
    vertices = [(x, y, z) for z in (back, front) for x, y in contour]
    faces = [tuple(reversed(range(n))), tuple(range(n, n*2))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    obj = mesh_object(name, vertices, faces, mat)
    return soften(obj, bevel) if bevel else obj


def ellipse(x, y, rx, ry, count=64):
    return [(x+rx*cos(i*2*pi/count), y+ry*sin(i*2*pi/count)) for i in range(count)]


def rounded_rect(x, y, width, height, radius, steps=8):
    points = []
    for px, py, start in [(width/2-radius,height/2-radius,0),
                         (-width/2+radius,height/2-radius,pi/2),
                         (-width/2+radius,-height/2+radius,pi),
                         (width/2-radius,-height/2+radius,3*pi/2)]:
        for i in range(steps+1):
            angle = start+i*pi/(2*steps)
            points.append((x+px+radius*cos(angle), y+py+radius*sin(angle)))
    return points


def bezier(outline, a, b, c, d, count=14):
    for i in range(count):
        t = i/count
        outline.append(tuple((1-t)**3*a[k]+3*(1-t)**2*t*b[k]
            +3*(1-t)*t*t*c[k]+t**3*d[k] for k in range(2)))


body_profile = spline([(-.70,.18,.16,.22),(-.62,.32,.25,.23),
    (-.43,.42,.32,.24),(-.15,.455,.36,.24),(.13,.435,.348,.235),
    (.37,.365,.305,.22),(.55,.265,.23,.21),(.65,.15,.15,.205),
    (.69,.01,.01,.205)], 6)
vertices = []
segments = 56
for x, ry, rz, cy in body_profile:
    for i in range(segments):
        a = i*2*pi/segments
        vertices.append((x, cy+ry*cos(a), rz*sin(a)))
faces = []
for row in range(len(body_profile)-1):
    for i in range(segments):
        a, b = row*segments+i, row*segments+(i+1)%segments
        faces.append((a,b,b+segments,a+segments))
faces += [tuple(reversed(range(segments))), tuple(range((len(body_profile)-1)*segments,len(vertices)))]
mesh_object("MintShell", vertices, faces, mint)


def surface_z(x, y):
    for i in range(len(body_profile)-1):
        a, b = body_profile[i], body_profile[i+1]
        if a[0] <= x <= b[0]:
            t = (x-a[0])/(b[0]-a[0])
            ry, rz, cy = [a[k]*(1-t)+b[k]*t for k in range(1,4)]
            return rz*sqrt(max(.01, 1-((y-cy)/ry)**2))
    return .16


def conform_side(obj, side):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=2, use_grid_fill=True)
    bm.to_mesh(obj.data)
    bm.free()
    # Ornament follows the shell; its edge never floats above the egg surface.
    for vertex in obj.data.vertices:
        x, y, depth = vertex.co.x, vertex.co.z, -vertex.co.y
        vertex.co.y = -side*(surface_z(x, y)+depth)
    obj.data.update()
    # Deformed ornaments need geometric normals rather than pre-deform normals.
    if obj.data.has_custom_normals:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    return obj


def badge_patch(name, center, radii, depth, mat, side):
    # Radial interior rings follow the shell as well as the perimeter. A single
    # deformed n-gon would cut through the convex shell after triangulation.
    count = 48
    rings = [(1,.002),(.987,depth*.8),(.96,depth),(.80,depth),
             (.60,depth),(.40,depth),(.20,depth),(.0001,depth)]
    vertices = []
    for radius, offset in rings:
        for i in range(count):
            a = i*2*pi/count
            x = center[0]+radii[0]*radius*cos(a)
            y = center[1]+radii[1]*radius*sin(a)
            vertices.append((x,y,side*(surface_z(x,y)+offset)))
    faces = []
    for row in range(len(rings)-1):
        for i in range(count):
            faces.append((row*count+i,row*count+(i+1)%count,
                (row+1)*count+(i+1)%count,(row+1)*count+i))
    return mesh_object(name,vertices,faces,mat)


# Thick continuous collar, with gold seat behind it and a teal lens gasket.
revolution("RearCollarGoldBand", spline([(-.57,.18),(-.57,.305),(-.585,.335),
    (-.625,.349),(-.67,.345),(-.68,.32),(-.68,.18)]), gold)
revolution("CreamMuzzleCollar", spline([(-.63,.30),(-.64,.355),(-.675,.389),
    (-.73,.397),(-.815,.397),(-.862,.375),(-.876,.34),(-.865,.282),
    (-.82,.30),(-.68,.30),(-.63,.30)]), cream)
revolution("LensGoldSeat", spline([(-.85,.295),(-.86,.32),(-.886,.342),
    (-.919,.337),(-.933,.315),(-.923,.300),(-.88,.290),(-.85,.295)]), gold)
revolution("LensTealSeal", spline([(-.915,.294),(-.93,.312),(-.95,.325),
    (-.965,.321),(-.963,.299),(-.94,.293),(-.915,.294)]), gasket)
revolution("CyanLens", [(-.965-.196*cos(i*pi/2/22),.315*sin(i*pi/2/22))
    for i in range(23)]+[(-.944,.30),(-.944,0)], lens)
revolution("RearGoldCap", spline([(.51,.13),(.525,.215),(.55,.243),
    (.615,.235),(.683,.199),(.732,.139),(.752,0)]), gold)

# Small gold dome, like the ready indicator of a rounded retro appliance.
revolution("ReadyLampRim", spline([(-.014,0),(-.01,.135),(.005,.145),
    (.025,.135),(.025,0)]), gold, "y", (.11,.655,0), 48)
revolution("ReadyLamp", [(sin(i*pi/2/16)*.107, cos(i*pi/2/16)*.107)
    for i in range(17)], gold, "y", (.11,.671,0), 48)

# A continuously curved, oval-section grip rather than an extruded flat panel.
grip_profile = spline([(-.115,.08,.235,.165),(-.21,.07,.195,.16),
    (-.34,.07,.17,.149),(-.46,.105,.174,.155),(-.59,.16,.20,.17),
    (-.69,.175,.21,.172),(-.745,.17,.18,.148)],5)
vertices = []
count = 48
for y,cx,rx,rz in grip_profile:
    for i in range(count):
        a = i*2*pi/count
        vertices.append((cx+rx*cos(a),y,rz*sin(a)))
faces = [(r*count+i,r*count+(i+1)%count,(r+1)*count+(i+1)%count,(r+1)*count+i)
         for r in range(len(grip_profile)-1) for i in range(count)]
faces += [tuple(reversed(range(count))),tuple(range((len(grip_profile)-1)*count,len(vertices)))]
mesh_object("CoralGrip",vertices,faces,coral)
vertices = []
foot_profile = spline([(0,-.661),(.86,-.661),(.96,-.674),(1,-.704),
    (.985,-.750),(.92,-.779),(0,-.779)],4)
for r,y in foot_profile:
    for i in range(count):
        a = i*2*pi/count
        x = .17+.242*r*cos(a)
        vertices.append((x,y+.18*(x-.17),.193*r*sin(a)))
faces = [(r*count+i,r*count+(i+1)%count,(r+1)*count+(i+1)%count,(r+1)*count+i)
         for r in range(len(foot_profile)-1) for i in range(count)]
mesh_object("CreamGripFoot",vertices,faces,cream)
trigger = []
bezier(trigger,(-.185,-.18),(-.16,-.165),(-.11,-.17),(-.09,-.19))
bezier(trigger,(-.09,-.19),(-.075,-.27),(-.077,-.37),(-.065,-.405))
bezier(trigger,(-.065,-.405),(-.16,-.43),(-.25,-.4),(-.23,-.35))
bezier(trigger,(-.23,-.35),(-.195,-.29),(-.205,-.25),(-.185,-.18))
solid("CreamTrigger",trigger,-.092,.092,cream,.021)

for side in [-1,1]:
    suffix = "Left" if side == 1 else "Right"
    badge_patch("BadgeBorder"+suffix,(.06,.25),(.297,.271),.014,mint_edge,side)
    badge_patch("CreamBadge"+suffix,(.06,.25),(.278,.253),.029,cream,side)
    bolt = [(.162,.425),(-.065,.245),(.022,.224),(-.047,.074),
            (.18,.273),(.086,.289)]
    conform_side(solid("LightningBadge"+suffix,bolt,.031,.054,gold,.009),side)
    for i in range(3):
        contour = rounded_rect(.433,.357-i*.105,.118,.061,.028)
        # The short vents do not need interior subdivision; their capsule faces
        # are thick enough to remain above the local curvature.
        vent = solid("GoldVent%d%s"%(i+1,suffix),contour,.002,.035,gold,.012)
        for vertex in vent.data.vertices:
            x,y,depth = vertex.co.x,vertex.co.z,-vertex.co.y
            vertex.co.y = -side*(surface_z(x,y)+depth)
    stud = solid("GripStud"+suffix,ellipse(.17,-.32,.049,.059,40),.136,.167,gold,.012)
    if side == -1:
        for vertex in stud.data.vertices:
            vertex.co.y *= -1

# A small molded glint hugs the lens rather than using a bloom-dependent sprite.
# It remains readable in the game's Compatibility renderer without transparency.
for name, center, size in [("LensGlint",(.15,.12),(.045,.033)),
                          ("LensGlintDot",(.235,.06),(.013,.018))]:
    vertices = []
    for ring in [.0001,.35,.7,1.0]:
        for i in range(32):
            a = i*2*pi/32
            y = center[0]+size[0]*ring*cos(a)
            z = center[1]+size[1]*ring*sin(a)
            x = -.965-.196*sqrt(max(0,1-(y/.315)**2-(z/.315)**2))-.002
            vertices.append((x,y+.22,z))
    faces = [(r*32+i,r*32+(i+1)%32,(r+1)*32+(i+1)%32,(r+1)*32+i)
             for r in range(3) for i in range(32)]
    mesh_object(name,vertices,faces,glint)

# Keep the collectible centered over its existing saucer and within its trigger.
for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        for vertex in obj.data.vertices:
            vertex.co.x += .22
            vertex.co.z += .02

bpy.ops.export_scene.gltf(filepath=str(OUT / "stun-gun.glb"),
    export_format="GLB", export_animations=False, export_cameras=False,
    export_lights=False, export_yup=True)
triangles = 0
for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
print("STUN_GUN_ASSET built; triangles=",triangles)
