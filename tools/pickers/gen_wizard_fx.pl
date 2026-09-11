use strict;
use warnings;

# gen_wizard_fx.pl > fx.html : one effect role of the quest at a time (where it plays, what is used today), the curated
# server-fx list under it with its !df fx number, type (loop / one-shot, from the name), asset path and vanilla usage.
# Effects cannot be rendered outside the game: the page pairs with `!df fx <n>` in game. Pick, Next, copy at the end.
use FindBin;
my $repo = "$FindBin::Bin/../..";

# curated list in df_audition.gsc order (= the n of !df fx <n>)
my @fx;
open my $a, '<', "$repo/df_audition.gsc" or die;
my $in = 0;
while (<$a>) {
    $in = 1 if /^df_aud_fx_list\(\)/;
    $in = 0 if $in && /^df_aud_snd_list\(\)/;
    push @fx, $1 if $in && /l\[l\.size\] = "([a-z0-9_]+)";/;
}
close $a;

# alias -> asset path, vanilla registration (gsc rows)
my ( %path, %use );
open my $f, '<', "$repo/tools/assets/fx_aliases_zm_transit.txt" or die;
while (<$f>) {
    chomp;
    next if /^#/;
    my ( $al, $p, $where ) = split /\t/;
    next unless $al;
    $path{$al} //= $p;
    if ( $where && $where =~ /\.gsc:/ && !$use{$al} ) {
        $where =~ s{^Core/maps/mp/zombies/}{};
        $where =~ s{^Core/maps/mp/}{};
        $where =~ s{^Maps/Tranzit/maps/mp/}{};
        $use{$al} = $where;
    }
}
close $f;

sub kind {
    my ($n) = @_;
    return 'one-shot' if $n =~ /_os$|burst|impact|explo|grabbed|lightning|flash|shock|poof|spawn_[abc]|death|dust|descend|ascend|dest\b|bust|switch_sparks|def_explosion|fw_burst|fw_impact|fw_pre|cherry_explode|thundergun_knockdown|upgrade_aquired|packapunch_fx|steal/;
    return 'loop';
}

