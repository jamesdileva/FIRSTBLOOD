# Worklog — Boss Arena Gladiator

Append-only sprint log. **Newest entry first.** One entry per sprint (or per meaningful session).
Never rewrite past entries — corrections go into a new entry. Decisions get stable IDs (`D-NNN`).

The entry template is at the bottom of this file.

---

## 011 · 2026-09-28 · Dodge / Block Integration (Sprint 09)

**Goal:** A coherent defensive model — full state-transition matrix (priority + cancellation rules), committed recovery windows, and a documented immunity map with no permanent-invulnerability holes.

**Scope:** `player_controller.gd` (attack-recovery cancels, block-active cancels), new `tools/validation/defense_check.gd` (the full combination matrix), new `docs/playtesting.md` (user-requested running batch-playtest checklist — maintained by the loop from now on), `AGENTS.md` (loop step 5 gains the checklist update).
**Non-goals:** boss-side behavior (no attacker exists until Sprint 10+), perfect parry (post-MVP), player hit reactions (Sprint 13), new tuning values.

**Decisions:**

- **D-029 (transition matrix):** committed windows stay committed — attack startup/active, dodge travel, and ALL recovery windows (dodge + block) accept no re-defense. Two cancel rules open the model up without breaking commitment: **an attack's recovery (after its hit window) can be canceled by dodge (priority) or block**, and **an active guard can be canceled by dodge or attack** (the attack is a fresh light_01 — blocking reset the chain). This applies to the finisher like any step. Neutral trigger priority stays dodge > block > attack.
- **D-030 (immunity map + event ordering):** dodge-travel i-frames are the *only* invulnerability in the game; block active is negation/mitigation, **never** immunity. Ordering: the hurtbox suppresses i-frame hits before the player's resolver sees them (hurtbox immunity → player resolution → Sprint 10 HealthComponent). No state combination yields permanent invulnerability: block↔dodge cycling keeps i-frame uptime ≤ 0.15 s per ≥ 0.4 s dodge cycle, and heavies always penetrate an active guard at 30 %.

**Roadmap checklist coverage (needs-review combination list):** idle→block, block→attack, attack→dodge, dodge→attack, dodge→block, block→dodge, recovery→attack, recovery→dodge — all asserted in `defense_check.gd`, plus "no contradictory states" (single state machine), "no permanent invulnerability" (immunity map tests), and "each has a recognizable purpose" (dodge = i-frame repositioning; block = stationary negation/mitigation).

**Implemented:**

- `player_controller.gd` — the two cancel rules from D-029: attack-recovery dodge/block cancels (checked before the buffer window, so dodge wins on a same-frame conflict) and block-active dodge/attack cancels. No other state changes — the matrix falls out of the single state machine.
- `docs/playtesting.md` — the running batch-playtest checklist (batch 1 = Sprints 02–09), now part of the loop.
- `tools/validation/defense_check.gd` — walks the combination matrix end-to-end.

**Files changed:** the above plus `.uid` sidecar and `AGENTS.md` (loop step 5).

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 14 resources)
- [x] Defense check — PASS:
  - attack recovery cancels into dodge and into block; startup/active ignore dodge (committed)
  - canceling dodge resets the chain (next swing light_01)
  - active guard cancels into dodge and into attack (fresh light_01)
  - block recovery: dodge ignored until it completes, then works
  - dodge recovery: attack ignored until it completes, then works
  - active block never grants invulnerability
- [x] Regressions — all six prior suites PASS (movement, dodge, combat, attack, combo, block), 180-frame run clean
- [ ] Cancel *feel* — batch playtest (batch 1 in `docs/playtesting.md` is ready).

Result: **PASS (automated)**.

**Check-harness note:** the first defense_check run flagged "dodge bypassed block recovery" — a harness bug, not game logic: test 5 never released the block button, so test 6's press had no fresh edge and the dodge legitimately fired from neutral. Harness rule: every synthesized press needs its release.

**Known limitations:**

- No attacker exists yet, so all cancels are input-driven; real pressure arrives with the boss (Sprint 10+).
- Block→attack cancel always starts a fresh chain (blocking reset it) — intentional.
- Damage-event ordering is documented (D-030) but HealthComponent arrives Sprint 10.

**Next:** Phase 4 begins — Sprint 10 Boss Framework: reusable boss controller, state machine, target tracking, attack selection, health, defeat. gdUnit4 integration also comes due here (D-017). Plan+scope first.

---

## 010 · 2026-09-28 · Block (Sprint 08)

**Goal:** Generous but non-infinite block — a held guard with a fixed active window, a vulnerable recovery that re-blocking cannot bypass, and per-hit-type damage resolution.

