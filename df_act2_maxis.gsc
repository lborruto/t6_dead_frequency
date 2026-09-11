// Dead Frequency - Act 2M "Maxis" (power stays OFF).
//   M1 "The Cold Room": a denizen latched onto a player is carried to the table under the tower (the
//                       relay socket: DF_SOCKET resolves to DF_TABLE since 2026-09-08); it dies there and
//                       opens an orange portal into the Nacht bunker, where a timed denizen hunt takes
//                       place (spec 5, M1). Timeout: everyone is sent back and the latch starts again.
//                       The last kill leaves a SKULL on the bunker floor: one press TAKES it in hand (carry
//                       notice, no fire, no lamp portals, dropped at the feet on down), everyone is sent back,
//                       and one press within 150 of the table PLACES it on slot 1: that completes M1. Nobody
//                       took it before the return: it lies at the tower return point instead, still pickable.
//   M2 "Fire and Ash":  FOUR braziers in a row along the lava (tower -> cornfield) exist from game start (ember
//                       glow). M2 lights brazier 1; a player takes ONE ember from any lit brazier and keeps it in
//                       hand (burns 5 hp/s, no portals, lost on down) while lighting the other three in any order;
//                       it is consumed when all four burn. Each lit brazier then swallows five burning zombies;
//                       the flames grow in stages (spec 5, M2). The four braziers are Act 3's nodes.
//   Side rules (audit 2.4, Maxis = fog / fire / silence): after M1 denizens leave players alone within 400
//                       of the table or a lit brazier, denizen spawns are doubled, and power ON at the end
//                       of a round costs every brazier one stage while M2 runs.
// Vanilla facts this file relies on (Maps\Tranzit\maps\mp\zombies\_zm_ai_screecher.gsc,
// Maps\Tranzit\maps\mp\zm_transit_ai_screecher.gsc, zm_transit.gsc):
//   - player.screecher = the denizen riding that player (set when it jumps, cleared when it detaches or dies);
//     denizen.linked_ent = the player, denizen.state "attacking" while on the head, denizen.isscreecher = 1.
//   - The tower and the Nacht bunker are both "screecher_volume" safety zones: vanilla makes denizens jump
//     off / refuse to hunt there. TranZit exposes the two decisions as level function pointers
//     (level.screecher_should_runaway, level.is_player_in_screecher_zone); they are wrapped for the whole game.
//   - Denizens are spawned with spawn_zombie( spawner, spawner.targetname, spawn_point ) where spawn_point is
//     a struct (.origin .angles); screecher_prespawn teleports the AI there. Deaths reach the shared
//     zombie death callback (zombie_death_event is threaded on every actor by zombie_spawn_init).
//   - Only _zm_gump::player_teleport_blackscreen_on() exists (_zm_gump.gsc:19): the server flashes a
//     clientfield for 0.05 s and the client fades the black screen out by itself (about 1.5 s).
//   - A downed player's revive trigger is linked to the player (_zm_laststand.gsc:656-658), so setorigin on
//     a downed player moves the trigger with them (M1 teleports downed players too).
// Polish 2026-09-08 (tools/polish_act2_maxis.md): models through df_model( "portal" | "brazier" ); the hole
//   spins with an orbiting orange light; cold fog at the Nacht anchors; dig sound where a denizen rises; a
//   distinct final sting; an ash burst at the return point; braziers crackle and each counted kill is heard.
// Audit 2026-09-08 (tools/audit_D.md): braziers at boot, ember chain, skull item, ride cue, downed teleport,
//   side rules, power penalty. Cross-file needs in tools/requests_D.md.
// Owner run 2026-09-09 (tools/audit_M2fix.md): the skull is carried and placed by hand (M1 completes on the
//   placement); the hole opens at anchor DF_PORTAL; four fixed braziers at the owner's spots, one ember lights
//   them all, five burning kills each. Cross-file needs in tools/requests_M2fix.md.
// Polish V2 2026-09-09 (tools/audit_V2maxis.md, from audit_art / audit_steps_v2 / audit_dialogue_v2): one cue
//   grammar through the df_systems helpers (df_cue_tick = progress, df_cue_subgoal = a node done, df_cue_fail =
//   progress lost, df_cue_deny = wrong input, df_step_focus = the AVAILABLE glint, df_node_done_trail = the
//   canon node -> tower runner, df_vox_once = a vanilla Maxis line once); the whole file is fire family (no
//   blue one-shot: every trail here is maxis_sparks landing in df_cue_side_flash, df_act2_maxis_trail); the latch cue
//   is the portal spawn sound; the skull is announced when it APPEARS (ITEM_SKULL_MAXIS) with a 30 s window and
//   a puzzle prompt for the room; M1 / M2 end on the uniform step sting (df_complete, not quiet); brazier fire
//   heights come from df_model_top_z( "brazier" ) (the low lava-rock cairn: rim 16); a brazier full is a sub-goal
//   (navcard + fire burst + trail to the tower); all four full raise a 20 s smoke column at the tower top; the
//   ember consumed fires the second hint rung; the power penalty speaks (M2_POWER_MAXIS).
//   Cross-file needs in tools/requests_V2maxis.md.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;
#include scripts\zm\zm_transit\df_scav;
#include scripts\zm\zm_transit\df_act3_hold; // df_s7_tower_safety_volume (requested for df_systems, requests_D.md)

// Steps registered, braziers spawned at boot (owner rule 2026-09-08: everything physical exists from game start).
df_act2_maxis_init()
{
    df_register_step( "m1", ::df_m1_run, ::df_m1_setup );
    df_register_step( "m2", ::df_m2_run, ::df_m2_setup );
    level thread df_m2_boot();
}

// =========================================================================================
// M1 - The Cold Room
// =========================================================================================

// Latch -> portal -> walk in -> timed hunt; a timeout loops back to the latch. Success: the skull appears in
// the bunker (a short window to take it), everyone returns, and the step ends when the skull is placed on
// table slot 1 (owner 2026-09-09: M1 completes on the placement, not on the return).
df_m1_run()
{
    level endon( "end_game" );

    level.df_m1_kills = 0;
    level.df_m1_phase = 0;
    level.df_m1_mode = "latch";
    df_m1_hooks_install();
    level thread df_m1_skip_cleanup();
    level thread df_m1_debug_latch_hook();
    level thread df_m1_debug_kills_hook();
    level thread df_m1_debug_cue_hook();
    // AVAILABLE glint 20 over the table top until the first latch (art audit change 2; df_step_focus wants the
    // glint point itself); it moves to the hole when it opens
    df_step_focus( "m1", df_coord( "DF_SOCKET" ).origin + ( 0, 0, df_model_top_z( "table" ) + 20 ) );
    df_debug_print( "DF: m1 waiting for a denizen latched within 300 of the table" );

    while ( true )
    {
        df_m1_wait_latch();
        df_m1_portal_open();
        who = df_m1_wait_portal_use();
        result = df_m1_cold_room( who );

        if ( result == "success" )
            df_m1_skull_appear();

        df_m1_portal_remove();
        df_m1_return_players();

        if ( result == "success" )
            break;

        // the line waits for the picture to be back after the black screen (see df_m1_finish); the FAIL cue
        // (emp thump to all + ash where it was lost) lands at the return point, and Maxis's canon "your power
        // supplies are drained, now start again" (vox_maxi_turbines_out_0, zm_transit_sq.gsc) once per game
        wait 2.0;
        df_cue_fail( df_coord( "DF_TOWER_RETURN" ).origin );
        df_say( "M1_MAXIS_FAIL" );
        df_vox_once( "vox_maxi_turbines_out_0", df_coord( "DF_SOCKET" ).origin );
        df_debug_print( "DF: m1 failed (" + result + "), back to the latch" );
    }

    df_m1_skull_follow_return();
    df_m1_wait_placed();
    df_m1_finish();
}

// After the return: the tower's safety volume is back (the latch removed it), the denizen rules are vanilla's
// again (mode "place": neither the latch nor the room rule applies, the side rules wait for M1 done), and the
// step blocks until the skull is on slot 1 (df_m1_skull_place_table notifies; a skull already placed by
// "!df fire m1_skull" during the latch counts).
df_m1_wait_placed()
{
    level endon( "end_game" );

    level.df_m1_mode = "place";
    df_s7_tower_safety_volume( 1 );

    if ( isdefined( level.df_m1_skull_table ) )
        return;

    df_debug_print( "DF: m1 waiting for the skull on table slot 1 (carry it within 150 of the table, one press)" );
    level waittill( "df_m1_skull_placed" );
}

// Placement done: the tower answers in orange for 12 s (the light over the table glows steady since Step 4),
// then M1_DONE and the ONE uniform step sting (df_complete, art audit change 1: zmb_powerup_grabbed means
// "step done" everywhere and nothing else plays it). The side rules start here (df_m1_after_rules).
df_m1_finish()
{
    level.df_m1_mode = undefined;
    df_m1_after_rules();
    df_tower_fx_start( "maxis" );
    level thread df_tower_fx_stop_after( 12 );
    wait 2.0;
    df_say( "M1_DONE" );
    df_complete( "m1" );
}

// "!df goto" past m1: the skull is already on the table, the side rules apply.
df_m1_setup()
{
    level.df_m1_mode = undefined;
    level.df_m1_phase = 0;
    df_m1_skull_place_table( 1 );
    df_m1_after_rules();
}

// Everything M1 spawned goes on "!df goto" past it: portal, lights, fog, huds, cold room denizens, floor skull,
// a carried skull. The hooks stay (df_m1_setup re-arms them right after) and the tower safety volume comes back.
df_m1_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_m1_done" );
    level waittill( "df_skip_m1" );

    if ( is_true( level.df_m1_phase ) )
        df_m1_phase_teardown();

    df_m1_portal_remove();
    df_m1_skull_clear_world();
    level.df_m1_mode = undefined;
    df_s7_tower_safety_volume( 1 );
}

// Audit 2.4 (Maxis = the silence), from M1 done for the rest of the game: the denizen hooks stay installed so
// df_m1_should_runaway / df_m1_in_screecher_zone protect players within 400 of the table or a lit brazier;
// the fog spawns twice the denizens (level.zombie_ai_limit_screecher, 2 in _zm_ai_screecher::init:82; Step 7
// raises and restores it around its wave, the finale zeroes it); the tower safety volume is back.
df_m1_after_rules()
{
    df_m1_hooks_install();
    df_s7_tower_safety_volume( 1 );
    level.zombie_ai_limit_screecher = 4;
    df_debug_print( "DF: m1 side rules on: denizens avoid the table and lit braziers (400), fog spawns doubled" );
}

// ---- vanilla hooks -----------------------------------------------------------------------
// Both pointers are read by _zm_ai_screecher on every decision, so swapping them is enough. The saved
// vanilla functions are called for everything outside our places.

df_m1_hooks_install()
{
    if ( is_true( level.df_m1_hooked ) )
        return;

    level.df_m1_hooked = 1;
    level.df_m1_vanilla_runaway = level.screecher_should_runaway;
    level.df_m1_vanilla_in_zone = level.is_player_in_screecher_zone;
    level.screecher_should_runaway = ::df_m1_should_runaway;
    level.is_player_in_screecher_zone = ::df_m1_in_screecher_zone;
}

