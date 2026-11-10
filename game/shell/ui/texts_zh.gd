# zh-CN 语言表（源语言）：常量名即文本键，经 Texts.t(&"键") 按当前语言取值（tech/01 E-5 双语构建）。
# 新增文案先加到本表，再补其它语言表（texts_en.gd）；缺键时 Texts 回退到本表。
# 消息模板（MSG_*）用 {name} 具名占位，由 Texts.msg() 以事件 args 填充。
class_name TextsZh
extends RefCounted

# 操作台四 Tab（04 §④.5）
const TAB_ACTION := "行动"
const TAB_DICE := "骰子"
const TAB_LOG := "日志"
const TAB_CHAR := "角色"

# 快捷栏芯片（09 §9.2）
const CHIP_ATTACK := "攻击"
const CHIP_FIRST_AID := "急救"
const CHIP_END_TURN := "结束回合"
const CHIP_ITEM_FMT := "%s ×%d"
const CHIP_MOVE := "移动" # 移动段（11 §4；12 §2.1 拖动移动的按钮等价路径）

## 指令集条目 → 芯片/轮盘按钮文案（两壳同源排版；次数余量实时呈现，09 §9.2）。
static func action_label(a: Dictionary) -> String:
	match StringName(str(a.get("type", ""))):
		EncounterSM.CMD_ATTACK:
			return CHIP_ATTACK
		EncounterSM.CMD_MOVE:
			return CHIP_MOVE
		EncounterSM.CMD_SKILL:
			var label := str(a.get("name", a.get("skill", "")))
			if int(a.get("uses", -1)) >= 0:
				label += " ×%d" % int(a["uses"])
			return label
		EncounterSM.CMD_ITEM:
			return CHIP_ITEM_FMT % [str(a.get("name", a.get("item", ""))), int(a.get("count", 0))]
		EncounterSM.CMD_FIRST_AID:
			return CHIP_FIRST_AID
		EncounterSM.CMD_END_TURN:
			return CHIP_END_TURN
	return str(a.get("name", "?"))

# 托管（09 §9.3）
const AUTO_ON := "托管"
const AUTO_OFF := "接管"

# ☰ 单局菜单（09 §7）
const MENU := "☰"
const MENU_CONTINUE := "继续"
const MENU_SAVE_QUIT := "保存并回主屏"
const MENU_HELP := "手势帮助"
const MENU_CONFIRM_QUIT := "确认退出？本局进度将丢失（遭遇进行中不存档）"
const MENU_SHAKE_ON := "屏幕震动：开"   # 14 清单 #4：震动可关（UI 偏好，不写状态板，12 §5 同机制）
const MENU_SHAKE_OFF := "屏幕震动：关"
const MENU_VOL_MASTER := "音量 · 主"      # 14 清单 #5：音量三档滑条（UI 偏好，12 §5 同机制）
const MENU_VOL_BGM := "音量 · 音乐"
const MENU_VOL_SFX := "音量 · 音效"

# 打击感飘字（14 清单 #3）
const JUICE_CRIT := "暴击"
const JUICE_MISS := "闪过"

# 掷骰演出（09 §6；04 §④.7：一切演出可跳过，统一长按 ≥400ms 防误触）
const KEY_ROLL_HINT := "长按任意处跳过演出"
const RESULT_SUCCESS := "成功"
const RESULT_FAIL := "失败"
const RESULT_CRIT := "大成功！"
const RESULT_FUMBLE := "大失败…"

# 横屏五区（04 §③、09 §4）
const ZONE_WHEEL := "行动轮盘"
const ZONE_DICE := "骰子盘"
const LOG_EXPAND := "日志 ▴"
const LOG_COLLAPSE := "收起 ▾"

