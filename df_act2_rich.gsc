// Dead Frequency - Act 2R "Richtofen" (power stays ON).
//   R1 "Summon the Storm": Simon Says on four fuse boxes in the Farm barn, a key card appears, inserting
//                          it at the table under the tower calls Avogadro down; he must be defeated at the
//                          tower (spec 5, R1). Failure locks the step until ONE BATTERY taken from the bus
//                          dashboard has charged all four boxes in turn (ITEM_BATTERY_RICH; consumed at the
//                          fourth). The four boxes then hold his charge and are Step 6's nodes on this side
//                          (audit #3: level.df_nodes kind "fuse").
//   R2 "Souls on the Line": N lamp posts (N = df_scaled "nodes") each swallow a quota of zombie souls
//                          (spec 5, R2); each filled lamp drops a WIRE SPOOL; the spools carried to the table
//                          build the antenna array and complete the step (audit 9, ITEM_SPOOL_RICH).
// Owner design (2026-09-07): sparks are the only Simon indicator. Classic growing sequence, replayed on a
// wrong press (audit 5). Each box keeps its own sound.
// Owner rule (2026-09-08): everything physical exists from game start: the boxes spawn at boot
// (df_r1_boot_spawn: dark, inert, a faint glow); R1 only arms them. The key card stays a reveal.
// Audit pass (2026-09-08, C-rich): capture_time / simon_len / fuse_souls rows (df_rich_scaled fallbacks
// until df_steps has them), no capture fail while he is within 900 of the tower, power-chamber softlock
// fix (R1_RICH_CHAMBER + poll), table pulses blue while he is alive at the tower, R2 beams on unfilled
// lamps, Richtofen side rules from R1 on (Avogadro every round, Jet Gun heat relief, turrets need no
// turbine from R2, power-OFF penalty at end of round).
// Earlier passes kept: models via df_model, puzzle prompt via df_prompt_puzzle, single-press pickups via
// df_press_use, lamps via df_lamps.gsc (one set per game), the inserted card stays on table slot 1.
// V2 pass (2026-09-09, V2-rich; tools/audit_steps_v2.md #1, tools/audit_art.md R1/R2, tools/audit_dialogue_v2.md):
// one battery for the four boxes (no bus respawn between boxes, drops at a downed carrier's feet), the
// shared cue grammar through the df_systems helpers (df_cue_tick = progress, df_cue_subgoal = one node
// done incl. the node -> tower trail, df_cue_fail = progress lost, df_cue_deny = wrong input,
// df_step_focus = the AVAILABLE glint, df_vox_once = a vanilla voice line once per game): no
// zmb_powerup_grabbed / zmb_spawn_powerup outside df_steps any more, box 3 tone zmb_elec_arc, a clink on
// every soul, audible capture clock in its last 30 s, the array glows on the table mast, df_touch( "r2" ),
// ITEM_BATTERY_RICH / ITEM_SPOOL_RICH said. Cross-file needs: tools/requests_V2rich.md.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_act3_vacuum;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;
#include scripts\zm\zm_transit\df_scav;
#include scripts\zm\zm_transit\df_lamps;

df_act2_rich_init()
{
    df_lamps_init();
    level thread df_r1_boot_spawn();
    df_register_step( "r1", ::df_r1_run, ::df_r1_setup );
    df_register_step( "r2", ::df_r2_run, ::df_r2_setup );
}

// Tower centre: the sq_common_area trigger (zm_transit_sq.gsc:28), fallback from the entity dump.
df_tower_center()
{
    if ( isdefined( level.sq_volume ) )
        return level.sq_volume.origin;

    return ( 7644, -464, -132 );
}

// Scaling row by name, `fallback` while df_steps has no such row yet (audit rows capture_time, simon_len
// belong to the steps agent; df_scaled itself indexes level.df_scale[key] without a check).
df_rich_scaled( key, fallback )
{
    if ( isdefined( level.df_scale ) && isdefined( level.df_scale[key] ) )
        return df_scaled( key );

    return fallback;
}

// =========================================================================================
// Shared presentation helpers (fuse boxes and lamps)
// =========================================================================================

// Controlled spark loop on a fuse box: elec_md (electrical/fx_elec_player_md, zm_transit_fx.gsc:36) is a
// short burst, so it is replayed on a fresh tag_origin every cycle and deleted after 0.6 s. s.fx2 is the
// (invisible) anchor whose existence keeps the loop alive; s.spark_period (seconds per cycle, default
// 1.0) may change while running. (Lamp sparks live in df_lamps.gsc.)
df_rich_spark_replay( s, origin )
{
    level endon( "end_game" );

    while ( isdefined( s.fx2 ) )
    {
        s.spark = df_fx_loop( "elec_md", origin );
        wait 0.6;
        df_fx_stop( s.spark );
        s.spark = undefined;
        period = 1.0;

        if ( isdefined( s.spark_period ) )
            period = s.spark_period;

        if ( period > 0.7 )
            wait( period - 0.6 );
        else
            wait 0.1;
    }

    df_fx_stop( s.spark );
    s.spark = undefined;
}

// Starts (on = 1) or stops (on = 0) the spark replay on a struct at `origin`.
df_rich_spark_set( s, origin, on )
{
    if ( on )
    {
        if ( isdefined( s.fx2 ) )
            return;

        s.fx2 = spawn( "script_model", origin );
        s.fx2 setmodel( "tag_origin" );
        level thread df_rich_spark_replay( s, origin );
        return;
    }

    df_fx_stop( s.fx2 );
    s.fx2 = undefined;
    df_fx_stop( s.spark );
    s.spark = undefined;
}

// Replaces the glow FX carried in s.glow (undefined = none). Glows are the map's own light glows
// (zm_transit_fx.gsc:54-55: fx_zmb_tranzit_light_glow, fx_zmb_tranzit_light_glow_xsm).
df_rich_glow_set( s, origin, fxname )
{
    df_fx_stop( s.glow );
    s.glow = undefined;

    if ( isdefined( fxname ) )
        s.glow = df_fx_loop( fxname, origin );
}

df_fx_stop_after( ent, seconds )
{
    level endon( "end_game" );
    wait( seconds );
    df_fx_stop( ent );
}

// A glinting pickup model of `kind` at pos (fx_zmb_tranzit_key_glint, zm_transit_fx.gsc:105), optionally
// riding `link` (the bus: linkto as df_act1 does for roof parts). Returns a struct {.model .fx}.
df_rich_pickup_place( kind, pos, link )
{
    p = spawnstruct();
    p.model = spawn( "script_model", pos );
    p.model setmodel( df_model( kind ) );
    p.model.angles = df_model_angles( kind, randomint( 360 ) );
    p.fx = df_fx_loop( "fx_zmb_tranzit_light_glow", pos + ( 0, 0, 14 ) );

    if ( isdefined( link ) )
    {
        p.model linkto( link );

        if ( isdefined( p.fx ) )
            p.fx linkto( link );
    }

    return p;
}

// Removes a pickup placed by df_rich_pickup_place (safe on undefined / already taken).
df_rich_pickup_remove( p )
{
    if ( !isdefined( p ) )
        return;

    df_fx_stop( p.fx );
    p.fx = undefined;

    if ( isdefined( p.model ) )
        p.model delete();

    p.model = undefined;
}

// =========================================================================================
// R1 - Summon the Storm
// =========================================================================================

// Boot: the boxes exist from game start (owner rule), dark and inert with a faint glow. Waits for the
// coords registry (df_boot runs df_coords_init first, but the anchors may be overridden a frame later).
df_r1_boot_spawn()
{
    level endon( "end_game" );

    while ( !isdefined( level.df_coords ) || !isdefined( level.df_coords["DF_FUSE_4"] ) )
        wait 0.5;

    df_r1_spawn_fuses();
    // audit art #2: the step's focus (AVAILABLE sting + glint until the first press) is the barn centre;
    // registered as soon as the boxes exist so df_steps has it the moment R1 opens
    df_step_focus( "r1", df_r1_focus_pos() );
}

// Centre of the four boxes: the R1 focus, the sub-goal cue spot, the card position fallback.
df_r1_boxes_center()
{
    center = ( 0, 0, 0 );

    foreach ( fuse in level.df_fuses )
        center = center + fuse.origin;

    return center * ( 1.0 / level.df_fuses.size );
}

df_r1_run()
{
    level endon( "end_game" );

    df_r1_spawn_fuses(); // no-op after the boot spawn
    level.df_r1_locked = 0;
    level.df_simon_final = df_rich_scaled( "simon_len", 6 );
    level.df_r1_capture_time = df_rich_scaled( "capture_time", 240 );
    level thread df_r1_skip_cleanup();
    level thread df_r1_hold_avogadro();
    level thread df_r1_debug_hooks();
    level thread df_fuse_prompt_poll();

    foreach ( fuse in level.df_fuses )
        level thread df_fuse_watch( fuse );

    df_r1_arm( 1 );
    // audit art R1.2: "the signal went to the farm": one trail from the table to the barn when R1 opens
    // (df_soul_fly = the richtofen_sparks runner, df_systems), and the focus glint on the barn centre
    df_step_focus( "r1", df_r1_focus_pos() );
    level thread df_soul_fly( df_coord( "DF_SOCKET" ).origin, df_r1_boxes_center() + ( 0, 0, 40 ) );

    while ( true )
    {
        // wait for a press (or the debug shortcut) while unlocked
        level waittill_either( "df_fuse_pressed", "df_debug_simon_solved" );

        if ( is_true( level.df_r1_locked ) )
            continue;

        if ( is_true( level.df_debug_simon ) || is_true( level.df_r1_simon_done ) )
        {
            level.df_debug_simon = 0;
            solved = 1; // audit v3 #5: a Simon solved once stays solved; a failed capture costs the battery trip only
        }
        else
            solved = df_simon_play();

        if ( !solved )
            continue;

        level.df_r1_simon_done = 1;

        // solved: the boxes stop being a puzzle and spark until the capture is decided
        df_r1_arm( 0 );

        foreach ( fuse in level.df_fuses )
            df_rich_spark_set( fuse, fuse.led_origin, 1 );

        // owner design: a key card appears between the boxes; inserting it at the tower calls him down
        df_r1_card_spawn();
        inserter = df_r1_wait_card_inserted();
        df_r1_summon( inserter );
        captured = df_r1_wait_capture();
        level notify( "df_r1_capture_over" );

        if ( captured )
        {
            df_r1_capture_burst();
            df_r1_card_table_glow(); // the card on the table stops blinking and just glows
            break;
        }

        foreach ( fuse in level.df_fuses )
            df_rich_spark_set( fuse, fuse.led_origin, 0 );

        df_r1_lock_until_refilled();
        level thread df_r1_refilled_kick(); // the loop resumes by itself: no Simon to replay
    }

    df_r1_finish();
}

