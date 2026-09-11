use strict;
use warnings;
use MIME::Base64 qw(encode_base64);

# gen_board.pl > board.html : the Dead Frequency sound board (every candidate cue of the TranZit banks, playable)
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

# what the mod plays each alias for today (df_*.gsc, 2026-09-11)
my %use = (
    zmb_spawn_powerup        => 'STEP AVAILABLE (with the glint)',
    zmb_buildable_piece_add  => 'progress tick (soul, part, charge)',
    zmb_sq_navcard_success   => 'sub-goal done (lamp filled, box, brazier)',
    zmb_powerup_grabbed      => 'STEP DONE',
    zmb_no_cha_ching         => 'wrong input',
    zmb_bus_emp_shutdown     => 'fail / progress lost',
    zmb_tombstone_timer_count => 'clock tick (no file in the dump)',
    zmb_switch_flip          => 'phone tone 1',
    zmb_meteor_activate      => 'phone tone 2',
    zmb_zombie_arc           => 'phone tone 3',
    zmb_power_rise_start     => 'phone tone 4, tune / draw start',
    zmb_perks_packa_knuckle_0 => 'handset off the hook',
    zmb_perks_packa_ready    => 'the phone rings',
    zmb_phdflop_explo        => 'fire ignites (brazier, Maxis strike)',
    zmb_turbine_wind         => 'hot air puff (ember, brazier puff)',
    evt_electrical_surge     => 'soul reaches a lamp (Richtofen)',
    zmb_meteor_loop          => 'hum: lamp waiting, orb idle',
    zmb_power_rise_loop      => 'hum: tuning / drawing',
    zmb_power_rise_stop      => 'tune / draw complete',
    zmb_avogadro_loop        => 'hum: Richtofen finale build-up',
    zmb_avogadro_warp_in     => 'Simon box 1, finale hum start',
    zmb_avogadro_warp_out    => 'Simon box 2',
    zmb_screecher_portal_arrive => 'Simon box 3',
    zmb_buildable_pickup     => 'take a part / ember',
    zmb_buildable_complete   => 'relay built, relay plugged, orb released',
    zmb_fire_loop            => 'hum: Maxis finale build-up',
    zmb_screecher_bury       => 'denizen digs out (M1)',
    zmb_bus_horn_warn        => 'relay at 200 hp',
    zmb_turbine_explo        => 'relay destroyed, part appears',
    zmb_screecher_portal_warp_2d => 'lamp portal taken',
    zmb_screecher_portal_end => 'lamp portal closes',
    mus_perks_jugganog_sting => 'sting',
    zmb_avogadro_spawn_3d    => 'Avogadro recalled (S7)',
);

my @groups = (
    [ 'In use today',        sub { exists $use{ $_[0] } } ],
    [ 'Short: tone and cue candidates (under 1.6 s)', sub { $_[1] <= 1.6 } ],
    [ 'Fire, lava, explosions', sub { $_[0] =~ /fire|burn|lava|explo|sizzle|nuke|flash/ } ],
    [ 'Electric, power, storm',  sub { $_[0] =~ /elec|arc|power|lightning|bolt|tesla|avogadro|surge|turbine|inert/ } ],
    [ 'Loops and hums',          sub { $_[0] =~ /loop|looper|ticktock/ } ],
    [ 'Everything else',         sub { 1 } ],
);

my @rows;
open my $bk, '<', 'board_keep.txt' or die;
while (<$bk>) {
    chomp;
    my ( $a, $f, $sz, $d, $pan, $dmin, $dmax, $vol ) = split /\t/;
    my $ext  = $f =~ /\.flac$/ ? 'flac' : 'wav';
    my $mime = $ext eq 'flac' ? 'audio/flac' : 'audio/wav';
    my $small = "small/$a.$ext";
    open my $fh, '<:raw', $small or die "$small: $!";
    local $/;
    my $bin = <$fh>;
    close $fh;
    my $b64 = encode_base64( $bin, '' );
    push @rows, { a => $a, d => $d, pan => $pan, dmin => $dmin, dmax => $dmax, vol => $vol, mime => $mime, b64 => $b64 };
}
close $bk;

