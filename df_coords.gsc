// Dead Frequency - world anchors and the model registry.
//
// Positions are derived from TranZit's own entity list (tools/zm_transit.d3dbsp.ents.txt, dumped from
// zm_transit.ff with OpenAssetTools Unlinker): walkable path nodes, zombie/dog spawn structs (always
// solid ground, never lava), vanilla part-spawn structs, the tower legs. Wall-mounted props find their
// wall at runtime with a horizontal trace from the room centre; heights are snapped to the real floor.
//
// Models come from df_models_init() (kind -> model, plus the model's facing convention). Step files never
// name a model: they call df_model( "<kind>" ). The anchors below take their model from the same registry,
// so a swap is one line there. Heights that depend on the model come from the registry too:
// df_model_top_z( kind ) = top surface above the origin (table top, brazier rim), df_model_rest_z( kind ) =
// how high the origin sits above the surface the prop rests on (tube centre, orb hover; 0 for base pivots),
// df_model_offset( kind ) = stacking offset of a piece on its parent (relay_top / relay_mast on the relay).
// Every number is measured on the glTF export (C:\Games\t6\model_dump\<zone>\model_export, POSITION bounds).
//
// Check in game: `!df show` (prints the model per anchor), `!df tp <KEY>`, `!df dump`, then tune live
// with `!df ang|lift|move` and paste the printed [SPOT] line into df_apply_overrides(). Overrides always win.
// Compare candidate models side by side with `!df catalog <keyword>` (df_catalog_models below) and put one
// into the registry with `!df catalog pick <n> <kind>`.
//
// The table (owner 2026-09-08): everything the players build or deposit under the tower goes onto ONE
// table, anchor DF_TABLE (kind "table"), instead of the old wall-mounted breaker panel. Its top carries
// three slots left to right (df_table_slot 0/1/2 = relay, key card, orb) and df_table_front() is the floor
// spot in front of it. DF_SOCKET stays the name every step uses for "the place at the tower" and is simply
// moved onto DF_TABLE (df_table_sync_socket), so no step file needed a new anchor for proximity or fx.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_catalog; // measured model sizes (df_catalog_lookup), used by df_model_top_z

// Every anchor. Wall props take their pitch/roll and wall-facing yaw offset from the model registry.
df_coords_init()
{
    if ( isdefined( level.df_coords ) )
        return;

    level.df_coords = [];

    // ---- Depot TVs (owner decision 2026-09-07): one inside on a wall of the phone room, three outside
    //      around the depot on dog spawn points (solid ground), facing the building. Audio stays on the phones.
    //      The "tv" model (CRT tube posed upright) has its origin at mid height: the anchors carry
    //      df_model_rest_z( "tv" ) above the floor so the tube stands ON the ground instead of half in it.
    depot_center = ( -6754, 5314, -40 );
    tv_rest = ( 0, 0, df_model_rest_z( "tv" ) );
    df_coords_on_walls( "DF_TV_", 1, ( -6475, 5324, -55 ), 75, 420, 20, tv_rest[2], "tv" );
    df_coord_set_facing( "DF_TV_2", df_ground( ( -6244.5, 5500.5, -20 ) ) + tv_rest, depot_center, "tv" );
    df_coord_set_facing( "DF_TV_3", df_ground( ( -6196.5, 4740.5, -20 ) ) + tv_rest, depot_center, "tv" );
    df_coord_set_facing( "DF_TV_4", df_ground( ( -7452.5, 4748.5, -20 ) ) + tv_rest, depot_center, "tv" );

    // ---- Depot wall phones (recorded in game with !spot). Player spots: the phones themselves are map
    //      statics (not in the entity dump), so no model is spawned here.
    df_coord_set( "DF_PHONE_1", ( -6455, 5309, -55 ), ( 0, -67, 0 ), undefined );
    df_coord_set( "DF_PHONE_2", ( -6485, 5299, -55 ), ( 0, -62, 0 ), undefined );

    // ---- The far signal light of Step 1 (owner spot 2026-09-11, outside the Depot fence, low ground): flashes the
    //      pipe order. The light sits 30 above the anchor. Move it: !df grab DF_SIGNAL / !df move DF_SIGNAL ...
    df_coord_set( "DF_SIGNAL", ( -6244, 5361, -187 ), ( 0, 88, 0 ), undefined ); // owner move 2026-09-11

    // ---- The hum that points at the signal light during Step 1 (owner spot 2026-09-11): zmb_power_on_loop,
    //      3D, audible from 525 to 750 units, so the Depot hears where to look.
    df_coord_set( "DF_SIGNAL_SND", ( -6245, 5085, -67 ), ( 0, -90, 0 ), undefined ); // owner move 2026-09-11

    // ---- Where the coil (the phone's relay part, kind "receiver") lands when Step 1 is solved. Default: the
    //      phone spot. Move it like any prop: `!df tp DF_COIL_DROP`, `!df move DF_COIL_DROP <fwd> <right> <up>`
    //      or `!df grab receiver`, then paste the printed line into df_apply_overrides (owner 2026-09-11).
    df_coord_set( "DF_COIL_DROP", ( -6455, 5309, -55 ), ( 0, -67, 0 ), df_model( "receiver" ) );

    // ---- Salvage parts A/B: an unused alternate of the vanilla jet gun part spawns (cabin = gauges,
    //      tunnel = engine), re-evaluated whenever needed so they never overlap the real part.
    //      Part C: dog spawn point at the cornfield edge, away from the lamp post.
    df_coords_refresh_dynamic();
    df_coord_set( "DF_PART_C", df_ground( ( 10123.5, -1477.5, -217 ) ), ( 0, 90, 0 ), df_model( "part_c" ) );

    // ---- Tower: legs at x 7452/7844, y -268/-660. NavCard table on the west side (7462, -457),
    //      so the relay socket goes between the two east legs. Derived fallback only: since 2026-09-08 the
    //      socket IS the table (df_table_sync_socket at the end of this function moves DF_SOCKET onto
    //      DF_TABLE); the wall anchor stays so `!df show` still has a socket entry and a pre-table save
    //      of df_apply_overrides keeps working.
    df_coord_on_nearest_wall( "DF_SOCKET", ( 7790, -465, -130 ), 420, 11, 40, "socket" );
    df_coord_set( "DF_TOWER_RETURN", ( 7552, -512, -72 ), ( 0, 0, 0 ), undefined );

    // ---- The table under the tower (owner 2026-09-08): the relay, the key card and the orb are all
    //      deposited on it (df_table_slot). Derived fallback = the owner's spot on the ground with its
    //      front along +x; df_apply_overrides pins the final one.
    df_coord_set( "DF_TABLE", df_ground( ( 7771, -448, -202 ) ) + ( 0, 0, 1 ), df_model_angles( "table", 0 ), df_model( "table" ) );

    // ---- Step 6 orb: ONE spot per side (audit 1.3, 2026-09-08). Maxis: the owner's spot under the tower
    //      (DF_ORB_TOWER, pinned in df_apply_overrides). Richtofen: the far side of the map so the carry still
    //      crosses it (DF_ORB_DINER, the diner's own player respawn point, tools/zm_transit.d3dbsp.ents.txt
    //      "player_respawn_point" -5991 -7686.5 34.46, next to the stop_1 bus stop zone at -5185 -7517).
    //      DF_ORB_SPAWN stays the key Step 6 reads: it is a COPY of the locked side's anchor
    //      (df_orb_spawn_sync on df_side_locked; the tower until a side is locked), so df_act3_vacuum needs no
    //      change; df_orb_spawn_for_side() is the explicit accessor. Rest height above the floor is the step's
    //      business (df_act3_vacuum re-grounds the anchor and adds its own rest offset).
    df_coord_set( "DF_ORB_TOWER", df_ground( ( 7628, -471, -207 ) ) + ( 0, 0, 1 ), ( 0, 0, 0 ), df_model( "orb" ) );
    df_coord_set( "DF_ORB_DINER", df_ground( ( -5991, -7686, 34 ) ) + ( 0, 0, 1 ), ( 0, 0, 0 ), df_model( "orb" ) );

    // ---- Step 6 orb landing: one of three spots at random, on both sides (owner 2026-09-11): the diner (as before),
    //      Town (1401 -445 -67) and the power station (11720 8491 -575). Picked when the side locks (df_orb_spawn_sync).
    df_coord_set( "DF_ORB_SPOT_1", df_ground( ( -5991, -7686, 34 ) ) + ( 0, 0, 1 ), ( 0, 0, 0 ), df_model( "orb" ) );
    df_coord_set( "DF_ORB_SPOT_2", df_ground( ( 1401, -445, -67 ) ) + ( 0, 0, 1 ), ( 0, -8, 0 ), df_model( "orb" ) );
    df_coord_set( "DF_ORB_SPOT_3", df_ground( ( 11720, 8491, -575 ) ) + ( 0, 0, 1 ), ( 0, -88, 0 ), df_model( "orb" ) );

    // ---- Step 6, Richtofen: the sparking transformer block on the small bridge at the power station exit (owner spot
    //      2026-09-11, INSIDE the block: 11095 8365 -529; the player fires from the bridge at 11084 8445 -543). The four
    //      Jet Gun draws happen here (df_act2_rich df_r1_export_nodes). No map entity marks it: the coordinate is the anchor.
    df_coord_set( "DF_CORE", ( 11092, 8361, -496 ), ( 0, 113, 0 ), undefined ); // owner placement 2026-09-11 (!df grab)
    df_coord_set( "DF_ORB_SPAWN", df_ground( ( 7628, -471, -207 ) ) + ( 0, 0, 1 ), ( 0, 0, 0 ), df_model( "orb" ) );

    // ---- Farm barn: four fuse boxes, each on the wall the owner faced from these spots (recorded with !pos
    //      on 2026-09-07). The "fuse" model is the breaker panel p6_zm_buildable_pswitch_body: 36 wide, 63 tall,
    //      16 deep, pivot at its BASE and 5..11 units in front of its back face (glTF bounds). lift 18 puts its
    //      centre at chest height (18 + 63 / 2 = 50, where the old 20-tall box was centred); off_wall 11 keeps
    //      the back out of the wall whichever way the depth axis turns (worst case a 6-unit gap).
    df_coords_row_on_wall( "DF_FUSE_1", 1, ( 8808, -5767, 50 ), -3, 0, 50, 6, "fuse" );
    df_coords_row_on_wall( "DF_FUSE_2", 1, ( 8526, -5599, 50 ), 89, 0, 50, 6, "fuse" );
    df_coords_row_on_wall( "DF_FUSE_3", 1, ( 8802, -5872, 50 ), -93, 0, 50, 6, "fuse" );
    df_coords_row_on_wall( "DF_FUSE_4", 1, ( 8530, -5840, 50 ), -87, 0, 50, 6, "fuse" );

    // ---- R1 key card appears here (owner 2026-09-08): a barn wall next to the fuse boxes, chest height,
    //      standing upright with its face towards the room (card pose in df_models_init). Derived fallback
    //      = the same wall spot; df_apply_overrides pins the final one. Read by df_act2_rich. 84 units along
    //      the wall from DF_FUSE_4 (x 8530 vs 8614): clear of the 36-wide panel (half width 18).
    df_coords_row_on_wall( "DF_CARD_SPAWN", 1, ( 8613, -5840, 50 ), -90, 0, 50, 4, "card" );

    // ---- Braziers (owner redesign 2026-09-09, Blood-of-the-Dead style): FOUR of them, always, in a row
    //      along the lava field between the tower and the cornfield lamp (x 8831..10363, y -1073..-1240), close
    //      enough to carry one ember around all of them. Derived fallback = the owner's feet spots on the
    //      ground; df_apply_overrides pins the final ones (front towards where the owner stood). The old
    //      lava-edge spots (Farm 8118 -6285, Town 1731 -115, Power 9992 7555) are gone.
    df_coord_set( "DF_BRAZIER_1", df_ground( ( 8831, -1185, -208 ) ), ( 0, 59, 0 ), df_model( "brazier" ) );
    df_coord_set( "DF_BRAZIER_2", df_ground( ( 9296, -1073, -203 ) ), ( 0, 300, 0 ), df_model( "brazier" ) );
    df_coord_set( "DF_BRAZIER_3", df_ground( ( 9913, -1193, -217 ) ), ( 0, 59, 0 ), df_model( "brazier" ) );
    df_coord_set( "DF_BRAZIER_4", df_ground( ( 10363, -1240, -215 ) ), ( 0, 213, 0 ), df_model( "brazier" ) );

    // ---- Nacht bunker: walkable nodes around the room centre (13520, -776), players face east (+x).
    // owner spot 2026-09-11 ([CHEAT] pos 13703 -822 -189 | ang 0 1 0), the four players 40 apart around it
    df_coord_set( "DF_NACHT_SPAWN_1", ( 13703, -822, -189 ), ( 0, 1, 0 ), undefined );
    df_coord_set( "DF_NACHT_SPAWN_2", ( 13703, -862, -189 ), ( 0, 1, 0 ), undefined );
    df_coord_set( "DF_NACHT_SPAWN_3", ( 13703, -782, -189 ), ( 0, 1, 0 ), undefined );
    df_coord_set( "DF_NACHT_SPAWN_4", ( 13663, -822, -189 ), ( 0, 1, 0 ), undefined );

    df_apply_overrides();
    df_table_sync_socket();

    // ---- M1 denizen hole (owner 2026-09-09): the spot the hole opens ON the ground in front of the table.
    //      Derived fallback = df_table_front() + 30 further out along the table's front (the old hard-coded
    //      spot in df_act2_maxis), computed AFTER the overrides so it follows the pinned table; the owner's
    //      own spot in df_apply_overrides wins (df_coord_set skips a pinned key). Read by df_m1_portal_open.
    df_coord_set( "DF_PORTAL", df_ground( df_table_front() + anglestoforward( ( 0, df_table_yaw(), 0 ) ) * 30 + ( 0, 0, 20 ) ), ( 0, df_table_yaw(), 0 ), df_model( "portal" ) );
    df_orb_spawn_sync();
    level thread df_orb_spawn_side_watch();
    level thread df_table_demo_hook();
    level thread df_beam_test_hook();
    df_debug_print( "DF: " + getarraykeys( level.df_coords ).size + " anchors derived" );
    df_debug_print( df_table_line() );
}

