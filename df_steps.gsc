// Dead Frequency - step machine and player-count scaling (spec sections 5, 6 and 7).
// Included by df_main.gsc and by every act file (df_act*.gsc, df_finale.gsc) so acts can register steps.
//
// Contract used by the act files (do not rename): df_register_step, df_complete, df_touch, df_is_done,
// df_set_side, df_scaled, df_scaled_for, df_scaled_step, df_player_count, df_hint_now,
// df_step_focus, level.df_side, level.df_done, notifies "df_<key>_done", "df_step_done",
// "df_step_available", "df_skip_<key>", "df_side_locked".
// Dialogue (owner 2026-09-08): the runner speaks <P>_START when a step becomes available and the stall
// ladder <P>_HINT_1 / <P>_HINT_2 / <P>_HINT_3 (level.df_step_dlg, df_step_dlg_key picks the _RICH / _MAXIS
// variant, and the <P>_<PHASE>_ keys while a step file has set a sub-goal with df_step_phase);
// a step file may fire a rung early on an event with df_hint_now (audit 2026-09-08 section 4). The ladder
// and the event hints obey level.df_text_hints (df_systems df_text_hints_on, default on), NOT the puzzle
// prompt switch level.df_hints (dialogue audit v2 2026-09-09 section 1.0: the old shared gate muted the
// whole ladder in a normal game).
// Cues (art audit 2026-09-09 #1 / #2, owner picks 2026-09-11): STEP AVAILABLE = zmb_screecher_portal_arrive
// to all + a fx_zmb_tranzit_light_glow on the step's focus (df_step_focus) until the first df_touch;
// STEP DONE = evt_bridge_collapse_start (the bridge groan) to all (df_complete).
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
// and added sweep_time_rich (removed by Task 6, owner 2026-09-25: the Richtofen side no longer runs
// Frequency Sweep, see df_act3_blackout.gsc), s7_period, s7_cap_rich, s7_cap_maxis (Step 7 scaled backwards:
// solo was the hardest lobby).
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
    df_scale_row( "lamp_souls", 10, 12, 14, 16 ); // design audit 2026-09-25 1.1 (was 12/15/18/18: R2 weighed twice M2) // audit v2 #6 (was 12/15/18/20: 4 nodes x 20 = 80 souls at 4 players): R2 per lamp, also Step 5 re-feed lamps
    df_scale_row( "capture_time", 240, 300, 300, 300 ); // audit (was a fixed 180 s): R1 Avogadro capture window in seconds
    df_scale_row( "cold_room_time", 60, 75, 90, 100 ); // M1 seconds
    df_scale_row( "cold_room_kills", 6, 9, 12, 15 ); // M1 denizens
    df_scale_row( "brazier_burns", 4, 5, 6, 7 ); // audit (was 3/4/5/6): M2 kills per lit grave (burning or not since 2026-09-23)
    df_scale_row( "nodes", 3, 3, 3, 3 ); // owner 2026-09-28: always three lamps (R2 batteries, Lights Out), whatever the player count
    df_scale_row( "hold_time", 75, 90, 105, 120 ); // audit v2 section 6 (owner 2026-09-09 had 75/95/115/135): Step 7 wave seconds
    df_scale_row( "hold_kills", 40, 55, 70, 85 ); // Step 7 kills inside the zone (spec row; the hold file defends an orb instead)
    df_scale_row( "orb_hp", 3000, 4200, 5400, 6600 ); // audit v3 co-op: the sprinter cap grows faster than the old hp did // owner 2026-09-09: was 2000..3200 // audit (was a fixed 2000): Step 7 orb hit points (level.df_s7_cfg_orb_hp in df_act3_hold)
    df_scale_row( "s7_period", 1.3, 1.0, 0.8, 0.7 ); // audit v2 section 6 (was 1.0/0.9/0.8/0.7): Step 7 seconds between sprinter spawns (df_act3_hold level.df_s7_cfg_period)
    df_scale_row( "s7_cap_rich", 10, 14, 18, 22 ); // audit v2 section 6 (was 12/16/20/24): Step 7 sprinters alive at once, Richtofen side (Avogadro adds pressure)
    df_scale_row( "s7_cap_maxis", 14, 18, 22, 26 ); // audit v2 section 6 (was 16/20/24/28): same, Maxis side (the smoke column, full sprinter cap)
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
// leaving mid-step does not lower an active target.
// owner 2026-09-23 (audit B12): frozen in every case. A step that never went through the runner (goto
// fabrication, a read before availability) snapshots the live count on its first read and keeps it, so two
// reads for the same step never disagree. No stepkey = the live count (df_scaled).
df_scaled_step( key, stepkey )
{
    if ( !isdefined( stepkey ) )
        return df_scaled( key );

    if ( !isdefined( level.df_step_players ) )
        level.df_step_players = [];

    if ( !isdefined( level.df_step_players[stepkey] ) )
        level.df_step_players[stepkey] = df_player_count();

    return df_scaled_for( key, level.df_step_players[stepkey] );
}

