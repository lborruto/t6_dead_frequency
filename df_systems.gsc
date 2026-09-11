// Dead Frequency - shared systems: dialogue HUD (subtitles), vanilla VO (df_maxis_vox / df_rich_vox /
// df_vox_once), FX, the unified cue grammar (df_cue_* / df_node_done_trail, art audit 2026-09-09), prompts
// (df_prompt / df_prompt_puzzle + level.df_hints), the dialogue-ladder switch (level.df_text_hints), single
// press (df_press_use), hold-to-use bars, icons, stats.
// HUD elems are per player (newclienthudelem) and destroyed on disconnect (df_sys_hud_disconnect_watch).
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;

// ---------------------------------------------------------------- debug ----

df_debug_print( msg )
{
    if ( getdvarint( "df_debug" ) == 1 )
    {
        iprintln( msg );
        print( "[DF] " + msg + "\n" );
    }
}

// Debug output: on the caller's screen when self is a player, and always in the console
// (console output needs `developer_script 1`), so results can be copy-pasted.
df_out( text )
{
    if ( isdefined( self ) && isplayer( self ) )
        self iprintln( text );

    print( "[DF] " + text + "\n" );
}

df_array_shift( arr )
{
    out = [];

    for ( i = 1; i < arr.size; i++ )
        out[out.size] = arr[i];

    return out;
}

// ------------------------------------------------------------- dialogue ----

// Queue all lines stored under `key`. Lines are shown one at a time, 6.5 s apart (df_say_pump). A line
// tagged coop (df_add_line 5th argument, "one lamp each") is dropped in solo.
df_say( key )
{
    key = df_sys_line_key( key );

    if ( !isdefined( key ) )
        return;

    solo = getplayers().size < 2;

    foreach ( e in level.df_lines[key] )
    {
        if ( solo && is_true( e.coop ) )
            continue;

        df_sys_line_queue( e );
    }
}

// Resolves a sheet key: lowercase alias, then the side variant of an event key once the side is locked
// (D5_FAIL -> D5_FAIL_RICH / _MAXIS, the plain key stays the fallback; dialogue2 request 2026-09-08).
// Undefined, with one debug line, for a key the sheet does not have.
df_sys_line_key( key )
{
    df_dialogue_init();

    if ( !isdefined( level.df_lines[key] ) && isdefined( level.df_lines_lower[tolower( key )] ) )
        key = level.df_lines_lower[tolower( key )];

    if ( isdefined( level.df_side ) )
    {
        suffix = "_MAXIS";

        if ( level.df_side == "rich" )
            suffix = "_RICH";

        if ( isdefined( level.df_lines[key + suffix] ) )
            key = key + suffix;
    }

    if ( !isdefined( level.df_lines[key] ) )
    {
        df_debug_print( "DF: unknown dialogue key " + key );
        return undefined;
    }

    return key;
}

// Appends one line struct to the queue and starts the pump when it is idle.
df_sys_line_queue( e )
{
    if ( !isdefined( level.df_say_queue ) )
        level.df_say_queue = [];

    level.df_say_queue[level.df_say_queue.size] = e;

    if ( !is_true( level.df_say_running ) )
        level thread df_say_pump();
}

df_say_pump()
{
    level endon( "end_game" );
    level.df_say_running = 1;

    while ( level.df_say_queue.size > 0 )
    {
        e = level.df_say_queue[0];
        level.df_say_queue = df_array_shift( level.df_say_queue );
        df_show_line( e );
        wait 6.5;
    }

    level.df_say_running = 0;
}

// Recipients, as in vanilla (zm_transit_sq.gsc richtofensay :956, zm_transit.gsc:1184): Maxis is heard by every
// player; Richtofen by the Stuhlinger player only (level.rich_sq_player), solo included. No Stuhlinger in the
// game = no Richtofen line. Speaker name coloured (Maxis warm orange, Richtofen cold blue), the text itself
// white. Debug: one console line naming the recipients.
df_show_line( e )
{
    if ( e.speaker == "maxis" )
    {
        name = "MAXIS:";
        color = ( 1, 0.72, 0.4 );
        recipients = getplayers();
    }
    else
    {
        name = "RICHTOFEN:";
        color = ( 0.55, 0.78, 1 );
        recipients = [];
        player = df_rich_recipient();

        // vanilla, strictly (owner 2026-09-11): Stuhlinger alone hears Richtofen. No Stuhlinger playing = the line is
        // dropped (one console note per game).
        if ( isdefined( player ) )
            recipients[0] = player;
        else if ( !is_true( level.df_rich_silent_said ) )
        {
            level.df_rich_silent_said = 1;
            df_debug_print( "DF: no Stuhlinger in this game: Richtofen stays silent (vanilla rule), his lines are dropped" );
        }
    }

    // a copy queued for one recipient only (nobody when he has left)
    if ( isdefined( e.only ) )
    {
        recipients = [];
        recipients[0] = e.only;
    }

    names = "";

    foreach ( player in recipients )
    {
        player thread df_hud_line( e.text, color, 6, name );
        names += player.name + " ";
    }

    if ( names == "" )
        names = "nobody ";

    df_debug_print( "DF: line " + name + " -> " + names + "(" + recipients.size + "/" + getplayers().size + ")" );
}

// Solo: the only player. Co-op: the Stuhlinger player (characterindex 1, set in zm_transit.gsc:1184).
// Co-op without Stuhlinger: first player, so the story is not lost.
// Vanilla rule, strictly (owner 2026-09-11; zm_transit_sq.gsc richtofensay :956): Richtofen speaks to
// level.rich_sq_player, Stuhlinger, and to nobody else, solo included. No Stuhlinger in the game = Richtofen silent.
df_rich_recipient()
{
    if ( isdefined( level.rich_sq_player ) && isplayer( level.rich_sq_player ) && is_player_valid( level.rich_sq_player ) )
        return level.rich_sq_player;

    return undefined;
}

// True when Richtofen has nobody to talk to (no Stuhlinger playing).
df_rich_silent()
{
    return !isdefined( df_rich_recipient() );
}

