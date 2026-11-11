# 角色动作动画 + 技能特效呈现层（docs/en/framework/14 #3 延伸；docs/en/tech/05 §9）
# 铁律与 JuiceLayer 同：纯呈现消费事件流（on_event），不改 core、不写 Board、不回注事件流；
# 双壳同一组件，壳只提供查询（锚点 / 单位矩形 / 美术引用 / 技能定义 / 阵营单位 / 隐藏真身）。
#
# 为什么是覆盖层：壳在每个事件后重建单位节点（容器重排），直接 tween 真身会被打断。
# 动作动画 = 在覆盖层画一个"替身"（单位美术），动画期间壳把真身美术透明（art_alpha），播完还原。
# 动作：lunge（近战扑击）/ cast（施法上浮发光）/ throw（投掷）/ hop（移动落地）/ brace（防御蓄力）/
#       down（倒地）/ revive（扶起）。
# 特效：slash / stab / claw / smash / bolt / lance / arc / burst / wave / heal / shield / smoke / summon / aura。
# 技能可在 skills.json / enemies.json 声明 "fx"（与可选 "fx_color"）；未声明按技能形态推断（resolve_fx）。
# 外部帧动画（可选，按约定覆盖程序化）：
#   res://assets/art/fx/fx_<name>.png              —— 特效横条帧（帧宽 = 图高）
#   res://assets/art/anims/anim_<art id>_<action>.png —— 单位动作横条帧（art id = art_ref 的 <id> 段）
class_name ActionFx
extends Control

const FX_KINDS: Array[String] = ["slash", "stab", "claw", "smash", "bolt", "lance", "arc", "burst", "wave",
	"heal", "shield", "smoke", "summon", "aura"]
const ACTIONS: Array[String] = ["lunge", "cast", "throw", "hop", "brace", "down", "revive"]
const MELEE := ["slash", "stab", "claw", "smash"]
const PROJECTILE := ["bolt", "lance", "arc"]
const ACTION_TIME := 0.42
const FX_TIME := {"slash": 0.32, "stab": 0.26, "claw": 0.32, "smash": 0.36, "bolt": 0.42, "lance": 0.34,
	"arc": 0.5, "burst": 0.55, "wave": 0.6, "heal": 0.7, "shield": 0.6, "smoke": 0.6, "summon": 0.7, "aura": 0.6}
const STRIP_FPS := 24.0

## 壳查询（均可空：缺省时该类演出静默跳过）。
var anchor_of: Callable = Callable()      # uid -> Vector2（全局）
var rect_of: Callable = Callable()        # uid -> Rect2（全局，单位美术区域）
var art_ref_of: Callable = Callable()     # uid -> String（art_ref，如 units/ink_fiend）
var side_of: Callable = Callable()        # uid -> StringName（&"party" / &"enemy"）
var units_of: Callable = Callable()       # side -> Array[String]（存活单位 id）
var skill_def_of: Callable = Callable()   # (uid, skill_id) -> Dictionary（运行时技能定义）
var art_alpha: Callable = Callable()      # (uid, alpha) -> void（真身美术显隐）
var item_icon_of: Callable = Callable()   # item_id -> Texture2D（投掷物）
var time_scale := 1.0                     # 托管倍速（壳注入）

var stats := {"actions": 0, "fx": 0, "strips": 0}
var last_actions: Array[Dictionary] = []  # 无头探针：[{uid, action}]（封顶 16）
var last_fx: Array[Dictionary] = []       # 无头探针：[{fx, from, to, hit}]（封顶 16）

var _pending: Array[Dictionary] = []
var _ghosts: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _hidden: Dictionary = {}              # uid -> 剩余动画数
var _strips: Dictionary = {}              # path -> Texture2D / null
var _rng := Rng.new(20261110)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func reset() -> void:
	for uid: String in _hidden.keys():
		_set_alpha(uid, 1.0)
	_hidden.clear()
	_pending.clear()
	_ghosts.clear()
	_effects.clear()
	last_actions.clear()
	last_fx.clear()
	for k: String in stats:
		stats[k] = 0
	queue_redraw()

## 壳重建单位节点时查询：动画中的单位真身保持透明（替身在演）。
func is_hidden(uid: String) -> bool:
	return _hidden.has(uid)

