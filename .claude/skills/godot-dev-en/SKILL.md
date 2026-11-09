---
name: godot-dev-en
description: The Age of the Codex Godot development workflow (English) — the doc-alignment iron rules, directory layout, GDScript conventions and verification steps that every code task under game/ must follow (new features, fixes, refactors, content-pack / sub-game integration, version iteration)
whenToUse: When a task involves writing, changing or debugging Godot code under game/, or implementing a new content pack, rule pack, sub-game, operations iteration, or the English/mobile build
type: prompt
---

# Godot development skill (The Age of the Codex) — English

You are the Godot engineer for *The Age of the Codex*. **Implementation obeys the docs**: `docs/` is the only design truth and code may only implement behavior the docs state. If you find a doc gap or contradiction while implementing, fix or rule on the doc first, then change the code (iron rule: the prototype and the implementation never exceed the docs).

Docs exist in two languages: the Chinese originals under `docs/` are authoritative; `docs/en/` is the maintained English mirror (terms in `docs/en/GLOSSARY.md`). Read whichever you work in, but when you change behavior, update **both** copies in the same commit.

## 0. Required reading before starting (by task type)

| Task type | Required docs (English mirror) |
|---|---|
| Logic core (Board / event stream / rules) | `docs/en/tech/01-technical-approach.md`, `docs/en/framework/07-world-state-machine-spec.md`, `docs/en/framework/11-light-rulepack-v1.md` |
| Screens / interaction | `docs/en/framework/04-ui-ux-design.md`, `docs/en/framework/09-encounter-and-dual-mode-spec.md`, `docs/en/framework/12-gesture-and-interaction-spec.md` |
| Content packs / side arcs / new campaigns | `docs/en/tech/02-content-pack-format-spec.md`, `docs/en/tech/03-content-pack-authoring-guide.md`, `docs/en/framework/08-branching-model-spec.md` |
| Resources / effects / numbers | `docs/en/tech/04-resources-and-effects-system.md`, `docs/en/framework/10-items-and-compendium-spec.md`, `docs/en/framework/11-light-rulepack-v1.md` |
| Monetization / operations iteration | `docs/en/framework/06-monetization-framework.md`, whitepaper §10.4 (dual-track iteration) |
| Known defects and verified status | `docs/en/tech/code-review-2026-11-10.md`, `docs/en/framework/03-TASKS.md` |

## 1. Engine and language (decided)

- **Godot 4.x (local 4.7.2, `/Applications/Godot.app/Contents/MacOS/Godot`), GDScript** (tech/01 E-1/E-4);
- Headless verification: `godot --headless --path game -s tests/run.gd` (exit code 1 on failure);
- Content-pack release form: one **PCK** per pack (`load_resource_pack`), per tech/01 §8.

## 2. Architecture iron rules → code constraints (non-negotiable)

| Doc iron rule | Code constraint |
|---|---|
| Presentation/logic decoupling (whitepaper §7.3) | `core/` contains only **RefCounted** classes; no `extends Node`, no scene tree / input / rendering APIs |
| The event stream is the only input (whitepaper §6) | core talks outward only via `EventStream.emit()`; shells only subscribe to the stream + read the Board, never call core internals (no `graph._enter(...)`-style private calls outside tests/tools) |
| The Board is the single source of truth (whitepaper §4.2) | All story reads/writes go through `Board.write(key, value, provenance)`; never mutate story-node state directly. This applies to `main.gd` and `subgame_runner.gd` too — route their writes through core APIs |
| Framework/content decoupling (whitepaper §2) | No pack ids (`campaign01`, `arena` …), node ids (`N1-1` …) or pack-private keys in `core/` or `shell/`; anything pack-specific comes from manifest/data |
| One core, two shells (09 §8) | The same `EncounterSM` instance drives `shell/portrait/` and `shell/landscape/`; no switching within an encounter |
| Rule packs as an extension axis (05) | Rule differences live in `core/encounter/rulepack/`; rendering and UI code are unaware of the rule tier |
| Monetization no-go zones (06 §4) | No code path that "pays to change dice / sells numbers"; entitlements only via `global.entitlement.*` Board variables |
| Auto-play shares the channel (09 §9.3) | AutoAgent and gesture input produce the same Command objects, differing only in `source` |
| Localization (tech/01 E-5) | core never emits player-facing prose; events carry message keys + params, and the shell resolves them through the locale tables |

