class_name SetCatalog
extends Resource
## Sprint 36 (D-104): the list of gear sets. Adding a set = adding a
## SetData resource here + tagging pieces with its id; no combat code.

@export var sets: Array[SetData] = []
