// Dead Frequency - TranZit replacement Easter Egg for Plutonium T6 (loose GSC).
// Main: init, precache, vanilla EE removal (df_compat), step machine boot, debug chat commands.
//
// Install: %localappdata%\Plutonium\storage\t6\scripts\zm\zm_transit\df_*.gsc (source, no compile needed)
// Debug:   console `set df_debug 1`, then chat `!df` for the command list (see README.md)
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;
#include scripts\zm\zm_transit\df_compat;
#include scripts\zm\zm_transit\df_act1;
#include scripts\zm\zm_transit\df_act2_rich;
#include scripts\zm\zm_transit\df_act2_maxis;
#include scripts\zm\zm_transit\df_act3_sweep;
#include scripts\zm\zm_transit\df_act3_vacuum;
#include scripts\zm\zm_transit\df_act3_hold;
#include scripts\zm\zm_transit\df_finale;
#include scripts\zm\zm_transit\df_lamps;
#include scripts\zm\zm_transit\df_scav;
#include scripts\zm\zm_transit\df_catalog;
#include scripts\zm\zm_transit\df_place;
#include scripts\zm\zm_transit\df_audition;

init()
{
    if ( !isdefined( level.script ) || level.script != "zm_transit" )
        return;

    if ( isdefined( level.df_active ) )
        return;

    level.df_active = 1;

    // Precache must happen here, synchronously in init() (the level-init window). From main() it is
    // ignored ("model not precached" at spawn, tested 2026-09-07). Other loose mods do the same.
    df_coords_precache(); // every model of df_coords::df_models_init (precachemodel works only here, synchronously)
    df_catalog_page_precache(); // one page of the full catalogue when `set df_catalog_page <n>` was used (df_catalog.gsc)
    level.df_version = "1.0.0-rc4";

    // df_compat.gsc: replaces the vanilla sidequest entry points (zm_transit_sq.gsc) with no-ops and
    // filters its stat writes, so only the NavCard path of vanilla survives.
    df_compat_init();
    level thread df_boot();
}

df_boot()
{
    level endon( "end_game" );

    flag_wait( "start_zombie_round_logic" );

    df_dialogue_init();
    df_init_scaling();
    df_init_steps();
    df_coords_init();
    level.df_hints = 0; // owner 2026-09-09: vanilla feel, no puzzle prompts; `!df hints on` shows them for tests
    level.df_text_hints = 1; // dialogue audit v2 1.0: the spoken HINT_1 / HINT_2 ladder has its own switch (`!df texthints off`)

    level thread df_debug_listener();
    level thread df_hud_connect_watcher();
    df_scav_init(); // Scavenger-style carry notices + TAB square (df_scav.gsc); works without Scavenger too
    level thread df_intro_line();

    // acts register their steps; the step machine starts each one when its prerequisites are met
    df_act1_init();
    df_act2_rich_init();
    df_act2_maxis_init();
    df_act3_sweep_init();
    df_act3_vacuum_init();
    df_act3_hold_init();
    df_finale_init();

    df_debug_print( "DF " + level.df_version + " loaded" );
}

df_intro_line()
{
    level endon( "end_game" );
    wait 20;
    df_say( "D0_INTRO" );
}

// ---------------------------------------------------------------- debug ----

// Chat: "!df <sub> [args]". Only active when console dvar df_debug is 1 (`set df_debug 1`).
// "!df" alone prints the command list.
df_debug_listener()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "say", message, player );

        if ( !isdefined( player ) || !isplayer( player ) || !isdefined( message ) )
            continue;

        if ( message.size < 3 || tolower( getsubstr( message, 0, 3 ) ) != "!df" )
            continue;

        if ( getdvarint( "df_debug" ) != 1 )
        {
            player df_out( "DF: debug commands need console `set df_debug 1`" );
            continue;
        }

        args = strtok( message, " " );
        sub = "help";
        arg = undefined;

        if ( args.size > 1 )
            sub = tolower( args[1] );

        if ( args.size > 2 )
            arg = args[2];

        player thread df_debug_command( sub, arg, args );
    }
}

// self = the player who typed. Each group handler returns 1 when it knew the command.
df_debug_command( sub, arg, args )
{
    self endon( "disconnect" );

    if ( self df_debug_cmd_quest( sub, arg ) )
        return;

    if ( self df_debug_cmd_world( sub, arg, args ) )
        return;

    if ( self df_debug_cmd_coords( sub, arg, args ) )
        return;

    if ( sub != "help" )
        self df_out( "DF: unknown command `!df " + sub + "`" );

    self df_debug_help();
}

