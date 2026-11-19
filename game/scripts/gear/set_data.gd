class_name SetData
extends Resource
## Sprint 36 (D-104): one gear set — guide §24's SetData shape. When the
## player wears `required_pieces` items tagged with this set's `id`, the
## modifier fields apply ON TOP of the pieces' own bonuses. The fields are
## the same units as GearData's, so the aggregation is one code path; a
## future triggered-effect bonus extends this structure.

@export var id := ""
@export var display_name := "UNNAMED"
@export var required_pieces := 2
@export var hp_bonus := 0.0
@export var armor := 0.0
@export var attack_bonus := 0.0
@export var movement_bonus := 0.0
@export var attack_speed_bonus := 0.0

## One-line summary for the armory (non-zero fields only).
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
