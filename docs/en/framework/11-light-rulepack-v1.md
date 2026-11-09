# Light Rule Pack v1 (light v1)

> Version: v1.1 (final; v1.1 strengthens D&D conformance: advantage/disadvantage, saving throws, companion rules, critical hits)
> Related docs: `05-rules-system-framework.md` §3/§8 (six elements and direction), `../story/02-campaign-ashenport-fragments.md` (the first bound campaign, recommended levels 1–4)
> Scope: complete numeric definitions for the Light rule pack's six elements. Goal: rules explainable in 5 minutes, friendly to one-handed play, with checks that stand out in presentation; leaves extension points for the later Standard tier.
> English mirror of `docs/framework/11-轻规则包-v1.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Attribute model

- **Three attributes**: Might / Finesse / Wits, values **-1 to +3**;
- Character creation: assign **+2 / +1 / 0**, one each (companions are predefined by the content pack);
- **HP = 10 + 2×level + Might modifier**;
- Extension point: the data structure is an "attribute table", not three hard-coded fields, so when the Standard tier moves to 6 attributes a mapping table folds them (doc 05 §5).

## 2. Skill table (derived from the three attributes)

| Skill | Attribute | Example use (placement in campaign01) |
|---|---|---|
| athletics | Might | Climbing, breaking doors |
| intimidate | Might | Interrogation, scaring off |
| stealth | Finesse | N2U-1 Black Feather Gathering |
| thievery | Finesse | Lockpicking, traps |
| perception | Wits | N0-2 The Vanished Pier Name |
| investigation | Wits | N1-2 faded site, N2L-1 Investigate Alone |
| history | Wits | N2S-1 Archive Trial |
| persuasion | Wits | N2G-1 Fragment Auction |
| soothe | Wits | R2 Empty Classroom |

- A check edge may declare an `a_or_b` dual skill (e.g. `history_or_perception`): use the higher of the two modifiers;
- Skills have no levels of their own; modifier = attribute modifier + proficiency (+2 if proficient in that skill). Character creation picks 2 proficient skills.

## 3. Check formula

```
d20 + attribute modifier (+ proficiency +2) (+ item modifier) vs DC
Three difficulty tiers: easy DC 8 / medium DC 12 / hard DC 16
```

- The output is always **a success/failure pair of branches** (D20 minimal core, doc 05 §2);
- Natural 20 = critical success (success + the content pack may attach extra effects); natural 1 = critical failure (failure + may attach a cost); both bump the presentation tier (doc 09 §6);
- **Critical attacks**: an attack with a natural 20 always hits and **doubles the damage dice** (roll the damage dice twice and sum; the modifier isn't doubled); an attack with a natural 1 always misses;
- Item modifiers (`check_mod` identity) are ≤ ±4 per check (doc 10 §1).

### 3.1 Advantage and disadvantage

- **Advantage**: roll 2d20, take the higher; **disadvantage**: roll 2d20, take the lower;
- They don't stack: multiple advantage sources = one advantage; advantage and disadvantage cancel out (any combination → normal roll);
- Applies to checks, attacks and saving throws;
- **Sources are declared by content packs** (environment / teamwork / effects / flags); the rule pack doesn't hard-code a list. Examples: the "witnessed_revocation" flag → the whole party has attack advantage on the first round of the relevant encounter; "Ink Shield" → attackers have disadvantage while it lasts.

## 4. Action economy (three parts)

Each turn: **move (≤6 squares) + action ×1 + bonus action ×1**, in any order.

- Actions: attack / skill / use an item / help a downed ally;
- Bonus actions: drink a potion, switch weapons, short-range movement skills, etc. (marked on the skill card);
- Reactions **are not part of the Light rules** (introduced in the Standard tier).

## 5. Combat round structure

- Initiative = d20 + Finesse modifier, in descending order; ties go to the player;
- Attack roll: d20 + attribute modifier vs target AC (AC = 10 + Finesse modifier + armor value);
- Damage = weapon die + attribute modifier (weapon dice table in §8); critical doubling in §3;
- Win/lose conditions: one side wiped out / a retreat edge / an objective defined by the encounter (escort, survive N rounds, etc.);
- ≤8 units on screen (portrait constraint, validator V8).

### 5.1 Saving throws (minimal version)

- Area effects and traps may declare a save: `save = { attr, dc, on_success: "half" | "none" }`;
- Saving throw = d20 + the relevant attribute modifier vs DC; on success, half damage (half, rounded down) or no damage (none);
- Saves use normal presentation by default; a content pack may mark one as a key check (doc 09 §6).

### 5.2 Companion rules (controllable but simplified)

- Companions are **controllable units**: they share the same command channel as the player character (the same quickbar and action economy); each living companion may take 1 action per round; if the player gives no command, the companion holds position;
- Simplified companion card: HP, AC, 1 attack modifier, 1 signature skill; no full three attributes or skill trees (deepened in the Standard tier);
- **Reviving the downed**: a companion at HP 0 is downed and stays down; an ally can use the "First Aid" action (d20 + Wits vs DC 8; on success they get back up with 1 HP); at the end of battle, downed companions automatically get up with 1 HP;
- When the player character is downed they make death saves (§7) while companions keep fighting; everyone down = party wipe, which takes the encounter's failure path.

## 6. Growth curve (levels 1–4, aligned with campaign01)

| Level | XP needed | Gains |
|---|---|---|
| 1 → 2 | 300 | HP +2; +1 attribute point |
| 2 → 3 | 700 | HP +2; +1 attribute point; +1 skill slot |
| 3 → 4 | 1200 | HP +2; +1 attribute point |

- Attribute points can be allocated at settlement or during battle loadout (doc 09 §9.1), each attribute capped at +3;
- XP sources: encounter settlement + failure-path compensation (failure is interesting too; XP isn't discounted: failure-path XP ≥ 80% of the success path);
- **Bookkeeping on the Board**: growth data is written to `global.growth.*` (doc 07 §2, tech/04 §8 growth system); xp effects from any content pack (including sub-games) flow in through the same channel.

## 7. Death and failure

- HP 0 → **downed**: enter death saves; each round, d20 ≥ 10 counts as a success, <10 as a failure, **best of three** — three successes first stabilises (1 HP), three failures first means death;
- Allies can use an action to help (First Aid, d20 + Wits vs DC 8; on success they stabilise);
- Death saves are a framework-constant **key check** (full-screen presentation, doc 09 §6);
- Party wipe = encounter failed → take that encounter's failure branch (whitepaper iron rule: failure is a branch, not a reload).

### 7.1 HP persists across encounters

- HP at the end of an encounter is written to the Board (`<ns>.hp.<char_id>`, doc 07 §2) and the next encounter starts from it — wounds are part of a continuous adventure; no "full HP every fight";
- The rest state restores HP to full and writes the Board (doc 09 §1 rest state);
- Downed companions get up with 1 HP after battle (§5.2), also written to the Board.

## 8. Weapon dice and use-limited skills

| Weapon class | Damage die | Example |
|---|---|---|
| Light | d4 | Short blade |
| One-handed | d6 | Harbor Guard sword |
| Heavy | d8 | Boat-hook axe |
| Spell-style | d6 (Wits) | Ink Bolt |

- No spell slots; **use-limited skills**: each active skill can be used N times per encounter (marked on the skill card, usually 1–3), restored at rest;
- Classes are presented as **skill-combination bundles** (three at launch: Harbor Guard / Scavenger / Ink Adept — players feel a style rather than read clauses, doc 05 §8).

## 9. Difficulty calibration and placement pacing (for content authors)

| Campaign stage | Recommended encounter difficulty | Check difficulty mix (easy/medium/hard) |
|---|---|---|
| Prologue tutorial | Easy | All easy |
| Act I | Easy–medium | 3/5/2 |
| Act II | Medium | 2/5/3 |
| Act III | Medium–hard | 1/4/5 |
| Finale | Hard | Key checks concentrated in cutscenes; don't gate players by difficulty |

Expected pass rate: a medium check with a +2 attribute and proficiency ≈ 65% (d20+4 vs 12) — the target band of "most rolls have suspense, and failure is worth watching".

## 10. Interface confirmation with the framework

- Event-stream format and Board read/write paths obey the three immutable items of the D20 minimal core;
- Rule-pack ID: `light`, version `1`; the campaign01 manifest declares this binding;
- This pack's deprecation strategy, freeze mechanism and the cross-pack attribute mapping-table spec are in doc 05 §7/§9 (the mapping table is frozen when the first cross-rule-pack campaign appears).
