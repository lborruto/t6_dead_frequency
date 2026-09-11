// Dead Frequency - live placement mode ("!df grab <KEY>"), 2026-09-08.
//   The anchor's prop is held at the point under your crosshair and follows it: you walk, look, rotate and lift
//   it, then place it. Replaces guessing a height from `!pos`, which reports the floor under your feet and made
//   props float above benches and tables (the vanilla-style fix in zm_transit_enhanced_noee is a hand-tuned
//   per-stop lift; this measures it instead).
//
// Controls while holding (every check is a builtin the stock scripts use: attackbuttonpressed
// Core/maps/mp/gametypes_zm/_gameobjects.gsc, adsbuttonpressed Core/maps/mp/zombies/_zm.gsc,
// meleebuttonpressed Core/maps/mp/animscripts/zm_dog_combat.gsc, usebuttonpressed, jumpbuttonpressed /
// sprintbuttonpressed Maps/Mob of the Dead/maps/mp/zm_prison_sq_fc.gsc, actionslot*buttonpressed
// Maps/Buried/maps/mp/zombies/_zm_ai_sloth.gsc):
//   fire / attack (mouse1, left click by default)   place it here and pin the anchor
//   melee (V by default; whatever key you have bound to melee)   cancel, leave the anchor as it was
//   ADS (right mouse)  hold to freeze the prop where it is (look around without moving it)
//   1 / 2 (slots 1/2)  turn left / right (15 deg, 5 with sprint held)
//   3 / 4 (slots 3/4)  lower / raise (4 units, 1 with sprint held)
//   use (F)            switch between "on the surface I aim at" and "floating 60 units in front of me"
//   jump (space)       face me again / reset the lift
//   chat fallback      !df drop (place), !df cancel (leave it as it was), !df rot <deg>, !df up <units>
//
// A place writes df_coord_override( key, origin, angles ) (df_coords.gsc), the same call df_apply_overrides uses,
// and prints the paste-ready line so it can be made permanent in the sources.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_coords;

df_place_yaw_step()
{
    return 15;
}

df_place_lift_step()
{
    return 4;
}

// How far in front of the eye a "floating" prop sits when surface snapping is off.
df_place_float_dist()
{
    return 60;
}

// self = player. Starts holding `key`. A second grab replaces the first.
df_place_grab( key )
{
    if ( !isdefined( df_coord( key ) ) )
    {
        self df_out( "DF: unknown anchor " + key + " (!df dump lists them all)" );
        return;
    }

    self df_place_end_current( "replaced" );
    df_preview_hide(); // the !df show copy of this anchor would sit inside the held prop

    c = df_coord( key );
    model = c.model;

    if ( !isdefined( model ) )
        model = df_model( "beacon" ); // anchors without a prop (spawn points) still need something visible

    ent = spawn( "script_model", c.origin );
    ent setmodel( model );
    ent.angles = c.angles;

    self.df_place_key = key;
    self.df_place_ent = ent;
    self.df_place_model = model;
    self.df_place_yaw = 0;      // extra turn on top of "face me"
    self.df_place_lift = 0;     // extra height above the surface
    self.df_place_snap = 1;     // 1 = on the aimed surface, 0 = floating in front of me
    self.df_place_start_org = c.origin;
    self.df_place_start_ang = c.angles;
    self.df_place_frozen = 0;

    self thread df_place_think();
    self df_out( "DF: holding " + key + " (" + model + "). FIRE = place, MELEE = cancel, ADS = freeze, 1/2 turn, 3/4 raise, F = surface/float, space = reset, !df drop / !df cancel" );
    df_debug_print( "DF: place mode on for " + key + " (" + model + ")" );
}

// self = player. The hold loop: follow the crosshair and read the buttons.
df_place_think()
{
    self endon( "disconnect" );
    self endon( "df_place_end" );
    level endon( "end_game" );

    last = 0;

    while ( isdefined( self.df_place_ent ) )
    {
        wait 0.05;

        if ( !isdefined( self.df_place_ent ) )
            return;

        self.df_place_frozen = self adsbuttonpressed();

        if ( !self.df_place_frozen )
            self df_place_follow();

        if ( gettime() - last > 200 )
        {
            last = gettime();
            self df_place_hud();
        }

        if ( self attackbuttonpressed() )
        {
            self df_place_drop();
            return;
        }

        if ( self meleebuttonpressed() )
        {
            self df_place_cancel();
            return;
        }

        self df_place_buttons();
    }
}

// self = player. Moves the held prop under the crosshair (or in front of the eye when snapping is off).
df_place_follow()
{
    eye = self geteye();
    forward = anglestoforward( self getplayerangles() );
    yaw = self.angles[1] + 180 + self.df_place_yaw;
    pos = eye + forward * df_place_float_dist();

    if ( self.df_place_snap )
    {
        trace = bullettrace( eye, eye + forward * 2500, 0, self );
        pos = trace["position"];
        normal = ( 0, 0, 1 );

        if ( isdefined( trace["normal"] ) )
            normal = trace["normal"];

        // a wall or a fence: stand the prop against it, front pointing out of the surface
        if ( normal[2] < 0.35 && normal[2] > -0.35 )
        {
            pos = pos + normal * 2;
            yaw = vectortoangles( normal )[1] + self.df_place_yaw;
        }
    }

    self.df_place_ent.origin = pos + ( 0, 0, self.df_place_lift );
    self.df_place_ent.angles = ( self.df_place_start_ang[0], yaw, self.df_place_start_ang[2] );
}

