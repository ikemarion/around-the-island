@tool
extends RefCounted
## Visual-only asset kit. Shapes/materials are cached; physics belongs to callers.
const CREAM := Color("f1dfb5")
const CORAL := Color("cd624e")
const TEAL := Color("39756d")
const INK := Color("233e3c")
const GOLD := Color("c49846")
const WOOD := Color("ac743c")
static var shapes: Dictionary = {}
static var mats: Dictionary = {}

static func material(color: Color, roughness := 0.6, metal := 0.0) -> StandardMaterial3D:
	var key := str(color,roughness,metal)
	if mats.has(key): return mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metal
	mats[key] = mat
	return mat

static func rounded(size: Vector3, radius: float) -> ArrayMesh:
	var key := str(size,radius)
	if shapes.has(key): return shapes[key]
	var half := size*0.5
	var r := minf(radius,minf(half.x,minf(half.y,half.z))*0.98)
	var inner := half-Vector3.ONE*r
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u := (axis+1)%3
		var v := (axis+2)%3
		var us: Array[float] = []
		var vs: Array[float] = []
		for t in [-1.0,-0.92,-0.71,-0.38,0.0]:
			us.append(-inner[u]+t*r)
			vs.append(-inner[v]+t*r)
		for t in [0.0,0.38,0.71,0.92,1.0]:
			us.append(inner[u]+t*r)
			vs.append(inner[v]+t*r)
		for sign_value in [-1.0,1.0]:
			for x in us.size()-1:
				for y in vs.size()-1:
					var points: Array[Vector3] = []
					var normals: Array[Vector3] = []
					for corner in [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]:
						var point := Vector3.ZERO
						point[axis] = half[axis]*sign_value
						point[u] = us[corner.x]
						point[v] = vs[corner.y]
						var core := point.clamp(-inner,inner)
						var normal := (point-core).normalized()
						points.append(core+normal*r)
						normals.append(normal)
					for index in ([0,2,1,0,3,2] if sign_value > 0 else [0,1,2,0,2,3]):
						surface.set_normal(normals[index])
						surface.add_vertex(points[index])
	var mesh := surface.commit()
	shapes[key] = mesh
	return mesh

static func piece(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, title: String, roughness := 0.6, metal := 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = title
	part.mesh = mesh
	part.position = at
	part.material_override = material(color,roughness,metal)
	parent.add_child(part)
	return part

static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color, title: String, radius := 0.08, roughness := 0.6) -> MeshInstance3D:
	return piece(parent,rounded(size,radius),at,color,title,roughness)

static func ball(parent: Node3D, size: Vector3, at: Vector3, color: Color, title: String, roughness := 0.4) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1
	shape.radial_segments = 32
	shape.rings = 16
	var part := piece(parent,shape,at,color,title,roughness)
	part.scale = size
	return part

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color, title: String) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = a.distance_to(b)
	shape.radial_segments = 16
	var part := piece(parent,shape,(a+b)*0.5,color,title)
	part.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return part

