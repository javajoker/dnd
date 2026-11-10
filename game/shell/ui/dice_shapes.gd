# 多面骰几何表（docs/en/framework/17-polyhedral-dice-spec.md §2/§6）
# 纯数据：顶点 / 面（多边形，外法线绕序）/ 面值 / 读数规则——Dice3D 据此建网格、碰撞、编号与落定对齐。
# - d6 / d8 / d10 / d12 / d20：读"顶面"，对面和恒为 N+1（标准编号）；
# - d4：四面体顶面朝上时没有"顶面"——读"顶点"（标准 d4 读顶尖数字），每个顶点一个值；
# - d10：五角偏方面体（风筝面），上下环高度按共面条件求解；d12：二十面体对偶（面心即十二面体顶点）。
# 零引擎依赖（只用 Vector3 / 数组），测试可直接断言几何与编号。
class_name DiceShapes
extends RefCounted

const KINDS: Array[String] = ["d4", "d6", "d8", "d10", "d12", "d20"]

## 构建一种骰子。返回 {die, sides, read ("face"|"vertex"), verts[], faces[[idx…]], normals[],
## values[]（face 读法 = 每面值；vertex 读法 = 每顶点值）, value_index{值: 面/顶点索引}, dirs[]（读数方向）}。
static func build(die: String, radius: float = 0.62) -> Dictionary:
	var raw: Array = []
	var faces: Array = []
	match die:
		"d4":
			raw = [Vector3(1, 1, 1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1)]
			faces = [[0, 1, 2], [0, 3, 1], [0, 2, 3], [1, 3, 2]]
		"d6":
			for x: int in [-1, 1]:
				for y: int in [-1, 1]:
					for z: int in [-1, 1]:
						raw.append(Vector3(x, y, z))
			faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
		"d8":
			raw = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
			for a: int in [0, 1]:
				for b: int in [2, 3]:
					for c: int in [4, 5]:
						faces.append([a, b, c])
		"d10":
			var z := 0.105
			var cos36 := cos(deg_to_rad(36.0))
			var h := z * (1.0 + cos36) / (1.0 - cos36) # 风筝面共面条件
			raw.append(Vector3(0, h, 0))  # 0 上顶
			raw.append(Vector3(0, -h, 0)) # 1 下顶
			for k: int in 5:
				var au := deg_to_rad(72.0 * k)
				var al := deg_to_rad(72.0 * k + 36.0)
				raw.append(Vector3(cos(au), z, sin(au)))   # 2+2k 上环
				raw.append(Vector3(cos(al), -z, sin(al)))  # 3+2k 下环
			for k: int in 5:
				var u := 2 + 2 * k
				var l := 3 + 2 * k
				var un := 2 + 2 * ((k + 1) % 5)
				var ln := 3 + 2 * ((k + 1) % 5)
				faces.append([0, u, l, un])   # 上风筝
				faces.append([1, l, un, ln])  # 下风筝
		"d12":
			var ico := _icosahedron()
			var iv: Array = ico["verts"]
			var ifaces: Array = ico["faces"]
			for f: Array in ifaces:
				raw.append(((iv[f[0]] as Vector3) + (iv[f[1]] as Vector3) + (iv[f[2]] as Vector3)) / 3.0)
			for vi: int in iv.size():
				var ring: Array = []
				for fi: int in ifaces.size():
					if (ifaces[fi] as Array).has(vi):
						ring.append(fi)
				faces.append(_sort_around(ring, raw, (iv[vi] as Vector3).normalized()))
		_:
			var ico2 := _icosahedron()
			raw = ico2["verts"]
			faces = ico2["faces"]
	var verts: Array = []
	var far := 0.0
	for v: Vector3 in raw:
		far = maxf(far, v.length())
	for v: Vector3 in raw:
		verts.append(v / far * radius)
	var normals: Array = []
	var out_faces: Array = []
	for f: Array in faces:
		var poly: Array = f.duplicate()
		var n := _poly_normal(poly, verts)
		if n.dot(_centroid(poly, verts)) < 0.0: # 绕序翻正：法线朝外
			poly.reverse()
			n = -n
		out_faces.append(poly)
		normals.append(n)
	var shape := {"die": die if KINDS.has(die) else "d20", "verts": verts, "faces": out_faces, "normals": normals}
	if die == "d4":
		shape["read"] = "vertex"
		shape["sides"] = 4
		var dirs: Array = []
		var values: Array = []
		var vi_map := {}
		for i: int in verts.size():
			dirs.append((verts[i] as Vector3).normalized())
			values.append(i + 1)
			vi_map[i + 1] = i
		shape["dirs"] = dirs
		shape["values"] = values
		shape["value_index"] = vi_map
	else:
		shape["read"] = "face"
		shape["sides"] = out_faces.size()
		shape["dirs"] = normals
		_number_opposites(shape)
	return shape

