// Dead Frequency - carry presentation layer in the style of "Scavenger Project" (zm_scavenger.gsc v1.9,
// created by NickB_05, v1.1 fixes by SyntaXError), the Mob-of-the-Dead-like piece carrying mod the owner runs
// next to us. Its header asks for credit when it is used by another project; it names no URL.
//
// What it does (nothing here touches zm_scavenger.gsc or any mc_* field; every field is df_scav_*):
//   1. df_scav_notify: the same top-left "Jet Gun (1/3)" notice Scavenger shows on a pickup
//      (zm_scavenger.gsc:265 mc_show_piece_notify: icon 20x20 at x -12 / text fontscale 1.3 at x -8, both
//      vertalign top, default font, no sort, 2.5 s then a 0.5 s fade), one row lower (y +30) so both never
//      overlap when they fire in the same second.
//   2. A "Dead Frequency" square in Scavenger's TAB row (zm_scavenger.gsc:786 mc_tab_square_watch): same
//      border shader zm_hud_icon_sq_tranceiver 33x33 alpha 0.7 sort 1, inner icon 25x25 sort 3, counter "n/N"
//      below (sort 3), check mark zm_hud_icon_sq_scafold 10x10 sort 4 when complete, square lifted 10 px while
//      something is carried. Placed right after their fifth TranZit square (x 91 + 5 * 39 = 286; their
//      plow / hatch / ladder block starts at 634 - 3 * 39 = 517), or at x 91 when Scavenger is not installed.
//      Console dvar `df_scav_slot <n>` forces slot n (n * 39 + 91) for a Scavenger version with another row.
//      TAB is read through our own notifyonplayercommand( "+scores" / "-scores" ) registrations
//      (zm_scavenger.gsc:790 registers its own names), never theirs.
//   3. df_scav_carry_set / df_scav_carry_clear: the API the acts call instead of the bottom-right icons
//      (df_carry_icon / df_part_icons_* / df_relay_carry_hud), see tools/requests_scav.md.
//   4. df_scav_busy / df_scav_wait_all_free: "do not move a player during Scavenger's 3 s build hold"
//      (player.mc_build_active, zm_scavenger.gsc:1956; player.mc_key_inserting, :1400).
// Detection (df_scav_present): a live probe of the level fields Scavenger's init() writes synchronously at
// level init (mc_gated_buildables / mc_immediate_buildables / mc_have, zm_scavenger.gsc:98-119) plus the two it
// writes later on "buildables_setup" (mc_buildables_ready / mc_stub_by_name, :485). Any one of them counts, so
// an older or newer version that renames one field still registers; the verdict "absent" is only settled after
// a 5 s poll (df_scav_detect), and until then every read is live, so nothing depends on the load order.
// Shaders: all vanilla, listed in tools/assets/shaders_zm_transit.txt (zm_hud_icon_battery :131,
// zm_hud_icon_jetgun_wires :141, zm_hud_icon_spool :150, zm_hud_icon_sq_keycard :151, zm_hud_icon_sq_meteor :154,
// zm_hud_icon_sq_powerbox :155, zm_hud_icon_sq_scafold :156, zm_hud_icon_sq_tranceiver :157), all precached by
// the map (Scavenger only re-precaches four of them). Sound on pickup stays in the acts: zmb_buildable_pickup,
// the vanilla part pickup (zm_transit_buildables.gsc:249 onpickup_common) that a Scavenger collect also plays.
// Polling: the only permanent loop is the per-player TAB loop, asleep on a waittill until TAB goes down and
// then 0.05 s ticks that compare one integer (level.df_scav_rev) and redraw only when a value changed.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_systems;
#include scripts\zm\zm_transit\df_coords;

// ------------------------------------------------------------------- init ----

