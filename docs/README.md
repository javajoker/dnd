# Documentation

The design documents are maintained **in English only**: [`en/README.md`](en/README.md) is the full index (framework, tech, story, sub-games, store), and terms follow [`en/GLOSSARY.md`](en/GLOSSARY.md). Any behavior change updates these documents in the same commit.

The earlier Chinese originals are archived, read-only, under [`../archive/zh-CN/docs/`](../archive/zh-CN/docs/). They are kept for reference and are not updated; where they differ from `en/`, `en/` wins.

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

- `en/framework/` — the game framework that doesn't change with the story (design intent)
- `en/tech/` — how the framework is implemented
- `en/story/` — world and campaign content
- `en/subgames/` — one folder per sub-game
- `en/store/` — store listing, privacy and billing documents

Pack data lives in the game itself, under [`../game/packs/`](../game/packs/README.md); that is the only copy.
