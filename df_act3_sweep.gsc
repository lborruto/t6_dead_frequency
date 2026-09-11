// Dead Frequency - Act 3 "Convergence", Step 5 "Frequency Sweep" (shared; the ANCHOR verb differs per side,
//   design audit 2026-09-08 #2 / #4).
//   The game's ONE lamp set (df_lamps.gsc: the lamps R2 filled with souls on the Richtofen side, picked here
//   on the Maxis side) must be TUNED (hold use at the lamp, 5 s: a short channelling) and ANCHORED.
//   The anchor FORK (owner 2026-09-09; canon: vanilla Maxis's third node IS two turbines at denizen lamps,
//   Richtofen "controls the undead"):
//   - Maxis (grid OFF): a running TURBINE within 200 of the lamp base (level.local_power[]: one struct per
//     powering turbine, .origin / .radius, _zm_power.gsc:248 add_local_power / :297 end_local_power). The
//     turbine gives the lamp the power the dark grid does not; it is chewed by zombies like any equipment.
//   - Richtofen (grid ON): a DENIZEN burrow at the lamp. Vanilla digs a portal when a denizen riding a
//     player's head reaches a lamp whose server flag power_on is set (zm_transit_ai_screecher.gsc:23-59);
//     main power already sets it (_zm_power.gsc:365) and df_lamp_power_silent keeps it set for the step
//     (the flag only, no clientfield) so a power hiccup cannot block the burrow.
//   The FIRST ANCHOR starts the countdown: Richtofen reads the "sweep_time_rich" row (480/360/300/270, the
//   denizen latches are RNG; steps audit v2 #3) when df_steps has it, else "sweep_time"; Maxis reads
//   "sweep_time" (360/300/270/240). `need` anchors before it ends complete the step.
//   Expiry FAILS FORWARD (steps audit v2 #2, 2026-09-09): the anchored lamps STAY anchored (beam and look
//   kept); only the lamps that were NOT anchored pay souls (8/10/12/14, kills within 400 of the base) and
//   re-tune; the clock restarts at the next anchor, with only the missing anchors left to win.
//   Lamp looks come only from df_lamp_state_set (df_lamps.gsc): "filled" = tunable (steady light + slow
//   burst + hum), "tuning" while the hold fills (quick bursts + the rising power loop), "waiting" (tuned,
//   15 s for the anchor: blinking light + tick-tock loop, a top-centre 15 s timer when df_sys_hud_timers),
//   "anchored" (steady light + tower beam + slow double burst), "souls" during the penalty.
//   Cue grammar (art audit 2026-09-09, one alias per meaning, helpers in df_systems): the step opening
//   registers its focus (df_step_focus: the first set lamp) and every still-untuned set lamp carries the
//   vanilla "take me" glint (fx_zmb_tranzit_key_glint, zm_transit_fx.gsc:105) at the bulb until its first
//   hold; a tune completing = two PROGRESS clinks (df_cue_tick x2, was the PaP-ready ding); an anchor =
//   SUB-GOAL chime + side flash at the bulb + the canon node -> tower runner (df_cue_subgoal does all
//   three); "Signal lost" = FAIL thump + side loss fx at the lamp (df_cue_fail, was silent to all but the
//   tuner); expiry = the EMP thump to everyone + D5_FAIL. No zmb_spawn_powerup here any more (it is the shared
//   STEP AVAILABLE alias) and no navcard / powerup_grabbed of our own (STEP DONE comes from df_complete).
//   Voice: vox_zmba_sidequest_near_light_0 once per game to Stuhlinger when the first tune starts on the
//   Richtofen side (zm_transit_sq.gsc:1156, df_vox_once).
// Shared helpers relied on: df_lamp_* (df_lamps), df_prompt, df_fx_loop / df_fx_stop, df_soul_fly,
// df_death_listen_*, df_scaled_step, df_touch, df_complete, df_say, df_debug_print, df_ground, df_coord,
// df_sys_clock_run, df_sys_hud_timers, and the 2026-09-09 core additions df_step_focus, df_cue_tick,
// df_cue_subgoal, df_cue_fail, df_vox_once (df_systems / df_steps "cues" sections, tools/audit_V2core.md).
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;
#include scripts\zm\zm_transit\df_lamps;

df_act3_sweep_init()
{
    df_lamps_init();
    df_register_step( "step5", ::df_s5_run, ::df_s5_setup );
}

// Tunables in one place (seconds / units / counts / text).
df_s5_config()
{
    level.df_s5_need = 3;
    level.df_s5_tune_time = 5; // audit #2: the anchor is the puzzle, the hold is a short channelling (was 20)
    level.df_s5_wait_time = 15;
    level.df_s5_drain_time = 10;
    level.df_s5_tune_radius = 200;
    level.df_s5_turbine_radius = 200; // Maxis anchor: a running turbine this close to the lamp base
    level.df_s5_anchor_fresh = 45; // Richtofen anchor: a burrow this recent still counts
    level.df_s5_soul_radius = 400;
    level.df_s5_soul_cue_every = 5;
    level.df_s5_timer_warn = 30;
    level.df_s5_timer_tick = 10;
    level.df_s5_hint = "Hold [{+activate}] to tune";
}

// Penalty souls per unanchored lamp (audit 1.1: 8/10/12/14). A "sweep_souls" row in df_steps wins when the
// steps agent adds one; until then this table, on the player count snapshotted when Step 5 opened.
df_s5_pen_quota()
{
    if ( isdefined( level.df_scale ) && isdefined( level.df_scale["sweep_souls"] ) )
        return df_scaled_step( "sweep_souls", "step5" );

    n = df_player_count();

    if ( isdefined( level.df_step_players ) && isdefined( level.df_step_players["step5"] ) )
        n = level.df_step_players["step5"];

    return 12 + 3 * n; // audit v3 #8: 15 solo (was 8), expiry now costs more than the rush it replaces
}

// level.df_side is locked by Step 4; undefined counts as Maxis rules (turbine anchor).
df_s5_is_rich()
{
    return isdefined( level.df_side ) && level.df_side == "rich";
}

