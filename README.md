# Boss Arena Gladiator — "First Blood"

A controller-first 3D boss-rush gladiator game built around readable, responsive melee combat in a single reusable Colosseum.

You begin as an unequipped gladiator with a dull sword and no armor. Survive fights, earn XP even when you lose, level core stats, and eventually grow into weapons, armor, magic, finishers, and mobility builds — all against mechanically distinct mythological bosses. Deliberately **not** an MMO, a live-service game, or an open-world RPG.

> Enter arena → read the boss → attack / block / dodge → exploit stagger → finisher → earn progression → fight a mechanically different boss.

## Status

**Sprint 00 — Project Definition (in progress).** The design suite is complete; there is no game code yet. The live log of decisions and results is [`worklog.md`](worklog.md).

## Tech Stack

| Layer | Choice |
|---|---|
| Engine | Godot 4.x stable (exact version pinned at Sprint 01) |
| Language | GDScript |
| Art | Blender → glTF/GLB → Godot, stylized low-poly |
| VCS | Git, local saves, zero online dependencies |
| Target | 60 FPS on low/mid-range hardware |

## MVP Scope (frozen)

One Colosseum · one player · one boss (**New Gladiator**) · movement, dodge, light-attack chain with automatic finisher · generous-but-limited block · readable boss telegraphs · stagger & breakout · XP on victory *and* defeat · basic levels · HUD · pause/retry · debug combat overlay.

Everything else — mythological bosses, magic, gear sets, difficulty modes — is explicitly post-MVP. The full boundary and its exclusions: [`docs/architecture.md`](docs/architecture.md) §3.

## Repository Layout

```text
FIRSTBLOOD/
├── AGENTS.md          # working contract for AI agents (sprint loop, conventions)
├── README.md          # this file
├── worklog.md         # append-only sprint log
├── docs/              # design suite: architecture, roadmap, implementation guide
├── game/              # Godot project (scenes/, scripts/, resources/, shaders/)  — Sprint 01
├── assets/            # blender/ sources (gdignore'd), exported/ GLB, textures, audio
├── tools/             # blender scripts, validation, asset pipeline
└── tests/             # combat/, bosses/, progression/, smoke/
```

## Sprint Workflow

Every sprint runs the same loop — the full contract lives in [`AGENTS.md`](AGENTS.md):

1. **Plan + scope** the sprint in `worklog.md` before coding.
2. **Implement** the smallest complete change; one system at a time.
3. **Verify** — automated tests for rules + the sprint's manual checklist for feel.
4. **Commit + push** with conventional, sprint-referenced messages.
5. **Update `worklog.md`** with results, decisions, and next steps.

The roadmap's standing rule: *do not advance because code exists; advance because behavior is verified* — and if the fight isn't fun by the combat-tuning sprint, stop adding content and fix combat.

## Documentation

Reading order:

1. [`docs/architecture.md`](docs/architecture.md) — the game: pillars, MVP boundary, combat model, systems.
2. [`docs/sprint-roadmap.md`](docs/sprint-roadmap.md) — the plan: 52 sprints with verification checklists and exit gates.
3. [`docs/implementation-guide.md`](docs/implementation-guide.md) — the craft: scenes, state machines, timing data, pipelines.
