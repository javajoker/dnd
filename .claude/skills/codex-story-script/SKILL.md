---
name: codex-story-script
description: Write and import story scripts (.story.md) for the Age of the Codex framework — the plain-text format for nodes, choices, checks, battles, effects, conditions, endings and lore, the story_import tool, and the procedure for adapting an existing story into branching playable content
whenToUse: Writing or editing a campaign, side quest or sub-game story; converting prose, an outline or a tabletop module into game content; any task that produces or changes nodes.json through a story script
type: prompt
---

# Story script skill

Spec: `docs/en/tech/10-story-script-format.md`. Templates: `game/kit/stories/{side_quest,campaign,subgame}.story.md`. Tool: `game/tools/story_import.gd`.

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
