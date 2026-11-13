# FadeUI: Customizable Auto Hide UI, Element by Element

FadeUI lets you choose exactly when each part of your World of Warcraft UI is shown. Give every element its own rule: **Always**, **In combat**, **Combat/Target**, **Out of combat**, or **Never**. Hide your action bars until a fight starts, keep your unit frames up while you have a target, and trim the minimap down to just its nodes, like herbs and ore. You get a clean, immersive screen while you explore, and everything you rely on fades back in the moment you need it.

Hiding your action bars? An optional, minimal spell icon pops up when a cast fails and shows you why: out of range, short on mana, rage or energy, or still on cooldown.

Built for **WoW Forever**. It's like pressing Alt-Z, but automatic and element by element, and your UI comes back on its own when combat starts.

## Why FadeUI

- **Your rules, element by element:** over 30 Blizzard UI elements, each with its own visibility mode.
- **Immersive by default:** a clean, minimal screen while you quest, gather or stand in town, with no clutter until it matters.
- **Play with hidden action bars:** spell helpers show when a spell is out of range, on cooldown or short on mana, and keybinds keep working.
- **A minimap that stays out of the way:** keep just the herb and ore nodes, or a borderless circular map.
- **Safe in combat:** built on secure state drivers, so there are no taint errors and no blocked actions.
- **Other addons too:** Questie, Chattynator and Details! work out of the box, and you can add any other addon's frame yourself.
- **Plays nice with Blizzard's UI:** Edit Mode, the Cooldown Manager and the Damage Meter all work, and one toggle puts everything back.

## Show UI in combat, hide it out of combat

Every element gets one of five modes:

- **Always**: shown, like the normal UI
- **In combat**: shown only while you're in combat
- **Combat/Target**: shown in combat, and whenever you have something targeted
- **Out of combat**: shown only while you're not in combat
- **Never**: always hidden while FadeUI is on. Keybinds on hidden action bars still work.

Chat has its own modes instead: **Always**, **When active** (hides after a set number of idle seconds and comes back with the next message), or **While typing**.

## Hide action bars, unit frames, minimap, chat and more

- **Action bars:** Action Bars 1–8, Stance/Form Bar, Totem Bar, Pet Bar
- **Unit frames:** Player, Pet, Totem Timers, Target, Target of Target, Focus, Cast Bar, Swing Timers, Boss Frames
- **Group frames:** Party Frames, Raid Frames, Raid Manager Tab
- **Everything else:** Minimap, Buffs, Debuffs, Quest Tracker, Chat, Menu Buttons, Bag Buttons, XP/Rep Bars, Cooldown Manager, Damage Meter

Bag buttons can also show whenever your bags are open, and action bars show while you drag a spell or item onto them or use Quick Keybind Mode.

## Works with other addons

- **Questie:** its quest tracker follows the Quest Tracker setting.
- **Chattynator:** the Chat setting fades Chattynator's windows instead of Blizzard's.
- **Details!:** its windows follow the Damage Meter setting, along with Blizzard's meter.

## Custom frames: hide any addon's UI

Is there something FadeUI doesn't have a setting for, such as another addon's window? Add it under **Custom frames** in the options window. Type the frame's name (`/fstack` shows it when you hover the frame), or click **Pick**, hover the frame and press Enter. It gets its own row with the same five modes, and removing it puts it straight back to normal.

## Minimal minimap: just the nodes, or a clean circle

Choose what the minimap looks like while it's shown, and what's left of it while it's hidden:

- **Normal:** Blizzard's minimap (while shown)
- **Nodes:** only what the minimap marks, such as herb and ore nodes, quest areas, party members and your arrow, with no map behind them (while hidden)
- **Map:** just the map, with no border or buttons, cropped to a circle around you at your usual zoom. Set its size from 30% to 100% (while shown or hidden)
- **None:** fully hidden (while hidden)

Hover a node or marker to see what it is. Clicking the map pings that spot, or turn that off so clicks go through to the world.

## Spell helpers for hidden action bars

With your action bars hidden, you can't see why a spell didn't cast. When a spell fails, these show its icon until it's ready:

- **Range helper:** a red border while you're out of range, green once you're in range
- **Resource helper:** a dulled icon while you're short on mana, rage or energy
- **Cooldown helper:** the cooldown sweep and countdown over the icon

The icon flashes when the spell is ready, and hides when you cast it or after a set time. Type `/fui range` to move it.

## More features

- **Smooth fading:** set the fade-in time, the fade-out time, and a delay before fading out (for example, right after combat ends). In combat, elements always hide instantly.
- **Hover to show:** for each element, keep it up while the mouse is over it, or show it whenever you hover its spot.
- **One-click setup:** click a column header in the options window to set every element to that mode.
- **Search:** type in the options window to find an element quickly.
- **Edit Mode friendly:** everything is shown while Edit Mode is open, so you can still move your frames.
- **Instant off switch:** turning FadeUI off puts everything back exactly as Blizzard had it.
- **Profiles:** save different setups (questing, raiding...) and switch between them. Profiles are shared across your account, each character remembers its own, and you can export a profile as text to share it or import someone else's.
- **Undo and redo:** step back and forth through your changes since you logged in, so a misclick (or Reset to defaults) is easy to take back.

## Commands and keybinds

- `/fadeui` or `/fui` opens the options window
- `/fui toggle`, `/fui on` or `/fui off` switches FadeUI on and off
- `/fui range` unlocks the spell helper icon so you can drag it into place (type it again to lock it)
- `/fui profile` lists your profiles, and `/fui profile <name>` switches to one (handy in a macro)
- `/fui combat` simulates combat (type it again to stop), so you can try out your settings without a fight. The options window has a button for it too
- `/fui reset` resets the current profile to the default settings
- **Key Bindings > AddOns > FadeUI** has binds for the on/off toggle and for opening the options window
- **Addon compartment button (minimap):** left-click toggles FadeUI, right-click opens the options window

## Source and bugs

[github.com/bstotmeister/fadeui](https://github.com/bstotmeister/fadeui)