// --------------------------------------------------------- step machine ----

// Step order (also the order `!df status` and `!df goto` walk), prerequisites, side locks, stall hint
// keys and the per-step bookkeeping arrays. "act2" is a pseudo key set by df_complete when r2 or m2
// finishes, so Step 5 has a single prerequisite whatever the side.
df_init_steps()
{
    // owner 2026-09-25 (design audit 2.1): the old "step2" (Salvage) is merged into step3 (build the relay on the
    // bus roof, then ride it); `!df goto step2` is an alias of step3 (df_main df_debug_goto).
    level.df_step_order = [];
    level.df_step_order[0] = "step1";
    level.df_step_order[1] = "step3";
    level.df_step_order[2] = "step4";
    level.df_step_order[3] = "r1";
    level.df_step_order[4] = "r2";
    level.df_step_order[5] = "m1";
    level.df_step_order[6] = "m2";
    level.df_step_order[7] = "step5";
    level.df_step_order[8] = "step6";
    level.df_step_order[9] = "step7";
    level.df_step_order[10] = "finale";

    level.df_step_prereq = [];
    level.df_step_prereq["step1"] = [];
    level.df_step_prereq["step3"] = df_step_keys1( "step1" );
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
    // (df_step_intro), then the stall ladder <P>_HINT_1 / _2 / _3 (df_step_stall_watcher). Act 3 and
    // the finale are shared, so their keys exist as <KEY>_RICH / <KEY>_MAXIS; df_step_dlg_key picks the
    // variant of the locked side and falls back to the plain key.
    level.df_step_dlg = [];
    level.df_step_dlg["step1"] = "S1";
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

    // Ladder timing (seconds from step availability or the last touch; owner 2026-09-08, reworked 2026-09-25 by
    // design audit 5.3 / 5.5): HINT_1 at 4 min untouched, HINT_2 at 10 min and again 6 min later (df_hint_second_max
    // plays at most, and only before HINT_3), HINT_3 (the explicit last resort) once at 20 min, then silence until
    // the next touch. The puzzle steps (df_hint_puzzle) wait longer, 6 min / 15 min, while they have no phase: the
    // players must search; a phase (df_step_phase) is a courier sub-goal and uses the normal timing. The intro
    // waits 2 s so it queues behind the DONE line.
    level.df_hint_first_s = 240;
    level.df_hint_second_s = 600;
    level.df_hint_repeat_s = 360;
    level.df_hint_second_max = 2;
    level.df_hint_third_s = 1200;
    level.df_hint_puzzle_first_s = 360;
    level.df_hint_puzzle_second_s = 900;
    level.df_hint_puzzle = [];
    level.df_hint_puzzle["step1"] = 1;
    level.df_hint_puzzle["r1"] = 1;
    level.df_hint_puzzle["m1"] = 1;
    level.df_hint_puzzle["step5"] = 1;
    level.df_intro_delay_s = 2;

    level.df_done = [];
    level.df_step_func = [];
    level.df_step_setup = [];
    level.df_step_avail_round = []; // round a step became available (`!df status`)
    level.df_step_avail_ms = []; // gettime() when it became available (console line of df_complete)
    level.df_step_players = []; // player count at that moment (df_scaled_step)
    level.df_step_touched = [];
    level.df_step_touch_ms = []; // owner 2026-09-23 (audit B11): gettime() of the last df_touch, restarts the stall clock
    level.df_step_hint_said = []; // highest ladder rung an event hint spoke (df_hint_now)
    level.df_step_hint_ms = []; // gettime() of that event hint
    level.df_step_focus = []; // key -> origin of the AVAILABLE glint (df_step_focus)
    level.df_step_glint = []; // key -> the glint fx ent while it shows (df_step_glint_start / _stop)
    level.df_step_phase = []; // key -> current sub-goal name for the dialogue keys (df_step_phase), undefined = none
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
// runners. The sting is the ONLY "step done" sound of the quest (art audit 2026-09-09 #1: the sting means
// "step done" and nothing else; steps play zmb_sq_navcard_success for their sub-goals instead), so the
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

    df_debug_print( "DF: step complete " + df_step_label( key ) + df_step_elapsed_text( key ) );
    level notify( "df_" + key + "_done" );
    level notify( "df_step_done", key );
}

