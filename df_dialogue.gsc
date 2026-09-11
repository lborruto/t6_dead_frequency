// Dead Frequency - dialogue sheet (spec section 7). Data only: the queue, HUD and recipients live in
// df_systems.gsc (df_say / df_show_line / df_rich_recipient).
//   Speakers: "maxis" is shown to every player; "rich" only to the Stuhlinger player (solo: the player).
//   A key may hold several lines; they are queued in order, 6.5 s apart. A lowercase alias is built per
//   key so "!df say s1_start" works.
//
//   Key families (dialogue2 pass, owner feedback 2026-09-08 "we need more, cryptic hints"):
//     <P>_START   spoken 2 s after the step becomes available (df_steps df_step_intro). Cryptic: sets the
//                 goal, the patron does not quite know what to do but knows what must be done.
//     <P>_HINT_1  stall ladder, 4 min untouched: less cryptic.       (old <D>_HINT keys are aliases)
//     <P>_HINT_2  10 min untouched, then every 6 min: almost explicit.
//     event keys  called by the step files (grep df_say): progress, FAIL, DONE.
//   Prefixes P: S1..S4 (Act 1), R1 R2 (Act 2 Richtofen), M1 M2 (Act 2 Maxis), S5 S6 S7 FIN (Act 3).
//
//   Side rule (owner 2026-09-08): before the fork (S1..S4) both patrons speak. On a locked side only the
//   side's patron carries the ladder and the failures; the rival heckles at most once per step (R1: the
//   capture taunt, R2 / M2: the DONE line, M1: the portal, Act 3: the START line). Act 3 and the finale
//   are shared, so their keys exist as <KEY>_RICH / <KEY>_MAXIS; df_steps picks the variant for the
//   ladder itself (df_step_dlg_key). For the event keys the step files call (D5_FAIL, D6_DONE, ...) df_say
//   prefers <key>_<SIDE> once the side is locked, so the plain Act 3 keys are reached only by !df say
//   before the fork: they keep the sided texts word for word (the compiler stores a string once, and the
//   packed script sits at the engine string limit; tools/audit_story_applied.md).
//   Richtofen-only lines that carry information the whole team needs are tagged broadcast = 1 (4th arg):
//   df_show_line sends them to every player (audit 2026-09-08 #1). A line tagged coop = 1 (5th arg) is
//   dropped in solo by df_say ("one lamp each").
//   Event keys added by the audit pass (2026-09-08), listed with their step: R1_RICH_CHAMBER, M1_EVENT,
//   S5_ANCHOR_TURBINE_MAXIS / S5_ANCHOR_DENIZEN_RICH, S6_NOJETGUN_RICH / _MAXIS, S6_DRAW_LAVA_MAXIS,
//   S7_AVOGADRO_RICH, A2_REWARD_RICH / _MAXIS, FIN_WORLD_RICH / _MAXIS, ITEM_RECEIVER, ITEM_BATTERY_RICH,
//   ITEM_SPOOL_RICH, ITEM_EMBER_MAXIS, ITEM_SKULL_MAXIS (tools/audit_A.md says who calls each), and
//   M2_POWER_MAXIS (dialogue audit v2, 2026-09-09). Dead keys cut by that audit (no caller, string budget):
//   D0_INTRO_POWEROFF, ITEM_FUSE, S3_HALF (tools/audit_V2dialogue.md); ITEM_KEEPSAKE_RICH / _MAXIS stay.
//   Lamps are never named by a colour in a line (the lamp colour does not render; they spark and hum).
//
//   Writing rules (story audit 2026-09-08, tools/audit_story.md): Richtofen manic, exclamations, insults,
//   German sprinkles, says obelisk / the flesh / 115 / my pretties; Maxis urgent, formal, technical,
//   says the Spire / energies / the design / the creature, German only Nein / Ja. Never souls (Buried
//   word), never his creature (the Avogadro is nobody's pet: Richtofen steals Maxis's battery in
//   R1). Each finale claims THIS spire and points at the other sites. START and HINT_1 hint, HINT_2 nearly
//   instructs (owner asked for it). ASCII only (the HUD font has no accents), text <= 78 chars so
//   "Richtofen: " + text fits one HUD line.

// Fills level.df_lines (called from df_main init and lazily from df_say). Idempotent.
// is_true / isdefined and the other unqualified helpers come from the vanilla utility scripts: without
// these three lines the game refuses the file with `Unresolved external "is_true"` (seen 2026-09-08).
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

