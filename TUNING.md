# TUNING.md — the combat knob table

Every feel value in the game lives in exactly one place. Change it there —
no script rewrites needed. Values are the shipped defaults (Sprint 16 audit);
the in-editor Inspector on the named node is the fastest way to tweak.

Legend: **[E]** = Inspector export on the named node · **[R]** = resource file ·
**[C]** = named constant in the named script · **[S]** = scene sub-resource.

---

## Player — `game/scenes/player/player.tscn` → `Player` node
Script: `game/scripts/player/player_controller.gd`

| Knob | Value | Effect |
|---|---|---|
| [E] `movement_speed` | 5.0 | Walk/run speed (m/s) |
| [E] `acceleration` | 40.0 | How fast full speed is reached |
| [E] `deceleration` | 50.0 | Stop-on-a-dime strength (must exceed accel for no-drift) |
| [E] `turn_speed` | 12.0 | How fast the body faces movement direction |
| [E] `lean_amount` | 0.08 | Placeholder movement-lean visual strength |
| [E] `arena_radius` | 16.0 | Radial bound inside the Colosseum wall |

### Dodge group
| Knob | Value | Effect |
|---|---|---|
| [E] `dodge_speed` | 12.0 | Burst speed (keep clearly above movement_speed) |
| [E] `dodge_duration` | 0.25 | Travel time (s) |
| [E] `dodge_invulnerability` | 0.15 | i-frame window at the start of travel |
| [E] `dodge_recovery` | 0.15 | Walkable recovery; only re-dodging is blocked |

### Combo group
| Knob | Value | Effect |
|---|---|---|
| [R] `combo` | `player_light_combo.tres` | The whole chain (see below) |

## Player combo — `game/resources/attacks/player_light_combo.tscn`... `player_light_combo.tres`
Per step (`light_01/02/03`) and `finisher`: damage, stagger_damage, hit_type,
startup, active, recovery, buffer_open, buffer_close. Current: damage
10/12/14/25, stagger 5/6/7/15, finisher breaks out the boss (Sprint 14).
Timing lives here, not on the player (D-022).

## Block — `player.tscn` → `Player` node (Block group)
| Knob | Value | Effect |
|---|---|---|
| [E] `block_startup` | 0.10 | Guard windup (hits land normally) |
| [E] `block_active` | 2.5 | Max guard time before forced recovery |
| [E] `block_recovery` | 0.75 | Vulnerable window; re-block cannot bypass |
| [E] `block_speed_multiplier` | 0.4 | Walk speed while guarding |
| [E] `block_heavy_multiplier` | 0.3 | Heavy damage kept through a full guard |

## Boss — `game/scenes/bosses/new_gladiator.tscn` → `Boss` node
Script: `game/scripts/bosses/boss_controller.gd`

| Knob | Value | Effect |
|---|---|---|
| [E] `movement_speed` | 3.0 | Approach/back-off speed |
| [E] `acceleration` / `deceleration` | 20.0 / 25.0 | Movement feel |
| [E] `turn_speed` | 8.0 | Facing speed |
| [E] `arena_radius` | 16.0 | Radial bound |
| [E] `back_off_distance` | 1.4 | Spacing band — visibly steps back when hugged (D-060) |
| [E] `string_pause` | 1.2 | Post-string opening the player acts in (D-040) |
| [E] `back_off…` guard: `guard_duration` | 1.0 | Defensive response length |
| [E] `guard_cooldown` | 5.0 | Min time between guards |
| [E] `guard_chance` | 0.4 | Roll after each string |
| [E] `guard_heavy_multiplier` | 0.4 | Heavy damage kept through boss guard |
| [E] `breakout_attack_id` | `finisher_01` | Which hit breaks the stagger (D-045) |
| [E] `breakout_finishers` | 1 | Finishers needed in one window (Sprint 39 raises) |
| [E] `breakout_duration` | 0.8 | Post-breakout recovery |

