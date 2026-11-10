# tech/07 · New-Game Kit — building another game on this framework

> Status: **implemented** (TASKS P5.4, 2026-11-10); remaining gaps in §5. Related: whitepaper §1/§10/§14, tech/02 (pack format), tech/03 (authoring guide), tech/05 (art pipeline), docs 15–17.

**Goal**: the framework is a reusable tabletop-RPG engine (d20 rules, story graph, World State Board, encounters, maps, party split, dice). A new narrative game is made by **changing story, art, music and theme data** — never the engine. This document is the contract that says exactly what a new game supplies and what it gets for free.

## 1. What stays fixed (the engine)

| Layer | Provided by the framework |
|---|---|
| Rules | d20 core + rule packs (doc 05; Light v1 = doc 11): checks, advantage, Inspiration, combat, rests, Hit Dice, equipment, items |
| Story | Story graph with five edge types + split/remote edges (docs 08, 15), condition/effect DSL, quests, endings, NG+ carry-over and feature progression |
| World | Board with namespaces and provenance, Doom Clock, reputation, alignment, bonds, lore (doc 07) |
| Exploration | Hub, camp, region maps, site maps, event tables, event cards (doc 16) |
| Encounters | Six-state encounter machine, loadout v2, quickbar, auto-play, both forms (doc 09) |
| Presentation | Portrait time form and landscape space form, dice strip/tray/key dice (doc 17), split view (doc 15), History Scroll, settle, home |
| Platform | Saves, i18n (`Texts` + pack `texts/<locale>.json`), safe areas, store/entitlements, export presets |

## 2. What a new game supplies

| Asset | Where | Format / spec |
|---|---|---|
| **Game manifest** | `game/packs/_game/game.json` (§3) | Title, default campaign, enabled packs, theme font, audio map, store ids |
| **UI flavour texts** | `game/packs/_game/texts/<locale>.json` | Overrides for the framework's neutral UI wording — camp title, Doom Clock mood lines, "saved" wording, lock texts, faction and Compendium-series names, rest messages (§3.1) |
| **Story** | `game/packs/<pack_id>/` | tech/02: `manifest.json`, `nodes.json`, `events.json`, `encounters.json`, `characters.json`, `enemies.json`, `skills.json`, `items.json`, `flags.json`, `endings.json`, `lore.json`, `maps.json` + `tables.json` (doc 16) |
| **Text** | `game/packs/<pack_id>/texts/<locale>.json` | Long text via `text_ref`, short text via convention keys (tech/02 §1.1); `source_locale` per pack |
| **Art** | `game/assets/art/…` + `art_ref` fields | tech/05: portraits, unit tokens, map backgrounds, area art; missing art falls back to placeholders |
| **Music & sound** | `game/assets/audio/…` + the game manifest `audio` map | BGM per state (home / camp / explore / battle / ending / map), SFX per event; missing files are tolerated silently |
| **Theme** | Game manifest `theme` | Palette tokens, fonts per locale, dice skin, title art |
| **Store data** | `docs/en/store/` pattern | Listing, privacy, product ids (doc 06 strategies per market) |

## 3. The game manifest (new)

```json
{
  "id": "codex_ashenport",
  "title_key": "game.title",
  "default_campaign": "campaign01",
  "packs": ["campaign01", "arc_tide", "arena", "riddle_maze"],
  "rule_pack": "light_v1",
  "locales": ["en", "zh-CN"],
  "theme": { "palette": "ink_gold", "font": { "en": "fonts/serif.ttf", "zh-CN": "fonts/NotoSansSC-Regular.otf" },
             "dice_skin": "default" },
  "audio": { "bgm": { "camp": "bgm_camp", "explore": "bgm_explore", "map": "bgm_map",
                      "battle": "bgm_battle", "ending": "bgm_ending" },
             "sfx": { "dice_roll": "dice_roll", "dice_land": "dice_land", "hit": "hit", "crit": "crit", "heal": "heal",
                      "coin": "coin", "door": "door", "card": "card", "link": "link", "throw": "throw" },
             "ambient": { "home": "amb_tide" } },
  "store": { "full_unlock": "entitlement.campaign01_full" }
}
```

The current game is the first instance (`packs/_game/`); the starter kit has its own (`kit/_game/`). Read by `GameManifest` (`shell/ui/game_manifest.gd`): `main` (default campaign, enabled packs, ops config under the same packs root), `AudioManager` (BGM per state, sound-effect names, loops, home ambience), `UITheme` (font). Missing keys fall back to the framework defaults.

