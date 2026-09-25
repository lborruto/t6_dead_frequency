# Dead Frequency - owner test guide (current build)

Solo, TranZit Original. Console BEFORE loading the map:

    developer 1
    developer_script 1
    set df_debug 1

Install first: `perl tools/deploy.pl` from the repo (Git Bash). Today the sources pack into TWO files,
`zm_transit_dead_frequency_1.gsc` + `_2.gsc` (see `release/`); both go in the game folder together and nothing
else from the repo. `!df status` prints the version: `DF <version> | side none | players 1 | round 1 | prompts off | texthints on`.

Every `!df` answer and every quest event lands in the console as `[DF] ...`: paste those lines when something is off.
ONE press of F = every pickup and placement (parts, coil, relay, card, battery, spools, the M1 / M2 hand, rock) and every
pipe kick / grave touch / Blackout switch flip.
Holds only: build the relay (3 s, vanilla bar + builder hands), power the relay (1.5 s,
small bar "Powering the relay"), open the frequency (5 s, bar "Opening the frequency"). NO timer on screen anywhere:
every clock is the Pack-a-Punch tick-tock loop on every player plus dry ticks in the last 30 s (every second, doubled
under 10 s). `set df_hud_timers 1` before loading brings the old top-centre timers back for a test.
Two switches: `!df hints on|off` = on-screen PUZZLE prompts (the Simon boxes, Jet Gun hints, "Take the hand before
the cold closes" in the bunker), default OFF; mechanic prompts (take / place / build / hold) always stay. The pipes
never show a prompt, whatever the switch. `!df texthints on|off` = the spoken HINT_1 (4 min) / HINT_2 (10 min, then
every 6 min) ladder and the event hints, default ON; START / FAIL / DONE lines play whatever it says.
Cue grammar, one sound = one meaning: portal-arrive sound + glint on the object = a step is AVAILABLE; piece-add clink =
progress tick; NavCard chime + side flash + a spark runner flying to the tower top = a sub-goal done; the bridge groan
(2D) = STEP DONE (the only step-done sound); NavCard fail buzz = wrong input (only you hear it); bus EMP thump =
something lost / failed; Samantha-steal burst + Avogadro thunder + a short quake = a quest ITEM ARRIVES (coil, key card,
spool, M1 hand, rock: every item comes by that strike). Anything put on the table = the piece-add clink ONLY: the table
under the tower shows NO fx of ours (no Step 4 preview light, no plug spark, no marker glint, no placing snap); the
lasting look is one small glow per finished step climbing the relay mast. `!df cue avail|tick|subgoal|fail|deny|trail|done`
plays each one where you stand.
Side family: everything electric (blue sparks) on Richtofen and before the fork, everything fire / ash on Maxis. On
Maxis NOTHING looks electric: lamps never light the vanilla (electric-arc) exploder and hum with zmb_fire_loop, the
tower top gets a slow fire pulse instead of the lightning orb, no Avogadro thunder crack at the Step 6 strike, the
Step 7 charge strikes or the finale burst.
Useful cheats: `!god`, `!points`, `!ammo`, `!kill`, `!round <n>`, `!gun jetgun_zm`, `!gun turbine_zm`, `!gun
tazer_knuckles_zm`; `!df freeze` (ours: every regular zombie stands inert until toggled back, denizens and Avogadro
untouched, new zombies freeze as they finish rising); `!df jet` / `!df jet watch` (Jet Gun heat values per player).

## 0. Load
- No red error popup. `!df status` -> the version line above, `registered: step1 step2 step3 step4 r1 r2 m1 m2 step5 step6 step7 finale`, `available: step1`.
- `!df fire compat` -> `DF compat: richcompleted 1 maxcompleted 1` (vanilla quest muted). Console at boot: `bus parts
  pinned (n moved): ladder at the Depot, hatch at the Diner`, `Galvaknuckles cost 3000 (was 6000), 1 wall buy(s) patched` and `orb landing spot
  DF_ORB_SPOT_n x y z (drawn once per game)` (the Step 6 spot, fixed for the whole game).
- ~20 s into round 1: MAXIS (orange name, white text) then RICHTOFEN (blue name) bottom centre, a soft tick per line.
  Readable? Cut on the right? A vanilla Maxis voice line plays at the phone when Step 1 opens (console `vox vox_maxi_tv_distress_0 3D`).
- `!df fire perks` -> `finale perks (debug): 5 perks` + one `finale perk X given` line each, five icons. `!df say FIN_RICH_2` (longest line): still readable?
- `!df scale` -> `players 1 | lamp_souls 12 | nodes 3` and `hold_time 75 | orb_hp 3000 | s7_period 1.3 | s7_cap rich 10 maxis 14`.
  A step's quotas are frozen at the player count it opened with.

## 1. What to check at round 1 (touch nothing first)
Everything below must already be there. Missing = the biggest bug of this build.
- Console during round 1: `table spawned at 7771 -448 ...`, `radio at ...`, `mast at ...`, four `screen n at ..., blinks k`
  (the pipes; `step1 order (pipe indexes) ...`), `signal light at ... (fx ...)`, `signal hum (zmb_meteor_loop) at ...`,
  four `m2 brazier_n at ... (ch_tombstone1)` (the graves), `lamp set: skipped diner townbridge ...`, `lamp set (3): <areas>`. Paste them.
- Depot: four PIPES (chimney pipe, 9 tall) on the ground around the depot (`!df tp DF_TV_1..4`), each blinking its own
  number (short flashes, a dark gap, ONE blue spark in the gap), no steady glow. Past the fence (`!df tp DF_SIGNAL`, the
  light 70 above the anchor) a light flashes the order in silent GROUPS (no click) with the same blue spark closing the
  message; a hum at `DF_SIGNAL_SND`. Is the far light visible from the Depot? Can you count four blinking pipes?
  Say so. The wall phone: no glint, no prompt, nothing on press.
- Fog: `!df tp DF_PART_A` radio (Diner garage, behind the box), `DF_PART_B` mast (Farm barn upper floor, a 117-tall post
  standing). Glint on each. There is no DF_PART_C any more (the third part is the wire coil, which arrives after Step 1).
  Take one part now: notice "Relay parts (1/3)", console `radio taken (1/3)`. It must count later.
- Tower: `!df tp DF_TABLE`: the work bench stands there, empty. Walk into it: you must NOT pass through, and you must
  NOT be able to jump onto it (two rows of clips, a 64-tall wall). `!df move DF_TABLE 20 0 0` moves the real table
  (`table follows DF_TABLE to ...`); move it back or restart.
- Barn: `!df tp DF_FUSE_1..4`: four small power boxes (13 x 20, centre at mid height) on the walls, back against
  the wall, lever side towards the room, NO glow yet (owner 2026-09-25: the boxes stand from boot on both sides;
  only a side lock gives them a look). Press F on one: nothing.
- Town: `!df tp DF_BRAZIER_1..4`: four TOMBSTONES spread over Town (owner spots 2026-09-23), standing on the ground,
  NO flame yet (owner 2026-09-25: the graves stand from boot on both sides; the small flame belongs to the Maxis
  side only, once locked). Walk into one: you must not pass through, and you must not be able to stand on it (two
  clip blocks, 64 tall).
- Tower: `!df tp DF_BLACKOUT_1..3`: three power switches stand near the table under the tower, lever ON, on BOTH
  sides from boot (console `DF: blackout 3 power switch(es) standing ON`). Press F: nothing yet (Richtofen's
  M3 / R3 arms them).
- Lamps: walk to one lamp of the printed set: one small electric spark at the bulb every 6 s, no colour, not green.
  `!df fire lamps` lists 3 lamps `set 1 state off`. None of them is diner or townbridge; one is the lamp nearest the tower.
- Bus parts: the ladder lies at the Depot (-7313 5441), the hatch at the Diner (-3537 -7214). `!df fire busparts`
  re-runs the pin and prints the pools.
- Not there yet, correct: coil, key card, rock, battery on the bus, spools, the M1 hand.

## 2. Models, effects, sounds (once)
    !df show
    !df tp DF_TABLE       work bench under the tower, front towards you; `!df fire table_demo` puts radio + coil box +
                          tall post on slot 0, card on slot 1, the rock on slot 2 (`!df hide` removes them)
    !df tp DF_TV_1        chimney pipe (pb_pole_telephone_bulb, 9 tall) on the ground (also TV_2..4)
    !df tp DF_SIGNAL      the far light spot (light 70 above); DF_SIGNAL_SND the hum spot
    !df tp DF_COIL_DROP   where the coil lands after Step 1 (-6311 5019 -46): preview of the wire coil
                          (p6_zm_buildable_jetgun_wires, slightly tilted)
    !df tp DF_FUSE_1      power box on the barn wall (also FUSE_2..4); IN the wall or floating? say which
    !df tp DF_BRAZIER_1   tombstone on the ground (also 2..4); sunk? floating?
    !df tp DF_CARD_SPAWN  key card preview upright on the barn wall, clear of panel 4
    !df tp DF_PORTAL      the M1 hole spot in front of the table (7623 -457 -207)
    !df tp DF_NACHT_SPAWN_1  a denizen spawn in the woods behind the cabin (also 2..4: 13673 -337, 13861 -327, 13643 -541, 13886 -522)
    !df tp DF_ORB_SPOT_1  the diner landing spot (-5991 -7686 34); SPOT_2 Town (900 130 -39); SPOT_3 power station
                          (11720 8491 -575): the rock preview on the ground at each, off the road?
    !df dump              one [SPOT] line per anchor + [MODEL] lines
Report: invisible / black / sideways / wrong size, with the anchor name. Fix live: `!df grab DF_ORB_SPOT_2` (fire =
place, melee = cancel), paste the printed line; a live tune of a DF_ORB_SPOT_n makes it this game's landing spot
(`orb landing spot now DF_ORB_SPOT_n (edited)`). `!df hide` when done. The M1 item is a plain HAND (kind `skull` in the
code, `p6_zm_buildable_pswitch_hand`, the same model and table pose as the M2 fire hand, kind `ember`); the Step 6 rock
is the meteor piece (`p6_zm_buildable_sq_meteor`).
Picking by ear and eye: the picker pages (Sound, Prop, Effect; self-contained HTML built by the generators in `tools/pickers`)
list the same sets as `!df snd list` / `!df fx list`. In game: `!df snd <n>` / `!df snd next` plays a sound to you at
full volume and prints its name; `!df fx <n>` / `!df fx next` plays an effect 8 s where you aim (`[FX n/150] name`);
`!df fx grid` puts a whole page of effects on pedestals in front of you (`gridnext` / `gridprev` / `gridbig` for the
huge ones / `gridoff`), walk to a pedestal and the bottom label reads `[n] name`. Paste the numbers or names you want,
and for what (pipe flash, signal light, lamp hungry / full / dark, grave flame, step glow, rock aura, ...).

## 3. Act 1 (shared)
**Step 1 Dead Air** (depot, no power). Skip: `!df fire a1_solve1` or `!df goto step2` (the coil arrives in both cases).
- Count the far light's groups ("3, pause, 1, pause, 4, pause, 2"), then KICK the pipes whose blink count matches, in
  that order (one press each; NO prompt, even with `!df hints on`): a spark on the pipe, it stops blinking and its light
  stays on. Holding F must not repeat. Console `screen n used, expected screen m, progress k`.
- Wrong pipe: the deny buzz (you only), all pipes blink again, console `wrong pipe, all pipes back to blinking (the
  signal keeps flashing the order)`. Same order. `!df fire a1_tv` kicks the next expected pipe.
- All four: `step1 solved, all four screens on`, bus dashboard pulse 5 s (NO horn), D1 lines, the step-done groan,
  `step complete step1`. Then the STRIKE at DF_COIL_DROP (burst, thunder, quake) and a glinting wire coil on the
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
  burst on the relay every 1.5 s (no big spark cloud over the bus), and `roof waves on: two zombies every 1.5 s ahead
  of the bus, cap 8, until the relay locks or the sweep ends` (cap +3 per extra player): zombies keep rising along the
  road and climbing on.
- Roof zombies swing: sparks, `relay hit, hp 740` (60 a hit). `!df fire a1_hit` (200) x2: `relay damaged, hp 400,
  second burst layer on`; x3: `relay low, hp 200, warning horn`.
- Arrival: leave horn, blue burst, 8 s of tower lightning, `stop 1/1 counted at <stop>`, then `relay locked, take it to
  the tower` + the dashboard power pulse replaying on the relay, `roof waves off`, D3 lines, `step complete step3`. ONE stop only.
- Power OFF while the bus rides (`!df power off` mid-trip): at the stop `the bus reached the stop without power: not
  counted`, EMP thump, D3_FAIL, relay kept.
- Wrong: paste every `sweep ...` / `bus left ...` / `roof waves ...` line.

**Step 4 Plug In**. Skip: `!df goto r1` (rich) or `!df goto m1` (maxis; the goto locks the side itself).
- One press within 120 takes the relay (`relay picked up by`, sparks on your back); the first lift of the game plays
  S4_CHOOSE ("Choose now..." / "Lights ON when you plug it..."). Portal at a lamp: deny buzz, refused.
- Carry it into the cornfield: Maxis's vanilla "Spire" voice once (`locked relay entered the cornfield`).
- Walk towards the table with power ON: NO light on the table (and no marker glint), only the console `table preview
  rich` from ~400 units. Walk away: `table preview off (no carrier within 400)`. `!df power off`, come back: `table
  preview maxis`, still nothing on the table.
- One press within 150: clink + switch-on sound, NO spark or snap on the table, the relay
  stands on the LEFT slot, turned 45 degrees, with the coil box and the TALL post on it (`plugged relay at ..., top piece
  relay_mast`), no table light at any time, tower visuals 15 s, one vanilla voice line, D4 line,
  `relay plugged by <you>, power 1, side rich`. A white runner starts climbing a tower leg every ~5 s and stays for the
  game. Four small step glows appear on the relay mast, bottom up (steps 1-4; default fx_zmb_tranzit_key_glint, `set df_step_glow_fx <fx>` swaps the glow).
- Side lock: `DF: side locked rich` (power ON) or `DF: side locked maxis` (power OFF). Boxes and graves are NEVER
  removed any more (owner 2026-09-25): power ON -> rich turns on the boxes' faint boot glow (no console line for
  it) and prints `DF: Richtofen side locked, the four graves stay dark` (check Town: four cold tombstones, still
  standing, no flame); power OFF -> maxis prints `DF: Maxis side locked, the four boxes stay dark` (check the
  barn: four boxes, still standing, no glow) and `DF: Maxis side locked, the four graves show their flame` (check
  Town: four graves, each flaming). The three DF_BLACKOUT switches keep standing ON, unaffected, on either side.
  Both locks also print `orb spawn for side X: x y z` (the spot drawn at boot, not a new draw). `!df status` shows
  the side. The lock is FINAL: `!df side maxis` now answers `side rich is already locked, it cannot change in
  this game (start a fresh game to test maxis)`.
