# Code Review and Checklist Verification · game/ · 2026-11-10

> Scope: the Godot project `game/` (core / shell / main / tools / tests / packs) checked against the design docs and against the status claimed in `framework/03-TASKS.md`, `framework/13-feature-checklist-and-loops.md` and `framework/14-presentation-and-platform-checklist.md`.
> Method: read the code paths behind each claim; ran the headless suite, packlint on all four packs, and the bot simulation; ran the acceptance-skill grep scans; probed layout headlessly. Format follows the `godot-acceptance` audit-report template.
> Engine: Godot 4.7.2.stable (local), GDScript, ~14.5k lines of game code + a 6.5k-line test file.

## Verdict: **Conditional pass for the framework core; fail for "launch-ready"**

The logic core is genuinely well built: clean RefCounted layering, seeded RNG, provenance on every Board write, data-driven packs with a real validator, and a bot simulation that reaches every node. But several items marked ✅ in the checklists are only true inside the headless test harness. A player on a real phone would hit three blockers: (1) progress is never loaded after relaunch, (2) landscape mode never rotates the device, (3) every new game rolls the same dice.

---

## 1. Evidence (what was run)

| Check | Result |
|---|---|
| Headless suite `godot --headless --path game -s tests/run.gd` (81 s) | **1568 PASS / 4 FAIL**, exit code 1 (the runner calls `quit(1)` correctly) |
| packlint campaign01 / arena / riddle_maze / arc_tide | 0 FAIL in all four; **13 WARN** in campaign01, 2 in arena |
| `tools/simulate.gd` (24 seeds) | All assertions green: 45/45 nodes covered, endings E1:1 / E2:2 / E3:10 / E4:11, check pass rate 69% |
| Iron-rule scan: `extends Node` / `Input.` / `@onready` / `SceneTree` in `core/` | Clean |
| Iron-rule scan: raw `randi()` / `randf()` outside `rng.gd` | Clean |
| Iron-rule scan: shell writes to Board | `shell/` clean, but **`main.gd` and `subgame_runner.gd` write the Board directly** (11 call sites; they sit outside `shell/`, so the grep in the skill misses them) |

### The 4 test failures

| Test | Cause | Kind |
|---|---|---|
| `M3 core/ git diff is empty` (`tests/run.gd:3499`) | Runs `git diff ec946ef ad46102`; those commits don't exist (the repo has a single `init commit`) | Test depends on history that isn't in this repo; remove it or replace it with a static check |
| `real input: fallback bar button → navigate` and 2 toggle tests (`tests/run.gd:5956`) | `ScreenHome` reads the **real** `user://settings.cfg`, which holds `home_bar_collapsed=true` from an earlier run, so the bar starts hidden and the click lands on nothing | Test-isolation bug: the test must set `home.settings_path` to a temp file like the juice/audio tests do |

---

## 2. Blocking defects (must fix before any device build)

> **Status 2026-11-10: B1, B3 and B4 are fixed (TASKS P4 Phase 0); the suite is 1583 PASS / 0 FAIL. B2 remains (Phase 3).**

### B1 · Saves are written but never loaded — `main.gd` ✅ fixed
`SaveSystem.read()` is never called outside tests. `main.gd:_ready` always builds a fresh `Board`. On relaunch, `_has_continuable()` (`main.gd:1396`) returns true because `has_save()` finds the file, so Home shows **"Continue"**, but `_on_campaign_start` sees an empty `visit_log` and starts a new campaign from N0-1. Every session's progress is lost when the app closes.
- Contradicts: PRD F6.1, doc 07 §4 (snapshot timing / migration chain), doc 13 §9 "Save snapshots ✅", TASKS TP4 "SaveSystem ✅".
- Fix: on launch, `SaveSystem.read()` → `migrate()` → `apply()` → `graph.deserialize(meta.graph)`; add a test that runs two `main` instances against the same temp slot.

### B2 · Landscape mode is a desktop window resize — `main.gd:252`
`_set_window_orientation` only sets `get_window().size` to 1280×720. On iOS/Android that does nothing; the device stays in portrait. There's no `DisplayServer.screen_set_orientation()`, no `display/window/handheld/orientation` setting, no safe-area handling (notch / home indicator), no handling of `NOTIFICATION_APPLICATION_PAUSED` (doc 09 §7 promises auto-pause on calls/backgrounding), and no Android back-button handling.
- Contradicts: the dual-form promise (whitepaper §7, PRD F1) on the target platform; doc 13 rates every landscape item ✅.

