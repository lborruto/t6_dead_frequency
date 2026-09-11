// Dead Frequency - Act 3 Step 6 "Vacuum" (spec 5 / Step 6; owner redesign v4, polish pass 2026-09-08, design
//   audit 2026-09-08 #3 / #4 / section 7; steps / art / dialogue audits v2 2026-09-09).
//   When the step opens the orb ARRIVES at DF_ORB_SPAWN (3 s build-up over the tower top, then the strike,
//   thunder: df_s6_orb_arrival) in the side's fx family: Richtofen = Avogadro's storm, his descend bolt, the
//   lightning orb and the blue one-shot; Maxis = a smoke column at the top (fx_zmb_tranzit_smk_column_lrg
//   when the alias exists, else three ash columns), then a fire burst and the lava ignite sound: never a
//   blue bolt on the fire side (art audit #9). The orb (df_model( "orb" ): the turbine rotor disc
//   p6_zm_buildable_turbine_fan since 2026-09-09, 25 x 10 x 25 with a centre pivot, spun slowly by
//   rotateyaw as the tombstone skull is, _zm_tombstone.gsc:332) rests there afterwards: the one thing
//   allowed to appear after a step. A player takes it with one press of F, then carries it to each charged
//   node left by Act 2 (level.df_nodes: the four barn FUSE BOXES R1 charged on the Richtofen side, kind
//   "fuse" exported by df_r1_finish; the M2 braziers on the Maxis side; R2 lamps still work as a fallback).
//   The DRAW verb differs per side (audit 2.3): Richtofen fires the Jet Gun at the node from close range for
//   5 s cumulative WHILE CARRYING THE ORB (electricity); Maxis stands ON LAVA within 300 of the brazier for
//   5 s cumulative while carrying it (fire draws the ash; the lava burns, no Jet Gun needed). With every node
//   drained the carrier places the charged orb in the relay on the table under the tower (one press of F,
//   within 150 units of df_coord( "DF_SOCKET" ) = DF_TABLE): the step is complete, the disc stays visible on
//   the table's slot 2 (df_s6_orb_table_show, aura on, spinning) and Step 7 defends that orb.
//   Visibility (owner: "the orb is too tiny"): while the orb holds a charge it carries a permanent
//   side-coloured aura (df_s6_aura_fx, cycle candidates with "!df fire orb_aura"), the elec_md /
//   lava_burning bursts and a soft hum (zmb_meteor_loop). On the ground (fresh at the spawn with zero
//   charges, or dropped) it ALWAYS carries the vanilla "take me" glint (fx_zmb_tranzit_key_glint,
//   zm_transit_fx.gsc:105, art audit S6.2) plus the tower beam; the step registers the spawn as its focus
//   (df_step_focus) for the shared STEP AVAILABLE cue.
//   Carrying: no lamp portals (df_portal_use in df_act1 checks player.df_orb). Going down drops the orb
//   at the feet (charges kept); an orb left on the ground 60 s flies HOME = the nearer of DF_ORB_SPAWN and
//   the table front (steps audit v2 #8: a Richtofen drop at the barn no longer flies back to the diner),
//   or the table front during a Step 7 restart cycle (df_s6_home_pos).
//   Guidance: every charged node and the waiting orb get the tower beam + rising light column
//   (df_beam_start); a Jet Gun holder (Richtofen) / the carrier (Maxis) near a node gets a puzzle hint; the
//   5 s draw is heard (power-rise loop). Taking the orb with no Jet Gun in any inventory says
//   S6_NOJETGUN_RICH once (Richtofen); the first Maxis pickup says S6_NOJETGUN_MAXIS once; D6_HINT once per
//   game on a later pickup (dialogue audit v2 1.4 #8: it used to repeat on every drop-and-pick);
//   S6_DRAW_LAVA_MAXIS once when the Maxis carrier first reaches a charged brazier. A refused draw (the
//   carrier at a charged node without a Jet Gun in hand / not standing in the lava) buzzes once per
//   approach (df_cue_deny, art audit S6.5). Richtofen's canon jet_low line plays once when the Jet Gun
//   runs hot during a draw (vox_zmba_sidequest_jet_low_0, zm_transit_sq.gsc:642, df_vox_once).
//   Cue grammar (art audit cue table): a node drained = SUB-GOAL chime + side flash at the node + the canon
//   node -> tower runner (df_cue_subgoal does all three), the meteor ping and the trail into the carrier
//   stay; the fourth charge = three rising PROGRESS clinks (df_cue_tick x3); placement = ONE sting only (the
//   uniform STEP DONE from df_complete; the 3D zmb_powerup_grabbed duplicate is gone). Every side flash here
//   is df_cue_side_flash (blue one-shot / 0.8 s fire_lrg), every short burst df_fx_burst.
//   Step 7 restart (contract 2026-09-08 with the Step 7 owner): level notify( "df_s6_restart" ) makes the
//   CHARGED orb (charges = target) reappear on the ground in front of the table, state "waiting",
//   pickable with one press; the nodes are NOT re-armed. Placing it again fires
//   level notify( "df_s6_redelivered" ). See df_s6_restart_listener. "!df fire s6_restart" fires it.
//   Lamps (2026-09-08, lamps agent): when an export still names lamps (kind "lamp", the older R2 export)
//   their looks come only from df_lamp_state_set ("charged" = side light + beam + hum, "drained" = dark) and
//   the aim / beam point is the real bulb (df_lamp_bulb_pos). With fuse or brazier nodes the anchored lamps of
//   Step 5 go dark when Step 6 starts so only the nodes carry beams (the lamps are no longer nodes, audit 1.3).
//
// Node states: "charged" (drawable) -> "drained".
// Orb states:  "waiting" (at the spawn / in front of the table after a restart) -> "carried" -> "dropped" (timer) ->
//              "waiting" | -> "placed".
//
// Shared helpers this file relies on (df_systems / df_steps / df_coords / df_lamps): df_press_use (single F
// press with a 0.3 s re-press guard), df_prompt (mechanic prompts), df_prompt_puzzle (hints, hidden when
// df_hints is 0), df_fx_loop / df_fx_once / df_fx_stop, df_soul_fly, df_beam_start / df_beam_stop, df_model /
// df_model_angles, df_coord, df_ground, df_table_front / df_table_slot / df_table_yaw, df_scaled, df_touch,
// df_complete, df_say, df_debug_print, df_lamp_find / df_lamp_bulb_pos / df_lamp_state_set / df_lamp_set_all,
// df_model_rest_z (world agent 2026-09-09), and the 2026-09-09 core additions df_step_focus, df_cue_tick,
// df_cue_subgoal, df_cue_deny, df_cue_side_flash, df_fx_burst, df_vox_once (tools/audit_V2core.md).
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_steps;
#include scripts\zm\zm_transit\df_coords;
#include scripts\zm\zm_transit\df_scav;
#include scripts\zm\zm_transit\df_lamps;

// Registers step6 and publishes the orb aura candidates (shared with Step 7 through level.df_orb_aura*).
df_act3_vacuum_init()
{
    df_lamps_init();
    df_s6_aura_init();
    level thread df_s6_debug_aura_hook();
    df_register_step( "step6", ::df_s6_run, ::df_s6_setup );
}

// ------------------------------------------------------------------ tuning ----

// Jet Gun draw range in units (owner validated)
df_s6_draw_range()
{
    return 350; // owner 2026-09-11: not too precise (was 300)
}

// cos( 55 deg ): the view must be within 55 degrees of the aim point (owner 2026-09-11: "not too precise"; was 37, and 30
// before that)
df_s6_draw_cos()
{
    return 0.57;
}

// 5 s of drawing at 0.05 s per tick
df_s6_draw_ticks()
{
    return 100;
}

// Seconds a dropped ball waits on the ground before flying home (audit section 5: 30 was short for a team
// down in the fog)
df_s6_drop_seconds()
{
    return 60;
}

// Height of the orb's origin above the surface it rests on: df_model_rest_z( "orb" ) from the df_coords
// registry (world agent 2026-09-09: the turbine rotor disc p6_zm_buildable_turbine_fan, 25 x 25 x 10, pivot
// at its base, hovers 5 = half its thickness under the aura). Used for the spawn, drops, the debug hook and
// the table slot (df_s6_table_pos adds it to the table TOP, exactly as it is added to the floor). Same
// source in df_act3_hold (df_s7_orb_rest_offset): a model swap in df_coords moves both at once.
df_s6_orb_rest_offset()
{
    return ( 0, 0, df_model_rest_z( "orb" ) );
}

// One slow turn every 8 s (rotateyaw on a script_model, the tombstone skull's spin _zm_tombstone.gsc:332;
// the R1 card does the same, df_act2_rich): under the aura the flat rotor disc reads as a coil / core.
// self = the orb model; ends with it ("death" is fired by delete).
df_s6_orb_spin()
{
    self endon( "death" );
    level endon( "end_game" );

    while ( isdefined( self ) )
    {
        self rotateyaw( 360, 8 );
        wait 8;
    }
}