// ------------------------------------------------------------- orb spawn ----
// Two spots, one key. The Richtofen path (audit 1.3: Step 6 should cross the map) starts the orb at the
// diner, the Maxis path keeps the owner's spot under the tower. Step 6 reads DF_ORB_SPAWN (df_s6_spawn_pos)
// when it starts, long after the side lock, so keeping DF_ORB_SPAWN equal to the side's anchor is enough.

// The anchor struct of the locked side (DF_ORB_DINER for "rich", DF_ORB_TOWER otherwise, including no side).
// One of the three landing spots at random, either side (owner 2026-09-11). The old per-side anchors stay as
// fallbacks when the spots are missing.
df_orb_spawn_for_side()
{
    spots = [];

    for ( i = 1; i <= 3; i++ )
    {
        if ( isdefined( level.df_coords["DF_ORB_SPOT_" + i] ) )
            spots[spots.size] = level.df_coords["DF_ORB_SPOT_" + i];
    }

    if ( spots.size > 0 )
    {
        pick = random( spots );
        df_debug_print( "DF: orb landing spot " + int( pick.origin[0] ) + " " + int( pick.origin[1] ) + " " + int( pick.origin[2] ) );
        return pick;
    }

    if ( isdefined( level.df_side ) && level.df_side == "rich" && isdefined( level.df_coords["DF_ORB_DINER"] ) )
        return level.df_coords["DF_ORB_DINER"];

    return level.df_coords["DF_ORB_TOWER"];
}

// Copies the side's anchor into DF_ORB_SPAWN (origin, angles, model) and pins it.
df_orb_spawn_sync()
{
    src = df_orb_spawn_for_side();

    if ( !isdefined( src ) )
        return;

    if ( !isdefined( level.df_coords["DF_ORB_SPAWN"] ) )
        df_coord_set( "DF_ORB_SPAWN", src.origin, src.angles, src.model );

    d = level.df_coords["DF_ORB_SPAWN"];
    d.origin = src.origin;
    d.angles = src.angles;
    d.model = src.model;
    d.overridden = 1;
}

// Re-syncs on every side lock (Step 4 socket, "!df side", "!df goto"; df_steps df_set_side notifies it).
df_orb_spawn_side_watch()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_side_locked", side );
        df_orb_spawn_sync();
        df_debug_print( "DF: orb spawn for side " + side + ": " + df_vec_str( level.df_coords["DF_ORB_SPAWN"].origin ) );
    }
}

// The boot line for the table: where it stands, which way it faces and the three slot positions, so the
// owner can compare what they see with what the script thinks (`!df show` draws the same points).
df_table_line()
{
    c = df_coord( "DF_TABLE" );
    s0 = df_table_slot( 0 );
    s1 = df_table_slot( 1 );
    s2 = df_table_slot( 2 );
    f = df_table_front();
    return "DF: table at " + df_vec_str( c.origin ) + " (front yaw " + int( df_table_yaw() ) + ", top +" + int( df_model_top_z( "table" ) ) + "), slots " + df_vec_str( s0 ) + " | " + df_vec_str( s1 ) + " | " + df_vec_str( s2 ) + ", front " + df_vec_str( f );
}

// "x y z" with whole numbers (console lines only).
df_vec_str( v )
{
    return int( v[0] ) + " " + int( v[1] ) + " " + int( v[2] );
}

// The owner's final coordinates (in-game test 2026-09-08). They win over every derived anchor above.
// Each line is the spot the owner recorded: feet position + the yaw looked at. Two paste formats:
//     df_coord_override_ground( "KEY", ( feet ), yaw, "kind" )                 prop on the floor at the spot, front towards the player
//     df_coord_override_ground_front( "KEY", ( pos ), yaw, "kind" )            prop on the floor at the spot, front ALONG that yaw
//     df_coord_override( "KEY", ( x, y, z ), ( p, y, r ) )                     raw [SPOT] console line (after !df ang|lift|move)
//     df_coord_override_rest( "KEY", ( x, y, z ), ( p, y, r ), "kind" )        raw line of a FLOOR spot + the kind's rest height
df_apply_overrides()
{
    // Depot TVs: four spots on the ground around the depot, screen towards where the owner stood.
    // owner-placed with !df grab on 2026-09-08 (exact [PLACE] lines recorded with a base-pivot model, so they
    // are floor spots); the CRT tube's origin is its centre, df_coord_override_rest adds df_model_rest_z( "tv" ).
    df_coord_override_rest( "DF_TV_1", ( -6269, 5593, -55 ), ( 0, 284, 0 ), "tv" );
    df_coord_override_rest( "DF_TV_2", ( -6313, 4117, -63 ), ( 0, 99, 0 ), "tv" );
    df_coord_override_rest( "DF_TV_3", ( -7234, 4588, -55 ), ( 0, 175, 0 ), "tv" ); // owner move 2026-09-11
    df_coord_override_rest( "DF_TV_4", ( -6884, 5627, -55 ), ( 0, 285, 0 ), "tv" ); // owner move 2026-09-11

    // Salvage parts on the ground at the spots (A cabin, B farm upper level, C Nacht bunker).
    // owner-placed with !df grab on 2026-09-08
    df_coord_override( "DF_PART_A", ( -4830, -7978, -29 ), ( 0, 130, 0 ) );
    df_coord_override( "DF_PART_B", ( 8149, -5088, 52 ), ( 0, 401, 0 ) );
    df_coord_override( "DF_PART_C", ( 14077, -538, -137 ), ( 0, 345, 0 ) );

    // Where the coil lands after Step 1 (owner-placed with !df grab on 2026-09-11, Depot floor near the phone)
    df_coord_override( "DF_COIL_DROP", ( -6311, 5019, -46 ), ( 0, 390, 0 ) ); // owner move 2026-09-11 (second spot)

    // R1 key card: on the barn wall faced from the spot, chest height (fallback when no wall is within
    // 250 units: 40 units in front of the spot at the same height, standing upright).
    // owner-placed with !df grab on 2026-09-08 (pitch 90 = the card stands upright against the barn wall)
    df_coord_override( "DF_CARD_SPAWN", ( 8614, -5864, 91 ), ( 90, 90, 0 ) );

    // Step 6 orb, Maxis side: the ground under the tower at the owner's spot. Richtofen side: the diner (the
    // diner's player respawn point, a spot that is always walkable and off the road). DF_ORB_SPAWN itself is
    // never pinned here: df_orb_spawn_sync copies the side's anchor into it after the overrides.
    df_coord_override_ground( "DF_ORB_TOWER", ( 7628, -471, -207 ), -2, "orb" );
    df_coord_override_ground( "DF_ORB_DINER", ( -5991, -7686, 34 ), 0, "orb" );

    // The table under the tower (owner spot [CHEAT] pos 7771 -448 -202 | ang 0 0 0): its front points
    // along +x (yaw 0), the direction the owner was looking, so the long side of the table lies across
    // that view (the "table" kind's +90 yaw offset does that turn) and the three slots run left to right
    // for a player standing here looking along yaw 0.
    df_coord_override_ground_front( "DF_TABLE", ( 7771, -448, -202 ), 0, "table" );

    // M1 denizen hole ON the ground at the owner's spot in front of the table (owner 2026-09-09,
    // [CHEAT] pos 7623 -457 -207 | ang 0 -1 0); the hole is round, the yaw only matters for `!df tp`.
    df_coord_override_ground( "DF_PORTAL", ( 7623, -457, -207 ), -1, "portal" );

    // The four M2 braziers (owner 2026-09-09, feet + look yaw, on the ground): a row along the lava between
    // the tower and the cornfield lamp. Always four, whatever the player count (df_m2_place_braziers).
    df_coord_override_ground( "DF_BRAZIER_1", ( 8831, -1185, -208 ), -121, "brazier" );
    df_coord_override_ground( "DF_BRAZIER_2", ( 9296, -1073, -203 ), 120, "brazier" );
    df_coord_override_ground( "DF_BRAZIER_3", ( 9913, -1193, -217 ), -121, "brazier" );
    df_coord_override_ground( "DF_BRAZIER_4", ( 10363, -1240, -215 ), 33, "brazier" );
}

