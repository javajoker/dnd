---
pack_id: arc_salvage
pack_type: arc
name: The Sealed Crate
source_locale: en
locales: ["en", "zh-CN"]
estimated_hours: "0.3"
monetization: {"strategies": ["free"]}
source_doc: docs/en/story/06-side-arc-the-sealed-crate.md
graft: {"into": "campaign01", "node": "N1-1", "label": "The Guild broker has a crate that needs fetching", "to": "S-1", "requires": {"flag.done": false}}
default_party: ["player_blank", "companion_kelan", "companion_laofei"]
---
<!-- Salvage Guild errand (book: docs/en/story/06-side-arc-the-sealed-crate.md). -->

# ACT SALVAGE: The Sealed Crate | role: Side arc

## S-1 scene: A Broker With a Short Fuse
The Salvage Guild keeps a counting table under an awning at the edge of the plaza. The broker, a thin woman named Orsolya Venn who weighs everything twice, slides a docket across it.

"Warehouse Nine on the Fog Wharf. Half of it has faded and the other half is going. In the back office there is a crate with the Guild's seal on it. Bring it to me unopened and the fee is sixty gold. Unopened. That is the whole job."
- choice "Take the docket" -> S-2 [do rep.salvage +1]
- choice "(Salvager's Apprentice) 'Sixty for a sealed crate? What is really in it?'" -> S-2 [if background = salvager_apprentice] [do rep.salvage +1, inspiration +1]

## S-2 check: Warehouse Nine
The front of the warehouse is only an idea: the doors are still there, but the wall around them has gone to pale paper. The back office is past a stack of cargo that is half crate and half rumour.
- check stealth medium "Slip through the faded loading bay" -> S-3 | fail S-2f
- check perception medium "Find the stretch of floor that is still real" -> S-3 | fail S-2f
- item boathook_axe "Hook a path through the faded stacks" -> S-3

## S-2f scene: The Floor Gives Way
A plank that was only remembered, not made, drops you into the cellar. The noise rolls through the whole building, and out on the wharf the nearest lamp goes grey.
> on_enter: clock +1
- choice "Climb back up to the office" -> S-3

## S-3 battle: What Lives in the Margins
The ink that eats the warehouse has started to take shape. A fiend unfolds from the shadow of the safe, and two small things drop from the beams to either side.
> encounter: medium | enemies ink_fiend, ink_imp x2 | xp 60 | mods hp+4 | gold 12 | loot ink_salve
- choice "Break the seal-lock on the crate" -> S-4

## S-4 scene: Unopened
You were told not to open it. Kelan does it anyway, with a quiet word of apology to the lid. Inside, packed in straw, are thirty thin plates of fired clay, each stamped with a household mark and a family name. Dwelling plates. The Fading has been eating the faded streets, and these are the plates that say who lived where.

Kelan reads the dates at a glance. "These are not salvage," she says. "These are still current. Every one of these families is alive and still has a door, and the Guild has been quietly lifting their plates before the Fading takes the house, so the house can be sold as empty."
> on_enter: lore revoked_registry_plates
- choice "Close the crate and think" -> S-5

## S-5 dialog: Sixty Gold, Unopened
Orsolya Venn is waiting at the foot of the wharf with two porters, as if she had known you would come this way. She holds out a purse and looks at the lid, then at the straw on your sleeve. "You opened it," she says, without heat. "Then you know what pays your rent. Plates for the gold, and everyone goes home."
- choice "Hand over the crate and take the sixty gold" -> S-6p [do rep.salvage +1, alignment -5, gold +60]
- choice "Take the plates to the Scriptorium registry, and let the clerks sort it out" -> S-6c [do rep.scriptorium +1, alignment +5]
- check intimidate medium "Keep the crate. Walk the plates back to their families yourself." -> S-6r | fail S-6x

## S-6x scene: Closed Doors
Venn lets you leave, which is worse than a fight. By the time you reach the first house on the plates the Guild has been, and the door has a fresh notice nailed to it. You deliver what you can; there is not enough of it.
> on_enter: rep.salvage -1, bond.kelan +5, xp 40
- choice "Walk back to the plaza" -> S-7

## S-6p scene: The Fee
The gold is real and heavy and counted twice. Kelan does not speak to you for the whole walk back, and when she does it is only to ask what the plates said.
> on_enter: bond.kelan -5, xp 40
- choice "Count the coins anyway" -> S-7

## S-6c scene: A Proper Procedure
The registry clerk takes the crate with both hands and a sigh, and gives you a receipt. It will take three months and a committee to decide whose houses these are. Kelan folds the receipt very small. "It is the right door," she says. "It is a slow one."
> on_enter: bond.kelan +5, xp 40, clock -1
- choice "Leave it with the clerks" -> S-7

## S-6r scene: Plates Home
Street by street, door by door, you press the plates back into the hands of the people they belong to. A cobbler cries. A child is given hers to carry. One old man says the plate is the wrong colour, and then holds it all afternoon. Kelan keeps a plate back for you, mended along its crack.
> on_enter: bond.kelan +15, give mended_house_plate, xp 40
- choice "Walk back to the plaza" -> S-7

## S-7 scene: The Awning at Dusk
The Guild's counting table is empty when you pass. Under the awning someone has chalked a new price on the board, and rubbed it out again.
> on_enter: write done
- choice "Return to the plaza" -> N1-1

## LORE revoked_registry_plates revoked_registry: The Dwelling Plates
Fired clay, a household mark, a family name: the plate that says a door belongs to the people behind it. When the Fading takes a street the plates go first, and a plate lifted early makes a house look empty to anyone who wants to buy one.
