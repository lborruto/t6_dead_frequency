// Dead Frequency - shared lamp set and lamp looks (owner feedback 2026-09-08, "lamps" agent).
//   ONE set of N = df_scaled( "nodes" ) fog lamp posts per game (level.df_lamps), picked once and reused by
//   every step: R2 fills THESE lamps with souls, Step 5 tunes exactly THESE lamps (its penalty refills them),
//   Step 6 drains them on the Richtofen side. Owner rule 2026-09-08 ("everything physical exists from game
//   start"): the set is picked at BOOT (df_lamps_init, called by the act inits from df_boot) and every set lamp
//   carries a faint idle marker from round 1 (one short burst at the bulb every 6 s, no colour,
//   df_lamp_idle_marker) so players can find them before R2 / Step 5; the quest states then take over.
//   FX FAMILY PER SIDE (owner 2026-09-09, "some lamps have a fire effect, others the electric effect"):
//   every lamp burst (idle marker, spark replays, Step 5's anchor / penalty bursts) comes from
//   df_lamp_burst_fx(): elec_md (electric) on Richtofen or before a side is locked, lava_burning (fire) on
//   Maxis, so a Maxis game is all fire and a Richtofen game all electricity.
//   df_lamp_set_get() always returns the same array; "!df goto" setups reuse it.
//   SET RULE (steps audit v2 #10, 2026-09-09): the pick skips the lamps of df_lamp_pick_exclude_names() ("diner",
//   "townbridge": on the Richtofen side a denizen tends to jump off the head on the way there, so a Step 5
//   anchor can be impossible at those two). The side is never known at boot, so the rule is simply "pick from
//   the six lamps that are valid on BOTH sides"; only a pick made after a Maxis lock (never in a normal game)
//   ignores the list.
//   One exclusive look per state, every fx / sound of the previous state removed first
//   (df_lamp_state_set): off, souls, filled, tuning, waiting, anchored, charged, drained, final.
//   ALL EIGHT lamps (finale / Act 2 reward, audit #8 and 2.4): df_lamp_colour_all( side ) puts every safety
//   light in state "final" (steady side colour, the same exploder logic + re-fire) and
//   df_lamp_power_silent_all( on ) sets the server power flag on all of them (portals and burrows without a
//   turbine). Non-set lamps get a lamp struct on first use (df_lamp_all_get, level.df_lamps_all); the keeper
//   then covers them too.
//   Every fx sits at the real BULB (df_lamp_bulb_pos): the position of the map's own blue-lamp exploder
//   (createfx/zm_transit_fx.gsc:3786-3875, fx_zmb_tranzit_light_safety_ric, 140-161 units above each
//   screecher_escape struct), found at runtime in level.createfxent; fallback struct origin + 148.
//   No green under our light: the vanilla client lights a powered lamp green through the clientfield
//   "screecher_light_<name>" (zm_transit.csc:650 safety_light_callback -> power_controlled_or_turbine);
//   while a set lamp carries our light its clientfield is held at 0 (df_lamp_keeper) and the SERVER flag
//   light.power_on (the only thing a denizen burrow checks, zm_transit_ai_screecher.gsc:55) is kept on
//   silently for Step 5 (df_lamp_power_silent) - no forced green, anchors still possible.
//   Colours (fixed 2026-09-08 after the owner still saw no blue): the vanilla quest does NOT colour a lamp with
//   a server fx. Each lamp has four client EXPLODERS (zm_transit.csc power_controlled_lights: on 100+2i green,
//   off 101+2i dark, off_sq 400+2i = fx_zmb_tranzit_light_safety_max ORANGE, on_sq 401+2i =
//   fx_zmb_tranzit_light_safety_ric BLUE; i = busdepot, diner, forest, cornfield, powerstation, huntershack,
//   townbridge, bridgedepot), switched client-side by power_controlled_or_turbine. So the side light here is the
//   map's own exploder fired from the server (Core _utility.gsc:93 exploder -> activateclientexploder, the call
//   zm_transit.gsc:2805 uses for the bus), re-fired after every vanilla power transition. The old claim that
//   fx_zmb_tranzit_light_safety_ric is blue when played server-side was wrong in game.
//   (zm_transit.csc:837 activate_exploder( on_sq ) = the _ric exploders), _max is the Maxis orange.
// Shared helpers relied on: df_fx_loop / df_fx_once / df_fx_stop, df_beam_start / df_beam_stop,
// df_debug_print (df_systems / df_coords), df_scaled (df_steps).
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;

