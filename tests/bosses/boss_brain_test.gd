# tests/bosses/boss_brain_test.gd
extends GdUnitTestSuite
## Unit tests for BossBrain attack selection (Sprint 10, D-032): range and
## cooldown filtering, weight rules, and the weighted distribution.

func _attack(id: StringName, min_range: float, max_range: float, weight: float) -> BossAttackData:
	var attack := BossAttackData.new()
	attack.attack_id = id
	attack.min_range = min_range
	attack.max_range = max_range
	attack.weight = weight
	return attack

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_returns_null_when_no_candidates() -> void:
	var picked := BossBrain.select_attack([], 2.0, {}, _rng(1))
	assert_bool(picked == null).is_true()

func test_filters_out_of_range_attacks() -> void:
	var near := _attack(&"near", 1.0, 2.5, 1.0)
	var far := _attack(&"far", 4.0, 8.0, 100.0)  # would win if not filtered
	var picked := BossBrain.select_attack([near, far], 1.5, {}, _rng(1))
	assert_bool(picked == near).is_true()

func test_respects_cooldowns() -> void:
	var attack := _attack(&"a", 1.0, 5.0, 1.0)
	var picked := BossBrain.select_attack([attack], 2.0, {&"a": 1.5}, _rng(1))
	assert_bool(picked == null).is_true()

func test_zero_weight_is_excluded() -> void:
	var attack := _attack(&"a", 1.0, 5.0, 0.0)
	var picked := BossBrain.select_attack([attack], 2.0, {}, _rng(1))
	assert_bool(picked == null).is_true()

func test_in_range_and_ready_is_picked() -> void:
	var attack := _attack(&"a", 1.0, 5.0, 2.0)
	var picked := BossBrain.select_attack([attack], 3.0, {}, _rng(1))
	assert_bool(picked == attack).is_true()

func test_range_band_edges_are_inclusive() -> void:
	var attack := _attack(&"a", 1.0, 2.5, 1.0)
	var at_min := BossBrain.select_attack([attack], 1.0, {}, _rng(1))
	var at_max := BossBrain.select_attack([attack], 2.5, {}, _rng(1))
	assert_bool(at_min == attack).is_true()
	assert_bool(at_max == attack).is_true()

func test_weighted_distribution_favors_heavy_weight() -> void:
	var common := _attack(&"common", 1.0, 5.0, 3.0)
	var rare := _attack(&"rare", 1.0, 5.0, 1.0)
	var common_count := 0
	var rng := _rng(42)
	for _i in 4000:
		if BossBrain.select_attack([common, rare], 2.0, {}, rng) == common:
			common_count += 1
	# 75% expected (3000 of 4000); generous band for RNG noise.
	assert_int(common_count).is_between(2700, 3300)

func test_cooldown_expiry_restores_selection() -> void:
	var attack := _attack(&"a", 1.0, 5.0, 1.0)
	assert_bool(BossBrain.select_attack([attack], 2.0, {&"a": 0.5}, _rng(1)) == null).is_true()
	assert_bool(BossBrain.select_attack([attack], 2.0, {&"a": 0.0}, _rng(1)) == attack).is_true()
