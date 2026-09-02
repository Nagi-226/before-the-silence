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
## A批6 · 合闸机制: 配电箱交互点触发时发出(Main 接 toast/HUD 目标行)
signal breaker_activated

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
# A线·层叠数据模型: 楼层 -> 墙格集(Vector2i -> 符号)。层墙不进一楼 wall_cells
# (一楼不变式原样), 供 is_wall 分层查询与小地图楼层化(批5)消费
var _layer_cells := {}
# 本图层区(天花板挖洞用): {rect: Rect2i, top: float(层顶高)}
var _layer_rects: Array[Dictionary] = []
# A批6 · 合闸机制运行时状态(build 时整体重置 = 转关/重打自动复位):
# gate_powered=闸门供电标志; _gate_map=本图是否有配电箱交互点(有闸才闭锁);
# _decals=贴花 id 注册表(状态切换用); _interactables=走进触发区列表
var gate_powered := false
var _gate_map := false
var _decals := {}
var _interactables: Array = []
# A批6 · 小地图楼层化: 楼梯位置标记(楼层 -> 格坐标数组, 异色点用)
var _stair_marks := {}


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
	_layer_cells.clear()
	_layer_rects.clear()
	_courtyard_cells.clear()
	_courtyard_rect = Rect2i()
	_map_w = LevelData.WIDTH
	_map_h = LevelData.HEIGHT
	_outdoor = false
	# A批6: 合闸机制状态重置(转关/重打 = 断电重来)
	gate_powered = false
	_decals.clear()
	_interactables.clear()
	_stair_marks.clear()
	_gate_map = _map_has_breaker(map_index)
	# B线: goals 命中且 suppressDataFlag → 抑制符号图 F 旗(改由配置旗接管)
	var suppress_flag := _goal_suppress_data_flag(map_index)
	# A批5: pickupOverrides.suppress — 符号图拾取生成跳过配置格(通用数组机制)
	# A批8: 一批可抑制多格(一层补给减量, 匀往二三层)
	var pickup_suppress := _pickup_suppress_cells(map_index)
	# A批7: enemyOverrides.suppress — 符号图敌人减量(一层精英挖减, 捕3层重布)
	var enemy_suppress := _enemy_suppress_cells(map_index)

	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var ground := _cell_center(x, y)
			if not pickup_suppress.is_empty() and "HCAhaw".contains(ch) \
					and pickup_suppress.has(Vector2i(x, y)):
				continue
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
					flag.consume_on_reach = not _gate_map  # A批6: 有闸图触旗不消旗(闭锁)
					flag.reached.connect(func(): goal_reached.emit())
					entity_root.add_child(flag)
				"0", "1", "2":
					if not enemy_suppress.is_empty() \
							and enemy_suppress.has(Vector2i(x, y)):
						continue
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
		_apply_partitions(map_index, buckets)
	else:
		spawn = _apply_ext_map(ext_map, entity_root, buckets)
	_build_walls(buckets)
	# 层几何先于天花板: 天花板需按层区 rect 挖洞抬升(层区净空 = base→层顶)
	_build_layers(map_index, entity_root)
	_build_floor_ceiling()
	_build_collision(buckets)
	_build_terrain(map_index)
	_build_stairs(map_index)
	_build_facade(map_index)
	_build_wall_decals(map_index)
	_spawn_props(map_index)
	_spawn_weapon_pickups(map_index, entity_root)
	_spawn_shell_pickups(map_index, entity_root)
	_spawn_upgrade_components(map_index, entity_root)
	_spawn_goal_flags(map_index, entity_root)
	_apply_pickup_overrides(map_index, entity_root)
	_apply_enemy_overrides(map_index, entity_root)
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
			flag.consume_on_reach = not _gate_map  # A批6: 有闸图触旗不消旗(闭锁)
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
	flag.consume_on_reach = not _gate_map  # A批6: 有闸图触旗不消旗(闭锁)
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


func is_wall(x: int, y: int, floor_level := 1) -> bool:
	if floor_level <= 1:
		return wall_cells.has(Vector2i(x, y))
	var cells: Dictionary = _layer_cells.get(floor_level, {})
	return cells.has(Vector2i(x, y))


## A线·取指定楼层的墙格集(Vector2i -> 符号; 供小地图楼层化/测试消费)
func get_layer_cells(floor_level: int) -> Dictionary:
	return _layer_cells.get(floor_level, {})


## A批6 · 小地图楼层化: 楼梯位置标记(该梯覆盖的每层各登记 footprint 格)
func get_stair_marks(floor_level: int) -> Array:
	return _stair_marks.get(floor_level, [])


