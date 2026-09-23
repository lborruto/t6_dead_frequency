use strict;
use warnings;
use FindBin;
use JSON::PP ();

# gen_composer_transit.pl > composer_transit.html : "Dead Frequency Prop Composer" -- pick TranZit models,
# stack several of them into an assembly, position each part precisely in a three.js viewer, and export
# ready-to-paste df_model_def(...) GSC. Reuses the viewer / model-loading / list-and-search / styling of
# tools/pickers/gen_wizard_mdl.pl (this mod's Prop Picker) and the texture-stripped parse + [vN] diagnostic
# line of the Magmagat Prop Picker (t6_motd_magmagat/tools/pickers/gen_mdl_motd.pl, functions mgStrip/mgDiag).
#
# Reads the OpenAssetTools glTF viewer dump (model_dump/viewer/<zone>/*.gltf + SIZES.txt) for the same four
# always-loaded zones the Prop Picker uses, and df_coords.gsc (df_models_init / df_model_def /
# df_table_slots_init / df_table_slot_def / df_fx_points_init / df_fx_point_def) for the preset assemblies'
# exact offsets. Nothing here writes to df_coords.gsc or any other repo file; it only reads them to build the
# static HTML page.
#
# Every effect / sound attach point df_fx_points_init() registers is drawn as a named cross (a dot for sounds,
# name containing "snd" or "hum") next to its parent prop: a third kind of "part" (ptype "fx") alongside the
# df_model_def model parts, attached to a parent part by KIND so it follows that part's position and yaw. The
# panel edits its offset in the PARENT's own frame (undoing the parent's yaw, same convention df_model_offset_at
# uses); export writes df_fx_point_def(...) lines the same way, minus the point's "base" (the parent's glTF top
# bound for a "TOP of prop" / "RIM of the prop" point, or another point's own resolved offset for a "base is
# fuse_led" / "on top of relay_array_node" point) so the line matches the registry's own convention exactly.

my $viewer = $ENV{DF_MODEL_VIEWER} // 'C:/Games/t6/model_dump/viewer';

# df_coords.gsc lives two directories up from this script's eventual home (tools/pickers/); DF_ROOT lets it
# be overridden (e.g. while this script still sits in a scratch folder rather than tools/pickers/).
my $DF_ROOT = $ENV{DF_ROOT} // "$FindBin::Bin/../..";
my $coords  = "$DF_ROOT/df_coords.gsc";
die "df_coords.gsc not found (looked at $coords)\n" unless -f $coords;

# ---- SIZES.txt (model -> zone/w/h/d), same parse as gen_wizard_mdl.pl ----------------------------------
my %dims;
open my $sz, '<', "$viewer/SIZES.txt" or die "$viewer/SIZES.txt: $!";
while (<$sz>) {
    next if /^#/;
    if (/^(\S+)\s+(\S+)\s+w\s+(\d+)\s+h\s+(\d+)\s+d\s+(\d+)/) { $dims{$1} = { zone => $2, w => $3, h => $4, d => $5 } }
}
close $sz;

# ---- collect candidate models from the four always-loaded zones, same filters as gen_wizard_mdl.pl -----
my @models;
for my $zone ( 'zm_transit', 'so_zclassic_zm_transit', 'common_zm', 'patch_zm' ) {
    next unless -d "$viewer/$zone";
    opendir my $dh, "$viewer/$zone" or die "$viewer/$zone: $!";
    for my $f ( sort readdir $dh ) {
        next unless $f =~ /^(.+)\.gltf$/;
        my $name = $1;
        next if $name =~ /^(c_|t6_|veh_|fx_|weapon_|tag_|skybox|world|projectile|fxanim|defaultvehicle)/;
        my $path = "$viewer/$zone/$f";
        my $size = -s $path;
        next if $size > 420_000;
        open my $fh, '<:raw', $path or die "$path: $!";
        local $/;
        my $json = <$fh>;
        close $fh;
        $json =~ s{</script}{<\\/script}gi;
        my $d = $dims{$name} || { w => 0, h => 0, d => 0 };
        push @models, { name => $name, zone => $zone, json => $json, w => $d->{w}, h => $d->{h}, d => $d->{d}, size => $size };
    }
    closedir $dh;
}
@models = sort { $a->{name} cmp $b->{name} } @models;

# ---- parse df_coords.gsc: df_model_def( kind, name, pitch, roll, yawoff [, ( x, y, z ) ] ); and
#      the slot registry df_table_slot_def( n, ( x, y, z ) ); -- these feed the preset assemblies below. ----
open my $cf, '<', $coords or die "$coords: $!";
local $/;
my $gsc = <$cf>;
close $cf;

my %model_def;    # kind -> { name, pitch, roll, yawoff, ox, oy, oz }
while ( $gsc =~ /df_model_def\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*(?:,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*)?\)\s*;/g ) {
    $model_def{$1} = { name => $2, pitch => $3 + 0, roll => $4 + 0, yawoff => $5 + 0, ox => ( $6 // 0 ) + 0, oy => ( $7 // 0 ) + 0, oz => ( $8 // 0 ) + 0 };
}
die "df_models_init(): no df_model_def(...) lines found in $coords\n" unless %model_def;

# ---- parse df_fx_points_init(): df_fx_point_def( "name", "parent_kind", ( x, y, z ) ); one line per effect /
#      sound attach point, with a trailing "//" comment giving its base rule ("TOP of prop", "RIM of the
#      prop", "base: fuse_led", "multiplied by ...", or nothing -- parent origin + offset). This is the one
#      registry df_fx_points_init() documents; the composer draws every point it finds here. -----------------
my %fx_def;   # name -> { parent, x, y, z, rule }
my @fx_order;
while ( $gsc =~ /df_fx_point_def\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*\)\s*;[ \t]*(\/\/[^\n]*)?/g ) {
    my ( $name, $parent, $x, $y, $z, $comment ) = ( $1, $2, $3 + 0, $4 + 0, $5 + 0, $6 // '' );
    $comment =~ s{^//\s*}{};
    $comment =~ s/\s+$//;
    die "df_fx_points_init(): duplicate df_fx_point_def(...) for \"$name\" in $coords\n" if $fx_def{$name};
    $fx_def{$name} = { parent => $parent, x => $x, y => $y, z => $z, rule => $comment };
    push @fx_order, $name;
}
die "df_fx_points_init(): no df_fx_point_def(...) lines found in $coords\n" unless %fx_def;
die sprintf( "df_fx_points_init(): no df_fx_point_def(...) lines found in $coords\n" ) unless @fx_order;

# ---- parse df_table_slots_init(): df_table_slot_def( n, ( x, y, z ) ); the three deposit slots of the table
#      in the TABLE's own frame, z measured from the table TOP (df_model_top_z("table")). This is the owner's
#      own layout since 2026-09-22 (it replaced the old "three slots 18 apart" rule), so the presets below draw
#      exactly what the game does and the page exports these very lines back. -------------------------------
my %slot_def;   # n -> [ x, y, z ]
while ( $gsc =~ /df_table_slot_def\(\s*(\d+)\s*,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*\)\s*;/g ) {
    $slot_def{ $1 + 0 } = [ $2 + 0, $3 + 0, $4 + 0 ];
}
for my $n ( 0, 1, 2 ) {
    die "df_table_slots_init(): no df_table_slot_def( $n, ( x, y, z ) ); line found in $coords\n" unless $slot_def{$n};
}

# df_model_top_z()'s "tops" lookup and df_model_rest_z()'s "rest" lookup (both keyed by MODEL NAME, not kind)
# -- read here the same way df_model_def(...) is, so the table presets' slot Z, the card/skull/orb lift, and
# the "TOP of prop" / "RIM of the prop" fx bases stay correct if the table/tv/brazier models are ever swapped.
my %top_z_by_model;
while ( $gsc =~ /tops\[\s*"([^"]+)"\s*\]\s*=\s*(-?[\d.]+)\s*;/g ) {
    $top_z_by_model{$1} = $2 + 0;
}
my %rest_z_by_model;
while ( $gsc =~ /rest\[\s*"([^"]+)"\s*\]\s*=\s*(-?[\d.]+)\s*;/g ) {
    $rest_z_by_model{$1} = $2 + 0;
}
# DF_TABLE's own front yaw (df_apply_overrides' df_coord_override_ground_front( "DF_TABLE", ..., front_yaw, "table" )).
my ($table_front_yaw) = $gsc =~ /df_coord_override_ground_front\(\s*"DF_TABLE"\s*,\s*\([^)]*\)\s*,\s*(-?[\d.]+)\s*,\s*"table"\s*\)/;
$table_front_yaw = defined($table_front_yaw) ? $table_front_yaw + 0 : 0;
# The card / skull / orb lifts are gone from the callers: each item's own lift is the z of its slot in the
# registry above (df_table_slot( n ) returns the item's FINAL rest position).

for my $kind (qw(relay relay_top relay_coil relay_mast table brazier ember card skull orb tv fuse receiver part_a portal spool)) {
    die "df_model_def for kind \"$kind\" not found in $coords -- needed for a preset\n" unless $model_def{$kind};
}

my $table_top_z = $top_z_by_model{ $model_def{table}{name} };
die "df_model_top_z: no tops[] entry for table model \"$model_def{table}{name}\" in $coords -- needed for the table presets\n"
    unless defined $table_top_z;
my $tv_top_z = $top_z_by_model{ $model_def{tv}{name} };
die "df_model_top_z: no tops[] entry for tv model \"$model_def{tv}{name}\" in $coords -- needed for the pipe_glow base\n"
    unless defined $tv_top_z;
my $brazier_top_z = $top_z_by_model{ $model_def{brazier}{name} };
die "df_model_top_z: no tops[] entry for brazier model \"$model_def{brazier}{name}\" in $coords -- needed for the brazier rim base\n"
    unless defined $brazier_top_z;
# The RIM the two brazier fire points hang on is NOT the model's top bound in every case: df_m2_rim_height()
# in df_act2_maxis.gsc returns 2 for any model whose name contains "tombstone" (owner 2026-09-11: the grave
# burns from its base, the flame used to start at the top), and only otherwise the registry top. Mirror that
# rule here, or the page draws the fire and the ash against a base the game never uses.
my $brazier_rim_z = ( $model_def{brazier}{name} =~ /tombstone/ ) ? 2 : $brazier_top_z;

my $orb_rest   = $rest_z_by_model{ $model_def{orb}{name} }   // 0;
my $skull_rest = $rest_z_by_model{ $model_def{skull}{name} } // 0;

printf STDERR "df_coords.gsc: relay=%s relay_coil=%s(%s,%s,%s) relay_mast=%s(%s,%s,%s) relay_top=%s(%s,%s,%s) brazier=%s(rim %s) ember=%s\n",
    $model_def{relay}{name}, $model_def{relay_coil}{name}, $model_def{relay_coil}{ox}, $model_def{relay_coil}{oy}, $model_def{relay_coil}{oz},
    $model_def{relay_mast}{name}, $model_def{relay_mast}{ox}, $model_def{relay_mast}{oy}, $model_def{relay_mast}{oz},
    $model_def{relay_top}{name}, $model_def{relay_top}{ox}, $model_def{relay_top}{oy}, $model_def{relay_top}{oz},
    $model_def{brazier}{name}, $brazier_rim_z, $model_def{ember}{name};
