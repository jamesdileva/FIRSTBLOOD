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

### XP (Sprint 19)

- [ ] Dealing damage to the boss earns **XP 1:1** (F1 shows `XP: 34/80 Lv 2`
      growing as you land swings).
- [ ] Killing the boss pays a **victory bonus** (+150); dying pays a smaller
      **consolation** (+25) — failure still progresses you.
- [ ] XP thresholds trigger **level-ups** (level shown in F1); leftover XP
      carries toward the next level.
- [ ] XP **persists across game restarts** (saved on victory/defeat/level-up).
- [ ] Overkill damage doesn't over-reward (the final blow credits only the
      boss's remaining health).
- [ ] Retry doesn't duplicate or revoke XP.

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

### HUD (Sprint 21)

- [ ] **Player HP bar** (bottom-left) drains when the boss hits you and
      refills on retry/level-up HP gains.
- [ ] **Boss panel** (top): NEW GLADIATOR name + HP bar — appears when the
      fight starts, hides when the boss dies.
- [ ] **XP bar + LV N** label: fills as you deal damage, levels up visibly.
- [ ] **Telegraph warning bar** under the boss panel: drains while the boss
      warns; yellow for the quick string, red for the heavy — mirrors the
      world marker.

### Menus & match flow (Sprint 22)

- [ ] Launch → **title screen**: START FIGHT (Enter / Space / gamepad A or
      Start); Esc quits. With a save it reads `CONTINUE — LV N`.
- [ ] **Pause** (Esc/Start mid-fight) freezes everything — boss, timer,
      telegraphs; PAUSED overlay; pressing again resumes cleanly.
- [ ] Killing the boss: after a readable ~1.2 s beat, the **VICTORY**
      overlay appears (R — Retry, T — Title).
- [ ] Dying: the **YOU DIED** overlay with the same options.
- [ ] **No soft-locks**: R mid-fight, R on an overlay, T to title — every
      route lands somewhere sane, and starting a new fight from the title
      always works.

### Full MVP playthrough (Sprint 23)

- [ ] From a fresh install: title → fight → win → R → fight → die → T →
      the title now shows `CONTINUE — LV N` matching the XP you earned;
      relaunching the game keeps it (save round-trip).
- [ ] XP accrues through the **whole loop**: damage during the fight, the
      +150 victory bonus, the +25 defeat consolation — nothing lost at the
      overlays or the scene swaps.
- [ ] The entire loop is playable **controller-only** — no keyboard-only
      gate anywhere.

### Boss selection (Sprint 25)

- [ ] The title's START FIGHT now opens a **SELECT YOUR OPPONENT** screen:
      one card per boss, the selection highlighted in gold.
- [ ] **Left/Right (d-pad or arrows)** cycles the cards and wraps around.
- [ ] **A / Enter** starts the fight against the **chosen** boss; the HUD's
      boss name matches the card you picked.
- [ ] **SPARRING GLADIATOR** is a deliberately easier partner — same moves,
      visibly less health (60 vs 100); a good first opponent.
- [ ] **B / Esc** returns to the title from the select screen; starting a
      fight from there always works (no soft-locks).
- [ ] The selection **sticks** between fights in the same session —
      returning to the select screen re-highlights your last pick.

### Armory & gear (Sprint 26)

- [ ] The title opens the **ARMORY** with **G / gamepad X**.
- [ ] Four starter pieces, one per slot: UP/DOWN navigates, **A wears or
      removes**, worn pieces show a **WORN** tag and a brighter row.
- [ ] The **totals line** updates as you dress: HP, ARMOR, ATTACK, SPEED,
      SWING %.
- [ ] Wearing the **Legion Cuirass** raises max HP (the HUD bar) and every
      unblocked hit hurts 1 less; F1's Player HP shows the bigger pool.
- [ ] **Wrist Wraps** make every swing hit chunkier (+2 damage per swing).
- [ ] The loadout **survives** returning to the title, starting a fight,
      AND a full game restart (it lives in the same save as your level).
- [ ] B/Esc returns to the title from the armory; boss select and the
      fight still work with gear worn (no soft-locks).

### Weapons (Sprint 27)

- [ ] The armory now lists **three weapons** at the bottom (the WEAPON
      slot): DULL SWORD, LEGION GLADIUS, TRAINER'S SPEAR — wearing one
      swaps the old one out, and your blade mesh **recolors and resizes**
      to match.
- [ ] **Legion Gladius** hits noticeably harder (12/14/16 +28 finisher vs
      the sword's 10/12/14 +25) but recovers a touch slower.
- [ ] **Trainer's Spear** swings faster and lighter (8/9/11 +20 finisher)
      with a visibly longer blade.
- [ ] Unequipping the weapon (A on the worn row) returns you to the
      default sword and grey blade.
- [ ] The equipped weapon **survives** a game restart like other gear.
- [ ] The whole fight still plays the same with any weapon — same buttons,
      same combo rhythm, just different numbers (no controller changes).

### Deliberately not visible yet (by design — don't report as bugs)

- (Nothing — through Sprint 23 every MVP system has shipped. Post-MVP
  items — magic, gear sets, boss selection, difficulty modes — remain out
  by design.)
