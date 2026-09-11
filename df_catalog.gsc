// Dead Frequency - full TranZit model catalogue (generated 2026-09-08 by tools/gen_catalog.pl from the glTF
// export of the game files: OpenAssetTools Unlinker --model-format GLTF on zm_transit, so_zclassic_zm_transit,
// common_zm, patch_zm, zm_transit_patch and the nine zm_transit_gump_* area zones; sizes measured from the
// meshes, in game units, player height ~70).
//   Data: one line per model, "name zone width height depth" (792 models).
//   `!df sizes <keyword|all> [page]` lists them with zone and size in the console: NO precache needed, so every
//   model of the map can be checked from in game.
//   `!df catalog <keyword>` spawns models, which only works for PRECACHED names: the curated list of
//   df_coords::df_catalog_models() plus, when the owner asks for it before loading the map,
//     set df_catalog_page <n>        one page of 30 names of the full catalogue (df_catalog_pagesize changes 30)
//     set df_extra_models "a b c"    hand-picked names (df_coords::df_catalog_extra_models)
//   Precaching everything is impossible: the engine has a model-index limit and 700+ extra models would exceed
//   it, so the page mechanism keeps the load safe.
// Zones: zm_transit / so_zclassic_zm_transit / common_zm / patch_zm / zm_transit_patch are ALWAYS loaded;
// a zm_transit_gump_<area> model is streamed with that area and renders untextured (black) elsewhere.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_systems;

// Every catalogue line, built once and cached on the level.
df_catalog_all()
{
    if ( isdefined( level.df_cat ) )
        return level.df_cat;

    l = [];
    l = df_cat_data_01( l );
    l = df_cat_data_02( l );
    l = df_cat_data_03( l );
    l = df_cat_data_04( l );
    l = df_cat_data_05( l );
    l = df_cat_data_06( l );
    l = df_cat_data_07( l );
    l = df_cat_data_08( l );
    l = df_cat_data_09( l );
    l = df_cat_data_10( l );
    l = df_cat_data_11( l );
    l = df_cat_data_12( l );
    l = df_cat_data_13( l );
    l = df_cat_data_14( l );
    l = df_cat_data_15( l );
    l = df_cat_data_16( l );
    l = df_cat_data_17( l );
    l = df_cat_data_18( l );
    l = df_cat_data_19( l );
    l = df_cat_data_20( l );

    level.df_cat = l;
    return l;
}

// "name zone w h d" -> the parts
df_cat_name( line )
{
    return strtok( line, " " )[0];
}

df_cat_zone( line )
{
    return strtok( line, " " )[1];
}

// "29x44x29" (width x height x depth in game units)
df_cat_size( line )
{
    p = strtok( line, " " );
    return p[2] + "x" + p[3] + "x" + p[4];
}

// True when the zone is loaded everywhere on the map (a gump zone streams with its area only).
df_cat_always( line )
{
    z = df_cat_zone( line );
    return !issubstr( z, "gump" );
}

// Lines whose model name contains `keyword` ("all" / "" = everything).
df_catalog_match( keyword )
{
    out = [];

    foreach ( line in df_catalog_all() )
    {
        if ( keyword == "" || keyword == "all" || issubstr( df_cat_name( line ), keyword ) )
            out[out.size] = line;
    }

    return out;
}

// The catalogue line of `name`, or undefined.
df_catalog_lookup( name )
{
    foreach ( line in df_catalog_all() )
    {
        if ( df_cat_name( line ) == name )
            return line;
    }

    return undefined;
}

// "name  zone  WxHxD" plus a note for streamed zones.
df_catalog_line_text( line )
{
    t = df_cat_name( line ) + "  " + df_cat_size( line ) + "  " + df_cat_zone( line );

    if ( !df_cat_always( line ) )
        t += " (streamed: black elsewhere)";

    return t;
}

// "!df sizes <keyword|all> [page]": 30 lines per page in the console, no precache, no spawning.
// Returns the summary line for the screen.
df_catalog_sizes_print( keyword, page )
{
    lines = df_catalog_match( keyword );

    if ( lines.size == 0 )
        return "DF: no model name contains `" + keyword + "` (try: rock skull table tv barrel pole light box crate all)";

    per = 30;
    pages = int( ( lines.size + per - 1 ) / per );

    if ( page < 1 )
        page = 1;

    if ( page > pages )
        page = pages;

    first = ( page - 1 ) * per;
    last = first + per;

    if ( last > lines.size )
        last = lines.size;

    df_debug_print( "DF: [SIZES] " + keyword + " page " + page + "/" + pages + " (name, width x height x depth in units, zone; player ~70 tall)" );

    for ( i = first; i < last; i++ )
        df_debug_print( "  " + ( i + 1 ) + ". " + df_catalog_line_text( lines[i] ) );

    return "DF: " + lines.size + " model(s) match `" + keyword + "`, page " + page + "/" + pages + " in the console";
}

// Precaches one page of the full catalogue when the console dvar df_catalog_page is set before the map loads
// (df_catalog_pagesize, default 30, changes how many). Called from df_main::init. Returns the number loaded.
df_catalog_page_precache()
{
    level.df_cat_loaded = [];
    page = getdvarint( "df_catalog_page" );

    if ( !isdefined( page ) || page < 1 )
        return 0;

    per = getdvarint( "df_catalog_pagesize" );

    if ( !isdefined( per ) || per < 1 )
        per = 30;

    lines = df_catalog_all();
    first = ( page - 1 ) * per;
    n = 0;

    for ( i = first; i < first + per && i < lines.size; i++ )
    {
        name = df_cat_name( lines[i] );
        precachemodel( name );
        level.df_cat_loaded[name] = 1;
        n++;
    }

    df_debug_print( "DF: catalogue page " + page + " precached: " + n + " model(s) (" + ( first + 1 ) + ".." + ( first + n ) + " of " + lines.size + "), spawnable with !df catalog <keyword>" );
    return n;
}

// True when `name` was precached by the page mechanism (so !df catalog may spawn it).
df_catalog_page_has( name )
{
    return isdefined( level.df_cat_loaded ) && isdefined( level.df_cat_loaded[name] );
}

df_cat_data_01( l )
{
    l[l.size] = "afr_barrel_biohazard_white_rust zm_transit 29 44 29";
    l[l.size] = "afr_chimp_skull_01 zm_transit_gump_forest2 10 9 7";
    l[l.size] = "afr_chimp_skull_03 zm_transit_gump_forest2 10 8 7";
    l[l.size] = "afr_junktire zm_transit_gump_diner 24 24 7";
    l[l.size] = "afr_mirror_broken zm_transit_gump_diner 25 34 9";
    l[l.size] = "afr_pallet_destroyed zm_transit_gump_busstation 49 10 65";
    l[l.size] = "afr_powerpole1 zm_transit 15 398 110";
    l[l.size] = "afr_wooden_fence_rail_01 zm_transit_gump_farm 6 9 116";
    l[l.size] = "afr_wooden_fence_rail_03 zm_transit_gump_farm 6 7 120";
    l[l.size] = "africa_skulls_pile_large zm_transit_gump_forest2 44 19 45";
    l[l.size] = "ap_table01 zm_transit_gump_town 40 34 70";
    l[l.size] = "bathroom_sink zm_transit_gump_busstation 28 35 28";
    l[l.size] = "bathroom_urinal zm_transit_gump_diner 15 49 20";
    l[l.size] = "berlin_hotel_lights_wall2_off zm_transit_gump_town 8 23 8";
    l[l.size] = "berlin_hotel_lights_wall2_on zm_transit_gump_town 8 23 8";
    l[l.size] = "berlin_lamp_post_sidewalk_01 zm_transit_gump_diner 34 292 34";
    l[l.size] = "berlin_traffic_signal_01_off zm_transit_gump_town 16 37 17";
    l[l.size] = "berlin_traffic_signal_01_red_light so_zclassic_zm_transit 2 8 8";
    l[l.size] = "c_zom_avagadro_fb so_zclassic_zm_transit 23 70 42";
    l[l.size] = "c_zom_engineer_viewhands so_zclassic_zm_transit 27 16 22";
    l[l.size] = "c_zom_farmgirl_viewhands so_zclassic_zm_transit 27 16 21";
    l[l.size] = "c_zom_oldman_viewhands so_zclassic_zm_transit 27 16 22";
    l[l.size] = "c_zom_player_engineer_fb so_zclassic_zm_transit 23 71 42";
    l[l.size] = "c_zom_player_farmgirl_fb so_zclassic_zm_transit 25 71 41";
    l[l.size] = "c_zom_player_oldman_fb so_zclassic_zm_transit 25 71 42";
    l[l.size] = "c_zom_player_reporter_fb so_zclassic_zm_transit 24 72 42";
    l[l.size] = "c_zom_reporter_viewhands so_zclassic_zm_transit 27 16 22";
    l[l.size] = "c_zom_screecher_fb so_zclassic_zm_transit 55 38 21";
    l[l.size] = "c_zom_zombie1_body01 so_zclassic_zm_transit 24 61 42";
    l[l.size] = "c_zom_zombie1_body01_g_larmoff so_zclassic_zm_transit 24 31 42";
    l[l.size] = "c_zom_zombie1_body01_g_legsoff so_zclassic_zm_transit 9 16 15";
    l[l.size] = "c_zom_zombie1_body01_g_llegoff so_zclassic_zm_transit 12 37 16";
    l[l.size] = "c_zom_zombie1_body01_g_lowclean so_zclassic_zm_transit 12 37 15";
    l[l.size] = "c_zom_zombie1_body01_g_rarmoff so_zclassic_zm_transit 24 31 39";
    l[l.size] = "c_zom_zombie1_body01_g_rlegoff so_zclassic_zm_transit 12 37 15";
    l[l.size] = "c_zom_zombie1_body01_g_upclean so_zclassic_zm_transit 24 31 42";
    l[l.size] = "c_zom_zombie1_body02 so_zclassic_zm_transit 24 61 42";
    l[l.size] = "c_zom_zombie1_body02_g_larmoff so_zclassic_zm_transit 24 31 42";
    l[l.size] = "c_zom_zombie1_body02_g_legsoff so_zclassic_zm_transit 9 16 15";
    l[l.size] = "c_zom_zombie1_body02_g_llegoff so_zclassic_zm_transit 12 37 16";
    return l;
}