// Every command on the screen and in the console (df_out), grouped so the screen queue can hold it.
df_debug_help()
{
    self df_out( "!df commands (chat, needs `set df_debug 1`; every answer is also a [DF] console line):" );
    self df_out( "  status | scale | help" );
    self df_out( "  goto <step1|step2|step3|step4|r1|r2|m1|m2|step5|step6|step7|finale> | side rich|maxis" );
    self df_out( "  say <LINE_KEY> | hints on|off (prompts) | texthints on|off (spoken ladder) | fire <name> | simon | souls | stat rich|maxis|none" );
    self df_out( "  power on|off | side_fx [stop] | avogadro | cue avail|tick|subgoal|fail|deny|trail|done | vox <alias>" );
    self df_out( "  show [KEY] | hide | tp <KEY> | dump | pos | aim [KEY] | lift <KEY> <up> | move <KEY> <fwd> <right> <up> | ang <KEY> <pitch> <yaw> <roll>" );
    self df_out( "  grab <KEY> (prop follows your crosshair) | drop | cancel | rot <deg> | up <units>" );
    self df_out( "  model [<kind> <name>] | orb <name> | catalog <keyword|all|extra> [page] | catalog pick <n> <kind> | catalog clear | sizes <keyword|all> [page]" );
    self df_out( "  catalog <keyword|all> [page] | catalog pick <n> <kind> | catalog clear   (models side by side in front of you)" );
}

// Quest state: status, goto, side, say, hints, scale, fire, simon, souls, stat.
df_debug_cmd_quest( sub, arg )
{
    switch ( sub )
    {
        case "status":
            self df_debug_status();
            return 1;

        case "goto":
            if ( !isdefined( arg ) )
            {
                self df_out( "Usage: !df goto <step1|step2|step3|step4|r1|r2|m1|m2|step5|step6|step7|finale>" );
                return 1;
            }

            self df_debug_goto( tolower( arg ) );
            return 1;

        case "side":
            if ( !isdefined( arg ) || ( tolower( arg ) != "rich" && tolower( arg ) != "maxis" ) )
            {
                self df_out( "Usage: !df side rich|maxis" );
                return 1;
            }

            df_set_side( tolower( arg ) );
            self df_out( "DF: side = " + level.df_side );
            return 1;

        case "say":
            if ( !isdefined( arg ) )
            {
                self df_out( "Usage: !df say <LINE_KEY>   e.g. !df say D1_MAXIS" );
                return 1;
            }

            df_say( arg );
            return 1;

        case "hints":
            if ( !isdefined( arg ) || ( tolower( arg ) != "on" && tolower( arg ) != "off" ) )
            {
                self df_out( "Usage: !df hints on|off   (current: " + df_debug_hints_str() + "; off hides puzzle prompts only, mechanic prompts stay)" );
                return 1;
            }

            df_hints_set( tolower( arg ) == "on" );
            self df_out( "DF: hints " + df_debug_hints_str() );
            return 1;

        case "texthints":
            if ( !isdefined( arg ) || ( tolower( arg ) != "on" && tolower( arg ) != "off" ) )
            {
                self df_out( "Usage: !df texthints on|off   (current: " + df_debug_text_hints_str() + "; off mutes the timed HINT_1/HINT_2 ladder and event hints, START/FAIL/DONE lines stay)" );
                return 1;
            }

            df_text_hints_set( tolower( arg ) == "on" );
            self df_out( "DF: texthints " + df_debug_text_hints_str() );
            return 1;

        case "scale":
            self df_out( "players " + df_player_count() + " | lamp_souls " + df_scaled( "lamp_souls" ) + " | nodes " + df_scaled( "nodes" ) + " | sweep_time " + df_scaled( "sweep_time" ) + " | sweep_time_rich " + df_scaled( "sweep_time_rich" ) );
            self df_out( "hold_time " + df_scaled( "hold_time" ) + " | orb_hp " + df_scaled( "orb_hp" ) + " | s7_period " + df_scaled( "s7_period" ) + " | s7_cap rich " + df_scaled( "s7_cap_rich" ) + " maxis " + df_scaled( "s7_cap_maxis" ) );
            return 1;

        case "fire":
            // generic debug hook: "!df fire xyz" -> level notify( "df_debug_xyz" ). Steps listen for these.
            if ( !isdefined( arg ) )
            {
                self df_out( "Usage: !df fire <name>   -> level notify df_debug_<name>" );
                return 1;
            }

            level notify( "df_debug_" + tolower( arg ) );
            self df_out( "DF: fired df_debug_" + tolower( arg ) );
            return 1;

        case "simon":
            level.df_debug_simon = 1;
            level notify( "df_debug_simon_solved" );
            self df_out( "DF: simon says solved (storm + summon)" );
            return 1;

        case "souls":
            self df_debug_souls();
            return 1;

        case "stat":
            self df_debug_stat( arg );
            return 1;
    }

    return 0;
}

