---
name: codex-side-quest
description: Recipe for adding a side quest (arc pack grafted into a campaign node) on the Age of the Codex framework — host and entry point, graft block, reuse of host data, flags and return path, registration, balance and acceptance
whenToUse: Someone wants a new side quest, side arc, optional episode, faction errand or companion story inside an existing campaign
type: prompt
---

# Side quest recipe

**Any model, any effort:** the steps and checks are the same. Follow them in order and decide by each tool's verdict line, not by your own confidence. Smaller models: follow literally and copy the worked example. Larger models: spend the extra on prose, choices and translation, not on new mechanics.

Follow the steps in order. Each one ends in a check you can run. The worked example is *The Crane Ledger*: `docs/en/story/05-side-arc-the-crane-ledger.md`, its `.story.md` script and `game/packs/arc_crane/`.

## 0. Setup

- Run every command from the repository root, with `G=/Applications/Godot.app/Contents/MacOS/Godot` in the same shell call: `G=/Applications/Godot.app/Contents/MacOS/Godot; $G --headless --path game -s tools/<tool>.gd -- <args>`.
- **Fresh checkout or worktree:** run `$G --headless --path game --import` once. Without it every tool fails with `Identifier "PackLoader" not declared`.
- **Shell:** use one plain command per call, with no `cd … &&` chains and no heredocs mixed with `cd`. Write files with the Write tool.
- **Paths:** pack dirs are relative to `game/` (`packs/<id>`, `user://story_trial/<id>`). Story scripts can be given from the repo root (`docs/en/story/…`).
- **Flags:** write flags and values literally (`--seed 7`), never through a shell variable or loop (zsh passes `"--seed 7"` as one word). The tuner rejects unknown arguments and class ids.
- **Editing JSON** such as `game.json`: use the Edit tool, not `sed -i` (BSD sed on macOS needs `-i ''`).

## 1. Learn the host

```bash
$G --headless --path game -s tools/pack_catalog.gd -- packs/campaign01
```

This prints everything you can reuse, with English names:
- characters, with their proficiencies and skills
- enemies, with stats
- items, classes, backgrounds and lore
- the `rep.*` / `bond.*` keys
- hubs, and the quests already grafted on each hub (keep your entry label different from theirs)
- the default party and the expected level per act
- the valid check skills
- the **Doom Clock budget** (campaign01: **+1**)

campaign01's JSON names are Chinese, so use this output rather than reading the raw JSON.

Companion backstory lives in `docs/en/story/01-world-age-of-the-codex.md` §8.2, the canon sheets:
- Never contradict a *locked* item there.
- If your quest fills an *open* item, add one line to that sheet in the same change, naming your quest id.
- If it fills none, write "Canon: no change" in the arc book. Inventing a new NPC (a broker, a clerk) needs no sheet.

## 2. Decide the entry

- **Host node:** usually the hub (campaign01 `N1-1`, "Free City Plaza", act SL-1, party level 1).
- **Entry kind:**
  - `choice`: always offered until done (`requires: {"flag.done": false}`).
  - `item`: offered only while carrying an item (`"item": "<id>"`).
  - Extra conditions go in `requires`: `rep.X`, `bond.X`, `background`, `hero_class`. Take ids from the `pack_catalog` output (classes: `harbor_guard`, `scavenger`, `ink_adept`; backgrounds: `dockhand`, `scriptorium_novice`, `uninked_runaway`, `salvager_apprentice`). In edges use `[if background = dockhand]`.
- **Reachability:** the entry must be visible when the player first stands at the node. campaign01's N1-1 comes at the very start, with every `rep` at 0, so a `rep.X >= 1` gate makes the quest unreachable, and simulate will report 0 % coverage. Item-gated entries are fine: the simulator starts holding the item.
- **Party:** battles use the script's `default_party`. In campaign01 that's `player_blank`, `companion_kelan` and `companion_laofei`, so both companions are always present.

## 3. Write the arc book

Create `docs/en/story/<nn>-side-arc-<slug>.md`, where `nn` is the next free number in `docs/en/story/`. Cover:
- the premise, in one line
- the graft block
- a node table (6–10 nodes)
- the payoff: XP, gold, `rep` / `bond` / alignment, an item, a lore entry
- what the host can read afterwards (an item id or a flag)

Give the choice real teeth: each option should reward a different faction or companion (world book §6). Use the arc_crane book as the template.

## 4. Write the script