// Where the aura and the charge bursts ride relative to the orb's origin (the sphere's centre).
df_s6_orb_fx_offset()
{
    return ( 0, 0, 0 );
}

// The aim point sits where players naturally look: the real bulb for set lamps (df_lamp_bulb_pos; the
// blue light), the box face for a barn fuse box (kind "fuse", audit #3: origin + 20, where R1 sparks it,
// df_r1_spawn_fuses led_origin), just above the brazier otherwise.
df_s6_orb_pos( node )
{
    if ( isdefined( node.kind ) && node.kind == "lamp" )
    {
        if ( isdefined( node.lamp ) )
            return df_lamp_bulb_pos( node.lamp );

        return node.origin + ( 0, 0, 148 );
    }

    if ( isdefined( node.kind ) && node.kind == "fuse" )
        return node.origin + ( 0, 0, 20 );

    if ( isdefined( node.kind ) && node.kind == "core" )
        return node.origin + ( 0, 0, 30 ); // the reactor core nodes (owner 2026-09-11)

    return node.origin + ( 0, 0, 60 );
}

// Where the guiding beam points for a node without a lamp look of its own (fuse boxes, braziers, fallback nodes).
df_s6_beam_pos( node )
{
    if ( isdefined( node.kind ) && node.kind == "lamp" )
        return df_s6_orb_pos( node );

    if ( isdefined( node.kind ) && node.kind == "fuse" )
        return node.origin + ( 0, 0, 20 );

    if ( isdefined( node.kind ) && node.kind == "core" )
        return node.origin + ( 0, 0, 30 );

    return node.origin + ( 0, 0, 40 );
}

// The floor in front of the table (df_coords df_table_front: 40 units out along the table's front) plus
// our rest offset. Where the charged orb reappears after a Step 7 failure (contract G) and where a
// dropped orb flies back to during a restart cycle. The name is kept: every caller means "in front of
// the place at the tower", which is the table since 2026-09-08.
df_s6_socket_front_pos()
{
    return df_table_front() + df_s6_orb_rest_offset();
}

// The orb's own place ON the table: slot 2 (the right one seen from the front), next to the key card
// (slot 1) and the plugged relay (slot 0). df_table_slot returns a point on the table TOP, so the same
// rest offset that puts the ball on the floor puts it on the table.
df_s6_table_pos()
{
    return df_table_slot( 2 ) + df_s6_orb_rest_offset();
}

// Where a dropped orb flies home from `from`: the table front during a Step 7 restart cycle, else the NEARER
// of DF_ORB_SPAWN and the table front (steps audit v2 #8: on Richtofen the spawn is the diner, so a drop at
// the barn used to fly back across the map; the table is where the orb goes anyway).
df_s6_home_pos( from )
{
    front = df_s6_socket_front_pos();

    if ( isdefined( level.df_s6_gen ) && level.df_s6_gen > 0 )
        return front;

    spawn_pos = df_s6_spawn_pos();

    if ( !isdefined( from ) || distancesquared( from, spawn_pos ) <= distancesquared( from, front ) )
        return spawn_pos;

    return front;
}

// Weapon names from tools/assets/weapons_zm_transit.txt (jetgun_zm, jetgun_upgraded_zm; _zm_weap_jetgun.gsc)
df_s6_is_jetgun( weapon )
{
    return isdefined( weapon ) && ( weapon == "jetgun_zm" || weapon == "jetgun_upgraded_zm" );
}

// level.df_side is locked by Step 4 (df_set_side); undefined counts as Richtofen colours.
df_s6_is_maxis()
{
    return isdefined( level.df_side ) && level.df_side == "maxis";
}

// The orb's charge burst by side: elec_md (zm_transit_fx.gsc:36) for Richtofen, lava_burning
// (zm_transit_fx.gsc:40, the lava fire on a player torso) for Maxis. Both are short bursts: replay them.
df_s6_charge_fx()
{
    if ( df_s6_is_maxis() )
        return "lava_burning";

    return "elec_md";
}

// Where the orb waits: the floor under DF_ORB_SPAWN (df_coords; re-grounded so our rest offset applies),
// else the floor at the table.
df_s6_spawn_pos()
{
    c = df_coord( "DF_ORB_SPAWN" );

    if ( isdefined( c ) )
        return df_ground( c.origin ) + df_s6_orb_rest_offset();

    return df_ground( df_coord( "DF_SOCKET" ).origin ) + df_s6_orb_rest_offset();
}

// ------------------------------------------------------------------- aura ----
// Permanent side-coloured light around the ball while it holds a charge, so the small model reads from a
// distance. The owner tests the candidates in game ("!df fire orb_aura" cycles them, both steps follow):
//   rich:  avogadro_health_half / _full / _low (fx_zmb_avog_health_*, the blue electric shimmer vanilla
//          plays on a tag_origin riding Avogadro, _zm_ai_avogadro.gsc:1370-1374), etrap_on (the electric
//          trap field, _zm_equip_electrictrap.gsc:269), fx_zmb_tranzit_flourescent_glow (zm_transit_fx.gsc:49).
//   maxis: fx_zmb_tranzit_fire_med (zm_transit_fx.gsc:99, the M2 brazier stage-1 fire),
//          fx_zmb_lava_crevice_glow_50 (:90, orange lava glow), fx_zmb_tranzit_fire_lrg (:100),
//          fx_zmb_ash_rising_md (:81, embers).
// fx_zmb_tranzit_light_safety_* are deliberately absent (owner: lamp-sized).

df_s6_aura_init()
{
    if ( isdefined( level.df_orb_aura ) )
        return;

    level.df_orb_aura = [];
    level.df_orb_aura["rich"] = [];
    level.df_orb_aura["rich"][0] = "avogadro_health_full"; // owner pick 2026-09-11 (Effect Picker)
    level.df_orb_aura["rich"][1] = "avogadro_health_half";
    level.df_orb_aura["rich"][2] = "avogadro_health_low";
    level.df_orb_aura["rich"][3] = "etrap_on";
    level.df_orb_aura["rich"][4] = "fx_zmb_tranzit_flourescent_glow";
    level.df_orb_aura["maxis"] = [];
    level.df_orb_aura["maxis"][0] = "powerup_on_caution"; // owner pick 2026-09-11 (Effect Picker)
    level.df_orb_aura["maxis"][1] = "fx_zmb_tranzit_fire_med";
    level.df_orb_aura["maxis"][2] = "fx_zmb_tranzit_fire_lrg";
    level.df_orb_aura["maxis"][3] = "fx_zmb_ash_rising_md";
    level.df_orb_aura_idx = 0;
}

// Current aura alias for the locked side (Richtofen colours until a side is locked).
df_s6_aura_fx()
{
    df_s6_aura_init();
    side = "rich";

    if ( df_s6_is_maxis() )
        side = "maxis";

    list = level.df_orb_aura[side];
    return list[level.df_orb_aura_idx % list.size];
}

// Makes the ball's aura and hum match its charge: both present while charges > 0, both gone otherwise.
df_s6_orb_aura_sync()
{
    orb = level.df_s6_orb;

    if ( !isdefined( orb ) || !isdefined( orb.ent ) || orb.charges <= 0 )
    {
        df_s6_orb_aura_off();
        return;
    }

    if ( !isdefined( orb.aura ) )
    {
        orb.aura = df_fx_loop( df_s6_aura_fx(), orb.ent.origin + df_s6_orb_fx_offset() );

        if ( isdefined( orb.aura ) )
            orb.aura linkto( orb.ent );
    }

    if ( !isdefined( orb.snd ) )
    {
        // zmb_meteor_loop: the soft hum of the song meteors (zm_transit.gsc:3349), natural 3D falloff
        orb.snd = spawn( "script_origin", orb.ent.origin );
        orb.snd linkto( orb.ent );
        orb.snd playloopsound( "zmb_avogadro_loop" );
    }
}

// Aura and hum off (the ball itself stays).
df_s6_orb_aura_off()
{
    orb = level.df_s6_orb;

    if ( !isdefined( orb ) )
        return;

    df_fx_stop( orb.aura );
    orb.aura = undefined;

    if ( isdefined( orb.snd ) )
    {
        orb.snd stoploopsound();
        orb.snd delete();
    }

    orb.snd = undefined;
}

// "!df fire orb_aura": next candidate for the current side, applied at once to a charged ball on the
// ground; level notify( "df_orb_aura_changed" ) lets Step 7 re-dress its orb too.
df_s6_debug_aura_hook()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_orb_aura" );
        level.df_orb_aura_idx++;
        df_debug_print( "DF: orb aura now " + df_s6_aura_fx() + " (index " + level.df_orb_aura_idx + ")" );

        if ( isdefined( level.df_s6_orb ) && isdefined( level.df_s6_orb.aura ) )
        {
            df_fx_stop( level.df_s6_orb.aura );
            level.df_s6_orb.aura = undefined;
            df_s6_orb_aura_sync();
        }

        level notify( "df_orb_aura_changed" );
    }
}

// ------------------------------------------------------------------- step ----

