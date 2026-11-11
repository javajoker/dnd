# art_src — source files for imported art (not shipped)

Delivered originals kept so the game-side versions can be regenerated. Nothing here is read by the game.

| Source | Game file(s) | Re-import |
|---|---|---|
| `ui/ui_*.png` (1024², transparent padding) | `game/assets/art/ui/ui_*.png` + `ui_kit.json` (9-slice margins) | `godot --headless --path game -s tools/import_ui_kit.gd -- ../art_src/ui` |
| `anims/<art id>_<action>_<N>f.jpg` (N poses in one row; JPEG with the checkerboard painted in) | `game/assets/art/anims/anim_<art id>_<action>.png` (square frames, transparent) | `godot --headless --path game -s tools/import_anim_strip.gd -- ../art_src/anims/companion_kelan_lunge_10f.jpg 10 anim_companion_kelan_lunge` |
| `app_icon.webp`, `key_art_*.webp` | `game/assets/brand/*` | converted once (see tech/05 §11) |

Prefer PNG with real transparency for future animation sheets — the importer keeps an existing alpha channel and skips background removal.
