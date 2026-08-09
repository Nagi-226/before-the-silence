extends CharacterBody3D
## Player — 移动/视角/射击/换弹/拾取效果/多武器切换
## 数值全部来自 GameData（与 C++ 版 JSON 同源），单位换算经 WorldConst.CELL
## 武器规则: 初始仅持手枪，冲锋枪需在场景内拾取获得；
##           Q/鼠标滚轮在已持有武器间循环切换；备弹为共享池（同种手枪弹药）

signal ammo_changed(clip: int, reserve: int)
signal health_changed(current: int, max_hp: int)
signal armor_changed(current: int, max_armor: int)
signal coins_changed(amount: int)
signal weapon_changed(weapon_name: String, viewmodel: String)
signal component_rejected(needed_tier: int)
signal pickup_hint(text: String)
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
var armor_max := 100
var armor_cur := 0  # 防护服能量：先于生命承受伤害（1:1 吸收）
var coins := 0
var ammo_reserve := 90

## 每武器运行时状态: id/displayName/auto/ammoClip/clipSize/fireInterval/damage/
## bulletSpeed/bulletRange/reloadTime/spawnOffset/viewmodel
var weapons: Array[Dictionary] = []
var weapon_index := 0
var weapon_owned: Array = []  # 与 weapons 平行；未持有的武器不参与切换循环
var weapon_tier := 0  # 通用升级组件等级 0/1/2，作用于全部武器（统一武备体系）

var _fire_cooldown := 0.0
var _reloading := 0.0
var _base_sens := 0.0024
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
	armor_max = int(pcfg.get("armorMax", 100))
	armor_cur = int(pcfg.get("baseArmor", 0))
	_build_weapons()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ammo_changed.emit(ammo_clip, ammo_reserve)
	health_changed.emit(health_cur, health_max)
	armor_changed.emit(armor_cur, armor_max)
	coins_changed.emit(coins)
	weapon_changed.emit(weapon_display_name(), weapon_viewmodel())


func _build_weapons() -> void:
	ammo_reserve = GameData.weapons_shared_reserve
	for i in GameData.weapons_cfg.size():
		var cd: Dictionary = GameData.weapons_cfg[i]
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
		weapon_owned.append(bool(cd.get("owned", i == 0)))
	if weapons.is_empty():  # 配置缺失兜底，保证可运行
		weapons.append({
			"id": "pistol", "displayName": "手枪", "auto": false,
			"ammoClip": 20, "clipSize": 20, "fireInterval": 0.1, "damage": 32,
			"bulletSpeed": 30.0, "bulletRange": 20.0, "reloadTime": 2.0,
			"spawnOffset": 1.0, "viewmodel": "Weapon.png",
		})
		weapon_owned.append(true)


func _physics_process(delta: float) -> void:
	velocity.y -= gravity * delta
	var dir2 := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(dir2.x, 0.0, dir2.y)).normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()

	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
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


## 在已持有武器间循环切换（dir=±1）。事件驱动：Main 转发 Q/滚轮输入
func cycle_weapon(dir: int) -> void:
	var owned_idx: Array = []
	for i in weapons.size():
		if weapon_owned[i]:
			owned_idx.append(i)
	if owned_idx.size() < 2:
		return
	var cur := owned_idx.find(weapon_index)
	if cur < 0:
		cur = 0
	var next: int = owned_idx[(cur + dir + owned_idx.size()) % owned_idx.size()]
	_switch_to(next)


func _switch_to(idx: int) -> void:
	if idx < 0 or idx >= weapons.size() or idx == weapon_index:
		return
	weapon_index = idx
	_reloading = 0.0  # 切枪打断换弹（备弹尚未转移，无副作用）
	_fire_cooldown = maxf(_fire_cooldown, WEAPON_SWITCH_DELAY)
	weapon_changed.emit(weapon_display_name(), weapon_viewmodel())
	ammo_changed.emit(ammo_clip, ammo_reserve)


## 武器拾取: 首拾获得该武器（弹匣补满并自动切换，返回 true）；
## 重复拾取转为备弹（weaponPickupAmmo），返回 false
func grant_weapon(id: String) -> bool:
	for i in weapons.size():
		if str(weapons[i]["id"]) != id:
			continue
		if weapon_owned[i]:
			var amounts: Dictionary = GameData.pickups_cfg.get("amounts", {})
			add_reserve(int(amounts.get("weaponPickupAmmo", 30)))
			return false
		weapon_owned[i] = true
		weapons[i]["ammoClip"] = int(weapons[i]["clipSize"])
		_switch_to(i)
		return true
	return false


