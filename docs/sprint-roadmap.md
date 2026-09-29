# Boss Arena Gladiator --- Sprint Roadmap

This is the primary execution document. Sprints are intentionally small
and sequential so failures can be attributed to one system at a time.

Each sprint has four parts:

-   **Goal** --- what changes.
-   **Tasks** --- what gets built.
-   **Verification** --- how to prove it works.
-   **End Goal** --- the concrete state required before moving on.

# Phase 0 --- Definition and Technical Spike

## Sprint 00 --- Project Definition

### Goal

Freeze MVP scope and establish the initial technical contract.

### Tasks

-   Create repository.
-   Create `docs/`.
-   Record MVP and explicit exclusions.
-   Decide initial controller actions.
-   Define initial player/boss scene responsibilities.
-   Define combat timing terminology.
-   Define debug requirements.

### Verification

-   MVP can be explained in one paragraph.
-   Every proposed feature is marked MVP or post-MVP.
-   No post-MVP system is required for the first playable fight.

### End Goal

A stable project definition that prevents scope creep during combat
implementation.

## Sprint 01 --- Godot / Rendering Spike

### Goal

Prove the technical foundation and rendering target.

### Tasks

-   Create Godot project.
-   Configure display and input.
-   Create temporary arena floor.
-   Add temporary player and boss placeholders.
-   Add basic third-person camera.
-   Verify controller input.
-   Establish debug logging.

### Verification

-   Project launches cleanly.
-   Controller moves the player.
-   Camera follows correctly.
-   Temporary scene maintains the intended performance target.

### End Goal

A blank but playable arena test scene.

# Phase 1 --- Player Foundation

## Sprint 02 --- Player Controller

### Goal

Create responsive third-person movement.

### Tasks

-   CharacterBody3D player.
-   Directional movement.
-   Acceleration/deceleration.
-   Rotation toward movement.
-   Gravity.
-   Arena boundary handling.
-   Basic animation hooks.

### Verification

-   Movement is responsive.
-   Player does not slide uncontrollably.
-   Player cannot leave the arena.
-   Controller input is consistent.

### End Goal

Movement feels good before combat exists.

## Sprint 03 --- Dodge

### Goal

Add fast, committed dodge movement.

### Tasks

-   Dodge state.
-   Direction selection.
-   Movement burst.
-   Completion requirement.
-   Recovery vulnerability.
-   Animation hook.

### Verification

-   Dodge is faster than walking.
-   Repeated input cannot create permanent invulnerability.
-   Player can dodge around the boss.
-   Recovery is observable in debug output.

### End Goal

Dodge is useful for both defense and positioning.

# Phase 2 --- Core Offense

## Sprint 04 --- Hitbox / Hurtbox Foundation

### Goal

Create reusable combat collision architecture.

### Tasks

-   Hurtbox component.
-   Hitbox component.
-   Damage payload.
-   Team/faction filtering.
-   Hit registration.
-   Debug visualization.

### Verification

-   Player hit can damage a test target.
-   Invalid self-hits are ignored.
-   Multiple overlapping hitboxes behave predictably.
-   Debug mode shows active areas.

### End Goal

A reusable combat interaction layer.

## Sprint 05 --- Light Attack

### Goal

Implement the first attack.

### Tasks

-   Attack state.
-   Startup.
-   Active frames.
-   Recovery.
-   Damage.
-   Hit reaction.
-   Animation hook.

### Verification

-   Attack cannot be spammed through its own recovery.
-   Hitbox appears only during the intended active period.
-   Target receives one intended hit.

### End Goal

One responsive melee attack.

## Sprint 06 --- Combo Chain

### Goal

Turn the attack into a 3--4 hit light chain.

### Tasks

-   Combo step tracking.
-   Input buffering.
-   Chain windows.
-   Reset conditions.
-   Per-step damage/timing.

### Verification

-   Correct sequence occurs.
-   Missed input resets appropriately.
-   Buffered input feels responsive.
-   Combo cannot become stuck.

### End Goal

A reliable basic light combo.

## Sprint 07 --- Automatic Finisher

### Goal

Add the first finisher automatically after the light chain.

### Tasks

