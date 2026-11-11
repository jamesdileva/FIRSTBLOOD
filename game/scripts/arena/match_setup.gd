class_name MatchSetup
extends RefCounted
## Sprint 25 (D-077): session-level encounter selection. A static holder on
## purpose (the D-065 static precedent) — the choice only has to survive a
## scene change within a session, and autoloads would alter project.godot
## semantics and `-s` check behavior mid-project. `selected == null` means
## the arena keeps its scene-default boss.

const ROSTER_PATH := "res://game/resources/bosses/boss_roster.tres"

static var selected: BossEntry

static func roster() -> BossRoster:
	return load(ROSTER_PATH) as BossRoster