static func seam(parent: Node3D, size: Vector2, at: Vector3, radius: float, color: Color, title: String, conform := Vector3.ZERO, bevel := 0.0) -> void:
	# Rounded rectangular piping in XY, rather than a painted flat line.
	var points: Array[Vector3] = []
	for corner in 4:
		var signs: Vector2 = [Vector2(1,1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,-1)][corner]
		for step in 7:
			var angle := (corner+float(step)/6)*PI/2
			var p := signs*(size*0.5-Vector2.ONE*radius)+Vector2(cos(angle),sin(angle))*radius
			var point := Vector3(p.x,p.y,0)+at
			if conform != Vector3.ZERO:
				var inner := conform*0.5-Vector3.ONE*bevel
				var distance := Vector2(maxf(0,absf(p.x)-inner.x),maxf(0,absf(p.y)-inner.y)).length_squared()
				point.z = signf(at.z)*(inner.z+sqrt(maxf(0,bevel*bevel-distance))+0.003)
			points.append(point)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var j := (i+1)%points.size()
		var tangent := (points[j]-points[i]).normalized()
		var sideways := tangent.cross(Vector3.BACK)
		for segment in 8:
			var a := TAU*segment/8.0
			var b := TAU*(segment+1)/8.0
			var na := sideways*cos(a)+Vector3.BACK*sin(a)
			var nb := sideways*cos(b)+Vector3.BACK*sin(b)
			for c in [Vector2i(i,0),Vector2i(j,1),Vector2i(j,0),Vector2i(i,0),Vector2i(i,1),Vector2i(j,1)]:
				var n := na if c.y == 0 else nb
				surface.set_normal(n)
				surface.add_vertex(points[c.x]+n*0.009)
	var piping := piece(parent,surface.commit(),Vector3.ZERO,color,title,0.9)
	piping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func make_box(parent: Node3D) -> void:
	var cardboard := box(parent,Vector3.ONE*0.9,Vector3.ZERO,Color("be9059"),"Cardboard",0.016,0.95)
	var paper := ShaderMaterial.new()
	paper.shader = preload("res://scripts/prop_paper.gdshader")
	cardboard.material_override = paper
	box(parent,Vector3(0.86,0.004,0.005),Vector3(0,0.451,0),Color("775338"),"FlapSeam",0.001)
	box(parent,Vector3(0.165,0.006,0.89),Vector3(0,0.453,0),Color("dfb77c"),"TopTape",0.002,0.85)
	for side in [-1,1]:
		box(parent,Vector3(0.165,0.26,0.004),Vector3(0,0.32,side*0.451),Color("dfb77c"),"FoldedTape",0.001,0.85)
		for tooth in 5:
			var torn := SurfaceTool.new()
			torn.begin(Mesh.PRIMITIVE_TRIANGLES)
			for p in [Vector3(-0.0165,0,0),Vector3(0,-0.018,0),Vector3(0.0165,0,0)]:
				torn.set_normal(Vector3(0,0,side))
				torn.add_vertex(p)
			var tip := piece(parent,torn.commit(),Vector3(-0.066+tooth*0.033,0.19,side*0.454),Color("dfb77c"),"TornTape")
			tip.material_override = tip.material_override.duplicate()
			tip.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
			tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box(parent,Vector3(0.30,0.17,0.006),Vector3(-0.18,-0.04,side*0.453),CREAM,"ShippingLabel",0.012,0.95)
		for row in 3:
			box(parent,Vector3(0.18-row*0.025,0.012,0.004),Vector3(-0.18,-0.0-row*0.033,side*0.458),Color("9c886b"),"LabelInk",0.001)
		for x in [0.18,0.27]:
			box(parent,Vector3(0.018,0.09,0.005),Vector3(x,-0.25,side*0.454),TEAL,"UpArrow",0.001)
			var triangle := SurfaceTool.new()
			triangle.begin(Mesh.PRIMITIVE_TRIANGLES)
			for p in [Vector3(-0.037,0,0),Vector3(0,0.06,0),Vector3(0.037,0,0)]:
				triangle.set_normal(Vector3(0,0,side))
				triangle.add_vertex(p)
			var arrow := piece(parent,triangle.commit(),Vector3(x,-0.21,side*0.458),TEAL,"ArrowHead")
			arrow.material_override = material(TEAL).duplicate()
			arrow.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
			arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box(parent,Vector3(0.16,0.018,0.005),Vector3(0.225,-0.31,side*0.454),TEAL,"ArrowBase",0.001)