// Owner paste format: a raw [SPOT] / [PLACE] line whose position is a FLOOR spot, for a kind whose model
// origin is not at its base (the CRT tube): the kind's rest height is added, then pinned like df_coord_override.
// The pasted numbers stay exactly what the console printed.
df_coord_override_rest( key, floor_pos, angles, kind )
{
    df_coord_override( key, floor_pos + ( 0, 0, df_model_rest_z( kind ) ), angles );
    level.df_coords[key].model = df_model( kind );
}

// Owner paste format: a prop of `kind` on the floor at the recorded feet position, its front turned towards
// where the player stood (yaw + 180), then pinned like df_coord_override.
df_coord_override_ground( key, feet, yaw, kind )
{
    if ( isdefined( level.df_coords[key] ) )
        level.df_coords[key].overridden = 0;

    df_coord_set( key, df_ground( feet ) + ( 0, 0, 1 ), df_model_angles( kind, yaw + 180 ), df_model( kind ) );
    level.df_coords[key].overridden = 1;
}

// Owner paste format for a prop whose own facing was recorded (not a spot to look from): on the floor at
// `pos`, front pointing ALONG `front_yaw`, then pinned like df_coord_override.
df_coord_override_ground_front( key, pos, front_yaw, kind )
{
    if ( isdefined( level.df_coords[key] ) )
        level.df_coords[key].overridden = 0;

    df_coord_set( key, df_ground( pos ) + ( 0, 0, 1 ), df_model_angles( kind, front_yaw ), df_model( kind ) );
    level.df_coords[key].overridden = 1;

    if ( key == "DF_TABLE" )
        df_table_sync_socket();
}

// ------------------------------------------------------------------ table ----
// The one place under the tower where things are deposited (owner 2026-09-08). DF_SOCKET is moved onto it
// so every existing step keeps working: proximity checks, prompts, fx and the Step 7 orb all read
// df_coord( "DF_SOCKET" ).origin. The three slots are on the table TOP (df_model_top_z), left to right as
// seen by a player standing at the table looking along its front yaw (slot 0 = left):
//     slot 0  the relay plugged in at Step 4 (df_act1)
//     slot 1  the key card, left on the table after R1 (df_act2_rich)
//     slot 2  the charged orb of Step 6, lifted by Step 7 and put back there (df_act3_vacuum / df_act3_hold)
// A slot returns the point ON the top, so a caller adds the same rest offset it would add on the floor.

// Distance between two slots along the table's long side (the pap table is 54 long: 3 slots 18 apart fit
// with a hand's width of margin). Change here if the owner swaps in a wider or narrower model; a NEGATIVE
// value mirrors the order (slot 0 on the other end) without touching anything else.
df_table_slot_spacing()
{
    return 18;
}

// Front yaw of the table: the stored yaw minus the "table" kind's own yaw offset, so it stays right after
// `!df ang DF_TABLE ...` or a model swap.
df_table_yaw()
{
    c = df_coord( "DF_TABLE" );
    yaw = 0;

    if ( isdefined( c ) )
        yaw = c.angles[1];

    if ( isdefined( level.df_model_yawoff ) && isdefined( level.df_model_yawoff["table"] ) )
        yaw -= level.df_model_yawoff["table"];

    return yaw;
}

// World position of slot n (0, 1, 2) on the table top. n = 0 is on the left of a player looking along the
// table's front yaw (anglestoright is the right-hand direction, so -right is their left).
df_table_slot( n )
{
    c = df_coord( "DF_TABLE" );

    if ( !isdefined( c ) )
        return ( 7771, -448, -180 ); // the owner's spot plus a bench height, should never be needed

    right = anglestoright( ( 0, df_table_yaw(), 0 ) );
    return c.origin + right * ( ( n - 1 ) * df_table_slot_spacing() ) + ( 0, 0, df_model_top_z( "table" ) );
}

// The floor 40 units in front of the table: where a dropped or returned orb rests (Step 6 restart) and
// the reference point the M1 denizen hole opens further out from.
df_table_front()
{
    c = df_coord( "DF_TABLE" );

    if ( !isdefined( c ) )
        return ( 7811, -448, -202 );

    return df_ground( c.origin + anglestoforward( ( 0, df_table_yaw(), 0 ) ) * 40 + ( 0, 0, 20 ) );
}

// DF_SOCKET follows DF_TABLE: same origin and angles (the "socket" kind's +90 yaw offset then still
// resolves to the table front in the older helpers that read the socket yaw). The socket keeps its model
// so `!df show` still previews the old panel, but no step spawns it any more (df_act1 spawns the table).
df_table_sync_socket()
{
    t = level.df_coords["DF_TABLE"];
    s = level.df_coords["DF_SOCKET"];

    if ( !isdefined( t ) || !isdefined( s ) )
        return;

    s.origin = t.origin;
    s.angles = t.angles;
    s.overridden = 1;
}

// Anchors that depend on what vanilla spawned this game. Safe to call again at any time.
df_coords_refresh_dynamic()
{
    df_coord_from_free_struct( "DF_PART_A", "jetgun_zm", "jetgun_zm_p6_zm_buildable_jetgun_guages", df_model( "part_a" ) );
    df_coord_from_free_struct( "DF_PART_B", "jetgun_zm", "jetgun_zm_p6_zm_buildable_jetgun_engine", df_model( "part_b" ) );
}

// ---------------------------------------------------------------- helpers ----

// The anchor struct (.origin .angles .model) for a key, or undefined.
df_coord( key )
{
    if ( !isdefined( level.df_coords ) )
        df_coords_init();

    return level.df_coords[key];
}

// Store an anchor unless a live override (!df ang|lift|move or df_coord_override) already pinned it.
df_coord_set( key, origin, angles, model )
{
    c = spawnstruct();
    c.origin = origin;
    c.angles = angles;
    c.model = model;

    if ( isdefined( level.df_coords[key] ) && is_true( level.df_coords[key].overridden ) )
        return;

    level.df_coords[key] = c;
}

// A prop of `kind` at `origin` turned so its front (per the registry convention) faces `look_at`.
df_coord_set_facing( key, origin, look_at, kind )
{
    dir = look_at - origin;
    yaw = vectortoangles( ( dir[0], dir[1], 0 ) )[1];
    df_coord_set( key, origin, df_model_angles( kind, yaw ), df_model( kind ) );
}

// Pin an anchor to a verified position (df_apply_overrides paste format).
df_coord_override( key, origin, angles )
{
    if ( !isdefined( level.df_coords[key] ) )
        df_coord_set( key, origin, angles, undefined );

    level.df_coords[key].origin = origin;
    level.df_coords[key].angles = angles;
    level.df_coords[key].overridden = 1;

    // pinning the table (df_apply_overrides, a pasted [SPOT] line, `!df grab DF_TABLE`) drags DF_SOCKET
    if ( key == "DF_TABLE" )
        df_table_sync_socket();
}

// "[SPOT] KEY | x y z | p y r | model" - same format as cheats_zm !spot, ready for df_apply_overrides().
df_coord_line( key )
{
    c = level.df_coords[key];
    model = "-";

    if ( isdefined( c.model ) )
        model = c.model;

    return "[SPOT] " + key + " | " + int( c.origin[0] ) + " " + int( c.origin[1] ) + " " + int( c.origin[2] ) + " | " + int( c.angles[0] ) + " " + int( c.angles[1] ) + " " + int( c.angles[2] ) + " | " + model;
}

// Snap a point to the floor below it (trace from 60 above to 300 below).
df_ground( pos )
{
    trace = bullettrace( pos + ( 0, 0, 60 ), pos - ( 0, 0, 300 ), 0, undefined );

    if ( isdefined( trace["position"] ) && trace["fraction"] < 1 )
        return trace["position"];

    return pos;
}

// Absolute value (GSC has no abs builtin); also used by other df files.
df_abs( x )
{
    if ( x < 0 )
        return -1 * x;

    return x;
}

// Horizontal traces from `center` in 12 directions; returns up to `count` wall hits, nearest first,
// at least 40 degrees apart. Each hit: .pos, .normal, .yaw (direction of the trace).
df_find_walls( center, maxdist, count )
{
    hits = [];

    for ( i = 0; i < 12; i++ )
    {
        yaw = i * 30;
        dir = anglestoforward( ( 0, yaw, 0 ) );
        trace = bullettrace( center, center + dir * maxdist, 0, undefined );

        if ( !isdefined( trace["position"] ) || trace["fraction"] >= 1 )
            continue;

        // started inside a solid (fraction ~0) or hit a floor/ceiling/slope: not a wall
        if ( distancesquared( center, trace["position"] ) < 8 * 8 )
            continue;

        if ( isdefined( trace["normal"] ) && df_abs( trace["normal"][2] ) > 0.5 )
            continue;

        h = spawnstruct();
        h.pos = trace["position"];
        h.normal = trace["normal"];
        h.yaw = yaw;
        h.dist = distance( center, h.pos );
        hits[hits.size] = h;
    }

    // nearest first
    for ( i = 0; i < hits.size; i++ )
    {
        for ( j = i + 1; j < hits.size; j++ )
        {
            if ( hits[j].dist < hits[i].dist )
            {
                tmp = hits[i];
                hits[i] = hits[j];
                hits[j] = tmp;
            }
        }
    }

    chosen = [];

    foreach ( h in hits )
    {
        ok = 1;

        foreach ( c in chosen )
        {
            d = df_abs( h.yaw - c.yaw );

            if ( d > 180 )
                d = 360 - d;

            if ( d < 40 )
                ok = 0;
        }

        if ( ok )
            chosen[chosen.size] = h;

        if ( chosen.size >= count )
            break;
    }

    return chosen;
}

// `count` props of `kind` on the walls of the room around `center` (traced at eye height `eye_z` above
// center). Each prop sits `off_wall` units off the wall, on the floor plus `lift`, front away from the wall.
df_coords_on_walls( prefix, count, center, eye_z, maxdist, off_wall, lift, kind )
{
    walls = df_find_walls( center + ( 0, 0, eye_z ), maxdist, count );

    for ( i = 0; i < count; i++ )
    {
        key = prefix + ( i + 1 );

        if ( i >= walls.size )
        {
            // not enough walls found: fall back to the room centre so the key still exists
            df_coord_set( key, center, df_model_angles( kind, 0 ), df_model( kind ) );
            df_debug_print( "DF: wall not found for " + key );
            continue;
        }

        df_coord_on_wall_hit( key, walls[i], off_wall, lift, kind );
    }
}

