# Boss Arena Gladiator --- Architecture

## 1. Project Summary

**Boss Arena Gladiator** is a controller-first 3D boss-rush gladiator
game built around readable, responsive melee combat in a reusable
Colosseum arena.

The player begins as an unequipped gladiator with a dull sword and no
armor. Progression comes from surviving fights, earning XP even after
failure, leveling core stats, and eventually acquiring weapons, armor,
magic, finishers, and mobility-focused builds.

The game is deliberately not an MMO, live-service game, or large
open-world RPG. The central loop is:

> Enter arena → read boss → attack/defend/dodge → exploit stagger →
> finish → earn progression → fight a mechanically different boss.

## 2. Design Pillars

1.  **Small control set, deep combat.** A few actions should produce
    meaningful decisions.
2.  **Readable bosses.** Telegraphs communicate danger before attacks
    land.
3.  **Responsive movement.** Controls should feel fast and springy even
    when attack animations are visually deliberate.
4.  **Defense is useful but not free.** Blocking is generous, while
    recovery prevents permanent turtling.
5.  **Dodge is mobility plus defense.** It is effectively reusable, but
    recovery and commitment create risk.
6.  **Stagger creates offense windows.** Successful defense and attacks
    can create short periods where the boss can be chain-hit.
7.  **Bosses are mechanically distinct, not a difficulty ladder.** A
    later boss may be more complicated without simply having more HP.
8.  **Every attempt has value.** XP is awarded on failure as well as
    victory.
9.  **Builds should eventually change how the game is played.** Gear
    sets, magic, finishers, and mobility can create radically different
    playstyles.
10. **MVP proves the combat before content expands.**

## 3. MVP --- "First Blood"

### Included

-   One reusable Colosseum arena.
-   One player character.
-   One boss: **New Gladiator**.
-   Controller-first input.
-   Third-person camera.
-   Movement.
-   Dodge/roll/dash.
-   Light attack chain.
-   Automatic finisher.
-   Block with active and recovery windows.
-   Hitbox/hurtbox combat.
-   Boss telegraphs.
-   Boss damage, stagger, recovery, and death.
-   Player health and defeat.
-   Victory and retry flow.
-   XP on victory and failure.
-   Basic level progression.
-   Basic stats: HP, attack, movement speed, attack speed.
-   HUD.
-   Pause/restart.
-   Debug combat overlay.

### Explicitly Deferred

-   Mythological bosses.
-   Boss selection.
-   Magic.
-   Complex gear.
-   Gear sets.
-   Multiple finishers.
-   Large weapon catalog.
-   Mobility skill tree.
-   Critical/Proud difficulty.
-   Wave survival.
-   Dungeon exploration.
-   Online multiplayer.
-   Procedural world generation.
-   Story campaign.

## 4. Core Combat Model

### Controller Concept

The exact final mapping can be tuned during implementation, but the
design should remain compact:

-   Left stick: movement.
-   Face button: light attack.
-   Dedicated defensive button: block.
-   Dedicated movement/defensive button: dodge.
-   Future LB modifier + A/B/X/Y: four equipped spells.

### Light Attack Chain

The basic attack is a short chain of approximately 3--4 attacks. The
final attack automatically becomes the equipped finisher.

The player should not need to maintain a large action bar or manually
select every combo step.

### Future Finisher Chaining

After MVP, multiple finishers can be equipped. Once a finisher is
triggered, compatible finishers can automatically chain according to the
configured sequence.

The system should be data-driven so additional finishers do not require
rewriting the player controller.

## 5. Blocking

Block is intentionally generous rather than frame-perfect.

Suggested initial tuning:

-   Approximately 2--3 seconds of active block.
-   Approximately 1 second of recovery/vulnerability.
-   Re-entering block immediately should not bypass recovery.
-   Normal, non-telegraphed boss chain attacks can be completely
    blocked.
-   A successful normal block can leave the boss staggered.
-   Telegraphed heavy/special attacks may be reduced rather than
    completely negated.

The numbers are tuning targets, not hard-coded design requirements.

## 6. Dodge

Dodge/roll/dash is faster than normal walking and is effectively
reusable.

It is deliberately constrained by commitment:

-   The player must finish the current dodge.
-   A short finishing/recovery vulnerability (playtest-tuned to roughly
    0.1--0.2 s) prevents continuous invulnerability. Recovery does not
    lock movement: walking/running resumes immediately, and only
    re-dodging is blocked until recovery completes.
-   Dodge should function as both an escape and positioning tool.

## 7. Hit, Stagger, and Boss Breakout

A successful combat interaction can place the boss into a stagger state.

While staggered:

-   The boss cannot immediately retaliate.
-   The player can chain attacks.
-   The player gets a meaningful punish window.

