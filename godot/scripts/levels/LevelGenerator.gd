extends Node3D
## LevelGenerator — 从符号地图构建 3D 几何与实体
## 对应 C++ 版 Level::setupEntities + 渲染几何，符号语义基于 C++ 版并有 Godot 侧演进:
##   X/M/S/G=墙(Brick/Metal/Stone/Grate)  P=出生  F=终点
##   0-2=敌人(小/中/大)  H=生命 C=金币 A=弹药 h=生命上限升级
##   道具平衡（Godot 侧）: a/w 符号位改生 e(防护服能量)；每第 4 个 H 也改生 e
##   （急救包密度过高，匀一部分给防护服电池，生命包数量约为原来 3/4）
## P2a 夜空室外区: 按 level_ext.json 的 courtyard 配置在原地图矩形之外向外扩出
##   石墙庭院（西缘留门洞连通室内），只操作运行时几何桶，不触碰与 C++
##   同源的 LevelData 地图数据。庭院位于天花板平面之外 → 室内屋顶自然形成屋檐。

signal goal_reached

const WALL_TEXTURES := {
	"X": "res://assets/images/Wall Concrete.bmp",
	"M": "res://assets/images/Wall Metal.bmp",
	"S": "res://assets/images/Wall Stone.bmp",
	"G": "res://assets/images/Wall Grate.bmp",
}

const EnemyScene := preload("res://scenes/entities/Enemy.tscn")
const PickupScene := preload("res://scenes/entities/Pickup.tscn")
const FlagScene := preload("res://scenes/entities/GoalFlag.tscn")

var wall_cells := {}  # Vector2i -> 符号，供 AI 视线/路径查询
var _health_seen := 0  # H 符号序号（道具平衡换算用，build 时归零）
var _courtyard_cells: Array[Vector2i] = []  # 本图庭院地板格（露天区，含门洞通道）
var _courtyard_rect := Rect2i()  # 庭院外扩矩形（格坐标），size==Vector2i.ZERO 表示无庭院
var _courtyard_tint := Color(1.0, 1.0, 1.0)
# 当前地图尺寸元数据(格): 符号图取 LevelData 常量, 外部地图(level_ext.maps)取配置
var _map_w := LevelData.WIDTH
var _map_h := LevelData.HEIGHT
var _outdoor := false  # 外部地图 outdoor=true: 无天花板(露天关卡)


func build(map_index: int, entity_root: Node3D) -> Vector3:
	# B线: 外部地图(level_ext.maps)优先——命中则符号图与实体全走配置,
	# 不触碰与 C++ 归档版同源的 LevelData(红线); 未命中回退符号图(现状行为)
	var ext_map := _ext_map_cfg(map_index)
	var rows: Variant = []
	if ext_map.is_empty():
		rows = (LevelData.MAPS[map_index] as String).split("\n")
	var buckets := {"X": [], "M": [], "S": [], "G": []}
	var spawn := Vector3.ZERO
	_health_seen = 0
	# B线转关复用本实例多次 build: 运行时状态必须整体重置
	wall_cells.clear()
	_courtyard_cells.clear()
	_courtyard_rect = Rect2i()
	_map_w = LevelData.WIDTH
	_map_h = LevelData.HEIGHT
	_outdoor = false
	# B线: goals 命中且 suppressDataFlag → 抑制符号图 F 旗(改由配置旗接管)
	var suppress_flag := _goal_suppress_data_flag(map_index)

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
					if suppress_flag:
						continue
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

	if ext_map.is_empty():
		_apply_courtyard(map_index, buckets)
	else:
		spawn = _apply_ext_map(ext_map, entity_root, buckets)
	_build_walls(buckets)
	_build_floor_ceiling()
	_build_collision(buckets)
	_build_terrain(map_index)
	_build_facade(map_index)
	_build_wall_decals(map_index)
	_spawn_props(map_index)
	_spawn_weapon_pickups(map_index, entity_root)
	_spawn_shell_pickups(map_index, entity_root)
	_spawn_upgrade_components(map_index, entity_root)
	_spawn_goal_flags(map_index, entity_root)
	return Vector3(spawn.x, 0.65, spawn.z)


