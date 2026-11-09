---
name: godot-acceptance-en
description: The Age of the Codex acceptance / self-check / audit workflow (English) — after a feature is done, accept it item by item against the docs; cross-doc consistency audits (D&D rules / branch graph / dual-shell consistency / monetization no-go zones / dual-track compliance / device readiness); outputs a structured audit report
whenToUse: When an implemented feature needs acceptance, for periodic self-checks, pre-release audits, or when the user asks to check "whether the implementation matches the docs" or to verify checklist status
type: prompt
---

# Acceptance / self-check / audit skill (The Age of the Codex) — English

The top audit principle: **implementation obeys the docs**. When the implementation exceeds the docs, either add it to the docs or delete it (the lead agent decides); when the implementation falls short of the docs, list the gap.

Second principle: **verify, don't trust the checkbox.** A ✅ in TASKS / doc 13 / doc 14 is a claim. Confirm it by reading the code path and running it — and confirm it on the target platform when the claim is about the player's experience, not just inside the headless harness.

Docs: Chinese originals under `docs/` are authoritative; the English mirror is `docs/en/` (terms in `docs/en/GLOSSARY.md`).

## 1. Feature acceptance (after every feature)

Tick every item; the feature is done only when all pass:

1. **Doc basis**: the doc clause is explicit (e.g. "11 §3.1 advantage/disadvantage");
2. **Headless tests**: `godot --headless --path game -s tests/run.gd` all green (check the process exit code, not a piped `tail`), with assertions for the new behavior;
3. **Iron-rule scans** (grep level):
   - `grep -rn "extends Node\|Input\.\|@onready" game/core/` → must be empty;
   - `grep -rn "randi()\|randf()" game/core/` (except rng.gd) → must be empty;
   - `grep -rn "Board\." game/shell/ | grep -v "read\|get_"` → shells must not write the Board;
   - `grep -n "board.write" game/main.gd game/subgame_runner.gd` → every hit needs a justification or a move into core;
   - `grep -rn "campaign01\|\"N[0-9]-" game/core game/shell` (comments excluded) → no hard-coded pack or node ids;
   - `grep -n "user://" game/tests/run.gd` → every path must be a test path, never the default save slot or settings file;
4. **Event-stream completeness**: does the new behavior produce events (traceable in the History Scroll)? Do writes carry provenance? Is player-facing text a message key rather than baked prose?
5. **Dual-shell consistency** (for encounters): run the same encounter in both shells; event streams must match byte for byte (numbers, checks, results).

## 2. System self-check (weekly or before a milestone)

| System | Against | Checks |
|---|---|---|
| Board / saves | framework/07 | Variable ranges, namespace permissions, snapshot timing and migration chain — **and that a save written in one launch is loaded in the next** |
| Branch graph | framework/08 + tech/02 §12 | packlint V1–V15 green; every V4 WARN reviewed (a declared reader that doesn't exist is a gap, not a warning) |
| Six encounter states | framework/09 §1 | Entry/exit conditions, loadout / quickbar / auto-play, leaving mid-encounter (save and return Home = replay the encounter), app pause/resume |
| Two forms | framework/09 §8 + 04 | No switch within an encounter, ≤8 units on portrait screens, breathing ratios, **real device orientation change** (not a window resize) |
| Gestures | framework/12 | Vocabulary parameters, conflict resolution, **every gesture has an equivalent button** |
| Rules | framework/11 | D20 / crits / advantage-disadvantage / saves / companions / death saves best of three |
| Effects | tech/04 | base→add→mul→override→clamp pipeline order, effect provenance (not implemented yet — mark as a gap) |
| Monetization | framework/06 | Entitlements read-only, no-go zones (no dice / numbers sold, free branches intact), locked-state presentation |
| Screen loop | 04 §5 | Entrances and exits of the nine screens |
| Randomness | tech/01 §5.2 | Seeded RNG; a **fresh seed per new game**; seed restored from saves |
| Localization | tech/01 E-5, tech/02 §1.1 | No user-facing strings in core; every UI string keyed; text fits at English length |

## 3. Release audit (before every release)

1. **packlint**: run `game/tools/packlint.gd` on every pack (V1–V15), all green;
2. **Bot simulation**: `game/tools/simulate.gd` reaches every campaign01 ending (TP1 exit);
3. **Dual-shell spot check**: 3 random encounters, event streams compared across the two shells;
4. **Save compatibility**: load a previous version's save + run the migration chain; **cold-launch the app and continue from that save**;
5. **Monetization no-go review**: every new product/entitlement path checked against the four rules of 06 §4;
6. **Dual-track compliance**: is this release content-track or operations-track? Did content go through the full pipeline? Did operations leave the content graph alone and not revoke acquired entitlements?
7. **Device check**: an Android and an iOS export build, installed and played on a real device: orientation, safe area, backgrounding, back button, text legibility.

## 4. Audit report format

```
## Audit report · <scope> · <date>
Verdict: pass / conditional pass / fail
### Evidence (commands run with outputs / logs / screenshots)
### Passed items
### Gaps (implementation < docs): [clause] description → suggested fix
### Overreach (implementation > docs): [location] description → suggestion: add to docs or delete
### Checklist verification: claimed status → verified status
### Risks and follow-ups
```

## 5. Fix discipline

- Gap fixes: implement per the docs;
- Overreach: **default to adding it to the docs** (precedent agreed with the user: crits, attribute points); if that's not possible, delete the implementation;
- A failed audit may not be merged; a conditional pass must list the open items in the commit message;
- When a checklist claim is found to be false, correct the checklist (both languages) in the same change.