// Called once from df_boot (df_main.gsc). Idempotent: an act that calls df_scav_carry_set before df_boot
// triggers the same init once and df_boot's call is then a no-op. Layout numbers mirror zm_scavenger.gsc:45-52
// (MC_TAB_SQUARE_X 91, _Y 97, _Y_ACTIVE 87, _SIZE 29, _BORDER_PAD 2, _SLOT_GAP 6, _CHECK_SIZE 10).
df_scav_init()
{
    if ( isdefined( level.df_scav_cfg ) )
        return;

    level.df_scav_slots = [];
    level.df_scav_kind = undefined;
    level.df_scav_present = undefined; // undefined = pending (live probe), 0 = absent, 1 = present
    level.df_scav_rev = 0;             // bumped on every state change; the TAB loops redraw only when it moved

    cfg = spawnstruct();
    cfg.tab_x = 91;
    cfg.tab_y = 97;
    cfg.tab_y_active = 87;
    cfg.sq = 29;
    cfg.pad = 2;
    cfg.gap = 6;
    cfg.check = 10;
    cfg.their_slots = 5;      // TranZit row: turbine, shield, turret, etrap, jetgun (zm_scavenger.gsc:753-757)
    cfg.notify_y = -23 + 30;  // their notice sits at y -23 (zm_scavenger.gsc:281); ours one row lower
    level.df_scav_cfg = cfg;

    level thread df_scav_detect();
    level thread df_scav_connect_watcher();
    level thread df_scav_debug_listener();
    df_debug_print( "DF: scav layer up (Scavenger detection pending)" );
}

// Settles the verdict: Scavenger's init() writes its level fields synchronously at level init, long before
// df_boot runs (start_zombie_round_logic), so the first probe normally answers. We still poll for 5 s in case
// a loader runs it later; until then df_scav_present() probes live, so nothing waits on this thread.
df_scav_detect()
{
    level endon( "end_game" );

    for ( i = 0; i < 10; i++ )
    {
        if ( df_scav_probe() )
            break;

        wait 0.5;
    }

    was = level.df_scav_present;
    level.df_scav_present = df_scav_probe();

    if ( !isdefined( was ) || was != level.df_scav_present )
        level.df_scav_rev++;

    if ( level.df_scav_present )
        df_debug_print( "DF: scav: Scavenger Project detected, TAB square after their row (x " + df_scav_slot_x() + ")" );
    else
        df_debug_print( "DF: scav: Scavenger Project not installed, TAB square at x " + df_scav_slot_x() );
}

// Live probe: any of the level fields zm_scavenger.gsc writes (v1.9: init :98-119 synchronously,
// mc_setup_custom_prompts :485-486 after "buildables_setup"). No function call into their file, no dependency
// on one field name.
df_scav_probe()
{
    if ( isdefined( level.mc_gated_buildables ) || isdefined( level.mc_immediate_buildables ) || isdefined( level.mc_have ) )
        return 1;

    if ( isdefined( level.mc_buildables_ready ) || isdefined( level.mc_stub_by_name ) )
        return 1;

    return 0;
}

// 1 when Scavenger is loaded. Settled value once df_scav_detect finished; live probe while pending (a hit
// while pending is cached at once, so a TAB square drawn during the first seconds already sits in the right
// place and never jumps).
df_scav_present()
{
    if ( isdefined( level.df_scav_present ) )
        return level.df_scav_present;

    if ( df_scav_probe() )
    {
        level.df_scav_present = 1;
        level.df_scav_rev++;
        return 1;
    }

    return 0;
}

// Players already in the game when df_boot runs never fire "connected" again (same pattern as
// df_systems::df_hud_connect_watcher).
df_scav_connect_watcher()
{
    level endon( "end_game" );

    foreach ( player in getplayers() )
        player thread df_scav_player_watchers();

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread df_scav_player_watchers();
    }
}

df_scav_player_watchers()
{
    if ( is_true( self.df_scav_watched ) )
        return;

    self.df_scav_watched = 1;
    self thread df_scav_tab_watch();
    self thread df_scav_disconnect_watch();
}