df_dialogue_init()
{
    if ( isdefined( level.df_lines ) )
        return;

    level.df_lines = [];

    // Intro (df_main, 20 s after the round 1 intro)
    df_add_line( "D0_INTRO", "maxis", "Something is speaking on a frequency no one should still have." );
    df_add_line( "D0_INTRO", "rich", "Ignore him, Samuel. Dead men make terrible radio hosts." );

    df_dialogue_act1();
    df_dialogue_act2_rich();
    df_dialogue_act2_maxis();
    df_dialogue_act3_sweep();
    df_dialogue_act3_vacuum();
    df_dialogue_act3_hold();
    df_dialogue_finale();
    df_dialogue_aliases();
}

// Act 1 "Static" (shared, both patrons). Mechanics (df_act1.gsc): Step 1 four pipes on the ground around
// the Depot each blink their own number (1-4, random per game); a far light past the fence flashes the
// order; the pipes are kicked in that order and the coil strikes down near the Depot (puzzle prompts
// hidden, the lines are the only teacher); Step 2 radio (Cabin), mast (tunnel) and coil (Depot) built on
// the bus roof; Step 3 the relay rides ONE full stop with power on while zombies chew on it
// (df_a1_stops_needed); Step 4 the relay goes to the table under the tower, the power state locks the side.
df_dialogue_act1()
{
    // Step 1 - Dead Air (the chimney pipes)
    df_add_line( "S1_START", "maxis", "The Depot is not dead. Something in the mud around it still keeps time." );
    df_add_line( "S1_START", "rich", "A light blinks past the fence, Samuel. Something out there can still count." );
    df_add_line( "S1_HINT_1", "maxis", "Four pipes in the mud. Each counts itself. The far light counts them in order." );
    df_add_line( "S1_HINT_2", "maxis", "Kick the pipes in the far light's order. A pipe that blinks three is three." );
    df_add_line( "S1_HINT_2", "rich", "Count the flashes, Samuel. Not a symphony, a headcount. Kick them in order." );
    df_add_line( "D1_MAXIS", "maxis", "Yes. The pattern holds. He will hear this too. A pity." );
    df_add_line( "D1_RICH", "rich", "Four rusty pipes in the mud! THAT is his grand antenna? Oh, Maxis. Hahaha!" );
    // ITEM_RECEIVER: the solved pipes call the coil down by a strike near the Depot, the relay's third part
    df_add_line( "ITEM_RECEIVER", "maxis", "The sky struck near the Depot. It left a coil of wire. The relay will need it." );

    // Step 2 - Salvage
    df_add_line( "S2_START", "maxis", "A voice needs a body. Three pieces of one; two lie where the fog is thick." );
    df_add_line( "S2_START", "rich", "A scavenger hunt! Oh, I adore those. Mind the corn, Samuel. It bites." );
    df_add_line( "S2_HINT_1", "maxis", "A cabin and a tunnel. The fog kept a piece in each. The light gave the third." );
    df_add_line( "S2_HINT_2", "maxis", "Radio from the cabin, mast from the tunnel, the coil. Build on the bus roof." );
    df_add_line( "S2_HINT_2", "rich", "Three parts and a school bus roof, Samuel. Even Maxis could build that." );
    df_add_line( "D2_DONE", "rich", "A relay on a school bus. Samuel, you are a genius and I hate it." );
    df_add_line( "D2_DONE", "maxis", "It travels. Good. Now let it listen to the road." );

    // Step 3 - Ride the Line (one full stop, power on; D3_FAIL covers relay destroyed, EMP, empty bus)
    df_add_line( "S3_START", "maxis", "It is built. Now it needs current, and distance. Both at once." );
    df_add_line( "S3_START", "rich", "A relay that goes nowhere hears nothing. Lights on, wheels turning, Samuel!" );
    df_add_line( "S3_HINT_1", "maxis", "The grid must hum and the bus must roll. One full stop, and keep it whole." );
    df_add_line( "S3_HINT_2", "maxis", "Power on. Ride one full stop with it. Keep their hands off the roof." );
    df_add_line( "S3_HINT_2", "rich", "One stop, Samuel, lights on, and nobody chewing the roof. Simple." );
    df_add_line( "D3_RICH_NOPOWER", "rich", "The power, Samuel! A relay in the dark is just luggage." );
    df_add_line( "D3_RICH_NOPOWER", "maxis", "It is deaf in the dark. For now, it needs his noise." );
    df_add_line( "D3_FAIL", "rich", "Lost the sweep. Did they chew on it, or did you wander off? Sloppy." );
    df_add_line( "D3_FAIL", "maxis", "The segment is lost. The road will come around again." );
    df_add_line( "D3_DONE", "maxis", "It has found the signal. Bring it to the source." );
    df_add_line( "D3_DONE", "rich", "The obelisk, Samuel! It always comes back to the obelisk. Oh, I love it!" );

    // Step 4 - Plug In (the relay lifts off the roof; the socket under the tower; power state = side)
    df_add_line( "S4_START", "maxis", "Take it where the signal was born. In the dark, if you value my voice." );
    df_add_line( "S4_START", "rich", "Pull my relay off that roof, Samuel. And leave the lights burning. For me." );
    df_add_line( "S4_HINT_1", "maxis", "The relay comes off the roof now. A table waits at the foot of the Spire." );
    df_add_line( "S4_HINT_2", "maxis", "Set the relay on the table under the Spire. Power on serves him. Off, me." );
    df_add_line( "S4_HINT_2", "rich", "Relay. Table. Obelisk. And leave the lights ON, Samuel, or he wins." );
    df_add_line( "D4_RICH_LOCK", "rich", "Lights on! Oh, Samuel, you chose the winning side. Maxis, are you weeping?" );
    df_add_line( "D4_RICH_LOCK", "maxis", "So you choose the noise over the silence. We shall see." );
    df_add_line( "D4_MAXIS_LOCK", "maxis", "Darkness. Good. He is loud, but he cannot follow where nothing hums." );
    df_add_line( "D4_MAXIS_LOCK", "rich", "Turning off the power. Very mature. Enjoy the fog, Samuel." );
}

