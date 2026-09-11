// Dead Frequency - Act 1 "Static" (shared).
//   Step 1 "Dead Air":       ONE Depot wall phone plays four tones in order; four dead SCREENS (df_model "tv" =
//                            the CRT tube p6_zm_buildable_etrap_tvtube, 22 tall) outside must be tapped in that
//                            order (spec 5, Step 1). Solved, the phone drops its RECEIVER: the relay's 3rd part.
//   Step 2 "Salvage":        two parts in the fog (battery, lattice) + the receiver, built into a relay on the bus roof.
//   Step 3 "Ride the Line":  the relay survives ONE full bus stop with power on while zombies chew it.
//   Step 4 "Plug In":        carry the locked relay to the table under the tower; power state locks the side.
//
// V2 pass (V2-act1, 2026-09-09, tools/audit_art.md S1-S4 + top 10 #7 #10, tools/audit_steps_v2.md #7,
// tools/audit_dialogue_v2.md; report tools/audit_V2act1.md). Uniform cue grammar through the core helpers:
// df_step_focus (glint of the AVAILABLE cue), df_cue_tick (progress), df_cue_deny (wrong input), df_cue_fail
// (progress lost), df_vox_once (vanilla Maxis / Richtofen lines once per game), df_complete (STEP DONE sting).
//   - S1: focus = the phone; no extra sting at the solve; receiver drop = tick + spark (no PaP ding); wrong
//     screen = deny (was the EMP thump); screen fx on the tube's top edge (df_a1_screen_z); vox_maxi_tv_distress_0
//     at the phone when the step opens.
//   - S2: THREE parts (steps audit #7: the cornfield-edge DF_PART_C is cut; receiver is idx 2); notices n/3;
//     vox_maxi_build_complete_0 at the relay once built; mast gap = df_model_offset( "relay_top" ) (world: +7).
//   - S3: sweep = controlled df_side_burst_fx() replays (no huge spark loop), a second layer at 400 hp, glint on
//     the relay until the first sweep, LOCKED = fx_zmb_tranzit_power_pulse replays (art #10: the lightning orb is
//     the tower's), fails through df_cue_fail, vox_maxi_near_corn_0 when the locked relay enters the cornfield.
//   - S4: the plugged relay wears kind "relay_mast" (when the registry has it) instead of the flat lattice;
//     vox_zmba_sidequest_power_on_0 (rich) / vox_maxi_power_off_0 (maxis) once at the lock; portal refusal = deny.
//
// Polish pass 2026-09-08 (act1): models via df_model(), puzzle prompts via df_prompt_puzzle(), single-press
// pickups via df_press_use(), small electric bursts (elec_sm / elec_md on a tag_origin deleted after 0.6 s),
// verified sounds, clearer console messages, `!df fire a1_*` hooks. Mechanics untouched.
// Polish pass 2 (act1b, owner feedback): the roof build is the vanilla build hold (builder hands, no bar,
// df_a1_build_hold), optional stacked "relay_top" piece (df_a1_relay_top_attach), a1_build hook.
// Polish pass 3 (table, owner 2026-09-08): the TABLE under the tower (df_model "table" at DF_TABLE, still
// level.df_socket) replaces the wall breaker panel; the plugged relay stands on its slot 0, the key card (R1)
// and the orb (Steps 6/7) take slots 1 and 2. See tools/polish_table.md.
// Audit pass (B-act1, 2026-09-08, tools/audit_design.md + owner rule "everything physical exists from boot"):
//   - table and the fog parts spawn at boot (df_a1_boot_items); Step 2 / Step 4 only arm them;
//   - Step 1 phone rings every 45 s until first listened; solving drops the RECEIVER (ITEM_RECEIVER);
//   - Step 2 needs every part (df_a1_parts_total, notices n/total); a destroyed relay drops them on the roof;
//   - Step 3 is ONE stop, swing 60, relay hp 800 (audit #9, section 3);
//   - Step 4 table glows blue (power on) / orange (off) while a carrier is within 400 (audit section 4).
//   See tools/audit_B.md.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_audition;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;
#include scripts\zm\zm_transit\df_scav;

// Registers the four Act 1 steps (df_steps::df_register_step), the debug hooks and the lamp portal guard,
// and puts the boot-time world objects in place (df_boot runs df_coords_init before this, df_main.gsc).
df_act1_init()
{
    df_register_step( "step1", ::df_step1_run, undefined );
    df_register_step( "step2", ::df_step2_run, ::df_step2_setup );
    df_register_step( "step3", ::df_step3_run, ::df_step3_setup );
    df_register_step( "step4", ::df_step4_run, ::df_step4_setup );

    df_a1_boot_items();
    df_a1_focus_boot();
    level thread df_a1_debug_hooks();

    // lamp portals refuse a player carrying the relay (Step 4) or an orb (Step 6)
    replaceFunc( maps\mp\zm_transit_ai_screecher::portal_use, ::df_portal_use );
}

// AVAILABLE cue glint points (df_steps::df_step_focus, art audit change 2) for the objects that exist from boot:
// Step 1 = the wall phone (the ring and the glint agree), Step 4 = the table under the tower (core's glint lives
// until the relay is lifted off the roof = df_touch; from then on df_step4_socket's own marker takes over, so
// the table is never double-lit). Step 2 registers none (every part already glints); Step 3's object rides the
// bus, so it gets its own linked glint instead (df_a1_relay_glint_set). Registered at init: the glint shows as
// soon as the step is available and a focus is known.
df_a1_focus_boot()
{
    // Step 1's object is the far signal light since 2026-09-11 (the phone has no role)
    c = df_coord( "DF_SIGNAL" );

    if ( !isdefined( c ) )
        c = df_coord( "DF_PHONE_1" );

    if ( isdefined( c ) )
        df_step_focus( "step1", c.origin + ( 0, 0, 40 ) );

    c = df_coord( "DF_SOCKET" );

    if ( isdefined( c ) )
        df_step_focus( "step4", c.origin + ( 0, 0, 40 ) );
}

// Owner rule (2026-09-08): everything physical exists from game start so players can look at it, pick it
// up and get hints before any step is done. The screens and the phone belong to Step 1 (boot already); this
// adds the TABLE under the tower (Step 4 only arms it) and the two fog parts (Step 2 only arms the roof
// build). The receiver is the one thing that appears later: the phone drops it when Step 1 is solved.
df_a1_boot_items()
{
    df_step4_socket_spawn();
    level thread df_a1_table_follow();
    df_a1_parts_boot();
}

// The table is spawned at boot, so a live `!df move / ang / lift DF_TABLE` (df_coords live tuning, which
// only moves the anchor and its preview) must drag the model too: poll the anchor twice a second.
df_a1_table_follow()
{
    level endon( "end_game" );

    while ( true )
    {
        wait 0.5;
        c = df_coord( "DF_TABLE" );

        if ( !isdefined( c ) || !isdefined( level.df_socket ) )
            continue;

        if ( c.origin == level.df_socket.origin && c.angles == level.df_socket.angles )
            continue;

        level.df_socket.origin = c.origin;
        level.df_socket.angles = c.angles;
        df_a1_table_clips_spawn( c );
        df_debug_print( "DF: table follows DF_TABLE to " + int( c.origin[0] ) + " " + int( c.origin[1] ) + " " + int( c.origin[2] ) );
    }
}

// =========================================================================================
// STEP 1 - Dead Air
// =========================================================================================

// Height of the screen fx over the "tv" anchor: the chimney pipe (pb_pole_telephone_bulb, 9 x 8 x 9, base pivot;
// owner 2026-09-09: back from the CRT tube) stands on its anchor, so glow, flicker and sparks sit just over its
// top. df_model_top_z( "tv" ) + 1 stays right if the model changes again.
df_a1_screen_z()
{
    return df_model_top_z( "tv" ) + 1;
}

// Spawns the four dead screens (df_model "tv") and the one phone spot, runs the poll until the order is solved.
// The canon distress recording (vox_maxi_tv_distress_0, zm_transit_sq.gsc:1098) plays once at the phone when the
// step opens (df_vox_once): the phone literally carries Maxis.
// Tones: TranZit ships no boat, foghorn, water or musical alias (every name of its three sound banks checked,
// tools/assets/soundbank), so the four are its shortest distinct signals, see level.df_tv_tones below.
// zmb_bus_horn_warn (the klaxon) is gone from the whole step, cue included.
df_step1_run()
{
    level endon( "end_game" );

    // Blinks (owner 2026-09-11): no tones any more. Each pipe blinks its own number, 1 to 4, dealt at RANDOM every
    // game (ids); the far signal light flashes those numbers in the order to press (df_step1_signal_loop).
    ids = [];

    for ( i = 0; i < 4; i++ )
        ids[i] = i + 1;

    ids = array_randomize( ids );

    order = [];

    for ( i = 0; i < 4; i++ )
        order[i] = i;

    level.df_tv_order = array_randomize( order );
    level.df_tv_progress = 0;
    level.df_phones_heard = 0;
    level.df_tv_lockout = 0;
    level.df_tvs = [];

    for ( i = 0; i < 4; i++ )
    {
        c = df_coord( "DF_TV_" + ( i + 1 ) );
        tv = spawnstruct();
        tv.kind = "tv";
        tv.index = i;
        tv.on = 0;
        tv.origin = c.origin;
        tv.angles = c.angles;
        tv.model = spawn( "script_model", c.origin );
        tv.model setmodel( df_model( "tv" ) );
        tv.model.angles = c.angles;
        // a dead screen on the ground: a permanent small glow on its top edge plus a spark every few seconds
        // (owner 2026-09-08: without a marker nobody finds them)
        // no steady glow (owner pick 2026-09-11): the locator is the blue spark fired once per blink cycle (df_a1_pipe_blink)
        tv.idle = undefined;
        tv.count = ids[i];
        tv.flasher = df_a1_flasher_make( df_a1_fx_pipe_flash(), c.origin + ( 0, 0, df_a1_screen_z() ) );
        level thread df_a1_pipe_blink( tv );
        level.df_tvs[i] = tv;
        df_debug_print( "DF: screen " + ( i + 1 ) + " at " + int( c.origin[0] ) + " " + int( c.origin[1] ) + " " + int( c.origin[2] ) + ", blinks " + tv.count );
    }

    // the wall phone has no role since 2026-09-11 (owner): the far signal light carries the order
    level.df_phones = [];

    level thread df_step1_poll();
    level thread df_step1_signal_loop();
    level thread df_step1_signal_hum(); // owner 2026-09-11: the hum at the far light (zmb_power_on_loop)
    level thread df_step1_skip_cleanup();
    df_debug_print( "DF: step1 order (pipe indexes) " + level.df_tv_order[0] + level.df_tv_order[1] + level.df_tv_order[2] + level.df_tv_order[3]
        + " = flashes " + level.df_tvs[level.df_tv_order[0]].count + " " + level.df_tvs[level.df_tv_order[1]].count + " "
        + level.df_tvs[level.df_tv_order[2]].count + " " + level.df_tvs[level.df_tv_order[3]].count );

    if ( !is_true( level.df_goto_busy ) )
    {
        c = df_coord( "DF_SIGNAL" );

        if ( !isdefined( c ) )
            c = df_coord( "DF_PHONE_1" );

        df_vox_once( "vox_maxi_tv_distress_0", c.origin + ( 0, 0, 40 ) );
    }

    level waittill( "df_step1_solved" );

    level notify( "df_step1_cleanup" );
    df_step1_flashers_stop();
    df_step1_lights_off(); // owner 2026-09-11: after the step the pipes stand dark, no light, no spark
    df_step1_hide_prompts();

    level thread df_step1_dashboard_cue();
    df_say( "D1_MAXIS" );
    df_say( "D1_RICH" );
    df_a1_receiver_drop();
    df_complete( "step1" );
}

// Step 1 solved (or skipped): the phone gives up its RECEIVER (audit section 9, key ITEM_RECEIVER): the
// relay's last part, lying on the floor at the phone spot (DF_PHONE_1 is the player's feet when it was
// recorded), taken like the fog parts. Model kind "receiver" (df_coords registry), df_model "part_a" until it
// exists (df_a1_part_model). Cue (art audit S1.4): a PROGRESS TICK (df_cue_tick) + the blue one-shot; the PaP
// ding is gone (zmb_perks_packa_ready = "the phone rings", nothing else). Step 2 registers no df_step_focus:
// every part, this one included, already wears the same glint (core: AVAILABLE sound only). Idempotent.
df_a1_receiver_drop()
{
    if ( df_is_done( "step2" ) || ( isdefined( level.df_parts ) && isdefined( level.df_parts[df_a1_receiver_idx()] ) ) )
        return;

    df_a1_parts_boot();
    c = df_coord( "DF_COIL_DROP" ); // its own anchor since 2026-09-11 (default = the phone spot)

    if ( !isdefined( c ) )
        c = df_coord( "DF_PHONE_1" );

    pos = df_ground( c.origin ) + ( 0, 0, 1 );

    // owner 2026-09-11: the coil arrives by LIGHTNING so the spot is seen from the whole Depot (same strike as the
    // Step 6 orb: descend fx on the ground, the tower lightning orb, the Avogadro spawn thunder, a short quake).
    // Nothing during a goto (skipped steps fabricate silently).
    if ( !is_true( level.df_goto_busy ) )
    {
        df_item_arrival( pos ); // the shared arrival of every quest item (df_systems)
        wait 0.4;
    }

    df_a1_part_place( df_a1_receiver_idx(), pos, c.angles[1], "coil" );
    df_debug_print( "DF: the phone dropped the receiver (part " + df_a1_parts_total() + ") at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) );

    // no cue while `!df goto` fabricates skipped steps (same rule as df_steps::df_step_intro)
    if ( is_true( level.df_goto_busy ) )
        return;

    df_snd_near( "zmb_switch_flip", pos, 900 ); // owner pick 2026-09-11: the coil drops = switch flip
    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", pos + ( 0, 0, 20 ) );
    df_fx_burst( "elec_md", pos + ( 0, 0, 20 ), 1.0 ); // the one-shot spark alone was not seen (owner 2026-09-09)
    df_say( "ITEM_RECEIVER" );
}

// Removes the puzzle prompt of every player (Step 1 owns all puzzle prompts while it runs).
df_step1_hide_prompts()
{
    foreach ( player in getplayers() )
    {
        player df_a1_puzzle_prompt( 0, undefined );
        player df_act1_prompt( 0, undefined, "pipe" );
    }
}

// "!df goto" past this step: remove the screens (and their light) entirely; the receiver still drops (Step 2
// needs it; a goto past Step 2 deletes it again in df_step2_setup).
df_step1_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_step1_cleanup" );
    level waittill( "df_skip_step1" );

    df_step1_flashers_stop();
    df_step1_hide_prompts();

    // owner 2026-09-11: the pipes STAY (the world keeps them), only their lights go
    df_step1_lights_off();

    df_a1_receiver_drop();
}

