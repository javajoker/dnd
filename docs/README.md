# Documentation

> 中文版：[`README.zh-CN.md`](README.zh-CN.md)（中文文档为设计真相源）

The design documents exist in two languages:

- **English** — [`en/README.md`](en/README.md): the full English index (framework, tech, story, sub-games, store). Terms follow [`en/GLOSSARY.md`](en/GLOSSARY.md).
- **Chinese** — [`README.zh-CN.md`](README.zh-CN.md): the original documents. They are the design source of truth; any behavior change updates both languages in the same commit.

## Where to start

| If you want to… | Read |
|---|---|
| Understand the game framework | [Framework Whitepaper](en/framework/01-framework-whitepaper.md) |
| See what's done and what's next | [TASKS](en/framework/03-TASKS.md) (P4 = English mobile release) |
| Know the current code state | [Code review 2026-11-10](en/tech/code-review-2026-11-10.md) |
| Write or translate content | [Content pack format](en/tech/02-content-pack-format-spec.md), [authoring guide](en/tech/03-content-pack-authoring-guide.md) |
| Prepare the store release | [store/](en/store/store-listing.md) |
| Read the story | [The Age of the Codex](en/story/01-world-age-of-the-codex.md), [Ashenport Fragments](en/story/02-campaign-ashenport-fragments.md) |

## Layout

- `framework/` — the game framework that doesn't change with the story (design intent)
- `tech/` — how the framework is implemented
- `story/` — world and campaign content; pack data lives in `story/<pack_id>/`
- `subgames/` — one folder per sub-game, pack data in `subgames/<name>/pack/`
- `en/` — the English mirror of all of the above, plus English-only store documents