**Scope:** `player_controller.gd` (BLOCK_STARTUP/BLOCK_ACTIVE/BLOCK_RECOVERY states, block timers, movement restriction, the player's damage-resolution layer), `debug_overlay.gd` (block timer), new `tools/validation/block_check.gd`.
**Non-goals:** block→attack/dodge cancellation rules (Sprint 09 is exactly that matrix), chip-damage resources/stamina, frame-perfect parry (docs: "perfect timing may be added later" — post-MVP), boss stagger from blocked hits (Sprint 13/14 consumes the hook), authored animations.

**Decisions:**

- **D-026 (block model):** three states per guide §7 — `BLOCK_STARTUP` 0.10 s (guard coming up; hits land normally) → `BLOCK_ACTIVE` max 2.5 s (doc target 2–3 s) → `BLOCK_RECOVERY` 0.75 s (vulnerable). Releasing early drops straight into recovery — tap-spamming can never reach a perpetual block. Holding through recovery re-engages the guard (generous cycle), but only after the full recovery: "immediate re-block cannot bypass recovery".
- **D-027 (damage-resolution layer):** the player connects its own hurtbox's raw `damaged` signal and re-emits **resolved** results: `hit_blocked` (NORMAL hits during active block — fully negated), `hit_mitigated` (HEAVY/SPECIAL during active block — amount × `block_heavy_multiplier` 0.3), `hit_taken` (everything else). The future HealthComponent (Sprint 10) consumes **only** the resolved signals, never the raw hurtbox. Blocked events keep their stagger payload — the Sprint 13/14 hook for "a successful normal block can leave the boss staggered".
- **D-028:** blocking resets the combo chain (defensive state, guide §9). Movement: slow walk (0.4×) during startup/active, normal movement during recovery (D-018 spirit — never planted). Trigger from grounded neutral only; priority when simultaneous: dodge > block > attack. Attack/dodge out of block is Sprint 09's matrix.

**Roadmap checklist coverage:** normal attacks blocked with no damage · heavy attacks reduced, not negated · recovery leaves the player vulnerable · immediate re-block cannot bypass recovery · block cannot be held forever (active timer expires while held) → `block_check.gd`.

**Implemented:**

- `player_controller.gd` — three block states with the D-026 lifecycle, `_resolve_incoming_damage()` (D-027), block-speed movement multiplier (`_neutral_movement` gained a `speed_multiplier` parameter), block animation hooks (`block_start`/`block_loop`/`block_recover`), combo reset on block, input priority dodge > block > attack.
- `debug_overlay.gd` — block timer line (active/recovery remaining).
- `tools/validation/block_check.gd` — drives the real player with a controlled boss-faction test hitbox and asserts the full checklist plus combo reset.

**Files changed:** the above plus `.uid` sidecar.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 14 resources)
- [x] Block check — PASS:
  - normal attack during active block: exactly 1 `hit_blocked`, zero damage taken
  - heavy attack during active block: exactly 1 `hit_mitigated` at 20 × 0.3 = 6.0, zero taken
  - releasing early drops into recovery; a hit during recovery is taken in full (vulnerable)
  - holding block through recovery never re-enters the guard (no bypass)
  - holding forever: active expires into recovery while held, then the guard re-engages — cycles with gaps, never permanent
  - blocking mid-grace resets the chain: next swing is light_01, not light_02
- [x] Regressions — movement PASS, dodge PASS, combat PASS, attack PASS, combo PASS, 180-frame run clean
- [ ] Block *feel* (generosity, 2.5 s window, slow-walk speed) — user playtest; all values are exports.

Result: **PASS (automated)**.

**Check-harness note:** the first block_check run "hung" — it had actually passed all assertions but the PASS print dereferenced the player *after* `arena.free()` (freed-instance access killed the coroutine before `quit()`). Harness rule: capture any player exports before teardown.

**Known limitations:**

- Attack/dodge inputs are ignored while in any block state — the block→attack/block→dodge transition matrix is Sprint 09's entire scope.
- Blocked normal attacks don't yet stagger the boss (no boss to stagger — Sprint 13/14 consumes `hit_blocked`'s stagger payload).
- No block feedback (VFX/sound/controller rumble) — Sprint 15.
- No stamina/chip damage — intentionally absent per docs.

**Next:** Sprint 09 — Dodge/Block Integration: the full state-transition matrix (attack↔block↔dodge cancellation rules, priority, damage-event ordering) so no contradictory states or invulnerability holes exist. Plan+scope first.

---

## 009 · 2026-09-28 · Automatic Finisher (Sprint 07)

**Goal:** Complete the core offense loop — attack → chain → automatic finisher — with increased impact and the boss-stagger interaction hook, no extra button.

**Scope:** `combo_data.gd` (finisher field), `combo_step_data.gd` (hit_type field), `player_light_combo.tres` (finisher step), `player_controller.gd` (finisher trigger/reset, payload push, `finisher_started`), `combo_check.gd` + `attack_check.gd` updates.
**Non-goals:** actual stagger/breakout (Sprints 13/14 — this sprint only ships the data hook), camera/VFX response (Sprint 15 consumes `finisher_started`), multiple/chained finishers (Sprint 39).

**Playtest note (entry 006 follow-up):** user verified movement, dodge, and chained/partial combos feel good. Damage escalation is not visible yet — by design: no HP components until Sprint 10, no hit feedback until Sprint 15, HUD in Sprint 21.

**Decisions:**

