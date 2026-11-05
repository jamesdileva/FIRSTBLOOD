class_name HitFeedback
extends RefCounted
## Sprint 15 impact feedback bus (D-049). Static on purpose — no autoload,
## so it works identically in the game and in `-s` headless SceneTree checks
## (the CombatDebug pattern). Actors report hits; the camera consumes shake;
## everything else (hit-stop, bursts, flash, vibration, sound hook) lives here.

static var hit_stop_until_msec := 0
static var last_hit_stop_ms := 0
static var last_hit_heavy := false
static var pending_shake := 0.0
static var impact_bursts_alive := 0
static var _hurt_layer: CanvasLayer
static var _hurt_rect: ColorRect
static var _impact_player: AudioStreamPlayer

static func is_hit_stop_active() -> bool:
	return Time.get_ticks_msec() < hit_stop_until_msec

## The attacker reports a landed swing: hit-stop, camera impulse, impact
## burst, sound hook, vibration — all scaled by hit type (D-051).
static func register_hit(hit_position: Vector3, hit_type: CombatTypes.HitType) -> void:
	var heavy := hit_type != CombatTypes.HitType.NORMAL
	last_hit_heavy = heavy
	last_hit_stop_ms = 90 if heavy else 45
	request_hit_stop(last_hit_stop_ms)
	pending_shake = maxf(pending_shake, 0.8 if heavy else 0.3)
	_spawn_impact(hit_position, heavy)
	play_impact_sound(heavy)
	_vibrate(heavy)

static func request_hit_stop(duration_ms: int) -> void:
	hit_stop_until_msec = maxi(hit_stop_until_msec, Time.get_ticks_msec() + duration_ms)

## The player was hit (taken or mitigated): red flash + heavy vibration.
static func player_hurt(heavy: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_ensure_hurt_overlay(tree)
	_hurt_rect.color.a = 0.35 if heavy else 0.22
	var timer := tree.create_timer(0.12)
	timer.timeout.connect(func() -> void:
		if _hurt_rect != null and is_instance_valid(_hurt_rect):
			_hurt_rect.color.a = 0.0)
	if heavy:
		_vibrate(true)

func _init() -> void:
	pass  # static-only class; never instantiated

static func _vibrate(heavy: bool) -> void:
	var weak := 0.7 if heavy else 0.25
	var strong := 0.9 if heavy else 0.35
	var seconds := 0.25 if heavy else 0.1
	Input.start_joy_vibration(0, weak, strong, seconds)

static func hurt_flash_active() -> bool:
	return _hurt_rect != null and is_instance_valid(_hurt_rect) and _hurt_rect.color.a > 0.0

static func _spawn_impact(position: Vector3, heavy: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var burst := MeshInstance3D.new()
	burst.name = "ImpactBurst"
	var mesh := SphereMesh.new()
	mesh.radius = 0.28 if heavy else 0.16
	mesh.height = 0.56 if heavy else 0.32
	burst.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.6, 0.25, 0.85) if heavy else Color(1.0, 0.95, 0.75, 0.7)
	burst.material_override = material
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.position = position
	impact_bursts_alive += 1
	tree.root.add_child(burst)
	var timer := tree.create_timer(0.16)
	timer.timeout.connect(func() -> void:
		impact_bursts_alive -= 1
		burst.queue_free())

## Placeholder sound hook (guide: sound hooks without shipping audio). When
## the art pass assigns a stream, this plays it — heavier hits pitch down.
static func play_impact_sound(heavy: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _impact_player == null or not is_instance_valid(_impact_player):
		_impact_player = AudioStreamPlayer.new()
		_impact_player.name = "ImpactSoundHook"
		tree.root.add_child(_impact_player)
	if _impact_player.stream != null:
		_impact_player.pitch_scale = 0.8 if heavy else 1.0
		_impact_player.play()

static func _ensure_hurt_overlay(tree: SceneTree) -> void:
	if _hurt_rect != null and is_instance_valid(_hurt_rect):
		return
	_hurt_layer = CanvasLayer.new()
	_hurt_layer.name = "HurtFeedback"
	_hurt_layer.layer = 90
	_hurt_rect = ColorRect.new()
	_hurt_rect.name = "HurtFlash"
	_hurt_rect.color = Color(0.8, 0.1, 0.1, 0.0)
	_hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_layer.add_child(_hurt_rect)
	tree.root.add_child(_hurt_layer)