// The tiny "a line appeared" tick, played to self (player) when a subtitle is shown. One place to
// change the alias. zmb_tombstone_timer_count: the Tombstone countdown tick, played to a player
// (_zm_tombstone.gsc:380), in tools/assets/sounds_zm_transit.txt. Louder fallbacks in the dump:
// zmb_player_hit_ding (hit marker, _zm_gametype.gsc:341), zmb_switch_flip (zm_transit_power.gsc:57).
df_sys_line_tick()
{
    self playlocalsound( "zmb_tombstone_timer_count" );
}

// ---- bottom-centre HUD slot map (vertalign user_bottom, negative y = up) --------------------------
//   df_bar_*          bar at y -48 (8 px, middle aligned), its label bottom at -56
//   df_prompt(_puzzle) text bottom at -78
//   subtitle rows      bottom row at -104, one more row every 18 px upwards (max 3 rows)
// Countdown timers of the steps sit at user_top y 40, part/carry icons at user_right, so nothing
// overlaps. Fonts: "default" as vanilla laststand text (_zm_laststand.gsc:876), scale 1.3.

// Subtitle layout (horzalign user_center, x relative to the screen centre). The speaker name is its
// own elem, right-aligned so it ends at DF_LINE_NAME_X whatever its width; the text rows are
// left-aligned from DF_LINE_TEXT_X (first row next to the name, continuation rows under the text).
// Row width 44 chars at scale 1.3 stays inside the safe area (~+240 px). Tune here only.
df_sys_line_name_x()
{
    return -190;
}

df_sys_line_text_x()
{
    return -182;
}

// Subtitle: coloured speaker name + white word-wrapped text rows, 0.4 s fade in, 0.6 s fade out,
// plus the tick (df_sys_line_tick). self = player. name undefined = text only, in `color`.
// The seq guard lets a newer line replace an older one without either touching destroyed elems.
df_hud_line( text, color, duration, name )
{
    self endon( "disconnect" );

    self df_sys_line_clear();
    rows = df_sys_wrap( text, 44, 3 );
    huds = [];
    text_color = ( 1, 1, 1 );

    if ( !isdefined( name ) )
        text_color = color;

    top_y = -104 - ( rows.size - 1 ) * 18;

    if ( isdefined( name ) )
    {
        hud = self df_sys_text_elem( top_y, 1.3, color, "right", df_sys_line_name_x() );
        hud settext( name );
        huds[huds.size] = hud;
    }

    for ( i = 0; i < rows.size; i++ )
    {
        // rows[0] is the top row
        hud = self df_sys_text_elem( top_y + i * 18, 1.3, text_color, "left", df_sys_line_text_x() );
        hud settext( rows[i] );
        huds[huds.size] = hud;
    }

    foreach ( hud in huds )
    {
        hud.alpha = 0;
        hud fadeovertime( 0.4 );
        hud.alpha = 1;
    }

    self.df_line_huds = huds;
    self df_sys_line_tick();

    if ( !isdefined( self.df_line_seq ) )
        self.df_line_seq = 0;

    self.df_line_seq++;
    my_seq = self.df_line_seq;

    wait( duration - 0.6 );

    // a newer line replaced (and destroyed) ours in the meantime
    if ( self.df_line_seq != my_seq )
        return;

    foreach ( hud in huds )
    {
        if ( isdefined( hud ) )
        {
            hud fadeovertime( 0.6 );
            hud.alpha = 0;
        }
    }

    wait 0.6;

    if ( self.df_line_seq == my_seq )
        self df_sys_line_clear();
}

// Destroys the current subtitle elems (name and rows) of a player (self).
df_sys_line_clear()
{
    if ( isdefined( self.df_line_huds ) )
    {
        foreach ( hud in self.df_line_huds )
        {
            if ( isdefined( hud ) )
                hud destroy();
        }
    }

    self.df_line_huds = [];
}

// Greedy word wrap: rows of at most `width` characters, at most `maxrows` rows (the last row takes
// whatever is left). settext does not wrap by itself and a long line runs off the safe area.
df_sys_wrap( text, width, maxrows )
{
    words = strtok( text, " " );
    rows = [];
    row = "";

    foreach ( word in words )
    {
        if ( row == "" )
        {
            row = word;
            continue;
        }

        if ( row.size + 1 + word.size > width && rows.size < maxrows - 1 )
        {
            rows[rows.size] = row;
            row = word;
            continue;
        }

        row = row + " " + word;
    }

    if ( row != "" )
        rows[rows.size] = row;

    return rows;
}

// One bottom text elem for self (player) with the shared style; caller sets text and alpha.
// Default: centred at x 0 (prompts, bar labels). alignx "left"/"right" with x: anchored at that
// offset from the screen centre (subtitle name and rows).
df_sys_text_elem( y, scale, color, alignx, x )
{
    if ( !isdefined( alignx ) )
        alignx = "center";

    if ( !isdefined( x ) )
        x = 0;

    hud = newclienthudelem( self );
    hud.alignx = alignx;
    hud.aligny = "bottom";
    hud.horzalign = "user_center";
    hud.vertalign = "user_bottom";
    hud.x = x;
    hud.y = y;
    hud.font = "default";
    hud.fontscale = scale;
    hud.color = color;
    hud.alpha = 1;
    hud.foreground = 1;
    hud.hidewheninmenu = 1;
    return hud;
}

// ------------------------------------------------------------------- VO ----
// Vanilla patron voice lines for free (art audit 2026-09-09 section 5). Aliases are the exact strings
// zm_transit_sq.gsc plays (grep vox_): vox_maxi_* (tv_distress, build_complete, near_corn, power_off,
// avogadro_stab, turbines_out, turbine_2light_on, turbine_final, ...) and vox_zmba_sidequest_* (power_on,
// jet_complete, near_light, jet_low, zom_lure, 4emp_mag, ...). Vanilla plays Maxis with playsoundatposition
// (zm_transit_sq.gsc:1008 maxissay) and Richtofen with playsoundtoplayer to level.rich_sq_player (:965
// richtofensay); these helpers do the same. Both BLOCK for the line (serialised per patron so two lines
// never overlap): always `level thread` them. An unknown alias is silent, never a crash.

