// Dead Frequency - Act 2M "Maxis" (power stays OFF). Current design (refreshed 2026-09-25, design audit 6.12):
//   M1 "The Cold Room": a denizen riding a player is carried within 300 of the table under the tower (the
//                       relay socket: DF_SOCKET resolves to DF_TABLE); it dies there and an orange hole opens in
//                       front of the table. Walking into it takes the whole team to the woods behind the hunter's
//                       cabin, where a timed denizen hunt takes place (cold_room_time / cold_room_kills). Timeout:
//                       everyone is sent back and the latch starts again. The last kill leaves Maxis's LANTERN
//                       (df_model "skull" = p_lights_cagelight02_red_off, a dead red cage lamp; ITEM_HAND_MAXIS):
//                       one press TAKES it (carry notice, no lamp portals, dropped at the feet on down), everyone
//                       is sent back, and one press within 150 of table slot 1 PLACES it: that completes M1.
//                       Nobody took it before the return: it lies at the tower return point, still pickable.
//   M2 "Fire and Ash":  the lantern stays on the table for the whole step (nobody carries it). FOUR graves
//                       (df_model "brazier" = ch_tombstone1; "brazier" names are historical) stand OUTSIDE the
//                       map around Town from game start, out of reach: a SHOT lights one (df_m2_grave_shot_watch)
//                       and opens a kill zone on the ground where the shooter stood (on the road under the bus
//                       for a shot from the bus). Each lit grave runs a sprinter wave and a cold timer and needs
//                       df_m2_quota kills inside its zone (five at least, burning or not; a Galvaknuckle kill is
//                       refused, M2_KNUCKLES_MAXIS); a full grave bursts and is gone, a cold one can be shot
//                       again. All four spent: the lantern on the table becomes the burning lantern by itself
//                       (df_m2_ember_charged). Act 3's node is the cabin hearth (one). The dialogue ladder uses
//                       the phases DOOR / LANTERN (M1) and LIT (M2) of df_steps df_step_phase.
//   Side rules (audit 2.4, Maxis = fog / fire / silence): after M1 denizens leave players alone within a lit
//                       grave's kill zone while M2 runs (near the cabin hearth while Step 6 is open), denizen
//                       spawns are doubled, and power ON at the end of a round costs the fullest lit grave its kills.
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
// History below: the passes as they were written; the M2 summary above is the current design.
// Polish 2026-09-08 (tools/polish_act2_maxis.md): models through df_model( "portal" | "brazier" ); the hole
//   spins with an orbiting orange light; cold fog at the Nacht anchors; dig sound where a denizen rises; a
//   distinct final sting; an ash burst at the return point; braziers crackle and each counted kill is heard.
// Audit 2026-09-08 (tools/audit_D.md): braziers at boot, ember chain, hand item, ride cue, downed teleport,
//   side rules, power penalty. Cross-file needs in tools/requests_D.md.
// Owner run 2026-09-09 (tools/audit_M2fix.md): the hand is carried and placed manually (M1 completes on the
//   placement); the hole opens at anchor DF_PORTAL; four fixed braziers at the owner's spots, one ember lights
//   them all, five kills each (burning or not since 2026-09-23). Cross-file needs in tools/requests_M2fix.md.
// Polish V2 2026-09-09 (tools/audit_V2maxis.md, from audit_art / audit_steps_v2 / audit_dialogue_v2): one cue
//   grammar through the df_systems helpers (df_cue_tick = progress, df_cue_subgoal = a node done, df_cue_fail =
//   progress lost, df_cue_deny = wrong input, df_step_focus = the AVAILABLE glint, df_node_done_trail = the
//   canon node -> tower runner, df_vox_once = a vanilla Maxis line once); the whole file is fire family (no
//   blue one-shot: every trail here is maxis_sparks landing in df_cue_side_flash, df_act2_maxis_trail); the latch cue
//   is the portal spawn sound; the hand is announced when it APPEARS (ITEM_HAND_MAXIS, renamed from ITEM_SKULL_MAXIS,
//   owner 2026-09-25) with a 30 s window and a puzzle prompt for the room; M1 / M2 end on the uniform step
//   sting (df_complete, not quiet); brazier fire
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
#include scripts\zm\zm_transit\df_act3_vacuum; // df_s6_any_jetgun (the Jet Gun warning at M2 completion)
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

