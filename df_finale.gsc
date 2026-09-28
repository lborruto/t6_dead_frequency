// Dead Frequency - Finale (spec section 5 "Finale", forked by level.df_side) + the quest's tracker and
// mid-quest reward (design audit 2026-09-08, items #7, #8, section 3, 8d.1).
//   Trigger: hold use 1 s at the table under the tower (DF_SOCKET resolves to DF_TABLE) with the right
//   power state (Richtofen: power on; Maxis: power off NOW or at the start of this round, df_fin_power_ok).
//   Sequence: every perk first (never lost), a 6 s build-up at the tower in the SIDE'S ELEMENT (art audit
//   2026-09-09 section 3 Finale / #9: Richtofen = electric trap hum, blue sparks and arcs over the table, the
//   power-station current at the base; Maxis = fire crackle, brazier-fire pulses and lava "ignite" over the
//   table, an ash column at the base and the lava-field smoke column at the tower top; both shake the ground),
//   the orb RISING from table slot 2 into the tower top (6 s, zmb_power_rise_loop, electric on both sides:
//   the tower is), the burst (tower fx in the side colour, the canon lightning orb, the side flash via
//   df_cue_side_flash at the top and over the table, thunder, 3 s shake, ONE vanilla vox line via df_vox_once:
//   vox_zmba_sidequest_4emp_mag_0 / vox_maxi_turbine_2light_on_0), the permanent world change (df_fin_world:
//   every lamp of the map in the side colour, Avogadro banished and the denizens silenced on both sides
//   (owner 2026-09-28); then the keepsake line ITEM_KEEPSAKE_RICH / _MAXIS for the card / skull left glowing
//   on slot 1), the rewards (sting, Max Ammo, the Jet Gun that never overheats, one screen message; both sides alike), the
//   globe stat, then the lines. df_complete( "finale" ) last.
//   Wrong power state at the table: df_cue_deny( presser ) + FIN_WRONG_POWER_* (once per 20 s).
//   No mid-quest reward any more (owner 2026-09-28: the Act 2 side rewards and their Max Ammo are gone).
//   Tracker (8d.1): one permanent runner light on the tower per completed act (Act 1 white current, Act 2
//   side sparks, Act 3 both) and the relay runner from the table up
//   the tower (df_fin_tracker_listener, df_fin_relay_runner_loop).
//   Shared helpers this file uses from df_systems (core agent, 2026-09-09): df_cue_deny( player ),
//   df_cue_side_flash( origin, side ), df_fx_burst( fx, origin, seconds ), df_vox_once( alias, origin ).
//   Rewards (both sides, owner 2026-09-28): every perk (df_fin_perk_list + the engine perks of df_fin_perks_extra; down players
//   get them on revive; "!df fire perks" tests it alone), Max Ammo, and a Jet Gun that never overheats.
//   The secret song is not here any more: it plays during the Step 7 wave (owner decision 2026-09-08).
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;
#include scripts\zm\zm_transit\df_lamps;
#include scripts\zm\zm_transit\df_act3_hold; // df_s7_aura_fx (the rising rock wears its Step 7 glow)

// Registers the step; the debug hooks, the Act 2 reward listener, the tracker and the round power snapshot
// listen from round 1 whatever the step state.
df_finale_init()
{
    df_register_step( "finale", ::df_fin_run, undefined );
    level.df_fin_fx = [];
    level.df_fin_track = [];
    level thread df_fin_debug_listener();
    level thread df_fin_round_power_watch();
    level thread df_fin_tracker_listener();
}

// ------------------------------------------------------------------ step ----

// Step body: watch the table until the sequence has run once. A re-entry after the finale already
// started (debug fire, then the step machine reaches the finale) only waits, no second prompt.
df_fin_run()
{
    level endon( "end_game" );
    level endon( "df_skip_finale" );

    level thread df_fin_skip_cleanup();

    if ( is_true( level.df_fin_started ) )
        df_debug_print( "DF: finale step reached but the sequence already ran, no prompt at the table" );
    else
    {
        level thread df_fin_socket_watch();
        df_debug_print( "DF: finale waiting at the table (side " + df_fin_side() + ")" );
    }

    level waittill( "df_finale_done" );
}

df_fin_side()
{
    if ( isdefined( level.df_side ) )
        return level.df_side;

    return "none";
}

// Tower centre on the ground (level.sq_volume is the vanilla tower volume, zm_transit_sq.gsc init).
df_fin_tower_base()
{
    center = ( 7644, -464, -132 );

    if ( isdefined( level.sq_volume ) )
        center = level.sq_volume.origin;

    return df_ground( center );
}

// Richtofen wants the power on, Maxis wants it off (flag "power_on": zm_transit_power.gsc:66). Maxis also
// accepts "the power was OFF when this round started" (audit section 3: the power-station trek must not sit
// at the very end; a team that turned the power on mid-round for a Pack-a-Punch keeps the finale).
df_fin_power_ok()
{
    if ( df_fin_side() == "rich" )
        return flag( "power_on" );

    return !flag( "power_on" ) || is_true( level.df_fin_round_power_off );
}

// Snapshot of the power flag at every round start ("start_of_round", _zm.gsc:3466) plus one at boot.
df_fin_round_power_watch()
{
    level endon( "end_game" );

    level.df_fin_round_power_off = !flag( "power_on" );

    while ( true )
    {
        level waittill( "start_of_round" );
        level.df_fin_round_power_off = !flag( "power_on" );
    }
}

// Players near the table under the tower get the prompt; a hold of 1 s with the right power state starts
// the finale. DF_SOCKET is the table (df_coords, owner 2026-09-08), so the radius and the marker sit on
// it: marker fx fx_zmb_tranzit_light_glow at df_fx_point "socket_glow" over the table, the same glow
// Step 4 uses. The shared STEP AVAILABLE sting (zmb_screecher_portal_arrive, df_steps df_step_available_cue) plays by
// itself when the step opens; no df_step_focus is registered here because this marker IS the table glint and
// outlives the first touch (a wrong-power press must not take it away before the hold).
df_fin_socket_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_finale" );
    level endon( "df_fin_started" );

    c = df_coord( "DF_SOCKET" );
    level.df_fin_marker = undefined; // owner 2026-09-25: no marker glint on the table (owner); the prompt leads

    while ( true )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            near = is_player_valid( player ) && distancesquared( player.origin, c.origin ) < 150 * 150;
            player df_prompt( near, "Hold [{+activate}] to open the frequency" );

            if ( !near || !player usebuttonpressed() )
                continue;

            df_touch( "finale" );

            if ( !df_fin_power_ok() )
            {
                df_fin_wrong_power( player );
                continue;
            }

            player df_prompt( 0, undefined );

            if ( !player df_hold_use( c.origin, 200, 1, "Opening the frequency" ) ) // owner 2026-09-28: shorter (was 2.5 s)
                continue;

            df_fin_clear_prompts();
            level thread df_fin_sequence( 0 );
            return;
        }
    }
}