// self = player. Turn, raise, snap mode, reset. Sprint held = fine steps.
df_place_buttons()
{
    yaw_step = df_place_yaw_step();
    lift_step = df_place_lift_step();

    if ( self sprintbuttonpressed() )
    {
        yaw_step = 5;
        lift_step = 1;
    }

    if ( self actionslotonebuttonpressed() )
        self.df_place_yaw -= yaw_step;

    if ( self actionslottwobuttonpressed() )
        self.df_place_yaw += yaw_step;

    if ( self actionslotthreebuttonpressed() )
        self.df_place_lift -= lift_step;

    if ( self actionslotfourbuttonpressed() )
        self.df_place_lift += lift_step;

    if ( self usebuttonpressed() )
    {
        self.df_place_snap = !self.df_place_snap;
        self df_out( "DF: " + df_place_mode_text( self.df_place_snap ) );
        wait 0.3; // one press, not a stream
    }

    if ( self jumpbuttonpressed() )
    {
        self.df_place_yaw = 0;
        self.df_place_lift = 0;
    }
}

df_place_mode_text( snap )
{
    if ( snap )
        return "on the surface I aim at";

    return "floating " + df_place_float_dist() + " units in front of me";
}

// self = player. Live read-out at the bottom of the screen.
df_place_hud()
{
    if ( !isdefined( self.df_place_ent ) )
        return;

    o = self.df_place_ent.origin;
    text = self.df_place_key + "  " + int( o[0] ) + " " + int( o[1] ) + " " + int( o[2] ) + "  yaw " + int( self.df_place_ent.angles[1] ) + "  lift " + int( self.df_place_lift );

    if ( self.df_place_frozen )
        text += "  [frozen]";

    self df_prompt( 1, text );
}

// self = player. Pins the anchor where the prop stands and prints the line for the sources.
df_place_drop()
{
    if ( !isdefined( self.df_place_ent ) )
    {
        self df_out( "DF: nothing held (!df grab <KEY> first)" );
        return;
    }

    key = self.df_place_key;
    model = self.df_place_model;
    origin = self.df_place_ent.origin;
    angles = self.df_place_ent.angles;
    df_coord_override( key, origin, angles );
    self df_place_end_current( "placed" );

    // the held copy is gone, so put the anchors own prop back: without this the model just vanishes on a
    // place and there is nothing to judge (owner report 2026-09-08)
    df_preview_refresh( key );

    // df_out, not df_debug_print: the paste-ready line must reach the console whatever df_debug is set to
    self df_out( "[SPOT] " + key + " | " + int( origin[0] ) + " " + int( origin[1] ) + " " + int( origin[2] ) + " | " + int( angles[0] ) + " " + int( angles[1] ) + " " + int( angles[2] ) + " | " + model );
    self df_out( "df_coord_override( \"" + key + "\", ( " + int( origin[0] ) + ", " + int( origin[1] ) + ", " + int( origin[2] ) + " ), ( " + int( angles[0] ) + ", " + int( angles[1] ) + ", " + int( angles[2] ) + " ) );" );
    playsoundatposition( "zmb_buildable_piece_add", origin );
    df_fx_once( "fx_zmb_tranzit_spark_blue_lg_os", origin + ( 0, 0, 8 ) );
}

// self = player. Leaves the anchor exactly as it was.
df_place_cancel()
{
    if ( !isdefined( self.df_place_ent ) )
    {
        self df_out( "DF: nothing held" );
        return;
    }

    key = self.df_place_key;
    self df_place_end_current( "cancelled" );
    self df_out( "DF: " + key + " left where it was" );
}

// self = player. Removes the held prop and the read-out. `why` only goes to the console.
df_place_end_current( why )
{
    if ( !isdefined( self.df_place_ent ) )
        return;

    key = self.df_place_key;
    self.df_place_ent delete();
    self.df_place_ent = undefined;
    self.df_place_key = undefined;
    self df_prompt( 0, undefined );
    self notify( "df_place_end" );
    df_debug_print( "DF: place mode off (" + key + ", " + why + ")" );
}

// self = player. "!df rot <deg>" and "!df up <units>" for people who prefer typing.
df_place_rot( deg )
{
    if ( !isdefined( self.df_place_ent ) )
    {
        self df_out( "DF: nothing held (!df grab <KEY> first)" );
        return;
    }

    self.df_place_yaw += deg;
    self df_place_hud();
    self df_out( "DF: turn " + int( self.df_place_yaw ) + " deg" );
}

df_place_up( units )
{
    if ( !isdefined( self.df_place_ent ) )
    {
        self df_out( "DF: nothing held (!df grab <KEY> first)" );
        return;
    }

    self.df_place_lift += units;
    self df_place_hud();
    self df_out( "DF: lift " + int( self.df_place_lift ) + " units" );
}
