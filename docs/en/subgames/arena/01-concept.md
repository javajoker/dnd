# Arena Gauntlet (arena) · Concept Design

> Version: v0.2 (M3 validation slice; v0.2 adds §7.5 monetization declaration, with the M4 entitlement model in place)
> Basis: whitepaper §10.2 (sub-game = a content pack that reuses the encounter state machine and swaps rule parameters and presentation),
> doc 04 §6 (entry/exit must pass through the ⑨ Settlement screen; the entrance hangs in the ② campaign entry area, no new global nav item),
> tech/02 §2 (manifest `pack_type: "subgame"` + `subgame` variant declaration), 11 §7.1 (HP persists across encounters).
> Data pack: `pack/` (authoring source; synced copy at `game/packs/arena/`, same two-copy discipline as campaign01).
> English mirror of `docs/subgames/arena/01-概念设计.md`. Terms follow `../../GLOSSARY.md`.

## 1. One line

A gauntlet ring in Ashenport's underground scribing hall: three back-to-back encounters of rising difficulty, no rest between them, and you settle for however far you get — the arena form of **failure is a branch**.

## 2. Gameplay structure

```
Enter (A-0 cutscene) → Fight 1 Imp pack (easy) → Fight 2 Ink Fiend (medium) → Fight 3 Page Warden elite (hard) → Settlement (A-END)
                         ↘ quit while ahead → Settlement   ↘ quit while ahead → Settlement
                         ↘ defeat → settle on fights completed (at any point)
```

- 3 fights in a row, difficulty easy → medium → hard (the Light rules' three tiers, 11 §3);
- After each win the player picks one: **press on** (next fight, no rest, HP not restored) or **quit while ahead** (settle on fights completed);
- Losing any fight ends this gauntlet; settle on fights completed (failure is a branch — whitepaper §5.2 in arena form);
- HP persists across fights (11 §7.1): tracked in `<ns>.hp.<char_id>`, not restored between fights — this is where "no rest in the gauntlet" lands in the rules;
- One loadout on entry (09 §9.1), no further loadout mid-gauntlet; use-limited skills reset as each encounter is assembled, per 11 §8.

## 3. Rewards (writing the Board is a hard requirement, 04 §6)

| When | Reward | Where it lands |
|---|---|---|
| Each win | XP (encounter xp: 50 / 80 / 120) | `xp.gain` event (provenance pack=arena) |
| Each win | Gold (20 / 30 / 50, declared in manifest `subgame.gold_reward`) | `<ns>.gold` counter (07 §2 constraint 3, same precedent as campaign01.gold) |
| Flawless bonus | Ink Core ×1 (`give_item` effect on A-3's victory edge) | `global.inv` (shared inventory) |
| End of each gauntlet | Record: total wins / best streak | `<ns>.wins` / `<ns>.best` bookkeeping keys (declared in manifest `subgame.stat_keys`) |
| Each win | Stage flags stage1/2/3_cleared, flawless | `<ns>.*` flags (flags.json ledger, V4 closed loop) |

Gold and records are counter/bookkeeping keys and are not in the flags.json ledger (same precedent as campaign01.gold / xp_total).

## 4. Gates and interop (whitepaper §10.2: interop with the main line via the Board)

- **Reads global**: recommended level Lv2+ (manifest `recommended_level: [2, 4]`, shown on the entry card, not a hard lock);
- **Writes global**: Ink Cores go into `global.inv` (visible and usable in the main line); XP goes into the event stream (growth settlement belongs to each campaign's meta loop; this sub-game doesn't do point allocation);
- **Writes `<ns>`**: gold / records / stage flags all live in the `arena.*` namespace (07 §3 namespace permissions; cross-pack writes forbidden).

## 5. Rule variant declaration (tech/02 §2)

- Reuses the Light rule pack **light_v1** (`rule_pack: {"id": "light", "min_version": 1}`), no new rule parameters;
- Variant declaration: `subgame.rules_override = { "arena_mode": true }` — presentation-layer semantics only (no rest interval in the gauntlet, settlement shows the gauntlet record); **the rendering layer is unaware of the rule tier** (doc 05 iron rule), and rules_override never enters EncounterSM's numeric path;
- Mode declaration: `presentation.mode = "choice"` (dual-mode, tech/02 §2.1): follows the player's campaign mode or entry choice; the entry card offers both portrait and landscape "fight" buttons.

## 6. Screen and framework commitments (04 §6)

- Entrance: a "special campaign book card" in the ② campaign entry area (`pack_type=subgame` is enough to be listed — data-driven, arena isn't hard-coded);
- Inside: cutscene nodes reuse the two shells' story state; battles reuse EncounterSM ×3 (one core, two shells, 09 §8);
- Entry/exit must pass through the ⑨ Settlement screen: the summary reads out each item in turn (XP / gold / Ink Cores / record); exits = back to Home / History Scroll;
- No new global nav items; the nine-screen loop stays intact (04 §5).

## 7. Line-up and enemies (all numbers within light_v1 ranges)

- Party: the Unwritten + Kelan + Old Fei (transcribed from campaign01 data; can be tuned independently later — sub-games can be released and updated independently);
- Fight 1: Ink Imp ×3 (reused); Fight 2: Ink Fiend + Imp ×2 (reused); Fight 3: **Page Warden elite** (new) + Imp ×2 —
  the elite has the area skill "Seal Shock" (save DC12 / half damage, placed per 11 §5.1).

## 7.5 Monetization declaration (doc 06 §2/§3; tech/02 §2.2/§2.3; placed in M4)

- **The gate lives in the pack**: manifest `entitlement.requires = ["entitlement.arena"]` — a hard gate; all must be true to unlock (tech/02 §2.2);
- **Strategy participation declaration**: manifest `monetization.strategies = ["dlc"]` — used for the ② entry locked-state presentation and the Home promo slot; the actual gate is always `requires` (tech/02 §2.3);
- **Lighting it up is operations' job**: purchase (shop order-id provenance) / time-limited free event (`packs/_ops/ops_config.json` event switch) / achievement reward ("Ashenport clearers enter free": lit when `campaign01.cleared` is true) — three paths reuse the same entitlement variable, and **this pack is completely unaware of them** (06 §3.2);
- Locked-state presentation: the ② entry special campaign book card is **visible but locked** — cover / recommended level / record shown as usual + narrative lock text ("The arena's gatekeeper only honors the mark") + a "Get" button, with no blunt "Not purchased" popup (06 §3.1); purchase happens in a half-screen sheet (04 §3.3), unlocks immediately, no restart needed;
- Refunds: once the entitlement is set false, a gauntlet in progress may finish but no new run can start (06 §5).

## 8. Pending rulings (reported with the M3 delivery notes)

1. tech/02 §2 shows `subgame.rules_override` as a rule-pack id string; this pack, per the task ruling, uses an **object** `{ "arena_mode": true }` (a set of presentation-layer switches) — suggest §2 document the object form;
2. Extension fields `gold_reward` / `stat_keys` in the `subgame` block (gauntlet reward and record key declarations) — suggest §2 register them as optional fields (§11: all new fields are optional);
3. ~~Should sub-game XP count toward the campaign growth system?~~ **Closed by ruling (tech/04 §8 growth system finalised, 2026-11-09)** — growth belongs to the framework-global keys `global.growth.*`; xp effects from any pack (including this sub-game) flow in through the same channel; the sub-game Settlement screen can allocate attribute points the same way the loadout does.