// True after M1 for a player within 400 of the table or a lit brazier: the fog creatures are ours there.
df_m1_protected( pos )
{
    if ( !df_is_done( "m1" ) || isdefined( level.df_m1_mode ) )
        return false;

    if ( distancesquared( pos, df_coord( "DF_SOCKET" ).origin ) < 400 * 400 )
        return true;

    return df_m2_lit_near( pos, 400 );
}

// self = denizen. Latch phase: a denizen riding a player keeps riding up to the table (the tower is a
// vanilla safety zone, zm_transit_ai_screecher.gsc:17). Cold room: nothing scares them inside the bunker.
// After M1: they jump off near the table and the lit braziers (vanilla runaway = true, :206).
df_m1_should_runaway( player )
{
    if ( isdefined( player ) && isdefined( level.df_m1_mode ) )
    {
        if ( level.df_m1_mode == "latch" && distancesquared( player.origin, df_coord( "DF_SOCKET" ).origin ) < 600 * 600 )
            return false;

        if ( level.df_m1_mode == "room" && df_m1_in_room( player.origin, 900 ) )
            return false;
    }

    if ( isdefined( player ) && df_m1_protected( player.origin ) )
        return true;

    if ( isdefined( level.df_m1_vanilla_runaway ) )
        return self [[ level.df_m1_vanilla_runaway ]]( player );

    return false;
}

// Cold room: players inside the bunker are valid prey even though it is a vanilla safety zone
// (zm_transit.gsc:935 is_player_in_screecher_zone). After M1: nobody is prey near the table or a lit brazier.
df_m1_in_screecher_zone( player )
{
    if ( isdefined( level.df_m1_mode ) && level.df_m1_mode == "room" && !is_true( player.isonbus ) && df_m1_in_room( player.origin, 900 ) )
        return true;

    if ( df_m1_protected( player.origin ) )
        return false;

    if ( isdefined( level.df_m1_vanilla_in_zone ) )
        return [[ level.df_m1_vanilla_in_zone ]]( player );

    return true;
}

// ---- latch -----------------------------------------------------------------------------

// Blocks until a ridden player reaches the table (or "!df fire m1_latch"); the denizen dies there through
// the vanilla death path (ash fx, weapon restored to the player). Audit #6: the tower's safety box is taken
// out of level.safety_volumes meanwhile (df_act3_hold df_s7_tower_safety_volume) so denizens rise AT the tower.
df_m1_wait_latch()
{
    level endon( "end_game" );

    level.df_m1_mode = "latch";
    df_s7_tower_safety_volume( 0 );
    level thread df_m1_latch_poll();
    level waittill( "df_m1_latched", den, who );
    level notify( "df_m1_latch_poll_stop" );
    df_touch( "m1" );

    if ( isdefined( den ) && isalive( den ) )
    {
        if ( isdefined( who ) && isplayer( who ) )
            den dodamage( den.health + 666, den.origin, who );
        else
            den dodamage( den.health + 666, den.origin );
    }

    df_debug_print( "DF: m1 latch done" );
}

// A player carrying a denizen (player.screecher, _zm_ai_screecher.gsc:549) within 300 of the table.
// Audit #6: the FIRST time anyone is ridden after M1 opened, the table pulses orange and Maxis speaks
// (M1_EVENT alone: the dialogue audit v2 dropped the hint rung that said the same thing 6.5 s later): the
// counter-reflex "do not knife it".
df_m1_latch_poll()
{
    level endon( "end_game" );
    level endon( "df_skip_m1" );
    level endon( "df_m1_latch_poll_stop" );

    socket = df_coord( "DF_SOCKET" ).origin;

    while ( true )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            if ( !isdefined( player.screecher ) )
                continue;

            if ( !is_true( level.df_m1_ride_cued ) )
            {
                level.df_m1_ride_cued = 1;
                level thread df_m1_ride_cue();
            }

            if ( distancesquared( player.origin, socket ) > 300 * 300 )
                continue;

            df_debug_print( "DF: m1 denizen latched at the table" );
            level notify( "df_m1_latched", player.screecher, player );
            return;
        }
    }
}

// Once per game: table pulses orange 5 s and M1_EVENT (the event line is the whole teaching; no hint rung here).
df_m1_ride_cue()
{
    level endon( "end_game" );

    df_debug_print( "DF: m1 first ride: table pulse + event line" );
    df_say( "M1_EVENT" );
    df_m1_table_pulse( 5 );
}

// Orange light over the table on / off every 0.5 s for `seconds` (lamp light alias zm_transit_fx.gsc:114),
// announced ONCE by the denizen portal opening sound (zmb_screecher_portal_spawn, zm_transit_ai_screecher.gsc:80):
// louder than the quiet zmb_souls_end it replaces and in the family of what the latch will open.
df_m1_table_pulse( seconds )
{
    level endon( "end_game" );

    pos = df_coord( "DF_SOCKET" ).origin + ( 0, 0, 60 );
    n = int( seconds * 2 );
    playsoundatposition( "zmb_screecher_portal_spawn", pos );

    for ( i = 0; i < n; i++ )
    {
        if ( i % 2 == 0 )
            fx = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", pos );
        else
            df_fx_stop( fx );

        wait 0.5;
    }

    df_fx_stop( fx );
}

// "!df fire m1_latch": open the portal without a denizen.
df_m1_debug_latch_hook()
{
    level endon( "end_game" );
    level endon( "df_m1_done" );
    level endon( "df_skip_m1" );

    while ( true )
    {
        level waittill( "df_debug_m1_latch" );
        level notify( "df_m1_latched" );
    }
}

// "!df fire m1_kills" or "!df souls" while the cold room runs: the kill target is met.
df_m1_debug_kills_hook()
{
    level endon( "end_game" );
    level endon( "df_m1_done" );
    level endon( "df_skip_m1" );

    while ( true )
    {
        level waittill_either( "df_debug_m1_kills", "df_debug_souls_done" );

        if ( !is_true( level.df_m1_phase ) )
            continue;

        level.df_m1_kills = level.df_m1_target;
        df_debug_print( "DF: m1 kills filled by debug" );
        level notify( "df_m1_phase_over", "success" );
    }
}

// Hard-to-reach audio/visual bits, testable anywhere during m1:
//   "!df fire m1_cue"   kill cue for kill 3 at the first player's feet (tick + puff + dings), then the last
//                       kill's sub-goal cue 2.5 s later;
//   "!df fire m1_burst" the return burst at DF_TOWER_RETURN;
//   "!df fire m1_fog"   toggles the cold room fog at the Nacht anchors (visit with !df tp DF_NACHT_SPAWN_1);
//   "!df fire m1_ride"  the first-ride cue (table pulse + M1_EVENT) even without a denizen;
//   "!df fire m1_skull" drops the skull in front of the first player; fired again (skull on the floor or in
//                       a hand) it goes onto table slot 1, which completes M1 once the cold room is done.
df_m1_debug_cue_hook()
{
    level endon( "end_game" );
    level endon( "df_m1_done" );
    level endon( "df_skip_m1" );

    while ( true )
    {
        what = level waittill_any_return( "df_debug_m1_cue", "df_debug_m1_burst", "df_debug_m1_fog", "df_debug_m1_ride", "df_debug_m1_skull" );

        if ( what == "df_debug_m1_burst" )
        {
            level thread df_m1_return_burst( df_coord( "DF_TOWER_RETURN" ).origin );
            continue;
        }

        if ( what == "df_debug_m1_fog" )
        {
            if ( isdefined( level.df_m1_room_fx ) )
                df_m1_room_fx_stop();
            else
                df_m1_room_fx_start();

            df_debug_print( "DF: m1 fog toggled" );
            continue;
        }

        if ( what == "df_debug_m1_ride" )
        {
            level thread df_m1_ride_cue();
            continue;
        }

        players = getplayers();

        if ( players.size == 0 )
            continue;

        if ( what == "df_debug_m1_skull" )
        {
            df_m1_debug_skull( players[0] );
            continue;
        }

        if ( !isdefined( level.df_m1_target ) )
            level.df_m1_target = df_scaled( "cold_room_kills" );

        pos = players[0].origin;
        level thread df_m1_kill_cue( 3, pos );
        wait 2.5;
        level thread df_m1_kill_cue( level.df_m1_target, pos );
    }
}

// ---- portal ----------------------------------------------------------------------------