// One poll for all screens and phones: the nearest unlit object within 80 units gets the puzzle prompt
// (df_prompt_puzzle, hidden with df_hints 0); a single press (df_press_use) uses it.
df_step1_poll()
{
    level endon( "end_game" );
    level endon( "df_step1_cleanup" );
    level endon( "df_skip_step1" );

    while ( true )
    {
        wait 0.05;

        foreach ( player in getplayers() )
        {
            target = undefined;

            if ( is_player_valid( player ) )
                target = df_step1_target( player );

            if ( !isdefined( target ) )
            {
                player df_a1_puzzle_prompt( 0, undefined );
                player df_act1_prompt( 0, undefined, "pipe" );
                continue;
            }

            if ( target.kind == "phone" )
                player df_a1_puzzle_prompt( 1, "Press [{+activate}] to listen" );
            else
                player df_act1_prompt( 1, "Press [{+activate}] to kick the pipe", "pipe" ); // audit v3 #10: a mechanic prompt, always shown

            if ( !player df_press_use() )
                continue;

            if ( target.kind == "phone" )
            {
                if ( !is_true( player.df_at_phone ) )
                    player thread df_phone_listen( target.index );

                continue;
            }

            level thread df_tv_press( target, player );
        }
    }
}

// Nearest screen that is still off, or phone, within 80 units of the player; undefined if none.
df_step1_target( player )
{
    best = undefined;
    best_d = 80 * 80;

    foreach ( tv in level.df_tvs )
    {
        if ( tv.on )
            continue;

        d = distancesquared( player.origin, tv.origin );

        if ( d < best_d )
        {
            best = tv;
            best_d = d;
        }
    }

    foreach ( phone in level.df_phones )
    {
        d = distancesquared( player.origin, phone.origin );

        if ( d < best_d )
        {
            best = phone;
            best_d = d;
        }
    }

    return best;
}

// One use on the phone: handset knock, then ALL FOUR tones 2 s apart (silence between every two notes), to that
// player only.
df_phone_listen( phone_index )
{
    self endon( "disconnect" );
    level endon( "df_step1_cleanup" );
    level endon( "df_skip_step1" );

    self.df_at_phone = 1;
    df_touch( "step1" );

    if ( !is_true( level.df_phones_heard ) )
        level.df_phones_heard = 1;

    df_debug_print( "DF: phone plays the whole order: " + level.df_tv_order[0] + " " + level.df_tv_order[1] + " " + level.df_tv_order[2] + " " + level.df_tv_order[3] );
    // handset off the hook: a knock (zmb_perks_packa_knuckle_0, 0.6 s, 2D); zmb_switch_flip is tone 1 now
    df_a1_tone_to( self, "evt_perk_deny" ); // owner pick 2026-09-11: handset = the perk bottle deny click
    wait 0.8;

    // longest tone 1.4 s, so 2 s apart leaves silence between notes (owner 2026-09-09: "they seem all together")
    for ( t = 0; t < 4; t++ )
    {
        df_a1_tone_to( self, level.df_tv_tones[level.df_tv_order[t]] );
        wait 2.0;
    }

    self.df_at_phone = 0;
}

// A screen was tapped by `who`: its tone and a short glow, then the order check.
// Wrong screen: WRONG INPUT cue to the presser (df_cue_deny = zmb_perks_packa_deny; the EMP thump means
// "progress lost" elsewhere, art audit S1.5), everything off, the phone rings.
// Other screens ignore presses meanwhile, or a correct press would light one the reset then kills.
df_tv_press( tv, who )
{
    level endon( "end_game" );
    level endon( "df_step1_cleanup" );
    level endon( "df_skip_step1" );

    if ( tv.on || is_true( level.df_tv_lockout ) )
        return;

    // no tone since 2026-09-11 (blinks): the pipe's own light burst is the tap feedback
    // glow on the screen's top edge while its tone plays
    df_fx_once( "switch_sparks", tv.origin + ( 0, 0, df_a1_screen_z() ) ); // owner pick 2026-09-11: the kick spark
    expected = level.df_tv_order[level.df_tv_progress];
    df_debug_print( "DF: screen " + ( tv.index + 1 ) + " used, expected screen " + ( expected + 1 ) + ", progress " + level.df_tv_progress );

    if ( tv.index == expected )
    {
        df_touch( "step1" ); // audit v3 #2: only a CORRECT kick counts as progress for the hint ladder
        df_tv_light( tv, 1 );
        // no extra sound on a correct pipe (owner 2026-09-11): its tone and its light are the feedback; the only
        // sting is the STEP DONE one when all four are lit
        level.df_tv_progress++;

        if ( level.df_tv_progress >= 4 )
        {
            // the STEP DONE sting is df_complete's (art audit change 1): nothing extra here
            df_debug_print( "DF: step1 solved, all four screens on" );
            level notify( "df_step1_solved" );
        }

        return;
    }

    level.df_tv_lockout = 1;

    if ( isdefined( who ) )
        df_cue_deny( who );

    wait 0.8;
    df_step1_reset_tvs();
    level.df_tv_lockout = 0;
}

// Screen on: fluorescent flicker on its top edge (fx alias zm_transit_fx.gsc:48); the sound is the PROGRESS TICK
// df_tv_press threads 1.5 s later (zmb_turn_on was here: a 14 s power-up rumble, four of them overlapping).
// Off: light removed.
df_tv_light( tv, on )
{
    tv.on = on;

    if ( on )
    {
        if ( !isdefined( tv.fx ) )
        {
            tv.fx = df_fx_loop( "fx_zmb_tranzit_light_bulb_xsm", tv.origin + ( 0, 0, df_a1_screen_z() ) ); // owner pick 2026-09-11: lit = steady glow
            level thread df_fx_keepalive( tv.fx ); // stays lit for the rest of the game (the client dropped it after a while)
        }

        return;
    }

    df_fx_stop( tv.fx );
    tv.fx = undefined;
}

// Wrong screen: everything off, the phone rings once, same order kept.
df_step1_reset_tvs()
{
    foreach ( tv in level.df_tvs )
        df_tv_light( tv, 0 );

    level.df_tv_progress = 0;
    df_debug_print( "DF: wrong pipe, all pipes back to blinking (the signal keeps flashing the order)" );
}

// Success cue: power pulse on the bus dashboard for 5 s (fx alias zm_transit_fx.gsc:117). The bus klaxon is
// deliberately absent: the owner had it removed from the whole step (2026-09-08).
df_step1_dashboard_cue()
{
    level endon( "end_game" );

    if ( !isdefined( level.the_bus ) )
        return;

    bus = level.the_bus;
    pos = bus.origin + anglestoforward( bus.angles ) * 190 + ( 0, 0, 70 );
    fx = df_fx_loop( "fx_zmb_tranzit_spark_int_runner", pos );

    if ( isdefined( fx ) )
        fx linkto( bus );

    playsoundatposition( "zmb_power_rise_start", bus.origin ); // 1 s power whine, 700 range (zmb_turn_on = 14 s rumble)
    wait 5;
    df_fx_stop( fx );
}

// =========================================================================================
// STEP 2 - Salvage
// =========================================================================================

// The parts already lie in the world (df_a1_parts_boot); this arms the roof build site and ends when the
// relay is built. Three parts: two from the fog plus the receiver the phone dropped at the end of Step 1.
// Built: Maxis's canon "build complete" line once at the relay (vox_maxi_build_complete_0, zm_transit.gsc:3326),
// then D2_DONE and the uniform STEP DONE sting (df_complete).
df_step2_run()
{
    level endon( "end_game" );

    df_a1_parts_boot();
    level thread df_step2_roof_site();

    level waittill( "df_relay_built" );

    if ( isdefined( level.df_relay ) )
        df_vox_once( "vox_maxi_build_complete_0", level.df_relay.origin + ( 0, 0, 30 ) );

    df_say( "D2_DONE" );
    df_complete( "step2" );
}

// Parts the relay needs: 2 fog parts + the receiver (steps audit v2 #7 CUT: was 4; the cornfield-edge part
// DF_PART_C / "chassis" is gone, Act 1 was 15-25 min of fetching before its first own idea).
df_a1_parts_total()
{
    return 3;
}

// Index of the receiver in level.df_parts (the last part; the fog parts are 0 .. total - 2).
df_a1_receiver_idx()
{
    return df_a1_parts_total() - 1;
}

// Boot (owner rule): the two fog parts (battery at the cabin, lattice in the tunnel), their glints and
// triggers exist from game start; a part taken before Step 2 opens still counts (the team inventory is
// level-wide). The skip listener starts here for the same reason. Idempotent.
df_a1_parts_boot()
{
    if ( isdefined( level.df_parts ) )
        return;

    df_coords_refresh_dynamic();
    level.df_parts = [];
    level.df_parts_collected = 0;
    df_step2_spawn_part( 0, "DF_PART_A", "radio" );
    df_step2_spawn_part( 1, "DF_PART_B", "mast" );
    level thread df_step2_skip_cleanup();
}

// Item kind of part idx: part_a / part_b / receiver (df_scav notice icon, df_coords model registry).
df_a1_part_kind( idx )
{
    if ( idx == 0 )
        return "part_a";

    if ( idx == 1 )
        return "part_b";

    return "receiver";
}

// Model kind actually spawned for part idx: the item kind, or "part_a" while the registry has no
// "receiver" model yet (df_model would print a warning and return an invisible tag_origin).
df_a1_part_model( idx )
{
    kind = df_a1_part_kind( idx );

    if ( isdefined( level.df_models ) && isdefined( level.df_models[kind] ) )
        return kind;

    return "part_a";
}

// One part at its anchor (df_coord key): see df_a1_part_place.
df_step2_spawn_part( idx, key, name )
{
    c = df_coord( key );
    df_a1_part_place( idx, c.origin, c.angles[1], name );
}

