// Dead Frequency - step machine and player-count scaling (spec sections 5, 6 and 7).
// Included by df_main.gsc and by every act file (df_act*.gsc, df_finale.gsc) so acts can register steps.
//
// Contract used by the act files (do not rename): df_register_step, df_complete, df_touch, df_is_done,
// df_set_side, df_scaled, df_scaled_for, df_scaled_step, df_player_count, df_hint_now,
// df_step_focus, level.df_side, level.df_done, notifies "df_<key>_done", "df_step_done",
// "df_step_available", "df_skip_<key>", "df_side_locked".
// Dialogue (owner 2026-09-08): the runner speaks <P>_START when a step becomes available and the stall
// ladder <P>_HINT_1 / <P>_HINT_2 (level.df_step_dlg, df_step_dlg_key picks the _RICH / _MAXIS variant);
// a step file may fire a rung early on an event with df_hint_now (audit 2026-09-08 section 4). The ladder
// and the event hints obey level.df_text_hints (df_systems df_text_hints_on, default on), NOT the puzzle
// prompt switch level.df_hints (dialogue audit v2 2026-09-09 section 1.0: the old shared gate muted the
// whole ladder in a normal game).
// Cues (art audit 2026-09-09 #1 / #2): STEP AVAILABLE = zmb_spawn_powerup to all + key glint on the step's
// focus (df_step_focus) until the first df_touch; STEP DONE = zmb_powerup_grabbed to all (df_complete).
// Own helpers are prefixed df_step_ / df_scale_.
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_transit\df_dialogue;
#include scripts\zm\zm_transit\df_systems;

// -------------------------------------------------------------- scaling ----

// Spec section 6 table, one row per key, four columns = 1..4 players. Owner decisions (2026-09-08) that
// differ from the spec are marked; the design audit of 2026-09-08 (tools/audit_design.md section 3)
// retuned fuse_souls, lamp_souls, brazier_burns, sweep_time and added orb_hp, capture_time, simon_len; the
// design audit v2 of 2026-09-09 (tools/audit_steps_v2.md sections 4 and 6) retuned lamp_souls and hold_time
// and added sweep_time_rich, s7_period, s7_cap_rich, s7_cap_maxis (Step 7 scaled backwards: solo was the
// hardest lobby).
// Rows nobody reads any more are kept so `!df scale` and the spec table stay complete: counter_mult (no
// step uses a generic counter), roof_cap (Act 1 relay takes hits, no cap), simon_len_1..3 (superseded by
// simon_len, one growing sequence), sweep_rounds (superseded by sweep_time, seconds from the first tuning),
// fuse_souls (STALE since the R1 refill became a battery per box, target 1: df_act2_rich reads nothing here).
df_init_scaling()
{
    level.df_scale = [];
    df_scale_row( "counter_mult", 1.0, 1.6, 2.1, 2.5 );
    df_scale_row( "roof_cap", 3, 4, 6, 8 );
    df_scale_row( "simon_len_1", 3, 4, 4, 4 );
    df_scale_row( "simon_len_2", 4, 5, 5, 5 );
    df_scale_row( "simon_len_3", 5, 6, 6, 6 );
    df_scale_row( "simon_len", 6, 6, 7, 7 ); // audit: R1 final Simon length (level.df_simon_final in df_act2_rich)
    df_scale_row( "fuse_souls", 6, 8, 10, 12 ); // STALE (audit v2 section 4): R1 refill is one battery per box (target 1), no soul quota; kept for `!df scale`
    df_scale_row( "lamp_souls", 12, 15, 18, 18 ); // audit v2 #6 (was 12/15/18/20: 4 nodes x 20 = 80 souls at 4 players): R2 per lamp, also Step 5 re-feed lamps
    df_scale_row( "capture_time", 240, 300, 300, 300 ); // audit (was a fixed 180 s): R1 Avogadro capture window in seconds
    df_scale_row( "cold_room_time", 60, 75, 90, 100 ); // M1 seconds
    df_scale_row( "cold_room_kills", 6, 9, 12, 15 ); // M1 denizens
    df_scale_row( "brazier_burns", 4, 5, 6, 7 ); // audit (was 3/4/5/6): M2 burning zombies per brazier
    df_scale_row( "nodes", 3, 3, 3, 4 ); // owner: spec says 1/2/3/4; always three lamps / braziers / charges, four with a full lobby
    df_scale_row( "sweep_rounds", 2, 1, 1, 1 ); // spec row, unused (see sweep_time)
    df_scale_row( "sweep_time", 360, 300, 270, 240 ); // audit (owner 300/240/210/180): Step 5 countdown in seconds from the first anchor (Maxis side)
    df_scale_row( "sweep_time_rich", 480, 360, 300, 270 ); // audit v2 #3: Richtofen's Step 5 clock (three denizen latches are RNG); df_act3_sweep reads it when level.df_side == "rich"
    df_scale_row( "hold_time", 75, 90, 105, 120 ); // audit v2 section 6 (owner 2026-09-09 had 75/95/115/135): Step 7 wave seconds
    df_scale_row( "hold_kills", 40, 55, 70, 85 ); // Step 7 kills inside the zone (spec row; the hold file defends an orb instead)
    df_scale_row( "orb_hp", 3000, 4200, 5400, 6600 ); // audit v3 co-op: the sprinter cap grows faster than the old hp did // owner 2026-09-09: was 2000..3200 // audit (was a fixed 2000): Step 7 orb hit points (level.df_s7_cfg_orb_hp in df_act3_hold)
    df_scale_row( "s7_period", 1.3, 1.0, 0.8, 0.7 ); // audit v2 section 6 (was 1.0/0.9/0.8/0.7): Step 7 seconds between sprinter spawns (df_act3_hold level.df_s7_cfg_period)
    df_scale_row( "s7_cap_rich", 10, 14, 18, 22 ); // audit v2 section 6 (was 12/16/20/24): Step 7 sprinters alive at once, Richtofen side (Avogadro adds pressure)
    df_scale_row( "s7_cap_maxis", 14, 18, 22, 26 ); // audit v2 section 6 (was 16/20/24/28): same, Maxis side (denizens add pressure)
}

