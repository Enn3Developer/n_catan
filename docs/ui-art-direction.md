# Storybook interface

The shared UI uses warm parchment, carved wooden borders, brass details, and moss-green primary actions to match the miniature medieval island. Fira Sans keeps controls readable; Noto Serif adds character to headings. Both font licenses ship with exports.

Run `python3 tools/build_ui_theme.py` from the repository to rebuild the authored SVG surfaces and `assets/ui_theme.tres`. The nine-slice surfaces stretch across menus and HUD panels without stretching their corners. Resource and development-card illustrations retain their own palettes.

## Main-menu logo

Asset: `assets/ui/game-logo.png`, 1760 × 880 PNG with its original transparent alpha. Generated using the built-in image generation tool, then copied unchanged into the project. The menu preserves its aspect ratio.

Final generation prompt:

> Use case: logo-brand. Create one finished game logo asset for a friendly medieval cartoon island-building board game. Text verbatim: "N CATAN" (N followed by CATAN, all letters clearly readable). Wide horizontal composition, roughly 2:1. Large hand-painted warm ivory and honey-gold lettering with a sturdy dark brown outline, sitting on a softly carved wooden sign. A small charming terracotta-roof medieval cottage and pine silhouette rise above the lettering, with a subtle wheat sprig and teal ocean ribbon integrated into the crest. Match a cozy low-poly miniature world: rounded chunky forms, restrained painterly shading, friendly proportions, tactile wood, no photorealism. Make the words dominate and remain legible at 300 px wide. Original design, no copied commercial board game logo. Transparent background with real alpha, clean isolated silhouette, no rectangular backdrop, no drop shadow beyond a soft tight edge shadow. No extra text, slogans, watermarks or mockup scene.
