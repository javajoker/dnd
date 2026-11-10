# Content Pack Authoring Guide: from campaign book to loadable data

> Version: v0.2 (discussion draft)
> Related docs: `02-content-pack-format-spec.md` (the format contract — read it first), `../story/02-campaign-ashenport-fragments.md` (source of the first instance)
> Scope: how content authors (designers / writers) transcribe a finalised campaign book into a loadable content pack. Reference instance: `../story/campaign01/`.
> English mirror of `docs/tech/03-内容包制作操作指南.md` (change history omitted). Terms follow `../GLOSSARY.md`.

---

## 1. Overall flow

```
① Campaign book design finalised (story/ docs, including the branch-graph self-check)
   → ② Create the pack: directory + manifest
   → ③ Transcribe the node graph into nodes.json
   → ④ Transcribe the five edge types (apply the edge templates)
   → ⑤ Transcribe the four tables (events / encounters / items / flags)
   → ⑥ Transcribe endings.json (+ lore.json)
   → ⑦ Run the validator (V1–V14 all green)
   → ⑧ Simulated playthrough / load in the engine
```

Transcription is **translation, not re-creation**: node IDs and edge directions in the data must correspond one-to-one with the campaign book. Graph problems found while transcribing (dead ends, missing failure paths) go back to the campaign book to be fixed and synced — never patched quietly in the data alone. When the two disagree, the design doc wins.

## 2. Campaign-book sections → data files

| Campaign book section | Data file | Notes |
|---|---|---|
| §1 Campaign card | `manifest.json` | Field-by-field |
| §3 Overall structure | `acts` in `nodes.json` | Act IDs, forced-mode marks |
| §4 Node graph | `nodes` in `nodes.json` | One step per node, see §3 |
| §5 Flag design | `flags.json` | The writer/reader ledger comes straight from the design table |
| §6 Quest/event list | `events.json` | One row per entry |
| §7 Encounter list | `encounters.json` | One row per entry |
| §8 Item table | `items.json` | One row per entry |
| §9 Ending types | `endings.json` | Conditions transcribed into the condition DSL |
| §10 Branch-graph self-check | Validator output | The manual self-check table is re-verified by V1–V14 automation |

## 3. Transcribing the node graph (steps ③④)

### 3.1 Numbering rules

- Keep the campaign-book numbering: `N<act>-<seq>`; Act II side chains add a letter (`N2S-1`); Act III rooms keep the `R` numbering;
- Derived nodes such as failure paths and secret passages use the original number plus a lowercase suffix (`N1-2b`, `N2G-2b`);
- **Never rename in the data** — the numbers are the only shared language between the design doc, the data, validator errors and playtest feedback.

### 3.2 Templates for the five edge types

| How the design writes it | Edge type | Required fields | Iron rule |
|---|---|---|---|
| `[C]` save / don't save / deceive | `choice` | `label` `to` | Effects go in `effects` |
| `[K · Perception · medium]` | `check` | `skill` `difficulty` `success` `failure` | **failure required** |
| `[I · Half-Page Tide Chart]` | `item` | `item` `to` | `fallback`, or omit (hidden) |
| `[T] Doom Clock reaches 2` | `doom_clock` | `at` `to` | `once: true` to prevent repeats |
| `[R · all three reputations ≤0]` | `reputation` | `requires` `to` | Invisible gate, no hint at the entrance |

Narrative effects the design writes on an edge ("late: costs 1 extra clock segment") always become that edge's `effects` (here `{ "clock": 1 }`), never the node's — effects belong to "taking this path", not "arriving at this point".

### 3.3 Convergence and hubs

- A convergence node with several inbound paths (e.g. N2-C): each upstream node's edge points directly to it; the convergence node doesn't declare its sources;
- Hub nodes (N1-1 Plaza): `type: "hub"`; the rest/shop functions are an associated `rest` encounter; out-edges are declared as usual.

## 4. Transcribing the four tables (step ⑤)

Using *Ashenport Fragments* as the example:

- **events.json**: the ten rows of campaign book §6 → ten entries. `[T]`/`[C]`/`[R]` in `trigger` map to `doom_clock` / `choice` / `hidden`;
- **encounters.json**: the rows of §7 → one entry each. Note that `R3`/`R4-r`/`R5` are in a forced-portrait act, so they must be `mode: "forced_time"` with `max_units` ≤8;
- **items.json**: the rows of §8 → one entry each. `roles` holds the four identity tags; branch keys must fill `unlocks`, which the validator uses to cross-check item-edge references;
- **flags.json**: the eight rows of §5 → eight entries. `writers`/`readers` hold node IDs; global variables (clock, reputation, alignment, bonds) must **not** go into the pack's flags.

## 5. Endings and Compendium (step ⑥)

- Ending conditions are transcribed literally into the condition DSL ("Inkbound alignment > midline" → `{ "alignment": { "ink_gt": 50 } }`);
- There must be exactly one `default: true` fallback ending (E4) — validators V1/V5 rely on it to prove no dead ends and clock convergence;
- Compendium entries state their series and unlocking node; cross-pack series (Weaver's Fragments etc.) only receive entries; packs never redefine a series.

## 6. Validation and loading (steps ⑦⑧)

```bash
# structure + graph validation (V1–V14); exit code 1 if any FAIL
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tools/packlint.gd -- packs/campaign01

# bot simulation: walk the graph with many seeds and reach every ending
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tools/simulate.gd
```

### Common validator errors

| Error | Cause | Fix |
|---|---|---|
| V3 check edge missing failure | A check edge has no failure path | Add the failure path to the campaign book, then transcribe |
| V4 orphan flag | A flag is written but never read (or vice versa) | Delete the flag, or design a read point |
| V5 clock unbounded | Clock effects can break out of 0–10 | Adjust effect values or add an E4-style fallback |
| V7 namespace violation | The pack writes a `global.` key outside the whitelist | Use an in-pack flag + an Event Center link instead |
| V8 portrait unit overflow | A portrait encounter has max_units >8 | Split the encounter or change its mode declaration |
| V14 graft target missing | The arc's graft.into / graft.node doesn't exist in the target pack | Check the target pack version and node number; all three graft fields (into/node/edge) are required |

## 6.1 How arc packs and sub-games differ

- **Side arcs (pack_type=arc)**: must have a `graft` block (tech/02 §2.6) — not one character of the host pack changes; the arc hooks into the main graph via an injected edge.
  The node graph is "a small arc + a convergence edge back to a host node"; no endings (converging back to the main line is the ending);
  it may reference the host pack's characters/enemies/items directly (resolved in the merged view); its own entry ids must not collide with the host's (V14);
  lint scope = `lint_grafted` (V1–V3/V11 on the merged view; V4/V6–V9/V12/V13 + V14 per this pack).
- **Sub-games (pack_type=subgame)**: self-contained packs (the four resource tables travel with the pack, as in arena);
  a pure-puzzle sub-game = explore nodes + maze beats (`retry_on_fail`/`hint` puzzle-room semantics, tech/02 §6);
  `subgame.clear_as_win: true` counts reaching the ending node as 1 win (the record rule for combat-free sub-games, §2.5).
- Single copy: pack data lives only in `game/packs/<id>/` (the old authoring copies under `docs/story/` and `docs/subgames/` are archived in `archive/zh-CN/docs/` and no longer maintained).

## 7. Text and localization

Short text is embedded in each file (`title` / `summary` / `label` / `name` fields); long text is externalised to `texts/<locale>.json` via `text_ref` (tech/02 §1.1). Extraction should be done by a tool, not by hand. For an English build, the short fields need keys as well (see the code-review report, M5).

## 8. Review checklist (self-check for a data PR)

- [ ] Compared section by section with the campaign book; no unauthorised nodes or edges added or removed
- [ ] Node numbers match the campaign book
- [ ] Every `check` edge has a failure path
- [ ] Branch-key items' `unlocks` and the graph's `item` edges reference each other
- [ ] The flags.json ledger = campaign book §5, and every declared reader really reads the flag
- [ ] Validator all green (or deferred items listed with reasons)
- [ ] The docs/ authoring copy and the game/packs/ runtime copy are identical
