#!/usr/bin/perl
# build.pl - merge the Dead Frequency df_*.gsc sources into ONE shippable GSC file.
#
# Plutonium T6 loads every *.gsc in scripts\zm\ and scripts\zm\zm_transit\ (root level only, see
# tools/polish_build.md) and all loaded scripts share one namespace: a function defined in a source
# file AND in the merged file is a fatal duplicate in game. So the merged file must never sit in the
# same load folder as the df_*.gsc sources. Keep the sources in src\ (never auto-loaded) and ship the
# merged file alone.
#
# Usage (Git Bash, from the project folder):
#   perl tools/build.pl                       # src\ if it holds df_main.gsc, else the project folder
#   perl tools/build.pl --src src --out release/zm_transit_dead_frequency.gsc
#   perl tools/build.pl --no-compile          # skip the gsc-tool syntax check
#   perl tools/build.pl --gsc-tool "D:\path\gsc-tool.exe"
# PowerShell has no perl on PATH; use "C:\Program Files\Git\usr\bin\perl.exe" tools\build.pl
#
# Exit codes: 0 ok, 1 usage/IO error, 2 duplicate function names (nothing written), 3 gsc-tool failed.
# Perl 5 core modules only (no CPAN). Backslashes inside regexes are written \x5c on purpose:
# one-liner backslash mangling bit this project before.
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename qw(dirname basename);
use File::Spec;
use Cwd qw(realpath);
use POSIX qw(strftime);

$| = 1;     # keep stdout and stderr lines in order

# ------------------------------------------------------------------ configuration ----

my $PROJECT_NAME = 'Dead Frequency - TranZit replacement Easter Egg (Plutonium T6, loose GSC)';
my $OUT_NAME     = 'zm_transit_dead_frequency.gsc';
my $GSC_TOOL     = 'C:\\Games\\t6\\gsc-tools\\gsc-tool.exe';
my @GSC_ARGS     = qw(-m comp -g t6 -s pc -y);

# concatenation order: shared layers first so a reader meets helpers before their callers
my @ORDER = qw(
    df_main.gsc
    df_compat.gsc
    df_systems.gsc
    df_steps.gsc
    df_dialogue.gsc
    df_coords.gsc
    df_lamps.gsc
    df_scav.gsc
    df_catalog.gsc
    df_place.gsc
    df_act1.gsc
    df_act2_rich.gsc
    df_act2_maxis.gsc
    df_act3_sweep.gsc
    df_act3_vacuum.gsc
    df_act3_hold.gsc
    df_finale.gsc
);

# ------------------------------------------------------------------ options ----

my $project = realpath( File::Spec->catdir( dirname( $0 ), File::Spec->updir ) )
    // File::Spec->rel2abs( File::Spec->catdir( dirname( $0 ), File::Spec->updir ) );

my ( $src, $out, $gsc_tool, $no_compile, $help );
my $ext = '';
GetOptions(
    'src=s'      => \$src,
    'out=s'      => \$out,
    'ext=s'      => \$ext,
    'gsc-tool=s' => \$gsc_tool,
    'no-compile' => \$no_compile,
    'help|h'     => \$help,
) or usage( 1 );
usage( 0 ) if $help;

$gsc_tool = $GSC_TOOL unless defined $gsc_tool;

if ( !defined $src )
{
    # transition-friendly default: prefer src\ once the sources have moved there
    my $cand = File::Spec->catdir( $project, 'src' );
    $src = ( -f File::Spec->catfile( $cand, "df_main.gsc$ext" ) ) ? $cand : $project;
}
$src = File::Spec->rel2abs( $src );
die "build.pl: source folder not found: $src\n" unless -d $src;

$out = File::Spec->catfile( $project, $OUT_NAME ) unless defined $out;
$out = File::Spec->rel2abs( $out );

if ( basename( $out ) =~ /^df_/i )
{
    die "build.pl: refusing to write '$out': an output named df_*.gsc looks like a source file\n";
}

print "build.pl: sources  $src\n";
print "build.pl: output   $out\n";

# ------------------------------------------------------------------ read sources ----

my @present;                # source basenames actually merged, in order
my @skipped;                # missing ones
my %text;                   # basename -> content
for my $name ( @ORDER )
{
    my $path = File::Spec->catfile( $src, "$name$ext" );
    if ( !-f $path )
    {
        warn "build.pl: WARNING: $name$ext not found in $src, skipped\n";
        push @skipped, $name;
        next;
    }
    open my $fh, '<', $path or die "build.pl: cannot read $path: $!\n";
    local $/;
    my $content = <$fh>;
    close $fh;
    $content =~ s/\r\n/\n/g;        # normalise CRLF; written back with \n
    $text{$name} = $content;
    push @present, $name;
}
die "build.pl: no source file found in $src (expected df_main.gsc and friends)\n" unless @present;