// Idempotent; called by the three step inits (df_main may call it too) from df_boot, i.e. after the scaling
// table and the players exist. Starts the debug hook and keeper, then picks the set at once (owner rule:
// the lamps exist and are marked from game start).
df_lamps_init()
{
    if ( is_true( level.df_lamps_ready ) )
        return;

    level.df_lamps_ready = 1;
    level.df_lamp_bulb_fallback = ( 0, 0, 148 );
    level thread df_lamp_debug_hook();
    level thread df_lamp_keeper();
    df_lamp_set_get();
}

// =========================================================================================
// the set
// =========================================================================================

// The game's lamp set (picked on the first call, N = df_scaled "nodes", one per fog area).
df_lamp_set_get()
{
    df_lamps_init();

    if ( !isdefined( level.df_lamps ) )
        df_lamp_pick_set();

    return level.df_lamps;
}

// Random pick among the 8 screecher_escape structs (zm_transit.gsc:2273), distinct script_noteworthy
// (= fog area), mixed with the clock so games differ. Lamps in the exclusion list (df_lamp_pick_excluded)
// are skipped unless the skip would leave fewer than n candidates.
df_lamp_pick_set()
{
    level.df_lamps = [];
    n = df_scaled( "nodes" );
    lights = getstructarray( "screecher_escape", "targetname" );

    if ( !isdefined( lights ) || lights.size == 0 )
    {
        df_debug_print( "DF: lamps: no screecher_escape structs on this map" );
        return;
    }

    lights = array_randomize( lights );

    // owner 2026-09-11: the lamp nearest the tower is always in the set (first of the shuffled list)
    tower = df_coord( "DF_SOCKET" );

    if ( isdefined( tower ) )
    {
        near = 0;

        for ( i = 1; i < lights.size; i++ )
        {
            if ( distancesquared( lights[i].origin, tower.origin ) < distancesquared( lights[near].origin, tower.origin ) )
                near = i;
        }

        if ( near != 0 )
        {
            tmp = lights[0];
            lights[0] = lights[near];
            lights[near] = tmp;
        }
    }

    names = "";
    skipped = "";
    allow_excluded = ( lights.size - df_lamp_pick_exclude_names().size ) < n;

    for ( i = 0; i < lights.size && level.df_lamps.size < n; i++ )
    {
        light = lights[i];
        name = light.script_noteworthy;

        if ( !isdefined( name ) )
            name = "light_" + i;

        if ( isdefined( df_lamp_find( name ) ) )
            continue;

        if ( !allow_excluded && df_lamp_pick_excluded( name ) )
        {
            skipped = skipped + name + " ";
            continue;
        }

        lamp = df_lamp_new( light, name );
        lamp.in_set = 1;
        level.df_lamps[level.df_lamps.size] = lamp;
        names = names + name + " ";
        df_lamp_idle_start( lamp );
    }

    if ( skipped != "" )
        df_debug_print( "DF: lamp set: skipped " + skipped + "(not valid for a Richtofen anchor, side " + df_lamp_side_text_or_none() + " at pick time)" );

    df_debug_print( "DF: lamp set (" + level.df_lamps.size + "): " + names );
}

// The lamps (script_noteworthy = fog area) never picked for the set unless the side is already locked to
// Maxis when the pick runs. Owner-editable: the eight names are busdepot, diner, forest, cornfield,
// powerstation, huntershack, townbridge, bridgedepot (df_lamp_exploder_base). diner and townbridge: on the
// Richtofen path a denizen jumps off the head on the way from the fog edge to these two lamps (steps audit v2
// #10), so a Step 5 anchor can be impossible there. Owner-editable list.
df_lamp_pick_exclude_names()
{
    if ( isdefined( level.df_lamp_pick_exclude ) )
        return level.df_lamp_pick_exclude;

    names = [];
    names[names.size] = "diner";
    names[names.size] = "townbridge";
    return names;
}

// True when `name` is on the exclusion list AND the pick is not made on a locked Maxis side (at boot the side
// is unknown, so the list applies: the set comes from the six lamps valid on both sides).
df_lamp_pick_excluded( name )
{
    if ( df_lamp_side_is_maxis() )
        return false;

    foreach ( n in df_lamp_pick_exclude_names() )
    {
        if ( n == name )
            return true;
    }

    return false;
}

// "rich" / "maxis" / "none" for the pick line.
df_lamp_side_text_or_none()
{
    side = df_lamp_side();

    if ( isdefined( side ) )
        return side;

    return "none";
}

