use strict;
use warnings;

# gen_wizard_mdl.pl > wizard_mdl.html : one prop role at a time (what it is, where it stands), the always-loaded
# model list with a search box under it, a 3D viewer (three.js) to look at any model, pick one, Next.
my $viewer = 'C:/Games/t6/model_dump/viewer';
my %dims;
open my $sz, '<', "$viewer/SIZES.txt" or die;
while (<$sz>) {
    next if /^#/;
    if (/^(\S+)\s+(\S+)\s+w\s+(\d+)\s+h\s+(\d+)\s+d\s+(\d+)/) { $dims{$1} = { zone => $2, w => $3, h => $4, d => $5 } }
}
close $sz;

my @models;
for my $zone ( 'zm_transit', 'so_zclassic_zm_transit', 'common_zm', 'patch_zm' ) {
    next unless -d "$viewer/$zone";
    opendir my $dh, "$viewer/$zone" or die;
    for my $f ( sort readdir $dh ) {
        next unless $f =~ /^(.+)\.gltf$/;
        my $name = $1;
        next if $name =~ /^(c_|t6_|veh_|fx_|weapon_|tag_|skybox|world|projectile|fxanim|defaultvehicle)/;
        my $path = "$viewer/$zone/$f";
        my $size = -s $path;
        next if $size > 420_000;
        open my $fh, '<:raw', $path or die;
        local $/;
        my $json = <$fh>;
        close $fh;
        $json =~ s{</script}{<\\/script}gi;
        my $d = $dims{$name} || { w => 0, h => 0, d => 0 };
        push @models, { name => $name, zone => $zone, json => $json, w => $d->{w}, h => $d->{h}, d => $d->{d} };
    }
    closedir $dh;
}
@models = sort { $a->{name} cmp $b->{name} } @models;

my @roles = (
    [ 'pipe', 'The four pipes (Step 1)', 'Four small props on the ground around the Depot. The phone plays four tones; the pipes are tapped in that order. They carry a glow on top and a spark every few seconds, so they must be small but findable.',
      'DF_TV_1..4, Depot. Under 30 units tall works best.', 'pb_pole_telephone_bulb' ],
    [ 'radio', 'The radio (relay base, part A)', 'The base of the relay. Lies at the Cabin as part A, then is the bottom piece of the built relay on the bus roof and on the table.',
      'DF_PART_A (Cabin), bus roof, table slot 0. Flat, about 20 x 30, under 15 tall.', 'p6_zm_buildable_sq_transceiver' ],
    [ 'mast', 'The mast (relay top, part B)', 'Stands at the tunnel as part B, then stands on the coil on the built relay. Tall and thin reads as an antenna from far.',
      'DF_PART_B (tunnel), relay top. Tall.', 'p6_zm_chain_fence_piece_end' ],
    [ 'coil', 'The wire coil (part 3, relay middle)', 'Dropped by the phone when Step 1 is solved, then sits on the radio under the mast. Also the model of the R2 wire spools that filled lamps drop.',
      'Depot floor, relay middle, near filled lamps. Small.', 'p6_zm_buildable_sq_electric_box' ],
    [ 'fuse', 'The four Simon boxes (Farm barn)', 'Four boxes on the barn walls, Richtofen side. They light up in the Simon order, get charged, and become the Step 6 nodes.',
      'DF_FUSE_1..4 on the barn walls at mid height. A wall box or panel.', 'p6_zm_buildable_sq_electric_box' ],
    [ 'brazier', 'The four braziers (lava)', 'Maxis side. Four along the lava past the tower; one burns, the ember lights the others, five burning kills fill each. The fire fx sits on their top.',
      'DF_BRAZIER_1..4 by the lava. Something that holds a fire: rocks, a drum, a bowl.', 'ch_tombstone1' ],
    [ 'orb', 'The charge orb (Step 6 and 7)', 'Lands by lightning, is carried, drains the four nodes, sits on table slot 2, then wanders under the tower during the Step 7 wave with an aura and a hum. Spins slowly.',
      'Carried and on the table. About 20 to 30 units, must read as a machine part, not the skull.', 'p6_zm_buildable_sq_meteor' ],
    [ 'skull', 'The skull (Maxis trophy)', 'Found in Nacht after the M1 latch, carried, placed on table slot 1. Stays there to the end.',
      'Table slot 1. Small.', 'p6_zm_buildable_sq_meteor' ],
    [ 'card', 'The key card (Richtofen)', 'Appears on the barn wall after Avogadro is captured, carried, inserted at table slot 1.',
      'Barn wall, then table slot 1. Small, flat.', 'p6_zm_keycard' ],
    [ 'table', 'The table under the tower', 'The build table: relay on slot 0, card or skull on slot 1, orb on slot 2. Has collision. Everything of the quest ends up on it.',
      'DF_TABLE 7771 -448 -202. About 90 long, 40 tall.', 'p6_zm_work_bench' ],
    [ 'portal', 'The M1 hole (Maxis)', 'The hole that opens in front of the table to Nacht when the latch is ready.',
      'DF_PORTAL 7623 -457 -207. Flat on the ground.', 'p6_zm_screecher_hole' ],
    [ 'ember', 'The ember / beacon', 'The carried fire of M2 and the beacon marker: a small glowing thing.',
      'Carried; markers. Small.', 'p6_zm_buildable_sq_meteor' ],
    [ 'battery', 'The bus battery (R1 fail)', 'Appears on the bus dashboard when the Simon locks; one battery charges the four boxes.',
      'Bus dashboard. Small.', 'p6_zm_buildable_battery' ],
);

