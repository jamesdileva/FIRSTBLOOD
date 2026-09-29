# Worklog — Boss Arena Gladiator

Append-only sprint log. **Newest entry first.** One entry per sprint (or per meaningful session).
Never rewrite past entries — corrections go into a new entry. Decisions get stable IDs (`D-NNN`).

The entry template is at the bottom of this file.

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