// Act 2R (Richtofen only; Maxis heckles once per step). Mechanics (df_act2_rich.gsc): R1 four power
// boxes in the Farm barn spark in a growing order (Simon), repeat it, a key card strikes onto the barn wall,
// insert it at the table, the storm drags the creature to the tower, defeat him within 900 of it (vanilla:
// knife only) inside capture_time s, failure: ONE bus battery refills all four boxes; R2 three set lamp
// posts (one always nearest the tower) each swallow a quota of kills (12 solo) within 400 units, a full lamp
// glows steady and a Galvaknuckles punch on the post drops a wire spool that goes to the table (ITEM_SPOOL_RICH).
// Story: the creature's energies were Maxis's plan (canon), Richtofen steals them (R1_MAXIS_TAUNT is a loss);
// the stolen storm sits in the four barn boxes (the S6 nodes) until the orb carries it to the obelisk.
df_dialogue_act2_rich()
{
    // R1 - Summon the Storm
    df_add_line( "R1_START", "rich", "Now we need a storm. Storms live in barns, Samuel. Trust me, I have checked.", 1 );
    df_add_line( "R1_HINT_1", "rich", "Four boxes in the Farm barn. They spark in an order. Sparks are a language.", 1 );
    df_add_line( "R1_HINT_2", "rich", "Watch the boxes spark, Samuel. Touch them in that order. It grows. Keep up.", 1 );
    df_add_line( "R1_RICH_CARD", "rich", "A card in the barn wall, Samuel! Better than a navcard. Feed the obelisk!", 1 );
    df_add_line( "R1_RICH_SUMMON", "rich", "There he is! Keep him under the obelisk. Knife, Samuel. Bullets only tickle.", 1 );
    // R1_RICH_FAIL covers both: defeated away from the tower, or the 180 s capture window ran out
    df_add_line( "R1_RICH_FAIL", "rich", "Gone! Wrong place, or too slow. The boxes sulk now. The bus keeps a battery.", 1 );
    // R1_RICH_CHAMBER: Avogadro still sleeps in the power chamber, no capture timer runs (audit section 5)
    df_add_line( "R1_RICH_CHAMBER", "rich", "He sleeps where the power is born, Samuel. Wake him. Poke him if you must.", 1 );
    df_add_line( "R1_RICH_CAPTURED", "rich", "Wunderbar! Maxis wanted his little battery. Now my barn boxes hold his storm!" );
    // ITEM_BATTERY_RICH: one battery from the bus dash refills all four boxes (audit section 9)
    df_add_line( "ITEM_BATTERY_RICH", "rich", "The boxes are empty. The bus keeps a battery under its dashboard. Borrow it.", 1 );
    df_add_line( "R1_MAXIS_TAUNT", "maxis", "Nein! The creature's energies were to be mine. You have set the design back." );

    // R2 - 115 on the Line
    df_add_line( "R2_START", "rich", "A battery is nothing without wires, Samuel. Look for the sparks in the fog.", 1 );
    df_add_line( "R2_HINT_1", "rich", "Some lamp posts spit sparks now. They are hungry, and they only eat one thing.", 1 );
    df_add_line( "R2_HINT_2", "rich", "Kill beneath a sparking lamp until it glows steady. Galvaknuckles on the post.", 1 );
    df_add_line( "R2_RICH_FULL", "rich", "Full! Now punch the post, Samuel. The Galvaknuckles, not your little knife.", 1 );
    df_add_line( "R2_RICH_NOFISTS", "rich", "Bare steel? No. Electricity wants electricity. Galvaknuckles, Samuel.", 1 );
    df_add_line( "R2_DONE", "rich", "Every lamp fat with 115! Lines on a map, Samuel. Oh, it is beautiful!" );
    df_add_line( "R2_DONE", "maxis", "He is building a cage. Do you not see it? Listen to the fog." );
    // ITEM_SPOOL_RICH: a wire spool drops at a filled lamp, three build the array on the relay (audit section 9)
    df_add_line( "ITEM_SPOOL_RICH", "rich", "A spool of wire, Samuel! Pick it up and string it to the obelisk. Wunderbar!", 1 );
}

