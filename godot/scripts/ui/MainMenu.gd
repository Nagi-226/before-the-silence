extends Control
## MainMenu — 项目主场景：标题 + 新游戏 / 设置 / 退出
## 支持键盘（↑↓ / Enter）与鼠标（悬停 / 点击）双操作

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const SETTINGS_SCENE := "res://scenes/ui/SettingsMenu.tscn"

var _items: Array[Label] = []
var _titles := ["新的行动", "设置", "退出游戏"]
var _actions := ["new", "settings", "quit"]
var _selected := 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(UIStyle.make_background())

	var box := UIStyle.make_center_vbox(10)
	add_child(box)

	var title := UIStyle.make_label("废 墟 侦 察", 46, UIStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := UIStyle.make_label("RETRO FPS · Godot 重制版", 16, UIStyle.DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(UIStyle.make_label(" ", 24))

	for i in _titles.size():
		var item := UIStyle.make_label(_titles[i], 24)
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.mouse_entered.connect(_on_item_hover.bind(i))
		item.gui_input.connect(_on_item_input.bind(i))
		box.add_child(item)
		_items.append(item)

	box.add_child(UIStyle.make_label(" ", 24))
	var hint := UIStyle.make_label("↑↓ 选择 · Enter 确认", 14, UIStyle.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
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
		"new":
			get_tree().change_scene_to_file(MAIN_SCENE)
		"settings":
			get_tree().change_scene_to_file(SETTINGS_SCENE)
		"quit":
			get_tree().quit()