// One static part in the world at pos facing yaw: model (df_model), key glint above it (fx alias
// zm_transit_fx.gsc:105) and a use trigger (a static part can use a real trigger; the spec's HINT_NOICON
// trigger, df_systems::df_spawn_use_trigger).
df_a1_part_place( idx, pos, yaw, name )
{
    part = spawnstruct();
    part.idx = idx;
    part.name = name;
    part.model = spawn( "script_model", pos + ( 0, 0, df_model_rest_z( df_a1_part_model( idx ) ) ) ); // centre-pivot parts (the coil box) rest ON the ground
    part.model setmodel( df_model( df_a1_part_model( idx ) ) );
    part.model.angles = df_model_angles( df_a1_part_model( idx ), yaw );
    part.fx = df_fx_loop( "fx_zmb_tranzit_light_glow", pos + ( 0, 0, 24 ) );
    part.trig = df_spawn_use_trigger( pos, 56, 72, "Press [{+activate}] to take the " + name );
    level.df_parts[idx] = part;
    level thread df_part_watch( part );
    df_debug_print( "DF: " + name + " at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) );
}

// Static part: one press of use on its trigger takes it (vanilla parts work the same, zm_transit_buildables.gsc:249).
df_part_watch( part )
{
    level endon( "end_game" );
    level endon( "df_skip_step2" );

    while ( true )
    {
        part.trig waittill( "trigger", who );

        if ( !isplayer( who ) || !is_player_valid( who ) )
            continue;

        // audit v3 #2: taking a part is not the unknown of Step 2 (the roof is), so it does not touch the ladder;
        // the touch is the build attempt on the roof
        df_a1_part_taken( part, who, "taken" );
        return;
    }
}

// A part joins the team inventory: world objects gone, icon for everyone,
// vanilla pickup sound (zmb_buildable_pickup, zm_transit_buildables.gsc:249). who may be undefined (debug hook).
df_a1_part_taken( part, who, verb )
{
    pos = undefined;

    if ( isdefined( part.model ) )
    {
        pos = part.model.origin;
        part.model delete();
    }

    if ( isdefined( part.trig ) )
        part.trig delete();

    df_fx_stop( part.fx );
    part.fx = undefined;

    level.df_parts_collected++;
    df_scav_carry_set( "parts", level.df_parts_collected, df_a1_parts_total(), who, df_a1_part_kind( part.idx ) );

    if ( isdefined( who ) )
        who playsound( "zmb_buildable_pickup" );
    else if ( isdefined( pos ) )
        playsoundatposition( "zmb_buildable_pickup", pos );

    level notify( "df_parts_changed" );
    df_debug_print( "DF: " + part.name + " " + verb + " (" + level.df_parts_collected + "/" + df_a1_parts_total() + ")" );
}

// Build site: the bus roof. A script-spawned use trigger cannot be linked to the moving bus, so we poll
// the bus's own roof trigger (level.roof_trig, kept on the bus by vanilla) and draw our own prompt.
// Building is the vanilla 3 s build hold (df_a1_build_hold_on: builder hands, loop sound, dust, no bar);
// the df_prompt "Hold to build" is shown only while nobody is building.
df_step2_roof_site()
{
    level endon( "end_game" );
    level endon( "df_skip_step2" );
    level endon( "df_skip_step3" ); // also started by a broken relay in Step 3

    while ( !isdefined( level.the_bus ) || !isdefined( level.roof_trig ) )
        wait 1;

    while ( true )
    {
        wait 0.1;

        // nothing to poll until the last part (the receiver included) is in hand
        if ( level.df_parts_collected < df_a1_parts_total() )
        {
            level waittill( "df_parts_changed" );
            continue;
        }

        foreach ( player in getplayers() )
        {
            on_roof = is_player_valid( player ) && player istouching( level.roof_trig );
            player df_act1_prompt( on_roof, "Hold [{+activate}] to build the relay", "roof_build" );

            if ( !on_roof || !player usebuttonpressed() )
                continue;

            df_touch( "step2" );
            player df_act1_prompt( 0, undefined, "roof_build" );

            if ( !player df_a1_build_hold_on( level.roof_trig, undefined, 260, 3 ) )
                continue;

            foreach ( p in getplayers() )
                p df_act1_prompt( 0, undefined, "roof_build" );

            df_step2_build_relay();
            level notify( "df_relay_built" );
            return;
        }
    }
}

// The relay: an upright antenna (df_model "relay", + optional "relay_top", df_a1_relay_spawn) on the roof
// surface under the roof trigger, riding the bus. Cues: assemble dust (building_dust, _zm_buildables.gsc:28),
// one blue burst (zm_transit_fx.gsc:123), a PROGRESS TICK (df_cue_tick: zmb_buildable_piece_add + small burst);
// the build-complete sound is played on the builder by the build hold, the STEP DONE sting by df_complete.
df_step2_build_relay()
{
    bus = level.the_bus;
    top = level.roof_trig.origin;
    pos = top - ( 0, 0, 40 );
    trace = bullettrace( top + ( 0, 0, 40 ), top - ( 0, 0, 120 ), 0, undefined );

    if ( isdefined( trace["position"] ) && trace["fraction"] < 1 )
        pos = trace["position"];

    relay = df_a1_relay_spawn( pos, bus.angles[1] ); // upright, front along the bus
    relay linkto( bus );
    level.df_relay = relay;

    level.df_relay_fx = undefined;
    level.df_relay_hp = 800; // audit section 3 (was 1000): with one stop the chewing must be able to matter
    level.df_relay_horned = 0;
    level.df_relay_sick = 0;
    df_relay_idle_fx();
    level thread df_relay_attract_start();

    if ( !is_true( level.df_relay_power_watching ) )
        level thread df_relay_power_watch();

    df_fx_once( "building_dust", pos + ( 0, 0, 10 ) );
    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", pos + ( 0, 0, 20 ) );

    if ( !is_true( level.df_goto_busy ) )
        df_cue_tick( pos );

    df_scav_carry_clear( "parts" );
    df_debug_print( "DF: relay built on the bus roof at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) + ", hp " + level.df_relay_hp );
}

// "!df goto" past this step: fabricate the relay without collecting parts; whatever parts still lie in
// the world (boot parts, the receiver dropped by the Step 1 skip) go.
df_step2_setup()
{
    while ( !isdefined( level.the_bus ) || !isdefined( level.roof_trig ) )
        wait 0.05;

    df_a1_parts_delete();
    df_scav_carry_clear( "parts" );

    if ( !isdefined( level.df_relay ) )
        df_step2_build_relay();
}

// "!df goto" past this step: parts, glints, triggers, prompts and icons go (started at boot with the parts).
df_step2_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_relay_built" );
    level waittill( "df_skip_step2" );

    df_a1_parts_delete();

    foreach ( player in getplayers() )
        player df_act1_prompt( 0, undefined, "roof_build" );

    df_scav_carry_clear( "parts" );
}

// Deletes every world object of the current parts (static or on the roof).
df_a1_parts_delete()
{
    if ( !isdefined( level.df_parts ) )
        return;

    foreach ( part in level.df_parts )
    {
        if ( isdefined( part.trig ) )
            part.trig delete();

        if ( isdefined( part.model ) )
            part.model delete();

        df_fx_stop( part.fx );
        part.fx = undefined;
    }
}

// =========================================================================================
// STEP 3 - Ride the Line (power ON required for a stop to count)
// =========================================================================================
// Owner design (2026-09-07), audit #9 (2026-09-08): the relay must survive ONE full stop (the spec's
// number; two stops were 4-6 min of sitting on a bus). It must be on the roof before the bus departs,
// power must be on and someone must ride. Zombies within reach chew on it (60 hp per swing, 800 hp; the
// spec's roof cap is not applied). Destroyed: it breaks back into its three parts on the roof; pick them
// up and rebuild, the stop count restarts. The completed stop sends lightning to the main tower.

// Stops the relay must survive (df_a1_stops_needed keeps the count in one place).
df_a1_stops_needed()
{
    return 1;
}

// Waits for bus departures (level.the_bus "departing", zm_transit_bus.gsc:503) and runs a sweep per
// valid departure until the stop is counted. AVAILABLE marker (art audit S3.2): the relay rides the bus, so
// instead of a fixed df_step_focus point it wears the key glint itself until the first sweep starts.
df_step3_run()
{
    level endon( "end_game" );

    level.df_relay_locked = 0;
    level.df_segments_done = 0;
    level thread df_step3_nopower_watch();
    level thread df_step3_skip_cleanup();

    // the relay implies a bus, but "!df goto step3" can get here before it exists
    while ( !isdefined( level.the_bus ) )
        wait 1;

    df_a1_relay_glint_set( 1 );

    while ( !is_true( level.df_relay_locked ) )
    {
        level.the_bus waittill( "departing" );

        if ( !isdefined( level.df_relay ) )
        {
            df_debug_print( "DF: bus left " + df_a1_stop_name() + " without a relay, no sweep" );
            continue;
        }

        if ( !flag( "power_on" ) )
        {
            df_debug_print( "DF: bus left " + df_a1_stop_name() + " without power, no sweep" );
            continue;
        }

        if ( df_players_on_bus().size == 0 )
        {
            df_debug_print( "DF: bus left " + df_a1_stop_name() + " empty, no sweep" );
            continue;
        }

        if ( is_true( level.df_sweep_active ) )
        {
            df_debug_print( "DF: sweep already running, ignoring departure" );
            continue;
        }

        df_step3_segment();
    }

    df_say( "D3_DONE" );
    df_complete( "step3" );
}

// Name of the stop the bus last reached / just left (level.busschedule.destinations, zm_transit_bus.gsc:579,
// bus.destinationindex set at :292). "?" when the schedule is not there yet.
df_a1_stop_name()
{
    bus = level.the_bus;

    if ( !isdefined( bus ) || !isdefined( bus.destinationindex ) || !isdefined( level.busschedule ) || !isdefined( level.busschedule.destinations ) )
        return "?";

    dest = level.busschedule.destinations[bus.destinationindex];

    if ( !isdefined( dest ) || !isdefined( dest.name ) )
        return "?";

    return dest.name;
}

// "!df goto" past this step: relay exists and is locked
df_step3_setup()
{
    df_step2_setup();
    level.df_relay_locked = 1;
    level.df_segments_done = df_a1_stops_needed();
    df_relay_fx_set( "locked" );
}

// "!df goto" past this step: a sweep in progress (hum, watchers) and the parts of a broken relay
// riding the roof must not survive it. The runner's own thread is ended by the same notify.
df_step3_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_step3_done" );
    level waittill( "df_skip_step3" );

    level notify( "df_step3_segment_end" );
    level.df_sweep_active = 0;
    df_step3_hum_stop();
    df_a1_relay_glint_set( 0 );
    df_a1_parts_delete();

    foreach ( player in getplayers() )
        player df_prompt( 0, undefined );
}

// Key glint (zm_transit_fx.gsc:105) riding the relay while Step 3 waits for its first sweep: on = spawn it
// linked to the relay (no-op without a relay or on a locked one), off = delete it. Kept in level.df_relay_glint.
df_a1_relay_glint_set( on )
{
    df_fx_stop( level.df_relay_glint );
    level.df_relay_glint = undefined;

    if ( !on || !isdefined( level.df_relay ) || is_true( level.df_relay_locked ) )
        return;

    level.df_relay_glint = df_fx_loop( "fx_zmb_tranzit_light_glow", level.df_relay.origin + ( 0, 0, 34 ) );

    if ( isdefined( level.df_relay_glint ) )
        level.df_relay_glint linkto( level.df_relay );
}

// Stops and deletes the sweep hum (script_origin with zmb_meteor_loop).
df_step3_hum_stop()
{
    if ( isdefined( level.df_step3_hum ) )
    {
        level.df_step3_hum stoploopsound();
        level.df_step3_hum delete();
    }

    level.df_step3_hum = undefined;
}

// Valid players riding WITH THE RELAY: inside the bus (player.isonbus, zm_transit_bus.gsc), on its roof trigger, or
// within a bus-sized radius of the relay itself (260 flat, 200 up: the roof, the ladder, the back bumper), which moves
// with the bus (owner 2026-09-11: an empty bus completing a stop must not count).
df_players_on_bus()
{
    out = [];
    relay = undefined;

    if ( isdefined( level.df_relay ) )
        relay = level.df_relay.origin;

    foreach ( p in getplayers() )
    {
        if ( !is_player_valid( p ) )
            continue;

        if ( is_true( p.isonbus ) || ( isdefined( level.roof_trig ) && p istouching( level.roof_trig ) ) )
        {
            out[out.size] = p;
            continue;
        }

        if ( isdefined( relay ) && abs( p.origin[2] - relay[2] ) < 200 && distance2dsquared( p.origin, relay ) < 260 * 260 )
            out[out.size] = p;
    }

    return out;
}

// Richtofen complains once per round when someone rides with the relay but no power.
df_step3_nopower_watch()
{
    level endon( "end_game" );
    level endon( "df_step3_done" );
    level endon( "df_skip_step3" );

    while ( true )
    {
        wait 1;

        if ( flag( "power_on" ) || !isdefined( level.df_relay ) || df_players_on_bus().size == 0 )
            continue;

        if ( isdefined( level.df_nopower_round ) && level.df_nopower_round == level.round_number )
            continue;

        level.df_nopower_round = level.round_number;
        df_say( "D3_RICH_NOPOWER" );
    }
}

// One sweep: controlled electric bursts (df_relay_fx_set "sweep") and a hum (zmb_meteor_loop, zm_transit.gsc:3349)
// on the relay until an outcome arrives: "arrived" (stop counted), "destroyed", "emp", "empty". Lost sweeps
// go through the FAIL cue (df_cue_fail: zmb_bus_emp_shutdown to all + the one-shot where it was lost).
df_step3_segment()
{
    level endon( "end_game" );

    df_touch( "step3" );
    df_a1_relay_glint_set( 0 );
    df_debug_print( "DF: sweep " + ( level.df_segments_done + 1 ) + "/" + df_a1_stops_needed() + " started, bus left " + df_a1_stop_name() + ", relay hp " + level.df_relay_hp );

    level.df_sweep_active = 1;
    level thread df_a1_roof_spawner(); // owner 2026-09-11: waves while the relay rides
    df_relay_fx_set( "sweep" );
    hum = spawn( "script_origin", level.df_relay.origin );
    hum linkto( level.the_bus );
    hum playloopsound( "zmb_avogadro_loop" );
    level.df_step3_hum = hum; // so a skip can silence it

    level thread df_step3_arrival_watch();
    level thread df_step3_emp_watch();
    level thread df_step3_empty_watch();

    level waittill( "df_step3_outcome", result );
    level notify( "df_step3_segment_end" );
    level.df_sweep_active = 0;
    df_step3_hum_stop();
    df_debug_print( "DF: sweep outcome " + result + " at " + df_a1_stop_name() + ", relay hp " + level.df_relay_hp );

    if ( result == "arrived" )
    {
        df_step3_stop_counted();
        return;
    }

    if ( result == "destroyed" )
    {
        level.df_segments_done = 0;
        df_cue_fail( level.the_bus.origin + ( 0, 0, 60 ) );
        df_say( "D3_FAIL" );
        df_step3_break_relay();
        return;
    }

    // emp or empty bus: the stop does not count, the relay is kept
    df_relay_idle_fx();
    df_cue_fail( level.the_bus.origin + ( 0, 0, 60 ) );
    df_say( "D3_FAIL" );
}

