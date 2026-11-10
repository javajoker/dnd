# en language table (tech/01 E-5 bilingual build). Constant names are the keys and must match texts_zh.gd
# (the source table); missing keys fall back to the source. Format strings keep the same %-specifiers in the
# same order, and MSG_* templates the same {name} placeholders — tests/run.gd test_texts_en checks both.
# Names follow docs/en/GLOSSARY.md.
class_name TextsEn
extends RefCounted

# Console tabs (04 §④.5)
const TAB_ACTION := "Action"
const TAB_LOG := "Log"
const TAB_CHAR := "Party"

# Quickbar chips (09 §9.2)
const CHIP_ATTACK := "Attack"
const CHIP_FIRST_AID := "First Aid"
const CHIP_END_TURN := "End Turn"
const CHIP_ITEM_FMT := "%s ×%d"
const CHIP_MOVE := "Move"

# Auto-play (09 §9.3)
const AUTO_ON := "Auto"
const AUTO_OFF := "Manual"

# ☰ menu (09 §7)
const MENU := "☰"
const MENU_CONTINUE := "Continue"
const MENU_SAVE_QUIT := "Save & Return Home"
const MENU_HELP := "Gesture Help"
const MENU_CONFIRM_QUIT := "Quit? This encounter's progress will be lost (no saving mid-encounter)."
const MENU_SHAKE_ON := "Screen shake: On"
const MENU_SHAKE_OFF := "Screen shake: Off"
const MENU_VOL_MASTER := "Volume · Master"
const MENU_VOL_BGM := "Volume · Music"
const MENU_VOL_SFX := "Volume · Effects"
const JUICE_CRIT := "Critical"
const JUICE_MISS := "Dodged"
const KEY_ROLL_HINT := "Press and hold anywhere to skip"
const RESULT_SUCCESS := "Success"
const RESULT_FAIL := "Failure"
const RESULT_CRIT := "Critical success!"
const RESULT_FUMBLE := "Critical failure…"
const ZONE_WHEEL := "Action Wheel"
const ZONE_DICE := "Dice Tray"
const LOG_EXPAND := "Log ▴"
const LOG_COLLAPSE := "Hide ▾"

# ⑨ Settlement
const SETTLE_TITLE := "Encounter Results"
const SETTLE_VICTORY := "Victory"
const SETTLE_DEFEAT := "Defeat"
const SETTLE_RETREAT := "Retreat"
const SETTLE_QUIT := "Quit"
const SETTLE_HOME := "Home"
const SETTLE_HISTORY := "View Scroll"
const SETTLE_NEXT := "Next Encounter"
const SETTLE_SAVED := "Codex recorded."
const SETTLE_ATTR_TITLE := "Growth (points can be saved for your next loadout)"
const SETTLE_ATTR_KEEP := "Save for later"
const COMMON_BACK := "Back"
const COMMON_WIP := "(minimal version: more as content arrives)"

# Story screens
const STORY_CONTINUE := "Continue"
const STORY_CHECK := "Check"
const MAZE_TITLE := "%s · Explore %d/%d"
const MAZE_AMBUSH_PREFIX := "Ambush check | "
const MAZE_LOOT := "Pick up: %s ×%d"
const MAZE_BEAT_OK := "Check passed."
const MAZE_BEAT_FAIL := "Check failed…"
const SKILL_NAMES := {
	"athletics": "Athletics", "intimidate": "Intimidate", "stealth": "Stealth", "thievery": "Thievery",
	"perception": "Perception", "investigation": "Investigation", "history": "History",
	"persuasion": "Persuasion", "soothe": "Soothe",
	"history_or_perception": "History/Perception",
}
const DIFF_NAMES := {"easy": "Easy", "medium": "Medium", "hard": "Hard"}
const FACTION_NAMES := {"scriptorium": "Scriptorium", "uninked": "Uninked", "salvage": "Salvage Guild"}
const STORY_CLOCK := "Clock %d"
const STORY_CLOCK_NEXT := "▸ %s at %d"
const STORY_FORECAST_TITLE := "Approaching Time Edges"
const STORY_FORECAST_EMPTY := "Nothing is approaching yet."
const STORY_QUEST_BADGE := "Events %d"
const STORY_SLICE_END := "Act I · End of slice"
const SETTLE_SLICE := "Slice complete"
const STORY_MODE_UNLOCK := "The replay ends here — from now on, you can walk the road with the whole view laid out."
const ENDING_TITLE := "[Ending] %s"
const ENDING_HOOK := "Next playthrough: %s"
const ENDING_NGPLUS := "Start New Game+"
const ENDING_HOME := "Home"
const ENDING_SAVED := "Codex recorded."
const ENDING_PLAYTHROUGH := "— End of playthrough %d —"
const NGPLUS_TOAST := "You return to before the Tidewake carrying scraps of the codex. A Weaver's Fragment comes with you; your Compendium and unlocks are kept."
const HUB_SHOP := "Shop"
const HUB_REST := "Rest"
const HUB_RUMOR := "Listen for Rumors"
const HUB_GOLD := "Gold: %d"
const HUB_CLOSE := "Leave"
const HUB_NO_GOLD := "Not enough gold."
const HUB_REST_HINT := "Long rest: full HP and all Hit Dice restored"
const HUB_RUMOR_NONE := "The pier is quiet. No new rumors."

