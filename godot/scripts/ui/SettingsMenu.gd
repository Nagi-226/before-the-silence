extends Control
## SettingsMenu — 双模式设置界面
## overlay_mode=false: 从主菜单进入的完整场景，返回=切回主菜单
## overlay_mode=true : 从暂停菜单实例化的覆盖层，返回=发出 closed 信号

signal closed

@export var overlay_mode := false

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

var _fullscreen_box: CheckBox


func _ready() -> void:
	add_child(UIStyle.make_background(
		Color(0.02, 0.025, 0.045, 1.0) if not overlay_mode
		else Color(0.02, 0.025, 0.045, 0.96)))

	var box := UIStyle.make_center_vbox(14)
	add_child(box)

	var title := UIStyle.make_label("设 置", 34, UIStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UIStyle.make_label(" ", 16))

	box.add_child(_make_slider_row("主音量", 0.0, 1.0, 0.05,
		Settings.master_volume, func(v: float): Settings.set_master_volume(v)))
	box.add_child(_make_slider_row("音效音量", 0.0, 1.0, 0.05,
		Settings.sfx_volume, func(v: float): Settings.set_sfx_volume(v)))
	box.add_child(_make_slider_row("鼠标灵敏度", 0.5, 2.0, 0.1,
		Settings.sensitivity, func(v: float): Settings.set_sensitivity(v)))

	var fs_row := HBoxContainer.new()
	fs_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fs_row.add_theme_constant_override("separation", 10)
	var fs_label := UIStyle.make_label("全屏显示", 20)
	fs_row.add_child(fs_label)
	_fullscreen_box = CheckBox.new()
	_fullscreen_box.button_pressed = Settings.fullscreen
	_fullscreen_box.toggled.connect(func(on: bool): Settings.set_fullscreen(on))
	fs_row.add_child(_fullscreen_box)
	box.add_child(fs_row)

	box.add_child(UIStyle.make_label(" ", 16))
	var back := UIStyle.make_label("    返  回", 24)
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.mouse_entered.connect(func():
		back.add_theme_color_override("font_color", UIStyle.ACCENT))
	back.mouse_exited.connect(func():
		back.add_theme_color_override("font_color", UIStyle.TEXT))
	back.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_go_back())
	box.add_child(back)


func _make_slider_row(label_text: String, min_v: float, max_v: float,
		step: float, initial: float, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(UIStyle.make_label(label_text, 20))
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(260, 0)
	var value_label := UIStyle.make_label(_format(initial), 16, UIStyle.DIM)
	value_label.custom_minimum_size = Vector2(56, 0)
	slider.value_changed.connect(func(v: float):
		value_label.text = _format(v)
		setter.call(v))
	row.add_child(slider)
	row.add_child(value_label)
	return row


func _format(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _go_back() -> void:
	GameData.play_sfx("UISelect")
	if overlay_mode:
		closed.emit()
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
