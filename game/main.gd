# 节点流程版流程控制器（tech/01 §10；04 §2 导航闭环 + §3.1/§④.2/§④.3；07 §4 存档；09 §3/§6/§7/§8/§9.1；tech/02 §3/§4/§5）
# 战役级横竖屏边界（09 §8）：开始战役即按所选形态切窗口与壳（横屏=横屏窗口+横屏壳，整备/叙事/战斗/结算同形态）；
#   幕级 forced 例外照旧（SL-0/SL-3 强制竖屏，幕末 forced_except 切回所选形态）；战役结束一切路径
#   （通关结局 / ☰ 中途退出 / 败北）恢复原屏幕布局（竖屏基准）；外层界面（主屏/功能界面）恒定竖屏；
#   全部数据驱动自 manifest presentation（mode + forced/forced_except），代码不写死任何战役。
# 串流：①主屏 → ②战役入口（模式分支，09 §3）→ **故事图驱动节点流程**（序章 N0-1 → … → 终章 E1~E4）：
#   scene/check/dialog/hub 节点由双壳故事态呈现（StoryVM 单源）；battle 节点进整备→遭遇→战后边回图；
#   强制幕（SL-0/SL-3）按 presentation.forced 换壳并以叙事化提示呈现（09 §3；N3-7 起 forced_except 解锁）；
#   结局节点 → 结局屏（tech/02 §9：四分型文案 + 多周目钩子 + 开始二周目）→ NG+ / 回主屏 / ⑧历史卷轴。
# 存档时机（07 §4.2）：切片/遭遇结算完成（主快照）+ 主屏闲置（兜底）+ 主屏手动"记录抄本"；
# 遭遇进行中不存档——☰「保存并回主屏」= 恢复遭遇进入前快照（09 §7，战斗重打）；
# 故事态（遭遇外）☰ = 存档后回主屏（节点进度在图快照 meta.graph 内）。
# 战斗数值由 packs 资源表驱动（tech/04 §1~§4 / tech/02 §6）：BattleDef.assemble 组装，引用缺失 fail-fast。
# 调试：`-- --m2n-shots` 走图截图 /tmp/m2n_*.png（不提交）；`-- --m3-shots` 子游戏截图；
# `-- --m4-shots` 锁定态/购买弹层截图；`-- --skin-shots` 外观页/换肤骰子截图（06 §7）；
# `-- --mode=space|time` 预选形态；`-- --mode-shots` 横屏战役边界截图；
# `-- --text-shots` 长文本外置呈现截图 /tmp/text_*.png（tech/02 §1.1，不提交）；
# `-- --font-shot` 整备「稳守」预设卡字体证据 /tmp/font_fixed.png（04 §7，不提交）；
# `-- --trans-shots` 转场中间帧+战斗对焦帧 /tmp/trans_*.png（14 清单 #8，不提交）。
extends Node

# 本切片范围：完整战役 M1（序章 → 幕一 → 幕二四链 → 幕三撤销区房间序列 → 终章 Boss/抉择/结局）；
# 结局节点（E1~E4）进结局屏（tech/02 §9），战斗失败仍走 ⑨ 结算（失败即分支，09 §7）。
const SLICE_ACTS: Array[String] = ["SL-0", "SL-1", "SL-2", "SL-3", "SL-4"]
const LANDSCAPE_SIZE := Vector2i(1280, 720)
const PACKS_ROOT := "res://packs"
## 本次启动的包根目录（`-- --packs-root=res://kit` 直接把新游戏工具包当整款游戏启动，tech/07 §4）。
var packs_root := PACKS_ROOT
const SHELL_SCENES := {
	&"time": "res://shell/portrait/encounter_portrait.tscn",
	&"space": "res://shell/landscape/encounter_landscape.tscn",
}
const SCREEN_SCENES := {
	&"home": "res://shell/ui/screen_home.tscn",
	&"entry": "res://shell/ui/screen_entry.tscn",
	&"loadout": "res://shell/ui/screen_loadout.tscn",
	&"settle": "res://shell/ui/screen_settle.tscn",
	&"history": "res://shell/ui/screen_history.tscn",
	&"quests": "res://shell/ui/screen_quests.tscn",
	&"inventory": "res://shell/ui/screen_inventory.tscn",
	&"character": "res://shell/ui/screen_character.tscn",
	&"ending": "res://shell/ui/screen_ending.tscn",
}
var stream: EventStream
var audio: AudioManager # 音频框架（14 清单 #5：纯呈现消费事件流，纯壳侧组件）
var transition: UiTransition # 统一转场器（14 清单 #8：界面切换淡入淡出 + 遭遇进场滑入，纯壳侧组件）
var board: Board
var rng: Rng
var entitlements: Entitlements      # 权利模型运行时（06 §2：商店/活动/成就三类点亮方）
var store: Store                    # 商店（shell/store：Mock 或平台适配器；06 §7）
var cosmetics: Cosmetics            # 外观系统运行时（06 §3/§7：皮肤只写外观旗标，纯演出）
var ops_config: Dictionary = {}     # 运营侧配置（06 §3.2：点亮在运营，不进内容包管线）
var graph: StoryGraph
var pack: Dictionary = {}
var router := ShellRouter.new()
var current_screen: Control = null
var shell: Control = null

