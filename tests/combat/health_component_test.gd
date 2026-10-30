# tests/combat/health_component_test.gd
extends GdUnitTestSuite
## Unit tests for HealthComponent math (Sprint 10, D-032): reduction, clamping,
## die-once semantics, no healing-by-damage after death, reset, zero amounts.

func _make_health(max_hp: float) -> HealthComponent:
	var health: HealthComponent = auto_free(HealthComponent.new())
	health.max_health = max_hp
	health.reset()
	return health

func _event(amount: float, hit_type := CombatTypes.HitType.NORMAL) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	event.hit_type = hit_type
	return event

func test_apply_damage_reduces_health() -> void:
	var health := _make_health(100.0)
	health.apply_damage(_event(30.0))
	assert_float(health.current_health).is_equal_approx(70.0, 0.001)

func test_health_clamps_at_zero_and_dies_exactly_once() -> void:
	var health := _make_health(50.0)
	var deaths := [0]  # array: lambdas capture locals by value
	health.died.connect(func() -> void: deaths[0] += 1)
	for _i in 3:
		health.apply_damage(_event(30.0))
	assert_float(health.current_health).is_equal_approx(0.0, 0.001)
	assert_int(deaths[0]).is_equal(1)
	assert_bool(health.is_dead()).is_true()

func test_no_damage_after_death() -> void:
	var health := _make_health(10.0)
	health.apply_damage(_event(20.0))
	health.apply_damage(_event(20.0))
	assert_float(health.current_health).is_equal_approx(0.0, 0.001)

func test_reset_revives_and_restores() -> void:
	var health := _make_health(40.0)
	health.apply_damage(_event(40.0))
	assert_bool(health.is_dead()).is_true()
	health.reset()
	assert_float(health.current_health).is_equal_approx(40.0, 0.001)
	assert_bool(health.is_dead()).is_false()

func test_zero_amount_is_ignored() -> void:
	var health := _make_health(30.0)
	var damaged_count := [0]  # array: lambdas capture locals by value
	health.damaged.connect(func(_event: DamageEvent) -> void: damaged_count[0] += 1)
	health.apply_damage(_event(0.0))
	assert_float(health.current_health).is_equal_approx(30.0, 0.001)
	assert_int(damaged_count[0]).is_equal(0)

func test_signals_fire_once_per_hit() -> void:
	var health := _make_health(20.0)
	var changed := [0]  # arrays: lambdas capture locals by value
	var damaged_count := [0]
	health.health_changed.connect(func(_current: float, _maximum: float) -> void: changed[0] += 1)
	health.damaged.connect(func(_event: DamageEvent) -> void: damaged_count[0] += 1)
	health.apply_damage(_event(5.0))
	assert_int(changed[0]).is_equal(1)
	assert_int(damaged_count[0]).is_equal(1)
