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
//   Richtofen is heard by the Stuhlinger player only, as in vanilla (df_show_line): no tag can widen that. A line
//   tagged coop = 1 (4th arg) is
//   dropped in solo by df_say ("one lamp each").
//   Event keys added by the audit pass (2026-09-08), listed with their step: R1_RICH_CHAMBER, M1_EVENT,
//   S6_NOJETGUN_RICH / _MAXIS,
//   S7_AVOGADRO_RICH, A2_REWARD_RICH / _MAXIS, FIN_WORLD_RICH / _MAXIS, ITEM_RECEIVER, ITEM_BATTERY_RICH,
//   ITEM_SPOOL_RICH, ITEM_EMBER_MAXIS, ITEM_HAND_MAXIS (tools/audit_A.md says who calls each; renamed from
//   ITEM_SKULL_MAXIS, owner 2026-09-25), and
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
    df_add_line( "D0_INTRO", "maxis", "The Spire still broadcasts on a dead frequency. Whoever tunes it owns it." );
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
// hidden, the lines are the only teacher); Step 2 radio (Diner garage), mast (Farm barn) and coil (Depot) built on
// the bus roof; Step 3 the relay rides ONE full stop with power on while zombies chew on it
// (df_a1_stops_needed); Step 4 the relay goes to the table under the tower, the power state locks the side.
df_dialogue_act1()
{
    // Step 1 - Dead Air (the chimney pipes)
    df_add_line( "S1_START", "maxis", "The Depot is not dead. Something in the mud around it still keeps time." );
    df_add_line( "S1_START", "rich", "A light blinks past the fence, Samuel. Something out there can still count." );
    df_add_line( "S1_HINT_1", "maxis", "Four pipes in the mud. Each counts itself. The far light counts them in order." );
    df_add_line( "S1_HINT_2", "maxis", "Press the pipes in the far light's order. A pipe that blinks three is three." );
    df_add_line( "S1_HINT_2", "rich", "Count the flashes, Samuel. Not a symphony, a headcount. Press them in order." );
    df_add_line( "D1_MAXIS", "maxis", "Yes. The pattern holds. He will hear this too. A pity." );
    df_add_line( "D1_RICH", "rich", "Four rusty pipes in the mud! THAT is his grand antenna? Oh, Maxis. Hahaha!" );
    // ITEM_RECEIVER: the solved pipes call the coil down by a strike near the Depot, the relay's third part
    df_add_line( "ITEM_RECEIVER", "maxis", "The sky struck near the Depot. It left a coil of wire. The relay will need it." );

    // Step 2 - Salvage
    df_add_line( "S2_START", "maxis", "A voice needs a body. Three pieces of one; two wait along the road." );
    df_add_line( "S2_START", "rich", "A scavenger hunt! Mind the barn, Samuel. Something up in the loft bites." );
    df_add_line( "S2_HINT_1", "maxis", "A garage and a barn, past the fog. The sky gave you the third." );
    df_add_line( "S2_HINT_2", "maxis", "Garage radio, barn mast, the coil. Build the relay on the bus roof." );
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
    df_add_line( "D3_FAIL", "rich", "Lost it! Chewed, zapped or abandoned? If it broke, the parts are on the roof." );
    df_add_line( "D3_FAIL", "maxis", "The stop is lost. If it broke, rebuild it on the roof. The road comes again." );
    df_add_line( "D3_DONE", "maxis", "It has found the signal. Bring it to the source." );
    df_add_line( "D3_DONE", "rich", "The obelisk, Samuel! It always comes back to the obelisk. Oh, I love it!" );

    // Step 4 - Plug In (the relay lifts off the roof; the table under the tower; power state = side)
    df_add_line( "S4_START", "maxis", "Take it where the signal was born. In the dark, if you value my voice." );
    df_add_line( "S4_START", "rich", "Off the roof, Samuel, lights burning! To the obelisk, that tower in the corn." );
    df_add_line( "S4_HINT_1", "maxis", "Off the roof now. A table waits under the Spire, the tower in the corn." );
    df_add_line( "S4_HINT_2", "maxis", "Set the relay on the table under the Spire. Power on serves him. Off, me." );
    df_add_line( "S4_HINT_2", "rich", "Relay. Table. Obelisk. And leave the lights ON, Samuel, or he wins." );
    // S4_CHOOSE: the relay leaves the roof, the side choice is announced (df_act1 Step 4, owner 2026-09-23)
    df_add_line( "S4_CHOOSE", "maxis", "Choose now. The Spire keeps the first voice it hears. Off for me." );
    df_add_line( "S4_CHOOSE", "rich", "Lights ON when you plug it, Samuel. The obelisk remembers who fed it." );
    df_add_line( "D4_RICH_LOCK", "rich", "Lights on! Oh, Samuel, you chose the winning side. Maxis, are you weeping?" );
    df_add_line( "D4_RICH_LOCK", "maxis", "So you choose the noise over the silence. We shall see." );
    df_add_line( "D4_MAXIS_LOCK", "maxis", "Darkness. Good. He is loud, but he cannot follow where nothing hums." );
    df_add_line( "D4_MAXIS_LOCK", "rich", "Turning off the power. Very mature. Enjoy the fog, Samuel." );
}

