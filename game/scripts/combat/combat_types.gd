class_name CombatTypes
extends RefCounted
## Shared combat enums and the physics-layer plan (D-013).
## Layers: 1 world · 2 player body · 3 boss body · 4 player_hurtbox · 5 boss_hurtbox.

enum Faction { PLAYER, BOSS, NEUTRAL }
enum HitType { NORMAL, HEAVY, SPECIAL }

static func hurtbox_layer(faction: Faction) -> int:
	match faction:
		Faction.PLAYER:
			return 1 << 3  # layer 4
		Faction.BOSS:
			return 1 << 4  # layer 5
		_:
			return 0

static func hitbox_mask(faction: Faction) -> int:
	# A hitbox only ever sees the opposing faction's hurtboxes.
	match faction:
		Faction.PLAYER:
			return 1 << 4
		Faction.BOSS:
			return 1 << 3
		Faction.NEUTRAL:
			return (1 << 3) | (1 << 4)  # hazards hit everyone
		_:
			return 0