// `count` props of `kind` in a row on the wall in front of `stand_pos` (a player position facing the wall
// with yaw `facing_yaw`): `spacing` apart along the wall, `off_wall` units off it, `lift` above the feet.
// The wall is always traced at chest height (50), whatever `lift` is, so a low lift (a tall base-pivot
// panel) still finds the wall and not a crate or a hay bale on the floor.
df_coords_row_on_wall( prefix, count, stand_pos, facing_yaw, spacing, lift, off_wall, kind )
{
    eye = stand_pos + ( 0, 0, 50 );
    forward = anglestoforward( ( 0, facing_yaw, 0 ) );
    trace = bullettrace( eye, eye + forward * 250, 0, undefined );
    normal = -1 * forward;
    wall = eye + forward * 40;

    if ( isdefined( trace["position"] ) && trace["fraction"] < 1 )
    {
        wall = trace["position"];

        if ( isdefined( trace["normal"] ) && lengthsquared( ( trace["normal"][0], trace["normal"][1], 0 ) ) > 0.01 )
            normal = vectornormalize( ( trace["normal"][0], trace["normal"][1], 0 ) );
    }

    angles = df_model_angles( kind, vectortoangles( normal )[1] );
    right = anglestoright( ( 0, facing_yaw, 0 ) );

    for ( i = 0; i < count; i++ )
    {
        pos = wall + normal * off_wall + right * ( ( i - ( count - 1 ) / 2.0 ) * spacing ) + ( 0, 0, lift - 50 );
        key = prefix;

        if ( count > 1 )
            key = prefix + ( i + 1 );

        df_coord_set( key, pos, angles, df_model( kind ) );
    }
}

// One prop of `kind` on the nearest wall/fence around `center`; falls back to the ground at `center`.
df_coord_on_nearest_wall( key, center, maxdist, off_wall, lift, kind )
{
    walls = df_find_walls( center, maxdist, 1 );

    if ( walls.size == 0 )
    {
        df_coord_set( key, df_ground( center ) + ( 0, 0, 8 ), df_model_angles( kind, 0 ), df_model( kind ) );
        df_debug_print( "DF: wall not found for " + key + ", placed on the ground" );
        return;
    }

    df_coord_on_wall_hit( key, walls[0], off_wall, lift, kind );
}

// Place a prop of `kind` on a df_find_walls hit: off the wall along its normal, on the floor plus `lift`,
// yaw = wall normal + the model's own front offset (see df_models_init).
df_coord_on_wall_hit( key, w, off_wall, lift, kind )
{
    flat_normal = ( w.normal[0], w.normal[1], 0 );

    // a (near) vertical surface normal has no yaw: face back along the trace instead
    if ( lengthsquared( flat_normal ) < 0.01 )
        flat_normal = -1 * anglestoforward( ( 0, w.yaw, 0 ) );

    flat_normal = vectornormalize( flat_normal );
    pos = df_ground( w.pos + flat_normal * off_wall ) + ( 0, 0, lift );
    df_coord_set( key, pos, df_model_angles( kind, vectortoangles( flat_normal )[1] ), df_model( kind ) );
}

// First vanilla part-spawn struct of that name not used by the real part this game:
// checks vanilla's own allocation table (piece_allocated) and, as a belt-and-braces, any model nearby.
df_coord_from_free_struct( key, buildable_name, struct_name, model )
{
    structs = getstructarray( struct_name, "targetname" );

    if ( !isdefined( structs ) || structs.size == 0 )
    {
        df_debug_print( "DF: no structs named " + struct_name );
        return;
    }

    models = getentarray( "script_model", "classname" );

    foreach ( index, s in structs )
    {
        if ( df_struct_allocated( buildable_name, struct_name, s ) )
            continue;

        occupied = 0;

        foreach ( m in models )
        {
            if ( distancesquared( m.origin, s.origin ) < 48 * 48 )
            {
                occupied = 1;
                break;
            }
        }

        if ( !occupied )
        {
            df_coord_set( key, s.origin, df_struct_yaw( s ), model );
            return;
        }
    }

    df_coord_set( key, structs[0].origin, df_struct_yaw( structs[0] ), model );
    df_debug_print( "DF: no free spawn for " + key + ", using the first one" );
}

// True when vanilla _zm_buildables reserved this struct for the real part (piecespawn.piece_allocated,
// Core/maps/mp/zombies/_zm_buildables.gsc:871 piece_allocate_spawn).
df_struct_allocated( buildable_name, struct_name, s )
{
    if ( !isdefined( level.zombie_buildables ) || !isdefined( level.zombie_buildables[buildable_name] ) )
        return false;

    buildable = level.zombie_buildables[buildable_name];

    if ( !isdefined( buildable.buildablepieces ) )
        return false;

    foreach ( piecespawn in buildable.buildablepieces )
    {
        if ( !isdefined( piecespawn.spawns ) || !isdefined( piecespawn.piece_allocated ) )
            continue;

        for ( i = 0; i < piecespawn.spawns.size; i++ )
        {
            if ( piecespawn.spawns[i] == s && is_true( piecespawn.piece_allocated[i] ) )
                return true;
        }
    }

    return false;
}

// Yaw only of a vanilla part-spawn struct (their pitch/roll are "lying around" poses).
df_struct_yaw( s )
{
    if ( isdefined( s.angles ) )
        return ( 0, s.angles[1], 0 );

    return ( 0, 0, 0 );
}

// ---------------------------------------------------------------- preview ----

// Spawn every planned prop (or one key) so the placement can be checked in game; each anchor's
// [SPOT] line (position, angles, model) goes to the console.
df_preview_show( key )
{
    df_coords_refresh_dynamic();

    if ( !isdefined( key ) )
        df_preview_hide();

    foreach ( k in getarraykeys( level.df_coords ) )
    {
        if ( isdefined( key ) && k != key )
            continue;

        df_preview_refresh( k );
        df_coords_console( df_coord_line( k ) );
    }
}

// (Re)spawn the preview of one key: model at the anchor plus a glint marker above it.
df_preview_refresh( key )
{
    if ( !isdefined( level.df_preview ) )
        level.df_preview = [];

    if ( isdefined( level.df_preview[key] ) )
    {
        foreach ( ent in level.df_preview[key] )
        {
            if ( isdefined( ent ) )
                ent delete();
        }
    }

    level.df_preview[key] = [];
    c = level.df_coords[key];

    if ( isdefined( c.model ) )
    {
        ent = spawn( "script_model", c.origin );
        ent setmodel( c.model );
        ent.angles = c.angles;
        level.df_preview[key][level.df_preview[key].size] = ent;
    }

    marker = df_fx_loop( "fx_zmb_tranzit_light_glow", c.origin + ( 0, 0, 40 ) );

    if ( isdefined( marker ) )
        level.df_preview[key][level.df_preview[key].size] = marker;

    if ( key == "DF_TABLE" )
        df_table_preview_slots( key );
}

// The three deposit slots of the table as key glints on its top, so `!df move DF_TABLE` / `!df ang
// DF_TABLE` can be judged in game. Slot 0 has the LOWEST glint and each next one is 10 units higher
// (same convention as the `!df catalog` row), and slot 0 is on the left looking along the table's front.
df_table_preview_slots( key )
{
    for ( n = 0; n < 3; n++ )
    {
        g = df_fx_loop( "fx_zmb_tranzit_light_glow", df_table_slot( n ) + ( 0, 0, 6 + n * 10 ) );

        if ( isdefined( g ) )
            level.df_preview[key][level.df_preview[key].size] = g;
    }

    df_coords_console( df_table_line() );
}

// Remove every preview prop and marker.
df_preview_hide()
{
    if ( !isdefined( level.df_preview ) )
        return;

    foreach ( key in getarraykeys( level.df_preview ) )
    {
        foreach ( ent in level.df_preview[key] )
        {
            if ( isdefined( ent ) )
                ent delete();
        }
    }

    level.df_preview = [];
}

// "!df fire table_demo": the three deposited items on their slots (relay + its table mast on slot 0, the
// key card upright on slot 1, the orb hovering on slot 2), just to look at the layout. `!df hide` removes them
// (they live in level.df_preview under their own key, which df_preview_hide clears with the rest).
// Nothing else is spawned: the real items come from df_act1 / df_act2_rich / df_act3_vacuum.
df_table_demo_hook()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_table_demo" );
        df_table_demo_spawn();
    }
}

df_table_demo_spawn()
{
    if ( !isdefined( level.df_preview ) )
        level.df_preview = [];

    key = "DF_TABLE_DEMO";

    if ( isdefined( level.df_preview[key] ) )
    {
        foreach ( ent in level.df_preview[key] )
        {
            if ( isdefined( ent ) )
                ent delete();
        }
    }

    level.df_preview[key] = [];
    df_preview_refresh( "DF_TABLE" );
    level.df_preview[key][level.df_preview[key].size] = df_table_demo_prop( "relay", df_table_slot( 0 ), ( 0, 0, 0 ) );

    // on the table the relay carries the tall mast (df_act1 df_step4_plugged_relay_spawn), not the roof slab
    mast = "relay_mast";

    if ( !isdefined( level.df_models[mast] ) )
        mast = "relay_top";

    if ( isdefined( level.df_models[mast] ) )
        level.df_preview[key][level.df_preview[key].size] = df_table_demo_prop( mast, df_table_slot( 0 ), df_model_offset( mast ) );

    // the wire coil between radio and mast (owner 2026-09-09: the assembled relay shows its three parts)
    if ( isdefined( level.df_models["relay_coil"] ) )
        level.df_preview[key][level.df_preview[key].size] = df_table_demo_prop( "relay_coil", df_table_slot( 0 ), df_model_offset( "relay_coil" ) );

    // the card stands upright (registry pose pitch 90), so half its length is below its own origin
    level.df_preview[key][level.df_preview[key].size] = df_table_demo_prop( "card", df_table_slot( 1 ), ( 0, 0, 8 ) );
    level.df_preview[key][level.df_preview[key].size] = df_table_demo_prop( "orb", df_table_slot( 2 ), ( 0, 0, df_model_rest_z( "orb" ) ) );
    df_debug_print( "DF: table demo: relay + " + mast + " on slot 0, key card on slot 1, orb on slot 2 at rest +" + df_model_rest_z( "orb" ) + " (!df hide removes them)" );
}

// One demo prop of `kind` at a slot (plus an offset), front turned the way the table faces.
df_table_demo_prop( kind, pos, offset )
{
    yaw = df_table_yaw();

    // the relay pieces sit at 45 degrees on the table (df_act1 df_a1_relay_spawn, owner 2026-09-11)
    if ( kind == "relay" || kind == "relay_coil" || kind == "relay_top" || kind == "relay_mast" )
        yaw = yaw - 45;

    ent = spawn( "script_model", pos + offset );
    ent setmodel( df_model( kind ) );
    ent.angles = df_model_angles( kind, yaw );
    return ent;
}