// World / vanilla state: avogadro, side_fx, power, show, hide, tp, coords, model, orb.
df_debug_cmd_world( sub, arg, args )
{
    switch ( sub )
    {
        case "avogadro":
            self df_debug_avogadro();
            return 1;

        case "side_fx":
            self df_debug_side_fx( arg );
            return 1;

        case "power":
            if ( !isdefined( arg ) || ( tolower( arg ) != "on" && tolower( arg ) != "off" ) )
            {
                self df_out( "Usage: !df power on|off   (current: " + df_power_state_str() + ")" );
                return 1;
            }

            self df_debug_power( tolower( arg ) == "on" );
            return 1;

        case "model":
            if ( !isdefined( arg ) )
            {
                self df_debug_models();
                return 1;
            }

            if ( args.size < 4 )
            {
                self df_out( "Usage: !df model <kind> <model_name>   (!df model alone lists kinds; e.g. !df model orb p6_zm_buildable_sq_meteor)" );
                return 1;
            }

            self df_debug_model_set( tolower( arg ), args[3] );
            return 1;

        case "orb":
            if ( !isdefined( arg ) )
            {
                self df_out( "Usage: !df orb <model_name>   (shortcut for !df model orb <model_name>)" );
                return 1;
            }

            self df_debug_model_set( "orb", arg );
            return 1;

        case "cue":
            self df_debug_cue( arg );
            return 1;

        case "freeze":
            // toggle: regular zombies stand still in the vanilla inert pose (df_audition.gsc); Avogadro / denizens untouched
            self df_freeze_toggle();
            return 1;

        case "fx":
            // audition a server fx where you aim (df_audition.gsc): !df fx list | <n> | next | prev | <name> | off
            self df_aud_fx( arg );
            return 1;

        case "snd":
            // audition a sound alias to you (df_audition.gsc): !df snd list | <n> | next | prev | <alias>
            self df_aud_snd( arg );
            return 1;

        case "vox":
            if ( !isdefined( arg ) )
            {
                self df_out( "Usage: !df vox <alias>   e.g. !df vox vox_maxi_tv_distress_0 (3D at your feet) | vox_zmba_sidequest_power_on_0 (2D to Samuel)" );
                return 1;
            }

            self df_debug_vox( tolower( arg ) );
            return 1;
    }

    return 0;
}

// "!df cue <name>": auditions one row of the cue grammar (df_systems cues section) at the player's feet, so
// the owner can hear that every sound means one thing. avail = STEP AVAILABLE (sound + a 6 s glint),
// tick = PROGRESS, subgoal = SUB-GOAL DONE (chime + side flash + trail to the tower), fail = FAIL,
// deny = WRONG INPUT, trail = the node -> tower trail alone, done = STEP DONE.
df_debug_cue( arg )
{
    if ( !isdefined( arg ) )
    {
        self df_out( "Usage: !df cue avail|tick|subgoal|fail|deny|trail|done   (plays that cue where you stand)" );
        return;
    }

    here = self.origin + ( 0, 0, 30 );

    switch ( tolower( arg ) )
    {
        case "avail":
            foreach ( player in getplayers() )
                player playsoundtoplayer( "zmb_screecher_portal_arrive", player );

            df_fx_burst( "fx_zmb_tranzit_key_glint", here, 6 );
            break;

        case "tick":
            df_cue_tick( here, 1 );
            break;

        case "subgoal":
            df_cue_subgoal( here, undefined );
            break;

        case "fail":
            df_cue_fail( here );
            break;

        case "deny":
            df_cue_deny( self );
            break;

        case "trail":
            level thread df_node_done_trail( here, undefined );
            break;

        case "done":
            df_step_complete_cue();
            break;

        default:
            self df_out( "DF: unknown cue " + arg + " (avail tick subgoal fail deny trail done)" );
            return;
    }

    self df_out( "DF: cue " + tolower( arg ) + " (side " + df_cue_side( undefined ) + ")" );
}

