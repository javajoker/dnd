# 权利模型运行时（docs/framework/06-商业化框架.md §2 权利模型 / §3.2 策略切分 / §5 退款）
# - 权利 = 状态板全局变量 global.entitlement.*（06 §2.1）；内容包只声明门槛（manifest
#   entitlement.requires，tech/02 §2.2），点亮方式归运营（商店/活动/成就三类写入方，06 §3.2）；
# - 写权限由 Board 强制执行：global.entitlement.* 仅 system 可写（07 §3），本类是唯一写入通道，
#   每次写入携带溯源（购买单号/活动 ID/成就 ID，06 §2.3），变更经 entitlement.change 进事件流（07 §6）；
# - 退款（06 §5）：权利置假；进行中战役允许跑完（运行中的流程核不回读权利），不可开新局
#   （入口 can_access 把关，与规则包冻结同一哲学）；
# - 付费禁区（06 §4）：本类只回答"能否进入"，绝不进入骰子/数值路径（core/encounter 零引用）。
class_name Entitlements
extends RefCounted

## 运营配置路径（06 §3.2：点亮在运营——定价/活动/成就规则是运营侧数据，不进内容包管线）。
const OPS_CONFIG_PATH := "res://packs/_ops/ops_config.json"

var board: Board
var stream: EventStream

func _init(p_board: Board, p_stream: EventStream) -> void:
	board = p_board
	stream = p_stream

# ---------------------------------------------------------------- 检查（tech/02 §2.2）

## manifest 声明的权利门槛（全真才解锁；缺省 = 随本体权利 = 可进入）。
static func requires_of(pack_manifest: Dictionary) -> Array:
	return (pack_manifest.get("entitlement", {}) as Dictionary).get("requires", [])

## 权利变量键：manifest 写 "entitlement.<x>"，状态板键 = "global.entitlement.<x>"（06 §2.3）。
static func board_key(require_var: String) -> String:
	return "global." + require_var

func can_access(pack_manifest: Dictionary) -> bool:
	return missing(pack_manifest).is_empty()

