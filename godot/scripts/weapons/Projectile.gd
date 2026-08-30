extends Area3D
## Projectile — 玩家与敌人共用的弹道实体（对应 C++ Projectile）
## 用 direction 显式驱动，避免 look_at 轴向歧义
## 敌人弹道支持孢子贴图: 设置 spore_texture 后以 Sprite3D 广告牌替代球形网格

var from_player := true
var damage := 1
var speed := 30.0
var max_range := 20.0
var direction := Vector3.FORWARD
var shooter: Node  # B线: 发射者(玩家弹道命中敌人时回报 hits_landed; 敌方不设)

var spore_texture: Texture2D    # AE-219 孢子贴图（缺失则沿用球形弹表现）
var spore_pixel_size := 0.015

var _traveled := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if spore_texture:
		var spore_sprite: Sprite3D = $SporeSprite
		spore_sprite.texture = spore_texture
		spore_sprite.pixel_size = spore_pixel_size
		spore_sprite.visible = true
		$Mesh.visible = false
	# 给刚出膛一帧的豁免，避免与射手自身胶囊体重叠误判
	set_deferred("monitoring", true)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	global_position += direction * step
	_traveled += step
	if _traveled >= max_range:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") and from_player:
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if shooter and is_instance_valid(shooter):
			shooter.hits_landed += 1  # B线: 命中回报(命中率结算)
		queue_free()
	elif body.is_in_group("player") and not from_player:
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif body is StaticBody3D:
		queue_free()
