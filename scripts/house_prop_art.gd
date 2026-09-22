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
	# +X is the nose. Visual-only, centered on the unchanged 5.4 x 1.65 x 2.55 collider.
	# The low waist and upright glazing make a friendly compact, not a glass capsule.
	var paint := Color("d76453")
	var ivory := Color("f3dfb6")
	var rubber := Color("283633")
	piece(parent,_car_body_mesh(),Vector3.ZERO,paint,"Coachwork",0.31)
	var roof := piece(parent,_car_roof_mesh(),Vector3.ZERO,ivory,"SculptedCabin",0.42)
	var roof_material := roof.material_override.duplicate() as StandardMaterial3D
	roof_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof.material_override = roof_material
	box(parent,Vector3(2.58,0.12,1.96),Vector3(-0.27,0.235,0),paint,"CabinBelt",0.058,0.36)
	# Actual hollow cabin: tinted panes, cream pillars, upholstered seats and steering wheel.
	for side in [-1,1]:
		box(parent,Vector3(0.58,0.13,0.66),Vector3(-0.12,0.28,side*0.46),TEAL.darkened(0.28),"SeatBase",0.064,0.95)
		var seat := box(parent,Vector3(0.15,0.53,0.66),Vector3(-0.42,0.50,side*0.46),Color("727b62"),"SeatBack",0.072,0.94)
		seat.rotation.z = -0.12
	box(parent,Vector3(0.40,0.20,1.59),Vector3(0.89,0.32,0),TEAL.darkened(0.24),"Dashboard",0.09,0.82)
	var steering := Node3D.new()
	steering.name = "SteeringWheel"
	parent.add_child(steering)
	steering.position = Vector3(0.62,0.54,0.47)
	steering.rotation.z = -0.42
	_car_ring(steering,0.24,0.026,Vector3.ZERO,ivory,"SteeringRim",Vector3(0,0,PI/2))
	rod(steering,Vector3(0,0,0),Vector3(0,0.22,0),0.019,ivory,"SteeringSpoke")
	rod(steering,Vector3(0,0,0),Vector3(0,-0.15,-0.17),0.019,ivory,"SteeringSpoke")
	rod(steering,Vector3(0,0,0),Vector3(0,-0.15,0.17),0.019,ivory,"SteeringSpoke")
	var pane: Array[Vector2] = [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]
	_car_window(parent,pane,"front",1,"CurvedWindshield",0.16)
	_car_window(parent,pane,"rear",1,"CurvedRearGlass",0.11)
	var front_side: Array[Vector2] = [Vector2(-0.40,0.29),Vector2(1.06,0.29),Vector2(0.79,0.82),Vector2(0.51,1.02),Vector2(-0.40,1.045)]
	var rear_side: Array[Vector2] = [Vector2(-1.57,0.29),Vector2(-0.54,0.29),Vector2(-0.54,1.045),Vector2(-1.14,1.02),Vector2(-1.40,0.80)]
	for side in [-1,1]:
		_car_window(parent,front_side,"side",side,"CurvedSideWindow",0.09)
		_car_window(parent,rear_side,"side",side,"CurvedQuarterWindow",0.08)
		rod(parent,Vector3(-0.47,0.28,side*1.004),Vector3(-0.47,1.05,side*0.88),0.05,ivory,"CreamCenterPillar")
		box(parent,Vector3(2.55,0.032,0.042),Vector3(-0.26,0.217,side*1.065),ivory,"WaistPinstripe",0.014,0.48)
		var shut: Array[Vector3] = []
		for p in _car_round_outline([Vector2(-0.85,0.17),Vector2(0.97,0.17),Vector2(0.73,-0.37),Vector2(-0.89,-0.37)],0.09):
			var top := 0.295-0.14*pow(maxf(0,p.x)/2.5,5)-0.08*pow(maxf(0,-p.x)/2.5,5)
			var normalized_y := clampf((p.y-(top-0.47)*0.5)/((top+0.47)*0.5),-1,1)
			var angle := asin(signf(normalized_y)*pow(absf(normalized_y),1/0.68))
			var point := _car_body_point(p.x,angle)
			shut.append(Vector3(point.x,point.y,side*(point.z+0.009)))
		_car_tube(parent,shut,0.010,paint.darkened(0.36),"DoorShutLine")
		ball(parent,Vector3(0.32,0.095,0.045),Vector3(-0.67,0.065,side*1.08),paint.darkened(0.18),"HandleRecess")
		box(parent,Vector3(0.27,0.045,0.064),Vector3(-0.67,0.071,side*1.123),GOLD,"DoorHandle",0.021,0.32)
		rod(parent,Vector3(0.81,0.30,side*1.02),Vector3(0.75,0.41,side*1.18),0.025,GOLD,"MirrorStalk")
		ball(parent,Vector3(0.16,0.23,0.13),Vector3(0.75,0.46,side*1.19),ivory,"Mirror",0.32)
		ball(parent,Vector3(0.017,0.168,0.094),Vector3(0.672,0.46,side*1.19),Color("71978f"),"MirrorGlass",0.2)
		for x in [-1.68,1.68]:
			ball(parent,Vector3(1.20,1.14,0.10),Vector3(x,-0.27,side*1.087),rubber,"WheelArchRecess",0.98)
			var fender := piece(parent,_car_fender_mesh(side),Vector3(x,-0.27,0),paint,"SculptedFender",0.31)
			fender.material_override = fender.mesh.surface_get_material(0)
			var tire := CylinderMesh.new()
			tire.top_radius = 0.525
			tire.bottom_radius = 0.525
			tire.height = 0.22
			tire.radial_segments = 32
			piece(parent,tire,Vector3(x,-0.275,side*1.105),rubber,"Tire",0.96).rotation.x = PI/2
			ball(parent,Vector3(0.98,0.98,0.18),Vector3(x,-0.275,side*1.178),rubber.lightened(0.025),"TireSidewall",0.98)
			_car_ring(parent,0.359,0.027,Vector3(x,-0.275,side*1.273),ivory,"CreamWheelRim",Vector3(PI/2,0,0))
			ball(parent,Vector3(0.64,0.64,0.10),Vector3(x,-0.275,side*1.249),Color("687e6c"),"HubInset",0.45)
			_car_ring(parent,0.286,0.012,Vector3(x,-0.275,side*1.303),GOLD,"HubcapBead",Vector3(PI/2,0,0))
			ball(parent,Vector3(0.53,0.53,0.14),Vector3(x,-0.275,side*1.28),ivory,"Hubcap",0.38)
		# Chunky inset rings make the large headlights feel part of the wings.
		ball(parent,Vector3(0.23,0.51,0.51),Vector3(2.40,0.085,side*0.77),ivory,"HeadlightRim",0.38)
		ball(parent,Vector3(0.10,0.41,0.41),Vector3(2.525,0.085,side*0.77),Color("6f8476"),"HeadlightGasket",0.6)
		ball(parent,Vector3(0.19,0.37,0.37),Vector3(2.535,0.085,side*0.77),Color("e0e5c8"),"HeadlightLens",0.19)
		ball(parent,Vector3(0.11,0.19,0.19),Vector3(2.48,-0.235,side*0.79),ivory,"IndicatorRim",0.42)
		ball(parent,Vector3(0.085,0.145,0.145),Vector3(2.54,-0.235,side*0.79),Color("d09b39"),"IndicatorLens",0.26)
		ball(parent,Vector3(0.10,0.25,0.19),Vector3(-2.45,-0.11,side*0.79),ivory,"TailLightRim",0.42)
		ball(parent,Vector3(0.09,0.19,0.14),Vector3(-2.51,-0.10,side*0.79),Color("9f3d30"),"TailLight",0.3)
	var rim := box(parent,Vector3(0.52,0.51,1.12),Vector3(2.46,-0.125,0),ivory,"GrilleRim",0.245,0.42)
	rim.scale.x = 0.25
	var grille := box(parent,Vector3(0.40,0.39,0.99),Vector3(2.525,-0.125,0),rubber,"GrilleRecess",0.19,0.76)
	grille.scale.x = 0.19
	for y in [-0.235,-0.12,-0.005]:
		box(parent,Vector3(0.045,0.036,0.90),Vector3(2.572,y,0),ivory,"GrilleSlat",0.017,0.43)
	box(parent,Vector3(0.038,0.35,0.036),Vector3(2.58,-0.125,0),ivory,"GrilleCenter",0.017,0.44)
	for nose in [-1,1]:
		var bumper: Array[Vector3] = []
		for i in 17:
			var z := lerpf(-1.01,1.01,float(i)/16)
			bumper.append(Vector3(nose*(2.57-0.15*pow(absf(z),4)),-0.42,z))
		_car_tube(parent,bumper,0.091,ivory,"CreamBumper",false)
		for side in [-1,1]:
			box(parent,Vector3(0.21,0.35,0.155),Vector3(nose*2.60,-0.365,side*0.72),ivory,"BumperGuard",0.072,0.43)
			ball(parent,Vector3.ONE*0.033,Vector3(nose*2.682,-0.415,side*0.92),GOLD,"BumperRivet",0.58)
	# Bonnet panel is a thin engraved contour following the sculpted upper shell.
	var bonnet_line: Array[Vector3] = []
	for p in _car_round_outline([Vector2(0.88,-0.62),Vector2(2.18,-0.53),Vector2(2.18,0.53),Vector2(0.88,0.62)],0.14):
		bonnet_line.append(_car_body_point(p.x,acos(clampf(p.y/1.05,-1,1)))+Vector3(0,0.007,0))
	_car_tube(parent,bonnet_line,0.007,paint.darkened(0.22),"BonnetSeam")
	var badge := ball(parent,Vector3(0.17,0.029,0.10),Vector3(2.20,0.235,0),GOLD,"BonnetBadge",0.35)
	badge.rotation.z = -0.26
	# Small trim cannot affect the silhouette's lighting and needn't cast dozens of shadows.
	for trim in parent.find_children("*","MeshInstance3D",true,false):
		if str(trim.name).contains("Glass") or str(trim.name).contains("Bead") or str(trim.name).contains("Seam") or str(trim.name).contains("Slat") or str(trim.name).contains("Rivet"):
			trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _car_body_point(x: float, angle: float) -> Vector3:
	var width := 1.055-0.19*pow(absf(x)/2.5,8)
	var top := 0.295-0.14*pow(maxf(0,x)/2.5,5)-0.08*pow(maxf(0,-x)/2.5,5)
	var middle := (top-0.47)*0.5
	var half := (top+0.47)*0.5
	return Vector3(x,middle+signf(sin(angle))*pow(absf(sin(angle)),0.68)*half,signf(cos(angle))*pow(absf(cos(angle)),0.48)*width)