// A stop counted: leave horn (zm_transit_bus.gsc:3070), blue burst on the relay, 8 s of tower lightning
// (the canon far cue). Last stop (the only one, audit #9): relay locked (power-pulse replays) with the
// switch-on sound; the STEP DONE sting is df_complete's. The cornfield watcher starts here: Maxis's canon
// "the Spire is nearby" line when the locked relay enters the cornfield (df_a1_cornfield_watch).
df_step3_stop_counted()
{
    level.df_segments_done++;
    playsoundatposition( "zmb_bus_horn_leave", level.the_bus.origin );
    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", level.df_relay.origin + ( 0, 0, 20 ) );
    df_tower_fx_start( "none" );
    level thread df_tower_fx_stop_after( 8 );
    df_debug_print( "DF: stop " + level.df_segments_done + "/" + df_a1_stops_needed() + " counted at " + df_a1_stop_name() + ", relay hp " + level.df_relay_hp );

    if ( level.df_segments_done >= df_a1_stops_needed() )
    {
        level.df_relay_locked = 1;
        df_relay_fx_set( "locked" );
        playsoundatposition( "zmb_power_rise_start", level.df_relay.origin );
        level thread df_a1_cornfield_watch();
        df_debug_print( "DF: relay locked, take it to the tower" );
        return;
    }

    df_relay_idle_fx();
}

// Where the locked relay is right now: the model (roof, dropped) or its carrier; undefined when neither exists.
df_a1_relay_ent()
{
    if ( isdefined( level.df_relay ) )
        return level.df_relay;

    if ( isdefined( level.df_relay_carrier ) )
        return level.df_relay_carrier;

    return undefined;
}

// Vanilla delivers vox_maxi_near_corn_0 through the bus driver when the built device rides into the cornfield
// (zm_transit_sq.gsc:1191). Ours: once per game (df_vox_once), 3D at the relay, when the locked relay (on the
// roof, dropped or carried) is inside zone "zone_amb_cornfield" (zm_transit.gsc:388, classic only;
// _zm_zonemgr::entity_in_zone with the enabled check ignored) or, when that zone is not there, within 1200 of
// the tower. Ends when the relay is plugged.
df_a1_cornfield_watch()
{
    level endon( "end_game" );
    level endon( "df_relay_plugged" );
    level endon( "df_skip_step3" );
    level endon( "df_skip_step4" );

    tower = df_tower_top();

    while ( true )
    {
        wait 1;
        ent = df_a1_relay_ent();

        if ( !isdefined( ent ) )
            continue;

        if ( !df_a1_in_cornfield( ent, tower ) )
            continue;

        df_debug_print( "DF: locked relay entered the cornfield, Maxis: the Spire is nearby" );
        df_vox_once( "vox_maxi_near_corn_0", ent.origin + ( 0, 0, 40 ) );
        return;
    }
}

// True when ent is in the cornfield: zone volumes when the zone exists, else the 1200-unit fallback around the tower.
df_a1_in_cornfield( ent, tower )
{
    if ( isdefined( level.zones ) && isdefined( level.zones["zone_amb_cornfield"] ) && isdefined( level.zones["zone_amb_cornfield"].volumes ) )
        return ent maps\mp\zombies\_zm_zonemgr::entity_in_zone( "zone_amb_cornfield", 1 );

    if ( !isdefined( tower ) )
        return false;

    return distance2dsquared( ent.origin, tower ) < 1200 * 1200;
}

// Bus reached the next stop (zm_transit_bus.gsc:457): counts when the relay lives and someone rode.
df_step3_arrival_watch()
{
    level endon( "end_game" );
    level endon( "df_step3_segment_end" );

    level.the_bus waittill( "reached_destination" );

    // the stop counts only if somebody rode with the relay into it (seen within the last 3 s: a ladder climb or
    // a moment in last stand must not lose an honest ride)
    if ( level.df_relay_hp > 0 && df_riders_recently( 3000 ) )
        level notify( "df_step3_outcome", "arrived" );
    else
    {
        df_debug_print( "DF: the bus reached the stop with nobody riding the relay: not counted" );
        level notify( "df_step3_outcome", "empty" );
    }
}

// EMP within 256 (+ its radius) of the bus fails the sweep (level "emp_detonate", _zm_weap_emp_bomb.gsc:80).
df_step3_emp_watch()
{
    level endon( "end_game" );
    level endon( "df_step3_segment_end" );

    while ( true )
    {
        level waittill( "emp_detonate", origin, radius );

        if ( !isdefined( radius ) )
            radius = 0;

        if ( distancesquared( origin, level.the_bus.origin ) < ( 256 + radius ) * ( 256 + radius ) )
        {
            df_debug_print( "DF: EMP near the bus, sweep lost" );
            level notify( "df_step3_outcome", "emp" );
        }
    }
}

// ---- zombie attacks on the relay ------------------------------------------------------------
// Same behaviour as the turbine: a zombie that gets within reach of a live relay (power on, not
// locked) stops and swings at it. Copied from _zm_equipment::item_attract_zombies / attack_item with
// our own hp accounting (the vanilla damage path is tied to player equipment tables).

// Polls zombies near the relay while it is live; ends for good once the relay is locked or gone.
df_relay_attract_start()
{
    level endon( "end_game" );
    level notify( "df_relay_attract_stop" );
    level endon( "df_relay_attract_stop" );

    // a locked relay never unlocks, so the poll can stop for good then
    while ( isdefined( level.df_relay ) && !is_true( level.df_relay_locked ) )
    {
        wait 0.1;

        if ( is_true( level.df_relay_locked ) || !flag( "power_on" ) )
            continue;

        relay = level.df_relay;

        foreach ( ai in getaiarray( level.zombie_team ) )
        {
            if ( !isdefined( ai ) || !isalive( ai ) )
                continue;

            if ( is_true( ai.is_inert ) || is_true( ai.is_traversing ) || is_true( ai.doing_equipment_attack ) )
                continue;

            // only regular zombies swing (vanilla is_quad/is_leaper crash on AI without an animname)
            if ( is_true( ai.isscreecher ) || !isdefined( ai.animname ) || ai.animname != "zombie" )
                continue;

            vdist = df_abs( ai.origin[2] - relay.origin[2] );
            d2 = distance2dsquared( ai.origin, relay.origin );

            if ( d2 < 72 * 72 && d2 > 24 * 24 && vdist < 64 )
                ai thread df_relay_attack_swing( relay );
        }
    }
}

// self = zombie. One melee swing at the relay (vanilla attack_item body, _zm_equipment.gsc:1626, own damage).
df_relay_attack_swing( item )
{
    self endon( "death" );
    item endon( "death" );
    self endon( "start_inert" );

    if ( is_true( self.doing_equipment_attack ) || is_true( self.not_interruptable ) )
        return;

    self thread maps\mp\zombies\_zm_equipment::attack_item_stop( item );
    self thread maps\mp\zombies\_zm_equipment::attack_item_interrupt( item );
    self.doing_equipment_attack = 1;
    self.item = item;
    self thread maps\mp\zombies\_zm_audio::do_zombies_playvocals( "attack", self.animname );

    melee_anim = "zm_window_melee";

    if ( !self.has_legs )
    {
        melee_anim = "zm_walk_melee_crawl";

        if ( isdefined( self.a.gib_ref ) && self.a.gib_ref == "no_legs" )
            melee_anim = "zm_stumpy_melee";
        else if ( self.zombie_move_speed == "run" || self.zombie_move_speed == "sprint" )
            melee_anim = "zm_run_melee_crawl";
    }

    self orientmode( "face point", item.origin );

    // animscripted pins the zombie to a WORLD position: on a moving bus it hung in the air while the bus drove on
    // (owner 2026-09-11). While the bus moves the swing is damage + sound only; the anim plays when it stands.
    moving = isdefined( level.the_bus ) && level.the_bus getspeedmph() > 0.5;

    if ( !moving )
        self animscripted( self.origin, flat_angle( vectortoangles( item.origin - self.origin ) ), melee_anim );

    self notify( "item_attack" );
    df_relay_damage( 60 ); // audit #9 (was 40): 800 hp / 60 = 14 swings, so one stop can still be lost
    item playsound( "fly_riotshield_zm_impact_flesh" );
    wait( randomint( 100 ) / 100.0 );
    self.doing_equipment_attack = 0;
    self orientmode( "face default" );
}

// Hp is kept across stops; it only comes back with a rebuilt relay. Every hit sparks (elec_sm burst);
// the first drop to 400 or less starts a second, permanent burst layer (art audit S3.3: a visibly "sicker"
// relay, players do not see the console hp); the first drop to 200 or less blows the warning horn once
// (zmb_bus_horn_warn, zm_transit_bus.gsc:3067).
df_relay_damage( amount )
{
    if ( !isdefined( level.df_relay ) || level.df_relay_hp <= 0 )
        return;

    level.df_relay_hp -= amount;
    df_debug_print( "DF: relay hit, hp " + level.df_relay_hp );
    level thread df_a1_burst( "elec_sm", level.df_relay, 24, 0.6 );

    if ( level.df_relay_hp > 0 )
    {
        if ( level.df_relay_hp <= 400 && !is_true( level.df_relay_sick ) )
        {
            level.df_relay_sick = 1;
            level thread df_a1_relay_sick_pulse();
            df_debug_print( "DF: relay damaged, hp " + level.df_relay_hp + ", second burst layer on" );
        }

        if ( level.df_relay_hp <= 200 && !is_true( level.df_relay_horned ) )
        {
            level.df_relay_horned = 1;
            playsoundatposition( "zmb_bus_horn_warn", level.df_relay.origin );
            df_debug_print( "DF: relay low, hp " + level.df_relay_hp + ", warning horn" );
        }

        return;
    }

    if ( is_true( level.df_sweep_active ) )
    {
        level notify( "df_step3_outcome", "destroyed" );
        return;
    }

    // destroyed while parked: same consequence, parts back on the roof. Runs in its own thread:
    // the caller is the zombie swing thread, which ends on the relay "death" notify.
    level thread df_relay_destroyed_parked();
}

// Relay chewed to 0 hp between stops: FAIL cue (df_cue_fail), Richtofen, parts back on the roof.
df_relay_destroyed_parked()
{
    level endon( "end_game" );
    level.df_segments_done = 0;
    df_cue_fail( level.the_bus.origin + ( 0, 0, 60 ) );
    df_say( "D3_FAIL" );
    df_step3_break_relay();
}

// Second burst layer of a damaged relay (hp <= 400): a side burst (df_side_burst_fx, pre-fork = the electric
// one) low on the radio every 0.8-1.4 s while the relay MODEL exists. It ends with the model (break, take) and
// is restarted by df_relay_drop_at while level.df_relay_sick is set; only a rebuild clears the flag.
df_a1_relay_sick_pulse()
{
    level endon( "end_game" );
    level notify( "df_a1_sick_stop" );
    level endon( "df_a1_sick_stop" );

    while ( isdefined( level.df_relay ) && is_true( level.df_relay_sick ) )
    {
        level thread df_a1_burst( df_side_burst_fx(), level.df_relay, 10, 0.6 );
        wait( randomfloatrange( 0.8, 1.4 ) );
    }
}

// Nobody on the bus for more than the rider grace -> the sweep is lost.
df_step3_empty_watch()
{
    level endon( "end_game" );
    level endon( "df_step3_segment_end" );

    level.df_last_rider_time = gettime();

    while ( true )
    {
        wait 0.5;

        if ( df_players_on_bus().size > 0 )
            level.df_last_rider_time = gettime();
        else if ( !df_riders_recently() )
        {
            df_debug_print( "DF: nobody on the bus for 6 s, sweep lost" );
            level notify( "df_step3_outcome", "empty" );
        }
    }
}

// Climbing to the roof, hanging on the ladder or a moment in last stand must not fail the ride:
// a rider seen within the last 6 s still counts.
df_riders_recently( window_ms )
{
    if ( !isdefined( window_ms ) )
        window_ms = 6000;

    if ( df_players_on_bus().size > 0 )
        return true;

    return isdefined( level.df_last_rider_time ) && gettime() - level.df_last_rider_time < window_ms;
}

// Destroyed relay: burst (blue one-shot + elec_md + turbine explosion sound, _zm_equip_turbine.gsc:447),
// the three parts lie on the roof again, ride with the bus, and can be picked up; the roof build site
// comes back so it can be rebuilt. (The FAIL sound is the caller's df_cue_fail.)
df_step3_break_relay()
{
    if ( !isdefined( level.df_relay ) )
        return;

    df_debug_print( "DF: relay destroyed, parts back on the roof" );
    df_relay_fx_set( "off" );
    df_a1_relay_glint_set( 0 );
    level notify( "df_relay_attract_stop" );
    level notify( "df_a1_sick_stop" );
    level.df_relay_sick = 0;
    pos = level.df_relay.origin;
    level.df_relay notify( "death" );
    df_a1_relay_delete( level.df_relay );
    level.df_relay = undefined;
    level.df_relay_hp = 0;
    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", pos + ( 0, 0, 20 ) );
    level thread df_a1_burst_at( "elec_md", pos + ( 0, 0, 20 ), 0.7 );
    playsoundatposition( "zmb_explo", pos );

    level.df_parts_collected = 0;
    level.df_parts = [];
    df_scav_carry_clear( "parts" );

    f = anglestoforward( level.the_bus.angles );
    r = anglestoright( level.the_bus.angles );
    df_step3_roof_part( 0, pos + f * 50, "radio" );
    df_step3_roof_part( 1, pos - f * 50, "mast" );
    df_step3_roof_part( df_a1_receiver_idx(), pos + r * 40, "coil" );

    level thread df_step2_roof_site();
}

