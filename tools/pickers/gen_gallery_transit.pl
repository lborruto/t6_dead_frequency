use strict;
use warnings;
use FindBin;

# gen_gallery_transit.pl > gallery.html : "TranZit Prop Gallery" -- every always-loaded TranZit model (the same set
# the Prop Picker / Prop Composer use) as a thumbnail grid SORTED BY SIZE (largest side), with its size, zone and
# the Dead Frequency kinds that already use it, a size filter, a search box, and a 3D viewer for the one you
# click. Thumbnails are rendered in the browser from the embedded glTF (grey: shape and size only). Read-only:
# nothing here writes to the repo.
my $viewer = 'C:/Games/t6/model_dump/viewer';
my $coords = "$FindBin::Bin/../../df_coords.gsc";

my %dims;
open my $sz, '<', "$viewer/SIZES.txt" or die "$viewer/SIZES.txt: $!";
while (<$sz>) {
    next if /^#/;
    if (/^(\S+)\s+(\S+)\s+w\s+(\d+)\s+h\s+(\d+)\s+d\s+(\d+)/) { $dims{$1} = { zone => $2, w => $3, h => $4, d => $5 } }
}
close $sz;

# which df kinds use a model today (df_model_def( "kind", "model", ... ))
my %used;
open my $cf, '<', $coords or die "$coords: $!";
while (<$cf>) {
    next if m{^\s*//};
    push @{ $used{$2} }, $1 while /df_model_def\(\s*"([^"]+)"\s*,\s*"([^"]+)"/g;
}
close $cf;

my @models;
my $total = 0;
for my $zone ( 'zm_transit', 'so_zclassic_zm_transit', 'common_zm', 'patch_zm' ) {
    next unless -d "$viewer/$zone";
    opendir my $dh, "$viewer/$zone" or die;
    for my $f ( sort readdir $dh ) {
        next unless $f =~ /^(.+)\.gltf$/;
        my $name = $1;
        next if $name =~ /^(c_|t6_|veh_|fx_|weapon_|tag_|skybox|world|projectile|fxanim|defaultvehicle)/;
        my $path = "$viewer/$zone/$f";
        my $bytes = -s $path;
        next if $bytes > 420_000;
        next if $total + $bytes > 14_500_000;
        open my $fh, '<:raw', $path or die;
        local $/;
        my $json = <$fh>;
        close $fh;
        $json =~ s{</script}{<\\/script}gi;
        $total += $bytes;
        my $d = $dims{$name} || { w => 0, h => 0, d => 0 };
        my $max = $d->{w};
        $max = $d->{h} if $d->{h} > $max;
        $max = $d->{d} if $d->{d} > $max;
        push @models, { name => $name, zone => $zone, json => $json, w => $d->{w}, h => $d->{h}, d => $d->{d}, max => $max,
                        used => join( ', ', @{ $used{$name} || [] } ) };
    }
    closedir $dh;
}
@models = sort { $a->{max} <=> $b->{max} || $a->{name} cmp $b->{name} } @models;
printf STDERR "%d models, %.2f MB of glTF\n", scalar @models, $total / 1048576;

my $scripts = join( '', map { qq~<script type="application/json" data-model="$_->{name}">$_->{json}</script>\n~ } @models );
my $list = join( ',', map {
    my $u = $_->{used}; $u =~ s/"/\\"/g;
    qq~{"n":"$_->{name}","z":"$_->{zone}","w":$_->{w},"h":$_->{h},"d":$_->{d},"m":$_->{max},"u":"$u"}~
} @models );
my $count = scalar @models;

print <<"HTML";
<title>TranZit Prop Gallery</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@500;600&family=IBM+Plex+Sans:wght@400;500&family=IBM+Plex+Mono&display=swap">
<style>
:root{--bg:#eef0ec;--panel:#fbfbf8;--ink:#1d211d;--muted:#5f685f;--rule:#d3d8d0;--acc:#b8541c;--acc-soft:#f4e3d8;--thumb:#dfe3dc;--sel:#fff3e6}
\@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){color-scheme:dark;--bg:#141714;--panel:#1c201c;--ink:#e3e8e1;--muted:#98a397;--rule:#2d332d;--acc:#f0874a;--acc-soft:#3a2518;--thumb:#252a25;--sel:#2c241c}}
:root[data-theme="dark"]{color-scheme:dark;--bg:#141714;--panel:#1c201c;--ink:#e3e8e1;--muted:#98a397;--rule:#2d332d;--acc:#f0874a;--acc-soft:#3a2518;--thumb:#252a25;--sel:#2c241c}
body{background:var(--bg);color:var(--ink);font:14px/1.5 "IBM Plex Sans",system-ui,sans-serif;padding-inline:16px;padding-block:20px 40px}
.wrap{max-width:1180px;margin:0 auto;display:flex;flex-direction:column;gap:16px}
h1{font:600 30px/1.1 "Chakra Petch","Arial Narrow",sans-serif;letter-spacing:.02em;margin:0;text-transform:uppercase}
.lede{color:var(--muted);margin:6px 0 0;max-width:75ch}
.bar{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
.bar input{font:14px "IBM Plex Sans",sans-serif;padding:7px 10px;border:1px solid var(--rule);border-radius:4px;background:var(--panel);color:var(--ink);min-width:220px;flex:1 1 220px}
.chip{font:500 12px "IBM Plex Mono",monospace;padding:6px 10px;border:1px solid var(--rule);border-radius:4px;background:var(--panel);color:var(--muted);cursor:pointer}
.chip.on{background:var(--acc-soft);color:var(--acc);border-color:var(--acc)}
.chip:focus-visible,.card:focus-visible{outline:2px solid var(--acc);outline-offset:2px}
.main{display:grid;grid-template-columns:1fr 360px;gap:16px;align-items:start}
\@media (max-width:860px){.main{grid-template-columns:1fr}}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(138px,1fr));gap:10px}
.card{background:var(--panel);border:1px solid var(--rule);border-radius:4px;padding:6px;cursor:pointer;display:flex;flex-direction:column;gap:4px;text-align:left;color:inherit;font:inherit}
.card.sel{border-color:var(--acc);background:var(--sel)}
.card img,.card .ph{width:100%;aspect-ratio:1;background:var(--thumb);border-radius:3px;display:block;object-fit:contain}
.nm{font:12px "IBM Plex Mono",monospace;overflow-wrap:anywhere;line-height:1.3}
.sz{font:11px "IBM Plex Mono",monospace;color:var(--muted);font-variant-numeric:tabular-nums}
.use{font:500 10px "IBM Plex Mono",monospace;color:var(--acc);text-transform:uppercase;letter-spacing:.05em;overflow-wrap:anywhere}
.side{position:sticky;top:12px;background:var(--panel);border:1px solid var(--rule);border-radius:4px;padding:12px;display:flex;flex-direction:column;gap:8px}
.side canvas{width:100%;aspect-ratio:1;background:var(--thumb);border-radius:3px;display:block}
.side h2{font:600 16px "Chakra Petch",sans-serif;margin:0;overflow-wrap:anywhere}
.kv{font:12px "IBM Plex Mono",monospace;color:var(--muted);font-variant-numeric:tabular-nums}
.copy{font:600 13px "IBM Plex Sans",sans-serif;padding:8px 12px;border:0;border-radius:4px;background:var(--acc);color:#fff;cursor:pointer;align-self:flex-start}
.count{font:12px "IBM Plex Mono",monospace;color:var(--muted)}
</style>
<div class="wrap">
  <header>
    <h1>TranZit prop gallery</h1>
    <p class="lede">All $count always-loaded TranZit models, smallest first (by the longest side, in game units: a player is about 70 tall). Grey previews show shape and size only; the game adds the textures. Orange tags are the Dead Frequency props that already use a model. Click one to turn it in 3D and copy its name.</p>
  </header>
  <div class="bar">
    <input id="q" type="search" placeholder="Search a model name" aria-label="Search models">
    <button class="chip on" data-max="0" type="button">All sizes</button>
    <button class="chip" data-max="15" type="button">Tiny &lt; 15</button>
    <button class="chip" data-max="30" type="button">Small &lt; 30</button>
    <button class="chip" data-max="60" type="button">Medium &lt; 60</button>
    <button class="chip" data-min="60" type="button">Large 60+</button>
    <span class="count" id="count"></span>
  </div>
  <div class="main">
    <div class="grid" id="grid"></div>
    <aside class="side">
      <canvas id="view" width="336" height="336"></canvas>
      <h2 id="vname">Pick a model</h2>
      <div class="kv" id="vinfo">Click any card.</div>
      <button class="copy" id="copy" type="button">Copy name</button>
    </aside>
  </div>
</div>
$scripts
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three\@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three\@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script>
(function(){
  var M = [$list];
  var raw = {};
  document.querySelectorAll('script[data-model]').forEach(function(s){ raw[s.getAttribute('data-model')] = s.textContent; });
  function strip(t){ try{ var j = JSON.parse(t); delete j.images; delete j.textures; delete j.samplers;
    (j.materials||[]).forEach(function(m){ delete m.normalTexture; delete m.occlusionTexture; delete m.emissiveTexture;
      if(m.pbrMetallicRoughness){ delete m.pbrMetallicRoughness.baseColorTexture; delete m.pbrMetallicRoughness.metallicRoughnessTexture; } });
    return JSON.stringify(j); }catch(e){ return t; } }
  var ok = !!(window.THREE && THREE.GLTFLoader);
  var loader = ok ? new THREE.GLTFLoader() : null;
  var grey = ok ? new THREE.MeshStandardMaterial({ color: 0xb9b9b0, roughness: 0.8, metalness: 0.05 }) : null;
  function load(name, done){
    if(!ok || !raw[name]) return done(null);
    try{ loader.parse(strip(raw[name]), '', function(g){ g.scene.traverse(function(o){ if(o.isMesh) o.material = grey; }); done(g.scene); }, function(){ done(null); }); }
    catch(e){ done(null); }
  }
  function frame(cam, obj, target){
    var box = new THREE.Box3().setFromObject(obj), size = box.getSize(new THREE.Vector3()), c = box.getCenter(new THREE.Vector3());
    var m = Math.max(size.x, size.y, size.z, 4);
    cam.position.set(c.x + m*1.15, c.y + m*0.8, c.z + m*1.45); cam.near = m/200; cam.far = m*60; cam.updateProjectionMatrix();
    if(target) target.copy(c); cam.lookAt(c);
  }
  function lights(scene){ scene.add(new THREE.HemisphereLight(0xffffff, 0x404040, 1.1)); var d = new THREE.DirectionalLight(0xffffff, 0.8); d.position.set(1,2,1.5); scene.add(d); }

  // thumbnails: one small offscreen renderer, one model at a time
  var tr = null, tscene, tcam;
  if(ok){ try{ tr = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true }); tr.setSize(160, 160); tscene = new THREE.Scene(); lights(tscene); tcam = new THREE.PerspectiveCamera(35, 1, 0.1, 1000); }catch(e){ tr = null; } }
  var queue = [];
  function pump(){
    if(!tr || !queue.length) return;
    var it = queue.shift();
    load(it.m.n, function(obj){
      if(obj){ tscene.add(obj); frame(tcam, obj); tr.render(tscene, tcam); it.img.src = tr.domElement.toDataURL('image/png'); tscene.remove(obj); }
      setTimeout(pump, 0);
    });
  }

  var grid = document.getElementById('grid'), q = document.getElementById('q'), countEl = document.getElementById('count');
  var minS = 0, maxS = 0, sel = null;
  M.forEach(function(m){
    var b = document.createElement('button'); b.type = 'button'; b.className = 'card'; m.el = b;
    var img = document.createElement('img'); img.alt = m.n; img.loading = 'lazy';
    b.appendChild(img);
    b.insertAdjacentHTML('beforeend', '<span class="nm">' + m.n + '</span><span class="sz">' + m.w + ' \\u00d7 ' + m.h + ' \\u00d7 ' + m.d + '</span>' + (m.u ? '<span class="use">' + m.u + '</span>' : ''));
    b.addEventListener('click', function(){ pick(m); });
    grid.appendChild(b); queue.push({ m: m, img: img });
  });
  function apply(){
    var t = q.value.trim().toLowerCase(), n = 0;
    M.forEach(function(m){ var show = (!t || m.n.toLowerCase().indexOf(t) >= 0 || m.u.toLowerCase().indexOf(t) >= 0) && (!maxS || m.m < maxS) && (!minS || m.m >= minS); m.el.hidden = !show; if(show) n++; });
    countEl.textContent = n + ' shown';
  }
  q.addEventListener('input', apply);
  document.querySelectorAll('.chip').forEach(function(c){ c.addEventListener('click', function(){
    document.querySelectorAll('.chip').forEach(function(x){ x.classList.remove('on'); }); c.classList.add('on');
    maxS = +(c.getAttribute('data-max') || 0); minS = +(c.getAttribute('data-min') || 0); apply(); }); });
  apply();
  setTimeout(pump, 50);

  // the big viewer
  var canvas = document.getElementById('view'), vr = null, vscene, vcam, ctl, cur = null;
  if(ok){ try{ vr = new THREE.WebGLRenderer({ canvas: canvas, antialias: true, alpha: true }); vscene = new THREE.Scene(); lights(vscene);
    vscene.add(new THREE.GridHelper(200, 20, 0x888888, 0x555555));
    vcam = new THREE.PerspectiveCamera(35, 1, 0.1, 5000); ctl = THREE.OrbitControls ? new THREE.OrbitControls(vcam, canvas) : null;
    (function loop(){ requestAnimationFrame(loop); var w = canvas.clientWidth, h = canvas.clientHeight; if(canvas.width !== w || canvas.height !== h){ vr.setSize(w, h, false); vcam.aspect = w/h; vcam.updateProjectionMatrix(); } if(ctl) ctl.update(); vr.render(vscene, vcam); })();
  }catch(e){ vr = null; } }
  function pick(m){
    if(sel) sel.el.classList.remove('sel'); sel = m; m.el.classList.add('sel');
    document.getElementById('vname').textContent = m.n;
    document.getElementById('vinfo').textContent = m.w + ' \\u00d7 ' + m.h + ' \\u00d7 ' + m.d + ' units \\u00b7 ' + m.z + (m.u ? ' \\u00b7 used as ' + m.u : '');
    if(!vr) return;
    if(cur){ vscene.remove(cur); cur = null; }
    load(m.n, function(obj){ if(!obj || sel !== m) return; cur = obj; vscene.add(obj); frame(vcam, obj, ctl ? ctl.target : null); });
  }
  document.getElementById('copy').addEventListener('click', function(){
    if(!sel) return; var b = this;
    navigator.clipboard.writeText(sel.n).then(function(){ b.textContent = 'Copied'; setTimeout(function(){ b.textContent = 'Copy name'; }, 1200); }, function(){});
  });
})();
</script>
HTML
