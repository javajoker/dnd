# Resources and Effects System Specification

> Version: v0.1.2 (discussion draft)
> Related docs: `01-technical-approach.md` §6, `02-content-pack-format-spec.md`, `../framework/11-light-rulepack-v1.md`
> Scope: the **data format and stacking model** for four kinds of numeric resources — characters, skills, items and effects (modifiers). Goal: "adding a resource = adding a data row; balancing = changing data values", with zero framework changes.
> English mirror of `docs/tech/04-资源与效果系统.md` (change history omitted). Terms follow `../GLOSSARY.md`.
> **Implementation status**: §1–§4, §6–§8 are implemented. §5 (the effect-modifier pipeline) is **not implemented** — no pack ships an effects.json yet.

---

## 1. Resource overview

| Resource | File | Owner | Examples |
|---|---|---|---|
| Character definitions | `characters.json` | Content pack | Player template, companions, NPCs |
| Skill definitions | `skills.json` | Content pack (a rule pack may provide a base set) | Sword Slash, Ink Bolt |
| Item definitions | `items.json` (doc 02 §7) | Content pack | Ink Core, Supply Potion |
| Effects (modifiers) | `effects.json` | Content pack | Ink Core tempering, escort blessing, poison |
| Enemy definitions | `enemies.json` | Content pack | Ink Fiend, Page Warden |

Design constraints (from doc 02): fixed file names; a new resource = a new data row; the sets of legal values (attribute names, check difficulty tiers, effect operators) are registered by the **rule pack**, and the validator checks against the bound rule pack.

## 2. characters.json

```json
{
  "id": "companion_kelan",
  "name": "Kelan",
  "kind": "companion",
  "attrs": { "might": 0, "finesse": 2, "wits": 1 },
  "hp_formula": "10 + 2*level + might",
  "ac_formula": "10 + finesse",
  "proficiencies": ["history", "soothe"],
  "skills": ["ink_dart", "scribe_shield"],
  "bond": { "initial": 20, "personal_quest": "kelan_q1" }
}
```

