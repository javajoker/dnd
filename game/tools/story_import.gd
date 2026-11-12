# Story Script 导入器（docs/en/tech/10-story-script-format.md）：把纯文本"故事脚本"（.story.md）转成内容包数据。
# 分工：创作（世界观 / 剧情 / 文案）是作者或 AI 写脚本；本工具只做确定性的结构转换 + 校验。
#
# 用法：
#   godot --headless --path game -s tools/story_import.gd -- <script.story.md> [--out <pack dir>] [--dry-run]
#   缺省输出 res://packs/<pack_id>/。写出 / 合并：manifest.json（front matter 合入）、nodes.json、flags.json、
#   encounters.json（保留已调好的 enemy_mods / pos）、endings.json、lore.json、texts/<source_locale>.json（长文本）。
#   不碰设计数据：characters / enemies / items / skills / classes / maps / tables（由世界设计者维护）。
#   写完即加载 + packlint（支线按嫁接口径），打印 FAIL / WARN 与缺失引用。
#
# 语法速览（完整规范见 tech/10）：
#   ---  front matter（key: value，值可为 JSON）---
#   # ACT <id>: <标题> | role: <角色> | mode: <choice|forced_time|…>
#   ## <节点 id> <类型>: <标题>        类型 ∈ scene hub check battle dialog explore rest branch ending map site
#   正文段落…（空行 = 分段）
#   > on_enter: xp 40, rep.salvage +1, write met_keeper, give heal_potion x2, lore keeper_log, clock +1
#   > encounter: medium | enemies ink_imp x2, ink_fiend | party player_blank, companion_kelan | xp 60 | gold 12 | loot ink_core
#   > ending: default | if rep.salvage >= 2        （ending 节点：缺省结局 / 达成条件）
#   > raw: {"任意": "节点字段"}
#   - choice "标签" -> 目标 [if 条件] [do 效果]
#   - check 技能 难度 "标签" -> 成功 | fail 失败 [do 成功效果] [fail_do 失败效果] [if 条件]
#   - item 道具 "标签" -> 目标 [if 条件] [do 效果]
#   - raw {"type": "doom_clock", "at": 2, "to": "N1-7", "once": true}
#   ## LORE <id> [series]: <标题>      图鉴条目（正文写入 texts，lore.json 记 text_ref）
extends SceneTree

const NODE_TYPES := ["scene", "hub", "check", "battle", "dialog", "explore", "rest", "branch", "ending", "map", "site"]
const DIFFICULTIES := ["easy", "medium", "hard"]
const LONG_TEXT := 140 # 超过即外置到 texts（text_ref），summary 取首句

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		print("用法：-s tools/story_import.gd -- <script.story.md> [--out <pack dir>] [--dry-run]")
		quit(1)
		return
	var src: String = a[0]
	var out := ""
	var dry := a.has("--dry-run")
	var oi := a.find("--out")
	if oi >= 0 and oi + 1 < a.size():
		out = a[oi + 1]
	src = resolve_path(src)
	if not FileAccess.file_exists(src):
		push_error("找不到脚本 / script not found：%s（试过：原样、game/ 下、仓库根下）" % a[0])
		quit(1)
		return
	var res := parse_script(FileAccess.get_file_as_string(src))
	for w: String in res["warnings"]:
		print("  [WARN] ", w)
	if not (res["errors"] as Array).is_empty():
		for e: String in res["errors"]:
			print("  [ERROR] ", e)
		print("== 导入失败：%d 处脚本错误（未写任何文件）==" % (res["errors"] as Array).size())
		quit(1)
		return
	var pack_id := str((res["manifest"] as Dictionary).get("pack_id", ""))
	if out == "":
		out = "res://packs/%s" % pack_id
	print("== %s → %s：%d 节点 / %d 遭遇 / %d 旗标 / %d 结局 / %d 图鉴 ==" % [src.get_file(), out,
		(res["nodes"]["nodes"] as Array).size(), (res["encounters"] as Array).size(), (res["flags"] as Array).size(),
		(res["endings"] as Array).size(), (res["lore"] as Array).size()])
	if dry:
		print(JSON.stringify(res["nodes"], "  ").left(3000))
		quit(0)
		return
	write_pack(res, out)
	var report := check_pack(out)
	for line: String in report["lines"]:
		print(line)
	print("== 导入完成：packlint %d FAIL / %d WARN ==" % [int(report["fail"]), int(report["warn"])])
	quit(0 if int(report["fail"]) == 0 else 2)