// Countdown length in seconds (steps audit v2 #3): Richtofen reads the "sweep_time_rich" row when df_steps
// defines it (480/360/300/270: three denizen latches are RNG), else "sweep_time"; Maxis always
// "sweep_time" (360/300/270/240). Both on the player count snapshotted when Step 5 opened (df_scaled_step).
df_s5_sweep_seconds()
{
    if ( df_s5_is_rich() && isdefined( level.df_scale ) && isdefined( level.df_scale["sweep_time_rich"] ) )
        return df_scaled_step( "sweep_time_rich", "step5" );

    return df_scaled_step( "sweep_time", "step5" );
}

// =========================================================================================
// step flow
// =========================================================================================

df_s5_run()
{
    level endon( "end_game" );
    level endon( "df_skip_step5" );

    df_s5_config();

    if ( !df_s5_collect_lamps() )
    {
        df_debug_print( "DF: s5 no lamp posts on this map, step auto-completed" );
        df_complete( "step5" );
        return;
    }

    if ( level.df_s5_need > level.df_s5_lamps.size )
        level.df_s5_need = level.df_s5_lamps.size;

    level.df_s5_phase = "tuning";
    level.df_s5_end_ms = undefined;
    level.df_s5_force_expire = 0;
    level thread df_s5_skip_cleanup();
    level thread df_s5_debug_hooks();
    level thread df_s5_prompt_think();

    foreach ( lamp in level.df_s5_lamps )
    {
        df_s5_lamp_reset( lamp );
        lamp.anchored = 0;
        lamp.touched = 0;
        df_lamp_power_silent( lamp, 1 ); // keeps the burrow flag on (Richtofen); harmless on Maxis
        df_lamp_state_set( lamp, "filled" );
        df_s5_glint_set( lamp, 1 ); // "take me" glint until this lamp's first hold (art audit S5.2)
        level thread df_s5_burrow_listen( lamp );
        level thread df_s5_claim_keeper( lamp );
        level thread df_s5_lamp_think( lamp );
    }

    // the shared STEP AVAILABLE cue (df_steps) glints the focus until the first touch: the first set lamp
    df_step_focus( "step5", df_lamp_bulb_pos( level.df_s5_lamps[0] ) );

    verb = "turbine within " + level.df_s5_turbine_radius;

    if ( df_s5_is_rich() )
    {
        verb = "knuckle jolt on the post";
        level thread df_s5_jolt_loop();
    }

    df_debug_print( "DF: s5 sweep open: " + level.df_s5_lamps.size + " set lamps, anchor " + level.df_s5_need + " (" + verb + "), timer " + df_s5_sweep_seconds() + " s from the first anchor" );

    while ( df_s5_anchored_count() < level.df_s5_need )
        level waittill( "df_s5_check" );

    df_s5_finish();
}

// Normal end: everything goes except the anchored look of the anchored lamps (the end state).
df_s5_finish()
{
    df_debug_print( "DF: s5 " + level.df_s5_need + " lamps anchored, step done" );
    df_s5_teardown( 0 );
    df_say( "D5_DONE" );
    df_complete( "step5" );
}

// "!df goto" past step5: `need` set lamps marked anchored (anchored look, no silent power).
df_s5_setup()
{
    df_s5_config();

    if ( !df_s5_collect_lamps() )
        return;

    n = 0;

    foreach ( lamp in level.df_s5_lamps )
    {
        if ( n >= level.df_s5_need )
            break;

        lamp.anchored = 1;
        df_lamp_state_set( lamp, "anchored" );
        n++;
    }

    df_debug_print( "DF: s5 setup: " + n + " lamps marked anchored" );
}

// A skip deletes everything, anchored looks included: df_debug_goto runs df_s5_setup right after it.
df_s5_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_step5_done" );
    level waittill( "df_skip_step5" );

    df_debug_print( "DF: s5 skipped, cleaning up" );
    df_s5_teardown( 1 );
}

// Ends every step thread and removes prompts, bars, countdowns, the penalty and the silent power.
// everything = 1 also drops the anchored flags (skip). Lamp looks: anchored lamps keep "anchored"; the
// others go back to "filled" (R2 lamps, still Step 6 nodes) or "off".
df_s5_teardown( everything )
{
    level notify( "df_s5_stop" );
    df_s5_hud_destroy_all();
    df_s5_wait_hud_destroy();
    df_s5_prompts_clear();
    df_death_listen_remove( "s5pen" );
    level.df_s5_pens = undefined;
    level.df_s5_end_ms = undefined;

    if ( !isdefined( level.df_s5_lamps ) )
        return;

    foreach ( lamp in level.df_s5_lamps )
    {
        df_s5_bar_hide( lamp );
        df_s5_glint_set( lamp, 0 );
        df_lamp_power_silent( lamp, 0 );

        if ( everything )
            lamp.anchored = 0;

        if ( is_true( lamp.anchored ) )
            df_lamp_state_set( lamp, "anchored" );
        else if ( !everything && is_true( lamp.filled ) )
            df_lamp_state_set( lamp, "filled" );
        else
            df_lamp_state_set( lamp, "off" );
    }
}

// =========================================================================================
// lamps (the shared set)
// =========================================================================================

// level.df_s5_lamps = the game's lamp set (df_lamp_set_get: R2's lamps, or picked now on the Maxis side).
df_s5_collect_lamps()
{
    level.df_s5_lamps = df_lamp_set_get();

    if ( !isdefined( level.df_s5_lamps ) || level.df_s5_lamps.size == 0 )
        return false;

    foreach ( lamp in level.df_s5_lamps )
        df_debug_print( "DF: s5 lamp " + lamp.name + " at " + int( lamp.origin[0] ) + " " + int( lamp.origin[1] ) + " " + int( lamp.origin[2] ) );

    return true;
}

// Tuning bookkeeping of one lamp back to empty (the anchored flag is handled by the caller).
df_s5_lamp_reset( lamp )
{
    lamp.progress = 0;
    lamp.tone_step = 0;
    lamp.wait_until = undefined;
    lamp.drain_until = undefined;
    lamp.tune_start = undefined;
}

df_s5_anchored_count()
{
    n = 0;

    foreach ( lamp in level.df_s5_lamps )
    {
        if ( is_true( lamp.anchored ) )
            n++;
    }

    return n;
}

