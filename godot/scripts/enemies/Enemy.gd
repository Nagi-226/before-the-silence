extends CharacterBody3D
## Enemy — 三种敌人共用，按 template_id 从 enemies.json 取数值
## AI: 侦测范围内追踪玩家，进入攻击范围停下开火（对应 C++ EnemyAISystem 简化版）

signal died
signal hurt
signal fired

const ProjectileScene := preload("res://scenes/weapons/Projectile.tscn")

## 玩家原点离地高(胶囊中心): 敌原点在脚底(Enemy.tscn CollisionShape y=0.8/高1.6)。
## 垂直差比较前先校准到同一脚部基准, 阈值语义才是纯地形高差
const PLAYER_ORIGIN_LIFT := 0.65

const PIXEL_SIZES := [0.0225, 0.02875, 0.0375]  # 小/中/大 体型 (64px AE-219 精灵, 值=米/像素, 世界高度与旧32px版一致)

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var flash_timer: Timer = $FlashTimer
@onready var attack_timer: Timer = $AttackTimer

var template_id := 0
var projectile_root: Node

var health := 1
var detection_range := 16.0
var attack_range := 4.0
var detection_vertical_tolerance := 1.5  # 垂直差阈值(米): |dy|超此值不侦测不追击不攻击(隔层防误侦测)
var move_speed := 5.0
var fire_damage := 1
var fire_interval := 0.5
var bullet_speed := 16.0
var is_dying := false

# AE-219 双攻击模式: "spore"=仅远程喷孢子, "melee_spore"=近战+远程双模式
var attack_mode := "spore"
var melee_range := 0.0        # <=0 表示无近战（米）
var melee_damage := 0
var melee_interval := 1.0

var _fire_cooldown := 0.0
var _melee_cooldown := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _base_modulate := Color.WHITE
var _idle_texture: Texture2D
var _attack_texture: Texture2D       # 旧式单攻击帧（缺失双帧时的优雅降级）
var _attack_melee_texture: Texture2D # " Attack Melee.png" 近战帧
var _attack_spore_texture: Texture2D # " Attack Spore.png" 喷/掷孢子帧
var _projectile_texture: Texture2D   # 孢子投射物贴图（缺失则沿用球形弹）
var _projectile_pixel_size := 0.0
var _sprite_base_pos := Vector3(0, 0.9, 0)
var _sprite_base_scale := Vector3.ONE
var _hurt_tween: Tween
var _death_tween: Tween


func _ready() -> void:
	add_to_group("enemies")
	var templates := GameData.enemy_templates()
	if template_id >= templates.size():
		push_warning("敌人模板越界: %d" % template_id)
		queue_free()
		return
	var t: Dictionary = templates[template_id]
	health = int(t.get("health", 1))
	detection_range = float(t.get("detectionRange", 8.0)) * WorldConst.CELL
	attack_range = float(t.get("attackRange", 2.0)) * WorldConst.CELL
	detection_vertical_tolerance = maxf(float(t.get("detectionVerticalTolerance", 1.5)), 0.0)
	move_speed = float(t.get("moveSpeed", 2.5)) * WorldConst.CELL
	attack_mode = str(t.get("attackMode", "spore"))
	melee_range = float(t.get("meleeRange", 0.0)) * WorldConst.CELL
	melee_damage = int(t.get("meleeDamage", 0))
	melee_interval = float(t.get("meleeInterval", 1.0))

	var tex_file: String = t.get("textureFile", "")
	var tex_path := "res://assets/sprites/" + tex_file.get_basename() + ".png"
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	_idle_texture = sprite.texture
	var base := tex_file.get_basename()
	var attack_path := "res://assets/sprites/" + base + " Attack.png"
	if ResourceLoader.exists(attack_path):
		_attack_texture = load(attack_path)
	var melee_path := "res://assets/sprites/" + base + " Attack Melee.png"
	if ResourceLoader.exists(melee_path):
		_attack_melee_texture = load(melee_path)
	var spore_path := "res://assets/sprites/" + base + " Attack Spore.png"
	if ResourceLoader.exists(spore_path):
		_attack_spore_texture = load(spore_path)
	var proj_file: String = t.get("projectileSprite", "")
	if proj_file != "":
		var proj_path := "res://assets/sprites/" + proj_file.get_basename() + ".png"
		if ResourceLoader.exists(proj_path):
			_projectile_texture = load(proj_path)
			_projectile_pixel_size = float(t.get("projectilePixelSize", 0.015))
	sprite.pixel_size = PIXEL_SIZES[clampi(template_id, 0, 2)]
	_base_modulate = sprite.modulate
	_sprite_base_pos = sprite.position
	_sprite_base_scale = sprite.scale

	if template_id < GameData.enemy_weapon_cfg.size():
		var w: Dictionary = GameData.enemy_weapon_cfg[template_id]
		fire_damage = int(w.get("damage", 1))
		# C++ 语义: fireRate 为每秒射击数, cooldown = 1/fireRate (PureLogic.h)
		fire_interval = 1.0 / float(w.get("fireRate", 1.0))
		bullet_speed = float(w.get("bulletSpeed", 8.0)) * WorldConst.CELL