// The four boxes (df_model "fuse" at DF_FUSE_1..4, angles already kind-adjusted by df_coords) with a
// hint-less use trigger each: the "Press F" prompt is a hideable puzzle prompt (df_fuse_prompt_poll).
// Idempotent: the boot thread and df_r1_run / df_r1_setup all call it.
df_r1_spawn_fuses()
{
    if ( isdefined( level.df_fuses ) )
        return;

    level.df_fuses = [];
    // per-box sounds (all verified: _zm_ai_avogadro.gsc:963/939, zm_transit_ai_screecher.gsc:176,
    // Core/_zm_traps.gsc:438). Box 3 was zmb_powerup_grabbed = the STEP DONE sting (audit art R1.3).
    level.df_fuse_snd = [];
    level.df_fuse_snd[0] = "zmb_avogadro_warp_in";
    level.df_fuse_snd[1] = "zmb_avogadro_warp_out";
    level.df_fuse_snd[2] = "zmb_screecher_portal_arrive";
    level.df_fuse_snd[3] = "zmb_zombie_arc"; // sound audit 2026-09-09: zmb_elec_arc is in no TranZit bank (silent)

    for ( i = 0; i < 4; i++ )
    {
        c = df_coord( "DF_FUSE_" + ( i + 1 ) );
        fuse = spawnstruct();
        fuse.idx = i;
        fuse.origin = c.origin;
        fuse.led_origin = c.origin + ( 0, 0, 10 );
        fuse.souls = 0;
        fuse.model = spawn( "script_model", c.origin );
        fuse.model setmodel( df_model( "fuse" ) );
        fuse.model.angles = c.angles;
        fuse.trig = df_spawn_use_trigger( c.origin, 56, 90, "" );
        df_rich_glow_set( fuse, fuse.led_origin, "fx_zmb_tranzit_light_glow_xsm" );
        level.df_fuses[i] = fuse;
    }

    level thread df_rich_side_watch();
}

// The Simon boxes belong to Richtofen's side: when the fork locks Maxis they go (owner 2026-09-11: seeing the
// other side's props is confusing). Before the fork everything physical exists, as the owner wants.
df_rich_side_watch()
{
    level endon( "end_game" );
    level waittill( "df_side_locked", side );

    if ( side != "maxis" )
        return;

    df_r1_retire_boxes();
}

df_r1_retire_boxes()
{
    if ( !isdefined( level.df_fuses ) )
        return;

    foreach ( fuse in level.df_fuses )
    {
        df_fx_stop( fuse.glow );
        fuse.glow = undefined;

        if ( isdefined( fuse.trig ) )
            fuse.trig delete();

        if ( isdefined( fuse.model ) )
            fuse.model delete();
    }

    level.df_fuses = [];
    df_debug_print( "DF: Maxis side locked, the four Simon boxes are gone" );
}

// R2: a player standing under a hungry lamp pulls the dead to it (owner 2026-09-11: "zombies take a while to
// spawn"). Every 3 s, per player within 450 of an unfilled set lamp: two regular zombies rise from the zone spawn
// structs within 600 of that lamp, while fewer than 20 zombies live and the engine has free actors. They hunt
// normally. Off with the step.
df_r2_lamp_spawner()
{
    level endon( "end_game" );
    level endon( "df_r2_done" );
    level endon( "df_skip_r2" );

    while ( true )
    {
        wait 3;

        if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
            continue;

        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) )
                continue;

            lamp = df_lamp_nearest( player.origin, 450, 1 );

            if ( !isdefined( lamp ) )
                continue;

            // local pressure: zombies within 1200 of THIS player (owner 2026-09-11: the map-wide cap blocked the waves)
            if ( df_zombies_near( player.origin, 1200 ) >= 12 || getfreeactorcount() < 2 )
                continue;

            spots = df_r2_lamp_spots( lamp );

            if ( spots.size == 0 )
                continue;

            for ( k = 0; k < 2; k++ )
            {
                spot = random( spots );
                spawner = random( level.zombie_spawners );
                ai = spawn_zombie( spawner, spawner.targetname, spot );

                if ( !isdefined( ai ) )
                    continue;

                if ( isdefined( spot.script_noteworthy ) && issubstr( spot.script_noteworthy, "riser_location" ) )
                    ai._rise_spot = spot;
                else
                    ai.spawn_point_override = spot;
            }

            df_debug_print( "DF: r2 two zombies pulled to lamp " + lamp.name + " (" + player.name + " under it)" );
        }
    }
}

// Zone spawn structs within 600 of the lamp, cached on the lamp.
df_r2_lamp_spots( lamp )
{
    if ( isdefined( lamp.df_spots ) )
        return lamp.df_spots;

    // within 1200, else the six nearest of the map (fog lamps sit between zones: 600 found nothing, owner 2026-09-11)
    lamp.df_spots = df_spawn_spots_near( lamp.origin, 1200 );
    df_debug_print( "DF: r2 lamp " + lamp.name + ": " + lamp.df_spots.size + " spawn structs for its waves" );
    return lamp.df_spots;
}

// R1 done: triggers and sparks go, the boxes keep a steady glow (they hold his charge now) and become
// Step 6's nodes on this side; the Richtofen side rules start.
df_r1_finish()
{
    foreach ( fuse in level.df_fuses )
    {
        if ( isdefined( fuse.trig ) )
            fuse.trig delete();

        fuse.trig = undefined;
        df_rich_spark_set( fuse, fuse.led_origin, 0 );
        df_rich_glow_set( fuse, fuse.led_origin, "fx_zmb_tranzit_light_glow" );
    }

    df_r1_export_nodes();
    df_r1_side_rules_start();
    df_complete( "r1" );
}

// "!df goto" past r1: the boxes (already there since boot) count as charged, the card sits on the table.
df_r1_setup()
{
    df_r1_spawn_fuses();
    df_r1_export_nodes();
    df_r1_card_table_place();
    df_r1_card_table_glow();
    df_r1_side_rules_start();
}

// Audit #3: Richtofen's Step 6 nodes = the sparking block at the power station, DF_CORE (same node struct shape;
// df_act3_vacuum reads kind "fuse"). The R2 lamps are NOT exported on this side.
// Step 6 nodes on Richtofen's side (owner 2026-09-11): the reactor core of the power station, where Avogadro sleeps
// (vanilla ent "core_mover", zm_transit_power.gsc powerevent). Four nodes 45 units around it, so the four charges
// are four 5 s draws at the same place: the whole Jet Gun emptied into the core. The barn boxes stay R1's.
// Fallback when the core ent is missing: the four boxes as before.
df_r1_export_nodes()
{
    level.df_nodes = [];
    core = df_coord( "DF_CORE" ); // the sparking transformer block on the power station bridge (owner 2026-09-11)
    pos = undefined;

    if ( isdefined( core ) )
        pos = core.origin;
    else
    {
        ent = getent( "core_mover", "targetname" );

        if ( isdefined( ent ) )
            pos = ent.origin;
    }

    if ( isdefined( pos ) )
    {
        offs = [];
        offs[0] = ( 25, 25, 0 );
        offs[1] = ( 25, -25, 0 );
        offs[2] = ( -25, -25, 0 );
        offs[3] = ( -25, 25, 0 );

        for ( i = 0; i < 4; i++ )
        {
            node = spawnstruct();
            node.origin = pos + offs[i];
            node.name = "core_" + ( i + 1 );
            node.kind = "core";
            level.df_nodes[level.df_nodes.size] = node;
        }

        df_debug_print( "DF: r1 done: Step 6 nodes = the transformer block at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) + " (four draws)" );
        return;
    }

    df_debug_print( "DF: r1 done: no DF_CORE anchor and no core_mover ent, the four boxes are the Step 6 nodes" );

    foreach ( fuse in level.df_fuses )
    {
        node = spawnstruct();
        node.origin = fuse.led_origin;
        node.name = "fuse_" + ( fuse.idx + 1 );
        node.kind = "fuse";
        level.df_nodes[level.df_nodes.size] = node;
    }
}

// "!df goto" past r1: everything R1 added goes away (triggers, sparks, card, battery, glints, carrier
// state, prompts, hum). The box models stay: they exist from boot and are Step 6's nodes.
df_r1_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_r1_done" );
    level waittill( "df_skip_r1" );

    foreach ( fuse in level.df_fuses )
    {
        if ( isdefined( fuse.trig ) )
            fuse.trig delete();

        fuse.trig = undefined;
        df_rich_spark_set( fuse, fuse.led_origin, 0 );
        df_rich_glow_set( fuse, fuse.led_origin, "fx_zmb_tranzit_light_glow_xsm" );
    }

    df_fx_stop( level.df_card_fx );
    level.df_card_fx = undefined;
    df_fx_stop( level.df_socket_marker );
    level.df_socket_marker = undefined;
    level notify( "df_r1_hum_stop" );

    if ( isdefined( level.df_card ) )
        level.df_card delete();

    df_r1_card_table_remove(); // the inserted card that stays on the table (slot 1)
    df_r1_battery_remove();
    level.df_card = undefined;
    level.df_card_carrier = undefined;
    level.df_card_held = 0;
    level.df_r1_armed = 0;
    level.df_r1_in_chamber = 0;

    foreach ( player in getplayers() )
    {
        player df_prompt( 0, undefined );
        player df_prompt_puzzle( 0, undefined );

        if ( is_true( player.df_carrying_card ) )
            df_r1_card_release( player );
    }
}

// Armed = the Simon can be started (unlocked, not solved): the boxes carry the full glow so players know
// they are live; otherwise (boot, solved, locked) the faint one.
df_r1_arm( on )
{
    level.df_r1_armed = on;

    foreach ( fuse in level.df_fuses )
    {
        if ( on )
            df_rich_glow_set( fuse, fuse.led_origin, "fx_zmb_tranzit_light_glow" );
        else
            df_rich_glow_set( fuse, fuse.led_origin, "fx_zmb_tranzit_light_glow_xsm" );
    }
}

// Puzzle prompt ("Press F", hideable with level.df_hints = 0) for players standing at a box while the
// Simon is armed. The trigger itself has no hint string.
df_fuse_prompt_poll()
{
    level endon( "end_game" );
    level endon( "df_r1_done" );
    level endon( "df_skip_r1" );

    while ( true )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            near = 0;

            if ( is_true( level.df_r1_armed ) && is_player_valid( player ) )
            {
                foreach ( fuse in level.df_fuses )
                {
                    if ( distancesquared( player.origin, fuse.origin ) < 70 * 70 )
                        near = 1;
                }
            }

            player df_prompt( near, "Press [{+activate}]" ); // audit v3 #10: a mechanic prompt, always shown
        }
    }
}

// Every press on a box is a Simon input (notify with the box index). A press while locked only buzzes.
df_fuse_watch( fuse )
{
    level endon( "end_game" );
    level endon( "df_r1_done" );
    level endon( "df_skip_r1" );

    while ( true )
    {
        fuse.trig waittill( "trigger", who );

        if ( !isplayer( who ) )
            continue;

        df_touch( "r1" );

        if ( is_true( level.df_r1_locked ) )
        {
            df_simon_buzzer( fuse );
            continue;
        }

        level.df_fuse_last_who = who;
        level notify( "df_fuse_pressed", fuse.idx );
        wait 0.2;
    }
}

