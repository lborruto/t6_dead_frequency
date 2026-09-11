# Contributing to Dead Frequency (developer documentation)

This file is for people who want to read, build, test or change the mod. Players should read the
[README](../README.md) and, for spoilers, [GUIDE.md](GUIDE.md). The owner's in-game test protocol is
[TESTING.md](TESTING.md); the model browser notes are [MODELS.md](MODELS.md); the original design document
(French) is [SPEC_fr.md](SPEC_fr.md).

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
  hatch at the Diner, sets the Galvaknuckles to 3000, and dumps the state on `!df fire compat`.
- `df_systems.gsc` - shared systems: the subtitle HUD (`df_say` / `df_show_line`, per-player hud elems destroyed
  on disconnect), vanilla VO helpers (`df_maxis_vox`, `df_rich_vox`, `df_vox_once`), FX helpers (`df_fx_loop`,
  `df_fx_burst`, `df_side_burst_fx`), the unified cue grammar (`df_cue_tick / _subgoal / _fail / _deny`,
  `df_step_focus`, `df_node_done_trail`), prompts (`df_prompt`, `df_prompt_puzzle` behind `level.df_hints`), the
  spoken-hint switch (`level.df_text_hints`), single press (`df_press_use`), hold-to-use bars, icons, stats, and
  `df_debug_print` (screen + `[DF]` console line).
- `df_steps.gsc` - the step machine and player-count scaling. Contract used by every act file (do not rename):
  `df_register_step`, `df_complete`, `df_touch`, `df_is_done`, `df_set_side`, `df_scaled`, `df_scaled_for`,
  `df_scaled_step`, `df_player_count`, `df_hint_now`, `df_step_avail_time`, `df_step_focus`, `level.df_side`,
  `level.df_done`, notifies `df_<key>_done`, `df_step_done`, `df_step_available`, `df_skip_<key>`,
  `df_side_locked`. Holds the scaling table (one row per key, four columns = 1..4 players) and the stall-hint
  ladder (START at +2 s, HINT_1 at 4 min, HINT_2 at 10 min then every 6 min).
- `df_dialogue.gsc` - the dialogue sheet, data only. Speakers `maxis` (shown to everyone) and `rich` (shown to
  the Stuhlinger player unless the line is tagged broadcast). Key families `<P>_START`, `<P>_HINT_1`,
  `<P>_HINT_2` and event keys per step; `_RICH` / `_MAXIS` variants for the shared acts. Writing rules are in its
  header (see "Rules" below).
- `df_coords.gsc` - world anchors and the model registry. Positions derive from TranZit's entity list
  (`tools/assets/zm_transit.d3dbsp.ents.txt`, dumped with the OpenAssetTools Unlinker); wall props find their wall at
  runtime with a trace; heights snap to the real floor. `df_models_init()` maps a kind (`table`, `tv`, `relay`,
  `fuse`, `card`, `brazier`, `skull`, `orb`, ...) to a model plus facing convention; step files never name a
  model, they call `df_model( kind )`. `df_apply_overrides()` is where `!df grab` output is pasted; overrides
  always win. Also the table (`DF_TABLE`, three slots; `DF_SOCKET` is moved onto it) and the curated
  `df_catalog_models()`.
- `df_lamps.gsc` - the ONE lamp set per game (3 lamps, 4 with a full lobby, picked at boot from the six lamps
  valid on both sides, diner and townbridge excluded) and every lamp look (`df_lamp_state_set`: off, souls,
  filled, tuning, waiting, anchored, charged, drained, final). The side colour is the map's own per-lamp client
  exploder fired from the server and re-fired after every power change; the clientfield is held at 0 so no
  green shows, and the server power flag is kept silently so burrows still work (`df_lamp_power_silent`).
- `df_scav.gsc` - the carry presentation layer in the style of Project Scavenger: the top-left pickup notice
  (one row below Scavenger's), the "Dead Frequency" TAB square right after Scavenger's fifth, and
  `df_scav_carry_set / _clear`, the API the acts call. Touches nothing of `zm_scavenger.gsc`; every field is
  `df_scav_*`.
- `df_catalog.gsc` - the full TranZit model catalogue (792 lines "name zone w h d", generated by
  `tools/gen_catalog.pl` from the glTF export). Development only: `!df sizes` reads it without precache.
  Replaced by `tools/catalog_stub.gsc` in the packed build (44 KB of strings).
- `df_place.gsc` - live placement mode (`!df grab <KEY>`): the anchor's prop follows the crosshair; fire places,
  melee cancels, ADS freezes, slots 1/2 turn, 3/4 raise, F toggles surface/float, jump resets. A place calls
  `df_coord_override` and prints the paste-ready line.
- `df_audition.gsc` - in-game audition of the game's own fx and sounds (`!df fx ...`, `!df snd ...`, the fx grid
  pages) so picks are made by eye and ear. Every fx key is registered server-side by a vanilla script; every
  alias is in the TranZit banks.
