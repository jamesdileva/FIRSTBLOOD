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

### Mana (Sprint 28)

- [ ] A **blue mana bar** sits under the XP bar in the HUD, and F1 shows
      `Mana: 100/100 (full)`.
- [ ] It stays full during normal fighting — **nothing spends mana yet**:
      the spells that consume it arrive in the next two sprints. Don't
      report the unused bar as a bug; it's the surface being prepared.
- [ ] Retrying (R) keeps it full; a full scene restart spawns you with a
      full pool.

### Spell input (Sprint 29)

- [ ] **Hold LB and press A / B / X / Y** — each fires the slot's spell
      (all four are the ARCANE SPARK placeholder for now) and the **mana
      bar drops by 10** per cast. F1 shows the loadout.
- [ ] The casts are **mana-gated**: dry the pool (cast ~10 times quickly)
      and further LB+face presses do nothing until it regenerates.
- [ ] **LB up, the same buttons stay melee**: X still swings, B still
      dodges/blocks — holding LB never leaks a surprise swing when the
      pool is empty.
- [ ] Casting only works **on the ground while neutral** — mid-swing,
      blocking, or dodging, LB+face does nothing, and the swing you
      started finishes normally.
- [ ] Mana regenerates after its ~3 s delay as usual.

### The spell pool (Sprint 30)

- [ ] The four slots now carry **real spells** (LB + face):
      **A — HEAL** (25 mana, +30 HP, green flash), **B — FIREBOLT** (20, a
      16-damage bolt flies at the boss), **X — FREEZE** (30, the boss is
      rooted 2 s — ice-blue, but it can still swing if you're close),
      **Y — REFLECT** (35, 3 s: you flash cyan, incoming hits do nothing,
      and the attacker takes 10 back per hit).
- [ ] Each spell **costs differently** — the mana bar drains at different
      rates, and the ~3 s regen delay starts on every cast.
- [ ] **Heal can't overheal** (caps at max HP) and **can't revive** (a
      killing blow ends the fight regardless of mana).
- [ ] **Freeze reads as a window**: the boss stops walking but its
      telegraphs/swings continue — use it to escape or set up, not to
      face-tank.
- [ ] **Reflect** rewards baiting: cast it as the boss commits, and its
      damage comes back (reflected damage earns XP like real damage).
- [ ] Dry the pool (cast until empty) — presses do nothing while short,
      and nothing leaks into melee.

### The Minotaur (Sprint 31)

- [ ] The boss select screen now lists **three** opponents — pick
      **MINOTAUR** (third card): 150 HP, slower feet, harder to stagger.
- [ ] **Stay FAR and he charges**: a long red telegraph, then he crosses
      the arena fast — **dodge sideways**, not backward. Standing still
      far away is exactly what he wants.
- [ ] **Stay CLOSE and he swings/slams**: single heavy swings (no string)
      and a **ground slam** whose marked zone is visibly wider than his
      body — the yellow/red marker shows the true footprint.
- [ ] **The slam punishes point-blank hugging** — step out during the
      telegraph and it whiffs entirely.
- [ ] His rhythm feels **different** from the New Gladiator: no swing
      strings, heavier individual hits, and you should feel *pushed* to
      keep repositioning.
- [ ] Stagger/breakout works on him (harder threshold — a full combo
      still staggers), and killing him pays VICTORY + XP like anyone.

### The Medusa (Sprint 32)

- [ ] Fourth boss card: **MEDUSA** — 120 HP, frail (staggers easily —
      punish her windows), keeps her distance.
- [ ] **Ranged pressure**: at mid-long range she **spits green bolts** —
      close in by dodging through them; standing still at range means
      eating bolts.
- [ ] **The gaze is the threat**: a long telegraph at mid-range — if it
      lands you're **petrified** (stone-grey, fully locked ~1.5 s, a free
      hit for her). Don't linger in the mid-range band; blocking a gaze
      negates the petrify too.
- [ ] **The mirror**: she flashes **silver** for ~3 s — your hits do
      NOTHING and bounce back for 10. Stop attacking until it drops;
      punish right after.