// Wrong power state: the presser hears the WRONG INPUT cue (df_cue_deny, df_systems: zmb_perks_packa_deny 2D,
// _zm_perks.gsc:795; art audit cue table) at most once per second while he holds the key, and the patron is
// annoyed once per 20 s (the line was the only feedback before the 2026-09-09 audit).
df_fin_wrong_power( player )
{
    if ( isdefined( player ) && ( !isdefined( player.df_fin_deny_time ) || gettime() - player.df_fin_deny_time >= 1000 ) )
    {
        player.df_fin_deny_time = gettime();
        df_cue_deny( player );
    }

    if ( isdefined( level.df_fin_wrong_time ) && gettime() - level.df_fin_wrong_time < 20000 )
        return;

    level.df_fin_wrong_time = gettime();

    if ( df_fin_side() == "rich" )
        df_say( "FIN_WRONG_POWER_RICH" );
    else
        df_say( "FIN_WRONG_POWER_MAXIS" );

    df_debug_print( "DF: finale refused, wrong power state for side " + df_fin_side() );
}

df_fin_clear_prompts()
{
    foreach ( player in getplayers() )
        player df_prompt( 0, undefined );

    df_fx_stop( level.df_fin_marker );
    level.df_fin_marker = undefined;
}

// -------------------------------------------------------------- sequence ----

// Runs once per game (level.df_fin_started / level.df_completed). nostat = 1: everything except the
// globe stat (debug). Order: perks, spectacle, rewards, stat, lines. The rewards and the stat come
// before the ~30 s of dialogue so a crash or a host quit during the lines cannot lose them.
df_fin_sequence( nostat )
{
    level endon( "end_game" );

    if ( is_true( level.df_fin_started ) || is_true( level.df_completed ) )
    {
        df_debug_print( "DF: finale sequence already ran, ignored" );
        return;
    }

    level.df_fin_started = 1;
    level notify( "df_fin_started" );
    df_fin_clear_prompts();

    // a debug start before Step 4 has no side yet: the power state decides, like the socket does
    if ( !isdefined( level.df_side ) )
    {
        if ( flag( "power_on" ) )
            df_set_side( "rich" );
        else
            df_set_side( "maxis" );
    }

    side = level.df_side;
    base = df_fin_tower_base();
    socket = df_coord( "DF_SOCKET" ).origin;
    df_debug_print( "DF: finale start, side " + side + ", nostat " + nostat );

    // rewards that must never be lost come first: every perk, before any visual can fail
    df_fin_perks_give_all( "finale" );

    df_fin_spectacle( side, base, socket, 1 );

    if ( !is_true( level.df_fin_aborted ) )
        df_fin_world( side );

    level.df_completed = 1;
    df_fin_rewards( side, socket );

    if ( is_true( nostat ) )
        df_debug_print( "DF: finale stat write skipped (debug)" );
    else
    {
        df_write_completion_stat( side );
        df_debug_print( "DF: finale stat written for side " + side );
    }

    df_fin_lines( side );
    df_debug_print( "DF: finale done" );
    df_complete( "finale", 1 ); // quiet: the finale has its own spectacle
}

// ------------------------------------------------------------- spectacle ----

// ~15.5 s: 6 s build-up in the side's element (hum over the table, pulses speeding up, shake growing, a
// column at the tower base, Maxis also a smoke column at the top: df_fin_buildup_fx), 6 s of the orb rising
// from table slot 2 into the tower top, then the burst (tower fx in the side colour, lightning orb at the top,
// side burst at the top and over the table, thunder, 3 s shake at 0.5, the side's vox line once). Only
// visuals and sounds: safe to replay via "!df fire finale_fx" (real = 0: a stand-in orb is spawned and
// removed). real = 1 (the finale itself): the Step 6 ball on the table is the one that rises, and
// "df_fin_orb_consumed" is sent (the Step 6 owner hides its ball; until then it crowns the tower). A skip
// during the build-up (df_fin_abort) ends the pulse/shake threads and clears every fx; the rise and the
// burst are skipped.
df_fin_spectacle( side, base, socket, real )
{
    level endon( "end_game" );

    level.df_fin_spectacle_running = 1;
    level.df_fin_aborted = 0;
    level.df_fin_fx = [];
    top = df_fin_tower_top( base );

    // build-up
    df_fin_hum_start( socket, side );
    df_fin_buildup_fx( side, base, top );
    level thread df_fin_pulses( socket, 6, side );
    level thread df_fin_shake( base, 6 );
    df_debug_print( "DF: finale build-up (6 s, " + side + ")" );
    wait 6;

    level notify( "df_fin_buildup_done" );
    df_fin_hum_stop();
    df_fin_fx_clear();

    if ( is_true( level.df_fin_aborted ) )
    {
        level.df_fin_spectacle_running = 0;
        return;
    }

    // the orb leaves the table (audit #8: the finale consumes something)
    orb = df_fin_orb_rise( top, real );

    // burst: our tower visuals for the rest of the game (df_systems df_tower_fx_start: lightning orb
    // at the top + side-coloured runners; vanilla's client version plays once per game, so we own it).
    // The lightning orb (zm_transit_fx.gsc:20) is canon on both sides; the flashes are the side's
    // (df_cue_side_flash, df_systems: the blue spark one-shot for Richtofen, 0.8 s of fx_zmb_tranzit_fire_lrg
    // for Maxis, plus the lava "ignite" crack at the top; art audit #9: the blue spark over the table was a
    // leak on the Maxis path).
    df_tower_fx_start( side );

    if ( side != "maxis" )
        df_fx_once( "sq_common_lightning", top ); // owner 2026-09-25 (fire only on Maxis)
    df_cue_side_flash( top, side );
    df_cue_side_flash( socket + ( 0, 0, 30 ), side );

    if ( side == "maxis" )
        playsoundatposition( "zmb_phdflop_explo", top );                       // fire whoosh ("ignite" is in no TranZit bank)

    playsoundatposition( "zmb_turn_on", base + df_fx_point( "tower_power_snd" ) );               // zm_transit_power.gsc:60
    wait 0.3;

    // thunder: the Avogadro arrival crack (_zm_ai_avogadro.gsc:810), verified loud by the owner; the cue
    // table keeps it on both sides (SPECTACLE row). earthquake( scale, duration, origin, radius ):
    // _zm_powerups.gsc:857 (nuke, 0.5 / 0.75 / 1000)
    if ( side != "maxis" )
        playsoundatposition( "zmb_avogadro_spawn_3d", top ); // owner 2026-09-25 (fire only on Maxis): the Maxis finale keeps the fire whoosh above

    earthquake( 0.5, 3, base, 1500 );
    df_fin_vox( side, base );
    df_debug_print( "DF: finale burst, tower fx on (" + side + ")" );
    wait 3;

    df_fin_orb_after_burst( orb, real );
    level.df_fin_spectacle_running = 0;
}

