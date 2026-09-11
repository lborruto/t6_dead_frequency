use strict;
use warnings;

# usage: perl dur.pl aliases.txt -> alias, duration (s) of the first extracted file, or "no file"
my $csv = 'so_zclassic_zm_transit/soundbank/zmb_classic_transit.all.aliases.csv';
my @roots = ( 'so_zclassic_zm_transit', 'patch_zm', 'common_zm' );
my %want;
open my $w, '<', $ARGV[0] or die;
while (<$w>) { chomp; $want{$_} = 1 if length }
close $w;

my %file;
for my $c ( $csv, 'patch_zm/soundbank/zmb_patch.all.aliases.csv' ) {
    open my $h, '<', $c or next;
    my $head = <$h>;
    while (<$h>) {
        chomp;
        my @f = split /,/, $_, -1;
        next unless $want{ $f[0] };
        push @{ $file{ $f[0] } }, $f[1] if length $f[1];
    }
    close $h;
}

sub wav_dur {
    my ($p) = @_;
    open my $fh, '<:raw', $p or return undef;
    my $buf;
    read $fh, $buf, 12;
    return undef unless substr( $buf, 0, 4 ) eq 'RIFF';
    my ( $rate, $brate, $data );
    while ( read( $fh, $buf, 8 ) == 8 ) {
        my ( $id, $sz ) = unpack 'a4 V', $buf;
        if ( $id eq 'fmt ' ) {
            read $fh, $buf, $sz;
            ( $rate, $brate ) = ( unpack( 'v v V V', $buf ) )[ 2, 3 ];
        }
        elsif ( $id eq 'data' ) { $data = $sz; last }
        else { seek $fh, $sz + ( $sz % 2 ), 1 }
    }
    return undef unless $brate && defined $data;
    return $data / $brate;
}

sub flac_dur {
    my ($p) = @_;
    open my $fh, '<:raw', $p or return undef;
    my $buf;
    read $fh, $buf, 4;
    return undef unless $buf eq 'fLaC';
    read $fh, $buf, 4;    # block header
    read $fh, $buf, 34;   # STREAMINFO
    my @b = unpack 'C*', substr( $buf, 10, 8 );
    my $rate = ( $b[0] << 12 ) | ( $b[1] << 4 ) | ( $b[2] >> 4 );
    my $samples = ( ( $b[3] & 0x0F ) * 2**32 ) + ( ( $b[4] << 24 ) | ( $b[5] << 16 ) | ( $b[6] << 8 ) | $b[7] );
    return undef unless $rate;
    return $samples / $rate;
}

for my $a ( sort keys %want ) {
    my $out = 'no row';
    if ( $file{$a} ) {
        $out = 'no file';
        for my $src ( @{ $file{$a} } ) {
            my $rel = $src;
            $rel =~ s/\\/\//g;
            $rel =~ s{^raw/sound/}{};
            my $found;
            for my $r (@roots) {
                for my $cand ( "$r/sound/$rel", "$r/sound/$rel.wav", "$r/sound/$rel.flac" ) {
                    if ( -f $cand ) { $found = $cand; last }
                }
                last if $found;
            }
            next unless $found;
            my $d = $found =~ /\.flac$/ ? flac_dur($found) : wav_dur($found);
            $d = wav_dur($found) // flac_dur($found) unless defined $d;
            $out = defined $d ? sprintf( '%.2f s', $d ) : 'unreadable';
            last;
        }
    }
    printf "%-34s %s\n", $a, $out;
}
