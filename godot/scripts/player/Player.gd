extends CharacterBody3D
## Player — 移动/视角/射击/换弹/拾取效果/多武器切换
## 数值全部来自 GameData（与 C++ 版 JSON 同源），单位换算经 WorldConst.CELL
## 武器规则: 手枪半自动 / 冲锋枪全自动，1/2 键切换；备弹为共享池（同种手枪弹药）

signal ammo_changed(clip: int, reserve: int)
signal health_changed(current: int, max_hp: int)
signal coins_changed(amount: int)
signal weapon_changed(weapon_name: String, viewmodel: String)
signal hurt
signal died
signal fired
signal reload_started
signal reload_finished

const ProjectileScene := preload("res://scenes/weapons/Projectile.tscn")
const WEAPON_SWITCH_DELAY := 0.3  # 切枪后的射击间隙，模拟掏枪动作

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var projectile_root: Node

var move_speed := 14.0
var mouse_sens := 0.0024
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var health_max := 100
var health_cur := 100
var coins := 0
var ammo_reserve := 90

## 每武器运行时状态: id/displayName/auto/ammoClip/clipSize/fireInterval/damage/
## bulletSpeed/bulletRange/reloadTime/spawnOffset/viewmodel
var weapons: Array[Dictionary] = []
var weapon_index := 0

var _fire_cooldown := 0.0
var _reloading := 0.0
var _base_sens := 0.0024
var _prev_weapon_key := [false, false]  # 1/2 键边沿检测状态（帧率无关的按下沿判定）
var _prev_shoot := false  # 射击键边沿检测（半自动模式用）
var _prev_reload := false  # 换弹键边沿检测

## 兼容访问器: 读写当前武器的弹匣状态（HUD/测试脚本沿用旧字段名）
var ammo_clip: int:
	get: return int(weapons[weapon_index]["ammoClip"])
	set(v): weapons[weapon_index]["ammoClip"] = v

var clip_size: int:
	get: return int(weapons[weapon_index]["clipSize"])
	set(v): weapons[weapon_index]["clipSize"] = v


func _ready() -> void:
	add_to_group("player")
	var pcfg := GameData.player_cfg
	move_speed = float(pcfg.get("moveSpeed", 7.0)) * WorldConst.CELL
	mouse_sens = float(pcfg.get("look", {}).get("sensitivity", 0.03)) * 0.08
	_base_sens = mouse_sens
	health_max = int(pcfg.get("baseHealth", 100))
	health_cur = health_max
	_build_weapons()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ammo_changed.emit(ammo_clip, ammo_reserve)
	health_changed.emit(health_cur, health_max)
	coins_changed.emit(coins)
	weapon_changed.emit(weapon_display_name(), weapon_viewmodel())


func _build_weapons() -> void:
	ammo_reserve = GameData.weapons_shared_reserve
	for cfg in GameData.weapons_cfg:
		var cd: Dictionary = cfg
		weapons.append({
			"id": str(cd.get("id", "")),
			"displayName": str(cd.get("displayName", "武器")),
			"auto": bool(cd.get("auto", false)),
			"ammoClip": int(cd.get("ammoClip", 20)),
			"clipSize": int(cd.get("clipSize", 20)),
			"fireInterval": 1.0 / float(cd.get("fireRate", 10.0)),
			"damage": int(cd.get("damage", 32)),
			"bulletSpeed": float(cd.get("bulletSpeed", 15.0)) * WorldConst.CELL,
			"bulletRange": float(cd.get("bulletRange", 10.0)) * WorldConst.CELL,
			"reloadTime": float(cd.get("reloadTime", 2.0)),
			"spawnOffset": float(cd.get("spawnOffset", 0.5)) * WorldConst.CELL,
			"viewmodel": str(cd.get("viewmodel", "Weapon.png")),
		})
	if weapons.is_empty():  # 配置缺失兜底，保证可运行
		weapons.append({
			"id": "pistol", "displayName": "手枪", "auto": false,
			"ammoClip": 20, "clipSize": 20, "fireInterval": 0.1, "damage": 32,
			"bulletSpeed": 30.0, "bulletRange": 20.0, "reloadTime": 2.0,
			"spawnOffset": 1.0, "viewmodel": "Weapon.png",
		})


func _physics_process(delta: float) -> void:
	velocity.y -= gravity * delta
	var dir2 := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(dir2.x, 0.0, dir2.y)).normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()

	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_process_weapon_switch()
	_process_reload(delta)
	var w: Dictionary = weapons[weapon_index]
	var shoot_pressed := Input.is_action_pressed("shoot")
	var want_fire := shoot_pressed if w["auto"] else (shoot_pressed and not _prev_shoot)
	_prev_shoot = shoot_pressed
	if want_fire and _fire_cooldown <= 0.0:
		_shoot()