// Latch -> portal -> walk in -> timed hunt; a timeout loops back to the latch. Success: the hand appears in
// the bunker (a short window to take it), everyone returns, and the step ends when the hand is placed on
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
    // owner 2026-09-25: no AVAILABLE glint over the table (nothing of ours on the table)
    df_debug_print( "DF: m1 waiting for a denizen latched within 300 of the table" );

    while ( true )
    {
        df_m1_wait_latch();
        df_m1_portal_open();
        df_step_phase( "m1", "DOOR" ); // owner 2026-09-25: M1_DOOR_HINT_n while nobody stepped into the hole
        who = df_m1_wait_portal_use();
        result = df_m1_cold_room( who );
        df_step_phase( "m1", undefined ); // back to the ride rungs; success sets LANTERN below

        if ( result == "success" )
            df_step_phase( "m1", "LANTERN" ); // owner 2026-09-25: M1_LANTERN_HINT_n until it is on the table

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
// step blocks until the hand is on slot 1 (df_m1_skull_place_table notifies; a hand already placed by
// "!df fire m1_skull" during the latch counts).
df_m1_wait_placed()
{
    level endon( "end_game" );

    level.df_m1_mode = "place";
    df_s7_tower_safety_volume( 1 );

    if ( isdefined( level.df_m1_skull_table ) )
        return;

    df_debug_print( "DF: m1 waiting for the lantern on table slot 1 (carry it within 150 of the table, one press)" );
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

// "!df goto" past m1: the hand is already on the table, the side rules apply.
df_m1_setup()
{
    level.df_m1_mode = undefined;
    level.df_m1_phase = 0;
    df_m1_skull_place_table( 1 );
    df_m1_after_rules();
}

// Everything M1 spawned goes on "!df goto" past it: portal, lights, fog, huds, cold room denizens, floor hand,
// a carried hand. The hooks stay (df_m1_setup re-arms them right after) and the tower safety volume comes back.
df_m1_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_m1_done" );
    level waittill( "df_skip_m1" );

    if ( is_true( level.df_m1_phase ) )
    {
        df_m1_phase_teardown();
        level thread df_m1_return_players(); // owner 2026-09-25: a goto during the cold room left the players in the woods
    }

    df_m1_zone_end();
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
    df_debug_print( "DF: m1 side rules on: denizens avoid the graves (M2) and the cabin fireplace (Step 6) within 400, fog spawns doubled" );
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
// rc3 (owner): the denizens leave a player alone ONLY beside a lit grave while M2 runs (the ember run). The tower is a
// denizen zone in vanilla (the cornfield fog has no safety volume) and stays one: no permanent camp. The graves
// stand in Town since 2026-09-23, outside the fog: denizens rarely reach them, the rule is harmless there.
df_m1_protected( pos )
{
    // owner 2026-09-25: the lamp steps (Richtofen R2, Maxis M3): no denizen near their lamps, power on or off
    if ( df_lamp_step_safe( pos ) )
        return true;

    // owner 2026-09-23: near ANY of the four graves while M2 runs, lit or not (the walk to light one was a denizen trap),
    // and near the cabin hearth while Step 6 is open (the Jet Gun draw there takes the whole gun)
    if ( is_true( level.df_m2_armed ) )
        return df_m2_grave_near( pos, 400 );

    if ( isdefined( level.df_side ) && level.df_side == "maxis" && isdefined( level.df_step_avail_round ) && isdefined( level.df_step_avail_round["step6"] ) && !df_is_done( "step6" ) )
        return df_m2_hearth_near( pos, 400 ); // owner 2026-09-25: Maxis only (the hooks are installed on both sides now)

    return false;
}

// owner 2026-09-25: during a lamp step (R2 / M3, level.df_lamp_safe_lamps set by those steps) a circle of
// level.df_lamp_safe_radius (320: vanilla's powered-lamp circle is 256, _zm_transit.gsc player_entered_safety_light)
// around each of the step's lamps is denizen-free whatever the power.
df_lamp_step_safe( pos )
{
    if ( !isdefined( level.df_lamp_safe_lamps ) || !isdefined( pos ) )
        return false;

    r = 320;

    if ( isdefined( level.df_lamp_safe_radius ) )
        r = level.df_lamp_safe_radius;

    foreach ( lamp in level.df_lamp_safe_lamps )
    {
        if ( isdefined( lamp ) && isdefined( lamp.origin ) && distance2dsquared( pos, lamp.origin ) < r * r )
            return true;
    }

    return false;
}

// True when this side's Step 6 node, the cabin hearth (DF_CABIN_HEARTH), is within radius of pos.
df_m2_hearth_near( pos, radius )
{
    c = df_coord( "DF_CABIN_HEARTH" );

    if ( !isdefined( c ) )
        return false;

    return distancesquared( pos, c.origin ) < radius * radius;
}

// True when one of the M2 graves stands within radius of pos, whatever its state.
df_m2_grave_near( pos, radius )
{
    if ( !isdefined( level.df_m2_braziers ) )
        return false;

    foreach ( b in level.df_m2_braziers )
    {
        if ( isdefined( b ) && isdefined( b.origin ) && distancesquared( pos, b.origin ) < radius * radius )
            return true;

        if ( isdefined( b ) && isdefined( b.zone ) && b.lit && !b.done && distancesquared( pos, b.zone ) < radius * radius )
            return true; // owner 2026-09-25: the kill zone of a lit grave
    }

    return false;
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
    // owner 2026-09-25: a rider carried into the tower's safety box stays on (the box only stops NEW latches there)
    if ( isdefined( level.df_m1_mode ) && level.df_m1_mode == "latch" && isdefined( player.screecher ) )
        return true;

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
// the vanilla death path (ash fx, weapon restored to the player). Owner 2026-09-25: the tower keeps its vanilla
// safety box (audit #6 had removed it so denizens rose AT the tower and latched there: the ride was free). A
// denizen has to be picked up in the fog and carried in; df_m1_should_runaway keeps a rider on through the box.
df_m1_wait_latch()
{
    level endon( "end_game" );

    level.df_m1_mode = "latch";
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
// Audit #6: the FIRST time anyone is ridden after M1 opened, the table sounds its cue and Maxis speaks
// (M1_EVENT alone: the dialogue audit v2 dropped the hint rung that said the same thing 6.5 s later; owner
// 2026-09-25: sound cue only, no table fx any more): the counter-reflex "do not knife it".
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

// Once per game: the portal spawn cue at the table and M1_EVENT (the event line is the whole teaching; no
// hint rung here).
df_m1_ride_cue()
{
    level endon( "end_game" );

    df_debug_print( "DF: m1 first ride: table cue + event line" );
    df_say( "M1_EVENT" );
    df_m1_table_pulse();
}

// Announced ONCE by the denizen portal opening sound (zmb_screecher_portal_spawn,
// zm_transit_ai_screecher.gsc:80): louder than the quiet zmb_souls_end it replaces and in the family of what
// the latch will open. owner 2026-09-25: the orange light glow/blink (fx_zmb_tranzit_light_glow_xsm) removed,
// the sound is the whole cue now.
df_m1_table_pulse()
{
    pos = df_coord( "DF_SOCKET" ).origin + ( 0, 0, 60 );
    playsoundatposition( "zmb_screecher_portal_spawn", pos );
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
//   "!df fire m1_ride"  the first-ride cue (table sound + M1_EVENT, no table fx) even without a denizen;
//   "!df fire m1_skull" drops the hand in front of the first player; fired again (the hand on the floor or
//                       already carried) it goes onto table slot 1, which completes M1 once the cold room is done.
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
            level.df_m1_target = df_scaled_step( "cold_room_kills", "m1" );

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

    level.df_m1_portal_light = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", pos + df_fx_point( "portal_light" ) );
    level.df_m1_portal_orbit = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", pos + df_fx_point( "portal_orbit" ) );

    // linkto( ent, tag, origin offset, angles offset ) as _zm_buildables.gsc:641: the light orbits the hole
    if ( isdefined( level.df_m1_portal_orbit ) )
        level.df_m1_portal_orbit linkto( level.df_m1_hole, "tag_origin", df_fx_point( "portal_orbit" ), ( 0, 0, 0 ) );

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

// Cold room centre = the middle of the four DF_NACHT_SPAWN anchors (the woods behind the hunter's cabin since owner 2026-09-25).
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

    seconds = df_scaled_step( "cold_room_time", "m1" );
    level.df_m1_target = df_scaled_step( "cold_room_kills", "m1" );
    level.df_m1_kills = 0;
    level.df_m1_phase = 1;
    level.df_m1_mode = "room";
    level.df_m1_last_kill_pos = undefined;

    df_m1_room_fx_start();
    df_m1_teleport_players_in();
    // owner 2026-09-25: the woods are an open denizen zone: df_m1_zone_start pauses vanilla's denizens there (only ours rise)
    // until the players are sent back or all walk out of the zone
    // (started once the players stand there, so the walk-out watch never fires during the teleport)
    df_m1_zone_start();
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

    // the denizen cap stays with the zone (df_m1_zone_end: the return teleport, walking out, or a skip)
}

// owner 2026-09-25: while the players are in the woods behind the cabin (an open fog zone of vanilla's), vanilla's denizen
// director is paused (zombie_ai_limit_screecher 0, _zm_ai_screecher.gsc:82; the solo near-miss escape spent,
// :253-262) and the vanilla denizens already there die quietly: only ours rise. The zone ends on the return
// teleport, on a skip, or the moment no player in the match stands within level.df_m1_zone_radius.
df_m1_zone_start()
{
    if ( is_true( level.df_m1_zone_on ) )
        return;

    level.df_m1_zone_on = 1;
    level.df_m1_zone_radius = 1000; // owner 2026-09-25: the farthest boundary reading is 935 from DF_M1_ZONE
    level.df_m1_saved_limit = level.zombie_ai_limit_screecher;
    level.zombie_ai_limit_screecher = 0;
    level.df_m1_saved_near_miss = level.near_miss;
    level.near_miss = 2;

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( isdefined( ai ) && isalive( ai ) && is_true( ai.isscreecher ) && df_m1_in_zone( ai.origin ) )
            ai dodamage( ai.health + 666, ai.origin );
    }

    level thread df_m1_zone_watch();
    df_debug_print( "DF: m1 no-denizen zone ON (" + level.df_m1_zone_radius + " around DF_M1_ZONE, the woods behind the cabin)" );
}

df_m1_zone_end()
{
    if ( !is_true( level.df_m1_zone_on ) )
        return;

    level.df_m1_zone_on = 0;
    level notify( "df_m1_zone_end" );

    if ( isdefined( level.df_m1_saved_limit ) )
        level.zombie_ai_limit_screecher = level.df_m1_saved_limit;

    if ( isdefined( level.df_m1_saved_near_miss ) )
        level.near_miss = level.df_m1_saved_near_miss;

    level.df_m1_saved_limit = undefined;
    level.df_m1_saved_near_miss = undefined;
    df_debug_print( "DF: m1 no-denizen zone OFF, vanilla denizens are back" );
}

// Inside the no-denizen zone: level.df_m1_zone_radius (2D) around DF_M1_ZONE.
df_m1_in_zone( pos )
{
    return distance2dsquared( pos, df_coord( "DF_M1_ZONE" ).origin ) < level.df_m1_zone_radius * level.df_m1_zone_radius;
}

// Walking out ends the zone as if the players were sent back.
df_m1_zone_watch()
{
    level endon( "end_game" );
    level endon( "df_m1_zone_end" );

    while ( true )
    {
        wait 0.5;
        inside = 0;

        foreach ( player in getplayers() )
        {
            if ( df_m1_in_match( player ) && df_m1_in_zone( player.origin ) )
                inside = 1;
        }

        if ( !inside )
        {
            df_debug_print( "DF: m1 every player left the woods on foot" );
            df_m1_zone_end();
            return;
        }
    }
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
    df_debug_print( "DF: m1 " + i + " player(s) sent to the woods behind the cabin" );
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
    df_m1_zone_end();
    df_debug_print( "DF: m1 " + i + " player(s) returned to the tower" );
}

// Arrival burst at the return point: the denizen death ash (screecher_death, _zm_ai_screecher.gsc:28, played
// once with playfx at :1134) and an orange light for 2 s. "!df fire m1_burst" replays it.
df_m1_return_burst( origin )
{
    level endon( "end_game" );

    df_fx_once( "screecher_death", origin + df_fx_point( "portal_burst_ash" ) );
    light = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", origin + df_fx_point( "portal_burst_light" ) );
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

        // owner 2026-09-25: too easy: three per player in the woods zone (at least four), one every 0.4 s
        n = 0;

        foreach ( player in getplayers() )
        {
            if ( is_player_valid( player ) && is_true( level.df_m1_zone_on ) && df_m1_in_zone( player.origin ) )
                n++;
        }

        cap = n * 3;

        if ( cap < 4 )
            cap = 4;

        if ( df_m1_denizens_alive().size >= cap )
            continue;

        df_m1_spawn_denizen();
        next = gettime() + 400;
    }
}

// A Nacht anchor for the next denizen, as a fresh struct (screecher_prespawn reads .origin/.angles).
df_m1_pick_spawn()
{
    // owner 2026-09-25: THREE rising spots (DF_NACHT_SPAWN_1..3), the one farthest from every player in the room;
    // the same spot twice in a row gives way to the next farthest
    players = df_m1_room_players();
    first = undefined;
    first_d2 = -1;
    second = undefined;
    second_d2 = -1;

    for ( i = 1; i <= 3; i++ )
    {
        c = df_coord( "DF_NACHT_SPAWN_" + i );
        d2 = 999999999;

        foreach ( player in players )
        {
            pd2 = distancesquared( player.origin, c.origin );

            if ( pd2 < d2 )
                d2 = pd2;
        }

        if ( d2 > first_d2 )
        {
            second = first;
            second_d2 = first_d2;
            first = i;
            first_d2 = d2;
        }
        else if ( d2 > second_d2 )
        {
            second = i;
            second_d2 = d2;
        }
    }

    pick = first;

    if ( isdefined( level.df_m1_last_spawn ) && level.df_m1_last_spawn == first && isdefined( second ) )
        pick = second;

    level.df_m1_last_spawn = pick;
    c = df_coord( "DF_NACHT_SPAWN_" + pick );
    spot = spawnstruct();
    spot.origin = c.origin;
    spot.angles = c.angles;
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

    // owner 2026-09-25: the red trail and the red embers only, no fire (flash 0 = no fire burst where it lands,
    // tick burst 0 = no lava burst at the corpse)
    level thread df_act2_maxis_trail( pos + ( 0, 0, 30 ), to, 0 );
    df_snd_near( "evt_player_swiped", pos, 700 );
    // the red embers rising off each kill, the "soul sucking" look the owner wants back: 5 s (the 0.8 s cut of
    // 2026-09-23 made them vanish; df_fx_once would never end, the fx loops)
    df_fx_burst( "fx_zmb_ash_rising_md", pos, 5 );
    df_cue_tick( pos, 0 );
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
df_act2_maxis_trail( from, to, flash )
{
    if ( !isdefined( flash ) )
        flash = 1;

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
    // owner 2026-09-23: flash 0 = a grave kill (df_m2_soul): no fire flash and no sound here, the caller plays them
    if ( flash )
    {
        df_cue_side_flash( to );
        df_snd_near( "evt_player_swiped", to, 600 ); // owner pick 2026-09-11: a soul reaches a brazier
    }

    df_fx_stop( ent );
}

// ---- hand (audit 9, ITEM_HAND_MAXIS, renamed from ITEM_SKULL_MAXIS owner 2026-09-25; owner 2026-09-09: carried by hand) ----
// The last kill leaves the hand on the bunker floor (still the zombie_skull model, df_model "skull"). One press
// within 100 TAKES it (carry notice via df_scav_carry_set "skull", no fire; lamp portals must refuse
// player.df_skull like the ember: df_portal_use, requests_M2fix.md). The return brings the carrier home; one
// press within 150 of table slot 1 PLACES it (df_coords df_table_slot, the slot the key card fills on the
// other side; the hand itself sits at its own table pose, no glow), and M1 completes on that. Nobody took it
// before the return: it lies at the tower return point under its glint, still pickable, never auto-placed.
// A carrier who goes down drops it at the feet (like the ember).

// Success: the hand drops at the last corpse and Maxis names it (ITEM_HAND_MAXIS, the TAKE line since the
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
    df_say( "ITEM_HAND_MAXIS" );
    df_m1_skull_wait_take( 30 );
}

// Blocks until somebody carries the hand or `seconds` pass.
df_m1_skull_wait_take( seconds )
{
    level endon( "end_game" );

    deadline = gettime() + seconds * 1000;

    while ( gettime() < deadline && !isdefined( level.df_m1_skull_carrier ) )
        wait 0.1;

    if ( !isdefined( level.df_m1_skull_carrier ) )
        df_debug_print( "DF: m1 lantern not taken in " + seconds + " s, it comes along to the tower" );
}

// A hand still lying on the floor after the return moves to the tower return point (48 units left of where
// the first player lands) so it is never left in the bunker; a carried hand travels with its carrier.
df_m1_skull_follow_return()
{
    if ( !isdefined( level.df_m1_skull ) || isdefined( level.df_m1_skull_carrier ) )
        return;

    c = df_coord( "DF_TOWER_RETURN" );
    df_m1_skull_drop( df_ground( c.origin + anglestoright( c.angles ) * -48 ) );
    df_debug_print( "DF: m1 lantern lies at the tower return point, take it to the table" );
}

// The hand lies on the floor under a glint (fx_zmb_tranzit_light_glow at df_fx_point "skull_glow")
// and the poll (prompts / presses) runs from here until the placement.
df_m1_skull_drop( ground )
{
    df_m1_skull_remove_floor();
    // owner 2026-09-25: the lantern stands upright ON the ground (its registry pose: pitch 180 puts the ceiling mount
    // under it), turns slowly and carries its glow
    level.df_m1_skull = spawn( "script_model", ground + ( 0, 0, 1 ) );
    level.df_m1_skull setmodel( df_model( "skull" ) );
    level.df_m1_skull.angles = df_model_angles( "skull", randomint( 360 ) );
    level.df_m1_skull thread df_m1_floor_hand_spin();
    // owner 2026-09-25: the tiny xsm glow was invisible in the fog: the full light glow on the hand plus the key glint
    level.df_m1_skull_fx = df_fx_loop( "fx_zmb_tranzit_light_glow", level.df_m1_skull.origin );
    level.df_m1_skull_glint = df_fx_loop( "fx_zmb_lava_crevice_glow_50", level.df_m1_skull.origin );

    // owner 2026-09-25: the light rides ON the hand (linked to the model): a white glow and the orange lava glow
    if ( isdefined( level.df_m1_skull_fx ) )
        level.df_m1_skull_fx linkto( level.df_m1_skull );

    if ( isdefined( level.df_m1_skull_glint ) )
        level.df_m1_skull_glint linkto( level.df_m1_skull );
    playsoundatposition( "zmb_buildable_piece_add", ground );
    level thread df_m1_skull_poll();
    df_debug_print( "DF: m1 lantern on the floor at " + int( ground[0] ) + " " + int( ground[1] ) + " " + int( ground[2] ) + ", one press takes it" );
}

// self = the floor hand: a slow turn, like the rock on the ground.
df_m1_floor_hand_spin()
{
    self endon( "death" );
    self endon( "df_spin_stop" ); // linked to the bus (df_m1_skull_monitor)

    while ( true )
    {
        self rotateyaw( 360, 8 );
        self waittill( "rotatedone" );
    }
}

// Prompts and presses every 0.05 s (df_press_use is edge-triggered): a standing player within 100 of the floor
// hand takes it (not while carrying the relay, an orb or the ember); the carrier within 150 of slot 1 places
// it. While the hand lies on the BUNKER floor, every other player in the room sees the puzzle prompt "take
// the hand before the cold closes" (df_prompt_puzzle, hidden with `!df hints off`; steps audit v2 #9) until
// it is taken or leaves
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

                df_m1_skull_prompt_set( player, "Press [{+activate}] to place the lantern" );

                if ( player df_press_use() )
                    df_m1_skull_place_by( player );

                continue;
            }

            busy = is_true( player.df_carrying_relay ) || isdefined( player.df_orb );

            if ( busy || !isdefined( level.df_m1_skull ) || distancesquared( player.origin, level.df_m1_skull.origin ) > 100 * 100 )
            {
                df_m1_skull_prompt_clear( player );
                df_m1_skull_room_prompt( player, df_m1_skull_in_room_with( player ) );
                continue;
            }

            df_m1_skull_room_prompt( player, 0 );
            df_m1_skull_prompt_set( player, "Press [{+activate}] to take the lantern" );

            if ( player df_press_use() )
                df_m1_skull_take( player );
        }
    }
}