// Act 2R (Richtofen only; Maxis heckles once per step). Mechanics (df_act2_rich.gsc): R1 four power
// boxes in the Farm barn spark in a growing order (Simon), repeat it, a key card strikes onto the barn wall,
// insert it at the table, the storm drags the creature to the tower, defeat him within 900 of it (vanilla:
// knife only) inside capture_time s, failure: ONE bus battery refills all four boxes; R2 three set lamp
// posts (one always nearest the tower) each swallow a quota of kills (12 solo) within 450 units, a full lamp
// glows steady and a Galvaknuckles punch on the post drops a wire spool that goes to the table (ITEM_SPOOL_RICH).
// Story: the creature's energies were Maxis's plan (canon), Richtofen steals them (R1_MAXIS_TAUNT is a loss);
// the stolen storm sits in the sparking block on the bridge (the S6 node) until the orb carries it to the obelisk.
df_dialogue_act2_rich()
{
    // R1 - Summon the Storm
    df_add_line( "R1_START", "rich", "Now we need a storm. Storms live in barns, Samuel. Trust me, I have checked." );
    df_add_line( "R1_HINT_1", "rich", "Four boxes in the Farm barn. They spark in an order. Sparks are a language." );
    df_add_line( "R1_HINT_2", "rich", "Watch the boxes spark, Samuel. Touch them in that order. It grows. Keep up." );
    df_add_line( "R1_RICH_CARD", "rich", "A card in the barn wall, Samuel! Put it on the table under the obelisk!" );
    df_add_line( "R1_RICH_SUMMON", "rich", "There he is! Keep him under the obelisk. Knife, Samuel. Bullets only tickle." );
    // R1_RICH_FAIL covers both: defeated away from the tower, or the capture window ran out (df_scaled
    // capture_time, 240 solo / 300 co-op)
    df_add_line( "R1_RICH_FAIL", "rich", "Gone! Wrong place, or too slow. The boxes sulk now. Feed them, Samuel." );
    // R1_RICH_CHAMBER: Avogadro still sleeps in the power chamber, no capture timer runs (audit section 5)
    df_add_line( "R1_RICH_CHAMBER", "rich", "He sleeps where the power is born, Samuel. Wake him. Poke him if you must." );
    df_add_line( "R1_RICH_CAPTURED", "rich", "Wunderbar! His storm ran home to the plant. It sulks in a box on the bridge!" );
    // ITEM_BATTERY_RICH: one battery from the bus dash refills all four boxes (audit section 9)
    df_add_line( "ITEM_BATTERY_RICH", "rich", "The boxes are empty. The bus keeps a battery on its dash. It charges all four." );
    // R1_RICH_NOSTORM: no Avogadro on the map, R1 completes on the card alone (df_act2_rich, owner 2026-09-23)
    df_add_line( "R1_RICH_NOSTORM", "rich", "Nothing came, Samuel. The storm is sulking. The card will have to do." );
    df_add_line( "R1_MAXIS_TAUNT", "maxis", "Nein! The creature's energies were to be mine. You have set the design back." );

    // R2 - 115 on the Line
    df_add_line( "R2_START", "rich", "A storm in a box is nothing without wires, Samuel. Look for sparks in the fog." );
    df_add_line( "R2_HINT_1", "rich", "Some lamp posts spit sparks now. They are hungry, and they only eat one thing." );
    df_add_line( "R2_HINT_2", "rich", "Kill beneath a sparking lamp until it glows steady. Galvaknuckles on the post." );
    df_add_line( "R2_RICH_FULL", "rich", "Full! Now punch the post, Samuel. The Galvaknuckles, not your little knife." );
    df_add_line( "R2_RICH_NOFISTS", "rich", "Bare steel? No. Electricity wants electricity. Galvaknuckles, Samuel." );
    // R2_POWER_RICH: the grid is off while R2 runs, the lamps leak (df_act2_rich, owner 2026-09-23)
    df_add_line( "R2_POWER_RICH", "rich", "Lights out, Samuel! A dark grid and my storm leaks away. Power. ON." );
    df_add_line( "R2_DONE", "rich", "Every lamp fat with 115! Lines on a map, Samuel. Oh, it is beautiful!" );
    df_add_line( "R2_DONE", "maxis", "He is building a cage. Do you not see it? Listen to the fog." );
    // ITEM_SPOOL_RICH: a wire spool drops at a filled lamp, three build the array on the relay (audit section 9)
    df_add_line( "ITEM_SPOOL_RICH", "rich", "A spool of wire, Samuel! Take it to the table under the obelisk. Wunderbar!" );
}

