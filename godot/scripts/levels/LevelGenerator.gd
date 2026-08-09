extends Node3D
## LevelGenerator — 从符号地图构建 3D 几何与实体
## 对应 C++ 版 Level::setupEntities + 渲染几何，符号语义基于 C++ 版并有 Godot 侧演进:
##   X/M/S/G=墙(Brick/Metal/Stone/Grate)  P=出生  F=终点
##   0-2=敌人(小/中/大)  H=生命 C=金币 A=弹药 h=生命上限升级
##   道具平衡（Godot 侧）: a/w 符号位改生 e(防护服能量)；每第 4 个 H 也改生 e
##   （急救包密度过高，匀一部分给防护服电池，生命包数量约为原来 3/4）

signal goal_reached

const WALL_TEXTURES := {
	"X": "res://assets/images/Wall Brick.bmp",
	"M": "res://assets/images/Wall Metal.bmp",
	"S": "res://assets/images/Wall Stone.bmp",
	"G": "res://assets/images/Wall Grate.bmp",
}

const EnemyScene := preload("res://scenes/entities/Enemy.tscn")
const PickupScene := preload("res://scenes/entities/Pickup.tscn")
const FlagScene := preload("res://scenes/entities/GoalFlag.tscn")

var wall_cells := {}  # Vector2i -> 符号，供 AI 视线/路径查询
var _health_seen := 0  # H 符号序号（道具平衡换算用，build 时归零）


func build(map_index: int, entity_root: Node3D) -> Vector3:
	var rows := (LevelData.MAPS[map_index] as String).split("\n")
	var buckets := {"X": [], "M": [], "S": [], "G": []}
	var spawn := Vector3.ZERO
	_health_seen = 0

	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var ground := _cell_center(x, y)
			match ch:
				"X", "M", "S", "G":
					buckets[ch].append(ground)
					wall_cells[Vector2i(x, y)] = ch
				"P":
					spawn = ground
				"F":
					var flag: Node3D = FlagScene.instantiate()
					flag.position = ground
					flag.reached.connect(func(): goal_reached.emit())
					entity_root.add_child(flag)
				"0", "1", "2":
					var enemy: Node3D = EnemyScene.instantiate()
					enemy.position = ground
					enemy.template_id = int(ch)
					enemy.projectile_root = get_parent()
					entity_root.add_child(enemy)
				"H":
					# 道具平衡：每第 4 个急救包改生防护服电池（e），
					# 生命包保留约 3/4，电池补给显著增加
					_health_seen += 1
					var hpick: Node3D = PickupScene.instantiate()
					hpick.position = ground
					hpick.symbol = "e" if _health_seen % 4 == 0 else "H"
					entity_root.add_child(hpick)
				"C", "A", "h":
					var pickup: Node3D = PickupScene.instantiate()
					pickup.position = ground
					pickup.symbol = ch
					entity_root.add_child(pickup)
				"a":
					# 扩展弹匣已实机移除（弹匣数值并入通用升级组件），
					# 其地图符号位改生防护服能量补给（e）
					var armor_pickup: Node3D = PickupScene.instantiate()
					armor_pickup.position = ground
					armor_pickup.symbol = "e"
					entity_root.add_child(armor_pickup)
				"w":
					# 神经加速器已实机移除（射速并入升级组件），
					# 其地图符号位同样改生防护服能量补给（e）
					var speed_pickup: Node3D = PickupScene.instantiate()
					speed_pickup.position = ground
					speed_pickup.symbol = "e"
					entity_root.add_child(speed_pickup)

	_build_walls(buckets)
	_build_floor_ceiling()
	_build_collision(buckets)
	_spawn_weapon_pickups(map_index, entity_root)
	_spawn_shell_pickups(map_index, entity_root)
	_spawn_upgrade_components(map_index, entity_root)
	return Vector3(spawn.x, 0.65, spawn.z)


func is_wall(x: int, y: int) -> bool:
	return wall_cells.has(Vector2i(x, y))


## 按 weapons.json 的 pickupSpawns 生成武器拾取物（smg="W" / shotgun="T"），
## 不进入与 C++ 同源的地图数据
func _spawn_weapon_pickups(map_index: int, entity_root: Node3D) -> void:
	const WEAPON_SYMBOLS := {"smg": "W", "shotgun": "T"}
	for entry in GameData.weapon_pickup_spawns:
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		var cell := _find_floor(int(ed.get("x", 0)), int(ed.get("y", 0)))
		if cell == Vector2i(-1, -1):
			push_warning("武器拾取点无有效地砖: map%d (%d,%d)" % [map_index, int(ed.get("x", 0)), int(ed.get("y", 0))])
			continue
		var pickup: Node3D = PickupScene.instantiate()
		pickup.position = _cell_center(cell.x, cell.y)
		pickup.symbol = str(WEAPON_SYMBOLS.get(str(ed.get("weapon", "smg")), "W"))
		entity_root.add_child(pickup)


## 按 weapons.json 的 shellSpawns 生成 12 号霰弹补给（符号 "s"），
## 自霰弹枪所在区域起随推进路线分布
func _spawn_shell_pickups(map_index: int, entity_root: Node3D) -> void:
	for entry in GameData.shell_spawns:
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		var cell := _find_floor(int(ed.get("x", 0)), int(ed.get("y", 0)))
		if cell == Vector2i(-1, -1):
			push_warning("霰弹补给点无有效地砖: map%d (%d,%d)" % [map_index, int(ed.get("x", 0)), int(ed.get("y", 0))])
			continue
		var pickup: Node3D = PickupScene.instantiate()
		pickup.position = _cell_center(cell.x, cell.y)
		pickup.symbol = "s"
		entity_root.add_child(pickup)