- `df_act1.gsc` - Act 1 "Static" (shared): Step 1 Dead Air (pipes + far signal light), Step 2 Salvage (three
  parts, relay built on the bus roof with the vanilla build hold), Step 3 Ride the Line (one full stop with power
  on, roof waves, relay hp), Step 4 Plug In (side lock at the table, graves / boxes removed). Also the portal
  refusal while carrying and the boot spawn of the fog parts and the table.
- `df_act2_rich.gsc` - Act 2 Richtofen: R1 Summon the Storm (Simon on the four barn boxes, key card, Avogadro
  capture at the tower, one-battery refill on failure), R2 Souls on the Line (hungry lamps, Galvaknuckle punch,
  spools), and the Richtofen side rules (Avogadro every round, Jet Gun relief, turrets without turbine,
  power-off penalty).
- `df_act2_maxis.gsc` - Act 2 Maxis: M1 The Cold Room (denizen latch at the table, the portal, the timed hunt
  in Nacht, the stone), M2 Fire and Ash (ember, four graves along the lava, burning kills, scorched nodes), and
  the Maxis side rules (denizen safety near the table and lit graves, doubled fog spawns, power-on penalty).
- `df_act3_sweep.gsc` - Step 5 Frequency Sweep: tune (hold 5 s) then anchor (turbine on Maxis, Galvaknuckle jolt
  on Richtofen) each set lamp; the audible countdown from the first anchor; fail-forward expiry with a soul
  penalty on the unanchored lamps only.
- `df_act3_vacuum.gsc` - Step 6 Vacuum: the orb's arrival at the drawn landing spot, the carry, the per-side draw
  (Jet Gun at a barn box / standing in lava at a scorched grave), the aura, home-flight of a dropped orb, the
  Step 7 restart contract (`df_s6_restart` / `df_s6_redelivered`).
- `df_act3_hold.gsc` - Step 7 The Line Holds: the wandering orb under the tower, our own sprinter spawner and
  alive cap, the orb hp and guard bonus, the zone rule, charge strikes, per-side pressure (Avogadro boss /
  denizens loose), the song, and the after-hold waves.
- `df_finale.gsc` - the finale (power gate, perks, build-up, orb rise, burst, permanent world change, rewards,
  globe stat), the Act 2 reward listener, and the tower tracker (runner lights per act, slot glows).

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
Load TranZit (Original). `!df status` must list `registered: step1 step2 step3 step4 r1 r2 m1 m2 step5 step6 step7 finale`.
Every `!df` answer is also printed in the console as `[DF] ...`, and every quest event prints a `DF: ...` line
there: paste those lines when reporting. The full protocol, step by step, is [TESTING.md](TESTING.md).

### Chat commands (need `df_debug 1`)

