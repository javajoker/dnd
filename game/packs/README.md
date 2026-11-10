# game/packs — the game's packs

> Format contract: `docs/en/tech/02-content-pack-format-spec.md` §1. These folders are the only copy of the pack data (edit them directly; packlint and the tests read them).

## Layout

| Folder | What it is |
|---|---|
| `_game/` | **Game manifest** (`game.json`: default campaign, enabled packs, theme font, music / sound map) and this game's **UI flavour texts** (`texts/<locale>.json`, layered over the framework's neutral wording) — `docs/en/tech/07-new-game-kit.md` §3 |
| `_ops/` | Operations data (entitlement registry, cosmetics registry, ops_config) — not a content pack |
| `campaign01/` | *Ashenport Fragments*, the first campaign (incl. the Fog Coast map and the split-party demo) |
| `arc_tide/` | Side arc *Echoes of Fog Wharf* (pack_type=arc, grafted onto N1-1) |
| `arena/` | Sub-game Arena Gauntlet (pack_type=subgame, DLC) |
| `riddle_maze/` | Sub-game Riddle Maze (pack_type=subgame, free, zero combat) |

Folders starting with `_` are never loaded as content packs.

## Starting a different game

`game/kit/` holds a ready-to-copy starter: `kit/_game/` (manifest + flavour texts) and `kit/starter/` (a small English-source campaign with a hub, a check, battles, a region map, a site, a table and an event card). Run it as a whole separate game with `godot --path game -- --packs-root=res://kit`, or copy `kit/_game` and `kit/starter` into `packs/` to replace this game. Recipe: `docs/en/tech/07-new-game-kit.md` §4.
