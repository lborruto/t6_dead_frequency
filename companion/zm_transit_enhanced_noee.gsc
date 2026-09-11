/*
   This script is my attempt to fix the shortcomings of Tranzit. So things like
   the jetgun and the bus system are completely reworked with some other QoL
   improvements like the PaP door not closing after the turbine is destroyed,
   denizens needing 4 knifes to die instead of 5, and the Avogadro dropping a
   max ammo at death.

   Credits to HadiKSA for letting me use scripts from his solo EE collection,
   and to CCDeroga and teh_bandit for making them.
*/

#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_buildables;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\gametypes_zm\_hud_util;

#include maps\mp\zm_transit_sq;
#include maps\mp\zombies\_zm_unitrigger;
#include maps\mp\zombies\_zm_powerups;
#include maps\mp\zombies\_zm_zonemgr;
#include maps\mp\zombies\_zm_stats;
#include maps\mp\gametypes_zm\_globallogic_score;
#include maps\mp\zombies\_zm_spawner;
#include maps\mp\zm_transit_utility;
#include maps\mp\zombies\_zm_sidequests;
#include common_scripts\utility;

init()
{
    if ( !isdefined( level.script ) || level.script != "zm_transit" )
        return;

    if ( isdefined( level.te_active ) )
        return;

    level.te_active = 1;

    replaceFunc( maps\mp\zm_transit_sq::richtofensay, ::te_richtofensay );

    maps\mp\zombies\_zm_spawner::register_zombie_death_event_callback( ::te_jetgun_points );

    level thread te_jetgun();
    level thread te_bus();
    level thread te_tweaks();
    level thread te_richtofen_ee();
}

/* ==========================================================================
   Jet Gun
   ========================================================================== */