df_cat_data_02( l )
{
    l[l.size] = "c_zom_zombie1_body02_g_lowclean so_zclassic_zm_transit 12 37 15";
    l[l.size] = "c_zom_zombie1_body02_g_rarmoff so_zclassic_zm_transit 24 31 39";
    l[l.size] = "c_zom_zombie1_body02_g_rlegoff so_zclassic_zm_transit 12 37 15";
    l[l.size] = "c_zom_zombie1_body02_g_upclean so_zclassic_zm_transit 24 31 42";
    l[l.size] = "c_zom_zombie2_body01 so_zclassic_zm_transit 24 60 41";
    l[l.size] = "c_zom_zombie2_body01_g_behead so_zclassic_zm_transit 6 10 8";
    l[l.size] = "c_zom_zombie2_body01_g_larmoff so_zclassic_zm_transit 24 38 39";
    l[l.size] = "c_zom_zombie2_body01_g_legsoff so_zclassic_zm_transit 9 29 14";
    l[l.size] = "c_zom_zombie2_body01_g_llegoff so_zclassic_zm_transit 11 40 15";
    l[l.size] = "c_zom_zombie2_body01_g_lowclean so_zclassic_zm_transit 11 40 15";
    l[l.size] = "c_zom_zombie2_body01_g_rarmoff so_zclassic_zm_transit 24 38 37";
    l[l.size] = "c_zom_zombie2_body01_g_rlegoff so_zclassic_zm_transit 11 40 15";
    l[l.size] = "c_zom_zombie2_body01_g_upclean so_zclassic_zm_transit 24 38 40";
    l[l.size] = "c_zom_zombie2_body02 so_zclassic_zm_transit 24 60 41";
    l[l.size] = "c_zom_zombie2_body02_g_larmoff so_zclassic_zm_transit 24 38 39";
    l[l.size] = "c_zom_zombie2_body02_g_rarmoff so_zclassic_zm_transit 24 38 37";
    l[l.size] = "c_zom_zombie2_body02_g_upclean so_zclassic_zm_transit 24 38 40";
    l[l.size] = "c_zom_zombie2_body03 so_zclassic_zm_transit 24 60 41";
    l[l.size] = "c_zom_zombie2_body03_g_larmoff so_zclassic_zm_transit 24 38 39";
    l[l.size] = "c_zom_zombie2_body03_g_rarmoff so_zclassic_zm_transit 24 38 37";
    l[l.size] = "c_zom_zombie2_body03_g_upclean so_zclassic_zm_transit 24 38 40";
    l[l.size] = "c_zom_zombie3_body01 so_zclassic_zm_transit 23 62 42";
    l[l.size] = "c_zom_zombie3_body01_g_larmoff so_zclassic_zm_transit 23 23 41";
    l[l.size] = "c_zom_zombie3_body01_g_legsoff so_zclassic_zm_transit 11 21 16";
    l[l.size] = "c_zom_zombie3_body01_g_llegoff so_zclassic_zm_transit 12 41 16";
    l[l.size] = "c_zom_zombie3_body01_g_lowclean so_zclassic_zm_transit 12 41 15";
    l[l.size] = "c_zom_zombie3_body01_g_rarmoff so_zclassic_zm_transit 23 23 38";
    l[l.size] = "c_zom_zombie3_body01_g_rlegoff so_zclassic_zm_transit 12 41 16";
    l[l.size] = "c_zom_zombie3_body01_g_upclean so_zclassic_zm_transit 23 23 42";
    l[l.size] = "c_zom_zombie3_body02 so_zclassic_zm_transit 23 62 42";
    l[l.size] = "c_zom_zombie3_body02_g_larmoff so_zclassic_zm_transit 23 23 41";
    l[l.size] = "c_zom_zombie3_body02_g_legsoff so_zclassic_zm_transit 11 21 16";
    l[l.size] = "c_zom_zombie3_body02_g_llegoff so_zclassic_zm_transit 12 41 16";
    l[l.size] = "c_zom_zombie3_body02_g_lowclean so_zclassic_zm_transit 12 41 15";
    l[l.size] = "c_zom_zombie3_body02_g_rarmoff so_zclassic_zm_transit 23 23 38";
    l[l.size] = "c_zom_zombie3_body02_g_rlegoff so_zclassic_zm_transit 12 41 16";
    l[l.size] = "c_zom_zombie3_body02_g_upclean so_zclassic_zm_transit 23 23 42";
    l[l.size] = "c_zom_zombie3_body03 so_zclassic_zm_transit 23 62 42";
    l[l.size] = "c_zom_zombie3_body03_g_larmoff so_zclassic_zm_transit 23 23 41";
    l[l.size] = "c_zom_zombie3_body03_g_legsoff so_zclassic_zm_transit 11 21 16";
    return l;
}

df_cat_data_03( l )
{
    l[l.size] = "c_zom_zombie3_body03_g_llegoff so_zclassic_zm_transit 12 41 16";
    l[l.size] = "c_zom_zombie3_body03_g_lowclean so_zclassic_zm_transit 12 41 15";
    l[l.size] = "c_zom_zombie3_body03_g_rarmoff so_zclassic_zm_transit 23 23 38";
    l[l.size] = "c_zom_zombie3_body03_g_rlegoff so_zclassic_zm_transit 12 41 16";
    l[l.size] = "c_zom_zombie3_body03_g_upclean so_zclassic_zm_transit 23 23 42";
    l[l.size] = "c_zom_zombie3_body04 so_zclassic_zm_transit 23 62 42";
    l[l.size] = "c_zom_zombie3_body04_g_larmoff so_zclassic_zm_transit 23 23 41";
    l[l.size] = "c_zom_zombie3_body04_g_legsoff so_zclassic_zm_transit 11 21 16";
    l[l.size] = "c_zom_zombie3_body04_g_llegoff so_zclassic_zm_transit 12 41 16";
    l[l.size] = "c_zom_zombie3_body04_g_lowclean so_zclassic_zm_transit 12 41 15";
    l[l.size] = "c_zom_zombie3_body04_g_rarmoff so_zclassic_zm_transit 23 23 38";
    l[l.size] = "c_zom_zombie3_body04_g_rlegoff so_zclassic_zm_transit 12 41 16";
    l[l.size] = "c_zom_zombie3_body04_g_upclean so_zclassic_zm_transit 23 23 42";
    l[l.size] = "c_zom_zombie3_body05 so_zclassic_zm_transit 23 62 42";
    l[l.size] = "c_zom_zombie3_body05_g_larmoff so_zclassic_zm_transit 23 23 41";
    l[l.size] = "c_zom_zombie3_body05_g_legsoff so_zclassic_zm_transit 11 21 16";
    l[l.size] = "c_zom_zombie3_body05_g_llegoff so_zclassic_zm_transit 12 41 16";
    l[l.size] = "c_zom_zombie3_body05_g_lowclean so_zclassic_zm_transit 12 41 15";
    l[l.size] = "c_zom_zombie3_body05_g_rarmoff so_zclassic_zm_transit 23 23 38";
    l[l.size] = "c_zom_zombie3_body05_g_rlegoff so_zclassic_zm_transit 12 41 16";
    l[l.size] = "c_zom_zombie3_body05_g_upclean so_zclassic_zm_transit 23 23 42";
    l[l.size] = "c_zom_zombie3_g_llegspawn so_zclassic_zm_transit 13 5 15";
    l[l.size] = "c_zom_zombie3_g_rlegspawn so_zclassic_zm_transit 9 5 14";
    l[l.size] = "c_zom_zombie_g_larmspawn so_zclassic_zm_transit 10 4 5";
    l[l.size] = "c_zom_zombie_g_llegspawn so_zclassic_zm_transit 13 6 13";
    l[l.size] = "c_zom_zombie_g_rarmspawn so_zclassic_zm_transit 12 7 6";
    l[l.size] = "c_zom_zombie_g_rlegspawn so_zclassic_zm_transit 9 6 14";
    l[l.size] = "c_zom_zombie_head_a so_zclassic_zm_transit 14 10 11";
    l[l.size] = "c_zom_zombie_head_k so_zclassic_zm_transit 14 10 10";
    l[l.size] = "c_zom_zombie_head_l so_zclassic_zm_transit 14 10 10";
    l[l.size] = "c_zom_zombie_head_n so_zclassic_zm_transit 14 10 11";
    l[l.size] = "ch_bedframemetal_dark zm_transit_gump_forest2 41 32 86";
    l[l.size] = "ch_corkboard_metaltrim_4x8 zm_transit 96 48 1";
    l[l.size] = "ch_dinerboothchair zm_transit_gump_town 28 44 62";
    l[l.size] = "ch_dinerboothchair_2_d zm_transit_gump_diner 29 44 62";
    l[l.size] = "ch_dinerboothchair_2_d3 zm_transit_gump_diner 29 44 62";
    l[l.size] = "ch_dinerboothtable zm_transit_gump_diner 33 32 54";
    l[l.size] = "ch_furniture_teachers_chair_dusty_1 zm_transit_gump_town 29 50 30";
    l[l.size] = "ch_gas_pump zm_transit_gump_diner 31 65 30";
    l[l.size] = "ch_mattress_2 zm_transit_gump_farm 40 7 83";
    return l;
}

df_cat_data_04( l )
{
    l[l.size] = "ch_mattress_bent_1 zm_transit_gump_town 106 67 50";
    l[l.size] = "ch_radiator01 zm_transit_gump_busstation 28 31 7";
    l[l.size] = "ch_tombstone1 zm_transit 3 32 20";
    l[l.size] = "ch_washer_01 zm_transit_gump_town 31 48 29";
    l[l.size] = "ch_water_fountain zm_transit_gump_busstation 25 36 32";
    l[l.size] = "com_bike_destroyed zm_transit_gump_busstation 69 17 42";
    l[l.size] = "com_cardboardbox_dusty_01 zm_transit_gump_farm 30 22 21";
    l[l.size] = "com_cardboardbox_dusty_02 zm_transit_gump_farm 44 26 35";
    l[l.size] = "com_cardboardbox_dusty_03 zm_transit_gump_farm 38 26 27";
    l[l.size] = "com_cash_register zm_transit_gump_town 19 12 23";
    l[l.size] = "com_cash_register_gstation zm_transit_gump_diner 19 12 23";
    l[l.size] = "com_crate01_farm zm_transit_gump_farm 26 26 50";
    l[l.size] = "com_crate02_farm zm_transit_gump_farm 26 26 51";
    l[l.size] = "com_debris_bumper01 zm_transit_gump_tunnel 6 9 61";
    l[l.size] = "com_debris_car_hood zm_transit_gump_tunnel 35 6 54";
    l[l.size] = "com_debris_car_panal02 zm_transit_gump_tunnel 63 5 34";
    l[l.size] = "com_debris_engine02 zm_transit_gump_tunnel 47 6 22";
    l[l.size] = "com_debris_metal_grille zm_transit_gump_tunnel 18 3 33";
    l[l.size] = "com_debris_steeringwheel02 zm_transit_gump_tunnel 20 9 15";
    l[l.size] = "com_file_cabinets_a_drawer zm_transit_gump_town 27 12 9";
    l[l.size] = "com_file_cabinets_a_long zm_transit_gump_town 47 105 130";
    l[l.size] = "com_file_cabinets_a_med zm_transit_gump_town 46 105 98";
    l[l.size] = "com_food_prep_station_fryer zm_transit_gump_diner 65 52 28";
    l[l.size] = "com_food_prep_station_sink zm_transit_gump_diner 52 47 28";
    l[l.size] = "com_food_prep_station_stove zm_transit_gump_diner 29 39 29";
    l[l.size] = "com_hub_cap_1 zm_transit_gump_diner 16 2 16";
    l[l.size] = "com_hub_cap_2 zm_transit_gump_diner 16 2 16";
    l[l.size] = "com_hub_cap_3 zm_transit_gump_diner 16 3 16";
    l[l.size] = "com_hub_cap_4 zm_transit_gump_diner 16 2 16";
    l[l.size] = "com_junktire zm_transit_gump_busstation 24 24 7";
    l[l.size] = "com_paintcan zm_transit_gump_diner 11 13 12";
    l[l.size] = "com_payphone_america zm_transit_gump_busstation 7 24 10";
    l[l.size] = "com_pipe_4_45angle_metal zm_transit_gump_powerstation 23 15 9";
    l[l.size] = "com_pipe_4_90angle_metal zm_transit_gump_powerstation 16 16 9";
    l[l.size] = "com_pipe_4_90angle_metal_rusted zm_transit_gump_tunnel 16 16 9";
    l[l.size] = "com_pipe_4_coupling_ceramic zm_transit_gump_powerstation 3 9 11";
    l[l.size] = "com_pipe_4_coupling_metal_rusted zm_transit_gump_tunnel 3 9 11";
    l[l.size] = "com_pipe_4_holder_metal_rusted zm_transit_gump_powerstation 1 70 9";
    l[l.size] = "com_pipe_4x128_metal zm_transit_gump_powerstation 128 8 8";
    l[l.size] = "com_pipe_4x128_metal_rusted zm_transit_gump_tunnel 128 8 8";
    return l;
}

