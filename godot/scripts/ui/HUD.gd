extends CanvasLayer
## HUD — 只读显示游戏状态（遵守 C++ 版 ui-code 规则: UI 不修改游戏状态）
## 叙事呈现: 开局简报层 / 拾取与区域 toast / 准星敌人名 / 结算叙事与统计
## 中文使用系统字体 微软雅黑，避免打包 CJK 字体文件

const MiniMapScript := preload("res://scripts/ui/MiniMap.gd")

@onready var crosshair: TextureRect = $Crosshair
@onready var ammo_label: Label = $AmmoLabel
@onready var health_label: Label = $HealthLabel
@onready var armor_label: Label = $ArmorLabel
@onready var coin_label: Label = $CoinLabel
@onready var hurt_rect: ColorRect = $HurtRect
@onready var weapon_rect: TextureRect = $WeaponRect
@onready var end_panel: PanelContainer = $EndPanel
@onready var end_title: Label = $EndPanel/VBox/TitleLabel
@onready var end_hint: Label = $EndPanel/VBox/HintLabel
@onready var end_vbox: VBoxContainer = $EndPanel/VBox

var _weapon_name := "手枪"

var _briefing_root: Control
var _briefing_blink: Tween
var _toast: Label
var _toast_tween: Tween
var _enemy_name: Label
var _end_story: Label
var _end_stats: Label
var _hurt_tween: Tween
var _weapon_tween: Tween
var _weapon_base_position := Vector2.ZERO
var _weapon_base_rotation := 0.0
var _weapon_base_scale := Vector2.ONE
var _weapon_id := "pistol"
var _weapon_anim_state := "idle"
var _reload_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "sans-serif"])
	for label in [ammo_label, health_label, armor_label, coin_label, end_title, end_hint]:
		label.add_theme_font_override("font", font)
	_build_narrative_ui()
	_weapon_base_position = weapon_rect.position
	_weapon_base_rotation = weapon_rect.rotation
	_weapon_base_scale = weapon_rect.scale
	weapon_rect.pivot_offset = weapon_rect.size * Vector2(0.5, 0.82)
	_build_weapon_feedback(font)


func _build_narrative_ui() -> void:
	# 准星下方敌人名
	_enemy_name = UIStyle.make_label("", 16, UIStyle.ACCENT)
	_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_name.set_anchors_preset(Control.PRESET_CENTER)
	_enemy_name.position = Vector2(-160, 14)
	_enemy_name.size = Vector2(320, 24)
	_enemy_name.visible = false
	add_child(_enemy_name)

	# 屏幕下方提示 toast
	_toast = UIStyle.make_label("", 17, UIStyle.TEXT)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.position = Vector2(-320, 120)
	_toast.size = Vector2(640, 60)
	_toast.visible = false
	add_child(_toast)

	# 结算面板: 叙事文本 + 统计（插在标题与提示之间）
	_end_story = UIStyle.make_label("", 15, UIStyle.DIM)
	_end_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_vbox.add_child(_end_story)
	end_vbox.move_child(_end_story, 1)
	_end_stats = UIStyle.make_label("", 16, UIStyle.TEXT)
	_end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_vbox.add_child(_end_stats)
	end_vbox.move_child(_end_stats, 2)


func _build_weapon_feedback(font: Font) -> void:
	_reload_label = Label.new()
	_reload_label.add_theme_font_override("font", font)
	_reload_label.add_theme_font_size_override("font_size", 16)
	_reload_label.add_theme_color_override("font_color", UIStyle.ACCENT)
	_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reload_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_reload_label.position = Vector2(-150, -206)
	_reload_label.size = Vector2(300, 28)
	_reload_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_label.visible = false
	add_child(_reload_label)


func update_ammo(clip: int, reserve: int) -> void:
	ammo_label.text = "%s  弹药  %d / %d" % [_weapon_name, clip, reserve]


func update_weapon(weapon_name: String, viewmodel: String) -> void:
	_weapon_name = weapon_name
	var vm := viewmodel.to_lower()
	if vm.contains("shotgun"):
		_weapon_id = "shotgun"
	elif vm.contains("smg"):
		_weapon_id = "smg"
	else:
		_weapon_id = "pistol"
	_reset_weapon_pose()
	var path := "res://assets/images/" + viewmodel
	if ResourceLoader.exists(path):
		weapon_rect.texture = load(path)