# roles: id, title, where it plays, today (primary fx), what it needs
my @roles = (
    [ 'pipe_idle', 'Pipe locator glow (Step 1)', 'A steady light on top of each of the four pipes so they are found in the fog. Whole Step 1.', 'fx_zmb_tranzit_spark_blue_lg_os', 'one-shot, fired once per blink cycle in the dark gap' ],
    [ 'pipe_flash', 'Pipe number blink (Step 1)', 'The pipe blinks its number: one burst per count, 0.6 s apart, then 2.5 s dark. Must read as a clear ON from 20 m.', 'fx_zmb_tranzit_light_bulb_xsm', 'a glow shown 0.7 s per flash' ],
    [ 'pipe_on', 'Pipe lit (Step 1)', 'A pipe pressed in the right order stops blinking and keeps this light until the step ends.', 'fx_zmb_tranzit_light_bulb_xsm', 'loop, steady' ],
    [ 'pipe_tap', 'Pipe kicked (Step 1)', 'The short spark when a pipe is pressed, right or wrong. 0.6 s.', 'switch_sparks', 'one-shot' ],
    [ 'signal_flash', 'The far signal light (Step 1)', 'Outside the fence, 30 above DF_SIGNAL: one flash per count, groups 1.5 s apart. Must be seen from the Depot.', 'fx_zmb_tranzit_light_bulb_xsm', 'a glow shown 0.7 s per flash' ],
    [ 'coil_arrival', 'The coil arrives (Step 1 done)', 'Lightning strike where the coil lands (DF_COIL_DROP): ground descend + bolt 40 up, then the coil and its glint.', 'grenade_samantha_steal', 'one-shot' ],
    [ 'glint', 'The "take me" glint (everywhere)', 'On every part, the coil, the card, the skull, the orb, and on the object of the step that just opened. The vanilla key glint.', 'fx_zmb_tranzit_light_glow', 'loop, small' ],
    [ 'power_pulse', 'Power pulse (bus dashboard, relay)', 'After Step 1 on the bus dashboard 5 s; on the relay when it locks at a stop; when the orb is placed.', 'fx_zmb_tranzit_spark_int_runner', 'loop, short' ],
    [ 'build_dust', 'Build dust (relay built)', 'The vanilla assemble dust while the builder hands work, and at the relay when it stands.', 'building_dust', 'one-shot' ],
    [ 'relay_glow', 'Relay powered glow (roof, table)', 'A small glow on the relay while power is on (roof relay, plugged relay on the table).', 'fx_zmb_tranzit_light_glow_xsm', 'loop, small' ],
    [ 'table_glow_rich', 'Table glow, Richtofen (Step 4, lamps, card)', 'Blue side light: the table as the carrier approaches with power ON, the Richtofen lamp bulbs, the card on its slot.', 'fx_zmb_tranzit_light_safety_ric', 'loop' ],
    [ 'table_glow_maxis', 'Table glow, Maxis (Step 4, lamps, skull, portal)', 'Orange side light: the table with power OFF, the Maxis lamp bulbs, the skull on its slot, the M1 portal lights, charged nodes.', 'fx_zmb_tranzit_light_safety_max', 'loop' ],
    [ 'flash_rich', 'Success flash, Richtofen side', 'The one-shot at every good moment on the blue side: sub-goal done, coil dropped, relay hit, card accepted, soul arriving at a lamp.', 'fx_zmb_tranzit_spark_blue_lg_os', 'one-shot' ],
    [ 'flash_maxis', 'Success flash, Maxis side', 'The 0.8 s fire burst at every good moment on the fire side (sub-goal done, soul arriving at a brazier).', 'fx_zmb_tranzit_fire_lrg', 'short burst (loop fx cut at 0.8 s)' ],
    [ 'burst_rich', 'Progress burst, Richtofen', 'The 0.6 s electric burst of a progress tick and of the lamps (blue side).', 'elec_md', 'short burst' ],
    [ 'burst_maxis', 'Progress burst, Maxis', 'The 0.6 s fire burst of a progress tick and of the lamps (fire side).', 'lava_burning', 'short burst' ],
    [ 'fail_maxis', 'Fail / loss, Maxis', 'Where progress was lost on the fire side: 0.8 s of rising ash (the blue side uses the success spark).', 'fx_zmb_ash_rising_md', 'short burst' ],
    [ 'trail_rich', 'Node-to-tower runner, Richtofen', 'The canon spark runner that flies from a finished node to the tower top (also the soul trails).', 'richtofen_sparks', 'loop on a moving point' ],
    [ 'trail_maxis', 'Node-to-tower runner, Maxis', 'Same runner on the fire side.', 'maxis_sparks', 'loop on a moving point' ],
    [ 'fuse_glow', 'Simon box glow (R1)', 'Faint glow on the four barn boxes from boot; the bigger glow when a box is charged / holds the storm.', 'fx_zmb_tranzit_light_glow_xsm', 'loop (charged: fx_zmb_tranzit_light_glow)' ],
    [ 'fuse_spark', 'Simon box lights up (R1)', 'A box shows itself in the Simon sequence: electric burst on its LED.', 'fx_zmb_tranzit_spark_blue_lg_os', 'one-shot' ],
    [ 'storm', 'Storm over the tower (R1, S6, S7)', 'The Avogadro storm cloud at the tower top while he is summoned, while the orb is coming, during the Step 7 wave.', 'fx_zmb_avog_storm', 'loop, huge, at the tower top' ],
    [ 'column_rise', 'Power rising column (R1, S7, finale, beams)', 'The rising power column at the table when Avogadro is summoned, when Step 7 starts, in the finale, and the marker at a beam target.', 'fx_zmb_tranzit_power_rising', 'loop' ],
    [ 'spool_lights', 'Spool lights on the mast (R2)', 'One small glow per placed spool climbing the relay mast on the table.', 'fx_zmb_tranzit_light_glow_xsm', 'loop, small' ],
    [ 'portal_hole', 'The M1 hole (Maxis)', 'The hole in front of the table to Nacht.', 'screecher_hole', 'loop, flat on the ground' ],
    [ 'nacht_fog', 'Cold fog in Nacht (M1)', 'The fog inside the bunker during the latch.', 'fx_zmb_fog_closet', 'loop, large' ],
    [ 'denizen_dig', 'Denizen digs out (M1)', 'Dirt billow where a denizen rises at the tower; screecher_death when one dies in the latch.', 'screecher_spawn_b', 'one-shot' ],
    [ 'brazier_ember', 'Brazier ember (M2, unlit)', 'The glow between the rocks of an unlit brazier from boot.', 'fx_zmb_lava_crevice_glow_50', 'loop, small' ],
    [ 'brazier_fire_1', 'Brazier fire, first stage (M2)', 'The fire of a lit brazier; also the Maxis orb aura first stage.', 'fx_zmb_tranzit_fire_med', 'loop' ],
    [ 'brazier_fire_2', 'Brazier fire, full (M2)', 'The full brazier: large fire plus rising ash on top.', 'fx_zmb_tranzit_fire_lrg', 'loop' ],
    [ 'smoke_column', 'Smoke column at the tower (Maxis)', 'The 20 s column when M2 completes, the Maxis Step 6 build-up, the Step 7 wave, the finale.', 'fx_zmb_tranzit_smk_column_lrg', 'loop, huge, at the tower top' ],
    [ 'beam', 'Beam to the tower (R2, S5, S6)', 'The light shaft from the table towards a hungry / charged lamp or node. Dvar df_beam_fx.', 'fx_zmb_tranzit_god_ray_interior_long', 'loop, long, oriented' ],
    [ 'orb_aura_rich', 'Orb aura, Richtofen (S6, S7)', 'The aura on the charge orb and on its carrier as it fills, blue side (stages end with the fluorescent glow).', 'avogadro_health_full', 'loop' ],
    [ 'orb_aura_maxis', 'Orb aura, Maxis (S6, S7)', 'The aura on the orb, fire side: fire_med, lava glow, fire_lrg, ash by stage.', 'powerup_on_caution', 'loop' ],
    [ 'strike', 'Lightning strike (S6 arrival, S7 strikes, finale)', 'The bolt on the orb when it arrives and at every charge strike; the finale burst at the tower top.', 'sq_common_lightning', 'one-shot' ],
);

