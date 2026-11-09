# Monetization Framework (the Entitlement Model)

> Version: v1.1 (final, P0.9 review passed; v1.1 adds per-pack strategy choice and the operations iteration track)
> Related docs: `01-framework-whitepaper.md` §10.4/§12, `02-PRD.md` F8, `04-ui-ux-design.md`, `../tech/02-content-pack-format-spec.md` §2.2/§2.3
> Scope: defines the business model as an abstract framework extension axis. Concrete pricing and the launch monetization strategy are operations decisions, planned separately (decided before store submission, see `03-TASKS.md` P0.5).
> English mirror of `docs/framework/06-商业化框架.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Positioning

The business model is not a shape of the framework but a **delivery strategy**:

- The framework provides a unified **entitlement model** that supports all four mainstream monetization models — mixable and adjustable per version; any future model is supported automatically as long as it lands on "lighting an entitlement variable";
- **Monetization strategy is a per-pack choice**: each campaign / sub-game independently declares which strategies it participates in (§3.2), adjusted per version with operations decisions;
- Monetization obeys the framework's iron rules like rules and story do: it takes effect only through the Board;
- Which strategy we launch with doesn't block the framework freeze (M0); it just needs to be decided before store submission.

## 2. The entitlement model

### 2.1 What an entitlement is

- **An entitlement = a global variable on the Board** (managed in the framework-layer namespace, see whitepaper §4.3);
- Content packs declare their own unlock conditions (which entitlement variables must be true);
- **There are many ways to light an entitlement**: purchase, event gifts, achievement rewards, NG+ carry-over — payment is just one of them. This lets operations tools such as "free trial chapters" and "achievements unlock hidden campaigns" reuse the same mechanism as payment.

### 2.2 Entitlement granularity

| Granularity | Example |
|---|---|
| Base entitlement | Eligibility for the base game |
| Campaign entitlement | A specific campaign book / story-branch pack |
| Benefit entitlement | Early-unlock rights or exclusive cosmetic usage during a subscription |
| Cosmetic entitlement | Dice skins, character looks, presentation effects |

### 2.3 Entitlement variable rules

- Namespace: all under `global.entitlement.*` (e.g. `global.entitlement.campaign01`), managed by the framework layer (`07-world-state-machine-spec.md` §3);
- **Only the shop / events / achievements systems may write**; content packs are read-only; a write takes effect immediately with no restart;
- **Registry**: every legal entitlement variable is registered in the operations-side registry `packs/_ops/entitlements.json` (a data file, not code constants) — a new entitlement = one new line on the operations side; validator V9 checks against this table that every entitlement a pack references is registered;
- Pack unlock-condition declaration: manifest `entitlement.requires` (data contract in `../tech/02-content-pack-format-spec.md` §2.2);
- Entitlement changes also carry provenance into the event stream (purchase order id / event id), enabling precise rollback on refunds.

## 3. Framework support for the four models

| Model | Mount point | What the player sees |
|---|---|---|
| Premium | Base entitlement bundle | One-time purchase in the app store |
| Content-pack DLC | Campaign / arc packs declare an entitlement gate | The campaign book card in the campaign entry (②) shows a "locked state" |
| Subscription | A periodic set of entitlements | Home promo slot + the subscription benefits area of the event center |
| Cosmetic / presentation items | Writes only cosmetic flags | Cosmetics page of the Inventory/Compendium (⑥), dice-skin slot |

### 3.1 Locked-state presentation rules

- Unlocked paid campaigns are **visible but locked** in the campaign entry — show the cover, synopsis and branch-collection progress instead of hiding them: let the content itself be the best sales page;
- The locked state is wrapped narratively (the same technique as forced modes), with no blunt "Not purchased" popup interrupting browsing;
- After purchase the entitlement is written to the Board immediately and the entrance unlocks on the spot, no restart.

### 3.2 Strategy choice and adjustment (per pack + operations side)

**Division of responsibilities (the key disambiguation)**:

| Side | Decides | Carrier | Stability |
|---|---|---|---|
| Content pack | **Gate**: which entitlements unlock this pack | manifest `entitlement.requires` (hard gate) + `monetization.strategies` (strategy participation declaration, see `../tech/02-content-pack-format-spec.md` §2.3) | Stable: travels with the pack version |
| Operations | **Lighting**: how entitlements are granted — pricing, purchase, subscription sets, event gifts, achievement rewards, limited-time free | The writers of entitlement variables (shop / events / achievements systems) | Variable: adjustable any time without a new pack version |

- One pack can participate in several strategies at once: e.g. once `Campaign X` declares `requires: [entitlement.campaign_x]`, operations can sell it directly (DLC), put the `campaign_x` entitlement into the subscription set (subscription), or light it free for a limited time (event) — **the content pack is completely unaware of all this**;
- **Acquired entitlements never downgrade**: tightening a strategy (e.g. free → paid) affects only players who haven't unlocked yet; no adjustment may revoke entitlements a player legitimately acquired (except via the refund flow, §5); loosening (e.g. DLC → included in subscription) takes effect immediately;
- Strategy adjustments go through operations review, not the content-pack pipeline — this is the boundary between operations-track (whitepaper §10.4) and content-track iteration;
- **Reclaiming limited-time grants**: limited-time lighting (event ttl) is set back to false on expiry by an **operations-side scheduled job**; the framework only guarantees "entitlement set false → entrance locks immediately, in-progress campaign may finish" (same philosophy as §5); the game runtime has no built-in countdown logic.

## 4. Monetization no-go zones (iron rules)

1. **Payment points never hang on check results** — the fairness of the dice is not for sale; any "pay to reroll" or "pay for a modifier" is permanently forbidden;
2. **Paid content never breaks the branch integrity of free paths** — a free player's campaign must be a complete story; paid packs add to it, they don't unlock its ending;
3. **Numeric power is not for sale** (if non-cosmetic goods are ever introduced, this rule must be re-reviewed);
4. Paid content packs go through **exactly the same** branch validation, namespace checks and screen-loop checks as free ones.

## 5. Relationship with the content-pack pipeline

- A paid content pack = an ordinary content pack + an entitlement-gate declaration; the pipeline, validation and versioning rules are reused entirely (whitepaper §10);
- The writers of entitlement variables (shop / events / achievements) are transparent to content packs — packs only read entitlement state;
- Refunds / entitlement revocation: after an entitlement variable is set false, an in-progress campaign is handled by **allowing the current campaign to finish but forbidding a new game** (same philosophy as the rule-pack freeze).

## 6. Relationship with the screen loop

- Monetization adds no global navigation items: shop capability lives inside three existing screens — the ① Home promo slot, the ② campaign entry locked state, and the ⑥ Inventory cosmetics page;
- **Home promo-slot content is delivered via operations config**: the `home_promo` block of `packs/_ops/ops_config.json` (copy + target jump pack_id/codex); if the config is empty the whole slot is hidden — no empty placeholder;
- Purchases complete in a half-screen sheet without leaving the current screen context (follows the sheet rules in doc 04 §3.3);
- The ⑨ Settlement screen has no monetization prompts whatsoever — the full stop at the emotional peak stays pure.

## 7. Launch monetization strategy (decided 2026-11-09)

**Free base game + content-pack DLC + cosmetic/presentation items**:

- Rationale: the game's core selling point is "the world keeps growing" (continuous content-pack delivery); a free base maximises first reach, and DLC is naturally isomorphic to the content pipeline; premium doesn't suit a continuous-delivery model, and subscription isn't enabled while content volume is too thin;
- Subscription is **not enabled this phase** (the subscription benefits area is not built either); re-review when the content stock reaches the subscription threshold (≥5 campaign packs);
- Mapping: campaign01 = free base; arena = DLC (live, demonstrating the full chain); cosmetic item slot = dice skins (completion reward for the "Treatise on the Fatedie" Compendium series, pure presentation);
- Cosmetic slot details (implemented 2026-11-09): skin registry = operations-side data file `packs/_ops/cosmetics.json` (isomorphic with the §2.3 entitlement registry — "lighting is operations' job": pricing, acquisition mapping and default skin are all registered on the operations side, with zero change to the content pipeline); Board keys = `global.cosmetic.*` (07 doc §3 v1.2 whitelist, system-write only); acquisition paths = completing the Treatise on the Fatedie (doc 10 §4) + a cosmetic item in the shop (launch placeholder "Salvage Bronze Glow", ¥6); purchase entrance = half-screen sheet on the ⑥ Inventory cosmetics page (inside the three existing screens of §6, no new global nav);
- No-go-zone review (the four rules of §4): all satisfied under this strategy — free path complete, no power sold, dice untouched, paid packs validated identically.

**English-market strategy (decided 2026-11-10; chosen per market, zero framework change)**: **free demo + one-time unlock** — Prologue + Act I free; one non-consumable purchase `entitlement.campaign01_full` unlocks Act II through the Finale and NG+; Arena is a separate small DLC (`entitlement.arena`); Riddle Maze and the arc_tide side arc are free; no cosmetics shop at launch. The gate is declared at act level with `entitlement.requires` (tech/02 §2.2); the narrative locked-state presentation is unchanged (§3.1); restore purchases is required; refunds follow §5 "finish the current run, no new run".
- Note: "free demo chapters" don't break §4 rule 2 — the free path (Prologue + Act I) is a complete demo unit in itself; payment unlocks the later content, not an ending.

## 8. Items to refine (in the operations project)

Pricing structure and regional differentiation, platform revenue share and compliance (minor protection, odds disclosure, etc.) are refined in the pricing project; the subscription benefits list is refined when subscription enablement is reviewed.