# ---- 子游戏（白皮书 §10.2；04 §6：入口挂 ② 战役入口区，进出场必经 ⑨ 结算）----
var _campaign_id := ""                # 当前主战役包 id（包目录发现，不写死）
var campaign: CampaignFlow           # 战役流程对象（campaign_flow.gd，代码评审 M2）
var sub_flow: SubgameFlow             # 子游戏流程对象（subgame_flow.gd，代码评审 M2）
var _subgames: Dictionary = {}        # pack_id -> pack（pack_type=subgame 数据驱动入列，不写死 arena）
# ---- 支线（tech/02 §2.6 graft，M4）：pack_type=arc 注入主战役合并视图，宿主数据不动 ----
var _arcs: Dictionary = {}            # pack_id -> arc pack（已发现支线包）
var _pack_host: Dictionary = {}       # 宿主包（未注入支线；合并视图 = graph.pack）

var _cli_mode: StringName = &""
var window_orientation: StringName = ShellRouter.MODE_TIME # 窗口形态（09 §8 战役级边界断言口；竖屏基准）
# ---- 迷宫探索序列（tech/02 §6 maze；04 §④.3 房间类型序列化）----
var _history_origin: StringName = &"home"
var _shot_driver: RefCounted = null # tools/shot_driver.gd（仅命令行截图旗标时加载）

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_cli_mode = ShellRouter.cli_mode(args) if args.has("--mode=space") or args.has("--mode=time") else &""
	var shots: Script = null
	if Array(args).any(func(a: String) -> bool: return a.ends_with("-shot") or a.ends_with("-shots")):
		shots = load("res://tools/shot_driver.gd") # 开发截图驱动（导出时排除 tools/，代码评审 M2）
		Rng.fixed_seed_override = shots.SHOT_SEED
		ProjectSettings.set_setting("game/market", "cn") # 截图走查覆盖完整战役（可用 --market=global 看锁定页）
		SaveSystem.save_dir = "user://shots/saves" # 截图从全新开局起步，且不触碰玩家真实存档/设置
		SaveSystem.delete()
		UiSettings.redirect_path = "user://shots/settings.cfg"
		CampaignFlow.skip_hero_creation = not args.has("--hero-shots") # 截图走缺省主角，建角截图单独开
	for a: String in args: # `-- --seed=N`：指定新开局种子（复现问题用）；`-- --locale=en`：指定语言（截图/走查）
		if a.begins_with("--seed="):
			Rng.fixed_seed_override = int(a.trim_prefix("--seed="))
		elif a.begins_with("--locale="):
			Texts.forced_locale = a.trim_prefix("--locale=")
		elif a.begins_with("--market="): # `-- --market=global|cn`：发行市场（锁定页 / 随本体权利走查）
			ProjectSettings.set_setting("game/market", a.trim_prefix("--market="))
		elif a.begins_with("--safe-area="): # `-- --safe-area=上,右,下,左`：桌面模拟刘海/Home 指示条
			SafeArea.override_insets = SafeArea.parse_arg(a)
		elif a.begins_with("--phone-size="): # `-- --phone-size=390x910`：桌面模拟窄长手机（竖屏窗口尺寸）
			var wh := a.trim_prefix("--phone-size=").split("x")
			if wh.size() == 2:
				phone_size_override = Vector2i(int(wh[0]), int(wh[1]))
				get_window().size = phone_size_override
		elif a.begins_with("--packs-root="): # `-- --packs-root=res://kit`：换一整款游戏（游戏清单 + 内容包，tech/07）
			packs_root = a.trim_prefix("--packs-root=")
			GameManifest.override_path = packs_root.path_join("_game/game.json")
			GameManifest.reset()
			Texts.clear_cache()
	_setup_cjk_font() # 主题在 --packs-root 之后构建：换游戏的调色板 / 字体进主题（tech/07 §3）
	UiFx.install(get_tree()) # UI 动效：按钮回弹 / 标题样式 / 弹层入场（tech/05 §10）
	# 界面语言（tech/01 E-5）：玩家偏好 → 系统语言；内容包按同一语言加载文本
	Texts.set_locale(Texts.detect_locale(UiSettings.load_locale()))
	PackLoader.locale = Texts.locale
	var campaign_dir := _find_campaign_dir()
	if campaign_dir == "":
		push_error("[main] res://packs 下没有 pack_type=campaign 的内容包")
		return
	var res := PackLoader.load_pack(campaign_dir)
	if not res["ok"]:
		push_error("%s 加载失败：%s" % [campaign_dir, ";".join(res["errors"])])
		return
	pack = res["pack"]
	_campaign_id = str(pack["pack_id"])
	_discover_subgames()
	stream = EventStream.new()
	audio = AudioManager.new() # 14 #5：先就位，_show_home 的翻页/潮声才有落点
	add_child(audio)
	stream.subscribe(audio.on_event) # 纯呈现订阅（与 JuiceLayer 同模式，不回注）
	transition = UiTransition.new() # 14 #8：先就位，_show_home 的首场切换即走转场
	add_child(transition)
	board = Board.new(stream)
	rng = Rng.new(Rng.new_game_seed()) # 每次新开局新种子（tech/01 §5.2）；读档时由快照覆盖
	# 启动读回（07 §4.2）：先恢复状态板与 RNG——支线注入与活动点亮都要读恢复后的权利状态
	var resumed := _read_resume_snapshot()
	if not resumed.is_empty():
		stream.restore(resumed.get("events", {})) # 历史卷轴跨启动可追溯（tech/01 E-3）
		SaveSystem.apply(resumed, board, rng)
	# 权利运行时 + 运营配置（06 §3.2：活动开关开 → 入口自动解锁，内容包零改动）
	entitlements = Entitlements.new(board, stream)
	ops_config = Entitlements.load_ops_config(packs_root.path_join("_ops/ops_config.json")) # 运营配置随本作（tech/07：新游戏可不带运营位）
	entitlements.apply_activities(ops_config)
	entitlements.apply_market_grants(ops_config, _market()) # 国内本体免费 / 海外试玩 + 解锁（06 §7）
	store = Store.create()
	store.purchase_finished.connect(_on_store_purchase)
	store.restore_finished.connect(_on_store_restore)
	store.revoked.connect(_on_store_revoked)
	cosmetics = Cosmetics.new(board, stream) # 皮肤注册表 = 运营侧数据（06 §7：packs/_ops/cosmetics.json）
	graph = StoryGraph.new(board, rng, pack)
	_pack_host = pack
	_discover_arcs()
	if not resumed.is_empty(): # 故事图进度在支线注入后恢复（合并视图含支线事件定义）
		graph.deserialize((resumed.get("meta", {}) as Dictionary).get("graph", {}))
		stream.emit(EventTypes.LOG, {"msg_key": "MSG_RESUMED"}, &"core")
	HeroBuild.apply(pack, board) # 主角构筑叠回玩家模板（读档 / 新开局均幂等，11 §1.1）
	if graph.pack != pack:
		HeroBuild.apply(graph.pack, board)
	campaign = CampaignFlow.new(self)
	sub_flow = SubgameFlow.new(self)
	stream.subscribe(_on_event)
	_show_home()
	if shots != null:
		_shot_driver = shots.new(self)
		_shot_driver.run(args)

