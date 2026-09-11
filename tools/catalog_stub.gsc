// Stand-in for df_catalog.gsc in the PACKED build (tools/pack.pl). The real catalogue (792 model names with
// sizes) is a development tool and its strings alone are 44 KB, which pushes the packed script's string block
// past the engine's 65535-byte limit (names then read wrong: "Unresolved external: t_completed"). The functions
// other files call keep working and simply report that the catalogue is not in this build. The multi-file
// development install (tools/deploy.pl --multi) ships the real df_catalog.gsc instead of this file.

df_catalog_all()
{
    return [];
}

df_cat_name( line )
{
    return strtok( line, " " )[0];
}

df_catalog_match( keyword )
{
    return [];
}

df_catalog_lookup( name )
{
    return undefined;
}

df_catalog_sizes_print( keyword, page )
{
    return "DF: the model catalogue is not in this packed build (use the development install: perl tools/deploy.pl --multi)";
}

df_catalog_page_precache()
{
    return 0;
}

df_catalog_page_has( name )
{
    return false;
}
