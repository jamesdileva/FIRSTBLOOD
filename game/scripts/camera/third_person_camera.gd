extends Node3D
## Sprint 01: basic third-person camera. Follows the player with smoothing and
## orbits via the right stick (camera_* actions). Feel tuning happens in
## Sprint 02 (framing) and Sprint 16 (combat-distance tuning).

@export var target: Node3D
@export var distance := 9.0
## Sprint 15.5 wall fix: the orbit never leaves this radius, so the wall ring
## can never sit between the camera and the player.
@export var camera_ring_radius := 17.5
@export var turn_speed := 2.5
@export var pitch_min := -0.1
@export var pitch_max := 1.1

var _yaw := 0.0
## Steeper default: the fighters fill the frame on load (playtest note).
var _pitch := 0.55
## Sprint 15: current shake amplitude (0..~1), decayed per frame.
var shake_level := 0.0

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	if target == null:
		target = get_tree().get_first_node_in_group("player")
	# Snap to the initial framing instead of lerping across the arena.
	global_position = _desired_position()
	_camera.look_at_from_position(global_position, _pivot(), Vector3.UP)

func _process(delta: float) -> void:
	# Sprint 15 camera impulse: consume the feedback bus, decay, offset the
	# camera through h/v offsets (never the tracked transform).
	if HitFeedback.pending_shake > shake_level:
		shake_level = HitFeedback.pending_shake
		HitFeedback.pending_shake = 0.0
	shake_level = maxf(shake_level - 3.0 * delta, 0.0)
	if _camera == null:
		return
	if shake_level > 0.001:
		_camera.h_offset = randf_range(-1.0, 1.0) * 0.18 * shake_level
		_camera.v_offset = randf_range(-1.0, 1.0) * 0.12 * shake_level
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0

func _physics_process(delta: float) -> void:
	if target == null:
		return
	_yaw = wrapf(_yaw + Input.get_axis("camera_left", "camera_right") * turn_speed * delta, -PI, PI)
	_pitch = clampf(_pitch + Input.get_axis("camera_up", "camera_down") * turn_speed * delta, pitch_min, pitch_max)
	var desired := _desired_position()
	# Sprint 15.5 wall fix: pull the horizontal orbit inside the wall ring —
	# the camera lerps in smoothly as the player nears the edge.
	var flat := Vector2(desired.x, desired.z)
	if flat.length() > camera_ring_radius:
		flat = flat.normalized() * camera_ring_radius
		desired.x = flat.x
		desired.z = flat.y
	global_position = global_position.lerp(desired, 1.0 - exp(-8.0 * delta))
	_camera.look_at(_pivot(), Vector3.UP)

func _pivot() -> Vector3:
	return target.global_position + Vector3.UP * 1.5

func _desired_position() -> Vector3:
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	return _pivot() + dir * distance