# ---------------------------------------------------------------- 应用生命周期与返回键（tech/01 §10.1；09 §7）

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			on_app_background()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			on_back_requested()

## 切后台 / 关闭：遭遇外兜底落档（遭遇进行中不存档——进程被杀至多损失当前这一局，09 §7）。
## 返回是否已落档。
func on_app_background() -> bool:
	if board == null or graph == null or campaign == null or campaign._in_encounter or sub_flow == null or sub_flow._sub_battling:
		return false
	_save("background")
	return true

## Android 返回键 / 系统返回手势：遭遇与故事态 = 打开 ☰ 菜单；功能界面 = 走该界面的返回出口；
## 主屏 = 先关帮助页，否则落档并退出。返回执行的动作名（测试与日志用）。
func on_back_requested() -> String:
	if shell != null and is_instance_valid(shell) and current_screen == shell and shell.has_method("_open_menu"):
		shell.call("_open_menu")
		return "menu"
	if current_screen is ScreenHome:
		var home := current_screen as ScreenHome
		if home.is_help_open():
			home.close_help()
			return "close_help"
		on_app_background()
		get_tree().quit()
		return "quit"
	if current_screen != null and current_screen.has_signal("back_requested"):
		current_screen.emit_signal("back_requested")
		return "back"
	_show_home()
	return "home"

## 主战役包发现（白皮书 §10.1：框架不写死内容包）：pack_type=campaign 的包中，manifest.entry=true 者优先，
## 否则取目录名序第一个。
func _find_campaign_dir() -> String:
	var preferred := GameManifest.default_campaign() # 游戏清单指定默认战役（tech/07 §3）
	if preferred != "" and FileAccess.file_exists(packs_root.path_join(preferred).path_join("manifest.json")):
		return packs_root.path_join(preferred)
	var found := ""
	for sub: String in DirAccess.get_directories_at(packs_root):
		if sub.begins_with("_"):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			packs_root.path_join(sub).path_join("manifest.json")))
		if not (raw is Dictionary) or str((raw as Dictionary).get("pack_type", "")) != "campaign":
			continue
		if bool((raw as Dictionary).get("entry", false)):
			return packs_root.path_join(sub)
		if found == "":
			found = packs_root.path_join(sub)
	return found

## 本战役多周目周目数键（manifest.ngplus.carries.playthrough；缺省 <id>.ngplus）。
func _playthrough_key() -> String:
	return str(((((pack.get("manifest", {}) as Dictionary).get("ngplus", {}) as Dictionary)
		.get("carries", {}) as Dictionary).get("playthrough", "%s.ngplus" % _campaign_id)))

## 启动读回最近快照（07 §4.2 启动读回；代码评审 B1）：读档 → 迁移链。
## 无档 = 新开局；坏档/未来版本 = 告警并按新开局处理（原档保留，直到下次写档才被替换）。
func _read_resume_snapshot() -> Dictionary:
	var res := SaveSystem.read()
	if not bool(res["ok"]):
		if str(res.get("error", "")) != "empty":
			push_warning("[main] 存档不可读（%s），按新开局处理" % str(res["error"]))
		return {}
	var mig := SaveSystem.migrate(res["snapshot"])
	if not bool(mig["ok"]):
		push_warning("[main] 存档迁移失败（%s），按新开局处理" % str(mig["error"]))
		return {}
	return mig["snapshot"]

## 子游戏包发现（白皮书 §10.2/§10.3）：扫描 packs/ 全部包目录，pack_type=subgame 即入列——
## 数据驱动，不写死 arena；加载失败只告警不阻断（单包缺陷不拖垮框架，tech/02 §1 向前兼容）。
func _discover_subgames() -> void:
	var dir := DirAccess.open(packs_root)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		if sub.begins_with("_"):
			continue # _ops 等运营目录非内容包（06 §3.2：运营配置不进内容包管线）
		if sub == str(pack.get("pack_id", "")) or not GameManifest.pack_enabled(sub):
			continue # 游戏清单未启用的包不入列（tech/07 §3）
		var res := PackLoader.load_pack(packs_root.path_join(sub))
		if not res["ok"]:
			push_warning("[main] 包 %s 加载失败（跳过）：%s" % [sub, ";".join(res["errors"])])
			continue
		var p: Dictionary = res["pack"]
		if str((p["manifest"] as Dictionary).get("pack_type", "")) == "subgame":
			_subgames[str(p["pack_id"])] = p