// Client hud elems are not freed with the client (vanilla _zm_laststand.gsc:334 does the same cleanup).
df_scav_disconnect_watch()
{
    self waittill( "disconnect" );

    if ( !isdefined( self ) )
        return;

    self df_scav_notify_clear();
    self df_scav_tab_destroy();
}

// ------------------------------------------------------------- kinds ----

// Kind -> HUD icon (tools/assets/shaders_zm_transit.txt). Every kind the acts pass (grep df_scav_carry_set):
// parts (Step 2 relay parts, team count; item part_a / part_b / receiver picks the notice icon), relay (Step 4
// carry), card (R1 key card), battery (R1, n/4), spool (R2, n/lamps), skull and ember (M1 / M2, 1/1),
// orb (Step 6, charges). Unknown kind -> the powerbox.
df_scav_icon( kind )
{
    switch ( kind )
    {
        case "receiver":
            return "zm_hud_icon_jetgun_wires"; // the wire coil (owner 2026-09-09)
        case "spool":
            return "zm_hud_icon_spool";
        case "battery":
            return "zm_hud_icon_battery";
        case "ember":
        case "skull":
            return "zm_hud_icon_sq_meteor";
        case "part_a":
            return "zm_hud_icon_sq_tranceiver"; // the radio
        case "part_b":
            return "zm_hud_icon_sq_scafold"; // the mast (no post icon in the map, the lattice is the nearest)
        case "part_c":
        case "parts":
            return "zm_hud_icon_sq_powerbox";
        case "relay":
            return "zm_hud_icon_sq_tranceiver";
        case "card":
            return "zm_hud_icon_sq_keycard";
        case "orb":
            return "zm_hud_icon_sq_meteor";
    }

    return "zm_hud_icon_sq_powerbox";
}

// Kind -> the name printed in the notice, like Scavenger's mc_display_name (zm_scavenger.gsc:170): the name of
// the thing being assembled, then "(n/N)" when N > 1.
df_scav_display_name( kind )
{
    switch ( kind )
    {
        case "receiver":
            return "Wire coil";
        case "spool":
            return "Wire spool";
        case "battery":
            return "Battery";
        case "ember":
            return "Ember";
        case "skull":
            return "Stone";
        case "parts":
        case "part_a":
        case "part_b":
        case "part_c":
            return "Relay parts";
        case "relay":
            return "Relay";
        case "card":
            return "Key Card";
        case "orb":
            return "Orb";
    }

    return "Dead Frequency";
}

// ---------------------------------------------------------- carry API ----

// The act owners call this on every pickup / count change (see tools/requests_scav.md).
//   kind   "parts" | "relay" | "card" | "battery" | "spool" | "skull" | "ember" | "orb" (the TAB square shows
//          the kind set most recently; when it is cleared, the most recent one still set)
//   count  what the team has now (parts collected, orb charges, 1 for a carried relay / card); default 0
//   total  the goal (3 parts, level.df_s6_target charges, 1); default 1
//   who    the player who picked it up: he gets the top-left notice; undefined = every player
//   item   optional notice icon kind ("part_a" / "part_b" / "receiver" / ...); default: the kind's icon
// Plays no sound: the acts keep their zmb_buildable_pickup at the pickup itself.
df_scav_carry_set( kind, count, total, who, item )
{
    if ( !isdefined( level.df_scav_cfg ) )
        df_scav_init();

    if ( !isdefined( count ) )
        count = 0;

    if ( !isdefined( total ) )
        total = 1;

    slot = spawnstruct();
    slot.count = count;
    slot.total = total;
    slot.stamp = gettime();
    level.df_scav_slots[kind] = slot;
    level.df_scav_kind = kind;
    level.df_scav_rev++;

    icon_kind = kind;

    if ( isdefined( item ) )
        icon_kind = item;

    progress = undefined;

    if ( total > 1 )
        progress = count + "/" + total;

    name = df_scav_display_name( kind );
    shader = df_scav_icon( icon_kind );

    if ( isdefined( who ) && isplayer( who ) )
        who thread df_scav_notify( name, shader, progress );
    else
    {
        foreach ( player in getplayers() )
            player thread df_scav_notify( name, shader, progress );
    }

    if ( getdvarint( "df_debug" ) == 1 )
        df_debug_print( "DF: scav " + kind + " " + count + "/" + total );
}

