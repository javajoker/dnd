# 商店抽象（06 §2/§7；tech/01 §10.1）：购买 / 恢复购买 / 撤销（退款）三个通道，信号回报结果。
# 应用层只认这个接口：拿到成功回报后经 Entitlements 点亮权利（Board system 写权限 + 单号溯源）。
# 实现：
# - MockStore（mock_store.gd）：开发与测试用，仅调试 / 编辑器构建可用；
# - 平台适配器（Google Play Billing / StoreKit 插件）：接入官方计费插件后按本接口实现并在 create() 登记——
#   见 docs/en/tech/06-english-mobile-plan.md §3 Phase 4。未登记时发布版返回"不可用"商店，绝不放行免费解锁。
class_name Store
extends RefCounted

## 购买结束：ok = 已付款且已确认；receipt_id = 平台单号（溯源）；error = "cancel" / "unavailable" / 平台错误。
signal purchase_finished(product_id: String, ok: bool, receipt_id: String, error: String)
## 恢复购买结束：owned = 该账号已拥有的非消耗型商品 id。
signal restore_finished(owned: Array)
## 平台通知撤销（退款 / 拒付）：应用层按 06 §5 置假权利（进行中的一局可跑完）。
signal revoked(product_id: String)

func is_available() -> bool:
	return false

func store_name() -> String:
	return "unavailable"

func purchase(product_id: String) -> void:
	purchase_finished.emit(product_id, false, "", "unavailable")

func restore() -> void:
	restore_finished.emit([])

## 选择当前平台的商店。平台适配器接入后在此按插件单例登记（Engine.has_singleton(...)）。
static func create() -> Store:
	if MockStore.allowed():
		return MockStore.new()
	return Store.new()