- **D-024:** The finisher is **fully automatic**: completing the third chain step always leads into it — no extra press. It cannot fire early (the only entry path is chain completion), cannot loop (it always ends the sequence and resets the combo), and buffered presses during it are absorbed. This reads the docs' "automatic spectacle" literally: every full chain culminates in the finisher.
- **D-025:** Finisher lives in `ComboData.finisher` (single MVP finisher; configurable sequences are Sprint 39). Data: `finisher_01`, damage 25, stagger 15, `hit_type = HEAVY`, timing 0.18/0.16/0.40 — a heavier commitment than any chain step. **Stagger hook:** `hit_type` + `stagger_damage` ride the DamageEvent (Sprint 13's StaggerComponent will consume them to trigger/break stagger), and a new `finisher_started` signal gives camera/VFX a hook (Sprint 15).

**Roadmap checklist coverage:** completing the combo triggers the finisher (sequence test) · cannot trigger twice accidentally (post-finisher press → light_01) · cannot trigger early (event gap ≥ light_03's full duration) · finisher resets the combo state → `combo_check.gd`; mashing payloads widened to include the finisher's 25 dmg in `attack_check.gd`.

**Implemented:**

- `combo_step_data.gd` — `hit_type` field (NORMAL/HEAVY/SPECIAL); `combo_data.gd` — `finisher` field.
- `player_light_combo.tres` — `finisher_01`: 25 dmg, 15 stagger, HEAVY, 0.18/0.16/0.40; empty buffer window by design (`buffer_close < buffer_open`, commented in the resource).
- `player_controller.gd` — `_advance_after_step()` routes chain completion into `_play_finisher()`; finisher end always resets (`_in_finisher` flag, dodge also clears it); payload push centralized in `_push_step_payload()`; `finisher_started` signal.
- `combo_check.gd` / `attack_check.gd` — finisher-aware expectations.

**Files changed:** the above (no scene changes — the finisher lives entirely in the resource).

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 14 resources)
- [x] Combo check — PASS:
  - completing the chain triggers the finisher: sequence light_01 → light_02 → light_03 → finisher_01
  - cannot trigger early: finisher's hit lands ≥ 34 ticks after light_03's (full step duration in between)
  - increased impact verified in the event: 25.0 damage, `hit_type = HEAVY`, 15.0 stagger
  - cannot trigger twice / resets state: after the finisher, the next press is a fresh light_01
  - mashing cycles 01 → 02 → 03 → finisher with every hit a full step apart (28–44 ticks), no deadlock
- [x] Regressions — movement PASS, dodge PASS, combat PASS, attack PASS (6 swings, recovery respected), 180-frame run clean
- [ ] Finisher *feel* (weight, commitment of the 0.74 s cycle) — user playtest; all values in `player_light_combo.tres`.

Result: **PASS (automated)**.

**Known limitations:**

- No visible payoff yet: damage/stagger are event data — visible feedback arrives with the boss (Sprint 10+), hit feedback (Sprint 15), HUD (Sprint 21).
- The stagger hook is data-only until Sprints 13/14 build StaggerComponent/breakout on top of `hit_type`/`stagger_damage`.
- `finisher_started` has no listeners yet (Sprint 15 camera/VFX).

**Next:** Phase 3 — Sprint 08 Block: block state with active window + recovery, damage reduction, normal vs heavy attack behavior. Plan+scope first.

---

## 008 · 2026-09-28 · Combo Chain (Sprint 06)

**Goal:** Turn the single light attack into a reliable 3-hit chain — combo step tracking, input buffering, chain windows, and reset conditions — driven by data Resources.

**Scope:** new `game/scripts/combat/combo_data.gd` + `combo_step_data.gd` (Resource classes), new `game/resources/attacks/player_light_combo.tres` (the actual chain data), `player_controller.gd` (combo index, buffer, grace, per-step payload push), `player.tscn` (combo resource assignment), `debug_overlay.gd` (combo step display), new `tools/validation/combo_check.gd`, smoke-check list extended, `attack_check.gd` payload assertion widened to the per-step damage values.
**Non-goals:** the automatic finisher (Sprint 07 — chain completion currently resets), attack↔dodge/block transition matrix (Sprint 09), per-step hit reactions (Sprint 13), authored swing animations.

**Decisions:**

- **D-022 (data migration promised in D-019):** the chain lives in `ComboData`/`ComboStepData` Resources — per-step `attack_id`, `animation`, `damage`, `stagger_damage`, `startup/active/recovery`, and a `[buffer_open, buffer_close]` input window in seconds from step start. One shared AttackHitbox gets its payload pushed per swing (one hitbox, data-driven payload), rather than one hitbox per step. Controller exports `attack_startup/active/recovery` are removed — the resource is the single source.
- **D-023 (buffer + reset semantics):** a press inside a step's buffer window is remembered (once) and consumed when the step ends, chaining into the next step immediately. A step that ends *without* buffered input keeps the chain alive for `reset_timeout` (0.35 s) so a slightly-late press still continues it — "stops attacking for too long" then resets to step 1. Completing the last step resets immediately (finisher slot, Sprint 07). Presses later than `buffer_close` are ignored — no accidental continuation. Any dodge resets the chain at once.

**Roadmap checklist coverage:** correct sequence occurs (attack_id sequence incl. wrap to a fresh combo) · missed input resets (grace expiry test) · buffered input feels responsive (mash-chaining with full-step gaps, ≤1-tick transitions) · combo cannot become stuck (mash ends → IDLE, hitbox inert, index reset) → `combo_check.gd`.

**Implemented:**

- `combo_data.gd` / `combo_step_data.gd` — Resource classes per D-022.
- `player_light_combo.tres` — light_01 (10 dmg) → light_02 (12) → light_03 (14), per-step timings, buffer windows 0.05→0.30 s (step 3: 0.05→0.44), `reset_timeout` 0.35 s.
- `player_controller.gd` — combo index, one-press-per-step buffering, grace continuation, chain-completion reset, dodge-reset; `_play_combo_step()` pushes the step payload into the shared AttackHitbox, restarts the step clock explicitly, and plays the step's animation (the state setter dedupes same-value transitions, so ATTACK→ATTACK chaining needs both). Controller attack-timing exports removed. Fallback single-swing combo if the resource is missing (no soft-lock).
- `debug_overlay.gd` — `Combo: 2/3 buffered` line via `combo_debug_text()`.
- `attack_check.gd` — swing counting moved from state entries to hit timestamps (chaining re-enters ATTACK without a state change, so entry-counting under-counts).

**Files changed:** the above plus `.uid` sidecars and `smoke_check.gd` (resource list now 14).

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 14 resources)
- [x] Combo check — PASS:
  - correct sequence: light_01 → light_02 → light_03 → light_01 (wrap to fresh combo)
  - mashing 100×: swings chain buffer-to-buffer with every hit a full step apart (28–34 ticks — recovery respected), sequence cycles cleanly, and the combo returns to IDLE with an inert hitbox after input stops — no deadlock
  - dropped input: chain continues inside the 0.35 s grace (light_02 after a late-ish follow-up), and resets to light_01 after the grace expires
  - late input past `buffer_close`: ignored — next press starts a fresh light_01, no accidental continuation
- [x] Regressions — movement PASS, dodge PASS (commitment held, 9 entries), combat PASS, attack PASS (active window 6–12 ticks, 6 swings, recovery respected), 180-frame run clean
- [ ] Combo *feel* (chain pacing, per-step damage spread) — user playtest; all values live in `player_light_combo.tres`.

Result: **PASS (automated)**.

**Bug the check caught:** chaining re-entered ATTACK without resetting `state_elapsed` (the state setter ignores same-value assignment), so the buffered next step started with the previous step's clock and instantly skipped — the first run produced light_01 → light_03. Fixed by restarting the clock in `_play_combo_step()`.

