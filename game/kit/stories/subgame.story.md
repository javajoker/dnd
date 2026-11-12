---
pack_id: bell_trials
pack_type: subgame
name: The Bell Tower Trials
source_locale: en
recommended_level: [2, 4]
monetization: {"strategies": ["free"]}
subgame: {"rules_override": {"arena_mode": true}, "gold_reward": [10, 20, 30], "stat_keys": {"wins": "bell_trials.wins", "best": "bell_trials.best"}}
default_party: ["player_blank", "companion_kelan", "companion_laofei"]
---
<!-- Sub-game template: a three-battle gauntlet. A sub-game pack is standalone — it needs its own
     characters.json / enemies.json / skills.json / items.json (copy them from a campaign or design new
     ones), then list the pack in packs/_game/game.json "packs". -->

# ACT BELL: The Bell Tower Trials | role: Gauntlet

## B-0 scene: The Bell Tower
Each bell in the tower was cast to call one thing up from the deep. Ring them in order, and survive what answers.
- choice "Ring the first bell" -> B-1

## B-1 battle: The First Bell
> encounter: easy | enemies ink_imp x2 | xp 30
- choice "Ring the second bell" -> B-2

## B-2 battle: The Second Bell
> encounter: medium | enemies ink_fiend, ink_imp | xp 50
- choice "Ring the last bell" -> B-3

## B-3 battle: The Last Bell
> encounter: hard | enemies ink_fiend x2 | xp 80
- choice "Let the tower fall silent" -> B-END

## B-END ending: Silence
The bells hang still. Whatever was down there has stopped answering.
> ending: default
