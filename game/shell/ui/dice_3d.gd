# 多面骰 3D 物理演出（docs/en/framework/17-polyhedral-dice-spec.md；09 §6 关键级"全屏物理演出"；
# 14 #2；04 §3.2 骰子系统；04 §④.7 长按跳过由壳层仲裁）。
# - 骰型来自 DiceShapes 几何表：d4 / d6 / d8 / d10 / d12 / d20（d100 = 十位 d10 + 个位 d10）；
# - 一次可掷多枚（play_set）：伤害 2d4、暴击翻倍骰、d100 等同场翻滚，各自落定到给定值；
# - compact（托盘档，17 §3）：透明底、无慢镜头、≈1 秒收束，叠在主视野下缘，不拦截输入；
# 铁律边界：
# - 结果由逻辑层给定（play/play_set 的参数就是事件流里的骰值）——物理只是演出，
#   落定时把目标面（d4 为目标顶点）定向到读数位置（最短弧对齐），绝不允许物理决定结果；
# - 纯呈现：不读写 Board、不发事件流、不引用 core 判定路径；皮肤只经 Cosmetics.palette_of 取色；
#   演出视觉随机走种子化 Rng，与逻辑骰无关；
# - time_scale 慢镜头是全局旋钮：恢复责任在本类（定格/跳过/析构三处兜底恢复）。
class_name Dice3D
extends Control

signal finished(result: int)

## 演出速率（1.0 = 正式节奏；测试/截图注入更大值压缩等待，物理弹道不变）。
var speed: float = 1.0
## 托盘档（17 §3）：透明底、无慢镜头、短弹跳；须在 add_child 前设定（_ready 建台按此取景）。
var compact := false

const DIE_RADIUS := 0.62          # 骰子外接球半径（米级桌面布景）
const TABLE_TOP := 0.0            # 桌面上表面高度
const SLOW_MO_SCALE := 0.3        # 慢镜头档位（14 #2：Engine.time_scale 渐变 0.3）
const THROW_MIN := 1.5            # 弹跳最短时长（秒，14 #2：1.5~2s）
const THROW_MAX := 2.0            # 弹跳上限，到点强制收束（物理只做表演）
const ALIGN_TIME := 0.5           # 慢镜头内定格对齐时长
const COMPACT_THROW := 0.55       # 托盘档弹跳时长
const COMPACT_ALIGN := 0.22
const MAX_VISIBLE_DICE := 6       # 同场最多可视骰数（更多骰只计入总和，由壳层文字呈现）
## 每种骰面字号（pixel_size）：面越大字越大。
const LABEL_PX := {"d4": 0.0015, "d6": 0.0034, "d8": 0.0024, "d10": 0.0019, "d12": 0.0021, "d20": 0.0022}

var _sub: SubViewport
var _camera: Camera3D
var _felt: MeshInstance3D
var _trim: MeshInstance3D
var _env: Environment
var _edge_mat: StandardMaterial3D # 边缘光（备用描边壳，皮肤扩展位）
var _body_mat: StandardMaterial3D
var _label_color := Color(0.93, 0.80, 0.45)
var _label_outline := Color(0.10, 0.07, 0.02)

## 当前同场骰：[{body: RigidBody3D, shape: Dictionary, target: int, labels: Array[Label3D], key: String}]
var _dice: Array = []

var _playing := false
var _skip := false
var _settled := false
var _prev_time_scale := 1.0
var _time_tween: Tween = null
var _camera_base_fov := 55.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE # 长按跳过由壳层 overlay 统一仲裁（04 §④.7）
	_build_stage()
	_set_dice([{"die": "d20", "value": 1}]) # 缺省一枚 d20（关键判定，兼容旧调用）
	resized.connect(_fit_viewport)
	_fit_viewport()

# ---------------------------------------------------------------- 舞台（桌面/灯光/相机/环境，全程序化）