// Idle marker of a set lamp in state "off": one short side-family burst (df_lamp_burst_fx) at the bulb every
// 6 s, no colour, no sound. Findable in the fog from round 1; ends with the first quest state
// (df_lamp_state_change) and restarts whenever the lamp goes back to "off".
df_lamp_idle_start( lamp )
{
    if ( !is_true( lamp.in_set ) || lamp.state != "off" )
        return;

    level thread df_lamp_idle_marker( lamp );
}

df_lamp_idle_marker( lamp )
{
    level endon( "end_game" );
    lamp endon( "df_lamp_state_change" );

    while ( lamp.state == "off" )
    {
        lamp.spark = df_fx_loop( df_lamp_burst_fx(), df_lamp_bulb_pos( lamp ) );
        wait 0.6;
        df_fx_stop( lamp.spark );
        lamp.spark = undefined;
        wait 5.4;
    }
}

// =========================================================================================
// all eight lamps (finale / Act 2 reward)
// =========================================================================================

// Every safety light of the map as a lamp struct: the set lamps themselves plus a struct per other lamp
// (built once, level.df_lamps_all). Source: getstructarray "screecher_escape" (zm_transit.gsc:2273), the
// same structs as level.safety_lights.
df_lamp_all_get()
{
    df_lamps_init();

    if ( isdefined( level.df_lamps_all ) )
        return level.df_lamps_all;

    level.df_lamps_all = [];
    lights = getstructarray( "screecher_escape", "targetname" );

    if ( !isdefined( lights ) )
        return level.df_lamps_all;

    foreach ( light in lights )
    {
        lamp = df_lamp_find_by_light( light );

        if ( !isdefined( lamp ) )
        {
            name = light.script_noteworthy;

            if ( !isdefined( name ) )
                name = "light_" + level.df_lamps_all.size;

            lamp = df_lamp_new( light, name );
        }

        level.df_lamps_all[level.df_lamps_all.size] = lamp;
    }

    df_debug_print( "DF: lamps: " + level.df_lamps_all.size + " lamps on the map (set + others)" );
    return level.df_lamps_all;
}

// Permanent world change (audit #8): every lamp of the map in the side colour for the rest of the game,
// through the same exploder logic as the set (state "final": steady colour, no beam, no sound, re-fired
// after clientfield flips and vanilla power changes). `side` "rich" = blue, "maxis" = orange; it is
// remembered (level.df_lamp_side_force) so the colour survives a later side change of level.df_side.
df_lamp_colour_all( side )
{
    if ( isdefined( side ) && ( side == "rich" || side == "maxis" ) )
        level.df_lamp_side_force = side;

    foreach ( lamp in df_lamp_all_get() )
    {
        lamp.final = 1;

        // a "final" lamp that already shows the colour only needs the new side, no rebuild
        if ( lamp.state == "final" )
        {
            df_lamp_exploder_set( lamp, 1 );
            continue;
        }

        df_lamp_state_set( lamp, "final" );
    }

    df_debug_print( "DF: lamps: all " + level.df_lamps_all.size + " lamps coloured " + df_lamp_side_text() );
}

// Server power flag on every lamp of the map (the flag a denizen burrow checks, zm_transit_ai_screecher.gsc:55):
// lamp portals open and denizens burrow anywhere without a turbine, no green light forced (the client keeps
// its own look). on = 0 gives every lamp back to the power system. Kept by df_lamp_keeper.
df_lamp_power_silent_all( on )
{
    n = 0;

    foreach ( lamp in df_lamp_all_get() )
    {
        df_lamp_power_silent( lamp, on );
        n++;
    }

    df_debug_print( "DF: lamps: silent power " + df_lamp_on_off( on ) + " on " + n + " lamps" );
}

// Lamps the keeper and the debug hook walk: all of them once df_lamp_all_get ran, else the set.
df_lamp_keeper_list()
{
    if ( isdefined( level.df_lamps_all ) )
        return level.df_lamps_all;

    if ( isdefined( level.df_lamps ) )
        return level.df_lamps;

    return [];
}

// One lamp struct: .light (the map struct), .origin (base), .bulb, .name, .state, plus the fx slots.
df_lamp_new( light, name )
{
    lamp = spawnstruct();
    lamp.light = light;
    lamp.origin = light.origin;
    lamp.name = name;
    lamp.bulb = df_lamp_find_bulb( light );
    lamp.state = "off";
    lamp.fx = [];
    lamp.souls = 0;
    lamp.filled = 0;
    lamp.vanilla_dark = 0;
    lamp.silent_power = 0;
    df_debug_print( "DF: lamp " + name + " base " + int( lamp.origin[0] ) + " " + int( lamp.origin[1] ) + " " + int( lamp.origin[2] ) + " bulb +" + int( lamp.bulb[2] - lamp.origin[2] ) + " exploders " + df_lamp_exploder_base( name ) + "/" + ( df_lamp_exploder_base( name ) + 1 ) );
    level thread df_lamp_exploder_watch( lamp );
    return lamp;
}