## 脚本路径：原样 → 相对 game/（Godot 进程的工作目录）→ 相对仓库根（从仓库根运行时传入 docs/… 也能找到）。
static func resolve_path(src: String) -> String:
	var root := ProjectSettings.globalize_path("res://")
	for cand: String in [src, root.path_join(src), root.path_join("..").path_join(src).simplify_path()]:
		if FileAccess.file_exists(cand):
			return cand
	return src

# ---------------------------------------------------------------- 解析

## 脚本 → { manifest, nodes{acts,nodes}, encounters[], flags[], endings[], lore[], texts{key: text}, errors[], warnings[] }。
static func parse_script(text: String) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var manifest := {}
	var acts: Array = []
	var nodes: Array = []
	var encounters: Array = []
	var endings: Array = []
	var lore: Array = []
	var texts := {}
	var lines := text.replace("\r\n", "\n").split("\n")
	var i := 0
	# front matter
	if lines.size() > 0 and lines[0].strip_edges() == "---":
		i = 1
		while i < lines.size() and lines[i].strip_edges() != "---":
			var ln := lines[i]
			var c := ln.find(":")
			if c > 0 and not ln.strip_edges().begins_with("#"):
				var k := ln.substr(0, c).strip_edges()
				var v := ln.substr(c + 1).strip_edges()
				manifest[k] = _value(v)
			i += 1
		i += 1
	if str(manifest.get("pack_id", "")) == "":
		errors.append("front matter 缺 pack_id")
	var pack_type := str(manifest.get("pack_type", "campaign"))
	if not ["campaign", "arc", "subgame"].has(pack_type):
		errors.append("pack_type 须为 campaign / arc / subgame（得到 %s）" % pack_type)
	var default_party: Array = manifest.get("default_party", [])
	var cur_act := ""
	var node: Dictionary = {}
	var para: Array[String] = []
	var cur_lore: Dictionary = {}
	var lore_para: Array[String] = []
	var in_comment := false
	while i < lines.size():
		var raw: String = lines[i]
		var line := raw.strip_edges()
		i += 1
		if in_comment or line.begins_with("<!--"): # HTML 注释块（可跨行）整段跳过
			in_comment = not line.contains("-->")
			continue
		if line.begins_with("# ACT ") or line.begins_with("# act "):
			_close_node(node, para, texts, warnings)
			node = {}
			para = []
			_close_lore(cur_lore, lore_para, lore, texts)
			cur_lore = {}
			lore_para = []
			var parts := line.substr(6).split("|")
			var head := parts[0]
			var c2 := head.find(":")
			var act := {"id": head.substr(0, c2).strip_edges() if c2 > 0 else head.strip_edges(),
				"title": head.substr(c2 + 1).strip_edges() if c2 > 0 else ""}
			for p: String in parts.slice(1):
				var c3 := p.find(":")
				if c3 > 0:
					act[p.substr(0, c3).strip_edges()] = _value(p.substr(c3 + 1).strip_edges())
			if not act.has("mode"):
				act["mode"] = "choice"
			acts.append(act)
			cur_act = str(act["id"])
			continue
		if line.begins_with("## LORE ") or line.begins_with("## lore "):
			_close_node(node, para, texts, warnings)
			node = {}
			para = []
			_close_lore(cur_lore, lore_para, lore, texts)
			lore_para = []
			var rest := line.substr(8)
			var c4 := rest.find(":")
			var idpart := (rest.substr(0, c4) if c4 > 0 else rest).strip_edges().split(" ", false)
			cur_lore = {"id": idpart[0], "series": idpart[1] if idpart.size() > 1 else "",
				"title": rest.substr(c4 + 1).strip_edges() if c4 > 0 else idpart[0]}
			continue
		if line.begins_with("## "):
			_close_node(node, para, texts, warnings)
			_close_lore(cur_lore, lore_para, lore, texts)
			cur_lore = {}
			lore_para = []
			para = []
			var rest2 := line.substr(3)
			var c5 := rest2.find(":")
			var idtype := (rest2.substr(0, c5) if c5 > 0 else rest2).strip_edges().split(" ", false)
			if idtype.size() < 2:
				errors.append("第 %d 行：节点头须为 \"## <id> <类型>: <标题>\"" % i)
				node = {}
				continue
			var ntype := idtype[1].to_lower()
			if not NODE_TYPES.has(ntype):
				errors.append("第 %d 行：节点 %s 类型 '%s' 非法（%s）" % [i, idtype[0], ntype, ", ".join(NODE_TYPES)])
			if cur_act == "":
				errors.append("第 %d 行：节点 %s 之前没有 # ACT" % [i, idtype[0]])
			node = {"id": idtype[0], "act": cur_act, "type": ntype,
				"title": rest2.substr(c5 + 1).strip_edges() if c5 > 0 else idtype[0], "edges": []}
			nodes.append(node)
			if ntype == "ending":
				endings.append({"id": idtype[0], "title": node["title"], "hidden": false, "default": false,
					"conditions": {}, "_node": node})
			continue
		if not cur_lore.is_empty():
			if line == "" and not lore_para.is_empty() and lore_para.back() != "":
				lore_para.append("")
			elif line != "":
				lore_para.append(line)
			continue
		if node.is_empty():
			if line != "" and not line.begins_with("<!--"):
				warnings.append("第 %d 行：节点外的文字被忽略：%s" % [i, line.left(40)])
			continue
		if line.begins_with(">"):
			var d := line.substr(1).strip_edges()
			var c6 := d.find(":")
			if c6 <= 0:
				errors.append("第 %d 行：指令须为 \"> 名称: 值\"" % i)
				continue
			var dk := d.substr(0, c6).strip_edges().to_lower()
			var dv := d.substr(c6 + 1).strip_edges()
			match dk:
				"on_enter":
					node["on_enter"] = (node.get("on_enter", []) as Array) + _effects(dv, i, errors)
				"encounter":
					var enc := _encounter(str(node["id"]), dv, default_party, i, errors)
					if not enc.is_empty():
						encounters.append(enc)
						node["encounter"] = enc["id"]
				"ending":
					for en: Dictionary in endings:
						if en["id"] == node["id"]:
							for part: String in dv.split("|"):
								var p2 := part.strip_edges()
								if p2 == "default":
									en["default"] = true
								elif p2 == "hidden":
									en["hidden"] = true
								elif p2.begins_with("if "):
									en["conditions"] = _cond(p2.substr(3), i, errors)
				"map", "site":
					node[dk] = dv
				"raw":
					var rv: Variant = JSON.parse_string(dv)
					if rv is Dictionary:
						node.merge(rv, true)
					else:
						errors.append("第 %d 行：> raw 须为 JSON 对象" % i)
				_:
					errors.append("第 %d 行：未知指令 '%s'（on_enter / encounter / ending / map / site / raw）" % [i, dk])
			continue
		if line.begins_with("- "):
			var edge := _edge(line, i, errors)
			if not edge.is_empty():
				(node["edges"] as Array).append(edge)
			continue
		if line == "":
			if not para.is_empty() and para.back() != "":
				para.append("")
			continue
		para.append(line)
	_close_node(node, para, texts, warnings)
	_close_lore(cur_lore, lore_para, lore, texts)
	# 结局：正文作 content（长文本外置）
	for en: Dictionary in endings:
		var n: Dictionary = en["_node"]
		en.erase("_node")
		var tk := "node.%s.text" % str(n["id"])
		if texts.has(tk):
			en["text_ref"] = "#" + tk
			en["content"] = str(n.get("summary", ""))
		else:
			en["content"] = str(n.get("summary", ""))
	if pack_type == "campaign" and not endings.is_empty() and not endings.any(func(e: Dictionary) -> bool: return bool(e["default"])):
		endings[endings.size() - 1]["default"] = true
		warnings.append("没有 > ending: default，已把最后一个结局设为缺省结局")
	# 旗标台账：write 效果 = 写者；flag.* 条件 = 读者（含支线嫁接入口边的 requires）
	var flags := _flags(nodes, encounters)
	var g_req: Dictionary = ((manifest.get("graft", {}) as Dictionary).get("requires", {}) as Dictionary)
	g_req.merge((((manifest.get("graft", {}) as Dictionary).get("edge", {}) as Dictionary).get("requires", {}) as Dictionary))
	for ck: Variant in g_req.keys():
		if str(ck).begins_with("flag.") and str(ck).count(".") == 1:
			var fid := str(ck).substr(5)
			var found := false
			for fl: Dictionary in flags:
				if fl["id"] == fid:
					(fl["readers"] as Array).append("graft")
					found = true
			if not found:
				flags.append({"id": fid, "name": fid, "type": "bool", "default": false, "writers": [], "readers": ["graft"]})
	# 节点 id 唯一 + 目标存在（支线可指向宿主节点：只告警）
	var ids := {}
	for n2: Dictionary in nodes:
		if ids.has(n2["id"]):
			errors.append("节点 id 重复：%s" % str(n2["id"]))
		ids[n2["id"]] = true
	for n3: Dictionary in nodes:
		for e: Dictionary in n3["edges"]:
			for key: String in ["to", "success", "failure"]:
				if e.has(key) and not ids.has(str(e[key])):
					if pack_type == "arc":
						warnings.append("节点 %s 指向本包外节点 %s（支线回宿主：请确认宿主存在该节点）" % [n3["id"], e[key]])
					else:
						errors.append("节点 %s 的出边指向不存在的节点 %s" % [n3["id"], e[key]])
	# manifest 缺省
	var m := manifest.duplicate(true)
	m.erase("default_party")
	if not m.has("name"):
		m["name"] = str(m.get("pack_id", ""))
	if not m.has("namespace"):
		m["namespace"] = str(m.get("pack_id", ""))
	m["pack_type"] = pack_type
	for kv: Array in [["pack_version", 1], ["min_framework_version", "1.0.0"], ["rule_pack", {"id": "light", "min_version": 1}],
			["presentation", {"mode": "choice"}], ["source_locale", "en"]]:
		if not m.has(kv[0]):
			m[kv[0]] = kv[1]
	if not m.has("locales"):
		m["locales"] = [str(m["source_locale"])]
	if not m.has("node_budget"):
		m["node_budget"] = nodes.size() + 4
	if pack_type == "arc" and not m.has("graft"):
		errors.append("支线（pack_type: arc）须在 front matter 写 graft: {\"into\", \"node\", \"edge\"}（tech/02 §2.6）")
	if pack_type == "subgame" and not m.has("subgame"):
		m["subgame"] = {"rules_override": {}, "gold_reward": [], "stat_keys":
			{"wins": "%s.wins" % m["namespace"], "best": "%s.best" % m["namespace"]}}
		warnings.append("子游戏缺 subgame 块：已按缺省生成（tech/02 §2.5）")
	if pack_type == "arc" and m.has("graft") and (m["graft"] as Dictionary).has("label") and not (m["graft"] as Dictionary).has("edge"):
		# 简写：graft: {"into", "node", "label", "to"?, "requires"?} → 标准 edge 块
		var g: Dictionary = m["graft"]
		var ge := {"type": "choice", "label": str(g["label"]), "to": str(g.get("to", nodes[0]["id"] if not nodes.is_empty() else ""))}
		if g.has("item"): # 道具门：持有该道具时才显形（tech/02 §4.3）
			ge["type"] = "item"
			ge["item"] = str(g["item"])
		if g.has("requires"):
			ge["requires"] = g["requires"]
		m["graft"] = {"into": str(g["into"]), "node": str(g["node"]), "edge": ge}
	return {"manifest": m, "nodes": {"acts": acts, "nodes": nodes}, "encounters": encounters, "flags": flags,
		"endings": endings, "lore": lore, "texts": texts, "errors": errors, "warnings": warnings}