- Persistence (owner, `say` in the in-game chat with `df_debug 1`): fresh game `say !df side maxis` -> graves
  flame, barn boxes present and dark. Fresh game `say !df side rich` -> boxes glow, graves present, no flame.
  `say !df goto step7` on Maxis -> all four graves still standing.
- Co-op: the carrier leaves the game with the relay: `relay carrier left the game, relay dropped`, then after 60 s
  untouched `orphan relay untouched for 60 s, returned to the table`.

## 4R. Richtofen side (power ON): `!df goto r1` in a fresh game if needed
**R1 Summon the Storm** (barn). Skips: `!df simon` (solves it), `!df fire r1_captured` (skips the fight).
- R1 opens: a spark runner flies from the table to the barn, the four boxes brighten, the AVAILABLE glint sits on
  box 1's LED (nothing floats at the barn centre; "Press F" at a panel only with hints on).
- Simon: one blue one-shot spark per box, `simon k/6 boxes: ...` matches what you see. Correct = click. Press a WRONG box
  on purpose at length 3: deny buzz + EMP thump at the box, console `simon wrong at k, replay`, the SAME three sparks
  replay. 20 s without a press: `simon abandoned (no input)`, press again to restart.
- Solved: three rising clinks, all boxes spark, then the STRIKE on the barn wall at DF_CARD_SPAWN (burst, thunder,
  quake) and the NavCard chime + a runner to the tower: `key card at ...`. The card must be VISIBLE. One press takes it
  (`key card taken`), one press at the table inserts it (sub-goal chime, `key card inserted`, `key card on the table,
  slot 1`: middle slot, lying flat, NO glint or glow on it).