// Act 2M (Maxis only; Richtofen heckles once per step). Mechanics (df_act2_maxis.gsc): M1 a denizen
// riding a player is carried within 300 of the socket and opens a hole into the Nacht bunker; six denizen
// kills (df_scaled cold_room_kills / cold_room_time) and the stone strikes down, the hole waits until
// someone walks in; M2 the ember waits on the table, any of the four graves by the lava lights it, burning
// zombies killed within 250 of a lit grave (5) make it vanish, all four charge the ember (brazier_burns).
df_dialogue_act2_maxis()
{
    // M1 - The Cold Room
    df_add_line( "M1_START", "maxis", "The signal needs a key. The fog is full of small, angry keys." );
    df_add_line( "M1_HINT_1", "maxis", "The little ones want the relay. Let one cling to you and walk it to the Spire." );
    df_add_line( "M1_HINT_2", "maxis", "Carry a little one on your head to the table. A hole opens. Go in. Kill six." );
    // M1_EVENT: the first denizen latches onto a player after M1 opens (event hint, audit #6)
    df_add_line( "M1_EVENT", "maxis", "Do not kill it. Let it ride. Carry it to the socket under the Spire. Quickly!" );
    df_add_line( "M1_PORTAL", "maxis", "A door. It is cold on the other side. Do not linger there." );
    df_add_line( "M1_PORTAL", "rich", "Do not go in there, Samuel. Actually, do. I could use the laugh." );
    df_add_line( "M1_MAXIS_FAIL", "maxis", "Too slow. The cold does not wait. Bring another one to the socket." );
    df_add_line( "M1_DONE", "maxis", "It is keyed. The signal knows us now. What is left needs fire." );
    // ITEM_SKULL_MAXIS: the STONE strikes down after the denizen kills; the take cue, called from
    // df_m1_skull_appear instead of the table placement (dialogue audit v2 #8; M1_DONE covers the placement)
    df_add_line( "ITEM_SKULL_MAXIS", "maxis", "Lightning left you a stone. Take it. Set it on the table under the Spire." );

    // M2 - Fire and Ash
    df_add_line( "M2_START", "maxis", "Four graves face the lava for a reason. A flame waits for you on the table." );
    df_add_line( "M2_HINT_1", "maxis", "Four graves stand by the lava past the Spire. Touch each with the flame." );
    df_add_line( "M2_HINT_2", "maxis", "Light a grave, stay near it, kill five burning dead beside it. Then the next." );
    df_add_line( "M2_MAXIS_BRAZIER", "maxis", "Good. That grave is spent. The fire remembers it." );
    // ITEM_EMBER_MAXIS: the ember taken from the table; a grave lights it, then the lit graves want burning
    // kills (dialogue audit v2, M2: the take touches the ladder, so this line carries the second half)
    df_add_line( "ITEM_EMBER_MAXIS", "maxis", "It burns you. Carry it to the graves by the lava and touch each one." );
    df_add_line( "M2_EMBER_CHARGED", "maxis", "All four are ash. The flame is heavy now. Bring it back to the table." );
    df_add_line( "M2_EMBER_LOST", "maxis", "The flame went out with you. It waits on the table again." );
    df_add_line( "M2_KNUCKLES_MAXIS", "maxis", "Nein! His current will not touch my graves. Fire. Only fire." );
    // M2_POWER_MAXIS: the grid was ON at the end of a round and a brazier stage is lost (df_m2_power_penalty;
    // dialogue audit v2 section 3, optional key; the caller is requested in tools/requests_V2dialogue.md)
    df_add_line( "M2_POWER_MAXIS", "maxis", "The grid is live. The graves forget their dead while it hums. Cut it." );
    df_add_line( "M2_DONE", "maxis", "The ash carries the message. Now the fog will answer it." );
    df_add_line( "M2_DONE", "rich", "Bonfires. He has reduced you to bonfires, Samuel." );
}