static func _close_node(node: Dictionary, para: Array[String], texts: Dictionary, warnings: Array[String]) -> void:
	if node.is_empty():
		return
	while not para.is_empty() and para.back() == "":
		para.pop_back()
	var body := "\n".join(para).replace("\n\n", "\n")
	if body == "":
		node["summary"] = str(node["title"])
		return
	if body.length() > LONG_TEXT:
		var key := "node.%s.text" % str(node["id"])
		texts[key] = body
		node["text_ref"] = "#" + key
		node["summary"] = _first_sentence(body)
	else:
		node["summary"] = body
	if (node["edges"] as Array).is_empty() and str(node["type"]) != "ending":
		warnings.append("节点 %s 没有出边（非结局节点会成为死路，packlint V1）" % str(node["id"]))

static func _close_lore(cur: Dictionary, para: Array[String], lore: Array, texts: Dictionary) -> void:
	if cur.is_empty():
		return
	while not para.is_empty() and para.back() == "":
		para.pop_back()
	var entry := {"id": cur["id"], "title": cur["title"], "source": ""}
	if str(cur["series"]) != "":
		entry["series"] = cur["series"]
	if not para.is_empty():
		var key := "lore.%s" % str(cur["id"])
		texts[key] = "\n".join(para).replace("\n\n", "\n")
		entry["text_ref"] = "#" + key
	lore.append(entry)