// One spark on a box for `seconds`: medium electric arcs (elec_md, the trap effect) switched off by us so
// it reads as a clean on/off signal, plus the box sound. (switch_sparks lingers and stacks: never use it.)
df_fuse_blink( fuse, seconds )
{
    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", fuse.led_origin ); // owner pick 2026-09-11 (Effect Picker)
    playsoundatposition( level.df_fuse_snd[fuse.idx], fuse.origin );
    wait( seconds );
}

// Classic Simon: the sequence grows by one spark each round and is replayed from the start; the
// players repeat it by pressing the boxes. Repeats are allowed (1, 2, 1 ...). Wrong press: buzzer and
// the SAME sequence again (audit 5, like Moon). Returns 1 at the final length (level.df_simon_final,
// df_scaled "simon_len"), 0 when abandoned (20 s without input).
df_simon_play()
{
    level endon( "end_game" );
    level endon( "df_skip_r1" );

    final_len = level.df_simon_final;
    seq = [];

    while ( seq.size < final_len )
    {
        seq[seq.size] = df_simon_pick( seq );
        result = df_simon_round( seq, final_len );

        while ( result == "wrong" )
        {
            wait 1.2;
            result = df_simon_round( seq, final_len );
        }

        if ( result == "gone" )
        {
            df_debug_print( "DF: simon abandoned (no input)" );
            return 0;
        }

        wait 0.7;
    }

    df_simon_success_arpeggio();
    return 1;
}

// One Simon round: shows `seq` (validated timing 0.7 s on, 0.5 s off) and reads the presses.
// Returns "ok", "wrong" (buzzer played) or "gone" (20 s without a press).
df_simon_round( seq, final_len )
{
    shown = "";

    foreach ( idx in seq )
        shown = shown + ( idx + 1 ) + " ";

    df_debug_print( "DF: simon " + seq.size + "/" + final_len + " boxes: " + shown );
    wait 0.8;

    foreach ( idx in seq )
    {
        df_fuse_blink( level.df_fuses[idx], 0.7 );
        wait 0.5;
    }

    for ( i = 0; i < seq.size; i++ )
    {
        level thread df_simon_input_timeout();
        level waittill( "df_fuse_pressed", pressed );
        level notify( "df_simon_timeout_cancel" );

        if ( !isdefined( pressed ) )
            return "gone";

        if ( pressed != seq[i] )
        {
            df_simon_buzzer( level.df_fuses[pressed] );
            df_debug_print( "DF: simon wrong at " + ( i + 1 ) + ", replay" );
            return "wrong";
        }

        df_simon_click( level.df_fuses[pressed] );
    }

    return "ok";
}

// Correct press: a mechanical click (the power switch flip, zm_transit_power.gsc:57) and a short spark
// with the box's own sound.
df_simon_click( fuse )
{
    playsoundatposition( "zmb_switch_flip", fuse.origin );
    level thread df_fuse_blink( fuse, 0.25 );
}

// Wrong press (or a press while locked): the WRONG INPUT cue (df_cue_deny = the Pack-a-Punch deny buzzer,
// _zm_perks.gsc:795) to the presser (level.df_fuse_last_who; everyone when unknown) plus the bus
// power-down thump at the box (zm_transit_bus.gsc:3097, loud) so the barn hears which box was wrong.
df_simon_buzzer( fuse )
{
    who = level.df_fuse_last_who;

    if ( isdefined( who ) && isplayer( who ) )
        df_cue_deny( who );
    else
    {
        foreach ( player in getplayers() )
            df_cue_deny( player );
    }

    playsoundatposition( "zmb_bus_emp_shutdown", fuse.origin );
}

// Solved: three rising clinks 0.2 s apart to every player (2D so the whole team hears it), one alias
// only: the PROGRESS TICK zmb_buildable_piece_add (zm_transit_sq.gsc:1074). The ONE sub-goal cue of the
// solve is the card's arrival (df_r1_card_spawn_fx), not five stings on the boxes (audit art R1.4).
df_simon_success_arpeggio()
{
    for ( i = 0; i < 3; i++ )
    {
        foreach ( player in getplayers() )
            player playsoundtoplayer( "zmb_buildable_piece_add", player );

        wait 0.2;
    }
}

// Next box of the sequence: random, mixed with the clock so games differ, never the same box three
// times in a row (repeats of two stay possible).
df_simon_pick( seq )
{
    for ( tries = 0; tries < 10; tries++ )
    {
        idx = ( randomint( 4 ) + int( gettime() / 37 ) ) % 4;

        if ( seq.size >= 2 && seq[seq.size - 1] == idx && seq[seq.size - 2] == idx )
            continue;

        return idx;
    }

    return ( seq[seq.size - 1] + 1 ) % 4;
}

// 20 s without a press: fires the press notify with no index, which the round reads as "gone".
df_simon_input_timeout()
{
    level endon( "end_game" );
    level endon( "df_skip_r1" );
    level endon( "df_simon_timeout_cancel" );
    wait 20;
    level notify( "df_fuse_pressed" );
}

// ---- key card (owner design 2026-09-07) --------------------------------------------------
// Solving the Simon does not call Avogadro yet: a key card descends between the fuse boxes. Carry it
// to the table under the tower; inserting it calls him down at the tower.

// The anchor DF_CARD_SPAWN (coords registry) 36 units above its floor; without it the old spot: centre
// of the four boxes, 40 units above the barn floor.
df_r1_card_pos()
{
    c = df_coord( "DF_CARD_SPAWN" );

    if ( isdefined( c ) )
        return df_ground( c.origin ) + ( 0, 0, 36 );

    return df_ground( df_r1_boxes_center() + ( 0, 0, 60 ) ) + ( 0, 0, 40 );
}

// Dramatic arrival: a rising light column for 3 s (fx_zmb_tranzit_power_rising, zm_transit_fx.gsc:119),
// Avogadro's descend flash and thunder, then the SUB-GOAL cue (df_cue_subgoal: NavCard chime + side
// one-shot at the card) the moment the card appears: the Simon's one "done" sound, at the barn.
df_r1_card_spawn_fx( pos )
{
    // the shared item arrival AT the card (owner 2026-09-11: the old ground column stood away from the card)
    df_item_arrival( pos );
    wait 0.8;
    df_cue_subgoal( pos );
}

// The AVAILABLE glint of R1 sits on the first box's LED, not in the air at the barn centre (owner 2026-09-11:
// "a floating light bulb in the middle for nothing").
df_r1_focus_pos()
{
    if ( isdefined( level.df_fuses ) && level.df_fuses.size > 0 && isdefined( level.df_fuses[0].led_origin ) )
        return level.df_fuses[0].led_origin + ( 0, 0, 6 );

    return df_r1_boxes_center() + ( 0, 0, 40 );
}