// Denizen hole ON the ground at anchor DF_PORTAL (df_coords: the owner's spot in front of the table, pinned
// in df_apply_overrides; derived fallback = df_table_front() + 30 further out, so `!df show` / `!df tp` /
// `!df grab DF_PORTAL` all work on it). Same birth as vanilla create_portal (zm_transit_ai_screecher.gsc:68-99):
// the hole model rises 20 units under the opening fx, then the vortex and the loop take over. Ours also spins
// slowly with an orange light riding it, plus a steady orange light over the centre.
df_m1_portal_open()
{
    c = df_coord( "DF_PORTAL" );
    pos = c.origin;
    level.df_m1_portal_pos = pos;

    level.df_m1_hole = spawn( "script_model", pos - ( 0, 0, 20 ) );
    level.df_m1_hole setmodel( df_model( "portal" ) );
    level.df_m1_hole.angles = c.angles;
    level.df_m1_hole playsound( "zmb_screecher_portal_spawn" );
    level.df_m1_portal_fx = df_fx_loop( "screecher_hole", pos );
    level.df_m1_hole moveto( pos, 1.0 );
    df_debug_print( "DF: m1 portal at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) );
    wait 1.2;

    df_fx_stop( level.df_m1_portal_fx );
    level.df_m1_portal_fx = undefined;

    // a skip during the rise already removed the hole
    if ( !isdefined( level.df_m1_hole ) )
        return;

    playfxontag( level._effect["screecher_vortex"], level.df_m1_hole, "tag_origin" );
    level.df_m1_hole playloopsound( "zmb_screecher_portal_loop", 2 );
    level thread df_m1_portal_spin();

    level.df_m1_portal_light = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", pos + ( 0, 0, 40 ) );
    level.df_m1_portal_orbit = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", pos + ( 28, 0, 30 ) );

    // linkto( ent, tag, origin offset, angles offset ) as _zm_buildables.gsc:641: the light orbits the hole
    if ( isdefined( level.df_m1_portal_orbit ) )
        level.df_m1_portal_orbit linkto( level.df_m1_hole, "tag_origin", ( 28, 0, 30 ), ( 0, 0, 0 ) );

    // the step's focus (AVAILABLE glint) moves from the table to the hole: "walk in here"
    df_step_focus( "m1", pos + ( 0, 0, 20 ) );
    df_say( "M1_PORTAL" );
}

// One slow turn every 10 s (rotateyaw on a script_model as _zm_tombstone.gsc:332, "rotatedone" as
// _zm_ai_faller.gsc:99); the vortex fx rides the tag and the orbit light is linked, so both turn with it.
df_m1_portal_spin()
{
    level endon( "end_game" );
    level endon( "df_m1_portal_closed" );

    while ( isdefined( level.df_m1_hole ) )
    {
        level.df_m1_hole rotateyaw( 360, 10 );
        level.df_m1_hole waittill( "rotatedone" );
    }
}

df_m1_portal_remove()
{
    level notify( "df_m1_portal_closed" );

    if ( isdefined( level.df_m1_hole ) )
    {
        playsoundatposition( "zmb_screecher_portal_end", level.df_m1_hole.origin );
        level.df_m1_hole stoploopsound();
        level.df_m1_hole delete();
    }

    df_fx_stop( level.df_m1_portal_light );
    df_fx_stop( level.df_m1_portal_orbit );
    df_fx_stop( level.df_m1_portal_fx );
    level.df_m1_hole = undefined;
    level.df_m1_portal_light = undefined;
    level.df_m1_portal_orbit = undefined;
    level.df_m1_portal_fx = undefined;
}

// Returns the first player who steps (or jumps) into the hole: within 50 units of its centre on the
// ground plane and no more than 90 above it (owner 2026-09-08: walk-in, no use trigger). Same refusal as
// the lamp portals for a player carrying something (df_portal_use): the WRONG INPUT cue (df_cue_deny, the
// Pack-a-Punch deny buzz to that player) at most every 2 s; nothing was lost, so no emp thump.
df_m1_wait_portal_use()
{
    level endon( "end_game" );

    pos = level.df_m1_portal_pos;
    last_refuse = 0;

    while ( true )
    {
        wait 0.1;

        foreach ( who in getplayers() )
        {
            if ( !is_player_valid( who ) )
                continue;

            if ( distance2dsquared( who.origin, pos ) > 50 * 50 )
                continue;

            dz = who.origin[2] - pos[2];

            if ( dz < -40 || dz > 90 )
                continue;

            if ( is_true( who.df_carrying_relay ) || isdefined( who.df_orb ) )
            {
                if ( gettime() - last_refuse > 2000 )
                {
                    last_refuse = gettime();
                    df_cue_deny( who );
                }

                continue;
            }

            df_touch( "m1" );
            df_debug_print( "DF: m1 portal entered by " + who.name );
            return who;
        }
    }
}

// ---- cold room -------------------------------------------------------------------------

// Bunker centre = the middle of the four Nacht spawn anchors.
df_m1_room_center()
{
    if ( isdefined( level.df_m1_room ) )
        return level.df_m1_room;

    sum = ( 0, 0, 0 );

    for ( i = 1; i <= 4; i++ )
        sum = sum + df_coord( "DF_NACHT_SPAWN_" + i ).origin;

    level.df_m1_room = sum * 0.25;
    return level.df_m1_room;
}

df_m1_in_room( pos, radius )
{
    return distance2dsquared( pos, df_m1_room_center() ) < radius * radius;
}

// Living, standing players inside the bunker.
df_m1_room_players()
{
    out = [];

    foreach ( player in getplayers() )
    {
        if ( is_player_valid( player ) && df_m1_in_room( player.origin, 900 ) )
            out[out.size] = player;
    }

    return out;
}

// A player still in the match (alive or downed; not a spectator), sessionstate as _zm.gsc:300.
df_m1_in_match( player )
{
    return isdefined( player ) && isdefined( player.sessionstate ) && player.sessionstate == "playing";
}

// Returns "success" or "timeout".
df_m1_cold_room( who )
{
    level endon( "end_game" );

    seconds = df_scaled( "cold_room_time" );
    level.df_m1_target = df_scaled( "cold_room_kills" );
    level.df_m1_kills = 0;
    level.df_m1_phase = 1;
    level.df_m1_mode = "room";
    level.df_m1_last_kill_pos = undefined;

    // vanilla's denizen director is paused (we spawn our own, _zm_ai_screecher.gsc:82 zombie_ai_limit_screecher)
    // and the solo "near miss" escape is spent (:253-262)
    level.df_m1_saved_limit = level.zombie_ai_limit_screecher;
    level.zombie_ai_limit_screecher = 0;
    level.df_m1_saved_near_miss = level.near_miss;
    level.near_miss = 2;

    df_m1_room_fx_start();
    df_m1_teleport_players_in();
    df_death_listen_add( "m1", ::df_m1_on_zombie_death );
    level thread df_m1_timer( seconds );
    level thread df_sys_clock_run( gettime() + int( seconds * 1000 ), "df_m1_phase_end", "df_skip_m1" );
    level thread df_m1_spawn_loop();

    foreach ( player in getplayers() )
    {
        if ( is_player_valid( player ) )
            player thread df_m1_timer_hud( seconds );
    }

    df_debug_print( "DF: m1 cold room " + seconds + " s, " + level.df_m1_target + " denizen kills" );
    level waittill( "df_m1_phase_over", result );

    if ( !isdefined( result ) )
        result = "timeout";

    df_debug_print( "DF: m1 cold room over: " + result + " (" + level.df_m1_kills + "/" + level.df_m1_target + ")" );
    df_m1_phase_teardown();
    return result;
}

df_m1_phase_teardown()
{
    level.df_m1_phase = 0;
    level.df_m1_mode = "latch";
    level notify( "df_m1_phase_end" );
    df_death_listen_remove( "m1" );
    df_m1_room_fx_stop();

    foreach ( player in getplayers() )
    {
        if ( isdefined( player.df_m1_hud ) )
            player.df_m1_hud destroy();

        player.df_m1_hud = undefined;
    }

    // leftovers die through the normal path so vanilla's counters and the ridden player are restored
    foreach ( ai in df_m1_denizens_alive() )
        ai dodamage( ai.health + 666, ai.origin );

    if ( isdefined( level.df_m1_saved_limit ) )
        level.zombie_ai_limit_screecher = level.df_m1_saved_limit;

    if ( isdefined( level.df_m1_saved_near_miss ) )
        level.near_miss = level.df_m1_saved_near_miss;

    level.df_m1_saved_limit = undefined;
    level.df_m1_saved_near_miss = undefined;
}

// Cold cue: a low fog patch on the floor at each Nacht anchor while the hunt runs (fx_zmb_fog_closet,
// zm_transit_fx.gsc:70, the smallest fog alias the map registers; fx_zmb_fog_low_300x300 is the bigger one).
df_m1_room_fx_start()
{
    df_m1_room_fx_stop();
    level.df_m1_room_fx = [];

    for ( i = 1; i <= 4; i++ )
    {
        c = df_coord( "DF_NACHT_SPAWN_" + i );
        fx = df_fx_loop( "fx_zmb_fog_closet", df_ground( c.origin ) + ( 0, 0, 4 ) );

        if ( isdefined( fx ) )
            level.df_m1_room_fx[level.df_m1_room_fx.size] = fx;
    }
}

df_m1_room_fx_stop()
{
    if ( isdefined( level.df_m1_room_fx ) )
    {
        foreach ( fx in level.df_m1_room_fx )
            df_fx_stop( fx );
    }

    level.df_m1_room_fx = undefined;
}

// Every player in the match goes in, downed ones included (audit 5/6: nobody bleeds out alone in the
// cornfield; their revive trigger is linked to them, _zm_laststand.gsc:658). Sounds and black screen are
// the vanilla portal's (zm_transit_ai_screecher.gsc:149 warp_2d per player, :176 arrive at the destination).
df_m1_teleport_players_in()
{
    df_scav_wait_all_free( 3.5 ); // spec 9: never move a player frozen in a Scavenger bench build
    i = 0;

    foreach ( player in getplayers() )
    {
        if ( !df_m1_in_match( player ) )
            continue;

        c = df_coord( "DF_NACHT_SPAWN_" + ( ( i % 4 ) + 1 ) );
        i++;
        player playsoundtoplayer( "zmb_screecher_portal_warp_2d", player );
        player maps\mp\zombies\_zm_gump::player_teleport_blackscreen_on();
        player setorigin( c.origin + ( 0, 0, 4 ) );
        player setplayerangles( c.angles );
    }

    playsoundatposition( "zmb_screecher_portal_arrive", df_m1_room_center() );
    df_debug_print( "DF: m1 " + i + " player(s) sent to the bunker" );
}

// Everyone in the bunker (standing or downed) comes back to DF_TOWER_RETURN (48-unit spread) with a burst there.
df_m1_return_players()
{
    df_scav_wait_all_free( 3.5 ); // spec 9: never move a player frozen in a Scavenger bench build
    c = df_coord( "DF_TOWER_RETURN" );
    i = 0;

    foreach ( player in getplayers() )
    {
        if ( !df_m1_in_match( player ) || !df_m1_in_room( player.origin, 1500 ) )
            continue;

        spread = anglestoright( c.angles ) * ( ( i % 2 ) * 48 ) + anglestoforward( c.angles ) * ( int( i / 2 ) * 48 );
        i++;
        player playsoundtoplayer( "zmb_screecher_portal_warp_2d", player );
        player maps\mp\zombies\_zm_gump::player_teleport_blackscreen_on();
        player setorigin( df_ground( c.origin + spread ) + ( 0, 0, 4 ) );
        player setplayerangles( c.angles );
    }

    playsoundatposition( "zmb_screecher_portal_arrive", c.origin );
    level thread df_m1_return_burst( c.origin );
    df_debug_print( "DF: m1 " + i + " player(s) returned to the tower" );
}

// Arrival burst at the return point: the denizen death ash (screecher_death, _zm_ai_screecher.gsc:28, played
// once with playfx at :1134) and an orange light for 2 s. "!df fire m1_burst" replays it.
df_m1_return_burst( origin )
{
    level endon( "end_game" );

    df_fx_once( "screecher_death", origin + ( 0, 0, 10 ) );
    light = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", origin + ( 0, 0, 50 ) );
    wait 2.0;
    df_fx_stop( light );
}

df_m1_timer( seconds )
{
    level endon( "end_game" );
    level endon( "df_skip_m1" );
    level endon( "df_m1_phase_end" );
    wait( seconds );
    level notify( "df_m1_phase_over", "timeout" );
}

// self = player. A single countdown number, top centre (y 40), cold blue; dialogue lines sit bottom centre
// (df_hud_line, y -95) so the two never overlap. Turns red-orange for the last 10 s.
df_m1_timer_hud( seconds )
{
    if ( !df_sys_hud_timers() )
        return; // owner 2026-09-09: no timer on screen, the clock ticks instead

    self endon( "disconnect" );

    if ( isdefined( self.df_m1_hud ) )
        self.df_m1_hud destroy();

    hud = newclienthudelem( self );
    hud.alignx = "center";
    hud.aligny = "top";
    hud.horzalign = "user_center";
    hud.vertalign = "user_top";
    hud.x = 0;
    hud.y = 40;
    hud.font = "default";
    hud.fontscale = 2.5;
    hud.foreground = 1;
    hud.hidewheninmenu = 1;
    hud.color = ( 0.7, 0.88, 1 );
    hud.alpha = 1;
    hud settimer( seconds );
    self.df_m1_hud = hud;
    self thread df_m1_timer_hud_warn( hud, seconds );

    level waittill( "df_m1_phase_end" );

    if ( isdefined( self.df_m1_hud ) )
        self.df_m1_hud destroy();

    self.df_m1_hud = undefined;
}

df_m1_timer_hud_warn( hud, seconds )
{
    self endon( "disconnect" );
    level endon( "df_m1_phase_end" );

    if ( seconds <= 10 )
        return;

    wait( seconds - 10 );

    if ( isdefined( hud ) )
        hud.color = ( 1, 0.45, 0.3 );
}

// Denizens near the bunker that are still alive (any state).
df_m1_denizens_alive()
{
    out = [];

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( !isdefined( ai ) || !isalive( ai ) || !is_true( ai.isscreecher ) )
            continue;

        if ( df_m1_in_room( ai.origin, 1500 ) )
            out[out.size] = ai;
    }

    return out;
}

