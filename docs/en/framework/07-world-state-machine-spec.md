# World State Machine Specification

> Version: v1.0 (final, corresponds to P0.2)
> Related docs: `01-framework-whitepaper.md` §4, `../tech/01-technical-approach.md` §4, `../tech/02-content-pack-format-spec.md` §4.6
> Scope: complete field definitions for the six kinds of World State Board variables, namespace rules, save-snapshot rules and Doom Clock behavior. Binding on the framework and every content pack.
> English mirror of `docs/framework/07-世界状态机规范.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Overall Board structure

The Board is a single mutable store: `Map<NamespacedKey, TypedValue>`. The six kinds of variables are six **semantic tags** on the same key-value space; storage, read/write and snapshot paths are unified, and the tags are used for UI grouping and validator checks.

Every write must carry provenance: `provenance = { event_id, node_id, pack_id }` (the data source for the History Scroll's "flag trace", doc 04 screen ⑧).

## 2. Field definitions for the six kinds of variables

| Variable | Key format | Type | Range | Default | Main writers | Main readers |
|---|---|---|---|---|---|---|
| Story Flag | `<ns>.<flag_id>` | bool | true/false | false | Node `on_enter` / edge `effects` / event settlement | Edge conditions, presentation variations, History Scroll |
| Reputation | `global.rep.<faction>` | int | **-5 to +5** | 0 | Node/edge effects, event settlement | Reputation edges, shops, NPC attitudes |
| Doom Clock | `global.doom_clock` (Epic clock) / `<ns>.clock.<id>` (local clock) | int | **0 to 10** | 0 | Edge effect `clock`, event settlement | Time edges, ending fallback, status bar |
| Inventory | `global.inv` | Set<item_id> | IDs registered in item tables | {} | `give_item` / `remove_item` effects | Item edges, Inventory/Compendium, ending conditions |
| Bond | `global.bond.<npc_id>` | int | **0 to 100** | 0 | Dialogue options, event settlement | Ending conditions, personal quest lines, departure events |
| Alignment | `global.alignment` | int | **0 to 100** (0 = fully Blankward, 100 = fully Inkbound) | **50** (midline) | Key choice edges | Ending type (`ink_gt 50` / `blank_gt 50`) |
| Cosmetic flags | `global.cosmetic.dice_skin` (currently equipped) / `global.cosmetic.owned.<skin_id>` (owned set) | String / bool | skin_id registered in the registry / true | "" = default skin / false | Shop purchase, Compendium completion reward, cosmetics-page equip action (all via the core Cosmetics channel) | Rendering-shell skinning (pure presentation); **never enters numeric / event-stream resolution** (06 §3/§4) |

Constraints:

- Out-of-range values are clamped at write time, and a `clamped` event goes into the event stream (never silent);
- Elements of `global.inv` must be IDs registered in a loaded content pack's items.json — checked both by validator V7 and at runtime;
- Counter-type flags (e.g. fragment count) aren't stored as Flags; they're expressed as `item.<id>` quantity queries (see `02-content-pack-format-spec.md` §4.6);
- **Currency**: an in-pack counter variable `<ns>.gold` (the pack's own economy, written with provenance; re-review promoting it to global when cross-pack currency appears);
- **Party HP bookkeeping**: persists across encounters, under the in-pack key `<ns>.hp.<char_id>` (see `11-light-rulepack-v1.md` §7);
- **`global.lore`**: the set of unlocked Compendium entries (Set<lore_id>), written by the `lore` effect (doc 10 §3); `global.tutorial.*`: tutorial trigger records (doc 12 §4);
- **`global.growth.*`**: party growth bookkeeping (`xp` cumulative experience / `level` / `attr_points` unallocated attribute points / `attrs.<attr>` allocated attributes), with XP written by the `xp` effect; the threshold table is defined by the bound rule pack (doc 11 §6, tech/04 §8).

## 3. Namespace rules

| Prefix | Owner | Write permission | Read permission |
|---|---|---|---|
| `global.rep.*` / `global.alignment` / `global.bond.*` / `global.inv` / `global.doom_clock` / `global.lore` / `global.tutorial.*` / `global.mode_choice.*` / `global.growth.*` | Framework layer (global variable whitelist) | Any content pack (via the effect vocabulary); `global.mode_choice.<campaign_id>` is the Board key for the campaign-entry mode choice (doc 09 §3) | Any content pack |
| `global.entitlement.*` | Framework layer (entitlement variables) | **Only the shop / events / achievements systems** (doc 06 §5) | Content packs read-only |
| `global.cosmetic.*` | Framework layer (cosmetic flags, doc 06 §3) | **System only** (shop purchase / Compendium completion reward / cosmetics-page equip, all via the core Cosmetics channel; same write-permission philosophy as entitlement variables) | Content packs read-only |
| `<pack_id>.*` | Private to a content pack | **That pack only** | Any pack (by full key) |

Iron rules:

1. Flags declared inside a pack are automatically prefixed with the pack ID (`campaign01.seen_fading`); content authors don't write the prefix;
2. Cross-pack **writes** are forbidden; cross-pack **reads** are allowed but the target pack must be declared in flags.json `readers`, keeping dependencies traceable;
3. The semantics of global variables are defined by this spec; content packs may not redefine them (e.g. don't use `rep.scriptorium` as a counter).

## 4. Save-snapshot rules

### 4.1 Snapshot contents

```
Save = {
  save_version,            // snapshot format version (incrementing integer)
  board,                   // the full Board
  event_tail,              // event-stream tail sequence number (anchor for replay and tracing)
  bindings,                // binding-version table for each content pack / rule pack
  rng_seed,                // seeded RNG state
  meta                     // playthrough count, created/saved time, campaign progress summary
}
```

### 4.2 When snapshots are taken

| When | Notes |
|---|---|
| Encounter settlement complete | The main snapshot point: save as soon as one meta-loop "stroke" is down |
| Home screen idle | Fallback snapshot to avoid losing progress if the process is killed |
| Manual | An explicit "Record the Codex" entry on Home |
| Load on launch | On launch, read the latest snapshot back (migration chain → restore Board, RNG, story-graph progress); "Continue" on Home resumes from here |

**No saving mid-encounter** (quitting an encounter = replaying it), consistent with the "failure doesn't reload" philosophy: save points are the punctuation of world state, not an undo tool.

### 4.3 Compatibility strategy

- Snapshots carry `save_version` and are upgraded step by step through a migration chain on load; the framework keeps migrators for snapshots from **the last 2 major versions**;
- Content packs / rule packs of an in-progress campaign are frozen at their bound versions per `bindings` until it finishes (doc 05 §7); new versions apply only to new games;
- NG+ carry-over = when initialising a new snapshot, selectively copy from the old snapshot according to the carry-over list declared by the content pack (the copied items are themselves data).

## 5. Doom Clock behavior

1. **Range fixed at 0–10**: the Epic clock (Fading level) and local clocks are isomorphic; out-of-range values clamp;
2. **Time-edge triggering**: immediately after a clock write, run one trigger scan; `once` edges satisfying `at` / `>=` conditions fire (see `../tech/01-technical-approach.md` §7);
3. **Bidirectional**: content must include both accelerating (+) and delaying (−) means (validator V5 checks convergence); a pure countdown is not allowed;
4. **Full-clock semantics**: a full Epic clock = the fallback bad ending fires (e.g. E4); content packs must declare a full-clock exit;
5. **Presentation**: a persistent overview gauge in the status bar; tapping pops up a preview of approaching time edges (doc 04 §3.1) — the player can sense it but not reverse-engineer it precisely, preserving tension.

## 6. Relationship with the event stream

- The Board is "now"; the event stream is "how we got here": every change to the Board corresponds to at least one event (`flag.written` / `clock.tick` / `rep.changed` …);
- The reverse doesn't hold: many events (damage, check details) don't change the Board;
- The History Scroll screen ⑧ = an event-stream view + links back to the Board via provenance keys.