my $list = '';
for my $m (@models) {
    $list .= qq~<li class="mrow" data-name="$m->{name}"><code>$m->{name}</code><span class="dims">$m->{w} x $m->{h} x $m->{d}</span><span class="zone">$m->{zone}</span></li>\n~;
}

my $steps = '';
my $n     = scalar @roles;
for my $i ( 0 .. $#roles ) {
    my ( $id, $title, $when, $where, $cur ) = @{ $roles[$i] };
    my $k = $i + 1;
    my $d = $dims{$cur} || { w => '?', h => '?', d => '?' };
    $steps .= <<"STEP";
<section class="step" data-id="$id" data-cur="$cur" hidden>
  <div class="card">
    <div class="eyebrow">Prop $k of $n</div>
    <h2>$title</h2>
    <p class="when">$when</p>
    <p class="ex"><b>Where:</b> $where</p>
    <div class="cur"><span>Today:</span><code>$cur</code><span class="dims">$d->{w} x $d->{h} x $d->{d}</span><button class="view" type="button" data-name="$cur">View</button><button class="keep" type="button">Keep it</button></div>
  </div>
</section>
STEP
}

my $scripts = join( '', map { qq~<script type="application/json" data-model="$_->{name}">$_->{json}</script>\n~ } @models );
my $count = scalar @models;