// Set lamp by area name (script_noteworthy), or undefined.
df_lamp_find( name )
{
    if ( !isdefined( level.df_lamps ) || !isdefined( name ) )
        return undefined;

    foreach ( lamp in level.df_lamps )
    {
        if ( lamp.name == name )
            return lamp;
    }

    return undefined;
}

// Set lamp whose struct is `light`, or undefined.
df_lamp_find_by_light( light )
{
    if ( !isdefined( level.df_lamps ) || !isdefined( light ) )
        return undefined;

    foreach ( lamp in level.df_lamps )
    {
        if ( lamp.light == light )
            return lamp;
    }

    return undefined;
}

// Nearest set lamp whose base is within `radius` (3D) of pos and for which `unfilled_only` holds.
df_lamp_nearest( pos, radius, unfilled_only )
{
    best = undefined;
    best_d2 = radius * radius;

    if ( !isdefined( level.df_lamps ) )
        return undefined;

    foreach ( lamp in level.df_lamps )
    {
        if ( unfilled_only && lamp.filled )
            continue;

        // horizontal distance from the post, height within 250 (owner 2026-09-09: the 3D sphere from the
        // base struct missed kills on slopes and roofs next to the lamp)
        if ( abs( pos[2] - lamp.origin[2] ) > 250 )
            continue;

        d2 = distance2dsquared( pos, lamp.origin );

        if ( d2 < best_d2 )
        {
            best = lamp;
            best_d2 = d2;
        }
    }

    return best;
}

// =========================================================================================
// bulb
// =========================================================================================

// Where the light bulb is: the map's blue-lamp exploder position (createfx zm_transit_fx.gsc:3786-3875)
// within 48 units (2D) of the struct, else the struct + 148 (the measured average).
df_lamp_find_bulb( light )
{
    if ( isdefined( level.createfxent ) )
    {
        foreach ( ent in level.createfxent )
        {
            if ( !isdefined( ent ) || !isdefined( ent.v ) || !isdefined( ent.v["fxid"] ) || !isdefined( ent.v["origin"] ) )
                continue;

            if ( ent.v["fxid"] != "fx_zmb_tranzit_light_safety_ric" )
                continue;

            if ( distance2dsquared( ent.v["origin"], light.origin ) < 48 * 48 )
                return ent.v["origin"];
        }
    }

    return light.origin + level.df_lamp_bulb_fallback;
}

// Bulb position of a set lamp (cached at pick time).
df_lamp_bulb_pos( lamp )
{
    if ( isdefined( lamp.bulb ) )
        return lamp.bulb;

    return lamp.origin + level.df_lamp_bulb_fallback;
}

// The side every lamp colour follows: the finale's forced side (df_lamp_colour_all) wins over level.df_side;
// undefined until a side is locked (every side-coloured helper then treats it as Richtofen blue).
df_lamp_side()
{
    if ( isdefined( level.df_lamp_side_force ) )
        return level.df_lamp_side_force;

    return level.df_side;
}

df_lamp_side_is_maxis()
{
    side = df_lamp_side();
    return isdefined( side ) && side == "maxis";
}

// "blue" / "orange" for the console lines.
df_lamp_side_text()
{
    if ( df_lamp_side_is_maxis() )
        return "orange";

    return "blue";
}

// The burst family of the side (owner 2026-09-09): the electric burst elec_md (zm_transit_fx.gsc:36) for
// Richtofen and before the fork, the fire burst lava_burning (zm_transit_fx.gsc:40) for Maxis. Both are
// short bursts: play them with df_fx_loop and delete the ent after 0.5-0.8 s.
df_lamp_burst_fx()
{
    if ( df_lamp_side_is_maxis() )
        return "lava_burning";

    return "elec_md";
}

// =========================================================================================
// states
// =========================================================================================

