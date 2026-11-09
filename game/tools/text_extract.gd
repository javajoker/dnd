# 文本抽取 CLI（tech/02 §1.1 双语构建）：列出某内容包在目标语言下待翻译的文本键。
# 用法：godot --headless --path game -s tools/text_extract.gd -- packs/<pack_id> <locale> <输出.json>
# 输出 = { 键: 源语言原文 }，只含目标语言 texts/<locale>.json 尚未提供（或为空）的键——
# 译者填写后并入 texts/<locale>.json；键清单口径 = PackLoader.text_entries() + text_ref 键（与 V15 一致）。
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("用法：-- packs/<pack_id> <locale> <out.json>")
		quit(2)
		return
	var dir := "res://" + args[0].trim_prefix("res://")
	var target := args[1]
	PackLoader.locale = ""
	var res := PackLoader.load_pack(dir)
	if not bool(res["ok"]):
		push_error("加载失败：%s" % ";".join(res["errors"]))
		quit(1)
		return
	var pack: Dictionary = res["pack"]
	var texts: Dictionary = pack["texts"]
	var source := str(pack["source_locale"])
	var src_long: Dictionary = texts.get("texts/%s.json" % source, {})
	var have: Dictionary = texts.get("texts/%s.json" % target, {})
	var out := {}
	var entries := PackLoader.text_entries(pack)
	for k: String in entries.keys():
		if str(have.get(k, "")) == "" and str(entries[k]) != "":
			out[k] = entries[k]
	for k: String in PackLoader.text_ref_keys(pack):
		if str(have.get(k, "")) == "":
			out[k] = str(src_long.get(k, ""))
	var f := FileAccess.open(args[2], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", false))
	f.close()
	print("[text_extract] %s → %s：待译 %d 键（已有 %d）" % [dir, target, out.size(), have.size()])
	quit(0)