static func _first_sentence(s: String) -> String:
	var first := s.split("\n")[0]
	for mark: String in ["。", ". ", "！", "! ", "？", "? "]:
		var p := first.find(mark)
		if p > 0 and p < 120:
			return first.substr(0, p + mark.length()).strip_edges()
	if first.length() <= 120:
		return first
	# 无句号可切：在 120 字内最后一个空格处截断加省略号（不切半个词；无空格的 CJK 直接截）
	var cut := first.left(120)
	var sp := cut.rfind(" ")
	return (cut.left(sp) if sp > 60 else cut).strip_edges().trim_suffix(",") + "…"

static func _value(v: String) -> Variant:
	if v.begins_with("{") or v.begins_with("[") or v.begins_with("\"") or v == "true" or v == "false" or v.is_valid_float():
		var p: Variant = JSON.parse_string(v)
		if p != null:
			return p
	return v

## 效果串 → 效果数组（tech/02 §4.6）。
static func _effects(s: String, line: int, errors: Array[String]) -> Array:
	var out: Array = []
	var re_num := RegEx.create_from_string("^(xp|gold|clock|inspiration|alignment|watch)\\s*([+-]?\\d+)$")
	var re_pref := RegEx.create_from_string("^((?:rep|bond|clock)\\.[\\w-]+)\\s*([+-]?\\d+)$")
	var re_item := RegEx.create_from_string("^(give|take)\\s+([\\w-]+)(?:\\s*x(\\d+))?$")
	var re_word := RegEx.create_from_string("^(lore|reveal)\\s+([\\w.-]+)$")
	var re_write := RegEx.create_from_string("^write\\s+([\\w-]+)(?:\\s*=\\s*(.+))?$")
	for tok: String in s.split(","):
		var t := tok.strip_edges()
		if t == "":
			continue
		var m := re_num.search(t)
		if m != null:
			out.append({m.get_string(1): int(m.get_string(2))})
			continue
		m = re_pref.search(t)
		if m != null:
			out.append({m.get_string(1): int(m.get_string(2))})
			continue
		m = re_item.search(t)
		if m != null:
			var n := int(m.get_string(3)) if m.get_string(3) != "" else 1
			for _k: int in n:
				out.append({("give_item" if m.get_string(1) == "give" else "remove_item"): m.get_string(2)})
			continue
		m = re_word.search(t)
		if m != null:
			out.append({m.get_string(1): m.get_string(2)})
			continue
		m = re_write.search(t)
		if m != null:
			var eff := {"write": m.get_string(1), "value": true}
			if m.get_string(2) != "":
				eff["value"] = _value(m.get_string(2).strip_edges())
			out.append(eff)
			continue
		errors.append("第 %d 行：看不懂的效果 '%s'（xp / gold / clock / inspiration / alignment / rep.X / bond.X / give / take / lore / reveal / write）" % [line, t])
	return out

