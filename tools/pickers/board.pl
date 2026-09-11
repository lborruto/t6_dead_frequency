use strict;
use warnings;

# board.pl: for every alias in board_dur.txt (alias, duration) find its extracted file and print
# alias \t file \t bytes \t duration \t pan \t distmin \t distmax \t volume
my %dur;
open my $d, '<', 'board_dur.txt' or die;
while (<$d>) { my ( $a, $s ) = split; $dur{$a} = $s }
close $d;

my %seen;
for my $csv ( 'so_zclassic_zm_transit/soundbank/zmb_classic_transit.all.aliases.csv', 'patch_zm/soundbank/zmb_patch.all.aliases.csv' ) {
    open my $h, '<', $csv or die;
    my $head = <$h>;
    chomp $head;
    my @cols = split /,/, $head;
    my %ix;
    $ix{ $cols[$_] } = $_ for 0 .. $#cols;
    while (<$h>) {
        chomp;
        my @f = split /,/, $_, -1;
        my $a = $f[ $ix{Name} ];
        next unless exists $dur{$a};
        next if $seen{$a}++;
        my $rel = $f[ $ix{FileSource} ];
        $rel =~ s/\\/\//g;
        $rel =~ s{^raw/sound/}{};
        my $found;
        for my $r ( 'so_zclassic_zm_transit', 'patch_zm' ) {
            if ( -f "$r/sound/$rel" ) { $found = "$r/sound/$rel"; last }
        }
        next unless $found;
        print join( "\t", $a, $found, -s $found, $dur{$a}, $f[ $ix{PanType} ], $f[ $ix{DistMin} ], $f[ $ix{DistMaxDry} ], $f[ $ix{VolMax} ] ), "\n";
    }
    close $h;
}