static func make_couch(parent: Node3D) -> void:
	# Existing collider is centered at Y=.725. The sofa faces -Z.
	box(parent,Vector3(4.65,0.38,1.4),Vector3(0,-0.34,0),CORAL.darkened(0.12),"UpholsteredBase",0.16,0.95)
	box(parent,Vector3(4.55,0.99,0.35),Vector3(0,0.13,0.54),CORAL,"BackSupport",0.16,0.95)
	for x in [-1.4,0.0,1.4]:
		box(parent,Vector3(1.36,0.34,1.12),Vector3(x,-0.06,-0.10),CORAL.lightened(0.07),"SeatCushion",0.165,0.95)
		var piping := Node3D.new()
		parent.add_child(piping)
		piping.position = Vector3(x,0.075,-0.10)
		piping.rotation.x = PI/2
		seam(piping,Vector2(1.27,1.02),Vector3.ZERO,0.14,CORAL.lightened(0.22),"SeatPiping")
		var back := box(parent,Vector3(1.37,0.94,0.46),Vector3(x,0.38,0.32),CORAL.lightened(0.05),"BackCushion",0.22,0.95)
		back.rotation.x = deg_to_rad(-8)
		seam(back,Vector2(1.17,0.76),Vector3(0,0,-0.229),0.15,CORAL.lightened(0.2),"BackPiping",Vector3(1.37,0.94,0.46),0.22)
	for side in [-1,1]:
		box(parent,Vector3(0.64,0.86,1.5),Vector3(side*2.16,-0.015,0),CORAL,"RolledArm",0.31,0.95)
		seam(parent,Vector2(0.46,0.68),Vector3(side*2.16,-0.015,-0.751),0.22,CORAL.lightened(0.2),"ArmPiping",Vector3(0.64,0.86,1.5),0.31)
		for z in [-0.5,0.45]:
			rod(parent,Vector3(side*2.06,-0.70,z),Vector3(side*1.99,-0.49,z-0.035),0.095,WOOD,"WoodFoot")
		var pillow := box(parent,Vector3(0.68,0.63,0.30),Vector3(side*1.50,0.35,-0.12),TEAL.lightened(0.3) if side<0 else GOLD,"ThrowPillow",0.145,0.95)
		pillow.rotation.z = side*0.19
		pillow.rotation.x = -0.18
		seam(pillow,Vector2(0.55,0.50),Vector3(0,0,-0.151),0.10,TEAL.lightened(0.42) if side<0 else GOLD.lightened(0.2),"PillowPiping")

static func make_tv_console(parent: Node3D) -> void:
	box(parent,Vector3(3.50,0.13,0.88),Vector3(0,0.31,0),WOOD.lightened(0.15),"WoodTop",0.06)
	box(parent,Vector3(3.35,0.43,0.79),Vector3(0,0.02,0),WOOD,"Cabinet",0.035)
	for side in [-1,1]:
		box(parent,Vector3(1.54,0.34,0.045),Vector3(side*0.81,0.035,0.415),TEAL,"CabinetDoor",0.035)
		ball(parent,Vector3.ONE*0.10,Vector3(side*0.14,0.04,0.46),CREAM,"CabinetKnob")
		for z in [-0.29,0.29]:
			rod(parent,Vector3(side*1.5,-0.37,z),Vector3(side*1.42,-0.16,z*0.86),0.075,WOOD,"ConsoleFoot")

static func make_tv(parent: Node3D) -> void:
	var shell := box(parent,Vector3(2.45,1.13,0.80),Vector3.ZERO,CREAM,"CRTShell",0.30,0.35)
	shell.scale.z = 0.5
	var recess := box(parent,Vector3(1.79,0.94,0.42),Vector3(-0.22,0,0.20),INK,"ScreenRecess",0.20,0.45)
	recess.scale.z = 0.13
	var glass := box(parent,Vector3(1.64,0.80,0.10),Vector3(-0.22,0,0.215),Color("376360"),"CurvedGlass",0.049,0.18)
	glass.mesh = rounded(Vector3(1.64,0.80,0.40),0.19)
	glass.scale.z = 0.25
	box(parent,Vector3(0.33,0.92,0.045),Vector3(0.96,0,0.183),CORAL,"ControlStrip",0.022)
	for y in [0.26,-0.02]:
		ball(parent,Vector3(0.22,0.22,0.095),Vector3(0.96,y,0.235),GOLD,"TuningKnob",0.3)
		box(parent,Vector3(0.023,0.15,0.024),Vector3(0.96,y,0.284),WOOD,"KnobGrip",0.01)
	for y in [-0.23,-0.31,-0.39]:
		box(parent,Vector3(0.21,0.028,0.014),Vector3(0.96,y,0.211),INK,"SpeakerSlot",0.006)
	for side in [-1,1]:
		box(parent,Vector3(0.15,0.10,0.24),Vector3(side*0.91,-0.60,0),INK,"TVFoot",0.03)
		rod(parent,Vector3(side*0.12,0.56,-0.015),Vector3(side*0.56,1.06,-0.06),0.012,WOOD,"Antenna")
		ball(parent,Vector3.ONE*0.046,Vector3(side*0.56,1.06,-0.06),GOLD,"AntennaTip")
	var star := SurfaceTool.new()
	star.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a := -PI/2+TAU*i/10
		var b := -PI/2+TAU*(i+1)/10
		for point in [Vector2.ZERO,Vector2(cos(a),-sin(a))*(0.25 if i%2==0 else 0.115),Vector2(cos(b),-sin(b))*(0.25 if (i+1)%2==0 else 0.115)]:
			star.set_normal(Vector3.BACK)
			star.add_vertex(Vector3(point.x-0.22,point.y,0.268))
	var icon := piece(parent,star.commit(),Vector3.ZERO,CREAM,"ScreenStar")
	icon.material_override = material(CREAM).duplicate()
	icon.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED

static func make_car(parent: Node3D) -> void:
	# +X is the nose; parts keep the original vehicle's footprint.
	box(parent,Vector3(5.12,0.69,2.25),Vector3(0,-0.09,0),CORAL,"Coachwork",0.32,0.28)
	var bonnet := box(parent,Vector3(1.82,0.62,1.94),Vector3(1.52,0.20,0),CORAL.lightened(0.04),"Bonnet",0.30,0.27)
	bonnet.scale.y = 0.48
	box(parent,Vector3(1.05,0.21,1.99),Vector3(-1.92,0.23,0),CORAL,"Boot",0.10,0.3)
	piece(parent,cabin_patch(-1.60,1.12,0,TAU,0),Vector3.ZERO,CREAM,"SculptedCabin",0.32)
	piece(parent,cabin_patch(0.62,1.03,0.50,PI-0.50,0.008),Vector3.ZERO,Color("659e99"),"CurvedWindshield",0.2)
	piece(parent,cabin_patch(-1.45,-1.08,0.6,PI-0.6,0.008),Vector3.ZERO,Color("659e99"),"CurvedRearGlass",0.2)
	for side in [-1,1]:
		for span in [Vector2(-1.16,-0.38),Vector2(-0.28,0.58)]:
			var a := -0.24 if side > 0 else PI-0.96
			var b := 0.96 if side > 0 else PI+0.24
			piece(parent,cabin_patch(span.x,span.y,a,b,0.012),Vector3.ZERO,Color("659e99"),"CurvedSideWindow",0.22)
		box(parent,Vector3(2.19,0.042,0.05),Vector3(-0.29,0.27,side*1.001),CREAM,"WindowSill",0.02)
		var panel := Node3D.new()
		parent.add_child(panel)
		panel.position = Vector3(-0.26,-0.01,side*1.135)
		seam(panel,Vector2(1.70,0.48),Vector3.ZERO,0.14,CORAL.darkened(0.22),"DoorShutLine")
		box(parent,Vector3(0.26,0.052,0.075),Vector3(-0.84,0.17,side*1.19),GOLD,"DoorHandle",0.022,0.3)
		rod(parent,Vector3(0.8,0.33,side*1.03),Vector3(0.85,0.43,side*1.3),0.025,CREAM,"MirrorStalk")
		ball(parent,Vector3(0.16,0.24,0.08),Vector3(0.85,0.46,side*1.31),CREAM,"Mirror")
		for x in [-1.68,1.68]:
			ball(parent,Vector3(1.43,0.82,0.55),Vector3(x,-0.02,side*1.05),CORAL,"SculptedFender",0.28)
			ball(parent,Vector3(1.12,1.08,0.12),Vector3(x,-0.30,side*1.282),INK,"WheelArchRecess",0.95)
			var tire := CylinderMesh.new()
			tire.top_radius = 0.47
			tire.bottom_radius = 0.47
			tire.height = 0.24
			tire.radial_segments = 48
			piece(parent,tire,Vector3(x,-0.32,side*1.23),Color("263332"),"Tire",0.98).rotation.x = PI/2
			ball(parent,Vector3(0.80,0.80,0.15),Vector3(x,-0.32,side*1.36),Color("364340"),"TireSidewall",0.95)
			ball(parent,Vector3(0.56,0.56,0.16),Vector3(x,-0.32,side*1.415),CREAM,"Hubcap",0.3)
			ball(parent,Vector3(0.39,0.39,0.04),Vector3(x,-0.32,side*1.50),CREAM.darkened(0.13),"HubInset",0.35)
		ball(parent,Vector3(0.17,0.43,0.43),Vector3(2.52,0.08,side*0.78),CREAM,"HeadlightRim",0.35)
		ball(parent,Vector3(0.11,0.31,0.31),Vector3(2.61,0.08,side*0.78),Color("d4e1bb"),"HeadlightLens",0.2)
		ball(parent,Vector3(0.085,0.12,0.12),Vector3(2.57,-0.24,side*0.80),GOLD,"IndicatorLens",0.25)
		ball(parent,Vector3(0.08,0.21,0.22),Vector3(-2.55,0,side*0.78),Color("a73e32"),"TailLight",0.3)
	var rim := box(parent,Vector3(0.50,0.45,1.09),Vector3(2.55,-0.08,0),CREAM,"GrilleRim",0.21)
	rim.scale.x = 0.24
	var grille := box(parent,Vector3(0.38,0.34,0.94),Vector3(2.62,-0.08,0),INK,"GrilleRecess",0.16)
	grille.scale.x = 0.20
	for y in [-0.18,-0.08,0.02]:
		box(parent,Vector3(0.04,0.024,0.88),Vector3(2.66,y,0),CREAM,"GrilleSlat",0.01)
	for x in [-2.60,2.65]:
		box(parent,Vector3(0.17,0.19,1.96),Vector3(x,-0.38,0),CREAM,"CreamBumper",0.08)
		for side in [-1,1]:
			box(parent,Vector3(0.21,0.34,0.15),Vector3(x,-0.32,side*0.7),CREAM,"BumperGuard",0.07)
	box(parent,Vector3(0.15,0.022,0.10),Vector3(2.16,0.36,0),GOLD,"BonnetBadge",0.01)