// Act 2M (Maxis only; Richtofen heckles once per step). Mechanics (df_act2_maxis.gsc): M1 a denizen
// riding a player is carried within 300 of the table and opens a hole into the Nacht bunker; the denizen
// kills (df_scaled cold_room_kills 6/9/12/15 within cold_room_time) leave the hand, the hole waits
// until someone walks in; M2 the fire hand (the power switch lever's hand) waits on the table, any of the four
// graves in Town (owner 2026-09-23) lights it, zombies killed within 250 of a lit grave (df_scaled
// brazier_burns 4/5/6/7, burning or not) make it vanish, all four charge the fire hand.
df_dialogue_act2_maxis()
{
    // M1 - The Cold Room
    df_add_line( "M1_START", "maxis", "The signal needs a key. The fog is full of small, angry keys." );
    df_add_line( "M1_HINT_1", "maxis", "The little ones want the relay. Let one cling to you and walk it to the Spire." );
    df_add_line( "M1_HINT_2", "maxis", "Carry a little one to the table. Clear the hole. Set the hand on the table." );
    // M1_EVENT: the first denizen latches onto a player after M1 opens (event hint, audit #6)
    df_add_line( "M1_EVENT", "maxis", "Do not kill it. Let it ride. Carry it to the table under the Spire. Quickly!" );
    df_add_line( "M1_PORTAL", "maxis", "A door to the woods behind the hunter's cabin. One steps in, all of you go." );
    df_add_line( "M1_PORTAL", "rich", "Do not go in there, Samuel. Actually, do. I could use the laugh." );
    df_add_line( "M1_MAXIS_FAIL", "maxis", "Too slow. The cold does not wait. Bring another one to the table." );
    df_add_line( "M1_DONE", "maxis", "It is keyed. The signal knows us now. The hand still wants fire." );
    // ITEM_HAND_MAXIS (renamed from ITEM_SKULL_MAXIS, owner 2026-09-25): the frozen hand (still the
    // zombie_skull model) appears after the denizen kills; the take cue, called from df_m1_skull_appear
    // instead of the table placement (dialogue audit v2 #8; M1_DONE covers the placement)
    df_add_line( "ITEM_HAND_MAXIS", "maxis", "The cold left a hand behind. The hand of his switch. Set it on the table." );

    // M2 - Fire and Ash
    df_add_line( "M2_START", "maxis", "Four graves stand beyond the edge of Town. Shoot one and it wakes." );
    df_add_line( "M2_HINT_1", "maxis", "The graves are outside Town. Shoot one, then kill the dead where you stood." );
    df_add_line( "M2_HINT_2", "maxis", "A woken grave wants the dead killed where you shot it. Be quick, it cools." );
    df_add_line( "M2_MAXIS_BRAZIER", "maxis", "Good. That grave is spent. Its fire runs to the hand." );
    // ITEM_EMBER_MAXIS: the fire hand taken from the table; a grave lights it, then the lit graves want
    // kills beside them, burning or not (dialogue audit v2, M2: the take touches the ladder, so this line
    // carries the second half)
    df_add_line( "ITEM_EMBER_MAXIS", "maxis", "Take the hand to the graves in Town. Light it at each and feed it the dead." );
    df_add_line( "M2_EMBER_CHARGED", "maxis", "All four are ash. Their fire runs home to the hand on the table." );
    df_add_line( "M2_EMBER_LOST", "maxis", "The hand fell with you. It waits on the table again." );
    df_add_line( "M2_KNUCKLES_MAXIS", "maxis", "Nein! His current will not touch my graves. Any weapon but his fists." );
    // M2_POWER_MAXIS: the grid was ON at the end of a round and ONE lit grave forgets its kills
    // (df_act2_maxis df_m2_power_penalty; dialogue audit v2 section 3)
    df_add_line( "M2_POWER_MAXIS", "maxis", "The grid is live. A grave forgets its dead while it hums. Cut it." );
    // M2_GRAVE_COLD: a lit grave was not filled in time (df_m2_grave_timer, owner 2026-09-23)
    df_add_line( "M2_GRAVE_COLD", "maxis", "Too slow. That grave went cold. Light it again and feed it from the start." );
    df_add_line( "M2_DONE", "maxis", "The ash carries the message. Now the fog will answer it." );
    df_add_line( "M2_DONE", "rich", "Bonfires. He has reduced you to bonfires, Samuel." );
}