## 条件串 → 条件字典（逗号 = 且；tech/02 §4.6）。
static func _cond(s: String, line: int, errors: Array[String]) -> Dictionary:
	var out := {}
	var re_cmp := RegEx.create_from_string("^([\\w.-]+)\\s*(>=|<=|==|!=|>|<)\\s*(-?\\d+)$")
	var re_eq := RegEx.create_from_string("^(hero_class|background|lead|in_group|thread)\\s*=\\s*([\\w-]+)$")
	for tok: String in s.split(","):
		var t := tok.strip_edges()
		if t == "":
			continue
		var neg := t.begins_with("not ")
		if neg:
			t = t.substr(4).strip_edges()
		var m := re_cmp.search(t)
		if m != null:
			out[m.get_string(1)] = {m.get_string(2): int(m.get_string(3))}
			continue
		m = re_eq.search(t)
		if m != null:
			out[m.get_string(1)] = m.get_string(2)
			continue
		if t.begins_with("flag.") or t.begins_with("item."):
			out[t] = not neg
			continue
		errors.append("第 %d 行：看不懂的条件 '%s'（flag.X / not flag.X / item.X / KEY >= N / hero_class = X …）" % [line, t])
	return out

## 边行 → 边字典。
static func _edge(line: String, ln: int, errors: Array[String]) -> Dictionary:
	var re_raw := RegEx.create_from_string("^-\\s*raw\\s+(\\{.*\\})\\s*$")
	var re_choice := RegEx.create_from_string("^-\\s*choice\\s+\"([^\"]*)\"\\s*->\\s*([\\w-]+)(.*)$")
	var re_check := RegEx.create_from_string("^-\\s*check\\s+(\\w+)\\s+(\\w+)\\s+\"([^\"]*)\"\\s*->\\s*([\\w-]+)\\s*\\|\\s*fail\\s+([\\w-]+)(.*)$")
	var re_item := RegEx.create_from_string("^-\\s*item\\s+([\\w-]+)\\s+\"([^\"]*)\"\\s*->\\s*([\\w-]+)(.*)$")
	var m := re_raw.search(line)
	if m != null:
		var rv: Variant = JSON.parse_string(m.get_string(1))
		if rv is Dictionary:
			return rv
		errors.append("第 %d 行：- raw 须为 JSON 对象" % ln)
		return {}
	var edge := {}
	var tail := ""
	m = re_choice.search(line)
	if m != null:
		edge = {"type": "choice", "label": m.get_string(1), "to": m.get_string(2)}
		tail = m.get_string(3)
	else:
		m = re_check.search(line)
		if m != null:
			var diff := m.get_string(2)
			if not DIFFICULTIES.has(diff):
				errors.append("第 %d 行：检定难度须为 easy / medium / hard（得到 %s）" % [ln, diff])
			edge = {"type": "check", "skill": m.get_string(1), "difficulty": diff, "label": m.get_string(3),
				"success": m.get_string(4), "failure": m.get_string(5)}
			tail = m.get_string(6)
		else:
			m = re_item.search(line)
			if m != null:
				edge = {"type": "item", "item": m.get_string(1), "label": m.get_string(2), "to": m.get_string(3)}
				tail = m.get_string(4)
	if edge.is_empty():
		errors.append("第 %d 行：看不懂的出边：%s" % [ln, line.left(60)])
		return {}
	# 尾部修饰：[if …] [do …] [fail_do …]
	var re_mod := RegEx.create_from_string("\\[(if|do|fail_do)\\s+([^\\]]*)\\]")
	for mm: RegExMatch in re_mod.search_all(tail):
		match mm.get_string(1):
			"if":
				edge["requires"] = _cond(mm.get_string(2), ln, errors)
			"do":
				edge["success_effects" if edge["type"] == "check" else "effects"] = _effects(mm.get_string(2), ln, errors)
			"fail_do":
				edge["failure_effects"] = _effects(mm.get_string(2), ln, errors)
	return edge