After one finisher in the MVP model, or a configured chained-finisher
sequence later, the boss breaks out of stagger and can block or attack
again.

Bosses can have different stagger durations and resistances.

## 8. Boss State Architecture

Recommended state model:

-   Idle / Observe
-   Approach
-   Attack Selection
-   Telegraph
-   Attack Active
-   Recovery
-   Staggered
-   Breakout
-   Defensive Response
-   Enraged / Special Phase
-   Defeated

Boss logic should select attacks through data rather than hard-coding
every attack inside a monolithic boss script.

## 9. Telegraph System

Telegraphs are a primary design system, not cosmetic effects.

Every dangerous boss attack should communicate:

-   What the boss is about to do.
-   Rough timing.
-   Direction or area of danger where possible.
-   Whether blocking, dodging, or repositioning is the intended
    response.

Telegraphs should be readable at normal camera distance and should
remain understandable during visual effects.

## 10. New Gladiator --- MVP Boss

The New Gladiator is the tutorial/fundamentals opponent.

Purpose:

-   Teach attack timing.
-   Teach blocking.
-   Teach dodge recovery.
-   Teach stagger.
-   Teach finishing.
-   Validate camera distance and arena scale.

The boss should use straightforward melee strings with readable windups
and predictable recovery.

It should be possible for a new player to understand the basic combat
loop without reading a manual.

## 11. Post-MVP Boss Catalog

The bosses below are documented now so the concept is not lost. They
should not expand MVP scope.

### Minotaur

-   Charge attacks.
-   Heavy melee.
-   Shockwaves.
-   Strong positioning pressure.

### Medusa

-   Petrification threat.
-   Ranged attacks.
-   Reflection mechanics.
-   Positioning and facing pressure.

### Giant Spider

-   Web attacks.
-   Poison.
-   Pounce.
-   Possible summons.

### Giant Crab

-   Heavy armor.
-   Sweeping claws.
-   Shorter punish windows.
-   Distinct front/side positioning rules.

### Mutated Lion

-   Fast pursuit.
-   Pounce.
-   Bleed.
-   Aggressive/enrage behavior.

### Hydra

-   Multiple heads.
-   Regeneration.
-   Target management.
-   Potentially changing attack patterns based on remaining heads.

### Hades

-   Resurrection.
-   Summons.
-   Multiple phases.
-   Arena control.

### Zeus

-   Lightning.
-   Ranged pressure.
-   Arena-wide attacks.
-   Enrage behavior.

Future idea bucket: Cerberus, Cyclops, Siren, Kraken-like beast,
Chimera, Talos, giant scorpion, Gorgon variants, colossal undead
champion.

## 12. Progression

XP is awarded for attempts so failure still advances the player.

Initial stats:

-   HP.
-   Attack.
-   Movement speed.
-   Attack speed.

Keep MVP progression simple. The purpose is to establish the loop rather
than create a full RPG economy.

## 13. Gear

Post-MVP gear can provide:

-   HP.
-   Armor.
-   Elemental effects.
-   Magic modifiers.
-   Movement/attack modifiers.
-   Set bonuses.

Visual progression should move from:

> no armor + dull blade → knight armor → ornate/golden weapons →
> increasingly fantastical/futuristic gladiator equipment.

### Example Build Identities

**Flame Set** - Fire magic becomes dramatically stronger. - Fire attacks
can become large-area attacks.

**Gladiator Set** - Extreme movement speed. - Increased attack speed. -
"Gladiator ninja" feel. - Finisher creates an explosion.

## 14. Magic

Magic is post-MVP.

The player equips four spells from a larger pool.

Suggested controller model:

-   Hold LB.
-   A/B/X/Y selects one of four equipped spells.

Example spells:

-   Heal.
-   Reflect.
-   Fire.
-   Freeze.

Mana depletes on use and regenerates after a delay. Exact values are
tuning decisions.

## 15. Mobility Abilities

Mobility upgrades can eventually expand the basic dodge/movement model
with abilities such as:

-   Enhanced dash.
-   Air movement.
-   Short teleport.
-   Extended dodge.
-   Directional burst.

These are post-MVP because movement must first feel correct without
them.

## 16. Difficulty Modes

Normal should be accessible enough to teach the combat system.

Critical/Proud is post-MVP and should change behavior rather than merely
inflating HP.

Possible modifiers:

-   Boss speed.
-   Attack timing.
-   Shorter telegraphs.
-   Additional attacks.
-   More aggressive behavior.
-   Halo/skull-style modifiers.
-   Different recovery windows.

## 17. Alternative Modes

Boss Rush is a natural post-MVP extension because it reinforces the core
identity.

Endless wave survival and dungeon exploration are experimental ideas.
They should only be implemented if they strengthen the boss-arena loop
rather than dilute it.

## 18. Art Direction

