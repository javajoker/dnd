# Store Listing — Age of the Codex: Ashenport Fragments (draft)

> For Google Play and the App Store, English market. Drafted 2026-11-10 from the campaign book and the English text in `game/packs/*/texts/en.json`. Placeholders are marked **[TBD]**.
> Wording rule: describe it as a "tabletop RPG" / "d20 RPG"; never use "D&D" or "Dungeons & Dragons" (trademark).

## Identity

| Field | Value |
|---|---|
| App name (≤30 chars) | Age of the Codex |
| Subtitle (iOS, ≤30) | A tabletop RPG in your pocket |
| Short description (Play, ≤80) | Roll the Fatedie, rewrite a fading city. A branching d20 story RPG. |
| Category | Games › Role Playing (secondary: Adventure) |
| Bundle / package id | **[TBD — replace `com.example.ageofthecodex` in `game/export_presets.cfg`]** |
| Languages | English, Simplified Chinese |
| Price | Free (with in-app purchases) |
| Contact email / website | **[TBD]** |
| Privacy policy URL | **[TBD]** — host `privacy-policy.md` |

## Full description

> This world is a book that is fading — and you are the only page that was never written.
>
> In the port city of Ashenport, whole streets are being *revoked*: wiped from the Scroll of All Things along with everyone's memory of them. You wake on the mudflats with no codex page in your arms. You are one of the Unwritten, and the Fatedie in your hand may be the last pen this city has.
>
> **A tabletop RPG built for one hand**
> • Every key choice is a d20 roll — and failure is never game over, it's another branch of the story.
> • Three factions want you: the Scriptorium that mends the Scroll, the Uninked who tear it up, and the Salvage Guild that profits from the pieces.
> • Your choices are written down: the History Scroll traces every result back to the roll that caused it.
> • Turn-based battles with a light d20 ruleset: advantage, saving throws, death saves, companions you control.
> • Four endings, a hidden one among them, and New Game+ that carries your story — never extra power — into the next playthrough.
>
> **Free to start**
> Play the Prologue and Act I free. One purchase unlocks the full campaign. No ads, no energy timers, and you can never pay to change a dice roll.
>
> Also inside: the Arena Gauntlet (an optional add-on), the Riddle Maze, and the side story *Echoes of Fog Wharf*.

## Keywords (iOS, ≤100 chars)

`rpg,tabletop,d20,story,choices,fantasy,turn based,dice,branching,narrative`

## In-app products

All are **non-consumable** (bought once, restorable). Prices are tier placeholders until set in the consoles.

| Product id | Unlocks (entitlement) | Price (placeholder) | Notes |
|---|---|---|---|
| `campaign01_full` | `entitlement.campaign01_full` — Act II to the Finale + New Game+ | $4.99 | The main unlock; shown on the locked-chapter screen |
| `arena_gauntlet` | `entitlement.arena` — Arena Gauntlet | $1.99 | Optional add-on on the Campaigns screen |
| `salvage_copper` | Dice skin "Salvage Bronze Glow" | $0.99 | Cosmetic; **not offered at the English launch** (no cosmetics shop) |

Product ids must match `shop.<key>.product_id` in `game/packs/_ops/ops_config.json`. A "Restore Purchases" button is on the Home help page and on the locked-chapter screen (required by App Store review).

## Screenshots

Capture with the screenshot driver in English, then upscale to each store's required sizes (6.7" iPhone 1290×2796, 6.5" 1242×2688, Play phone 1080×1920+):

| Shot | Command flag | Shows |
|---|---|---|
| Camp | `--home-shot` | Home illustration and menu |
| Story choice | `--m2n-shots` (dialog) | Branching dialogue with faction badges |
| Check | `--m2n-shots` (check) | d20 check button with DC and modifier |
| Battle | `--m3-shots` (battle) | Portrait battle |
| Ending | `--text-shots` (ending) | Ending text |
| Unlock | `--market=global --lock-shot` | Free demo end + unlock (optional) |

Example: `godot --path game -- --locale=en --home-shot`. The driver writes PNGs to `/tmp`; the window is 390×760, so for store sizes run with a larger window or render at 3× before submission **[TBD]**.

## Age rating (questionnaire answers)

| Topic | Answer |
|---|---|
| Violence | Mild fantasy violence: turn-based battles against ink creatures; no blood, gore or realistic violence |
| Fear / horror themes | Mild: people and places "fade" from existence (non-graphic) |
| Language, sexual content, drugs, alcohol, tobacco | None |
| Gambling / simulated gambling | **No.** Dice are a game mechanic; nothing purchasable is random, no loot boxes, no real-money wagering |
| In-app purchases | Yes (non-consumable unlocks) |
| User-generated content / chat / sharing location | None |
| Ads | None |
| Expected rating | ESRB E10+ / PEGI 7 / IARC 7+ / App Store 9+ (confirm via the questionnaires) |

## Pre-submission checklist

- [ ] Set the real bundle/package id and app icons (`game/export_presets.cfg`, launcher icons)
- [ ] Create the products above in Play Console and App Store Connect; set price tiers; update `ops_config.json` English `price_text` (or read localized prices from the store at runtime)
- [ ] Integrate the billing plugins per `billing-adapter.md`; test with Play license testers and App Store sandbox accounts (purchase, cancel, restore on a second device, refund)
- [ ] Host the privacy policy and fill in the Play Data safety form / App Store privacy labels from `privacy-policy.md`
- [ ] Internal testing track (Play) and TestFlight build; real-device pass from TASKS P4 Phase 3
