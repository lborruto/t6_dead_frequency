# Changelog

All notable changes to Dead Frequency are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.1.0] - unreleased

### Added
- Step 5 splits by side: Maxis "Lights Out" (M3) and Richtofen "Blackout" (R3).
  - M3: three lamps hum with Richtofen's power; a claymore kill at a lamp's base puts it out
    (250 units, any claymore weapon name); Richtofen relights one lamp per round. A put-out lamp
    reverts to vanilla exactly, sending its electricity back to the tower.
  - R3: three vanilla-style power switches at Nacht, Town and the power plant. Each switch turned
    ON sends a sprint wave at it. All three must be ON within one round: at the end of every
    round with a switch still OFF, Maxis knocks every ON switch back OFF; the third ON wins at
    once. One press of F within range turns a switch ON (refused while the grid is off).
  - `!df goto m3` / `!df goto r3` jump to the step5 slot by side name.
- M2: four graves stand outside the map around Town, drawn at random from eight spots each game.
  Shoot a grave to light it (90 s each, all four can burn at once); its kill zone opens where
  the shooter stood, and denizens leave players alone inside it. A filled grave bursts and is
  gone.
- Maxis's relic is now a lantern (a dead red cage lamp, standing upright). M1 leaves it, it
  waits on the table through M2 and catches fire when the fourth grave is spent, and Step 6
  bursts it into the rock. Replaces the earlier ember / skull / fire-hand designs.
- M1's cold room moves to the woods behind the hunter's cabin; a no-denizen zone covers the area
  while players are inside, ending on the return teleport, a skip, or walking out.
- Step 6 Maxis: the rock charges at the hunter's cabin fireplace (hold the rock and fire the Jet
  Gun until it overheats, as Richtofen's plant bridge block); denizens leave players alone near it.
- Dropped quest items can no longer be lost: the key card, battery and lantern ride the bus
  when their carrier goes down on it, and fly home after 60 s untaken (card to the barn wall,
  battery to the dashboard, lantern to the tower).
- `!df setpos <KEY> x y z [yaw]` moves any named anchor straight to world coordinates (switches
  and graves follow a moved anchor); `!df who` diagnoses blocked interactions.
- TranZit prop gallery tool (every always-loaded model, sorted by size, with a 3D viewer) for
  finding new prop candidates.

### Changed
- R1 is punished properly: a wrong Simon press starts a new sequence from one spark, and a failed
  capture needs the bus battery in all four boxes AND the Simon again before a new key card comes.
- Finale gift: the perks stay on after a power-off (vanilla pauses them; before the finale they
  still go down with the power), plus Deadshot, Mule Kick and PhD Flopper (no HUD icon on TranZit).
- Step 2 "Salvage" is merged into Step 3 "Ride the Line": one step covers collecting the parts,
  building the relay on the bus roof and the ride. Parts and spots are unchanged; its hints
  follow the build first, then the ride. `!df goto step2` is an alias of `step3`; the relay
  mast shows eight step glows instead of nine.
- R2: lamp quota lowered to 10 / 12 / 14 / 16 kills (was 12 / 15 / 18 / 18), and a punched
  full lamp's wire spool now flies to the table by itself - no pickup, carry or table trip.
- R3 Blackout: the three switches must all be ON within one round (see Added).
- Step 6: the rock's release is seen and heard by the whole team - a screen shake and a loud
  crack for every player, and the trail climbs high above the tower before it curves down to
  the landing spot.
- Step 7: relay-powering hold shortened to 1.5 s; finale hold at the table is 2.5 s.
- Galvaknuckles wall buy now actually costs 3000 (was silently still 6000; the fix touches
  `level.tazer_cost`, the wall stub and `level._melee_weapons`).
- Pipes and Simon-style puzzle inputs no longer show an interact prompt, matching vanilla; pickups,
  builds and deposits keep theirs.
- Dialogue and on-screen hints reworked across M1/M2/M3/R3 to match the new mechanics (grave
  lighting, lantern arc, lamp/switch steps).
- Scavenger's TAB square now uses a plain dark frame instead of Scavenger's radio-picture border.

- Hint ladders make the players search: START tells the goal, HINT_1 points at the place or the
  idea, HINT_2 is a sharper nudge but never the recipe, and a new one-time HINT_3 at 20 minutes
  is the plain last resort (the old explicit texts); after it the patrons stay quiet until you
  make progress. HINT_2 plays at most twice. Puzzle steps (Dead Air, R1, M1, R3 / M3) wait
  longer: 6 and 15 minutes instead of 4 and 10.