// Owner 2026-09-08: two denizens per standing player in the bunker (at least two), a fresh one every 0.6 s
// while under the cap, the first one 1 s after arrival.
df_m1_spawn_loop()
{
    level endon( "end_game" );
    level endon( "df_skip_m1" );
    level endon( "df_m1_phase_end" );

    if ( !isdefined( level.screecher_spawners ) || level.screecher_spawners.size == 0 )
    {
        df_debug_print( "DF: m1 no screecher spawner in the map, nothing will rise (use !df fire m1_kills)" );
        return;
    }

    next = gettime() + 1000;

    while ( true )
    {
        wait 0.1;

        if ( gettime() < next )
            continue;

        cap = df_m1_room_players().size * 2;

        if ( cap < 2 )
            cap = 2;

        if ( df_m1_denizens_alive().size >= cap )
            continue;

        df_m1_spawn_denizen();
        next = gettime() + 600;
    }
}

// The Nacht anchor farthest from the players, as a fresh struct (screecher_prespawn reads .origin/.angles).
df_m1_pick_spawn()
{
    players = df_m1_room_players();
    best = undefined;
    best_d2 = -1;

    for ( i = 1; i <= 4; i++ )
    {
        c = df_coord( "DF_NACHT_SPAWN_" + i );
        d2 = 999999999;

        foreach ( player in players )
        {
            pd2 = distancesquared( player.origin, c.origin );

            if ( pd2 < d2 )
                d2 = pd2;
        }

        if ( d2 > best_d2 )
        {
            best_d2 = d2;
            best = c;
        }
    }

    spot = spawnstruct();
    spot.origin = best.origin;
    spot.angles = best.angles;
    return spot;
}

// spawn_zombie( spawner, target_name, spawn_point ) as _zm_utility.gsc:236. The ground opens where it will
// rise: the dig sound (zmb_screecher_dig, _zm_ai_screecher.gsc:324) and the dirt billow (screecher_spawn_b,
// :24) at the spot; vanilla adds the hand burst and falling dirt on the AI itself (play_screecher_fx :434).
df_m1_spawn_denizen()
{
    spot = df_m1_pick_spawn();
    playsoundatposition( "zmb_screecher_bury", spot.origin ); // zmb_screecher_dig is in no TranZit bank (silent)
    df_fx_once( "screecher_spawn_b", spot.origin );
    spawner = random( level.screecher_spawners );
    ai = spawn_zombie( spawner, spawner.targetname, spot );

    if ( !isdefined( ai ) )
    {
        df_debug_print( "DF: m1 denizen spawn failed" );
        return;
    }

    ai.spawn_point = spot;
    level.zombie_screecher_count++;
    ai thread df_m1_denizen_death_watch();
    level thread df_m1_denizen_tune( ai );
    df_debug_print( "DF: m1 denizen rising at " + int( spot.origin[0] ) + " " + int( spot.origin[1] ) );
}

// Cold room denizens are fragile: guns work on them while they rise, the head-melee still works once
// they latch. Set after the spawn functions ran (zombie_spawn_init writes the round health first).
df_m1_denizen_tune( ai )
{
    wait 0.2;

    if ( isdefined( ai ) && isalive( ai ) )
    {
        ai.health = 250;
        ai.maxhealth = 250;
    }
}

// self = denizen. Belt and braces with the death listener (whichever runs first counts it).
df_m1_denizen_death_watch()
{
    self waittill( "death" );

    if ( isdefined( self ) )
        df_m1_count_kill( self );
}

df_m1_on_zombie_death( zombie )
{
    if ( !is_true( zombie.isscreecher ) )
        return;

    if ( !df_m1_in_room( zombie.origin, 1500 ) )
        return;

    df_m1_count_kill( zombie );
}

df_m1_count_kill( ai )
{
    if ( !is_true( level.df_m1_phase ) )
        return;

    pos = df_m1_room_center();

    if ( isdefined( ai ) )
    {
        if ( is_true( ai.df_m1_counted ) )
            return;

        ai.df_m1_counted = 1;
        pos = ai.origin;
    }

    level.df_m1_kills++;
    level.df_m1_last_kill_pos = pos;
    level thread df_m1_kill_cue( level.df_m1_kills, pos );
    df_debug_print( "DF: m1 denizen kill " + level.df_m1_kills + "/" + level.df_m1_target );

    if ( level.df_m1_kills >= level.df_m1_target )
        level notify( "df_m1_phase_over", "success" );
}

// Owner 2026-09-08 (Buried witches feel): every kill is heard climbing. Kill k = an orange trail from the
// corpse to the nearest bunker player, the PROGRESS TICK at the corpse (df_cue_tick with burst: the piece-add
// clink + 0.6 s of lava fire, art audit cue table) with a puff of rising ash, then k quick dings
// (zmb_player_hit_ding, the vanilla hit marker alias, per player). The LAST kill is the SUB-GOAL cue
// (df_cue_subgoal: navcard chime + fire flash at the corpse + the canon runner to the tower top, seen by
// whoever is outside) after a beat of silence; the loud cha-ching is out (owner).
df_m1_kill_cue( k, pos )
{
    level endon( "end_game" );

    players = df_m1_room_players();

    if ( players.size == 0 )
        players = getplayers();

    to = df_m1_room_center() + ( 0, 0, 40 );
    best_d2 = undefined;

    foreach ( player in players )
    {
        d2 = distancesquared( player.origin, pos );

        if ( !isdefined( best_d2 ) || d2 < best_d2 )
        {
            best_d2 = d2;
            to = player.origin + ( 0, 0, 40 );
        }
    }

    level thread df_act2_maxis_trail( pos + ( 0, 0, 30 ), to );
    df_fx_once( "fx_zmb_ash_rising_md", pos );
    df_cue_tick( pos, 1 );
    wait 0.4;

    dings = k;

    if ( dings > 8 )
        dings = 8;

    for ( i = 0; i < dings; i++ )
    {
        foreach ( player in getplayers() )
            player playsoundtoplayer( "zmb_buildable_piece_add", player ); // zmb_player_hit_ding: no TranZit bank has it

        wait 0.12;
    }

    if ( k < level.df_m1_target )
        return;

    wait 0.6;
    df_cue_subgoal( pos + ( 0, 0, 30 ) );
}

// Fire-side soul trail (audit_art change 9: no blue one-shot on the Maxis path): the maxis_sparks runner
// (fx_zmb_race_trail_grief, zm_transit_fx.gsc:18, the orange tower runner of the vanilla Maxis ending) flies
// from `from` to `to` in 0.4-1.5 s and lands in the side's success flash (df_systems df_cue_side_flash:
// fx_zmb_tranzit_fire_lrg for 0.8 s on this side) with the vanilla soul sound (zmb_souls_end). Same shape and
// timing as df_systems df_soul_fly, which is the blue one (richtofen_sparks + blue spark) and stays for the
// Richtofen path.
df_act2_maxis_trail( from, to )
{
    level endon( "end_game" );

    ent = df_fx_loop( "maxis_sparks", from + ( 0, 0, 40 ) );

    if ( !isdefined( ent ) )
        return;

    wait 0.15; // one snapshot so the client sees it before it flies (no pool: its teleports drew streaks)

    if ( !isdefined( ent ) )
        return;

    dist = distance( from, to );
    time = dist / 700;

    if ( time < 0.4 )
        time = 0.4;

    if ( time > 1.5 )
        time = 1.5;

    ent moveto( to, time );
    wait( time );
    df_cue_side_flash( to );
    df_snd_near( "evt_player_swiped", to, 600 ); // owner pick 2026-09-11: a soul reaches a brazier
    df_fx_stop( ent );
}

// ---- skull (audit 9, ITEM_SKULL_MAXIS; owner 2026-09-09: carried by hand) ---------------------------
// The last kill leaves a skull on the bunker floor. One press within 100 TAKES it into the hand (carry notice
// via df_scav_carry_set "skull", no fire; lamp portals must refuse player.df_skull like the ember: df_portal_use,
// requests_M2fix.md). The return brings the carrier home; one press within 150 of table slot 1 PLACES it
// (df_coords df_table_slot, the slot the key card fills on the other side) under an orange glow, and M1
// completes on that. Nobody took it before the return: it lies at the tower return point under its glint,
// still pickable, never auto-placed. A carrier who goes down drops it at the feet (like the ember).

// Registry kind "skull" (df_coords df_models_init_items); the "orb" model if the kind is ever removed.
df_m1_skull_model()
{
    fallback = df_model( "orb" ); // also runs df_models_init

    if ( isdefined( level.df_models ) && isdefined( level.df_models["skull"] ) )
        return level.df_models["skull"];

    return fallback;
}

// Success: the skull drops at the last corpse and Maxis names it (ITEM_SKULL_MAXIS, the TAKE line since the
// dialogue audit v2), then a 30 s window (steps audit v2 #9: co-op players are still shooting when it drops)
// for someone to take it before the return. The poll started by the drop does the prompts and presses (and the
// room-wide puzzle prompt while it lies in the bunker); it keeps running after the return.
df_m1_skull_appear()
{
    level endon( "end_game" );

    // already on the table ("!df fire m1_skull" during the latch): nothing to take
    if ( isdefined( level.df_m1_skull_table ) )
        return;

    pos = level.df_m1_last_kill_pos;

    if ( !isdefined( pos ) )
        pos = df_m1_room_center();

    df_item_arrival( df_ground( pos ) ); // the shared strike of every quest item (owner 2026-09-11)
    df_m1_skull_drop( df_ground( pos ) );
    df_say( "ITEM_SKULL_MAXIS" );
    df_m1_skull_wait_take( 30 );
}

// Blocks until somebody carries the skull or `seconds` pass.
df_m1_skull_wait_take( seconds )
{
    level endon( "end_game" );

    deadline = gettime() + seconds * 1000;

    while ( gettime() < deadline && !isdefined( level.df_m1_skull_carrier ) )
        wait 0.1;

    if ( !isdefined( level.df_m1_skull_carrier ) )
        df_debug_print( "DF: m1 skull not taken in " + seconds + " s, it comes along to the tower" );
}

// A skull still lying on the floor after the return moves to the tower return point (48 units left of where
// the first player lands) so it is never left in the bunker; a carried skull travels with its carrier.
df_m1_skull_follow_return()
{
    if ( !isdefined( level.df_m1_skull ) || isdefined( level.df_m1_skull_carrier ) )
        return;

    c = df_coord( "DF_TOWER_RETURN" );
    df_m1_skull_drop( df_ground( c.origin + anglestoright( c.angles ) * -48 ) );
    df_debug_print( "DF: m1 skull lies at the tower return point, take it to the table" );
}

// The skull lies on the floor under a glint (fx_zmb_tranzit_key_glint, the part glint, zm_transit_fx.gsc:105)
// and the poll (prompts / presses) runs from here until the placement.
df_m1_skull_drop( ground )
{
    df_m1_skull_remove_floor();
    level.df_m1_skull = spawn( "script_model", ground + ( 0, 0, 8 ) );
    level.df_m1_skull setmodel( df_m1_skull_model() );
    level.df_m1_skull_fx = df_fx_loop( "fx_zmb_tranzit_light_glow", ground + ( 0, 0, 20 ) );
    playsoundatposition( "zmb_buildable_piece_add", ground );
    level thread df_m1_skull_poll();
    df_debug_print( "DF: m1 skull on the floor at " + int( ground[0] ) + " " + int( ground[1] ) + " " + int( ground[2] ) + ", one press takes it" );
}