// The one "step done" sting, heard by everyone: evt_bridge_collapse_start, the bridge groan (owner pick
// 2026-09-11; was zmb_powerup_grabbed, before that zmb_cha_ching_loud).
// playsoundtoplayer( alias, player ) as in Core/maps/mp/zombies/_zm.gsc:1843.
df_step_complete_cue()
{
    foreach ( player in getplayers() )
        player playsoundtoplayer( "evt_bridge_collapse_start", player ); // owner pick 2026-09-11: STEP DONE = the bridge groan
}

// STEP AVAILABLE cue (art audit 2026-09-09 #2): zmb_screecher_portal_arrive to every player (owner pick
// 2026-09-11, was zmb_spawn_powerup) right after "df_step_available", plus a fx_zmb_tranzit_light_glow
// (df_step_glint_start) on the step's focus point until the
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

// A player interacted with the step: its AVAILABLE glint goes and the stall clock restarts from now.
// owner 2026-09-23 (audit B11): a touch used to end the ladder for good, so a team that touched a step once
// and then got stuck never heard a hint again; df_step_stall_watcher now starts over at HINT_1,
// df_hint_first_s after the LAST touch.
df_touch( key )
{
    level.df_step_touched[key] = 1;
    level.df_step_touch_ms[key] = gettime();
    df_step_glint_stop( key );
}

// Locks the side (Step 4 socket: power ON = rich, OFF = maxis; also !df side / !df goto). The extra
// "df_step_done" wakes the parked r1 / m1 runners, whose prerequisites depend on the side.
// owner 2026-09-23 (audit B1): the lock is final. A second change removed both acts' world state (graves and
// boxes) and broke the game, so a different side once one is locked is refused (debug line, returns 0);
// callers read level.df_side afterwards. Returns 1 when level.df_side == side on return.
df_set_side( side )
{
    if ( isdefined( level.df_side ) && level.df_side == side )
        return 1;

    if ( isdefined( level.df_side ) )
    {
        df_debug_print( "DF: side change to " + side + " refused, " + level.df_side + " is locked for this game" );
        return 0;
    }

    level.df_side = side;
    df_debug_print( "DF: side locked " + side );
    level notify( "df_side_locked", side );
    level notify( "df_step_done", "side" );
    return 1;
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

    // owner 2026-09-23 (audit D19): the end of Act 2 queues many lines (about 45 s); Step 5's START waits for the
    // df_say pump to go idle (level.df_say_running / level.df_say_queue, df_systems df_say_pump). Capped at 90 s.
    if ( key == "step5" )
        df_step_wait_dialogue_idle( 90 );

    df_debug_print( "DF: intro " + intro + " (" + key + " available)" );
    df_say( intro );
}

// owner 2026-09-23 (audit D19): returns once the dialogue queue is empty and its pump idle, at most `cap` s.
df_step_wait_dialogue_idle( cap )
{
    waited = 0;

    while ( waited < cap )
    {
        busy = is_true( level.df_say_running );

        if ( !busy && isdefined( level.df_say_queue ) && level.df_say_queue.size > 0 )
            busy = 1;

        if ( !busy )
            return;

        wait 0.5;
        waited += 0.5;
    }
}

