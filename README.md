# FadeUI

Hide the UI like Alt-Z, one element at a time. Each Blizzard element (action bars,
player frame, minimap, chat...) can be shown **Always**, **In combat**,
**Combat/Target**, **Out of combat**, or **Never**. Visibility is driven by secure
state drivers, so elements appear and disappear in combat without taint errors,
and keybinds keep working on hidden bars.

## Usage

- `/fadeui` or `/fui` — open the options window
- Keybindings → AddOns → FadeUI — toggle FadeUI (like Alt-Z) or open options
- Addon compartment (minimap) button — left-click toggles, right-click opens options

## Development

Addon source lives in `FadeUI/`. Symlink it into your WoW client so changes load on `/reload`:

```sh
scripts/link.sh                # _classic_beta_ (default)
scripts/link.sh _retail_       # or any other flavor folder
```

Set `WOW_DIR` if WoW isn't installed at `/Applications/World of Warcraft`.

## Releasing

Bump `## Version` in `FadeUI/FadeUI.toc`, then push a tag:

```sh
git tag v2.0.1 && git push origin v2.0.1
```

GitHub Actions runs the [BigWigs packager](https://github.com/BigWigsMods/packager),
which builds `FadeUI-v2.0.1.zip` (excluding dev files listed in `.pkgmeta`) and
attaches it to a GitHub release.
