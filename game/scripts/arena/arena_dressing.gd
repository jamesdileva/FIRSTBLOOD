extends Node3D
## Sprint 18 dressing layer (D-055/D-056): decorative props and light dressing
## built in code — pillars, torches, banners, floor emblem. Presentation only:
## no gameplay reads or writes anything here. The art pass replaces geometry.

const WALL_RADIUS := 18.5
const PILLAR_HEIGHT := 5.0

var _torch_lights: Array[OmniLight3D] = []

func _ready() -> void:
	_build_pillars()
	_build_torches()
	_build_banners()
	_build_floor_emblem()

func _build_pillars() -> void:
	# Eight pillars on the wall-segment boundaries (the wall ring's joints).
	var pillar_material := StandardMaterial3D.new()
	pillar_material.albedo_color = Color(0.66, 0.61, 0.54, 1.0)
	pillar_material.roughness = 0.85
	for i in 8:
		var angle := (float(i) + 0.5) * TAU / 8.0
		var pillar := MeshInstance3D.new()
		pillar.name = "Pillar%d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.42
		mesh.bottom_radius = 0.55
		mesh.height = PILLAR_HEIGHT
		pillar.mesh = mesh
		pillar.material_override = pillar_material
		pillar.position = Vector3(sin(angle) * (WALL_RADIUS + 0.2), PILLAR_HEIGHT / 2.0, cos(angle) * (WALL_RADIUS + 0.2))
		add_child(pillar)
		var cap := MeshInstance3D.new()
		cap.name = "PillarCap%d" % i
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(1.1, 0.3, 1.1)
		cap.mesh = cap_mesh
		cap.material_override = pillar_material
		cap.position = pillar.position + Vector3(0, PILLAR_HEIGHT / 2.0 + 0.15, 0)
		add_child(cap)

func _build_torches() -> void:
	# Warm lights on the four diagonal pillars + emissive braziers.
	var torch_material := StandardMaterial3D.new()
	torch_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torch_material.albedo_color = Color(1.0, 0.62, 0.25, 1.0)
	for i in 4:
		var angle := (float(i) + 0.5) * TAU / 4.0
		var base := Vector3(sin(angle) * (WALL_RADIUS + 0.2), PILLAR_HEIGHT + 0.3, cos(angle) * (WALL_RADIUS + 0.2))
		var brazier := MeshInstance3D.new()
		brazier.name = "Torch%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.45, 0.35, 0.45)
		brazier.mesh = mesh
		brazier.material_override = torch_material
		brazier.position = base
		add_child(brazier)
		var light := OmniLight3D.new()
		light.name = "TorchLight%d" % i
		light.light_color = Color(1.0, 0.6, 0.3, 1.0)
		light.light_energy = 2.0
		light.omni_range = 9.0
		light.shadow_enabled = false
		light.position = base + Vector3(0, 0.5, 0)
		light.set_script(load("res://game/scripts/arena/torch_flicker.gd"))
		add_child(light)
		_torch_lights.append(light)

func _build_banners() -> void:
	# Crimson banners hanging from the gate posts (double-sided quads).
	var banner_material := StandardMaterial3D.new()
	banner_material.albedo_color = Color(0.55, 0.12, 0.1, 1.0)
	banner_material.roughness = 0.9
	banner_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side: float in [-1.0, 1.0]:
		var angle: float = 0.055 * side  # just inside the gate posts
		var banner := MeshInstance3D.new()
		banner.name = "Banner%s" % ("Plus" if side > 0.0 else "Minus")
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.9, 1.7)
		banner.mesh = mesh
		banner.material_override = banner_material
		banner.position = Vector3(sin(angle) * (WALL_RADIUS + 0.35), 2.6, cos(angle) * (WALL_RADIUS + 0.35))
		banner.rotation.y = angle + PI / 2.0
		add_child(banner)

func _build_floor_emblem() -> void:
	# A dark inner circle + aged-gold ring inlay at the arena's center.
	var inner := MeshInstance3D.new()
	inner.name = "FloorEmblemInner"
	var disc := CylinderMesh.new()
	disc.top_radius = 9.0
	disc.bottom_radius = 9.0
	disc.height = 0.04
	inner.mesh = disc
	var inner_material := StandardMaterial3D.new()
	inner_material.albedo_color = Color(0.6, 0.5, 0.36, 1.0)
	inner_material.roughness = 0.95
	inner.material_override = inner_material
	inner.position = Vector3(0, 0.01, 0)
	add_child(inner)

	var ring := MeshInstance3D.new()
	ring.name = "FloorEmblemRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 8.6
	torus.outer_radius = 9.2
	ring.mesh = torus
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.7, 0.55, 0.3, 1.0)
	ring_material.metallic = 0.6
	ring_material.roughness = 0.4
	ring.material_override = ring_material
	ring.position = Vector3(0, 0.05, 0)
	add_child(ring)