# ① Home (Camp)
const HOME_TITLE := "Ashenport · Camp"
const HOME_ENTRY_CAMPAIGN := "Campaigns"
const HOME_CONTINUE := "Continue"
const HOME_ENTRY_QUESTS := "Events"
const HOME_ENTRY_INVENTORY := "Inventory"
const HOME_ENTRY_CHARACTER := "Party"
const HOME_ENTRY_HISTORY := "History Scroll"
const HOME_HELP := "Help"
const HOME_SAVE := "Record the Codex"
const HOME_SAVED := "Codex recorded"
const HOME_BAR_HINT := "Text menu"
const HOME_BAR_COLLAPSE := "▾ Hide menu"
const HOME_BAR_EXPAND := "▴ Show menu"
const HOME_DOOM_LOW := "The campfire still burns high. The ink hangs on the horizon like rain that hasn't decided to fall."
const HOME_DOOM_MID := "The street names have faded a little more. People in the camp have started writing important things on their hands."
const HOME_DOOM_HIGH := "The Fading is close. The codex pages feel cold — all that will remain is what you write yourself."

# ② Campaign Entry (04 §②, 09 §3)
const ENTRY_TITLE := "Campaigns"
const ENTRY_START := "Begin Campaign"
const ENTRY_MODE_SPACE := "Landscape · Spatial"
const ENTRY_MODE_SPACE_DESC := "Tactical grid · positioning · big battles — every act laid out in full view"
const ENTRY_MODE_TIME := "Portrait · Temporal"
const ENTRY_MODE_TIME_DESC := "Room by room · story flow · one-handed — a memory unfolding at its own pace"
const ENTRY_MODE_PICK := "Choose how this journey is told (locked for the whole campaign)"
const ENTRY_MODE_CHOSEN := "Chosen: "
const ENTRY_COLLECT := "Branches explored"
const ENTRY_PLAYED := "Modes played: "
const ENTRY_SUBGAME_SECTION := "— Special campaign books · Sub-games —"
const ENTRY_SUBGAME_TAG := "[Sub-game · Gauntlet]"
const SUBGAME_ENTER_TIME := "Play in Portrait"
const SUBGAME_ENTER_SPACE := "Play in Landscape"
const SUBGAME_STATS := "Total wins %d · Best streak %d"
const SUBGAME_LEVEL := "Recommended Lv.%d+"
const LOCK_DEFAULT := "The gatekeeper only honors the mark — and your codex doesn't hold that page yet."
const LOCK_ACQUIRE := "Get"
const SHOP_TITLE := "The Gatekeeper's Seal Niche"
const SHOP_CONFIRM := "Confirm"
const SHOP_CANCEL := "Not now"
const SHOP_LINE := "%s — %s. Once the gatekeeper takes your mark, the ring's door opens for you."

# Loadout (09 §9.1)
const LOADOUT_TITLE := "Loadout"
const LOADOUT_SKILLS := "Skills (%d available, pick %d)"
const LOADOUT_ITEMS := "Items (%d slots)"
const LOADOUT_ATTRS := "Unspent attribute points: %d"
const LOADOUT_CONFIRM := "Set Out"
const LOADOUT_FULL := "(slots full)"
const LOADOUT_PRESET_TITLE := "Presets"
const LOADOUT_PRESET_EMPTY := "(nothing chosen yet — tap a preset or pick slot by slot)"
const LOADOUT_PRESET_MISSING := "Preset incomplete (skipped): %s"
const LOADOUT_PARTY_ITEM := "%s HP %d/%d"