# 结算（04 §⑨）
const SETTLE_TITLE := "遭遇结算"
const SETTLE_VICTORY := "胜利"
const SETTLE_DEFEAT := "失败"
const SETTLE_RETREAT := "撤退"
const SETTLE_QUIT := "退出"
const SETTLE_HOME := "回主屏"
const SETTLE_HISTORY := "查看卷轴"
const SETTLE_NEXT := "下一遭遇" # 04 §⑨/§④.8：胜利结算三出口之一（沿故事图边推进）
const SETTLE_SAVED := "抄本已记录。" # 07 §4.2 结算快照（溯源在代码注释，条款号不上屏，M2 审计 G7）
const SETTLE_ATTR_TITLE := "成长加点（属性点可留到下次整备）"
const SETTLE_ATTR_KEEP := "留到下次整备"

# 通用
const COMMON_BACK := "返回"
const COMMON_WIP := "（最小版：要素随内容接入补全）"

# 节点流程（04 §3.1/§④.2/§④.3、09 §6、tech/02 §3/§5、战役书 §4 N1-1）
const STORY_CONTINUE := "继续"
const STORY_CHECK := "检定"
const MAZE_TITLE := "%s · 探索 %d/%d"          # 迷宫探索序列标题（tech/02 §6 maze；04 §④.3 房间序列）
const MAZE_AMBUSH_PREFIX := "伏击判定｜"        # 伏击拍按钮前缀（tech/02 §6 maze.beats）
const MAZE_LOOT := "拾取：%s ×%d"              # 拾取拍按钮（04 §④.3 拾取房）
const MAZE_BEAT_OK := "检定成功。"
const MAZE_BEAT_FAIL := "检定失败……"
const SKILL_NAMES := {
	"athletics": "运动", "intimidate": "威吓", "stealth": "潜行", "thievery": "巧手",
	"perception": "感知", "investigation": "调查", "history": "历史",
	"persuasion": "交涉", "soothe": "安抚",
	# a_or_b 复合键（11 §2 取高）：显示层映射（M2 审计 G6：复合键不得原样上屏）
	"history_or_perception": "历史/感知",
}
const DIFF_NAMES := {"easy": "易", "medium": "中", "hard": "难"}
const FACTION_NAMES := {"scriptorium": "誊写庭", "uninked": "断墨会", "salvage": "拾遗行会"}
const STORY_CLOCK := "时钟 %d 格"
const STORY_CLOCK_NEXT := "▸ %s %d格"
const STORY_FORECAST_TITLE := "时间边预告" # 04 §3.1（条款号不上屏，M2 审计 G7）
const STORY_FORECAST_EMPTY := "暂无逼近的时间边。"
const STORY_QUEST_BADGE := "事件 %d"
const STORY_SLICE_END := "幕一 · 切片终点"
const SETTLE_SLICE := "切片完成"
# 模式锁定（09 §3：强制是叙事手段；tech/02 §2.1 forced / forced_except）
const STORY_MODE_UNLOCK := "回放到此为止——往后的路，可以用全局的视野走了。"
# 结局屏（tech/02 §9；战役书 §9：结局演出 + 尾声结算合并于 ending 节点）
const ENDING_TITLE := "【结局】%s"
const ENDING_HOOK := "多周目钩子：%s"
const ENDING_NGPLUS := "开始二周目"
const ENDING_HOME := "回主屏"
const ENDING_SAVED := "抄本已记录。" # 07 §4.2 结局快照（同上）
const ENDING_PLAYTHROUGH := "—— 第 %d 周目 完 ——"
const NGPLUS_TOAST := "你带着抄本残页回到潮醒之前。织命者残简 ×1 随行，图鉴与权利如故。"
# Hub（战役书 §4 N1-1：休整 / 商店 / 传闻；04 §3.3 半屏弹层）
const HUB_SHOP := "商店"
const HUB_REST := "休整"
const HUB_RUMOR := "听传闻"
const HUB_GOLD := "金币：%d"
const HUB_CLOSE := "离开"
const HUB_NO_GOLD := "金币不足。"
const HUB_REST_HINT := "休整：恢复全部 HP 与技能次数"
const HUB_RUMOR_NONE := "码头寂静，暂无新传闻。"

