# Art Pipeline Specification

> Version: v0.1
> Related docs: `02-content-pack-format-spec.md` (§1.1 the isomorphic text_ref mechanism, §10 lore), `04-resources-and-effects-system.md` (§1/§2 character / enemy tables), `../framework/14-presentation-and-platform-checklist.md` #7, `../framework/04-ui-ux-design.md` §4 (ink / gold-ink palette)
> Role: the single source of truth for art assets — **directories, naming, resolution tiers, import conventions, placeholder fallback and the content-pack reference field (`art_ref`)**. Implementation follows this doc; a new asset category or field is added here before code changes.
> English mirror of `docs/tech/05-美术管线.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Directory structure

```
game/assets/art/
├── units/       # battle unit art (battlefield tokens for both sides)
├── portraits/   # character portraits (party chips / roster / dialogue)
├── scenes/      # map / site backgrounds (doc 16 §6 `background`); Home illustrations via the game manifest
└── icons/       # item icons (§7.2)
```

- Assets are version-controlled (same as fonts/audio); at runtime the shell's `ArtLoader` (`shell/ui/art_loader.gd`) reads PNGs directly via `Image.load_from_file` — the same channel as `AudioStreamWAV.load_from_file`: no import pipeline, testable headless, silent fallback on missing files;
- The first assets are generated procedurally by `game/tools/gen_art.py` (pure Python standard library, zero third-party copyright, fixed seed, byte-for-byte reproducible); real art replaces them by overwriting files of the same name, with hotspot/reference keys unchanged.

> Mobile-export note: files read with `Image.load_from_file` from `res://` must be explicitly included in the export (`*.png` in the export filter), otherwise only imported `.ctex` resources ship. Verify this in the first device build.

## 2. Naming

```
<class>_<id>_<tier>.png
```

- `<class>` = singular of the directory: `unit` / `portrait` / `scene` / `icon`;
- `<id>` = the content-pack entry id (the `id` from characters / enemies / lore, lower snake case);
- `<tier>` = pixel edge length as an integer (see §3);
- Examples: `units/unit_ink_fiend_128.png`, `portraits/portrait_companion_kelan_128.png`;
- Validation: the test layer checks every file in the directory against `^(unit|portrait|scene|icon)_[a-z0-9]+(_[a-z0-9]+)*_[0-9]+\.png$`.

## 3. Resolution tiers

| Class | 1x (baseline) | 2x (HD) | Notes |
|---|---|---|---|
| units | 64 | 128 | Battlefield tokens; portrait unit cards / landscape grid cells |
| portraits | 128 | 256 | Party chips show 1x scaled; the roster uses 2x |
| scenes | 1080 width | 2160 | Map / site backgrounds; height follows the map's `frame` aspect |
| icons | 64 | 128 | Item icons; delivered at 128 (`ArtLoader.ICON_TIER`), shown at 28–32 px in lists and 72 px in the detail sheet |

- Phase 1 delivers only the **tier currently used** (units 128, portraits 128); adding a tier = a same-named file with another tier suffix; shells fetch with `ArtLoader.texture_for(ref, tier)`;
- Missing tier fallback: fall back to the largest existing tier; if none = no-art fallback (§5).

## 4. Import conventions

- Phase-1 assets (procedural silhouettes with anti-aliased edges): **filter on (smooth)** — `ImageTexture`'s default linear filtering, not nearest-neighbour pixel art;
- If pixel-art assets are introduced later: register that subset here and switch it to filter off (set uniformly by the shell after creating the `ImageTexture`; filter mode is an asset property and never enters core);
- Transparent PNG (RGBA); silhouette bodies at 100% opacity; outlines/glows may be semi-transparent.

## 5. Placeholder rules (no-art fallback)

- **Missing art always falls back silently at runtime and never rejects loading** (same rule as a missing text_ref key in tech/02 §1.1): `ArtLoader.texture_for` returns `null` and the shell keeps its existing fallback — units = color block + single-character token, portraits = text-only chips;
- Broken links are data defects caught by test-layer assertions (every entry that declares `art_ref` must point to an existing, loadable file);
- Purely procedural presentation such as the Home painting has no external asset dependency and is its own fallback.

