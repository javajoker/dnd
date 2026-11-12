---
name: codex-side-quest
description: Recipe for adding a side quest (arc pack grafted into a campaign node) on the Age of the Codex framework — host and entry point, graft block, reuse of host data, flags and return path, registration, balance and acceptance
whenToUse: Someone wants a new side quest, side arc, optional episode, faction errand or companion story inside an existing campaign
type: prompt
---

# Side quest recipe

References: `docs/en/tech/02-content-pack-format-spec.md` §2.6 (graft), `docs/en/story/04-side-arc-echoes-of-fog-wharf.md` (worked example), `docs/en/tech/11-content-pipeline-and-agents.md` §3.3.

1. **Entry point:** host campaign + node (usually a hub such as campaign01 `N1-1`), entry label, entry condition (`requires`: not done yet, a flag, an item, a reputation, a class / background for personal quests).
2. **Arc book** (`docs/en/story/<nn>-side-arc-<id>.md`): premise, 4–10 nodes, payoff (lore, reputation, items, XP), how the host reacts afterwards (flags the host may read).
3. **Script** from `game/kit/stories/side_quest.story.md`: `pack_type: arc`, `graft` (`into`, `node`, `label`, `to`, `requires`), `default_party` = host party; last node writes `done` and returns to the host node.
4. **Reuse host data** (characters, enemies, items, lore series) — the merged view resolves them; add new data only when the quest needs it (own `enemies.json` / `items.json` in the arc pack).
5. **Import** (`tools/story_import.gd`) — packlint lints the arc grafted onto its host (V14 namespace independence, V5 combined clock bound).
6. **Register:** add the id to `packs/_game/game.json` `packs`.
7. **Balance** with `balance_tune` (automatically on the merged view), then acceptance (tech/11 §6).
