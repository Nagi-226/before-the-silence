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
var state := "briefing"  # briefing / play / level_end(关卡间结算) / ended
var map_index := 0

var _pause_menu: Node
var _kills := 0
var _pickups_taken := 0
var _start_msec := 0
var _hints := []  # {pos: Vector3, radius: float, text: String, shown: bool}
var _seen_pickup_types := {}
var _enemy_names: Array = []
# B线·转关: campaign 游标与每关统计快照(结算显示本关增量)
var _campaign_cursor := 0
var _level_start := {"kills": 0, "pickups": 0, "shots": 0, "hits": 0}
# B批4·T5: Main.tscn 出厂环境快照(首次应用时抓取), 作无配置关卡的回落基准
var _env_base := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	view_rect.texture = viewport.get_texture()
	player.projectile_root = viewport
	# 起手关: 主菜单经 GameData.pending_start_map 注入(level_ext.campaign.startMap); 未注入(-1)回落 campaign 首关
	# 消费即复位 → SmokeTest 直挂 Main(绕过主菜单)恒从 sequence[0]=map0 起, 回归不受影响
	var seq := _campaign_sequence()
	var start := GameData.pending_start_map
	GameData.pending_start_map = -1
	if start < 0 or not seq.has(start):
		start = int(seq[0])
		_campaign_cursor = 0
	else:
		_campaign_cursor = seq.find(start)  # 对齐游标: 本关通关后正确推进到 sequence 下一关而非循环回本关
	map_index = start
	_apply_environment(map_index)  # B批4·T5: per-map 夜空/雾
	var spawn: Vector3 = level.build(map_index, entities)
	player.global_position = spawn
	hud.setup_minimap(level, player, entities)

	_connect_player()
	_connect_entities()
	level.goal_reached.connect(_on_victory)
	level.breaker_activated.connect(_on_breaker_activated)  # A批6 合闸机制

	_enemy_names = GameData.narrative_cfg.get("enemy_names", [])
	_setup_hints()

	var briefings: Array = GameData.narrative_cfg.get("briefings", [])
	var briefing: Dictionary = briefings[map_index] if map_index < briefings.size() else {}
	hud.show_briefing(briefing)
	get_tree().paused = true


## B线·关卡流程序列(level_ext.campaign.sequence, 缺省单关回退现状行为)
func _campaign_sequence() -> Array:
	var d: Dictionary = GameData.level_ext_cfg.get("campaign", {})
	if d.is_empty():
		return [0]
	return d.get("sequence", [0])


## B批4·T5 环境差异化: 按 map 应用 level_ext.environments 的夜空/雾参数。
## 未命中当前关 → 回落 Main.tscn 出厂值(首次调用时快照, 免与场景文件双份维护)。
## 直接改常驻 Environment/Sky 资源: 转关清场只清 Area3D, WorldEnvironment 不在
## 其列 → 每关无条件重设(含回落), 否则上一关的氛围会残留到下一关。
func _apply_environment(idx: int) -> void:
	var node: WorldEnvironment = viewport.get_node_or_null("WorldEnvironment")
	if node == null or node.environment == null:
		return
	var env := node.environment
	var sky_mat: ProceduralSkyMaterial = null
	if env.sky != null:
		sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	if _env_base.is_empty():
		_env_base = {"fogDensity": env.fog_density, "fogColor": env.fog_light_color}
		if sky_mat != null:
			_env_base["skyTop"] = sky_mat.sky_top_color
			_env_base["skyHorizon"] = sky_mat.sky_horizon_color
			_env_base["groundBottom"] = sky_mat.ground_bottom_color
			_env_base["groundHorizon"] = sky_mat.ground_horizon_color
	var cfg := {}
	for e in GameData.level_ext_cfg.get("environments", []):
		var ed: Dictionary = e
		if int(ed.get("map", -1)) == idx:
			cfg = ed
	env.fog_enabled = true
	env.fog_density = float(cfg.get("fogDensity", _env_base["fogDensity"]))
	env.fog_light_color = _env_color(cfg.get("fogColor"), _env_base["fogColor"])
	if sky_mat == null:
		return
	sky_mat.sky_top_color = _env_color(cfg.get("skyTop"), _env_base["skyTop"])
	sky_mat.sky_horizon_color = _env_color(
		cfg.get("skyHorizon"), _env_base["skyHorizon"])
	sky_mat.ground_bottom_color = _env_color(
		cfg.get("groundBottom"), _env_base["groundBottom"])
	sky_mat.ground_horizon_color = _env_color(
		cfg.get("groundHorizon"), _env_base["groundHorizon"])