// Where the tower's lightning orb sits (df_systems df_tower_top, the sq_common_tower_fx struct); fallback
// 700 above the base.
df_fin_tower_top( base )
{
    top = df_tower_top();

    if ( isdefined( top ) )
        return top;

    return base + ( 0, 0, 700 );
}

// The build-up columns (all tracked in level.df_fin_fx, cleared with the build-up). Richtofen: the
// power-station rising current at the base (fx_zmb_tranzit_power_rising, zm_transit_fx.gsc:119). Maxis: the
// ash column at the base (fx_zmb_ash_rising_md, :81, the cue table's Maxis "channelling" column) and the
// lava-field smoke column at the tower top (fx_zmb_tranzit_smk_column_lrg, :101, createfx
// zm_transit_fx.csc:596): the fire side's own far cue while the orb climbs.
df_fin_buildup_fx( side, base, top )
{
    if ( side == "maxis" )
    {
        df_fin_fx_add( df_fx_loop( "fx_zmb_ash_rising_md", base ) );
        df_fin_fx_add( df_fx_loop( "fx_zmb_tranzit_smk_column_lrg", top ) );
        return;
    }

    df_fin_fx_add( df_fx_loop( "fx_zmb_tranzit_power_rising", base ) );
}

// The climax vox, once per game (df_vox_once, df_systems; art audit section 5). Richtofen:
// vox_zmba_sidequest_4emp_mag_0, 2D to the Stuhlinger player (zm_transit_sq.gsc:760, the canon "you did
// it"); Maxis: vox_maxi_turbine_2light_on_0, 3D at the tower base (zm_transit_sq.gsc:514; the alias is
// "2light", not "2lights"). df_vox_once does not block (it threads the serialized helper itself) and plays
// each alias once per game, so a "!df fire finale_fx" replay stays silent after the first.
df_fin_vox( side, base )
{
    if ( side == "maxis" )
    {
        df_vox_once( "vox_maxi_turbine_2light_on_0", base + ( 0, 0, 60 ) );
        return;
    }

    df_vox_once( "vox_zmba_sidequest_4emp_mag_0", undefined );
}

// The orb rises from table slot 2 to `top` in 6 s with the reactor-core rise sound (zm_transit_power.gsc:399-409:
// zmb_power_rise_start, loop zmb_power_rise_loop, zmb_power_rise_stop). real = 1 uses the Step 6 ball resting
// on the table (level.df_s6_orb.ent, df_act3_vacuum df_s6_orb_table_show); otherwise, or when that ball is not
// there (debug before Step 6), a stand-in df_model( "orb" ) is spawned on the slot. Returns the moving entity.
df_fin_orb_rise( top, real )
{
    ent = undefined;
    level.df_fin_orb_temp = 0;

    // owner 2026-09-23: only a rock resting on the table rises; one still on the floor or carried (a Step 7
    // restart cycle cut short) is left to df_fin_orb_after_burst, which hides it through df_fin_orb_consumed
    if ( is_true( real ) && isdefined( level.df_s6_orb ) && isdefined( level.df_s6_orb.ent ) && isdefined( level.df_s6_orb.state ) && level.df_s6_orb.state == "placed" )
        ent = level.df_s6_orb.ent;

    if ( !isdefined( ent ) )
    {
        ent = spawn( "script_model", df_table_slot( 2 ) ); // the slot already is the orb's rest position
        ent setmodel( df_model( "orb" ) );
        ent.angles = df_model_angles( "orb", df_table_yaw() );
        level.df_fin_orb_temp = 1;
    }

    // owner 2026-09-28: the rock keeps the glow it had while protected: the resting glow already rides it (linked);
    // only a stand-in (debug) gets its own, settled 0.15 s before the move so the client draws it
    level.df_fin_rising = 1;
    df_fx_stop( level.df_fin_rise_aura );
    level.df_fin_rise_aura = undefined;

    if ( !isdefined( level.df_fin_rest_aura ) || !isdefined( level.df_fin_rest_on ) || level.df_fin_rest_on != ent )
    {
        level.df_fin_rise_aura = df_fx_loop( df_s7_aura_fx(), ent.origin );

        if ( isdefined( level.df_fin_rise_aura ) )
            level.df_fin_rise_aura linkto( ent );

        wait 0.15;
    }

    ent playsound( "zmb_power_rise_start" );
    ent playloopsound( "zmb_power_rise_loop", 0.75 );
    ent moveto( top, 6, 1, 1 );
    df_debug_print( "DF: finale orb rising to the tower top (6 s, stand-in " + level.df_fin_orb_temp + ")" );
    wait 6;

    if ( isdefined( ent ) )
    {
        ent stoploopsound();
        ent playsound( "zmb_power_rise_stop" );
    }

    return ent;
}

// After the burst: a stand-in is deleted; the real ball is reported consumed (level notify
// "df_fin_orb_consumed", Step 6 owner hides it and its aura) and stays at the top until then.
df_fin_orb_after_burst( ent, real )
{
    df_fx_stop( level.df_fin_rise_aura ); // the rise glow goes with the burst
    level.df_fin_rise_aura = undefined;
    df_fin_rest_aura_off();
    level.df_fin_rising = 0;
    level.df_fin_rise_aura = undefined;

    if ( is_true( level.df_fin_orb_temp ) )
        df_fx_stop( ent );

    // owner 2026-09-23: sent after a stand-in too when real, so a Step 6 rock that was not on the table goes as well
    if ( is_true( real ) )
    {
        level notify( "df_fin_orb_consumed" );
        df_debug_print( "DF: finale orb consumed (df_fin_orb_consumed sent)" );
    }
}

// ----------------------------------------------------------- world change ----

// Permanent world change after the burst (audit #8 / 2.4 "after the finale"), once per game:
//   every lamp of the map in the side colour for the rest of the game (df_lamps df_lamp_colour_all: blue / orange),
//   and on BOTH sides (owner 2026-09-28) Avogadro banished (df_fin_avogadro_banish) and no denizen ever spawns again
//   (level.zombie_ai_limit_screecher = 0, the director's cap, _zm_ai_screecher.gsc:35/82). No lamp power any more.
// Then FIN_WORLD_RICH / FIN_WORLD_MAXIS and the keepsake line (df_fin_keepsake). "!df fire finale_world"
// runs it alone.
df_fin_world( side )
{
    if ( is_true( level.df_fin_world_done ) )
        return;

    level.df_fin_world_done = 1;
    df_lamp_colour_all( side );

    level thread df_fin_avogadro_banish();
    level.zombie_ai_limit_screecher = 0;
    level thread df_fin_denizen_keeper();

    if ( side == "rich" )
        df_say( "FIN_WORLD_RICH" );
    else
        df_say( "FIN_WORLD_MAXIS" );

    df_fin_keepsake( side );
    df_debug_print( "DF: finale world change done (" + side + ")" );
}

