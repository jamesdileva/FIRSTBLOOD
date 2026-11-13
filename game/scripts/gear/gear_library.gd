class_name GearLibrary
extends RefCounted
## Sprint 26 (D-080): the session loadout — a static holder (the D-077
## precedent) synced to the shared save file's "equipment" key. One file,
## many owners: every writer read-merges (progression.save() does too), so
## saving XP never drops gear and saving gear never drops XP. The key is
## additive — old saves load with an empty loadout.

const CATALOG_PATH := "res://game/resources/gear/gear_catalog.tres"

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