// Act 3 Step 5, by side (owner 2026-09-25; df_act3_sweep.gsc dispatches).
// RICHTOFEN "Blackout" (df_act3_blackout.gsc): Maxis flips three switches under the obelisk OFF; one F press
// flips one back ON (refused while the grid is off, BO_NOPOWER_RICH) and sends a wave at it; at each end of
// round Maxis knocks one ON switch OFF again (BO_OFF_MAXIS). All three ON wins (D5_DONE_RICH).
// MAXIS "Lights Out" (df_act3_sweep.gsc): three lamps hum with Richtofen's power; a lamp goes dark only when a
// zombie dies to a CLAYMORE (Farm wall buy) at its base, any other kill there does nothing (LO_NOTHAND_MAXIS,
// once); each dark lamp says LO_DARK_MAXIS; at each end of round Richtofen relights one (LO_RELIGHT). All three
// dark wins (D5_DONE_MAXIS). The coop START lines say "one switch / lamp each".
df_dialogue_act3_sweep()
{
    // Blackout (Richtofen)
    df_add_line( "S5_START_RICH", "rich", "Maxis cut three switches under the obelisk, Samuel! Flip them all ON!" );
    df_add_line( "S5_START_RICH", "rich", "Split up, Samuel. One switch each, and keep the lights burning.", 1 );
    df_add_line( "S5_START_RICH", "maxis", "His switches fall dark. Let them stay dark. Let him feel the fog." );
    // Lights Out (Maxis)
    df_add_line( "S5_START_MAXIS", "maxis", "He feeds three lamps in the fog. His voice hums in them. Put them out." );
    df_add_line( "S5_START_MAXIS", "maxis", "You are several. One lamp each, and let the dead do the work.", 1 );
    df_add_line( "S5_START_MAXIS", "rich", "My lamps, Samuel! He wants them dark? Over my... well, over yours." );
    // plain S5_HINT_1 (!df say before the fork): the sided texts word for word, no own string
    df_add_line( "S5_HINT_1", "maxis", "Claymores are sold at the Farm. Plant one at the foot of a humming lamp." );
    df_add_line( "S5_HINT_1", "rich", "Three switches under the obelisk, Samuel. One press each, lights on." );
    df_add_line( "S5_HINT_1_RICH", "rich", "Three switches under the obelisk, Samuel. One press each, lights on." );
    df_add_line( "S5_HINT_1_MAXIS", "maxis", "Claymores are sold at the Farm. Plant one at the foot of a humming lamp." );
    df_add_line( "S5_HINT_2_RICH", "rich", "Power ON, then press each dark switch under the obelisk. All three at once!" );
    df_add_line( "S5_HINT_2_MAXIS", "maxis", "A claymore at the post, then let the dead walk into it. Three lamps dark." );
    df_add_line( "LO_NOTHAND_MAXIS", "maxis", "Not your hand. His light must fall at the step of the dead. A claymore." );
    df_add_line( "LO_DARK_MAXIS", "maxis", "One lamp is dark. His voice is thinner already." );
    df_add_line( "LO_RELIGHT", "maxis", "He has relit one of them. Put it out again." );
    df_add_line( "LO_RELIGHT", "rich", "Back ON, my lovely lamp! Try harder, Maxis!" );
    df_add_line( "D5_DONE", "rich", "All three ON! The obelisk drinks, Samuel. Now my card wants to let go!" );
    df_add_line( "D5_DONE", "maxis", "Three lamps dark. His voice is gone. Something small must carry the charge." );
    df_add_line( "D5_DONE_RICH", "rich", "All three ON! The obelisk drinks, Samuel. Now my card wants to let go!" );
    df_add_line( "D5_DONE_MAXIS", "maxis", "Three lamps dark. His voice is gone. Something small must carry the charge." );
    df_add_line( "BO_OFF_MAXIS", "maxis", "Another of his switches falls. The dark is patient." );
    df_add_line( "BO_OFF_MAXIS", "rich", "One fell again? Maxis sulks every round. Flip it back ON, schnell!" );
    df_add_line( "BO_NOPOWER_RICH", "rich", "Power ON first, Samuel! A switch on a dead grid is a toy." );
}

