# Changelog

## 1.1.0 (unreleased)

- **WoW Forever:** tracking button at the minimap edge. Shows the icon of your active hunter tracking (or a neutral eye if none is active); left-click opens a list of your hunter tracking types to switch between them.
- The tracking button is built from the client's tracking list, so it shows exactly the tracking types your character knows, and hides when there are none.
- Move it around the minimap with Shift + drag while the panels are unlocked; the position is saved.
- Turn it on or off with *Tracking* in the right-click menu or `/tk tracking on|off`. On by default.
- Tracking cannot be switched in combat; a chat message tells you so.

## 1.0.0

First public release for **World of Warcraft: Midnight**. WoW Forever support is coming at launch.

- Two compact panels for hunters: **Aspects** and **Traps**, placed above the main action bar.
- Only learned spells are shown; the panels update automatically when you learn spells or change specialization.
- Cooldown swipe and countdown numbers on every icon, working in combat.
- Standard proc glow (spell activation overlay), the same as on the default action bars.
- Active aspect is highlighted with the standard action button border.
- Reorder icons with Shift + drag (can be turned off in the menu).
- Panels are locked by default; unlock to move them by the title bar.
- Two looks: **Blizzard** (default) and **Night Elf** (the same buttons inside a leafy branch frame).
- Right-click menu: Lock, Prevent icon reordering, Style, Scale, Hide panel, Reset position.
- Slash commands `/trailkit` and `/tk`: `lock`, `unlock`, `scale`, `reset`, `test`, `help`.
- Test mode with placeholder icons that works on any class.
- Account-wide settings with an automatic per-character backup.
- Localized for all WoW client languages.
