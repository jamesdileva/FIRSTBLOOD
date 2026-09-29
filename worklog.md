# Worklog — Boss Arena Gladiator

Append-only sprint log. **Newest entry first.** One entry per sprint (or per meaningful session).
Never rewrite past entries — corrections go into a new entry. Decisions get stable IDs (`D-NNN`).

The entry template is at the bottom of this file.

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