// Act 3 Step 6 "Vacuum" (shared, sided keys). Mechanics (df_act3_vacuum.gsc): the rock lands at one of three
// random spots (the Diner, Town or the power plant: the HINT_1 lines name all three). Richtofen: the key card on
// the table discharges and its storm falls as the rock (S6_CARD_RICH); Maxis: the fire hand bursts and its fire
// falls as the rock (S6_EMBER_MAXIS). A player carries it to the ONE charged node of the side and fires
// the Jet Gun into it until the gun overheats: Richtofen the sparking block on the power station bridge, Maxis
// (owner 2026-09-23) the fireplace of the hunter's cabin in the woods; full, it goes to table slot 2. D6_HINT is
// the cue on every pickup of a not yet full orb (df_s6_orb_take). S6_NOJETGUN_<SIDE>: R2 / M2 completion and the
// pickup, when no player carries a Jet Gun.
df_dialogue_act3_vacuum()
{
    df_add_line( "S6_START_RICH", "rich", "That crackle at the power plant, Samuel? My storm wants out. Find it a jar." );
    df_add_line( "S6_START_RICH", "maxis", "He has you carrying his batteries now. Follow his light, if you must." );
    df_add_line( "S6_START_MAXIS", "maxis", "The hunter's cabin in the woods keeps a fire. The rock must drink from it." );
    // S6_EMBER_MAXIS: the fire hand on the table bursts and its fire flies off to where the rock will fall (df_s6_ember_burst)
    df_add_line( "S6_EMBER_MAXIS", "maxis", "The hand gives its fire to the sky. It falls far away, as a rock. Find it." );
    // S6_CARD_RICH: the key card on the table discharges, its storm falls as the rock (df_act3_vacuum, owner 2026-09-23)
    df_add_line( "S6_CARD_RICH", "rich", "The card calls the storm down! It fell as a rock. Diner, Town or plant!" );
    df_add_line( "S6_START_MAXIS", "rich", "A ROCK, Samuel! He wants you to carry a rock! Oh, I could not make this up!" );
    df_add_line( "S6_HINT_1_RICH", "rich", "My storm fell as a rock, Samuel. The Diner, Town or the plant. Fetch it!" );
    df_add_line( "S6_HINT_1_MAXIS", "maxis", "The hand's fire fell as a rock: the Diner, Town or the plant. Find it." );
    df_add_line( "S6_HINT_2_RICH", "rich", "Take the rock to the sparking block on the plant bridge. Empty a Jet Gun!" );
    df_add_line( "S6_HINT_2_MAXIS", "maxis", "Carry the rock to the hunter's cabin fireplace. Fire a full Jet Gun into it." );
    df_add_line( "D6_HINT", "rich", "Someone built a big vacuum cleaner, Samuel. Aim it at the sparking block." );
    df_add_line( "D6_HINT", "maxis", "The rock is empty. Fire a Jet Gun into the fireplace of the hunter's cabin." );
    df_add_line( "D6_HINT_RICH", "rich", "Someone built a big vacuum cleaner, Samuel. Aim it at the sparking block." );
    df_add_line( "D6_HINT_MAXIS", "maxis", "The rock is empty. Fire a Jet Gun into the fireplace of the hunter's cabin." );
    // S6_NOJETGUN_*: R2 / M2 completion or the orb pickup, and no player carries a Jet Gun (event hint, audit section 4)
    df_add_line( "S6_NOJETGUN_RICH", "rich", "No engine? Build one, Samuel! Four parts in the fog. Jet with an afterburner!" );
    df_add_line( "S6_NOJETGUN_MAXIS", "maxis", "The rock needs a Jet Gun. Build one: its four parts lie in the fog." );
    // D6_FULL_*: the Jet Gun overheats, the rock is full, now to the relay (df_act3_vacuum, owner 2026-09-23)
    df_add_line( "D6_FULL_RICH", "rich", "Full! Now bring my rock to the table under the obelisk, Samuel. Schnell!" );
    df_add_line( "D6_FULL_MAXIS", "maxis", "It is full. Carry the rock to the table under the Spire. Set it in the relay." );
    df_add_line( "D6_DONE", "maxis", "The charge is home. The Spire will not keep it quietly. Someone must wake it." );
    df_add_line( "D6_DONE", "rich", "The charge is home! He thinks it is his. Wake the obelisk and prove him wrong." );
    df_add_line( "D6_DONE_RICH", "rich", "The charge is home! He thinks it is his. Wake the obelisk and prove him wrong." );
    df_add_line( "D6_DONE_MAXIS", "maxis", "The charge is home. The Spire will not keep it quietly. Someone must wake it." );
}