func _build_stage() -> void:
	var container := SubViewportContainer.new()
	container.name = "ViewportContainer"
	container.stretch = false # 尺寸由 _fit_viewport 手写 1:1（stretch=true 禁改 SubViewport.size）
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_sub = SubViewport.new()
	_sub.name = "Sub"
	_sub.own_world_3d = true
	_sub.transparent_bg = compact # 托盘档：透明底叠在主视野上
	container.add_child(_sub)

	var env_node := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_CLEAR_COLOR if compact else Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.02, 0.07)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.22, 0.20, 0.28)
	_env.ambient_light_energy = 0.9
	_env.glow_enabled = not compact # 边缘光泛光（金墨高光，小剂量防糊面；透明底不开泛光）
	_env.glow_intensity = 0.3
	_env.glow_bloom = 0.04
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env_node.environment = _env
	_sub.add_child(env_node)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = _camera_base_fov
	_sub.add_child(_camera)
	_camera.look_at_from_position(Vector3(0, 4.7, 6.3), Vector3(0, 0.3, 0), Vector3.UP)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color(1.0, 0.88, 0.62) # 金色主光
	sun.light_energy = 1.35
	sun.shadow_enabled = not compact
	_sub.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.4, 2.6, -1.8)
	rim.light_color = Color(0.45, 0.55, 1.0) # 冷色轮廓补光，衬金墨
	rim.light_energy = 0.7
	rim.omni_range = 8.0
	_sub.add_child(rim)

	# 桌面（墨色绒面 + 金边底盘；托盘档只留碰撞，不画桌面）
	var table := StaticBody3D.new()
	table.name = "Table"
	_sub.add_child(table)
	_felt = MeshInstance3D.new()
	var felt_mesh := BoxMesh.new()
	felt_mesh.size = Vector3(11, 0.4, 8.4)
	_felt.mesh = felt_mesh
	var felt_mat := StandardMaterial3D.new()
	felt_mat.albedo_color = Color(0.05, 0.05, 0.10)
	felt_mat.roughness = 0.9
	_felt.material_override = felt_mat
	_felt.position = Vector3(0, TABLE_TOP - 0.2, 0)
	_felt.visible = not compact
	table.add_child(_felt)
	_trim = MeshInstance3D.new()
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(11.5, 0.16, 8.9)
	_trim.mesh = trim_mesh
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.36, 0.26, 0.08)
	trim_mat.metallic = 0.9
	trim_mat.roughness = 0.35
	trim_mat.emission_enabled = true
	trim_mat.emission = Color(0.55, 0.38, 0.10)
	trim_mat.emission_energy_multiplier = 0.35
	_trim.material_override = trim_mat
	_trim.position = Vector3(0, TABLE_TOP - 0.44, 0)
	_trim.visible = not compact
	table.add_child(_trim)
	var table_col := CollisionShape3D.new()
	var table_box := BoxShape3D.new()
	table_box.size = Vector3(11, 0.4, 8.4)
	table_col.shape = table_box
	table_col.position = _felt.position
	table.add_child(table_col)
	# 隐形围挡：骰不出画（物理仍只是表演，围挡保证收束在镜头内）
	for w: Array in [[Vector3(5.6, 1.5, 0), Vector3(0.2, 3.4, 8.8)],
			[Vector3(-5.6, 1.5, 0), Vector3(0.2, 3.4, 8.8)],
			[Vector3(0, 1.5, 4.3), Vector3(11.6, 3.4, 0.2)],
			[Vector3(0, 1.5, -4.3), Vector3(11.6, 3.4, 0.2)]]:
		var wall_col := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = w[1]
		wall_col.shape = wall_box
		wall_col.position = w[0]
		table.add_child(wall_col)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.07, 0.06, 0.12)
	_body_mat.metallic = 0.35
	_body_mat.roughness = 0.32
	_body_mat.rim_enabled = true # 边缘光（14 #2 金墨配色 + 边缘光）
	_body_mat.rim = 1.0
	_body_mat.rim_tint = 0.2
	if compact:
		_tray_body_tone() # 托盘档透明底叠在深色界面上：骰身提亮 + 微自发光，轮廓才看得见
	_edge_mat = StandardMaterial3D.new() # 备用描边壳（默认不启用，皮肤扩展位）
	_edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_edge_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_edge_mat.grow = true
	_edge_mat.grow_amount = 0.014
	_edge_mat.albedo_color = Color(0.91, 0.78, 0.42)

# ---------------------------------------------------------------- 骰体（按 DiceShapes 程序化构建）