// Puts the lamp in `state`; a repeat of the current state is a no-op. Everything of the previous state
// (lights, sparks, blink, hum, tick-tock, beam) is removed first, then the new look is built:
//   off      vanilla lamp back (green if powered)
//   souls    accepting souls: one faint side glow at the bulb + Avogadro hum (_zm_ai_avogadro.gsc:811)
//   filled   R2 done / live set lamp (tunable): steady side light + one slow burst every 2 s + meteor hum
//            (zm_transit.gsc:3349)
//   tuning   Step 5 hold in progress: side light + quick bursts (every 0.7 s) + meteor hum
//   waiting  tuned, waiting for the anchor: blinking side light + tick-tock loop (_zm_perks.gsc:721), no burst
//   anchored Step 5 done here: steady side light + tower beam (df_beam_start) + a permanent slow DOUBLE burst
//            every 3 s at the bulb (owner 2026-09-09: reads as "done" even if the exploder colour fails), silent
//   charged  Step 6 drawable: side light + tower beam + meteor hum
//   drained  Step 6 done here: everything off, the lamp stays dark
//   final    finale world change (df_lamp_colour_all): steady side light, nothing else, for the rest of the game
// A lamp marked .final (the finale ran) ignores every later state: the world change is permanent.
df_lamp_state_set( lamp, state )
{
    if ( !isdefined( lamp ) || !isdefined( state ) )
        return;

    if ( isdefined( lamp.state ) && lamp.state == state )
        return;

    if ( is_true( lamp.final ) && state != "final" )
    {
        df_debug_print( "DF: lamp " + lamp.name + " keeps its final colour, state " + state + " ignored" );
        return;
    }

    df_lamp_clear( lamp );
    lamp.state = state;
    bulb = df_lamp_bulb_pos( lamp );

    if ( state == "off" )
    {
        df_lamp_vanilla_light( lamp, 1 );
        df_lamp_idle_start( lamp );
        df_debug_print( "DF: lamp " + lamp.name + " -> off" );
        return;
    }

    // every other state carries our light: no vanilla green under it
    df_lamp_vanilla_light( lamp, 0 );

    if ( state == "souls" )
    {
        // hungry: the exploder colour, the hum and a spark every 2 s (owner 2026-09-11: the sparks mean "feed me")
        df_lamp_exploder_set( lamp, 1 );
        level thread df_lamp_spark_replay( lamp, 2.0 );
        df_lamp_hum_set( lamp, "zmb_avogadro_loop", 0.5 );
    }
    else if ( state == "filled" )
    {
        // charged: NO sparks, NO electric arcs (the vanilla exploder is off: owner 2026-09-11, "remove the electric
        // effect when the spool is dropped"), a steady bulb glow instead
        df_lamp_exploder_set( lamp, 0 );
        g = df_fx_loop( "fx_zmb_tranzit_light_bulb_xsm", bulb );

        if ( isdefined( g ) )
        {
            lamp.fx[lamp.fx.size] = g;
            level thread df_fx_keepalive( g );
        }

        df_lamp_hum_set( lamp, "zmb_avogadro_loop", undefined );
    }
    else if ( state == "tuning" )
    {
        df_lamp_exploder_set( lamp, 1 );
        level thread df_lamp_spark_replay( lamp, 0.7 ); // the faster sparks are the "tuning" intensity now
        df_lamp_hum_set( lamp, "zmb_avogadro_loop", undefined );
    }
    else if ( state == "waiting" )
    {
        level thread df_lamp_blink( lamp );
        df_lamp_hum_set( lamp, "zmb_perks_packa_ticktock", undefined );
    }
    else if ( state == "anchored" )
    {
        df_lamp_exploder_set( lamp, 0 ); // tuned and held: arcs off (owner 2026-09-11), the beam and the pulse say it
        lamp.beam = df_beam_start( bulb );
        level thread df_lamp_spark_replay( lamp, 3.0, 2 ); // the double pulse is the "anchored" signature
    }
    else if ( state == "charged" )
    {
        df_lamp_exploder_set( lamp, 0 );
        lamp.beam = df_beam_start( bulb );
        df_lamp_hum_set( lamp, "zmb_avogadro_loop", undefined );
    }
    else if ( state == "final" )
        df_lamp_exploder_set( lamp, 1 );
    else if ( state != "drained" )
        df_debug_print( "DF: lamp " + lamp.name + " unknown state " + state + " (treated as drained)" );

    df_debug_print( "DF: lamp " + lamp.name + " -> " + state );
}

// Removes every fx / sound / beam of the current state and ends its threads (blink, spark replay).
df_lamp_clear( lamp )
{
    lamp notify( "df_lamp_state_change" );

    if ( isdefined( lamp.fx ) )
    {
        foreach ( ent in lamp.fx )
            df_fx_stop( ent );
    }

    lamp.fx = [];
    df_lamp_exploder_set( lamp, 0 );
    df_fx_stop( lamp.spark );
    lamp.spark = undefined;
    df_fx_stop( lamp.blink_fx );
    lamp.blink_fx = undefined;
    df_lamp_hum_set( lamp, undefined, undefined );
    df_beam_stop( lamp.beam );
    lamp.beam = undefined;
}

