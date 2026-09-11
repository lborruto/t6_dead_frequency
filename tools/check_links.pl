# Reports df_* functions called in each df_*.gsc that are defined neither in the file nor in the
# df_* files it #includes (the in-game "Unresolved external" error gsc-tool cannot catch).
# Usage: perl tools/check_links.pl <folder with df_*.gsc>
use strict; use warnings;
my $dir = shift // '.';
my %defs; my %incs;
for my $f (glob("$dir/df_*.gsc")) {
    my ($name) = $f =~ /(df_[a-z0-9_]+)\.gsc$/;
    open my $h, '<', $f or die "$f: $!"; my $src = do { local $/; <$h> }; close $h;
    $defs{$name} = { map { $_ => 1 } $src =~ /^(df_[a-z0-9_]+)\(/mg };
    $incs{$name} = [ $src =~ /^#include scripts\x5czm\x5czm_transit\x5c(df_[a-z0-9_]+);/mg ];
}
my $bad = 0;
for my $name (sort keys %defs) {
    open my $h, '<', "$dir/$name.gsc" or die; my $src = do { local $/; <$h> }; close $h;
    $src =~ s{//[^\n]*}{}g;
    my %visible = %{ $defs{$name} };
    for my $inc (@{ $incs{$name} }) { %visible = (%visible, %{ $defs{$inc} || {} }); }
    my %seen;
    for my $call ($src =~ /\b(df_[a-z0-9_]+)\(/g, $src =~ /::(df_[a-z0-9_]+)/g) {
        next if $visible{$call} || $seen{$call}++;
        print "$name.gsc references $call but no included df file defines it\n"; $bad++;
    }
}
# duplicate definitions across files (all df files share one namespace once included)
my %where;
for my $name (keys %defs) { push @{ $where{$_} }, $name for keys %{ $defs{$name} }; }
for my $fn (sort keys %where) {
    next if @{ $where{$fn} } < 2;
    print "$fn() is defined in more than one file: @{ $where{$fn} }\n"; $bad++;
}
print $bad ? "$bad problem(s)\n" : "links ok\n";
exit($bad ? 1 : 0);