## dice = [{die: "d8", value: 6, tens?: bool}]；骰型/数量变化时重建骰体，相同则复用。
func _set_dice(dice: Array) -> void:
	var keys: Array = []
	for d: Variant in dice:
		keys.append("%s%s" % [str((d as Dictionary).get("die", "d20")), "T" if bool((d as Dictionary).get("tens", false)) else ""])
	var same := keys.size() == _dice.size()
	if same:
		for i: int in keys.size():
			if str(_dice[i]["key"]) != str(keys[i]):
				same = false
				break
	if not same:
		for e: Variant in _dice:
			((e as Dictionary)["body"] as Node).queue_free()
		_dice.clear()
		var radius := DIE_RADIUS * (1.0 if dice.size() <= 2 else (0.82 if dice.size() <= 4 else 0.7)) # 多骰缩小防拥挤
		for i: int in dice.size():
			var spec: Dictionary = dice[i]
			var shape := DiceShapes.build(str(spec.get("die", "d20")), radius)
			shape["radius"] = radius
			var entry := {"shape": shape, "key": keys[i], "tens": bool(spec.get("tens", false)), "target": 1}
			entry["body"] = _make_body(shape, bool(spec.get("tens", false)), entry)
			_dice.append(entry)
	for i: int in dice.size():
		var sides := int((_dice[i]["shape"] as Dictionary)["sides"])
		_dice[i]["target"] = clampi(int((dice[i] as Dictionary).get("value", 1)), 1, sides)

func _make_body(shape: Dictionary, tens: bool, entry: Dictionary) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Die_%s" % str(shape["die"])
	body.mass = 0.9
	var phys := PhysicsMaterial.new()
	phys.bounce = 0.42
	phys.friction = 0.55
	body.physics_material_override = phys
	body.can_sleep = true
	body.visible = false
	body.freeze = true
	_sub.add_child(body)
	var col := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = PackedVector3Array(shape["verts"])
	col.shape = hull
	body.add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = _build_mesh(shape)
	body.add_child(mi)
	entry["labels"] = _build_labels(body, shape, tens)
	return body

