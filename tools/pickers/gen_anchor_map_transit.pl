use strict;
use warnings;
use FindBin;
use JSON::PP ();

# gen_anchor_map_transit.pl > anchor_map_transit.html : "Dead Frequency Anchor Map" -- a top-down 2D map of
# TranZit (every walkable pathnode as the floor plan, zone labels, window squares, the bus) with every mod
# anchor as a draggable marker, for gross X/Y placement by eye ("move the signal light behind the fence").
# Height (Z) is not edited by dragging: the in-game `!df grab` tool sets it against the real surface; the
# numeric panel still lets Z be typed in directly when a value is already known.
#
# Reads tools/assets/zm_transit.d3dbsp.ents.txt (the floor plan: node_pathnode / info_volume zones /
# zbarrier_* windows / the_bus / player_respawn_point) and df_coords.gsc (every anchor: literal df_coord_set
# defaults, df_ground(literal)-wrapped defaults, and every df_coord_override* call in df_apply_overrides(),
# which always wins). Anchors whose position can only be known in game (wall traces, "!df grab" spots, a
# runtime random pick) are listed separately as "in-game only" and never plotted. Nothing here writes to
# df_coords.gsc or the ents file; it only reads them to build the static HTML page.

my $DF_ROOT = $ENV{DF_ROOT} // "$FindBin::Bin/../..";
my $ents_path   = "$DF_ROOT/tools/assets/zm_transit.d3dbsp.ents.txt";
my $coords_path = "$DF_ROOT/df_coords.gsc";
die "ents file not found (looked at $ents_path)\n"   unless -f $ents_path;
die "df_coords.gsc not found (looked at $coords_path)\n" unless -f $coords_path;

sub rnd { my $v = shift; return $v >= 0 ? int( $v + 0.5 ) : -int( -$v + 0.5 ); }

# =========================================================================================
# 1. The floor plan: tools/assets/zm_transit.d3dbsp.ents.txt, every "{ ... }" entity block.
# =========================================================================================
open my $ef, '<', $ents_path or die "$ents_path: $!";
local $/;
my $ents_txt = <$ef>;
close $ef;

my ( @pathnodes, @zones, @windows, @respawns, $bus );
my ( $minx, $maxx, $miny, $maxy ) = ( 1e18, -1e18, 1e18, -1e18 );

while ( $ents_txt =~ /\{([^{}]*)\}/gs ) {
    my $block = $1;
    my %kv;
    while ( $block =~ /"([^"]+)"\s*"([^"]*)"/g ) {
        $kv{$1} = $2 unless exists $kv{$1};    # first occurrence of a key wins (a block can repeat "target")
    }
    next unless defined $kv{classname};

    if ( $kv{classname} eq 'node_pathnode' && defined $kv{origin} ) {
        my ( $x, $y ) = split ' ', $kv{origin};
        $x += 0; $y += 0;
        push @pathnodes, [ rnd($x), rnd($y) ];
        $minx = $x if $x < $minx; $maxx = $x if $x > $maxx;
        $miny = $y if $y < $miny; $maxy = $y if $y > $maxy;
    }
    elsif ( $kv{classname} eq 'info_volume' && defined( $kv{targetname} ) && $kv{targetname} =~ /^zone_(.+)$/ && defined $kv{origin} ) {
        my $short = $1;
        my ( $x, $y ) = split ' ', $kv{origin};
        push @zones, { n => $short, x => rnd( $x + 0 ), y => rnd( $y + 0 ) };
    }
    elsif ( $kv{classname} =~ /^zbarrier_/ && defined $kv{origin} ) {
        my ( $x, $y ) = split ' ', $kv{origin};
        push @windows, [ rnd( $x + 0 ), rnd( $y + 0 ) ];
    }
    elsif ( defined( $kv{targetname} ) && $kv{targetname} eq 'the_bus' && defined $kv{origin} ) {
        my ( $x, $y ) = split ' ', $kv{origin};
        $bus = { x => rnd( $x + 0 ), y => rnd( $y + 0 ) };
    }
    elsif ( defined( $kv{targetname} ) && $kv{targetname} eq 'player_respawn_point' && defined $kv{origin} ) {
        my ( $x, $y ) = split ' ', $kv{origin};
        push @respawns, [ rnd( $x + 0 ), rnd( $y + 0 ) ];
    }
}
die "no node_pathnode blocks found in $ents_path\n" unless @pathnodes;

my $PAD = 800;
my $vb_x = $minx - $PAD;
my $vb_y = -$maxy - $PAD;                      # screen y = -(game y); top of viewBox = -(max game y)
my $vb_w = ( $maxx - $minx ) + 2 * $PAD;
my $vb_h = ( $maxy - $miny ) + 2 * $PAD;

# =========================================================================================
# 2. Anchors: df_coords.gsc. Only literal-vector positions (default) and every df_coord_override* call
#    (override, always wins) are resolvable offline; wall-trace / facing / vanilla-struct defaults with no
#    override are DERIVED at run time and listed separately.
# =========================================================================================
open my $cf, '<', $coords_path or die "$coords_path: $!";
local $/;
my $gsc = <$cf>;
close $cf;

# ---- model registry (kind -> name, upright pitch/roll, wall yaw offset), same parse gen_composer_transit.pl uses
my ( %k_name, %k_pitch, %k_roll, %k_yawoff );
while ( $gsc =~ /df_model_def\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*(?:,\s*\([^)]*\)\s*)?\)\s*;/g ) {
    $k_name{$1} = $2; $k_pitch{$1} = $3 + 0; $k_roll{$1} = $4 + 0; $k_yawoff{$1} = $5 + 0;
}

