// Dead Frequency - Act 3, Step 7 "The Line Holds" (spec 5, Step 7; owner redesign v3, polish pass 2026-09-08).
//   A player powers the relay at the table under the tower (hold 3 s, a channelling action the owner
//   validated; the radius is keyed on df_coord( "DF_SOCKET" ).origin, which IS the table since 2026-09-08).
//   The charge orb (df_model( "orb" ): the turbine rotor disc p6_zm_buildable_turbine_fan since 2026-09-09,
//   the same disc Step 6 left on the table, spun by rotateyaw) lifts off its slot and wanders under the tower
//   for the wave's seconds; it has orb hp per player count. Our own spawner raises sprinting zombies at the
//   tower's spawn structs, close and fast (alive cap per side and player count, snapshotted at wave start),
//   and every zombie near the tower hunts the orb instead of the players (vanilla enemyoverride pattern:
//   ignoreall + setgoalpos); next to it they swing like at equipment. A living player must stay within 700
//   of the tower centre (10 s cumulative absence fails; 5 s back inside resets the count).
//   NUMBERS (steps audit v2 #4, section 6; the df_steps rows win when they exist, else the local tables in
//   df_act3_hold_init): spawn period "s7_period" 1.3/1.0/0.8/0.7 s, alive cap "s7_cap_rich" 10/14/18/22 /
//   "s7_cap_maxis" 14/18/22/26, "orb_hp" 3000/3600/4200/4800, "hold_time" 75/90/105/120 s, swing 30,
//   strikes every 10-20 s heal 10 %. Solo is no longer the hardest lobby.
//   GUARD BONUS (steps audit v2 #5, the step's name made literal): while a living player stands within 200
//   of the orb (df_s7_guarded) a swing does 15 instead of 30 and a strike heals 15 % instead of 10 %. The
//   player who holds the line with the stone wins; the one who trains at 600 loses it.
//   Side pressure from the START of the wave (audit 2.3): Richtofen recalls Avogadro, a boss in the wave
//   (camping the orb damages it; three knife hits banish him and drop a Max Ammo at the table, audit 8b(3))
//   with fewer sprinters; Maxis lets the denizens loose on the tower (safety volume off) with the full
//   sprinter cap and an ash / smoke column at the tower top for the whole wave (the fire side's far cue,
//   art audit S7.6). The Easter Egg song plays during the wave (one start per 330 s: stopsounds does not
//   end the stream).
//   Success = the countdown runs out with the orb alive: it glides back onto the table (slot 2, rising sound,
//   tower fx), Step 6's resting disc takes the slot over again for the finale, D7_DONE and the ONE uniform
//   STEP DONE sting from df_complete (art audit #1: the navcard chime here is gone). Failure: the orb bursts
//   in the side family (df_s7_orb_burst; emp sound) and our disc vanishes, D7_FAIL, then the Step 6 contract
//   (agreed with the Step 6 owner, 2026-09-08): level notify( "df_s6_restart" ) makes Step 6 put the charged
//   orb back IN FRONT OF THE TABLE, pickable (its own model, not ours); a player picks it up and places it
//   again, Step 6 fires "df_s6_redelivered" and the table is armed again. The charges are not lost.
// Feedback is the orb itself: the side-coloured aura shared with Step 6 (level.df_orb_aura, cycled with
// "!df fire orb_aura"), elec_md / lava_burning bursts, a hum, sparks on hits, a "damaged" state below 30 %
// hp (faster bursts, a warning beep every 2 s), the countdown, and every 10-20 s a "charge strike"
// (df_s7_charge_strikes: 2 s of denser static + rising sound, then the strike from above with thunder:
// Richtofen = Avogadro's descend bolt + lightning orb + blue flash; Maxis = a fire burst + ash on the
// ground + ignite, NEVER the blue bolt, art audit #9) so players read "it is charging, protect it"; no
// health bar (spec 7). Voice: vox_zmba_sidequest_zom_lure_0 once per game to Stuhlinger at the first wave
// start on Richtofen (zm_transit_sq.gsc:728), vox_maxi_turbines_out_0 at a Maxis fail (:331), via df_vox_once.
//
// Shared helpers this file relies on (df_systems / df_steps / df_coords): df_prompt, df_hold_use, df_fx_loop /
// df_fx_once / df_fx_stop, df_tower_fx_start / df_tower_fx_stop_after, df_model / df_model_angles, df_coord,
// df_ground, df_table_slot / df_table_yaw, df_model_rest_z (world agent 2026-09-09), df_scaled_for,
// df_player_count, df_touch, df_complete, df_say, df_debug_print, df_abs, and the 2026-09-09 core additions
// df_step_focus, df_cue_side_flash, df_fx_burst, df_vox_once (tools/audit_V2core.md).
// df_s7_tower_safety_volume( on ) is also meant for the act2_maxis agent (M1 latch, audit #6): plain level
// function, idempotent, safe from any file that #includes this one.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;

// Registers step7 and sets the wave config (read once; period / alive cap / orb hp / hold are per player
// count, index 0..3 = 1..4 players; the cap is per side: Richtofen has Avogadro on top, audit 2.3). Every
// table here is the FALLBACK for a df_steps row of the same meaning (orb_hp, hold_time, s7_period,
// s7_cap_rich, s7_cap_maxis): the row wins when it exists (df_s7_orb_hp, df_s7_hold_seconds,
// df_s7_period, df_s7_cap). Values = steps audit v2 section 6 table.
df_act3_hold_init()
{
    // config (read once)
    level.df_s7_cfg_orb_hp = []; // audit v2: 3000 +600 per extra player (df_steps "orb_hp" row wins)
    level.df_s7_cfg_orb_hp[0] = 3000;
    level.df_s7_cfg_orb_hp[1] = 3600;
    level.df_s7_cfg_orb_hp[2] = 4200;
    level.df_s7_cfg_orb_hp[3] = 4800;
    level.df_s7_cfg_hold = []; // audit v2: shorter co-op waves so they do not sag (df_steps "hold_time" row wins)
    level.df_s7_cfg_hold[0] = 75;
    level.df_s7_cfg_hold[1] = 90;
    level.df_s7_cfg_hold[2] = 105;
    level.df_s7_cfg_hold[3] = 120;
    level.df_s7_cfg_strike_min = 10; // charge strikes every 10-20 s (df_s7_charge_strikes)
    level.df_s7_cfg_strike_max = 20;
    level.df_s7_cfg_strike_heal = 0.10; // a strike heals this fraction of max hp (audit v2: 10 % stays)
    level.df_s7_cfg_strike_heal_guarded = 0.15; // ... 15 % while a player guards the orb (audit v2 #5)
    level.df_s7_cfg_swing_dmg = 30; // was 40 (owner 2026-09-09); the count on the orb is the lever, not the swing
    level.df_s7_cfg_swing_dmg_guarded = 15; // half while a player guards the orb (audit v2 #5)
    level.df_s7_cfg_guard_radius = 200; // a living player this close to the orb = guarded
    level.df_s7_cfg_damaged_frac = 0.3; // below 30 % hp the orb is "damaged": faster bursts + warning beep
    level.df_s7_cfg_actor_limit = 48;
    level.df_s7_cfg_zone_reset = 5; // seconds back inside the zone that clear the absence counter
    level.df_s7_cfg_period = []; // audit v2: solo 1.3 s (58 spawns instead of 75); df_steps "s7_period" row wins
    level.df_s7_cfg_period[0] = 1.3;
    level.df_s7_cfg_period[1] = 1.0;
    level.df_s7_cfg_period[2] = 0.8;
    level.df_s7_cfg_period[3] = 0.7;
    level.df_s7_cfg_cap = [];
    level.df_s7_cfg_cap["rich"] = []; // df_steps "s7_cap_rich" row wins
    level.df_s7_cfg_cap["rich"][0] = 10;
    level.df_s7_cfg_cap["rich"][1] = 14;
    level.df_s7_cfg_cap["rich"][2] = 18;
    level.df_s7_cfg_cap["rich"][3] = 22;
    level.df_s7_cfg_cap["maxis"] = []; // df_steps "s7_cap_maxis" row wins
    level.df_s7_cfg_cap["maxis"][0] = 14;
    level.df_s7_cfg_cap["maxis"][1] = 18;
    level.df_s7_cfg_cap["maxis"][2] = 22;
    level.df_s7_cfg_cap["maxis"][3] = 26;

    df_register_step( "step7", ::df_s7_run, undefined );
}

// True when df_steps defines the scaling row `key` (the steps agent adds rows over time; every read here
// falls back to the local table until then).
df_s7_row_exists( key )
{
    return isdefined( level.df_scale ) && isdefined( level.df_scale[key] );
}

// Player count the wave is scaled on: the count snapshotted when Step 7 became available (df_steps
// level.df_step_players, the df_scaled_step rule), else the live count. Read once per wave into
// level.df_s7_players (audit 6.7: no live df_player_count in the spawner).
df_s7_player_count()
{
    if ( isdefined( level.df_step_players ) && isdefined( level.df_step_players["step7"] ) )
        return level.df_step_players["step7"];

    return df_player_count();
}