Copy `game/kit/stories/side_quest.story.md` to `docs/en/story/<nn>-side-arc-<slug>.story.md`. The full format is in the `codex-story-script` skill and tech/10.

**Front matter:**
- `pack_id: arc_<name>`
- `pack_type: arc`
- `source_locale: en`
- `locales: ["en", "zh-CN"]`
- `monetization: {"strategies": ["free"]}`
- `source_doc: docs/en/story/<nn>-…md`, the book path (the acceptance test finds the script from it)
- `graft: {"into": "campaign01", "node": "N1-1", "label": "…", "to": "<first node>", "requires": {"flag.done": false}}`; add `"item": "<id>"` for an item gate
- `default_party: [...]`

**Rules that packlint enforces:**
- **Doom Clock:** at most one `clock +1` in the whole quest. Send every failed check to one costed scene, e.g. `- check athletics medium "…" -> X-3 | fail X-2f`, with `X-2f` holding `> on_enter: clock +1`. A `clock -1` is allowed, but it doesn't buy back budget.
- **Checks:** use only these skills: athletics, intimidate, stealth, thievery, perception, investigation, history, persuasion, soothe. Give each check a failure target that moves the story on.
- **Ending:** the last node writes `done` and returns to the host (`- choice "Return to the plaza" -> N1-1`).
- **Flags:** every flag you `write` must be read somewhere (`[if flag.X]`). Otherwise V4 warns; drop the write, or use an item as the host-facing marker.
- **Node budget:** V6 counts *logical* nodes. Suffixed nodes (`X-2f`, `X-5a`) and endings don't count, so its number is lower than your node count.

**Battles** (`> encounter: <difficulty> | enemies … | xp … | gold … | loot …`): start from a line-up that is already in band at the same level, then tune it in step 7.

| Difficulty, level 1 | Known in-band line-up | xp / gold |
|---|---|---|
| easy | `ink_imp x3, ink_swarm` (or `mercenary x2 \| mods hp+4`) | 40 / 8 |
| medium | `ink_fiend, ink_imp x2 \| mods hp+4`, or `ink_swarm, dock_ambusher x2, ink_imp \| mods hp-1` | 60 / 12 |
| hard (level 2) | `mercenary x3` | 100–150 / 20–30 |

## 5. Add new data, before importing

- **New items** go in `game/packs/<id>/items.json`. Copy the shape from `arc_crane/items.json`, and keep the item weaker than the shop's equivalent. `roles` takes one or more of `stat`, `check_mod`, `branch_key`, `codex`.
- **Quest-log entry:** write `game/packs/<id>/events.json` (copy `arc_crane/events.json`). Its trigger `label` must equal the graft label, `node` is your last node, and `settle` is `[{"xp": 20}]`.
- Reuse host enemies. A new enemy is world-designer work (`codex-content-design`).

## 6. Import, translate and register

```bash
$G --headless --path game -s tools/story_import.gd -- docs/en/story/<nn>-side-arc-<slug>.story.md
```

The first import reports **1 FAIL: V15**, because `texts/zh-CN.json` doesn't exist yet. That's expected. Anything else must be fixed in the script before you continue (see the marker table below).

```bash
$G --headless --path game -s tools/text_extract.gd -- packs/<id> zh-CN <scratch dir>/<id>_zh.json
```

Use any writable temporary folder (your scratchpad if you have one). The output file lists every key **with its English text as the value**. It includes `items.*` and `events.*` keys, which is why step 5 writes those files first. Translate every value into Chinese and save the result as `game/packs/<id>/texts/zh-CN.json`. Don't copy English across: an English value counts as present but ships English to Chinese players.
- **Host terms:** 老费 (Old Fei), 珂兰 (Kelan), 白页者 (the Unwritten), 誊写庭 (Scriptorium), 黑羽 (the Uninked, Black Feather), 拾遗行会 (Salvage Guild), 自由市广场 (Free City Plaza), 褪色 (the Fading), 墨魈 (Ink Fiend), 墨魈幼体 (Ink Imp), 墨魈群 (Ink Swarm).
- **Key forms:** `nodes.<id>.title|summary|edges.N.label`, `node.<id>.text` (long text), `lore.<id>` and `lore.<id>.title`, `items.<id>.name`, `events.<id>.*`, `manifest.*`.

Register the pack: add `"<id>"` to `"packs"` in `game/packs/_game/game.json`. packlint doesn't check registration; the test suite does.