// The vanilla "take me" glint (fx_zmb_tranzit_key_glint, zm_transit_fx.gsc:105, the buildable-part marker)
// at the bulb of a set lamp that nobody has tuned yet (art audit S5.2: "filled" looks like the R2 residue,
// nothing else says the lamp wants a hold). on = 0 removes it; a lamp that was touched never gets it back.
df_s5_glint_set( lamp, on )
{
    if ( on && is_true( lamp.touched ) )
        on = 0;

    if ( !on )
    {
        df_fx_stop( lamp.glint );
        lamp.glint = undefined;
        return;
    }

    if ( isdefined( lamp.glint ) )
        return;

    lamp.glint = df_fx_loop( "fx_zmb_tranzit_light_glow", df_lamp_bulb_pos( lamp ) );
}

// Two PROGRESS clinks (df_cue_tick = zmb_buildable_piece_add 3D, zm_transit_sq.gsc:1074) 0.2 s apart at pos:
// "the lamp is tuned" (art audit S5.3; the PaP-ready ding meant "go back to the machine"). Thread it.
df_s5_tuned_clinks( pos )
{
    level endon( "end_game" );

    df_cue_tick( pos );
    wait 0.2;
    df_cue_tick( pos );
}

// The look of an unanchored lamp during the tuning phase, from its bar: "filled" idle (or draining after
// "Signal lost"), "tuning" while the bar fills or leaks, "waiting" at 100 % until the anchor.
df_s5_look( lamp )
{
    if ( isdefined( lamp.drain_until ) )
        return "filled";

    if ( lamp.progress >= 1 )
        return "waiting";

    if ( lamp.progress > 0 )
        return "tuning";

    return "filled";
}

// A denizen that never finished its walk to the lamp leaves a stale "claimed" mark
// (zm_transit_ai_screecher.gsc:47) that blocks the next burrow; freed after 30 s. .burrow_active is set by
// create_portal (:71) and cleared at :153. (Power is kept by df_lamp_keeper.)
df_s5_claim_keeper( lamp )
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );

    while ( true )
    {
        wait 0.5;

        if ( is_true( lamp.light.claimed ) && !is_true( lamp.light.burrow_active ) )
        {
            if ( !isdefined( lamp.claim_seen ) )
                lamp.claim_seen = gettime();
            else if ( gettime() - lamp.claim_seen > 30000 )
            {
                lamp.light.claimed = undefined;
                lamp.claim_seen = undefined;
                df_debug_print( "DF: s5 lamp " + lamp.name + " stale denizen claim cleared" );
            }
        }
        else
            lamp.claim_seen = undefined;
    }
}

// =========================================================================================
// prompt ("Hold to tune" is a mechanic prompt: df_prompt, shown while the bar is idle)
// =========================================================================================

df_s5_prompt_think()
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );

    r2 = level.df_s5_tune_radius * level.df_s5_tune_radius;

    while ( true )
    {
        foreach ( player in getplayers() )
        {
            want = 0;

            if ( is_player_valid( player ) )
                want = df_s5_prompt_wanted( player, r2 );

            df_s5_prompt_set( player, want );
        }

        wait 0.2;
    }
}

// True inside the radius of a set lamp that is TUNABLE (df_s5_lamp_tunable): not anchored, not draining
// after "Signal lost", not full and waiting. A lamp whose hold fills or leaks stays tunable (the hold can be
// resumed), so the prompt stays up through the hold, as a vanilla hold hint does (owner bug 2026-09-09).
df_s5_prompt_wanted( player, r2 )
{
    if ( level.df_s5_phase != "tuning" )
        return 0;

    foreach ( lamp in level.df_s5_lamps )
    {
        if ( !df_s5_lamp_tunable( lamp ) )
            continue;

        if ( distancesquared( player.origin, lamp.origin ) < r2 )
            return 1;
    }

    return 0;
}

// Tunable = a hold at this lamp does something: not anchored, no drain running, bar below 100 %.
df_s5_lamp_tunable( lamp )
{
    if ( is_true( lamp.anchored ) || isdefined( lamp.drain_until ) )
        return false;

    return lamp.progress < 1;
}

// df_prompt (df_systems) is ONE shared slot per player (self.df_prompt_hud) that other systems also clear
// (disconnect watch, other steps' prompts): our own "shown" flag must never outlive the HUD element, or the
// prompt would never come back (owner bug 2026-09-09: no prompt after a "Signal lost" drain). Shown =
// our flag AND the element exists; otherwise a wanted prompt is (re)created.
df_s5_prompt_set( player, want )
{
    shown = is_true( player.df_s5_prompt ) && isdefined( player.df_prompt_hud );

    if ( want && !shown )
    {
        if ( is_true( player.df_s5_prompt ) )
            player df_prompt( 0, undefined ); // our element is gone: clear the slot before re-showing

        player df_prompt( 1, level.df_s5_hint );
        player.df_s5_prompt = 1;
        return;
    }

    if ( !want && is_true( player.df_s5_prompt ) )
    {
        player df_prompt( 0, undefined );
        player.df_s5_prompt = 0;
    }
}

df_s5_prompts_clear()
{
    foreach ( player in getplayers() )
        df_s5_prompt_set( player, 0 );
}

// =========================================================================================
// anchors (Richtofen: denizen burrow at the lamp; Maxis: running turbine within 200 of the base)
// =========================================================================================

// zm_transit_ai_screecher::screecher_should_burrow notifies "burrow_done" on the light struct (:59).
df_s5_burrow_listen( lamp )
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );

    while ( true )
    {
        lamp.light waittill( "burrow_done" );
        lamp.burrow_time = gettime();
        df_debug_print( "DF: s5 denizen burrowed at lamp " + lamp.name );
    }
}