// Maxis line: 3D at origin when given, else 2D to every player (Maxis is heard by all, df_show_line rule).
df_maxis_vox( alias, origin )
{
    level endon( "end_game" );

    while ( is_true( level.df_maxis_talking ) )
        wait 0.1;

    level.df_maxis_talking = 1;
    df_sys_vox_play( alias, origin, undefined );
    wait 8;
    level.df_maxis_talking = 0;
}

// Richtofen line: 2D to the Stuhlinger player (df_rich_recipient) like vanilla, or 3D at origin when given.
// While he speaks 2D the recipient's own character VO is muted (player.dontspeak, zm_transit_sq.gsc:975).
df_rich_vox( alias, origin )
{
    level endon( "end_game" );

    while ( is_true( level.df_rich_talking ) )
        wait 0.1;

    player = df_rich_recipient();

    // vanilla rule (owner 2026-09-11): no Stuhlinger in a co-op lobby = no Richtofen, recordings included
    if ( df_rich_silent() )
        return;

    if ( !isdefined( player ) && !isdefined( origin ) )
        return;

    level.df_rich_talking = 1;
    df_sys_vox_play( alias, origin, player );

    if ( isdefined( player ) && !isdefined( origin ) )
        player.dontspeak = 1;

    wait 8;

    if ( isdefined( player ) )
        player.dontspeak = 0;

    level.df_rich_talking = 0;
}

// One alias, one delivery: 3D at origin (playsoundatposition, zm_transit_sq.gsc:1008) when origin is given,
// else 2D (playsoundtoplayer, :965) to `player`, or to everyone when no player is given.
df_sys_vox_play( alias, origin, player )
{
    if ( isdefined( origin ) )
    {
        playsoundatposition( alias, origin );
        df_debug_print( "DF: vox " + alias + " 3D" );
        return;
    }

    if ( isdefined( player ) )
    {
        player playsoundtoplayer( alias, player );
        df_debug_print( "DF: vox " + alias + " -> " + player.name );
        return;
    }

    foreach ( p in getplayers() )
        p playsoundtoplayer( alias, p );

    df_debug_print( "DF: vox " + alias + " -> all" );
}

// Plays a vanilla vox alias at most once per game (event lines fired from polls or repeats). The patron is
// read from the alias (vox_maxi_* = Maxis, anything else = Richtofen); origin optional (see the helpers).
// Does NOT block: it threads the helper itself. Returns 1 the first time, 0 afterwards.
df_vox_once( alias, origin )
{
    if ( !isdefined( level.df_vox_said ) )
        level.df_vox_said = [];

    if ( is_true( level.df_vox_said[alias] ) )
        return 0;

    level.df_vox_said[alias] = 1;

    if ( alias.size >= 9 && getsubstr( alias, 0, 9 ) == "vox_maxi_" )
        level thread df_maxis_vox( alias, origin );
    else
        level thread df_rich_vox( alias, origin );

    return 1;
}

// ---------------------------------------------------------------- sounds ----

// A short 3D alias "at" origin, delivered to every player within radius at the listener (playsoundtoplayer on the
// player = distance 0 = full volume). Sound audit 2026-09-09: most cue aliases of the banks fade out at 150-175
// units, so playsoundatposition at a lamp, a box or a brazier reached nobody standing a few metres away.
df_snd_near( alias, origin, radius )
{
    foreach ( player in getplayers() )
    {
        if ( distancesquared( player.origin, origin ) <= radius * radius )
            player playsoundtoplayer( alias, player );
    }
}

// ------------------------------------------------------------------- FX ----

// Looping FX: returns the tag_origin entity carrying it. Delete it (df_fx_stop) to stop.
df_fx_loop( fxname, origin, angles )
{
    if ( !isdefined( level._effect[fxname] ) )
    {
        df_debug_print( "DF: missing fx " + fxname );
        return undefined;
    }

    ent = spawn( "script_model", origin );
    ent setmodel( "tag_origin" );

    if ( isdefined( angles ) )
        ent.angles = angles;

    playfxontag( level._effect[fxname], ent, "tag_origin" );
    return ent;
}

df_fx_stop( ent )
{
    if ( isdefined( ent ) )
        ent delete();
}

df_fx_once( fxname, origin )
{
    if ( !isdefined( level._effect[fxname] ) )
    {
        df_debug_print( "DF: missing fx " + fxname );
        return;
    }

    playfx( level._effect[fxname], origin );
}

// ------------------------------------------------------------- tower fx ----
// Server-side re-creation of the vanilla completion visuals (zm_transit_classic.csc):
// a lightning orb at the tower top plus coloured spark runners climbing the sq_common_pole_fx
// struct chains. Vanilla's client version plays the Richtofen colour only once per game and
// leaves its lightning running, so we own the whole thing and can start/stop/recolour it.

df_tower_top()
{
    s = getstruct( "sq_common_tower_fx", "targetname" );

    if ( !isdefined( s ) )
        return undefined;

    return s.origin - ( 0, 0, 768 );
}

df_tower_fx_start( side )
{
    df_tower_fx_stop();
    clientnotify( "sq_kfx" );
    clientnotify( "sqkl" );

    level.df_tower_fx_side = side;
    level.df_tower_fx_ents = [];
    level thread df_tower_fx_lightning( side );
    level thread df_tower_fx_runners( side );
}

df_tower_fx_stop()
{
    level notify( "df_tower_fx_stop" );

    if ( isdefined( level.df_tower_fx_ents ) )
    {
        foreach ( ent in level.df_tower_fx_ents )
            df_fx_stop( ent );
    }

    level.df_tower_fx_ents = [];
    level.df_tower_fx_side = undefined;
}

df_tower_fx_stop_after( seconds )
{
    level endon( "end_game" );
    wait( seconds );
    df_tower_fx_stop();
}

