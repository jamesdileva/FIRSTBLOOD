class_name GearData
extends Resource
## Sprint 26 (D-079): one equippable piece — guide §24 fields minus the
## explicitly-post-MVP ones (elemental effects, gear sets). Bonuses use the
## same units as the level stats (D-066): flat HP, flat armor soak, flat
## attack damage, flat m/s, and a fraction added to the attack-speed
## multiplier. `id` is the persistence key in the save's equipment list.

@export var id := ""
@export var display_name := "UNNAMED"
@export var slot := &"BODY"
@export var hp_bonus := 0.0
@export var armor := 0.0
@export var attack_bonus := 0.0
@export var movement_bonus := 0.0
@export var attack_speed_bonus := 0.0

## One-line stat summary for the armory rows (non-zero fields only).
func summary() -> String:
	var parts: PackedStringArray = []
	if hp_bonus != 0.0:
		parts.append("%+.0f HP" % hp_bonus)
	if armor != 0.0:
		parts.append("Armor %.0f" % armor)
	if attack_bonus != 0.0:
		parts.append("%+.0f ATTACK" % attack_bonus)
	if movement_bonus != 0.0:
		parts.append("%+.2f m/s" % movement_bonus)
	if attack_speed_bonus != 0.0:
		parts.append("%+.0f%% swing" % (attack_speed_bonus * 100.0))
	return " · ".join(parts) if not parts.is_empty() else "No modifiers"