### Boss attacks — inline in `new_gladiator.tscn` (BossAttackData resources)
| Attack | Damage | Stagger | Telegraph | Startup/Active/Recovery | Cooldown | Weight |
|---|---|---|---|---|---|---|
| boss_light | 10 | 6 | 0.4 | 0.30/0.12/0.45 | 1.6 | 3.0 |
| boss_light_2 | 12 | 7 | 0.25 | 0.25/0.12/0.50 | 2.5 | 0 (chained) |
| boss_heavy | 20 | 12 | 0.7 | 0.50/0.15/0.80 | 4.0 | 1.0 |

Lunge speeds: light 2.0, light_2 1.0.

## Boss stagger — `new_gladiator.tscn` → `Stagger` node
| Knob | Value | Effect |
|---|---|---|
| [E] `stagger_threshold` | 15 | Points to open the window (light string = 18) |
| [E] `stagger_duration` | 2.5 | Punish window length (2.5 s fits a full combo) |
| [E] `resistance_growth` | 1.5 | Threshold multiplier per stagger |

## Boss health — `new_gladiator.tscn` → `Health` node
| Knob | Value | Effect |
|---|---|---|
| [E] `max_health` | 100 | ~8–10 clean player swings |

## Boss roster — `game/resources/bosses/boss_roster.tres` (Sprint 25)
| Knob | Value | Effect |
|---|---|---|
| [E] entries | New Gladiator + Sparring Gladiator | The select screen's menu order; first = the arena's default |
| [E] entry scene | `sparring_gladiator.tscn` (inherits `new_gladiator.tscn`) | Data-only variant: `max_health` 60, `boss_title` SPARRING GLADIATOR |

## Hit feedback — `game/scripts/feedback/hit_feedback.gd` [C]
| Knob | Value | Effect |
|---|---|---|
| [C] light hit-stop | 45 ms | Freeze on light hits (both actors) |
| [C] heavy hit-stop | 90 ms | Freeze on heavies/finisher |
| [C] boss-hit stop | 30 ms | Freeze when the boss lands a hit |
| [C] shake impulses | 0.3 / 0.8 | Camera jolt per hit type |
| [C] hurt flash alpha | 0.22 / 0.35 | Red flash on taken/mitigated hits |
| [C] vibration | 0.25/0.1 vs 0.7/0.9 | Gamepad strength per hit type |

## Camera — `player.tscn`... `arena.tscn` → `CameraRig` node
| Knob | Value | Effect |
|---|---|---|
| [E] `distance` | 9.0 | Orbit distance from the player |
| [E] `camera_ring_radius` | 17.5 | Max horizontal orbit radius (wall pull-in, D-058) |
| [E] `turn_speed` | 2.5 | Right-stick orbit speed |
| [E] `pitch_min` / `pitch_max` | −0.1 / 1.1 | Pitch clamps |
| (default pitch) | 0.55 | Load framing (steeper = more overhead) |

## Arena — `arena.tscn` + `arena_blockout.gd`
| Knob | Value | Effect |
|---|---|---|
| [S] floor disc | r 18 | Play surface |
| [S] wall ring | r 18.5, h 4 | 15 segments + gate gap |
| [S] tiers | r 20.5/23/25.5, tops 0.8/1.8/2.8 | Hollow segment rings (never solid discs — D-057) |
| [E] `arena_radius` (both actors) | 16.0 | Navigation clamp |

---

## Tuning rules (from the design docs)

1. Hit-stop pauses actor state clocks — timing checks allow timer + hit-stop allowance.
2. Dodge recovery stays walkable (D-018); block recovery stays committed (Sprint 08).
3. `deceleration` must stay ≥ `acceleration` (no-drift guarantee, movement check).
4. `dodge_speed` stays clearly above `movement_speed` (roadmap check).
5. The finisher must remain reachable inside the stagger window (2.5 s vs ~1.9 s combo, D-048).
6. Resistance growth keeps stagger loops self-limiting until Sprint 39's data tuning.