# ⑧ History Scroll
const HISTORY_TITLE := "History Scroll"
const HISTORY_KEY_MARK := "★ Key check"
const HISTORY_EMPTY := "(no entries yet)"
const HISTORY_PROV := "Source: %s · %s"

# ⑤ Event Center
const QUESTS_TITLE := "Event Center"
const QUESTS_ACTIVE := "In progress"
const QUESTS_DONE := "Finished (archived to the History Scroll)"
const QUESTS_ABANDONED := "Abandoned (archived to the History Scroll)"
const QUESTS_ABANDON := "Abandon"
const QUESTS_EMPTY := "(no events in progress)"

# ⑥ Inventory and Compendium
const INV_TITLE := "Inventory & Compendium"
const INV_BAG := "Inventory"
const INV_CODEX := "Compendium"
const INV_FILTER_ALL := "All"
const INV_ROLE_NAMES := {
	"stat": "Gear", "check_mod": "Check tools", "branch_key": "Branch keys", "codex": "Compendium tokens",
}
const INV_BRANCH_HINT := "It looks like it might be useful somewhere…"
const CODEX_SERIES := {
	"weaver_fragments": "Weaver's Fragments", "revoked_registry": "Register of the Revoked",
	"fatedie_study": "Treatise on the Fatedie", "ashenport_local": "Ashenport Gazetteer",
}
const CODEX_REWARDS := {
	"weaver_fragments": "Complete → a hidden storyline revealing the truth of the Fading",
	"revoked_registry": "Complete → unlocks a Remembrance campaign (portrait only)",
	"fatedie_study": "Complete → the \"Faded Ink Grey\" dice skin (cosmetic only)",
	"ashenport_local": "Complete → Ashenport reputation and shop discounts",
}
const CODEX_PROGRESS := "%s: %d/%d"
const CODEX_REWARD_LINE := "  Reward: %s"
const CODEX_LOCKED_TITLE := "???"
const INV_COSMETIC := "Cosmetics"
const COSMETIC_EQUIP := "Equip"
const COSMETIC_EQUIPPED := "Equipped"
const COSMETIC_UNEQUIP := "Unequip"
const COSMETIC_NOT_OWNED := "Not owned"
const COSMETIC_PURE_NOTE := "Skins only recolor the die — they never change your luck (cosmetic only)"
const COSMETIC_SRC_DEFAULT := "Owned from the start"
const COSMETIC_SRC_CODEX := "Reward for completing the Treatise on the Fatedie"
const COSMETIC_SRC_SHOP := "The Gatekeeper's Seal Niche · %s"
const COSMETIC_SRC_NGPLUS := "New Game+ · exclusive to ending %s"
const COSMETIC_SHOP_LINE := "\"%s\" — %s. The gatekeeper strikes a new seal, and your die catches a different light from now on."

# ⑧ Battle replay
const HISTORY_REPLAY := "Replay"
const REPLAY_TITLE := "Battle Replay (presentation only · results can't change)"
const REPLAY_SKIP := "Skip"
const REPLAY_DONE := "— End of replay —"

# Room review (04 §④.2)
const ROOM_REVIEW_TITLE := "Past Rooms"
const ROOM_REVIEW_HINT := "(Read-only: finished checks and battles don't reset)"
const GESTURE_CANCEL := "Released on empty space — cancelled"
const GESTURE_PATH_AIM := "Path: %s → %s"

# ⑦ Party
const CHAR_TITLE := "Party"
const CHAR_BOND := "Bonds"
const CHAR_GROWTH := "Growth: Lv.%d  XP %d/%s"
const CHAR_GROWTH_MAX := "Growth: Lv.%d  XP %d (max level)"
const CHAR_GROWTH_ATTRS := "Allocated: MGT %+d FIN %+d WIT %+d  Unspent points: %d"

