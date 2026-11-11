# 场景背景（tech/05 §11）：幕插画铺在故事 / 战斗主视野之后（等比铺满、压暗保证文字可读）。
# 双壳同一组件；数据 = 幕的 art_ref（nodes.json acts[].art_ref，如 "scenes/act_1"）；缺图 = 隐藏。
class_name SceneBackdrop
extends TextureRect

const TIER := 1080
const DIM_STORY := 0.55   # 故事态：插画清晰些（文字另有半透明底）
const DIM_BATTLE := 0.3   # 战斗态：压得更暗，单位卡在前

var current_ref := ""

func _init() -> void:
	name = "SceneBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	visible = false

## 设置幕插画与压暗度；ref 为空或缺图 = 隐藏。
func show_scene(ref: String, dim: float) -> void:
	if ref != current_ref:
		current_ref = ref
		texture = ArtLoader.texture_for(ref, TIER) if ref != "" else null
	visible = texture != null
	self_modulate = Color(dim, dim, dim * 1.05)

## 故事文本的半透明底板（压在插画上可读）。
static func text_backing() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.04, 0.55)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	return sb
