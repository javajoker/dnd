---
name: codex-new-game
description: Recipe for making a new game on the Age of the Codex framework — kit copy, game manifest, theme / audio / art, world and campaign books, design data, story script import, balance and acceptance
whenToUse: Someone wants a new game (new world, new campaign, new theme) built on this engine
type: prompt
---

# New game recipe

Run every command from the repository root with `G=/Applications/Godot.app/Contents/MacOS/Godot` set (one shell call: `G=… ; $G --headless --path game -s tools/… -- …`).

- **Fresh checkout or worktree:** run `$G --headless --path game --import` once first. Without it every tool fails with `Identifier "PackLoader" not declared` (the global class cache is missing).
- **Shell:** one plain command per call, no `cd … &&` chains or heredocs mixed with `cd` (sandboxes reject them). Write files with the Write tool.
- **Paths:** pack dirs are relative to `game/` (`packs/<id>`, `user://story_trial/<id>`); story scripts can be given from the repo root (`docs/en/story/…`) or from `game/` (`kit/stories/…`).

References: `docs/en/tech/07-new-game-kit.md`, `docs/en/tech/11-content-pipeline-and-agents.md` §3.1, `docs/en/tech/08-asset-prompts.md`.

1. **Kit:** copy `game/kit/_game` → `<root>/_game` and `game/kit/starter` → `<root>/<campaign_id>` (or start from `game/kit/stories/campaign.story.md`). Try it: `godot --path game -- --packs-root=res://kit`.
2. **Game manifest** `_game/game.json`: `id`, `title`, `default_campaign`, `packs`, `locales`, `theme` (`palette`, `font`, `title_font`, `home_art` + `home_hotspots` + `home_focus`, `ui_dir`), `audio` (bgm / sfx / ambient), `store`. UI flavour texts in `_game/texts/<locale>.json`.
3. **World book** (`docs/en/story/01-world-<id>.md`) — codex-story-writer + codex-world-designer: concept, factions (→ rep), places, threat (→ Doom Clock), lore series, classes & backgrounds fiction.
4. **Campaign book** (`docs/en/story/02-campaign-<id>.md`): acts, hub, branches, endings, flags.
5. **Design data** — codex-world-designer (`codex-content-design`): classes / backgrounds, characters, skills, items, enemies; maps & tables if the game explores.
6. **Story script** — codex-story-writer (`codex-story-script`): `<campaign_id>.story.md` → `tools/story_import.gd`; set manifest `start`, `balance.act_level`, `recommended_level`.
7. **Balance** — codex-balancer (`codex-balance`).
8. **Assets:** placeholders work (`gen_art.py`, `gen_audio.py`); final art / music via tech/08 prompts; art ids in data (`art_ref`, `fx`), audio names in the manifest.
9. **Acceptance** (tech/11 §6) with the new packs root: packlint, balance_tune, simulate, screenshots per locale (`--packs-root=… --home-shot`, `--phone-size=390x910 --auto-battle-shots`).
10. **Store:** listing / privacy per `docs/en/store/` patterns; build per `docs/en/tech/09-build-and-release-guide.md`.

Engine changes only with a spec (tech/07 §6). No third-party trademarks in player-facing text.

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
| balance_tune | `✗ 仍越界（需改阵容）/ out of band: change the line-up — too easy / too hard …` | the HP knob (capped at ±40 % of the weakest enemy's HP) can't fix it: **change the line-up** in the direction given, re-import, re-tune |
| balance_tune | `✗ enemy_mods.hp +N 超过上限 ±M` | a stored HP buff is too big: change the line-up and remove the `mods` |
| balance_tune | `== 建议 N 处（加 --write 写回）==` / `== 已写回 … ==` / `== 全部在区间内 ==` | N suggestions (re-run with `--write`) / written / all in band |
| simulate | `== 仿真断言全绿 ==` / `== 仿真失败：N ==` | all assertions green / N failures |
| simulate | `未覆盖：ID` / `覆盖 a/b 节点（x%）` / `卡在节点 ID` | node never reached / coverage (≥ 95 % needed) / bot stuck (no usable exit) |
| tests/run.gd | `== 全部通过 ==` / `FAIL …` | whole suite green / a failed check (grep the log for `FAIL `) |
