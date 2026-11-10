# tech/07 · New-Game Kit — building another game on this framework

> Status: **design final; partly implemented** (gaps listed in §5, scheduled in TASKS P5). Related: whitepaper §1/§10/§14, tech/02 (pack format), tech/03 (authoring guide), tech/05 (art pipeline), docs 15–17.

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
| **Game manifest** | `game/packs/_game/game.json` (new, §3) | Title, default campaign, packs list, theme, audio map, store ids |
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
  "audio": { "bgm": { "home": "bgm_camp", "camp": "bgm_camp", "explore": "bgm_camp", "map": "bgm_camp",
                      "battle": "bgm_battle", "ending": "bgm_camp" },
             "sfx": { "dice_roll": "dice_roll", "dice_land": "dice_land", "hit": "hit", "crit": "crit", "heal": "heal" },
             "ambient": { "home": "amb_tide" } },
  "store": { "full_unlock": "entitlement.campaign01_full" }
}
```

The current game is the first instance of this manifest; today these values are spread across code constants (§5).

## 4. Recipe: a new game in ten steps

1. Copy `game/packs/_template/` (a minimal pack: one hub, one check, one battle, one ending, one region map) to `game/packs/<new_id>/`;
2. Write the **game manifest** (§3): title, packs, theme, audio map;
3. Write the **world and campaign book** in `docs/en/story/` (design intent first, as with *The Age of the Codex*);
4. Transcribe the book into pack data (tech/03), choosing the **form** per campaign: space → landscape, time → portrait, or `choice` (doc 09 §2; doc 15 §6 for side campaigns);
5. Add **characters, skills, items, gear** — reuse the rule pack; only numbers and names change;
6. Draw the **maps** and write the **event tables** (doc 16); decide the **progression** per playthrough (doc 15 §7);
7. Add **art** (`art_ref`) and **audio** (manifest `audio` map) — placeholders work until assets arrive;
8. Run `tools/packlint.gd` (V1–V21) and the bot simulation (`tools/simulate.gd`) until every ending is reachable and win rates sit in their bands;
9. Capture screenshots per locale/form (`--locale=…` shot flags) and play through on device;
10. Fill the store documents and choose the monetization strategy per market (doc 06) — content data stays identical across markets.

## 5. Gaps to close so the kit is real (TASKS P5)

| Gap today | Change |
|---|---|
| BGM/SFX names are code constants (`AudioManager.BGM_ASSETS`) | Read the game manifest `audio` map; keep code constants only as fallback |
| Title, default campaign and pack list are wired in `main.gd` | Read the game manifest |
| Palette/fonts are set in the theme resource and code | Theme tokens from the game manifest |
| No `_template` pack | Add a minimal template pack that passes packlint and the simulation |
| Story-specific names in shell code comments and a few UI strings | Move remaining story nouns into pack text (UI tables keep only framework words) |
| No region/site maps, tables, split, polyhedral dice | Docs 15–17 |

## 6. Guardrails

- **Engine changes need a framework reason**: if a new game needs a mechanic, it is added as a general framework feature with a spec (like docs 15–17), never as a story-specific branch in code;
- **Backward compatibility**: new framework versions keep old packs loading (whitepaper §10.1);
- **Trademarks**: "D&D-style" describes the mechanics internally; player-facing and store text never uses third-party trademarks or setting names.