te_jetgun()
{
    walk_speed     = 0.90;
    sprint_speed   = 1.35;

    sprint_ticks   = 80;
    staminup_mult  = 2;
    staminup_speed = 1.00;
    refill_ticks   = 80;
    resume_frac    = 0.25;

    drop_frac      = 0.70;
    grace_ticks    = 3;
    move_min       = 40;
    damage_lock    = 10;

    drop_at        = 98;
    slow_heat      = 1;
    heat_seconds   = 7.7;
    cool_seconds   = 40;
    slow_every     = 5;
    cooldown_ticks = 1600;
    fx_interval    = 32;
    fx_height      = 2;
    fx_forward     = 12;
    fx_stop_early  = 130;
    block_trigger  = 1;

    level endon( "end_game" );

    min_sq = move_min * move_min;
    sprint_cone = 0.5;
    drop_sq = drop_frac * drop_frac;

    for ( ;; )
    {
        level.explode_overheated_jetgun = undefined;
        level.unbuild_overheated_jetgun = undefined;
        level.take_overheated_jetgun = undefined;

        if ( !isdefined( level.equipment_ignored_by_zombies ) )
            level.equipment_ignored_by_zombies = [];

        level.equipment_ignored_by_zombies["jetgun_zm"] = 1;

        if ( isdefined( level.jgx_prot ) )
        {
            level.jgx_prot.damage = -100000;
            level.jgx_prot.health = 100000;
            level.jgx_prot.maxhealth = 100000;
            level.jgx_prot.ignore_lava_damage = 1;
            level.jgx_prot.marked_for_death = undefined;

            if ( isdefined( level.destructible_equipment ) )
            {
                keep = [];

                for ( d = 0; d < level.destructible_equipment.size; d++ )
                {
                    if ( !isdefined( level.destructible_equipment[d] ) )
                        continue;

                    if ( level.destructible_equipment[d] == level.jgx_prot )
                        continue;

                    keep[keep.size] = level.destructible_equipment[d];
                }

                level.destructible_equipment = keep;
            }
        }

        if ( isdefined( level.jgx_safe_wait ) && level.jgx_safe_wait > 0 )
        {
            level.jgx_safe_wait = level.jgx_safe_wait - 1;

            if ( level.jgx_safe_wait <= 0 )
            {
                level.equipment_safe_to_drop = level.jgx_safe_fn;
                level.jgx_safe_fn = undefined;
                level.jgx_safe_wait = undefined;
            }
        }

        if ( isdefined( level.jgx_refresh ) && level.jgx_refresh > 0 )
        {
            level.jgx_refresh = level.jgx_refresh - 1;

            if ( level.jgx_refresh <= 0 )
            {
                if ( isdefined( level.jgx_stub ) )
                {
                    if ( isdefined( level.jgx_rad ) )
                        level.jgx_stub.test_radius_sq = level.jgx_rad;

                    if ( isdefined( level.jgx_pos ) )
                        level.jgx_stub.origin = level.jgx_pos;
                }

                level.jgx_stub = undefined;
                level.jgx_pos = undefined;
                level.jgx_rad = undefined;
                level.jgx_refresh = undefined;
            }
        }

        players = get_players();

        for ( i = 0; i < players.size; i++ )
        {
            player = players[i];

            if ( !isdefined( player ) || !isdefined( player.score ) )
                continue;

            if ( !isdefined( player.equipment_damage ) )
                player.equipment_damage = [];

            player.equipment_damage["jetgun_zm"] = -100000;

            if ( !isdefined( player.jgx_cooling ) )
                player.jgx_cooling = 0;

            if ( !isdefined( player.jgx_cool_left ) )
                player.jgx_cool_left = 0;

            if ( !isdefined( player.jgx_speed ) )
                player.jgx_speed = 1;

            if ( !isdefined( player.jgx_sprinting ) )
                player.jgx_sprinting = 0;

            if ( !isdefined( player.jgx_peak ) )
                player.jgx_peak = 0;

            if ( !isdefined( player.jgx_below ) )
                player.jgx_below = 0;

            if ( !isdefined( player.jgx_lock ) )
                player.jgx_lock = 0;

            has_su = 0;

            if ( player hasperk( "specialty_longersprint" ) )
                has_su = 1;

            max_stam = sprint_ticks;
            boost = 1;

            if ( has_su )
            {
                max_stam = int( sprint_ticks * staminup_mult );
                boost = staminup_speed;
            }

            if ( !isdefined( player.jgx_stam ) )
                player.jgx_stam = max_stam;

            if ( player.jgx_stam > max_stam )
                player.jgx_stam = max_stam;

            recharge = max_stam / refill_ticks;
            resume_at = max_stam * resume_frac;

            if ( !isdefined( player.jgx_hp ) )
                player.jgx_hp = player.health;

            took_damage = 0;

            if ( player.health < player.jgx_hp )
                took_damage = 1;

            player.jgx_hp = player.health;

            if ( player.jgx_lock > 0 )
                player.jgx_lock = player.jgx_lock - 1;

            holding = 0;

            if ( player getcurrentweapon() == "jetgun_zm" )
                holding = 1;

            want = 1;

            if ( !holding )
            {
                player.jgx_sprinting = 0;
                player.jgx_peak = 0;
                player.jgx_below = 0;
            }
            else
            {
                vel = player getvelocity();
                speed_sq = vel[0] * vel[0] + vel[1] * vel[1];

                moving = 0;

                if ( speed_sq > min_sq )
                    moving = 1;

                if ( moving )
                {
                    ang = player getplayerangles();
                    fwd = anglestoforward( ( 0, ang[1], 0 ) );

                    dotv = vel[0] * fwd[0] + vel[1] * fwd[1];

                    if ( dotv <= 0 )
                        moving = 0;
                    else if ( dotv * dotv < sprint_cone * sprint_cone * speed_sq )
                        moving = 0;
                }

                held = 0;

                if ( player sprintbuttonpressed() )
                    held = 1;

                ready = 0;

                if ( player.jgx_stam >= resume_at && player.jgx_stam > 0 )
                    ready = 1;

                if ( held && moving && ready && player.jgx_lock <= 0 )
                {
                    if ( !player.jgx_sprinting )
                        player.jgx_peak = speed_sq;

                    player.jgx_sprinting = 1;
                }

                if ( player.jgx_sprinting )
                {
                    if ( speed_sq > player.jgx_peak )
                        player.jgx_peak = speed_sq;

                    if ( speed_sq < player.jgx_peak * drop_sq )
                    {
                        player.jgx_below = player.jgx_below + 1;

                        if ( player.jgx_below >= grace_ticks )
                            player.jgx_sprinting = 0;
                    }
                    else
                        player.jgx_below = 0;
                }
                else
                    player.jgx_below = 0;

                if ( !moving )
                    player.jgx_sprinting = 0;

                if ( player attackbuttonpressed() )
                    player.jgx_sprinting = 0;

                if ( player adsbuttonpressed() )
                    player.jgx_sprinting = 0;

                if ( took_damage && damage_lock > 0 )
                {
                    player.jgx_sprinting = 0;
                    player.jgx_lock = damage_lock;
                }

                if ( player.jgx_sprinting )
                {
                    player.jgx_stam = player.jgx_stam - 1;

                    if ( player.jgx_stam <= 0 )
                    {
                        player.jgx_stam = 0;
                        player.jgx_sprinting = 0;
                    }
                }
                else
                {
                    player.jgx_stam = player.jgx_stam + recharge;

                    if ( player.jgx_stam > max_stam )
                        player.jgx_stam = max_stam;
                }

                if ( !player.jgx_sprinting )
                {
                    player.jgx_peak = 0;
                    player.jgx_below = 0;
                }

                if ( player.jgx_sprinting )
                    want = sprint_speed * boost;
                else
                    want = walk_speed * boost;
            }

            if ( player.jgx_speed != want )
            {
                player.jgx_speed = want;
                player setmovespeedscale( want );
            }

            if ( player.jgx_cooling )
            {
                player.jgx_cool_left = player.jgx_cool_left - 1;

                if ( !isdefined( level.jgx_stub ) )
                {
                    models = getentarray( "script_model", "classname" );

                    for ( m = 0; m < models.size; m++ )
                    {
                        if ( !isdefined( models[m].stub ) )
                            continue;

                        if ( !isdefined( models[m].stub.equipname ) )
                            continue;

                        if ( models[m].stub.equipname != "jetgun_zm" )
                            continue;

                        level.jgx_stub = models[m].stub;
                        level.jgx_prot = models[m];
                        level.jgx_found = 1;
                        models[m] notify( "stop_attracting_zombies" );

                        if ( !isdefined( level.jgx_hint ) )
                            level.jgx_hint = level.jgx_stub.hint_string;

                        if ( !isdefined( level.jgx_func ) )
                            level.jgx_func = level.jgx_stub.trigger_func;

                        level.jgx_stub.hint_string = "Jet Gun is cooling down";

                        if ( block_trigger )
                            level.jgx_stub.trigger_func = undefined;

                        if ( !isdefined( level.jgx_pos ) )
                        {
                            level.jgx_pos = models[m].origin;
                            level.jgx_ang = models[m].angles;
                        }
                        else
                        {
                            models[m].origin = level.jgx_pos;
                            models[m].angles = level.jgx_ang;
                            level.jgx_stub.origin = level.jgx_pos;
                            level.jgx_stub.angles = level.jgx_ang;
                        }

                        break;
                    }
                }

                if ( isdefined( level.jgx_prot ) && fx_interval > 0 && player.jgx_cool_left > fx_stop_early )
                {
                    if ( !isdefined( player.jgx_fx ) )
                        player.jgx_fx = 0;

                    player.jgx_fx = player.jgx_fx + 1;

                    if ( player.jgx_fx >= fx_interval )
                    {
                        player.jgx_fx = 0;

                        if ( isdefined( level._effect ) && isdefined( level._effect["jetgun_overheat"] ) )
                            playfx( level._effect["jetgun_overheat"], level.jgx_prot.origin + ( 0, 0, fx_height ) + anglestoforward( level.jgx_prot.angles ) * fx_forward );
                    }
                }

                if ( player.jgx_cool_left > 0 && player hasweapon( "jetgun_zm" ) )
                {
                    player.jetgun_overheating = 0;
                    player.jetgun_heatval = 0;
                    if ( !isdefined( level.jgx_safe_wait ) )
                        level.jgx_safe_fn = level.equipment_safe_to_drop;

                    level.equipment_safe_to_drop = undefined;
                    level.jgx_safe_wait = 4;

                    player maps\mp\zombies\_zm_equipment::equipment_drop( "jetgun_zm" );
                    level.jgx_stub = undefined;
                }

                if ( player.jgx_cool_left <= 0 )
                {
                    if ( isdefined( level.jgx_stub ) )
                    {
                        if ( isdefined( level.jgx_hint ) )
                            level.jgx_stub.hint_string = level.jgx_hint;

                        if ( isdefined( level.jgx_func ) )
                            level.jgx_stub.trigger_func = level.jgx_func;

                        level.jgx_rad = level.jgx_stub.test_radius_sq;
                        level.jgx_stub.test_radius_sq = 0;

                        if ( isdefined( level.jgx_pos ) )
                            level.jgx_stub.origin = level.jgx_pos + ( 0, 0, 9000 );

                        level.jgx_refresh = 4;
                    }

                    player.jgx_cooling = 0;
                }
            }

            if ( !player hasweapon( "jetgun_zm" ) )
                continue;

            if ( !isdefined( player.jetgun_heatval ) )
                continue;

            heat = player.jetgun_heatval;

            if ( slow_heat )
            {
                if ( !isdefined( player.jgx_heat ) )
                    player.jgx_heat = 0;

                in_hand = 0;

                if ( player getcurrentweapon() == "jetgun_zm" )
                    in_hand = 1;

                firing = 0;

                if ( in_hand && player attackbuttonpressed() && !player.jgx_cooling )
                    firing = 1;

                if ( firing )
                    player.jgx_heat = player.jgx_heat + ( drop_at / heat_seconds ) * 0.05;
                else if ( in_hand )
                    player.jgx_heat = player.jgx_heat - ( drop_at / cool_seconds ) * 0.05;

                if ( player.jgx_heat < 0 )
                    player.jgx_heat = 0;

                if ( player.jgx_heat > drop_at )
                    player.jgx_heat = drop_at;

                player setweaponoverheating( 0, player.jgx_heat );

                player.jetgun_heatval = 0;

                heat = player.jgx_heat;
            }

            if ( !player.jgx_cooling && heat >= drop_at )
            {
                player notify( "jetgun_overheated" );

                if ( isdefined( level.sq_volume ) && player istouching( level.sq_volume ) )
                {
                    if ( isdefined( level.sq_progress ) && isdefined( level.sq_progress["rich"] ) && !level.sq_progress["rich"]["A_jetgun_tower"] )
                    {
                        level.sq_progress["rich"]["A_jetgun_tower"] = 1;
                        level thread maps\mp\zm_transit_sq::richtofensay( "vox_zmba_sidequest_jet_empty_0", undefined, 0, 16 );
                        level thread maps\mp\zm_transit_sq::richtofen_sidequest_complete_check( "A_complete" );
                        level thread maps\mp\zm_transit_sq::update_sidequest_stats( "sq_transit_rich_stage_2" );

                        foreach ( sqp in get_players() )
                        {
                            if ( isdefined( sqp.score ) )
                            {
                                sqp setclientfield( "screecher_sq_lights", 1 );
                                break;
                            }
                        }

                    }
                }

                player.jetgun_heatval = 0;

                player.jgx_cooling = 1;
                player.jgx_cool_left = cooldown_ticks;
                level.jgx_stub = undefined;
                level.jgx_pos = undefined;
                level.jgx_found = undefined;

                player.jetgun_overheating = 0;
                player.jetgun_heatval = 0;

                player.jgx_heat = 0;

                if ( !isdefined( level.jgx_safe_wait ) )
                    level.jgx_safe_fn = level.equipment_safe_to_drop;

                level.equipment_safe_to_drop = undefined;
                level.jgx_safe_wait = 4;

                player maps\mp\zombies\_zm_equipment::equipment_drop( "jetgun_zm" );
            }
        }

        wait 0.05;
    }
}

