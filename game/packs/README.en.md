# game/packs — runtime content-pack copies

> English version of [`README.md`](README.md). Format contract: `docs/tech/02-内容包格式规范.md` §1 (English: `docs/en/tech/02-content-pack-format-spec.md`).

## Sync relationship

- **Authoring source**: `docs/story/<pack_id>/` (campaigns and arcs); sub-game sources are `docs/subgames/<name>/pack/`;
- **Runtime copy**: `game/packs/<pack_id>/` (the loader and simulation read only this directory);
- The two must be byte-identical: change the docs source first, then sync with `cp <source>/*.json game/packs/<pack_id>/`;
- Consistency is meant to be enforced by a CI / packlint pre-step (currently manual); for release, this directory is packaged as PCK files per tech/01 §8 (not implemented yet).
- `_ops/` is operations-side data (entitlement registry, cosmetics registry, ops_config) and is not a content pack.

## Current packs

| Pack | Source | Notes |
|---|---|---|
| campaign01 | `docs/story/campaign01/` | *Ashenport Fragments*, the first campaign |
| arc_tide | `docs/story/arc_tide/` | Side arc *Echoes of Fog Wharf* (pack_type=arc, grafted onto N1-1) |
| arena | `docs/subgames/arena/pack/` | Sub-game Arena Gauntlet (pack_type=subgame, DLC) |
| riddle_maze | `docs/subgames/riddle-maze/pack/` | Sub-game Riddle Maze (pack_type=subgame, free, zero combat) |
