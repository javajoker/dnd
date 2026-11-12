# Final Balance and Boss Design (*Ashenport Fragments*)

> Version: v1.0
> Related docs: `../framework/11-light-rulepack-v1.md` (numeric rules), `02-campaign-ashenport-fragments.md` §7/§11; data: `campaign01/enemies.json` / `encounters.json`
> Scope: difficulty targets for every encounter, boss turn-behavior scripts, final enemy stats. Method: **simulation-driven** — calibrated against bot win-rate distributions, never by guesswork.
> English mirror of `docs/story/03-数值定稿与Boss设计.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Difficulty targets and calibration method

| Difficulty tier | Target win rate (default loadout, no auto-play bonus) | Experience role |
|---|---|---|
| Easy | 85–95% | Tutorial and narrative pacing beats |
| Medium | 70–80% | Standard main-line tension |
| Hard | 50–65% | Punishment paths and the Finale; losable but meaningful |

Calibration: `tools/winrate.gd` runs 200 bot battles per encounter with the default party; once the win rate lands in the target band, the numbers are final. If not, adjust enemy HP / attack / count (never the rule pack). `tools/balance_tune.gd -- <pack dir> --games 600 [--write]` automates the search: for each battle out of band it finds an encounter-level `enemy_mods` (HP first, then attack), confirms with a second seed, and flags battles that need a line-up change (tech/11 §5).

**Per-encounter knob** (P6.3): `encounters.json` `"enemy_mods": {"hp": n, "attack_mod": n}` adjusts every enemy instance of that encounter without touching the shared enemy entry. Used after companion healing skills arrived: R3 and R4-r2 got `hp +2`; N2S-2, N2U-1b and R4-r `hp +1`. Measured at 1000 games per battle (seed 5): N2S-2 76.9%, N2U-1b 73.0% (3000 games), N2U-2 77.2%, R3 71.9%, R4-r 72.2%, R4-r2 71.9%; easy 89–90%, hard 56.6–63.6%. Re-run with several seeds before changing a knob: at 200 games one battle wobbles by about ±3 points.

**Class check** (P6.3): `tools/winrate.gd -- <games> <seed> <pack dir> <class>` reruns every battle with a chosen class (tech/07 §5). Each class must stay within **±7 points** of the default hero's rate per battle, so no build trivialises or locks a fight; the default hero alone is held to the bands above.

## 2. Boss turn-behavior scripts

Enemy entries gain a `behavior` field (a data-driven turn-behavior script):

```json
"behavior": [
  { "every_n_rounds": 2, "skill": "ink_surge" },
  { "when_hp_below": 0.5, "once": true, "skill": "call_imps" }
]
```

| Field | Meaning |
|---|---|
| `every_n_rounds` | Use this skill every N rounds (replaces the basic attack) |
| `when_hp_below` + `once` | Fires once when HP crosses the threshold (phase change) |
| `skill` | References one of the enemy's own skills (AoE declares its save, 11 §5.1) |

Scripts are evaluated in order; if nothing matches, the enemy makes a basic attack. Everything a behavior script produces goes into the event stream (`battle.skill`, including save details).

## 3. Boss design drafts

### 3.1 The Page Warden (R5, hard)

- Role: the Scriptorium's automatic scribing golem — the enforcer of order;
- `seal_shock` Seal Shock: AoE every 2 rounds (Finesse save DC 12, half damage, 1d6+2);
- Phase change: once, when HP < 50%, "Rewrite the Rules" — its own attacks get +1 for the rest of the battle (traceable in the event stream).

### 3.2 The Inktide Avatar (N4-1, hard)

- Role: incarnation of the Fading tide;
- `tide_sweep` Inktide Sweep: AoE every 2 rounds (Finesse save DC 13, half damage, 1d6+2);
- `call_imps` Summon: once, when HP < 50%, summons Ink Imp ×2 (validated against the ≤8 units on screen constraint);
- The showed_mercy flag → `enemy_weaken` attack -2 (tech/02 §6, already in place).

## 4. Enemy stat table (final)

The values after §1 simulation calibration are authoritative and are written to `campaign01/enemies.json`. Every later adjustment must rerun winrate and update this table.

Calibration run: 200 runs per encounter, base seed 20261109, default party = expected level + default loadout.

| Enemy | HP | AC | Attack mod | Damage |
|---|---|---|---|---|
| Ink Imp | 8 | 10 | +2 | 1d4 |
| Ink Fiend | 16 | 11 | +3 | 1d4+1 |
| Ink Swarm | 10 | 10 | +3 | 1d4+1 |
| Black Feather Guard | 12 | 12 | +3 | 1d6 |
| Tax Collector's Guard | 14 | 11 | +3 | 1d6 |
| Fog Wharf Ambusher | 9 | 11 | +3 | 1d4+1 |
| Three-Faction Mercenary | 12 | 12 | +3 | 1d6+1 |
| Page Warden | 38 | 13 | +5 | 1d6+2 |
| Inktide Avatar | 15 | 13 | +3 | 1d6+2 |

Line-ups: N1-2b Imp×3 + Swarm×1; N2S-2 Swarm×2; N2U-1b Black Feather Guard×3; R3/R4-r2 Fiend + Swarm×2; R4-r Swarm×3 + Imp×1.

Measured win rates (%): N1-2b 88.5 / N1-7 87.0 / N2S-2 78.5 / N2U-1b 80.0 / N2U-2 72.5 / N2L-1b 55.5 / R3 70.5 / R4-r 72.5 / R4-r2 70.5 / R5 56.0 / N4-1 58.5 — all within the §1 target bands.

## 5. Growth and consumables check

- Total main-line XP from Prologue + Act I through Act III vs the 300/700/1200 threshold table: finishing should land around Lv3 (Lv4 with one side-chain replay, campaign book §1). Measured (winrate calibration round): Scriptorium chain 810 / Uninked chain 1110 / Salvage Guild chain 1040 — all Lv3 ✓;
- Lone-wolf chain totals 1290 → Lv4 — the expected ceiling for a "high-risk, high-reward" design; kept (acceptance ruling 2026-11-09);
- Supply Potion / Ink Core placement vs difficulty targets (11 §9 placement pacing): calibration is strict, assuming "default loadout, no items", so potions are the player's margin for error.