# ---------------------------------------------------------------- 支线包（tech/02 §2.6 graft，M4；白皮书 §10.4 内容轨）
# 发现：pack_type=arc 且 graft.into=主战役即入列；注入：权利门槛通过才 graft（06 §3.1 硬门槛，
# 未点亮 = 不注入，宿主图与未安装逐字节一致）。合并视图 = graph.pack（宿主数据不动，PackLoader.merge_graft）。

func _discover_arcs() -> void:
	var dir := DirAccess.open(packs_root)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		if sub.begins_with("_"):
			continue
		if sub == str(pack.get("pack_id", "")):
			continue
		if _subgames.has(sub) or not GameManifest.pack_enabled(sub):
			continue # 子游戏已入列（pack_type 互斥）；游戏清单未启用的包不入列
		var res := PackLoader.load_pack(packs_root.path_join(sub))
		if not res["ok"]:
			push_warning("[main] 包 %s 加载失败（跳过）：%s" % [sub, ";".join(res["errors"])])
			continue
		var p: Dictionary = res["pack"]
		var manifest: Dictionary = p["manifest"]
		if str(manifest.get("pack_type", "")) != "arc":
			continue
		if str((manifest.get("graft", {}) as Dictionary).get("into", "")) != str(pack.get("pack_id", "")):
			continue # 挂接目标非本战役（多战役预留）
		_arcs[str(p["pack_id"])] = p
	_graft_discovered_arcs()

## 注入全部已发现且权利通过的支线；NG+ 重建图时重放（权利状态随新板再判定）。
func _graft_discovered_arcs() -> void:
	for pid: String in _arcs:
		var p: Dictionary = _arcs[pid]
		if not entitlements.can_access(p["manifest"]):
			continue # 未解锁 = 不注入（tech/02 §2.2/§2.6）
		var gres: Dictionary = graph.graft_pack(p)
		if not bool(gres["ok"]):
			push_warning("[main] 支线 %s 注入失败（跳过）：%s" % [pid, ";".join(gres["errors"] as Array)])
	pack = graph.pack # 合并视图（无注入时 = 宿主原包）：BattleDef/StoryVM/图鉴同源消费（§2.6）

# ---------------------------------------------------------------- 导航（04 §2/§5：任何界面有明确来路退路）

## 界面切换统一走转场器（14 #8 淡入淡出，硬切消除）：逻辑即时换屏（current_screen 就位、
## 绑定/连信号照常），视觉上旧屏在淡出段保持可点（幕布不吞输入），中场回收旧屏、新屏现身。
func _swap(screen: Control) -> void:
	var old := current_screen
	var old_shell := shell
	current_screen = screen
	UITheme.attach(screen) # 主题经 Control 链下发（根为普通 Node，Window.theme 穿不透）
	add_child(screen)
	if transition != null:
		screen.visible = false # 淡出中场现身（14 #8；逻辑可用，视觉切换在转场中场）
		var freeing := old != null and old != old_shell
		transition.swap_at_mid(old if freeing else null, null if freeing else old_shell, screen)
	else:
		if old != null and old != old_shell:
			old.queue_free()
		elif old_shell != null:
			old_shell.visible = false
	if audio != null:
		audio.play_sfx(&"page") # 翻页（界面切换，14 #5 SFX 通道）
		audio.set_home_ambient(screen is ScreenHome) # 主屏常播港口潮声（14 #6）

# ---------------------------------------------------------------- 窗口形态（09 §8 战役级横竖屏边界）

## 竖屏基准尺寸 = 项目窗口配置（竖屏基准由工程设置声明，代码不写死）。
## 桌面模拟手机比例：`-- --phone-size=390x910`（窄长屏走查；真机不受影响）。
var phone_size_override := Vector2i.ZERO

func _portrait_size() -> Vector2i:
	if phone_size_override != Vector2i.ZERO:
		return phone_size_override
	return Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width", 390)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 760)))

## 窗口形态切换（09 §8）：space = 横屏窗口（1280×720），time = 竖屏基准。
## 开始战役即切所选形态；战役内常态保持（幕级 forced 例外经同一通道）；战役结束一切路径调 MODE_TIME 恢复。
## headless 下不动物理窗口（无显示服务器），window_orientation 照常记账供无头断言。
func _set_window_orientation(mode: StringName) -> void:
	window_orientation = mode
	if DisplayServer.get_name() == "headless":
		return
	if OS.has_feature("mobile"):
		# 真机：切设备屏幕方向（tech/01 §10.1）；桌面窗口缩放只是开发便利
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE
			if mode == ShellRouter.MODE_SPACE else DisplayServer.SCREEN_PORTRAIT)
		return
	get_window().size = LANDSCAPE_SIZE if mode == ShellRouter.MODE_SPACE else _portrait_size()
	get_window().move_to_center()

