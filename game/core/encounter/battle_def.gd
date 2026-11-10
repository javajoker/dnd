# 战斗定义组装器（docs/tech/04-资源与效果系统.md §2/§3/§4；docs/tech/02-内容包格式规范.md §6）
# 由内容包资源表组装 EncounterSM.begin_combat 的战斗定义：
#   遭遇 party/enemies 实例（tech/02 §6）→ characters.json / enemies.json 条目（tech/04 §1/§2）；
#   hp/ac 由规则包求值字符串公式（tech/04 §2：规则包求值，改规则包不改角色表）；
#   普攻修正/伤害骰 = 角色 basic_attack 技能的 attr 属性值与 damage（tech/04 §2 basic_attack）；
#   出战技能 = 整备选择 ∩（角色已习得 ∩ skills.json）（tech/04 §7）；
#   道具 = 整备选择 ∩ 背包持有 ∩ items.json 含 use 块（tech/04 §4）；
#   玩家模板叠加成长：属性点分配与每级 HP+2（11 §6；簿记 global.growth.*，tech/04 §8）；
#   首回合优势 = 遭遇 party_advantage 旗标声明（11 §3.1：来源由内容包声明）；
#   敌方条件削弱 = 遭遇 enemy_weaken 旗标声明（tech/02 §6：与 party_advantage 对称的难度修正）。
# 纯数据组装，零引擎依赖；任何引用缺失/公式求值失败 → ok=false 并逐条报错（引导层 fail-fast）。
class_name BattleDef
extends RefCounted

## tech/04 §3 target（数据层）→ EncounterSM target（运行时）映射。
const TARGET_MAP := {"enemy_single": "enemy", "ally_single": "ally", "self": "self"}
## 玩家模板缺省出战技能数（整备未启用时的兜底：已习得列表前 2 个，对齐 TP2 引导脚本）。
const DEFAULT_SKILL_COUNT := 2

## 角色 HP 上限唯一口径（战斗组装 / 状态栏 / 休息共用，杜绝多处重算漂移）：
## hp_formula 以模板基础属性求值；玩家模板叠加每级 HP 加值（11 §6）；同伴按 1 级。公式失败返回 1。
## pack 非空时叠加装备 HP 加值（饰物 max_hp，11 §8.1）。
static func max_hp_for(c: Dictionary, board: Board, pack: Dictionary = {}) -> int:
	var equip_hp := 0
	if not pack.is_empty() and c.has("id"):
		equip_hp = int(Equipment.modifiers(board, str(pack.get("pack_id", "")), pack.get("items", {}),
			str(c["id"]))["max_hp"])
	return _base_max_hp(c, board) + equip_hp

static func _base_max_hp(c: Dictionary, board: Board) -> int:
	var base_attrs: Dictionary = c.get("attrs", {})
	var is_player := str(c.get("kind", "")) == "player_template"
	var level := Growth.level(board) if is_player else 1
	var fvars := {"might": int(base_attrs.get("might", 0)), "finesse": int(base_attrs.get("finesse", 0)),
		"wits": int(base_attrs.get("wits", 0)), "level": level}
	var hp: Variant = LightV1.eval_formula(str(c.get("hp_formula", "10")), fvars)
	if hp == null:
		return 1
	return int(hp) + ((level - 1) * LightV1.LEVEL_HP_BONUS if is_player else 0)