// Prompts and presses every 0.05 s (df_press_use is edge-triggered): a standing player within 100 of the floor
// skull takes it (not while carrying the relay, an orb or the ember); the carrier within 150 of slot 1 places
// it. While the skull lies on the BUNKER floor, every other player in the room sees the puzzle prompt "take
// the skull" (df_prompt_puzzle, hidden with `!df hints off`; steps audit v2 #9) until it is taken or leaves
// the room. One instance at a time (a new drop restarts it); ends with the placement or a skip.
df_m1_skull_poll()
{
    level endon( "end_game" );
    level endon( "df_skip_m1" );
    level endon( "df_m1_skull_placed" );
    level notify( "df_m1_skull_poll_stop" );
    level endon( "df_m1_skull_poll_stop" );

    while ( true )
    {
        wait 0.05;

        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) )
            {
                df_m1_skull_prompt_clear( player );
                df_m1_skull_room_prompt( player, 0 );
                continue;
            }

            if ( is_true( player.df_skull ) )
            {
                df_m1_skull_room_prompt( player, 0 );

                if ( distancesquared( player.origin, df_table_slot( 1 ) ) > 150 * 150 )
                {
                    df_m1_skull_prompt_clear( player );
                    continue;
                }

                df_m1_skull_prompt_set( player, "Press [{+activate}] to place the stone" );

                if ( player df_press_use() )
                    df_m1_skull_place_by( player );

                continue;
            }

            busy = is_true( player.df_carrying_relay ) || isdefined( player.df_orb ) || is_true( player.df_ember );

            if ( busy || !isdefined( level.df_m1_skull ) || distancesquared( player.origin, level.df_m1_skull.origin ) > 100 * 100 )
            {
                df_m1_skull_prompt_clear( player );
                df_m1_skull_room_prompt( player, df_m1_skull_in_room_with( player ) );
                continue;
            }

            df_m1_skull_room_prompt( player, 0 );
            df_m1_skull_prompt_set( player, "Press [{+activate}] to take the stone" );

            if ( player df_press_use() )
                df_m1_skull_take( player );
        }
    }
}

// True while the floor skull and this player are both inside the bunker (the take window and just after).
df_m1_skull_in_room_with( player )
{
    if ( !isdefined( level.df_m1_skull ) )
        return 0;

    return df_m1_in_room( level.df_m1_skull.origin, 900 ) && df_m1_in_room( player.origin, 900 );
}

// Room-wide puzzle prompt slot (own flag so the mechanic prompt and other steps' prompts are never touched).
df_m1_skull_room_prompt( player, show )
{
    if ( is_true( show ) )
    {
        if ( is_true( player.df_m1_skull_room_prompt ) )
            return;

        player.df_m1_skull_room_prompt = 1;
        player df_prompt_puzzle( 1, "Take the stone before the cold closes" );
        return;
    }

    if ( !is_true( player.df_m1_skull_room_prompt ) )
        return;

    player.df_m1_skull_room_prompt = 0;
    player df_prompt_puzzle( 0, undefined );
}

// Own prompt slot (owner-guarded so another step's df_prompt is never removed by this poll).
df_m1_skull_prompt_set( player, text )
{
    if ( is_true( player.df_m1_skull_prompt ) )
        return;

    player.df_m1_skull_prompt = 1;
    player df_prompt( 1, text );
}

df_m1_skull_prompt_clear( player )
{
    if ( !is_true( player.df_m1_skull_prompt ) )
        return;

    player.df_m1_skull_prompt = 0;
    player df_prompt( 0, undefined );
}

// The skull goes into the hand: flag (lamp portals refuse it), carry notice, pickup sound, drop watch.
df_m1_skull_take( player )
{
    df_m1_skull_remove_floor();
    df_m1_skull_prompt_clear( player );
    player.df_skull = 1;
    level.df_m1_skull_carrier = player;
    player playsoundtoplayer( "zmb_buildable_pickup", player );
    df_scav_carry_set( "skull", 1, 1, player );
    level thread df_m1_skull_monitor( player );
    df_touch( "m1" );
    df_debug_print( "DF: m1 skull taken by " + player.name + ", carry it to the table (slot 1, one press within 150)" );
}

// The skull leaves the hand (placed, dropped, skip): flag off, notice cleared.
df_m1_skull_release( player )
{
    if ( isdefined( player ) )
    {
        player.df_skull = undefined;
        df_m1_skull_prompt_clear( player );
    }

    level.df_m1_skull_carrier = undefined;
    df_scav_carry_clear( "skull" );
}

// Every carried skull back out of the hands (no poll restart: callers decide); both prompt slots cleared.
df_m1_skull_clear_hands()
{
    foreach ( player in getplayers() )
    {
        if ( is_true( player.df_skull ) )
            df_m1_skull_release( player );

        df_m1_skull_prompt_clear( player );
        df_m1_skull_room_prompt( player, 0 );
    }

    level.df_m1_skull_carrier = undefined;
}

// Skip: floor skull, carried skull and the poll all go.
df_m1_skull_clear_world()
{
    level notify( "df_m1_skull_poll_stop" );
    df_m1_skull_remove_floor();
    df_m1_skull_clear_hands();
}

// The carrier goes down (player_is_in_laststand, _zm_laststand.gsc:56): the skull drops at the feet with its
// glint and the PROGRESS LOST cue (df_cue_fail: emp thump to all + ash where it fell), anyone takes it again.
// The carrier leaves the game: it drops at the tower return point.
df_m1_skull_monitor( player )
{
    level endon( "end_game" );
    level endon( "df_skip_m1" );

    while ( true )
    {
        wait 0.1;

        if ( !isdefined( player ) )
        {
            df_m1_skull_release( undefined );
            df_m1_skull_drop( df_ground( df_coord( "DF_TOWER_RETURN" ).origin ) );
            df_debug_print( "DF: m1 skull carrier left, the skull lies at the tower return point" );
            return;
        }

        if ( !is_true( player.df_skull ) )
            return;

        if ( player maps\mp\zombies\_zm_laststand::player_is_in_laststand() || !is_player_valid( player ) )
        {
            ground = df_ground( player.origin );
            df_m1_skull_release( player );
            df_m1_skull_drop( ground );
            df_cue_fail( ground );
            df_debug_print( "DF: m1 skull dropped (" + player.name + " went down), take it again" );
            return;
        }
    }
}

// The carrier places it: hand emptied, skull on slot 1 with the full cue.
df_m1_skull_place_by( player )
{
    df_m1_skull_release( player );
    df_debug_print( "DF: m1 skull placed by " + player.name );
    df_m1_skull_place_table( 0 );
}

df_m1_skull_remove_floor()
{
    if ( isdefined( level.df_m1_skull ) )
        level.df_m1_skull delete();

    df_fx_stop( level.df_m1_skull_fx );
    level.df_m1_skull = undefined;
    level.df_m1_skull_fx = undefined;
}

// Skull on table slot 1 (10 up: half the zombie_skull height, catalogue 16x23x21), slow spin like the hole,
// orange lamp light (zm_transit_fx.gsc:114) 8 above it. quiet = 1 (goto): no trail. The line (M1_DONE) is
// df_m1_finish's; ITEM_SKULL_MAXIS moved to the drop. Any floor or carried skull is gone first (debug / goto
// paths). The "df_m1_skull_placed" notify is LAST on purpose: it ends the poll (which may be the calling
// thread) and wakes df_m1_wait_placed.
df_m1_skull_place_table( quiet )
{
    if ( isdefined( level.df_m1_skull_table ) )
        return;

    df_m1_skull_remove_floor();
    df_m1_skull_clear_hands();
    pos = df_table_slot( 1 ) + ( 0, 0, 10 );
    level.df_m1_skull_table = spawn( "script_model", pos );
    level.df_m1_skull_table setmodel( df_m1_skull_model() );
    level.df_m1_skull_table_fx = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", pos + ( 0, 0, 8 ) );
    level thread df_m1_skull_spin();
    df_debug_print( "DF: m1 skull on the table, slot 1 (" + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) + ")" );

    if ( !is_true( quiet ) )
        level thread df_act2_maxis_trail( pos + ( 0, 0, 200 ), pos );

    level notify( "df_m1_skull_placed" );
}

df_m1_skull_spin()
{
    level endon( "end_game" );

    while ( isdefined( level.df_m1_skull_table ) )
    {
        level.df_m1_skull_table rotateyaw( 360, 12 );
        level.df_m1_skull_table waittill( "rotatedone" );
    }
}

// "!df fire m1_skull": a skull on the floor or in a hand -> placed on the table (completes M1 once the cold
// room is done); none -> one drops 60 in front of the player.
df_m1_debug_skull( player )
{
    if ( isdefined( level.df_m1_skull_table ) )
    {
        df_debug_print( "DF: m1 skull already on the table" );
        return;
    }

    if ( isdefined( level.df_m1_skull ) || isdefined( level.df_m1_skull_carrier ) )
    {
        df_m1_skull_place_table( 0 );
        return;
    }

    df_m1_skull_drop( df_ground( player.origin + anglestoforward( ( 0, player.angles[1], 0 ) ) * 60 ) );
}

// =========================================================================================
// M2 - Fire and Ash
// =========================================================================================

// Boot: the four braziers stand along the lava from game start with their ember glow (owner rule 2026-09-08);
// df_boot has already run df_coords_init when the acts register.
df_m2_boot()
{
    level endon( "end_game" );

    wait 0.1;
    df_m2_place_braziers();
    level thread df_m2_debug_restage_hook();
}

// Arms the braziers: brazier 1 is lit (the AVAILABLE focus sits on its rim), the ember and the burning kills
// count from here. All four full: the nodes export, the tower answers in orange 12 s with the fire side's
// spectacle (df_m2_column: a 20 s smoke column at the tower top, the Maxis counterpart of the Richtofen storm),
// M2_DONE and the uniform step sting (df_complete, not quiet).
df_m2_run()
{
    level endon( "end_game" );

    df_m2_place_braziers();
    level.df_m2_target = df_m2_quota();
    level.df_m2_armed = 1;
    df_death_listen_add( "m2", ::df_m2_on_zombie_death );
    level thread df_m2_skip_cleanup();
    level thread df_m2_debug_hook();
    level thread df_m2_ember_poll();
    level thread df_m2_burn_watch();
    level thread df_m2_power_penalty();
    level thread df_m2_fists_loop(); // owner 2026-09-11 (fists 7): the knuckles are the wrong tool here
    level thread df_m2_grave_spawner(); // owner 2026-09-11: gentle waves near a lit grave
    level.df_m2_ember_returned = 0;
    level.df_m2_ember_charged = 0;
    df_m2_ember_spawn_table();
    df_step_focus( "m2", level.df_m2_ember_pos + ( 0, 0, 10 ) );
    df_debug_print( "DF: m2 the ember burns on the table: take it (one press), touch any tombstone with it, " + level.df_m2_target + " burning zombies at a lit one make it vanish; all four gone = bring the charged ember back to the table" );

    while ( !df_m2_all_done() || !is_true( level.df_m2_ember_returned ) )
        level waittill( "df_m2_check" );

    level.df_m2_armed = 0;
    df_death_listen_remove( "m2" );
    df_m2_export_nodes();
    df_tower_fx_start( "maxis" );
    level thread df_tower_fx_stop_after( 12 );
    level thread df_m2_column( 20 );
    df_say( "M2_DONE" );
    df_complete( "m2" );
}

