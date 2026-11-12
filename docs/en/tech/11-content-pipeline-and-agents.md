# tech/11 · Content Pipeline and Agent Set — new games, sub-games, side quests

> Status: **implemented** (2026-11-12). Agents in `.claude/agents/`, skills in `.claude/skills/`. Tools: `game/tools/story_import.gd` (tech/10), `game/tools/balance_tune.gd`, `game/tools/pack_catalog.gd` (a pack's reusable ids, English names, stats and Doom Clock budget), `winrate.gd`, `simulate.gd`, `packlint.gd`, `text_extract.gd`, `gen_art.py` / `gen_audio.py`. Related: tech/07 (new-game kit), tech/02 / tech/04 (data formats), docs 11 / 15 / 16 (rules, party split, maps), story/03 (balance bands), tech/08 (asset prompts).

The framework already separates **engine** from **content** (tech/07). This document defines how content is produced: who does what, in which order, with which tools, and what "done" means. The same pipeline serves three products:

| Product | Pack type | Lives | Reaches the player |
|---|---|---|---|
| **New game** | a whole `_game` + one or more `campaign` packs | its own packs root (start from `game/kit/`) | `--packs-root`, or replaces `packs/` |
| **Sub-game** | `subgame` (standalone gauntlet / puzzle / challenge) | `game/packs/<id>/` | auto-discovered; listed in `packs/_game/game.json` `packs`; settlement on entry and exit |
| **Side quest** | `arc` grafted into a campaign node | `game/packs/<id>/` | one injected option at the host node (tech/02 §2.6) |

## 1. Roles (agents)

| Agent | Owns | Never does |
|---|---|---|
| **codex-producer** | the brief → plan → hand-offs → acceptance; runs the definition of done (§6) | invents lore or numbers itself |
| **codex-story-writer** | world & campaign books (`docs/en/story/`), story scripts (`*.story.md`), importing existing stories, all prose | edits stats or engine code |
| **codex-world-designer** | worldview structure (factions, places, series), characters, classes & backgrounds, items / props, skills, enemies, maps & event tables — as pack data | writes plot beats or tunes win rates by feel |
| **codex-balancer** | win rates, encounter line-ups and `enemy_mods`, XP / gold curve, class parity, check difficulty mix | changes the rule pack or story structure |
| **godot-developer-en** (existing) | engine / framework changes when content needs a new mechanic (tech/07 §6) | content |

Each agent loads its skills at the start: producer → `codex-new-game` / `codex-new-subgame` / `codex-side-quest`; story writer → `codex-story-script`; world designer → `codex-content-design`; balancer → `codex-balance`.

## 2. Pipeline

```
brief ──► 1 design intent (story writer + world designer, docs/en/story/<book>.md)
      ──► 2 data skeleton (world designer: characters / enemies / items / skills / classes)
      ──► 3 story script (story writer: <id>.story.md) ──► story_import ──► packlint
      ──► 4 balance (balancer: balance_tune / winrate / simulate)
      ──► 5 text & assets (translations via text_extract; art / audio via tech/08 prompts)
      ──► 6 acceptance (producer: §6) ──► commit
```

Steps 2 and 3 iterate: the importer lists missing references (enemies, items) that the world designer then adds. Step 4 only adjusts encounter-level knobs, so the writer can keep re-importing without losing tuning (the importer preserves `enemy_mods`).

## 3. Product recipes

### 3.1 New game

1. Copy `game/kit/_game` and `game/kit/starter` to a new packs root (or run the kit as-is with `--packs-root=res://kit` first).
2. Edit the **game manifest** (`_game/game.json`): id, title, `default_campaign`, `packs`, `theme` (palette, fonts, home art + hotspots, UI frames dir), `audio`, `balance` (tech/07 §3).
3. Story writer writes the **world book** (`docs/en/story/01-world-<id>.md`: concept, factions, places, threat clock, lore series) and the **campaign book** (acts, hub, branches, endings).
4. World designer authors classes, backgrounds, characters, enemies, items, skills (§4).
5. Story writer writes `<campaign>.story.md` (template `game/kit/stories/campaign.story.md`) → import.
6. Balancer tunes; producer accepts (§6).

### 3.2 Sub-game

1. Brief = a loop (gauntlet, puzzle maze, escort run…) that reuses `EncounterSM`; settlement on entry and exit (whitepaper §10.2).
2. A sub-game is **standalone**: its own `characters` / `enemies` / `skills` / `items` (copy from a campaign or design new).
3. Script from `game/kit/stories/subgame.story.md`; front matter `subgame` block (`rules_override`, `gold_reward`, `stat_keys`, `clear_as_win`), optional `entitlement` + `monetization`.
4. Add the pack id to `packs/_game/game.json` `packs`; if it has an entitlement, register it in `packs/_ops/entitlements.json` (packlint V9).
5. Puzzle rooms (`maze` encounters with beats) are written in `encounters.json` directly (tech/02 §6) — reference them from `explore` nodes via `> raw: {"encounter": "<id>"}`.

### 3.3 Side quest

1. Pick the host campaign and node (usually a hub); decide the entry condition (`requires`, e.g. not done yet, a flag, an item).
2. Script from `game/kit/stories/side_quest.story.md`: `pack_type: arc`, `graft`, last node returns to the host node and writes `done`.
3. Reuse the host's characters / enemies / items (the merged view resolves them); add new ones only if the brief needs them.
4. Add the pack id to `packs/_game/game.json` `packs`. packlint lints it grafted onto the host (V14 namespace independence, V5 combined clock bound).

## 4. Design data (world designer)

| What | File | Key rules |
|---|---|---|
| Worldview | `docs/en/story/01-world-*.md` | factions → `rep.<faction>` keys (−5…+5); places → nodes / maps; lore series → `lore.json` `series`; threat → Doom Clock budget |
| Classes & backgrounds | `classes.json` (doc 11 §1.1) | attributes −1…+3 (assign +2/+1/0 for creation); Hit Die d6–d10; 3 class skills; start items; backgrounds: one proficiency, a keepsake, start effects, a story hook |
| Characters | `characters.json` (tech/04 §2) | `kind` player_template / companion; `hp_formula` / `ac_formula` in attribute terms; `basic_attack`; companions carry a signature skill + one support skill |
| Skills | `skills.json` (tech/04 §3) | `kind` attack / utility; damage dice d4–d8 (+mod); `uses_per_encounter` 1–3; `heal` for healing; `fx` for animation (tech/05 §9) |
| Items | `items.json` (tech/02 §7) | roles stat / check_mod (≤ ±4) / branch_key / codex; `use` (heal / damage / consume); `equip` slot + AC/damage for gear; `price` for shops |
| Enemies | `enemies.json` (tech/04 §1) | anchor on story/03 §4: minion 8–10 HP, AC 10, +2, 1d4; soldier 12–14 HP, AC 11–12, +3, 1d6; boss 35–40 HP, AC 13, +5, 1d6+2 with an AoE (`save`) and a phase skill; `attack_fx` |
| Maps & tables | `maps.json`, `tables.json` (doc 16) | locations with `pos` matching the map art; d4–d100 tables covering every face once (V20) |

Checks: easy DC 8 / medium 12 / hard 16; mix per act per doc 11 §9. Growth: XP 300 / 700 / 1200 for levels 2 / 3 / 4; a campaign ends inside level 3 (story/03 §5); battle gold ≈ XP ÷ 5.

## 5. Balance (balancer)

1. Every battle encounter has a difficulty: easy 85–95 %, medium 70–80 %, hard 50–65 % win rate for the expected party level (manifest `balance.act_level`).
2. Measure and tune automatically:
   ```bash
   godot --headless --path game -s tools/balance_tune.gd -- packs/<id> --games 600
   godot --headless --path game -s tools/balance_tune.gd -- packs/<id> --games 600 --write
   ```
   The tuner binary-searches an `enemy_mods.hp` (then `attack_mod`) that brings each out-of-band battle to its band centre, re-checks with a second seed and reports battles that can't be fixed by knobs ("change the line-up").
3. Class parity: `tools/winrate.gd -- <games> <seed> <pack dir> <class>` for each class — within ±7 points of the default hero.
4. Whole-run sanity: `tools/simulate.gd -- 24 <pack dir>` — every run reaches an ending, the Doom Clock stays in range, ≥ 95 % node coverage. A side quest is injected into its host and run from the host start (the bot takes the injected option when it appears); coverage counts the quest's own nodes.
5. Noise: 200 games ≈ ±3 points; decide with ≥ 600 games and two seeds.

## 6. Definition of done (producer)

Cold-start rule: the skills must be enough on their own. A fresh agent on a smaller model (Sonnet, low effort), given only a brief, must be able to finish this list. Re-test after changing the skills or tools (§7).


- [ ] `packlint` 0 FAIL (side quests grafted onto their host)
- [ ] `balance_tune` reports every battle in band; classes within tolerance
- [ ] `simulate` green (endings reached, coverage ≥ 95 %)
- [ ] Headless test suite green (`tests/run.gd`)
- [ ] Texts complete for every shipped locale (`text_extract`, V15)
- [ ] Pack listed in the game manifest; entitlement registered if gated
- [ ] Docs: the story / world book in `docs/en/story/`, any new mechanic specified before code (tech/07 §6)
- [ ] Player-facing text uses no third-party trademarks or setting names

## 7. Cold-start verification log

| Date | Model / effort | Brief | Result | Fixes made from it |
|---|---|---|---|---|
| 2026-11-12 | Sonnet / low | Kelan companion side quest, 6–8 nodes | Invalid run: its worktree was cut from `main`, without the pipeline commits. Even so it hand-wrote a valid arc (packlint 0 FAIL, tests green) | First-run `--import` step; shell and path rules; graft edge types, party, faction keys and item roles written into the side-quest skill; importer resolves repo-root paths and item-gated short grafts; `pack_catalog.gd`; output-marker glossary; per-class balance via `balance_tune --class` |