/* ==========================================================================
   Bus
   ========================================================================== */
te_bus()
{
    wait_multiplier = 2;
    prompt_radius   = 80;
    prompt_text     = "Hold ^3[{+activate}]^7 to tell the driver to go";
    departing_text  = "Departing...";
    hold_ticks      = 8;
    debounce_ticks  = 60;
    call_cost       = 750;
    need_power      = 1;
    nopower_text    = "You must turn on the Power first!";
    busy_text       = "The bus is busy responding to another call";
    athere_text     = "The bus is already at your location";
    athere_dist     = 2500;
    athere_settle   = 30;
    call_timeout    = 2400;
    mute_horn       = 1;
    call_text       = "Hold ^3[{+activate}]^7 to call the bus  ^7[Cost: 750]";
    called_text     = "The bus will arrive shortly!";
    call_speed_mult = 10;
    call_near_mult  = 3;
    call_rider_mult = 3;
    kill_plow       = 1;
    near_lookahead  = 2;
    lookahead       = 3;
    slow_dist       = 2500;
    arrive_speed    = 12;
    waiting_dist    = 1200;
    panel_model     = "p6_zm_buildable_sq_transceiver";
    panel_yaw       = 0;
    panel_yaw       = 0;

    level endon( "end_game" );

    while ( !isdefined( level.busschedule ) || !isdefined( level.busschedule.destinations ) )
        wait 0.5;

    bus = getent( "the_bus", "targetname" );
    driver = getent( "bus_driver_head", "targetname" );

    stub = undefined;

    if ( isdefined( driver ) )
    {
        stub = spawnstruct();
        stub.origin = driver.origin;
        stub.angles = ( 0, 0, 0 );
        stub.script_unitrigger_type = "unitrigger_radius_use";
        stub.radius = prompt_radius;
        stub.script_height = 72;
        stub.hint_string = prompt_text;
        stub.cursor_hint = "HINT_NOICON";

        maps\mp\zombies\_zm_unitrigger::register_unitrigger( stub );
    }

    stopnames = array( "depot", "diner", "farm", "power", "town" );

    stoppos = [];
    stoppos[0] = ( -6673, 4940, -55 );
    stoppos[1] = ( -5390, -7047, -57 );
    stoppos[2] = ( 6884, -5579, -61 );
    stoppos[3] = ( 10651, 7514, -571 );
    stoppos[4] = ( 1313, 845, -61 );

    stoprise = [];
    stoprise[0] = 14;
    stoprise[1] = 30;
    stoprise[2] = 42;
    stoprise[3] = 34;
    stoprise[4] = 36;

    stopyaw = [];
    stopyaw[0] = -15;
    stopyaw[1] = 75;
    stopyaw[2] = -45;
    stopyaw[3] = -30;
    stopyaw[4] = -10;

    callstubs = [];
    callnames = [];

    for ( i = 0; i < stopnames.size; i++ )
    {
        pos = stoppos[i];

        cs = spawnstruct();
        cs.origin = pos;
        cs.angles = ( 0, 0, 0 );
        cs.script_unitrigger_type = "unitrigger_radius_use";
        cs.radius = prompt_radius;
        cs.script_height = 72;
        cs.hint_string = call_text;
        cs.cursor_hint = "HINT_NOICON";

        maps\mp\zombies\_zm_unitrigger::register_unitrigger( cs );

        if ( panel_model != "" )
        {
            m = spawn( "script_model", pos + ( 0, 0, stoprise[i] ) );
            m setmodel( panel_model );
            m.angles = ( 0, panel_yaw + stopyaw[i], 0 );
        }

        callstubs[callstubs.size] = cs;
        callnames[callnames.size] = stopnames[i];
    }

    called = "";
    called_pos = ( 0, 0, 0 );
    last_here = "";
    was_onbus = 0;
    skip_cool = 0;
    slow_sq = slow_dist * slow_dist;
    wait_sq = waiting_dist * waiting_dist;

    athere_sq = athere_dist * athere_dist;
    call_age = 0;
    busy_expired = 0;
    stopped_ticks = 0;

    cow_path = getent( "cow_catcher_path_blocker", "targetname" );

    plow_trig = getent( "trigger_plow", "targetname" );
    hatch_clips = getentarray( "hatch_clip", "targetname" );
    plow_clips = getentarray( "plow_clip", "targetname" );
    was_solid_state = 0;

    silent_ent = spawn( "script_origin", ( 0, 0, -30000 ) );
    real_automaton = undefined;
    muted = 0;

    rad_sq = prompt_radius * prompt_radius;
    cooldown = 0;
    prompt_on = 1;
    departing = 0;

    for ( ;; )
    {
        players = get_players();

        for ( i = 0; i < level.busschedule.destinations.size; i++ )
        {
            if ( isdefined( level.busschedule.destinations[i].bcx_done ) )
                continue;

            if ( !isdefined( level.busschedule.destinations[i].maxwaittimebeforeleaving ) )
                continue;

            level.busschedule.destinations[i].bcx_done = 1;
            level.busschedule.destinations[i].maxwaittimebeforeleaving = level.busschedule.destinations[i].maxwaittimebeforeleaving * wait_multiplier;
        }

        if ( cooldown > 0 )
            cooldown = cooldown - 1;

        if ( isdefined( level.the_bus ) )
            bus = level.the_bus;

        moving = 0;

        if ( isdefined( bus ) && isdefined( bus.ismoving ) && bus.ismoving )
            moving = 1;

        if ( isdefined( stub ) )
        {
            if ( moving && prompt_on )
            {
                maps\mp\zombies\_zm_unitrigger::unregister_unitrigger( stub );
                prompt_on = 0;
            }
            else if ( !moving && !prompt_on )
            {
                stub.hint_string = prompt_text;
                departing = 0;
                maps\mp\zombies\_zm_unitrigger::register_unitrigger( stub );
                prompt_on = 1;
            }

            if ( isdefined( driver ) )
                stub.origin = driver.origin;
        }

        if ( skip_cool > 0 )
            skip_cool = skip_cool - 1;

        here = "";
        nxt = "";

        if ( isdefined( bus ) && isdefined( bus.destinationindex ) && isdefined( level.busschedule.destinations[bus.destinationindex] ) )
        {
            here = level.busschedule.destinations[bus.destinationindex].name;

            ni = bus.destinationindex + 1;

            if ( ni >= level.busschedule.destinations.size )
                ni = 0;

            if ( isdefined( level.busschedule.destinations[ni] ) )
                nxt = level.busschedule.destinations[ni].name;
        }

        if ( moving )
            stopped_ticks = 0;
        else
            stopped_ticks = stopped_ticks + 1;

        if ( called != "" )
        {
            call_age = call_age + 1;

            if ( call_age > call_timeout )
                busy_expired = 1;
        }
        else
        {
            call_age = 0;
            busy_expired = 0;
        }

        for ( c = 0; c < callstubs.size; c++ )
        {
            on = 1;

            if ( need_power )
            {
                on = 0;

                if ( isdefined( level.flag ) && isdefined( level.flag["power_on"] ) && level.flag["power_on"] )
                    on = 1;
                else if ( maps\mp\zombies\_zm_power::has_local_power( callstubs[c].origin ) )
                    on = 1;
            }

            callstubs[c].bcx_on = on;

            at_here = 0;

            if ( isdefined( bus ) && !moving && stopped_ticks >= athere_settle )
            {
                if ( distancesquared( bus.origin, callstubs[c].origin ) < athere_sq )
                    at_here = 1;
            }

            want_hint = call_text;

            if ( !on )
                want_hint = nopower_text;
            else if ( called != "" && callnames[c] == called )
                want_hint = called_text;
            else if ( called != "" && !busy_expired )
                want_hint = busy_text;
            else if ( at_here )
                want_hint = athere_text;

            if ( isdefined( callstubs[c].bcx_hint ) && callstubs[c].bcx_hint == want_hint )
                continue;

            callstubs[c].bcx_hint = want_hint;
            callstubs[c].hint_string = want_hint;

            maps\mp\zombies\_zm_unitrigger::unregister_unitrigger( callstubs[c] );
            maps\mp\zombies\_zm_unitrigger::register_unitrigger( callstubs[c] );
        }

        if ( mute_horn && isdefined( level.automaton ) )
        {
            if ( !isdefined( real_automaton ) && level.automaton != silent_ent )
                real_automaton = level.automaton;

            want_mute = 0;

            if ( called != "" && !near_called )
                want_mute = 1;

            if ( want_mute && !muted )
            {
                muted = 1;
                level.automaton = silent_ent;
            }
            else if ( !want_mute && muted )
            {
                muted = 0;

                if ( isdefined( real_automaton ) )
                    level.automaton = real_automaton;
            }
        }

        near_called = 0;

        if ( called != "" && isdefined( bus ) && isdefined( bus.destinationindex ) )
        {
            for ( k = 0; k <= near_lookahead; k++ )
            {
                ni2 = bus.destinationindex + k;

                while ( ni2 >= level.busschedule.destinations.size )
                    ni2 = ni2 - level.busschedule.destinations.size;

                if ( !isdefined( level.busschedule.destinations[ni2] ) )
                    continue;

                if ( level.busschedule.destinations[ni2].name == called )
                {
                    near_called = 1;
                    break;
                }
            }
        }

        onbus = 0;

        foreach ( pl in players )
        {
            if ( !isdefined( pl.isonbus ) || !pl.isonbus )
                continue;

            onbus = 1;
            break;
        }

        boosting = 0;

        if ( called != "" && moving && isdefined( bus ) )
        {
            if ( distancesquared( bus.origin, called_pos ) > slow_sq )
                boosting = 1;
        }

        full_speed = 0;

        if ( boosting && !onbus && !near_called )
            full_speed = 1;

        if ( boosting && isdefined( bus.destinationindex ) )
        {
            dest = level.busschedule.destinations[bus.destinationindex];

            if ( isdefined( dest ) && isdefined( dest.busspeedleaving ) )
            {
                mult = call_speed_mult;

                if ( onbus )
                    mult = call_rider_mult;

                if ( near_called && mult > call_near_mult )
                    mult = call_near_mult;

                spd = dest.busspeedleaving * mult;
                bus.targetspeed = spd;
                bus setspeed( spd, 80, 80 );
            }
        }
        else if ( called != "" && moving && isdefined( bus ) )
        {
            bus.targetspeed = arrive_speed;
            bus setspeed( arrive_speed, 80, 80 );
        }

        if ( isdefined( bus ) )
        {
            skipit = 0;

            if ( called != "" && here != "" && isdefined( bus.destinationindex ) )
            {
                skipit = 1;

                for ( k = 0; k <= lookahead; k++ )
                {
                    ki = bus.destinationindex + k;

                    while ( ki >= level.busschedule.destinations.size )
                        ki = ki - level.busschedule.destinations.size;

                    if ( !isdefined( level.busschedule.destinations[ki] ) )
                        continue;

                    if ( level.busschedule.destinations[ki].name == called )
                    {
                        skipit = 0;
                        break;
                    }
                }
            }

            bus.skip_next_destination = skipit;
        }

        if ( called != "" && !moving && here != "" && here != called && skip_cool <= 0 )
        {
            bus notify( "depart_early" );
            skip_cool = debounce_ticks;
        }

        if ( onbus )
            was_onbus = 1;
        else if ( was_onbus )
        {
            was_onbus = 0;
            called = "";

            if ( isdefined( bus ) )
                bus.skip_next_destination = 0;
        }

        if ( called != "" && here != "" && ( here == called || nxt == called ) )
        {
            anyone = 0;

            foreach ( pl in players )
            {
                if ( isdefined( pl.isonbus ) && pl.isonbus )
                {
                    anyone = 1;
                    break;
                }

                if ( distancesquared( pl.origin, called_pos ) < wait_sq )
                {
                    anyone = 1;
                    break;
                }
            }

            if ( !anyone )
            {
                called = "";

                if ( isdefined( bus ) )
                    bus.skip_next_destination = 0;
            }
        }

        if ( called != "" && !moving && here == called )
        {
            called = "";
        }

        if ( called == "" && cooldown <= 0 )
        {
            for ( i = 0; i < players.size; i++ )
            {
                player = players[i];

                if ( !isdefined( player ) || !isdefined( player.score ) )
                    continue;

                if ( !is_player_valid( player ) )
                    continue;

                for ( c = 0; c < callstubs.size; c++ )
                {
                    if ( !isdefined( player.bcx_chold ) )
                        player.bcx_chold = 0;

                    if ( distancesquared( player.origin, callstubs[c].origin ) > rad_sq )
                        continue;

                    if ( !player usebuttonpressed() )
                    {
                        player.bcx_chold = 0;
                        continue;
                    }

                    player.bcx_chold = player.bcx_chold + 1;

                    if ( player.bcx_chold < hold_ticks )
                        continue;

                    player.bcx_chold = 0;

                    if ( isdefined( callstubs[c].bcx_hint ) && callstubs[c].bcx_hint != call_text )
                    {
                        player play_sound_on_ent( "no_purchase" );
                        break;
                    }

                    if ( call_cost > 0 && player.score < call_cost )
                    {
                        player play_sound_on_ent( "no_purchase" );
                        break;
                    }

                    if ( call_cost > 0 )
                    {
                        player maps\mp\zombies\_zm_score::minus_to_player_score( call_cost );
                        player play_sound_on_ent( "purchase" );
                    }

                    called = callnames[c];
                    called_pos = callstubs[c].origin;
                    cooldown = debounce_ticks;
                    call_age = 0;
                    busy_expired = 0;

                    if ( !moving )
                    {
                        bus notify( "depart_early" );
                        skip_cool = debounce_ticks;
                    }

                    break;
                }

                if ( called != "" )
                    break;
            }
        }

        if ( isdefined( bus ) && isdefined( driver ) && cooldown <= 0 && !moving && !departing )
        {
            for ( i = 0; i < players.size; i++ )
            {
                player = players[i];

                if ( !isdefined( player ) || !isdefined( player.score ) )
                    continue;

                if ( !is_player_valid( player ) )
                    continue;

                if ( !isdefined( player.bcx_hold ) )
                    player.bcx_hold = 0;

                if ( distancesquared( player.origin, driver.origin ) > rad_sq )
                {
                    player.bcx_hold = 0;
                    continue;
                }

                if ( !player usebuttonpressed() )
                {
                    player.bcx_hold = 0;
                    continue;
                }

                player.bcx_hold = player.bcx_hold + 1;

                if ( player.bcx_hold < hold_ticks )
                    continue;

                player.bcx_hold = 0;
                bus notify( "depart_early" );
                departing = 1;
                cooldown = debounce_ticks;

                if ( isdefined( stub ) )
                {
                    stub.hint_string = departing_text;
                    maps\mp\zombies\_zm_unitrigger::unregister_unitrigger( stub );
                    maps\mp\zombies\_zm_unitrigger::register_unitrigger( stub );
                }

                break;
            }
        }

        if ( isdefined( bus ) && full_speed != was_solid_state )
        {
            was_solid_state = full_speed;

            if ( full_speed )
            {
                bus notsolid();
                bus setplayercollision( 0 );

                if ( isdefined( bus.cow_catcher_blocker ) )
                {
                    bus.cow_catcher_blocker notsolid();
                    bus.cow_catcher_blocker setplayercollision( 0 );
                }

                if ( isdefined( cow_path ) )
                {
                    cow_path notsolid();
                    cow_path setplayercollision( 0 );
                }

                if ( isdefined( bus.path_blockers ) )
                {
                    for ( b = 0; b < bus.path_blockers.size; b++ )
                    {
                        if ( !isdefined( bus.path_blockers[b] ) )
                            continue;

                        bus.path_blockers[b] notsolid();
                        bus.path_blockers[b] setplayercollision( 0 );
                    }
                }

                if ( isdefined( bus.doorblockers ) )
                {
                    for ( b = 0; b < bus.doorblockers.size; b++ )
                    {
                        if ( !isdefined( bus.doorblockers[b] ) )
                            continue;

                        bus.doorblockers[b] notsolid();
                        bus.doorblockers[b] setplayercollision( 0 );
                    }
                }

                for ( b = 0; b < hatch_clips.size; b++ )
                {
                    if ( !isdefined( hatch_clips[b] ) )
                        continue;

                    hatch_clips[b] notsolid();
                    hatch_clips[b] setplayercollision( 0 );
                }

                if ( isdefined( bus.plow_clip_attached ) && bus.plow_clip_attached )
                {
                    for ( b = 0; b < plow_clips.size; b++ )
                    {
                        if ( !isdefined( plow_clips[b] ) )
                            continue;

                        plow_clips[b] notsolid();
                        plow_clips[b] setplayercollision( 0 );
                    }
                }

                if ( isdefined( plow_trig ) )
                {
                    if ( !isdefined( plow_trig.bcx_local ) )
                        plow_trig.bcx_local = bus worldtolocalcoords( plow_trig.origin );

                    plow_trig unlink();
                }
            }
            else
            {
                bus solid();
                bus setplayercollision( 1 );

                if ( isdefined( bus.cow_catcher_blocker ) )
                {
                    bus.cow_catcher_blocker solid();
                    bus.cow_catcher_blocker setplayercollision( 1 );
                }

                if ( isdefined( cow_path ) )
                {
                    cow_path solid();
                    cow_path setplayercollision( 1 );
                }

                if ( isdefined( bus.path_blockers ) )
                {
                    for ( b = 0; b < bus.path_blockers.size; b++ )
                    {
                        if ( !isdefined( bus.path_blockers[b] ) )
                            continue;

                        bus.path_blockers[b] solid();
                        bus.path_blockers[b] setplayercollision( 1 );
                    }
                }

                if ( isdefined( bus.plow_clip_attached ) && bus.plow_clip_attached )
                {
                    for ( b = 0; b < plow_clips.size; b++ )
                    {
                        if ( !isdefined( plow_clips[b] ) )
                            continue;

                        plow_clips[b] solid();
                        plow_clips[b] setplayercollision( 1 );
                    }
                }

                if ( isdefined( bus.doorblockers ) )
                {
                    for ( b = 0; b < bus.doorblockers.size; b++ )
                    {
                        if ( !isdefined( bus.doorblockers[b] ) )
                            continue;

                        bus.doorblockers[b] setplayercollision( 1 );
                    }
                }

                for ( b = 0; b < hatch_clips.size; b++ )
                {
                    if ( !isdefined( hatch_clips[b] ) )
                        continue;

                    hatch_clips[b] solid();
                    hatch_clips[b] setplayercollision( 1 );
                }

                if ( isdefined( plow_trig ) && isdefined( plow_trig.bcx_local ) )
                    plow_trig linkto( bus, "", plow_trig.bcx_local, ( 0, 0, 0 ) );
            }
        }

        if ( full_speed && isdefined( bus ) && isdefined( plow_trig ) )
            plow_trig.origin = bus.origin - ( 0, 0, 10000 );

        wait 0.05;
    }
}