// run_func: nodes, the arrival strike, the ball, monitors, wait for the ball to be placed, complete, arm the
// Step 7 restart contract.
df_s6_run()
{
    level endon( "end_game" );
    level endon( "df_skip_step6" );

    level thread df_s6_skip_cleanup();
    df_s6_build_nodes();
    level.df_s6_target = level.df_s6_nodes.size;
    level.df_orbs_delivered = 0;
    level.df_s6_said_nojet = 0;
    level.df_s6_said_lava = 0;
    level.df_s6_said_hint = 0;
    level.df_s6_said_jet_low = 0;

    // the shared STEP AVAILABLE cue (df_steps) glints the focus until the first touch: 20 over the orb spawn
    df_step_focus( "step6", df_s6_spawn_pos() + ( 0, 0, 20 ) );
    df_s6_orb_arrival( df_s6_spawn_pos() );
    df_s6_orb_reset( 0 );
    df_s6_monitors_start();

    df_debug_print( "DF: s6 started, orb waiting at DF_ORB_SPAWN, " + level.df_s6_target + " charge(s) to collect (" + level.df_s6_nodes_source + ")" );

    while ( level.df_s6_orb.state != "placed" )
        level waittill( "df_s6_check" );

    level notify( "df_s6_stop" );
    df_s6_cleanup();
    df_debug_print( "DF: s6 orb placed with " + level.df_s6_orb.charges + "/" + level.df_s6_target + " charge(s)" );
    df_say( "D6_DONE" );
    df_complete( "step6" );
    level thread df_s6_restart_listener();
}

// The orb's origin (audit section 7; art audit #9 / cue table SPECTACLE row): 3 s of build-up over the tower
// top with a low rumble (earthquake, as the hellhound bolt _zm_ai_dogs.gsc:205), then the strike at the spot
// and Avogadro's thunder crack (zmb_avogadro_spawn_3d, _zm_ai_avogadro.gsc:810) on both sides.
//   Richtofen: the storm cloud (fx_zmb_avog_storm, zm_transit_fx.gsc:120), then his arrival bolt on the
//   ground (avogadro_descend, _zm_ai_avogadro.gsc:33/:814), the lightning orb (sq_common_lightning,
//   zm_transit_fx.gsc:20) and the blue one-shot (df_cue_side_flash).
//   Maxis: the smoke column (df_s6_arrival_fx_start), then a fire burst (df_cue_side_flash) and the lava
//   ignite sound ("ignite", zm_transit_lava.gsc:275): fire, never a blue bolt.
// The caller places the disc right after. Blocking; a skip during the build-up ends the caller and
// df_s6_cleanup removes the column / storm.
df_s6_orb_arrival( pos )
{
    top = df_tower_top();

    if ( !isdefined( top ) )
    {
        // level.sq_volume is the vanilla tower volume (zm_transit_sq.gsc); the constant is its origin
        top = ( 7644, -464, -132 ) + ( 0, 0, 900 );

        if ( isdefined( level.sq_volume ) )
            top = level.sq_volume.origin + ( 0, 0, 900 );
    }

    df_s6_arrival_fx_start( top );
    earthquake( 0.2, 3, pos, 1200 );
    df_debug_print( "DF: s6 build-up over the tower, the orb arrives in 3 s" );
    wait 3;
    df_s6_arrival_fx_stop();

    if ( df_s6_is_maxis() )
        playsoundatposition( "zmb_phdflop_explo", pos ); // fire whoosh ("ignite" is in no TranZit bank)
    else
    {
        df_fx_once( "avogadro_descend", df_ground( pos ) );
        df_fx_once( "sq_common_lightning", pos );
    }

    df_cue_side_flash( pos, undefined );
    playsoundatposition( "zmb_avogadro_spawn_3d", pos );
    earthquake( 0.3, 0.6, pos, 800 );
    df_debug_print( "DF: s6 strike at DF_ORB_SPAWN" );
}

// The 3 s build-up at the tower top, per side: Richtofen the storm cloud (fx_zmb_avog_storm); Maxis the
// large smoke column (fx_zmb_tranzit_smk_column_lrg, createfx zm_transit_fx.csc:596 / zm_transit_fx.gsc:101)
// when the alias is registered, else three ash columns (fx_zmb_ash_rising_md, zm_transit_fx.gsc:81) 60
// apart. level.df_s6_arrival_fx holds the fx ents (an array) for df_s6_arrival_fx_stop.
df_s6_arrival_fx_start( top )
{
    df_s6_arrival_fx_stop();
    level.df_s6_arrival_fx = [];

    if ( !df_s6_is_maxis() )
    {
        level.df_s6_arrival_fx[0] = df_fx_loop( "fx_zmb_avog_storm", top );
        return;
    }

    if ( isdefined( level._effect["fx_zmb_tranzit_smk_column_lrg"] ) )
    {
        level.df_s6_arrival_fx[0] = df_fx_loop( "fx_zmb_tranzit_smk_column_lrg", top );
        return;
    }

    level.df_s6_arrival_fx[0] = df_fx_loop( "fx_zmb_ash_rising_md", top );
    level.df_s6_arrival_fx[1] = df_fx_loop( "fx_zmb_ash_rising_md", top + ( 60, 0, 0 ) );
    level.df_s6_arrival_fx[2] = df_fx_loop( "fx_zmb_ash_rising_md", top + ( -60, 0, 0 ) );
}

// Every build-up fx ent off (safe when none is running).
df_s6_arrival_fx_stop()
{
    if ( isdefined( level.df_s6_arrival_fx ) )
    {
        foreach ( ent in level.df_s6_arrival_fx )
            df_fx_stop( ent );
    }

    level.df_s6_arrival_fx = undefined;
}

// Starts (or restarts) every step monitor. df_s6_stop first, so a second call never doubles them.
df_s6_monitors_start()
{
    level notify( "df_s6_stop" );
    level thread df_s6_draw_monitor();
    level thread df_s6_hint_monitor();
    level thread df_s6_pickup_monitor();
    level thread df_s6_carry_monitor();
    level thread df_s6_socket_monitor();
    level thread df_s6_debug_draw_hook();
    level thread df_s6_debug_deliver_hook();
    level thread df_s6_debug_orb_hook();
}

// ---------------------------------------------------------------- restart ----
// Step 7 contract (G, 2026-09-08): a failed tower defence fires level notify( "df_s6_restart" ); the
// CHARGED orb reappears on the floor in front of the table, state "waiting", one press picks it up,
// one press places it again: level notify( "df_s6_redelivered" ). Nodes stay drained. No second df_complete.

// Armed once (by completion or by df_s6_setup); every df_s6_restart starts a new redo cycle.
// The finale lifts the resting orb into the tower and bursts it (df_finale df_fin_orb_rise): once it notifies
// "df_fin_orb_consumed" the table copy is gone for good.
df_s6_finale_consume_watch()
{
    level endon( "end_game" );
    level waittill( "df_fin_orb_consumed" );

    if ( isdefined( level.df_s6_orb ) )
    {
        df_s6_orb_hide();
        level.df_s6_orb.state = "consumed";
    }

    df_debug_print( "DF: s6 orb consumed by the finale" );
}

df_s6_restart_listener()
{
    level endon( "end_game" );

    if ( is_true( level.df_s6_restart_armed ) )
        return;

    level.df_s6_restart_armed = 1;
    level.df_s6_gen = 0;
    level thread df_s6_debug_restart_hook();
    level thread df_s6_table_orb_watch();
    level thread df_s6_table_orb_return_watch();
    level thread df_s6_finale_consume_watch();

    while ( true )
    {
        level waittill( "df_s6_restart" );
        level.df_s6_gen++;
        level thread df_s6_restart_cycle( level.df_s6_gen );
    }
}

// ---- the orb on the table while Step 7 borrows it ---------------------------------------
// Step 7 spawns its OWN ball for the wave (it must move, take damage and burst), so our resting ball has
// to disappear for that time or the table would carry two orbs. Step 7 tells us with two notifies:
//   "df_s7_orb_taken"     the wave orb has been spawned on slot 2  -> hide ours
//   "df_s7_orb_returned"  the wave orb glided back / Step 7 was skipped -> show ours on slot 2 again
// A Step 7 FAILURE sends neither: it fires "df_s6_restart" instead and the restart cycle puts the charged
// orb in front of the table (df_s6_socket_front_pos). Both watchers only act on a "placed" orb, so they
// can never fight the restart cycle or the carried ball.

df_s6_table_orb_watch()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_s7_orb_taken" );

        if ( !isdefined( level.df_s6_orb ) || level.df_s6_orb.state != "placed" )
            continue;

        df_s6_orb_hide();
        df_debug_print( "DF: s6 orb hidden while Step 7 holds it" );
    }
}

df_s6_table_orb_return_watch()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_s7_orb_returned" );

        if ( !isdefined( level.df_s6_orb ) || level.df_s6_orb.state != "placed" )
            continue;

        df_s6_orb_table_show();
    }
}