func is_busy() -> bool:
	return not _ghosts.is_empty() or not _effects.is_empty() or not _pending.is_empty()

# ---------------------------------------------------------------- 壳共用查询（两壳同一实现，不复制逻辑）

## 运行时单位里按 id 找技能定义（skills / 其他技能数组）；sid 为空 = 普攻（取单位 attack_fx）。
static func skill_in_unit(u: Dictionary, sid: String) -> Dictionary:
	if sid == "":
		return {"fx": str(u["attack_fx"])} if u.has("attack_fx") else {}
	for v: Variant in u.values():
		if v is Array:
			for s: Variant in v:
				if s is Dictionary and str((s as Dictionary).get("id", "")) == sid:
					return s
	return {}

## 单位真身美术显隐：竖屏单位按钮（icon 着色）/ 横屏格内单位图（art_token 子节点 modulate）。
static func unit_art_alpha(node: Control, a: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is Button:
		for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_disabled_color",
				"icon_focus_color", "icon_hover_pressed_color"]:
			node.add_theme_color_override(key, Color(1, 1, 1, a))
		return
	var host: Node = node.get_parent() if node.get_parent() != null else node
	for c: Node in host.get_children():
		if c is CanvasItem and (c as Node).has_meta("art_token"):
			var ci := c as CanvasItem
			ci.modulate = Color(ci.modulate, a)

# ---------------------------------------------------------------- 特效推断（数据优先，形态兜底）

## 技能定义 → 特效名。def.fx 优先；否则：治疗 → heal；带 save 的范围 → burst；
## 辅助（utility）→ shield；攻击按属性：智（墨术）→ bolt，敏 → stab，力 → slash；敌方无属性普攻 → claw。
static func resolve_fx(def: Dictionary, side: StringName = &"party") -> String:
	var fx := str(def.get("fx", ""))
	if FX_KINDS.has(fx):
		return fx
	if def.has("heal"):
		return "heal"
	if def.has("save"):
		return "burst"
	var kind := str(def.get("kind", "attack"))
	if kind == "utility" or kind == "buff":
		return "shield" if kind == "utility" else "aura"
	if kind == "summon":
		return "summon"
	match str(def.get("attr", "")):
		"wits":
			return "bolt"
		"finesse":
			return "stab"
		"might":
			return "slash"
	return "claw" if side == &"enemy" else "slash"

## 特效 → 施放者动作。
static func action_for(fx: String) -> String:
	if MELEE.has(fx):
		return "lunge"
	if fx == "arc":
		return "throw"
	if fx == "shield" or fx == "aura":
		return "brace"
	return "cast"

## 特效颜色：def.fx_color 优先；否则按特效 / 阵营。
static func fx_color(fx: String, def: Dictionary = {}, side: StringName = &"party") -> Color:
	if def.has("fx_color"):
		return Color.from_string(str(def["fx_color"]), Color.WHITE)
	match fx:
		"heal":
			return Color(0.55, 0.95, 0.6)
		"shield", "aura":
			return Color(0.95, 0.82, 0.45)
		"smoke":
			return Color(0.7, 0.72, 0.75)
		"bolt", "lance", "summon":
			return Color(0.78, 0.58, 1.0) if side == &"party" else Color(0.86, 0.42, 1.0)
		"claw", "burst", "wave":
			return Color(0.9, 0.45, 1.0) if side == &"enemy" else Color(0.98, 0.8, 0.4)
	return Color(1.0, 0.93, 0.75)

# ---------------------------------------------------------------- 事件入口（只登记，隔帧播出）

