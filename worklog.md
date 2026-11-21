# Worklog — Boss Arena Gladiator

Append-only sprint log. **Newest entry first.** One entry per sprint (or per meaningful session).
Never rewrite past entries — corrections go into a new entry. Decisions get stable IDs (`D-NNN`).

The entry template is at the bottom of this file.

---

## 028 · 2026-11-13 · Gear Framework (Sprint 26, post-MVP)

**Goal:** Equippable gear data with stat modifiers that change player stats and persist correctly — gear can be added without rewriting player combat (roadmap Sprint 26, guide §24).

**Scope:** new `GearData`/`GearCatalog` resources (guide §24 fields minus the explicitly-post-MVP `elemental_effects`/`set_id`) + a starter 4-piece catalog; new `GearLibrary` static (session loadout ↔ save); new `EquipmentComponent` on the player (one piece per slot, swap-on-equip); player stat composition joins level stats + gear totals (D-066 path extended, not replaced); armor soaks unblocked incoming damage at the `_resolve_incoming_damage` hook; `progression.save()` becomes read-merge so the shared save file keeps per-system keys; a minimal Armory screen off the title (new `armory` action: G / gamepad Y) as the equip affordance; new `gear_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** gear sets, elemental effects, weapon variants (Sprint 27's separate sprint), in-fight equip UI, gear art, drop/loot systems.

**Decisions (planned):**

- **D-079 (gear is data with string slots):** `GearData` carries `slot` (StringName: HEAD/BODY/HANDS/FEET) plus flat bonuses matching the level-stat units (hp, armor, attack, movement, attack-speed fraction). The EquipmentComponent enforces one piece per slot; equipping into an occupied slot swaps. Adding a piece = adding a resource to the catalog — zero combat-code changes.
- **D-080 (shared save file, per-system keys):** the loadout lives in a `GearLibrary` static (the D-077 precedent) synced to `user://save.json`'s new `equipment` key. One file, many owners: every writer read-merges, so `progression.save()` (fixed this sprint) preserves the gear key and gear saves preserve XP/level. Version stays 1 — the key is additive; old saves load with an empty loadout.
- **D-081 (armor = flat soak, floor 1):** unblocked incoming damage loses `armor` points (floored at 1 so nothing becomes a total negate); blocked NORMAL hits still fully negate; a block-mitigated heavy takes the multiplier first, then the soak. Applied at the player's single damage-resolution hook — never by mutating HP directly (the DamageEvent stays the only payload).

**Verification (planned):** `gear_check.gd` — catalog integrity (unique slots, non-negative bonuses), aggregation math + slot swap, player stat composition (max health, attack payload bonus, armor soak on a resolved DamageEvent), persistence round-trip through the check save + the progression-save merge safety, and the real path title → armory (G) → equip → Esc → title → fight → the spawned player wears the loadout. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-13)*