**Known limitations:**

- No finisher yet: a buffered press during the last step is absorbed and the chain resets (Sprint 07 replaces that with the automatic finisher).
- Chain resets on dodge but not yet on being hit (player hit reactions arrive in Sprint 09/13).
- Attack can't cancel dodge recovery (Sprint 09 owns transitions).
- No authored animations — per-step `animation` names (`attack_01/02/03`) are wired for the art pass.

**Next:** Sprint 07 — Automatic Finisher: finisher data + trigger after the chain, increased impact, and the boss-stagger interaction hook. Plan+scope first.

---

## 006 · 2026-09-28 · Playtest Results + Dodge Recovery Retune (D-018)

**Goal:** Record the user's first controller playtest and apply its one fix: dodge recovery must never plant the player stationary.

**Playtest results (user, controller):**

- Movement + camera: **good, verified, working** — closes the pending manual checks from Sprints 01–03.
- Arena bounds: worked as intended.
- F1 debug mode: works.
- Dodge: recovery planted the player stationary for the full 1.0 s — rejected. Wanted: ~0.1–0.2 s of commitment, never stationary, walk/run resumes immediately, only re-dodging blocked (anti-infinite-dodge).

**Decision:**

- **D-018 (revises the architecture §6 tuning target of "around one second"):** `dodge_recovery = 0.15 s`. Recovery is a short vulnerable window that does **not** lock movement — input moves the player normally during it; the only blocked action is starting another dodge until the window completes (travel 0.25 s + recovery 0.15 s ≈ 0.4 s minimum between dodge starts, so i-frames can never chain into permanent invulnerability). Architecture §6 is updated to match the decided design.

**Scope:** `player_controller.gd` (recovery branch runs normal movement, no dodge trigger), `docs/architecture.md` §6 (doc maintenance per Definition of Done), `tools/validation/dodge_check.gd` (commitment constant updated).
**Non-goals:** attack/dodge transition rules (Sprint 09), input buffering (Sprint 06).

**Verification (updated `dodge_check.gd`):**

- [x] Commitment held under input spam: re-dodge gaps ≥ 22 ticks (24-tick nominal commitment), no i-frame chaining
- [x] Recovery observed and vulnerable; i-frames still bounded to travel
- [x] Movement + dodge regressions PASS; main scene 180 frames clean

Result: **PASS**.

---

## 007 · 2026-09-28 · Light Attack (Sprint 05)

**Goal:** One responsive melee attack — the first real consumer of the Sprint 04 combat layer, with startup/active/recovery timing and a hit-reaction hook.

**Scope:** `player_controller.gd` (ATTACK state: rooted, timed windows, hitbox activation), `player.tscn` (AttackHitbox node — player-faction HitboxComponent with capsule-reach box), new `tools/validation/attack_check.gd`.
**Non-goals:** combo chain and input buffering (Sprint 06), attack↔dodge/block transition rules (Sprint 09 — attack currently triggers only from IDLE/MOVE, grounded), target hit reactions/stagger (Sprint 13), hit feedback VFX/hitstop (Sprint 15), authored animations (art pass).

**Decisions:**

- **D-019:** Timing lives on the controller (`attack_startup 0.10 / active 0.12 / recovery 0.25`, all exports); the payload (`damage 10.0`, `stagger_damage 5.0`, `attack_id light_01`) lives on the scene's AttackHitbox node. Controller owns timing; hitbox owns payload — Sprint 06's combo data will drive both.
- **D-020:** The attack is rooted and committed: movement input ignored during ATTACK (decelerates to stop), grounded only, trigger from IDLE/MOVE only. Dodge input takes priority over attack when both land the same frame. Attack during dodge recovery is blocked for now — Sprint 09 owns those transitions.
- **D-021:** Hit-reaction hook: the player re-emits its hitbox's `hit_landed` as `attack_connected(event, target)` — hitstop, VFX, and target reactions (Sprints 13/15) hang from that signal without touching the attack state machine.

**Roadmap checklist coverage:** attack cannot be spammed through its own recovery (entry-gap assertion) · hitbox appears only during the active period (tick-sampled) · target receives one intended hit per swing (real boss-placeholder hurtbox via synthesized input) → `attack_check.gd`.

**Implemented:**

- `player_controller.gd`: `ATTACK` state — rooted (movement input ignored, decelerates), grounded trigger from IDLE/MOVE only, dodge input has priority when both land the same frame; hitbox activation gated to `[startup, startup+active)`; recovery exits to IDLE. `attack_connected(event, target)` re-emits the hitbox's `hit_landed` as the hit-reaction hook.
- `player.tscn`: `AttackHitbox` node — player-faction HitboxComponent, box reach centered 1 m in front, payload damage 10 / stagger 5 / `light_01`.
- `tools/validation/attack_check.gd` — end-to-end check against the real boss hurtbox.

**Files changed:** the above plus `.uid` sidecars.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 11 resources)
- [x] Attack check — PASS:
  - hitbox active only in the intended window (observed active ticks 6–12 of the swing; silent during startup and recovery)
  - boss hurtbox received exactly one event with the full payload (amount 10, stagger 5, `light_01`, source = player)
  - mashing attack for ~3 s: 6 swings → 6 hits, every re-attack gap ≥ 26 ticks (28-tick commitment) — recovery cannot be bypassed
  - hitbox inert outside ATTACK
- [x] Regressions — movement PASS (travel 4.73 m, dots 1.00, drift 0.000), dodge PASS (commitment held, 9 entries), combat PASS (all six assertions), 180-frame run clean
- [ ] Attack *feel* (rooting weight, reach, recovery length) — user playtest; D-019 exports are the knobs.

Result: **PASS (automated)**.

**Known limitations:**

