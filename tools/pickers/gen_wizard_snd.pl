use strict;
use warnings;
use MIME::Base64 qw(encode_base64);

# gen_wizard_snd.pl > wizard_snd.html : one action at a time, its examples in the quest, the whole sound list under it,
# pick one, Next. Reads board_keep.txt + small/ (shrunk files) + vanilla_use.txt.
my %vanilla;
open my $v, '<', 'vanilla_use.txt' or die;
while (<$v>) {
    chomp;
    next if /^#/;
    my ( $a, $where ) = split /\t/;
    next unless $a;
    $where =~ s{^Core/maps/mp/zombies/}{};
    $where =~ s{^Core/maps/mp/}{};
    $where =~ s{^Maps/Tranzit/maps/mp/}{};
    $vanilla{$a} //= $where;
}
close $v;

my @sounds;
open my $bk, '<', 'board_keep.txt' or die;
while (<$bk>) {
    chomp;
    my ( $a, $f, $sz, $d, $pan, $dmin, $dmax, $vol ) = split /\t/;
    my $ext   = $f =~ /\.flac$/ ? 'flac' : 'wav';
    my $mime  = $ext eq 'flac' ? 'audio/flac' : 'audio/wav';
    my $small = "small/$a.$ext";
    open my $fh, '<:raw', $small or die "$small: $!";
    local $/;
    my $bin = <$fh>;
    close $fh;
    push @sounds, { a => $a, d => $d, pan => $pan, dmin => $dmin, dmax => $dmax, vol => $vol, uri => "data:$mime;base64," . encode_base64( $bin, '' ) };
}
close $bk;
@sounds = sort { $a->{d} <=> $b->{d} } @sounds;