// "!df vox <alias>": plays a vanilla patron line through df_maxis_vox (vox_maxi_*, 3D at your feet) or
// df_rich_vox (anything else, 2D to the Stuhlinger player). Unknown aliases are silent: check the console.
df_debug_vox( alias )
{
    if ( alias.size >= 9 && getsubstr( alias, 0, 9 ) == "vox_maxi_" )
    {
        level thread df_maxis_vox( alias, self.origin + ( 0, 0, 50 ) );
        self df_out( "DF: maxis vox " + alias + " at your feet (silence = alias unknown or a Maxis line already playing)" );
        return;
    }

    level thread df_rich_vox( alias, undefined );
    self df_out( "DF: rich vox " + alias + " to Samuel (silence = alias unknown or a Richtofen line already playing)" );
}

// World anchors (df_coords): show, hide, tp, coords, ang, lift, move. Tuning results also go to the
// console and the df_pos dvar (df_debug_tune_result).
df_debug_cmd_coords( sub, arg, args )
{
    switch ( sub )
    {
        case "show":
            if ( isdefined( arg ) && !isdefined( df_coord( arg ) ) )
            {
                self df_out( "DF: unknown key " + arg + " (!df coords lists them)" );
                return 1;
            }

            df_preview_show( arg );
            self df_out( "DF: preview spawned (!df hide to remove, !df tp <KEY> to visit)" );
            return 1;

        case "hide":
            df_preview_hide();
            self df_out( "DF: preview removed" );
            return 1;

        case "tp":
            if ( !isdefined( arg ) )
            {
                self df_out( "Usage: !df tp <KEY>   e.g. !df tp DF_TV_1   (!df coords lists keys)" );
                return 1;
            }

            if ( !self df_preview_teleport( arg ) )
                self df_out( "DF: unknown key " + arg );

            return 1;

        case "coords":
        case "dump":
            // every anchor as [SPOT] lines and the model registry as [MODEL] lines, console only (df_coords_dump)
            self df_out( df_coords_dump() );
            return 1;

        case "ang":
            if ( args.size < 6 )
            {
                self df_out( "Usage: !df ang <KEY> <pitch> <yaw> <roll>   e.g. !df ang DF_TV_1 270 90 180" );
                return 1;
            }

            self df_debug_tune_result( df_coord_tune_angles( args[2], float( args[3] ), float( args[4] ), float( args[5] ) ), args[2] );
            return 1;

        case "lift":
            if ( args.size < 4 )
            {
                self df_out( "Usage: !df lift <KEY> <units>   e.g. !df lift DF_SOCKET 6" );
                return 1;
            }

            self df_debug_tune_result( df_coord_tune_lift( args[2], float( args[3] ) ), args[2] );
            return 1;

        case "move":
            if ( args.size < 6 )
            {
                self df_out( "Usage: !df move <KEY> <forward> <right> <up>   (relative to where you face)" );
                return 1;
            }

            self df_debug_tune_result( df_coord_tune_move( args[2], self, float( args[3] ), float( args[4] ), float( args[5] ) ), args[2] );
            return 1;

        case "catalog":
            self df_debug_catalog( args );
            return 1;

        case "grab":
            if ( args.size < 3 )
            {
                self df_out( "Usage: !df grab <KEY>   the prop follows your crosshair: melee = place, ADS = freeze, 1/2 turn, 3/4 raise, F = surface/float, space = reset" );
                return 1;
            }

            self df_place_grab( args[2] );
            return 1;

        case "drop":
            self df_place_drop();
            return 1;

        case "cancel":
            self df_place_cancel();
            return 1;

        case "rot":
            if ( args.size < 3 )
            {
                self df_out( "Usage: !df rot <degrees>   (turns the held prop; negative turns the other way)" );
                return 1;
            }

            self df_place_rot( float( args[2] ) );
            return 1;

        case "up":
            if ( args.size < 3 )
            {
                self df_out( "Usage: !df up <units>   (raises the held prop; negative lowers it)" );
                return 1;
            }

            self df_place_up( float( args[2] ) );
            return 1;

        case "pos":
        case "aim":
            // where you stand AND where you look (bench tops, tables, walls) + the height between the two
            self df_debug_aim( args );
            return 1;

        case "sizes":
            // every model of the map (792) with its measured size and zone, in the console; no precache needed
            if ( args.size < 3 )
            {
                self df_out( "Usage: !df sizes <keyword|all> [page]   e.g. !df sizes table   (name, WxHxD in units, zone; player ~70 tall)" );
                return 1;
            }

            page = 1;

            if ( args.size > 3 )
                page = int( args[3] );

            self df_out( df_catalog_sizes_print( tolower( args[2] ), page ) );
            return 1;
    }

    return 0;
}