// Puts every set lamp in `state` (unpicked set: picks it).
df_lamp_set_all( state )
{
    foreach ( lamp in df_lamp_set_get() )
        df_lamp_state_set( lamp, state );
}

// Loop sound on a script_origin at the bulb (vanilla pattern, zm_transit.gsc:3349); alias undefined = silence.
df_lamp_hum_set( lamp, alias, volume )
{
    if ( isdefined( lamp.snd ) )
    {
        lamp.snd stoploopsound();
        lamp.snd delete();
    }

    lamp.snd = undefined;

    if ( !isdefined( alias ) )
        return;

    lamp.snd = spawn( "script_origin", df_lamp_bulb_pos( lamp ) );

    if ( isdefined( volume ) )
        lamp.snd playloopsound( alias, volume );
    else
        lamp.snd playloopsound( alias );
}

// Controlled burst replay at the bulb: the side-family burst (df_lamp_burst_fx: elec_md / lava_burning, both
// short) is played `pulses` times (default 1, 0.6 s each, 0.2 s apart) every `period` seconds and deleted
// after each pulse. Ends with the state (df_lamp_state_change).
df_lamp_spark_replay( lamp, period, pulses )
{
    level endon( "end_game" );
    lamp endon( "df_lamp_state_change" );

    if ( !isdefined( pulses ) || pulses < 1 )
        pulses = 1;

    while ( true )
    {
        for ( i = 0; i < pulses; i++ )
        {
            lamp.spark = df_fx_loop( df_lamp_burst_fx(), df_lamp_bulb_pos( lamp ) );
            wait 0.6;
            df_fx_stop( lamp.spark );
            lamp.spark = undefined;

            if ( i < pulses - 1 )
                wait 0.2;
        }

        if ( period > 0.7 )
            wait( period - 0.6 );
        else
            wait 0.1;
    }
}

// "waiting" blink: the side light on 0.5 s / off 0.5 s at the bulb. Ends with the state.
df_lamp_blink( lamp )
{
    level endon( "end_game" );
    lamp endon( "df_lamp_state_change" );

    while ( true )
    {
        df_lamp_exploder_set( lamp, 1 );
        wait 0.5;
        df_lamp_exploder_set( lamp, 0 );
        wait 0.5;
    }
}

// =========================================================================================
// side colour = the map's own lamp exploders (see the header)
// =========================================================================================

// Base exploder id of a lamp area: off_sq (Maxis orange) = base, on_sq (Richtofen blue) = base + 1,
// green "on" = base - 300, dark "off" = base - 299 (zm_transit.csc power_controlled_lights). -1 = unknown lamp.
df_lamp_exploder_base( name )
{
    ids = [];
    ids["busdepot"] = 400;
    ids["diner"] = 402;
    ids["forest"] = 404;
    ids["cornfield"] = 406;
    ids["powerstation"] = 408;
    ids["huntershack"] = 410;
    ids["townbridge"] = 412;
    ids["bridgedepot"] = 414;

    if ( isdefined( name ) && isdefined( ids[name] ) )
        return ids[name];

    return -1;
}

// The exploder that colours this lamp for the locked side (blue for Richtofen, orange for Maxis; blue until a
// side is locked, like every other side-coloured thing in the mod). undefined for an unknown lamp name.
df_lamp_side_exploder( lamp )
{
    base = df_lamp_exploder_base( lamp.name );

    if ( base < 0 )
        return undefined;

    if ( df_lamp_side_is_maxis() )
        return base;

    return base + 1;
}