// Orb hp for this wave: the "orb_hp" scaling row when the steps agent has added it, else our table.
df_s7_orb_hp()
{
    if ( df_s7_row_exists( "orb_hp" ) )
        return df_scaled_for( "orb_hp", level.df_s7_players );

    return level.df_s7_cfg_orb_hp[level.df_s7_players - 1];
}

// Wave length in seconds: the "hold_time" row (75/90/105/120 after the steps agent's change), else our table.
df_s7_hold_seconds()
{
    if ( df_s7_row_exists( "hold_time" ) )
        return df_scaled_for( "hold_time", level.df_s7_players );

    return level.df_s7_cfg_hold[level.df_s7_players - 1];
}

// Seconds between two of our spawns: the "s7_period" row when it exists, else our table.
df_s7_period()
{
    if ( df_s7_row_exists( "s7_period" ) )
        return df_scaled_for( "s7_period", level.df_s7_players );

    return level.df_s7_cfg_period[level.df_s7_players - 1];
}

// Alive cap of our spawner for this wave: side row ("rich" also carries Avogadro) x player count; the
// "s7_cap_rich" / "s7_cap_maxis" rows when they exist, else our tables.
df_s7_cap()
{
    side = "maxis";

    if ( isdefined( level.df_side ) && level.df_side == "rich" )
        side = "rich";

    if ( df_s7_row_exists( "s7_cap_" + side ) )
        return df_scaled_for( "s7_cap_" + side, level.df_s7_players );

    return level.df_s7_cfg_cap[side][level.df_s7_players - 1];
}

// GUARD BONUS (steps audit v2 #5): 1 while a living player (is_player_valid: up, not in last stand) stands
// within df_s7_cfg_guard_radius of the wave orb. Read at every swing and every strike.
df_s7_guarded()
{
    if ( !isdefined( level.df_s7_orb ) )
        return 0;

    r2 = level.df_s7_cfg_guard_radius * level.df_s7_cfg_guard_radius;

    foreach ( player in getplayers() )
    {
        if ( is_player_valid( player ) && distancesquared( player.origin, level.df_s7_orb.origin ) < r2 )
            return 1;
    }

    return 0;
}

// Tower centre: the vanilla sq_common_area volume (level.sq_volume, zm_transit_sq.gsc), fixed fallback.
df_s7_tower_center()
{
    if ( isdefined( level.sq_volume ) )
        return level.sq_volume.origin;

    return ( 7644, -464, -132 );
}

// The place at the tower where the relay is powered: DF_SOCKET, which df_coords keeps on the table
// (DF_TABLE) since 2026-09-08. Every proximity check, prompt and fx of this step is keyed on it.
df_s7_socket()
{
    return df_coord( "DF_SOCKET" ).origin;
}

// Height of the orb's origin above the ground when it rests / rolls, and above the table top when it
// sits on its slot (df_s7_orb_slot): df_model_rest_z( "orb" ) from the df_coords registry (world agent
// 2026-09-09: the turbine rotor disc p6_zm_buildable_turbine_fan, 25 x 25 x 10, pivot at its base, hovers
// 5 = half its thickness under the aura). Same source in df_act3_vacuum (df_s6_orb_rest_offset): a model
// swap in df_coords moves both at once.
df_s7_orb_rest_offset()
{
    return ( 0, 0, df_model_rest_z( "orb" ) );
}

// One slow turn every 8 s (rotateyaw, the tombstone skull's spin _zm_tombstone.gsc:332), the same spin Step 6
// gives the resting disc, so it does not "stop" when the wave takes it. rotateyaw turns the angles while
// moveto (df_s7_orb_wander) moves the origin: independent movers. self = the wave orb; ends with it.
df_s7_orb_spin()
{
    self endon( "death" );
    level endon( "end_game" );

    while ( isdefined( self ) )
    {
        self rotateyaw( 360, 8 );
        wait 8;
    }
}

// Where the aura and the charge bursts ride relative to the orb's origin (the sphere's centre).
df_s7_orb_fx_offset()
{
    return ( 0, 0, 0 );
}

// Side charge burst: elec_md (zm_transit_fx.gsc:36) for Richtofen, lava_burning (:40) for Maxis.
df_s7_charge_fx()
{
    if ( isdefined( level.df_side ) && level.df_side == "maxis" )
        return "lava_burning";

    return "elec_md";
}

// Side aura alias shared with Step 6: level.df_orb_aura[side][level.df_orb_aura_idx] (published by
// df_act3_vacuum_init, cycled with "!df fire orb_aura"). Fallbacks if Step 6 is not loaded:
// avogadro_health_half (_zm_ai_avogadro.gsc:1372) / fx_zmb_tranzit_fire_med (zm_transit_fx.gsc:99).
df_s7_aura_fx()
{
    side = "rich";
    fallback = "avogadro_health_full";

    if ( isdefined( level.df_side ) && level.df_side == "maxis" )
    {
        side = "maxis";
        fallback = "powerup_on_caution";
    }

    if ( !isdefined( level.df_orb_aura ) || !isdefined( level.df_orb_aura[side] ) || level.df_orb_aura[side].size == 0 )
        return fallback;

    idx = 0;

    if ( isdefined( level.df_orb_aura_idx ) )
        idx = level.df_orb_aura_idx % level.df_orb_aura[side].size;

    return level.df_orb_aura[side][idx];
}

// 1 while the orb is below the damaged threshold.
df_s7_orb_damaged()
{
    return isdefined( level.df_s7_orb_hp ) && isdefined( level.df_s7_orb_max ) && level.df_s7_orb_hp < level.df_s7_orb_max * level.df_s7_cfg_damaged_frac;
}

// =========================================================================================
// Step flow
// =========================================================================================

// run_func: arm the socket, run waves until one succeeds (each fail runs the Step 6 restart contract).
df_s7_run()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );

    level.df_s7_active = 0;
    level.df_s7_force_start = 0;
    level thread df_s7_skip_cleanup();
    level thread df_s7_debug_start_watch();
    level thread df_s7_aura_change_watch();
    level.df_s7_players = df_s7_player_count();

    // the shared STEP AVAILABLE cue (df_steps) glints the focus until the first touch: 20 over the orb's slot
    df_step_focus( "step7", df_s7_orb_slot() + ( 0, 0, 20 ) );
    df_debug_print( "DF: s7 socket armed (hold " + df_s7_hold_seconds() + " s, orb " + df_s7_orb_hp() + " hp, period " + df_s7_period() + " s, cap " + df_s7_cap() + ", " + level.df_s7_players + " player(s))" );

    while ( true )
    {
        starter = df_s7_wait_for_start();
        result = df_s7_wave( starter );

        if ( result == "success" )
            break;

        df_s7_fail( result );

        // Step 6 contract (2026-09-08): our ball is gone (df_s7_orb_burst); Step 6 spawns the charged orb
        // again on the floor in front of the table, pickable; placing it again fires df_s6_redelivered and we re-arm
        df_debug_print( "DF: s7 notify df_s6_restart: orb back in front of the table, pick it up and place it again (waiting for df_s6_redelivered)" );
        level notify( "df_s6_restart" );
        level waittill_either( "df_s6_redelivered", "df_debug_s7_start" );
        df_debug_print( "DF: s7 orb redelivered, the table is armed again" );
    }

    df_s7_success();
}

// Poll players near the socket: df_prompt (mechanic), then hold use 3 s (usebuttonpressed + df_hold_use, a
// channelling hold the owner validated). Returns the player who started the wave (undefined for the debug hook).
df_s7_wait_for_start()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );

    socket = df_s7_socket();

    while ( true )
    {
        wait 0.1;

        if ( is_true( level.df_s7_force_start ) )
        {
            level.df_s7_force_start = 0;
            df_s7_prompts_off();
            df_debug_print( "DF: s7 started by debug hook" );
            return undefined;
        }

        foreach ( player in getplayers() )
        {
            near = is_player_valid( player ) && distancesquared( player.origin, socket ) < 150 * 150;
            player df_prompt( near, "Hold [{+activate}] to power the relay" );

            if ( !near || !player usebuttonpressed() )
                continue;

            df_touch( "step7" );
            player df_prompt( 0, undefined );

            if ( !player df_hold_use( socket, 200, 3, "Powering the relay" ) )
                continue;

            df_s7_prompts_off();
            return player;
        }
    }
}

// Every player's prompt off.
df_s7_prompts_off()
{
    foreach ( player in getplayers() )
        player df_prompt( 0, undefined );
}