// The finale residue on the table (dialogue audit v2 row 11 / section 5: ITEM_KEEPSAKE_RICH / _MAXIS need a
// caller): the Act 2 trophy stays on slot 1 for good, the key card glowing for Richtofen, the skull for
// Maxis, and the patron says so once. Only when that act actually left something there (df_is_done r1 / m1;
// a debug finale from round 1 has an empty slot and says nothing).
df_fin_keepsake( side )
{
    if ( is_true( level.df_fin_keepsake_done ) )
        return;

    level.df_fin_keepsake_done = 1;

    if ( side == "rich" )
    {
        if ( !df_is_done( "r1" ) )
            return;

        df_say( "ITEM_KEEPSAKE_RICH" );
    }
    else
    {
        if ( !df_is_done( "m1" ) )
            return;

        df_say( "ITEM_KEEPSAKE_MAXIS" );
    }

    df_debug_print( "DF: finale keepsake on slot 1 (" + side + ")" );
}

// M1 saves / restores the denizen cap around its cold room (df_act2_maxis); a late restore or any other
// writer must not bring the denizens back: re-assert 0 every 2 s.
df_fin_denizen_keeper()
{
    level endon( "end_game" );

    while ( true )
    {
        if ( isdefined( level.zombie_ai_limit_screecher ) && level.zombie_ai_limit_screecher != 0 )
        {
            level.zombie_ai_limit_screecher = 0;
            df_debug_print( "DF: denizen cap reset to 0 (finale)" );
        }

        wait 2;
    }
}

// Avogadro never returns. Vanilla rewrites return_round on EVERY cloud entry (_zm_ai_avogadro.gsc:693-697:
// round + 1, or + 2..5) and cloud_update brings him down once round_number >= return_round (:781), so this is
// a keeper, not a one-shot: in the cloud, return_round and level.next_avogadro_round stay 9999. Out in the
// world he is sent up first through his own exit (avogadro_exit( "exit_idle" ), :634: state "exiting", exit
// anim, ghost, cloud), the same call the vanilla defeat path makes from outside his state loop (:1330). Asleep
// in the power chamber he is left alone (he only wakes on the vanilla release, a Maxis-side thing).
df_fin_avogadro_banish()
{
    level endon( "end_game" );

    if ( is_true( level.df_fin_avogadro_banished ) )
        return;

    level.df_fin_avogadro_banished = 1;
    sent = 0;

    while ( true )
    {
        a = level.avogadro;

        if ( isdefined( a ) && isdefined( a.state ) )
        {
            if ( a.state == "cloud" )
            {
                if ( !isdefined( a.return_round ) || a.return_round != 9999 )
                {
                    a.return_round = 9999;
                    level.next_avogadro_round = 9999;
                    df_debug_print( "DF: avogadro banished to the cloud (return_round 9999)" );
                }
            }
            else if ( !sent && ( a.state == "idle" || a.state == "chasing" || a.state == "chasing_bus" || a.state == "stay_attached" ) )
            {
                sent = 1;
                a thread maps\mp\zombies\_zm_ai_avogadro::avogadro_exit( "exit_idle" );
                df_debug_print( "DF: avogadro sent up from state " + a.state );
            }
        }

        wait 0.5;
    }
}

// Pulses over the table every 0.5 s, speeding up to 0.15 s. Richtofen: the blue spark one-shot
// (zm_transit_fx.gsc:123) plus the electric trap arc sound (_zm_traps.gsc:438). Maxis: a 0.4 s burst of the
// large brazier fire (fx_zmb_tranzit_fire_lrg, :100, the same burst S6 / S7 use on the fire side) plus the
// lava "ignite" one-shot (zm_transit_lava.gsc:275). Ends with the build-up or on abort.
df_fin_pulses( socket, seconds, side )
{
    level endon( "end_game" );
    level endon( "df_fin_buildup_done" );
    level endon( "df_fin_abort" );

    interval = 0.5;
    stop = gettime() + seconds * 1000;

    while ( gettime() < stop )
    {
        if ( side == "maxis" )
        {
            // owner 2026-09-23: each burst lasts at most the current interval, so bursts never stack as it shrinks
            fx_len = 0.4;
            snd_len = 0.6;

            if ( fx_len > interval )
                fx_len = interval;

            if ( snd_len > interval )
                snd_len = interval;

            df_fx_burst( "fx_zmb_tranzit_fire_lrg", socket + df_fx_point( "socket_glow" ), fx_len );   // df_systems, self-cleaning
            df_snd_loop_burst( "zmb_fire_loop", socket, snd_len ); // owner pick 2026-09-11: puff = fire loop burst
        }
        else
        {
            df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", socket + df_fx_point( "socket_glow" ) );
            playsoundatposition( "zmb_zombie_arc", socket ); // zmb_elec_arc is in no TranZit bank (silent)
        }

        wait( interval );
        interval = interval * 0.88;

        if ( interval < 0.15 )
            interval = 0.15;
    }
}

// Ground shake for players near the tower, growing from 0.1 to 0.4 over the build-up. Vanilla scales
// stay at or below 0.5 (_zm_powerups.gsc:857, zm_buried_classic.gsc:1235), so do ours.
df_fin_shake( base, seconds )
{
    level endon( "end_game" );
    level endon( "df_fin_buildup_done" );
    level endon( "df_fin_abort" );

    start = gettime();
    total = seconds * 1000;

    while ( gettime() - start < total )
    {
        frac = ( gettime() - start ) / total;
        earthquake( 0.1 + 0.3 * frac, 0.6, base, 1500 );
        wait 0.5;
    }
}

// Rising hum over the table on a script_origin. Richtofen: the electric trap start + loop
// (_zm_traps.gsc:406-408). Maxis: the fire trap whoosh (zmb_firetrap_start, _zm_traps.gsc:414, the M2 brazier
// lighting sound) + the burning-zombie crackle loop (zmb_fire_loop, zm_transit_lava.gsc:224, the lit brazier
// hum): art audit #9, the electric hum was a leak on the fire side.
df_fin_hum_start( socket, side )
{
    df_fin_hum_stop();
    level.df_fin_hum = spawn( "script_origin", socket + ( 0, 0, 30 ) );

    if ( side == "maxis" )
    {
        level.df_fin_hum playsound( "zmb_phdflop_explo" ); // zmb_firetrap_start: silent in TranZit
        level.df_fin_hum playloopsound( "zmb_fire_loop" );
        return;
    }

    // zmb_elec_start / zmb_elec_loop are in no TranZit bank: the Avogadro warp-in and his electric loop instead
    level.df_fin_hum playsound( "zmb_avogadro_warp_in" );
    level.df_fin_hum playloopsound( "zmb_avogadro_loop" );
}

