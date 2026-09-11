// Dead Frequency - compatibility layer: vanilla TranZit Easter Egg OFF, returning-player state,
// co-installed loose scripts (zm_transit_enhanced_noee.gsc, zm_scavenger.gsc).
//
// The vanilla quest lives in maps\mp\zm_transit_sq.gsc (line numbers below refer to the decompiled
// file). Two mechanisms, both needed because a loose script's init() runs after the map's main()
// chain has started, so some vanilla threads are already parked on flags when we get here:
//   1. replaceFunc on the functions vanilla calls AFTER our init(): the two side quests (threaded by
//      sidequest_main on every power change), the stat writer, and sidequest_main itself (effective
//      only when our init() wins the race against zm_transit_classic.gsc:94).
//   2. level.maxcompleted = level.richcompleted = 1 once the round logic starts: every vanilla quest
//      line goes through maxissay() (:991) / richtofensay() (:945), which return at once when their
//      side is "completed". This also mutes te_richtofensay in zm_transit_enhanced_noee.gsc (same
//      check) without a second replaceFunc on richtofensay, which that script already owns.
// What survives on purpose: the NavCard (init_navcard :1343), the NavCard table (sq_common buildable,
// zm_transit_buildables.gsc:135-153) with its reader (navcomputer_waitfor_navcard :1418) and its two
// stats, the bar TV radio (survivor_vox :1048), and level.sq_progress (read by enhanced_noee).
// Full audit table: tools/polish_compat.md.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_systems;

// Called synchronously from df_main::init(), before any wait.
df_compat_init()
{
    level thread df_bus_parts_pin();   // owner 2026-09-11: ladder at the Depot, hatch at the Diner
    level thread df_knuckles_price();  // owner 2026-09-11: Galvaknuckles 3000
    // sidequest_main() (:140) reads sq_transit_last_completed and relights the tower for returning
    // players; our copy does neither. Harmless if vanilla's copy is already running (see below).
    replaceFunc( maps\mp\zm_transit_sq::sidequest_main, ::df_compat_sidequest_main );

    // Both quests are threaded by sidequest_main after start_zombie_round_logic (:183, :196), i.e.
    // after this init(): the no-op always wins. This removes stages A/B/C of both sides, their
    // dialogue threads (wait_for_richtoffen_intro :582, lure/light hints :678/:736), the client
    // fields sq_tower_sparks / screecher_maxis_lights / screecher_sq_lights (:418-419, :660, :763)
    // and the completion sequences (tower colour, powerup drops :541/:804).
    replaceFunc( maps\mp\zm_transit_sq::maxis_sidequest, ::df_noop );
    replaceFunc( maps\mp\zm_transit_sq::richtofen_sidequest, ::df_noop );

    // Every sq_transit_* stat write goes through here; only the NavCard-table stats pass.
    replaceFunc( maps\mp\zm_transit_sq::update_sidequest_stats, ::df_vanilla_stats_filter );

    level thread df_compat_mute_vanilla();
    level thread df_compat_debug_listener();
}

df_noop()
{
}

// Replacement for zm_transit_sq::sidequest_main (:140). Effective only if our init() ran before
// zm_transit_classic.gsc:94 threaded the original; otherwise the original is already parked on the
// flag and df_compat_mute_vanilla catches up 0.05 s after it. Keeps level.sq_progress
// (sidequest_init_tracker :204) because zm_transit_enhanced_noee.gsc indexes it (:497, :1420).
df_compat_sidequest_main()
{
    maps\mp\zm_transit_sq::sidequest_init_tracker();
    flag_wait( "start_zombie_round_logic" );
    df_compat_mark_vanilla_done();
    df_debug_print( "DF: vanilla sidequest_main replaced (no stat read, tower dark)" );
}

// Fallback for the case where vanilla's sidequest_main is the one running: it resets both completed
// flags right after start_zombie_round_logic (:144-145), reads sq_transit_last_completed and, for a
// player whose stat says "completed", relights the tower with clientnotify sqrc/sqmc at +0 s and
// +1 s (:165-172 -> zm_transit_classic.csc:33 sidequest_complete_watch). We overwrite the flags one
// frame later and kill the client loops after both notifies have gone out (the tower is far from
// the spawn, nobody sees the two seconds it may glow).
df_compat_mute_vanilla()
{
    level endon( "end_game" );

    flag_wait( "start_zombie_round_logic" );
    wait 0.05;
    df_compat_mark_vanilla_done();

    wait 2.5;
    df_compat_tower_dark();
    wait 3;
    df_compat_tower_dark();
}