my %placed;
my $html_groups = '';
for my $g (@groups) {
    my ( $title, $test ) = @$g;
    my @in = grep { !$placed{ $_->{a} } && $test->( $_->{a}, $_->{d} ) } sort { $a->{d} <=> $b->{d} } @rows;
    next unless @in;
    $placed{ $_->{a} } = 1 for @in;
    my $items = '';
    for my $r (@in) {
        my $pct  = int( 100 * ( $r->{d} > 6 ? 6 : $r->{d} ) / 6 );
        my $range = $r->{pan} eq '2d' ? 'everywhere (2D)' : "3D, fades $r->{dmin}-$r->{dmax} units";
        my $rangecls = $r->{pan} eq '2d' ? 'chip chip-2d' : ( $r->{dmax} < 300 ? 'chip chip-short' : 'chip' );
        my $usecls = exists $use{ $r->{a} } ? 'use' : 'use use-none';
        my $usetxt = exists $use{ $r->{a} } ? $use{ $r->{a} } : 'not used by the mod';
        my $van   = $vanilla{ $r->{a} } ? "vanilla: $vanilla{$r->{a}}" : 'vanilla: not played by a TranZit script';
        my $dur   = sprintf( '%.1f s', $r->{d} );
        $items .= <<"ROW";
<li class="row" data-alias="$r->{a}">
  <button class="play" type="button" aria-label="Play $r->{a}"><span class="tri"></span></button>
  <div class="main">
    <div class="line1"><code class="alias">$r->{a}</code><span class="$rangecls">$range</span><span class="chip chip-vol">vol $r->{vol}</span></div>
    <div class="bar" aria-hidden="true"><i style="width:$pct%"></i></div>
    <div class="line2"><span class="dur">$dur</span><span class="$usecls">$usetxt</span><span class="van">$van</span></div>
  </div>
  <label class="pick"><span>use for</span>
    <select data-alias="$r->{a}">
      <option value="">nothing</option>
      <option>phone tone 1</option><option>phone tone 2</option><option>phone tone 3</option><option>phone tone 4</option>
      <option>handset</option><option>phone ring</option><option>progress tick</option><option>sub-goal done</option>
      <option>step done</option><option>wrong input</option><option>fail</option><option>clock tick</option>
      <option>fire ignites</option><option>fire puff</option><option>soul arrives</option><option>hum electric</option>
      <option>hum fire</option><option>tune complete</option><option>other (say in notes)</option>
    </select>
  </label>
  <audio preload="none" src="data:$r->{mime};base64,$r->{b64}"></audio>
</li>
ROW
    }
    my $n = scalar @in;
    $html_groups .= <<"GRP";
<section class="group">
  <h2>$title <small>$n</small></h2>
  <ul class="rows">$items</ul>
</section>
GRP
}

