extends Area3D
## GoalFlag — 终点旗。C++ 版中 finishPos 从未被使用（无法通关的 Bug），
## Godot 版在此正式实现胜利条件

signal reached


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		reached.emit()
		queue_free()