df_cat_data_05( l )
{
    l[l.size] = "com_pipe_4x256_metal zm_transit_gump_powerstation 256 8 8";
    l[l.size] = "com_pipe_4x256_metal_bstation zm_transit_gump_busstation 256 8 8";
    l[l.size] = "com_pipe_4x256_metal_rusted zm_transit_gump_tunnel 256 8 8";
    l[l.size] = "com_pipe_4x32_metal zm_transit_gump_powerstation 32 8 8";
    l[l.size] = "com_pipe_4x64_metal zm_transit_gump_powerstation 64 8 8";
    l[l.size] = "com_pipe_4x64_metal_rusted zm_transit_gump_tunnel 64 8 8";
    l[l.size] = "com_pipe_8_90angle_ceramic zm_transit_gump_powerstation 20 20 18";
    l[l.size] = "com_pipe_8_90angle_ceramic_lab zm_transit_gump_labs 20 20 18";
    l[l.size] = "com_pipe_8x128_ceramic zm_transit_gump_powerstation 128 16 16";
    l[l.size] = "com_pipe_8x128_ceramic_diner zm_transit_gump_diner 128 16 16";
    l[l.size] = "com_pipe_8x128_ceramic_lab zm_transit_gump_labs 128 16 16";
    l[l.size] = "com_pipe_8x256_ceramic zm_transit_gump_powerstation 256 16 16";
    l[l.size] = "com_pipe_8x32_ceramic zm_transit_gump_powerstation 32 16 16";
    l[l.size] = "com_pipe_8x64_ceramic zm_transit_gump_powerstation 64 16 16";
    l[l.size] = "com_powerline_tower_top2_broken2 zm_transit_gump_forest2 1034 290 775";
    l[l.size] = "com_powerline_tower_top_broken2 zm_transit_gump_powerstation 767 612 1270";
    l[l.size] = "com_restaurantchair_2 zm_transit_gump_busstation 23 41 22";
    l[l.size] = "com_restaurantkitchentable_1 zm_transit_gump_farm 84 40 33";
    l[l.size] = "com_restaurantkitchenvent zm_transit_gump_diner 129 35 53";
    l[l.size] = "com_restaurantsink_2comps zm_transit_gump_diner 30 45 80";
    l[l.size] = "com_roofvent3 zm_transit_gump_diner 38 32 33";
    l[l.size] = "com_spray_can01 zm_transit_gump_diner 3 10 3";
    l[l.size] = "com_stepladder_large_closed so_zclassic_zm_transit 28 95 9";
    l[l.size] = "com_stove zm_transit_gump_farm 29 49 30";
    l[l.size] = "com_trafficcone01 zm_transit_gump_tunnel 16 28 16";
    l[l.size] = "com_trash_bin_sml01 zm_transit_gump_town 19 19 14";
    l[l.size] = "com_woodlog_16_192_a zm_transit_gump_forest2 16 16 196";
    l[l.size] = "com_woodlog_16_192_b zm_transit_gump_forest2 16 16 194";
    l[l.size] = "com_woodlog_16_192_c zm_transit_gump_forest2 16 16 194";
    l[l.size] = "com_woodlog_16_192_d zm_transit_gump_forest2 16 17 194";
    l[l.size] = "com_woodlog_24_96_a zm_transit_gump_forest2 23 24 98";
    l[l.size] = "com_woodlog_24_96_b zm_transit_gump_forest2 25 25 97";
    l[l.size] = "com_woodlog_24_96_c zm_transit_gump_forest2 24 24 97";
    l[l.size] = "com_woodlog_24_96_d zm_transit_gump_forest2 24 26 97";
    l[l.size] = "ct_dry_machine zm_transit_gump_town 50 85 45";
    l[l.size] = "debris_rubble_chunk_03 zm_transit_gump_tunnel 24 8 25";
    l[l.size] = "debris_rubble_chunk_05 zm_transit_gump_tunnel 15 6 14";
    l[l.size] = "debris_rubble_chunk_10 zm_transit_gump_tunnel 11 10 29";
    l[l.size] = "debris_rubble_pile_01 zm_transit_gump_tunnel 47 15 58";
    l[l.size] = "debris_rubble_pile_02 zm_transit_gump_tunnel 66 35 58";
    return l;
}

df_cat_data_06( l )
{
    l[l.size] = "defaultvehicle patch_zm 198 58 77";
    l[l.size] = "dest_glo_powerbox_glass02_chunk03 so_zclassic_zm_transit 0 8 8";
    l[l.size] = "dest_glo_powerbox_glass02_chunk04 so_zclassic_zm_transit 0 19 6";
    l[l.size] = "dest_glo_powerbox_glass02_chunk05 so_zclassic_zm_transit 0 17 5";
    l[l.size] = "diner_stool_01 zm_transit_gump_diner 19 27 19";
    l[l.size] = "foliage_red_pine_stump_lg zm_transit_gump_forest2 114 77 98";
    l[l.size] = "furniture_lamp_hanging zm_transit_gump_town 34 42 34";
    l[l.size] = "furniture_lamp_hanging_off zm_transit_gump_town 34 42 34";
    l[l.size] = "furniture_pool_table_snooker zm_transit_gump_town 160 34 92";
    l[l.size] = "fx common_zm 49 6 29";
    l[l.size] = "fx_char_gib_chunk_bone03 common_zm 3 3 5";
    l[l.size] = "fx_char_gib_chunk_fat common_zm 3 3 1";
    l[l.size] = "fx_char_gib_chunk_flesh03 common_zm 4 5 2";
    l[l.size] = "fx_char_gib_chunk_meat01 common_zm 3 9 7";
    l[l.size] = "fx_char_gib_chunk_meat02 common_zm 4 5 8";
    l[l.size] = "fx_decal_burnt_paper so_zclassic_zm_transit 6 5 5";
    l[l.size] = "fx_decal_burnt_paper2 so_zclassic_zm_transit 9 6 8";
    l[l.size] = "fx_decal_burnt_paper3 so_zclassic_zm_transit 7 1 10";
    l[l.size] = "fx_wood_splinter01 common_zm 4 28 2";
    l[l.size] = "fx_wood_splinter02 common_zm 6 20 2";
    l[l.size] = "fxanim_zom_bus_interior_mod zm_transit 318 26 90";
    l[l.size] = "intro_props_wires_01 zm_transit_gump_powerstation 1212 198 103";
    l[l.size] = "intro_props_wires_02 zm_transit_gump_powerstation 1160 202 92";
    l[l.size] = "iw_rooftop_ac_unit zm_transit_gump_diner 71 59 109";
    l[l.size] = "light_outdoorwall01 zm_transit_gump_busstation 3 4 10";
    l[l.size] = "light_outdoorwall01_on zm_transit_gump_busstation 6 8 15";
    l[l.size] = "light_outdoorwall01_on_power zm_transit_gump_powerstation 6 8 15";
    l[l.size] = "lights_indlight zm_transit_gump_busstation 42 14 24";
    l[l.size] = "lights_indlight_diner zm_transit_gump_diner 42 14 24";
    l[l.size] = "lights_indlight_farm zm_transit_gump_farm 42 14 24";
    l[l.size] = "lights_indlight_on_depot zm_transit_gump_busstation 42 14 24";
    l[l.size] = "lights_indlight_on_diner zm_transit_gump_diner 42 14 24";
    l[l.size] = "lights_indlight_on_farm zm_transit_gump_farm 42 14 24";
    l[l.size] = "lights_indlight_on_power zm_transit_gump_powerstation 42 14 24";
    l[l.size] = "lights_indlight_on_town zm_transit_gump_town 42 14 24";
    l[l.size] = "lights_indlight_power zm_transit_gump_powerstation 42 14 24";
    l[l.size] = "locomotive_sidevent_01 zm_transit_gump_powerstation 7 24 96";
    l[l.size] = "me_dumpster_close zm_transit_gump_diner 59 67 105";
    l[l.size] = "mp_m_trash_pile zm_transit_gump_busstation 78 40 40";
    l[l.size] = "mp_radiation_building_supports02 zm_transit_gump_powerstation 14 242 78";
    return l;
}

