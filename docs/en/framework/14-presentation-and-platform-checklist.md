# Presentation and Platform Checklist (productisation roadmap)

> Version: v0.1
> Related docs: `13-feature-checklist-and-loops.md` (framework feature baseline), `06-monetization-framework.md` §8, PRD §7
> Note: the productisation gap list once the framework features (doc 13) are all ✅. Principle: **all presentation work is shell work and never touches the logic core** (the event stream is the only input — presentation just hooks onto it). Status: `[ ]` not started / `[~]` in progress / `[x]` done
> English mirror of `docs/framework/14-表现层与平台化清单.md` (change history omitted). Terms follow `../GLOSSARY.md`.

---

## Phase 1: Presentation · hard defects and core ritual (P0)

| # | Item | Content | Acceptance | Status |
|---|---|---|---|---|
| 1 | Font fix | Bundle a CJK font (Source Han Sans / Noto Sans SC, OFL) as the default theme; eliminate tofu glyphs | Strings render at normal width; re-captured screens show no tofu | [x] for Chinese (04 §7 three sizes finalised); an English build needs a Latin face — the two Noto Sans SC files are 16 MB |
| 2 | 3D physical dice presentation | Key checks: a 3D D20 with physical bounce + slow-motion freeze; normal quick rolls get an upgraded tray animation; deliver the "Fatedie ritual" | Key-check presentation feels physical, long-press to skip, event stream unchanged | [x] (09 §6 / 04 §3.2; the face that lands on top = the given result, asserted per value — physics plays no part in the outcome) |
| 3 | Hit-feel trio | Floating damage numbers (crits bigger and gold), hit flash/knockback, kill dissolve particles | All three in, both shells driven by the same events | [x] Frozen parameters: numbers float up + fade 0.8 s; crit gold ×1.6 with a "Critical" tag; heals green +N; misses grey "Dodged"; hit flash one frame + 6 px spring-back; kill = 12 ink shards + 0.5 s fade; both shells use the same JuiceLayer/JuiceConfig; event stream byte-for-byte unchanged |
| 4 | Tiered screen shake | Small shake on hit, big shake on crit / death save | Tiered triggers, can be turned off (setting) | [x] Frozen parameters: hit 2 px / 0.15 s, crit or death save 5 px / 0.3 s; toggle `ui.screen_shake` in `user://settings.cfg`, on by default, switchable from the ☰ menu; a UI preference, not written to the Board |

## Phase 2: Presentation · atmosphere (P1)