func on_event(ev: Dictionary) -> void:
	var p: Dictionary = ev.get("payload", {})
	match StringName(ev["type"]):
		EventTypes.BATTLE_ATTACK:
			var a := str(p.get("attacker", ""))
			var def := _skill(a, str(p.get("skill", "")))
			var fx := resolve_fx(def, _side(a))
			if MELEE.has(fx) or not PROJECTILE.has(fx):
				_queue_action(a, action_for(fx), str(p.get("target", "")))
			else:
				_queue_action(a, "cast", str(p.get("target", "")))
			_queue_fx(fx, a, str(p.get("target", "")), def, bool(p.get("hit", false)), bool(p.get("crit", false)))
		EventTypes.SKILL_USE:
			if StringName(p.get("source", &"")) == &"enemy": # 敌方范围技（带 save）：施法 + 我方范围特效
				var u := str(p.get("unit", ""))
				var def2 := _skill(u, str(p.get("skill", "")))
				if def2.is_empty():
					def2 = {"save": {}}
				_queue_action(u, "cast", "")
				_queue_area(resolve_fx(def2, &"enemy"), u, &"party", def2)
		EventTypes.BATTLE_SKILL:
			var u2 := str(p.get("unit", ""))
			var def3 := _skill(u2, str(p.get("skill", "")))
			if p.has("effect"):
				def3 = def3.duplicate()
				def3["kind"] = "buff"
				_queue_action(u2, "brace", "")
				_queue_fx(resolve_fx(def3, &"enemy"), u2, u2, def3, true, false)
			elif p.has("summoned"):
				def3 = def3.duplicate()
				def3["kind"] = "summon"
				_queue_action(u2, "cast", "")
				_queue_fx(resolve_fx(def3, &"enemy"), u2, u2, def3, true, false)
			else:
				if not def3.has("save"):
					def3 = def3.duplicate()
					def3["save"] = p.get("save", {})
				_queue_action(u2, "cast", "")
				_queue_area(resolve_fx(def3, &"enemy"), u2, &"party", def3)
		EventTypes.ITEM_USE:
			var u3 := str(p.get("unit", ""))
			var tgt := str(p.get("target", u3))
			if bool(p.get("thrown", false)):
				_queue_action(u3, "throw", tgt)
				_queue_fx("arc", u3, tgt, {"item": str(p.get("item", ""))}, true, false)
			elif int(p.get("healed", 0)) > 0:
				_queue_action(u3, "cast", "")
				_queue_fx("heal", u3, tgt, {}, true, false)
		EventTypes.LOG:
			match str(p.get("msg_key", "")):
				"MSG_SKILL_HEAL":
					var u4 := str(p.get("unit", ""))
					var d4 := _skill(u4, str(p.get("skill", "")))
					_queue_action(u4, "cast", "")
					_queue_fx("heal", u4, str(p.get("target", u4)), d4, true, false)
				"MSG_SKILL_USED":
					var u5 := str(p.get("unit", ""))
					var d5 := _skill(u5, str(p.get("skill", "")))
					var fx5 := resolve_fx(d5 if not d5.is_empty() else {"kind": "utility"}, _side(u5))
					_queue_action(u5, action_for(fx5), "")
					_queue_fx(fx5, u5, u5, d5, true, false)
		EventTypes.BATTLE_MOVE:
			_queue_action(str(p.get("unit", "")), "hop", "")
		EventTypes.BATTLE_DOWN:
			_queue_action(str(p.get("unit", "")), "down", "")
		EventTypes.BATTLE_REVIVE:
			var u6 := str(p.get("unit", ""))
			_queue_action(u6, "revive", "")
			_queue_fx("heal", u6, u6, {}, true, false)

func _skill(uid: String, sid: String) -> Dictionary:
	if not skill_def_of.is_valid():
		return {}
	var d: Variant = skill_def_of.call(uid, sid)
	return d if d is Dictionary else {}

func _side(uid: String) -> StringName:
	return StringName(side_of.call(uid)) if side_of.is_valid() else &"party"

func _queue_action(uid: String, action: String, toward: String) -> void:
	if uid == "":
		return
	_pending.append({"kind": &"action", "uid": uid, "action": action, "toward": toward, "wait": 1})

func _queue_fx(fx: String, from: String, to: String, def: Dictionary, hit: bool, crit: bool) -> void:
	_pending.append({"kind": &"fx", "fx": fx, "from": from, "to": to, "def": def, "hit": hit, "crit": crit,
		"wait": 1})

func _queue_area(fx: String, from: String, side: StringName, def: Dictionary) -> void:
	var targets: Array = units_of.call(side) if units_of.is_valid() else []
	_pending.append({"kind": &"area", "fx": fx, "from": from, "targets": targets, "def": def, "wait": 1})