// Both vanilla sides "completed": maxissay()/richtofensay()/te_richtofensay return early, so the
// power on/off/EMP lines of richtofen_sidequest_power_state (:590-605), the intro (:193), the
// ambient Maxis hints (avogadro_far_from_tower :1194, avogadro_is_near_tower :1241,
// avogadro_stab_watch :1230, avogadro_stunned_vo :1450, transit_buildable_vo_override
// zm_transit.gsc:3326), the terminal lines of sidequest_logic (:118, :132) and the jet gun line of
// builable_built_custom_func (:1114) all fall silent.
// sq_progress["rich"]["A_jetgun_tower"] = 1 closes the jet-gun-under-the-tower branch that
// zm_transit_enhanced_noee.gsc:497 re-implements outside richtofen_sidequest_a (it would set the
// client field screecher_sq_lights, i.e. the blue "sidequest" lamp fx + zmb_safety_light_sidequest).
df_compat_mark_vanilla_done()
{
    level.maxcompleted = 1;
    level.richcompleted = 1;

    if ( !isdefined( level.sq_progress ) || !isdefined( level.sq_progress["rich"] ) )
        maps\mp\zm_transit_sq::sidequest_init_tracker();

    level.sq_progress["rich"]["A_jetgun_tower"] = 1;
}

// Kills the vanilla client tower loops: runners end on "sq_kfx" (zm_transit_classic.csc:55),
// lightning on "sqkl" (:81). df_tower_fx_start sends the same two before drawing its own.
df_compat_tower_dark()
{
    clientnotify( "sq_kfx" );
    clientnotify( "sqkl" );
}

// Replacement for zm_transit_sq::update_sidequest_stats (:894). Vanilla writes every stage / reset /
// complete stat of both sides through it; only the two NavCard-table branches survive:
//   "sq_transit_started"         (:113, table built) -> per-player stat read by init_navcomputer
//                                 (:1379): the table is pre-built in later games, as in vanilla.
//   "navcard_applied_zm_transit" (:1437, card accepted) -> navcard_needed cleared + HUD refresh.
// Everything else returns, so the vanilla quest can never write sq_transit_rich_* / sq_transit_maxis_*;
// the finale writes the completion stat itself (df_systems::df_write_completion_stat).
df_vanilla_stats_filter( stat_name )
{
    if ( stat_name != "navcard_applied_zm_transit" && stat_name != "sq_transit_started" )
        return;

    foreach ( player in getplayers() )
    {
        if ( stat_name == "sq_transit_started" )
            player.transit_sq_started = 1;
        else
            player maps\mp\zombies\_zm_stats::set_global_stat( level.navcard_needed, 0 );

        player maps\mp\zombies\_zm_stats::increment_client_stat( stat_name, 0 );
    }

    if ( stat_name == "navcard_applied_zm_transit" )
        level thread maps\mp\zm_transit_sq::sq_refresh_player_navcard_hud();

    df_debug_print( "DF: vanilla stat kept: " + stat_name );
}

// `!df fire compat` -> one console/screen dump of the vanilla state this file controls and of what
// each player has on disk (stats read the same way vanilla reads them, _zm_stats::get_global_stat).
df_compat_debug_listener()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "df_debug_compat" );
        df_compat_debug_dump();
    }
}

df_compat_debug_dump()
{
    df_debug_print( "DF compat: richcompleted " + df_compat_flag_str( level.richcompleted ) + " maxcompleted " + df_compat_flag_str( level.maxcompleted ) );

    jet = "n/a";

    if ( isdefined( level.sq_progress ) && isdefined( level.sq_progress["rich"] ) && isdefined( level.sq_progress["rich"]["A_jetgun_tower"] ) )
        jet = "" + level.sq_progress["rich"]["A_jetgun_tower"];

    df_debug_print( "DF compat: sq_progress rich A_jetgun_tower " + jet + " | enhanced_noee " + df_compat_flag_str( level.te_active ) + " | scavenger " + df_compat_flag_str( isdefined( level.mc_gated_buildables ) ) );

    foreach ( player in getplayers() )
    {
        line = player.name + ": last_completed " + player maps\mp\zombies\_zm_stats::get_global_stat( "sq_transit_last_completed" );
        line = line + " started " + player maps\mp\zombies\_zm_stats::get_global_stat( "sq_transit_started" );
        line = line + " card_held " + player maps\mp\zombies\_zm_stats::get_global_stat( "navcard_held_zm_transit" );
        line = line + " card_applied " + player maps\mp\zombies\_zm_stats::get_global_stat( "navcard_applied_zm_transit" );
        df_debug_print( "DF compat: " + line );
    }
}