// Act 3 Step 5 "Frequency Sweep" (shared, sided keys). Mechanics (df_act3_sweep.gsc): the set lamps hum
// (Richtofen: the R2 lamps; Maxis: three lamps the tower picks and marks when the step opens, the
// Maxis player fed graves, never lamps); hold at a lamp to tune it and an anchor must hold it within 15 s.
// Fork (owner 2026-09-09, canon: vanilla Maxis's third node IS two turbines at denizen lamps): MAXIS anchors
// with a running TURBINE within 200 of the lamp base (the grid is dark, the turbine gives the lamp the power
// the grid does not); RICHTOFEN anchors by PUNCHING the post with the Galvaknuckles (the denizen burrow
// anchor is gone; the key name stays). The first anchor starts the audible countdown (df_scaled sweep_time);
// three anchors win; expiry drops the anchors and the unanchored lamps want kills first.
// Story (audit section 7): the lamps are Richtofen's old antenna. The coop lines say "one lamp each".
// S5_ANCHOR_TURBINE_MAXIS / S5_ANCHOR_DENIZEN_RICH: said once per game, the first time a tuned lamp waits.
df_dialogue_act3_sweep()
{
    df_add_line( "S5_START_RICH", "rich", "The lamps were my antenna, Samuel. Each one you fed still hums with it.", 1 );
    df_add_line( "S5_START_RICH", "rich", "You are not alone, Samuel. One lamp each. The clock waits for no one.", 1, 1 );
    df_add_line( "S5_START_RICH", "maxis", "Careful. Whatever you tune, he is listening on the other end." );
    df_add_line( "S5_START_MAXIS", "maxis", "The Spire needs three points. Three lamps in the fog have begun to hum." );
    df_add_line( "S5_START_MAXIS", "maxis", "You are several. One lamp each; the fog rewards those who spread out.", 0, 1 );
    df_add_line( "S5_START_MAXIS", "rich", "Street lights, Samuel! He has you tuning STREET LIGHTS! Hahaha! Pathetic." );
    // plain S5_HINT_1 (D5_HINT alias, !df say before the fork): the sided texts word for word, no own string
    df_add_line( "S5_HINT_1", "maxis", "Stand at a humming lamp until it settles. Then it waits. It will need power." );
    df_add_line( "S5_HINT_1", "rich", "Stand at one of YOUR lamps and hold on. Then jolt the post. Electric fists." );
    df_add_line( "S5_HINT_1_RICH", "rich", "Stand at one of YOUR lamps and hold on. Then jolt the post. Electric fists.", 1 );
    df_add_line( "S5_HINT_1_MAXIS", "maxis", "Stand at a humming lamp until it settles. Then it waits. It will need power." );
    df_add_line( "S5_HINT_2_RICH", "rich", "Stand at a lamp until it ticks, then punch the post with the Galvaknuckles.", 1 );
    df_add_line( "S5_NOFISTS_RICH", "rich", "Not with that, Samuel! The Galvaknuckles. The lamp wants a real jolt.", 1 );
    df_add_line( "S5_HINT_2_MAXIS", "maxis", "A running turbine at a humming lamp, then stand at it until it ticks. Three." );
    // S5_ANCHOR_TURBINE_MAXIS: on the Maxis path a running turbine at the set lamp is the anchor (owner 2026-09-09)
    df_add_line( "S5_ANCHOR_TURBINE_MAXIS", "maxis", "It drifts. The grid feeds that lamp nothing. A turbine at its foot. Quickly!" );
    // S5_ANCHOR_DENIZEN_RICH: on the Richtofen path a Galvaknuckles punch on the set lamp post is the anchor
    df_add_line( "S5_ANCHOR_DENIZEN_RICH", "rich", "Nothing holds it, Samuel! Punch the post! Galvaknuckles, while it ticks!", 1 );
    df_add_line( "D5_ANCHOR", "maxis", "That one holds. The others still drift. Listen again." );
    df_add_line( "D5_ANCHOR_RICH", "rich", "One holds! The others still wobble, Samuel. Faster." );
    df_add_line( "D5_ANCHOR_MAXIS", "maxis", "That one holds. The others still drift. Listen again." );
    df_add_line( "D5_FAIL", "rich", "Too slow, Samuel! What held, holds. The loose lamps want the dead first." );
    df_add_line( "D5_FAIL", "maxis", "The clock ran out. What is anchored stays. Loose lamps want the dead first." );
    df_add_line( "D5_FAIL_RICH", "rich", "Too slow, Samuel! What held, holds. The loose lamps want the dead first.", 1 );
    df_add_line( "D5_FAIL_MAXIS", "maxis", "The clock ran out. What is anchored stays. Loose lamps want the dead first." );
    df_add_line( "D5_DONE", "rich", "Tuned! Do you hear it, Samuel? Now something must carry the charge home." );
    df_add_line( "D5_DONE", "maxis", "Three anchors. It cannot drift now. Something small must carry the charge." );
    df_add_line( "D5_DONE_RICH", "rich", "Tuned! Do you hear it, Samuel? Now something must carry the charge home." );
    df_add_line( "D5_DONE_MAXIS", "maxis", "Three anchors. It cannot drift now. Something small must carry the charge." );
}