## [r, g, b] 数组 → Color; 缺省或畸形(非数组/不足 3 项)则原样回退 fallback
func _env_color(v: Variant, fallback: Color) -> Color:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() < 3:
		return fallback
	var a: Array = v
	return Color(float(a[0]), float(a[1]), float(a[2]))


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
	hud.update_weapon(player.weapon_display_name(), player.weapon_viewmodel(), player.weapon_ammo_type())
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
		# A批6: 可选 floor 字段——按对应楼层墙格校验(层区提示挂层墙格),
		# 触发时同样要求玩家楼层匹配(跨层不串响)
		var hfloor := maxi(1, int(hd.get("floor", 1)))
		if level.is_wall(gx, gy, hfloor):
			continue
		_hints.append({
			"pos": Vector3((gx + 0.5) * WorldConst.CELL, 0.0, (gy + 0.5) * WorldConst.CELL),
			"radius": float(hd.get("radius", 4)) * WorldConst.CELL,
			"text": str(hd.get("text", "")),
			"floor": hfloor,
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
	elif state == "level_end":
		# B线·关卡间结算: Enter 进入下一关 / R 重打本关 / ESC 返回主菜单
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ENTER:
				_advance_level()
			elif event.physical_keycode == KEY_R:
				_restart()
			elif event.physical_keycode == KEY_ESCAPE:
				_go_main_menu()
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
	# A批6: 常驻目标行——有闸图按供电状态给口径, 无闸图不显示(零硬编码)
	if level.has_gate():
		hud.set_objective(_gate_text("objectivePowered" if level.gate_powered else "objectiveLocked"))
	else:
		hud.set_objective("")
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_msec = Time.get_ticks_msec()
	# B线·每关统计快照(结算显示本关增量: 击杀/拾取/命中率/用时)
	_level_start = {
		"kills": _kills,
		"pickups": _pickups_taken,
		"shots": player.shots_fired,
		"hits": player.hits_landed,
	}
	GameData.play_sfx("UISelect")


func _process(_delta: float) -> void:
	if state != "play" or get_tree().paused:
		return
	_update_enemy_name()
	_update_hints()
	# A批6: 走进触发(配电箱等 wallDecals 交互点, 零新按键)
	level.tick_interactables(player.global_position,
		WorldConst.floor_at_y(player.global_position.y))


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
	var pfloor := WorldConst.floor_at_y(player.global_position.y)
	for h in _hints:
		if h.shown:
			continue
		if int(h.get("floor", 1)) != pfloor:
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


## A批6 · 合闸机制: 配电箱触发 → toast + 目标行切换(文案全走 narrative.json gate 段)
func _on_breaker_activated() -> void:
	hud.show_toast(_gate_text("toastPowered"), 3.5)
	hud.set_objective(_gate_text("objectivePowered"))


## A批6: 取 narrative.gate 段文案(仅当其 map 命中当前关; 否则空串)
func _gate_text(key: String) -> String:
	var g: Dictionary = GameData.narrative_cfg.get("gate", {})
	if g.is_empty() or int(g.get("map", -1)) != map_index:
		return ""
	return str(g.get(key, ""))


func _on_victory() -> void:
	if game_over:
		return
	# A批6 · 撤离闭锁: 有闸图未通电时触旗不判通关(旗不消, 通电后可再触)
	if level.has_gate() and not level.gate_powered:
		hud.show_toast(_gate_text("toastLocked"), 3.5)
		GameData.play_sfx("UIMove")
		return
	game_over = true
	get_tree().paused = true
	GameData.play_sfx("Victory")
	var victories: Array = GameData.narrative_cfg.get("victory", [])
	var story: String = str(victories[map_index]) if map_index < victories.size() else ""
	# B线·转关: 流程还有下一关 → 关卡间结算态(level_end); 最终关 → 终局结算(ended)
	var has_next: bool = _campaign_cursor + 1 < _campaign_sequence().size()
	if has_next:
		state = "level_end"
		hud.show_end(true, story, _stats_text(), true)
	else:
		state = "ended"
		hud.show_end(true, story, _stats_text())


## B线·转关: 场景内重建下一关(保留 Player 实例 → 武器/升级/备弹/生命天然跨关保留,
## 免序列化)。清场(实体/关卡几何/残留弹道) → 重建 → 重连信号 → 下一关简报。
func _advance_level() -> void:
	if state != "level_end":
		return
	var seq := _campaign_sequence()
	_campaign_cursor += 1
	if _campaign_cursor >= seq.size():
		return
	for c in entities.get_children():
		c.queue_free()
	for c in level.get_children():
		c.queue_free()
	for c in viewport.get_children():
		if c is Area3D:  # 清残留弹道(Projectile); 固定子树(Level/Entities/Player/环境)不受影响
			c.queue_free()
	await get_tree().physics_frame

	map_index = int(seq[_campaign_cursor])
	_apply_environment(map_index)  # B批4·T5: 每关重设, 防上一关氛围残留
	var spawn: Vector3 = level.build(map_index, entities)
	player.global_position = spawn
	player.velocity = Vector3.ZERO
	# 跨关保留策略(拍板B2): 武器/升级/备弹/生命原样保留, 弹匣自动补满
	for i in player.weapons.size():
		player.weapons[i]["ammoClip"] = int(player.weapons[i]["clipSize"])
	player.ammo_changed.emit(player.ammo_clip, player.ammo_reserve)

	hud.dismiss_end()
	hud.setup_minimap(level, player, entities)
	_connect_entities()
	_setup_hints()
	game_over = false
	state = "briefing"
	_start_msec = 0  # 待 dismiss_briefing 重置并做本关统计快照
	var briefings: Array = GameData.narrative_cfg.get("briefings", [])
	var briefing: Dictionary = briefings[map_index] if map_index < briefings.size() else {}
	hud.show_briefing(briefing)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
	# B线·每关独立统计(关卡开始时快照的增量); 命中率=命中数/击发数(霰弹一发=一次)
	var kills := _kills - int(_level_start["kills"])
	var picks := _pickups_taken - int(_level_start["pickups"])
	var acc := "-"
	var shots: int = player.shots_fired - int(_level_start["shots"])
	if shots > 0:
		var hits: int = player.hits_landed - int(_level_start["hits"])
		acc = "%d%%" % roundi(float(hits) / float(shots) * 100.0)
	@warning_ignore("integer_division")
	return "击杀 %d · 命中率 %s · 拾取 %d · 用时 %02d:%02d" % [kills, acc, picks, secs / 60, secs % 60]


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
