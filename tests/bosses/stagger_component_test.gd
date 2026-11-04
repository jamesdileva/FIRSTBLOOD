# tests/bosses/stagger_component_test.gd
extends GdUnitTestSuite
## Unit tests for StaggerComponent (Sprint 13, D-042/043): accumulation,
## threshold crossing, single-window semantics, timed recovery, resistance.

func _make_stagger(threshold: float, duration: float, growth := 1.5) -> StaggerComponent:
	var stagger: StaggerComponent = auto_free(StaggerComponent.new())
	stagger.stagger_threshold = threshold
	stagger.stagger_duration = duration
	stagger.resistance_growth = growth
	stagger.reset()
	return stagger

func _event(stagger_damage: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.stagger_damage = stagger_damage
	return event

func test_below_threshold_does_not_stagger() -> void:
	var stagger := _make_stagger(30.0, 2.0)
	assert_bool(stagger.add_stagger(_event(10.0))).is_false()
	assert_bool(stagger.is_staggered()).is_false()

func test_crossing_threshold_staggers_once() -> void:
	var stagger := _make_stagger(30.0, 2.0)
	assert_bool(stagger.add_stagger(_event(20.0))).is_false()
	assert_bool(stagger.add_stagger(_event(15.0))).is_true()
	assert_bool(stagger.is_staggered()).is_true()

func test_staggered_ignores_further_stagger() -> void:
	var stagger := _make_stagger(30.0, 2.0)
	stagger.add_stagger(_event(30.0))
	assert_bool(stagger.add_stagger(_event(50.0))).is_false()

func test_zero_stagger_damage_is_ignored() -> void:
	var stagger := _make_stagger(30.0, 2.0)
	assert_bool(stagger.add_stagger(_event(0.0))).is_false()
	assert_bool(stagger.is_staggered()).is_false()

func test_window_ends_after_duration_and_rearms() -> void:
	var stagger := _make_stagger(30.0, 2.0)
	var recovered_count := [0]
	stagger.recovered.connect(func() -> void: recovered_count[0] += 1)
	stagger.add_stagger(_event(30.0))
	assert_bool(stagger.tick_recovery(1.0)).is_false()
	assert_bool(stagger.tick_recovery(0.9)).is_false()
	assert_bool(stagger.is_staggered()).is_true()
	assert_bool(stagger.tick_recovery(0.2)).is_true()
	assert_bool(stagger.is_staggered()).is_false()
	assert_int(recovered_count[0]).is_equal(1)
	# re-armed, but resistance raised the threshold to 45 (30 x 1.5):
	# the old 40 points now fall short, 50 crosses
	assert_bool(stagger.add_stagger(_event(10.0))).is_false()
	assert_bool(stagger.add_stagger(_event(50.0))).is_true()

func test_resistance_raises_the_threshold() -> void:
	var stagger := _make_stagger(30.0, 1.0, 2.0)  # growth 2.0 for easy math
	stagger.add_stagger(_event(30.0))
	assert_bool(stagger.tick_recovery(1.1)).is_true()
	# threshold is now 60: the old full-strength combo no longer staggers
	assert_bool(stagger.add_stagger(_event(30.0))).is_false()
	assert_bool(stagger.add_stagger(_event(30.0))).is_true()

func test_reset_clears_everything() -> void:
	var stagger := _make_stagger(30.0, 1.0, 2.0)
	stagger.add_stagger(_event(30.0))
	stagger.tick_recovery(1.1)  # threshold grew to 60
	stagger.reset()
	assert_bool(stagger.is_staggered()).is_false()
	assert_bool(stagger.add_stagger(_event(30.0))).is_true()
