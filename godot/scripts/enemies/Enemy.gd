extends CharacterBody3D
## Enemy — 三种敌人共用，按 template_id 从 enemies.json 取数值
## AI: 侦测范围内追踪玩家，进入攻击范围停下开火（对应 C++ EnemyAISystem 简化版）

signal died
signal hurt
signal fired

const ProjectileScene := preload("res://scenes/weapons/Projectile.tscn")

const PIXEL_SIZES := [0.045, 0.0575, 0.075]  # 小/中/大 体型 (32px 精灵, 值=米/像素)

@onready var sprite: Sprite3D = $Sprite3D
@onready var flash_timer: Timer = $FlashTimer

var template_id := 0
var projectile_root: Node

var health := 1
var detection_range := 16.0
var attack_range := 4.0
var move_speed := 5.0
var fire_damage := 1
var fire_interval := 0.5
var bullet_speed := 16.0

var _fire_cooldown := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _base_modulate := Color.WHITE


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
	move_speed = float(t.get("moveSpeed", 2.5)) * WorldConst.CELL

	var tex_file: String = t.get("textureFile", "")
	var tex_path := "res://assets/sprites/" + tex_file.get_basename() + ".png"
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	sprite.pixel_size = PIXEL_SIZES[clampi(template_id, 0, 2)]
	_base_modulate = sprite.modulate

	if template_id < GameData.enemy_weapon_cfg.size():
		var w: Dictionary = GameData.enemy_weapon_cfg[template_id]
		fire_damage = int(w.get("damage", 1))
		# C++ 语义: fireRate 为每秒射击数, cooldown = 1/fireRate (PureLogic.h)
		fire_interval = 1.0 / float(w.get("fireRate", 1.0))
		bullet_speed = float(w.get("bulletSpeed", 8.0)) * WorldConst.CELL


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	velocity.y -= _gravity * delta
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist <= detection_range and dist > attack_range:
		var dir := to_player.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	elif dist <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_shoot_at(player)
			_fire_cooldown = fire_interval
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _shoot_at(player: Node3D) -> void:
	fired.emit()
	var proj: Node3D = ProjectileScene.instantiate()
	proj.from_player = false
	proj.damage = fire_damage
	proj.speed = bullet_speed
	proj.max_range = detection_range + WorldConst.CELL * 2
	var root := projectile_root if projectile_root else get_tree().root
	root.add_child(proj)
	var muzzle := global_position + Vector3(0, WorldConst.EYE_HEIGHT * 0.8, 0)
	proj.global_position = muzzle
	var target: Vector3 = player.global_position + Vector3(0, 0.65, 0)
	proj.direction = (target - muzzle).normalized()


func take_damage(amount: int) -> void:
	health -= amount
	sprite.modulate = Color(4.0, 4.0, 4.0)  # 受击白闪
	flash_timer.start(float(GameData.enemies_cfg.get("feedback", {}).get("hurtFlashTime", 0.2)))
	if health <= 0:
		died.emit()
		queue_free()
	else:
		hurt.emit()


func _on_flash_timer_timeout() -> void:
	sprite.modulate = _base_modulate