static func _car_roof_point(angle: float, radial: float) -> Vector3:
	# A shallow soft dome, not a beveled cube. Maximum world height is 2.0m.
	return Vector3(-0.32+1.19*signf(cos(angle))*pow(absf(cos(angle)),0.40)*radial,0.945+0.23*sqrt(maxf(0,1-radial*radial)),0.99*signf(sin(angle))*pow(absf(sin(angle)),0.40)*radial)

static func _car_roof_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 14:
		for i in 64:
			for uv in [Vector2(i,ring),Vector2(i+1,ring+1),Vector2(i+1,ring),Vector2(i,ring),Vector2(i,ring+1),Vector2(i+1,ring+1)]:
				var angle: float = uv.x*TAU/64
				var radial: float = uv.y/14
				var da := _car_roof_point(angle+0.0001,radial)-_car_roof_point(angle-0.0001,radial)
				var dr := _car_roof_point(angle,minf(1,radial+0.0001))-_car_roof_point(angle,maxf(0,radial-0.0001))
				surface.set_normal(da.cross(dr).normalized() if radial>0 else Vector3.UP)
				surface.add_vertex(_car_roof_point(angle,radial))
	return surface.commit()

static func _car_body_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		for j in 40:
			for ij in [Vector2(i,j),Vector2(i+1,j+1),Vector2(i+1,j),Vector2(i,j),Vector2(i,j+1),Vector2(i+1,j+1)]:
				var x := lerpf(-2.47,2.47,ij.x/40)
				var a: float = TAU*ij.y/40
				var dx := _car_body_point(x+0.001,a)-_car_body_point(x-0.001,a)
				var da := _car_body_point(x,a+0.001)-_car_body_point(x,a-0.001)
				surface.set_normal(dx.cross(da).normalized())
				surface.add_vertex(_car_body_point(x,a))
	for x in [-2.47,2.47]:
		for j in 40:
			var points: Array[Vector3] = [Vector3(x,-0.15,0),_car_body_point(x,TAU*j/40),_car_body_point(x,TAU*(j+1)/40)]
			if x < 0: points.reverse()
			for p in points:
				surface.set_normal(Vector3(signf(x),0,0))
				surface.add_vertex(p)
	return surface.commit()

