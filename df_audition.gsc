// Dead Frequency - df_audition.gsc
// In-game audition of the game's own fx and sounds, so the owner picks by eye and ear instead of by name
// (owner 2026-09-11: "make me the list of sounds and effects and I'll tell you").
//   !df fx  <n|next|prev|list|off|name>   plays server fx n of the curated list for 8 s where you aim, prints its name
//   !df snd <n|next|prev|list|alias>       plays sound n of the curated list to you, prints its name
// Every fx key below is registered server-side by a vanilla TranZit / core script (tools/assets/fx_aliases_zm_transit.txt,
// .gsc rows); every alias is in the TranZit banks (tools/assets/soundbank, lint_sounds.pl). The full playable sound
// board with durations and ranges is the Sound Picker page (tools/pickers/gen_wizard_snd.pl).
#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_coords;

// ---------------------------------------------------------------------------------------------- fx ----
// Curated: glows, lights, sparks, fire, lava, power, storm, beams, trails, power-up rings, dust. Weapon, gore,
// wall-buy and view-model fx left out.
df_aud_fx_list()
{
    l = [];
    // lights and glows
    l[l.size] = "fx_zmb_tranzit_key_glint";
    l[l.size] = "fx_zmb_tranzit_light_glow";
    l[l.size] = "fx_zmb_tranzit_light_glow_xsm";
    l[l.size] = "fx_zmb_tranzit_light_glow_fog";
    l[l.size] = "fx_zmb_tranzit_light_bulb_xsm";
    l[l.size] = "fx_zmb_tranzit_light_safety";
    l[l.size] = "fx_zmb_tranzit_light_safety_max";
    l[l.size] = "fx_zmb_tranzit_light_safety_ric";
    l[l.size] = "fx_zmb_tranzit_light_safety_off";
    l[l.size] = "fx_zmb_tranzit_light_street_tinhat";
    l[l.size] = "fx_zmb_tranzit_street_lamp";
    l[l.size] = "fx_zmb_tranzit_light_desklamp";
    l[l.size] = "fx_zmb_tranzit_light_depot_cans";
    l[l.size] = "fx_zmb_tranzit_light_town_cans";
    l[l.size] = "fx_zmb_tranzit_light_town_cans_sm";
    l[l.size] = "fx_zmb_tranzit_truck_light";
    l[l.size] = "fx_zmb_tranzit_flourescent_glow";
    l[l.size] = "fx_zmb_tranzit_flourescent_glow_lg";
    l[l.size] = "fx_zmb_tranzit_flourescent_dbl_glow";
    l[l.size] = "fx_zmb_tranzit_flourescent_flicker";
    l[l.size] = "fx_zmb_tranzit_bar_glow";
    l[l.size] = "fx_zmb_tranzit_depot_map_flicker";
    l[l.size] = "fx_zmb_tranzit_bowling_sign_fog";
    l[l.size] = "chest_light";
    l[l.size] = "lght_marker";
    l[l.size] = "lght_marker_flare";
    l[l.size] = "mc_towerlight";
    l[l.size] = "mc_trafficlight";
    l[l.size] = "zapper_light_ready";
    l[l.size] = "zapper_light_notready";
    l[l.size] = "revive_light";
    l[l.size] = "revive_light_flicker";
    l[l.size] = "jugger_light";
    l[l.size] = "sleight_light";
    l[l.size] = "deadshot_light";
    l[l.size] = "monkey_glow";
    l[l.size] = "fx_brakelight";
    l[l.size] = "fx_emergencylight";
    l[l.size] = "fx_headlight";
    // power-up rings and grabs
    l[l.size] = "powerup_on";
    l[l.size] = "powerup_on_red";
    l[l.size] = "powerup_on_caution";
    l[l.size] = "powerup_on_solo";
    l[l.size] = "powerup_off";
    l[l.size] = "powerup_grabbed";
    l[l.size] = "powerup_grabbed_red";
    l[l.size] = "powerup_grabbed_caution";
    l[l.size] = "powerup_grabbed_solo";
    l[l.size] = "powerup_grabbed_wave";
    l[l.size] = "powerup_grabbed_wave_red";
    l[l.size] = "upgrade_aquired";
    l[l.size] = "packapunch_fx";
    // sparks and electricity
    l[l.size] = "fx_zmb_tranzit_spark_blue_lg_os";
    l[l.size] = "fx_zmb_tranzit_spark_blue_lg_loop";
    l[l.size] = "fx_zmb_tranzit_spark_blue_sm_loop";
    l[l.size] = "fx_zmb_tranzit_spark_ext_runner";
    l[l.size] = "fx_zmb_tranzit_spark_int_runner";
    l[l.size] = "switch_sparks";
    l[l.size] = "elec_sm";
    l[l.size] = "elec_md";
    l[l.size] = "elec_torso";
    l[l.size] = "etrap_on";
    l[l.size] = "tesla_shock";
    l[l.size] = "tesla_shock_secondary";
    l[l.size] = "electric_cherry_reload_small";
    l[l.size] = "electric_cherry_reload_medium";
    l[l.size] = "electric_cherry_reload_large";
    l[l.size] = "electric_cherry_explode";
    l[l.size] = "fx_zmb_tranzit_transformer_on";
    l[l.size] = "fx_zmb_tranzit_power_on";
    l[l.size] = "fx_zmb_tranzit_power_pulse";
    l[l.size] = "fx_zmb_tranzit_power_rising";
    // storm, lightning, Avogadro
    l[l.size] = "sq_common_lightning";
    l[l.size] = "lightning_dog_spawn";
    l[l.size] = "fx_zmb_avog_storm";
    l[l.size] = "fx_zmb_avog_storm_low";
    l[l.size] = "avogadro_ascend";
    l[l.size] = "avogadro_descend";
    l[l.size] = "avogadro_phasing";
    l[l.size] = "avogadro_phase_trail";
    l[l.size] = "avogadro_health_full";
    l[l.size] = "avogadro_health_half";
    l[l.size] = "avogadro_health_low";
    l[l.size] = "avogadro_bolt";
    // fire, lava, smoke, ash
    l[l.size] = "fx_zmb_tranzit_fire_med";
    l[l.size] = "fx_zmb_tranzit_fire_lrg";
    l[l.size] = "ambush_bus_fire";
    l[l.size] = "lava_burning";
    l[l.size] = "bus_lava_driving";
    l[l.size] = "fx_zmb_lava_50x50_sm";
    l[l.size] = "fx_zmb_lava_100x100";
    l[l.size] = "fx_zmb_lava_crevice_glow_50";
    l[l.size] = "fx_zmb_lava_crevice_glow_100";
    l[l.size] = "fx_zmb_lava_crevice_smoke_100";
    l[l.size] = "fx_zmb_lava_smoke_pit";
    l[l.size] = "fx_zmb_lava_smoke_tall";
    l[l.size] = "fx_zmb_tranzit_lava_distort_sm";
    l[l.size] = "fx_zmb_tranzit_smk_column_lrg";
    l[l.size] = "fx_zmb_tranzit_smk_interior_md";
    l[l.size] = "fx_zmb_ash_rising_md";
    l[l.size] = "fx_zmb_ash_windy_heavy_sm";
    l[l.size] = "fx_zmb_ash_windy_heavy_md";
    l[l.size] = "fx_zmb_ash_ember_1000x1000";
    l[l.size] = "dog_trail_fire";
    l[l.size] = "dog_trail_ash";
    l[l.size] = "def_explosion";
    // beams
    l[l.size] = "spotlight_beam";
    l[l.size] = "fx_zmb_tranzit_god_ray_interior_long";
    l[l.size] = "fx_zmb_tranzit_god_ray_interior_med";
    l[l.size] = "fx_zmb_tranzit_god_ray_pwr_station";
    l[l.size] = "fx_zmb_tranzit_god_ray_depot_cool";
    l[l.size] = "fx_zmb_tranzit_god_ray_depot_warm";
    l[l.size] = "fx_zmb_tranzit_god_ray_short_warm";
    l[l.size] = "fx_zmb_tranzit_god_ray_tunnel_warm";
    l[l.size] = "fx_zmb_tranzit_god_ray_vault";
    // trails, clouds, dust, portals
    l[l.size] = "richtofen_sparks";
    l[l.size] = "maxis_sparks";
    l[l.size] = "fw_trail";
    l[l.size] = "fw_pre_burst";
    l[l.size] = "fw_burst";
    l[l.size] = "fw_impact";
    l[l.size] = "spawn_cloud";
    l[l.size] = "poltergeist";
    l[l.size] = "butterflies";
    l[l.size] = "building_dust";
    l[l.size] = "rise_burst";
    l[l.size] = "rise_billow";
    l[l.size] = "screecher_spawn_a";
    l[l.size] = "screecher_spawn_b";
    l[l.size] = "screecher_hole";
    l[l.size] = "screecher_vortex";
    l[l.size] = "screecher_death";
    l[l.size] = "grenade_samantha_steal";
    l[l.size] = "turbine_on";
    l[l.size] = "turbine_low";
    l[l.size] = "turbine_med";
    l[l.size] = "turbine_aoe";
    l[l.size] = "jetgun_vortex";
    l[l.size] = "thundergun_smoke_cloud";
    l[l.size] = "fx_zmb_fog_closet";
    l[l.size] = "fx_zmb_fog_low_300x300";
    l[l.size] = "fx_zbus_trans_fog";
    return l;
}