// Act 3 Step 7 "The Line Holds" (shared, sided keys). Mechanics (df_act3_hold.gsc): hold the relay 1.5 s,
// the orb leaves it and wanders under the tower for hold_time seconds while zombies hunt it and lightning
// charges it; a player must stay within 700 of the tower; failure bursts the orb, the charged rock waits in
// front of the table to be picked up and placed again (df_s6_restart). D7_START fires when the wave begins.
df_dialogue_act3_hold()
{
    df_add_line( "S7_START_RICH", "rich", "All in place, Samuel! The obelisk is itching. One touch and the fun begins." );
    df_add_line( "S7_START_RICH", "maxis", "When he starts this, stay close to what you placed. He will not protect it." );
    df_add_line( "S7_START_MAXIS", "maxis", "Everything is in place. The Spire waits for a hand. When it wakes, stay near." );
    df_add_line( "S7_START_MAXIS", "rich", "Go on, touch it. What is the worst that could happen? Do not answer that." );
    df_add_line( "S7_HINT_1", "maxis", "The Spire is primed and idle. It wants a hand on the relay. It wants it now." );
    df_add_line( "S7_HINT_1", "rich", "The relay on the table, Samuel. Hold it, and do not wander off afterwards." );
    df_add_line( "S7_HINT_1_RICH", "rich", "The relay on the table, Samuel. Hold it, and do not wander off afterwards." );
    df_add_line( "S7_HINT_1_MAXIS", "maxis", "The Spire is primed and idle. It wants a hand on the relay. It wants it now." );
    df_add_line( "S7_HINT_2_RICH", "rich", "Hold the relay. The rock walks, they chase it, you kill them. Stay close." );
    df_add_line( "S7_HINT_2_MAXIS", "maxis", "Hold the relay. Then guard the rock under the Spire until its charge holds." );
    df_add_line( "D7_START", "maxis", "Now they will come. Hold the line. Keep them off the rock." );
    df_add_line( "D7_START", "rich", "Even my pretties want a bite of it! Discipline them, Samuel!" );
    df_add_line( "D7_START_RICH", "rich", "Even my pretties want a bite of it! Discipline them, Samuel!" );
    df_add_line( "D7_START_MAXIS", "maxis", "Now they will come. Hold the line. Keep them off the rock." );
    // owner 2026-09-25: S7_DENIZEN_MAXIS removed (no caller: Step 7 no longer releases denizens on the
    // Maxis path, df_act3_hold df_s7_side_pressure)
    // D7_ZONE_*: every player left the tower zone during the hold (df_act3_hold, owner 2026-09-23)
    df_add_line( "D7_ZONE_RICH", "rich", "Come BACK, Samuel! Walk away from the obelisk and my rock dies alone." );
    df_add_line( "D7_ZONE_MAXIS", "maxis", "You are leaving the Spire. Return to it now, or the charge is lost." );
    // S7_AVOGADRO_RICH: Avogadro joins the wave on the Richtofen path, knife him (audit section 8b)
    df_add_line( "S7_AVOGADRO_RICH", "rich", "He is back for my rock! Three good stabs, Samuel, and he leaves you a present." );
    // failure: the charged orb waits in front of the table, pickable (Step 6 contract, df_s6_restart)
    df_add_line( "D7_FAIL", "rich", "NEIN! My rock fell by the table. Pick it up, Samuel, place it again!" );
    df_add_line( "D7_FAIL", "maxis", "The rock burst. It waits in front of the table. Take it and set it again." );
    df_add_line( "D7_FAIL_RICH", "rich", "NEIN! My rock fell by the table. Pick it up, Samuel, place it again!" );
    df_add_line( "D7_FAIL_MAXIS", "maxis", "The rock burst. It waits in front of the table. Take it and set it again." );
    df_add_line( "D7_DONE", "maxis", "It held. The frequency is ready. It wants silence, and a hand." );
    df_add_line( "D7_DONE", "rich", "It held! Oh, it HELD! Do you feel it, Samuel? The obelisk is about to sing." );
    df_add_line( "D7_DONE_RICH", "rich", "It held! Oh, it HELD! Do you feel it, Samuel? The obelisk is about to sing." );
    df_add_line( "D7_DONE_MAXIS", "maxis", "It held. The frequency is ready. It wants silence, and a hand." );
}