## 未点亮的权利变量清单（锁定态呈现与缺口的判定依据）。
func missing(pack_manifest: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in requires_of(pack_manifest):
		if not bool(board.read(board_key(str(r)))):
			out.append(str(r))
	return out

# ---------------------------------------------------------------- 幕级门槛（tech/02 §2.2 幕级；06 §7 英文市场：免费试玩 + 一次性解锁）

## 某幕声明的权利门槛（nodes.json acts[].entitlement.requires；缺省 = 无门槛）。
static func act_requires(pack: Dictionary, act_id: String) -> Array:
	for a: Variant in pack.get("acts", []):
		if str((a as Dictionary).get("id", "")) == act_id:
			return ((a as Dictionary).get("entitlement", {}) as Dictionary).get("requires", [])
	return []

## 本局是否已凭权利进入过带门槛的幕（退款后仍可跑完当前一局，06 §5）。键属包命名空间簿记。
static func run_unlock_key(pack: Dictionary) -> String:
	return "%s.run_unlocked" % str(pack.get("pack_id", ""))

## 未点亮的幕级门槛（锁定态呈现依据）；本局已解锁过则视为无缺口。
func missing_for_act(pack: Dictionary, act_id: String) -> Array:
	var req := act_requires(pack, act_id)
	if req.is_empty() or bool(board.read(run_unlock_key(pack))):
		return []
	return req.filter(func(r: Variant) -> bool: return not bool(board.read(board_key(str(r)))))

## 进入幕前检查：可进入时若该幕有门槛，记下"本局已解锁"（退款不回收进行中的一局）。
func enter_act(pack: Dictionary, act_id: String) -> bool:
	if not missing_for_act(pack, act_id).is_empty():
		return false
	if not act_requires(pack, act_id).is_empty() and not bool(board.read(run_unlock_key(pack))):
		board.write(run_unlock_key(pack), true,
			{"event_id": stream.tail(), "node_id": "", "pack_id": str(pack.get("pack_id", ""))})
	return true

## 发行市场随本体点亮的权利（运营配置 market_grants.<market>；06 §7 国内本体免费 / 海外试玩 + 解锁）。
func apply_market_grants(ops_config: Dictionary, market: String) -> Array:
	var applied: Array = []
	for key: Variant in ((ops_config.get("market_grants", {}) as Dictionary).get(market, []) as Array):
		if not bool(board.read("global.entitlement." + str(key))):
			if _write(str(key), true, {"granted_by": "market", "market": market}):
				applied.append(str(key))
	return applied

## 恢复购买点亮（商店回报已拥有的非消耗型商品；App Store 审核要求）。
func restore_grant(key: String, receipt_id: String) -> bool:
	if bool(board.read("global.entitlement." + key)):
		return false
	return _write(key, true, {"granted_by": "restore", "receipt_id": receipt_id})

## 商店商品 → 权利键（运营配置 shop.<key>.product_id 反查）。
static func key_for_product(ops_config: Dictionary, product_id: String) -> String:
	var shop: Dictionary = ops_config.get("shop", {})
	for k: Variant in shop.keys():
		if str((shop[k] as Dictionary).get("product_id", "")) == product_id:
			return str(k)
	return ""

# ---------------------------------------------------------------- 三类写入方（06 §2.3：写权限仅商店/活动/成就）

## 商店购买点亮：receipt_id = 购买单号（mock；真实支付接入是运营立项留白，06 §7）。
func shop_purchase(pack_id: String, receipt_id: String) -> bool:
	return _write(pack_id, true, {"granted_by": "shop", "receipt_id": receipt_id})

## 活动赠送点亮：activity_id 溯源；ttl_hours > 0 时记录限免时长（mock：到期回收归运营侧
## 定时任务，本切片只落溯源不实现计时器——06 §3.2 点亮方式对内容包透明）。
func activity_grant(pack_id: String, activity_id: String, ttl_hours: int = 0) -> bool:
	var extra := {"granted_by": "activity", "activity_id": activity_id}
	if ttl_hours > 0:
		extra["ttl_hours"] = ttl_hours
	return _write(pack_id, true, extra)

## 成就奖励点亮：achievement_id 溯源（06 §2.1：点亮手段多样，付费只是其中之一）。
func achievement_grant(pack_id: String, achievement_id: String) -> bool:
	return _write(pack_id, true, {"granted_by": "achievement", "achievement_id": achievement_id})

## 退款（06 §5）：权利变量置假。进行中战役不回读权利、允许跑完；新局由入口 can_access 拒绝。
func refund(pack_id: String) -> bool:
	return _write(pack_id, false, {"granted_by": "refund"})

# ---------------------------------------------------------------- 成就规则（点亮在运营：规则表在运营配置，06 §3.2）

## 评估运营配置中的成就点亮规则：flag 为真且权利未点亮 → achievement_grant。
## 返回本次新点亮的 pack_id 列表（幂等：已点亮不重复发）。
func check_achievements(ops_config: Dictionary) -> Array:
	var granted: Array = []
	for rule: Variant in ops_config.get("achievements", []):
		var r: Dictionary = rule
		var flag := str(r.get("flag", ""))
		var pack_id := str(r.get("pack_id", ""))
		if flag.is_empty() or pack_id.is_empty():
			continue
		if bool(board.read(flag)) and not bool(board.read("global.entitlement." + pack_id)):
			if achievement_grant(pack_id, str(r.get("id", ""))):
				granted.append(pack_id)
				stream.emit(EventTypes.LOG,
					{"msg_key": "MSG_ACHIEVEMENT", "args": {"label": str(r.get("label", r.get("id", "")))}, "toast": true},
					&"core")
	return granted

# ---------------------------------------------------------------- 运营配置（06 §3.2 运营侧数据）

## 加载运营配置（商店价格表 / 活动开关 / 成就点亮规则）；缺失或解析失败 = 空配置（容错不阻断）。
static func load_ops_config(path: String = OPS_CONFIG_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[entitlements] 运营配置缺失：%s（按空配置容错）" % path)
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if raw == null or not raw is Dictionary:
		push_error("[entitlements] 运营配置 JSON 解析失败：%s" % path)
		return {}
	return PackLoader.localize_ops(raw, "ops") # 投放文案按当前语言（_ops/texts/<locale>.json）

## 应用活动开关：enabled=true 的活动点亮对应权利（运营轨不动内容包的证明：只写 Board）。
## 返回本次点亮的活动 id 列表。
func apply_activities(ops_config: Dictionary) -> Array:
	var applied: Array = []
	for act: Variant in ops_config.get("activities", []):
		var a: Dictionary = act
		if not bool(a.get("enabled", false)):
			continue
		var pack_id := str(a.get("pack_id", ""))
		if pack_id.is_empty():
			continue
		if activity_grant(pack_id, str(a.get("id", "")), int(a.get("ttl_hours", 0))):
			applied.append(str(a.get("id", "")))
	return applied

## 商店价格表条目（战役入口锁定态「获取」按钮与购买弹层呈现依据，06 §3.1/§6）。
static func price_of(ops_config: Dictionary, pack_id: String) -> Dictionary:
	return (ops_config.get("shop", {}) as Dictionary).get(pack_id, {})

# ---------------------------------------------------------------- 内部

## 唯一写入落点：Board system 写权限（07 §3）+ 溯源合并（购买单号/活动 ID/成就 ID，06 §2.3）。
func _write(pack_id: String, value: bool, extra_prov: Dictionary) -> bool:
	var prov := {"event_id": stream.tail(), "node_id": "", "pack_id": "system"}
	prov.merge(extra_prov)
	return board.write("global.entitlement." + pack_id, value, prov)
