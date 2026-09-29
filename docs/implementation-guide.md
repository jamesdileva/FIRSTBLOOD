# Boss Arena Gladiator --- Implementation Guide

This guide describes how to build the game one system at a time while
preserving working functionality.

# 1. Implementation Philosophy

## One System at a Time

Each sprint should change one understandable area of the project.

When implementing:

1.  Identify the exact files affected.
2.  Preserve existing behavior.
3.  Make the smallest complete change.
4.  Run the sprint verification.
5.  Only then move to the next system.

Do not replace a large working script with a new architecture unless the
current structure is genuinely blocking progress.

## Build the Combat Sandbox First

Before creating polished bosses, establish a test arena where the
following can be inspected quickly:

-   Player movement.
-   Dodge.
-   Attack.
-   Block.
-   Hitboxes.
-   Boss attacks.
-   Telegraphs.
-   Stagger.
-   Recovery.

# 2. Initial Godot Setup

Use a current stable Godot 4.x release validated when the project is
initialized.

Create:

``` text
project.godot
```

Configure:

-   3D renderer appropriate to the target hardware.
-   Window resolution.
-   60 FPS target.
-   Controller input actions.
-   Main scene.

Recommended input actions:

``` text
move_left
move_right
move_forward
move_back
attack
block
dodge
spell_modifier
spell_a
spell_b
spell_x
spell_y
pause
```

Use input actions instead of hard-coded device buttons so controller
mappings remain configurable.

# 3. Scene Architecture

A useful initial player scene:

``` text
Player
├── CharacterBody3D
├── CollisionShape3D
├── Visual
│   └── Mesh / AnimatedModel
├── Hurtbox
├── Hitboxes
├── AnimationPlayer / AnimationTree
├── StateMachine
├── CameraTarget
└── Audio/VFX hooks
```

Boss:

``` text
Boss
├── CharacterBody3D
├── CollisionShape3D
├── Visual
├── Hurtbox
├── Hitboxes
├── StateMachine
├── TelegraphController
├── AttackController
├── HealthComponent
└── Audio/VFX hooks
```

Keep combat components reusable.

# 4. State Machine

Do not place every behavior into one enormous `_physics_process()`
function.

Use a state model such as:

``` text
IDLE
MOVE
ATTACK
BLOCK
DODGE
STAGGER
RECOVERY
DEAD
```

For bosses:

``` text
OBSERVE
APPROACH
SELECT_ATTACK
TELEGRAPH
ATTACK
RECOVERY
STAGGER
BREAKOUT
DEFENSIVE_RESPONSE
ENRAGED
DEAD
```

The state machine should answer:

-   What can the actor do right now?
-   What input is accepted?
-   Can the current state be interrupted?
-   When does it transition?

# 5. Combat Timing Model

Do not bury timing numbers throughout scripts.

Create attack data with values such as:

``` text
startup
active_duration
recovery
combo_window
damage
stagger_damage
knockback
finisher
```

A conceptual attack lifecycle is:

``` text
Input
  ↓
Startup
  ↓
Active Hitbox
  ↓
Recovery
  ↓
Next Combo / Neutral
```

This allows tuning without rewriting behavior.

# 6. Hitbox / Hurtbox Architecture

A hitbox represents an attack area.

A hurtbox represents a damageable area.

A damage payload can contain:

``` text
damage
stagger_damage
hit_type
source
knockback
status_effect
```

Keep the damage receiver separate from the attack itself.

This allows the same system to support:

-   Player attacks.
-   Boss attacks.
-   Magic.
-   Environmental hazards.
-   Future status effects.

# 7. Block Implementation

Block should have explicit states/timers:

``` text
Neutral
  ↓
Block Active
  ↓
Block Recovery
  ↓
Neutral
```

Suggested initial tuning:

``` text
active: 2–3 seconds
recovery: ~1 second
```

These are starting points only.

A normal boss attack during active block should:

1.  Register the collision.
2.  Check the defender's block state.
3.  Negate damage.
4.  Produce block feedback.
5.  Apply boss stagger if configured.

A telegraphed heavy attack can instead:

-   Reduce damage.
-   Apply knockback.
-   Consume some defensive resource if one exists later.
-   Avoid full stagger.

Do not allow the player to re-enter active block while recovery is still
running.

# 8. Dodge Implementation

Dodge should be implemented as a movement state, not as an arbitrary
teleport.

Conceptual flow:

``` text
Neutral
  ↓
Dodge Start
  ↓
Dodge Movement
  ↓
Dodge End
  ↓
Recovery
  ↓
Neutral
```

During the active dodge window:

-   Movement is controlled by dodge velocity.
-   Normal attacks should not override it.
-   Invulnerability, if used, should have a precisely defined window.

During recovery:

-   The player can be vulnerable.
-   Another dodge should not bypass the intended commitment.

The goal is to prevent button-mashing from becoming permanent defense
while keeping the movement fast.

# 9. Combo Implementation

Represent the combo as data rather than separate hard-coded methods:

``` text
Combo
├── Attack 1
├── Attack 2
├── Attack 3
└── Finisher
```

Each attack has its own:

-   Animation.
-   Damage.
-   Timing.
-   Hitbox.
-   Input buffer window.

Input buffering is important. If the player presses attack slightly
before the next attack window, the input can be remembered and consumed
at the correct transition.

Reset the combo when:

-   The player stops attacking for too long.
-   The player enters an incompatible defensive state.
-   The finisher completes.
-   The actor is interrupted.

# 10. Automatic Finisher

The first MVP finisher should require no additional button.

Conceptually:

``` text
Attack 1 → Attack 2 → Attack 3 → Finisher
```

Later, support:

``` text
Attack Chain
   ↓
Finisher A
   ↓
Finisher B
   ↓
Finisher C
```

The sequence should be controlled by data so a gear set or weapon can
change the finisher sequence without modifying the combo engine.

# 11. Boss Architecture

The boss should be built from reusable systems rather than a single
bespoke script.

Recommended responsibilities:

### BossController

Coordinates high-level behavior.

### BossStateMachine

Controls behavior states.

### AttackController

Selects and executes attacks.

### TelegraphController

Displays warnings and manages windup timing.

### HealthComponent

Handles damage, death, and health state.

### StaggerComponent

Handles stagger duration, resistance, and breakout rules.

# 12. Boss Attack Data

A boss attack resource should contain values such as:

``` text
name
range
startup
active_duration
recovery
damage
stagger_damage
telegraph_type
telegraph_duration
attack_type
block_behavior
stagger_behavior
cooldown
```

The boss AI chooses from valid attacks based on:

-   Distance.
-   Cooldown.
-   Current state.
-   Previous attack.
-   Player position.
-   Boss phase.

Avoid selecting completely randomly. Weighted selection or contextual
rules make behavior more intentional.

# 13. Telegraph Implementation

A telegraph is a gameplay event:

``` text
Attack Selected
      ↓
Telegraph Started
      ↓
Player Reads Warning
      ↓
Attack Activates
      ↓
Recovery
```

The visual can be:

-   Animation.
-   Arena indicator.
-   Weapon glow.
-   Ground marker.
-   Pose change.
-   Audio cue.

Use multiple signals when appropriate, but keep the intended response
obvious.

Debug mode should show the exact remaining telegraph time.

# 14. Stagger System

A simple stagger model:

``` text
Neutral
  ↓
Stagger Threshold Reached
  ↓
Staggered
  ↓
Punish Window
  ↓
Breakout
  ↓
Recovery / Attack
```

Store:

``` text
stagger_duration
stagger_resistance
finisher_count
breakout_threshold
```

This lets future bosses have different resistance without changing the
global combat system.

# 15. Boss Breakout

The purpose of breakout is to prevent infinite player combos.

Example MVP rule:

``` text
Boss staggered
↓
Player attacks
↓
Finisher lands
↓
Boss exits stagger
↓
Boss defends or attacks
```

Later, the same mechanism can support multiple chained finishers.

# 16. Animation Architecture

Animation should communicate gameplay timing rather than dictate it
blindly.

Separate:

-   Gameplay timing.
-   Animation playback.
-   Hitbox activation.
-   State transitions.

Animations should have readable anticipation and impact, while gameplay
movement remains responsive.

Useful animation naming:

``` text
idle
run
walk
attack_01
attack_02
attack_03
finisher_01
block_start
block_loop
block_recover
dodge_start
dodge_loop
dodge_recover
hit_light
hit_heavy
stagger
breakout
death
```

# 17. Blender Pipeline

Use Blender for:

-   Character modeling.
-   Boss modeling.
-   Weapons.
-   Arena geometry.
-   Props.
-   Rigging.
-   Animation.

Recommended interchange format:

``` text
GLB / glTF
```

Keep source files under:

``` text
assets/blender/
```

Exported assets go under:

``` text
assets/exported/
```

# 18. Blender Naming Rules

Use predictable names because automation will eventually depend on them.

Example:

``` text
Boss_Minotaur
Boss_Medusa
Weapon_GladiatorSword
Arena_Colosseum
Anim_Attack_01
Anim_Dodge
Anim_Stagger
```

Avoid names such as:

``` text
final_final2
newboss
thing
SwordNew
```

# 19. AI-Assisted Asset Workflow

An AI agent can help create production scaffolding.

Recommended workflow:

``` text
Boss concept
    ↓
Gameplay specification
    ↓
Model requirements
    ↓
Blender generation/editing
    ↓
Rig
    ↓
Animations
    ↓
GLB export
    ↓
Godot import
    ↓
Combat test
    ↓
Revision
```

AI is especially useful for repetitive work:

-   Blender Python scripts.
-   Mesh generation helpers.
-   Naming.
-   Export scripts.
-   Material setup.
-   Godot resource generation.
-   Validation scripts.

Do not treat generated assets as automatically production-ready. Review:

-   Silhouette.
-   Rig quality.
-   Animation timing.
-   Foot placement.
-   Hitbox placement.
-   Readability.
-   Performance.

# 20. Asset Quality Gate

Before an asset enters a playable boss:

-   Correct scale.
-   Correct origin.
-   Correct orientation.
-   Correct naming.
-   Valid rig.
-   Required animations present.
-   Materials render correctly.
-   Collision works.
-   No excessive geometry.
-   No obvious animation deformation.

# 21. Colosseum Scene

The arena should be intentionally reusable.

Recommended structure:

``` text
Colosseum
├── ArenaFloor
├── ArenaWalls
├── PlayerSpawn
├── BossSpawn
├── CameraBounds
├── Lighting
├── EnvironmentProps
├── VFXPoints
└── AudioPoints
```

Boss-specific visual identity can later be layered onto the same core
arena.

# 22. Camera

Use a third-person camera with a clear combat framing target.

Priorities:

1.  Keep player and boss visible.
2.  Avoid sudden clipping.
3.  Maintain readable distance.
4.  Avoid excessive camera motion.
5.  Support arena boundaries.

Camera tuning belongs in the combat-feel phase, not only in final
polish.

# 23. Progression Implementation

Use a progression resource or manager containing:

``` text
level
xp
xp_to_next
base_hp
base_attack
movement_speed
attack_speed
```

On level-up:

1.  Add level.
2.  Apply configured stat changes.
3.  Save.
4.  Update HUD.

Keep the first version intentionally simple.

# 24. Gear Implementation

Gear should be data-driven.

Example structure:

``` text
GearData
├── name
├── slot
├── hp_bonus
├── armor
├── attack_modifier
├── movement_modifier
├── attack_speed_modifier
├── elemental_effects
└── set_id
```

Set data can contain:

``` text
SetData
├── name
├── required_pieces
└── bonuses
```

Do not hard-code Flame Set or Gladiator Set effects directly into the
player controller.

# 25. Magic Implementation

Magic uses four equipped slots backed by a larger spell library.

``` text
MagicLoadout
├── slot_a
├── slot_b
├── slot_x
└── slot_y
```

Input flow:

``` text
Hold LB
  ↓
Press A/B/X/Y
  ↓
Resolve equipped spell
  ↓
Check mana/cooldown
  ↓
Cast
```