df_cat_data_07( l )
{
    l[l.size] = "ny_harbor_planter zm_transit_gump_busstation 57 29 56";
    l[l.size] = "ny_harbor_sub_int_light_2 zm_transit_gump_tunnel 38 4 12";
    l[l.size] = "ny_harbor_sub_int_light_2_off zm_transit_gump_tunnel 38 4 12";
    l[l.size] = "ny_harbor_sub_int_pipes_under zm_transit_gump_powerstation 150 17 39";
    l[l.size] = "ny_manhattan_barrier_sawhorse zm_transit_gump_tunnel 80 44 40";
    l[l.size] = "ny_manhattan_street_pipe_01_broken zm_transit_gump_tunnel 41 391 41";
    l[l.size] = "ny_utility_pipes_vertical zm_transit_gump_powerstation 37 189 25";
    l[l.size] = "p6_anim_zm_barricade_board_01 zm_transit 104 9 3";
    l[l.size] = "p6_anim_zm_barricade_board_01_upgrade zm_transit 104 9 3";
    l[l.size] = "p6_anim_zm_barricade_board_02 zm_transit 109 9 2";
    l[l.size] = "p6_anim_zm_barricade_board_02_upgrade zm_transit 109 9 2";
    l[l.size] = "p6_anim_zm_barricade_board_03 zm_transit 109 9 2";
    l[l.size] = "p6_anim_zm_barricade_board_03_upgrade zm_transit 109 9 3";
    l[l.size] = "p6_anim_zm_barricade_board_04 zm_transit 104 9 3";
    l[l.size] = "p6_anim_zm_barricade_board_04_upgrade zm_transit 104 9 3";
    l[l.size] = "p6_anim_zm_barricade_board_05 zm_transit 104 9 3";
    l[l.size] = "p6_anim_zm_barricade_board_05_upgrade zm_transit 104 9 3";
    l[l.size] = "p6_anim_zm_barricade_board_06 zm_transit 104 9 3";
    l[l.size] = "p6_anim_zm_barricade_board_06_upgrade zm_transit 104 9 3";
    l[l.size] = "p6_anim_zm_barricade_board_bus_01 zm_transit 9 48 3";
    l[l.size] = "p6_anim_zm_barricade_board_bus_01_upgrade zm_transit 9 48 3";
    l[l.size] = "p6_anim_zm_barricade_board_bus_02 zm_transit 9 49 2";
    l[l.size] = "p6_anim_zm_barricade_board_bus_02_upgrade zm_transit 9 49 2";
    l[l.size] = "p6_anim_zm_barricade_board_bus_03 zm_transit 9 48 3";
    l[l.size] = "p6_anim_zm_barricade_board_bus_03_upgrade zm_transit 9 48 3";
    l[l.size] = "p6_anim_zm_barricade_board_bus_04 zm_transit 9 49 2";
    l[l.size] = "p6_anim_zm_barricade_board_bus_04_upgrade zm_transit 9 49 3";
    l[l.size] = "p6_anim_zm_barricade_board_bus_05 zm_transit 9 48 3";
    l[l.size] = "p6_anim_zm_barricade_board_bus_05_upgrade zm_transit 9 48 3";
    l[l.size] = "p6_anim_zm_barricade_board_bus_collision zm_transit 8 51 55";
    l[l.size] = "p6_anim_zm_barricade_board_collision zm_transit 8 111 107";
    l[l.size] = "p6_anim_zm_buildable_etrap zm_transit 60 47 25";
    l[l.size] = "p6_anim_zm_buildable_pap zm_transit 86 93 47";
    l[l.size] = "p6_anim_zm_buildable_pap_on zm_transit 86 93 47";
    l[l.size] = "p6_anim_zm_buildable_sq zm_transit 140 979 181";
    l[l.size] = "p6_anim_zm_buildable_turbine zm_transit 29 81 43";
    l[l.size] = "p6_anim_zm_buildable_turret zm_transit 40 49 27";
    l[l.size] = "p6_anim_zm_bus_driver zm_transit 33 71 25";
    l[l.size] = "p6_anim_zm_magic_box zm_transit 96 19 27";
    l[l.size] = "p6_anim_zm_magic_box_fake zm_transit 90 27 34";
    return l;
}

df_cat_data_08( l )
{
    l[l.size] = "p6_antenna_3 zm_transit_gump_farm 108 104 71";
    l[l.size] = "p6_billboard_pillar_top zm_transit_gump_diner 544 355 83";
    l[l.size] = "p6_car_lift zm_transit_gump_diner 91 36 209";
    l[l.size] = "p6_car_lift_lowered zm_transit_gump_diner 91 8 220";
    l[l.size] = "p6_chair_damaged_trash_panama zm_transit_gump_busstation 41 41 42";
    l[l.size] = "p6_cic_wires_hanging zm_transit_gump_powerstation 176 27 12";
    l[l.size] = "p6_door_metal_no_decal_left zm_transit_gump_town 61 102 18";
    l[l.size] = "p6_door_metal_no_decal_right zm_transit_gump_town 61 102 18";
    l[l.size] = "p6_duct_sq_sml_64_dirty zm_transit_gump_diner 64 22 22";
    l[l.size] = "p6_duct_sq_sml_vent_dirty zm_transit_gump_diner 8 22 22";
    l[l.size] = "p6_duct_sq_sml_vert_90_dirty zm_transit_gump_diner 27 27 22";
    l[l.size] = "p6_garage_pipes_1x128 zm_transit 128 2 2";
    l[l.size] = "p6_garage_pipes_1x16 zm_transit_gump_tunnel 16 2 2";
    l[l.size] = "p6_garage_pipes_1x32 zm_transit_gump_tunnel 32 2 2";
    l[l.size] = "p6_garage_pipes_1x64 zm_transit_gump_powerstation 64 2 2";
    l[l.size] = "p6_garage_pipes_90deg02 zm_transit_gump_tunnel 3 2 3";
    l[l.size] = "p6_garage_pipes_90deg03 zm_transit_gump_tunnel 9 2 9";
    l[l.size] = "p6_garage_pipes_holder zm_transit_gump_tunnel 1 25 2";
    l[l.size] = "p6_grass_wild_mixed_med zm_transit 186 41 157";
    l[l.size] = "p6_karma_window_vent_open zm_transit_gump_powerstation 90 136 18";
    l[l.size] = "p6_light_sconce_motel_off zm_transit_gump_town 18 21 23";
    l[l.size] = "p6_light_sconce_motel_on zm_transit_gump_town 18 21 23";
    l[l.size] = "p6_lights_club_recessed zm_transit 11 1 11";
    l[l.size] = "p6_lights_club_recessed_fx_shell so_zclassic_zm_transit 7 1 7";
    l[l.size] = "p6_lights_club_recessed_fx_shell2 so_zclassic_zm_transit 2 10 10";
    l[l.size] = "p6_lights_club_recessed_off zm_transit 11 1 11";
    l[l.size] = "p6_longtable_sink zm_transit_gump_farm 187 54 48";
    l[l.size] = "p6_monitor_small zm_transit_gump_powerstation 28 21 3";
    l[l.size] = "p6_monitor_support_1 zm_transit_gump_powerstation 7 24 9";
    l[l.size] = "p6_monitor_support_2 zm_transit_gump_powerstation 7 34 9";
    l[l.size] = "p6_monitor_support_slant zm_transit_gump_powerstation 7 17 9";
    l[l.size] = "p6_monsoon_crate_01_shell zm_transit_gump_powerstation 60 60 98";
    l[l.size] = "p6_pak_electric_box_set_03 zm_transit_gump_busstation 40 41 6";
    l[l.size] = "p6_pak_muddy_clothes_pile zm_transit_gump_busstation 40 7 53";
    l[l.size] = "p6_pak_veh_train_boxcar zm_transit_gump_powerstation 448 180 151";
    l[l.size] = "p6_plant_cornstalk_dmg_128 zm_transit_gump_cornfield 48 8 133";
    l[l.size] = "p6_plant_cornstalk_lrg_dry zm_transit_gump_cornfield 54 169 57";
    l[l.size] = "p6_plant_cornstalk_lrg_row_256_dry zm_transit_gump_cornfield 289 174 72";
    l[l.size] = "p6_plant_cornstalk_lrg_row_256_dry_farm zm_transit_gump_farm 289 174 72";
    l[l.size] = "p6_plant_cornstalk_lrg_row_512_dry zm_transit_gump_cornfield 554 177 75";
    return l;
}

df_cat_data_09( l )
{
    l[l.size] = "p6_sink_motel zm_transit_gump_town 29 42 23";
    l[l.size] = "p6_sofa_damaged_panama zm_transit_gump_busstation 40 42 98";
    l[l.size] = "p6_sofa_damaged_trash_panama zm_transit_gump_busstation 40 48 98";
    l[l.size] = "p6_stanchion_post zm_transit_gump_busstation 14 42 14";
    l[l.size] = "p6_street_pole_sign_broken zm_transit_gump_busstation 118 81 9";
    l[l.size] = "p6_table_bunker zm_transit_gump_forest2 98 29 48";
    l[l.size] = "p6_table_bunker_sm zm_transit_gump_forest2 50 22 33";
    l[l.size] = "p6_valve_01_ceramic zm_transit_gump_powerstation 43 38 21";
    l[l.size] = "p6_window_frame_wood_white zm_transit_gump_farm 8 73 48";
    l[l.size] = "p6_window_frame_wood_white_diner zm_transit_gump_diner 8 73 48";
    l[l.size] = "p6_wood_plank_rustic01_2x12_96 zm_transit_gump_busstation 97 3 13";
    l[l.size] = "p6_wood_window_shutter_red_left zm_transit_gump_farm 4 76 27";
    l[l.size] = "p6_wood_window_shutter_red_right zm_transit_gump_farm 4 76 27";
    l[l.size] = "p6_zm_ball_return zm_transit_gump_town 26 43 173";
    l[l.size] = "p6_zm_bank_deposit_box_open_02 zm_transit 31 12 4";
    l[l.size] = "p6_zm_bank_deposit_box_open_02b zm_transit 31 31 6";
    l[l.size] = "p6_zm_bank_deposit_box_open_02c zm_transit 31 30 2";
    l[l.size] = "p6_zm_bank_deposit_box_open_03 zm_transit 31 12 28";
    l[l.size] = "p6_zm_bank_pilaster_1 zm_transit_gump_town 34 214 11";
    l[l.size] = "p6_zm_bank_teller_desk zm_transit_gump_town 11 36 20";
    l[l.size] = "p6_zm_bank_teller_window zm_transit_gump_town 6 48 33";
    l[l.size] = "p6_zm_bank_teller_window_d1 zm_transit_gump_town 6 48 33";
    l[l.size] = "p6_zm_bank_vault_door zm_transit 68 102 16";
    l[l.size] = "p6_zm_bank_vault_door_frame zm_transit 81 112 15";
    l[l.size] = "p6_zm_bank_vault_floor_hatch zm_transit 236 23 156";
    l[l.size] = "p6_zm_barbershop_window_01 zm_transit 60 112 14";
    l[l.size] = "p6_zm_barbershop_window_02 zm_transit_gump_town 60 106 16";
    l[l.size] = "p6_zm_barn_door_left zm_transit_gump_farm 96 192 8";
    l[l.size] = "p6_zm_barn_door_right zm_transit_gump_farm 96 192 8";
    l[l.size] = "p6_zm_barn_handrail_01 zm_transit_gump_farm 72 248 211";
    l[l.size] = "p6_zm_barn_handrail_02 zm_transit_gump_farm 86 42 164";
    l[l.size] = "p6_zm_barn_window zm_transit_gump_farm 8 64 64";
    l[l.size] = "p6_zm_bench_old zm_transit_gump_busstation 116 39 29";
    l[l.size] = "p6_zm_bench_old_town zm_transit_gump_town 116 39 29";
    l[l.size] = "p6_zm_bench_plastic zm_transit_gump_busstation 32 39 121";
    l[l.size] = "p6_zm_brick_clump_red zm_transit_gump_town 101 5 119";
    l[l.size] = "p6_zm_brick_clump_red_depot zm_transit_gump_busstation 101 5 119";
    l[l.size] = "p6_zm_brick_clump_red_power zm_transit_gump_powerstation 101 5 119";
    l[l.size] = "p6_zm_brick_clump_white zm_transit_gump_town 114 6 111";
    l[l.size] = "p6_zm_broken_asphault_debris zm_transit 81 8 80";
    return l;
}