// Stall hint ladder for one step (owner 2026-09-08; reworked 2026-09-25, design audit 5.3 / 5.5). The clock runs
// from the step's availability or its LAST df_touch (a phase change counts as one, df_step_phase): HINT_1 at
// df_step_hint_first_s (it points), HINT_2 at df_step_hint_second_s (a sharper nudge, never a recipe) and again
// every df_hint_repeat_s, df_hint_second_max plays at most and only before df_hint_third_s, then HINT_3 (the
// explicit last resort) once at df_hint_third_s, then silence until the next touch. A touch starts the ladder
// over at HINT_1 (owner 2026-09-23, audit B11). level.df_text_hints == 0 (`!df texthints off`, df_systems
// df_text_hints_on) mutes a rung but the clock keeps running; the puzzle prompt switch (level.df_hints, off by
// default) has no say here. Nothing is said once the finale is reachable (df_step_finale_reached). A missing
// rung falls back (df_step_hint_key); a step with no rung at all is reported once and gets no stall hints. A
// rung 1 / 2 already spoken by an event (df_hint_now) is skipped once.
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

    skipped = 0; // highest rung this thread already skipped because an event hint said it
    clock = df_step_last_touch( key ); // owner 2026-09-23 (audit B11): the touch this clock runs from
    base = df_step_clock_base( key );
    first = 0; // HINT_1 spoken on this clock
    second = 0; // HINT_2 plays on this clock
    third = 0; // HINT_3 spoken on this clock

    while ( true )
    {
        rung = 0;
        due = 0;
        second_due = df_step_hint_second_s( key ) + second * level.df_hint_repeat_s;

        if ( !first )
        {
            rung = 1;
            due = df_step_hint_first_s( key );
        }
        else if ( second < level.df_hint_second_max && second_due < level.df_hint_third_s )
        {
            rung = 2;
            due = second_due;
        }
        else if ( !third )
        {
            rung = 3;
            due = level.df_hint_third_s;
        }

        delay = 5; // ladder spent: only watch for the next touch

        if ( rung > 0 )
            delay = ( base + due * 1000 - gettime() ) / 1000;

        if ( delay < 0.05 )
            delay = 0.05;

        wait( delay );

        if ( df_step_finale_reached() )
            return;

        // touched (or a new phase) during the wait = start over at HINT_1 from that touch
        last = df_step_last_touch( key );

        if ( last != clock )
        {
            clock = last;
            base = df_step_clock_base( key );
            first = 0;
            second = 0;
            third = 0;
            continue;
        }

        if ( rung == 0 )
            continue;

        if ( rung == 1 )
            first = 1;
        else if ( rung == 2 )
            second++;
        else
            third = 1;

        if ( rung < 3 && rung <= df_step_hint_said( key ) && rung > skipped )
        {
            skipped = rung;
            continue;
        }

        if ( !df_text_hints_on() )
            continue;

        hint = df_step_hint_key( key, rung );

        if ( !isdefined( hint ) )
            continue;

        df_debug_print( "DF: stall hint " + hint + " (" + key + " untouched, rung " + rung + ")" );
        df_say( hint );
    }
}

// gettime() the stall clock of a step runs from: its last touch, else its availability.
df_step_clock_base( key )
{
    last = df_step_last_touch( key );

    if ( last > 0 )
        return last;

    if ( isdefined( level.df_step_avail_ms ) && isdefined( level.df_step_avail_ms[key] ) )
        return level.df_step_avail_ms[key];

    return gettime();
}

// True for a puzzle step (level.df_hint_puzzle) that has no phase: its ladder waits longer (owner 2026-09-25).
df_step_hint_is_puzzle( key )
{
    if ( !isdefined( level.df_hint_puzzle ) || !isdefined( level.df_hint_puzzle[key] ) )
        return false;

    return !isdefined( df_step_phase_of( key ) );
}

// Seconds after the clock base when HINT_1 is due.
df_step_hint_first_s( key )
{
    if ( df_step_hint_is_puzzle( key ) )
        return level.df_hint_puzzle_first_s;

    return level.df_hint_first_s;
}

// Seconds after the clock base when the first HINT_2 is due.
df_step_hint_second_s( key )
{
    if ( df_step_hint_is_puzzle( key ) )
        return level.df_hint_puzzle_second_s;

    return level.df_hint_second_s;
}

// owner 2026-09-23 (audit B11): gettime() of the step's last df_touch, 0 = never touched.
df_step_last_touch( key )
{
    if ( isdefined( level.df_step_touch_ms ) && isdefined( level.df_step_touch_ms[key] ) )
        return level.df_step_touch_ms[key];

    return 0;
}

// Event hint (audit 2026-09-08 section 4): a step file fires rung 1 or 2 of a step's ladder NOW, when a
// player reaches the moment the rung is about (today: the relay carried near the table in S4, the first lit
// grave in M2), instead of waiting for the clock. Same key choice as the clock (df_step_hint_key: phase and
// side variant, other rung as fallback; HINT_3 is never an event rung). Silent while `!df texthints off` (level.df_text_hints, not the
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