// ---------------------------------------------------------------- catalog ----
// "!df catalog <keyword|all> [page]": up to 10 catalog models (df_coords::df_catalog_models) in a row in
// front of the player, 70 units apart, a key glint above each (higher for each next number), numbered
// left to right in the console. "!df catalog clear" removes them, "!df catalog pick <n> <kind>" puts
// entry n of the last shown page into the registry (df_model_set) and re-shows the anchors.
df_debug_catalog( args )
{
    if ( args.size < 3 )
    {
        self df_out( "Usage: !df catalog <keyword|all> [page] | catalog pick <n> <kind> | catalog clear   e.g. !df catalog rocks" );
        return;
    }

    what = tolower( args[2] );

    if ( what == "clear" )
    {
        df_debug_catalog_clear();
        self df_out( "DF: catalog cleared" );
        return;
    }

    if ( what == "pick" )
    {
        self df_debug_catalog_pick( args );
        return;
    }

    page = 1;

    if ( args.size > 3 )
        page = int( args[3] );

    if ( page < 1 )
        page = 1;

    self df_debug_catalog_show( what, page );
}

// "!df pos" / "!df aim [KEY]": prints the player's feet, the exact point they are LOOKING at and the height
// between the two, so a prop can be recorded on a bench top or a table instead of the floor under the feet.
// The trace is the vanilla bullettrace( from, to, hit_players, ignore_ent ) used all over the stock scripts
// (e.g. Core/maps/mp/zombies/_zm_weap_jetgun.gsc). With a KEY the anchor is snapped to that point right away.
df_debug_aim( args )
{
    eye = self geteye();
    forward = anglestoforward( self getplayerangles() );
    trace = bullettrace( eye, eye + forward * 2500, 0, self );
    pos = trace["position"];
    normal = ( 0, 0, 1 );

    if ( isdefined( trace["normal"] ) )
        normal = trace["normal"];

    surface = "floor/top";

    if ( normal[2] < 0.35 && normal[2] > -0.35 )
        surface = "wall";
    else if ( normal[2] <= -0.35 )
        surface = "ceiling";

    dz = int( pos[2] - self.origin[2] );
    yaw = int( self.angles[1] );
    self df_out( "feet " + df_debug_vec( self.origin ) + " | ang 0 " + yaw + " 0" );
    self df_out( "aim  " + df_debug_vec( pos ) + " | " + surface + " | " + dz + " above your feet | " + int( distance( self.origin, pos ) ) + " units away" );

    // paste-ready line for df_coords::df_apply_overrides
    face = yaw + 180;
    origin = pos + ( 0, 0, 1 );

    if ( surface == "wall" )
    {
        face = int( vectortoangles( normal )[1] );
        origin = pos + normal * 2;
    }

    df_debug_print( "DF: [AIM] df_coord_override( \"KEY\", ( " + int( origin[0] ) + ", " + int( origin[1] ) + ", " + int( origin[2] ) + " ), ( 0, " + face + ", 0 ) );" );

    if ( args.size < 3 )
    {
        self df_out( "paste line in the console. `!df aim <KEY>` snaps that anchor here (e.g. !df aim DF_TV_1)" );
        return;
    }

    key = args[2];

    if ( !isdefined( df_coord( key ) ) )
    {
        self df_out( "DF: unknown anchor " + key + " (!df dump lists them)" );
        return;
    }

    df_coord_override( key, origin, ( 0, face, 0 ) );
    self df_out( "DF: " + key + " snapped to your aim point (" + surface + "). !df show to look; !df ang " + key + " <pitch> " + face + " <roll> for the model pose" );
}

// "x y z" as integers
df_debug_vec( v )
{
    return int( v[0] ) + " " + int( v[1] ) + " " + int( v[2] );
}