# ① 主屏（04 §①）
const HOME_TITLE := "烬港 · 营地"
const HOME_ENTRY_CAMPAIGN := "战役入口"
const HOME_CONTINUE := "继续"
const HOME_ENTRY_QUESTS := "事件中心"
const HOME_ENTRY_INVENTORY := "背包图鉴"
const HOME_ENTRY_CHARACTER := "角色"
const HOME_ENTRY_HISTORY := "历史卷轴"
const HOME_HELP := "帮助"
const HOME_SAVE := "记录抄本"
const HOME_SAVED := "抄本已记录"
# 兜底条 toggle（12 §5：可收起/展开，默认展开，偏好持久化到本地设置；把手始终可触达）
const HOME_BAR_HINT := "文字入口条"
const HOME_BAR_COLLAPSE := "▾ 收起入口条"
const HOME_BAR_EXPAND := "▴ 展开入口条"
## 营地图景随褪墨度（global.doom_clock 0~10）变化（04 §①：状态板的可视化）。
static func home_doom_text(clock: int) -> String:
	if clock <= 3:
		return HOME_DOOM_LOW
	if clock <= 6:
		return HOME_DOOM_MID
	return HOME_DOOM_HIGH
const HOME_DOOM_LOW := "营火尚旺。墨迹在天边，像一场还没下定的雨。"
const HOME_DOOM_MID := "街名又淡了一分。营地的人开始把重要的事写在手上。"
const HOME_DOOM_HIGH := "褪墨逼近。抄本的纸页发凉——能留下的，只有你写下的部分。"

# ② 战役入口（04 §②、09 §3）
const ENTRY_TITLE := "战役入口"
const ENTRY_START := "开始战役"
const ENTRY_MODE_SPACE := "横屏空间战役"
const ENTRY_MODE_SPACE_DESC := "战术格 · 站位 · 大战场——以全局视野摊开每一幕"
const ENTRY_MODE_TIME := "竖屏时间战役"
const ENTRY_MODE_TIME_DESC := "多房间 · 叙事流 · 单手节奏——一段记忆按自己的节奏展开"
const ENTRY_MODE_PICK := "选择这一程的讲述方式（整场战役锁定）" # 09 §3（同上）
const ENTRY_MODE_CHOSEN := "已选："
const ENTRY_COLLECT := "分支收集度"
const ENTRY_PLAYED := "已玩模式："
# ② 子游戏卡（04 §6：入口挂战役入口区作特殊战役书卡；pack_type=subgame 数据驱动入列）
const ENTRY_SUBGAME_SECTION := "—— 特殊战役书卡 · 子游戏 ——"
const ENTRY_SUBGAME_TAG := "〔子游戏 · 连战〕"
const SUBGAME_ENTER_TIME := "竖屏参战"
const SUBGAME_ENTER_SPACE := "横屏参战"
const SUBGAME_STATS := "累计胜场 %d · 最佳连战 %d"
const SUBGAME_LEVEL := "建议等级 Lv.%d+"

# ② 锁定态与购买（06 §3.1：可见但锁定、叙事化包装、无"未购买"生硬弹窗；06 §6 + 04 §3.3：半屏弹层购买）
const LOCK_DEFAULT := "守门人只认印记——你的抄本里还没有这一页。"
const LOCK_ACQUIRE := "获取"
const SHOP_TITLE := "守门人的印龛"
const SHOP_CONFIRM := "确认获取"
const SHOP_CANCEL := "再想想"
## 购买弹层文案（叙事化包装：商品名 + 价格 + 一句叙事；购买即解锁无需重启，06 §3.1）。
static func shop_line(pack_name: String, price_text: String) -> String:
	return SHOP_LINE % [pack_name, price_text]
const SHOP_LINE := "《%s》——%s。守门人收下印记，擂台的门就会为你翻开。"

