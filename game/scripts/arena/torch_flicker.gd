extends OmniLight3D
## Sprint 18 presentation-only torch flicker. Purely visual: modulates the
## light energy around its set base. No gameplay reads or writes this.

@export var base_energy := 2.0
@export var flicker_amount := 0.5
@export var flicker_speed := 9.0

var _time := 0.0

func _ready() -> void:
	_time = randf() * 10.0  # desync multiple torches

func _process(delta: float) -> void:
	_time += delta
	light_energy = base_energy + sin(_time * flicker_speed) * flicker_amount * 0.5 \
			+ sin(_time * flicker_speed * 2.7) * flicker_amount * 0.3
