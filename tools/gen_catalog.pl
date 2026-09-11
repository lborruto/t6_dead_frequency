use strict; use warnings;
my $src = "C:/Games/t6/model_dump/viewer/SIZES.txt";
open my $h,'<',$src or die $src; my @rows;
while (<$h>) { next if /^#/; chomp; my @f = split /\s+/; next unless @f >= 8;
  my ($name,$zone,$w,$ht,$d) = ($f[0],$f[1],$f[3],$f[5],$f[7]);
  next if $name =~ /^(collision_|zm_collision|fx_axis)/;
  push @rows, "$name $zone $w $ht $d"; }
close $h;
my $per = 40; my $nfun = int((@rows + $per - 1)/$per);
my $bs = "\\";
open my $o,'>',"df_catalog.gsc" or die;
print $o <<"HDR";
// Dead Frequency - full TranZit model catalogue (generated 2026-09-08 by tools/gen_catalog.pl from the glTF
// export of the game files: OpenAssetTools Unlinker --model-format GLTF on zm_transit, so_zclassic_zm_transit,
// common_zm, patch_zm, zm_transit_patch and the nine zm_transit_gump_* area zones; sizes measured from the
// meshes, in game units, player height ~70).
//   Data: one line per model, "name zone width height depth" (@{[scalar @rows]} models).
//   `!df sizes <keyword|all> [page]` lists them with zone and size in the console: NO precache needed, so every
//   model of the map can be checked from in game.
//   `!df catalog <keyword>` spawns models, which only works for PRECACHED names: the curated list of
//   df_coords::df_catalog_models() plus, when the owner asks for it before loading the map,
//     set df_catalog_page <n>        one page of 30 names of the full catalogue (df_catalog_pagesize changes 30)
//     set df_extra_models "a b c"    hand-picked names (df_coords::df_catalog_extra_models)
//   Precaching everything is impossible: the engine has a model-index limit and 700+ extra models would exceed
//   it, so the page mechanism keeps the load safe.
// Zones: zm_transit / so_zclassic_zm_transit / common_zm / patch_zm / zm_transit_patch are ALWAYS loaded;
// a zm_transit_gump_<area> model is streamed with that area and renders untextured (black) elsewhere.
#include common_scripts${bs}utility;
#include maps${bs}mp${bs}_utility;
#include maps${bs}mp${bs}zombies${bs}_zm_utility;
#include scripts${bs}zm${bs}zm_transit${bs}df_systems;

// Every catalogue line, built once and cached on the level.
df_catalog_all()
{
    if ( isdefined( level.df_cat ) )
        return level.df_cat;

    l = [];
HDR
print $o "    l = df_cat_data_".sprintf("%02d",$_)."( l );\n" for (1..$nfun);
print $o <<'MID';

    level.df_cat = l;
    return l;
}

// "name zone w h d" -> the parts
df_cat_name( line )
{
    return strtok( line, " " )[0];
}

df_cat_zone( line )
{
    return strtok( line, " " )[1];
}

// "29x44x29" (width x height x depth in game units)
df_cat_size( line )
{
    p = strtok( line, " " );
    return p[2] + "x" + p[3] + "x" + p[4];
}

// True when the zone is loaded everywhere on the map (a gump zone streams with its area only).
df_cat_always( line )
{
    z = df_cat_zone( line );
    return !issubstr( z, "gump" );
}

// Lines whose model name contains `keyword` ("all" / "" = everything).
df_catalog_match( keyword )
{
    out = [];

    foreach ( line in df_catalog_all() )
    {
        if ( keyword == "" || keyword == "all" || issubstr( df_cat_name( line ), keyword ) )
            out[out.size] = line;
    }

    return out;
}

// The catalogue line of `name`, or undefined.
df_catalog_lookup( name )
{
    foreach ( line in df_catalog_all() )
    {
        if ( df_cat_name( line ) == name )
            return line;
    }

    return undefined;
}

// "name  zone  WxHxD" plus a note for streamed zones.
df_catalog_line_text( line )
{
    t = df_cat_name( line ) + "  " + df_cat_size( line ) + "  " + df_cat_zone( line );

    if ( !df_cat_always( line ) )
        t += " (streamed: black elsewhere)";

    return t;
}

// "!df sizes <keyword|all> [page]": 30 lines per page in the console, no precache, no spawning.
// Returns the summary line for the screen.
df_catalog_sizes_print( keyword, page )
{
    lines = df_catalog_match( keyword );

    if ( lines.size == 0 )
        return "DF: no model name contains `" + keyword + "` (try: rock skull table tv barrel pole light box crate all)";

    per = 30;
    pages = int( ( lines.size + per - 1 ) / per );

    if ( page < 1 )
        page = 1;

    if ( page > pages )
        page = pages;

    first = ( page - 1 ) * per;
    last = first + per;

    if ( last > lines.size )
        last = lines.size;

    df_debug_print( "DF: [SIZES] " + keyword + " page " + page + "/" + pages + " (name, width x height x depth in units, zone; player ~70 tall)" );

    for ( i = first; i < last; i++ )
        df_debug_print( "  " + ( i + 1 ) + ". " + df_catalog_line_text( df_catalog_all()[0] ) );

    return "DF: " + lines.size + " model(s) match `" + keyword + "`, page " + page + "/" + pages + " in the console";
}

// Precaches one page of the full catalogue when the console dvar df_catalog_page is set before the map loads
// (df_catalog_pagesize, default 30, changes how many). Called from df_main::init. Returns the number loaded.
df_catalog_page_precache()
{
    level.df_cat_loaded = [];
    page = getdvarint( "df_catalog_page" );

    if ( !isdefined( page ) || page < 1 )
        return 0;

    per = getdvarint( "df_catalog_pagesize" );

    if ( !isdefined( per ) || per < 1 )
        per = 30;

    lines = df_catalog_all();
    first = ( page - 1 ) * per;
    n = 0;

    for ( i = first; i < first + per && i < lines.size; i++ )
    {
        name = df_cat_name( lines[i] );
        precachemodel( name );
        level.df_cat_loaded[name] = 1;
        n++;
    }

    df_debug_print( "DF: catalogue page " + page + " precached: " + n + " model(s) (" + ( first + 1 ) + ".." + ( first + n ) + " of " + lines.size + "), spawnable with !df catalog <keyword>" );
    return n;
}

// True when `name` was precached by the page mechanism (so !df catalog may spawn it).
df_catalog_page_has( name )
{
    return isdefined( level.df_cat_loaded ) && isdefined( level.df_cat_loaded[name] );
}

MID
for my $fi (1..$nfun) {
  printf $o "df_cat_data_%02d( l )\n{\n", $fi;
  my $s = ($fi-1)*$per; my $e = $s+$per-1; $e = $#rows if $e > $#rows;
  for my $i ($s..$e) { my $r = $rows[$i]; $r =~ s/"/'/g; print $o "    l[l.size] = \"$r\";\n"; }
  print $o "    return l;\n}\n\n";
}
close $o;
print "df_catalog.gsc written: ", scalar @rows, " models, $nfun data functions\n";
