extends Area3D
## Projectile — 玩家与敌人共用的弹道实体（对应 C++ Projectile）
## 用 direction 显式驱动，避免 look_at 轴向歧义

var from_player := true
var damage := 1
var speed := 30.0
var max_range := 20.0
var direction := Vector3.FORWARD

var _traveled := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
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
		queue_free()
	elif body.is_in_group("player") and not from_player:
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif body is StaticBody3D:
		queue_free()