func _show_home() -> void:
	_set_window_orientation(ShellRouter.MODE_TIME) # 外层界面恒定竖屏（09 §8：一切离场路径恢复竖屏基准）
	if audio != null:
		audio.to_home() # BGM 收止（14 #5：主屏无常驻 BGM，潮声由 _swap 的 set_home_ambient 接管）
	campaign._in_encounter = false
	sub_flow._sub_active = false # 回主屏即子游戏离场（04 §6：离场必经结算，未到结算即放弃本次连战）
	sub_flow._sub_battling = false
	sub_flow._sub = null
	if shell != null: # 壳随离场回收（09 §7 结算态之后为正常离场）
		shell.queue_free()
		shell = null
	var home: ScreenHome = (load(SCREEN_SCENES[&"home"]) as PackedScene).instantiate()
	_swap(home)
	# 运营位接运营配置（06 §6：home_promo 块投放，空配置不出空位）
	home.bind(board, graph.quest_badge_count(), _has_continuable(),
		(ops_config.get("home_promo", {}) as Dictionary))
	home.navigate.connect(_on_home_navigate)
	home.promo_pressed.connect(_on_home_promo)
	home.save_requested.connect(_save_home)
	home.idle_timeout.connect(_save_idle)
	home.tutorial_done.connect(func() -> void: _tutorial_mark("boot")) # 启动卡一次性（12 §4）
	home.retrain_requested.connect(_on_retrain) # 重学入口（12 §4：可重学）
	home.language_requested.connect(_on_language_requested)
	home.restore_requested.connect(_restore_purchases)
	if not bool(board.read("global.tutorial.boot", false)):
		home.show_launch_tutorial() # 首次启动 3 页核心手势卡（12 §4 第一层）
	router = ShellRouter.new() # 回主屏即离场：壳锁定随单局结束（09 §8）

## 教程触发记录（12 §4：写 global.tutorial.<id>，一次原则，不因重开重复打扰）。
func _tutorial_mark(id: String) -> void:
	board.write("global.tutorial.%s" % id, true,
		{"event_id": stream.tail(), "node_id": graph.current_id, "pack_id": "system"})

func _tutorial_seen(id: String) -> bool:
	return bool(board.read("global.tutorial.%s" % id, false))

## 重学：清全部教程触发记录（重放启动卡 + 情境提示恢复一次），再重放启动卡（12 §4）。
## 切换界面语言（tech/01 E-5）：记偏好 → 落档 → 重载主场景（启动读回续玩，文本按新语言重新加载）。
func _on_language_requested(l: String) -> void:
	UiSettings.save_locale(l)
	_save("language")
	get_tree().reload_current_scene()

func _on_retrain() -> void:
	for key: String in board.keys_with_prefix("global.tutorial."):
		board.write(key, false, {"event_id": stream.tail(), "node_id": graph.current_id,
			"pack_id": "system"})
	_show_home()
	if current_screen is ScreenHome:
		(current_screen as ScreenHome).show_launch_tutorial()

## 情境教程（12 §4 第二层：首次进入某情境，每类一次；半透明遮罩+高亮，非模态）。
func _context_hint(id: String, text: String) -> void:
	if _tutorial_seen(id):
		return
	if shell != null and shell.has_method("show_tutorial_hint"):
		shell.call("show_tutorial_hint", id, text)
	_tutorial_mark(id)

func _on_home_navigate(screen_id: StringName) -> void:
	audio.play_ui(&"ui_click") # UI 点击音（14 #5）
	match screen_id:
		&"entry":
			_show_entry()
		&"quests":
			_show_quests()
		&"inventory":
			_show_inventory()
		&"character":
			_show_character()
		&"history":
			_history_origin = &"home"
			_show_history()

## 运营位点按路由（06 §6）：target="codex" → ⑥ 背包图鉴；target=pack_id → ② 战役入口对应卡，
## 锁定包直达购买半屏弹层（06 §3.1/§6：锁定态卡 +「获取」；弹层不离开当前界面情境，04 §3.3）。
## 本函数只做导航路由：不写板、不进事件流（运营位是纯呈现层挂载点）。
func _on_home_promo(target: String) -> void:
	if target == "codex":
		_show_inventory()
		return
	if not _subgames.has(target):
		push_warning("[main] home_promo 目标未登记为已发现包：%s（忽略，06 §6 容错不阻断）" % target)
		return
	_show_entry()
	if not entitlements.can_access((_subgames[target] as Dictionary)["manifest"]):
		_on_acquire_requested(target) # 锁定包 → 直达购买弹层（06 §6）

func _show_entry() -> void:
	_set_window_orientation(ShellRouter.MODE_TIME) # 外层界面恒定竖屏（09 §8）
	var entry: ScreenEntry = (load(SCREEN_SCENES[&"entry"]) as PackedScene).instantiate()
	_swap(entry)
	var played: Array = []
	var played_raw: Variant = board.read("global.mode_choice.%s" % _campaign_id)
	if played_raw is String and str(played_raw) != "":
		played.append(str(played_raw))
	entry.bind(pack, played, _collect_pct())
	entry.mode_chosen.connect(_on_mode_chosen)
	entry.start_requested.connect(_on_campaign_start.bind(entry))
	entry.back_requested.connect(_show_home)
	# 子游戏卡（04 §6 特殊战役书卡）：manifest 数据驱动（名称/建议等级/模式/战绩键）；
	# 权利门槛未点亮 → 锁定态卡（06 §3.1：可见但锁定 + 叙事化文案 +「获取」）
	var cards: Array = []
	for pid: String in _subgames:
		var p: Dictionary = _subgames[pid]
		var manifest: Dictionary = p["manifest"]
		var runner := SubgameRunner.new(p, board, stream, rng)
		cards.append({"pack_id": pid, "name": str(manifest.get("name", pid)),
			"level_min": int((manifest.get("recommended_level", [1]) as Array)[0]),
			"mode": str((manifest.get("presentation", {}) as Dictionary).get("mode", "choice")),
			"stats": runner.stats(),
			"locked": not entitlements.can_access(manifest),
			"lock_text": str(manifest.get("lock_text", Texts.s(&"LOCK_DEFAULT")))})
	entry.bind_subgames(cards)
	entry.subgame_start.connect(_on_subgame_start)
	entry.acquire_requested.connect(_on_acquire_requested)
	entry.shop_popup.purchase_confirmed.connect(_on_purchase_confirmed)
	if _cli_mode != &"":
		entry.pick_mode(_cli_mode)
	elif not played.is_empty():
		entry.pick_mode(StringName(str(played[0]))) # 已选模式预选（09 §3 整场锁定；04 §② 已玩标记）




