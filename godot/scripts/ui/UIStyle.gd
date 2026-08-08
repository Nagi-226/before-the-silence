class_name UIStyle
## UIStyle — 菜单/HUD 共用的复古 UI 样式与构建工具
## 中文使用系统字体微软雅黑，避免打包 CJK 字体文件

const BG_COLOR := Color(0.04, 0.045, 0.07)
const ACCENT := Color(0.95, 0.75, 0.3)
const TEXT := Color(0.85, 0.87, 0.9)
const DIM := Color(0.55, 0.58, 0.65)
const SELECT_PREFIX := "▶ "
const NORMAL_PREFIX := "    "


static func make_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "sans-serif"])
	return f


static func make_label(text: String, size: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", make_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 全屏深色底
static func make_background(color: Color = BG_COLOR) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


## 居中容器
static func make_center_vbox(spacing: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", spacing)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box