# Help and tutorial (12 §4)
const HELP_TITLE := "Gesture Guide"
const HELP_RETRAIN := "Replay Tutorials"
const HELP_LINES: Array[String] = [
	"Tap = select / confirm (options, buttons, target cells, target units)",
	"Tap a chip / wheel action = use it on the default target",
	"Long-press (≥0.4 s) = unit / item details; long-press to skip key-check presentations",
	"Drag your own unit = move (spends movement; shows where you'll land)",
	"Drag a path (ally → enemy) = targeted skill: the path previews the trajectory; release to confirm, release on empty space to cancel",
	"Two-finger tap (battlefield / main view) = end turn / quick roll for normal checks",
	"Swipe (console) = switch the four tabs (Action / Dice / Log / Party)",
	"Pinch = zoom the battlefield (overview ↔ follow camera; springs back in portrait)",
	"Swipe down / tap (progress bar) = review past rooms (read-only; finished checks and battles don't reset)",
	"(Every gesture has an equivalent button — gestures are a shortcut, never the only way)",
]
const TUT_NEXT := "Next"
const TUT_SKIP := "Skip"
const TUT_DISMISS := "Tap anywhere to continue"
const TUT_CARDS: Array[String] = [
	"[Tap] = Select\nOptions, buttons, targets — a light tap decides.",
	"[Long-press] = Details\nHold a unit or item for a moment to open its info card.",
	"[Swipe] = Switch\nSwipe left or right on the bottom console to switch Action / Dice / Log / Party.",
]
const TUT_HINT_COMBAT := "Drag your unit = move; drag onto an enemy = cast along the path; two-finger tap = end turn; pinch = zoom the battlefield."
const TUT_HINT_CHECK := "Two-finger tap = quick roll; tapping the check button works too. Long-press to skip key-check presentations."
const TUT_HINT_KEY := "Key-check presentation: hold ≥0.4 s to skip. Nothing is lost — it's all written to the log and the Scroll."

# Event-stream message templates (core emits msg_key + args; tech/01 E-5)
const MSG_REST := "You take a long rest at the inn. Your wounds are rewritten and your Hit Dice restored."
const MSG_ACHIEVEMENT := "Achievement: {label}"
const MSG_SKIN_CODEX := "Series complete — the \"{skin}\" dice skin is yours. (Cosmetic only; it never changes your luck.)"
const MSG_SKIN_SHOP := "The gatekeeper strikes a new seal — the \"{skin}\" dice skin is yours. (Cosmetic only; it never changes your luck.)"
const MSG_MAZE_START := "Exploration begins ({beats} steps)"
const MSG_MAZE_AMBUSH := "Ambush! ({enemy})"
const MSG_MAZE_LOOT := "Picked up: {item} ×{n}"
const MSG_MAZE_DONE := "Exploration complete"
const MSG_SKILL_USED := "{unit} uses {skill}"
const MSG_ENCOUNTER_END := "Encounter over: {result} ({rounds} rounds)"
const MSG_SUB_STAGE_WIN := "Bout {stage} won: gold +{gold} (no rest between bouts — you carry your wounds into the next)"
const MSG_SUB_CLEAR := "Clear recorded +1"
const MSG_RESUMED := "The codex falls open at the page where you last left off."
const MSG_REWIND_BATTLE := "You close the codex. This page's rain is gently turned back to the beginning."
const MSG_REWIND_STORY := "You close the codex. That's where this part of the story stops."
const MSG_REWIND_SUB := "You close the codex. The ring's ink gong fades away."
const MSG_PURCHASED := "The gatekeeper takes your mark — the door to {pack} is open. (Unlocked now, no restart needed.)"
const MSG_SAVED := "Codex recorded."
const MSG_STORY_ECHO := "[{title}] {text}"

# Language (tech/01 E-5)
const LANG_BUTTON := "Language: English"

