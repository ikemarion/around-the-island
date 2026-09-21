@tool
extends RefCounted
## Kitchen art only: no bodies, collision changes, RNG, or network state.
const ART = preload("res://scripts/house_prop_art.gd")
const TEAL := Color("54847a")
const PANEL := Color("639487")
const DARK := Color("365c54")
const CREAM := Color("eddfbc")
const WOOD := Color("bd8950")
const GOLD := Color("dec18a")
const CORAL := Color("ce745b")

static func slab(parent: Node3D, size: Vector3, at: Vector3, color: Color, title: String, radius: float) -> MeshInstance3D:
	# Flatten a deeper rounded solid, preserving wide XZ corners on thin trim.
	var part := ART.box(parent,Vector3(size.x,0.8,size.z),at,color,title,radius)
	part.scale.y = size.y/0.8
	return part

static func handle(parent: Node3D, at: Vector3, horizontal: bool, title: String) -> void:
	var direction := Vector3.RIGHT if horizontal else Vector3.UP
	for sign_value in [-1,1]:
		ART.ball(parent,Vector3(0.075,0.075,0.055),at+direction*sign_value*0.11,GOLD,title+"Mount")
	ART.rod(parent,at-direction*0.11+Vector3(0,0,0.035),at+direction*0.11+Vector3(0,0,0.035),0.032,GOLD,title)