Recommended MVP direction: **stylized low-poly/cartoon 3D**.

Goals:

-   Strong silhouettes.
-   Simple materials.
-   Readable attacks.
-   Efficient rendering.
-   Reusable assets.
-   Visually distinctive bosses without AAA production costs.

A reusable Colosseum dramatically reduces environment scope. Boss
identity can later be reinforced with lighting, VFX, props, and arena
dressing.

## 19. AI-Assisted Art Pipeline

AI agents can assist with:

1.  Boss concept/specification.
2.  Modeling requirements.
3.  Blender Python/procedural modeling.
4.  Rigging/animation scaffolding.
5.  Asset naming and organization.
6.  Godot import/setup.
7.  Automated validation.
8.  Iterative corrections.

Recommended pipeline:

> Concept → gameplay specification → Blender generation/editing →
> rig/animation → GLB/glTF export → Godot import → gameplay test →
> revision.

Human review remains important for silhouette, timing, readability,
hitboxes, animation quality, consistency, and performance.

## 20. Technical Stack

-   Godot 4.x stable branch validated at project initialization.
-   GDScript for MVP.
-   Blender for 3D asset creation.
-   glTF/GLB for interchange.
-   Git for version control.
-   Local saves.
-   No online service dependency.

## 21. Repository Structure

``` text
boss-arena-gladiator/
├── project.godot
├── README.md
├── docs/
│   ├── architecture.md
│   ├── sprint-roadmap.md
│   ├── implementation-guide.md
│   ├── boss-catalog.md
│   └── combat-tuning.md
├── game/
│   ├── scenes/
│   │   ├── arena/
│   │   ├── player/
│   │   ├── bosses/
│   │   ├── ui/
│   │   └── effects/
│   ├── scripts/
│   │   ├── player/
│   │   ├── combat/
│   │   ├── bosses/
│   │   ├── progression/
│   │   ├── items/
│   │   ├── magic/
│   │   ├── camera/
│   │   └── ui/
│   ├── resources/
│   │   ├── attacks/
│   │   ├── bosses/
│   │   ├── items/
│   │   ├── abilities/
│   │   └── progression/
│   └── shaders/
├── assets/
│   ├── blender/
│   │   ├── characters/
│   │   ├── bosses/
│   │   ├── arena/
│   │   ├── weapons/
│   │   └── props/
│   ├── exported/
│   │   ├── characters/
│   │   ├── bosses/
│   │   ├── arena/
│   │   └── animations/
│   ├── textures/
│   ├── materials/
│   └── audio/
├── tools/
│   ├── blender/
│   ├── validation/
│   └── asset_pipeline/
└── tests/
    ├── combat/
    ├── bosses/
    ├── progression/
    └── smoke/
```

## 22. Data-Driven Design

Use Godot Resources for reusable game data:

-   AttackData.
-   BossData.
-   BossAttackData.
-   GearData.
-   GearSetData.
-   MagicAbilityData.
-   ProgressionData.

Scenes should define composition. Resources should define tunable
values.

This makes it possible to add a new boss or attack without rewriting
core systems.

## 23. Performance

Target 60 FPS on the intended low/mid-range development hardware.

Use:

-   Stylized low-poly meshes.
-   Controlled texture sizes.
-   Reusable materials.
-   Limited dynamic lights.
-   Simple collision geometry.
-   Animation reuse.
-   Object pooling for repeated effects where useful.
-   LOD only where it provides measurable value.

## 24. Debugging and QA

A debug overlay should expose:

-   FPS.
-   Player state.
-   Boss state.
-   Attack name.
-   Current combo step.
-   Block timer.
-   Dodge timer.
-   Stagger timer.
-   Distance to boss.
-   Current HP.
-   Hitbox/hurtbox visualization.

Combat should have deterministic enough timing to reproduce bugs.

## 25. Save Strategy

MVP save data can be local and minimal:

-   XP.
-   Level.
-   Basic stats.
-   Later: unlocked gear, spells, finishers, bosses, and modes.

No account or backend is required.

## 26. Definition of Done

A feature is complete when:

-   It works through the normal controller flow.
-   It has no known soft-lock.
-   It survives a scene restart.
-   It is represented in the correct data/scene layer.
-   Debug output can verify important timing.
-   It does not break earlier functionality.
-   It meets the sprint verification checklist.

## 27. Design Guardrails

Do not expand content to compensate for weak combat.

If the game does not feel good by the combat-tuning milestone, stop
adding bosses, gear, magic, or modes and fix:

-   Movement.
-   Timing.
-   Hit feedback.
-   Block.
-   Dodge.
-   Telegraphs.
-   Stagger.
-   Camera.
-   Animation responsiveness.

The MVP must prove that the basic arena fight is fun before the project
earns additional systems.