df_r1_card_spawn()
{
    pos = df_r1_card_pos();
    df_r1_card_spawn_fx( pos );
    df_r1_card_place( pos );
    df_say( "R1_RICH_CARD" );
    df_debug_print( "DF: key card at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) );
}

// The card model (df_model "card" = p6_zm_keycard: vanilla spawns it as a plain script_model too,
// _zm_utility.gsc:4609 place_navcard), its glint (fx_zmb_tranzit_key_glint, zm_transit_fx.gsc:105) and
// the slow float unless level.df_card_float is 0 (owner test switch). Used by the first spawn and drops.
df_r1_card_place( pos )
{
    level.df_card = spawn( "script_model", pos );
    level.df_card setmodel( df_model( "card" ) );
    level.df_card.angles = ( 0, randomint( 360 ), 0 );
    level.df_card_fx = df_fx_loop( "fx_zmb_tranzit_light_glow", pos + ( 0, 0, 10 ) );
    level.df_card_carrier = undefined;

    if ( !isdefined( level.df_card_float ) || level.df_card_float != 0 )
        level thread df_r1_card_float( level.df_card, pos );
}

// ---- the card on the table (owner 2026-09-08) --------------------------------------------
// Inserting the card does not consume it: it STAYS on the table under the tower, slot 1 (the middle
// one), upright and facing the table's front, next to the plugged relay (slot 0) and the orb (slot 2).
// While Avogadro is still out there it keeps a small glint (fx_zmb_tranzit_key_glint, zm_transit_fx.gsc:105);
// once he is captured the glint becomes a steady faint glow (fx_zmb_tranzit_light_glow_xsm,
// zm_transit_fx.gsc:55). Only df_r1_skip_cleanup (`!df goto` past R1) removes it.

// Slot 1 plus 8 units: the card pose is pitch 90 (df_coords: upright, face along the front), and its
// origin sits mid-card (vanilla lays it flat with the origin ON the card, _zm_utility.gsc:4609
// place_navcard), so half its length would be inside the table top without the lift. Tune here.
df_r1_card_table_pos()
{
    return df_table_slot( 1 ) + ( 0, 0, 2 ); // owner 2026-09-11: was 8, the card floated over the table
}

df_r1_card_table_place()
{
    df_r1_card_table_remove();
    pos = df_r1_card_table_pos();
    level.df_card_table = spawn( "script_model", pos );
    level.df_card_table setmodel( df_model( "card" ) );
    level.df_card_table.angles = df_model_angles( "card", df_table_yaw() );
    level.df_card_table_fx = df_fx_loop( "fx_zmb_tranzit_light_glow", pos + ( 0, 0, 10 ) );
    df_debug_print( "DF: key card on the table, slot 1" );
}

// Avogadro is captured: the glint gives way to the steady faint glow for the rest of the game.
df_r1_card_table_glow()
{
    if ( !isdefined( level.df_card_table ) )
        return;

    df_fx_stop( level.df_card_table_fx );
    level.df_card_table_fx = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", level.df_card_table.origin + ( 0, 0, 6 ) );
}

df_r1_card_table_remove()
{
    df_fx_stop( level.df_card_table_fx );
    level.df_card_table_fx = undefined;

    if ( isdefined( level.df_card_table ) )
        level.df_card_table delete();

    level.df_card_table = undefined;
}

// Slow rotation (rotateyaw, as _zm_tombstone.gsc:332) with a gentle 6-unit bob until the card is taken.
df_r1_card_float( card, base )
{
    level endon( "end_game" );
    level endon( "df_skip_r1" );

    up = 1;

    while ( isdefined( card ) )
    {
        card rotateyaw( 360, 8 );

        for ( t = 0; t < 4 && isdefined( card ); t++ )
        {
            if ( up )
                card moveto( base + ( 0, 0, 6 ), 2, 0.8, 0.8 );
            else
                card moveto( base - ( 0, 0, 6 ), 2, 0.8, 0.8 );

            up = !up;
            wait 2;
        }
    }
}

// Pickup and insertion are single presses (df_press_use). The card drops where a carrier goes down or
// leaves. Returns the player who inserted it.
df_r1_wait_card_inserted()
{
    level endon( "end_game" );

    socket = df_coord( "DF_SOCKET" ).origin;
    df_fx_stop( level.df_socket_marker );
    level.df_socket_marker = df_fx_loop( "fx_zmb_tranzit_light_glow", socket + ( 0, 0, 40 ) );

    while ( true )
    {
        wait 0.05; // df_press_use is edge-triggered: poll at 0.05 s (df_systems.gsc)
        df_r1_card_carrier_check();

        foreach ( player in getplayers() )
        {
            if ( df_r1_card_player_tick( player, socket ) )
                return player;
        }
    }
}

// df_card_held is the truth while carried: a disconnected player's entity reference turns undefined, so
// df_card_carrier alone cannot tell "nobody carries it" from "the carrier left". Drops on down / leave.
df_r1_card_carrier_check()
{
    if ( !is_true( level.df_card_held ) )
        return;

    carrier = level.df_card_carrier;

    if ( !isdefined( carrier ) || !isplayer( carrier ) )
    {
        df_r1_card_drop( level.df_card_carrier_pos, undefined );
        return;
    }

    level.df_card_carrier_pos = carrier.origin;

    if ( carrier maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
        df_r1_card_drop( carrier.origin, carrier );
}

// One player's prompts and presses for this frame. Returns 1 when this player inserted the card.
df_r1_card_player_tick( player, socket )
{
    if ( !is_player_valid( player ) )
    {
        player df_prompt( 0, undefined );
        return 0;
    }

    if ( isdefined( level.df_card_carrier ) && player == level.df_card_carrier )
    {
        near = distancesquared( player.origin, socket ) < 150 * 150;
        player df_prompt( near, "Press [{+activate}] to insert the key card" );

        if ( !near || !player df_press_use() )
            return 0;

        df_r1_card_release( player );
        df_fx_stop( level.df_socket_marker );
        level.df_socket_marker = undefined;
        df_cue_subgoal( socket + ( 0, 0, 30 ) ); // card accepted = a sub-goal (audit art R1.4)
        df_r1_card_table_place();
        df_debug_print( "DF: key card inserted" );
        return 1;
    }

    if ( isdefined( level.df_card ) && !is_true( level.df_card_held ) )
    {
        near = distancesquared( player.origin, level.df_card.origin ) < 100 * 100;
        player df_prompt( near, "Press [{+activate}] to take the key card" );

        if ( near && player df_press_use() )
        {
            player df_prompt( 0, undefined );
            df_r1_card_take( player );
        }

        return 0;
    }

    // someone else carries it: bystanders who stood next to it lose their pickup prompt
    player df_prompt( 0, undefined );
    return 0;
}

// Carry notice via df_scav (kind "card"), pickup sound zm_transit_buildables.gsc:249.
df_r1_card_take( player )
{
    df_fx_stop( level.df_card_fx );
    level.df_card_fx = undefined;
    level.df_card delete();
    level.df_card = undefined;
    level.df_card_carrier = player;
    level.df_card_carrier_pos = player.origin;
    level.df_card_held = 1;
    player.df_carrying_card = 1;
    df_scav_carry_set( "card", 1, 1, player );
    player playsound( "zmb_buildable_pickup" );
    df_debug_print( "DF: key card taken" );
}

df_r1_card_release( player )
{
    level.df_card_carrier = undefined;
    level.df_card_held = 0;
    player.df_carrying_card = 0;
    df_scav_carry_clear( "card" );
    player df_prompt( 0, undefined );
}

df_r1_card_drop( pos, player )
{
    level.df_card_held = 0;

    if ( isdefined( player ) )
        df_r1_card_release( player );
    else
        level.df_card_carrier = undefined;

    df_r1_card_place( df_ground( pos ) + ( 0, 0, 10 ) );
    df_debug_print( "DF: key card dropped" );
}

// ---- summon ------------------------------------------------------------------------------

// Key card in the table: storm and lightning over the tower, a dramatic power sound, a rising hum at the
// table until he lands, then Avogadro is called back (spec 8.2: cloud_update() returns him at once when
// level.round_number >= return_round) in the inserting player's region, and warped next to the table
// once he has landed. Softlock fix (audit 5): while he is still chained in the power chamber (nobody has
// released him with the power on) no capture clock runs; R1_RICH_CHAMBER points at the power room and
// df_r1_wait_chamber calls him down the moment he is free.
df_r1_summon( inserter )
{
    tower_top = df_tower_center() + ( 0, 0, 900 );
    storm = df_fx_loop( "fx_zmb_avog_storm", tower_top );
    level thread df_fx_stop_after( storm, 25 );
    df_tower_fx_start( "rich" );
    level thread df_tower_fx_stop_after( 12 );
    playsoundatposition( "zmb_avogadro_spawn_3d", df_coord( "DF_SOCKET" ).origin );
    level thread df_r1_summon_hum();
    level thread df_r1_table_pulse();

    foreach ( player in getplayers() )
        player playsoundtoplayer( "zmb_power_off_quad", player );

    if ( !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) )
    {
        df_say( "R1_RICH_SUMMON" );
        df_debug_print( "DF: no avogadro entity to summon" );
        return;
    }

    df_debug_print( "DF: avogadro state " + level.avogadro.state );
    level.df_r1_summoned = 1;

    if ( level.avogadro.state == "chamber" || level.avogadro.state == "wait_for_player" )
    {
        level.df_r1_in_chamber = 1;
        df_say( "R1_RICH_CHAMBER" );
        level thread df_r1_wait_chamber( inserter );
        return;
    }

    df_say( "R1_RICH_SUMMON" );

    if ( level.avogadro.state == "cloud" )
        df_r1_call_down( inserter );

    // roaming, on the bus or leaving right now ("exiting"): the tower thread waits for him to land and
    // calls him back should he reach the cloud again
    level thread df_r1_keep_avogadro_at_tower( inserter );
}

// Polls Avogadro out of the power chamber (vanilla releases him when a player looks at the core with
// the power on, _zm_ai_avogadro.gsc:312-356: "wait_for_player" -> "chasing"). Then the normal summon.
df_r1_wait_chamber( inserter )
{
    level endon( "end_game" );
    level endon( "df_r1_capture_over" );
    level endon( "df_skip_r1" );

    while ( isdefined( level.avogadro ) && isdefined( level.avogadro.state ) && ( level.avogadro.state == "chamber" || level.avogadro.state == "wait_for_player" ) )
        wait 0.5;

    level.df_r1_in_chamber = 0;

    if ( !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) )
        return;

    df_debug_print( "DF: avogadro released, state " + level.avogadro.state );
    df_say( "R1_RICH_SUMMON" );

    if ( level.avogadro.state == "cloud" )
        df_r1_call_down( inserter );

    level thread df_r1_keep_avogadro_at_tower( inserter );
}

// Audit 4: while he is alive within 900 of the tower the table pulses blue (the Richtofen lamp light,
// fx_zmb_tranzit_light_safety_ric, zm_transit_fx.gsc:115): 5 s on, a short gap, until the capture ends.
df_r1_table_pulse()
{
    level endon( "end_game" );
    level endon( "df_r1_capture_over" );
    level endon( "df_skip_r1" );

    pos = df_coord( "DF_SOCKET" ).origin + ( 0, 0, 30 );

    while ( true )
    {
        if ( !df_r1_avogadro_near_tower() )
        {
            wait 1;
            continue;
        }

        fx = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", pos );
        wait 5;
        df_fx_stop( fx );
        wait 0.6;
    }
}

// True while Avogadro is down (idle / chasing / phasing) within 900 units of the tower centre.
df_r1_avogadro_near_tower()
{
    if ( !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) )
        return false;

    s = level.avogadro.state;

    if ( s != "idle" && s != "chasing" && s != "phasing" )
        return false;

    return distancesquared( level.avogadro.origin, df_tower_center() ) < 900 * 900;
}

// The reactor's rising power sound at the table (zm_transit_power.gsc:399-409: zmb_power_rise_start,
// zmb_power_rise_loop at 0.75, zmb_power_rise_stop) until Avogadro has landed, at most 15 s.
df_r1_summon_hum()
{
    level endon( "end_game" );

    hum = spawnstruct();
    origin = df_coord( "DF_SOCKET" ).origin + ( 0, 0, 40 );
    hum.snd = spawn( "script_origin", origin );
    hum.snd playsound( "zmb_power_rise_start" );
    hum.snd playloopsound( "zmb_power_rise_loop", 0.75 );
    level thread df_r1_summon_hum_timeout();
    level waittill_any( "df_r1_avogadro_landed", "df_r1_hum_stop", "df_r1_capture_over" );

    if ( isdefined( hum.snd ) )
    {
        hum.snd stoploopsound();
        hum.snd playsound( "zmb_power_rise_stop" );
        wait 1;
        hum.snd delete();
    }
}

df_r1_summon_hum_timeout()
{
    level endon( "end_game" );
    level endon( "df_r1_hum_stop" );
    wait 15;
    level notify( "df_r1_hum_stop" );
}

// In the cloud: bring him down over `player`'s region. His cloud drifts to a random region every 30 s
// (cloud_update_fx); without this he comes down anywhere, waits 30 s for a player and leaves.
df_r1_call_down( player )
{
    region = "cornfield";

    if ( isdefined( player ) && isplayer( player ) )
        region = df_region_of_player( player, region );

    level.avogadro.current_region = region;
    level.avogadro.return_round = level.round_number;
    df_debug_print( "DF: avogadro called down over " + region );
}

// The inserter while alive, else any living player: whose region he is called down to.
df_r1_summon_target( inserter )
{
    if ( isdefined( inserter ) && is_player_valid( inserter ) )
        return inserter;

    foreach ( player in getplayers() )
    {
        if ( is_player_valid( player ) )
            return player;
    }

    return undefined;
}

// Region name ("bus", "diner", "farm", "cornfield", "power", "town") containing the player's zone
// (level.transit_region from _zm_ai_avogadro init_regions; get_current_zone _zm_utility.gsc:2979).
df_region_of_player( player, fallback )
{
    zone = player get_current_zone();

    if ( !isdefined( zone ) || !isdefined( level.transit_region ) )
        return fallback;

    foreach ( name in getarraykeys( level.transit_region ) )
    {
        foreach ( z in level.transit_region[name].zones )
        {
            if ( z == zone )
                return name;
        }
    }

    return fallback;
}