# 整备（09 §9.1）
const LOADOUT_TITLE := "整备"
const LOADOUT_SKILLS := "技能备选（%d 选 %d）"
const LOADOUT_ITEMS := "道具携带（槽位 %d）"
const LOADOUT_ATTRS := "未分配属性点：%d"
const LOADOUT_CONFIRM := "确认出发"
const LOADOUT_FULL := "（槽位已满）"
# 横屏专版（04 §④.8：三段横列 + 队伍状态条置顶 + 预设卡）
const LOADOUT_PRESET_TITLE := "预设"
const LOADOUT_PRESET_EMPTY := "（尚未选择，点选预设或逐项挑选）"
const LOADOUT_PRESET_MISSING := "预设未备齐（已跳过）：%s" # 09 §9.3：未习得/未持有跳过并提示
const LOADOUT_PARTY_ITEM := "%s HP %d/%d"

# ⑧ 历史卷轴（04 §⑧）
const HISTORY_TITLE := "历史卷轴"
const HISTORY_KEY_MARK := "★ 关键判定"
const HISTORY_EMPTY := "（尚无条目）"
const HISTORY_PROV := "来源：%s · %s"

# ⑤ 事件中心（04 §⑤）
const QUESTS_TITLE := "事件中心"
const QUESTS_ACTIVE := "进行中"
const QUESTS_DONE := "已完结（归档历史卷轴）"
const QUESTS_ABANDONED := "已放弃（归档历史卷轴）"
const QUESTS_ABANDON := "放弃"
const QUESTS_EMPTY := "（暂无进行中的事件）"

# ⑥ 背包与图鉴（04 §⑥：四重身份筛选 / 图鉴系列进度与集齐奖励预告）
const INV_TITLE := "背包与图鉴"
const INV_BAG := "背包"
const INV_CODEX := "图鉴"
const INV_FILTER_ALL := "全部"
const INV_ROLE_NAMES := { # 四重身份（tech/02 §7 roles；10 §1 标签体系）
	"stat": "数值装备", "check_mod": "检定工具", "branch_key": "分支钥匙", "codex": "图鉴信物",
}
const INV_BRANCH_HINT := "它似乎能在某处派上用场……" # 分支钥匙提示（04 §⑥ 示例句式）
const CODEX_SERIES := { # 系列归世界观层定义（story/01 §9 四大系列；10 §3；id 以 tech/02 §10 注册值为准）
	"weaver_fragments": "织命者残简", "revoked_registry": "被撤销者名录",
	"fatedie_study": "命骰考", "ashenport_local": "烬港风物志",
}
const CODEX_REWARDS := { # 集齐奖励预告（世界观 §9 方向；10 §4 白名单，永不卖数值）
	"weaver_fragments": "集齐 → 揭示褪墨真相的隐藏剧情线",
	"revoked_registry": "集齐 → 解锁「追忆」战役（强制竖屏形态）",
	"fatedie_study": "集齐 → 骰子皮肤「褪墨灰」（纯演出）",
	"ashenport_local": "集齐 → 烬港声望与商店折扣",
}
const CODEX_PROGRESS := "%s：%d/%d"
const CODEX_REWARD_LINE := "　预告：%s"
const CODEX_LOCKED_TITLE := "？？？"

# ⑥ 外观页（06 §3/§6/§7：外观页挂背包图鉴；皮肤只写外观旗标，纯演出不卖数值）
const INV_COSMETIC := "外观"
const COSMETIC_EQUIP := "装备"
const COSMETIC_EQUIPPED := "已装备"
const COSMETIC_UNEQUIP := "卸下"
const COSMETIC_NOT_OWNED := "未获得"
const COSMETIC_PURE_NOTE := "皮肤只换骰面配色，不动骰运（纯演出）"
## 皮肤获得途径说明（注册表 grant 声明 → 叙事化一行）。
static func cosmetic_source_line(def: Dictionary) -> String:
	var g: Dictionary = def.get("grant", {})
	match str(g.get("kind", "")):
		"default":
			return COSMETIC_SRC_DEFAULT
		"codex_series":
			return COSMETIC_SRC_CODEX
		"shop":
			return COSMETIC_SRC_SHOP % str((def.get("shop", {}) as Dictionary).get("price_text", ""))
		"ngplus_ending":
			return COSMETIC_SRC_NGPLUS % str(g.get("ending", ""))
	return ""