// One part lying on the roof (df_model part_x / receiver), glint above it, both riding the bus.
df_step3_roof_part( idx, origin, name )
{
    part = spawnstruct();
    part.idx = idx;
    part.name = name;
    part.model = spawn( "script_model", origin + ( 0, 0, df_model_rest_z( df_a1_part_model( idx ) ) ) ); // centre-pivot parts rest ON the roof
    part.model setmodel( df_model( df_a1_part_model( idx ) ) );
    part.model.angles = df_model_angles( df_a1_part_model( idx ), level.the_bus.angles[1] );
    part.model linkto( level.the_bus );
    part.fx = df_fx_loop( "fx_zmb_tranzit_light_glow", origin + ( 0, 0, 20 ) );

    if ( isdefined( part.fx ) )
        part.fx linkto( level.the_bus );

    level.df_parts[idx] = part;
    level thread df_roof_part_watch( part );
}

// Moving part on the roof: poll players near it (no trigger can ride the bus), one press takes it.
df_roof_part_watch( part )
{
    level endon( "end_game" );
    level endon( "df_skip_step3" );

    while ( isdefined( part.model ) )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            near = is_player_valid( player ) && distancesquared( player.origin, part.model.origin ) < 90 * 90;
            player df_act1_prompt( near, "Press [{+activate}] to take the " + part.name, "roof_part_" + part.idx );

            if ( !near || !player df_press_use() )
                continue;

            player df_act1_prompt( 0, undefined, "roof_part_" + part.idx );
            df_a1_part_taken( part, player, "recovered from the roof" );
            return;
        }
    }
}

// Relay visual state on the roof (or dropped): "off", "idle" (powered: tiny glow + elec_sm bursts every
// 2-3.5 s), "sweep" (the same glow + a side burst every 1.5 s: art audit S3.1, the huge blue spark loop
// zm_transit_fx.gsc:66 enveloped the bus), "locked" (power-pulse replays: art audit #10, the lightning orb
// sq_common_lightning means "Easter Egg complete" on the pylon and stays the tower's).
df_relay_fx_set( mode )
{
    df_fx_stop( level.df_relay_fx );
    level.df_relay_fx = undefined;
    level notify( "df_relay_pulse_stop" );
    level notify( "df_a1_pulse_stop_relay" );

    if ( !isdefined( mode ) || mode == "off" || !isdefined( level.df_relay ) )
        return;

    if ( mode == "locked" )
    {
        level thread df_relay_lock_pulse();
        return;
    }

    fx = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", level.df_relay.origin + ( 0, 0, 30 ) );

    if ( isdefined( fx ) )
        fx linkto( level.df_relay );

    level.df_relay_fx = fx;

    if ( mode == "sweep" )
    {
        level thread df_a1_sweep_pulse();
        return;
    }

    // "idle": the antenna is powered
    level thread df_a1_idle_pulse( level.df_relay, "relay", 30 );
}

// Sweep intensity: a side burst (df_side_burst_fx, pre-fork = the electric one, 0.6 s) on the relay every
// 1.5 s, like the fuse boxes; ends with the mode (df_relay_fx_set notifies "df_a1_pulse_stop_relay").
df_a1_sweep_pulse()
{
    level endon( "end_game" );
    level endon( "df_a1_pulse_stop_relay" );

    while ( isdefined( level.df_relay ) )
    {
        level thread df_a1_burst( df_side_burst_fx(), level.df_relay, 24, 0.6 );
        wait 1.5;
    }
}

// Locked relay: the dashboard power pulse (fx_zmb_tranzit_power_pulse, zm_transit_fx.gsc:117, the Step 1
// success look) replayed for 1 s every 1.5-2.5 s above it.
df_relay_lock_pulse()
{
    level endon( "end_game" );
    level endon( "df_relay_pulse_stop" );

    while ( isdefined( level.df_relay ) )
    {
        level thread df_a1_burst( "fx_zmb_tranzit_spark_int_runner", level.df_relay, 30, 1.0 );
        wait( randomfloatrange( 1.5, 2.5 ) );
    }
}

// Relay light when nothing special happens: locked = orb pulse, power on = small idle, no power = dark.
df_relay_idle_fx()
{
    if ( !isdefined( level.df_relay ) )
        return;

    if ( is_true( level.df_relay_locked ) )
    {
        df_relay_fx_set( "locked" );
        return;
    }

    if ( flag( "power_on" ) )
    {
        df_relay_fx_set( "idle" );
        return;
    }

    df_relay_fx_set( "off" );
}

// Follows the power switch (flag "power_on") for the life of the game so the relay lights up or goes dark with it.
df_relay_power_watch()
{
    level endon( "end_game" );
    level.df_relay_power_watching = 1;

    while ( true )
    {
        if ( flag( "power_on" ) )
            flag_waitopen( "power_on" );
        else
            flag_wait( "power_on" );

        if ( !is_true( level.df_sweep_active ) )
            df_relay_idle_fx();
    }
}

// =========================================================================================
// STEP 4 - Plug In (side lock)
// =========================================================================================
// Take the locked relay off the roof (one press), carry it to the tower socket (no lamp teleports
// while carrying; a downed carrier drops it), plug it in (one press). Power on = Richtofen, off = Maxis.

// Runs the pickup poll, the carrier monitor and the socket poll until the relay is plugged.
df_step4_run()
{
    level endon( "end_game" );

    level thread df_step4_pickup_watch();
    level thread df_relay_carry_monitor();
    level thread df_step4_socket();
    level thread df_step4_skip_cleanup();

    level waittill( "df_relay_plugged" );
    df_complete( "step4" );
}

// "!df goto" past this step: relay plugged, side already chosen by the goto command
df_step4_setup()
{
    if ( isdefined( level.df_relay ) )
    {
        df_relay_fx_set( "off" );
        df_a1_relay_delete( level.df_relay );
        level.df_relay = undefined;
    }

    if ( !isdefined( level.df_side ) )
    {
        if ( flag( "power_on" ) )
            df_set_side( "rich" );
        else
            df_set_side( "maxis" );
    }

    df_step4_socket_spawn();
    df_step4_socket_light( level.df_side );
    df_step4_plugged_relay_spawn();
    level.df_relay_plugged = 1;
}

// The TABLE under the tower (owner 2026-09-08, df_model "table" at anchor DF_TABLE): the place the relay
// plugs into and where every later step deposits its item (slot 0 relay, slot 1 key card, slot 2 orb;
// df_coords df_table_slot). It replaces the wall-mounted breaker panel that used to stand here, and it
// stays level.df_socket so everything reading level.df_socket.origin / df_coord( "DF_SOCKET" ).origin
// keeps working (df_coords moves DF_SOCKET onto DF_TABLE). The "socket" kind is only a `!df show` preview now.
// Spawned at BOOT (df_a1_boot_items, owner rule); Step 4 and the goto setup only find it here. Idempotent.
df_step4_socket_spawn()
{
    if ( isdefined( level.df_socket ) )
        return;

    c = df_coord( "DF_TABLE" );
    level.df_socket = spawn( "script_model", c.origin );
    level.df_socket setmodel( df_model( "table" ) );
    level.df_socket.angles = c.angles;
    df_a1_table_clips_spawn( c );
    df_debug_print( "DF: table spawned at " + int( c.origin[0] ) + " " + int( c.origin[1] ) + " " + int( c.origin[2] ) + " (front yaw " + int( df_table_yaw() ) + ")" );
}

// A script_model has no collision, so players walked through the bench (owner 2026-09-09). Three player
// clips (collision_player_32x32x32, the model vanilla's ffotd uses for exactly this, zm_transit_ffotd.gsc:17)
// along the bench's long side, 16 up so the block spans the floor whether the model's pivot is its base or
// its centre; 32 high is more than a player can step. Zombies ignore player clips: the wave still reaches
// the orb.
df_a1_table_clips_spawn( c )
{
    df_a1_table_clips_delete();
    level.df_socket_clips = [];
    yaw = df_table_yaw();
    right = anglestoright( ( 0, yaw, 0 ) );

    // two rows (owner 2026-09-11: players jumped onto the table): 16 and 48 up = a 64-tall wall
    for ( k = -1; k <= 1; k++ )
    {
        for ( row = 0; row < 2; row++ )
        {
            clip = spawn( "script_model", c.origin + right * ( k * 30 ) + ( 0, 0, 16 + row * 32 ) );
            clip setmodel( df_model( "clip" ) );
            clip.angles = ( 0, yaw, 0 );
            level.df_socket_clips[level.df_socket_clips.size] = clip;
        }
    }
}

df_a1_table_clips_delete()
{
    if ( !isdefined( level.df_socket_clips ) )
        return;

    foreach ( clip in level.df_socket_clips )
    {
        if ( isdefined( clip ) )
            clip delete();
    }

    level.df_socket_clips = undefined;
}

// Table light in the locked side's colour, over the middle of the table (lamp fx aliases
// zm_transit_fx.gsc:114/115).
df_step4_socket_light( side )
{
    df_fx_stop( level.df_socket_fx );
    fxname = "fx_zmb_tranzit_light_glow_xsm";

    if ( side == "rich" )
        fxname = "fx_zmb_tranzit_light_glow_xsm";

    level.df_socket_fx = df_fx_loop( fxname, level.df_socket.origin + ( 0, 0, 30 ) );
}

// The plugged relay: the antenna stands ON THE TABLE, slot 0 (the left one seen from the front), for the
// rest of the game (level.df_socket_relay), lit only while the power is on (same idle look as on the
// roof). df_table_slot returns the point on the table top and the relay's own pivot is at its base
// (buildable piece), so it just stands there. Its top piece (art audit change 7): kind "relay_mast" (the
// upright post, 117 tall, so the Step 4 residue is an antenna seen from outside the fence) when the coords
// registry defines it, else the roof's flat "relay_top"; both stacked at their registry offset by
// df_a1_relay_spawn. An anchor DF_SOCKET_RELAY, if the coords registry ever defines one, still wins.
df_step4_plugged_relay_spawn()
{
    if ( isdefined( level.df_socket_relay ) )
        return;

    c = df_coord( "DF_SOCKET_RELAY" );

    if ( isdefined( c ) )
    {
        pos = c.origin;
        yaw = c.angles[1];
    }
    else
    {
        pos = df_table_slot( 0 );
        yaw = df_table_yaw();
    }

    top_kind = "relay_top";

    if ( isdefined( level.df_models ) && isdefined( level.df_models["relay_mast"] ) )
        top_kind = "relay_mast";

    level.df_socket_relay = df_a1_relay_spawn( pos, yaw, top_kind );
    level thread df_a1_plugged_power_watch();
    df_debug_print( "DF: plugged relay at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) + ", top piece " + top_kind );
}

// Plugged relay light follows the power flag for the rest of the game.
df_a1_plugged_power_watch()
{
    level endon( "end_game" );

    while ( isdefined( level.df_socket_relay ) )
    {
        df_a1_plugged_fx( flag( "power_on" ) );

        if ( flag( "power_on" ) )
            flag_waitopen( "power_on" );
        else
            flag_wait( "power_on" );
    }
}

// Plugged relay idle look on/off (tiny glow + elec_sm bursts while powered).
df_a1_plugged_fx( on )
{
    level notify( "df_a1_pulse_stop_plugged" );
    df_fx_stop( level.df_socket_relay_fx );
    level.df_socket_relay_fx = undefined;

    if ( !on || !isdefined( level.df_socket_relay ) )
        return;

    level.df_socket_relay_fx = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", level.df_socket_relay.origin + ( 0, 0, 30 ) );
    level thread df_a1_idle_pulse( level.df_socket_relay, "plugged", 30 );
}

// Relay on the roof (or dropped on the ground): stand within 120 units, one press to carry it.
df_step4_pickup_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step4" );
    level endon( "df_relay_plugged" );

    while ( true )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            near = isdefined( level.df_relay ) && is_player_valid( player ) && !is_true( player.df_carrying_relay ) && distancesquared( player.origin, level.df_relay.origin ) < 120 * 120;
            player df_act1_prompt( near, "Press [{+activate}] to take the relay", "relay_pickup" );

            if ( !near || !player df_press_use() )
                continue;

            df_touch( "step4" );
            df_a1_socket_marker_set( 1 ); // the AVAILABLE glint of the step ends with the touch: ours takes over
            player df_act1_prompt( 0, undefined, "relay_pickup" );
            player df_relay_take();
            break; // the relay is gone: the other players' distance check would read an undefined origin
        }
    }
}

// self = player. The relay model leaves the world; the player carries it (icon, elec_sm bursts on the back).
df_relay_take()
{
    df_relay_fx_set( "off" );
    df_a1_relay_glint_set( 0 );
    df_a1_relay_delete( level.df_relay );
    level.df_relay = undefined;
    level.df_relay_carrier = self;
    level.df_relay_carrier_pos = self.origin;
    level.df_relay_carried = 1; // survives the carrier entity (disconnect), see df_relay_carry_monitor
    self.df_carrying_relay = 1;
    df_scav_carry_set( "relay", 1, 1, self );
    self df_a1_carry_fx( 1 );
    self playsound( "zmb_buildable_pickup" );
    df_debug_print( "DF: relay picked up by " + self.name );
}

