class_name CombatDebug
extends RefCounted
## Global combat debug toggles (D-016). Static on purpose: no autoload needed,
## so it is safe inside `-s` headless SceneTree scripts. The F1 debug overlay
## toggles these together with its own visibility.

static var combat_shapes_visible := false