func apply_look(relative: Vector2) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var sens := _base_sens * Settings.sensitivity
	rotate_y(-relative.x * sens)
	head.rotate_x(-relative.y * sens)
	var lim := deg_to_rad(WorldConst.PITCH_LIMIT_DEG)
	head.rotation.x = clampf(head.rotation.x, -lim, lim)


func _process_weapon_switch() -> void:
	var keys := [Input.is_action_pressed("weapon_1"), Input.is_action_pressed("weapon_2")]
	var target := -1
	for i in 2:
		if keys[i] and not _prev_weapon_key[i]:
			target = i
	_prev_weapon_key = keys
	if target < 0 or target >= weapons.size() or target == weapon_index:
		return
	weapon_index = target
	_reloading = 0.0  # 切枪打断换弹（备弹尚未转移，无副作用）
	_fire_cooldown = maxf(_fire_cooldown, WEAPON_SWITCH_DELAY)
	weapon_changed.emit(weapon_display_name(), weapon_viewmodel())
	ammo_changed.emit(ammo_clip, ammo_reserve)


func _process_reload(delta: float) -> void:
	var w: Dictionary = weapons[weapon_index]
	if _reloading > 0.0:
		_reloading -= delta
		if _reloading <= 0.0:
			var need := clip_size - ammo_clip
			var take := mini(need, ammo_reserve)
			ammo_clip += take
			ammo_reserve -= take
			ammo_changed.emit(ammo_clip, ammo_reserve)
			reload_finished.emit()
	elif Input.is_action_pressed("reload") and not _prev_reload and ammo_clip < clip_size and ammo_reserve > 0:
		_reloading = float(w["reloadTime"])
		reload_started.emit()
	_prev_reload = Input.is_action_pressed("reload")


func _shoot() -> void:
	if _reloading > 0.0:
		return
	var w: Dictionary = weapons[weapon_index]
	if ammo_clip <= 0:
		if ammo_reserve > 0:
			_reloading = float(w["reloadTime"])
			reload_started.emit()
		return
	ammo_clip -= 1
	_fire_cooldown = float(w["fireInterval"])
	fired.emit()
	var proj: Node3D = ProjectileScene.instantiate()
	proj.from_player = true
	proj.damage = int(w["damage"])
	proj.speed = float(w["bulletSpeed"])
	proj.max_range = float(w["bulletRange"])
	proj.direction = -camera.global_transform.basis.z
	var root := projectile_root if projectile_root else get_tree().root
	root.add_child(proj)
	proj.global_position = camera.global_position - camera.global_transform.basis.z * float(w["spawnOffset"])
	ammo_changed.emit(ammo_clip, ammo_reserve)


func take_damage(amount: int) -> void:
	if health_cur <= 0:
		return
	health_cur = maxi(health_cur - amount, 0)
	hurt.emit()
	health_changed.emit(health_cur, health_max)
	if health_cur <= 0:
		died.emit()


func heal(amount: int) -> void:
	health_cur = mini(health_cur + amount, health_max)
	health_changed.emit(health_cur, health_max)


func add_reserve(amount: int) -> void:
	ammo_reserve += amount
	ammo_changed.emit(ammo_clip, ammo_reserve)


func weapon_display_name() -> String:
	return str(weapons[weapon_index]["displayName"])


func weapon_viewmodel() -> String:
	return str(weapons[weapon_index]["viewmodel"])


## 升级拾取: kind = "Health" / "Ammo" / "Speed"，消耗金币，返回是否生效
## Ammo/Speed 升级作用于全部武器（统一武备体系）
func try_upgrade(kind: String) -> bool:
	var ups: Dictionary = GameData.pickups_cfg.get("upgrades", {})
	var cost: int = int(ups.get("cost", 10))
	if coins < cost:
		return false
	coins -= cost
	match kind:
		"Health":
			var amount := int(ups.get("healthUpgrade", 20))
			health_max += amount
			heal(amount)
		"Ammo":
			var clip_add := int(ups.get("ammoClipUpgrade", 5))
			for w in weapons:
				w["clipSize"] = int(w["clipSize"]) + clip_add
			ammo_reserve += int(ups.get("ammoReserveUpgrade", 10))
			ammo_changed.emit(ammo_clip, ammo_reserve)
		"Speed":
			var add := float(ups.get("fireRateUpgrade", 2.0))
			var cap := float(ups.get("fireRateCap", 20.0))
			for w in weapons:
				var rate := minf(1.0 / float(w["fireInterval"]) + add, cap)
				w["fireInterval"] = 1.0 / rate
	coins_changed.emit(coins)
	return true