# ---------------------------------------------------------------- 节点流程（故事图驱动；UI 只消费 StoryVM + 事件流）










# ---------------------------------------------------------------- 结局与多周目（tech/02 §9；战役书 §9/§8）



# ---------------------------------------------------------------- 迷宫探索序列（tech/02 §6 maze 块；04 §④.3）
# 逐拍呈现：check/ambush 拍掷 d20+修正（与检定边同一公式，11 §2/§3），loot 拍写板拾取；
# 节拍效果/进度全部由 MazeRunner 落 core（写板带溯源、进事件流），本层只转发与刷新。





# ---------------------------------------------------------------- 整备（09 §9.1；tech/02 §2.4）







# ---------------------------------------------------------------- 遭遇（09 §2/§7/§8；tech/02 §2.1）




# ---------------------------------------------------------------- 结算（04 §⑨；07 §4.2 主快照点）

func _on_event(ev: Dictionary) -> void:
	if ev["type"] == EventTypes.LORE_UNLOCK:
		# 图鉴集齐奖励到账（10 §4 v1.1：聚合全包 lore 判定；命骰考 → 骰子皮肤，纯演出）
		cosmetics.check_codex_rewards(_all_lore_defs())
	if ev["type"] == EventTypes.COMBAT_END and sub_flow._sub_active and sub_flow._sub_battling:
		sub_flow._sub_on_combat_end(ev["payload"]["result"]) # 子游戏连战路由（04 §6）
		return
	if ev["type"] == EventTypes.COMBAT_START:
		# 情境教程：首次战斗（12 §4：拖动移动 + 轨迹施法 + 双指点击结束回合 + 捏合缩放）
		_context_hint("combat", Texts.s(&"TUT_HINT_COMBAT"))
	if ev["type"] == EventTypes.CHECK_ROLL and bool(ev["payload"].get("key", false)):
		# 情境教程：首次关键判定（可跳过演出，04 §④.7 长按跳过）
		_context_hint("key_roll", Texts.s(&"TUT_HINT_KEY"))
	if ev["type"] == EventTypes.COMBAT_END and campaign._in_encounter:
		campaign._encounter_result = ev["payload"]["result"]
		_show_settle_deferred()






# ---------------------------------------------------------------- ⑤⑥⑦⑧ 功能界面（04 §⑤⑥⑦⑧ 最小版）

func _show_quests() -> void:
	_set_window_orientation(ShellRouter.MODE_TIME) # 外层界面恒定竖屏（09 §8）
	var screen: ScreenQuests = (load(SCREEN_SCENES[&"quests"]) as PackedScene).instantiate()
	_swap(screen)
	screen.bind(graph.quests())
	screen.abandon_requested.connect(func(qid: String) -> void:
		graph.abandon_quest(qid) # 放弃写旗标 + 事件在 core（04 §⑤）；放弃后归档历史卷轴
		_show_quests())
	screen.back_requested.connect(_show_home)

func _show_inventory() -> void:
	_set_window_orientation(ShellRouter.MODE_TIME) # 外层界面恒定竖屏（09 §8）
	var screen: ScreenInventory = (load(SCREEN_SCENES[&"inventory"]) as PackedScene).instantiate()
	_swap(screen)
	screen.bind(board.get_inv(), pack.get("items", {}), board.get_lore(), _all_lore_defs(),
		pack.get("texts", {})) # tech/02 §1.1：图鉴正文 text_ref 解析数据源
	_bind_cosmetics(screen)
	screen.back_requested.connect(_show_home)

## 外观页绑定与写板通道（06 §3/§6/§7：装备/购买写外观旗标，仅 system 可写，07 §3 v1.2）。
func _bind_cosmetics(screen: ScreenInventory) -> void:
	var owned: Array = []
	for e: Variant in cosmetics.skins():
		var sid := str((e as Dictionary).get("id", ""))
		if cosmetics.is_owned(sid):
			owned.append(sid)
	screen.bind_cosmetics(cosmetics.skins(), owned, cosmetics.equipped_id())
	if not screen.equip_requested.is_connected(_on_skin_equip):
		screen.equip_requested.connect(_on_skin_equip)
		screen.unequip_requested.connect(_on_skin_unequip)
		screen.skin_purchase_requested.connect(_on_skin_purchase)

func _on_skin_equip(skin_id: String) -> void:
	if cosmetics.equip(skin_id):
		_show_inventory() # 重进刷新（与购买解锁同一「写入即生效」哲学，06 §3.1）

func _on_skin_unequip() -> void:
	if cosmetics.unequip():
		_show_inventory()

## 商店外观商品购买确认 → 商店点亮方写板（单号溯源，06 §2.3/§7）→ 外观页当场刷新。
func _on_skin_purchase(skin_id: String) -> void:
	var receipt_id := "rcpt_skin_%d" % stream.tail() # mock 单号（真实支付接入是运营立项留白，06 §8）
	if not cosmetics.shop_purchase(skin_id, receipt_id):
		return
	stream.emit(EventTypes.LOG,
		{"msg_key": "MSG_SKIN_SHOP", "args": {"skin": cosmetics.skin_name(skin_id)},
			"toast": true}, &"core")
	_show_inventory()