// Act 3 Step 6 "Vacuum" (shared, sided keys). Mechanics (df_act3_vacuum.gsc): one small orb (a meteor
// stone model) lands by lightning at one of three random spots, either side (the HINT_1 lines say "where
// the lightning struck", never a fixed place); a player carries it to each charged node:
// Richtofen the four barn power boxes, Jet Gun fired at the box 5 s while carrying; Maxis the scorched grave
// spots, the carrier stands IN the lava beside one (requests_C / _E); full, it goes to table slot 2. D6_HINT is the
// cue on every pickup of a not yet full orb (df_s6_orb_take).
df_dialogue_act3_vacuum()
{
    df_add_line( "S6_START_RICH", "rich", "That crackle at the power plant, Samuel? My storm wants out. Find it a jar.", 1 );
    df_add_line( "S6_START_RICH", "maxis", "He has you carrying his batteries now. Follow his light, if you must." );
    df_add_line( "S6_START_MAXIS", "maxis", "The ash by the lava still holds what it drank. Something must gather it up." );
    df_add_line( "S6_START_MAXIS", "rich", "A ROCK, Samuel! He wants you to carry a rock! Oh, I could not make this up!" );
    df_add_line( "S6_HINT_1_RICH", "rich", "Where the lightning struck, Samuel: a rock. Emptier than it looks. Fetch it.", 1 );
    df_add_line( "S6_HINT_1_MAXIS", "maxis", "A rock fell with the lightning. It is a vessel, and empty. Pick it up." );
    df_add_line( "S6_HINT_2_RICH", "rich", "Hold the rock at the sparking block on the bridge. Empty the Jet Gun into it.", 1 );
    df_add_line( "S6_HINT_2_MAXIS", "maxis", "Hold the rock in the lava by each spent grave. Let it drink. Then the table." );
    df_add_line( "D6_HINT", "rich", "Someone built a big vacuum cleaner, Samuel. Aim it at the sparking block." );
    df_add_line( "D6_HINT", "maxis", "The rock is empty. Each burnt grave still holds what you fed it. Draw it out." );
    df_add_line( "D6_HINT_RICH", "rich", "Someone built a big vacuum cleaner, Samuel. Aim it at the sparking block.", 1 );
    df_add_line( "D6_HINT_MAXIS", "maxis", "The rock is empty. Each burnt grave still holds what you fed it. Draw it out." );
    // S6_NOJETGUN_*: the orb is taken and no player carries a Jet Gun (event hint, audit section 4)
    df_add_line( "S6_NOJETGUN_RICH", "rich", "No engine? Build one, Samuel! Four parts in the fog. Jet with an afterburner!", 1 );
    df_add_line( "S6_NOJETGUN_MAXIS", "maxis", "You do not need his engine. Fire draws the ash. Stand in the burning ground." );
    // S6_DRAW_LAVA_MAXIS: the carrier stands in lava beside a scorched grave spot and the draw is running (audit #4)
    df_add_line( "S6_DRAW_LAVA_MAXIS", "maxis", "It drinks. Stay in the fire until the rock is full. It costs skin, not time." );
    df_add_line( "D6_DONE", "maxis", "The charge is home. The Spire will not keep it quietly. Someone must wake it." );
    df_add_line( "D6_DONE", "rich", "The charge is home! He thinks it is his. Wake the obelisk and prove him wrong." );
    df_add_line( "D6_DONE_RICH", "rich", "The charge is home! He thinks it is his. Wake the obelisk and prove him wrong." );
    df_add_line( "D6_DONE_MAXIS", "maxis", "The charge is home. The Spire will not keep it quietly. Someone must wake it." );
}