| Command | Effect |
|---|---|
| `!df status` | version, side, player count, round, hints state, steps done / available / registered |
| `!df goto <step>` | mark previous steps done, make `<step>` available (`step1..step4 r1 r2 m1 m2 step5 step6 step7 finale`). Never deletes the boot props (pipes, table, boxes, graves, lamps); the side lock still removes the other side's boxes / graves |
| `!df side rich` / `!df side maxis` | lock the side by hand (also picks the orb landing spot, console `orb landing spot ...`, and copies it into DF_ORB_SPAWN) |
| `!df say <KEY>` | show a dialogue key (`!df say s1_start` works too) |
| `!df scale` | print a few scaled values for the current player count |
| `!df simon` | solve the R1 Simon (storm + summon follow) |
| `!df souls` | fill every soul / carry counter of the open step: R1 refill (all four boxes charged), R2 (lamps filled AND every spool counted), M1 kills, M2 graves (all spent, ember returned), Step 5 penalty |
| `!df avogadro` | force Avogadro back from the cloud (only when he is in the cloud) |
| `!df side_fx` / `!df side_fx stop` | start / stop the tower visuals for the locked side |
| `!df power on` / `!df power off` | flip TranZit power (fires the real switch if built, else the flags) |
| `!df stat rich` / `!df stat maxis` / `!df stat none` | WRITES the completion stat (globe glow) for that side, or clears it |
| `!df hints on` / `!df hints off` | show / hide the on-screen puzzle prompts only (Jet Gun / lava hints, the cold-room take line, "take the skull" in the bunker); default off. Mechanic prompts (take / place / build / hold) always stay |
| `!df texthints on` / `!df texthints off` | the spoken hint ladder (HINT_1 at 4 min, HINT_2 at 10 min then every 6 min, event hints); default on. START / FAIL / DONE lines always play |
| `!df cue avail|tick|subgoal|fail|deny|trail|done` | plays one row of the cue grammar where you stand (step available, progress tick, sub-goal chime + flash + trail to the tower, fail thump, deny buzz, the trail alone, step done) |
| `!df vox <alias>` | plays a vanilla patron voice line (`vox_maxi_*` 3D at your feet, anything else 2D to Samuel); silence = unknown alias |
| `!df freeze` | toggle: every regular zombie stands still in the vanilla inert pose until toggled back (Avogadro and denizens untouched); new zombies freeze as they finish rising |
| `!df fx grid` / `!df fx gridnext` / `!df fx gridprev` / `!df fx gridbig` / `!df fx gridoff` | the curated effects in pages in front of you, 8 per row on small pedestals, one-shots re-fired so they stay visible (gridbig = the huge ones, fewer per page, wider apart; the client culls entity effects, so pages stay small); stand by a pedestal and the bottom label reads `[n] name`; the console prints the page |
| `!df fx list` / `!df fx <n>` / `!df fx next` / `!df fx prev` / `!df fx <name>` / `!df fx off` | audition one of ~150 server fx for 8 s where you aim; the console prints its index and name (df_audition.gsc). Pairs with the Effect Picker page |
| `!df snd list` / `!df snd <n>` / `!df snd next` / `!df snd prev` / `!df snd <alias>` | audition one of the curated bank sound aliases, played to you at full volume; the console prints its index and name. The same set is on the Sound Picker page with durations and ranges |
| `!df model` / `!df model <kind> <name>` / `!df orb <name>` | list the model registry / swap a model for props spawned from now on. A swapped model renders only if the map precached it; make it permanent in `df_models_init` (df_coords.gsc) |
| `!df show [KEY]` / `!df hide` / `!df tp <KEY>` / `!df dump` (= `!df coords`) | preview props with a glint / remove them / teleport to an anchor / print every anchor as `[SPOT]` and every model as `[MODEL]` |
| `!df lift <KEY> <up>` / `!df move <KEY> <fwd> <right> <up>` / `!df ang <KEY> <pitch> <yaw> <roll>` | tune an anchor live. `!df move DF_TABLE ...` moves the real table |
| `!df grab <KEY>` / `!df drop` / `!df cancel` / `!df rot <deg>` / `!df up <units>` | live placement: the prop follows your crosshair (fire = place, melee = cancel, ADS = freeze, 1/2 turn, 3/4 raise, F = surface/float, space = reset) |
| `!df pos` / `!df aim [KEY]` | print where you stand and what you aim at / snap an anchor to the aim point |
| `!df catalog <keyword|all> [page]` / `!df catalog pick <n> <kind>` / `!df catalog clear` | up to 10 candidate models in a row in front of you; `pick` assigns one to a kind. Needs `--multi` for the full list |
| `!df sizes <keyword|all> [page]` | list catalogue models with size and zone, no precache needed (`--multi` only) |
| `!df fire <name>` | generic hook, see the table below (`level notify( "df_debug_<name>" )`) |
| `!df` or `!df help` | full command list |

### Debug hooks (`!df fire <name>`)