// Spawns page `page` (10 per page) of the names containing `keyword` in a row in front of self.
df_debug_catalog_show( keyword, page )
{
    names = df_catalog_filter( keyword );

    // plus the page of the full catalogue precached by `set df_catalog_page <n>` (df_catalog.gsc)
    foreach ( line in df_catalog_match( keyword ) )
    {
        name = df_cat_name( line );

        if ( df_catalog_page_has( name ) && !isinarray( names, name ) )
            names[names.size] = name;
    }

    if ( names.size == 0 )
    {
        self df_out( "DF: no catalog model contains `" + keyword + "` (try: buildable rocks sphere pole light barrel tank skull bottle all)" );
        return;
    }

    pages = int( ( names.size + 9 ) / 10 );

    if ( page > pages )
        page = pages;

    df_debug_catalog_clear();
    level.df_catalog_ents = [];
    level.df_catalog_shown = [];

    yaw = self.angles[1];
    forward = anglestoforward( ( 0, yaw, 0 ) );
    right = anglestoright( ( 0, yaw, 0 ) );
    first = ( page - 1 ) * 10;
    count = names.size - first;

    if ( count > 10 )
        count = 10;

    screen = "";

    for ( i = 0; i < count; i++ )
    {
        name = names[first + i];
        pos = df_ground( self.origin + forward * 160 + right * ( ( i - ( count - 1 ) / 2.0 ) * 70 ) ) + ( 0, 0, 1 );
        ent = spawn( "script_model", pos );
        ent setmodel( name );
        ent.angles = df_debug_catalog_angles( name, yaw + 180 );
        level.df_catalog_ents[level.df_catalog_ents.size] = ent;

        // glint climbs 10 units per number: #1 lowest (your left), #10 highest (your right)
        glint = df_fx_loop( "fx_zmb_tranzit_key_glint", pos + ( 0, 0, 50 + i * 10 ) );

        if ( isdefined( glint ) )
            level.df_catalog_ents[level.df_catalog_ents.size] = glint;

        level.df_catalog_shown[i + 1] = name;
        df_coords_console( "[CATALOG] " + ( i + 1 ) + ". " + name );
        screen = screen + ( i + 1 ) + " " + name + "  ";

        if ( i % 5 == 4 || i == count - 1 )
        {
            self iprintln( screen );
            screen = "";
        }
    }

    self df_out( "DF: catalog `" + keyword + "` page " + page + "/" + pages + ": " + count + " models, #1 on your LEFT (lowest glint). !df catalog pick <n> <kind> | !df catalog clear" );
}

// A catalog model stands with the pose of the registry kind that uses it (tv 270/180 ...), else upright,
// front towards the player.
df_debug_catalog_angles( name, front_yaw )
{
    kind = df_model_kind_of( name );

    if ( isdefined( kind ) )
        return df_model_angles( kind, front_yaw );

    return ( 0, front_yaw, 0 );
}

df_debug_catalog_clear()
{
    if ( isdefined( level.df_catalog_ents ) )
    {
        foreach ( ent in level.df_catalog_ents )
        {
            if ( isdefined( ent ) )
                ent delete();
        }
    }

    level.df_catalog_ents = [];
}

// "!df catalog pick <n> <kind>": entry n of the last shown page becomes the model of <kind>.
df_debug_catalog_pick( args )
{
    if ( args.size < 5 || !isdefined( level.df_catalog_shown ) || level.df_catalog_shown.size == 0 )
    {
        self df_out( "Usage: !df catalog pick <n> <kind>   after a !df catalog <keyword>; kinds: relay relay_top orb part_a part_b part_c tv phone fuse socket brazier card portal beacon" );
        return;
    }

    n = int( args[3] );
    kind = tolower( args[4] );

    if ( n < 1 || !isdefined( level.df_catalog_shown[n] ) )
    {
        self df_out( "DF: pick a number between 1 and " + level.df_catalog_shown.size + " (left to right in the last catalog row)" );
        return;
    }

    if ( !isdefined( level.df_models ) )
        df_models_init();

    old = "(new kind)";

    if ( isdefined( level.df_models[kind] ) )
        old = level.df_models[kind];

    df_model_set( kind, level.df_catalog_shown[n] );
    df_preview_show( undefined );
    self df_out( "DF: " + kind + " = " + level.df_catalog_shown[n] + " (was " + old + "); anchors re-shown. Props spawned from now on use it (!df goto or restart the step); to keep it, tell me the kind + name" );
}

df_debug_hints_str()
{
    if ( df_hints_on() )
        return "on";

    return "off";
}

df_debug_text_hints_str()
{
    if ( df_text_hints_on() )
        return "on";

    return "off";
}