// Act 3 Step 7 "The Line Holds" (shared, sided keys). Mechanics (df_act3_hold.gsc): hold the socket 3 s,
// the orb leaves it and wanders under the tower for hold_time seconds while zombies hunt it and lightning
// charges it; a player must stay within 700 of the tower; failure bursts the orb, its charge waits at
// the socket to be picked up and placed again (df_s6_restart). D7_START fires when the wave begins.
df_dialogue_act3_hold()
{
    df_add_line( "S7_START_RICH", "rich", "All in place, Samuel! The obelisk is itching. One touch and the fun begins.", 1 );
    df_add_line( "S7_START_RICH", "maxis", "When he starts this, stay close to what you placed. He will not protect it." );
    df_add_line( "S7_START_MAXIS", "maxis", "Everything is in place. The Spire waits for a hand. When it wakes, stay near." );
    df_add_line( "S7_START_MAXIS", "rich", "Go on, touch it. What is the worst that could happen? Do not answer that." );
    df_add_line( "S7_HINT_1", "maxis", "The Spire is primed and idle. It wants a hand on the socket. It wants it now." );
    df_add_line( "S7_HINT_1", "rich", "The socket, Samuel. Hold it, and do not wander off afterwards." );
    df_add_line( "S7_HINT_1_RICH", "rich", "The socket, Samuel. Hold it, and do not wander off afterwards.", 1 );
    df_add_line( "S7_HINT_1_MAXIS", "maxis", "The Spire is primed and idle. It wants a hand on the socket. It wants it now." );
    df_add_line( "S7_HINT_2_RICH", "rich", "Hold the socket. The rock walks, they chase it, you kill them. Stay close.", 1 );
    df_add_line( "S7_HINT_2_MAXIS", "maxis", "Hold the socket. Then guard the rock under the Spire until its charge holds." );
    df_add_line( "D7_START", "maxis", "Now they will come. Hold the line. Keep them off the rock." );
    df_add_line( "D7_START", "rich", "Let my pretties come! Keep them off my rock, Samuel!" );
    df_add_line( "D7_START_RICH", "rich", "Let my pretties come! Keep them off my rock, Samuel!" );
    df_add_line( "D7_START_MAXIS", "maxis", "Now they will come. Hold the line. Keep them off the rock." );
    // S7_AVOGADRO_RICH: Avogadro joins the wave on the Richtofen path, knife him (audit section 8b)
    df_add_line( "S7_AVOGADRO_RICH", "rich", "He is back for my rock! Three good stabs, Samuel, and he leaves you a present.", 1 );
    // failure: the charged orb waits at the socket, pickable (Step 6 contract, df_s6_restart)
    df_add_line( "D7_FAIL", "rich", "NEIN! The charge fell back to the socket. Pick it up, Samuel, place it again!" );
    df_add_line( "D7_FAIL", "maxis", "The rock burst. Its charge waits at the socket. Take it and set it again." );
    df_add_line( "D7_FAIL_RICH", "rich", "NEIN! The charge fell back to the socket. Pick it up, Samuel, place it again!", 1 );
    df_add_line( "D7_FAIL_MAXIS", "maxis", "The rock burst. Its charge waits at the socket. Take it and set it again." );
    df_add_line( "D7_DONE", "maxis", "It held. The frequency is ready. It wants silence, and a hand." );
    df_add_line( "D7_DONE", "rich", "It held! Oh, it HELD! Do you feel it, Samuel? The obelisk is about to sing." );
    df_add_line( "D7_DONE_RICH", "rich", "It held! Oh, it HELD! Do you feel it, Samuel? The obelisk is about to sing." );
    df_add_line( "D7_DONE_MAXIS", "maxis", "It held. The frequency is ready. It wants silence, and a hand." );
}