## 组装战斗定义。返回 { ok, errors[], def }；def 仅在 ok 时可用。
## selection = 整备选择 {skills[], items[]}（可空 = 缺省）；board 供成长/背包/优势旗标读取（只读）。
static func assemble(pack: Dictionary, encounter_id: String, selection: Dictionary, board: Board) -> Dictionary:
	var errors: Array[String] = []
	var pack_id := str(pack.get("pack_id", ""))
	var encounters: Dictionary = pack.get("encounters", {})
	if not encounters.has(encounter_id):
		return {"ok": false, "errors": ["遭遇 '%s' 未在 encounters.json 登记（tech/02 §6）" % encounter_id], "def": {}}
	var enc: Dictionary = encounters[encounter_id]
	var characters: Dictionary = pack.get("characters", {})
	var skills: Dictionary = pack.get("skills", {})
	var enemies: Dictionary = pack.get("enemies", {})
	var items: Dictionary = pack.get("items", {})

	# ---- 队伍（tech/02 §6 party 实例 → tech/04 §2 角色条目）----
	var party: Array = []
	var party_entries: Array = enc.get("party", [])
	if party_entries.is_empty():
		errors.append("遭遇 %s 未声明 party（tech/02 §6：引导层不自动组队）" % encounter_id)
	# 分队中的小组战（15 §2.2）：party_from = "group" 时只派焦点小组的成员
	var split_party := PartySplit.new(board, pack)
	var group_members: Array = split_party.members(split_party.focus()) \
		if str(enc.get("party_from", "")) == "group" and split_party.is_split() else []
	for entry: Variant in party_entries:
		var e: Dictionary = entry
		var ref := str(e.get("ref", ""))
		if not group_members.is_empty() and not group_members.has(ref):
			continue
		if not characters.has(ref):
			errors.append("遭遇 %s party 引用未登记角色 '%s'（characters.json）" % [encounter_id, ref])
			continue
		party.append(_build_character_unit(str(e.get("id", ref)), ref, characters[ref],
			pack_id, selection, board, skills, items, encounter_id, errors))

	# ---- 敌方（tech/02 §6 enemies 实例 → tech/04 §1 敌人条目）----
	var foes: Array = []
	var enemy_entries: Array = enc.get("enemies", [])
	if ["battle", "escort", "hybrid"].has(str(enc.get("type", ""))) and enemy_entries.is_empty():
		errors.append("战斗/护送/混合遭遇 %s 未声明 enemies（tech/02 §6）" % encounter_id)
	for entry: Variant in enemy_entries:
		var e: Dictionary = entry
		var ref := str(e.get("ref", ""))
		if not enemies.has(ref):
			errors.append("遭遇 %s enemies 引用未登记敌人 '%s'（enemies.json）" % [encounter_id, ref])
			continue
		foes.append(_build_enemy_unit(str(e.get("id", ref)), enemies[ref], enemies, encounter_id, errors))

	# ---- 护送目标（tech/02 §6 escort 块 → 11 §5「遭遇定义的目标达成」）----
	var escort_def := {}
	if str(enc.get("type", "")) == "escort":
		var esc: Dictionary = enc.get("escort", {})
		var npc: Dictionary = esc.get("unit", {})
		if npc.is_empty():
			errors.append("护送遭遇 %s 缺 escort.unit（护送对象内联条目，tech/02 §6）" % encounter_id)
		elif int(esc.get("survive_rounds", 0)) < 1:
			errors.append("护送遭遇 %s escort.survive_rounds < 1（tech/02 §6）" % encounter_id)
		else:
			var npc_id := str(npc.get("id", "escort_npc"))
			# 护送对象以 kind=escort_npc 入队：不占行动轮、不可被指令、HP 不持久化（tech/02 §6）
			party.append({"id": npc_id, "name": str(npc.get("name", npc_id)), "kind": "escort_npc",
				"hp": int(npc.get("hp", 1)), "max_hp": int(npc.get("hp", 1)),
				"ac": int(npc.get("ac", 10)),
				"attrs": (npc.get("attrs", {"might": 0, "finesse": 0, "wits": 0}) as Dictionary).duplicate(),
				"attack_mod": int(npc.get("attack_mod", 0)), "damage": str(npc.get("damage", "1d4"))})
			escort_def = {"unit_id": npc_id, "survive_rounds": int(esc["survive_rounds"]),
				"failure_effects": (esc.get("failure_effects", []) as Array).duplicate(true)}

	# ---- 首回合优势（11 §3.1 内容包声明来源）----
	var adv_rounds := 0
	var adv: Dictionary = enc.get("party_advantage", {})
	if adv.has("flag"):
		var fkey := str(adv["flag"])
		if not fkey.contains("."):
			fkey = "%s.%s" % [pack_id, fkey]
		if bool(board.read(fkey)):
			adv_rounds = int(adv.get("rounds", 1))

	# ---- 敌方条件削弱（tech/02 §6 enemy_weaken：旗标驱动的难度修正，与 party_advantage 对称；
	# 如战役书 §5 手下留情 → N4-1 税吏证词 Boss 攻击修正 -2）----
	var weaken: Dictionary = enc.get("enemy_weaken", {})
	if weaken.has("flag"):
		var wkey := str(weaken["flag"])
		if not wkey.contains("."):
			wkey = "%s.%s" % [pack_id, wkey]
		if bool(board.read(wkey)):
			for u: Variant in foes:
				(u as Dictionary)["attack_mod"] = int((u as Dictionary)["attack_mod"]) \
					+ int(weaken.get("attack_mod", 0))

	# ---- 平衡微调（tech/02 §6 enemy_mods）：本场全部敌人 HP / 攻击修正加值——保留战役书阵容只调强度 ----
	var mods: Dictionary = enc.get("enemy_mods", {})
	if not mods.is_empty():
		for u: Variant in foes:
			var ud: Dictionary = u
			ud["hp"] = int(ud["hp"]) + int(mods.get("hp", 0))
			ud["max_hp"] = int(ud["max_hp"]) + int(mods.get("hp", 0))
			ud["attack_mod"] = int(ud["attack_mod"]) + int(mods.get("attack_mod", 0))

	var loot: Array = []
	for l: Variant in enc.get("loot", []):
		loot.append({"item": str((l as Dictionary).get("item", "")), "n": int((l as Dictionary).get("n", 1))})
	# ---- 背包与军械（11 §8.1/§8.2）：整备外的可用道具（取用 = 动作）+ 可在战斗中换上的武器 ----
	var pack_items := _pack_items(selection, board, items, pack_id)
	var armory := _armory(pack, board)
	var def := {"party": party, "enemies": foes, "party_advantage_rounds": adv_rounds,
		"loot": loot, "xp": int(enc.get("xp", 0)),
		"gold": int(enc.get("gold", 0))} # 胜利金币（11 §7.3 战利金；包命名空间 <pack>.gold）
	if not escort_def.is_empty():
		def["escort"] = escort_def
	if not pack_items.is_empty():
		def["pack_items"] = pack_items
	if not armory.is_empty():
		def["armory"] = armory
	else:
		for u: Variant in party:
			(u as Dictionary).erase("weapon_base") # 无可换武器：不携带换武器基准（def 结构保持精简）
	return {"ok": errors.is_empty(), "errors": errors, "def": def}