# the actions that need a sound: id, title, when, examples, current alias, what fits
my @roles = (
    [ 'avail', 'A step becomes available', 'Right after the previous step ends: the whole team hears that something new exists somewhere on the map. A glint marks the object.',
      'R2 opens: the three lamps start sparking. Step 6 opens: the orb lands at the diner. M2 opens: the first brazier lights.', 'zmb_screecher_portal_arrive', 'one short sound, under 1.5 s' ],
    [ 'tick', 'Progress tick', 'One unit of progress, heard by the players close to it. It can fire many times a minute, so it must be short and dry.',
      'A zombie killed under a hungry lamp (1 of 12). A part picked up (1 of 3). A pipe tapped right. A Simon box charged.', 'zmb_buildable_piece_add', 'a click or clink, under 0.8 s' ],
    [ 'subgoal', 'Sub-goal done', 'A node is finished. Everyone hears it; a spark runner flies from the node to the tower top.',
      'A lamp is full of souls. A brazier is full. Avogadro captured in the barn. The key card accepted at the table.', 'zmb_sq_navcard_success', 'a chime, 1 to 2 s' ],
    [ 'done', 'Step done', 'The only "step complete" sound of the whole quest. Everyone hears it, 2D. Followed by the patron lines.',
      'The four pipes solved. The relay built on the bus roof. The relay plugged on the table. All lamps anchored in Step 5.', 'evt_bridge_collapse_start', 'a satisfying sting, 1 to 3 s' ],
    [ 'deny', 'Wrong input', 'Only the player who pressed hears it.',
      'A wrong pipe in the melody. A wrong Simon box. Trying a lamp portal while carrying the orb or the relay.', 'zmb_sq_navcard_fail', 'a short buzz or bonk' ],
    [ 'fail', 'Fail, progress lost', 'Everyone hears it, 2D, then the patron explains.',
      'The Step 5 clock runs out. The relay is destroyed on the roof. Avogadro is defeated away from the tower. Nacht latch timeout.', 'zmb_bus_emp_shutdown', 'a heavy shutdown, 2 to 4 s' ],
    [ 'clock', 'Clock tick', 'No timer is drawn: this tick IS the clock. Every 5 s, every second under 30 s, doubled under 10 s.',
      'Step 5 countdown after the first anchor. Step 7 wave (75 s solo). The Nacht latch (60 s).', 'zmb_perks_packa_ticktock', 'a dry tick, under 0.5 s' ],
    [ 'handset', 'Phone: handset off the hook', 'Press F on the depot wall phone; this plays 0.8 s before the four tones.',
      'Step 1 only.', 'evt_perk_deny', 'a knock or click' ],
    [ 'tone1', 'Phone tone 1', 'The melody the pipes must repeat: four DIFFERENT short sounds, 2 s apart. Each pipe plays its own when tapped.',
      'The phone plays them in a random order; the tapped pipe repeats its tone at full volume.', 'zmb_switch_flip', 'under 1.4 s, unlike the other three' ],
    [ 'tone2', 'Phone tone 2', 'Second of the four melody sounds.', 'Same as tone 1.', 'zmb_turret_down', 'under 1.4 s, unlike the other three' ],
    [ 'tone3', 'Phone tone 3', 'Third of the four melody sounds.', 'Same as tone 1.', 'zmb_zombie_arc', 'under 1.4 s, unlike the other three' ],
    [ 'tone4', 'Phone tone 4', 'Fourth of the four melody sounds.', 'Same as tone 1.', 'zmb_power_rise_start', 'under 1.4 s, unlike the other three' ],
    [ 'ring', 'The phone rings', 'Heard by everyone in the Depot.',
      'Every 45 s until somebody listens to the phone. Once after a wrong pipe.', 'zmb_whoosh', 'a ring, a ding, a bell' ],
    [ 'drop', 'The coil drops', 'Step 1 solved: the wire coil lands where you stood to listen, with a flash.',
      'Step 1 only (the coil is the relay\'s third part).', 'zmb_switch_flip', 'a clink or a thud' ],
    [ 'ignite', 'Fire ignites', 'Maxis side. A whoosh of fire.',
      'A brazier lit with the ember. A brazier grows a stage. The Maxis charge strike on the orb in Step 7. The orb lands under the tower.', 'zmb_phdflop_explo', 'a whoosh, 1 to 2 s' ],
    [ 'puff', 'Hot air puff', 'Maxis side, small.',
      'Taking the ember from a lit brazier. A burning zombie approaching a lit brazier makes it puff.', 'zmb_fire_loop', 'a soft gust' ],
    [ 'soul_rich', 'A soul reaches a lamp (Richtofen)', 'R2: a kill near a sparking lamp sends a trail into the bulb. This plays when it arrives.',
      'R2, 12 times per lamp solo.', 'evt_electrical_surge', 'a small electric zap' ],
    [ 'soul_maxis', 'A soul reaches a brazier (Maxis)', 'M2: a burning kill near a lit brazier sends a trail into the fire. This plays when it arrives.',
      'M2, 5 times per brazier.', 'evt_player_swiped', 'a small fire puff' ],
    [ 'hum_wait', 'Hum: waiting, idle (loop)', 'A loop on an object. It repeats until the state changes.',
      'A tuned lamp waiting 15 s for its anchor. The charged orb hovering. A charged node.', 'zmb_avogadro_loop', 'a loop' ],
    [ 'hum_charge', 'Hum: tuning or drawing (loop)', 'A rising loop while the player holds or draws. No bar on screen: this is the feedback.',
      'Holding F 5 s on a lamp in Step 5. Drawing a node\'s charge into the orb in Step 6. The finale build-up.', 'zmb_power_rise_loop', 'a rising loop' ],
    [ 'tune_done', 'Tune or draw complete', 'The hum stops and this plays once.',
      'A lamp tuned (Step 5). A node drained (Step 6).', 'zmb_power_rise_stop', 'a short release' ],
    [ 'hum_fin_rich', 'Finale build-up hum (Richtofen)', 'Electric loop on the table for 6 s before the orb rises.',
      'Finale, Richtofen side.', 'zmb_avogadro_loop', 'an electric loop' ],
    [ 'hum_fin_maxis', 'Finale build-up hum (Maxis)', 'Fire loop on the table for 6 s before the orb rises.',
      'Finale, Maxis side.', 'zmb_fire_loop', 'a fire loop' ],
    [ 'dig', 'A denizen digs out', 'M1 latch: the ground opens where a denizen rises at the tower.',
      'M1, several times.', 'zmb_screecher_bury', 'dirt, digging' ],
    [ 'destroyed', 'Relay destroyed, parts drop', 'Step 3: the roof relay chewed to 0 hp bursts and its three parts drop back.',
      'Also when a part appears in the world.', 'zmb_explo', 'a bang' ],
    [ 'portal', 'A lamp portal is taken', 'The player warps from a lamp; heard 2D by that player.',
      'Any lamp portal, whole game.', 'zmb_screecher_portal_warp_2d', 'a warp' ],
    [ 'orb_release', 'Step 7 starts', 'The orb leaves its slot on the table and the wave begins.',
      'Step 7 only.', 'zmb_screecher_portal_end', 'a release, a click' ],
    [ 'sting', 'Finale sting', 'After the world change, before the closing lines.',
      'Finale only.', 'zmb_whoosh', 'a musical sting' ],
);

