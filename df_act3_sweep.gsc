// Dead Frequency - Act 3 Step 5, by side (owner 2026-09-25).
//   The step key stays "step5"; df_s5_run / df_s5_setup dispatch on level.df_side:
//   - Richtofen: "Blackout" (df_act3_blackout.gsc): Maxis flips three power switches OFF, one press each turns
//     them back ON.
//   - Maxis: "Lights Out" (this file): Richtofen feeds his power into THREE lamps of the fog (the game's ONE lamp
//     set, df_lamps df_lamp_set_get); the players put them out. Only the dead may break his light: a lamp goes
//     dark when a zombie dies to a CLAYMORE (claymore_zm, sold at the Farm wall buy) within
//     level.df_s5_kill_radius of its base. Any other kill there does nothing (Maxis says why once, after five
//     such kills, LO_NOTHAND_MAXIS). At every end of round while a lamp still hums, Richtofen relights ONE dark lamp
//     (LO_RELIGHT), the mirror of Maxis's knock in Blackout. Three dark at once: the step is done (level.df_s5_need =
//     3; owner 2026-09-25: exactly three lamps hum at every player count, the first three of the set).
//   Replaces the old tune + turbine sweep (the turbine is his electricity; the owner wanted the fire side to break
//   the lamps instead).
// Lamp looks come only from df_lamp_state_set (df_lamps.gsc): "possessed" = humming with his power (a big
// looping electric spark, a blue glow, his hum: it is Richtofen's light), "vanilla" = put out, the lamp exactly as the map has it.
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
    level.df_s5_kill_radius = 250; // owner 2026-09-25: a claymore kill this close to the lamp base puts it out (150 missed:
                                   // a claymore throws the zombie several steps before it dies)
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
    level thread df_s5_claymore_watch();

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
    set = df_lamp_set_get();

    if ( !isdefined( set ) || set.size == 0 )
        return false;

    // owner 2026-09-25: exactly three lamps at every player count (the set is three since 2026-09-28; the cap
    // stays as a guard)
    level.df_s5_lamps = [];

    for ( i = 0; i < set.size && i < 3; i++ )
        level.df_s5_lamps[i] = set[i];

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
        df_lamp_state_set( lamp, "vanilla" );
    else
        df_lamp_state_set( lamp, "possessed" );

    if ( is_true( quiet ) )
        return;

    bulb = df_lamp_bulb_pos( lamp );

    if ( dark )
    {
        // owner 2026-09-25: his electricity escapes: a blue snap at the bulb and a spark trail flying back to his tower
        df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", bulb );
        playsoundatposition( "zmb_zombie_arc", bulb );
        top = df_tower_top();

        if ( isdefined( top ) )
            level thread df_soul_fly( bulb, top );

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

// owner 2026-09-25: the game reports a claymore kill as weapon "none", MOD_GRENADE_SPLASH (owner's console), the same as a
// thrown grenade. So the step tracks the planted claymores (player.claymores, _zm_weap_claymore.gsc) standing within the
// kill radius of a humming lamp; when a tracked one disappears (it exploded) the lamp stamps df_s5_clay_gone_ms. A splash
// kill there within 1.5 s of that stamp is the claymore's, either order: a kill seen before the watch noticed the
// claymore gone waits as df_s5_splash_ms and is credited at the stamp (df_s5_claymore_gone). A merely planted claymore
// no longer lets a grenade count.
df_s5_claymore_watch()
{
    level endon( "end_game" );
    level endon( "df_skip_step5" );
    level endon( "df_s5_stop" );

    level.df_s5_clays = [];

    while ( true )
    {
        wait 0.05;
        df_s5_claymore_sweep();
    }
}

// One pass: stamps the lamps whose tracked claymore is gone, then tracks every new claymore near a humming lamp.
df_s5_claymore_sweep()
{
    if ( !isdefined( level.df_s5_clays ) )
        return;

    r2 = level.df_s5_kill_radius * level.df_s5_kill_radius;
    kept = [];

    foreach ( t in level.df_s5_clays )
    {
        if ( isdefined( t.ent ) )
            kept[kept.size] = t;
        else
            df_s5_claymore_gone( t.lamp );
    }

    level.df_s5_clays = kept;

    foreach ( player in getplayers() )
    {
        if ( !isdefined( player.claymores ) )
            continue;

        foreach ( clay in player.claymores )
        {
            if ( !isdefined( clay ) || df_s5_claymore_tracked( clay ) )
                continue;

            foreach ( lamp in level.df_s5_lamps )
            {
                if ( is_true( lamp.df_s5_dark ) || distance2dsquared( clay.origin, lamp.origin ) >= r2 )
                    continue;

                t = spawnstruct();
                t.ent = clay;
                t.lamp = lamp;
                level.df_s5_clays[level.df_s5_clays.size] = t;
                break;
            }
        }
    }
}

df_s5_claymore_tracked( clay )
{
    foreach ( t in level.df_s5_clays )
    {
        if ( isdefined( t.ent ) && t.ent == clay )
            return true;
    }

    return false;
}

// True while a tracked claymore still stands by `lamp`.
df_s5_claymore_at( lamp )
{
    if ( !isdefined( level.df_s5_clays ) )
        return false;

    foreach ( t in level.df_s5_clays )
    {
        if ( isdefined( t.ent ) && t.lamp == lamp )
            return true;
    }

    return false;
}

// A tracked claymore by `lamp` just went off: stamp it, and credit a splash kill seen there in the last 1.5 s.
df_s5_claymore_gone( lamp )
{
    lamp.df_s5_clay_gone_ms = gettime();

    if ( !isdefined( lamp.df_s5_splash_ms ) || gettime() - lamp.df_s5_splash_ms >= 1500 )
        return;

    lamp.df_s5_splash_ms = undefined;

    if ( !is_true( lamp.df_s5_dark ) )
        df_s5_lamp_out( lamp );
}

df_s5_claymore_blast( lamp, mod )
{
    if ( mod != "MOD_GRENADE_SPLASH" && mod != "MOD_EXPLOSIVE" )
        return false;

    df_s5_claymore_sweep(); // a claymore gone this frame stamps its lamp now
    return isdefined( lamp.df_s5_clay_gone_ms ) && gettime() - lamp.df_s5_clay_gone_ms < 1500;
}

// Only a claymore puts a lamp out: the dead set it off, not the player's hand (LO_NOTHAND_MAXIS once, after five refused kills).
df_s5_on_zombie_death( zombie )
{
    lamp = df_s5_lit_near( zombie.origin );

    if ( !isdefined( lamp ) )
        return;

    weapon = "none";

    if ( isdefined( zombie.damageweapon ) )
        weapon = zombie.damageweapon;

    mod = "none";

    if ( isdefined( zombie.damagemod ) )
        mod = zombie.damagemod;

    // owner 2026-09-25: the console says what killed each zombie by a humming lamp, so a refused kill can be read
    df_debug_print( "DF: s5 kill by " + lamp.name + " at " + int( distance2d( zombie.origin, lamp.origin ) ) + ": weapon " + weapon + ", mod " + mod );

    if ( !issubstr( weapon, "claymore" ) && !df_s5_claymore_blast( lamp, mod ) )
    {
        // a splash kill by a claymore still standing: it may be that claymore's blast, credited once it is seen gone
        if ( ( mod == "MOD_GRENADE_SPLASH" || mod == "MOD_EXPLOSIVE" ) && df_s5_claymore_at( lamp ) )
        {
            lamp.df_s5_splash_ms = gettime();
            return;
        }

        // owner 2026-09-25 (design audit 5.4): said once per game, and only after five refused kills by a humming lamp,
        // so the first stray kill no longer teaches the step (the line itself does not name the claymore)
        if ( !isdefined( level.df_s5_nothand_n ) )
            level.df_s5_nothand_n = 0;

        level.df_s5_nothand_n++;

        if ( level.df_s5_nothand_n >= 5 && !is_true( level.df_s5_nothand_said ) )
        {
            level.df_s5_nothand_said = 1;
            df_say( "LO_NOTHAND_MAXIS" );
        }

        return;
    }

    df_s5_lamp_out( lamp );
}

// The lamp goes dark by a claymore: progress tick, the count line, the step check.
df_s5_lamp_out( lamp )
{
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
