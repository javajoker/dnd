---
pack_id: arc_crane
pack_type: arc
name: The Crane Ledger
source_locale: en
locales: ["en", "zh-CN"]
estimated_hours: "0.3"
monetization: {"strategies": ["free"]}
source_doc: docs/en/story/05-side-arc-the-crane-ledger.md
graft: {"into": "campaign01", "node": "N1-1", "label": "Old Fei wants a word about his ledger", "to": "C-1", "requires": {"flag.done": false}}
default_party: ["player_blank", "companion_kelan", "companion_laofei"]
---
<!-- Old Fei's companion quest (book: docs/en/story/05-side-arc-the-crane-ledger.md). Import:
     godot --headless --path game -s tools/story_import.gd -- ../docs/en/story/05-side-arc-the-crane-ledger.story.md -->

# ACT CRANE: The Crane Ledger | role: Side arc

## C-1 scene: Under the Old Crane
Old Fei sits on the counterweight of the dead harbour crane, turning a tally board over in his hands. For thirty years he chalked every crew he lifted cargo with into one ledger, and kept that ledger in the tally house by the breakwater.

"Last night I couldn't remember the name of the lad who lost two fingers to the chain," he says. "I knew it yesterday. The Fading's in the tally house. Help me fetch the ledger before it eats the rest."
- choice "Go to the tally house with him" -> C-2 [do bond.laofei +5]
- choice "(Dockhand) 'I grew up under this crane. My name's in there too.'" -> C-2 [if background = dockhand] [do bond.laofei +10, inspiration +1]

## C-2 check: The Flooded Tally House
The tide has come in under the tally house door and swollen it shut. Through the shutters you can hear something wet turning pages.
- check athletics medium "Shoulder the swollen door" -> C-3 | fail C-2f
- check thievery medium "Work the shutter latch quietly" -> C-3 | fail C-2f
- item boathook_axe "Pry the door off with the boathook axe" -> C-3

## C-2f scene: Too Much Noise
The door gives at last with a crack that carries across the whole harbour. Inside, the wet page-turning stops. Out on the breakwater a lamp goes grey, and then the one beside it.
> on_enter: clock +1
- choice "Get inside before it's too late" -> C-3

## C-3 battle: Ink at the Ledger
A swarm of ink has settled on the open ledger like flies on spilt sugar, drinking names line by line. It rises when you step inside, and two salvage-scavengers who were waiting for it to finish come up out of the dark behind you.
> encounter: medium | enemies ink_swarm, dock_ambusher x2 | xp 60 | gold 12 | loot ink_salve
- choice "Lift the ledger out of the water" -> C-4

## C-4 dialog: Three Buyers for a Book of Names
Half the ledger is grey. Old Fei reads what is left with his finger on each line. At the door, a Scriptorium clerk with two hired swords is already waiting.

"That is a register of the living," the clerk says. "The Scriptorium will re-ink it properly. You will be paid." Behind him, an Uninked runner shouts from the breakwater: let the tide have it, names are chains. And Old Fei just holds the book.
> on_enter: lore revoked_registry_crane
- choice "Hand it to the clerk to be re-inked" -> C-6s [do rep.scriptorium +1, alignment +5, gold +15]
- choice "Throw it to the tide, as the runner says" -> C-6u [do rep.uninked +1, alignment -5]
- check persuasion medium "It stays with Old Fei. Talk the clerk down." -> C-6k | fail C-5

## C-5 battle: The Clerk's Hired Swords
The clerk steps back and nods to his escort. The hired swords draw, polite about it, the way men are who are paid by the day.
> encounter: easy | enemies mercenary x2 | xp 40 | gold 8
- choice "Let the clerk run" -> C-6k [do rep.scriptorium -1]

## C-6k scene: Names Read Aloud
That night Old Fei sits on the crane's counterweight and reads every name still left in the ledger, slowly, out loud, one crew at a time. Some lines come back a little darker as he reads them. When he gets to the lad with two fingers missing he stops, and laughs, and says the name twice.

He presses his old crane token into your hand. "For the next crew."
> on_enter: bond.laofei +15, give fei_crane_token, xp 40
- choice "Walk back with him" -> C-7

## C-6s scene: A Clean Copy
The clerk sends the copy back three days later: clean gold ink, every surviving line, the grey ones left blank. Old Fei turns the pages for a long time. "It's neat," he says. "They spelled Big Hu wrong."
> on_enter: bond.laofei +5, xp 40, clock -1
- choice "Leave him to it" -> C-7

## C-6u scene: What the Tide Keeps
The ledger turns once in the swell and goes under. The runner salutes you from the breakwater and is gone. Old Fei watches the water for a while. "Maybe they'd rather be free of my chalk," he says, not believing it.
> on_enter: bond.laofei -5, xp 40
- choice "Stand with him a while" -> C-7

## C-7 scene: The Crane at Low Tide
The tide goes out. The crane stands over the plaza the way it always has, rusted into one position, pointing at the sea.
> on_enter: write done
- choice "Return to the plaza" -> N1-1

## LORE revoked_registry_crane revoked_registry: The Crane Ledger
Thirty years of harbour crews chalked into one book by the crane operator called Old Fei: who lifted, who lost a finger, who was owed a drink. When the Fading reached the tally house it ate the ledger from the back, newest crews first, as if it knew the old man would notice the young ones last.