func play_weapon_fire() -> void:
	if _weapon_anim_state == "reload":
		return
	if _weapon_tween and _weapon_tween.is_valid():
		_weapon_tween.kill()
	_weapon_anim_state = "fire"
	var kick := Vector2(3.0, 16.0) if _weapon_id == "pistol" else Vector2(-2.0, 9.0)
	var turn := -0.055 if _weapon_id == "pistol" else 0.025
	weapon_rect.position = _weapon_base_position + kick
	weapon_rect.rotation = _weapon_base_rotation + turn
	weapon_rect.scale = _weapon_base_scale * Vector2(1.04, 0.96)
	_weapon_tween = create_tween().set_parallel(true)
	_weapon_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_weapon_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_weapon_tween.tween_property(weapon_rect, "position", _weapon_base_position, 0.11)
	_weapon_tween.tween_property(weapon_rect, "rotation", _weapon_base_rotation, 0.11)
	_weapon_tween.tween_property(weapon_rect, "scale", _weapon_base_scale, 0.11)
	_weapon_tween.chain().tween_callback(func(): _weapon_anim_state = "idle")


## 泵动式霰弹枪：击发后下拉-回推的上膛动作（DOOM 式节奏）。
## 二阶组件后转半自动/全自动，Player 不再发 pump_started，本函数即不再触发。
func play_weapon_pump(duration: float) -> void:
	if _weapon_anim_state == "reload":
		return
	if _weapon_tween and _weapon_tween.is_valid():
		_weapon_tween.kill()
	_weapon_anim_state = "pump"
	var down := _weapon_base_position + Vector2(6.0, 22.0)
	var half := clampf(duration * 0.45, 0.08, 0.3)
	_weapon_tween = create_tween()
	_weapon_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_weapon_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_weapon_tween.tween_property(weapon_rect, "position", down, half)
	_weapon_tween.parallel().tween_property(weapon_rect, "rotation", _weapon_base_rotation + 0.06, half)
	_weapon_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_weapon_tween.tween_property(weapon_rect, "position", _weapon_base_position, half)
	_weapon_tween.parallel().tween_property(weapon_rect, "rotation", _weapon_base_rotation, half)
	_weapon_tween.tween_callback(func(): _weapon_anim_state = "idle")


## 两把武器使用不同轮廓的换弹动作，后续可无缝替换为逐帧手部素材。
func play_weapon_reload(weapon_id: String, duration: float) -> void:
	if _weapon_tween and _weapon_tween.is_valid():
		_weapon_tween.kill()
	_weapon_id = weapon_id
	_weapon_anim_state = "reload"
	_reload_label.text = "%s · 装填霰弹" % _weapon_name if weapon_id == "shotgun" else "%s · 更换弹匣" % _weapon_name
	_reload_label.visible = true
	_reload_label.modulate.a = 1.0
	_weapon_tween = create_tween()
	_weapon_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	if weapon_id == "smg":
		_weapon_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_weapon_tween.tween_property(weapon_rect, "position", _weapon_base_position + Vector2(-82, 92), duration * 0.28)
		_weapon_tween.parallel().tween_property(weapon_rect, "rotation", -0.28, duration * 0.28)
		_weapon_tween.tween_property(weapon_rect, "position", _weapon_base_position + Vector2(74, 78), duration * 0.34)
		_weapon_tween.parallel().tween_property(weapon_rect, "rotation", 0.2, duration * 0.34)
	else:
		_weapon_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		_weapon_tween.tween_property(weapon_rect, "position", _weapon_base_position + Vector2(58, 56), duration * 0.3)
		_weapon_tween.parallel().tween_property(weapon_rect, "rotation", 0.72, duration * 0.3)
		_weapon_tween.tween_property(weapon_rect, "position", _weapon_base_position + Vector2(35, 74), duration * 0.3)
		_weapon_tween.parallel().tween_property(weapon_rect, "rotation", 0.42, duration * 0.3)
	_weapon_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_weapon_tween.tween_property(weapon_rect, "position", _weapon_base_position, duration * 0.38)
	_weapon_tween.parallel().tween_property(weapon_rect, "rotation", _weapon_base_rotation, duration * 0.38)
	_weapon_tween.tween_callback(_finish_weapon_reload_visual)