## 通用武器升级组件: tier=1/2/3 需按顺序获取，三级为改装上限。
## 生效则按 weapons.json upgradeComponents.levels 表改写全部武器的
## clipSize/damage/auto 并返回 true；顺序不符或满级则发 component_rejected
## 并返回 false（拾取物保留原地，玩家可稍后回来取）
func apply_weapon_component(tier: int) -> bool:
	if tier != weapon_tier + 1:
		component_rejected.emit(weapon_tier + 1)
		return false
	if tier < 1 or tier > GameData.component_levels.size():
		return false
	weapon_tier = tier
	var table: Dictionary = (GameData.component_levels[tier - 1] as Dictionary).get("weapons", {})
	var rate_add := GameData.component_fire_rate_add
	for w in weapons:
		var entry: Variant = table.get(str(w["id"]))
		if entry is Dictionary:
			w["clipSize"] = int(entry.get("clipSize", w["clipSize"]))
			w["damage"] = int(entry.get("damage", w["damage"]))
			w["auto"] = bool(entry.get("auto", w["auto"]))
		if rate_add > 0.0:
			w["fireInterval"] = 1.0 / (1.0 / float(w["fireInterval"]) + rate_add)
	ammo_changed.emit(ammo_clip, ammo_reserve)
	return true


## 弹匣绝对上限: 组件等级表最高阶的 clipSize（缺配时不设限）
func clip_cap_for(weapon_id: String) -> int:
	var cap := 999
	for lv in GameData.component_levels:
		var entry: Variant = (lv as Dictionary).get("weapons", {}).get(weapon_id)
		if entry is Dictionary and entry.has("clipSize"):
			cap = int(entry["clipSize"])
	return cap


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
	# 防护服能量先于生命承受伤害（1:1 吸收，溢出部分扣生命）
	if armor_cur > 0:
		var absorbed := mini(armor_cur, amount)
		armor_cur -= absorbed
		amount -= absorbed
		armor_changed.emit(armor_cur, armor_max)
	health_cur = maxi(health_cur - amount, 0)
	hurt.emit()
	health_changed.emit(health_cur, health_max)
	if health_cur <= 0:
		died.emit()


func heal(amount: int) -> void:
	health_cur = mini(health_cur + amount, health_max)
	health_changed.emit(health_cur, health_max)


## 急救包拾取: 生命已满时拒收（拾取物保留原地，避免浪费地图资源）
func try_heal(amount: int) -> bool:
	if health_cur >= health_max:
		pickup_hint.emit("生命值已满")
		return false
	heal(amount)
	return true


## 防护服能量补给拾取: 满能量时拒收（同急救包规则）
func try_add_armor(amount: int) -> bool:
	if armor_cur >= armor_max:
		pickup_hint.emit("防护服能量已满")
		return false
	armor_cur = mini(armor_cur + amount, armor_max)
	armor_changed.emit(armor_cur, armor_max)
	return true


func add_reserve(amount: int) -> void:
	ammo_reserve += amount
	ammo_changed.emit(ammo_clip, ammo_reserve)


func weapon_display_name() -> String:
	return str(weapons[weapon_index]["displayName"])


func weapon_viewmodel() -> String:
	return str(weapons[weapon_index]["viewmodel"])


## 升级拾取: kind = "Health" / "Ammo" / "Speed"，消耗金币，返回是否生效
## Ammo/Speed 升级作用于全部武器（统一武备体系）
## Ammo 弹匣增长钳制在组件最高阶 clipSize（33/60 顶头）；全部到顶则拒收
func try_upgrade(kind: String) -> bool:
	var ups: Dictionary = GameData.pickups_cfg.get("upgrades", {})
	var cost: int = int(ups.get("cost", 10))
	if coins < cost:
		return false
	if kind == "Ammo":
		var clip_add_check := int(ups.get("ammoClipUpgrade", 5))
		var any_growth := false
		for w in weapons:
			if int(w["clipSize"]) < clip_cap_for(str(w["id"])):
				any_growth = true
		if not any_growth:
			pickup_hint.emit("弹匣已达改装上限，扩展弹匣保留在原地")
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
				var cap := clip_cap_for(str(w["id"]))
				w["clipSize"] = mini(int(w["clipSize"]) + clip_add, cap)
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
