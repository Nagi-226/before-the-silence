extends CharacterBody3D
## Player — 移动/视角/射击/换弹/拾取效果
## 数值全部来自 GameData（与 C++ 版 JSON 同源），单位换算经 WorldConst.CELL

signal ammo_changed(clip: int, reserve: int)
signal health_changed(current: int, max_hp: int)
signal coins_changed(amount: int)
signal hurt
signal died
signal fired
signal reload_started
signal reload_finished

const ProjectileScene := preload("res://scenes/weapons/Projectile.tscn")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var projectile_root: Node

var move_speed := 14.0
var mouse_sens := 0.0024
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var health_max := 20
var health_cur := 20
var coins := 0
var ammo_clip := 30
var ammo_reserve := 90
var clip_size := 30
var fire_interval := 0.1
var fire_damage := 1
var bullet_speed := 30.0
var bullet_range := 20.0
var spawn_offset := 1.0
var reload_time := 2.0

var _fire_cooldown := 0.0
var _reloading := 0.0
var _base_sens := 0.0024


func _ready() -> void:
	add_to_group("player")
	var pcfg := GameData.player_cfg
	var wcfg := GameData.weapon_cfg
	move_speed = float(pcfg.get("moveSpeed", 7.0)) * WorldConst.CELL
	mouse_sens = float(pcfg.get("look", {}).get("sensitivity", 0.03)) * 0.08
	_base_sens = mouse_sens
	health_max = int(pcfg.get("baseHealth", 20))
	health_cur = health_max
	ammo_clip = int(wcfg.get("ammoClip", 30))
	ammo_reserve = int(wcfg.get("ammoReserve", 90))
	clip_size = int(wcfg.get("clipSize", 30))
	fire_interval = 1.0 / float(wcfg.get("fireRate", 10.0))
	fire_damage = int(wcfg.get("damage", 1))
	bullet_speed = float(wcfg.get("bulletSpeed", 15.0)) * WorldConst.CELL
	bullet_range = float(wcfg.get("bulletRange", 10.0)) * WorldConst.CELL
	spawn_offset = float(wcfg.get("spawnOffset", 0.5)) * WorldConst.CELL
	reload_time = float(wcfg.get("reloadTime", 2.0))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ammo_changed.emit(ammo_clip, ammo_reserve)
	health_changed.emit(health_cur, health_max)
	coins_changed.emit(coins)


func _physics_process(delta: float) -> void:
	velocity.y -= gravity * delta
	var dir2 := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(dir2.x, 0.0, dir2.y)).normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()

	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_process_reload(delta)
	if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		_shoot()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := _base_sens * Settings.sensitivity
		rotate_y(-event.relative.x * sens)
		head.rotate_x(-event.relative.y * sens)
		var lim := deg_to_rad(WorldConst.PITCH_LIMIT_DEG)
		head.rotation.x = clampf(head.rotation.x, -lim, lim)


func _process_reload(delta: float) -> void:
	if _reloading > 0.0:
		_reloading -= delta
		if _reloading <= 0.0:
			var need := clip_size - ammo_clip
			var take := mini(need, ammo_reserve)
			ammo_clip += take
			ammo_reserve -= take
			ammo_changed.emit(ammo_clip, ammo_reserve)
			reload_finished.emit()
	elif Input.is_action_just_pressed("reload") and ammo_clip < clip_size and ammo_reserve > 0:
		_reloading = reload_time
		reload_started.emit()


func _shoot() -> void:
	if _reloading > 0.0:
		return
	if ammo_clip <= 0:
		if ammo_reserve > 0:
			_reloading = reload_time
			reload_started.emit()
		return
	ammo_clip -= 1
	_fire_cooldown = fire_interval
	fired.emit()
	var proj: Node3D = ProjectileScene.instantiate()
	proj.from_player = true
	proj.damage = fire_damage
	proj.speed = bullet_speed
	proj.max_range = bullet_range
	proj.direction = -camera.global_transform.basis.z
	var root := projectile_root if projectile_root else get_tree().root
	root.add_child(proj)
	proj.global_position = camera.global_position - camera.global_transform.basis.z * spawn_offset
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


## 升级拾取: kind = "Health" / "Ammo" / "Speed"，消耗金币，返回是否生效
func try_upgrade(kind: String) -> bool:
	var ups: Dictionary = GameData.pickups_cfg.get("upgrades", {})
	var cost: int = int(ups.get("cost", 10))
	if coins < cost:
		return false
	coins -= cost
	match kind:
		"Health":
			health_max += int(ups.get("healthUpgrade", 5))
			heal(int(ups.get("healthUpgrade", 5)))
		"Ammo":
			clip_size += int(ups.get("ammoClipUpgrade", 5))
			ammo_reserve += int(ups.get("ammoReserveUpgrade", 10))
			ammo_changed.emit(ammo_clip, ammo_reserve)
		"Speed":
			var new_rate := minf(1.0 / fire_interval + float(ups.get("fireRateUpgrade", 2.0)),
				float(ups.get("fireRateCap", 20.0)))
			fire_interval = 1.0 / new_rate
	coins_changed.emit(coins)
	return true