// ------------------------------------------------------------------------------------------- sounds ----
// The same set as the sound board (short cues, tones, fire, electric, hums), in the board's order.
df_aud_snd_list()
{
    l = [];
    l[l.size] = "zmb_no_cha_ching";
    l[l.size] = "evt_perk_deny";
    l[l.size] = "zmb_sq_navcard_fail";
    l[l.size] = "zmb_perks_broken_jingle";
    l[l.size] = "evt_player_swiped";
    l[l.size] = "zmb_buildable_piece_add";
    l[l.size] = "zmb_perks_packa_knuckle_1";
    l[l.size] = "zmb_perks_packa_knuckle_0";
    l[l.size] = "zmb_screecher_impact";
    l[l.size] = "evt_player_final_hit";
    l[l.size] = "zmb_turret_down";
    l[l.size] = "zmb_spawn_powerup";
    l[l.size] = "zmb_tombstone_spawn";
    l[l.size] = "zmb_perks_packa_ticktock";
    l[l.size] = "zmb_power_rise_start";
    l[l.size] = "zmb_explo_sweet";
    l[l.size] = "zmb_perks_packa_deny";
    l[l.size] = "zmb_turbine_wind";
    l[l.size] = "zmb_zombie_arc";
    l[l.size] = "zmb_zombie_end_inert";
    l[l.size] = "zmb_sq_navcard_success";
    l[l.size] = "zmb_powerup_grabbed";
    l[l.size] = "zmb_tombstone_grab";
    l[l.size] = "evt_fridge_locker_close";
    l[l.size] = "zmb_switch_flip";
    l[l.size] = "zmb_meteor_activate";
    l[l.size] = "evt_electrical_surge";
    l[l.size] = "evt_fridge_locker_open";
    l[l.size] = "zmb_avogadro_warp_in";
    l[l.size] = "zmb_box_poof";
    l[l.size] = "evt_nuke_flash";
    l[l.size] = "zmb_phdflop_explo";
    l[l.size] = "zmb_buildable_complete";
    l[l.size] = "zmb_screecher_emerge";
    l[l.size] = "zmb_turret_startup";
    l[l.size] = "zmb_avogadro_warp_out";
    l[l.size] = "zmb_power_rise_stop";
    l[l.size] = "evt_nuked";
    l[l.size] = "zmb_screecher_bury";
    l[l.size] = "zmb_insta_kill";
    l[l.size] = "zmb_box_poof_land";
    l[l.size] = "zmb_explo";
    l[l.size] = "zmb_turbine_pulse";
    l[l.size] = "zmb_pwr_rm_bolt_sml";
    l[l.size] = "zmb_cha_ching";
    l[l.size] = "zmb_cha_ching_loud";
    l[l.size] = "zmb_screecher_portal_arrive";
    l[l.size] = "zmb_perks_packa_ready";
    l[l.size] = "zmb_screecher_portal_spawn";
    l[l.size] = "zmb_screecher_portal_warp_2d";
    l[l.size] = "zmb_fire_loop";
    l[l.size] = "zmb_bus_emp_shutdown";
    l[l.size] = "zmb_pwr_rm_bolt_lrg";
    l[l.size] = "zmb_whoosh";
    l[l.size] = "zmb_screecher_portal_end";
    l[l.size] = "zmb_burn_loop";
    l[l.size] = "mus_perks_jugganog_sting";
    l[l.size] = "zmb_perks_power_on";
    l[l.size] = "zmb_sizzle";
    l[l.size] = "zmb_power_rise_loop";
    l[l.size] = "zmb_screecher_portal_loop";
    l[l.size] = "zmb_lightning_l";
    l[l.size] = "evt_bridge_collapse_start";
    l[l.size] = "zmb_phdflop_explo_more";
    l[l.size] = "zmb_meteor_loop";
    l[l.size] = "zmb_power_on_loop";
    l[l.size] = "zmb_avogadro_loop";
    l[l.size] = "zmb_turbine_loop";
    l[l.size] = "zmb_lava_smallfire";
    l[l.size] = "amb_church_bell";
    l[l.size] = "zmb_spawn_powerup_loop";
    l[l.size] = "zmb_tombstone_looper";
    l[l.size] = "zmb_tombstone_timer_count";
    l[l.size] = "zmb_buildable_pickup";
    l[l.size] = "zmb_turbine_explo";
    l[l.size] = "uin_alert_lockon";
    return l;
}

