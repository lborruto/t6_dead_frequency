# Pickers

Generators of three self-contained HTML pages used to choose the mod's sounds, props and effects by ear and eye
instead of by name. Each page walks one quest role at a time (what it is, where it plays, what is used today),
shows the candidates under it, and ends with a copyable "role = choice" list.

- `gen_wizard_snd.pl` - Sound Picker: every candidate cue of the TranZit sound banks, playable in the browser
  (files downsampled by `shrink.pl`), with duration, 3D range and bank volume.
- `gen_wizard_mdl.pl` - Prop Picker: every always-loaded TranZit model in a three.js viewer (glTF from the
  OpenAssetTools Unlinker dump), with a search box.
- `gen_wizard_fx.pl` - Effect Picker: the curated server effects of `df_audition.gsc` with their `!df fx <n>`
  number (effects cannot be rendered outside the game: the page pairs with the in-game command).
- `gen_board.pl`, `board.pl`, `dur.pl`, `shrink.pl`, `table.pl` - helpers that build the sound lists.

Inputs are NOT in the repository (game data, several hundred MB): the sound bank dump made with
`Unlinker.exe --include-assets soundbank` on `so_zclassic_zm_transit.ff` and `patch_zm.ff`, the halved WAVs, and the
glTF model dump (`docs/MODELS.md` says how to make it). The scripts expect them next to the working directory as
`board_keep.txt`, `small/`, `vanilla_use.txt` (= `tools/assets/sounds_zm_transit.txt`) and a model viewer folder;
adjust the paths at the top of each script. Output: `perl gen_wizard_snd.pl > board.html`, and so on; open the HTML
in a browser.

The roles (actions / props / effects) and their "today" values are hard-coded at the top of each generator: update
them when the cue grammar or the model registry changes.
