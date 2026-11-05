# FadeUI

Hide the UI like Alt-Z, one element at a time. Keep your screen clear while you're out questing or standing around, and have the parts you need fade in the moment combat starts or you pick a target.

## Modes

Every element gets one of five modes:

- **Always**: shown, like the normal UI
- **In combat**: shown only while you're in combat
- **Combat/Target**: shown in combat, and whenever you have something targeted
- **Out of combat**: shown only while you're not in combat
- **Never**: always hidden while FadeUI is on. Keybinds on hidden action bars still work.

Chat has its own modes instead: **Always**, **When active** (hides after a set number of idle seconds and comes back with the next message), or **While typing**.

## What it can hide

- **Action bars:** Action Bars 1–8, Stance/Form Bar, Pet Bar
- **Unit frames:** Player, Pet, Target, Target of Target, Focus, Cast Bar, Swing Timers, Boss Frames
- **Group frames:** Party Frames, Raid Frames, Raid Manager Tab
- **Everything else:** Minimap, Buffs, Debuffs, Quest Tracker, Chat, Menu Buttons, Bag Buttons, XP/Rep Bars, Cooldown Manager, Damage Meter

Bag buttons can also show whenever your bags are open.

## Minimap styles

Choose what the minimap looks like while it's shown, and what's left of it while it's hidden:

- **Normal:** Blizzard's minimap (while shown)
- **Nodes:** only what the minimap marks, such as herb and ore nodes, quest areas, party members and your arrow, with no map behind them (while hidden)
- **Map:** just the map, with no border or buttons, cropped to a circle around you at your usual zoom. Set its size from 30% to 100% (while shown or hidden)
- **None:** fully hidden (while hidden)

Hover a node or marker to see what it is. Clicking the map pings that spot, or turn that off so clicks go through to the world.

## Spell helpers

With your action bars hidden, you can't see why a spell didn't cast. When a spell fails, these show its icon until it's ready:

- **Range helper:** a red border while you're out of range, green once you're in range
- **Resource helper:** a dulled icon while you're short on mana, rage or energy
- **Cooldown helper:** the cooldown sweep and countdown over the icon

The icon flashes when the spell is ready, and hides when you cast it or after a set time. Type `/fui range` to move it.

## Features

- **No combat taint:** visibility runs on secure state drivers, so frames appear and disappear in combat without errors.
- **Adjustable fading:** set the fade-in time, the fade-out time, and a delay before fading out (for example, right after combat ends). In combat, elements always hide instantly.
- **One-click setup:** click a column header in the options window to set every element to that mode.
- **Search:** type in the options window to find an element quickly.
- **Edit Mode friendly:** everything is shown while Edit Mode is open, so you can still move your frames.
- **Instant off switch:** turning FadeUI off puts everything back exactly as Blizzard had it.
- **Account-wide settings:** every character shares one setup, or tick a box to give a character its own.

## Usage

- `/fadeui` or `/fui` opens the options window
- `/fui toggle`, `/fui on` or `/fui off` switches FadeUI on and off (like Alt-Z)
- `/fui range` unlocks the spell helper icon so you can drag it into place (type it again to lock it)
- `/fui reset` goes back to the default settings
- **Key Bindings > AddOns > FadeUI** has binds for the on/off toggle and for opening the options window
- **Addon compartment button (minimap):** left-click toggles FadeUI, right-click opens the options window

## Source and bugs

[github.com/bstotmeister/fadeui](https://github.com/bstotmeister/fadeui)