-   Finisher data.
-   Finisher trigger.
-   Finisher animation.
-   Increased impact.
-   Boss stagger interaction hook.

### Verification

-   Completing the combo triggers the finisher.
-   Finisher cannot trigger twice accidentally.
-   Finisher resets the combo state.

### End Goal

Attack → chain → automatic finisher is the core offense loop.

# Phase 3 --- Defense

## Sprint 08 --- Block

### Goal

Implement generous active block and recovery.

### Tasks

-   Block state.
-   Active timer.
-   Recovery timer.
-   Damage reduction.
-   Normal attack perfect-block behavior.
-   Heavy/special reduced-damage behavior.

### Verification

-   Normal boss attacks can be blocked.
-   Player takes no damage from intended normal blocks.
-   Heavy attacks can still cause reduced damage.
-   Immediate re-block cannot bypass recovery.

### End Goal

Blocking feels forgiving but cannot be held forever.

## Sprint 09 --- Dodge / Block Integration

### Goal

Make defense choices interact cleanly.

### Tasks

-   State priority rules.
-   Dodge cancellation rules.
-   Block cancellation rules.
-   Recovery windows.
-   Damage immunity rules.

### Verification

-   No contradictory states.
-   Player cannot become permanently invulnerable.
-   Dodge and block each have a recognizable purpose.

### End Goal

A coherent defensive model.

# Phase 4 --- Boss Foundation

## Sprint 10 --- Boss Framework

### Goal

Build a reusable boss controller.

### Tasks

-   Boss scene.
-   Boss state machine.
-   Target tracking.
-   Distance evaluation.
-   Attack selection interface.
-   Health.
-   Defeat state.

### Verification

-   Boss follows player.
-   Boss can enter and exit states.
-   Boss can be defeated without special-case code.

### End Goal

A reusable boss framework rather than a one-off enemy.

## Sprint 11 --- Telegraph System

### Goal

Create readable attack warnings.

### Tasks

-   Telegraph data.
-   Windup timer.
-   Visual indicator.
-   Attack activation.
-   Cancellation rules.
-   Debug timing display.

### Verification

-   Player can identify an incoming attack.
-   Telegraph duration is measurable.
-   Active attack occurs after the warning.
-   Effects do not obscure the signal.

### End Goal

Telegraphs become a core combat language.

## Sprint 12 --- New Gladiator

### Goal

Build the MVP boss.

### Tasks

-   Gladiator model placeholder.
-   Basic melee chain.
-   Approach behavior.
-   Telegraphs.
-   Recovery.
-   Basic defense.
-   Death.

### Verification

-   Boss can complete a full fight.
-   Player can win using attack, block, and dodge.
-   Boss does not soft-lock.

### End Goal

A complete first boss encounter exists.

# Phase 5 --- Stagger and Punish

## Sprint 13 --- Boss Stagger

### Goal

Make successful combat create punish windows.

### Tasks

-   Stagger state.
-   Stagger timer.
-   Stagger resistance.
-   Hit reactions.
-   Attack interruption rules.

### Verification

-   Correct attacks stagger the boss.
-   Stagger ends automatically.
-   Boss cannot attack while appropriately staggered.

### End Goal

The player has a meaningful offensive reward for good defense/attacks.

## Sprint 14 --- Boss Breakout

### Goal

Prevent infinite stagger loops.

### Tasks

-   Finisher counter.
-   Breakout behavior.
-   Boss defensive response.
-   Recovery transition.

### Verification

-   Boss can be punished during stagger.
-   After the configured finisher event, boss breaks out.
-   Boss resumes combat predictably.

### End Goal

Combat cycles naturally between neutral, defense, stagger, punish, and
reset.

# Phase 6 --- Combat Feel

## Sprint 15 --- Hit Feedback

### Goal

Make successful actions feel impactful.

### Tasks

-   Hit pause/hit-stop.
-   Camera impulse where appropriate.
-   Impact VFX.
-   Sound hooks.
-   Boss reaction animations.
-   Damage feedback.

### Verification

-   Hits are immediately readable.
-   Feedback does not obscure telegraphs.
-   Heavy attacks feel heavier than light attacks.

### End Goal

The combat has physical feedback rather than placeholder interactions.