// self = player. Clears carry state; drop_at (optional) puts the relay model back in the world.
df_relay_release( drop_at )
{
    self.df_carrying_relay = 0;
    df_scav_carry_clear( "relay" );
    self df_a1_carry_fx( 0 );
    level.df_relay_carrier = undefined;
    level.df_relay_carried = 0;

    if ( !isdefined( drop_at ) )
        return;

    df_relay_drop_at( drop_at, self.angles[1] );

    // downed while riding: the relay rides along instead of being left behind on the road
    if ( isdefined( level.df_relay ) && isdefined( level.the_bus ) && ( is_true( self.isonbus ) || ( isdefined( level.roof_trig ) && self istouching( level.roof_trig ) ) ) )
    {
        level.df_relay linkto( level.the_bus );
        df_debug_print( "DF: dropped relay linked to the bus" );
    }
}

// Relay model back in the world, upright on the ground, with its state light (and its damage layer if it had one).
df_relay_drop_at( drop_at, yaw )
{
    pos = df_ground( drop_at );
    level.df_relay = df_a1_relay_spawn( pos, yaw );
    level.df_relay_fx = undefined;
    df_relay_idle_fx();

    if ( is_true( level.df_relay_sick ) )
        level thread df_a1_relay_sick_pulse();

    df_debug_print( "DF: relay dropped at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) );
}


// self = player. Carry fx on/off: short elec_sm bursts on J_SpineLower (tag used by zm_transit_lava.gsc:186)
// every 1-2 s instead of a permanent loop. The current burst is also kept in level.df_relay_carry_fx so the
// monitor can delete it when the carrier's entity is gone.
df_a1_carry_fx( on )
{
    self notify( "df_a1_carry_stop" );
    df_fx_stop( self.df_carry_fx );
    self.df_carry_fx = undefined;
    level.df_relay_carry_fx = undefined;

    if ( on )
        self thread df_a1_carry_pulse();
}

df_a1_carry_pulse()
{
    self endon( "disconnect" );
    self endon( "df_a1_carry_stop" );
    level endon( "end_game" );

    while ( true )
    {
        b = df_fx_loop( "elec_sm", self.origin + ( 0, 0, 50 ) );

        if ( isdefined( b ) )
        {
            b linkto( self, "J_SpineLower", ( 0, 0, 0 ), ( 0, 0, 0 ) );
            self.df_carry_fx = b;
            level.df_relay_carry_fx = b;
            wait 0.6;
            df_fx_stop( b );
            self.df_carry_fx = undefined;
            level.df_relay_carry_fx = undefined;
        }

        wait( randomfloatrange( 1.0, 1.8 ) );
    }
}

// A carrier who goes down or leaves drops the relay where they were.
df_relay_carry_monitor()
{
    level endon( "end_game" );
    level endon( "df_skip_step4" );
    level endon( "df_relay_plugged" );

    while ( true )
    {
        wait 0.1;
        carrier = level.df_relay_carrier;

        if ( !isdefined( carrier ) )
        {
            // a carrier who left the game leaves no entity behind, only the flag: drop where they were
            if ( is_true( level.df_relay_carried ) )
            {
                level.df_relay_carried = 0;
                df_fx_stop( level.df_relay_carry_fx );
                level.df_relay_carry_fx = undefined;
                df_relay_drop_at( level.df_relay_carrier_pos, 0 );
                df_debug_print( "DF: relay carrier left the game, relay dropped" );
            }

            continue;
        }

        level.df_relay_carrier_pos = carrier.origin;

        if ( carrier maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
        {
            df_debug_print( "DF: relay carrier went down, relay dropped" );
            carrier df_relay_release( carrier.origin );
        }
    }
}

// The table at the tower base (exists since boot): the step's AVAILABLE glint marks it until the relay is
// lifted (df_step_focus, core), then our own marker (df_a1_socket_marker_set, same glint) until the plug;
// while a relay carrier is within 400 it glows in the colour the power state would lock (audit section 4,
// preview; silent on purpose, the colour is the message); a carrier standing within 150 gets the prompt; one
// press plugs the relay in and the power state locks the side.
df_step4_socket()
{
    level endon( "end_game" );
    level endon( "df_skip_step4" );
    level endon( "df_relay_plugged" );

    df_step4_socket_spawn();
    c = df_coord( "DF_SOCKET" );

    // a relay already off the roof (goto, or picked up before this thread ran) has no AVAILABLE glint left
    if ( is_true( level.df_relay_carried ) || is_true( level.df_step_touched["step4"] ) )
        df_a1_socket_marker_set( 1 );

    while ( true )
    {
        wait 0.1;
        preview = undefined;

        foreach ( player in getplayers() )
        {
            carrier = is_true( player.df_carrying_relay ) && is_player_valid( player );

            if ( carrier && distancesquared( player.origin, c.origin ) < 400 * 400 )
                preview = df_a1_side_of_power();

            near = carrier && distancesquared( player.origin, c.origin ) < 150 * 150;
            player df_act1_prompt( near, "Press [{+activate}] to plug in the relay", "relay_socket" );

            if ( !near || !player df_press_use() )
                continue;

            player df_act1_prompt( 0, undefined, "relay_socket" );
            df_a1_socket_marker_set( 0 );
            df_step4_plug( player );
            return;
        }

        df_a1_table_preview( preview );
    }
}

// Our key glint over the table (+40, zm_transit_fx.gsc:105) from the relay pickup to the plug; idempotent.
df_a1_socket_marker_set( on )
{
    if ( !on )
    {
        df_fx_stop( level.df_socket_marker );
        level.df_socket_marker = undefined;
        return;
    }

    if ( isdefined( level.df_socket_marker ) || !isdefined( level.df_socket ) || is_true( level.df_relay_plugged ) )
        return;

    c = df_coord( "DF_SOCKET" );
    level.df_socket_marker = df_fx_loop( "fx_zmb_tranzit_light_glow", c.origin + ( 0, 0, 40 ) );
}

// The side the power switch would lock right now: on = Richtofen, off = Maxis (Step 4 rule).
df_a1_side_of_power()
{
    if ( flag( "power_on" ) )
        return "rich";

    return "maxis";
}

// Side preview on the table (audit section 4): `side` = "rich" (blue), "maxis" (orange) or undefined (off).
// Same lamp fx as the final light, kept in level.df_socket_fx so df_step4_socket_light simply replaces it
// on the plug. Only acts when the state changes (called every poll tick).
df_a1_table_preview( side )
{
    if ( isdefined( side ) && isdefined( level.df_a1_preview ) && level.df_a1_preview == side )
        return;

    if ( !isdefined( side ) && !isdefined( level.df_a1_preview ) )
        return;

    level.df_a1_preview = side;

    if ( !isdefined( side ) )
    {
        df_fx_stop( level.df_socket_fx );
        level.df_socket_fx = undefined;
        df_debug_print( "DF: table preview off (no carrier within 400)" );
        return;
    }

    df_step4_socket_light( side );
    df_debug_print( "DF: table preview " + side + " (carrier within 400, power " + flag( "power_on" ) + ")" );

    // audit v3 #1: the fork is irreversible and Step 3 forced the power ON, so the choice is spoken the first time
    // the table lights up for a carrier (S4_HINT_2: "Power on serves him. Off, me."), whatever the ladder state
    if ( !is_true( level.df_a1_fork_said ) )
    {
        level.df_a1_fork_said = 1;
        df_hint_now( "step4", 2 );
    }
}

// The relay is plugged: side from the power flag, socket light, antenna at the socket, blue burst, a PROGRESS
// TICK click (df_cue_tick) and the switch-on sound (zmb_turn_on, zm_transit_power.gsc:60), 15 s of tower
// visuals in the side's colour, the lock line and the canon first-contact voice once (df_vox_once, 3D at the
// table): Richtofen vox_zmba_sidequest_power_on_0 (zm_transit_sq.gsc:1043) or Maxis vox_maxi_power_off_0
// (zm_transit_sq.gsc:599). The STEP DONE sting is df_complete's (df_step4_run). The wrong-side preview
// (df_a1_table_preview) stays silent on purpose: the colour is the whole message.
df_step4_plug( who )
{
    who df_relay_release( undefined );

    side = df_a1_side_of_power();
    df_set_side( side );
    level.df_relay_plugged = 1;
    level.df_a1_preview = undefined; // the preview light becomes the final one
    df_step4_socket_light( side );
    df_step4_plugged_relay_spawn();
    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", level.df_socket.origin + ( 0, 0, 20 ) );
    df_cue_tick( level.df_socket.origin + ( 0, 0, 30 ) );
    playsoundatposition( "zmb_buildable_complete", level.df_socket.origin ); // 1.4 s "built" (zmb_turn_on = 14 s)
    df_tower_fx_start( side );
    level thread df_tower_fx_stop_after( 15 );

    if ( side == "rich" )
    {
        df_say( "D4_RICH_LOCK" );
        df_vox_once( "vox_zmba_sidequest_power_on_0", level.df_socket.origin + ( 0, 0, 40 ) );
    }
    else
    {
        df_say( "D4_MAXIS_LOCK" );
        df_vox_once( "vox_maxi_power_off_0", level.df_socket.origin + ( 0, 0, 40 ) );
    }

    df_debug_print( "DF: relay plugged by " + who.name + ", power " + flag( "power_on" ) + ", side " + side );
    level notify( "df_relay_plugged" );
}

// "!df goto" past this step: socket glint, prompts and carry state go (the setup func rebuilds the end state).
df_step4_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_relay_plugged" );
    level waittill( "df_skip_step4" );

    df_a1_socket_marker_set( 0 );
    df_a1_table_preview( undefined );

    foreach ( player in getplayers() )
    {
        player df_act1_prompt( 0, undefined, "relay_pickup" );
        player df_act1_prompt( 0, undefined, "relay_socket" );

        if ( is_true( player.df_carrying_relay ) )
            player df_relay_release( undefined );
    }
}

// ---- relay model + optional top piece -------------------------------------------------------------
// Every relay in the world (roof, dropped, plugged) is spawned here: df_model "relay" stood upright with
// its front along `yaw` (df_model_angles) plus, when the coords registry defines the top kind ("relay_top" =
// the flat lattice for the roof, low enough for the tunnel; "relay_mast" = the upright post for the table),
// a second piece stacked on it at df_model_offset( kind ) (the registry's own height: world sets relay_top
// to +7 = the radio's height, art audit change 7, the old +30 left 23 units of air) and linked to it.

// Spawns a relay model at pos facing yaw (with its top piece, `top_kind` optional, default "relay_top");
// returns the base script_model.
df_a1_relay_spawn( pos, yaw, top_kind )
{
    yaw = yaw - 45; // owner 2026-09-11: the relay sits at 45 degrees on the roof and on the table, turned this way (all pieces follow relay.df_yaw)
    relay = spawn( "script_model", pos );
    relay setmodel( df_model( "relay" ) );
    relay.angles = df_model_angles( "relay", yaw );
    relay.df_yaw = yaw;

    if ( !isdefined( top_kind ) )
        top_kind = "relay_top";

    df_a1_relay_top_attach( relay, top_kind );
    df_a1_relay_coil_attach( relay );
    return relay;
}

// The wire coil on the radio (registry kind "relay_coil", owner 2026-09-09: the assembled relay shows all three
// parts, roof and table alike). No-op when the registry has no such kind. Rides along (linkto).
df_a1_relay_coil_attach( relay )
{
    if ( !isdefined( relay ) || !isdefined( level.df_models ) || !isdefined( level.df_models["relay_coil"] ) )
        return;

    yaw = relay.angles[1];

    if ( isdefined( relay.df_yaw ) )
        yaw = relay.df_yaw;

    coil = spawn( "script_model", relay.origin + df_model_offset( "relay_coil" ) );
    coil setmodel( df_model( "relay_coil" ) );
    coil.angles = df_model_angles( "relay_coil", yaw );
    coil linkto( relay );
    relay.df_coil = coil;
}

// Stacks the `kind` piece on `relay` (no-op when the registry has no such kind); it rides along (linkto).
df_a1_relay_top_attach( relay, kind )
{
    if ( !isdefined( relay ) || !isdefined( level.df_models ) || !isdefined( level.df_models[kind] ) )
        return;

    // the registry owns the stacking height (df_coords df_model_def, printed by `!df dump`)
    offset = df_model_offset( kind );
    yaw = relay.angles[1];

    if ( isdefined( relay.df_yaw ) )
        yaw = relay.df_yaw;

    top = spawn( "script_model", relay.origin + offset );
    top setmodel( df_model( kind ) );
    top.angles = df_model_angles( kind, yaw );
    top linkto( relay );
    relay.df_top = top;
}

// Removes the top piece and the coil of `relay` (safe without them).
df_a1_relay_top_detach( relay )
{
    if ( !isdefined( relay ) )
        return;

    if ( isdefined( relay.df_coil ) )
    {
        relay.df_coil delete();
        relay.df_coil = undefined;
    }

    if ( !isdefined( relay.df_top ) )
        return;

    relay.df_top delete();
    relay.df_top = undefined;
}

// Deletes a relay model and its top piece (roof, dropped or plugged). Safe on undefined.
df_a1_relay_delete( relay )
{
    if ( !isdefined( relay ) )
        return;

    df_a1_relay_top_detach( relay );
    relay delete();
}

// ---- vanilla-style build hold ---------------------------------------------------------------------
// Mirrors _zm_buildables::buildable_use_hold_think_internal (Core/maps/mp/zombies/_zm_buildables.gsc:1845-1900):
// the player lowers the gun for the "zombie_builder_zm" hands (precacheitem :20 in _zm_buildables::init, run on
// every map by Core _zm.gsc:153; giveweapon/switchtoweapon :1864-1865), move states off (_zm_utility.gsc:4706),
// offhands + weapon cycling off (increment_is_drinking :3108), build loop sound zmb_buildable_loop on a
// script_origin (:2489, alias :2509), assemble dust at the camera every 0.5 s (buildable_play_build_fx :1911),
// 3 s default (:1850). No progress bar: the owner wants the hands animation only. Abort (key released, out of
// range, down, grenade, denizen) and success both restore the weapon (switch_back_primary_weapon,
// _zm_weapons.gsc:257; takeweapon :1878, decrement_is_drinking :1881, enable_player_move_states :1883);
// success then plays zmb_buildable_complete (:1604) on the builder.
// The hold runs in its own player thread and reports through a player field: a loop with
// `self endon( "disconnect" )` called from a level watcher would bind that watcher to this player for good.

// self = player. Build at a fixed point: hold use for `seconds` within `radius` of `origin`. Returns 1/0.
df_a1_build_hold( origin, radius, seconds )
{
    return self df_a1_build_hold_on( undefined, origin, radius, seconds );
}

// self = player. Same for a target riding an entity (the bus roof trigger): range is checked against ent.origin.
df_a1_build_hold_on( ent, origin, radius, seconds )
{
    self.df_a1_build_result = undefined;
    self thread df_a1_build_thread( ent, origin, radius, seconds );

    while ( isdefined( self ) && !isdefined( self.df_a1_build_result ) )
        wait 0.05;

    if ( !isdefined( self ) || !self.df_a1_build_result )
        return 0;

    return 1;
}

df_a1_build_thread( ent, origin, radius, seconds )
{
    self endon( "disconnect" );
    self.df_a1_build_result = self df_a1_build_body( ent, origin, radius, seconds );
}

// self = player. The hold itself (vanilla lines in the block comment above). Returns 1 on completion.
df_a1_build_body( ent, origin, radius, seconds )
{
    if ( isdefined( ent ) && !isdefined( origin ) )
        origin = ent.origin; // fallback should the entity vanish mid-build

    self.df_a1_building = 1;
    self disable_player_move_states( 1 );
    self increment_is_drinking();
    orgweapon = self getcurrentweapon();
    self giveweapon( "zombie_builder_zm" );
    self switchtoweapon( "zombie_builder_zm" );
    level thread df_a1_build_cues( self );

    start = gettime();
    total = seconds * 1000;
    ok = 0;
    // the vanilla build bar (owner 2026-09-11: "exactly like the turbine"): _zm_buildables::player_progress_bar, stopped
    // by the buildable_progress_end notify as vanilla does
    self thread maps\mp\zombies\_zm_buildables::player_progress_bar( start, total, undefined );

    while ( self df_a1_build_continue( ent, origin, radius ) )
    {
        if ( gettime() - start >= total )
        {
            ok = 1;
            break;
        }

        wait 0.05;
    }

    self notify( "buildable_progress_end" );
    self.df_a1_building = 0;
    self maps\mp\zombies\_zm_weapons::switch_back_primary_weapon( orgweapon );
    self takeweapon( "zombie_builder_zm" );

    if ( isdefined( self.is_drinking ) && self.is_drinking )
        self decrement_is_drinking();

    self enable_player_move_states();

    if ( ok )
        self playsound( "zmb_buildable_complete" );
    else
        df_debug_print( "DF: build aborted by " + self.name );

    return ok;
}

// self = player. Mirrors player_continue_building (_zm_buildables.gsc:1745-1763): not down or reviving,
// not throwing a grenade, not grabbed by a denizen, use still held, still within `radius` of the target.
df_a1_build_continue( ent, origin, radius )
{
    if ( !is_player_valid( self ) || self maps\mp\zombies\_zm_laststand::player_is_in_laststand() || self in_revive_trigger() )
        return 0;

    if ( self isthrowinggrenade() || isdefined( self.screecher ) || !self usebuttonpressed() )
        return 0;

    if ( isdefined( ent ) )
        return distancesquared( self.origin, ent.origin ) <= radius * radius;

    return distancesquared( self.origin, origin ) <= radius * radius;
}

// Build loop sound + assemble dust while player.df_a1_building is set (vanilla: player.buildableaudio
// script_origin with zmb_buildable_loop, _zm_buildables.gsc:2489-2509; building_dust at the camera every
// 0.5 s, :1911). Level thread: the sound entity is deleted even if the builder leaves mid-build.
df_a1_build_cues( player )
{
    level endon( "end_game" );

    hum = spawn( "script_origin", player.origin );
    hum playloopsound( "zmb_buildable_loop" );

    while ( isdefined( player ) && is_true( player.df_a1_building ) )
    {
        df_fx_once( "building_dust", player getplayercamerapos() );
        wait 0.5;
    }

    hum stoploopsound();
    hum delete();
}

// ---- shared helpers for the poll-based interactions ---------------------------------------------

// Several poll loops can want one player's mechanic prompt at once (the three roof parts lie 40-100 units
// apart): only the loop that showed it may hide it, otherwise they fight and the prompt flickers.
// self = player. owner = any string naming the caller.
df_act1_prompt( show, text, owner )
{
    if ( show )
    {
        if ( isdefined( self.df_prompt_hud ) && isdefined( self.df_prompt_owner ) && self.df_prompt_owner != owner )
            return;

        self df_prompt( 1, text );
        self.df_prompt_owner = owner;
        return;
    }

    if ( isdefined( self.df_prompt_owner ) && self.df_prompt_owner == owner )
    {
        self df_prompt( 0, undefined );
        self.df_prompt_owner = undefined;
    }
}

// self = player. Puzzle prompt (df_systems::df_prompt_puzzle, hidden with df_hints 0) called every poll tick:
// only shows/hides when the text actually changes, so the hud is never rebuilt per frame.
df_a1_puzzle_prompt( show, text )
{
    if ( show )
    {
        if ( isdefined( self.df_a1_puzzle_text ) && self.df_a1_puzzle_text == text )
            return;

        if ( isdefined( self.df_a1_puzzle_text ) )
            self df_prompt_puzzle( 0, undefined );

        self df_prompt_puzzle( 1, text );
        self.df_a1_puzzle_text = text;
        return;
    }

    if ( isdefined( self.df_a1_puzzle_text ) )
    {
        self df_prompt_puzzle( 0, undefined );
        self.df_a1_puzzle_text = undefined;
    }
}

// ---- small electric fx --------------------------------------------------------------------------
// elec_sm / elec_md (zm_transit_fx.gsc:36-37) are short player-shock bursts: played on a tag_origin that is
// deleted after `life` seconds they make a clean spark with nothing left behind. Never ended early by a
// skip notify on purpose: the burst always deletes its own carrier.

// Burst riding an entity (relay on the bus, plugged relay), `z` above its origin. fxname may come from
// df_side_burst_fx(): an undefined alias is a no-op instead of a script error.
df_a1_burst( fxname, ent, z, life )
{
    level endon( "end_game" );

    if ( !isdefined( ent ) || !isdefined( fxname ) )
        return;

    b = df_fx_loop( fxname, ent.origin + ( 0, 0, z ) );

    if ( !isdefined( b ) )
        return;

    b linkto( ent );
    wait( life );
    df_fx_stop( b );
}

// Burst at a fixed point.
df_a1_burst_at( fxname, origin, life )
{
    level endon( "end_game" );

    b = df_fx_loop( fxname, origin );

    if ( !isdefined( b ) )
        return;

    wait( life );
    df_fx_stop( b );
}

// Powered idle: an elec_sm burst on `ent` every 2-3.5 s until the entity dies or
// level notify( "df_a1_pulse_stop_" + key ). key: "relay" (roof / dropped) or "plugged" (socket).
df_a1_idle_pulse( ent, key, z )
{
    level endon( "end_game" );
    level endon( "df_a1_pulse_stop_" + key );

    while ( isdefined( ent ) )
    {
        level thread df_a1_burst( "elec_sm", ent, z, 0.6 );
        wait( randomfloatrange( 2, 3.5 ) );
    }
}

// ---- debug hooks: "!df fire a1_<x>" -> level notify( "df_debug_a1_<x>" ) (df_main) -------------------
// a1_solve1  light all four screens (Step 1 solved)      a1_tv     press the next expected screen
// a1_parts   take every remaining part (static or roof)  a1_hit    200 damage to the relay (x2 = second layer)
// a1_stop    count the running sweep as arrived           a1_relay  bring the relay (roof/ground) to player 1
// a1_build   player 1 runs the vanilla build hold where they stand (no parts, nothing built): hold use within 10 s
// a1_receiver  the phone drops the receiver now (without solving the screens)
// a1_corn    play the cornfield line where the relay is now (the once-per-game guard still applies)

df_a1_debug_hooks()
{
    level thread df_a1_hook( "a1_solve1" );
    level thread df_a1_hook( "a1_tv" );
    level thread df_a1_hook( "a1_parts" );
    level thread df_a1_hook( "a1_hit" );
    level thread df_a1_hook( "a1_stop" );
    level thread df_a1_hook( "a1_relay" );
    level thread df_a1_hook( "a1_build" );
    level thread df_a1_hook( "a1_receiver" );
    level thread df_a1_hook( "a1_corn" );
}

df_a1_hook( name )
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_" + name );
        level thread df_a1_hook_run( name );
    }
}

