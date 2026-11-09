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

> **Batch 1 played (2026-11-09): all core items verified.** Three issues found and fixed the same day: the stand-tier cylinders occluded the fight from raised cameras (now hollow rings), the camera orbit now stays inside the wall ring, and retry now resets the fight to spawn positions (it previously revived in place). Remaining feel notes are logged for the deferred Sprint 16 tuning lab.

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

### The Colosseum (Sprint 17)

- [ ] The fight happens in a **round walled arena**: sand disc, stone wall
      ring with an entry gate and posts, three rising spectator tiers
      outside the wall.
- [ ] You and the boss stay **inside the ring** — hugging the wall, walking
      into it, lunging: nobody escapes or clips through.
- [x] The wall doesn't block your view at combat distance; the camera stays
      usable near the wall (no clipping through stone).
      *FIXED 2026-11-09 — the camera orbit now stays inside the wall ring;
      previously it orbited outside the wall at the arena edge and the stone
      blocked the view. Verified by windowed screenshot.*
- [ ] The arena feels big enough to dodge around the boss but not so big
      that combat feels empty.

### The New Gladiator (Sprints 10–12)

- [ ] The boss (tan gladiator with sword and shield) walks up and fights:
      a **two-swing sword string** (the second swing chains right after the
      first) plus a **heavy overhead** — the sword visibly raises during
      every warning, yellow marker for the string, red for the heavy.
- [~] It steps back when you hug it, lunges when you're far, and pauses
      after each string — you should feel openings to act.
      *PLAYTEST NOTE: the back-pedal is barely visible — the boss mostly
      closes distance. Logged for the Sprint 16 tuning lab.*
- [ ] It sometimes raises a **blue guard** after a string: your normal
      swings do nothing through it (heavies chip 40 %); wait it out.
- [ ] Hitting it drains its HP (F1 shows Boss HP); ~8–10 clean swings kill
      it — it stops and F1 shows DEAD.
- [ ] **You have 100 HP now** (F1 shows Player HP): the boss's sword hurts,
      the heavy hurts more, your block negates the light string. **You can
      die** — the gladiator falls, greys out.
- [x] **R / Back retries** the fight after death (placeholder until the
      real menus) — both sides reset.
      *FIXED 2026-11-09 — retry now resets the fight to spawn positions;
      previously it revived in place, which read as "nothing happened".
      Verified headlessly (physical R key event → both sides reset).*

### Boss stagger + breakout (Sprints 13–14)

- [ ] Land a full combo (string + finisher) and the boss **staggers**: violet
      aura, F1 shows `STAGGERED` for ~2.5 s, its sword droops — a free punish
      window. Keep swinging!
- [ ] Swinging **during the boss's own telegraph** can stagger it mid-warning,
      stealing its turn.
- [ ] **Land your finisher inside the stagger window and the boss BREAKS
      OUT** — blue flash, it recovers for a beat, then defends or attacks.
      This is the intended rhythm: stagger → punish → finisher → breakout.
- [ ] The window also closes on its own (~2.5 s) if you don't land the
      finisher — both endings should feel readable.
- [ ] Repeated staggers get **harder** (resistance builds each time) —
      intended pacing; the finisher-breakout is your reliable route.
- [ ] Blocked hits (the boss's blue guard) don't build stagger.

### Hit feedback (Sprint 15)

- [ ] Every landed swing has **weight**: a brief hit-stop freeze, an impact
      flash at the contact point, a small camera jolt.
- [ ] **Heavies and finishers hit harder** than lights: longer freeze,
      bigger orange burst, stronger shake, stronger vibration.
- [ ] Getting hit flashes the screen red (more on heavies) and vibrates.
- [ ] The boss **flinches** when damaged and its sword droops while
      staggered.
- [ ] None of it washes out the telegraphs or causes motion sickness.

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

- Boss stagger/reactions to your hits (Sprint 13), boss breakout (Sprint
  14), hit feedback like hitstop/VFX (Sprint 15), HUD other than F1
  (Sprint 21), XP (Sprint 19).
