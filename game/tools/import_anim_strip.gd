# 动作帧条导入（docs/en/tech/05 §9）：美术交付的横排帧图 → ActionFx 帧条（方帧、透明底）。
#   - 等宽切 N 帧，每帧补成正方形（帧宽 = 图高），人物居中；
#   - 去背景：交付图若是 JPEG（"透明"棋盘格被画进像素里），从每帧四边泛洪清除与外部连通的
#     低饱和浅灰像素（棋盘格），人物内部的灰色高光不受影响；边缘 1px 羽化；已带透明的 PNG 原样保留。
# 用法：godot --headless --path game -s tools/import_anim_strip.gd -- <源图> <帧数> <输出名，如 anim_companion_kelan_lunge>
# 输出：res://assets/art/anims/<输出名>.png
extends SceneTree

const BG_LUM := Vector2(0.50, 0.80) # 棋盘格亮度区间
const BG_SAT := 0.10                # 棋盘格饱和度上限
const BG_SAT_LOOSE := 0.14          # 第二遍（紧邻已清除区域的 JPEG 噪点）放宽

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("用法：-s tools/import_anim_strip.gd -- <源图> <帧数> <输出名>")
		quit(1)
		return
	var src := Image.load_from_file(a[0])
	src.convert(Image.FORMAT_RGBA8)
	var n := int(a[1])
	var fw := src.get_width() / n
	var fh := src.get_height()
	var side := maxi(fw, fh)
	var strip := Image.create(side * n, side, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	if src.detect_alpha() == Image.ALPHA_NONE:
		_key_background(src) # 整条去背景（帧间空隙与外部连通，一次泛洪即可）
	# 切帧：在每个名义分界（i*fw）附近 ±40% 帧宽内找前景最少的列下刀——交付图的人物间距不均匀，
	# 等宽硬切会把人物切开
	var col_fg := PackedInt32Array()
	col_fg.resize(src.get_width())
	for x: int in src.get_width():
		var cnt := 0
		for y: int in range(0, fh, 2):
			if src.get_pixel(x, y).a > 0.3:
				cnt += 1
		col_fg[x] = cnt
	# 按人物分段：列前景质量做一维加权 k-means（N 个中心，从等距名义中心起步）——人物是质量峰，
	# 矛尖 / 墨点质量小拉不动中心，挥砍拖影连着两帧也只是略微偏移；刀口取相邻中心的中点。
	var centers: Array[float] = []
	for i: int in n:
		centers.append((i + 0.5) * fw)
	for _iter: int in 30:
		var sum_w: Array[float] = []
		var sum_x: Array[float] = []
		sum_w.resize(n)
		sum_x.resize(n)
		sum_w.fill(0.0)
		sum_x.fill(0.0)
		for x5: int in src.get_width():
			var m := float(col_fg[x5])
			if m <= 0.0:
				continue
			var best_c := 0
			for c: int in range(1, n):
				if absf(x5 - centers[c]) < absf(x5 - centers[best_c]):
					best_c = c
			sum_w[best_c] += m
			sum_x[best_c] += m * x5
		for c2: int in n:
			if sum_w[c2] > 0.0:
				centers[c2] = sum_x[c2] / sum_w[c2]
	var cuts: Array[int] = [0]
	for i: int in range(1, n):
		cuts.append(int((centers[i - 1] + centers[i]) * 0.5))
	cuts.append(src.get_width())
	for i2: int in n:
		var seg := src.get_region(Rect2i(cuts[i2], 0, cuts[i2 + 1] - cuts[i2], fh))
		var used := seg.get_used_rect() # 人物包围盒：横向居中，脚底贴帧底
		if used.size.x <= 0:
			continue
		var fig := seg.get_region(used)
		if fig.get_width() > side or fig.get_height() > side:
			var k := minf(side / float(fig.get_width()), side / float(fig.get_height()))
			fig.resize(int(fig.get_width() * k), int(fig.get_height() * k), Image.INTERPOLATE_LANCZOS)
		var ox := i2 * side + (side - fig.get_width()) / 2
		var oy := side - fig.get_height() - maxi(0, fh - (used.position.y + used.size.y))
		strip.blit_rect(fig, Rect2i(Vector2i.ZERO, fig.get_size()), Vector2i(ox, maxi(0, oy)))
	var out := "res://assets/art/anims"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var path := ProjectSettings.globalize_path(out.path_join("%s.png" % a[2]))
	strip.save_png(path)
	print("[anim] %s：%d 帧 %dx%d → %s" % [a[0].get_file(), n, side, side, path])
	quit()

static func _bg_like(c: Color, sat_max: float) -> bool:
	var lum := c.get_luminance()
	return lum >= BG_LUM.x and lum <= BG_LUM.y and c.s <= sat_max

## 从四边泛洪清除与外部连通的棋盘格像素；第二遍放宽阈值吃掉紧邻的 JPEG 噪点；最后 1px 羽化。
static func _key_background(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var bg := PackedByteArray()
	bg.resize(w * h)
	var queue: Array[int] = []
	for x: int in w:
		for y: int in [0, h - 1]:
			queue.append(y * w + x)
	for y2: int in h:
		for x2: int in [0, w - 1]:
			queue.append(y2 * w + x2)
	for pass_i: int in 2:
		var sat_max := BG_SAT if pass_i == 0 else BG_SAT_LOOSE
		if pass_i == 1: # 第二遍从已清除区域的边界继续
			queue.clear()
			for idx: int in w * h:
				if bg[idx] == 1:
					queue.append(idx)
		var head := 0
		while head < queue.size():
			var idx2: int = queue[head]
			head += 1
			var px := idx2 % w
			var py := idx2 / w
			if pass_i == 0 and bg[idx2] == 1:
				continue
			if pass_i == 0:
				if not _bg_like(img.get_pixel(px, py), sat_max):
					continue
				bg[idx2] = 1
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := px + d.x
				var ny := py + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var nidx := ny * w + nx
				if bg[nidx] == 1:
					continue
				if pass_i == 0:
					queue.append(nidx)
				elif _bg_like(img.get_pixel(nx, ny), sat_max):
					bg[nidx] = 1
					queue.append(nidx)
	for y3: int in h:
		for x3: int in w:
			var i3 := y3 * w + x3
			if bg[i3] == 1:
				img.set_pixel(x3, y3, Color(0, 0, 0, 0))
				continue
			var edge := 0 # 羽化：与背景相邻的前景像素半透明
			for d2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ex := x3 + d2.x
				var ey := y3 + d2.y
				if ex >= 0 and ey >= 0 and ex < w and ey < h and bg[ey * w + ex] == 1:
					edge += 1
			if edge > 0:
				var c := img.get_pixel(x3, y3)
				img.set_pixel(x3, y3, Color(c, c.a * (0.75 if edge == 1 else 0.5)))