static func cabinet(parent: Node3D, width: float, at: Vector3, drawer: bool, index: int) -> void:
	var face := Node3D.new()
	face.name = "Cabinet%d" % index
	parent.add_child(face)
	face.position = at
	ART.box(face,Vector3(width,0.65,0.06),Vector3.ZERO,DARK,"DoorReveal",0.028)
	ART.box(face,Vector3(width-0.038,0.614,0.055),Vector3(0,0,0.024),PANEL,"DoorFrame",0.025)
	ART.box(face,Vector3(width-0.16,0.46,0.023),Vector3(0,-0.015,0.051),TEAL,"InsetPanel",0.011)
	# Small inset molding, all four sides, avoids a flat painted-on rectangle.
	ART.seam(face,Vector2(width-0.15,0.47),Vector3(0,-0.015,0.065),0.055,Color("719c8d"),"InsetMolding")
	if drawer:
		ART.box(face,Vector3(width-0.035,0.018,0.025),Vector3(0,0.12,0.06),DARK,"DrawerJoint",0.006)
		handle(face,Vector3(0,0.225,0.071),true,"DrawerPull")
	else:
		handle(face,Vector3((width*0.5-0.15)*(-1 if index%2 == 0 else 1),0.07,0.07),false,"DoorPull")
	# The carcass casts the cabinet shadow. Tiny layered moldings otherwise
	# produce noisy self-shadow striping in the Compatibility renderer.
	for part in face.find_children("*","MeshInstance3D",true,false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func make_island(parent: Node3D) -> void:
	var art := Node3D.new()
	art.name = "KitchenArt"
	parent.add_child(art)
	slab(art,Vector3(7.10,0.10,2.85),Vector3(0,-0.425,0),DARK,"RecessedToeKick",0.24)
	slab(art,Vector3(7.30,0.055,3.01),Vector3(0,-0.353,0),WOOD,"WoodPlinth",0.26)
	ART.box(art,Vector3(7.30,0.72,3.02),Vector3(0,0.025,0),TEAL,"CabinetCarcass",0.20)
	slab(art,Vector3(7.36,0.038,3.08),Vector3(0,0.347,0),DARK,"CounterShadow",0.26)
	slab(art,Vector3(7.50,0.115,3.20),Vector3(0,0.415,0),WOOD,"RoundedWoodCounterEdge",0.31)
	slab(art,Vector3(7.38,0.036,3.08),Vector3(0,0.456,0),CREAM,"CreamCountertop",0.28)
	for side in [-1,1]:
		var front := Node3D.new()
		front.name = "Front" if side == 1 else "Back"
		art.add_child(front)
		front.rotation.y = 0 if side == 1 else PI
		for index in 6:
			cabinet(front,1.10,Vector3(-2.925+index*1.17,-0.007,1.50),index%3 == 1,index)
		var end := Node3D.new()
		end.name = "End%d" % side
		art.add_child(end)
		end.rotation.y = side*PI/2
		for index in 2:
			cabinet(end,1.20,Vector3(-0.64+index*1.28,-0.007,3.64),true,index)
	# Modest kitchen dressing sits on the blocked island, outside the score lanes.
	var tea := Node3D.new()
	tea.name = "TeaCorner"
	art.add_child(tea)
	tea.position = Vector3(2.65,0.475,1.03)
	slab(tea,Vector3(0.65,0.035,0.55),Vector3(0,0.018,0),WOOD,"TeaBoard",0.22)
	ART.ball(tea,Vector3(0.33,0.30,0.33),Vector3(0,0.18,0),CORAL,"KettleBody")
	slab(tea,Vector3(0.22,0.035,0.22),Vector3(0,0.32,0),GOLD,"KettleLid",0.10)
	ART.ball(tea,Vector3.ONE*0.065,Vector3(0,0.36,0),DARK,"LidKnob")
	ART.rod(tea,Vector3(0.12,0.16,0),Vector3(0.26,0.28,0),0.045,CORAL,"Spout")
	for side in [-1,1]:
		ART.rod(tea,Vector3(0,0.23,side*0.13),Vector3(0,0.42,side*0.13),0.026,DARK,"HandleStem")
	ART.rod(tea,Vector3(0,0.42,-0.13),Vector3(0,0.42,0.13),0.032,WOOD,"KettleGrip")
	var bowl := Node3D.new()
	bowl.name = "FruitBowl"
	art.add_child(bowl)
	bowl.position = Vector3(-2.65,0.475,1.03)
	var profile: Array[Vector2] = [Vector2(0,0),Vector2(0.12,0),Vector2(0.20,0.04),Vector2(0.27,0.15),Vector2(0.26,0.18),Vector2(0.23,0.18),Vector2(0.18,0.07),Vector2(0.1,0.04),Vector2(0,0.04)]
	ART.piece(bowl,preload("res://scripts/collectible_design.gd").lathe(profile,48),Vector3.ZERO,CREAM,"CeramicBowl")
	for index in 3:
		var at := Vector3(cos(index*TAU/3)*0.105,0.17,sin(index*TAU/3)*0.105)
		ART.ball(bowl,Vector3.ONE*0.18,at,Color("d99544"),"Orange")
		ART.ball(bowl,Vector3(0.065,0.018,0.03),at+Vector3.UP*0.09,TEAL,"Leaf")

static func make_chair(parent: Node3D) -> void:
	# Every piece fits the existing 0.9 m body; keep the movable network ID.
	slab(parent,Vector3(0.83,0.13,0.79),Vector3(0,-0.015,0),WOOD,"RoundedWoodSeat",0.26)
	slab(parent,Vector3(0.76,0.022,0.72),Vector3(0,0.055,-0.008),Color("d5a663"),"SeatTop",0.23)
	for side in [-1,1]:
		for depth in [-1,1]:
			ART.rod(parent,Vector3(side*0.30,-0.42,depth*0.29),Vector3(side*0.255,-0.065,depth*0.25),0.045,TEAL,"SplayedLeg")
		ART.rod(parent,Vector3(side*0.28,-0.23,-0.27),Vector3(side*0.28,-0.23,0.27),0.026,DARK,"SideStretcher")
		ART.rod(parent,Vector3(side*0.26,0.025,0.27),Vector3(side*0.27,0.38,0.32),0.032,TEAL,"BackSpindle")
	var back := ART.box(parent,Vector3(0.76,0.265,0.30),Vector3(0,0.303,0.32),WOOD,"RoundedBackrest",0.12)
	back.scale.z = 0.32
	for side in [-1,1]:
		ART.ball(parent,Vector3(0.037,0.037,0.012),Vector3(side*0.26,0.29,0.269),GOLD,"BrassPeg")

static func dress_boundaries(arena: Node3D) -> void:
	# Shallow wainscot stays on the existing low walls: sightlines stay open.
	for wall_name in ["NorthWall","SouthWall"]:
		var wall: Node3D = arena.get_node(wall_name)
		var side := 1.0 if wall_name == "NorthWall" else -1.0
		ART.box(wall,Vector3(18.35,0.065,0.35),Vector3(0,0.32,0),WOOD,"WoodCap",0.028)
		ART.box(wall,Vector3(18.30,0.07,0.35),Vector3(0,-0.29,0),DARK,"Skirting",0.025)
		for index in 24:
			ART.box(wall,Vector3(0.70,0.50,0.023),Vector3(-8.625+index*0.75,0.005,side*0.171),PANEL,"Wainscot",0.01)
	for wall_name in ["WestWall","EastWall"]:
		var wall: Node3D = arena.get_node(wall_name)
		var side := 1.0 if wall_name == "WestWall" else -1.0
		for index in 3:
			var length: float = [1.0,4.0,1.0][index]
			var center: float = [-5.5,0.0,5.5][index]
			ART.box(wall,Vector3(0.026,1.38,length-0.03),Vector3(side*0.149,0.40,center),CREAM,"Plaster",0.012)
			ART.box(wall,Vector3(0.034,0.07,length),Vector3(side*0.15,-0.31,center),WOOD,"ChairRail",0.016)
			ART.box(wall,Vector3(0.034,0.07,length),Vector3(side*0.15,-1.10,center),DARK,"Baseboard",0.016)
			for board in int(length/0.5):
				ART.box(wall,Vector3(0.02,0.68,0.465),Vector3(side*0.151,-0.71,center-length*0.5+0.25+board*0.5),PANEL,"DividerPanel",0.009)
			for edge in [-1,1]:
				ART.box(wall,Vector3(0.035,2.28,0.075),Vector3(side*0.15,0,center+edge*(length*0.5-0.042)),WOOD,"PassageWoodTrim",0.016)