df_a1_hook_run( name )
{
    level endon( "end_game" );

    switch ( name )
    {
        case "a1_solve1":
            df_a1_hook_solve1();
            break;
        case "a1_tv":
            df_a1_hook_tv();
            break;
        case "a1_parts":
            df_a1_hook_parts();
            break;
        case "a1_hit":
            if ( !isdefined( level.df_relay ) )
                df_debug_print( "DF: a1_hit: no relay" );
            else
                df_relay_damage( 200 );

            break;
        case "a1_stop":
            if ( is_true( level.df_sweep_active ) )
                level notify( "df_step3_outcome", "arrived" );
            else
                df_debug_print( "DF: a1_stop: no sweep running (ride with the relay, power on)" );

            break;
        case "a1_relay":
            df_a1_hook_relay();
            break;
        case "a1_build":
            df_a1_hook_build();
            break;
        case "a1_receiver":
            if ( isdefined( level.df_parts ) && isdefined( level.df_parts[df_a1_receiver_idx()] ) )
                df_debug_print( "DF: a1_receiver: the receiver already dropped" );
            else
                df_a1_receiver_drop();

            break;
        case "a1_corn":
            df_a1_hook_corn();
            break;
    }
}

// `!df fire a1_corn`: the cornfield line at the relay's current place (roof / ground / carrier), or at player 1.
df_a1_hook_corn()
{
    ent = df_a1_relay_ent();

    if ( !isdefined( ent ) )
    {
        players = getplayers();

        if ( players.size == 0 )
            return;

        ent = players[0];
    }

    df_debug_print( "DF: a1_corn: cornfield line at " + int( ent.origin[0] ) + " " + int( ent.origin[1] ) + " " + int( ent.origin[2] ) );
    df_vox_once( "vox_maxi_near_corn_0", ent.origin + ( 0, 0, 40 ) );
}

// `!df fire a1_build`: player 1 gets 10 s to press and hold use, then the build hold runs where they stand
// (hands animation, loop, dust, complete sound); nothing is built, parts are not needed.
df_a1_hook_build()
{
    players = getplayers();

    if ( players.size == 0 )
        return;

    players[0] thread df_a1_hook_build_player();
}

df_a1_hook_build_player()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    df_debug_print( "DF: a1_build: press and hold [use] within 10 s" );
    start = gettime();

    while ( !self usebuttonpressed() )
    {
        if ( gettime() - start > 10000 )
        {
            df_debug_print( "DF: a1_build: no press, cancelled" );
            return;
        }

        wait 0.05;
    }

    ok = self df_a1_build_hold( self.origin, 200, 3 );
    df_debug_print( "DF: a1_build: result " + ok + " (1 = completed, 0 = aborted)" );
}

df_a1_hook_solve1()
{
    if ( df_is_done( "step1" ) || !isdefined( level.df_tvs ) )
    {
        df_debug_print( "DF: a1_solve1: step1 not running" );
        return;
    }

    foreach ( tv in level.df_tvs )
        df_tv_light( tv, 1 );

    level.df_tv_progress = 4;
    df_debug_print( "DF: a1_solve1: all screens on" );
    level notify( "df_step1_solved" );
}

df_a1_hook_tv()
{
    if ( df_is_done( "step1" ) || !isdefined( level.df_tvs ) )
    {
        df_debug_print( "DF: a1_tv: step1 not running" );
        return;
    }

    expected = level.df_tv_order[level.df_tv_progress];
    df_debug_print( "DF: a1_tv: pressing screen " + ( expected + 1 ) );
    level thread df_tv_press( level.df_tvs[expected], undefined );
}

df_a1_hook_parts()
{
    if ( !isdefined( level.df_parts ) || level.df_parts.size == 0 )
    {
        df_debug_print( "DF: a1_parts: no parts in the world" );
        return;
    }

    foreach ( part in level.df_parts )
    {
        if ( isdefined( part.model ) )
            df_a1_part_taken( part, undefined, "taken by debug" );
    }
}