- No combo yet — a second attack press mid-swing is ignored (buffering arrives with Sprint 06).
- No hit feedback beyond the event: hitstop/VFX/sound land in Sprint 15; target reactions in Sprint 13.
- The boss is a static capsule; it neither reacts nor retaliates until Sprints 10+.
- Attack during dodge recovery is blocked for now (Sprint 09 owns transition rules).

**Check-harness note:** two false alarms were hit while building the check — walking up to the boss stalls against its collision and freezes facing (yaw is now snapped directly; facing mechanics are movement_check's job), and the idle gap between swings is shorter than a poll tick, so swing counting uses the `state_changed` signal with global physics-frame stamps. Both recorded here for future check authors.

**Next:** Sprint 06 — Combo Chain: 3–4-hit chain from combo data, input buffering, chain windows, reset conditions. Plan+scope first.

---

---

## 005 · 2026-09-28 · Hitbox / Hurtbox Foundation (Sprint 04)

**Goal:** Create the reusable combat collision layer — hitbox components deliver structured damage events to hurtbox components, with team filtering and debug visualization — so every later attack (player, boss, magic) reuses one system.

**Scope:** new `game/scripts/combat/` (`combat_types.gd`, `damage_event.gd`, `hitbox_component.gd`, `hurtbox_component.gd`), new `game/scripts/debug/combat_debug.gd` (static toggles), player + boss placeholder scenes gain real hurtboxes, debug overlay syncs the combat-shape toggle, new `tools/validation/combat_check.gd`, smoke check list extended.
**Non-goals:** health components (boss health is Sprint 10), the player's actual attack hitbox (Sprint 05), hit reactions/stagger (Sprint 13), block interaction (Sprint 08/09).

**Decisions:**

- **D-013:** Physics layer plan — layer 1 world, 2 player body, 3 boss body, 4 player_hurtbox, 5 boss_hurtbox (named in `project.godot`). Hitboxes carry no layer and mask only the opposite faction's hurtbox layer; a code-side faction check remains as defense-in-depth ("invalid self-hits are ignored" holds even under misconfiguration).
- **D-014:** `DamageEvent` (RefCounted) is the only sanctioned way damage intent crosses actors: `source`, `amount`, `stagger_damage`, `knockback`, `hit_type` (NORMAL/HEAVY/SPECIAL per the docs' attack categories), `attack_id`, `status_effect` (placeholder field, no behavior). Hitboxes create events; hurtboxes resolve them and emit `damaged`/`damage_blocked` — receivers stay separate from attackers (guide §6).
- **D-015:** Immunity is receiver-side: a hurtbox walks its owner chain and calls `is_invulnerable()` when the actor defines it. This wires Sprint 03's dodge i-frames into real damage prevention — verified in this sprint's check.
- **D-016:** Debug visualization uses a static `CombatDebug` toggle (no autoload, safe in `-s` headless scripts). F1 debug mode now toggles the overlay and combat shapes (red = active hitbox, green = hurtbox) together.
- **D-017 (revises D-005):** gdUnit4 integration deferred to Sprint 10 (boss state machines — first large pure-logic surface). Rationale: the SceneTree runtime checks are deterministic, headless, and CI-shaped; the addon will be integrated once, deliberately, with version compatibility validated. flagged for the user to veto.

**Roadmap checklist coverage:** player-faction hit damages test target · same-faction hits ignored (layer + code filter) · two overlapping hitboxes deliver exactly one event each per activation · debug mode shows active areas · dodge i-frames block a hit → all in `combat_check.gd`.

**Implemented:**

- `combat_types.gd` — `Faction`, `HitType`, layer/mask mapping helpers.
- `damage_event.gd` — structured payload per D-014.
- `hurtbox_component.gd` — passive receiver, immunity check up the owner chain (D-015), `damaged`/`damage_blocked` signals, green debug shape.
- `hitbox_component.gd` — active-window attacker: masks opposing faction, dedups one hit per target per activation via both `area_entered` and a per-tick sweep, red debug shape visible only while active.
- `combat_debug.gd` — static toggle; F1 debug mode = overlay + combat shapes together.
- `player.tscn`/`boss_placeholder.tscn` — real hurtboxes (capsule, faction PLAYER/BOSS); `project.godot` names the five physics layers.
- `tools/validation/combat_check.gd` — runtime sandbox asserting the full checklist; smoke check extended to the new combat scripts.

**Files changed:** the above plus `debug_overlay.gd`, `smoke_check.gd`, `.uid` sidecars.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 11 resources, main scene instantiates)
- [x] Combat check — PASS:
  - player-faction hitbox → boss-faction target: exactly one event with the full payload intact (amount, stagger, knockback, attack_id, source, hit_type)
  - second activation hits exactly once again (dedup resets per activation)
  - same-faction hurtbox overlapped by the hitbox: zero events (physics layer + code filter)
  - two overlapping hitboxes: exactly 2 events, combined damage 13.0
  - invulnerable owner: 0 damaged + reported via `damage_blocked`; toggling off: exactly 1 event — Sprint 03 dodge i-frames are now combat-wired
  - debug shapes: hitbox shape visible only while active; hurtbox shape present
- [x] Movement check regression — PASS (travel 4.73 m, dots 1.00, drift 0.000)
- [x] Dodge check regression — PASS (peak 12.0 m/s, spam commitment held, boss slide 3.23 m)
- [x] Main scene 180 frames headless — zero errors
- [ ] Visual check of the red/green shapes and controller feel — deferred to the user's playtest session (F1 toggles debug mode).

Result: **PASS (automated)**.

**Known limitations:**

- No receivers yet: nothing consumes `damaged` (HealthComponent arrives with the boss framework, Sprint 10; player HP later).
- The player has no attack hitbox yet — Sprint 05 (Light Attack) creates the first real one and consumes this layer.
- Hit feedback (VFX/sound) is Sprint 15.

**Next:** Sprint 05 — Light Attack: attack state with startup/active/recovery consuming a player-faction HitboxComponent, first damage numbers, hit reaction hook. Plan+scope first.

---

## 004 · 2026-09-28 · Dodge (Sprint 03)

**Goal:** Add fast, committed dodge movement — a repositioning/escape tool constrained by commitment so input mashing can never become permanent invulnerability.

**Scope:** `game/scripts/player/player_controller.gd` (DODGE + DODGE_RECOVERY states, timers, invulnerability window, `is_invulnerable()`), `game/scripts/debug/debug_overlay.gd` (dodge/recovery timer + i-frame display — "recovery is observable in debug output"), new `tools/validation/dodge_check.gd` headless verification.
**Non-goals:** dodge cancels/interaction with block and attack (Sprint 09 integration), input buffering (Sprint 06), air dodge (post-MVP mobility ability), damage system consuming `is_invulnerable()` (Sprint 04 wires that), authored animations.

**Roadmap checklist coverage:** dodge faster than walking / intended direction / recovery not bypassable by repeated input / recovery vulnerable / recovery observable in debug / no boundary tunneling / dodge around the boss → all covered by `dodge_check.gd` except final feel, which stays a manual check.

**Decisions:**

- **D-010:** Dodge parameters (documented starting points, all exports): travel **0.25 s at 12 m/s ≈ 3 m**; invulnerability **first 0.15 s of travel** (tuned separately from travel duration, per docs); recovery **1.0 s** per architecture §6 ("initially around one second"). Horizontal velocity is zeroed at travel→recovery transition so the burst ends cleanly (no skid). *Tuning watch: if the playtest feels sluggish, `dodge_recovery` is the first knob.*
- **D-011:** Direction selection: held movement input (camera-relative); **neutral dodge = backward relative to camera**; grounded only — air dodge is post-MVP.
- **D-012:** Commitment model: recovery state ignores input and cannot be re-dodged until it completes; i-frames exist **only** inside the travel window — recovery is always vulnerable. The future damage system queries `is_invulnerable()`; no HP logic exists yet, so this sprint proves the timing geometry.

**Implemented:**

- `player_controller.gd`: `DODGE` (travel burst, exactly `dodge_duration` at `dodge_speed`, direction from held input or camera-backward when neutral, grounded only) and `DODGE_RECOVERY` (committed, input ignored, always vulnerable). `is_invulnerable()` is true only while `state_elapsed < dodge_invulnerability` inside travel. State transitions centralized in the `state` setter (resets `state_elapsed`, emits, plays animation hooks `dodge_start`/`dodge_recover`). Horizontal velocity zeroed at travel→recovery so the burst stops cleanly with no skid.
- `debug_overlay.gd`: shows remaining dodge/recovery time and an `i-frames ACTIVE` line — the roadmap's "recovery is observable in debug output".
- `tools/validation/dodge_check.gd`: headless check driving the real arena scene with synthesized input.

**Files changed:** `game/scripts/player/player_controller.gd`, `game/scripts/debug/debug_overlay.gd`, `tools/validation/dodge_check.gd` (+ `.uid`), `worklog.md`.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 6 resources, main scene instantiates)
- [x] Movement check (Sprint 02 regression) — PASS: travel 4.73 m, direction dot 1.00, facing dot 1.00, drift 0.000 m/s
- [x] Dodge check — PASS:
  - faster than walking: peak **12.0 m/s** vs 5.0 m/s walk
  - neutral dodge: ~3 m camera-backward, dot > 0.8
  - i-frames present at dodge start and cleared before travel ended
  - input spam (~3.7 s): 3 dodge entries, **all gaps ≥ 70 ticks** (75-tick commitment) — mashing cannot re-dodge or chain i-frames
  - `DODGE_RECOVERY` observed and vulnerable throughout (no i-frames)
  - dodge slid past the boss placeholder: 3.23 m lateral, unblocked
  - dodge into the arena boundary held the clamp (no tunneling)