// One wave. Returns "success" (timer out, orb alive), "fail_zone" (nobody held the zone),
// "fail_orb" (orb destroyed) or "fail_debug". Start cues: zmb_turn_on (zm_transit_power.gsc:60) at the
// socket, zmb_power_off_quad (:414) to every player, D7_START; Richtofen adds his canon "lure them to the
// obelisk" line once per game (vox_zmba_sidequest_zom_lure_0, zm_transit_sq.gsc:728, df_vox_once); Maxis
// lights the tower top for the whole wave (df_s7_column_start).
df_s7_wave( starter )
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );

    socket = df_s7_socket();
    level.df_s7_players = df_s7_player_count();
    level.df_s7_time = df_s7_hold_seconds();
    level.df_s7_orb_max = df_s7_orb_hp();
    level.df_s7_orb_hp = level.df_s7_orb_max;
    level.df_s7_result = undefined;
    level.df_s7_start_ms = gettime();
    level.df_s7_end_ms = level.df_s7_start_ms + level.df_s7_time * 1000;
    level.df_s7_out_ms = 0;
    level.df_s7_avo_ms = 0;
    level.df_s7_last_hit_snd = 0;
    level.df_s7_spawned = 0;
    level.df_s7_strike_n = 0;
    level.df_s7_striking = 0;
    level.df_s7_starter = starter;
    level.df_s7_active = 1;

    df_s7_orb_spawn();
    playsoundatposition( "zmb_screecher_portal_end", socket ); // owner pick 2026-09-11: Step 7 starts

    foreach ( player in getplayers() )
        player playsoundtoplayer( "zmb_power_off_quad", player );

    df_say( "D7_START" );
    side = "none";

    if ( isdefined( level.df_side ) )
        side = level.df_side;

    if ( side == "rich" )
        df_vox_once( "vox_zmba_sidequest_zom_lure_0", undefined ); // non-blocking, once per game
    else
        df_s7_column_start();

    df_debug_print( "DF: s7 wave started, " + level.df_s7_time + " s, orb " + level.df_s7_orb_hp + " hp, side " + side + ", guard bonus within " + level.df_s7_cfg_guard_radius );

    level thread df_s7_song_start();
    df_s7_boost( 1 );
    df_s7_find_spots();
    level thread df_s7_orb_wander();
    level thread df_s7_orb_pulse();
    level thread df_s7_orb_damaged_beep();
    level thread df_s7_charge_strikes();
    level thread df_s7_spawner();
    level thread df_s7_recruit_nearby();
    level thread df_s7_attract();
    level thread df_s7_hud_loop();
    level thread df_sys_clock_run( level.df_s7_end_ms, "df_s7_wave_over", "df_skip_step7" );
    level thread df_s7_zone_watch();
    level thread df_s7_side_pressure();
    level thread df_s7_debug_watch();

    while ( !isdefined( level.df_s7_result ) )
    {
        wait 0.1;

        if ( isdefined( level.df_s7_result ) )
            break;

        if ( gettime() >= level.df_s7_end_ms )
            level.df_s7_result = "success";
    }

    result = level.df_s7_result;
    df_debug_print( "DF: s7 wave over: " + result + " (orb hp " + level.df_s7_orb_hp + ", " + level.df_s7_spawned + " zombies spawned by us)" );
    df_s7_teardown();

    if ( result == "success" )
        df_s7_orb_return();
    else
        df_s7_orb_burst();

    return result;
}

// Ends every wave thread, releases the hunters and restores the world. Safe to call when no wave runs.
// The orb itself is handled by the caller (return / burst) or by df_s7_orb_remove.
df_s7_teardown()
{
    level.df_s7_active = 0;
    level notify( "df_s7_wave_over" );
    level thread df_s7_afterwave(); // owner 2026-09-11: the dead keep coming until the song ends
    df_s7_release_hunters();
    df_s7_boost( 0 );
    df_s7_denizens( 0 );
    df_s7_song_stop();
    df_fx_stop( level.df_s7_storm );
    level.df_s7_storm = undefined;
    df_s7_column_stop();
    df_s7_hud_destroy_all();
    df_s7_prompts_off();
}

// A failed wave: the line (the orb burst / restart cue is df_s7_orb_burst, the contract is df_s7_run);
// on Maxis his canon "your power supplies are drained, now start again" (vox_maxi_turbines_out_0,
// zm_transit_sq.gsc:331) at the table, once per game (df_vox_once; art audit S7.5).
df_s7_fail( result )
{
    df_say( "D7_FAIL" );

    if ( isdefined( level.df_side ) && level.df_side == "maxis" )
        df_vox_once( "vox_maxi_turbines_out_0", df_s7_socket() ); // non-blocking, once per game

    df_debug_print( "DF: s7 failed (" + result + ")" );
}

// Success after the glide-back: the rising column (fx_zmb_tranzit_power_rising, zm_transit_fx.gsc:119) at
// the socket, D7_DONE, then the ONE uniform STEP DONE sting through df_complete (art audit #1: the navcard
// chime that used to replace it means SUB-GOAL now). The tower fx started with the glide (df_s7_orb_return)
// and stop 12 s later.
df_s7_success()
{
    df_fx_once( "fx_zmb_tranzit_power_rising", df_s7_socket() );
    level thread df_tower_fx_stop_after( 12 );
    df_say( "D7_DONE" );
    df_complete( "step7" );
}

// Maxis's far cue for the wave (art audit S7.6: the Richtofen side has the storm at the top, the fire side
// had nothing): the large smoke column (fx_zmb_tranzit_smk_column_lrg, createfx zm_transit_fx.csc:596 /
// zm_transit_fx.gsc:101) at the tower top when the alias is registered, else three ash columns
// (fx_zmb_ash_rising_md, zm_transit_fx.gsc:81) 60 apart. Stopped by df_s7_column_stop at teardown.
df_s7_column_start()
{
    df_s7_column_stop();
    top = df_s7_tower_center() + ( 0, 0, 900 );
    level.df_s7_column = [];

    if ( isdefined( level._effect["fx_zmb_tranzit_smk_column_lrg"] ) )
    {
        level.df_s7_column[0] = df_fx_loop( "fx_zmb_tranzit_smk_column_lrg", top );
        return;
    }

    level.df_s7_column[0] = df_fx_loop( "fx_zmb_ash_rising_md", top );
    level.df_s7_column[1] = df_fx_loop( "fx_zmb_ash_rising_md", top + ( 60, 0, 0 ) );
    level.df_s7_column[2] = df_fx_loop( "fx_zmb_ash_rising_md", top + ( -60, 0, 0 ) );
}

// The tower-top column off (safe when none runs).
df_s7_column_stop()
{
    if ( isdefined( level.df_s7_column ) )
    {
        foreach ( ent in level.df_s7_column )
            df_fx_stop( ent );
    }

    level.df_s7_column = undefined;
}

// "!df goto" past us / skip: wave threads, hunters, world levers, orb, aura, hum, HUD and prompts all go.
df_s7_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_step7_done" );
    level waittill( "df_skip_step7" );

    df_s7_teardown();
    df_s7_orb_remove();
    level notify( "df_s7_orb_returned" ); // give the table slot back to Step 6's resting ball
    df_debug_print( "DF: s7 skipped, cleaned up" );
}

// =========================================================================================
// The orb
// =========================================================================================

// The orb (df_model( "orb" ), precached by df_coords_precache) lifted off the table's slot 2 - where
// Step 6 left it (df_s7_orb_slot) - the thing zombies swing at, with its side aura, a linked hum
// (zmb_meteor_loop, zm_transit.gsc:3349), the slow spin and the side flash (df_cue_side_flash) as it
// appears. The registry's base angles (df_model_angles) lay the disc flat, the yaw is the table's. Step 6's
// resting model is hidden for as long as ours exists: level notify( "df_s7_orb_taken" ) tells it to
// (contract with the Step 6 owner, 2026-09-08), and "df_s7_orb_returned" (success or a skip) gives the
// slot back.
df_s7_orb_spawn()
{
    df_s7_orb_remove();
    level notify( "df_s7_orb_taken" );
    pos = df_s7_orb_slot();

    // owner 2026-09-08: a small physical object instead of a lamp-sized light; its charge shows as the aura
    // plus electricity (Richtofen) or fire (Maxis) pulsed on it by df_s7_orb_pulse
    level.df_s7_orb = spawn( "script_model", pos );
    level.df_s7_orb setmodel( df_model( "orb" ) );
    level.df_s7_orb.angles = df_model_angles( "orb", df_table_yaw() );
    level.df_s7_orb thread df_s7_orb_spin();
    df_s7_orb_aura_on();

    level.df_s7_orb_snd = spawn( "script_origin", pos );
    level.df_s7_orb_snd linkto( level.df_s7_orb );
    level.df_s7_orb_snd playloopsound( "zmb_avogadro_loop" );
    df_cue_side_flash( pos, undefined );
    df_debug_print( "DF: s7 orb taken from the table, slot 2 (aura " + df_s7_aura_fx() + ")" );
}

// The orb's place on the table: slot 2 of DF_TABLE (df_coords), plus our rest offset - the same point
// Step 6 rests its delivered ball on, so the wave starts exactly where the player left it.
df_s7_orb_slot()
{
    return df_table_slot( 2 ) + df_s7_orb_rest_offset();
}

// Ball, aura, hum and the burst riding it all go.
df_s7_orb_remove()
{
    if ( isdefined( level.df_s7_orb_snd ) )
    {
        level.df_s7_orb_snd stoploopsound();
        level.df_s7_orb_snd delete();
    }

    level.df_s7_orb_snd = undefined;
    df_fx_stop( level.df_s7_orb_aura );
    level.df_s7_orb_aura = undefined;
    df_fx_stop( level.df_s7_orb_fx );
    level.df_s7_orb_fx = undefined;
    df_fx_stop( level.df_s7_orb );
    level.df_s7_orb = undefined;
}