// "!df fire s6_restart" = the Step 7 fail contract without Step 7.
df_s6_debug_restart_hook()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_s6_restart" );
        df_debug_print( "DF: s6 restart fired by debug" );
        level notify( "df_s6_restart" );
    }
}

// One redo round: the charged orb waits in front of the table (nodes untouched), the monitors run
// again, placing it fires df_s6_redelivered. A newer restart (higher generation) makes this cycle step aside.
// zmb_bus_emp_shutdown: the bus EMP sound (zm_transit_bus.gsc:3097), loud and verified.
df_s6_restart_cycle( gen )
{
    level endon( "end_game" );

    // stop running monitors and wake any older cycle so it can exit
    level notify( "df_s6_stop" );
    level notify( "df_s6_check" );
    df_s6_cleanup();
    df_s6_build_nodes();
    level.df_s6_target = level.df_s6_nodes.size;

    if ( isdefined( level.df_s6_orb ) )
        df_s6_orb_hide();

    orb = spawnstruct();
    orb.state = "waiting";
    orb.charges = level.df_s6_target;
    orb.drop_id = 0;
    level.df_s6_orb = orb;
    level.df_orbs_delivered = orb.charges;
    df_scav_carry_clear( "orb" );
    df_scav_carry_set( "orb", orb.charges, level.df_s6_target, undefined );
    df_s6_orb_show( df_s6_socket_front_pos() );
    df_s6_monitors_start();

    foreach ( player in getplayers() )
        player playsoundtoplayer( "zmb_bus_emp_shutdown", player );

    df_debug_print( "DF: s6 restart: charged orb (" + orb.charges + "/" + level.df_s6_target + ") waiting in front of the table, pick it up and place it again" );

    while ( level.df_s6_orb.state != "placed" )
    {
        level waittill( "df_s6_check" );

        if ( level.df_s6_gen != gen )
            return;
    }

    level notify( "df_s6_stop" );
    df_s6_cleanup();
    df_debug_print( "DF: s6 orb placed again, waiting for the next restart" );
    level notify( "df_s6_redelivered" );
}

// A node holds a charge again (unused by the restart contract since 2026-09-08, kept for the fallback
// markers): set lamps get the shared "charged" look, other nodes the beam + our orange marker.
// Ends the charged-node hum (safe when there is none).
df_s6_node_hum_stop( node )
{
    if ( !isdefined( node ) || !isdefined( node.own_snd ) )
        return;

    node.own_snd stoploopsound();
    node.own_snd delete();
    node.own_snd = undefined;
}

df_s6_node_fx_on( node )
{
    if ( isdefined( node.lamp ) )
    {
        df_lamp_state_set( node.lamp, "charged" );
        return;
    }

    df_s6_beam_on( node );

    if ( isdefined( node.src ) && is_true( node.src.fallback ) && !isdefined( node.own_fx ) )
        node.own_fx = df_fx_loop( "fx_zmb_tranzit_light_glow_xsm", node.origin + ( 0, 0, 40 ) );

    // a charged fuse box / brazier is HEARD (owner 2026-09-09: no visual instruction): the meteor hum at the
    // draw point, the same hum a charged lamp carries (zm_transit.gsc:3349)
    if ( !isdefined( node.own_snd ) )
    {
        node.own_snd = spawn( "script_origin", df_s6_orb_pos( node ) );
        node.own_snd playloopsound( "zmb_avogadro_loop" );
    }
}

// setup_func for "!df goto" past this step: every node drained, the orb counts as placed and rests on the
// table's slot 2 (so a "!df goto step7" or "!df goto finale" has the ball where a real run leaves it).
df_s6_setup()
{
    level notify( "df_s6_stop" );
    level.df_s6_nodes = undefined;
    df_s6_build_nodes();

    foreach ( node in level.df_s6_nodes )
    {
        node.state = "drained";
        df_s6_node_fx_off( node );
    }

    df_s6_orb_reset( level.df_s6_nodes.size );
    level.df_s6_orb.state = "placed";
    df_s6_orb_table_show();
    level.df_s6_target = level.df_s6_nodes.size;
    level.df_orbs_delivered = level.df_s6_target;
    df_debug_print( "DF: s6 setup, orb marked placed with " + level.df_s6_target + " charge(s), resting on the table" );

    // Step 7 may fail after a "!df goto step7": arm the restart contract here as well (guarded against double arming)
    level thread df_s6_restart_listener();
}

// Wraps level.df_nodes (exported by R1 as fuse boxes / M2 as braziers; R2 lamps as the older export) into
// our own node structs. Without an export (e.g. a Maxis run before M2 exists) the nodes are the braziers
// DF_BRAZIER_1..N with our own orange marker (fx_zmb_tranzit_light_safety_max, zm_transit_fx.gsc:114). Set
// lamps (node.lamp, df_lamp_find by name) get the shared "charged" look; every other charged node gets the
// guiding beam. When the nodes are not lamps (both sides now) the Step 5 lamps go dark so only the nodes
// carry beams.
df_s6_build_nodes()
{
    if ( isdefined( level.df_s6_nodes ) )
        return;

    level.df_s6_nodes = [];
    level.df_s6_nodes_source = "level.df_nodes";
    lamps_used = 0;

    if ( !isdefined( level.df_nodes ) || level.df_nodes.size == 0 )
    {
        level.df_nodes = [];
        n = df_scaled( "nodes" );

        for ( i = 1; i <= n; i++ )
        {
            c = df_coord( "DF_BRAZIER_" + i );

            if ( !isdefined( c ) )
                continue;

            node = spawnstruct();
            node.origin = c.origin;
            node.name = "brazier_" + i;
            node.kind = "brazier";
            node.fallback = 1;
            level.df_nodes[level.df_nodes.size] = node;
        }

        level.df_s6_nodes_source = "fallback: level.df_nodes undefined, using DF_BRAZIER_1.." + n;
    }

    for ( i = 0; i < level.df_nodes.size; i++ )
    {
        src = level.df_nodes[i];
        node = spawnstruct();
        node.index = i;
        node.origin = src.origin;
        node.name = src.name;
        node.kind = src.kind;
        node.src = src;
        node.state = "charged";
        node.draw_ticks = 0;

        if ( isdefined( node.kind ) && node.kind == "lamp" )
            node.lamp = df_lamp_find( node.name );

        if ( isdefined( node.lamp ) )
            lamps_used++;

        df_s6_node_fx_on( node );
        level.df_s6_nodes[level.df_s6_nodes.size] = node;
        df_debug_print( "DF: s6 node " + i + " " + node.kind + " " + node.name );
    }

    if ( lamps_used == 0 && isdefined( level.df_lamps ) )
        df_lamp_set_all( "off" );
}

// ------------------------------------------------------------------- beam ----
// Tower morse light from the socket towards the node + rising light column at it (df_beam_start in
// df_coords: mc_towerlight zm_transit_fx.gsc:42, fx_zmb_tranzit_power_rising :119), shown while the
// node still holds its charge.

df_s6_beam_on( node )
{
    // set lamps: the beam belongs to the lamp's "charged" look (df_lamps.gsc)
    if ( isdefined( node.beam ) || isdefined( node.lamp ) )
        return;

    node.beam = df_beam_start( df_s6_beam_pos( node ) );
    df_debug_print( "DF: s6 beam on node " + node.index );
}

// Beam and column of a node off (df_beam_stop).
df_s6_beam_off( node )
{
    if ( !isdefined( node.beam ) )
        return;

    df_beam_stop( node.beam );
    node.beam = undefined;
    df_debug_print( "DF: s6 beam off node " + node.index );
}

// -------------------------------------------------------------------- orb ----
// level.df_s6_orb: .state, .charges, .ent (the ball), .aura (side light loop), .fx (charge burst riding
// it), .snd (hum), .beam, .carrier, .carrier_pos, .drop_id.

// (Re)creates the orb struct with `charges` charges at the spawn, state "waiting".
df_s6_orb_reset( charges )
{
    if ( isdefined( level.df_s6_orb ) )
        df_s6_orb_hide();

    orb = spawnstruct();
    orb.state = "waiting";
    orb.charges = charges;
    orb.drop_id = 0;
    level.df_s6_orb = orb;
    df_scav_carry_clear( "orb" );

    if ( charges > 0 )
        df_scav_carry_set( "orb", charges, level.df_s6_target, undefined );

    df_s6_orb_show( df_s6_spawn_pos() );
    df_debug_print( "DF: s6 orb at " + int( orb.ent.origin[0] ) + " " + int( orb.ent.origin[1] ) + " " + int( orb.ent.origin[2] ) + ", " + charges + " charge(s)" );
}