// Once he has landed, warp him next to the table the way vanilla phases him, so the fight starts at
// the tower. While the capture is open: keep his region on a living player (region_empty() would make
// him leave) and warp him back if he wanders more than 1500 units from the tower.
df_r1_keep_avogadro_at_tower( inserter )
{
    level endon( "end_game" );
    level endon( "df_r1_capture_over" );
    level endon( "df_skip_r1" );

    for ( t = 0; t < 1500; t++ )
    {
        wait 0.1;

        if ( !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) )
            return;

        if ( level.avogadro.state == "idle" || level.avogadro.state == "chasing" )
            break;

        // back in the cloud with a later return round: he was leaving when called, or he landed, found
        // nobody in his region within 30 s and left again (exit_idle). Call him back.
        if ( level.avogadro.state == "cloud" && isdefined( level.avogadro.return_round ) && level.avogadro.return_round > level.round_number )
            df_r1_call_down( df_r1_summon_target( inserter ) );
    }

    level notify( "df_r1_avogadro_landed" );
    wait 1;
    df_avogadro_warp_near_tower();

    while ( true )
    {
        wait 2;

        if ( !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) )
            return;

        if ( level.avogadro.state != "idle" && level.avogadro.state != "chasing" )
            continue;

        foreach ( player in getplayers() )
        {
            if ( is_player_valid( player ) )
            {
                level.avogadro.current_region = df_region_of_player( player, level.avogadro.current_region );
                break;
            }
        }

        if ( distancesquared( level.avogadro.origin, df_tower_center() ) > 1500 * 1500 )
            df_avogadro_warp_near_tower();
    }
}

df_avogadro_warp_near_tower()
{
    socket = df_coord( "DF_SOCKET" ).origin;
    dest = df_ground( socket + ( 0, 0, 60 ) + anglestoforward( ( 0, randomint( 360 ), 0 ) ) * 320 );
    level.avogadro thread df_avogadro_phase_to( dest );
    df_debug_print( "DF: avogadro warped to the tower" );
}

// self = avogadro. Mirrors _zm_ai_avogadro::do_phase around the vanilla teleport routine
// (avogadro_teleport( dest, angles, lerp_time )).
df_avogadro_phase_to( dest )
{
    self endon( "death" );

    if ( self.state != "idle" && self.state != "chasing" )
        return;

    self.state = "phasing";
    self notify( "stop_find_flesh" );
    self notify( "zombie_acquire_enemy" );
    self.ignoreall = 1;
    self maps\mp\zombies\_zm_ai_avogadro::avogadro_teleport( dest, ( 0, randomint( 360 ), 0 ), 0.8 );
    self.ignoreall = 0;
    self.state = "idle";
}

// Vanilla brings Avogadro back from his cloud every few rounds on his own. While R1 is open and the
// storm has not been called, his return round is pushed ahead so only the storm brings him down.
df_r1_hold_avogadro()
{
    level endon( "end_game" );
    level endon( "df_r1_done" );
    level endon( "df_skip_r1" );

    while ( true )
    {
        wait 0.5;

        if ( is_true( level.df_r1_summoned ) || !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) )
            continue;

        // cloud_update polls every 0.1 s and fires the moment round_number reaches return_round, so the
        // push must happen before the round changes: keep the return two rounds ahead at all times.
        if ( level.avogadro.state == "cloud" && isdefined( level.avogadro.return_round ) && level.avogadro.return_round <= level.round_number + 1 )
            level.avogadro.return_round = level.round_number + 2;
    }
}

// ---- capture -----------------------------------------------------------------------------

// Waits for the defeat (avogadro_pain notifies "avogadro_defeated", _zm_ai_avogadro.gsc:1288). Captured
// when it happens within 900 units of the tower (or forced by "!df fire r1_captured").
// Returns 1 = captured, 0 = defeated elsewhere or the clock ran out while he was away from the tower.
df_r1_wait_capture()
{
    level endon( "end_game" );
    level thread df_r1_capture_timeout();
    level waittill_either( "avogadro_defeated", "df_r1_capture_timeout" );
    level notify( "df_r1_capture_timeout_cancel" );

    captured = 0;

    if ( is_true( level.df_r1_force_captured ) )
        captured = 1;
    else if ( isdefined( level.avogadro ) && distancesquared( level.avogadro.origin, df_tower_center() ) < 900 * 900 && !is_true( level.df_r1_timed_out ) )
        captured = 1;

    level.df_r1_force_captured = 0;
    level.df_r1_timed_out = 0;
    level.df_r1_summoned = 0;
    level.df_r1_in_chamber = 0;

    if ( !captured )
    {
        df_debug_print( "DF: avogadro not captured" );
        // audit art R1.5: the fail was text only; the FAIL cue (EMP thump to all + side one-shot) at the table
        df_cue_fail( df_coord( "DF_SOCKET" ).origin + ( 0, 0, 30 ) );
        df_say( "R1_RICH_FAIL" );
        return 0;
    }

    df_debug_print( "DF: avogadro captured at the tower" );
    socket_pos = df_coord( "DF_SOCKET" ).origin;
    df_fx_once( "avogadro_ascend", socket_pos );
    phasing = df_fx_loop( "avogadro_phasing", socket_pos + ( 0, 0, 30 ) );
    level thread df_fx_stop_after( phasing, 10 );
    df_say( "R1_RICH_CAPTURED" );
    df_say( "R1_MAXIS_TAUNT" );
    // the canon Maxis taunt for a knifed Avogadro (zm_transit_sq.gsc:1238 maxissay), 3D at the table, once
    // per game (df_vox_once threads the serialised helper itself)
    df_vox_once( "vox_maxi_avogadro_stab_0", socket_pos + ( 0, 0, 40 ) );
    return 1;
}

// Capture clock (df_scaled "capture_time", 240/300/300/300): does not run while he is still in the
// power chamber, and never expires while he is within 900 of the tower (audit 5): only "defeated
// elsewhere" or leaving the tower after the time is up fails the capture.
df_r1_capture_timeout()
{
    level endon( "end_game" );
    level endon( "df_skip_r1" );
    level endon( "df_r1_capture_timeout_cancel" );

    while ( is_true( level.df_r1_in_chamber ) )
        wait 1;

    if ( level.df_r1_capture_time > 30 )
        wait( level.df_r1_capture_time - 30 );

    // audit art R1.3: the clock had no audible tempo; the last 30 s tick once per second to everyone
    // (zmb_tombstone_timer_count, the Tombstone countdown, Core/_zm_tombstone.gsc:380)
    for ( i = 0; i < 30; i++ )
    {
        foreach ( player in getplayers() )
            player playsoundtoplayer( "zmb_tombstone_timer_count", player );

        wait 1;
    }

    while ( df_r1_avogadro_near_tower() )
        wait 1;

    level.df_r1_timed_out = 1;
    level notify( "df_r1_capture_timeout" );
}

// Captured: his charge is drawn into the boxes one after the other - a soul trail from the table and a
// one-shot spark burst at each box, then the sparks go out. No sting here: df_complete plays the one
// STEP DONE sound right after (audit art R1.4).
df_r1_capture_burst()
{
    socket_pos = df_coord( "DF_SOCKET" ).origin + ( 0, 0, 40 );

    foreach ( fuse in level.df_fuses )
    {
        level thread df_soul_fly( socket_pos, fuse.led_origin );
        wait 0.2;
    }

    wait 1.5;

    foreach ( fuse in level.df_fuses )
    {
        df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", fuse.led_origin );
        df_rich_spark_set( fuse, fuse.led_origin, 0 );
        wait 0.25;
    }
}

// ---- refill lock: the battery (audit 9, ITEM_BATTERY_RICH; audit v2 #1: ONE battery) -----------
// Failure locks the Simon until ONE BATTERY (df_model "part_a") taken from the bus dashboard has charged
// every box: one press takes it from the bus, one press at each empty box charges that box, the battery
// stays in hand between boxes (the ember rule, M2) and is consumed at the fourth. It never respawns on
// the bus while it exists somewhere (in a hand, or on the ground where a carrier went down). No round
// wait, no kill quota. fuse.souls stays the counter (1 = charged, target 1) so `!df souls` (df_main sets
// fuse.souls = level.df_r1_refill_target) and `!df fire r1_soul` are still the debug shortcuts.

df_r1_lock_until_refilled()
{
    level endon( "end_game" );
    level.df_r1_locked = 1;
    level.df_r1_refill_target = 1;

    foreach ( fuse in level.df_fuses )
    {
        fuse.souls = 0;
        df_r1_fuse_charged_look( fuse, 0 ); // locked boxes go dark (audit art R1.5)
    }

    df_debug_print( "DF: r1 locked, one battery from the bus charges the four boxes" );
    df_r1_battery_spawn_on_bus();
    df_say( "ITEM_BATTERY_RICH" ); // audit dialogue 1.4 #4: the battery line had no caller
    level thread df_r1_battery_loop();

    while ( !df_r1_all_refilled() )
        level waittill_either( "df_r1_refill_check", "df_debug_souls_done" );

    level notify( "df_r1_refilled" );
    df_r1_battery_remove();

    foreach ( fuse in level.df_fuses )
        df_rich_spark_set( fuse, fuse.led_origin, 0 );

    level.df_r1_locked = 0;
    df_r1_arm( 1 );
    df_debug_print( "DF: r1 unlocked, simon available again" );
}

df_r1_all_refilled()
{
    foreach ( fuse in level.df_fuses )
    {
        if ( fuse.souls < level.df_r1_refill_target )
            return false;
    }

    return true;
}

// The battery on the bus dashboard (the spot df_act1 df_step1_dashboard_cue lights: 190 units forward,
// 64 up, riding the bus). Only at the start of a lock: never while one exists (lying, riding or held).
// Without a bus (should not happen) it lies between the boxes.
df_r1_battery_spawn_on_bus()
{
    b = level.df_r1_bat;

    if ( isdefined( b ) && ( isdefined( b.model ) || is_true( b.held ) ) )
        return;

    b = spawnstruct();
    link = level.the_bus;
    pos = df_r1_card_pos();

    if ( isdefined( link ) )
        pos = link.origin + anglestoforward( link.angles ) * 190 + ( 0, 0, 64 );

    b.pick = df_rich_pickup_place( "battery", pos, link ); // kind "battery" = the car battery (part_a is the radio now)
    b.model = b.pick.model;
    b.held = 0;
    level.df_r1_bat = b;
    df_debug_print( "DF: battery on the bus" );
}

// Battery lying somewhere (a dropped one): same struct, no link.
df_r1_battery_drop( pos, player )
{
    b = level.df_r1_bat;
    b.held = 0;

    if ( isdefined( player ) )
        df_r1_battery_release( player );

    b.carrier = undefined;
    b.pick = df_rich_pickup_place( "battery", df_ground( pos ) + ( 0, 0, 6 ), undefined );
    b.model = b.pick.model;
    df_debug_print( "DF: battery dropped" );
}

// Removes the world battery and any carrier state (lock over, skip).
df_r1_battery_remove()
{
    b = level.df_r1_bat;

    if ( !isdefined( b ) )
        return;

    df_rich_pickup_remove( b.pick );
    b.model = undefined;

    if ( isdefined( b.carrier ) && isplayer( b.carrier ) )
        df_r1_battery_release( b.carrier );

    b.held = 0;
    level.df_r1_bat = undefined;
}

// Presses and prompts while locked (0.05 s: df_press_use is edge-triggered). Ends with the lock.
df_r1_battery_loop()
{
    level endon( "end_game" );
    level endon( "df_r1_refilled" );
    level endon( "df_skip_r1" );

    while ( true )
    {
        wait 0.05;
        df_r1_battery_carrier_check();

        foreach ( player in getplayers() )
            df_r1_battery_player_tick( player );
    }
}

