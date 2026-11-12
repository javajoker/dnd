---
name: codex-balance
description: Balance content for the Age of the Codex framework — win-rate bands, the balance_tune auto-tuner, enemy_mods and line-ups, class parity, XP/gold curves, bot simulation, and how to report evidence
whenToUse: Tuning battles, checking a new pack before release, adding enemies / classes / skills, or when a fight feels too easy or too hard
type: prompt
---

# Balance skill

References: `docs/en/story/03-balance-and-boss-design.md` (bands, anchors, measured rates), `docs/en/framework/11-light-rulepack-v1.md` §6 / §9, `docs/en/tech/11-content-pipeline-and-agents.md` §5.

## Targets

| Difficulty | Win rate (default party, expected level) |
|---|---|
| easy | 85–95 % |
| medium | 70–80 % |
| hard | 50–65 % |

Expected level per act: manifest `balance.act_level` (e.g. `{"A1": 1, "A2": 2}`). Classes: within ±7 points of the default hero. XP: a full campaign ends inside level 3 (700–1199 XP). Battle gold ≈ XP ÷ 5.

## Tools

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path game -s tools/balance_tune.gd -- packs/<id> --games 600                # measure + suggest
$G --headless --path game -s tools/balance_tune.gd -- packs/<id> --games 600 --write        # write enemy_mods
$G --headless --path game -s tools/balance_tune.gd -- packs/<id> --games 600 --seed 7       # confirm, 2nd seed
$G --headless --path game -s tools/balance_tune.gd -- packs/<id> --only <encounter> --games 1000
$G --headless --path game -s tools/winrate.gd -- 600 5 packs/<id> [class_id]                # full table / per class
$G --headless --path game -s tools/simulate.gd -- 24 packs/<id>                             # whole runs (side quests: injected into the host)
```

Side quests are tuned on the merged view with their host automatically. Trial packs: `user://story_trial/<id>`.

## Knob order

1. `enemy_mods.hp` (all enemies of that encounter) — the tuner's first choice.
2. `enemy_mods.attack_mod` (±1–2) when HP alone can't reach the band.
3. Line-up (add / remove / swap enemies) when the tuner reports "still out of band".
4. Shared enemy stats — only with the world designer; re-run every pack using that enemy.
5. Never the rule pack.

## Reporting

A table per pack: encounter, difficulty, band, rate before, change, rate after (two seeds, ≥ 600 games). Note noise (200 games ≈ ±3 points). Record final rates in the pack's book (and story/03 for campaign01).