```bash
$G --headless --path game -s tools/packlint.gd -- packs/<id>
```

This must end `== packlint 完成：0 FAIL / 0 WARN ==`.

## 7. Balance

```bash
$G --headless --path game -s tools/balance_tune.gd -- packs/<id> --games 600
```

This works for side quests: it tunes on the host's merged view. Bands for the default party: easy 85–95 %, medium 70–80 %, hard 50–65 %.
- **`✓` suggestion:** re-run with `--write`.
- **`✗ … change the line-up`:** the HP knob is capped at ±40 % of the weakest enemy's HP. Edit the script's `enemies …` (the message says whether to add or remove), re-import, then re-tune.
- **Confirm:** re-run with `--seed 7`.
- **Classes:** run once each with `--class harbor_guard`, `--class scavenger` and `--class ink_adept`. Each must be within ±7 points of the default run.

## 8. Accept

```bash
$G --headless --path game -s tools/simulate.gd -- 24 packs/<id>
$G --headless --path game -s tests/run.gd
```

- **simulate:** runs the quest injected into its host and must end `== 仿真断言全绿 ==` with 100 % coverage of your nodes.
- **Test suite:** takes about 3 minutes. Run it **once**, with a 600-second timeout (or in the background), and read only the **last line**: `== 全部通过 == RESULT: PASS n / FAIL 0`. Don't count `FAIL` with grep, because some check names contain the word. It must end `== 全部通过 ==`. You don't write test code: `test_arc_packs` automatically checks every side quest in `game.json`:
  - grafted lint
  - the script matches the pack
  - battle bands and the HP cap
  - grafted simulation coverage
- **Wrap up:**
  - Record the final rates in the arc book.
  - Add a README row under `docs/en/README.md` §story.
  - Commit on the current branch (`feat(content): …`). Never push.

## Reading tool output (messages are in Chinese — decide by these markers and the exit code)

| Tool | Marker | Meaning |
|---|---|---|
| all | exit code `0` | success; `1` = load / script error; `2` = check failed |
| story_import | `[ERROR] 第 N 行：…` / `== 导入失败 … 未写任何文件 ==` | script error on line N; **nothing was written** |
| story_import | `== 导入完成：packlint X FAIL / Y WARN ==` | imported; X must be 0 (only V15 is expected, before translation) |
| story_import | `[WARN] 节点 … 指向本包外节点 N1-1` | a side quest returning to its host — expected, ignore |
| packlint | `[FAIL] Vn：…` / `[WARN]` / `[PASS]` / `[N/A ]` | rule Vn failed / warning / passed / not applicable |
| packlint | `V4 旗标 X 无图层条件读取` | flag X is written but never read: read it in an `[if …]`, or drop the `write` |
| packlint | `V5 … 正向时钟效果代数和 +N 超过上限 10` | too many `clock +` effects (host + quest): use one costed failure scene |
| packlint | `V11 … 引用未登记道具 / 敌人 'x'` | id x doesn't exist: fix the spelling, or add it to the pack's `items.json` / `enemies.json` |
| packlint | `V15 声明语言 zh-CN 但缺 …` | missing `texts/zh-CN.json` or keys — step 6 |
| balance_tune | `（在区间内，不动） in band  Lv1` | in band, unchanged (Lv = simulated party level) |
| balance_tune | `{"hp":3} 74.3% ✓` | suggested `enemy_mods` and the confirmed rate: write it with `--write` |
| balance_tune | `✗ 仍越界（需改阵容）/ out of band: change the line-up — too easy / too hard …` | the HP knob can't fix it: change the enemies in the script |
| balance_tune | `✗ enemy_mods.hp +N 超过上限 ±M` | a stored HP buff is too big: change the line-up and remove the `mods` |
| balance_tune | `== 建议 N 处（加 --write 写回）==` / `== 已写回 … ==` / `== 全部在区间内 ==` | N suggestions / written / all in band |
| simulate | `== 仿真断言全绿 ==` / `== 仿真失败：N ==` | all assertions green / N failures |
| simulate | `未覆盖：ID` / `覆盖 a/b 节点（x%）` / `卡在节点 ID` | node never reached / coverage / bot stuck (no usable exit) |
| tests/run.gd | last line `== 全部通过 == RESULT: PASS n / FAIL 0` / `== 失败：N == RESULT: …` | whole suite green / N failed checks (failed ones print as `ERROR:   FAIL …`) |
