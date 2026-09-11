# companion/zm_transit_enhanced_noee.gsc

**TranZit Enhanced (noee build)** by **Myrix**, original release: https://forum.plutonium.pw/topic/46428/release-zm-tranzit-enhanced. A REQUIRED companion script for Dead Frequency.
It is attached to every Dead Frequency release; copy it into the same game folder as the two Dead Frequency files:

    %LOCALAPPDATA%\Plutonium\storage\t6\scripts\zm\zm_transit\

## What it does

It is a general TranZit fix-up script, not part of the quest itself:

- the Jet Gun is completely reworked (heat, speed, refill, points on kills);
- the bus system is reworked (calling the bus, stops, parts);
- quality-of-life tweaks: the Pack-a-Punch door no longer closes after the turbine is destroyed, denizens need
  4 knife hits instead of 5, the Avogadro drops a Max Ammo when he dies, and a few more.

Dead Frequency was built and tested with this script loaded and relies on its bus and Jet Gun behaviour, which is
why it is required rather than optional.

## Why this specific build ("noee")

The regular release of TranZit Enhanced also carries helpers for the VANILLA TranZit Easter Egg in solo. Dead
Frequency turns the vanilla Easter Egg off and ships its own solo handling, so this build, made by the author for
Dead Frequency, has those helpers removed. The credit lines in the script's own header about solo Easter Egg
scripts refer to that removed part.

Do not install the regular `zm_transit_enhanced.gsc` next to Dead Frequency, and do not install any other
"solo Easter Egg" script for TranZit: they alter the vanilla quest, which this mod disables.

## Credits

TranZit Enhanced and its noee build: **Myrix**. The file is included unchanged from the build the author
delivered; Dead Frequency does not edit it, and it keeps its author's terms.