printf STDERR "df_coords.gsc: table=%s top_z=%s front_yaw=%s card=%s(pitch %s) skull=%s(rest %s) orb=%s(rest %s) tv=%s(top %s)\n",
    $model_def{table}{name}, $table_top_z, $table_front_yaw, $model_def{card}{name}, $model_def{card}{pitch},
    $model_def{skull}{name}, $skull_rest, $model_def{orb}{name}, $orb_rest, $model_def{tv}{name}, $tv_top_z;
printf STDERR "df_coords.gsc: table slots (df_table_slot_def, z from the top %s): %s\n", $table_top_z,
    join( ' | ', map { sprintf '%d = ( %s, %s, %s )', $_, @{ $slot_def{$_} } } ( 0, 1, 2 ) );
printf STDERR "df_coords.gsc: %d df_fx_point_def(...) points parsed from df_fx_points_init()\n", scalar @fx_order;

# The preset's own models must be embedded no matter what the size budget below does to the general list.
my %required = map { $model_def{$_}{name} => 1 } qw(relay relay_coil relay_mast relay_top table brazier ember card skull orb tv fuse receiver part_a portal spool);

# ---- 16 MB page budget: if the embedded glTF payload would push the page over it, drop the largest
#      glTF files first (never a model any preset needs) and remember how many were dropped. -------------
my $BUDGET = 15_500_000;                                                       # leaves headroom for the HTML/CSS/JS chrome
my $total  = 0;
$total += $_->{size} for @models;
my $dropped = 0;
if ( $total > $BUDGET ) {
    my @droppable = sort { $b->{size} <=> $a->{size} } grep { !$required{ $_->{name} } } @models;
    while ( $total > $BUDGET && @droppable ) {
        my $victim = shift @droppable;
        @models = grep { $_->{name} ne $victim->{name} } @models;
        $total -= $victim->{size};
        $dropped++;
    }
}
@models = sort { $a->{name} cmp $b->{name} } @models;
my $count = scalar @models;
printf STDERR "%d models embedded (%.2f MB of glTF), %d dropped for the 16 MB budget\n", $count, $total / 1024 / 1024, $dropped;

# ---- HTML fragments ---------------------------------------------------------------------------------
my $list = '';
for my $m (@models) {
    $list .= qq~<li class="mrow" data-name="$m->{name}"><code>$m->{name}</code><span class="dims">$m->{w} x $m->{h} x $m->{d}</span><span class="zone">$m->{zone}</span></li>\n~;
}
my $scripts = join( '', map { qq~<script type="application/json" data-model="$_->{name}">$_->{json}</script>\n~ } @models );

# ---- preset assemblies, as data for the page's PRESETS object -----------------------------------------
# "table" and "tombstone" presets need the base model's own top bound (df_model_top_z equivalent), which is
# only knowable from the glTF mesh bounds for a live-swapped model, so those parts carry snapTop:1 and the
# page resolves their Z at load time from the base model's live bounds (mirrors df_model_top_z / df_m2_rim_height
# in df_coords.gsc / df_act2_maxis.gsc, which likewise derive it from the measured glTF bounds when a catalog
# swap is in play). The fx crosses' own "TOP of prop" / "RIM of the prop" bases, by contrast, are resolved HERE,
# numerically, from the exact same tops[] dict df_model_top_z() itself reads (parsed above into %top_z_by_model),
# since df_fx_points_init() documents them against that same static registry, not a live re-measurement.
#
# Rotates an (x,y,z) stacking offset by a yaw in degrees -- the same 2D rotation df_offset_rotate() in
# df_coords.gsc applies (via df_model_offset_at / df_fx_point_at) to a piece's registered offset when its
# parent is turned.
sub df_rotate_offset {
    my ( $ox, $oy, $oz, $yaw_deg ) = @_;
    my $rad = $yaw_deg * 3.14159265358979323846 / 180;
    my $c   = cos($rad);
    my $s   = sin($rad);
    return ( $ox * $c - $oy * $s, $ox * $s + $oy * $c, $oz );
}
sub r2 { my $n = shift; return int( $n * 100 + ( $n >= 0 ? 0.5 : -0.5 ) ) / 100; }

# ---- fx point helper: builds one "ptype":"fx" part for the PRESETS data. name must be a df_fx_point_def(...)
#      name; parent overrides the registry's own parent_kind (only used for aliasing, never needed in practice
#      since every preset attaches an fx point to the same kind the registry names); bx/by/bz override the
#      point's "base" (the vector its export subtracts to recover the registry's raw offset -- 0,0,0 unless the
#      point is one of the 7 "TOP of prop" / "RIM of the prop" / "base is X" / "on top of Y" points below);
#      ox/oy/oz override the resulting LOCAL offset outright (used for tower_column_side's mirrored -60 cross,
#      which is drawn but never exported). ------------------------------------------------------------------
my %fx_base;   # name -> [bx,by,bz], default [0,0,0] (registry offset only, no base to undo on export)
$fx_base{pipe_glow}        = [ 0, 0, $tv_top_z ];                       # TOP of the prop (tv)
$fx_base{brazier_rim_fire} = [ 0, 0, $brazier_rim_z ];                  # RIM of the prop (brazier), df_m2_rim_height
$fx_base{brazier_ash}      = [ 0, 0, $brazier_rim_z ];                  # RIM of the prop (brazier), df_m2_rim_height
$fx_base{fuse_focus}       = [ 0, 0, $fx_def{fuse_led}{z} ];            # base is fuse_led, not the box origin
$fx_base{relay_array_step} = [ 0, 0, $fx_def{relay_array_node}{z} ];    # "multiplied by the array level, on top of relay_array_node"

