# Branching Model Specification

> Version: v1.0 (final, corresponds to P0.3)
> Related docs: `01-framework-whitepaper.md` §5, `../tech/02-content-pack-format-spec.md` §4 (data-layer DSL), §12 (automated validation)
> Scope: full definitions and validation rules for the five edge types, writing rules for "failure is a branch", node convergence strategy and branch budgets. Data representation follows `02-content-pack-format-spec.md`; this doc defines the design-layer semantics and constraints.
> English mirror of `docs/framework/08-分支模型规范.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Full definitions of the five edge types

| Edge type | Semantics | Visibility to player | Hard validation rules |
|---|---|---|---|
| Choice edge `choice` | An explicit player decision | Visible option card | `label` required; judged by **rendered width** — it must fit on one line of a portrait option card (guide: ≤20 Chinese characters, ≤36 English characters), in every shipped language; effects go in `effects` |
| Check edge `check` | A D20 check with success/failure paths | Visible (tiered dice presentation, see doc 09 §6) | **`failure` required**; the skill name must be registered in the bound rule pack |
| Item edge `item` | Appears only when holding a specific item | Hidden (appears once held) | The referenced item's `roles` must include `branch_key`; choose explicitly between `fallback` and omission |
| Time edge `doom_clock` | Fires automatically when the Doom Clock reaches a segment | Semi-visible (clock preview sheet) | `once: true` by default; must not point to a dead end |
| Reputation/alignment edge `reputation` | An invisible threshold, noticeable in hindsight | Hidden | Conditions only read the global variable whitelist; must be traceable in the History Scroll |

General rules: any edge can stack an extra `requires` gate; an edge's effects (writing flags / clock / reputation) belong to "taking this path", not "arriving at this point" — never put effects on the target node to pass them off as edge effects.


## 2. Writing rules for "failure is a branch"

Every check edge's failure path must satisfy **one of** the following:

| Pattern | Content requirement | Example (campaign01) |
|---|---|---|
| A. Independent path | ≥1 encounter or 1 exclusive cutscene, then merges back into the main line | N1-2 failure → N1-2b Cordoned Alley battle |
| B. Costed convergence | Merges with the success path at the same node, but the failure edge carries different effects (clock / reputation / flag / resources) | N2S-1 failure → 1-segment time penalty |
| C. Escalated punishment | Failure triggers a harder encounter, then forces a return to the path-choice point | N2L-1 failure → Wanted battle → forced chain choice |

**Forbidden**: idle convergence (failure = nothing happens and it merges directly), failure lock (the failure path has no out-edge), failure deletes content (the failure path is so short the player can't tell a branch exists).

Failure paths need narrative dignity too: failure text must not be system-speak like "You failed"; it must be a real rewrite of the world (in-world: the Weave wrote down a different version).

## 3. Node convergence strategy

1. **Side chains of ≤3 nodes must converge**: a side chain (e.g. the three faction chains of Act II) may span no more than 3 nodes from the fork to the convergence point;
2. **Convergence carries flags**: when paths merge, each carries different flag / reputation / clock state; nodes after the convergence point must respond with differentiated treatment (opening lines, attitudes, difficulty, available options), otherwise it counts as false convergence (the validator helps judge this with flag-read checks);
3. **A convergence point has a single job**: it only pieces together intel and advances the main line; it introduces no new branching dimension;
4. **Lone-wolf / hidden shortcuts**: every hidden path must have ≥2 reachable entrances (e.g. a reputation gate + a difficulty check), so "discoverability" doesn't depend on the luck of a single playthrough.

## 4. Branch budget (per campaign)

| Item | Budget | Basis |
|---|---|---|
| Total logical nodes | 25–40 | campaign01 measured 31/35; beyond that, split the campaign |
| Total edges | ≤ 2.5 × nodes | Prevents edge explosion from diluting what branches mean |
| Nodes per act | 5–15 | Whitepaper L2 definition |
| Out-edges per node | ≤ 5 (explicit choices ≤4 + hidden edges ≤1) | A portrait option list readable on one screen |
| Share of check edges | 20%–40% | Keeps the D20 ritual dense without dice fatigue |
| Ending types | 3–5 (including 1 `default` fallback) | Balance point between convergence and replay value |

The budget is **enforced by the validator** (V6 and extensions); an over-budget pack must be split into several content packs, with no exceptions.

## 5. Branch-graph validation checklist

Two layers: manual design self-check (the campaign book §10 pattern) + automated validation (`../tech/02-content-pack-format-spec.md` §12, V1–V10):

| Layer | Checks |
|---|---|
| Design self-check | Mark the failure pattern (A/B/C) of every check edge; verify differentiated treatment after convergence; ending conditions mutually exclusive with a fallback |
| Automated | No dead ends / no unreachable nodes / complete failure paths / closed flag loops / bounded clocks / budget / namespaces / portrait constraint / entitlement declarations / screen loop |

When the two layers disagree, the automated result wins and the design doc is revised (transcription discipline: `../tech/03-content-pack-authoring-guide.md` §1).