// The permanent side aura on a tag_origin linked to the ball (replaces any previous one).
df_s7_orb_aura_on()
{
    df_fx_stop( level.df_s7_orb_aura );
    level.df_s7_orb_aura = undefined;

    if ( !isdefined( level.df_s7_orb ) )
        return;

    level.df_s7_orb_aura = df_fx_loop( df_s7_aura_fx(), level.df_s7_orb.origin + df_s7_orb_fx_offset() );

    if ( isdefined( level.df_s7_orb_aura ) )
        level.df_s7_orb_aura linkto( level.df_s7_orb );
}

// "!df fire orb_aura" (handled in df_act3_vacuum) ends with level notify( "df_orb_aura_changed" ): re-dress
// a living wave orb with the new candidate.
df_s7_aura_change_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_step7_done" );

    while ( true )
    {
        level waittill( "df_orb_aura_changed" );

        if ( isdefined( level.df_s7_orb ) )
        {
            df_s7_orb_aura_on();
            df_debug_print( "DF: s7 orb aura now " + df_s7_aura_fx() );
        }
    }
}

// The charge riding the ball while the wave runs: elec_md (Richtofen) or lava_burning (Maxis), both
// short bursts, replayed on a tag_origin linked to the ball so nothing lingers. Healthy: on 0.8 s,
// off 0.3 s. Damaged (below 30 % hp): on 0.4 s, off 0.1 s, so the ball visibly flickers.
df_s7_orb_pulse()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    fxname = df_s7_charge_fx();

    while ( isdefined( level.df_s7_orb ) )
    {
        on = 0.8;
        off = 0.3;

        if ( df_s7_orb_damaged() )
        {
            on = 0.4;
            off = 0.1;
        }

        df_fx_stop( level.df_s7_orb_fx );
        level.df_s7_orb_fx = df_fx_loop( fxname, level.df_s7_orb.origin + df_s7_orb_fx_offset() );

        if ( isdefined( level.df_s7_orb_fx ) )
            level.df_s7_orb_fx linkto( level.df_s7_orb );

        wait( on );
        df_fx_stop( level.df_s7_orb_fx );
        level.df_s7_orb_fx = undefined;
        wait( off );
    }
}

// Damaged state: every 2 s while the orb is below 30 % hp, the tombstone timer beep
// (zmb_tombstone_timer_count, _zm_tombstone.gsc:380, played to each player as vanilla does) and a
// short spark on the ball. Entering the state is printed once.
df_s7_orb_damaged_beep()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    announced = 0;

    while ( isdefined( level.df_s7_orb ) )
    {
        wait 0.5;

        if ( !df_s7_orb_damaged() )
        {
            announced = 0;
            continue;
        }

        if ( !announced )
        {
            announced = 1;
            df_debug_print( "DF: s7 orb damaged (" + level.df_s7_orb_hp + "/" + level.df_s7_orb_max + " hp): warning beeps on" );
        }

        foreach ( player in getplayers() )
            player playsoundtoplayer( "zmb_tombstone_timer_count", player );

        level thread df_s7_orb_spark( 0.3 );
        wait 1.5;
    }
}

// Charge strikes (owner 2026-09-08: "lightning on it every 10-20 s, like it is being charged"): while the
// wave runs, every level.df_s7_cfg_strike_min..max s one df_s7_charge_strike (blocking, so strikes never
// overlap). The debug hook "!df fire s7_strike" fires one now (df_s7_debug_strike_watch).
df_s7_charge_strikes()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    while ( isdefined( level.df_s7_orb ) )
    {
        wait( randomfloatrange( level.df_s7_cfg_strike_min, level.df_s7_cfg_strike_max ) );

        if ( isdefined( level.df_s7_orb ) )
            df_s7_charge_strike();
    }
}

// One charge strike on the wave orb. Build-up (2 s): the reactor rise sound (zmb_power_rise_start,
// zm_transit_power.gsc:399) on the disc and a fresh side burst (elec_md zm_transit_fx.gsc:36 / lava_burning
// :40) every 0.25 s on top of the normal pulse, so the static visibly thickens. Strike, per side (art audit
// #9: no blue on the fire side): Richtofen = Avogadro's arrival bolt from the sky (avogadro_descend =
// fx_zmb_avog_descend, _zm_ai_avogadro.gsc:33 loadfx, :814 playfx on the ground under him) on the ground
// under the disc, the lightning orb (sq_common_lightning, zm_transit_fx.gsc:20) and the side flash
// (df_cue_side_flash: the blue one-shot) on the disc; Maxis = the side flash (df_cue_side_flash: 0.8 s of
// fire_lrg), a second fire_lrg burst riding the disc (fx_zmb_tranzit_fire_lrg, :100), 0.8 s of ash on the
// ground under it (fx_zmb_ash_rising_md, :81, df_fx_burst) and the lava ignite sound ("ignite",
// zm_transit_lava.gsc:275). Both: his
// thunder crack (zmb_avogadro_spawn_3d, _zm_ai_avogadro.gsc:810) and a short rumble (earthquake, as the
// hellhound bolt _zm_ai_dogs.gsc:205). A strike CHARGES the orb: 10 % of max hp back, 15 % while a player
// guards it (df_s7_guarded, audit v2 #5). Refused while another strike runs.
df_s7_charge_strike()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    if ( is_true( level.df_s7_striking ) || !isdefined( level.df_s7_orb ) )
        return;

    level.df_s7_striking = 1;
    level.df_s7_strike_n++;
    n = level.df_s7_strike_n;
    maxis = isdefined( level.df_side ) && level.df_side == "maxis";
    level.df_s7_orb playsound( "zmb_power_rise_start" );

    for ( t = 0; t < 8; t++ )
    {
        level thread df_s7_orb_fx_burst( df_s7_charge_fx(), 0.5 );
        wait 0.25;

        if ( !isdefined( level.df_s7_orb ) )
        {
            level.df_s7_striking = 0;
            return;
        }
    }

    pos = level.df_s7_orb.origin;

    if ( maxis )
    {
        level thread df_s7_orb_fx_burst( "fx_zmb_tranzit_fire_lrg", 0.8 );
        df_fx_burst( "fx_zmb_ash_rising_md", df_ground( pos ), 0.8 );
        level.df_s7_orb playsound( "zmb_phdflop_explo" ); // fire whoosh ("ignite" is in no TranZit bank)
    }
    else
    {
        df_fx_once( "avogadro_descend", df_ground( pos ) );
        df_fx_once( "sq_common_lightning", pos );
        level thread df_s7_orb_fx_burst( "elec_md", 0.6 );
    }

    df_cue_side_flash( pos, undefined );
    playsoundatposition( "zmb_avogadro_spawn_3d", pos );
    earthquake( 0.25, 0.5, pos, 600 );

    // owner 2026-09-09: a strike CHARGES the orb (the strikes are the reason to hold on); audit v2 #5: more
    // while a living player stands with it
    if ( isdefined( level.df_s7_orb_hp ) && isdefined( level.df_s7_orb_max ) && level.df_s7_orb_hp > 0 )
    {
        frac = level.df_s7_cfg_strike_heal;
        guarded = df_s7_guarded();

        if ( guarded )
            frac = level.df_s7_cfg_strike_heal_guarded;

        heal = int( level.df_s7_orb_max * frac );
        level.df_s7_orb_hp += heal;

        if ( level.df_s7_orb_hp > level.df_s7_orb_max )
            level.df_s7_orb_hp = level.df_s7_orb_max;

        df_debug_print( "DF: s7 charge strike " + n + " healed the orb +" + heal + " (guarded " + guarded + ") -> " + level.df_s7_orb_hp + "/" + level.df_s7_orb_max );
    }
    else
        df_debug_print( "DF: s7 charge strike " + n );

    level.df_s7_striking = 0;
}

// Wander under the tower: random points within 250 of the centre, on the ground, reachable in a straight
// line from where the orb is (a bullettrace that hits something is rejected); moveto 4-6 s per leg, 1-2 s pauses.
df_s7_orb_wander()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    center = df_s7_tower_center();

    while ( isdefined( level.df_s7_orb ) )
    {
        dest = df_s7_orb_pick_point( center );

        if ( isdefined( dest ) )
        {
            time = randomfloatrange( 4, 6 );
            level.df_s7_orb moveto( dest, time );
            wait( time );
        }

        wait( randomfloatrange( 1, 2 ) );
    }
}

// A ground point within 60-250 of the centre with a clear straight line from the ball, or undefined after 8 tries.
df_s7_orb_pick_point( center )
{
    for ( tries = 0; tries < 8; tries++ )
    {
        dir = anglestoforward( ( 0, randomint( 360 ), 0 ) );
        flat = center + dir * randomfloatrange( 60, 250 );
        dest = df_ground( ( flat[0], flat[1], center[2] + 40 ) ) + df_s7_orb_rest_offset() + ( 0, 0, 40 ); // hovers 40 up (owner 2026-09-11: hard to see on the ground)
        trace = bullettrace( level.df_s7_orb.origin, dest, 0, level.df_s7_orb );

        if ( isdefined( trace["fraction"] ) && trace["fraction"] < 1 )
            continue;

        return dest;
    }

    return undefined;
}