| Step | Hooks |
|---|---|
| Act 1 | `a1_solve1` (Step 1 solved, the coil arrives), `a1_tv` (kick the next expected pipe), `a1_parts` (take every part, coil included), `a1_hit` (200 dmg to the relay), `a1_stop` (count the running sweep), `a1_relay` (relay to your feet), `a1_build` (vanilla build hands demo), `a1_receiver` (the coil arrives at DF_COIL_DROP now, without the pipes), `a1_corn` (the Maxis cornfield line at the relay) |
| R1 / R2 | `simon_solved` (= `!df simon`), `souls_done` (= `!df souls`), `r1_captured`, `r1_sounds` (click / buzzer / arpeggio), `r1_soul` (ONE box gets its battery without the bus trip), `r1_card` (card arrival fx), `r2_soul` (one soul into the first unfilled lamp), `r2_punch` (every full lamp gives its spool without the knuckles), `r2_spool` (one spool counts as placed) |
| M1 / M2 | `m1_latch`, `m1_kills`, `m1_cue` (kill cue demo), `m1_burst`, `m1_fog` (toggle bunker fog), `m1_ride` (first-ride cue: table pulse + line + hint, no denizen needed), `m1_skull` (drop the stone in front of you; fire again to send it to the table), `m2_ember` (you hold the ember now), `m2_light` (light the next unlit grave), `m2_fill` (spend every grave and return the ember), `m2_restage` (re-skin the graves after `!df model brazier ...`), `m2_penalty` (the power-ON penalty now), `m2_column` (the 20 s smoke column at the tower top) |
| Step 5 | `s5_anchor`, `s5_all`, `s5_time` (needs one anchor first), `s5_penalty` |
| Step 6 | `s6_orb` (orb to your feet), `s6_draw` (one charge), `s6_deliver`, `s6_restart`, `orb_aura` (next aura candidate) |
| Step 7 | `s7_start`, `s7_time` (win), `s7_fail`, `s7_hp`, `s7_dmg` (100 dmg; solo 3000 hp: damaged under 900, destroyed at 0, strikes heal in between), `s7_strike` (one charge strike now) |
| Finale | `finale`, `finale_nostat`, `finale_fx` (~15 s spectacle with a stand-in orb, repeatable), `finale_world` (the permanent world change alone, once), `a2_reward` (the Act 2 reward now, once), `perks` (give every perk + summary) |
| Lamps | `lamps` (every known lamp with set / state / silent / exploder), `lamps_all` (all 8 lamps in the side colour), `lamps_power` (silent power flag on all 8) |
| Misc | `scav` / `scav_slot` (Scavenger-style notice and TAB square demo), `table_demo` (table + slots preview: relay + mast, card, orb), `beam_test` (20 s beam to the nearest lamp; `set df_beam_fx <alias>`, `set df_beam_flip 1`), `compat` (vanilla-EE state + disk stats dump), `busparts` (re-run the ladder / hatch pin and print the part pools) |

Event hints: a step file may speak a hint the moment something happens (console `DF: event hint <KEY> (<step>)`);
the 4 min stall ladder then skips that rung once. `!df texthints off` silences the ladder (prompts have their own switch).

### Dvars (console, set BEFORE loading the map)

| Dvar | Default | Effect |
|---|---|---|
| `df_debug` | 0 | `1` enables the `!df` chat commands (including `!df status`) |
| `df_hud_timers` | 0 | `1` restores the old on-screen timers for a test (the shipped build has none) |
| `df_fx_pipe_flash` | `fx_zmb_tranzit_light_bulb_xsm` | the Step 1 pipe flash |
| `df_fx_signal` | `fx_zmb_tranzit_light_glow` | the Step 1 far signal light |
| `df_fx_pipe_locator` | `fx_zmb_tranzit_spark_blue_lg_os` | the one-shot spark closing each pipe cycle and each signal message |
| `df_signal_lift` | 70 | height of the signal light above DF_SIGNAL |
| `df_signal_hum` | `zmb_meteor_loop` | the loop played 20 above DF_SIGNAL_SND |
| `df_beam_fx` | (built-in choice) | the tower beam alias for `!df fire beam_test` / the node beams; try `fx_zmb_tranzit_god_ray_pwr_station`, `_interior_med`, `mc_towerlight` |
| `df_beam_flip` | 0 | `1` reverses the beam direction |
| `df_extra_models` | "" | space-separated model names to precache for `!df catalog extra` (up to ~10) |
| `df_catalog_page` / `df_catalog_pagesize` | - / 30 | precache one page of the full catalogue (`--multi` install) |
| `df_lamp_glow` | 1 | `0` turns the safety glow in the lamp bulb off (the exploder colour alone) |

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
df_coord_override( "DF_ORB_SPOT_2", ( 1401, -445, -67 ), ( 0, 90, 0 ) );
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
| DF_PART_A / B | part_a `p6_zm_buildable_sq_transceiver` (the radio), part_b `p6_zm_chain_fence_piece_end` (the mast, standing, 117 tall) | Cabin (-4830 -7978 -29) / tunnel (8149 -5088 52). DF_PART_C and `part_c` still exist in the registry; nothing is spawned there |
| DF_COIL_DROP | receiver = `p6_zm_buildable_sq_electric_box` (the wire coil) | where the coil lands after Step 1 (-6311 5019 -46); move it with `!df move DF_COIL_DROP ...` or `!df grab DF_COIL_DROP` |
| DF_BUS_ROOF_OFFSET | relay = `p6_zm_buildable_sq_transceiver` + relay_coil = `p6_zm_buildable_sq_electric_box` (+17) + relay_mast = relay_top = `p6_zm_chain_fence_piece_end` (+27), yaw -45: the same three pieces on the roof and on the table | bus roof centre / table slot 0 |
| DF_FUSE_1..4 | fuse = `p6_zm_buildable_sq_electric_box` (13 x 20 power box, centre at 50, 6 off the wall) | barn walls (Farm) |
| DF_CARD_SPAWN | card = `p6_zm_keycard` (the strike lands it 36 above the floor under the anchor) | barn wall (8614 -5864 91) |
| (battery / spool, no anchor) | battery = `p6_zm_buildable_battery`, spool = `p6_zm_buildable_jetgun_wires` | bus dashboard / the foot of a punched lamp |
| DF_BRAZIER_1..4 | brazier = `ch_tombstone1` (the graves, 31 tall, one player clip each) | four owner spots along the lava, tower -> cornfield (8831 -1185, 9296 -1073, 9913 -1193, 10363 -1240) |
| (ember, stone, no anchor) | ember = a flame fx (the registry kind `ember` is unused in hand), skull = `p6_zm_buildable_sq_meteor` (the STONE, rests 3 above its base) | table slot 2 / carried, then table slot 1 |
| DF_NACHT_SPAWN_1..4 | none, stand there | inside the Nacht bunker (13703 -822 -189 and three neighbours) |
| DF_TOWER_RETURN | none, stand there | return point after the Cold Room (7552 -512 -72) |
| DF_ORB_SPOT_1..3 | orb = `p6_zm_buildable_sq_meteor` (the same stone model, rests 3 above the ground) | the three Step 6 landing spots: diner (-5991 -7686 34), Town (1401 -445 -67), power station (11720 8491 -575) |
| DF_ORB_SPAWN | orb | a COPY of the spot picked at the side lock; Step 6 reads it when it starts |
| DF_ORB_TOWER / DF_ORB_DINER | orb | the old per-side spawns, kept only as fallbacks when no DF_ORB_SPOT exists |
| DF_PORTAL | portal = `p6_zm_screecher_hole` | the M1 hole in front of the table (7623 -457 -207) |
| (fx grid) | beacon = `p6_zm_buildable_sq_meteor` | the pedestals of `!df fx grid` |