## Sprint 16 --- Combat Tuning Lab

### Goal

Tune the complete MVP combat loop before adding content.

### Tasks

-   Movement speed tuning.
-   Dodge duration/recovery tuning.
-   Block duration/recovery tuning.
-   Combo timing.
-   Finisher timing.
-   Telegraph timing.
-   Boss recovery.
-   Stagger duration.
-   Camera distance.
-   Hit feedback.

### Verification

-   A new player can understand the fight.
-   Skilled play can consistently exploit readable openings.
-   Blocking is useful but not dominant.
-   Dodge is useful but not free.
-   Combat does not feel sluggish.

### End Goal

**Combat fun is proven before content expansion.**

# Phase 7 --- Colosseum

## Sprint 17 --- Colosseum Blockout

### Goal

Replace the temporary floor with the actual arena layout.

### Tasks

-   Arena floor.
-   Walls.
-   Entry area.
-   Spectator structure placeholders.
-   Camera boundaries.
-   Navigation boundaries.

### Verification

-   Player and boss remain readable.
-   Arena is large enough for positioning but not so large that combat
    becomes empty.
-   Camera remains functional around the boundaries.

### End Goal

Playable Colosseum blockout.

## Sprint 18 --- Stylized Art Pass

### Goal

Establish the visual identity.

### Tasks

-   Low-poly arena geometry.
-   Stylized materials.
-   Player visual.
-   Gladiator visual.
-   Basic lighting.
-   Basic environment props.

### Verification

-   Silhouettes are readable.
-   Combat remains visually clear.
-   Performance target remains achievable.

### End Goal

A recognizable stylized arena rather than a prototype room.

# Phase 8 --- Progression

## Sprint 19 --- XP

### Goal

Add persistent progression rewards.

### Tasks

-   XP model.
-   XP on victory.
-   XP on failure.
-   Reward calculation.
-   Save integration hook.

### Verification

-   Both victory and defeat award XP correctly.
-   XP survives restart after save.

### End Goal

Every attempt contributes to progression.

## Sprint 20 --- Basic Level-Up

### Goal

Implement simple player levels and stats.

### Tasks

-   Level thresholds.
-   HP.
-   Attack.
-   Movement speed.
-   Attack speed.
-   Stat application.

### Verification

-   Leveling changes stats.
-   Stats persist.
-   No stat is applied twice after scene reload.

### End Goal

A simple progression loop exists without RPG complexity.

# Phase 9 --- Player Experience

## Sprint 21 --- HUD

### Goal

Expose combat information cleanly.

### Tasks

-   Player health.
-   Boss health.
-   XP/level.
-   Optional stamina/recovery indicators if needed.
-   Boss telegraph support.

### Verification

-   Important information is readable during combat.
-   HUD does not cover the action.

### End Goal

The player understands combat state without debug tools.

## Sprint 22 --- Menus / Retry

### Goal

Complete the basic game loop.

### Tasks

-   Title/start flow.
-   Pause.
-   Victory.
-   Defeat.
-   Retry.
-   Return to menu.
-   Save/load.

### Verification

-   Every transition works.
-   Retry resets the fight cleanly.
-   Pause cannot break combat state.
-   Save data remains valid.

### End Goal

A complete playable loop from launch to victory/defeat and replay.

# Phase 10 --- MVP Validation

## Sprint 23 --- Full MVP Playthrough

### Goal

Integrate everything into one cohesive build.

### Tasks

-   Full arena.
-   Full player.
-   Full Gladiator.
-   HUD.
-   Progression.
-   Menus.
-   Save.
-   Audio/VFX pass.
-   Remove prototype-only dependencies.

### Verification

-   Fresh install/playthrough works.
-   Victory works.
-   Failure works.
-   XP works after both.
-   Retry works.
-   No known soft-lock.

### End Goal

A complete MVP build.

## Sprint 24 --- External Playtest

### Goal

Test whether the combat is understandable and enjoyable without
developer guidance.

### Tasks

-   Give build to external tester(s).
-   Observe first fight.
-   Record confusion points.
-   Record deaths and successful defenses.
-   Record control issues.
-   Prioritize fixes.

### Verification