// Success: the tower lights up in the side colour (df_tower_fx_start) and the orb glides back ONTO ITS
// SLOT on the table over 2 s with the power-rise sound of the reactor core (zmb_power_rise_start /
// _loop / _stop, zm_transit_power.gsc:399-409). Our ball is then removed and "df_s7_orb_returned" hands
// the slot back to Step 6, whose model rests there for the finale.
df_s7_orb_return()
{
    if ( !isdefined( level.df_s7_orb ) )
        return;

    df_tower_fx_start( level.df_side );
    dest = df_s7_orb_slot();
    level.df_s7_orb playsound( "zmb_power_rise_start" );

    if ( isdefined( level.df_s7_orb_snd ) )
    {
        level.df_s7_orb_snd stoploopsound();
        level.df_s7_orb_snd playloopsound( "zmb_power_rise_loop" );
    }

    level.df_s7_orb moveto( dest, 2 );
    wait 2;

    if ( isdefined( level.df_s7_orb ) )
        level.df_s7_orb playsound( "zmb_power_rise_stop" );

    df_cue_side_flash( dest, undefined );
    df_s7_orb_remove();
    level notify( "df_s7_orb_returned" ); // Step 6 shows its resting disc on the slot again
    df_debug_print( "DF: s7 orb back on the table, slot 2" );
}

// Failure: the orb bursts in the side family (art audit #9): two side flashes (df_cue_side_flash: blue
// one-shots on Richtofen, fire bursts on Maxis), a 0.8 s side burst (elec_md / lava_burning, df_fx_burst)
// left behind at the spot, on Maxis 0.8 s of ash too (fx_zmb_ash_rising_md, zm_transit_fx.gsc:81), and the
// bus EMP sound (zmb_bus_emp_shutdown, zm_transit_bus.gsc:3097). Our disc, aura, hum and riding fx are
// deleted right here (df_s7_orb_remove): the burst fx stand alone at the spot, and Step 6 spawns its own
// pickable orb at the socket on df_s6_restart, so nothing of ours may linger.
df_s7_orb_burst()
{
    if ( isdefined( level.df_s7_orb ) )
    {
        pos = level.df_s7_orb.origin;
        df_cue_side_flash( pos, undefined );
        df_cue_side_flash( pos + ( 0, 0, 40 ), undefined );
        df_fx_burst( df_s7_charge_fx(), pos + df_s7_orb_fx_offset(), 0.8 );

        if ( isdefined( level.df_side ) && level.df_side == "maxis" )
            df_fx_burst( "fx_zmb_ash_rising_md", df_ground( pos ), 0.8 );

        playsoundatposition( "zmb_bus_emp_shutdown", pos );
    }

    df_s7_orb_remove();
    df_debug_print( "DF: s7 orb burst" );
}

// Every hit: 0.4 s of sparks on the orb; the emp sound at most every 5 s; hp 0 = fail. Crossing the
// damaged threshold is printed (the beep thread takes over from there).
df_s7_orb_damage( amount, who )
{
    if ( !is_true( level.df_s7_active ) || level.df_s7_orb_hp <= 0 || !isdefined( level.df_s7_orb ) )
        return;

    level.df_s7_orb_hp -= amount;
    level thread df_s7_orb_spark( 0.4 );

    if ( gettime() - level.df_s7_last_hit_snd > 5000 )
    {
        level.df_s7_last_hit_snd = gettime();
        playsoundatposition( "zmb_bus_emp_shutdown", level.df_s7_orb.origin );
    }

    df_debug_print( "DF: s7 orb hit by " + who + ", hp " + level.df_s7_orb_hp );

    if ( level.df_s7_orb_hp > 0 )
        return;

    level.df_s7_orb_hp = 0;
    df_debug_print( "DF: s7 orb destroyed" );
    level.df_s7_result = "fail_orb";
}

// Short controllable spark riding the orb (elec_md, zm_transit_fx.gsc:36). Hits are physical, so both sides spark.
df_s7_orb_spark( seconds )
{
    df_s7_orb_fx_burst( "elec_md", seconds );
}

// A short burst of `fxname` on a tag_origin linked to the ball, deleted after `seconds` (the controllable
// way to play the short-burst fx: elec_md, lava_burning, fx_zmb_tranzit_fire_lrg). Thread it.
df_s7_orb_fx_burst( fxname, seconds )
{
    level endon( "end_game" );

    if ( !isdefined( level.df_s7_orb ) )
        return;

    ent = df_fx_loop( fxname, level.df_s7_orb.origin + df_s7_orb_fx_offset() );

    if ( isdefined( ent ) && isdefined( level.df_s7_orb ) )
        ent linkto( level.df_s7_orb );

    wait( seconds );
    df_fx_stop( ent );
}

// =========================================================================================
// Zombies: our spawner, the hunt and the swing
// =========================================================================================

// Spawn structs of the tower's zone: every zone.spawn_locations struct within 1400 of the tower centre
// (the zone manager already sorted risers/normal spawns into zone.spawn_locations); fallback: the raw
// cornfield spawner structs with a riser_location tag within 1400.
df_s7_find_spots()
{
    center = df_s7_tower_center();
    level.df_s7_spots = [];

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

                if ( distancesquared( s.origin, center ) < 1400 * 1400 )
                    level.df_s7_spots[level.df_s7_spots.size] = s;
            }
        }
    }

    if ( level.df_s7_spots.size == 0 )
    {
        foreach ( s in getstructarray( "zone_amb_cornfield_spawners", "targetname" ) )
        {
            if ( !isdefined( s.script_noteworthy ) || !issubstr( s.script_noteworthy, "riser_location" ) )
                continue;

            if ( distancesquared( s.origin, center ) < 1400 * 1400 )
                level.df_s7_spots[level.df_s7_spots.size] = s;
        }
    }

    df_debug_print( "DF: s7 " + level.df_s7_spots.size + " spawn structs near the tower" );
}

// Our spawner: every spawn_period, while our living zombies are under the cap and the engine has a free
// actor (getfreeactorcount), a regular zombie (level.zombie_spawners, spawn_zombie _zm_utility.gsc:236 as
// round_spawning _zm.gsc:2896 does) placed at one of the tower structs through the spawn hooks
// do_zombie_spawn (_zm_spawner.gsc:2612) reads (_rise_spot / spawn_point_override).
df_s7_spawner()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    period = df_s7_period();
    cap = df_s7_cap();
    df_debug_print( "DF: s7 spawner on: every " + period + " s, cap " + cap + " (" + level.df_s7_players + " player(s) at wave start)" );

    while ( true )
    {
        wait( period );

        if ( !isdefined( level.df_s7_orb ) || level.df_s7_spots.size == 0 )
            continue;

        if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
            continue;

        if ( df_s7_count_ours() >= cap || getfreeactorcount() < 1 )
            continue;

        spot = random( level.df_s7_spots );
        spawner = random( level.zombie_spawners );
        ai = spawn_zombie( spawner, spawner.targetname, spot );

        if ( !isdefined( ai ) )
            continue;

        // the zombie's own spawn logic runs at frame end: hand it our struct now
        if ( isdefined( spot.script_noteworthy ) && issubstr( spot.script_noteworthy, "riser_location" ) )
            ai._rise_spot = spot;
        else
            ai.spawn_point_override = spot;

        ai.df_s7_ours = 1;
        level.df_s7_spawned++;
        ai thread df_s7_hunt_orb( 1 );
    }
}

// Living zombies our spawner raised (ai.df_s7_ours), from getaiarray( level.zombie_team ).
df_s7_count_ours()
{
    n = 0;

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( isdefined( ai ) && isalive( ai ) && is_true( ai.df_s7_ours ) )
            n++;
    }

    return n;
}

// Vanilla zombies already up within 1200 of the tower join the hunt (checked every 2 s).
df_s7_recruit_nearby()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    center = df_s7_tower_center();

    while ( true )
    {
        foreach ( ai in getaiarray( level.zombie_team ) )
        {
            if ( !isdefined( ai ) || !isalive( ai ) || is_true( ai.df_s7_hunter ) )
                continue;

            if ( !isdefined( ai.animname ) || ai.animname != "zombie" || is_true( ai.isonbus ) || is_true( ai.isscreecher ) )
                continue;

            if ( distancesquared( ai.origin, center ) < 1200 * 1200 )
                ai thread df_s7_hunt_orb( 0 );
        }

        wait 2;
    }
}

// self = zombie. Drives it to the orb the way vanilla drives to a point of interest
// (_zm_spawner::zombie_follow_enemy :2517: setgoalpos + goalradius), re-asserted every 0.5 s so the vanilla
// find_flesh (_zm_ai_basic.gsc:11) started after rising cannot take over; set_zombie_run_cycle( "sprint" )
// (_zm_utility.gsc:199) once. fresh = 1: wait until the zombie has risen ("risen" notify).
df_s7_hunt_orb( fresh )
{
    self endon( "death" );
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    self.df_s7_hunter = 1;

    if ( fresh )
        self waittill( "risen" );

    while ( isdefined( level.df_s7_orb ) )
    {
        wait 0.5;

        if ( !isdefined( self.animname ) || self.animname != "zombie" )
            return;

        if ( is_true( self.is_traversing ) || is_true( self.is_inert ) )
            continue;

        if ( !is_true( self.df_s7_sprinted ) && is_true( self.has_legs ) && isdefined( self.zombie_move_speed ) && self.zombie_move_speed != "sprint" && !is_true( self.isonbus ) )
        {
            self.df_s7_sprinted = 1;
            self set_zombie_run_cycle( "sprint" );
        }

        self notify( "stop_find_flesh" );
        self notify( "zombie_acquire_enemy" );
        self.ignoreall = 0; // hunters still swing at players standing in their way

        if ( is_true( self.doing_equipment_attack ) )
            continue;

        self.goalradius = 48;
        self setgoalpos( level.df_s7_orb.origin );
    }
}

