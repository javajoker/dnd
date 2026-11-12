# Pack catalogue (tech/11 §4): prints a pack's reusable ids with English names and key numbers, so a writer or
# designer can reuse host data without reading raw JSON (campaign01's data names are zh-CN; English lives in texts).
# Usage: godot --headless --path game -s tools/pack_catalog.gd -- <pack dir> [--locale en]
extends SceneTree

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		print("Usage: -s tools/pack_catalog.gd -- <pack dir> [--locale en]")
		quit(1)
		return
	var dir: String = a[0] if a[0].contains("://") else "res://" + a[0]
	var li := a.find("--locale")
	PackLoader.locale = a[li + 1] if li >= 0 and li + 1 < a.size() else "en"
	var res := PackLoader.load_pack(dir)
	if not bool(res["ok"]):
		print("LOAD FAILED: ", res["errors"])
		quit(1)
		return
	var p: Dictionary = res["pack"]
	var m: Dictionary = p["manifest"]
	print("# %s (%s) — %s" % [p["pack_id"], m.get("pack_type", "campaign"), m.get("name", "")])
	print("default party (encounter party refs): ", _default_party(p))
	print("expected level per act (manifest balance.act_level): ", (m.get("balance", {}) as Dictionary).get("act_level", {}))
	print("\n## Acts")
	for act: Dictionary in p.get("acts", []):
		print("- %s  %s  mode=%s" % [act.get("id", ""), act.get("title", ""), act.get("mode", "")])
	print("\n## Hubs and graft points (node id · act · title · exits)")
	for nid: String in p["node_order"]:
		var n: Dictionary = p["nodes"][nid]
		if str(n.get("type", "")) == "hub":
			print("- %s · %s · %s · %d exits" % [nid, n.get("act", ""), n.get("title", ""), (n.get("edges", []) as Array).size()])
	print("\n## Characters (ref · kind · name)")
	for id: String in (p.get("characters", {}) as Dictionary).keys():
		var c: Dictionary = p["characters"][id]
		print("- %s · %s · %s" % [id, c.get("kind", ""), c.get("name", "")])
	print("\n## Enemies (ref · name · HP / AC / attack / damage)")
	for id: String in (p.get("enemies", {}) as Dictionary).keys():
		var e: Dictionary = p["enemies"][id]
		print("- %s · %s · %s / %s / +%s / %s%s" % [id, e.get("name", ""), e.get("hp", "?"), e.get("ac", "?"),
			e.get("attack_mod", "?"), e.get("damage", "?"), "  BOSS" if e.get("boss", false) else ""])
	print("\n## Items (id · name · roles · price · use/equip)")
	for id: String in (p.get("items", {}) as Dictionary).keys():
		var it: Dictionary = p["items"][id]
		var extra := ""
		if it.has("use"):
			extra = "use " + JSON.stringify(it["use"])
		elif it.has("equip"):
			extra = "equip " + JSON.stringify(it["equip"])
		print("- %s · %s · %s · %s · %s" % [id, it.get("name", ""), ",".join(PackedStringArray(it.get("roles", []))),
			str(it.get("price", "-")), extra])
	print("\n## Classes / backgrounds (ids for hero_class / background conditions and balance_tune --class)")
	for id: String in (p.get("classes", {}) as Dictionary).keys():
		print("- class %s · %s" % [id, (p["classes"][id] as Dictionary).get("name", "")])
	for id: String in (p.get("backgrounds", {}) as Dictionary).keys():
		print("- background %s · %s" % [id, (p["backgrounds"][id] as Dictionary).get("name", "")])
	print("\n## Lore entries (id · series · title)")
	for l: Dictionary in p.get("lore", []):
		print("- %s · %s · %s" % [l.get("id", ""), l.get("series", ""), l.get("title", "")])
	var keys := {}
	var clock_pos := 0
	_scan(p["nodes"], keys)
	for rec: Dictionary in PacklintCore._collect_effects(p): # 与 packlint V5 同一口径
		var eff: Dictionary = rec["effect"]
		if eff.has("clock"):
			clock_pos += maxi(int(eff["clock"]), 0)
	print("\n## Global keys used (rep.* factions, bond.* companions, alignment)")
	var ks := keys.keys()
	ks.sort()
	print("- ", ", ".join(PackedStringArray(ks)))
	print("\n## Doom Clock budget (packlint V5: host + side quest positive clock effects ≤ 10)")
	print("- positive clock effects in this pack: +%d → a side quest grafted here may add at most +%d" % [clock_pos, maxi(0, 10 - clock_pos)])
	quit(0)

static func _default_party(p: Dictionary) -> Array:
	for eid: String in (p.get("encounters", {}) as Dictionary).keys():
		var party: Array = (p["encounters"][eid] as Dictionary).get("party", [])
		if not party.is_empty():
			return party.map(func(x: Variant) -> String: return str((x as Dictionary).get("ref", x)) if x is Dictionary else str(x))
	return []

static func _scan(v: Variant, out: Dictionary) -> void:
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			var ks := str(k)
			if ks.begins_with("rep.") or ks.begins_with("bond.") or ks == "alignment":
				out[ks] = true
			_scan((v as Dictionary)[k], out)
	elif v is Array:
		for x: Variant in v:
			_scan(x, out)