df_tower_fx_lightning( side )
{
    level endon( "end_game" );
    level endon( "df_tower_fx_stop" );

    top = df_tower_top();

    if ( !isdefined( top ) )
    {
        df_debug_print( "DF: sq_common_tower_fx struct not found" );
        return;
    }

    // side "none" = lightning only (signal before a side is locked)
    if ( side != "none" )
    {
        glow = "fx_zmb_tranzit_light_glow_xsm";
        sparks = "maxis_sparks";

        if ( side == "rich" )
        {
            glow = "fx_zmb_tranzit_light_glow_xsm";
            sparks = "richtofen_sparks";
        }

        level.df_tower_fx_ents[level.df_tower_fx_ents.size] = df_fx_loop( glow, top );
        level.df_tower_fx_ents[level.df_tower_fx_ents.size] = df_fx_loop( sparks, top + ( 0, 0, 20 ) );
    }

    while ( true )
    {
        df_fx_once( "sq_common_lightning", top );
        wait( randomfloatrange( 1, 2 ) );
    }
}

df_tower_fx_runners( side )
{
    level endon( "end_game" );
    level endon( "df_tower_fx_stop" );

    if ( side == "none" )
        return;

    structs = getstructarray( "sq_common_pole_fx", "targetname" );

    if ( !isdefined( structs ) || structs.size == 0 )
    {
        df_debug_print( "DF: sq_common_pole_fx structs not found" );
        return;
    }

    fx = "maxis_sparks";

    if ( side == "rich" )
        fx = "richtofen_sparks";

    while ( true )
    {
        foreach ( struct in structs )
        {
            level thread df_tower_fx_runner( fx, struct );
            wait( randomfloatrange( 0.5, 1 ) );
        }

        wait( randomintrange( 3, 9 ) );
    }
}

df_tower_fx_runner( fx, struct )
{
    level endon( "end_game" );
    level endon( "df_tower_fx_stop" );

    ent = df_fx_loop( fx, struct.origin );

    if ( !isdefined( ent ) )
        return;

    ent thread df_tower_fx_runner_stop_watch();

    while ( isdefined( struct.target ) )
    {
        next = getstruct( struct.target, "targetname" );

        if ( !isdefined( next ) )
            break;

        struct = next;
        ent moveto( struct.origin, 1.4 );
        ent waittill( "movedone" );
    }

    if ( isdefined( ent ) )
        ent delete();
}

df_tower_fx_runner_stop_watch()
{
    self endon( "death" );
    level waittill( "df_tower_fx_stop" );

    if ( isdefined( self ) )
        self delete();
}

// ------------------------------------------------------------------ cues ----
// The unified cue grammar (art audit 2026-09-09 section 1: one alias = one meaning, in one row only):
//   STEP AVAILABLE  zmb_spawn_powerup 2D + key glint on the focus     df_steps df_step_available_cue (automatic)
//   PROGRESS TICK   zmb_buildable_piece_add 3D                        df_cue_tick( origin [, burst] )
//   SUB-GOAL DONE   zmb_sq_navcard_success 3D + side flash + trail    df_cue_subgoal( origin [, side] )
//   STEP DONE       zmb_powerup_grabbed 2D                            df_steps df_complete (automatic)
//   WRONG INPUT     zmb_perks_packa_deny to the presser               df_cue_deny( player )
//   FAIL / LOST     zmb_bus_emp_shutdown 2D + side loss fx            df_cue_fail( [origin] )
// Sounds: zmeat.gsc:2080, zm_transit_sq.gsc:1074 / :1436, _zm_perks.gsc:795, zm_transit_bus.gsc:3097
// (tools/assets/sounds_zm_transit.txt). Side fx: Richtofen and pre-fork fx_zmb_tranzit_spark_blue_lg_os
// (true one-shot, zm_transit_fx.gsc:123); Maxis fx_zmb_tranzit_fire_lrg (:100) / fx_zmb_ash_rising_md (:81),
// loops cut after 0.8 s by df_fx_burst.

// "rich" / "maxis": the side given, else the locked side, else "rich" (the electric look before the fork).
df_cue_side( side )
{
    if ( isdefined( side ) )
        return side;

    if ( isdefined( level.df_side ) )
        return level.df_side;

    return "rich";
}

// The short burst alias of a side (PROGRESS / WARNING rows): elec_md (zm_transit_fx.gsc:36) for Richtofen
// and before the fork, lava_burning (:40) for Maxis. Both are 0.5-0.8 s bursts: play them with df_fx_burst.
df_side_burst_fx( side )
{
    if ( df_cue_side( side ) == "maxis" )
        return "lava_burning";

    return "elec_md";
}

// A looping or lingering fx played for `seconds`, then its ent is deleted (the brief's rule for elec_*,
// lava_burning, fire_lrg, ash_rising). Returns at once and cleans up by itself.
df_fx_burst( fxname, origin, seconds )
{
    ent = df_fx_loop( fxname, origin );

    if ( !isdefined( ent ) )
        return;

    ent thread df_sys_fx_burst_end( seconds );
}

df_sys_fx_burst_end( seconds )
{
    self endon( "death" );
    wait( seconds );

    if ( isdefined( self ) )
        self delete();
}

// The side's success flash at a point: the blue spark (Richtofen / pre-fork), 0.8 s of fire for Maxis.
df_cue_side_flash( origin, side )
{
    if ( df_cue_side( side ) == "maxis" )
    {
        df_fx_burst( "fx_zmb_tranzit_fire_lrg", origin, 0.8 );
        return;
    }

    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", origin );
}

// PROGRESS TICK: one soul counted, one charge, one part, one click. To every player within 700 of origin, at the
// listener: the alias is 3D with a 150 unit range, so played at a lamp it never reached a player killing at 450
// (sound audit 2026-09-09). burst 1 adds the side's 0.6 s spark / lava puff there (leave it off for ticks that
// fire several times a second).
df_cue_tick( origin, burst )
{
    df_snd_near( "zmb_buildable_piece_add", origin, 700 );

    if ( is_true( burst ) )
        df_fx_burst( df_side_burst_fx( undefined ), origin, 0.6 );
}

// SUB-GOAL DONE: one node finished (lamp filled, brazier full, lamp anchored, node drained, Simon solved,
// card accepted). The chime to every player (team information; the alias is 3D with a 175 unit range, so at the
// node it was heard by nobody), side flash at origin, then the canon trail node -> tower top.
df_cue_subgoal( origin, side )
{
    foreach ( player in getplayers() )
        player playsoundtoplayer( "zmb_sq_navcard_success", player );

    df_cue_side_flash( origin, side );
    level thread df_node_done_trail( origin, side );
}