# df_model_rest_z()'s rest[name] table (model NAME -> rest height): needed for df_coord_override_rest (DF_TV_*).
my %rest_by_name;
while ( $gsc =~ /rest\["([^"]+)"\]\s*=\s*(-?[\d.]+);/g ) { $rest_by_name{$1} = $2 + 0; }
sub rest_z_of_kind { my $kind = shift; my $name = $k_name{$kind} // ''; return $rest_by_name{$name} // 0; }

my ( %default, %override, %model_of );

# Pattern A: df_coord_set( "KEY", ( x, y, z ), ( p, y, r ), ... )  -- fully literal.
while ( $gsc =~ /df_coord_set\(\s*"([A-Z0-9_]+)"\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,/g ) {
    $default{$1} = { x => $2 + 0, y => $3 + 0, z => $4 + 0, p => $5 + 0, yw => $6 + 0, r => $7 + 0 };
}

# Pattern B: df_coord_set( "KEY", df_ground( ( x, y, z ) ) [+ ( ox, oy, oz )], ( p, y, r ), ... )
#            df_ground() is a floor trace (a runtime call); the literal vector fed into it is used as-is here
#            (matches the design note that these spots are already recorded at/near the floor).
while ( $gsc =~ /df_coord_set\(\s*"([A-Z0-9_]+)"\s*,\s*df_ground\(\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*\)\s*(?:\+\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*)?,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,/g ) {
    my ( $key, $x, $y, $z, $ox, $oy, $oz, $p, $yw, $r ) = ( $1, $2 + 0, $3 + 0, $4 + 0, ( $5 // 0 ) + 0, ( $6 // 0 ) + 0, ( $7 // 0 ) + 0, $8 + 0, $9 + 0, $10 + 0 );
    $default{$key} = { x => $x + $ox, y => $y + $oy, z => $z + $oz, p => $p, yw => $yw, r => $r };
}

# Pattern C: df_coord_override( "KEY", ( x, y, z ), ( p, y, r ) );  -- direct raw override, fully literal.
while ( $gsc =~ /df_coord_override\(\s*"([A-Z0-9_]+)"\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*\)\s*;/g ) {
    $override{$1} = { x => $2 + 0, y => $3 + 0, z => $4 + 0, p => $5 + 0, yw => $6 + 0, r => $7 + 0 };
}

# Pattern D: df_coord_override_rest( "KEY", ( floor_x, floor_y, floor_z ), ( p, y, r ), "kind" );
#            df_coord_override( key, floor_pos + ( 0, 0, df_model_rest_z( kind ) ), angles ) -- angles pass through unchanged.
while ( $gsc =~ /df_coord_override_rest\(\s*"([A-Z0-9_]+)"\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,\s*"([a-z_0-9]+)"\s*\)\s*;/g ) {
    my ( $key, $x, $y, $z, $p, $yw, $r, $kind ) = ( $1, $2 + 0, $3 + 0, $4 + 0, $5 + 0, $6 + 0, $7 + 0, $8 );
    $override{$key} = { x => $x, y => $y, z => $z + rest_z_of_kind($kind), p => $p, yw => $yw, r => $r };
    $model_of{$key} = $kind;
}

# Pattern E: df_coord_override_ground( "KEY", ( feet_x, feet_y, feet_z ), yaw, "kind" );
#            df_coord_set( key, df_ground( feet ) + ( 0, 0, 1 ), df_model_angles( kind, yaw + 180 ), ... )
while ( $gsc =~ /df_coord_override_ground\(\s*"([A-Z0-9_]+)"\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,\s*(-?[\d.]+)\s*,\s*"([a-z_0-9]+)"\s*\)\s*;/g ) {
    my ( $key, $x, $y, $z, $yawparam, $kind ) = ( $1, $2 + 0, $3 + 0, $4 + 0, $5 + 0, $6 );
    my $pitch = $k_pitch{$kind} // 0; my $roll = $k_roll{$kind} // 0; my $yawoff = $k_yawoff{$kind} // 0;
    $override{$key} = { x => $x, y => $y, z => $z + 1, p => $pitch, yw => $yawparam + 180 + $yawoff, r => $roll };
    $model_of{$key} = $kind;
}

# Pattern F: df_coord_override_ground_front( "KEY", ( pos_x, pos_y, pos_z ), front_yaw, "kind" );
#            df_coord_set( key, df_ground( pos ) + ( 0, 0, 1 ), df_model_angles( kind, front_yaw ), ... )
while ( $gsc =~ /df_coord_override_ground_front\(\s*"([A-Z0-9_]+)"\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,\s*(-?[\d.]+)\s*,\s*"([a-z_0-9]+)"\s*\)\s*;/g ) {
    my ( $key, $x, $y, $z, $front_yaw, $kind ) = ( $1, $2 + 0, $3 + 0, $4 + 0, $5 + 0, $6 );
    my $pitch = $k_pitch{$kind} // 0; my $roll = $k_roll{$kind} // 0; my $yawoff = $k_yawoff{$kind} // 0;
    $override{$key} = { x => $x, y => $y, z => $z + 1, p => $pitch, yw => $front_yaw + $yawoff, r => $roll };
    $model_of{$key} = $kind;
}

# ---- derived-only candidates: wall traces, facing, vanilla-struct lookups (position not known offline
#      unless a literal override above already resolved the same key -- an override always wins). ----------
my %derived_reason;
while ( $gsc =~ /df_coords_on_walls\(\s*"([A-Z0-9_]+)"\s*,\s*(\d+)\s*,/g ) {
    my ( $prefix, $count ) = ( $1, $2 );
    for my $i ( 1 .. $count ) { $derived_reason{"$prefix$i"} = 'wall-trace default (df_coords_on_walls)'; }
}
while ( $gsc =~ /df_coord_set_facing\(\s*"([A-Z0-9_]+)"\s*,/g ) {
    $derived_reason{$1} = 'faces a computed target at run time (df_coord_set_facing)';
}
while ( $gsc =~ /df_coord_on_nearest_wall\(\s*"([A-Z0-9_]+)"\s*,/g ) {
    $derived_reason{$1} = 'wall-trace default (df_coord_on_nearest_wall)';
}
while ( $gsc =~ /df_coords_row_on_wall\(\s*"([A-Z0-9_]+)"\s*,\s*(\d+)\s*,/g ) {
    my ( $prefix, $count ) = ( $1, $2 );
    if ( $count == 1 ) { $derived_reason{$prefix} = 'wall-trace default (df_coords_row_on_wall)'; }
    else { for my $i ( 1 .. $count ) { $derived_reason{"$prefix$i"} = 'wall-trace default (df_coords_row_on_wall)'; } }
}
while ( $gsc =~ /df_coord_from_free_struct\(\s*"([A-Z0-9_]+)"\s*,/g ) {
    $derived_reason{$1} = "vanilla buildable struct lookup, varies per game (df_coord_from_free_struct)";
}
# An override always wins over any derived default: drop a candidate once a literal override resolved it.
for my $k ( keys %override ) { delete $derived_reason{$k}; }

# DF_ORB_SPAWN: df_orb_spawn_sync() unconditionally overwrites it after df_apply_overrides() with a RANDOM
# pick among DF_ORB_SPOT_1/2/3 (df_orb_spawn_for_side, random()) whenever a side locks; the literal default
# parsed above (pattern B) is never what actually ends up live, so force it into "in-game only" instead.
delete $default{DF_ORB_SPAWN};
delete $override{DF_ORB_SPAWN};
$derived_reason{DF_ORB_SPAWN} = 'synced at runtime to a RANDOM pick of DF_ORB_SPOT_1/2/3 (or the locked side'."'".'s tower/diner anchor), df_orb_spawn_sync -- never fixed offline';

sub category {
    my $k = shift;
    return 'tv'     if $k =~ /^DF_TV_/;
    return 'part'   if $k =~ /^DF_PART_/;
    return 'orb'    if $k =~ /^DF_ORB_/;
    return 'table'  if $k eq 'DF_SOCKET' || $k eq 'DF_TABLE';
    return 'signal' if $k =~ /^DF_SIGNAL/;
    return 'coil'   if $k =~ /^DF_COIL/;
    return 'core'   if $k eq 'DF_CORE' || $k eq 'DF_CABIN_HEARTH';
    return 'lamp'   if $k =~ /^DF_LAMP/;
    return 'other';
}

my %seen;
my @anchors;
for my $key ( sort keys %default, sort keys %override ) {
    next if $seen{$key}++;
    my $src = exists $override{$key} ? 'override' : 'default';
    my $c = $override{$key} || $default{$key};
    push @anchors, {
        key => $key, x => rnd( $c->{x} ), y => rnd( $c->{y} ), z => rnd( $c->{z} ),
        p => rnd( $c->{p} ), yw => rnd( $c->{yw} ), r => rnd( $c->{r} ),
        src => $src, cat => category($key), model => $model_of{$key} // '',
    };
}
@anchors = sort { $a->{key} cmp $b->{key} } @anchors;
die "no anchors resolved from $coords_path\n" unless @anchors;

my @derived = map { { key => $_, reason => $derived_reason{$_} } } sort keys %derived_reason;

printf STDERR "ents: %d pathnodes, %d zones, %d windows, %d respawn points, bus %s\n",
    scalar(@pathnodes), scalar(@zones), scalar(@windows), scalar(@respawns), ( $bus ? 'found' : 'not found' );
printf STDERR "df_coords.gsc: %d anchors resolved (%d default, %d override), %d derived (in-game only): %s\n",
    scalar(@anchors), scalar( grep { $_->{src} eq 'default' } @anchors ), scalar( grep { $_->{src} eq 'override' } @anchors ),
    scalar(@derived), join( ', ', map { $_->{key} } @derived );

# =========================================================================================
# 3. Emit the page.
# =========================================================================================
my $json = JSON::PP->new->canonical->utf8(0);

# flat integer pairs keep the pathnode cloud compact (task: "compact integer arrays in a script/json block")
my @pn_flat;
push @pn_flat, $_->[0], -$_->[1] for @pathnodes;      # pre-negate Y here: screen y = -(game y)
my @win_flat;
push @win_flat, $_->[0], -$_->[1] for @windows;
my @rsp_flat;
push @rsp_flat, $_->[0], -$_->[1] for @respawns;
my @zones_out = map { { n => $_->{n}, x => $_->{x}, y => -$_->{y} } } @zones;
my $bus_out = $bus ? { x => $bus->{x}, y => -$bus->{y} } : undef;
my @anchors_out = map {
    { key => $_->{key}, x => $_->{x}, y => -$_->{y}, z => $_->{z}, p => $_->{p}, yw => $_->{yw}, r => $_->{r}, src => $_->{src}, cat => $_->{cat}, model => $_->{model} }
} @anchors;

my $pn_json      = $json->encode( \@pn_flat );
my $win_json     = $json->encode( \@win_flat );
my $rsp_json     = $json->encode( \@rsp_flat );
my $zones_json   = $json->encode( \@zones_out );
my $bus_json     = $json->encode($bus_out);
my $anchors_json = $json->encode( \@anchors_out );
my $derived_json = $json->encode( \@derived );
my $vb_json      = $json->encode( { x => $vb_x, y => $vb_y, w => $vb_w, h => $vb_h } );

my $footer_note = sprintf(
    "%d pathnodes, %d zones, %d windows, %d respawn points%s embedded from tools/assets/zm_transit.d3dbsp.ents.txt; %d anchors (%d default, %d override) and %d in-game-only keys from df_coords.gsc.",
    scalar(@pathnodes), scalar(@zones), scalar(@windows), scalar(@respawns), ( $bus ? ' plus the bus' : '' ),
    scalar(@anchors), scalar( grep { $_->{src} eq 'default' } @anchors ), scalar( grep { $_->{src} eq 'override' } @anchors ),
    scalar(@derived)
);

my $template = <<'HTMLEOF';
<title>Dead Frequency Anchor Map</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;700&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{--bg:#efece6;--panel:#ffffff;--ink:#1b1e23;--muted:#5d6673;--line:#d9d4ca;--accent:#c96f14;--elec:#1f78b8;--good:#3f8f46;--bar:#e6dfd2;--sel:#fff3e4;--canvas:#dcd7cc;
--cat-tv:#1f78b8;--cat-part:#c96f14;--cat-orb:#8e44ad;--cat-table:#3f8f46;--cat-signal:#d6336c;--cat-coil:#c9a227;--cat-core:#c0392b;--cat-lamp:#12a5a5;--cat-other:#5d6673}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419;--canvas:#23272d;
--cat-tv:#4aa8e8;--cat-part:#e5892f;--cat-orb:#b07cd6;--cat-table:#7bc47f;--cat-signal:#f06595;--cat-coil:#e0c04a;--cat-core:#e0645a;--cat-lamp:#3fd0d0;--cat-other:#8d96a3}}
:root[data-theme="dark"]{--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419;--canvas:#23272d;
--cat-tv:#4aa8e8;--cat-part:#e5892f;--cat-orb:#b07cd6;--cat-table:#7bc47f;--cat-signal:#f06595;--cat-coil:#e0c04a;--cat-core:#e0645a;--cat-lamp:#3fd0d0;--cat-other:#8d96a3}
body{background:var(--bg);color:var(--ink);font:15px/1.5 "IBM Plex Sans",system-ui,sans-serif;margin:0}
.wrap{max-width:1600px;margin:0 auto;padding:20px 20px 40px}
.top{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:4px}
.top h1{font:700 34px/1 "Barlow Condensed","Arial Narrow",sans-serif;margin:0;flex:1}
.lede{color:var(--muted);margin:0 0 14px;max-width:110ch}
code{font:500 13px "IBM Plex Mono",monospace}
button{font:600 13px "IBM Plex Sans",sans-serif;cursor:pointer}
.pickbtn{background:var(--accent);color:#fff;border:0;padding:7px 12px}
.ghost{background:transparent;color:var(--ink);border:1px solid var(--line);padding:6px 10px}
.ghost:disabled{opacity:.4;cursor:default}
button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible{outline:2px solid var(--elec);outline-offset:2px}
.layout{display:grid;grid-template-columns:minmax(0,1fr) 340px;gap:16px;align-items:start}
@media (max-width:1000px){.layout{grid-template-columns:1fr}}
.mapcard{background:var(--panel);border:1px solid var(--line)}
.mapbar{display:flex;align-items:center;gap:10px;padding:8px 10px;border-bottom:1px solid var(--line);flex-wrap:wrap}
.mapbar input[type=search]{flex:1;min-width:160px;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:7px 9px;font:13px "IBM Plex Sans",sans-serif}
.corner-note{position:absolute;left:10px;bottom:8px;background:color-mix(in srgb, var(--panel) 82%, transparent);border:1px solid var(--line);padding:4px 8px;font:11px "IBM Plex Mono",monospace;color:var(--muted);pointer-events:none}
.mapwrap{position:relative}
svg#map{display:block;width:100%;height:74vh;background:var(--canvas);cursor:grab}
svg#map.panning{cursor:grabbing}
.legend{display:flex;flex-wrap:wrap;gap:10px 16px;padding:8px 10px;border-top:1px solid var(--line);font:12px "IBM Plex Sans",sans-serif;color:var(--muted)}
.legend .item{display:flex;align-items:center;gap:5px}
.swatch{width:11px;height:11px;border-radius:50%;display:inline-block;flex:none}
.swatch.sq{border-radius:2px}
.legend label{display:flex;align-items:center;gap:5px;cursor:pointer}
.card{background:var(--panel);border:1px solid var(--line);padding:12px 14px}
.eyebrow{font:600 11px "IBM Plex Sans",sans-serif;letter-spacing:.1em;text-transform:uppercase;color:var(--accent);margin:0 0 8px}
.field{display:grid;grid-template-columns:52px 1fr;gap:6px;align-items:center;margin-bottom:6px}
.field label{font:11px "IBM Plex Sans",sans-serif;color:var(--muted);text-transform:uppercase}
.field input{background:var(--panel);color:var(--ink);border:1px solid var(--line);font:13px "IBM Plex Mono",monospace;padding:5px 6px;width:100%;box-sizing:border-box}
.field input:disabled{opacity:.55}
.badgerow{display:flex;gap:6px;align-items:center;margin:8px 0;flex-wrap:wrap}
.badge{font:11px "IBM Plex Sans",sans-serif;padding:2px 7px;border-radius:10px;border:1px solid var(--line)}
.badge.moved{background:var(--sel);border-color:var(--accent);color:var(--accent)}
.badge.src-override{background:var(--bar);color:var(--ink)}
.badge.src-default{background:transparent;color:var(--muted)}
.section-h{font:700 15px "Barlow Condensed",sans-serif;margin:14px 0 4px;text-transform:uppercase;letter-spacing:.04em;color:var(--muted)}
.side .card + .card{margin-top:10px}
.derived-list{max-height:180px;overflow:auto;font:12px "IBM Plex Mono",monospace}
.derived-list .row{padding:4px 0;border-bottom:1px solid var(--line)}
.derived-list .row .k{color:var(--accent)}
.derived-list .row .r{display:block;color:var(--muted);font:11px "IBM Plex Sans",sans-serif;margin-top:1px}
.export textarea{width:100%;box-sizing:border-box;min-height:90px;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:6px;font:12px "IBM Plex Mono",monospace;margin:6px 0}
.hint{font-size:12px;color:var(--muted);margin:0 0 6px}
footer.note{color:var(--muted);font-size:12px;margin-top:20px;border-top:1px solid var(--line);padding-top:10px}
.anchor circle{cursor:grab}
.anchor.dragging circle{cursor:grabbing}
.anchor text{font:6px "IBM Plex Mono",monospace;pointer-events:none;paint-order:stroke;stroke:var(--panel);stroke-width:1.4px}
.anchor .lbl{opacity:0}
.anchor.hot .lbl,.anchor.selected .lbl{opacity:1}
.anchor.selected circle.dot{stroke:var(--elec);stroke-width:14}
.zonelabel{font:34px "IBM Plex Sans",sans-serif;fill:var(--muted);opacity:.65;pointer-events:none}
</style>
<div class="wrap">
<div class="top"><h1>Dead Frequency Anchor Map</h1></div>
<p class="lede">TranZit's own walkable pathnode cloud as the floor plan, every mod anchor as a draggable marker. Drag empty space to pan, wheel to zoom, drag a marker to move it (X/Y only -- Z and angles stay put; <code>!df grab</code> in game sets height against the real floor). Search a key to jump to it, then export <code>df_coord_override(...)</code> lines for every marker you moved.</p>
<div class="layout">

<div class="mapcard">
<div class="mapbar">
<input type="search" id="search" placeholder="Search an anchor key (e.g. DF_SIGNAL, DF_TV_2, DF_BRAZIER_1)">
<button class="ghost" type="button" id="frameAll">Frame all</button>
</div>
<div class="mapwrap">
<svg id="map" xmlns="http://www.w3.org/2000/svg">
  <g id="viewport">
    <path id="pathnodes-layer" fill="none" stroke="#8a8478" stroke-width="26" stroke-linecap="round" opacity="0.55"></path>
    <g id="windows-layer"></g>
    <g id="zones-layer"></g>
    <g id="respawn-layer" style="display:none"></g>
    <g id="bus-layer"></g>
    <g id="anchors-layer"></g>
  </g>
</svg>
<div class="corner-note">Screen up = game +Y &middot; screen right = game +X &middot; grey dots = pathnodes (floor plan) &middot; drag = pan &middot; wheel = zoom</div>
</div>
<div class="legend" id="legend">
<span class="item"><span class="swatch" style="background:var(--cat-tv)"></span>DF_TV_</span>
<span class="item"><span class="swatch" style="background:var(--cat-part)"></span>DF_PART_</span>
<span class="item"><span class="swatch" style="background:var(--cat-orb)"></span>DF_ORB_</span>
<span class="item"><span class="swatch" style="background:var(--cat-table)"></span>DF_SOCKET / DF_TABLE</span>
<span class="item"><span class="swatch" style="background:var(--cat-signal)"></span>DF_SIGNAL*</span>
<span class="item"><span class="swatch" style="background:var(--cat-coil)"></span>DF_COIL*</span>
<span class="item"><span class="swatch" style="background:var(--cat-core)"></span>DF_CORE / DF_CABIN_HEARTH</span>
<span class="item"><span class="swatch" style="background:var(--cat-lamp)"></span>DF_LAMP*</span>
<span class="item"><span class="swatch" style="background:var(--cat-other)"></span>other</span>
<span class="item"><span class="swatch sq" style="background:#c0392b"></span>window (zbarrier_*)</span>
<span class="item"><span class="swatch" style="background:#2a6f3d;border-radius:2px"></span>the bus</span>
<span class="item"><label><input type="checkbox" id="toggleRespawn"> respawn points (29)</label></span>
</div>
</div>

<div class="side">
<div class="card" id="selCard">
<p class="eyebrow">Selected anchor</p>
<p class="hint" id="selKey">none selected -- click a marker or search a key</p>
<div class="badgerow" id="selBadges"></div>
<div class="field"><label>X</label><input type="number" step="1" id="fX" disabled></div>
<div class="field"><label>Y</label><input type="number" step="1" id="fY" disabled></div>
<div class="field"><label>Z</label><input type="number" step="1" id="fZ" disabled></div>
<div class="field"><label>Yaw</label><input type="number" step="1" id="fYw" disabled></div>
<button class="ghost" type="button" id="resetBtn" disabled>Reset to source</button>
</div>

<div class="card">
<p class="eyebrow">In-game only (<span id="derivedCount">0</span>)</p>
<p class="hint">Position derived at run time (wall trace, facing, a random pick, or a vanilla buildable lookup) -- not plotted. Use <code>!df grab &lt;KEY&gt;</code> in game, then paste the printed line into the Import box below.</p>
<div class="derived-list" id="derivedList"></div>
</div>

<div class="card export">
<p class="eyebrow">Export -- moved anchors only</p>
<textarea id="expMoved" readonly></textarea>
<button class="ghost" type="button" id="copyMoved">Copy</button>
</div>

<div class="card export">
<p class="eyebrow">Export -- all anchors</p>
<textarea id="expAll" readonly></textarea>
<button class="ghost" type="button" id="copyAll">Copy</button>
</div>

<div class="card export">
<p class="eyebrow">Import</p>
<p class="hint">One per line: <code>[SPOT] KEY | x y z | p y r | model</code> or <code>df_coord_override( "KEY", ( x, y, z ), ( p, y, r ) );</code></p>
<textarea id="importIn" placeholder="[SPOT] DF_SIGNAL | -6244 5361 -187 | 0 88 0 | -"></textarea>
<button class="ghost" type="button" id="importBtn">Import</button>
</div>
</div>

</div>
<footer class="note">__FOOTER__</footer>
</div>
<script type="application/json" id="data-pathnodes">__PN_JSON__</script>
<script type="application/json" id="data-windows">__WIN_JSON__</script>
<script type="application/json" id="data-respawns">__RSP_JSON__</script>
<script type="application/json" id="data-zones">__ZONES_JSON__</script>
<script type="application/json" id="data-bus">__BUS_JSON__</script>
<script type="application/json" id="data-anchors">__ANCHORS_JSON__</script>
<script type="application/json" id="data-derived">__DERIVED_JSON__</script>
<script type="application/json" id="data-viewbox">__VB_JSON__</script>
<script>
(function(){
  var STORE_KEY = 'df_anchor_map_transit_v1';
  var NS = 'http://www.w3.org/2000/svg';

  function readJSON(id){ return JSON.parse(document.getElementById(id).textContent); }
  var pnFlat   = readJSON('data-pathnodes');
  var winFlat  = readJSON('data-windows');
  var rspFlat  = readJSON('data-respawns');
  var zones    = readJSON('data-zones');
  var bus      = readJSON('data-bus');
  var srcAnchors = readJSON('data-anchors');
  var derived  = readJSON('data-derived');
  var vb0      = readJSON('data-viewbox');

  // ---------- anchor state: keep GAME units (x, gameY) throughout; svg y = -gameY at render time ----------
  var anchors = srcAnchors.map(function(a){
    return {
      key: a.key, x: a.x, y: -a.y, z: a.z, p: a.p, yw: a.yw, r: a.r,
      origX: a.x, origY: -a.y, origZ: a.z, origYw: a.yw,
      src: a.src, cat: a.cat, model: a.model, hasSource: true
    };
  });
  var byKey = {};
  anchors.forEach(function(a){ byKey[a.key] = a; });

  function loadStore(){ try{ return JSON.parse(localStorage.getItem(STORE_KEY) || 'null'); }catch(e){ return null; } }
  function saveStore(){
    try{
      var out = {};
      anchors.forEach(function(a){
        if (!a.hasSource || a.x !== a.origX || a.y !== a.origY || a.z !== a.origZ || a.yw !== a.origYw) {
          out[a.key] = { x:a.x, y:a.y, z:a.z, yw:a.yw, p:a.p, r:a.r, cat:a.cat, hasSource:a.hasSource };
        }
      });
      localStorage.setItem(STORE_KEY, JSON.stringify(out));
    }catch(e){}
  }
  (function applyStore(){
    var st = loadStore();
    if (!st) return;
    Object.keys(st).forEach(function(k){
      var rec = st[k];
      if (byKey[k]) {
        byKey[k].x = rec.x; byKey[k].y = rec.y; byKey[k].z = rec.z; byKey[k].yw = rec.yw;
        if (typeof rec.p === 'number') byKey[k].p = rec.p;
        if (typeof rec.r === 'number') byKey[k].r = rec.r;
      } else if (!rec.hasSource) {
        var na = { key:k, x:rec.x, y:rec.y, z:rec.z, p:rec.p||0, yw:rec.yw, r:rec.r||0,
                   origX:rec.x, origY:rec.y, origZ:rec.z, origYw:rec.yw,
                   src:'imported', cat:rec.cat||'other', model:'', hasSource:false };
        anchors.push(na); byKey[k] = na;
      }
    });
  })();

  // ---------- svg setup ----------
  var svg = document.getElementById('map');
  var viewport = document.getElementById('viewport');
  var vb = { x: vb0.x, y: vb0.y, w: vb0.w, h: vb0.h };
  var vbInit = { x: vb0.x, y: vb0.y, w: vb0.w, h: vb0.h };
  function applyVB(){ svg.setAttribute('viewBox', vb.x + ' ' + vb.y + ' ' + vb.w + ' ' + vb.h); }
  applyVB();

  function clientToUser(cx, cy){
    var rect = svg.getBoundingClientRect();
    var ux = vb.x + ( cx - rect.left ) / rect.width * vb.w;
    var uy = vb.y + ( cy - rect.top ) / rect.height * vb.h;
    return [ux, uy];
  }

  // pathnodes: one path, many zero-length "dot" subpaths (round linecap draws each as a circle)
  var pnD = '';
  for (var i = 0; i < pnFlat.length; i += 2) { pnD += 'M' + pnFlat[i] + ' ' + pnFlat[i+1] + 'l0 0'; }
  document.getElementById('pathnodes-layer').setAttribute('d', pnD);

  var winLayer = document.getElementById('windows-layer');
  for (var i = 0; i < winFlat.length; i += 2) {
    var r = document.createElementNS(NS, 'rect');
    r.setAttribute('x', winFlat[i] - 30); r.setAttribute('y', winFlat[i+1] - 30);
    r.setAttribute('width', 60); r.setAttribute('height', 60);
    r.setAttribute('fill', '#c0392b'); r.setAttribute('opacity', '0.55');
    winLayer.appendChild(r);
  }

  var zoneLayer = document.getElementById('zones-layer');
  zones.forEach(function(z){
    var t = document.createElementNS(NS, 'text');
    t.setAttribute('x', z.x); t.setAttribute('y', z.y);
    t.setAttribute('text-anchor', 'middle');
    t.setAttribute('class', 'zonelabel');
    t.textContent = z.n;
    zoneLayer.appendChild(t);
    var c = document.createElementNS(NS, 'circle');
    c.setAttribute('cx', z.x); c.setAttribute('cy', z.y); c.setAttribute('r', 22);
    c.setAttribute('fill', 'none'); c.setAttribute('stroke', 'var(--muted)'); c.setAttribute('opacity', '0.5');
    zoneLayer.appendChild(c);
  });

  var rspLayer = document.getElementById('respawn-layer');
  for (var i = 0; i < rspFlat.length; i += 2) {
    var c = document.createElementNS(NS, 'circle');
    c.setAttribute('cx', rspFlat[i]); c.setAttribute('cy', rspFlat[i+1]); c.setAttribute('r', 24);
    c.setAttribute('fill', '#2a6f3d'); c.setAttribute('opacity', '0.5');
    rspLayer.appendChild(c);
  }
  document.getElementById('toggleRespawn').addEventListener('change', function(){
    rspLayer.style.display = this.checked ? '' : 'none';
  });

  if (bus) {
    var busLayer = document.getElementById('bus-layer');
    var b = document.createElementNS(NS, 'rect');
    b.setAttribute('x', bus.x - 60); b.setAttribute('y', bus.y - 32);
    b.setAttribute('width', 120); b.setAttribute('height', 64);
    b.setAttribute('fill', '#2a6f3d'); b.setAttribute('opacity', '0.85'); b.setAttribute('rx', 6);
    busLayer.appendChild(b);
    var bt = document.createElementNS(NS, 'text');
    bt.setAttribute('x', bus.x); bt.setAttribute('y', bus.y - 40);
    bt.setAttribute('text-anchor', 'middle'); bt.setAttribute('class', 'zonelabel');
    bt.setAttribute('font-size', '30'); bt.textContent = 'the_bus';
    busLayer.appendChild(bt);
  }

  // ---------- anchor markers ----------
  var anchorLayer = document.getElementById('anchors-layer');
  var selectedKey = null;
  var elByKey = {};

  function anchorColor(cat){ return 'var(--cat-' + (cat || 'other') + ')'; }

  function buildMarker(a){
    var g = document.createElementNS(NS, 'g');
    g.setAttribute('class', 'anchor');
    g.dataset.key = a.key;
    g.setAttribute('transform', 'translate(' + a.x + ',' + (-a.y) + ')');
    var dot = document.createElementNS(NS, 'circle');
    dot.setAttribute('class', 'dot');
    dot.setAttribute('r', 42);
    dot.setAttribute('fill', anchorColor(a.cat));
    dot.setAttribute('stroke', 'var(--panel)');
    dot.setAttribute('stroke-width', '6');
    g.appendChild(dot);
    var lbl = document.createElementNS(NS, 'g');
    lbl.setAttribute('class', 'lbl');
    var lblBg = document.createElementNS(NS, 'rect');
    lblBg.setAttribute('x', 50); lblBg.setAttribute('y', -14); lblBg.setAttribute('height', 28);
    lblBg.setAttribute('fill', 'var(--panel)'); lblBg.setAttribute('opacity', '0.85');
    var lblT = document.createElementNS(NS, 'text');
    lblT.setAttribute('x', 56); lblT.setAttribute('y', 6);
    lblT.setAttribute('font-size', '30'); lblT.setAttribute('fill', 'var(--ink)');
    lblT.textContent = a.key;
    lbl.appendChild(lblBg); lbl.appendChild(lblT);
    g.appendChild(lbl);
    // size the label background to the text after it's in the DOM
    requestAnimationFrame(function(){ try{ var bb = lblT.getBBox(); lblBg.setAttribute('width', bb.width + 12); }catch(e){} });
    g.addEventListener('mouseenter', function(){ g.classList.add('hot'); });
    g.addEventListener('mouseleave', function(){ g.classList.remove('hot'); });
    anchorLayer.appendChild(g);
    elByKey[a.key] = g;
    g.addEventListener('mousedown', function(ev){ startDrag(ev, a); });
    return g;
  }
  anchors.forEach(buildMarker);

  // ---------- pan (drag empty space) ----------
  var panning = false, panLast = null;
  svg.addEventListener('mousedown', function(ev){
    if (ev.target.closest && ev.target.closest('.anchor')) return;
    panning = true; panLast = clientToUser(ev.clientX, ev.clientY);
    svg.classList.add('panning');
  });
  window.addEventListener('mousemove', function(ev){
    if (!panning) return;
    var cur = clientToUser(ev.clientX, ev.clientY);
    vb.x -= (cur[0] - panLast[0]); vb.y -= (cur[1] - panLast[1]);
    applyVB();
    panLast = clientToUser(ev.clientX, ev.clientY);
  });
  window.addEventListener('mouseup', function(){ panning = false; svg.classList.remove('panning'); });

  // ---------- zoom (wheel) ----------
  svg.addEventListener('wheel', function(ev){
    ev.preventDefault();
    var factor = ev.deltaY < 0 ? 0.88 : 1.136;
    var p = clientToUser(ev.clientX, ev.clientY);
    var nw = vb.w * factor, nh = vb.h * factor;
    if (nw < 300 || nw > vbInit.w * 6) return;
    vb.x = p[0] - (p[0] - vb.x) * (nw / vb.w);
    vb.y = p[1] - (p[1] - vb.y) * (nh / vb.h);
    vb.w = nw; vb.h = nh;
    applyVB();
  }, { passive: false });

  document.getElementById('frameAll').addEventListener('click', function(){
    vb.x = vbInit.x; vb.y = vbInit.y; vb.w = vbInit.w; vb.h = vbInit.h; applyVB();
  });

  // ---------- drag a marker (X/Y only) ----------
  var dragging = null;
  function startDrag(ev, a){
    ev.stopPropagation();
    ev.preventDefault();
    dragging = a;
    elByKey[a.key].classList.add('dragging');
    selectAnchor(a.key);
  }
  window.addEventListener('mousemove', function(ev){
    if (!dragging) return;
    var p = clientToUser(ev.clientX, ev.clientY);
    dragging.x = Math.round(p[0]);
    dragging.y = Math.round(-p[1]);
    var g = elByKey[dragging.key];
    g.setAttribute('transform', 'translate(' + dragging.x + ',' + (-dragging.y) + ')');
    updateSelPanel();
  });
  window.addEventListener('mouseup', function(){
    if (dragging) {
      elByKey[dragging.key].classList.remove('dragging');
      refreshBadges(dragging.key);
      saveStore();
      updateExports();
      dragging = null;
    }
  });

  // ---------- selection + numeric panel ----------
  function selectAnchor(key){
    if (selectedKey && elByKey[selectedKey]) elByKey[selectedKey].classList.remove('selected');
    selectedKey = key;
    if (elByKey[key]) elByKey[key].classList.add('selected');
    updateSelPanel();
  }
  var fX = document.getElementById('fX'), fY = document.getElementById('fY'),
      fZ = document.getElementById('fZ'), fYw = document.getElementById('fYw'),
      selKey = document.getElementById('selKey'), selBadges = document.getElementById('selBadges'),
      resetBtn = document.getElementById('resetBtn');

  function moved(a){ return !a.hasSource || a.x !== a.origX || a.y !== a.origY || a.z !== a.origZ || a.yw !== a.origYw; }

  function updateSelPanel(){
    var a = selectedKey ? byKey[selectedKey] : null;
    [fX, fY, fZ, fYw].forEach(function(f){ f.disabled = !a; });
    resetBtn.disabled = !a || !a.hasSource;
    if (!a) { selKey.textContent = 'none selected -- click a marker or search a key'; selBadges.innerHTML = ''; [fX,fY,fZ,fYw].forEach(function(f){ f.value = ''; }); return; }
    selKey.textContent = a.key + (a.model ? ' (' + a.model + ')' : '');
    fX.value = a.x; fY.value = a.y; fZ.value = a.z; fYw.value = a.yw;
    var html = '<span class="badge src-' + a.src + '">' + a.src + '</span>';
    if (moved(a)) html += '<span class="badge moved">moved</span>';
    selBadges.innerHTML = html;
  }
  function refreshBadges(key){ if (key === selectedKey) updateSelPanel(); }

  [ [fX,'x'], [fY,'y'], [fZ,'z'], [fYw,'yw'] ].forEach(function(pair){
    var el = pair[0], field = pair[1];
    el.addEventListener('change', function(){
      if (!selectedKey) return;
      var a = byKey[selectedKey];
      var v = parseFloat(el.value);
      if (isNaN(v)) v = a[field];
      a[field] = Math.round(v);
      var g = elByKey[a.key];
      g.setAttribute('transform', 'translate(' + a.x + ',' + (-a.y) + ')');
      updateSelPanel(); saveStore(); updateExports();
    });
  });
  resetBtn.addEventListener('click', function(){
    if (!selectedKey) return;
    var a = byKey[selectedKey];
    if (!a.hasSource) return;
    a.x = a.origX; a.y = a.origY; a.z = a.origZ; a.yw = a.origYw;
    var g = elByKey[a.key];
    g.setAttribute('transform', 'translate(' + a.x + ',' + (-a.y) + ')');
    updateSelPanel(); saveStore(); updateExports();
  });

  anchorLayer.addEventListener('click', function(ev){
    var g = ev.target.closest ? ev.target.closest('.anchor') : null;
    if (g) selectAnchor(g.dataset.key);
  });

  // ---------- search ----------
  document.getElementById('search').addEventListener('keydown', function(ev){
    if (ev.key !== 'Enter') return;
    var q = this.value.trim().toUpperCase();
    if (!q) return;
    var hit = anchors.find(function(a){ return a.key === q; }) ||
              anchors.find(function(a){ return a.key.indexOf(q) >= 0; });
    if (!hit) return;
    selectAnchor(hit.key);
    var half = Math.min(vbInit.w, vbInit.h) * 0.12;
    vb.w = half * 2; vb.h = half * 2 * (vbInit.h / vbInit.w);
    vb.x = hit.x - vb.w / 2; vb.y = -hit.y - vb.h / 2;
    applyVB();
  });

  // ---------- in-game-only side panel ----------
  document.getElementById('derivedCount').textContent = derived.length;
  document.getElementById('derivedList').innerHTML = derived.map(function(d){
    return '<div class="row"><span class="k">' + d.key + '</span><span class="r">' + d.reason + '</span></div>';
  }).join('') || '<p class="hint">none</p>';

  // ---------- export ----------
  function fmtLine(a){
    return 'df_coord_override( "' + a.key + '", ( ' + a.x + ', ' + a.y + ', ' + a.z + ' ), ( ' + a.p + ', ' + a.yw + ', ' + a.r + ' ) );';
  }
  function updateExports(){
    var sorted = anchors.slice().sort(function(a,b){ return a.key < b.key ? -1 : a.key > b.key ? 1 : 0; });
    document.getElementById('expMoved').value = sorted.filter(moved).map(fmtLine).join('\n');
    document.getElementById('expAll').value = sorted.map(fmtLine).join('\n');
  }
  updateExports();

  function copyText(t, btn){
    function done(){ var old = btn.textContent; btn.textContent = 'Copied'; setTimeout(function(){ btn.textContent = old; }, 1200); }
    if (navigator.clipboard) navigator.clipboard.writeText(t).then(done, function(){ prompt('Copy this:', t); });
    else prompt('Copy this:', t);
  }
  document.getElementById('copyMoved').addEventListener('click', function(){ copyText(document.getElementById('expMoved').value, this); });
  document.getElementById('copyAll').addEventListener('click', function(){ copyText(document.getElementById('expAll').value, this); });

  // ---------- import ----------
  var reSpot = /^\[SPOT\]\s*(\S+)\s*\|\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\|\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)/;
  var reOverride = /df_coord_override\(\s*"([^"]+)"\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*\)/;
  document.getElementById('importBtn').addEventListener('click', function(){
    var lines = document.getElementById('importIn').value.split('\n').map(function(l){ return l.trim(); }).filter(Boolean);
    var count = 0;
    lines.forEach(function(line){
      var m = reSpot.exec(line) || reOverride.exec(line);
      if (!m) return;
      var key = m[1], x = Math.round(+m[2]), y = Math.round(+m[3]), z = Math.round(+m[4]),
          p = Math.round(+m[5]), yw = Math.round(+m[6]), r = Math.round(+m[7]);
      var a = byKey[key];
      if (a) {
        a.x = x; a.y = y; a.z = z; a.p = p; a.yw = yw; a.r = r;
      } else {
        a = { key: key, x: x, y: y, z: z, p: p, yw: yw, r: r,
              origX: x, origY: y, origZ: z, origYw: yw, src: 'imported', cat: 'other', model: '', hasSource: false };
        anchors.push(a); byKey[key] = a;
        buildMarker(a);
      }
      var g = elByKey[key];
      if (g) g.setAttribute('transform', 'translate(' + a.x + ',' + (-a.y) + ')');
      count++;
    });
    if (count) { saveStore(); updateExports(); if (selectedKey) updateSelPanel(); }
  });

  updateExports();
})();
</script>
HTMLEOF

$template =~ s/\Q__FOOTER__\E/$footer_note/;
$template =~ s/\Q__PN_JSON__\E/$pn_json/;
$template =~ s/\Q__WIN_JSON__\E/$win_json/;
$template =~ s/\Q__RSP_JSON__\E/$rsp_json/;
$template =~ s/\Q__ZONES_JSON__\E/$zones_json/;
$template =~ s/\Q__BUS_JSON__\E/$bus_json/;
$template =~ s/\Q__ANCHORS_JSON__\E/$anchors_json/;
$template =~ s/\Q__DERIVED_JSON__\E/$derived_json/;
$template =~ s/\Q__VB_JSON__\E/$vb_json/;

print $template;
