// Dead Frequency - Step 5 on the Richtofen side, "Blackout" (owner 2026-09-25, spec
//   docs/superpowers/specs/2026-09-25-blackout-and-persistent-props-design.md).
//   Three power switches (vanilla's switch without its hand: kinds pswitch_body + pswitch_lever, anchors
//   DF_BLACKOUT_1..3) stand ON from boot on both sides. When Step 5 opens on Richtofen, Maxis cuts the grid: the three
//   levers roll OFF. One press of F within 80 of an OFF switch rolls it ON again (vanilla: rotateroll -90 = ON,
//   +90 = OFF, zmb_switch_flip then zmb_turn_on, zm_transit_power.gsc:56-60), refused while the grid is off. Each switch
//   turned ON sends a 20 s sprint wave at it; at every end of round while one is OFF, Maxis knocks one ON switch
//   OFF again. All three ON at once: the step is done. The Maxis side keeps the lamp step (df_act3_sweep.gsc).
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;

df_act3_blackout_init()
{
    level thread df_bo_boot();
    level thread df_bo_debug_hook();
}

// Boot: the three switches stand ON for the whole game on both sides (owner: props exist from the start).
df_bo_boot()
{
    level endon( "end_game" );
    wait 0.1;
    df_bo_spawn();
}

df_bo_spawn()
{
    if ( isdefined( level.df_bo ) )
        return;

    level.df_bo = [];

    for ( i = 0; i < 3; i++ )
    {
        c = df_coord( "DF_BLACKOUT_" + ( i + 1 ) );

        if ( !isdefined( c ) )
            continue;

        s = spawnstruct();
        s.idx = i;
        s.origin = c.origin;
        s.yaw = c.angles[1];
        s.body = spawn( "script_model", c.origin );
        s.body setmodel( df_model( "pswitch_body" ) );
        s.body.angles = df_model_angles( "pswitch_body", s.yaw );
        s.lever = spawn( "script_model", c.origin + df_model_offset_at( "pswitch_lever", s.yaw ) );
        s.lever setmodel( df_model( "pswitch_lever" ) );
        s.lever.angles = df_model_angles( "pswitch_lever", s.yaw ) + ( 0, 0, -90 ); // ON
        s.on = 1;
        level.df_bo[level.df_bo.size] = s;
    }

    df_debug_print( "DF: blackout " + level.df_bo.size + " power switch(es) standing ON" );
}

// Rolls one lever; quiet = no sound (setup / debug).
df_bo_set( s, on, quiet )
{
    if ( s.on == on )
        return;

    s.on = on;

    if ( on )
        s.lever rotateroll( -90, 0.3 );
    else
        s.lever rotateroll( 90, 0.3 );

    if ( is_true( quiet ) )
        return;

    s.lever playsound( "zmb_switch_flip" );

    if ( on )
    {
        wait 0.3;
        s.lever playsound( "zmb_turn_on" );
        df_cue_tick( s.origin + ( 0, 0, 40 ), 0 );
        return;
    }

    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", s.origin + ( 0, 0, 40 ) );
}

df_bo_on_count()
{
    n = 0;

    foreach ( s in level.df_bo )
    {
        if ( s.on )
            n++;
    }

    return n;
}

// Step 5 on Richtofen (called by df_s5_run; blocks until the three are ON).
df_bo_run()
{
    level endon( "end_game" );
    level endon( "df_skip_step5" );

    df_bo_spawn();

    if ( level.df_bo.size == 0 )
    {
        df_debug_print( "DF: blackout no switch anchors, step auto-completed" );
        df_complete( "step5" );
        return;
    }

    level thread df_bo_skip_cleanup();
    level.df_bo_active = 1;

    foreach ( s in level.df_bo )
        level thread df_bo_set( s, 0 );

    df_debug_print( "DF: blackout Maxis cut the grid: " + level.df_bo.size + " switch(es) OFF, one press each turns it ON" );
    level thread df_bo_press_loop();
    level thread df_bo_round_knock();

    while ( df_bo_on_count() < level.df_bo.size )
        level waittill( "df_bo_check" );

    df_bo_stop();
    df_cue_subgoal( level.df_bo[0].origin + ( 0, 0, 40 ) );
    df_debug_print( "DF: blackout all switches ON" );
    df_say( "D5_DONE" );
    df_complete( "step5" );
}

// Goto past step5 on Richtofen: the three stand ON, nothing running.
df_bo_setup()
{
    df_bo_spawn();

    foreach ( s in level.df_bo )
        level thread df_bo_set( s, 1, 1 );

    df_bo_stop();
}

df_bo_stop()
{
    level.df_bo_active = 0;
    level notify( "df_bo_stop" );

    foreach ( player in getplayers() )
        player df_prompt( 0, undefined );
}

df_bo_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_bo_stop" );
    level waittill( "df_skip_step5" );
    df_bo_stop();
}

