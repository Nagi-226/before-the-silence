extends Node
## GameData (autoload) — 加载与 C++ 版同源的 JSON 配置，注册输入动作，管理共享音效
## 路径绑定: project.godot [autoload]

var player_cfg := {}
var weapons_cfg := []
var weapons_shared_reserve := 90
var weapon_pickup_spawns := []  # [{weapon, map, x, y}] 场景内武器拾取点
var shell_spawns := []  # [{map, x, y}] 12号霰弹补给生成点
var component_levels := []  # [{tier, weapons:{id:{clipSize, damage, auto?}}}] 通用武器升级组件数值表
var component_spawns := []  # [{tier, map, x, y}] 升级组件生成点
var component_fire_rate_add := 0.0  # 每阶组件附加射速提升（合并原神经加速器职能）
var enemy_weapon_cfg := []
var enemies_cfg := {}
var pickups_cfg := {}
var game_cfg := {}
var narrative_cfg := {}
var level_ext_cfg := {}  # P2 地形扩展层（Godot 侧专属配置，不进入 C++ 同源地图）

var pickup_sounds := {}
var sfx := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0

const CFG_DIR := "res://assets/config/"

const SFX_NAMES := [
	"Shoot", "EnemyShoot", "ReloadStart", "ReloadEnd",
	"EnemyHurt", "EnemyDie", "PlayerHurt",
	"UIMove", "UISelect", "Victory", "Defeat",
]


func _ready() -> void:
	player_cfg = _load_json(CFG_DIR + "player.json")
	var weapons := _load_json(CFG_DIR + "weapons.json")
	weapons_cfg = weapons.get("weapons", [])
	weapons_shared_reserve = int(weapons.get("sharedReserve", 90))
	weapon_pickup_spawns = weapons.get("pickupSpawns", [])
	shell_spawns = weapons.get("shellSpawns", [])
	var comps: Dictionary = weapons.get("upgradeComponents", {})
	component_levels = comps.get("levels", [])
	component_spawns = comps.get("spawns", [])
	component_fire_rate_add = float(comps.get("fireRateAdd", 0.0))
	enemy_weapon_cfg = weapons.get("enemyTemplates", [])
	enemies_cfg = _load_json(CFG_DIR + "enemies.json")
	pickups_cfg = _load_json(CFG_DIR + "pickups.json")
	game_cfg = _load_json(CFG_DIR + "game.json")
	narrative_cfg = _load_json(CFG_DIR + "narrative.json")
	level_ext_cfg = _load_json(CFG_DIR + "level_ext.json")
	_setup_sfx_bus()
	_load_sounds()
	_load_sfx()
	_register_actions()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)


func _setup_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("配置缺失: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_warning("配置解析失败: " + path)
	return {}


func _load_sounds() -> void:
	var mapping := {
		"Coin": "res://assets/sounds/Coin.ogg",
		"Health": "res://assets/sounds/Health.ogg",
		"Ammo": "res://assets/sounds/Ammo.ogg",
		"UpgradeHealth": "res://assets/sounds/Upgrade.ogg",
		"UpgradeAmmo": "res://assets/sounds/Upgrade.ogg",
		"UpgradeSpeed": "res://assets/sounds/Energy Orb.ogg",
		"WeaponPickup": "res://assets/sounds/Energy Orb.ogg",
		"WeaponComp": "res://assets/sounds/Upgrade.ogg",
	}
	for key in mapping:
		var stream: Variant = load(mapping[key])
		if stream:
			pickup_sounds[key] = stream


func play_pickup_sound(type_name: String) -> void:
	var stream: AudioStream = pickup_sounds.get(type_name)
	if stream == null:
		return
	_play_on_pool(stream)


func _load_sfx() -> void:
	for n in SFX_NAMES:
		var path := "res://assets/sounds/%s.wav" % n
		if ResourceLoader.exists(path):
			sfx[n] = load(path)


func play_sfx(sfx_name: String) -> void:
	var stream: AudioStream = sfx.get(sfx_name)
	if stream == null:
		return
	_play_on_pool(stream)


func _play_on_pool(stream: AudioStream) -> void:
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = stream
	p.play()


func enemy_templates() -> Array:
	return enemies_cfg.get("templates", [])


func _register_actions() -> void:
	var key_actions := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"reload": KEY_R,
		"weapon_switch": KEY_Q,
	}
	for action in key_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = key_actions[action]
		InputMap.action_add_event(action, ev)
	var wheel_actions := {
		"weapon_next": MOUSE_BUTTON_WHEEL_UP,
		"weapon_prev": MOUSE_BUTTON_WHEEL_DOWN,
	}
	for action in wheel_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var wv := InputEventMouseButton.new()
		wv.button_index = wheel_actions[action]
		InputMap.action_add_event(action, wv)
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mb)