// stoploopsound, 0.05 s, delete: the trap's own shutdown order (_zm_traps.gsc:425-428).
df_fin_hum_stop()
{
    if ( !isdefined( level.df_fin_hum ) )
        return;

    ent = level.df_fin_hum;
    level.df_fin_hum = undefined;
    ent stoploopsound();
    wait 0.05;

    if ( isdefined( ent ) )
        ent delete();
}

// Every looping fx ent of the finale is tracked here so one call removes them all.
df_fin_fx_add( ent )
{
    if ( isdefined( ent ) )
        level.df_fin_fx[level.df_fin_fx.size] = ent;
}

df_fin_fx_clear()
{
    foreach ( ent in level.df_fin_fx )
        df_fx_stop( ent );

    level.df_fin_fx = [];
}

// ----------------------------------------------------------------- perks ----
// Owner decision 2026-09-08: the reward is every perk of the map. Root cause of "no perks in game":
// level._custom_perks is only filled by _zm_perks::register_perk_* (_zm_perks.gsc:3640-3727), which
// TranZit never calls (only MOTD's Electric Cherry does), so the old loop over its keys gave nothing.

// The perk list: the six TranZit machines (zm_transit.gsc:288-293 level.zombiemode_using_*_perk ->
// _zm_perks.gsc turn_*_on, notifies specialty_fastreload_power_on :1007, quickrevive :1119, armorvest
// :1233, rof :1271, longersprint :1309, scavenger :1387) plus any perk a mod registered in
// level._custom_perks. Solo: vanilla removes the Tombstone machine (zm_transit_utility.gsc:204-211
// solo_tombstone_removal, getnumexpectedplayers() <= 1), so specialty_scavenger is skipped there too.
df_fin_perk_list()
{
    perks = [];
    perks[perks.size] = "specialty_armorvest";
    perks[perks.size] = "specialty_quickrevive";
    perks[perks.size] = "specialty_fastreload";
    perks[perks.size] = "specialty_rof";
    perks[perks.size] = "specialty_longersprint";

    if ( getnumexpectedplayers() > 1 )
        perks[perks.size] = "specialty_scavenger";
    else
        df_debug_print( "DF: finale perks: solo game, Tombstone skipped (machine removed by vanilla)" );

    if ( isdefined( level._custom_perks ) )
    {
        foreach ( perk in getarraykeys( level._custom_perks ) )
        {
            if ( !isinarray( perks, perk ) )
                perks[perks.size] = perk;
        }
    }

    return perks;
}

// Every player, every perk; `reason` is "finale" or "debug" (console). The purchase limit is raised
// first and remembered in level.df_fin_perk_limit (df_fin_perk_limit_raise re-asserts it on every give,
// so it stays raised). _zm_utility::get_player_perk_purchase_limit() (:5059) returns
// level.perk_purchase_limit (4, _zm_perks.gsc:23) unless a map installs a func; TranZit does not.
df_fin_perks_give_all( reason )
{
    perks = df_fin_perk_list();
    df_fin_perk_limit_raise( perks.size );
    df_debug_print( "DF: finale perks (" + reason + "): " + perks.size + " perks, limit " + level.perk_purchase_limit );

    if ( isdefined( level.get_player_perk_purchase_limit ) )
        df_debug_print( "DF: warning, level.get_player_perk_purchase_limit is installed, the limit may be ignored" );

    foreach ( player in getplayers() )
        player thread df_fin_perks_player( perks, reason );
}

df_fin_perk_limit_raise( count )
{
    if ( !isdefined( level.df_fin_perk_limit ) || level.df_fin_perk_limit < count )
        level.df_fin_perk_limit = count;

    if ( level.df_fin_perk_limit < 4 )
        level.df_fin_perk_limit = 4;

    if ( !isdefined( level.perk_purchase_limit ) || level.perk_purchase_limit < level.df_fin_perk_limit )
        level.perk_purchase_limit = level.df_fin_perk_limit;
}

// self = player (threaded). A down player gets nothing now and everything on revive (or on the next
// spawn after a bleed-out). Otherwise: one pass, 0.5 s, a second pass for whatever hasperk still
// denies, then one summary line on screen and in the console.
df_fin_perks_player( perks, reason )
{
    self endon( "disconnect" );
    level endon( "end_game" );

    if ( !self df_fin_perks_can_take() )
    {
        df_debug_print( "DF: finale perks: " + self.name + " is down, perks on revive" );
        self thread df_fin_perks_on_revive( perks, reason );
        return;
    }

    missing = self df_fin_perks_pass( perks );

    if ( missing.size > 0 )
    {
        wait 0.5;
        missing = self df_fin_perks_pass( perks );
    }

    // went down during the passes: finish on revive
    if ( missing.size > 0 && !self df_fin_perks_can_take() )
    {
        df_debug_print( "DF: finale perks: " + self.name + " went down mid-give, rest on revive" );
        self thread df_fin_perks_on_revive( perks, reason );
        return;
    }

    text = "none";

    if ( missing.size > 0 )
    {
        text = "";

        foreach ( perk in missing )
            text += perk + " ";
    }

    self df_out( "finale perks: " + ( perks.size - missing.size ) + "/" + perks.size + " given, missing: " + text );
    self df_fin_perks_extra();
    self thread df_fin_perks_keep( perks );
}

// owner 2026-09-25: "ALL perks available in the BO2 engine". Three more perks work on TranZit although the map
// has no machine for them, because their effect lives in the engine and the core scripts: Deadshot (engine aim),
// Mule Kick (_zm_weapons weapon limit reads hasperk) and PhD Flopper (_zm.gsc damage override reads
// specialty_flakjacket). They are set with setperk only: give_perk would call set_perk_clientfield, whose HUD
// clientfields TranZit never registers (_zm_perks.gsc:3093, only for the map's own machines), so they show no
// perk icon. Electric Cherry, Vulture Aid and Who's Who cannot be given: their code and assets are not in TranZit.
df_fin_perks_extra()
{
    extras = [];
    extras[extras.size] = "specialty_deadshot";
    extras[extras.size] = "specialty_additionalprimaryweapon";
    extras[extras.size] = "specialty_flakjacket";

    foreach ( perk in extras )
    {
        if ( self hasperk( perk ) )
            continue;

        self setperk( perk );
        df_debug_print( "DF: finale extra perk " + perk + " set on " + self.name + " (no HUD icon on TranZit)" );
    }
}

