# 界面文本的唯一入口（tech/01 E-5 双语构建）：壳层一律经 Texts 取文案，不直接引用某一语言表。
# - 语言表 = 常量脚本（常量名即键）：zh-CN = texts_zh.gd（源语言），en = texts_en.gd（存在即启用）；
# - 取值：当前语言表 → 源语言表回退（缺键不报错，V15/测试负责完整性）；
# - 事件消息：core / 应用层只发 {msg_key, args}，Texts.msg() 按当前语言渲染；无 msg_key 的旧事件
#   或内容包数据文本（已在加载时按语言叠加）原样显示 payload.msg。
# - 语言是 UI 偏好（UiSettings ui.locale；缺省按系统语言），不写状态板。
class_name Texts
extends RefCounted

const SOURCE_LOCALE := "zh-CN" # 源语言：内容与文案的编写语言，缺键回退到它
const DEFAULT_LOCALE := "en"   # 缺省语言：未选择语言且系统语言不是中文时使用（英文版为默认入口）
const TABLE_PATHS := {
	"zh-CN": "res://shell/ui/texts_zh.gd",
	"en": "res://shell/ui/texts_en.gd",
}

static var locale: String = DEFAULT_LOCALE
## 强制语言（测试/工具）：非空时 detect_locale 恒返回它，与系统语言和玩家偏好无关。
static var forced_locale: String = ""
static var _tables: Dictionary = {} # locale -> 常量表（Dictionary）；懒加载

## 已提供的语言（表文件存在才算）。
static func available_locales() -> Array:
	var out: Array = []
	for l: String in TABLE_PATHS.keys():
		if ResourceLoader.exists(TABLE_PATHS[l]):
			out.append(l)
	return out

## 设置当前语言；不支持的语言回落源语言。返回实际生效的语言。
static func set_locale(l: String) -> String:
	locale = l if available_locales().has(l) else default_locale()
	return locale

## 缺省语言：英文表存在即英文，否则源语言。
static func default_locale() -> String:
	return DEFAULT_LOCALE if available_locales().has(DEFAULT_LOCALE) else SOURCE_LOCALE

## 玩家偏好优先；其次系统语言为中文 → zh-CN；其余一律缺省语言（英文）。
static func detect_locale(preferred: String = "") -> String:
	if forced_locale != "":
		return forced_locale
	if preferred != "" and available_locales().has(preferred):
		return preferred
	var os_lang := OS.get_locale_language()
	if os_lang == "zh":
		return "zh-CN"
	return default_locale()

## 文本键取值（Variant：多数为 String，少数为 Array，如 TUT_CARDS）。
static func t(key: StringName) -> Variant:
	var table := _table(locale)
	if table.has(key):
		return table[key]
	var src := _table(SOURCE_LOCALE)
	if src.has(key):
		return src[key]
	push_warning("[texts] 缺少文本键 %s" % key)
	return String(key)

## 字符串文本键（绝大多数文案）：类型化为 String，供带类型的变量/格式化直接使用。
static func s(key: StringName) -> String:
	return str(t(key))

## 文本行数组（教程卡、帮助表等）：类型化为 PackedStringArray。
static func lines(key: StringName) -> PackedStringArray:
	return PackedStringArray(t(key))

## 具名占位模板：Texts.fmt(&"MSG_X", {"name": v}) → "{name}" 替换。
static func fmt(key: StringName, args: Dictionary = {}) -> String:
	return str(t(key)).format(args)

## 事件消息渲染：msg_key + args 优先；否则显示 payload.msg（内容包文本 / 旧事件）。
static func msg(payload: Dictionary) -> String:
	var key := str(payload.get("msg_key", ""))
	if key != "":
		return fmt(StringName(key), payload.get("args", {}))
	return str(payload.get("msg", ""))

## 当前语言表是否含该键（测试与 V15 用）。
static func has_key(l: String, key: StringName) -> bool:
	return _table(l).has(key)

## 某语言表全部键（覆盖率检查用）。
static func keys(l: String) -> Array:
	return _table(l).keys()

static func _table(l: String) -> Dictionary:
	if _tables.has(l):
		return _tables[l]
	var table := {}
	if TABLE_PATHS.has(l) and ResourceLoader.exists(TABLE_PATHS[l]):
		var script: Script = load(TABLE_PATHS[l])
		for k: StringName in script.get_script_constant_map().keys():
			table[StringName(k)] = script.get_script_constant_map()[k]
	# 本作风味文案覆盖框架中性默认（packs/_game/texts/<locale>.json；tech/07 §3）
	var overlay := GameManifest.text_overlay(l)
	for k2: Variant in overlay.keys():
		table[StringName(str(k2))] = overlay[k2]
	_tables[l] = table
	return table

## 换游戏 / 测试注入清单后清缓存（下次取值重新叠加覆盖层）。
static func clear_cache() -> void:
	_tables.clear()

# ---------------------------------------------------------------- 带逻辑的文案（原 TextsZh 静态函数，按当前语言取模板）