// Stores one table row: index 0..3 = 1..4 players.
df_scale_row( key, v1, v2, v3, v4 )
{
    level.df_scale[key] = [];
    level.df_scale[key][0] = v1;
    level.df_scale[key][1] = v2;
    level.df_scale[key][2] = v3;
    level.df_scale[key][3] = v4;
}

// Live player count clamped to 1..4 (getplayers() is the vanilla builtin used by _zm.gsc everywhere).
df_player_count()
{
    n = getplayers().size;

    if ( n < 1 )
        n = 1;

    if ( n > 4 )
        n = 4;

    return n;
}

// Table value for the current player count. Read it once when a step starts (AGENT_BRIEF rule 8).
df_scaled( key )
{
    return df_scaled_for( key, df_player_count() );
}

// Table value for an explicit player count (clamped to 1..4).
df_scaled_for( key, count )
{
    if ( count < 1 )
        count = 1;

    if ( count > 4 )
        count = 4;

    return level.df_scale[key][count - 1];
}

// Spec section 6: scale on the player count recorded when `stepkey` became available, so a player
// leaving mid-step does not lower an active target. Falls back to the live count.
df_scaled_step( key, stepkey )
{
    if ( isdefined( level.df_step_players[stepkey] ) )
        return df_scaled_for( key, level.df_step_players[stepkey] );

    return df_scaled( key );
}

// --------------------------------------------------------- step machine ----

