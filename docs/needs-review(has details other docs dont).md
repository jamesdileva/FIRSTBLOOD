## 1. Project Summary

**Working title:** Boss Arena Gladiator

A controller-first, stylized 3D mythological boss-rush game built around a very small control scheme, readable telegraphed attacks, fast/springy player movement, generous-but-limited blocking, dodge mobility, combo chains, finishers, and build experimentation.

The player begins as an unequipped gladiator with a dull sword and little/no armor. The game takes place primarily in a Colosseum. The initial MVP proves the combat loop against one human gladiator boss. Post-MVP content expands the same foundation into mythological bosses, weapons, armor, magic, mobility abilities, set bonuses, chained finishers, and harder modes.

The core design principle is:

> **Keep the controls small; make the interactions and build possibilities large.**

---

## 2. Product Pillars

1. **Boss-first combat**
   - The boss is the content.
   - Bosses should have distinct rules, attacks, phases, and personalities rather than simply larger health pools.

2. **Readable difficulty**
   - Dangerous attacks are telegraphed.
   - The player should usually understand why they were hit.

3. **Fast, springy movement**
   - Walking/running is functional.
   - Dodge/roll/dash is substantially faster and doubles as repositioning.
   - Attacks should feel responsive even when animations are visually exaggerated.

4. **Small control surface**
   - Light attack.
   - Heavy/alternate attack where useful.
   - Block.
   - Dodge.
   - Four equipped magic abilities post-MVP.
   - Additional depth comes from progression and interactions, not a huge action bar.

5. **Automatic spectacle**
   - Combo chains naturally lead into finishers.
   - Players should not need a dedicated finisher button for the basic system.
   - Multiple equipped finishers can chain post-MVP.

6. **Build experimentation**
   - Gear affects stats and behavior.
   - Set bonuses can radically change play style.
   - Magic loadouts specialize the player for particular fights.

7. **Low-cost stylized 3D**
   - Target stylized low-poly/cartoon 3D rather than realism.
   - One main arena dramatically reduces environment scope.
   - AI-assisted Blender production is allowed and encouraged, but every asset must pass gameplay/readability review.

---

## 3. MVP Definition

### MVP codename: First Blood

The MVP is intentionally small.

### Included

- One Colosseum arena.
- One player gladiator.
- One boss: New Gladiator.
- Controller support.
- Third-person camera.
- Movement.
- Fast dodge/roll.
- Light attack chain.
- Basic automatic finisher.
- Block with active window and recovery.
- Boss telegraphs.
- Boss attacks.
- Damage, hit, stagger, recovery, and death states.
- Basic player/boss health.
- Basic XP.
- XP on defeat/failure.
- A small number of level/stat upgrades.
- Basic HUD.
- Restart/retry flow.
- Basic stylized 3D art.

### Explicitly excluded from MVP

- Mythological bosses.
- Boss selection.
- Magic.
- Four-spell loadouts.
- Complex gear inventory.
- Gear sets.
- Chained finishers.
- Large weapon catalog.
- Mobility skill tree.
- Proud/Critical mode.
- Wave survival.
- Dungeon mode.
- Online multiplayer.
- Procedural world generation.
- Story campaign.

The MVP is complete when the one-boss loop is fun and repeatable, not merely when every planned subsystem exists.

---

## 4. Post-MVP Vision

### Boss roster

Initial catalog:

1. New Gladiator — MVP/tutorial boss.
2. Minotaur — charges, heavy attacks, shockwaves, positioning.
3. Medusa — petrification, ranged attacks, reflection opportunities.
4. Giant Spider — web zones, poison, mobility, summons.
5. Giant Crab — armor, sweeping claws, short stagger windows.
6. Mutated Lion — aggressive pursuit, pounces, bleed/enrage.
7. Hydra — multiple heads, regeneration, target management.
8. Hades — resurrection, summons, phase changes.
9. Zeus — lightning, arena-wide attacks, ranged pressure.

Additional boss concepts should be added to a catalog rather than immediately entering the roadmap.

### Boss design rule

A boss should primarily introduce a **new combat question**:

| Boss | Main combat question |
|---|---|
| New Gladiator | Can the player use the fundamentals? |
| Minotaur | Can the player manage positioning and charges? |
| Medusa | Can the player react to and exploit ranged/petrification attacks? |
| Spider | Can the player stay mobile through hazards and summons? |
| Crab | Can the player identify armored openings? |
| Lion | Can the player survive relentless pressure? |
| Hydra | Can the player manage multiple vulnerable targets? |
| Hades | Can the player adapt across phases/resurrection? |
| Zeus | Can the player read large arena-wide telegraphs? |

These are design intents, not difficulty rankings.

---

## 5. Combat Architecture

### Player actions

Core:

- Move.
- Light attack.
- Heavy/alternate attack where implemented.
- Block.
- Dodge.

Post-MVP:

- Four equipped magic abilities.
- Mobility abilities.
- Additional finishers.
- Weapon-specific attack transformations.

### Controller mapping concept

Core controller:

- Left stick: movement.
- Right stick: camera.
- Face button: light attack.
- Secondary face/shoulder input: heavy/alternate attack if required.
- Trigger/shoulder: block.
- Secondary trigger/shoulder: dodge.
- Start/menu: pause.

Magic post-MVP:

- Hold LB.
- A/B/X/Y select Magic 1/2/3/4.

Only four spells are equipped at a time, even if the overall game eventually has many spells.

---

## 6. Attack and Combo Model

The basic attack chain is intentionally simple.

Example:

`Light -> Light -> Light -> Finisher`

or

`Light -> Light -> Light -> Light -> Finisher`

The exact chain length should be tuned through prototype testing.

### Combo principles

- Input buffering should be forgiving.
- The player should be able to string attacks naturally.
- Each attack has startup, active/hit, recovery, and cancel rules.
- The combo should feel fast even if the animation itself is visually readable.
- Completing the base chain automatically triggers a finisher.

### Post-MVP finisher system

Players can unlock/equip multiple finishers.

Example:

`Combo -> Finisher A -> Finisher B -> Finisher C`

The chain must eventually terminate.

After the player's finisher sequence, the boss exits stagger and returns to combat. This prevents permanent stun-locking.

A later skill/level unlock may introduce additional finisher behavior, but the control scheme should remain compact.

---

## 7. Defense Model

### Block

Block is an animated action rather than a permanent toggle.

Conceptual states:

`Block Startup -> Active Block -> Block Recovery`

Initial tuning target:

- Active block: approximately 2–3 seconds.
- Recovery: approximately 0.75–1.0 seconds.

These are starting values, not final values.

### Required behavior

- Holding block cannot provide indefinite safety.
- Releasing/restarting block cannot bypass recovery.
- During recovery, the player is vulnerable.
- Normal boss attacks can be fully blocked.
- Large telegraphed attacks may be reduced rather than completely negated.
- Specific boss attacks may bypass, break, or interact differently with block.
- Perfect timing may be added later if it improves the system without making normal block too difficult.

### Design target

