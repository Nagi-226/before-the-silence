extends CanvasLayer
## PauseMenu — 游戏内暂停层（process_mode=ALWAYS，暂停时仍可交互）
## 继续 / 重新开始 / 设置 / 返回主菜单；ESC 切换开关

signal resumed
signal restart_requested
signal quit_requested

const SETTINGS_SCENE := preload("res://scenes/ui/SettingsMenu.tscn")

var _items: Array[Label] = []
var _titles := ["继续行动", "重新开始", "设置", "返回主菜单"]
var _actions := ["resume", "restart", "settings", "quit"]
var _selected := 0
var _settings_open := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var box := UIStyle.make_center_vbox(10)
	add_child(box)

	var title := UIStyle.make_label("行 动 暂 停", 32, UIStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UIStyle.make_label(" ", 18))

	for i in _titles.size():
		var item := UIStyle.make_label(_titles[i], 24)
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.mouse_entered.connect(_on_item_hover.bind(i))
		item.gui_input.connect(_on_item_input.bind(i))
		box.add_child(item)
		_items.append(item)

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _settings_open:
		return
	if event.is_action_pressed("ui_cancel"):
		resumed.emit()
	elif event.is_action_pressed("ui_up"):
		_selected = (_selected + _items.size() - 1) % _items.size()
		_refresh()
		GameData.play_sfx("UIMove")
	elif event.is_action_pressed("ui_down"):
		_selected = (_selected + 1) % _items.size()
		_refresh()
		GameData.play_sfx("UIMove")
	elif event.is_action_pressed("ui_accept"):
		_activate(_selected)


func _on_item_hover(index: int) -> void:
	if _selected != index:
		_selected = index
		_refresh()


func _on_item_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_activate(index)


func _refresh() -> void:
	for i in _items.size():
		var sel := i == _selected
		_items[i].text = (UIStyle.SELECT_PREFIX if sel else UIStyle.NORMAL_PREFIX) + _titles[i]
		_items[i].add_theme_color_override("font_color",
			UIStyle.ACCENT if sel else UIStyle.TEXT)


func _activate(index: int) -> void:
	GameData.play_sfx("UISelect")
	match _actions[index]:
		"resume":
			resumed.emit()
		"restart":
			restart_requested.emit()
		"settings":
			_open_settings()
		"quit":
			quit_requested.emit()


func _open_settings() -> void:
	_settings_open = true
	var settings: Control = SETTINGS_SCENE.instantiate()
	settings.overlay_mode = true
	settings.closed.connect(func():
		settings.queue_free()
		_settings_open = false)
	add_child(settings)