// --------------------------------------------------------------------------------------- commands ----
// self = the player who typed. Resolves n / next / prev / a name against `list`; undefined = print the list.
df_aud_resolve( arg, list, last )
{
    if ( arg == "next" )
    {
        if ( !isdefined( last ) )
            return 0;

        return ( last + 1 ) % list.size;
    }

    if ( arg == "prev" )
    {
        if ( !isdefined( last ) )
            return list.size - 1;

        return ( last + list.size - 1 ) % list.size;
    }

    if ( df_aud_is_number( arg ) )
    {
        n = int( arg );

        if ( n < 0 || n >= list.size )
            return undefined;

        return n;
    }

    for ( i = 0; i < list.size; i++ )
    {
        if ( list[i] == arg )
            return i;
    }

    return undefined;
}

df_aud_is_number( s )
{
    if ( !isdefined( s ) || s.size == 0 )
        return 0;

    for ( i = 0; i < s.size; i++ )
    {
        c = s[i];

        if ( c != "0" && c != "1" && c != "2" && c != "3" && c != "4" && c != "5" && c != "6" && c != "7" && c != "8" && c != "9" )
            return 0;
    }

    return 1;
}

// Prints the list ten names a line (the console wraps long lines).
df_aud_print_list( list, label )
{
    self df_out( label + ": " + list.size + " entries (number = the n of !df " + label + " <n>)" );
    line = "";

    for ( i = 0; i < list.size; i++ )
    {
        line = line + i + " " + list[i] + "   ";

        if ( ( i % 6 ) == 5 || i == list.size - 1 )
        {
            self df_out( line );
            line = "";
            wait 0.05;
        }
    }
}

