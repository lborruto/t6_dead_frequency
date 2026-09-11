Dead Frequency - TranZit model browser (exported 2026-09-08 with OpenAssetTools Unlinker from the game files)

WHAT IS HERE
  viewer\zm_transit\            216 models always loaded on TranZit (props, buildables, lights...)
  viewer\so_zclassic_zm_transit\ 130 models of the classic game mode (also always loaded)
  viewer\common_zm\              16 shared zombies models
  INDEX_<zone>.txt               plain list of the model names per folder (search with Ctrl+F)
  Each file name IS the game model name (e.g. p6_zm_buildable_sq_transceiver.gltf).

HOW TO VIEW
  Double-click a .gltf: it opens in Windows "3D Viewer" (built into Windows 11; if it is missing, install
  "3D Viewer" from the Microsoft Store, free). Rotate with the mouse. The grid = 1 unit.
  These viewer copies are UNTEXTURED grey (glTF cannot carry the game's DDS textures): use them for SHAPE and SIZE.
  Textured originals (DDS references, open in Blender) are in <zone>\model_export\ + <zone>\images\.

HOW TO SEE ONE TEXTURED IN GAME
  Console BEFORE loading TranZit:   set df_extra_models "name1 name2 name3"   (up to ~10 names)
  In game:  !df catalog extra        -> they stand in a row in front of you, textured, real size.
            !df catalog pick 2 orb   -> entry 2 becomes the orb (or relay, relay_top, tv, brazier, card...).
  Then put the final name in df_coords.gsc (df_models_init) so it becomes permanent.

SIZE HINT
  Player height is about 70 units; a doorway about 100. The bus roof relay should stay under ~90 units tall.

WHY A MODEL THAT EXISTS ON THE MAP CAN STILL RENDER AS A BLACK BOX (measured 2026-09-08)
  A TranZit model asset has an owner zone. Five zones are loaded for the whole game (zm_transit,
  so_zclassic_zm_transit, common_zm, patch_zm, zm_transit_patch). The rest are per-area packages
  (zm_transit_gump_farm, _town, _diner, _busstation, _powerstation, _tunnel, _labs, _forest2, _cornfield) and only
  about four of them are resident at a time: there are exactly four zm_transit_gump_prealloc slots.
  p_jun_old_tv (the farmhouse TV) is owned by zm_transit_gump_farm, while its materials mc/mtl_p_jun_old_tv,
  mc/mtl_p_jun_old_tv_glass and its two images are owned by zm_transit. So at the Depot the textures are in memory
  but the MESH is not, and a spawned TV shows as an untextured box. Nothing is wrong with the model: the game only
  ever needs it inside the farm.
  Rule: spawn only models marked ALWAYS in tools/assets/xmodels_zm_transit.txt (584 of the 1038), or accept that a
  STREAMED model (454) is visible only in its own area. `!df sizes <keyword>` marks streamed models in game.

THE MODEL CATALOGUE IS NOT IN THE PACKED (SINGLE FILE) BUILD
  Its 792 model names and sizes are 44 KB of strings, and a T6 script may hold at most 65535 bytes of strings in
  total (every function name is a 16-bit offset into that block; past the limit the game reads names from the
  wrong place and refuses the file). The packed build therefore replaces df_catalog.gsc with tools/catalog_stub.gsc
  and `!df sizes` answers that the catalogue is missing. For model hunting, install the development layout:
      perl tools/deploy.pl --multi        (the 17 sources, catalogue included)
      perl tools/deploy.pl                (back to the single packed file)
  `!df sizes` / `!df catalog` work in the --multi install; everything else is identical in both.