// Step order (also the order `!df status` and `!df goto` walk), prerequisites, side locks, stall hint
// keys and the per-step bookkeeping arrays. "act2" is a pseudo key set by df_complete when r2 or m2
// finishes, so Step 5 has a single prerequisite whatever the side.
df_init_steps()
{
    level.df_step_order = [];
    level.df_step_order[0] = "step1";
    level.df_step_order[1] = "step2";
    level.df_step_order[2] = "step3";
    level.df_step_order[3] = "step4";
    level.df_step_order[4] = "r1";
    level.df_step_order[5] = "r2";
    level.df_step_order[6] = "m1";
    level.df_step_order[7] = "m2";
    level.df_step_order[8] = "step5";
    level.df_step_order[9] = "step6";
    level.df_step_order[10] = "step7";
    level.df_step_order[11] = "finale";

    level.df_step_prereq = [];
    level.df_step_prereq["step1"] = [];
    level.df_step_prereq["step2"] = df_step_keys1( "step1" );
    level.df_step_prereq["step3"] = df_step_keys1( "step2" );
    level.df_step_prereq["step4"] = df_step_keys1( "step3" );
    level.df_step_prereq["r1"] = df_step_keys1( "step4" );
    level.df_step_prereq["r2"] = df_step_keys1( "r1" );
    level.df_step_prereq["m1"] = df_step_keys1( "step4" );
    level.df_step_prereq["m2"] = df_step_keys1( "m1" );
    level.df_step_prereq["step5"] = df_step_keys1( "act2" );
    level.df_step_prereq["step6"] = df_step_keys1( "step5" );
    level.df_step_prereq["step7"] = df_step_keys1( "step6" );
    level.df_step_prereq["finale"] = df_step_keys1( "step7" );

    // side-locked steps: their runner also waits for level.df_side (df_set_side, Step 4 socket)
    level.df_step_side = [];
    level.df_step_side["r1"] = "rich";
    level.df_step_side["r2"] = "rich";
    level.df_step_side["m1"] = "maxis";
    level.df_step_side["m2"] = "maxis";

    // Dialogue per step (owner 2026-09-08, df_dialogue.gsc): <P>_START when the step becomes available
    // (df_step_intro), then the stall ladder <P>_HINT_1 / <P>_HINT_2 (df_step_stall_watcher). Act 3 and
    // the finale are shared, so their keys exist as <KEY>_RICH / <KEY>_MAXIS; df_step_dlg_key picks the
    // variant of the locked side and falls back to the plain key.
    level.df_step_dlg = [];
    level.df_step_dlg["step1"] = "S1";
    level.df_step_dlg["step2"] = "S2";
    level.df_step_dlg["step3"] = "S3";
    level.df_step_dlg["step4"] = "S4";
    level.df_step_dlg["r1"] = "R1";
    level.df_step_dlg["r2"] = "R2";
    level.df_step_dlg["m1"] = "M1";
    level.df_step_dlg["m2"] = "M2";
    level.df_step_dlg["step5"] = "S5";
    level.df_step_dlg["step6"] = "S6";
    level.df_step_dlg["step7"] = "S7";
    level.df_step_dlg["finale"] = "FIN";

    // Ladder timing (seconds from step availability, owner 2026-09-08): HINT_1 at 4 min untouched, HINT_2
    // at 10 min, then HINT_2 again every 6 min. The intro waits 2 s so it queues behind the DONE line.
    level.df_hint_first_s = 240;
    level.df_hint_second_s = 600;
    level.df_hint_repeat_s = 360;
    level.df_intro_delay_s = 2;

    // step -> first rung key, kept for readers of the old table (`!df` helpers, reports). The finale has
    // no stall hints (df_step_finale_reached), so it is not listed.
    level.df_hint_key = [];

    foreach ( key, prefix in level.df_step_dlg )
    {
        if ( key != "finale" )
            level.df_hint_key[key] = prefix + "_HINT_1";
    }

    level.df_done = [];
    level.df_step_func = [];
    level.df_step_setup = [];
    level.df_step_avail_round = []; // round a step became available (`!df status`)
    level.df_step_avail_ms = []; // gettime() when it became available (console line of df_complete)
    level.df_step_players = []; // player count at that moment (df_scaled_step)
    level.df_step_touched = [];
    level.df_step_hint_said = []; // highest ladder rung an event hint spoke (df_hint_now)
    level.df_step_hint_ms = []; // gettime() of that event hint
    level.df_step_focus = []; // key -> origin of the AVAILABLE glint (df_step_focus)
    level.df_step_glint = []; // key -> the glint fx ent while it shows (df_step_glint_start / _stop)
    level.df_side = undefined;
    level.df_quiet_complete = 0;
    level.df_completed = 0; // set by df_finale on success (rewards / stat)
}