// FAIL / PROGRESS LOST: the EMP thump to everyone, plus the side's loss fx where it was lost (origin
// optional): the blue spark, or 0.8 s of rising ash for Maxis.
df_cue_fail( origin )
{
    foreach ( player in getplayers() )
        player playsoundtoplayer( "zmb_bus_emp_shutdown", player );

    if ( !isdefined( origin ) )
        return;

    if ( df_cue_side( undefined ) == "maxis" )
    {
        df_fx_burst( "fx_zmb_ash_rising_md", origin, 0.8 );
        return;
    }

    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", origin );
}

// WRONG INPUT: the purchase refusal (zmb_no_cha_ching, the 0.2 s buzz every zombies player knows; the previous
// zmb_perks_packa_deny is a dull 1 s clunk at volume 68, owner 2026-09-09 "not a buzz"), to the one player who
// pressed (nobody else needs to hear it).
df_cue_deny( player )
{
    if ( !isdefined( player ) || !isplayer( player ) )
        return;

    player playsoundtoplayer( "zmb_sq_navcard_fail", player ); // owner pick 2026-09-11 (Sound Picker)
}

// Canon "node done" trail (zm_transit_classic.csc:112-155 sidequest_complete_fx_triangle_runner): ONE
// richtofen_sparks / maxis_sparks runner spawned 140 above `from`, dips to +100 in 1.4 s, then flies to the
// tower top (df_tower_top) in 1.4 s and vanishes: the far cue every TranZit player knows. side undefined =
// the locked side ("rich" before the fork). Thread it: it lasts 2.8 s.
df_node_done_trail( from, side )
{
    level endon( "end_game" );

    top = df_tower_top();

    if ( !isdefined( top ) )
        return;

    fx = "richtofen_sparks";

    if ( df_cue_side( side ) == "maxis" )
        fx = "maxis_sparks";

    ent = df_fx_loop( fx, from + ( 0, 0, 140 ) );

    if ( !isdefined( ent ) )
        return;

    ent moveto( from + ( 0, 0, 100 ), 1.4 );
    ent waittill( "movedone" );
    ent moveto( top, 1.4 );
    ent waittill( "movedone" );
    df_fx_stop( ent );
}

// ------------------------------------------------------------ triggers ----

// A use trigger: fires "trigger", who when a player presses use inside it. hint "" = no prompt.
df_spawn_use_trigger( origin, radius, height, hint )
{
    trig = spawn( "trigger_radius_use", origin, 0, radius, height );
    trig setcursorhint( "HINT_NOICON" );
    trig sethintstring( hint );
    trig triggerignoreteam();
    return trig;
}

// ---------------------------------------------------------- part icons ----
// Team-wide "parts collected" icons, bottom-right (spec 5.2). level.df_part_icons[slot] = shader.

// One "carrying" icon per player, bottom-right above the part icons. show 0 clears it.
df_carry_icon( show, shader, size )
{
    if ( isdefined( self.df_carry_icon ) )
        self.df_carry_icon destroy();

    self.df_carry_icon = undefined;

    if ( !show )
        return;

    if ( !isdefined( size ) )
        size = 48;

    hud = newclienthudelem( self );
    hud.alignx = "right";
    hud.aligny = "bottom";
    hud.horzalign = "user_right";
    hud.vertalign = "user_bottom";
    hud.x = -10;
    hud.y = -160;
    hud.alpha = 0.9;
    hud.foreground = 1;
    hud.hidewheninmenu = 1;
    hud setshader( shader, size, size );
    self.df_carry_icon = hud;
}

df_part_icons_refresh()
{
    if ( isdefined( self.df_part_huds ) )
    {
        foreach ( h in self.df_part_huds )
        {
            if ( isdefined( h ) )
                h destroy();
        }
    }

    self.df_part_huds = [];

    if ( !isdefined( level.df_part_icons ) )
        return;

    n = 0;

    foreach ( shader in level.df_part_icons )
    {
        hud = newclienthudelem( self );
        hud.alignx = "right";
        hud.aligny = "bottom";
        hud.horzalign = "user_right";
        hud.vertalign = "user_bottom";
        hud.x = -10 - n * 40;
        hud.y = -110;
        hud.alpha = 0.85;
        hud.foreground = 1;
        hud.hidewheninmenu = 1;
        hud setshader( shader, 32, 32 );
        self.df_part_huds[self.df_part_huds.size] = hud;
        n++;
    }
}

// Every player gets a spawn watcher (icons on respawn) and a disconnect cleaner. Players already in
// the game when df_boot runs never fire "connected" again, so they are threaded here directly.
df_hud_connect_watcher()
{
    level endon( "end_game" );

    foreach ( player in getplayers() )
        player thread df_hud_player_watchers();

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread df_hud_player_watchers();
    }
}

df_hud_player_watchers()
{
    if ( is_true( self.df_sys_watched ) )
        return;

    self.df_sys_watched = 1;
    self thread df_hud_spawn_watcher();
    self thread df_sys_hud_disconnect_watch();
}

df_hud_spawn_watcher()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "spawned_player" );
        self df_part_icons_refresh();
    }
}

// Client hud elems are not freed with the client: destroy every elem we own on disconnect, as vanilla
// does for its revive text (_zm_laststand.gsc:334 laststand_clean_up_on_disconnect).
df_sys_hud_disconnect_watch()
{
    self waittill( "disconnect" );

    if ( !isdefined( self ) )
        return;

    self df_sys_line_clear();
    self df_prompt( 0, undefined );
    self df_prompt_puzzle( 0, undefined );
    self df_carry_icon( 0, undefined, undefined );

    if ( isdefined( self.df_part_huds ) )
    {
        foreach ( h in self.df_part_huds )
        {
            if ( isdefined( h ) )
                h destroy();
        }
    }

    self.df_part_huds = [];

    if ( isdefined( self.df_sys_bars ) )
    {
        foreach ( bar in self.df_sys_bars )
        {
            if ( isdefined( bar ) )
                df_bar_destroy( bar );
        }
    }

    self.df_sys_bars = [];
}