## 对面配对编号：第 k 对取 (k+1, N-k)，对面和 N+1。
static func _number_opposites(shape: Dictionary) -> void:
	var normals: Array = shape["normals"]
	var n := normals.size()
	var values: Array = []
	values.resize(n)
	var index := {}
	var used: Array = []
	used.resize(n)
	used.fill(false)
	var pair := 0
	for i: int in n:
		if used[i]:
			continue
		var j := -1
		var best := 0.0
		for k: int in n:
			if k != i and not used[k]:
				var d := (normals[i] as Vector3).dot(normals[k])
				if d < best:
					best = d
					j = k
		used[i] = true
		values[i] = pair + 1
		index[pair + 1] = i
		if j >= 0 and best < -0.99:
			used[j] = true
			values[j] = n - pair
			index[n - pair] = j
		pair += 1
	shape["values"] = values
	shape["value_index"] = index

## 读数方向（世界系下 +Y 最大者即读数）：face = 面法线；vertex = 顶点方向。
static func reading(shape: Dictionary, basis: Basis) -> int:
	var dirs: Array = shape["dirs"]
	var best := -1
	var best_y := -2.0
	for i: int in dirs.size():
		var y := (basis * (dirs[i] as Vector3)).y
		if y > best_y:
			best_y = y
			best = i
	return int((shape["values"] as Array)[best]) if best >= 0 else -1

## 编号合规：1..N 各一次；有对面者和为 N+1（d4 读顶点，无对面约束）。
static func values_valid(shape: Dictionary) -> bool:
	var n := int(shape["sides"])
	var values: Array = shape["values"]
	if values.size() != n:
		return false
	for v: int in range(1, n + 1):
		if not values.has(v):
			return false
	if str(shape["read"]) == "vertex":
		return true
	var normals: Array = shape["normals"]
	for i: int in n:
		for k: int in n:
			if k != i and (normals[i] as Vector3).dot(normals[k]) < -0.99 and int(values[i]) + int(values[k]) != n + 1:
				return false
	return true

## 面是否共面（网格/碰撞正确性的几何前提；风筝面与五边形面测试用）。
static func faces_planar(shape: Dictionary, eps: float = 0.002) -> bool:
	var verts: Array = shape["verts"]
	for fi: int in (shape["faces"] as Array).size():
		var poly: Array = shape["faces"][fi]
		var n: Vector3 = shape["normals"][fi]
		var d := n.dot(verts[poly[0]])
		for idx: Variant in poly:
			if absf(n.dot(verts[idx]) - d) > eps:
				return false
	return true

## 内切距离（面心到中心；数字贴面高度用）。
static func face_center(shape: Dictionary, fi: int) -> Vector3:
	return _centroid(shape["faces"][fi], shape["verts"])

static func _icosahedron() -> Dictionary:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	return {"verts": verts, "faces": faces}

static func _centroid(poly: Array, verts: Array) -> Vector3:
	var c := Vector3.ZERO
	for i: Variant in poly:
		c += verts[i]
	return c / float(poly.size())

static func _poly_normal(poly: Array, verts: Array) -> Vector3:
	var n := Vector3.ZERO # Newell 法：任意凸多边形稳定
	for i: int in poly.size():
		var a: Vector3 = verts[poly[i]]
		var b: Vector3 = verts[poly[(i + 1) % poly.size()]]
		n.x += (a.y - b.y) * (a.z + b.z)
		n.y += (a.z - b.z) * (a.x + b.x)
		n.z += (a.x - b.x) * (a.y + b.y)
	return n.normalized()

## 绕轴排序（十二面体五边形顶点按角度成环）。
static func _sort_around(idx: Array, pts: Array, axis: Vector3) -> Array:
	var ref := (pts[idx[0]] as Vector3) - axis * axis.dot(pts[idx[0]])
	ref = ref.normalized()
	var side := axis.cross(ref)
	var withang: Array = []
	for i: Variant in idx:
		var p: Vector3 = pts[i]
		var q := p - axis * axis.dot(p)
		withang.append([atan2(q.dot(side), q.dot(ref)), i])
	withang.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return withang.map(func(e: Array) -> int: return int(e[1]))