- [x] Main scene runs 180 frames headless, zero errors — PASS
- [ ] Dodge *feel* (speed, recovery length, i-frame generosity) — **deferred to user's playtest session**; D-010 flags `dodge_recovery` (1.0 s, the documented starting value) as the first knob if it feels sluggish.

Result: **PASS (automated)** — per the user, manual feel validation is deferred to a later playtest session.

**Known limitations:**

- No dodge animation yet — `dodge_start`/`dodge_recover` hooks no-op until the art pass.
- No damage system exists, so i-frames are timing-proven but not yet combat-proven; Sprint 04's hurtbox consumes `is_invulnerable()`.
- Dodge has no input buffering near recovery end (deliberate; combo buffering lands in Sprint 06).
- Air dodge intentionally excluded (post-MVP mobility).

**Next:** Sprint 04 — Hitbox/Hurtbox Foundation: reusable Hurtbox/Hitbox components, DamageEvent payload, team filtering, hit registration, debug visualization. Plan+scope first.

---

## 003 · 2026-09-28 · Player Controller (Sprint 02)

**Goal:** Make the gladiator's movement feel responsive and controlled before any combat exists — acceleration/deceleration, rotation toward movement, gravity, arena-boundary handling, and basic animation hooks.

**Scope:** `game/scripts/player/player_controller.gd` (rewrite of the Sprint 01 raw movement), `game/scripts/debug/debug_overlay.gd` (show player state), new `tools/validation/movement_check.gd` (headless automated verification of the roadmap's testable checklist items).
**Non-goals:** dodge (Sprint 03), attacks, real animation assets (art pass, Sprint 12/18 — hooks only), real Colosseum walls (Sprint 17), camera feel tuning beyond Sprint 01's rig.

**Roadmap checklist coverage:**

- "Movement is responsive" / "Player does not slide uncontrollably" / "Player cannot leave the arena" / "Controller input is consistent" → automated via `movement_check.gd` (moves in the camera-relative direction at target speed, stops without drift after input release, faces movement direction, arena clamp holds) + manual controller feel check by user.
- "Basic animation hooks" → player exposes a `State` enum (IDLE/MOVE/AIRBORNE), `state_changed` signal, and a `play_animation()` helper that no-ops until an AnimationPlayer with matching animations exists.

**Decisions:**

- **D-007:** Initial tuning values (starting points, tuned further in playtesting/Sprint 16): `movement_speed = 5.0`, `acceleration = 40.0`, `deceleration = 50.0` (brakes harder than it accelerates — no drift after input release), `turn_speed = 12.0` (exponential lerp toward movement yaw). All are `@export`s, not hard-coded.
- **D-008:** Animation hook approach: state enum + signal + `play_animation(name)` guard helper; a subtle code-driven "lean into movement" placeholder on the Visual node gives visible responsiveness without authored animations. Real animation naming follows guide §16 (`idle`, `run`, …).
- **D-009:** Facing rotates the player root yaw (`lerp_angle`); collision capsule is symmetric so gameplay is unaffected, and camera-relative movement is independent of body facing.

**Environment:** Remote `origin` added — https://github.com/jamesdileva/FIRSTBLOOD (public, created via `gh`). All Sprint 00/01 commits pushed. Push now happens every verified commit per the sprint loop.

**Implemented:**

- `player_controller.gd` rewritten: camera-relative direction, `move_toward` acceleration/deceleration (D-007), yaw facing via `lerp_angle` (D-009), gravity, arena-bound clamp (now `@export arena_half_extent`), `State` enum + `state_changed` signal + `play_animation()` hook + placeholder lean (D-008). All tuning values are exports.
- `debug_overlay.gd` shows the player state (IDLE/MOVE/AIRBORNE).
- `tools/validation/movement_check.gd` — headless check that synthesizes input, drives the real arena scene, and asserts the roadmap's testable checklist.

**Files changed:** `game/scripts/player/player_controller.gd`, `game/scripts/debug/debug_overlay.gd`, `tools/validation/movement_check.gd` (+ `.uid`), `worklog.md`.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 input actions, 6 resources, main scene instantiates)
- [x] Movement check — PASS: travel 4.73 m in 60 frames (≈ target 5 m/s after accel ramp), direction dot 1.00 (exact camera-relative), facing dot 1.00 (body faces movement), drift 0.000 m/s after release, arena clamp holds
- [x] Main scene runs 180 frames headless, zero errors — PASS
- [ ] "Movement feels good" + controller consistency — **manual, pending user playtest** (Gate A input; tuning values in D-007 are starting points)

