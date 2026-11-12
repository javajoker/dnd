---
name: codex-new-subgame
description: Recipe for adding a sub-game (gauntlet, puzzle maze, challenge run) to a game on the Age of the Codex framework — standalone pack data, subgame manifest block, registration, entitlement, balance and acceptance
whenToUse: Someone wants a new mini-mode, arena, gauntlet, puzzle sequence or replayable challenge inside an existing game
type: prompt
---

# New sub-game recipe

References: `docs/en/tech/02-content-pack-format-spec.md` §2.5, `docs/en/subgames/` (arena, riddle-maze), whitepaper §10.2, `docs/en/tech/11-content-pipeline-and-agents.md` §3.2.

1. **Concept** (1 page, `docs/en/subgames/<id>/01-concept.md`): the loop, length (3–8 nodes), win / loss, rewards (`gold_reward` per tier, XP), replay hook (`stat_keys` wins / best), entry rule (free or entitlement).
2. **Standalone data:** a sub-game pack carries its own `characters.json` / `enemies.json` / `skills.json` / `items.json` (copy the campaign's and adjust, or design new — `codex-content-design`).
3. **Story script** from `game/kit/stories/subgame.story.md`: `pack_type: subgame`, `subgame` block (`rules_override` such as `arena_mode` / `puzzle_mode`, `gold_reward`, `stat_keys`, `clear_as_win` for puzzles), `recommended_level`, `balance.act_level`, `monetization`.
4. **Puzzle rooms:** `maze` encounters with beats (check / loot / ambush, `retry_on_fail` + `hint`) written in `encounters.json` (tech/02 §6); reference them from `explore` nodes (`> raw: {"encounter": "RM-1"}`).
5. **Register:** add the id to `packs/_game/game.json` `packs`; gated sub-games add `entitlement.requires` and an entry in `packs/_ops/entitlements.json` (packlint V9) plus a store product if sold.
6. **Balance:** gauntlets escalate easy → medium → hard; `balance_tune` each battle; HP persists across the run unless the design restores it.
7. **Acceptance** (tech/11 §6) + the sub-game rule: entering and leaving always pass through settlement (no lost rewards).
