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
    ON sends a sprint wave at it; at the end of every round Maxis knocks one ON switch OFF. One
    press of F within range turns it back ON (refused while the grid is off).
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
- Dropped quest items can no longer be lost: the key card, battery, spool and lantern ride the bus
  when their carrier goes down on it, and fly home after 60 s untaken (card to the barn wall,
  battery to the dashboard, spool to its lamp, lantern to the tower).
- `!df setpos <KEY> x y z [yaw]` moves any named anchor straight to world coordinates (switches
  and graves follow a moved anchor); `!df who` diagnoses blocked interactions.
- TranZit prop gallery tool (every always-loaded model, sorted by size, with a 3D viewer) for
  finding new prop candidates.

### Changed
- Step 7: relay-powering hold shortened to 1.5 s; finale hold at the table is 2.5 s.
- Galvaknuckles wall buy now actually costs 3000 (was silently still 6000; the fix touches
  `level.tazer_cost`, the wall stub and `level._melee_weapons`).
- Pipes and Simon-style puzzle inputs no longer show an interact prompt, matching vanilla; pickups,
  builds and deposits keep theirs.
- Dialogue and on-screen hints reworked across M1/M2/M3/R3 to match the new mechanics (grave
  lighting, lantern arc, lamp/switch steps).
- Scavenger's TAB square now uses a plain dark frame instead of Scavenger's radio-picture border.

- Hint ladders reveal step by step: HINT_1 points at the place, HINT_2 at the method.
- R1 fuse boxes moved to new spots in the Farm barn.
- Maxis Step 7: no denizens at the tower while the relay holds.

### Fixed
- Claymore kills at a Lights Out lamp count (the game reports them as weapon "none"); a splash
  kill counts only right after a nearby claymore detonates.
- A grave could miss the shot: it now takes bullets on its trigger, its model and two bullet
  walls inside the stone, and each grave lights independently.
- Blackout, Lights Out and grave props follow their anchors when moved by `!df setpos`,
  `!df grab` or `!df aim`; `!df setpos` refuses unknown keys and keeps pitch and roll.
- Skipping past M1 during the cold room brings players back from the woods.
- Lamps put out in Lights Out stay dark in Step 6; Step 7 after-hold waves stop at the finale;
  the upgraded Jet Gun also cools for the finale reward.

### Removed
- M2 lantern carrying (take, burn, drop): the lantern never leaves the table now.
- Table fx under the tower and the Step 4 preview light.

### Testers and modders
- Debug: `!df setpos`, `!df who`, `!df goto m3`, `!df goto r3`.
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