## 背包道具 = 持有且含 use 块、未放进快取袋（整备 items）的道具；战斗中取用耗 1 动作（11 §8.2）。
static func _pack_items(selection: Dictionary, board: Board, items: Dictionary, pack_id: String = "") -> Array:
	var pouch: Array = selection.get("items", [])
	var share := PartySplit.new(board, {"pack_id": pack_id})
	var out: Array = []
	for iid: String in items.keys():
		var it: Dictionary = items[iid]
		if not it.has("use") or pouch.has(iid) or share.available(iid) <= 0:
			continue
		if str((it["use"] as Dictionary).get("timing", "")) == "out_of_combat":
			continue
		out.append({"id": iid, "name": str(it.get("name", iid)), "count": share.available(iid),
			"use": (it["use"] as Dictionary).duplicate(true), "pouch": false})
	return out

## 军械 = 背包里的武器（每件带剩余可分配数）；战斗中换武器 = 物品互动（每回合一次，11 §8.1）。
static func _armory(pack: Dictionary, board: Board) -> Array:
	var items: Dictionary = pack.get("items", {})
	var out: Array = []
	for iid: String in items.keys():
		var eb := Equipment.equip_block(items, iid)
		if eb.is_empty() or not Equipment.COMBAT_SWAPPABLE.has(str(eb.get("slot", ""))) or not board.has_item(iid):
			continue
		out.append({"id": iid, "name": str((items[iid] as Dictionary).get("name", iid)),
			"count": board.item_count(iid), "holders": Equipment.holders(board, pack, iid),
			"equip": eb.duplicate(true)})
	return out

# ---------------------------------------------------------------- 单位组装

