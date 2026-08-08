extends CanvasLayer
## HUD — 只读显示游戏状态（遵守 C++ 版 ui-code 规则: UI 不修改游戏状态）
## 中文使用系统字体 微软雅黑，避免打包 CJK 字体文件

@onready var crosshair: TextureRect = $Crosshair
@onready var ammo_label: Label = $AmmoLabel
@onready var health_label: Label = $HealthLabel
@onready var coin_label: Label = $CoinLabel
@onready var hurt_rect: ColorRect = $HurtRect
@onready var end_panel: PanelContainer = $EndPanel
@onready var end_title: Label = $EndPanel/VBox/TitleLabel
@onready var end_hint: Label = $EndPanel/VBox/HintLabel

var _hurt_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "sans-serif"])
	for label in [ammo_label, health_label, coin_label, end_title, end_hint]:
		label.add_theme_font_override("font", font)


func update_ammo(clip: int, reserve: int) -> void:
	ammo_label.text = "弹药  %d / %d" % [clip, reserve]


func update_health(current: int, max_hp: int) -> void:
	health_label.text = "生命  %d / %d" % [current, max_hp]


func update_coins(amount: int) -> void:
	coin_label.text = "金币  %d" % amount


func show_hurt() -> void:
	if _hurt_tween and _hurt_tween.is_running():
		_hurt_tween.kill()
	hurt_rect.modulate.a = 1.0
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(hurt_rect, "modulate:a", 0.0, 0.3)


func show_end(victory: bool) -> void:
	crosshair.visible = false
	end_panel.visible = true
	if victory:
		end_title.text = "任务完成"
		end_hint.text = "按 Enter 重新挑战  ·  按 ESC 退出"
	else:
		end_title.text = "你阵亡了"
		end_hint.text = "按 Enter 重新挑战  ·  按 ESC 退出"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