// on = 1: fire the side exploder, and kill the client's dark "off" look on that lamp (activating then stopping
// it from the server is the only way a server script can deactivate a client-started exploder).
// on = 0: stop it. Safe to repeat; a stop before every start prevents doubled loop fx on the clients
// (clientscripts/mp/_fx.csc playlightloopexploder appends, it does not check).
df_lamp_exploder_set( lamp, on )
{
    id = df_lamp_side_exploder( lamp );

    if ( !isdefined( id ) )
    {
        if ( on )
            df_debug_print( "DF: lamp " + lamp.name + ": no exploder table entry, no side colour" );

        return;
    }

    if ( !isdefined( level._exploder_ids ) || !isdefined( level._exploder_ids[id] ) )
    {
        if ( on )
            df_debug_print( "DF: lamp " + lamp.name + ": exploder " + id + " unknown to the server, no side colour" );

        return;
    }

    if ( isdefined( lamp.exploder ) && lamp.exploder != id )
        maps\mp\_utility::stop_exploder( lamp.exploder ); // side changed under us: never leave two colours lit

    if ( !on )
    {
        if ( isdefined( lamp.exploder ) )
            maps\mp\_utility::stop_exploder( lamp.exploder );

        lamp.exploder = undefined;
        lamp.exploder_gen = df_lamp_gen_next( lamp );
        df_lamp_glow_set( lamp, 0 );
        return;
    }

    off_id = df_lamp_exploder_base( lamp.name ) - 299;
    maps\mp\_utility::exploder( off_id );
    maps\mp\_utility::stop_exploder( off_id );
    maps\mp\_utility::stop_exploder( id );
    maps\mp\_utility::exploder( id );
    lamp.exploder = id;
    lamp.exploder_gen = df_lamp_gen_next( lamp );
    level thread df_lamp_exploder_refire( lamp, lamp.exploder_gen, 0.6 );
    level thread df_lamp_exploder_refire( lamp, lamp.exploder_gen, 2.0 );
    df_lamp_glow_set( lamp, 1 );
}

// A monotonically growing number per lamp: a scheduled re-fire only acts if nothing newer happened since.
df_lamp_gen_next( lamp )
{
    if ( !isdefined( lamp.gen ) )
        lamp.gen = 0;

    lamp.gen++;
    return lamp.gen;
}

// Fires the side exploder again `delay` s later if the lamp still wants it: the client kills every sq exploder
// of a lamp whenever its power clientfield changes, and OUR OWN flip to 0 in df_lamp_state_set is such a change.
df_lamp_exploder_refire( lamp, gen, delay )
{
    level endon( "end_game" );
    wait( delay );

    if ( !isdefined( lamp ) || !isdefined( lamp.exploder ) || !isdefined( lamp.exploder_gen ) || lamp.exploder_gen != gen )
        return;

    id = lamp.exploder;
    maps\mp\_utility::stop_exploder( id );
    maps\mp\_utility::exploder( id );
}

// Safety net in a colour known to render (the orb aura candidates the owner has seen): Avogadro's blue
// shimmer for Richtofen, the lava glow for Maxis, sitting in the bulb. `set df_lamp_glow 0` turns it off once
// the exploders are confirmed in game, so the lamp keeps only the map's own light.
df_lamp_glow_set( lamp, on )
{
    df_fx_stop( lamp.glow );
    lamp.glow = undefined;

    if ( !on || getdvar( "df_lamp_glow" ) == "0" )
        return;

    fxname = "avogadro_health_half";

    if ( df_lamp_side_is_maxis() )
        fxname = "fx_zmb_lava_crevice_glow_50";

    lamp.glow = df_fx_loop( fxname, df_lamp_bulb_pos( lamp ) );
}

// Every vanilla power transition on this lamp (safety_light_power_on/off, zm_transit.gsc:2350-2376, plus the
// clientfield flip the keeper answers with) makes the client run power_controlled_or_turbine once more, which
// deactivates every sq exploder of that lamp. Wait for the keeper to have re-darkened it, then fire again.
df_lamp_exploder_watch( lamp )
{
    level endon( "end_game" );

    while ( isdefined( lamp ) && isdefined( lamp.light ) )
    {
        lamp.light waittill_any( "power_on", "power_off" );
        wait 0.8;

        if ( isdefined( lamp.exploder ) && isdefined( lamp.state ) && lamp.state != "off" && lamp.state != "drained" && lamp.state != "waiting" )
        {
            df_lamp_exploder_set( lamp, 1 );
            df_debug_print( "DF: lamp " + lamp.name + " side colour re-fired after a vanilla power change" );
        }
    }
}

// "off" / "401 (blue)" / "400 (orange)" for the debug print.
df_lamp_exploder_text( lamp )
{
    if ( !isdefined( lamp.exploder ) )
        return "off";

    colour = "blue";

    if ( lamp.exploder % 2 == 0 )
        colour = "orange";

    return lamp.exploder + " (" + colour + ")";
}

// =========================================================================================
// vanilla light and power
// =========================================================================================