// "!df souls": fill every open soul counter (fuse boxes, lamps) at once.
df_debug_souls()
{
    if ( isdefined( level.df_fuses ) && isdefined( level.df_r1_refill_target ) )
    {
        foreach ( fuse in level.df_fuses )
            fuse.souls = level.df_r1_refill_target;
    }

    if ( isdefined( level.df_r2_lamps ) )
    {
        foreach ( lamp in level.df_r2_lamps )
            df_r2_fill( lamp );
    }

    level notify( "df_debug_souls_done" );
    self df_out( "DF: soul counters filled" );
}

// "!df stat rich|maxis|none": WRITES the globe stat (df_write_completion_stat) or clears it.
df_debug_stat( arg )
{
    if ( !isdefined( arg ) || ( tolower( arg ) != "rich" && tolower( arg ) != "maxis" && tolower( arg ) != "none" ) )
    {
        self df_out( "Usage: !df stat rich|maxis|none   (WRITES the globe stat; none = clear it)" );
        return;
    }

    if ( tolower( arg ) == "none" )
    {
        df_reset_completion_stat();
        self df_out( "DF: sq_transit_last_completed cleared (globe off)" );
        return;
    }

    df_write_completion_stat( tolower( arg ) );
    self df_out( "DF: wrote sq_transit_last_completed for side " + tolower( arg ) );
}

// "!df side_fx [stop]": our tower visuals for the locked side.
df_debug_side_fx( arg )
{
    if ( isdefined( arg ) && tolower( arg ) == "stop" )
    {
        df_tower_fx_stop();
        self df_out( "DF: tower fx stopped" );
        return;
    }

    if ( !isdefined( level.df_side ) )
    {
        self df_out( "DF: lock a side first (!df side rich|maxis)" );
        return;
    }

    df_tower_fx_start( level.df_side );
    self df_out( "DF: tower fx started for " + level.df_side + " (!df side_fx stop to end)" );
}

// "!df model": the model registry of df_coords (level.df_models), one kind per line.
df_debug_models()
{
    if ( !isdefined( level.df_models ) )
        df_models_init();

    self df_out( "DF models (kind = name); swap one with !df model <kind> <name>:" );

    foreach ( kind, name in level.df_models )
        self df_out( "  " + kind + " = " + name );
}

// "!df model <kind> <name>" / "!df orb <name>": live swap through df_coords::df_model_set. Only props
// spawned afterwards use it, and a runtime swap is NOT precached (precachemodel works only in init()).
df_debug_model_set( kind, name )
{
    if ( !isdefined( level.df_models ) )
        df_models_init();

    old = "(new kind)";

    if ( isdefined( level.df_models[kind] ) )
        old = level.df_models[kind];

    df_model_set( kind, name );
    df_preview_show( undefined );
    self df_out( "DF: model " + kind + " = " + name + " (was " + old + "); anchors re-shown, props spawned from now on use it (!df goto or restart the step)" );
    self df_out( "DF: a name outside the registry / catalog (!df catalog all) is NOT precached and renders as nothing until it is added to df_coords.gsc and the map reloaded" );
}

df_power_state_str()
{
    if ( flag( "power_on" ) )
        return "on";

    return "off";
}

// Flips TranZit's power without touching the switch. If the power switch is built, the real switch
// trigger is fired so vanilla runs its full sequence; otherwise the flags and client notifies vanilla
// would set are applied directly (zm_transit_power.gsc::electricswitch).
df_debug_power( on )
{
    if ( on == flag( "power_on" ) )
    {
        self df_out( "DF: power already " + df_power_state_str() );
        return;
    }

    trig = getent( "powerswitch_buildable_trigger_power", "targetname" );

    if ( isdefined( trig ) )
    {
        trig notify( "trigger", self );
        wait 0.2;

        if ( on == flag( "switches_on" ) )
        {
            self df_out( "DF: power switch flipped, wait for the reactor" );
            return;
        }
    }

    if ( on )
    {
        flag_set( "switches_on" );
        clientnotify( "pwr" );
        level thread df_debug_power_finish();
        self df_out( "DF: power coming on (reactor sequence)" );
        return;
    }

    flag_clear( "switches_on" );
    clientnotify( "pwo" );
    flag_clear( "power_on" );
    self df_out( "DF: power off" );
}

df_debug_power_finish()
{
    level endon( "end_game" );
    level thread df_debug_power_timeout();
    level waittill_either( "power_event_complete", "df_power_timeout" );
    clientnotify( "pwr" );
    flag_set( "power_on" );
    df_debug_print( "DF: power on" );
}