# Shell format strings
const FMT_CHECK_LABEL := "%s: %s (%s DC %d · mod %+d)"
const SETTLE_LINE_ITEM := "Gained: %s ×%d (added to inventory)"
const SETTLE_LINE_FLAG := "Flag: %s"
const SETTLE_LINE_REP := "Reputation: %s %+d"
const SETTLE_LINE_LOADOUT := "Loadout: skills %s / items %s"
const SETTLE_LINE_XP := "XP +%d"
const LOG_XP := "XP +%d"
const SETTLE_LINE_LEVEL := "Level: Lv.%d"
const SETTLE_LINE_ATTR := "Growth: +%d attribute points"
const SETTLE_LINE_CLOCK := "Doom Clock: %d"
const SETTLE_LINE_ITEM_SHARED := "Gained: %s ×%d (added to inventory, usable in the campaign)"
const SETTLE_LINE_LORE := "New Compendium entry: %s"
const SETTLE_LINE_GOLD_DELTA := "Gold %+d (total %d)"
const SETTLE_LINE_GOLD := "Gold +%d (total %d)"
const SETTLE_LINE_RECORD := "Record: %d wins this run · %d wins total · best streak %d"
const SETTLE_LINE_FLAWLESS := "A flawless bow: the ring will remember your name"
const SETTLE_SUB_TITLE := "Gauntlet Results"
const LOG_GESTURE_HELP := "Gesture help: %s"
const UNIT_CARD_HP := "HP %d/%d  AC %d"
const UNIT_CARD_DAMAGE := "Damage %s  Attack mod %+d"
const UNIT_CARD_STATE := "State: %s"
const UNIT_DOWNED := "Downed"
const UNIT_DEAD := "Dead"
const UNIT_OK := "OK"
const UNIT_CARD_CELL := "Cell: %s"
const UNIT_CARD_INIT := "Initiative: #%d"
const ROUND_FMT := "Round %d"
const TIME_EDGE_DEFAULT := "Time edge"
const DOOM_PREVIEW_LINE := "%s — fires at clock %d (%s)"
const BRACKET_FMT := "[%s]"
const DICE_DETAIL := "Roll %s mod %+d total %d (%s)"
const KEY_DEATH_SAVE_TALLY := "\nDeath saves: %d successes, %d failures"
const REVIEW_EMPTY := "(no past rooms yet)"
const REVIEW_DETAIL := "[%s]\n%s"
const FLASH_COMBAT_START := "Battle begins!"
const FLASH_DOWNED := "%s is down!"
const FLASH_TARGET := "Target: %s"
const CHAR_TAB_DEAD := " (dead)"
const CHAR_TAB_DOWNED := " (downed, saves %d/%d)"
const CHAR_TAB_LINE := "%s  HP %d/%d  AC %d  MGT%+.0f FIN%+.0f WIT%+.0f%s"
const LOG_AUTO_TAG := " (auto)"
const LOG_DEATH_SAVE := "%s death save: %d → %s (%d successes, %d failures)"
const LOG_SAVE := "%s saving throw: %d%+d=%d vs %d → %s (damage %d)"
const LOG_FIRST_AID := "%s gives first aid to %s: %d → %s"
const LOG_CHECK := "Check · %s: %d%+d=%d vs %d → %s"
const LOG_CHECK_TOTAL := "Check: %d"
const LOG_ATTACK := "%s attacks %s: %s"
const LOG_HIT_DAMAGE := "hit for %d"
const LOG_MISS := "miss"
const LOG_CRIT_TAG := " (critical!)"
const LOG_FUMBLE_TAG := " (critical failure)"
const LOG_STATE_ENTER := "— Entering %s —"
const LOG_COMBAT_START := "Battle begins. Initiative: %s"
const LOG_SKILL := "%s uses %s%s"
const LOG_SUMMON_TAG := ": summons ×%d"
const LOG_ATK_MOD_TAG := " (attack mod → %+d)"
const LOG_SKILL_EXTRA := "%s uses %s%s%s"
const LOG_ITEM_USE := "%s uses %s → %s (heals %d)%s"
const LOG_DOWNED := "⚠ %s is down!"
const LOG_DIED := "✝ %s dissolves."
const LOG_REVIVED := "%s gets back up (1 HP, %s)."
const LOG_CMD_REJECTED := "(Command refused: %s)"
const LOG_COMBAT_END := "— Battle over: %s —"
const LOG_ITEM_GAIN := "Gained item: %s ×%d"
const PAREN_PAIR_FMT := "%s (%s)"
const HUB_SHOP_LINE := "%s — %d gold%s"
const HUB_OWNED_TAG := " (have %d)"
const PAREN_FMT := " (%s)"
const CHAR_WIP_LINE := "(skill uses / equipment slots / status effects %s)"
const CHAR_ROSTER_LINE := "%s  HP %d/%d  MGT%+.0f FIN%+.0f WIT%+.0f\n  Skills: %s"
const ENTRY_SUBGAME_NAME := "%s %s %s"
const BOOK_TITLE_FMT := "%s"
const ENTRY_LEVEL_HOURS := "Recommended level %s · About %s hours"
const ENTRY_ACTS := "Acts: %s"
const ENTRY_RECOMMEND_TAG := "\n[Recommended]"
const HIST_HIT := "hit %d"
const HIST_MISS := "miss"
const HIST_CHECK_DETAIL := "Check: rolled %s, kept %d, mod %+d = %d vs DC %d → %s"
const HIST_DEATH_SAVES := "Death saves: %d successes, %d failures"
const HIST_ATTACK_DETAIL := "Attack: rolled %s, kept %d (%s), mod %+d vs AC %d → %s"
const HIST_HIT_DETAIL := "hit, damage %d %s"
const HIST_FLAG_CHANGE := "Flag change: %s  %s → %s"
const INV_ITEM_LINE := "%s ×%d  %s"
const TAG_FMT := "[%s]"
const INV_ROLES := "Type: %s"
const INV_USE_HEAL := "Use: restores %s HP (bonus action)"
const INV_CONSUMABLE := "Consumable"
const INV_CHECK_MOD := "Check modifier: works while carried (check tool)"
const INV_PRICE := "Price: %d gold"
const INV_LORE_LINE := "📜 %s (%s)"
const INV_LORE_SOURCE := "Found: %s"
const COLON_PAIR_FMT := "%s: %s"
const QUEST_LINE := "◆ %s — %s\n  %s (%s)"
const SETTLE_HEAD := "[%s] %s — %s"
const SETTLE_ATTR_AVAIL := "%s (%d available)"
const EDGE_BADGES := "  [%s]"
const RUMOR_LINE := "Rumor: someone mentions \"%s\" — %s."
const TOAST_FLAG := "Flag updated: %s"
const TOAST_REP := "Reputation: %s %+d (%d)"
const TOAST_ITEM_GAIN := "Gained: %s ×%d"
const TOAST_ITEM_LOSS := "Used: %s ×%d"
const TOAST_QUEST_TRIGGER := "Event started: %s"
const TOAST_QUEST_SETTLE := "Event finished: %s"
const TOAST_LORE := "New Compendium entry: %s"
const LIST_SEP := ", "
const STATE_NAMES := {"enter": "Enter", "explore": "Explore", "discover": "Discover", "combat": "Combat",
	"settle": "Settlement", "rest": "Rest", "exit": "Exit"}