df_cat_data_10( l )
{
    l[l.size] = "p6_zm_buildable_battery so_zclassic_zm_transit 16 14 9";
    l[l.size] = "p6_zm_buildable_etrap_base so_zclassic_zm_transit 60 47 22";
    l[l.size] = "p6_zm_buildable_etrap_tvtube so_zclassic_zm_transit 21 21 22";
    l[l.size] = "p6_zm_buildable_jetgun_engine so_zclassic_zm_transit 60 21 25";
    l[l.size] = "p6_zm_buildable_jetgun_guages so_zclassic_zm_transit 9 5 11";
    l[l.size] = "p6_zm_buildable_jetgun_handles so_zclassic_zm_transit 11 4 10";
    l[l.size] = "p6_zm_buildable_jetgun_wires so_zclassic_zm_transit 25 7 25";
    l[l.size] = "p6_zm_buildable_pap_body so_zclassic_zm_transit 59 37 25";
    l[l.size] = "p6_zm_buildable_pap_table so_zclassic_zm_transit 54 21 11";
    l[l.size] = "p6_zm_buildable_pswitch_body zm_transit 36 63 16";
    l[l.size] = "p6_zm_buildable_pswitch_hand zm_transit 9 8 9";
    l[l.size] = "p6_zm_buildable_pswitch_lever zm_transit 18 23 5";
    l[l.size] = "p6_zm_buildable_sq_electric_box zm_transit 13 20 4";
    l[l.size] = "p6_zm_buildable_sq_meteor zm_transit 5 5 6";
    l[l.size] = "p6_zm_buildable_sq_scaffolding zm_transit 83 4 24";
    l[l.size] = "p6_zm_buildable_sq_transceiver zm_transit 26 7 19";
    l[l.size] = "p6_zm_buildable_turbine_fan so_zclassic_zm_transit 25 10 25";
    l[l.size] = "p6_zm_buildable_turbine_mannequin so_zclassic_zm_transit 23 62 20";
    l[l.size] = "p6_zm_buildable_turbine_rudder so_zclassic_zm_transit 16 2 15";
    l[l.size] = "p6_zm_buildable_turret_ammo so_zclassic_zm_transit 5 8 7";
    l[l.size] = "p6_zm_buildable_turret_mower so_zclassic_zm_transit 37 20 26";
    l[l.size] = "p6_zm_building_rundown_01 zm_transit_gump_busstation 324 268 418";
    l[l.size] = "p6_zm_building_rundown_03 zm_transit_gump_busstation 324 268 337";
    l[l.size] = "p6_zm_catwalk_128_straight zm_transit_gump_powerstation 128 45 74";
    l[l.size] = "p6_zm_chain_fence_piece_end zm_transit 13 117 3";
    l[l.size] = "p6_zm_church_column zm_transit 20 320 32";
    l[l.size] = "p6_zm_church_column_tall zm_transit 20 432 32";
    l[l.size] = "p6_zm_church_window_large zm_transit 104 174 6";
    l[l.size] = "p6_zm_core_panel_01 zm_transit_gump_powerstation 26 93 151";
    l[l.size] = "p6_zm_core_panel_02 zm_transit_gump_powerstation 26 83 151";
    l[l.size] = "p6_zm_core_reactor_base zm_transit_gump_powerstation 305 193 305";
    l[l.size] = "p6_zm_core_reactor_floor_tile_a1 zm_transit_gump_powerstation 160 28 160";
    l[l.size] = "p6_zm_core_reactor_floor_tile_a1_labs zm_transit_gump_labs 160 28 160";
    l[l.size] = "p6_zm_core_reactor_floor_tile_a4_labs zm_transit_gump_labs 160 28 160";
    l[l.size] = "p6_zm_core_reactor_floor_tile_b1 zm_transit_gump_powerstation 160 28 160";
    l[l.size] = "p6_zm_core_reactor_floor_tile_b1_labs zm_transit_gump_labs 160 28 160";
    l[l.size] = "p6_zm_core_reactor_floor_tile_b2 zm_transit_gump_powerstation 160 28 160";
    l[l.size] = "p6_zm_core_reactor_floor_tile_b4 zm_transit_gump_powerstation 160 28 160";
    l[l.size] = "p6_zm_core_reactor_floor_tile_b5 zm_transit_gump_powerstation 80 28 160";
    l[l.size] = "p6_zm_core_reactor_floor_tile_b5_labs zm_transit_gump_labs 80 28 160";
    return l;
}

df_cat_data_11( l )
{
    l[l.size] = "p6_zm_core_reactor_roof zm_transit_gump_powerstation 416 51 388";
    l[l.size] = "p6_zm_core_reactor_roof_center zm_transit_gump_powerstation 353 57 354";
    l[l.size] = "p6_zm_core_reactor_room_lower_catwalk_a zm_transit_gump_powerstation 148 24 183";
    l[l.size] = "p6_zm_core_reactor_room_lower_catwalk_b zm_transit_gump_powerstation 172 24 172";
    l[l.size] = "p6_zm_core_reactor_room_stairs zm_transit_gump_powerstation 126 82 151";
    l[l.size] = "p6_zm_core_reactor_room_upper_catwalk_a zm_transit_gump_powerstation 217 25 421";
    l[l.size] = "p6_zm_core_reactor_room_upper_catwalk_b zm_transit_gump_powerstation 370 25 370";
    l[l.size] = "p6_zm_core_reactor_top zm_transit_gump_powerstation 165 192 165";
    l[l.size] = "p6_zm_depot_window_1 zm_transit 64 64 8";
    l[l.size] = "p6_zm_diner_window zm_transit_gump_diner 5 68 80";
    l[l.size] = "p6_zm_door_brokenwindow zm_transit 60 102 2";
    l[l.size] = "p6_zm_door_security_depot zm_transit 59 100 3";
    l[l.size] = "p6_zm_door_tearin_wood01 zm_transit 60 55 8";
    l[l.size] = "p6_zm_farm_chickencoop zm_transit_gump_farm 116 172 212";
    l[l.size] = "p6_zm_farm_trough zm_transit_gump_farm 68 46 164";
    l[l.size] = "p6_zm_garage_door_01 zm_transit 3 124 88";
    l[l.size] = "p6_zm_gas_sign_01 zm_transit_gump_diner 177 96 107";
    l[l.size] = "p6_zm_gasstation_oilrack zm_transit_gump_diner 48 56 32";
    l[l.size] = "p6_zm_highway_sign zm_transit_gump_tunnel 369 148 39";
    l[l.size] = "p6_zm_keys zm_transit 11 7 4";
    l[l.size] = "p6_zm_kiosk zm_transit_gump_busstation 145 163 37";
    l[l.size] = "p6_zm_magazines_rack zm_transit_gump_busstation 46 61 10";
    l[l.size] = "p6_zm_magazines_rack_town zm_transit_gump_town 46 61 10";
    l[l.size] = "p6_zm_monitor_table_01 zm_transit_gump_powerstation 96 32 36";
    l[l.size] = "p6_zm_monitor_table_display_01 zm_transit_gump_powerstation 72 28 15";
    l[l.size] = "p6_zm_open_power_panel zm_transit_gump_powerstation 34 61 8";
    l[l.size] = "p6_zm_outhouse zm_transit_gump_busstation 92 125 100";
    l[l.size] = "p6_zm_picture01 zm_transit_gump_town 50 50 1";
    l[l.size] = "p6_zm_picture02 zm_transit_gump_town 43 43 1";
    l[l.size] = "p6_zm_picture03 zm_transit_gump_town 43 35 1";
    l[l.size] = "p6_zm_pipe_ring_panel_01 zm_transit_gump_powerstation 74 52 40";
    l[l.size] = "p6_zm_pipe_ring_panel_02 zm_transit_gump_powerstation 69 52 40";
    l[l.size] = "p6_zm_pipe_ring_panel_03 zm_transit_gump_powerstation 74 80 51";
    l[l.size] = "p6_zm_pool_table_lamp zm_transit_gump_town 38 40 82";
    l[l.size] = "p6_zm_power_station_pipe_2x256 zm_transit_gump_powerstation 256 2 2";
    l[l.size] = "p6_zm_power_station_pipe_2x256_tunnel zm_transit_gump_tunnel 256 2 2";
    l[l.size] = "p6_zm_power_station_pipe_ring zm_transit_gump_powerstation 911 140 911";
    l[l.size] = "p6_zm_power_station_railing zm_transit_gump_powerstation 723 40 724";
    l[l.size] = "p6_zm_power_station_railing_core zm_transit_gump_powerstation 462 40 462";
    l[l.size] = "p6_zm_power_station_railing_steps zm_transit_gump_powerstation 135 120 2";
    return l;
}

