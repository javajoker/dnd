# Riddle Maze (riddle_maze) · Concept Design

> Version: v1.0 (M4 content expansion, second sub-game)
> Basis: whitepaper §10.2 (sub-game = reuse the encounter state machine + swap rule parameters and presentation), 04 §6 (entry/exit
> must pass through ⑨ Settlement; entrance in the ② campaign entry area), tech/02 §2.5 (subgame variant block) / §6 (maze beats,
> retry_on_fail / hint puzzle-room semantics), 11 §2/§3 (check formula).
> Data pack: `pack/` (authoring source; synced copy at `game/packs/riddle_maze/`, same two-copy discipline as campaign01/arena).
> English mirror of `docs/subgames/riddle-maze/01-概念设计.md`. Terms follow `../../GLOSSARY.md`.

## 1. One line

Beneath the scribing hall runs an even older corridor: three quiet chambers locked by riddles instead of bars — **no blades, only brains**.
Get it wrong and the corridor gives you a hint and lets you think it through again.

## 2. Gameplay structure (pure puzzle room sequence, zero combat)

```
Enter (R-0 cutscene) → Chamber One (R-1 Wits check · medium) → Chamber Two (R-2 pick up a riddle scrap + Wits check · medium)
                     → Chamber Three (R-3 Wits check · hard) → Settlement (R-END)
```

- Reuses the **MazeRunner exploration sequence** (tech/02 §6 maze) to carry the room content: a beat sequence of check rooms + pickup rooms,
  **zero combat** — no battle nodes or encounter enemies are declared;
- **Failure gives a hint and a retry, never a dead end**: every check beat declares `retry_on_fail: true` + `hint` (tech/02 §6) —
  a failed check doesn't advance the beat and doesn't apply failure effects; it shows the hint text and retries in place;
- All checks are **Wits-based skills** (investigation / history / perception, derived from the Wits attribute in 11 §2); modifier = player attribute + proficiency;
- Leaving mid-run via ☰ and resuming later is naturally supported by MazeRunner's beat-progress bookkeeping (`<ns>.maze.<enc>.idx`, 07 §4.2).

## 3. Rewards (writing the Board is a hard requirement, 04 §6)

| When | Reward | Where it lands |
|---|---|---|
| R-END clear (on_enter) | Gold +40 (`gold` effect, tech/02 §4.6) | `riddle_maze.gold` counter (07 §2 currency clause) |
| R-END clear (on_enter) | Compendium entry `fatedie_study_riddle` (lore effect) | `global.lore` (doc 10 Compendium) |
| R-END clear (on_enter) | XP +60 (xp effect) | Flows into `global.growth.xp` (tech/04 §8 rule 1) |
| R-2 pickup beat | "Riddle Scrap" ×1 (codex item) | `global.inv` (shared inventory) |
| End of each run | Clear count / record bookkeeping | `<ns>.wins` / `<ns>.best` (manifest `subgame.stat_keys`; one clear counts as 1 win) |

## 4. Gates and monetization (tech/02 §2.2/§2.3)

- **Entitlement default = free with the base game**; `monetization.strategies = ["free"]` (V9 consistency: free must not declare requires);
- Interop with the main line: XP flows into growth; gold / Compendium / items interoperate via global keys; reads and writes no main-line flags.

## 5. Rule variant declaration (tech/02 §2.5)

- Reuses the Light rule pack light_v1 with no rule-parameter changes; `rules_override = { "puzzle_mode": true }` —
  presentation-layer semantics only (no combat; settlement shows the puzzle record); the rendering layer is unaware of the rule tier (05 iron rule);
- `presentation.mode = "choice"`: the entry card has fight buttons for both forms (04 §6 data-driven listing).

## 6. Screen and framework commitments (04 §6)

- Entrance: a sub-game card in the ② campaign entry area (data-driven, same channel as arena);
- Inside: cutscene/puzzle rooms reuse the two shells' story state + maze-beat presentation; entry/exit must pass through ⑨ Settlement (summary: XP / gold / Compendium / record);
- Core reuse: StoryGraph walks the node graph + MazeRunner walks the beats; **the zero-combat path never instantiates EncounterSM**;
  adding this sub-game introduced no new core types (the only M4 core changes are the generic graft capability and the maze retry fields, decoupled from this sub-game).

## 7. Rooms and riddles (all numbers within light_v1 ranges)

| Room | Beat | Skill / difficulty | Hint |
|---|---|---|---|
| R-1 Chamber One · Inscription | Check beat | investigation · medium (DC12) | "The inscription is written backwards — read from the last character forward." |
| R-2 Chamber Two · Scrap | Pickup beat (Riddle Scrap ×1) → check beat | history · medium (DC12) | "The timeline on the back of the scrap is missing a page: the year that was revoked." |
| R-3 Chamber Three · Fatedie | Check beat | perception · hard (DC16) | "The notches on the die aren't numbers — they're tide levels. Count the rises and falls." |

## 8. Pending rulings and gaps

- Riddle text is first-version placeholder (atmospheric); the real riddles/answers await copy iteration (`texts/zh-CN.json` extraction slots reserved);
- The fixed 40 gold is a first-version placeholder (compensating for no combat XP; aligned with the size of a single arena fight);
- "Clear count" reuses the `wins` record-key semantics (one clear = 1 win); if a separate key name is needed, adjust via manifest.subgame.stat_keys.
