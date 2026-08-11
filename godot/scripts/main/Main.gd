extends Control
## Main — 组装 SubViewport 复古呈现层（240×135 → 最近邻放大）与游戏世界
## 复古呈现核心: 低分辨率渲染目标 + Nearest 过滤 + 环境雾模拟距离阴影
## 产品层流程: briefing(简报) → play(游玩+暂停菜单) → ended(叙事结算)

const PauseScene := preload("res://scenes/ui/PauseMenu.tscn")
const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

@onready var viewport: SubViewport = $Viewport
@onready var view_rect: TextureRect = $ViewRect
@onready var level: Node3D = $Viewport/Level
@onready var entities: Node3D = $Viewport/Entities
@onready var player: CharacterBody3D = $Viewport/Player
@onready var hud: CanvasLayer = $HUD

var game_over := false
var state := "briefing"  # briefing / play / ended
var map_index := 0

var _pause_menu: Node
var _kills := 0
var _pickups_taken := 0
var _start_msec := 0
var _hints := []  # {pos: Vector3, radius: float, text: String, shown: bool}
var _seen_pickup_types := {}
var _enemy_names: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	view_rect.texture = viewport.get_texture()
	player.projectile_root = viewport
	var spawn: Vector3 = level.build(map_index, entities)
	player.global_position = spawn
	hud.setup_minimap(level, player, entities)

	_connect_player()
	_connect_entities()
	level.goal_reached.connect(_on_victory)

	_enemy_names = GameData.narrative_cfg.get("enemy_names", [])
	_setup_hints()

	var briefings: Array = GameData.narrative_cfg.get("briefings", [])
	var briefing: Dictionary = briefings[map_index] if map_index < briefings.size() else {}
	hud.show_briefing(briefing)
	get_tree().paused = true


func _connect_player() -> void:
	player.ammo_changed.connect(hud.update_ammo)
	player.health_changed.connect(hud.update_health)
	player.armor_changed.connect(hud.update_armor)
	player.coins_changed.connect(hud.update_coins)
	player.weapon_changed.connect(hud.update_weapon)
	player.hurt.connect(func():
		hud.show_hurt()
		GameData.play_sfx("PlayerHurt"))
	player.died.connect(_on_defeat)
	player.fired.connect(func():
		GameData.play_sfx("Shoot")
		hud.play_weapon_fire())
	player.pump_started.connect(func(duration: float):
		GameData.play_sfx("ReloadStart")
		hud.play_weapon_pump(duration))
	player.reload_started.connect(func():
		GameData.play_sfx("ReloadStart")
		hud.play_weapon_reload(player.weapon_id(), player.weapon_reload_time()))
	player.reload_finished.connect(func():
		GameData.play_sfx("ReloadEnd")
		hud.finish_weapon_reload())
	player.component_rejected.connect(func(needed: int):
		const TIER_NAMES := {1: "一级", 2: "二级", 3: "三级"}
		if needed > 3:
			hud.show_toast("武器改装已完成（三级组件上限）")
		else:
			hud.show_toast("组件不兼容：需要先获得%s武器升级组件" % TIER_NAMES.get(needed, "上一级")))
	player.pickup_hint.connect(func(text: String): hud.show_toast(text))
	# Player._ready 先于本函数执行，初始信号已丢失——主动同步一次 HUD
	hud.update_weapon(player.weapon_display_name(), player.weapon_viewmodel())
	hud.update_ammo(player.ammo_clip, player.ammo_reserve)
	hud.update_health(player.health_cur, player.health_max)
	hud.update_armor(player.armor_cur, player.armor_max)
	hud.update_coins(player.coins)


func _connect_entities() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.died.connect(_on_enemy_died)
		e.hurt.connect(func(): GameData.play_sfx("EnemyHurt"))
		e.fired.connect(func(): GameData.play_sfx("EnemyShoot"))
	for p in get_tree().get_nodes_in_group("pickups"):
		p.collected.connect(_on_pickup_collected)


