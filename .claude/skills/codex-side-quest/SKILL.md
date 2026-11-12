---
name: codex-side-quest
description: Recipe for adding a side quest (arc pack grafted into a campaign node) on the Age of the Codex framework — host and entry point, graft block, reuse of host data, flags and return path, registration, balance and acceptance
whenToUse: Someone wants a new side quest, side arc, optional episode, faction errand or companion story inside an existing campaign
type: prompt
---

# Side quest recipe

References: `docs/en/tech/02-content-pack-format-spec.md` §2.6 (graft), `docs/en/story/05-side-arc-the-crane-ledger.md` + `.story.md` (worked example made with this recipe), `docs/en/story/04-side-arc-echoes-of-fog-wharf.md`, `docs/en/tech/11-content-pipeline-and-agents.md` §3.3.

1. **Entry point:** host campaign + node (usually a hub such as campaign01 `N1-1`), entry label, entry condition (`requires`: not done yet, a flag, an item, a reputation, a class / background for personal quests).
2. **Arc book** (`docs/en/story/<nn>-side-arc-<id>.md`): premise, 4–10 nodes, payoff (lore, reputation, items, XP), how the host reacts afterwards (flags the host may read).
3. **Script** from `game/kit/stories/side_quest.story.md`: `pack_type: arc`, `graft` (`into`, `node`, `label`, `to`, `requires`), `default_party` = host party; last node writes `done` and returns to the host node.
4. **Reuse host data** (characters, enemies, items, lore series) — the merged view resolves them; add new data only when the quest needs it (own `enemies.json` / `items.json` in the arc pack).
5. **Import** (`tools/story_import.gd`) — packlint lints the arc grafted onto its host (V14 namespace independence, V5 combined clock bound).
6. **Register:** add the id to `packs/_game/game.json` `packs`.
7. **Balance** with `balance_tune` (automatically on the merged view), then acceptance (tech/11 §6).

Lessons from arc_crane:
- **Doom Clock budget:** campaign01 already spends 9 of 10 segments (packlint V5 sums them). A side quest gets at most one +1 cost, so route every failed check through one costed node.
- **Locales:** the shipped game is `en` + `zh-CN`. Set `locales: ["en", "zh-CN"]` and write `texts/zh-CN.json` from `tools/text_extract.gd -- packs/<id> zh-CN <out.json>`, reusing the host's terms (老费, 誊写庭, 黑羽…). V15 fails until it's complete.
- **Quest log:** hand-write `events.json` (trigger at the host node with the graft label, `node` = the last node, `settle`). The importer keeps it.
- **New items:** put them in the arc's own `items.json` before importing (V11).
- Add a `test_<pack>` in `tests/run.gd` (grafted lint, band lock, grafted simulation coverage).