// --------------------------------------------------------------- prompt ----

// Our own bottom-centre prompt for MECHANIC interactions that cannot use a trigger hint (moving
// targets: take/place the orb, build, plug). self = player. df_prompt( 1, "text" ) shows it (a second
// show while one is up is ignored: callers poll), df_prompt( 0 ) removes it. Field: self.df_prompt_hud.
df_prompt( show, text )
{
    if ( show )
    {
        if ( isdefined( self.df_prompt_hud ) )
            return;

        hud = self df_sys_text_elem( -78, 1.3, ( 1, 1, 1 ) );
        hud settext( text );
        self.df_prompt_hud = hud;
        return;
    }

    if ( isdefined( self.df_prompt_hud ) )
        self.df_prompt_hud destroy();

    self.df_prompt_hud = undefined;
}

// Same as df_prompt, for PUZZLE objects that only need a look (Simon boxes, TVs, phones, lamps):
// hidden entirely while level.df_hints == 0 (`!df hints off`). Own slot (self.df_prompt_puzzle_hud),
// same screen position as df_prompt: keep the two apart in space (puzzle props vs carried objects).
// Semantics: show 1 = create once (ignored while one is up or hints are off), show 0 = destroy.
df_prompt_puzzle( show, text )
{
    if ( show && df_hints_on() )
    {
        if ( isdefined( self.df_prompt_puzzle_hud ) )
            return;

        hud = self df_sys_text_elem( -78, 1.3, ( 0.9, 0.9, 0.9 ) );
        hud settext( text );
        self.df_prompt_puzzle_hud = hud;
        return;
    }

    if ( isdefined( self.df_prompt_puzzle_hud ) )
        self.df_prompt_puzzle_hud destroy();

    self.df_prompt_puzzle_hud = undefined;
}

// level.df_hints: the on-screen PUZZLE PROMPTS only (df_prompt_puzzle). 0 = hidden (df_main default,
// vanilla feel), 1 or undefined = shown. Since the dialogue audit v2 (2026-09-09, section 1.0) it no longer
// gates the spoken ladder: that is level.df_text_hints below.
df_hints_on()
{
    return !isdefined( level.df_hints ) || level.df_hints != 0;
}

// `!df hints on|off`: sets level.df_hints; off also removes every puzzle prompt currently on screen.
df_hints_set( on )
{
    if ( on )
    {
        level.df_hints = 1;
        return;
    }

    level.df_hints = 0;

    foreach ( player in getplayers() )
        player df_prompt_puzzle( 0, undefined );
}

// level.df_text_hints: the DIALOGUE ladder (df_steps df_step_stall_watcher HINT_1 / HINT_2 and the
// df_hint_now event hints). 1 or undefined = spoken (default), 0 = muted (`!df texthints off`). START, FAIL
// and DONE lines are story beats and play whatever this says.
df_text_hints_on()
{
    return !isdefined( level.df_text_hints ) || level.df_text_hints != 0;
}

// `!df texthints on|off`: sets level.df_text_hints. The ladder clocks keep running while muted.
df_text_hints_set( on )
{
    level.df_text_hints = 0;

    if ( on )
        level.df_text_hints = 1;
}

// ----------------------------------------------------------- single press ----

// self = player. True exactly once per press of the use key (edge: the key was up on the previous
// call and is down now), and never twice within 0.3 s, so one press cannot pick up AND place, and a
// held key does not repeat. State per player: self.df_press_use_down (key state seen by the last
// call), self.df_press_use_last (ms of the last accepted press). Poll it every 0.05 s while the player
// is IN RANGE of your object; a call consumes the edge, so do not poll it for players who cannot use
// the object (another monitor's press would be eaten). Pickups/placements only; holds use df_hold_use.
df_press_use()
{
    pressed = self usebuttonpressed();
    was_down = is_true( self.df_press_use_down );
    self.df_press_use_down = pressed;

    if ( !pressed || was_down )
        return 0;

    if ( !isdefined( self.df_press_use_last ) )
        self.df_press_use_last = 0;

    if ( gettime() - self.df_press_use_last < 300 )
        return 0;

    self.df_press_use_last = gettime();
    return 1;
}

// ------------------------------------------------------------ hold use ----

// self = player. Returns 1 when use was held for `seconds` while within `radius` of `origin`.
// No endon("disconnect") here: endon binds the CALLING thread (a level watcher such as df_part_watch)
// to this player for the rest of its life. is_player_valid() returns 0 as soon as the player is gone
// or downed, which ends the loop instead.
df_hold_use( origin, radius, seconds, label )
{
    bar = self df_bar_create( label );
    start = gettime();
    total = seconds * 1000;
    ok = 0;

    while ( true )
    {
        if ( !is_player_valid( self ) || !self usebuttonpressed() || distancesquared( self.origin, origin ) > radius * radius )
            break;

        frac = ( gettime() - start ) / total;
        df_bar_update( bar, frac );

        if ( gettime() - start >= total )
        {
            ok = 1;
            break;
        }

        wait 0.05;
    }

    df_bar_destroy( bar );
    return ok;
}

// Progress bar for self (player): 200x8 "white" shader bar (material as vanilla's revive bar,
// _zm_laststand.gsc:504) at y -48 with an optional label above it. Registered in self.df_sys_bars so
// the disconnect watcher can destroy it; df_bar_destroy unregisters. Returns the bar struct.
df_bar_create( label )
{
    bar = spawnstruct();
    bar.width = 200;
    bar.owner = self;

    bar.bg = self df_sys_bar_elem( ( 0.1, 0.1, 0.1 ), 0.6, bar.width );
    bar.fill = self df_sys_bar_elem( ( 0.9, 0.9, 0.9 ), 0.9, 1 );

    if ( isdefined( label ) )
    {
        bar.text = self df_sys_text_elem( -56, 1.2, ( 1, 1, 1 ) );
        bar.text settext( label );
    }

    if ( !isdefined( self.df_sys_bar_seq ) )
        self.df_sys_bar_seq = 0;

    if ( !isdefined( self.df_sys_bars ) )
        self.df_sys_bars = [];

    self.df_sys_bar_seq++;
    bar.id = "b" + self.df_sys_bar_seq;
    self.df_sys_bars[bar.id] = bar;
    return bar;
}

