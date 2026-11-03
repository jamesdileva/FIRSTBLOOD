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

### Boss framework (Sprint 10)

- [ ] The red boss walks up to you and swings (two attacks: a quick one and
      a heavier, slower one); F1 shows its state (OBSERVE/APPROACH/ATTACK/
      RECOVERY) and its HP.
- [ ] Hitting it drains its HP; ~8–10 clean swings kill it — it stops and
      F1 shows DEAD. (No restart flow yet, so relaunch to fight again.)
- [ ] Its quick swings can be blocked fully; the heavy one still hurts a
      little through a perfect-timing guard (30 %).
- [ ] You cannot be killed yet — your HP arrives in a later sprint.

### Telegraphs (Sprint 11)

- [ ] Before every swing the boss flashes and shows a ground marker in the
      danger zone: **yellow = quick attack, red = heavy attack**. F1 shows
      `Boss telegraph` with the remaining time.
- [ ] The heavy attack warns visibly longer than the quick one.
- [ ] Step out of range during the warning and the boss cancels (it then
      cools down before trying again).
- [ ] The warning is readable at normal camera distance and doesn't wash
      out the fight.

### Deliberately not visible yet (by design — don't report as bugs)

- Your own HP bar / death (Sprint 10+ for boss side, HUD Sprint 21), hit
  feedback like hitstop/VFX (Sprint 15), XP (Sprint 19).