const ATTR_SHORT := {"might": "MGT", "finesse": "FIN", "wits": "WIT"}
const NOTICE_FORCED_TIME := "This memory can only be replayed in fragments — it unfolds at its own pace."
const NOTICE_FORCED_SPACE := "This act can't be told from inside; it can only be laid out in full view."

# Store and locked chapters (06 §3.1/§7; P4 Phase 4)
const LOCK_CHAPTER_TEXT := "The codex closes here — the pages beyond haven't been opened for you yet."
const LOCK_CHAPTER_DEMO := "That's the end of the free demo: the Prologue and Act I. Unlock the full campaign once, and every choice you've made carries on from this page."
const LOCK_CHAPTER_GET := "Unlock the full campaign · %s"
const LOCK_CHAPTER_GET_NOPRICE := "Unlock the full campaign"
const LOCK_BACK_HOME := "Back to Camp"
const STORE_RESTORE := "Restore Purchases"
const MSG_RESTORED := "Restored {n} purchase(s)."
const MSG_PURCHASE_FAILED := "The purchase didn't go through: {error}"
const MSG_STORE_UNAVAILABLE := "The store isn't available right now."
const SHOP_LINE_CAMPAIGN := "%s — %s. One unlock, and your codex carries on from this page."
const DICE_STRIP_IDLE := "Your rolls appear here"

# ---- Camp and rests (11 §7.2 short/long rest; battle gold 11 §7.3) ----
const CAMP := "Make Camp"
const CAMP_TITLE := "Camp"
const CAMP_SUPPLIES := "Supplies"
const CAMP_PARTY_LINE := "%s  HP %d/%d · Hit Dice %d/%d (%s)"
const CAMP_SHORT_REST := "Short rest: roll a Hit Die"
const CAMP_FULL := "Full"
const CAMP_NO_DICE := "No Hit Dice"
const CAMP_LONG_REST := "Long rest (Doom Clock +%d)"
const CAMP_HINT := "Short rest: spend Hit Dice to heal. Long rest: full HP and Hit Dice back, but time passes. Skill uses recharge every encounter."
const HUB_INN_REST := "Long rest here (safe haven, free)"
const MSG_SHORT_REST := "{name} takes a short rest: rolled {roll} on the {die}, healing {heal} HP ({hp}/{max_hp})."
const MSG_LONG_REST_CAMP := "You make camp for a long rest. Wounds close and Hit Dice return — but the ink fades a little more (Doom Clock +{clock})."
const MSG_GOLD_GAIN := "Found {amount} gold."