// One layer of the bar (background or fill), left-anchored so the fill grows to the right.
df_sys_bar_elem( color, alpha, width )
{
    hud = newclienthudelem( self );
    hud.alignx = "left";
    hud.aligny = "middle";
    hud.horzalign = "user_center";
    hud.vertalign = "user_bottom";
    hud.x = -100;
    hud.y = -48;
    hud.color = color;
    hud.alpha = alpha;
    hud.foreground = 1;
    hud.hidewheninmenu = 1;
    hud setshader( "white", width, 8 );
    return hud;
}

df_bar_update( bar, frac )
{
    if ( frac < 0 )
        frac = 0;

    if ( frac > 1 )
        frac = 1;

    w = int( bar.width * frac );

    if ( w < 1 )
        w = 1;

    bar.fill setshader( "white", w, 8 );
}

// Destroys the three elems and unregisters the bar from its owner (safe to call twice or after the
// owner left; any caller, self need not be the player).
df_bar_destroy( bar )
{
    if ( !isdefined( bar ) )
        return;

    if ( isdefined( bar.bg ) )
        bar.bg destroy();

    if ( isdefined( bar.fill ) )
        bar.fill destroy();

    if ( isdefined( bar.text ) )
        bar.text destroy();

    if ( isdefined( bar.owner ) && isdefined( bar.id ) && isdefined( bar.owner.df_sys_bars ) )
        bar.owner.df_sys_bars[bar.id] = undefined;
}

// ----------------------------------------------------------------- souls ----
// A "soul" flying from a dead zombie into a collector: TranZit has no soul effect of its own, so the
// glowing trail vanilla uses for the tower runners (richtofen_sparks) travels the path, with a wire
// spark burst and the vanilla soul sound on arrival.
df_soul_fly( from, to )
{
    level endon( "end_game" );

    // a fresh entity that settles 0.15 s before it flies (the client needs a snapshot to see it: trails spawned and
    // moved on the same frame were sometimes never seen). No pool: a parked entity's teleport drew a streak down
    // the post (owner 2026-09-11: "zombie, top of the lamp, bottom of the post").
    ent = df_fx_loop( "richtofen_sparks", from + ( 0, 0, 40 ) );

    if ( !isdefined( ent ) )
        return;

    wait 0.15;

    dist = distance( from, to );
    time = dist / 700;

    if ( time < 0.4 )
        time = 0.4;

    if ( time > 1.5 )
        time = 1.5;

    ent moveto( to, time );
    wait( time );
    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", to );
    df_snd_near( "evt_electrical_surge", to, 600 ); // zmb_souls_end is a Buried alias, silent in TranZit
    df_fx_stop( ent );
}

// ---- keepalive ----
// A looping effect on a still entity is dropped by the client after a while (owner 2026-09-11: the lit pipes went
// inert, the fx grid emptied). Nudging the entity half a unit every 5 s keeps it updated and its effect alive.
// Only for entities that are never linked (a linked entity must not have its origin set).
df_fx_keepalive( ent )
{
    level endon( "end_game" );
    up = 1;

    while ( isdefined( ent ) )
    {
        wait 5;

        if ( !isdefined( ent ) )
            return;

        if ( up )
            ent.origin = ent.origin + ( 0, 0, 0.5 );
        else
            ent.origin = ent.origin - ( 0, 0, 0.5 );

        up = !up;
    }
}

// ---- item arrival ----
// Every quest item that appears in the world (coil, key card, spool, skull) arrives the same way: the black-hole
// burst (grenade_samantha_steal, owner pick 2026-09-11), the Avogadro thunder, a short quake.
df_item_arrival( pos )
{
    df_fx_once( "grenade_samantha_steal", pos + ( 0, 0, 20 ) );
    playsoundatposition( "zmb_avogadro_spawn_3d", pos );
    earthquake( 0.3, 0.6, pos, 800 );
}

// --------------------------------------------------------- zombie deaths ----
// One vanilla death callback (self = the dying zombie) fans out to whoever is listening.

df_death_dispatch_init()
{
    if ( is_true( level.df_death_dispatch_ready ) )
        return;

    level.df_death_dispatch_ready = 1;
    level.df_death_listeners = [];
    maps\mp\zombies\_zm_spawner::register_zombie_death_event_callback( ::df_zombie_death_event );
}

df_zombie_death_event()
{
    if ( !isdefined( level.df_death_listeners ) )
        return;

    foreach ( func in level.df_death_listeners )
    {
        // a listener may remove itself (or another) while we iterate the key snapshot
        if ( isdefined( func ) )
            [[ func ]]( self );
    }
}

// Listeners are keyed by name (function pointers cannot be compared in T6 GSC).
df_death_listen_add( key, func )
{
    df_death_dispatch_init();
    level.df_death_listeners[key] = func;
}

df_death_listen_remove( key )
{
    if ( !isdefined( level.df_death_listeners ) )
        return;

    level.df_death_listeners[key] = undefined;
}

// ---------------------------------------------------------------- stats ----

// Mirrors vanilla update_sidequest_stats("sq_transit_rich_complete"/"sq_transit_maxis_complete").
// Makes the world-map globe glow. Only call from the finale or the explicit debug command.
df_write_completion_stat( side )
{
    if ( side == "rich" )
    {
        value = 1;
        stat = "sq_transit_rich_complete";
        counter = "global_zm_total_rich_sq_complete_transit";
    }
    else
    {
        value = 2;
        stat = "sq_transit_maxis_complete";
        counter = "global_zm_total_max_sq_complete_transit";
    }

    foreach ( player in getplayers() )
    {
        player maps\mp\zombies\_zm_stats::set_global_stat( "sq_transit_last_completed", value );
        incrementcounter( counter, 1 );
        player maps\mp\zombies\_zm_stats::increment_client_stat( stat, 0 );
    }

    level notify( "transit_sidequest_achieved" );
}