### 3.1 UI flavour texts

The framework's UI tables (`texts_en.gd` / `texts_zh.gd`) keep **neutral** wording ("Camp", "Progress saved.", "This chapter isn't unlocked yet."). A game layers its own voice on top with `packs/_game/texts/<locale>.json` — the same keys, any subset; dictionary keys (`FACTION_NAMES`, `CODEX_SERIES`, `CODEX_REWARDS`) are JSON objects. *The Age of the Codex* moves 24 keys there ("Ashenport · Camp", "Codex recorded.", the ink-themed Doom Clock lines, the faction and series names…).

## 4. Recipe: a new game in ten steps

1. Copy `game/kit/starter/` (a minimal English-source campaign: crossroads, an inn hub with a shop, a check with a failure branch, two battles, an ending, a region map with a ruin site, an event table and an event card) to `game/packs/<new_id>/`, and `game/kit/_game/` to `game/packs/_game/` — or first run the kit untouched as its own game: `godot --path game -- --packs-root=res://kit`;
2. Edit the **game manifest** (§3) and the **UI flavour texts** (§3.1): title, packs, theme, audio map, your game's voice;
3. Write the **world and campaign book** in `docs/en/story/` (design intent first, as with *The Age of the Codex*);
4. Transcribe the book into pack data (tech/03), choosing the **form** per campaign: space → landscape, time → portrait, or `choice` (doc 09 §2; doc 15 §6 for side campaigns);
5. Add **characters, skills, items, gear** — reuse the rule pack; only numbers and names change;
6. Draw the **maps** and write the **event tables** (doc 16); decide the **progression** per playthrough (doc 15 §7);
7. Add **art** (`art_ref`) and **audio** (manifest `audio` map) — placeholders work until assets arrive;
8. Run `tools/packlint.gd -- packs/<id>` (V1–V21) and the bot simulation (`tools/simulate.gd -- 24 packs/<id>`: every run reaches an ending, the Doom Clock stays in range, ≥95% node coverage; the bot also explores maps, sites and party splits) until both are green; check battle win rates against their bands;
9. Capture screenshots per locale/form (`--locale=…` shot flags) and play through on device;
10. Fill the store documents and choose the monetization strategy per market (doc 06) — content data stays identical across markets.

## 5. What is done and what is left

| Item | State |
|---|---|
| Music / sound names in code | **Done** — `game.json` `audio` map (code constants are the fallback) |
| Title, default campaign, pack list in `main.gd` | **Done** — `default_campaign` / `packs`; `--packs-root` swaps the whole packs folder (incl. `_ops`) |
| Font | **Done** — `theme.font` |
| World-flavoured UI wording in framework tables | **Done** — moved to `packs/_game/texts` (§3.1) |
| Template pack | **Done** — `kit/starter` (packlint 0 FAIL, simulation 100% coverage) |
| Home-screen illustration | **Done** — `theme.home_art` (image path; hotspots keep working); without it the procedural Ashenport scene is drawn |
| Theme palette tokens | **Done** — `theme.palette` (`bg`, `panel`, `sheet`, `accent`, `accent_soft`, `text`, `muted`, `success`, `danger`, `ink`; hex) feeds the UI theme and the shared sheets; colours not yet tokenised remain in screen code |
| Battle win-rate tool for any pack | **Done** — `tools/winrate.gd -- <games> <seed> <pack dir> [class]`, expected level per act from manifest `balance.act_level`; with a class id, every battle is rerun with that build (±7 points of the default hero) |
| Full audio set | **Done** — five BGM states (camp / explore / **map** / battle / ending; `map.travel` and `site.enter` switch to map) and SFX for coin, door, card, link, throw on top of the first set; all procedural (`gen_audio.py`), replaceable by file (tech/08) |
| Starter-kit art | **Done** — home illustration (`theme.home_art`) and unit art for the kit's enemies |
| Generated art / music | Prompt pack for external AI tools: tech/08 |

## 6. Guardrails

- **Engine changes need a framework reason**: if a new game needs a mechanic, it is added as a general framework feature with a spec (like docs 15–17), never as a story-specific branch in code;
- **Backward compatibility**: new framework versions keep old packs loading (whitepaper §10.1);
- **Trademarks**: "D&D-style" describes the mechanics internally; player-facing and store text never uses third-party trademarks or setting names.
