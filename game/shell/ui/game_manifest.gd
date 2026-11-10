# 游戏清单（docs/en/tech/07-new-game-kit.md §3）：把"这是哪一款游戏"从代码里拿出来。
# packs/_game/game.json = 默认战役 / 启用的包 / 语言 / 主题字体 / 音乐与音效映射；
# packs/_game/texts/<locale>.json = 本作的界面风味文案（覆盖框架中性默认文案，Texts 取值时叠加）。
# 换一款游戏 = 换 _game 目录 + 内容包 + 美术音频资源，引擎代码不动。文件缺失时一律回落框架缺省。
class_name GameManifest
extends RefCounted

const PATH := "res://packs/_game/game.json"
const TEXTS_DIR := "res://packs/_game/texts"

## 测试 / 工具可注入其他清单目录（为空 = 正式路径）。
static var override_path := ""
static var _data: Dictionary = {}
static var _loaded := false
static var _overlays: Dictionary = {} # locale -> {key: value}

static func reset() -> void:
	_loaded = false
	_data = {}
	_overlays = {}

static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var p := override_path if override_path != "" else PATH
		if FileAccess.file_exists(p):
			var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
			if raw is Dictionary:
				_data = raw
	return _data

static func id() -> String:
	return str(data().get("id", ""))

## 默认战役包 id（空 = 由 main 按 manifest.entry / 目录名挑选）。
static func default_campaign() -> String:
	return str(data().get("default_campaign", ""))

## 本作启用的包（空数组 = packs/ 下发现的全部包）。
static func packs() -> Array:
	return data().get("packs", [])

static func pack_enabled(pack_id: String) -> bool:
	return packs().is_empty() or packs().has(pack_id)

static func font(fallback: String) -> String:
	var f := str((data().get("theme", {}) as Dictionary).get("font", ""))
	return f if f != "" and ResourceLoader.exists(f) else fallback

static func _audio() -> Dictionary:
	return data().get("audio", {})

## 状态 → BGM 资产名（camp / explore / battle / ending / map）。
static func bgm(state: StringName, fallback: StringName) -> StringName:
	var m: Dictionary = _audio().get("bgm", {})
	return StringName(str(m.get(String(state), fallback)))

## 逻辑音效名 → 资产名（未映射 = 同名资产）。
static func sfx(name: StringName) -> StringName:
	var m: Dictionary = _audio().get("sfx", {})
	return StringName(str(m.get(String(name), name)))

static func ambient(slot: String, fallback: StringName) -> StringName:
	var m: Dictionary = _audio().get("ambient", {})
	return StringName(str(m.get(slot, fallback)))

static func loop_assets(fallback: Array) -> Array:
	var l: Array = _audio().get("loop", [])
	return l if not l.is_empty() else fallback

## 本作界面风味文案（locale 缺文件 = 空表）。
static func text_overlay(locale: String) -> Dictionary:
	if _overlays.has(locale):
		return _overlays[locale]
	var out := {}
	var dir := TEXTS_DIR if override_path == "" else override_path.get_base_dir().path_join("texts")
	var p := dir.path_join("%s.json" % locale)
	if FileAccess.file_exists(p):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if raw is Dictionary:
			out = raw
	_overlays[locale] = out
	return out