### B3 · Fixed RNG seed for every new game — `main.gd:22,110` ✅ fixed
`rng = Rng.new(BATTLE_SEED)` with `BATTLE_SEED := 20260009` ("this slice's two main-line checks are both success paths"). Every install, and every new campaign within a session, replays the identical dice sequence. Combined with B1, every player's first run is the same run. This undermines the core experience goal ("the ritual of the roll", PRD §3) and the "dice fairness" pillar.
- Fix: seed from `Time.get_unix_time_from_system()` / `randi()` once at new-game time, store it in the snapshot (already supported), and keep fixed seeds only for tests/tools.

### B4 · Tests destroy the real player's data ✅ fixed
`tests/run.gd:5156` deletes `user://saves/slot1.json` (the real default slot), and `test_home_real_input` reads and writes the real `user://settings.cfg`. Running the suite on a dev machine wipes the developer's own save and changes their preferences — and it is the cause of three of the four failures in §1.
- Fix: give `SaveSystem` and `UiSettings` an injectable base path, and have every test use `user://test/…`.

---

## 3. Major findings

### M1 · Framework and content are not decoupled in code (whitepaper §2 pillar 1)
- `core/graph/story_graph.gd:230` hard-codes `GOLD_KEY := "campaign01.gold"` and `GOLD_START := 30` — in the **logic core**.
- `core/save/save_system.gd:81-99` migration hard-codes `campaign01.*` keys.
- `main.gd` hard-codes `PACK_DIR = res://packs/campaign01`, `global.mode_choice.campaign01`, `campaign01.cleared`, `campaign01.ngplus`, node ids `N1-1`/`N4-*`, and pack-specific key filters (`main.gd:888`, duplicated in `shell/ui/story_vm.gd:144`).
- Consequence: "a new campaign = a new content pack, no framework change" isn't true yet; campaign02 would require editing core and main. Sub-games and side arcs *are* data-driven (`_discover_subgames`, `graft`), which shows the pattern works.
- Fix: move gold key / starting gold / settlement-exempt keys into manifest fields; derive the campaign pack from a catalog instead of a constant.

### M2 · `main.gd` is an 1,861-line god object (shot drivers moved to `tools/shot_driver.gd`; split still open)
It holds campaign flow, sub-game flow (a second copy of maze/battle/settle/save-quit logic, `_sub_*`), save timing, entitlements, cosmetics, and ~450 lines of screenshot/demo drivers (`_run_shots_*`, 16 CLI flags) that call private core methods (`graph._enter("N1-3")`) and write fake events into the stream. The demo code ships in the production main scene.
- Fix: split into `CampaignFlow`, `SubgameFlow` (sharing one encounter/settle flow), `AppServices`; move shot drivers to `tools/`.

### M3 · Campaign-book flags are written but never read (packlint V4 WARN ×13)
`seen_fading`, `blank_memory`, `page_tearer`, `insider`, `failed_to_hold` are written by nodes but read by **no** edge, text variant or code. The campaign book promises reads at R2 (dialogue bonus), E1 (cutscene variation), the Finale (tax collector absent), N3-1 (extra opening line) and E4 — and §10 marks "flags closed-loop ✅". Players' choices at those points currently have no visible consequence. packlint downgrades it to WARN ("needs manual check") so it never fails CI.
- Fix: add the `text_variants` / edge conditions (the mechanism already exists), then promote V4 "declared reader not found" to FAIL.

### M4 · Effect-modifier pipeline not implemented (tech/04 §5)
No `EffectEngine`, no `effect.attach`/`effect.expire` events, no base→add→mul→override→clamp. Correctly recorded as a known gap in TASKS; no current pack uses it. It blocks the Standard rule tier and any item with a passive modifier.

### M5 · Localization is not ready for an English build
- Core emits **Chinese prose into the event stream** (`maze_runner.gd:43,90,109,111`, `encounter_sm.gd:583,717`, `story_graph.gd:288` …). The stream is persisted in saves and replayed in the History Scroll, so the text is baked into save files in one language. Events should carry a message key + params and let the shell localise.
- UI strings live in one `TextsZh` class, referenced by name from ~25 shell files; there's no locale switch.
- Pack JSON holds ~460 inline Chinese strings (edge labels, item/skill/enemy names, riddle hints); only campaign01 long text (52 keys, 4,322 chars) is externalised via `text_ref`.
- The 20-character `label` limit (doc 08 §1) and fixed button widths were sized for CJK; English is ~2–3× wider.
- Fonts: 2 × Noto Sans SC OTF = **16 MB**, the biggest download item; an English build needs a Latin face (~200 KB).

### M6 · Doc and code disagree on the gesture scope (docs fixed)
`game/README.md` says gesture phase 1 is "tap only" and that other gestures must not appear in player-facing help (M2 audit G3), while doc 13 says the full vocabulary is implemented and the help page shows the full 12 §1 table. The code (`gesture_layer.gd`, `gesture_recognizer.gd`) and tests support doc 13, so the README was stale; it has been corrected.

