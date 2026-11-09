# 事件流（docs/tech/01-技术方案讨论稿.md §5；docs/framework/07-世界状态机规范.md §6）
# 追加式、不可变：事件一旦写入不得修改；渲染、历史卷轴、回放消费同一条流。
# 事件结构（tech/01 §5.1 + godot-dev §4）：{id, session, type, payload, source, node}
class_name EventStream
extends RefCounted

var _events: Array[Dictionary] = []
var _subscribers: Array[Callable] = []
var _next_id: int = 1

## 追加一条事件并同步通知订阅者。返回写入的事件（含递增 id）。
func emit(type: StringName, payload: Dictionary = {}, source: StringName = &"core", node: String = "", session: String = "") -> Dictionary:
	var ev := {
		"id": _next_id,
		"session": session,
		"type": type,
		"payload": payload.duplicate(true),
		"source": source,
		"node": node,
	}
	_next_id += 1
	_events.append(ev)
	for fn: Callable in _subscribers:
		fn.call(ev)
	return ev

## 订阅事件流（渲染壳唯一消费通道，tech/01 §5.2 进程内发布订阅）。
func subscribe(fn: Callable) -> void:
	if not _subscribers.has(fn):
		_subscribers.append(fn)

func unsubscribe(fn: Callable) -> void:
	_subscribers.erase(fn)

## 按类型查询（历史卷轴 / 调试视图）。
func query_by_type(type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Dictionary in _events:
		if ev["type"] == type:
			out.append(ev)
	return out

## 事件流尾部序号：存档锚点（07 §4.1 event_tail）。
func tail() -> int:
	return _next_id - 1

func size() -> int:
	return _events.size()

## 取 id 大于 event_id 的事件段（自存档锚点回放/追溯用）。
func since(event_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Dictionary in _events:
		if int(ev["id"]) > event_id:
			out.append(ev)
	return out

func all() -> Array[Dictionary]:
	return _events.duplicate()

## 存档用全量序列化（tech/01 E-3 裁决：事件流全量随存档，历史卷轴跨启动可追溯）。
## 事件 payload 只含 msg_key/数据，不含按语言渲染的文案，读回后按当前语言呈现。
func serialize() -> Dictionary:
	return {"events": _events.duplicate(true), "next_id": _next_id}

## 读回历史（不通知订阅者：历史不是"新发生"的事件）。缺省/旧档 = 保持空流。
func restore(state: Dictionary) -> void:
	var evs: Array = state.get("events", [])
	if evs.is_empty():
		return
	_events.clear()
	for ev: Variant in evs:
		var d: Dictionary = ev
		d["type"] = StringName(str(d.get("type", "")))
		d["source"] = StringName(str(d.get("source", "")))
		d["id"] = int(d.get("id", 0))
		_events.append(d)
	_next_id = maxi(int(state.get("next_id", 1)), int(_events.back()["id"]) + 1)
