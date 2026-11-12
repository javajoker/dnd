---
name: codex-content-design
description: Design worldview and game data for the Age of the Codex framework — factions, places, lore series, classes and backgrounds, characters and companions, skills, items, props and gear, enemies and bosses, maps and event tables — with the JSON schemas and the Light rule pack's number ranges
whenToUse: Creating or extending a world; adding classes, backgrounds, companions, skills, items, equipment, enemies, bosses, maps or event tables; filling data references a story script needs
type: prompt
---

# Content design skill

**Any model, any effort:** the steps and checks are the same. Follow them in order and decide by each tool's verdict line, not by your own confidence. Smaller models: follow literally and copy the worked example. Larger models: spend the extra on prose, choices and translation, not on new mechanics.

Run every command from the repository root with `G=/Applications/Godot.app/Contents/MacOS/Godot` set (one shell call: `G=… ; $G --headless --path game -s tools/… -- …`).

- **Fresh checkout or worktree:** run `$G --headless --path game --import` once first. Without it every tool fails with `Identifier "PackLoader" not declared` (the global class cache is missing).
- **Shell:** one plain command per call, no `cd … &&` chains or heredocs mixed with `cd` (sandboxes reject them). Write files with the Write tool.
- **Paths:** pack dirs are relative to `game/` (`packs/<id>`, `user://story_trial/<id>`); story scripts can be given from the repo root (`docs/en/story/…`) or from `game/` (`kit/stories/…`).

References: `docs/en/framework/11-light-rulepack-v1.md` (numbers), `docs/en/tech/04-resources-and-effects-system.md` (schemas), `docs/en/tech/02-content-pack-format-spec.md` (pack files), `docs/en/story/03-balance-and-boss-design.md` §4 (enemy anchors), `docs/en/framework/16-map-and-exploration-spec.md` (maps / tables), `docs/en/tech/05-art-pipeline.md` (art ids, `fx`).

**Host data at a glance:** `$G --headless --path game -s tools/pack_catalog.gd -- packs/<host>` lists reusable ids with English names and stats (characters, enemies, items, classes, backgrounds, lore, rep / bond keys), hubs, the default party, act levels and the **Doom Clock budget** left for a side quest. campaign01's JSON names are Chinese; use this instead of reading raw JSON.

## Worldview → mechanics

| Fiction | Mechanic |
|---|---|
| Factions | `rep.<faction>` (−5…+5); options gated `[if rep.X >= 2]`; endings conditioned on standing |
| Companions | characters `kind: companion`; `bond.<id>`; a signature skill + a support skill |
| The threat | Doom Clock: time-costing choices (`clock +1`) and `doom_clock` edges |
| Legends | lore series (`lore.json` `series`), unlocked by `lore <id>` effects |
| Places | nodes / hubs; exploration → `maps.json` regions & sites |
| Moral axis | `alignment` ±N and endings on it |

## Numbers (Light rule pack)

- Attributes might / finesse / wits, −1…+3; creation +2 / +1 / 0; DC 8 / 12 / 16; item check modifiers ≤ ±4.
- Player HP formula ~ `8–10 + attribute`; AC `10 + finesse` (+ gear); Hit Die d6 (fragile) – d10 (tough).
- Skills: damage d4 (light) / d6 (one-handed, spells) / d8 (heavy); `uses_per_encounter` 1–3 (null = at will for basic attacks); heal 1d6+1 … 1d8+1.
- Enemies (story/03 §4): minion 8–10 HP · AC 10 · +2 · 1d4; soldier 12–14 HP · AC 11–12 · +3 · 1d6; elite 15–16 HP · AC 11–13 · +3 · 1d6+2; boss 35–40 HP · AC 13 · +5 · 1d6+2 + AoE (`save` DC 12–13, half) + phase skill.
- Growth XP 300 / 700 / 1200; encounter XP ≈ 40 (easy) / 60–80 (medium) / 100–150 (hard); gold ≈ XP ÷ 5.