// Moves the relay model to the first player's feet (unlinked from the bus), keeping its state light.
df_a1_hook_relay()
{
    players = getplayers();

    if ( !isdefined( level.df_relay ) || players.size == 0 )
    {
        df_debug_print( "DF: a1_relay: no relay in the world (carried or not built)" );
        return;
    }

    p = players[0];
    pos = df_ground( p.origin + anglestoforward( ( 0, p.angles[1], 0 ) ) * 60 );
    level.df_relay unlink();
    level.df_relay.origin = pos;
    level.df_relay.angles = df_model_angles( "relay", p.angles[1] );
    df_relay_idle_fx();
    df_debug_print( "DF: a1_relay: relay moved to " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) );
}

// Replaces zm_transit_ai_screecher::portal_use (vanilla body copied, zm_transit_ai_screecher.gsc:149-151):
// a player carrying the relay or a charge orb cannot take a lamp portal (WRONG INPUT cue, df_cue_deny; nothing
// is lost). The caller already removed the portal from level.portals, so it is put back for everyone else.
df_portal_use( player )
{
    if ( is_true( player.df_carrying_relay ) || isdefined( player.df_orb ) || is_true( player.df_ember ) || is_true( player.df_skull ) )
    {
        level.portals[level.portals.size] = self;
        df_cue_deny( player );
        return;
    }

    player playsoundtoplayer( "zmb_screecher_portal_warp_2d", player );
    self thread maps\mp\zm_transit_ai_screecher::teleport_player( player );
    playsoundatposition( "zmb_screecher_portal_end", self.hole.origin );
    self.hole delete();
    self.burrow_active = 0;
}

// Volume: playsoundtoplayer has no gain, so a tone is THREE instances at once (about +9 dB). An alias whose bank
// LimitCount is 1 (zmb_switch_flip) keeps a single instance and stays at its own level: pick a louder alias for
// it on the Sound Picker if it is still too quiet (owner 2026-09-11: "the phone needs to be louder").
df_a1_tone_to( player, alias )
{
    for ( i = 0; i < 3; i++ )
        player playsoundtoplayer( alias, player );
}

// ---- Blinks (owner 2026-09-11) --------------------------------------------------------------------
// Each pipe blinks its own number in a loop: tv.count flashes of 0.25 s, 0.6 s apart, then 2.5 s dark; pipes start
// 0.7 s apart so no two flash together. Stops while the pipe is lit (tv.on). Fx: dvar df_fx_pipe_flash (default
// fx_zmb_tranzit_light_glow), auditioned with !df fx.
df_a1_pipe_blink( tv )
{
    level endon( "end_game" );
    level endon( "df_step1_cleanup" );
    level endon( "df_skip_step1" );

    wait( 0.7 * tv.index );

    while ( isdefined( tv.model ) )
    {
        if ( tv.on )
        {
            wait 0.5;
            continue;
        }

        for ( k = 0; k < tv.count; k++ )
        {
            if ( tv.on || !isdefined( tv.model ) )
                break;

            df_a1_flash( df_a1_fx_pipe_flash(), tv.origin + ( 0, 0, df_a1_screen_z() ), tv.flasher );
        }

        // the locator (owner pick 2026-09-11: the blue one-shot spark) once in the dark gap, clear of the count
        wait 1.0;

        if ( !tv.on && isdefined( tv.model ) )
            df_fx_once( df_a1_fx_pipe_locator(), tv.origin + ( 0, 0, df_a1_screen_z() ) );

        wait 1.6;
    }
}

// The far signal light (DF_SIGNAL, outside the fence): the order as groups of flashes, 0.3 s each 0.7 s apart,
// 1.5 s dark between groups, 4 s dark after the message, forever while the step runs. One click per flash to the
// players within 2500 (count the clicks or the flashes). Fx: dvar df_fx_signal (default fx_zmb_tranzit_light_glow).
df_step1_signal_loop()
{
    level endon( "end_game" );
    level endon( "df_step1_cleanup" );
    level endon( "df_skip_step1" );

    c = df_coord( "DF_SIGNAL" );

    if ( !isdefined( c ) )
    {
        df_debug_print( "DF: no DF_SIGNAL anchor, the order is not shown" );
        return;
    }

    pos = c.origin + ( 0, 0, df_a1_signal_lift() ); // owner 2026-09-11: "a little higher": 70 (dvar df_signal_lift)
    level.df_s1_signal_flasher = df_a1_flasher_make( df_a1_fx_signal(), pos );
    df_debug_print( "DF: signal light at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) + " (fx " + df_a1_fx_signal() + ")" );

    while ( true )
    {
        for ( t = 0; t < 4; t++ )
        {
            tv = level.df_tvs[level.df_tv_order[t]];

            for ( k = 0; k < tv.count; k++ )
            {
                df_a1_flash( df_a1_fx_signal(), pos, level.df_s1_signal_flasher ); // no sound (owner 2026-09-11: flashes only)
            }

            wait 2.0;
        }

        // the message is closed by the same spark as the pipes (owner 2026-09-11), then dark
        df_fx_once( df_a1_fx_pipe_locator(), pos );
        wait 4;
    }
}

// The hum near the signal light (owner 2026-09-11): zmb_power_on_loop on a script_origin at DF_SIGNAL_SND for the
// whole step; gone with the step (cleanup or skip).
df_step1_signal_hum()
{
    level endon( "end_game" );

    // its own spot since 2026-09-11 (owner): DF_SIGNAL_SND, 20 above the anchor; the far light spot as fallback
    c = df_coord( "DF_SIGNAL_SND" );
    lift = 20;

    if ( !isdefined( c ) )
    {
        c = df_coord( "DF_SIGNAL" );
        lift = df_a1_signal_lift();
    }

    if ( !isdefined( c ) )
        return;

    e = spawn( "script_origin", c.origin + ( 0, 0, lift ) );
    e playloopsound( df_a1_signal_hum_alias(), 2 ); // 2 s fade-in as vanilla (zm_transit_power.gsc:408)
    df_debug_print( "DF: signal hum (" + df_a1_signal_hum_alias() + ") at " + int( c.origin[0] ) + " " + int( c.origin[1] ) + " " + int( c.origin[2] ) );

    level waittill_any( "df_step1_cleanup", "df_skip_step1" );

    if ( isdefined( e ) )
        e delete();
}

// Height of the far light and its hum over the DF_SIGNAL anchor: dvar df_signal_lift, default 70 (owner 2026-09-11).
df_a1_signal_lift()
{
    v = getdvar( "df_signal_lift" );

    if ( v != "" )
        return int( v );

    return 70;
}

// The hum alias at the far light: dvar df_signal_hum, default zmb_power_on_loop (streamed, 3D 525-750; if it stays
// silent try a loaded loop: set df_signal_hum zmb_turbine_loop, or zmb_avogadro_loop, or amb_alarm_interior_industrial).
df_a1_signal_hum_alias()
{
    v = getdvar( "df_signal_hum" );

    if ( v != "" )
        return v;

    return "zmb_meteor_loop"; // owner pick 2026-09-11 (was zmb_power_on_loop, not heard; streamed loop, 3D 50-250)
}

// Fx names the owner can swap before loading the map: set df_fx_pipe_flash <fx>, set df_fx_signal <fx>
// (any key of !df fx list). Unknown or empty = the default.
df_a1_fx_pipe_flash()
{
    v = getdvar( "df_fx_pipe_flash" );

    if ( v != "" && isdefined( level._effect[v] ) )
        return v;

    return "fx_zmb_tranzit_light_bulb_xsm"; // owner pick 2026-09-11 (Effect Picker): a glow, shown 0.7 s per flash
}

// The locator spark of a blinking pipe (dvar df_fx_pipe_locator).
df_a1_fx_pipe_locator()
{
    v = getdvar( "df_fx_pipe_locator" );

    if ( v != "" && isdefined( level._effect[v] ) )
        return v;

    return "fx_zmb_tranzit_spark_blue_lg_os"; // owner pick 2026-09-11 (Effect Picker)
}

// One flash of `fx` at pos, then the gap, so a count reads (blocks for the slot):
//   one-shot effect: fired once, 0.7 s slot;
//   loop effect (a glow): `flasher` is its permanent entity parked underground (df_a1_flasher_make): moved to pos
//   for 0.6 s, then back down. 1.2 s slot. Moving beats spawning: a spawned glow raced the client and flashes
//   were dropped (owner 2026-09-11: "spark, bulb once, spark, bulb twice").
df_a1_flash( fx, pos, flasher )
{
    if ( df_aud_fx_is_oneshot( fx ) || !isdefined( flasher ) )
    {
        df_fx_once( fx, pos );
        wait 0.7;
        return;
    }

    flasher.origin = pos;
    wait 0.6;

    if ( isdefined( flasher ) )
        flasher.origin = pos - ( 0, 0, 4000 );

    wait 0.6;
}

// The permanent glow entity of a blinking thing, parked 4000 under its spot (undefined for a one-shot fx).
df_a1_flasher_make( fx, pos )
{
    if ( df_aud_fx_is_oneshot( fx ) )
        return undefined;

    return df_fx_loop( fx, pos - ( 0, 0, 4000 ) );
}

// Removes the flasher entities of Step 1 (pipes + signal) at the end of the step or on a skip.
df_step1_flashers_stop()
{
    if ( isdefined( level.df_tvs ) )
    {
        foreach ( tv in level.df_tvs )
        {
            df_fx_stop( tv.flasher );
            tv.flasher = undefined;
        }
    }

    df_fx_stop( level.df_s1_signal_flasher );
    level.df_s1_signal_flasher = undefined;
}

df_a1_fx_signal()
{
    v = getdvar( "df_fx_signal" );

    if ( v != "" && isdefined( level._effect[v] ) )
        return v;

    return "fx_zmb_tranzit_light_bulb_xsm"; // owner pick 2026-09-11 (Effect Picker): the same glow as the pipes
}

// The pipes' lights and sparks off, the models kept (owner 2026-09-11).
df_step1_lights_off()
{
    if ( !isdefined( level.df_tvs ) )
        return;

    foreach ( tv in level.df_tvs )
    {
        df_fx_stop( tv.fx );
        tv.fx = undefined;
        df_fx_stop( tv.idle );
        tv.idle = undefined;
        tv.on = 1; // stops the blink loop for good
    }
}

// ---- roof waves (owner 2026-09-11) ----------------------------------------------------------
// While the relay rides (level.df_sweep_active) and is not locked yet: every 2.5 s a regular zombie rises from a zone
// spawn struct within 700 of the bus, up to 10 of ours alive, whatever the round. They hunt normally: on the bus
// they climb and chew the relay as the roof zombies do. Ends with the sweep or the lock.
df_a1_roof_spawner()
{
    level endon( "end_game" );
    level endon( "df_skip_step3" );

    df_debug_print( "DF: roof waves on: two zombies every 1.5 s ahead of the bus, cap " + df_a1_roof_cap() + ", until the relay locks or the sweep ends" );

    while ( is_true( level.df_sweep_active ) && !is_true( level.df_relay_locked ) )
    {
        wait 1.5;

        if ( !isdefined( level.the_bus ) || !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
            continue;

        if ( df_a1_roof_count() >= df_a1_roof_cap() || getfreeactorcount() < 1 )
            continue;

        spots = [];

        if ( isdefined( level.zones ) )
        {
            foreach ( key in getarraykeys( level.zones ) )
            {
                zone = level.zones[key];

                if ( !isdefined( zone.spawn_locations ) )
                    continue;

                foreach ( s in zone.spawn_locations )
                {
                    if ( isdefined( s.is_enabled ) && !s.is_enabled )
                        continue;

                    // within 900 of the bus and AHEAD of it (dot with its forward > 0), so the wave meets the bus
                    // and boards it instead of chasing its tail (owner 2026-09-11: "a lot of zombies getting on the roof")
                    if ( distancesquared( s.origin, level.the_bus.origin ) < 900 * 900
                        && vectordot( anglestoforward( level.the_bus.angles ), vectornormalize( s.origin - level.the_bus.origin ) ) > 0 )
                        spots[spots.size] = s;
                }
            }
        }

        if ( spots.size == 0 )
            continue;

        for ( k = 0; k < 2; k++ )
        {
            if ( df_a1_roof_count() >= df_a1_roof_cap() || getfreeactorcount() < 1 )
                break;

            spot = random( spots );
            spawner = random( level.zombie_spawners );
            ai = spawn_zombie( spawner, spawner.targetname, spot );

            if ( !isdefined( ai ) )
                continue;

            if ( isdefined( spot.script_noteworthy ) && issubstr( spot.script_noteworthy, "riser_location" ) )
                ai._rise_spot = spot;
            else
                ai.spawn_point_override = spot;

            ai.df_roof_ours = 1;
        }
    }

    df_debug_print( "DF: roof waves off" );
}

df_a1_roof_count()
{
    n = 0;

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( isdefined( ai ) && isalive( ai ) && is_true( ai.df_roof_ours ) )
            n++;
    }

    return n;
}

// The assault on the charging relay (owner 2026-09-11: "a lot of zombies"): 8 of ours alive at once solo, +3 per extra
// player. The relay has 800 hp and loses 60 a swing, so the rider has to fight, not wait.
df_a1_roof_cap()
{
    n = getplayers().size;

    if ( n < 1 )
        n = 1;

    return 8 + 3 * ( n - 1 );
}