// One press of F at an OFF switch, like vanilla; refused on a dead grid.
df_bo_press_loop()
{
    level endon( "end_game" );
    level endon( "df_bo_stop" );

    while ( true )
    {
        wait 0.05;

        foreach ( player in getplayers() )
        {
            s = df_bo_near_off( player );

            if ( !isdefined( s ) )
            {
                if ( is_true( player.df_bo_prompt ) )
                {
                    player.df_bo_prompt = 0;
                    player df_prompt( 0, undefined );
                }

                continue;
            }

            player.df_bo_prompt = 1;
            player df_prompt( 1, "Press [{+activate}] to turn the power switch ON" );

            if ( !player df_press_use() )
                continue;

            df_touch( "step5" );

            if ( !flag( "power_on" ) )
            {
                df_cue_deny( player );

                // owner 2026-09-25 (review round 1 #2): df_press_use only blocks presses < 300 ms apart, so
                // a held key can queue BO_NOPOWER_RICH many times a second; say it at most once every 10 s.
                if ( !isdefined( level.df_bo_nopower_ms ) || gettime() - level.df_bo_nopower_ms >= 10000 )
                {
                    level.df_bo_nopower_ms = gettime();
                    df_say( "BO_NOPOWER_RICH" );
                }

                continue;
            }

            level thread df_bo_set( s, 1 );
            level thread df_bo_wave( s );
            df_debug_print( "DF: blackout switch " + ( s.idx + 1 ) + " ON by " + player.name + " (" + ( df_bo_on_count() ) + "/" + level.df_bo.size + ")" );
            level notify( "df_bo_check" );
        }
    }
}

df_bo_near_off( player )
{
    if ( !is_player_valid( player ) )
        return undefined;

    foreach ( s in level.df_bo )
    {
        if ( !s.on && distancesquared( player.origin, s.origin ) < 80 * 80 )
            return s;
    }

    return undefined;
}

// At every end of round while a switch is OFF, Maxis knocks one ON switch OFF again.
df_bo_round_knock()
{
    level endon( "end_game" );
    level endon( "df_bo_stop" );

    while ( true )
    {
        level waittill( "end_of_round" );

        n = df_bo_on_count();

        if ( n == 0 || n == level.df_bo.size )
            continue;

        ons = [];

        foreach ( s in level.df_bo )
        {
            if ( s.on )
                ons[ons.size] = s;
        }

        s = random( ons );
        level thread df_bo_set( s, 0 );
        df_say( "BO_OFF_MAXIS" );
        df_debug_print( "DF: blackout Maxis knocked switch " + ( s.idx + 1 ) + " OFF at the end of the round" );
    }
}

// 20 s of sprinters at a switch just turned ON (the M2 grave pattern: 2 every 2 s, cap 8 + 3 per extra player).
df_bo_wave( s )
{
    level endon( "end_game" );
    level endon( "df_bo_stop" );

    if ( !isdefined( s.spots ) )
        s.spots = df_spawn_spots_near( s.origin, 1200 );

    end_ms = gettime() + 20000;
    cap = 8 + 3 * ( getplayers().size - 1 );

    while ( gettime() < end_ms )
    {
        wait 2;

        if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 || s.spots.size == 0 )
            continue;

        if ( df_bo_wave_count( s ) >= cap )
            continue;

        for ( k = 0; k < 2; k++ )
        {
            if ( getfreeactorcount() < 1 )
                break;

            spot = random( s.spots );
            spawner = random( level.zombie_spawners );
            ai = spawn_zombie( spawner, spawner.targetname, spot );

            if ( !isdefined( ai ) )
                continue;

            if ( isdefined( spot.script_noteworthy ) && issubstr( spot.script_noteworthy, "riser_location" ) )
                ai._rise_spot = spot;
            else
                ai.spawn_point_override = spot;

            ai.df_bo_wave = s;
            ai thread df_bo_sprint();
        }
    }
}

df_bo_wave_count( s )
{
    n = 0;

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( isdefined( ai ) && isalive( ai ) && isdefined( ai.df_bo_wave ) && ai.df_bo_wave == s )
            n++;
    }

    return n;
}

df_bo_sprint()
{
    self endon( "death" );

    while ( true )
    {
        wait 0.5;

        if ( is_true( self.in_the_ground ) || is_true( self.is_traversing ) || !is_true( self.completed_emerging_into_playable_area ) )
            continue;

        if ( is_true( self.has_legs ) && isdefined( self.zombie_move_speed ) && self.zombie_move_speed != "sprint" )
            self set_zombie_run_cycle( "sprint" );

        return;
    }
}

// "!df fire blackout_off": all three OFF (a running step keeps going); "!df fire blackout_on": all three ON.
df_bo_debug_hook()
{
    level endon( "end_game" );

    while ( true )
    {
        what = level waittill_any_return( "df_debug_blackout_off", "df_debug_blackout_on" );
        df_bo_spawn();

        foreach ( s in level.df_bo )
            level thread df_bo_set( s, what == "df_debug_blackout_on" );

        df_debug_print( "DF: blackout debug: every switch " + what );
        level notify( "df_bo_check" );
    }
}
