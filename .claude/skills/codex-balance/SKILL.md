---
name: codex-balance
description: Balance content for the Age of the Codex framework — win-rate bands, the balance_tune auto-tuner, enemy_mods and line-ups, class parity, XP/gold curves, bot simulation, and how to report evidence
whenToUse: Tuning battles, checking a new pack before release, adding enemies / classes / skills, or when a fight feels too easy or too hard
type: prompt
---

# Balance skill

**Any model, any effort:** the steps and checks are the same. Follow them in order and decide by each tool's verdict line, not by your own confidence. Smaller models: follow literally and copy the worked example. Larger models: spend the extra on prose, choices and translation, not on new mechanics.

Run every command from the repository root with `G=/Applications/Godot.app/Contents/MacOS/Godot` set (one shell call: `G=… ; $G --headless --path game -s tools/… -- …`).

- **Fresh checkout or worktree:** run `$G --headless --path game --import` once first. Without it every tool fails with `Identifier "PackLoader" not declared` (the global class cache is missing).
- **Shell:** one plain command per call, no `cd … &&` chains or heredocs mixed with `cd` (sandboxes reject them). Write files with the Write tool.
- **Paths:** pack dirs are relative to `game/` (`packs/<id>`, `user://story_trial/<id>`); story scripts can be given from the repo root (`docs/en/story/…`) or from `game/` (`kit/stories/…`).

References: `docs/en/story/03-balance-and-boss-design.md` (bands, anchors, measured rates), `docs/en/framework/11-light-rulepack-v1.md` §6 / §9, `docs/en/tech/11-content-pipeline-and-agents.md` §5.

## Targets

| Difficulty | Win rate (default party, expected level) |
|---|---|
| easy | 85–95 % |
| medium | 70–80 % |
| hard | 50–65 % |

Expected level per act: manifest `balance.act_level` (e.g. `{"A1": 1, "A2": 2}`). Classes: within ±7 points of the default hero. XP: a full campaign ends inside level 3 (700–1199 XP). Battle gold ≈ XP ÷ 5.

## Tools

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path game -s tools/balance_tune.gd -- packs/<id> --games 600                # measure + suggest
$G --headless --path game -s tools/balance_tune.gd -- packs/<id> --games 600 --write        # write enemy_mods
$G --headless --path game -s tools/balance_tune.gd -- packs/<id> --games 600 --seed 7       # confirm, 2nd seed
$G --headless --path game -s tools/balance_tune.gd -- packs/<id> --only <encounter> --games 1000
$G --headless --path game -s tools/balance_tune.gd -- packs/<id> --games 600 --class <class_id>  # per class (ids: pack_catalog)
$G --headless --path game -s tools/winrate.gd -- 600 5 packs/<id> [class_id]                # campaigns only (no side-quest merge)
$G --headless --path game -s tools/simulate.gd -- 24 packs/<id>                             # whole runs (side quests: injected into the host)
```

Side quests are tuned on the merged view with their host automatically. Trial packs: `user://story_trial/<id>`.

## Knob order

1. `enemy_mods.hp` (all enemies of that encounter) — the tuner's first choice, **capped at ±40 % of the weakest enemy's HP** (rounded up: Ink Imp 8 → ±4). A bigger buff turns the enemy into a different monster, so the tuner refuses it and asks for a line-up change.
2. `enemy_mods.attack_mod` (±1–2) when HP alone can't reach the band.
3. Line-up (add / remove / swap enemies) when the tuner reports "still out of band".
4. Shared enemy stats — only with the world designer; re-run every pack using that enemy.
5. Never the rule pack.

## Starting line-ups known to be in band (default party)

| Difficulty, level | Line-up |
|---|---|
| easy, Lv1 | `ink_imp x3, ink_swarm` · `mercenary x2` + hp+4 |
| medium, Lv1 | `ink_fiend, ink_imp x2` + hp+4 · `ink_swarm, dock_ambusher x2, ink_imp` + hp−1 |
| medium, Lv2 | `uninked_guard x3` + hp+1 |
| hard, Lv2 | `mercenary x3` |
| medium, Lv3 | `ink_fiend, ink_swarm x2` + hp+2 |
| hard, Lv3 | `page_warden` (boss) · `tide_avatar, ink_imp x2` |

These were measured with the default hero, 600 games, seed 20261109; each class lands within ±7 points. A new battle that starts above 95 % or below 40 % has the wrong line-up. Start from this table instead of tuning HP.

`tests/run.gd` `test_arc_packs` locks every side quest's battles to their bands (200 games, ±3) and enforces the HP cap, so a drifted battle fails the suite.

## Reporting

A table per pack: encounter, difficulty, band, rate before, change, rate after (two seeds, ≥ 600 games). Note noise (200 games ≈ ±3 points). Record final rates in the pack's book (and story/03 for campaign01).

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
