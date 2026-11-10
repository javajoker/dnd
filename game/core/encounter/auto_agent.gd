# 托管代理（docs/framework/09-遭遇与双模式交互规范.md §9.3；docs/tech/01-技术方案讨论稿.md §6.2）
# - 与手操同一 Command 通道：产出同构命令对象 {type, actor, target, skill, item, source}，
#   仅 source="auto"——可回放、可追溯，托管得不到任何手操得不到的结果；
# - 策略链：低血用药（默认 HP<50%，阈值可配置）→ 按序技能（次数技能优先，耗尽退普攻）→ 结束回合；
#   同伴与玩家角色共用本代理（同一指令通道与行动经济，11 §5.2）；
# - 节拍下限由 shell 侧 Timer 实现（≥0.8s/动作，1×/2×），core 侧只产出命令；
# - 关键判定（死亡豁免）由状态机自动掷出并照常全屏演出，托管不跳过（09 §9.3）。
class_name AutoAgent
extends RefCounted

## HP 低于该比例时优先用药（09 §9.3：默认 50%，阈值可配置）。
var heal_threshold := 0.5

## 为当前行动单位产出下一条命令；无命令可出（非友方阶段/战斗结束）返回 {}。
func next_command(sm: EncounterSM) -> Dictionary:
	var uid := sm.current_actor_id()
	if uid == "" or sm.is_over():
		return {}
	var u := sm.get_unit(uid)
	var cmd := {"type": &"", "actor": uid, "target": "", "skill": "", "item": "", "source": &"auto"}
	# 1) 低血用药（附赠动作）
	if not bool(u["bonus_used"]) and float(u["hp"]) / float(maxi(1, int(u["max_hp"]))) < heal_threshold:
		for it: Variant in (u["items"] as Array):
			var use: Dictionary = (it as Dictionary).get("use", {})
			if int((it as Dictionary).get("count", 0)) > 0 and bool((it as Dictionary).get("pouch", true)) \
					and str(use.get("timing", "")) == "bonus_action" and use.has("heal"):
				cmd["type"] = EncounterSM.CMD_ITEM
				cmd["item"] = str((it as Dictionary)["id"])
				cmd["target"] = uid
				return cmd
	# 1.5) 治疗技能（11 §8 v1.2）：有倒地或低血队友时，先救伤最重者（倒地优先）
	if not bool(u["action_used"]):
		for sk: Variant in (u["skills"] as Array):
			var sd: Dictionary = sk
			if str(sd.get("kind", "")) != "utility" or not sd.has("heal"):
				continue
			if int((u["skill_uses"] as Dictionary).get(str(sd["id"]), -1)) == 0:
				continue
			var best := ""
			var best_ratio := heal_threshold
			for id: String in sm.get_order():
				var a := sm.get_unit(id)
				if str(a["side"]) != "party" or bool(a["dead"]) or str(a.get("kind", "")) == "escort_npc":
					continue
				if str(sd.get("target", "ally")) == "self" and id != uid:
					continue
				var ratio := -1.0 if bool(a["downed"]) else float(a["hp"]) / float(maxi(1, int(a["max_hp"])))
				if ratio < best_ratio:
					best_ratio = ratio
					best = id
			if best != "":
				cmd["type"] = EncounterSM.CMD_SKILL
				cmd["skill"] = str(sd["id"])
				cmd["target"] = best
				return cmd
	# 2) 按序技能（次数技能优先 → 耗尽退普攻，09 §9.3）
	if not bool(u["action_used"]):
		var target := sm.first_alive_enemy()
		if target != "":
			for sk: Variant in (u["skills"] as Array):
				if str((sk as Dictionary).get("kind", "attack")) != "attack":
					continue
				if int((u["skill_uses"] as Dictionary).get(str((sk as Dictionary)["id"]), -1)) == 0:
					continue
				cmd["type"] = EncounterSM.CMD_SKILL
				cmd["skill"] = str((sk as Dictionary)["id"])
				cmd["target"] = target
				return cmd
			cmd["type"] = EncounterSM.CMD_ATTACK
			cmd["target"] = target
			return cmd
	# 3) 结束回合
	cmd["type"] = EncounterSM.CMD_END_TURN
	return cmd