// owner 2026-09-25: the gift outlives the power. Vanilla pauses every perk when its machine loses power
// (_zm_power.gsc:633 perk_power_off -> _zm_perks::perk_pause, then the "<machine>_off" notify); a player who got
// the finale perks gets the paused ones straight back (the same restore as _zm_perks::perk_unpause :2673, for
// this player only). Before the finale nothing changes: perks go down with the power as in vanilla.
// self = player. One watcher per player.
df_fin_perks_keep( perks )
{
    self endon( "disconnect" );
    level endon( "end_game" );

    if ( is_true( self.df_fin_perks_kept ) )
        return;

    self.df_fin_perks_kept = 1;

    while ( true )
    {
        level waittill_any_return( "juggernog_off", "revive_off", "sleight_off", "doubletap_off", "marathon_off", "tombstone_off" ); // waittill_any takes 5 at most
        wait 0.05;

        if ( !isdefined( self.disabled_perks ) )
            continue;

        foreach ( perk in perks )
        {
            if ( !is_true( self.disabled_perks[perk] ) )
                continue;

            self.disabled_perks[perk] = 0;
            self maps\mp\zombies\_zm_perks::set_perk_clientfield( perk, 1 );
            self setperk( perk );

            if ( issubstr( perk, "specialty_scavenger" ) )
                self.hasperkspecialtytombstone = 1;

            self maps\mp\zombies\_zm_perks::perk_set_max_health_if_jugg( perk, 0, 0 );
            df_debug_print( "DF: finale perk " + perk + " kept on " + self.name + " (power off)" );
        }
    }
}

// self = player. Alive and not in last stand (_zm_laststand::player_is_in_laststand).
df_fin_perks_can_take()
{
    return isalive( self ) && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand();
}

// self = player. One give pass: give_perk( perk, 0 ) (_zm_perks.gsc:1982; setperk, num_perks++, the
// perk HUD via set_perk_clientfield :2216, perk_think watcher) for every perk hasperk denies, 0.1 s
// apart. Returns the perks hasperk still denies after the pass. Stops early if the player goes down.
df_fin_perks_pass( perks )
{
    missing = [];

    foreach ( perk in perks )
    {
        if ( !self df_fin_perks_can_take() )
        {
            missing[missing.size] = perk;
            continue;
        }

        if ( self hasperk( perk ) )
            continue;

        df_fin_perk_limit_raise( perks.size );
        self maps\mp\zombies\_zm_perks::give_perk( perk, 0 );
        wait 0.1;

        if ( self hasperk( perk ) )
            df_debug_print( "DF: finale perk " + perk + " given to " + self.name );
        else
        {
            df_debug_print( "DF: finale perk " + perk + " NOT held by " + self.name + " after give_perk" );
            missing[missing.size] = perk;
        }
    }

    return missing;
}

// self = player. Waits for the revive ("player_revived", _zm_laststand.gsc:996/1014/1021) or the next
// spawn after a bleed-out ("spawned_player", _zm.gsc:2601), then gives the perks. One watcher per player.
df_fin_perks_on_revive( perks, reason )
{
    self endon( "disconnect" );
    level endon( "end_game" );

    if ( is_true( self.df_fin_perk_wait ) )
        return;

    self.df_fin_perk_wait = 1;
    self waittill_any( "player_revived", "spawned_player" );
    wait 0.5;
    self.df_fin_perk_wait = 0;
    df_debug_print( "DF: finale perks: " + self.name + " is back, giving now" );
    self thread df_fin_perks_player( perks, reason + "/revive" );
}

// --------------------------------------------------------------- rewards ----

// Everything after the spectacle: the perk sting, Max Ammo, the side reward (unless Act 2 already gave it),
// one screen message.
df_fin_rewards( side, socket )
{
    df_fin_reward_sting( socket );
    df_fin_reward_powerup( socket );

    // rc5: the Jet Gun that never overheats is a FINALE reward only (at Act 2 it broke the Step 6 overheat draw);
    // owner 2026-09-28: both sides get it
    df_fin_reward_jetgun();

    df_fin_reward_message( side );
}

// The Juggernog machine sting, once. Alias mus_perks_jugganog_sting (_zm_perks.gsc:2961, script_label of
// the machine trigger), played by _zm_audio::play_jingle_or_stinger (_zm_audio.gsc:964-985) on the
// machine only while level.music_override == 0: we keep that guard.
df_fin_reward_sting( socket )
{
    if ( is_true( level.music_override ) )
    {
        df_debug_print( "DF: finale sting skipped, music_override set" );
        return;
    }

    playsoundatposition( "zmb_whoosh", socket + df_fx_point( "socket_glow" ) ); // owner pick 2026-09-11: the sting = the box whoosh
    df_debug_print( "DF: finale sting played" );
}

// "free_perk" is not in TranZit's include_powerups() list (zm_transit.gsc:1602-1617), so its powerup
// struct does not exist; "full_ammo" is. Dropped a little in front of the socket, towards the tower
// centre. specific_powerup_drop: _zm_powerups.gsc:545.
df_fin_reward_powerup( socket )
{
    center = df_fin_tower_base();
    dir = center - socket;
    dir = ( dir[0], dir[1], 0 );

    if ( length( dir ) > 1 )
        dir = vectornormalize( dir ) * 40;

    spot = df_ground( socket + dir + ( 0, 0, 20 ) );
    level maps\mp\zombies\_zm_powerups::specific_powerup_drop( "full_ammo", spot );
    df_debug_print( "DF: finale power-up dropped" );
}

// One screen line per player listing what was won (df_out: screen + console).
df_fin_reward_message( side )
{
    text = "Dead Frequency complete: every perk, Max Ammo, the Jet Gun never overheats, Avogadro and the denizens are gone";

    foreach ( player in getplayers() )
        player df_out( text );
}

// The finale's Jet Gun reward (both sides, owner 2026-09-28): the Jet Gun never overheats (nothing needs its heat after Step 7).
df_fin_reward_jetgun()
{
    level thread df_fin_jetgun_cool_loop();
    df_debug_print( "DF: finale reward on (jet gun cool)" );
}

// never_overheat() in _zm_weap_jetgun.gsc:143-158 is dev-only (whole body inside /# #/), but the builtin
// it uses is called in retail code (watch_overheat :166, _zm_weapons.gsc:2706), so we run the same loop
// ourselves. The mirrored player fields (_zm_weap_jetgun.gsc:174-175) keep the vanilla watcher, and the
// noee jet gun rework (.jgx_heat), in agreement.
df_fin_jetgun_cool_loop()
{
    level endon( "end_game" );

    if ( is_true( level.df_fin_jetgun_loop ) )
        return;

    level.df_fin_jetgun_loop = 1;

    while ( true )
    {
        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) )
                continue;

            w = player getcurrentweapon();

            if ( w != "jetgun_zm" )
                continue;

            player setweaponoverheating( 0, 0 );
            player.jetgun_overheating = 0;
            player.jetgun_heatval = 0;

            if ( isdefined( player.jgx_heat ) )
                player.jgx_heat = 0;
        }

        wait 0.05;
    }
}

