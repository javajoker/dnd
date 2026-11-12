# 平衡自动调参（docs/en/story/03 §1；docs/en/tech/11 §5）：逐场测胜率，越出难度区间的战斗搜一组
# enemy_mods（全体敌人 HP 加值，必要时再加攻击修正）把胜率拉回区间中心——只建议 / 写回遭遇级旋钮，
# 不改共享的敌人条目与规则包（铁律：调数值不调规则）。
#
# 用法：godot --headless --path game -s tools/balance_tune.gd -- <包目录> [--games N] [--seed S] [--class ID] [--write] [--only ID]
#   - 缺省 400 局 / 场、种子 20261109；搜索时同一种子（共同随机数，曲线平滑）；最终值用另一种子复核
#   - 支线包（manifest.graft）自动并入宿主后测
#   - --write：把建议写回 <包目录>/encounters.json（保留其余字段与键序）
#   - 退出码：0 = 全部在区间（或已写回且复核在区间）；2 = 仍有越界
extends SceneTree

const HP_RANGE := Vector2i(-8, 14)
const ATK_RANGE := Vector2i(-2, 2)

var _wr: GDScript

func _init() -> void:
	_wr = load("res://tools/winrate.gd")
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		print("用法：-s tools/balance_tune.gd -- <包目录> [--games N] [--seed S] [--class ID] [--write] [--only ID]")
		quit(1)
		return
	var dir: String = a[0] if a[0].contains("://") else "res://" + a[0]
	var games := int(_opt(a, "--games", "400"))
	var seed := int(_opt(a, "--seed", "20261109"))
	var cls := _opt(a, "--class", "")
	var only := _opt(a, "--only", "")
	var write := a.has("--write")
	var res := PackLoader.load_pack(dir)
	if not bool(res["ok"]):
		for e: String in res["errors"]:
			print("  [LOAD] ", e)
		quit(1)
		return
	var pack: Dictionary = res["pack"]
	var own_id := str(pack.get("pack_id", ""))
	var graft: Dictionary = (pack["manifest"] as Dictionary).get("graft", {})
	if not graft.is_empty(): # 支线：并入宿主资源表后测
		var host_dir := dir.get_base_dir().path_join(str(graft.get("into", "")))
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(host_dir)):
			host_dir = "res://packs/%s" % str(graft.get("into", ""))
		var host := PackLoader.load_pack(host_dir)
		var merged := PackLoader.merge_graft(host["pack"], pack)
		var view: Dictionary = merged.get("view", {})
		# 只调本包的遭遇
		var own: Dictionary = pack["encounters"]
		pack = view.duplicate()
		var only_own := {}
		for eid: String in own.keys():
			only_own[eid] = (view.get("encounters", {}) as Dictionary).get(eid, own[eid])
		pack["encounters"] = only_own
	if cls != "":
		_wr.hero_class = cls
	var targets: Dictionary = _wr.TARGETS
	var rows: Array = []
	var out_of_band := 0
	print("== 平衡调参 %s：每场 %d 局，种子 %d%s ==" % [own_id, games, seed, "，职业 " + cls if cls != "" else ""])
	print("遭遇        难度    区间      现值      建议 enemy_mods          调后（复核）")
	for eid: String in _wr.battle_encounters(pack):
		if only != "" and eid != only:
			continue
		var enc: Dictionary = pack["encounters"][eid]
		var diff := str(enc.get("difficulty", "medium"))
		if not targets.has(diff):
			continue
		var band: Array = targets[diff]
		var lo := float(band[0])
		var hi := float(band[1])
		var center := (lo + hi) * 0.5
		var base_mods: Dictionary = (enc.get("enemy_mods", {}) as Dictionary).duplicate()
		var r0 := _rate(pack, eid, base_mods, games, seed)
		if r0 >= lo and r0 <= hi:
			print("%-11s %-7s %2d~%-3d   %5.1f%%   （在区间内，不动）" % [eid, diff, int(lo), int(hi), r0])
			continue
		var best := _search(pack, eid, base_mods, games, seed, center)
		var check := _rate(pack, eid, best["mods"], games, seed + 7777) # 换种子复核
		var ok := check >= lo and check <= hi
		if not ok:
			out_of_band += 1
		print("%-11s %-7s %2d~%-3d   %5.1f%%   %-24s %5.1f%% %s" % [eid, diff, int(lo), int(hi), r0,
			JSON.stringify(best["mods"]), check, "✓" if ok else "✗ 仍越界（需改阵容 / 敌人条目）"])
		rows.append({"id": eid, "mods": best["mods"]})
	if write and not rows.is_empty():
		_write(dir, rows)
		print("== 已写回 %d 场的 enemy_mods → %s/encounters.json ==" % [rows.size(), dir])
	elif not rows.is_empty():
		print("== 建议 %d 处（加 --write 写回）==" % rows.size())
	else:
		print("== 全部在区间内 ==")
	quit(2 if out_of_band > 0 else 0)