// The fork (owner 2026-09-09, see the header). Maxis: a running turbine within df_s5_turbine_radius of the
// lamp base. level.local_power holds one struct per turbine that is currently powering (add_local_power on
// warm-up _zm_equip_turbine.gsc:410, removed by end_local_power when it is picked up, dies or is EMPed); a
// distance test to the base is the honest check (the powered item's .power flag is also set by main power,
// _zm_power.gsc:365 set_global_power, and cannot tell a turbine apart in general).
// Richtofen: a burrow during the tuning, or a recent one (df_s5_anchor_fresh), or a portal still open at the
// lamp (an open portal blocks any new burrow there until someone jumps in, so it must count). Under main
// power light.power_on is 1, so the vanilla create_portal path (zm_transit_ai_screecher.gsc:55) just works.
df_s5_has_anchor( lamp )
{
    if ( !df_s5_is_rich() )
        return df_s5_turbine_near( lamp );

    // owner 2026-09-11 (fists 5): Richtofen's anchor is a Galvaknuckle JOLT on the post (df_s5_jolt_loop), during the
    // tuning or within df_s5_anchor_fresh seconds before it. The denizen burrow no longer counts (it was RNG).
    if ( !isdefined( lamp.jolt_time ) )
        return false;

    if ( gettime() - lamp.jolt_time <= level.df_s5_anchor_fresh * 1000 )
        return true;

    if ( isdefined( lamp.tune_start ) && lamp.jolt_time >= lamp.tune_start )
        return true;

    return false;
}

// True when a powering turbine stands within df_s5_turbine_radius (flat + height) of the lamp base.
df_s5_turbine_near( lamp )
{
    if ( !isdefined( level.local_power ) )
        return false;

    r2 = level.df_s5_turbine_radius * level.df_s5_turbine_radius;

    foreach ( lp in level.local_power )
    {
        if ( isdefined( lp ) && isdefined( lp.origin ) && distancesquared( lp.origin, lamp.origin ) < r2 )
            return true;
    }

    return false;
}

// The anchor moment: the "anchored" look (steady side light + tower beam + slow double burst) and the
// SUB-GOAL cue at the bulb (df_cue_subgoal: zmb_sq_navcard_success 3D, the side flash and the canon node ->
// tower runner richtofen_sparks / maxis_sparks to the pylon top, zm_transit_classic.csc:112-155; art audit
// cue table + #4). The zmb_spawn_powerup sting is gone (it is the shared STEP AVAILABLE alias now). The
// FIRST anchor of a countdown-less phase starts the countdown (audit #2).
df_s5_anchor( lamp )
{
    if ( is_true( lamp.anchored ) )
        return;

    lamp.anchored = 1;
    df_s5_lamp_reset( lamp );
    df_s5_bar_hide( lamp );
    df_s5_glint_set( lamp, 0 );
    df_lamp_state_set( lamp, "anchored" );
    df_cue_subgoal( df_lamp_bulb_pos( lamp ) );

    n = df_s5_anchored_count();
    df_debug_print( "DF: s5 lamp " + lamp.name + " anchored (" + n + "/" + level.df_s5_need + ")" );

    if ( n < level.df_s5_need )
    {
        df_say( "D5_ANCHOR" );

        if ( !isdefined( level.df_s5_end_ms ) )
            df_s5_timer_start();
    }

    df_s5_wait_hud_sync();
    level notify( "df_s5_check" );
}

// =========================================================================================
// countdown (starts at the first ANCHOR, shown top-centre to every player)
// =========================================================================================

// Side-aware length (df_s5_sweep_seconds: "sweep_time_rich" on Richtofen when the row exists, else
// "sweep_time"), on the player count snapshotted when Step 5 opened.
df_s5_timer_start()
{
    seconds = df_s5_sweep_seconds();
    level.df_s5_end_ms = gettime() + seconds * 1000;
    level.df_s5_force_expire = 0;
    level.df_s5_hud_warned = 0;
    level.df_s5_last_tick = undefined;
    level thread df_s5_hud_loop();
    level thread df_sys_clock_run( level.df_s5_end_ms, "df_s5_stop", "df_skip_step5", "df_s5_timer_over" );
    level thread df_s5_timer_watch();
    df_debug_print( "DF: s5 countdown started at the first anchor: " + seconds + " s" );
}

df_s5_timer_watch()
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );

    while ( gettime() < level.df_s5_end_ms && !is_true( level.df_s5_force_expire ) )
        wait 0.1;

    df_s5_fail();
}

// Expiry fails forward (steps audit v2 #2): the anchored lamps KEEP their anchor (look, beam, flag); the
// buzz (zmb_bus_emp_shutdown, zm_transit_bus.gsc:3097) and D5_FAIL play, then the soul penalty runs only on
// the lamps that were NOT anchored when the time ran out (audit 1.1); those reopen for tuning afterwards
// (back to "filled", their stale burrow forgotten) and the next anchor starts a fresh timer with only the
// missing anchors left to win. A Richtofen fail no longer costs three denizen latches.
df_s5_fail()
{
    level notify( "df_s5_timer_over" );
    df_s5_hud_destroy_all();
    df_s5_wait_hud_destroy();
    level.df_s5_end_ms = undefined;
    level.df_s5_force_expire = 0;
    level.df_s5_phase = "penalty";
    unanchored = [];

    foreach ( lamp in level.df_s5_lamps )
    {
        if ( is_true( lamp.anchored ) )
            continue;

        unanchored[unanchored.size] = lamp;
        lamp.burrow_time = undefined;
        lamp.jolt_time = undefined;
        df_s5_lamp_reset( lamp );
        df_s5_bar_hide( lamp );
    }

    df_debug_print( "DF: s5 countdown expired: " + df_s5_anchored_count() + " anchor(s) kept, " + unanchored.size + " lamp(s) pay the penalty" );

    foreach ( player in getplayers() )
        player playsoundtoplayer( "zmb_bus_emp_shutdown", player );

    df_say( "D5_FAIL" );
    df_s5_penalty( unanchored );

    level.df_s5_phase = "tuning";

    foreach ( lamp in unanchored )
        df_lamp_state_set( lamp, "filled" );

    df_debug_print( "DF: s5 tuning open again on the unanchored lamps, countdown starts at the next anchor" );
}