---

## 4. Minor findings

- **Package size**: BGM shipped as uncompressed 16-bit WAV (2 × 2.6 MB for 30 s loops); use Ogg Vorbis (~10× smaller).
- **No export presets**: `export_presets.cfg` is gitignored and absent; no Android/iOS build has been produced or tested (doc 14 phase 3 is honestly unchecked).
- **Doc index was stale** (fixed): `docs/README.md` listed riddle-maze as "not started" though it is live; `game/packs/README.md` listed only campaign01 and arena.
- **Assertion counts in docs are stale** (TASKS 1311, doc 13 "967", doc 14 "1572 all green"); the suite is 1572 checks with 4 failing.
- **One 6,564-line test file** with 109 test functions and no per-test isolation; a crash in an early test aborts everything after it. Split it per module and add a filter argument.
- **Shell knows pack-private keys** (`story_vm.gd:144` filters `campaign01.*` keys out of the settlement summary) — breaks "renderers are content-agnostic".
- **Docs claim compile-time layering** (tech/01 §3 "reverse references impossible by construction"); GDScript has no assemblies, so it's enforced only by grep. Add `main.gd` / `subgame_runner.gd` to the grep or route their writes through a core API.
- **Character tab mentions spell slots** (doc 04 §④.5 / ⑦) though the Light rules have none; the code shows skill uses, which is right — the doc should follow.

## 5. What is genuinely solid (keep)

- `core/` really is engine-free and fully headless-testable; the grep scans are clean.
- Board: namespace permissions, clamping with `clamped` events, mandatory provenance (missing provenance is rejected with an error, verified in the test log).
- packlint V1–V14 shares evaluator code with the runtime; negative tests prove each rule fails when it should.
- Dual-shell byte-identical event streams (`tools/shell_diff.gd`) and the monetization no-go assertions (cosmetics and entitlement switches leave the event stream unchanged).
- The Light rules match doc 11: 2d20 advantage, nat-20 crit doubles dice not modifiers, saves with half/none, HP = 10 + 2×level + Might via `hp_bonus`, death saves best of three.
- Sub-games and side arcs are data-driven end to end (`pack_type=subgame` discovery, `graft` injection into a merged view).

---

## 6. Checklist verification (claimed → verified)

| Checklist item | Claimed | Verified | Note |
|---|---|---|---|
| TASKS TP0 logic core | ✅ | ✅ | |
| TASKS TP1 simulation, all endings | ✅ | ✅ | 24-seed run reproduced |
| TASKS TP2/TP3 shells, byte-identical streams | ✅ | ✅ (desktop/headless) | Landscape on device: ❌ (B2) |
| TASKS TP4 SaveSystem | ✅ | ⚠️ | Writes and migrates; **never loads on launch** (B1) |
| TASKS P1.2 flags closed loop | ✅ | ❌ | 5 flags with no reader (M3) |
| TASKS P1.2 full playthrough | ✅ | ⚠️ | Playable in one session; can't resume across sessions; fixed seed (B3) |
| TASKS P2 "new campaign without framework change" (implied by the whitepaper) | ✅ | ❌ | campaign01 hard-coded in core and main (M1) |
| TASKS P2 go-live checklist V1–V14 | ✅ | ✅ | 0 FAIL ×4 packs |
| Doc 13 §8 interruption / auto-pause (09 §7) | ✅ | ❌ | No pause/background handling |
| Doc 13 §9 save snapshots | ✅ | ⚠️ | See B1 |
| Doc 13 §12 headless tests | ✅ | ⚠️ | 4 failing (§1) |
| Doc 13 §5 gestures | ✅ | ✅ | README is stale (M6) |
| Doc 14 #1 font | [x] | ✅ for Chinese | Needs a Latin face for English (M5) |
| Doc 14 #2–#8 presentation | [x] | ✅ | Verified by tests; not checked on a device |
| Doc 14 #9–#16 platform / ops | [ ] | [ ] | Correctly unchecked |
| E-5 localization | "doesn't block" | ❌ for English | See M5 |

Both the Chinese and English checklists (TASKS, 13, 14) have been updated to these verified statuses, and the fixes are scheduled as TASKS P4.

## 7. Recommended fix order

1. B4 test isolation (cheap; makes everything else measurable) → remove the git-SHA test.
2. B1 load-on-launch + B3 per-game seed.
3. M1 de-hard-code campaign01 (manifest fields + pack catalog) and M2 split `main.gd`.
4. B2 mobile platform layer: orientation API, safe area, pause/resume, back button, export presets, first device build.
5. M5 i18n layer (message keys in events, locale tables, Latin font) — prerequisite for the English game.
6. M3 wire the orphan flags; promote V4 to FAIL.