static func _opt(a: PackedStringArray, key: String, def: String) -> String:
	var i := a.find(key)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else def

## 在给定 enemy_mods 下的胜率（百分比）。
func _rate(pack: Dictionary, eid: String, mods: Dictionary, games: int, seed: int) -> float:
	var enc: Dictionary = pack["encounters"][eid]
	var keep: Variant = enc.get("enemy_mods")
	if mods.is_empty():
		enc.erase("enemy_mods")
	else:
		enc["enemy_mods"] = mods
	var r: Dictionary = _wr.run_encounter(pack, eid, games, seed)
	if keep == null:
		enc.erase("enemy_mods")
	else:
		enc["enemy_mods"] = keep
	return 100.0 * float(r["wins"]) / maxf(1.0, float(r["games"]))

## 先二分 HP 加值（HP 越高胜率越低，单调）；HP 到边界仍不够再试攻击修正。返回 {mods, rate}。
func _search(pack: Dictionary, eid: String, base: Dictionary, games: int, seed: int, center: float) -> Dictionary:
	var min_hp := 999
	for e: Variant in (pack["encounters"][eid] as Dictionary).get("enemies", []):
		var ref := str((e as Dictionary).get("ref", ""))
		min_hp = mini(min_hp, int(((pack.get("enemies", {}) as Dictionary).get(ref, {}) as Dictionary).get("hp", 1)))
	var lo := maxi(HP_RANGE.x, 1 - min_hp + 1) # 敌人 HP 至少留 2
	var hi := HP_RANGE.y
	var atk := int(base.get("attack_mod", 0))
	var cache := {}
	var rate_at := func(hp: int, at: int) -> float:
		var key := "%d,%d" % [hp, at]
		if not cache.has(key):
			var m := {}
			if hp != 0:
				m["hp"] = hp
			if at != 0:
				m["attack_mod"] = at
			cache[key] = _rate(pack, eid, m, games, seed)
		return cache[key]
	var a := lo
	var b := hi
	while a < b:
		var mid := (a + b) / 2
		if float(rate_at.call(mid, atk)) > center:
			a = mid + 1
		else:
			b = mid
	var best_hp := a
	var best_atk := atk
	var best_err := absf(float(rate_at.call(best_hp, atk)) - center)
	for cand: int in [a - 1, a + 1]:
		if cand >= lo and cand <= hi:
			var err := absf(float(rate_at.call(cand, atk)) - center)
			if err < best_err:
				best_err = err
				best_hp = cand
	if best_err > 5.0: # HP 旋钮不够：在攻击修正上再搜一圈
		for at2: int in range(ATK_RANGE.x, ATK_RANGE.y + 1):
			for hp2: int in [best_hp - 4, best_hp - 2, best_hp, best_hp + 2, best_hp + 4]:
				if hp2 < lo or hp2 > hi:
					continue
				var err2 := absf(float(rate_at.call(hp2, at2)) - center)
				if err2 < best_err:
					best_err = err2
					best_hp = hp2
					best_atk = at2
	var mods := {}
	if best_hp != 0:
		mods["hp"] = best_hp
	if best_atk != 0:
		mods["attack_mod"] = best_atk
	return {"mods": mods, "rate": float(rate_at.call(best_hp, best_atk))}

## 写回 encounters.json：只改 enemy_mods（空 = 删除该键），其余字段与键序不动。
func _write(dir: String, rows: Array) -> void:
	var path := ProjectSettings.globalize_path(dir.path_join("encounters.json"))
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var list: Array = data if data is Array else (data as Dictionary).get("encounters", [])
	for row: Dictionary in rows:
		for e: Variant in list:
			var d: Dictionary = e
			if str(d.get("id", "")) == str(row["id"]):
				if (row["mods"] as Dictionary).is_empty():
					d.erase("enemy_mods")
				else:
					d["enemy_mods"] = row["mods"]
	var importer: GDScript = load("res://tools/story_import.gd")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(importer.ints(data), "  ", false) + "\n")
	f.close()
