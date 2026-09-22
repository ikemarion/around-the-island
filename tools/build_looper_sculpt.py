"""Rebuild the Looper's continuous plush sculpt and reproducible Blender source.

Run: Blender --background --python tools/build_looper_sculpt.py
Helpers take Godot-local metres: Y up, face +Z. Body/face/loop positions
are baked into chest coordinates. Arms and legs use separate local anchors.
The open handle silhouette, sleepy inset eyes, and soft mitten hands follow
the approved Little Weirdos / J - Loopers character reference.
"""
import bpy
from mathutils import Vector
from math import sin, cos, pi, sqrt
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "characters" / "looper"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def coord(p):
    return (p[0], -p[2], p[1])


def material(name, color, roughness=.94):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


fabric = material("LooperFabric", (.40, .30, .51))
cuff = material("Cuff", (.86, .79, .63))
ivory = material("Ivory", (.90, .84, .69))
ink = material("Ink", (.038, .032, .043), .74)


def ellipsoid(name, center, radius, mat=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, location=coord(center))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (radius[0], radius[2], radius[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    return obj


def tube(name, points, radius, radii=None, closed=False):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 12
    curve.bevel_depth = radius
    curve.bevel_resolution = 5
    curve.use_fill_caps = not closed
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    spline.use_cyclic_u = closed
    for i, (bp, point) in enumerate(zip(spline.bezier_points, points)):
        bp.co = coord(point)
        bp.radius = radii[i] if radii else 1
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


def join(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def fuse(name, parts, voxel=.008):
    obj = join(name, parts)
    mod = obj.modifiers.new("Continuous stuffed plush", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    mod.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Soft hand stuffed contours", "SMOOTH")
    mod.factor = 1.08
    mod.iterations = 6
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.clear()
    obj.data.materials.append(fabric)
    return obj


def finish(obj, ratio=1):
    bpy.context.view_layer.objects.active = obj
    if ratio < 1:
        mod = obj.modifiers.new("Game topology", "DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.update()
    return obj


def smoothstep(a, b, x):
    t = max(0, min(1, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def soft_joint(obj, name, hinge, angle, start, end):
    obj.shape_key_add(name="Basis")
    key = obj.shape_key_add(name=name)
    for v in key.data:
        x, z, y = v.co.x, -v.co.y, v.co.z
        weight = smoothstep(start, end, -y)
        a = angle * weight
        dy, dz = y - hinge[1], z - hinge[2]
        v.co.z = hinge[1] + dy * cos(a) - dz * sin(a)
        v.co.y = -(hinge[2] + dy * sin(a) + dz * cos(a))


# One smooth loft avoids intersection ridges from a stack of ellipsoids.
# Each section is (height, half-width, front/back center, half-depth).
# The wide hips continue into a short waist and a broad head without a chin
# shelf, lip, or separate ball. Rearward belly -> forward head gives the S.
BODY_PROFILE = [
    (-.473, .000, -.050, .000), (-.460, .080, -.050, .074),
    (-.433, .159, -.049, .132), (-.380, .226, -.047, .181),
    (-.290, .269, -.040, .211), (-.185, .273, -.023, .217),
    (-.080, .242, -.006, .204), (.020, .208, .012, .184),
    (.120, .228, .030, .207), (.220, .303, .044, .251),
    (.320, .330, .052, .259), (.415, .337, .053, .255),
    (.510, .316, .050, .236), (.590, .268, .045, .198),
    (.650, .197, .042, .151), (.687, .109, .041, .087),
    (.703, .000, .041, .000),
]


def body_section(y):
    i = 0
    while i < len(BODY_PROFILE) - 2 and BODY_PROFILE[i + 1][0] < y:
        i += 1
    a, b = BODY_PROFILE[i], BODY_PROFILE[i + 1]
    previous = BODY_PROFILE[max(0, i - 1)]
    following = BODY_PROFILE[min(len(BODY_PROFILE) - 1, i + 2)]
    span = b[0] - a[0]
    t = max(0, min(1, (y - a[0]) / span))
    result = []
    for axis in (1, 2, 3):
        slope_a = (b[axis] - previous[axis]) / (b[0] - previous[0])
        slope_b = (following[axis] - a[axis]) / (following[0] - a[0])
        result.append((2*t**3 - 3*t**2 + 1)*a[axis] +
                      (t**3 - 2*t**2 + t)*span*slope_a +
                      (-2*t**3 + 3*t**2)*b[axis] +
                      (t**3 - t**2)*span*slope_b)
    return result


vertices, faces = [], []
rows, segments = 160, 96
for row in range(rows + 1):
    y = BODY_PROFILE[0][0] + (BODY_PROFILE[-1][0] - BODY_PROFILE[0][0]) * row / rows
    width, center, depth = body_section(y)
    for segment in range(segments):
        a = segment * 2*pi/segments
        vertices.append(coord((width*cos(a), y, center+depth*sin(a))))
for row in range(rows):
    for segment in range(segments):
        a = row*segments + segment
        b = row*segments + (segment+1) % segments
        faces.append((a, a+segments, b+segments, b))
mesh = bpy.data.meshes.new("Continuous Looper pear")
mesh.from_pydata(vertices, [], faces)
mesh.materials.append(fabric)
mesh.update()
body = bpy.data.objects.new("Body", mesh)
bpy.context.collection.objects.link(body)
finish(body, .92)

# A real empty hole survives from every view; this is not a circle decal.
# A slight forward lean and asymmetric lower join feel like sewn plush.
loop = tube("TopLoop", [
    (-.012 + .122*cos(a)*cos(-.13) - .090*sin(a)*sin(-.13),
     .804 + .122*cos(a)*sin(-.13) + .090*sin(a)*cos(-.13),
     .024 + .017*sin(a))
    for a in [i * 2 * pi / 12 for i in range(12)]
], .057, [1.0 + .035 * sin(i * 2 * pi / 12) for i in range(12)], closed=True)
loop.data.materials.append(fabric)
bpy.context.view_layer.objects.active = loop
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
finish(loop, .75)


def face_surface(x, y):
    # Use the exact loft profile, not an approximate sphere under the face.
    width, center, depth = body_section(y)
    return center + depth * sqrt(max(.03, 1 - (x / max(width, .001)) ** 2))


def eye_bounds(u, cy):
    top = cy + .027 - .014 * u
    return top - .070 * sqrt(max(0, 1 - u * u)), top


def surface_patch(name, left, right, bounds, mat, offset=.005, slices=40):
    # A curved, closed applique rather than a flat floating face sticker.
    # Multiple vertical bands follow the plush cheek under each sleepy eye.
    vertices, faces = [], []
    bands = 8
    for back in (False, True):
        for i in range(slices + 1):
            x = left + (right - left) * i / slices
            low, high = bounds(x)
            for j in range(bands + 1):
                y = low + (high - low) * j / bands
                convex = .0035 * sin(pi * i / slices) * sin(pi * j / bands)
                z = face_surface(x, y) + offset + convex - (.007 if back else 0)
                vertices.append(coord((x, y, z)))
    layer = (slices + 1) * (bands + 1)
    for k in range(2):
        for i in range(slices):
            for j in range(bands):
                a = k * layer + i * (bands + 1) + j
                ids = (a, a + bands + 1, a + bands + 2, a + 1)
                faces.append(ids if k == 0 else ids[::-1])
    perimeter = ([i * (bands + 1) for i in range(slices + 1)] +
                 [slices * (bands + 1) + j for j in range(1, bands + 1)] +
                 [i * (bands + 1) + bands for i in range(slices - 1, -1, -1)] +
                 [j for j in range(bands - 1, 0, -1)])
    for i, a in enumerate(perimeter):
        b = perimeter[(i + 1) % len(perimeter)]
        faces.append((a, a + layer, b + layer, b))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj)


for side, label in [(-1, "Left"), (1, "Right")]:
    cx, cy = side * .126, .471
    eye_width = .097
    def bounds(x, center=cx, center_y=cy):
        return eye_bounds((x - center) / eye_width, center_y)
    surface_patch("Eye" + label, cx - eye_width, cx + eye_width, bounds, ivory)
    # Both pupils glance sideways. Their tops tuck beneath the cloth lids.
    pupil_cx = cx + .046
    pupil_cy = .466
    def pupil_bounds(x, center=pupil_cx, center_y=pupil_cy, eye_bounds_fn=bounds):
        yextent = .030 * sqrt(max(0, 1 - ((x - center) / .026) ** 2))
        low, high = eye_bounds_fn(x)
        return max(low + .001, center_y - yextent), min(high - .0003, center_y + yextent)
    surface_patch("Pupil" + label, pupil_cx - .026, pupil_cx + .026, pupil_bounds, ink, .010, 28)
    # A softly rounded purple upper rim makes the heavy half-lidded gaze read
    # from an oblique camera without adding angry eyebrow rods.
    lid_points = []
    for i in range(9):
        x = cx - eye_width + 2 * eye_width * i / 8
        y = bounds(x)[1] + .005
        lid_points.append((x, y, face_surface(x, y) + .002))
    lid = tube("Lid" + label, lid_points, .0085,
               [.12, .72, 1, 1, 1, 1, 1, .72, .12])
    lid.data.materials.append(fabric)
    finish(lid, .40)

smile_xy = [(-.041, .309), (-.021, .301), (.011, .300), (.042, .306), (.070, .321)]
smile = tube("Smile", [(x, y, face_surface(x, y) + .006) for x, y in smile_xy],
             .008, [.68, 1, 1, 1, .66])
smile.data.materials.append(ink)
finish(smile, .7)

for side, name in [(-1, "LeftArm"), (1, "RightArm")]:
    wrist = Vector((side * .16, -.575, .055))
    def hand_point(offset):
        x, y, z = offset
        x *= side
        angle = side * .34
        return wrist + Vector((x * cos(angle) + z * sin(angle), y,
                               -x * sin(angle) + z * cos(angle)))
    parts = [tube("Continuous curved plush arm", [
        (0, 0, 0), (side * .080, -.15, -.022),
        (side * .135, -.30, -.025), (side * .155, -.445, .012), tuple(wrist),
    ], .073, [1.1, 1.03, .94, .87, .85]),
        ellipsoid("Shoulder cap", (0, -.012, 0), (.086, .10, .084)),
        ellipsoid("Generous soft palm", tuple(hand_point((.002, -.025, .009))),
                  (.108, .118, .082))]
    # Broad rounded mitten lobes, a curled-in thumb, no thin human fingers.
    for finger in range(2):
        x = (finger - .5) * .090
        tip = hand_point((x * 1.04, -.137 + finger * .014, .036))
        parts.append(tube("Puffy mitten lobe", [
            tuple(hand_point((x, -.032, .008))),
            tuple(hand_point((x * 1.08, -.098, .018))), tuple(tip),
        ], .052, [1.07, 1, .96]))
        parts.append(ellipsoid("Rounded finger tip", tuple(tip), (.052, .058, .051)))
    thumb = hand_point((-.111, -.016, .058))
    parts.append(tube("Cupped mitten thumb", [tuple(hand_point((-.049, .010, .015))),
                                               tuple(thumb)], .054))
    parts.append(ellipsoid("Rounded thumb", tuple(thumb), (.055, .058, .053)))
    finish(fuse(name, parts, .0068), .29)

for side, name in [(-1, "LeftLeg"), (1, "RightLeg")]:
    leg = finish(fuse(name, [
        # The upper join bends inward/back into the pear, not out into a
        # separate oval thigh pad. Preserve the long buried reach for swings.
        tube("Soft curved knee", [(-side*.075, .160, -.035),
                                   (-side*.040, .065, -.025),
                                   (-side*.006, 0, -.015),
                                   (side * .087, -.105, -.055),
                                   (side * .105, -.25, .012)],
             .080, [.65, .80, .92, 1, 1]),
        ellipsoid("Buried tapered hip", (-side*.070, .120, -.032), (.059, .090, .060)),
        ellipsoid("Broad padded foot", (side * .11, -.320, .086), (.176, .088, .205)),
    ], .007), .28)
    # Sewn cream ankle ring, part of the same morph so it never floats away.
    ring = tube("Cream ankle cuff", [
        (side * .105 + .088 * cos(a), -.244 + .007 * cos(a), .018 + .086 * sin(a))
        for a in [i * 2 * pi / 12 for i in range(12)]
    ], .034, closed=True)
    ring.data.materials.append(cuff)
    finish(ring, .40)
    leg = join(name, [leg, ring])
    soft_joint(leg, "KneeFlex", (side * .055, -.13, -.045), .90, .08, .20)
    finish(leg)

bpy.ops.object.select_all(action="SELECT")
source = ROOT / "tools" / "sculpt-source"
source.mkdir(exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(source / "looper-sculpt.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "looper-sculpt.glb"), export_format="GLB",
                          use_selection=True, export_materials="EXPORT", export_yup=True)
total = 0
for obj in bpy.context.selected_objects:
    if obj.type == "MESH":
        obj.data.calc_loop_triangles()
        triangles = len(obj.data.loop_triangles)
        total += triangles
        corners = [obj.matrix_world @ Vector(p) for p in obj.bound_box]
        dimensions = tuple(round(v, 4) for v in obj.dimensions)
        print("LOOPER_MESH", obj.name, triangles, "triangles", "Blender dimensions", dimensions,
              "materials", [m.name for m in obj.data.materials])
print("LOOPER_SCULPT_BAKE PASS", total, "triangles", OUT)