# ---------------------------------------------------------------- 播出

func _process(delta: float) -> void:
	var queued := _pending.size()
	for i: int in queued:
		var job: Dictionary = _pending.pop_front()
		if int(job.get("wait", 0)) > 0:
			job["wait"] = int(job["wait"]) - 1
			_pending.append(job)
			continue
		match StringName(job["kind"]):
			&"action":
				_start_action(str(job["uid"]), str(job["action"]), str(job["toward"]))
			&"fx":
				_start_fx(str(job["fx"]), str(job["from"]), str(job["to"]), job["def"], bool(job["hit"]), bool(job["crit"]))
			&"area":
				for t: Variant in job["targets"]:
					_start_fx(str(job["fx"]), str(job["from"]), str(t), job["def"], true, false)
	var dt := delta * maxf(time_scale, 0.1)
	for g: Dictionary in _ghosts.duplicate():
		g["t"] = float(g["t"]) + dt
		if float(g["t"]) >= float(g["dur"]):
			_ghosts.erase(g)
			_release(str(g["uid"]))
	for e: Dictionary in _effects.duplicate():
		e["t"] = float(e["t"]) + dt
		if float(e["t"]) >= float(e["dur"]):
			_effects.erase(e)
	if not _ghosts.is_empty() or not _effects.is_empty():
		queue_redraw()
	elif get_meta(&"dirty", false):
		set_meta(&"dirty", false)
		queue_redraw()

func _record(arr: Array[Dictionary], rec: Dictionary) -> void:
	arr.append(rec)
	if arr.size() > 16:
		arr.pop_front()

func _start_action(uid: String, action: String, toward: String) -> void:
	stats["actions"] += 1
	_record(last_actions, {"uid": uid, "action": action})
	if not rect_of.is_valid():
		return
	var r: Variant = rect_of.call(uid)
	if not r is Rect2 or (r as Rect2).size == Vector2.ZERO:
		return
	var ref := str(art_ref_of.call(uid)) if art_ref_of.is_valid() else ""
	var tex := ArtLoader.texture_for(ref) if ref != "" else null
	var strip := action_strip(ref.get_file(), action) if ref != "" else null
	if tex == null and strip == null:
		return # 无美术：只播特效，不出替身
	var dir := Vector2.ZERO
	if toward != "" and anchor_of.is_valid():
		dir = Vector2(anchor_of.call(toward)) - (r as Rect2).get_center()
	var g := {"uid": uid, "action": action, "rect": r, "tex": tex, "strip": strip, "dir": dir, "t": 0.0,
		"dur": ACTION_TIME * (1.4 if action == "down" or action == "revive" else 1.0)}
	if strip != null:
		stats["strips"] += 1
		g["dur"] = maxf(float(g["dur"]), _strip_frames(strip) / STRIP_FPS)
	_ghosts.append(g)
	_hidden[uid] = int(_hidden.get(uid, 0)) + 1
	_set_alpha(uid, 0.0)

func _release(uid: String) -> void:
	var n := int(_hidden.get(uid, 0)) - 1
	if n <= 0:
		_hidden.erase(uid)
		_set_alpha(uid, 1.0)
	else:
		_hidden[uid] = n
	set_meta(&"dirty", true)

func _set_alpha(uid: String, a: float) -> void:
	if art_alpha.is_valid():
		art_alpha.call(uid, a)

func _start_fx(fx: String, from: String, to: String, def: Dictionary, hit: bool, crit: bool) -> void:
	stats["fx"] += 1
	var side := _side(from)
	_record(last_fx, {"fx": fx, "from": from, "to": to, "hit": hit})
	if not anchor_of.is_valid():
		return
	var e := {"fx": fx, "t": 0.0, "dur": float(FX_TIME.get(fx, 0.4)) * (1.15 if crit else 1.0),
		"from": Vector2(anchor_of.call(from)) if from != "" else Vector2(anchor_of.call(to)),
		"to": Vector2(anchor_of.call(to)) if to != "" else Vector2(anchor_of.call(from)),
		"color": fx_color(fx, def, side), "hit": hit, "crit": crit, "seed": _rng.range_int(0, 9999),
		"strip": _strip("res://assets/art/fx/fx_%s.png" % fx)}
	if fx == "arc" and item_icon_of.is_valid():
		e["icon"] = item_icon_of.call(str(def.get("item", "")))
	if e["strip"] != null:
		stats["strips"] += 1
		e["dur"] = maxf(float(e["dur"]), _strip_frames(e["strip"]) / STRIP_FPS)
	_effects.append(e)