## 3. Directory layout (game/)

```
game/
├── project.godot
├── core/            # logic core (RefCounted, zero engine deps, headless-testable)
│   ├── state/       # board.gd / event_stream.gd / rng.gd (seeded)
│   ├── graph/       # story_graph.gd / conditions.gd / pack_loader.gd
│   ├── encounter/   # encounter_sm.gd / rulepack/light_v1.gd / auto_agent.gd
│   └── save/        # save_system.gd (snapshot = full Board + event tail + bound versions)
├── shell/           # rendering shells
│   ├── ui/          # the nine screens (home / entry / settle / history / …)
│   ├── portrait/    # portrait temporal form (three-band breathing + room sequence)
│   └── landscape/   # landscape spatial form (five zones + tactical grid)
├── packs/           # content-pack runtime copies (tech/02 §1 layout; PCK on release)
├── tools/           # packlint.gd (V1–V15) / simulate.gd (bot simulation) / shot drivers
└── tests/           # headless test entry tests/run.gd
```

## 4. GDScript conventions

- Type annotations everywhere (`var x: int`, `func f() -> void`); core classes `PascalCase`, file names `snake_case.gd`;
- Event = `Dictionary` (`{id, type, payload, source, node}`); event types are `StringName` constants in `core/state/event_types.gd`;
- All randomness through a seeded instance of `core/state/rng.gd`, never bare `randi()`; **a new game gets a fresh seed** — fixed seeds are for tests and tools only;
- UI text: shells always go through `Texts` (`shell/ui/texts.gd`) — `Texts.s(&"KEY")` for strings, `Texts.lines()` for line arrays, `Texts.t()` for dictionaries; add new text to the source table `texts_zh.gd` first (constant name = key), then to `texts_en.gd`; never hard-code text in any language in UI code (a test guards this);
- Event messages: core and the app layer emit only `{msg_key, args}` (templates use `{name}` placeholders), and shells render them with `Texts.msg(payload)`; pack text is localized at load time, never assembled in code;
- Persistent paths (`user://saves`, `user://settings.cfg`) must be injectable; tests always use a `user://test/…` path and never touch the player's real data;
- Debug/screenshot drivers belong in `tools/`, not in `main.gd`;
- Commit messages: conventional commits (`feat(core): …` / `fix(shell): …` / `packs: …`), in English or Chinese to match the team's choice.

## 5. Development flow (every task)

1. **Read the docs**: per the §0 table; cite clause numbers in your reply as the basis for the implementation;
2. **Small steps**: core first, shells after; keep `tests/run.gd` passing at every step;
3. **Headless verification**: `godot --headless --path game -s tests/run.gd` all green; run packlint on every pack you touched;
4. **Self-check**: tick the "implementation vs doc clauses" list (see the `godot-acceptance-en` skill);
5. **Commit**: conventional commits; if doc behavior changes, update the docs (both languages) in the same commit.

## 6. Iteration rules (whitepaper §10.4 dual track)

- **Content track** (new branches / side arcs / sub-games / rule packs): touch only `packs/` data + necessary generic core capabilities; sub-games reuse `EncounterSM` and bring their own rule parameters and presentation; entering/leaving must pass through the Settlement screen (04 §6);
- **Operations track** (monetization / events / entitlement grants): change only entitlement configuration and `monetization` declarations, never the content graph; acquired entitlements never downgrade;
- No iteration may break: old-save compatibility (SaveSystem migration chain), dual-shell event-stream consistency, validation V1–V15.

## 7. Forbidden (violations mean redo)

- `Node` / `SceneTree` / `Input` / `@onready` in core;
- Shells (or `main.gd`) modifying the Board or story nodes directly (must go through core APIs);
- Driving the UI while bypassing the event stream;
- Adding manifest fields or resource types not registered in tech/02 without updating the spec;
- Copy-pasting separate "landscape" and "portrait" versions of logic;
- Hard-coding a pack id or node id in core or shell code;
- Tests that read or delete the real `user://` save or settings.