## A批6 · 合闸机制: 本图是否配置了配电箱交互点(wallDecals interact=breaker)
func has_gate() -> bool:
	return _gate_map


## A批8 · 小地图目标标记: 配电箱触发点清单(无闸图返回空数组)。
## cell=触发格(供测试断言), pos=格中心米坐标(供标记绘制), floor=所属楼层。
## 供电后仍返回——由调用方按 gate_powered 换色(目标已达成, 标记转暗淡)。
func get_gate_marks() -> Array:
	var out: Array = []
	for entry in _interactables:
		var d: Dictionary = entry
		var p: Vector2 = d.get("pos", Vector2.ZERO)
		out.append({
			"cell": Vector2i(int(p.x / WorldConst.CELL), int(p.y / WorldConst.CELL)),
			"pos": p,
			"floor": int(d.get("floor", 1)),
		})
	return out


func _map_has_breaker(map_index: int) -> bool:
	for entry in GameData.level_ext_cfg.get("wallDecals", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) == map_index and str(ed.get("interact", "")) == "breaker":
			return true
	return false


## A批6 · 贴花 id 注册表查询(状态切换/测试断言用)
func get_decal(decal_id: String) -> MeshInstance3D:
	return _decals.get(decal_id, null)


## A批6 · 走进触发(wallDecals interact 扩展, 零新按键): Main._process 每帧传入
## 玩家位置与楼层; 命中触发区(水平距离 ≤ radius 且楼层匹配)即一次性触发
func tick_interactables(player_pos: Vector3, player_floor: int) -> void:
	for it in _interactables:
		if it["fired"] or int(it["floor"]) != player_floor:
			continue
		var d := Vector2(player_pos.x, player_pos.z).distance_to(it["pos"])
		if d <= float(it["radius"]):
			it["fired"] = true
			_activate_breaker()