// One-element prerequisite list.
df_step_keys1( a )
{
    arr = [];
    arr[0] = a;
    return arr;
}

// Called by the act init functions. run_func: level function that sets the step up, blocks until it
// is solved and ends with df_complete( key ). setup_func (optional): fabricates the step's end state
// when "!df goto" skips it. Registering starts the runner, which parks until the prerequisites hold.
df_register_step( key, run_func, setup_func )
{
    if ( isdefined( level.df_step_func[key] ) )
    {
        df_debug_print( "DF: step " + key + " registered twice, keeping the first" );
        return;
    }

    level.df_step_func[key] = run_func;

    if ( isdefined( setup_func ) )
        level.df_step_setup[key] = setup_func;

    level thread df_step_runner( key );
}

// One thread per registered step: park, record availability, play the AVAILABLE cue, start the stall
// watcher, run the step. "df_skip_<key>" (sent by !df goto) ends this thread and, by contract, every
// thread of the step.
df_step_runner( key )
{
    level endon( "end_game" );
    level endon( "df_skip_" + key );

    df_wait_prereq( key );

    if ( df_is_done( key ) )
        return;

    level.df_step_avail_round[key] = level.round_number;
    level.df_step_avail_ms[key] = gettime();
    level.df_step_players[key] = df_player_count();
    level notify( "df_step_available", key );
    level thread df_step_available_cue( key );
    level thread df_step_glint_skip_watch( key );
    level thread df_step_intro( key );
    level thread df_step_stall_watcher( key );
    df_debug_print( "DF: step available " + key );

    level [[ level.df_step_func[key] ]]();

    // reached only when the run func returned by itself (a skip ends this thread first)
    if ( !df_is_done( key ) )
        df_debug_print( "DF: run func of " + key + " returned without df_complete" );
}

// True when the step's side (if any) is locked and every prerequisite key is done.
df_prereq_met( key )
{
    if ( isdefined( level.df_step_side[key] ) )
    {
        if ( !isdefined( level.df_side ) || level.df_side != level.df_step_side[key] )
            return false;
    }

    foreach ( pre in level.df_step_prereq[key] )
    {
        if ( !df_is_done( pre ) )
            return false;
    }

    return true;
}

// Parking loop of a runner. Wakes on every "df_step_done" (sent by df_complete, df_set_side and the end
// of a goto) and re-checks. Goto parking: `!df goto <target>` (df_main.gsc df_debug_goto) sets
// level.df_goto_busy = 1 BEFORE it completes the skipped steps one by one; without this extra check the
// runner of an intermediate step would see its prerequisite met, start for one frame and then be
// killed by its "df_skip_" notify, leaving half-spawned world state. The goto clears the flag and sends
// one last "df_step_done" ("goto") when everything up to the target is fabricated, so only the target's
// runner leaves this loop. Unchanged behaviour, documented.
df_wait_prereq( key )
{
    while ( !df_prereq_met( key ) || is_true( level.df_goto_busy ) )
        level waittill( "df_step_done" );
}

// True once df_complete( key ) ran (also for the pseudo key "act2").
df_is_done( key )
{
    return is_true( level.df_done[key] );
}

// Marks a step done, removes its AVAILABLE glint, plays the uniform STEP DONE sting and wakes the parked
// runners. The sting is the ONLY "step done" sound of the quest (art audit 2026-09-09 #1: zmb_powerup_grabbed
// means "step done" and nothing else; steps play zmb_sq_navcard_success for their sub-goals instead), so the
// quiet flag is the one way to skip it: quiet = 1 as the 2nd argument, or level.df_quiet_complete = 1 right
// before the call for callers that cannot change the call (consumed here). Steps should NOT pass it just
// because their tower fx plays: players must hear the same sting at every step end. Debug exception: no
// sting while "!df goto" fabricates skipped steps (one sting per skipped step would be noise).
df_complete( key, quiet )
{
    if ( df_is_done( key ) )
        return;

    level.df_done[key] = 1;

    if ( key == "r2" || key == "m2" )
        level.df_done["act2"] = 1;

    df_step_glint_stop( key );
    silent = is_true( quiet ) || is_true( level.df_quiet_complete ) || is_true( level.df_goto_busy );
    level.df_quiet_complete = 0;

    if ( !silent )
        df_step_complete_cue();

    df_debug_print( "DF: step complete " + key + df_step_elapsed_text( key ) );
    level notify( "df_" + key + "_done" );
    level notify( "df_step_done", key );
}

