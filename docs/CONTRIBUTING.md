# Contributing to Dead Frequency (developer documentation)

This file is for people who want to read, build, test or change the mod. Players should read the
[README](../README.md) and, for spoilers, [GUIDE.md](GUIDE.md). The owner's in-game test protocol is
[TESTING.md](TESTING.md); the model browser notes are [MODELS.md](MODELS.md).

The sources are the `df_*.gsc` files in the repository root. The release is a BUILD of them: `tools/pack.pl`
concatenates the sources into two loadable files. Never edit a packed file; edit a source and pack again.

Every step was validated in game on both sides. The version string `!df status` prints
(`level.df_version` in `df_main.gsc`) moves whenever the mechanics change.

## Toolchain facts that bite

- Plutonium T6 loads every `*.gsc` in `scripts\zm\` and `scripts\zm\zm_transit\` (root level only) and all loaded
  scripts share ONE namespace: a function defined twice is a fatal duplicate at load. So the packed files and the
  sources must never sit in the game folder together.
- A compiled T6 script addresses every function and import name as a 16-bit offset into its string block, so
  that block cannot pass 65535 bytes. Over it the game reads names from the wrong place and prints nonsense
  `Unresolved external` errors (`t_completed `, `bal_stat`, seen 2026-09-08). The plain concatenation of the
  sources has a 102339-byte string block (`df_catalog.gsc` alone is 44127), so one file is not enough: see "The
  build".
- `gsc-tool -m comp -g t6 -s pc -y <file>` (xensik's gsc-tool) catches SYNTAX errors only. It does not catch a
  misspelled or non-existent function name; those show up as script errors in the game console when the map
  loads (needs `developer 1; developer_script 1`). The lints below exist for exactly that gap.
- `toupper` does not exist in T6 GSC. `precachemodel` works only inside `init()`; only models the map precached
  can be spawned. The FX `switch_sparks` lingers and stacks; small controllable sparks are `elec_sm` / `elec_md`
  on a `tag_origin` deleted after 0.5-0.7 s (`df_fx_loop`).
- Perl 5 core modules only in every tool (no CPAN). From PowerShell use
  `"C:\Program Files\Git\usr\bin\perl.exe"`; the examples below assume Git Bash from the repo folder.

## Layout of the sources

One paragraph per file. The header comment of each file is the authoritative description and lists the
vanilla facts the file relies on (with line numbers into the decompiled scripts); read it before touching the file.

- `df_main.gsc` - entry point: `init()`, precache, vanilla-EE removal via `df_compat`, boot of the step machine,
  and the whole `!df` chat command dispatcher (`df_debug_listener`, gated on the `df_debug` dvar) with its help
  text. Holds `level.df_version`.
- `df_compat.gsc` - compatibility layer: turns the vanilla TranZit Easter Egg OFF (`replaceFunc` on the side
  quests, the stat writer and `sidequest_main`, plus `level.maxcompleted = level.richcompleted = 1` so every
  vanilla quest line returns at once), keeps the NavCard, the NavCard table and its stats, the bar TV radio and
  `level.sq_progress` (read by `zm_transit_enhanced_noee.gsc`), pins the bus ladder at the Depot and the roof
  hatch at the Diner, prices the Galvaknuckles at 3000 (owner 2026-09-25: they are a MELEE wall buy, priced by
  `_zm_weap_tazer_knuckles::init` into `level.tazer_cost`, the wall stub's `cost` / `hint_parm2`, and
  `level._melee_weapons` - a stale write to `level.zombie_weapons[...].cost` was never read, so the wall still
  charged 6000; `level.tazer_cost` is set at once, then `df_knuckles_price` waits for round logic to start
  (`flag_wait( "start_zombie_round_logic" )`, owner 2026-09-25: the wall stubs can spawn after our init) before it
  patches every copy of the price, retrying for up to 30 s), and dumps the state on `!df fire compat`.
- `df_systems.gsc` - shared systems: the subtitle HUD (`df_say` / `df_show_line`, per-player hud elems destroyed
  on disconnect), vanilla VO helpers (`df_maxis_vox`, `df_rich_vox` - always 2D to Stuhlinger only, never 3D, owner 2026-09-25 -,
  `df_vox_once`), FX helpers (`df_fx_loop`,
  `df_fx_burst`, `df_side_burst_fx`), the unified cue grammar (`df_cue_tick / _subgoal / _fail / _deny`,
  `df_step_focus`, `df_node_done_trail`), prompts (`df_prompt`, `df_prompt_puzzle` behind `level.df_hints`), the
  spoken-hint switch (`level.df_text_hints`), single press (`df_press_use`), hold-to-use bars, icons, stats, and
  `df_debug_print` (screen + `[DF]` console line).
- `df_steps.gsc` - the step machine and player-count scaling. Contract used by every act file (do not rename):
  `df_register_step`, `df_complete`, `df_touch`, `df_is_done`, `df_set_side`, `df_scaled`, `df_scaled_for`,
  `df_scaled_step`, `df_player_count`, `df_hint_now`, `df_step_avail_time`, `df_step_focus`, `level.df_side`,
  `level.df_done`, notifies `df_<key>_done`, `df_step_done`, `df_step_available`, `df_skip_<key>`,
  `df_side_locked`. Holds the scaling table (one row per key, four columns = 1..4 players; `df_scaled_step`
  freezes a step's quotas at the player count it opened with, or snapshots it on the first read) and the
  stall-hint ladder (START at +2 s, HINT_1 at 4 min, HINT_2 at 10 min and once more at 16 min, HINT_3 once at 20 min,
  then silence; the puzzle steps `step1` / `r1` / `m1` / `step5` wait 6 / 15 min while they have no phase,
  `level.df_hint_puzzle`; every `df_touch` restarts it at HINT_1 from the last touch). `df_step_phase( key, name )`
  names a sub-goal: `df_step_dlg_key` / `df_step_hint_key` then prefer `<P>_<PHASE>_HINT_n` keys (every rung of the
  phase before any plain one) and a phase CHANGE restarts the clock like a touch. Phases in use: step3 BUILD, r1
  CARD / WAKE / HUNT / BATTERY, r2 PUNCH, m1 DOOR / LANTERN, m2 LIT, step6 ROCK / FULL. `df_set_side` is final: a different side once one is locked is refused
  (returns 0).
- `df_dialogue.gsc` - the dialogue sheet, data only. Speakers `maxis` (shown to everyone) and `rich` (shown to
  the Stuhlinger player only, as in vanilla: no Stuhlinger in the game means no Richtofen line; the broadcast tag is kept as data and no longer widens the audience). Key families `<P>_START`, `<P>_HINT_1`,
  `<P>_HINT_2`, `<P>_HINT_3`, the phase rungs `<P>_<PHASE>_HINT_n` and event keys per step (owner rule 2026-09-25:
  START = the goal, HINT_1 points, HINT_2 nudges harder but never gives the recipe, only HINT_3 may be explicit;
  an event line never solves its step; every Richtofen step has ONE Maxis line in its START key so the players who
  are not Stuhlinger hear the idea); `_RICH` / `_MAXIS` variants for the shared acts. Writing rules are in its
  header (see "Rules" below). Event keys added 2026-09-23: `S4_CHOOSE` (first lift of the relay), `R1_RICH_NOSTORM`
  (no Avogadro entity), `R2_POWER_RICH` (power-OFF penalty), `A2_JETGUN_RICH` / `_MAXIS` (Act 2 done, nobody has
  a Jet Gun; `S6_NOJETGUN_*` stays for the Step 6 pickup), `M2_GRAVE_COLD`, `S6_CARD_RICH`,
  `D6_FULL_RICH` / `_MAXIS`, `D7_ZONE_RICH` / `_MAXIS`. `S7_DENIZEN_MAXIS` was removed (owner 2026-09-25: no
  caller left, the Maxis Step 7 wave no longer releases denizens, `df_act3_hold` `df_s7_side_pressure`).
  `ITEM_EMBER_MAXIS` and `M2_EMBER_LOST` were cut in the same 2026-09-25 audit pass (no caller left once the M2
  lantern take/carry/monitor code was removed, `df_act2_maxis.gsc`). The
  Maxis item lines follow the lantern arc (2026-09-25):
  `ITEM_HAND_MAXIS` (renamed from `ITEM_SKULL_MAXIS`), `M1_DONE`, `M2_START`, `M2_EMBER_CHARGED` and
  `ITEM_KEEPSAKE_MAXIS` speak of the lantern, never a skull. That same 2026-09-25 pass reworded ~24 lines to
  match the mechanics (the M2 / Lights Out hint ladders, the Blackout switch lines naming Nacht / Town / the
  plant, stale M2 / D5 / S6 / D7 lines, `M2_KNUCKLES_MAXIS`) - every quote elsewhere in the docs must match
  `df_dialogue.gsc` verbatim.
- `df_coords.gsc` - world anchors and the model registry. Positions derive from TranZit's entity list
  (`tools/assets/zm_transit.d3dbsp.ents.txt`, dumped with the OpenAssetTools Unlinker); wall props find their wall at
  runtime with a trace; heights snap to the real floor. `df_models_init()` maps a kind (`table`, `tv`, `relay`,
  `fuse`, `card`, `brazier`, `skull`, `orb`, `pswitch_body`, `pswitch_lever`, ...) to a model plus facing
  convention; step files never name a model, they call `df_model( kind )`. `df_apply_overrides()` is where `!df grab` output is pasted; overrides
  always win. Also the table (`DF_TABLE`, three slots; `DF_SOCKET` is moved onto it; `df_table_point( offset )`
  for props posed in the table frame: the M1 lantern and the burning lantern, at the same pose), the fx attach points (`df_fx_point_def`), the Step 6 landing-spot draw (once per game at boot) and the curated
  `df_catalog_models()`.
- `df_lamps.gsc` - the ONE lamp set per game (3 lamps, 4 with a full lobby, picked at boot from the six lamps
  valid on both sides, diner and townbridge excluded) and every lamp look (`df_lamp_state_set`: off, souls,
  filled, possessed, vanilla, charged, drained, final; `possessed` / `vanilla` owner 2026-09-25, Maxis M3 / R3
  "Lights Out" - `vanilla` renamed from `dark`, put out goes back to exactly the map's own light, his escaping
  power flying off as a blue spark to the tower). The side colour is the map's own per-lamp client
  exploder fired from the server and re-fired after every power change (never on the Maxis side: that exploder
  carries electric arcs, so `df_lamp_exploder_set` keeps it off there and the lava glow and bursts carry the look;
  `df_lamp_hum_set` swaps `zmb_avogadro_loop` for `zmb_fire_loop` on Maxis); the clientfield is held at 0 so no
  green shows, and the server power flag is kept silently so burrows still work (`df_lamp_power_silent`).
- `df_scav.gsc` - the carry presentation layer in the style of Project Scavenger: (icons: Scavenger's `images`
  folder repaints zm_hud_icon_sq_tranceiver, _sq_scafold, _sq_meteor, _sq_powerbox, _battery and _fan, so our items use
  _panel, _coil, _tvtube, _ladder, _jetgun_engine, _sq_keycard and hud_status_dead; the TAB frame is Scavenger's own) the top-left pickup notice
  (one row below Scavenger's), the "Dead Frequency" TAB square right after Scavenger's fifth, and
  `df_scav_carry_set / _clear`, the API the acts call. Touches nothing of `zm_scavenger.gsc`; every field is
  `df_scav_*`.
- `df_catalog.gsc` - the full TranZit model catalogue (792 lines "name zone w h d", generated by
  `tools/gen_catalog.pl` from the glTF export). Development only: `!df sizes` reads it without precache.
  Replaced by `tools/catalog_stub.gsc` in the packed build (44 KB of strings).
- `df_place.gsc` - live placement mode (`!df grab <KEY>`): the anchor's prop follows the crosshair; fire places,
  melee cancels, ADS freezes, slots 1/2 turn, 3/4 raise, F toggles surface/float, jump resets. Turn and raise
  fire on the button EDGE (`df_place_edge`, owner 2026-09-25): one step per press of the slot, not per frame
  while it reads as held - a held or stuck action slot (e.g. with claymores or equipment on it) used to spin the
  prop at full speed. The snap trace also ignores the held prop itself (`bullettrace( eye, ..., self.df_place_ent )`,
  owner 2026-09-25): before that it could hit the preview and pull it toward the eye, then miss it the next
  frame, so the prop jumped back and forth. A place calls `df_coord_override` and prints the paste-ready line;
  moving a `DF_BLACKOUT_n` or `DF_BRAZIER_n` this way also respawns the real switch / grave at the new spot
  (`df_coord_tune_done`, `df_bo_respawn` / `df_m2_grave_move_hook`).
- `df_audition.gsc` - in-game audition of the game's own fx and sounds (`!df fx ...`, `!df snd ...`, the fx grid
  pages) so picks are made by eye and ear. Every fx key is registered server-side by a vanilla script; every
  alias is in the TranZit banks.
- `df_act1.gsc` - (owner 2026-09-28: every table deposit - relay, key card, batteries, lantern, rock - is the vanilla build hold `df_a1_build_hold`, 3 s) Act 1 "Static" (shared): Step 1 Dead Air (pipes + far signal light), Step 3 Ride the Line
  (owner 2026-09-25: the old Step 2 Salvage is merged in, `df_a1_build_phase`: three parts, relay built on the bus
  roof with the vanilla build hold, the ladder on phase "BUILD"; then one full stop with power on at departure AND
  arrival, roof waves, relay hp; there is no `step2` key, `!df goto step2` is an alias of step3), Step 4 Plug In (the side preview is console-only since 2026-09-25: no table light, no plug spark, no marker glint; side lock at the table,
  graves / boxes stay, only their look changes (owner 2026-09-25); a relay dropped by a carrier who left returns
  to the table after 60 s). Also the portal refusal while carrying and the boot spawn of the fog parts and the table.
- `df_act2_rich.gsc` - Act 2 Richtofen: R1 Summon the Storm (Simon on the four barn boxes, key card, Avogadro
  capture at the tower, one-battery refill on failure after which the card comes back without a Simon replay; no
  Avogadro entity = R1 counts as captured), R2 115 on the Line (hungry lamps, Galvaknuckle punch, a battery drops at the
  lamp and is carried to the table, one build hold for all the batteries in hand (`df_r2_spool_*`, owner 2026-09-25; model kind `r2_battery`); the set settles filled at R2 end), and the Richtofen side rules (Avogadro every round except while Step 6 is open, turrets
  without turbine, the power-OFF penalty, which runs from R1 open so its refill-lock branch works).
- `df_act2_maxis.gsc` - Act 2 Maxis: M1 The Cold Room (denizen latch at the table, the portal, the timed hunt in
  the woods behind the hunter's cabin at the farthest of three rising spots (DF_NACHT_SPAWN_1..3, never twice in
  a row, a no-denizen zone of `level.df_m1_zone_radius`, 1000, around `DF_M1_ZONE` pauses vanilla's own denizens
  for the whole zone while it runs), the lantern, code kind `skull`, standing upright on the ground and spinning,
  with a white + lava glow linked to it, left on the table at the burning lantern's pose; a lantern dropped on the
  bus (owner 2026-09-25) links to it (no spin while linked) and, left untaken 60 s, flies home to `DF_TOWER_RETURN`
  (`df_m1_skull_home_timer`); the tower keeps its vanilla safety box during the latch so a
  denizen must be carried in from the fog, never rises there for free), M2 Fire and Ash (owner 2026-09-25: the
  lantern M1 left on the table is never picked up again - the old take/carry/monitor code and the fists loop
  (`df_m2_fists_loop`) are gone; a Galvaknuckle kill inside a lit grave's zone is refused and Maxis says so,
  `M2_KNUCKLES_MAXIS`, throttled to once per 20 s; the four graves stand OUTSIDE the map at their own owner
  spots, `DF_BRAZIER_1..4`, with NO player collision any more (the old two stacked clips are gone - the graves
  are unreachable on foot anyway) and showing nothing until shot: each carries a `trigger_damage` PLUS two
  ghosted `collision_wall_64x64x10_standard` bullet walls crossed inside the stone (`df_m2_grave_shield_spawn`,
  the map's own ghosted collision model) so a shot cannot fly through it; every hit on any of the four (trigger,
  model or either wall) prints `DF: m2 <name> hit (lit N)` first, so a grave that "does nothing" can still be
  read; a bullet on an unlit one (`df_m2_grave_shot_watch`) lights it - a large fire on the grave itself
  (`df_m2_fire_fx`, default `fx_zmb_tranzit_fire_lrg`) plus a fixed medium one at its rim, seen from Town - and
  opens its KILL ZONE, a
  SEPARATE small flame (fixed `character_fire_death_sm`) plus a lava glow in a circle of `df_m2_zone_radius`
  (dvar, default 400) on the ground where the shooter stood; `df_m2_zone_of` reads the zone back for
  `df_m2_on_zombie_death`; the wave and the denizen-safe rule (`df_m2_grave_near`) key off the zone, not the
  (unreachable) grave position; a counted kill sends a red trail + rising embers off the corpse (`df_m2_soul`,
  the M1 look) to the GRAVE itself (`df_m2_ash_pos`), not the zone; the 90 s cold timer clears the zone and the
  grave's fire, not just the count, but leaves the grave standing - the same grave must be shot again to open a
  fresh one; the fifth kill (`df_m2_fill`) sends a separate trail from the grave's rim to the lantern on the table
  (`df_act2_maxis_trail`) and then EXPLODES the grave (`zmb_explo_sweet` + a `fx_zmb_tranzit_fire_lrg` burst +
  `fx_zmb_ash_rising_md` + a small earthquake) before deleting it outright - trigger, model, both bullet walls
  gone, console `DF: m2 <name> spent, it burst and is gone (k/4)`, even on a quiet (`!df goto` skip) fill;
  `!df fire m2_fill` just fills all four the same way; the fourth spent grave charges the lantern in place,
  `df_m2_ember_charged` alone now (no `df_m2_ember_return`, no carry, no return trip - cut with the rest of the
  take/carry code); at completion it exports the ONE
  Step 6 node, the hunter's cabin fireplace `DF_CABIN_HEARTH`, and warns when nobody has a Jet Gun), and the Maxis side rules
  (`df_m1_protected`: denizens leave players alone inside a lit grave's kill zone while M2 runs and near the
  cabin fireplace while Step 6 is open; doubled fog spawns; the power-ON penalty, which empties only the
  fullest lit grave).
- `df_act3_sweep.gsc` - M3 / R3 on Maxis: "Lights Out" (owner 2026-09-25, replaces the old tune + turbine
  Frequency Sweep). Richtofen feeds his power into the set lamps (`df_lamp_set_get`); M3 / R3 opens with all of
  them "possessed" (his look: a big looping electric spark, a blue glow, his hum). Only the dead may break his
  light: a zombie dying to a CLAYMORE (`claymore_zm`, sold at the Farm wall buy, or one already planted there)
  within `level.df_s5_kill_radius` (250, owner 2026-09-25, up from 150: a claymore throws its kill several steps
  before it dies) of a humming lamp's base puts it out (`df_s5_lit_near`, `df_s5_on_zombie_death`). The game
  reports a claymore kill as weapon `none`, mod `MOD_GRENADE_SPLASH` (identical to a thrown grenade), so the step
  TRACKS each planted claymore near a humming lamp individually (owner 2026-09-25 rework: `level.df_s5_clays`,
  one struct per claymore + lamp, `df_s5_claymore_sweep` polled every 0.05 s, `df_s5_claymore_watch`); when a
  TRACKED claymore disappears (it exploded) its lamp is stamped (`lamp.df_s5_clay_gone_ms`, `df_s5_claymore_gone`),
  and a splash kill there within 1.5 s of that stamp is credited, either order - a kill seen BEFORE the watch
  notices the claymore gone waits as `lamp.df_s5_splash_ms` and is credited retroactively at the stamp; a merely
  PLANTED (not yet exploded) claymore no longer lets a grenade kill count by itself; every kill near a
  humming lamp still prints its weapon and mod to the console first, so a refused kill can be read. Put out, a lamp
  goes back to state "vanilla" - exactly the map's own light, nothing of ours left on it - with his stolen power
  snapping off as a blue spark and flying to the tower top (`df_soul_fly`); any other kill in range does nothing
  to the lamp; the fifth such kill says LO_NOTHAND_MAXIS, once for the game. THREE dark lamps win (`level.df_s5_need`; exactly three
  lamps hum at every player count, the first three of the set, owner 2026-09-25).
  At every end of round with a lamp still humming, Richtofen relights one dark lamp at random
  (`df_s5_relight_loop`, LO_RELIGHT) - the mirror of Blackout's knock. No timer, no countdown, no soul penalty.
  Debug: `!df fire s5_dark` (every lamp dark at once) / `s5_relight` (every lamp humming again),
  `df_s5_debug_hook`. `df_s5_setup` (`!df goto` past M3 / R3 on Maxis) leaves the set lamps dark, nothing running.
  Also owns `df_s5_run` / `df_s5_setup`, M3 / R3's single entry point on both sides (registered with
  `df_register_step`): on Richtofen (`level.df_side == "rich"`) it hands off at once to `df_bo_run` / `df_bo_setup`
  in `df_act3_blackout.gsc` (owner 2026-09-25).
- `df_act3_blackout.gsc` - M3 / R3 on Richtofen (owner 2026-09-25): "Blackout". Three power switches (kinds
  `pswitch_body` + `pswitch_lever`, anchors `DF_BLACKOUT_1..3`, each now at its own owner spot instead of side by
  side under the tower) stand ON from boot on both sides, built exactly like the map's own power switch: the
  lever's registry offset is `(0 -9 46.25)` on the body, and its ON / OFF pose is the registry angle plus a dvar
  (`df_bo_pose`, `df_bo_lever_on` default `0 0 0` / `df_bo_lever_off` default `0 0 90` - vanilla itself: OFF =
  roll 90, ON = roll 0, `zm_transit_power.gsc:56`); absolute angles stored once so `df_bo_set` always rotates TO
  the pose, never BY a relative amount (repeated relative rotates could drift it off true). `df_bo_respawn`
  deletes and respawns all three from their anchors at the current dvar poses while keeping each one's ON / OFF
  state (`!df fire blackout_respawn`, and automatically whenever a `DF_BLACKOUT_n` anchor is tuned, `!df grab` /
  `!df setpos` included). When M3 / R3 opens all three roll OFF at once (Maxis cuts the grid). One press of F
  within 80 of an OFF switch rolls it back ON (flip sound, then `zmb_turn_on` plus an electric burst (`elec_md`)
  and a blue snap (`fx_zmb_tranzit_spark_blue_lg_os`) at the lever - his power coming back), refused while the
  map's main power is off (BO_NOPOWER_RICH, throttled to once per 10 s); each switch turned ON pulls a 20 s
  sprinting wave at it (the M2 grave pattern: 2 every 2 s, cap 8 + 3 per extra player); at every end of round
  with a switch still OFF, Maxis knocks EVERY lit one back off (BO_OFF_MAXIS; owner 2026-09-25: all three within one
  round, was one per round). The third ON completes the step at once. No scaling (three switches at every lobby size). Debug: `!df fire blackout_off` / `blackout_on` /
  `blackout_respawn`.
- `df_act3_vacuum.gsc` - Step 6 Vacuum (the item is a "rock" on screen, `orb` in the code): the opening at the
  table (Richtofen the key card discharges, Maxis the burning lantern bursts), the release (owner 2026-09-25, `df_s6_release_cue`: a shake at every player and a crack 2D to every player; the
  trail climbs 1800 over the table and curves down, `df_s6_trail_fly`), the rock's arrival at the drawn landing
  spot, the carry, the draw (the same on both sides: ONE node, the Jet Gun or its upgrade fired at it with the rock
  carried until the gun overheats, a plain weapon swap never counts; Richtofen the transformer block `DF_CORE`, Maxis
  the cabin fireplace `DF_CABIN_HEARTH`, aim point `cabin_hearth_node`), the aura, home-flight of a dropped rock (60 s)
  or of one never touched (3 min, to the table front), the Step 7 restart contract (`df_s6_restart` /
  `df_s6_redelivered`, `df_s6_place_silent` when a skip ends a restart cycle).
- `df_act3_hold.gsc` - Step 7 The Line Holds: the 1.5 s "Hold F to power the relay" start, the orb gliding along its route (df_s7_path_def, set in the prop composer) under the tower, our own sprinter spawner and
  alive cap, the orb hp and guard bonus, the zone rule (a player downed inside counts as present; horn + D7_ZONE
  line at 5 s), charge strikes, per-side pressure (Avogadro boss on Richtofen; on Maxis the fast zombies and the smoke column
  only, no denizens since 2026-09-25), the song (one length constant,
  `df_s7_song_seconds`, for the restart guard and the after-hold waves), and the after-hold waves (never started
  after a skip; also end the moment the finale starts, owner 2026-09-25, `level endon( "df_fin_started" )`).
- `df_finale.gsc` - the finale (power gate, hold 2.5 s, perks, build-up, orb rise, burst, permanent world change, rewards,
  globe stat), the Act 2 reward listener, and the tower tracker (runner lights per act, and from Step 4 the side-coloured relay runner
  from the table relay up the tower, `df_fin_relay_runner_loop`); the no-overheat Jet Gun reward (`df_fin_jetgun_cool_loop`).

## The build

### tools/pack.pl (what the release uses)

```
perl tools/pack.pl                  # -> release/zm_transit_dead_frequency.gsc, refuses an oversized file (exit 3)
perl tools/pack.pl --parts 2        # -> release/zm_transit_dead_frequency_1.gsc + _2.gsc
perl tools/pack.pl --with-catalog   # keep df_catalog.gsc (development only)
perl tools/pack.pl --keep-comments  # readable output, twice the size
```

Concatenates the sources in `@ORDER`, strips comments, qualifies the unqualified vanilla helper calls from
`tools/vanilla_namespaces.txt` (so the packed file needs no `#include` resolution at load), replaces
`df_catalog.gsc` by `tools/catalog_stub.gsc`, estimates the string block and refuses a file over 62000 bytes
(margin under the 65535 engine limit); when `gsc-tool.exe` is available it also compiles the result and reads
the exact number from the binary (`tools/gsc_header.pl`). Every `df_*.gsc` in the repo MUST be in `@ORDER`: a
source left out compiles fine alone and fails at load with `Unresolved external` (`df_audition.gsc` /
`df_aud_fx`, 2026-09-11); pack.pl dies if one is missing. Today the sources pack into TWO files.