// Key of one ladder rung (1, 2 or 3) for a step, side variant preferred. While the step has a phase
// (df_step_phase) the phase keys "<P>_<PHASE>_HINT_n" come first, every rung of them, before the plain ones, so a
// phase never borrows a plain rung about another sub-goal while it has lines of its own. Fallbacks: rung 1 ->
// HINT_2, rung 2 -> HINT_1, rung 3 -> HINT_2 then HINT_1. Undefined when the step has no ladder at all.
df_step_hint_key( key, rung )
{
    if ( !isdefined( level.df_step_dlg[key] ) )
        return undefined;

    df_dialogue_init();
    kinds = [];

    if ( rung == 3 )
    {
        kinds[0] = "HINT_3";
        kinds[1] = "HINT_2";
        kinds[2] = "HINT_1";
    }
    else if ( rung == 2 )
    {
        kinds[0] = "HINT_2";
        kinds[1] = "HINT_1";
    }
    else
    {
        kinds[0] = "HINT_1";
        kinds[1] = "HINT_2";
    }

    phase = df_step_phase_of( key );

    if ( isdefined( phase ) )
    {
        foreach ( kind in kinds )
        {
            hint = df_step_dlg_lookup( level.df_step_dlg[key] + "_" + phase + "_" + kind );

            if ( isdefined( hint ) )
                return hint;
        }
    }

    foreach ( kind in kinds )
    {
        hint = df_step_dlg_lookup( level.df_step_dlg[key] + "_" + kind );

        if ( isdefined( hint ) )
            return hint;
    }

    return undefined;
}

// owner 2026-09-25 (design audit 5.2): a step's current sub-goal, e.g. df_step_phase( "step3", "BUILD" ) while
// the relay is not built yet; undefined clears it. df_step_dlg_key / df_step_hint_key then prefer
// "<P>_<PHASE>_<kind>" keys. A CHANGE of phase on an available step restarts its stall clock like a df_touch (the
// new sub-goal gets its own ladder from HINT_1) without removing the AVAILABLE glint.
df_step_phase( key, phase )
{
    if ( !isdefined( level.df_step_phase ) )
        level.df_step_phase = [];

    old = level.df_step_phase[key];
    level.df_step_phase[key] = phase;
    changed = isdefined( old ) != isdefined( phase );

    if ( !changed && isdefined( phase ) && old != phase )
        changed = 1;

    if ( !changed || df_is_done( key ) )
        return;

    if ( isdefined( level.df_step_avail_ms ) && isdefined( level.df_step_avail_ms[key] ) && isdefined( level.df_step_touch_ms ) )
        level.df_step_touch_ms[key] = gettime();
}

// The step's current phase (df_step_phase), undefined for none.
df_step_phase_of( key )
{
    if ( !isdefined( level.df_step_phase ) )
        return undefined;

    return level.df_step_phase[key];
}

// "<P>_<kind>_<SIDE>" when the side is locked and df_dialogue.gsc has that key, else "<P>_<kind>" when it
// exists, else undefined. P = level.df_step_dlg[key]; SIDE = RICH / MAXIS from level.df_side. While the step
// has a phase (df_step_phase) "<P>_<PHASE>_<kind>[_<SIDE>]" is tried first (e.g. S3_BUILD_HINT_1). Other files
// may use it for their own keys, e.g. df_step_dlg_key( "step5", "FAIL" ).
df_step_dlg_key( key, kind )
{
    if ( !isdefined( level.df_step_dlg[key] ) )
        return undefined;

    df_dialogue_init();
    phase = df_step_phase_of( key );

    if ( isdefined( phase ) )
    {
        hint = df_step_dlg_lookup( level.df_step_dlg[key] + "_" + phase + "_" + kind );

        if ( isdefined( hint ) )
            return hint;
    }

    return df_step_dlg_lookup( level.df_step_dlg[key] + "_" + kind );
}

// base + "_" + SIDE when the side is locked and the sheet has it, else base when the sheet has it, else undefined.
df_step_dlg_lookup( base )
{
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

// owner 2026-09-25: the player-facing name of a step. step5 is one slot run by side (df_act3_sweep dispatches):
// "m3" on Maxis (Lights Out), "r3" on Richtofen (Blackout); every other key is its own name.
df_step_label( key )
{
    if ( isdefined( key ) && key == "step5" && isdefined( level.df_side ) )
    {
        if ( level.df_side == "maxis" )
            return "m3";

        return "r3";
    }

    return key;
}