// Carrier down or gone: the battery drops at the carrier's last position.
df_r1_battery_carrier_check()
{
    b = level.df_r1_bat;

    if ( !isdefined( b ) || !is_true( b.held ) )
        return;

    if ( !isdefined( b.carrier ) || !isplayer( b.carrier ) )
    {
        df_r1_battery_drop( b.carrier_pos, undefined );
        return;
    }

    b.carrier_pos = b.carrier.origin;

    if ( b.carrier maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
        df_r1_battery_drop( b.carrier.origin, b.carrier );
}

// One player's battery prompts / presses this frame: the carrier keeps the prompt at EVERY empty box
// (within 70) and charges it with one press; anyone else takes the free battery (within 100 of it, on
// the bus or on the ground).
df_r1_battery_player_tick( player )
{
    b = level.df_r1_bat;

    if ( !isdefined( b ) || !is_player_valid( player ) )
    {
        player df_prompt( 0, undefined );
        return;
    }

    if ( is_true( b.held ) && isdefined( b.carrier ) && player == b.carrier )
    {
        fuse = df_r1_empty_fuse_near( player.origin, 70 );
        player df_prompt( isdefined( fuse ), "Press [{+activate}] to charge the box" );

        if ( isdefined( fuse ) && player df_press_use() )
            df_r1_battery_slot( fuse, player );

        return;
    }

    if ( isdefined( b.model ) && !is_true( b.held ) )
    {
        near = distancesquared( player.origin, b.model.origin ) < 100 * 100;
        player df_prompt( near, "Press [{+activate}] to take the battery" );

        if ( near && player df_press_use() )
            df_r1_battery_take( player );

        return;
    }

    player df_prompt( 0, undefined );
}

// Nearest box within `radius` that still needs its battery, or undefined.
df_r1_empty_fuse_near( pos, radius )
{
    best = undefined;
    best_d2 = radius * radius;

    foreach ( fuse in level.df_fuses )
    {
        if ( fuse.souls >= level.df_r1_refill_target )
            continue;

        d2 = distancesquared( pos, fuse.origin );

        if ( d2 < best_d2 )
        {
            best = fuse;
            best_d2 = d2;
        }
    }

    return best;
}

// Carry notice via df_scav (kind "battery", battery icon of part_a), pickup sound zm_transit_buildables.gsc:249.
df_r1_battery_take( player )
{
    b = level.df_r1_bat;
    df_rich_pickup_remove( b.pick );
    b.model = undefined;
    b.carrier = player;
    b.carrier_pos = player.origin;
    b.held = 1;
    player.df_carrying_bat = 1;
    df_scav_carry_set( "battery", df_r1_charged_count(), 4, player, "battery" );
    player playsound( "zmb_buildable_pickup" );
    player df_prompt( 0, undefined );
    df_debug_print( "DF: battery taken" );
}

df_r1_battery_release( player )
{
    player.df_carrying_bat = 0;
    df_scav_carry_clear( "battery" );
    player df_prompt( 0, undefined );
}

df_r1_charged_count()
{
    n = 0;

    foreach ( fuse in level.df_fuses )
    {
        if ( fuse.souls >= level.df_r1_refill_target )
            n++;
    }

    return n;
}

// The battery charges `fuse` (player = carrier, undefined for the debug hook): the box lights up (full
// glow + steady sparks) with a PROGRESS TICK (df_cue_tick). The battery stays in the carrier's hands for
// the next empty box (audit v2 #1); at the fourth it is consumed and the SUB-GOAL cue plays at the barn
// centre (all four charged). The debug hook leaves the world battery where it is.
df_r1_battery_slot( fuse, player )
{
    fuse.souls = level.df_r1_refill_target;
    df_r1_fuse_charged_look( fuse, 1 );
    df_cue_tick( fuse.led_origin, 1 ); // clink + the side's 0.6 s spark burst at the box
    df_debug_print( "DF: box " + ( fuse.idx + 1 ) + " charged " + df_r1_charged_count() + "/4" );

    if ( df_r1_all_refilled() )
    {
        df_r1_battery_remove(); // consumed: releases the carrier, deletes a lying one
        df_cue_subgoal( df_r1_boxes_center() + ( 0, 0, 40 ) );
        df_debug_print( "DF: battery consumed, all four boxes charged" );
    }
    else
        df_r1_battery_notice();

    level notify( "df_r1_refill_check" );
}

// The carrier's TAB notice shows charged boxes / 4 (df_scav kind "battery", battery icon of part_a).
df_r1_battery_notice()
{
    b = level.df_r1_bat;

    if ( !isdefined( b ) || !is_true( b.held ) || !isdefined( b.carrier ) || !isplayer( b.carrier ) )
        return;

    df_scav_carry_set( "battery", df_r1_charged_count(), 4, b.carrier, "battery" );
}

// Box look during the lock: charged = full glow + steady sparks; uncharged (locked) = dark and silent
// (audit art R1.5: the boxes' glow goes off while they are locked). df_r1_arm( 1 ) relights them.
df_r1_fuse_charged_look( fuse, on )
{
    if ( on )
    {
        df_rich_glow_set( fuse, fuse.led_origin, "fx_zmb_tranzit_light_glow" );
        df_rich_spark_set( fuse, fuse.led_origin, 1 );
        return;
    }

    df_rich_glow_set( fuse, fuse.led_origin, undefined );
    df_rich_spark_set( fuse, fuse.led_origin, 0 );
}

// ---- Richtofen side rules (audit 2.4: "the noise") ---------------------------------------
// From R1 on: Avogadro returns EVERY round until the finale; the Jet Gun bleeds heat above 50 for every
// holder (E removes the Step 6 copy); at end of round with the power OFF one filled lamp / charged box
// loses 5 souls (console only). Turrets need no turbine from R2 on (df_r2_run).
df_r1_side_rules_start()
{
    if ( is_true( level.df_r1_rules ) )
        return;

    level.df_r1_rules = 1;
    level thread df_r1_avogadro_keeper();
    level thread df_r1_jetgun_relief();
    level thread df_r1_power_penalty();
}

// Every round: whenever his cloud return is more than one round away, pull it to the next round
// (_zm_ai_avogadro.gsc:693-698 sets it 2-5 rounds ahead, cloud_update:781 fires when round_number reaches
// it). Stops once the finale is done (level.df_completed; df_finale banishes him itself).
df_r1_avogadro_keeper()
{
    level endon( "end_game" );

    while ( !is_true( level.df_completed ) )
    {
        wait 1;

        if ( !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) || level.avogadro.state != "cloud" )
            continue;

        if ( isdefined( level.avogadro.return_round ) && level.avogadro.return_round > level.round_number + 1 )
        {
            level.avogadro.return_round = level.round_number + 1;
            df_debug_print( "DF: avogadro returns next round" );
        }
    }
}

// isweaponoverheating( 1 ) = heat value, ( 0 ) = locked; the builtins vanilla's watch_overheat uses
// (_zm_weap_jetgun.gsc:160-175, weapon name "jetgun_zm" :165). One heat point per 0.1 s above 50.
df_r1_jetgun_relief()
{
    level endon( "end_game" );

    while ( true )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) || player getcurrentweapon() != "jetgun_zm" )
                continue;

            if ( player isweaponoverheating( 0 ) )
                continue;

            heat = player isweaponoverheating( 1 );

            if ( heat > 50 )
                player setweaponoverheating( 0, heat - 1 );
        }
    }
}

// End of round with the power off (flag "power_on", zm_transit_power.gsc): one lamp with souls loses 5
// (a filled lamp reopens: "souls" look, beam back); failing that, during the refill lock one charged box
// loses its battery. Silent in game, one console line.
df_r1_power_penalty()
{
    level endon( "end_game" );

    while ( !is_true( level.df_completed ) )
    {
        level waittill( "end_of_round" );

        if ( flag( "power_on" ) || is_true( level.df_completed ) )
            continue;

        lamp = df_r1_penalty_lamp();

        if ( isdefined( lamp ) )
        {
            lamp.souls = lamp.souls - 5;

            if ( lamp.souls < 0 )
                lamp.souls = 0;

            if ( lamp.filled && lamp.souls < level.df_r2_target )
            {
                lamp.filled = 0;
                df_lamp_state_set( lamp, "souls" );
                df_r2_beam_set( lamp, 1 );
            }

            df_debug_print( "DF: power off: lamp " + lamp.name + " -5, " + lamp.souls );
            continue;
        }

        if ( !is_true( level.df_r1_locked ) )
            continue;

        foreach ( fuse in level.df_fuses )
        {
            if ( fuse.souls >= level.df_r1_refill_target )
            {
                fuse.souls = 0;
                df_r1_fuse_charged_look( fuse, 0 );
                df_r1_battery_notice(); // the one battery is still out there: the carrier's count drops
                df_debug_print( "DF: power off: box " + ( fuse.idx + 1 ) + " emptied" );
                break;
            }
        }
    }
}

// The R2 lamp that pays the penalty: while R2 is open, the fullest lamp with souls; none otherwise.
df_r1_penalty_lamp()
{
    if ( !isdefined( level.df_r2_lamps ) || df_is_done( "r2" ) || !isdefined( level.df_r2_target ) )
        return undefined;

    best = undefined;

    foreach ( lamp in level.df_r2_lamps )
    {
        if ( lamp.souls <= 0 )
            continue;

        if ( !isdefined( best ) || lamp.souls > best.souls )
            best = lamp;
    }

    return best;
}

// ---- debug hooks (!df fire <name>) ---------------------------------------------------------
//   r1_captured : the open capture counts as a capture at the tower (no fight needed)
//   r1_sounds   : plays click, buzzer and the success arpeggio at box 1 so the aliases can be judged
//   r1_soul     : during the refill lock, one box gets charged without the trip (the battery stays put)
//   r1_card     : replays the key card arrival FX between the boxes (no card spawned)
df_r1_debug_hooks()
{
    level endon( "end_game" );
    level endon( "df_r1_done" );
    level endon( "df_skip_r1" );

    while ( true )
    {
        msg = level waittill_any_return( "df_debug_r1_captured", "df_debug_r1_sounds", "df_debug_r1_soul", "df_debug_r1_card" );

        if ( msg == "df_debug_r1_captured" )
        {
            level.df_r1_force_captured = 1;
            level notify( "df_r1_capture_timeout" );
            df_debug_print( "DF: capture forced" );
        }
        else if ( msg == "df_debug_r1_sounds" )
            level thread df_r1_debug_sounds();
        else if ( msg == "df_debug_r1_soul" )
            df_r1_debug_soul();
        else if ( msg == "df_debug_r1_card" )
            level thread df_r1_card_spawn_fx( df_r1_card_pos() );
    }
}

df_r1_debug_sounds()
{
    level endon( "end_game" );
    fuse = level.df_fuses[0];
    df_debug_print( "DF: click" );
    df_simon_click( fuse );
    wait 1.5;
    df_debug_print( "DF: buzzer" );
    df_simon_buzzer( fuse );
    wait 2;
    df_debug_print( "DF: arpeggio" );
    df_simon_success_arpeggio();
}