// The thing is gone (built, inserted, placed, reset): the square goes back to the most recent other kind, or idle.
df_scav_carry_clear( kind )
{
    if ( !isdefined( level.df_scav_slots ) || !isdefined( level.df_scav_slots[kind] ) )
        return;

    level.df_scav_slots[kind] = undefined;

    if ( isdefined( level.df_scav_kind ) && level.df_scav_kind == kind )
        level.df_scav_kind = df_scav_next_kind();

    level.df_scav_rev++;

    if ( getdvarint( "df_debug" ) == 1 )
        df_debug_print( "DF: scav " + kind + " cleared" );
}

// The kind set most recently among those still set (any kind, no fixed list), or undefined.
df_scav_next_kind()
{
    best = undefined;
    best_stamp = -1;

    foreach ( k in getarraykeys( level.df_scav_slots ) )
    {
        slot = level.df_scav_slots[k];

        if ( !isdefined( slot ) )
            continue;

        if ( slot.stamp > best_stamp )
        {
            best_stamp = slot.stamp;
            best = k;
        }
    }

    return best;
}

// ------------------------------------------------------------- notice ----

// self = player. Top-left notice identical to zm_scavenger.gsc:265 mc_show_piece_notify (icon 20x20
// alignx right at x -12, text fontscale 1.3 alignx left at x -8, both vertalign top, default font, 2.5 s then
// 0.5 s fade), on the row below theirs (level.df_scav_cfg.notify_y). A newer notice replaces an older one.
// hidewheninmenu = 1 (theirs leaves the default): ours hides in the pause menu, both stay up under TAB.
df_scav_notify( display_name, icon_shader, progress_text )
{
    self endon( "disconnect" );

    if ( !isdefined( level.df_scav_cfg ) )
        df_scav_init();

    self df_scav_notify_clear();
    y = level.df_scav_cfg.notify_y;

    icon = newclienthudelem( self );
    icon.horzalign = "left";
    icon.vertalign = "top";
    icon.alignx = "right";
    icon.aligny = "top";
    icon.x = -12;
    icon.y = y;
    icon.alpha = 1;
    icon.hidewheninmenu = 1;

    if ( isdefined( icon_shader ) )
        icon setshader( icon_shader, 20, 20 );

    self.df_scav_notify_icon = icon;
    icon thread df_scav_fade_destroy( 2.5 );

    if ( !isdefined( display_name ) )
        return;

    text = newclienthudelem( self );
    text.horzalign = "left";
    text.vertalign = "top";
    text.alignx = "left";
    text.aligny = "top";
    text.x = -8;
    text.y = y;
    text.fontscale = 1.3;
    text.alpha = 1;
    text.hidewheninmenu = 1;

    if ( isdefined( progress_text ) )
        text settext( display_name + " (" + progress_text + ")" );
    else
        text settext( display_name );

    self.df_scav_notify_text = text;
    text thread df_scav_fade_destroy( 2.5 );
}

// self = player. Removes a notice still on screen.
df_scav_notify_clear()
{
    if ( isdefined( self.df_scav_notify_icon ) )
        self.df_scav_notify_icon destroy();

    if ( isdefined( self.df_scav_notify_text ) )
        self.df_scav_notify_text destroy();

    self.df_scav_notify_icon = undefined;
    self.df_scav_notify_text = undefined;
}

// self = hud elem. Same timing as zm_scavenger.gsc:353 mc_fade_and_destroy.
df_scav_fade_destroy( delay )
{
    self endon( "death" );
    wait delay;

    if ( !isdefined( self ) )
        return;

    self fadeovertime( 0.5 );
    self.alpha = 0;
    wait 0.5;

    if ( isdefined( self ) )
        self destroy();
}

// ------------------------------------------------------------ TAB square ----