// Props: stand 110 units in front, looking at it. Player spots (no model): stand on it, facing its way.
df_preview_teleport( key )
{
    c = df_coord( key );

    if ( !isdefined( c ) )
        return false;

    if ( !isdefined( c.model ) )
    {
        self setorigin( c.origin + ( 0, 0, 5 ) );
        self setplayerangles( c.angles );
        return true;
    }

    // stand on the prop's front side: its yaw minus the wall offset of the kind using this model (tv +180)
    front_yaw = c.angles[1];
    kind = df_model_kind_of( c.model );

    if ( isdefined( kind ) && isdefined( level.df_model_yawoff[kind] ) )
        front_yaw = front_yaw - level.df_model_yawoff[kind];

    back = anglestoforward( ( 0, front_yaw, 0 ) ) * 110;
    pos = df_ground( c.origin + back ) + ( 0, 0, 5 );
    self setorigin( pos );
    self setplayerangles( vectortoangles( c.origin - pos ) );
    return true;
}

// "!df dump": every anchor as a [SPOT] line plus the model registry as [MODEL] lines, console only
// (needs `developer_script 1`; a screen print of 30+ lines would be unreadable). Returns the one-line
// summary for df_out.
df_coords_dump()
{
    if ( !isdefined( level.df_coords ) )
        df_coords_init();

    df_coords_refresh_dynamic();
    keys = getarraykeys( level.df_coords );

    foreach ( k in keys )
        df_coords_console( df_coord_line( k ) );

    kinds = getarraykeys( level.df_models );

    foreach ( kind in kinds )
    {
        off = df_model_offset( kind );
        df_coords_console( "[MODEL] " + kind + " -> " + level.df_models[kind] + " | pitch/roll " + int( level.df_model_base[kind][0] ) + "/" + int( level.df_model_base[kind][2] ) + " | wall yaw +" + int( level.df_model_yawoff[kind] ) + " | offset " + int( off[0] ) + " " + int( off[1] ) + " " + int( off[2] ) );
    }

    return "DF: " + keys.size + " anchors ([SPOT]) and " + kinds.size + " models ([MODEL]) listed in the console";
}

// Console-only line (copy-paste material), same "[DF] " prefix as df_out.
df_coords_console( line )
{
    print( "[DF] " + line + "\n" );
}

// ------------------------------------------------------------ live tuning ----
// Each returns the new [SPOT] line (or undefined for an unknown key) and refreshes the preview. Tuning
// DF_TABLE drags DF_SOCKET (and with it every proximity check, prompt and fx of the steps) along.

df_coord_tune_angles( key, pitch, yaw, roll )
{
    if ( !isdefined( level.df_coords[key] ) )
        return undefined;

    level.df_coords[key].angles = ( pitch, yaw, roll );
    level.df_coords[key].overridden = 1;
    df_coord_tune_done( key );
    return df_coord_line( key );
}

df_coord_tune_lift( key, units )
{
    if ( !isdefined( level.df_coords[key] ) )
        return undefined;

    level.df_coords[key].origin = level.df_coords[key].origin + ( 0, 0, units );
    level.df_coords[key].overridden = 1;
    df_coord_tune_done( key );
    return df_coord_line( key );
}

// Move relative to the player's facing: forward / right / up.
df_coord_tune_move( key, player, f, r, u )
{
    if ( !isdefined( level.df_coords[key] ) )
        return undefined;

    yaw_only = ( 0, player.angles[1], 0 );
    delta = anglestoforward( yaw_only ) * f + anglestoright( yaw_only ) * r + ( 0, 0, u );
    level.df_coords[key].origin = level.df_coords[key].origin + delta;
    level.df_coords[key].overridden = 1;
    df_coord_tune_done( key );
    return df_coord_line( key );
}

// After any live tune: re-spawn that preview and, for the table, keep DF_SOCKET on it and print the new
// slot positions. Tuning a side's orb anchor (DF_ORB_TOWER / DF_ORB_DINER) re-copies it into DF_ORB_SPAWN.
df_coord_tune_done( key )
{
    if ( key == "DF_TABLE" )
        df_table_sync_socket();

    if ( key == "DF_ORB_TOWER" || key == "DF_ORB_DINER" )
        df_orb_spawn_sync();

    df_preview_refresh( key );

    if ( key != "DF_TABLE" )
        return;

    // the socket preview rides along, but only if one is up (df_preview_refresh would spawn one otherwise)
    if ( isdefined( level.df_preview ) && isdefined( level.df_preview["DF_SOCKET"] ) )
        df_preview_refresh( "DF_SOCKET" );

    df_coords_console( df_table_line() );
}

// ----------------------------------------------------------------- beams ----
// "Look there" marker for a world target: a light shaft (df_beam_fx) aimed from the table under the tower
// at the target plus a rising light column (fx_zmb_tranzit_power_rising) at the target's ground point.
// Returns a struct; df_beam_stop() removes it. Callers: df_lamps (anchored / charged), df_act2_rich (R2
// unfilled lamps), df_act3_vacuum (charged nodes, resting orb).
//
// The shaft alias (art audit #3, 2026-09-09): the old mc_towerlight is fx_zmb_morsecode_loop, the pylon's
// blinking morse DOT (zm_transit.csc:118), not a ray, so aiming it did nothing. The audit's spotlight_beam
// (env/light/fx_ray_spotlight_md) is NOT available on TranZit: Core/maps/mp/zombies/_load.gsc:248 registers
// it only when the map has a "spotlight_fx" struct (TranZit has none, tools/zm_transit.d3dbsp.ents.txt) and
// the raw fx is not in the TranZit fastfiles (tools/assets/fx_zm_transit.txt), so a loadfx would fail at load.
// The only real light shafts in the fastfile are the map's god rays (zm_transit_fx.gsc:103-111, aliases
// fx_zmb_tranzit_god_ray_*); the long interior one is the default here. `set df_beam_fx <alias>` tries
// another registered alias live (e.g. fx_zmb_tranzit_god_ray_pwr_station, _interior_med, mc_towerlight),
// `set df_beam_flip 1` aims it the other way (from the target back to the table) if the ray is authored
// backwards, and `!df fire beam_test` shows one for 20 s towards the nearest lamp post.
df_beam_start( target_origin )
{
    b = spawnstruct();
    socket = df_coord( "DF_SOCKET" ).origin + ( 0, 0, 80 );
    dir = vectornormalize( target_origin - socket );
    aim = dir;

    if ( getdvar( "df_beam_flip" ) == "1" )
        aim = -1 * dir;

    b.beam = df_fx_loop( df_beam_fx(), socket + dir * 40, vectortoangles( aim ) );
    b.marker = df_fx_loop( "fx_zmb_tranzit_power_rising", df_ground( target_origin ) );
    return b;
}

// The shaft alias: the console dvar df_beam_fx when it names a registered alias, else the long god ray,
// else (never on vanilla TranZit) the morse dot with a one-time console note.
df_beam_fx()
{
    want = getdvar( "df_beam_fx" );

    if ( isdefined( want ) && want != "" && isdefined( level._effect[want] ) )
        return want;

    if ( isdefined( level._effect["fx_zmb_tranzit_god_ray_interior_long"] ) )
        return "fx_zmb_tranzit_god_ray_interior_long";

    if ( !is_true( level.df_beam_fallback_noted ) )
    {
        level.df_beam_fallback_noted = 1;
        df_debug_print( "DF: beam: fx_zmb_tranzit_god_ray_interior_long not registered, falling back to mc_towerlight (a dot, not a ray)" );
    }

    return "mc_towerlight";
}

// "!df fire beam_test": a 20 s beam from the table towards the bulb of the nearest lamp post
// (screecher_escape struct + 148, the same fallback bulb height df_lamps uses), so the owner can judge the
// alias and its direction without playing to R2. Prints the alias and the aim.
df_beam_test_hook()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "df_debug_beam_test" );
        socket = df_coord( "DF_SOCKET" ).origin;
        lights = getstructarray( "screecher_escape", "targetname" );
        best = undefined;

        foreach ( light in lights )
        {
            if ( !isdefined( best ) || distancesquared( light.origin, socket ) < distancesquared( best.origin, socket ) )
                best = light;
        }

        if ( !isdefined( best ) )
        {
            df_debug_print( "DF: beam test: no lamp post struct found" );
            continue;
        }

        target = best.origin + ( 0, 0, 148 );
        df_debug_print( "DF: beam test: " + df_beam_fx() + " from the table to lamp " + best.script_noteworthy + " at " + df_vec_str( target ) + " for 20 s (set df_beam_fx / df_beam_flip, then fire again)" );
        level thread df_beam_test_run( target );
    }
}

df_beam_test_run( target )
{
    level endon( "end_game" );
    b = df_beam_start( target );
    wait 20;
    df_beam_stop( b );
}

df_beam_stop( b )
{
    if ( !isdefined( b ) )
        return;

    df_fx_stop( b.beam );
    df_fx_stop( b.marker );
    b.beam = undefined;
    b.marker = undefined;
}

// =========================================================================================
// Model registry (polish pass 2026-09-08, art audit 2026-09-09). Every step asks df_model( kind ) instead of
// hard-coding a model name, so a model swap is one line here. Kinds: "relay" (bus roof radio / tower relay,
// the base), "relay_top" (the low slab stacked on the ROOF relay, offset df_model_offset( "relay_top" )),
// "relay_mast" (the tall post stacked on the TABLE relay after Step 4, offset df_model_offset( "relay_mast" )),
// "orb" (Step 6/7 charge core), "part_a" "part_b" "part_c" (Step 2 parts), "tv", "phone", "fuse", "socket",
// "brazier", "card" (R1 key card), "portal" (M1 hole), "beacon" (Step 5 anchor marker), "table" (the bench
// under the tower the relay / card / orb are deposited on, DF_TABLE + df_table_slot), and the audit items of
// 2026-09-08 (section 9): "skull" (M1 trophy on table slot 1), "receiver" (S1 handset part), "spool" (R2
// wire spool), "ember" (M2 carried ember).
//
// Selection rules (tools/assets/xmodels_zm_transit.txt, dumped from the fastfiles):
//   - only models whose zones are always resident: zm_transit, common_zm, so_zclassic_zm_transit.
//     A model tagged with a zm_transit_gump_<area> zone has its textures streamed with that area: spawned
//     elsewhere it renders as an untextured black block (owner report on p_jun_old_tv, a gump_farm model,
//     spawned at the depot 2026-09-08). Only the depot phones may use a gump_busstation model.
//   - prefer models vanilla itself spawns dynamically (buildable pieces, key card, screecher hole):
//     proven to render as script_models. Static-only props (afr_barrel_*, test_sphere_*) are precached by
//     df_coords_precache() from df_main::init (works there, tested 2026-09-07).
// Facing conventions (pitch/roll that stands the model upright, yaw offset that turns its front away from
// a wall) live next to the model so df_model_angles() places every wall prop the same way.
// =========================================================================================

// Model name for a kind ("tag_origin" and a console warning for an unknown kind).
df_model( kind )
{
    if ( !isdefined( level.df_models ) )
        df_models_init();

    if ( isdefined( level.df_models[kind] ) )
        return level.df_models[kind];

    df_debug_print( "DF: df_model: unknown kind " + kind + ", using tag_origin" );
    return "tag_origin";
}