static func _build_character_unit(inst_id: String, ref: String, c: Dictionary, pack_id: String,
		selection: Dictionary, board: Board, skills: Dictionary, items: Dictionary,
		encounter_id: String, errors: Array[String]) -> Dictionary:
	var kind := str(c.get("kind", ""))
	var base_attrs: Dictionary = c.get("attrs", {})
	var alloc: Dictionary = {}
	var hp_bonus := 0
	var level := 1
	if kind == "player_template":
		# 成长叠加（11 §6；簿记归框架全局键 global.growth.*，tech/04 §8）：
		# 属性点分配进最终属性；HP 加值只加 HP（11 §6 与属性点解耦）
		alloc = Growth.attrs_map(board)
		level = Growth.level(board)
		hp_bonus = (level - 1) * LightV1.LEVEL_HP_BONUS
	# hp/ac：公式以模板基础属性求值（属性点分配不影响 hp/ac 基值，11 §6 成长只走 hp_bonus）
	var fvars := {"might": int(base_attrs.get("might", 0)), "finesse": int(base_attrs.get("finesse", 0)),
		"wits": int(base_attrs.get("wits", 0)), "level": level}
	var hp: Variant = LightV1.eval_formula(str(c.get("hp_formula", "")), fvars)
	if hp == null:
		errors.append("角色 %s hp_formula 求值失败：'%s'（tech/04 §2 白名单 might/finesse/wits/level）"
			% [inst_id, str(c.get("hp_formula", ""))])
		hp = 1
	var ac: Variant = LightV1.eval_formula(str(c.get("ac_formula", "")), fvars)
	if ac == null:
		errors.append("角色 %s ac_formula 求值失败：'%s'（tech/04 §2）" % [inst_id, str(c.get("ac_formula", ""))])
		ac = 10
	var final_attrs := {}
	for a: String in ["might", "finesse", "wits"]:
		final_attrs[a] = int(base_attrs.get(a, 0)) + int(alloc.get(a, 0))
	# 普攻修正/伤害骰 = basic_attack 技能（tech/04 §2）
	var atk_mod := 0
	var dmg := "1d4"
	var ba_id := str(c.get("basic_attack", ""))
	if ba_id.is_empty():
		errors.append("角色 %s 缺 basic_attack（tech/04 §2）" % inst_id)
	elif not skills.has(ba_id):
		errors.append("角色 %s basic_attack 引用未登记技能 '%s'（skills.json）" % [inst_id, ba_id])
	else:
		var ba: Dictionary = skills[ba_id]
		atk_mod = int(final_attrs.get(str(ba.get("attr", "might")), 0))
		dmg = str(ba.get("damage", dmg))
	# HP 跨遭遇持久化（11 §7.1）：<pack>.hp.<char_id> 有记录则以此开局（钳 1~上限；
	# 死亡记录 0 按 1 HP 抬升——轻规则无永久死亡系统），无记录 = 满血公式值
	# 装备修正（11 §8.1）：AC / 攻击加值 / 武器伤害骰替换（保留原修正）/ 饰物 HP 上限
	var eq_mods := Equipment.modifiers(board, pack_id, items, ref)
	var base_atk := atk_mod
	var base_dmg := dmg
	ac = int(ac) + int(eq_mods["ac"])
	atk_mod += int(eq_mods["attack"])
	dmg = Equipment.weapon_damage(dmg, str(eq_mods["damage_die"]))
	var max_hp := int(hp) + hp_bonus + int(eq_mods["max_hp"])
	var hp_now := max_hp
	var hp_key := "%s.hp.%s" % [pack_id, ref]
	if board.has(hp_key):
		hp_now = clampi(int(board.read(hp_key)), 1, max_hp)
	var unit := {
		"id": inst_id,
		"ref": ref, # characters.json 条目 id：HP 持久化写板键（11 §7.1 <ns>.hp.<char_id>）
		"name": str(c.get("name", inst_id)),
		"kind": "player" if kind == "player_template" else kind, # 运行时 kind：player/companion（11 §5.2）
		"hp": hp_now, "max_hp": max_hp, "ac": int(ac),
		"attrs": final_attrs, "attack_mod": atk_mod, "damage": dmg,
	}
	# art_ref 纯呈现透传（tech/05 §6；core 只搬数据不引用渲染 API，缺图壳层静默兜底）
	if c.has("art_ref"):
		unit["art_ref"] = str(c["art_ref"])
	# 装备呈现与战斗换武器基准（无装备不加键：既有 def 结构不变）
	var eq := Equipment.equipped(board, pack_id, items, ref)
	if not eq.is_empty():
		unit["equipment"] = eq
		if eq.has("weapon"):
			unit["weapon"] = str(eq["weapon"])
	# 换武器基准 = 无武器时的攻击修正（含其他槽加值）与普攻伤害式；assemble 在无军械时剔除
	unit["weapon_base"] = {"attack_mod": base_atk + int(eq_mods["attack"])
		- int(Equipment.equip_block(items, str(eq_mods["weapon"])).get("attack", 0)), "damage": base_dmg}
	# 出战技能：整备选择 ∩ 已习得（tech/04 §7）；selection.skills_by_char 按角色备战（09 §9.1 逐角色整备）；
	# 同伴未单独指定 = 恒带全部已习得（招牌技能，11 §5.2）
	var learned: Array = c.get("skills", [])
	var picked: Array = []
	var by_char: Dictionary = selection.get("skills_by_char", {})
	if by_char.has(ref):
		picked = by_char[ref]
	elif kind == "player_template":
		picked = selection.get("skills", [])
		if picked.is_empty():
			picked = learned.slice(0, DEFAULT_SKILL_COUNT) # 整备未启用兜底（TP2 引导脚本对齐）
	else:
		picked = learned
	var unit_skills: Array = []
	for sid: Variant in picked:
		var skill_id := str(sid)
		if not learned.has(skill_id):
			continue # 未习得不进战斗 def（整备层已校验槽位，防御式跳过）
		if not skills.has(skill_id):
			errors.append("角色 %s 出战技能 '%s' 未在 skills.json 登记" % [inst_id, skill_id])
			continue
		unit_skills.append(runtime_skill(skills[skill_id]))
	unit["skills"] = unit_skills
	# 出战道具：整备选择 ∩ 背包持有 ∩ items.json 含 use 块（tech/04 §4；仅玩家模板携带，
	# 键存在性与 TP2 引导脚本结构对齐：玩家单位恒有 items 键，同伴无）
	if kind == "player_template":
		var unit_items: Array = []
		for iid: Variant in selection.get("items", []):
			var item_id := str(iid)
			if not items.has(item_id) or not (items[item_id] as Dictionary).has("use"):
				continue
			var avail := PartySplit.new(board, {"pack_id": pack_id}).available(item_id) # 分队时只用本组那一份（15 §3.3）
			if avail <= 0:
				continue
			unit_items.append({"id": item_id, "name": str((items[item_id] as Dictionary).get("name", item_id)),
				"count": avail,
				"use": ((items[item_id] as Dictionary)["use"] as Dictionary).duplicate(true)})
		unit["items"] = unit_items
	return unit

