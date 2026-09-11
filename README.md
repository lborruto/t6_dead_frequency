# Dead Frequency

<img width="640" height="360" alt="1789149570984-wp9607715-3" src="https://github.com/user-attachments/assets/e769e5c5-b96b-4a2c-bee2-88d9f3ad7947" />


A new Easter Egg for **TranZit** on **Plutonium T6**. The original quest is gone; this one takes its place.

Twelve steps across the whole map, from the bus Depot to the tower. Halfway through you side with Richtofen or
Maxis, and the rest of the quest is theirs: different steps, different items, different ending. Both patrons talk
you through it. Solo or up to four players.

**Play it blind.** It was built to be discovered. If you are truly stuck, [docs/GUIDE.md](docs/GUIDE.md) has the
solution, one folded step at a time.

<img width="630" height="430" alt="1789150242878-99fa2a6c-e46b-427d-a962-a5bd6ffaabca-image" src="https://github.com/user-attachments/assets/ad9b17bf-49b4-4cd9-9132-e417d23cf34b" />
<img width="630" height="430" alt="1789150120232-05b5bb01-287b-4d2a-8bf4-4441e0dd1ce0-image" src="https://github.com/user-attachments/assets/1a99d03d-178e-4e50-8227-773b71743875" />
<img width="630" height="430" alt="1789150354432-dcb3dc8d-252f-4e6e-ac08-09828865c064-image" src="https://github.com/user-attachments/assets/b76a3db6-88f6-4952-bf18-a469b57da4cd" />

## Requirements

- Plutonium T6, map **Green Run - TranZit**, mode **Original**.
- [**Scavenger Project**](https://github.com/NickB05/Project_Scavenger) by NickB_05 (carry every buildable piece).
  Not included: install it from its own page.
- [**TranZit Enhanced**](https://forum.plutonium.pw/topic/46428/release-zm-tranzit-enhanced) by Myrix, the `noee`
  build. Attached to every release; see [companion/README.md](companion/README.md).

## Install

1. Download the three files of the latest [release](../../releases):
   `zm_transit_dead_frequency_1.gsc`, `zm_transit_dead_frequency_2.gsc`, `zm_transit_enhanced_noee.gsc`.
2. Put them in `%LOCALAPPDATA%\Plutonium\storage\t6\scripts\zm\zm_transit\`.
3. Install Scavenger in `%LOCALAPPDATA%\Plutonium\storage\t6\scripts\zm\` as its page says.
4. Remove any other TranZit Easter Egg script from those folders, "solo Easter Egg" helpers included.
5. Start TranZit. To check it loaded: console `set df_debug 1`, then `!df status` in the chat.

Nothing else from this repository goes into the game folders. To update, replace the files with the new release.

## Credits

- Design and direction: [lborruto](https://github.com/lborruto). Code: lborruto and Claude (Anthropic).
- [Scavenger Project](https://github.com/NickB05/Project_Scavenger): NickB_05.
- [TranZit Enhanced](https://forum.plutonium.pw/topic/46428/release-zm-tranzit-enhanced): Myrix.
- Treyarch for the game, the Plutonium team for the platform.

## Contributing

Issues and pull requests are welcome. The `df_*.gsc` files are the sources; the release is a build of them.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the layout, the build, the lints, the debug commands and the rules.

## License

MIT, see [LICENSE](LICENSE). The companion script and Scavenger keep their own authors' terms.
