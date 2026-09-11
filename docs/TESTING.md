# Dead Frequency - owner test guide (current build)

Solo, TranZit Original. Console BEFORE loading the map:

    developer 1
    developer_script 1
    set df_debug 1

Install first: `perl tools/deploy.pl` from the repo (Git Bash). Today the sources pack into TWO files,
`zm_transit_dead_frequency_1.gsc` + `_2.gsc` (see `release/`); both go in the game folder together and nothing
else from the repo. `!df status` prints the version: `DF <version> | side none | players 1 | round 1 | prompts off | texthints on`.

Every `!df` answer and every quest event lands in the console as `[DF] ...`: paste those lines when something is off.
ONE press of F = every pickup and placement (parts, coil, relay, card, battery, spools, stone, ember, orb) and every
pipe kick / grave touch.
Holds only: build the relay (3 s, vanilla bar + builder hands), tune a lamp (5 s, heard not seen), power the relay (3 s,
small bar "Powering the relay"), open the frequency (5 s, bar "Opening the frequency"). NO timer on screen anywhere:
every clock is the Pack-a-Punch tick-tock loop on every player plus dry ticks in the last 30 s (every second, doubled
under 10 s). `set df_hud_timers 1` before loading brings the old top-centre timers back for a test.
Two switches: `!df hints on|off` = on-screen PUZZLE prompts ("kick the pipe", Simon boxes, Jet Gun / lava hints, "take
the skull" in the bunker), default OFF; mechanic prompts (take / place / build / hold, kick the pipe, the Simon boxes) always stay. `!df texthints on|off`
= the spoken HINT_1 (4 min) / HINT_2 (10 min, then every 6 min) ladder and the event hints, default ON; START / FAIL /
DONE lines play whatever it says.
Cue grammar, one sound = one meaning: portal-arrive sound + glint on the object = a step is AVAILABLE; piece-add clink =
progress tick; NavCard chime + side flash + a spark runner flying to the tower top = a sub-goal done; the bridge groan
(2D) = STEP DONE (the only step-done sound); NavCard fail buzz = wrong input (only you hear it); bus EMP thump =
something lost / failed; Samantha-steal burst + Avogadro thunder + a short quake = a quest ITEM ARRIVES (coil, key card,
spool, stone, orb: every item comes by that strike). `!df cue avail|tick|subgoal|fail|deny|trail|done` plays each one
where you stand.
Side family: everything electric (blue sparks) on Richtofen and before the fork, everything fire / ash on Maxis.
Useful cheats: `!god`, `!points`, `!ammo`, `!kill`, `!round <n>`, `!gun jetgun_zm`, `!gun turbine_zm`, `!gun
tazer_knuckles_zm`; `!df freeze` (ours: every regular zombie stands inert until toggled back, denizens and Avogadro
untouched, new zombies freeze as they finish rising).

## 0. Load
- No red error popup. `!df status` -> the version line above, `registered: step1 step2 step3 step4 r1 r2 m1 m2 step5 step6 step7 finale`, `available: step1`.
- `!df fire compat` -> `DF compat: richcompleted 1 maxcompleted 1` (vanilla quest muted). Console at boot: `bus parts
  pinned (n moved): ladder at the Depot, hatch at the Diner` and `Galvaknuckles cost 3000 (was 6000)`.
- ~20 s into round 1: MAXIS (orange name, white text) then RICHTOFEN (blue name) bottom centre, a soft tick per line.
  Readable? Cut on the right? A vanilla Maxis voice line plays at the phone when Step 1 opens (console `vox vox_maxi_tv_distress_0 3D`).
- `!df fire perks` -> `finale perks (debug): 5 perks` + one `finale perk X given` line each, five icons. `!df say FIN_RICH_2` (longest line): still readable?
- `!df scale` -> `players 1 | lamp_souls 12 | nodes 3 | sweep_time 360 | sweep_time_rich 480` and `hold_time 75 | orb_hp 3000 | s7_period 1.3 | s7_cap rich 10 maxis 14`.

## 1. What to check at round 1 (touch nothing first)
Everything below must already be there. Missing = the biggest bug of this build.
- Console during round 1: `table spawned at 7771 -448 ...`, `radio at ...`, `mast at ...`, four `screen n at ..., blinks k`
  (the pipes; `step1 order (pipe indexes) ...`), `signal light at ... (fx ...)`, `signal hum (zmb_meteor_loop) at ...`,
  four `m2 brazier_n at ... (ch_tombstone1)` (the graves), `lamp set: skipped diner townbridge ...`, `lamp set (3): <areas>`. Paste them.
- Depot: four PIPES (chimney pipe, 9 tall) on the ground around the depot (`!df tp DF_TV_1..4`), each blinking its own
  number (short flashes, a dark gap, ONE blue spark in the gap), no steady glow. Past the fence (`!df tp DF_SIGNAL`, the
  light 70 above the anchor) a light flashes the order in GROUPS with a click per flash and the same blue spark closing
  the message; a hum at `DF_SIGNAL_SND`. Is the far light visible from the Depot? Can you count four blinking pipes?
  Say so. The wall phone: no glint, no prompt, nothing on press.
- Fog: `!df tp DF_PART_A` radio (cabin), `DF_PART_B` mast (tunnel, a 117-tall post standing). Glint on each. `DF_PART_C` still exists as an
  anchor but NOTHING lies there (the third part is the wire coil, which arrives after Step 1). Take one part now: notice
  "Relay parts (1/3)", console `radio taken (1/3)`. It must count later.
- Tower: `!df tp DF_TABLE`: the work bench stands there, empty. Walk into it: you must NOT pass through, and you must
  NOT be able to jump onto it (two rows of clips, a 64-tall wall). `!df move DF_TABLE 20 0 0` moves the real table
  (`table follows DF_TABLE to ...`); move it back or restart.
- Barn: `!df tp DF_FUSE_1..4`: four small power boxes (13 x 20, centre at mid height) on the walls, faint glow, back
  against the wall, lever side towards the room. Press F on one: nothing.
- Lava: `!df tp DF_BRAZIER_1..4`: four TOMBSTONES in a row along the lava (tower -> cornfield), standing on the ground,
  nothing on them, no fire, no glow. Walk into one: you must not pass through.
- Lamps: walk to one lamp of the printed set: one small electric spark at the bulb every 6 s, no colour, not green.
  `!df fire lamps` lists 3 lamps `set 1 state off`. None of them is diner or townbridge; one is the lamp nearest the tower.
- Bus parts: the ladder lies at the Depot (-7313 5441), the hatch at the Diner (-3537 -7214). `!df fire busparts`
  re-runs the pin and prints the pools.
- Not there yet, correct: coil, key card, orb, battery on the bus, spools, stone, ember.

## 2. Models, effects, sounds (once)
    !df show
    !df tp DF_TABLE       work bench under the tower, front towards you; `!df fire table_demo` puts radio + coil box +
                          tall post on slot 0, card on slot 1, the stone on slot 2 (`!df hide` removes them)
    !df tp DF_TV_1        chimney pipe (pb_pole_telephone_bulb, 9 tall) on the ground (also TV_2..4)
    !df tp DF_SIGNAL      the far light spot (light 70 above); DF_SIGNAL_SND the hum spot
    !df tp DF_COIL_DROP   where the coil lands after Step 1 (-6311 5019 -46): preview of the electric box
    !df tp DF_FUSE_1      power box on the barn wall (also FUSE_2..4); IN the wall or floating? say which
    !df tp DF_BRAZIER_1   tombstone on the ground (also 2..4); sunk? floating?
    !df tp DF_CARD_SPAWN  key card preview upright on the barn wall, clear of panel 4
    !df tp DF_PORTAL      the M1 hole spot in front of the table (7623 -457 -207)
    !df tp DF_ORB_SPOT_1  the diner landing spot (-5991 -7686 34); SPOT_2 Town (1401 -445 -67); SPOT_3 power station
                          (11720 8491 -575): the stone preview on the ground at each, off the road?
    !df side rich         console `orb landing spot ...` (one of the three, at random; `!df side maxis` picks again)
    !df dump              one [SPOT] line per anchor + [MODEL] lines
Report: invisible / black / sideways / wrong size, with the anchor name. Fix live: `!df grab DF_ORB_SPOT_2` (fire =
place), paste the printed line. `!df hide` when done. The stone (M1) and the orb (Step 6) are the SAME meteor model.
Picking by ear and eye: the picker pages (Sound, Prop, Effect; self-contained HTML built by the generators in `tools/pickers`)
list the same sets as `!df snd list` / `!df fx list`. In game: `!df snd <n>` / `!df snd next` plays a sound to you at
full volume and prints its name; `!df fx <n>` / `!df fx next` plays an effect 8 s where you aim (`[FX n/150] name`);
`!df fx grid` puts a whole page of effects on pedestals in front of you (`gridnext` / `gridprev` / `gridbig` for the
huge ones / `gridoff`), walk to a pedestal and the bottom label reads `[n] name`. Paste the numbers or names you want,
and for what (pipe flash, signal light, lamp hungry / full / anchored, grave flame, orb aura, ...).

## 3. Act 1 (shared)
**Step 1 Dead Air** (depot, no power). Skip: `!df fire a1_solve1` or `!df goto step2` (the coil arrives in both cases).
- Count the far light's groups ("3, pause, 1, pause, 4, pause, 2"), then KICK the pipes whose blink count matches, in
  that order (one press each; "Press F to kick the pipe" only with `!df hints on`): a spark on the pipe, it stops
  blinking and its light stays on. Holding F must not repeat. Console `screen n used, expected screen m, progress k`.
- Wrong pipe: the deny buzz (you only), all pipes blink again, console `wrong pipe, all pipes back to blinking (the
  signal keeps flashing the order)`. Same order. `!df fire a1_tv` kicks the next expected pipe.
- All four: `step1 solved, all four screens on`, bus dashboard pulse 5 s (NO horn), D1 lines, the step-done groan,
  `step complete step1`. Then the STRIKE at DF_COIL_DROP (burst, thunder, quake) and a glinting electric box on the
  ground: `the phone dropped the receiver (part 3) at ...`, Richtofen names it. One press: "Relay parts (n/3)". The
  pipes stay, dark, no spark; the far light and its hum are off.
- Fx to try (before loading): `set df_fx_pipe_flash <fx>`, `set df_fx_signal <fx>`, `set df_fx_pipe_locator <fx>` with
  any name from `!df fx list`; `set df_signal_lift <units>` (default 70), `set df_signal_hum <alias>` (default
  zmb_meteor_loop). Move the light: `!df grab DF_SIGNAL`, paste the printed line.
- Wrong: paste the `screen n used ...` lines and `step1 order ...`.

**Step 2 Salvage** (fog). Skip: `!df goto step3` (parts deleted, relay built).
- Take the remaining parts (one press, notice n/3, TAB square). `!df fire a1_parts` takes the rest, coil included.
- Bus roof with TWO parts: NO build prompt. With all THREE: "Hold F to build the relay", gun lowers, vanilla progress
  bar + builder hands, 3 s, the relay stands on the roof turned 45 degrees: radio, the coil box on it, the 117-tall
  mast on the box (the same relay as later on the table), console `relay built on the bus roof at ..., hp 800`,
  Maxis's vanilla "build complete" voice once. `!df fire a1_build` demos the hands anywhere.
- `!df power off`: relay dark. `!df power on`: tiny glow + a spark every 2-3 s.

**Step 3 Ride the Line** (power ON). Skip: `!df fire a1_stop` (needs a running sweep) or `!df goto step4`.
- Glint on the relay until the first sweep. Bus leaves: `sweep 1/1 started, bus left <stop>, relay hp 800`, a blue
  burst on the relay every 1.5 s (no big spark cloud over the bus), and `roof waves on: a zombie every 2.5 s near the
  bus, up to 10, until the relay locks or the sweep ends`: zombies keep rising along the road and climbing on.
- Roof zombies swing: sparks, `relay hit, hp 740` (60 a hit). `!df fire a1_hit` (200) x2: `relay damaged, hp 400,
  second burst layer on`; x3: `relay low, hp 200, warning horn`.
- Arrival: leave horn, blue burst, 8 s of tower lightning, `stop 1/1 counted at <stop>`, then `relay locked, take it to
  the tower` + the dashboard power pulse replaying on the relay, `roof waves off`, D3 lines, `step complete step3`. ONE stop only.
- Wrong: paste every `sweep ...` / `bus left ...` / `roof waves ...` line.

**Step 4 Plug In**. Skip: `!df goto r1` (rich) or `!df goto m1` (maxis; the goto locks the side itself).
- One press within 120 takes the relay (`relay picked up by`, sparks on your back). Portal at a lamp: deny buzz, refused.
- Carry it into the cornfield: Maxis's vanilla "Spire" voice once (`locked relay entered the cornfield`).
- Walk towards the table with power ON: from ~400 units a plain small glow on the table is BLUE (no lamp-shaped light),
  console `table preview rich`. Walk away: off (`table preview off`). `!df power off`, come back: ORANGE, `table preview maxis`.
- One press within 150: blue burst + clink + switch-on sound, the relay stands on the LEFT slot, turned 45 degrees,
  with the coil box and the TALL post on it (`plugged relay at ..., top piece relay_mast`), the colour stays, tower
  visuals 15 s, one vanilla voice line, D4 line, `relay plugged by <you>, power 1, side rich`. A white runner starts
  climbing a tower leg every ~5 s and stays for the game; a tiny glow on the left slot.
- Side lock: power ON = `side rich` and `Richtofen side locked, the four tombstones are gone` (check the lava: no
  graves); power OFF = `side maxis` and `Maxis side locked, the four Simon boxes are gone` (check the barn: no boxes).
  Both print `orb landing spot ...` (the Step 6 spot). `!df status` shows the side.

## 4R. Richtofen side (power ON): `!df goto r1` in a fresh game if needed
**R1 Summon the Storm** (barn). Skips: `!df simon` (solves it), `!df fire r1_captured` (skips the fight).
- R1 opens: a spark runner flies from the table to the barn, the four boxes brighten, the AVAILABLE glint sits on
  box 1's LED (nothing floats at the barn centre; "Press F" at a panel only with hints on).
- Simon: one blue one-shot spark per box, `simon k/6 boxes: ...` matches what you see. Correct = click. Press a WRONG box
  on purpose at length 3: deny buzz + EMP thump at the box, console `simon wrong at k, replay`, the SAME three sparks
  replay. 20 s without a press: `simon abandoned (no input)`, press again to restart.
- Solved: three rising clinks, all boxes spark, then the STRIKE on the barn wall at DF_CARD_SPAWN (burst, thunder,
  quake) and the NavCard chime + a runner to the tower: `key card at ...`. The card must be VISIBLE. One press takes it
  (`key card taken`), one press at the table inserts it (`key card on the table, slot 1`, middle slot, lying 2 above
  the top, glint on it).
- Case A (nobody stood at the power core yet): NO clock, Richtofen's chamber line, console `avogadro state chamber`. Look
  at the core in the power room: `avogadro released`, called down and `avogadro warped to the tower`.
- Case B (he roams or sits in the cloud): storm over the tower, `avogadro called down`, warped to the tower at once.
- While he is alive within 900 of the tower the table pulses BLUE. The last 30 s of the 240 s clock tick once a second;
  stay near him past it: NO fail while he is within 900.
- Knife him 3 times (vanilla's defeat): `avogadro captured at the tower`, soul trails from the table into the 4 boxes, a
  blue burst on each, the card's glint becomes a steady glow, `step complete r1`. Maxis's vanilla stab line once.
- Wrong: paste `simon ...`, `avogadro ...` lines.

**R2 Souls on the Line**. Skips: `!df fire r2_soul` (one soul), `r2_punch` (every full lamp frees its spool), `r2_spool` (one spool counted), `!df souls` (all).
- Console `r2 3 lamps, 12 souls each`, then per lamp `r2 lamp X: N spawn structs for its waves`. At a set lamp: the
  side colour IN the bulb, a hum, a spark every 2 s (HUNGRY), a light shaft from the tower and a light column at the
  base. NOT green.
- Stand within 450 of a hungry lamp: every 3 s two zombies rise nearby (`r2 two zombies pulled to lamp X (<you> under
  it)`) while fewer than 20 live. Kill within 450 of the post: `lamp X souls a/12` every 5, a trail into the bulb and a
  clink for EVERY soul (every trail must be visible, no streak). A miss says `kill not absorbed: NNN from lamp X (need
  450, ...)`.
- At 12: `lamp X filled`, NavCard chime + blue flash + runner to the tower, beam off, the sparks STOP and the bulb keeps
  a steady glow (no electric arcs), Richtofen: "punch the post". Console `lamp X full: punch the post with the knuckles
  to get the spool`.
- Buy the Galvaknuckles (Diner roof, through the hatch, 3000). Melee the post within 90: a spark on the post, `r2 lamp X
  punched by <you>, the spool is out`, the STRIKE at the lamp's foot and a glinting WIRE SPOOL on the ground (`spool at
  lamp X`). Richtofen names the first spool. Knife the post instead (or any gun melee): deny buzz + "Bare steel? No."
  (once per 20 s), console `r2 <you> hit lamp X without the knuckles (<weapon>)`, no spool.
- "Press F to take the spool" (`spool taken (1 in hand, 0 placed)`); spools STACK, carry all three; at the table "Press F
  to place the spools": clink + spark at the relay slot, one glow per spool climbs the post, `spool placed 3/3`,
  `step complete r2`, R2_DONE, Step 5 opens.
- Act 2 reward at once: `act 2 reward given (rich): side reward + Max Ammo at the table`, Richtofen's reward line, blue
  runners start climbing the tower next to the white one. Place a turret (`!gun turret_zm`) with no turbine: it fires.
- Side rules: hold the Jet Gun until the heat passes 50: the needle stalls. Power OFF and end a round: `power off: lamp X
  -5, n` (a filled lamp reopens, hungry again). Avogadro comes back EVERY round (`avogadro returns next round`).

## 4M. Maxis side (power OFF): `!df goto m1` in a fresh game (the goto locks the side)
**M1 The Cold Room**. Skips: `!df fire m1_ride` (ride cue), `m1_latch`, `m1_kills`, `m1_skull` (stone in front of you; fire again = on the table).
- `!df goto m1`: console `m1 waiting for a denizen latched within 300 of the table` then `s7 tower safety volumes
  removed: N`. Denizens now rise AT the tower in the fog. Glint over the table.
- Let a denizen jump on you anywhere: the portal-open sound, the table pulses ORANGE 5 s, Maxis's M1_EVENT line,
  console `m1 first ride: table pulse + event line`. Only the first time.
- Walk to the table with it: it dies in ash, `m1 denizen latched at the table`, `m1 portal at 7623 -457 ...`: the hole
  rises out of the ground in front of the table and spins with an orbiting orange light; the glint moves onto it.
- Walk INTO the hole (no F): warp sound, black flash, Nacht. `m1 cold room 60 s, 6 denizen kills`, cold fog, the
  tick-tock (no timer). Denizens rise two at a time (`m1 denizen rising at`); each kill = trail + ash + `m1 denizen kill k/6`.
- Success: `m1 cold room over: success`, the STRIKE where the last one died and the STONE (the small meteor rock) lies
  there with a glint (`m1 skull on the floor at ..., one press takes it`: console and prompt still say "skull"),
  Maxis: "Lightning left you a stone"; 30 s window, "Press F to take the skull" within 100 ("Take the skull before the
  cold closes" for the room only with hints on). Then everyone is sent back (`m1 1 player(s) returned to the tower`).
  Nobody took it: `m1 skull not taken in 30 s, it comes along to the tower`, it lies at the tower return point with its
  glint, NEVER placed by itself.
- Carry it (notice, no lamp portals, drops at your feet if you go down: `m1 skull dropped`). "Press F to place the
  skull" within 150 of the table: `m1 skull on the table, slot 1 (...)`, tower orange 12 s, M1_DONE, `step complete m1`.
- After M1: `m1 side rules on: denizens avoid the table and lit braziers (400), fog spawns doubled`. Stand near the table
  with a denizen on your head: it jumps off.
- Timeout: `m1 cold room over: timeout`, back at the tower with an ash burst + EMP thump, Maxis's fail line, `m1 failed
  (timeout), back to the latch`.

**M2 Fire and Ash**. Skips: `!df fire m2_ember` (you hold it), `m2_light` (next grave lit), `m2_fill` (all four spent, ember returned), `!df souls` (same), `m2_column` (smoke replay), `m2_penalty`.
- M2 opens: `m2 the ember burns on the table: take it (one press), touch any tombstone with it, 5 burning zombies at a
  lit one make it vanish; all four gone = bring the charged ember back to the table`. A FLAME burns on the table's
  RIGHT slot with the glint; the four graves stand dark.
- "Press F to take the ember" within 100 of the table: pickup sound, ignite crack, lava fire on your body, health drops
  5/s (never below 15 by the ember alone), `m2 ember taken from the table by <you> (5 hp/s while carried; it stays in
  hand for the whole step)`, Maxis names it once. Lamp portal: deny, refused.
- Within 100 of a DARK grave: "Press F to light the grave". One press: whoosh + ignite + ash puff, a SMALL flame at the
  base of the tombstone, a clink, the ember STAYS in your hand: `m2 brazier_n lit by <you> (1/4 lit, 3 to go, the ember
  stays in hand)`. Any order, any number lit at once. Console `m2 brazier_n: N spawn structs for its waves`.
- Stand within 300 of a lit grave: every 4 s one zombie rises nearby (`m2 one zombie pulled to brazier_n (<you> beside
  it)`, up to about ten around you), crosses the lava and burns. Kill it burning within 250 of that grave: a fire burst
  at the body, a fire trail into the grave, clink + lava puff, `m2 brazier_n 1/5`. A burning kill at a DARK grave does
  not count (console silent). At 5: `m2 brazier_n spent and gone (k/4)`: the tombstone bursts (large fire + rising ash)
  and VANISHES, a scorched lava glow stays on the ground.
- All four gone: NavCard chime + fire flash + a runner from YOU to the tower, the flame on your body grows, `m2 all four
  stones spent, the ember is charged: return it to the table (one press within 150)`. At the table "Press F to return
  the ember": fire burst at the table, `m2 the charged ember is back in the table`, `step complete m2`, tower orange
  12 s, `m2 smoke column at the tower top for 20 s`, M2_DONE, act 2 reward at once (`act 2 reward given (maxis)`, Max
  Ammo, Maxis line, orange runners on the tower). `!df fire lamps`: `silent 1` on all 8 lamps; a denizen dropping at any
  lamp opens a portal, no turbine.
- Galvaknuckles (`!gun tazer_knuckles_zm`) melee within 100 of a grave, or anywhere with the ember in hand: deny buzz +
  "His current will not touch my graves", console `m2 <you> used the knuckles at the stones: refused`.
- Wrong: paste the `m2 brazier_n ...` lines and whether the zombie was burning.

## 5. Act 3 (shared; what differs per side is marked)
**Step 5 Frequency Sweep**. Skips: `!df fire s5_anchor` (one lamp), `s5_all`, `s5_time` (expire, needs an anchor), `s5_penalty` (pay it), `!df goto step6`.
- Console `s5 sweep open: 3 set lamps, anchor 3 (turbine within 200 | knuckle jolt on the post), timer 360 | 480 s from
  the first anchor` (Maxis 360, Richtofen 480). ONLY the same three lamps get "Hold F to tune"; each untuned one wears a
  glint at the bulb; no lamp turns green.
- Hold F 5 s: a rising power sound at the lamp (NO bar), 1 / 2 / 3 quick ticks at 25 / 50 / 75 %, then two clinks and
  `lamp X tuned, waiting 15 s for an anchor`: the light blinks, tick-tock at the lamp, no timer, the electric arcs are
  off. The first time, the patron names the anchor (S5_ANCHOR_TURBINE_MAXIS / S5_ANCHOR_DENIZEN_RICH = "Punch the post!").
  - MAXIS: put a RUNNING TURBINE within 200 of the lamp base (before or during the wait): NavCard chime + fire flash +
    runner to the tower, `lamp X anchored (1/3)`, and only now `s5 countdown started at the first anchor: 360 s`, ticks.
  - RICH: melee the post with the GALVAKNUCKLES within 90 while it ticks (or up to 45 s before you tune it): `s5 lamp X
    jolted by <you> (counts as the anchor for 45 s)`, anchored, `s5 countdown started ...: 480 s`. A denizen burrow does
    NOTHING here any more. Richtofen's vanilla lamp line once.
  - Without an anchor: after 15 s EMP thump + side fx at the lamp, `no anchor within 15 s, signal lost, draining`, 10 s,
    `tunable again`, prompt back. No countdown.
- The countdown is the Pack-a-Punch tick-tock riding you (one loop per player, everywhere on the map); the dry ticks join
  under 30 s. Anchored lamp: steady side light + light shaft from the tower + slow double burst, no arcs. 3 anchors:
  D5_DONE, `step complete step5`.
- Wrong: paste `s5 lamp X ...` lines; on Maxis say where the turbine stood.

**Step 6 Vacuum**. Skips: `!df fire s6_orb` (orb to your feet), `s6_draw` (one charge), `s6_deliver` (finish), `s6_restart`, `orb_aura` (next aura), `!df goto step7`.
- Step opens: `s6 build-up over the tower, the orb arrives in 3 s` (RICH storm cloud + rumble / MAXIS smoke column), then
  a bolt + thunder (RICH) or a fire burst + ignite (MAXIS) at the spot, `s6 strike at DF_ORB_SPAWN`, and the STONE lies
  on the ground there, glint + light shaft on it. The spot is the one printed at the side lock (`orb landing spot ...`):
  the diner, Town or the power station, on EITHER side (`!df tp DF_ORB_SPOT_1..3`). The Step 5 lamps go dark. Console
  lists the nodes: RICH `s6 node 0 fuse fuse_1` .. 3 (the barn boxes, shaft + column + hum on each); MAXIS `s6 node 0
  brazier brazier_1` .. 3 (the scorched spots where the graves stood, shaft + column + hum on each).
- One press within 100 takes it (`s6 orb picked up by <you> (0/4 charges)`, notice, TAB square). No lamp portals while
  carrying. MAXIS: Maxis's fire line once. RICH with no Jet Gun in any inventory: Richtofen's vacuum line once; otherwise
  D6_HINT once per game.
- RICH: `!gun jetgun_zm`, carry the orb to a panel, fire at it within 300 looking at it: a rising power sound (no bar),
  `s6 drawing node k`, after 5 s cumulative NavCard chime + flash + runner to the tower + meteor ping + trail into you,
  `s6 charge 1/4 in the orb (node ...)`, blue arcs on your torso. Refused: `jet gun firing but no charged node within
  300` / `firing near node k, aim NN/100 (need 80)`; carrier with no Jet Gun in hand within 300 of a panel: deny buzz
  once per approach (`draw refused at node k`). Heat is bled above 30 while you draw (`jet gun running hot` line once).
- MAXIS: walk with the orb to a scorched spot: within 300 Maxis's lava line once. Stand IN the lava next to it 5 s
  cumulative (step out = pause; you burn the whole time: Juggernog helps): rising sound, then `s6 charge 1/4`. Outside
  the lava within 300: `carrier near node k but not on lava` and after 2 s one deny buzz. The Jet Gun does nothing here.
- All charges: three clinks, `s6 orb fully charged, bring it to the tower socket`, aura + hum on the stone and on you
  (RICH avogadro_health_full, MAXIS powerup_on_caution; `!df fire orb_aura` cycles). At the table with charges missing:
  "The orb needs N more charge(s)". Full, one press within 150: "Press F to place the orb in the relay", power pulse +
  flash + clink, the stone rests on the RIGHT slot with its aura, glow on the slot, D6_DONE, `step complete step6`.
- Drop test: go down while carrying: `s6 orb dropped at ..., 60 s to pick it up`; wait: `s6 orb returned home (...)` =
  the NEARER of the landing spot and the table front, charges kept.

**Step 7 The Line Holds**. Skips: `!df fire s7_start`, `s7_time` (win now), `s7_fail`, `s7_hp` (print hp), `s7_dmg` (100 dmg), `s7_strike`.
- At the table: `s7 socket armed (hold 3 s, orb 3000 hp, period 1.3 s, cap 10 | 14, 1 player(s))`, glint over the right
  slot, "Hold F to power the relay". Hold 3 s (bar "Powering the relay"): the stone leaves the slot and wanders under the
  tower HOVERING 40 UP with its aura and hum (easy to see from the road?), switch-on + power-down sounds, D7_START, `s7
  wave started, 75 s, orb 3000 hp, side X, guard bonus within 200`, the song starts (`s7 song started`), the tick-tock
  rides you. `s7 spawner on: every 1.3 s, cap 10 (1 player(s) at wave start)`.
- RICH: `s7 Richtofen pressure: Avogadro from the start`, storm at the tower top, Richtofen's Avogadro line once, his
  vanilla "lure them" line once. He lands: `s7 avogadro landed wounded (1 hit seeded, 3 knife hits banish him)`. Knife
  him 3 times: `s7 avogadro banished by knife, Max Ammo at the table`, chime, Max Ammo in front of the table, storm off.
- MAXIS: `s7 Maxis pressure: denizens from the start`, `s7 denizens released on the tower`, denizens at the tower from
  the first second, a smoke column at the tower top for the whole wave.
- Sprinters rise near YOU (spawn structs within 900 of a random living player) and run to the stone: sparks + `s7 orb hit
  by zombie, hp 2970` (30). Stand within 200 of the stone: `hit by zombie (guarded), hp ...` (15). Every 10-20 s `s7
  charge strike n healed the orb +300 (guarded 0)` (+450 when guarded): 2 s of denser bursts, then RICH bolt +
  lightning orb / MAXIS fire burst + ash, thunder.
- Zone: leave the 700 zone 4 s, come back 6 s, leave 4 s, come back: no fail, console `s7 zone held 5 s, absence counter
  reset`. Leave 11 s straight: fail (`zone abandoned`). Horn at 5 s away (`zone empty for 5 s cumulative`).
- `!df fire s7_dmg` until hp is under 900: `s7 orb damaged (...): warning beeps on`, faster bursts, a beep every 2 s.
  Keep firing to 0: `s7 orb destroyed`, `s7 wave over: fail_orb`, side flashes + EMP sound, D7_FAIL, `s6 restart:
  charged orb (4/4) waiting in front of the table`. One press takes it, one press places it (`s7 orb redelivered, the
  table is armed again`), hold again. Song must NOT play twice within 330 s. Never two stones at once.
- Survive (or `!df fire s7_time`): `s7 wave over: success`, tower lights, the stone glides back onto the right slot in 2 s
  with the rising sound, `s7 orb back on the table, slot 2`, light column, D7_DONE, `step complete step7`, one more white
  and one more side runner on the tower. MAXIS: `s7 denizen levers restored`, `s7 tower safety volume restored`.
- AFTER the hold the song keeps playing (256 s, it cannot be stopped): `s7 after the hold: waves near the players until
  the song ends in N s`. Walk anywhere: zombies keep rising near you (every 1.3 s, up to the cap around you) and hunt you
  normally, no stone to defend. When the song ends: `s7 after-hold waves over (song ended, or a new wave)`. The finale
  can be started meanwhile.
- Wrong: paste `s7 wave over ...`, the last `s7 orb hit ...` and `s7 charge strike ...` lines.

**Finale**. Skips: `!df fire finale` (full run), `finale_nostat` (no globe stat), `finale_fx` (~15 s show, stand-in orb, repeatable), `finale_world` (world change alone), `a2_reward`.
- `finale waiting at the table (side X)`, glint on the table, "Hold F to open the frequency". Power gate: RICH power ON;
  MAXIS power OFF now, OR the round STARTED with the power off (turn it ON mid-round, the hold is still accepted). Wrong:
  deny buzz while you hold, the patron complains once per 20 s, `finale refused, wrong power state for side X`.
- Hold 5 s (bar "Opening the frequency"): `finale start, side X, nostat 0`. Order: all perks (one console line each),
  `finale build-up (6 s, X)` (RICH: electric hum, blue sparks and arcs over the table; MAXIS: fire crackle, fire pulses,
  ash column at the base, smoke column at the top; both shake), `finale orb rising to the tower top (6 s, stand-in 0)`:
  the stone lifts off the right slot with the reactor hum, `finale burst, tower fx on`, lightning at the top, side flash,
  thunder, 3 s shake, one vanilla voice line, `s6 orb consumed by the finale`. Then EVERY fog lamp of the map is in the
  side colour (`lamps: all 8 lamps coloured ...`): check the depot lamp and the town lamp, far from the tower. Console
  `finale world change done (X)`, the patron's world line, the keepsake line for the card / stone on the middle slot
  (`finale keepsake on slot 1`), sting, Max Ammo (`finale power-up dropped`), `side reward already given (Act 2), not
  repeated`, screen message "Dead Frequency complete: ...", `finale stat written for side X`, three closing lines
  (6.5 s apart), `finale done`, `step complete finale`.
- RICH: `avogadro banished to the cloud (return_round 9999)`; play two more rounds: he never returns. MAXIS: `denizen cap
  reset to 0 (finale)`; no denizen appears in the fog again.
- `!df stat none` clears the globe afterwards.

## 6. Fail paths (each in its own game or with `!df goto`)
- Step 1, wrong pipe: deny buzz, all four blink again, same order; the far light never stops. Kicking a pipe twice or
  holding F must not count twice.
- Step 3, relay destroyed: 14 roof swings (or `!df fire a1_hit` x4): EMP thump + explosion, `relay destroyed, parts back
  on the roof`, THREE glinting parts on the roof (radio fore, mast aft, coil right). One press each, rebuild, ride again.
- Step 3, EMP near the bus during the ride: `EMP near the bus, sweep lost`, the relay stays. Power OFF: `bus left <stop>
  without power, no sweep`. Empty bus 6 s: `nobody on the bus for 6 s, sweep lost`.
- R1, capture fail: kill him far from the tower, or walk him away after 240 s: `avogadro not captured`, EMP thump at the
  table, Richtofen's fail line, `r1 locked, one battery from the bus charges the four boxes`, the boxes go dark. ONE
  glinting BATTERY on the bus dashboard (`battery on the bus`), Richtofen names it. "Press F to take the battery" within
  100 (`battery taken`, notice "0/4"). Walk to the barn: "Press F to charge the box" at every empty panel (within 70):
  glow + sparks + clink, `box n charged k/4`, the battery STAYS in hand; at the fourth `battery consumed, all four boxes
  charged`, NavCard chime + runner, `r1 unlocked, simon available again`. ONE bus trip. Go down while carrying:
  `battery dropped` at your feet, pick it up again. `!df fire r1_soul` charges one box without the trip, `!df souls` all four.
- R1, power OFF at the end of a round during the lock: `power off: box n emptied` (one more panel to charge).
- R2, full lamp punched with the wrong tool: deny + "Bare steel? No.", no spool; `!df fire r2_punch` frees every ready spool.
- M1, timeout: see 4M. M1, stone carrier down: `m1 skull dropped`, take it again.
- M2, carrier down: EMP thump + ash, `m2 ember lost (<you> went down), it waits on the table again`, the fire on you
  stops; the flame is back on the right slot, take it again. Lit graves keep their count.
- M2, power ON at the end of a round: EMP thump + ash, Maxis's M2_POWER line, `m2 power ON at end of round: N lit
  stone(s) forget their dead (Maxis wants the dark)`: every lit hungry grave is back to 0/5 (spent graves stay gone);
  nothing left to lose prints `m2 power on at end of round, nothing left to lose`. `!df fire m2_penalty` does it now.
- Step 5, expiry FAILS FORWARD: anchor ONE lamp, then `!df fire s5_time`: EMP thump, `s5 countdown expired: 1 anchor(s)
  kept, 2 lamp(s) pay the penalty`, D5_FAIL, the anchored lamp KEEPS its light and shaft, `s5 penalty: 8 souls each into
  the unanchored lamp(s) <names>`: ONLY those two show the hungry look. Kill within 400 of them: trails, `penalty lamp X
  souls a/8`, at 8 `filled`; `s5 penalty paid`, `s5 tuning open again on the unanchored lamps, countdown starts at the
  next anchor`. `!df fire s5_penalty` or `!df souls` pays it.
- Step 5, no anchor: "signal lost" after 15 s, 10 s drain, nothing else, no countdown.
- Step 6, orb dropped: 60 s then home (nearer of the landing spot / table front, charges kept). After a Step 7 fail its
  home is the table front.
- Step 7, orb destroyed / zone empty: see Step 7 above; hold the table again, no second song.
- Finale, wrong power: RICH deny + line with the power off; MAXIS refuses a round that started with power on.

## 7. Skips and cleanliness
- `!df goto <step>` at any point: the skipped steps leave nothing behind (no lights, sparks, prompts, hums) BUT the boot
  props stay: pipes (dark), table, boxes / graves (the side lock removes the other side's), lamps. No AVAILABLE / DONE
  sounds during the jump, the target step plays its own once it opens. `!df goto step3`: no parts anywhere, relay on the
  roof. `!df goto step2`: coil at DF_COIL_DROP, two parts in the fog, 3 needed.
- `!df goto r1` / `m1` locks the side itself (`side set to rich for r1`, `orb landing spot ...`). `!df goto step5` and
  later with no side: `no side locked, defaulting to rich`; type `!df side maxis` FIRST for a Maxis test.
- `!df goto step5` RICH from round 1: boxes with a steady glow, card glowing on the middle slot, lamps filled (steady
  glow, no sparks), three glows on the post, `act 2 reward given silently (goto)` (no Max Ammo, no line). MAXIS: stone on
  the middle slot, four scorched glows where the graves stood, no ember prompts. `!df goto step7` / `finale`: the stone
  rests on the right slot, tracker runners on.
- Stall hints: leave a step untouched 4 min: `stall hint <KEY> (<step> untouched)` + one line, then at 10 min and every
  6 min; an event hint earlier (`event hint ...`) skips that rung once. `!df texthints off` mutes them (the clock keeps
  running); `!df hints off` (default) only hides puzzle prompts.
- `!df vox <alias>` plays a vanilla patron line (e.g. `vox_maxi_tv_distress_0` 3D at your feet). Silence = unknown alias.
- `!df freeze` while testing a placement: every regular zombie stands inert; toggle again to release them.
- Scavenger: pick up a real jet gun part: it goes to the pool (top-left notice), TAB shows the squares. Any console
  error naming `zm_scavenger` or `epod_key`? The pinned ladder / hatch must still be buildable as vanilla.
- Co-op only, when you have a second player: Richtofen's blue lines that carry team information reach everyone (including
  the finale's wrong-power line and closing lines); the Step 5 "one lamp each" line appears; a downed player is
  teleported into Nacht with the team and can be revived there; Step 7 sprinters rise near a random living player.

## Open verifications (things the code cannot decide alone)
- Step 1 readability: is the far light visible from where the pipes are, can four blinking pipes be told apart, is the
  closing spark a clear "end of message"? Say which fx you settle on (`df_fx_pipe_flash`, `df_fx_signal`, `df_fx_pipe_locator`).
- Beam alias / orientation: `!df fire beam_test` = one light shaft from the table to the nearest lamp for 20 s, console
  `beam test: <alias> from the table to lamp X`. Wrong way round: `set df_beam_flip 1`, fire again. Nothing: `set
  df_beam_fx fx_zmb_tranzit_god_ray_pwr_station` (or `_interior_med`, `mc_towerlight`), fire again. Say which one reads as a beam.
- Stone rest height: the meteor rests 3 above slot 2 / the ground (`!df fire table_demo`, `!df tp DF_ORB_SPOT_n`). Sunk or floating? Say so.
- Fuse box wall offset: the boxes are 6 off the wall at mid height. In the wall, or a visible gap? Say which box (`!df tp DF_FUSE_n`).
- Grave flame: the small flame sits at the base of the lit tombstone (`!df fire m2_light`). Buried or floating? Say so.
- Orb landing spots: is the stone reachable and visible at Town (SPOT_2) and at the power station (SPOT_3)? Off the road?
- Step 7 solo pass rate: at round 10 with a Pack-a-Punched gun, how many tries out of three pass? Paste `s7 wave over ...`.
  Are the after-hold waves (until the song ends) fun or too long?
- Finale queue length: after the burst, world line + keepsake + three closing lines = ~5-6 lines at 6.5 s each (~40 s).
  Too long? Say so.

## What to report
Per step: OK / not OK, the `[DF]` console lines around the problem, and for models the anchor name plus what you see.
For positions: the `[SPOT]` line printed by `!df grab` / `!df move`. For picks: the `[n] name` of the effect / sound
(or the "Copy picks" list from the picker pages) and what it is for.
