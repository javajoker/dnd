# tech/10 · Story Script Format and Importer

> Status: **implemented** (2026-11-12). Tool: `game/tools/story_import.gd`. Templates: `game/kit/stories/` (side quest, campaign, sub-game). Related: tech/02 (pack format — the importer's output), tech/11 (the content pipeline and agents that use it).

**Why:** content packs are JSON graphs; writing them by hand is slow and error-prone, and an imported story (a novel chapter, a tabletop module, a designer's outline) has no structure at all. The **story script** is a plain-text format a writer — human or AI — can produce directly; the importer turns it into pack data deterministically and runs packlint. Creative work stays in the script; structure, ids, flag ledgers and validation are the tool's job.

## 1. Command

```bash
godot --headless --path game -s tools/story_import.gd -- <file.story.md> [--out <pack dir>] [--dry-run]
```

- Default output `game/packs/<pack_id>/`; `--out user://story_trial/<id>` for a trial import outside the shipping packs; `--dry-run` parses and prints without writing.
- **Writes / owns:** `nodes.json`, `flags.json`, `endings.json`, `lore.json`, battle entries of `encounters.json`, long text in `texts/<source_locale>.json`; **merges** the front matter into `manifest.json`.
- **Keeps:** tuned encounter fields (`enemy_mods`, `pos`, `note`, `party_advantage`, `enemy_weaken`) and non-battle encounters already in the file — re-importing never undoes the balancer's work.
- **Never touches** design data: `characters`, `enemies`, `items`, `skills`, `classes`, `maps`, `tables` (empty files are created if missing).
- After writing it loads the pack and runs **packlint** (side quests are linted grafted onto their host); exit code 0 = no FAIL, 2 = FAIL found, 1 = script errors (nothing written).

## 2. Format

UTF-8 Markdown-like text, one statement per line.

### 2.1 Front matter

```
---
pack_id: arc_lantern
pack_type: arc                 # campaign | arc | subgame
name: The Lantern Vigil
source_locale: en
graft: {"into": "campaign01", "node": "N1-1", "label": "Answer the lantern-keeper's call", "to": "L-1", "requires": {"flag.done": false}}
default_party: ["player_blank", "companion_kelan", "companion_laofei"]
---
```

`key: value`; a value that looks like JSON (`{…}`, `[…]`, numbers, `true`/`false`, quoted strings) is parsed as JSON. Every key except `default_party` goes into `manifest.json` (tech/02 §2): `recommended_level`, `start`, `balance`, `subgame`, `monetization`, `entitlement`, `presentation`, `estimated_hours`, … Defaults: `namespace` = `pack_id`, `source_locale` = `en`, `rule_pack` light v1, `node_budget` = nodes + 4. A side quest's short `graft` form (`label` / `to` / `requires`) is expanded to the standard `{into, node, edge}` block; a sub-game without a `subgame` block gets a default one.

### 2.2 Acts and nodes

```
# ACT LANTERN: The Lantern Vigil | role: Side arc | mode: choice

## L-1 scene: A Light on the Water
Narrative text. Blank line = new paragraph.
```

- Node header `## <id> <type>: <title>`; types: `scene hub check battle dialog explore rest branch ending map site` (tech/02 §3).
- Text up to 140 characters becomes the node `summary`; longer text goes to `texts/<locale>.json` as `node.<id>.text` with `text_ref`, and the summary is its first sentence.
- `<!-- … -->` comments (one or several lines) are ignored.

### 2.3 Directives (`> name: value`)

| Directive | Meaning | Example |
|---|---|---|
| `on_enter` | effects when the node is entered | `> on_enter: xp 40, rep.salvage +1, lore lantern_keeper, write met_keeper` |
| `encounter` | the node's battle (`id` = node id) | `> encounter: medium \| enemies ink_fiend, ink_imp x2 \| xp 60 \| gold 12 \| loot ink_core` |
| `ending` | ending node: `default`, `hidden`, `if <conditions>` | `> ending: if rep.salvage >= 2` |
| `map` / `site` | map / site node target (doc 16) | `> map: fog_coast` |
| `raw` | any extra node fields as JSON | `> raw: {"text_variants": [...]}` |

Encounter fields: `enemies` (refs, `xN` repeats), `party` (character refs; default = front-matter `default_party`), `xp`, `gold`, `loot` (`item xN`), `max_units`, `mods` (`hp+2 atk-1` → `enemy_mods`). Difficulty first: `easy | medium | hard`.

### 2.4 Edges (`- …`)

```
- choice "Row out at once" -> L-2
- choice "Leave it be" -> L-END [if flag.met_keeper] [do gold +10]
- check perception medium "Read the light" -> L-2 | fail L-3 [do inspiration +1] [fail_do clock +1]
- item half_tide_table "Use the tide chart" -> L-5
- raw {"type": "doom_clock", "at": 2, "to": "L-9", "once": true}
```

`[if …]` = `requires`; `[do …]` = effects (on a check: success effects); `[fail_do …]` = check failure effects. Targets may point outside the pack only in a side quest (back to the host). Any edge type the shorthand doesn't cover (`reputation`, `split`, `remote`, `doom_clock`) goes through `raw`.

### 2.5 Effects and conditions

| Effect | JSON | Condition | JSON |
|---|---|---|---|
| `xp 40` | `{"xp": 40}` | `flag.done` / `not flag.done` | `{"flag.done": true/false}` |
| `gold +10` / `gold -5` | `{"gold": 10}` | `item.ink_core` | `{"item.ink_core": true}` |
| `clock +1` | `{"clock": 1}` | `rep.salvage >= 2` | `{"rep.salvage": {">=": 2}}` |
| `inspiration +1` | `{"inspiration": 1}` | `clock >= 3` | `{"clock": {">=": 3}}` |
| `alignment -5` | `{"alignment": -5}` | `bond.laofei >= 20` | `{"bond.laofei": {">=": 20}}` |
| `rep.salvage +1`, `bond.laofei +10`, `clock.local +1` | `{"rep.salvage": 1}` … | `hero_class = scavenger` | `{"hero_class": "scavenger"}` |
| `give heal_potion x2` / `take ink_core` | `{"give_item": …}` ×2 / `{"remove_item": …}` | `background = dockhand`, `lead = companion_kelan` | … |
| `lore lantern_keeper` | `{"lore": …}` | comparison ops | `>= <= > < == !=` |
| `write met_keeper` / `write tally = 3` | `{"write": …, "value": true/3}` | several, comma-separated | all must hold |
| `reveal fog_coast.marsh` | `{"reveal": …}` | | |

Flags written with `write` and read in `[if flag.X]` (or by the graft's `requires`) are collected into `flags.json` with their writer / reader nodes (packlint V4 ledger).

### 2.6 Compendium entries

```
## LORE lantern_keeper ashenport_local: The Lantern on the Water
Entry body (goes to texts as lore.<id>; lore.json gets a text_ref).
```

The optional second word is the series (tech/02 §10). Unlock it from a node with the effect `lore <id>`.

## 3. Importing an existing story

1. Read the source and list its **beats** (one decision or one location each), its **cast**, **places**, **objects**, **conflicts**;
2. Map beats to node types: travel / description → `scene`; a test of skill → `check`; a fight → `battle`; a town or camp → `hub`; an end → `ending`. Keep 8–40 nodes per arc; every non-ending node needs at least one exit, and every check a failure branch (packlint V1/V3);
3. Map the cast to existing characters / enemies, or hand new ones to the world designer (tech/11 §4);
4. Write the script, import with `--out user://story_trial/<id>`, fix packlint findings, then import into `game/packs/`.

The `codex-story-writer` agent with the `codex-story-script` skill follows exactly this procedure (tech/11).

## 4. Limits

- One script = one pack. Multi-act campaigns use several `# ACT` sections in the same file.
- Text variants, events (`events.json`), maps / tables and party splits are authored with `> raw` / `- raw` or directly in JSON; the importer leaves those files alone.
- The importer doesn't invent stats: enemies, items and skills referenced in the script must exist in the pack (or the host, for a side quest) — packlint reports any that don't.