- Hints follow the current sub-goal: R1 (key card, Avogadro asleep, the hunt, the battery), R2
  (a full lamp waiting for its punch), M1 (the open hole, the lantern), M2 (after the first lit
  grave), Step 3 (build, then ride) and Step 6 (rock not found, empty, full) each have their own
  rungs, and moving to a new sub-goal restarts the hint clock.
- Event lines no longer solve their step: the first denizen ride, the first stray kill at a
  Lights Out lamp (now after five such kills, no claymore named), the first full R2 lamp (no
  Galvaknuckles named) and the Step 6 pickup only point the way.
- Players who are not Stuhlinger on Richtofen's side now hear one cold Maxis line at the start of
  R1, R2 and the finale (R3, Step 6 and Step 7 already had one) that gives away the idea of the
  step; R3's Maxis line no longer tells them to keep the switches dark.
- Step 6 release lines only say "look up", the landing spots are named by the first hint, and no
  opening line names the node any more. Blackout, Lights Out, Step 3 and R2 lines match the new
  mechanics (every lit switch falls at the round end, any number of humming lamps, the flying
  spool, the build-and-ride step; the build line and the ride line are one exchange now).
- R1 fuse boxes moved to new spots in the Farm barn.
- Maxis Step 7: no denizens at the tower while the relay holds.

### Fixed
- Richtofen is heard only by the Stuhlinger player, recordings included: his Step 4 lock line
  played in 3D at the table, audible to everyone nearby.
- Lights Out with four players: all four set lamps hum and three put out win; the fourth now
  goes out with the win instead of humming for the rest of the game.
- Claymore kills at a Lights Out lamp count (the game reports them as weapon "none"); a splash
  kill counts only right after a nearby claymore detonates.
- A grave could miss the shot: it now takes bullets on its trigger, its model and two bullet
  walls inside the stone, and each grave lights independently.
- Blackout, Lights Out and grave props follow their anchors when moved by `!df setpos`,
  `!df grab` or `!df aim`; `!df setpos` refuses unknown keys and keeps pitch and roll.
- Skipping past M1 during the cold room brings players back from the woods.
- Lamps put out in Lights Out stay dark in Step 6; Step 7 after-hold waves stop at the finale.

### Removed
- M2 lantern carrying (take, burn, drop): the lantern never leaves the table now.
- Table fx under the tower and the Step 4 preview light.

### Testers and modders
- Debug: `!df setpos`, `!df who`, `!df goto m3`, `!df goto r3`, `!df fire r1_fail`.
- Internal: effect attach points and table slot poses moved into data registries
  (`df_fx_point_def`, `df_table_slot_def`); composer/picker tooling updated to read and export
  from them (relay, table, card/orb/lantern poses, power-switch and grave anchors). These are
  workflow tools only and do not affect gameplay.

## [1.0.0-rc6] - 2026-09-22

### Fixed
- Docs and in-game hints now point to the fog parts' real locations (radio: Diner garage, mast:
  Farm barn) instead of the old cabin/tunnel spots.

## [1.0.0-rc5] - 2026-09-11

### Fixed
- The Richtofen Jet Gun reward no longer blocks progress on Step 6.

## [1.0.0-rc4] - 2026-09-11

### Changed
- Richtofen's broadcast is heard by Stuhlinger only, exactly as vanilla (broadcast tag removed
  from the sheet and code; no solo stand-in; recordings included).
- Step 3 stops now count only with a rider near the relay.
- Roof assault while the relay charges: two zombies every 1.5 s ahead of the bus, capped at
  8 + 3 per extra player.

### Fixed
- Relay swings on a moving bus no longer pin a zombie in the air.

### Removed
- Dead heat-relief helper code.

## [1.0.0-rc3] - 2026-09-11

Baseline for this changelog. Richtofen Step 6 becomes a single draw (fire the Jet Gun at the block
until it overheats, vanilla tower rule); Step 7 after-hold waves rise at the tower; denizen
immunity applies only beside a lit grave during M2.

## Earlier

- **v1.0.0-rc2** (2026-09-11): Step 7 orb HP scales with lobby size (3000/4200/5400/6600); graves
  explained in dialogue; the Nacht door line warns that everyone goes.
- **v1.0.0-rc1** (2026-09-11): first tagged build of Dead Frequency.
