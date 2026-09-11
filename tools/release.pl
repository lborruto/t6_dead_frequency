#!/usr/bin/perl
# release.pl - build the single-file Dead Frequency GSC and package it for players.
#
# Produces <project>\release\ holding:
#   zm_transit_dead_frequency.gsc   the merged script (built fresh by tools/build.pl, gsc-tool checked)
#   README.md                       the project README (copied)
#   INSTALL.txt                     where to put the file, what must NOT be in the load path, how to verify
#
# Usage (Git Bash, from the project folder):
#   perl tools/release.pl                      # sources: src\ if it holds df_main.gsc, else the project folder
#   perl tools/release.pl --src src --out release
#   perl tools/release.pl --no-build           # only refresh README.md / INSTALL.txt next to an existing merged file
# PowerShell has no perl on PATH; use "C:\Program Files\Git\usr\bin\perl.exe" tools\release.pl
#
# Exit codes: 0 ok, 1 usage/IO error, otherwise build.pl's code (2 duplicates, 3 gsc-tool error).
# Perl 5 core modules only (no CPAN).
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename qw(dirname basename);
use File::Spec;
use File::Copy qw(copy);
use Cwd qw(realpath);
use POSIX qw(strftime);

$| = 1;

my $OUT_NAME = 'zm_transit_dead_frequency.gsc';

my $tools   = realpath( dirname( $0 ) ) // File::Spec->rel2abs( dirname( $0 ) );
my $project = realpath( File::Spec->catdir( $tools, File::Spec->updir ) )
    // File::Spec->rel2abs( File::Spec->catdir( $tools, File::Spec->updir ) );

my ( $src, $out_dir, $no_build, $help );
GetOptions(
    'src=s'    => \$src,
    'out=s'    => \$out_dir,
    'no-build' => \$no_build,
    'help|h'   => \$help,
) or usage( 1 );
usage( 0 ) if $help;

$out_dir = File::Spec->catdir( $project, 'release' ) unless defined $out_dir;
$out_dir = File::Spec->rel2abs( $out_dir );
if ( !-d $out_dir )
{
    mkdir $out_dir or die "release.pl: cannot create $out_dir: $!\n";
}
my $merged = File::Spec->catfile( $out_dir, $OUT_NAME );

# ------------------------------------------------------------------ 1. build ----

if ( !$no_build )
{
    my @cmd = ( 'perl', File::Spec->catfile( $tools, 'build.pl' ), '--out', $merged );
    push @cmd, '--src', $src if defined $src;
    print "release.pl: running: @cmd\n";
    my $rc = system( @cmd );
    if ( $rc != 0 )
    {
        my $code = $rc == -1 ? 1 : ( $rc >> 8 );
        die "release.pl: build failed (exit $code), nothing packaged\n";
    }
}
die "release.pl: merged file missing: $merged (run without --no-build)\n" unless -f $merged;

# version string for INSTALL.txt, read from the merged header written by build.pl
my $version = 'unknown';
{
    open my $fh, '<', $merged or die "release.pl: cannot read $merged: $!\n";
    while ( my $line = <$fh> )
    {
        last if $. > 20;
        if ( $line =~ /^\/\/ Version : (.+?)\s*$/ ) { $version = $1; last; }
    }
    close $fh;
}

# ------------------------------------------------------------------ 2. README ----

my $readme = File::Spec->catfile( $project, 'README.md' );
if ( -f $readme )
{
    copy( $readme, File::Spec->catfile( $out_dir, 'README.md' ) )
        or die "release.pl: cannot copy README.md: $!\n";
    print "release.pl: copied README.md\n";
}
else
{
    warn "release.pl: WARNING: README.md not found in $project, not copied\n";
}

# ------------------------------------------------------------------ 3. INSTALL.txt ----

my $date = strftime( '%Y-%m-%d', localtime );
my $install = <<"TXT";
Dead Frequency - TranZit replacement Easter Egg for Plutonium T6 (Black Ops II Zombies)
Version $version, packaged $date

WHAT IS IN THIS FOLDER
  zm_transit_dead_frequency.gsc  the whole mod in ONE loose GSC file (no compiling needed)
  README.md                      walkthrough, debug commands, test checklists
  INSTALL.txt                    this file