df_compat_flag_str( value )
{
    if ( is_true( value ) )
        return "1";

    return "0";
}

// ---- bus parts pinned (owner 2026-09-11) --------------------------------------------------------
// Vanilla deals the three bus parts (ladder, hatch, plow) at random over one shared pool of spawn structs
// (zm_transit_buildables.gsc combine_buildable_pieces). The relay is built on the bus ROOF, which needs the ladder,
// and the Galvaknuckles sit on the Diner roof, reached through the hatch: so the ladder always lies at the Depot and
// the hatch always at the Diner. Vanilla's own piece functions do the move (piece_unspawn / piece_spawn_in on the
// generated pieces, _zm_buildables.gsc), 3 s after the pieces exist; the plow takes a free spot.
df_bus_parts_pin()
{
    level endon( "end_game" );
    level thread df_bus_parts_debug();
    flag_wait( "start_zombie_round_logic" );

    // the pieces are generated by the bus buildable stubs some time after the flag: poll until they exist
    for ( t = 0; t < 100000; t++ )
    {
        wait 1;
        ladder = df_bus_piece( "busladder" );
        hatch = df_bus_piece( "bushatch" );
        plow = df_bus_piece( "cattlecatcher" );

        if ( isdefined( ladder ) && isdefined( hatch ) && isdefined( plow ) && isdefined( ladder.model ) && isdefined( hatch.model ) )
            break;
    }

    if ( !isdefined( ladder ) || !isdefined( hatch ) || !isdefined( ladder.spawns ) || ladder.spawns.size < 2 )
    {
        df_debug_print( "DF: bus parts: pieces never appeared, vanilla placement kept" );
        return;
    }

    df_debug_print( "DF: bus parts: pieces found " + t + " s after the round flag" );
    df_bus_parts_report( ladder, hatch, plow );
    moved = df_bus_parts_apply( ladder, hatch, plow );
    df_debug_print( "DF: bus parts pinned (" + moved + " moved): ladder at the Depot, hatch at the Diner" );
}

// Pins the two parts from the map's own structs (each part has its own pool, dealt per game; the wanted spot may not
// be in it, so it is appended). The plow keeps whatever vanilla gave it: its spots are its own.
df_bus_parts_apply( ladder, hatch, plow )
{
    depot = ( -7313, 5441, -55 );
    diner = ( -3537, -7214, -54 );
    moved = 0;

    // evict whatever else stands on a target spot (two parts on one spot hid the hatch, owner 2026-09-11)
    moved += df_bus_piece_evict( plow, depot, diner, "plow" );
    moved += df_bus_piece_evict( hatch, depot, undefined, "hatch" );
    moved += df_bus_piece_evict( ladder, undefined, diner, "ladder" );

    moved += df_bus_piece_pin( ladder, "busladder_com_stepladder_large_closed", depot, "ladder -> Depot" );
    moved += df_bus_piece_pin( hatch, "bushatch_veh_t6_civ_bus_zombie_roof_hatch", diner, "hatch -> Diner" );
    return moved;
}

// If `piece` stands within 120 of a or b (the spots reserved for the ladder and the hatch), it moves to the first spot
// of its own pool that is clear of both. Carried or built pieces are left alone.
df_bus_piece_evict( piece, a, b, label )
{
    if ( !isdefined( piece ) || !isdefined( piece.model ) || !isdefined( piece.spawns ) || isdefined( piece.owner ) )
        return 0;

    if ( !df_bus_near_spot( piece.model.origin, a ) && !df_bus_near_spot( piece.model.origin, b ) )
        return 0;

    for ( i = 0; i < piece.spawns.size; i++ )
    {
        o = piece.spawns[i].origin;

        if ( df_bus_near_spot( o, a ) || df_bus_near_spot( o, b ) )
            continue;

        return df_bus_piece_move( piece, i, label + " evicted from a reserved spot" );
    }

    df_debug_print( "DF: bus parts: " + label + " sits on a reserved spot and its pool has no free one" );
    return 0;
}

df_bus_near_spot( pos, spot )
{
    return isdefined( spot ) && distancesquared( pos, spot ) < 120 * 120;
}

