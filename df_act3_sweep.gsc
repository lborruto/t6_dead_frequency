// Dead Frequency - Act 3 Step 5, by side (owner 2026-09-25).
//   The step key stays "step5"; df_s5_run / df_s5_setup dispatch on level.df_side:
//   - Richtofen: "Blackout" (df_act3_blackout.gsc): Maxis flips three power switches OFF, one press each turns
//     them back ON.
//   - Maxis: "Lights Out" (this file): Richtofen feeds his power into THREE lamps of the fog (the game's ONE lamp
//     set, df_lamps df_lamp_set_get); the players put them out. Only the dead may break his light: a lamp goes
//     dark when a zombie dies to a CLAYMORE (claymore_zm, sold at the Farm wall buy) within
//     level.df_s5_kill_radius of its base. Any other kill there does nothing (Maxis says why once,
//     LO_NOTHAND_MAXIS). At every end of round while a lamp still hums, Richtofen relights ONE dark lamp
//     (LO_RELIGHT), the mirror of Maxis's knock in Blackout. All three dark at once: the step is done.
//   Replaces the old tune + turbine sweep (the turbine is his electricity; the owner wanted the fire side to break
//   the lamps instead).
// Lamp looks come only from df_lamp_state_set (df_lamps.gsc): "possessed" = humming with his power (a big
// looping electric spark, a blue glow, his hum: it is Richtofen's light), "dark" = the vanilla light off, black.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;
#include scripts\zm\zm_transit\df_lamps;
#include scripts\zm\zm_transit\df_act3_blackout;

df_act3_sweep_init()
{
    df_lamps_init();
    df_register_step( "step5", ::df_s5_run, ::df_s5_setup );
}

df_s5_config()
{
    level.df_s5_need = 3;
    level.df_s5_kill_radius = 150; // a claymore kill this close to the lamp base puts it out
}

// =========================================================================================
// step flow
// =========================================================================================

df_s5_run()
{
    level endon( "end_game" );
    level endon( "df_skip_step5" );

    if ( isdefined( level.df_side ) && level.df_side == "rich" )
    {
        df_bo_run();
        return;
    }

    df_s5_config();

    if ( !df_s5_collect_lamps() )
    {
        df_debug_print( "DF: s5 no lamp posts on this map, step auto-completed" );
        df_complete( "step5" );
        return;
    }

    level thread df_s5_skip_cleanup();
    level thread df_s5_relight_loop();
    level thread df_s5_debug_hook();

    foreach ( lamp in level.df_s5_lamps )
        df_s5_lamp_set( lamp, 0, 1 );

    df_death_listen_add( "s5", ::df_s5_on_zombie_death );
    level.df_lamp_safe_lamps = level.df_s5_lamps; // owner 2026-09-25: no denizens within 320 of the M3 lamps (df_lamp_step_safe)
    level.df_lamp_safe_radius = 320;
    df_step_focus( "step5", df_lamp_bulb_pos( level.df_s5_lamps[0] ) );
    df_debug_print( "DF: s5 lights out: " + level.df_s5_lamps.size + " lamps hum with his power, a claymore kill within " + level.df_s5_kill_radius + " puts one out, " + level.df_s5_need + " dark to win" );

    while ( df_s5_dark_count() < level.df_s5_need )
        level waittill( "df_s5_check" );

    df_s5_stop();
    df_say( "D5_DONE" );
    df_debug_print( "DF: s5 " + level.df_s5_need + " lamps dark, step done" );
    df_complete( "step5" );
}

// "!df goto" past step5 on Maxis: the set lamps stand dark, nothing running.
df_s5_setup()
{
    if ( isdefined( level.df_side ) && level.df_side == "rich" )
    {
        df_bo_setup();
        return;
    }

    df_s5_config();

    if ( !df_s5_collect_lamps() )
        return;

    foreach ( lamp in level.df_s5_lamps )
        df_s5_lamp_set( lamp, 1, 1 );

    df_s5_stop();
    df_debug_print( "DF: s5 setup: " + level.df_s5_lamps.size + " lamps dark" );
}

df_s5_stop()
{
    level.df_lamp_safe_lamps = undefined;
    df_death_listen_remove( "s5" );
    level notify( "df_s5_stop" );
}

df_s5_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );
    level waittill( "df_skip_step5" );
    level.df_lamp_safe_lamps = undefined;
    df_death_listen_remove( "s5" );
}

