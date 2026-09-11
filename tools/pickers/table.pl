use strict;
use warnings;

# usage: perl table.pl want.txt  -> compact table of the bank rows for those aliases
my $csv = 'so_zclassic_zm_transit/soundbank/zmb_classic_transit.all.aliases.csv';
my %want;
open my $w, '<', $ARGV[0] or die;
while (<$w>) { chomp; $want{$_} = 1 if length }
close $w;

open my $h, '<', $csv or die;
my $head = <$h>;
chomp $head;
my @cols = split /,/, $head;
my %ix;
$ix{ $cols[$_] } = $_ for 0 .. $#cols;
my %rows;
while (<$h>) {
    chomp;
    my @f = split /,/, $_, -1;
    my $n = $f[ $ix{Name} ];
    push @{ $rows{$n} }, \@f if $want{$n};
}
close $h;

printf "%-34s %2s %-58s %-8s %-7s %5s %5s %-3s %-4s %3s %s\n", 'alias', 'n', 'file', 'stor', 'vol', 'dmin', 'dmax', 'pan', 'loop', 'lim', 'bus';
for my $a ( sort keys %want ) {
    if ( !$rows{$a} ) { printf "%-34s -- NOT IN BANK\n", $a; next }
    my @r = @{ $rows{$a} };
    for my $f ( @r[ 0 .. ( @r > 2 ? 1 : $#r ) ] ) {
        my $file = $f->[ $ix{FileSource} ];
        $file =~ s/^raw\\sound\\//;
        $file = substr( $file, -58 ) if length $file > 58;
        printf "%-34s %2d %-58s %-8s %-7s %5s %5s %-3s %-4s %3s %s\n", $a, scalar @r, $file, $f->[ $ix{Storage} ],
          $f->[ $ix{VolMin} ] . '-' . $f->[ $ix{VolMax} ], $f->[ $ix{DistMin} ], $f->[ $ix{DistMaxDry} ],
          $f->[ $ix{PanType} ], substr( $f->[ $ix{Looping} ], 0, 4 ), $f->[ $ix{LimitCount} ], $f->[ $ix{Bus} ];
    }
}
