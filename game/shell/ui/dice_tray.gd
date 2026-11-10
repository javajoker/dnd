# 骰盘托盘档（docs/en/framework/17-polyhedral-dice-spec.md §3）：伤害 / 回复 / 生命骰等多骰就地翻滚。
# - 叠在主视野下缘、不拦截输入；≈1 秒收束后淡出；新骰到来时最新者优先（至多排队一组）；
# - 设置三档（UI 偏好，user://settings.cfg，不写状态板）：on = 全部 / key = 只在暴击 / off = 不显示
#   （关键检定的全屏演出不受此设置影响，09 §6）；
# - 纯呈现：只消费事件流里的 dice / damage_dice 清单，结果由逻辑层给定。
class_name DiceTray
extends Control

const MODE_ON := "on"
const MODE_KEY := "key"
const MODE_OFF := "off"
const MODES: Array[String] = [MODE_ON, MODE_KEY, MODE_OFF]
const SETTINGS_SECTION := "ui"
const SETTINGS_KEY := "dice_tray"
const HOLD := 0.55 # 落定后停留（秒）

var dice3d: Dice3D
var settings_path := UiSettings.PATH
var speed := 1.0 # 托管 2× 时由壳层同步
var palette: Dictionary = {}
var _pending: Array = []
var _running := false
var played := 0 # 测试探针：已演出组数

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	dice3d = (load("res://shell/ui/dice_3d.tscn") as PackedScene).instantiate() as Dice3D
	dice3d.compact = true
	add_child(dice3d)

static func load_mode(path: String = UiSettings.PATH) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(UiSettings._resolve(path)) != OK:
		return MODE_ON
	var m := str(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, MODE_ON))
	return m if MODES.has(m) else MODE_ON

static func save_mode(mode: String, path: String = UiSettings.PATH) -> void:
	UiSettings._save_key(SETTINGS_KEY, mode if MODES.has(mode) else MODE_ON, path)

## 循环切换（☰ 菜单按钮）：on → key → off → on。
static func cycle_mode(path: String = UiSettings.PATH) -> String:
	var next := MODES[(MODES.find(load_mode(path)) + 1) % MODES.size()]
	save_mode(next, path)
	return next

## 从事件取托盘骰组；不该上托盘返回 []。
static func dice_for_event(ev: Dictionary, mode: String) -> Array:
	if mode == MODE_OFF:
		return []
	var p: Dictionary = ev.get("payload", {})
	match StringName(str(ev.get("type", ""))):
		EventTypes.BATTLE_ATTACK:
			if not bool(p.get("hit", false)):
				return []
			if mode == MODE_KEY and not bool(p.get("crit", false)):
				return []
			return p.get("damage_dice", [])
		EventTypes.ITEM_USE:
			return [] if mode == MODE_KEY else p.get("dice", [])
		EventTypes.CHECK_ROLL:
			if str(p.get("kind", "")) == "save" and mode == MODE_ON:
				return p.get("damage_dice", [])
		EventTypes.TABLE_ROLL:
			# 事件表（16 §4）：全部档显示；仅暴击档只显示 key 表
			if mode == MODE_ON or bool(p.get("key", false)):
				return p.get("dice", [])
		EventTypes.LOG:
			if mode == MODE_ON and p.has("dice"):
				return p["dice"] # 短休生命骰等
	return []

func on_event(ev: Dictionary) -> void:
	var dice := dice_for_event(ev, load_mode(settings_path))
	if dice.is_empty():
		return
	_pending = [{"dice": dice, "seed": int(ev.get("id", 1)) * 53 + 11}] # 最新者优先
	if not _running:
		_drain()

func _drain() -> void:
	_running = true
	while not _pending.is_empty():
		var job: Dictionary = _pending.pop_front()
		visible = true
		modulate.a = 1.0
		dice3d.speed = speed
		dice3d.play_set(job["dice"], int(job["seed"]), palette)
		played += 1
		while dice3d.is_playing():
			await get_tree().process_frame
		await get_tree().create_timer(HOLD / speed).timeout
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	await tw.finished
	if _pending.is_empty():
		visible = false
		dice3d.clear()
	_running = false
	if not _pending.is_empty():
		_drain()