// One box charged without the trip; the world battery (bus, ground or carried) is left as it is.
df_r1_debug_soul()
{
    if ( !is_true( level.df_r1_locked ) )
    {
        df_debug_print( "DF: r1 is not locked" );
        return;
    }

    fuse = df_r1_empty_fuse_near( level.df_fuses[0].origin, 100000 );

    if ( isdefined( fuse ) )
        df_r1_battery_slot( fuse, undefined );
}

// =========================================================================================
// R2 - Souls on the Line
// =========================================================================================

// The lamps are the game's one lamp set (df_lamps.gsc): picked here on the Richtofen side, reused by
// Step 5 (tuning, penalty). level.df_r2_lamps is the same array (df_main "!df souls" reads it). Every
// unfilled lamp carries a tower beam (audit: R2 was "run around the fog looking for blue"). A filled lamp
// drops a wire spool at its base; the step completes when every spool is placed on the table (the
// antenna array), which is the Step 5 prerequisite. Turrets need no turbine from here on (audit 2.4).
df_r2_run()
{
    level endon( "end_game" );

    df_r2_pick_lamps();
    level.df_r2_target = df_scaled( "lamp_souls" );
    level.df_r2_spools = 0;
    level.df_r2_spools_need = level.df_r2_lamps.size;
    level.df_r2_spool_ents = [];

    foreach ( lamp in level.df_r2_lamps )
    {
        lamp.souls = 0;
        lamp.filled = 0;
        lamp.spool_dropped = 0;
        df_lamp_state_set( lamp, "souls" );
        df_r2_beam_set( lamp, 1 );
    }

    df_death_listen_add( "r2", ::df_r2_on_zombie_death );
    level thread df_r2_skip_cleanup();
    level thread df_r2_debug_hooks();
    level thread df_r2_spool_loop();
    level thread df_r2_lamp_spawner(); // owner 2026-09-11: the dead come to a player under a hungry lamp
    level thread df_r2_punch_loop();   // owner 2026-09-11 (fists 4): the knuckles free the spool of a full lamp
    df_debug_print( "DF: r2 " + level.df_r2_lamps.size + " lamps, " + level.df_r2_target + " souls each" );

    while ( level.df_r2_spools < level.df_r2_spools_need )
    {
        msg = level waittill_any_return( "df_r2_check", "df_debug_souls_done" );

        if ( msg == "df_debug_souls_done" )
            df_r2_spools_deliver_all();
    }

    df_death_listen_remove( "r2" );
    level.equipment_turret_needs_power = 0; // _zm_equip_turret.gsc:224-238 startturretdeploy: no turbine needed
    df_say( "R2_DONE" );

    if ( !df_s6_any_jetgun() )
        df_say( "S6_NOJETGUN_RICH" ); // audit v3 #6: the Jet Gun is a prerequisite of Step 6, said here and not at the pickup
    // canon "the device is complete" in Richtofen's mouth (zm_transit_sq.gsc:1120 richtofensay), 2D to
    // Stuhlinger, once per game (df_vox_once threads the helper itself)
    df_vox_once( "vox_zmba_sidequest_jet_complete_0" );
    df_complete( "r2" );
}

// "!df goto" past r2: the set (same one for the whole game) counts as filled and the array as built.
// No node export here: Step 6 on Richtofen draws from the fuse boxes (df_r1_export_nodes).
df_r2_setup()
{
    df_r2_pick_lamps();

    if ( !isdefined( level.df_r2_target ) )
        level.df_r2_target = df_scaled( "lamp_souls" );

    foreach ( lamp in level.df_r2_lamps )
    {
        lamp.filled = 1;
        lamp.souls = level.df_r2_target;
        lamp.spool_dropped = 1;
        df_lamp_state_set( lamp, "filled" );
    }

    level.df_r2_spools_need = level.df_r2_lamps.size;
    level.df_r2_spools = 0;
    level.df_r2_spool_ents = [];
    df_r2_spools_deliver_all();
    level.equipment_turret_needs_power = 0;
}

// level.df_r2_lamps = the shared set (N = df_scaled "nodes", one lamp per fog area, df_lamp_pick_set).
df_r2_pick_lamps()
{
    level.df_r2_lamps = df_lamp_set_get();
}

// Tower beam (df_beam_start, df_coords) at the bulb of an unfilled set lamp; own field so the lamp's
// state changes (df_lamp_clear touches lamp.beam only) leave it alone.
df_r2_beam_set( lamp, on )
{
    if ( on )
    {
        if ( !isdefined( lamp.r2_beam ) )
            lamp.r2_beam = df_beam_start( df_lamp_bulb_pos( lamp ) );

        return;
    }

    df_beam_stop( lamp.r2_beam );
    lamp.r2_beam = undefined;
}

// Owner 2026-09-08: the absorb radius is a plain sphere of 450 units around the lamp BASE (3D distance,
// so a kill on a slope or a roof counts the same as on the road); no zone or other filter. The nearest
// set lamp that still needs souls takes the soul (trail to its bulb) and EVERY soul clinks at the bulb
// (df_cue_tick; audit art R2.3: Origins / DE soul boxes let each soul be heard). The first counted kill
// touches the step (audit dialogue 1.4 #3: the stall ladder stops). Console line every 5 souls.
df_r2_on_zombie_death( zombie )
{
    best = df_lamp_nearest( zombie.origin, 450, 1 );

    if ( !isdefined( best ) )
    {
        df_r2_miss_debug( zombie.origin );
        return;
    }

    df_touch( "r2" );
    best.souls++;
    level thread df_soul_fly( zombie.origin, df_lamp_bulb_pos( best ) );

    if ( best.souls >= level.df_r2_target )
        df_r2_fill( best );
    else
    {
        df_cue_tick( df_lamp_bulb_pos( best ) );

        if ( best.souls % 5 == 0 )
            df_debug_print( "DF: lamp " + best.name + " souls " + best.souls + "/" + level.df_r2_target );
    }

    level notify( "df_r2_check" );
}

// A kill that reached no set lamp: once per 2 s, how far the nearest UNFILLED set lamp was (so a "sometimes
// it counts, sometimes not" report can be read off the console).
df_r2_miss_debug( pos )
{
    if ( isdefined( level.df_r2_miss_ms ) && gettime() - level.df_r2_miss_ms < 2000 )
        return;

    best = df_lamp_nearest( pos, 2000, 1 );

    if ( !isdefined( best ) )
        return;

    level.df_r2_miss_ms = gettime();
    df_debug_print( "DF: kill not absorbed: " + int( distance2d( pos, best.origin ) ) + " from lamp " + best.name + " (need 450, height diff " + int( abs( pos[2] - best.origin[2] ) ) + ")" );
}

// Filled: the shared "filled" look (steady side light + slow sparks + meteor hum, df_lamps.gsc), the
// SUB-GOAL cue at the bulb (df_cue_subgoal, df_systems: NavCard chime + side flash + the canon node ->
// tower trail of zm_transit_classic.csc; audit art #4), the beam goes out and the lamp drops its wire
// spool (once per lamp, even if a power penalty reopens it).
df_r2_fill( lamp )
{
    if ( lamp.filled )
        return;

    lamp.filled = 1;
    lamp.souls = level.df_r2_target;
    df_lamp_state_set( lamp, "filled" );
    df_r2_beam_set( lamp, 0 );
    df_cue_subgoal( df_lamp_bulb_pos( lamp ) );
    df_debug_print( "DF: lamp " + lamp.name + " filled" );

    // owner 2026-09-11 (fists 4): the spool stays in the post until somebody punches it with the Galvaknuckles
    if ( !is_true( lamp.spool_dropped ) )
    {
        lamp.spool_ready = 1;

        if ( !is_true( level.df_r2_full_said ) )
        {
            level.df_r2_full_said = 1;
            df_say( "R2_RICH_FULL" );
        }

        df_debug_print( "DF: lamp " + lamp.name + " full: punch the post with the knuckles to get the spool (!df fire r2_punch drops every ready spool)" );
    }
}

// ---- wire spools (audit 9, ITEM_SPOOL_RICH) --------------------------------------------------
// Model kind "spool" once df_coords has it (requested), else the electric box part (part_c).

df_r2_spool_kind()
{
    if ( isdefined( level.df_models ) && isdefined( level.df_models["spool"] ) )
        return "spool";

    return "part_c";
}

// The spool lands on the ground 40 units from the pole towards the tower (out of the post itself) under
// the vanilla "take me" glint (df_rich_pickup_place adds fx_zmb_tranzit_key_glint +14; audit art R2.1).
// No sound of its own: the lamp's sub-goal cue just played at the bulb. The first spool of the game is
// announced (ITEM_SPOOL_RICH, audit dialogue 1.4 #2: the line had no caller).
df_r2_spool_drop( lamp )
{
    dir = df_coord( "DF_SOCKET" ).origin - lamp.origin;
    dir = vectornormalize( ( dir[0], dir[1], 0 ) );
    pos = df_ground( lamp.origin + dir * 40 + ( 0, 0, 30 ) ) + ( 0, 0, 6 );
    s = spawnstruct();
    s.lamp = lamp;
    s.held = 0;
    df_item_arrival( pos ); // the spool appears by the same strike as every quest item (owner 2026-09-11)
    s.pick = df_rich_pickup_place( df_r2_spool_kind(), pos, undefined );
    s.model = s.pick.model;
    level.df_r2_spool_ents[level.df_r2_spool_ents.size] = s;

    if ( !is_true( level.df_r2_spool_said ) )
    {
        level.df_r2_spool_said = 1;
        df_say( "ITEM_SPOOL_RICH" );
    }

    df_debug_print( "DF: spool at lamp " + lamp.name );
}

// Presses and prompts for the spools (0.05 s: df_press_use is edge-triggered) until the step ends.
df_r2_spool_loop()
{
    level endon( "end_game" );
    level endon( "df_r2_done" );
    level endon( "df_skip_r2" );

    table = df_coord( "DF_SOCKET" ).origin;

    while ( true )
    {
        wait 0.05;

        foreach ( s in level.df_r2_spool_ents )
            df_r2_spool_carrier_check( s );

        foreach ( player in getplayers() )
            df_r2_spool_player_tick( player, table );
    }
}