| # | Item | Content | Acceptance | Status |
|---|---|---|---|---|
| 5 | Audio framework | BGM in four states (camp / explore / battle / ending) + SFX bus (dice / hit / page / UI) + volume settings | Framework plays; switching driven by the state machine | [x] Frozen parameters: four buses Master/BGM/SFX/Ambient (BGM/SFX/Ambient feed Master); BGM states driven by the event stream — node.enter (hub → camp, battle nodes don't switch, others → explore) / combat.start → battle / state.entered(settle) → explore / story.ending → ending; 1.0 s A/B crossfade, the same track doesn't restart; SFX mapping check.roll → roll then land after 0.45 s, battle.attack hit → hit / crit → crit (not stacked, miss is silent), item.use healed>0 → heal, page/UI clicks called directly from the shell; Master/BGM/SFX sliders in ☰ (`ui.vol_*`, UI preferences not on the Board); missing files fail silently and are only counted |
| 6 | First audio assets | Harbor tide ambience, dice, hit, page-turn, BGM ×2 | Audible in game | [x] `game/tools/gen_audio.py` synthesises everything in Python with zero third-party copyright, reproducible (fixed seed 20261109), 44.1 kHz 16-bit mono ×10: tide_loop 9 s / dice_roll 0.5 s / dice_land 0.18 s / hit 0.22 s / crit 0.35 s / heal 0.6 s / page 0.28 s / ui_click 0.09 s / bgm_camp and bgm_battle 30 s each; loops are quantised to whole periods with head-tail crossfade for seamless looping; Home plays tide_loop continuously (Ambient bus); explore/ending BGM temporarily share bgm_camp — adding assets only changes the BGM_ASSETS table |
| 7 | Art pipeline | Atlas rules (naming / resolution tiers / Lore illustration slots), first batch of character portraits and enemy units, layered upgrade of the Home painting | Pipeline doc + first assets live | [x] Pipeline spec finalised in tech/05 *Art Pipeline*: directories `assets/art/{units,portraits,scenes,icons}`, naming `<class>_<id>_<tier>.png`, tiers units 64/128 · portraits 128/256, phase-1 filter on (smooth), silent color-block fallback for missing art, `art_ref` isomorphic with `text_ref` (pure presentation reference). `tools/gen_art.py` (standard library only) procedurally generates the first 6 assets (512 supersample → 128 box filter, fixed seed 20261109): Ink Imp / Ink Fiend / Page Warden unit art + the Unwritten / Kelan / Old Fei portraits. Core only passes data through (BattleDef + party_status, zero rendering API); both shells share one ArtLoader; the Home painting gains procedural layered detail driven by data tables and fading with the Doom Clock |
| 8 | Transitions and camera | Screen transition animations; battle follow camera with push/pull | No more hard cuts | [x] Frozen parameters in `shell/ui/transition.gd`: fade out / in 0.25 s each, curtain uses IGNORE so input still works during transitions, rapid successive switches settle the previous one instantly, encounters slide in 36 px upward with the fade-in. `shell/ui/battle_camera.gd`: focus pan 0.35 s, single-axis pan ≤ 30% of the visible area, push ×1.12 in 0.18 s + pull back 0.22 s (0.40 s ≤ 0.5 s total), spring-back 0.30 s; follow = turn.start.actor; push/pull = battle.attack crit / combat.start with a boss, same event source as Juice, zoom only (screen shake has a single source, JuiceLayer); pinch sessions take camera priority; both shells share the component and parameters; event stream byte-for-byte unchanged |

## Phase 3: Platform (P2, required for store release)

| # | Item | Content | Acceptance | Status |
|---|---|---|---|---|
| 9 | Payment SDK | Real IAP (purchase / refund / receipt validation) replacing the mock | Full sandbox flow | [ ] |
| 10 | Compliance | Identity verification, minor protection, privacy policy; licence (ISBN) assessment for mainland China | Compliance checklist passes review | [ ] |
| 11 | Accounts and cloud saves | Account system + cloud save sync (snapshots are already structured) | Continue on multiple devices | [ ] |
| 12 | Crash monitoring | Crash reporting, performance monitoring | Queryable in a backend | [ ] |
| 12a | Mobile platform layer | Device orientation API, safe area, pause/resume, back button, export presets, audio compression (tech/01 §10.1) | Playable on real Android/iOS devices | [~] implemented, device verification pending |
| 12b | Bilingual build | Event msg_keys, locale tables, pack text keys, English layout widths (tech/01 E-5) | Switch zh/en with no overflow on any screen | [x] |

## Phase 4: Operations tech (P3, prerequisite for M4)

| # | Item | Content | Acceptance | Status |
|---|---|---|---|---|
| 13 | Analytics | Event stream → analytics reporter (a naturally structured data source) | Key funnels queryable | [ ] |
| 14 | Remote config / hot update | Remote PCK delivery + remote ops_config overrides | Config changes take effect without a release | [ ] |
| 15 | A/B experiments | Dual-mode choice distribution, difficulty curve (PRD §7 metrics) | Experiment groups readable | [ ] |
| 16 | Package size and loading | PCK split-download progress UI, splash screen | Downloads and plays over a real network path | [ ] |

## Other known gaps (tracked)

- Real-device matrix and touch-feel validation (gesture parameters / hot zones under real thumbs);
- Headless screenshot channel (CI visual regression);
- tech/04 §5 effects modifier runtime pipeline (must land before the first pack that uses it).