// The orb (df_model( "orb" ), precached by df_coords_precache) appears ON THE GROUND at pos, spinning, with
// its aura, hum, charge bursts, a guiding beam and the "take me" glint (fx_zmb_tranzit_key_glint,
// zm_transit_fx.gsc:105) 20 above it, charged or not (art audit S6.2: a bare disc at the diner with no
// marker was the weakest AVAILABLE cue of the quest). The registry's base angles (df_model_angles) lay the
// disc flat; the yaw is random. pos already includes df_s6_orb_rest_offset.
df_s6_orb_show( pos )
{
    orb = level.df_s6_orb;
    df_s6_orb_hide();
    orb.ent = spawn( "script_model", pos );
    orb.ent setmodel( df_model( "orb" ) );
    orb.ent.angles = df_model_angles( "orb", randomint( 360 ) );
    orb.ent thread df_s6_orb_spin();
    orb.beam = df_beam_start( pos + ( 0, 0, 20 ) );
    orb.glint = df_fx_loop( "fx_zmb_tranzit_light_glow", pos + ( 0, 0, 20 ) );
    df_s6_orb_aura_sync();
    orb.ent thread df_s6_orb_charge_fx();
}

// The delivered orb on its table slot (owner 2026-09-08): the same disc with its aura and hum, spinning on
// slot 2 for the rest of the game instead of vanishing into a panel. No guiding beam and no glint (it IS
// the destination) and no prompt (state "placed"). Step 7 borrows it for its wave (df_s6_table_orb_watch).
df_s6_orb_table_show()
{
    orb = level.df_s6_orb;

    if ( !isdefined( orb ) )
        return;

    df_s6_orb_hide();
    pos = df_s6_table_pos();
    orb.ent = spawn( "script_model", pos );
    orb.ent setmodel( df_model( "orb" ) );
    orb.ent.angles = df_model_angles( "orb", df_table_yaw() );
    orb.ent thread df_s6_orb_spin();
    df_s6_orb_aura_sync();
    orb.ent thread df_s6_orb_charge_fx();
    df_debug_print( "DF: s6 orb resting on the table, slot 2 (" + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) + ")" );
}

// Removes the disc and everything riding it (beam, glint, aura, hum, burst; the struct and its charges stay).
df_s6_orb_hide()
{
    orb = level.df_s6_orb;

    if ( !isdefined( orb ) )
        return;

    df_s6_orb_aura_off();

    if ( isdefined( orb.beam ) )
        df_beam_stop( orb.beam );

    orb.beam = undefined;
    df_fx_stop( orb.glint );
    orb.glint = undefined;
    df_fx_stop( orb.fx );
    orb.fx = undefined;
    df_fx_stop( orb.ent );
    orb.ent = undefined;
}

// self = the ball. The side burst (elec_md / lava_burning, short: on 0.8 s, off 0.3 s) pulsed on it while
// it holds a charge; nothing while empty. Also keeps aura + hum in step with the charge count.
df_s6_orb_charge_fx()
{
    self endon( "death" );
    level endon( "end_game" );

    orb = level.df_s6_orb;
    fxname = df_s6_charge_fx();

    while ( isdefined( self ) && isdefined( orb ) )
    {
        df_s6_orb_aura_sync();

        if ( orb.charges <= 0 )
        {
            wait 0.5;
            continue;
        }

        df_fx_stop( orb.fx );
        orb.fx = df_fx_loop( fxname, self.origin + df_s6_orb_fx_offset() );

        if ( isdefined( orb.fx ) )
            orb.fx linkto( self );

        wait 0.8;
        df_fx_stop( orb.fx );
        orb.fx = undefined;
        wait 0.3;
    }
}

// Players within 100 of the waiting / dropped ball get "Press F to take the orb"; one press (df_press_use,
// edge-detected with a 0.3 s re-press guard, polled every 0.05 s only for players in range as df_systems
// asks) carries it, like a vanilla buildable part (zm_transit_buildables.gsc:249).
df_s6_pickup_monitor()
{
    level endon( "end_game" );
    level endon( "df_skip_step6" );
    level endon( "df_s6_stop" );

    while ( true )
    {
        wait 0.05;
        orb = level.df_s6_orb;

        if ( !isdefined( orb ) || !isdefined( orb.ent ) || ( orb.state != "waiting" && orb.state != "dropped" ) )
            continue;

        foreach ( player in getplayers() )
        {
            if ( isdefined( player.df_orb ) || is_true( player.df_carrying_relay ) )
                continue;

            near = is_player_valid( player ) && distancesquared( player.origin, orb.ent.origin ) < 100 * 100;

            if ( !near )
            {
                player df_s6_prompt_clear( "orb" );
                continue;
            }

            player df_s6_prompt_set( "orb", "Press [{+activate}] to take the orb" );

            if ( !player df_press_use() )
                continue;

            df_touch( "step6" );
            player df_s6_orb_take();
            break;
        }
    }
}

// ------------------------------------------------------------------ carry ----

// self = player. The ball leaves the world and rides the player (player.df_orb = 1, checked by
// df_portal_use in df_act1). zmb_buildable_pickup: vanilla part pickup sound (zm_transit_buildables.gsc:249).
df_s6_orb_take()
{
    orb = level.df_s6_orb;
    df_s6_orb_hide();
    orb.state = "carried";
    orb.carrier = self;
    orb.carrier_pos = self.origin;
    self.df_orb = 1;
    df_scav_carry_set( "orb", orb.charges, level.df_s6_target, self );
    self df_s6_prompt_clear( undefined );
    self df_s6_bar_sync( undefined );
    self thread df_s6_carry_fx();
    self playsound( "zmb_buildable_pickup" );
    df_debug_print( "DF: s6 orb picked up by " + self.name + " (" + orb.charges + "/" + level.df_s6_target + " charges)" );

    if ( orb.charges >= level.df_s6_target )
        return;

    // audit section 4: the pickup is the moment to say what draws the charge. Maxis: the fire, once; Richtofen
    // with no Jet Gun anywhere: the vacuum cleaner line, once. Afterwards the generic D6_HINT, once per game
    // (dialogue audit v2 1.4 #8: drop-and-pick cycles used to queue a 6.5 s line every time).
    if ( !is_true( level.df_s6_said_nojet ) && ( df_s6_is_maxis() || !df_s6_any_jetgun() ) )
    {
        level.df_s6_said_nojet = 1;

        if ( df_s6_is_maxis() )
            df_say( "S6_NOJETGUN_MAXIS" );
        else
            df_say( "S6_NOJETGUN_RICH" );

        return;
    }

    if ( is_true( level.df_s6_said_hint ) )
        return;

    level.df_s6_said_hint = 1;
    df_say( "D6_HINT" );
}

// True when any player carries a Jet Gun (getweaponslistprimaries, the list _zm_weapons.gsc:197 walks).
df_s6_any_jetgun()
{
    foreach ( player in getplayers() )
    {
        foreach ( weapon in player getweaponslistprimaries() )
        {
            if ( df_s6_is_jetgun( weapon ) )
                return true;
        }
    }

    return false;
}

// self = player. Clears the carry state (the orb state is handled by the caller).
df_s6_carry_release()
{
    self.df_orb = undefined;
    self df_s6_prompt_clear( undefined );
    df_fx_stop( self.df_s6_carry_fx );
    self.df_s6_carry_fx = undefined;
}

// The charge riding the carrier: elec_torso (zm_transit_fx.gsc:38) for Richtofen or lava_burning (:40)
// for Maxis on the torso, replayed every second on a fresh tag_origin linked to J_SpineLower (the
// player spine tag vanilla uses for torso FX), each deleted before the next. Nothing while the orb is empty.
df_s6_carry_fx()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    fxname = "elec_torso";

    if ( df_s6_is_maxis() )
        fxname = "lava_burning";

    while ( isdefined( self.df_orb ) )
    {
        df_fx_stop( self.df_s6_carry_fx );
        self.df_s6_carry_fx = undefined;

        if ( !isdefined( level.df_s6_orb ) || level.df_s6_orb.charges <= 0 )
        {
            wait 0.5;
            continue;
        }

        ent = df_fx_loop( fxname, self.origin + ( 0, 0, 45 ) );

        if ( isdefined( ent ) )
            ent linkto( self, "J_SpineLower", ( 0, 0, 0 ), ( 0, 0, 0 ) );

        self.df_s6_carry_fx = ent;
        wait 0.8;
        df_fx_stop( self.df_s6_carry_fx );
        self.df_s6_carry_fx = undefined;
        wait 0.2;
    }
}

// A carrier who goes down (player_is_in_laststand, _zm_laststand.gsc:56) or is otherwise no longer a valid
// player drops the orb at the feet; one who leaves the game drops it where they last stood.
df_s6_carry_monitor()
{
    level endon( "end_game" );
    level endon( "df_skip_step6" );
    level endon( "df_s6_stop" );

    while ( true )
    {
        wait 0.1;
        orb = level.df_s6_orb;

        if ( !isdefined( orb ) || orb.state != "carried" )
            continue;

        carrier = orb.carrier;

        if ( !isdefined( carrier ) || !isplayer( carrier ) )
        {
            df_debug_print( "DF: s6 orb carrier left the game" );
            df_s6_orb_drop( orb.carrier_pos );
            continue;
        }

        orb.carrier_pos = carrier.origin;

        if ( carrier maps\mp\zombies\_zm_laststand::player_is_in_laststand() || !is_player_valid( carrier ) )
        {
            df_debug_print( "DF: s6 orb carrier went down" );
            df_s6_orb_drop( carrier.origin );
        }
    }
}