const COSMETIC_SRC_DEFAULT := "起手即有"
const COSMETIC_SRC_CODEX := "图鉴「命骰考」集齐奖励"
const COSMETIC_SRC_SHOP := "守门人的印龛 · %s"
const COSMETIC_SRC_NGPLUS := "多周目继承 · 结局 %s 专属"
## 皮肤购买弹层文案（与战役购买同一叙事化手法，06 §3.1；shop_line 是战役句式，皮肤另起一句）。
static func cosmetic_shop_line(skin_name: String, price_text: String) -> String:
	return COSMETIC_SHOP_LINE % [skin_name, price_text]
const COSMETIC_SHOP_LINE := "「%s」——%s。守门人拓下一枚新印，骰面从此换一种光。"

# ⑧ 战报回放（04 §⑧：事件流重演，纯演出不可改结果；最小版 = 节拍日志重演）
const HISTORY_REPLAY := "重演"
const REPLAY_TITLE := "战报重演（纯演出 · 不可改结果）"
const REPLAY_SKIP := "跳过"
const REPLAY_DONE := "—— 重演终 ——"

# 房间回看（04 §④.2：下滑/点按推进条展开已过房间；只读，已完成检定与战斗不重置）
const ROOM_REVIEW_TITLE := "已过房间"
const ROOM_REVIEW_HINT := "（只读回看：已完成的检定与战斗不会重置）"

# 手势反馈（12 §3：抬手落空 = 取消，不产生半状态指令）
const GESTURE_CANCEL := "落空，已取消"
const GESTURE_PATH_AIM := "轨迹：%s → %s"

# ⑦ 角色（04 §⑦）
const CHAR_TITLE := "角色"
const CHAR_BOND := "羁绊"
# 成长区（tech/04 §8）：等级 / XP 进度 / 已分配属性 / 未分配点数
const CHAR_GROWTH := "成长：Lv.%d　经验 %d/%s"
const CHAR_GROWTH_MAX := "成长：Lv.%d　经验 %d（已满级）"
const CHAR_GROWTH_ATTRS := "已分配：力 %+d 敏 %+d 智 %+d　未分配点数：%d"

# 帮助页 · 手势图鉴（12 §4：常驻，主动进入；12 §1/§2 全表）
# 手势层已落地（gesture_recognizer.gd / gesture_layer.gd）：按 12 §1 判定参数全量上屏；
# 铁律同步上屏：一切手势均有按钮等价路径（12 §1）。
const HELP_TITLE := "手势图鉴"
const HELP_RETRAIN := "重学教程"
const HELP_LINES: Array[String] = [
	"点按 = 选择 / 确认（选项、按钮、目标格、目标单位）",
	"点按芯片 / 轮盘 = 对默认目标使用",
	"长按（≥0.4 秒）= 单位 / 道具详情卡；关键判定演出长按跳过",
	"拖动己方单位 = 移动（消耗移动段，拖动中显示落点预览）",
	"拖动轨迹（己方 → 敌方）= 指向性技能：轨迹即弹道预览，松手确认，落空取消",
	"双指点击（战场 / 主视野）= 结束回合 / 普通检定一键快掷",
	"横滑（操作台）= 四 Tab 切换（行动 / 骰子 / 日志 / 角色）",
	"双指捏合 = 战场缩放（全局俯瞰 ↔ 跟随镜头；竖屏松手弹回）",
	"下滑 / 点按（推进条）= 已过房间回看（只读，已完成检定与战斗不重置）",
	"（一切手势均有按钮等价路径——手势是效率层，不是唯一通道）",
]