Result: **PASS (automated)** — feel confirmation belongs to the user's controller session.

**Known limitations:**

- No authored animations yet — `play_animation("idle"/"run"/"airborne")` no-ops until an AnimationPlayer exists (art pass).
- Arena boundary is still a soft clamp; walls arrive in Sprint 17.
- Camera pitch/height not yet user-facing exports beyond distance; revisit in Sprint 16 tuning lab.

**Next:** Sprint 03 — Dodge: dodge state, direction selection, movement burst, completion requirement, recovery vulnerability, animation hook. Plan+scope first.

---

## 002 · 2026-09-28 · Godot / Rendering Spike (Sprint 01)

**Goal:** Prove the technical foundation — a launchable Godot project with placeholder arena, player and boss placeholders, basic third-person camera, controller input map, and debug overlay.

**Scope:** `project.godot` (engine config, full input map), `game/scenes/arena/arena.tscn` (main scene), `game/scenes/player/player.tscn`, `game/scenes/bosses/boss_placeholder.tscn`, `game/scripts/player/player_controller.gd` (raw input-to-movement placeholder), `game/scripts/camera/third_person_camera.gd`, `game/scripts/debug/debug_overlay.gd`, `tools/validation/smoke_check.gd` (headless verification), `.gdignore` conventions.

**Non-goals:** tuned movement feel (Sprint 02), dodge (03), combat systems (04+), real Colosseum geometry (Sprint 17), gdUnit4 integration (deferred — see D-005).

**Environment — D-003 resolved (engine pin):**

- Godot **4.7.2 stable** confirmed installed via winget (`GodotEngine.GodotEngine`).
- Binary: `C:\Users\j\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe`
- Invoke as `godot` in cmd/PowerShell (shim: `%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.cmd`). From Git Bash use `cmd //c godot ...` — bash `which` cannot resolve `.cmd` shims, which is why Godot appeared missing from PATH.
- Cross-check: the user's other Godot project `surfhop` ("Velocity") also targets Godot 4.7 — the engine is proven working on this machine.

**Decisions:**

- **D-003 (resolved):** Engine pinned to Godot 4.7.2 stable. Matches `docs/needs-review(...)` §18 ("4.7.2 is current stable") and the user's existing 4.7 project.
- **D-005:** gdUnit4 integration deferred to Sprint 04 (where the first pure-logic combat tests arrive). Sprint 01 headless validation uses a lightweight `smoke_check.gd` SceneTree script instead. Rationale: no unit-testable logic exists yet; avoids addon setup risk before the engine version is exercised.
- **D-006:** MVP input map defined per implementation-guide §2/§3: WASD/left-stick movement, J/X-button attack, K/LT block, L/B-button dodge, Esc/Start pause, F1 debug toggle, right-stick camera actions, and the post-MVP `spell_modifier` (LB) + `spell_a/b/x/y` actions defined now but unused, exactly as the guide specifies. No gameplay code reads physical buttons.

**Implemented:**

- `project.godot` — Godot 4.7.2 / Forward Plus, 1280×720, main scene, 18 input actions.
- `game/scenes/arena/arena.tscn` — placeholder arena: floor + collision, sun with shadows, environment, spawn markers, Player/Boss placeholders, camera rig, debug overlay.
- `game/scenes/player/player.tscn` — CharacterBody3D capsule (blue) with facing indicator; `game/scenes/bosses/boss_placeholder.tscn` — StaticBody3D capsule (red).
- `game/scripts/player/player_controller.gd` — camera-relative input-to-movement, gravity, temporary arena-bound clamp. Deliberately raw; Sprint 02 tunes feel.
- `game/scripts/camera/third_person_camera.gd` — smoothed follow + right-stick orbit/pitch.
- `game/scripts/debug/debug_overlay.gd` — FPS, player position/speed, boss distance; F1 toggle; auto-hidden in headless.
- `tools/validation/smoke_check.gd` — headless SceneTree script validating input map + resource loads + main-scene instantiation.
- `.gdignore` in `assets/blender/` and `docs/` so Godot never imports sources/docs.

