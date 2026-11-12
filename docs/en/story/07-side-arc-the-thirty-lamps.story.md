---
pack_id: arc_lamps
pack_type: arc
name: The Thirty Lamps
source_locale: en
locales: ["en", "zh-CN"]
estimated_hours: "0.2"
monetization: {"strategies": ["free"]}
source_doc: docs/en/story/07-side-arc-the-thirty-lamps.md
graft: {"into": "campaign01", "node": "N1-1", "label": "The archivist asks for a copyist", "to": "S-1", "requires": {"flag.done": false}}
default_party: ["player_blank", "companion_kelan", "companion_laofei"]
---
<!-- Scriptorium errand (book: docs/en/story/07-side-arc-the-thirty-lamps.md). Import:
     godot --headless --path game -s tools/story_import.gd -- ../docs/en/story/07-side-arc-the-thirty-lamps.story.md -->

# ACT LAMPS: The Thirty Lamps | role: Side arc

## S-1 scene: The Archivist's Errand
Archivist Dace of the Scriptorium waits at the plaza fountain with a seal case under one arm and no sleep in her face. A novice copyist, Pell Ambry, went into the Reading Room of the Thirty Lamps three nights ago to finish a copy. He hasn't come out, and the annex seal is due to close at the next tide.

"Bring him out before it sets," Dace says. "The Ninth Rule is plain: a sealed room's pages are revoked with the room. I would rather not revoke a boy."
- choice "Take the errand to the annex" -> S-2

## S-2 check: The Sealed Annex Door
The annex door is painted over with ink-rings, and the seal ring in the middle is still turning. Someone has tried to pull the lock from inside. The metal is bent, not broken.
- check investigation medium "Read the dating on the seal ring" -> S-3 | fail S-2f
- check athletics medium "Force the bent hinges" -> S-3 | fail S-2f

## S-2f scene: The Lamp Goes Grey
The hinges give with a dry snap that runs up the annex stair like a dropped ruler. Inside, the Reading Room's lamps go grey one after another, and a bell rings in the annex tower that nobody rang.
> on_enter: clock +1
- choice "Get inside before the seal sets" -> S-3

## S-3 battle: Ink in the Thirty Lamps
Thirty lamps stand in a ring around an empty desk, and about half of them have gone out. The ink that took them has settled into shapes: a tall one with a pen for a hand, and two small ones that copy every move you make.
> encounter: medium | enemies ink_fiend, ink_imp x2 | xp 60 | mods hp+4 | gold 12 | loot ink_salve
- choice "Reach the centre desk" -> S-4

## S-4 dialog: Pell at the Centre Desk
Pell is copying by the last living lamp. His pen shakes, but his lines are straight. On the sheet in front of him are thirty names, Dace's own roll of novices, all of them revoked when their pages faded.

"If I finish the copy, they are written down somewhere," he says, without looking up. "The seal closes at the tide. I know what the Ninth Rule says. Let me finish, and then I'll come out."
- choice "Tell Pell the seal is closing and carry him out" -> S-5r
- choice "Let Pell finish the copy and carry the sheet out with you" -> S-5w
- choice "(Scriptorium Novice) 'I copied the Ninth Rule too. There is a clause for copies.'" -> S-5w [if background = scriptorium_novice] [do inspiration +1]

## S-5r scene: The Seal Closes
You carry Pell out on your shoulder while he protests that he has four more names. Behind you the sheet goes grey, one name at a time, from the bottom up. At the door the seal ring stops turning, and the annex is silent.

Dace takes the boy's arm without a word and signs the revocation slip in her own hand.
> on_enter: rep.scriptorium +1, alignment +5, gold +15, xp 40
- choice "Walk back to the plaza" -> S-6

## S-5w scene: A Copy Carried Out
Pell finishes the thirty names in careful ink while the seal rings. You fold the sheet into your coat and walk him out through the grey lamps. He does not look back at the annex, and he does not say thank you until the tide is well behind you.

The Salvage Guild's broker will buy a copy like that without asking where it came from. Dace, when she sees the empty desk, does not ask you for it.
> on_enter: rep.scriptorium -1, rep.salvage +1, alignment -5, gold +10, give pell_copy, xp 40
- choice "Walk back to the plaza" -> S-6

## S-6 scene: The Thirty Lamps
Whatever you carried out of the annex, the Reading Room is now a room that does not hold names. The lamps of the Scriptorium still burn over the plaza, and Dace's seal case is a little lighter.
> on_enter: lore revoked_registry_lamps, write done
- choice "Return to the plaza" -> N1-1

## LORE revoked_registry_lamps revoked_registry: The Thirty Lamps
A reading room in the Scriptorium annex with thirty lamps set in a ring. The novices who worked there copied the Scroll's margins by lamplight. When the Fading reached the annex, its pages went first, and the names went with them, so the Scriptorium revoked the whole roll. A copyist who finished the roll would have written thirty names back into the world, and there is a rule against that.
