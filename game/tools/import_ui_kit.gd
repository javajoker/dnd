# UI 套件导入（docs/en/tech/05 §10）：把美术交付的大尺寸框体（如 1024² 带透明留白）处理成游戏可用的九宫格：
#   1) 按不透明区域裁掉留白；2) 缩放到屏幕尺度（九宫格四角按纹理原像素绘制，必须先缩到合适大小）；
#   3) 写 ui_kit.json 边距表（UiKit 读取：外部框体用表里的九宫格边距）。
# 用法：godot --headless --path game -s tools/import_ui_kit.gd -- <源目录> [输出目录=res://assets/art/ui]
# 规格表 SPEC：目标尺寸（w/h；0 = 按比例）+ 边距（占目标尺寸的比例 l/t/r/b）——按美术稿角饰大小定。
extends SceneTree

const SPEC := {
	"button": {"w": 64, "h": 64, "m": [0.25, 0.25, 0.25, 0.25]},
	"button_hover": {"w": 64, "h": 64, "m": [0.25, 0.25, 0.25, 0.25]},
	"button_pressed": {"w": 64, "h": 64, "m": [0.25, 0.25, 0.25, 0.25]},
	"button_disabled": {"w": 64, "h": 64, "m": [0.25, 0.25, 0.25, 0.25]},
	"panel": {"w": 160, "h": 160, "m": [0.24, 0.24, 0.24, 0.24]},
	"sheet": {"w": 160, "h": 160, "m": [0.24, 0.26, 0.24, 0.12]},
	"toast": {"w": 0, "h": 44, "m": [0.24, 0.45, 0.24, 0.45]},
	"field": {"w": 64, "h": 64, "m": [0.2, 0.2, 0.2, 0.2]},
	"tooltip": {"w": 64, "h": 64, "m": [0.2, 0.2, 0.2, 0.2]},
	"track": {"w": 0, "h": 18, "m": [0.1, 0.45, 0.1, 0.45]},
	"fill": {"w": 0, "h": 18, "m": [0.1, 0.45, 0.1, 0.45]},
	"grabber": {"w": 0, "h": 28, "m": [0.45, 0.4, 0.45, 0.4]},
}

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		push_error("用法：-s tools/import_ui_kit.gd -- <源目录> [输出目录]")
		quit(1)
		return
	var src: String = a[0]
	var out: String = a[1] if a.size() > 1 else ProjectSettings.globalize_path("res://assets/art/ui")
	DirAccess.make_dir_recursive_absolute(out)
	var table := {}
	for name: String in SPEC:
		var path := src.path_join("ui_%s.png" % name)
		if not FileAccess.file_exists(path):
			print("[ui_kit] 缺 %s（保持程序化框体）" % name)
			continue
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGBA8)
		var box := img.get_used_rect() # 不透明区域（裁掉留白）
		img = img.get_region(box)
		var sp: Dictionary = SPEC[name]
		var h := int(sp["h"])
		var w := int(sp["w"]) if int(sp["w"]) > 0 else maxi(1, int(round(img.get_width() * h / float(img.get_height()))))
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
		img.save_png(out.path_join("ui_%s.png" % name))
		var m: Array = sp["m"]
		table[name] = [round(w * float(m[0])), round(h * float(m[1])), round(w * float(m[2])), round(h * float(m[3]))]
		print("[ui_kit] %s：裁 %s → %dx%d 边距 %s" % [name, box, w, h, table[name]])
	var f := FileAccess.open(out.path_join("ui_kit.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(table, "  ") + "\n")
	f.close()
	quit()
