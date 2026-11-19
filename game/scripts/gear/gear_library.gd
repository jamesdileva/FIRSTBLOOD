class_name GearLibrary
extends RefCounted
## Sprint 26 (D-080): the session loadout — a static holder (the D-077
## precedent) synced to the shared save file's "equipment" key. One file,
## many owners: every writer read-merges (progression.save() does too), so
## saving XP never drops gear and saving gear never drops XP. The key is
## additive — old saves load with an empty loadout.

const CATALOG_PATH := "res://game/resources/gear/gear_catalog.tres"
const SETS_PATH := "res://game/resources/gear/gear_sets.tres"

static var loadout: Array[StringName] = []
static var _loaded := false

static func catalog() -> GearCatalog:
	return load(CATALOG_PATH) as GearCatalog

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	loadout.clear()
	for id in ProgressionComponent.read_save().get("equipment", []):
		if typeof(id) == TYPE_STRING or typeof(id) == TYPE_STRING_NAME:
			loadout.append(StringName(id))

## Check-isolation hook: force a fresh read (the check save may have been
## deleted after the static already loaded).
static func reload_from_save() -> void:
	_loaded = false
	ensure_loaded()

## Resolve ids against the catalog, skipping unknown ones (a removed or
## renamed item must never crash the load).
static func resolve(ids: Array) -> Array[GearData]:
	var items: Array[GearData] = []
	var by_id := {}
	var gear_catalog := catalog()
	if gear_catalog == null:
		return items
	for item in gear_catalog.items:
		if item != null and not item.id.is_empty():
			by_id[item.id] = item
	for id in ids:
		if by_id.has(StringName(id)):
			items.append(by_id[StringName(id)])
	return items

static func set_catalog() -> SetCatalog:
	return load(SETS_PATH) as SetCatalog

## Sprint 36 (D-103): which sets are ACTIVE for an id list — count the
## equipped pieces per set_id, a set qualifies at its required_pieces.
## The single rule both the EquipmentComponent totals and the armory use.
static func active_sets(ids: Array) -> Array[SetData]:
	var active: Array[SetData] = []
	var sets_catalog := set_catalog()
	if sets_catalog == null:
		return active
	var counts := {}
	for item in resolve(ids):
		if item.set_id != "":
			counts[item.set_id] = int(counts.get(item.set_id, 0)) + 1
	for set_data in sets_catalog.sets:
		if int(counts.get(set_data.id, 0)) >= set_data.required_pieces:
			active.append(set_data)
	return active

static func set_loadout(ids: Array[StringName]) -> void:
	loadout = ids.duplicate()
	save_loadout()

## Read-merge write of the equipment key (see the D-080 class comment).
static func save_loadout() -> void:
	var data := ProgressionComponent.read_save()
	var ids: Array = []
	for id in loadout:
		ids.append(String(id))
	data["equipment"] = ids
	var file := FileAccess.open(ProgressionComponent._save_path(), FileAccess.WRITE)
	if file == null:
		push_warning("Gear save failed: %d" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))
	file.close()