// ---------------------------------------------------------------- tracker ----
// Audit 8d.1: a visible progression tracker. Listens to df_steps' "df_step_done", key (df_complete, also
// during a "!df goto" fabrication, so a goto lands with the right tracker):
//   step4 (Act 1 done)  -> permanent white runner on the tower
//   r2 / m2 (Act 2)     -> permanent side-coloured runner
//   step7 (Act 3)       -> a second pair of runners (white + side)
//   step4 also          -> the relay runner: a side-coloured runner leaves the plugged relay every few seconds and
//                          climbs the nearest tower chain to the top (owner 2026-09-28: it replaces the step glows)
// Runners are our own copy of df_systems' df_tower_fx_runner: the shared one dies with every
// df_tower_fx_stop (each act's 12 s cue calls it), these survive until end_game. The side of a runner is
// re-read at every launch so the colour follows the locked side.
df_fin_tracker_listener()
{
    level endon( "end_game" );

    foreach ( key in level.df_step_order )
    {
        if ( df_is_done( key ) )
            df_fin_tracker_apply( key );
    }

    while ( true )
    {
        level waittill( "df_step_done", key );
        df_fin_tracker_apply( key );
    }
}

// Idempotent per key.
df_fin_tracker_apply( key )
{
    if ( !isdefined( key ) || is_true( level.df_fin_track[key] ) )
        return;

    level.df_fin_track[key] = 1;

    // owner 2026-09-28: from the charged rock on the table (Step 6 done) to the finale burst, the rock never loses its glow
    if ( key == "step6" || key == "step7" )
        level thread df_fin_rest_aura_watch();

    if ( key == "step4" )
    {
        level thread df_fin_runner_loop( "white", 5 );
        level thread df_fin_relay_runner_loop( 4 );
    }
    else if ( key == "r2" || key == "m2" )
        level thread df_fin_runner_loop( "side", 5 );
    else if ( key == "step7" )
    {
        level thread df_fin_runner_loop( "white", 4 );
        level thread df_fin_runner_loop( "side", 4 );
        level thread df_fin_orb_beacon_loop( 3 );
        level thread df_fin_rest_aura_watch();
    }
    else
        return;

    df_debug_print( "DF: tracker: " + key + " marked" );
}

// owner 2026-09-28: "instead of the relay glows, a light from the relay to the top of the tower, red / blue for
// Maxis / Richtofen": from Step 4 on, every `gap` s a side-coloured runner (df_fin_runner_fx "side") rises off the
// plugged relay, flies to the foot of the tower chain nearest to it and climbs that chain to the top.
df_fin_relay_runner_loop( gap )
{
    level endon( "end_game" );

    structs = getstructarray( "sq_common_pole_fx", "targetname" );

    if ( !isdefined( structs ) || structs.size == 0 )
    {
        df_debug_print( "DF: tracker: sq_common_pole_fx structs not found, no relay runner" );
        return;
    }

    while ( !isdefined( level.df_socket_relay ) )
        wait 1;

    start = getclosest( level.df_socket_relay.origin, structs );
    df_debug_print( "DF: tracker: relay runner up the tower every " + gap + " s" );

    while ( true )
    {
        if ( isdefined( level.df_socket_relay ) )
            level thread df_fin_relay_runner( df_fin_runner_fx( "side" ), level.df_socket_relay.origin + ( 0, 0, 40 ), start );

        wait( gap + randomfloat( 1 ) );
    }
}

// owner 2026-09-28: while the frequency waits to be opened, the rock on the table (slot 2) shoots a side-coloured light
// straight up to the top of the tower every `gap` s: one runner at a time (df_fin_orb_beacon), it ends with the
// finale's start.
df_fin_orb_beacon_loop( gap )
{
    level endon( "end_game" );
    level endon( "df_fin_started" );

    if ( is_true( level.df_fin_started ) || is_true( level.df_completed ) )
        return;

    top = df_tower_top();

    if ( !isdefined( top ) )
        top = ( 7644, -464, -132 ) + ( 0, 0, 900 );

    df_debug_print( "DF: finale beacon: the rock lights the tower top every " + gap + " s until the frequency opens" );

    while ( true )
    {
        level thread df_fin_orb_beacon( df_fin_runner_fx( "side" ), df_table_slot( 2 ) + ( 0, 0, 6 ), top );
        wait( gap );
    }
}

// owner 2026-09-28: "the glow should never leave the rock": from Step 6 done to the finale burst the rock wears the
// glow it has while protected (df_s7_aura_fx). Step 7 carries its own (the wave rock, df_s7_orb_aura_on); outside a
// wave this watcher keeps one glow linked to the Step 6 rock resting on the table, and it stays linked while the
// finale lifts that rock (level.df_fin_rising) until the burst removes it. One watcher per game, 0.25 s ticks.
df_fin_rest_aura_watch()
{
    level endon( "end_game" );

    if ( is_true( level.df_fin_rest_watching ) )
        return;

    level.df_fin_rest_watching = 1;

    while ( !is_true( level.df_completed ) )
    {
        rock = undefined;

        if ( isdefined( level.df_s6_orb ) && isdefined( level.df_s6_orb.ent ) && isdefined( level.df_s6_orb.state ) && level.df_s6_orb.state == "placed" )
            rock = level.df_s6_orb.ent;

        if ( is_true( level.df_fin_rising ) )
        {
            // the rise keeps the glow it has
        }
        else if ( isdefined( rock ) && !is_true( level.df_s7_active ) )
        {
            if ( !isdefined( level.df_fin_rest_aura ) || !isdefined( level.df_fin_rest_on ) || level.df_fin_rest_on != rock )
                df_fin_rest_aura_on( rock );
        }
        else if ( isdefined( level.df_fin_rest_aura ) )
            df_fin_rest_aura_off();

        wait 0.25;
    }

    df_fin_rest_aura_off();
}

// One glow on `rock`, linked (spawned while the rock rests, so the client has drawn it before any move).
df_fin_rest_aura_on( rock )
{
    df_fin_rest_aura_off();
    level.df_fin_rest_aura = df_fx_loop( df_s7_aura_fx(), rock.origin );
    level.df_fin_rest_on = rock;

    if ( isdefined( level.df_fin_rest_aura ) )
        level.df_fin_rest_aura linkto( rock );
}

df_fin_rest_aura_off()
{
    df_fx_stop( level.df_fin_rest_aura );
    level.df_fin_rest_aura = undefined;
    level.df_fin_rest_on = undefined;
}