## 逐面独立顶点（平直着色），多边形扇形三角化；墨面本体 + 材质级 rim 边缘光。
func _build_mesh(shape: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: Array = shape["verts"]
	for fi: int in (shape["faces"] as Array).size():
		var poly: Array = shape["faces"][fi]
		var n: Vector3 = shape["normals"][fi]
		for k: int in range(1, poly.size() - 1):
			# Godot 以顺时针为正面：外法线逆时针的多边形按 0 / k+1 / k 发射（否则外表面被剔除、只见内壁）
			for idx: int in [poly[0], poly[k + 1], poly[k]]:
				st.set_normal(n)
				st.add_vertex(verts[idx])
	var mesh := st.commit()
	mesh.surface_set_material(0, _body_mat)
	return mesh

## 数字：face 读法 = 面心一枚；vertex 读法（d4）= 每面三枚，各朝所属顶点（顶尖读数）。
func _build_labels(body: RigidBody3D, shape: Dictionary, tens: bool) -> Array[Label3D]:
	var out: Array[Label3D] = []
	var px: float = float(LABEL_PX.get(str(shape["die"]), 0.0022)) * float(shape.get("radius", DIE_RADIUS)) / DIE_RADIUS
	var verts: Array = shape["verts"]
	var values: Array = shape["values"]
	for fi: int in (shape["faces"] as Array).size():
		var poly: Array = shape["faces"][fi]
		var n: Vector3 = shape["normals"][fi]
		var c := DiceShapes.face_center(shape, fi)
		if str(shape["read"]) == "vertex":
			for vi: Variant in poly:
				var tip: Vector3 = verts[vi]
				var lbl := _label(str(values[vi]), px)
				lbl.position = c.lerp(tip, 0.55) + n * 0.012
				var up := (tip - c)
				up = (up - n * n.dot(up)).normalized()
				lbl.basis = Basis(up.cross(n).normalized(), up, n).orthonormalized()
				body.add_child(lbl)
				out.append(lbl)
		else:
			var v := int(values[fi])
			var text := ("%02d" % ((v % 10) * 10)) if tens else str(v)
			if int(shape["sides"]) >= 9 and (v == 6 or v == 9) and not tens:
				text += "."  # 6 / 9 区分（实体骰惯例：面数 ≥9 的骰在 6、9 后加点）
			var lbl2 := _label(text, px)
			lbl2.position = c + n * 0.012
			lbl2.basis = _facing_basis(n)
			body.add_child(lbl2)
			out.append(lbl2)
	return out

func _label(text: String, px: float) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 220
	lbl.pixel_size = px
	lbl.modulate = _label_color
	lbl.outline_size = 26
	lbl.outline_modulate = _label_outline
	lbl.double_sided = false
	lbl.no_depth_test = false
	lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD # 字形外区域直接丢弃：不画出黑色方框盖住骰面
	return lbl

## 局部基：+Z = 面外法线（Label3D 正面朝 +Z），文字上方尽量朝世界上方。
static func _facing_basis(n: Vector3) -> Basis:
	var z := n.normalized()
	var hint := Vector3.UP if absf(z.y) < 0.95 else Vector3.FORWARD
	var x := hint.cross(z).normalized()
	var y := z.cross(x)
	return Basis(x, y, z).orthonormalized()

## d100 拆成十位 d10 + 个位 d10（17 §2）：r ∈ 1..100 → 十位面显示 00..90、个位 1..10，二者相加 = r。
static func d100_spec(r: int) -> Array:
	var tens_digit := (clampi(r, 1, 100) - 1) / 10
	return [{"die": "d10", "value": tens_digit if tens_digit > 0 else 10, "tens": true},
		{"die": "d10", "value": ((clampi(r, 1, 100) - 1) % 10) + 1}]

# ---------------------------------------------------------------- 对外 API（壳层唯一入口）

## 开始演出：单枚 d20（关键判定，兼容旧调用）。result = 逻辑层已定的骰值；seed 只驱动视觉弹道。
func play(result: int, seed: int, palette: Dictionary = {}) -> void:
	play_set([{"die": "d20", "value": result}], seed, palette)

## 同场多骰：dice = [{die, value, tens?}]（超过 MAX_VISIBLE_DICE 的骰只计数不呈现）。
func play_set(dice: Array, seed: int, palette: Dictionary = {}) -> void:
	if _playing or dice.is_empty():
		return
	_set_dice(dice.slice(0, MAX_VISIBLE_DICE))
	_apply_palette(palette)
	_run(seed)

func is_playing() -> bool:
	return _playing

## 长按跳过（壳层仲裁后调用）：立即定格到目标并恢复时间，同步完成不拖拍。
func request_skip() -> void:
	if not _playing or _settled:
		return
	_skip = true

## 首枚骰的当前读数（测试断言口：落定后必等于 play 的 result）。
func top_face() -> int:
	if _dice.is_empty():
		return -1
	return DiceShapes.reading(_dice[0]["shape"], (_dice[0]["body"] as RigidBody3D).global_transform.basis.orthonormalized())

## 全部骰的当前读数（按 play_set 顺序）。
func top_values() -> Array:
	var out: Array = []
	for e: Variant in _dice:
		out.append(DiceShapes.reading((e as Dictionary)["shape"],
			((e as Dictionary)["body"] as RigidBody3D).global_transform.basis.orthonormalized()))
	return out

func face_count() -> int:
	return int((_dice[0]["shape"] as Dictionary)["sides"]) if not _dice.is_empty() else 0

## 编号合规：首枚骰 1..N 齐备且对面和 N+1（测试断言口）。
func face_values_valid() -> bool:
	return not _dice.is_empty() and DiceShapes.values_valid(_dice[0]["shape"])

## 当前同场骰型（测试/截图探针）。
func dice_kinds() -> Array:
	return _dice.map(func(e: Dictionary) -> String: return str((e["shape"] as Dictionary)["die"]))

# ---------------------------------------------------------------- 演出流程（物理是表演，结果早定）

func _run(seed: int) -> void:
	# 多骰抬高机位（俯视看清顶面数字）；单骰保留原关键演出构图
	if compact:
		# 托盘档：近机位俯拍（托盘区域只占主视野一段，骰子须够大才看得清数字）
		_camera.look_at_from_position(Vector3(0, 3.4, 2.2), Vector3(0, 0, 0.1), Vector3.UP)
	elif _dice.size() > 1:
		_camera.look_at_from_position(Vector3(0, 6.6, 4.4), Vector3(0, 0, 0.2), Vector3.UP)
	else:
		_camera.look_at_from_position(Vector3(0, 4.7, 6.3), Vector3(0, 0.3, 0), Vector3.UP)
	_camera.fov = _camera_base_fov
	_playing = true
	_skip = false
	_settled = false
	_prev_time_scale = Engine.time_scale
	_throw(seed)
	# ① 自由弹跳（正式 1.5~2s；托盘档 ≈0.55s）；/speed 压缩等待，物理弹道本身不吃 speed
	var visual := Rng.new(seed)
	var fly_min := (COMPACT_THROW if compact
		else visual.range_int(int(THROW_MIN * 100), int(THROW_MAX * 100)) / 100.0) / speed
	var fly_cap := ((COMPACT_THROW + 0.3) if compact else (THROW_MAX + 0.6)) / speed
	var t := 0.0
	while t < fly_min or (t < fly_cap and not _all_still()):
		if _skip:
			break
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	if not _skip:
		# ② 定格对齐（正式档带慢镜头 + 镜头推近；托盘档直接对齐）
		for e: Variant in _dice:
			((e as Dictionary)["body"] as RigidBody3D).freeze = true
		if not compact:
			_tween_time_scale(SLOW_MO_SCALE, 0.14 / speed)
		await _align_to_targets((COMPACT_ALIGN if compact else ALIGN_TIME) / speed)
	if not _skip and not compact:
		_tween_time_scale(_prev_time_scale, 0.10 / speed)
		await get_tree().create_timer(0.10 / speed).timeout
	_settle_now()

## 随机初速 + 角速度抛出（视觉随机走种子化 Rng，与逻辑骰无关）；多骰沿 x 错开出手。
func _throw(seed: int) -> void:
	var visual := Rng.new(seed)
	var n := _dice.size()
	for i: int in n:
		var body: RigidBody3D = _dice[i]["body"]
		body.freeze = false
		body.visible = true
		body.sleeping = false
		var slot := _slot(i, n)
		body.position = Vector3(slot.x + visual.range_int(-6, 6) / 10.0, (2.2 if compact else 4.4) + i * 0.25,
			slot.y + visual.range_int(-10, 10) / 10.0 * (0.4 if compact else 1.0))
		body.rotation = Vector3(visual.range_int(0, 628) / 100.0,
			visual.range_int(0, 628) / 100.0, visual.range_int(0, 628) / 100.0)
		body.linear_velocity = Vector3(visual.range_int(-12, 12) / 10.0 * (0.5 if compact else 1.0),
			-2.2, visual.range_int(-8, 8) / 10.0 * (0.4 if compact else 1.0))
		body.angular_velocity = Vector3(visual.range_int(-90, 90) / 10.0,
			visual.range_int(-90, 90) / 10.0, visual.range_int(-90, 90) / 10.0)

func _all_still() -> bool:
	for e: Variant in _dice:
		var b: RigidBody3D = (e as Dictionary)["body"]
		if not (b.sleeping or (b.linear_velocity.length() < 0.35 and b.angular_velocity.length() < 0.6)):
			return false
	return true

## 目标旋转：把目标面法线（d4 为目标顶点方向）最短弧转到世界 +Y。
func _target_basis(e: Dictionary) -> Basis:
	var shape: Dictionary = e["shape"]
	var idx := int((shape["value_index"] as Dictionary)[int(e["target"])])
	var b0 := (e["body"] as RigidBody3D).global_transform.basis.orthonormalized()
	var dir_world := (b0 * (shape["dirs"][idx] as Vector3)).normalized()
	var b1 := (Basis(Quaternion(dir_world, Vector3.UP)) * b0).orthonormalized()
	if str(shape["read"]) == "face":
		# 读数面朝上后再绕竖轴转正：结果数字的"上方"背向镜头（从镜头看是正读，不会倒置成 6/9）
		var up_w := b1 * _facing_basis(shape["dirs"][idx]).y
		if Vector2(up_w.x, up_w.z).length() > 0.01:
			b1 = (Basis(Vector3.UP, PI - atan2(up_w.x, up_w.z)) * b1).orthonormalized()
	return b1

## 多骰排布格位（画面纵横比自适应：竖屏每行至多 3 枚、横屏一行排开），返回 (x, z)。
func _slot(i: int, n: int) -> Vector2:
	var aspect := 1.0
	if _sub != null and _sub.size.y > 0:
		aspect = float(_sub.size.x) / float(_sub.size.y)
	var cols := n if aspect >= 1.0 else mini(n, 3)
	cols = maxi(cols, 1)
	var rows := int(ceil(float(n) / float(cols)))
	var r := i / cols
	var c := i % cols
	var in_row := mini(cols, n - r * cols)
	var dx := 1.45 if aspect >= 1.0 else 1.25
	return Vector2((c - (in_row - 1) / 2.0) * dx, (r - (rows - 1) / 2.0) * 1.9)

## 静息位置：贴桌（最低顶点落在桌面）+ 多骰按格位收拢到镜头中心。
func _rest_position(e: Dictionary, b1: Basis, i: int, n: int) -> Vector3:
	var min_y := INF
	for v: Vector3 in (e["shape"] as Dictionary)["verts"]:
		min_y = minf(min_y, (b1 * v).y)
	var slot := _slot(i, n)
	if n == 1:
		var pos := (e["body"] as RigidBody3D).position
		return Vector3(clampf(pos.x * 0.45, -2.2, 2.2), TABLE_TOP - min_y + 0.002, clampf(pos.z * 0.45, -1.5, 1.5))
	return Vector3(slot.x, TABLE_TOP - min_y + 0.002, slot.y)

func _align_to_targets(duration: float) -> void:
	var n := _dice.size()
	var plans: Array = []
	for i: int in n:
		var e: Dictionary = _dice[i]
		var body: RigidBody3D = e["body"]
		var b1 := _target_basis(e)
		plans.append({"q0": body.global_transform.basis.orthonormalized().get_rotation_quaternion(),
			"q1": b1.get_rotation_quaternion().normalized(), "from": body.position,
			"rest": _rest_position(e, b1, i, n)})
	var elapsed := 0.0
	while elapsed < duration:
		if _skip:
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var k := smoothstep(0.0, 1.0, clampf(elapsed / duration, 0.0, 1.0))
		for i: int in n:
			var body2: RigidBody3D = _dice[i]["body"]
			body2.basis = Basis((plans[i]["q0"] as Quaternion).slerp(plans[i]["q1"], k)).orthonormalized()
			body2.position = (plans[i]["from"] as Vector3).lerp(plans[i]["rest"], k)
		if not compact:
			_camera.fov = lerpf(_camera_base_fov, 46.0 if n == 1 else 52.0, k)
	for i: int in n:
		var body3: RigidBody3D = _dice[i]["body"]
		body3.basis = Basis(plans[i]["q1"]).orthonormalized()
		body3.position = plans[i]["rest"]
		body3.linear_velocity = Vector3.ZERO
		body3.angular_velocity = Vector3.ZERO

## 定格兜底：跳过/异常路径同步完成——瞬间对齐、时间恢复、发 finished（首枚骰值）。
func _settle_now() -> void:
	if _settled:
		return
	_settled = true
	var n := _dice.size()
	for i: int in n:
		var e: Dictionary = _dice[i]
		var body: RigidBody3D = e["body"]
		body.freeze = true
		var b1 := _target_basis(e)
		body.basis = b1
		body.position = _rest_position(e, b1, i, n)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	if not compact:
		_camera.fov = 46.0 if n == 1 else 52.0
	_restore_time_scale()
	_playing = false
	var result := int(_dice[0]["target"]) if n > 0 else 0
	finished.emit(result)

## 隐藏骰体（托盘档收起时调用；下次 play 重新出手）。
func clear() -> void:
	for e: Variant in _dice:
		((e as Dictionary)["body"] as RigidBody3D).visible = false

func _tween_time_scale(target: float, duration: float) -> void:
	if _time_tween != null and _time_tween.is_valid():
		_time_tween.kill()
	_time_tween = create_tween()
	_time_tween.tween_property(Engine, "time_scale", target, maxf(duration, 0.01))

func _restore_time_scale() -> void:
	if _time_tween != null and _time_tween.is_valid():
		_time_tween.kill()
	Engine.time_scale = _prev_time_scale

func _exit_tree() -> void:
	if Engine.time_scale != _prev_time_scale:
		Engine.time_scale = _prev_time_scale # 兜底：演出中析构不得留下慢镜头

# ---------------------------------------------------------------- 皮肤（只读调色板，渲染对规则无感）

func _apply_palette(pal: Dictionary) -> void:
	if pal.is_empty():
		return
	_label_color = pal.get("face", Color(0.93, 0.80, 0.45))
	var pip: Color = pal.get("pip", Color(0.10, 0.08, 0.05))
	_label_outline = pip.darkened(0.4)
	for e: Variant in _dice:
		for lbl: Label3D in (e as Dictionary)["labels"]:
			lbl.modulate = _label_color
			lbl.outline_modulate = _label_outline
	_edge_mat.albedo_color = _label_color # 备用描边壳随肤（默认不启用）
	_body_mat.albedo_color = pip.darkened(0.35).lerp(Color(0.07, 0.06, 0.12), 0.4)
	if compact:
		_tray_body_tone()

func _tray_body_tone() -> void:
	_body_mat.albedo_color = _body_mat.albedo_color.lerp(Color(0.30, 0.27, 0.42), 0.65)
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.16, 0.13, 0.24)
	_body_mat.emission_energy_multiplier = 0.6

func _fit_viewport() -> void:
	if _sub == null:
		return
	var s := size
	if s.x < 8.0 or s.y < 8.0:
		s = get_viewport_rect().size
	_sub.size = Vector2i(maxi(int(s.x), 8), maxi(int(s.y), 8))
