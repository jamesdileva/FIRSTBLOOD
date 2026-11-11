class_name BossEntry
extends Resource
## Sprint 25 (D-076): one selectable encounter. Pure data — a display name,
## a one-line blurb for the select screen, and the boss scene to load.
## Adding a boss means adding one of these pointing at a boss scene; the
## selector and the arena swap need no changes.

@export var display_name := "UNNAMED"
@export var blurb := ""
@export var scene: PackedScene