-   Tester understands movement.
-   Tester discovers attack.
-   Tester understands block/dodge.
-   Tester recognizes boss telegraphs.
-   Tester understands victory/defeat.

### End Goal

Evidence that the MVP communicates its core loop.

# Phase 11 --- Post-MVP Foundation

## Sprint 25 --- Boss Selection

Goal: establish selectable encounters without changing the core fight
architecture.

Verification: multiple boss data entries can be selected and loaded.

End Goal: boss selection screen/framework.

## Sprint 26 --- Gear Framework

Goal: add equippable gear data and stat modifiers.

Verification: equipment changes player stats and persists correctly.

End Goal: gear can be added without rewriting player combat.

## Sprint 27 --- Weapon Variants

Goal: support different weapons while preserving the compact combat
model.

Verification: weapon data changes attack behavior/visuals correctly.

End Goal: multiple weapons are possible without controller bloat.

# Phase 12 --- Magic

## Sprint 28 --- Mana

Goal: add mana expenditure and delayed regeneration.

Verification: mana decreases on use and regenerates after the configured
delay.

End Goal: reliable mana subsystem.

## Sprint 29 --- Four-Slot Spell Input

Goal: implement LB + A/B/X/Y spell selection.

Verification: each of four slots reliably activates its assigned spell.

End Goal: four equipped spells can coexist with melee controls.

## Sprint 30 --- Initial Magic

Goal: implement initial spell pool.

Initial candidates: heal, reflect, fire, freeze.

Verification: each spell has distinct behavior and resource cost.

End Goal: first build-oriented magic loadout.

# Phase 13 --- Boss Expansion

## Sprint 31 --- Minotaur

Mechanics: charge, heavy attacks, shockwaves, positioning.

Verification: behavior is clearly distinct from New Gladiator.

End Goal: positioning-focused boss.

## Sprint 32 --- Medusa

Mechanics: petrification threat, ranged pressure, reflection.

Verification: player must adapt to facing/range and telegraph
differences.

End Goal: ranged/control boss.

## Sprint 33 --- Giant Spider

Mechanics: webs, poison, pounce, possible summons.

Verification: mobility and status pressure create a distinct encounter.

End Goal: control/mobility boss.

## Sprint 34 --- Giant Crab

Mechanics: armor, sweeping claws, shorter openings.

Verification: positioning and punish timing differ from other bosses.

End Goal: armored defense-oriented boss.

## Sprint 35 --- Mutated Lion

Mechanics: pursuit, pounce, bleed, aggression/enrage.

Verification: fight has noticeably higher movement pressure without
relying only on HP.

End Goal: aggressive pursuit boss.

# Phase 14 --- Build Identity

## Sprint 36 --- Set Framework

Goal: support gear sets and set bonuses.

Verification: equipping a set changes configured gameplay effects.

End Goal: extensible set system.

## Sprint 37 --- Flame Set

Goal: implement fire-focused identity.

Verification: fire magic gains major area/effect changes when equipped.

End Goal: magic specialization build.

## Sprint 38 --- Gladiator Set

Goal: implement speed-focused identity.

Verification: movement/attack speed increase and finisher explosion work
together without breaking combat rules.

End Goal: high-speed melee build.

# Phase 15 --- Advanced Combat

## Sprint 39 --- Multiple Finishers

Goal: add configurable finisher sequences.

Verification: finishers can chain automatically according to data
configuration.

End Goal: expanded combo expression without a larger action bar.

## Sprint 40 --- Mobility Abilities

Goal: expand movement specialization.

Verification: mobility abilities obey combat state/recovery rules.

End Goal: mobility builds can feel meaningfully different.

# Phase 16 --- Advanced Bosses

## Sprint 41 --- Hydra

Goal: implement multi-head/regeneration encounter.

Verification: head/state changes affect combat behavior correctly.

End Goal: multi-target boss.

## Sprint 42 --- Hades

Goal: implement resurrection/summon/phase mechanics.

Verification: phase transitions cannot soft-lock and resurrection is
deterministic.

End Goal: multi-phase supernatural boss.

## Sprint 43 --- Zeus

Goal: implement lightning/ranged/arena-wide pressure.