A spell resource can contain:

``` text
name
mana_cost
cooldown
cast_time
effect_type
damage
heal_amount
status_effect
area_radius
```

# 26. Save System

For MVP, local save is sufficient.

Store only what is needed:

``` text
XP
Level
Stats
Settings
```

Later:

``` text
Unlocked bosses
Gear
Gear sets
Magic
Finishers
Difficulty
Modes
```

Save after meaningful progression events rather than every frame.

# 27. Debug Tools

Create a debug overlay early rather than waiting until the end.

Display:

``` text
FPS
Player State
Boss State
Attack
Combo Step
Block Timer
Dodge Timer
Stagger Timer
Distance
Player HP
Boss HP
```

Useful toggles:

``` text
Show hitboxes
Show hurtboxes
Freeze boss
Freeze player
Force stagger
Force attack
Reset fight
```

These tools dramatically reduce combat tuning time.

# 28. Automated Validation

Eventually add scripts that validate:

-   Missing resources.
-   Invalid attack references.
-   Missing animations.
-   Duplicate IDs.
-   Broken boss data.
-   Invalid gear set references.
-   Missing magic slots.

Asset validation can live under:

``` text
tools/validation/
```

# 29. AI Coding-Agent Rules

If an AI coding agent is used, give it these rules:

1.  Read the architecture and current sprint before editing.
2.  Inspect existing files before replacing them.
3.  Make one feature change at a time.
4.  Preserve existing functionality.
5.  Never remove working menu/input/save functionality without explicit
    instruction.
6.  State exact files changed.
7.  Explain what changed briefly.
8.  Provide verification steps.
9.  Do not silently change design assumptions.
10. If a requested feature conflicts with the architecture, stop and
    identify the conflict before rewriting the project.

# 30. Recommended Development Loop

For every sprint:

``` text
Read sprint
  ↓
Inspect current project
  ↓
Identify files
  ↓
Implement smallest change
  ↓
Run project
  ↓
Run verification checklist
  ↓
Fix only failures
  ↓
Commit
  ↓
Next sprint
```

This is particularly important for combat because changing several
timing systems at once makes it difficult to know what caused a new
problem.

# 31. Verification Template

Use this structure in development notes:

``` text
Sprint: XX

Implemented:
- ...

Files changed:
- ...

Verification:
[ ] Project launches
[ ] Feature works
[ ] Existing combat still works
[ ] Controller works
[ ] No console errors
[ ] No soft-lock

Result:
PASS / FAIL

Notes:
- ...
```

# 32. Performance Targets

Initial target:

``` text
60 FPS
```

Measure:

-   Frame time.
-   Draw calls.
-   Memory.
-   VFX cost.
-   Physics cost.
-   Animation cost.

Do not prematurely optimize everything. Profile representative fights
first.

# 33. Final Implementation Order

The intended implementation order is:

``` text
Project
↓
Movement
↓
Dodge
↓
Hitbox/Hurtbox
↓
Attack
↓
Combo
↓
Finisher
↓
Block
↓
Defense Integration
↓
Boss Framework
↓
Telegraphs
↓
New Gladiator
↓
Stagger
↓
Breakout
↓
Combat Feel
↓
Colosseum
↓
Progression
↓
HUD/Menus
↓
MVP Validation
↓
Bosses
↓
Gear
↓
Magic
↓
Advanced Combat
↓
Difficulty
↓
Optional Modes
↓
Hardening
```

# 34. Most Important Implementation Rule

If the game does not feel good by the combat-tuning sprint, **stop
adding content**.

Do not respond to weak combat by adding:

-   More bosses.
-   More gear.
-   More spells.
-   More weapons.
-   More modes.

Instead fix:

-   Movement.
-   Input response.
-   Attack timing.
-   Block timing.
-   Dodge recovery.
-   Telegraph readability.
-   Stagger behavior.
-   Camera.
-   Hit feedback.
-   Animation transitions.

The project succeeds or fails on whether the simple arena fight is
enjoyable before the large feature set arrives.