- `gear_data.gd` + `gear_catalog.gd` — the data layer per guide §24 (minus `elemental_effects`/`set_id`, explicitly post-MVP): id, display name, string slot, flat bonuses in the level-stat units, plus a `summary()` one-liner for the armory. `game/resources/gear/` holds the starter catalog: Trainee's Cap (HEAD, HP+6), Legion Cuirass (BODY, HP+12/Armor 1), Wrist Wraps (HANDS, ATK+2), Sprinter's Sandals (FEET, SPEED+0.3/SWING+2%).
- `gear_library.gd` — static loadout (D-080): session holder ↔ the save's `equipment` key, read-merge both ways; unknown ids resolve to nothing (a removed piece never crashes a load).
- `equipment_component.gd` — one piece per slot, swap-on-equip, on-demand totals, `equipment_changed`; applies the GearLibrary loadout at ready and mirrors every change back into it + the save. The armory uses a headless staging component as its editor — the slot-swap logic exists once.
- `player_controller.gd` — `_apply_level_stats` became `_recompute_stats` (level part + gear part); level-ups and equipment changes both route through it, so neither wipes the other; max-health shrink clamps current HP. Armor soaks unblocked incoming damage at `_resolve_incoming_damage` (D-081: floor 1; blocked normals still fully negate; blocking heavies takes multiplier-then-soak).
- `progression_component.gd` — `save()` is now read-merge so the shared save file keeps per-system keys (D-080); the equipment key is additive, old saves load with an empty loadout, version stays 1.
- `armory.tscn`/`armory.gd` — the equip affordance off the title (new `armory` action: G / gamepad X): one row per piece (name, stat summary, WORN tag, gold highlight), ui_up/ui_down navigate, start_match wears/removes, ui_cancel back; a totals line sums the worn modifiers.
- `tools/validation/gear_check.gd` — the five-phase check; smoke list +13 paths and the `armory` action.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Gear check — **PASS** (one run failed first: the check's own expected-value arithmetic forgot the wraps contribute attack, not HP — 32 is correct after the HEAD swap; the code was right). Catalog integrity, aggregation + slot swap + is_equipped, player composition (100 → 112 HP, attack payload +2), armor soak 10→9 and the floor at 1, level-up preserves gear (2×2+2=6), loadout round-trip, progression-save merge keeps the gear key, unknown ids resolve harmlessly, and the real path title → armory → equip → title → fight spawns a player wearing the loadout at 112 max HP
- [x] Full sweep — **all 23 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Armory *feel* (row readability, toggle responsiveness) and combat impact of armor/attack gear — the user's next batch session

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- Twice now, prepending a worklog entry by matching the previous entry's HEADER ate that header — the fix is to anchor the edit on the previous entry's TAIL (its last paragraph) instead. (Applied this sprint; noted so the next agent doesn't rediscover it.)
- The gear check's first failure was its own expected-value arithmetic (34 vs 32) — when an assert fails, recompute the expectation before touching the code.

**Known limitations:**

- The armory is the only equip path (between fights, no player alive); in-fight swapping has no UI and no stat-change moment mid-combat.
- No gear acquisition yet — the four starter pieces are the whole catalog; drops/purchases are future work.
- Armor is a flat soak (floor 1); percentage mitigation can come later if builds need it.

---

## 029 · 2026-11-13 · Weapon Variants (Sprint 27, post-MVP)

**Goal:** Different weapons change attack behavior (their own combo data) and visuals, with no controller bloat — gear can be added without rewriting player combat, and weapons are no exception (roadmap Sprint 27).

**Scope:** new `WeaponData` (extends `GearData`, slot `WEAPON`: carries a `ComboData` + blade color/length); three weapons in the catalog (the Dull Sword = the current default combo, a Legion Gladius = heavier swings, a Trainer's Spear = lighter/faster, longer blade); two new combo resources; a primitive `WeaponBlade` mesh on the player tinted/scaled per weapon; one weapon application point in the player controller (`_apply_weapon()`); gear_check's slot-uniqueness assertion learns that WEAPON holds alternatives; new `weapon_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** per-weapon hitbox reach/geometry (data-only variants this sprint), weapon art models, weapon-specific animations, drops/acquisition, two-handed stances.

**Decisions (planned):**

- **D-082 (a weapon is gear that carries behavior):** `WeaponData extends GearData` — the armory rows, the one-per-slot swap, and the save persistence all reuse the Sprint 26 framework with zero new UI or save code. The player has a single application point (`_apply_weapon()`): equipped WEAPON → its `combo` + visuals; nothing else in the controller changes. The compact combat model holds — same buttons, different data.
- **D-083 (default-first):** no weapon equipped = the scene-assigned combo (`player_light_combo.tres`) and the dull-sword visuals — every existing check and the current feel are untouched; the Dull Sword resource references the default combo explicitly for self-documentation.
- **D-084 (variants are pure data):** gladius (damage +2 per swing, slightly heavier recoveries) and spear (lighter/faster, longer visual blade) are resource-level tunes of the same combo shape. Hitbox reach stays out of scope — behavior means damage/stagger/timings this sprint.

**Verification (planned):** `weapon_check.gd` — catalog integrity (≥2 WEAPON pieces, each combo resolves with steps + finisher), behavior (default → weapon → default combo reference swap, payload damage from the weapon's own step data), visuals (blade tint + length follow the weapon, restore on unequip), and the real path armory → equip spear → fight → the spawned player swings the spear's combo with the spear's blade. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-13)*

- `weapon_data.gd` — `WeaponData extends GearData` (D-082): `combo: ComboData`, `visual_color`, `blade_length`; `summary()` appends the damage chain ("swings 12/14/16/28 F").
- `game/resources/weapons/` — Dull Sword (the default combo, explicitly referenced), Legion Gladius, Trainer's Spear; `game/resources/attacks/` gains `gladius_light_combo.tres` (+2 damage/swing, +0.02–0.03 s recoveries) and `spear_light_combo.tres` (−2 damage/swing, faster startups). Catalog updated to 7 pieces.
- `player.tscn` — a primitive `WeaponBlade` BoxMesh beside the body (the prototype-visual language).
- `player_controller.gd` — `_default_combo` captured at ready; `_apply_weapon()` is the single application point (D-082/083): equipped WEAPON → its combo + blade tint/length; anything else restores the default. Wired into `_ready` and `_on_equipment_changed`.
- `gear_check.gd` — the slot-uniqueness assertion now exempts `WEAPON` (alternatives legitimately share it); `weapon_check.gd` new; smoke list +6 paths.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Weapon check — **PASS first run**: catalog integrity (3 weapons, every combo resolves with steps + finisher), the Dull Sword references the default combo, default → gladius → default combo-reference swap, the gladius payload carried from its own step data (12.0), blade tint + length follow and restore (steel-blue ×0.9 ↔ default grey ×1.0), and the real path armory → equip the spear → fight spawns a player on the spear's combo with the spear's blade
- [x] Gear check regression — PASS (7-piece catalog, weapons in the armory)
- [x] Full sweep — **all 24 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Weapon *feel* (gladius vs spear pacing, damage readability) — the user's next batch session

Result: **PASS (automated)**.

**Known limitations:**

- Reach is visual only (blade length) — the hitbox geometry is shared; per-weapon reach is a future behavior change if builds want it.
- Weapon-specific animations/models are art-pass work; all weapons share the placeholder swing set.

---

## 030 · 2026-11-16 · Mana (Sprint 28, Phase 12 opener)

**Goal:** A reliable mana subsystem — mana decreases on use and regenerates after the configured delay (roadmap Sprint 28; architecture §14: "exact values are tuning decisions").

**Scope:** new `ManaComponent` (atomic spend, regen delay set on every spend, flat regen rate after the delay — all exports on the player scene); the player gains the Mana node and `reset_for_retry` refills it; the HUD gains a mana bar (the D-069 poll pattern) and the F1 debug overlay a Mana line; new `mana_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** spell consumers (Sprint 29's four-slot input + Sprint 30's spell pool), mana costs per spell, persistence (mana is per-fight state like HP), UI polish.

**Decisions (planned):**

- **D-085 (atomic spend + delayed flat regen):** `spend()` is all-or-nothing (no partial spends, no negative mana); every spend resets the regen-delay timer; after the delay, mana regenerates at a flat rate per second until full. Values (max 100, delay 3.0 s, rate 20/s) are exports on the player scene — the docs leave them to tuning.
- **D-086 (a subsystem with observability, no spender yet):** nothing consumes mana this sprint — the consumers are Sprint 29's input mapping and Sprint 30's spells. So the sprint ships *observable* mana: the F1 overlay shows current/max + regen state, and the HUD gains the mana bar so the player-facing surface exists before the first spell does. Playtesting.md explains the bar sits full until then. R-retry refills mana (the D-058 full-reset semantics).

**Verification (planned):** `mana_check.gd` — API math (spend true/false, no over-spend), the delay honored (no regen inside the window, flat-rate regen after it, clamp at max), the real player's component (retry refills), and the HUD bar tracking through a spend→delay→regen cycle. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-16)*

- `mana_component.gd` — `ManaComponent` (D-085): atomic `spend()` (all-or-nothing, `is_available()` for future spells), the regen delay set on every spend, flat-rate regen after the delay with a clamp at max (the D-068 poll), `mana_changed`/`mana_spent` signals, and `reset()` for the D-058 retry semantics. Values are exports on the player's `Mana` node (max 100, delay 3.0 s, rate 20/s — the docs' tuning-decision slot).
- `player.tscn` gains the `Mana` node; `reset_for_retry()` refills it.
- `hud.tscn`/`hud.gd` — a blue `ManaBar` under the XP bar, polled like every other HUD value (D-069); `debug_overlay.gd` — a `Mana: 100/100 (full|regening)` F1 line (D-086: the subsystem ships observable, with its spenders arriving in Sprints 29/30).
- `tools/validation/mana_check.gd` — the four-phase check; smoke list +1 path.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Mana check — **PASS first run**: atomic spend math (30 true, 80 over-spend false and unchanged, 0-cost true), `is_available` boundary, the player pool spawns full, NO regen inside the 1.67 s window, ~+10 after 0.5 s of post-delay regen (20/s confirmed), full refill + clamp, retry refill, and the HUD bar tracking a spend→delay→refill cycle with the component's max
- [x] Full sweep — **all 25 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Mana *feel* — deferred with the rest of the batch; nothing consumes the pool until Sprint 29/30

Result: **PASS (automated)**.

**Known limitations:**

- No mana spender exists yet (by design — D-086); the first real cost arrives with the Sprint 30 spell pool.
- Regen is flat; the docs' later spells could want burst/weighted regen — a tune, not a rewrite.

---

## 031 · 2026-11-16 · Four-Slot Spell Input (Sprint 29, Phase 12)

**Goal:** LB + A/B/X/Y resolves four equipped spell slots, reliably, without breaking melee controls (roadmap Sprint 29; guide §25's MagicLoadout shape).

**Scope:** new `SpellData` resource (id, display name, mana cost, effect key); the Arcane Spark placeholder spell (mana-only — the Sprint 30 pool replaces it with real effects); new `MagicComponent` on the player (four slot exports, mana-gated cast, `spell_cast` signal, effect dispatch stub); the LB-gate in the player's neutral-state input handling (modifier held → the spell layer owns the face press); F1 loadout line; new `spell_input_check.gd` (real joypad events); smoke list; TUNING.md; playtesting.md.
**Non-goals:** real spell effects (Sprint 30's pool: heal/reflect/fire/freeze), spell equip UI/library (arrives with multiple spells), casting from attack/block/dodge/airborne states, cast animations, HUD slot indicators.

**Decisions (planned):**

- **D-087 (the modifier owns the press):** LB held + a face button = the spell layer consumes that press — the cast happens, or nothing does (a mana-short cast never becomes a surprise sword swing). LB up → the same buttons remain attack/dodge/block untouched. The gate lives in the neutral-state handler only: committed actions (attack/block/dodge) stay committed, and casting from other states is a future tune.
- **D-088 (slots are data, effects are dispatch):** `MagicComponent` holds the four `SpellData` exports (the guide's MagicLoadout) and resolves each cast through the ManaComponent's atomic `spend()`; the spell's `effect` key dispatches to implementations — Sprint 29 ships only the spark no-op, Sprint 30 fills the dispatcher with the real pool.

**Verification (planned):** `spell_input_check.gd` — loadout integrity (four assigned slots, cost > 0), the cast path (mana drops by the cost, empty slot false, mana-short false with no spend), real joypad input (LB+A/B/X/Y each casts exactly once per press; LB up → a face press does nothing), and melee coexistence (casting is rejected mid-attack and works again after recovery). Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-16)*

- `spell_data.gd` — `SpellData` (D-088): id, display name, `mana_cost`, and an `effect` dispatch key; `game/resources/magic/spell_arcane_spark.tres` is the Sprint 29 placeholder (cost 10 — the mana spend IS its effect until Sprint 30's pool).
- `magic_component.gd` — the four slot exports (guide §25's MagicLoadout) + `cast_slot()`: resolve the slot → the sibling ManaComponent's atomic `spend()` → `spell_cast` → the effect dispatcher (spark = no-op; unknown keys warn). `loadout_debug()` feeds F1.
- `player.tscn` gains the `Magic` node with all four slots assigned the spark; `player_controller.gd` gains the D-087 gate at the top of the ground-neutral input branch: LB held → `_spell_slot_pressed()` → cast (or consume the press); LB up → melee inputs untouched. Committed states (attack/block/dodge) never reach it.
- `debug_overlay.gd` — `Spells: A=ARCANE SPARK(10) B=... X=... Y=...` line.
- `tools/validation/spell_input_check.gd` — real joypad events (LB=9, faces 0-3); smoke list +3 paths.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Spell input check — **PASS** (first run failed on three CHECK bugs, not engine bugs: the mana-short arithmetic ignored that `spend()` is atomic — 85 bounced off a pool of 80; the bare instantiation never landed so the player hung in AIRBORNE with no floor to stand the ground-neutral gate on; and one nonsense double-call line. Fixed: `spend(75)`, a StaticBody floor, cleaner asserts). Covers: four assigned slots, direct cast path (−10 per cast, unknown slot false, mana-short false with the pool untouched), four real LB+face casts spending exactly 40, no cast with LB up, no cast mid-attack, cast working again after recovery
- [x] Full sweep — **all 26 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Cast *feel* — with the batch (still the spark placeholder until Sprint 30; the real spells are the feel test)

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- A bare `player.tscn` instantiation floats in AIRBORNE forever — any check that exercises ground-state input needs a StaticBody floor under the spawn (spell_input_check adds a 20×1×20 box at y −0.5).
- When asserting a resource pool, remember the API's own invariants first: atomic `spend()` means an over-amount call is a no-op, not a partial drain.

**Known limitations:**

- The spark placeholder has no world effect — the mana spend is the observable; real spells (and the feel) arrive with Sprint 30's pool.
- Casting is ground-neutral only; airborne/block-state casting and spell-canceling an attack recovery are future tunes.

---

## 032 · 2026-11-16 · Initial Magic (Sprint 30, Phase 12)

**Goal:** The first real spell pool — each spell has distinct behavior and a distinct resource cost (roadmap Sprint 30; the guide's candidates: heal, reflect, fire, freeze).

**Scope:** `SpellData` gains generic `power`/`duration` params (per-effect interpretation, no per-spell field sprawl); four spell resources with distinct costs (heal 25 / fire 20 / freeze 30 / reflect 35); the dispatcher implements all four effects — heal (HP restore, clamped, honest `health_changed`), fire (a real projectile: a moving `HitboxComponent` carrier, damage via the existing DamageEvent path, despawn on hit/timeout), freeze (the boss rooted for the duration, tinted, restored — `BossController.freeze_for`), reflect (a timed buff: incoming damage negated and a flat amount returned to the event's `source`); `HealthComponent.heal()`; player body-tint helper for spell feedback; the spark stays in resources as the unassigned debug spell; slots A/B/X/Y become heal/fire/freeze/reflect; `spell_input_check.gd` re-anchors to dynamic costs; new `spell_pool_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** spell equip UI (one spell per slot is the whole pool for now), per-spell animations/VFX art, spell leveling, elemental status effects beyond the four.

**Decisions (planned):**

- **D-089 (effects dispatch by key, params are generic):** `SpellData.power`/`duration` mean what the effect says (heal: HP; fire: projectile damage; freeze: seconds rooted; reflect: damage returned / seconds active). Adding a spell = a resource with an effect key the dispatcher knows — no new fields per spell.
- **D-090 (the projectile reuses the combat pipeline):** the fire spell spawns a code-built carrier whose HitboxComponent (faction PLAYER) travels in a straight line and lands its `DamageEvent` through the same hurtbox→Health path as melee — no bespoke damage code; despawn on first hit or a 2 s lifetime.
- **D-091 (reflect is honest through the event):** during the window, incoming damage to the player is negated and `DamageEvent(power, source=player)` is applied to the incoming event's `source` — the XP system sees reflected damage as real boss damage (it is). Freezing roots movement only; the boss still attacks, keeping the fight's rhythm readable.

**Verification (planned):** `spell_pool_check.gd` (arena-based) — four distinct slots with distinct positive costs; heal restores clamped HP; fire's projectile reaches and damages the boss through the real pipeline and despawns; freeze roots the boss (speed 0 → restored, `is_frozen()` toggles); reflect negates a boss-sourced hit and returns its power to the boss, then expires. `spell_input_check.gd` re-anchored to the new costs (dynamic, per-slot asserts). Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-16)*

- `spell_data.gd` — `power`/`duration` params (D-089); four spell resources: HEAL (25 mana, +30 HP), FIREBOLT (20, 16 damage), FREEZE (30, 2.0 s root), REFLECT (35, 3.0 s, 10 returned per hit). The spark stays in resources as the unassigned debug spell; slots A/B/X/Y become heal/fire/freeze/reflect.
- `magic_component.gd` — the dispatcher (D-089): heal (clamped, green flash), fire (D-090: a code-built `SpellProjectile` — faction-PLAYER `HitboxComponent` + glowing mesh flying straight at the boss's chest, despawn on first hit/2 s lifetime), freeze (delegates to the boss), reflect (timed window + cyan tint, ended by timeout or retry).
- `health_component.gd` — `heal()`: honest HP gain (clamped, emits `health_changed`).
- `boss_controller.gd` — `freeze_for(duration)`/`is_frozen()` (D-091): roots movement only — the state machine keeps running so telegraphs/swings continue; ice-blue tint; `reset()` clears the root and tint.
- `player_controller.gd` — `set_body_tint`/`clear_body_tint` (spell feedback, shared slot with the dead-grey override); the reflect branch in `_resolve_incoming_damage` (D-091): negates the hit and applies `DamageEvent(power, source=player)` to the event's source — reflected damage is real boss damage and earns XP.
- `spell_pool_check.gd` (new, arena-based); `spell_input_check.gd` re-anchored to dynamic per-slot costs; smoke list +6 paths.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Spell pool check — **PASS** (two check-run findings fixed along the way): distinct slots/costs (25/20/30/35), heal 60→90 clamped at max, the firebolt crossed 8 m and dealt exactly 16 through the real hurtbox→Health pipeline then despawned, freeze rooted (speed 0, released at 2.0 s to the pre-freeze speed), reflect negated a boss-sourced 12-hit and returned 10, expired cleanly (a post-window hit landed normally, no return). **The pool check's first run caught a REAL bug**: `freeze_for` captured the pre-freeze speed but never zeroed `movement_speed` — the boss kept walking, roamed into attack range during the reflect test, and its real attacks lit up the reflect window (the phantom boss damage in the first run's asserts). One-line fix; the instrumentation confirmed the deterministic sequence before removal
- [x] Spell input check re-anchored — PASS (per-slot costs asserted dynamically; the LB-up and mid-attack coexistence asserts unchanged)
- [x] Full sweep — **all 27 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Spell *feel* — THE batch-playtest item this arc was building toward: costs, the firebolt's readability, freeze-vs-swing rhythm, reflect timing

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- The `-s` `get_tree()` lesson bit a THIRD time (the pool check used `get_tree().get_nodes_in_group`) — in a SceneTree script the tree methods are on `self`.
- When a pooled resource's assert fails by exactly one resource's worth (boss −20 instead of −10), suspect the environment was live: the unfrozen boss walked into range and its real attacks triggered the reflect window during the test. Park the actors BEFORE the window opens, not after.

**Known limitations:**

- One spell per slot, no equip UI (the pool is exactly the four slots' contents; a spell library arrives when there are more spells than slots).
- The firebolt is a straight line — no arc, no splash; freeze roots only the feet (attacks continue) by design.
- Reflected damage earns XP (it is real boss damage) — if that ever over-rewards defensive play, it's a tuning knob, not a rewrite.

---

## 033 · 2026-11-17 · Minotaur (Sprint 31, Phase 13 opener)

**Goal:** A second boss whose behavior is clearly distinct from the New Gladiator — charge, heavy attacks, shockwaves, positioning (roadmap Sprint 31). Hosted by the existing boss framework, not a new architecture.

**Scope:** `BossAttackData` gains `hitbox_size_scale` (D-092: the per-attack footprint); `BossController._apply_attack_footprint` resizes the attack BoxShape AND the telegraph marker at every attack entry (telegraph shows the scaled danger zone, D-035's mirror stays truthful); new `minotaur.tscn` — the bull (primitive: dark horned bulk), HP 150, slower feet (2.2 m/s), a harder-to-stagger threshold (25), and four data-only attacks: a light swing, a slow HEAVY overhead, **the charge** (9 m/s lunge across a 3–8 m band after a 0.9 s red telegraph — data via the existing `lunge_speed`), and **the shockwave slam** (a 24-damage HEAVY whose footprint scales to a wide slab — the ground marker shows it); the roster gains the Minotaur (D-076: zero selector code); new `minotaur_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** new boss states/behaviors beyond the data (no wall-splat, no enraged phase), real bull art, a third arena, per-boss music.

**Decisions (planned):**

- **D-092 (the footprint is attack data):** `hitbox_size_scale` on BossAttackData, applied at every attack entry so the hitbox, the ground marker, and the danger all stay the same shape. A shockwave is a *scaled* attack, not a new system — the guide's data-driven attack principle holds.
- **D-093 (the charge is the positioning lesson):** the charge is the existing lunge with extreme numbers (9 m/s, 0.5 s active, a far 3–8 m range band, long red telegraph) — standing far is no longer free; standing still while it fires is punished. Combined with the point-blank slam, the Minotaur forces movement: the fight is about where you stand, not just when you swing.

**Verification (planned):** `minotaur_check.gd` — roster integrity (three entries, distinct scenes), data distinctness (a far-band lunge attack + a scaled HEAVY footprint the gladiator lacks), and the behavioral proof in the arena: the real select path spawns the MINOTAUR (title + 150 HP); parked far, the boss charges and a stationary player eats 20; parked point-blank, the slam's scaled footprint lands 24; stepping out during the telegraph takes nothing. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-17)*

- `boss_attack_data.gd` — `hitbox_size_scale` (D-092); `boss_controller.gd` — `_apply_attack_footprint` resizes the attack BoxShape AND the telegraph marker's BoxMesh at every attack entry (`_push_payload` for attacks/followups, `_show_telegraph` for the warning), with the base footprint captured once. The danger zone shown is the zone that hits.
- `minotaur.tscn` — the bull (dark red-brown bulk + ivory horns, primitives), boss_title MINOTAUR, 150 HP, movement_speed 2.2, stagger threshold 25 (vs the gladiator's 15), and four data-only attacks: light swing (14, no string — a deliberate contrast), slow HEAVY overhead (22), the charge (20 HEAVY, 9 m/s lunge, 3–8 m band, 0.9 s telegraph — pure `lunge_speed` data, zero new code), and the shockwave slam (24 HEAVY, footprint ×(2.4, 1, 1.8)).
- `boss_roster.tres` — the third entry ("150 health, a charge from afar, and a ground slam. Keep moving."); the D-076 promise held: **zero selector or arena code changed**.
- `minotaur_check.gd` — roster + data-distinctness + the behavioral proof; smoke list +1 path.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Minotaur check — **PASS**: three distinct roster entries; the Minotaur's data carries a far-band 9 m/s lunge charge and a ×2.4-wide HEAVY slam the gladiator lacks (and the gladiator provably has neither shape); the real select path (title → select → two rights → confirm) spawns the MINOTAUR at 150 HP; the stationary player parked far ate the full charge (−20, the boss carried ~4 m); the point-blank slam landed 24 on its scaled footprint; stepping out during the telegraph took **nothing**
- [x] First runs' findings: an orphaned `else` parse error in the check, then "never charged" — the instrumentation showed the charge fired during the settle window (the brain selects within ticks); the watch now starts at tick 0. The framework itself needed no fixes — the data was right on the first run
- [x] Full sweep — **all 28 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Minotaur *feel* (charge dodge timing, slam zone readability, difficulty vs the gladiator) — THE headline item for the next batch playtest

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- Python replaces with backslash-continuations silently no-match — the grep-verify rule extends to them (the [D] instrumentation "applied" and printed nothing until redone with the Edit tool).
- Boss brains act FAST after settle: an instrumentation window that starts after a settle period misses the first telegraph entirely. Watch from tick 0.

**Known limitations:**

- The shockwave is a scaled front slab, not a radial ring — it reads as a ground slam; a true ring needs a shape the framework doesn't carry yet.
- The bull is primitives (body/head/horns); the art pass dresses it.
- No per-boss stagger behavior differences beyond the threshold (the Minotaur resists more, that's it).

---

## 034 · 2026-11-17 · Medusa (Sprint 32, Phase 13)

**Goal:** A ranged/control boss — petrification threat, ranged pressure, reflection; the player must adapt to facing/range and telegraph differences (roadmap Sprint 32).

**Scope:** `BossAttackData` gains `attack_shape` (melee default / projectile / shield), `status_effect`, and `duration` (D-094: attack *shapes* dispatch, payloads stay data); `HitboxComponent` forwards `status_effect` into the DamageEvent (the field has been waiting since D-021); `BossController` grows three small dispatch branches — the projectile shape spawns a faction-BOSS bolt through the same Projectile carrier the player's firebolt uses, the shield shape raises a timed **mirror** (incoming damage negated, `DamageEvent` returned to the source — the boss-side twin of the player's Sprint 30 reflect); `SpellProjectile` becomes the generic `Projectile` (moved to combat/); the player gains the **petrify** status (D-095: hit by a petrify-status attack → rooted `petrify_duration`, stone tint, cleared by timeout/retry); `medusa.tscn` — the serpent (slim, green, hood), 120 HP, frail stagger (12), and four attacks: the ranged spit (12, 3–9 m band, weight 3 — the pressure), the gaze (SPECIAL, 8 dmg + petrify status, 1.0 s telegraph), a close cleave (16 HEAVY), and the mirror shield; the roster grows to four; new `medusa_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** real stone statues/petrify models, per-boss projectiles beyond one shape, summoning snakes, gaze-mechanics tied to the camera facing (a zone threat, not a look-at-her rule — the roadmap says *threat*, and facing the camera at her is post-MVP polish).

**Decisions (planned):**

- **D-094 (shapes dispatch, data pays):** `attack_shape` picks the ATTACK-phase behavior — melee (the existing hitbox window), projectile (spawn and go), shield (a timed self-buff) — while damage/cooldowns/telegraphs stay the same data every boss already uses. The petrify rides the DamageEvent's existing `status_effect` field: the hit lands honestly, then the status applies.
- **D-095 (petrify is a full body-lock, not a slow):** caught by the gaze = rooted, stone-grey, no inputs — but the boss's own rhythm (the 1.0 s telegraph, the 6 s cooldown) makes it escapable, and retry clears it. It's a punish window opener, not a death sentence.
- **D-096 (the mirror is the player's reflect, inverted):** the same negation-and-return semantic the player learned in Sprint 30, now on the boss — the player reads the tint and *stops attacking* for three seconds. Build-oriented play, both directions.

**Verification (planned):** `medusa_check.gd` — roster of four distinct entries; the data carries a projectile-shaped ranged attack, a petrify-status gaze, and a mirror; behavior in the arena: parked far, the spit's bolt crosses and lands (−12) — ranged pressure proven; the gaze's hit petrifies the player (rooted + tint, clears on timeout); with the mirror forced, damage to the boss is negated and returned to the player (−10), and lands normally after expiry. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-17)*

- `boss_attack_data.gd` — `attack_shape` (melee/projectile/shield, D-094), `status_effect`, `duration`; `hitbox_component.gd` — the `status_effect` export forwarded into the DamageEvent (the D-021 field finally has a sender).
- `boss_controller.gd` — the ATTACK-phase shape dispatch (projectile: one bolt via the generic `Projectile` carrier at faction BOSS; shield: the timed mirror — negated hits return `DamageEvent(damage)` to the source, silver tint, `is_mirroring()`); the lunge and hitbox-window gating now respect the shape; `_push_payload` resets the once-per-attack shape guard; `reset()` clears the mirror.
- `player_controller.gd` — the petrify status (D-095): `petrify_for`/`petrify_active`, a body-lock that skips the state machine (retry still works, gravity still applies, dead-guarded), stone tint, cleared by timeout/retry; a clean hit carrying `&"petrify"` applies it — blocked/mitigated paths never do (blocking the gaze is counter-tech).
- `projectile.gd` — renamed `SpellProjectile` → `Projectile`, moved to `combat/` (both factions use it now); `magic_component.gd` + smoke list re-referenced.
- `medusa.tscn` — the serpent (slim green capsule, hood), 120 HP, 2.6 m/s, stagger threshold 12, four attacks: the spit (projectile, 3–9 m), the gaze (SPECIAL, petrify status, footprint ×(1.5, 1, 2.2)), the cleave (HEAVY), the mirror (shield, 3 s/10 return); roster entry four ("Spits from range, petrifies what lingers, mirrors what strikes").
- `medusa_check.gd` (new, real select path at index 3); `minotaur_check.gd`'s roster assert updated to the grown roster; smoke list +1 path.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Medusa check — **PASS**: four distinct entries; the spit is projectile-shaped with a 9 m band, the gaze carries `&"petrify"` as SPECIAL, the mirror is a 3 s shield; the real select path spawns the MEDUSA at 120 HP; the spit's bolt crossed 6 m and landed −12 (ranged pressure); the gaze petrified a mid-range player (−8, rooted, released ~1.5 s); the mirror negated a 15-damage strike and returned 10 to the player, then expired (a post-mirror hit landed fully)
- [x] The sweep caught TWO check-layer races the solo run hid: (1) the **poke-overwrite race** — phase D's spit recovery ended *after* phase E poked the cooldowns, so the natural 1.6 s cooldown overwrote the poke and a stray spit fired mid-gaze-test (the "20 instead of 8" symptom); fixed by waiting for OBSERVE before poking (the recovery's write lands first); (2) the **minotaur check's stale roster count** (three) bailed via `quit(1)` before printing — the empty-log hang signature. Both fixed; the framework code itself was correct
- [x] Full sweep — **all 29 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Medusa *feel* (gaze dodge windows, mirror timing, ranged-pressure balance) — a headline item for the next batch playtest

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- A check that pokes cooldowns must wait for the actor's OBSERVE (recovery done) first — a pending recovery writes its natural cooldown OVER the poke. The sweep's back-to-back load exposed it where the solo run hid it.
- An early `quit(1)` before the failure print produces the empty-log hang signature — print the failures or fail loudly.

**Known limitations:**

- The petrify is a full body-lock (no slow-move variant); the gaze is a zone threat, not a camera-facing rule (post-MVP polish).
- One projectile shape per boss faction; reflected damage during the boss's mirror can stack with the player's own reflect window (an exotic interaction to watch in playtesting).

---

## 035 · 2026-11-18 · Giant Spider (Sprint 33, Phase 13)

**Goal:** A control/mobility boss — webs, poison, pounce; mobility and status pressure create a distinct encounter (roadmap Sprint 33). Summons are the roadmap's "possible" — deferred, not silently skipped.

**Scope:** the player gains two more DamageEvent-carried statuses (D-097: the same pipe the petrify opened — **web**, a movement slow, and **poison**, the first damage-over-time, ticking honestly through HealthComponent and able to kill); the delivery hook becomes a status match; `spider.tscn` — the eight-legged horror (primitives: dark abdomen, head, six legs), 110 HP, fast (3.2 m/s), very frail (stagger 10), three attacks: the **web spit** (projectile, 6 dmg + web slow ×0.4 for 2.5 s, 3–8 m), the **venom bite** (10 dmg + poison: 3 per 0.5 s for 4 s), and the **pounce** (14 dmg, 8 m/s lunge across a 2.5–6 m band — the charge's data sibling, D-098); roster entry five; new `spider_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** summons (a spawn system is its own sprint), web-zone pools (a persistent AoE), wall-crawling, poison stacking.

**Decisions (planned):**

- **D-097 (statuses ride the one pipe):** web and poison reuse the `status_effect` → resolution-match mechanism the petrify opened — each is a small timer on the player, the poison ticks honest `DamageEvent`s through HealthComponent (it can kill, it earns the boss nothing fake). The web slow applies at the movement choke point (`_neutral_movement`) so blocks/dodges compound with it naturally.
- **D-098 (the pounce is the charge's sibling):** same lunge data with a shorter band and faster rhythm — the spider's answer to mid-range kiting. With webs slowing escapes and poison punishing trades, the encounter pressures MOBILITY itself: the player must keep moving *well*, not just move.

**Verification (planned):** `spider_check.gd` — five distinct roster entries; the data carries a web-status projectile, a poison-status bite, and a pounce lunge; behavior in the arena: the web bolt lands and the player's speed visibly halves (then recovers), the venom bite poisons (the HP drains in honest ticks, then clears), and the pounce crosses its band into a stationary player. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-18)*

- `player_controller.gd` — the web and poison statuses (D-097): `web_for`/`poison_for` timers, the poison ticking honest `DamageEvent`s through HealthComponent every 0.5 s (it can kill), the web slow applied at the `_neutral_movement` choke point (blocks/dodges compound), the delivery hook now a status `match`, retry clears everything, tints per status (pale-blue web, green poison).
- `spider.tscn` — the arachnid (dark abdomen, head, six legs — primitives), 110 HP, 3.2 m/s (the fastest boss), stagger threshold 10, three attacks: the web spit (projectile, 6 dmg + slow, 3–8 m), the venom bite (10 + poison, point-blank), the pounce (14 HEAVY, 8 m/s lunge, 2.5–6 m).
- `boss_roster.tres` — entry five ("Webs slow you, venom lingers, and it pounces. Keep your feet."); `spider_check.gd` (new); smoke list +1 path.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Spider check — **PASS**: five distinct entries; the web is a projectile carrying `&"web"`, the venom carries `&"poison"`, the pounce lunges ≥7 m/s across a 5 m band; the real select path (four rights → confirm) spawns the GIANT SPIDER at 110 HP; the web bolt landed (−6), the player's speed halved (0.4×, `effective_speed()`), and recovered on expiry; the bite poisoned (−10 + the drain observed), the ticks cleared on expiry; the pounce crossed its band into a stationary player (−14)
- [x] The first runs' findings were ALL check-layer: the web bolt hit during the settle window (the Sprint 31 brain-speed lesson, again — the watches now start at tick 0); D's 999-second cooldown pokes leaked into E/F (fixed with `clear()` + targeted re-pokes after `wait_observe`); the bite/poison assert needed a captured baseline (the DoT ticks land inside any post-hit window). The instrumentation trace proved the web status itself was correct end-to-end on the first run
- [x] The sweep also caught the **medusa check's stale roster count** (four → five, the same empty-log bail as last sprint) and its absolute HP asserts broken by legitimate stray spit damage — both hardened to relative asserts (capture-at-telegraph, capture-before-strike); medusa PASS ×2 after
- [x] Full sweep — **all 30 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Spider *feel* (web slow readability, poison pressure vs the heal spell, pounce dodge rhythm) — a headline item for the next batch playtest

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- The brain-speed lesson now has a general form: **any boss-check watch must start at tick 0 after positioning** — settle windows swallow the first telegraph, and the assert then measures a stale or expired state.
- Cooldown pokes need `clear()` + targeted re-pokes AFTER `wait_observe` — a pending recovery's natural cooldown write overwrites stale pokes.
- Absolute HP asserts break the moment a boss has ranged pressure (stray bolts land inside any window) — assert **relative to a capture point** at the phase boundary.
- Python string-strips can leave mangled indentation (a stray `\t\t\tif`) — grep-verify every strip, and the parse error's file:line is in the log's `at:` line.

**Known limitations:**

- Summons deferred (the roadmap's "possible"): a spawn system is its own sprint.
- No web-zone pools or wall-crawling; poison doesn't stack (a re-bite refreshes the timer).
- The spider's six legs are static primitives — no procedural leg animation (art pass).

---

## 036 · 2026-11-18 · Giant Crab (Sprint 34, Phase 13)

**Goal:** An armored defense-oriented boss — armor, sweeping claws, shorter openings; positioning and punish timing differ from other bosses (roadmap Sprint 34).

**Scope:** `BossController` gains `@export var armor` with a shell soak in the default damage path (floor 1, the D-081 semantics — and **the shell cracks during STAGGERED**: the punish window takes full damage, the stagger buildup is unaffected by the soak); `crab.tscn` — the armored wall (wide flat shell, two claws — primitives), 130 HP, 2.4 m/s, stagger 18 but a longer 2.4 s window (the reward), **shorter openings** (recoveries 0.3–0.5 s vs the gladiator's 0.4–0.8, a short 0.35 s snap telegraph), and three attacks: the two-sweep claw string (wide footprints ×(1.9–2.0, 1, ~1.2) — the minotaur's footprint scaling reused), and the point-blank snap; roster entry six; new `crab_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** armor phases/enrage, shell-throwing, bubbles, real crab art, per-boss armor on other bosses (the export defaults to 0 — only the crab sets it).

**Decisions (planned):**

- **D-099 (armor is a soak that cracks):** the crab's `armor` soaks every hit outside STAGGERED (floored at 1 like the player's gear armor, D-081) and does nothing inside the punish window — the stagger becomes the damage window by construction. The soak touches `amount` only, so stagger buildup flows untouched (armored, but staggcrackable).
- **D-100 (shorter openings = data, not states):** the crab's recoveries and its snap telegraph are simply shorter numbers — the "fewer punish windows" feel comes from tuning, and its ONE big window (the 2.4 s stagger) is longer than the others'. Wide sweeps punish lateral hugging; the snap punishes lingering point-blank.

**Verification (planned):** `crab_check.gd` — six distinct roster entries; the data carries armor + wide sweep footprints + short recoveries; behavior in the arena: the real select path spawns the GIANT CRAB (130 HP, armor 3), a 15-damage strike lands as 12 (the soak), the shell cracks on stagger (a stagger-heavy strike triggers it; the next 15 lands FULL), the armor re-hardens after the window, and the sweep's scaled footprint lands its 12 point-blank. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-18)*

- `boss_controller.gd` — `@export var armor` (D-099): a flat soak (floor 1) in the resolve's default path — the STAGGERED branch is the crack (full damage inside the punish window); the soak touches `amount` only, so stagger buildup flows untouched. Every other boss defaults to 0.
- `crab.tscn` — the armored wall (wide flat metallic shell, two claws, four legs — primitives), 130 HP, 2.4 m/s, stagger 18 with a longer 2.4 s window, armor 3, and three attacks: the two-sweep claw string (wide footprints ×(1.9/2.0, 1, 1.1/1.2) — D-092's scaling reused; sweep_2 is followup-only), and the point-blank snap (22 HEAVY, a 0.35 s telegraph — the shortest warning of any boss).
- `boss_roster.tres` — entry six ("An armored shell soaks your swings. Crack it in the stagger."); `crab_check.gd` (new); smoke list +1 path.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Crab check — **PASS**: six distinct entries; the crab carries armor 3, wide sweep footprints, a chained second sweep, and short recoveries (the gladiator provably has armor 0); the real select path (five rights → confirm) spawns the GIANT CRAB at 130 HP; a 15 strike landed as 12 (the soak); a stagger-heavy strike cracked the shell and the next 15 landed FULL; after the window the shell re-hardened (a 10 strike → 7); the sweep's scaled footprint landed its 12 point-blank
- [x] The first run's four failures were ALL the check's own arithmetic (it asserted remaining-HP formulas instead of damage deltas, and a float-dust `<` on the scaled footprint) — the mechanic was correct on the first run; the asserts now use before/after damage deltas with tolerances
- [x] Full sweep — **all 31 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Crab *feel* (the soak's grind, sweep-dodge spacing, the crack-window payoff) — a headline item for the next batch playtest

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- When a mechanic mutates a shared value (HP), assert **deltas captured around the event**, not absolute expected values — the max-health base made three asserts wrong in one run.
- Float-dust `<` on a computed product (`x < 1.8 * 1.9`) fails on exact equality — tolerance-compare.

**Known limitations:**

- The armor is a flat soak (the player-gear pattern); percentage mitigation stays post-MVP.
- The sweeps are static wide slabs — no claw-swing animation arcs (art pass).
- The shell "crack" is mechanical only (full damage in the window) — no visual shell-break state (art pass / a future polish sprint).

---

## 037 · 2026-11-18 · Mutated Lion (Sprint 35, Phase 13)

**Goal:** An aggressive pursuit boss — pursuit, pounce, bleed, aggression/enrage; the fight has noticeably higher movement pressure without relying only on HP (roadmap Sprint 35).

**Scope:** `BossController` gains the **enrage** (D-101: a health-fraction threshold — crossed once, the boss's movement multiplies and it tints red; polled D-068-style, reset-safe via a captured spawn speed); `player_controller.gd` gains the **bleed** status (D-102: the third DamageEvent-carried status — a heavier, shorter DoT than the spider's poison, same timer pipe); `lion.tscn` — the predator (tawny body, mane — primitives), 115 HP, **3.6 m/s** (the fastest yet), stagger 14, enrage at 50% (×1.6 speed → 5.76), three attacks: the fang bite (12, a 0.35 s telegraph — the pressure), the **pounce** (15 HEAVY, 9 m/s lunge, 2.5–6.5 m), and the **rending claws** (14 + bleed: 5 per 0.5 s for 3 s — 30 total, the heaviest DoT); roster entry seven; new `lion_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** enrage damage multipliers (speed only this sprint), leap-chains, roar knockbacks, real lion art.

**Decisions (planned):**

- **D-101 (enrage is a threshold state, not a phase system):** one poll — at `enrage_threshold` of max health the boss multiplies its movement by `enrage_speed_multiplier`, tints red, and never un-enrages within the fight. It reuses the tint pattern and is reset-safe (a captured spawn speed restores cleanly). Other bosses default to threshold 0 (never).
- **D-102 (bleed is the pipe's third rider):** like poison but heavier per tick and shorter — the player's status block stays a set of parallel small timers until a third mechanic forces generalization. The movement pressure comes from the lion's FEET (3.6 → 5.76 m/s enraged) plus pounce range, not from HP bloat (115 HP — the lowest of the tier bosses).

**Verification (planned):** `lion_check.gd` — seven distinct roster entries; the data carries a bleed-status attack, a pounce lunge, the pursuit speed, and the enrage exports; behavior in the arena: the real select path spawns the MUTATED LION (115 HP); the rending claws' hit bleeds the player (the ticks drain, then clear); the pounce crosses its band into a stationary player (−15); damaging the lion past 50% enrages it (speed visibly multiplies, red tint) and it **closes distance on a stationary player** — the pursuit. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-18)*

- `boss_controller.gd` — the enrage (D-101): `enrage_threshold`/`enrage_speed_multiplier` exports, a once-per-fight poll (≤ the threshold fraction of max health → the movement multiplies, red tint, never un-enrages), `is_enraged()`, and a captured spawn speed so reset restores the pre-enrage pace. Every other boss defaults to threshold 0.
- `player_controller.gd` — the bleed status (D-102): `bleed_for`/`bleed_active` — 5 per 0.5 s for 3 s (30 total, the heaviest DoT), the same timer pipe as poison, retry-clears, red tint.
- `lion.tscn` — the predator (tawny body, mane box, primitives), 115 HP, 3.6 m/s, stagger 14/2.2, enrage 50%/×1.6, three attacks: the fang bite (12, 0.35 s telegraph), the pounce (15 HEAVY, 9 m/s lunge, 2.5–6.5 m), the rending claws (14 + bleed).
- `boss_roster.tres` — entry seven ("It hunts you down, bleeds you, and only gets faster. Keep running."); `lion_check.gd` (new); smoke list +1 path.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Lion check — **PASS**: seven distinct entries; the claws carry `&"bleed"`, the pounce lunges ≥8 m/s across a 6.5 m band, the pursuit speed 3.6 with enrage exports in range; the real select path (six rights → confirm) spawns the MUTATED LION at 115 HP; the claws landed and bled (the ticks drained ≥20, then cleared); the pounce crossed its band into a stationary player (−15); a 60-damage wound crossed the threshold → enraged, the speed multiplied to 5.76, and over 4 s the lion closed ≥2 m of a 7 m gap on a stationary player
- [x] The check hardenings this sprint (all check-layer; the mechanics were correct on the first run): the claws' damage assert went relative (bleed ticks land inside any window); E's poke-leak fixed with `clear()` + re-pokes (the D pokes would lock the pounce out); the pursuit assert became a **closest-approach over 4 s** — the raw path length under-measured a pursuit that legitimately pauses (string_pause + pounce telegraphs are part of the rhythm)
- [x] The sweep ALSO caught a **real latent hazard** in the minotaur check: its stepped-out wait read `_current_attack.telegraph_duration` AFTER the player teleport trips the telegraph's distance cancel (`_current_attack` nulls → a null access kills the coroutine → the empty-log hang). The duration is now captured before the teleport; minotaur PASS after
- [x] Full sweep — **all 32 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Lion *feel* (enrage pressure, bleed-vs-heal rhythm, pounce dodge windows) — a headline item for the next batch playtest

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- A pursuit assert must measure **closest approach over a long window**, not path length or a short window — aggressive bosses pause legitimately (string_pause, telegraphs) and the pauses are part of the pressure being tested.
- Any check that teleports the player out of a live telegraph must capture the telegraph's parameters FIRST — the distance cancel nulls `_current_attack` on the next tick.
- The python-replace silent-fail bit a third time; grep-verify after every programmatic edit.

**Known limitations:**

- The enrage multiplies movement only — no attack-speed or damage multiplier yet (a tuning knob if the enrage feels toothless).
- Bleed doesn't stack or interact with movement (a move-triggered variant is a future tune).
- No roar/leap-chain; the mane is a static primitive (art pass).

---

## 038 · 2026-11-19 · Set Framework (Sprint 36, Phase 14 — Build Identity)

**Goal:** Support gear sets and set bonuses — equipping a set changes configured gameplay effects; an extensible set system (roadmap Sprint 36). Fully headless-verifiable: no playtest data required (the user deferred playtest-dependent sprints explicitly).

**Scope:** `GearData` gains `set_id` (the guide §24 field, deferred from Sprint 26 — now this sprint's business); new `SetData`/`SetCatalog` resources (the guide's SetData shape: name, required_pieces, bonuses — the bonuses reuse the gear modifier fields so the aggregation is ONE code path); `GearLibrary.active_sets(ids)` — the shared rule (count equipped pieces per set_id ≥ required_pieces → active); `EquipmentComponent._total` adds active-set contributions (the player composition, the HUD, and every consumer get set bonuses with ZERO new wiring — the D-079 promise holds); the armory's totals line includes them; the starter **TRAINEE SET** (the existing Trainee's Cap + Wrist Wraps tagged: 2 pieces → +4 attack) so the framework ships with a real, wearable set; new `set_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** the Flame/Gladiator sets (Sprints 37/38), set-specific triggered effects (a "bonuses" field beyond flat stats), set UI beyond the totals line, respecialization costs.

**Decisions (planned):**

- **D-103 (set bonuses are derived, never stored):** the save stores item ids only; active sets are computed from what's equipped — equipping/unequipping grants/removes bonuses automatically, and retry/reload/restart all re-derive identically. No save-format change (version stays 1).
- **D-104 (the guide's SetData shape, one aggregation path):** `SetData` carries `required_pieces` plus the same modifier fields as `GearData` — the totals functions sum gear + active sets in one place, so a future triggered-effect bonus extends the same structure. `GearData.set_id` tags pieces; adding a set = a resource + tags on pieces, zero combat code.

**Verification (planned):** `set_check.gd` — the set catalog loads (the Trainee Set, 2 pieces); headless aggregation: one piece → no bonus, both pieces → the attack total includes the +4; the real player composition (the level-1 attack payload = items 2 + set 4 = 6); unequip one piece → the bonus drops; the real armory path (equip both → fight → the spawned player carries the set-boosted payload). The existing gear_check must survive untouched (its swap phase deactivates the set by design). Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-19)*

- `gear_data.gd` — `set_id` (the guide §24 field, deferred from Sprint 26); `set_data.gd`/`set_catalog.gd` — the guide's SetData shape (required_pieces + the same modifier fields as GearData, so the aggregation is one code path) and its catalog; `gear_sets.tres` — the starter **TRAINEE SET** (the existing Trainee's Cap + Wrist Wraps tagged, 2 pieces → +4 attack).
- `gear_library.gd` — `active_sets(ids)`: the single rule (count equipped pieces per set_id ≥ required_pieces → active) used by both consumers.
- `equipment_component.gd` — `_total` adds active-set contributions: the player's stat composition, the HUD, and every downstream consumer get set bonuses with ZERO new wiring (the D-079 promise held again).
- `armory.gd` — the totals line includes set contributions and names active sets ("TRAINEE SET ACTIVE").
- `set_check.gd` (new); smoke list +3 paths.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Set check — **PASS first run**: the catalog loads (the Trainee Set, 2 pieces, +4 attack); a lone set piece grants nothing; both pieces put the +4 through the equipment totals (attack 6 = 2 item + 4 set) without polluting the other totals; unequipping one piece drops it; the real player composition carried it (the level-1 payload 6, the cap's 106 max health); the real armory path (wear both → the totals line names "TRAINEE SET ACTIVE" → fight) spawned a player with the set-boosted payload
- [x] The gear_check survived untouched (its swap phase deactivates the set by design — the wraps alone never trigger it)
- [x] The sweep caught the **lion check's flake** (a third cooldown poke-leak: D/E poked the pounce at 999 s and F never freed it — the lion could never pounce in the pursuit window; the failing runs closed exactly 1.0 m, the approach's momentum). Fixed with `clear()` + targeted re-pokes in F; the lion check passed ×3 after
- [x] Full sweep — **all 33 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Set *feel* (wearing the Trainee Set's chunkier hits) — folded into the batch playtest list

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- The cooldown poke-leak recurred a THIRD time (the lion's F phase) — the rule is now law: **any check phase that needs an attack available must start from `_cooldowns.clear()` + explicit pokes of what it wants EXCLUDED**, never from incremental un-poking.
- The derived-bonus pattern (D-103) needed zero save changes and zero player-controller changes — the aggregation seam (the equipment totals) absorbed the feature.

**Known limitations:**

- Set bonuses are flat stats only; triggered effects (the Flame/Gladiator sets' special behaviors) arrive with Sprints 37/38.
- One set in the catalog; the armory shows the set's name but no per-piece set progress display.

---

## 039 · 2026-11-21 · Flame Set (Sprint 37, Phase 14 — Build Identity)

**Goal:** A fire-focused identity — fire magic gains major area/effect changes when the set is equipped (roadmap Sprint 37).

**Scope:** `SetData` gains an `effect` key (the extensible hook: a set can DECLARE a behavior); `SpellData` gains `blast_damage`/`blast_radius` (the fire spell carries its own variant numbers); the `Projectile` gains an optional explosion — on hit, a radial shape-query damages every enemy hurtbox in the radius through the honest `receive_damage` path, plus a flash; the MagicComponent's fire cast reads the player's active sets for `&"flame_bolt"` and configures the bolt; two new fire pieces (**EMBER CROWN** HEAD hp+4, **FLAME BRACERS** HANDS atk+1, both `set_id "flame"`); the **FLAME SET** (2 pieces, effect `&"flame_bolt"`, no flat stats — the blast IS the bonus); the firebolt's blast: 8 damage in 2.5 m (the primary is caught too — 24 total single-target); new `flame_set_check.gd`; smoke list; TUNING.md; playtesting.md.
**Non-goals:** burning DoT on the blast (a 4th status), the Gladiator Set (Sprint 38), fire-resistance gear, new spells.

**Decisions (planned):**

- **D-105 (the set declares, the spell carries, the projectile does):** the guide's "no set effects hard-coded in the player controller" holds by shape — `SetData.effect` is a data key, `SpellData.blast_*` are the fire spell's own variant numbers, and the projectile implements the blast generically (0 = none). The MagicComponent only BRIDGES: active sets → effect key → configure the spawn.
- **D-106 (the blast catches the primary):** the explosion damages every enemy hurtbox in the radius INCLUDING the direct-hit target — single-target 24, multi-target potential 16+8×n. It lands through `receive_damage` like everything else, so stagger/XP/feedback all see it honestly.

**Verification (planned):** `flame_set_check.gd` — the Flame Set data (2 tagged pieces, the effect key) and the fire spell's blast fields; behavior in the arena with the real LB+B cast: without the set the firebolt deals 16; equipping the Flame Set pieces makes the same cast deal 24 (the direct hit plus the blast catching the boss in its radius); the real armory path (equip both → fight → cast) spawns the explosive firebolt. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-21)*

- `set_data.gd` — `effect` (D-105: a set can DECLARE a behavior key); `spell_data.gd` — `blast_damage`/`blast_radius` (the fire spell carries its own variant numbers); `projectile.gd` — the optional explosion: on hit, a radial shape-query damages every enemy hurtbox in the radius through the honest `receive_damage` path (the primary included — 24 single-target), plus an expanding orange flash freed before the next swing; `magic_component.gd` — the fire cast reads the player's active sets for `&"flame_bolt"` and configures the spawn (the guide's no-hard-coded-set-effects rule holds by shape: the set declares, the spell carries, the projectile does).
- The FLAME SET: **EMBER CROWN** (HEAD, hp+4) + **FLAME BRACERS** (HANDS, atk+1), both `set_id "flame"`, 2 pieces → the blast; no flat set stats (the blast IS the bonus); the fire spell's data: blast 8 in 2.5 m.
- The gear catalog grows to 9 items; `flame_set_check.gd` (new); smoke list +2 paths.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Flame set check — **PASS**: the set data and the blast fields; the arena mechanics with the REAL LB+B cast — without the set the firebolt dealt 16, with the Flame Set pieces the same cast dealt 24 (16 direct + 8 blast catching the boss); the real armory path (equip both → fight → cast) spawned the explosive firebolt (−24)
- [x] The first runs' findings, all check/harness-layer: the cast helper needed `await` (it's a coroutine), the cast needed a landing wait (the ground-neutral gate), B's assert used the wrong max-HP base, and B's live-player equips polluted the loadout the armory phase then "unequipped" — the armory's toggles were CORRECT the whole time. The blast itself worked on the first run
- [x] The sweep then caught two catalog-growth casualties in the older checks: the gear_check's slot-uniqueness rule (sets legitimately share slots — it now asserts unique **ids**) and the weapon_check's hardcoded spear row (the flame pieces shifted it — it now finds the row dynamically). Both fixed; all four gear-family checks PASS
- [x] Full sweep — **all 34 checks PASS** (the minotaur's single sweep-load timeout verified ×3 solo after — its hang mechanism was fixed in Sprint 35)
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Flame Set *feel* (the blast's readability, the explosion's payoff vs 20 mana) — a headline item for the next batch playtest

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- A helper with `await` inside is a coroutine — every call site needs `await` or the parse fails at the call, not the definition.
- When a check phase mutates shared state (the loadout) via live-node equips, later phases inherit it — clear at phase boundaries (`set_loadout([])`).
- The catalog grows across sprints: armory navigation must find rows dynamically (by item id), never by hardcoded down-counts.

**Known limitations:**

- The blast damages one faction layer (BOSS hurtboxes); multi-faction blasts await a second enemy.
- The flash is a static expanding sphere — a real explosion VFX is art-pass work.
- The blast's stagger damage is 0 (deliberate: spells don't build the punish window).

---

## 040 · 2026-11-21 · Gladiator Set (Sprint 38, Phase 14 — Build Identity)

**Goal:** A speed-focused identity — movement/attack speed increase and a finisher explosion working together without breaking combat rules (roadmap Sprint 38).

**Scope:** the **GLADIATOR SET** (2 new pieces: **GLADIATOR PAULDRONS** BODY hp+5/move+0.1, **GLADIATOR GREAVES** FEET move+0.25; the set grants move+0.3/attack-speed+0.05 with the effect key `&"gladiator_finisher"`) — the speed half is PURE DATA through the Sprint 36 aggregation; `ComboStepData` gains `blast_damage`/`blast_radius` (the finisher steps carry 10/2.2 — all three combos' finishers, so the identity works with any weapon); new `CombatBlast.detonate` (combat/blast.gd) — the radial query + the events + the flash, extracted from the projectile so BOTH consumers share one implementation; the player's finisher hit handler detonates when the hit is a finisher, the step carries a blast, and the player's active sets contain the gladiator effect key; the gladiator-provoked stagger/breakout interplay asserted as-is (no special-casing); new `gladiator_set_check.gd` (the full-combo damage totals with/without the set); smoke list; TUNING.md; playtesting.md.
**Non-goals:** attack-speed telegraph changes (the swing DATA is untouched), enrage-style multipliers, real pauldron art, per-weapon finisher variations.

**Decisions (planned):**

- **D-107 (the speed half is data, the explosion half is a generic blast):** the movement/attack-speed increase needs ZERO code — the set's own `movement_bonus`/`attack_speed_bonus` flow through the Sprint 36 aggregation. The finisher explosion is a generic mechanism (any step carrying blast fields detonates when the player's active sets contain the gating effect key) — the blast implementation is ONE static shared by the projectile and the melee finisher.
- **D-108 (the combat rules hold by construction):** the blast lands through the same `receive_damage` path as everything else — the hit-once guard, the stagger buildup, and the breakout all see honest events; the check asserts EXACT combo totals (61 without the set, 71 with) so a double-hit or a blast duplication fails loudly.

**Verification (planned):** `gladiator_set_check.gd` — the set data (2 tagged pieces, the effect key, the speed bonuses); the real player's stats with the set (movement 5.65, attack-speed ×1.05); the arena with the REAL combo inputs: without the set a full combo takes exactly 61, with the set 71 (the finisher + the blast catching the boss) — and the gladiator's own stagger/breakout fires mid-combo as usual. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-21)*

- `blast.gd` — `CombatBlast.detonate` (D-107): the ONE radial-damage implementation (the shape query, the honest events, the flash) shared by the projectile's firebolt blast and the finisher's explosion — the projectile's inline version extracted into it.
- `combo_step_data.gd` — `blast_damage`/`blast_radius` (the finisher steps carry 10/2.2 — all three combos' finishers, so the identity works with any weapon); `player_controller.gd` — the finisher blast gate reads `combo.finisher` explicitly (NOT `_current_step()`, which still points at light_03 during the finisher) and detonates when the player's active sets contain `&"gladiator_finisher"`.
- The GLADIATOR SET: **GLADIATOR PAULDRONS** (BODY, hp+5/move+0.1) + **GLADIATOR GREAVES** (FEET, move+0.25), both `set_id "gladiator"`; the set grants move+0.3/attack-speed+0.05 (the speed half is pure data through the Sprint 36 aggregation) + the effect key (the explosion half).
- `gladiator_set_check.gd` (new): one arena player drives BOTH combos (the un-set baseline 61, then the set equips on the SAME player → the speed asserts + 75 with the blast and the mid-combo level-up); smoke list +3 paths.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Gladiator set check — **PASS**: the set data (the effect key, the speed bonuses); the arena with the REAL combo inputs — without the set a full combo dealt exactly 61; equipping the set multiplied the speed to 5.65 (×1.05 attack speed) and the same combo dealt 75 (61 + 4 from the mid-combo level-up + 10 finisher blast) — the combat rules held by construction (the exact totals: no double-hits, no blast duplication)
- [x] The first runs' findings, all check-layer: the original two-player structure (a bare B player + the arena player) made `get_first_node_in_group("player")` return the B player (never freed) for phase C's combos — the C1 "un-set" combo was actually driving the set-wearing B player (71 = 61 + blast). **The restructure eliminated the B player entirely**: one arena player drives both combos (the un-set baseline, then the set equips on the SAME player). The blast's gate also had a real bug: `_current_step()` returns light_03 during the finisher (blast fields 0) — the gate now reads `combo.finisher` explicitly
- [x] Full sweep — **all 34 validation checks PASS** (the gear/weapon/set checks survived the catalog growth: the gear check asserts unique ids, the weapon check finds rows dynamically)
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Gladiator Set *feel* (the speed identity's readability, the finisher blast's payoff) — a headline item for the next batch playtest

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- **Never create a second player instance in a check that drives combos via global input** — `Input.action_press` reaches every listening player, and an unfreed first player in the "player" group hijacks `get_first_node_in_group` for every later phase. One arena player, two combos (the baseline, then the equips on the same player).
- The finisher's `_current_step()` still points at the last LIGHT step during the finisher — the finisher's own data must be read via `combo.finisher` explicitly.
- The mid-combo level-up (+2 attack from D-066) shifts the combo's damage totals — the checks' expected values must account for the XP the combos themselves generate.

**Known limitations:**

- The finisher blast's stagger damage is 0 (deliberate: the blast is a damage payoff, not a stagger builder).
- The speed bonuses are flat (no percentage multiplier); the movement/attack-speed numbers are D-066-consistent.
- No gladiator-themed visual (the pauldrons/greaves are stat pieces; the art pass dresses them).

## 041 · 2026-11-21 · Multiple Finishers (Sprint 39, Phase 15 — Advanced Combat)

**Goal:** Configurable finisher sequences — finishers chain automatically according to data configuration; expanded combo expression without a larger action bar (roadmap Sprint 39).

**Scope:** `ComboData.finisher` (single) becomes `finisher_chain: Array[ComboStepData]` — the finisher steps flow automatically after the last light step, per the data; the player gains `_finisher_index` (the chain position) and `_current_step()` returns the CURRENT chain step during the finisher (the payload, the timings, the animation, and the blast gate all read it — no `combo.finisher` special-casing anywhere); the blast gate generalizes to the chain step's own blast fields (any chain step can carry a blast); the data: the default combo's chain becomes **[finisher_01 (25 dmg) → finisher_02 (15 dmg, a quick followthrough carrying the Gladiator Set's 10/2.2 blast)]** — the 2-step chain proves the automatic chaining; the gladius/spear combos: 1-element chains (the framework handles any length); the consumers: weapon_data's summary (the chain's last step's damage), the checks (the combo_check's expected chain, the gladiator/weapon checks' finisher refs, the damage totals 61 → 76/90); TUNING.md; playtesting.md.
**Non-goals:** input-triggered finisher selection (the chain is automatic per the roadmap), per-finisher animations beyond the existing placeholder set, new weapons.

**Decisions (planned):**

- **D-109 (the chain replaces the single finisher):** `finisher_chain` replaces `finisher` — a 1-element chain IS the old single finisher (the gladius/spear combos), a 2-element chain proves the automatic chaining (the default combo). The player's flow: after the last light step, `_finisher_index` walks the chain; each step's payload/timings/animation come from `_current_step()` — one code path, any chain length.
- **D-110 (the blast rides the chain step's own data):** the Gladiator Set's explosion gate generalizes from `combo.finisher.blast_damage` to the CURRENT chain step's blast fields — any finisher step can carry a blast, the data decides. The default combo's blast caps the sequence (finisher_02, the last step).

**Verification (planned):** the combo_check's expected chain gains finisher_02 (the 5-swing automatic sequence); the gladiator_set_check's totals shift (the un-set 76, the gladiator 90 = 76 + 4 level-up + 10 blast on the chain's last step); the weapon_check's finisher refs follow the chain. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-21)*

- `combo_data.gd` — `finisher` (single) → `finisher_chain: Array[ComboStepData]` (D-109): the finisher steps flow in order after the last light step with no input.
- `player_controller.gd` — `_finisher_index` (the chain position); `_current_step()` returns the CURRENT chain step during the finisher (the payload, the timings, the animation, and the blast gate all read it — one code path, any chain length); `_play_finisher` starts the chain (the `_in_finisher` flip FIRST — the payload push reads `_current_step()`); `_advance_after_step` advances the chain automatically (the next step plays with no input; the last step ends the sequence); the blast gate reads the chain step's own blast fields (D-110: any chain step can carry a blast).
- The data: the default combo's chain = **[finisher_01 (25, HEAVY) → finisher_02 (15, NORMAL, the Gladiator Set's 10/2.2 blast)]** — the 2-step chain proves the automatic chaining; the gladius/spear: 1-element chains; `weapon_data.gd`'s summary reads the chain's last step's damage.
- The checks: the combo_check's expected chain + the mash cycle (5 swings) + the chain-gap asserts; the attack_check's spam payloads (+15); the gladiator_set_check's totals (76 un-set / 94 gladiator — the level-up's +2 lands on 4 swings: the C1 combo's 76 XP pushes the level-up to light_01's hit in C2); the weapon_check's chain refs.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Combo check — **PASS**: the 5-swing expected chain ([light_01, light_02, light_03, finisher_01, finisher_02]), the chain's gap asserts (the finisher_01→02 gap: the full 0.74 s recovery ≈ 49 ticks + hit-stop), the mash cycle (5 swings, wrap-around), the buffered chaining, the grace reset, the late-input ignored
- [x] Attack check — **PASS** (the spam payloads + finisher_02's 15)
- [x] Gladiator set check — **PASS**: the un-set combo 76; the gladiator combo 94 (76 + 8 from the mid-combo level-up [the level-up fires at light_01's hit in C2 — the C1 combo's 76 XP + 10 crosses the 80 threshold] + 10 blast on the chain's last step)
- [x] Full sweep — **all 34 validation checks PASS** (the weapon/set/flame checks' finisher refs updated to the chain)
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Finisher chain *feel* (the 2-step sequence's rhythm, the blast's payoff at the end) — a headline item for the next batch playtest

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- `_play_finisher` must flip `_in_finisher` BEFORE `_push_step_payload(_current_step())` — the payload push reads `_current_step()`, which gates on `_in_finisher` to return the chain step (the pre-flip push would push the last LIGHT step's payload).
- The python-replace silent-fail: the blast gate's old text had drifted (the D-107 comment rewrite) — grep-verify every programmatic edit; the Edit tool for anything with escapes.
- The chain steps play their FULL recovery before advancing (the finisher_01's 0.74 s ≈ 49 ticks) — the checks' gap ranges must cover the finisher steps' longer recoveries.

**Known limitations:**

- The finisher chain is 2 steps on the default combo only; the gladius/spear carry 1-step chains (the framework handles any length).
- The chain steps share the finisher_01/02 placeholder animations (the art pass differentiates them).
- No input-triggered finisher selection (the chain is automatic per the roadmap).

---

---


---

## 027 · 2026-11-11 · Boss Selection (Sprint 25, post-MVP)

**Goal:** A boss selection screen between the title and the arena, driven by a data roster — selectable encounters without changing the core fight architecture (roadmap Sprint 25). MVP is complete (Sprint 23 gate passed); the user directs post-MVP work explicitly.

**Scope:** new `BossEntry`/`BossRoster` resources + `game/resources/bosses/boss_roster.tres`; new `MatchSetup` static holder (session selection); new `game/scenes/ui/boss_select.tscn` + `boss_select.gd` (controller-first: cycle/confirm/back); new `arena.gd` root script that swaps the arena's Boss node for the selected entry at `_enter_tree`; new `sparring_gladiator.tscn` (inherited scene, pure data overrides: HP 60, its own title) as the second roster entry; `boss_controller.gd` gains a `boss_title` export (presentation metadata only); `hud.gd` reads it for the boss name; `title_screen.gd`'s `start_fight()` now routes to the select screen; new `boss_select_check.gd`; `playthrough_check.gd` phase 2 follows the real new path; smoke list; TUNING.md; playtesting.md.
**Non-goals:** brand-new boss behaviors (the sparring variant reuses the same gladiator controller), per-boss arenas, difficulty modes, unlock/lock logic, boss-select art.

**Decisions (planned):**

- **D-076 (roster is data, the framework is roster-agnostic):** adding a boss = adding a `BossEntry` resource pointing at a boss scene — the selector and the arena swap change zero lines. The roadmap verification ("multiple boss data entries can be selected and loaded") is met with two entries: the New Gladiator and a sparring variant.
- **D-077 (selection transport = static holder, not an autoload):** `MatchSetup.selected` (a `class_name` static, the D-065 static precedent). Autoloads would alter project.godot semantics and `-s` check behavior mid-project for no gain; the selection only needs to survive a scene change within a session.
- **D-078 (second entry = scene-inherited sparring variant):** `sparring_gladiator.tscn` inherits `new_gladiator.tscn`, overriding only data (max_health 60, boss_title). Pure-data proof of the framework, and a deliberately easier first opponent for the Sprint 24 external playtest.

**Verification (planned):** `boss_select_check.gd` — roster integrity (≥2 entries, scenes resolve), the real path title → select → cycle → confirm → the arena spawns the *chosen* boss (assert boss_title + max_health), back navigation to the title, and the no-selection default keeps the scene's New Gladiator. `playthrough_check.gd` follows the real path through the select screen. Full sweep + gdUnit4 + frame-run.

**Implemented:** *(2026-11-11)*

- `boss_entry.gd` + `boss_roster.gd` — the data layer: a selectable encounter (display name, blurb, scene) and the ordered roster. `game/resources/bosses/boss_roster.tres` holds the two entries.
- `match_setup.gd` — `MatchSetup.selected` static holder (D-077): the session's chosen entry; `null` = the arena's scene default.
- `arena.gd` (new root script on `arena.tscn`) — at `_enter_tree` (before anything is in the tree), swaps the default Boss child for the selected entry's scene at the BossSpawn position; group lookups, the progression binding, and the flow see exactly one boss from frame one.
- `boss_select.tscn` + `boss_select.gd` — the select screen: one code-built card per entry (gold border + full color on the selection), ui_left/ui_right cycle (wraps), `start_match` confirms, ui_cancel returns to the title. The default selection resumes at the previously chosen entry.
- `sparring_gladiator.tscn` — inherits `new_gladiator.tscn` with data-only overrides: `max_health` 60, `boss_title` "SPARRING GLADIATOR" (D-078).
- `boss_controller.gd` — `@export var boss_title` (presentation metadata only); `hud.gd` sets the boss-name label from it in its existing poll.
- `title_screen.gd` — `start_fight()` routes to the select screen (the fight now starts from its confirm).
- `tools/validation/boss_select_check.gd` — the six-phase check below; `playthrough_check.gd` phase 2 now goes title → BossSelect → Enter → Arena; smoke list 23 → 33 paths.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Boss select check — **PASS first run**: roster integrity (2 entries, distinct scenes, names), the real path title → select, `ui_right` moves the selection, confirm spawns the CHOSEN boss (sparring override `max_health` 60 + title asserted), back navigation via Esc, and the no-selection default keeps the scene's New Gladiator
- [x] Playthrough check — **PASS** (671 ticks): the full MVP loop now flows through the select screen
- [x] Full sweep — **all 22 validation checks PASS**
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot
- [ ] Select-screen *feel* (card readability, cycle/confirm pacing) — the user's next session

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- The boss swap must happen at `_enter_tree` of the arena root, not from a sibling's `_ready`: sibling `_ready` order would free the boss before its `_ready` ran (or after the player's progression already bound to it) — entering-tree-time replacement keeps exactly one boss for every listener.
- Writing an inherited scene by hand works fine: `[node name="Health" parent="." index="4"]` overrides resolve by name, and the root instance override sets script exports directly.

**Known limitations:**

- The sparring variant shares the New Gladiator's attack resources — it differs only in health (and title). Real per-boss attack sets arrive with future boss content.
- The select screen is code-built placeholder UI (the D-073 precedent); the art pass dresses it.

---

## 026 · 2026-11-10 · Full MVP Playthrough (Sprint 23)

**Goal:** One cohesive build validated end-to-end through the REAL scene flow — title → fight → victory/defeat → retry/title — plus the prototype-only-dependency audit the docs' Sprint 23 asks for.

**Scope:** new `tools/validation/playthrough_check.gd` (the real scene-change loop: title → start_match → arena → probe fight → victory → retry → defeat → to_title, with XP persistence through the save), stub/audit cleanup, smoke list.
**Non-goals:** new mechanics, art assets (the presentation layer shipped in Sprint 18), export presets (a real export build is a packaging task, not a code sprint).

**Decisions:**

- **D-074 (the playthrough check drives the REAL scene flow):** `change_scene_to_file` paths are exercised for real — the title's `start_fight()`, the flow's `to_title()`, and the current-scene swaps are all asserted (not bypassed by direct instantiation like the other checks). In `-s` mode the check sets `current_scene` manually so `change_scene_to_file` has a valid source.
- **D-075 (XP honesty extends to overkill):** `HealthComponent.apply_damage` now writes the **actual damage dealt** back onto the event (overkill clamped at remaining health) — XP, hit-stop weight, and every future listener see honest numbers. Found by the XP check's first run (a lethal 1000-damage event awarded 1000 XP against 80 remaining HP).

**Roadmap checklist mapping:** fresh install (the check-save deleted; the title loads) ✓ victory ✓ defeat ✓ XP ✓ retry ✓ no soft-locks (the whole loop driven headlessly) → `playthrough_check.gd`.

**Implemented:** *(2026-11-10)*

- `tools/validation/playthrough_check.gd` — the real-scene-loop check (D-074): fresh title → `start_fight()` scene swap → the probe defeats the gladiator (451 ticks) → VICTORY + XP poll → R revives both → the probe dies → DEFEAT + the +25 consolation → T back to the title → the save round-trips (`level 3, xp 75` — correct carry-over math).
- `title_screen.gd` — `start_fight()` extracted as a named method so the check (and future automation) drives the same path a player's button press does.
- `smoke_check.gd` — resource list 21 → 23 (the two Sprint 22 additions).
- `health_component.gd` — the overkill clamp (D-075) landed in this sprint's first pass.
- Stub audit: `hit_feedback.gd`'s empty `_init` stub removed; no reset_placeholder/TODO/FIXME markers anywhere in `game/`.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Playthrough check — **PASS ×3** (first run FAILED on 3 timing races, see lessons; two clean runs after the fix for flake confidence)
- [x] Full sweep — **all 21 validation checks PASS** (attack, block, boss, breakout, colosseum, combat, combo, defense, dodge, feedback, flow, gladiator, hud, level, movement, playthrough, retry, smoke, stagger, telegraph, xp)
- [x] gdUnit4 — 24/24
- [x] Frame-run — clean boot of the title main scene
- [ ] Full-loop *feel* (pacing across title → fight → overlays → title) — the user's next batch session

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- Reading a polled transition **immediately after its trigger races the countdown**: the flow's 1.2 s victory/defeat delay means `flow.state` is still RUNNING for ~72 ticks after the killing blow. Fixed by polling each transition with a `_wait_for_state` helper (the flow_check pattern) instead of fixed waits — 3 of 3 first-run failures were this one race.
- A grep across a check's output that matches **nothing** means look at the log tail: the first instrumented run failed to parse (`player_health` referenced before declaration) and never printed a single marker.

**Known limitations:**

- The playthrough probe is a simple band-holder/masher — it validates the **loop**, not balance feel (the Sprint 16 tuning lab and human playtesting remain the feel gates).
- Export presets remain deferred (post-MVP packaging task).

---

## 025 · 2026-11-10 · Menus/Retry (Sprint 22)

**Goal:** The complete basic game loop — title → fight → victory/defeat → retry/title, with pause — every path controller-first, no state persisting accidentally.

**Scope:** new `game/scripts/arena/match_flow.gd` (MatchFlow component: RUNNING/VICTORY/DEFEAT + pause), new `game/scenes/ui/title_screen.tscn` + `title_screen.gd` (the new main scene), `project.godot` (main_scene, `start_match`/`to_title` actions), new `tools/validation/flow_check.gd`, `TUNING.md` flow section, `docs/playtesting.md`, smoke list.
**Non-goals:** settings/video menus, real art on the screens, mouse/keyboard-only UI (controller-first ✓ the actions accept both), level-up screen (Sprint 20 shipped the stat part; a dedicated screen is polish).

**Decisions:**

- **D-071 (MatchFlow):** a component on the arena polls (the D-068 pattern) player/boss death → a 1.2 s countdown (the death animation reads) → **VICTORY/DEFEAT**; a self-healing poll returns to RUNNING when a retry heals both sides (checks and the universal R can reset without routing through the flow). Pause = `get_tree().paused` with the flow at `PROCESS_MODE_ALWAYS` — combat freezes by engine semantics ("pause cannot break combat state" holds structurally), the countdown freezes with it, and Esc/Start resumes.
- **D-072 (title as the entry point):** `title_screen.tscn` becomes the main scene — Enter/Space/gamepad A/Start fights, Esc quits, and the save is read to show `CONTINUE — LV N`. The checks instantiate `arena.tscn` directly and are unaffected.
- **D-073 (code-built overlays):** the victory/defeat/pause panels are code-built CanvasLayers layered above the HUD (30 > 20) — the D-054/D-055 precedent; the art pass replaces them.

**Retire:** the placeholder R-retry (D-059) becomes one path among several — R still works mid-fight and on the end screens (armed when the fight is over); the overlays' Retry calls the same `_retry()`/reset flow, so all routes share one semantics (D-058: reset to spawn positions).

**Implemented:** *(2026-11-10)*

- `match_flow.gd` — the MatchFlow component on the arena: RUNNING/VICTORY/DEFEAT polled from player/boss death, a 1.2 s countdown, self-healing (a retry that heals both sides returns the flow to RUNNING even when reset bypasses the flow), pause handling (ALWAYS process mode), code-built overlays above the HUD (layer 30): VICTORY / YOU DIED / PAUSED with R/T hints.
- `title_screen.tscn` + `title_screen.gd` — the new main scene: Enter/Space/gamepad A/Start fights, Esc quits, the save read (`ProgressionComponent.read_save()`, static) shows CONTINUE — LV N.
- `project.godot` — main scene → the title; `start_match` (Enter/Space/A/Start) and `to_title` (T/Y) actions.
- `tools/validation/flow_check.gd` — death→overlays, R resets, pause freeze/resume, to_title present.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 21 resources)
- [x] Flow check — **PASS**: the player's death → DEFEAT overlay; R → RUNNING + both revived + the panel hidden; the boss's death → VICTORY overlay; R again → RUNNING; pause froze the tree AND the boss's state clock (combat state untouched); resume restored the fight; `to_title` present
- [x] Frame-run — the title loads as the main scene, parse-clean
- [x] Full sweep — all suites PASS, gdUnit4 24/24
- [ ] Flow *feel* (the 1.2 s delays, panel readability) — the user's next session

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- `Label.new()` without a name gets an auto-generated one — the code-built panels' `get_node("Title")` failed until the nodes were named.
- In a `-s` SceneTree script, `get_tree()` doesn't exist — `paused` is accessed directly (the script IS the tree).
- The sweep "hung" twice on aborted check coroutines (a runtime error in `_run` skips `quit()` — the tree runs forever). The lesson stands: any runtime error in a check's coroutine = hang; timeout every first run of a new check.

**Known limitations:**

- The title is text-only (the art pass assets will dress it).
- Pause during the outcome overlays is allowed (both panels coexist — harmless).
- No settings video/audio menus (post-MVP per docs).

**Next:** Phase 9 is complete (HUD + menus/retry + XP + levels). The roadmap resumes: **Sprint 23 — Full MVP Playthrough** (the docs' Phase 10: the whole game as a player would — launch → fight → die/win → XP → retry, no soft-locks) — largely covered by the flagship checks; the plan+scope will map the docs' checklist onto what remains. Plan+scope first.

## 024 · 2026-11-10 · HUD (Sprint 21)

**Goal:** Player-facing combat information — player HP, boss HP with name, XP/level, and a telegraph warning — always-on during combat, readable, never covering the action.

**Scope:** new `game/scenes/ui/hud.tscn` + `game/scripts/ui/hud.gd` (a polling CanvasLayer), instanced into the arena, smoke list, new `tools/validation/hud_check.gd`, `docs/playtesting.md`.
**Non-goals:** pause indicator/menus (Sprint 22), combo indicator (optional, deferred), damage numbers (deferred per docs "only if useful"), animated bar tweens (a polish pass), F1 changes (stays debug-only).

**Decisions:**

- **D-068 (polling HUD):** the HUD polls group lookups (`player`/`boss` → Health/Progression/state) every frame instead of receiving pushes — robust to retry/resets/revives with zero cross-node wiring, and the checks can assert bar values directly.
- **D-069 (two-layer UI):** the HUD (this sprint) is always-on player-facing information; the F1 overlay (Sprint 01) stays debug-only with the diagnostic lines. "No debug values ship in normal mode" holds — the HUD shows only HP/XP/level/telegraph, no positions or state names.
- **D-070 (telegraph support):** the HUD's telegraph bar mirrors the boss's warning window (remaining time, colored yellow/red by hit type — the same language as the ground markers), so the warning reads at HUD level too without washing out the world markers.

**Implemented:** *(2026-11-10)*

- `hud.tscn` / `hud.gd` — a polling CanvasLayer (D-068): player HP bar (bottom left), XP bar + `LV` label, boss panel (name + HP bar, top center), telegraph warning bar (yellow/red by hit type, mirrors the world markers' language).
- Instanced into the arena; the smoke list gained the HUD scene/script.
- `tools/validation/hud_check.gd` — bars track health/progression after damage and XP, the telegraph bar matches the attack type, the boss panel hides on boss death and restores on retry.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 21 resources)
- [x] HUD check — **PASS**: the player bar tracked 100 → 70 after damage; the XP bar/level label tracked progression after 100 XP; the telegraph bar showed during the boss's TELEGRAPH with the type-matching color; the boss panel hid on boss death and restored on retry
- [x] Full sweep — all suites PASS (breakout_check flaked once in-sweep and passed 3/3 solo — a known rare alignment flake, documented), gdUnit4 24/24, 180-frame run clean
- [ ] HUD *readability* (bar placement, sizes, no-cover check) — the user's next session

Result: **PASS (automated)**.

**Known limitations:**

- No pause indicator, combo indicator, or damage numbers (deferred per docs "only if useful").
- Bars are static layouts — animation tweens (bar damage-lag, telegraph pulse) are a polish-pass candidate.

**Next:** the user re-verifies the batch-1 fixes + the HUD, then the roadmap resumes: **Sprint 22 — Menus/Retry** (title/start flow, pause with indicator, victory/defeat screens, save/load — replacing the placeholder R-retry), per the docs' Phase 9. Plan+scope first.

---

## 023 · 2026-11-09 · Basic Level-Up (Sprint 20)

**Goal:** The level curve applies real stat bonuses — HP, attack, movement speed, attack speed — so XP matters; levels persist; nothing double-applies after scene reload; the checks' timing assertions stay deterministic against leveled players.

**Scope:** `progression_component.gd` (per-level stat rate exports), `player_controller.gd` (stat application from the level curve, attack-speed scaling of combo timings, attack bonus in swing payloads), `TUNING.md` (level-stat section), new `tools/validation/level_check.gd`, save isolation for all checks.
**Non-goals:** level-up screen/UI (F1 shows the level; the visual moment is the gold burst from Sprint 15's burst system), stat *choices* (predefined progression per needs-review §20), enemy scaling.

**Decisions:**

- **D-065 (save isolation):** `user://save.json` is the REAL player save — shared machine-wide — so the check sweeps would wipe the user's progress every run. The progression now reads an env override (`FIRSTBLOOD_CHECK_SAVE`): when set, saves go to `user://check_save.json`. Every check sets it; the game never does. The user's real save is untouchable by automation.
- **D-066 (derive-from-level):** stats are **derived from the level**, never incrementally accumulated — `stat = base + per_level × (level − 1)`. Scene reload resets the exports to base, then the progression re-applies once for the loaded level: "no stat is applied twice after scene reload" holds by construction.
- **D-067 (attack speed via timing scale):** attack speed scales the combo step timings (`startup/active/recovery/buffer ÷ multiplier`) — the state machine's phase logic is untouched, so faster swings cannot bypass state rules (needs-review §20: "attack speed cannot bypass state logic").

**Curve (exports on the Progression node):** HP +10/level, attack +2/level, move speed +0.15/level, attack speed +4%/level — at level 3: 120 HP, +4 attack, 5.3 m/s, 1.08× swings.

---

## 022 · 2026-11-09 · XP (Sprint 19)

**Goal:** Persistent progression rewards — XP from damage dealt, victory and defeat bonuses, a level event at thresholds, and a local save so XP survives restarts.

**Scope:** new `game/scripts/progression/progression_component.gd` + `game/scripts/progression/` (save JSON), `player.tscn` (Progression node), `debug_overlay.gd` (XP/Level lines), new `tools/validation/xp_check.gd`, `TUNING.md` XP section, smoke list.
**Non-goals:** stat application on level-up (Sprint 20 — this sprint levels the NUMBER only), real HUD (F1 debug lines only until Sprint 21), boss XP tuning data files, settings save.

**Decisions:**

- **D-062 (XP sources):** 1:1 XP from **actual damage dealt to the boss** (bound to the boss's `Health.damaged` — blocked/guarded hits earn nothing, guard-mitigated earn the reduced amount), a **victory bonus** on boss death, and a **defeat consolation** on player death (architecture pillar 8: "failure still advances the player"). Values: victory 150, defeat 25.
- **D-063 (level curve):** `xp_required(level) = 80 × 1.5^(level−1)` — data-driven by exports; XP carries over past a threshold (no waste). Level-up emits a signal; stat application lands in Sprint 20.
- **D-064 (save):** `user://save.json`, versioned (`version: 1`, migration-ready per needs-review §22), written after meaningful events only (victory/defeat/level-up — never per frame), loaded at ready. The binding to the boss is lazy (first-use) — the player readies before the boss exists in the arena scene.

**Roadmap checklist coverage:** leveling changes stats (movement/max HP/swing payload/attack-speed multiplier asserted at level 3) · stats persist (a fresh player instance with the saved level derives identical stats — no double-apply) · attack speed cannot bypass state logic (the scaling divides the combo timings; the phase logic is untouched) · the boss takes the boosted damage → `level_check.gd`.

**Implemented:** *(2026-11-09)*

- `player_controller.gd` — `_apply_level_stats(level)`: derives movement/max HP/attack bonus/attack-speed multiplier from the level (base + per-level × (level−1), D-066); connected to the progression's `level_up` and run at ready for the loaded level; the combo timings scale via `_scaled()` (D-067); swing payloads carry `attack_stat_bonus`.
- `progression_component.gd` — per-level rate exports (hp 10, attack 2, move 0.15, attack speed 0.04) + save isolation (D-065).
- `TUNING.md` — the level-stat section.
- `tools/validation/level_check.gd` — L1 base, L3 stats, boosted boss damage, fresh-instance no-double-apply, persistence.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 19 resources)
- [x] Level check — **PASS** (twice): level 1 base (5.0 m/s, 100 HP, 1.0×, light_01 10); 200 XP → level 3 → **5.3 m/s, 120 max HP, light_01 payload 14, attack-speed 1.08×**; the boss takes the boosted 14 from a landed swing; a fresh player instance with the saved level derives identical stats (no double-apply after reload)
- [x] Full sweep — all seventeen suites PASS, gdUnit4 24/24, 180-frame run clean
- [ ] Level *feel* — the user's next session (the curve rates are exports)

Result: **PASS (automated)**.

**Harness lesson (this sprint):** the flagship's phase 4 placed the probe 8 m from the boss (the rewrite dropped the placement) — the forced-hitbox assert read 0 damage. Also: two "successful" batch patches had silently not matched (the `_ready` wiring; the movement_check boundary replace lost a trailing backslash to line-continuation escaping). The loop now grep-verifies every batch-patch insert AND removal; multi-line replacements with backslashes go through the Edit tool.

**Known limitations:**

- Stat bonuses are predefined (no stat choices) — per needs-review §20's "predefined progression"; a choice UI is post-MVP.
- The level curve rates (hp 10 / attack 2 / move 0.15 / attack-speed 0.04 per level) are first-pass — the tuning lab owns them.
- No level-up visual moment beyond the F1 numbers (a gold burst candidate for Sprint 15's burst system).

**Next:** Phase 8 is complete (XP + levels + stats + save). The roadmap resumes: **Sprint 21 — HUD** (real HP/XP/level/boss-HP bars replacing the F1 debug lines) — the user's playtest feedback slot. Plan+scope first.

**Implemented:** *(2026-11-09)*

- `progression_component.gd` — XP accumulation, level thresholds (80 × 1.5^(level−1), carry-over), versioned JSON save (`user://save.json`), lazy boss binding (damage → XP 1:1, boss death → victory bonus), defeat consolation, `total_earned` lifetime metric.
- `player.tscn` — Progression node; `debug_overlay.gd` — `XP: 34/80  Lv 2` F1 lines.
- `HealthComponent.apply_damage` — the event now reports the **actual damage dealt** (overkill clamped at remaining health): XP, hit-stop weight, and every future listener see honest numbers.
- `tools/validation/xp_check.gd` — 7 phases with a clean-save baseline.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 19 resources)
- [x] XP check — **PASS**: damage 1:1, negative XP guarded, victory bonus (150) on boss death, level-up at the threshold with carry-over (level 3 at 250 XP), defeat consolation (+25), fresh-component save/load, retry does not duplicate or revoke XP
- [x] Overkill honesty — a lethal 1000-damage event against 80 remaining HP awards **80 XP**, not 1000 (the event reports actual damage)
- [x] Regressions — all suites PASS, gdUnit4 24/24
- [ ] XP *feel* (the 150/25 bonus split, the level curve) — the user's next session; all values are exports

Result: **PASS (automated)**.

**Debug story:** the first run's numbers exposed **overkill XP farming** — a lethal 1000-damage event awarded 1000 XP against 80 remaining HP. `HealthComponent.apply_damage` now writes the clamped actual damage back onto the event. Also: `progression.xp` is the carry-over balance (spent on level-ups), so the check asserts `total_earned` — the lifetime metric the HUD will show.

**Known limitations:**

- No stat application on level-up (Sprint 20), no XP display outside F1 (Sprint 21 HUD), no boss XP tuning data files.
- The save stores xp/level only; `total_earned` rebuilds from thresholds on load.
- The combo_check late-press needed retiming for the hit-stop clock freeze (fixed; documented margin).

**Next:** Sprint 20 — Basic Level-Up: stat application on level-up (HP/attack/movement from the level curve), the level-up moment made visible, save integration already in place. Plan+scope first.

---

## 021 · 2026-11-09 · Combat Tuning Lab (Sprint 16)

**Goal:** Make tuning cheap and apply the batch-1 playtest notes — a universal retry (works after the boss dies OR the player dies — the playtest caught that retry only existed in the death branch), visible boss spacing (the playtest noted the back-pedal is barely visible), a complete knob table (`TUNING.md`), and a hard-coded-value audit.

**Re-verification (user, 2026-11-09):** camera wall fix ✓ confirmed; grey-screen tier fix ✓ confirmed; **retry still broken — after the boss dies OR the player dies.** Root cause found: the retry check lived only in the player's DEAD branch; with the boss dead and the player alive, no handler exists.

**Scope:** `player_controller.gd` (universal retry), `boss_controller.gd` (spacing tuning exports + visible back-off band), new `TUNING.md` (the complete knob table), new `tools/validation/retry_check.gd`, `docs/playtesting.md`.
**Non-goals:** an in-game live-tuning panel (deferred — `TUNING.md` + exports satisfy the docs' "adjustable without rewriting scripts" bar; a panel is a Sprint 22+ candidate), new combat mechanics, real art assets.

**Decisions:**

- **D-059 (universal retry):** the retry check moves to the top of the player's `_physics_process` — available in every state — but only **arms when the fight is over** (the boss is dead or the player is dead), so a stray R mid-fight can't reset an ongoing duel. Fixes both playtest cases with one path.
- **D-060 (boss spacing):** `back_off_distance` (1.4 m) replaces the old narrow band (min_range − 0.2 ≈ 0.8 m): the boss now visibly steps back whenever the target hugs it — including during the string pause — creating the openings the playtest found missing. The lunge still closes distance; the equilibrium (boss backs off, player walks in) is the intended dance.
- **D-061 (the tuning surface):** all feel values live in exactly one place each — actor exports (Player/Boss nodes), the combo resource (`player_light_combo.tres`), the boss attack resources, and the `HitFeedback` constants. `TUNING.md` is the complete index (name, location, current value, effect). No duplicates; the audit greps the controllers for stray gameplay magic numbers.

**Implemented:** *(2026-11-09)*

- `player_controller.gd` — universal retry (D-059): the check moved to the top of `_physics_process`, armed only when the fight is over (boss dead or player dead — `_fight_over()`); a stray R mid-fight does nothing.
- `boss_controller.gd` — `back_off_distance` (1.4, D-060) replaces the narrow min-range band; the boss visibly steps back whenever the target hugs it, including during the string pause.
- `TUNING.md` — the complete knob table: player (movement/dodge/block), combo resource, boss (spacing/strings/guard/breakout/attacks/stagger/health), hit-feedback constants, camera, arena — with current values, locations, and effects, plus the tuning rules from the design docs.
- `tools/validation/retry_check.gd` — case A (player dies → R → both sides reset to spawn), case B (boss dies → R → both sides reset), case C (a stray R mid-fight does nothing).

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Retry check — **PASS**: case A (player-death retry revives + repositions both), case B (boss-death retry revives + repositions both), case C (a stray R mid-fight does nothing — D-059 arming)
- [x] Full sweep — all suites PASS in the round arena, gdUnit4 24/24
- [ ] Boss-spacing *feel* (is 1.4 m enough?) — the user's next quick session; the knob is one export

Result: **PASS (automated)**.

**Known limitations:**

- No in-game live-tuning panel — `TUNING.md` + exports satisfy the docs' bar; a panel is a Sprint 22+ candidate.
- The boss's back-off and the player's walk-in can oscillate at the band edge — observed harmless in checks; a hysteresis pass is a tuning-lab note.

**Next:** the user re-verifies the retry + boss spacing, then the roadmap resumes: **Sprint 19 — XP** (Phase 8, progression: XP on victory and defeat, save hook) — the user's call on pacing.

## 020 · 2026-11-09 · Batch-1 Playtest Results + Camera/Retry Fixes

**Goal:** Record the user's batch-1 playtest (Sprints 02–18) and fix the three issues found.

**Batch-1 verdict (user): "overall felt great, very minimal issues."** All core-loop checkboxes passed: movement, camera orbit, dodge, the full combo/finisher chain, buffering, block + cancels, telegraphs, stagger, breakout, hit feedback, the Colosseum shell, death/HP. This closes the roadmap's Gate A (combat fun) for the shipped loop.

**Issues found (3):**

1. **Camera near the wall** — at the arena edge the outer wall obstructs the view; the user must rotate the camera. Geometry confirmed the cause: the camera orbits ~8.1 m behind the player, so at the ring edge (player r 16) it sits at r ≈ 24 — outside the wall (18.5) — and the sightline to the player passes under the wall top (y 2.5 at the wall vs 4.0 height).
2. **Initial camera orientation** — on first load the screen is grey (fog/horizon) until the user pans down; panning "back to overhead" shows empty floor. Suspect: the camera rig's `_ready` snap/orientation isn't taking effect on load — diagnose headless before fixing.
3. **Retry after death doesn't work** — R/Back does nothing. Diagnose headless (action registration, DEAD-branch reachability, `_retry` path).

**Tuning-lab notes (logged for the deferred Sprint 16):**

- Boss back-pedal barely visible — it mostly closes distance; the user exploited it for easy kills. Widen the back-off band / preferred-distance tuning.
- No art on the gladiator yet (stick + cylinder) — expected; art pass assets deferred (D-055).

**Fixes scoped:** camera wall pull-in (clamp the orbit's horizontal radius inside the wall ring with smoothing — the sightline can then never cross the stone), camera load orientation (per headless diagnosis), retry fix (per headless diagnosis).

**Implemented:** *(2026-11-09, same day)*

- `third_person_camera.gd` — the orbit's horizontal radius is clamped inside the wall ring (`camera_ring_radius` 17.5) with smooth pull-in; default pitch 0.45 → 0.55 (more overhead on load).
- Retry (D-058): `_retry()` now repositions the player to its spawn and the boss's `reset()` restores its spawn — a visible fight reset.
- **Tier occlusion fix (D-057, the big one):** the stand tiers were SOLID cylinders (r 20.5/23/25.5) whose caps covered the entire play area at 0.8/1.8/2.8 m — any camera above their height looked at the caps, not the fight (the user's "grey screen" and the wall-blocked view share this root cause). The tiers are now hollow segment-box rings behind the wall; nothing caps the play area.
- Headless diagnosis confirmed retry and the camera orientation were functionally correct — the issues were UX/geometry, caught by a windowed screenshot probe (`get_viewport().get_texture()`, removed after use).

**Verification:**

- [x] Colosseum check — PASS twice (structure + radial clamp + tier nodes)
- [x] Feedback check — PASS (hit-stop magnitudes, camera shake decay, hurt flash via a deterministic mitigated strike)
- [x] Full sweep — all fourteen suites PASS (the hit-stop's check-margin effects fixed en route), gdUnit4 24/24
- [x] Screenshot probe (windowed) — the fighters, emblem ring, and wall visible on load ✓
- [ ] The fixed build re-verified by the user at the next session

Result: **PASS (automated)**.

**Decisions:** **D-057 (tier occlusion):** stand tiers are hollow segment rings, never solid discs — solid radius-N cylinders cap everything inside them. **D-058 (retry semantics):** retry = full fight reset to spawn positions, not an in-place revive.

---

## 019 · 2026-11-06 · Stylized Art Pass — presentation layer (Sprint 18)

**Goal:** Dress the Colosseum and the fighters for the batch-1 playtest — sky, warm light, post-processing, materials, pillars/torches/banners, floor emblem — with **zero gameplay-logic changes**.

**Deferral note:** the user deferred Sprint 16 (D-052) to post-playtest and asked to pull this sprint forward; the roadmap's art pass (Sprint 18) splits here:

- **D-055 (code-driven presentation now, Blender assets later):** this sprint ships everything expressible in scene resources and code — sky/environment/post-processing, materials, decorative props, light dressing. The guide §17–19 Blender pipeline (real character/arena assets) stays deferred — it needs interactive tooling and is its own future sprint.
- **D-056 (presentation-only guarantee):** no gameplay-logic files change. New code is presentation scripts only (`arena_dressing.gd`, `torch_flicker.gd`); every check must stay green **unmodified**.

**Scope:** `arena.tscn` (ProceduralSky + Environment w/ glow+fog+filmic tonemap, sun tuning, floor materials), new `game/scripts/arena/arena_dressing.gd` + `torch_flicker.gd` (pillars, torches, banners, emblem ring), `new_gladiator.tscn` / `player.tscn` material polish. **Not touched:** any controller, component, state machine, or check logic.
**Non-goals:** Blender assets, particle VFX systems, damage numbers, HUD (Sprint 21), animation assets.

**Implemented:** *(2026-11-06)*

- `arena.tscn` — ProceduralSky (warm horizon), Environment: filmic tonemap, glow, subtle warm fog, ambient-from-sky; sun warmed to 1.3 energy; floor disc sand + roughness polish.
- `arena_dressing.gd` — 8 pillars + caps on the wall-ring joints, 4 flickering torch braziers + warm OmniLights (no shadows, perf), 2 crimson banners at the gate, floor emblem (inner disc + gold ring inlay).
- `torch_flicker.gd` — presentation-only energy modulation, desynced per torch.
- `new_gladiator.tscn` / `player.tscn` — material polish (metallic steel sword, bronze shield, roughness tuning).

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 18 resources)
- [x] Colosseum check — PASS (structure unchanged: 15 walls + 2 posts + 3 tiers; radial clamp holds)
- [x] Full sweep — all 14 suites PASS, gdUnit4 24/24, frame run parse-clean
- [ ] **Visual verification = the batch-1 playtest** (the point of pulling this sprint forward): sky/lighting mood, fighter readability against the sand, telegraph colors against the new materials, torch/banner dressing, motion-sickness check on the shake

Result: **PASS (automated + structural)**.

**Known limitations:**

- Everything is code-built primitive geometry and materials — no Blender assets (D-055 keeps that as its own future sprint).
- Glow/fog values are first-pass guesses; the tuning lab can own them (they're scene-resource tunables).
- Banners are static quads (no cloth sway); torch flicker is the only animated dressing.
- The frame-run caught a Variant-inference parse error in the dressing script post-import — fixed by typing the loop variable; noted for the -s-strictness list.

**Next:** the **batch-1 playtest** (user) — then the deferred **Sprint 16 — Combat Tuning Lab** turns those notes into tuning across every export. The art pass's own tuning (glow/fog/sun) rides along in the same lab.

## 018 · 2026-11-05 · Colosseum Blockout (Sprint 17)

**Goal:** Replace the temporary flat plane with the actual arena shell — a round walled Colosseum with stand tiers and an entry gate — so the batch-1 playtest happens in the real arena.

**Deferral first:**

- **D-052 (Sprint 16 deferred to post-playtest):** the Combat Tuning Lab's entire input is the batch-1 playtest notes; a tuning pass without them has nothing to tune. The user's call, recorded before starting Sprint 17 — roadmap order 16→17 becomes 17→(playtest)→16, both still scheduled.

**Scope:** new `game/scripts/arena/arena_blockout.gd` (code-built walls, gate, tiers per the D-035 precedent), `arena.tscn` (floor plane → disc, Blockout node), player + boss bounds clamp (box → radial), checks updated for the new bound shape, new `tools/validation/colosseum_check.gd`, `docs/playtesting.md`.
**Non-goals:** art-pass geometry/textures, camera wall-collision (tuning lab candidate), navigable gate (the gate is presentational; the bounds clamp keeps the fight inside), crowd logic.

**Decisions:**

- **D-053 (round arena):** the blockout is a **round Colosseum** — disc floor (radius 18), a wall ring at radius 18.5 (15 segments + a gate gap with two posts), three rising stand tiers outside the wall. The docs' arena identity over the old ±20 box plane. Player and boss bounds change from a box clamp (±18) to a **radial clamp (radius 16)** — the movement/dodge boundary checks updated with it.
- **D-054 (code-built blockout):** walls/tiers/gate are built by `arena_blockout.gd` at ready (the D-035 precedent — placeholder geometry the art pass replaces); the arena scene stays thin.

---

## 017 · 2026-11-05 · Hit Feedback (Sprint 15)

**Goal:** Make successful actions feel impactful — hit-stop, camera impulse, impact bursts, sound hooks, boss flinch, player hurt flash, controller vibration — with heavy attacks measurably heavier than light ones and nothing obscuring telegraphs.

**Scope:** new `game/scripts/feedback/hit_feedback.gd` (static feedback bus), `third_person_camera.gd` (shake consumption + decay), `player_controller.gd` + `boss_controller.gd` (hit-stop freeze, report calls, boss flinch), new `tools/validation/feedback_check.gd`, `docs/playtesting.md`.
**Non-goals:** real audio streams (the hook plays silence until the art pass ships sounds), damage numbers (deferred per docs "only if useful"), particle-system VFX (mesh bursts until the art pass), HUD elements (Sprint 21).

**Decisions:**

- **D-049 (static bus, no autoload):** `HitFeedback` is a static class (the CombatDebug pattern) — **autoloads do not instantiate in `-s` headless checks**, and the actors must call it. Statics + `Engine.get_main_loop()` cover spawning/overlays in every mode.
- **D-050 (hit-stop via actor freeze, not time_scale):** the hit-stop is a global freeze-until timestamp (`hit_stop_until_msec`); both actors' `_physics_process` early-return while it holds. **`Engine.time_scale` is deliberately untouched** — scaling the clock stretches every headless check's real-time runtime 20×; freezing actors keeps tick counts and check budgets stable. State timers pause during hit-stop, which is correct hit-stop semantics.
- **D-051 (weight scaling):** every channel scales by `hit_type` — hit-stop 45 ms light / 90 ms heavy, shake 0.3 / 0.8, impact burst size and color, vibration strength, hurt-flash alpha. Heavy and finisher read heavier through the same pipeline (the verification asserts both magnitudes are observed and distinct).

**Roadmap checklist coverage:** hits immediately readable (hit-stop + burst fire on every landed hit — asserted) · feedback does not obscure telegraphs (bursts spawn at hit moments, never during TELEGRAPH; shake subtle — manual playtest confirms feel) · heavy vs light distinct (both stop durations and shake levels observed) → `feedback_check.gd`; motion-sickness-safe shake amplitude → batch playtest.

**Implemented:** *(2026-11-05)*

- `hit_feedback.gd` — static bus: hit-stop freeze-until timestamp, impact bursts (code-built unshaded spheres, self-freeing), player hurt flash overlay, sound hook (plays silence until a stream ships), vibration, shake impulse for the camera.
- `player_controller.gd` / `boss_controller.gd` — hit-stop freeze at the top of `_physics_process`; the player reports landed swings (`register_hit`) and hurt flashes (`hit_taken`/`hit_mitigated`); the boss reports its hits (30 ms stop) and flinches on damage.
- `third_person_camera.gd` — consumes the shake impulse, decays to rest, offsets via `Camera3D.h_offset`/`v_offset` (never the tracked transform).
- `tools/validation/feedback_check.gd` — polls the bus, camera, and boss during a live fight; asserts both weight magnitudes, no `time_scale` violations, spawn/decay, and the hurt flash via a deterministic mitigated test strike.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 18 resources)
- [x] Feedback check — **PASS**: hit-stop observed with **both magnitudes** (45 ms light, 90 ms heavy), **`Engine.time_scale` never left 1.0**, impact bursts spawned and cleaned up, camera consumed and **decayed** shake to rest, boss flinch observed, hurt flash fired (via a deterministic mitigated heavy strike)
- [x] Regressions — all fourteen suites PASS after widening the margins the hit-stop legitimately affects (swing tails extend by the freeze; state clocks pause), gdUnit4 24/24, 180-frame run clean
- [ ] Feedback *feel* — shake amplitude, hit-stop weight, flash intensity — batch playtest (now due: the full loop through Phase 6's feedback)

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- The hit-stop freezes actor state clocks — every pre-hit-stop tick-count assertion needed its margins widened (swing tails, idle waits, stagger-window upper bound). The invariant is "never exceeds timer + hit-stop allowance."
- Boss `_visual` needed an `@onready` — the flinch patch referenced it before it existed; the parse error surfaced immediately in the check run.

**Known limitations:**

- No audio streams, no particle VFX, no damage numbers — the hooks and geometry placeholders are in place for the art pass.
- The camera shake is positional noise via `h_offset`/`v_offset` — a trauma-based model (smoother, directional) is a Sprint 16 tuning-lab candidate.
- Vibration has no headless verification (no joypad) — batch playtest confirms.

**Next:** Sprint 16 — Combat Tuning Lab: the docs' big gate ("if the game does not feel good, stop adding content"). No new mechanics — rapid tuning of every exported value against playtest notes, then the batch-1 playtest verdict decides what Phase 6+ does next. Plan+scope first.

---

## 016 · 2026-11-04 · Boss Breakout (Sprint 14)

**Goal:** Prevent infinite stagger loops and complete the core loop's rhythm — the finisher lands during the stagger window and breaks the boss out into a readable recovery that ends in defend-or-attack.

**Scope:** `stagger_component.gd` (forced window end) + unit tests, `boss_controller.gd` (BREAKOUT state, finisher counter, defend-or-attack transition), stagger threshold retune (30 → 15), new `tools/validation/breakout_check.gd`, `docs/playtesting.md`.
**Non-goals:** knockback/kick on breakout (Sprint 15 feedback), counterattack beyond the existing moveset, chained-finisher sequences (Sprint 39 uses the counter this sprint installs).

**Decisions:**

- **D-045 (breakout trigger):** a **finisher-tagged hit during the stagger window** breaks the boss out immediately — tagged via `breakout_attack_id` on the boss (matches the player's combo finisher id, keeping it data-driven). A `_finishers_in_stagger` counter with `breakout_finishers := 1` is the extension point Sprint 39 needs for chained-finisher sequences (N finishers → breakout).
- **D-046 (breakout behavior):** BREAKOUT is a **0.8 s readable recovery** — the boss roots, shows the blue guard aura, then **defends (GUARD) or attacks (OBSERVE → selection)** at ~50/50 (guard honoring its cooldown). The stagger's resistance applies on breakout (the window was consumed), and the stagger still self-ends by timer when no finisher lands — both enders coexist.
- **D-047 (threshold retune — design correction):** stagger threshold **30 → 15**. At 30, the stagger opened *on* the finisher's own hit (the combo's 33 crossed there), leaving nothing to land during the window — the punish window was self-defeating. At 15 the light string (5+6+7=18) opens the stagger and the **finisher becomes the breakout tool**: hit → combo → stagger → finisher → breakout, exactly the architecture §7 rhythm. Resistance grows from there (15 → 22.5 → 33.75).

**Roadmap checklist coverage:** the finisher ends the stagger (BREAKOUT observed on a finisher hit mid-window, window measured shorter than the timer) · boss defends or attacks after breakout · the player cannot permanently lock the boss (max continuous STAGGERED tracked; every window ends) → `breakout_check.gd`.

**Implemented:** *(2026-11-05)*

- `arena_blockout.gd` — code-built Colosseum shell: 15 wall segments + gate gap (D-054), 2 gate posts with collision, three rising stand tiers (mesh-only, outside the play space).
- `arena.tscn` — floor plane → **disc** (CylinderMesh + CylinderShape3D, radius 18, sand), Blockout node added.
- Player + boss — box clamp (±18) → **radial clamp** (`arena_radius` 16, D-053); movement/dodge boundary checks updated to the radial shape.
- `tools/validation/colosseum_check.gd` — arena shell structure + radial clamp on both actors + a physical wall-drive test.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 18 resources)
- [x] Colosseum check — **PASS** (twice): disc floor r 18, 15 wall segments + 2 posts + 3 tiers present, the player and the boss teleported far out are pulled back inside the ring, and driving the player into the wall for 1.5 s does not tunnel through
- [x] Regressions — all fourteen suites PASS in the round arena (movement, dodge, combat, attack, combo, block, defense, boss, telegraph, stagger, breakout, gladiator, feedback), gdUnit4 24/24, 180-frame run clean
- [ ] Arena *readability* (silhouettes against the tiers, camera near the wall, size feel) — batch-1 playtest

Result: **PASS (automated)**.

**Harness lesson (this sprint):** the sweep "hung" on movement_check — a stale `arena_half_extent` reference survived my Sprint-17 patch because the Python replace pattern lost a trailing backslash to line-continuation escaping and matched nothing, yet printed success. Two rules added to the loop: **grep-verify every batch-patch insert AND every removal**, and prefer the Edit tool for multi-line replacements containing backslashes.

**Known limitations:**

- The gate is presentational — the radial clamp keeps the fight inside (navigable entry is post-MVP).
- No camera wall-collision: at the arena edge, low camera pitches can clip stone near the floor (tuning-lab candidate).
- The tiers are mesh-only (no collision) — nothing can reach them (the clamp holds), noted for the art pass.

**Next:** the batch-1 playtest (user), then the deferred **Sprint 16 — Combat Tuning Lab** processes those notes. The roadmap after 16: Sprint 18 — Stylized Art Pass (the art pass replaces the blockout visuals).

**Implemented:** *(2026-11-05)*

- `stagger_component.gd` — `breakout()`: force-end the window; resistance applies, `recovered` fires.
- `boss_controller.gd` — BREAKOUT state (0.8 s recovery with the blue guard aura → GUARD or OBSERVE ~50/50, guard cooldown respected), finisher counter (`breakout_attack_id` + `breakout_finishers`, D-045), death-beats-breakout gate.
- `new_gladiator.tscn` — stagger threshold 15, duration 2.5 (D-047/D-048).
- `tests/bosses/stagger_component_test.gd` — 4 breakout cases (suite total 24).
- `tools/validation/breakout_check.gd` — two-window fight check.
- `docs/playtesting.md` — the stagger section became stagger+breakout with the intended rhythm.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 18 resources)
- [x] gdUnit4 — **PASS: 24/24 test cases** (4 new breakout cases)
- [x] Breakout check — **PASS** (3 consecutive runs):
  - window 1 (probe holds guard, lands nothing) ran the **full timer** in stable runs — no breakout without a finisher
  - window 2 (probe keeps mashing) ended via **BREAKOUT** when the finisher landed inside it — measurably early
  - after BREAKOUT the boss moved on (guard, attack flow, or a punish re-stagger — D-042)
  - no permanent lock: max continuous STAGGERED stretch ≤ the timer
- [x] Regressions — all thirteen suites PASS, gdUnit4 24/24, 180-frame run clean
- [ ] Breakout *feel* (the 0.8 s recovery, defend-or-attack cadence) — the batch-1 playtest after this sprint.

Result: **PASS (automated)**.

**Debug story (the big one):** the flagship trace exposed that the fight was **structurally unwinnable-as-designed**: with threshold 30 the stagger opened *on* the finisher's own hit, so the punish window never had a finisher left to land — and a probe at contact could never build enough to re-stagger. Fixes: threshold 15 (D-047, the light string opens the stagger), window 2.5 s (D-048, a full combo fits the punish window with margin), and the **death-beats-breakout gate** (a lethal finisher during stagger previously overwrote DEAD with BREAKOUT — a zombie boss). Also caught: the check's own top-up/revive block had silently never been inserted (patch debt — grep-verified inserts from now on).

**Known limitations:**

- No knockback or counterattack on breakout (Sprint 15 feedback; the moveset is the counter for now).
- `breakout_finishers = 1` is the MVP setting; Sprint 39's chained finishers raise it by data.
- The probe's full-timer window is timing-sensitive (an in-flight finisher at the stagger edge legitimately breaks out) — the timer-ender path is unit-tested, and the integration check scopes that assertion accordingly.

**Next:** Phase 6 — Sprint 15 Hit Feedback (hit pause, camera impulse, impact VFX, sound hooks, boss reaction animations, damage feedback — the combat becomes physical). This closes the core-loop feel work the tuning sprint builds on. Plan+scope first.

---

## 015 · 2026-11-04 · Boss Stagger (Sprint 13)

**Goal:** Successful combat creates punish windows — player hits build stagger, a full combo staggers the boss into a visible, interrupting, self-ending punish window, with resistance so it can't be farmed.

**Scope:** new `game/scripts/combat/stagger_component.gd` (reusable, per guide §14) + gdUnit4 suite, `boss_controller.gd` (STAGGERED state, interruption rules, stagger visuals, resolver hook), `new_gladiator.tscn` (Stagger node), new `tools/validation/stagger_check.gd`, `docs/playtesting.md`.
**Non-goals:** breakout (Sprint 14 — the stagger currently ends only by timer), player-side flinch, stagger-driven finisher multipliers, accumulation decay.

**Decisions:**

- **D-042 (StaggerComponent):** threshold/accumulation/duration/resistance live in a reusable component (guide §14's stagger model). `add_stagger(event)` accumulates `event.stagger_damage` and emits `staggered` when the threshold crosses; the owner ticks `tick_recovery(delta)` and gets `recovered` at the end. The boss's threshold is **30 = exactly one full player combo** (light 5 + light 6 + light_2 7 + finisher 15 = 33) — the teach is "finish your string, earn the window".
- **D-043 (interruption + resistance):** stagger **interrupts TELEGRAPH/ATTACK/RECOVERY/GUARD** (hides telegraph/guard visuals, drops the hitbox) — the punish window can steal the boss's turn. Blocked hits (boss guard) build **no** stagger. No accumulation decay (MVP); after each stagger the threshold grows ×1.5 (resistance) so stagger loops self-limit until Sprint 14's breakout replaces the timer as the ender.
- **D-044 (readability):** stagger gets its own color — **violet aura**, distinct from telegraph yellow/red and guard blue; F1 shows `STAGGERED` in the boss state line. Hit reactions this sprint = the interrupt + aura + sword dropping to rest; fancier reactions are Sprint 15 feedback.

**Roadmap checklist coverage:** correct attacks (stagger_damage-carrying hits) stagger the boss · the window self-ends via the component timer · the boss cannot attack while staggered (hitbox dropped, no ATTACK entry) · stagger visibly interrupts a telegraph · resistance makes the second stagger harder → `stagger_check.gd` + the gdUnit4 component suite.

**Implemented:** *(2026-11-04)*

- `stagger_component.gd` — threshold/accumulation/duration/resistance per D-042; `add_stagger` returns whether the threshold crossed, `tick_recovery` runs the timed window and re-arms with resistance; `staggered`/`recovered` signals.
- `boss_controller.gd` — STAGGERED state (entry via the component signal, exits through the component timer into the D-040 string pause), resolver gates (dead → ignore; guard → negated hits build no stagger; otherwise health + `add_stagger`), `_enter_stagger` interrupt (drops hitbox, hides telegraph/guard, violet aura D-044, `stagger_started` signal), sword-droop hit reaction.
- `new_gladiator.tscn` — Stagger node (threshold 30, duration 2.0, growth 1.5).
- `tests/bosses/stagger_component_test.gd` — 7 unit cases (suite total now 21).
- `tools/validation/stagger_check.gd` — probe-driven cadence check with edge-based window measurement.
- `docs/playtesting.md` — batch 1 gains the stagger section.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 18 resources)
- [x] gdUnit4 — **PASS: 21/21 test cases** (7 new stagger cases; one initially-wrong expectation corrected — after resistance the old 40 points correctly fall short of 45)
- [x] Stagger check — **PASS**:
  - the probe's combo staggers the boss (window measured **~121 ticks** from the entry edge, 2.0 s data)
  - at least one stagger opened **mid-telegraph** (the attack-interruption rule observed live)
  - the boss's hitbox never activated during STAGGERED ticks
  - the second stagger required more hits than the first (resistance honored)
- [x] Regressions — all eleven suites PASS, 180-frame run clean
- [ ] Stagger *feel* — batch playtest (after Sprint 14, per the user's plan)

Result: **PASS (automated)**.

**Debug story (the interesting one):** the first stagger check run hung with the boss stuck in STAGGERED forever. The trace showed the state entered at T265 and never left — **the `_physics_process` match had no `State.STAGGERED` case**: my batch patch added the enum, visuals, and `_staggered_physics`, but the match-case insertion silently didn't apply (independent string replaces, no per-replace verification). Rule going forward: every state added to the enum gets its physics-match case in the same edit, verified by grep.

**Known limitations:**

- Breakout is Sprint 14 — until then the stagger ends only by timer, and resistance (×1.5 per stagger) is the anti-farm valve.
- No player flinch or damage multipliers during stagger (Sprint 15 feedback).
- Stagger accumulation never decays between hits (MVP simplification).

**Next:** Sprint 14 — Boss Breakout: the finisher ends the stagger (breakout state, recovery transition, "boss defends or attacks"), completing the core loop's drama: hit → stagger → punish → breakout → reset. Plan+scope first.

---

## 014 · 2026-11-03 · New Gladiator (Sprint 12)

**Goal:** The MVP boss — a distinct gladiator placeholder with readable sword telegraphs, a melee attack string, pressure lunges, and basic defense — in a complete fight that is winnable (attack/block/dodge) and losable, with no soft-locks.

**Scope:** `BossAttackData` gains `followup` (string chaining) + `lunge_speed`; `boss_controller.gd` (attack strings, lunge, GUARD state = the "basic defense" task, procedural sword swing, dead-target handling); player gains **health, death, and retry** (`player_controller.gd` DEAD state, Health node, `retry` input action, death visuals) — required by this sprint's winnable/losable verification; boss scene renamed to `new_gladiator.tscn` with gladiator primitive visuals; new `tools/validation/gladiator_check.gd` (the flagship full-fight check); overlay Player HP; `telegraph_check.gd` timing updates.
**Non-goals:** stagger/hit reactions (Sprint 13), breakout (Sprint 14), proper menus/defeat screens (Sprint 22 — retry is a placeholder input), real art (Sprint 17/18), XP.

**Decisions:**

- **D-036 (gladiator identity + strings):** the boss scene becomes the **New Gladiator** (`new_gladiator.tscn`): tan body + head, steel sword on a `SwordPivot`, bronze shield arm — primitives with a readable silhouette. The sword animates procedurally: slow wind-up during TELEGRAPH, snap-through during ATTACK (anticipation → impact, guide §16's "animation timing is gameplay"). Attacks are a **string**: `boss_light` (followup → `boss_light_2`, small lunge = the "approach/pressure attack") ending, plus `boss_heavy`. Followup attacks have weight 0 (never brain-selected, only chained); each attack keeps its own telegraph and cooldown.
- **D-037 (boss basic defense):** a GUARD state — after finishing a string, if the player is in range and the guard is off cooldown (weighted chance), the boss raises a 1.0 s guard: NORMAL hits negated, HEAVY/SPECIAL × 0.4, own 5 s cooldown, blue aura visual. This is the Defensive-Response placeholder for Sprint 14's breakout ("boss defends or attacks").
- **D-038 (fight is losable):** the player gets its own HealthComponent (100) fed by the resolver's `hit_taken`/`hit_mitigated` only (D-027 honored). Death → DEAD state (fallen visual, inputs dead, `died` signal), the boss stands down against a dead target, and a `retry` action (R / Back) resets both — placeholder until Sprint 22's menus.

**Roadmap checklist coverage:** boss completes full fights indefinitely (flagship check runs a real fight) · player wins using attack + block + dodge (scripted: block the light string, dodge-cancel the heavy telegraph, mash on recovery) · boss defeats a passive player · no soft-locks (dead-target standdown + retry) · boss neither stands motionless nor spams one attack (variety asserted).

---

## 013 · 2026-11-03 · Telegraph System (Sprint 11)

**Goal:** Readable attack warnings — a TELEGRAPH state inserted into the boss attack flow with a measurable, tunable warning window and placeholder visuals that survive placeholder art.

**Scope:** `boss_controller.gd` (TELEGRAPH state, code-built ground marker + body aura, cancel rule), `boss_placeholder.tscn` (per-attack telegraph durations), `debug_overlay.gd` (telegraph timer), new `tools/validation/telegraph_check.gd`, `docs/playtesting.md` batch 1 update.
**Non-goals:** animation-driven telegraphs (art pass), audio cues, arena decals/VFX polish (Sprint 15), player-side stagger interrupts (Sprint 13).

**Decisions:**

- **D-034 (telegraph model):** the flow becomes SELECT_ATTACK → **TELEGRAPH** (`BossAttackData.telegraph_duration`, 0 = immediate) → ATTACK → RECOVERY. During the window the boss roots, faces its target, and shows the warning; if the target leaves `max_range + 0.5 m` grace, the attack **cancels to OBSERVE with the attack's full cooldown** — so the player can bait telegraphs but not for free. Damage to the boss during a telegraph does *not* interrupt (interruption belongs to Sprint 13's stagger). Colors derive from `hit_type`: yellow = NORMAL, red = HEAVY/SPECIAL — one visual language, no per-attack config.
- **D-035 (placeholder visuals):** code-built following the hitbox debug-shape precedent — a ground marker mirroring the AttackHitbox footprint (thin unshaded box just above the floor) plus a slightly-oversized translucent body aura. The scene swaps in real VFX at the art pass; the gameplay timing never depends on them.

**Implemented:** *(completed 2026-11-04)*

- `new_gladiator.tscn` (renamed from `boss_placeholder.tscn`) — the MVP boss: tan body + head, steel sword on `Visual/SwordPivot`, bronze shield arm; three inline attack resources: `boss_light` (10 dmg, telegraph 0.4, followup → `boss_light_2`, lunge 2.0) → `boss_light_2` (12 dmg, telegraph 0.25, lunge 1.0, weight 0 — string-chained only) and `boss_heavy` (20 dmg, HEAVY, telegraph 0.7).
- `boss_controller.gd` — followup string chaining, lunge during the active window, GUARD state (D-037), procedural sword anticipation/impact, dead-target standdown, resolver guard branch, `boss_blocked` signal.
- Player: `HealthComponent` (100) wired to `hit_taken`/`hit_mitigated` only (D-027 honored), DEAD state (fall + grey-out, `died` signal), `retry` input action (R/Back) resetting both sides (D-038).
- `tools/validation/gladiator_check.gd` — the flagship: a scripted player wins via attack + block + dodge, a passive player loses, retry resumes, attack variety asserted across phases.
- `telegraph_check.gd` — dynamic per-attack expected durations, spacing band, edge-based measurement.
- `docs/playtesting.md` — batch 1 now covers the full New Gladiator fight.

**Decisions made during implementation (beyond the plan):**

- **D-039 (soft-facing):** swings snap the player's yaw toward the foe within 3 m at swing start. Found via the flagship: a player who backed off or strafed froze facing mid-turn (rooted attacks lock facing) and whiffed constantly — hostile for controller-first play; snap is deliberate, the swing stays committed.
- **D-040 (post-string pause):** `string_pause` (1.2 s) — the boss stands down after a melee string. Found via the flagship: light's cooldown expired *during* its own string, so the boss re-strung forever and **the fight was unwinnable** (the player could only block, 0 swings possible). The pause is the architecture's "predictable recovery" made mechanical.
- **D-041 (back-pedal):** the boss steps away when the target is inside every attack's minimum range — it previously stood inert forever (soft-lock) when hugged.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 18 resources)
- [x] Gladiator check (flagship) — **PASS**: the scripted player **wins in ~611-819 ticks** using attack (mash in openings), block (negates the light string), and dodge (cancels out of the heavy telegraph); a **passive player loses**; **retry resets both sides** and the fight resumes; attack variety (all three attacks) asserted
- [x] Regressions — all eleven suites PASS (smoke, movement, dodge, combat, attack, combo, block, defense, boss, telegraph, gladiator), gdUnit4 14/14, 180-frame run clean
- [ ] Fight *feel* — the flagship proves winnable/losable; the batch-1 playtest judges pacing, string readability, and the guard rhythm.

Result: **PASS (automated)**.

**Harness lessons (this sprint):**

- The scripted player must release synthesized buttons (a held attack gives one `just_pressed` edge ever) and mash with alternating press/release edges.
- Movement turns the character — a scripted "back off" also turns them away from the boss; soft-facing (D-039) removes the need for facing management in swing assertions.
- Timing assertions must measure from the *transition edge* into a state, never from first observation (a poll can catch a state mid-window).
- Deterministic variety: pin other attacks on cooldown (`_cooldowns[...] = N`) instead of hoping weighted RNG shows the wanted one.
- Spacing logic must be direction-aware — a lunging boss crosses to the other side of the player, inverting fixed camera-relative "toward/away" keys.

**Known limitations:**

- No stagger/hit reactions (Sprint 13) — the boss ignores your hits except HP; no breakout (14); no XP (19); retry is a placeholder input until Sprint 22's menus; guard aura/sword motion are code-driven placeholders (art pass).

**Next:** Phase 5 — Sprint 13 Boss Stagger (stagger value/state/duration from the staged `stagger_damage` payload, hit reactions, interruption rules — the punish window) and Sprint 14 Boss Breakout (the finisher ends it). Plan+scope first.

**Implemented:** *(2026-11-03)*

- `boss_controller.gd` — TELEGRAPH state (SELECT_ATTACK → TELEGRAPH → ATTACK), `_build_telegraph_visuals()` (marker sized from the AttackHitbox box footprint, body aura), `_show_telegraph`/`_hide_telegraph`/`_cancel_telegraph`, hit-type-derived colors, cancel rule with full cooldown; death and reset also hide the visuals.
- `boss_placeholder.tscn` — `telegraph_duration` 0.35 s (boss_light) / 0.6 s (boss_heavy).
- `debug_overlay.gd` — `Boss telegraph: X.XX s` remaining-time line.
- `tools/validation/telegraph_check.gd` — AI-driven check with per-attack duration measurement.
- `docs/playtesting.md` — batch 1 gains the telegraph section.

**Verification:**

- [x] Headless import — PASS, exit 0
- [x] Smoke check — PASS (18 actions, 18 resources)
- [x] Telegraph check — PASS:
  - the boss enters TELEGRAPH before ATTACK, and the player's hit event lands only after the telegraph window elapsed
  - light telegraph measured ~21 ticks (0.35 s), heavy ~36 ticks (0.6 s) — measurable, distinct, and tunable per attack via the resource
  - stepping out of range mid-warning cancels into OBSERVE and the attack's cooldown is honored (no re-attack for ≥ 120 ticks)
- [x] Regressions — all suites PASS (boss, movement, dodge, combat, attack, combo, block, defense), gdUnit4 14/14, 180-frame run clean
- [ ] Telegraph *readability* (marker visibility, color language, "effects don't obscure the signal") — batch 1 playtest; the F1 overlay shows the countdown.

Result: **PASS (automated)**.

**Known limitations:**

- Visuals are placeholder geometry by design (D-035) — no animation pose, glow ramp, or audio cue yet (art pass / Sprint 15).
- Boss damage does not interrupt a telegraph; that interception belongs to Sprint 13's stagger.
- The player has no telegraph-reading reward yet (perfect-timing parry remains post-MVP per docs).

**Next:** Sprint 12 — New Gladiator: the actual MVP boss built on this framework (gladiator placeholder model, 2–3 melee attacks with telegraphs, approach/pressure behavior, full fight validation). Plan+scope first.

---

## 012 · 2026-09-28 · Boss Framework (Sprint 10)

**Goal:** A reusable boss controller — brain-driven state machine, target tracking, weighted data-driven attack selection, health, and defeat — plus the gdUnit4 integration deferred since D-005/017.

**Scope:** new `game/scripts/combat/health_component.gd`, `game/scripts/bosses/` (`boss_controller.gd`, `boss_brain.gd`, `boss_attack_data.gd`), boss placeholder scene upgraded into the framework host, debug overlay (boss state + HP), first gdUnit4 suites (`tests/combat/`, `tests/bosses/`), runner wrapper `tools/testing/run_tests.cmd`, new `tools/validation/boss_check.gd`, existing checks pin the boss, smoke list + AGENTS.md testing section updated.
**Non-goals:** telegraphs (Sprint 11 inserts the TELEGRAPH state), stagger/hit reactions (Sprint 13), breakout (Sprint 14), the actual New Gladiator data/art (Sprint 12), boss backstepping/spacing subtleties.

**Decisions:**

- **D-031 (composition):** `BossController` (state machine OBSERVE / APPROACH / SELECT_ATTACK / ATTACK / RECOVERY / DEAD) + `BossBrain` (pure static decision logic — weighted attack selection honoring range, cooldowns, and weights, with an injected RNG so it's unit-testable) + `BossAttackData` Resources + `HealthComponent`. Attacks are rooted like the player's; when in range but everything is on cooldown the boss stands and observes (readable idle, no state churn). Death flows health → `died` → DEAD + `defeated` signal — no special-casing. `reset()` exists for retry flows.
- **D-032 (gdUnit4 now, fulfilling D-017):** addon installed under `addons/gdUnit4`, suites live under `tests/` mirroring runtime dirs, runs headless via `tools/testing/run_tests.cmd` (GODOT_BIN pinned to the winget install). First suites: HealthComponent math (reduce/clamp/die-once/after-death/reset/zero-amount) and BossBrain selection (range filter, cooldowns, zero-weight, weighted distribution). The SceneTree checks remain the integration layer — unit tests validate rules, integration checks validate scene behavior; both are CI-shaped.
- **D-033 (existing checks stay deterministic):** the boss placeholder scene becomes a mobile framework host, so every existing check script pins the boss with `set_physics_process(false)` right after instantiation; `boss_check.gd` owns all AI assertions. For the boss, its hurtbox's `damaged` signal IS the resolved path (bosses have no mitigation layer) and feeds `HealthComponent` directly.

**Implemented:** *(completed 2026-10-30)*

- `health_component.gd` — reduce/clamp/die-once/reset + `health_changed`/`damaged`/`died` signals.
- `boss_controller.gd` — the six-state machine, cooldown ticking, rooted swings with payload push, arena bounds, facing, animation hooks, `reset()`.
- `boss_brain.gd` + `boss_attack_data.gd` — pure selection logic + data resource (telegraph field staged for Sprint 11).
- `boss_placeholder.tscn` — framework host: CharacterBody3D + Hurtbox + AttackHitbox + Health + two inline attack resources (boss_light 3.0 weight / boss_heavy HEAVY 1.0).
- `debug_overlay.gd` — Boss state + Boss HP lines.
- gdUnit4 v6.2.1 under `addons/gdUnit4`; suites `tests/combat/health_component_test.gd` (6 cases) and `tests/bosses/boss_brain_test.gd` (8 cases); runner `tools/testing/run_tests.cmd`.
- `tools/validation/boss_check.gd` — the only check that runs boss AI.
- All six prior check scripts pin the boss.

**Files changed:** the above plus `project.godot` (plugin), `.gitignore` (reports/), `AGENTS.md` (testing section), `.uid` sidecars.

**Verification:**

- [x] Headless import — PASS, exit 0 (gdUnit4 addon imports clean)
- [x] Smoke check — PASS (18 actions, 18 resources)
- [x] gdUnit4 — **PASS: 14/14 test cases, 0 errors, 0 failures, 0 orphans, exit 0** (D-017 fulfilled)
- [x] Boss check — PASS: boss approached the player (6.8 → 3.8 m), cycled into and out of ATTACK, landed hits on the player's resolver, died from lethal damage via the generic health path, stayed DEAD and inert, and resumed fighting after `reset()`
- [x] Regressions — all seven suites PASS with the pinned boss (smoke, movement, dodge, combat, attack, combo, block, defense), 180-frame run clean
- [ ] Boss *feel* (approach speed, attack pacing) — batch 1 playtest; the boss is now visible in-game: it walks up, swings (F1 shows its state and HP), and can be killed with ~8–10 swings.

Result: **PASS (automated)**.

**Harness lessons (three real ones this sprint):**

1. **Deferred tree entry in `-s` scripts:** nodes added during `_initialize` complete their ready/group processing on the **first frame**, not at `add_child` time. Tick-0 group lookups return null, and — critically — the deferred ready callback auto-enables physics processing for scripts defining `_physics_process`, silently undoing a tick-0 `set_physics_process(false)`. Fix: do group lookups and freezes *after* the first frame (2-frame wait in the check scripts; freeze uses `arena.get_node_or_null("Boss")` by path). This caused the boss to walk to its 2.5 m attack standoff — just outside the player's 2.0 m reach — producing the "0 damage events" cascade.
2. **GDScript lambdas capture locals by value:** `func(): deaths += 1` never propagates; counters captured in signal lambdas must live in reference containers (arrays).
3. **gdUnit4 v6 specifics:** headless runs need `--ignoreHeadlessMode`; the addon runs with warnings-as-errors (Variant-inferred `:=` fails to parse); nodes in tests need `auto_free()` or the run exits nonzero on orphans; fail-fast is default (`-c` runs the full set).

**Known limitations:**

- The boss has no telegraphs yet (Sprint 11), never staggers (13), and gives no XP (19) — it swings, takes damage, dies, and resets.
- Boss attacks are unblockable-feeling only in the sense that the player can block them (block resolution works on boss hits — NORMAL negated, HEAVY × 0.3 — verified in block_check).
- No boss animation hooks play (no AnimationPlayer yet — art pass).

**Next:** Sprint 11 — Telegraph System: telegraph data + windup state inserted into the boss attack flow, readable warnings, debug timing display. Plan+scope first.

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