// Keeps a countdown on every player's screen, turns it red for the last df_s5_timer_warn seconds and
// ticks once a second for the last df_s5_timer_tick (zmb_tombstone_timer_count, _zm_tombstone.gsc:380).
df_s5_hud_loop()
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );
    level endon( "df_s5_timer_over" );

    while ( true )
    {
        remaining = ( level.df_s5_end_ms - gettime() ) / 1000;

        foreach ( player in getplayers() )
        {
            if ( !isdefined( player.df_s5_hud ) )
                player df_s5_hud_create();
        }

        if ( remaining <= level.df_s5_timer_warn && !is_true( level.df_s5_hud_warned ) )
        {
            level.df_s5_hud_warned = 1;
            df_s5_hud_recolor( df_s5_timer_color( remaining ) );
            df_debug_print( "DF: s5 countdown: " + level.df_s5_timer_warn + " s left" );
        }

        // ticks: df_sys_clock_run (df_systems), started next to this loop

        wait 0.5;
    }
}

// Side colour (blue / orange) until the warning, then red.
df_s5_timer_color( remaining )
{
    if ( remaining <= level.df_s5_timer_warn )
        return ( 1, 0.35, 0.3 );

    if ( isdefined( level.df_side ) && level.df_side == "rich" )
        return ( 0.6, 0.82, 1 );

    return ( 1, 0.78, 0.5 );
}

// self = player. A small "Sweep" label over a large timer (settimer counts down on the client), top
// centre, y 22..70; the anchor timer (df_s5_wait_hud_create) sits below it at y 82..120.
df_s5_hud_create()
{
    if ( !df_sys_hud_timers() )
        return; // owner 2026-09-09: no timer on screen, the clock ticks instead (set df_hud_timers 1 to see it)

    remaining = ( level.df_s5_end_ms - gettime() ) / 1000;

    if ( remaining < 0.1 )
        remaining = 0.1;

    color = df_s5_timer_color( remaining );
    self.df_s5_hud_label = self df_s5_hud_text( 22, "default", 1.2, color, 0.8 );
    self.df_s5_hud_label settext( "Sweep" );
    self.df_s5_hud = self df_s5_hud_text( 40, "objective", 2.2, color, 0.9 );
    self.df_s5_hud settimer( remaining );
}

// self = player. One top-centre text element (the vanilla newclienthudelem pattern, _zm_tombstone.gsc).
df_s5_hud_text( y, font, scale, color, alpha )
{
    hud = newclienthudelem( self );
    hud.alignx = "center";
    hud.aligny = "top";
    hud.horzalign = "user_center";
    hud.vertalign = "user_top";
    hud.x = 0;
    hud.y = y;
    hud.font = font;
    hud.fontscale = scale;
    hud.color = color;
    hud.alpha = alpha;
    hud.foreground = 1;
    hud.hidewheninmenu = 1;
    return hud;
}

df_s5_hud_recolor( color )
{
    foreach ( player in getplayers() )
    {
        if ( isdefined( player.df_s5_hud ) )
            player.df_s5_hud.color = color;

        if ( isdefined( player.df_s5_hud_label ) )
            player.df_s5_hud_label.color = color;
    }
}

df_s5_hud_destroy_all()
{
    foreach ( player in getplayers() )
    {
        if ( isdefined( player.df_s5_hud ) )
            player.df_s5_hud destroy();

        if ( isdefined( player.df_s5_hud_label ) )
            player.df_s5_hud_label destroy();

        player.df_s5_hud = undefined;
        player.df_s5_hud_label = undefined;
    }
}

// =========================================================================================
// anchor timer (owner: the 15 s "waiting" must be unmistakable): a top-centre "Anchor" timer for every
// player while any lamp waits for its anchor, showing the earliest deadline; the lamp itself blinks and
// plays the tick-tock loop (df_lamps "waiting").
// =========================================================================================

// Called every lamp tick: (re)builds the timer when the earliest deadline changes, removes it when no
// lamp is waiting.
df_s5_wait_hud_sync()
{
    until = undefined;

    if ( level.df_s5_phase == "tuning" )
    {
        foreach ( lamp in level.df_s5_lamps )
        {
            if ( is_true( lamp.anchored ) || isdefined( lamp.drain_until ) || lamp.progress < 1 || !isdefined( lamp.wait_until ) )
                continue;

            if ( !isdefined( until ) || lamp.wait_until < until )
                until = lamp.wait_until;
        }
    }

    if ( !isdefined( until ) )
    {
        df_s5_wait_hud_destroy();
        return;
    }

    if ( isdefined( level.df_s5_wait_hud_until ) && level.df_s5_wait_hud_until == until )
        return;

    df_s5_wait_hud_destroy();
    level.df_s5_wait_hud_until = until;

    foreach ( player in getplayers() )
        player df_s5_wait_hud_create( until );
}

// self = player. "Anchor" label + timer, amber, right under the sweep countdown.
df_s5_wait_hud_create( until_ms )
{
    if ( !df_sys_hud_timers() )
        return; // the lamp's tick-tock loop (state "waiting") is the audible version

    remaining = ( until_ms - gettime() ) / 1000;

    if ( remaining < 0.1 )
        remaining = 0.1;

    color = ( 1, 0.85, 0.35 );
    self.df_s5_wait_label = self df_s5_hud_text( 82, "default", 1.2, color, 0.9 );
    self.df_s5_wait_label settext( "Anchor" );
    self.df_s5_wait_hud = self df_s5_hud_text( 98, "objective", 1.8, color, 1 );
    self.df_s5_wait_hud settimer( remaining );
}

df_s5_wait_hud_destroy()
{
    level.df_s5_wait_hud_until = undefined;

    foreach ( player in getplayers() )
    {
        if ( isdefined( player.df_s5_wait_hud ) )
            player.df_s5_wait_hud destroy();

        if ( isdefined( player.df_s5_wait_label ) )
            player.df_s5_wait_label destroy();

        player.df_s5_wait_hud = undefined;
        player.df_s5_wait_label = undefined;
    }
}

// =========================================================================================
// penalty: souls back into the lamps that were NOT anchored at expiry (audit 1.1, 2026-09-08)
// =========================================================================================