// Carrier down or gone: the spool drops at the carrier's last position.
df_r2_spool_carrier_check( s )
{
    if ( !is_true( s.held ) )
        return;

    if ( !isdefined( s.carrier ) || !isplayer( s.carrier ) )
    {
        df_r2_spool_drop_at( s, s.carrier_pos, undefined );
        return;
    }

    s.carrier_pos = s.carrier.origin;

    if ( s.carrier maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
        df_r2_spool_drop_at( s, s.carrier.origin, s.carrier );
}

df_r2_spool_drop_at( s, pos, player )
{
    s.held = 0;
    s.carrier = undefined;
    s.pick = df_rich_pickup_place( df_r2_spool_kind(), df_ground( pos ) + ( 0, 0, 6 ), undefined );
    s.model = s.pick.model;

    if ( isdefined( player ) )
        df_r2_spool_notice( player );

    df_debug_print( "DF: spool dropped" );
}

// Spools carried by `player` (owner 2026-09-09: they stack, like Scavenger's parts).
df_r2_spools_carried( player )
{
    n = 0;

    foreach ( s in level.df_r2_spool_ents )
    {
        if ( is_true( s.held ) && isdefined( s.carrier ) && s.carrier == player )
            n++;
    }

    return n;
}

// One player's spool prompts / presses this frame: a free spool within 100 is taken (any number can be
// carried); with spools in hand, one press within 150 of the table places them ALL.
df_r2_spool_player_tick( player, table )
{
    if ( !is_player_valid( player ) )
    {
        player df_prompt( 0, undefined );
        return;
    }

    s = df_r2_spool_near( player.origin, 100 );

    if ( isdefined( s ) )
    {
        player df_prompt( 1, "Press [{+activate}] to take the spool" );

        if ( player df_press_use() )
            df_r2_spool_take( s, player );

        return;
    }

    if ( df_r2_spools_carried( player ) > 0 )
    {
        near = distancesquared( player.origin, table ) < 150 * 150;
        player df_prompt( near, "Press [{+activate}] to place the spools" );

        if ( near && player df_press_use() )
            df_r2_spool_deliver( player );

        return;
    }

    player df_prompt( 0, undefined );
}

// A free spool (lying, not carried) within `radius` of pos, or undefined.
df_r2_spool_near( pos, radius )
{
    foreach ( s in level.df_r2_spool_ents )
    {
        if ( isdefined( s.model ) && !is_true( s.held ) && distancesquared( pos, s.model.origin ) < radius * radius )
            return s;
    }

    return undefined;
}

// Pickup: the spool leaves the world and rides with the player; notice = placed + carried of the total.
// Touches the step (a take proves the player found the mechanic; the ladder stops).
df_r2_spool_take( s, player )
{
    df_touch( "r2" );
    df_rich_pickup_remove( s.pick );
    s.model = undefined;
    s.held = 1;
    s.carrier = player;
    s.carrier_pos = player.origin;
    df_r2_spool_notice( player );
    player playsound( "zmb_buildable_pickup" );
    player df_prompt( 0, undefined );
    df_debug_print( "DF: spool taken (" + df_r2_spools_carried( player ) + " in hand, " + level.df_r2_spools + " placed)" );
}

// The carry notice / TAB square for this player: placed so far + what they hold, out of the total.
df_r2_spool_notice( player )
{
    n = level.df_r2_spools + df_r2_spools_carried( player );

    if ( n <= 0 )
    {
        df_scav_carry_clear( "spool" );
        return;
    }

    df_scav_carry_set( "spool", n, level.df_r2_spools_need, player, "spool" );
}

// Kept for the debug / goto path (df_r2_spools_deliver_all): clears the notice of a carrier.
df_r2_spool_release( player )
{
    df_scav_carry_clear( "spool" );
    player df_prompt( 0, undefined );
}

// The spool goes into the array on the table: the PROGRESS TICK cue at the relay slot (df_cue_tick =
// piece-add clink + side burst) and one more glow up the mast (df_r2_array_set). The struct leaves the
// world list. The step's own sting comes from df_complete when the last one lands.
df_r2_spool_deliver( player )
{
    placed = 0;

    foreach ( s in level.df_r2_spool_ents )
    {
        if ( !is_true( s.held ) || !isdefined( s.carrier ) || s.carrier != player )
            continue;

        s.held = 0;
        s.carrier = undefined;
        s.done = 1;
        level.df_r2_spools++;
        placed++;
    }

    if ( placed == 0 )
        return;

    df_r2_spool_notice( player );
    player df_prompt( 0, undefined );
    df_cue_tick( df_table_slot( 0 ) + ( 0, 0, 30 ), 1 ); // clink + spark burst at the relay slot
    df_r2_array_set( level.df_r2_spools );
    df_debug_print( "DF: " + placed + " spool(s) placed, " + level.df_r2_spools + "/" + level.df_r2_spools_need );
    level notify( "df_r2_check" );
}

// Debug / goto: every spool counts as placed; the ones in the world (or carried) go away.
df_r2_spools_deliver_all()
{
    foreach ( s in level.df_r2_spool_ents )
    {
        df_rich_pickup_remove( s.pick );
        s.model = undefined;

        if ( is_true( s.held ) && isdefined( s.carrier ) && isplayer( s.carrier ) )
            df_r2_spool_release( s.carrier );

        s.held = 0;
    }

    level.df_r2_spools = level.df_r2_spools_need;
    df_r2_array_set( level.df_r2_spools );
    level notify( "df_r2_check" );
}

// The antenna array on the plugged relay (table slot 0): the act1 owner's stacking hook when present
// (level.df_relay_array_func( n, total ), requested) and nothing else; otherwise n small glows ON the
// table mast (fx_zmb_tranzit_light_glow_xsm, zm_transit_fx.gsc:55) at slot 0 + 40 / 56 / 72: the mast
// is the 117-tall p6_zm_chain_fence_piece_end post (world agent, audit art #7), so the glows sit on its
// lower half instead of floating over a 7-tall radio (audit art R2.4).
df_r2_array_set( n )
{
    if ( isdefined( level.df_relay_array_func ) )
    {
        level [[ level.df_relay_array_func ]]( n, level.df_r2_spools_need );
        return;
    }

    if ( !isdefined( level.df_r2_array_fx ) )
        level.df_r2_array_fx = [];

    for ( i = level.df_r2_array_fx.size; i < n; i++ )
        level.df_r2_array_fx[i] = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", df_table_slot( 0 ) + ( 0, 0, 40 + 16 * i ) );
}

// "!df goto" past r2: the listener, beams, spools and carrier state go; the set stays (one set per game)
// and df_r2_setup, run right after this notify, marks it filled and the array built.
df_r2_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_r2_done" );
    level waittill( "df_skip_r2" );
    df_death_listen_remove( "r2" );

    foreach ( lamp in level.df_r2_lamps )
        df_r2_beam_set( lamp, 0 );

    if ( isdefined( level.df_r2_spool_ents ) )
    {
        foreach ( s in level.df_r2_spool_ents )
        {
            df_rich_pickup_remove( s.pick );

            if ( is_true( s.held ) && isdefined( s.carrier ) && isplayer( s.carrier ) )
                df_r2_spool_release( s.carrier );
        }
    }

    level.df_r2_spool_ents = [];

    foreach ( player in getplayers() )
        player df_prompt( 0, undefined );
}

// Debug hooks (!df fire <name>):
//   r2_soul  : one soul into the first unfilled lamp (counter feedback, fill cue, spool drop)
//   r2_spool : one spool counts as placed on the table without the carry (removes one lying spool)
df_r2_debug_hooks()
{
    level endon( "end_game" );
    level endon( "df_r2_done" );
    level endon( "df_skip_r2" );

    while ( true )
    {
        msg = level waittill_any_return( "df_debug_r2_soul", "df_debug_r2_spool" );

        if ( msg == "df_debug_r2_spool" )
        {
            df_r2_debug_spool();
            continue;
        }

        fake = spawnstruct();

        foreach ( lamp in level.df_r2_lamps )
        {
            if ( !lamp.filled )
            {
                fake.origin = lamp.origin;
                df_r2_on_zombie_death( fake );
                break;
            }
        }
    }
}

df_r2_debug_spool()
{
    if ( level.df_r2_spools >= level.df_r2_spools_need )
        return;

    foreach ( s in level.df_r2_spool_ents )
    {
        if ( isdefined( s.model ) && !is_true( s.held ) )
        {
            df_rich_pickup_remove( s.pick );
            s.model = undefined;
            s.done = 1;
            break;
        }
    }

    level.df_r2_spools++;
    df_r2_array_set( level.df_r2_spools );
    df_debug_print( "DF: spool placed " + level.df_r2_spools + "/" + level.df_r2_spools_need );
    level notify( "df_r2_check" );
}

// ---- fists (owner 2026-09-11, idea 4) ---------------------------------------------------------
// A full lamp (lamp.spool_ready) gives its spool when a player within 90 of its post melees with the Galvaknuckles:
// punch fx on the post, the spool drops (df_r2_spool_drop, with the item arrival). Any other melee there: the
// deny buzz and Richtofen naming the fists, once per 20 s. "!df fire r2_punch" drops every ready spool.
df_r2_punch_loop()
{
    level endon( "end_game" );
    level endon( "df_r2_done" );
    level endon( "df_skip_r2" );

    level thread df_r2_punch_debug();

    while ( true )
    {
        wait 0.05;

        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) || !df_melee_edge( player ) )
                continue;

            lamp = df_r2_punch_target( player.origin );

            if ( !isdefined( lamp ) )
                continue;

            if ( !df_has_knuckles( player ) )
            {
                df_cue_deny( player );

                if ( !isdefined( level.df_r2_nofists_time ) || gettime() - level.df_r2_nofists_time > 20000 )
                {
                    level.df_r2_nofists_time = gettime();
                    df_say( "R2_RICH_NOFISTS" );
                }

                df_debug_print( "DF: r2 " + player.name + " hit lamp " + lamp.name + " without the knuckles (" + player getcurrentweapon() + ")" );
                continue;
            }

            df_r2_punch_release( lamp, player.name );
        }
    }
}

// The full lamp whose post is within 90 of pos, spool not yet out.
df_r2_punch_target( pos )
{
    foreach ( lamp in level.df_r2_lamps )
    {
        if ( is_true( lamp.spool_ready ) && !is_true( lamp.spool_dropped ) && distancesquared( pos, lamp.origin ) <= 90 * 90 )
            return lamp;
    }

    return undefined;
}

df_r2_punch_release( lamp, who )
{
    lamp.spool_ready = 0;
    lamp.spool_dropped = 1;
    df_punch_fx( lamp.origin, df_lamp_bulb_pos( lamp ) );
    df_r2_spool_drop( lamp );
    df_debug_print( "DF: r2 lamp " + lamp.name + " punched by " + who + ", the spool is out" );
}

df_r2_punch_debug()
{
    level endon( "end_game" );
    level endon( "df_r2_done" );
    level endon( "df_skip_r2" );

    while ( true )
    {
        level waittill( "df_debug_r2_punch" );

        foreach ( lamp in level.df_r2_lamps )
        {
            if ( is_true( lamp.spool_ready ) && !is_true( lamp.spool_dropped ) )
                df_r2_punch_release( lamp, "debug" );
        }
    }
}

// After the battery has charged the four boxes the run loop waits for a box press; with the Simon kept solved
// (audit v3 #5) the card comes back by itself.
df_r1_refilled_kick()
{
    level endon( "end_game" );
    wait 0.2;
    level notify( "df_fuse_pressed" );
}