Note: the stone (M1) and the orb (Step 6) share the meteor model; `!df catalog pick <n> skull` swaps the stone,
`!df orb <name>` the orb. `!df model` lists every kind; `!df fire table_demo` previews relay + mast, card and orb on
the three slots.

## Lamps

ONE lamp set per game (3 lamps, 4 with a full lobby), picked at boot from the six lamps valid on both sides (diner and
townbridge are skipped) with the idle spark marker; R2 feeds THESE, Step 5 tunes THESE. The side colour is the map's
own per-lamp client exploder (blue = 401 + 2i, orange = 400 + 2i, i = the lamp's area index) fired from the server and
re-fired after every vanilla power change, plus a safety glow in the bulb. `set df_lamp_glow 0` before loading turns
the safety glow off. No forced green under our light: the clientfield is held at 0 and the server power flag is kept
silently so burrows still work. States: off, souls (hungry: colour + hum + a spark every 2 s), filled (steady bulb
glow, no sparks), tuning, waiting, anchored, charged, drained, final (steady side colour after the finale, all 8 lamps).
Stall hints: a step untouched 4 min gets a hint line, then at 10 min and every 6 min (never once the finale is
reachable); an event hint spoken earlier skips the 4 min rung once. Vanilla EE: fully off (both quests, their dialogue,
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
| ITEM ARRIVAL | grenade_samantha_steal burst + zmb_avogadro_spawn_3d thunder + a short quake: coil, card, spools, stone, orb |

Side family: everything electric (blue sparks) on Richtofen and before the fork, everything fire / ash on Maxis.

## Co-installed mods (checked against the packed file)

- `scripts\zm\zm_scavenger.gsc` (Project Scavenger v1.9, NickB_05). Disjoint from Dead Frequency: it replaces only
  `_zm_buildables::player_can_take_piece`, we replace only the sidequest functions and the denizen portal use; our
  parts, coil, battery, spools, stone and orb are our own script_models, so a press can never be taken by both. The
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
   the table, the four boxes, the four graves and the lamp set are spawned at boot. The only things that appear
   later are quest ITEMS, and **every quest item arrives by the shared strike** (`grenade_samantha_steal` burst +
   `zmb_avogadro_spawn_3d` thunder + a short quake): the coil, the key card, the spools, the stone, the orb.
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
