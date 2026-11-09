# Items and Compendium Specification

> Version: v1.0 (final, corresponds to P0.6)
> Related docs: `01-framework-whitepaper.md` §8, `../tech/02-content-pack-format-spec.md` §7/§10, `06-monetization-framework.md` §4 (no-go zones)
> Scope: the tag system and combination rules for the four item identities; how Compendium series are divided and the form of completion rewards.
> English mirror of `docs/framework/10-道具与图鉴规范.md`. Terms follow `../GLOSSARY.md`.

---

## 1. The four-identity tag system

Every item carries a `roles` tag array (data format in `../tech/02-content-pack-format-spec.md` §7):

| Tag | Identity | Design duty | Hard rules |
|---|---|---|---|
| `stat` | Numeric | Affects in-encounter power (weapons / armor / consumables / upgrade stones) | The numbers are reviewed with the bound rule pack |
| `check_mod` | Check modifier | Affects the pass rate of check edges | Modifier ≤ one difficulty step (Light rules cap ±4) |
| `branch_key` | Branch key | Opens item edges, changing the shape of the story graph | **Must declare `unlocks`**; validator cross-checks it against item edges |
| `codex` | Compendium / Lore | Completing a series unlocks background entries and hidden entrances | Must belong to a registered Compendium series |

Combination rules:

- Identities can stack (e.g. Weaver's Fragment = `codex` + `branch_key`) and this is encouraged — the escalation through four identities is exactly the design intent of collection driving branch topology (whitepaper §8);
- An edge opened by a `branch_key` must have a non-key alternative path (`fallback` or a detour): keys are shortcuts and extras, not iron doors — exceptions need review;
- Story items (Fatedie-like) are marked `quest: true`: can't be dropped, don't count toward carry weight, can't be sold.

## 2. Rarity and placement

| Rarity | Identity | Placement principle |
|---|---|---|
| Common | stat | Shops / regular loot |
| Fine | stat / check_mod | Boss loot, check success paths |
| Rare | branch_key | Deep in side chains, hidden pickups |
| Token | codex (+branch_key) | Spread out as a series: main line ×1, hidden spot ×1, boss ×1, NG+ ×1 (the campaign01 fragment pattern is the template) |

Acquisition writes the Board immediately (`give_item` effect + event stream); the inventory is just a view of the Board's `global.inv`.

## 3. How Compendium series are divided

- **Series are defined at the world layer** (the four series in `../story/01-world-age-of-the-codex.md` §9); content packs only contribute entries and declare their series in lore.json;
- Conditions for a new series: ≥6 entries, a clear completion reward, and a theme that doesn't overlap existing series;
- Every entry's unlock source must be findable in nodes.json (a `lore` effect or a hidden pickup point), so "can't complete it" can always be traced back to "there's content you haven't played".

## 4. Completion reward forms (whitelist)

| Reward form | Example | Status |
|---|---|---|
| Hidden storyline | Complete the Weaver's Fragments → reveals the truth of the Fading | ✅ |
| Hidden campaign / form | Register of the Revoked → unlocks a "Remembrance" campaign (forced portrait) | ✅ |
| Cosmetic | Treatise on the Fatedie → dice skin | ✅ (pure presentation, doc 06 §3) |
| Reputation / discount | Ashenport Gazetteer → Ashenport reputation and shop discount | ✅ |
| **Numeric power** | — | ❌ Permanently forbidden (same root as the doc 06 §4 no-go zones: collection doesn't sell power either) |

Completion check: triggered by the event of all entries in a series unlocking; settlement uses the standard effect vocabulary; reward content goes through the ordinary content-pack validation pipeline.

Cosmetic reward delivery details (v1.1): when the completion reward is a dice skin, lighting it = writing the cosmetic flag `global.cosmetic.owned.<skin_id>` (doc 07 §3 v1.2, system-write only); series completion aggregates lore entries across **all loaded content packs** (entries can be contributed by other packs, e.g. the Riddle Maze pack contributes a Treatise on the Fatedie entry); series ids follow the values registered in `../tech/02-content-pack-format-spec.md` §10 (Treatise on the Fatedie = `fatedie_study`); skins and the "series → skin" mapping are registered in the operations-side registry `packs/_ops/cosmetics.json` (doc 06 §7).