static func _build_enemy_unit(inst_id: String, def: Dictionary, enemies: Dictionary, encounter_id: String,
		errors: Array[String]) -> Dictionary:
	var attrs := {"might": 0, "finesse": 0, "wits": 0}
	for a: String in (def.get("attrs", {}) as Dictionary).keys():
		attrs[a] = int((def["attrs"] as Dictionary)[a])
	var unit := {
		"id": inst_id,
		"name": str(def.get("name", inst_id)),
		"hp": int(def.get("hp", 1)), "max_hp": int(def.get("hp", 1)),
		"ac": int(def.get("ac", 10)),
		"attrs": attrs,
		"attack_mod": int(def.get("attack_mod", 0)),
		"damage": str(def.get("damage", "1d4")),
	}
	if def.has("art_ref"): # art_ref 纯呈现透传（tech/05 §6）
		unit["art_ref"] = str(def["art_ref"])
	if def.has("attack_fx"): # 普攻特效纯呈现透传（ActionFx；缺省按阵营推断）
		unit["attack_fx"] = str(def["attack_fx"])
	var unit_skills: Array = []
	for sk: Variant in def.get("skills", []):
		var s: Dictionary = sk
		var out := {"id": str(s.get("id", "")), "name": str(s.get("name", s.get("id", ""))),
			"kind": str(s.get("kind", "attack"))}
		if s.has("attr"):
			out["attr"] = str(s["attr"])
		if s.has("damage"):
			out["damage"] = str(s["damage"])
		if s.has("uses"):
			out["uses"] = int(s["uses"])
		if s.has("cooldown"):
			out["cooldown"] = int(s["cooldown"])
		for fk2: String in ["fx", "fx_color"]: # 技能特效纯呈现透传（ActionFx）
			if s.has(fk2):
				out[fk2] = str(s[fk2])
		if s.has("save"):
			var sv: Dictionary = s["save"]
			out["save"] = {"attr": str(sv.get("attr", "finesse")), "dc": int(sv.get("dc", 12)),
				"on_success": str(sv.get("on_success", "half"))}
		if str(s.get("kind", "")) == "aoe" and not (s.get("save", {}) as Dictionary).has("dc"):
			errors.append("遭遇 %s 敌人 %s 范围技能 '%s' 缺 save.dc（11 §5.1）"
				% [encounter_id, inst_id, str(s.get("id", ""))])
		# 转阶段自身强化（story/03 §3.1：buff 技能 effect 块透传）
		if s.has("effect"):
			out["effect"] = (s["effect"] as Dictionary).duplicate(true)
		# 召唤技能（story/03 §3.2）：ref 引用的敌人条目内联为 summon 模板（fail-fast）
		if str(s.get("kind", "")) == "summon":
			var sref := str(s.get("ref", ""))
			if not enemies.has(sref):
				errors.append("遭遇 %s 敌人 %s 召唤技能 '%s' 引用未登记敌人 '%s'（enemies.json）"
					% [encounter_id, inst_id, str(s.get("id", "")), sref])
			else:
				var t: Dictionary = enemies[sref]
				out["summon"] = {"ref": sref, "name": str(t.get("name", sref)),
					"hp": int(t.get("hp", 1)), "ac": int(t.get("ac", 10)),
					"attrs": (t.get("attrs", {"might": 0, "finesse": 0, "wits": 0}) as Dictionary).duplicate(),
					"attack_mod": int(t.get("attack_mod", 0)), "damage": str(t.get("damage", "1d4"))}
				if t.has("art_ref"): # 召唤模板同透传（story/03 §3.2 召唤幼体同享单位图，tech/05 §6）
					(out["summon"] as Dictionary)["art_ref"] = str(t["art_ref"])
				out["count"] = int(s.get("count", 1))
		unit_skills.append(out)
	if not unit_skills.is_empty():
		unit["skills"] = unit_skills
	# 回合行为脚本（story/03 §2：every_n_rounds / when_hp_below+once；引用的技能须为本条目自带）
	if def.has("behavior"):
		var behavior: Array = []
		for b: Variant in (def["behavior"] as Array):
			var bd: Dictionary = b
			var entry := {"skill": str(bd.get("skill", ""))}
			if bd.has("every_n_rounds"):
				entry["every_n_rounds"] = int(bd["every_n_rounds"])
			elif bd.has("when_hp_below"):
				entry["when_hp_below"] = float(bd["when_hp_below"])
				entry["once"] = bool(bd.get("once", false))
			else:
				errors.append("遭遇 %s 敌人 %s behavior 条目缺触发器（story/03 §2：every_n_rounds / when_hp_below）"
					% [encounter_id, inst_id])
			var known := false
			for sk2: Variant in unit_skills:
				if str((sk2 as Dictionary)["id"]) == str(entry["skill"]):
					known = true
			if not known:
				errors.append("遭遇 %s 敌人 %s behavior 引用非自带技能 '%s'（story/03 §2）"
					% [encounter_id, inst_id, str(entry["skill"])])
			behavior.append(entry)
		unit["behavior"] = behavior
	return unit