**Files changed:** the above plus `icon.svg`.

**Verification:**

- [x] Headless import (`godot --headless --path . --import`) — PASS, exit 0, no errors
- [x] Smoke check (18 input actions, 6 resources, main-scene instantiation) — PASS
- [x] Main scene runs 180 frames headless with zero script/runtime errors — PASS
- [x] Project launches cleanly (headless run; GUI launch pending user's first open) — PASS
- [ ] Controller moves the player — **manual, pending user with gamepad** (input map verified programmatically; WASD keyboard fallback wired)
- [ ] Camera follows correctly / right-stick orbit — **manual, visual check pending**
- [ ] Performance target on dev hardware — **manual, needs a real display** (placeholder scene is trivially light)

Result: **PASS (automated)** — manual controller/camera/performance checks remain for the user.

**Notes / known limitations:**

- Movement feel is intentionally untuned (Sprint 02's job); attack/block/dodge actions exist in the input map but do nothing yet, matching the roadmap.
- Arena boundary is a soft position clamp until Sprint 17 adds real walls.
- Godot 4.7 generated `.gd.uid` sidecar files for scripts — committed as source metadata.
- **User action:** open the project in Godot (`godot` from cmd, or the project folder), plug in a controller, and confirm movement + camera; then Sprint 02 can start.

**Next:** Sprint 02 — Player Controller: tuned acceleration/deceleration, rotation toward movement, arena boundary handling, basic animation hooks. Start with a plan+scope entry.

---

## 001 · 2026-09-28 · Docs Review + Repository Bootstrap (Sprint 00)

**Goal:** Review the design suite, establish repo best practices, and prepare for Sprint 01.

**Done:**

- Reviewed all four documents in `docs/`.
- Created `AGENTS.md` — the working contract: mandatory sprint loop, MVP guardrails, Godot/GDScript conventions, testing rules, git rules.
- Created `README.md` — project overview, status, stack, sprint workflow.
- Created this `worklog.md` with the entry template.
- Added `.gitignore` (Godot 4, Blender backups, OS junk).
- Initialized git repository and committed the baseline (docs + scaffolding).

**Review findings (docs):**

- Overall plan is strong: small sequential sprints, verification-first advancement, a frozen MVP boundary, and the critical guardrail "if combat isn't fun by Sprint 16, stop adding content and fix combat."
- `needs-review(has details other docs dont).md` is the raw generator/source draft. It **contains details missing from the clean docs**: Godot 4.7.x (4.7.2) engine pin, Forward+ renderer recommendation, `camera_*` input actions and `attack_heavy`, block recovery tuned at 0.75–1.0 s, the structured `DamageEvent` payload, `ComboDefinition`/`ComboStep` data, save-file versioning for migration, `CHR_/BOS_/ENV_/WPN_/ANM_` asset naming, and a per-boss "combat question" table. Recommendation: mine these into the three clean docs, then archive the file.
- Naming conflict: `implementation-guide.md` §18 uses `Boss_Minotaur` / `Anim_Attack_01` while the raw draft uses `BOS_Minotaur` / `ANM_Player_Light01`. → See D-001.
- No test framework is named anywhere, yet the roadmap demands tests every sprint and `tests/` folders exist in the planned tree. → See D-002.
- Blender source files will sit *inside* the Godot project (`assets/blender/`) → must get a `.gdignore` when the Godot project is created at Sprint 01, or Godot will try to import them.
- Engine version differs between docs: architecture says "4.x validated at init"; the raw draft says 4.7.x. → Validate and pin one version at Sprint 01 (D-003 pending).

**Decisions:**

- **D-001:** Asset naming uses the prefix scheme (`CHR_`, `BOS_`, `ENV_`, `WPN_`, `PROP_`, `ANM_`). Rationale: machine-parseable names are required by the Sprint 48 naming-validation automation; the guide §18 examples remain readable under the scheme. Recorded in `AGENTS.md`.
- **D-002:** Automated tests use **gdUnit4** (validate at Sprint 01; GUT is the fallback). Rationale: headless CLI runner, active Godot 4 support, works in CI.
- **D-003 (pending):** Engine pin — validate the current stable Godot 4.7.x at Sprint 01 and record it here.
- **D-004:** The sprint loop (plan+scope → implement → verify → commit+push → worklog) is codified in `AGENTS.md` and applies to every sprint.

**Open items:**

- Git remote is not configured — push is pending a remote URL from the user.
- `needs-review(...)` file: rename to something sane (e.g. `docs/archive/source-draft.md`) after mining its unique details into the clean docs. User call.
- Light attack chain length (3 vs 4 hits) is deliberately open — tune at Sprint 06.
- Exact controller mapping — tune during Sprints 01–03 as the docs intend.

**Next:** Sprint 01 — Godot/Rendering Spike: create the Godot project (pin engine, `.gdignore` blender sources), configure display/input map, placeholder arena + player + boss, third-person camera, controller verification, debug logging. Start the entry with plan+scope before implementing.

---

## Entry Template

Copy this for every new entry (newest at top):

```text
## NNN · YYYY-MM-DD · <Title> (Sprint NN)

**Goal:** one sentence.

**Scope:** files/areas planned to change.
**Non-goals:** what is explicitly out of this sprint.

**Implemented:**
- ...

**Files changed:**
- ...

**Verification:** (sprint checklist + guide §31 template)
- [ ] item — PASS/FAIL

Result: PASS / FAIL

**Decisions:** D-NNN: what and why.
**Known limitations:** ...
**Next:** ...
```