// Each lamp in `lamps` takes df_s5_pen_quota() souls ("souls" look); filled ones go "filled". An empty
// list (cannot happen: a full set completes the step) returns at once.
df_s5_penalty( lamps )
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );

    if ( !isdefined( lamps ) || lamps.size == 0 )
        return;

    target = df_s5_pen_quota();
    level.df_s5_pens = [];
    level.df_s5_pen_target = target;
    names = "";

    foreach ( lamp in lamps )
    {
        pen = spawnstruct();
        pen.lamp = lamp;
        pen.souls = 0;
        pen.filled = 0;
        level.df_s5_pens[level.df_s5_pens.size] = pen;
        df_lamp_state_set( lamp, "souls" );
        names = names + lamp.name + " ";
    }

    df_debug_print( "DF: s5 penalty: " + target + " souls each into the unanchored lamp(s) " + names );
    level thread df_s5_pen_debug_hook();
    df_death_listen_add( "s5pen", ::df_s5_pen_on_zombie_death );

    while ( !df_s5_pens_filled() )
        level waittill( "df_s5_pen_check" );

    df_death_listen_remove( "s5pen" );
    level notify( "df_s5_pen_done" );
    level.df_s5_pens = undefined;
    df_debug_print( "DF: s5 penalty paid" );
}

df_s5_pens_filled()
{
    foreach ( pen in level.df_s5_pens )
    {
        if ( !pen.filled )
            return false;
    }

    return true;
}

// Death listener: the nearest unfilled penalty lamp whose BASE is within df_s5_soul_radius (3D) takes the
// soul (trail to the bulb). Every df_s5_soul_cue_every souls a piece-add clink (zmb_buildable_piece_add,
// zm_transit_sq.gsc:1074) at the bulb says the counter moved.
df_s5_pen_on_zombie_death( zombie )
{
    best = undefined;
    best_d2 = level.df_s5_soul_radius * level.df_s5_soul_radius;

    foreach ( pen in level.df_s5_pens )
    {
        if ( pen.filled )
            continue;

        d2 = distancesquared( zombie.origin, pen.lamp.origin );

        if ( d2 < best_d2 )
        {
            best = pen;
            best_d2 = d2;
        }
    }

    if ( !isdefined( best ) )
        return;

    best.souls++;
    bulb = df_lamp_bulb_pos( best.lamp );
    level thread df_soul_fly( zombie.origin, bulb );

    if ( best.souls >= level.df_s5_pen_target )
        df_s5_pen_fill( best );
    else if ( best.souls % level.df_s5_soul_cue_every == 0 )
    {
        df_snd_near( "zmb_buildable_piece_add", bulb, 700 ); // the alias fades at 150: to the killer, at the listener
        df_debug_print( "DF: s5 penalty lamp " + best.lamp.name + " souls " + best.souls + "/" + level.df_s5_pen_target );
    }

    level notify( "df_s5_pen_check" );
}

// Completion cue for one penalty lamp: the SUB-GOAL cue at the bulb (df_cue_subgoal: chime + side flash +
// the lamp -> tower runner, as an R2 lamp filling; the zmb_powerup_grabbed that doubled the chime was the
// STEP DONE alias), look back to "filled".
df_s5_pen_fill( pen )
{
    if ( pen.filled )
        return;

    pen.filled = 1;
    pen.souls = level.df_s5_pen_target;
    df_lamp_state_set( pen.lamp, "filled" );
    df_cue_subgoal( df_lamp_bulb_pos( pen.lamp ) );
    df_debug_print( "DF: s5 penalty lamp " + pen.lamp.name + " filled" );
}

// "!df souls" / "!df fire s5_penalty": every penalty lamp filled at once.
df_s5_pen_debug_hook()
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );
    level endon( "df_s5_pen_done" );

    level waittill_either( "df_debug_souls_done", "df_debug_s5_penalty" );
    df_debug_print( "DF: s5 debug: penalty souls filled" );

    foreach ( pen in level.df_s5_pens )
        df_s5_pen_fill( pen );

    level notify( "df_s5_pen_check" );
}

// =========================================================================================
// tuning (hold use at the lamp)
// =========================================================================================
// One thread per lamp owns its "bar" (heard, not seen: the rising power loop, df_s5_rise_start). progress
// 0..1 fills while someone holds use inside the radius, leaks slowly when nobody does, waits at 100 % for
// an anchor, and is force-drained when none came. Each tick goes to exactly one of the four df_s5_tick_*
// states below, then the lamp look follows the bar. State per phase (owner bug 2026-09-09):
//   fill / leak   progress in (0,1), drain_until undefined -> tunable, prompt up, rise loop on
//   waiting       progress == 1, wait_until set            -> no prompt, no loop (tick-tock from the lamp)
//   drain         drain_until set, progress falling        -> no prompt, no loop
//   empty again   df_s5_lamp_reset: progress exactly 0, drain_until / wait_until undefined -> prompt returns

df_s5_lamp_think( lamp )
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );

    tick = 0.05;
    r2 = level.df_s5_tune_radius * level.df_s5_tune_radius;

    while ( true )
    {
        wait( tick );

        if ( is_true( lamp.anchored ) || level.df_s5_phase != "tuning" )
        {
            df_s5_bar_hide( lamp );
            continue;
        }

        holder = df_s5_find_holder( lamp, r2 );

        if ( isdefined( holder ) )
            lamp.last_holder = holder;

        if ( isdefined( lamp.drain_until ) )
            df_s5_tick_drain( lamp, holder, tick );
        else if ( lamp.progress >= 1 )
            df_s5_tick_waiting( lamp, holder );
        else if ( isdefined( holder ) )
            df_s5_tick_fill( lamp, holder, tick );
        else
            df_s5_tick_leak( lamp, tick );

        if ( !is_true( lamp.anchored ) )
            df_lamp_state_set( lamp, df_s5_look( lamp ) );

        df_s5_wait_hud_sync();
    }
}

// "Signal lost": forced drain after the anchor wait ran out, input ignored until the bar is empty; no
// prompt and no rise loop meanwhile. Empty: df_s5_lamp_reset clears drain_until and puts progress at
// exactly 0, so df_s5_lamp_tunable is true again and the prompt returns on the next prompt tick.
df_s5_tick_drain( lamp, holder, tick )
{
    df_s5_bar_hide( lamp );
    lamp.progress -= tick / level.df_s5_drain_time;
    lamp.tone_step = int( lamp.progress * 4 );

    if ( lamp.progress <= 0.001 )
    {
        df_s5_lamp_reset( lamp );
        df_debug_print( "DF: s5 lamp " + lamp.name + " tunable again" );
    }
}

