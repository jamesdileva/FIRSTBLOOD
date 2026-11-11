extends Node3D
## Sprint 25 (D-076): the arena's encounter hook. When a roster selection is
## set, the scene-default boss child is replaced by the selected entry's
## scene at the BossSpawn position — before anything enters the tree, so
## group lookups, the progression binding, and the flow see exactly one boss
## from frame one. No selection: the scene's own New Gladiator stays.

func _enter_tree() -> void:
	var entry := MatchSetup.selected
	if entry == null or entry.scene == null:
		return
	var default_boss := get_node_or_null("Boss")
	if default_boss != null:
		remove_child(default_boss)
		default_boss.free()
	var spawned: Node = entry.scene.instantiate()
	spawned.name = "Boss"
	add_child(spawned)
	var spawn := get_node_or_null("BossSpawn")
	if spawn != null:
		spawned.position = spawn.position