func _setup_hints() -> void:
	var hints_cfg: Array = GameData.narrative_cfg.get("area_hints", [])
	for h in hints_cfg:
		var hd: Dictionary = h
		if int(hd.get("map", 0)) != map_index:
			continue
		var gx := int(hd.get("x", 0))
		var gy := int(hd.get("y", 0))
		if level.is_wall(gx, gy):
			continue
		_hints.append({
			"pos": Vector3((gx + 0.5) * WorldConst.CELL, 0.0, (gy + 0.5) * WorldConst.CELL),
			"radius": float(hd.get("radius", 4)) * WorldConst.CELL,
			"text": str(hd.get("text", "")),
			"shown": false,
		})


func _unhandled_input(event: InputEvent) -> void:
	if state == "briefing":
		if (event is InputEventKey and event.pressed and not event.echo) \
				or (event is InputEventMouseButton and event.pressed):
			dismiss_briefing()
	elif state == "play":
		if event is InputEventMouseMotion:
			player.apply_look(event.relative)
		elif event.is_action_pressed("weapon_switch") or event.is_action_pressed("weapon_next"):
			player.cycle_weapon(1)
		elif event.is_action_pressed("weapon_prev"):
			player.cycle_weapon(-1)
		elif event.is_action_pressed("ui_cancel"):
			_open_pause()
	elif state == "ended":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_R:
				_restart()
			elif event.physical_keycode == KEY_ESCAPE:
				_go_main_menu()


func dismiss_briefing() -> void:
	if state != "briefing":
		return
	state = "play"
	hud.dismiss_briefing()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_msec = Time.get_ticks_msec()
	GameData.play_sfx("UISelect")


func _process(_delta: float) -> void:
	if state != "play" or get_tree().paused:
		return
	_update_enemy_name()
	_update_hints()


func _update_enemy_name() -> void:
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 30.0
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	var hit: Dictionary = space.intersect_ray(query)
	if hit and hit.collider.is_in_group("enemies"):
		var tid: int = hit.collider.template_id
		if tid < _enemy_names.size():
			hud.set_enemy_name(str(_enemy_names[tid]))
			return
	hud.set_enemy_name("")


func _update_hints() -> void:
	var flat := Vector3(player.global_position.x, 0.0, player.global_position.z)
	for h in _hints:
		if h.shown:
			continue
		if flat.distance_to(h.pos) <= h.radius:
			h.shown = true
			hud.show_toast(str(h.text), 3.5)
			GameData.play_sfx("UIMove")


func _open_pause() -> void:
	_pause_menu = PauseScene.instantiate()
	add_child(_pause_menu)
	_pause_menu.resumed.connect(_close_pause)
	_pause_menu.restart_requested.connect(func():
		_close_pause()
		_restart())
	_pause_menu.quit_requested.connect(func():
		_close_pause()
		_go_main_menu())
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_pause() -> void:
	if _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_pickup_collected(symbol: String) -> void:
	_pickups_taken += 1
	if not _seen_pickup_types.has(symbol):
		_seen_pickup_types[symbol] = true
		var descs: Dictionary = GameData.narrative_cfg.get("pickup_descriptions", {})
		if descs.has(symbol):
			hud.show_toast(str(descs[symbol]))


func _on_enemy_died() -> void:
	_kills += 1
	GameData.play_sfx("EnemyDie")


func _on_victory() -> void:
	if game_over:
		return
	game_over = true
	state = "ended"
	get_tree().paused = true
	GameData.play_sfx("Victory")
	var victories: Array = GameData.narrative_cfg.get("victory", [])
	var story: String = str(victories[map_index]) if map_index < victories.size() else ""
	hud.show_end(true, story, _stats_text())


func _on_defeat() -> void:
	if game_over:
		return
	game_over = true
	state = "ended"
	get_tree().paused = true
	GameData.play_sfx("Defeat")
	var defeat: Dictionary = GameData.narrative_cfg.get("defeat", {})
	hud.show_end(false, str(defeat.get("text", "")), _stats_text())


func _stats_text() -> String:
	var secs := int((Time.get_ticks_msec() - _start_msec) / 1000.0) if _start_msec > 0 else 0
	@warning_ignore("integer_division")
	return "击杀 %d · 拾取 %d · 用时 %02d:%02d" % [_kills, _pickups_taken, secs / 60, secs % 60]


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
