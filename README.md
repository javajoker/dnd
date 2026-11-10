# Age of the Codex: Ashenport Fragments

A tabletop-style d20 RPG for phones, built in Godot 4.7. You are one of the Unwritten in a world that is a fading book: roll the Fatedie, and every success or failure branches the story. The engine is a framework for content packs — campaigns, side arcs and sub-games are data, not code.

The game is bilingual (English by default; Chinese when the phone is set to Chinese or the player picks it). The English mobile release is portrait-first, with the Prologue and Act I free and a one-time unlock for the full campaign.

## Repository

| Folder | What it is |
|---|---|
| [`game/`](game/README.md) | The Godot project: logic core, two rendering shells, content packs, tools, tests |
| [`docs/`](docs/README.md) | Design docs (English; the maintained source of truth) |
| [`prototype/`](prototype/README.md) | Zero-dependency browser prototype of the nine screens |
| `.claude/` | Engineering agent and skills (`godot-dev-en`, `godot-acceptance-en`, `godot-developer-en`) |
| [`archive/zh-CN/`](archive/zh-CN/) | Archived Chinese docs, READMEs and agent/skills (read-only, no longer updated) |

## Quick start

Requires Godot 4.7.2 (`/Applications/Godot.app/Contents/MacOS/Godot` on macOS).

Run the game:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path game
```

Run the headless test suite (exit code 1 on any failure):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tests/run.gd
```

Validate a content pack:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tools/packlint.gd -- packs/campaign01
```

More — screenshots, language/market/safe-area flags, exporting — in [`game/README.md`](game/README.md).

## Status

See [TASKS](docs/en/framework/03-TASKS.md) (section P4) and the [code review](docs/en/tech/code-review-2026-11-10.md). The game side of the English release is done; what remains needs store accounts and devices: billing plugin adapters ([contract](docs/en/store/billing-adapter.md)), export templates/SDKs, and a real-device pass.

## License

See [LICENSE](LICENSE).