// Bar full, waiting for the anchor: the lamp blinks + tick-tocks (state "waiting"), everyone sees the 15 s
// anchor timer when df_sys_hud_timers; no prompt, no rise loop. Wait over ("Signal lost"): the FAIL cue at
// the bulb (df_cue_fail: the EMP thump to everyone + the side loss fx where the progress was lost; art audit
// S5.5: it used to be silent for everyone but the tuner), drain starts.
df_s5_tick_waiting( lamp, holder )
{
    df_s5_bar_hide( lamp );

    if ( df_s5_has_anchor( lamp ) )
    {
        df_s5_anchor( lamp );
        return;
    }

    if ( gettime() >= lamp.wait_until )
    {
        lamp.drain_until = gettime();
        lamp.wait_until = undefined;
        df_debug_print( "DF: s5 lamp " + lamp.name + " no anchor within " + level.df_s5_wait_time + " s, signal lost, draining" );
        df_cue_fail( df_lamp_bulb_pos( lamp ) );
    }
}

// The patron names the missing anchor once per game, the first time a tuned lamp waits for it:
// S5_ANCHOR_DENIZEN_RICH (Richtofen: a digger must ride you there) / S5_ANCHOR_TURBINE_MAXIS (Maxis: a
// turbine at the lamp's foot).
df_s5_anchor_hint_once()
{
    if ( is_true( level.df_s5_anchor_said ) )
        return;

    level.df_s5_anchor_said = 1;

    if ( df_s5_is_rich() )
        df_say( "S5_ANCHOR_DENIZEN_RICH" );
    else
        df_say( "S5_ANCHOR_TURBINE_MAXIS" );
}

// Richtofen's canon "you are at a lamp" line (vox_zmba_sidequest_near_light_0, zm_transit_sq.gsc:1156) to
// Stuhlinger, once per game (df_vox_once keeps the flag, threads and serializes df_rich_vox itself), the
// first time a tune starts on the Richtofen side (art audit S5.4). Nothing on Maxis (no canon line fits).
df_s5_near_light_once()
{
    if ( df_s5_is_rich() )
        df_vox_once( "vox_zmba_sidequest_near_light_0", undefined );
}

// Someone holds use: the bar fills (the "tuning" look sparks, the rise loop plays), a tick pattern every
// 25 %; at 100 % the loop ends (zmb_power_rise_stop, zm_transit_power.gsc:409) and two PROGRESS clinks
// (df_s5_tuned_clinks) say the lamp is tuned and waits (owner 2026-09-09: one distinct sound for that
// moment; art audit S5.3: the PaP ding was the wrong family). The first hold on a lamp is its "touch":
// the glint goes, and on the Richtofen side the first tune of the game gets Richtofen's near_light line.
// (The old "a denizen grabbing the tuner costs 50 %" rule is gone, audit #2.)
df_s5_tick_fill( lamp, holder, tick )
{
    if ( lamp.progress <= 0 )
    {
        lamp.tune_start = gettime();
        lamp.tone_step = 0;
        lamp.touched = 1;
        df_s5_glint_set( lamp, 0 );
        df_touch( "step5" );
        df_s5_near_light_once();
        df_debug_print( "DF: s5 tuning started at lamp " + lamp.name );
    }

    lamp.progress += tick / level.df_s5_tune_time;
    df_s5_bar_show( lamp, holder, "Tuning" );

    if ( lamp.progress >= 1 )
    {
        lamp.progress = 1;

        if ( df_s5_has_anchor( lamp ) )
        {
            df_s5_anchor( lamp );
            return;
        }

        lamp.wait_until = gettime() + int( level.df_s5_wait_time * 1000 );
        df_s5_bar_hide( lamp );
        level thread df_s5_tuned_clinks( df_lamp_bulb_pos( lamp ) );
        df_s5_anchor_hint_once();
        df_debug_print( "DF: s5 lamp " + lamp.name + " tuned, waiting " + level.df_s5_wait_time + " s for an anchor" );
        return;
    }

    df_s5_tone_check( lamp, holder );
}

// Nobody holding: slow leak, the bar stays on the last tuner's screen while he is close.
df_s5_tick_leak( lamp, tick )
{
    if ( lamp.progress <= 0 )
    {
        df_s5_bar_hide( lamp );
        return;
    }

    lamp.progress -= tick / ( level.df_s5_drain_time * 2 );
    lamp.tone_step = int( lamp.progress * 4 );

    if ( lamp.progress <= 0 )
    {
        df_s5_lamp_reset( lamp );
        df_s5_bar_hide( lamp );
        df_debug_print( "DF: s5 lamp " + lamp.name + " bar leaked empty" );
        return;
    }

    df_s5_bar_show( lamp, df_s5_bar_viewer( lamp, undefined ), "Tuning" );
}

// Rising tone steps: crossing 25 / 50 / 75 % plays 1 / 2 / 3 quick ticks to the tuner (no pitch control
// in GSC, so the count rises instead). lamp.tone_step follows the bar down so a re-fill plays them again.
df_s5_tone_check( lamp, holder )
{
    step = int( lamp.progress * 4 );

    if ( step > 3 )
        step = 3;

    if ( step <= lamp.tone_step )
        return;

    lamp.tone_step = step;
    holder thread df_s5_tone_play( step );
}

// self = player. zmb_tombstone_timer_count is the vanilla 2D tick (_zm_tombstone.gsc:380).
df_s5_tone_play( count )
{
    self endon( "disconnect" );

    for ( i = 0; i < count; i++ )
    {
        self playsoundtoplayer( "zmb_tombstone_timer_count", self );
        wait 0.15;
    }
}

// The player holding use inside the radius. The current holder keeps the lamp while he holds; otherwise
// the first player found takes over (co-op: one tuner per lamp is enough).
df_s5_find_holder( lamp, r2 )
{
    h = lamp.holder;

    if ( isdefined( h ) && isplayer( h ) && is_player_valid( h ) && h usebuttonpressed() && distancesquared( h.origin, lamp.origin ) < r2 )
        return h;

    lamp.holder = undefined;

    foreach ( player in getplayers() )
    {
        if ( !is_player_valid( player ) || !player usebuttonpressed() )
            continue;

        if ( distancesquared( player.origin, lamp.origin ) < r2 )
        {
            lamp.holder = player;
            return player;
        }
    }

    return undefined;
}

