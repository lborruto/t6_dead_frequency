use strict;
use warnings;
use File::Basename qw(basename);

# Rebuilds tools/assets/xmodels_zm_transit.txt from the OAT Unlinker --list dumps, distinguishing the zone that
# OWNS a mesh from zones that merely reference it. Usage: perl tools/gen_xmodel_owners.pl <folder with *.list.txt>
my $dir = shift or die "usage: gen_xmodel_owners.pl <list folder>\n";
my (%own, %ref);

for my $f (glob("$dir/*.list.txt")) {
    my $z = basename($f, '.list.txt');
    open my $h, '<', $f or next;

    while (my $l = <$h>) {
        chomp $l;
        next unless $l =~ s/^xmodel, //;

        if ($l =~ s/^,//) { $ref{$l}{$z} = 1 }   # "xmodel, ,name" = reference stub, mesh lives in another zone
        else              { $own{$l}{$z} = 1 }   # "xmodel, name"  = this zone carries the mesh
    }

    close $h;
}

my @always = qw(zm_transit so_zclassic_zm_transit common_zm patch_zm zm_transit_patch);
sub is_always { my @z = @_; for my $z (@z) { for my $a (@always) { return 1 if $z eq $a } } return 0 }

open my $o, '>', 'tools/assets/xmodels_zm_transit.txt' or die;
print $o <<'HDR';
# xmodel OWNERSHIP in the TranZit fastfiles (OAT Unlinker --list, regenerated 2026-09-08).
# model | owner zone(s), i.e. where the MESH lives | ALWAYS or STREAMED | zones that only reference it
#
# ALWAYS   = an owner zone stays loaded all game (zm_transit, so_zclassic_zm_transit, common_zm, patch_zm,
#            zm_transit_patch). Safe to precachemodel and spawn anywhere on the map.
# STREAMED = the mesh is owned by a zm_transit_gump_<area> package. Only about four area packages are resident at
#            a time (there are four zm_transit_gump_prealloc slots), so outside that area the mesh is not in memory
#            and a spawned model shows as nothing or a black box, EVEN when the main zone references it and its
#            materials and images are always loaded. That is the p_jun_old_tv case: the mesh belongs to
#            zm_transit_gump_farm while mc/mtl_p_jun_old_tv and its two images belong to zm_transit.
HDR

for my $m (sort keys %own) {
    my @o = sort keys %{ $own{$m} };
    my @r = $ref{$m} ? sort keys %{ $ref{$m} } : ();
    printf $o "%s\t%s\t%s\t%s\n", $m, join(',', @o), (is_always(@o) ? 'ALWAYS' : 'STREAMED'), (@r ? join(',', @r) : '-');
}

close $o;
my $n = scalar keys %own;
my $a = grep { is_always(sort keys %{ $own{$_} }) } keys %own;
print "$n models: $a ALWAYS, ", $n - $a, " STREAMED\n";
