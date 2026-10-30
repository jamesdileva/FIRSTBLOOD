class_name BossBrain
extends RefCounted
## Deterministic boss decision logic (guide §12), pure and static so it is
## unit-testable. Selects attacks by weight among candidates that are in
## range, off cooldown, and have positive weight — never purely random.

static func select_attack(
		attacks: Array[BossAttackData],
		distance: float,
		cooldowns: Dictionary,
		rng: RandomNumberGenerator,
) -> BossAttackData:
	var candidates: Array[BossAttackData] = []
	var total_weight := 0.0
	for attack in attacks:
		if attack == null:
			continue
		if distance < attack.min_range or distance > attack.max_range:
			continue
		if float(cooldowns.get(attack.attack_id, 0.0)) > 0.0:
			continue
		if attack.weight <= 0.0:
			continue
		candidates.append(attack)
		total_weight += attack.weight
	if candidates.is_empty():
		return null
	var roll := rng.randf() * total_weight
	for attack in candidates:
		roll -= attack.weight
		if roll <= 0.0:
			return attack
	return candidates[candidates.size() - 1]