// The ball lands on the ground under pos (charges kept) and the return timer starts.
df_s6_orb_drop( pos )
{
    orb = level.df_s6_orb;

    if ( isdefined( orb.carrier ) && isplayer( orb.carrier ) )
        orb.carrier df_s6_carry_release();

    orb.carrier = undefined;
    orb.state = "dropped";
    orb.drop_id++;
    ground = df_ground( pos );
    df_s6_orb_show( ground + df_s6_orb_rest_offset() );
    playsoundatposition( "zmb_bus_emp_shutdown", ground );
    level thread df_s6_drop_timer( orb.drop_id );
    df_debug_print( "DF: s6 orb dropped at " + int( ground[0] ) + " " + int( ground[1] ) + " " + int( ground[2] ) + ", " + df_s6_drop_seconds() + " s to pick it up" );
}

// A disc left on the ground flies home (the nearer of the spawn and the table front, df_s6_home_pos;
// charges kept), df_soul_fly trail.
df_s6_drop_timer( drop_id )
{
    level endon( "end_game" );
    level endon( "df_skip_step6" );
    level endon( "df_s6_stop" );

    wait( df_s6_drop_seconds() );
    orb = level.df_s6_orb;

    if ( !isdefined( orb ) || orb.state != "dropped" || orb.drop_id != drop_id || !isdefined( orb.ent ) )
        return;

    from = orb.ent.origin;
    home = df_s6_home_pos( from );
    df_s6_orb_hide();
    orb.state = "waiting";
    level thread df_soul_fly( from + ( 0, 0, 20 ), home + ( 0, 0, 20 ) );
    df_s6_orb_show( home );
    df_debug_print( "DF: s6 orb returned home (" + int( home[0] ) + " " + int( home[1] ) + " " + int( home[2] ) + ")" );
}

// ----------------------------------------------------------------- prompts ----
// Several monitors want the player's prompt (orb pickup, socket, Jet Gun hint), so each one owns it by
// name: a monitor only removes the prompt it set itself. Orb and socket prompts (mechanic, df_prompt) win
// over the hint (puzzle, df_prompt_puzzle: hidden when level.df_hints == 0) because the hint monitor never
// overwrites another owner.

// self = player
df_s6_prompt_set( owner, text )
{
    if ( isdefined( self.df_s6_prompt_owner ) && self.df_s6_prompt_owner == owner && isdefined( self.df_s6_prompt_text ) && self.df_s6_prompt_text == text )
        return;

    self df_s6_prompt_hide();

    if ( owner == "hint" )
        self df_prompt_puzzle( 1, text );
    else
        self df_prompt( 1, text );

    self.df_s6_prompt_owner = owner;
    self.df_s6_prompt_text = text;
}

// self = player. Removes the prompt only if `owner` set it (or any prompt when owner is undefined).
df_s6_prompt_clear( owner )
{
    if ( !isdefined( self.df_s6_prompt_owner ) )
        return;

    if ( isdefined( owner ) && self.df_s6_prompt_owner != owner )
        return;

    self df_s6_prompt_hide();
    self.df_s6_prompt_owner = undefined;
    self.df_s6_prompt_text = undefined;
}

// self = player. Both prompt kinds off (cheap when already hidden).
df_s6_prompt_hide()
{
    self df_prompt( 0, undefined );
    self df_prompt_puzzle( 0, undefined );
}

// Richtofen: a Jet Gun holder within draw range of a charged node is told what to do (no bar showing yet):
// bring the orb first, or fire at the node while carrying it. Maxis: the orb CARRIER within range of a
// charged brazier is told to stand in the lava (S6_DRAW_LAVA_MAXIS once, the first time it happens).
// Puzzle hints: hidden when hints are off. The refused-draw buzz (df_s6_deny_check) rides the same poll.
df_s6_hint_monitor()
{
    level endon( "end_game" );
    level endon( "df_skip_step6" );
    level endon( "df_s6_stop" );

    range2 = df_s6_draw_range() * df_s6_draw_range();
    maxis = df_s6_is_maxis();

    while ( true )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            player df_s6_deny_check( range2, maxis );
            show = is_player_valid( player ) && !isdefined( player.df_s6_bar ) && isdefined( df_s6_charged_node_near( player.origin, range2 ) );

            if ( show && maxis )
                show = isdefined( player.df_orb );
            else if ( show )
                show = df_s6_is_jetgun( player getcurrentweapon() );

            if ( show )
            {
                text = "Fire the Jet Gun at it to draw the charge into the orb";

                if ( maxis )
                {
                    text = "Stand in the lava by the brazier to draw the charge";

                    if ( !is_true( level.df_s6_said_lava ) )
                    {
                        level.df_s6_said_lava = 1;
                        df_say( "S6_DRAW_LAVA_MAXIS" );
                    }
                }
                else if ( !isdefined( player.df_orb ) )
                    text = "Bring the orb here to take this charge";

                if ( !isdefined( player.df_s6_prompt_owner ) || player.df_s6_prompt_owner == "hint" )
                    player df_s6_prompt_set( "hint", text );

                continue;
            }

            player df_s6_prompt_clear( "hint" );
        }
    }
}

// self = player, polled every 0.1 s. A refused draw buzzes ONCE PER APPROACH (df_cue_deny = zmb_perks_packa_deny
// 2D to the carrier, art audit S6.5: it used to be console-only): the orb CARRIER within draw range of a
// charged node who cannot draw there, i.e. Richtofen without a Jet Gun in hand, Maxis not standing in the
// lava for 2 s straight. The denial is remembered per node until the carrier leaves that node's range (or
// draws), so walking around a brazier does not buzz on every step.
df_s6_deny_check( range2, maxis )
{
    node = undefined;

    if ( is_player_valid( self ) && isdefined( self.df_orb ) && !isdefined( self.df_s6_bar ) )
        node = df_s6_charged_node_near( self.origin, range2 );

    if ( !isdefined( node ) )
    {
        self.df_s6_deny_node = undefined;
        self.df_s6_deny_ms = undefined;
        return;
    }

    if ( isdefined( self.df_s6_deny_node ) && self.df_s6_deny_node == node.index )
        return;

    if ( maxis )
    {
        if ( self df_s6_on_lava() )
        {
            self.df_s6_deny_ms = undefined;
            return;
        }

        if ( !isdefined( self.df_s6_deny_ms ) )
            self.df_s6_deny_ms = gettime();

        if ( gettime() - self.df_s6_deny_ms < 2000 )
            return;
    }
    else if ( df_s6_is_jetgun( self getcurrentweapon() ) )
        return;

    self.df_s6_deny_node = node.index;
    self.df_s6_deny_ms = undefined;
    df_cue_deny( self );
    df_debug_print( "DF: s6 draw refused at node " + node.index + " (" + node.name + "): carrier " + self.name + " has no means to draw here" );
}

// Nearest charged (undrawn) node within range2 of pos, aim not considered.
df_s6_charged_node_near( pos, range2 )
{
    best = undefined;
    best_d2 = range2;

    foreach ( node in level.df_s6_nodes )
    {
        if ( node.state != "charged" )
            continue;

        d2 = distancesquared( pos, node.origin );

        if ( d2 < best_d2 )
        {
            best = node;
            best_d2 = d2;
        }
    }

    return best;
}

// ------------------------------------------------------------------- draw ----
// Every 0.05 s, per side (audit 2.3):
//   Richtofen: each ORB CARRIER firing the Jet Gun (is_jetgun_firing = engine spin > 0.2,
//   _zm_weap_jetgun.gsc:285) within 300 of a charged node and looking at it accumulates draw ticks on that
//   node. While firing, the heat is bled back down above 30 so the gun cannot break during a draw.
//   Maxis: each ORB CARRIER standing ON LAVA within 300 of a charged brazier accumulates ticks on the
//   nearest one (no aim, no weapon). 5 s of ticks pulls the charge into the orb.
df_s6_draw_monitor()
{
    level endon( "end_game" );
    level endon( "df_skip_step6" );
    level endon( "df_s6_stop" );

    range2 = df_s6_draw_range() * df_s6_draw_range();
    maxis = df_s6_is_maxis();

    while ( true )
    {
        wait 0.05;

        foreach ( player in getplayers() )
        {
            node = undefined;

            if ( maxis )
            {
                if ( is_player_valid( player ) && isdefined( player.df_orb ) && player df_s6_on_lava() )
                    node = df_s6_charged_node_near( player.origin, range2 );
            }
            else if ( is_player_valid( player ) && df_s6_is_jetgun( player getcurrentweapon() ) && player maps\mp\zombies\_zm_weap_jetgun::is_jetgun_firing() )
            {
                player df_s6_overheat_relief();

                if ( isdefined( player.df_orb ) )
                    node = player df_s6_aimed_node( range2 );
            }

            if ( !isdefined( node ) )
            {
                if ( maxis )
                    player df_s6_lava_debug( range2 );
                else
                    player df_s6_aim_debug( range2 );

                player df_s6_bar_sync( undefined );
                continue;
            }

            if ( node.draw_ticks == 0 )
            {
                df_touch( "step6" );
                df_debug_print( "DF: s6 drawing node " + node.index + " (" + node.name + ")" );
            }

            node.draw_ticks++;
            player df_s6_bar_sync( node );

            // a burst at the light every half second of progress (df_fx_burst: the loop ent dies after 0.6 s)
            if ( node.draw_ticks % 10 == 0 )
                df_fx_burst( df_s6_charge_fx(), df_s6_orb_pos( node ), 0.6 );

            if ( node.draw_ticks >= df_s6_draw_ticks() )
                df_s6_drain( node, player );
        }
    }
}

