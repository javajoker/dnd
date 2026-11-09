# game/ — The Age of the Codex · Godot project

> English version of [`README.md`](README.md).
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

See [`../docs/en/tech/code-review-2026-11-10.md`](../docs/en/tech/code-review-2026-11-10.md): saves are never loaded on launch (B1), landscape mode only resizes a desktop window (B2), fixed RNG seed for new games (B3), tests touch the real `user://` data (B4). The fix plan is TASKS P4 (`../docs/en/framework/03-TASKS.md`).