// Wave over: hunters go back to hunting players (vanilla restore from _zm_ai_basic inert wakeup:
// ignoreall 0, level.ignore_find_flesh check, find_flesh).
df_s7_release_hunters()
{
    n = 0;

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( !isdefined( ai ) || !isalive( ai ) || !is_true( ai.df_s7_hunter ) )
            continue;

        ai.df_s7_hunter = 0;
        ai.ignoreall = 0;
        ai notify( "zombie_acquire_enemy" );

        if ( !isdefined( level.ignore_find_flesh ) || !ai [[ level.ignore_find_flesh ]]() )
            ai thread maps\mp\zombies\_zm_ai_basic::find_flesh();

        n++;
    }

    df_debug_print( "DF: s7 " + n + " hunters released" );
}

// Zombies within 72 (flat) / 90 (vertical) of the orb swing at it (vanilla equipment-attack pattern
// _zm_equipment::attack_item :1571, as Step 3 does on the bus).
df_s7_attract()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    while ( true )
    {
        wait 0.1;

        orb = level.df_s7_orb;

        if ( !isdefined( orb ) )
            continue;

        foreach ( ai in getaiarray( level.zombie_team ) )
        {
            if ( !isdefined( ai ) || !isalive( ai ) )
                continue;

            if ( is_true( ai.is_inert ) || is_true( ai.is_traversing ) || is_true( ai.doing_equipment_attack ) )
                continue;

            // only regular zombies swing (vanilla is_quad/is_leaper crash on AI without an animname)
            if ( is_true( ai.isscreecher ) || !isdefined( ai.animname ) || ai.animname != "zombie" )
                continue;

            vdist = df_abs( ai.origin[2] - orb.origin[2] );
            d2 = distance2dsquared( ai.origin, orb.origin );

            if ( d2 < 72 * 72 && vdist < 90 )
                ai thread df_s7_attack_swing( orb );
        }
    }
}

// self = zombie. One melee swing at the orb: the vanilla attack_item body (_zm_equipment.gsc:1571;
// attack_item_stop :1651, attack_item_interrupt :1633, do_zombies_playvocals _zm_audio.gsc:326, melee anims
// zm_window_melee / zm_*_melee_crawl / zm_stumpy_melee, flat_angle _zm_utility.gsc:4120, impact sound
// fly_riotshield_zm_impact_flesh) with our own damage: level.df_s7_cfg_swing_dmg, halved to
// df_s7_cfg_swing_dmg_guarded while a living player stands with the orb (df_s7_guarded, audit v2 #5).
df_s7_attack_swing( item )
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
    self animscripted( self.origin, flat_angle( vectortoangles( item.origin - self.origin ) ), melee_anim );
    self notify( "item_attack" );
    dmg = level.df_s7_cfg_swing_dmg;
    who = "zombie";

    if ( df_s7_guarded() )
    {
        dmg = level.df_s7_cfg_swing_dmg_guarded;
        who = "zombie (guarded)";
    }

    df_s7_orb_damage( dmg, who );
    item playsound( "fly_riotshield_zm_impact_flesh" );
    wait( randomint( 100 ) / 100.0 );
    self.doing_equipment_attack = 0;
    self orientmode( "face default" );
}

// =========================================================================================
// Vanilla boost (kept small: our spawner does the work)
// =========================================================================================
// _zm_utility::set_run_speed() draws randomintrange( level.zombie_move_speed, +35 ) and sprints above 70:
// at 100 every zombie spawned during the wave (vanilla's or ours) sprints. Restored with vanilla's own
// formula (_zm.gsc round_end) because a round change during the wave would make a saved copy stale.
// level.zombie_actor_limit is raised so vanilla's spawner does not clear corpses under our horde; the
// vanilla alive limit and zombie_total are left alone: round_spawning simply pauses while
// get_current_zombie_count() >= level.zombie_ai_limit, and the round stays open while zombies are alive
// (round_wait), so it resumes and ends normally after the wave.

// on = 1: raise level.zombie_actor_limit and set zombie_move_speed 100 (saved first); on = 0: restore.
df_s7_boost( on )
{
    if ( on )
    {
        if ( is_true( level.df_s7_boosted ) )
            return;

        level.df_s7_boosted = 1;
        level.df_s7_saved_actor_limit = level.zombie_actor_limit;
        level.df_s7_saved_move_speed = level.zombie_move_speed;
        level.zombie_actor_limit = level.df_s7_cfg_actor_limit;
        level.zombie_move_speed = 100;
        df_debug_print( "DF: s7 boost on (sprint spawns, actor limit " + level.zombie_actor_limit + ")" );
        return;
    }

    if ( !is_true( level.df_s7_boosted ) )
        return;

    level.df_s7_boosted = 0;

    if ( isdefined( level.df_s7_saved_actor_limit ) )
        level.zombie_actor_limit = level.df_s7_saved_actor_limit;

    restored = level.df_s7_saved_move_speed;

    if ( isdefined( level.zombie_vars ) && isdefined( level.gamedifficulty ) )
    {
        if ( level.gamedifficulty == 0 && isdefined( level.zombie_vars["zombie_move_speed_multiplier_easy"] ) )
            restored = level.round_number * level.zombie_vars["zombie_move_speed_multiplier_easy"];
        else if ( isdefined( level.zombie_vars["zombie_move_speed_multiplier"] ) )
            restored = level.round_number * level.zombie_vars["zombie_move_speed_multiplier"];
    }

    if ( isdefined( restored ) )
        level.zombie_move_speed = restored;

    df_debug_print( "DF: s7 boost off" );
}

// =========================================================================================
// Song (mirrors zm_transit::sndplaymusicegg, guarded like the bears' waitfor_override)
// =========================================================================================

// mus_zmb_secret_song (zm_transit.gsc sndplaymusicegg) on a script_origin over the tower, refused while
// level.music_override is set or within 330 s of the previous start.
df_s7_song_start()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    if ( is_true( level.music_override ) )
    {
        df_debug_print( "DF: s7 song refused, music_override set" );
        return;
    }

    // owner test 2026-09-08: two songs overlapped after a fail + retry, so stopsounds() does not end the
    // streamed track. One start per song length (5.5 min): a retry inside that window keeps the running one.
    if ( isdefined( level.df_s7_song_ms ) && gettime() - level.df_s7_song_ms < 330000 )
    {
        df_debug_print( "DF: s7 song still running from the last attempt, not restarted" );
        return;
    }

    df_s7_song_stop();
    level.df_s7_song_ent = spawn( "script_origin", df_s7_tower_center() + ( 0, 0, 100 ) );
    wait 1;
    level.df_s7_song_ent playsound( "mus_zmb_secret_song" );
    level.df_s7_song_ms = gettime();
    df_debug_print( "DF: s7 song started" );
}

// stopsounds on the song entity (does not end an already streaming track: see the 330 s guard), then delete.
df_s7_song_stop()
{
    if ( !isdefined( level.df_s7_song_ent ) )
        return;

    level.df_s7_song_ent stopsounds();
    level thread df_s7_song_delete( level.df_s7_song_ent );
    level.df_s7_song_ent = undefined;
    df_debug_print( "DF: s7 song stopped" );
}

// Deletes the song entity a frame after stopsounds.
df_s7_song_delete( ent )
{
    wait 0.05;

    if ( isdefined( ent ) )
        ent delete();
}

// =========================================================================================
// Zone and countdown
// =========================================================================================

// Nobody alive (is_player_valid) inside the 700 zone for more than 10 s cumulative fails the wave. The bus
// horn (zmb_bus_horn_warn, zm_transit_bus.gsc:3067) at 5 s warns. df_s7_cfg_zone_reset s spent back inside
// without a break clear the counter (audit section 5: three short trips no longer add up to a fail).
df_s7_zone_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    center = df_s7_tower_center();
    warned = 0;
    inside_ms = 0;

    while ( true )
    {
        wait 0.1;
        inside = 0;

        foreach ( player in getplayers() )
        {
            if ( is_player_valid( player ) && distancesquared( player.origin, center ) < 700 * 700 )
            {
                inside = 1;
                break;
            }
        }

        if ( inside )
        {
            inside_ms += 100;

            if ( level.df_s7_out_ms > 0 && inside_ms >= level.df_s7_cfg_zone_reset * 1000 )
            {
                level.df_s7_out_ms = 0;
                warned = 0;
                df_debug_print( "DF: s7 zone held " + level.df_s7_cfg_zone_reset + " s, absence counter reset" );
            }

            continue;
        }

        inside_ms = 0;
        level.df_s7_out_ms += 100;

        if ( level.df_s7_out_ms >= 5000 && !warned )
        {
            warned = 1;
            df_debug_print( "DF: s7 zone empty for 5 s cumulative" );

            foreach ( player in getplayers() )
                player playsoundtoplayer( "zmb_bus_horn_warn", player );
        }

        if ( level.df_s7_out_ms > 10000 )
        {
            df_debug_print( "DF: s7 zone abandoned" );
            level.df_s7_result = "fail_zone";
            return;
        }
    }
}