df_cat_data_12( l )
{
    l[l.size] = "p6_zm_power_station_railing_steps_labs zm_transit 135 120 2";
    l[l.size] = "p6_zm_quarantine_fence_01 zm_transit 142 98 3";
    l[l.size] = "p6_zm_quarantine_fence_02 zm_transit 142 98 3";
    l[l.size] = "p6_zm_quarantine_fence_03 zm_transit 142 98 3";
    l[l.size] = "p6_zm_rain_gutter_01 zm_transit_gump_farm 583 258 789";
    l[l.size] = "p6_zm_raingutter_clamp zm_transit 5 2 12";
    l[l.size] = "p6_zm_rocks_large_cluster_01 zm_transit 957 256 800";
    l[l.size] = "p6_zm_rocks_medium_05 zm_transit 395 176 308";
    l[l.size] = "p6_zm_rocks_small_cluster_01 zm_transit 189 29 81";
    l[l.size] = "p6_zm_rocks_small_cluster_03 zm_transit 88 16 77";
    l[l.size] = "p6_zm_score_table zm_transit_gump_town 30 36 30";
    l[l.size] = "p6_zm_screecher_hole so_zclassic_zm_transit 108 18 105";
    l[l.size] = "p6_zm_shoe_rack zm_transit_gump_town 106 99 17";
    l[l.size] = "p6_zm_sign_bank zm_transit_gump_town 6 20 86";
    l[l.size] = "p6_zm_sign_bookstore zm_transit_gump_town 112 30 26";
    l[l.size] = "p6_zm_sign_bowling_large zm_transit_gump_town 128 243 24";
    l[l.size] = "p6_zm_sign_bowling_small zm_transit_gump_town 89 61 7";
    l[l.size] = "p6_zm_sign_bus_rooftop zm_transit_gump_busstation 32 220 140";
    l[l.size] = "p6_zm_sign_church zm_transit_gump_town 78 70 8";
    l[l.size] = "p6_zm_sign_deptstore zm_transit_gump_town 386 93 73";
    l[l.size] = "p6_zm_sign_diner zm_transit_gump_diner 539 399 82";
    l[l.size] = "p6_zm_sign_diner_24hrs zm_transit_gump_diner 128 94 43";
    l[l.size] = "p6_zm_sign_diner_base zm_transit_gump_diner 160 22 96";
    l[l.size] = "p6_zm_sign_diner_rooftop zm_transit_gump_diner 447 155 138";
    l[l.size] = "p6_zm_sign_diner_supports zm_transit_gump_diner 115 295 26";
    l[l.size] = "p6_zm_sign_laundromat zm_transit_gump_town 89 61 7";
    l[l.size] = "p6_zm_sign_neon_bar zm_transit_gump_town 112 42 16";
    l[l.size] = "p6_zm_sign_neon_bowling zm_transit_gump_town 114 43 5";
    l[l.size] = "p6_zm_sign_neon_bowling_flicker zm_transit_gump_town 114 43 5";
    l[l.size] = "p6_zm_sign_neon_loans zm_transit_gump_town 26 254 144";
    l[l.size] = "p6_zm_sign_neon_open zm_transit_gump_town 43 19 3";
    l[l.size] = "p6_zm_sign_restrooms zm_transit_gump_busstation 72 12 2";
    l[l.size] = "p6_zm_sign_terminal zm_transit_gump_busstation 144 22 2";
    l[l.size] = "p6_zm_sign_tickets zm_transit_gump_busstation 56 12 2";
    l[l.size] = "p6_zm_silo zm_transit_gump_farm 272 943 256";
    l[l.size] = "p6_zm_station_pipes_01 zm_transit_gump_powerstation 84 77 16";
    l[l.size] = "p6_zm_street_power_pole zm_transit_gump_busstation 166 532 166";
    l[l.size] = "p6_zm_town_window_01 zm_transit 40 68 4";
    l[l.size] = "p6_zm_tunnel_pillar_1 zm_transit 56 252 128";
    l[l.size] = "p6_zm_water_tower zm_transit_gump_busstation 281 552 267";
    return l;
}

df_cat_data_13( l )
{
    l[l.size] = "p6_zm_weapon_locker zm_transit_gump_farm 49 75 39";
    l[l.size] = "p6_zm_wind_turbine zm_transit_gump_cornfield 30 350 54";
    l[l.size] = "p6_zm_wind_turbine_rotor zm_transit_gump_cornfield 311 270 20";
    l[l.size] = "p6_zm_window_dest_glass_big zm_transit 0 178 126";
    l[l.size] = "p6_zm_window_dest_glass_big_broken zm_transit 1 27 126";
    l[l.size] = "p6_zm_window_dest_glass_small zm_transit 1 78 44";
    l[l.size] = "p6_zm_window_dest_glass_small_broken zm_transit 1 12 44";
    l[l.size] = "p6_zm_work_bench zm_transit 31 44 88";
    l[l.size] = "p_cub_barstool zm_transit_gump_town 16 31 16";
    l[l.size] = "p_cub_door01_wood_fullsize zm_transit 60 102 8";
    l[l.size] = "p_cub_door_wood_frame01 zm_transit_gump_town 68 128 8";
    l[l.size] = "p_dest_electric_panel01_base zm_transit_gump_powerstation 50 100 6";
    l[l.size] = "p_dest_electric_panel01_lid01 zm_transit_gump_powerstation 1 12 8";
    l[l.size] = "p_dest_electric_panel01_lid02 zm_transit_gump_powerstation 2 10 11";
    l[l.size] = "p_dest_electric_panel02_base zm_transit_gump_powerstation 7 96 24";
    l[l.size] = "p_dest_electric_panel02_lid01 zm_transit_gump_powerstation 2 19 10";
    l[l.size] = "p_dest_electric_panel04_base zm_transit_gump_powerstation 2 10 10";
    l[l.size] = "p_dest_electric_panel04_lid01 zm_transit_gump_powerstation 1 10 10";
    l[l.size] = "p_dest_electrical_transformer01_dest zm_transit_gump_powerstation 79 128 93";
    l[l.size] = "p_eb_lg_suitcase zm_transit_gump_busstation 39 27 13";
    l[l.size] = "p_eb_med_suitcase zm_transit_gump_busstation 28 20 32";
    l[l.size] = "p_ger_folding_chair zm_transit_gump_farm 22 40 25";
    l[l.size] = "p_glo_barbed_wire05 zm_transit_gump_farm 6 43 4";
    l[l.size] = "p_glo_barbed_wire06 zm_transit_gump_farm 108 43 9";
    l[l.size] = "p_glo_bathroom_sink zm_transit_gump_diner 28 35 28";
    l[l.size] = "p_glo_bathroom_toilet zm_transit_gump_diner 41 38 25";
    l[l.size] = "p_glo_bookshelf_wide_d zm_transit_gump_town 40 110 111";
    l[l.size] = "p_glo_bookshelf_wide_d_forest2 zm_transit_gump_forest2 40 110 111";
    l[l.size] = "p_glo_bucket_metal zm_transit_gump_forest2 14 15 15";
    l[l.size] = "p_glo_bucket_metal_farm zm_transit_gump_farm 14 15 15";
    l[l.size] = "p_glo_cans_multiple zm_transit_gump_diner 16 6 8";
    l[l.size] = "p_glo_cardboardbox_1 zm_transit_gump_powerstation 30 22 21";
    l[l.size] = "p_glo_cinder_block zm_transit 16 8 8";
    l[l.size] = "p_glo_coiledwire zm_transit_gump_diner 46 78 13";
    l[l.size] = "p_glo_corrugated_metal4x8_holes zm_transit 48 96 1";
    l[l.size] = "p_glo_electrical_pipes_45deg zm_transit_gump_busstation 3 1 4";
    l[l.size] = "p_glo_electrical_pipes_90deg zm_transit_gump_labs 3 1 3";
    l[l.size] = "p_glo_electrical_pipes_90deg_depot zm_transit_gump_busstation 3 1 3";
    l[l.size] = "p_glo_electrical_pipes_long zm_transit_gump_labs 5 2 72";
    l[l.size] = "p_glo_electrical_pipes_long_depot zm_transit_gump_busstation 5 2 72";
    return l;
}

df_cat_data_14( l )
{
    l[l.size] = "p_glo_electrical_pipes_short zm_transit_gump_labs 5 2 24";
    l[l.size] = "p_glo_electrical_pipes_short_depot zm_transit_gump_busstation 5 2 24";
    l[l.size] = "p_glo_electrical_pipes_t zm_transit_gump_busstation 3 1 2";
    l[l.size] = "p_glo_gascan zm_transit_gump_diner 7 18 14";
    l[l.size] = "p_glo_light_fluorescent_yellow_damaged_depot zm_transit_gump_busstation 13 5 55";
    l[l.size] = "p_glo_light_fluorescent_yellow_damaged_diner zm_transit_gump_diner 13 5 55";
    l[l.size] = "p_glo_light_fluorescent_yellow_damaged_town zm_transit_gump_town 13 5 55";
    l[l.size] = "p_glo_light_fluorescent_yellow_damaged_tunnel zm_transit_gump_tunnel 13 5 55";
    l[l.size] = "p_glo_lights_fluorescent_yellow zm_transit 13 4 55";
    l[l.size] = "p_glo_lights_fluorescent_yellow_on_depot zm_transit_gump_busstation 13 4 55";
    l[l.size] = "p_glo_lights_fluorescent_yellow_on_diner zm_transit_gump_diner 13 4 55";
    l[l.size] = "p_glo_lights_fluorescent_yellow_on_town zm_transit_gump_town 13 4 55";
    l[l.size] = "p_glo_lights_fluorescent_yellow_on_tunnel zm_transit_gump_tunnel 13 4 55";
    l[l.size] = "p_glo_office_bookset1 zm_transit_gump_farm 12 14 12";
    l[l.size] = "p_glo_palette zm_transit_gump_powerstation 59 6 58";
    l[l.size] = "p_glo_powerline_tower_redwhite zm_transit 792 1885 443";
    l[l.size] = "p_glo_sandbags_green_lego_mdl zm_transit 26 44 64";
    l[l.size] = "p_glo_sandbags_green_long zm_transit_gump_farm 35 41 250";
    l[l.size] = "p_glo_sandbags_green_long_128x64_khe_sahn zm_transit_gump_farm 34 66 141";
    l[l.size] = "p_glo_static_berlin_couch zm_transit_gump_town 30 40 83";
    l[l.size] = "p_glo_street_light01 zm_transit_gump_town 18 192 18";
    l[l.size] = "p_glo_street_light01_fx_shell so_zclassic_zm_transit 14 10 14";
    l[l.size] = "p_glo_street_light01_on zm_transit_gump_town 18 192 18";
    l[l.size] = "p_glo_street_light02 zm_transit 73 209 29";
    l[l.size] = "p_glo_street_light02_on_light so_zclassic_zm_transit 14 4 14";
    l[l.size] = "p_glo_tools_axe zm_transit_gump_forest2 12 2 38";
    l[l.size] = "p_glo_tools_chest_short zm_transit 30 11 18";
    l[l.size] = "p_glo_tools_chest_tall zm_transit_gump_busstation 32 46 20";
    l[l.size] = "p_glo_tools_chest_tall_1 zm_transit_gump_diner 32 46 20";
    l[l.size] = "p_glo_tools_hoe zm_transit_gump_farm 10 6 65";
    l[l.size] = "p_glo_tools_rake zm_transit_gump_farm 20 4 58";
    l[l.size] = "p_glo_tools_saw zm_transit_gump_farm 6 0 29";
    l[l.size] = "p_glo_tools_shovel zm_transit_gump_farm 12 2 58";
    l[l.size] = "p_glo_tools_wheelbarrow zm_transit_gump_farm 32 23 69";
    l[l.size] = "p_glo_trashcan zm_transit_gump_busstation 26 35 26";
    l[l.size] = "p_glo_trashcan_diner zm_transit_gump_diner 26 35 26";
    l[l.size] = "p_glo_trashcan_town zm_transit_gump_town 26 35 26";
    l[l.size] = "p_glo_wall_vent_1 zm_transit_gump_labs 82 44 8";
    l[l.size] = "p_jun_ashtray zm_transit_gump_busstation 13 26 13";
    l[l.size] = "p_jun_ashtray_town zm_transit_gump_town 13 26 13";
    return l;
}