// !df fx ...  (self = player)
df_aud_fx( arg )
{
    list = df_aud_fx_list();

    if ( !isdefined( arg ) || arg == "list" )
    {
        self thread df_aud_print_list( list, "fx" );
        return;
    }

    // the grid: every effect at once (!df fx grid = the small and medium ones, gridbig = the huge ones, gridoff)
    if ( arg == "grid" || arg == "gridbig" )
    {
        self df_aud_grid( arg == "gridbig" );
        return;
    }

    if ( arg == "gridnext" || arg == "gridprev" )
    {
        self df_aud_grid_turn( arg == "gridnext" );
        return;
    }

    if ( arg == "gridoff" )
    {
        df_aud_grid_stop();
        self df_out( "fx grid removed" );
        return;
    }

    df_aud_fx_stop();

    if ( arg == "off" )
    {
        df_aud_grid_stop();
        self df_out( "fx audition stopped" );
        return;
    }

    idx = df_aud_resolve( arg, list, level.df_aud_fx_idx );

    if ( !isdefined( idx ) )
    {
        // any registered key, even outside the curated list
        if ( isdefined( level._effect[arg] ) )
        {
            df_aud_fx_show( arg, -1 );
            return;
        }

        self df_out( "fx: unknown '" + arg + "' (not in the list, not a registered server fx). !df fx list | grid | gridbig | gridoff" );
        return;
    }

    level.df_aud_fx_idx = idx;
    df_aud_fx_show( list[idx], idx );
}