## 遭遇串：难度 | enemies a x2, b | party … | xp N | gold N | loot a x1 | max_units N | mods hp+2 atk-1
static func _encounter(node_id: String, s: String, default_party: Array, ln: int, errors: Array[String]) -> Dictionary:
	var parts := s.split("|")
	var diff := parts[0].strip_edges()
	if not DIFFICULTIES.has(diff):
		errors.append("第 %d 行：遭遇难度须为 easy / medium / hard（得到 %s）" % [ln, diff])
		return {}
	var enc := {"id": node_id, "node": node_id, "type": "battle", "mode": "inherit", "difficulty": diff}
	var party: Array = default_party
	for p: String in parts.slice(1):
		var t := p.strip_edges()
		var sp := t.find(" ")
		var key := t.substr(0, sp) if sp > 0 else t
		var val := t.substr(sp + 1).strip_edges() if sp > 0 else ""
		match key:
			"enemies":
				var list: Array = []
				var counts := {}
				for tok: String in val.split(","):
					var mm := RegEx.create_from_string("^([\\w-]+)(?:\\s*x(\\d+))?$").search(tok.strip_edges())
					if mm == null:
						errors.append("第 %d 行：敌人写法 '%s'（如 ink_imp x2）" % [ln, tok])
						continue
					var ref := mm.get_string(1)
					for _k: int in (int(mm.get_string(2)) if mm.get_string(2) != "" else 1):
						counts[ref] = int(counts.get(ref, 0)) + 1
						list.append({"id": "%s%d" % [ref, counts[ref]], "ref": ref})
				enc["enemies"] = list
			"party":
				party = Array(val.split(",")).map(func(x: String) -> String: return x.strip_edges())
			"xp", "gold", "max_units":
				enc[key] = int(val)
			"loot":
				var loot: Array = []
				for tok2: String in val.split(","):
					var m2 := RegEx.create_from_string("^([\\w-]+)(?:\\s*x(\\d+))?$").search(tok2.strip_edges())
					if m2 != null:
						loot.append({"item": m2.get_string(1), "n": int(m2.get_string(2)) if m2.get_string(2) != "" else 1})
				enc["loot"] = loot
			"mods":
				var mods := {}
				for tok3: String in val.split(" ", false):
					var m3 := RegEx.create_from_string("^(hp|atk)([+-]\\d+)$").search(tok3)
					if m3 != null:
						mods["hp" if m3.get_string(1) == "hp" else "attack_mod"] = int(m3.get_string(2))
				enc["enemy_mods"] = mods
			_:
				errors.append("第 %d 行：遭遇字段 '%s' 未知（enemies / party / xp / gold / loot / max_units / mods）" % [ln, key])
	if not enc.has("enemies"):
		errors.append("第 %d 行：战斗遭遇 %s 缺 enemies" % [ln, node_id])
	var pl: Array = []
	var pid := 0
	for ref2: Variant in party:
		pid += 1
		pl.append({"id": "pc" if pid == 1 else str(ref2).trim_prefix("companion_"), "ref": str(ref2)})
	if not pl.is_empty():
		enc["party"] = pl
	if not enc.has("max_units"):
		enc["max_units"] = (enc.get("enemies", []) as Array).size() + pl.size()
	return enc