// self = player. Shows "Drawing the charge" with the node's progress while drawing, removes it otherwise.
// The hint prompt sits at the same screen spot, so it is cleared while the bar is up.
df_s6_bar_sync( node )
{
    // owner 2026-09-09: no bar. The draw is HEARD: the power-rise start + loop at the node while the charge
    // flows (zm_transit_power.gsc:399-409), stopped the moment the player stops drawing.
    if ( !isdefined( node ) )
    {
        if ( isdefined( self.df_s6_bar ) )
        {
            self.df_s6_bar stoploopsound();
            self.df_s6_bar delete();
        }

        self.df_s6_bar = undefined;
        return;
    }

    if ( !isdefined( self.df_s6_bar ) )
    {
        self df_s6_prompt_clear( "hint" );
        self.df_s6_bar = spawn( "script_origin", df_s6_orb_pos( node ) );
        self.df_s6_bar playsound( "zmb_power_rise_start" );
        self.df_s6_bar playloopsound( "zmb_power_rise_loop" );
    }
}

// self = player. Nearest charged node within range that the player is looking at (geteye, getplayerangles).
df_s6_aimed_node( range2 )
{
    eye = self geteye();
    forward = anglestoforward( self getplayerangles() );
    best = undefined;
    best_d2 = range2;

    foreach ( node in level.df_s6_nodes )
    {
        if ( node.state != "charged" )
            continue;

        target = df_s6_orb_pos( node );
        d2 = distancesquared( self.origin, node.origin );

        if ( d2 >= best_d2 )
            continue;

        if ( vectordot( forward, vectornormalize( target - eye ) ) < df_s6_draw_cos() )
            continue;

        best = node;
        best_d2 = d2;
    }

    return best;
}

// self = player. On lava right now: the vanilla burn flag (player_lava_damage sets self.is_burning for
// 0.5 s per damage pulse, zm_transit_lava.gsc:134-157) OR touching a lava_damage trigger volume
// (object_touching_lava, zm_transit_lava.gsc:9, the test vanilla runs on players and dropped weapons,
// zm_transit.gsc:1666). The OR bridges the gaps between damage pulses.
df_s6_on_lava()
{
    if ( is_true( self.is_burning ) )
        return true;

    return self maps\mp\zm_transit_lava::object_touching_lava();
}

// self = player. Once per second while carrying the orb near a charged brazier but not on lava: says so,
// so an owner test can tell "not in the lava" from "too far".
df_s6_lava_debug( range2 )
{
    if ( !is_player_valid( self ) || !isdefined( self.df_orb ) )
        return;

    if ( isdefined( self.df_s6_aim_dbg ) && gettime() - self.df_s6_aim_dbg < 1000 )
        return;

    node = df_s6_charged_node_near( self.origin, range2 );

    if ( !isdefined( node ) )
        return;

    self.df_s6_aim_dbg = gettime();
    df_debug_print( "DF: s6 carrier near node " + node.index + " but not on lava (stand in it to draw)" );
}

// self = player holding a firing Jet Gun. isweaponoverheating( 1 ) = heat value, ( 0 ) = locked.
// Same builtins vanilla uses outside dev blocks in watch_overheat (_zm_weap_jetgun.gsc:160). Threshold 30
// (audit section 5: at 50 the gun could still break into parts mid-draw). Richtofen only; when the act2_rich
// agent adds the level-wide Richtofen relief (audit 2.4) this one becomes redundant and can go.
// Once per game, the first time the gun runs hot (heat above 70) while a carrier draws, Richtofen's canon
// jet_low line (vox_zmba_sidequest_jet_low_0: vanilla plays it on a hot / locked Jet Gun at a lamp,
// zm_transit_sq.gsc:642-653) goes to Stuhlinger through df_vox_once (art audit section 5).
df_s6_overheat_relief()
{
    if ( self isweaponoverheating( 0 ) )
        return;

    heat = self isweaponoverheating( 1 );

    if ( heat > 70 && isdefined( self.df_orb ) && !is_true( level.df_s6_said_jet_low ) )
    {
        level.df_s6_said_jet_low = 1; // our own flag saves a df_vox_once call per tick once it has played
        df_vox_once( "vox_zmba_sidequest_jet_low_0", undefined );
        df_debug_print( "DF: s6 jet gun running hot during a draw (" + int( heat ) + "), jet_low line" );
    }

    if ( heat > 30 )
        self setweaponoverheating( 0, heat - 1 );
}

// The node gives up its charge into the carried orb: node visuals off, the SUB-GOAL cue at the draw point
// (df_cue_subgoal: zmb_sq_navcard_success 3D, the side flash and the canon node -> tower runner), the
// meteor ping (zmb_meteor_activate, zm_transit.gsc:3353), a trail from the light into the carrier, one more
// charge. The zmb_powerup_grabbed 2D to the carrier is gone (STEP DONE alias). When all are in: three
// rising PROGRESS clinks at the carrier (df_s6_ready_clinks) instead of the chime (art audit S6.3).
// `player` (optional) is the carrier.
df_s6_drain( node, player )
{
    if ( node.state != "charged" )
        return;

    node.draw_ticks = 0;
    node.state = "drained";
    pos = df_s6_orb_pos( node );
    df_s6_node_fx_off( node );
    df_cue_subgoal( pos ); // the chime alone (zmb_meteor_activate is a Step 1 tone now, and two sounds at once were mud)

    orb = level.df_s6_orb;
    orb.charges++;
    level.df_orbs_delivered = orb.charges;
    df_scav_carry_set( "orb", orb.charges, level.df_s6_target, player );
    ready_at = pos;

    if ( isdefined( player ) && isplayer( player ) )
    {
        level thread df_soul_fly( pos, player.origin + ( 0, 0, 40 ) );
        player df_s6_bar_sync( undefined );
        ready_at = player.origin + ( 0, 0, 40 );
    }
    else if ( isdefined( orb.ent ) )
        level thread df_soul_fly( pos, orb.ent.origin + ( 0, 0, 20 ) );

    df_debug_print( "DF: s6 charge " + orb.charges + "/" + level.df_s6_target + " in the orb (node " + node.index + " " + node.name + ")" );

    if ( orb.charges >= level.df_s6_target )
    {
        level thread df_s6_ready_clinks( ready_at );
        df_debug_print( "DF: s6 orb fully charged, bring it to the tower socket" );
    }
}

// Three PROGRESS clinks (df_cue_tick = zmb_buildable_piece_add 3D, zm_transit_sq.gsc:1074) 0.2 s apart at
// pos: the "ready" pattern of a fully charged orb (art audit S6.3). Thread it.
df_s6_ready_clinks( pos )
{
    level endon( "end_game" );

    for ( i = 0; i < 3; i++ )
    {
        df_cue_tick( pos );
        wait 0.2;
    }
}

// ------------------------------------------------------------------ place ----

// The carrier of a fully charged orb within 150 of the socket presses F once (df_press_use, polled every
// 0.05 s only for carriers in range) to place it in the relay. With charges missing the prompt says how
// many are left. Only carriers reach df_press_use here and only non-carriers in df_s6_pickup_monitor, so
// the two monitors never eat each other's press.
df_s6_socket_monitor()
{
    level endon( "end_game" );
    level endon( "df_skip_step6" );
    level endon( "df_s6_stop" );

    c = df_coord( "DF_SOCKET" );

    while ( true )
    {
        wait 0.05;
        orb = level.df_s6_orb;

        foreach ( player in getplayers() )
        {
            if ( !isdefined( player.df_orb ) )
                continue;

            near = is_player_valid( player ) && distancesquared( player.origin, c.origin ) < 150 * 150;

            if ( !near )
            {
                player df_s6_prompt_clear( "socket" );
                continue;
            }

            missing = level.df_s6_target - orb.charges;

            if ( missing > 0 )
            {
                player df_s6_prompt_set( "socket", "The orb needs " + missing + " more charge(s)" );
                continue;
            }

            player df_s6_prompt_set( "socket", "Press [{+activate}] to place the orb in the relay" );

            if ( !player df_press_use() )
                continue;

            if ( orb.state == "carried" && isdefined( orb.carrier ) && orb.carrier == player )
                df_s6_place( player );
            else
                player df_s6_carry_release();
        }
    }
}