## Schemas (examples)

```json
// characters.json
{"id": "hero", "name": "The Hero", "kind": "player_template", "attrs": {"might": 2, "finesse": 1, "wits": 0},
 "hit_die": "d10", "hp_formula": "10 + 2*might", "ac_formula": "10 + finesse",
 "proficiencies": ["athletics", "perception"], "basic_attack": "strike", "skills": ["power_strike"], "art_ref": "portraits/hero"}
// skills.json
{"id": "strike", "name": "Strike", "kind": "attack", "attr": "might", "damage": "1d6+2", "uses_per_encounter": null,
 "target": "enemy_single", "gesture": "tap", "fx": "slash"}
{"id": "mend", "name": "Mend", "kind": "utility", "heal": "1d8+1", "uses_per_encounter": 2, "target": "ally_single", "fx": "heal"}
// items.json
{"id": "potion", "name": "Healing Potion", "roles": ["stat"], "source": "Inn shop", "price": 10,
 "use": {"timing": "bonus_action", "heal": "1d4+2", "consume": true}}
{"id": "longsword", "name": "Longsword", "roles": ["stat"], "price": 30, "equip": {"slot": "weapon", "damage_die": "1d8"}}
// enemies.json (boss)
{"id": "warden", "name": "The Warden", "art_ref": "units/warden", "hp": 38, "ac": 13, "attack_mod": 5, "damage": "1d6+2",
 "attrs": {"might": 2, "finesse": 1, "wits": 1}, "attack_fx": "smash", "boss": true,
 "skills": [{"id": "seal_shock", "name": "Seal Shock", "kind": "aoe", "fx": "burst", "damage": "1d6+2",
             "save": {"attr": "finesse", "dc": 12, "on_success": "half"}},
            {"id": "rewrite", "name": "Rewrite the Rules", "kind": "buff", "fx": "aura", "effect": {"attack_mod": 1}}],
 "behavior": [{"every_n_rounds": 2, "skill": "seal_shock"}, {"when_hp_below": 0.5, "once": true, "skill": "rewrite"}]}
// classes.json → {"classes": [...], "backgrounds": [...]}
{"id": "scavenger", "name": "Scavenger", "art_ref": "portraits/class_scavenger", "desc": "…", "story": "…",
 "attrs": {"might": 0, "finesse": 2, "wits": 1}, "hp_formula": "8 + finesse", "ac_formula": "10 + finesse", "hit_die": "d8",
 "proficiencies": ["stealth", "thievery", "perception"], "basic_attack": "hook_knife",
 "skills": ["sneak_strike", "smoke_step", "inklance"], "start_items": [{"item": "tide_bomb", "n": 1}], "start_equip": []}
{"id": "dockhand", "name": "Dockhand", "proficiency": "athletics", "keepsake": "dock_tally", "story": "…",
 "effects": [{"gold": 10}, {"give_item": "heal_potion"}]}
```

Gear slots: weapon / armor / shield / trinket (doc 11 §8.1). Item identities: stat, check_mod, branch_key, codex. `fx` values: slash stab claw smash bolt lance arc burst wave heal shield smoke summon aura.

## Design heuristics

- One sentence of fantasy per class / enemy / item before any number.
- Each class has a different best attribute and a different answer to "how do I win this fight?" (front-line, opportunist, caster / healer).
- Companions fill the party's gaps; their second skill is support (heal / guard).
- Enemy roster per act: 2–3 minion types, 1–2 soldiers, 1 boss; mix melee with an area threat.
- Props tell the world: keepsakes, keys that open branches (`branch_key` + `unlocks`), lore tokens (`codex`).
- New art: add `art_ref` ids and prompts (tech/08); missing art falls back silently.

## Validate

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tools/packlint.gd -- packs/<id>
```
V11 (references), V12 (keys), V13 (uses / consume), V22 (fx names) must pass. Then hand new enemies to the balancer.