static func _flags(nodes: Array, encounters: Array) -> Array:
	var reg := {}
	var add := func(fid: String, role: String, who: String) -> void:
		if not reg.has(fid):
			reg[fid] = {"id": fid, "name": fid, "type": "bool", "default": false, "writers": [], "readers": []}
		var arr: Array = reg[fid][role]
		if not arr.has(who):
			arr.append(who)
	for n: Dictionary in nodes:
		var nid := str(n["id"])
		for eff: Dictionary in n.get("on_enter", []):
			if eff.has("write"):
				add.call(str(eff["write"]), "writers", nid)
		for e: Dictionary in n["edges"]:
			for key: String in ["effects", "success_effects", "failure_effects"]:
				for eff2: Dictionary in e.get(key, []):
					if eff2.has("write"):
						add.call(str(eff2["write"]), "writers", nid)
			for ck: Variant in (e.get("requires", {}) as Dictionary).keys():
				if str(ck).begins_with("flag.") and str(ck).count(".") == 1:
					add.call(str(ck).substr(5), "readers", nid)
	return reg.values()

# ---------------------------------------------------------------- 写包

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(ints(data), "  ", false) + "\n") # 保留键序；整数不写成 60.0
	f.close()

## JSON 解析出的整值浮点数还原为整数（Godot 的 JSON 一律解析为浮点，写回会变成 60.0）。
static func ints(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, round(v)) and absf(v) < 1e15:
		return int(v)
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return ints(x))
	if v is Dictionary:
		var out := {}
		for k: Variant in (v as Dictionary).keys():
			out[k] = ints(v[k])
		return out
	return v

