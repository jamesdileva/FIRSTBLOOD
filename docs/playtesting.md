# Playtesting — Running Batch Checklist

The automated suites in `tools/validation/` verify **rules** headlessly; this
file tracks what a human should **feel**-check. Playtest in batches every few
sprints: work through the current batch's items, note anything that feels off
(timing, weight, responsiveness), and report back. Feel-tuning knobs live as
Inspector exports on the Player node — the worklog's D-NNN entries name them.

**Launch:** `godot` in this folder (or open it in the editor, press F5).
**F1** toggles the debug overlay + red/green combat shapes.

---

## Batch 1 — Sprints 02–09 · Player foundation, offense, defense

### Movement (Sprint 02)

- [ ] WASD / left stick moves responsively; stops on a dime — no sliding after release.
- [ ] Movement is camera-relative; the player turns to face where they move.
- [ ] The player cannot leave the arena floor.

### Camera (Sprint 01)

- [ ] Camera follows smoothly; right stick orbits and pitches without clipping.

### Dodge (Sprint 03 + D-018 retune)

- [ ] B / L dashes fast in the held direction; no direction = camera-backward.
- [ ] Recovery (~0.15 s) never plants you — walking continues; only re-dodging
      is blocked until it ends. F1 shows the timer and a brief `i-frames ACTIVE`.
- [ ] Mashing dodge can't chain invulnerability.

### Attack & Combo (Sprints 05–07)

- [ ] J / Space / X swings — the 3-hit chain (light_01 → 02 → 03) plays
      start-to-finish with each swing fully committed.
- [ ] Pressing attack *slightly early* during a swing chains the next one
      automatically (buffering).
- [ ] Pausing mid-chain: a follow-up within ~0.35 s continues the chain;
      waiting longer resets to swing 1.
- [ ] Completing the chain fires the **finisher automatically** — heavier,
      slower, no extra button.
- [ ] Mashing produces swing → swing → swing → finisher cycles; the player
      never gets stuck.
- [ ] Dodging mid-chain resets the combo (next swing is swing 1).

### Block (Sprints 08–09)

- [ ] Hold K / LT: guard up after a short windup, lasts max ~2.5 s, then
      drops into a 0.75 s recovery **even while held**; re-engages after
      recovery. It can't be held forever.
- [ ] Slow walk while guarding; releasing early also enters recovery.
- [ ] F1 shows `Block timer` while guarding/recovering.
- [ ] Dodging or attacking during the guard **cancels** it (Sprint 09).
- [ ] A swing's **recovery** can be dodge/block-canceled (Sprint 09) —
      startup and the hit itself stay committed.

### Deliberately not visible yet (by design — don't report as bugs)

- Damage numbers / HP bars (Sprint 10+), hit feedback like hitstop/VFX
  (Sprint 15), HUD (Sprint 21), enemies that attack back (Sprint 10+).