## B线: 取 level_ext.maps 中匹配 map_index 的外部地图配置(未命中返回空字典)
func _ext_map_cfg(map_index: int) -> Dictionary:
	for entry in GameData.level_ext_cfg.get("maps", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) == map_index:
			return ed
	return {}


## B线: goals 段命中且 suppressDataFlag=true → 抑制符号图 F 旗(改由配置旗接管)
func _goal_suppress_data_flag(map_index: int) -> bool:
	for entry in GameData.level_ext_cfg.get("goals", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		return bool(ed.get("suppressDataFlag", false))
	return false


## B线: 按 goals.flags 配置生成终点旗(如第一关旗挪庭院)
func _spawn_goal_flags(map_index: int, entity_root: Node3D) -> void:
	for entry in GameData.level_ext_cfg.get("goals", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		for f in ed.get("flags", []):
			var fd: Dictionary = f
			var flag: Node3D = FlagScene.instantiate()
			flag.position = _cell_center(int(fd.get("x", 0)), int(fd.get("y", 0)))
			flag.reached.connect(func(): goal_reached.emit())
			entity_root.add_child(flag)


## B线: 外部地图应用——灰盒围墙环(真几何, 进 buckets/wall_cells, AI/小地图/碰撞可用)
## + 配置实体(spawn/flag/enemies/pickups)。返回出生点(格中心)。
func _apply_ext_map(cfg: Dictionary, entity_root: Node3D, buckets: Dictionary) -> Vector3:
	_map_w = maxi(int(cfg.get("width", 0)), 4)
	_map_h = maxi(int(cfg.get("height", 0)), 4)
	_outdoor = bool(cfg.get("outdoor", false))
	var symbol := str((cfg.get("borderWall", {}) as Dictionary).get("symbol", "S"))
	if not WALL_TEXTURES.has(symbol):
		symbol = "S"
	for y in range(_map_h):
		for x in range(_map_w):
			if x == 0 or y == 0 or x == _map_w - 1 or y == _map_h - 1:
				buckets[symbol].append(_cell_center(x, y))
				wall_cells[Vector2i(x, y)] = symbol

	var sp: Dictionary = cfg.get("spawn", {})
	var spawn := _cell_center(int(sp.get("x", 1)), int(sp.get("y", 1)))

	var fl: Dictionary = cfg.get("flag", {})
	var flag: Node3D = FlagScene.instantiate()
	flag.position = _cell_center(int(fl.get("x", _map_w - 3)), int(fl.get("y", 2)))
	flag.reached.connect(func(): goal_reached.emit())
	entity_root.add_child(flag)

	for e in cfg.get("enemies", []):
		var ed: Dictionary = e
		var enemy: Node3D = EnemyScene.instantiate()
		enemy.position = _cell_center(int(ed.get("x", 0)), int(ed.get("y", 0)))
		enemy.template_id = int(ed.get("id", 0))
		enemy.projectile_root = get_parent()
		entity_root.add_child(enemy)

	for p in cfg.get("pickups", []):
		var pd: Dictionary = p
		var pickup: Node3D = PickupScene.instantiate()
		pickup.position = _cell_center(int(pd.get("x", 0)), int(pd.get("y", 0)))
		pickup.symbol = str(pd.get("symbol", "A"))
		entity_root.add_child(pickup)

	return spawn


func is_wall(x: int, y: int) -> bool:
	return wall_cells.has(Vector2i(x, y))


## 庭院露天格集合（P2a，供测试与后续地形系统查询）
func get_courtyard_cells() -> Array[Vector2i]:
	return _courtyard_cells


func has_courtyard() -> bool:
	return not _courtyard_cells.is_empty()


## P2a 庭院外扩: 在原地图矩形之外追加围墙环并登记露天格。
## 门洞开在围墙环西缘（压住原边界列，消除隐形夹缝）。门洞格在原图中本就是
## 东边界墙 —— 必须先移除原墙（渲染/碰撞/小地图均从 wall_cells+buckets 派生），
## 否则门物理与逻辑上都打不开。天花板整片覆盖原地图矩形且庭院在其之外 →
## 无需挖洞即得屋檐效果。
func _apply_courtyard(map_index: int, buckets: Dictionary) -> void:
	var cfg: Dictionary = GameData.level_ext_cfg.get("courtyard", {})
	if cfg.is_empty() or int(cfg.get("map", -1)) != map_index:
		return
	var rect: Dictionary = cfg.get("rect", {})
	if rect.is_empty():
		push_warning("level_ext.courtyard 缺少 rect，跳过庭院外扩")
		return
	var x0 := int(rect.get("x", 0))
	var y0 := int(rect.get("y", 0))
	var w := int(rect.get("w", 0))
	var h := int(rect.get("h", 0))
	if w <= 2 or h <= 2:
		push_warning("level_ext.courtyard.rect 尺寸无效 (%dx%d)，跳过庭院外扩" % [w, h])
		return
	var symbol := str(cfg.get("wallSymbol", "S"))
	if not WALL_TEXTURES.has(symbol):
		symbol = "S"
	var tint: Array = cfg.get("floorTint", [])
	if tint.size() >= 3:
		_courtyard_tint = Color(float(tint[0]), float(tint[1]), float(tint[2]))

	var doorway: Dictionary = cfg.get("doorway", {})
	var door_x := int(doorway.get("x", x0))
	var door_y := int(doorway.get("y", y0 + h / 2))
	var door_h := maxi(1, int(doorway.get("h", 2)))

	_courtyard_rect = Rect2i(x0, y0, w, h)
	var x1 := x0 + w - 1
	var y1 := y0 + h - 1
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var cell := Vector2i(cx, cy)
			var on_ring := cx == x0 or cx == x1 or cy == y0 or cy == y1
			var on_door := cx == door_x and cy >= door_y and cy < door_y + door_h
			if on_door:
				# 门洞格本是东边界墙: 先移除原墙再放行（不登记露天格，
				# 露天格仅统计矩形内部，与 (w-2)*(h-2) 断言一致）
				wall_cells.erase(cell)
				var center := _cell_center(cx, cy)
				for s: String in buckets:
					buckets[s].erase(center)
			elif on_ring:
				# 围墙环: 原图已有墙的格跳过（西缘压住原边界列），避免重复网格与碰撞体
				if not wall_cells.has(cell):
					buckets[symbol].append(_cell_center(cx, cy))
					wall_cells[cell] = symbol
			else:
				_courtyard_cells.append(cell)


## 混合路线阶段一: 装饰外立面。现有墙顶(2.6m)之上叠 stories 层窗户带 + 女儿墙,
## 总高≈三层体量, 兑现"出门回头见三层仓库"的视觉说服力。纯布景:
## 不登记 wall_cells、不进 buckets、不建碰撞 → 碰撞/AI/子弹/小地图零改动。
## 立面朝 +X(庭院侧)竖立, 与原墙东面留 offset 防共面闪烁。
func _build_facade(map_index: int) -> void:
	var cfg: Dictionary = GameData.level_ext_cfg.get("facade", {})
	if cfg.is_empty() or int(cfg.get("map", -1)) != map_index:
		return
	var col := int(cfg.get("col", 0))
	var row_min := int(cfg.get("rowMin", 0))
	var row_max := int(cfg.get("rowMax", row_min))
	var extend := int(cfg.get("extendRows", 0))
	var stories := maxi(1, int(cfg.get("stories", 2)))
	var story_h := float(cfg.get("storyHeight", WorldConst.WALL_HEIGHT))
	var r0 := row_min - extend
	var r1 := row_max + extend
	var width := float(r1 - r0 + 1) * WorldConst.CELL
	var height := story_h * float(stories)
	var base_y := WorldConst.WALL_HEIGHT
	var face_x := (col + 1) * WorldConst.CELL + float(cfg.get("offset", 0.05))
	var z_center := (float(r0 + r1 + 1) / 2.0) * WorldConst.CELL

	var root := Node3D.new()
	root.name = "Facade"
	add_child(root)

	# 窗户带主体: 单片竖面, 纹理横向平铺保持窗户近方形
	var win_tex: Variant = load(str(cfg.get("windowTexture", "")))
	if win_tex == null:
		push_warning("facade.windowTexture 缺失，跳过外立面")
		root.queue_free()
		return
	var band_mat := StandardMaterial3D.new()
	band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	band_mat.albedo_texture = win_tex
	band_mat.uv1_scale = Vector3(float(cfg.get("uvScaleX", 1.0)), 1.0, 1.0)
	var band := QuadMesh.new()
	band.size = Vector2(width, height)
	band.material = band_mat
	var band_mi := MeshInstance3D.new()
	band_mi.name = "FacadeBand"
	band_mi.mesh = band
	band_mi.rotation.y = PI / 2  # Quad 法线 +Z → 转向 +X(庭院侧)
	band_mi.position = Vector3(face_x, base_y + height * 0.5, z_center)
	root.add_child(band_mi)

	# 女儿墙/屋檐: 压顶一条, 用板材贴图, 向前(庭院侧)微挑
	if bool(cfg.get("parapet", false)):
		var parapet_tex: Variant = load(str(cfg.get("wallTexture", "")))
		if parapet_tex != null:
			var p_mat := StandardMaterial3D.new()
			p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			p_mat.albedo_texture = parapet_tex
			var p_box := BoxMesh.new()
			p_box.size = Vector3(0.5, 0.5, width)
			p_box.material = p_mat
			var p_mi := MeshInstance3D.new()
			p_mi.name = "FacadeParapet"
			p_mi.mesh = p_box
			p_mi.position = Vector3(
				face_x - 0.2, base_y + height + 0.25, z_center)
			root.add_child(p_mi)


## 墙面贴花(布景): 把整面墙替换成专属贴图(如出生点货运大门)。与外立面同约定:
## 不登记 wall_cells、不进 buckets、不建碰撞 → 逻辑零侵入; 贴花面沿法线外推
## offset 防与原墙面共面闪烁。face 为法线朝向("N"=-Z "S"=+Z "E"=+X "W"=-X)。
func _build_wall_decals(map_index: int) -> void:
	var decals: Array = GameData.level_ext_cfg.get("wallDecals", [])
	var idx := 0
	for entry in decals:
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		var tex_path := str(ed.get("texture", ""))
		if not ResourceLoader.exists(tex_path):
			push_warning("墙面贴花贴图缺失: " + tex_path)
			continue
		var tex: Variant = load(tex_path)
		var x0 := int(ed.get("x", 0))
		var y0 := int(ed.get("y", 0))
		var w := maxi(1, int(ed.get("w", 1)))
		var width := float(w) * WorldConst.CELL
		var height := WorldConst.WALL_HEIGHT
		var offset := float(ed.get("offset", 0.05))
		var face := str(ed.get("face", "N"))
		# N/S 面墙沿 x 延伸 w 格；E/W 面墙沿 y 延伸 w 格（2026-08-30 庭院东墙大门，
		# 转关叙事贴花。覆盖格口径与 SmokeTest 贴花墙格断言一致）
		var cx: float
		var cz: float
		if face == "E" or face == "W":
			cx = (float(x0) + 0.5) * WorldConst.CELL
			cz = (float(y0) + float(w) * 0.5) * WorldConst.CELL
		else:
			cx = (float(x0) + float(w) * 0.5) * WorldConst.CELL
			cz = (float(y0) + 0.5) * WorldConst.CELL
		var pos := Vector3.ZERO
		var rot_y := 0.0
		match face:
			"N":
				pos = Vector3(cx, height * 0.5, cz - WorldConst.CELL * 0.5 - offset)
				rot_y = PI
			"S":
				pos = Vector3(cx, height * 0.5, cz + WorldConst.CELL * 0.5 + offset)
				rot_y = 0.0
			"E":
				pos = Vector3(cx + WorldConst.CELL * 0.5 + offset, height * 0.5, cz)
				rot_y = PI / 2
			"W":
				pos = Vector3(cx - WorldConst.CELL * 0.5 - offset, height * 0.5, cz)
				rot_y = -PI / 2
			_:
				push_warning("墙面贴花未知 face: " + face)
				continue
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		quad.material = mat
		var mi := MeshInstance3D.new()
		mi.name = "WallDecal_%d" % idx
		mi.mesh = quad
		mi.rotation.y = rot_y
		mi.position = pos
		mi.add_to_group("wall_decals")
		add_child(mi)
		idx += 1


const PROP_PIXEL_SIZE := 0.02  # 道具 Sprite3D 基准米/像素(128px 精灵≈2.56m), 配置 scale 乘数微调


## 混合路线阶段一: 庭院 billboard 道具(与敌人/拾取物同源技术)。
## 首批不加碰撞(可穿过, 不干扰 AI/寻路); 不登记 wall_cells → 逻辑零侵入。
## 精灵透明底自动落地: 扫描贴图最低不透明像素行对齐地面。
func _spawn_props(map_index: int) -> void:
	var props: Array = GameData.level_ext_cfg.get("props", [])
	var idx := 0
	for entry in props:
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		var tex_path := str(ed.get("sprite", ""))
		var tex: Variant = load(tex_path) if ResourceLoader.exists(tex_path) else null
		if tex == null:
			push_warning("道具贴图缺失: " + tex_path)
			continue
		var sprite := Sprite3D.new()
		sprite.name = "Prop_%d" % idx
		sprite.texture = tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.pixel_size = PROP_PIXEL_SIZE * float(ed.get("scale", 1.0))
		var h_px := float(sprite.texture.get_height())
		var bottom_px := _opaque_bottom_row(sprite.texture)
		sprite.position = _cell_center(int(ed.get("x", 0)), int(ed.get("y", 0))) \
			+ Vector3(0.0, (bottom_px - h_px * 0.5) * sprite.pixel_size, 0.0)
		sprite.add_to_group("props")
		add_child(sprite)
		idx += 1


## 贴图自下而上首个不透明像素行(道具落地基准); 取不到图时退回 90% 高度兜底
func _opaque_bottom_row(tex: Texture2D) -> float:
	var img := tex.get_image()
	if img == null:
		return float(tex.get_height()) * 0.9
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.05:
				return float(y)
	return float(tex.get_height()) * 0.9


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


## 目标格是地板则直接返回；否则按环向外搜索就近地板（配置容错）。
## 注意: 庭院格已登记进 wall_cells 的反义（非墙），本函数天然兼容庭院坐标
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
	# 包围盒必须按实际墙格计算: 庭院围墙位于原地图矩形之外，
	# 若沿用地图尺寸的固定包围盒，新增实例会被视锥剔除（MultiMesh custom_aabb 坑）
	var half := WorldConst.CELL * 0.5
	var minc := Vector3(INF, 0, INF)
	var maxc := Vector3(-INF, 0, -INF)
	for symbol in buckets:
		for pos in buckets[symbol]:
			minc = minc.min(pos)
			maxc = maxc.max(pos)
	var map_aabb: AABB
	if maxc.x >= minc.x:
		map_aabb = AABB(
			Vector3(minc.x - half, 0, minc.z - half),
			Vector3(maxc.x - minc.x + WorldConst.CELL, WorldConst.WALL_HEIGHT,
				maxc.z - minc.z + WorldConst.CELL))
	else:
		# 无任何墙体时退回地图尺寸包围盒
		var ws := Vector3(
			LevelData.WIDTH * WorldConst.CELL, WorldConst.WALL_HEIGHT,
			LevelData.HEIGHT * WorldConst.CELL)
		map_aabb = AABB(Vector3(0, 0, 0) - Vector3(half, 0, half),
			ws + Vector3(WorldConst.CELL, 0, WorldConst.CELL))

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
	# 地图尺寸取当前图元数据(符号图=LevelData 常量, 外部地图=level_ext.maps 配置)
	var plane_size := Vector2(
		_map_w * WorldConst.CELL, _map_h * WorldConst.CELL)

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

	# outdoor 地图(如 map2 室外街道)无天花板, 露天由 Main 场景环境提供
	if _outdoor:
		return
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

	# P2a 庭院地面覆层: 仅覆盖庭院矩形，暗色冷调区分室内地砖;
	# 抬升 1cm 防止与室内大地板共面闪烁; 露天无顶 —— 夜空由 Main 场景环境提供
	if _courtyard_rect.size.x > 0:
		var cw := float(_courtyard_rect.size.x * WorldConst.CELL)
		var ch := float(_courtyard_rect.size.y * WorldConst.CELL)
		var ground_tex := str(GameData.level_ext_cfg.get("courtyard", {}) \
			.get("groundTexture", "res://assets/images/Floor Tile.bmp"))
		var ext_mat := StandardMaterial3D.new()
		ext_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ext_mat.albedo_texture = load(ground_tex)
		ext_mat.albedo_color = _courtyard_tint
		ext_mat.uv1_scale = Vector3(cw / WorldConst.CELL, ch / WorldConst.CELL, 1)
		var ext_mesh := PlaneMesh.new()
		ext_mesh.size = Vector2(cw, ch)
		ext_mesh.material = ext_mat
		var ext_mi := MeshInstance3D.new()
		ext_mi.name = "CourtyardFloor"
		ext_mi.mesh = ext_mesh
		ext_mi.position = Vector3(
			(float(_courtyard_rect.position.x) + _courtyard_rect.size.x * 0.5) * WorldConst.CELL,
			0.01,
			(float(_courtyard_rect.position.y) + _courtyard_rect.size.y * 0.5) * WorldConst.CELL)
		add_child(ext_mi)


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


## P2b 高度地形: 平台(实心台体) + 斜坡(旋转坡板), 配置于 level_ext.json terrain 段。
## 玩法元素——进碰撞(CharacterBody3D 天然可行走/贴地), 但不登记 wall_cells/buckets
## → 敌人 AI/小地图/墙碰撞计数零改动(隔层侦测留待敌人地面吸附批次处理)。
## 每个地形体为独立 StaticBody3D(Terrain_Platform_i / Terrain_Ramp_i), 挂 "terrain" 组。
const TERRAIN_RAMP_THICK := 0.3  # 坡板厚度(米)


func _build_terrain(map_index: int) -> void:
	var terrain: Array = GameData.level_ext_cfg.get("terrain", [])
	var idx := 0
	for entry in terrain:
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		var plat: Dictionary = ed.get("platform", {})
		if not plat.is_empty():
			if _build_terrain_platform(idx, plat):
				idx += 1
		var ramp: Dictionary = ed.get("ramp", {})
		if not ramp.is_empty():
			if _build_terrain_ramp(idx, ramp):
				idx += 1


## 实心平台: 矩形格区自地面抬升至 height, 顶面可行走/承碰撞
func _build_terrain_platform(idx: int, cfg: Dictionary) -> bool:
	var x := int(cfg.get("x", 0))
	var y := int(cfg.get("y", 0))
	var w := maxi(1, int(cfg.get("w", 1)))
	var h := maxi(1, int(cfg.get("h", 1)))
	var height := float(cfg.get("height", 0.0))
	if height <= 0.0 or height >= WorldConst.WALL_HEIGHT:
		push_warning("terrain.platform 高度无效 (%.2fm), 跳过" % height)
		return false
	var center := Vector3(
		(float(x) + float(w) * 0.5) * WorldConst.CELL,
		height * 0.5,
		(float(y) + float(h) * 0.5) * WorldConst.CELL)
	_make_terrain_body("Terrain_Platform_%d" % idx, Basis.IDENTITY, center,
		Vector3(float(w) * WorldConst.CELL, height, float(h) * WorldConst.CELL),
		_terrain_material(cfg))
	return true


## 斜坡: 沿 dir(N/S/E/W, 坡顶朝向)自地面抬升至 height 的坡板。
## 水平跨距 = dir 轴向格数×CELL, 坡度须 <45°(CharacterBody3D 可行走上限);
## 两端各延 5cm 咬合地面与平台消缝。
func _build_terrain_ramp(idx: int, cfg: Dictionary) -> bool:
	var x := int(cfg.get("x", 0))
	var y := int(cfg.get("y", 0))
	var w := maxi(1, int(cfg.get("w", 1)))
	var h := maxi(1, int(cfg.get("h", 1)))
	var height := float(cfg.get("height", 0.0))
	var dir := str(cfg.get("dir", "E"))
	if height <= 0.0 or height >= WorldConst.WALL_HEIGHT:
		push_warning("terrain.ramp 高度无效 (%.2fm), 跳过" % height)
		return false
	var along_x := dir == "E" or dir == "W"
	var span := float(w if along_x else h) * WorldConst.CELL
	var width := float(h if along_x else w) * WorldConst.CELL
	var slope_deg := rad_to_deg(atan2(height, span))
	if slope_deg >= 45.0:
		push_warning("terrain.ramp 坡度 %.1f° 超 45° 不可行走, 跳过" % slope_deg)
		return false
	var x0 := float(x) * WorldConst.CELL
	var z0 := float(y) * WorldConst.CELL
	var cx := x0 + float(w) * WorldConst.CELL * 0.5
	var cz := z0 + float(h) * WorldConst.CELL * 0.5
	var overlap := 0.05
	var low := Vector3.ZERO
	var high := Vector3.ZERO
	match dir:
		"E":
			low = Vector3(x0 - overlap, 0.0, cz)
			high = Vector3(x0 + span + overlap, height, cz)
		"W":
			low = Vector3(x0 + span + overlap, 0.0, cz)
			high = Vector3(x0 - overlap, height, cz)
		"S":
			low = Vector3(cx, 0.0, z0 - overlap)
			high = Vector3(cx, height, z0 + span + overlap)
		"N":
			low = Vector3(cx, 0.0, z0 + span + overlap)
			high = Vector3(cx, height, z0 - overlap)
		_:
			push_warning("terrain.ramp 未知 dir: " + dir)
			return false
	var fwd := (high - low).normalized()
	var fwd_flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var side_w := fwd_flat.cross(Vector3.UP)  # 宽向(水平, 垂直坡向)
	var up := side_w.cross(fwd)               # 坡面法线(朝上)
	var slope_len := (high - low).length()
	var center := (low + high) * 0.5 - up * (TERRAIN_RAMP_THICK * 0.5)
	_make_terrain_body("Terrain_Ramp_%d" % idx, Basis(fwd, up, side_w), center,
		Vector3(slope_len, TERRAIN_RAMP_THICK, width),
		_terrain_material(cfg))
	return true


func _make_terrain_body(body_name: String, basis: Basis, center: Vector3,
		size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.transform = Transform3D(basis, center)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	body.add_child(mi)
	body.add_to_group("terrain")
	add_child(body)
	return body


func _terrain_material(cfg: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var tex_path := str(cfg.get("texture", "res://assets/images/Floor Tile.bmp"))
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	var tint: Array = cfg.get("tint", [])
	if tint.size() >= 3:
		mat.albedo_color = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	return mat