// Finale (df_finale.gsc): hold the socket 5 s with the side's power state (Richtofen on, Maxis off);
// wrong state once per 20 s; then three lines. FIN_START is the intro when the step becomes available.
// Co-op (dialogue audit v2 1.5): FIN_WRONG_POWER_RICH and FIN_RICH_1..3 are broadcast, so a non-Samuel
// player holding the table learns why the finale refuses and sees the ending too.
df_dialogue_finale()
{
    df_add_line( "FIN_START_RICH", "rich", "It is ready. Lights on, hand on the socket, and it is mine. Ours. Mine.", 1 );
    df_add_line( "FIN_START_MAXIS", "maxis", "It is ready. Kill the power, hold the socket, and let it speak for itself." );
    df_add_line( "FIN_WRONG_POWER_RICH", "rich", "Lights on, Samuel. LIGHTS. ON.", 1 );
    df_add_line( "FIN_WRONG_POWER_MAXIS", "maxis", "An active grid disrupts my signal. Shut down the power." );
    df_add_line( "FIN_RICH_1", "rich", "JA! You did it, Samuel! The obelisk sings for me! Oh, what a glorious day!", 1 );
    df_add_line( "FIN_RICH_2", "rich", "Did you hear that, Maxis? One spire down! Soon the flesh covers the Earth!", 1 );
    df_add_line( "FIN_RICH_3", "rich", "You are a hero, Samuel! You saved the Earth... for me to play with! Hahaha!", 1 );
    df_add_line( "FIN_RICH_3", "maxis", "This Spire is his. For now. There are other sites." );
    df_add_line( "FIN_MAXIS_1", "maxis", "Yes! The Spire is online. This one answers to me, and he cannot touch it." );
    df_add_line( "FIN_MAXIS_2", "maxis", "Hear me, worm: your noise bought you nothing. This Spire is no longer yours." );
    df_add_line( "FIN_MAXIS_3", "maxis", "Your help has been invaluable. The other sites must be likewise empowered." );
    df_add_line( "FIN_MAXIS_3", "rich", "Silence! He gave you SILENCE, Samuel! Enjoy it. I am still in your head." );
    // A2_REWARD_*: the side reward given early when Act 2 completes, Max Ammo at the table (audit #7)
    df_add_line( "A2_REWARD_RICH", "rich", "A gift, Samuel! Bullets, and my toys no longer need his little windmills.", 1 );
    df_add_line( "A2_REWARD_MAXIS", "maxis", "A small return. The lamp doors open for you. The fog keeps its distance." );
    // FIN_WORLD_*: the permanent world change after the spectacle (audit #8)
    df_add_line( "FIN_WORLD_RICH", "rich", "The lamps, Samuel! All sparking, all mine. The creature? The obelisk ate him!", 1 );
    df_add_line( "FIN_WORLD_MAXIS", "maxis", "The lamps answer to me now. The fog is quiet. The little ones will not return." );
    // residue lines, once, right after FIN_WORLD_* (df_finale df_fin_keepsake): the card / the stone stay on the table
    df_add_line( "ITEM_KEEPSAKE_RICH", "rich", "Keep the card, Samuel. A souvenir of the day you made me very happy.", 1 );
    df_add_line( "ITEM_KEEPSAKE_MAXIS", "maxis", "The stone stays on the table. Let it remind him whose Spire this is." );
}

// Old stall hint keys (spec section 7, README, `!df say`) point at the HINT_1 rung of their step.
// D6_HINT is not an alias: it stays the orb pickup cue (df_act3_vacuum.gsc).
df_dialogue_aliases()
{
    df_add_alias( "D1_HINT", "S1_HINT_1" );
    df_add_alias( "D2_HINT", "S2_HINT_1" );
    df_add_alias( "D3_HINT", "S3_HINT_1" );
    df_add_alias( "D4_HINT", "S4_HINT_1" );
    df_add_alias( "R1_HINT", "R1_HINT_1" );
    df_add_alias( "R2_HINT", "R2_HINT_1" );
    df_add_alias( "M1_HINT", "M1_HINT_1" );
    df_add_alias( "M2_HINT", "M2_HINT_1" );
    df_add_alias( "D5_HINT", "S5_HINT_1" );
    df_add_alias( "D7_HINT", "S7_HINT_1" );
}

// Append one line to a key and register the key's lowercase alias (T6 has tolower but no toupper).
// broadcast (optional, 1): a Richtofen line every player should see (df_show_line). coop (optional, 1):
// only with two or more players (df_say drops it in solo).
df_add_line( key, speaker, text, broadcast, coop )
{
    if ( !isdefined( level.df_lines[key] ) )
    {
        level.df_lines[key] = [];

        if ( !isdefined( level.df_lines_lower ) )
            level.df_lines_lower = [];

        level.df_lines_lower[tolower( key )] = key;
    }

    e = spawnstruct();
    e.speaker = speaker;
    e.text = text;

    if ( is_true( broadcast ) )
        e.broadcast = 1;

    if ( is_true( coop ) )
        e.coop = 1;

    level.df_lines[key][level.df_lines[key].size] = e;
}

// Makes `alias` show the same lines as `key` (array copy of the same structs) with its own lowercase alias.
df_add_alias( alias, key )
{
    if ( !isdefined( level.df_lines[key] ) )
        return;

    level.df_lines[alias] = level.df_lines[key];
    level.df_lines_lower[tolower( alias )] = alias;
}