// The orb goes into the relay (also used by the debug hook, whatever state it was in): power pulse
// (fx_zmb_tranzit_power_pulse, zm_transit_fx.gsc:117) 3 s + the side flash over the table (df_cue_side_flash)
// and the part-add clink (zmb_buildable_piece_add, zm_transit_sq.gsc:1074). ONE sting only: the uniform
// STEP DONE from df_complete (art audit S6.4: the 3D zmb_powerup_grabbed here doubled it within a second).
// Owner 2026-09-08: the disc does not vanish any more, it stays on the table's slot 2 (df_s6_orb_table_show).
df_s6_place( player )
{
    orb = level.df_s6_orb;

    if ( orb.state == "placed" )
        return;

    if ( isdefined( player ) && isplayer( player ) )
        player df_s6_carry_release();

    if ( isdefined( orb.carrier ) && isplayer( orb.carrier ) )
        orb.carrier df_s6_carry_release();

    orb.carrier = undefined;
    orb.state = "placed";
    df_s6_orb_table_show();
    level.df_orbs_delivered = level.df_s6_target;

    socket_pos = df_coord( "DF_SOCKET" ).origin;

    if ( isdefined( level.df_socket ) )
        socket_pos = level.df_socket.origin;

    pulse = df_fx_loop( "fx_zmb_tranzit_spark_int_runner", socket_pos + ( 0, 0, 30 ) );
    level thread df_s6_fx_stop_after( pulse, 3 );
    df_cue_side_flash( socket_pos + ( 0, 0, 30 ), undefined );
    df_snd_near( "zmb_buildable_piece_add", socket_pos, 700 );

    df_debug_print( "DF: s6 orb placed in the relay, resting on the table" );
    level notify( "df_s6_check" );
}

// Deletes an fx entity after `seconds`.
df_s6_fx_stop_after( ent, seconds )
{
    level endon( "end_game" );
    wait( seconds );
    df_fx_stop( ent );
}

// The node's "charged" visuals go out: set lamps go "drained" (dark, df_lamps.gsc); other nodes lose the
// beam, our fallback marker and the Act 2 visuals M2 exports on the node struct (.fx/.fx2/.snd).
df_s6_node_fx_off( node )
{
    if ( isdefined( node.lamp ) )
    {
        df_lamp_state_set( node.lamp, "drained" );
        return;
    }

    df_s6_beam_off( node );
    df_fx_stop( node.own_fx );
    node.own_fx = undefined;
    df_s6_node_hum_stop( node );

    src = node.src;

    if ( isdefined( src ) )
    {
        df_fx_stop( src.fx );
        src.fx = undefined;
        df_fx_stop( src.fx2 );
        src.fx2 = undefined;

        if ( isdefined( src.snd ) )
            src.snd delete();

        src.snd = undefined;
    }
}

// ---------------------------------------------------------------- cleanup ----

// "!df goto" past us / skip: stop the monitors and remove everything we spawned.
df_s6_skip_cleanup()
{
    level endon( "end_game" );
    level endon( "df_step6_done" );
    level waittill( "df_skip_step6" );

    level notify( "df_s6_stop" );
    df_s6_cleanup();
    df_s6_orb_hide(); // a placed orb survives df_s6_cleanup (it rests on the table), but not a skip
    df_scav_carry_clear( "orb" );
    df_debug_print( "DF: s6 skipped, world cleaned" );
}

// Ball, aura, hum, beams, carry FX, prompts, bars and our own fallback markers go away. Set lamps keep
// their current look (charged / drained, owned by df_lamps). A PLACED orb is left alone: it rests on the
// table for the rest of the game (df_s6_orb_table_show); the skip cleanup above removes that one.
df_s6_cleanup()
{
    df_s6_arrival_fx_stop();

    foreach ( player in getplayers() )
    {
        player df_s6_prompt_clear( undefined );
        player df_s6_bar_sync( undefined );
        player.df_s6_deny_node = undefined;
        player.df_s6_deny_ms = undefined;

        if ( isdefined( player.df_orb ) )
            player df_s6_carry_release();
    }

    if ( isdefined( level.df_s6_orb ) )
    {
        if ( level.df_s6_orb.state != "placed" )
            df_s6_orb_hide();

        level.df_s6_orb.carrier = undefined;
    }

    if ( !isdefined( level.df_s6_nodes ) )
        return;

    foreach ( node in level.df_s6_nodes )
    {
        df_s6_beam_off( node );
        df_fx_stop( node.own_fx );
        node.own_fx = undefined;
        df_s6_node_hum_stop( node );
    }
}

// ------------------------------------------------------------------ debug ----
// Hooks: "!df fire s6_orb" (ball to player 1), "s6_draw" (nearest charge into the orb), "s6_deliver"
// (all charges + placed), "s6_restart" (Step 7 fail contract: charged orb back in front of the socket),
// "orb_aura" (next aura candidate), "lamps" (df_lamps: set + states).

// "!df fire s6_draw": the charged node nearest to the caller (first player) gives its charge to the orb
// without the Jet Gun. Nobody carrying it: the first player gets the orb first.
df_s6_debug_draw_hook()
{
    level endon( "end_game" );
    level endon( "df_skip_step6" );
    level endon( "df_s6_stop" );

    while ( true )
    {
        level waittill( "df_debug_s6_draw" );

        players = getplayers();
        from = df_coord( "DF_SOCKET" ).origin;

        if ( players.size > 0 )
            from = players[0].origin;

        best = undefined;
        best_d2 = undefined;

        foreach ( node in level.df_s6_nodes )
        {
            if ( node.state != "charged" )
                continue;

            d2 = distancesquared( from, node.origin );

            if ( !isdefined( best ) || d2 < best_d2 )
            {
                best = node;
                best_d2 = d2;
            }
        }

        if ( !isdefined( best ) )
        {
            df_debug_print( "DF: s6 debug draw: no charged node left" );
            continue;
        }

        orb = level.df_s6_orb;

        if ( orb.state != "carried" && players.size > 0 && orb.state != "placed" )
            players[0] df_s6_orb_take();

        df_debug_print( "DF: s6 debug draw on node " + best.index );
        df_s6_drain( best, orb.carrier );
    }
}

// "!df fire s6_deliver": every remaining charge goes into the orb and the orb is placed.
df_s6_debug_deliver_hook()
{
    level endon( "end_game" );
    level endon( "df_skip_step6" );
    level endon( "df_s6_stop" );

    while ( true )
    {
        level waittill( "df_debug_s6_deliver" );

        foreach ( node in level.df_s6_nodes )
        {
            if ( node.state == "charged" )
                df_s6_drain( node, undefined );
        }

        df_debug_print( "DF: s6 debug deliver: orb placed" );
        df_s6_place( level.df_s6_orb.carrier );
    }
}

// "!df fire s6_orb": the ball is brought to the first player's feet (waiting there).
df_s6_debug_orb_hook()
{
    level endon( "end_game" );
    level endon( "df_skip_step6" );
    level endon( "df_s6_stop" );

    while ( true )
    {
        level waittill( "df_debug_s6_orb" );

        players = getplayers();
        orb = level.df_s6_orb;

        if ( players.size == 0 || !isdefined( orb ) || orb.state == "placed" )
        {
            df_debug_print( "DF: s6 debug orb: nothing to move" );
            continue;
        }

        if ( orb.state == "carried" && isdefined( orb.carrier ) && isplayer( orb.carrier ) )
            orb.carrier df_s6_carry_release();

        orb.carrier = undefined;
        orb.state = "waiting";
        orb.drop_id++;
        pos = players[0].origin + anglestoforward( players[0].angles ) * 60;
        df_s6_orb_show( df_ground( pos ) + df_s6_orb_rest_offset() );
        df_debug_print( "DF: s6 debug orb: orb placed in front of " + players[0].name );
    }
}

// self = player. Once per second while firing the Jet Gun near a charged node without being counted:
// prints why (no orb / distance / aim), so an owner test can tell "not aiming" from "not firing".
df_s6_aim_debug( range2 )
{
    if ( !is_player_valid( self ) || !df_s6_is_jetgun( self getcurrentweapon() ) || !self maps\mp\zombies\_zm_weap_jetgun::is_jetgun_firing() )
        return;

    if ( isdefined( self.df_s6_aim_dbg ) && gettime() - self.df_s6_aim_dbg < 1000 )
        return;

    self.df_s6_aim_dbg = gettime();
    node = df_s6_charged_node_near( self.origin, range2 );

    if ( !isdefined( node ) )
    {
        df_debug_print( "DF: s6 jet gun firing but no charged node within " + df_s6_draw_range() );
        return;
    }

    if ( !isdefined( self.df_orb ) )
    {
        df_debug_print( "DF: s6 firing near node " + node.index + " but not carrying the orb (it waits at DF_ORB_SPAWN)" );
        return;
    }

    dot = vectordot( anglestoforward( self getplayerangles() ), vectornormalize( df_s6_orb_pos( node ) - self geteye() ) );
    df_debug_print( "DF: s6 firing near node " + node.index + ", aim " + int( dot * 100 ) + "/100 (need " + int( df_s6_draw_cos() * 100 ) + ")" );
}