// Countdown at the top of the screen for every player (late joiners get one too).
df_s7_hud_loop()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    while ( true )
    {
        foreach ( player in getplayers() )
        {
            if ( !isdefined( player.df_s7_hud ) )
                player df_s7_hud_create();
        }

        wait 0.5;
    }
}

// self = player. Countdown top centre, side colour, big "objective" font with the dark glow vanilla uses on
// its notify text (glowcolor / glowalpha, _hud_message.gsc:64) so it reads against the sky; settimer counts down.
df_s7_hud_create()
{
    if ( !df_sys_hud_timers() )
        return; // owner 2026-09-09: no timer on screen, the clock ticks instead

    remaining = ( level.df_s7_end_ms - gettime() ) / 1000;

    if ( remaining < 0.1 )
        remaining = 0.1;

    color = ( 1, 0.78, 0.5 );

    if ( level.df_side == "rich" )
        color = ( 0.6, 0.82, 1 );

    hud = newclienthudelem( self );
    hud.alignx = "center";
    hud.aligny = "top";
    hud.horzalign = "user_center";
    hud.vertalign = "user_top";
    hud.x = 0;
    hud.y = 30;
    hud.font = "objective";
    hud.fontscale = 2.4;
    hud.color = color;
    hud.alpha = 1;
    hud.glowcolor = ( 0, 0, 0 );
    hud.glowalpha = 1;
    hud.foreground = 1;
    hud.hidewheninmenu = 1;
    hud settimer( remaining );
    self.df_s7_hud = hud;
}

// Every player's countdown off.
df_s7_hud_destroy_all()
{
    foreach ( player in getplayers() )
    {
        if ( isdefined( player.df_s7_hud ) )
            player.df_s7_hud destroy();

        player.df_s7_hud = undefined;
    }
}

// The debug timer hook moves the end: refresh every countdown.
df_s7_hud_refresh_all()
{
    df_s7_hud_destroy_all();

    foreach ( player in getplayers() )
        player df_s7_hud_create();
}

// =========================================================================================
// Side pressure, from the start of the wave (audit 2.3)
// =========================================================================================

// Richtofen: Avogadro is recalled at once and is the wave's boss (df_s7_avogadro_boss); Maxis: the denizens
// are loose on the tower from the first second (levers + safety volume, df_s7_denizens).
df_s7_side_pressure()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    if ( isdefined( level.df_side ) && level.df_side == "rich" )
    {
        df_debug_print( "DF: s7 Richtofen pressure: Avogadro from the start" );
        level thread df_s7_avogadro_watch();
        level thread df_s7_avogadro_boss();
        df_s7_recall_avogadro();
        return;
    }

    df_debug_print( "DF: s7 Maxis pressure: denizens from the start" );
    df_s7_denizens( 1 );
}

// ---- Richtofen: Avogadro (same recall as R1: region = a player's, return_round = now, then warped) ----

// Avogadro as the boss of the wave (audit 8b(3)): S7_AVOGADRO_RICH once per game when he is called; his
// vanilla melee counter decides the fight (avogadro_damage_func _zm_ai_avogadro.gsc:1382: a knife hit adds
// 1, Galvaknuckles 2; at 4 avogadro_pain :1273 fires level notify( "avogadro_defeated" ) and he leaves for
// the cloud). He lands already wounded from R1 (df_s7_keep_avogadro_at_tower seeds one hit), so three knife
// hits banish him. Then his pressure ends (df_s7_avo_done stops the keeper and the orb damage), a Max Ammo
// drops at the table (specific_powerup_drop( "full_ammo" ), _zm_powerups.gsc:545, as the finale does) with
// the chime (zmb_sq_navcard_success, zm_transit_sq.gsc:1436).
df_s7_avogadro_boss()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    if ( !is_true( level.df_s7_avo_said ) )
    {
        level.df_s7_avo_said = 1;
        df_say( "S7_AVOGADRO_RICH" );
    }

    level waittill( "avogadro_defeated" );
    level notify( "df_s7_avo_done" );
    df_fx_stop( level.df_s7_storm );
    level.df_s7_storm = undefined;
    socket = df_s7_socket();
    spot = df_ground( socket + anglestoforward( ( 0, df_table_yaw(), 0 ) ) * 60 + ( 0, 0, 20 ) );
    level maps\mp\zombies\_zm_powerups::specific_powerup_drop( "full_ammo", spot );
    df_snd_near( "zmb_sq_navcard_success", socket, 3000 ); // team information; the alias fades at 175
    df_debug_print( "DF: s7 avogadro banished by knife, Max Ammo at the table" );
}

// Storm over the tower (fx_zmb_avog_storm, zm_transit_fx.gsc:120) + zmb_avogadro_spawn_3d, then the recall
// through level.avogadro.current_region / .return_round (_zm_ai_avogadro.gsc cloud logic).
df_s7_recall_avogadro()
{
    socket = df_s7_socket();
    tower_top = df_s7_tower_center() + ( 0, 0, 900 );
    df_fx_stop( level.df_s7_storm );
    level.df_s7_storm = df_fx_loop( "fx_zmb_avog_storm", tower_top );
    playsoundatposition( "zmb_avogadro_spawn_3d", socket );

    if ( !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) )
    {
        df_debug_print( "DF: s7 no avogadro entity to recall" );
        return;
    }

    df_debug_print( "DF: s7 avogadro state " + level.avogadro.state );

    if ( level.avogadro.state == "cloud" )
    {
        region = "cornfield";
        anchor = df_s7_zone_player();

        if ( isdefined( anchor ) )
            region = df_s7_region_of_player( anchor, region );

        level.avogadro.current_region = region;
        level.avogadro.return_round = level.round_number;
        df_debug_print( "DF: s7 avogadro called down over " + region );
        level thread df_s7_keep_avogadro_at_tower();
        return;
    }

    if ( level.avogadro.state == "chamber" )
    {
        df_debug_print( "DF: s7 avogadro still in the power chamber, no recall" );
        return;
    }

    level thread df_s7_keep_avogadro_at_tower();
}

// A living player inside the zone, else the starter, else any living player.
df_s7_zone_player()
{
    center = df_s7_tower_center();
    any = undefined;

    foreach ( player in getplayers() )
    {
        if ( !is_player_valid( player ) )
            continue;

        if ( distancesquared( player.origin, center ) < 700 * 700 )
            return player;

        if ( !isdefined( any ) )
            any = player;
    }

    if ( isdefined( level.df_s7_starter ) && is_player_valid( level.df_s7_starter ) )
        return level.df_s7_starter;

    return any;
}

// Region name ("bus", "diner", "farm", "cornfield", "power", "town") containing the player's zone
// (get_current_zone _zm_utility.gsc:2979, level.transit_region from zm_transit.gsc).
df_s7_region_of_player( player, fallback )
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

// Once he has landed, warp him next to the socket; while the wave runs keep his region on a living
// player (region_empty() would make him leave) and warp him back if he wanders off. Ends with the wave or
// with his defeat (df_s7_avo_done). On landing he carries one melee hit already (hit_by_melee, the counter
// avogadro_update_health :1369 reads: the "half" shimmer shows he is wounded), so three knife hits finish him.
df_s7_keep_avogadro_at_tower()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );
    level endon( "df_s7_avo_done" );

    for ( t = 0; t < 600; t++ )
    {
        wait 0.1;

        if ( !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) )
            return;

        if ( level.avogadro.state == "idle" || level.avogadro.state == "chasing" )
            break;
    }

    wait 1;

    if ( isdefined( level.avogadro ) && isdefined( level.avogadro.hit_by_melee ) && level.avogadro.hit_by_melee < 1 )
    {
        level.avogadro.hit_by_melee = 1;
        df_debug_print( "DF: s7 avogadro landed wounded (1 hit seeded, 3 knife hits banish him)" );
    }

    df_s7_avogadro_warp_near_socket();

    while ( true )
    {
        wait 2;

        if ( !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) )
            return;

        if ( level.avogadro.state != "idle" && level.avogadro.state != "chasing" )
            continue;

        anchor = df_s7_zone_player();

        if ( isdefined( anchor ) )
            level.avogadro.current_region = df_s7_region_of_player( anchor, level.avogadro.current_region );

        if ( distancesquared( level.avogadro.origin, df_s7_tower_center() ) > 1500 * 1500 )
            df_s7_avogadro_warp_near_socket();
    }
}

// A random ground point 320 from the socket, then the phase warp.
df_s7_avogadro_warp_near_socket()
{
    socket = df_s7_socket();
    dest = df_ground( socket + ( 0, 0, 60 ) + anglestoforward( ( 0, randomint( 360 ), 0 ) ) * 320 );
    level.avogadro thread df_s7_avogadro_phase_to( dest );
    df_debug_print( "DF: s7 avogadro warped to the tower" );
}

// self = avogadro. Mirrors _zm_ai_avogadro::do_phase (:1155) around the vanilla teleport routine
// avogadro_teleport (:929).
df_s7_avogadro_phase_to( dest )
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