// The struct of `targetname` nearest to place (within 400) goes into the piece's pool if absent; the piece moves there.
df_bus_piece_pin( piece, targetname, place, label )
{
    if ( !isdefined( piece ) || !isdefined( piece.spawns ) )
        return 0;

    target = undefined;
    best = 400 * 400;

    foreach ( s in getstructarray( targetname, "targetname" ) )
    {
        d = distancesquared( s.origin, place );

        if ( d < best )
        {
            best = d;
            target = s;
        }
    }

    if ( !isdefined( target ) )
    {
        df_debug_print( "DF: bus parts: no " + targetname + " struct near " + int( place[0] ) + " " + int( place[1] ) );
        return 0;
    }

    idx = -1;

    for ( i = 0; i < piece.spawns.size; i++ )
    {
        if ( piece.spawns[i] == target )
            idx = i;
    }

    if ( idx < 0 )
    {
        piece.spawns[piece.spawns.size] = target;
        idx = piece.spawns.size - 1;
        df_debug_print( "DF: bus parts: " + label + ": spot added to the pool as [" + idx + "]" );
    }

    if ( isdefined( piece.current_spawn ) && piece.current_spawn == idx && isdefined( piece.model ) )
        return 0;

    return df_bus_piece_move( piece, idx, label );
}

// The generated (world) piece of a vanilla buildable, or undefined.
df_bus_piece( name )
{
    if ( !isdefined( level.zombie_buildables ) || !isdefined( level.zombie_buildables[name] ) )
        return undefined;

    b = level.zombie_buildables[name];

    if ( !isdefined( b.buildablepieces ) || b.buildablepieces.size == 0 )
        return undefined;

    return b.buildablepieces[0].generated_piece;
}

// Vanilla's own unspawn / spawn on the piece, at spawn index idx. Skipped when a player already holds it.
df_bus_piece_move( piece, idx, label )
{
    if ( !isdefined( piece ) || isdefined( piece.owner ) || !isdefined( piece.piecespawn ) )
        return 0;

    piece maps\mp\zombies\_zm_buildables::piece_unspawn();
    piece.current_spawn = idx;
    piece.piecespawn.piece_allocated[idx] = 1;
    piece maps\mp\zombies\_zm_buildables::piece_spawn_in( piece.piecespawn );
    df_debug_print( "DF: bus parts: " + label + " (" + int( piece.spawns[idx].origin[0] ) + " " + int( piece.spawns[idx].origin[1] ) + " " + int( piece.spawns[idx].origin[2] ) + ")" );
    return 1;
}

// ---- Galvaknuckles at 3000 (owner 2026-09-11) --------------------------------------------------
// The wall-buy reads level.zombie_weapons[weapon].cost at every prompt and purchase (_zm_weapons get_weapon_cost).
df_knuckles_price()
{
    level endon( "end_game" );

    while ( !isdefined( level.zombie_weapons ) || !isdefined( level.zombie_weapons["tazer_knuckles_zm"] ) )
        wait 0.5;

    level.zombie_weapons["tazer_knuckles_zm"].cost = 3000;
    df_debug_print( "DF: Galvaknuckles cost 3000 (was " + 6000 + ")" );
}

// Console picture of the bus parts: the shared pool and where each piece stands (before the pin, and on demand).
df_bus_parts_report( ladder, hatch, plow )
{
    line = "";

    for ( i = 0; i < ladder.spawns.size && i < 16; i++ )
        line = line + "[" + i + "] " + int( ladder.spawns[i].origin[0] ) + " " + int( ladder.spawns[i].origin[1] ) + "  ";

    df_debug_print( "DF: bus parts pool (" + ladder.spawns.size + "): " + line );
    df_debug_print( "DF: bus parts now: ladder " + df_bus_piece_where( ladder ) + " | hatch " + df_bus_piece_where( hatch ) + " | plow " + df_bus_piece_where( plow ) );
}

df_bus_piece_where( piece )
{
    if ( !isdefined( piece ) )
        return "none";

    idx = "?";

    if ( isdefined( piece.current_spawn ) )
        idx = "" + piece.current_spawn;

    if ( isdefined( piece.model ) )
        return "spot " + idx + " at " + int( piece.model.origin[0] ) + " " + int( piece.model.origin[1] ) + " " + int( piece.model.origin[2] );

    return "spot " + idx + ", no model (carried or built)";
}

// "!df fire busparts": report and pin again, now.
df_bus_parts_debug()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_busparts" );
        ladder = df_bus_piece( "busladder" );
        hatch = df_bus_piece( "bushatch" );
        plow = df_bus_piece( "cattlecatcher" );

        if ( !isdefined( ladder ) || !isdefined( hatch ) )
        {
            df_debug_print( "DF: bus parts: pieces not found (level.zombie_buildables busladder / bushatch)" );
            continue;
        }

        df_bus_parts_report( ladder, hatch, plow );
        df_bus_parts_apply( ladder, hatch, plow );
        df_bus_parts_report( ladder, hatch, plow );
    }
}