// The fire side's far spectacle: fx_zmb_tranzit_smk_column_lrg (the big smoke column the map places over its
// burning wrecks, createfx zm_transit_fx.csc:596; alias zm_transit_fx.gsc:101) at the tower top for `seconds`.
// "!df fire m2_column" replays it. Nothing when the tower struct is missing (df_tower_top undefined).
df_m2_column( seconds )
{
    level endon( "end_game" );

    top = df_tower_top();

    if ( !isdefined( top ) )
        return;

    fx = df_fx_loop( "fx_zmb_tranzit_smk_column_lrg", top );
    df_debug_print( "DF: m2 smoke column at the tower top for " + seconds + " s" );
    wait( seconds );
    df_fx_stop( fx );
}

// Burning kills per lit brazier (owner 2026-09-09): five, fixed for solo; a bigger brazier_burns row wins.
df_m2_quota()
{
    q = df_scaled( "brazier_burns" );

    if ( !isdefined( q ) || q < 5 )
        q = 5;

    return q;
}

// "!df goto" past m2: all four braziers lit to the last stage (quietly: no sting, no line per brazier) and
// exported as nodes.
df_m2_setup()
{
    df_m2_place_braziers();

    if ( !isdefined( level.df_m2_target ) )
        level.df_m2_target = df_m2_quota();

    foreach ( b in level.df_m2_braziers )
        df_m2_fill( b, 1 );

    level.df_m2_ember_returned = 1;
    level.df_m2_ember_charged = 1;
    df_m2_export_nodes();
    level thread df_m2_debug_restage_hook();
}

// "!df goto" past m2: the braziers stay (they are the world's), the ember and the listeners go.
df_m2_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level waittill( "df_skip_m2" );
    level.df_m2_armed = 0;
    df_death_listen_remove( "m2" );
    df_m2_ember_table_remove();

    foreach ( player in getplayers() )
    {
        if ( is_true( player.df_ember ) )
            df_m2_ember_release( player );

        df_m2_prompt_clear( player );
    }
}

// "!df fire m2_fill" or "!df souls": every brazier completes. "!df fire m2_light": the next unlit brazier
// lights as if an ember had reached it (an ember still in a hand is consumed once none is left unlit, by the
// poll). "!df fire m2_ember": the first player holds an ember (from the nearest lit brazier, or brazier 1).
// "!df fire m2_penalty": the power-on stage drop, now. "!df fire m2_column": the 20 s tower smoke column.
df_m2_debug_hook()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level endon( "df_skip_m2" );

    while ( true )
    {
        what = level waittill_any_return( "df_debug_m2_fill", "df_debug_souls_done", "df_debug_m2_light", "df_debug_m2_ember", "df_debug_m2_penalty", "df_debug_m2_column" );

        if ( what == "df_debug_m2_column" )
        {
            level thread df_m2_column( 20 );
            continue;
        }

        if ( what == "df_debug_m2_light" )
        {
            b = df_m2_nearest( undefined, undefined, 0 );

            if ( isdefined( b ) )
                df_m2_light( b, undefined );
            else
                df_debug_print( "DF: m2 every brazier is lit" );

            continue;
        }

        if ( what == "df_debug_m2_ember" )
        {
            players = getplayers();

            if ( players.size > 0 && !is_true( players[0].df_ember ) )
                df_m2_ember_take( players[0] );

            continue;
        }

        if ( what == "df_debug_m2_penalty" )
        {
            df_m2_power_drop();
            continue;
        }

        foreach ( b in level.df_m2_braziers )
            df_m2_fill( b );

        level.df_m2_ember_returned = 1;
        df_debug_print( "DF: m2 stones spent and ember returned by debug" );
        level notify( "df_m2_check" );
    }
}

// "!df fire m2_restage": re-reads df_model( "brazier" ) on the standing braziers (after a live model swap)
// and re-applies stage fx and crackle at the new rim height. Alive from boot.
df_m2_debug_restage_hook()
{
    level endon( "end_game" );

    if ( is_true( level.df_m2_restage_hooked ) )
        return;

    level.df_m2_restage_hooked = 1;

    while ( true )
    {
        level waittill( "df_debug_m2_restage" );
        df_m2_restage();
    }
}

df_m2_restage()
{
    if ( !isdefined( level.df_m2_braziers ) )
        return;

    model = df_model( "brazier" );

    foreach ( b in level.df_m2_braziers )
    {
        if ( isdefined( b.model ) )
            b.model setmodel( model );

        b.rim = df_m2_rim_height( model );
        df_m2_crackle_stop( b );
        stage = b.stage;
        b.stage = -1;
        df_m2_set_stage( b, stage );
    }

    df_debug_print( "DF: m2 braziers restaged with " + model + " (rim " + df_m2_rim_height( model ) + ")" );
}

// Exactly FOUR braziers (owner 2026-09-09, whatever the player count) at DF_BRAZIER_1..4 (df_coords: the
// owner's spots along the lava between the tower and the cornfield lamp), model df_model( "brazier" )
// (df_coords registry), dark ember glow to start, unlit. Names brazier_1..4 (the Step 6 fallback names).
df_m2_place_braziers()
{
    if ( isdefined( level.df_m2_braziers ) )
        return;

    level.df_m2_braziers = [];
    model = df_model( "brazier" );

    for ( i = 0; i < 4; i++ )
    {
        c = df_coord( "DF_BRAZIER_" + ( i + 1 ) );
        b = spawnstruct();
        b.idx = i;
        b.name = "brazier_" + ( i + 1 );
        b.origin = df_ground( c.origin + ( 0, 0, 20 ) ); // on the ground (owner 2026-09-11: they hovered)
        b.count = 0;
        b.stage = -1;
        b.lit = 0;
        b.done = 0;
        b.fx = [];
        b.rim = df_m2_rim_height( model );
        b.model = spawn( "script_model", b.origin );
        b.model setmodel( model );
        b.model.angles = c.angles;
        // player collision (owner 2026-09-11: players walked through them), one clip 16 up like the table's
        b.clip = spawn( "script_model", b.origin + ( 0, 0, 16 ) );
        b.clip setmodel( df_model( "clip" ) );
        b.clip.angles = c.angles;
        df_m2_set_stage( b, 0 );
        level.df_m2_braziers[i] = b;
        df_debug_print( "DF: m2 " + b.name + " at " + int( c.origin[0] ) + " " + int( c.origin[1] ) + " " + int( c.origin[2] ) + " (" + model + ")" );
    }

    level thread df_m2_side_watch();
}

// The tombstones belong to Maxis's side: when the fork locks Richtofen they go (owner 2026-09-11).
df_m2_side_watch()
{
    level endon( "end_game" );
    level waittill( "df_side_locked", side );

    if ( side != "rich" )
        return;

    df_m2_retire_braziers();
}

df_m2_retire_braziers()
{
    if ( !isdefined( level.df_m2_braziers ) )
        return;

    foreach ( b in level.df_m2_braziers )
    {
        foreach ( fx in b.fx )
            df_fx_stop( fx );

        b.fx = [];
        df_m2_crackle_stop( b );

        if ( isdefined( b.model ) )
            b.model delete();

        if ( isdefined( b.clip ) )
            b.clip delete();
    }

    level.df_m2_braziers = [];
    df_debug_print( "DF: Richtofen side locked, the four tombstones are gone" );
}

// Height of the bowl's rim above the anchor = the TOP of the registry model, measured (df_coords
// df_model_top_z( "brazier" ): the small explicit table, then the glTF catalogue; the low lava-rock cairn
// p6_zm_rocks_small_cluster_03 is 16). Every stage fx sits relative to it (df_m2_set_stage), so a live model
// swap (`!df model brazier <name>` then `!df fire m2_restage`) lands the fire on the new top by itself. The
// family table below only answers for a model name that is NOT the registry's (issubstr as
// _zm_utility.gsc:2941).
df_m2_rim_height( model )
{
    // the tombstone burns from its base (owner 2026-09-11: the flame started at the top)
    if ( issubstr( model, "tombstone" ) )
        return 2;

    if ( model == df_model( "brazier" ) )
        return df_model_top_z( "brazier" );

    if ( issubstr( model, "rocks" ) )
        return 16;

    if ( issubstr( model, "barrel" ) )
        return 44;

    if ( issubstr( model, "bucket" ) )
        return 20;

    if ( issubstr( model, "etrap" ) )
        return 18;

    if ( issubstr( model, "stove" ) )
        return 36;

    return 28;
}

// Stage FX (spec 5, M2), all relative to the rim (b.rim = the model top): 0 ember glow 6 below the rim (unlit;
// on the 16-tall cairn it shows between the rocks), 1 medium fire at the rim (lit), 2 large fire, 3 two large
// fires 10 apart plus rising ash 20 above (zm_transit_fx.gsc:90, 99, 100, 81). From stage 1 the brazier crackles.
df_m2_set_stage( b, stage )
{
    if ( stage == b.stage )
        return;

    b.stage = stage;

    foreach ( fx in b.fx )
        df_fx_stop( fx );

    b.fx = [];
    top = b.origin + ( 0, 0, b.rim );

    // owner 2026-09-11: an unlit tombstone shows nothing; a lit one carries one small flame; a spent one is gone
    // (df_m2_fill deletes the model and leaves the scorched glow itself)
    if ( stage <= 0 )
    {
        df_m2_crackle_stop( b );
        return;
    }

    df_m2_crackle_start( b );
    f = df_fx_loop( "fx_zmb_tranzit_fire_med", top );

    if ( isdefined( f ) )
    {
        b.fx[b.fx.size] = f;
        level thread df_fx_keepalive( f );
    }
}

// Low fire crackle on a lit brazier: zmb_fire_loop, the loop vanilla puts on a burning zombie
// (zm_transit_lava.gsc:224), on its own tag_origin at the rim so it survives stage changes.
df_m2_crackle_start( b )
{
    if ( isdefined( b.snd ) )
        return;

    b.snd = spawn( "script_model", b.origin + ( 0, 0, b.rim ) );
    b.snd setmodel( "tag_origin" );
    b.snd playloopsound( "zmb_fire_loop" );
}

df_m2_crackle_stop( b )
{
    if ( isdefined( b.snd ) )
    {
        b.snd stoploopsound();
        b.snd delete();
    }

    b.snd = undefined;
}

// ---- braziers: queries ---------------------------------------------------------------------

// Nearest brazier to pos within radius (both optional: undefined = any), with the wanted lit state
// (lit = 1 lit and unfinished, 2 lit whether finished or not, 0 unlit, undefined = any). Returns undefined
// when none matches.
df_m2_nearest( pos, radius, lit )
{
    if ( !isdefined( level.df_m2_braziers ) )
        return undefined;

    best = undefined;
    best_d2 = undefined;

    if ( isdefined( radius ) )
        best_d2 = radius * radius;

    foreach ( b in level.df_m2_braziers )
    {
        if ( isdefined( lit ) && lit == 1 && ( !b.lit || b.done ) )
            continue;

        if ( isdefined( lit ) && lit == 2 && !b.lit )
            continue;

        if ( isdefined( lit ) && lit == 0 && b.lit )
            continue;

        d2 = 0;

        if ( isdefined( pos ) )
            d2 = distancesquared( pos, b.origin );

        if ( isdefined( best_d2 ) && d2 >= best_d2 )
            continue;

        best = b;
        best_d2 = d2;
    }

    return best;
}