# 教程三层（12 §4：可跳过、可重学、跳过不丢信息；触发记录写 global.tutorial.*）
const TUT_NEXT := "下一页"
const TUT_SKIP := "跳过"
const TUT_DISMISS := "点任意处继续"
const TUT_CARDS: Array[String] = [
	"【点按】= 选择\n选项、按钮、目标——轻点即定。",
	"【长按】= 详情\n按住单位或道具片刻，展开它的信息卡。",
	"【横滑】= 切换\n在底部操作台左右滑动，切换行动 / 骰子 / 日志 / 角色。",
]
const TUT_HINT_COMBAT := "拖动己方单位 = 移动；拖到敌方 = 轨迹施法；双指点击 = 结束回合；双指捏合 = 缩放战场。"
const TUT_HINT_CHECK := "双指点击 = 一键快掷；点按检定按钮亦可。关键判定演出可长按跳过。"
const TUT_HINT_KEY := "关键判定演出：长按 ≥0.4 秒跳过，跳过不丢信息（内容同步写入日志与卷轴）。"

# 事件流消息模板（core/应用层只发 msg_key + args，壳按当前语言渲染；tech/01 E-5）
const MSG_REST := "你在广场的篝火边休整。伤口被重新誊写，技能次数已恢复。"
const MSG_ACHIEVEMENT := "成就达成：{label}"
const MSG_SKIN_CODEX := "图鉴集齐——骰子皮肤「{skin}」已到账。（纯演出，不动骰运）"
const MSG_SKIN_SHOP := "守门人拓下新印——骰子皮肤「{skin}」已到手。（纯演出，不动骰运）"
const MSG_MAZE_START := "探索开始（{beats} 拍）"
const MSG_MAZE_AMBUSH := "伏击！（{enemy}）"
const MSG_MAZE_LOOT := "拾取：{item} ×{n}"
const MSG_MAZE_DONE := "探索完成"
const MSG_SKILL_USED := "{unit} 发动了「{skill}」"
const MSG_ENCOUNTER_END := "遭遇结束：{result}（{rounds} 回合）"
const MSG_SUB_STAGE_WIN := "第 {stage} 场告捷：金币 +{gold}（连胜无休整，下一场带伤上阵）"
const MSG_SUB_CLEAR := "通关记录 +1"
const MSG_RESUMED := "抄本翻回上次落笔的那一页。"
const MSG_REWIND_BATTLE := "你合上抄本。这一页的雨，被轻轻翻回了开头。"
const MSG_REWIND_STORY := "你合上抄本。这一程就讲到这里。"
const MSG_REWIND_SUB := "你合上抄本。擂台的墨锣声远去了。"
const MSG_PURCHASED := "守门人收下印记——《{pack}》的门开了。（购买即解锁，无需重启）"
const MSG_SAVED := "抄本已记录。"
const MSG_STORY_ECHO := "【{title}】{text}"

# 语言设置（tech/01 E-5：UI 偏好 ui.locale；切换后回到主屏重载）
const LANG_BUTTON := "语言：中文"

