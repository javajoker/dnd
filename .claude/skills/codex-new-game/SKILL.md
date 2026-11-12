---
name: codex-new-game
description: Recipe for making a new game on the Age of the Codex framework — kit copy, game manifest, theme / audio / art, world and campaign books, design data, story script import, balance and acceptance
whenToUse: Someone wants a new game (new world, new campaign, new theme) built on this engine
type: prompt
---

# New game recipe

References: `docs/en/tech/07-new-game-kit.md`, `docs/en/tech/11-content-pipeline-and-agents.md` §3.1, `docs/en/tech/08-asset-prompts.md`.

1. **Kit:** copy `game/kit/_game` → `<root>/_game` and `game/kit/starter` → `<root>/<campaign_id>` (or start from `game/kit/stories/campaign.story.md`). Try it: `godot --path game -- --packs-root=res://kit`.
2. **Game manifest** `_game/game.json`: `id`, `title`, `default_campaign`, `packs`, `locales`, `theme` (`palette`, `font`, `title_font`, `home_art` + `home_hotspots` + `home_focus`, `ui_dir`), `audio` (bgm / sfx / ambient), `store`. UI flavour texts in `_game/texts/<locale>.json`.
3. **World book** (`docs/en/story/01-world-<id>.md`) — codex-story-writer + codex-world-designer: concept, factions (→ rep), places, threat (→ Doom Clock), lore series, classes & backgrounds fiction.
4. **Campaign book** (`docs/en/story/02-campaign-<id>.md`): acts, hub, branches, endings, flags.
5. **Design data** — codex-world-designer (`codex-content-design`): classes / backgrounds, characters, skills, items, enemies; maps & tables if the game explores.
6. **Story script** — codex-story-writer (`codex-story-script`): `<campaign_id>.story.md` → `tools/story_import.gd`; set manifest `start`, `balance.act_level`, `recommended_level`.
7. **Balance** — codex-balancer (`codex-balance`).
8. **Assets:** placeholders work (`gen_art.py`, `gen_audio.py`); final art / music via tech/08 prompts; art ids in data (`art_ref`, `fx`), audio names in the manifest.
9. **Acceptance** (tech/11 §6) with the new packs root: packlint, balance_tune, simulate, screenshots per locale (`--packs-root=… --home-shot`, `--phone-size=390x910 --auto-battle-shots`).
10. **Store:** listing / privacy per `docs/en/store/` patterns; build per `docs/en/tech/09-build-and-release-guide.md`.

Engine changes only with a spec (tech/07 §6). No third-party trademarks in player-facing text.
