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
# always-loaded zones the Prop Picker uses, and df_coords.gsc (df_models_init / df_model_def / df_table_slot*)
# for the three preset assemblies' exact offsets. Nothing here writes to df_coords.gsc or any other repo file;
# it only reads them to build the static HTML page.

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
#      df_table_slot_spacing() { return N; } -- these feed the three preset assemblies below. -------------
open my $cf, '<', $coords or die "$coords: $!";
local $/;
my $gsc = <$cf>;
close $cf;

my %model_def;    # kind -> { name, pitch, roll, yawoff, ox, oy, oz }
while ( $gsc =~ /df_model_def\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*(?:,\s*\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*)?\)\s*;/g ) {
    $model_def{$1} = { name => $2, pitch => $3 + 0, roll => $4 + 0, yawoff => $5 + 0, ox => ( $6 // 0 ) + 0, oy => ( $7 // 0 ) + 0, oz => ( $8 // 0 ) + 0 };
}
die "df_models_init(): no df_model_def(...) lines found in $coords\n" unless %model_def;

my ($table_spacing) = $gsc =~ /df_table_slot_spacing\(\)\s*\{\s*return\s+(-?[\d.]+)\s*;/;
$table_spacing = defined($table_spacing) ? $table_spacing + 0 : 18;

# df_model_top_z()'s "tops" lookup and df_model_rest_z()'s "rest" lookup (both keyed by MODEL NAME, not kind)
# -- read here the same way df_model_def(...) is, so the "Table, Richtofen/Maxis loaded" presets' slot Z and
# card/skull/orb lift stay correct if the table or item models are ever swapped in the registry.
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
# df_table_demo_spawn's own card lift ( df_table_demo_prop( "card", df_table_slot(1), ( 0, 0, <this> ) ) ); the
# orb's lift is df_model_rest_z( "orb" ), already covered by %rest_z_by_model above.
my ($card_lift) = $gsc =~ /df_table_demo_prop\(\s*"card"\s*,\s*df_table_slot\(\s*1\s*\)\s*,\s*\(\s*0\s*,\s*0\s*,\s*(-?[\d.]+)\s*\)\s*\)/;
$card_lift = defined($card_lift) ? $card_lift + 0 : 8;

for my $kind (qw(relay relay_top relay_coil relay_mast table brazier ember card skull orb)) {
    die "df_model_def for kind \"$kind\" not found in $coords -- needed for a preset\n" unless $model_def{$kind};
}

my $table_top_z = $top_z_by_model{ $model_def{table}{name} };
die "df_model_top_z: no tops[] entry for table model \"$model_def{table}{name}\" in $coords -- needed for the table presets\n"
    unless defined $table_top_z;
my $orb_rest   = $rest_z_by_model{ $model_def{orb}{name} }   // 0;
my $skull_rest = $rest_z_by_model{ $model_def{skull}{name} } // 0;

printf STDERR "df_coords.gsc: relay=%s(0,0,0) relay_coil=%s(0,0,%s) relay_mast=%s(0,0,%s) relay_top=%s(0,0,%s) table_slot_spacing=%s brazier=%s ember=%s(offset 0,0,0)\n",
    $model_def{relay}{name}, $model_def{relay_coil}{name}, $model_def{relay_coil}{oz}, $model_def{relay_mast}{name}, $model_def{relay_mast}{oz},
    $model_def{relay_top}{name}, $model_def{relay_top}{oz}, $table_spacing, $model_def{brazier}{name}, $model_def{ember}{name};
printf STDERR "df_coords.gsc: table=%s top_z=%s front_yaw=%s card=%s(pitch %s, lift %s) skull=%s(rest %s) orb=%s(rest %s)\n",
    $model_def{table}{name}, $table_top_z, $table_front_yaw, $model_def{card}{name}, $model_def{card}{pitch}, $card_lift,
    $model_def{skull}{name}, $skull_rest, $model_def{orb}{name}, $orb_rest;

# The preset's own models must be embedded no matter what the size budget below does to the general list.
my %required = map { $model_def{$_}{name} => 1 } qw(relay relay_coil relay_mast table brazier ember card skull orb);

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

# ---- the three preset assemblies + Empty, as data for the page's PRESETS object -------------------------
# "table" and "tombstone" presets need the base model's own top bound (df_model_top_z equivalent), which is
# only knowable from the glTF mesh bounds, so those parts carry snapTop:1 and the page resolves their Z at
# load time from the base model's live bounds (mirrors df_model_top_z / df_m2_rim_height in df_coords.gsc /
# df_act2_maxis.gsc, which likewise derive it from the measured glTF bounds, not a stored constant).
# Rotates an (x,y,z) stacking offset by a yaw in degrees -- the same 2D rotation df_offset_rotate() in
# df_coords.gsc applies (via df_model_offset_at) to a piece's registered offset when its parent is turned.
sub df_rotate_offset {
    my ( $ox, $oy, $oz, $yaw_deg ) = @_;
    my $rad = $yaw_deg * 3.14159265358979323846 / 180;
    my $c   = cos($rad);
    my $s   = sin($rad);
    return ( $ox * $c - $oy * $s, $ox * $s + $oy * $c, $oz );
}
sub r2 { my $n = shift; return int( $n * 100 + ( $n >= 0 ? 0.5 : -0.5 ) ) / 100; }

# df_table_slot( n ) in df_coords.gsc: c.origin + right * ( (n-1) * df_table_slot_spacing() ) + (0,0,df_model_top_z("table")),
# where right = anglestoright( (0, df_table_yaw(), 0) ). At yaw 0 the engine's right vector is (0,-1,0) (X-forward,
# Z-up, right-handed: forward x up = (1,0,0) x (0,0,1) = (0,-1,0)); df_rotate_offset() turns that with table_front_yaw
# the same way it turns any other registered offset. "n=0 is on the left looking along the table's front"
# (df_table_preview_slots) checks out: left = -right, so slot 0 = right * (-spacing) sits on the left.
my ( $right_x, $right_y ) = df_rotate_offset( 0, -1, 0, $table_front_yaw );
sub table_slot_xyz {
    my ($n) = @_;
    my $mult = ( $n - 1 ) * $table_spacing;
    return ( r2( $right_x * $mult ), r2( $right_y * $mult ), $table_top_z );
}
my @slot0 = table_slot_xyz(0);
my @slot1 = table_slot_xyz(1);
my @slot2 = table_slot_xyz(2);

# The relay sits 45 degrees off the table's front on slot 0 (df_a1_relay_spawn: "yaw = yaw - 45"; df_table_demo_prop:
# same, "the relay pieces sit at 45 degrees on the table"); relay_coil / relay_mast ride at their registered
# df_model_offset, turned the same way (df_model_offset_at / df_offset_rotate).
my $relay_yaw = $table_front_yaw - 45;
my ( $coil_ox, $coil_oy, $coil_oz ) = df_rotate_offset( $model_def{relay_coil}{ox}, $model_def{relay_coil}{oy}, $model_def{relay_coil}{oz}, $relay_yaw );
my ( $mast_ox, $mast_oy, $mast_oz ) = df_rotate_offset( $model_def{relay_mast}{ox}, $model_def{relay_mast}{oy}, $model_def{relay_mast}{oz}, $relay_yaw );
my @relay_pos      = ( r2( $slot0[0] ),               r2( $slot0[1] ),               r2( $slot0[2] ) );
my @relay_coil_pos = ( r2( $slot0[0] + $coil_ox ),     r2( $slot0[1] + $coil_oy ),     r2( $slot0[2] + $coil_oz ) );
my @relay_mast_pos = ( r2( $slot0[0] + $mast_ox ),     r2( $slot0[1] + $mast_oy ),     r2( $slot0[2] + $mast_oz ) );
my $relay_coil_yaw = $relay_yaw + $model_def{relay_coil}{yawoff};
my $relay_mast_yaw = $relay_yaw + $model_def{relay_mast}{yawoff};

# card / skull sit on slot 1, not turned with the relay (df_table_demo_prop only turns the relay kinds); their
# own yaw is just the table's front yaw plus the kind's own df_model_def yaw offset (0 for both).
my $card_yaw  = $table_front_yaw + $model_def{card}{yawoff};
my $skull_yaw = $table_front_yaw + $model_def{skull}{yawoff};
my @card_pos  = ( r2( $slot1[0] ), r2( $slot1[1] ), r2( $slot1[2] + $card_lift ) );
my @skull_pos = ( r2( $slot1[0] ), r2( $slot1[1] ), r2( $slot1[2] + $skull_rest ) );

# orb sits on slot 2 (both sides), hovering df_model_rest_z( "orb" ) above the slot (df_table_demo_prop's own orb line).
my $orb_yaw  = $table_front_yaw + $model_def{orb}{yawoff};
my @orb_pos  = ( r2( $slot2[0] ), r2( $slot2[1] ), r2( $slot2[2] + $orb_rest ) );

my %presets = (
    relay => {
        label => 'Relay (roof and table)',
        note  => 'From df_models_init() in df_coords.gsc: base = kind "relay" ('
          . $model_def{relay}{name}
          . ') at (0,0,0); coil = kind "relay_coil" (' . $model_def{relay_coil}{name} . '), df_model_offset (0,0,' . $model_def{relay_coil}{oz}
          . '); mast = kind "relay_mast" (' . $model_def{relay_mast}{name} . '), df_model_offset (0,0,' . $model_def{relay_mast}{oz}
          . ') -- the same offset (0,0,' . $model_def{relay_top}{oz} . ') is registered for kind "relay_top" (the roof placement of the same mast).',
        parts => [
            { kind => 'relay',      model => $model_def{relay}{name},      x => 0, y => 0, z => 0,                        pitch => $model_def{relay}{pitch},      roll => $model_def{relay}{roll},      yaw => 0 },
            { kind => 'relay_coil', model => $model_def{relay_coil}{name}, x => 0, y => 0, z => $model_def{relay_coil}{oz}, pitch => $model_def{relay_coil}{pitch}, roll => $model_def{relay_coil}{roll}, yaw => 0 },
            { kind => 'relay_mast', model => $model_def{relay_mast}{name}, x => 0, y => 0, z => $model_def{relay_mast}{oz}, pitch => $model_def{relay_mast}{pitch}, roll => $model_def{relay_mast}{roll}, yaw => 0 },
        ],
    },
    table => {
        label => 'Table with three slots',
        note  => 'Base = kind "table" (' . $model_def{table}{name} . ') at (0,0,0). Three slot markers ('
          . 'p6_zm_buildable_sq_meteor) at X = (n-1) * df_table_slot_spacing() = -' . $table_spacing . ', 0, +' . $table_spacing
          . ' (df_table_slot_spacing() in df_coords.gsc returns ' . $table_spacing
          . '); Z is the table model\'s own top bound, computed live from its glTF bounds when this preset loads (what df_model_top_z("table") '
          . 'computes at runtime from the same glTF). Yaw is 0 here: df_table_yaw() depends on the placed table\'s in-level angle, not on a standalone preview.',
        parts => [
            { kind => 'table', model => $model_def{table}{name},        x => 0,                y => 0, z => 0, pitch => $model_def{table}{pitch}, roll => $model_def{table}{roll}, yaw => 0 },
            { kind => 'slot_0', model => 'p6_zm_buildable_sq_meteor', x => -1 * $table_spacing, y => 0, z => 0, pitch => 0, roll => 0, yaw => 0, snapTop => 1 },
            { kind => 'slot_1', model => 'p6_zm_buildable_sq_meteor', x => 0,                    y => 0, z => 0, pitch => 0, roll => 0, yaw => 0, snapTop => 1 },
            { kind => 'slot_2', model => 'p6_zm_buildable_sq_meteor', x => 1 * $table_spacing,  y => 0, z => 0, pitch => 0, roll => 0, yaw => 0, snapTop => 1 },
        ],
    },
    table_rich => {
        label => 'Table, Richtofen loaded',
        note  => 'Base = kind "table" (' . $model_def{table}{name} . ') at (0,0,0), front yaw ' . $table_front_yaw
          . ' (df_apply_overrides\' df_coord_override_ground_front for DF_TABLE). Slot Z = df_model_top_z("table") = '
          . $table_top_z . ', spacing = df_table_slot_spacing() = ' . $table_spacing
          . '; slot 0 is on the left looking along the table\'s front (right = (0,-1,0) at yaw 0), so slot 0 = ('
          . $slot0[0] . ',' . $slot0[1] . ',' . $slot0[2] . '), slot 1 = (' . $slot1[0] . ',' . $slot1[1] . ',' . $slot1[2]
          . '), slot 2 = (' . $slot2[0] . ',' . $slot2[1] . ',' . $slot2[2] . '). Slot 0: the plugged relay assembly, same '
          . 'math as df_table_demo_prop / df_a1_relay_spawn -- relay turned yaw - 45 = ' . $relay_yaw
          . '; relay_coil at its df_model_offset (' . $model_def{relay_coil}{ox} . ',' . $model_def{relay_coil}{oy} . ',' . $model_def{relay_coil}{oz}
          . ') rotated by that -45 to (' . $coil_ox . ',' . $coil_oy . ',' . $coil_oz . '); relay_mast at its df_model_offset ('
          . $model_def{relay_mast}{ox} . ',' . $model_def{relay_mast}{oy} . ',' . $model_def{relay_mast}{oz} . ') rotated the same way to ('
          . $mast_ox . ',' . $mast_oy . ',' . $mast_oz . '). Slot 1: kind "card" (' . $model_def{card}{name}
          . ') at slot 1 + (0,0,' . $card_lift . ') (df_table_demo_prop\'s own card lift), pitch ' . $model_def{card}{pitch}
          . ' per its df_model_def. Slot 2: kind "orb" (' . $model_def{orb}{name} . ') at slot 2 + (0,0,df_model_rest_z("orb")='
          . $orb_rest . '). The GSC export gives relay_coil / relay_mast offsets relative to the relay part (matching how '
          . 'they are registered), plus a separate "table layout" block for the three slots\' own positions.',
        parts => [
            { kind => 'table',      model => $model_def{table}{name},      x => 0, y => 0, z => 0, pitch => $model_def{table}{pitch}, roll => $model_def{table}{roll}, yaw => $table_front_yaw },
            { kind => 'relay',      model => $model_def{relay}{name},      x => $relay_pos[0],      y => $relay_pos[1],      z => $relay_pos[2],      pitch => $model_def{relay}{pitch},      roll => $model_def{relay}{roll},      yaw => $relay_yaw, slot => 0 },
            { kind => 'relay_coil', model => $model_def{relay_coil}{name}, x => $relay_coil_pos[0], y => $relay_coil_pos[1], z => $relay_coil_pos[2], pitch => $model_def{relay_coil}{pitch}, roll => $model_def{relay_coil}{roll}, yaw => $relay_coil_yaw },
            { kind => 'relay_mast', model => $model_def{relay_mast}{name}, x => $relay_mast_pos[0], y => $relay_mast_pos[1], z => $relay_mast_pos[2], pitch => $model_def{relay_mast}{pitch}, roll => $model_def{relay_mast}{roll}, yaw => $relay_mast_yaw },
            { kind => 'card',       model => $model_def{card}{name},       x => $card_pos[0],       y => $card_pos[1],       z => $card_pos[2],       pitch => $model_def{card}{pitch},       roll => $model_def{card}{roll},       yaw => $card_yaw, slot => 1 },
            { kind => 'orb',        model => $model_def{orb}{name},        x => $orb_pos[0],        y => $orb_pos[1],        z => $orb_pos[2],        pitch => $model_def{orb}{pitch},        roll => $model_def{orb}{roll},        yaw => $orb_yaw, slot => 2 },
        ],
    },
    table_maxis => {
        label => 'Table, Maxis loaded',
        note  => 'Base = kind "table" (' . $model_def{table}{name} . ') at (0,0,0), front yaw ' . $table_front_yaw
          . '. Same slot 0 relay assembly and slot 2 orb as "Table, Richtofen loaded" (see that preset\'s note for the '
          . 'relay math); slot 1 here is kind "skull" (' . $model_def{skull}{name}
          . ', the same model as "orb") instead of the card -- df_coords.gsc has no dedicated df_table_demo_prop line for '
          . 'it, so its lift above the slot uses df_model_rest_z("skull") = ' . $skull_rest
          . ' the same way the orb\'s own hover does, since it is the same base-pivot-free meteor-piece model. Pitch/roll/yaw '
          . 'all 0 per its df_model_def. The GSC export gives relay_coil / relay_mast offsets relative to the relay part, '
          . 'plus a separate "table layout" block for the three slots\' own positions.',
        parts => [
            { kind => 'table',      model => $model_def{table}{name},      x => 0, y => 0, z => 0, pitch => $model_def{table}{pitch}, roll => $model_def{table}{roll}, yaw => $table_front_yaw },
            { kind => 'relay',      model => $model_def{relay}{name},      x => $relay_pos[0],      y => $relay_pos[1],      z => $relay_pos[2],      pitch => $model_def{relay}{pitch},      roll => $model_def{relay}{roll},      yaw => $relay_yaw, slot => 0 },
            { kind => 'relay_coil', model => $model_def{relay_coil}{name}, x => $relay_coil_pos[0], y => $relay_coil_pos[1], z => $relay_coil_pos[2], pitch => $model_def{relay_coil}{pitch}, roll => $model_def{relay_coil}{roll}, yaw => $relay_coil_yaw },
            { kind => 'relay_mast', model => $model_def{relay_mast}{name}, x => $relay_mast_pos[0], y => $relay_mast_pos[1], z => $relay_mast_pos[2], pitch => $model_def{relay_mast}{pitch}, roll => $model_def{relay_mast}{roll}, yaw => $relay_mast_yaw },
            { kind => 'skull',      model => $model_def{skull}{name},      x => $skull_pos[0],      y => $skull_pos[1],      z => $skull_pos[2],      pitch => $model_def{skull}{pitch},      roll => $model_def{skull}{roll},      yaw => $skull_yaw, slot => 1 },
            { kind => 'orb',        model => $model_def{orb}{name},        x => $orb_pos[0],        y => $orb_pos[1],        z => $orb_pos[2],        pitch => $model_def{orb}{pitch},        roll => $model_def{orb}{roll},        yaw => $orb_yaw, slot => 2 },
        ],
    },
    tombstone => {
        label => 'Tombstone + ember',
        note  => 'Base = kind "brazier" (' . $model_def{brazier}{name} . ') at (0,0,0). Ember = kind "ember" ('
          . $model_def{ember}{name} . '), df_model_def offset (0,0,0) -- it already has its own model in df_coords.gsc, so no substitute was '
          . 'needed. Its height on the tombstone (the "rim") is computed at runtime in df_act2_maxis.gsc (df_m2_rim_height -> df_model_top_z("brazier")) '
          . 'from the tombstone\'s own top glTF bound, not a stored df_model_offset, so this preset places it at the base model\'s live top bound too.',
        parts => [
            { kind => 'brazier', model => $model_def{brazier}{name}, x => 0, y => 0, z => 0, pitch => $model_def{brazier}{pitch}, roll => $model_def{brazier}{roll}, yaw => 0 },
            { kind => 'ember',   model => $model_def{ember}{name},   x => 0, y => 0, z => 0, pitch => $model_def{ember}{pitch},   roll => $model_def{ember}{roll},   yaw => 0, snapTop => 1 },
        ],
    },
);
my $presets_json = JSON::PP->new->canonical->encode( \%presets );

my $footer_note = "$count TranZit models embedded (glTF under 420 KB each, zones zm_transit / so_zclassic_zm_transit / common_zm / patch_zm); $dropped dropped to stay under the 16 MB page budget.";

# ---- the page -----------------------------------------------------------------------------------------
my $template = <<'HTMLEOF';
<title>Dead Frequency Prop Composer</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;700&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{--bg:#efece6;--panel:#ffffff;--ink:#1b1e23;--muted:#5d6673;--line:#d9d4ca;--accent:#c96f14;--elec:#1f78b8;--good:#3f8f46;--bar:#e6dfd2;--sel:#fff3e4;--canvas:#dcd7cc}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419;--canvas:#23272d}}
:root[data-theme="dark"]{--bg:#15171b;--panel:#1e2227;--ink:#ece6d9;--muted:#8d96a3;--line:#2c3138;--accent:#e5892f;--elec:#4aa8e8;--good:#7bc47f;--bar:#2a2f36;--sel:#2b2419;--canvas:#23272d}
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
.part-row .kindrow{display:flex;gap:6px;margin-bottom:6px}
.part-row input[type=text],.part-row select{background:var(--panel);color:var(--ink);border:1px solid var(--line);font:12px "IBM Plex Mono",monospace;padding:4px 5px;min-width:0}
.part-row .kindrow input[type=text]{flex:1}
.part-row .kindrow select{flex:1.4}
.part-row .nums{display:grid;grid-template-columns:repeat(6,1fr);gap:4px;margin-bottom:6px}
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
<p class="lede">Pick TranZit models on the left, add them as parts, position each part in the viewer (drag to turn, wheel to zoom, right-drag to pan), then export df_model_def(...) lines for df_coords.gsc. Grid cells are 10 units, the post is a 70-unit player.</p>
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
<div class="hint">Click a model on the left to preview it; "Add as part" drops it into the scene at the origin. Arrows = X/Y by 1, PageUp/PageDown = Z by 1, Q/E = yaw 5&deg; (Shift = 5 units / 15&deg;, Alt = 0.25 unit / 1&deg;) on the selected part.</div>
<div class="diag" id="diag"></div>
</div>
<div class="readout" id="readout">nothing selected</div>
</div>

<div class="right">
<div class="card"><div class="eyebrow">Presets</div>
<div class="presets"><select id="presetSel">
<option value="">Load a preset...</option>
<option value="relay">Relay (roof and table)</option>
<option value="table">Table with three slots</option>
<option value="table_rich">Table, Richtofen loaded</option>
<option value="table_maxis">Table, Maxis loaded</option>
<option value="tombstone">Tombstone + ember</option>
<option value="empty">Empty</option>
</select></div>
<p class="preset-note" id="presetNote"></p>
</div>

<div class="section-h">Parts</div>
<div class="parts" id="parts"></div>

<div class="section-h">Export</div>
<div class="export">
<p class="hint" style="padding:0 0 4px">GSC for Dead Frequency (offsets relative to the base part, rounded to 0.5):</p>
<pre id="gscOut"></pre>
<button class="ghost" type="button" id="copyGsc">Copy GSC</button>
<p class="hint" style="padding:8px 0 4px">Scene text (paste back into "Import scene" below, on this page or another session):</p>
<pre id="sceneOut"></pre>
<button class="ghost" type="button" id="copyScene">Copy scene</button>
<p class="hint" style="padding:8px 0 4px">Import scene:</p>
<textarea id="importIn" placeholder="kind | model | x y z | p y r"></textarea>
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
  var VERSION = 'v2';
  var STORE_KEY = 'df_composer_transit';

  function loadStore(){ try{ return JSON.parse(localStorage.getItem(STORE_KEY)||'null'); }catch(e){ return null; } }
  function saveStore(){ try{ localStorage.setItem(STORE_KEY, JSON.stringify({parts:parts, sel:selected})); }catch(e){} }

  var parts = [];      // {kind,model,x,y,z,pitch,yaw,roll}
  var selected = -1;
  var viewingModel = null;
  var previewGroup = null;

  function newPart(model){
    return { kind: model, model: model, x: 0, y: 0, z: 0, pitch: 0, yaw: 0, roll: 0 };
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
  var GREY = 0xb8b0a2, ACCENT = 0xe5892f;
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
  function toThree(x, y, z){ return new THREE.Vector3(x, z, y); }
  function setPose(obj, p){
    obj.position.copy(toThree(p.x, p.y, p.z));
    var e = new THREE.Euler(
      THREE.MathUtils.degToRad(p.pitch),
      -THREE.MathUtils.degToRad(p.yaw),
      THREE.MathUtils.degToRad(p.roll),
      'YXZ'
    );
    obj.quaternion.setFromEuler(e);
  }

  function clearGroups(){
    for (var i = 0; i < partGroups.length; i++) { if (partGroups[i]) scene.remove(partGroups[i]); }
    partGroups = [];
    if (ghostBox) { scene.remove(ghostBox); ghostBox = null; }
  }

  function updateGhost(bounds){
    if (ghostBox) { scene.remove(ghostBox); ghostBox = null; }
    if (!ok || !parts.length) return;
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
      ensureModel(p.model, function(entry){
        if (!entry || !parts[i] || parts[i] !== p) return;
        var grp = new THREE.Group();
        var clone = entry.tmpl.clone(true);
        var color = (i === selected) ? ACCENT : GREY;
        clone.traverse(function(o){ if (o.isMesh) o.material = new THREE.MeshStandardMaterial({ color: color, roughness: 0.85, metalness: 0.05, side: THREE.DoubleSide }); });
        grp.add(clone);
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
    copy.x += 2; copy.y += 2;
    parts.splice(i + 1, 0, copy); selected = i + 1; saveStore(); renderParts(); rebuildScene();
  }
  function removePart(i){
    parts.splice(i, 1);
    if (selected >= parts.length) selected = parts.length - 1;
    saveStore(); renderParts(); rebuildScene();
  }
  function round2(n){ return Math.round(n * 100) / 100; }
  function snapPart(i){
    if (i < 1) return;
    var below = parts[i - 1], target = parts[i];
    var mb = modelCache[below.model], mt = modelCache[target.model];
    if (!mb || !mt) { mgDiag('snap: model bounds not loaded yet for ' + below.model + ' or ' + target.model + ' -- try again in a moment'); return; }
    target.z = round2(below.z + mb.bounds.maxz - mt.bounds.minz);
    saveStore(); renderParts(); rebuildScene();
  }
  function setAsBase(i){
    if (i < 1) return;
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
    var p = parts[selected], used = true;
    switch (ev.key) {
      case 'ArrowLeft': p.x -= unit; break;
      case 'ArrowRight': p.x += unit; break;
      case 'ArrowUp': p.y += unit; break;
      case 'ArrowDown': p.y -= unit; break;
      case 'PageUp': p.z += unit; break;
      case 'PageDown': p.z -= unit; break;
      case 'q': case 'Q': p.yaw -= deg; break;
      case 'e': case 'E': p.yaw += deg; break;
      default: used = false;
    }
    if (used) { ev.preventDefault(); saveStore(); renderParts(); rebuildScene(); }
  });

  function updateReadout(){
    var el = document.getElementById('readout');
    if (selected < 0 || !parts[selected]) { el.textContent = 'nothing selected'; return; }
    var p = parts[selected];
    el.textContent = p.kind + ' | ' + p.model + ' | ' + p.x + ' ' + p.y + ' ' + p.z + ' | ' + p.pitch + ' ' + p.yaw + ' ' + p.roll;
  }

  // ---------- export / import ----------
  function round05(n){ return Math.round(n * 2) / 2; }
  function gscText(){
    if (!parts.length) return '';
    var base = parts[0];
    // The relay's own sub-parts (relay_coil, relay_mast, relay_top) are registered relative to the RELAY, not
    // whatever part[0] happens to be (e.g. the table in the "Table, Richtofen/Maxis loaded" presets): find the
    // relay part, if any, and use it as their reference so these lines match df_model_offset's own convention.
    var relay = null;
    parts.forEach(function(p){ if (p.kind === 'relay') relay = p; });
    var lines = parts.map(function(p){
      var ref = (relay && (p.kind === 'relay_coil' || p.kind === 'relay_mast' || p.kind === 'relay_top')) ? relay : base;
      var dx = round05(p.x - ref.x), dy = round05(p.y - ref.y), dz = round05(p.z - ref.z);
      return 'df_model_def( "' + p.kind + '", "' + p.model + '", ' + p.pitch + ', ' + p.roll + ', ' + p.yaw + ', ( ' + dx + ', ' + dy + ', ' + dz + ' ) );';
    });
    // Table-slot occupants (a part carrying .slot, 0/1/2) are code (df_table_slot in df_coords.gsc), not registry
    // entries, so they get their own plain-text block of absolute positions instead of a df_model_def line.
    var slotted = parts.filter(function(p){ return typeof p.slot === 'number'; }).slice().sort(function(a, b){ return a.slot - b.slot; });
    if (slotted.length) {
      lines.push('');
      lines.push('// table layout (df_table_slot( n ) in df_coords.gsc -- code, not registry entries)');
      slotted.forEach(function(p){
        lines.push('slot ' + p.slot + ' = ' + p.kind + ' at ( ' + round05(p.x) + ', ' + round05(p.y) + ', ' + round05(p.z) + ' )');
      });
    }
    return lines.join('\n');
  }
  function sceneText(){
    return parts.map(function(p){ return p.kind + ' | ' + p.model + ' | ' + p.x + ' ' + p.y + ' ' + p.z + ' | ' + p.pitch + ' ' + p.yaw + ' ' + p.roll; }).join('\n');
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
      if (seg.length < 4) return;
      var xyz = seg[2].split(/\s+/).map(Number), pyr = seg[3].split(/\s+/).map(Number);
      np.push({ kind: seg[0], model: seg[1], x: xyz[0] || 0, y: xyz[1] || 0, z: xyz[2] || 0, pitch: pyr[0] || 0, yaw: pyr[1] || 0, roll: pyr[2] || 0 });
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
    var baseModel = parts.length ? parts[0].model : null;
    var needsTop = parts.some(function(p){ return p.snapTop; });
    if (needsTop && baseModel) {
      ensureModel(baseModel, function(entry){
        var topZ = entry ? entry.bounds.maxz : 0;
        parts.forEach(function(p){ if (p.snapTop) p.z = topZ; });
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
$template =~ s/\Q__FOOTER__\E/$footer_note/;

print $template;