## 6. The art_ref field (isomorphic with text_ref)

- Entries in a pack's `characters.json` / `enemies.json` / `lore.json` may declare an optional `art_ref`;
- **Value format**: `"<category dir>/<id>"` (without the class prefix, tier or extension), e.g. `"art_ref": "units/ink_fiend"`;
- **Resolution**: `res://assets/art/<category dir>/<class>_<id>_<tier>.png` (§2/§3), path assembled by `ArtLoader`;
- **Semantics**: a pure presentation reference — never enters graph traversal, checks or event-stream resolution (same as text_variants); core only passes the data through (BattleDef puts it in the unit dictionary) and never references rendering APIs;
- **Scope**: `art_ref` is an **in-pack resource key** anchored at the framework's `res://assets/art/`; the form where a content pack ships its own art directory (an art/ merged view inside a PCK) will be specified here when the first side-arc pack with art lands;
- **Reference integrity**: a declared art_ref's file must exist, load, and match a §3 tier — checked by the test layer.

## 7. First asset batch (checklist 14 #7)

| art_ref | File | Entry | Recognition cues |
|---|---|---|---|
| `units/ink_imp` | `units/unit_ink_imp_128.png` | Ink Imp | Small ink-drop silhouette, two horn buds, ink tendrils below |
| `units/ink_fiend` | `units/unit_ink_fiend_128.png` | Ink Fiend | Bulky ink mass, horns, dripping jagged bottom edge |
| `units/page_warden` | `units/unit_page_warden_128.png` | Page Warden | Robed golem silhouette, halo of torn pages behind the head |
| `portraits/player_blank` | `portraits/portrait_player_blank_128.png` | The Unwritten | Hooded silhouette + blank-page face, gold accent |
| `portraits/companion_kelan` | `portraits/portrait_companion_kelan_128.png` | Kelan | Slender silhouette + codex satchel, teal accent |
| `portraits/companion_laofei` | `portraits/portrait_companion_laofei_128.png` | Old Fei | Stocky silhouette + iron-hook hand, orange-brown accent |

Unified style: silhouette + ink gradient + gold-ink outline (matching the Home painting, 04 §4 ink / gold-ink palette); portraits add an accent-color outline over the silhouette to tell them apart.

### 7.1 Second batch (P6.4)

`python3 game/tools/gen_art.py --new` (same style, same rules) adds:

| art_ref | Entry | Recognition cues |
|---|---|---|
| `portraits/class_harbor_guard` | Harbor Guard (class) | Broad armoured shoulders, round buckler, visor slit; steel-blue accent |
| `portraits/class_scavenger` | Scavenger (class) | Slanted hood, face scarf, hook knife; moss accent |
| `portraits/class_ink_adept` | Ink Adept (class) | Robe, raised quill, ring of ink glyphs; violet accent |
| `units/ink_swarm` | Ink Swarm | Three huddled ink blobs, many eyes |
| `units/uninked_guard` | Black Feather Guard | Head-wrap, quarterstaff, blank emblem |
| `units/tax_guard` | Tax Collector's Guard | Tall hat, halberd, ledger; crimson accent |
| `units/dock_ambusher` | Fog Wharf Ambusher | Crouched, two knives |
| `units/mercenary` | Three-Faction Mercenary | Cloak, greatsword across the back |
| `units/tide_avatar` | The Inktide Avatar | Cresting ink wave, droplet crown, several eyes |
| `units/bandit` / `units/wolf` / `units/scout` | Starter-kit enemies | Axe bandit / side-view wolf / bow scout |

Every `art_ref` in campaign01, arena and the starter kit now resolves (the test layer checks it). The hero screen shows the class portrait on each class button. `gen_art.py --home` draws the starter kit's home illustration (`kit/_game/home_art.png`, 720×1280, landmarks inside the home hotspots). Prompts for replacing all of these with generated art: tech/08.