- Formulas are **string expressions** (whitelisted variables: attrs / level / proficiency) evaluated by the rule pack — changing the rule pack doesn't change the character table;
- The player template `kind: "player_template"` provides creation defaults (the +2/+1/0 of doc 11 §1);
- Optional `basic_attack`: the basic-attack skill id (must be registered in this pack's skills.json, V11); the bootstrap derives the basic attack modifier (= the value of that skill's `attr`) and damage die (= that skill's `damage`) from it;
- Optional `hit_die` (doc 11 §7.2): the Hit Die size (`"d6"` / `"d8"` / `"d10"`…, default d8); a short rest spends Hit Dice to heal die roll + Might modifier;
- Optional `art_ref` (tech/05 §6): portrait reference (`"portraits/<id>"`); a pure presentation reference passed through BattleDef into the unit dictionary and party_status; shells fall back silently when art is missing.

enemies.json entries may also have `art_ref` (tech/05 §6): enemy unit art reference (`"units/<id>"`); passed through BattleDef (including inline summon templates); both shells' battlefield tokens show the image.

## 3. skills.json

```json
{
  "id": "inkbolt",
  "name": "Ink Bolt",
  "kind": "attack",
  "attr": "wits",
  "damage": "1d6",
  "uses_per_encounter": 2,
  "target": "enemy_single",
  "gesture": "path",
  "effects_on_hit": ["ink_burn_1"]
}
```

| Field | Description |
|---|---|
| kind | `attack` / `check` / `heal` / `utility` — decides whether it resolves through the check formula or as heal/utility |
| uses_per_encounter | use limit (Light rules), restored at rest; `null` = unlimited |
| gesture | suggested gesture (`tap`/`path`), a presentation hint only; doesn't affect validity |
| effects_on_hit | effect IDs attached on hit (§5) |
| save | optional, saving-throw declaration for area effects (doc 11 §5.1): `{ "attr": "finesse", "dc": 11, "on_success": "half" }` |
| adv / dis | optional, declares that the skill itself is a source of advantage/disadvantage (doc 11 §3.1) |

## 4. Making items usable (items.json extension)

On top of the four identities in doc 02 §7, items get an optional `use` block:

```json
{ "id": "heal_potion", "name": "Supply Potion", "roles": ["stat"],
  "use": { "timing": "bonus_action", "target": "ally_single", "heal": "1d4+2", "consume": true } }
```

- `timing`: `action` / `bonus_action` / `out_of_combat` — aligned with the action economy (doc 09);
- `consume: true` removes it from `global.inv` after use (Board write + event stream, same as every other rule);
- `target`: `ally` (default) / `enemy`; `enemy` + `damage` (dice) = a thrown item that makes an attack roll d20+Finesse vs AC (11 §8.2);
- In-combat action economy: a `bonus_action` item in the quick pouch = bonus action; a pack item or an `action` item = action (11 §8.2);
- The runtime uses **flat keys** (the effect sits directly under `use`, as above). A nested `"effect": { … }` form will be unified once the §5 effect runtime lands.

### 4.1 Equipment (the items.json `equip` block)

```json
{ "id": "boathook_axe", "name": "Boathook Axe", "roles": ["stat"], "price": 40,
  "equip": { "slot": "weapon", "damage_die": "1d8" } }
```

| Key | Meaning |
|---|---|
| slot | Required: `weapon` / `armor` / `shield` / `trinket` (11 §8.1) |
| ac | Optional AC bonus |
| attack | Optional to-hit bonus |
| damage_die | Optional, weapon only: replaces the basic attack's damage die (keeps the modifier) |
| max_hp | Optional max-HP bonus |
| users | Optional list of character ids allowed to wear it (references checked by V11) |

- Equipment state is written to `<ns>.equip.<char_id>.<slot>` (a bookkeeping key, never read out); an item can be worn by at most as many characters as copies owned;
- packlint V12 checks slot / key set / dice expressions; V11 checks `users` references.

## 5. Effect system (modifier stacking model) — not implemented yet

### 5.1 Effect definitions (effects.json)

```json
{
  "id": "ink_core_weapon",
  "name": "Ink Core Tempering",
  "target_attr": "attack_damage",
  "op": "add",
  "value": 1,
  "duration": "campaign",
  "stack": "refresh"
}
```

| Field | Legal values | Meaning |
|---|---|---|
| target_attr | modifiable attributes registered by the rule pack (attack_damage / ac / hp_max / check_mod.<skill> / …) | What it modifies |
| op | `add` / `mul` / `override` / `clamp_max` / `clamp_min` | How it modifies |
| duration | `encounter` / `rest` / `campaign` / `permanent` | When it expires |
| stack | `refresh` (same source refreshes) / `stack` (stacks, needs `max_stack`) / `unique` (unique per ID) | Stacking behavior |

### 5.2 Evaluation pipeline (fixed order, no exceptions)

```
final = clamp( override( mul( base + Σadd ) ) )
```

1. `base`: the base value from the rule-pack formula;
2. `add` bucket: sum of all add modifiers;
3. `mul` bucket: product of all mul modifiers;
4. `override`: the one **attached most recently** wins (an override is unique);
5. `clamp_*`: clamp last.

The evaluation order for any value is globally fixed — this is the effect-layer guarantee of "same event stream, zero difference between the two forms"; the rendering layer only reads final values.

### 5.3 Provenance and removal

- Every effect attach/expire/trigger goes into the event stream (`effect.attach` / `effect.expire`) with its source (item / skill / node) — the History Scroll can answer "where did this +1 come from";
- Effects only modify numbers and **may never write story flags directly** (flags are written through the effect vocabulary; the iron rule is unchanged).

### 5.4 Updates and balance changes

- Resource tables are versioned with the content pack; in-progress campaigns are frozen at their bound version (same strategy as rule packs);
- Balance changes (numbers / use counts / effect amounts) = data changes to resource tables only, validated through the content pipeline, **no framework change**;
- A new modifiable attribute = a rule-pack version upgrade (an extension point reserved in the data structure, doc 11 §1).

## 6. Validation extensions (merged into doc 02 §12)

| # | Check |
|---|---|
| V11 | Closed resource references: IDs referenced between skills / items / effects all exist; skills referenced by characters are registered |
| V12 | Legal effects: target_attr is registered in the bound rule pack; legal op / duration / stack values |
| V13 | Use-limited skills have uses ≥1; consumable items must not silently disappear outside encounters |

## 7. Relationship with Loadout

- The Loadout pools come straight from these resource tables: skill choices = skills the character has learned (characters.json `skills` ∩ skills.json); items to carry = inventory items with a `use` block;
- Slot limits are declared in the pack config (`02-content-pack-format-spec.md` §2.4); this system hard-codes none;
- Loadout only decides "what to bring in" and doesn't change the resources themselves (except attribute-point allocation — with `respec: true` reallocation is allowed and writes the `attr.respec` event).

## 8. Growth system (final)

Growth is a **framework-layer** capability (characters carry across campaigns, doc 05 §5), not private bookkeeping of one content pack:

| Key (doc 07 §2 whitelist) | Meaning | Writer |
|---|---|---|
| `global.growth.xp` | Cumulative experience | The `xp` effect (any pack: campaign / arc / **sub-game**) |
| `global.growth.level` | Level | The growth system, automatically, from the bound rule pack's threshold table |
| `global.growth.attr_points` | Unallocated attribute points | +N automatically on level-up; −1 on allocation |
| `global.growth.attrs.<attr>` | Allocated attributes | The allocation API (Settlement screen / Loadout screen, doc 09 §9.1) |

Rules:

1. **An xp effect flows straight in**: any `xp` effect from any pack writes `global.growth.xp` — which structurally resolves the question of where sub-game XP belongs;
2. **The threshold table belongs to the rule pack**: level thresholds (Light 300/700/1200, 11 §6) and per-level gains (HP +2, +1 attribute point, skill slot) are declared by the bound rule pack; cross-rule-pack conversion uses the attribute mapping table (05 §5);
3. **Attribute-point allocation**: on the Settlement or Loadout screen, each attribute capped at +3 (11 §6), writing an `attr.alloc` event;
4. Bookkeeping-key migration: old in-pack growth keys (e.g. `campaign01.xp_total`) are merged into `global.growth.*` by the save migration chain (07 §4.3). (Code-review note: that migrator hard-codes `campaign01.*` keys — M1.)