my %cat = map { $_->{a} => ( $_->{d} <= 1.6 ? 'short' : ( $_->{a} =~ /loop|looper|ticktock/ ? 'loop' : 'long' ) ) } @sounds;

sub rows_for {
    my ($rid) = @_;
    my $out = '';
    for my $s (@sounds) {
        my $range = $s->{pan} eq '2d' ? '2D' : "3D $s->{dmin}-$s->{dmax}";
        my $dur   = sprintf( '%.1f s', $s->{d} );
        my $van   = $vanilla{ $s->{a} } ? $vanilla{ $s->{a} } : '';
        $out .= qq~<li class="row" data-alias="$s->{a}" data-cat="$cat{$s->{a}}"><button class="play" type="button" data-alias="$s->{a}" aria-label="Play $s->{a}"><span class="tri"></span></button><label class="pickrow"><input type="radio" name="pick-$rid" value="$s->{a}"><code>$s->{a}</code><span class="dur">$dur</span><span class="chip">$range</span><span class="chip">vol $s->{vol}</span><span class="van">$van</span></label></li>\n~;
    }
    return $out;
}

my $steps = '';
my $n     = scalar @roles;
for my $i ( 0 .. $#roles ) {
    my ( $id, $title, $when, $ex, $cur, $fits ) = @{ $roles[$i] };
    my $rows = rows_for($id);
    my $k    = $i + 1;
    $steps .= <<"STEP";
<section class="step" data-id="$id" data-cur="$cur" hidden>
  <div class="card">
    <div class="eyebrow">Action $k of $n</div>
    <h2>$title</h2>
    <p class="when">$when</p>
    <p class="ex"><b>In the quest:</b> $ex</p>
    <p class="fits"><b>What fits:</b> $fits</p>
    <div class="cur"><span>Today:</span><button class="play small" type="button" data-alias="$cur" aria-label="Play current"><span class="tri"></span></button><code>$cur</code><button class="keep" type="button">Keep it</button></div>
  </div>
  <div class="filters"><input type="search" placeholder="Search a sound (name)" aria-label="Search"><div class="chips"><button type="button" data-cat="" class="on">all</button><button type="button" data-cat="short">short</button><button type="button" data-cat="long">long</button><button type="button" data-cat="loop">loops</button></div></div>
  <ul class="rows">$rows</ul>
</section>
STEP
}

my $json = join( ',', map { qq~"$_->{a}":"$_->{uri}"~ } @sounds );
my $count = scalar @sounds;

