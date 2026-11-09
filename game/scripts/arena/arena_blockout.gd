extends Node3D
## Sprint 17 Colosseum blockout (D-054): code-built placeholder geometry the
## art pass replaces — a wall ring with a gate gap, gate posts, and three
## rising spectator tiers. No collision outside the wall: the actors' radial
## clamp (arena_radius) is the navigation boundary.

const WALL_SEGMENTS := 16
const WALL_RADIUS := 18.5
const WALL_HEIGHT := 4.0
const GATE_SEGMENT := 0  # the gap faces +Z
const GATE_HALF_ANGLE := TAU / WALL_SEGMENTS / 2.0

var _stone: StandardMaterial3D
var _stone_dark: StandardMaterial3D
var _sand: StandardMaterial3D

func _ready() -> void:
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.62, 0.58, 0.52, 1.0)
	_stone_dark = StandardMaterial3D.new()
	_stone_dark.albedo_color = Color(0.45, 0.4, 0.35, 1.0)
	_sand = StandardMaterial3D.new()
	_sand.albedo_color = Color(0.72, 0.63, 0.47, 1.0)
	_build_walls()
	_build_gate()
	_build_tiers()

func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "WallRing"
	add_child(body)
	for i in WALL_SEGMENTS:
		if i == GATE_SEGMENT:
			continue  # the entry gap
		var angle: float = float(i) * TAU / float(WALL_SEGMENTS)
		var position := Vector3(sin(angle) * WALL_RADIUS, WALL_HEIGHT / 2.0, cos(angle) * WALL_RADIUS)
		_add_box(body, "Wall%d" % i, Vector3(7.3, WALL_HEIGHT, 1.0), position, angle, _stone)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(7.3, WALL_HEIGHT, 1.0)
		shape.shape = box
		shape.position = position
		shape.rotation.y = angle
		body.add_child(shape)

func _build_gate() -> void:
	# Two posts flanking the gap plus an entry strip reaching outward.
	for side in [-1.0, 1.0]:
		var angle: float = GATE_HALF_ANGLE * side
		var position := Vector3(sin(angle) * WALL_RADIUS, WALL_HEIGHT / 2.0 + 0.5, cos(angle) * WALL_RADIUS)
		var body := StaticBody3D.new()
		body.name = "GatePost%s" % ("Plus" if side > 0.0 else "Minus")
		add_child(body)
		_add_box(body, "Post", Vector3(1.0, WALL_HEIGHT + 1.0, 1.0), position, angle, _stone_dark)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, WALL_HEIGHT + 1.0, 1.0)
		shape.shape = box
		shape.position = position
		shape.rotation.y = angle
		body.add_child(shape)
	var strip := MeshInstance3D.new()
	strip.name = "EntryStrip"
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(6.0, 0.4, 8.0)
	strip.mesh = strip_mesh
	strip.material_override = _sand
	strip.position = Vector3(0, -0.1, WALL_RADIUS + 4.0)
	add_child(strip)

func _build_tiers() -> void:
	# D-048 fix: the tiers are RINGS (segment boxes) behind the wall — solid
	# cylinders would cap the whole play area and occlude the fight from any
	# camera above their height.
	var tiers := [
		{"radius": 20.5, "height": 1.6, "top": 0.8, "color": Color(0.58, 0.54, 0.48, 1.0), "length": 8.3},
		{"radius": 23.0, "height": 3.2, "top": 1.8, "color": Color(0.54, 0.5, 0.45, 1.0), "length": 9.3},
		{"radius": 25.5, "height": 4.8, "top": 2.8, "color": Color(0.5, 0.46, 0.41, 1.0), "length": 10.3},
	]
	for t_i in tiers.size():
		var tier: Dictionary = tiers[t_i]
		var tier_node := Node3D.new()
		tier_node.name = "Tier%d" % (t_i + 1)
		add_child(tier_node)
		var material := StandardMaterial3D.new()
		material.albedo_color = tier["color"]
		for i in WALL_SEGMENTS:
			var angle := float(i) * TAU / float(WALL_SEGMENTS) + TAU / float(WALL_SEGMENTS) / 2.0
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.name = "Tier%dSeg%d" % [(t_i + 1), i]
			var mesh := BoxMesh.new()
			mesh.size = Vector3(tier["length"], tier["height"], 2.0)
			mesh_instance.mesh = mesh
			mesh_instance.material_override = material
			mesh_instance.position = Vector3(sin(angle) * tier["radius"], float(tier["top"]) - float(tier["height"]) / 2.0, cos(angle) * tier["radius"])
			mesh_instance.rotation.y = angle
			tier_node.add_child(mesh_instance)

func _add_box(parent: Node, node_name: String, size: Vector3, position: Vector3, yaw: float, material: StandardMaterial3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	mesh_instance.rotation.y = yaw
	parent.add_child(mesh_instance)