my $list_rows = '';
for my $i ( 0 .. $#fx ) {
    my $n = $fx[$i];
    my $k = kind($n);
    my $p = $path{$n} || '';
    my $u = $use{$n} ? "vanilla: $use{$n}" : '';
    $list_rows .= qq~<li class="row" data-name="$n" data-kind="$k"><span class="num">$i</span><label class="pickrow"><input type="radio" name="pick-ROLE" value="$n"><code>$n</code><span class="chip chip-$k">$k</span><span class="path">$p</span><span class="van">$u</span></label><button class="cmd" type="button" data-cmd="!df fx $i" title="Copy the in-game command">!df fx $i</button></li>\n~;
}

my $steps = '';
my $nroles = scalar @roles;
for my $i ( 0 .. $#roles ) {
    my ( $id, $title, $where, $cur, $needs ) = @{ $roles[$i] };
    my $k = $i + 1;
    my $rows = $list_rows;
    $rows =~ s/pick-ROLE/pick-$id/g;
    my $curidx = -1;
    for my $j ( 0 .. $#fx ) { if ( $fx[$j] eq $cur ) { $curidx = $j; last } }
    my $curcmd = $curidx >= 0 ? "!df fx $curidx" : "!df fx $cur";
    $steps .= <<"STEP";
<section class="step" data-id="$id" data-cur="$cur" hidden>
  <div class="card">
    <div class="eyebrow">Effect $k of $nroles</div>
    <h2>$title</h2>
    <p class="when">$where</p>
    <p class="fits"><b>What fits:</b> $needs</p>
    <div class="cur"><span>Today:</span><code>$cur</code><button class="cmd" type="button" data-cmd="$curcmd">$curcmd</button><button class="keep" type="button">Keep it</button></div>
  </div>
  <div class="filters"><input type="search" placeholder="Search an effect (name or path: glow, spark, fire, ray...)" aria-label="Search"><div class="chips"><button type="button" data-kind="" class="on">all</button><button type="button" data-kind="one-shot">one-shot</button><button type="button" data-kind="loop">loop</button></div></div>
  <ul class="rows">$rows</ul>
</section>
STEP
}

my $count = scalar @fx;
print <<"HTML";
<title>Dead Frequency Effect Picker</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;700&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{--bg:#efece6;--panel:#ffffff;--ink:#1b1e23;--muted:#5d6673;--line:#d9d4ca;--accent:#c96f14;--elec:#1f78b8;--good:#3f8f46;--bar:#e6dfd2;--sel:#fff3e4}
\@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419}}
:root[data-theme="dark"]{--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419}
body{background:var(--bg);color:var(--ink);font:15px/1.5 "IBM Plex Sans",system-ui,sans-serif;margin:0}
.wrap{max-width:1040px;margin:0 auto;padding:22px 20px 90px}
.top{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:10px}
.top h1{font:700 34px/1 "Barlow Condensed","Arial Narrow",sans-serif;margin:0;flex:1}
.progress{font:13px "IBM Plex Mono",monospace;color:var(--muted)}
.track{height:4px;background:var(--bar);margin:0 0 16px}.track i{display:block;height:100%;background:var(--accent);transition:width .2s}
.card{background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--accent);padding:16px 18px;margin-bottom:12px}
.eyebrow{font:600 11px "IBM Plex Sans",sans-serif;letter-spacing:.1em;text-transform:uppercase;color:var(--accent)}
.card h2{font:700 30px/1.05 "Barlow Condensed",sans-serif;margin:4px 0 8px;text-wrap:balance}
.card p{margin:0 0 6px;max-width:72ch}.fits{color:var(--muted);font-size:14px}
.cur{display:flex;align-items:center;gap:10px;margin-top:10px;padding-top:10px;border-top:1px solid var(--line);flex-wrap:wrap}
.cur span{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
code{font:500 14px "IBM Plex Mono",monospace}
button{font:600 13px "IBM Plex Sans",sans-serif;cursor:pointer}
.nav button,.copy{background:var(--accent);color:#fff;border:0;padding:9px 16px;font-size:14px}
.nav button.ghost,.keep{background:transparent;color:var(--ink);border:1px solid var(--line);padding:7px 12px}
.nav button:disabled{opacity:.4;cursor:default}
.cmd{background:var(--bg);color:var(--elec);border:1px solid var(--line);padding:4px 8px;font:500 12px "IBM Plex Mono",monospace;white-space:nowrap}
button:focus-visible,input:focus-visible{outline:2px solid var(--elec);outline-offset:2px}
.filters{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:0 0 8px}
.filters input{flex:1 1 240px;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px 10px;font:14px "IBM Plex Sans",sans-serif}
.chips{display:flex;gap:6px}.chips button{background:transparent;color:var(--muted);border:1px solid var(--line);padding:5px 10px;font:12px "IBM Plex Mono",monospace}
.chips button.on{color:var(--accent);border-color:var(--accent)}
.rows{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:4px}
.row{display:flex;align-items:center;gap:10px;background:var(--panel);border:1px solid var(--line);padding:6px 10px}
.row.picked{background:var(--sel);border-color:var(--accent)}
.num{font:500 12px "IBM Plex Mono",monospace;color:var(--muted);min-width:26px;text-align:right}
.pickrow{display:flex;align-items:center;gap:10px;flex:1;cursor:pointer;min-width:0;flex-wrap:wrap}
.chip{font:11px "IBM Plex Mono",monospace;border:1px solid var(--line);padding:0 5px;border-radius:3px;color:var(--muted)}
.chip-one-shot{color:var(--accent);border-color:var(--accent)}.chip-loop{color:var(--elec);border-color:var(--elec)}
.path{font:11px "IBM Plex Mono",monospace;color:var(--muted)}
.van{font-size:11px;color:var(--muted);margin-left:auto}
.summary .list{font:13px/1.7 "IBM Plex Mono",monospace;white-space:pre-wrap;background:var(--panel);border:1px solid var(--line);padding:12px}
.summary textarea{width:100%;box-sizing:border-box;min-height:80px;margin:10px 0;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px;font:14px "IBM Plex Sans",sans-serif}
.foot{position:fixed;left:0;right:0;bottom:0;background:var(--panel);border-top:1px solid var(--line);padding:10px 20px;display:flex;justify-content:center;gap:10px;z-index:3}
.toast{position:fixed;bottom:64px;left:50%;transform:translateX(-50%);background:var(--ink);color:var(--bg);padding:6px 12px;font:13px "IBM Plex Mono",monospace;opacity:0;transition:opacity .2s;pointer-events:none}
.toast.on{opacity:1}
</style>
<div class="wrap">
<div class="top"><h1>Dead Frequency Effect Picker</h1><span class="progress" id="prog"></span></div>
<div class="track"><i id="bar" style="width:0%"></i></div>
<p style="color:var(--muted);margin:0 0 14px;max-width:80ch">Effects cannot be shown outside the game, so this page works with the game open: one effect role at a time, read where it plays, then look at candidates in game with <code>!df fx &lt;number&gt;</code> (the number is on each row, the button copies the command; the effect plays 8 s where you aim). Tick the one you want, Next. <b>one-shot</b> = plays once (flashes, strikes, bursts); <b>loop</b> = stays on (glows, fires, beams, auras). The type is guessed from the name. $count server effects.</p>
$steps
<section class="step summary" data-id="summary" hidden>
  <div class="card"><div class="eyebrow">Done</div><h2>Your picks</h2><p>Copy this and paste it to me. "keep" means the current effect stays.</p></div>
  <div class="list" id="sumlist"></div>
  <textarea id="notes" placeholder="Notes (too big, too small, wrong colour, wrong height...)"></textarea>
  <button class="copy" type="button" id="copy">Copy picks</button>
</section>
</div>
<div class="foot nav"><button type="button" class="ghost" id="prev">Previous</button><button type="button" class="ghost" id="skip">Skip</button><button type="button" id="next">Next</button></div>
<div class="toast" id="toast">copied</div>
<script>
(function(){
  var steps=Array.prototype.slice.call(document.querySelectorAll('.step')),cur=0,picks={},keep={},notes=document.getElementById('notes');
  try{var st=JSON.parse(localStorage.getItem('df_wiz_fx')||'{}');picks=st.picks||{};keep=st.keep||{};cur=st.cur||0;notes.value=st.notes||'';}catch(e){}
  function save(){try{localStorage.setItem('df_wiz_fx',JSON.stringify({picks:picks,keep:keep,cur:cur,notes:notes.value}))}catch(e){}}
  function toast(t){var el=document.getElementById('toast');el.textContent=t;el.classList.add('on');setTimeout(function(){el.classList.remove('on')},1200)}
  function copyText(t){if(navigator.clipboard){navigator.clipboard.writeText(t).then(function(){toast('copied: '+t)},function(){prompt('Copy this:',t)})}else{prompt('Copy this:',t)}}
  function summary(){var out=[];steps.forEach(function(s){var id=s.dataset.id;if(id==='summary')return;var t=s.querySelector('h2').textContent;var v=picks[id]?picks[id]:(keep[id]?'keep ('+s.dataset.cur+')':'-- not decided --');out.push(t+' = '+v)});return out.join('\\n')}
  function show(i){cur=Math.max(0,Math.min(steps.length-1,i));steps.forEach(function(s,k){s.hidden=k!==cur});
    document.getElementById('prog').textContent=cur<steps.length-1?('effect '+(cur+1)+' / '+(steps.length-1)):'summary';
    document.getElementById('bar').style.width=Math.round(100*cur/(steps.length-1))+'%';
    document.getElementById('prev').disabled=cur===0;document.getElementById('skip').disabled=cur===steps.length-1;
    document.getElementById('next').textContent=cur===steps.length-2?'Finish':'Next';document.getElementById('next').disabled=cur===steps.length-1;
    if(cur===steps.length-1)document.getElementById('sumlist').textContent=summary();
    window.scrollTo(0,0);save()}
  steps.forEach(function(s){var id=s.dataset.id;
    s.querySelectorAll('input[type=radio]').forEach(function(r){
      if(picks[id]===r.value){r.checked=true;r.closest('.row').classList.add('picked')}
      r.addEventListener('change',function(){picks[id]=r.value;delete keep[id];s.querySelectorAll('.row').forEach(function(x){x.classList.remove('picked')});r.closest('.row').classList.add('picked');save()});
    });
    var k=s.querySelector('.keep');if(k)k.addEventListener('click',function(){keep[id]=1;delete picks[id];s.querySelectorAll('.row').forEach(function(x){x.classList.remove('picked')});s.querySelectorAll('input[type=radio]').forEach(function(r){r.checked=false});save();show(cur+1)});
    var search=s.querySelector('input[type=search]'),chips=s.querySelectorAll('.chips button'),kind='';
    function filter(){var q=(search?search.value:'').toLowerCase();s.querySelectorAll('.row').forEach(function(r){var hay=r.dataset.name+' '+(r.querySelector('.path')||{}).textContent;var ok=(!q||hay.toLowerCase().indexOf(q)>=0)&&(!kind||r.dataset.kind===kind);r.hidden=!ok})}
    if(search)search.addEventListener('input',filter);
    chips.forEach(function(c){c.addEventListener('click',function(){kind=c.dataset.kind;chips.forEach(function(x){x.classList.toggle('on',x===c)});filter()})});
  });
  document.querySelectorAll('.cmd').forEach(function(b){b.addEventListener('click',function(){copyText(b.dataset.cmd)})});
  document.getElementById('prev').addEventListener('click',function(){show(cur-1)});
  document.getElementById('next').addEventListener('click',function(){show(cur+1)});
  document.getElementById('skip').addEventListener('click',function(){show(cur+1)});
  notes.addEventListener('input',save);
  document.getElementById('copy').addEventListener('click',function(){var t=summary();if(notes.value)t+='\\n\\nNotes: '+notes.value;copyText(t)});
  show(cur);
})();
</script>
HTML