// The fx at the point you aim at (ground hit within 300, else 150 ahead), for 8 s or until the next one.
df_aud_fx_show( name, idx )
{
    if ( !isdefined( level._effect[name] ) )
    {
        self df_out( "[FX " + idx + "] " + name + ": registered by no server script here, nothing to play" );
        return;
    }

    eye = self geteye();
    fwd = anglestoforward( self getplayerangles() );
    trace = bullettrace( eye, eye + fwd * 300, 0, self );
    pos = eye + fwd * 150;

    if ( isdefined( trace["fraction"] ) && trace["fraction"] < 1 )
        pos = trace["position"] + trace["normal"] * 4;

    level.df_aud_fx_ent = df_fx_loop( name, pos );
    level thread df_aud_fx_auto_stop( level.df_aud_fx_ent, 8 );
    tag = "[FX " + idx + "/" + df_aud_fx_list().size + "] ";

    if ( idx < 0 )
        tag = "[FX] ";

    self df_out( tag + name + "  at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) + "  (8 s; !df fx next | prev | <n> | <name> | list | off)" );
}

df_aud_fx_stop()
{
    if ( isdefined( level.df_aud_fx_ent ) )
        df_fx_stop( level.df_aud_fx_ent );

    level.df_aud_fx_ent = undefined;
}

df_aud_fx_auto_stop( ent, seconds )
{
    level endon( "end_game" );
    wait( seconds );

    if ( isdefined( ent ) && isdefined( level.df_aud_fx_ent ) && level.df_aud_fx_ent == ent )
        df_aud_fx_stop();
}

// !df snd ...  (self = player). Played to you at your own position = full volume, like the mod's cues.
df_aud_snd( arg )
{
    list = df_aud_snd_list();

    if ( !isdefined( arg ) || arg == "list" )
    {
        self thread df_aud_print_list( list, "snd" );
        return;
    }

    idx = df_aud_resolve( arg, list, level.df_aud_snd_idx );
    name = arg;
    tag = "[SND] ";

    if ( isdefined( idx ) )
    {
        level.df_aud_snd_idx = idx;
        name = list[idx];
        tag = "[SND " + idx + "/" + list.size + "] ";
    }

    self playsoundtoplayer( name, self );
    self df_out( tag + name + "  (!df snd next | prev | <n> | <alias> | list; silence = the alias is in no bank)" );
}

// ---------------------------------------------------------------------------------------------- grid ----
// !df fx grid: every curated effect spawned at once, 8 per row, 110 apart, starting 150 in front of the player,
// each on a small pedestal (the beacon model). One-shot effects re-fire every 2 s so they are seen. Stand within
// 70 of a pedestal: the bottom-screen label reads "[n] name" (n = the !df fx number), and the console prints it
// once. The huge ones (fog, storms, columns, rays, fireworks) are a separate grid: !df fx gridbig, 5 per row,
// 400 apart. !df fx gridoff (or !df fx off) removes everything. Owner 2026-09-11.
df_aud_fx_is_big( n )
{
    return issubstr( n, "fog" ) || issubstr( n, "storm" ) || issubstr( n, "smk_column" ) || issubstr( n, "god_ray" )
        || issubstr( n, "spotlight_beam" ) || issubstr( n, "fw_" ) || issubstr( n, "spawn_cloud" ) || issubstr( n, "thundergun" )
        || issubstr( n, "jetgun" ) || issubstr( n, "lava_100" ) || issubstr( n, "ash_ember" ) || issubstr( n, "smoke_tall" )
        || issubstr( n, "smoke_pit" ) || issubstr( n, "lava_creek" ) || issubstr( n, "lava_river" ) || issubstr( n, "transformer_on" )
        || issubstr( n, "tranzit_power_on" ) || issubstr( n, "lightning" ) || issubstr( n, "avogadro_" ) || issubstr( n, "turbine_" );
}

// One-shot by name (same guess as the Effect Picker page): played once, so the grid re-fires it every 2 s.
df_aud_fx_is_oneshot( n )
{
    return issubstr( n, "_os" ) || issubstr( n, "burst" ) || issubstr( n, "impact" ) || issubstr( n, "explo" )
        || issubstr( n, "grabbed" ) || issubstr( n, "lightning" ) || issubstr( n, "flash" ) || issubstr( n, "shock" )
        || issubstr( n, "poof" ) || issubstr( n, "spawn_a" ) || issubstr( n, "spawn_b" ) || issubstr( n, "spawn_c" )
        || issubstr( n, "death" ) || issubstr( n, "dust" ) || issubstr( n, "descend" ) || issubstr( n, "ascend" )
        || issubstr( n, "bust" ) || issubstr( n, "switch_sparks" ) || issubstr( n, "def_explosion" ) || issubstr( n, "cherry_explode" )
        || issubstr( n, "knockdown" ) || issubstr( n, "upgrade_aquired" ) || issubstr( n, "packapunch_fx" ) || issubstr( n, "steal" );
}

// self = player. Builds the page list (the small or the big effects) and shows page 0 in front of the player.
// Pages (owner 2026-09-11): 24 effects at once (big: 8) is what the client keeps alive; the full 130 vanished.
df_aud_grid( big )
{
    df_aud_grid_stop();
    df_aud_fx_stop();

    list = df_aud_fx_list();
    level.df_aud_grid_names = [];
    level.df_aud_grid_idx = [];

    for ( i = 0; i < list.size; i++ )
    {
        if ( df_aud_fx_is_big( list[i] ) != big || !isdefined( level._effect[list[i]] ) )
            continue;

        level.df_aud_grid_names[level.df_aud_grid_names.size] = list[i];
        level.df_aud_grid_idx[level.df_aud_grid_idx.size] = i;
    }

    level.df_aud_grid_big = big;
    level.df_aud_grid_page = 0;
    level.df_aud_grid_fwd = anglestoforward( ( 0, self.angles[1], 0 ) );
    level.df_aud_grid_right = anglestoright( ( 0, self.angles[1], 0 ) );
    level.df_aud_grid_origin = self.origin;
    self df_aud_grid_show_page();
}

// Next / previous page, same spot and facing as the first `grid`.
df_aud_grid_turn( forward )
{
    if ( !isdefined( level.df_aud_grid_names ) || level.df_aud_grid_names.size == 0 )
    {
        self df_out( "no grid: !df fx grid first" );
        return;
    }

    per = df_aud_grid_per_page();
    pages = int( ( level.df_aud_grid_names.size + per - 1 ) / per );

    if ( forward )
        level.df_aud_grid_page = ( level.df_aud_grid_page + 1 ) % pages;
    else
        level.df_aud_grid_page = ( level.df_aud_grid_page + pages - 1 ) % pages;

    self df_aud_grid_show_page();
}

df_aud_grid_per_page()
{
    if ( is_true( level.df_aud_grid_big ) )
        return 6;

    return 16;
}

// self = player. Spawns the current page: cols per row, spacing apart, from the stored origin and facing.
df_aud_grid_show_page()
{
    df_aud_grid_clear_cells();

    cols = 8;
    spacing = 110;

    if ( is_true( level.df_aud_grid_big ) )
    {
        cols = 4;
        spacing = 400;
    }

    per = df_aud_grid_per_page();
    pages = int( ( level.df_aud_grid_names.size + per - 1 ) / per );
    first = level.df_aud_grid_page * per;
    fwd = level.df_aud_grid_fwd;
    right = level.df_aud_grid_right;
    base = level.df_aud_grid_origin + fwd * 150 - right * ( spacing * ( cols - 1 ) / 2 );

    level.df_aud_grid = [];
    n = 0;

    for ( k = first; k < first + per && k < level.df_aud_grid_names.size; k++ )
    {
        name = level.df_aud_grid_names[k];
        i = level.df_aud_grid_idx[k];
        r = int( n / cols );
        c = n % cols;
        n++;
        pos = base + fwd * ( spacing * r ) + right * ( spacing * c );
        ground = df_ground( pos + ( 0, 0, 40 ) );

        if ( isdefined( ground ) )
            pos = ground;

        cell = spawnstruct();
        cell.name = name;
        cell.idx = i;
        cell.pos = pos + ( 0, 0, 12 );
        cell.pedestal = spawn( "script_model", pos );
        cell.pedestal setmodel( df_model( "beacon" ) );

        if ( df_aud_fx_is_oneshot( name ) )
            level thread df_aud_grid_oneshot( cell );
        else
            cell.ent = df_fx_loop( name, cell.pos );

        level.df_aud_grid[level.df_aud_grid.size] = cell;
    }

    level thread df_aud_grid_refresh();
    level thread df_aud_grid_label();
    self df_out( "fx grid page " + ( level.df_aud_grid_page + 1 ) + "/" + pages + ": " + n + " effects, " + cols + " per row, " + spacing + " apart. Walk to a pedestal: the label names it. !df fx gridnext | gridprev | gridoff" );
    self thread df_aud_grid_legend( cols );
}

// The client drops looping effects on entities after a while (owner 2026-09-11, even 24 at once): every 6 s each
// loop cell is re-spawned so a culled effect is back within seconds. One-shots already re-fire on their own.
df_aud_grid_refresh()
{
    level endon( "end_game" );
    level endon( "df_aud_grid_stop" );

    while ( true )
    {
        wait 6;

        foreach ( cell in level.df_aud_grid )
        {
            if ( !isdefined( cell.ent ) )
                continue;

            df_fx_stop( cell.ent );
            cell.ent = df_fx_loop( cell.name, cell.pos );
            wait 0.05;
        }
    }
}

// Removes the cells of the current page only (the page list stays).
df_aud_grid_clear_cells()
{
    level notify( "df_aud_grid_stop" );

    if ( isdefined( level.df_aud_grid ) )
    {
        foreach ( cell in level.df_aud_grid )
        {
            df_fx_stop( cell.ent );

            if ( isdefined( cell.pedestal ) )
                cell.pedestal delete();
        }
    }

    level.df_aud_grid = [];
    wait 0.05; // let the deletes reach the client before the next page spawns
}

df_aud_grid_legend( cols )
{
    line = "";
    row = 0;

    for ( i = 0; i < level.df_aud_grid.size; i++ )
    {
        cell = level.df_aud_grid[i];
        line = line + "[" + cell.idx + "] " + cell.name + "  ";

        if ( ( i % cols ) == cols - 1 || i == level.df_aud_grid.size - 1 )
        {
            self df_out( "row " + row + " (left to right): " + line );
            line = "";
            row++;
            wait 0.05;
        }
    }
}

df_aud_grid_oneshot( cell )
{
    level endon( "end_game" );
    level endon( "df_aud_grid_stop" );

    while ( true )
    {
        df_fx_once( cell.name, cell.pos );
        wait 2;
    }
}

// The bottom-screen label of the nearest pedestal within 70 units, per player; console once per new one.
df_aud_grid_label()
{
    level endon( "end_game" );
    level endon( "df_aud_grid_stop" );

    while ( true )
    {
        wait 0.2;

        foreach ( player in getplayers() )
        {
            best = undefined;
            best_d = 70 * 70;

            foreach ( cell in level.df_aud_grid )
            {
                d = distancesquared( player.origin, cell.pos );

                if ( d < best_d )
                {
                    best = cell;
                    best_d = d;
                }
            }

            if ( !isdefined( best ) )
            {
                if ( isdefined( player.df_aud_grid_near ) )
                {
                    player.df_aud_grid_near = undefined;
                    player df_prompt( 0, undefined );
                }

                continue;
            }

            if ( isdefined( player.df_aud_grid_near ) && player.df_aud_grid_near == best.name )
                continue;

            player.df_aud_grid_near = best.name;
            player df_prompt( 0, undefined );
            player df_prompt( 1, "[" + best.idx + "] " + best.name );
            player df_out( "fx here: [" + best.idx + "] " + best.name );
        }
    }
}

df_aud_grid_stop()
{
    df_aud_grid_clear_cells();
    level.df_aud_grid_names = [];
    level.df_aud_grid_idx = [];

    foreach ( player in getplayers() )
    {
        if ( isdefined( player.df_aud_grid_near ) )
        {
            player.df_aud_grid_near = undefined;
            player df_prompt( 0, undefined );
        }
    }
}

// -------------------------------------------------------------------------------------------- freeze ----
// !df freeze (toggle). Every regular zombie (animname "zombie": Avogadro and the denizens are not) is put in the
// vanilla inert pose: no pathing, no target, standing (or crawling) still, and stays there until the toggle is off.
// This is vanilla's inert_think without inert_wakeup (a player within 64 units, sprinting within 600, a shot or a
// bump would wake it): that wake-up is what defeated the cheats_zm.gsc "ignoreall + setgoalpos" version.
// New zombies are frozen as they finish rising (poll every 0.5 s). Off: the wake anim, then find_flesh again.
df_freeze_toggle()
{
    if ( is_true( level.df_freeze ) )
    {
        level.df_freeze = 0;
        level notify( "df_freeze_off" );
        n = 0;

        foreach ( zombie in getaiarray( "axis" ) )
        {
            if ( isdefined( zombie ) && isalive( zombie ) && is_true( zombie.df_frozen ) )
            {
                zombie thread df_freeze_release();
                n++;
            }
        }

        self df_out( "freeze OFF: " + n + " zombie(s) released" );
        return;
    }

    level.df_freeze = 1;
    level thread df_freeze_loop();
    self df_out( "freeze ON: regular zombies stand still (Avogadro and denizens untouched); !df freeze again to release" );
}

df_freeze_loop()
{
    level endon( "end_game" );
    level endon( "df_freeze_off" );

    while ( true )
    {
        foreach ( zombie in getaiarray( "axis" ) )
        {
            if ( !isdefined( zombie ) || !isalive( zombie ) || is_true( zombie.df_frozen ) )
                continue;

            if ( !isdefined( zombie.animname ) || zombie.animname != "zombie" )
                continue;

            // let it finish rising / climbing first, the pose would break those
            if ( is_true( zombie.in_the_ground ) || is_true( zombie.is_traversing ) || !is_true( zombie.completed_emerging_into_playable_area ) )
                continue;

            zombie thread df_freeze_apply();
        }

        wait 0.5;
    }
}

// self = zombie
df_freeze_apply()
{
    self endon( "death" );
    self.df_frozen = 1;
    self.ignoreall = 1;
    self notify( "stop_find_flesh" );
    self notify( "zombie_acquire_enemy" );
    self notify( "stop_zombie_goto_entrance" );
    self setgoalpos( self.origin );
    self.goalradius = 8;

    if ( is_true( self.doing_equipment_attack ) )
        self stopanimscripted();

    self animmode( "normal" );

    if ( is_true( self.has_legs ) )
    {
        if ( self hasanimstatefromasd( "zm_inert" ) )
            self setanimstatefromasd( "zm_inert", "inert1" );
    }
    else if ( self hasanimstatefromasd( "zm_inert_crawl" ) )
        self setanimstatefromasd( "zm_inert_crawl", maps\mp\zombies\_zm_ai_basic::get_inert_crawl_substate() );

    // keep it pinned: find_flesh / attack code may re-issue a goal on a hit or a near player
    while ( is_true( level.df_freeze ) && is_true( self.df_frozen ) )
    {
        self setgoalpos( self.origin );
        wait 1;
    }
}

// self = zombie
df_freeze_release()
{
    self endon( "death" );
    self.df_frozen = 0;
    self.ignoreall = 0;

    if ( is_true( self.has_legs ) && self hasanimstatefromasd( "zm_inert" ) )
        self maps\mp\zombies\_zm_ai_basic::inert_transition();

    self thread maps\mp\zombies\_zm_ai_basic::find_flesh();
}

// ------------------------------------------------------------------------------------------ jet gun ----
// !df jet: why does the Jet Gun (not) heat? One console block per player with every value the heat path reads:
// vanilla _zm_weap_jetgun watch_overheat (jetgun_heatval / jetgun_overheating, started only by the equipment give),
// TranZit Enhanced's own model (jgx_heat, jgx_cooling, jgx_cool_left, jgx_lock), the engine's heat and the trigger.
// Hold the trigger 3 s, then type it. Also starts the vanilla watcher when a held Jet Gun has no heat value at all
// (a gun given outside the equipment path never heats otherwise).
df_jet_report( arg )
{
    // "!df jet watch": 8 s of samples every 0.5 s, so the trigger can be HELD while the values are read (typing the
    // command releases the trigger, and the enhanced model cools 2.5 units a second: a single sample after typing
    // shows nothing)
    if ( isdefined( arg ) && arg == "watch" )
    {
        self thread df_jet_watch();
        return;
    }

    foreach ( player in getplayers() )
    {
        w = player getcurrentweapon();
        has = player hasweapon( "jetgun_zm" );
        line = player.name + ": weapon " + w + " | has jetgun " + has;
        line += " | vanilla heatval " + df_jet_val( player.jetgun_heatval ) + " overheating " + df_jet_val( player.jetgun_overheating );
        line += " | engine heat " + player isweaponoverheating( 1 ) + " overheating " + player isweaponoverheating( 0 );
        line += " | enhanced jgx_heat " + df_jet_val( player.jgx_heat ) + " cooling " + df_jet_val( player.jgx_cooling ) + " cool_left " + df_jet_val( player.jgx_cool_left ) + " lock " + df_jet_val( player.jgx_lock );
        line += " | trigger " + player attackbuttonpressed();
        self df_out( "DF jet: " + line );

        if ( has && w == "jetgun_zm" && !isdefined( player.jetgun_heatval ) )
        {
            player thread maps\mp\zombies\_zm_weap_jetgun::watch_overheat();
            self df_out( "DF jet: " + player.name + " had no vanilla heat value (gun given outside the equipment path): watcher started, fire again" );
        }
    }

    if ( !isdefined( level.te_active ) )
        self df_out( "DF jet: TranZit Enhanced is NOT loaded (level.te_active undefined): vanilla heat model only" );
}

df_jet_val( v )
{
    if ( !isdefined( v ) )
        return "undef";

    return "" + v;
}

df_jet_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );
    self df_out( "DF jet: sampling for 8 s, HOLD THE TRIGGER now" );

    for ( i = 0; i < 16; i++ )
    {
        wait 0.5;
        self df_out( "DF jet " + ( i * 0.5 ) + " s: trigger " + self attackbuttonpressed() + " | engine heat " + self isweaponoverheating( 1 ) + " | vanilla heatval " + df_jet_val( self.jetgun_heatval ) + " | enhanced jgx_heat " + df_jet_val( self.jgx_heat ) + " cooling " + df_jet_val( self.jgx_cooling ) + " lock " + df_jet_val( self.jgx_lock ) + " | weapon " + self getcurrentweapon() );
    }
}