# ---------------------------------------------------------------- 外部帧条

func _strip(path: String) -> Texture2D:
	if _strips.has(path):
		return _strips[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_strips[path] = tex
	return tex

## 单位动作帧条：anim_<id>_<action>；进攻类动作（lunge / cast / throw）缺专用条时
## 依次回落 anim_<id>_attack → anim_<id>_lunge（一条出招动画即可覆盖全部进攻）。
func action_strip(art_id: String, action: String) -> Texture2D:
	var names: Array[String] = [action]
	if ["lunge", "cast", "throw"].has(action):
		names.append_array(["attack", "lunge"])
	for nm: String in names:
		var t := _strip("res://assets/art/anims/anim_%s_%s.png" % [art_id, nm])
		if t != null:
			return t
	return null

static func _strip_frames(tex: Texture2D) -> int:
	return maxi(1, int(tex.get_width() / maxf(1.0, tex.get_height())))

func _draw_strip(tex: Texture2D, center: Vector2, size: float, u: float, mod: Color = Color.WHITE) -> void:
	var n := _strip_frames(tex)
	var f := clampi(int(u * n), 0, n - 1)
	var h := float(tex.get_height())
	draw_texture_rect_region(tex, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)),
		Rect2(f * h, 0, h, h), mod)

# ---------------------------------------------------------------- 绘制