// True when a lit brazier stands within radius of pos (denizen side rule, df_m1_protected).
df_m2_lit_near( pos, radius )
{
    if ( !isdefined( level.df_m2_braziers ) )
        return false;

    foreach ( b in level.df_m2_braziers )
    {
        if ( b.lit && distancesquared( pos, b.origin ) < radius * radius )
            return true;
    }

    return false;
}

df_m2_lit_count()
{
    n = 0;

    foreach ( b in level.df_m2_braziers )
    {
        if ( b.lit )
            n++;
    }

    return n;
}

// ---- ember (audit 9, ITEM_EMBER_MAXIS; owner 2026-09-09: one ember lights them all) -----------------
// Only brazier 1 is lit by M2. A player within 100 of any LIT brazier takes an ember (one press) while an
// unlit brazier remains; within 100 of an UNLIT brazier the carrier lights it (one press) and KEEPS the ember:
// it is consumed only when the fourth brazier burns (owner fix: "I could not light the third one"). Carrying
// burns: lava_burning on the player (zm_transit_fx.gsc:40, replayed like df_act3_vacuum's carry fx), 5 hp
// per second, no lamp portals (player.df_ember, refused in df_portal_use), lost when downed (take a new one
// from any lit brazier). Any order: brazier 1 -> 2 -> 3 -> 4 is only the natural walk.

// Prompts and presses for every standing player, 0.05 s (df_press_use consumes the key edge: only polled
// for players who can act on something). An ember in hand with nothing left to light is consumed here.
df_m2_ember_poll()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level endon( "df_skip_m2" );

    while ( true )
    {
        wait 0.05;

        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) || is_true( player.df_carrying_relay ) || isdefined( player.df_orb ) || is_true( player.df_skull ) )
            {
                df_m2_prompt_clear( player );
                continue;
            }

            if ( is_true( player.df_ember ) )
            {
                // charged: it goes back into the table
                if ( is_true( level.df_m2_ember_charged ) )
                {
                    if ( distancesquared( player.origin, df_coord( "DF_SOCKET" ).origin ) <= 150 * 150 )
                    {
                        df_m2_prompt_set( player, "Press [{+activate}] to return the ember" );

                        if ( player df_press_use() )
                            df_m2_ember_return( player );
                    }
                    else
                        df_m2_prompt_clear( player );

                    continue;
                }

                b = df_m2_nearest( player.origin, 100, 0 );

                if ( !isdefined( b ) )
                {
                    df_m2_prompt_clear( player );
                    continue;
                }

                df_m2_prompt_set( player, "Press [{+activate}] to light the grave" );

                if ( player df_press_use() )
                    df_m2_light( b, player );

                continue;
            }

            // the ember waits on the table
            if ( !is_true( level.df_m2_ember_on_table ) || distancesquared( player.origin, level.df_m2_ember_pos ) > 120 * 120 )
            {
                df_m2_prompt_clear( player );
                continue;
            }

            df_m2_prompt_set( player, "Press [{+activate}] to take the ember" );

            if ( player df_press_use() )
                df_m2_ember_take( player );
        }
    }
}

// Own prompt slot (owner-guarded so another step's df_prompt is never removed by this poll).
df_m2_prompt_set( player, text )
{
    if ( is_true( player.df_m2_prompt ) )
        return;

    player.df_m2_prompt = 1;
    player df_prompt( 1, text );
}

df_m2_prompt_clear( player )
{
    if ( !is_true( player.df_m2_prompt ) )
        return;

    player.df_m2_prompt = 0;
    player df_prompt( 0, undefined );
}

// The player takes an ember from lit brazier b: flag, carry notice (df_scav kind "ember"), burning fx, damage
// tick, drop watch, first-time line.
df_m2_ember_take( player )
{
    df_m2_ember_table_remove();
    player.df_ember = 1;
    df_m2_prompt_clear( player );
    player playsoundtoplayer( "zmb_buildable_pickup", player );
    df_snd_loop_burst( "zmb_fire_loop", player.origin + ( 0, 0, 40 ), 1.2 ); // owner pick 2026-09-11: puff = fire loop burst
    df_scav_carry_set( "ember", 1, 1, player );
    player thread df_m2_ember_carry();
    level thread df_m2_ember_monitor( player );
    df_touch( "m2" );
    df_debug_print( "DF: m2 ember taken from the table by " + player.name + " (5 hp/s while carried; it stays in hand for the whole step)" );

    if ( is_true( level.df_m2_ember_said ) )
        return;

    level.df_m2_ember_said = 1;
    df_say( "ITEM_EMBER_MAXIS" );
}

// The ember leaves the player (consumed or lost): flag off, notice cleared, fx thread ends.
df_m2_ember_release( player )
{
    player.df_ember = undefined;
    player notify( "df_m2_ember_end" );
    df_fx_stop( player.df_m2_ember_fx );
    player.df_m2_ember_fx = undefined;
    df_m2_prompt_clear( player );
    df_scav_carry_clear( "ember" );
}

// self = carrier. lava_burning is a short burst (POLISH_BRIEF): replayed every second on the spine like
// df_s6_carry_fx (linkto J_SpineLower, playfxontag tag zm_transit_lava.gsc:186), and 5 hp taken with it
// (dodamage on a player as zm_transit_lava.gsc:154), never below 15 hp so the ember alone cannot down anyone.
df_m2_ember_carry()
{
    self endon( "disconnect" );
    self endon( "df_m2_ember_end" );
    level endon( "end_game" );

    while ( is_true( self.df_ember ) )
    {
        df_fx_stop( self.df_m2_ember_fx );
        fxname = "lava_burning";

        if ( is_true( level.df_m2_ember_charged ) )
            fxname = "fx_zmb_tranzit_fire_med"; // charged: a real flame on the carrier

        ent = df_fx_loop( fxname, self.origin + ( 0, 0, 45 ) );

        if ( isdefined( ent ) )
            ent linkto( self, "J_SpineLower", ( 0, 0, 0 ), ( 0, 0, 0 ) );

        self.df_m2_ember_fx = ent;

        // audit v3 #3: never below half health (the fire side has no Juggernog), and no burn beside a lit grave
        if ( is_player_valid( self ) && self.health > int( self.maxhealth * 0.5 ) && !df_m2_lit_near( self.origin, 300 ) )
            self dodamage( 5, self.origin );

        wait 0.8;
        df_fx_stop( self.df_m2_ember_fx );
        self.df_m2_ember_fx = undefined;
        wait 0.2;
    }
}

// The ember is lost when the carrier goes down (player_is_in_laststand, _zm_laststand.gsc:56) or leaves:
// the PROGRESS LOST cue (df_cue_fail: emp thump to all + ash where it went out).
df_m2_ember_monitor( player )
{
    level endon( "end_game" );
    level endon( "df_skip_m2" );

    while ( isdefined( player ) && is_true( player.df_ember ) )
    {
        wait 0.1;

        if ( !isdefined( player ) )
            return;

        if ( player maps\mp\zombies\_zm_laststand::player_is_in_laststand() || !is_player_valid( player ) )
        {
            df_m2_ember_release( player );
            df_cue_fail( player.origin );
            df_m2_ember_spawn_table();
            df_say( "M2_EMBER_LOST" );
            df_debug_print( "DF: m2 ember lost (" + player.name + " went down), it waits on the table again" );
            return;
        }
    }
}

// Lights brazier b (stage 1, whoosh zmb_firetrap_start _zm_traps.gsc:414 + ignite zm_transit_lava.gsc:275);
// player (optional) is the carrier: the ember STAYS in the hand while a brazier is still unlit and is consumed
// with the last one.
df_m2_light( b, player )
{
    if ( b.lit )
        return;

    b.lit = 1;
    df_m2_set_stage( b, 1 );

    // the first lit grave teaches the rule (audit v3 #4: M2_HINT_2 had no caller since the ember no longer burns out)
    if ( df_m2_lit_count() == 1 )
        df_hint_now( "m2", 2 );
    // fire whoosh, 1.4 s, 750 range: the closest thing to an ignition in the banks (zmb_firetrap_start and
    // "ignite" are Buried / lava-script aliases that no TranZit bank carries: both were silent)
    playsoundatposition( "zmb_phdflop_explo", b.origin + ( 0, 0, b.rim ) );
    df_fx_once( "fx_zmb_ash_rising_md", b.origin + ( 0, 0, b.rim + 10 ) );
    who = "m2";
    left = 4 - df_m2_lit_count();
    tail = "";

    if ( isdefined( player ) && isplayer( player ) )
    {
        df_m2_prompt_clear( player );
        df_touch( "m2" );
        who = player.name;
        player playsoundtoplayer( "zmb_buildable_piece_add", player );
        tail = ", the ember stays in hand";
    }

    df_debug_print( "DF: m2 " + b.name + " lit by " + who + " (" + df_m2_lit_count() + "/4 lit, " + left + " to go" + tail + ")" );
    level notify( "df_m2_check" );
}

// ---- burning kills ---------------------------------------------------------------------------

// A zombie that dies burning (zombie.is_on_fire, zm_transit_lava.gsc:179/241) within 250 of a LIT, unfinished brazier.
df_m2_on_zombie_death( zombie )
{
    if ( !isdefined( level.df_m2_braziers ) )
        return;

    // audit v3 #4: a kill that does not burn, beside a lit grave, is refused to the killer (deny buzz, 5 s throttle):
    // the silent rule "they must burn" is shown instead of guessed
    if ( !is_true( zombie.is_on_fire ) )
    {
        if ( isdefined( zombie.attacker ) && isplayer( zombie.attacker ) && isdefined( df_m2_nearest( zombie.origin, 250, 1 ) ) )
        {
            if ( !isdefined( zombie.attacker.df_m2_deny_ms ) || gettime() - zombie.attacker.df_m2_deny_ms > 5000 )
            {
                zombie.attacker.df_m2_deny_ms = gettime();
                df_cue_deny( zombie.attacker );
            }
        }

        return;
    }

    best = df_m2_nearest( zombie.origin, 250, 1 );

    if ( !isdefined( best ) )
        return;

    df_touch( "m2" );
    best.count++;
    // the soul leaves the burning body as it bursts (owner 2026-09-11): a fire burst at the zombie, then the trail
    df_fx_burst( "fx_zmb_tranzit_fire_med", zombie.origin + ( 0, 0, 30 ), 0.6 );
    df_snd_near( "evt_player_swiped", zombie.origin, 600 );
    level thread df_act2_maxis_trail( zombie.origin, best.origin + ( 0, 0, best.rim + 10 ) );
    level thread df_m2_kill_cue( best );
    df_m2_update( best );
    level notify( "df_m2_check" );
}

// Each counted kill is heard at the bowl: the PROGRESS TICK (df_cue_tick with burst at the rim: piece-add
// clink + 0.6 s of lava fire) and the lava puff (ignite + rising ash), timed for the fire trail landing
// (df_act2_maxis_trail takes 0.4-1.5 s).
df_m2_kill_cue( b )
{
    level endon( "end_game" );

    wait 0.5;
    df_cue_tick( b.origin + ( 0, 0, b.rim ), 1 );
    df_m2_puff( b );
}

