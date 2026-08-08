extends Control
## Main — 组装 SubViewport 复古呈现层（240×135 → 最近邻放大）与游戏世界
## 复古呈现核心: 低分辨率渲染目标 + Nearest 过滤 + 环境雾模拟距离阴影

@onready var viewport: SubViewport = $Viewport
@onready var view_rect: TextureRect = $ViewRect
@onready var level: Node3D = $Viewport/Level
@onready var entities: Node3D = $Viewport/Entities
@onready var player: CharacterBody3D = $Viewport/Player
@onready var hud: CanvasLayer = $HUD

var game_over := false


func _ready() -> void:
	view_rect.texture = viewport.get_texture()
	player.projectile_root = viewport
	var spawn: Vector3 = level.build(0, entities)
	player.global_position = spawn

	player.ammo_changed.connect(hud.update_ammo)
	player.health_changed.connect(hud.update_health)
	player.coins_changed.connect(hud.update_coins)
	player.hurt.connect(hud.show_hurt)
	player.died.connect(_on_defeat)
	level.goal_reached.connect(_on_victory)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	elif game_over and event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()


func _on_victory() -> void:
	game_over = true
	get_tree().paused = true
	hud.show_end(true)


func _on_defeat() -> void:
	game_over = true
	get_tree().paused = true
	hud.show_end(false)