## 全部已加载内容包的 lore 条目聚合（10 §4 v1.1：集齐判定跨包；主战役 + 子游戏 + 支线）。
func _all_lore_defs() -> Array:
	var out: Array = []
	out.append_array(pack.get("lore", []))
	for pid: String in _subgames.keys():
		out.append_array((_subgames[pid] as Dictionary).get("lore", []))
	for pid: String in _arcs.keys():
		out.append_array((_arcs[pid] as Dictionary).get("lore", []))
	return out

func _show_character() -> void:
	_set_window_orientation(ShellRouter.MODE_TIME) # 外层界面恒定竖屏（09 §8）
	var screen: ScreenCharacter = (load(SCREEN_SCENES[&"character"]) as PackedScene).instantiate()
	_swap(screen)
	# 返回连接先于数据绑定（M2 审计 G1：绑定路径任何早期返回都不得带走出口）
	screen.back_requested.connect(_show_home)
	var bonds := {}
	for key: String in board.keys_with_prefix("global.bond."):
		bonds[key.trim_prefix("global.bond.")] = board.read(key)
	# 队伍卡 = 名册直组（StoryGraph.party_roster，04 §⑦），与战斗定义解耦——
	# 主屏/非战斗上下文无当前遭遇，不得走 _battle_def（M2 审计 G1：组装失败曾致脚本错误+软锁）。
	# 成长区（tech/04 §8）：等级 / XP 进度 / 已分配属性 / 未分配点数
	screen.lead_info = {"enabled": graph.party.lead_enabled(), "lead": graph.party.lead_char()}
	screen.lead_requested.connect(func(cid: String) -> void:
		graph.party.set_lead(cid, graph.current_id)
		_save("lead")
		_show_character())
	screen.bind(graph.party_roster(), bonds, Growth.xp_progress(board))

## ⑧ 历史卷轴：从主屏 / 结算进入，返回来源界面（04 §5 出口列）。
func _show_history() -> void:
	_set_window_orientation(ShellRouter.MODE_TIME) # ⑧历史卷轴为功能界面：恒定竖屏（09 §8）
	var screen: ScreenHistory = (load(SCREEN_SCENES[&"history"]) as PackedScene).instantiate()
	_swap(screen)
	screen.bind(stream, board)
	screen.back_requested.connect(func() -> void:
		if _history_origin == &"settle":
			_bind_settle() # 返回来源界面（04 §5 出口列：结算→卷轴→结算）
		elif _history_origin == &"sub_settle":
			_sub_bind_settle() # 子游戏结算同理（04 §6：子游戏复用框架界面）
		else:
			_show_home())

# ---------------------------------------------------------------- 子游戏连战（白皮书 §10.2；04 §6；docs/subgames/arena/01-概念设计.md）
# 流程：② 入口卡 → A-0 演出 → 整备（仅进场一次）→ EncounterSM ×N（场间无休整，HP 持久 11 §7.1）
#   → 每场胜利写金币/胜场（SubgameRunner）→ 战后边（追击/收兵）→ ⑨ 结算（写板硬要求）→ 回主屏。
# 全部数据驱动自子游戏包（节点图/遭遇/奖励声明），core 零改动；本块是 §10.2"子游戏不动框架"的运行时落点。

# ---------------------------------------------------------------- 权利与商店（06 §2/§3/§6）

## 锁定卡「获取」→ 购买半屏弹层（06 §6：不离开当前界面情境；04 §3.3）。
func _on_acquire_requested(pack_id: String) -> void:
	if not _subgames.has(pack_id):
		return
	var entry := current_screen as ScreenEntry
	if entry == null:
		return
	var manifest: Dictionary = _subgames[pack_id]["manifest"]
	var price := Entitlements.price_of(ops_config, pack_id)
	entry.shop_popup.open(pack_id, str(manifest.get("name", pack_id)),
		str(price.get("price_text", "")))

## 购买确认 → 商店点亮方写板（单号溯源，06 §2.3）→ 入口当场刷新解锁（06 §3.1：购买即解锁无需重启）。
func _on_purchase_confirmed(pack_id: String) -> void:
	_buy(pack_id)

# ---------------------------------------------------------------- 商店（06 §7；shell/store）：购买 / 恢复 / 撤销

## 发行市场（工程设置 game/market；导出预设自定义特性覆盖，如 cn_store → cn）。
func _market() -> String:
	return str(ProjectSettings.get_setting("game/market", "global"))

## 发起购买：key = 运营配置 shop 条目键（= 权利键）。商店不可用时只提示，不点亮任何权利。
func _buy(key: String) -> void:
	var item := Entitlements.price_of(ops_config, key)
	var product_id := str(item.get("product_id", key))
	if not store.is_available():
		stream.emit(EventTypes.LOG, {"msg_key": "MSG_STORE_UNAVAILABLE", "toast": true}, &"core")
		return
	store.purchase(product_id)

func _on_store_purchase(product_id: String, ok: bool, receipt_id: String, error: String) -> void:
	var key := Entitlements.key_for_product(ops_config, product_id)
	if key == "":
		key = product_id
	if not ok:
		if error != "cancel":
			stream.emit(EventTypes.LOG, {"msg_key": "MSG_PURCHASE_FAILED", "args": {"error": error}, "toast": true}, &"core")
		return
	entitlements.shop_purchase(key, receipt_id)
	var item := Entitlements.price_of(ops_config, key)
	stream.emit(EventTypes.LOG,
		{"msg_key": "MSG_PURCHASED", "args": {"pack": str(item.get("name", key))}, "toast": true}, &"core")
	_refresh_after_unlock()

func _restore_purchases() -> void:
	if not store.is_available():
		stream.emit(EventTypes.LOG, {"msg_key": "MSG_STORE_UNAVAILABLE", "toast": true}, &"core")
		return
	store.restore()

