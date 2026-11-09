# English Mobile Release — Decision Record and Plan

> Status: decided 2026-11-10. Inputs: `code-review-2026-11-10.md` (current state of `game/`), framework docs 01/04/06/09/12, tech/01–05.

## 1. Decisions

| Question | Decision | Consequence |
|---|---|---|
| Content scope | **All current content**: campaign01 (Prologue–Finale, E1–E4, NG+), arc_tide, Arena, Riddle Maze | No new game design; the work is engineering + English writing |
| Orientation | **Portrait-first v1**; landscape spatial form in v1.1 | Campaigns declared `choice` resolve to `time` on v1; the landscape shell stays in the codebase behind a flag, and the Campaign Entry mode cards show landscape as "coming soon" (or are hidden) |
| Business model | **Free demo + one unlock**: Prologue + Act I free; one non-consumable purchase unlocks the full campaign (Acts II–Finale + NG+); Arena stays a small separate DLC; Riddle Maze and arc_tide free | Maps onto the existing entitlement model without framework changes (see §3.4); no cosmetics shop at launch |
| Build | **One bilingual build** (zh-CN + en) with an in-game language setting | Requires a real i18n layer in core, shells and packs |

## 2. Market notes for the English build

- Don't use "D&D" or "Dungeons & Dragons" in the store listing or in-game; say "tabletop RPG" / "d20". The Light rules are original, so no SRD licensing is needed.
- The China-specific compliance items in doc 14 #10 (real-name verification, ISBN licence) don't apply; English-market needs are a privacy policy, store data-safety forms, age rating (IARC / App Store), and restore-purchases.
- Fonts: ship a Latin face (e.g. an OFL serif/sans, ~200 KB) as the default for `en`; load Noto Sans SC only for `zh-CN` (it's 16 MB today).

## 3. Plan

Phases are ordered by dependency; each ends with the headless suite green and packlint 0 FAIL.

### Phase 0 — Fix the blockers from the code review
1. Test isolation (B4): injectable paths for `SaveSystem` / `UiSettings`, tests on `user://test/…`; replace the git-SHA test.
2. Load on launch (B1): read → migrate → apply → graph.deserialize; "Continue" really continues; a cold-start test.
3. Seed per new game (B3); fixed seeds only in tests/tools.
4. Move the `_run_shots_*` drivers out of `main.gd` into `tools/`.

### Phase 1 — Decouple and localise the engine
1. De-hard-code campaign01 (M1): gold key / starting gold / settlement-exempt keys from the manifest; the campaign pack comes from a pack catalog.
2. Message keys in events (M5): core emits `{ "msg_key": "...", "args": {...} }`; the History Scroll, logs and toasts resolve them in the shell. Save migration v2→v3 converts old prose logs (keep them as opaque text).
3. Locale tables: replace `TextsZh` with `Texts` + `texts/zh-CN` and `texts/en` tables; a `ui.locale` setting (default from the OS locale).
4. Pack text: locale-independent `text_ref`; add keys for short fields (`title`, `summary`, `label`, `name`, `hint`); packlint V15 = every key exists in every shipped locale.
5. Layout pass for English length: buttons/labels autowrap or shrink-to-fit; revise the 20-character label rule (doc 08 §1) to a width-based rule.

### Phase 2 — English content
1. Extract all strings to `en.json` per pack + the UI table (estimate: ~460 short pack strings, ~300 UI strings, 52 long texts ≈ 4.3k Chinese characters → roughly 15–20k English words with the narrative prose).
2. Translate using `docs/en/GLOSSARY.md` for names; an English edit pass for tone (prose, not literal translation); riddle text in Riddle Maze needs rewriting, not translation (the puzzles depend on wording).
3. Wire the 5 orphan flags (M3) while the text is open — they need English and Chinese variant text anyway.

### Phase 3 — Mobile platform layer (portrait)
1. `display/window/handheld/orientation = portrait`; landscape gated behind a feature flag.
2. Safe-area insets (notch / home indicator) for the three-band layout and full-screen takeovers.
3. App lifecycle: pause on `NOTIFICATION_APPLICATION_PAUSED`, idle-save on background, resume; Android back button = ☰ menu / back.
4. Export presets for Android (AAB) and iOS; include the PNG/WAV files read via `load_from_file`; convert BGM to Ogg.
5. Real-device pass: gesture thresholds, 44 pt targets, text legibility, performance on a low-end Android.

### Phase 4 — Store and monetization
1. Entitlements: `entitlement.campaign01_full` (gates Acts II–Finale via the existing `entitlement.requires` mechanism, applied at the act level), `entitlement.arena`.
2. IAP plugins: Google Play Billing and StoreKit 2 through Godot's official plugins; receipt handling, restore purchases, refund → existing "finish current run, no new run" rule.
3. The locked-state presentation already exists (doc 06 §3.1); add English narrative lock text.
4. Store assets, privacy policy, age rating, a TestFlight / internal-testing track.

### v1.1 — Landscape spatial form
Real orientation switching via `DisplayServer.screen_set_orientation`, landscape safe areas, tactical-grid tuning on device, then turn the mode choice back on.

## 4. Framework doc changes (applied in both languages)

- Doc 06 §7: English-market strategy (free demo + one-time unlock) added beside the Chinese launch strategy.
- Doc 07 §4.2: "load on launch" snapshot timing.
- Doc 08 §1: label limit judged by rendered width in every language.
- Doc 09 §8: form switching = device orientation; v1 portrait-first.
- tech/01: per-game seeding (§5.2), thin app layer and no content constants (§3), mobile platform layer (§10.1), E-5 decided (bilingual build, msg_key events).
- tech/02: locale-independent `text_ref` and keyed short fields (§1.1), act-level entitlement gate (§2.2), strict V4, new V15 text completeness (§12).
- Doc 14: items 12a (mobile platform layer) and 12b (bilingual build).
- TASKS: verified statuses and the P4 English-release checklist.