// Who sees the bar when nobody holds: the last tuner while he is within twice the radius.
df_s5_bar_viewer( lamp, holder )
{
    if ( isdefined( holder ) )
        return holder;

    h = lamp.last_holder;

    if ( !isdefined( h ) || !isplayer( h ) || !is_player_valid( h ) )
        return undefined;

    r = level.df_s5_tune_radius * 2;

    if ( distancesquared( h.origin, lamp.origin ) > r * r )
        return undefined;

    return h;
}

// The "bar" is the rising power loop at the lamp (no HUD bar since 2026-09-09): one per lamp, rebuilt when
// the viewer or the label changes, shown only while the hold fills or leaks ("Tuning").
df_s5_bar_show( lamp, player, label )
{
    if ( !isdefined( player ) )
    {
        df_s5_bar_hide( lamp );
        return;
    }

    if ( isdefined( lamp.bar ) )
    {
        if ( !isdefined( lamp.bar_owner ) || lamp.bar_owner != player || lamp.bar_label != label )
            df_s5_bar_hide( lamp );
    }

    if ( !isdefined( lamp.bar ) )
    {
        lamp.bar = df_s5_rise_start( lamp ); // owner 2026-09-09: no bar, a rising power sound at the lamp
        lamp.bar_owner = player;
        lamp.bar_label = label;
    }
}

// The tuning is heard, not seen: power-rise start + loop on a script_origin at the bulb
// (zm_transit_power.gsc:399-409). Returned so lamp.bar can stop it.
df_s5_rise_start( lamp )
{
    ent = spawn( "script_origin", df_lamp_bulb_pos( lamp ) );
    ent playsound( "zmb_power_rise_start" );
    ent playloopsound( "zmb_power_rise_loop" );
    return ent;
}

df_s5_bar_hide( lamp )
{
    if ( isdefined( lamp.bar ) )
    {
        lamp.bar stoploopsound();
        lamp.bar playsound( "zmb_power_rise_stop" );
        lamp.bar delete();
    }

    lamp.bar = undefined;
    lamp.bar_owner = undefined;
    lamp.bar_label = undefined;
}

// =========================================================================================
// debug hooks
//   !df fire s5_anchor   anchor the unanchored set lamp nearest to a player
//   !df fire s5_all      anchor `need` lamps (completes the step)
//   !df fire s5_time     expire the countdown now (needs a running countdown: it starts at the first anchor)
//   !df fire s5_penalty  fill the penalty souls now (see df_s5_pen_debug_hook); "!df souls" does the same
//   !df fire lamps       (df_lamps.gsc) prints the set and every lamp's state
// =========================================================================================

df_s5_debug_hooks()
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );

    level thread df_s5_debug_anchor_hook();
    level thread df_s5_debug_time_hook();
    level waittill( "df_debug_s5_all" );
    df_debug_print( "DF: s5 debug: anchoring " + level.df_s5_need + " lamps" );

    foreach ( lamp in level.df_s5_lamps )
    {
        if ( df_s5_anchored_count() >= level.df_s5_need )
            break;

        df_s5_anchor( lamp );
    }
}

df_s5_debug_anchor_hook()
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );

    while ( true )
    {
        level waittill( "df_debug_s5_anchor" );
        pos = df_coord( "DF_SOCKET" ).origin;

        foreach ( player in getplayers() )
        {
            if ( is_player_valid( player ) )
            {
                pos = player.origin;
                break;
            }
        }

        best = undefined;
        best_d2 = 0;

        foreach ( lamp in level.df_s5_lamps )
        {
            if ( is_true( lamp.anchored ) )
                continue;

            d2 = distancesquared( pos, lamp.origin );

            if ( !isdefined( best ) || d2 < best_d2 )
            {
                best = lamp;
                best_d2 = d2;
            }
        }

        if ( !isdefined( best ) )
        {
            df_debug_print( "DF: s5 debug: no unanchored lamp left" );
            continue;
        }

        df_debug_print( "DF: s5 debug: anchoring lamp " + best.name );
        df_s5_anchor( best );
    }
}

df_s5_debug_time_hook()
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );

    while ( true )
    {
        level waittill( "df_debug_s5_time" );

        if ( !isdefined( level.df_s5_end_ms ) )
        {
            df_debug_print( "DF: s5 debug: no countdown running (anchor one lamp first, e.g. !df fire s5_anchor)" );
            continue;
        }

        df_debug_print( "DF: s5 debug: expiring the countdown" );
        level.df_s5_force_expire = 1;
    }
}

// ---- fists (owner 2026-09-11, idea 5) ---------------------------------------------------------
// Richtofen's Step 5 anchor: melee with the Galvaknuckles within 90 of a set lamp's post = a jolt (lamp.jolt_time);
// df_s5_has_anchor reads it while the lamp waits. Another melee there: deny + Richtofen names the fists (20 s).
df_s5_jolt_loop()
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level endon( "df_skip_step5" );

    while ( true )
    {
        wait 0.05;

        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) || !df_melee_edge( player ) )
                continue;

            lamp = df_s5_jolt_target( player.origin );

            if ( !isdefined( lamp ) )
                continue;

            if ( !df_has_knuckles( player ) )
            {
                df_cue_deny( player );

                if ( !isdefined( level.df_s5_nofists_time ) || gettime() - level.df_s5_nofists_time > 20000 )
                {
                    level.df_s5_nofists_time = gettime();
                    df_say( "S5_NOFISTS_RICH" );
                }

                continue;
            }

            lamp.jolt_time = gettime();
            df_punch_fx( lamp.origin, df_lamp_bulb_pos( lamp ) );
            df_debug_print( "DF: s5 lamp " + lamp.name + " jolted by " + player.name + " (counts as the anchor for " + level.df_s5_anchor_fresh + " s)" );
        }
    }
}

// The set lamp (not yet anchored) whose post is within 90 of pos.
df_s5_jolt_target( pos )
{
    foreach ( lamp in level.df_s5_lamps )
    {
        if ( !is_true( lamp.anchored ) && distancesquared( pos, lamp.origin ) <= 90 * 90 )
            return lamp;
    }

    return undefined;
}
