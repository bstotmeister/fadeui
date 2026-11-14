# FadeUI

Auto hide the World of Warcraft UI out of combat for a clean, immersive screen. Each
Blizzard element (action bars, player frame, minimap, chat...) can be shown **Always**,
**In combat**, **Combat/Target**, **Out of combat**, or **Never**, like pressing Alt-Z
but per element and automatic. Visibility is driven by secure state drivers, so
elements appear and disappear in combat without taint errors, and keybinds keep
working on hidden bars.

## Usage

- `/fadeui` or `/fui` — open the options window
- Keybindings → AddOns → FadeUI — toggle FadeUI (like Alt-Z) or open options
- Addon compartment (minimap) button — left-click toggles, right-click opens options

Drag the grip in the options window's bottom-right corner to make it bigger or smaller, from
75% to 150%, and double-click it to go back to 100%.

## Development

Addon source lives in `FadeUI/`. Symlink it into your WoW client so changes load on `/reload`:

```sh
scripts/link.sh                # _forever_ (default)
scripts/link.sh _retail_       # or any other flavor folder
```

Set `WOW_DIR` if WoW isn't installed at `/Applications/World of Warcraft`.

To support another addon, add a file for it to `FadeUI/Addons/` and list it in
`FadeUI/Addons/Addons.xml`. `FadeUI/Addons.lua` describes what a file can declare, and
`Addons/Questie.lua` and `Addons/Chattynator.lua` are examples.

## Contributing

Report bugs and request features with the [issue forms](https://github.com/bstotmeister/fadeui/issues/new/choose).
For branches, pull requests, labels, milestones and releasing, see [CONTRIBUTING](.github/CONTRIBUTING.md).