- [ ] Her kit should force you to **adapt distance and timing** vs the
      other bosses: spit at range, cleave up close, gaze in between,
      mirror whenever you get greedy.
- [ ] Stagger/breakout, retry, XP, and the full fight loop all work
      against her like the others.

### The Giant Spider (Sprint 33)

- [ ] Fifth boss card: **GIANT SPIDER** — 110 HP, frail, and the fastest
      thing in the arena (3.2 m/s).
- [ ] **Webs slow you**: a pale-blue bolt at mid-long range — if it lands
      you're tinted and move at ~40% speed for 2.5 s. Dodging a web is
      easier than escaping after one lands.
- [ ] **Venom lingers**: its point-blank bite poisons you (green tint) —
      ~24 damage ticks over 4 s even after you disengage. **The HEAL
      spell's value just went up.**
- [ ] **The pounce punishes kiting**: a fast mid-range leap — dodge
      sideways as it lands, like the Minotaur's charge but shorter.
- [ ] The whole fight should feel like **status management**: webs slow
      your escapes, poison punishes trades, and the spider itself dies
      fast if you can pin it down (easiest stagger of all five).
- [ ] Poison can **kill you** — the defeat flow works from a DoT tick.
- [ ] Stagger/breakout, retry (clears webs/poison), XP, and the full loop
      all work against it like the others.

### The Giant Crab (Sprint 34)

- [ ] Sixth boss card: **GIANT CRAB** — 130 HP, slow, and **armored**: your
      swings deal ~3 less per hit against its shell.
- [ ] **The stagger is the payoff**: crack it (a full combo staggers it)
      and the shell **breaks** — hits inside the punish window deal FULL
      damage. Before the stagger, the shell grinds you down; inside it,
      unload everything.
- [ ] **Sweeping claws**: a two-sweep string with visibly **wider**
      danger zones than the other bosses' swings — the marked slabs reach
      wider than its body. Step BACK out of them, not sideways along them.
- [ ] **Shorter openings**: its recoveries are shorter than the other
      bosses' — the gap after its strings is brief. Its **snap** (a fast
      point-blank heavy) has the shortest warning of any boss attack.
- [ ] The fight should feel like **attrition and timing**: respect the
      shell, dodge the wide sweeps, and save your burst for the crack.
- [ ] Stagger/breakout, retry (the shell re-hardens), XP, and the full
      loop all work against it like the others.

### The Mutated Lion (Sprint 35)

- [ ] Seventh boss card: **MUTATED LION** — 115 HP (the lowest), but the
      fastest thing in the arena at 3.6 m/s: **it never stops closing**.
- [ ] **Bleed hurts more than poison**: the rending claws tint you red and
      tick ~30 damage over 3 s — disengage AND heal, or it compounds.
- [ ] **The pounce** closes mid-range gaps fast (9 m/s) — dodge sideways
      on its shorter telegraph.
- [ ] **THE ENRAGE**: drop it to half health and it **flashes red and
      speeds up ×1.6** — the fight changes pace completely. Dodge
      discipline matters more than ever; there's no second phase, just
      relentless pursuit.
- [ ] The whole fight should feel like **constant movement pressure** —
      the highest of the six bosses, without relying on a big HP pool.
- [ ] Stagger/breakout, retry (the enrage resets with the fight), XP, and
      the full loop all work against it like the others.

### Gear sets (Sprint 36)

- [ ] The armory now has **sets**: wear the **Trainee's Cap AND the Wrist
      Wraps together** and the totals line names **TRAINEE SET ACTIVE** —
      your swings gain an extra **+4 attack** on top of both pieces.
- [ ] Unequip either piece and the set bonus vanishes (the totals line
      loses it too).
- [ ] The set bonus flows everywhere gear does: the F1 payload, the
      arena, the real fight.
- [ ] Sets are derived from what you wear — no extra saves, no funny
      business across restarts.

### The Flame Set (Sprint 37)

- [ ] The armory lists two new fire pieces: the **EMBER CROWN** (HEAD,
      +4 HP) and the **FLAME BRACERS** (HANDS, +1 attack) — wear both and
      the totals line names **FLAME SET ACTIVE**.