/* ==========================================================================
   QoL improvements
   ========================================================================== */
te_tweaks()
{
    global_turbine_doors = 1;
    keep_local_target    = "lab_secret_hatch";
    avogadro_drop        = "full_ammo";
    denizen_knifes       = 4;
    flee_when_reviving   = 1;
    pap_door_stays_open  = 1;
    pap_door_target      = "lab_secret_hatch";

    level endon( "end_game" );

    if ( global_turbine_doors )
        level.power_local_doors_globally = 1;

    avo_out = 0;

    if ( flee_when_reviving )
    {
        while ( !isdefined( level.screecher_should_runaway ) )
            wait 0.5;

        level.tw_stock_runaway = level.screecher_should_runaway;
        level.screecher_should_runaway = ::tw_screecher_should_runaway;
    }

    for ( ;; )
    {
        if ( denizen_knifes > 0 )
        {
            foreach ( pl in get_players() )
            {
                if ( !isdefined( pl.screecher ) )
                    continue;

                if ( !isdefined( pl.screecher.player_score ) )
                    continue;

                preload = 30 - 6;
                after_prev = ( denizen_knifes - 1 ) * 6;

                if ( pl.screecher.player_score >= after_prev && pl.screecher.player_score < preload )
                    pl.screecher.player_score = preload;
            }
        }

        if ( avogadro_drop != "" )
        {
            now_out = 0;

            if ( isdefined( level.avogadro ) && isdefined( level.avogadro.state ) )
            {
                st_a = level.avogadro.state;

                if ( st_a != "cloud" && st_a != "chamber" && st_a != "wait_for_player" && st_a != "exiting" )
                    now_out = 1;
            }

            if ( !now_out && avo_out && isdefined( level.avogadro ) && isdefined( level.avogadro.origin ) )
                level maps\mp\zombies\_zm_powerups::specific_powerup_drop( avogadro_drop, level.avogadro.origin );

            avo_out = now_out;
        }

        if ( global_turbine_doors )
            level.power_local_doors_globally = 1;

        if ( keep_local_target != "" && isdefined( level.powered_items ) )
        {
            for ( i = 0; i < level.powered_items.size; i++ )
            {
                pw = level.powered_items[i];

                if ( !isdefined( pw ) || !isdefined( pw.target ) )
                    continue;

                if ( !isdefined( pw.target.target ) )
                    continue;

                if ( pw.target.target != keep_local_target )
                    continue;

                pw.power_sources = 1;
            }
        }

        if ( pap_door_stays_open && isdefined( level.powered_items ) )
        {
            for ( n = 0; n < level.powered_items.size; n++ )
            {
                pw = level.powered_items[n];

                if ( !isdefined( pw ) || !isdefined( pw.target ) )
                    continue;

                if ( !isdefined( pw.target.target ) )
                    continue;

                if ( pw.target.target != pap_door_target )
                    continue;

                open = 0;

                if ( isdefined( pw.target.local_power_on ) && pw.target.local_power_on )
                    open = 1;

                if ( isdefined( pw.target.power_on ) && pw.target.power_on )
                    open = 1;

                if ( isdefined( pw.power ) && pw.power )
                    open = 1;

                if ( !open )
                    continue;

                pw.powered_count = 100;
                pw.power = 1;
            }
        }

        wait 0.05;
    }
}

