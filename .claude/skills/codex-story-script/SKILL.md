---
name: codex-story-script
description: Write and import story scripts (.story.md) for the Age of the Codex framework — the plain-text format for nodes, choices, checks, battles, effects, conditions, endings and lore, the story_import tool, and the procedure for adapting an existing story into branching playable content
whenToUse: Writing or editing a campaign, side quest or sub-game story; converting prose, an outline or a tabletop module into game content; any task that produces or changes nodes.json through a story script
type: prompt
---

# Story script skill

**Any model, any effort:** the steps and checks are the same. Follow them in order and decide by each tool's verdict line, not by your own confidence. Smaller models: follow literally and copy the worked example. Larger models: spend the extra on prose, choices and translation, not on new mechanics.

Run every command from the repository root with `G=/Applications/Godot.app/Contents/MacOS/Godot` set (one shell call: `G=… ; $G --headless --path game -s tools/… -- …`).

- **Fresh checkout or worktree:** run `$G --headless --path game --import` once first. Without it every tool fails with `Identifier "PackLoader" not declared` (the global class cache is missing).
- **Shell:** one plain command per call, no `cd … &&` chains or heredocs mixed with `cd` (sandboxes reject them). Write files with the Write tool.
- **Paths:** pack dirs are relative to `game/` (`packs/<id>`, `user://story_trial/<id>`); story scripts can be given from the repo root (`docs/en/story/…`) or from `game/` (`kit/stories/…`).

Spec: `docs/en/tech/10-story-script-format.md`. Templates: `game/kit/stories/{side_quest,campaign,subgame}.story.md`. Tool: `game/tools/story_import.gd`.

**Host data at a glance:** `$G --headless --path game -s tools/pack_catalog.gd -- packs/<host>` lists reusable ids with English names and stats (characters, enemies, items, classes, backgrounds, lore, rep / bond keys), hubs, the default party, act levels and the **Doom Clock budget** left for a side quest. campaign01's JSON names are Chinese; use this instead of reading raw JSON.

## Workflow

1. Copy the matching template; set the front matter (`pack_id`, `pack_type`, `name`, `source_locale`, `default_party`; `graft` for a side quest; `subgame` for a sub-game; `start` / `balance` / `recommended_level` for a campaign).
2. Write acts (`# ACT <id>: <title> | role: …`) and nodes (`## <id> <type>: <title>` + text + `>` directives + `-` edges).
3. Trial import, fix, then import for real:
   ```bash
   G=/Applications/Godot.app/Contents/MacOS/Godot
   $G --headless --path game -s tools/story_import.gd -- path/to/<id>.story.md --out user://story_trial/<id>
   $G --headless --path game -s tools/story_import.gd -- path/to/<id>.story.md
   $G --headless --path game -s tools/simulate.gd -- 12 packs/<id>
   ```
4. Keep the `.story.md` next to the book in `docs/en/story/` or in the pack folder — it is the source of truth for the structure; re-import after every edit (tuned `enemy_mods` survive).

## Cheat sheet

```
## L-1 scene: Title
Text…
> on_enter: xp 40, gold +10, clock +1, inspiration +1, rep.salvage +1, bond.laofei +5, alignment -5,
            give heal_potion x2, take ink_core, lore lantern_keeper, write met_keeper, reveal fog_coast.marsh
> encounter: medium | enemies ink_fiend, ink_imp x2 | party player_blank, companion_kelan | xp 60 | gold 12 | loot ink_core | mods hp+2
> ending: default | hidden | if rep.salvage >= 2
> raw: {"text_variants": [...]}
- choice "Label" -> L-2 [if flag.met_keeper, not flag.done] [do gold +5]
- check perception medium "Label" -> L-3 | fail L-4 [do xp 10] [fail_do clock +1]
- item half_tide_table "Label" -> L-5
- raw {"type": "doom_clock", "at": 3, "to": "L-9", "once": true}
## LORE lantern_keeper ashenport_local: Title
Body…
```

Conditions: `flag.X`, `not flag.X`, `item.X`, `rep.F >= N`, `bond.C >= N`, `clock >= N`, `hero_class = X`, `background = X`, `lead = X` (comma = and).
Skills for checks: athletics, intimidate, stealth, thievery, perception, investigation, history, persuasion, soothe (doc 11 §2). Difficulties: easy / medium / hard (DC 8 / 12 / 16).

## Canon

Companion and NPC backstory: the world book's canon sheets (`docs/en/story/01-world-*.md` §8.2). Don't contradict *locked* items. When you fill an *open* one, record it there in the same change.

## Structure rules (packlint will fail otherwise)

- Every non-ending node has an exit; every check has a failure target (V1 / V3).
- Every node reachable from the start (V2); ids unique; side-quest exits may point to host nodes.
- Every flag read is written somewhere (V4 ledger — the importer builds it; a write nobody reads is a WARN).
- Doom Clock costs stay bounded (V5); node count within `node_budget` (V6).
- Enemies / items / skills referenced must exist (V11) — list missing ones for the world designer.

## Importing an existing story

1. Beat list: one line per decision or location; mark fights, tests, discoveries, endings.
2. Map: description → scene, test → check (+ failure branch), fight → battle, safe place → hub/rest, end → ending.
3. Cast & props → existing ids or a hand-off list (name, role, one line).
4. Consequences → flags / reputation / items so later scenes can react (`[if …]`).
5. Keep the author's voice, trim exposition, make every choice matter. No third-party trademarks in player-facing text.

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
| tests/run.gd | last line `== 全部通过 == RESULT: PASS n / FAIL 0` / `== 失败：N == RESULT: …` | whole suite green / N failed checks (failed ones print as `ERROR:   FAIL …`) |
