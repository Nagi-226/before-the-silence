extends Area3D
## Pickup — 六种拾取物，符号语义与 C++ 版一致
## H=生命 C=金币 A=弹药  h/a/w=升级(消耗金币)

signal collected(symbol: String)

@onready var sprite: Sprite3D = $Sprite3D

var symbol := "C"

var _base_y := 0.9
var _time := 0.0

const TYPE_NAMES := {
	"H": "Health", "C": "Coin", "A": "Ammo",
	"h": "UpgradeHealth", "a": "UpgradeAmmo", "w": "UpgradeSpeed",
}
const TEXTURES := {
	"H": "Heart.png", "C": "Coin.png", "A": "Battery.png",
	"h": "Upgrade Heart 10.png", "a": "Upgrade Ammo 10.png",
	"w": "Upgrade Weapon Speed 10.png",
}
const SOUND_KEYS := {
	"Health": "Health", "Coin": "Coin", "Ammo": "Ammo",
	"UpgradeHealth": "UpgradeHealth", "UpgradeAmmo": "UpgradeAmmo",
	"UpgradeSpeed": "UpgradeSpeed",
}


func _ready() -> void:
	add_to_group("pickups")
	var tex_path: String = "res://assets/sprites/" + TEXTURES.get(symbol, "Coin.png")
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	sprite.position.y = _base_y + sin(_time * 2.5) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var type_name: String = TYPE_NAMES.get(symbol, "Coin")
	var amounts: Dictionary = GameData.pickups_cfg.get("amounts", {})
	match type_name:
		"Health":
			body.heal(int(amounts.get("healAmount", 1)))
		"Ammo":
			body.add_reserve(int(amounts.get("ammoPickup", 10)))
		"Coin":
			body.coins += 1
			body.coins_changed.emit(body.coins)
		"UpgradeHealth":
			if not body.try_upgrade("Health"):
				return  # 金币不足，保留拾取物
		"UpgradeAmmo":
			if not body.try_upgrade("Ammo"):
				return
		"UpgradeSpeed":
			if not body.try_upgrade("Speed"):
				return
	GameData.play_pickup_sound(SOUND_KEYS.get(type_name, "Coin"))
	collected.emit(symbol)
	queue_free()