tw_screecher_should_runaway( player )
{
    if ( isdefined( player.is_reviving_any ) && player.is_reviving_any > 0 )
        return true;

    if ( isdefined( level.tw_stock_runaway ) )
        return self [[ level.tw_stock_runaway ]]( player );

    return false;
}

/* ==========================================================================
   Richtofen easter egg
   ========================================================================== */
te_richtofen_ee()
{
	thread rico_richtofen_sidequest_c();
	thread rico_screecher_light_on_sq();
}

rico_richtofen_sidequest_c()
{
	for (;;)
	{
		level waittill( "safety_light_power_off" );
		thread rico_safety_light_power_off();
	}
}

rico_screecher_light_on_sq()
{
	for (;;)
	{
		level waittill( "safety_light_power_on" );
		thread rico_safety_light_power_on();
	}
}

rico_safety_light_power_off()
{
	waittillframeend;

	if ( getPlayers().size == 1 && level.sq_progress["rich"]["C_screecher_light"] == 1 )
		level.sq_progress["rich"]["C_screecher_light"] += 2;
}

rico_safety_light_power_on()
{
	waittillframeend;

	if ( getPlayers().size == 1 && level.sq_progress["rich"]["C_screecher_light"] == 1 )
		level.sq_progress["rich"]["C_screecher_light"]++;
}