// True while the floor hand and this player are both inside the bunker (the take window and just after).
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
        player df_prompt_puzzle( 1, "Take the lantern before the cold closes" );
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

// It goes into the player's hand: flag (lamp portals refuse it), carry notice, pickup sound, drop watch.
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
    df_debug_print( "DF: m1 lantern taken by " + player.name + ", carry it to the table (slot 1, one press within 150)" );
}

// It leaves the player's hand (placed, dropped, skip): flag off, notice cleared.
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

// Every carried hand released (no poll restart: callers decide); both prompt slots cleared.
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

// Skip: floor hand, carried hand and the poll all go.
df_m1_skull_clear_world()
{
    level notify( "df_m1_skull_poll_stop" );
    df_m1_skull_remove_floor();
    df_m1_skull_clear_hands();
}

// The carrier goes down (player_is_in_laststand, _zm_laststand.gsc:56): the hand drops at the feet with its
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
            df_debug_print( "DF: m1 lantern carrier left, the lantern lies at the tower return point" );
            return;
        }

        if ( !is_true( player.df_skull ) )
            return;

        if ( player maps\mp\zombies\_zm_laststand::player_is_in_laststand() || !is_player_valid( player ) )
        {
            ground = df_ground( player.origin );
            on_bus = df_player_on_bus( player );
            df_m1_skull_release( player );
            df_m1_skull_drop( ground );

            // owner 2026-09-25: dropped on the bus it rides along (no spin while linked; its glows ride the model)
            if ( on_bus && isdefined( level.df_m1_skull ) )
            {
                level.df_m1_skull notify( "df_spin_stop" );
                level.df_m1_skull linkto( level.the_bus );
            }

            level thread df_m1_skull_home_timer( level.df_m1_skull );
            df_cue_fail( ground );
            df_debug_print( "DF: m1 lantern dropped (" + player.name + " went down), take it again" );
            return;
        }
    }
}

