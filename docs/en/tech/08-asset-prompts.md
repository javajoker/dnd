# tech/08 · Asset Prompt Pack — art, music and sound from external AI tools

> Status: **ready to use** (TASKS P6.4, 2026-11-10). Related: tech/05 (art pipeline: folders, naming, sizes, fallback), tech/07 (new-game kit: game manifest `audio` / `theme`), doc 14 (presentation checklist).
> Scope: every asset the game can show or play, with a copy-ready prompt for an external generator, the target file name and the delivery spec. Today each slot is filled by a **procedural placeholder** (`game/tools/gen_art.py`, `game/tools/gen_audio.py`); a generated asset replaces it by **overwriting the same file name** — no code or data change.

---

## 1. How to use this pack

1. Pick a tool per asset type (examples, not endorsements): images — Midjourney, DALL·E / ChatGPT image, Stable Diffusion XL / Flux (local), Adobe Firefly; music — Suno, Udio, Stable Audio; sound effects — ElevenLabs Sound Effects, Stable Audio.
2. Paste the **style prefix** (§2) in front of every image prompt, then the asset prompt. Use the negative prompt where the tool supports one.
3. Generate 4+ candidates, pick the one that **reads as a silhouette at 64 px** (units/portraits are shown small on phones).
4. Post-process (§6), save under the exact file name, run the checks in §7.
5. Keep a log (`docs/en/tech/08-asset-log.md`, create it on first use): asset, tool, model/version, prompt, seed, date, licence tier. Stores and publishers may ask.

### 1.1 Licence and store rules (check before shipping)

