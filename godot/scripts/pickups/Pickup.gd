extends Area3D
## Pickup — 拾取物，符号语义与 C++ 版一致（a/w 已实机移除，a 位改生 e）
## H=生命 C=金币 A=弹药 e=防护服能量  h=生命上限升级(消耗金币)  W=武器(冲锋枪)
## T=武器(霰弹枪)  s=12号霰弹补给
## u/U/v=通用武器升级组件(一/二/三级，配置生成，需按顺序获取)
## 拒收规则: H 生命满 / e 能量满 / h 金币不足 / 组件越级或满级时，拾取物保留原地

signal collected(symbol: String)

@onready var sprite: Sprite3D = $Sprite3D

var symbol := "C"

var _base_y := 0.9
var _time := 0.0

const TYPE_NAMES := {
	"H": "Health", "C": "Coin", "A": "Ammo", "e": "Armor",
	"h": "UpgradeHealth",
	"W": "SMG", "T": "Shotgun", "s": "Shells",
	"u": "WeaponComp1", "U": "WeaponComp2", "v": "WeaponComp3",
}
const TEXTURES := {
	"H": "Heart.png", "C": "Coin.png", "A": "Upgrade Ammo 10.png",
	"e": "Battery.png",
	"h": "Upgrade Heart 10.png",
	"W": "Weapon SMG Pickup.png", "T": "Weapon Shotgun Pickup.png",
	"s": "Shells 12g.png",
	"u": "Upgrade Component 1.png", "U": "Upgrade Component 2.png",
	"v": "Upgrade Component 3.png",
}
const SOUND_KEYS := {
	"Health": "Health", "Coin": "Coin", "Ammo": "Ammo", "Armor": "Ammo",
	"UpgradeHealth": "UpgradeHealth",
	"SMG": "WeaponPickup", "Shotgun": "WeaponPickup", "Shells": "Ammo",
	"WeaponComp1": "WeaponComp", "WeaponComp2": "WeaponComp",
	"WeaponComp3": "WeaponComp",
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
			if not body.try_heal(int(amounts.get("healAmount", 1))):
				return  # 生命已满，保留拾取物
		"Ammo":
			body.add_reserve(int(amounts.get("ammoPickup", 10)), str(amounts.get("ammoPickupType", "9×19mm")))
		"Armor":
			if not body.try_add_armor(int(amounts.get("armorPickup", 10))):
				return  # 防护服能量已满，保留拾取物
		"Coin":
			body.coins += 1
			body.coins_changed.emit(body.coins)
		"UpgradeHealth":
			if not body.try_upgrade("Health"):
				return  # 金币不足，保留拾取物
		"SMG":
			body.grant_weapon("smg")
		"Shotgun":
			body.grant_weapon("shotgun")
		"Shells":
			body.add_reserve(int(amounts.get("shellPickup", 6)), str(amounts.get("shellPickupType", "12号霰弹")))
		"WeaponComp1":
			if not body.apply_weapon_component(1):
				return  # 顺序不符（或已满级），保留拾取物
		"WeaponComp2":
			if not body.apply_weapon_component(2):
				return
		"WeaponComp3":
			if not body.apply_weapon_component(3):
				return
	GameData.play_pickup_sound(SOUND_KEYS.get(type_name, "Coin"))
	collected.emit(symbol)
	queue_free()