// The one "step done" sting, heard by everyone: zmb_powerup_grabbed (owner 2026-09-08, was
// zmb_cha_ching_loud), on the owner's list of aliases audible as 2D sounds (tools/POLISH_BRIEF.md);
// vanilla plays it on every power-up grab (Core/maps/mp/zombies/_zm_powerups.gsc:953).
// playsoundtoplayer( alias, player ) as in Core/maps/mp/zombies/_zm.gsc:1843.
df_step_complete_cue()
{
    foreach ( player in getplayers() )
        player playsoundtoplayer( "evt_bridge_collapse_start", player ); // owner pick 2026-09-11: STEP DONE = the bridge groan
}

// STEP AVAILABLE cue (art audit 2026-09-09 #2): zmb_spawn_powerup to every player (the power-up drop sound,
// zmeat.gsc:2080 = "something new is in the world") right after "df_step_available", plus the vanilla
// "take me" glint (fx_zmb_tranzit_key_glint, zm_transit_fx.gsc:105) on the step's focus point until the
// first df_touch, df_complete or skip. A step without a registered focus gets the sound only. Nothing
// during a goto (the target step's runner still plays it once the jump is over).
df_step_available_cue( key )
{
    if ( is_true( level.df_goto_busy ) )
        return;

    foreach ( player in getplayers() )
        player playsoundtoplayer( "zmb_screecher_portal_arrive", player ); // owner pick 2026-09-11: AVAILABLE = portal arrive

    df_step_glint_start( key );
}

// Steps register the point their AVAILABLE glint floats at: the object the player must find (box 1 of the
// barn, the resting orb, the table, a lamp bulb). Pass the glint point itself (object top + about 20, like
// the part glints). Call it any time: from the init before the step is available, or from the run func once
// the object exists; the glint appears as soon as the step is available AND a focus is known. A second
// call moves it; origin undefined clears focus and glint.
df_step_focus( key, origin )
{
    if ( !isdefined( level.df_step_focus ) )
        level.df_step_focus = [];

    level.df_step_focus[key] = origin;
    df_step_glint_stop( key );

    if ( isdefined( origin ) )
        df_step_glint_start( key );
}

// Glint on the focus of a step that is available, untouched and unfinished (one ent per step).
df_step_glint_start( key )
{
    if ( !isdefined( level.df_step_glint ) )
        level.df_step_glint = [];

    if ( isdefined( level.df_step_glint[key] ) || !isdefined( level.df_step_focus[key] ) )
        return;

    if ( !isdefined( level.df_step_avail_ms[key] ) || df_is_done( key ) || is_true( level.df_step_touched[key] ) )
        return;

    level.df_step_glint[key] = df_fx_loop( "fx_zmb_tranzit_light_glow", level.df_step_focus[key] );
    df_debug_print( "DF: available glint on " + key );
}

// Removes a step's AVAILABLE glint (touch, complete, skip, focus change). Safe when there is none.
df_step_glint_stop( key )
{
    if ( !isdefined( level.df_step_glint ) || !isdefined( level.df_step_glint[key] ) )
        return;

    df_fx_stop( level.df_step_glint[key] );
    level.df_step_glint[key] = undefined;
}

// A skipped step (!df goto) loses its glint too; df_complete covers the normal end.
df_step_glint_skip_watch( key )
{
    level endon( "end_game" );
    level endon( "df_" + key + "_done" );
    level waittill( "df_skip_" + key );
    df_step_glint_stop( key );
}

