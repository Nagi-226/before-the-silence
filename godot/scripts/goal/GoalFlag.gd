extends Area3D
## GoalFlag — 终点旗。C++ 版中 finishPos 从未被使用（无法通关的 Bug），
## Godot 版在此正式实现胜利条件

signal reached

## A批6 · 撤离闭锁: 有合闸机制的图(false)触旗只发信号不消旗——
## 未通电时 Main 拒绝通关, 旗须保留供通电后再次触发; 无闸图(true)维持原行为
var consume_on_reach := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		reached.emit()
		if consume_on_reach:
			queue_free()
