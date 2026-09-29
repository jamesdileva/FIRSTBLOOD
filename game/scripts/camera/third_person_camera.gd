extends Node3D
## Sprint 01: basic third-person camera. Follows the player with smoothing and
## orbits via the right stick (camera_* actions). Feel tuning happens in
## Sprint 02 (framing) and Sprint 16 (combat-distance tuning).

@export var target: Node3D
@export var distance := 9.0
@export var turn_speed := 2.5
@export var pitch_min := -0.1
@export var pitch_max := 1.1

var _yaw := 0.0
var _pitch := 0.45

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	if target == null:
		target = get_tree().get_first_node_in_group("player")
	# Snap to the initial framing instead of lerping across the arena.
	global_position = _desired_position()
	_camera.look_at_from_position(global_position, _pivot(), Vector3.UP)

func _physics_process(delta: float) -> void:
	if target == null:
		return
	_yaw = wrapf(_yaw + Input.get_axis("camera_left", "camera_right") * turn_speed * delta, -PI, PI)
	_pitch = clampf(_pitch + Input.get_axis("camera_up", "camera_down") * turn_speed * delta, pitch_min, pitch_max)
	global_position = global_position.lerp(_desired_position(), 1.0 - exp(-8.0 * delta))
	_camera.look_at(_pivot(), Vector3.UP)

func _pivot() -> Vector3:
	return target.global_position + Vector3.UP * 1.5

func _desired_position() -> Vector3:
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	return _pivot() + dir * distance