func _physics_process(delta: float) -> void:
	if is_dying:
		velocity = Vector3.ZERO
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	velocity.y -= _gravity * delta
	var to_player := player.global_position - global_position
	var dy := absf((player.global_position.y - PLAYER_ORIGIN_LIFT) - global_position.y)
	to_player.y = 0.0
	var dist := to_player.length()

	if dy > detection_vertical_tolerance:
		# 隔层防护: 垂直差超阈值(楼板/高差阻隔)——不侦测不追击不攻击
		velocity.x = 0.0
		velocity.z = 0.0
	elif dist <= detection_range and dist > attack_range:
		var dir := to_player.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	elif dist <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		if melee_range > 0.0 and dist <= melee_range:
			# 贴身时改爪击（双模式敌人）
			_melee_cooldown -= delta
			if _melee_cooldown <= 0.0:
				_melee_at(player)
				_melee_cooldown = melee_interval
		else:
			_fire_cooldown -= delta
			if _fire_cooldown <= 0.0:
				_shoot_at(player)
				_fire_cooldown = fire_interval
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


## 近战爪击: 换近战帧 + 直接对玩家结算伤害（无弹道，贴脸判定）
func _melee_at(player: Node3D) -> void:
	fired.emit()
	_enter_attack_pose("melee")
	if player.has_method("take_damage"):
		player.take_damage(melee_damage)


func _shoot_at(player: Node3D) -> void:
	fired.emit()
	_enter_attack_pose("spore")
	var proj: Node3D = ProjectileScene.instantiate()
	proj.from_player = false
	proj.damage = fire_damage
	proj.speed = bullet_speed
	proj.max_range = detection_range + WorldConst.CELL * 2
	if _projectile_texture:
		proj.spore_texture = _projectile_texture
		proj.spore_pixel_size = _projectile_pixel_size
	var root := projectile_root if projectile_root else get_tree().root
	root.add_child(proj)
	var muzzle := global_position + Vector3(0, WorldConst.EYE_HEIGHT * 0.8, 0)
	proj.global_position = muzzle
	var target: Vector3 = player.global_position + Vector3(0, 0.65, 0)
	proj.direction = (target - muzzle).normalized()


## DOOM 式攻击帧: 攻击瞬间换对应贴图并后座，短暂停顿后还原。
## kind: "spore"=喷/掷孢子帧, "melee"=近战爪击帧; 双帧缺失时回退旧式单攻击帧
func _enter_attack_pose(kind: String = "spore") -> void:
	var tex: Texture2D
	if kind == "melee":
		tex = _attack_melee_texture if _attack_melee_texture else _attack_texture
	else:
		tex = _attack_spore_texture if _attack_spore_texture else _attack_texture
	if tex:
		sprite.texture = tex
	sprite.position = _sprite_base_pos + Vector3(0.0, -0.04, 0.0)
	var pose_time := float(GameData.enemies_cfg.get("feedback", {}).get("attackPoseTime", 0.18))
	attack_timer.start(pose_time)


func _on_attack_timer_timeout() -> void:
	if _idle_texture:
		sprite.texture = _idle_texture
	sprite.position = _sprite_base_pos


func take_damage(amount: int) -> void:
	if is_dying:
		return
	health -= amount
	sprite.modulate = Color(4.0, 4.0, 4.0)  # 受击白闪
	if health <= 0:
		health = 0
		_start_death()
	else:
		_play_hurt_recoil()
		flash_timer.start(float(GameData.enemies_cfg.get("feedback", {}).get("hurtFlashTime", 0.2)))
		hurt.emit()


func _play_hurt_recoil() -> void:
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	var kick := float(GameData.enemies_cfg.get("feedback", {}).get("hurtKick", 0.1))
	sprite.position = _sprite_base_pos + Vector3(0.0, kick, 0.0)
	sprite.scale = _sprite_base_scale * Vector3(1.12, 0.9, 1.0)
	_hurt_tween = create_tween().set_parallel(true)
	_hurt_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hurt_tween.tween_property(sprite, "position", _sprite_base_pos, 0.16)
	_hurt_tween.tween_property(sprite, "scale", _sprite_base_scale, 0.16)


## 复古街机式死亡表现：击杀反馈 -> 倒地压扁 -> 尸体停留 -> 闪烁淡出。
func _start_death() -> void:
	is_dying = true
	died.emit()
	flash_timer.stop()
	attack_timer.stop()
	collision_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()

	var feedback: Dictionary = GameData.enemies_cfg.get("feedback", {})
	var fall_time := float(feedback.get("deathFallTime", 0.34))
	var corpse_time := float(feedback.get("corpseStayTime", 1.25))
	var blink_time := float(feedback.get("corpseBlinkTime", 0.55))
	var fade_time := float(feedback.get("deathFadeTime", 0.4))
	var fall_dir := -1.0 if int(absf(global_position.x / WorldConst.CELL)) % 2 == 0 else 1.0

	_death_tween = create_tween()
	_death_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(sprite, "rotation:z", fall_dir * 1.3, fall_time)
	_death_tween.parallel().tween_property(sprite, "position", _sprite_base_pos + Vector3(0.0, -0.55, 0.0), fall_time)
	_death_tween.parallel().tween_property(sprite, "scale", _sprite_base_scale * Vector3(1.18, 0.34, 1.0), fall_time)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.72, 0.16, 0.13, 1.0), fall_time)
	_death_tween.tween_interval(corpse_time)
	for _i in range(3):
		_death_tween.tween_property(sprite, "modulate:a", 0.18, blink_time / 6.0)
		_death_tween.tween_property(sprite, "modulate:a", 1.0, blink_time / 6.0)
	_death_tween.tween_property(sprite, "modulate:a", 0.0, fade_time)
	_death_tween.tween_callback(queue_free)


func _on_flash_timer_timeout() -> void:
	if not is_dying:
		sprite.modulate = _base_modulate