# 壳层格式串（原各界面内嵌文案，tech/01 E-5 统一入表）
const FMT_CHECK_LABEL := "%s：%s（%s DC %d · 修正 %+d）"
const SETTLE_LINE_ITEM := "获得：%s ×%d（已入背包）"
const SETTLE_LINE_FLAG := "旗标：%s"
const SETTLE_LINE_REP := "声望：%s %+d"
const SETTLE_LINE_LOADOUT := "整备：技能 %s / 道具 %s"
const SETTLE_LINE_XP := "经验 +%d"
const LOG_XP := "经验 +%d"
const SETTLE_LINE_LEVEL := "等级：Lv.%d"
const SETTLE_LINE_ATTR := "成长：属性点 +%d"
const SETTLE_LINE_CLOCK := "时间钟：%d 格"
const SETTLE_LINE_ITEM_SHARED := "获得：%s ×%d（已入背包，主线可用）"
const SETTLE_LINE_LORE := "图鉴新增：%s"
const SETTLE_LINE_GOLD_DELTA := "金币 %+d（累计 %d）"
const SETTLE_LINE_GOLD := "金币 +%d（累计 %d）"
const SETTLE_LINE_RECORD := "战绩：本次 %d 胜 · 累计 %d 胜 · 最佳连战 %d"
const SETTLE_LINE_FLAWLESS := "全胜谢幕：擂台为你留名"
const SETTLE_SUB_TITLE := "连战结算"
const LOG_GESTURE_HELP := "手势帮助：%s"
const UNIT_CARD_HP := "HP %d/%d　AC %d"
const UNIT_CARD_DAMAGE := "伤害骰 %s　攻击修正 %+d"
const UNIT_CARD_STATE := "状态：%s"
const UNIT_DOWNED := "倒地"
const UNIT_DEAD := "死亡"
const UNIT_OK := "正常"
const UNIT_CARD_CELL := "格位：%s"
const UNIT_CARD_INIT := "先攻位次：%d"
const ROUND_FMT := "第 %d 轮"
const TIME_EDGE_DEFAULT := "时间边"
const DOOM_PREVIEW_LINE := "%s —— 时钟 %d 格触发（%s）"
const BRACKET_FMT := "【%s】"
const DICE_DETAIL := "骰 %s 修正 %+d 合计 %d（%s）"
const KEY_DEATH_SAVE_TALLY := "\n死亡豁免 %d 胜 %d 负"
const REVIEW_EMPTY := "（尚无已过房间）"
const REVIEW_DETAIL := "【%s】\n%s"
const FLASH_COMBAT_START := "遭遇战开始！"
const FLASH_DOWNED := "%s 倒地！"
const FLASH_TARGET := "目标：%s"
const CHAR_TAB_DEAD := "（死亡）"
const CHAR_TAB_DOWNED := "（倒地 豁%d/%d）"
const CHAR_TAB_LINE := "%s  HP %d/%d  AC %d  力%+.0f 敏%+.0f 智%+.0f%s"
const LOG_AUTO_TAG := "（托管）"
const LOG_DEATH_SAVE := "%s 死亡豁免：%d → %s（%d胜%d负）"
const LOG_SAVE := "%s 豁免：%d%+d=%d vs %d → %s（伤 %d）"
const LOG_FIRST_AID := "%s 急救 %s：%d → %s"
const LOG_CHECK := "检定·%s：%d%+d=%d vs %d → %s"
const LOG_CHECK_TOTAL := "检定：%d"
const LOG_ATTACK := "%s 攻击 %s：%s"
const LOG_HIT_DAMAGE := "命中 %d 点"
const LOG_MISS := "失手"
const LOG_CRIT_TAG := "（暴击！）"
const LOG_FUMBLE_TAG := "（大失败）"
const LOG_STATE_ENTER := "—— 进入「%s」——"
const LOG_COMBAT_START := "战斗开始，先攻序：%s"
const LOG_SKILL := "%s 发动「%s」%s"
const LOG_SUMMON_TAG := "：召唤 ×%d"
const LOG_ATK_MOD_TAG := "（攻击修正 → %+d）"
const LOG_SKILL_EXTRA := "%s 发动「%s」%s%s"
const LOG_ITEM_USE := "%s 使用「%s」→ %s（回复 %d）%s"
const LOG_DOWNED := "⚠ %s 倒地！"
const LOG_DIED := "✝ %s 消散。"
const LOG_REVIVED := "%s 重新站起（1 HP，%s）。"
const LOG_CMD_REJECTED := "（命令被拒：%s）"
const LOG_COMBAT_END := "—— 战斗结束：%s ——"
const LOG_ITEM_GAIN := "获得物品：%s ×%d"
const PAREN_PAIR_FMT := "%s（%s）"
const HUB_SHOP_LINE := "%s —— %d 金币%s"
const HUB_OWNED_TAG := "（持有 ×%d）"
const PAREN_FMT := "（%s）"
const CHAR_WIP_LINE := "（法术位 / 装备槽 / 状态效果 %s）"
const CHAR_ROSTER_LINE := "%s　HP %d/%d　力%+.0f 敏%+.0f 智%+.0f\n　技能：%s"
const ENTRY_SUBGAME_NAME := "%s《%s》 %s"
const BOOK_TITLE_FMT := "《%s》"
const ENTRY_LEVEL_HOURS := "推荐等级 %s · 预计时长 %s"
const ENTRY_ACTS := "幕构成：%s"
const ENTRY_RECOMMEND_TAG := "\n〔框架推荐〕"
const HIST_HIT := "命中 %d"
const HIST_MISS := "未命中"
const HIST_CHECK_DETAIL := "检定明细：骰 %s 取 %d 修正 %+d = %d vs DC %d → %s"
const HIST_DEATH_SAVES := "死亡豁免 %d 胜 %d 负"
const HIST_ATTACK_DETAIL := "攻击明细：骰 %s 取 %d（%s）修正 %+d vs AC %d → %s"
const HIST_HIT_DETAIL := "命中，伤害 %d %s"
const HIST_FLAG_CHANGE := "旗标变化：%s　%s → %s"
const INV_ITEM_LINE := "%s ×%d　%s"
const TAG_FMT := "〔%s〕"
const INV_ROLES := "身份：%s"
const INV_USE_HEAL := "使用：恢复 %s HP（附赠动作）"
const INV_CONSUMABLE := "消耗品"
const INV_CHECK_MOD := "检定修正：携带即生效（检定工具）"
const INV_PRICE := "价格：%d 金币"
const INV_LORE_LINE := "📜 %s（%s）"
const INV_LORE_SOURCE := "来源：%s"
const COLON_PAIR_FMT := "%s：%s"
const QUEST_LINE := "◆ %s —— %s\n　%s（%s）"
const SETTLE_HEAD := "【%s】%s —— %s"
const SETTLE_ATTR_AVAIL := "%s（可用 %d）"
const EDGE_BADGES := "　〔%s〕"
const RUMOR_LINE := "传闻：有人说起「%s」——%s。"
const TOAST_FLAG := "旗标更新：%s"
const TOAST_REP := "声望：%s %+d（%d）"
const TOAST_ITEM_GAIN := "获得：%s ×%d"
const TOAST_ITEM_LOSS := "消耗：%s ×%d"
const TOAST_QUEST_TRIGGER := "事件触发：%s"
const TOAST_QUEST_SETTLE := "事件完结：%s"
const TOAST_LORE := "图鉴新增：%s"
const LIST_SEP := "、"
const STATE_NAMES := {"enter": "进场", "explore": "探索", "discover": "发现", "combat": "战斗",
	"settle": "结算", "rest": "休整", "exit": "出场"}
const ATTR_SHORT := {"might": "力", "finesse": "敏", "wits": "智"}
const NOTICE_FORCED_TIME := "这一段记忆只能以碎片的方式回放——它按自己的节奏展开。"
const NOTICE_FORCED_SPACE := "这一幕无法从内部讲述，只能以全局的视野摊开。"

# 商店与章节锁定（06 §3.1/§7；P4 阶段 4）
const LOCK_CHAPTER_TEXT := "抄本在这里合上了——后面的书页，还没有为你写开。"
const LOCK_CHAPTER_DEMO := "免费试玩到此为止：序章与幕一。一次性解锁完整战役，之后的一切选择都会接着这一页写下去。"
const LOCK_CHAPTER_GET := "解锁完整战役 · %s"
const LOCK_CHAPTER_GET_NOPRICE := "解锁完整战役"
const LOCK_BACK_HOME := "回营地"
const STORE_RESTORE := "恢复购买"
const MSG_RESTORED := "已恢复 {n} 项购买。"
const MSG_PURCHASE_FAILED := "购买未完成：{error}"
const MSG_STORE_UNAVAILABLE := "商店暂不可用。"
const SHOP_LINE_CAMPAIGN := "《%s》——%s。一次解锁，抄本会从这一页接着写下去。"
