# 调色板令牌（docs/en/tech/07-new-game-kit.md §3：theme.palette）：界面颜色按名取，新游戏改清单即换色。
# 缺省值 = 本作现行配色（墨黑 / 金墨 / 纸色）；清单可只覆盖其中几项（"#rrggbb" 或 "#rrggbbaa"）。
class_name Palette
extends RefCounted

const DEFAULTS := {
	"bg": "#0d0d14",        # 屏幕底色
	"panel": "#14141a",     # 面板 / 卡片
	"sheet": "#141419f7",   # 半屏弹层底（不透明，04 §3.3）
	"accent": "#d9bf73",    # 强调色（金墨：边框、选中、标题点缀）
	"accent_soft": "#d9bf7380",
	"text": "#e8e3d6",      # 正文
	"muted": "#a6a29a",     # 次要文字
	"success": "#8fcc8f",
	"danger": "#e65242",
	"ink": "#1a1a2c",       # 骰身 / 深色块
}

static func color(token: String) -> Color:
	var p: Dictionary = (GameManifest.data().get("theme", {}) as Dictionary).get("palette", {})
	var hex := str(p.get(token, DEFAULTS.get(token, "#ff00ff")))
	return Color.from_string(hex, Color.MAGENTA)

## 半屏弹层的统一样式（hub / 营地 / 地图事件卡 / 联络 / 分装 共用）。
static func sheet_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color("sheet")
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.border_width_top = 1
	sb.border_color = color("accent_soft")
	sb.set_content_margin_all(14)
	return sb