func finish_weapon_reload() -> void:
	if _weapon_anim_state == "reload":
		if _weapon_tween and _weapon_tween.is_valid():
			_weapon_tween.kill()
		_finish_weapon_reload_visual()


func is_weapon_reloading() -> bool:
	return _weapon_anim_state == "reload"


func _finish_weapon_reload_visual() -> void:
	_weapon_anim_state = "idle"
	_reload_label.visible = false
	weapon_rect.position = _weapon_base_position
	weapon_rect.rotation = _weapon_base_rotation
	weapon_rect.scale = _weapon_base_scale


func _reset_weapon_pose() -> void:
	if _weapon_tween and _weapon_tween.is_valid():
		_weapon_tween.kill()
	_weapon_anim_state = "idle"
	if _reload_label:
		_reload_label.visible = false
	weapon_rect.position = _weapon_base_position
	weapon_rect.rotation = _weapon_base_rotation
	weapon_rect.scale = _weapon_base_scale


func update_health(current: int, max_hp: int) -> void:
	health_label.text = "生命  %d / %d" % [current, max_hp]


func update_armor(current: int, max_armor: int) -> void:
	armor_label.text = "防护  %d / %d" % [current, max_armor]


func update_coins(amount: int) -> void:
	coin_label.text = "金币  %d" % amount


## 右上角小地图: Main 在关卡构建后注入数据引用
func setup_minimap(level: Node, player: Node3D, entities: Node3D) -> void:
	var mm: Control = MiniMapScript.new()
	mm.name = "MiniMap"
	add_child(mm)
	mm.setup(level, player, entities)


func show_hurt() -> void:
	if _hurt_tween and _hurt_tween.is_running():
		_hurt_tween.kill()
	hurt_rect.modulate.a = 1.0
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(hurt_rect, "modulate:a", 0.0, 0.3)


## 开局简报（游戏暂停时显示，任意键由 Main 转发 dismiss）
func show_briefing(data: Dictionary) -> void:
	_briefing_root = ColorRect.new()
	_briefing_root.color = Color(0.01, 0.012, 0.03, 0.93)
	_briefing_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_briefing_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_briefing_root)

	var box := UIStyle.make_center_vbox(14)
	_briefing_root.add_child(box)

	var title := UIStyle.make_label(str(data.get("title", "行动简报")), 30, UIStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UIStyle.make_label(" ", 14))
	for line in data.get("lines", []):
		var l := UIStyle.make_label(str(line), 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	box.add_child(UIStyle.make_label(" ", 14))
	var hint := UIStyle.make_label("—— 按任意键开始行动 ——", 16, UIStyle.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var blink := create_tween().set_loops()
	blink.tween_property(hint, "modulate:a", 0.25, 0.8)
	blink.tween_property(hint, "modulate:a", 1.0, 0.8)
	_briefing_blink = blink


func dismiss_briefing() -> void:
	if _briefing_blink and _briefing_blink.is_valid():
		_briefing_blink.kill()
	_briefing_blink = null
	if _briefing_root:
		_briefing_root.queue_free()
		_briefing_root = null


func show_toast(text: String, dur: float = 2.4) -> void:
	if _toast_tween and _toast_tween.is_running():
		_toast_tween.kill()
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(dur)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func(): _toast.visible = false)


func set_enemy_name(text: String) -> void:
	_enemy_name.visible = text != ""
	if _enemy_name.text != text:
		_enemy_name.text = text


func show_end(victory: bool, story: String, stats_text: String) -> void:
	crosshair.visible = false
	_enemy_name.visible = false
	_toast.visible = false
	dismiss_briefing()
	end_panel.visible = true
	end_title.text = "任务完成" if victory else "你阵亡了"
	_end_story.text = story
	_end_stats.text = stats_text
	end_hint.text = "按 Enter 重新挑战  ·  按 ESC 返回主菜单"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