// Full angles for a prop of `kind` whose front must point along world yaw `front_yaw`
// (wall normal, or the direction to what it should look at).
df_model_angles( kind, front_yaw )
{
    if ( !isdefined( level.df_models ) )
        df_models_init();

    base = ( 0, 0, 0 );
    yawoff = 0;

    if ( isdefined( level.df_model_base[kind] ) )
        base = level.df_model_base[kind];

    if ( isdefined( level.df_model_yawoff[kind] ) )
        yawoff = level.df_model_yawoff[kind];

    return ( base[0], front_yaw + yawoff, base[2] );
}

// kind -> model, upright pitch/roll, wall-facing yaw offset. One df_model_def line per kind; the comment
// gives the zone(s) from tools/assets/xmodels_zm_transit.txt and why this model.
df_models_init()
{
    level.df_models = [];
    level.df_model_base = [];
    level.df_model_yawoff = [];
    level.df_model_offset = [];
    level.df_model_pose = [];

    // relay: the transmitter built on the bus roof and plugged into the tower. Owner 2026-09-08: "just a
    // simple radio, make it an antenna". No always-loaded antenna fits a bus roof: pb_pole_telephone_bulb,
    // afr_powerpole1 and p_glo_powerline_tower_redwhite (all zm_transit) are full-size poles / a pylon
    // (hundreds of units, map statics with no script or entity-dump usage to measure them; the bus goes
    // through the tunnel and under the depot roof). p6_antenna_3 is gump_farm only (black elsewhere). So
    // the relay is a composite: this radio set as the base (vanilla EE piece, zm_transit_buildables.gsc:138,
    // sq_common "tag_part_03", 64x96 pickup radius) plus "relay_top" stacked on it (below).
    // Spec 9 note: the owner's noee mod uses this model for call-bus panels at stop signs (cosmetic overlap).
    df_model_def( "relay", "p6_zm_buildable_sq_transceiver", 0, 0, 0 );

    // relay_top: the piece on the ROOF radio (the bus goes through the tunnel and under the depot roof, so
    // it stays low). Vanilla EE tower lattice section (zm_transit, sq_common "tag_part_01",
    // zm_transit_buildables.gsc:137), the same piece the players carried as part_b. glTF: 83 x 24 flat slab,
    // 4.4 thick, pivot at its CENTRE; the radio is 7.3 tall with a base pivot, so the slab's underside meets
    // the radio top at 7.3 + 2.2 = 9 (art audit #7: the old 30 left 23 units of air). Spawned by df_act1 at
    // relay.origin + df_model_offset( "relay_top" ) with the relay's yaw (only when this kind exists).
    // Owner 2026-09-09: "the relay should look the same each time": the roof relay is the SAME assembly as the
    // table relay, radio + coil + mast (relay_top = relay_mast; the slab read as "just a plank"). The mast pokes
    // through the tunnel roof and the depot roof for a second while the bus passes: cosmetic, no collision.
    df_model_def( "relay_top", "p6_zm_chain_fence_piece_end", 0, 0, 0, ( 0, 0, 27 ) ); // on the box: 7 + 20

    // relay_coil: the wire coil the phone gave (part 3), stacked on the radio (7.3 tall) on the roof and on the
    // table; the mast stands on the coil (7.6 tall, base pivot, 25 x 25 footprint on the radio's 26 x 19).
    // owner pick 2026-09-11: the power box (13 x 20 x 4, CENTRE pivot) stands upright on the radio: centre at 7 + 10
    df_model_def( "relay_coil", "p6_zm_buildable_sq_electric_box", 0, 0, 0, ( 0, 0, 17 ) );

    // relay_mast: the piece on the TABLE relay after Step 4 (no clearance problem under the tower): a fence
    // end post, zm_transit ALWAYS, glTF 13 x 3 footprint, 117 tall, pivot at its base, its brace extends 12
    // along -x (inside the radio's 26-long footprint). Stacked at the radio's top (7) it makes the plugged
    // relay a 124-tall antenna readable from outside the fence (art audit #7). Spawned by df_act1
    // (df_step4_plugged_relay_spawn) at relay.origin + df_model_offset( "relay_mast" ) with the relay's yaw.
    df_model_def( "relay_mast", "p6_zm_chain_fence_piece_end", 0, 0, 0, ( 0, 0, 27 ) ); // on the box (7 + 20)

    // orb: Step 6/7 charge core. Art audit #6: kind "orb" and kind "skull" were both zombie_skull, so the
    // Maxis table held two identical skulls; the trophy stays the skull, the orb is a machine part: the
    // turbine rotor disc (so_zclassic_zm_transit ALWAYS, vanilla turbine buildable piece,
    // zm_transit_buildables.gsc turbine pieces). glTF: 25 x 25 disc, 10 thick, pivot at its BASE (not the
    // centre): it rests with df_model_rest_z( "orb" ) = 5 of hover under the steps' aura fx; spun slowly
    // (rotateyaw, df_act3) it reads as a coil / core and never as the trophy.
    // Alternatives (all always loaded, all in df_catalog_models for `!df catalog orb`):
    //   zombie_skull                  common_zm, the insta-kill powerup skull (_zm_powerups.gsc:96), 16 x 23 x 21, rest 14
    //   p6_zm_buildable_sq_meteor     zm_transit, the EE meteor piece (the original orb, too small for the owner)
    //   p6_zm_rocks_small_cluster_01  zm_transit, a small rock pile
    //   zombie_pickup_perk_bottle     so_zclassic_zm_transit, the perk-bottle powerup (_zm_powerups.gsc:103)
    //   test_sphere_silver            common_zm, chrome sphere (mirrors the black sky, reads dark)
    //   semtex_bag                    zm_transit, a rounded canvas bag
    // owner pick 2026-09-11 (Prop Picker): the EE meteor piece, 5 x 6 x 5, centre pivot (the skull is the same model,
    // owner's choice; the orb spins and wears the aura, the skull sits still on slot 1).
    df_model_def( "orb", "p6_zm_buildable_sq_meteor", 0, 0, 0 );

    // part_a: cabin, the "battery" of spec 10. Vanilla electric trap battery piece (so_zclassic_zm_transit,
    // zm_transit_buildables.gsc electric_trap pieces): a car battery, clearly a power cell.
    // Owner 2026-09-09: the parts ARE the pieces of the assembled relay, same positions, models swapped:
    // part_a (Cabin) = the radio itself (the car battery moved to kind "battery" for the R1 bus battery).
    df_model_def( "part_a", "p6_zm_buildable_sq_transceiver", 0, 0, 0 );

    // battery: the R1 bus battery (df_act2_rich), the electric trap battery piece (so_zclassic_zm_transit).
    df_model_def( "battery", "p6_zm_buildable_battery", 0, 0, 0 );

    // part_b: tunnel, the "antenna" of spec 10. Vanilla EE tower lattice piece (zm_transit, sq_common
    // "tag_part_01", zm_transit_buildables.gsc:137): a metal mast section, reads as an antenna.
    // part_b (tunnel) = the mast, the fence end post (13 x 3 footprint, 117 tall, base pivot): it STANDS at its
    // anchor, readable from far (owner 2026-09-09; was the flat lattice slab).
    df_model_def( "part_b", "p6_zm_chain_fence_piece_end", 0, 0, 0 );

    // part_c: cornfield, the "chassis" of spec 10. Vanilla EE power box piece (zm_transit, sq_common
    // "tag_part_02", zm_transit_buildables.gsc:135, HUD icon zm_hud_icon_sq_powerbox): the transmitter housing.
    df_model_def( "part_c", "p6_zm_buildable_sq_electric_box", 0, 0, 0 );

    // tv: the electric trap's CRT picture tube, a vanilla piece (so_zclassic_zm_transit ALWAYS, spawned
    // anywhere by _zm_buildables). Stands upright with pitch 270 / roll 180, screen away from the wall with
    // yaw +180 (owner-tested 2026-09-07, README "TVs: pitch 270 + roll 180 stand upright"). Art audit #5: the
    // 9-unit pb_pole_telephone_bulb of 2026-09-08 was unreadable without its glow; the tube is 21 x 21 x 22,
    // literally the "screen" the Step 1 lines talk about. glTF: 21 wide, 22 deep, 20.6 long; posed upright
    // its origin is at MID height (the tube spans -11..+11 around it), hence df_model_rest_z( "tv" ) = 11 on
    // the DF_TV anchors and "top of the tube" = anchor + 11. p_jun_old_tv (the farmhouse TV) is gump_farm and
    // renders black at the depot; the power station monitors are gump_powerstation: same problem.
    df_model_def( "tv", "pb_pole_telephone_bulb", 0, 0, 0 ); // owner 2026-09-09: the chimney pipe again, not the tube

    // phone: the depot wall payphone (zm_transit + gump_busstation: the depot IS the bus station gump, so
    // its textures are resident where the phones are). The two real phones are map statics (not in the
    // entity dump); this is for any script-spawned phone prop.
    df_model_def( "phone", "com_payphone_america", 0, 0, 0 );

    // fuse: the four Simon boxes on the barn walls. Art audit section 2: the EE power box
    // (p6_zm_buildable_sq_electric_box, 13 x 20 x 4) read from 3 m only; the vanilla power switch panel piece
    // (zm_transit + so_zclassic_zm_transit ALWAYS, zm_transit_buildables.gsc powerswitch pieces) is a 36 x 63
    // breaker panel, 16 deep, three times the size, so the boxes read from the barn door. Front along the
    // model's right side (yaw +90, the Treyarch wall-panel convention the electric box validated 2026-09-07).
    // glTF: pivot at the BASE, so the anchor is the panel's bottom edge: centre = anchor + 32, top = + 63.
    // p_rus_electricalbox_03 would be the barn's own box but is gump_farm (streams only at the farm).
    // Owner 2026-09-09: the EE power box again (the breaker panel was not wanted); anchors back to the box centre
    // at 50 with 6 off the wall. Centre pivot: top edge = anchor + 10 (df_model_top_z).
    df_model_def( "fuse", "p6_zm_buildable_sq_electric_box", 0, 0, 90 );

    // socket: the old wall panel at the tower base; fallback only since the table IS the socket
    // (df_table_sync_socket), kept so `!df show` still previews DF_SOCKET. Same panel as "fuse".
    df_model_def( "socket", "p6_zm_buildable_pswitch_body", 0, 0, 90 );

    // brazier: a low lava-rock cairn (zm_transit ALWAYS, a map static precached by df_coords_precache). Art
    // audit #8: the white biohazard drum afr_barrel_biohazard_white_rust (29 x 44 x 29) read "toxic waste"
    // and its 44-tall closed body hid the stage-0 ember; the cairn is the Blood-of-the-Dead stone-bowl
    // silhouette and belongs to the lava field the four braziers stand in. glTF: 88 x 77 footprint (off
    // centre: 58 one way, 30 the other), 16.5 tall with the pivot 2.6 above its lowest rock, so on the ground
    // the rim / top is anchor + 14 (df_model_top_z( "brazier" )): the fire sits on the rocks, visible all round.
    // owner pick 2026-09-11 (Prop Picker): a tombstone (ch_tombstone1, zm_transit, 3 x 20 footprint, 31 tall, base
    // pivot); the fire sits on its top edge (df_model_top_z = 31).
    df_model_def( "brazier", "ch_tombstone1", 0, 0, 0 );

    // card: the NavCard model (zm_transit; zm_transit.gsc:118 precaches it, zm_transit_sq.gsc:1365 places it
    // LYING FLAT on the depot floor at (-6245, 5479.5, -55.35), angles (0,0,0): the model's origin is on the
    // card, face up +z). Owner 2026-09-08: "invisible, can be taken but not seen" when floating at chest
    // height: a flat card seen edge-on has no visible area. Pose here: pitch 90 stands it upright with its
    // face along the wall normal (out of the wall), so DF_CARD_SPAWN shows it like a badge on the wall.
    df_model_def( "card", "p6_zm_keycard", 90, 0, 0 );

    // table: the bench under the tower everything is deposited on (owner 2026-09-08). Vanilla Pack-a-Punch
    // "legs" buildable piece (so_zclassic_zm_transit; zm_transit_buildables.gsc:53 generate_zombie_buildable_piece
    // "pap" with pickup radius 48x15, HUD icon zm_hud_icon_chairleg), i.e. the PaP table itself, and a piece
    // vanilla spawns dynamically. The three struct spawns in the entity dump (tools/zm_transit.d3dbsp.ents.txt:
    // "pap_p6_zm_buildable_pap_table", angles "0 5.8 0" / "0 287.6 0") lie flat on the ground: pitch/roll 0
    // stand it up, pivot at the base. glTF dump (C:\Games\t6\model_dump): 54 long x 11 deep x 21 tall, so the
    // long side runs along the model's +x and the yaw offset +90 turns it ACROSS the front direction, which is
    // what makes the three slots run left to right in front of a player. Top height: df_model_top_z.
    // owner 2026-09-08: p6_zm_work_bench instead of the PaP table piece. Measured: 31 x 44 x 88 against
    // 54 x 21 x 11, i.e. a real waist-high bench (44, player ~70) with an 88-long top for the three slots,
    // it lives in zm_transit (ALWAYS loaded) and it is the bench players already read as a crafting table.
    // Its long axis runs along the anchor front already, so the yaw offset drops from 90 to 0.
    df_model_def( "table", "p6_zm_work_bench", 0, 0, 0 );

    // portal: the denizen burrow hole (so_zclassic_zm_transit; _zm_ai_screecher.gsc:20 precaches it,
    // zm_transit_ai_screecher.gsc:78 setmodel).
    df_model_def( "portal", "p6_zm_screecher_hole", 0, 0, 0 );

    // beacon: small marker under Step 5 anchor FX. The vanilla meteor piece (zm_transit, sq_common
    // "tag_part_04"): small on purpose here, visible, proven to spawn.
    df_model_def( "beacon", "p6_zm_buildable_sq_meteor", 0, 0, 0 );
    // player collision block for the table (patch_zm, ALWAYS; the vanilla ffotd pattern zm_transit_ffotd.gsc:17/47)
    df_model_def( "clip", "collision_player_32x32x32", 0, 0, 0 );
    df_models_init_items();
}