## tech/04 §3 技能条目 → 运行时技能结构（uses_per_encounter→uses；target 枚举映射；
## gesture 为呈现层提示不进战斗 def）。
static func runtime_skill(s: Dictionary) -> Dictionary:
	var out := {"id": str(s.get("id", "")), "name": str(s.get("name", s.get("id", ""))),
		"kind": str(s.get("kind", "attack"))}
	if s.has("attr"):
		out["attr"] = str(s["attr"])
	if s.has("damage"):
		out["damage"] = str(s["damage"])
	if s.get("uses_per_encounter") != null:
		out["uses"] = int(s["uses_per_encounter"])
	out["target"] = str(TARGET_MAP.get(str(s.get("target", "enemy_single")), "enemy"))
	if s.has("effect"):
		out["effect"] = (s["effect"] as Dictionary).duplicate(true)
	if s.has("heal"):
		out["heal"] = str(s["heal"]) # 治疗技能（utility + heal 骰）
	if bool(s.get("adv", false)):
		out["adv"] = true # 攻击自带优势（如偷袭）
	for fk: String in ["fx", "fx_color"]: # 技能特效纯呈现透传（ActionFx；core 不读）
		if s.has(fk):
			out[fk] = str(s[fk])
	if s.has("save"):
		out["save"] = (s["save"] as Dictionary).duplicate(true)
	return out