my $count = scalar @rows;
print <<"HTML";
<title>Dead Frequency Sound Board</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;700&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{--bg:#efece6;--panel:#ffffff;--ink:#1b1e23;--muted:#5d6673;--line:#d9d4ca;--accent:#c96f14;--elec:#1f78b8;--good:#3f8f46;--bar:#e6dfd2}
\@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36}}
:root[data-theme="dark"]{--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36}
body{background:var(--bg);color:var(--ink);font:15px/1.5 "IBM Plex Sans",system-ui,sans-serif;margin:0}
.wrap{max-width:1060px;margin:0 auto;padding:28px 20px 80px}
header h1{font:700 44px/1 "Barlow Condensed","Arial Narrow",sans-serif;letter-spacing:.01em;margin:0 0 6px;text-wrap:balance}
header p{color:var(--muted);max-width:68ch;margin:0 0 18px}
.picks{position:sticky;top:0;z-index:2;background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--accent);padding:12px 16px;margin:0 0 26px;display:flex;gap:16px;align-items:flex-start;flex-wrap:wrap}
.picks h3{font:700 18px/1 "Barlow Condensed",sans-serif;text-transform:uppercase;letter-spacing:.08em;margin:0 0 6px;color:var(--accent)}
.picks .list{flex:1 1 320px;min-height:22px;font:13px/1.6 "IBM Plex Mono",monospace;white-space:pre-wrap;color:var(--ink)}
.picks .list:empty::before{content:"choose a role on any row below; your list builds here";color:var(--muted);font-family:"IBM Plex Sans",sans-serif}
.picks textarea{flex:1 1 260px;min-height:60px;background:var(--bg);color:var(--ink);border:1px solid var(--line);padding:8px;font:13px/1.5 "IBM Plex Sans",sans-serif;resize:vertical}
.picks .btns{display:flex;flex-direction:column;gap:8px}
button.copy,button.clear{background:var(--accent);color:#fff;border:0;padding:9px 14px;font:600 13px "IBM Plex Sans",sans-serif;letter-spacing:.02em;cursor:pointer}
button.clear{background:transparent;color:var(--muted);border:1px solid var(--line)}
button:focus-visible,select:focus-visible{outline:2px solid var(--elec);outline-offset:2px}
.group{margin:0 0 34px}
.group h2{font:700 26px/1.1 "Barlow Condensed",sans-serif;margin:0 0 10px;padding-bottom:6px;border-bottom:1px solid var(--line)}
.group h2 small{font:500 15px "IBM Plex Mono",monospace;color:var(--muted);margin-left:8px}
.rows{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:6px}
.row{display:grid;grid-template-columns:44px 1fr auto;gap:14px;align-items:center;background:var(--panel);border:1px solid var(--line);padding:10px 12px}
.row.playing{border-color:var(--accent)}
.play{width:44px;height:44px;border-radius:50%;border:1px solid var(--line);background:var(--bg);cursor:pointer;display:grid;place-items:center}
.play .tri{width:0;height:0;border-left:14px solid var(--accent);border-top:9px solid transparent;border-bottom:9px solid transparent;margin-left:3px}
.row.playing .play{background:var(--accent)}.row.playing .play .tri{border-left-color:#fff}
.main{min-width:0;display:flex;flex-direction:column;gap:5px}
.line1,.line2{display:flex;gap:10px;align-items:baseline;flex-wrap:wrap}
.alias{font:500 15px "IBM Plex Mono",monospace;color:var(--ink)}
.chip{font:12px "IBM Plex Mono",monospace;color:var(--muted);border:1px solid var(--line);padding:0 6px;border-radius:3px}
.chip-2d{color:var(--elec);border-color:var(--elec)}
.chip-short{color:var(--accent);border-color:var(--accent)}
.bar{height:4px;background:var(--bar);max-width:360px}.bar i{display:block;height:100%;background:var(--accent)}
.dur{font:13px "IBM Plex Mono",monospace;font-variant-numeric:tabular-nums;color:var(--ink)}
.use{font-size:13px;color:var(--good);font-weight:600}.use-none{color:var(--muted);font-weight:400}
.van{font-size:12px;color:var(--muted)}
.pick{display:flex;flex-direction:column;gap:3px;font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}
.pick select{background:var(--bg);color:var(--ink);border:1px solid var(--line);padding:6px 8px;font:13px "IBM Plex Sans",sans-serif;min-width:170px}
\@media (max-width:720px){.row{grid-template-columns:44px 1fr}.pick{grid-column:2}.bar{max-width:none}}
\@media (prefers-reduced-motion: no-preference){.row{transition:border-color .15s}}
</style>
<div class="wrap">
<header>
  <h1>Dead Frequency Sound Board</h1>
  <p>Every sound below is a real alias of the TranZit Original banks ($count of them, played from the game files). Ranges are the alias's own 3D fade distances in game units; the mod already delivers cues at the listener, so range only matters for sounds played at a prop. Press play, choose what each sound should be used for, then copy the list and paste it back to me.</p>
</header>
<div class="picks">
  <div><h3>Your picks</h3><div class="list" id="picks"></div></div>
  <textarea id="notes" placeholder="Notes: which cue is too quiet, what the pipes should sound like, anything else"></textarea>
  <div class="btns"><button class="copy" type="button" id="copy">Copy picks</button><button class="clear" type="button" id="clear">Clear</button></div>
</div>
$html_groups
</div>
<script>
(function(){
  var rows=document.querySelectorAll('.row'),current=null,picks={},notesEl=document.getElementById('notes');
  try{picks=JSON.parse(localStorage.getItem('df_picks')||'{}')||{};notesEl.value=localStorage.getItem('df_notes')||'';}catch(e){picks={}}
  function save(){try{localStorage.setItem('df_picks',JSON.stringify(picks));localStorage.setItem('df_notes',notesEl.value)}catch(e){}}
  function render(){var out=[];Object.keys(picks).forEach(function(a){if(picks[a])out.push(picks[a]+' = '+a)});document.getElementById('picks').textContent=out.join('\\n')}
  rows.forEach(function(row){
    var audio=row.querySelector('audio'),btn=row.querySelector('.play'),sel=row.querySelector('select'),alias=row.dataset.alias;
    if(picks[alias])sel.value=picks[alias];
    btn.addEventListener('click',function(){
      if(current&&current!==audio){current.pause();current.currentTime=0;current.closest('.row').classList.remove('playing')}
      if(!audio.paused){audio.pause();audio.currentTime=0;row.classList.remove('playing');current=null;return}
      current=audio;row.classList.add('playing');audio.play();
    });
    audio.addEventListener('ended',function(){row.classList.remove('playing');if(current===audio)current=null});
    sel.addEventListener('change',function(){picks[alias]=sel.value;save();render()});
  });
  notesEl.addEventListener('input',save);
  document.getElementById('copy').addEventListener('click',function(){
    var t=document.getElementById('picks').textContent;if(notesEl.value)t+='\\n\\nNotes: '+notesEl.value;
    var b=this;function done(){b.textContent='Copied';setTimeout(function(){b.textContent='Copy picks'},1500)}
    if(navigator.clipboard){navigator.clipboard.writeText(t).then(done,function(){prompt('Copy this:',t)})}else{prompt('Copy this:',t)}
  });
  document.getElementById('clear').addEventListener('click',function(){picks={};notesEl.value='';save();render();rows.forEach(function(r){r.querySelector('select').value=''})});
  render();
})();
</script>
HTML
