# 战斗日志文案共享格式化（godot-dev §7：禁止复制两份"横屏版/竖屏版"逻辑）
# 两壳的日志带/日志 Tab 消费同一事件流，条目文案只此一处；name_of = 单位 id → 显示名查询。
class_name BattleText
extends RefCounted

static func state_name(st: StringName) -> String:
	return str((Texts.t(&"STATE_NAMES") as Dictionary).get(String(st), str(st)))

## 托管来源标注（09 §9.3：事件流标注来源 auto，可追溯）。
static func src_tag(p: Dictionary) -> String:
	return Texts.s(&"LOG_AUTO_TAG") if str(p.get("source", "")) == "auto" else ""

static func check_text(p: Dictionary, name_of: Callable) -> String:
	match str(p.get("kind", "")):
		"death_save":
			return Texts.s(&"LOG_DEATH_SAVE") % [name_of.call(str(p["roller"])),
				int(p["keep"]), Texts.s(&"RESULT_SUCCESS") if bool(p["success"]) else Texts.s(&"RESULT_FAIL"),
				int(p.get("s", 0)), int(p.get("f", 0))]
		"save":
			return Texts.s(&"LOG_SAVE") % [name_of.call(str(p["roller"])),
				int(p["keep"]), int(p["mod"]), int(p["total"]), int(p["dc"]),
				Texts.s(&"RESULT_SUCCESS") if bool(p["success"]) else Texts.s(&"RESULT_FAIL"),
				int(p.get("damage", 0))]
		"first_aid":
			return Texts.s(&"LOG_FIRST_AID") % [name_of.call(str(p["roller"])),
				name_of.call(str(p["target"])), int(p["total"]),
				Texts.s(&"RESULT_SUCCESS") if bool(p["success"]) else Texts.s(&"RESULT_FAIL")]
		"story_check":
			var skill := str(p.get("skill", ""))
			return Texts.s(&"LOG_CHECK") % [str(Texts.t(&"SKILL_NAMES").get(skill, skill)),
				int(p["keep"]), int(p["mod"]), int(p["total"]), int(p["dc"]),
				Texts.s(&"RESULT_SUCCESS") if bool(p["success"]) else Texts.s(&"RESULT_FAIL")]
	return Texts.s(&"LOG_CHECK_TOTAL") % int(p.get("total", 0))

static func attack_text(p: Dictionary) -> String:
	var txt := Texts.s(&"LOG_ATTACK") % [p["attacker_name"], p["target_name"],
		Texts.s(&"LOG_HIT_DAMAGE") % int(p["damage"]) if bool(p["hit"]) else Texts.s(&"LOG_MISS")]
	if bool(p["crit"]):
		txt += Texts.s(&"LOG_CRIT_TAG")
	elif bool(p["fumble"]):
		txt += Texts.s(&"LOG_FUMBLE_TAG")
	return txt

## 事件 → 日志条目文案；不该入日志的事件类型返回 ""。
static func event_log_text(ev: Dictionary, name_of: Callable) -> String:
	var p: Dictionary = ev.get("payload", {})
	match StringName(ev["type"]):
		EventTypes.STATE_ENTERED:
			return Texts.s(&"LOG_STATE_ENTER") % state_name(StringName(p["state"]))
		EventTypes.COMBAT_START:
			return Texts.s(&"LOG_COMBAT_START") % " → ".join(p["order"])
		EventTypes.BATTLE_ATTACK:
			return attack_text(p) + src_tag(p)
		EventTypes.CHECK_ROLL:
			return check_text(p, name_of) + src_tag(p)
		EventTypes.SKILL_USE:
			return Texts.s(&"LOG_SKILL") % [name_of.call(str(p["unit"])), p["name"], src_tag(p)]
		EventTypes.BATTLE_SKILL:
			# Boss 行为脚本技能（story/03 §2）：召唤/转阶段附明细，AoE 明细由随后 check.roll 豁免条目承载
			var extra := ""
			if p.has("summoned"):
				extra = Texts.s(&"LOG_SUMMON_TAG") % (p["summoned"] as Array).size()
			elif p.has("attack_mod_after"):
				extra = Texts.s(&"LOG_ATK_MOD_TAG") % int(p["attack_mod_after"])
			return Texts.s(&"LOG_SKILL_EXTRA") % [name_of.call(str(p["unit"])), p["name"], extra, src_tag(p)]
		EventTypes.ITEM_USE:
			return Texts.s(&"LOG_ITEM_USE") % [name_of.call(str(p["unit"])), p["item"],
				name_of.call(str(p["target"])), int(p["healed"]), src_tag(p)]
		EventTypes.BATTLE_DOWN:
			return Texts.s(&"LOG_DOWNED") % str(p["name"])
		EventTypes.BATTLE_DEAD:
			return Texts.s(&"LOG_DIED") % str(p["name"])
		EventTypes.BATTLE_REVIVE:
			return Texts.s(&"LOG_REVIVED") % [p["name"], p["reason"]]
		EventTypes.COMMAND_REJECTED:
			return Texts.s(&"LOG_CMD_REJECTED") % str(p["reason"])
		EventTypes.COMBAT_END:
			return Texts.s(&"LOG_COMBAT_END") % str(p["result"])
		EventTypes.LOG:
			return Texts.msg(p)
		EventTypes.ITEM_GAIN:
			return Texts.s(&"LOG_ITEM_GAIN") % [p["item_id"], int(p["count"])]
		EventTypes.XP_GAIN:
			return Texts.s(&"LOG_XP") % int(p["amount"])
	return ""