// owner 2026-09-25: a dropped lantern nobody takes in 60 s comes along to the tower (df_m1_skull_follow_return).
df_m1_skull_home_timer( skull )
{
    level endon( "end_game" );
    level endon( "df_skip_m1" );
    level endon( "df_m1_skull_placed" );

    if ( !df_drop_wait_home( skull ) || !isdefined( level.df_m1_skull ) || level.df_m1_skull != skull )
        return;

    level thread df_soul_fly( skull.origin, df_coord( "DF_TOWER_RETURN" ).origin );
    df_m1_skull_follow_return();
}

// The carrier places it: hand emptied, the hand on slot 1 with the full cue.
df_m1_skull_place_by( player )
{
    df_m1_skull_release( player );
    df_debug_print( "DF: m1 lantern placed by " + player.name );
    df_m1_skull_place_table( 0 );
}

df_m1_skull_remove_floor()
{
    if ( isdefined( level.df_m1_skull ) )
        level.df_m1_skull delete();

    df_fx_stop( level.df_m1_skull_fx );
    df_fx_stop( level.df_m1_skull_glint );
    level.df_m1_skull_glint = undefined;
    level.df_m1_skull = undefined;
    level.df_m1_skull_fx = undefined;
}

// The hand on the table at its own pose (df_coords df_model_def "skull" offset, table frame), slow spin like the hole,
// no glow (the placing snap only). quiet = 1 (goto): no snap, no trail. The line (M1_DONE) is
// df_m1_finish's; ITEM_HAND_MAXIS moved to the drop. Any floor or carried hand is gone first (debug / goto
// paths). The "df_m1_skull_placed" notify is LAST on purpose: it ends the poll (which may be the calling
// thread) and wakes df_m1_wait_placed.
df_m1_skull_place_table( quiet )
{
    if ( isdefined( level.df_m1_skull_table ) )
        return;

    df_m1_skull_remove_floor();
    df_m1_skull_clear_hands();
    // owner 2026-09-23: the hand (zombie_skull, pivot 14 over its base) has its own pose in the table frame, set in the
    // Prop Composer (df_coords df_model_def "skull" offset); slot 1 stays the card's
    pos = df_table_point( df_model_offset( "ember" ) ); // owner 2026-09-25: exactly where the fire hand will lie
    level.df_m1_skull_table = spawn( "script_model", pos );
    level.df_m1_skull_table setmodel( df_model( "skull" ) );
    level.df_m1_skull_table.angles = df_model_angles( "ember", df_table_yaw() );
    // owner 2026-09-23: no glow on the hand (one glow per step on the relay); the placing snap only
    if ( !is_true( quiet ) )
        df_cue_table_place( pos );
    df_debug_print( "DF: m1 lantern on the table, slot 1 (" + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) + ")" );

    if ( !is_true( quiet ) )
        level thread df_act2_maxis_trail( pos + ( 0, 0, 200 ), pos );

    level notify( "df_m1_skull_placed" );
}