static func _car_round_outline(outline: Array[Vector2], distance: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in outline.size():
		var corner := outline[i]
		var previous := outline[posmod(i-1,outline.size())]
		var next := outline[(i+1)%outline.size()]
		var a := corner.move_toward(previous,minf(distance,corner.distance_to(previous)*0.4))
		var b := corner.move_toward(next,minf(distance,corner.distance_to(next)*0.4))
		for step in 6:
			var t := float(step)/5
			points.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
	return points

static func _car_window_point(p: Vector2, kind: String, side: int) -> Vector3:
	if kind == "front":
		return Vector3(lerpf(1.115,0.655,p.y)+0.055*(1-p.x*p.x)*sin(p.y*PI),lerpf(0.29,1.045,p.y),p.x*lerpf(0.983,0.855,p.y))
	if kind == "rear":
		return Vector3(lerpf(-1.645,-1.31,p.y)-0.035*(1-p.x*p.x)*sin(p.y*PI),lerpf(0.29,0.99,p.y),p.x*lerpf(0.983,0.865,p.y))
	return Vector3(p.x,p.y,side*(1.035-(p.y-0.235)*0.17))

static func _car_window(parent: Node3D, outline: Array[Vector2], kind: String, side: int, title: String, radius: float) -> void:
	var points := _car_round_outline(outline,radius)
	var center := Vector2.ZERO
	for p in points: center += p
	center /= points.size()
	var border: Array[Vector3] = []
	for p in points: border.append(_car_window_point(p,kind,side))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 5:
		for i in points.size():
			var next := (i+1)%points.size()
			for uv in [Vector2(i,ring),Vector2(next,ring+1),Vector2(i,ring+1),Vector2(i,ring),Vector2(next,ring),Vector2(next,ring+1)]:
				var p := center.lerp(points[int(uv.x)],uv.y/5)
				var dx := _car_window_point(p+Vector2(0.001,0),kind,side)-_car_window_point(p-Vector2(0.001,0),kind,side)
				var dy := _car_window_point(p+Vector2(0,0.001),kind,side)-_car_window_point(p-Vector2(0,0.001),kind,side)
				surface.set_normal(dx.cross(dy).normalized()*(side if kind == "side" else (-1 if kind == "front" else 1)))
				surface.add_vertex(_car_window_point(p,kind,side))
	var glass := piece(parent,surface.commit(),Vector3.ZERO,Color("8abab0"),title,0.18)
	var mat := material(Color("80b5ac"),0.24).duplicate() as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.56
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frame_normal := Vector3.BACK if kind == "side" else Vector3.RIGHT
	_car_tube(parent,border,0.044,Color("f3dfb6"),title+"CreamSurround",true,frame_normal)
	# Thin inside rubber bead, separate from the broad cream pillars.
	var seal: Array[Vector3] = []
	for p in points: seal.append(_car_window_point(center.lerp(p,0.89),kind,side))
	_car_tube(parent,seal,0.012,Color("527b70"),title+"RubberSeal",true,frame_normal)

static func _car_fender_point(a: float, t: float, side: int) -> Vector3:
	var radius := 0.565+0.22*sin(t*PI)-0.07*t
	return Vector3(cos(a)*radius,sin(a)*radius,side*(1.19+0.13*sin(t*PI)-0.39*t))

static func _car_fender_mesh(side: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		for j in 8:
			var corners := [Vector2(i,j),Vector2(i+1,j+1),Vector2(i+1,j),Vector2(i,j),Vector2(i,j+1),Vector2(i+1,j+1)]
			if side > 0: corners.reverse()
			for ij in corners:
				var a := lerpf(-0.16,PI+0.16,ij.x/32)
				var t: float = ij.y/8
				var da := _car_fender_point(a+0.001,t,side)-_car_fender_point(a-0.001,t,side)
				var dt := _car_fender_point(a,t+0.001,side)-_car_fender_point(a,t-0.001,side)
				surface.set_normal(da.cross(dt).normalized()*-side)
				surface.add_vertex(_car_fender_point(a,t,side))
	var mesh := surface.commit()
	# The far-side arch shares topology with the near side; render both faces.
	var arch_material := material(Color("d76453"),0.31).duplicate() as StandardMaterial3D
	arch_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,arch_material)
	return mesh

static func _car_tube(parent: Node3D, points: Array[Vector3], radius: float, color: Color, title: String, closed := true, reference := Vector3.UP) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_count := points.size()
	for i in ring_count if closed else ring_count-1:
		var j := (i+1)%ring_count
		for segment in 8:
			for corner in [Vector2(i,segment),Vector2(j,segment),Vector2(j,segment+1),Vector2(i,segment),Vector2(j,segment+1),Vector2(i,segment+1)]:
				var index := int(corner.x)
				var previous := posmod(index-1,ring_count) if closed else maxi(0,index-1)
				var next := (index+1)%ring_count if closed else mini(ring_count-1,index+1)
				var forward := (points[next]-points[previous]).normalized()
				var u := forward.cross(reference if absf(forward.dot(reference))<0.98 else Vector3.FORWARD).normalized()
				var v := forward.cross(u).normalized()
				var angle: float = corner.y*TAU/8
				var normal := u*cos(angle)+v*sin(angle)
				surface.set_normal(normal)
				surface.add_vertex(points[int(corner.x)]+normal*radius)
	var trim := piece(parent,surface.commit(),Vector3.ZERO,color,title,0.45)
	var trim_mat := trim.material_override.duplicate() as StandardMaterial3D
	trim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	trim.material_override = trim_mat
	trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _car_ring(parent: Node3D, radius: float, thickness: float, at: Vector3, color: Color, title: String, rotation: Vector3) -> void:
	var shape := TorusMesh.new()
	shape.inner_radius = radius-thickness
	shape.outer_radius = radius+thickness
	shape.rings = 32
	shape.ring_segments = 8
	var trim := piece(parent,shape,at,color,title,0.43)
	trim.rotation = rotation
	trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
