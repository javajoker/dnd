# game/ — The Age of the Codex · Godot project

> 中文版：[`README.zh-CN.md`](README.zh-CN.md).
> Workflow and iron rules: `.claude/skills/godot-dev/SKILL.md` (English: `.claude/skills/godot-dev-en/SKILL.md`) — read before every task
> Acceptance audit: `.claude/skills/godot-acceptance/SKILL.md` (English: `godot-acceptance-en`)
> Design truth: `../docs/` (framework design / tech contracts / story content); English mirror in `../docs/en/`

## Environment

- Godot 4.7.2: `/Applications/Godot.app/Contents/MacOS/Godot` (GDScript channel, tech/01 E-1 decision)
- Headless tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tests/run.gd` (exit code 1 on any failure)
- packlint: `… --headless --path game -s tools/packlint.gd -- packs/<pack_id>`
- Bot simulation: `… --headless --path game -s tools/simulate.gd [-- <seed count>]`

## Structure

| Directory | Responsibility | Iron rule |
|---|---|---|
| `core/` | Logic core: Board / event stream / story graph / encounter state machine / rule pack / saves | RefCounted only, zero engine dependencies |
| `shell/` | Rendering shells: nine screens + portrait temporal / landscape spatial forms | Consume the event stream only; read the Board only |
| `packs/` | Content-pack runtime copies (tech/02 §1 layout); packaged as PCK for release | Data-driven, no logic |
| `tools/` | packlint (V1–V14) / simulate (bot simulation) / winrate / shell_diff / asset generators | Command line, reuse core evaluation code |
| `tests/` | Headless tests | Assertions grow with features |

## Technical prototype roadmap (tech/01 §10)

TP0 logic-core skeleton → TP1 campaign01 simulation of every ending → TP2 single-encounter portrait shell → TP3 dual-shell event-stream consistency → TP4 minimal nine-screen loop.

## Gesture layer

The full doc 12 §1 vocabulary is implemented (`shell/ui/gesture_recognizer.gd` / `gesture_layer.gd`, shared by both shells): tap, long-press, drag, drag path, swipe, two-finger tap, pinch. Iron rule unchanged: every gesture has an equivalent button path (12 §1).

## Known open issues

See [`../docs/en/tech/code-review-2026-11-10.md`](../docs/en/tech/code-review-2026-11-10.md): B1/B3/B4 are fixed (P4 Phase 0); still open: landscape mode only resizes a desktop window (B2), campaign01 hard-coding (M1), localization (M5).

Screenshot tool: `godot --path game -- --home-shot` (flag table in `tools/shot_driver.gd`). Extra flags: `--seed=N` (reproduce a game), `--locale=en|zh-CN` (language), `--safe-area=top,right,bottom,left` (simulate a notch).

## Exporting

Presets live in `export_presets.cfg` (Android AAB, iOS, and a "Desktop PCK check"). Signing keys are never committed — pass them via `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `_USER` / `_PASSWORD` or the editor. Without export templates you can still verify the package:

```bash
godot --headless --path game --export-pack "Desktop PCK check" build/check/game.pck
```

A full device build needs the Godot 4.7.2 export templates, plus the Android SDK/JDK (Android) or full Xcode (iOS). The fix plan is TASKS P4 (`../docs/en/framework/03-TASKS.md`).