Block should feel generous.

The player should think:

> "I could have blocked that."

not:

> "The game gave me a two-frame parry and killed me."

---

## 8. Dodge Model

Dodge is effectively unlimited but constrained by animation/recovery.

Concept:

`Dodge -> Dodge Recovery -> Dodge`

Rules:

- Dodge is faster than normal movement.
- The player can chain another dodge only after the previous dodge reaches the appropriate state.
- The recovery/finish portion leaves the player vulnerable.
- Dodge distance and recovery can be modified by gear/abilities later.
- Invulnerability duration should be tuned separately from travel duration.

The dodge is both:
- defensive tool
- mobility tool

---

## 9. Hit, Stagger, and Boss Breakout

### Attack categories

1. **Normal boss attack**
   - Usually readable.
   - Block can fully mitigate it.
   - Successful block may create a stagger opportunity.

2. **Telegraphed heavy attack**
   - Stronger.
   - Player may dodge.
   - Block may reduce damage rather than fully negate it.
   - Exact interaction is boss-specific.

3. **Special/boss-rule attack**
   - Custom behavior.
   - May require dodge, reflection, positioning, or another mechanic.

### Player attack against boss

A successful hit may put the boss into stagger.

During stagger:

`Hit -> Combo -> Finisher`

After the finisher sequence:

`Boss Breakout -> Recovery/Counter`

The boss can then:
- block,
- attack,
- reposition,
- enter another phase,
- use a desperation action.

### Boss-specific stagger

Bosses can have different:
- stagger duration,
- stagger resistance,
- stagger thresholds,
- escape behavior,
- counter behavior.

This is more important than simply giving bosses increasing HP.

---

## 10. Boss State Machine

Suggested high-level states:

- Idle.
- Search.
- Approach.
- Attack selection.
- Telegraph.
- Attack execution.
- Recovery.
- Hit.
- Stagger.
- Finisher reaction.
- Breakout.
- Enrage.
- Phase transition.
- Death.

Each boss should compose these states rather than requiring a completely separate AI architecture.

Boss-specific data should define:
- attacks,
- telegraph duration,
- damage,
- range,
- cooldown,
- stagger behavior,
- phase rules,
- special mechanics.

---

## 11. Progression

### MVP progression

Keep progression small:

- XP.
- Level.
- HP.
- Attack.
- Movement speed.
- Attack speed.

Failure still grants XP.

The purpose is to make attempts productive without allowing grinding to replace learning the boss.

### Post-MVP gear

Equipment can affect:
- HP.
- Armor.
- Attack.
- Attack speed.
- Movement speed.
- Mana.
- Magic effectiveness.
- Elemental behavior.
- Dodge behavior.
- Stagger behavior.

### Example sets

**Flame Set**
- Fire abilities gain larger AOE.
- Higher fire damage.
- Full set can create explosive fire interactions.

**Gladiator Set**
- Higher movement speed.
- Higher attack speed.
- Faster combo behavior.
- Finisher produces an explosive effect.
- Intended visual fantasy: highly mobile gladiator/ninja.

Set bonuses should alter play style, not merely provide larger numbers.

---

## 12. Magic

Post-MVP only.

The player may own many spells but equips four.

Controller:

`Hold LB + A/B/X/Y`

Example spell categories:
- Heal.
- Reflect.
- Fire.
- Freeze.

Potential future spells:
- Lightning.
- Petrify.
- Dash.
- Shield.
- AOE.
- Summon.
- Gravity.
- Shadow.

### Mana

- Maximum mana.
- Spell cost.
- Regeneration delay.
- Regeneration rate.

Mana regenerates automatically after combat activity according to tunable values.

---

## 13. Mobility Abilities

Post-MVP.

Potential abilities:
- Extended dash.
- Double dash.
- Air dash.
- Wall jump.
- Grapple.
- Blink.
- Temporary flight.

Mobility abilities should preserve the game's springy movement identity rather than becoming a second large ability bar.

---

## 14. Difficulty Modes

### Normal

Core intended experience.

- Generous telegraphs.
- Reasonable boss damage.
- Accessible block windows.
- Intended for learning bosses.

### Critical/Proud

Post-MVP.

Rather than simply increasing HP, it can use:
- Faster attacks.
- More aggressive AI.
- Shorter telegraphs.
- Additional attack variants.
- Enrage changes.
- Boss modifiers.
- Halo/skull-style modifiers.
- Reduced recovery opportunities.

This mode is a mastery layer, not part of the initial development target.

---

## 15. Alternative Modes

Deferred and not guaranteed.

### Boss Rush
Strong fit with the core identity.

### Endless Arena Survival
Potential leveling/challenge mode.

### Wave Survival
Fight groups instead of a single boss.

### Dungeon Expedition
Potentially much larger scope.

Decision rule:

> Do not build alternate modes until the boss-rush loop is already proven.

Boss Rush is the first alternate mode worth investigating because it reinforces the central fantasy rather than replacing it.

---

## 16. Art Direction

Target:

**Stylized low-poly/cartoon 3D.**

Not:
- photorealistic,
- AAA-quality,
- voxel-first,
- 2D pixel art unless prototyping shows a strong advantage.

Priorities:

1. Silhouette.
2. Animation readability.
3. Attack telegraphs.
4. Hit feedback.
5. Boss scale.
6. Color/value separation.
7. Arena readability.
8. Detail.

The Colosseum is the main environment and should be reusable across bosses through lighting, props, effects, and localized dressing.

---

## 17. AI-Assisted Art Pipeline

AI agents can be used as production assistants, but they should not be treated as a magic one-click AAA asset generator.

Pipeline:

`Concept -> Agent-assisted specification -> Blender generation/editing -> Rig/animation -> glTF -> Godot import -> Gameplay test -> Revision`

Useful agent tasks:
- Generate concept prompts and references.
- Draft Blender Python scripts.
- Create primitive/blockout geometry.
- Generate repeated props.
- Set up materials.
- Create or modify procedural geometry.
- Assist with rig/animation setup.
- Generate asset metadata.
- Inspect exported assets.
- Create Godot import/configuration files.
- Produce variations.

Blender has an embedded Python API suitable for procedural modeling, animation, import/export, and automation. Godot's 3D pipeline supports glTF and imported animation libraries, making Blender -> glTF/GLB -> Godot a practical pipeline.

Human/agent review remains required for:
- gameplay readability,
- collision,
- hitboxes,
- animation timing,
- boss silhouette,
- performance,
- asset consistency.

---

## 18. Recommended Technical Stack

### Engine
Godot 4.7.x stable branch at project start, unless a newer stable release is explicitly validated before initialization.

Godot 4.7.2 is the current stable release at the time of this architecture document.

### 3D
- Blender 5.x/current stable.
- glTF/GLB interchange.
- Low-poly meshes.
- Simple materials.
- Rigged animations.

### Language
**GDScript** initially.

Reason:
- Fast iteration.
- Native Godot workflow.
- Easy for an AI coding agent to inspect and modify.
- Avoid unnecessary C#/.NET complexity for MVP.