// "!df fire m1_skull": the hand, on the floor or already carried, -> placed on the table (completes M1 once the cold
// room is done); none -> one drops 60 in front of the player.
df_m1_debug_skull( player )
{
    if ( isdefined( level.df_m1_skull_table ) )
    {
        df_debug_print( "DF: m1 lantern already on the table" );
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

// Boot: the four braziers stand in Town from game start with their ember glow (owner rule 2026-09-08);
// df_boot has already run df_coords_init when the acts register.
df_m2_boot()
{
    level endon( "end_game" );

    wait 0.1;
    df_m2_place_braziers();
    level thread df_m2_debug_restage_hook();
    df_m1_hooks_install(); // owner 2026-09-25: both sides, for the lamp-step safe circle (df_lamp_step_safe); vanilla otherwise
}

// Arms the braziers: brazier 1 is lit (the AVAILABLE focus sits on its rim), the ember and the kills
// count from here. All four full: the Step 6 node (the cabin hearth) exports, the tower answers in orange 12 s with the fire side's
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
    // owner 2026-09-25: the graves stand outside the map: they are SHOT to light (df_m2_grave_shot_watch); the hand stays on the
    // table and takes the four fires at the end (df_m2_ember_charged), nobody carries it
    level thread df_m2_power_penalty();
    level thread df_m2_grave_spawner(); // owner 2026-09-11: gentle waves near a lit grave
    level thread df_m2_grave_clock(); // owner 2026-09-23: the cold timer ticks (one shared clock)
    level.df_m2_ember_returned = 0;
    level.df_m2_ember_charged = 0;
    df_m2_ember_spawn_table();
    // owner 2026-09-25: no AVAILABLE glint over the table (nothing of ours on the table)
    df_debug_print( "DF: m2 the lantern waits on the table; shoot a grave outside Town to light it, kill " + level.df_m2_target + " zombies within " + df_m2_zone_radius() + " of where you shot from; four graves = the burning lantern" );

    while ( !df_m2_all_done() || !is_true( level.df_m2_ember_returned ) )
        level waittill( "df_m2_check" );

    level.df_m2_armed = 0;
    df_death_listen_remove( "m2" );
    df_m2_export_nodes();
    df_tower_fx_start( "maxis" );
    level thread df_tower_fx_stop_after( 12 );
    level thread df_m2_column( 20 );
    df_say( "M2_DONE" );

    // owner 2026-09-23: Step 6 on this side is a Jet Gun draw at the cabin fireplace, as on Richtofen's side (R2 says
    // its warning there): with no Jet Gun in any inventory the team hears now that one is needed, not at the pickup.
    // owner 2026-09-23: its own line here (A2_JETGUN_MAXIS); S6_NOJETGUN_MAXIS stays for the Step 6 pickup only
    if ( !df_s6_any_jetgun() )
        df_say( "A2_JETGUN_MAXIS" );

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

// Kills per lit brazier (owner 2026-09-09; burning or not since 2026-09-23): five, fixed for solo; a bigger brazier_burns row wins.
df_m2_quota()
{
    q = df_scaled_step( "brazier_burns", "m2" );

    if ( !isdefined( q ) || q < 5 )
        q = 5;

    return q;
}

// "!df goto" past m2: all four braziers lit to the last stage (quietly: no sting, no line per brazier); the
// Step 6 node (the cabin hearth) exported.
df_m2_setup()
{
    df_m2_place_braziers();

    if ( !isdefined( level.df_m2_target ) )
        level.df_m2_target = df_m2_quota();

    foreach ( b in level.df_m2_braziers )
        df_m2_fill( b, 1 );

    level.df_m2_ember_returned = 1;
    level.df_m2_ember_charged = 1;
    df_m2_ember_spawn_table( 1 ); // goto past m2: the charged fire hand rests on the table
    df_m2_export_nodes();
    level thread df_m2_debug_restage_hook();
}

// "!df goto" past m2: the graves stay (they are the world's), the lantern and the listeners go.
df_m2_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level waittill( "df_skip_m2" );
    level.df_m2_armed = 0;
    df_death_listen_remove( "m2" );
    df_m2_ember_table_remove();
}

// "!df fire m2_fill" or "!df souls": every grave completes and the burning lantern rests on the table.
// "!df fire m2_light": the next unlit grave lights as if it was shot.
// "!df fire m2_penalty": the power-on stage drop, now. "!df fire m2_column": the 20 s tower smoke column.
df_m2_debug_hook()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level endon( "df_skip_m2" );

    while ( true )
    {
        what = level waittill_any_return( "df_debug_m2_fill", "df_debug_souls_done", "df_debug_m2_light", "df_debug_m2_penalty", "df_debug_m2_column" );

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

        if ( what == "df_debug_m2_penalty" )
        {
            df_m2_power_drop();
            continue;
        }

        // the fourth fill charges the lantern (df_m2_ember_charged)
        foreach ( b in level.df_m2_braziers )
            df_m2_fill( b );
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
// owner's spots in Town, 2026-09-23), model df_model( "brazier" )
// (df_coords registry), dark ember glow to start, unlit. Names brazier_1..4.
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
        b.angles = c.angles; // the grave's own yaw: df_m2_ash_pos turns the horizontal ash offset with it
        b.count = 0;
        b.stage = -1;
        b.lit = 0;
        b.done = 0;
        b.fx = [];
        b.rim = df_m2_rim_height( model );
        b.model = spawn( "script_model", b.origin );
        b.model setmodel( model );
        b.model.angles = c.angles;
        df_m2_set_stage( b, 0 );
        // owner 2026-09-25: a damage trigger on the grave (outside the map): a bullet on it lights it
        b.hit = spawn( "trigger_damage", b.origin, 0, 40, 90 );
        b.model setcandamage( 1 ); // owner 2026-09-25: the model takes the bullet too (a second path if the trigger misses)
        level thread df_m2_grave_shot_watch( b, b.hit );
        level thread df_m2_grave_shot_watch( b, b.model );
        df_m2_grave_shield_spawn( b );
        level.df_m2_braziers[i] = b;
        df_debug_print( "DF: m2 " + b.name + " at " + int( c.origin[0] ) + " " + int( c.origin[1] ) + " " + int( c.origin[2] ) + " (" + model + ")" );
    }

    level thread df_m2_side_watch();
    level thread df_m2_grave_move_hook();
}

// owner 2026-09-25: a DF_BRAZIER_n anchor moved in game (!df setpos / !df grab / !df move) carries its grave along:
// model, the damage trigger, the bullet walls and the flame / crackle at the new rim. df_coords df_coord_tune_done notifies.
df_m2_grave_move_hook()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_m2_grave_moved", key );

        foreach ( b in level.df_m2_braziers )
        {
            if ( !isdefined( b ) || "DF_BRAZIER_" + ( b.idx + 1 ) != key )
                continue;

            c = df_coord( key );
            b.origin = df_ground( c.origin + ( 0, 0, 20 ) );
            b.angles = c.angles;
            b.df_spots = undefined;

            if ( isdefined( b.model ) )
            {
                b.model.origin = b.origin;
                b.model.angles = c.angles;
            }

            // owner 2026-09-25: the damage trigger follows too (a moved grave kept its trigger at the old spot: shots did nothing)
            if ( isdefined( b.hit ) )
                b.hit.origin = b.origin;

            df_m2_grave_shield_place( b );
            df_m2_crackle_stop( b );
            stage = b.stage;
            b.stage = -1;
            df_m2_set_stage( b, stage );
            df_debug_print( "DF: m2 " + b.name + " moved to " + int( b.origin[0] ) + " " + int( b.origin[1] ) + " " + int( b.origin[2] ) );
        }
    }
}

// owner 2026-09-25: the kill zone of a lit grave: a circle of df_m2_zone_radius (dvar df_m2_zone_radius, default 400) on the
// ground where the player stood when the shot lit it, marked by a lava glow and a small flame.
df_m2_zone_radius()
{
    r = getdvarint( "df_m2_zone_radius" );

    if ( r <= 0 )
        r = 400;

    return r;
}

// owner 2026-09-25: "add collision to the tombstone for bullet". The grave model stops no
// bullet, so a shot could fly through the stone and never reach its trigger. Two crossed bullet walls (the
// map's own collision_wall_64x64x10_standard, precached by zm_transit_ffotd.gsc) stand inside the stone,
// ghosted like vanilla's, and take damage: a bullet stops on them and lights the grave.
df_m2_grave_shield_spawn( b )
{
    b.shield = [];

    for ( i = 0; i < 2; i++ )
    {
        w = spawn( "script_model", b.origin );
        w setmodel( "collision_wall_64x64x10_standard" );
        w ghost();
        w setcandamage( 1 );
        b.shield[i] = w;
        level thread df_m2_grave_shot_watch( b, w );
    }

    df_m2_grave_shield_place( b );
}

df_m2_grave_shield_place( b )
{
    if ( !isdefined( b.shield ) )
        return;

    for ( i = 0; i < b.shield.size; i++ )
    {
        b.shield[i].origin = b.origin + ( 0, 0, 36 );
        b.shield[i].angles = ( 0, b.angles[1] + 90 * i, 0 );
    }
}

df_m2_grave_shield_remove( b )
{
    if ( !isdefined( b.shield ) )
        return;

    foreach ( w in b.shield )
    {
        if ( isdefined( w ) )
            w delete();
    }

    b.shield = undefined;
}

// owner 2026-09-25: every grave has its own watchers, so the four can be lit at once (solo or co-op), each with its own 90 s timer.
// src = the damage trigger or the model; the watcher ends when its entity goes (the grave explodes).
df_m2_grave_shot_watch( b, src )
{
    level endon( "end_game" );

    while ( isdefined( src ) )
    {
        src waittill( "damage", amount, attacker );

        // owner 2026-09-25: the console names every hit on a grave, so a grave that "does nothing" can be read
        if ( is_true( level.df_m2_armed ) && !b.done )
            df_debug_print( "DF: m2 " + b.name + " hit (lit " + b.lit + ")" );

        if ( !is_true( level.df_m2_armed ) || b.lit || b.done || !isdefined( attacker ) || !isplayer( attacker ) )
            continue;

        b.zone = df_m2_zone_ground( attacker );
        b.df_spots = undefined;
        df_m2_zone_fx( b, 1 );
        level thread df_act2_maxis_trail( df_m2_rim_pos( b ), b.zone, 0 );
        df_m2_light( b, attacker );
        df_debug_print( "DF: m2 " + b.name + " shot by " + attacker.name + ", kill zone at " + int( b.zone[0] ) + " " + int( b.zone[1] ) + " (" + df_m2_zone_radius() + ")" );
    }
}

// owner 2026-09-25: the kill zone always lies on the road, never on the bus: a shooter on the bus (roof or
// inside) gets the ground under the bus (the trace ignores the bus, then anything else linked to it), so the
// flame and the radius stay where he fired and never ride away with the bus.
df_m2_zone_ground( player )
{
    if ( !df_player_on_bus( player ) )
        return df_ground( player.origin );

    from = player.origin + ( 0, 0, 10 );

    for ( i = 0; i < 4; i++ )
    {
        trace = bullettrace( from, from - ( 0, 0, 600 ), 0, level.the_bus );

        if ( !isdefined( trace["position"] ) || trace["fraction"] >= 1 )
            break;

        ent = trace["entity"];

        if ( !isdefined( ent ) || ( isdefined( ent.classname ) && ent.classname == "worldspawn" ) )
            return trace["position"];

        from = trace["position"] - ( 0, 0, 4 );
    }

    return df_ground( player.origin );
}