// The physical items of the design audit (2026-09-08, section 9), one kind each; same selection rules.
df_models_init_items()
{
    // skull: the cold room's trophy Maxis leaves on table slot 1 after M1 (audit #7 / 9). The insta-kill
    // powerup skull (common_zm, ALWAYS; _zm_powerups.gsc:96 spawns it dynamically), 16 x 23 x 21; glTF: the
    // pivot is 14 above its lowest point (df_model_rest_z( "skull" ) = 14). Since the art audit (#6) the orb is
    // the turbine disc, so this is the only skull on the table; the zombie head gib c_zom_zombie_head_a
    // (so_zclassic_zm_transit, ALWAYS, 14 x 10 x 11, precached by character/c_zom_zombie1_01.gsc:34) stays in
    // the catalog as the one-line alternative.
    df_model_def( "skull", "p6_zm_buildable_sq_meteor", 0, 0, 0 ); // owner pick 2026-09-11 (Prop Picker)

    // receiver: the handset the depot phone drops after Step 1 (audit 9, the relay's 4th part). No phone
    // handset is always loaded (com_payphone_america is gump_busstation, black elsewhere); the jet gun handles
    // piece (so_zclassic_zm_transit, ALWAYS, zm_transit_buildables.gsc jetgun pieces) is a hand-sized grip with
    // a trigger, 11 x 4 x 10, proven to spawn as a buildable. Fallback: p6_zm_buildable_battery (16 x 14 x 9).
    // receiver (the phone's part) = the wire coil, p6_zm_buildable_jetgun_wires (owner 2026-09-09, "bobine"), the
    // same model R2's spools use: the relay carries one on the radio.
    df_model_def( "receiver", "p6_zm_buildable_sq_electric_box", 0, 0, 0 ); // owner pick 2026-09-11 (Prop Picker): the EE power box

    // spool: the wire spool a filled lamp drops in R2 (audit 9). The jet gun wire bundle piece
    // (so_zclassic_zm_transit, ALWAYS, zm_transit_buildables.gsc jetgun pieces), 25 x 7 x 25: a coil of cable.
    // Fallback: p6_zm_buildable_sq_electric_box (13 x 20 x 4).
    df_model_def( "spool", "p6_zm_buildable_jetgun_wires", 0, 0, 0 );

    // ember: the carried ember of the M2 chain (audit 9). The EE meteor piece (zm_transit, ALWAYS, sq_common
    // "tag_part_04"), 5 x 5 x 6: a small glowing rock; the step wraps it in fire fx (lava_burning / lava glow).
    // No other always-loaded coal-like prop exists (zombie_meteor_chunk_sml2 is gump_busstation).
    df_model_def( "ember", "p6_zm_buildable_sq_meteor", 0, 0, 0 );
}

// One registry entry: model plus its upright pitch/roll, the yaw offset that points its front away from a
// wall (0 for models whose +x is the front or that have no front) and an optional world offset (relative
// to the kind's parent prop, e.g. relay_top above the relay). The pose is also remembered per model name
// so a live swap (df_model_set) can look it up.
df_model_def( kind, name, pitch, roll, yawoff, offset )
{
    if ( !isdefined( offset ) )
        offset = ( 0, 0, 0 );

    if ( !isdefined( level.df_model_offset ) )
        level.df_model_offset = [];

    if ( !isdefined( level.df_model_pose ) )
        level.df_model_pose = [];

    level.df_models[kind] = name;
    level.df_model_base[kind] = ( pitch, 0, roll );
    level.df_model_yawoff[kind] = yawoff;
    level.df_model_offset[kind] = offset;
    level.df_model_pose[name] = ( pitch, yawoff, roll );
}

// World offset of a stacked kind relative to its parent prop ((0,0,0) unless df_model_def gave one).
df_model_offset( kind )
{
    if ( !isdefined( level.df_models ) )
        df_models_init();

    if ( isdefined( level.df_model_offset[kind] ) )
        return level.df_model_offset[kind];

    return ( 0, 0, 0 );
}

// Height of the TOP surface of a kind's model above its own origin (which sits at the model's base for
// every prop we place on the ground): where df_table_slot puts the things deposited on it. Order:
//   1. the small table below, for models whose deposit plane is not simply their full height,
//   2. the measured height of the generated catalogue (df_catalog.gsc, "name zone width height depth",
//      glTF export of the game files), so ANY model the owner swaps in with `!df model table <name>` or
//      `!df catalog pick <n> table` gets its own real top,
//   3. 36, a normal table height, as a last resort.
df_model_top_z( kind )
{
    name = df_model( kind );

    // kept explicit so the tops still work when df_catalog.gsc is out of the build (the packed release
    // stubs it); glTF POSITION bounds (top = max height above the pivot, NOT the bounding height when the
    // pivot is not at the bottom)
    tops = [];
    tops["p6_zm_work_bench"] = 44;               // 31 x 44 x 88, the vanilla TranZit bench, base pivot
    tops["p6_zm_buildable_pap_table"] = 21;      // 54 x 21 x 11, the PaP table legs (previous choice)
    tops["p6_zm_rocks_small_cluster_03"] = 14;   // brazier cairn: 16.5 tall, pivot 2.6 above the lowest rock
    tops["afr_barrel_biohazard_white_rust"] = 44; // the old drum brazier, base pivot
    tops["p6_zm_buildable_sq_transceiver"] = 7;  // relay radio, base pivot (the coil sits here)
    tops["p6_zm_buildable_jetgun_wires"] = 8;    // wire coil, 7.6 tall, base pivot (the mast sits on it at +15)
    tops["p6_zm_buildable_sq_electric_box"] = 10; // fuse power box, 20 tall, centre pivot
    tops["p6_zm_buildable_pswitch_body"] = 63;   // fuse panel, base pivot
    tops["p6_zm_chain_fence_piece_end"] = 117;   // relay mast, base pivot
    tops["p6_zm_buildable_turbine_fan"] = 10;    // orb disc, base pivot
    tops["p6_zm_buildable_sq_meteor"] = 2;       // meteor piece, centre pivot, 4.5 tall
    tops["ch_tombstone1"] = 31;                  // tombstone brazier, base pivot, 31 tall
    tops["p6_zm_buildable_etrap_tvtube"] = 11;   // tv tube posed upright: origin at mid height, top +11
    tops["pb_pole_telephone_bulb"] = 9;          // tv = the chimney pipe (9 x 8 x 9, base pivot)

    if ( isdefined( tops[name] ) )
        return tops[name];

    line = df_catalog_lookup( name );

    if ( isdefined( line ) )
    {
        h = int( strtok( line, " " )[3] );

        if ( h > 0 )
            return h;
    }

    return 36;
}

// Height of a kind's model ORIGIN above the surface it rests on (floor, table top), in its registered pose,
// so the prop looks placed: 0 for the base-pivot props (most of them), the half height for models whose pivot
// is at their centre, the measured pivot height for the skull. The one deliberate non-contact value is the
// orb: the turbine disc has a base pivot (contact would be 0) but it hovers 5 above the slot / floor under the
// steps' aura fx, so a spinning core never z-fights the table (requested in tools/requests_act3_orb.md and
// requests_hold2.md; df_act3_vacuum / df_act3_hold add this to df_table_slot( 2 ), the floor and DF_ORB_SPAWN).
// Numbers: glTF POSITION bounds of the model export.
df_model_rest_z( kind )
{
    name = df_model( kind );
    rest = [];
    rest["p6_zm_buildable_turbine_fan"] = 5;   // orb: 25 x 25 x 10 disc, base pivot, hovers half its thickness
    rest["p6_zm_buildable_sq_meteor"] = 3;     // orb / skull: the meteor piece, centre pivot, 4.5 tall
    rest["p6_zm_buildable_etrap_tvtube"] = 11; // tv posed upright: origin at mid height, 21 tall
    rest["zombie_skull"] = 14;                 // skull: pivot 14 above its lowest point (top +9)
    rest["test_sphere_lambert"] = 16;          // the old debug sphere (centre pivot)
    rest["p6_zm_buildable_sq_scaffolding"] = 2; // flat slab, centre pivot, 4.4 thick
    rest["p6_zm_buildable_sq_electric_box"] = 10; // 13 x 20 x 4 box, centre pivot

    if ( isdefined( rest[name] ) )
        return rest[name];

    return 0;
}