- [ ] With the set on, **FIREBOLT (LB + B) explodes on impact**: the bolt
      deals its 16 AND blasts everything near the hit for 8 more — a
      single-target cast went from 16 to **24**, with real multi-target
      potential when more enemies arrive.
- [ ] The blast reads as a big orange flash at the impact.
- [ ] The explosion stacks with everything else: the set's pieces' own
      bonuses, your level's attack bonus, and gear armor all apply as
      usual — one cast, 20 mana, just bigger.
- [ ] Without the set the firebolt is the plain 16 — the identity is the
      set's, not the spell's.

### The Gladiator Set (Sprint 38)

- [ ] The armory lists two more pieces: the **GLADIATOR PAULDRONS**
      (BODY, +5 HP/+0.1 speed) and the **GLADIATOR GREAVES** (FEET,
      +0.25 speed) — wear both and the totals line names **GLADIATOR
      SET ACTIVE** (+0.3 speed, +5% swing).
- [ ] The speed is real: **your gladiator moves visibly faster** and
      swings ~5% quicker with the set on.
- [ ] **The finisher explodes**: the combo's automatic finisher blasts
      everything near the hit for **10 extra damage** — an orange flash
      at the impact, on top of the finisher's own 25.
- [ ] The blast works with **any weapon** (the default sword, the
      gladius, the spear — all three finishers carry it).
- [ ] The explosion doesn't break the combo: the chain still flows
      (light_01 → 02 → 03 → finisher → blast), the stagger/breakout
      rhythm is unchanged, and retry/restart all work normally.

### Multiple finishers (Sprint 39)

- [ ] The default sword's combo now ends in a **two-finisher sequence**:
      light_01 → light_02 → light_03 → **finisher (25, heavy)** →
      **finisher followthrough (15, quick)** — the second finisher flows
      automatically, no extra input.
- [ ] The **Gladiator Set's blast caps the sequence**: the finisher_02's
      hit explodes for 10 (with the set on) — the explosion rewards the
      full 5-swing sequence.
- [ ] The mashing wraps through the 5-swing cycle smoothly — the player
      never gets stuck, the chain never deadlocks.
- [ ] The gladius and the spear keep their **single-finisher** chains —
      the weapons feel different.
- [ ] Retry/restart all work normally through the longer sequence.

### Sprint ability (Sprint 40)

- [ ] **Hold Left Shift (or L3) while moving** — the gladiator sprints at
      ~1.4× speed. The F1 overlay shows `Sprint: ON`.
- [ ] The sprint **only works while moving** — holding it while standing
      still does nothing.
- [ ] The sprint is **disabled in combat states**: your swings root you
      (no sprint-escape mid-swing), blocking keeps its slow walk (the
      sprint doesn't stack), and dodging uses the dodge's own speed.
- [ ] After a swing's recovery or a dodge ends, **the sprint resumes
      automatically** — no re-press needed.
- [ ] With the **Gladiator Set** on, the sprint reaches ~**7.9 m/s** —
      the mobility build's signature pace.
- [ ] The sprint carries into falls (the momentum) — sprinting off a
      ledge keeps the speed.

### The Hydra (Sprint 41)

- [ ] Eighth boss card: **HYDRA** — 105 HP split across **three heads**,
      each its own target (aim at the heads, not the body — body shots
      pass through).
- [ ] **Head damage drains the boss bar** (the main health) AND the
      head's own gate — the boss bar shows the real progress.
- [ ] **Killing a head works**: its head droops dark and stops taking
      hits — but the boss's **bites weaken** (fewer heads, weaker
      attacks).
- [ ] **Heads regrow**: a dead head returns after ~5 s with a full gate —
      you must kill all three within the window or the progress resets.
- [ ] **Kill all three** and the Hydra dies naturally — the defeat, the
      XP, and the victory all work like the other bosses.
- [ ] The Hydra's stagger/breakout works (head hits build the stagger).

### Deliberately not visible yet (by design — don't report as bugs)

- (Nothing — through Sprint 23 every MVP system has shipped. Post-MVP
  items — magic, gear sets, boss selection, difficulty modes — remain out
  by design.)
