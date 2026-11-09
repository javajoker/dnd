# UI 偏好本地持久化（12 §5：玩家偏好持久化——UI 偏好不是世界状态，不写状态板，存本地设置 user://settings.cfg）
# - shell 侧工具（引擎依赖允许）：ConfigFile 存取；core 零感知；
# - 读失败/键缺失一律回落文档默认值；写盘合并既有键，不覆盖其它设置。
class_name UiSettings
extends RefCounted

const PATH := "user://settings.cfg"
const SECTION := "ui"
const KEY_HOME_BAR_COLLAPSED := "home_bar_collapsed"
const KEY_SCREEN_SHAKE := "screen_shake"
const KEY_VOL_MASTER := "vol_master" # 14 清单 #5：音量三档（UI 偏好，不写状态板）
const KEY_VOL_BGM := "vol_bgm"
const KEY_VOL_SFX := "vol_sfx"
const KEY_LOCALE := "locale" # tech/01 E-5：界面语言（UI 偏好，不写状态板）；"" = 跟随系统

## 默认偏好文件重定向（可注入）：非空时，凡传入 PATH 的读写改走此路径——测试与工具据此隔离，
## 不触碰玩家真实设置；显式传入的其它路径不受影响。
static var redirect_path: String = ""

static func _resolve(path: String) -> String:
	return redirect_path if redirect_path != "" and path == PATH else path

## 主屏兜底条是否收起；默认展开（12 §5：默认展开）。
static func load_home_bar_collapsed(path: String = PATH) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_resolve(path)) != OK:
		return false
	return bool(cfg.get_value(SECTION, KEY_HOME_BAR_COLLAPSED, false))

static func save_home_bar_collapsed(collapsed: bool, path: String = PATH) -> void:
	_save_key(KEY_HOME_BAR_COLLAPSED, collapsed, path)

## 屏幕震动是否开启（14 清单 #4：可关的设置项）；默认开启。
static func load_screen_shake(path: String = PATH) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_resolve(path)) != OK:
		return true
	return bool(cfg.get_value(SECTION, KEY_SCREEN_SHAKE, true))

static func save_screen_shake(enabled: bool, path: String = PATH) -> void:
	_save_key(KEY_SCREEN_SHAKE, enabled, path)

## 音量档位读（14 清单 #5；0.0~1.0，读失败/键缺失回落默认满格 1.0）。
static func load_volume(key: String, path: String = PATH) -> float:
	var cfg := ConfigFile.new()
	if cfg.load(_resolve(path)) != OK:
		return 1.0
	return clampf(float(cfg.get_value(SECTION, key, 1.0)), 0.0, 1.0)

static func save_volume(key: String, value: float, path: String = PATH) -> void:
	_save_key(key, clampf(value, 0.0, 1.0), path)

## 界面语言偏好；未设置返回 ""（跟随系统语言）。
static func load_locale(path: String = PATH) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(_resolve(path)) != OK:
		return ""
	return str(cfg.get_value(SECTION, KEY_LOCALE, ""))

static func save_locale(l: String, path: String = PATH) -> void:
	_save_key(KEY_LOCALE, l, path)

## 写盘合并既有键，不覆盖其它设置。
static func _save_key(key: String, value: Variant, path: String) -> void:
	var cfg := ConfigFile.new()
	var p := _resolve(path)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	cfg.load(p)
	cfg.set_value(SECTION, key, value)
	var err := cfg.save(p)
	if err != OK:
		push_warning("[ui_settings] 偏好写盘失败 %s err=%d" % [p, err])