func _local(p: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * p

func _draw() -> void:
	for g: Dictionary in _ghosts:
		_draw_ghost(g)
	for e: Dictionary in _effects:
		_draw_fx(e)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ghost(g: Dictionary) -> void:
	var r: Rect2 = g["rect"]
	var u := clampf(float(g["t"]) / float(g["dur"]), 0.0, 1.0)
	var c := _local(r.get_center())
	var side := minf(r.size.x, r.size.y)
	var off := Vector2.ZERO
	var rot := 0.0
	var sc := Vector2.ONE
	var mod := Color.WHITE
	var s := sin(PI * u)
	match str(g["action"]):
		"lunge":
			var d: Vector2 = g["dir"]
			var dist := minf(70.0, d.length() * 0.45)
			off = d.normalized() * dist * s if d.length() > 1.0 else Vector2(0, -12) * s
			rot = 0.18 * s * (1.0 if d.x >= 0.0 else -1.0)
		"throw":
			var d2: Vector2 = g["dir"]
			off = (d2.normalized() * 18.0 if d2.length() > 1.0 else Vector2.ZERO) * s
			rot = -0.25 * s
		"cast":
			off = Vector2(0, -10) * s
			sc = Vector2.ONE * (1.0 + 0.1 * s)
			mod = Color(1.0 + 0.6 * s, 1.0 + 0.5 * s, 1.0 + 0.8 * s)
		"hop":
			off = Vector2(0, -16) * s
			sc = Vector2(1.0 + 0.1 * (1.0 - s), 1.0 - 0.1 * (1.0 - s)) if u > 0.85 else Vector2.ONE
		"brace":
			sc = Vector2(1.0 + 0.1 * s, 1.0 - 0.08 * s)
			mod = Color(1.0 + 0.4 * s, 1.0 + 0.35 * s, 1.0)
		"down":
			var k := ease(u, 0.4)
			rot = 1.25 * k
			off = Vector2(side * 0.15 * k, side * 0.18 * k)
			mod = Color(1, 1, 1, 1.0 - 0.45 * k)
		"revive":
			var k2 := 1.0 - ease(u, 0.4)
			rot = 1.25 * k2
			off = Vector2(side * 0.15 * k2, side * 0.18 * k2)
			mod = Color(1.0 + 0.6 * s, 1.0 + 0.6 * s, 1.0 + 0.3 * s)
	draw_set_transform(c + off, rot, sc)
	if g["strip"] != null:
		_draw_strip(g["strip"], Vector2.ZERO, side, u, mod)
	elif g["tex"] != null:
		draw_texture_rect(g["tex"], Rect2(Vector2(-side, -side) * 0.5, Vector2(side, side)), false, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_fx(e: Dictionary) -> void:
	var u := clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
	var a := _local(e["from"])
	var b := _local(e["to"])
	var col: Color = e["color"]
	var fade := 1.0 - u
	var hit := bool(e["hit"])
	var big := 1.3 if bool(e["crit"]) else 1.0
	if e["strip"] != null: # 外部帧条覆盖程序化（投射类仍沿弹道走）
		var pos := a.lerp(b, minf(1.0, u * 1.6)) if PROJECTILE.has(str(e["fx"])) else b
		_draw_strip(e["strip"], pos, 96.0 * big, u)
		return
	match str(e["fx"]):
		"slash":
			for k: int in 3:
				var r := (32.0 + k * 11.0) * big
				var a0 := -2.4 + k * 0.25
				var sweep := 2.2 * minf(1.0, u * 2.2)
				_garc(b + Vector2(-6 + k * 6, -4), r, a0, a0 + sweep, 18, Color(col, fade * (0.9 - k * 0.2)),
					(4.0 - k) * big, true)
			if not hit:
				_garc(b + Vector2(30, 0), 22, -1.0, 1.0, 10, Color(col, fade * 0.3), 2.0, true)
		"stab":
			var dir := (b - a).normalized() if (b - a).length() > 1.0 else Vector2.RIGHT
			var tip := b + dir * 10.0
			var len := 46.0 * minf(1.0, u * 3.0) * big
			_gline(tip - dir * len, tip, Color(col, fade), 4.0 * big, true)
			if hit and u > 0.3:
				for k2: int in 6:
					var ang := TAU * k2 / 6.0 + float(e["seed"])
					_gline(tip, tip + Vector2(cos(ang), sin(ang)) * 16.0 * u * big, Color(1, 1, 0.8, fade), 2.0, true)
		"claw":
			for k3: int in 3:
				var o := Vector2(-14 + k3 * 14, 0)
				var p0 := b + o + Vector2(-16, -22) * big
				var p1 := b + o + Vector2(16, 22) * big
				_gline(p0, p0.lerp(p1, minf(1.0, u * 2.5)), Color(col, fade), 5.0 * big, true)
		"smash":
			draw_circle(b, 34.0 * big * minf(1.0, u * 2.0), Color(col, 0.35 * fade))
			for k4: int in 8:
				var ang2 := TAU * k4 / 8.0
				_gline(b + Vector2(cos(ang2), sin(ang2)) * 14.0, b + Vector2(cos(ang2), sin(ang2)) * (14.0 + 34.0 * u * big),
					Color(col, fade), 3.0, true)
		"bolt", "lance":
			var travel := minf(1.0, u / 0.6)
			var head := a.lerp(b, travel)
			if travel < 1.0:
				for k5: int in 6:
					var tp := a.lerp(b, maxf(0.0, travel - k5 * 0.04))
					draw_circle(tp, (9.0 - k5) * big, Color(col, 0.8 - k5 * 0.12))
				draw_circle(head, 6.0 * big, Color(1, 1, 1, 0.9))
				if str(e["fx"]) == "lance":
					_gline(a.lerp(b, maxf(0.0, travel - 0.25)), head, Color(col, 0.9), 5.0 * big, true)
			elif hit:
				var v := (u - 0.6) / 0.4
				draw_circle(b, 30.0 * big * v, Color(col, 0.5 * (1.0 - v)))
				_garc(b, 36.0 * big * v, 0.0, TAU, 24, Color(1, 1, 1, 1.0 - v), 2.0, true)
		"arc":
			var tr := minf(1.0, u / 0.7)
			var pos2 := a.lerp(b, tr) + Vector2(0, -90.0 * sin(PI * tr))
			if tr < 1.0:
				if e.get("icon") is Texture2D:
					draw_set_transform(pos2, tr * TAU * 1.5, Vector2.ONE)
					draw_texture_rect(e["icon"], Rect2(-16, -16, 32, 32), false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					draw_circle(pos2, 8.0, col)
			else:
				var v2 := (u - 0.7) / 0.3
				draw_circle(b, 40.0 * v2, Color(0.55, 0.8, 0.95, 0.5 * (1.0 - v2)))
				for k6: int in 10:
					var ang3 := TAU * k6 / 10.0 + float(e["seed"])
					draw_circle(b + Vector2(cos(ang3), sin(ang3)) * 46.0 * v2, 4.0 * (1.0 - v2), Color(0.8, 0.95, 1.0, 1.0 - v2))
		"burst":
			draw_circle(b, 46.0 * u, Color(col, 0.35 * fade))
			_garc(b, 52.0 * u, 0.0, TAU, 32, Color(col, fade), 4.0, true)
			for k7: int in 10:
				var ang4 := TAU * k7 / 10.0 + float(e["seed"]) * 0.01
				draw_circle(b + Vector2(cos(ang4), sin(ang4)) * 60.0 * u, 5.0 * fade, Color(col.lightened(0.3), fade))
		"wave":
			for k8: int in 3:
				var v3 := clampf(u * 1.4 - k8 * 0.2, 0.0, 1.0)
				_garc(b + Vector2(0, 20), 30.0 + 50.0 * v3, PI * 1.1, PI * 1.9, 20, Color(col, (1.0 - v3) * 0.9), 5.0, true)
		"heal":
			_garc(b, 30.0 + 10.0 * u, 0.0, TAU, 28, Color(col, 0.6 * fade), 3.0, true)
			for k9: int in 9:
				var x := -26.0 + k9 * 6.5
				var yy := 26.0 - 70.0 * fmod(u + k9 * 0.13, 1.0)
				var pt := b + Vector2(x, yy)
				_gline(pt + Vector2(-4, 0), pt + Vector2(4, 0), Color(col.lightened(0.4), fade), 2.0)
				_gline(pt + Vector2(0, -4), pt + Vector2(0, 4), Color(col.lightened(0.4), fade), 2.0)
		"shield":
			var pulse := 1.0 + 0.06 * sin(u * TAU * 2.0)
			draw_circle(b, 40.0 * pulse * minf(1.0, u * 3.0), Color(col, 0.18 * fade))
			_garc(b, 40.0 * pulse * minf(1.0, u * 3.0), 0.0, TAU, 6, Color(col, fade), 3.0, true)
		"smoke":
			for k10: int in 7:
				var ang5 := TAU * k10 / 7.0 + float(e["seed"])
				draw_circle(b + Vector2(cos(ang5), sin(ang5)) * 24.0 * u, 18.0 + 16.0 * u, Color(col, 0.35 * fade))
		"summon":
			for k11: int in 4:
				var a1 := u * TAU * 1.5 + k11 * PI * 0.5
				_garc(b + Vector2(0, 24), 18.0 + 14.0 * k11 * 0.3, a1, a1 + 1.6, 12, Color(col, fade), 4.0, true)
			draw_circle(b + Vector2(0, 24), 22.0 * minf(1.0, u * 2.0), Color(0.05, 0.02, 0.08, 0.6 * fade))
		"aura":
			for k12: int in 8:
				var x2 := -30.0 + k12 * 8.5
				var y2 := 30.0 - 60.0 * fmod(u * 1.3 + k12 * 0.17, 1.0)
				_gline(b + Vector2(x2, y2), b + Vector2(x2, y2 - 14), Color(col, fade), 3.0, true)
			_garc(b, 38.0, 0.0, TAU, 28, Color(col, 0.5 * fade), 2.0, true)

## 发光描边：外圈宽而淡的光晕 + 内芯（暗底上也看得清）。
func _gline(a: Vector2, b: Vector2, col: Color, w: float = 2.0, aa: bool = true) -> void:
	draw_line(a, b, Color(col, col.a * 0.28), w * 3.2, aa)
	draw_line(a, b, col, w, aa)
	draw_line(a, b, Color(1, 1, 1, col.a * 0.55), maxf(1.0, w * 0.35), aa)

func _garc(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = 2.0, aa: bool = true) -> void:
	draw_arc(c, r, a0, a1, n, Color(col, col.a * 0.28), w * 3.2, aa)
	draw_arc(c, r, a0, a1, n, col, w, aa)