df_cat_data_15( l )
{
    l[l.size] = "p_jun_barbed_wire_cage zm_transit_gump_farm 34 21 84";
    l[l.size] = "p_jun_caution_sign zm_transit 43 84 58";
    l[l.size] = "p_jun_ceiling_fan zm_transit_gump_diner 57 32 57";
    l[l.size] = "p_jun_chickencoop zm_transit_gump_farm 32 23 51";
    l[l.size] = "p_jun_coffeepotold zm_transit_gump_diner 12 21 16";
    l[l.size] = "p_jun_dockpost_pow zm_transit_gump_farm 11 51 11";
    l[l.size] = "p_jun_int_table_lg zm_transit_gump_farm 97 38 50";
    l[l.size] = "p_jun_metal_shelves zm_transit_gump_diner 64 74 25";
    l[l.size] = "p_jun_metal_shelves_cornfield zm_transit_gump_cornfield 64 74 25";
    l[l.size] = "p_jun_metal_shelves_town zm_transit_gump_town 64 74 25";
    l[l.size] = "p_jun_old_tv zm_transit_gump_farm 27 34 20";
    l[l.size] = "p_jun_rebar01_single_dirty zm_transit_gump_town 3 76 2";
    l[l.size] = "p_jun_rebar02_single_dirty zm_transit_gump_busstation 2 24 9";
    l[l.size] = "p_jun_roof_vent zm_transit_gump_town 6 9 6";
    l[l.size] = "p_jun_rubble02 zm_transit_gump_powerstation 86 20 87";
    l[l.size] = "p_jun_storage_crate zm_transit_gump_farm 62 78 180";
    l[l.size] = "p_jun_storage_crate_forest2 zm_transit_gump_forest2 62 78 180";
    l[l.size] = "p_jun_woodbarrel_single zm_transit_gump_forest2 36 50 36";
    l[l.size] = "p_kow_trash_pile zm_transit_gump_town 78 40 40";
    l[l.size] = "p_lights_barefixture_off_depot zm_transit_gump_busstation 4 6 4";
    l[l.size] = "p_lights_barefixture_off_farm zm_transit_gump_farm 4 6 4";
    l[l.size] = "p_lights_barefixture_on zm_transit_gump_farm 4 6 4";
    l[l.size] = "p_lights_barefixture_on_power zm_transit_gump_powerstation 4 6 4";
    l[l.size] = "p_lights_cagelight02_red_off zm_transit 6 8 6";
    l[l.size] = "p_lights_hangingbulb_off zm_transit_gump_town 2 31 3";
    l[l.size] = "p_lights_hangingbulb_on_depot zm_transit_gump_busstation 2 31 2";
    l[l.size] = "p_lights_lantern_hang_on zm_transit_gump_farm 12 25 11";
    l[l.size] = "p_lights_lantern_hang_on_corn zm_transit_gump_cornfield 12 25 11";
    l[l.size] = "p_rus_ac_unit zm_transit_gump_busstation 131 78 109";
    l[l.size] = "p_rus_air_vent zm_transit_gump_town 47 66 47";
    l[l.size] = "p_rus_animal_cage_medium_01 zm_transit_gump_labs 43 40 40";
    l[l.size] = "p_rus_bathroom_papertowel zm_transit_gump_diner 16 27 5";
    l[l.size] = "p_rus_blinds02 zm_transit_gump_busstation 79 61 4";
    l[l.size] = "p_rus_blinds03 zm_transit_gump_busstation 79 89 11";
    l[l.size] = "p_rus_blinds04 zm_transit_gump_busstation 79 72 3";
    l[l.size] = "p_rus_bookcase_fncy zm_transit_gump_farm 61 102 24";
    l[l.size] = "p_rus_building_supports01 zm_transit_gump_powerstation 122 87 84";
    l[l.size] = "p_rus_bunker_wire01 zm_transit_gump_labs 16 9 64";
    l[l.size] = "p_rus_crate_metal_1 zm_transit_gump_labs 64 30 37";
    l[l.size] = "p_rus_crate_metal_2 zm_transit_gump_labs 32 31 37";
    return l;
}

df_cat_data_16( l )
{
    l[l.size] = "p_rus_desklamp_wmd_on zm_transit 6 21 17";
    l[l.size] = "p_rus_door_roller zm_transit 3 170 182";
    l[l.size] = "p_rus_door_white_frame_60 zm_transit_gump_diner 64 104 8";
    l[l.size] = "p_rus_door_white_plain_left zm_transit 60 102 9";
    l[l.size] = "p_rus_door_white_plain_right zm_transit 60 102 9";
    l[l.size] = "p_rus_door_white_window_plain_left zm_transit 60 102 9";
    l[l.size] = "p_rus_dumpster_zm_bstation zm_transit_gump_busstation 59 67 105";
    l[l.size] = "p_rus_dumpster_zm_town zm_transit_gump_town 59 67 105";
    l[l.size] = "p_rus_electric_boxes4 zm_transit_gump_labs 27 25 9";
    l[l.size] = "p_rus_electricalbox_01 zm_transit_gump_diner 15 18 6";
    l[l.size] = "p_rus_electricalbox_02 zm_transit_gump_busstation 23 17 5";
    l[l.size] = "p_rus_electricalbox_03 zm_transit_gump_farm 10 19 6";
    l[l.size] = "p_rus_electricalbox_04 zm_transit_gump_powerstation 18 41 6";
    l[l.size] = "p_rus_electricpanel_01 zm_transit_gump_town 49 100 6";
    l[l.size] = "p_rus_fuelstorage_tank_rusty_zm_farm zm_transit_gump_farm 136 156 239";
    l[l.size] = "p_rus_fuelstorage_tank_rusty_zm_gstation zm_transit_gump_diner 136 156 239";
    l[l.size] = "p_rus_handrail_yellow_128_double zm_transit_gump_tunnel 3 36 128";
    l[l.size] = "p_rus_handrail_yellow_256_double zm_transit_gump_tunnel 3 36 256";
    l[l.size] = "p_rus_handrail_yellow_32_double zm_transit_gump_tunnel 2 18 32";
    l[l.size] = "p_rus_handrail_yellow_64_end zm_transit_gump_tunnel 3 36 64";
    l[l.size] = "p_rus_lab_hall_break_win01 zm_transit_gump_labs 10 68 128";
    l[l.size] = "p_rus_locker_closed zm_transit_gump_busstation 27 72 20";
    l[l.size] = "p_rus_locker_door_a zm_transit_gump_busstation 23 33 3";
    l[l.size] = "p_rus_locker_door_b zm_transit_gump_busstation 23 33 3";
    l[l.size] = "p_rus_locker_open zm_transit_gump_busstation 27 72 19";
    l[l.size] = "p_rus_oven_iron_body zm_transit_gump_farm 31 128 37";
    l[l.size] = "p_rus_panel_pent_04 zm_transit_gump_labs 6 1 13";
    l[l.size] = "p_rus_pipes_modular_clampc zm_transit_gump_labs 13 21 21";
    l[l.size] = "p_rus_pipes_modular_valve zm_transit_gump_labs 37 21 44";
    l[l.size] = "p_rus_pneumatic_dolly zm_transit_gump_labs 73 52 39";
    l[l.size] = "p_rus_rb_lab_portable_curtain zm_transit_gump_labs 93 95 12";
    l[l.size] = "p_rus_rocket_wire_debris zm_transit_gump_powerstation 204 12 178";
    l[l.size] = "p_rus_rollup_door_120 zm_transit_gump_diner 31 83 133";
    l[l.size] = "p_rus_rollup_door_136 zm_transit_gump_busstation 17 19 142";
    l[l.size] = "p_rus_sign_biohazard zm_transit_gump_labs 13 13 1";
    l[l.size] = "p_rus_storage_cabinet zm_transit_gump_diner 26 72 32";
    l[l.size] = "p_rus_table_steel zm_transit_gump_diner 63 33 37";
    l[l.size] = "p_rus_tank_chemical_dmg zm_transit 48 88 47";
    l[l.size] = "p_rus_tank_large_midsection zm_transit_gump_farm 296 96 296";
    l[l.size] = "p_rus_tank_large_rooftop zm_transit_gump_farm 306 99 306";
    return l;
}

df_cat_data_17( l )
{
    l[l.size] = "p_rus_window01_nosnow zm_transit_gump_powerstation 128 80 8";
    l[l.size] = "p_rus_window03_nosnow zm_transit_gump_powerstation 128 80 50";
    l[l.size] = "p_rus_wires_modular_straight_256 zm_transit_gump_labs 256 25 51";
    l[l.size] = "p_rus_wires_modular_straight_256_pstation zm_transit_gump_powerstation 256 25 51";
    l[l.size] = "p_rus_wmd_glo_vent_support zm_transit_gump_labs 24 62 3";
    l[l.size] = "p_us_fireplace_screen_tools zm_transit_gump_forest2 27 17 4";
    l[l.size] = "p_zom_barrel_02 zm_transit_gump_labs 31 44 31";
    l[l.size] = "p_zom_barrel_02_clean zm_transit_gump_powerstation 31 44 31";
    l[l.size] = "p_zom_clock zm_transit_gump_busstation 47 47 6";
    l[l.size] = "p_zom_clock_diner zm_transit_gump_diner 47 47 6";
    l[l.size] = "p_zom_clock_hourhand zm_transit 1 15 0";
    l[l.size] = "p_zom_clock_minhand zm_transit 1 22 0";
    l[l.size] = "p_zom_clock_town zm_transit_gump_town 47 47 6";
    l[l.size] = "p_zom_fence_chainlink zm_transit_gump_diner 130 117 14";
    l[l.size] = "p_zom_moon_lab_vent_3x3 zm_transit_gump_powerstation 216 42 60";
    l[l.size] = "paris_kitchen_counter_a zm_transit_gump_diner 44 37 32";
    l[l.size] = "paris_kitchen_counter_b zm_transit_gump_diner 41 37 30";
    l[l.size] = "paris_kitchen_plates_broken_01 zm_transit_gump_diner 30 4 13";
    l[l.size] = "paris_kitchen_plates_broken_02 zm_transit_gump_diner 32 3 28";
    l[l.size] = "paris_kitchen_plates_broken_03 zm_transit_gump_diner 18 1 23";
    l[l.size] = "pb_couch zm_transit_gump_farm 30 40 83";
    l[l.size] = "pb_pole_telephone_bulb zm_transit 9 8 9";
    l[l.size] = "prefab_berlin_phone_pole zm_transit_gump_cornfield 15 416 134";
    l[l.size] = "projectile_m203grenade zm_transit 3 2 2";
    l[l.size] = "rb_fence02 zm_transit_gump_town 120 92 6";
    l[l.size] = "rb_fence06 zm_transit_gump_farm 120 58 7";
    l[l.size] = "skybox_zm_transit zm_transit 1567 640 1567";
    l[l.size] = "static_peleliu_filecabinet_metal zm_transit_gump_cornfield 18 64 30";
    l[l.size] = "storefront_door02_window zm_transit 60 102 6";
    l[l.size] = "t5_foliage_bush05 zm_transit 155 151 168";
    l[l.size] = "t5_foliage_shrubs02 zm_transit 226 73 149";
    l[l.size] = "t5_foliage_tree_burnt02 zm_transit 448 472 423";
    l[l.size] = "t5_foliage_tree_burnt03 zm_transit 686 695 658";
    l[l.size] = "t6_attach_fastmag_chicom_view zm_transit 3 8 2";
    l[l.size] = "t6_attach_fastmag_chicom_world zm_transit 3 8 2";
    l[l.size] = "t6_attach_fastmag_saiga_view zm_transit 6 12 3";
    l[l.size] = "t6_attach_fastmag_saiga_world zm_transit 5 11 2";
    l[l.size] = "t6_attach_gl_m203_m16_view zm_transit 14 6 2";
    l[l.size] = "t6_attach_gl_m203_m16_world zm_transit 17 6 2";
    l[l.size] = "t6_attach_gl_m320_view zm_transit 18 7 2";
    return l;
}

