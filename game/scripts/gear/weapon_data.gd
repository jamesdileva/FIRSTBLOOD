class_name WeaponData
extends GearData
## Sprint 27 (D-082): a weapon variant — gear that carries attack behavior.
## The slot is &"WEAPON"; equipping one swaps the player's ComboData and
## blade visuals through the single `_apply_weapon()` hook. Everything else
## (armory rows, one-per-slot swap, save persistence) is the Sprint 26
## gear framework unchanged.

@export var combo: ComboData
@export var visual_color := Color(0.82, 0.8, 0.75)
@export var blade_length := 1.0

func summary() -> String:
	var text := super.summary()
	if combo == null:
		return text
	var damages: PackedStringArray = []
	for step in combo.steps:
		damages.append("%.0f" % step.damage)
	if combo.finisher != null:
		damages.append("%.0f F" % combo.finisher.damage)
	if damages.is_empty():
		return text
	var swings := "swings " + "/".join(damages)
	if text == "No modifiers":
		return swings
	return text + " · " + swings