### Version control
Git.

### Asset organization
Separate source assets from imported/runtime assets.

### AI
External/local coding/design agents are optional production accelerators, not runtime dependencies.

---

## 19. Proposed Repository Structure

```text
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
20. Data-Driven Design

Combat content should use Resources/data assets wherever practical.

Examples:

AttackData
- damage
- startup
- active_time
- recovery
- range
- knockback
- stagger_value
- telegraph_duration
- block_behavior
- animation
- effects
BossAttackData
- attack_id
- weight
- range
- cooldown
- telegraph
- damage
- phase_requirement
- preferred_distance
- followup
GearSetData
- set_id
- pieces
- stat_modifiers
- set_bonuses
- visual_variant

This lets content expand without rewriting the combat engine.

21. Performance Strategy

Target performant stylized 3D rather than maximum fidelity.

Priorities:

Simple materials.
Controlled texture sizes.
Reusable meshes.
Limited dynamic lights.
LOD where useful.
Avoid unnecessary physics.
Animation reuse.
Simple collision.
Object pooling for repeated effects/projectiles.
Avoid expensive per-frame scans.

The Colosseum should be designed to run well on midrange hardware.

22. Save/Progression Strategy

MVP can use a simple local save.

Store:

player level,
XP,
unlocked upgrades,
defeated boss flags when boss selection exists,
equipment unlocks post-MVP,
settings.

No account system.

No server.

No online dependency.

23. Testing Strategy

Every sprint should have a playable verification target.

Testing categories:

Input.
Movement.
Timing.
Hit detection.
Block behavior.
Dodge behavior.
Boss AI.
State transitions.
Progression.
UI.
Performance.
Controller.
Save/load.
Asset import.

For combat, manual playtesting is mandatory because automated tests cannot determine whether the combat actually feels good.

Automated tests should validate rules; human testing validates feel.

24. Definition of Done

A feature is not done merely because it works once.

A feature is done when:

implemented,
tested,
controller-tested if applicable,
no obvious regressions,
timing values are data-driven,
debug output is clean,
the feature works after restarting the game,
documentation/tuning notes are updated.

For bosses:

every attack has a readable telegraph,
hitboxes are intentional,
recovery exists,
stagger rules are intentional,
death works,
retry works,
no soft lock is known.
25. Design Guardrails

Avoid:

huge ability bars,
MMO-style stats,
inventory clutter,
mandatory grinding,
dozens of currencies,
procedural generation for its own sake,
multiple environments during MVP,
multiplayer,
realistic art requirements,
excessive cinematics,
boss HP inflation as the main source of difficulty.

Prefer:

few inputs,
meaningful timing,
dramatic animation,
boss-specific rules,
reusable arena,
data-driven content,
stylized assets,
fast iteration.
"""

roadmap = r"""# Boss Arena Gladiator — Sprint Roadmap

Roadmap Philosophy

This roadmap deliberately proves the game in layers.

The project should not start by creating ten bosses, armor sets, magic, menus, or a giant inventory.

The first question is:

Is moving, attacking, blocking, dodging, and fighting one readable enemy in the Colosseum fun?

Everything else is downstream of that answer.

Phase 0 — Preproduction
Sprint 00 — Project Definition
Goal

Freeze the MVP and establish the repository.

Tasks
Create Git repository.
Create Godot project.
Create docs directory.
Create initial project README.
Record MVP boundary.
Record post-MVP boss catalog.
Record combat principles.
Decide initial resolution/aspect behavior.
Establish controller-first input philosophy.
Establish naming conventions.
Establish debug-build convention.
Deliverables
Launchable blank Godot project.
Architecture documents.
Initial folder structure.
Git history with clean baseline.
Verification
Project opens in Godot.
Project runs.
Git status is clean after initial commit.
Documentation is present.
No post-MVP feature accidentally appears in MVP scope.
End Goal

A stable starting point that an AI coding agent can inspect without ambiguity.

Sprint 01 — Visual/Technical Spike
Goal

Validate the 3D pipeline before serious combat work.

Tasks
Install/validate Godot stable.
Install/validate Blender.
Create a primitive gladiator.
Create a primitive boss.
Create a primitive Colosseum blockout.
Export GLB from Blender.
Import into Godot.
Test one skeletal animation.
Test one attack animation.
Test camera framing.
Test basic lighting.
Record import conventions.
Verification
Blender asset exports successfully.
Godot imports the asset without broken transforms.
Animation plays.
Character can be instantiated as a scene.
Arena runs at target resolution.
Controller can be detected.
End Goal

A proven Blender -> GLB -> Godot loop.

Phase 1 — Movement Prototype
Sprint 02 — Player Controller
Goal

Make the gladiator feel good before adding combat.

Tasks
CharacterBody3D player.
Gravity.
Ground movement.
Acceleration.
Deceleration.
Rotation toward movement.
Camera-relative movement.
Camera follow.
Controller mapping.
Basic run speed.
Basic animation placeholders.
Tuning variables
movement_speed
acceleration
deceleration
turn_speed
gravity
camera_distance
camera_height
Verification
Controller moves player.
Player does not drift after input release.
Camera behaves consistently.
Player cannot leave arena bounds.
Movement feels responsive.
End Goal

Walking/running around the Colosseum already feels responsive.

Sprint 03 — Dodge/Roll
Goal

Create the fast/springy mobility foundation.

Tasks
Dodge action.
Direction selection.
Dodge distance.
Dodge speed.
Invulnerability window.
Dodge animation.
Dodge recovery.
Prevent infinite same-frame chaining.
Debug display for dodge states.
Initial design

Dodge -> travel -> finish/recovery

Verification
Dodge is faster than walking.
Dodge moves in intended direction.
Repeated input cannot bypass the recovery rule.
Player is vulnerable during recovery.
Dodge does not cause tunneling through arena boundaries.
Controller behavior is reliable.
End Goal

Player can rapidly reposition without becoming permanently invulnerable.

Phase 2 — Combat Foundation
Sprint 04 — Hitbox/Hurtbox Framework
Goal

Create reusable combat collision infrastructure.

Tasks
Hurtbox component.
Hitbox component.
Damage event.
Damage receiver.
Team/faction filtering.
Debug visualization.
Hit registration event.
Basic hit effect hook.
Verification
Player can hit a test target.
Target receives exactly one intended hit.
Hitbox does not repeatedly damage unintentionally.
Player cannot damage themselves.
Debug visualization matches actual collision.
End Goal

Combat interactions are reusable rather than hard-coded into the player.

Sprint 05 — Light Attack
Goal

Implement the first real attack.

Tasks
Attack input.
Attack state.
Startup.
Active frames.
Recovery.
Animation.
Hitbox timing.
Damage.
Hit reaction.
Attack interruption rules.
Input buffering.
Verification
Attack only damages during active window.
Attack recovery creates a real commitment.
Repeated input behaves predictably.
Hit feedback occurs.
Controller input feels responsive.
End Goal

One satisfying sword strike.

Sprint 06 — Combo Chain
Goal

Turn the single strike into a basic combo.

Tasks
Attack 1.
Attack 2.
Attack 3.
Optional Attack 4.
Combo timeout.
Input buffer.
Animation transitions.
Different hit reactions.
Combo debug display.
Verification
Player can reliably produce the intended chain.
Dropping input resets combo correctly.
Late input does not create accidental attacks.
Rapid input still respects attack state.
Combo feels fast and readable.
End Goal

A basic attack chain feels natural without a complex control scheme.

Sprint 07 — Automatic Finisher
Goal

Make the combo culminate in spectacle.

Tasks
Finisher animation.
Finisher state.
Finisher damage.
Finisher timing.
Boss/player interaction placeholder.
Camera response.
Hit effect.
Sound hook.
Verification
Completing the combo automatically enters finisher.
Finisher cannot trigger early.
Finisher cannot loop forever.
Player regains control after finisher.
Animation and hitbox timing agree.
End Goal

The basic combat loop already contains a satisfying payoff.

Phase 3 — Defense
Sprint 08 — Block State
Goal

Implement the generous animated block.

Tasks
Block input.
Block startup.
Active block.
Block recovery.
Blocking animation.
Damage reduction.
Block movement restrictions.
Re-block prevention during recovery.
Debug timer.
Starting tuning
Active block target: 2–3 seconds.
Recovery target: approximately 0.75–1 second.
Verification
Block stops normal damage.
Block cannot be held indefinitely.
Recovery creates vulnerability.
Repeated block input cannot bypass recovery.
Player visually remains in the correct state.
Controller feels natural.
End Goal

Block is forgiving but not abusable.

Sprint 09 — Dodge/Block Combat Integration
Goal

Make movement and defense interact correctly.

Tasks
Dodge invulnerability.
Block priority.
Attack -> block transition rules.
Dodge -> attack transition.
Block -> attack transition.
Recovery vulnerability.
Damage event ordering.
Verification

Test all combinations:

idle -> block
block -> attack
attack -> dodge
dodge -> attack
dodge -> block
block -> dodge
recovery -> attack
recovery -> dodge
End Goal

No obvious state-transition holes.

Phase 4 — First Boss
Sprint 10 — Boss Framework
Goal

Create a reusable boss architecture before making the gladiator boss.

Tasks
Boss base scene.
Boss health.
Boss state machine.
Target acquisition.
Distance checks.
Attack selection.
Attack cooldown.
Telegraph state.
Recovery state.
Hit state.
Death state.
Verification
Boss can locate player.
Boss can enter/exit states.
Invalid transitions are rejected.
Boss cannot attack while dead.
Boss can be reset cleanly.
End Goal

A reusable boss framework exists.

Sprint 11 — Telegraph System
Goal

Make attacks readable.

Tasks
Telegraph animation.
Telegraph VFX hook.
Audio warning hook.
Attack windup.
Active attack.
Recovery.
Debug telegraph timer.
Standard telegraph data format.
Verification
Player can identify attack before impact.
Telegraph ends exactly when attack begins.
Telegraph timing is tunable.
No attack starts before its telegraph finishes.
Visual signal is obvious in the arena.
End Goal

The player learns attacks rather than guessing.

Sprint 12 — New Gladiator Boss
Goal

Create the complete MVP boss.

Boss attacks

Start with only 2–3:

Normal sword strike.
Heavy telegraphed strike.
Simple approach/pressure attack.
Tasks
Boss model.
Basic animations.
Attack data.
AI.
Distance behavior.
Attack cooldowns.
Telegraphs.
Hit reactions.
Death.
Verification
Boss can fight indefinitely without breaking.
Boss does not stand motionless.
Boss does not spam one attack uncontrollably.
Player can identify attacks.
Player can block/dodge attacks.
Boss can be defeated.
Boss can defeat player.
End Goal

A complete fight exists.

Phase 5 — Stagger and Boss Breakout
Sprint 13 — Boss Stagger
Goal

Connect player combos to boss reactions.

Tasks
Stagger value.
Stagger state.
Stagger duration.
Hit reaction.
Combo vulnerability.
Finisher vulnerability.
Verification
Player hit can trigger stagger.
Boss remains vulnerable during intended window.
Boss does not randomly leave stagger.
Boss can recover.
Stagger is visible and readable.
End Goal

Player can earn a combo opportunity.

Sprint 14 — Boss Breakout
Goal

Prevent infinite stun-locking.

Tasks
Finisher completion.
Breakout state.
Boss recovery.
Boss block/attack choice.
Optional counterattack.
Verification
One finisher sequence ends.
Boss reliably exits stagger.
Boss can retaliate.
Player cannot permanently lock boss.
Repeated combos still feel rewarding.
End Goal

The fight has a complete offensive rhythm.

Phase 6 — Combat Feel
Sprint 15 — Hit Feedback
Tasks
Hit pause/hitstop.
Camera shake.
Impact VFX.
Damage numbers only if useful.
Sound effects.
Controller vibration if supported.
Heavy attack feedback.
Finisher feedback.
Verification
Light hit and heavy hit feel distinct.
Block feels impactful.
Finisher feels substantially stronger.
Effects do not obscure telegraphs.
Camera shake does not cause motion sickness.
End Goal

The combat feels materially better without adding mechanics.

Sprint 16 — Combat Tuning Lab
Goal

Tune feel rather than add content.

Test variables
movement speed
dodge distance
dodge invulnerability
dodge recovery
block duration
block recovery
attack startup
attack recovery
combo timing
finisher timing
boss telegraph duration
boss recovery
stagger duration
Process

Create a developer tuning panel or resource values that can be changed rapidly.

Verification
Major timing values can be adjusted without rewriting scripts.
Test sessions can compare multiple values.
No hard-coded duplicate values remain.
End Goal

Combat tuning becomes cheap.

Phase 7 — Arena and MVP Art
Sprint 17 — Colosseum Blockout
Tasks
Arena floor.
Outer walls.
Gates.
Stands.
Basic props.
Spawn points.
Camera boundaries.
Combat-safe space.
Verification
Player cannot escape.
Boss cannot become trapped.
Camera keeps both combatants readable.
Arena is large enough for dodging.
No geometry interferes with combat unintentionally.
End Goal

The arena supports the combat rather than merely surrounding it.

Sprint 18 — Stylized Art Pass
Tasks
Replace blockout player.
Replace boss.
Arena material pass.
Simple lighting.
Simple sky.
Simple crowd/stand dressing.
Basic weapon.
AI-assisted workflow
Agent proposes visual specifications.
Agent may draft Blender Python.
Blender generates/edit assets.
Human reviews silhouette.
Export GLB.
Godot import.
Gameplay review.
Verification
Assets remain readable at gameplay distance.
Boss silhouette is clear.
Player silhouette is clear.
Attacks remain visible.
Performance remains acceptable.
End Goal

The game looks like a coherent stylized game rather than a prototype.

Phase 8 — Progression
Sprint 19 — XP
Tasks
XP resource.
XP from damage/death.
XP from boss defeat.
Level thresholds.
Level event.
Verification
XP persists through death.
XP cannot become negative.
Level-up occurs at intended threshold.
Retry does not duplicate XP incorrectly.
End Goal

Failure still produces meaningful progression.

Sprint 20 — Basic Level-Up
Initial stats
HP.
Attack.
Movement speed.
Attack speed.
Tasks
Level-up screen.
Stat choices or predefined progression.
Apply modifiers.
Save values.
Verification
Level-up changes actual gameplay.
Stat changes do not break animation timing.
Movement remains within reasonable bounds.
Attack speed cannot bypass state logic.
End Goal

The player can become stronger without needing equipment.

Phase 9 — MVP UX
Sprint 21 — HUD
Tasks
Player HP.
Boss HP.
XP/level.
Pause indicator.
Optional combo indicator.
Optional block/recovery debug toggle.
Verification
HUD remains readable.
Boss health updates correctly.
Player health updates correctly.
No debug values ship in normal mode.
Sprint 22 — Menus and Retry
Tasks
Title.
Start.
Restart.
Pause.
Resume.
Quit.
Defeat screen.
Victory screen.
Verification
Every path works with controller.
Restart fully resets fight.
Pause actually pauses combat.
No state persists accidentally after restart.
Phase 10 — MVP Validation
Sprint 23 — Full MVP Playthrough
Goal

Treat the game as a player would.

Test loop

Launch -> Enter Arena -> Fight -> Die -> Gain XP -> Retry -> Level -> Fight -> Win

Verification checklist
No soft locks.
No combat state dead ends.
No controller-only blockers.
No boss AI dead ends.
No camera disasters.
No impossible-to-read attacks.
XP works.
Restart works.
Victory works.
End Goal

First complete playable MVP.

Sprint 24 — External Playtest
Goal

Test whether the core idea works without developer guidance.

Questions
Do players understand block?
Do they understand dodge?
Can they read the boss?
Does the combo feel good?
Does the finisher feel rewarding?
Is the boss too easy/hard?
Is the arena too large/small?
Does failure feel productive?
Would they voluntarily fight the boss again?
Critical rule

Do not add content to solve a combat-feel problem.

Fix the combat first.

End Goal

A validated MVP.

Phase 11 — Post-MVP Foundation

Only begin after MVP validation.

Sprint 25 — Boss Selection
Tasks
Boss roster screen.
Boss availability.
Boss descriptions.
Boss preview.
Fight button.
Return to Colosseum.
Verification
Multiple bosses can load.
Player state resets correctly.
Boss-specific rules do not leak between fights.
Sprint 26 — Gear Framework
Tasks
Equipment slots.
Item data.
HP.
Armor.
Attack.
Movement.
Attack speed.
Visual equipment swapping.
Verification
Equipment changes stats.
Equipment survives save/load.
Visual model matches equipped item.
No invalid combinations crash the game.
Sprint 27 — Weapon Variants
Tasks
Larger sword.
Knight sword.
Golden sword.
Weapon-specific modifiers.
Attack animation variants where needed.
Verification
Weapon changes feel different.
Hitboxes remain correct.
Weapon visuals match collision.
Existing boss remains beatable.
Phase 12 — Magic
Sprint 28 — Mana Framework
Tasks
Mana.
Cost.
Regeneration delay.
Regeneration rate.
HUD.
Verification
Spell cannot cast without sufficient mana.
Mana regenerates correctly.
Regeneration cannot exceed maximum.
Death/restart resets appropriately.
Sprint 29 — Four-Slot Magic Input
Tasks
Hold LB.
A/B/X/Y selection.
Four equipped slots.
Input conflict handling.
Controller prompts.
Verification
All four spells can be triggered.
Holding/releasing LB behaves consistently.
No accidental basic attack triggers.
Rebinding remains possible later.
Sprint 30 — Initial Magic Set

Implement:

Heal.
Reflect.
Fire.
Freeze.
Verification

Each spell:

has clear feedback,
respects mana,
has cooldown/state rules if needed,
interacts with boss correctly,
can be disabled for bosses that should not support the interaction.
Phase 13 — More Bosses
Sprint 31 — Minotaur
Mechanics
Charge.
Heavy strike.
Shockwave.
Positioning pressure.
Verification
Attacks have readable telegraphs.
Charge cannot trap player unfairly.
Shockwave has a readable safe response.
Stagger behavior is distinct from Gladiator.
Sprint 32 — Medusa
Mechanics
Petrification.
Ranged attack.
Reflection interaction.
Verification
Petrification is clearly telegraphed.
Player understands how to avoid it.
Reflect interaction works.
Boss cannot accidentally petrify through unintended geometry.
Sprint 33 — Spider
Mechanics
Web.
Poison.
Jump/pounce.
Optional small summons.
Verification
Arena remains readable.
Webs don't cover the entire play space too quickly.
Summons don't overwhelm MVP combat rules.
Sprint 34 — Crab
Mechanics
Armor.
Sweeping claw.
Short stagger.
Vulnerable opening.
Verification
Armor state is visually obvious.
Player can learn the opening.
Boss doesn't become tedious.
Sprint 35 — Mutated Lion
Mechanics
Pounce.
Chase.
Bleed.
Enrage.
Verification
Aggression feels different from Minotaur.
Player has counterplay.
Enrage changes behavior rather than merely adding HP.
Phase 14 — Build System
Sprint 36 — Set Framework
Tasks
Set IDs.
Piece counts.
Set bonuses.
Visual sets.
Modifier stacking rules.
Verification
2-piece and 4-piece bonuses activate correctly.
Removing an item removes the bonus.
Save/load preserves the build.
Sprint 37 — Flame Set
Goal

Create the first highly specialized build.

Effects
Fire AOE.
Fire damage.
Explosive interactions.
Verification
Fire build is visibly and mechanically different.
Effects remain performant.
Bosses still have counterplay.
Sprint 38 — Gladiator Set
Effects
Movement speed.
Attack speed.
Combo speed.
Finisher explosion.
Visual identity.
Verification
Build feels dramatically faster.
Animation state logic remains stable.
Dodge cannot bypass intended recovery.
Phase 15 — Advanced Combat
Sprint 39 — Multiple Finishers
Tasks
Finisher inventory.
Equip system.
Finisher selection.
Chaining.
Chain termination.
Boss breakout after sequence.
Verification
Multiple finishers can chain.
No infinite chain.
Boss always exits stagger.
Different finishers have distinct gameplay effects.
Sprint 40 — Mobility Abilities

Implement initial candidates:

Extended dash.
Double dash.
Air dash.
Verification
Abilities do not invalidate arena geometry.
Recovery rules remain meaningful.
Boss attacks remain readable.
Phase 16 — Advanced Bosses
Sprint 41 — Hydra
Mechanics
Multiple heads.
Regrowth.
Target selection.
Multi-hit interactions.
Verification
Head state is clear.
Regrowth is understandable.
Fight remains performant.
Sprint 42 — Hades
Mechanics
Resurrection.
Summons.
Phase transition.
Arena changes.
Verification
Death/resurrection state is deterministic.
Phase transition cannot soft-lock.
Arena changes preserve combat boundaries.
Sprint 43 — Zeus
Mechanics
Lightning.
Arena-wide telegraphs.
Ranged pressure.
Enrage.
Verification
Safe areas are readable.
Lightning does not become visual noise.
Player can use block/reflect where intended.
Phase 17 — Difficulty
Sprint 44 — Critical/Proud Mode
Tasks
Difficulty modifier framework.
Boss multipliers.
Speed modifiers.
Telegraph modifiers.
Additional attacks.
Enrage changes.
Halo/skull modifiers.
Verification
Normal mode remains unchanged.
Critical mode feels different rather than merely longer.
Modifiers stack predictably.
No modifier makes a boss impossible without counterplay.
Phase 18 — Optional Modes
Sprint 45 — Boss Rush Prototype
Tasks
Sequential boss fights.
Healing/progression rules.
Boss order.
End reward.
Verification
Mode reinforces core gameplay.
Run length is manageable.
Boss transitions are stable.
Sprint 46 — Endless Survival Experiment
Goal

Determine whether wave survival adds value.

Decision gate

If the mode feels like a different game rather than an extension of the boss arena, shelve it.

Sprint 47 — Dungeon Experiment
Goal

Prototype only if there is a compelling reason.

Decision gate

Do not proceed unless:

boss arena core is mature,
additional content is justified,
the mode strengthens rather than dilutes the game's identity.
Phase 19 — Production Hardening
Sprint 48 — Asset Pipeline Automation
Tasks
Blender export conventions.
Naming checks.
Animation checks.
GLB validation.
Godot import validation.
Asset manifest.
Optional AI-agent asset report.
Verification

A newly created boss asset can be validated through the same pipeline as existing assets.

Sprint 49 — Performance Pass
Tasks
Frame-time profiling.
Physics profiling.
Draw-call review.
VFX review.
Animation review.
Memory review.
Verification
Target hardware maintains acceptable frame rate.
No boss creates unacceptable spikes.
Arena remains performant during maximum VFX.
Sprint 50 — Controller QA
Tasks

Test:

Xbox-style controller.
Generic XInput controller if available.
Keyboard fallback.
Disconnect/reconnect.
Menu navigation.
Magic modifier.
Dodge.
Block.
Combo.
Verification

Entire game can be completed without keyboard/mouse.

Sprint 51 — Final Combat Polish
Tasks
Attack timing.
Block timing.
Dodge timing.
Camera.
Hitstop.
Sound.
VFX.
Finishers.
Boss telegraphs.
Verification

Playtesters can describe:

what they did wrong,
what the boss did,
what they should try next.

If players instead say "I don't know what happened," improve readability.

Long-Term Boss Catalog

These are intentionally documented but not promised for implementation.

Medusa
Petrification.
Ranged attacks.
Reflection.
Statue/environment interaction.
Minotaur
Charge.
Axe.
Shockwave.
Rage.
Giant Spider
Web.
Poison.
Pounce.
Adds.
Giant Crab
Armor.
Claws.
Sweep.
Burrow/popup possibility.
Mutated Lion
Pounce.
Chase.
Bleed.
Enrage.
Hydra
Multiple heads.
Regrowth.
Area denial.
Hades
Resurrection.
Summoning.
Underworld.
Multiple lives/phases.
Zeus
Lightning.
Arena-wide attacks.
Flying/ranged phase.
Enrage.
Future ideas bucket

Potential future mythological creatures:

Cerberus.
Cyclops.
Siren.
Kraken-like arena beast.
Chimera.
Talos.
Giant scorpion.
Gorgon variants.
Colossal undead champion.

These remain ideas until individually designed.

Global Verification Gates

A phase should not advance solely because its checklist is complete.

Gate A — Combat Fun

Can a tester voluntarily play several fights without being asked?

Gate B — Readability

Can the player identify why they were hit?

Gate C — Responsiveness

Do movement, attacks, block, and dodge respond predictably?

Gate D — Boss Identity

Does a new boss play differently because of mechanics rather than HP?

Gate E — Build Identity

Does gear change play style rather than only increase numbers?

Gate F — Scope

Is the feature strengthening the boss-rush game or creating a second game?

Gate G — Performance

Does added spectacle preserve acceptable frame time?

MVP Exit Criteria

MVP is complete only when all are true:

One complete Colosseum.
One complete playable Gladiator boss.
Controller-first gameplay.
Movement feels responsive.
Dodge is useful and constrained.
Block is generous but cannot be held forever.
Light combo works.
Automatic finisher works.
Boss telegraphs are readable.
Boss can stagger.
Boss can break out.
Player can die.
Player can win.
Failure grants XP.
Leveling works.
Restart works.
Pause works.
No known soft-lock in normal play.
External tester can understand the basic combat without developer explanation.

The most important criterion:

The MVP is fun before post-MVP systems are added.
"""

implementation = r"""# Boss Arena Gladiator — Implementation Guide

1. Implementation Principles
Principle 1 — One system at a time

Implement and verify one feature before layering the next.

Principle 2 — Preserve working behavior

When modifying a player, boss, or combat script:

preserve existing controls,
preserve existing states,
preserve existing signals,
avoid replacing whole files unnecessarily.
Principle 3 — Data before hard-coding

Combat values should migrate into Resources/data objects once their behavior is proven.

Principle 4 — Prototype with primitives

A capsule gladiator and colored shapes are acceptable until combat is fun.

Principle 5 — Animation timing is gameplay

Never treat animations as decoration. Attack startup, active windows, recovery, block recovery, dodge recovery, and boss telegraphs are gameplay values.

2. Initial Godot Project

Recommended engine:

Godot 4.7.x stable branch.
GDScript.
Forward+ for normal development unless compatibility testing indicates another renderer is preferable.

Initial project settings:

3D.
Landscape.
Controller-first.
60 FPS target.
VSync configurable.
Window scaling enabled.
Input actions defined centrally.

Avoid using development/nightly Godot builds for the production project unless a specific feature requires one and has been validated.

3. Initial Input Map

Create actions similar to:

move_left
move_right
move_forward
move_back

camera_left
camera_right
camera_up
camera_down

attack_light
attack_heavy
block
dodge

magic_modifier

magic_1
magic_2
magic_3
magic_4

pause

Do not bind gameplay logic directly to physical keys/buttons.

Scripts should ask:

Input.is_action_pressed(...)
Input.is_action_just_pressed(...)

This keeps keyboard/controller mapping separate from combat logic.

4. Player Scene

Suggested scene:

Player
├── CharacterBody3D
├── CollisionShape3D
├── VisualRoot
│   ├── Model
│   └── AnimationTree
├── Hurtbox
├── Weapon
│   ├── Hitbox
│   └── WeaponVisual
├── StateMachine
├── CameraTarget
└── Audio

Potential script split:

player_controller.gd
player_state_machine.gd
player_combat.gd
player_defense.gd
player_stats.gd
player_animation.gd

Avoid putting every system into one 1000-line player script.

5. State Machine

Recommended initial player states:

IDLE
MOVE
ATTACK
FINISHER
BLOCK_START
BLOCK_ACTIVE
BLOCK_RECOVERY
DODGE
DODGE_RECOVERY
HIT
DEAD

Later:

CASTING
AIRBORNE
MOBILITY_ABILITY
SPECIAL_FINISHER

Every state should explicitly define:

entry behavior,
update behavior,
exit behavior,
allowed transitions.
6. Combat Timing

Use normalized data where possible.

Attack:

startup
active
recovery

Block:

startup
active
recovery

Dodge:

startup
travel
invulnerability
recovery

Boss telegraph:

telegraph
attack
recovery

Avoid scattering timing values through multiple scripts.

7. Hitbox Architecture

A hitbox should describe:

owner,
team,
damage,
damage type,
stagger value,
knockback,
attack ID.

A hurtbox should describe:

owner,
team,
damage receiver,
immunity rules,
current state.

Damage should be delivered through a structured event rather than direct manipulation of another object's health.

Conceptual event:

DamageEvent
- source
- target
- amount
- damage_type
- stagger
- knockback
- attack_id
- flags
8. Block Implementation

Block should not be:

if blocking:
    damage = 0

Instead:

BLOCK_START
    ↓
BLOCK_ACTIVE
    ↓
BLOCK_RECOVERY

Damage resolution:

if attack hits during BLOCK_ACTIVE:
    apply block behavior
else:
    apply normal damage

Block behavior can later vary by attack:

FULL_BLOCK
REDUCED_DAMAGE
GUARD_BREAK
REFLECT
UNBLOCKABLE

Do not implement every behavior during MVP.

MVP should primarily support:

normal attack blocked,
heavy telegraphed attack reduced,
recovery vulnerable.
9. Dodge Implementation

Dodge should be an authored movement state rather than simply multiplying movement speed.

Store:

direction,
distance,
duration,
invulnerability window,
recovery duration.

A dodge should be deterministic.

Do not rely on physics impulses alone for the primary movement unless testing proves they provide better control.

10. Combo Implementation

Recommended data:

ComboDefinition
- combo_id
- steps[]
- finisher_id
- timeout

Each step:

ComboStep
- attack_id
- animation
- buffer_open
- buffer_close
- next_step

Basic MVP behavior:

Light pressed
 -> Attack 1

Light during buffer
 -> Attack 2

Light during buffer
 -> Attack 3

Combo completed
 -> Finisher

The player should not need a separate finisher button.

11. Boss Architecture

Use composition.

Boss
├── BossBrain
├── BossStateMachine
├── BossStats
├── TargetSensor
├── AttackController
├── TelegraphController
├── Hurtbox
├── AnimationTree
└── PhaseController

Boss-specific attacks should be data-driven.

Example:

BossAttackData
- id
- animation
- telegraph_time
- range_min
- range_max
- damage
- stagger
- cooldown
- weight
- phase
- recovery
- block_behavior
12. Boss AI

Start simple.

The MVP Gladiator does not need machine learning.

Use deterministic decision logic:

if dead:
    die

elif player_far:
    approach

elif cooldown_active:
    reposition

elif player_in_attack_range:
    select_attack

else:
    approach

Attack selection can use weighted choices.

Example:

normal_attack: 60
heavy_attack: 25
pressure_attack: 15

Later bosses can override selection rules.

13. Telegraph System

Every boss attack should have a defined telegraph.

Telegraph options:

animation pose,
weapon glow,
arena marker,
sound,
particle effect,
boss vocalization.

Use multiple channels for major attacks.

A telegraph must:

begin clearly,
remain visible long enough,
end at the attack's actual activation point.

The attack should never visually land before its gameplay hit.

14. Boss Stagger

Implement stagger as a real state.

Possible data:

stagger_duration
stagger_resistance
stagger_threshold
finisher_allowed
breakout_time

MVP can use a simple threshold.

Post-MVP bosses can customize it.

15. Boss Breakout

The breakout system exists to preserve combat flow.

Concept:

STAGGER
 -> PLAYER_COMBO
 -> FINISHER
 -> BREAKOUT
 -> RECOVERY
 -> DECISION

The boss should not instantly attack on the exact frame the finisher ends.

Give it a readable recovery/counter window.

16. Animation Architecture

Use Blender for source animation and Godot AnimationTree for runtime state/blending.

Suggested animation groups:

movement/
    idle
    walk
    run
    turn

combat/
    light_1
    light_2
    light_3
    light_4
    finisher_1

defense/
    block_start
    block_loop
    block_end

movement/
    dodge
    dodge_end

reaction/
    hit_light
    hit_heavy
    stagger
    death

Do not require every animation to be perfect before integrating.

A placeholder animation with correct timing is more valuable than a beautiful animation with incorrect timing.

17. Blender Pipeline

Source:

assets/blender/

Export:

assets/exported/

Recommended asset naming:

CHR_Player_Gladiator
BOS_Gladiator
ENV_Colosseum
WPN_DullSword
ANM_Player_Light01
ANM_Boss_Heavy01

Keep Blender source files separate from exported runtime files.

Use Blender Python when automation is helpful.

Possible automated tasks:

create primitives,
build repeated arena props,
assign materials,
rename objects,
create collections,
export selected assets,
validate object names,
create simple animation scaffolding.
18. AI-Assisted Art Workflow

The agent should behave like a production assistant.

Step 1

Human defines:

Boss:
Minotaur

Gameplay:
Large melee boss
Charge
Axe swing
Shockwave
Short stagger

Visual:
Stylized low-poly
Large silhouette
Readable horns
Simple armor
Warm fantasy palette
Step 2

Agent creates:

concept specification,
asset requirements,
Blender script where useful,
animation list.
Step 3

Blender produces/editable asset.

Step 4

Human reviews:

silhouette,
proportions,
readability.
Step 5

Export GLB.

Step 6

Godot imports.

Step 7

Gameplay review.

Step 8

Agent receives specific correction:

"Horn silhouette is good but attack windup is too small. Increase shoulder/weapon anticipation and make the shockwave ground marker clearer."

This is a much more realistic and useful AI pipeline than expecting an agent to generate a complete production-ready boss from one sentence.

19. Asset Quality Gate

Every AI-assisted asset must pass:

Visual
recognizable silhouette,
no broken geometry,
acceptable proportions,
consistent style.
Animation
no obvious deformation failures,
feet/weapon behave acceptably,
attack starts/ends correctly,
recovery pose is readable.
Gameplay
hitboxes fit the model,
hurtboxes fit the model,
telegraphs remain visible,
asset does not obscure player.
Technical
imports into Godot,
no missing dependencies,
reasonable polygon/texture cost,
correct scale,
correct orientation.
20. Colosseum Scene

Keep the arena modular.

Colosseum
├── Floor
├── OuterRing
├── Walls
├── Gates
├── Stands
├── Props
├── Lighting
├── PlayerSpawn
├── BossSpawn
├── CameraBounds
└── CombatBounds

Do not create separate arenas for each boss initially.

Use:

lighting,
VFX,
props,
sky,
localized effects

to differentiate later encounters.

21. Camera

The camera should prioritize combat readability.

Goals:

keep player visible,
keep boss visible,
show telegraphs,
avoid clipping,
zoom out for large bosses,
avoid excessive camera shake.

Potential components:

CombatCamera
├── TargetResolver
├── DistanceController
├── CollisionController
├── ShakeController
└── BossScaleAdjustment

Do not implement elaborate cinematic camera logic during MVP.

22. Progression Data

Use resources such as:

PlayerStatsData
LevelData
UpgradeData

Example:

LevelData
- level
- xp_required
- hp_bonus
- attack_bonus
- move_speed_bonus
- attack_speed_bonus

This keeps balance editable without changing code.

23. Gear Data

Post-MVP:

GearData
- id
- name
- slot
- stats
- set_id
- visual
- passive_effects

Set:

GearSetData
- id
- name
- required_pieces
- bonuses

Effects should be composable.

Avoid giant conditional code such as:

if wearing_fire_set and wearing_boots and ...

Prefer effect/modifier objects.

24. Magic Architecture

Post-MVP:

MagicAbilityData
- id
- name
- cost
- cooldown
- animation
- effect
- target_type

Player:

MagicLoadout
- slot_1
- slot_2
- slot_3
- slot_4

Controller:

hold LB
A -> slot 1
B -> slot 2
X -> slot 3
Y -> slot 4

This provides a large spell library without increasing the number of primary combat buttons.

25. Save System

Start local.

Suggested save:

save.json

Data:

version,
player XP,
player level,
upgrades,
defeated bosses,
unlocked gear,
equipped gear,
magic loadout,
settings.

Include a save version number so future changes can migrate old saves.

26. Debug Tools

A developer debug overlay is strongly recommended.

Toggle:

F1

Possible values:

FPS
Player State
Boss State
Player HP
Boss HP
Current Attack
Attack Timer
Block Timer
Dodge Timer
Stagger Timer
Distance

Optional visualizations:

hitboxes,
hurtboxes,
attack ranges,
boss detection radius,
telegraph zones,
combat boundaries.

These tools will save substantial debugging time.

27. AI Coding-Agent Rules

An AI coding agent should:

Read architecture docs before editing.
Read sprint roadmap before beginning a sprint.
Inspect existing files.
Make the smallest change that completes the task.
Preserve existing behavior.
Run the project after changes.
Report changed files.
Report verification performed.
Identify anything not verified.
Never silently implement post-MVP features.

For a sprint task, request:

Goal
Files to inspect
Files to change
Implementation
Verification
Known limitations
28. Recommended Agent Development Loop
Read sprint
   ↓
Inspect repository
   ↓
Identify exact files
   ↓
Implement one feature
   ↓
Run game
   ↓
Test feature
   ↓
Fix regressions
   ↓
Commit
   ↓
Update sprint verification

Do not ask the agent to:

"Build the whole combat system."

Instead:

"Implement Sprint 05: Light Attack. Do not implement combo, block, dodge, magic, gear, or future systems."

This keeps failures attributable.

29. Verification Templates
Movement
 Controller recognized.
 Movement works.
 Camera works.
 Arena bounds work.
 No drift.
 No unintended speed changes.
Attack
 Input works.
 Startup works.
 Hit window works.
 Recovery works.
 Hitbox works.
 Damage works.
 Animation matches hit timing.
Block
 Startup.
 Active block.
 Recovery.
 Damage reduction.
 Cannot bypass recovery.
 Animation matches state.
Dodge
 Direction correct.
 Distance correct.
 Invulnerability correct.
 Recovery vulnerable.
 Cannot bypass recovery.
Boss
 Finds player.
 Attacks.
 Telegraphs.
 Recovers.
 Gets hit.
 Staggers.
 Breaks out.
 Dies.
 Resets.
30. Performance Targets

Initial development target:

60 FPS target.
Stable frame pacing.
No major spikes during attacks.
No obvious memory growth during repeated retries.

Do not prematurely optimize.

Profile after:

arena art,
boss VFX,
animations,
multiple effects,
large bosses

are present.

31. Final Implementation Order

The safest implementation sequence is:

Project
 ↓
3D pipeline
 ↓
Player movement
 ↓
Dodge
 ↓
Hitboxes
 ↓
Light attack
 ↓
Combo
 ↓
Finisher
 ↓
Block
 ↓
Boss framework
 ↓
Telegraphs
 ↓
Gladiator boss
 ↓
Stagger
 ↓
Boss breakout
 ↓
Combat tuning
 ↓
Arena art
 ↓
XP
 ↓
Levels
 ↓
HUD
 ↓
Menus
 ↓
MVP playtest

Only after MVP:

Boss selection
 ↓
Gear
 ↓
Weapons
 ↓
Magic
 ↓
More bosses
 ↓
Set bonuses
 ↓
Multiple finishers
 ↓
Mobility abilities
 ↓
Critical/Proud
 ↓
Boss Rush / optional modes
32. The Most Important Implementation Rule

If the game does not feel good by the time Sprint 16 is complete, stop adding content.

Do not solve a combat problem by adding:

another weapon,
another boss,
magic,
gear,
more stats,
another mode.

Fix:

movement,
timing,
hit feedback,
block,
dodge,
telegraphs,
stagger,
camera,
animation.

The game succeeds or fails on those systems first.
"""

files = {
"architecture.md": architecture,
"sprint-roadmap.md": roadmap,
"implementation-guide.md": implementation,
}

for filename, content in files.items():
path = os.path.join(out_dir, filename)
pypandoc.convert_text(
content,
"md",
format="md",
outputfile=path,
extra_args=["--standalone"]
)

Create a small index/readme using the same required md pipeline.

index = """# Boss Arena Gladiator — Architecture Suite

This folder contains the project planning suite:

architecture.md — technical/product architecture, systems, data model, art pipeline, and design guardrails.
sprint-roadmap.md — detailed implementation roadmap with MVP gates, post-MVP expansion, boss catalog, and sprint-by-sprint verification.
implementation-guide.md — practical implementation conventions for Godot, Blender, combat, bosses, assets, AI-assisted development, testing, and debugging.
Recommended reading order
architecture.md
sprint-roadmap.md
implementation-guide.md

The roadmap is intentionally the largest document. The MVP stops after proving the one-boss combat loop; mythology, magic, gear sets, multiple finishers, mobility abilities, harder modes, and alternate modes are preserved as post-MVP work.
"""
pypandoc.convert_text(
index,
"md",
format="md",
outputfile=os.path.join(out_dir, "README.md"),
extra_args=["--standalone"]
)

print(f"Created architecture suite in: {out_dir}")
for f in ["README.md", "architecture.md", "sprint-roadmap.md", "implementation-guide.md"]:
print(os.path.join(out_dir, f))