## A批6 · 合闸: 供电标志置真 + 配电箱换"已合闸"贴图(onTexture) +
## 所有带 poweredTexture 的贴花换开启态(如庭院货运大门) + 通知 Main
func _activate_breaker() -> void:
	if gate_powered:
		return
	gate_powered = true
	for entry in GameData.level_ext_cfg.get("wallDecals", []):
		var ed: Dictionary = entry
		var swap_to := ""
		if str(ed.get("interact", "")) == "breaker":
			swap_to = str(ed.get("onTexture", ""))
		elif ed.has("poweredTexture"):
			swap_to = str(ed.get("poweredTexture", ""))
		if swap_to.is_empty() or not ResourceLoader.exists(swap_to):
			continue
		var mi := get_decal(str(ed.get("id", "")))
		if mi != null and mi.mesh is QuadMesh:
			((mi.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture = load(swap_to)
	breaker_activated.emit()


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


## A批5 · 一层隔墙(partitions): 把配置格登记进 wall_cells/buckets, 与原生墙一致的
## 网格/碰撞/小地图表现(渲染/碰撞/小地图均从 wall_cells+buckets 派生, 登记即全链路生效)。
## 已是墙的格(原生墙/同配置重复格/庭院围墙)跳过防重复建墙; LevelData 零触碰。
## cells 为 [x,y] 对数组; symbol 缺省 X(混凝土, 与仓库内部墙一致)。
func _apply_partitions(map_index: int, buckets: Dictionary) -> void:
	for entry in GameData.level_ext_cfg.get("partitions", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		var symbol := str(ed.get("symbol", "X"))
		if not WALL_TEXTURES.has(symbol):
			symbol = "X"
		for c in ed.get("cells", []):
			var cell := Vector2i(int(c[0]), int(c[1]))
			if wall_cells.has(cell):
				continue
			buckets[symbol].append(_cell_center(cell.x, cell.y))
			wall_cells[cell] = symbol


## A批5 · pickupOverrides.suppress: 需在符号扫描中跳过的拾取格集(通用, 可多条)
## A批8: suppress 兼容两种格式——单格字典 {x,y}(A批5 旧口径) 与
## 数组 [{x,y},...](批量削减, 一层补给匀往二三层)
func _pickup_suppress_cells(map_index: int) -> Dictionary:
	var out := {}
	for entry in GameData.level_ext_cfg.get("pickupOverrides", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		var s: Variant = ed.get("suppress", {})
		if s is Array:
			for it in s:
				var itd: Dictionary = it
				out[Vector2i(int(itd.get("x", -1)), int(itd.get("y", -1)))] = true
		elif s is Dictionary and not (s as Dictionary).is_empty():
			var sd: Dictionary = s
			out[Vector2i(int(sd.get("x", -1)), int(sd.get("y", -1)))] = true
	return out


## A批7 · enemyOverrides.suppress: 符号图敌人抑制格集(suppress 为数组,
## 每条 {x,y} 一格; 一层精英减量——被抑制敌人由 place 捕3层重布)
func _enemy_suppress_cells(map_index: int) -> Dictionary:
	var out := {}
	for entry in GameData.level_ext_cfg.get("enemyOverrides", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		for s in ed.get("suppress", []):
			var sd: Dictionary = s
			out[Vector2i(int(sd.get("x", -1)), int(sd.get("y", -1)))] = true
	return out


## A批7 · enemyOverrides.place: 按配置落敌({x,y,id[,floor]}); floor≥2 时
## 取该层 baseHeight 抬升(敌人原点在脚底, 落层板顶), 缺省 floor=1 地面
func _apply_enemy_overrides(map_index: int, entity_root: Node3D) -> void:
	for entry in GameData.level_ext_cfg.get("enemyOverrides", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		for p in ed.get("place", []):
			var pd: Dictionary = p
			var floor_n := maxi(1, int(pd.get("floor", 1)))
			var base_h := 0.0
			if floor_n >= 2:
				base_h = _layer_base_height(map_index, floor_n)
			var enemy: Node3D = EnemyScene.instantiate()
			enemy.position = _cell_center(int(pd.get("x", 0)), int(pd.get("y", 0))) \
				+ Vector3(0.0, base_h, 0.0)
			enemy.template_id = int(pd.get("id", 0))
			enemy.projectile_root = get_parent()
			entity_root.add_child(enemy)


## A批7 · 取指定图/楼层的层板顶高(baseHeight, 未命中返回 0)
func _layer_base_height(map_index: int, floor_n: int) -> float:
	for entry in GameData.level_ext_cfg.get("layers", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) == map_index \
				and int(ed.get("floor", 0)) == floor_n:
			return float(ed.get("baseHeight", WorldConst.WALL_HEIGHT))
	return 0.0


## A批5 · pickupOverrides.place: 按配置落拾取(符号直给, 不介入 H→e 平衡计数——
## 挪位语义=同一个急救包换位置, 全场 H/e 总量口径不变)
func _apply_pickup_overrides(map_index: int, entity_root: Node3D) -> void:
	for entry in GameData.level_ext_cfg.get("pickupOverrides", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		var p: Dictionary = ed.get("place", {})
		if p.is_empty():
			continue
		var pickup: Node3D = PickupScene.instantiate()
		pickup.position = _cell_center(int(p.get("x", 0)), int(p.get("y", 0)))
		pickup.symbol = str(p.get("symbol", "H"))
		entity_root.add_child(pickup)


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
## A批6 扩展: floor=贴附楼层(≥2 为层墙, y 抬升 (floor-1)×WALL_HEIGHT);
## id=注册进 _decals 供状态切换; interact="breaker"+radius+floor=走进触发区
## (触发格=墙格沿 face 方向前一格, 一次性, 见 tick_interactables)。
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
		var floor_n := maxi(1, int(ed.get("floor", 1)))  # A批6: 层墙贴花抬升
		var base_y := float(floor_n - 1) * WorldConst.WALL_HEIGHT
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
				pos = Vector3(cx, base_y + height * 0.5, cz - WorldConst.CELL * 0.5 - offset)
				rot_y = PI
			"S":
				pos = Vector3(cx, base_y + height * 0.5, cz + WorldConst.CELL * 0.5 + offset)
				rot_y = 0.0
			"E":
				pos = Vector3(cx + WorldConst.CELL * 0.5 + offset, base_y + height * 0.5, cz)
				rot_y = PI / 2
			"W":
				pos = Vector3(cx - WorldConst.CELL * 0.5 - offset, base_y + height * 0.5, cz)
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
		# A批6: id 注册(状态切换/测试定位) + 走进触发区登记(触发格=墙格沿 face 前一格)
		var decal_id := str(ed.get("id", ""))
		if not decal_id.is_empty():
			_decals[decal_id] = mi
		if str(ed.get("interact", "")) == "breaker":
			var step := Vector2i(0, 0)
			match face:
				"N": step = Vector2i(0, -1)
				"S": step = Vector2i(0, 1)
				"E": step = Vector2i(1, 0)
				"W": step = Vector2i(-1, 0)
			var tcell := Vector2i(x0, y0) + step
			_interactables.append({
				"id": decal_id,
				"pos": Vector2((tcell.x + 0.5) * WorldConst.CELL, (tcell.y + 0.5) * WorldConst.CELL),
				"radius": float(ed.get("radius", 1.5)),
				"floor": floor_n,
				"fired": false,
			})
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
	# A线批3/批4r: 层区天花板——2.6 平面挖掉最外层区; 逐层生成暴露区顶板
	# (层 i 的 rect 减上层 rect, 该层顶面高度——修复中间层暴露区全露天 bug);
	# 最高层整块顶板; 露台/楼梯井露天由上层 slabHoles 板洞机制天然处理
	if not _layer_rects.is_empty():
		var sorted_layers: Array = _layer_rects.duplicate()
		sorted_layers.sort_custom(func(a, b): return int(a["floor"]) < int(b["floor"]))
		var outer: Rect2i = sorted_layers[0]["rect"]
		for lrd in sorted_layers:
			var rr: Rect2i = lrd["rect"]
			if rr.get_area() > outer.get_area():
				outer = rr
		var o_x1 := outer.position.x + outer.size.x
		var o_y1 := outer.position.y + outer.size.y
		_ceiling_band(0, 0, _map_w, outer.position.y, WorldConst.WALL_HEIGHT)  # 北条
		_ceiling_band(0, o_y1, _map_w, _map_h - o_y1, WorldConst.WALL_HEIGHT)  # 南条
		_ceiling_band(0, outer.position.y, outer.position.x, outer.size.y, WorldConst.WALL_HEIGHT)  # 西条
		_ceiling_band(o_x1, outer.position.y, _map_w - o_x1, outer.size.y, WorldConst.WALL_HEIGHT)  # 东条
		for i in sorted_layers.size():
			var cur: Dictionary = sorted_layers[i]
			var cur_rect: Rect2i = cur["rect"]
			var cur_top: float = float(cur["top"])
			if i + 1 >= sorted_layers.size():
				# 最高层: 整 rect 一块顶板(沿用 Ceiling 节点名, P2a 屋檐断言兼容)
				_ceiling_band(cur_rect.position.x, cur_rect.position.y,
					cur_rect.size.x, cur_rect.size.y, cur_top, "Ceiling")
				continue
			# 中间层暴露区: 本层 rect 内非周界墙位且未被上层覆盖的格 → 逐格板 @ 本层顶面
			var upper: Rect2i = sorted_layers[i + 1]["rect"]
			for cy in range(cur_rect.position.y, cur_rect.position.y + cur_rect.size.y):
				for cxx in range(cur_rect.position.x, cur_rect.position.x + cur_rect.size.x):
					var cell := Vector2i(cxx, cy)
					var on_ring := cxx == cur_rect.position.x or cxx == cur_rect.position.x + cur_rect.size.x - 1 \
						or cy == cur_rect.position.y or cy == cur_rect.position.y + cur_rect.size.y - 1
					if on_ring or upper.has_point(cell):
						continue
					_ceiling_band(cxx, cy, 1, 1, cur_top)
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


## 天花板分片(格坐标区, 朝下平面)——层区挖洞后的环绕拼合用
func _ceiling_band(x0: int, y0: int, w: int, h: int, y_height: float,
		band_name: String = "") -> void:
	if w <= 0 or h <= 0:
		return
	var size := Vector2(float(w) * WorldConst.CELL, float(h) * WorldConst.CELL)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = load("res://assets/images/Ceiling.bmp")
	mat.uv1_scale = Vector3(size.x / WorldConst.CELL, size.y / WorldConst.CELL, 1)
	mat.backlight_enabled = false
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	if band_name.is_empty():
		band_name = "CeilingBand_%d_%d" % [x0, y0]
	mi.name = band_name
	mi.mesh = mesh
	mi.position = Vector3(
		(float(x0) + float(w) * 0.5) * WorldConst.CELL,
		y_height,
		(float(y0) + float(h) * 0.5) * WorldConst.CELL)
	mi.rotation.x = PI  # 平面朝下
	add_child(mi)

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


## 地形/楼梯 y 基准: base(绝对米, 阶梯地形任意高度起步用)优先,
## 否则 floor((floor-1)×WALL_HEIGHT), 缺省地面 0
func _terrain_base_y(cfg: Dictionary) -> float:
	if cfg.has("base"):
		return maxf(float(cfg.get("base", 0.0)), 0.0)
	return float(maxi(1, int(cfg.get("floor", 1))) - 1) * WorldConst.WALL_HEIGHT


## A批4r · 正经楼梯: 逐级 BoxMesh 台阶(纯视觉, 8级/层, 级高≤0.325m) +
## 平滑斜坡碰撞(楼梯外观+坡道行走——业界常规, 纯踏步碰撞会卡脚/滑步)。
## 底/顶落板等高衔接(碰撞几何同 ramp); 楼梯井穿板洞由 layers.slabHoles 配置
## A批5: 顶端水平外延0.15m搭楼板面(卡顶修复); N/S 向台阶堆叠方向修正(原写反)
func _build_stairs(map_index: int) -> void:
	var idx := 0
	for entry in GameData.level_ext_cfg.get("stairs", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		if _build_stair(idx, ed):
			idx += 1


func _build_stair(idx: int, cfg: Dictionary) -> bool:
	var x := int(cfg.get("x", 0))
	var y := int(cfg.get("y", 0))
	var w := maxi(1, int(cfg.get("w", 2)))   # 沿升向格数(水平长度)
	var h := maxi(1, int(cfg.get("h", 1)))   # 楼梯宽格数
	var dir := str(cfg.get("dir", "E"))
	var height := float(cfg.get("height", 0.0))
	var base_y := _terrain_base_y(cfg)
	var steps := maxi(2, int(cfg.get("steps", 8)))
	if height <= 0.0 or height > WorldConst.WALL_HEIGHT:
		push_warning("stairs 高度无效 (%.2fm), 跳过" % height)
		return false
	var along_x := dir == "E" or dir == "W"
	var span := float(w if along_x else h) * WorldConst.CELL
	var width := float(h if along_x else w) * WorldConst.CELL
	var slope_deg := rad_to_deg(atan2(height, span))
	if slope_deg >= 45.0:
		push_warning("stairs 坡度 %.1f° 超 45° 不可行走, 跳过" % slope_deg)
		return false
	if height / float(steps) > 0.325:
		push_warning("stairs 级高 %.3fm 超 0.325m 上限, 跳过" % (height / float(steps)))
		return false
	var x0 := float(x) * WorldConst.CELL
	var z0 := float(y) * WorldConst.CELL
	var cx := x0 + float(w) * WorldConst.CELL * 0.5
	var cz := z0 + float(h) * WorldConst.CELL * 0.5
	# A批5 卡顶修复(实证推导): 坡面线必须穿过板洞沿角点(洞缘平面×目标板面高度)。
	# 原方案"顶端水平外延0.15m、坡顶仍止于2.6"实测仍楔住: 胶囊(半径0.35)底球被
	# 洞缘竖直唇沿挡停(top−0.24m处, 接触法线≈65°判为墙)。修法: 低端外延5cm咬合
	# 地面不变; 坡线锚定角点(等高衔接), 顶端自角点沿坡向再外延0.15m搭进楼板——
	# 唇沿上凸仅≈8cm且接触法线≈33°<45°(floor_max_angle), 胶囊滑上而非楔住。
	# 实走验证: SmokeTest 两部楼梯×三角度上行全部到顶(站上目标板面)
	var overlap_low := 0.05
	var overlap_high := 0.15
	var low := Vector3.ZERO
	var corner := Vector3.ZERO
	match dir:
		"E":
			low = Vector3(x0 - overlap_low, base_y, cz)
			corner = Vector3(x0 + span, base_y + height, cz)
		"W":
			low = Vector3(x0 + span + overlap_low, base_y, cz)
			corner = Vector3(x0, base_y + height, cz)
		"S":
			low = Vector3(cx, base_y, z0 - overlap_low)
			corner = Vector3(cx, base_y + height, z0 + span)
		"N":
			low = Vector3(cx, base_y, z0 + span + overlap_low)
			corner = Vector3(cx, base_y + height, z0)
		_:
			push_warning("stairs 未知 dir: " + dir)
			return false
	var high := corner + (corner - low).normalized() * overlap_high

	# 碰撞: 平滑斜坡(无视觉 mesh, 视觉由台阶群承担)——楼梯外观+坡道行走
	var fwd := (high - low).normalized()
	var fwd_flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var side_w := fwd_flat.cross(Vector3.UP)
	var up := side_w.cross(fwd)
	var slope_len := (high - low).length()
	var body := StaticBody3D.new()
	body.name = "Stair_Ramp_%d" % idx
	body.transform = Transform3D(Basis(fwd, up, side_w),
		(low + high) * 0.5 - up * (TERRAIN_RAMP_THICK * 0.5))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(slope_len, TERRAIN_RAMP_THICK, width)
	col.shape = shape
	body.add_child(col)
	body.add_to_group("stairs")
	add_child(body)

	# 视觉: 逐级实心台阶盒(纯 Mesh, 不进碰撞)——第 i 级从基面堆叠到 (i+1)×级高
	var tex_path := str(cfg.get("texture", ""))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	var step_h := height / float(steps)
	var step_d := span / float(steps)
	for i in steps:
		var box := BoxMesh.new()
		var mi := MeshInstance3D.new()
		mi.name = "Stair_Step_%d_%d" % [idx, i]
		box.material = mat
		if along_x:
			# E: 自西向东逐级升高; W: 自东向西
			var s0 := x0 + (span * float(i) / float(steps) if dir == "E" \
				else span * float(steps - i - 1) / float(steps))
			box.size = Vector3(step_d, step_h * float(i + 1), width)
			mi.position = Vector3(s0 + step_d * 0.5, base_y + step_h * float(i + 1) * 0.5, cz)
		else:
			# N: 自南向北逐级升高(低端在南); S: 自北向南(低端在北)
			# A批5修复: 原 N/S 分支写反(低端堆了最高台阶——顶层台阶盒堵在楼梯入口,
			# 与上行玩家胶囊视觉干涉); 旧楼梯均为 E 向从未暴露。顶层台阶顶面恰为
			# base+height 与目标层板等高, 不凸出(胶囊半径0.35m 无干涉)
			var t0 := z0 + (span * float(i) / float(steps) if dir == "S" \
				else span * float(steps - i - 1) / float(steps))
			box.size = Vector3(width, step_h * float(i + 1), step_d)
			mi.position = Vector3(cx, base_y + step_h * float(i + 1) * 0.5, t0 + step_d * 0.5)
		mi.mesh = box
		add_child(mi)
	# A批6: 小地图楼梯标记——footprint 格登记到该梯覆盖的每个楼层(底层与顶层)
	var lo_floor := WorldConst.floor_at_y(base_y)
	var hi_floor := WorldConst.floor_at_y(base_y + height)
	for f in range(lo_floor, hi_floor + 1):
		if not _stair_marks.has(f):
			_stair_marks[f] = []
		for sy in range(y, y + h):
			for sx in range(x, x + w):
				_stair_marks[f].append(Vector2i(sx, sy))
	return true


## 实心平台: 矩形格区自所在层地板抬升至 height, 顶面可行走/承碰撞。
## floor 字段(A线批3): y 基准 = (floor-1)×WALL_HEIGHT, 缺省 1(地面)向后兼容
func _build_terrain_platform(idx: int, cfg: Dictionary) -> bool:
	var x := int(cfg.get("x", 0))
	var y := int(cfg.get("y", 0))
	var w := maxi(1, int(cfg.get("w", 1)))
	var h := maxi(1, int(cfg.get("h", 1)))
	var height := float(cfg.get("height", 0.0))
	var base_y := _terrain_base_y(cfg)
	# 上限含等号: height==WALL_HEIGHT(2.6)合法——层间坡道顶恰为上层地板
	if height <= 0.0 or height > WorldConst.WALL_HEIGHT:
		push_warning("terrain.platform 高度无效 (%.2fm), 跳过" % height)
		return false
	var center := Vector3(
		(float(x) + float(w) * 0.5) * WorldConst.CELL,
		base_y + height * 0.5,
		(float(y) + float(h) * 0.5) * WorldConst.CELL)
	_make_terrain_body("Terrain_Platform_%d" % idx, Basis.IDENTITY, center,
		Vector3(float(w) * WorldConst.CELL, height, float(h) * WorldConst.CELL),
		_terrain_material(cfg))
	return true


## 斜坡: 沿 dir(N/S/E/W, 坡顶朝向)自所在层地板抬升至 height 的坡板。
## 水平跨距 = dir 轴向格数×CELL, 坡度须 <45°(CharacterBody3D 可行走上限);
## 两端各延 5cm 咬合地面与平台消缝。floor 字段(A线批3): y 基准 = (floor-1)×WALL_HEIGHT。
func _build_terrain_ramp(idx: int, cfg: Dictionary) -> bool:
	var x := int(cfg.get("x", 0))
	var y := int(cfg.get("y", 0))
	var w := maxi(1, int(cfg.get("w", 1)))
	var h := maxi(1, int(cfg.get("h", 1)))
	var height := float(cfg.get("height", 0.0))
	var dir := str(cfg.get("dir", "E"))
	var base_y := _terrain_base_y(cfg)
	# 上限含等号: height==WALL_HEIGHT(2.6)合法——一层坡道顶恰为二层地板
	if height <= 0.0 or height > WorldConst.WALL_HEIGHT:
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
			low = Vector3(x0 - overlap, base_y, cz)
			high = Vector3(x0 + span + overlap, base_y + height, cz)
		"W":
			low = Vector3(x0 + span + overlap, base_y, cz)
			high = Vector3(x0 - overlap, base_y + height, cz)
		"S":
			low = Vector3(cx, base_y, z0 - overlap)
			high = Vector3(cx, base_y + height, z0 + span + overlap)
		"N":
			low = Vector3(cx, base_y, z0 + span + overlap)
			high = Vector3(cx, base_y + height, z0 - overlap)
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
		size: Vector3, mat: Material, group := "terrain") -> StaticBody3D:
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
	body.add_to_group(group)
	add_child(body)
	return body


## A线批3 · 层叠数据模型落地: 楼板(slabHoles 挖洞) + 层墙(grid 逐格符号,
## y 偏移 baseHeight, 沿用墙材质) + 层实体(enemies/pickups 按 baseHeight 抬升)。
## A批7 · 承载重构: 楼板/层墙渲染改 MultiMesh(每层每符号 1 实例), 碰撞改
## 行合并宽 BoxShape 挂单层 body(参照一层墙 _build_walls/_build_collision 模式)
## ——扩面至全图规模时避免逐格 StaticBody 爆节点(~28000 body)。
## custom_aabb 必须按实际格集计算(视锥剔除坑)。层墙登记 _layer_cells 不进
## 一楼 wall_cells; 碰撞 body 挂 "layers" 组 → 一楼不变式原样。无 layers 配置零变化。
const LAYER_SLAB_THICK := 0.3  # 楼板厚度(米), 顶面=baseHeight


func _build_layers(map_index: int, entity_root: Node3D) -> void:
	for entry in GameData.level_ext_cfg.get("layers", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != map_index:
			continue
		var floor_n := maxi(2, int(ed.get("floor", 2)))
		var base_h := float(ed.get("baseHeight", WorldConst.WALL_HEIGHT))
		var rect: Dictionary = ed.get("rect", {})
		var x0 := int(rect.get("x", 0))
		var y0 := int(rect.get("y", 0))
		var rw := maxi(1, int(rect.get("w", 1)))
		var rh := maxi(1, int(rect.get("h", 1)))
		var holes := {}
		for hh in ed.get("slabHoles", []):
			var hd: Dictionary = hh
			holes[Vector2i(int(hd.get("x", -1)), int(hd.get("y", -1)))] = true
		_layer_cells[floor_n] = {}
		_layer_rects.append({
			"floor": floor_n,
			"rect": Rect2i(x0, y0, rw, rh),
			"top": base_h + WorldConst.WALL_HEIGHT,
		})

		# 楼板: MultiMesh 渲染 + 行合并碰撞(单 body 挂 "layers" 组)
		var slab_mat := _terrain_material(ed)
		var slab_positions: Array[Vector3] = []
		var slab_col := StaticBody3D.new()
		slab_col.name = "Layer_SlabCol_F%d" % floor_n
		slab_col.add_to_group("layers")
		add_child(slab_col)
		for y in range(y0, y0 + rh):
			var run_x := -1  # 当前连续板段起点(-1=无)
			for x in range(x0, x0 + rw + 1):
				var solid := x < x0 + rw and not holes.has(Vector2i(x, y))
				if solid:
					if run_x < 0:
						run_x = x
					slab_positions.append(_cell_center(x, y) \
						+ Vector3(0.0, base_h - LAYER_SLAB_THICK * 0.5, 0.0))
				if not solid and run_x >= 0:
					_add_run_collision(slab_col, run_x, x - run_x, y,
						base_h - LAYER_SLAB_THICK * 0.5, LAYER_SLAB_THICK)
					run_x = -1
		if not slab_positions.is_empty():
			_add_layer_multimesh("Layer_Slabs_F%d" % floor_n, slab_positions,
				Vector3(WorldConst.CELL, LAYER_SLAB_THICK, WorldConst.CELL), slab_mat)

		# 层墙: grid 逐格符号(相对 rect 原点; 行=符号 row)
		# 渲染=每符号 1 个 MultiMesh; 碰撞=逐格共享 shape(同一层 body)——
		# 不可行合并: 楼梯井道恰在墙格接缝上(如 col32 两侧均墙), 旧逐格盒
		# 接缝法线相消可侧穿, 合并后实墙堵死楼梯(回归实证);
		# _layer_cells 仍逐格登记(is_wall 分层查询/小地图消费)
		var wall_mats := {}
		var wall_positions := {}  # 符号 -> Array[Vector3]
		var wall_col := StaticBody3D.new()
		wall_col.name = "Layer_WallCol_F%d" % floor_n
		wall_col.add_to_group("layers")
		add_child(wall_col)
		var wall_shared := BoxShape3D.new()
		wall_shared.size = Vector3(WorldConst.CELL, WorldConst.WALL_HEIGHT, WorldConst.CELL)
		var grid: Array = ed.get("grid", [])
		for gy in grid.size():
			var row_str := str(grid[gy])
			for gx in row_str.length():
				var ch := row_str[gx]
				if not WALL_TEXTURES.has(ch):
					continue
				if not wall_mats.has(ch):
					var m := StandardMaterial3D.new()
					m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					m.albedo_texture = load(WALL_TEXTURES[ch])
					wall_mats[ch] = m
				if not wall_positions.has(ch):
					wall_positions[ch] = [] as Array[Vector3]
				var cx := x0 + gx
				var cy := y0 + gy
				var pos := _cell_center(cx, cy) \
					+ Vector3(0.0, base_h + WorldConst.WALL_HEIGHT * 0.5, 0.0)
				(wall_positions[ch] as Array).append(pos)
				_layer_cells[floor_n][Vector2i(cx, cy)] = ch
				var wcol := CollisionShape3D.new()
				wcol.shape = wall_shared
				wcol.position = pos
				wall_col.add_child(wcol)
		for sym in wall_positions:
			_add_layer_multimesh("Layer_Walls_F%d_%s" % [floor_n, sym],
				wall_positions[sym],
				Vector3(WorldConst.CELL, WorldConst.WALL_HEIGHT, WorldConst.CELL),
				wall_mats[sym])

		# 层实体: 敌人/拾取物按 baseHeight 抬升(敌人原点在脚底, 落板顶)
		for e in ed.get("enemies", []):
			var edd: Dictionary = e
			var enemy: Node3D = EnemyScene.instantiate()
			enemy.position = _cell_center(int(edd.get("x", 0)), int(edd.get("y", 0))) \
				+ Vector3(0.0, base_h, 0.0)
			enemy.template_id = int(edd.get("id", 0))
			enemy.projectile_root = get_parent()
			entity_root.add_child(enemy)
		for p in ed.get("pickups", []):
			var pd: Dictionary = p
			var pickup: Node3D = PickupScene.instantiate()
			pickup.position = _cell_center(int(pd.get("x", 0)), int(pd.get("y", 0))) \
				+ Vector3(0.0, base_h, 0.0)
			pickup.symbol = str(pd.get("symbol", "A"))
			entity_root.add_child(pickup)


## A批7 · 层几何 MultiMesh 渲染: custom_aabb 按实际实例包围盒计算(防视锥剔除)
func _add_layer_multimesh(mm_name: String, positions: Array, box_size: Vector3,
		mat: Material) -> void:
	if positions.is_empty():
		return
	var half := box_size * 0.5
	var minc: Vector3 = positions[0]
	var maxc: Vector3 = positions[0]
	for p in positions:
		minc = minc.min(p)
		maxc = maxc.max(p)
	var box := BoxMesh.new()
	box.size = box_size
	var mm := MultiMeshInstance3D.new()
	mm.name = mm_name
	mm.multimesh = MultiMesh.new()
	mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mm.multimesh.mesh = box
	mm.multimesh.custom_aabb = AABB(minc - half, maxc - minc + box_size)
	mm.material_override = mat
	mm.multimesh.instance_count = positions.size()
	for i in positions.size():
		mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
	add_child(mm)


## A批7 · 行合并碰撞: 一行连续 run_len 格合并为一个宽 BoxShape(挂层碰撞 body)
func _add_run_collision(body: StaticBody3D, run_x0: int, run_len: int, row_y: int,
		center_y: float, thick: float) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(float(run_len) * WorldConst.CELL, thick, WorldConst.CELL)
	col.shape = shape
	col.position = Vector3(
		(float(run_x0) + float(run_len) * 0.5) * WorldConst.CELL,
		center_y,
		(float(row_y) + 0.5) * WorldConst.CELL)
	body.add_child(col)


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