## 指令集条目 → 芯片/轮盘按钮文案（两壳同源排版；次数余量实时呈现，09 §9.2）。
static func action_label(a: Dictionary) -> String:
	match StringName(str(a.get("type", ""))):
		EncounterSM.CMD_ATTACK:
			return s(&"CHIP_ATTACK")
		EncounterSM.CMD_MOVE:
			return s(&"CHIP_MOVE")
		EncounterSM.CMD_SKILL:
			var label := str(a.get("name", a.get("skill", "")))
			if int(a.get("uses", -1)) >= 0:
				label += " ×%d" % int(a["uses"])
			return label
		EncounterSM.CMD_ITEM:
			if not bool(a.get("pouch", true)) or str(a.get("cost", "")) == "action":
				return s(&"CHIP_ITEM_ACTION_FMT") % [str(a.get("name", a.get("item", ""))), int(a.get("count", 0))]
			return s(&"CHIP_ITEM_FMT") % [str(a.get("name", a.get("item", ""))), int(a.get("count", 0))]
		EncounterSM.CMD_EQUIP:
			return s(&"CHIP_EQUIP_FMT") % str(a.get("name", a.get("item", "")))
		EncounterSM.CMD_FIRST_AID:
			return s(&"CHIP_FIRST_AID")
		EncounterSM.CMD_END_TURN:
			return s(&"CHIP_END_TURN")
	return str(a.get("name", "?"))

## 营地图景随褪墨度（global.doom_clock 0~10）变化（04 §①：状态板的可视化）。
static func home_doom_text(clock: int) -> String:
	if clock <= 3:
		return s(&"HOME_DOOM_LOW")
	if clock <= 6:
		return s(&"HOME_DOOM_MID")
	return s(&"HOME_DOOM_HIGH")

## 购买弹层文案（06 §3.1 叙事化包装）。
static func shop_line(pack_name: String, price_text: String) -> String:
	return s(&"SHOP_LINE") % [pack_name, price_text]

## 皮肤获得途径说明（注册表 grant 声明 → 叙事化一行）。
static func cosmetic_source_line(def: Dictionary) -> String:
	var g: Dictionary = def.get("grant", {})
	match str(g.get("kind", "")):
		"default":
			return s(&"COSMETIC_SRC_DEFAULT")
		"codex_series":
			return s(&"COSMETIC_SRC_CODEX")
		"shop":
			return s(&"COSMETIC_SRC_SHOP") % str((def.get("shop", {}) as Dictionary).get("price_text", ""))
		"ngplus_ending":
			return s(&"COSMETIC_SRC_NGPLUS") % str(g.get("ending", ""))
	return ""

## 皮肤购买弹层文案。
static func cosmetic_shop_line(skin_name: String, price_text: String) -> String:
	return s(&"COSMETIC_SHOP_LINE") % [skin_name, price_text]

## 快捷栏分组（09 §9.2；11 §8.2）：快取袋道具与常规动作常驻；背包道具与换武器收进「背包」组按需展开。
## 纯呈现分组，不改过滤结果（指令集仍唯一来自 EncounterSM.get_available_actions）。
static func split_pack_actions(actions: Array) -> Dictionary:
	var main: Array = []
	var pack: Array = []
	for a: Variant in actions:
		var d: Dictionary = a
		var t := StringName(str(d.get("type", "")))
		if t == EncounterSM.CMD_EQUIP or (t == EncounterSM.CMD_ITEM and not bool(d.get("pouch", true))):
			pack.append(d)
		else:
			main.append(d)
	return {"main": main, "pack": pack}

## 技能一句话说明（整备资源库卡片；数据 = BattleDef.runtime_skill 形态）。
static func skill_desc(sk: Dictionary) -> String:
	var parts: Array[String] = []
	if str(sk.get("kind", "attack")) == "attack":
		var attr_names: Dictionary = t(&"ATTR_SHORT")
		parts.append(s(&"DESC_ATTACK") % [str(sk.get("damage", "")), str(attr_names.get(str(sk.get("attr", "might")), ""))])
	else:
		parts.append(s(&"DESC_UTILITY"))
	if int(sk.get("uses", -1)) > 0:
		parts.append(s(&"DESC_USES") % int(sk["uses"]))
	return s(&"DESC_SEP").join(parts)

## 道具 use 块一句话说明（回复 / 投掷 + 行动经济）。
static func item_desc(use: Dictionary) -> String:
	var parts: Array[String] = []
	if use.has("heal"):
		parts.append(s(&"DESC_HEAL") % str(use["heal"]))
	if use.has("damage"):
		parts.append(s(&"DESC_THROW") % str(use["damage"]))
	parts.append(s(&"DESC_ACTION") if str(use.get("timing", "")) == "action" else s(&"DESC_BONUS"))
	return s(&"DESC_SEP").join(parts)

## 装备一句话说明（槽位 + 修正）。
static func gear_desc(eb: Dictionary) -> String:
	var names: Dictionary = t(&"SLOT_NAME")
	var parts: Array[String] = [str(names.get(str(eb.get("slot", "")), str(eb.get("slot", ""))))]
	if str(eb.get("damage_die", "")) != "":
		parts.append(s(&"DESC_DIE") % str(eb["damage_die"]))
	if int(eb.get("attack", 0)) != 0:
		parts.append(s(&"DESC_ATK") % int(eb["attack"]))
	if int(eb.get("ac", 0)) != 0:
		parts.append(s(&"DESC_AC") % int(eb["ac"]))
	if int(eb.get("max_hp", 0)) != 0:
		parts.append(s(&"DESC_HP") % int(eb["max_hp"]))
	return s(&"DESC_SEP").join(parts)