// " | round N | 4m12s" for the console line: time since the step became available, "" for steps that
// never went through the runner (goto fabrication).
df_step_elapsed_text( key )
{
    if ( !isdefined( level.df_step_avail_ms[key] ) )
        return "";

    seconds = int( ( gettime() - level.df_step_avail_ms[key] ) / 1000 );
    minutes = int( seconds / 60 );
    seconds = seconds - minutes * 60;
    return " | round " + level.round_number + " | " + minutes + "m" + seconds + "s";
}

// A player interacted with the step: no stall hint for it any more (the watcher exits at its next tick)
// and its AVAILABLE glint goes.
df_touch( key )
{
    level.df_step_touched[key] = 1;
    df_step_glint_stop( key );
}

// Locks the side (Step 4 socket: power ON = rich, OFF = maxis; also !df side / !df goto). The extra
// "df_step_done" wakes the parked r1 / m1 runners, whose prerequisites depend on the side.
df_set_side( side )
{
    if ( isdefined( level.df_side ) && level.df_side == side )
        return;

    if ( isdefined( level.df_side ) )
        df_debug_print( "DF: side changed from " + level.df_side + " to " + side + " (debug; running steps of the other act are not stopped)" );

    level.df_side = side;
    df_debug_print( "DF: side locked " + side );
    level notify( "df_side_locked", side );
    level notify( "df_step_done", "side" );
}

// Per-step intro (owner 2026-09-08): the step's <P>_START key, df_intro_delay_s after it became available
// so it queues behind the previous step's DONE line (the df_say pump serialises anyway). Not a stall
// hint: it plays whatever level.df_hints says (it is the story beat that used to live in the DONE
// lines). Silent when the step is already done (auto-complete, goto) or has no START key.
df_step_intro( key )
{
    level endon( "end_game" );
    level endon( "df_" + key + "_done" );
    level endon( "df_skip_" + key );

    wait( level.df_intro_delay_s );

    if ( df_is_done( key ) || is_true( level.df_goto_busy ) )
        return;

    intro = df_step_dlg_key( key, "START" );

    if ( !isdefined( intro ) )
    {
        df_debug_print( "DF: step " + key + " has no START dialogue key" );
        return;
    }

    df_debug_print( "DF: intro " + intro + " (" + key + " available)" );
    df_say( intro );
}

// Stall hint ladder for one step (owner 2026-09-08): <P>_HINT_1 df_hint_first_s after the step became
// available (cryptic), <P>_HINT_2 at df_hint_second_s (almost explicit), then HINT_2 every
// df_hint_repeat_s, until a player touches the step (df_touch), the step completes or is skipped.
// level.df_text_hints == 0 (`!df texthints off`, df_systems df_text_hints_on) mutes a rung but the clock
// keeps running so hints resume when re-enabled; the puzzle prompt switch (level.df_hints, off by default)
// has no say here any more. Nothing is said once the finale is reachable (df_step_finale_reached). A
// missing rung falls back to the other one; a step with neither rung is reported once and gets no stall
// hints. A rung already spoken by an event (df_hint_now) is skipped once.
df_step_stall_watcher( key )
{
    level endon( "end_game" );
    level endon( "df_" + key + "_done" );
    level endon( "df_skip_" + key );

    if ( key == "finale" || !isdefined( level.df_step_dlg[key] ) )
        return;

    df_dialogue_init();

    if ( !isdefined( df_step_hint_key( key, 1 ) ) )
    {
        df_debug_print( "DF: step " + key + " has no HINT_1 / HINT_2 dialogue key, no stall hints for this step" );
        return;
    }

    rung = 1;
    delay = level.df_hint_first_s;
    skipped = 0; // highest rung this clock already skipped because an event hint said it

    while ( true )
    {
        wait( delay );

        if ( is_true( level.df_step_touched[key] ) )
            return;

        if ( df_step_finale_reached() )
            return;

        hint = df_step_hint_key( key, rung );
        due = rung;

        if ( rung == 1 )
        {
            delay = level.df_hint_second_s - level.df_hint_first_s;
            rung = 2;
        }
        else
            delay = level.df_hint_repeat_s;

        if ( delay < 1 )
            delay = 1;

        if ( due <= df_step_hint_said( key ) && due > skipped )
        {
            skipped = due;
            continue;
        }

        if ( !df_text_hints_on() )
            continue;

        df_debug_print( "DF: stall hint " + hint + " (" + key + " untouched)" );
        df_say( hint );
    }
}