print <<"HTML";
<title>Dead Frequency Prop Picker</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;700&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{--bg:#efece6;--panel:#ffffff;--ink:#1b1e23;--muted:#5d6673;--line:#d9d4ca;--accent:#c96f14;--elec:#1f78b8;--good:#3f8f46;--bar:#e6dfd2;--sel:#fff3e4;--canvas:#dcd7cc}
\@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419;--canvas:#23272d}}
:root[data-theme="dark"]{--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419;--canvas:#23272d}
body{background:var(--bg);color:var(--ink);font:15px/1.5 "IBM Plex Sans",system-ui,sans-serif;margin:0}
.wrap{max-width:1180px;margin:0 auto;padding:22px 20px 90px}
.top{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:10px}
.top h1{font:700 34px/1 "Barlow Condensed","Arial Narrow",sans-serif;margin:0;flex:1}
.progress{font:13px "IBM Plex Mono",monospace;color:var(--muted)}
.track{height:4px;background:var(--bar);margin:0 0 16px}.track i{display:block;height:100%;background:var(--accent);transition:width .2s}
.grid{display:grid;grid-template-columns:minmax(0,1fr) minmax(320px,46%);gap:18px;align-items:start}
\@media (max-width:860px){.grid{grid-template-columns:1fr}.viewer{position:static}}
.card{background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--accent);padding:16px 18px;margin-bottom:12px}
.eyebrow{font:600 11px "IBM Plex Sans",sans-serif;letter-spacing:.1em;text-transform:uppercase;color:var(--accent)}
.card h2{font:700 30px/1.05 "Barlow Condensed",sans-serif;margin:4px 0 8px;text-wrap:balance}
.card p{margin:0 0 6px;max-width:70ch}.ex{color:var(--muted);font-size:14px}
.cur{display:flex;align-items:center;gap:10px;margin-top:10px;padding-top:10px;border-top:1px solid var(--line);flex-wrap:wrap}
.cur span:first-child{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
code{font:500 14px "IBM Plex Mono",monospace}
.dims{font:12px "IBM Plex Mono",monospace;font-variant-numeric:tabular-nums;color:var(--muted)}
.zone{font:11px "IBM Plex Mono",monospace;color:var(--muted);margin-left:auto}
button{font:600 14px "IBM Plex Sans",sans-serif;cursor:pointer}
.nav button,.pickbtn{background:var(--accent);color:#fff;border:0;padding:9px 16px}
.nav button.ghost,.keep,.view{background:transparent;color:var(--ink);border:1px solid var(--line);padding:7px 12px}
.nav button:disabled,.pickbtn:disabled{opacity:.4;cursor:default}
button:focus-visible,input:focus-visible{outline:2px solid var(--elec);outline-offset:2px}
.filters{display:flex;gap:10px;margin:0 0 8px}
.filters input{flex:1;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px 10px;font:14px "IBM Plex Sans",sans-serif}
.mlist{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:3px;max-height:56vh;overflow:auto;border:1px solid var(--line);background:var(--panel)}
.mrow{display:flex;align-items:center;gap:10px;padding:6px 10px;cursor:pointer;border-bottom:1px solid var(--line)}
.mrow:hover{background:var(--bg)}.mrow.viewing{outline:2px solid var(--elec);outline-offset:-2px}.mrow.picked{background:var(--sel)}
.viewer{position:sticky;top:12px;background:var(--panel);border:1px solid var(--line)}
.viewer canvas{display:block;width:100%;height:420px;background:var(--canvas)}
.vbar{display:flex;align-items:center;gap:10px;padding:10px 12px;flex-wrap:wrap;border-top:1px solid var(--line)}
.vbar .dims{margin-left:auto}
.hint{font-size:12px;color:var(--muted);padding:0 12px 10px}
.summary .list{font:13px/1.7 "IBM Plex Mono",monospace;white-space:pre-wrap;background:var(--panel);border:1px solid var(--line);padding:12px}
.summary textarea{width:100%;box-sizing:border-box;min-height:80px;margin:10px 0;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px;font:14px "IBM Plex Sans",sans-serif}
.foot{position:fixed;left:0;right:0;bottom:0;background:var(--panel);border-top:1px solid var(--line);padding:10px 20px;display:flex;justify-content:center;gap:10px;z-index:3}
</style>
<div class="wrap">
<div class="top"><h1>Dead Frequency Prop Picker</h1><span class="progress" id="prog"></span></div>
<div class="track"><i id="bar" style="width:0%"></i></div>
<p style="color:var(--muted);margin:0 0 14px;max-width:80ch">One prop at a time. Read where it stands, view what is used today, then search the list, click a model to see it in 3D (grey: shape and size only, the game adds the textures), and press "Pick this one". $count always-loaded TranZit models; the grid cells are 10 units, the post is a 70-unit player.</p>
<div class="grid">
<div class="left">
$steps
<section class="step summary" data-id="summary" hidden>
  <div class="card"><div class="eyebrow">Done</div><h2>Your picks</h2><p>Copy this and paste it to me. "keep" means the current model stays.</p></div>
  <div class="list" id="sumlist"></div>
  <textarea id="notes" placeholder="Notes (too big, wrong pose, lay it flat, ...)"></textarea>
  <button class="pickbtn" type="button" id="copy">Copy picks</button>
</section>
<div id="listwrap">
<div class="filters"><input type="search" id="search" placeholder="Search a model name (e.g. antenna, radio, box, lamp)"></div>
<ul class="mlist" id="mlist">$list</ul>
</div>
</div>
<div class="viewer" id="viewer"><canvas id="c"></canvas>
<div class="vbar"><code id="vname">nothing loaded</code><span class="dims" id="vdims"></span><button class="pickbtn" type="button" id="pick" disabled>Pick this one</button></div>
<div class="hint">Drag to turn, wheel to zoom, right-drag to pan.</div></div>
</div>
</div>
<div class="foot nav"><button type="button" class="ghost" id="prev">Previous</button><button type="button" class="ghost" id="skip">Skip</button><button type="button" id="next">Next</button></div>
$scripts
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three\@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three\@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script>
(function(){
  var steps=Array.prototype.slice.call(document.querySelectorAll('.step')),cur=0,picks={},keep={},viewing=null;
  var notes=document.getElementById('notes');
  try{var st=JSON.parse(localStorage.getItem('df_wiz_mdl')||'{}');picks=st.picks||{};keep=st.keep||{};cur=st.cur||0;notes.value=st.notes||'';}catch(e){}
  function save(){try{localStorage.setItem('df_wiz_mdl',JSON.stringify({picks:picks,keep:keep,cur:cur,notes:notes.value}))}catch(e){}}
  // ---- three.js viewer
  var canvas=document.getElementById('c'),renderer,scene,camera,controls,model=null,ok=!!(window.THREE&&THREE.GLTFLoader&&THREE.OrbitControls);
  if(ok){
    renderer=new THREE.WebGLRenderer({canvas:canvas,antialias:true,alpha:true});renderer.setPixelRatio(window.devicePixelRatio||1);
    scene=new THREE.Scene();camera=new THREE.PerspectiveCamera(45,1,0.5,5000);camera.position.set(90,70,120);
    controls=new THREE.OrbitControls(camera,canvas);controls.enableDamping=true;
    scene.add(new THREE.HemisphereLight(0xffffff,0x5a5348,0.9));var dl=new THREE.DirectionalLight(0xffffff,0.8);dl.position.set(120,200,80);scene.add(dl);
    var grid=new THREE.GridHelper(400,40,0xb08050,0x8a8a8a);grid.material.opacity=0.6;grid.material.transparent=true;scene.add(grid);
    var post=new THREE.Mesh(new THREE.BoxGeometry(6,70,6),new THREE.MeshStandardMaterial({color:0x4aa8e8,roughness:0.9}));post.position.set(-60,35,0);scene.add(post);
    function resize(){var w=canvas.clientWidth,h=canvas.clientHeight;if(canvas.width!==w||canvas.height!==h){renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix()}}
    (function loop(){requestAnimationFrame(loop);resize();controls.update();renderer.render(scene,camera)})();
  }else{document.getElementById('viewer').querySelector('.hint').textContent='The 3D libraries did not load; pick by name and size, I will check the shape.'}
  var loader=ok?new THREE.GLTFLoader():null,mat=ok?new THREE.MeshStandardMaterial({color:0xb8b0a2,roughness:0.85,metalness:0.05,side:THREE.DoubleSide}):null;
  function show(name){
    var el=document.querySelector('script[data-model="'+name+'"]');if(!el)return;
    viewing=name;document.getElementById('vname').textContent=name;
    var row=document.querySelector('.mrow[data-name="'+name+'"]');document.querySelectorAll('.mrow.viewing').forEach(function(r){r.classList.remove('viewing')});
    if(row){row.classList.add('viewing');document.getElementById('vdims').textContent=row.querySelector('.dims').textContent+' units'}
    document.getElementById('pick').disabled=false;
    if(!ok)return;
    loader.parse(el.textContent,'',function(g){
      if(model){scene.remove(model)}model=g.scene;model.traverse(function(o){if(o.isMesh){o.material=mat}});scene.add(model);
      var box=new THREE.Box3().setFromObject(model),size=box.getSize(new THREE.Vector3()),center=box.getCenter(new THREE.Vector3());
      var m=Math.max(size.x,size.y,size.z,8);controls.target.copy(center);camera.position.set(center.x+m*1.2,center.y+m*0.9,center.z+m*1.6);camera.near=m/100;camera.far=m*50;camera.updateProjectionMatrix();
    },function(e){document.getElementById('vname').textContent=name+' (could not parse)'});
  }
  // ---- steps
  function summary(){var out=[];steps.forEach(function(s){var id=s.dataset.id;if(id==='summary')return;var t=s.querySelector('h2').textContent;var v=picks[id]?picks[id]:(keep[id]?'keep ('+s.dataset.cur+')':'-- not decided --');out.push(t+' = '+v)});return out.join('\\n')}
  function markPicked(){var s=steps[cur],p=s?picks[s.dataset.id]:null;document.querySelectorAll('.mrow').forEach(function(r){r.classList.toggle('picked',r.dataset.name===p)})}
  function go(i){cur=Math.max(0,Math.min(steps.length-1,i));steps.forEach(function(s,k){s.hidden=k!==cur});
    var last=cur===steps.length-1;document.getElementById('listwrap').hidden=last;
    document.getElementById('prog').textContent=last?'summary':('prop '+(cur+1)+' / '+(steps.length-1));
    document.getElementById('bar').style.width=Math.round(100*cur/(steps.length-1))+'%';
    document.getElementById('prev').disabled=cur===0;document.getElementById('skip').disabled=last;document.getElementById('next').disabled=last;
    document.getElementById('next').textContent=cur===steps.length-2?'Finish':'Next';
    if(last)document.getElementById('sumlist').textContent=summary();else show(picks[steps[cur].dataset.id]||steps[cur].dataset.cur);
    markPicked();window.scrollTo(0,0);save()}
  steps.forEach(function(s){var id=s.dataset.id;
    var v=s.querySelector('.view');if(v)v.addEventListener('click',function(){show(v.dataset.name)});
    var k=s.querySelector('.keep');if(k)k.addEventListener('click',function(){keep[id]=1;delete picks[id];save();go(cur+1)});
  });
  document.querySelectorAll('.mrow').forEach(function(r){r.addEventListener('click',function(){show(r.dataset.name)})});
  document.getElementById('pick').addEventListener('click',function(){if(!viewing)return;var s=steps[cur];if(!s||s.dataset.id==='summary')return;picks[s.dataset.id]=viewing;delete keep[s.dataset.id];save();markPicked()});
  document.getElementById('search').addEventListener('input',function(){var q=this.value.toLowerCase();document.querySelectorAll('.mrow').forEach(function(r){r.hidden=q&&r.dataset.name.indexOf(q)<0})});
  document.getElementById('prev').addEventListener('click',function(){go(cur-1)});
  document.getElementById('next').addEventListener('click',function(){go(cur+1)});
  document.getElementById('skip').addEventListener('click',function(){go(cur+1)});
  notes.addEventListener('input',save);
  document.getElementById('copy').addEventListener('click',function(){var t=summary();if(notes.value)t+='\\n\\nNotes: '+notes.value;var b=this;function done(){b.textContent='Copied';setTimeout(function(){b.textContent='Copy picks'},1500)}if(navigator.clipboard){navigator.clipboard.writeText(t).then(done,function(){prompt('Copy this:',t)})}else{prompt('Copy this:',t)}});
  go(cur);
})();
</script>
HTML
