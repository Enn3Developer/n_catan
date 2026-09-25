# Storybook interface

The shared UI uses warm parchment, carved wooden borders, brass details, and moss-green primary actions to match the miniature medieval island. Fira Sans keeps controls readable; Noto Serif adds character to headings. Both font licenses ship with exports.

Run `python3 tools/build_ui_theme.py` from the repository to rebuild the authored SVG surfaces and `assets/ui_theme.tres`. The nine-slice surfaces stretch across menus and HUD panels without stretching their corners, so their decoration stays inside the slice margins: a stroke that crosses the middle smears into a bar across every panel. Resource and development-card illustrations retain their own palettes.

## Controls

Every control takes its look from the theme. Choose a variation rather than overriding colors or styles on a node:

| Variation | Base | Use |
| --- | --- | --- |
| `PrimaryButton` | Button | The one main action on a screen or dialog. Green is kept for this. |
| `IconButton` | Button | Icon-only tools, 40 × 40 px. |
| `ListButton` | Button | Rows in a list, such as music tracks. Bare until hovered, honey when chosen. |
| `Card` | PanelContainer | A raised tile inside a panel: lobby seats, notifications. |
| `Row` / `PlainRow` | PanelContainer | Flat bands in a list; alternate them for long lists. |
| `HeadingLabel` | Label | Serif titles and headings. |
| `SectionLabel` | Label | Small rust labels above a group of controls, usually upper case. |
| `MutedLabel` | Label | Captions, hints and secondary values. |
| `ErrorLabel` | Label | Validation messages. |

Toggle buttons, tabs and pressed buttons sink into honey wood. Switches (`CheckButton`) and checkboxes draw only their glyph and label, never a button frame.

Dialogs inherit `scenes/ui/dialog.tscn` and put their buttons in its footer: one row, right-aligned, pinned below the content when the content scrolls. Secondary buttons such as Close or Back come first and the main action comes last. Resources are picked with tiles showing their illustration (`resource_choice.tscn`), and amounts are set with − / + tiles (`resource_steppers.gd`), not dropdowns or spin boxes. Trades are always worded from the viewer's side: "You give" and "You get", whoever made the offer.

Full-window screens with many options, such as Settings, are a centred card of at most 980 × 720 px with their tabs down the left, so labels stay close to their controls on wide windows.

## In-game screen

The island needs width more than height, so the HUD keeps the sides of the window clear. The scoreboard sits in the top left corner and the tools in the top right. Each scoreboard row names who plays the seat when it isn't a present human (bot, away, or bot playing for someone who dropped) and marks your own row with you. Longest road and largest army show a +2 beside the stat that earned them. Both corners are open sea, since the camera frames the island across the full width and the island fills at most the middle half of it. On small windows the scoreboard reaches into that half, so the camera frames the island to the right of it. The resources and actions are in one bar along the bottom. Every action stays in its place all game and greys out when it doesn't apply, so the bar never changes size. Its first line says what the game is waiting for, and the buttons for a single step, such as stealing or finishing free roads, sit on that line. Development cards are small portrait cards fanned out beside the bar, one per type with a count in the corner the next card leaves in view. A title shrinks to fit that strip, down to 10 px, and past that ends in an ellipsis; pointing at a card lifts it upright and shows the whole title. On windows too narrow for the fan beside the bar, a smaller fan sits in the bar next to the resources.

## Day and night

`scripts/ui_day_night.gd` swaps the interface to its night palette at dusk. Flat colors change through its `PALETTE` table, so a style may only use a day color that table maps. Textures go through `shaders/ui_night.gdshader`, which maps them by brightness and gives primary (green) and selected (honey) wood their own night tones.

## Main-menu logo

Asset: `assets/ui/game-logo.png`, 1760 × 880 PNG with its original transparent alpha. Generated using the built-in image generation tool, then copied unchanged into the project. The menu preserves its aspect ratio.

Final generation prompt:

> Use case: logo-brand. Create one finished game logo asset for a friendly medieval cartoon island-building board game. Text verbatim: "N CATAN" (N followed by CATAN, all letters clearly readable). Wide horizontal composition, roughly 2:1. Large hand-painted warm ivory and honey-gold lettering with a sturdy dark brown outline, sitting on a softly carved wooden sign. A small charming terracotta-roof medieval cottage and pine silhouette rise above the lettering, with a subtle wheat sprig and teal ocean ribbon integrated into the crest. Match a cozy low-poly miniature world: rounded chunky forms, restrained painterly shading, friendly proportions, tactile wood, no photorealism. Make the words dominate and remain legible at 300 px wide. Original design, no copied commercial board game logo. Transparent background with real alpha, clean isolated silhouette, no rectangular backdrop, no drop shadow beyond a soft tight edge shadow. No extra text, slogans, watermarks or mockup scene.