### tools/deploy.pl (install into the game folder)

```
perl tools/check_links.pl .
perl tools/deploy.pl                # packed: one file if it fits, else two, else three
perl tools/deploy.pl --parts N      # force N packed files
perl tools/deploy.pl --multi        # the sources side by side (development: !df sizes / !df catalog work)
perl tools/deploy.pl --game DIR
```

Game folder: `%LOCALAPPDATA%\Plutonium\storage\t6\scripts\zm\zm_transit\`. Each mode removes what the other
modes installed before, because the two layouts must never coexist. Never hand-edit an installed file.

### tools/build.pl and tools/release.pl (the older single-file chain)

`build.pl` merges the sources into ONE file (duplicate-name check, gsc-tool syntax check, includes deduplicated,
merged line k of a file == source line k). `release.pl` runs it and writes `release/` with the merged file, a
copy of the README and an `INSTALL.txt`. They predate the string-block discovery and produce a file the engine
refuses today; `pack.pl` supersedes them and they are kept for their checks and history.

### tools/gsc_header.pl

`perl tools/gsc_header.pl <compiled .gsc>` prints the T6 script header and the size of the string block: this
is how the 65535 limit was measured.

### The GitHub Action (`.github/workflows/release.yml`)

On every push to `main` / `master` that touches a `df_*.gsc`, the stub, the pack / lint tools, the sound bank
tables or the workflow itself: run `lint_includes`, `lint_sounds`, `lint_calls` and `check_links`, then pack (one
file, else two, else three), then publish a GitHub Release tagged `v<version>-<run>` with every
`release/zm_transit_dead_frequency*.gsc` attached. `companion/` is not packed (pack.pl globs `df_*.gsc` in the
repo root only). A push that only touches docs creates no release. `workflow_dispatch` starts one by hand.

## The lints (run all four before every push)

```
perl tools/lint_includes.pl && perl tools/lint_sounds.pl && perl tools/lint_calls.pl && perl tools/check_links.pl .
```

| Tool | Catches | Incident that motivated it |
|---|---|---|
| `tools/lint_includes.pl` | a `df_*.gsc` that calls a vanilla SCRIPT helper (not an engine builtin) without the three utility includes (`common_scripts\utility`, `maps\mp\_utility`, `maps\mp\zombies\_zm_utility`) | `df_dialogue.gsc` called `is_true` without them: `Unresolved external`, the whole mod refused at load (2026-09-08) |
| `tools/lint_sounds.pl` | a sound alias played by a source that is in none of the game's real alias tables (`tools/assets/soundbank/*.aliases.csv`), i.e. silent in game; also prints the 3D range of every alias played with `playsoundatposition` so a 150-unit alias at a prop is caught by eye. `vox_*` aliases live in the english bank the unlinker does not resolve and are accepted when a vanilla TranZit script plays them | eight silent aliases had slipped through the earlier "used by vanilla scripts" list: `zmb_elec_arc`, `zmb_souls_end`, `ignite`, `zmb_firetrap_start`, `zmb_screecher_dig`, `zmb_player_hit_ding`, `zmb_elec_start` / `_loop` (2026-09-09) |
| `tools/lint_calls.pl` | a function name called in the sources that is defined in no `df_*.gsc` and used by name in no vanilla T6 zombies script: almost surely a helper from another CoD | `array_remove` (a later-CoD helper): `Unresolved external` at load, invisible to the compiler (2026-09-11) |
| `tools/check_links.pl` | a `df_*` function called in a file that is defined neither there nor in a `df_*` file it `#include`s, and duplicate definitions across files (all df files share one namespace) | the class of `Unresolved external` gsc-tool cannot see; the pack.pl `@ORDER` check covers the packed-build variant (`df_aud_fx`, 2026-09-11) |

Generators (run when the inputs change, not on every build): `tools/gen_vanilla_map.pl <decompiled ZM folder>`
rewrites `tools/vanilla_namespaces.txt`; `tools/gen_catalog.pl` rewrites `df_catalog.gsc` from the glTF export;
`tools/gen_xmodel_owners.pl <folder with *.list.txt>` rewrites `tools/assets/xmodels_zm_transit.txt`.

## Testing setup (every time)

Console before loading the map:
```
developer 1
developer_script 1
set df_debug 1
```
Load TranZit (Original). `!df status` must list `registered: step1 step3 step4 r1 r2 m1 m2 step5 step6 step7 finale`.
Every `!df` answer is also printed in the console as `[DF] ...`, and every quest event prints a `DF: ...` line
there: paste those lines when reporting. The full protocol, step by step, is [TESTING.md](TESTING.md).

### Chat commands (need `df_debug 1`)

| Command | Effect |
|---|---|
| `!df status` | version, side, player count, round, hints state, steps done / available / registered |
| `!df who` | diagnostic for "why is F doing nothing": prints whether you are drinking / screecher-ridden / in laststand, your current weapon, whether you carry the relay / orb / lantern / battery, and every `trigger_radius_use` within 200 of you with its distance |
| `!df goto <step>` | mark previous steps done, make `<step>` available (`step1 step3 step4 r1 r2 r3 m1 m2 m3 step5 step6 step7 finale`; `step2` = step3). Forward only: a step already done or not ahead of the current one is refused, and so is a step of the other side once a side is locked. A jump that does not finish in 20 s is aborted by a watchdog (the goto flag is cleared). Never deletes the boot props (pipes, table, boxes, graves, the three power switches, lamps); the side lock only ever changes their look (glow / flame), never removes them |
| `!df side rich` / `!df side maxis` | lock the side by hand; FINAL, a second, different side is refused (`side X is already locked ...`). Re-copies the landing spot drawn at boot into DF_ORB_SPAWN (console `orb spawn for side X: ...`, no new draw) |
| `!df say <KEY>` | show a dialogue key (`!df say s1_start` works too) |
| `!df scale` | print a few scaled values for the current player count |
| `!df simon` | solve the R1 Simon (storm + summon follow) |
| `!df souls` | fill every soul / carry counter of the open step: R1 refill (all four boxes charged), R2 (lamps filled AND every battery inserted), M1 kills, M2 graves (all spent, burning lantern returned) |
| `!df avogadro` | force Avogadro back from the cloud (only when he is in the cloud) |
| `!df side_fx` / `!df side_fx stop` | start / stop the tower visuals for the locked side |
| `!df power on` / `!df power off` | flip TranZit power (fires the real switch if built, else the flags) |
| `!df stat rich` / `!df stat maxis` / `!df stat none` | WRITES the completion stat (globe glow) for that side, or clears it |
| `!df hints on` / `!df hints off` | show / hide the on-screen puzzle prompts only (the Simon boxes, Jet Gun hints, the cold-room "Take the lantern before the cold closes"); default off. Mechanic prompts (take / place / build / hold) always stay; the Step 1 pipes never show one |
| `!df texthints on` / `!df texthints off` | the spoken hint ladder (HINT_1 at 4 min, HINT_2 at 10 / 16 min, HINT_3 at 20 min, puzzle steps 6 / 15 / 20; event hints); default on. START / FAIL / DONE lines always play |
| `!df cue avail|tick|subgoal|fail|deny|trail|done` | plays one row of the cue grammar where you stand (step available, progress tick, sub-goal chime + flash + trail to the tower, fail thump, deny buzz, the trail alone, step done) |
| `!df vox <alias>` | plays a vanilla patron voice line (`vox_maxi_*` 3D at your feet, anything else 2D to Samuel); silence = unknown alias |
| `!df jet` / `!df jet watch` | Jet Gun heat diagnostic (df_audition.gsc): one console line per player with every value the heat path reads (vanilla heatval / overheating, engine heat, TranZit Enhanced `jgx_*`, trigger); starts the vanilla heat watcher on a gun given outside the equipment path. `watch` samples every 0.5 s for 8 s so the trigger can be held |
| `!df freeze` | toggle: every regular zombie stands still in the vanilla inert pose until toggled back (Avogadro and denizens untouched); new zombies freeze as they finish rising |
| `!df fx grid` / `!df fx gridnext` / `!df fx gridprev` / `!df fx gridbig` / `!df fx gridoff` | the curated effects in pages in front of you, 8 per row on small pedestals, one-shots re-fired so they stay visible (gridbig = the huge ones, fewer per page, wider apart; the client culls entity effects, so pages stay small); stand by a pedestal and the bottom label reads `[n] name`; the console prints the page |
| `!df fx list` / `!df fx <n>` / `!df fx next` / `!df fx prev` / `!df fx <name>` / `!df fx off` | audition one of ~150 server fx for 8 s where you aim; the console prints its index and name (df_audition.gsc). Pairs with the Effect Picker page |
| `!df snd list` / `!df snd <n>` / `!df snd next` / `!df snd prev` / `!df snd <alias>` | audition one of the curated bank sound aliases, played to you at full volume; the console prints its index and name. The same set is on the Sound Picker page with durations and ranges |
| `!df model` / `!df model <kind> <name>` / `!df orb <name>` | list the model registry / swap a model for props spawned from now on. A swapped model renders only if the map precached it; make it permanent in `df_models_init` (df_coords.gsc) |
| `!df show [KEY]` / `!df hide` / `!df tp <KEY>` / `!df dump` (= `!df coords`) | preview props with a glint / remove them / teleport to an anchor / print every anchor as `[SPOT]` and every model as `[MODEL]` |
| `!df lift <KEY> <up>` / `!df move <KEY> <fwd> <right> <up>` / `!df ang <KEY> <pitch> <yaw> <roll>` | tune an anchor live. `!df move DF_TABLE ...` moves the real table |
| `!df setpos <KEY> <x> <y> <z> [yaw]` | an anchor straight to world coordinates (yaw optional, keeps the anchor's current yaw if left off; pitch and roll always stay from the anchor - only yaw can change); an unknown `KEY` is refused (`DF: unknown anchor <KEY> (!df dump lists them)`, nothing changes); calls `df_coord_override` + `df_coord_tune_done` like every other tune, so a `DF_BLACKOUT_n` or `DF_BRAZIER_n` respawns the real prop too |
| `!df grab <KEY>` / `!df drop` / `!df cancel` / `!df rot <deg>` / `!df up <units>` | live placement: the prop follows your crosshair (fire = place, melee = cancel, ADS = freeze, 1/2 turn, 3/4 raise, F = surface/float, space = reset); turn and raise move ONE step per PRESS of the slot button (edge-detected, `df_place_edge`), not per frame while it reads as held - a held or stuck action slot used to spin the prop at full speed. A `DF_BLACKOUT_n` or `DF_BRAZIER_n` placed this way moves the real switch / grave along with the anchor (model, trigger, bullet walls / lever), not just the anchor |
| `!df pos` / `!df aim [KEY]` | print where you stand and what you aim at / snap an anchor to the aim point (also calls `df_coord_tune_done`, so a `DF_BLACKOUT_n` or `DF_BRAZIER_n` respawns the real prop, like `!df setpos`, owner 2026-09-25) |
| `!df catalog <keyword|all> [page]` / `!df catalog pick <n> <kind>` / `!df catalog clear` | up to 10 candidate models in a row in front of you; `pick` assigns one to a kind. Needs `--multi` for the full list |
| `!df sizes <keyword|all> [page]` | list catalogue models with size and zone, no precache needed (`--multi` only) |
| `!df fire <name>` | generic hook, see the table below (`level notify( "df_debug_<name>" )`) |
| `!df` or `!df help` | full command list |

### Debug hooks (`!df fire <name>`)

| Step | Hooks |
|---|---|
| Act 1 | `a1_solve1` (Step 1 solved, the coil arrives), `a1_tv` (kick the next expected pipe), `a1_parts` (take every part, coil included), `a1_hit` (200 dmg to the relay), `a1_stop` (count the running sweep), `a1_relay` (relay to your feet), `a1_build` (vanilla build hands demo), `a1_receiver` (the coil arrives at DF_COIL_DROP now, without the pipes), `a1_corn` (the Maxis cornfield line at the relay) |
| R1 / R2 | `simon_solved` (= `!df simon`), `souls_done` (= `!df souls`), `r1_captured`, `r1_fail` (the capture fail path now: battery on the bus, then the Simon again), `r1_sounds` (click / buzzer / arpeggio), `r1_soul` (ONE box gets its battery without the bus trip), `r1_card` (card arrival fx), `r2_soul` (one soul into the first unfilled lamp), `r2_punch` (every full lamp drops its battery without the knuckles), `r2_spool` (one battery counts as inserted) |
| M1 / M2 | `m1_latch`, `m1_kills`, `m1_cue` (kill cue demo), `m1_burst`, `m1_fog` (toggle cold-room fog at the DF_NACHT_SPAWN anchors), `m1_ride` (first-ride cue: table sound + line + hint, no table fx, no denizen needed), `m1_skull` (drop the M1 lantern in front of you; fire again to send it to the table), `m2_light` (light the next unlit grave), `m2_fill` (spend every grave; the fourth charges the burning lantern on the table), `m2_restage` (re-skin the graves after `!df model brazier ...`), `m2_penalty` (the power-ON penalty now), `m2_column` (the 20 s smoke column at the tower top). (`m2_ember` and the old lantern-carry debug are gone, owner 2026-09-25.) |
| M3 / R3 (Maxis Lights Out) | `s5_dark` (every lamp dark at once, completes the step), `s5_relight` (every lamp humming again) |
| M3 / R3 (Richtofen Blackout) | `blackout_off` (all three switches OFF, a running step keeps going), `blackout_on` (all three ON, completes the step if it is open), `blackout_respawn` (deletes and respawns all three switches from their anchors at the current `df_bo_lever_on` / `df_bo_lever_off` poses, keeping each one's ON / OFF state; also fires itself when a `DF_BLACKOUT_n` anchor is tuned) |
| Step 6 | `s6_orb` (rock to your feet), `s6_draw` (one charge), `s6_deliver`, `s6_restart`, `orb_aura` (next aura candidate) |
| Step 7 | `s7_start`, `s7_time` (win), `s7_fail`, `s7_hp`, `s7_dmg` (100 dmg; solo 3000 hp: damaged under 900, destroyed at 0, strikes heal in between), `s7_strike` (one charge strike now) |
| Finale | `finale`, `finale_nostat`, `finale_fx` (~15 s spectacle with a stand-in orb, repeatable), `finale_world` (the permanent world change alone, once), `a2_reward` (the Act 2 reward now, once), `perks` (give every perk + summary) |
| Lamps | `lamps` (every known lamp with set / state / silent / exploder), `lamps_all` (all 8 lamps in the side colour), `lamps_power` (silent power flag on all 8) |
| Misc | `scav` / `scav_slot` (Scavenger-style notice and TAB square demo), `table_demo` (table + slots preview: relay + coil box + mast on slot 0, card on slot 1, rock on slot 2), `beam_test` (20 s beam to the nearest lamp; `set df_beam_fx <alias>`, `set df_beam_flip 1`), `compat` (vanilla-EE state + disk stats dump), `busparts` (re-run the ladder / hatch pin and print the part pools) |

Event hints: a step file may speak a hint the moment something happens (console `DF: event hint <KEY> (<step>)`);
the stall ladder then skips that rung once (HINT_3 is never an event rung). Every touch or phase change (`df_touch`) restarts the ladder at HINT_1 from that
touch. `!df texthints off` silences the ladder (prompts have their own switch).

### Dvars (console, set BEFORE loading the map)

| Dvar | Default | Effect |
|---|---|---|
| `df_debug` | 0 | `1` enables the `!df` chat commands (including `!df status`) |
| `df_hud_timers` | 0 | `1` restores the old on-screen timers for a test (the shipped build has none) |
| `df_fx_pipe_flash` | `fx_zmb_tranzit_light_bulb_xsm` | the Step 1 pipe flash |
| `df_fx_signal` | `fx_zmb_tranzit_light_bulb_xsm` | the Step 1 far signal light (silent flashes) |
| `df_fx_pipe_locator` | `fx_zmb_tranzit_spark_blue_lg_os` | the one-shot spark closing each pipe cycle and each signal message |
| `df_signal_lift` | 70 | height of the signal light above DF_SIGNAL |
| `df_signal_hum` | `zmb_meteor_loop` | the loop played 20 above DF_SIGNAL_SND |
| `df_beam_fx` | (built-in choice) | the tower beam alias for `!df fire beam_test` / the node beams; try `fx_zmb_tranzit_god_ray_pwr_station`, `_interior_med`, `mc_towerlight` |
| `df_beam_flip` | 0 | `1` reverses the beam direction |
| `df_extra_models` | "" | space-separated model names to precache for `!df catalog extra` (up to ~10) |
| `df_catalog_page` / `df_catalog_pagesize` | - / 30 | precache one page of the full catalogue (`--multi` install) |
| `df_lamp_glow` | 1 | `0` turns the safety glow in the lamp bulb off (the exploder colour alone) |
| `df_m2_grave_time` | 90 | seconds a lit M2 grave has to be filled before it goes cold (unlit, count back to 0) |
| `df_m2_zone_radius` | 400 | radius of a lit M2 grave's kill zone, the circle on the ground where the shooter stood when the grave was lit |
| `df_m2_fire_fx` | `character_fire_death_sm` | the small M2 flame on every standing grave, replayed every 2 s |
| `df_m2_hand_fx` | `dog_trail_fire` | the burning lantern's own, smaller flame on the table (only once the four graves are ash), replayed every 2 s; read at the next spawn (`character_fire_death_sm` = the old one) |
| `df_bo_lever_on` / `df_bo_lever_off` | `0 0 0` / `0 0 90` | pitch yaw roll ADDED to the `pswitch_lever` registry angle for the Blackout switch's ON / OFF pose (vanilla: OFF = roll 90, ON = roll 0, `zm_transit_power.gsc:56`); after changing either, `!df fire blackout_respawn` re-poses the three live switches |
| `df_catalog` | "" | `0` skips precaching `df_catalog_models()` (the registry models are always precached) |
| `df_scav_slot` | "" (auto) | forces the TAB square slot for a Scavenger version whose row has another length |

## Asset ground truth (`tools/assets/`)

Everything a source names must exist in the game files; these lists are the proof, dumped with the OpenAssetTools
(OAT) Unlinker from the TranZit fastfiles:

- `soundbank/*.aliases.csv` - the real sound alias tables (`--include-assets soundbank`); compact form
  `sound_aliases_zm_transit.txt` (alias, file, volume, 3D range, pan). `lint_sounds.pl` reads them.
  `sounds_zm_transit.txt` is the older "aliases the vanilla scripts play" list (insufficient alone: see the lint).
- `fx_aliases_zm_transit.txt` - every fx key a vanilla TranZit / core script registers server-side (`.gsc` rows);
  `fx_zm_transit.txt` the raw fx list. `df_audition.gsc` and the Effect Picker are built from these.
- `xmodels_zm_transit.txt` - every model with its OWNER zone and ALWAYS / STREAMED status (`gen_xmodel_owners.pl`).
  Spawn only ALWAYS models (584 of 1038); a STREAMED model renders as a black box outside its own area. Details
  in [MODELS.md](MODELS.md).
- `shaders_zm_transit.txt`, `weapons_zm_transit.txt` - HUD shaders (the Scavenger-style icons come from here) and
  weapon names.
- `tools/assets/zm_transit.d3dbsp.ents.txt` - the map's entity list (every struct / trigger / node with coordinates);
  `df_coords.gsc` derives its anchors from it.

Rule for cues: most short aliases are 3D and fade out at 150-175 units, so a cue meant for a player is delivered
with `df_snd_near( alias, origin, radius )` / `playsoundtoplayer` at the listener, never `playsoundatposition` at
a prop.

### Pickers (`tools/pickers/`)

Generators of three self-contained HTML pages used to choose sounds, props and effects by ear and eye (Sound
Picker, Prop Picker with a three.js viewer, Effect Picker paired with `!df fx <n>`). Inputs, links and the rebuild
commands are in [`tools/pickers/README.md`](../tools/pickers/README.md). Every pick made this way is written into
the source with an `owner pick <date>` comment.

## Coordinate workflow

`df_coords.gsc` derives every anchor from the entity dump. Check them in game with `!df show`, `!df tp <KEY>`,
`!df dump`; tune live with `!df lift / move / ang`, or better `!df grab <KEY>`: the prop follows your crosshair,
fire places it. A place prints a paste-ready line:

```
df_coord_override( "DF_ORB_SPOT_2", ( 900, 130, -39 ), ( 0, 165, 0 ) );
```

Paste it into `df_apply_overrides()` in `df_coords.gsc`. Overrides always win over the derived positions.
The older way (the owner's `cheats_zm.gsc`: `!place <model>`, `!nudge`, `!spot <KEY>`, `!spots`) is recorded in
`tools/history/`.

### Anchors and models

| Key | Model kind (registry name) | Where |
|---|---|---|
| DF_TABLE (DF_SOCKET is moved onto it) | table = `p6_zm_work_bench` | under the tower (7771 -448 -202); slots 0/1/2 on its top, left to right; two rows of `collision_player_32x32x32` clips (kind `clip`) = a 64-tall wall along the long side |
| DF_TV_1..4 | tv = `pb_pole_telephone_bulb` (chimney pipe, 9 tall) | four spots on the ground around the Depot |
| DF_SIGNAL / DF_SIGNAL_SND | none (a light 70 above DF_SIGNAL, dvar `df_signal_lift`; the hum 20 above DF_SIGNAL_SND, dvar `df_signal_hum`) | past the Depot fence (-6244 5361 -187) / (-6245 5085 -67) |
| DF_PHONE_1 / DF_PHONE_2 | none | the Depot wall phones; kept as anchors, no role in the quest any more |
| DF_PART_A / B | part_a `p6_zm_buildable_sq_transceiver` (the radio), part_b `p6_zm_chain_fence_piece_end` (the mast, standing, 117 tall) | Diner garage, behind the box (-4830 -7978 -29) / Farm barn upper floor (8149 -5088 52). The DF_PART_C anchor is gone (2026-09-23); the `part_c` kind stays only for `!df catalog pick` |
| DF_COIL_DROP | receiver = `p6_zm_buildable_sq_electric_box` (the power box, slightly tilted) | where the coil lands after Step 1 (-6311 5019 -46); move it with `!df move DF_COIL_DROP ...` or `!df grab DF_COIL_DROP` |
| DF_BUS_ROOF_OFFSET | relay = `p6_zm_buildable_sq_transceiver` + relay_coil = `p6_zm_buildable_sq_electric_box` (+17) + relay_mast = relay_top = `p6_zm_chain_fence_piece_end` (+27), yaw -45: the same three pieces on the roof and on the table | bus roof centre / table slot 0 |
| DF_FUSE_1..4 | fuse = `p6_zm_buildable_sq_electric_box` (13 x 20 power box, centre at 50, 6 off the wall) | owner 2026-09-25: four owner spots on the Farm barn walls (8825 -5744 105, 8801 -5889 106, 8526 -5889 105, 8518 -5582 106); stand from boot on both sides, no fx until Richtofen locks (a faint LED glow, then R1 drives the sparks and the Simon); Maxis locked = dark scenery, model kept |
| DF_CARD_SPAWN | card = `p6_zm_keycard` (the strike lands it 36 above the floor under the anchor) | barn wall (8614 -5864 91) |
| (battery, no anchor) | battery = `p6_zm_buildable_battery` (R1 fuse battery; R2 batteries use kind `r2_battery`, the same model; the `spool` kind is no longer spawned) | bus dashboard |
| DF_BRAZIER_1..4 | brazier = `ch_tombstone1` (the graves, 31 tall, NO player collision - owner 2026-09-25: the old two stacked clips are gone, the graves stand outside the map, unreachable on foot; unlit shows nothing, lit carries a large fire seen from Town; a `trigger_damage` PLUS two ghosted `collision_wall_64x64x10_standard` bullet walls crossed inside the stone (`df_m2_grave_shield_spawn`) are what a SHOT hits to light it) | owner 2026-09-25: OUTSIDE the map around Town; stand from boot on both sides, Richtofen locked = dark scenery, model and shield kept; a spent grave (M2 quota met, `df_m2_fill`) EXPLODES and is deleted outright - trigger, model, both bullet walls - nothing left standing; `!df grab` / `!df setpos` / `!df aim` on the anchor (before that) moves the real grave (model, trigger, bullet walls, flame/crackle) along (`df_m2_grave_move_hook`) | Every game draws four of the eight owner spots below at random (df_coords df_grave_pool_pick; console `m2 grave N drawn at x y z`): (1944 -1040 124, yaw 127), (328 -797 132, yaw 297), (2062 374 88, yaw 259), (-86 224 -36, yaw 43), (2581 -1009 -55, yaw 139), (2610 413 -55, yaw 204), (2812 -264 -62, yaw 218), (799 -1024 -52, yaw 56).
| DF_BLACKOUT_1..3 | pswitch_body = `p6_zm_buildable_pswitch_body` (the switch body) + pswitch_lever = `p6_zm_buildable_pswitch_lever` (the lever, offset `(0 -9 46.25)` onto the body, exactly the map's own; ON / OFF poses are dvars, `df_bo_lever_on` / `_off`, added to the registry angle) | owner 2026-09-25: three power switches, each at its OWN owner spot (13810 -196 -188, 829 -1482 -44, 11668 8524 -575), no longer side by side under the tower; stand ON from boot on both sides; `!df grab` / `!df setpos` on the anchor respawns the real switch (`df_bo_respawn`) |
| (M1 lantern, burning lantern, no anchor) | both `p_lights_cagelight02_red_off`, HUD label "Lantern", rock icon `zm_hud_icon_sq_meteor`: the M1 lantern = kind `skull` (the name stays in the code and console), placed at the `ember` table pose, no spin, no flame; the burning lantern = kind `ember`, the same lantern entity M1 left on the table (owner 2026-09-25: never swapped or taken again for M2 - it just becomes the burning lantern in place once the four graves are spent), flame only when charged (fx point `hand_fire`, dvar `df_m2_hand_fx`); posed in the table frame by the `ember` df_model_def offset (`df_table_point`) | on the table for the whole of M1 and M2; the M1 lantern is dropped on the floor where the last denizen died before that |
| DF_NACHT_SPAWN_1..4 | none, stand there | inside the woods behind the cabin (the cold room moved there from the Nacht bunker, owner 2026-09-25), owner spots 2026-09-23 (13673 -337, 13861 -327, 13643 -541, 13886 -522; z -188); each denizen rises at a random one at least 150 from every player, never the same twice in a row, inside the no-denizen zone (`DF_M1_ZONE`, radius 1000, `level.df_m1_zone_radius`) that pauses vanilla's own denizens for the whole zone while the room runs |
| DF_TOWER_RETURN | none, stand there | return point after the Cold Room (7552 -512 -72) |
| DF_ORB_SPOT_1..3 | orb = `p6_zm_buildable_sq_meteor` (kind `orb_ground` on the floor, rests 3 above the ground) | the three Step 6 landing spots: diner (-5991 -7686 34), Town (900 130 -39), power station (11720 8491 -575); ONE is drawn at boot for the whole game (`level.df_orb_spot_key`); a live tune of a spot makes it the pick |
| DF_CORE | none (the map's transformer block; aim / beam / hum point `core_node`) | Richtofen's Step 6 node, the sparking block on the power station bridge (11092 8361 -496) |
| DF_CABIN_HEARTH | none (the map's fireplace; aim / beam / hum / glow point `cabin_hearth_node`, 18 up = the centre of the opening) | Maxis's Step 6 node, the fireplace of the hunter's cabin in the woods (5430 6874 -24, yaw 183) |
| DF_ORB_SPAWN | orb | a COPY of the spot drawn at boot (re-copied at the side lock, no new draw); Step 6 reads it when it starts |
| DF_ORB_TOWER / DF_ORB_DINER | orb | the old per-side spawns, kept only as fallbacks when no DF_ORB_SPOT exists |
| DF_PORTAL | portal = `p6_zm_screecher_hole` | the M1 hole in front of the table (7623 -457 -207) |
| (fx grid) | beacon = `p6_zm_buildable_sq_meteor` | the pedestals of `!df fx grid` |

Note: the M1 item is Maxis's lantern (since 2026-09-25; `zombie_skull` from 2026-09-23, the meteor model before);
`!df catalog pick <n> skull` swaps it, `!df orb <name>` the Step 6 rock. `!df model` lists every kind; `!df fire
table_demo` previews relay + coil box + mast, card and rock on the three slots. The table under the tower carries NO fx of
ours (no Step 4 preview light, no plug spark, no marker glint at Step 4 / the R1 card insert / the finale, no placing
snap; the burning burning lantern between M2 and Step 6 is the one exception): the lasting look is the relay runner, from Step 4 a side-coloured trail from the plugged relay up
the nearest tower leg every ~4 s (`df_fin_relay_runner_loop`, owner 2026-09-28: it replaced the eight step glows).

## Lamps

ONE lamp set per game (3 lamps, 4 with a full lobby), picked at boot from the six lamps valid on both sides (diner and
townbridge are skipped) with the idle spark marker; R2 feeds THESE, M3 / R3 (Maxis: "Lights Out") fills THESE with
Richtofen's power and darkens them with claymore kills.
Richtofen's M3 / R3 is Blackout instead (`df_act3_blackout.gsc`, the three `DF_BLACKOUT_1..3` power switches) and
touches none of the lamps. The side colour is the map's
own per-lamp client exploder (blue = 401 + 2i, orange = 400 + 2i, i = the lamp's area index) fired from the server and
re-fired after every vanilla power change, plus a safety glow in the bulb. On the Maxis side the exploder is never lit
(it carries electric arcs): the lava glow in the bulb and the lava bursts carry the look, and the hum is `zmb_fire_loop`. `set df_lamp_glow 0` before loading turns
the safety glow off. No forced green under our light: the clientfield is held at 0 and the server power flag is kept
silently so burrows still work. States: off, souls (hungry: colour + hum + a spark every 2 s), filled (steady bulb
glow, no sparks, R2's full lamp), possessed (Maxis M3 / R3 Lights Out, owner 2026-09-25: his look, a big looping
electric spark, a blue glow, his hum - Richtofen's power in the lamp), vanilla (Maxis M3 / R3 put out, owner
2026-09-25, renamed from `dark`: exactly the map's own light, nothing of ours left on it - his stolen power snaps
off as a blue spark and flies to the tower top as it goes), charged, drained, final (steady side colour after the
finale, all 8 lamps).
Stall hints: a step untouched 4 min gets a hint line (6 min on a puzzle step), then HINT_2 at 10 and 16 min (15 on a
puzzle step), HINT_3 once at 20 min, then nothing (never once the finale is reachable); every touch or phase change
starts the ladder over from that moment; an event hint spoken earlier skips its rung once. Vanilla EE: fully off (both quests, their dialogue,
the tower relight for returning players); the NavCard table and its stats keep working. `!df fire compat` dumps it.

## Sounds

The real alias tables of TranZit Original are in `tools/assets/soundbank/*.aliases.csv` (dumped from the game with the
OAT Unlinker, `--include-assets soundbank`; compact list `tools/assets/sound_aliases_zm_transit.txt`: alias, file,
volume, 3D range, pan). `perl tools/lint_sounds.pl` fails the build when a source plays an alias that no bank carries
(silent in game): the vanilla-script usage list that was used before let eight silent aliases through (zmb_elec_arc,
zmb_souls_end, "ignite", zmb_firetrap_start, zmb_screecher_dig, zmb_player_hit_ding, zmb_elec_start / _loop).
The vox_* aliases live in the english bank the unlinker does not resolve; the lint accepts the ones vanilla TranZit plays.
Owner picks are made by ear with `!df snd <n>` in game or the Sound Picker page, by eye with `!df fx <n>` / `!df fx grid`
or the Effect Picker page, and by shape with the Prop Picker page (`tools/pickers/README.md`); every pick is written into
the source with an `owner pick <date>` comment.

### Cue grammar (one sound = one meaning, `df_systems.gsc` / `df_steps.gsc`)

| Meaning | Sound + look |
|---|---|
| step AVAILABLE | zmb_screecher_portal_arrive to every player + a glint (fx_zmb_tranzit_light_glow) on the object |
| progress TICK | zmb_buildable_piece_add 3D at the object |
| SUB-GOAL done | zmb_sq_navcard_success + side flash + a spark runner flying to the tower top |
| step DONE | evt_bridge_collapse_start (the bridge groan) to every player, the only step-done sound |
| DENY (wrong input) | zmb_sq_navcard_fail to the presser only |
| FAIL / lost | zmb_bus_emp_shutdown + the side's loss fx |
| ITEM ARRIVAL | grenade_samantha_steal burst + zmb_avogadro_spawn_3d thunder + a short quake: coil, card, M1 lantern, rock |
| ITEM ON THE TABLE | `df_cue_table_place`: the zmb_buildable_piece_add clink only, NO fx (since 2026-09-25 the table under the tower shows nothing of ours): M1 lantern, burning lantern, rock; the relay plug has no spark either (clink + switch-on sound) |

Side family: everything electric (blue sparks) on Richtofen and before the fork, everything fire / ash on Maxis. On
Maxis nothing electric (2026-09-25): no lamp exploder and a fire hum on the lamps; the tower top gets a slow
fx_zmb_tranzit_fire_med pulse instead of the `sq_common_lightning` orb (`df_tower_fx_lightning`: the acts' 12 s cues
and the finale); no zmb_avogadro_spawn_3d crack at the Step 6 strike, the Step 7 charge strikes or the finale burst;
the Step 7 rock flickers with `lava_burning` when hit (Richtofen keeps `elec_md`).

## Co-installed mods (checked against the packed file)

- `scripts\zm\zm_scavenger.gsc` (Project Scavenger v1.9, NickB_05). Disjoint from Dead Frequency: it replaces only
  `_zm_buildables::player_can_take_piece`, we replace only the sidequest functions and the denizen portal use; our
  parts, coil, battery, the M1 / M2 lantern and rock are our own script_models, so a press can never be taken by both. The
  bus-part pin uses vanilla's own piece functions. HUD: Scavenger draws top-left / top-right while TAB is held; our
  notices sit one row lower and our TAB square right after their fifth. Only risk: it precaches `zom_hud_icon_epod_key`
  (Die Rise); an error naming it is theirs.
- `scripts\zm\zm_transit\zm_transit_enhanced_noee.gsc` (`companion/`): its `te_richtofensay` is muted by the same
  `level.richcompleted` check vanilla uses, without a second `replaceFunc`; it reads `level.sq_progress`, which
  `df_compat` keeps for that reason.
- `scripts\zm\nav_autocomplete.gsc`: reads/writes only `sq_transit_started` and `navcard_applied_zm_transit`, the two
  vanilla stats our compat filter keeps. No conflict.
- Any "solo Easter Egg" script for TranZit (`tranzit_extra_richtofen_solo.gsc`, `tranzit_maxis_any_player_ee.gsc`)
  only alters the VANILLA quest, which Dead Frequency turns off: keep them out of the game folder.

## Rules every change must keep

1. **Everything physical exists from game start; steps only ARM it.** The pipes, the far light, the fog parts,
   the table, the four boxes, the four graves, the three power switches and the lamp set are spawned at boot, on
   both sides, and none of them is ever deleted; only fx (glow, flame, ON/OFF) follow the locked side and the
   open step. EXCEPTION (owner 2026-09-25, M2): a spent grave now EXPLODES and is deleted outright
   (`df_m2_fill`) once its zone quota is met - the four `DF_BRAZIER_n` are the one prop this rule no longer
   holds for; a future change should either accept that or restore the "stays standing, scorched" look this
   rule originally described. The only things that appear later are quest ITEMS, and **every quest item arrives
   by the shared strike** (`grenade_samantha_steal` burst +
   `zmb_avogadro_spawn_3d` thunder + a short quake): the coil, the key card, the M1 lantern, the rock.
2. **Cue grammar: one sound = one meaning.** Use the `df_cue_*` helpers, never a raw `playsound` for a quest
   cue; do not reuse a grammar alias for anything else (the table above is the contract).
3. **No on-screen timers.** Clocks are heard (`df_sys_clock_run`: the tick-tock loop + dry ticks under 30 s).
   `df_hud_timers` may draw one for a test only.
4. **Dialogue lines are <= 78 ASCII characters** so `"Richtofen: " + text` fits one HUD line; ASCII only, the
   HUD font has no accents. Voices: Richtofen manic (obelisk, the flesh, 115, my pretties), Maxis formal and
   technical (the Spire, energies, the design, the creature). Never "souls" (a Buried word).
5. **Never a colour word in a line.** The lamp colour does not render for everyone; lamps spark and hum. Say
   "the lamp that sparks", not "the blue lamp".
6. **One press for every pickup and placement** (`df_press_use`); holds only for the four channelling actions.
7. **Models via `df_model( kind )`, anchors via `df_coord( KEY )`**; never a literal model name or coordinate in a
   step file.
8. **Every builtin, helper, notify, fx, alias and model you use must exist in the decompiled vanilla scripts or
   the asset lists.** Grep before use; run the four lints; then test in game with `developer_script 1`.

## History

The mod was built between 2026-09-04 and 2026-09-11 in owner-tested passes: audits (design, story, dialogue, steps,
art, sound, play), each applied by one-shot patch scripts, then in-game feedback rounds. Those records and the
full commit history are kept privately by the owner; the public repository starts at 1.0.0-rc1 with a single
commit. Header comments in the sources still cite the audits by name (`audit_design.md`, `audit_V2*.md`, ...):
they describe decisions, not files you can open here.