// x of our square: after Scavenger's five TranZit squares (pitch size + 2 * pad + gap = 39, so 286; their
// right block starts at 634 - 3 * 39 = 517), or their first position when they are not installed. The console
// dvar `df_scav_slot <n>` (empty = auto) forces slot n for a Scavenger version whose row has another length.
df_scav_slot_x()
{
    cfg = level.df_scav_cfg;
    pitch = cfg.sq + cfg.pad * 2 + cfg.gap;
    forced = getdvar( "df_scav_slot" );

    if ( isdefined( forced ) && forced != "" )
        return cfg.tab_x + int( forced ) * pitch;

    if ( df_scav_present() )
        return cfg.tab_x + cfg.their_slots * pitch;

    return cfg.tab_x;
}

// self = player. Registers our own "+scores" / "-scores" notifies (zm_scavenger.gsc:790 does the same with
// its own names) and draws the square while TAB is held. Asleep on a waittill while TAB is up; while it is
// held, one 0.05 s tick compares level.df_scav_rev and redraws only when something changed (theirs redraws
// every tick, ours looks the same).
df_scav_tab_watch()
{
    self endon( "disconnect" );

    self notifyonplayercommand( "df_scav_tab_down", "+scores" );
    self notifyonplayercommand( "df_scav_tab_up", "-scores" );
    self.df_scav_tab_held = 0;
    self thread df_scav_tab_key_listener( "df_scav_tab_up", 0 );

    while ( true )
    {
        if ( !self.df_scav_tab_held )
        {
            self waittill( "df_scav_tab_down" );
            self.df_scav_tab_held = 1;
        }

        self df_scav_tab_create();

        while ( self.df_scav_tab_held )
        {
            if ( self.df_scav_tab_rev != level.df_scav_rev )
                self df_scav_tab_update();

            wait 0.05;
        }

        self df_scav_tab_destroy();
    }
}

df_scav_tab_key_listener( name, held )
{
    self endon( "disconnect" );

    while ( true )
    {
        self waittill( name );
        self.df_scav_tab_held = held;
    }
}

// Border and icon as zm_scavenger.gsc:820-844: border = zm_hud_icon_sq_tranceiver (size + 2 pad) alpha 0.7
// white sort 1; icon (size - 2 pad) alpha 0.5 sort 3; both centre/middle aligned at the slot x. The first
// df_scav_tab_update follows at once (rev -1 never matches).
df_scav_tab_create()
{
    cfg = level.df_scav_cfg;
    x = df_scav_slot_x();

    border = self df_scav_tab_elem( x, cfg.tab_y, 1 );
    border.alpha = 0.7;
    border.color = ( 1, 1, 1 );
    border setshader( "zm_hud_icon_sq_tranceiver", cfg.sq + cfg.pad * 2, cfg.sq + cfg.pad * 2 );
    self.df_scav_tab_border = border;

    icon = self df_scav_tab_elem( x, cfg.tab_y, 3 );
    icon.alpha = 0.5;
    self.df_scav_tab_icon = icon;
    self.df_scav_tab_icon_kind = undefined;
    self.df_scav_tab_rev = -1;
}

// One centre/middle aligned top-left elem at (x, y) with the given sort, like every square of theirs.
df_scav_tab_elem( x, y, sort )
{
    hud = newclienthudelem( self );
    hud.horzalign = "left";
    hud.vertalign = "top";
    hud.alignx = "center";
    hud.aligny = "middle";
    hud.x = x;
    hud.y = y;
    hud.sort = sort;
    hud.hidewheninmenu = 0; // the scoreboard IS a menu: keep it visible while TAB is held, as theirs
    return hud;
}