df_m2_zone_fx( b, on )
{
    if ( isdefined( b.zone_fx ) )
    {
        foreach ( fx in b.zone_fx )
            df_fx_stop( fx );
    }

    b.zone_fx = [];

    if ( !on || !isdefined( b.zone ) )
        return;

    g = df_fx_loop( "fx_zmb_lava_crevice_glow_50", b.zone + ( 0, 0, 2 ) );

    if ( isdefined( g ) )
        b.zone_fx[b.zone_fx.size] = g;

    f = df_fx_loop( "character_fire_death_sm", b.zone + ( 0, 0, 2 ) ); // the small flame marks the zone (the big fire is the grave's)

    if ( isdefined( f ) )
    {
        b.zone_fx[b.zone_fx.size] = f;
        level thread df_m2_flame_keep( f, "character_fire_death_sm" );
    }
}

// The lit, unfinished grave whose kill zone holds pos, else undefined.
df_m2_zone_of( pos )
{
    if ( !isdefined( level.df_m2_braziers ) )
        return undefined;

    r = df_m2_zone_radius();

    foreach ( b in level.df_m2_braziers )
    {
        if ( isdefined( b ) && b.lit && !b.done && isdefined( b.zone ) && distance2dsquared( pos, b.zone ) < r * r )
            return b;
    }

    return undefined;
}

df_m2_side_watch()
{
    level endon( "end_game" );
    side = level.df_side; // owner 2026-09-25: a side locked before this ran was missed (as df_rich_side_watch)

    if ( !isdefined( side ) )
        level waittill( "df_side_locked", side );

    if ( side == "maxis" )
        df_m2_graves_wake();
    else
        df_m2_retire_braziers();
}

// Maxis locked: every standing, unfinished grave shows its small flame (the stage is re-applied).
df_m2_graves_wake()
{
    if ( !isdefined( level.df_m2_braziers ) )
        return;

    foreach ( b in level.df_m2_braziers )
    {
        stage = b.stage;
        b.stage = -1;
        df_m2_set_stage( b, stage );
    }

    df_debug_print( "DF: Maxis side locked, the four graves show their flame" );
}

// Richtofen locked: the graves stay as scenery (owner 2026-09-25): fx and sound go, models stay.
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
    }

    df_debug_print( "DF: Richtofen side locked, the four graves stay dark" );
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

// The two brazier attach points. The BASE is the measured rim of this brazier's model (b.rim =
// df_m2_rim_height, which follows a live `!df model brazier <name>` swap); the extra above it lives in the
// df_coords attach-point registry as "brazier_rim_fire" (the fire, the crackle, the whoosh, the puff, the
// spent burst) and "brazier_ash" (the rising ash, which has a horizontal part and is therefore turned with
// the grave's own yaw). The Prop Composer draws both crosses against the brazier with "rim" as their base,
// and since [v6] it uses the same rim df_m2_rim_height gives (2 for a tombstone), not the model top.
df_m2_rim_pos( b )
{
    return b.origin + ( 0, 0, b.rim ) + df_fx_point( "brazier_rim_fire" );
}

df_m2_ash_pos( b )
{
    yaw = 0;

    if ( isdefined( b.angles ) )
        yaw = b.angles[1];

    return b.origin + ( 0, 0, b.rim ) + df_fx_point_at( "brazier_ash", yaw );
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
    top = df_m2_rim_pos( b );

    // owner 2026-09-23: EVERY standing tombstone carries the one small flame, lit or not (it showed on the lit one
    // only); a lit one also crackles; a spent one is gone (df_m2_fill deletes the model and leaves the scorched glow)
    if ( is_true( b.done ) )
    {
        df_m2_crackle_stop( b );
        return;
    }

    // owner 2026-09-25: the graves stand from boot on both sides; the small flame belongs to the Maxis side only
    if ( !isdefined( level.df_side ) || level.df_side != "maxis" )
    {
        df_m2_crackle_stop( b );
        return;
    }

    // owner 2026-09-25: an unlit grave shows nothing; only a grave that was shot (lit) burns
    if ( stage <= 0 || !b.lit )
    {
        df_m2_crackle_stop( b );
        return;
    }

    df_m2_crackle_start( b );

    // owner 2026-09-25: the graves stand outside the map now: a LARGE fire when lit, seen from Town
    // (`set df_m2_fire_fx <fx key>` swaps it at the next lighting)
    f = df_fx_loop( df_m2_small_fire_fx(), top ); // a looping fire: no replay needed (df_m2_flame_keep would stack it)

    if ( isdefined( f ) )
        b.fx[b.fx.size] = f;

    g = df_fx_loop( "fx_zmb_tranzit_fire_med", top );

    if ( isdefined( g ) )
        b.fx[b.fx.size] = g;
}

// Low fire crackle on a lit brazier: zmb_fire_loop, the loop vanilla puts on a burning zombie
// (zm_transit_lava.gsc:224), on its own tag_origin at the rim so it survives stage changes.
df_m2_crackle_start( b )
{
    if ( isdefined( b.snd ) )
        return;

    b.snd = spawn( "script_model", df_m2_rim_pos( b ) );
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

// Lights brazier b (stage 1, whoosh zmb_firetrap_start _zm_traps.gsc:414 + ignite zm_transit_lava.gsc:275);
// player (optional) is the shooter.
df_m2_light( b, player )
{
    if ( b.lit )
        return;

    b.lit = 1;
    b.lit_ms = gettime();
    df_m2_set_stage( b, 1 );
    level thread df_m2_grave_timer( b );

    // the first lit grave teaches the rule (audit v3 #4: M2_HINT_2 had no caller since the ember no longer burns out)
    // owner 2026-09-25: from the first lit grave on the ladder speaks the lit rungs (M2_LIT_HINT_n); the phase is
    // set first so the event rung is M2_LIT_HINT_2
    if ( df_m2_lit_count() == 1 )
        df_step_phase( "m2", "LIT" );

    if ( df_m2_lit_count() == 1 )
        level thread df_hint_now( "m2", 2 ); // owner 2026-09-25: threaded, never holds up the shot watcher
    // fire whoosh, 1.4 s, 750 range: the closest thing to an ignition in the banks (zmb_firetrap_start and
    // "ignite" are Buried / lava-script aliases that no TranZit bank carries: both were silent)
    playsoundatposition( "zmb_phdflop_explo", df_m2_rim_pos( b ) );
    who = "m2";
    left = 4 - df_m2_lit_count();

    if ( isdefined( player ) && isplayer( player ) )
    {
        df_touch( "m2" );
        who = player.name;
        player playsoundtoplayer( "zmb_buildable_piece_add", player );
    }

    df_debug_print( "DF: m2 " + b.name + " lit by " + who + " (" + df_m2_lit_count() + "/4 lit, " + left + " to go)" );
    level notify( "df_m2_check" );
}

// Owner 2026-09-23: a lit grave has df_m2_grave_time seconds (dvar, default 90) to be filled. Past that it goes
// cold: unlit, its count back to 0, the PROGRESS LOST cue at the rim and Maxis says so. It must be lit again with
// the fire hand and filled from zero. One timer per lighting (b.light_id); a grave filled in time stops it.
df_m2_grave_time()
{
    t = getdvarint( "df_m2_grave_time" );

    if ( t <= 0 )
        t = 90;

    return t;
}

df_m2_grave_timer( b )
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level endon( "df_skip_m2" );

    if ( !isdefined( b.light_id ) )
        b.light_id = 0;

    b.light_id++;
    id = b.light_id;
    limit = df_m2_grave_time() * 1000;

    while ( true )
    {
        wait 1;

        if ( b.done || !b.lit || b.light_id != id )
            return;

        if ( gettime() - b.lit_ms < limit )
            continue;

        b.lit = 0;
        b.count = 0;
        df_m2_zone_fx( b, 0 ); // owner 2026-09-25: shoot it again for a new zone
        b.zone = undefined;
        df_m2_set_stage( b, 0 );
        df_cue_fail( df_m2_rim_pos( b ) );
        df_say( "M2_GRAVE_COLD" );
        df_debug_print( "DF: m2 " + b.name + " went cold (not filled within " + df_m2_grave_time() + " s): light it again and fill it from 0" );
        level notify( "df_m2_check" );
        return;
    }
}

