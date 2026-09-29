# AGENTS.md — Working Contract for AI Agents (and Humans)

**Boss Arena Gladiator** — a controller-first 3D boss-rush gladiator game (Godot 4.x + GDScript).
MVP codename **First Blood**: one Colosseum, one player, one boss ("New Gladiator"), one fun fight.

This file is the operating contract for any agent working in this repository.
If AGENTS.md conflicts with the design docs on *what* to build, the design docs win.
AGENTS.md governs *how* we work.

## Document Map

| File | Purpose |
|---|---|
| `docs/architecture.md` | What the game is: pillars, MVP boundary, combat model, systems, stack |
| `docs/sprint-roadmap.md` | The execution plan: sprint-by-sprint goals, tasks, verification, gates |
| `docs/implementation-guide.md` | How to build it: scenes, state machines, timing model, pipelines |
| `docs/needs-review(has details other docs dont).md` | Raw source draft — supersedes nothing; being mined for unique details. Not authoritative. |
| `worklog.md` | Append-only sprint log: what was done, verified, and decided |
| `README.md` | Project overview for newcomers |

**Required reading before touching code:** `architecture.md` → current sprint in `sprint-roadmap.md` → the relevant `implementation-guide.md` sections → the last 2–3 `worklog.md` entries.

## The Sprint Loop (mandatory, every sprint)

1. **Plan + scope** — Open `docs/sprint-roadmap.md` and read the current sprint. Start a new `worklog.md` entry *before coding*: goal (one sentence), scope (files/areas to touch), explicit non-goals. A sprint is done when its **Verification** section passes — not when the code exists.
2. **Implement** — the smallest complete change that satisfies the sprint's Tasks. One system at a time. Inspect existing files before replacing them; preserve working behavior (never remove working input/menu/save functionality without explicit instruction). If a task conflicts with the architecture, **stop and surface the conflict** instead of rewriting the project.
3. **Verify** — two layers, both required:
   - *Automated (rules):* headless test run (gdUnit4, fallback GUT) covering pure logic — damage math, state transitions, thresholds, save round-trips, data integrity.
   - *Manual (feel):* launch the game, execute the sprint's Verification checklist plus a regression spot-check of the previous sprint, using the debug overlay for timings.
   Record PASS/FAIL per item in the worklog entry.
4. **Commit + push** — conventional commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, `tune:`) referencing the sprint, e.g. `feat(player): dodge state with recovery (sprint 03)`. One commit per verified increment. Push only after verification passes; never push failing work to `main`.
5. **Update worklog.md** — complete the entry: implemented list, files changed, verification results, decisions made (with rationale), known limitations, next step.

## Hard Rules

- **MVP scope only.** Build only what the current sprint names. Never silently implement post-MVP systems (magic, gear sets, boss selection, difficulty modes, alternate modes).
- **Combat first.** If combat does not feel good by the tuning sprint (16), fix combat — do not add content to compensate (architecture §27, guide §34).
- **No soft-locks.** Every feature must survive a scene restart and work through the normal controller flow.
- **Controller-first.** No gameplay logic bound to physical buttons — only to input actions.
- **Data-driven.** Timing/damage values live in Resources (`AttackData`, `BossAttackData`, …), not scattered through scripts. Scenes define composition; resources define tunables.
- **Prototype with primitives.** A capsule gladiator is fine until combat is fun. A placeholder animation with correct timing beats a beautiful one with wrong timing.
- **Don't silently change design assumptions.** If something is unclear or a request requires unrelated infrastructure, stop, note it, and defer (roadmap Gate E).

## Godot / GDScript Conventions

- Engine: Godot 4.x **stable** — pin the exact validated version in `worklog.md` at Sprint 01 and do not change it mid-project.
- GDScript for MVP (no C#/.NET). Tabs for indentation (Godot default).
- File and directory names: `snake_case`. Classes and nodes: `PascalCase`. Signals: past tense (`hit_registered`).
- Read input only via `Input.is_action_just_pressed("dodge")` etc. — the input map is the single source of button truth.
- Player and boss behavior run through explicit state machines (guide §4). Every state defines entry / update / exit behavior and allowed transitions.
- Reusable components over god-scripts: `Hurtbox`, `Hitbox`, `HealthComponent`, `StaggerComponent` as shared scenes. Damage flows through a structured `DamageEvent` (guide §6) — never mutate another actor's HP directly.
- Keep `assets/blender/` (and any non-runtime source dirs) excluded from Godot import with a `.gdignore` file.

## Asset Naming

Prefix scheme (machine-parseable, required later by the Sprint 48 naming-validation automation):

```text
CHR_Player_Gladiator     characters
BOS_Minotaur             bosses
ENV_Colosseum            environment/arena
WPN_DullSword            weapons
PROP_Banner              props
ANM_Player_Light01       animations
```

Never: `final_final2`, `newboss`, `thing`, `SwordNew`. Blender sources live in `assets/blender/`; exported GLB goes to `assets/exported/`.

## Testing

- Framework: **gdUnit4** (validate at Sprint 01; GUT is the fallback). Tests live under `tests/` mirroring runtime dirs (`combat/`, `bosses/`, `progression/`, `smoke/`).
- Automated tests validate **rules**; human playtesting validates **feel**. Neither substitutes for the other.
- Anything that is pure logic gets an automated test the same sprint it is built.
- The runner must work headless (`godot --headless` + gdUnit4 CLI) so it can run in CI or without a display.

## Git

- Never commit: `.godot/`, `*.blend1`/`*.blend2`, local saves, logs, OS junk (see `.gitignore`).
- `.import` files and `export_presets.cfg` **are** committed.
- Local-only project: no secrets, accounts, or online services by design.

## Worklog Discipline

`worklog.md` is append-only history, newest entry first, one entry per sprint (or per meaningful session). Never rewrite past entries; corrections go in a new entry. Every decision gets an ID (`D-NNN`) so later entries and docs can reference it.