- Case A (nobody stood at the power core yet): NO clock, Richtofen's chamber line, console `avogadro state chamber`. Look
  at the core in the power room: `avogadro released`, called down and `avogadro warped to the tower`.
- Case B (he roams or sits in the cloud): storm over the tower, `avogadro called down`, warped to the tower at once.
- Case C (no Avogadro entity at all): R1_RICH_NOSTORM ("Nothing came, Samuel..."), `no avogadro entity to summon, r1
  counts as captured`, R1 completes without a fight.
- While he is alive within 900 of the tower there is no table fx, only the no-fail rule. The last 30 s of the
  240 s clock tick once a second; stay near him past it: NO fail while he is within 900.
- Knife him 3 times (vanilla's defeat): `avogadro captured at the tower`, soul trails from the table into the 4 boxes, a
  blue burst on each, `step complete r1`, the fifth step glow on the relay. Maxis's vanilla stab line once.
- Wrong: paste `simon ...`, `avogadro ...` lines.

**R2 115 on the Line**. Skips: `!df fire r2_soul` (one kill), `r2_punch` (every full lamp frees its spool), `r2_spool` (one spool counted), `!df souls` (all).
- Console `r2 3 lamps, 12 souls each`, then per lamp `r2 lamp X: N spawn structs for its waves`. At a set lamp: the
  side colour IN the bulb, a hum, a spark every 2 s (HUNGRY), a light shaft from the tower and a light column at the
  base. NOT green.
- Stand within 450 of a hungry lamp: every 3 s two zombies rise nearby (`r2 two zombies pulled to lamp X (<you> under
  it)`) while fewer than 12 zombies are within 1200 of you. Kill within 450 of the post: `lamp X souls a/12` every 5, a
  trail into the bulb and a clink for EVERY kill (every trail must be visible, no streak). A miss says `kill not
  absorbed: NNN from lamp X (need 450, ...)`.
- At 12: `lamp X filled`, NavCard chime + blue flash + runner to the tower, beam off, the sparks STOP and the bulb keeps
  a steady glow (no electric arcs), Richtofen: "punch the post". Console `lamp X full: punch the post with the knuckles
  to get the spool (!df fire r2_punch drops every ready spool)`.
- Buy the Galvaknuckles (Diner roof, through the hatch, 3000). Melee the post within 90: a spark on the post, `r2 lamp X
  punched by <you>, the spool is out`, the STRIKE at the lamp's foot and a glinting WIRE SPOOL on the ground (`spool at
  lamp X`). Richtofen names the first spool. Knife the post instead (or any gun melee): deny buzz + "Bare steel? No."
  (once per 20 s), console `r2 <you> hit lamp X without the knuckles (<weapon>)`, no spool.
- "Press F to take the spool" (`spool taken (1 in hand, 0 placed)`); spools STACK, carry all three; at the table "Press F
  to place the spools": clink + spark at the relay slot, `3 spool(s) placed, 3/3`, `r2 antenna array 3/3` (NO glows on
  the mast for the spools), `step complete r2`, R2_DONE, the sixth step glow on the relay, M3 / R3 opens. Every lamp of
  the set ends filled with its beam off. Nobody holding a Jet Gun: A2_JETGUN_RICH ("Before the end you will need a Jet Gun").
- Act 2 reward at once: `act 2 reward given (rich): side reward + Max Ammo at the table`, Richtofen's reward line, blue
  runners start climbing the tower next to the white one. Place a turret (`!gun turret_zm`) with no turbine: it fires.
- Side rules: hold the Jet Gun until the heat passes 50: the needle stalls. Power OFF and end a round: `power off: lamp X
  -5, n` + R2_POWER_RICH ("Lights out, Samuel!"); a filled lamp whose spool is still in the post reopens (hungry again),
  one whose spool is out never does. Avogadro comes back EVERY round (`avogadro returns next round`), except while
  Step 6 is open.

## 4M. Maxis side (power OFF): `!df goto m1` in a fresh game (the goto locks the side)
**M1 The Cold Room**. Skips: `!df fire m1_ride` (ride cue), `m1_latch`, `m1_kills`, `m1_skull` (the hand in front of you; fire again = on the table).
- `!df goto m1`: console `m1 waiting for a denizen latched within 300 of the table`. The tower keeps its vanilla
  safety box: no denizen rises or latches at the tower; get one on your head in the fog and walk it in.
- Let a denizen jump on you anywhere: the portal-open sound, Maxis's M1_EVENT line, console `m1 first ride:
  table cue + event line`. No light. Only the first time.
- Walk to the table with it: it dies in ash, `m1 denizen latched at the table`, `m1 portal at 7623 -457 ...`: the hole
  rises out of the ground in front of the table and spins with an orbiting orange light; the glint moves onto it.
- Walk INTO the hole (no F): warp sound, black flash, Nacht. `m1 cold room 60 s, 6 denizen kills`, cold fog, the
  tick-tock (no timer). Denizens rise two at a time at the FARTHEST of three Nacht spots (DF_NACHT_SPAWN_1..3) from every
  player, never the same one twice in a row (`m1 denizen rising at x y`: the coordinates must change); each kill =
  red trail + 5 s of rising embers + `m1 denizen kill k/6`. The hand floats 14 above the floor, turning, with a tiny glow.
- Success: `m1 cold room over: success (6/6)`, the STRIKE where the last one died and the HAND (the power switch hand,
  `p6_zm_buildable_pswitch_hand`; code kind `skull`, so the console still says skull) lies there with a glint (`m1
  skull on the floor at ..., one press takes it`), Maxis (ITEM_HAND_MAXIS): "The cold left a hand behind. The
  hand of his switch. Set it on the table."; 30 s
  window, "Press F to take the hand" within 100 ("Take the hand before the cold closes" for the room only with hints
  on). Then everyone is sent back (`m1 1 player(s) returned to the tower`). Nobody took it: `m1
  skull not taken in 30 s, it comes along to the tower`, it lies at the tower return point with its glint, NEVER
  placed by itself.
- Carry it (notice "Hand" with the rock icon, TAB square, no lamp portals, drops at your feet if you go
  down: `m1 hand dropped (<you> went down), take it again`). "Press F to place the hand" within 150 of the table:
  the clink only (no snap), `m1 hand placed by <you>`, `m1 hand on the table, slot 1 (...)` (it lies at the fire hand's
  pose, exactly where M2's fire hand will rest; no spin, no glow, no flame), tower cue 12 s (the slow fire pulse at the
  top, no lightning), M1_DONE ("...The hand still wants fire."), `step complete m1`.
- After M1: `m1 side rules on: denizens avoid the graves (M2) and the cabin fireplace (Step 6) within 400, fog spawns doubled` (the tower safety
  volume comes back as well). Stand at the table with a denizen on your
  head: say whether it jumps off.
- Timeout: `m1 cold room over: timeout`, back at the tower with an ash burst + EMP thump, Maxis's fail line, `m1 failed
  (timeout), back to the latch`.

**M2 Fire and Ash**. Skips: `!df fire m2_ember` (you hold it), `m2_light` (next grave lit), `m2_fill` (all four spent, fire hand returned), `!df souls` (same), `m2_column` (smoke replay), `m2_penalty`.
- M2 opens: M2_START ("The hand on the table wants fire..."), `m2 the hand is on the table (charged 0)` and `m2 the
  fire hand burns on the table: take it (one press), touch any tombstone with it, 5 zombies killed at a lit one make it
  vanish; all four gone = bring the charged fire hand back to the table`. The M1 hand is swapped for M2's at the SAME
  pose (never two hands on the table): a plain hand, NO flame yet, with the glint.
- "Press F to take the hand" within 100 of the table: pickup sound + a short fire-loop puff, notice "Hand" (rock icon),
  NO fire on your body and NO damage while it is uncharged, `m2 fire hand taken from the table by <you> (5 hp/s while
  carried; it stays in hand for the whole step)` (the console text is older than the rule: no burn yet), Maxis names it
  once (ITEM_EMBER_MAXIS "Take the hand to the graves in Town..."). Lamp portal: deny, refused.
- Within 100 of an unlit grave: "Press F to light the hand". One press: fire whoosh, the grave starts to CRACKLE (its
  small flame stays), a clink, the hand STAYS in your hand: `m2 brazier_n lit by <you> (1/4 lit, 3 to go, you keep
  the fire hand)`. Any order, any number lit at once. Console `m2 brazier_n: N spawn structs for its waves`.
- A lit grave starts its wave (`m2 wave ON at brazier_n`): two sprinting zombies every 2 s from the Town spawn structs
  within 1200 (N above must not be 0), up to 8 per grave (+3 per extra player). Kill one within 250 of that grave,
  burning or not, any gun: EVERY counted kill = a fire burst at the body with the swipe sound there, a fire trail into
  the grave, then the clink at the grave (two different sounds; paste it if one is missing on quick kills), `m2
  brazier_n 1/5`. A kill at an unlit grave does not count (deny buzz to the killer, console silent); a Galvaknuckle kill
  at a lit grave does not count either (deny buzz). At 5: `m2 brazier_n spent (the grave stays, its flame is out)
  (k/4)`: a small burst, the tombstone STAYS standing with its clips, its flame goes out, and a scorched lava
  glow marks the spot.
- Cold timer: a lit grave not filled within 90 s (`set df_m2_grave_time <s>` before loading) goes cold: the tick-tock
  runs for the grave that cools first (dry ticks in its last 30 s), then EMP thump at the grave, M2_GRAVE_COLD, `m2
  brazier_n went cold (not filled within 90 s): light it again and fill it from 0`, the crackle stops, `m2 wave OFF at
  brazier_n`.
- All four gone: NavCard chime + fire flash + a runner from YOU to the tower, it is now the FIRE HAND: a real flame on
  your body (fx_zmb_tranzit_fire_med) and 5 hp/s burn (never below half health, and not within 300 of a lit grave),
  M2_EMBER_CHARGED ("...Their fire lives in the hand now. Set it on the table."), `m2 all four graves spent, the fire
  hand is charged: return it to the table (one press within 150)`. At the table "Press F to set the fire hand on the
  table": the clink only (no snap), it rests on the table BURNING until Step 6 bursts it (no prompt; the hand's flame is
  `dog_trail_fire`, `set df_m2_hand_fx <fx>` swaps it), `m2 the hand is on the table (charged 1)`, `m2 the charged fire
  hand is back in the table`, `step complete m2`, tower cue 12 s (fire pulse at the top, no lightning), `m2 smoke column at
  the tower top for 20 s`, M2_DONE, act 2 reward at once (`act 2 reward given (maxis)`, Max Ammo, Maxis line, orange
  runners on the tower). Nobody holding a Jet Gun: A2_JETGUN_MAXIS ("Before the end you will need a Jet Gun").
  `m2 done: Step 6 node = the cabin hearth at 5430 6874 -24 (one draw: fire until the Jet Gun overheats)`. `!df fire
  lamps`: `silent 1` on all 8 lamps; a denizen dropping at any lamp opens a portal, no turbine.
- Galvaknuckles (`!gun tazer_knuckles_zm`) melee within 100 of a grave, or anywhere with the hand in hand (charged or not): deny buzz +
  "His current will not touch my graves...", console `m2 <you> used the knuckles at the graves: refused`.
- Denizens leave you alone within 400 of ANY of the four graves (lit or not) while M2 runs.
- Wrong: paste the `m2 brazier_n ...` lines, the `spawn structs` count, and what killed the zombie.

## 5. Act 3 (shared; what differs per side is marked)
**M3 / R3 Lights Out (Maxis)**. Skips: `!df fire s5_dark` (every lamp dark at once, completes the step), `s5_relight` (every lamp humming again), `!df goto step6`.
- S5 START waits until the end-of-Act-2 lines are over (at most 90 s). Console `DF: s5 lights out: 3 lamps hum with
  his power, a claymore kill within 150 puts one out, 3 dark to win` (also with 4 set lamps in a full lobby, need
  4; fewer only if the set itself is smaller). Every set lamp is state "filled": a steady bulb glow, no sparks, no
  hold prompt anywhere - nothing to press.
- Buy a CLAYMORE at the Farm wall buy (`claymore_zm`, 8827 -5838) and plant one at the foot of a humming lamp
  (within 150 of its base). Let a zombie walk into it: `DF: s5 lamp X put out by a claymore (1/3 dark)`, the fire
  burst + rising ash at the bulb + a tick clink (progress cue), the lamp goes state "dark" (the vanilla light off,
  nothing of ours - no glow, no hum), LO_DARK_MAXIS ("One lamp is dark. His voice is thinner already.") unless
  that kill is the winning one.
- Kill a zombie within 150 of a humming lamp WITHOUT a claymore (gun, melee, anything): the lamp does not change,
  console silent, LO_NOTHAND_MAXIS ("Not your hand. His light must fall at the step of the dead. A claymore.")
  plays once for the whole game - kill a few more that way and it does not repeat.
- End a round (`!round <n>`) with at least one lamp still dark and at least one still humming: `DF: s5 Richtofen
  relit lamp X at the end of the round`, the `zmb_turn_on` sound, LO_RELIGHT ("He has relit one of them. Put it
  out again."), one random dark lamp goes back to "filled". With zero dark, or all of them dark, end of round does
  nothing.
- Put out THREE lamps at once (every lamp if the set is smaller): `DF: s5 3 lamps dark, step done`, D5_DONE
  ("Three lamps dark. His voice is gone. Something small must carry the charge."), `step complete step5`.
- No countdown, no soul penalty, nothing lost by taking your time: only the claymore mechanic and the end-of-round
  relight move the count.
- `!df fire s5_dark` / `s5_relight`: `DF: s5 debug: every lamp df_debug_s5_dark` / `df_debug_s5_relight` (the
  console line names the raw hook, not dark/lit, on purpose); every lamp jumps to that state at once (`s5_dark`
  also completes the step if it is open). `!df goto step6`: every set lamp stands dark, nothing running,
  `DF: s5 setup: 3 lamps dark`.
- Wrong: paste every `DF: s5 ...` line and which lamp.

**M3 / R3 Blackout (Richtofen)**. Skips: `!df fire blackout_off` (all three switches OFF, a running step keeps
going), `!df fire blackout_on` (all three ON, completes the step if it is open), `!df goto step6`.
- The three DF_BLACKOUT switches stand ON from boot on both sides (console `DF: blackout 3 power switch(es)
  standing ON`); Maxis's side never touches them.
- S5 opens (after the end-of-Act-2 lines, at most 90 s): `DF: blackout Maxis cut the grid: 3 switch(es) OFF, one
  press each turns it ON` - all three levers roll OFF at once (flip sound + a short blue spark at each).
- Within 80 of a dark switch: "Press [{+activate}] to turn the power switch ON". One press (no hold): the lever
  rolls ON (flip sound, then `zmb_turn_on`, a progress clink), `DF: blackout switch N ON by <you> (a/3)`, and a
  20 s wave of sprinting zombies rises at that switch (2 every 2 s, cap 8 + 3 per extra player).
- Press an OFF switch while the map's main power is OFF: deny buzz, BO_NOPOWER_RICH ("Power ON first, Samuel! A
  switch on a dead grid is a toy."), said at most once every 10 s even if you hold the key.
- End of a round with at least one switch still OFF: `DF: blackout Maxis knocked switch N OFF at the end of the
  round`, BO_OFF_MAXIS ("Another of his switches falls. The dark is patient.") - Maxis always knocks an ON switch,
  never one already dark.
- All three ON at once: sub-goal cue, `DF: blackout all switches ON`, D5_DONE_RICH ("All three ON! The obelisk
  drinks, Samuel. Now my card wants to let go!"), `step complete step5`.
- `!df fire blackout_off` / `blackout_on`: `DF: blackout debug: every switch df_debug_blackout_off` /
  `df_debug_blackout_on` (the console line names the raw hook, not ON/OFF, on purpose). `!df goto step6`: all
  three switches stand ON, nothing running, no console line.
- No scaling: three switches whatever the lobby size.
- Wrong: paste every `DF: blackout ...` line and which switch.

**Step 6 Vacuum**. Skips: `!df fire s6_orb` (rock to your feet), `s6_draw` (one charge), `s6_deliver` (finish), `s6_restart`, `orb_aura` (next aura), `!df goto step7`.
- Step opens at the table: RICH the key card discharges (blue spark + arc crack, a blue runner to the landing spot,
  S6_CARD_RICH, `s6 the key card discharged on the table, its charge flew to the landing spot`; the card stays); MAXIS
  the fire hand bursts and is gone (fire burst, its fire flies to the landing spot, S6_EMBER_MAXIS, `s6 the fire hand
  burst on the table, its fire flew to the landing spot`). Then `s6 build-up over the tower, the orb arrives in 3 s`
  (RICH storm cloud + rumble / MAXIS smoke column), a bolt + thunder (RICH) or a fire burst + ignite, NO thunder crack (MAXIS) at the
  spot, `s6 strike at DF_ORB_SPAWN`, and the ROCK lies on the ground there, glint + light shaft on it. The spot is the
  one drawn at boot (`orb landing spot DF_ORB_SPOT_n ...`): the diner, Town or the power station, on EITHER side
  (`!df tp DF_ORB_SPOT_1..3`). The M3 / R3 lamps go dark. Console lists ONE node: RICH `s6 node 0 core core` (the
  sparking block on the power station bridge), MAXIS `s6 node 0 hearth cabin hearth` (the fireplace of the hunter's
  cabin in the woods, `!df tp DF_CABIN_HEARTH`): shaft + column + hum on it (RICH the Avogadro hum, MAXIS a fire
  crackle), MAXIS also a small glow in the fireplace opening.
- Leave the rock untouched 3 min: `s6 rock untouched 180 s at its landing spot, flew to the table front (...)`, a trail
  flies there and the glint follows.
- "Press F to take the rock" within 100 (`s6 orb picked up by <you> (0/1 charges)`, notice "Rock 0/1", TAB square). No
  lamp portals while carrying. With no Jet Gun in any inventory: the side's "build a Jet Gun" line once (RICH "No
  engine? Build one...", MAXIS "The rock needs a Jet Gun"); otherwise D6_HINT once per game.
- BOTH SIDES, the same draw: `!gun jetgun_zm` (the upgraded Jet Gun works too), carry the rock to the node, fire at it
  within 350 looking at it (cone 55 degrees on the aim point): a rising power sound (no bar), `s6 drawing node 0`, side
  bursts at the node. Keep firing until the gun OVERHEATS while still aimed: `s6 jet gun overheated at the node: the
  charge is drawn`, NavCard chime + flash + runner to the tower + trail into you, `s6 charge 1/1 in the orb (node 0 ...)`.
  Overheat while looking away: `overheated away from the node: nothing drawn`, try again. A plain weapon swap mid-draw
  draws nothing (`s6 heat watch ended on weapon_change`, or `s6 jet gun gone without an overheat signal: nothing drawn`).
  Refused: `jet gun firing but no charged node within 350` / `firing near node 0, aim NN/100 (need 57)` / `firing near
  node 0 without the orb in hand (orb: <state, distance, position>)`. Walking past the node with another gun: silent.
- MAXIS aim check at the fireplace: crouched at 5394 6872 looking straight in, standing at the same spot, and standing
  a metre back (5357 6872) must all draw. Wrong: paste the `aim NN/100` line and your `!pos`. Denizens leave you alone
  within 400 of the fireplace while Step 6 is open. RICH: Avogadro stays in his cloud while Step 6 is open.
- All charges: three clinks, `s6 orb fully charged, bring it to the tower socket`, D6_FULL_RICH / D6_FULL_MAXIS, aura +
  hum on the rock and on you (RICH avogadro_health_full, MAXIS powerup_on_caution; `!df fire orb_aura` cycles). At the
  table with charges missing: "The rock needs N more charge(s)". Full, one press within 150: "Press F to place the rock
  in the relay", the clink only (no snap on the table), the rock rests on the RIGHT slot with NO aura, the "Rock" notice is
  cleared, D6_DONE, `step complete step6`, the eighth step glow on the relay.
- `!df goto step6` MAXIS (after `!df side maxis`): console `m2 done: Step 6 node = the cabin hearth ...` and `s6 node 0
  hearth cabin hearth`; RICH `r1 done: Step 6 node = the transformer block ...`.
- Drop test: go down while carrying: `s6 orb dropped at ..., 60 s to pick it up`; wait: `s6 orb returned home (...)` =
  the NEARER of the landing spot and the table front, charges kept.

**Step 7 The Line Holds**. Skips: `!df fire s7_start`, `s7_time` (win now), `s7_fail`, `s7_hp` (print hp), `s7_dmg` (100 dmg), `s7_strike`.
- At the table: `s7 socket armed (hold 75 s, orb 3000 hp, period 1.3 s, cap 10 | 14, 1 player(s))` (the "hold" there is
  the wave length), glint over the right slot, "Hold F to power the relay". Hold 1.5 s (bar "Powering the relay"): the rock leaves the slot and wanders under the
  tower HOVERING 40 UP with its aura and hum (RICH the Avogadro hum, MAXIS a fire crackle; easy to see from the road?),
  switch-on + power-down sounds, D7_START, `s7 wave started, 75 s, orb 3000 hp, side X, guard bonus within 200`, the
  song starts (`s7 song started`), the tick-tock rides you. `s7 N spawn structs near the tower`, `s7 spawner on: every
  1.3 s, cap 10 (1 player(s) at wave start)`.
- RICH: `s7 Richtofen pressure: Avogadro from the start`, storm at the tower top, Richtofen's Avogadro line once, his
  vanilla "lure them" line once. He lands: `s7 avogadro landed wounded (1 hit seeded, 3 knife hits banish him)`. Knife
  him 3 times: `s7 avogadro banished by knife, Max Ammo at the table`, chime, Max Ammo in front of the table, storm off.
- MAXIS: `s7 Maxis pressure: the fast zombies only (no denizens)`, NO S7_DENIZEN_MAXIS line, no `s7 denizens released`,
  no denizen at the tower during the wave; a smoke column at the tower top for the whole wave.
- Sprinters rise AROUND THE TOWER (spawn structs within 1400 of it) and run to the rock: sparks (MAXIS a lava fire flicker) + `s7 orb hit by
  zombie, hp 2970` (30). Stand within 200 of the rock: `hit by zombie (guarded), hp ...` (15). Every 10-20 s `s7 charge
  strike n healed the orb +300 (guarded 0)` (+450 when guarded): 2 s of denser bursts, then RICH bolt + lightning orb +
  thunder / MAXIS fire burst + ash, NO thunder crack.
- Zone: leave the 700 zone 4 s, come back 6 s, leave 4 s, come back: no fail, console `s7 zone held 5 s, absence counter
  reset`. Leave 11 s straight: fail (`zone abandoned`). At 5 s away: horn + D7_ZONE_RICH / D7_ZONE_MAXIS (at most once
  per 30 s), `zone empty for 5 s cumulative`. Go down INSIDE the zone (solo, `!god` off): the zone still counts as held.
- `!df fire s7_dmg` until hp is under 900: `s7 orb damaged (...): warning beeps on`, faster bursts, a beep every 2 s.
  Keep firing to 0: `s7 orb destroyed`, `s7 wave over: fail_orb`, side flashes + EMP sound, D7_FAIL, `s6 restart:
  charged orb (1/1) waiting in front of the table`. One press takes it, one press places it (`s7 orb redelivered, the
  table is armed again`), hold again. Song must NOT play twice within its own length (256.5 s): `s7 song still running
  from the last attempt, not restarted`. Never two rocks at once.
- Survive (or `!df fire s7_time`): `s7 wave over: success`, tower lights, the rock glides back onto the right slot in 2 s
  with the rising sound, `s7 orb back on the table, slot 2`, D7_DONE, `step complete step7`, the ninth step glow (the
  relay mast is fully lit), one more white and one more side runner on the tower.
- AFTER the hold the song keeps playing (256 s from its start, it cannot be stopped): `s7 after the hold: waves near the
  players until the song ends in N s`. Walk anywhere: zombies keep rising near you (every 1.3 s, up to the cap around
  you) and hunt you normally, no rock to defend. When the song ends: `s7 after-hold waves over (song ended, or a new
  wave)`. The finale can be started meanwhile. `!df goto finale` DURING the wave: no after-hold waves start at all.
- Wrong: paste `s7 wave over ...`, the last `s7 orb hit ...` and `s7 charge strike ...` lines.

**Finale**. Skips: `!df fire finale` (full run), `finale_nostat` (no globe stat), `finale_fx` (~15 s show, stand-in rock, repeatable), `finale_world` (world change alone), `a2_reward`.
- `finale waiting at the table (side X)`, NO marker glint on the table (the prompt leads), "Hold F to open the frequency". Power gate: RICH power ON;
  MAXIS power OFF now, OR the round STARTED with the power off (turn it ON mid-round, the hold is still accepted). Wrong:
  deny buzz while you hold, the patron complains once per 20 s, `finale refused, wrong power state for side X`.
- Hold 5 s (bar "Opening the frequency"): `finale start, side X, nostat 0`. Order: all perks (one console line each),
  `finale build-up (6 s, X)` (RICH: electric hum, blue sparks and arcs over the table; MAXIS: fire crackle, fire pulses,
  ash column at the base, smoke column at the top; both shake), `finale orb rising to the tower top (6 s, stand-in 0)`:
  the rock lifts off the right slot with the reactor hum, `finale burst, tower fx on`, RICH lightning at the top + Avogadro
  thunder / MAXIS the slow fire pulse at the top, no lightning, no thunder crack; side flash, 3 s shake, one vanilla
  voice line, `s6 orb consumed by the finale`. Then EVERY fog lamp of the map is in the
  side colour (`lamps: all 8 lamps coloured ...`; MAXIS: the lava glow in the bulb, never the vanilla exploder with its
  electric arcs): check the depot lamp and the town lamp, far from the tower. Console
  `finale world change done (X)`, the patron's world line, the keepsake line (RICH the card left on the table; MAXIS
  "The hand burnt away for this...", the hand is gone since Step 6) (`finale keepsake on slot 1`), sting, Max Ammo (`finale power-up dropped`), `side reward already given (Act 2), not
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
  Co-op: the "take" prompt of a part goes from EVERY screen once somebody takes it (and on a goto past Step 3).
- Step 3, EMP near the bus during the ride: `EMP near the bus, sweep lost`, the relay stays. Power OFF: `bus left <stop>
  without power, no sweep`, or at the stop `the bus reached the stop without power: not counted`. Empty bus 6 s:
  `nobody on the bus for 6 s, sweep lost`.
- R1, capture fail: kill him far from the tower, or walk him away after 240 s: `avogadro not captured`, EMP thump at the
  table, Richtofen's fail line, the key card LEAVES the table, `r1 locked, one battery from the bus charges the four
  boxes`, the boxes go dark. ONE glinting BATTERY on the bus dashboard (`battery on the bus`), Richtofen names it.
  "Press F to take the battery" within 100 (`battery taken`, notice "0/4"). Walk to the barn: "Press F to charge the box"
  at every empty panel (within 70): glow + sparks + clink, `box n charged k/4`, NO deny buzz or EMP thump on these
  presses (nor on the fourth), the battery STAYS in hand; at the fourth `battery consumed, all four boxes charged`,
  NavCard chime + runner, `r1 unlocked, the key card comes back`, and the key card arrives again by itself (`key card at
  ...`, no Simon replay). ONE bus trip. Go down while carrying: `battery dropped` at your feet, pick it up again. `!df
  fire r1_soul` charges one box without the trip, `!df souls` all four.
- R1, power OFF at the end of a round during the lock: `power off: box n emptied` + R2_POWER_RICH (one more panel to charge).
- R2, full lamp punched with the wrong tool: deny + "Bare steel? No.", no spool; `!df fire r2_punch` frees every ready spool.
- M1, timeout: see 4M. M1, hand carrier down (console says skull): `m1 hand dropped (<you> went down), take it again`. Carrier leaves:
  `m1 hand carrier left, the hand lies at the tower return point`.
- M2, carrier down: EMP thump + ash, `m2 fire hand lost (<you> went down), it waits on the table again`, M2_EMBER_LOST ("The hand
  fell with you..."), the fire on you stops (charged only); the hand is back on the table (plain, or burning if it was
  already the fire hand), take it again. Lit graves keep their count. Carrier leaves the game: `m2 the fire
  hand carrier left, it waits on the table again`, the notice clears.
- M2, power ON at the end of a round: EMP thump at the grave, Maxis's M2_POWER line, `m2 power ON at end of round:
  brazier_n forgets its N dead (Maxis wants the dark)`: ONLY the lit unfinished grave with the most kills goes back to
  0/5 (the others keep theirs, spent graves stay gone); nothing left to lose prints `m2 power on at end of round,
  nothing left to lose`. `!df fire m2_penalty` does it now.
- M2, a lit grave left alone 90 s: see the cold timer in 4M.
- Step 6, rock dropped: 60 s then home (nearer of the landing spot / table front, charges kept). After a Step 7 fail its
  home is the table front. Never touched after landing: 3 min, then the table front.
- Step 7, rock destroyed / zone empty: see Step 7 above; hold the table again, no second song.
- Finale, wrong power: RICH deny + line with the power off; MAXIS refuses a round that started with power on.

## 7. Skips and cleanliness
- `!df goto <step>` at any point: the skipped steps leave nothing behind (no lights, sparks, prompts, hums) BUT the boot
  props stay: pipes (dark), table, boxes, graves, the three DF_BLACKOUT switches, lamps. Boxes and graves are NEVER
  removed by the side lock any more (owner 2026-09-25): only their look (glow / flame) follows the locked side, both
  stay standing for the rest of the game. No AVAILABLE / DONE sounds during the jump, the target step plays its own
  once it opens. `!df goto step3`: no parts anywhere, relay on the roof. `!df goto step2`: coil at DF_COIL_DROP, two
  parts in the fog, 3 needed.
- The goto only moves FORWARD and never crosses the lock: `<step> is already done, goto only moves forward`, `<step> is
  not ahead of the current step <key>, goto only moves forward`, `<step> belongs to the <side> side but <side> is locked
  in this game (start a fresh game)`. A jump that hangs is aborted after 20 s: `goto <step> did not finish in 20 s,
  aborted (goto flag cleared)`; paste it.
- `!df goto r1` / `m1` locks the side itself (`side set to rich for r1`, `orb spawn for side ...`). `!df goto m3` (Maxis) / `!df goto r3` (Richtofen) and
  later with no side: `no side locked, defaulting to rich (use !df side maxis first to test Maxis)`; type `!df side
  maxis` FIRST for a Maxis test (it cannot be changed afterwards).
- `!df goto m3` (Maxis) / `!df goto r3` (Richtofen) RICH from round 1: boxes with a steady glow, the card on the middle slot (no glow), lamps filled
  (steady glow, no sparks), six step glows on the relay mast, `act 2 reward given silently (goto)` (no Max Ammo, no
  line). MAXIS: ONE hand on the table (M2's replaced M1's at the same pose), the charged fire hand
  resting there with its small flame (no prompt), four graves STILL STANDING, spent, dark, each with a scorched
  glow (owner 2026-09-25: no longer deleted; cosmetic, not Step 6 nodes). `!df goto step7` / `finale`: the
  rock rests on the right slot (no "Rock" notice), the fire hand is gone, tracker runners on.
- Stall hints: leave a step untouched 4 min: `stall hint <KEY> (<step> untouched)` + one line, then at 10 min and every
  6 min; every touch of the step starts the ladder over (HINT_1 4 min after the LAST touch); an event hint earlier
  (`event hint ...`) skips that rung once. `!df texthints off` mutes them (the clock keeps running); `!df hints off`
  (default) only hides puzzle prompts.
- `!df vox <alias>` plays a vanilla patron line (e.g. `vox_maxi_tv_distress_0` 3D at your feet). Silence = unknown alias.
- `!df freeze` while testing a placement: every regular zombie stands inert; toggle again to release them.
- Scavenger: pick up a real jet gun part: it goes to the pool (top-left notice), TAB shows the squares. Any console
  error naming `zm_scavenger` or `epod_key`? The pinned ladder / hatch must still be buildable as vanilla.
- Co-op only, when you have a second player: Richtofen's blue lines that carry team information reach everyone (including
  the finale's wrong-power line and closing lines); the M3 / R3 "one lamp each" line appears; a downed player is
  teleported into Nacht with the team and can be revived there; the Step 7 after-hold waves rise near a random living
  player; a carrier who leaves drops the relay (back on the table after 60 s), the M2 hand (back on the table at once)
  or the M1 hand (at the tower return point).

## Open verifications (things the code cannot decide alone)
- Step 1 readability: is the far light visible from where the pipes are, can four blinking pipes be told apart, is the
  closing spark a clear "end of message"? Say which fx you settle on (`df_fx_pipe_flash`, `df_fx_signal`, `df_fx_pipe_locator`).
- Beam alias / orientation: `!df fire beam_test` = one light shaft from the table to the nearest lamp for 20 s, console
  `beam test: <alias> from the table to lamp X`. Wrong way round: `set df_beam_flip 1`, fire again. Nothing: `set
  df_beam_fx fx_zmb_tranzit_god_ray_pwr_station` (or `_interior_med`, `mc_towerlight`), fire again. Say which one reads as a beam.
- Step glows: nine small glows up the relay mast by the end. Too faint / too strong? `set df_step_glow_fx <fx>` before
  loading swaps the glow (default fx_zmb_tranzit_key_glint, dimmer than the old bulb glow).
- Table pose: the M1 hand and the M2 fire hand lie at the SAME pose on the table (`!df goto m2` then `!df goto
  step5` on Maxis); the M1 one must not spin. Sunk, floating, inside the relay? Say so. Rock rest height: 3 above slot 2 / the ground (`!df fire
  table_demo`, `!df tp DF_ORB_SPOT_n`).
- Fuse box wall offset: the boxes are 6 off the wall at mid height. In the wall, or a visible gap? Say which box (`!df tp DF_FUSE_n`).
- Grave flame: the small flame sits at the top of every standing tombstone (`set df_m2_fire_fx <fx>` swaps it). The
  fire hand on the table has its own, smaller flame (`dog_trail_fire`; `set df_m2_hand_fx <fx>` swaps it at the next
  spawn, `character_fire_death_sm` = the old one). Buried or floating? Visible from the road? Say so.
- Orb landing spots: is the rock reachable and visible at Town (SPOT_2, 900 130) and at the power station (SPOT_3)? Off the road?
- Step 7 solo pass rate: at round 10 with a Pack-a-Punched gun, how many tries out of three pass? Paste `s7 wave over ...`.
  Are the after-hold waves (until the song ends) fun or too long?
- Finale queue length: after the burst, world line + keepsake + three closing lines = ~5-6 lines at 6.5 s each (~40 s).
  Too long? Say so.

## What to report
Per step: OK / not OK, the `[DF]` console lines around the problem, and for models the anchor name plus what you see.
For positions: the `[SPOT]` line printed by `!df grab` / `!df move`. For picks: the `[n] name` of the effect / sound
(or the "Copy picks" list from the picker pages) and what it is for.