# any df_*.gsc in the source folder that is not in the order list is probably a new file someone forgot
opendir( my $dh, $src ) or die "build.pl: cannot list $src: $!\n";
my %known   = map { lc "$_$ext" => 1 } @ORDER;
my $ext_re  = quotemeta( $ext );
my @unknown = sort grep { /^df_[a-z0-9_]+\.gsc$ext_re$/i && !$known{ lc $_ } } readdir $dh;
closedir $dh;
warn "build.pl: WARNING: df_*.gsc in $src not in the build order (not merged): @unknown\n" if @unknown;

# ------------------------------------------------------------------ version string ----

my $version = 'unknown';
if ( defined $text{'df_main.gsc'} && $text{'df_main.gsc'} =~ /level\.df_version\s*=\s*"([^"]*)"/ )
{
    $version = $1;
}
else
{
    warn "build.pl: WARNING: level.df_version = \"...\" not found in df_main.gsc\n";
}

# ------------------------------------------------------------------ includes ----

# project includes are dropped (everything is in one file now); vanilla includes are collected,
# deduplicated (first occurrence wins the order) and emitted once at the top.
my @vanilla;
my %seen_include;
my $stripped = 0;
my %body;       # basename -> content without #include lines

for my $name ( @present )
{
    # removed include lines become blank lines so merged line k of a file == source line k
    # (exact locations in the duplicate report and in gsc-tool error mapping below)
    my @kept;
    for my $line ( split /\n/, $text{$name}, -1 )
    {
        if ( $line =~ /^\s*#include\s+(.+?)\s*;\s*$/ )
        {
            my $target = $1;
            if ( $target =~ m{^scripts[\x5c/]zm[\x5c/]zm_transit[\x5c/]}i )
            {
                $stripped++;
            }
            else
            {
                my $key = lc $target;
                $key =~ s{/}{\x5c}g;
                push @vanilla, "#include $target;" unless $seen_include{$key}++;
            }
            push @kept, '';
            next;
        }
        push @kept, $line;
    }
    my $joined = join( "\n", @kept );
    $joined =~ s/\n*\z/\n/;
    $body{$name} = $joined;
}

# ------------------------------------------------------------------ duplicate functions ----

# A definition is `name(` at column 0 whose next non-empty line starts with `{`. Block comments are
# blanked first (keeping line numbers) so a commented-out function does not count.
my %defs;       # function -> [ "file:line", ... ]
for my $name ( @present )
{
    my $scan = $body{$name};
    $scan =~ s{/\*.*?\*/}{ my $m = $&; $m =~ s/[^\n]//g; $m }gse;
    my @lines = split /\n/, $scan, -1;
    for my $i ( 0 .. $#lines )
    {
        next unless $lines[$i] =~ /^([a-z_][a-z0-9_]*)\s*\(/;
        my $fn = $1;
        my $j = $i + 1;
        $j++ while $j <= $#lines && $lines[$j] =~ /^\s*$/;
        next unless $j <= $#lines && $lines[$j] =~ /^\s*\{/;
        push @{ $defs{$fn} }, "$name:" . ( $i + 1 );
    }
}

my @dups = sort grep { @{ $defs{$_} } > 1 } keys %defs;
if ( @dups )
{
    print STDERR "build.pl: ERROR: function(s) defined more than once (fatal duplicate in game):\n";
    print STDERR "  $_()  ->  @{ $defs{$_} }\n" for @dups;
    print STDERR "build.pl: nothing written.\n";
    exit 2;
}

my $entry = join ' ', grep { $defs{$_} } qw(init main);
if ( $entry eq '' )
{
    warn "build.pl: WARNING: no init() or main() defined; Plutonium would load this file but never run it\n";
}

# ------------------------------------------------------------------ assemble ----

my $date = strftime( '%Y-%m-%d %H:%M', localtime );
my $header = join "\n",
    "// $OUT_NAME",
    "// $PROJECT_NAME",
    "// Version : $version",
    "// Built   : $date by tools/build.pl",
    "// Sources : " . join( ', ', @present ),
    ( @skipped ? "// Skipped : " . join( ', ', @skipped ) . " (not found)" : () ),
    "//",
    "// GENERATED FILE - do not edit. Edit the sources in src/ and run tools/build.pl.",
    "// Install : %localappdata%\\Plutonium\\storage\\t6\\scripts\\zm\\zm_transit\\$OUT_NAME",
    "//           The df_*.gsc sources must NOT be in scripts\\zm\\ or scripts\\zm\\zm_transit\\ at the",
    "//           same time (all loaded scripts share one namespace: every function would be duplicated).",
    "// Verify  : console `set df_debug 1`, chat `!df status` -> \"DF $version | ...\"",
    "";

my $output = $header . "\n" . join( "\n", @vanilla ) . "\n";
my @segments;   # [ first merged line of the file body, name ] for error mapping
for my $name ( @present )
{
    $output .= "\n// ===== $name =====\n\n";
    my $lines_before = ( $output =~ tr/\n// );
    push @segments, [ $lines_before + 1, $name ];
    $output .= $body{$name};
}
$output =~ s/\n*\z/\n/;

# merged line number -> "file.gsc:line"
sub source_of
{
    my ( $line ) = @_;
    my $hit;
    for my $seg ( @segments )
    {
        last if $seg->[0] > $line;
        $hit = $seg;
    }
    return $hit ? sprintf( '%s:%d', $hit->[1], $line - $hit->[0] + 1 ) : 'header';
}

# ------------------------------------------------------------------ write ----

my $out_dir = dirname( $out );
if ( !-d $out_dir )
{
    mkdir $out_dir or die "build.pl: cannot create $out_dir: $!\n";
}
open my $oh, '>', $out or die "build.pl: cannot write $out: $!\n";
binmode $oh;
print {$oh} $output;
close $oh;

my $fn_count = scalar keys %defs;
printf "build.pl: merged %d file(s), %d function(s), %d vanilla include(s), %d project include(s) stripped, version %s\n",
    scalar @present, $fn_count, scalar @vanilla, $stripped, $version;
print "build.pl: entry point(s): $entry\n" if $entry ne '';
print "build.pl: wrote $out (" . length( $output ) . " bytes)\n";

# the trap this whole tool exists for: merged file next to the sources it was built from
opendir( $dh, $out_dir ) or die "build.pl: cannot list $out_dir: $!\n";
my @neighbours = sort grep { /^df_[a-z0-9_]+\.gsc$/i } readdir $dh;
closedir $dh;
if ( @neighbours )
{
    warn "build.pl: WARNING: $out_dir also holds " . scalar( @neighbours ) . " df_*.gsc source file(s).\n"
       . "build.pl:          Plutonium loads every *.gsc in that folder: do NOT start the game with both\n"
       . "build.pl:          the merged file and the sources there (every function would be defined twice).\n"
       . "build.pl:          Move the sources to src\\ (perl tools/build.pl --src src) or delete the merged\n"
       . "build.pl:          file before launching.\n";
}

# ------------------------------------------------------------------ syntax check ----

if ( $no_compile )
{
    print "build.pl: --no-compile given, gsc-tool not run\n";
    exit 0;
}

my $exe      = $gsc_tool;
my $out_arg  = $out;
if ( $^O eq 'cygwin' || $^O eq 'msys' )
{
    # native exe needs a Windows path for the file; the shell needs a POSIX path for the exe
    chomp( my $w = `cygpath -w "$out" 2>/dev/null` );
    $out_arg = $w if $w ne '';
    chomp( my $u = `cygpath -u "$exe" 2>/dev/null` );
    $exe = $u if $u ne '';
}
if ( !-f $exe )
{
    warn "build.pl: WARNING: gsc-tool not found at $gsc_tool (use --gsc-tool PATH); syntax not checked\n";
    exit 0;
}

my $cmd = join( ' ', map { qq{"$_"} } ( $exe, @GSC_ARGS, $out_arg ) ) . ' 2>&1';
print "build.pl: running gsc-tool: $cmd\n";
my $log = `$cmd`;
my $rc  = $? >> 8;
$log = '' unless defined $log;

if ( $rc == 0 && $log =~ /^compiled\s/m )
{
    print "build.pl: gsc-tool OK: " . ( ( $log =~ /^(compiled\s.*)$/m ) ? $1 : 'compiled' ) . "\n";
    exit 0;
}

print STDERR "build.pl: ERROR: gsc-tool reported a problem (exit $rc). Output:\n";
print STDERR ( $log eq '' ? "  (no output)\n" : $log =~ s/^/  /mgr );

# gsc-tool prints <file>:<line>:<col>: translate merged lines back to the source file
my $out_base = quotemeta( basename( $out ) );
my %mapped;
while ( $log =~ /$out_base:(\d+):(\d+)?/g )
{
    my $src_loc = source_of( $1 );
    $mapped{"merged line $1 = $src_loc"}++;
}
if ( %mapped )
{
    print STDERR "build.pl: location in the sources: $_\n" for sort keys %mapped;
}
print STDERR "build.pl: the merged file $out was written but is NOT valid; fix the source above and rebuild.\n";
exit 3;

# ------------------------------------------------------------------ helpers ----

sub usage
{
    my ( $code ) = @_;
    my $fh = $code ? *STDERR : *STDOUT;
    print {$fh} <<"USAGE";
build.pl - merge the Dead Frequency df_*.gsc sources into one $OUT_NAME
  --src DIR        folder holding the df_*.gsc sources (default: <project>\\src if it has df_main.gsc, else <project>)
  --out FILE       merged file to write (default: <project>\\$OUT_NAME)
  --ext SUFFIX     extra suffix on the source names, e.g. --ext .txt reads df_main.gsc.txt (fallback layout)
  --gsc-tool PATH  gsc-tool.exe used for the syntax check (default: $GSC_TOOL)
  --no-compile     do not run gsc-tool
  --help           this text
Order: @ORDER
USAGE
    exit $code;
}