## 按 weapons.json upgradeComponents.spawns 生成通用武器升级组件
## （符号 "u"/"U"/"v" = 一/二/三级），不进入与 C++ 同源的地图数据
func _spawn_upgrade_components(map_index: int, entity_root: Node3D) -> void:
	const TIER_SYMBOLS := {1: "u", 2: "U", 3: "v"}
	for entry in GameData.component_spawns:
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		var tier := int(ed.get("tier", 1))
		var cell := _find_floor(int(ed.get("x", 0)), int(ed.get("y", 0)))
		if cell == Vector2i(-1, -1):
			push_warning("升级组件生成点无有效地砖: map%d (%d,%d)" % [map_index, int(ed.get("x", 0)), int(ed.get("y", 0))])
			continue
		var pickup: Node3D = PickupScene.instantiate()
		pickup.position = _cell_center(cell.x, cell.y)
		pickup.symbol = str(TIER_SYMBOLS.get(tier, "u"))
		entity_root.add_child(pickup)


## 目标格是地板则直接返回；否则按环向外搜索就近地板（配置容错）
func _find_floor(x: int, y: int) -> Vector2i:
	if not is_wall(x, y):
		return Vector2i(x, y)
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				if not is_wall(x + dx, y + dy):
					return Vector2i(x + dx, y + dy)
	return Vector2i(-1, -1)


func _cell_center(x: int, y: int) -> Vector3:
	return Vector3((x + 0.5) * WorldConst.CELL, 0.0, (y + 0.5) * WorldConst.CELL)


func _build_walls(buckets: Dictionary) -> void:
	var world_size := Vector3(
		LevelData.WIDTH * WorldConst.CELL, WorldConst.WALL_HEIGHT,
		LevelData.HEIGHT * WorldConst.CELL)
	var map_aabb := AABB(
		Vector3(0, 0, 0) - Vector3(WorldConst.CELL, 0, WorldConst.CELL) * 0.5,
		world_size + Vector3(WorldConst.CELL, 0, WorldConst.CELL))

	for symbol in buckets:
		var cells: Array = buckets[symbol]
		if cells.is_empty():
			continue
		var box := BoxMesh.new()
		box.size = Vector3(WorldConst.CELL, WorldConst.WALL_HEIGHT, WorldConst.CELL)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = load(WALL_TEXTURES[symbol])
		var mm := MultiMeshInstance3D.new()
		mm.name = "Walls_" + symbol
		mm.multimesh = MultiMesh.new()
		mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		mm.multimesh.mesh = box
		mm.multimesh.custom_aabb = map_aabb
		mm.material_override = mat
		mm.multimesh.instance_count = cells.size()
		for i in cells.size():
			var pos: Vector3 = cells[i] + Vector3(0, WorldConst.WALL_HEIGHT * 0.5, 0)
			mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		add_child(mm)


func _build_floor_ceiling() -> void:
	var plane_size := Vector2(
		LevelData.WIDTH * WorldConst.CELL, LevelData.HEIGHT * WorldConst.CELL)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mat.albedo_texture = load("res://assets/images/Floor Tile.bmp")
	floor_mat.uv1_scale = Vector3(plane_size.x / WorldConst.CELL, plane_size.y / WorldConst.CELL, 1)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = plane_size
	floor_mesh.material = floor_mat
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Floor"
	floor_mi.mesh = floor_mesh
	floor_mi.position = Vector3(plane_size.x * 0.5, 0.0, plane_size.y * 0.5)
	add_child(floor_mi)

	var ceil_mat := StandardMaterial3D.new()
	ceil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ceil_mat.albedo_texture = load("res://assets/images/Ceiling.bmp")
	ceil_mat.uv1_scale = Vector3(plane_size.x / WorldConst.CELL, plane_size.y / WorldConst.CELL, 1)
	ceil_mat.backlight_enabled = false
	var ceil_mesh := PlaneMesh.new()
	ceil_mesh.size = plane_size
	ceil_mesh.material = ceil_mat
	var ceil_mi := MeshInstance3D.new()
	ceil_mi.name = "Ceiling"
	ceil_mi.mesh = ceil_mesh
	ceil_mi.position = Vector3(plane_size.x * 0.5, WorldConst.WALL_HEIGHT, plane_size.y * 0.5)
	ceil_mi.rotation.x = PI  # 平面朝下
	add_child(ceil_mi)


func _build_collision(buckets: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "WallCollision"
	var shared_shape := BoxShape3D.new()
	shared_shape.size = Vector3(WorldConst.CELL, WorldConst.WALL_HEIGHT, WorldConst.CELL)
	for symbol in buckets:
		for pos in buckets[symbol]:
			var col := CollisionShape3D.new()
			col.shape = shared_shape
			col.position = pos + Vector3(0, WorldConst.WALL_HEIGHT * 0.5, 0)
			body.add_child(col)
	add_child(body)

	# 地面: 无限平面
	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	var ground_col := CollisionShape3D.new()
	ground_col.shape = WorldBoundaryShape3D.new()
	ground_body.add_child(ground_col)
	add_child(ground_body)
