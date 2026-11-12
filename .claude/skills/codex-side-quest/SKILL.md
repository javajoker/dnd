---
name: codex-side-quest
description: Recipe for adding a side quest (arc pack grafted into a campaign node) on the Age of the Codex framework — host and entry point, graft block, reuse of host data, flags and return path, registration, balance and acceptance
whenToUse: Someone wants a new side quest, side arc, optional episode, faction errand or companion story inside an existing campaign
type: prompt
---

# Side quest recipe

Run every command from the repository root with `G=/Applications/Godot.app/Contents/MacOS/Godot` set (one shell call: `G=… ; $G --headless --path game -s tools/… -- …`).

- **Fresh checkout or worktree:** run `$G --headless --path game --import` once first. Without it every tool fails with `Identifier "PackLoader" not declared` (the global class cache is missing).
- **Shell:** one plain command per call, no `cd … &&` chains or heredocs mixed with `cd` (sandboxes reject them). Write files with the Write tool.
- **Paths:** pack dirs are relative to `game/` (`packs/<id>`, `user://story_trial/<id>`); story scripts can be given from the repo root (`docs/en/story/…`) or from `game/` (`kit/stories/…`).

References: `docs/en/tech/02-content-pack-format-spec.md` §2.6 (graft), `docs/en/story/05-side-arc-the-crane-ledger.md` + `.story.md` (worked example made with this recipe), `docs/en/story/04-side-arc-echoes-of-fog-wharf.md`, `docs/en/tech/11-content-pipeline-and-agents.md` §3.3.

**Host data at a glance:** `$G --headless --path game -s tools/pack_catalog.gd -- packs/<host>` lists reusable ids with English names and stats (characters, enemies, items, classes, backgrounds, lore, rep / bond keys), hubs, the default party, act levels and the **Doom Clock budget** left for a side quest. campaign01's JSON names are Chinese; use this instead of reading raw JSON.

1. **Entry point:** host campaign + node (usually a hub such as campaign01 `N1-1`), entry label, entry condition (`requires`: not done yet, a flag, an item, a reputation, a class / background for personal quests).
2. **Arc book** (`docs/en/story/<nn>-side-arc-<id>.md`): premise, 4–10 nodes, payoff (lore, reputation, items, XP), how the host reacts afterwards (flags the host may read).
3. **Script** from `game/kit/stories/side_quest.story.md`: `pack_type: arc`, `graft` (`into`, `node`, `label`, `to`, `requires`), `default_party` = host party; last node writes `done` and returns to the host node.
4. **Reuse host data** (characters, enemies, items, lore series) — the merged view resolves them; add new data only when the quest needs it (own `enemies.json` / `items.json` in the arc pack).
5. **Import** (`tools/story_import.gd`) — packlint lints the arc grafted onto its host (V14 namespace independence, V5 combined clock bound).
6. **Register:** add the id to `packs/_game/game.json` `packs`.
7. **Balance** with `balance_tune` (automatically on the merged view), then acceptance (tech/11 §6).

Facts a cold start needs:
- **Graft edge:** any edge type works. Use `choice` for "always offered until done" (`requires: {"flag.done": false}`), and `item` (`"item": "<id>"`) for "offered only while carrying X". Other conditions (`rep.*`, `bond.*`, `background`, `hero_class`) go in `requires`. Use the short form in the script's front matter: `graft: {"into", "node", "label", "to", "requires"}` (add `"item": "<id>"` for an item gate).
- **Party:** battles use the encounter's `party` list (the script's `default_party`). campaign01's default party is `player_blank`, `companion_kelan` and `companion_laofei`, so companion quests can assume both companions are present.
- **Factions / companions:** use the `rep.*` / `bond.*` keys `pack_catalog` lists (campaign01: `rep.scriptorium`, `rep.uninked`, `rep.salvage`; `bond.kelan`, `bond.laofei`). A new faction is a world-book decision, not a typo fix.
- **Item roles:** one or more of `stat` (usable or equippable), `check_mod`, `branch_key` (opens a path), `codex` (keepsake or lore token) — packlint V12.
- **Source locale `en`** is fine for new packs (arc_crane is one). Write English in the script; `zh-CN` comes from `text_extract`.

Lessons from arc_crane:
- **Doom Clock budget:** campaign01 already spends 9 of 10 segments (packlint V5 sums them). A side quest gets at most one +1 cost, so route every failed check through one costed node.
- **Locales:** the shipped game is `en` + `zh-CN`. Set `locales: ["en", "zh-CN"]` and write `texts/zh-CN.json` from `tools/text_extract.gd -- packs/<id> zh-CN <out.json>`, reusing the host's terms (老费, 誊写庭, 黑羽…). V15 fails until it's complete.
- **Quest log:** hand-write `events.json` (trigger at the host node with the graft label, `node` = the last node, `settle`). The importer keeps it.
- **New items:** put them in the arc's own `items.json` before importing (V11).
- Add a `test_<pack>` in `tests/run.gd` (grafted lint, band lock, grafted simulation coverage).

## Reading tool output (messages are in Chinese — decide by these markers and the exit code)

| Tool | Marker | Meaning |
|---|---|---|
| all | exit code `0` | success; `1` = load / script error; `2` = check failed |
| story_import | `[ERROR] 第 N 行：…` / `== 导入失败 … 未写任何文件 ==` | script error on line N; **nothing was written** |
| story_import | `== 导入完成：packlint X FAIL / Y WARN ==` | imported; X must be 0 |
| story_import | `[WARN] 节点 … 指向本包外节点 N1-1` | a side quest returning to its host — expected, ignore |
| packlint | `[FAIL] Vn：…` / `[WARN]` / `[PASS]` / `[N/A ]` | rule Vn failed / warning / passed / not applicable |
| packlint | `V4 旗标 X 无图层条件读取` | flag X is written but never read: read it in an `[if …]`, or drop the `write` |
| packlint | `V5 … 正向时钟效果代数和 +N 超过上限 10` | too many `clock +` effects (host + quest); keep the quest within the budget `pack_catalog` prints |
| packlint | `V11 … 引用未登记道具 / 敌人 'x'` | id x doesn't exist: fix the spelling, or add it to the pack's `items.json` / `enemies.json` |
| packlint | `V15 声明语言 zh-CN 但缺 …` | missing `texts/zh-CN.json` or keys — fill from `text_extract` |
| balance_tune | `（在区间内，不动）` | in band, unchanged |
| balance_tune | `{"hp":5} 71.3% ✓` | suggested `enemy_mods` and the confirmed rate: OK |
| balance_tune | `✗ 仍越界（需改阵容 / 敌人条目）` | knobs can't fix it: **change the line-up** (enemy count / types), re-import, re-tune |
| balance_tune | `== 建议 N 处（加 --write 写回）==` / `== 已写回 … ==` / `== 全部在区间内 ==` | N suggestions (re-run with `--write`) / written / all in band |
| simulate | `== 仿真断言全绿 ==` / `== 仿真失败：N ==` | all assertions green / N failures |
| simulate | `未覆盖：ID` / `覆盖 a/b 节点（x%）` / `卡在节点 ID` | node never reached / coverage (≥ 95 % needed) / bot stuck (no usable exit) |
| tests/run.gd | `== 全部通过 ==` / `FAIL …` | whole suite green / a failed check (grep the log for `FAIL `) |
