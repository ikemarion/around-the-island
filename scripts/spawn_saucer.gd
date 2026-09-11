extends Node3D
const DESIGN = preload("res://scripts/collectible_design.gd")
var glow: StandardMaterial3D
var available := false

func _ready() -> void:
	var teal := DESIGN.material(Color("377d72"), 0.42)
	var cream := DESIGN.material(Color("f3dfb1"), 0.3)
	var well := DESIGN.material(Color("cdb88e"), 0.5)
	glow = DESIGN.material(Color("ffdb78"))
	glow.emission_enabled = true
	glow.emission = Color("ffc65b")
	DESIGN.piece(self,"TealBase",[Vector2(0,0.015),Vector2(0.68,0.015),Vector2(0.74,0.025),Vector2(0.76,0.055),Vector2(0.75,0.18),Vector2(0.72,0.23),Vector2(0,0.23)],teal)
	DESIGN.piece(self,"CeramicLip",[Vector2(0.70,0.16),Vector2(0.76,0.18),Vector2(0.79,0.22),Vector2(0.78,0.27),Vector2(0.74,0.31),Vector2(0.65,0.33),Vector2(0.57,0.32),Vector2(0.53,0.29),Vector2(0.52,0.25),Vector2(0.55,0.22),Vector2(0.70,0.16)],cream)
	DESIGN.piece(self,"RecessedWell",[Vector2(0,0.20),Vector2(0.5,0.20),Vector2(0.54,0.23),Vector2(0.53,0.255),Vector2(0.47,0.26),Vector2(0,0.26)],well)
	DESIGN.piece(self,"ReadyRing",[Vector2(0.49,0.258),Vector2(0.51,0.255),Vector2(0.53,0.26),Vector2(0.51,0.265),Vector2(0.49,0.258)],glow)
	# Scalloped inset medallions repeat around the ceramic base.
	for index in 12:
		var arch := MeshInstance3D.new()
		arch.mesh = SphereMesh.new()
		arch.mesh.radial_segments = 24
		arch.mesh.rings = 12
		arch.scale = Vector3(0.23,0.23,0.035)
		var angle := TAU * index / 12.0
		arch.position = Vector3(sin(angle)*0.75,0.07,cos(angle)*0.75)
		arch.rotation.y = angle
		arch.material_override = DESIGN.material(Color("29645c"),0.6)
		add_child(arch)
	set_available(false)

func set_available(value: bool) -> void:
	available = value
	if glow:
		glow.emission_energy_multiplier = 1.25 if value else 0.0
		glow.albedo_color = Color("ffe09b") if value else Color("a89a7e")