// Owner 2026-09-23: the cold timer was silent. ONE shared countdown clock (df_sys_clock_run: tick-tock, then the
// tombstone ticks in the last 30 s) runs for the lit unfinished grave that goes cold first; re-aimed every 0.5 s
// when that grave fills, cools or a sooner one exists, and stopped ("df_m2_clock_stop") when none is lit.
// One clock and not one per grave: the helper's tick-tock rides every player and would stack.
df_m2_grave_clock()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level endon( "df_skip_m2" );

    running = undefined;

    while ( true )
    {
        wait 0.5;
        soonest = undefined;
        limit = df_m2_grave_time() * 1000;

        foreach ( b in level.df_m2_braziers )
        {
            if ( b.done || !b.lit || !isdefined( b.lit_ms ) )
                continue;

            end_ms = b.lit_ms + limit;

            if ( !isdefined( soonest ) || end_ms < soonest )
                soonest = end_ms;
        }

        if ( isdefined( soonest ) && soonest <= gettime() )
            soonest = undefined;

        if ( !isdefined( soonest ) )
        {
            if ( isdefined( running ) )
                level notify( "df_m2_clock_stop" );

            running = undefined;
            continue;
        }

        if ( isdefined( running ) && running == soonest )
            continue;

        if ( isdefined( running ) )
            level notify( "df_m2_clock_stop" );

        running = soonest;
        level thread df_sys_clock_run( soonest, "df_m2_clock_stop", "df_m2_done", "df_skip_m2" );
    }
}

// ---- kills at a lit grave ------------------------------------------------------------------------

// Owner 2026-09-23 (the graves moved to Town): ANY zombie that dies within 250 of a LIT, unfinished grave counts,
// burning or not. The old rule wanted zombie.is_on_fire (zm_transit_lava.gsc:179/241), which only the lava beside
// the old row of graves ever set: in Town no kill would have counted. A kill beside an UNLIT grave (and no lit one
// in reach) is refused to the killer (deny buzz, 5 s throttle): light it first. A Galvaknuckle kill
// (zombie.damageweapon, set by the vanilla actor damage callback) never counts, and Maxis says so (M2_KNUCKLES_MAXIS, 20 s throttle) -
// player: before 2026-09-23 the burning rule kept those out by itself.
df_m2_on_zombie_death( zombie )
{
    if ( !isdefined( level.df_m2_braziers ) )
        return;

    best = df_m2_zone_of( zombie.origin ); // owner 2026-09-25: kills count inside a lit grave's zone (where it was shot from)
    knuckles = isdefined( zombie.damageweapon ) && zombie.damageweapon == "tazer_knuckles_zm";

    if ( !isdefined( best ) || knuckles )
    {
        // the buzz only for the knuckles inside a zone
        near = isdefined( best );

        if ( near && isdefined( zombie.attacker ) && isplayer( zombie.attacker ) )
        {
            if ( !isdefined( zombie.attacker.df_m2_deny_ms ) || gettime() - zombie.attacker.df_m2_deny_ms > 5000 )
            {
                zombie.attacker.df_m2_deny_ms = gettime();
                df_cue_deny( zombie.attacker );
            }

            if ( knuckles && ( !isdefined( level.df_m2_fists_time ) || gettime() - level.df_m2_fists_time > 20000 ) )
            {
                level.df_m2_fists_time = gettime();
                df_say( "M2_KNUCKLES_MAXIS" );
            }
        }

        return;
    }

    df_touch( "m2" );
    best.count++;
    level thread df_m2_soul( zombie.origin, best );
    df_m2_update( best );
    level notify( "df_m2_check" );
}