INSTALL
  1. Press Win+R, paste  %localappdata%\\Plutonium\\storage\\t6\\scripts\\zm  and press Enter.
     Create the folders if they do not exist. Inside "zm", create a folder named  zm_transit
     (that folder is loaded only when the TranZit map is running).
  2. Copy  zm_transit_dead_frequency.gsc  into
     %localappdata%\\Plutonium\\storage\\t6\\scripts\\zm\\zm_transit\\
  3. Start Plutonium T6 Zombies, choose TranZit (Green Run / Original). No restart is needed
     between games: ending the match and starting a new one reloads the script.

DO NOT KEEP THE SOURCES IN THE LOAD PATH
  This file is the merged copy of the development sources df_main.gsc, df_systems.gsc, df_steps.gsc,
  df_dialogue.gsc, df_coords.gsc, df_act1.gsc, df_act2_*.gsc, df_act3_*.gsc, df_finale.gsc.
  Plutonium loads EVERY *.gsc in  scripts\\zm\\  and in  scripts\\zm\\zm_transit\\ , and all loaded
  scripts share one namespace. If any df_*.gsc source is in one of those two folders at the same
  time as zm_transit_dead_frequency.gsc, every function is defined twice and the map fails to load.
  -> Those two folders must contain either the sources OR this single file, never both.
     (A sub-folder such as scripts\\zm\\zm_transit\\src\\ is not loaded by the game and is fine.)
  Also remove older copies: transit_new_ee_poc.gsc, T6EE*.gsc or any other TranZit Easter Egg script,
  which would fight over the same tower.

VERIFY IT LOADED
  1. Before loading the map, open the console (~) and type:   set df_debug 1
  2. In the game, open chat and type:   !df status
     Expected answer on screen and in the console:
       DF $version | side none | players 1 | round 1 ...
       registered: step1 step2 step3 step4 r1 r2 m1 m2 step5 step6 step7 finale
  3. No red script error and no "duplicate function" / "COM_ERROR" popup while the map loads.
  If nothing answers: the file is in the wrong folder (check step 2 of INSTALL), or df_debug is 0.
  With df_debug 0 the mod still runs normally; the chat commands are only for testing.
  `!df` alone lists every command; README.md explains the walkthrough and the test checklists.
TXT

my $install_path = File::Spec->catfile( $out_dir, 'INSTALL.txt' );
open my $ih, '>', $install_path or die "release.pl: cannot write $install_path: $!\n";
binmode $ih;
$install =~ s/\n/\r\n/g;        # Windows notepad friendly
print {$ih} $install;
close $ih;
print "release.pl: wrote INSTALL.txt\n";

# ------------------------------------------------------------------ summary ----

print "release.pl: release folder $out_dir\n";
opendir( my $dh, $out_dir ) or die;
for my $f ( sort grep { !/^\./ } readdir $dh )
{
    printf "release.pl:   %-32s %8d bytes\n", $f, -s File::Spec->catfile( $out_dir, $f );
}
closedir $dh;

# warn if the release folder is itself a Plutonium load folder or holds sources
opendir( $dh, $out_dir ) or die;
my @src_here = grep { /^df_[a-z0-9_]+\.gsc$/i } readdir $dh;
closedir $dh;
warn "release.pl: WARNING: $out_dir also contains df_*.gsc sources: @src_here (never load both)\n" if @src_here;
if ( $out_dir =~ m{[\x5c/]scripts[\x5c/]zm(?:[\x5c/]zm_transit)?[\x5c/]?$}i )
{
    warn "release.pl: WARNING: $out_dir is a Plutonium load folder; make sure no df_*.gsc source is in it\n";
}
exit 0;

sub usage
{
    my ( $code ) = @_;
    my $fh = $code ? *STDERR : *STDOUT;
    print {$fh} <<"USAGE";
release.pl - build $OUT_NAME and package it with README.md and INSTALL.txt
  --src DIR    sources for build.pl (default: <project>\\src if it has df_main.gsc, else <project>)
  --out DIR    release folder (default: <project>\\release)
  --no-build   skip build.pl, only refresh README.md and INSTALL.txt
  --help       this text
USAGE
    exit $code;
}