func _on_store_restore(owned: Array) -> void:
	var n := 0
	for pid: Variant in owned:
		var key := Entitlements.key_for_product(ops_config, str(pid))
		if key != "" and entitlements.restore_grant(key, "restore:%s" % str(pid)):
			n += 1
	stream.emit(EventTypes.LOG, {"msg_key": "MSG_RESTORED", "args": {"n": n}, "toast": true}, &"core")
	_refresh_after_unlock()

## 平台撤销（退款）：权利置假；进行中的一局凭"本局已解锁"可跑完（06 §5）。
func _on_store_revoked(product_id: String) -> void:
	var key := Entitlements.key_for_product(ops_config, product_id)
	if key != "":
		entitlements.refund(key)

func _refresh_after_unlock() -> void:
	if current_screen is ScreenLocked:
		_present_node()
	elif current_screen is ScreenEntry:
		_show_entry()


# ---------------------------------------------------------------- 战役流程（委托 CampaignFlow，代码评审 M2）

func _on_mode_chosen(mode: StringName) -> void:
	campaign._on_mode_chosen(mode)

func _on_campaign_start(entry: ScreenEntry) -> void:
	campaign._on_campaign_start(entry)

func _present_node() -> void:
	campaign._present_node()

func _battle_def(selection: Dictionary) -> Dictionary:
	return campaign._battle_def(selection)

func _show_settle_deferred() -> void:
	campaign._show_settle_deferred()

func _bind_settle() -> void:
	campaign._bind_settle()

func _story_show(vm: Dictionary) -> void:
	campaign._story_show(vm)

func _story_mode() -> StringName:
	return campaign._story_mode()

func _on_story_edge(idx: int) -> void:
	campaign._on_story_edge(idx)

func _on_hub_action(action: String, arg: String) -> void:
	campaign._on_hub_action(action, arg)

func _loadout_candidates() -> Dictionary:
	return campaign._loadout_candidates()

func _on_save_quit() -> void:
	campaign._on_save_quit()

# ---------------------------------------------------------------- 子游戏流程（委托 SubgameFlow，代码评审 M2）

func _on_subgame_start(pack_id: String, mode: StringName) -> void:
	sub_flow._on_subgame_start(pack_id, mode)

func _on_sub_story_edge(idx: int) -> void:
	sub_flow._on_sub_story_edge(idx)

func _sub_bind_settle() -> void:
	sub_flow._sub_bind_settle()

func _bindings() -> Dictionary:
	var packs := {_campaign_id:
		int((pack.get("manifest", {}) as Dictionary).get("pack_version", 1))}
	for pid: String in _subgames: # 子游戏包版本随快照绑定（07 §4.1 三方版本解耦，tech/02 §11）
		packs[pid] = int(((_subgames[pid] as Dictionary).get("manifest", {}) as Dictionary).get("pack_version", 1))
	for pid: String in _arcs: # 支线包版本同口径绑定（tech/02 §2.6/§11）
		packs[pid] = int(((_arcs[pid] as Dictionary).get("manifest", {}) as Dictionary).get("pack_version", 1))
	return {"packs": packs,
		"rule_pack": (pack.get("manifest", {}) as Dictionary).get("rule_pack", {}),
		"framework": "1.0.0"}

func _meta() -> Dictionary:
	return {"playthrough": int(board.read(_playthrough_key(), 0)) + 1,
		"ngplus": int(board.read(_playthrough_key(), 0)), # 周目数随快照落档（07 §4.1 meta）
		"created_at": Time.get_datetime_string_from_system(false, true),
		"progress": "当前节点 %s · 已访 %d 节点 · 胜场 %d" % [graph.current_id,
			graph.visit_log.size(), campaign._battles_won],
		"graph": graph.serialize(),
		"node_id": graph.current_id}

## 写档（遭遇外时机专用：结算完成 / 主屏手动 / 主屏闲置 / ☰ 回主屏恢复后）。
func _save(reason: String) -> void:
	if campaign._in_encounter:
		push_error("[main] 遭遇进行中不存档（07 §4.2）——调用方时机错误")
		return
	var snap := SaveSystem.make_snapshot(board, stream, rng, _bindings(), _meta())
	if SaveSystem.write(snap):
		stream.emit(EventTypes.LOG, {"msg_key": "MSG_SAVED", "args": {"reason": reason}}, &"core")

func _save_home() -> void:
	_save("home_manual")

func _save_idle() -> void:
	_save("home_idle")

## 有进行中的战役可"继续"：以故事图真实进度为准（启动读回后同样成立），不以存档文件存在与否判断。
func _has_continuable() -> bool:
	return not graph.visit_log.is_empty() and not graph.is_at_ending()

func _collect_pct() -> float:
	var total := maxi((pack.get("nodes", {}) as Dictionary).size(), 1)
	return float(graph.visit_log.size()) / float(total) * 100.0

func _item_name(item_id: String) -> String:
	return str((pack.get("items", {}) as Dictionary).get(item_id, {}).get("name", item_id))

# ---------------------------------------------------------------- 中文字体（04 §7：内置 Noto Sans SC + 默认主题，系统字体仅开发兜底）

func _setup_cjk_font() -> void:
	if UITheme.apply(get_window()):
		print("[main] 内置中文字体已设为默认主题：", UITheme.FONT_REGULAR)
	elif UITheme.regular != null:
		push_warning("[main] 内置中文字体缺失，回退系统字体（仅开发兜底，不入发布形态）")
	else:
		push_warning("[main] 未找到任何中文字体，界面文字可能无法渲染")