### 7.2 Item icons and map backgrounds (P6.4)

- **Icons**: `gen_art.py --icons` draws one 128 px icon per item in every pack (campaign01, arena, riddle_maze, starter kit — 23 files, `icons/icon_<item_id>_128.png`): parts filled with material colours (glass, ink, wood, steel, paper, gold, leather) and the gold-ink rim. Lookup: the item's `art_ref` if present, otherwise `icons/<item id>`. Shown on the inventory list and detail sheet, the loadout library / pouch / equipment slots, the camp shop, and item chips in the battle quickbar (both forms). Missing icon = the button stays text-only.
- **Map backgrounds**: `gen_art.py --scenes` draws the Fog Coast region map (paper, coastline, landmarks at each location, fog in the east), the Old Lighthouse site (stone interior, lamp glow), and the starter kit's wilds and ruin. Wired through `maps.json` `background` (doc 16 §6).

## 8. Shell integration

- Portrait (`shell/portrait/`): unit cards show the art_ref image as `Button.icon` (expanded, centered, text over it with a shadow); party chips = portrait TextureRect + text (HBox);
- Landscape (`shell/landscape/`): a grid-cell token lays down a TextureRect first (aspect-fit, centered), then the HP text; dimming for dead/downed applies to the image and the background alike;
- Both shells share one `ArtLoader` (no duplicated "landscape/portrait" loading logic); no art_ref or a failed load = the §5 fallback;
- Home painting: phase 1 uses no external images; `_draw` adds procedural layers (shed-roof light strings, tower windows and beam, glints on the water), still driven by breathing and the Fading level (12 §5).

## 9. Character action animation and skill effects (P6.6)

`shell/ui/action_fx.gd` (`ActionFx`) is a presentation layer in both shells, beside the hit-feedback layer (`JuiceLayer`). It consumes the event stream only — never writes the Board or emits events (a test checks the stream is byte-identical with and without it).