// One light: settles 0.15 s on the rock, rises to the tower top in 1.2 s, then goes. Threaded, no endon: a flight
// always ends and deletes its light, even when the finale starts mid-flight.
df_fin_orb_beacon( fx, from, top )
{
    ent = df_fx_loop( fx, from );

    if ( !isdefined( ent ) )
        return;

    wait 0.15;
    ent moveto( top, 1.2 );
    wait 1.2;
    df_fx_stop( ent );
}

// One runner: settles 0.15 s at the relay (a trail moved on its spawn frame is not always seen), flies to the chain's
// foot (700 units/s, 0.4-1.5 s, like df_soul_fly), then climbs the chain (df_fin_runner's 1.4 s per segment).
df_fin_relay_runner( fx, from, struct )
{
    level endon( "end_game" );

    ent = df_fx_loop( fx, from );

    if ( !isdefined( ent ) )
        return;

    wait 0.15;
    t = distance( from, struct.origin ) / 700;

    if ( t < 0.4 )
        t = 0.4;

    if ( t > 1.5 )
        t = 1.5;

    ent moveto( struct.origin, t );
    ent waittill( "movedone" );

    while ( isdefined( struct.target ) )
    {
        next = getstruct( struct.target, "targetname" );

        if ( !isdefined( next ) )
            break;

        struct = next;
        ent moveto( struct.origin, 1.4 );
        ent waittill( "movedone" );
    }

    df_fx_stop( ent );
}

// The runner fx of a colour: "white" = the power-station rising current (fx_zmb_tranzit_power_rising,
// zm_transit_fx.gsc:119, white-blue light column: the Act 1 pre-fork residue, the cue table's "white
// runner"), "side" = the side's soul trail (richtofen_sparks blue / maxis_sparks orange, zm_transit_fx.gsc:18-19,
// the same family df_systems' tower runners and the node -> tower trails use), read at launch time.
df_fin_runner_fx( colour )
{
    if ( colour != "side" )
        return "fx_zmb_tranzit_power_rising";

    if ( df_fin_side() == "maxis" )
        return "maxis_sparks";

    return "richtofen_sparks";
}

// For the rest of the game: every `gap` s one runner climbs one of the tower's sq_common_pole_fx chains
// (the structs df_systems df_tower_fx_runners uses), picked at random.
df_fin_runner_loop( colour, gap )
{
    level endon( "end_game" );

    structs = getstructarray( "sq_common_pole_fx", "targetname" );

    if ( !isdefined( structs ) || structs.size == 0 )
    {
        df_debug_print( "DF: tracker: sq_common_pole_fx structs not found" );
        return;
    }

    while ( true )
    {
        level thread df_fin_runner( df_fin_runner_fx( colour ), structs[randomint( structs.size )] );
        wait( gap + randomfloat( 1 ) );
    }
}

// One climb along a struct chain (1.4 s per segment, like df_tower_fx_runner), then the fx ent goes.
df_fin_runner( fx, struct )
{
    level endon( "end_game" );

    ent = df_fx_loop( fx, struct.origin );

    if ( !isdefined( ent ) )
        return;

    while ( isdefined( struct.target ) )
    {
        next = getstruct( struct.target, "targetname" );

        if ( !isdefined( next ) )
            break;

        struct = next;
        ent moveto( struct.origin, 1.4 );
        ent waittill( "movedone" );
    }

    df_fx_stop( ent );
}

// ----------------------------------------------------------------- lines ----

// Three lines after the spectacle. df_say shows each line 6 s and spaces its queue by 6.5 s
// (df_systems df_say_pump), so 6.5 s is the tightest spacing the shared HUD allows; FIN_*_3 carries
// the other patron's reply as a 4th line from the same queue.
df_fin_lines( side )
{
    prefix = "FIN_MAXIS_";

    if ( side == "rich" )
        prefix = "FIN_RICH_";

    df_say( prefix + "1" );
    wait 6.5;
    df_say( prefix + "2" );
    wait 6.5;
    df_say( prefix + "3" );
}

// ----------------------------------------------------------------- debug ----

// "!df fire finale" runs the whole finale with the stat write, "!df fire finale_nostat" without it,
// "!df fire finale_fx" replays only the ~15 s spectacle with a stand-in orb (no rewards, no stat, repeatable),
// "!df fire finale_world" runs the permanent world change alone (lamps, Avogadro / denizens, once),
// "!df fire perks" gives every perk to every player now, with the summary line (no finale).
df_fin_debug_listener()
{
    level endon( "end_game" );

    level thread df_fin_debug_wait( "df_debug_finale", 0 );
    level thread df_fin_debug_wait( "df_debug_finale_nostat", 1 );
    level thread df_fin_debug_fx_wait();
    level thread df_fin_debug_perks_wait();
    level thread df_fin_debug_world_wait();
}

// "!df fire finale_world": the world change for the locked side (power state if none: on = Richtofen).
df_fin_debug_world_wait()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_finale_world" );
        df_fin_world( df_fin_debug_side() );
    }
}

// The locked side, else the power state decides (on = Richtofen), like the socket does.
df_fin_debug_side()
{
    side = df_fin_side();

    if ( side != "none" )
        return side;

    if ( flag( "power_on" ) )
        return "rich";

    return "maxis";
}

// "!df fire perks": the perk reward alone, repeatable (perks already held are skipped by hasperk).
df_fin_debug_perks_wait()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_perks" );
        df_fin_perks_give_all( "debug" );
    }
}

df_fin_debug_wait( name, nostat )
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( name );

        if ( is_true( level.df_fin_started ) || is_true( level.df_completed ) )
        {
            df_debug_print( "DF: finale already started, ignoring " + name );
            continue;
        }

        df_debug_print( "DF: debug " + name );
        level thread df_fin_sequence( nostat );
    }
}

// Spectacle only, in the current side colour (power state if no side is locked yet).
df_fin_debug_fx_wait()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_finale_fx" );

        if ( is_true( level.df_fin_spectacle_running ) )
        {
            df_debug_print( "DF: finale spectacle already running, ignoring df_debug_finale_fx" );
            continue;
        }

        side = df_fin_debug_side();
        df_debug_print( "DF: debug finale spectacle, side " + side );
        level thread df_fin_spectacle( side, df_fin_tower_base(), df_coord( "DF_SOCKET" ).origin, 0 );
    }
}

// --------------------------------------------------------------- cleanup ----

// "df_skip_finale": the prompt at the table, marker, hum and every finale fx go; a running build-up is aborted.
df_fin_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_finale_done" );
    level waittill( "df_skip_finale" );

    level.df_fin_aborted = 1;
    level notify( "df_fin_abort" );
    df_fin_clear_prompts();
    df_fin_hum_stop();
    df_fin_fx_clear();
    df_fin_rest_aura_off();
    df_debug_print( "DF: finale skipped, the prompt at the table and every fx removed" );
}