// Event hint (audit 2026-09-08 section 4): a step file fires rung 1 or 2 of a step's ladder NOW, when a
// player is visibly doing the wrong thing (first denizen latch in M1, "signal lost" in S5, orb taken with
// no Jet Gun in S6), instead of waiting for the clock. Same key choice as the clock (df_step_hint_key:
// side variant, other rung as fallback). Silent while `!df texthints off` (level.df_text_hints, not the
// puzzle prompt switch), once the finale is reachable, for a done or not yet available step, and for a
// repeat of the same rung inside df_hint_repeat_s (callers may fire it on every event). Marks the rung as
// spoken so df_step_stall_watcher skips it once. Returns 1 when a line was queued.
df_hint_now( key, rung )
{
    if ( !isdefined( rung ) || rung < 2 )
        rung = 1;
    else
        rung = 2;

    if ( df_is_done( key ) || !isdefined( level.df_step_avail_ms[key] ) || df_step_finale_reached() )
        return 0;

    if ( !df_text_hints_on() )
        return 0;

    now = gettime();
    said = df_step_hint_said( key );

    if ( said >= rung && isdefined( level.df_step_hint_ms[key] ) && now - level.df_step_hint_ms[key] < level.df_hint_repeat_s * 1000 )
        return 0;

    hint = df_step_hint_key( key, rung );

    if ( !isdefined( hint ) )
        return 0;

    if ( rung > said )
        level.df_step_hint_said[key] = rung;

    level.df_step_hint_ms[key] = now;
    df_debug_print( "DF: event hint " + hint + " (" + key + ")" );
    df_say( hint );
    return 1;
}

// Highest ladder rung an event hint (df_hint_now) has spoken for a step, 0 = none.
df_step_hint_said( key )
{
    if ( isdefined( level.df_step_hint_said[key] ) )
        return level.df_step_hint_said[key];

    return 0;
}

// Key of one ladder rung (1 or 2) for a step, side variant preferred; the other rung when this one has
// no line; undefined when the step has no ladder at all.
df_step_hint_key( key, rung )
{
    kind = "HINT_1";
    other = "HINT_2";

    if ( rung == 2 )
    {
        kind = "HINT_2";
        other = "HINT_1";
    }

    hint = df_step_dlg_key( key, kind );

    if ( !isdefined( hint ) )
        hint = df_step_dlg_key( key, other );

    return hint;
}

// "<P>_<kind>_<SIDE>" when the side is locked and df_dialogue.gsc has that key, else "<P>_<kind>" when it
// exists, else undefined. P = level.df_step_dlg[key]; SIDE = RICH / MAXIS from level.df_side. Other files
// may use it for their own keys, e.g. df_step_dlg_key( "step5", "FAIL" ).
df_step_dlg_key( key, kind )
{
    if ( !isdefined( level.df_step_dlg[key] ) )
        return undefined;

    df_dialogue_init();
    base = level.df_step_dlg[key] + "_" + kind;
    suffix = df_step_side_suffix();

    if ( isdefined( suffix ) && isdefined( level.df_lines[base + "_" + suffix] ) )
        return base + "_" + suffix;

    if ( isdefined( level.df_lines[base] ) )
        return base;

    return undefined;
}

// "RICH" / "MAXIS" for the locked side, undefined before the fork (no toupper in T6, hence the table).
df_step_side_suffix()
{
    if ( !isdefined( level.df_side ) )
        return undefined;

    if ( level.df_side == "rich" )
        return "RICH";

    if ( level.df_side == "maxis" )
        return "MAXIS";

    return undefined;
}

// True once the finale is available or running (level.df_fin_started is set by df_finale): no stall
// hint may play from then on.
df_step_finale_reached()
{
    if ( is_true( level.df_fin_started ) )
        return true;

    return isdefined( level.df_step_avail_round["finale"] );
}