te_richtofensay( vox_line, intro, ignore_power_state, time )
{
    level endon( "end_game" );
    level endon( "intermission" );

    if ( vox_line == "vox_zmba_sidequest_jet_low_0" )
        return;

    if ( isdefined( level.intermission ) && level.intermission )
        return;

    if ( isdefined( level.richcompleted ) && level.richcompleted )
        return;

    
    if ( vox_line == "vox_zmba_sidequest_4emp_mag_0" )
    {
        while ( isdefined( level.richtofen_talking_to_samuel ) && level.richtofen_talking_to_samuel )
            wait 1;

        if ( isdefined( level.rich_sq_player ) && is_player_valid( level.rich_sq_player ) )
            level.rich_sq_player playsoundtoplayer( vox_line, level.rich_sq_player );

        return;
    }

    level endon( "richtofen_c_complete" );

    if ( !isdefined( time ) )
        time = 45;

    
    waited = 0;

    while ( isdefined( level.richtofen_talking_to_samuel ) && level.richtofen_talking_to_samuel )
        wait 1;

    while ( !( isdefined( level.richtofen_sq_intro_said ) && level.richtofen_sq_intro_said ) && waited < 15 )
    {
        waited++;
        wait 1;
    }

    while ( isdefined( level.richtofen_talking_to_samuel ) && level.richtofen_talking_to_samuel )
        wait 1;

    if ( isdefined( level.rich_sq_player ) && is_player_valid( level.rich_sq_player ) )
    {
        powered = 0;

        if ( isdefined( level.flag ) && isdefined( level.flag["power_on"] ) && level.flag["power_on"] )
        {
            if ( isdefined( level.flag["switches_on"] ) && level.flag["switches_on"] )
                powered = 1;
        }

        if ( !powered && !( isdefined( ignore_power_state ) && ignore_power_state ) )
            return;

        level.rich_sq_player playsoundtoplayer( vox_line, level.rich_sq_player );

        if ( !( isdefined( level.richtofen_talking_to_samuel ) && level.richtofen_talking_to_samuel ) )
            level thread maps\mp\zm_transit_sq::richtofen_talking( time );
    }
}

te_jetgun_points()
{
    if ( !isdefined( self.damageweapon ) || self.damageweapon != "jetgun_zm" )
        return;

    if ( !isdefined( self.attacker ) || !isplayer( self.attacker ) )
        return;

    if ( isdefined( self.nuked ) && self.nuked )
        return;

    points = 50;

    if ( isdefined( level.zombie_vars[self.attacker.team]["zombie_point_scalar"] ) )
        points = points * level.zombie_vars[self.attacker.team]["zombie_point_scalar"];

    self.attacker maps\mp\zombies\_zm_score::add_to_player_score( points );
}