// Avogadro within 100 units of the orb for more than 5 s cumulative: 10 hp/s (5 hp per 0.5 s tick). Ends
// with his defeat (df_s7_avo_done).
df_s7_avogadro_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );
    level endon( "df_s7_avo_done" );

    while ( true )
    {
        wait 0.5;

        if ( !isdefined( level.avogadro ) || !isdefined( level.avogadro.state ) || !isdefined( level.df_s7_orb ) )
            continue;

        state = level.avogadro.state;

        if ( state == "cloud" || state == "chamber" || state == "exiting" || state == "wait_for_player" )
            continue;

        if ( distancesquared( level.avogadro.origin, level.df_s7_orb.origin ) > 100 * 100 )
            continue;

        level.df_s7_avo_ms += 500;

        // owner 2026-09-09: softer. Ten seconds of grace, then 3 hp per half second while he camps the orb
        if ( level.df_s7_avo_ms <= 10000 )
            continue;

        df_s7_orb_damage( 3, "avogadro" );
    }
}

// ---- Maxis: denizens on the tower -----------------------------------------------------------
// Three verified levers, all restored at the end of the wave:
//   level.zones["zone_cornfield_prototype"].screecher_zone (zm_transit::init_screecher_zones),
//   level.zombie_ai_limit_screecher (2 in _zm_ai_screecher::init) raised to 4,
//   the tower's "screecher_volume" safety box (ents dump: info_volume at 7640 -457 -11) taken out of
//   level.safety_volumes (zm_transit::player_entered_safety_zone), which otherwise makes every player
//   at the tower invisible to the denizen spawner.

// on = 1: flip the three levers (saved first); on = 0: restore them.
df_s7_denizens( on )
{
    if ( on )
    {
        if ( is_true( level.df_s7_denizens_on ) )
            return;

        level.df_s7_denizens_on = 1;

        if ( isdefined( level.zones ) && isdefined( level.zones["zone_cornfield_prototype"] ) )
        {
            level.df_s7_zone_saved = level.zones["zone_cornfield_prototype"].screecher_zone;
            level.zones["zone_cornfield_prototype"].screecher_zone = 1;
        }

        level.df_s7_limit_saved = level.zombie_ai_limit_screecher;
        level.zombie_ai_limit_screecher = 4;
        df_s7_tower_safety_volume( 0 );
        df_debug_print( "DF: s7 denizens released on the tower" );
        return;
    }

    if ( !is_true( level.df_s7_denizens_on ) )
        return;

    level.df_s7_denizens_on = 0;

    if ( isdefined( level.zones ) && isdefined( level.zones["zone_cornfield_prototype"] ) )
        level.zones["zone_cornfield_prototype"].screecher_zone = level.df_s7_zone_saved;

    if ( isdefined( level.df_s7_limit_saved ) )
        level.zombie_ai_limit_screecher = level.df_s7_limit_saved;

    df_s7_tower_safety_volume( 1 );
    df_debug_print( "DF: s7 denizen levers restored" );
}

// on = 0: rebuild level.safety_volumes without the tower box and forget cached hits;
// on = 1: drop the cache so vanilla re-reads the full list on the next check (zm_transit.gsc:956
// player_entered_safety_zone rebuilds level.safety_volumes when it is undefined).
// Shared lever (audit #6): the act2_maxis agent calls it during the M1 latch from its own file (include
// df_act3_hold). Idempotent: repeated calls with the same value do nothing; level.df_s7_safety_off tells
// anyone the current state. M1 and Step 7 never overlap, so no reference count.
df_s7_tower_safety_volume( on )
{
    if ( on )
    {
        if ( !is_true( level.df_s7_safety_off ) )
            return;

        level.df_s7_safety_off = 0;
        level.safety_volumes = undefined;

        foreach ( player in getplayers() )
            player.last_safety_volume = undefined;

        df_debug_print( "DF: s7 tower safety volume restored" );
        return;
    }

    if ( is_true( level.df_s7_safety_off ) )
        return;

    level.df_s7_safety_off = 1;
    volumes = getentarray( "screecher_volume", "targetname" );
    center = df_s7_tower_center();
    kept = [];
    removed = 0;

    if ( !isdefined( volumes ) )
        volumes = [];

    foreach ( v in volumes )
    {
        flat = ( v.origin[0] - center[0], v.origin[1] - center[1], 0 );

        if ( lengthsquared( flat ) < 600 * 600 )
        {
            removed++;
            continue;
        }

        kept[kept.size] = v;
    }

    level.safety_volumes = kept;

    foreach ( player in getplayers() )
        player.last_safety_volume = undefined;

    df_debug_print( "DF: s7 tower safety volumes removed: " + removed );
}

// =========================================================================================
// Debug hooks (!df fire s7_start | s7_time | s7_fail | s7_hp | s7_dmg | s7_strike; orb_aura lives in df_act3_vacuum)
// =========================================================================================

// "!df fire s7_start": start the wave without the hold (also skips the redelivery wait after a fail).
df_s7_debug_start_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_step7_done" );

    while ( true )
    {
        level waittill( "df_debug_s7_start" );

        if ( !is_true( level.df_s7_active ) )
            level.df_s7_force_start = 1;
    }
}

// "!df fire s7_time": end the timer now (success if the orb is alive). Starts the other wave hooks.
df_s7_debug_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    level thread df_s7_debug_fail_watch();
    level thread df_s7_debug_hp_watch();
    level thread df_s7_debug_dmg_watch();
    level thread df_s7_debug_strike_watch();

    while ( true )
    {
        level waittill( "df_debug_s7_time" );
        level.df_s7_end_ms = gettime();
        df_s7_hud_refresh_all();
        df_debug_print( "DF: s7 timer ended by debug hook" );
    }
}

// "!df fire s7_fail": force a fail (runs the Step 6 restart contract).
df_s7_debug_fail_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    level waittill( "df_debug_s7_fail" );
    df_debug_print( "DF: s7 failed by debug hook" );
    level.df_s7_result = "fail_debug";
}

// "!df fire s7_hp": print the orb hp and our zombie counts.
df_s7_debug_hp_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    while ( true )
    {
        level waittill( "df_debug_s7_hp" );
        iprintln( "DF: s7 orb hp " + level.df_s7_orb_hp + "/" + level.df_s7_orb_max + ", ours alive " + df_s7_count_ours() + ", spawned " + level.df_s7_spawned );
    }
}

// "!df fire s7_dmg": 100 damage to the orb (solo: 14 fires from full reach the damaged state, 20 destroy it).
df_s7_debug_dmg_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    while ( true )
    {
        level waittill( "df_debug_s7_dmg" );
        df_s7_orb_damage( 100, "debug" );
    }
}

// "!df fire s7_strike": one charge strike now (2 s build-up, then the bolt); ignored while one runs.
df_s7_debug_strike_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );
    level endon( "df_s7_wave_over" );

    while ( true )
    {
        level waittill( "df_debug_s7_strike" );

        if ( is_true( level.df_s7_striking ) )
        {
            df_debug_print( "DF: s7 strike already running" );
            continue;
        }

        df_debug_print( "DF: s7 strike fired by debug hook" );
        level thread df_s7_charge_strike();
    }
}

// ---- after the hold: waves until the song ends (owner 2026-09-11) ------------------------------------
// The Easter Egg song (mus_zmb_secret_song, 256 s, cannot be stopped once streaming) keeps playing after the hold.
// While it plays: a regular zombie every df_s7_period() s near a random living player (zone spawn structs within
// 900 of him, else the six nearest), while fewer than df_s7_cap() zombies live within 1500 of him. They hunt
// normally, wherever the players go. Ends with the song, a new wave (a retry), or a skip.
df_s7_afterwave()
{
    level endon( "end_game" );
    level endon( "df_skip_step7" );

    if ( !isdefined( level.df_s7_song_ms ) || is_true( level.df_s7_afterwave_on ) )
        return;

    end_ms = level.df_s7_song_ms + 256500;

    if ( gettime() >= end_ms )
        return;

    level.df_s7_afterwave_on = 1;
    period = df_s7_period();
    cap = df_s7_cap();
    df_debug_print( "DF: s7 after the hold: waves near the players until the song ends in " + int( ( end_ms - gettime() ) / 1000 ) + " s" );

    while ( gettime() < end_ms && !is_true( level.df_s7_active ) )
    {
        wait( period );

        if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 || getfreeactorcount() < 1 )
            continue;

        players = [];

        foreach ( p in getplayers() )
        {
            if ( is_player_valid( p ) )
                players[players.size] = p;
        }

        if ( players.size == 0 )
            continue;

        player = random( players );

        // rc3 (owner): the waves rise AT THE TOWER, not beside the players (one player under the tower and three
        // farming far away was a free ride); the cap counts the dead around the tower
        center = df_s7_tower_center();

        if ( df_zombies_near( center, 1500 ) >= cap )
            continue;

        spots = level.df_s7_spots;

        if ( !isdefined( spots ) || spots.size == 0 )
            spots = df_spawn_spots_near( center, 1400 );

        if ( spots.size == 0 )
            continue;

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

    level.df_s7_afterwave_on = 0;
    df_debug_print( "DF: s7 after-hold waves over (song ended, or a new wave)" );
}
