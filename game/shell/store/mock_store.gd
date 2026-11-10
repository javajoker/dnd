# 模拟商店（开发 / 测试）：同步回报结果，next_result 可注入取消 / 失败；只在调试或编辑器构建可用，
# 发布版移动端永远拿不到它（Store.create 回退为不可用商店），避免免费放行付费内容。
class_name MockStore
extends Store

## 下一次购买的结果："ok" / "cancel" / "fail"（测试注入；用后复位为 ok）。
static var next_result := "ok"

var _owned := {} # product_id -> receipt_id（本进程内的"账号已购"）
var _n := 0

static func allowed() -> bool:
	return OS.is_debug_build() or OS.has_feature("editor")

func is_available() -> bool:
	return true

func store_name() -> String:
	return "mock"

func purchase(product_id: String) -> void:
	var result := next_result
	next_result = "ok"
	if result == "cancel":
		purchase_finished.emit(product_id, false, "", "cancel")
		return
	if result == "fail":
		purchase_finished.emit(product_id, false, "", "mock_failure")
		return
	_n += 1
	var receipt := "mock_%s_%d" % [product_id, _n]
	_owned[product_id] = receipt
	purchase_finished.emit(product_id, true, receipt, "")

func restore() -> void:
	restore_finished.emit(_owned.keys())

## 测试：模拟平台撤销（退款）。
func simulate_revoke(product_id: String) -> void:
	_owned.erase(product_id)
	revoked.emit(product_id)

## 测试：模拟"另一台设备上买过"（恢复购买场景）。
func grant_owned(product_id: String) -> void:
	_owned[product_id] = "mock_restore_%s" % product_id