df_cat_data_18( l )
{
    l[l.size] = "t6_attach_gl_m320_world zm_transit 11 7 2";
    l[l.size] = "t6_attach_grip_view zm_transit 2 4 1";
    l[l.size] = "t6_attach_grip_world zm_transit 2 4 1";
    l[l.size] = "t6_attach_mag_ak_view zm_transit 5 8 1";
    l[l.size] = "t6_attach_mag_ak_world zm_transit 5 8 1";
    l[l.size] = "t6_attach_mag_chicom_view zm_transit 2 7 1";
    l[l.size] = "t6_attach_mag_chicom_world zm_transit 2 7 1";
    l[l.size] = "t6_attach_mag_dsr50_view zm_transit 5 4 2";
    l[l.size] = "t6_attach_mag_dsr50_world zm_transit 5 4 2";
    l[l.size] = "t6_attach_mag_fal_view zm_transit 3 7 1";
    l[l.size] = "t6_attach_mag_fal_world zm_transit 3 6 1";
    l[l.size] = "t6_attach_mag_galil_view zm_transit 5 9 1";
    l[l.size] = "t6_attach_mag_galil_world zm_transit 5 9 1";
    l[l.size] = "t6_attach_mag_hamr_view zm_transit 3 8 6";
    l[l.size] = "t6_attach_mag_hamr_world zm_transit 4 8 6";
    l[l.size] = "t6_attach_mag_m14_view zm_transit 3 5 1";
    l[l.size] = "t6_attach_mag_m14_world zm_transit 3 5 1";
    l[l.size] = "t6_attach_mag_m16_view zm_transit 3 5 1";
    l[l.size] = "t6_attach_mag_m16_world zm_transit 3 4 1";
    l[l.size] = "t6_attach_mag_m82_view zm_transit 6 7 1";
    l[l.size] = "t6_attach_mag_m82_world zm_transit 5 6 1";
    l[l.size] = "t6_attach_mag_mp5_view zm_transit 4 8 1";
    l[l.size] = "t6_attach_mag_mp5_world zm_transit 4 8 1";
    l[l.size] = "t6_attach_mag_saiga_view zm_transit 5 10 1";
    l[l.size] = "t6_attach_mag_saiga_world zm_transit 5 10 1";
    l[l.size] = "t6_attach_mag_saritch_view zm_transit 3 6 1";
    l[l.size] = "t6_attach_mag_saritch_world zm_transit 3 6 1";
    l[l.size] = "t6_attach_mag_type95_view zm_transit 6 9 1";
    l[l.size] = "t6_attach_mag_type95_world zm_transit 6 8 1";
    l[l.size] = "t6_attach_mag_usrpg_world zm_transit 23 3 3";
    l[l.size] = "t6_attach_mag_x95l_view zm_transit 4 9 1";
    l[l.size] = "t6_attach_mag_x95l_world zm_transit 4 8 1";
    l[l.size] = "t6_attach_mag_xm8_view zm_transit 4 8 1";
    l[l.size] = "t6_attach_mag_xm8_world zm_transit 4 8 1";
    l[l.size] = "t6_attach_optic_acog_view zm_transit 5 2 2";
    l[l.size] = "t6_attach_optic_acog_world zm_transit 5 2 2";
    l[l.size] = "t6_attach_optic_aimpoint_view zm_transit 4 2 1";
    l[l.size] = "t6_attach_optic_aimpoint_world zm_transit 4 2 1";
    l[l.size] = "t6_attach_optic_combo_view zm_transit 5 3 2";
    l[l.size] = "t6_attach_optic_combo_world zm_transit 5 3 2";
    return l;
}

df_cat_data_19( l )
{
    l[l.size] = "t6_attach_optic_holo_zmb_ads zm_transit 3 2 2";
    l[l.size] = "t6_attach_optic_holo_zmb_view zm_transit 3 2 2";
    l[l.size] = "t6_attach_optic_holo_zmb_world zm_transit 3 2 2";
    l[l.size] = "t6_attach_optic_kobra_view zm_transit 5 5 2";
    l[l.size] = "t6_attach_optic_kobra_world zm_transit 5 5 2";
    l[l.size] = "t6_attach_optic_m32_ads zm_transit 4 2 1";
    l[l.size] = "t6_attach_optic_m32_view zm_transit 4 2 1";
    l[l.size] = "t6_attach_optic_mms_view zm_transit 2 2 3";
    l[l.size] = "t6_attach_optic_mms_world zm_transit 3 2 3";
    l[l.size] = "t6_attach_optic_rangefinder_ads zm_transit 4 2 2";
    l[l.size] = "t6_attach_optic_rangefinder_view zm_transit 4 2 2";
    l[l.size] = "t6_attach_optic_rangefinder_world zm_transit 6 3 3";
    l[l.size] = "t6_attach_optic_reflex_view zm_transit 3 2 2";
    l[l.size] = "t6_attach_optic_reflex_world zm_transit 3 2 2";
    l[l.size] = "t6_attach_optic_vzoom_80s_view zm_transit 16 3 2";
    l[l.size] = "t6_attach_optic_vzoom_80s_world zm_transit 16 3 2";
    l[l.size] = "t6_attach_pistol_fastmag_view zm_transit 3 2 2";
    l[l.size] = "t6_attach_pistol_fastmag_world zm_transit 3 2 2";
    l[l.size] = "t6_attach_sniper_silencer1_view zm_transit 13 3 3";
    l[l.size] = "t6_attach_sniper_silencer1_world zm_transit 10 2 2";
    l[l.size] = "t6_attach_speedloader_view zm_transit 5 3 3";
    l[l.size] = "tag_flash zm_transit 2 4 3";
    l[l.size] = "tag_flash zm_transit_patch 2 4 3";
    l[l.size] = "undr_locker_military_red zm_transit_gump_labs 42 78 31";
    l[l.size] = "usa_sign_deercrossing zm_transit_gump_town 38 38 0";
    l[l.size] = "veh_t6_civ_60s_coupe_dead zm_transit 208 59 86";
    l[l.size] = "veh_t6_civ_bus_zombie zm_transit 545 156 155";
    l[l.size] = "veh_t6_civ_bus_zombie_brakelights so_zclassic_zm_transit 2 8 83";
    l[l.size] = "veh_t6_civ_bus_zombie_cow_catcher so_zclassic_zm_transit 69 44 148";
    l[l.size] = "veh_t6_civ_bus_zombie_flashing_lights so_zclassic_zm_transit 458 12 99";
    l[l.size] = "veh_t6_civ_bus_zombie_headlights so_zclassic_zm_transit 455 96 115";
    l[l.size] = "veh_t6_civ_bus_zombie_roof_hatch zm_transit 109 33 59";
    l[l.size] = "veh_t6_civ_bus_zombie_turnsignal_left so_zclassic_zm_transit 462 11 7";
    l[l.size] = "veh_t6_civ_bus_zombie_turnsignal_right so_zclassic_zm_transit 462 11 7";
    l[l.size] = "veh_t6_civ_microbus_dead zm_transit 195 83 94";
    l[l.size] = "veh_t6_civ_movingtrk_cab_dead zm_transit 274 145 139";
    l[l.size] = "veh_t6_civ_smallwagon_dead zm_transit 153 71 86";
    l[l.size] = "vehicle_tractor_2 zm_transit_gump_farm 134 105 92";
    l[l.size] = "weapon_parabolic_knife zm_transit 15 2 1";
    l[l.size] = "weapon_usa_ray_gun zm_transit 17 9 4";
    return l;
}

df_cat_data_20( l )
{
    l[l.size] = "weapon_zombie_monkey_bomb zm_transit 17 19 11";
    l[l.size] = "world_dw_knife_bowie zm_transit 10 25 2";
    l[l.size] = "world_knife_bowie zm_transit 26 5 1";
    l[l.size] = "yieldsign_01 zm_transit_gump_town 39 123 4";
    l[l.size] = "zm_awning_01_blue zm_transit_gump_town 229 56 57";
    l[l.size] = "zm_awning_01_stripe zm_transit_gump_town 229 56 57";
    l[l.size] = "zm_awning_02_blue zm_transit_gump_town 153 56 57";
    l[l.size] = "zm_t6_civ_movingtrk_box_dead zm_transit 161 126 128";
    l[l.size] = "zombie_ammocan so_zclassic_zm_transit 24 13 8";
    l[l.size] = "zombie_carpenter so_zclassic_zm_transit 13 30 9";
    l[l.size] = "zombie_metal_door_right zm_transit_gump_powerstation 61 121 11";
    l[l.size] = "zombie_meteor_chunk_sml2 zm_transit_gump_busstation 18 11 24";
    l[l.size] = "zombie_modular_wires_lg zm_transit_gump_powerstation 128 16 25";
    l[l.size] = "zombie_pickup_perk_bottle so_zclassic_zm_transit 4 13 4";
    l[l.size] = "zombie_sign_please_wait zm_transit 20 22 0";
    l[l.size] = "zombie_skull common_zm 16 23 21";
    l[l.size] = "zombie_teddybear zm_transit 11 26 17";
    l[l.size] = "zombie_theater_folded_chair zm_transit_gump_farm 22 46 4";
    l[l.size] = "zombie_vending_doubletap2 zm_transit 53 91 25";
    l[l.size] = "zombie_vending_doubletap2_on zm_transit 53 91 25";
    l[l.size] = "zombie_vending_jugg zm_transit 30 100 37";
    l[l.size] = "zombie_vending_jugg_on zm_transit 30 100 37";
    l[l.size] = "zombie_vending_marathon zm_transit 46 88 27";
    l[l.size] = "zombie_vending_marathon_on zm_transit 46 88 27";
    l[l.size] = "zombie_vending_revive zm_transit 49 85 35";
    l[l.size] = "zombie_vending_revive_on zm_transit 49 85 35";
    l[l.size] = "zombie_vending_sleight zm_transit 51 104 32";
    l[l.size] = "zombie_vending_sleight_on zm_transit 51 104 32";
    l[l.size] = "zombie_vending_tombstone zm_transit 54 113 30";
    l[l.size] = "zombie_vending_tombstone_on zm_transit 54 113 30";
    l[l.size] = "zombie_x2_icon common_zm 22 16 3";
    l[l.size] = "zombie_z_money_icon so_zclassic_zm_transit 22 23 3";
    return l;
}