df_scav_tab_destroy()
{
    if ( isdefined( self.df_scav_tab_border ) )
        self.df_scav_tab_border destroy();

    if ( isdefined( self.df_scav_tab_icon ) )
        self.df_scav_tab_icon destroy();

    if ( isdefined( self.df_scav_tab_counter ) )
        self.df_scav_tab_counter destroy();

    if ( isdefined( self.df_scav_tab_check ) )
        self.df_scav_tab_check destroy();

    self.df_scav_tab_border = undefined;
    self.df_scav_tab_icon = undefined;
    self.df_scav_tab_counter = undefined;
    self.df_scav_tab_check = undefined;
    self.df_scav_tab_icon_kind = undefined;
    self.df_scav_tab_rev = undefined;
}

// State rules as zm_scavenger.gsc:1040 mc_update_tab_slot_hud: nothing -> dim icon at y 97; partial
// (0 < count < total) -> counter "n/total" under the square and the square at y 87; complete
// (count >= total) -> icon alpha 1 + check mark bottom-right. Runs only when level.df_scav_rev moved
// (a carry change, or the detection verdict), so the strings here are built once per change, not per tick.
df_scav_tab_update()
{
    cfg = level.df_scav_cfg;
    x = df_scav_slot_x();
    kind = level.df_scav_kind;
    y = cfg.tab_y;
    need_counter = 0;
    need_check = 0;
    have = 0;
    total = 0;
    icon_kind = "parts";
    alpha = 0.5;

    if ( isdefined( kind ) && isdefined( level.df_scav_slots[kind] ) )
    {
        slot = level.df_scav_slots[kind];
        icon_kind = kind;
        have = slot.count;
        total = slot.total;

        if ( total > 0 && have >= total )
        {
            alpha = 1;
            need_check = 1;
        }
        else if ( have > 0 )
        {
            need_counter = 1;
            y = cfg.tab_y_active;
        }
    }

    icon = self.df_scav_tab_icon;

    if ( !isdefined( self.df_scav_tab_icon_kind ) || self.df_scav_tab_icon_kind != icon_kind )
    {
        icon setshader( df_scav_icon( icon_kind ), cfg.sq - cfg.pad * 2, cfg.sq - cfg.pad * 2 );
        self.df_scav_tab_icon_kind = icon_kind;
    }

    icon.alpha = alpha;
    icon.x = x;
    icon.y = y;
    self.df_scav_tab_border.x = x;
    self.df_scav_tab_border.y = y;

    self df_scav_tab_counter_sync( need_counter, x, y, have, total );
    self df_scav_tab_check_sync( need_check, x, y );
    self.df_scav_tab_rev = level.df_scav_rev;
}

// Counter text under the square: fontscale 1.17, y = square + size / 2 + pad + 6 (zm_scavenger.gsc:1171).
df_scav_tab_counter_sync( need, x, y, have, total )
{
    cfg = level.df_scav_cfg;

    if ( need && !isdefined( self.df_scav_tab_counter ) )
    {
        counter = self df_scav_tab_elem( x, y, 3 );
        counter.fontscale = 1.17;
        counter.alpha = 1;
        self.df_scav_tab_counter = counter;
    }
    else if ( !need && isdefined( self.df_scav_tab_counter ) )
    {
        self.df_scav_tab_counter destroy();
        self.df_scav_tab_counter = undefined;
    }

    if ( !isdefined( self.df_scav_tab_counter ) )
        return;

    self.df_scav_tab_counter.x = x;
    self.df_scav_tab_counter.y = y + ( cfg.sq / 2 ) + cfg.pad + 6;
    self.df_scav_tab_counter settext( have + "/" + total );
}

// Check mark zm_hud_icon_sq_scafold 10x10 in the bottom-right corner of the square (zm_scavenger.gsc:1198).
df_scav_tab_check_sync( need, x, y )
{
    cfg = level.df_scav_cfg;

    if ( need && !isdefined( self.df_scav_tab_check ) )
    {
        check = self df_scav_tab_elem( x, y, 4 );
        check.alpha = 1;
        check setshader( "zm_hud_icon_sq_scafold", cfg.check, cfg.check );
        self.df_scav_tab_check = check;
    }
    else if ( !need && isdefined( self.df_scav_tab_check ) )
    {
        self.df_scav_tab_check destroy();
        self.df_scav_tab_check = undefined;
    }

    if ( !isdefined( self.df_scav_tab_check ) )
        return;

    self.df_scav_tab_check.x = x + ( cfg.sq / 2 ) - ( cfg.check / 2 );
    self.df_scav_tab_check.y = y + ( cfg.sq / 2 ) - ( cfg.check / 2 );
}

