use strict;
use warnings;
use File::Basename qw(dirname);

# lint_sounds.pl: every sound alias the df_*.gsc sources play must exist in the game's real alias tables
# (tools/assets/soundbank/*.aliases.csv, dumped from common_zm.ff / patch_zm.ff / so_zclassic_zm_transit.ff with the
# OAT Unlinker, --include-assets soundbank). An alias that is in no bank is silent in game: eight of them were
# found on 2026-09-09 (zmb_elec_arc, zmb_souls_end, "ignite", ...). vox_* aliases live in the english bank whose
# table the unlinker does not resolve: they are accepted when a vanilla TranZit script plays them (the list below).
# Exit code 1 on any unknown alias. Also prints the range of every 3D alias played with playsoundatposition so a
# 150-unit alias at a prop is caught by eye.
my $tools = dirname(__FILE__);
my $repo  = "$tools/..";

my %alias;
my %info;
for my $csv ( glob("$tools/assets/soundbank/*.aliases.csv") ) {
    open my $h, '<', $csv or die "$csv: $!";
    my $head = <$h>;
    chomp $head;
    my @cols = split /,/, $head;
    my %ix;
    $ix{ $cols[$_] } = $_ for 0 .. $#cols;
    while (<$h>) {
        chomp;
        my @f = split /,/, $_, -1;
        my $n = $f[ $ix{Name} ];
        next unless length $n;
        $alias{$n} = 1;
        $info{$n} //= sprintf( '%s %s-%s', $f[ $ix{PanType} ], $f[ $ix{DistMin} ], $f[ $ix{DistMaxDry} ] );
    }
    close $h;
}
die "lint_sounds.pl: no alias tables under tools/assets/soundbank\n" unless %alias;

# vox aliases the vanilla TranZit scripts play (english bank, not in the dumped tables)
my %vox_ok = map { $_ => 1 } qw(
  vox_maxi_avogadro_stab_0 vox_maxi_build_complete_0 vox_maxi_near_corn_0 vox_maxi_power_off_0
  vox_maxi_turbine_2light_on_0 vox_maxi_turbines_out_0 vox_maxi_tv_distress_0
  vox_zmba_sidequest_4emp_mag_0 vox_zmba_sidequest_jet_complete_0 vox_zmba_sidequest_jet_low_0
  vox_zmba_sidequest_near_light_0 vox_zmba_sidequest_power_on_0 vox_zmba_sidequest_zom_lure_0
);

my $bad = 0;
my %seen;
for my $f ( sort glob("$repo/df_*.gsc") ) {
    open my $h, '<', $f or die;
    my $ln = 0;
    while ( my $line = <$h> ) {
        $ln++;
        next if $line =~ m{^\s*//};
        my @found;
        # direct calls
        while ( $line =~ /\b(playsound|playsoundtoplayer|playsoundatposition|playloopsound|playlocalsound|play_sound_at_pos|playsoundwithnotify|df_snd_near|df_a1_tone_near|df_vox_once|df_maxis_vox|df_rich_vox|df_lamp_hum_set)\s*\(\s*(?:[a-z_.\[\]0-9]+\s*,\s*)?"([a-z0-9_]+)"/gi ) {
            push @found, $2;
        }
        # alias tables filled by assignment
        while ( $line =~ /\b(df_tv_tones|df_fuse_snd|df_[a-z0-9_]*snd[a-z0-9_]*|df_[a-z0-9_]*alias[a-z0-9_]*)\s*(?:\[[^\]]*\])?\s*=\s*"([a-z0-9_]+)"/gi ) {
            push @found, $2;
        }
        for my $a (@found) {
            next if $seen{"$f:$a"}++;
            my $name = $f;
            $name =~ s{.*/}{};
            if ( $alias{$a} ) {
                if ( $line =~ /playsoundatposition/ && $info{$a} =~ /3d (\d+)-(\d+)/ && $2 < 300 ) {
                    printf "range  %-16s %5d  %-34s 3D fades out at %s units when played AT a position\n", $name, $ln, $a, $2;
                }
                next;
            }
            if ( $a =~ /^vox_/ ) {
                next if $vox_ok{$a};
                printf "vox?   %-16s %5d  %s  (not a vanilla TranZit vox alias, unverified)\n", $name, $ln, $a;
                next;
            }
            printf "SILENT %-16s %5d  %s  is in no TranZit sound bank\n", $name, $ln, $a;
            $bad++;
        }
    }
    close $h;
}

if ($bad) { print "lint_sounds.pl: $bad silent alias(es)\n"; exit 1 }
print "sounds ok\n";