// on = 0: the client shows the lamp dark whatever its power (clientfield 0, zm_transit.csc:654-670: the
// "off" exploder replaces the green one), kept there by df_lamp_keeper. on = 1: back to what the power
// system believes (the powered item's .power, _zm_power.gsc:110; else the struct flag).
df_lamp_vanilla_light( lamp, on )
{
    light = lamp.light;

    if ( !isdefined( light ) || !isdefined( light.clientfieldname ) )
        return;

    if ( !on )
    {
        lamp.vanilla_dark = 1;
        level setclientfield( light.clientfieldname, 0 );

        // the client answers this flip by deactivating every sq exploder of the lamp: fire it again after
        if ( isdefined( lamp.exploder ) && isdefined( lamp.exploder_gen ) )
            level thread df_lamp_exploder_refire( lamp, lamp.exploder_gen, 0.6 );

        return;
    }

    lamp.vanilla_dark = 0;
    want = is_true( light.power_on );
    item = df_lamp_powered_item( light );

    if ( isdefined( item ) )
        want = is_true( item.power );

    if ( want )
        level setclientfield( light.clientfieldname, 1 );
    else
        level setclientfield( light.clientfieldname, 0 );
}

// Server-side power flag only (light.power_on, what create_portal checks, zm_transit_ai_screecher.gsc:55):
// denizens can burrow at the lamp without a turbine and without the green light. off = back to the truth.
df_lamp_power_silent( lamp, on )
{
    light = lamp.light;

    if ( !isdefined( light ) )
        return;

    if ( on )
    {
        lamp.silent_power = 1;
        light.power_on = 1;
        return;
    }

    lamp.silent_power = 0;
    want = 0;
    item = df_lamp_powered_item( light );

    if ( isdefined( item ) )
        want = is_true( item.power );

    light.power_on = want;
}

// level.powered_items[i].target is the light struct (_zm_power.gsc:108, add_powered_item).
df_lamp_powered_item( light )
{
    if ( !isdefined( level.powered_items ) )
        return undefined;

    foreach ( item in level.powered_items )
    {
        if ( isdefined( item.target ) && item.target == light )
            return item;
    }

    return undefined;
}

// Every 0.5 s: a vanilla power transition (main power toggled, turbine placed / removed) reruns
// safety_light_power_on / _off (zm_transit.gsc:2350-2374) and would relight the lamp green or drop the
// power flag; put our choices back.
df_lamp_keeper()
{
    level endon( "end_game" );

    while ( true )
    {
        wait 0.5;

        foreach ( lamp in df_lamp_keeper_list() )
        {
            if ( is_true( lamp.vanilla_dark ) && isdefined( lamp.light.clientfieldname ) )
                level setclientfield( lamp.light.clientfieldname, 0 );

            if ( is_true( lamp.silent_power ) && !is_true( lamp.light.power_on ) )
                lamp.light.power_on = 1;
        }
    }
}

// =========================================================================================
// debug: "!df fire lamps" prints every known lamp (set first) and its state;
//        "!df fire lamps_all" colours all eight in the locked side (power state if none: on = blue);
//        "!df fire lamps_power" sets the silent power flag on all eight (portals without turbines).
// =========================================================================================

df_lamp_debug_hook()
{
    level endon( "end_game" );
    level thread df_lamp_debug_all_hook();
    level thread df_lamp_debug_power_hook();

    while ( true )
    {
        level waittill( "df_debug_lamps" );
        lamps = df_lamp_keeper_list();
        set = 0;

        if ( isdefined( level.df_lamps ) )
            set = level.df_lamps.size;

        df_debug_print( "DF: lamps: " + set + " in the set, " + lamps.size + " known" );

        foreach ( lamp in lamps )
            df_debug_print( "DF: lamp " + lamp.name + " set " + is_true( lamp.in_set ) + " state " + lamp.state + " souls " + lamp.souls + " at " + int( lamp.origin[0] ) + " " + int( lamp.origin[1] ) + " " + int( lamp.origin[2] ) + " bulb z " + int( df_lamp_bulb_pos( lamp )[2] ) + " power " + df_lamp_on_off( lamp.light.power_on ) + " silent " + lamp.silent_power + " dark " + lamp.vanilla_dark + " exploder " + df_lamp_exploder_text( lamp ) + " glow " + isdefined( lamp.glow ) );
    }
}

df_lamp_debug_all_hook()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_lamps_all" );
        side = level.df_side;

        if ( !isdefined( side ) )
        {
            side = "maxis";

            if ( flag( "power_on" ) )
                side = "rich";
        }

        df_lamp_colour_all( side );
    }
}

df_lamp_debug_power_hook()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_lamps_power" );
        df_lamp_power_silent_all( 1 );
    }
}

df_lamp_on_off( flag )
{
    if ( is_true( flag ) )
        return "on";

    return "off";
}
