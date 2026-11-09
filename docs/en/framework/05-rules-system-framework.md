# Rules System Framework (Rule Packs)

> Version: v1.0 (final, P0.8 review passed)
> Related docs: `01-framework-whitepaper.md` §11, `02-PRD.md` F7; the first Light rule pack's details are in `11-light-rulepack-v1.md`
> Scope: defines the abstract model of rule depth as a framework extension axis. Concrete numeric design is in `11-light-rulepack-v1.md`.
> English mirror of `docs/framework/05-规则系统框架.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Positioning

Rule depth is not a one-shot product decision but an **extension axis** of the framework:

- The framework only fixes the D20 minimal core; all other rules are carried by **rule packs**;
- A rule pack is a kind of content pack and can be released and versioned independently;
- Different campaigns / sub-games can bind rule packs of different depths and coexist on the same framework;
- **The first main campaign launches on the Light rule pack** (direction decided); later packs can introduce deeper rules without changing the framework.

## 2. The D20 minimal core (shared by all rule packs)

These three items are the immutable part of the framework; no rule pack may bypass them:

1. **D20 check**: roll + modifier vs difficulty, producing success/failure branches — the check edge of whitepaper §5;
2. **Event-stream output**: the results of every rule resolution are output as events; the rendering layer, History Scroll and achievement system consume only the event stream;
3. **Board reads/writes**: rule packs may affect story branches only by reading and writing Board variables, never by touching story nodes directly.

## 3. The six elements of a rule pack

A rule pack must fully define all six of the following elements:

| Element | Content | Light-rules example (directional) |
|---|---|---|
| Attribute model | Which numeric dimensions a character has | 3 attributes (Might / Finesse / Wits) + HP |
| Check formula | How modifiers are computed and difficulty calibrated | Modifier = attribute value; three difficulty tiers (easy / medium / hard) |
| Action economy | What can be done each turn | Move + action + bonus, three parts |
| Combat round structure | Initiative, round loop, win/lose conditions | Initiative = Finesse check; turns rotate |
| Growth curve | What leveling up grants | +HP per level, unlock 1 skill slot |
| Death and failure | What happens at zero | Death saves best of three; allies can revive |

## 4. Three rule-depth presets

| Tier | Audience | Attribute model | Action economy | Signature systems |
|---|---|---|---|---|
| Light | Launch main line, short-session players | 3 attributes + HP | Three-part | No spell slots; use-limited skills |
| Standard | Core RPG players | 6 attributes + HP + proficiencies | Three-part + reactions | Status-effect system, skill trees |
| Deep | Tabletop enthusiasts | 5e-like full attributes | Full action economy | Spell slots, saving throws, feats, advantage/disadvantage |

- The three tiers are **preset templates**; content packs can tweak them (e.g. a hybrid "Light + spell slots" tier);
- Tiers don't need upward compatibility — a campaign that binds a tier runs on that tier;
- A new tier = a new rule-pack template, reviewed through the content-pack pipeline.

## 5. Binding model

- **Campaign-level binding**: every campaign book declares the rule-pack ID and minimum version it needs; it is loaded as declared on entry;
- **Sub-games**: may carry their own rule pack (variant rules), and also go through the six-element completeness check;
- **Coexistence**: in the same save, different campaigns can each run their own rule pack — the Board's variable types are the common language; rule packs are just different "dialects" for reading and writing;
- **Party data bridging**: when a character is carried across campaigns, the attribute mapping table declared by the rule pack handles the conversion (e.g. the rule for folding the Deep tier's 6 attributes into the Light tier's 3); the mapping table ships with the rule pack.

## 6. Relationship with other framework layers

| Framework layer | Relationship |
|---|---|
| World State Board | Rule packs read/write the Board; variable types are fixed and don't change with rule depth |
| Event Stream | Event streams from different rule packs share one format; only the source of numbers differs |
| Dual-form rendering | **The rendering layer is unaware of the rule tier** — one renderer serves every rule pack |
| Screen loop | The Character screen (⑦) shows the field set of the current campaign's rule pack dynamically |
| History Scroll | Check details show "rule-pack name + formula" to keep everything traceable |

## 7. Versioning and iteration

- Rule packs have their own version numbers, decoupled from framework and content-pack versions;
- When a rule pack upgrades: **an in-progress campaign can be frozen on the old version to finish**; new games default to the new version;
- Players can see the rule-pack version badge of the campaign at its entrance;
- When a rule pack reaches end of life (EOL), existing in-progress campaigns must still be finishable — the freeze mechanism is a hard guarantee.

## 8. The first Light rule pack (final: light v1)

Details are finalised in `11-light-rulepack-v1.md`: 3 attributes (-1 to +3), three difficulty tiers (DC 8/12/16), three-part action economy, use-limited skills, death saves best of three, a level 1–4 growth curve; the direction of presenting classes as "skill-combination bundles" is kept.

## 9. Open items

- ~~Concrete numeric tables for the Light rule pack~~ (finalised: `11-light-rulepack-v1.md`);
- A full specification for attribute mapping tables (must be frozen when the first cross-rule-pack campaign appears);
- ~~Advantage / disadvantage~~ (now in the Light rules core, doc 11 §3.1: 2d20 take highest/lowest, sources declared by content packs).