// Finale (df_finale.gsc): hold the relay 5 s with the side's power state (Richtofen on, Maxis off);
// wrong state once per 20 s; then three lines. FIN_START is the intro when the step becomes available.
// Co-op: a non-Samuel player at the table gets Maxis and the deny buzz; Richtofen stays Samuel's (vanilla rule).
df_dialogue_finale()
{
    df_add_line( "FIN_START_RICH", "rich", "It is ready. Lights on, hand on the relay, and it is mine. Ours. Mine." );
    df_add_line( "FIN_START_MAXIS", "maxis", "It is ready. Kill the power, hold the relay, and let it speak for itself." );
    df_add_line( "FIN_WRONG_POWER_RICH", "rich", "Lights on, Samuel. LIGHTS. ON." );
    df_add_line( "FIN_WRONG_POWER_MAXIS", "maxis", "An active grid disrupts my signal. Shut down the power." );
    df_add_line( "FIN_RICH_1", "rich", "JA! You did it, Samuel! The obelisk sings for me! Oh, what a glorious day!" );
    df_add_line( "FIN_RICH_2", "rich", "Did you hear that, Maxis? One obelisk down! Soon the flesh covers the Earth!" );
    df_add_line( "FIN_RICH_3", "rich", "You are a hero, Samuel! You saved the Earth... for me to play with! Hahaha!" );
    df_add_line( "FIN_RICH_3", "maxis", "This Spire is his. For now. There are other sites." );
    df_add_line( "FIN_MAXIS_1", "maxis", "The Spire is online. This one answers to me, and he cannot touch it." );
    df_add_line( "FIN_MAXIS_2", "maxis", "Richtofen. Your noise bought you nothing. This Spire is no longer yours." );
    df_add_line( "FIN_MAXIS_3", "maxis", "Your help has been invaluable. The other sites must be likewise empowered." );
    df_add_line( "FIN_MAXIS_3", "rich", "Silence! He gave you SILENCE, Samuel! Enjoy it. I am still in your head." );
    // A2_REWARD_*: the side reward given early when Act 2 completes, Max Ammo at the table (audit #7)
    df_add_line( "A2_REWARD_RICH", "rich", "A gift, Samuel! Bullets, and my toys no longer need his little windmills." );
    df_add_line( "A2_REWARD_MAXIS", "maxis", "A small return. The little ones' doors open for you, without a turbine." );
    // A2_JETGUN_*: Act 2 completes, the Jet Gun is announced ahead of Step 6 (df_steps, owner 2026-09-23)
    df_add_line( "A2_JETGUN_RICH", "rich", "Before the end you will need a Jet Gun, Samuel. Four parts lie in the fog." );
    df_add_line( "A2_JETGUN_MAXIS", "maxis", "Before the end you will need a Jet Gun. Its four parts lie in the fog." );
    // FIN_WORLD_*: the permanent world change after the spectacle (audit #8)
    df_add_line( "FIN_WORLD_RICH", "rich", "The lamps, Samuel! All sparking, all mine. And Avogadro? The obelisk ate him!" );
    df_add_line( "FIN_WORLD_MAXIS", "maxis", "The lamps answer to me now. The fog is quiet. The little ones will not return." );
    // residue lines, once, right after FIN_WORLD_* (df_finale df_fin_keepsake): the card / the hand stay on the table
    df_add_line( "ITEM_KEEPSAKE_RICH", "rich", "Keep the card, Samuel. A souvenir of the day you made me very happy." );
    df_add_line( "ITEM_KEEPSAKE_MAXIS", "maxis", "The hand burnt away for this. Let the Spire remember whose fire it holds." );
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
// coop (optional, 1):
// only with two or more players (df_say drops it in solo).
df_add_line( key, speaker, text, coop )
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