sub fx_part {
    my (%o)  = @_;
    my $name = $o{name} // die "fx_part: missing name\n";
    my $d    = $fx_def{$name} // die "fx_part: unknown fx point \"$name\" (not in df_fx_points_init())\n";
    my $base = $fx_base{$name} || [ 0, 0, 0 ];
    my $bx   = defined $o{bx} ? $o{bx} : $base->[0];
    my $by   = defined $o{by} ? $o{by} : $base->[1];
    my $bz   = defined $o{bz} ? $o{bz} : $base->[2];
    my $ox   = defined $o{ox} ? $o{ox} : $bx + $d->{x};
    my $oy   = defined $o{oy} ? $o{oy} : $by + $d->{y};
    my $oz   = defined $o{oz} ? $o{oz} : $bz + $d->{z};
    return {
        ptype  => 'fx',
        name   => $name,
        parent => ( $o{parent} // $d->{parent} ),
        ox     => r2($ox), oy => r2($oy), oz => r2($oz),
        baseX  => r2($bx), baseY => r2($by), baseZ => r2($bz),
        sound  => ( $name =~ /snd|hum/ ? 1 : 0 ),
        rule   => $d->{rule},
    };
}

# ---- model part helper: builds one "ptype":"model" part. parent (a KIND string) marks a part whose
#      df_model_def offset is genuinely relative to another part in the SAME preset (only relay_coil /
#      relay_mast / relay_top, per df_model_offset's own registry -- everything else, even a piece that sits
#      visually on top of another prop like the table, is placed by other GSC code, not a df_model_def offset,
#      and stays root-level here); fxAlias lets an fx point's registry parent_kind (e.g. the generic "part")
#      resolve to a concrete part carrying a more specific kind (e.g. "part_a"); anchor marks a neutral stand-in
#      for a kind with no model of its own in df_models_init() (drawn translucent, labelled "<kind> (anchor)",
#      and never exported as a df_model_def line). ------------------------------------------------------------
sub model_part {
    my (%o) = @_;
    my %p = (
        ptype => 'model', kind => $o{kind}, model => $o{model},
        x => $o{x} // 0, y => $o{y} // 0, z => $o{z} // 0,
        pitch => $o{pitch} // 0, roll => $o{roll} // 0, yaw => $o{yaw} // 0,
    );
    $p{parent}  = $o{parent}  if $o{parent};
    $p{fxAlias} = $o{fxAlias} if $o{fxAlias};
    $p{anchor}  = 1           if $o{anchor};
    $p{snapTop} = 1           if $o{snapTop};
    $p{slot}    = $o{slot}    if defined $o{slot};
    return \%p;
}

# Kinds with no model of their own in df_models_init() (per the owner spec for this composer): drawn with a
# small neutral marker (the same always-loaded meteor piece kind "orb" already uses) instead of a real prop,
# and never exported as a df_model_def line -- only their fx points are.
my $anchor_model = $model_def{orb}{name};
sub anchor_part { my ($kind) = @_; return model_part( kind => $kind, model => $anchor_model, anchor => 1 ); }

# df_table_slot( n ) in df_coords.gsc: c.origin + df_offset_rotate( (x,y,0), df_table_yaw() ) + (0,0,
# df_model_top_z("table") + z), where (x,y,z) is the slot's own df_table_slot_def entry (z from the TOP).
# The scene puts the table at (0,0,0) with its front yaw, so a slot's scene position is its registered offset
# turned by table_front_yaw, at the table top plus its own z. df_rotate_offset() turns it the same way it
# turns any other registered offset.
sub table_slot_xyz {
    my ($n) = @_;
    my $d = $slot_def{$n};
    my ( $sx, $sy ) = df_rotate_offset( $d->[0], $d->[1], 0, $table_front_yaw );
    return ( r2($sx), r2($sy), r2( $table_top_z + $d->[2] ) );
}
my @slot0 = table_slot_xyz(0);
my @slot1 = table_slot_xyz(1);
my @slot2 = table_slot_xyz(2);

# The relay sits 45 degrees off the table's front on slot 0 (df_a1_relay_spawn: "yaw = yaw - 45"; df_table_demo_prop:
# same, "the relay pieces sit at 45 degrees on the table"); relay_coil / relay_mast ride at their registered
# df_model_offset, turned the same way (df_model_offset_at / df_offset_rotate).
# the turn is read from df_table_demo_prop ("yaw = yaw - N;") so the page follows the code (owner turned it to 135 on 2026-09-22)
my ($relay_turn) = $gsc =~ /df_relay_table_turn\(\)\s*{\s*return (-?[\d.]+);/s;
$relay_turn = -45 unless defined $relay_turn;
my $relay_yaw = $table_front_yaw + $relay_turn;
my ( $coil_ox, $coil_oy, $coil_oz ) = df_rotate_offset( $model_def{relay_coil}{ox}, $model_def{relay_coil}{oy}, $model_def{relay_coil}{oz}, $relay_yaw );
my ( $mast_ox, $mast_oy, $mast_oz ) = df_rotate_offset( $model_def{relay_mast}{ox}, $model_def{relay_mast}{oy}, $model_def{relay_mast}{oz}, $relay_yaw );
my @relay_pos      = ( r2( $slot0[0] ),               r2( $slot0[1] ),               r2( $slot0[2] ) );
my @relay_coil_pos = ( r2( $slot0[0] + $coil_ox ),     r2( $slot0[1] + $coil_oy ),     r2( $slot0[2] + $coil_oz ) );
my @relay_mast_pos = ( r2( $slot0[0] + $mast_ox ),     r2( $slot0[1] + $mast_oy ),     r2( $slot0[2] + $mast_oz ) );
my $relay_coil_yaw = $relay_yaw + $model_def{relay_coil}{yawoff};
my $relay_mast_yaw = $relay_yaw + $model_def{relay_mast}{yawoff};

# card / skull sit ON slot 1, not turned with the relay (df_table_demo_prop only turns the relay kinds); their
# own yaw is the table's front yaw plus the kind's own df_model_def yaw offset. No lift of their own any more:
# the slot IS the item's rest position (the owner drags the item, the slot's z follows it).
my $card_yaw  = $table_front_yaw + $model_def{card}{yawoff};
my $skull_yaw = $table_front_yaw + $model_def{skull}{yawoff};
my @card_pos  = @slot1;
my @skull_pos = @slot1;

# orb sits ON slot 2 (both sides), the slot's own z carrying the hover the owner gave it.
my $orb_yaw  = $table_front_yaw + $model_def{orb}{yawoff};
my @orb_pos  = @slot2;

# fx points shared by both "Table, ... loaded" presets: the socket points (parent "table" directly), the nine
# relay_step_glow_N (parent "relay") and orb_aura/orb_glint (parent "orb").
sub table_common_fx {
    my @fx = (
        fx_part( name => 'socket_spark',  parent => 'table' ),
        fx_part( name => 'socket_glow',   parent => 'table' ),
        fx_part( name => 'socket_marker', parent => 'table' ),
    );
    push @fx, map { fx_part( name => "relay_step_glow_$_", parent => 'relay' ) } 1 .. 9; # owner 2026-09-23: one glow per step up the mast
    push @fx, fx_part( name => 'orb_aura', parent => 'orb' ), fx_part( name => 'orb_glint', parent => 'orb' );
    return @fx;
}

my @preset_order;
my %presets;

sub add_preset {
    my ( $key, $label, $note, @parts ) = @_;
    push @preset_order, $key;
    $presets{$key} = { label => $label, note => $note, parts => \@parts };
}

add_preset(
    'pipe1', 'Pipe (Step 1)',
    'Kind "tv" (' . $model_def{tv}{name} . ') at (0,0,0). pipe_glow: base = TOP of the prop, df_model_top_z("tv") = '
      . $tv_top_z . ', registry offset (0,0,' . $fx_def{pipe_glow}{z} . ') on top of that.',
    model_part( kind => 'tv', model => $model_def{tv}{name}, pitch => $model_def{tv}{pitch}, roll => $model_def{tv}{roll} ),
    fx_part( name => 'pipe_glow', parent => 'tv' ),
);

add_preset(
    'signal', 'Signal light',
    'Kind "signal" has no model of its own in df_models_init(): the marker below is a neutral stand-in (' . $anchor_model
      . '). signal_flash and signal_hum both sit at the anchor origin plus their own registry offset (no top/rim base); signal_hum is a 3D sound (dot).',
    anchor_part('signal'),
    fx_part( name => 'signal_flash', parent => 'signal' ),
    fx_part( name => 'signal_hum',   parent => 'signal' ),
);

add_preset(
    'part_ground', 'Part on the ground',
    'Kind "part_a" (' . $model_def{part_a}{name}
      . ') at (0,0,0): the concrete prop the generic registry parent "part" attaches to here (fx points still export parent "part", not "part_a"). '
      . 'part_glint = the ground spot, part_roof_glint = the same point\'s bus-roof variant; both registry offset only.',
    model_part( kind => 'part_a', model => $model_def{part_a}{name}, pitch => $model_def{part_a}{pitch}, roll => $model_def{part_a}{roll}, fxAlias => 'part' ),
    fx_part( name => 'part_glint',      parent => 'part' ),
    fx_part( name => 'part_roof_glint', parent => 'part' ),
);

add_preset(
    'spool_pickup', 'Spool (pickup)',
    'Kind "spool" (' . $model_def{spool}{name} . ') at (0,0,0), a real df_model_def entry -- moving it exports a normal df_model_def line, not a marker. pickup_glint sits at the prop\'s origin plus its registry offset.',
    model_part( kind => 'spool', model => $model_def{spool}{name}, pitch => $model_def{spool}{pitch}, roll => $model_def{spool}{roll} ),
    fx_part( name => 'pickup_glint', parent => 'spool' ),
);

add_preset(
    'coil_drop', 'Coil drop',
    'Kind "receiver" (' . $model_def{receiver}{name} . ') at (0,0,0). part_spark = where the part lands, registry offset only.',
    model_part( kind => 'receiver', model => $model_def{receiver}{name}, pitch => $model_def{receiver}{pitch}, roll => $model_def{receiver}{roll} ),
    fx_part( name => 'part_spark', parent => 'receiver' ),
);

add_preset(
    'relay_roof', 'Relay (bus roof)',
    'Base = kind "relay" (' . $model_def{relay}{name} . ') at (0,0,0); coil = kind "relay_coil" (' . $model_def{relay_coil}{name}
      . '), df_model_offset (' . $model_def{relay_coil}{ox} . ',' . $model_def{relay_coil}{oy} . ',' . $model_def{relay_coil}{oz}
      . '); top = kind "relay_top" (' . $model_def{relay_top}{name} . '), df_model_offset (' . $model_def{relay_top}{ox} . ',' . $model_def{relay_top}{oy} . ',' . $model_def{relay_top}{oz}
      . '). The six fx points (relay_dust/spark/burst_low/burst_mid/glow/glint) all take parent "relay", registry offset only.',
    model_part( kind => 'relay', model => $model_def{relay}{name}, pitch => $model_def{relay}{pitch}, roll => $model_def{relay}{roll} ),
    model_part(
        kind => 'relay_coil', model => $model_def{relay_coil}{name},
        x => $model_def{relay_coil}{ox}, y => $model_def{relay_coil}{oy}, z => $model_def{relay_coil}{oz},
        pitch => $model_def{relay_coil}{pitch}, roll => $model_def{relay_coil}{roll}, yaw => $model_def{relay_coil}{yawoff},
        parent => 'relay',
    ),
    model_part(
        kind => 'relay_top', model => $model_def{relay_top}{name},
        x => $model_def{relay_top}{ox}, y => $model_def{relay_top}{oy}, z => $model_def{relay_top}{oz},
        pitch => $model_def{relay_top}{pitch}, roll => $model_def{relay_top}{roll}, yaw => $model_def{relay_top}{yawoff},
        parent => 'relay',
    ),
    fx_part( name => 'relay_dust',      parent => 'relay' ),
    fx_part( name => 'relay_spark',     parent => 'relay' ),
    fx_part( name => 'relay_burst_low', parent => 'relay' ),
    fx_part( name => 'relay_burst_mid', parent => 'relay' ),
    fx_part( name => 'relay_glow',      parent => 'relay' ),
    fx_part( name => 'relay_glint',     parent => 'relay' ),
);

add_preset(
    'relay_table', 'Relay (table, plugged)',
    'The relay assembly as it stands on the table before the table\'s own front yaw is applied (see "Table, ... loaded" for the full turn). '
      . 'mast = kind "relay_mast" (' . $model_def{relay_mast}{name} . '), df_model_offset (' . $model_def{relay_mast}{ox} . ',' . $model_def{relay_mast}{oy} . ',' . $model_def{relay_mast}{oz}
      . '). relay_array_node marks slot 0\'s own array position (registry offset (0,0,' . $fx_def{relay_array_node}{z}
      . ')); relay_array_step is drawn ONCE here (node + 1 step, "+step") though the game code multiplies its registry offset by the live array level.',
    model_part( kind => 'relay', model => $model_def{relay}{name}, pitch => $model_def{relay}{pitch}, roll => $model_def{relay}{roll} ),
    model_part(
        kind => 'relay_coil', model => $model_def{relay_coil}{name},
        x => $model_def{relay_coil}{ox}, y => $model_def{relay_coil}{oy}, z => $model_def{relay_coil}{oz},
        pitch => $model_def{relay_coil}{pitch}, roll => $model_def{relay_coil}{roll}, yaw => $model_def{relay_coil}{yawoff},
        parent => 'relay',
    ),
    model_part(
        kind => 'relay_mast', model => $model_def{relay_mast}{name},
        x => $model_def{relay_mast}{ox}, y => $model_def{relay_mast}{oy}, z => $model_def{relay_mast}{oz},
        pitch => $model_def{relay_mast}{pitch}, roll => $model_def{relay_mast}{roll}, yaw => $model_def{relay_mast}{yawoff},
        parent => 'relay',
    ),
    fx_part( name => 'relay_array_node', parent => 'relay' ),
    fx_part( name => 'relay_array_step', parent => 'relay' ),
    fx_part( name => 'relay_step_glow_1', parent => 'relay' ),
    fx_part( name => 'relay_step_glow_2', parent => 'relay' ),
    fx_part( name => 'relay_step_glow_3', parent => 'relay' ),
    fx_part( name => 'relay_step_glow_4', parent => 'relay' ),
    fx_part( name => 'relay_step_glow_5', parent => 'relay' ),
    fx_part( name => 'relay_step_glow_6', parent => 'relay' ),
    fx_part( name => 'relay_step_glow_7', parent => 'relay' ),
    fx_part( name => 'relay_step_glow_8', parent => 'relay' ),
    fx_part( name => 'relay_step_glow_9', parent => 'relay' ),
);

for my $variant ( [ 'table_rich', 'Table, Richtofen loaded' ], [ 'table_maxis', 'Table, Maxis loaded' ] ) {
    my ( $key, $label ) = @$variant;
    my $is_rich = $key eq 'table_rich';
    my $note =
        'Base = kind "table" (' . $model_def{table}{name} . ') at (0,0,0), front yaw ' . $table_front_yaw
      . '. The three slots are the registry df_table_slots_init() in df_coords.gsc, one df_table_slot_def line each, '
      . 'in the table\'s frame with z from the top (df_model_top_z("table") = ' . $table_top_z . '): '
      . join( ', ', map { sprintf 'slot %d = ( %s, %s, %s )', $_, @{ $slot_def{$_} } } ( 0, 1, 2 ) )
      . '. Each item sits exactly ON its slot (the lift is the slot\'s own z; no caller adds anything). '
      . 'Slot 0: the plugged relay assembly (relay turned yaw + ' . $relay_turn . ' = ' . $relay_yaw . '); relay_coil / relay_mast at their '
      . 'df_model_offset, rotated the same way. Slot 1: '
      . ( $is_rich
        ? 'kind "card" (' . $model_def{card}{name} . ').'
        : 'kind "skull" (' . $model_def{skull}{name} . ').' )
      . ' Slot 2: kind "orb" (' . $model_def{orb}{name} . ')'
      . '. fx: socket_spark/glow/marker (parent "table"), '
      . ( $is_rich ? 'no card points' : 'skull_glow (parent "skull", the floor stone glow)' )
      . ', orb_aura/orb_glint (parent "orb"). The GSC export gives every child part\'s offset in ITS PARENT\'s own frame (undoing that '
      . 'part\'s own yaw, e.g. relay_coil / relay_mast come back out at their exact df_model_offset despite the relay\'s -45 turn), '
      . 'plus a ready-to-paste "table layout" block of df_table_slot_def lines for the three slots.';

    my @occupant = $is_rich
      ? ( model_part( kind => 'card', model => $model_def{card}{name}, x => $card_pos[0], y => $card_pos[1], z => $card_pos[2], pitch => $model_def{card}{pitch}, roll => $model_def{card}{roll}, yaw => $card_yaw, slot => 1 ) )
      : ( model_part( kind => 'skull', model => $model_def{skull}{name}, x => $skull_pos[0], y => $skull_pos[1], z => $skull_pos[2], pitch => $model_def{skull}{pitch}, roll => $model_def{skull}{roll}, yaw => $skull_yaw, slot => 1 ) );

    my @occupant_fx = $is_rich
      ? ()
      : ( fx_part( name => 'skull_glow', parent => 'skull' ) );

    # owner 2026-09-23: the FIRE HAND (kind "ember") on the Maxis table, a child of the table: its export is the
    # df_model_def "ember" offset in the table frame (df_table_point), shown here where M2 leaves it before Step 6
    my @hand = $is_rich ? () : (
        model_part( kind => 'ember', model => $model_def{ember}{name}, x => $model_def{ember}{ox} // 0, y => $model_def{ember}{oy} // 0, z => $model_def{ember}{oz} // 46,
                    pitch => $model_def{ember}{pitch}, roll => $model_def{ember}{roll}, yaw => $table_front_yaw + ($model_def{ember}{yawoff} // 0), parent => 'table' ),
        fx_part( name => 'hand_fire', parent => 'ember' ),
    );

    add_preset(
        $key, $label, $note,
        model_part( kind => 'table', model => $model_def{table}{name}, pitch => $model_def{table}{pitch}, roll => $model_def{table}{roll}, yaw => $table_front_yaw ),
        model_part( kind => 'relay', model => $model_def{relay}{name}, x => $relay_pos[0], y => $relay_pos[1], z => $relay_pos[2], pitch => $model_def{relay}{pitch}, roll => $model_def{relay}{roll}, yaw => $relay_yaw, slot => 0 ),
        model_part(
            kind => 'relay_coil', model => $model_def{relay_coil}{name},
            x => $relay_coil_pos[0], y => $relay_coil_pos[1], z => $relay_coil_pos[2],
            pitch => $model_def{relay_coil}{pitch}, roll => $model_def{relay_coil}{roll}, yaw => $relay_coil_yaw,
            parent => 'relay',
        ),
        model_part(
            kind => 'relay_mast', model => $model_def{relay_mast}{name},
            x => $relay_mast_pos[0], y => $relay_mast_pos[1], z => $relay_mast_pos[2],
            pitch => $model_def{relay_mast}{pitch}, roll => $model_def{relay_mast}{roll}, yaw => $relay_mast_yaw,
            parent => 'relay',
        ),
        @occupant,
        model_part( kind => 'orb', model => $model_def{orb}{name}, x => $orb_pos[0], y => $orb_pos[1], z => $orb_pos[2], pitch => $model_def{orb}{pitch}, roll => $model_def{orb}{roll}, yaw => $orb_yaw, slot => 2 ),
        table_common_fx(),
        @occupant_fx,
        @hand,
    );
}

add_preset(
    'fuse', 'Fuse box',
    'Kind "fuse" (' . $model_def{fuse}{name} . ') at (0,0,0). fuse_led = the LED face (registry offset only, z=' . $fx_def{fuse_led}{z}
      . '); fuse_focus\'s base is fuse_led itself (registry offset (0,0,' . $fx_def{fuse_focus}{z} . ') on top of it); fuse_aim = registry offset only.',
    model_part( kind => 'fuse', model => $model_def{fuse}{name}, pitch => $model_def{fuse}{pitch}, roll => $model_def{fuse}{roll} ),
    fx_part( name => 'fuse_led',   parent => 'fuse' ),
    fx_part( name => 'fuse_focus', parent => 'fuse' ),
    fx_part( name => 'fuse_aim',   parent => 'fuse' ),
);

add_preset(
    'core', 'Core block',
    'Kind "core" has no model of its own (marker: ' . $anchor_model . '). core_node: registry offset only.',
    anchor_part('core'),
    fx_part( name => 'core_node', parent => 'core' ),
);

add_preset(
    'cabin_hearth', 'Cabin hearth (Step 6 Maxis)',
    'Kind "cabin_hearth" (DF_CABIN_HEARTH, the floor under the fireplace opening of the hunter cabin in the woods) has no model of its own: the fireplace is map geometry (marker: ' . $anchor_model . '). cabin_hearth_node: registry offset only (the aim, beam, hum and glow point, the centre of the opening).',
    anchor_part('cabin_hearth'),
    fx_part( name => 'cabin_hearth_node', parent => 'cabin_hearth' ),
);

add_preset(
    'lamp', 'Lamp post',
    'Kind "lamp" has no model of its own (marker: ' . $anchor_model . '). lamp_bulb_glow: registry offset only (the fallback bulb height when the map exploder is not found).',
    anchor_part('lamp'),
    fx_part( name => 'lamp_bulb_glow', parent => 'lamp' ),
);

add_preset(
    'tombstone', 'Tombstone',
    'Base = kind "brazier" (' . $model_def{brazier}{name} . ') at (0,0,0). brazier_rim_fire / brazier_ash: base = the RIM the game uses, df_m2_rim_height("' . $model_def{brazier}{name} . '") = ' . $brazier_rim_z
      . '. brazier_ember: registry offset only (the fire hand is on the Maxis table preset).',
    model_part( kind => 'brazier', model => $model_def{brazier}{name}, pitch => $model_def{brazier}{pitch}, roll => $model_def{brazier}{roll} ),
    fx_part( name => 'brazier_rim_fire', parent => 'brazier' ),
    fx_part( name => 'brazier_ash',      parent => 'brazier' ),
    fx_part( name => 'brazier_ember',    parent => 'brazier' ),
);

add_preset(
    'card_barn', 'Key card (barn)',
    'Kind "card_barn": the key card where it first appears in the barn, standing and floating (its z is the float height above the floor under DF_CARD_SPAWN; the game adds a random turn). '
      . 'Pitch / roll / yaw here become its pose. card_barn_glint: the glint on it. The table pose is the separate kind "card" (Table presets).',
    model_part( kind => 'card_barn', model => $model_def{card_barn}{name}, x => $model_def{card_barn}{ox} // 0, y => $model_def{card_barn}{oy} // 0, z => $model_def{card_barn}{oz} // 36,
                pitch => $model_def{card_barn}{pitch}, roll => $model_def{card_barn}{roll}, yaw => $model_def{card_barn}{yawoff} // 0 ),
    fx_part( name => 'card_barn_glint', parent => 'card_barn' ),
);

add_preset(
    'orb_ground', 'Orb (on the ground)',
    'Kind "orb_ground": the rock where it lands and rests on the floor (Step 6 landing spots, drops, the Step 7 wander). Its z is the rest height above the floor. '
      . 'The glints shown are the orb points (orb_aura / orb_glint), the same ones as on the table. The table pose is slot 2 of the Table presets.',
    model_part( kind => 'orb_ground', model => $model_def{orb_ground}{name}, x => 0, y => 0, z => $model_def{orb_ground}{oz} // 3,
                pitch => $model_def{orb_ground}{pitch}, roll => $model_def{orb_ground}{roll}, yaw => $model_def{orb_ground}{yawoff} // 0, fxAlias => 'orb' ),
    fx_part( name => 'orb_aura',  parent => 'orb_ground' ),
    fx_part( name => 'orb_glint', parent => 'orb_ground' ),
);

add_preset(
    'orb', 'Orb',
    'Kind "orb" (' . $model_def{orb}{name} . ') at (0,0,0); df_model_rest_z("orb") = ' . $orb_rest . ' of hover is handled by the step code, not shown here. orb_aura / orb_glint: registry offset only.',
    model_part( kind => 'orb', model => $model_def{orb}{name}, pitch => $model_def{orb}{pitch}, roll => $model_def{orb}{roll} ),
    fx_part( name => 'orb_aura',  parent => 'orb' ),
    fx_part( name => 'orb_glint', parent => 'orb' ),
);

add_preset(
    'portal', 'Portal',
    'Kind "portal" (' . $model_def{portal}{name} . ') at (0,0,0), a real df_model_def entry -- moving it exports a normal df_model_def line, not a marker. '
      . 'portal_orbit has a horizontal registry offset (' . $fx_def{portal_orbit}{x} . ',0,' . $fx_def{portal_orbit}{z} . '); the rest are vertical only.',
    model_part( kind => 'portal', model => $model_def{portal}{name}, pitch => $model_def{portal}{pitch}, roll => $model_def{portal}{roll} ),
    fx_part( name => 'portal_light',       parent => 'portal' ),
    fx_part( name => 'portal_orbit',       parent => 'portal' ),
    fx_part( name => 'portal_burst_ash',   parent => 'portal' ),
    fx_part( name => 'portal_burst_light', parent => 'portal' ),
);

add_preset(
    'tower', 'Tower',
    'Kind "tower" has no model of its own (marker: ' . $anchor_model . '). tower_column_side is registered once (' . $fx_def{tower_column_side}{x}
      . ',0,0) and mirrored +/- at runtime: drawn here as two crosses but exported once. tower_power_snd is a 3D sound (dot).',
    anchor_part('tower'),
    fx_part( name => 'tower_column_side', parent => 'tower' ),                                                     # +60, first occurrence: what gets exported
    fx_part( name => 'tower_column_side', parent => 'tower', ox => -1 * $fx_def{tower_column_side}{x} ),           # -60, display only
    fx_part( name => 'tower_power_snd', parent => 'tower' ),
);

# ---- sanity check: every one of the 44 registry fx points must appear in the presets above exactly once
#      (by name; a point may be DRAWN more than once, like tower_column_side, but must
#      still be reachable), and nothing unknown must have snuck in. ---------------------------------------
my %used_fx;
for my $key (@preset_order) {
    for my $p ( @{ $presets{$key}{parts} } ) {
        $used_fx{ $p->{name} } = 1 if $p->{ptype} eq 'fx';
    }
}
my @missing_fx = grep { !$used_fx{$_} } @fx_order;
die "Composer presets are missing fx points: @missing_fx\n" if @missing_fx;
my @unknown_fx = grep { !exists $fx_def{$_} } keys %used_fx;
die "Composer presets reference unknown fx points: @unknown_fx\n" if @unknown_fx;
printf STDERR "presets cover all %d registry fx points across %d presets\n", scalar( keys %used_fx ), scalar(@preset_order);

my $presets_json = JSON::PP->new->canonical->encode( \%presets );

# ---- FX_REGISTRY: the full 44-point registry, embedded so the page's "Import scene" can round-trip a
#      pasted `fx | name | parent | x y z` line without the preset that first drew it (sound flag, base rule
#      text, and the base vector its export subtracts). -----------------------------------------------------
my %fx_registry_out;
for my $name (@fx_order) {
    my $base = $fx_base{$name} || [ 0, 0, 0 ];
    $fx_registry_out{$name} = {
        parent => $fx_def{$name}{parent},
        rule   => $fx_def{$name}{rule},
        sound  => ( $name =~ /snd|hum/ ? 1 : 0 ),
        baseX  => $base->[0], baseY => $base->[1], baseZ => $base->[2],
    };
}
my $fx_registry_json = JSON::PP->new->canonical->encode( \%fx_registry_out );

my $preset_options = join( '', map { qq~<option value="$_">$presets{$_}{label}</option>\n~ } @preset_order );
$preset_options .= qq~<option value="empty">Empty</option>\n~;

my $footer_note = "$count TranZit models embedded (glTF under 420 KB each, zones zm_transit / so_zclassic_zm_transit / common_zm / patch_zm); $dropped dropped to stay under the 16 MB page budget. "
  . scalar(@fx_order) . " effect/sound attach points from df_fx_points_init() across " . scalar(@preset_order) . " presets.";

# ---- the page -----------------------------------------------------------------------------------------
my $template = <<'HTMLEOF';
<title>Dead Frequency Prop Composer</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;700&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{--bg:#efece6;--panel:#ffffff;--ink:#1b1e23;--muted:#5d6673;--line:#d9d4ca;--accent:#c96f14;--elec:#1f78b8;--good:#3f8f46;--bar:#e6dfd2;--sel:#fff3e4;--canvas:#dcd7cc;--fx:#a5238f}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419;--canvas:#23272d;--fx:#e469cf}}
:root[data-theme="dark"]{--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419;--canvas:#23272d;--fx:#e469cf}
body{background:var(--bg);color:var(--ink);font:15px/1.5 "IBM Plex Sans",system-ui,sans-serif;margin:0}
.wrap{max-width:1440px;margin:0 auto;padding:22px 20px 40px}
.top{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:6px}
.top h1{font:700 34px/1 "Barlow Condensed","Arial Narrow",sans-serif;margin:0;flex:1}
.lede{color:var(--muted);margin:0 0 16px;max-width:100ch}
.card{background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--accent);padding:12px 14px;margin-bottom:10px}
.eyebrow{font:600 11px "IBM Plex Sans",sans-serif;letter-spacing:.1em;text-transform:uppercase;color:var(--accent)}
code{font:500 13px "IBM Plex Mono",monospace}
.dims{font:12px "IBM Plex Mono",monospace;font-variant-numeric:tabular-nums;color:var(--muted)}
.zone{font:11px "IBM Plex Mono",monospace;color:var(--muted);margin-left:auto}
button{font:600 13px "IBM Plex Sans",sans-serif;cursor:pointer}
.pickbtn{background:var(--accent);color:#fff;border:0;padding:8px 14px}
.pickbtn:disabled{opacity:.4;cursor:default}
.ghost{background:transparent;color:var(--ink);border:1px solid var(--line);padding:6px 10px}
button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible{outline:2px solid var(--elec);outline-offset:2px}
.filters{display:flex;gap:10px;margin:0 0 8px}
.filters input{flex:1;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px 10px;font:14px "IBM Plex Sans",sans-serif}
.mlist{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:3px;max-height:52vh;overflow:auto;border:1px solid var(--line);background:var(--panel)}
.mrow{display:flex;align-items:center;gap:10px;padding:6px 10px;cursor:pointer;border-bottom:1px solid var(--line)}
.mrow:hover{background:var(--bg)}.mrow.viewing{outline:2px solid var(--elec);outline-offset:-2px}
.composer{display:grid;grid-template-columns:300px minmax(380px,1fr) 340px;gap:16px;align-items:start;margin-top:10px}
@media (max-width:1150px){.composer{grid-template-columns:1fr}}
.viewer{position:sticky;top:12px;background:var(--panel);border:1px solid var(--line)}
.viewer canvas{display:block;width:100%;height:480px;background:var(--canvas)}
.vbar{display:flex;align-items:center;gap:10px;padding:10px 12px;flex-wrap:wrap;border-top:1px solid var(--line)}
.vbar .dims{margin-left:auto}
.hint{font-size:12px;color:var(--muted);padding:0 12px 10px}
.diag{font:11px "IBM Plex Mono",monospace;color:var(--muted);padding:0 12px 10px}
.parts{max-height:52vh;overflow:auto;padding-right:2px}
.part-row{border:1px solid var(--line);padding:8px 10px;margin-bottom:8px;background:var(--panel)}
.part-row.selected{outline:2px solid var(--elec);outline-offset:-2px;background:var(--sel)}
.part-row.fxrow{border-left:3px solid var(--fx)}
.part-row .kindrow{display:flex;gap:6px;margin-bottom:6px;align-items:center}
.part-row input[type=text],.part-row select{background:var(--panel);color:var(--ink);border:1px solid var(--line);font:12px "IBM Plex Mono",monospace;padding:4px 5px;min-width:0}
.part-row .kindrow input[type=text]{flex:1}
.part-row .kindrow select{flex:1.4}
.part-row .nums{display:grid;grid-template-columns:repeat(6,1fr);gap:4px;margin-bottom:6px}
.part-row.fxrow .nums{grid-template-columns:repeat(3,1fr)}
.part-row .nums label{display:block;font:10px "IBM Plex Sans",sans-serif;color:var(--muted);text-transform:uppercase}
.part-row .nums input{width:100%;box-sizing:border-box;background:var(--panel);color:var(--ink);border:1px solid var(--line);font:12px "IBM Plex Mono",monospace;padding:3px}
.part-row .btnrow{display:flex;gap:4px;flex-wrap:wrap}
.part-row .btnrow button{font:11px "IBM Plex Sans",sans-serif;padding:4px 7px;background:transparent;color:var(--ink);border:1px solid var(--line);cursor:pointer}
.part-row .btnrow button:disabled{opacity:.35;cursor:default}
.readout{font:13px "IBM Plex Mono",monospace;background:var(--panel);border:1px solid var(--line);padding:8px 10px;margin:10px 0;white-space:pre-wrap;word-break:break-word}
.presets{display:flex;gap:8px;align-items:center;margin:12px 0 4px}
.presets select{flex:1;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:7px 9px;font:13px "IBM Plex Sans",sans-serif}
.preset-note{font-size:12px;color:var(--muted);margin:0 0 10px;max-width:70ch}
.export pre{font:11px/1.5 "IBM Plex Mono",monospace;white-space:pre-wrap;word-break:break-word;background:var(--panel);border:1px solid var(--line);padding:8px;max-height:160px;overflow:auto;margin:6px 0}
.export textarea{width:100%;box-sizing:border-box;min-height:70px;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:6px;font:12px "IBM Plex Mono",monospace;margin:6px 0}
.section-h{font:700 16px "Barlow Condensed",sans-serif;margin:14px 0 4px;text-transform:uppercase;letter-spacing:.04em;color:var(--muted)}
footer.note{color:var(--muted);font-size:12px;margin-top:24px;border-top:1px solid var(--line);padding-top:10px}
</style>
<div class="wrap">
<div class="top"><h1>Dead Frequency Prop Composer</h1></div>
<p class="lede">Pick TranZit models on the left, add them as parts, position each part in the viewer (drag to turn, wheel to zoom, right-drag to pan), then export df_model_def(...) lines for df_coords.gsc. A preset also loads its registry effect / sound attach points as named crosses (a dot for a 3D sound) next to their prop; they follow their parent part's position and yaw, and export as df_fx_point_def(...) lines. Grid cells are 10 units, the post is a 70-unit player.</p>
<div class="composer">

<div class="left">
<div class="card"><div class="eyebrow">Models</div>
<div class="filters"><input type="search" id="search" placeholder="Search a model name (e.g. transceiver, box, fence, tombstone)"></div>
<ul class="mlist" id="mlist">
__LIST__
</ul>
</div>
</div>

<div class="mid">
<div class="viewer" id="viewer"><canvas id="c"></canvas>
<div class="vbar"><code id="vname">nothing previewed</code><span class="dims" id="vdims"></span><button class="pickbtn" type="button" id="addBtn" disabled>Add as part</button></div>
<div class="hint">Click a model on the left to preview it; "Add as part" drops it into the scene at the origin. Arrows = X/Y by 1, PageUp/PageDown = Z by 1, Q/E = yaw 5&deg;, R/F = pitch 5&deg;, Z/C = roll 5&deg; (Shift = 5 units / 15&deg;, Alt = 0.25 unit / 1&deg;) on the selected part -- for a selected fx cross, arrows/PageUp/PageDown move its offset in its PARENT's frame instead (it has no pitch/yaw/roll of its own: it turns with its parent).</div>
<div class="diag" id="diag"></div>
</div>
<div class="readout" id="readout">nothing selected</div>
</div>

<div class="right">
<div class="card"><div class="eyebrow">Presets</div>
<div class="presets"><select id="presetSel">
<option value="">Load a preset...</option>
__PRESET_OPTIONS__
</select></div>
<p class="preset-note" id="presetNote"></p>
</div>

<div class="section-h">Parts</div>
<div class="parts" id="parts"></div>

<div class="section-h">Export</div>
<div class="export">
<p class="hint" style="padding:0 0 4px">GSC for Dead Frequency (model offsets relative to the parent part's own frame, fx offsets minus their base, rounded to 0.5):</p>
<pre id="gscOut"></pre>
<button class="ghost" type="button" id="copyGsc">Copy GSC</button>
<p class="hint" style="padding:8px 0 4px">Scene text (paste back into "Import scene" below, on this page or another session):</p>
<pre id="sceneOut"></pre>
<button class="ghost" type="button" id="copyScene">Copy scene</button>
<p class="hint" style="padding:8px 0 4px">Import scene:</p>
<textarea id="importIn" placeholder="kind | model | x y z | p y r&#10;fx | name | parent | x y z"></textarea>
<button class="ghost" type="button" id="importBtn">Import scene</button>
</div>
</div>

</div>
<footer class="note">__FOOTER__</footer>
</div>
__SCRIPTS__
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script>
(function(){
  var PRESETS = __PRESETS_JSON__;
  var FX_REGISTRY = __FX_REGISTRY_JSON__;
  var VERSION = 'v7';
  var TABLE_TOP_Z = __TABLE_TOP_Z__;   // df_model_top_z( "table" ): the slot registry's z is measured from here
  var STORE_KEY = 'df_composer_transit';

  function loadStore(){ try{ return JSON.parse(localStorage.getItem(STORE_KEY)||'null'); }catch(e){ return null; } }
  function saveStore(){ try{ localStorage.setItem(STORE_KEY, JSON.stringify({parts:parts, sel:selected})); }catch(e){} }

  // parts is a mix of two part shapes:
  //   model: {ptype:'model', kind, model, x,y,z, pitch,yaw,roll, parent?, fxAlias?, anchor?, snapTop?, slot?}
  //   fx:    {ptype:'fx', name, parent, ox,oy,oz, baseX,baseY,baseZ, sound, rule}
  // an fx part's parent is a KIND string matched against a model part's own kind, or its fxAlias.
  var parts = [];
  var selected = -1;
  var viewingModel = null;
  var previewGroup = null;

  function newPart(model){
    return { ptype: 'model', kind: model, model: model, x: 0, y: 0, z: 0, pitch: 0, yaw: 0, roll: 0 };
  }
  function findParentPart(parentKind){
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i];
      if (p.ptype !== 'fx' && (p.kind === parentKind || p.fxAlias === parentKind)) return p;
    }
    return null;
  }
  function rotateXY(ox, oy, yawDeg){
    var r = yawDeg * Math.PI / 180, c = Math.cos(r), s = Math.sin(r);
    return [ ox * c - oy * s, ox * s + oy * c ];
  }

  // ---------- left model list (DOM-driven, like the Prop Picker) ----------
  var listEl = document.getElementById('mlist');
  var modelNames = Array.prototype.map.call(listEl.querySelectorAll('.mrow'), function(r){ return r.dataset.name; });

  var searchEl = document.getElementById('search');
  searchEl.addEventListener('input', function(){
    var q = this.value.toLowerCase();
    Array.prototype.forEach.call(listEl.querySelectorAll('.mrow'), function(r){ r.hidden = !!q && r.dataset.name.toLowerCase().indexOf(q) < 0; });
  });

  // ---------- three.js viewer ----------
  var canvas = document.getElementById('c');
  var ok = !!(window.THREE && THREE.GLTFLoader && THREE.OrbitControls);
  var renderer, scene, camera, controls;
  var loader = ok ? new THREE.GLTFLoader() : null;
  var GREY = 0xb8b0a2, ACCENT = 0xe5892f, ANCHOR_GREY = 0x7c8794, FX_COLOR = 0xd83bd8, FX_SEL = 0xffe14d;
  var modelCache = {};   // name -> { tmpl: THREE.Group, bounds: {minx,maxx,miny,maxy,minz,maxz} }
  var partGroups = [];   // parallel to parts[]
  var ghostBox = null;

  var diagEl = document.getElementById('diag');
  function mgDiag(t){ if(diagEl) diagEl.textContent = '[' + VERSION + '] ' + t; }
  window.addEventListener('error', function(ev){ mgDiag('script error: ' + (ev.message || ev.type)); });

  function mgStrip(t){
    try{
      var j = JSON.parse(t);
      delete j.images; delete j.textures; delete j.samplers;
      (j.materials || []).forEach(function(m){
        delete m.normalTexture; delete m.occlusionTexture; delete m.emissiveTexture;
        if(m.pbrMetallicRoughness){ delete m.pbrMetallicRoughness.baseColorTexture; delete m.pbrMetallicRoughness.metallicRoughnessTexture; }
      });
      return JSON.stringify(j);
    }catch(e){ return t; }
  }

  // Union of every POSITION accessor's min/max, straight off the glTF JSON text (same technique as the
  // Magmagat picker's Perl-side gltf_bounds, done here in JS so it also covers the parts added at runtime).
  // These dumps keep COD's own axes (Z up), matching df_model_def's (x,y,z) offset convention directly.
  function gltfBounds(t){
    var minx = [], miny = [], minz = [], maxx = [], maxy = [], maxz = [];
    var re = /"min"\s*:\s*\[\s*(-?[0-9.eE+-]+)\s*,\s*(-?[0-9.eE+-]+)\s*,\s*(-?[0-9.eE+-]+)\s*\]/g, m;
    while ((m = re.exec(t))) { minx.push(+m[1]); miny.push(+m[2]); minz.push(+m[3]); }
    re = /"max"\s*:\s*\[\s*(-?[0-9.eE+-]+)\s*,\s*(-?[0-9.eE+-]+)\s*,\s*(-?[0-9.eE+-]+)\s*\]/g;
    while ((m = re.exec(t))) { maxx.push(+m[1]); maxy.push(+m[2]); maxz.push(+m[3]); }
    if (!minx.length || !maxx.length) return { minx: 0, maxx: 0, miny: 0, maxy: 0, minz: 0, maxz: 0 };
    return {
      minx: Math.min.apply(null, minx), maxx: Math.max.apply(null, maxx),
      miny: Math.min.apply(null, miny), maxy: Math.max.apply(null, maxy),
      minz: Math.min.apply(null, minz), maxz: Math.max.apply(null, maxz)
    };
  }

  if (ok) {
    renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true, alpha: true });
    renderer.setPixelRatio(window.devicePixelRatio || 1);
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(45, 1, 0.5, 5000);
    camera.position.set(130, 110, 170);
    controls = new THREE.OrbitControls(camera, canvas);
    controls.target.set(0, 20, 0);
    controls.enableDamping = true;
    scene.add(new THREE.HemisphereLight(0xffffff, 0x5a5348, 0.9));
    var dl = new THREE.DirectionalLight(0xffffff, 0.8); dl.position.set(120, 200, 80); scene.add(dl);
    var grid = new THREE.GridHelper(400, 40, 0xb08050, 0x8a8a8a); grid.material.opacity = 0.6; grid.material.transparent = true; scene.add(grid);
    var post = new THREE.Mesh(new THREE.BoxGeometry(6, 70, 6), new THREE.MeshStandardMaterial({ color: 0x4aa8e8, roughness: 0.9 }));
    post.position.set(-100, 35, 0); scene.add(post);
    function resize(){ var w = canvas.clientWidth, h = canvas.clientHeight; if (canvas.width !== w || canvas.height !== h) { renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix(); } }
    (function loop(){ requestAnimationFrame(loop); resize(); controls.update(); renderer.render(scene, camera); })();
  } else {
    var hintEl = document.querySelector('#viewer .hint');
    if (hintEl) hintEl.textContent = 'The 3D libraries did not load; parts can still be added, positioned and exported by the numbers.';
  }
  mgDiag('three.js ' + (window.THREE ? ('r' + THREE.REVISION) : 'NOT loaded') +
    ', GLTFLoader ' + (window.THREE && THREE.GLTFLoader ? 'ok' : 'missing') +
    ', OrbitControls ' + (window.THREE && THREE.OrbitControls ? 'ok' : 'missing') +
    ', WebGL ' + (function(){ try{ var c = document.createElement('canvas'); return (c.getContext('webgl') || c.getContext('experimental-webgl')) ? 'ok' : 'unavailable'; }catch(e){ return 'unavailable'; } })() +
    '; last parse: none yet');

  function ensureModel(name, cb){
    if (modelCache[name]) { cb(modelCache[name]); return; }
    var el = document.querySelector('script[data-model="' + name + '"]');
    if (!el || !ok) { cb(null); return; }
    var raw = el.textContent;
    var bounds = gltfBounds(raw);
    loader.parse(mgStrip(raw), '', function(g){
      var entry = { tmpl: g.scene, bounds: bounds };
      modelCache[name] = entry;
      var mc = 0; g.scene.traverse(function(o){ if (o.isMesh) mc++; });
      mgDiag('parsed ' + name + ': ' + mc + ' mesh(es), ok');
      cb(entry);
    }, function(e){
      mgDiag('parse error on ' + name + ': ' + (e && e.message ? e.message : e));
      cb(null);
    });
  }

  // Logical (x,y,z,pitch,yaw,roll) match df_model_def's own convention (x,y ground, z vertical); the three.js
  // scene is Y-up, so the vertical logical Z maps to three's Y here, matching the corrective root rotation
  // already baked into every dumped glTF (that is what lets the plain Prop Picker show any single model
  // upright with no rotation of its own).
  //
  // Axis mapping for setPose()'s Euler, spelled out (this is the one thing every part -- model or fx group --
  // rotates through, so pitch/roll editing depends on it being right): game angles are (pitch, yaw, roll)
  // exactly as df_model_angles() returns them ( base[0]=pitch, front_yaw+yawoff, base[2]=roll ), pitch tips the
  // model's nose up/down around its own left/right (three's X) axis, yaw turns it left/right around the
  // vertical (three's Y, since toThree maps logical Z -> three Y) axis, roll banks it around its own forward
  // (three's Z, since toThree maps logical Y -> three Z) axis. THREE.Euler order 'YXZ' applies yaw, then pitch,
  // then roll, each around the object's OWN (already-rotated) axis -- the same order the composed quaternion
  // from df_model_angles' single (pitch, yaw, roll) triplet implies. Yaw is negated because the engine's yaw
  // increases clockwise looking down +Z while three's Y-rotation increases counter-clockwise looking down +Y.
  // A part's pitch/roll fields (in the Parts panel, or R/F and Z/C on the keyboard) feed p.pitch / p.roll here
  // directly: e.g. the card's registry pitch 90 (df_model_def "card","p6_zm_keycard",90,0,0) tips it flat,
  // exactly like a wall prop's registered upright pitch/roll already does for tv/fuse/socket.
  // FIXED 2026-09-23 (owner: the game did not match the preview): game X forward / Y left / Z up maps to three
  // (x, z, -y), the right-handed conversion glTF itself uses; the old (x, z, y) mirrored the world left/right and
  // applied "pitch" around the forward axis (that is a roll). Game angles are yaw about Z, then pitch about the
  // model's own left axis (positive = nose DOWN), then roll about its own forward axis: three Euler order 'YZX'
  // with y = yaw, z = -pitch, x = roll.
  function toThree(x, y, z){ return new THREE.Vector3(x, z, -y); }
  function setPose(obj, p){
    obj.position.copy(toThree(p.x, p.y, p.z));
    var e = new THREE.Euler(
      -THREE.MathUtils.degToRad(p.roll),
      THREE.MathUtils.degToRad(p.yaw),
      -THREE.MathUtils.degToRad(p.pitch),
      'YZX'
    );
    obj.quaternion.setFromEuler(e);
  }

  // A 3-axis cross (6 units, +/-3 on each local axis) for an fx point, and a filled dot for a 3D sound point
  // (name containing "snd" or "hum"). Built directly in three.js space (X stays X, logical Y -> three Z,
  // logical Z(vertical) -> three Y) so the group's own setPose() rotation (parent yaw) turns it correctly.
  function makeCross(color){
    var pts = new Float32Array([ -3,0,0, 3,0,0,  0,0,-3, 0,0,3,  0,-3,0, 0,3,0 ]);
    var geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(pts, 3));
    return new THREE.LineSegments(geo, new THREE.LineBasicMaterial({ color: color }));
  }
  function makeDot(color){
    return new THREE.Mesh(new THREE.SphereGeometry(2, 10, 8), new THREE.MeshBasicMaterial({ color: color }));
  }
  // A small always-visible floating text label (a canvas-texture sprite always faces the camera).
  function makeLabel(text, fg, bg){
    var cnv = document.createElement('canvas'); cnv.width = 256; cnv.height = 64;
    var ctx = cnv.getContext('2d');
    ctx.font = '30px "IBM Plex Sans", sans-serif';
    var w = Math.max(24, Math.min(246, ctx.measureText(text).width + 16));
    ctx.fillStyle = bg || 'rgba(20,20,24,0.78)';
    ctx.fillRect(0, 10, w, 44);
    ctx.fillStyle = fg || '#fff';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 6, 32, w - 10);
    var tex = new THREE.CanvasTexture(cnv);
    tex.needsUpdate = true;
    var spr = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false, depthWrite: false, transparent: true }));
    spr.scale.set(w / 64 * 8, 44 / 64 * 8, 1);
    spr.renderOrder = 999;
    return spr;
  }

  function clearGroups(){
    for (var i = 0; i < partGroups.length; i++) { if (partGroups[i]) scene.remove(partGroups[i]); }
    partGroups = [];
    if (ghostBox) { scene.remove(ghostBox); ghostBox = null; }
  }

  function updateGhost(bounds){
    if (ghostBox) { scene.remove(ghostBox); ghostBox = null; }
    if (!ok || !parts.length || parts[0].ptype === 'fx') return;
    var base = parts[0];
    var sx = Math.max(bounds.maxx - bounds.minx, 0.01);
    var sy = Math.max(bounds.maxz - bounds.minz, 0.01);
    var sz = Math.max(bounds.maxy - bounds.miny, 0.01);
    var geo = new THREE.BoxGeometry(sx, sy, sz);
    var edges = new THREE.EdgesGeometry(geo);
    ghostBox = new THREE.LineSegments(edges, new THREE.LineBasicMaterial({ color: 0x4aa8e8, transparent: true, opacity: 0.35 }));
    var cx = base.x + (bounds.minx + bounds.maxx) / 2;
    var cy = base.y + (bounds.miny + bounds.maxy) / 2;
    var cz = base.z + (bounds.minz + bounds.maxz) / 2;
    ghostBox.position.copy(toThree(cx, cy, cz));
    scene.add(ghostBox);
  }

  function rebuildScene(){
    if (!ok) return;
    clearGroups();
    parts.forEach(function(p, i){
      partGroups[i] = null;
      if (p.ptype === 'fx') {
        var parent = findParentPart(p.parent);
        var px = parent ? parent.x : 0, py = parent ? parent.y : 0, pz = parent ? parent.z : 0, pyaw = parent ? parent.yaw : 0;
        var rot = rotateXY(p.ox, p.oy, pyaw);
        var wx = px + rot[0], wy = py + rot[1], wz = pz + p.oz;
        var selFlag = (i === selected);
        var color = selFlag ? FX_SEL : FX_COLOR;
        var grp = new THREE.Group();
        grp.add(p.sound ? makeDot(color) : makeCross(color));
        var label = makeLabel(p.name, selFlag ? '#1b1e23' : '#fff', selFlag ? '#ffe14d' : 'rgba(20,20,24,0.78)');
        label.position.set(0, 6, 0);
        grp.add(label);
        setPose(grp, { x: wx, y: wy, z: wz, pitch: 0, yaw: pyaw, roll: 0 });
        scene.add(grp);
        partGroups[i] = grp;
        return;
      }
      ensureModel(p.model, function(entry){
        if (!entry || !parts[i] || parts[i] !== p) return;
        var grp = new THREE.Group();
        var clone = entry.tmpl.clone(true);
        var color = (i === selected) ? ACCENT : (p.anchor ? ANCHOR_GREY : GREY);
        clone.traverse(function(o){ if (o.isMesh) o.material = new THREE.MeshStandardMaterial({ color: color, roughness: 0.85, metalness: 0.05, side: THREE.DoubleSide, transparent: !!p.anchor, opacity: p.anchor ? 0.4 : 1 }); });
        grp.add(clone);
        if (p.anchor) {
          var lab = makeLabel(p.kind + ' (anchor)', '#fff', 'rgba(60,72,86,0.85)');
          lab.position.set(0, 10, 0);
          grp.add(lab);
        }
        setPose(grp, p);
        scene.add(grp);
        partGroups[i] = grp;
        if (i === 0) updateGhost(entry.bounds);
      });
    });
  }

  // ---------- preview (click a row on the left) ----------
  function previewModel(name){
    viewingModel = name;
    document.getElementById('vname').textContent = name;
    Array.prototype.forEach.call(listEl.querySelectorAll('.mrow.viewing'), function(r){ r.classList.remove('viewing'); });
    var row = listEl.querySelector('.mrow[data-name="' + name + '"]');
    if (row) { row.classList.add('viewing'); document.getElementById('vdims').textContent = row.querySelector('.dims').textContent + ' units'; }
    document.getElementById('addBtn').disabled = false;
    if (!ok) return;
    ensureModel(name, function(entry){
      if (!entry || viewingModel !== name) return;
      if (previewGroup) { scene.remove(previewGroup); previewGroup = null; }
      var clone = entry.tmpl.clone(true);
      clone.traverse(function(o){ if (o.isMesh) o.material = new THREE.MeshStandardMaterial({ color: GREY, roughness: 0.85, metalness: 0.05, side: THREE.DoubleSide }); });
      previewGroup = new THREE.Group();
      previewGroup.add(clone);
      previewGroup.position.set(-160, 0, -80);   // off to the side, clear of the composed scene near the origin
      scene.add(previewGroup);
      if (parts.length === 0 && !camerasFramedOnce) {
        var box = new THREE.Box3().setFromObject(clone), size = box.getSize(new THREE.Vector3()), center = box.getCenter(new THREE.Vector3());
        var m = Math.max(size.x, size.y, size.z, 8);
        controls.target.copy(center);
        camera.position.set(center.x + m * 1.2, center.y + m * 0.9, center.z + m * 1.6);
        camera.near = m / 100; camera.far = m * 50; camera.updateProjectionMatrix();
        camerasFramedOnce = true;
      }
    });
  }
  var camerasFramedOnce = false;

  listEl.addEventListener('click', function(ev){
    var row = ev.target.closest ? ev.target.closest('.mrow') : null;
    if (!row) { var n = ev.target; while (n && n !== listEl && !n.classList.contains('mrow')) n = n.parentNode; row = (n && n.classList && n.classList.contains('mrow')) ? n : null; }
    if (!row) return;
    previewModel(row.dataset.name);
  });

  document.getElementById('addBtn').addEventListener('click', function(){
    if (!viewingModel) return;
    if (previewGroup) { scene.remove(previewGroup); previewGroup = null; }
    parts.push(newPart(viewingModel));
    selected = parts.length - 1;
    saveStore(); renderParts(); rebuildScene();
  });

  // ---------- parts panel ----------
  var partsEl = document.getElementById('parts');
  function escAttr(s){ return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;'); }
  function modelOptions(cur){
    var html = '';
    for (var i = 0; i < modelNames.length; i++) { var n = modelNames[i]; html += '<option value="' + n + '"' + (n === cur ? ' selected' : '') + '>' + n + '</option>'; }
    if (modelNames.indexOf(cur) < 0) html = '<option value="' + escAttr(cur) + '" selected>' + escAttr(cur) + '</option>' + html;
    return html;
  }
  function renderParts(){
    var html = '';
    parts.forEach(function(p, i){
      var sel = i === selected ? ' selected' : '';
      if (p.ptype === 'fx') {
        html += '<div class="part-row fxrow' + sel + '" data-i="' + i + '">';
        html += '<div class="kindrow"><code>' + escAttr(p.name) + '</code><span class="dims">parent: ' + escAttr(p.parent) + (p.sound ? ' (sound)' : '') + '</span></div>';
        html += '<div class="nums">';
        ['ox', 'oy', 'oz'].forEach(function(f){
          html += '<label>' + f + '<input type="number" step="0.5" class="fld" data-i="' + i + '" data-f="' + f + '" value="' + p[f] + '"></label>';
        });
        html += '</div>';
        html += '<p class="hint" style="padding:0 0 6px">' + escAttr(p.rule || 'parent origin + offset (no top/rim base)') + '</p>';
        html += '<div class="btnrow">';
        html += '<button type="button" class="sel" data-i="' + i + '">Select</button>';
        html += '<button type="button" class="dup" data-i="' + i + '">Duplicate</button>';
        html += '<button type="button" class="rm" data-i="' + i + '">Remove</button>';
        html += '</div></div>';
        return;
      }
      html += '<div class="part-row' + sel + '" data-i="' + i + '">';
      html += '<div class="kindrow"><input type="text" class="kind" data-i="' + i + '" value="' + escAttr(p.kind) + '">';
      html += '<select class="modelsel" data-i="' + i + '">' + modelOptions(p.model) + '</select></div>';
      html += '<div class="nums">';
      ['x', 'y', 'z', 'pitch', 'yaw', 'roll'].forEach(function(f){
        html += '<label>' + f + '<input type="number" step="0.5" class="fld" data-i="' + i + '" data-f="' + f + '" value="' + p[f] + '"></label>';
      });
      html += '</div><div class="btnrow">';
      html += '<button type="button" class="sel" data-i="' + i + '">Select</button>';
      html += '<button type="button" class="dup" data-i="' + i + '">Duplicate</button>';
      html += '<button type="button" class="rm" data-i="' + i + '">Remove</button>';
      html += '<button type="button" class="snap" data-i="' + i + '"' + (i === 0 ? ' disabled' : '') + '>Snap on top of part below</button>';
      html += '<button type="button" class="base" data-i="' + i + '"' + (i === 0 ? ' disabled' : '') + '>Set as base</button>';
      html += '</div></div>';
    });
    partsEl.innerHTML = html || '<p class="hint">No parts yet. Click a model on the left, then "Add as part".</p>';
    bindPartEvents();
    updateReadout();
    updateExport();
  }
  function bindPartEvents(){
    Array.prototype.forEach.call(partsEl.querySelectorAll('.kind'), function(inp){
      inp.addEventListener('input', function(){ parts[+this.dataset.i].kind = this.value; saveStore(); updateExport(); updateReadout(); });
    });
    Array.prototype.forEach.call(partsEl.querySelectorAll('.modelsel'), function(sel){
      sel.addEventListener('change', function(){ parts[+this.dataset.i].model = this.value; saveStore(); rebuildScene(); updateExport(); updateReadout(); });
    });
    Array.prototype.forEach.call(partsEl.querySelectorAll('.fld'), function(inp){
      inp.addEventListener('input', function(){
        var i = +this.dataset.i, f = this.dataset.f, v = parseFloat(this.value); if (isNaN(v)) v = 0;
        parts[i][f] = v; saveStore(); rebuildScene(); updateReadout(); updateExport();
      });
    });
    Array.prototype.forEach.call(partsEl.querySelectorAll('.sel'), function(b){ b.addEventListener('click', function(){ selectPart(+this.dataset.i); }); });
    Array.prototype.forEach.call(partsEl.querySelectorAll('.dup'), function(b){ b.addEventListener('click', function(){ duplicatePart(+this.dataset.i); }); });
    Array.prototype.forEach.call(partsEl.querySelectorAll('.rm'), function(b){ b.addEventListener('click', function(){ removePart(+this.dataset.i); }); });
    Array.prototype.forEach.call(partsEl.querySelectorAll('.snap'), function(b){ b.addEventListener('click', function(){ snapPart(+this.dataset.i); }); });
    Array.prototype.forEach.call(partsEl.querySelectorAll('.base'), function(b){ b.addEventListener('click', function(){ setAsBase(+this.dataset.i); }); });
  }
  function selectPart(i){ selected = i; saveStore(); renderParts(); rebuildScene(); }
  function duplicatePart(i){
    var src = parts[i], copy = {}; for (var k in src) copy[k] = src[k];
    if (copy.ptype === 'fx') { copy.ox += 2; copy.oy += 2; } else { copy.x += 2; copy.y += 2; }
    parts.splice(i + 1, 0, copy); selected = i + 1; saveStore(); renderParts(); rebuildScene();
  }
  function removePart(i){
    parts.splice(i, 1);
    if (selected >= parts.length) selected = parts.length - 1;
    saveStore(); renderParts(); rebuildScene();
  }
  function round2(n){ return Math.round(n * 100) / 100; }
  function snapPart(i){
    if (i < 1 || parts[i].ptype === 'fx') return;
    var below = parts[i - 1], target = parts[i];
    var mb = modelCache[below.model], mt = modelCache[target.model];
    if (!mb || !mt) { mgDiag('snap: model bounds not loaded yet for ' + below.model + ' or ' + target.model + ' -- try again in a moment'); return; }
    target.z = round2(below.z + mb.bounds.maxz - mt.bounds.minz);
    saveStore(); renderParts(); rebuildScene();
  }
  function setAsBase(i){
    if (i < 1 || parts[i].ptype === 'fx') return;
    var p = parts.splice(i, 1)[0];
    parts.unshift(p);
    selected = 0;
    saveStore(); renderParts(); rebuildScene();
  }

  // ---------- keyboard on the selected part ----------
  document.addEventListener('keydown', function(ev){
    if (selected < 0 || !parts[selected]) return;
    var ae = document.activeElement;
    if (ae && /^(INPUT|TEXTAREA|SELECT)$/.test(ae.tagName)) return;
    var unit = ev.shiftKey ? 5 : (ev.altKey ? 0.25 : 1);
    var deg = ev.shiftKey ? 15 : (ev.altKey ? 1 : 5);
    var p = parts[selected], used = true, isFx = p.ptype === 'fx';
    switch (ev.key) {
      case 'ArrowLeft': if (isFx) p.ox -= unit; else p.x -= unit; break;
      case 'ArrowRight': if (isFx) p.ox += unit; else p.x += unit; break;
      case 'ArrowUp': if (isFx) p.oy += unit; else p.y += unit; break;
      case 'ArrowDown': if (isFx) p.oy -= unit; else p.y -= unit; break;
      case 'PageUp': if (isFx) p.oz += unit; else p.z += unit; break;
      case 'PageDown': if (isFx) p.oz -= unit; else p.z -= unit; break;
      case 'q': case 'Q': if (!isFx) p.yaw -= deg; else used = false; break;
      case 'e': case 'E': if (!isFx) p.yaw += deg; else used = false; break;
      case 'r': case 'R': if (!isFx) p.pitch -= deg; else used = false; break;
      case 'f': case 'F': if (!isFx) p.pitch += deg; else used = false; break;
      case 'z': case 'Z': if (!isFx) p.roll -= deg; else used = false; break;
      case 'c': case 'C': if (!isFx) p.roll += deg; else used = false; break;
      default: used = false;
    }
    if (used) { ev.preventDefault(); saveStore(); renderParts(); rebuildScene(); }
  });

  function updateReadout(){
    var el = document.getElementById('readout');
    if (selected < 0 || !parts[selected]) { el.textContent = 'nothing selected'; return; }
    var p = parts[selected];
    if (p.ptype === 'fx') {
      el.textContent = p.name + ' | parent ' + p.parent + ' | ' + p.ox + ' ' + p.oy + ' ' + p.oz + (p.rule ? ('  -- ' + p.rule) : '');
    } else {
      el.textContent = p.kind + ' | ' + p.model + ' | ' + p.x + ' ' + p.y + ' ' + p.z + ' | ' + p.pitch + ' ' + p.yaw + ' ' + p.roll;
    }
  }

  // ---------- export / import ----------
  function round05(n){ return Math.round(n * 2) / 2; }
  function gscText(){
    if (!parts.length) return '';
    var modelParts = parts.filter(function(p){ return p.ptype !== 'fx' && !p.anchor; });
    var lines = modelParts.map(function(p){
      var dx = 0, dy = 0, dz = 0, yaw = p.yaw;
      // A part's own df_model_def offset is only meaningful relative to ANOTHER part when it carries an
      // explicit .parent (relay_coil / relay_mast / relay_top, per df_model_offset's own registry): undo the
      // parent's yaw the same way df_model_offset_at() rotates the stored offset BY the parent's yaw, so the
      // exported numbers match the registry regardless of how the parent itself is turned in this scene
      // (e.g. the relay sitting at -45 on a loaded table).
      if (p.parent) {
        var parent = findParentPart(p.parent);
        if (parent) {
          var loc = rotateXY(p.x - parent.x, p.y - parent.y, -parent.yaw);
          dx = round05(loc[0]); dy = round05(loc[1]); dz = round05(p.z - parent.z);
          yaw = round2(p.yaw - parent.yaw);
        }
      }
      return 'df_model_def( "' + p.kind + '", "' + p.model + '", ' + p.pitch + ', ' + p.roll + ', ' + yaw + ', ( ' + dx + ', ' + dy + ', ' + dz + ' ) );';
    });

    // Table-slot occupants (a part carrying .slot, 0/1/2) are the slot REGISTRY (df_table_slots_init in
    // df_coords.gsc), so they export as ready-to-paste df_table_slot_def lines instead of a df_model_def line:
    // the offset in the TABLE's own frame (the table's yaw undone, like any other child part) with z measured
    // from the table TOP, which is exactly what df_table_slot( n ) adds back.
    var slotted = parts.filter(function(p){ return p.ptype !== 'fx' && typeof p.slot === 'number'; }).slice().sort(function(a, b){ return a.slot - b.slot; });
    if (slotted.length) {
      var tablePart = findParentPart('table');
      lines.push('');
      lines.push('// table layout (df_table_slot_def in df_coords.gsc, df_table_slots_init(); z from the table top ' + TABLE_TOP_Z + ')');
      slotted.forEach(function(p){
        var lx = p.x, ly = p.y, lz = p.z - TABLE_TOP_Z;
        if (tablePart) {
          var loc = rotateXY(p.x - tablePart.x, p.y - tablePart.y, -tablePart.yaw);
          lx = loc[0]; ly = loc[1]; lz = p.z - tablePart.z - TABLE_TOP_Z;
        }
        lines.push('df_table_slot_def( ' + p.slot + ', ( ' + round05(lx) + ', ' + round05(ly) + ', ' + round05(lz) + ' ) ); // ' + p.kind);
      });
    }

    // Every fx point, offset in its parent's own frame minus its base (the parent's glTF top/rim bound, or
    // another point's own resolved offset -- see baseX/baseY/baseZ), so the export matches df_fx_point_def's
    // own registry convention. A point drawn more than once (tower_column_side) exports once.
    var fxParts = parts.filter(function(p){ return p.ptype === 'fx'; });
    var seen = {}, fxLines = [];
    fxParts.forEach(function(p){
      if (seen[p.name]) return;
      seen[p.name] = true;
      var rx = round05(p.ox - (p.baseX || 0)), ry = round05(p.oy - (p.baseY || 0)), rz = round05(p.oz - (p.baseZ || 0));
      fxLines.push('df_fx_point_def( "' + p.name + '", "' + p.parent + '", ( ' + rx + ', ' + ry + ', ' + rz + ' ) );');
    });
    if (fxLines.length) {
      lines.push('');
      lines.push('// effect / sound attach points (df_fx_point_def in df_coords.gsc, df_fx_points_init())');
      lines.push.apply(lines, fxLines);
    }
    return lines.join('\n');
  }
  function sceneText(){
    return parts.map(function(p){
      if (p.ptype === 'fx') return 'fx | ' + p.name + ' | ' + p.parent + ' | ' + p.ox + ' ' + p.oy + ' ' + p.oz;
      return p.kind + ' | ' + p.model + ' | ' + p.x + ' ' + p.y + ' ' + p.z + ' | ' + p.pitch + ' ' + p.yaw + ' ' + p.roll;
    }).join('\n');
  }
  function updateExport(){
    document.getElementById('gscOut').textContent = gscText();
    document.getElementById('sceneOut').textContent = sceneText();
  }
  function copyText(t, btn){
    function done(){ var old = btn.textContent; btn.textContent = 'Copied'; setTimeout(function(){ btn.textContent = old; }, 1500); }
    if (navigator.clipboard) { navigator.clipboard.writeText(t).then(done, function(){ prompt('Copy this:', t); }); }
    else { prompt('Copy this:', t); }
  }
  document.getElementById('copyGsc').addEventListener('click', function(){ copyText(gscText(), this); });
  document.getElementById('copyScene').addEventListener('click', function(){ copyText(sceneText(), this); });
  document.getElementById('importBtn').addEventListener('click', function(){
    var lines = document.getElementById('importIn').value.split('\n').map(function(l){ return l.trim(); }).filter(Boolean);
    var np = [];
    lines.forEach(function(l){
      var seg = l.split('|').map(function(s){ return s.trim(); });
      if (seg[0] === 'fx') {
        if (seg.length < 4) return;
        var fxyz = seg[3].split(/\s+/).map(Number);
        var reg = FX_REGISTRY[seg[1]] || {};
        np.push({
          ptype: 'fx', name: seg[1], parent: seg[2] || reg.parent || '',
          ox: fxyz[0] || 0, oy: fxyz[1] || 0, oz: fxyz[2] || 0,
          baseX: reg.baseX || 0, baseY: reg.baseY || 0, baseZ: reg.baseZ || 0,
          sound: reg.sound || 0, rule: reg.rule || ''
        });
        return;
      }
      if (seg.length < 4) return;
      var xyz = seg[2].split(/\s+/).map(Number), pyr = seg[3].split(/\s+/).map(Number);
      np.push({ ptype: 'model', kind: seg[0], model: seg[1], x: xyz[0] || 0, y: xyz[1] || 0, z: xyz[2] || 0, pitch: pyr[0] || 0, yaw: pyr[1] || 0, roll: pyr[2] || 0 });
    });
    if (np.length) { parts = np; selected = 0; saveStore(); renderParts(); rebuildScene(); }
  });

  // ---------- presets ----------
  function applyPreset(key){
    var preset = PRESETS[key];
    if (!preset) return;
    parts = preset.parts.map(function(p){ var c = {}; for (var k in p) c[k] = p[k]; return c; });
    selected = parts.length ? 0 : -1;
    var note = document.getElementById('presetNote'); if (note) note.textContent = preset.note || '';
    saveStore(); renderParts(); rebuildScene();
    var baseModel = parts.length && parts[0].ptype !== 'fx' ? parts[0].model : null;
    var needsTop = parts.some(function(p){ return p.ptype !== 'fx' && p.snapTop; });
    if (needsTop && baseModel) {
      ensureModel(baseModel, function(entry){
        var topZ = entry ? entry.bounds.maxz : 0;
        parts.forEach(function(p){ if (p.ptype !== 'fx' && p.snapTop) p.z = topZ; });
        saveStore(); renderParts(); rebuildScene();
      });
    }
  }
  document.getElementById('presetSel').addEventListener('change', function(){
    var key = this.value;
    if (key === 'empty') {
      parts = []; selected = -1;
      var note = document.getElementById('presetNote'); if (note) note.textContent = 'Empty scene.';
      saveStore(); renderParts(); rebuildScene();
    } else if (key) { applyPreset(key); }
    this.value = '';
  });

  // ---------- boot ----------
  var saved = loadStore();
  if (saved && saved.parts && saved.parts.length) { parts = saved.parts; selected = (typeof saved.sel === 'number') ? saved.sel : 0; }
  renderParts();
  rebuildScene();
})();
</script>
HTMLEOF

$template =~ s/\Q__LIST__\E/$list/;
$template =~ s/\Q__SCRIPTS__\E/$scripts/;
$template =~ s/\Q__PRESETS_JSON__\E/$presets_json/;
$template =~ s/\Q__FX_REGISTRY_JSON__\E/$fx_registry_json/;
$template =~ s/\Q__TABLE_TOP_Z__\E/$table_top_z/;
$template =~ s/\Q__PRESET_OPTIONS__\E/$preset_options/;
$template =~ s/\Q__FOOTER__\E/$footer_note/;

print $template;
