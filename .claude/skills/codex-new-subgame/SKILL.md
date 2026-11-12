---
name: codex-new-subgame
description: Recipe for adding a sub-game (gauntlet, puzzle maze, challenge run) to a game on the Age of the Codex framework — standalone pack data, subgame manifest block, registration, entitlement, balance and acceptance
whenToUse: Someone wants a new mini-mode, arena, gauntlet, puzzle sequence or replayable challenge inside an existing game
type: prompt
---

# New sub-game recipe

**Any model, any effort:** the steps and checks are the same. Follow them in order and decide by each tool's verdict line, not by your own confidence. Smaller models: follow literally and copy the worked example. Larger models: spend the extra on prose, choices and translation, not on new mechanics.

Run every command from the repository root with `G=/Applications/Godot.app/Contents/MacOS/Godot` set (one shell call: `G=… ; $G --headless --path game -s tools/… -- …`).

- **Fresh checkout or worktree:** run `$G --headless --path game --import` once first. Without it every tool fails with `Identifier "PackLoader" not declared` (the global class cache is missing).
- **Shell:** one plain command per call, no `cd … &&` chains or heredocs mixed with `cd` (sandboxes reject them). Write files with the Write tool.
- **Paths:** pack dirs are relative to `game/` (`packs/<id>`, `user://story_trial/<id>`); story scripts can be given from the repo root (`docs/en/story/…`) or from `game/` (`kit/stories/…`).

References: `docs/en/tech/02-content-pack-format-spec.md` §2.5, `docs/en/subgames/` (arena, riddle-maze), whitepaper §10.2, `docs/en/tech/11-content-pipeline-and-agents.md` §3.2.

1. **Concept** (1 page, `docs/en/subgames/<id>/01-concept.md`): the loop, length (3–8 nodes), win / loss, rewards (`gold_reward` per tier, XP), replay hook (`stat_keys` wins / best), entry rule (free or entitlement).
2. **Standalone data:** a sub-game pack carries its own `characters.json` / `enemies.json` / `skills.json` / `items.json` (copy the campaign's and adjust, or design new — `codex-content-design`).
3. **Story script** from `game/kit/stories/subgame.story.md`: `pack_type: subgame`, `subgame` block (`rules_override` such as `arena_mode` / `puzzle_mode`, `gold_reward`, `stat_keys`, `clear_as_win` for puzzles), `recommended_level`, `balance.act_level`, `monetization`.
4. **Puzzle rooms:** `maze` encounters with beats (check / loot / ambush, `retry_on_fail` + `hint`) written in `encounters.json` (tech/02 §6); reference them from `explore` nodes (`> raw: {"encounter": "RM-1"}`).
5. **Register:** add the id to `packs/_game/game.json` `packs`; gated sub-games add `entitlement.requires` and an entry in `packs/_ops/entitlements.json` (packlint V9) plus a store product if sold.
6. **Balance:** gauntlets escalate easy → medium → hard; `balance_tune` each battle; HP persists across the run unless the design restores it.
7. **Acceptance** (tech/11 §6) + the sub-game rule: entering and leaving always pass through settlement (no lost rewards).

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
| balance_tune | `（在区间内，不动） in band  Lv1` | in band, unchanged (Lv = simulated party level) |
| balance_tune | `{"hp":5} 71.3% ✓` | suggested `enemy_mods` and the confirmed rate: OK |
| balance_tune | `✗ 仍越界（需改阵容）/ out of band: change the line-up — too easy / too hard …` | the HP knob (capped at ±40 % of the weakest enemy's HP) can't fix it: **change the line-up** in the direction given, re-import, re-tune |
| balance_tune | `✗ enemy_mods.hp +N 超过上限 ±M` | a stored HP buff is too big: change the line-up and remove the `mods` |
| balance_tune | `== 建议 N 处（加 --write 写回）==` / `== 已写回 … ==` / `== 全部在区间内 ==` | N suggestions (re-run with `--write`) / written / all in band |
| simulate | `== 仿真断言全绿 ==` / `== 仿真失败：N ==` | all assertions green / N failures |
| simulate | `未覆盖：ID` / `覆盖 a/b 节点（x%）` / `卡在节点 ID` | node never reached / coverage (≥ 95 % needed) / bot stuck (no usable exit) |
| tests/run.gd | the `RESULT:` line (`… \| grep RESULT`): `== 全部通过 == RESULT: PASS n / FAIL 0` / `== 失败：N == RESULT: …` | whole suite green / N failed checks (failed ones print as `ERROR:   FAIL …`; engine `RID … leaked` lines after it are noise) |
