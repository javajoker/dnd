# Side Arc · *The Crane Ledger* (arc_crane) · Design Notes

> Version: v1.0 (2026-11-12) — the first side quest made end to end with the content pipeline (tech/11 §3.3).
> Script (structure source of truth): `05-side-arc-the-crane-ledger.story.md` → `tools/story_import.gd` → `game/packs/arc_crane/`.
> Related: tech/02 §2.6 (graft), tech/10 (script format), story/03 (balance bands), world book §4.5 / §6 / §9.

## 1. One line

Old Fei has chalked every harbour crew he ever worked with into one ledger, and the Fading has started eating it from the back. Help him get it out of the flooded tally house, then decide who the names belong to.

## 2. How it attaches

```json
"graft": {"into": "campaign01", "node": "N1-1",
  "edge": {"type": "choice", "label": "Old Fei wants a word about his ledger", "to": "C-1", "requires": {"flag.done": false}}}
```

- **Entry:** the Free City Plaza hub (N1-1). It's always offered until the quest is done (Old Fei is in the default party).
- **Return:** C-7 goes back to N1-1. The main line, its endings and its flags are untouched.
- **Free:** `monetization.strategies = ["free"]`, no entitlement.
- **Quest log:** `events.json` `crane_ledger` (objective, completes at C-7, settles +20 XP).

## 3. Node arc (10 nodes)

| Node | Type | Content |
|---|---|---|
| C-1 | scene | **Under the Old Crane**: Old Fei asks for help (`bond.laofei +5`). **Dockhand** background line: "my name's in there too" (`bond.laofei +10`, inspiration +1) |
| C-2 | check | **The Flooded Tally House**: athletics or thievery, medium; the **Boathook Axe** (item edge) opens it outright. Either failed check → C-2f |
| C-2f | scene | **Too Much Noise**: the one costed failure, `clock +1` (a lamp on the breakwater fades) → C-3 |
| C-3 | battle | **Ink at the Ledger** (medium): Ink Swarm + Dock Ambusher ×2 + Ink Imp, `enemy_mods.hp −1`; 60 XP, 12 gold, Ink Salve |
| C-4 | dialog | **Three Buyers for a Book of Names**: lore `revoked_registry_crane`. The Scriptorium clerk, an Uninked runner and Old Fei himself |
| C-5 | battle | **The Clerk's Hired Swords** (easy, only if the persuasion check fails): Mercenary ×2, `enemy_mods.hp +4`; 40 XP, 8 gold; `rep.scriptorium -1` |
| C-6k | scene | **Names Read Aloud** (keep it): `bond.laofei +15`, **Old Fei's Crane Token**, 40 XP |
| C-6s | scene | **A Clean Copy** (Scriptorium): from C-4 `rep.scriptorium +1`, alignment +5 (Inkbound), 15 gold; here `bond.laofei +5`, `clock −1` (re-inking slows the Fading, world book §5), 40 XP |
| C-6u | scene | **What the Tide Keeps** (Uninked): from C-4 `rep.uninked +1`, alignment −5 (Blankward); here `bond.laofei −5`, 40 XP |
| C-7 | scene | **The Crane at Low Tide**: writes `done` → N1-1 |

The choice at C-4 is the quest's point: each faction gets a reward for its view of what names are for (world book §6). The kindest option for Old Fei costs a check and maybe a fight.

## 3.1 Canon

This quest filled Old Fei's open item "his written past" in the world book §8.2: the crane ledger, the tally house, and the crews named.

## 4. Data added (world designer)

| Data | Where | Why |
|---|---|---|
| `fei_crane_token` — Old Fei's Crane Token, trinket, `max_hp +2`, not sold | `arc_crane/items.json` | A keepsake that rewards the companion route. It's weaker than the shop's Tide Charm (+3, 35 gold) so it doesn't outclass bought gear. The host can read `item.fei_crane_token` later to react to this quest |
| Lore `revoked_registry_crane` | `arc_crane/lore.json` (series *Register of the Revoked*) | Counts toward the series completion |

Everything else is reused from the host: player_blank, Kelan, Old Fei, Ink Swarm, Dock Ambusher, Mercenary, Ink Salve, Boathook Axe.

## 5. Interface with the main line

- **Reads:** `background` (Dockhand line), `item.boathook_axe`, its own `arc_crane.done`.
- **Writes:** `arc_crane.done`; global `bond.laofei`, `rep.scriptorium` / `rep.uninked`, `alignment`, `lore`, XP and gold; `doom_clock` +1 (C-2f) or −1 (C-6s).
- **Doom Clock:** packlint V5 sums host + arc positive clock effects: 9 + 1 = 10 ≤ 10. Together with arc_tide (also +1) the static sum would be 11. Both arcs are linted one at a time, and the runtime clamps the clock to 0–10 (`Board.CLOCK_MAX`). Any further arc that costs a clock segment needs a host-wide budget review.

## 6. Balance and validation (measured 2026-11-12)

| Battle | Band | Before | Change | After (seed 20261109 / 7 / 99, 600 games) |
|---|---|---|---|---|
| C-3 | medium 70–80 | 93.7 % (Swarm + Ambusher ×2) | first `hp +5`; then the HP cap (±40 % of the weakest enemy, so ±4) ruled that a different monster, so the line-up gained an Ink Imp, with `hp −1` | 77.7 / 74.3 / 76.7 % |
| C-5 | easy 85–95 | 100 % (one mercenary; HP and attack knobs couldn't fix it) | line-up → Mercenary ×2, `hp +4` | 89.2 / 88.2 / 89.8 % |

- Classes (600 games): Harbour Guard 77.0 / 92.2, Scavenger 74.0 / 89.8, Ink Adept 76.5 / 90.5. All within ±7 points of the default hero.
- packlint (grafted onto campaign01): 0 FAIL / 0 WARN; zh-CN 54 keys complete.
- `simulate.gd -- 24 packs/arc_crane` (injected into the host, run from the host start): every run reaches a host ending, clock in range, quest node coverage 10/10. Covered by `test_arc_crane` in `tests/run.gd`.

## 7. Pipeline notes (what this run fixed)

- The importer cut long summaries mid-word; now it cuts at a word boundary with an ellipsis.
- `simulate.gd` and `StoryBot.run` now accept side quests: they inject the arc into its host, and the bot takes the injected option when it appears.
- The first line-up was rejected by the tuner ("change the line-up"), as tech/11 §5 intends.
- C-3 was re-done after the HP cap was introduced: `hp +5` on 9-HP ambushers broke the cap, so the line-up changed instead.