static func cabin_point(x: float, angle: float, offset: float) -> Vector3:
	var profile := [Vector3(-1.60,0.35,0.70),Vector3(-1.38,0.72,0.88),Vector3(-0.95,1.02,0.96),Vector3(-0.40,1.11,0.98),Vector3(0.24,1.08,0.97),Vector3(0.68,0.91,0.94),Vector3(1.12,0.31,0.78)]
	var high := 0.3
	var width := 0.8
	for i in profile.size()-1:
		if x >= profile[i].x and x <= profile[i+1].x:
			var t := inverse_lerp(profile[i].x,profile[i+1].x,x)
			high = lerpf(profile[i].y,profile[i+1].y,t)
			width = lerpf(profile[i].z,profile[i+1].z,t)
			break
	var half := (high-0.23)*0.5
	var y := (high+0.23)*0.5+signf(sin(angle))*pow(absf(sin(angle)),0.72)*half
	var z := signf(cos(angle))*pow(absf(cos(angle)),0.72)*(width+offset)
	return Vector3(x,y+offset,z)

static func cabin_patch(x0: float, x1: float, a0: float, a1: float, offset: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		for j in 24:
			for ij in [Vector2(i,j),Vector2(i+1,j+1),Vector2(i+1,j),Vector2(i,j),Vector2(i,j+1),Vector2(i+1,j+1)]:
				var x := lerpf(x0,x1,ij.x/32)
				var a := lerpf(a0,a1,ij.y/24)
				var dx := cabin_point(minf(1.12,x+0.001),a,offset)-cabin_point(maxf(-1.60,x-0.001),a,offset)
				var da := cabin_point(x,a+0.001,offset)-cabin_point(x,a-0.001,offset)
				surface.set_normal(dx.cross(da).normalized())
				surface.add_vertex(cabin_point(x,a,offset))
	return surface.commit()