- **Why a "ghost":** the shells rebuild unit nodes after every event, so a tween on the real node would be cut off. For an action, ActionFx draws a copy of the unit's art on its own layer and animates that, while the real art is made transparent (`art_alpha`); it is restored when the action ends.
- **Actions:** `lunge` (melee, toward the target), `cast` (rise and glow), `throw`, `hop` (move), `brace` (defend / buff), `down` (falls over), `revive` (rises with a glow). About 0.4 s; scaled by the auto-play speed.
- **Effects:** `slash`, `stab`, `claw`, `smash`, `bolt`, `lance`, `arc` (thrown, drawn with the item's icon), `burst`, `wave`, `heal`, `shield`, `smoke`, `summon`, `aura` — procedural strokes with a glow halo, coloured by effect and side.
- **Event mapping:** `battle.attack` → actor action + effect at the target; enemy area skills (`skill.use` from an enemy, `battle.skill`) → cast + effect on every party member; healing skills (`MSG_SKILL_HEAL`) → cast + `heal`; utility skills (`MSG_SKILL_USED`) → `brace`/`cast` + their effect; thrown items → `throw` + `arc`; `battle.move` → `hop`; `battle.down` / `battle.revive`.
- **Data:** `fx` / `fx_color` / `attack_fx` (tech/04 §2); inference fallback when absent.
- **Sprite strips (optional, override the procedural drawing):**
  - effects: `game/assets/art/fx/fx_<name>.png` — one horizontal strip of square frames (frame width = image height), played at 24 fps at the target (projectiles travel along their path);
  - unit actions: `game/assets/art/anims/anim_<art id>_<action>.png` — same format; `<art id>` is the `<id>` part of the unit's `art_ref` (e.g. `anim_ink_fiend_lunge.png`, `anim_class_scavenger_cast.png`).
  Prompts: tech/08 §3.5–§3.6.

## 10. Game UI kit (P6.6)

- **`UiKit`** (`shell/ui/ui_kit.gd`) builds the whole theme: buttons (normal / hover with outer glow / pressed / disabled), panels, bottom sheets (rounded top, square bottom), toast ribbons, input fields, sliders (gem grabber), scroll bars, progress bars, tabs, tooltips, popup menus. Frames are **9-slice textures rendered at start-up from the palette tokens** (double gold-ink border, inner rule, corner studs and filigree, gradient fill), so a new game's `theme.palette` re-colours everything with no new art.
- **External art overrides:** a file `ui_<name>.png` in `game/assets/art/ui/` (or the manifest's `theme.ui_dir`) replaces the generated frame of that name. Names, sizes and 9-slice margins: `button`, `button_hover`, `button_pressed`, `button_disabled` (48 px, margin 14), `panel` and `sheet` (96 px, margin 26), `toast` (64 px, margin 22), `field` and `tooltip` (32 px, margin 10), `track`, `fill`, `grabber` (16 px, margin 7). Prompts: tech/08 §3.4.
- **Type variations:** `TitleLabel` (gold, outlined, title font), `ToastLabel` (ribbon), `FramePanel` (roomy ornate panel — the default panel keeps 4 px content margins so existing layouts don't change size).
- **Title font:** the manifest's `theme.title_font` (a font file path) is used for `TitleLabel`; without it, the bold body font.
- **`UiFx`** (`shell/ui/ui_fx.gd`), installed on the scene tree by `main`, applies motion with no per-screen code: buttons press to 0.94 and spring back (hover brightens on desktop); labels with a font size ≥ 20 and no custom colour become `TitleLabel`; bottom sheets (marked by `Palette.sheet_style()`) pop up and fade in when shown; toasts pop in (`UiFx.pop`). Only `scale`, `modulate` and the type variation are touched — never layout positions. A node with meta `no_ui_fx` is skipped.
- **Layout rule learned the hard way:** any code that sizes children from a container's `size` must subtract that container's stylebox `get_minimum_size()` — otherwise themed padding makes the child exactly too big and the layout loops (the landscape grid did this).

## 11. Delivered art, act scenes and brand (2026-11-11)

- **Final art replaced the placeholders file by file** (portraits, units, icons, map / site backgrounds) — same names, sizes and transparency rules, so no code changed. `gen_art.py` / `gen_audio.py` now **skip files that already exist** (`--force` to overwrite) so a placeholder run can never clobber final art.
- **Act scenes** `scenes/scene_act_<1-5>_1080.png` (1080×1935): `nodes.json` acts declare `"art_ref": "scenes/act_<n>"`; `StoryVM` passes the current act's scene as `vm.scene`; `SceneBackdrop` (`shell/ui/scene_backdrop.gd`, both shells) cover-fills the main view behind the story (dim 0.55, story text on a translucent reading panel) and behind battles of that act (dim 0.3). Missing file = no backdrop.
- **Battle cards with real art:** portrait unit cards put the art on top and name / HP below (`vertical_icon_alignment = TOP`); landscape tokens put the text at the cell bottom — text never covers a face.
- **Map positions follow the art:** a location's `pos` is presentation only, so after new map art arrives the locations / areas are nudged onto the painted landmarks (Fog Coast: Fishers' Row, chapel, lighthouse; Old Lighthouse: lamp room, storeroom; starter wilds and ruin).
- **Home:** `scenes/scene_home_ashenport_1080.png` with image-space hotspots (tech/07 §5); hotspots are drawn as breathing corner brackets rather than boxes.
- **Brand** (`game/assets/brand/`): `app_icon_1024.png` and 512 / 192 / 180 / 167 / 152 / 120 / 87 / 80 / 76 / 60 / 58 / 40 px sizes (RGB, no alpha), Android adaptive background (the full icon) + transparent foreground, `key_art_landscape.png`, `key_art_phone.png` (boot splash, iOS launch storyboard). Store use: `docs/en/store/store-listing.md`.