// Upright pose of a model NAME as ( pitch, wall yaw offset, roll ): what df_model_def registered for it,
// else the default upright ( 0, 0, 0 ). Lets a swapped kind take the pose its new model needs.
df_model_pose( name )
{
    if ( isdefined( level.df_model_pose ) && isdefined( level.df_model_pose[name] ) )
        return level.df_model_pose[name];

    return ( 0, 0, 0 );
}

// "!df model <kind> <name>" / "!df catalog pick": live swap for owner tests. The kind takes the pose known
// for the new model (df_model_pose; upright default), every anchor carrying the old model is re-skinned in
// place (same front yaw, new pose) so `!df show` previews it at once, and props spawned from now on use it.
// Only models the map or df_coords_precache() already precached render (precachemodel works in init()
// only): every catalog model is, an unknown name is for the next map load.
df_model_set( kind, name )
{
    if ( !isdefined( level.df_models ) )
        df_models_init();

    old_name = level.df_models[kind];
    old_yawoff = 0;

    if ( isdefined( level.df_model_yawoff[kind] ) )
        old_yawoff = level.df_model_yawoff[kind];

    pose = df_model_pose( name );
    level.df_models[kind] = name;
    level.df_model_base[kind] = ( pose[0], 0, pose[2] );
    level.df_model_yawoff[kind] = pose[1];

    if ( !isdefined( level.df_model_offset[kind] ) )
        level.df_model_offset[kind] = ( 0, 0, 0 );

    if ( isdefined( old_name ) && isdefined( level.df_coords ) )
        df_coords_reskin( kind, old_name, old_yawoff );

    df_debug_print( "DF: model " + kind + " -> " + name + " (renders only if precached: registry and catalog models are)" );
}

// After a swap: every anchor that carried `old_name` gets the kind's new model and pose, keeping the
// direction its front pointed (yaw minus the old wall offset). Live-tuned angles keep their yaw too.
df_coords_reskin( kind, old_name, old_yawoff )
{
    n = 0;

    foreach ( key in getarraykeys( level.df_coords ) )
    {
        c = level.df_coords[key];

        if ( !isdefined( c.model ) || c.model != old_name )
            continue;

        c.model = level.df_models[kind];
        c.angles = df_model_angles( kind, c.angles[1] - old_yawoff );
        n++;
    }

    if ( n > 0 )
        df_debug_print( "DF: " + n + " anchor(s) now use " + level.df_models[kind] );
}

// Called from df_main::init (the only place precachemodel works): every registry model once, never
// tag_origin, plus the `!df catalog` candidates (df_catalog_models) unless console `set df_catalog 0`.
df_coords_precache()
{
    if ( !isdefined( level.df_models ) )
        df_models_init();

    done = [];

    foreach ( kind, name in level.df_models )
    {
        if ( name == "tag_origin" || isdefined( done[name] ) )
            continue;

        precachemodel( name );
        done[name] = 1;
    }

    registry = getarraykeys( done ).size;

    if ( getdvar( "df_catalog" ) != "0" )
    {
        foreach ( name in df_catalog_models() )
        {
            if ( isdefined( done[name] ) )
                continue;

            precachemodel( name );
            done[name] = 1;
        }
    }

    // owner picks from the glTF dump (C: Games t6 model_dump viewer): `set df_extra_models "name1 name2"` BEFORE
    // loading the map precaches them so `!df catalog extra` shows them textured in game (df_catalog_extra_models)
    foreach ( name in df_catalog_extra_models() )
    {
        if ( isdefined( done[name] ) )
            continue;

        precachemodel( name );
        done[name] = 1;
        df_debug_print( "DF: extra model precached: " + name );
    }

    df_debug_print( "DF: " + registry + " registry models precached, " + getarraykeys( done ).size + " with the catalog" );
}

// =========================================================================================
// Catalog for `!df catalog <keyword> [page]` (df_main): candidate models the owner can look at in game,
// side by side, and pick into the registry with `!df catalog pick <n> <kind>`. Every name is from
// tools/assets/xmodels_zm_transit.txt in an always-loaded zone (zm_transit, common_zm,
// so_zclassic_zm_transit; com_payphone_america is the one gump_busstation exception, already in the
// registry), so they render anywhere. All are precached at init by df_coords_precache(), which is what
// makes a live pick render. Keep it around 45 names: each costs a model slot in the server tables.
// The keyword filters by substring of the name, so group words are part of the names themselves
// (buildable, rocks, sphere, pole, light, ...).
// =========================================================================================
df_catalog_models()
{
    m = [];

    // registry models (all kinds), so `!df catalog buildable` shows the current picks too
    m[m.size] = "p6_zm_buildable_sq_transceiver";  // relay base (radio, 26 x 7 x 19)
    m[m.size] = "p6_zm_buildable_sq_scaffolding";  // relay_top / part_b (lattice slab, 83 x 4 x 24)
    m[m.size] = "p6_zm_chain_fence_piece_end";     // relay_mast (fence end post, 13 x 117 x 3)
    m[m.size] = "p6_zm_buildable_sq_electric_box"; // part_c (the old fuse box, 13 x 20 x 4)
    m[m.size] = "p6_zm_buildable_sq_meteor";       // beacon / ember (small rock, 5 x 5 x 6)
    m[m.size] = "p6_zm_buildable_battery";         // part_a (16 x 14 x 9)
    m[m.size] = "p6_zm_buildable_etrap_tvtube";    // tv (CRT tube, 21 x 21 x 22, pose 270/180)
    m[m.size] = "p6_zm_buildable_pswitch_body";    // fuse / socket (breaker panel, 36 x 63 x 16)
    m[m.size] = "p6_zm_buildable_turbine_fan";     // orb (rotor disc, 25 x 10 x 25)
    m[m.size] = "p6_zm_keycard";                   // card
    m[m.size] = "p6_zm_screecher_hole";            // portal (108 x 18 x 105)
    m[m.size] = "p6_zm_rocks_small_cluster_03";    // brazier (lava-rock cairn, 88 x 16 x 77)
    m[m.size] = "com_payphone_america";            // phone (depot only)
    m[m.size] = "p6_zm_work_bench";                // table (31 x 44 x 88)
    m[m.size] = "p6_zm_buildable_jetgun_handles";  // receiver (hand grip, 11 x 4 x 10)
    m[m.size] = "p6_zm_buildable_jetgun_wires";    // spool (wire bundle, 25 x 7 x 25)
    m[m.size] = "zombie_skull";                    // skull (insta-kill skull, 16 x 23 x 21)
    m[m.size] = "c_zom_zombie_head_a";             // skull alternative (zombie head, 14 x 10 x 11)

    // antenna / mast candidates (relay_top, relay_mast)
    m[m.size] = "pb_pole_telephone_bulb";          // bulb lamp head (9 x 8 x 9, the old tv)
    m[m.size] = "afr_powerpole1";                  // power pole (tall)
    m[m.size] = "p_glo_powerline_tower_redwhite";  // red/white pylon (huge)
    m[m.size] = "p6_garage_pipes_1x128";           // a 128-unit pipe: plain mast
    m[m.size] = "p_glo_street_light02";            // street light pole
    m[m.size] = "p6_zm_buildable_turbine_rudder";  // aircraft fin (turbine piece)
    m[m.size] = "p6_zm_raingutter_clamp";          // small metal bracket

    // orb candidates (round things)
    m[m.size] = "zombie_pickup_perk_bottle";       // perk bottle powerup
    m[m.size] = "p6_zm_rocks_medium_05";           // boulder
    m[m.size] = "p6_zm_rocks_small_cluster_01";
    m[m.size] = "p6_zm_rocks_large_cluster_01";
    m[m.size] = "test_sphere_lambert";             // untextured grey sphere (the old orb)
    m[m.size] = "test_sphere_silver";              // chrome sphere
    m[m.size] = "semtex_bag";                      // rounded bag
    m[m.size] = "p_glo_cinder_block";

    // brazier / container candidates
    m[m.size] = "afr_barrel_biohazard_white_rust"; // white biohazard drum (the old brazier, 29 x 44 x 29)
    m[m.size] = "p6_zm_buildable_pap_table";       // the PaP table legs (54 x 11 x 21, old table)
    m[m.size] = "p6_zm_buildable_etrap_base";      // electric trap frame
    m[m.size] = "p_rus_tank_chemical_dmg";         // dented chemical tank
    m[m.size] = "p_glo_tools_chest_short";         // tool chest
    m[m.size] = "p6_zm_buildable_turret_mower";    // lawn mower
    m[m.size] = "p_glo_sandbags_green_lego_mdl";

    // tv / screen / light candidates
    m[m.size] = "berlin_traffic_signal_01_red_light"; // traffic light head
    m[m.size] = "p6_lights_club_recessed";         // recessed ceiling light
    m[m.size] = "p_lights_cagelight02_red_off";    // red cage light
    m[m.size] = "p_glo_lights_fluorescent_yellow"; // fluorescent tube
    m[m.size] = "p_rus_desklamp_wmd_on";           // desk lamp
    m[m.size] = "p6_zm_bank_deposit_box_open_02";  // open deposit box

    // misc props
    m[m.size] = "p6_zm_keys";                      // key ring
    m[m.size] = "p_jun_caution_sign";              // caution sign
    m[m.size] = "com_stepladder_large_closed";     // step ladder
    m[m.size] = "berlin_wood_table";               // wooden table (table alternative)
    m[m.size] = "p6_zm_buildable_pap_body";        // PaP machine body (table alternative, tall)
    return m;
}

// Catalog names containing `keyword` ("all" or "" = every name), in catalog order.
df_catalog_filter( keyword )
{
    out = [];

    if ( keyword == "extra" )
        return df_catalog_extra_models();

    foreach ( name in df_catalog_models() )
    {
        if ( keyword == "" || keyword == "all" || issubstr( name, keyword ) )
            out[out.size] = name;
    }

    foreach ( name in df_catalog_extra_models() )
    {
        if ( keyword == "" || keyword == "all" || issubstr( name, keyword ) )
            out[out.size] = name;
    }

    return out;
}

// Model names from the console dvar df_extra_models (`set df_extra_models "p_glo_x p6_zm_y"`, space or comma
// separated, set BEFORE the map loads). Names must exist in tools/assets/xmodels_zm_transit.txt: an unknown
// model name is a fatal error at load, so check the spelling against the list first.
df_catalog_extra_models()
{
    out = [];
    raw = getdvar( "df_extra_models" );

    if ( !isdefined( raw ) || raw == "" )
        return out;

    foreach ( tok in strtok( raw, " ,;" ) )
    {
        if ( tok != "" )
            out[out.size] = tolower( tok );
    }

    return out;
}

// The registry kind currently using `name`, or undefined (so a catalog preview can stand a model up
// with its known pose).
df_model_kind_of( name )
{
    if ( !isdefined( level.df_models ) )
        df_models_init();

    foreach ( kind, n in level.df_models )
    {
        if ( n == name )
            return kind;
    }

    return undefined;
}