## 写出包目录：结构文件由脚本生成；manifest 与已有合并；遭遇保留已调参数；设计数据文件不动（缺则建空表）。
static func write_pack(res: Dictionary, out: String) -> void:
	var dir := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(dir.path_join("texts"))
	var old_m: Variant = _read_json(dir.path_join("manifest.json"))
	var m: Dictionary = res["manifest"]
	if old_m is Dictionary:
		var merged: Dictionary = (old_m as Dictionary).duplicate(true)
		merged.merge(m, true)
		m = merged
	_write_json(dir.path_join("manifest.json"), m)
	_write_json(dir.path_join("nodes.json"), res["nodes"])
	_write_json(dir.path_join("flags.json"), res["flags"])
	if not (res["endings"] as Array).is_empty() or str(m.get("pack_type", "")) != "arc":
		_write_json(dir.path_join("endings.json"), res["endings"])
	_write_json(dir.path_join("lore.json"), res["lore"])
	# 遭遇：保留人工 / 平衡器调过的字段（enemy_mods / pos / note / party_advantage / enemy_weaken）
	var old_e: Variant = _read_json(dir.path_join("encounters.json"))
	var keep := {}
	if old_e is Array:
		for e: Variant in old_e:
			keep[str((e as Dictionary).get("id", ""))] = e
	var encs: Array = res["encounters"]
	for e2: Dictionary in encs:
		var prev: Dictionary = keep.get(str(e2["id"]), {})
		for k: String in ["enemy_mods", "pos", "note", "party_advantage", "enemy_weaken"]:
			if prev.has(k) and not e2.has(k):
				e2[k] = prev[k]
	# 非战斗的已有遭遇（rest / maze 等，人工维护）原样保留
	if old_e is Array:
		for e3: Variant in old_e:
			var d: Dictionary = e3
			if str(d.get("type", "")) != "battle" and not encs.any(func(x: Dictionary) -> bool: return x["id"] == d.get("id")):
				encs.append(d)
	_write_json(dir.path_join("encounters.json"), encs)
	var loc := str(m.get("source_locale", "en"))
	var tpath := dir.path_join("texts/%s.json" % loc)
	var old_t: Variant = _read_json(tpath)
	var t: Dictionary = (old_t as Dictionary).duplicate() if old_t is Dictionary else {}
	t.merge(res["texts"], true)
	_write_json(tpath, t)
	for f: String in ["characters.json", "enemies.json", "items.json", "skills.json", "events.json"]:
		if not FileAccess.file_exists(dir.path_join(f)):
			_write_json(dir.path_join(f), [])

## 加载 + packlint（支线按嫁接口径），返回 {lines, fail, warn}。
static func check_pack(out: String) -> Dictionary:
	var lines: Array[String] = []
	var res := PackLoader.load_pack(out)
	if not bool(res["ok"]):
		for e: String in res["errors"]:
			lines.append("  [LOAD] " + e)
		return {"lines": lines, "fail": (res["errors"] as Array).size(), "warn": 0}
	var pack: Dictionary = res["pack"]
	var issues: Array = []
	var graft: Dictionary = (pack["manifest"] as Dictionary).get("graft", {})
	if not graft.is_empty():
		var host_dir := out.get_base_dir().path_join(str(graft.get("into", "")))
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(host_dir)):
			host_dir = "res://packs/%s" % str(graft.get("into", "")) # 输出在别处（试导入）：宿主取正式包
		var host := PackLoader.load_pack(host_dir)
		if bool(host["ok"]):
			issues = PacklintCore.lint_grafted(pack, host["pack"])
		else:
			lines.append("  [LOAD] 宿主包 %s 加载失败" % str(graft.get("into", "")))
	else:
		issues = PacklintCore.lint(pack)
	var fail := 0
	var warn := 0
	for it: Dictionary in issues:
		if it["level"] == PacklintCore.LEVEL_FAIL:
			fail += 1
			lines.append("  [FAIL] %s：%s" % [it["v"], it["msg"]])
		elif it["level"] == PacklintCore.LEVEL_WARN:
			warn += 1
			lines.append("  [WARN] %s：%s" % [it["v"], it["msg"]])
	return {"lines": lines, "fail": fail, "warn": warn}
