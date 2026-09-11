use strict;
use warnings;

# shrink.pl <in.wav> <out.wav>: 16-bit PCM WAV -> mono, half sample rate (pairs averaged), 16-bit. Other formats: copy.
my ( $in, $out ) = @ARGV;
open my $fh, '<:raw', $in or die "$in: $!";
local $/;
my $data = <$fh>;
close $fh;

if ( substr( $data, 0, 4 ) ne 'RIFF' ) {
    open my $o, '>:raw', $out or die;
    print $o $data;
    close $o;
    exit 0;
}

my $pos = 12;
my ( $fmt, $ch, $rate, $bits, $pcm );
while ( $pos + 8 <= length $data ) {
    my ( $id, $sz ) = unpack 'a4 V', substr( $data, $pos, 8 );
    my $body = substr( $data, $pos + 8, $sz );
    if ( $id eq 'fmt ' ) {
        ( $fmt, $ch, $rate ) = unpack 'v v V', $body;
        $bits = unpack 'v', substr( $body, 14, 2 );
    }
    elsif ( $id eq 'data' ) { $pcm = $body; last }
    $pos += 8 + $sz + ( $sz % 2 );
}

if ( !defined $pcm || $fmt != 1 || $bits != 16 ) {
    open my $o, '>:raw', $out or die;
    print $o $data;
    close $o;
    exit 0;
}

my @s = unpack 's<*', $pcm;
my @mono;
if ( $ch == 2 ) {
    for ( my $i = 0 ; $i + 1 < @s ; $i += 2 ) { push @mono, ( $s[$i] + $s[ $i + 1 ] ) / 2 }
}
else { @mono = @s }

my @half;
for ( my $i = 0 ; $i + 1 < @mono ; $i += 2 ) { push @half, int( ( $mono[$i] + $mono[ $i + 1 ] ) / 2 ) }
my $nrate = int( $rate / 2 );
my $body  = pack 's<*', @half;
my $fmtc  = pack 'v v V V v v', 1, 1, $nrate, $nrate * 2, 2, 16;
my $wav   = 'RIFF' . pack( 'V', 4 + 8 + length($fmtc) + 8 + length($body) ) . 'WAVE' . 'fmt ' . pack( 'V', length $fmtc ) . $fmtc . 'data' . pack( 'V', length $body ) . $body;
open my $o, '>:raw', $out or die;
print $o $wav;
close $o;