df_debug_power_timeout()
{
    level endon( "end_game" );
    level endon( "power_event_complete" );
    wait 4;
    level notify( "df_power_timeout" );
}

df_debug_tune_result( line, key )
{
    if ( !isdefined( line ) )
    {
        self df_out( "DF: unknown key " + key + " (!df coords lists them)" );
        return;
    }

    self iprintln( line );
    print( line + "\n" );
    setdvar( "df_pos", line );
}

df_debug_status()
{
    side = "none";

    if ( isdefined( level.df_side ) )
        side = level.df_side;

    self df_out( "DF " + level.df_version + " | side " + side + " | players " + df_player_count() + " | round " + level.round_number + " | prompts " + df_debug_hints_str() + " | texthints " + df_debug_text_hints_str() );

    done = "";
    avail = "";
    registered = "";

    foreach ( key in level.df_step_order )
    {
        if ( df_is_done( key ) )
            done = done + key + " ";
        else if ( isdefined( level.df_step_avail_round[key] ) )
            avail = avail + key + " ";

        if ( isdefined( level.df_step_func[key] ) )
            registered = registered + key + " ";
    }

    self df_out( "done: " + done );
    self df_out( "available: " + avail );
    self df_out( "registered: " + registered );
}

df_step_index( key )
{
    for ( i = 0; i < level.df_step_order.size; i++ )
    {
        if ( level.df_step_order[i] == key )
            return i;
    }

    return -1;
}

// Marks every step before `target` complete (running its setup_func when one exists) so the
// target becomes available. Picks a side automatically when the target needs one.
df_debug_goto( target )
{
    if ( df_step_index( target ) < 0 )
    {
        self df_out( "DF: unknown step " + target );
        return;
    }

    if ( is_true( level.df_goto_busy ) )
    {
        self df_out( "DF: a goto is still running" );
        return;
    }

    // Set before any notify: runners stay parked in df_wait_prereq until the jump is finished, so
    // intermediate steps are never started for a frame and then skipped.
    level.df_goto_busy = 1;

    if ( isdefined( level.df_step_side[target] ) && ( !isdefined( level.df_side ) || level.df_side != level.df_step_side[target] ) )
    {
        // the target belongs to a side: lock it, otherwise its runner can never become available
        df_set_side( level.df_step_side[target] );
        self df_out( "DF: side set to " + level.df_side + " for " + target );
    }
    else if ( !isdefined( level.df_side ) && df_step_index( target ) > df_step_index( "step4" ) )
    {
        df_set_side( "rich" );
        self df_out( "DF: no side locked, defaulting to rich (use !df side maxis first to test Maxis)" );
    }

    // level thread: a player leaving mid-jump must not leave df_goto_busy stuck at 1
    level thread df_debug_goto_run( target );
}

df_debug_goto_run( target )
{
    level endon( "end_game" );

    for ( i = 0; i < level.df_step_order.size; i++ )
    {
        key = level.df_step_order[i];

        if ( key == target )
            break;

        if ( isdefined( level.df_step_side[key] ) && level.df_step_side[key] != level.df_side )
            continue;

        if ( df_is_done( key ) )
            continue;

        level notify( "df_skip_" + key );

        if ( isdefined( level.df_step_setup[key] ) )
            level [[ level.df_step_setup[key] ]]();

        df_complete( key );
        wait 0.05;
    }

    level.df_goto_busy = 0;
    level notify( "df_step_done", "goto" );
    df_debug_print( "DF: jumped to " + target );
}

// Forces Avogadro back from the cloud (spec 8.2): cloud_update() returns him when
// level.round_number >= self.return_round.
df_debug_avogadro()
{
    if ( !isdefined( level.avogadro ) )
    {
        self df_out( "DF: no avogadro entity yet" );
        return;
    }

    state = "undefined";

    if ( isdefined( level.avogadro.state ) )
        state = level.avogadro.state;

    if ( state == "cloud" )
    {
        level.avogadro.return_round = level.round_number;
        self df_out( "DF: avogadro return forced" );
        return;
    }

    self df_out( "DF: avogadro state is " + state + " (only 'cloud' can be forced)" );
}

// Vanilla tower notifies, kept for reference (zm_transit_classic.csc): "sq_kfx" kills the runner
// loop, "sqkl" kills the lightning loop, "sqm"/"sqr" start orange/blue runners + lightning, but
// "sqr" only ever plays once per game. We use our own df_tower_fx_start/stop instead.