Verification: arena-wide attacks remain readable and counterable.

End Goal: ranged arena-control boss.

# Phase 17 --- Critical / Proud

## Sprint 44 --- Advanced Difficulty

Goal: create a harder mode based on changed behavior and timing.

### Tasks

-   Boss multipliers where justified.
-   Speed changes.
-   Additional attacks.
-   Shorter telegraphs.
-   More aggressive transitions.
-   Optional halo/skull modifiers.

### Verification

-   Difficulty is meaningfully different.
-   HP inflation is not the primary mechanic.
-   Existing bosses remain readable.

### End Goal

A challenging mode that changes combat behavior.

# Phase 18 --- Optional Modes / Experiments

## Sprint 45 --- Boss Rush

Goal: test a mode that directly reinforces the boss-arena identity.

Verification: multiple encounters can be chained with progression
preserved appropriately.

End Goal: replayable Boss Rush prototype.

## Sprint 46 --- Endless Survival Experiment

Goal: test whether wave survival adds value without diluting the core
game.

Verification: mode is fun independently and does not require rewriting
boss systems.

End Goal

Keep, revise, or shelve based on playtest evidence.

## Sprint 47 --- Dungeon Experiment

Goal: test limited exploration/progression between fights.

Verification: exploration adds meaningful decisions rather than becoming
unrelated content.

End Goal

Keep, revise, or shelve based on evidence.

# Phase 19 --- Hardening

## Sprint 48 --- Asset Pipeline Automation

Goal: reduce manual work for repeated boss/asset creation.

Tasks: - Blender scripts. - Naming validation. - GLB export checks. -
Godot import checks. - Basic asset manifests.

Verification: a new test asset can pass the pipeline with minimal manual
correction.

End Goal: repeatable asset pipeline.

## Sprint 49 --- Performance Pass

Goal: verify performance on intended low/mid-range hardware.

Tasks: - Frame-time profiling. - Draw-call review. - Lighting review. -
VFX review. - Collision review. - Memory review.

Verification: target frame rate is stable in representative combat.

End Goal: predictable performance.

## Sprint 50 --- Controller QA

Goal: test all combat and menu flows using the controller as the primary
interface.

Verification: no required keyboard/mouse dependency remains for normal
play.

End Goal: controller-first experience.

## Sprint 51 --- Final Combat Polish

Goal: final pass on the core feel.

Tasks: - Timing. - Camera. - Hit feedback. - Telegraph readability. -
Animation transitions. - Sound. - VFX. - Input buffering. - Recovery
windows.

Verification: complete playthrough without debug tools feels cohesive.

End Goal: combat is polished enough to support further content
production.

# Global Verification Gates

Do not advance because a sprint's code exists. Advance because its
behavior is verified.

## Gate A --- Combat Feel

-   Movement is responsive.
-   Attacks have readable timing.
-   Block feels generous.
-   Dodge feels useful.
-   Hit feedback is clear.

## Gate B --- Readability

-   Boss silhouettes are clear.
-   Telegraphs are understandable.
-   VFX do not hide danger.
-   Camera maintains useful combat distance.

## Gate C --- Boss Identity

Every new boss should introduce a meaningful behavioral difference, not
just new HP/damage values.

## Gate D --- Build Identity

Gear, magic, finishers, and mobility should change decisions or play
patterns, not simply add larger numbers.

## Gate E --- Scope

If a feature requires unrelated infrastructure or significantly delays
combat validation, defer it.

## Gate F --- Performance

Representative fights should maintain the intended frame-rate target on
the development hardware.

# MVP Exit Criteria

MVP is complete only when all of the following are true:

-   One complete Colosseum.
-   One complete New Gladiator boss.
-   Controller-first controls.
-   Responsive movement.
-   Useful but constrained dodge.
-   Generous but non-infinite block.
-   Light attack chain.
-   Automatic finisher.
-   Readable boss telegraphs.
-   Boss stagger.
-   Boss breakout.
-   Player death.
-   Boss victory.
-   XP on failure.
-   Basic leveling.
-   Restart.
-   Pause.
-   No known soft-lock.
-   External tester can understand basic combat.
-   Most importantly: the MVP is fun before post-MVP systems are added.