print <<"HTML";
<title>Dead Frequency Sound Picker</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;700&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{--bg:#efece6;--panel:#ffffff;--ink:#1b1e23;--muted:#5d6673;--line:#d9d4ca;--accent:#c96f14;--elec:#1f78b8;--good:#3f8f46;--bar:#e6dfd2;--sel:#fff3e4}
\@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419}}
:root[data-theme="dark"]{--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419}
body{background:var(--bg);color:var(--ink);font:15px/1.5 "IBM Plex Sans",system-ui,sans-serif;margin:0}
.wrap{max-width:980px;margin:0 auto;padding:22px 20px 90px}
.top{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:16px}
.top h1{font:700 34px/1 "Barlow Condensed","Arial Narrow",sans-serif;margin:0;flex:1}
.progress{font:13px "IBM Plex Mono",monospace;color:var(--muted)}
.nav{display:flex;gap:8px}
.nav button,.keep,.copy{background:var(--accent);color:#fff;border:0;padding:9px 16px;font:600 14px "IBM Plex Sans",sans-serif;cursor:pointer}
.nav button.ghost,.keep{background:transparent;color:var(--ink);border:1px solid var(--line)}
.nav button:disabled{opacity:.4;cursor:default}
button:focus-visible,input:focus-visible{outline:2px solid var(--elec);outline-offset:2px}
.track{height:4px;background:var(--bar);margin:0 0 20px}.track i{display:block;height:100%;background:var(--accent);transition:width .2s}
.card{background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--accent);padding:16px 18px;margin-bottom:14px}
.eyebrow{font:600 11px "IBM Plex Sans",sans-serif;letter-spacing:.1em;text-transform:uppercase;color:var(--accent)}
.card h2{font:700 30px/1.05 "Barlow Condensed",sans-serif;margin:4px 0 8px;text-wrap:balance}
.card p{margin:0 0 6px;max-width:72ch}.when{color:var(--ink)}.ex,.fits{color:var(--muted);font-size:14px}
.cur{display:flex;align-items:center;gap:10px;margin-top:10px;padding-top:10px;border-top:1px solid var(--line);flex-wrap:wrap}
.cur span{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.cur code{font:500 14px "IBM Plex Mono",monospace}
.filters{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:0 0 8px}
.filters input{flex:1 1 240px;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px 10px;font:14px "IBM Plex Sans",sans-serif}
.chips{display:flex;gap:6px}.chips button{background:transparent;color:var(--muted);border:1px solid var(--line);padding:5px 10px;font:12px "IBM Plex Mono",monospace;cursor:pointer}
.chips button.on{color:var(--accent);border-color:var(--accent)}
.rows{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:4px}
.row{display:flex;align-items:center;gap:10px;background:var(--panel);border:1px solid var(--line);padding:6px 10px}
.row.playing{border-color:var(--accent)}.row.picked{background:var(--sel);border-color:var(--accent)}
.pickrow{display:flex;align-items:center;gap:10px;flex:1;cursor:pointer;min-width:0;flex-wrap:wrap}
.pickrow code{font:500 14px "IBM Plex Mono",monospace}
.dur{font:12px "IBM Plex Mono",monospace;font-variant-numeric:tabular-nums;color:var(--ink);min-width:44px}
.chip{font:11px "IBM Plex Mono",monospace;color:var(--muted);border:1px solid var(--line);padding:0 5px;border-radius:3px}
.van{font-size:11px;color:var(--muted);margin-left:auto}
.play{width:36px;height:36px;border-radius:50%;border:1px solid var(--line);background:var(--bg);cursor:pointer;display:grid;place-items:center;flex:none}
.play.small{width:30px;height:30px}
.play .tri{width:0;height:0;border-left:11px solid var(--accent);border-top:7px solid transparent;border-bottom:7px solid transparent;margin-left:2px}
.row.playing .play{background:var(--accent)}.row.playing .play .tri{border-left-color:#fff}
.summary .list{font:13px/1.7 "IBM Plex Mono",monospace;white-space:pre-wrap;background:var(--panel);border:1px solid var(--line);padding:12px}
.summary textarea{width:100%;box-sizing:border-box;min-height:80px;margin:10px 0;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px;font:14px "IBM Plex Sans",sans-serif}
.foot{position:fixed;left:0;right:0;bottom:0;background:var(--panel);border-top:1px solid var(--line);padding:10px 20px;display:flex;justify-content:center;gap:10px;z-index:3}
</style>
<div class="wrap">
<div class="top"><h1>Dead Frequency Sound Picker</h1><span class="progress" id="prog"></span></div>
<div class="track"><i id="bar" style="width:0%"></i></div>
<p class="when" style="color:var(--muted);margin:0 0 16px;max-width:76ch">One action at a time. Read where it happens, listen to what plays today, then press play on the list and tick the one you want. Next moves on; Skip leaves an action unchanged. Your picks are kept in this browser and summed up at the end, with a copy button. The "vol" chip is the alias's own level in the bank (60 quiet, 95 loud): the game has no volume knob, so prefer 85+ for anything that must be heard. $count sounds, all from the TranZit banks.</p>
$steps
<section class="step summary" data-id="summary" hidden>
  <div class="card"><div class="eyebrow">Done</div><h2>Your picks</h2><p class="when">Copy this and paste it to me. "keep" means the current sound stays.</p></div>
  <div class="list" id="sumlist"></div>
  <textarea id="notes" placeholder="Notes (too quiet, wrong feel, ideas)"></textarea>
  <button class="copy" type="button" id="copy">Copy picks</button>
</section>
</div>
<div class="foot nav"><button type="button" class="ghost" id="prev">Previous</button><button type="button" class="ghost" id="skip">Skip</button><button type="button" id="next">Next</button></div>
<audio id="player" preload="auto"></audio>
<script type="application/json" id="snd">{$json}</script>
<script>
(function(){
  var SND=JSON.parse(document.getElementById('snd').textContent);
  var steps=Array.prototype.slice.call(document.querySelectorAll('.step')),cur=0,picks={},keep={};
  var player=document.getElementById('player'),playingRow=null,notes=document.getElementById('notes');
  try{var st=JSON.parse(localStorage.getItem('df_wiz_snd')||'{}');picks=st.picks||{};keep=st.keep||{};cur=st.cur||0;notes.value=st.notes||'';}catch(e){}
  function save(){try{localStorage.setItem('df_wiz_snd',JSON.stringify({picks:picks,keep:keep,cur:cur,notes:notes.value}))}catch(e){}}
  function stop(){player.pause();player.currentTime=0;if(playingRow){playingRow.classList.remove('playing');playingRow=null}}
  function play(alias,row){if(playingRow===row&&!player.paused){stop();return}stop();if(!SND[alias])return;player.src=SND[alias];player.play();if(row){playingRow=row;row.classList.add('playing')}}
  player.addEventListener('ended',function(){if(playingRow){playingRow.classList.remove('playing');playingRow=null}});
  function summary(){var out=[];steps.forEach(function(s){var id=s.dataset.id;if(id==='summary')return;var t=s.querySelector('h2').textContent;var v=picks[id]?picks[id]:(keep[id]?'keep ('+s.dataset.cur+')':'-- not decided --');out.push(t+' = '+v)});return out.join('\\n')}
  function show(i){stop();cur=Math.max(0,Math.min(steps.length-1,i));steps.forEach(function(s,k){s.hidden=k!==cur});
    document.getElementById('prog').textContent=cur<steps.length-1?('action '+(cur+1)+' / '+(steps.length-1)):'summary';
    document.getElementById('bar').style.width=Math.round(100*cur/(steps.length-1))+'%';
    document.getElementById('prev').disabled=cur===0;document.getElementById('skip').disabled=cur===steps.length-1;
    document.getElementById('next').textContent=cur===steps.length-2?'Finish':'Next';document.getElementById('next').disabled=cur===steps.length-1;
    if(cur===steps.length-1)document.getElementById('sumlist').textContent=summary();
    window.scrollTo(0,0);save()}
  steps.forEach(function(s){
    var id=s.dataset.id;
    s.querySelectorAll('.play').forEach(function(b){b.addEventListener('click',function(){play(b.dataset.alias,b.closest('.row'))})});
    s.querySelectorAll('input[type=radio]').forEach(function(r){
      if(picks[id]===r.value){r.checked=true;r.closest('.row').classList.add('picked')}
      r.addEventListener('change',function(){picks[id]=r.value;delete keep[id];s.querySelectorAll('.row').forEach(function(x){x.classList.remove('picked')});r.closest('.row').classList.add('picked');save()});
    });
    var k=s.querySelector('.keep');if(k)k.addEventListener('click',function(){keep[id]=1;delete picks[id];s.querySelectorAll('.row').forEach(function(x){x.classList.remove('picked')});s.querySelectorAll('input[type=radio]').forEach(function(r){r.checked=false});save();show(cur+1)});
    var search=s.querySelector('input[type=search]'),chips=s.querySelectorAll('.chips button'),cat='';
    function filter(){var q=(search?search.value:'').toLowerCase();s.querySelectorAll('.row').forEach(function(r){var ok=(!q||r.dataset.alias.indexOf(q)>=0)&&(!cat||r.dataset.cat===cat);r.hidden=!ok})}
    if(search)search.addEventListener('input',filter);
    chips.forEach(function(c){c.addEventListener('click',function(){cat=c.dataset.cat;chips.forEach(function(x){x.classList.toggle('on',x===c)});filter()})});
  });
  document.getElementById('prev').addEventListener('click',function(){show(cur-1)});
  document.getElementById('next').addEventListener('click',function(){show(cur+1)});
  document.getElementById('skip').addEventListener('click',function(){show(cur+1)});
  notes.addEventListener('input',save);
  document.getElementById('copy').addEventListener('click',function(){var t=summary();if(notes.value)t+='\\n\\nNotes: '+notes.value;var b=this;function done(){b.textContent='Copied';setTimeout(function(){b.textContent='Copy picks'},1500)}if(navigator.clipboard){navigator.clipboard.writeText(t).then(done,function(){prompt('Copy this:',t)})}else{prompt('Copy this:',t)}});
  show(cur);
})();
</script>
HTML
