---
pack_id: arc_lantern
pack_type: arc
name: The Lantern Vigil
source_locale: en
estimated_hours: "0.2"
monetization: {"strategies": ["free"]}
graft: {"into": "campaign01", "node": "N1-1", "label": "Answer the lantern-keeper's call", "to": "L-1", "requires": {"flag.done": false}}
default_party: ["player_blank", "companion_kelan", "companion_laofei"]
---
<!-- Side quest template: grafts one extra option into campaign01's plaza (N1-1). Import:
     godot --headless --path game -s tools/story_import.gd -- kit/stories/side_quest.story.md -->

# ACT LANTERN: The Lantern Vigil | role: Side arc

## L-1 scene: A Light on the Water
A lantern burns on the black water past the last pier, where no boat is moored. The keeper of the harbour lamps, an old woman with ink to the elbows, says it has burned for three nights and nobody lit it.

"Go and see who is keeping it," she says. "And if it is not one of ours, put it out."
- check perception medium "Read the light from the pier" -> L-2 | fail L-2 [fail_do clock +1]
- choice "Row out at once" -> L-2

## L-2 battle: The Drowned Bell-Ringers
Under the lantern, three shapes of ink rise out of the water, still ringing bells that make no sound.
> encounter: medium | enemies ink_fiend, ink_imp x2 | xp 60 | gold 12 | loot ink_core
- choice "Lift the lantern from the water" -> L-3

## L-3 scene: The Keeper's Name
The lantern's glass is etched with a name that the harbour register says was revoked twenty years ago. The flame steadies when you read it aloud.
> on_enter: lore lantern_keeper, rep.salvage +1, xp 40
- choice "Keep the lantern burning" -> L-4 [do alignment -5]
- choice "Put it out, as the keeper asked" -> L-4 [do alignment +5, gold +10]

## L-4 scene: Quiet Water
You row back. Behind you the water is dark either way, and the keeper of the harbour lamps is already asleep at her post.
> on_enter: write done
- choice "Return to the plaza" -> N1-1

## LORE lantern_keeper ashenport_local: The Lantern on the Water
For three nights a lantern burned past the last pier, kept by no one. Its glass carried the name of a lamp-keeper struck from the harbour register twenty years before. Some say a name read aloud is a name half written back.
