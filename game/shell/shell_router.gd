# 壳选择路由（09 §2/§3/§8；tech/02 §2.1 presentation 声明）
# - 按 manifest `presentation` 解析遭遇壳形态：mode=space/time 直接落定；mode=choice 时按启动参数
#   `-- --mode=space|time`（缺省 time）；`forced` 幕（如 SL-0/SL-3）强制声明形态并以叙事化提示呈现
#   （09 §3：包装文案禁止系统腔，不出现"模式已锁定"等字样）；
# - 形态是战役级属性，单局内禁止切换（09 §8）：遭遇开始即 lock，此后任何切换请求拒绝。
class_name ShellRouter
extends RefCounted

const MODE_SPACE := &"space" # 横屏·空间形态（04 §③）
const MODE_TIME := &"time"   # 竖屏·时间形态（04 §④）

## 强制形态的叙事化包装文案（09 §3：禁止系统腔）。
const NOTICE_FORCED := {MODE_TIME: &"NOTICE_FORCED_TIME", MODE_SPACE: &"NOTICE_FORCED_SPACE"}

## 强制形态提示文案（按当前语言）。
static func forced_notice(mode: StringName) -> String:
	return str(Texts.t(NOTICE_FORCED[mode])) if NOTICE_FORCED.has(mode) else ""

var _locked := false
var locked_mode: StringName = &""

## 横屏空间形态是否可用（tech/01 §10.1：英文版 v1 竖屏优先，横屏 v1.1 开放）。
## 工程设置 game/features/landscape（桌面缺省开；.mobile 覆盖为关），测试可直接改设置。
static func landscape_enabled() -> bool:
	return bool(ProjectSettings.get_setting("game/features/landscape", true))

## 生效形态：横屏未开放时一律落竖屏（choice / forced space / 子游戏参战同一口径）。
static func effective(mode: StringName) -> StringName:
	return MODE_TIME if mode == MODE_SPACE and not landscape_enabled() else mode

## 解析壳形态。presentation = manifest.presentation；cli_args = OS.get_cmdline_user_args()；
## story_line_id = 当前遭遇所属幕（forced 按幕强制）。返回 {mode, forced, notice}。
static func resolve(presentation: Dictionary, cli_args: PackedStringArray, story_line_id: String) -> Dictionary:
	var forced: Dictionary = presentation.get("forced", {})
	if forced.has(story_line_id):
		var m := StringName(str(forced[story_line_id]))
		return {"mode": m, "forced": true, "notice": forced_notice(m)}
	match str(presentation.get("mode", "time")):
		"space":
			return {"mode": MODE_SPACE, "forced": true, "notice": ""}
		"choice":
			return {"mode": cli_mode(cli_args), "forced": false, "notice": ""}
		_:
			return {"mode": MODE_TIME, "forced": true, "notice": ""}

## choice 模式下的启动参数解析：`-- --mode=space|time`，缺省 time。
static func cli_mode(cli_args: PackedStringArray) -> StringName:
	for a: String in cli_args:
		if a == "--mode=space":
			return MODE_SPACE
		if a == "--mode=time":
			return MODE_TIME
	return MODE_TIME

## 遭遇开始 → 壳锁定（09 §8：单局内不存在横竖屏切换入口）。
func lock_encounter(mode: StringName) -> void:
	_locked = true
	locked_mode = mode

func is_locked() -> bool:
	return _locked

## 切换请求：锁定后一律拒绝（返回 false）。
func request_switch(_mode: StringName) -> bool:
	return not _locked
