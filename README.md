# Trailkit

Compact hunter bars for **World of Warcraft: Midnight** and **WoW Forever**: one panel for your aspects, one for your traps, right above the main action bar.

## Supported clients

- **Midnight (retail):** Aspect of the Cheetah, Aspect of the Turtle, Aspect of the Eagle; Freezing, Tar, High Explosive, Implosive and Steel Trap.
- **WoW Forever:** all aspects (Monkey, Hawk, Cheetah, Pack, Beast, Wild) and traps (Immolation, Freezing, Frost, Explosive), with spell ranks.

The client is detected automatically. Only spells you have learned are shown, so talents of other specializations stay hidden.

## Features

- Two independent panels: **Aspects** (left) and **Traps** (right).
- Shows only the spells you have learned. Each button always casts the highest rank you know and updates automatically when you learn a new rank or change specialization.
- Active aspect is highlighted with a border (any rank counts).
- Cooldown swipe and countdown numbers on every icon.
- Standard proc glow (spell activation overlay) when a spell lights up, same as on the default action bars.
- Tooltips on hover.
- Move panels when unlocked (out of combat only). Panels are locked by default.
- Reorder icons with Shift + drag, like in FloAspectBar (out of combat, works whether the panels are locked or not).
- Two looks: **Blizzard** (default, matches the standard action buttons) and **Night Elf** (the same buttons inside a leafy branch frame; unavailable if the client lacks that texture).
- Right-click menu: Lock, Prevent icon reordering, Style, Scale, Hide panel, Reset position.
- Test mode with placeholder icons that works on any class.
- Settings are saved account-wide, with a per-character backup copy restored automatically if needed.
- Localized for all WoW client languages: English, Russian, German, French, Spanish (EU and LatAm), Italian, Portuguese (BR), Korean, Simplified and Traditional Chinese.

## Usage

- **Unlock:** `/tk unlock`. A title bar appears on each panel; drag it to move the panel.
- **Lock again:** `/tk lock` or *Lock* in the right-click menu.
- **Reorder icons:** hold Shift and drag an icon onto another one to swap them. Shift-click never casts. To turn this off, check *Prevent icon reordering* in the right-click menu.

## Commands

`/trailkit` or `/tk`:

| Command | Description |
|---|---|
| `lock` | Lock panels in place |
| `unlock` | Unlock panels for moving |
| `scale <0.5–2>` | Set the scale of both panels |
| `reset` | Reset positions and show hidden panels |
| `test` | Toggle test mode with placeholder icons |
| `help` | Show the command list |

## Notes

- Blizzard does not allow addons to change action buttons in combat. Moving, reordering, scaling and hiding panels only work out of combat; spell changes during combat are applied right after combat ends.
- When aura information is hidden from addons in combat, the aspect highlight keeps its last known state.

## Translations

Translations were made with care, but some of them may be inaccurate. If you notice a wrong or awkward phrase in your language, please report it in the comments or the issue tracker. Include the language and a better wording, and it will be fixed in the next version.