- Use a plan whose terms grant **commercial use** of outputs (most free tiers don't). Keep the receipt/terms version in the log.
- **Never** name living artists, studios, franchises or trademarked settings in prompts ("in the style of …"). The game's own words (Ashenport, the Fading, Ink Fiend …) are fine.
- Steam asks for an **AI-generated content disclosure**; Apple and Google don't require one today, but the store listing (`docs/en/store/store-listing.md`) must not claim hand-made art if it isn't.
- Music: choose instrumental, no vocals, and confirm the tool's terms allow use in a commercial game and on streams.

## 2. Style bible (images)

**Look**: dark ink-wash fantasy. Deep blue-black ink, aged paper, **gold-ink** line highlights; one identity colour per character. Painterly but with a clean, readable silhouette. Light from the upper left. No text in the image.

**Palette** (matches the UI tokens in `packs/_game/game.json` and the placeholders): ink `#1A1A2C` → `#04040C`, paper `#D8D1B8`, gold ink `#E0B552`, ember `#F28C33`; identity colours — the Unwritten gold, Kelan teal `#5CB8AC`, Old Fei rust `#D8843E`, Harbor Guard steel blue `#78A0D4`, Scavenger moss `#96B460`, Ink Adept violet `#A880DC`, hostile humans crimson `#C44848`.

**Style prefix** (paste first):

```
Dark ink-wash fantasy game art, deep blue-black ink with aged-paper tones and glowing gold-ink linework, painterly brush texture, strong readable silhouette, rim light from upper left, muted palette with one accent colour, centered subject, no text, no watermark,
```

**Negative prompt**:

```
text, letters, watermark, signature, logo, frame, border, photorealistic, 3d render, anime, chibi, cute, gore, extra limbs, blurry, cropped head, busy background
```

## 3. Characters, units and icons

Delivery: transparent PNG (RGBA), square; generate at 1024 px, deliver **128 px** (and optionally 256 px as `_256`), subject filling ~80% of the frame. Path `game/assets/art/<folder>/<file>`.

### 3.1 Portraits (`portraits/`) — bust, three-quarter view, plain dark background (to be removed)

| File | Prompt (after the style prefix) |
|---|---|
| `portrait_player_blank_128.png` | hooded wanderer whose face is a blank page of old paper, no features, gold-ink outline around the hood, calm and uncanny, the Unwritten |
| `portrait_companion_kelan_128.png` | slender young archivist in a long grey-blue robe, short dark hair, a leather satchel stuffed with copied pages, ink-stained fingers, teal accent, wary but kind eyes |
| `portrait_companion_laofei_128.png` | stocky old harbour crane-master, grey beard, weathered face, an iron boat-hook in place of his left hand, oilskin coat, rust-orange accent, gruff warmth |
| `portrait_class_harbor_guard_128.png` | broad-shouldered harbour guard in dented plate over a tabard, round dock buckler with a gold rivet, helmet with a visor slit, steel-blue accent, steady stance |
| `portrait_class_scavenger_128.png` | lean wreck-scavenger in a slanted hood and face scarf, hook knife at the hip, salvage pouch, moss-green accent, sharp watchful eyes |
| `portrait_class_ink_adept_128.png` | young scribe-mage in a long robe raising a quill that drips glowing ink, small floating ink glyphs circling them, violet accent, focused expression |

### 3.2 Battle units (`units/`) — full body, facing the viewer, plain dark background

| File | Prompt |
|---|---|
| `unit_ink_imp_128.png` | small blob of living ink with two horn buds and dripping tendrils, glowing gold eyes, mischievous |
| `unit_ink_fiend_128.png` | hulking ink creature with heavy shoulders and curved horns, ink dripping from its jagged lower edge, glowing gold eyes, menacing |
| `unit_ink_swarm_128.png` | a cluster of three small ink blobs huddled together, many tiny glowing eyes, dripping |
| `unit_page_warden_128.png` | tall robed scribing golem, a halo of torn floating pages behind its head, face mask with a thin gold slit, rigid and mechanical, the Scriptorium's enforcer |
| `unit_tide_avatar_128.png` | towering wave of black ink shaped like a cresting tide, a crown of ink droplets, several glowing gold eyes inside the wave, the Inktide Avatar, final boss presence |
| `unit_uninked_guard_128.png` | rebel guard in a cloth head-wrap and patched coat, long quarterstaff, a blank white emblem on the chest, Black Feather Guard |
| `unit_tax_guard_128.png` | uniformed tax collector's guard in a tall hat with a crimson band, halberd, an open ledger under one arm, stern bureaucrat soldier |
| `unit_dock_ambusher_128.png` | crouching dockside ambusher with two short knives, hood and mask, fog wisps around the feet |
| `unit_mercenary_128.png` | hardened mercenary with a cloak and a greatsword slung across the back, mismatched armour pieces from three factions |
| `unit_bandit_128.png` *(starter kit)* | hooded road bandit with a hand axe, ragged cloak |
| `unit_wolf_128.png` *(starter kit)* | lean grey wolf in side view, ears up, long tail, one glowing eye |
| `unit_scout_128.png` *(starter kit)* | light-armoured scout with a short bow, cloak, alert pose |

### 3.3 Item icons (`icons/`, 128 px)

Shown in the inventory, loadout, camp shop and battle quickbar (tech/05 §7.2). File `icon_<item_id>_128.png`, transparent background; keep the object bold — it is shown as small as 28 px. Prompt pattern: *"single object icon, centered, three-quarter view, dark background, gold-ink rim light: …"*

| Item id | Object |
|---|---|
| `heal_potion` | stoppered glass vial of pale blue restorative draught |
| `ink_flask` | squat flask of black ink with a wax seal |
| `ink_salve` | small tin of dark salve with a violet glow |
| `tide_bomb` | round clay bomb wrapped in net, sea-water sloshing inside, short fuse |
| `ink_core` | fist-sized crystal of solid ink with a gold heart |
| `codex_fragment` | torn page fragment with faint glowing script |
| `fatedie` | ornate twenty-sided die of bone and gold |
| `half_tide_table` | half of a torn tide chart, wave lines and numbers (no legible text) |
| `scriptorium_signet` | heavy gold signet ring with a quill seal |
| `black_feather_token` | black feather tied to a bone token |
| `boathook_axe` | axe with a hooked back spike, rope-wrapped haft |
| `padded_coat` | quilted padded coat, salt-stained |
| `dock_buckler` | small round buckler with a central gold rivet |
| `tide_charm` | shell-and-cord charm with a pearl |
| `salvage_gloves` | worn leather work gloves with brass knuckle plates |
| `scribe_ring` | thin silver ring engraved with a quill |
| `dock_tally` | wooden tally stick with notches |
| `novice_quill` | simple goose quill with an ink-stained tip |
| `torn_ribbon` | torn red ribbon with a blank white seal |
| `appraisal_loupe` | brass jeweller's loupe on a chain |
| `potion` *(starter kit)* | red healing potion in a round flask |
| `longsword` *(starter kit)* | plain steel longsword with a leather grip |
| `riddle_page` *(Riddle Maze)* | parchment page with a spiral puzzle glyph |

### 3.4 UI kit frames (`ui/`, 9-slice) — optional, the game draws its own from the palette

Each file replaces the generated frame of the same name (tech/05 §10). Draw **one square frame per file**, centred, with flat, even edges so it stretches cleanly; ornaments only in the corners (the corners are not stretched). Transparent outside the frame. Keep text-free.

| File | Size | Corner margin | Prompt (after the style prefix) |
|---|---|---|---|
| `ui_button.png` | 48×48 (draw at 192, downscale) | 14 | game UI button frame, dark ink-blue gradient fill, thin double gold-ink border, tiny gold diamond studs in the four corners, flat straight edges, no text, transparent background |
| `ui_button_hover.png` | 48×48 | 14 | same frame, slightly lighter fill, brighter gold border with a soft outer glow (glow inside the 3 px padding) |
| `ui_button_pressed.png` | 48×48 | 14 | same frame pressed in: darker fill with an inner shadow at the top, bright gold border |
| `ui_button_disabled.png` | 48×48 | 14 | same frame greyed out: grey fill, faded grey border, no studs |
| `ui_panel.png` | 96×96 (draw at 384) | 26 | ornate dark panel frame, deep ink gradient fill, double gold-ink border with an inner hairline, gold filigree corner ornaments with a small diamond, plain straight edges between corners |
| `ui_sheet.png` | 96×96 | 26 | bottom-sheet frame: rounded top corners with gold filigree, square bottom edge with no border, deep ink fill |
| `ui_toast.png` | 64×64 | 22 | ribbon banner frame, pill shape, dark fill, gold border, small notches at both ends |
| `ui_field.png`, `ui_tooltip.png` | 32×32 | 10 | simple inset field frame, very dark fill, thin gold border |
| `ui_track.png` / `ui_fill.png` / `ui_grabber.png` | 16×16 | 7 | slider track (dark groove, faint gold rim) / filled part (gold gradient) / scroll grabber (translucent gold pill) |

**Fonts** (`theme.title_font`): pick an openly licensed display face (SIL Open Font License) for titles — a classical serif in the spirit of carved inscriptions or old book titles works with this world; check it covers every character your locales need (the body font stays Noto Sans SC for Chinese). Put the file in `game/assets/fonts/` with its licence text, and set `"title_font": "res://assets/fonts/<file>"` in `packs/_game/game.json`.

### 3.5 Unit action animations (`anims/`, sprite strips) — optional

The game animates a still portrait procedurally (tech/05 §9); a strip replaces that for one unit and one action. Format: **one horizontal strip of square frames**, frame size = image height (256 px recommended), **8–12 frames**, transparent background, the character centred and the same scale in every frame, feet on the same baseline. File `anim_<art id>_<action>.png` where `<art id>` is the unit's art id (`ink_fiend`, `companion_kelan`, `class_scavenger` …) and `<action>` ∈ `lunge`, `cast`, `throw`, `hop`, `brace`, `down`, `revive`.

Generic prompt (image tools that make sprite sheets, e.g. a model fine-tuned for sprite sheets, or generate frames one by one with a fixed seed and the same reference image):

```
[style prefix] sprite sheet, 10 frames in one horizontal row, same character in every frame: <character description from §3.1/§3.2>, performing <action>: <action description>, consistent proportions and lighting, transparent background, no text
```

| Action | Description to insert |
|---|---|
| `lunge` | steps forward and strikes with the weapon, then recovers to the start pose |
| `cast` | raises a hand or quill, a glow gathers, releases forward, returns |
| `throw` | winds up and throws an object forward, follow-through, returns |
| `hop` | small hop forward and lands with a slight squash |
| `brace` | plants feet and raises guard or shield, holds, relaxes |
| `down` | staggers and collapses to the ground, ends lying still |
| `revive` | pushes up from the ground to standing, a faint golden glow |

Tip: if the tool can't keep the character consistent, generate the key poses (start / peak / end) and in-between with an interpolation tool, then lay them out in a strip.

### 3.6 Skill effects (`fx/`, sprite strips) — optional

Format as §3.5 (horizontal strip of square frames, 256 px, 8–16 frames, transparent background, **effect centred**, additive-looking glow on black is fine if your tool can't do transparency — remove the black with a "screen" blend or a luminance key). File `fx_<name>.png`.

| File | Prompt (after "game VFX sprite sheet, N frames in one row, transparent background, no text,") |
|---|---|
| `fx_slash.png` | a curved white-gold blade slash arc sweeping across, ink droplets trailing |
| `fx_stab.png` | a quick straight thrust streak with a spark burst at the tip |
| `fx_claw.png` | three parallel violet-black ink claw marks raking diagonally |
| `fx_smash.png` | a heavy impact shockwave ring with radiating cracks and dust |
| `fx_bolt.png` | a glowing violet ink orb with a short trailing tail, then a small burst |
| `fx_lance.png` | a narrow violet ink spear of light, then a piercing flash |
| `fx_arc.png` | a splash of sea water bursting outward in droplets (the thrown-bomb impact) |
| `fx_burst.png` | an expanding ring of dark violet ink with droplets flung outward |
| `fx_wave.png` | a black ink tide wave rising and crashing forward |
| `fx_heal.png` | soft green-gold sparkles and small crosses rising, a gentle ring |
| `fx_shield.png` | a hexagonal gold-ink barrier forming, pulsing once, fading |
| `fx_smoke.png` | a grey smoke puff expanding and thinning out |
| `fx_summon.png` | a swirling dark portal of ink opening on the ground |
| `fx_aura.png` | rising red-gold streaks around a figure's silhouette area, empowering aura |

## 4. Scenes and maps

Delivery: opaque PNG/JPG. Portrait **1080×1920** (time form), landscape **1920×1080** (space form). Keep the edges calm — screens crop with "cover" scaling.

### 4.1 Home illustration (game manifest `theme.home_art`)

The home screen's hotspots are fixed normalized rectangles (`shell/ui/home_scroll.gd` `HOTSPOTS`); the picture must put each landmark inside its box (x, y, w, h as fractions of the image):

| Landmark (opens) | Box |
|---|---|
| Lighthouse / tide tower (Campaigns) | 0.06, 0.10, 0.15, 0.42 — tall, left |
| Market sheds (Inventory) | 0.50, 0.48, 0.26, 0.18 — centre-right, mid |
| Campfire with companions (Party) | 0.28, 0.62, 0.18, 0.24 — centre-left, low |
| Notice board (Events) | 0.78, 0.64, 0.18, 0.26 — right, low |
| Pile of torn pages and a hidden codex (History) | 0.04, 0.72, 0.20, 0.24 — left, bottom |

Prompt (1080×1920, file `game/assets/art/scenes/scene_home_ashenport_1080.png`, then set `"home_art": "res://assets/art/scenes/scene_home_ashenport_1080.png"` in `packs/_game/game.json`):

```
[style prefix] vertical night panorama of a fading harbour city, sea horizon at 55% height, a tall tide tower with three lit windows on the far left, market sheds with warm lanterns centre-right, a small campfire with two seated companions lower centre-left, a wooden notice board covered in paper notes lower right, a pile of torn pages and a half-hidden book lower left, parts of the city dissolving into blank paper at the edges, stars fading, calm melancholy, composition with clear empty space between landmarks
```

The starter kit's procedural crossroads (`game/kit/_game/home_art.png`) uses the same boxes: watchtower / inn and stalls / campfire / notice board / chest and books.

### 4.2 Region and site maps (doc 16)

Each image covers the map's `background.frame` grid rectangle (doc 16 §6), so **landmarks must sit where the locations are**. Positions below are fractions of the image (x from the left, y from the top); keep a clear patch at each so the location button doesn't hide the drawing entirely. Leave out routes — the game draws them.

| File | Size | Landmarks (x, y) | Prompt |
|---|---|---|---|
| `scenes/scene_map_fog_coast_1080.png` | 1080×810 (frame 8×6) | plaza 0.12, 0.83 · Fishers' Row 0.25, 0.50 · Sunken Bell Chapel 0.50, 0.83 · Old Lighthouse 0.62, 0.17 · Salt Marsh 0.88, 0.50 | top-down hand-drawn fantasy region map on aged paper, sea in the upper left with the coastline running diagonally, a small town square lower left, a row of fishers' huts on the shore middle left, a chapel with a bell tower half sunk in a pond lower middle, an old striped lighthouse on a headland at the top, a reedy salt marsh on the right under thick fog, scattered pines, ink-wash fog banks, no labels, no text, no roads |
| `scenes/scene_site_lighthouse_1080.png` | 1080×720 (frame 6×4) | Entry Hall 0.17, 0.75 · Keeper's Room 0.50, 0.50 · Hidden Storeroom 0.67, 0.75 · Lamp Room 0.83, 0.25 | interior of an old stone lighthouse seen as one wide cut-away wall, an arched doorway lower left, a keeper's bed and desk in the middle by a moonlit window slit, stacked crates in a hidden recess lower right, the great lamp and lens glowing warm upper right, dark ink-wash stonework, no text |
| `scenes/scene_map_wilds_1080.png` *(starter kit)* | 1080×1080 (frame 5×5) | inn 0.20, 0.60 · grove 0.60, 0.20 · ruin 0.80, 0.80 | hand-drawn wilderness map on pale green paper, a river crossing diagonally, a lone inn on the left, a dense pine grove at the top, broken columns of a ruin lower right, no text |
| `scenes/scene_site_ruin_1080.png` *(starter kit)* | 1080×540 (frame 4×2) | gate 0.25, 0.50 · hall 0.75, 0.50 | stone floor of a ruined temple seen from above at an angle, a broken gate arch on the left, a row of cracked columns on the right, rubble, no text |

To use a different size or frame, change `background.frame` in `maps.json` and keep the image at the same aspect ratio.

### 4.3 Act scenes (story backgrounds, reserved)

One per act, 1080×1920, file `scenes/scene_act_<n>_1080.png`: *Tidewake* (dawn at a ruined pier, a figure waking on wet planks); *The Faded Street* (a street whose house fronts fade into blank paper); *Three Pens* (three faction banners — a gold quill, a black feather, a salvage hook — over a crowded square); *The Revoked Quarter* (a silent district where people are half-erased outlines); *The Harbor's Last Page* (a black ink tide rising over the harbour at night, a lone lighthouse beam).

### 4.4 Store and app icon

- **App icon** 1024×1024, no transparency: *a single gold-ink twenty-sided die on a blank page torn at the edges, dark ink background, bold and simple, readable at 48 px.* No words.
- **Key art** 2048×1152 (landscape) and 1290×2796 (phone): the three companions on a pier facing a rising ink tide, gold light from the lighthouse. Leave the top third calm for the title, which is added as text later (never let the generator draw text).

## 5. Music and sound

Delivery: **WAV, 44.1 kHz, 16-bit** (mono or stereo), file `game/assets/audio/<name>.wav`. Loops must start and end cleanly (see §6.2). The game maps states and events to names in `packs/_game/game.json` → `audio` (tech/07 §3).

### 5.1 Music (instrumental, no vocals)

Common prompt suffix: *"instrumental, no vocals, seamless loop, game background music, not too busy, leaves room for sound effects"*.

| File | Plays when | Length | Prompt |
|---|---|---|---|
| `bgm_camp.wav` | hub / camp | 30–60 s loop | quiet harbour camp at night, soft solo cello and plucked lute, distant sea, A minor with an added ninth, 60 BPM, warm but melancholy |
| `bgm_explore.wav` | story scenes | 30–60 s loop | curious exploration through a fading port city, plucked harp arpeggios, low string drone, sparse flute melody, D dorian, 84 BPM, gentle forward motion |
| `bgm_map.wav` | region / site maps | 30–60 s loop | travelling along a foggy coast, frame drum walking pulse, hurdy-gurdy drone, pentatonic whistle melody, A minor, 96 BPM, steady and adventurous |
| `bgm_battle.wav` | combat | 45–90 s loop | tense dark-fantasy skirmish, taiko and low strings, staccato cello ostinato, brass swells, D minor, 120 BPM, driving but not epic-orchestral |
| `bgm_ending.wav` | ending screen | 30–60 s loop | bittersweet resolution at dawn, slow piano and strings, soft celesta bells, F major, 66 BPM, hopeful and quiet |
| `tide_loop.wav` | home ambience | 10–30 s loop | ambient harbour at night: slow waves on stone, faint rigging creaks, distant gull, no music |

### 5.2 Sound effects (dry, no reverb tail longer than the length given)

| File | Event | Length | Prompt |
|---|---|---|---|
| `dice_roll.wav` | any check | 0.4–0.7 s | a bone die rattling and tumbling on a wooden tray |
| `dice_land.wav` | die settles | 0.1–0.3 s | a single die landing on wood, soft knock |
| `hit.wav` | attack hits | 0.15–0.35 s | blunt melee impact on leather armour |
| `crit.wav` | critical hit | 0.25–0.5 s | heavy impact with a bright metallic ring |
| `heal.wav` | healing | 0.4–0.8 s | three soft rising chime notes, gentle magical warmth |
| `page.wav` | screen change | 0.15–0.4 s | a single paper page turning |
| `ui_click.wav` | buttons | 0.05–0.15 s | soft wooden tick, subtle UI click |
| `coin.wav` | gold gained | 0.3–0.7 s | two small gold coins clinking |
| `door.wav` | entering a new area | 0.6–1.2 s | old wooden door creaking open, ending in a soft thud |
| `card.wav` | event card choice | 0.15–0.4 s | a playing card flicked onto a table |
| `link.wav` | party link / message | 0.5–1.0 s | ethereal two-tone shimmer rising in pitch, magical message sent |
| `throw.wav` | thrown item | 0.25–0.6 s | short whoosh of an object thrown past |

## 6. Post-processing

### 6.1 Images

1. Remove the background for units/portraits (tool's own remover, or `rembg`), keep soft edges.
2. Crop square with the subject centred, ~10% margin; downscale with a high-quality filter (Lanczos) to 128 px (and 256 px if wanted).
3. Check at 64 px on a dark background: the silhouette must still read; boost the rim light if not.
4. Save as RGBA PNG under the exact name; scenes as PNG or high-quality JPG (keep the `.png` name or update the manifest path).

### 6.2 Audio

1. Trim silence at the start; normalise peaks to about −1 dBFS; loudness around −16 LUFS for music, −14 for SFX.
2. Loops: cut on a bar line, crossfade the last 0.5 s into the start (Audacity: select the tail, *Crossfade Clips*), check by looping playback; export 44.1 kHz 16-bit WAV.
3. Looped files keep `edit/loop_mode=2` in their `.wav.import` (already set for every BGM; Godot re-imports on next launch).

## 7. Delivery checklist

- [ ] File name and folder exactly as above (lower snake case, size suffix for art).
- [ ] Run the game's checks from `game/`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tests/run.gd
```

  The art test checks every `art_ref` resolves, sizes and transparency; the audio test checks sample rate and **length windows** — if a new track is longer than the window in `test_audio` (`expects` in `game/tests/run.gd`), widen that window in the same change.
- [ ] For animations and UI frames: `--fx-shots` (effects mid-animation, add `--landscape`), `--camp-shots`, `--split-shots`, `--home-shot` show the UI kit on real screens.
- [ ] Look at it in context: `godot --path game -- --locale=en --hero-shots` (class portraits), `--icon-shots` (item icons), `--home-shot` (home art), `--map-shots` (maps; add `--landscape` for the space form), `--m3-shots` (battle units); images land in `/tmp`.
- [ ] Add the asset to the log (§1) and keep the placeholder generator unchanged (it stays the fallback for new games).