// One counted kill, the same every time (owner 2026-09-23: the soul, the burst and the sound each kill): the body
// bursts (0.5 s of lava fire + the swipe sound at the body), the soul flies to the grave (df_act2_maxis_trail,
// blocking), and lands with the PROGRESS TICK clink at the rim. Two different aliases, 0.4-1.5 s apart: the same
// alias twice per kill (swipe at the body and at the grave) was cut by the engine when kills came quickly.
df_m2_soul( from, b )
{
    level endon( "end_game" );

    // owner 2026-09-25: the kill counted: the red soul trail flies into the zone's flame (you see it land where you stand) and red
    // embers rise off the body, as in the M1 woods; no fire burst
    to = df_m2_ash_pos( b ); // owner 2026-09-25: from the corpse to the tombstone itself

    df_snd_near( "evt_player_swiped", from, 700 );
    df_fx_burst( "fx_zmb_ash_rising_md", from, 3 );
    df_act2_maxis_trail( from + ( 0, 0, 10 ), to, 0 );
    df_cue_tick( to, 0 );
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
    df_m2_zone_fx( b, 0 );

    // owner 2026-09-25: the grave's fire flies to the hand waiting on the table
    if ( !is_true( quiet ) && isdefined( level.df_m2_ember_pos ) )
        level thread df_act2_maxis_trail( df_m2_rim_pos( b ), level.df_m2_ember_pos, 0 );
    b.count = level.df_m2_target;
    top = df_m2_rim_pos( b );

    // owner 2026-09-25: the stone is spent: a small burst, the model stays, its flame goes, a scorched glow marks the spot (cosmetic: no Step 6 node).
    // stage -1 first so an unlit (stage 0) stone filled by a skip still loses its flame
    b.stage = -1;
    df_m2_set_stage( b, 0 );

    // owner 2026-09-25: the spent grave EXPLODES and is gone (it stands outside the map: nothing to keep)
    if ( !is_true( quiet ) )
    {
        playsoundatposition( "zmb_explo_sweet", top );
        df_fx_burst( "fx_zmb_tranzit_fire_lrg", top, 1.0 );
        df_fx_burst( "fx_zmb_ash_rising_md", top, 3 );
        earthquake( 0.2, 0.6, top, 900 );
    }

    if ( isdefined( b.hit ) )
        b.hit delete();

    b.hit = undefined;

    if ( isdefined( b.model ) )
        b.model delete();

    df_m2_grave_shield_remove( b );

    if ( is_true( quiet ) )
        return;

    df_cue_subgoal( top );
    df_say( "M2_MAXIS_BRAZIER" );
    df_debug_print( "DF: m2 " + b.name + " spent, it burst and is gone (" + df_m2_done_count() + "/4)" );

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
// the new stage. Owner 2026-09-23: softened, only the lit unfinished grave with the most kills forgets them.
df_m2_power_drop()
{
    if ( !isdefined( level.df_m2_braziers ) || !isdefined( level.df_m2_target ) )
        return;

    best = undefined;

    foreach ( b in level.df_m2_braziers )
    {
        // owner 2026-09-11 rework: a spent grave stays spent; a lit hungry grave forgets its dead.
        // owner 2026-09-23 (softer): only ONE forgets, the lit unfinished grave with the most kills
        if ( b.done || !b.lit || b.count <= 0 )
            continue;

        if ( !isdefined( best ) || b.count > best.count )
            best = b;
    }

    if ( !isdefined( best ) )
    {
        df_debug_print( "DF: m2 power on at end of round, nothing left to lose" );
        return;
    }

    lost = best.count;
    best.count = 0;
    df_cue_fail( df_m2_rim_pos( best ) );
    df_say( "M2_POWER_MAXIS" );
    df_debug_print( "DF: m2 power ON at end of round: " + best.name + " forgets its " + lost + " dead (Maxis wants the dark)" );
}

// Step 6 node on Maxis's side (owner 2026-09-23): ONE node, the fireplace of the hunter's cabin in the woods
// (DF_CABIN_HEARTH), drawn exactly like Richtofen's DF_CORE: fire the Jet Gun into it with the rock carried until the
// gun overheats (df_act3_vacuum df_s6_overheat_watch). Kind "hearth": aim / beam / hum / glow at the registry point
// cabin_hearth_node. The spent graves keep their scorched glow as M2's mark on the world; they are no Step 6 nodes.
// Also run by df_m2_setup, so "!df goto step6" on this side gets the same node.
df_m2_export_nodes()
{
    level.df_nodes = [];
    c = df_coord( "DF_CABIN_HEARTH" );

    if ( !isdefined( c ) )
    {
        df_debug_print( "DF: m2 done: no DF_CABIN_HEARTH anchor, Step 6 builds its own node" );
        return;
    }

    node = spawnstruct();
    node.origin = c.origin;
    node.name = "cabin hearth";
    node.kind = "hearth";
    level.df_nodes[level.df_nodes.size] = node;
    df_debug_print( "DF: m2 done: Step 6 node = the cabin hearth at " + int( c.origin[0] ) + " " + int( c.origin[1] ) + " " + int( c.origin[2] ) + " (one draw: fire until the Jet Gun overheats)" );
}

// ---- the fire hand on the table (owner 2026-09-11 rework; the FIRE HAND since 2026-09-23) ----------------
// The hand (df_model "ember", the power switch hand piece) waits on the table at its own pose (df_coords
// df_model_def "ember" offset, in the table frame: df_table_point) with the tiny flame the graves carry.
// resting = 1: it came back charged and stays there, no prompt, until Step 6 bursts it (df_s6_ember_burst).
df_m2_ember_spawn_table( resting )
{
    df_m2_ember_table_remove();

    // owner 2026-09-25 (the hand arc): the hand M1 left on the table is the one M2 hands out (same pose, the entity just changes owner)
    if ( isdefined( level.df_m1_skull_table ) )
    {
        level.df_m1_skull_table delete();
        level.df_m1_skull_table = undefined;
    }

    yaw = df_table_yaw();
    level.df_m2_ember_pos = df_table_point( df_model_offset( "ember" ) );
    level.df_m2_ember_table_fx = [];
    level.df_m2_hand_table = spawn( "script_model", level.df_m2_ember_pos );
    level.df_m2_hand_table setmodel( df_model( "ember" ) );
    level.df_m2_hand_table.angles = df_model_angles( "ember", yaw );

    // owner 2026-09-25 (the hand arc): a plain hand until the four graves are ash; the flame only on the charged hand
    if ( is_true( resting ) || is_true( level.df_m2_ember_charged ) )
    {
        f = df_fx_loop( df_m2_hand_fire_fx(), level.df_m2_ember_pos + df_fx_point_at( "hand_fire", yaw ) );

        if ( isdefined( f ) )
        {
            level.df_m2_ember_table_fx[level.df_m2_ember_table_fx.size] = f;
            level thread df_m2_flame_keep( f, df_m2_hand_fire_fx() );
        }
    }

    df_debug_print( "DF: m2 the lantern is on the table (charged " + is_true( level.df_m2_ember_charged ) + ")" );
}

df_m2_ember_table_remove()
{
    if ( isdefined( level.df_m2_ember_table_fx ) )
    {
        foreach ( fx in level.df_m2_ember_table_fx )
            df_fx_stop( fx );
    }

    level.df_m2_ember_table_fx = [];

    if ( isdefined( level.df_m2_hand_table ) )
        level.df_m2_hand_table delete();

    level.df_m2_hand_table = undefined;
}

// The small flame burns out after a few seconds (a character death fire, not a looping one: owner 2026-09-23, the
// hand showed none and only a freshly lit grave had one). Replayed on its carrier every 2 s while it exists.
df_m2_flame_keep( ent, fxname )
{
    level endon( "end_game" );

    if ( !isdefined( fxname ) )
        fxname = df_m2_small_fire_fx();

    while ( isdefined( ent ) )
    {
        wait 2;

        if ( isdefined( ent ) && isdefined( level._effect[fxname] ) )
            playfxontag( level._effect[fxname], ent, "tag_origin" );
    }
}

// owner 2026-09-25: the fire hand's own, smaller flame (the zombie fire of the graves looked big on a hand): the hellhound
// trail fire by default, `set df_m2_hand_fx <fx key>` swaps it at the next spawn (character_fire_death_sm = the old one).
df_m2_hand_fire_fx()
{
    fxname = getdvar( "df_m2_hand_fx" );

    if ( !isdefined( fxname ) || fxname == "" )
        fxname = "dog_trail_fire";

    return fxname;
}

// The one small flame of M2 (graves and the fire hand); `set df_m2_fire_fx <fx key>` swaps it.
df_m2_small_fire_fx()
{
    fire_fx = getdvar( "df_m2_fire_fx" );

    if ( !isdefined( fire_fx ) || fire_fx == "" )
        fire_fx = "fx_zmb_tranzit_fire_lrg"; // owner 2026-09-25: large, the graves are outside the map

    return fire_fx;
}

// All four graves are spent: the lantern on the table is charged and M2 completes (df_m2_run). It rests there
// until Step 6 bursts it (df_s6_ember_burst).
df_m2_ember_charged()
{
    level.df_m2_ember_charged = 1;
    df_say( "M2_EMBER_CHARGED" );
    df_m2_ember_spawn_table( 1 );
    level.df_m2_ember_returned = 1;
    df_cue_table_place( level.df_m2_ember_pos ); // owner 2026-09-23: the one placing snap, no fire burst or ash
    playsoundatposition( "zmb_buildable_complete", df_coord( "DF_SOCKET" ).origin );
    df_debug_print( "DF: m2 all four graves spent, the burning lantern rests on the table" );
    level notify( "df_m2_check" );
}

// ---- grave waves (owner 2026-09-23) --------------------------------------------------------------
// Lighting a grave starts a WAVE at it: two sprinting zombies every 2 s from the spawn structs within 1200 of that
// grave, while fewer than 8 (+3 per extra player) of ours live around it. The wave ends the moment the grave is
// full (b.done) or goes out. Every lit hungry grave runs its own wave.
df_m2_grave_spawner()
{
    level endon( "end_game" );
    level endon( "df_m2_done" );
    level endon( "df_skip_m2" );

    while ( true )
    {
        wait 2;

        if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 || !isdefined( level.df_m2_braziers ) )
            continue;

        cap = 8 + 3 * ( getplayers().size - 1 );

        foreach ( b in level.df_m2_braziers )
        {
            if ( !isdefined( b ) || !is_true( b.lit ) || is_true( b.done ) )
                continue;

            if ( !is_true( b.df_wave_on ) )
            {
                b.df_wave_on = 1;
                df_debug_print( "DF: m2 wave ON at " + b.name );
            }

            if ( df_m2_wave_count( b ) >= cap )
                continue;

            spots = df_m2_grave_spots( b );

            if ( spots.size == 0 )
                continue;

            for ( k = 0; k < 2; k++ )
            {
                if ( getfreeactorcount() < 1 )
                    break;

                spot = random( spots );
                spawner = random( level.zombie_spawners );
                ai = spawn_zombie( spawner, spawner.targetname, spot );

                if ( !isdefined( ai ) )
                    continue;

                if ( isdefined( spot.script_noteworthy ) && issubstr( spot.script_noteworthy, "riser_location" ) )
                    ai._rise_spot = spot;
                else
                    ai.spawn_point_override = spot;

                ai.df_m2_wave = b;
                ai thread df_m2_wave_sprint();
            }
        }

        foreach ( b in level.df_m2_braziers )
        {
            if ( isdefined( b ) && is_true( b.df_wave_on ) && ( !is_true( b.lit ) || is_true( b.done ) ) )
            {
                b.df_wave_on = 0;
                df_debug_print( "DF: m2 wave OFF at " + b.name );
            }
        }
    }
}

// Our live wave zombies of grave b.
df_m2_wave_count( b )
{
    n = 0;

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( isdefined( ai ) && isalive( ai ) && isdefined( ai.df_m2_wave ) && ai.df_m2_wave == b )
            n++;
    }

    return n;
}

// self = wave zombie: sprints once it has risen (the same switch the Step 7 wave uses).
df_m2_wave_sprint()
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

df_m2_grave_spots( b )
{
    if ( isdefined( b.df_spots ) )
        return b.df_spots;

    centre = b.origin;

    if ( isdefined( b.zone ) )
        centre = b.zone; // owner 2026-09-25: the waves come at the kill zone (the grave itself stands outside the map)

    b.df_spots = df_spawn_spots_near( centre, 1200 );
    df_debug_print( "DF: m2 " + b.name + ": " + b.df_spots.size + " spawn structs for its waves" );
    return b.df_spots;
}
