extends CanvasLayer
## Sprint 01 debug overlay (implementation-guide §27): FPS, player position and
## speed, boss distance. F1 toggles. Extended with state/timers in later sprints.

const SAMPLE_INTERVAL := 0.5

var _fps := 0.0
var _frames := 0
var _accum := 0.0

@onready var _label: Label = $Label

func _ready() -> void:
	# The overlay is meaningless without a display. Debug mode (D-016) bundles
	# the overlay and the combat shape visualization together.
	visible = DisplayServer.get_name() != "headless"
	CombatDebug.combat_shapes_visible = visible

func _process(delta: float) -> void:
	_frames += 1
	_accum += delta
	if _accum >= SAMPLE_INTERVAL:
		_fps = _frames / _accum
		_frames = 0
		_accum = 0.0
		_update_text()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		CombatDebug.combat_shapes_visible = visible

func _update_text() -> void:
	var lines: PackedStringArray = ["FPS: %d" % roundi(_fps)]
	# Untyped on purpose: reads dynamic members the player script adds.
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		lines.append("Player state: %s" % player.State.keys()[player.state])
		lines.append("Player pos: (%.1f, %.1f, %.1f)" % [
			player.global_position.x, player.global_position.y, player.global_position.z,
		])
		lines.append("Player speed: %.1f m/s" % Vector3(player.velocity.x, 0.0, player.velocity.z).length())
	var boss := get_tree().get_first_node_in_group("boss") as Node3D
	if player != null and boss != null:
		lines.append("Boss distance: %.1f m" % player.global_position.distance_to(boss.global_position))
	if player != null and (player.state == player.State.DODGE or player.state == player.State.DODGE_RECOVERY):
		var total: float = player.dodge_duration if player.state == player.State.DODGE else player.dodge_recovery
		lines.append("Dodge timer: %.2f s left" % maxf(total - player.state_elapsed, 0.0))
	if player != null and player.is_invulnerable():
		lines.append("i-frames ACTIVE")
	_label.text = "\n".join(lines)