// Clears the globe stat (0 = neither side completed). Debug use only.
df_reset_completion_stat()
{
    foreach ( player in getplayers() )
        player maps\mp\zombies\_zm_stats::set_global_stat( "sq_transit_last_completed", 0 );
}

// =========================================================================================
// audible countdown (owner 2026-09-09: no timers on screen)
// =========================================================================================

// A soft tick to every player every 5 s, every second under 30 s, doubled under 10 s, until end_ms or any of
// the notifies. zmb_tombstone_timer_count is the vanilla tombstone countdown tick (_zm_tombstone.gsc:380).
// The old on-screen timers still exist behind `set df_hud_timers 1` for testing.
df_sys_clock_run( end_ms, n1, n2, n3 )
{
    level endon( "end_game" );

    if ( isdefined( n1 ) )
        level endon( n1 );

    if ( isdefined( n2 ) )
        level endon( n2 );

    if ( isdefined( n3 ) )
        level endon( n3 );

    // owner pick 2026-09-11: the clock IS the Pack-a-Punch tick-tock loop, one on every player, for the whole
    // countdown; the dry tombstone ticks below stay for the last 30 s (urgency).
    level thread df_sys_clock_loop( end_ms, n1, n2, n3 );
    last = -1;

    while ( gettime() < end_ms )
    {
        remaining = int( ( end_ms - gettime() ) / 1000 );

        if ( remaining > 30 )
        {
            wait 0.1;
            continue;
        }

        if ( remaining != last )
        {
            last = remaining;

            if ( remaining <= 30 || remaining % 5 == 0 )
                level thread df_sys_clock_tick( remaining <= 10 );
        }

        wait 0.1;
    }
}

// The tick-tock loop (zmb_perks_packa_ticktock, 3D 25-175, so one script_origin rides each player) until end_ms
// or any of the notifies, then the ents go.
df_sys_clock_loop( end_ms, n1, n2, n3 )
{
    ents = [];

    foreach ( player in getplayers() )
    {
        e = spawn( "script_origin", player.origin );
        e linkto( player );
        e playloopsound( "zmb_perks_packa_ticktock" );
        ents[ents.size] = e;
    }

    secs = ( end_ms - gettime() ) / 1000;

    if ( secs > 0 )
        level waittill_any_timeout( secs, n1, n2, n3 );

    foreach ( e in ents )
    {
        if ( isdefined( e ) )
            e delete();
    }
}

// A looping alias as a short burst: a script_origin plays it at origin and dies after `seconds` (owner picks of
// 2026-09-11 use loop aliases for one-shot moments, e.g. zmb_fire_loop as the hot-air puff).
df_snd_loop_burst( alias, origin, seconds )
{
    e = spawn( "script_origin", origin );
    e playloopsound( alias );
    e thread df_sys_fx_burst_end( seconds );
}

df_sys_clock_tick( urgent )
{
    level endon( "end_game" );

    foreach ( player in getplayers() )
        player playsoundtoplayer( "zmb_tombstone_timer_count", player );

    if ( !urgent )
        return;

    wait 0.12;

    foreach ( player in getplayers() )
        player playsoundtoplayer( "zmb_tombstone_timer_count", player );
}

// True when the owner asked for the on-screen timers back (console `set df_hud_timers 1`).
df_sys_hud_timers()
{
    return getdvar( "df_hud_timers" ) == "1";
}

// ---- fists ----
// The Galvaknuckles are tazer_knuckles_zm (zm_transit.gsc). One melee press edge per player: true on the frame the
// melee button goes down (df_melee_edge, one consumer at a time: the steps that read it never overlap).
df_melee_edge( player )
{
    down = player meleebuttonpressed();
    was = is_true( player.df_melee_was );
    player.df_melee_was = down;
    return down && !was;
}

// The Galvaknuckles replace the knife, so the current weapon stays the gun (owner 2026-09-11: "hit lamp without the
// knuckles (mp5k_upgraded_zm)"): the inventory is what tells.
df_has_knuckles( player )
{
    return player hasweapon( "tazer_knuckles_zm" );
}

// The electric punch on a post at pos: blue one-shot spark at the bulb, wire spark burst at chest height, the arc.
df_punch_fx( pos, bulb )
{
    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", bulb );
    df_fx_once( "switch_sparks", pos + ( 0, 0, 50 ) );
    playsoundatposition( "zmb_zombie_arc", pos );
}

// Living zombies within radius of pos (the local pressure a spawner should respect, not the map-wide count).
df_zombies_near( pos, radius )
{
    n = 0;
    r2 = radius * radius;

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( isdefined( ai ) && isalive( ai ) && distancesquared( ai.origin, pos ) < r2 )
            n++;
    }

    return n;
}

// Zone spawn structs within radius of pos; when none (the fog lamps and the graves sit between zones), the six
// nearest of the whole map. Enabled zones only.
df_spawn_spots_near( pos, radius )
{
    spots = [];
    all = [];

    if ( !isdefined( level.zones ) )
        return spots;

    foreach ( key in getarraykeys( level.zones ) )
    {
        zone = level.zones[key];

        if ( !isdefined( zone.spawn_locations ) )
            continue;

        foreach ( s in zone.spawn_locations )
        {
            if ( isdefined( s.is_enabled ) && !s.is_enabled )
                continue;

            all[all.size] = s;

            if ( distancesquared( s.origin, pos ) < radius * radius )
                spots[spots.size] = s;
        }
    }

    if ( spots.size > 0 )
        return spots;

    // the six nearest (no array_remove: T6 has no such helper, it failed at load 2026-09-11)
    taken = [];

    for ( k = 0; k < 6 && k < all.size; k++ )
    {
        best = -1;

        for ( i = 0; i < all.size; i++ )
        {
            if ( is_true( taken[i] ) )
                continue;

            if ( best < 0 || distancesquared( all[i].origin, pos ) < distancesquared( all[best].origin, pos ) )
                best = i;
        }

        if ( best < 0 )
            break;

        taken[best] = 1;
        spots[spots.size] = all[best];
    }

    return spots;
}