df_s5_collect_lamps()
{
    level.df_s5_lamps = df_lamp_set_get();

    if ( !isdefined( level.df_s5_lamps ) || level.df_s5_lamps.size == 0 )
        return false;

    if ( level.df_s5_lamps.size < level.df_s5_need )
        level.df_s5_need = level.df_s5_lamps.size;

    foreach ( lamp in level.df_s5_lamps )
        df_debug_print( "DF: s5 lamp " + lamp.name + " at " + int( lamp.origin[0] ) + " " + int( lamp.origin[1] ) + " " + int( lamp.origin[2] ) );

    return true;
}

// One lamp humming (dark 0) or dark (dark 1); quiet = no fx or sound (setup / opening).
df_s5_lamp_set( lamp, dark, quiet )
{
    lamp.df_s5_dark = dark;

    if ( dark )
        df_lamp_state_set( lamp, "dark" );
    else
        df_lamp_state_set( lamp, "possessed" );

    if ( is_true( quiet ) )
        return;

    bulb = df_lamp_bulb_pos( lamp );

    if ( dark )
    {
        df_fx_burst( "fx_zmb_tranzit_fire_med", bulb, 0.6 );
        df_fx_burst( "fx_zmb_ash_rising_md", bulb, 1.5 );
        df_snd_near( "zmb_phdflop_explo", lamp.origin, 900 );
        return;
    }

    df_snd_near( "zmb_turn_on", lamp.origin, 900 );
}

df_s5_dark_count()
{
    n = 0;

    foreach ( lamp in level.df_s5_lamps )
    {
        if ( is_true( lamp.df_s5_dark ) )
            n++;
    }

    return n;
}

// The humming lamp nearest to pos within the kill radius, else undefined.
df_s5_lit_near( pos )
{
    best = undefined;
    best_d2 = level.df_s5_kill_radius * level.df_s5_kill_radius;

    foreach ( lamp in level.df_s5_lamps )
    {
        if ( is_true( lamp.df_s5_dark ) )
            continue;

        d2 = distancesquared( pos, lamp.origin );

        if ( d2 <= best_d2 )
        {
            best = lamp;
            best_d2 = d2;
        }
    }

    return best;
}

// Only a claymore puts a lamp out: the dead set it off, not the player's hand (LO_NOTHAND_MAXIS once otherwise).
df_s5_on_zombie_death( zombie )
{
    lamp = df_s5_lit_near( zombie.origin );

    if ( !isdefined( lamp ) )
        return;

    if ( !isdefined( zombie.damageweapon ) || zombie.damageweapon != "claymore_zm" )
    {
        if ( !is_true( level.df_s5_nothand_said ) )
        {
            level.df_s5_nothand_said = 1;
            df_say( "LO_NOTHAND_MAXIS" );
        }

        return;
    }

    df_touch( "step5" );
    df_s5_lamp_set( lamp, 1 );
    df_cue_tick( df_lamp_bulb_pos( lamp ), 0 );
    df_debug_print( "DF: s5 lamp " + lamp.name + " put out by a claymore (" + df_s5_dark_count() + "/" + level.df_s5_need + " dark)" );

    if ( df_s5_dark_count() < level.df_s5_need )
        df_say( "LO_DARK_MAXIS" );

    level notify( "df_s5_check" );
}

// At every end of round while a lamp still hums, Richtofen relights one dark lamp (the mirror of Blackout's knock).
df_s5_relight_loop()
{
    level endon( "end_game" );
    level endon( "df_skip_step5" );
    level endon( "df_s5_stop" );

    while ( true )
    {
        level waittill( "end_of_round" );

        n = df_s5_dark_count();

        if ( n == 0 || n >= level.df_s5_lamps.size )
            continue;

        darks = [];

        foreach ( lamp in level.df_s5_lamps )
        {
            if ( is_true( lamp.df_s5_dark ) )
                darks[darks.size] = lamp;
        }

        lamp = random( darks );
        df_s5_lamp_set( lamp, 0 );
        df_say( "LO_RELIGHT" );
        df_debug_print( "DF: s5 Richtofen relit " + lamp.name + " at the end of the round" );
    }
}

// "!df fire s5_dark": every lamp dark (the step completes); "!df fire s5_relight": every lamp humming again.
df_s5_debug_hook()
{
    level endon( "end_game" );
    level endon( "df_s5_stop" );

    while ( true )
    {
        what = level waittill_any_return( "df_debug_s5_dark", "df_debug_s5_relight" );

        foreach ( lamp in level.df_s5_lamps )
            df_s5_lamp_set( lamp, what == "df_debug_s5_dark", 1 );

        df_debug_print( "DF: s5 debug: every lamp " + what );
        level notify( "df_s5_check" );
    }
}