// --------------------------------------------------------- busy guard ----

// 1 while Scavenger holds this player at a bench: mc_build_active (3 s build hold, zm_scavenger.gsc:1956,
// player frozen with the builder weapon) or mc_key_inserting (Die Rise key, :1400). Spec 9: do not take
// control of (teleport) a player while true. Works with or without Scavenger (both undefined -> 0).
df_scav_busy( player )
{
    if ( !isdefined( player ) )
        return 0;

    return is_true( player.mc_build_active ) || is_true( player.mc_key_inserting );
}

// Blocks until no valid player is busy, at most max_seconds (a build hold lasts 3 s; 3.5 covers it).
// For the teleport sites: call it once before the loop that moves everyone. Returns at once when nobody is
// busy (the usual case), so the 0.05 s tick only runs during an actual hold.
df_scav_wait_all_free( max_seconds )
{
    if ( !isdefined( max_seconds ) )
        max_seconds = 3.5;

    deadline = gettime() + int( max_seconds * 1000 );

    while ( gettime() < deadline )
    {
        busy = 0;

        foreach ( player in getplayers() )
        {
            if ( df_scav_busy( player ) )
                busy = 1;
        }

        if ( !busy )
            return;

        wait 0.05;
    }

    df_debug_print( "DF: scav: a player was still in a build hold after " + max_seconds + " s, moving on" );
}

// -------------------------------------------------------------- debug ----

// `!df fire scav`      -> state dump + a demo notice on every screen ("Orb (2/3)" with the meteor icon)
// `!df fire scav_slot` -> fake "Relay parts 2/3" in the TAB square for 20 s, then complete for 10 s,
//                         then cleared (hold TAB to watch it move)
df_scav_debug_listener()
{
    level endon( "end_game" );

    for ( ;; )
    {
        which = level waittill_any_return( "df_debug_scav", "df_debug_scav_slot" );

        if ( which == "df_debug_scav_slot" )
        {
            level thread df_scav_debug_slot_demo();
            continue;
        }

        df_scav_debug_dump();

        foreach ( player in getplayers() )
            player thread df_scav_notify( "Orb", df_scav_icon( "orb" ), "2/3" );
    }
}

df_scav_debug_dump()
{
    kind = "none";

    if ( isdefined( level.df_scav_kind ) )
        kind = level.df_scav_kind;

    verdict = "pending";

    if ( isdefined( level.df_scav_present ) )
        verdict = "" + level.df_scav_present;

    df_debug_print( "DF: scav present " + verdict + " (probe " + df_scav_probe() + ") slot_x " + df_scav_slot_x() + " kind " + kind + " rev " + level.df_scav_rev );

    foreach ( k in getarraykeys( level.df_scav_slots ) )
    {
        if ( isdefined( level.df_scav_slots[k] ) )
            df_debug_print( "DF: scav slot " + k + " " + level.df_scav_slots[k].count + "/" + level.df_scav_slots[k].total );
    }

    foreach ( player in getplayers() )
        df_debug_print( "DF: scav " + player.name + " tab_held " + is_true( player.df_scav_tab_held ) + " busy " + df_scav_busy( player ) );
}

df_scav_debug_slot_demo()
{
    level endon( "end_game" );

    df_scav_carry_set( "parts", 2, 3, undefined, "part_b" );
    df_debug_print( "DF: scav demo: hold TAB, the square shows 2/3 (20 s), then complete (10 s), then idle" );
    wait 20;
    df_scav_carry_set( "parts", 3, 3, undefined, "part_c" );
    wait 10;
    df_scav_carry_clear( "parts" );
}