df_m2_puff( b )
{
    top = b.origin + ( 0, 0, b.rim );
    df_snd_loop_burst( "zmb_fire_loop", top, 1.2 ); // owner pick 2026-09-11: puff = fire loop burst
    df_fx_once( "fx_zmb_ash_rising_md", top + ( 0, 0, 10 ) );
}

// Audit 4 cue: a burning zombie (zombie.is_on_fire) entering 250 of a lit unfinished brazier makes it puff
// once (the bowl "notices" the fire): the silent rule "it must burn" is shown before the first kill.
// 1 s poll over get_round_enemy_array (_zm_utility.gsc:123).
df_m2_burn_watch()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level endon( "df_skip_m2" );

    while ( true )
    {
        wait 1.0;

        foreach ( zombie in get_round_enemy_array() )
        {
            if ( !isdefined( zombie ) || !is_true( zombie.is_on_fire ) || is_true( zombie.df_m2_puffed ) )
                continue;

            b = df_m2_nearest( zombie.origin, 250, 1 );

            if ( !isdefined( b ) )
                continue;

            zombie.df_m2_puffed = 1;
            df_m2_puff( b );
        }
    }
}

// Lit brazier: stage = 1 + floor( 2 * count / target ) (1 or 2); the quota fills it (stage 3). Each stage-up
// is the fire trap whoosh alone (zmb_firetrap_start, _zm_traps.gsc:414): the Avogadro thunder that played
// with it was electricity at a fire (art audit change 9, side leak) and is gone.
df_m2_update( b )
{
    if ( b.count >= level.df_m2_target )
    {
        df_m2_fill( b );
        return;
    }

    df_debug_print( "DF: m2 " + b.name + " " + b.count + "/" + level.df_m2_target );
}

// A brazier full = ONE node done (art audit changes 1 and 4): the SUB-GOAL cue at the rim (df_systems
// df_cue_subgoal: navcard chime 3D + 0.8 s fire flash + the canon node -> tower runner, maxis_sparks from the
// rim to the tower top, the far cue every TranZit player knows), then M2_MAXIS_BRAZIER. quiet = 1 (setup):
// stage only.
df_m2_fill( b, quiet )
{
    if ( b.done )
        return;

    b.lit = 1;
    b.done = 1;
    b.count = level.df_m2_target;
    top = b.origin + ( 0, 0, b.rim );

    // the stone is spent: a small burst, the model goes, a scorched glow marks the spot (Step 6 node)
    df_m2_set_stage( b, 0 );

    if ( !is_true( quiet ) )
    {
        df_fx_burst( "fx_zmb_tranzit_fire_lrg", top, 0.8 );
        df_fx_once( "fx_zmb_ash_rising_md", top + ( 0, 0, 10 ) );
        playsoundatposition( "zmb_explo_sweet", top );
    }

    if ( isdefined( b.model ) )
        b.model delete();

    if ( isdefined( b.clip ) )
        b.clip delete();

    g = df_fx_loop( "fx_zmb_lava_crevice_glow_50", b.origin + ( 0, 0, 2 ) );

    if ( isdefined( g ) )
    {
        b.fx[b.fx.size] = g;
        level thread df_fx_keepalive( g );
    }

    if ( is_true( quiet ) )
        return;

    df_cue_subgoal( top );
    df_say( "M2_MAXIS_BRAZIER" );
    df_debug_print( "DF: m2 " + b.name + " spent and gone (" + df_m2_done_count() + "/4)" );

    if ( df_m2_all_done() )
        df_m2_ember_charged();
}

df_m2_done_count()
{
    n = 0;

    foreach ( b in level.df_m2_braziers )
    {
        if ( b.done )
            n++;
    }

    return n;
}

df_m2_all_done()
{
    foreach ( b in level.df_m2_braziers )
    {
        if ( !b.done )
            return false;
    }

    return true;
}

// ---- power penalty (audit 2.4: Maxis wants the power OFF) --------------------------------------

// While M2 runs: at every end_of_round (vanilla notify) with the power on, every brazier drops one stage.
df_m2_power_penalty()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level endon( "df_skip_m2" );

    while ( true )
    {
        level waittill( "end_of_round" );

        if ( !flag( "power_on" ) )
            continue;

        df_m2_power_drop();
    }
}

// One stage down per brazier: complete -> half quota (stage 2), stage 2 -> empty but lit, lit and empty ->
// unlit again (only while another brazier stays lit, so an ember can always be taken). The PROGRESS LOST cue
// (df_cue_fail: emp thump to all + ash) at the first brazier that shrank, an ash puff at every other one, and
// Maxis says why (M2_POWER_MAXIS, dialogue audit v2: "the fires shrink while the grid hums"); the fx follow
// the new stage.
df_m2_power_drop()
{
    if ( !isdefined( level.df_m2_braziers ) || !isdefined( level.df_m2_target ) )
        return;

    dropped = 0;
    first = undefined;

    foreach ( b in level.df_m2_braziers )
    {
        // owner 2026-09-11 rework: a spent stone stays spent; a lit hungry stone forgets its dead
        if ( b.done || !b.lit || b.count <= 0 )
            continue;

        b.count = 0;

        dropped++;
        rim = b.origin + ( 0, 0, b.rim );

        if ( !isdefined( first ) )
        {
            first = b;
            df_cue_fail( rim );
        }
        else
            df_fx_once( "fx_zmb_ash_rising_md", rim );
    }

    if ( dropped == 0 )
    {
        df_debug_print( "DF: m2 power on at end of round, nothing left to lose" );
        return;
    }

    df_say( "M2_POWER_MAXIS" );
    df_debug_print( "DF: m2 power ON at end of round: " + dropped + " lit stone(s) forget their dead (Maxis wants the dark)" );
}

// The lit braziers are Act 3's nodes (same shape as df_r2_export_nodes, kind "brazier").
df_m2_export_nodes()
{
    level.df_nodes = [];

    foreach ( b in level.df_m2_braziers )
    {
        node = spawnstruct();
        node.origin = b.origin;
        node.name = b.name;
        node.kind = "brazier";
        level.df_nodes[level.df_nodes.size] = node;
    }
}

// ---- the ember on the table (owner 2026-09-11 rework) --------------------------------------------
// The flame waits on table slot 2 (empty until Step 6) with the "take me" glint. Take: df_m2_ember_take.
df_m2_ember_spawn_table()
{
    df_m2_ember_table_remove();
    level.df_m2_ember_pos = df_table_slot( 2 ) + ( 0, 0, 6 );
    level.df_m2_ember_on_table = 1;
    level.df_m2_ember_table_fx = [];
    f = df_fx_loop( "fx_zmb_tranzit_fire_med", level.df_m2_ember_pos );

    if ( isdefined( f ) )
    {
        level.df_m2_ember_table_fx[level.df_m2_ember_table_fx.size] = f;
        level thread df_fx_keepalive( f );
    }

    g = df_fx_loop( "fx_zmb_tranzit_light_glow", level.df_m2_ember_pos + ( 0, 0, 14 ) );

    if ( isdefined( g ) )
        level.df_m2_ember_table_fx[level.df_m2_ember_table_fx.size] = g;

    df_debug_print( "DF: m2 the ember burns on the table (slot 2)" );
}

df_m2_ember_table_remove()
{
    level.df_m2_ember_on_table = 0;

    if ( isdefined( level.df_m2_ember_table_fx ) )
    {
        foreach ( fx in level.df_m2_ember_table_fx )
            df_fx_stop( fx );
    }

    level.df_m2_ember_table_fx = [];
}

// All four stones are spent: the ember in hand (or on the table) is charged. In hand: the carrier's flame grows,
// Maxis asks for it back, the prompt at the table says "return". On the table (nobody carried it at that moment):
// it goes back into the table by itself.
df_m2_ember_charged()
{
    level.df_m2_ember_charged = 1;
    df_say( "M2_EMBER_CHARGED" );

    // heard and seen (owner 2026-09-11): the sub-goal chime + flash + runner to the tower from the carrier
    foreach ( player in getplayers() )
    {
        if ( is_true( player.df_ember ) )
            df_cue_subgoal( player.origin + ( 0, 0, 40 ) );
    }

    if ( is_true( level.df_m2_ember_on_table ) )
    {
        df_m2_ember_return( undefined );
        return;
    }

    df_debug_print( "DF: m2 all four stones spent, the ember is charged: return it to the table (one press within 150)" );
}

// The charged ember goes into the table: fire burst at the socket, the hand is empty, M2 completes (df_m2_run).
df_m2_ember_return( player )
{
    if ( isdefined( player ) )
        df_m2_ember_release( player );

    df_m2_ember_table_remove();
    level.df_m2_ember_returned = 1;
    socket = df_coord( "DF_SOCKET" ).origin;
    df_fx_burst( "fx_zmb_tranzit_fire_lrg", socket + ( 0, 0, 30 ), 1.0 );
    df_fx_once( "fx_zmb_ash_rising_md", socket + ( 0, 0, 40 ) );
    playsoundatposition( "zmb_buildable_complete", socket );
    df_debug_print( "DF: m2 the charged ember is back in the table" );
    level notify( "df_m2_check" );
}

// ---- fists (owner 2026-09-11, idea 7) ---------------------------------------------------------
// Maxis wants fire, not the creature's current: a Galvaknuckle melee within 100 of a tombstone, or with the ember
// in hand, is refused (deny buzz + M2_KNUCKLES_MAXIS once per 20 s). Nothing else happens.
df_m2_fists_loop()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level endon( "df_skip_m2" );

    while ( true )
    {
        wait 0.05;

        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) || !df_melee_edge( player ) || !df_has_knuckles( player ) )
                continue;

            if ( !is_true( player.df_ember ) && !isdefined( df_m2_nearest( player.origin, 100, undefined ) ) )
                continue;

            df_cue_deny( player );

            if ( !isdefined( level.df_m2_fists_time ) || gettime() - level.df_m2_fists_time > 20000 )
            {
                level.df_m2_fists_time = gettime();
                df_say( "M2_KNUCKLES_MAXIS" );
            }

            df_debug_print( "DF: m2 " + player.name + " used the knuckles at the stones: refused" );
        }
    }
}

// ---- grave waves (owner 2026-09-11) --------------------------------------------------------------
// A player within 300 of a lit, hungry grave pulls one zombie every 4 s from the zone spawn structs within 700 of
// that grave (they cross the lava to reach him and burn), while fewer than 16 live. Gentler than the R2 lamps:
// five kills are enough.
df_m2_grave_spawner()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level endon( "df_skip_m2" );

    while ( true )
    {
        wait 4;

        if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
            continue;

        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) )
                continue;

            b = df_m2_nearest( player.origin, 300, 1 );

            if ( !isdefined( b ) )
                continue;

            if ( df_zombies_near( player.origin, 1200 ) >= 10 || getfreeactorcount() < 1 )
                continue;

            spots = df_m2_grave_spots( b );

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

            df_debug_print( "DF: m2 one zombie pulled to " + b.name + " (" + player.name + " beside it)" );
        }
    }
}

df_m2_grave_spots( b )
{
    if ( isdefined( b.df_spots ) )
        return b.df_spots;

    b.df_spots = df_spawn_spots_near( b.origin, 1200 );
    df_debug_print( "DF: m2 " + b.name + ": " + b.df_spots.size + " spawn structs for its waves" );
    return b.df_spots;
}
