extends Node
## SmokeTest — headless 端到端自检（可长期保留作回归测试）
## 覆盖: 世界生成(含a/w移除与防护服生成) / 武器持有模型 / 武器拾取 /
##       Q+滚轮循环切换 / 金币拾取 / 满血拒收急救包 / 防护服充能与优先承伤 /
##       通用升级组件(顺序拦截+一二三级数值+射速叠加+满级拒收) /
##       霰弹枪(泵动配置/拾取/单发弹丸数/12号霰弹补给) /
##       子弹命中敌人 / 弹药消耗 / 武器动画 / 敌人死亡流程 / 终点旗通关判定 /
##       P2a 夜空室外区(夜空环境/庭院外扩围墙环+门洞/露天格/天花板保留/小地图跟随) /
##       阶段一布景(装饰外立面高度/庭院道具数量/布景零逻辑侵入不变式) /
##       AE-219敌人(三模板贴图切换/双攻击帧加载/巨型移速/孢子弹道精灵化) /
##       EDAA世界观化(简报提灯/2026当代/敌名三型/混凝土仓库墙/徽记菜单背景) /
##       菜单身份(徽记完整容下不出界/标题静默之前) / HUD弹药口径显示(9×19mm/12号霰弹) /
##       A批5 西北大厅塔楼(迷宫式二三层/楼梯间/卡顶修复/一层隔墙/急救包挪位/BFS连通性)
##       A批6 楼梯2朝向修复(dir=N+三层落点开洞)/小地图楼层化(按y切层+楼梯标记) /
##       合闸机制(配电箱走进触发/大门贴花切换/撤离闭锁) / 物资重排(W→2F, T+U+s×2→3F,
##       map0 删 v, 巨宿主镇守) / HUD 目标行(narrative.gate 口径) /
##       A批6.1 小地图视觉修订(楼梯间整格琥珀色块/撤离信标闭锁态红环可视化) /
##       A批7 迷宫扩面(二三层全境 8378/8398 格≈115%≥70%+全连通BFS) /
##       enemyOverrides 精英重布(1F id2 40→10, 24×3F+6×2F) / 楼层角标 1F/2F/3F /
##       A批8 补给跨楼层重平衡(1F 383→199 / 2F 27→105 / 3F 28→115, 密度 5.26→2.73
##       与 0.32→1.25/1.37; h 生命上限升级每层截断 3 防血上限 100→620) /
##       孢子囊+人类宿主跨层布防(1F id0 28→20 id1 68→36, 2F +38 3F +35) /
##       小地图目标标记(W/T/u/U/v 五色菱形 + 电闸橙红方块, 跨层半透明区分)
## 运行: godot --path godot --headless res://scenes/tests/SmokeTest.tscn

var _frame := 0
var _fail := false

var _main: Node
var _player: Node
var _level: Node
var _entities: Node3D

var _enemy_target: Node
var _enemy_hp_before := 0
var _ammo_before := 0
var _noop_test_done := false
var _cycle_test_done := false
var _components_test_done := false
var _shotgun_test_done := false
var _health_test_done := false
var _death_test_done := false
var _flag_test_done := false
var _p2b_climb_base_y := 0.0
var _y_enemy: Node = null
var _y_enemy_start_y := 0.0
var _campaign_test_done := false
var _layer_test_done := false
var _minimap_floor_test_done := false  # A批6
var _gate_static_test_done := false    # A批6


## A批5 · 塔楼静态断言: 层几何(楼板+层墙)与配置一致 / 可走格从 grid+slabHoles 推导 /
## is_wall 分层查询 / partitions 隔墙入墙格集(不变式改为从配置推导) /
## 一层连通性 BFS / pickupOverrides 抑制与放置
func _test_layers_static() -> void:
	var l2: Dictionary = {}
	var l3: Dictionary = {}
	for l in GameData.level_ext_cfg.get("layers", []):
		var ld: Dictionary = l
		if int(ld.get("map", -1)) != 0:
			continue
		if int(ld.get("floor", 0)) == 2:
			l2 = ld
		elif int(ld.get("floor", 0)) == 3:
			l3 = ld
	_report(not l2.is_empty() and not l3.is_empty(),
		"layers 配置就绪(西北大厅塔楼 二/三层)")
	if l2.is_empty() or l3.is_empty():
		return

	# A批7 · 层几何承载重构: 楼板/层墙渲染改 MultiMesh, 碰撞改行合并宽 shape
	# 挂单层 body → "layers" 组每层恰 2 个碰撞 body(板+墙), 与配置层数一致
	var layer_count := 0
	for l in GameData.level_ext_cfg.get("layers", []):
		var ld: Dictionary = l
		if int(ld.get("map", -1)) == 0:
			layer_count += 1
	var layers_nodes := get_tree().get_nodes_in_group("layers")
	_report(layers_nodes.size() == layer_count * 2,
		"层几何碰撞: %d body (每层 板+墙 各 1, 共 %d 层, A批7 行合并承载)"
		% [layers_nodes.size(), layer_count])

	# 可走格: grid 空格数 − 板洞数。A批7 迷宫扩面: rect 扩至全境 (0,0,168,62),
	# 断言基准=生成器 BFS 实证(自楼梯落点全连通): F2 8378 / F3 8398,
	# 分母=一层室内全部可走面积 7284(探针实测), 达标 ≥70%(实际 ≈115%)
	for ld in [l2, l3]:
		var spaces := 0
		for row in ld.get("grid", []):
			for ch in str(row):
				if ch == " ":
					spaces += 1
		var walk := spaces - (ld.get("slabHoles", []) as Array).size()
		var fn := int(ld.get("floor", 0))
		var expect_walk := 8378 if fn == 2 else 8398
		_report(walk == expect_walk and walk >= 5098,
			"%d层可走格: %d (期望 %d = 一层室内7284格的 %.1f%%, ≥70%%)"
			% [fn, walk, expect_walk, walk / 7284.0 * 100.0])

	# A批7 · 三层连通性 BFS: 楼梯2 改 N 向后落点=(31,20), 扩面全境后
	# 全部可走格(含旧塔楼区块+新迷宫区, 经周界门洞连通)自此可达
	var holes3 := {}
	for hh in l3.get("slabHoles", []):
		var hd: Dictionary = hh
		holes3[Vector2i(int(hd.get("x", -1)), int(hd.get("y", -1)))] = true
	var walls3: Dictionary = _level.get_layer_cells(3)
	var seen3 := {Vector2i(31, 20): true}
	var queue3: Array[Vector2i] = [Vector2i(31, 20)]
	while not queue3.is_empty():
		var cur: Vector2i = queue3.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if seen3.has(n) or walls3.has(n) or holes3.has(n):
				continue
			if n.x < 0 or n.x > 167 or n.y < 0 or n.y > 61:
				continue
			seen3[n] = true
			queue3.append(n)
	_report(seen3.size() == 8398,
		"三层连通性: (31,20) BFS 可达 %d 格 (期望 8398 = 全部可走格, 楼梯2落点全连通)"
		% seen3.size())

	# 分层墙查询: (1,17) 塔西北角——一楼大厅地板 / 二层墙 / 三层墙
	_report(not _level.is_wall(1, 17, 1) and _level.is_wall(1, 17, 2)
		and _level.is_wall(1, 17, 3),
		"is_wall 分层查询: (1,17) 一楼可走 / 二三层塔角墙")
	_report(not _level.is_wall(17, 24, 2) and not _level.is_wall(17, 24, 3),
		"is_wall 分层查询: (17,24) 二三层室内空")

	# A批5 · partitions 隔墙: 实际新增格(去重且原为符号图地板)全部进 wall_cells。
	# 一楼墙格不变式 = 4197(原生符号墙4140 − 庭院门洞2 + 庭院围墙59) + partitions
	# 实际新增数。探针实证新增=10 → 4207(设计稿"11格/4208"系把西墙与北墙的
	# 交叠格计了两次; 且其坐标口径按首条内容行为row0, 运行时首行为空行需+1)
	var part_new := _partition_new_cells()
	_report(part_new.size() == 10,
		"partitions 实际新增墙格: %d (期望 10, 探针实证全为空地格)" % part_new.size())
	_report(_level.wall_cells.size() == 4197 + part_new.size(),
		"一楼墙格数: %d (期望 %d = 4197 + partitions新增, 层墙不污染 wall_cells)"
		% [_level.wall_cells.size(), 4197 + part_new.size()])
	var part_in := true
	for c in part_new:
		if not _level.is_wall(c.x, c.y):
			part_in = false
	_report(part_in, "partitions 隔墙格全部登记进 wall_cells(网格/碰撞/小地图同源)")
	_report(not _level.is_wall(29, 24), "井道门洞 (29,24) 保持开通")

	# 一层连通性: 自 (28,23)(大厅井道门旁) BFS 全部非墙格(含庭院, 界 0..191×0..67)。
	# 期望 7523 = 探针实测(2026-08-30): 无隔墙 7533 − 新增10格墙, 恰好无失联;
	# 井道内净区经门洞 (29,24) 仍全可达(爬楼梯路径)
	var start := Vector2i(28, 23)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x < 0 or n.x > 191 or n.y < 0 or n.y > 67:
				continue
			if seen.has(n) or _level.wall_cells.has(n):
				continue
			seen[n] = true
			queue.append(n)
	_report(seen.size() == 7523,
		"一层连通性: (28,23) BFS 可达 %d 格 (期望 7523 含庭院, 井道围合后大厅无失联)"
		% seen.size())
	var well_ok := true
	for wy in range(22, 28):
		for wx in range(30, 33):
			if not seen.has(Vector2i(wx, wy)):
				well_ok = false
	_report(well_ok, "井道内净区 cols30-32×rows22-27 经门洞全可达")

	# A批5 · pickupOverrides: (153,31) 符号图 H 已抑制 / (150,31) 配置 H 已放置
	# (设计稿写 (153,30)/(150,30), 其 y 口径按首条内容行为 row0, 运行时需 +1——
	# 探针实证 (153,30)='X' 而 (153,31)='H')
	var at_suppress := false
	var at_place := false
	for c in _entities.get_children():
		if not ("symbol" in c):
			continue
		var pc := Vector2i(int(c.global_position.x / WorldConst.CELL),
			int(c.global_position.z / WorldConst.CELL))
		if pc == Vector2i(153, 31):
			at_suppress = true
		elif pc == Vector2i(150, 31) and c.symbol == "H":
			at_place = true
	_report(not at_suppress, "pickupOverrides: (153,31) 旧坡道位急救包已抑制")
	_report(at_place, "pickupOverrides: (150,31) 急救包已按配置放置(H)")


## partitions 实际新增格集: 配置格去重且原为符号图地板(已是墙的格被生成器跳过)。
## 断言基准与生成器逻辑同口径——数量从配置+符号图推导, 不硬编码
func _partition_new_cells() -> Array[Vector2i]:
	var rows := (LevelData.MAPS[0] as String).split("\n")
	var seen := {}
	var out: Array[Vector2i] = []
	for entry in GameData.level_ext_cfg.get("partitions", []):
		var ed: Dictionary = entry
		if int(ed.get("map", -1)) != 0:
			continue
		for c in ed.get("cells", []):
			var cell := Vector2i(int(c[0]), int(c[1]))
			if seen.has(cell):
				continue
			seen[cell] = true
			if cell.y < 0 or cell.y >= rows.size() \
					or cell.x < 0 or cell.x >= (rows[cell.y] as String).length():
				continue
			if not "XMSG".contains(rows[cell.y][cell.x]):
				out.append(cell)
	return out


## A批6 · 层落位核验辅助: 存在符号匹配且位于指定格/指定层高的拾取物,
## 且该格在对应楼层为可走地板(非层墙、非板洞)
func _assert_layer_entity(symbol: String, x: int, y: int, base_h: float, label: String) -> void:
	var f := int(base_h / WorldConst.WALL_HEIGHT) + 1
	var cell := Vector2i(x, y)
	var floor_ok: bool = not _level.is_wall(x, y, f)
	for l in GameData.level_ext_cfg.get("layers", []):
		var ld: Dictionary = l
		if int(ld.get("map", -1)) != 0 or int(ld.get("floor", 0)) != f:
			continue
		for hh in ld.get("slabHoles", []):
			var hd: Dictionary = hh
			if Vector2i(int(hd.get("x", -1)), int(hd.get("y", -1))) == cell:
				floor_ok = false
	var found := false
	for c in _entities.get_children():
		if not ("symbol" in c) or c.symbol != symbol:
			continue
		var pc := Vector2i(int(c.global_position.x / WorldConst.CELL),
			int(c.global_position.z / WorldConst.CELL))
		if pc == cell and absf(float(c.global_position.y) - base_h) < 0.1:
			found = true
	_report(found and floor_ok,
		"%s (落位=%s, 层地板格=%s)" % [label, "命中" if found else "缺失", "是" if floor_ok else "否"])


## A批5/批6 · 塔楼几何静态断言: 二/三层同 footprint(无退台) / 楼板 2.60/5.20 射线 /
## 楼梯(2部×8级/级高0.325/贴图/梯顶与目标层板等高衔接/顶端外延0.15卡顶修复实证/
## 顶层台阶不凸出且位于梯顶端) / 顶板 7.80 对齐外立面 / 塔区2.6天花板已挖 /
## 楼梯井头空 / A批6: 楼梯2 dir=N(低端 row22 南缘, 三层落点 (31-32,20)) +
## 三层 row20 cols30-32 开洞。(两部楼梯三角度实走上行由 _test_layer_climb 帧251 覆盖)
func _test_third_floor_static() -> void:
	var l2: Dictionary = {}
	var l3: Dictionary = {}
	for l in GameData.level_ext_cfg.get("layers", []):
		var ld: Dictionary = l
		if int(ld.get("map", -1)) != 0:
			continue
		if int(ld.get("floor", 0)) == 2:
			l2 = ld
		elif int(ld.get("floor", 0)) == 3:
			l3 = ld
	_report(not l3.is_empty(), "三层配置就绪(西北大厅塔楼顶层)")
	if l3.is_empty() or l2.is_empty():
		return
	var r2: Rect2i = Rect2i(
		int((l2.get("rect", {}) as Dictionary).get("x", 0)),
		int((l2.get("rect", {}) as Dictionary).get("y", 0)),
		int((l2.get("rect", {}) as Dictionary).get("w", 0)),
		int((l2.get("rect", {}) as Dictionary).get("h", 0)))
	var r3: Rect2i = Rect2i(
		int((l3.get("rect", {}) as Dictionary).get("x", 0)),
		int((l3.get("rect", {}) as Dictionary).get("y", 0)),
		int((l3.get("rect", {}) as Dictionary).get("w", 0)),
		int((l3.get("rect", {}) as Dictionary).get("h", 0)))
	_report(r2 == r3,
		"二/三层同 footprint(无退台): (%d,%d %dx%d)"
		% [r3.position.x, r3.position.y, r3.size.x, r3.size.y])

	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	var base2 := float(l2.get("baseHeight", 2.6))
	var base3 := float(l3.get("baseHeight", 5.2))
	# 楼板顶面射线 @(17,24)——两层 grid 均为室内空格且非板洞(探针逐格核验)
	var px := 17.5 * WorldConst.CELL
	var pz := 24.5 * WorldConst.CELL
	var hit3 := _ray_down(space, Vector3(px, base3 + 3.0, pz), base3 - 1.0)
	_report(absf(hit3 - base3) < 0.05,
		"三层楼板顶面高度: %.2fm (期望 %.2fm; 同证二层室内上方被三层板完整覆盖)"
		% [hit3, base3])
	# 二层板: 自三层板底(4.9)之下起射 → 命中二层板顶 2.6
	var hit2 := _ray_down(space, Vector3(px, base3 - 0.4, pz), 0.0)
	_report(absf(hit2 - base2) < 0.05,
		"二层楼板顶面高度: %.2fm (期望 %.2fm)" % [hit2, base2])

	# 楼梯断言: 配置就绪/贴图可加载/级高合规/台阶与碰撞体数量/梯顶等高衔接
	var map0_stairs: Array = []
	var expect_steps := 0
	for sd in GameData.level_ext_cfg.get("stairs", []):
		var sdd: Dictionary = sd
		if int(sdd.get("map", -1)) != 0:
			continue
		map0_stairs.append(sdd)
		expect_steps += maxi(2, int(sdd.get("steps", 8)))
	_report(map0_stairs.size() == 2, "楼梯配置就绪(一→二/二→三各一部)")
	var stair_tex_ok := true
	for sdd in map0_stairs:
		if not ResourceLoader.exists(str(sdd.get("texture", ""))):
			stair_tex_ok = false
	_report(stair_tex_ok, "楼梯贴图可加载(Stair Steps)")
	var step_nodes := 0
	for n in _level.get_children():
		if str(n.name).begins_with("Stair_Step_"):
			step_nodes += 1
	_report(step_nodes == expect_steps,
		"楼梯台阶: %d 级 (期望 %d, 8级×2部)" % [step_nodes, expect_steps])
	var stair_bodies := get_tree().get_nodes_in_group("stairs")
	_report(stair_bodies.size() == 2, "楼梯平滑斜坡碰撞体: %d (期望 2)" % stair_bodies.size())
	for sdd in map0_stairs:
		var step_h := float(sdd.get("height", 2.6)) / float(maxi(2, int(sdd.get("steps", 8))))
		_report(step_h <= 0.325, "楼梯级高 %.3fm ≤ 0.325m 上限 (base=%.1f)"
			% [step_h, float(sdd.get("base", 0.0))])
	# 梯顶与目标层板等高衔接: 楼梯1(N向, 顶在北缘 z=48) 射线落于板洞内缘0.1m处
	# 仍命中 2.6(顶端外延0.15m 搭上二层板面); 楼梯2(A批6改N向, 顶在北缘 z=42) 同理 5.2
	for i in map0_stairs.size():
		var sdd: Dictionary = map0_stairs[i]
		var sbase := float(sdd.get("base", 0.0))
		var stop := sbase + float(sdd.get("height", 2.6))
		var sx_mid := (float(int(sdd.get("x", 0))) + 1.0) * WorldConst.CELL
		var sdir := str(sdd.get("dir", "N"))
		var z0 := float(int(sdd.get("y", 0))) * WorldConst.CELL
		var span := float(int(sdd.get("h", 2))) * WorldConst.CELL  # N/S 向: 沿升向=h格
		var z_top := z0 if sdir == "N" else z0 + span
		var z_probe := z_top - 0.1 if sdir == "N" else z_top + 0.1
		var hit_top := _ray_down(space, Vector3(sx_mid, stop + 1.5, z_probe), sbase - 0.5)
		_report(absf(hit_top - stop) < 0.1,
			"楼梯%d(base=%.1f)顶与目标层板等高衔接: %.2fm (期望 %.2fm)"
			% [i, sbase, hit_top, stop])
		# 卡顶修复实证: 斜坡碰撞体顶端沿升向越过板洞边缘 ≥0.1m(外延0.15m)
		var body := _level.get_node_or_null("Stair_Ramp_%d" % i) as StaticBody3D
		if body == null:
			_report(false, "楼梯%d 斜坡碰撞体缺失" % i)
			continue
		var half_len: float = ((body.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.x * 0.5
		var tip: Vector3 = body.global_transform.origin \
			+ body.global_transform.basis.x * half_len
		var tip_ok: bool = tip.z <= z0 - 0.05 if sdir == "N" else tip.z >= z0 + span + 0.05
		_report(tip_ok, "楼梯%d 斜坡顶端外延越过板洞边缘: tip.z=%.3f (边缘 %.2f)"
			% [i, tip.z, z_top])
		# 顶层台阶可视体: 位于梯顶端(N/S堆叠方向修正实证)且顶面与目标层板
		# 精确等高——不凸出板面, 与上行玩家胶囊(半径0.35m)无干涉
		var steps_n := maxi(2, int(sdd.get("steps", 8)))
		var mi := _level.get_node_or_null("Stair_Step_%d_%d" % [i, steps_n - 1]) as MeshInstance3D
		if mi == null:
			_report(false, "楼梯%d 顶层台阶节点缺失" % i)
			continue
		var box := mi.mesh as BoxMesh
		var step_d := span / float(steps_n)
		_report(absf(float(mi.position.z) - (z_top + (0.5 * step_d if sdir == "N" else -0.5 * step_d))) < step_d,
			"楼梯%d 顶层台阶位于梯顶端 (z=%.2f, 梯顶 %.2f, N/S堆叠方向正确)"
			% [i, mi.position.z, z_top])
		_report(absf(float(mi.position.y) + box.size.y * 0.5 - stop) < 0.01,
			"楼梯%d 顶层台阶顶面 %.3f == 目标层板 %.3f (不凸出, 胶囊无干涉)"
			% [i, float(mi.position.y) + box.size.y * 0.5, stop])

	# 层顶板 7.8 与装饰外立面总高精确对齐(顶板为纯视觉 Mesh, 查节点位置而非射线)
	var top3 := base3 + WorldConst.WALL_HEIGHT
	var ceiling_mi: MeshInstance3D = _level.get_node_or_null("Ceiling") as MeshInstance3D
	_report(ceiling_mi != null and absf(float(ceiling_mi.position.y) - top3) < 0.05,
		"三层顶板: %.2fm (期望 %.2fm)"
		% [float(ceiling_mi.position.y) if ceiling_mi else -99.0, top3])
	var fcfg: Dictionary = GameData.level_ext_cfg.get("facade", {})
	var facade_top: float = WorldConst.WALL_HEIGHT \
		+ float(fcfg.get("stories", 2)) * float(fcfg.get("storyHeight", WorldConst.WALL_HEIGHT))
	_report(absf(top3 - facade_top) < 0.01,
		"三层顶板 %.2fm 与装饰外立面总高 %.2fm 精确对齐(回头视线三层结构无缝)" % [top3, facade_top])

	# 塔区 2.6m 天花板已挖: 所有 2.6 高的天花板分片(视觉 Mesh)不得与塔区 rect 重叠
	var dug_ok := true
	for n in _level.get_children():
		var cmi := n as MeshInstance3D
		if cmi == null or not str(cmi.name).begins_with("Ceiling"):
			continue
		if absf(float(cmi.position.y) - WorldConst.WALL_HEIGHT) > 0.05:
			continue
		var pm := cmi.mesh as PlaneMesh
		if pm == null:
			continue
		var bw: float = pm.size.x / WorldConst.CELL
		var bh: float = pm.size.y / WorldConst.CELL
		var band := Rect2i(
			int(cmi.position.x / WorldConst.CELL - bw * 0.5 + 0.01),
			int(cmi.position.z / WorldConst.CELL - bh * 0.5 + 0.01),
			int(bw + 0.01), int(bh + 0.01))
		if band.intersects(r2):
			dug_ok = false
	_report(dug_ok, "塔区 2.6m 天花板已挖(分片与塔 rect 无重叠)")
	# 板洞开: 楼梯1井格 (31,24) 自 2.7 下射不命中 2.6 板(命中梯坡面≈1.9)
	var hit_hole := _ray_down(space, Vector3(31.5 * WorldConst.CELL, 2.7, 24.5 * WorldConst.CELL), 0.0)
	_report(hit_hole < 2.55 and hit_hole > 0.5,
		"一→二楼梯井板洞开: 命中 %.2fm (<2.6, 梯坡面)" % hit_hole)
	# 楼梯井头空: 梯顶之上净空——楼梯1: 2.6→三层板底4.9; 楼梯2: 5.2→顶板7.8
	var hit_head1 := _ray_down(space, Vector3(31.5 * WorldConst.CELL, 4.85, 24.5 * WorldConst.CELL), 0.0)
	_report(hit_head1 < 2.6 and hit_head1 > 0.0,
		"楼梯1井道头空: 2.6→4.9 无阻挡 (命中 %.2fm)" % hit_head1)
	var hit_head2 := _ray_down(space, Vector3(31.5 * WorldConst.CELL, 7.7, 21.5 * WorldConst.CELL), 3.0)
	_report(hit_head2 < 5.2 and hit_head2 > 3.0,
		"楼梯2井道头空: 5.2→7.8 无阻挡 (命中 %.2fm)" % hit_head2)

	# A批6 · 楼梯2 dir=N 配套: 三层 row20 cols30-32 开为地板(落点 (31-32,20)),
	# 保留 col29 井道西墙与 col33 塔边界墙; 落点格有楼板(非板洞)承接
	_report(_level.is_wall(29, 20, 3) and _level.is_wall(33, 20, 3),
		"三层 row20: col29/col33 墙保留(井道西界/塔边界)")
	_report(not _level.is_wall(30, 20, 3) and not _level.is_wall(31, 20, 3)
		and not _level.is_wall(32, 20, 3),
		"三层 row20: cols30-32 开为地板(楼梯2 落点走廊)")
	var hit_land := _ray_down(space, Vector3(31.5 * WorldConst.CELL, 7.0, 20.5 * WorldConst.CELL), 4.0)
	_report(absf(hit_land - base3) < 0.05,
		"三层落点 (31,20) 楼板承接: %.2fm (期望 %.2fm)" % [hit_land, base3])


## 垂直向下射线辅助: 返回命中 y(未命中返回 -99)
func _ray_down(space: PhysicsDirectSpaceState3D, from: Vector3, to_y: float) -> float:
	var ray := PhysicsRayQueryParameters3D.create(
		from, Vector3(from.x, to_y, from.z))
	ray.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return -99.0
	return float(hit["position"].y)


## A批6 · 小地图楼层化: 楼层判定公式(与交互点同口径 WorldConst.floor_at_y) /
## 逐层墙格集与生成器一致(1F=wall_cells 含 partitions; 2F/3F=层 grid 墙格) /
## 非当前楼层墙体不画(每层纹理独立) / 实切换(玩家 y 0→2.6→5.2→复位) /
## 楼梯标记登记。帧位20, 玩家位置用后复位(不干扰串行传送测试)
func _test_minimap_floors() -> void:
	var mm: Node = _main.get_node("HUD").get_node_or_null("MiniMap")
	if mm == null:
		_report(false, "小地图节点缺失(楼层化)")
		_minimap_floor_test_done = true
		return
	_report(WorldConst.floor_at_y(0.0) == 1 and WorldConst.floor_at_y(2.6) == 2
		and WorldConst.floor_at_y(5.2) == 3,
		"楼层判定: y=0/2.6/5.2 → 1/2/3 层 (clamp 上限 3)")
	# 墙格集一致(集合语义, 不依赖顺序)
	var ok1: bool = mm.floor_cells(1).size() == _level.wall_cells.size()
	for c in mm.floor_cells(1):
		if not _level.wall_cells.has(c):
			ok1 = false
	_report(ok1, "小地图 1F 墙格集 == wall_cells(含 partitions): %d 格" % mm.floor_cells(1).size())
	var l2c: Dictionary = _level.get_layer_cells(2)
	var l3c: Dictionary = _level.get_layer_cells(3)
	var ok2: bool = mm.floor_cells(2).size() == l2c.size()
	for c in mm.floor_cells(2):
		if not l2c.has(c):
			ok2 = false
	var ok3: bool = mm.floor_cells(3).size() == l3c.size()
	for c in mm.floor_cells(3):
		if not l3c.has(c):
			ok3 = false
	_report(ok2 and ok3, "小地图 2F/3F 墙格集 == 层 grid 墙格: %d/%d 格"
		% [mm.floor_cells(2).size(), mm.floor_cells(3).size()])
	# 非当前楼层墙体不画: 楼层纹理各自独立——partitions 北墙格 (31,21)
	# (一层隔墙, 二层同位为地板) 仅应出现在 1F 纹理
	var tex1: ImageTexture = mm.get("_floor_texes")[1]
	var tex2: ImageTexture = mm.get("_floor_texes")[2]
	var img1 := tex1.get_image()
	var img2 := tex2.get_image()
	_report(img1.get_pixelv(Vector2i(31, 21)).a > 0.5 and img2.get_pixelv(Vector2i(31, 21)).a < 0.5,
		"非当前楼层墙体不画: partitions 墙格 (31,21) 仅在 1F 纹理")
	# 楼梯标记: 楼梯1 footprint 登记到 1F/2F, 楼梯2 登记到 2F/3F
	var sm: Dictionary = {}
	for f in [1, 2, 3]:
		sm[f] = {}
		for c in _level.get_stair_marks(f):
			sm[f][c] = true
	_report(sm[1].has(Vector2i(31, 24)) and sm[2].has(Vector2i(31, 24))
		and sm[2].has(Vector2i(31, 21)) and sm[3].has(Vector2i(31, 21)),
		"楼梯标记: 梯1@(31-32,24-25)→1F/2F, 梯2@(31-32,21-22)→2F/3F")
	# A批6.1: 撤离闭锁态小地图口径——map0 有闸未通电 → 信标闭锁态(红色空心环)
	_report(mm.flag_locked(), "小地图闭锁态: map0 有闸未通电 → 撤离信标锁定表现")
	# 实切换: 模拟玩家脚部 y 在 0/2.6/5.2, MiniMap 当前楼层 1/2/3 且纹理随切。
	# 在庭院空旷点 (172,33) 进行——Pickup 触发半径 2.0m, 塔楼落位区做 y 切换会
	# 误收 T/U/s(实证: 帧20 玩家在 (5,27) 上空 5.26m 把 2m 外的霰弹枪 T 吸走了)
	var saved_pos: Vector3 = _player.global_position
	var saved_vel: Vector3 = _player.velocity
	var switch_ok := true
	var fail_at := 0
	for tc in [[0.65, 1], [2.66, 2], [5.26, 3]]:
		# 轮询至切换生效(上限10帧, 与 Q 切换 flake 加固同法): 每帧钉住 y
		# 防重力下落漂移; headless 下空闲帧与物理帧节奏不稳
		var phase_ok := false
		for i in 10:
			_player.velocity = Vector3.ZERO
			_player.global_position = Vector3(345.0, float(tc[0]), 67.0)
			await get_tree().process_frame
			if mm.current_floor() == int(tc[1]) \
					and mm.get("_wall_tex") == (mm.get("_floor_texes") as Dictionary)[int(tc[1])] \
					and mm.floor_badge() == "%dF" % int(tc[1]):
				phase_ok = true
				break
		if not phase_ok:
			switch_ok = false
			fail_at = int(tc[1])
	# 复位后楼层跟随实际位置(帧12 起玩家在二层 W 落点 → 回 2F);
	# 需等 MiniMap._process 跑过(空闲帧)再读
	_player.velocity = Vector3.ZERO
	_player.global_position = saved_pos
	_player.velocity = saved_vel
	var back_ok := false
	for i in 10:
		await get_tree().process_frame
		if mm.current_floor() == WorldConst.floor_at_y(saved_pos.y):
			back_ok = true
			break
	_report(switch_ok and back_ok,
		"小地图楼层实切换: y=0.65/2.66/5.26 → 1/2/3F 纹理随切+角标 1F/2F/3F 随显, 复位跟随实际楼层 (fail_at=%d, back=%s)"
		% [fail_at, str(back_ok)])
	_minimap_floor_test_done = true


## A批6 · 合闸机制静态断言: 贴图可加载 / 本图有闸未通电 / 触发区配置口径 /
## 贴花 id 注册与初始贴图 / HUD 目标行(简报后常驻)=narrative.gate.objectiveLocked /
## 楼层化区域提示已登记。帧位21(简报已于帧2 dismiss)
func _test_gate_static() -> void:
	_report(ResourceLoader.exists("res://assets/images/Breaker Off.bmp")
		and ResourceLoader.exists("res://assets/images/Breaker On.bmp"),
		"配电箱贴图可加载(Breaker Off/On)")
	_report(ResourceLoader.exists("res://assets/images/Gate Cargo Open.bmp"),
		"大门开启态贴图可加载(Gate Cargo Open)")
	_report(_level.has_gate() and not _level.gate_powered,
		"合闸机制: map0 有配电箱交互点, 初始未通电")
	var its: Array = _level.get("_interactables")
	_report(its.size() == 1 and int(its[0]["floor"]) == 2
		and absf(float((its[0]["pos"] as Vector2).x) - 31.0) < 0.01
		and absf(float((its[0]["pos"] as Vector2).y) - 37.0) < 0.01
		and absf(float(its[0]["radius"]) - 1.5) < 0.01,
		"配电箱触发区: (15,18) 半径1.5m 楼层=2 (走进触发, 零新按键)")
	var br: MeshInstance3D = _level.get_decal("breaker_2f")
	var gt: MeshInstance3D = _level.get_decal("gate_cargo")
	_report(br != null and gt != null, "贴花 id 注册: breaker_2f / gate_cargo")
	if br != null:
		var btex := ((br.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture
		_report(btex != null and btex.resource_path.ends_with("Breaker Off.bmp"),
			"配电箱初始贴图=Breaker Off(红灯)")
		_report(absf(br.position.y - (WorldConst.WALL_HEIGHT + WorldConst.WALL_HEIGHT * 0.5)) < 0.05,
			"配电箱贴花挂在二层墙高: y=%.2f (期望 3.9)" % br.position.y)
	if gt != null:
		var gtex := ((gt.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture
		_report(gtex != null and gtex.resource_path.ends_with("Gate Cargo.bmp"),
			"大门初始贴图=Gate Cargo(关门)")
	# HUD 目标行(数据源 narrative.gate, 零硬编码比对)
	var gate_cfg: Dictionary = GameData.narrative_cfg.get("gate", {})
	var hud: Node = _main.get_node("HUD")
	var obj: Label = hud.get("_objective")
	_report(obj != null and obj.visible and obj.text == str(gate_cfg.get("objectiveLocked", "")),
		"HUD 目标行(简报后常驻): %s" % (obj.text if obj else "<missing>"))
	# 楼层化区域提示已登记(楼梯间 1F / 三楼口 2F)
	var h1 := false
	var h2 := false
	for h in _main.get("_hints"):
		var t := str(h.get("text", ""))
		if t.contains("配电设备的嗡鸣") and int(h.get("floor", 1)) == 1:
			h1 = true
		if t.contains("重物囤积") and int(h.get("floor", 1)) == 2:
			h2 = true
	_report(h1 and h2, "区域提示楼层化登记: 楼梯间(1F 嗡鸣) / 三楼口(2F 重物囤积)")
	_gate_static_test_done = true


## A批5/批6 · 层间贯通实测(协程): 二层哨戒敌不隔层侦测一楼玩家 → 两部楼梯×三角度
## (正面/左偏30°/右偏30°)实走上行——到顶 y 增量达标且贴近目标板面(不滞留)。
## A批6: 起点改为"从行走面接近低端再上行"(A批5 起点在楼梯占地内直放直走,
## 未覆盖真实路径 → 楼梯2 低端怼墙卡死漏检, 用户实机发现); 楼梯2 已改 dir=N。
## 帧位251, 全程约 230 帧; flag 测试(_verify_death_cleanup 尾部)等待
## _layer_test_done 串行, 避免旗标传送抢占玩家; campaign_flow(310) 容忍等待
func _test_layer_climb() -> void:
	# 二层敌自建(帧85 _setup_shoot 会清场 build 生成的全部敌人, 不可依赖)
	var layer_enemy: Node = preload("res://scenes/entities/Enemy.tscn").instantiate()
	layer_enemy.template_id = 1
	layer_enemy.projectile_root = _main.get_node("Viewport")
	_entities.add_child(layer_enemy)
	layer_enemy.global_position = Vector3(51.0, 2.6, 55.0)  # 二层哨戒位 (25,27) F房间
	layer_enemy.velocity = Vector3.ZERO
	await get_tree().physics_frame
	# 1) 隔层: 玩家移到二层敌正下方一楼 → 敌不应侦测(垂直差2.6m>阈值1.5m)
	_player.global_position = Vector3(51.0, 0.65, 55.0)
	_player.velocity = Vector3.ZERO
	for i in 3:
		await get_tree().physics_frame
	_report(is_zero_approx(float(layer_enemy.velocity.x)) and is_zero_approx(float(layer_enemy.velocity.z)),
		"二层哨戒敌不隔层侦测一楼玩家 (垂直差2.6m>阈值)")
	# 后续登顶测试防干扰: 伤害清零并挪至二层西南远角 (4,19)——距井道≈55m 超侦测范围
	layer_enemy.fire_damage = 0
	layer_enemy.melee_damage = 0
	layer_enemy.global_position = Vector3(9.0, 2.6, 39.0)
	layer_enemy.velocity = Vector3.ZERO

	# 2) 两部楼梯×三角度实走上行(从行走面接近低端——A批6 真实路径口径)。
	#    楼梯1(一→二, N向升, 低端 z=52.05): 起点一层井道行走带 (31,27)=(63,55) 北行,
	#      走 3m 平地后零阶差踏上梯
	#    楼梯2(二→三, A批6 改 N向, 低端 z=46.05): 起点二层落点走廊 (31,23)=(63,47.5)
	#      北行踏上(原 S 向低端怼 row20 北墙, 只能侧面上坡卡死)
	#    偏角行进会横向漂移, 起点对侧预偏保持全程在梯面(宽2格)内
	await _climb_stair(Vector3(64.0, 0.0, 55.0), 0.0, 0.0, 2.6, 47.9, -1.0, "楼梯1(一→二)正面")
	await _climb_stair(Vector3(65.3, 0.0, 55.0), PI / 6.0, 0.0, 2.6, 47.9, -1.0, "楼梯1(一→二)左偏30°")
	await _climb_stair(Vector3(62.5, 0.0, 55.0), -PI / 6.0, 0.0, 2.6, 47.9, -1.0, "楼梯1(一→二)右偏30°")
	await _climb_stair(Vector3(64.0, 3.2, 47.5), 0.0, 2.6, 5.2, 41.9, -1.0, "楼梯2(二→三)正面")
	await _climb_stair(Vector3(65.3, 3.2, 47.5), PI / 6.0, 2.6, 5.2, 41.9, -1.0, "楼梯2(二→三)左偏30°")
	await _climb_stair(Vector3(62.5, 3.2, 47.5), -PI / 6.0, 2.6, 5.2, 41.9, -1.0, "楼梯2(二→三)右偏30°")
	_layer_test_done = true


## 实走上行辅助: 传送至梯底(start.y 为脚部起值), 沉降3帧后按住 W 45 物理帧
## (速度14m/s ≈ 10.5m; A批6 起点改行走面接近后行程加长, 且坡面投影减速——
## 35帧/8.2m 实测余量不足停在唇沿 90% 处), 断言: 自 expect_base 起爬升 >2.45m、
## 终点 y 站上目标板面(±0.12m)且水平越过洞缘平面(past_z×z_sign)——到顶不卡顶不滞留
func _climb_stair(start: Vector3, ry: float, expect_base: float, target_top: float,
		past_z: float, z_sign: float, label: String) -> void:
	_player.global_position = start
	_player.rotation.y = ry
	_player.velocity = Vector3.ZERO
	for i in 3:
		await get_tree().physics_frame  # 沉降落坡/落地
	_key_down(KEY_W)
	for i in 45:
		await get_tree().physics_frame
	_key_up(KEY_W)
	await get_tree().physics_frame
	var rise := float(_player.global_position.y) - expect_base
	var past := (float(_player.global_position.z) - past_z) * z_sign > 0.0
	_report(rise > 2.45 and absf(float(_player.global_position.y) - target_top) < 0.12 and past,
		"%s 实走上行到顶: 爬升 %.2fm → y=%.2f z=%.1f (站上板面 %.2f 且越过洞缘, 不卡顶)"
		% [label, rise, _player.global_position.y, _player.global_position.z, target_top])


func _test_campaign_config() -> void:
	var seq: Array = (GameData.level_ext_cfg.get("campaign", {}) as Dictionary).get("sequence", [])
	_report(seq.size() == 3 and int(seq[0]) == 0 and int(seq[1]) == 2 and int(seq[2]) == 1,
		"关卡序列 campaign: 仓库区→街道→地下设施 [%s]" % str(seq))

	var has_map0_goal := false
	for g in GameData.level_ext_cfg.get("goals", []):
		if int((g as Dictionary).get("map", -1)) == 0:
			has_map0_goal = true
	_report(has_map0_goal, "goals 配置: 第一关庭院旗已配置")

	var m2: Dictionary = {}
	for m in GameData.level_ext_cfg.get("maps", []):
		if int((m as Dictionary).get("map", -1)) == 2:
			m2 = m
	_report(not m2.is_empty() and int(m2.get("width", 0)) == 140 and int(m2.get("height", 0)) == 84,
		"map2 外部地图配置就绪 (140×84 室外, level_ext.maps 管线)")

	var flags := []
	for c in _entities.get_children():
		if c.has_signal("reached"):
			flags.append(c)
	_report(flags.size() == 1,
		"第一关终点旗: 室内F旗已抑制, 仅庭院配置旗 (数量=%d)" % flags.size())
	if flags.size() == 1:
		_report(float(flags[0].global_position.x) > 167.0 * WorldConst.CELL,
			"终点旗位于庭院内 (%.0f, %.0f)"
			% [flags[0].global_position.x, flags[0].global_position.z])


## B线批1 · 转关流程端到端(协程): 等待 flag 测试触发第一关通关 →
## level_end 结算态(下一关入口) → 击发计数口径 → 转关 → map2 灰盒生成 →
## 跨关保留(武器/升级/弹匣补满)。帧位 310, flag 测试 timer 链约 300+ 帧触发
func _test_campaign_flow() -> void:
	var waited := 0
	while not _main.game_over and waited < 600:
		await get_tree().physics_frame
		waited += 1
	# A批5: 登顶三角度实走延长后通关触发晚于帧310, 本协程会抢先于 _check_flag
	# 消费 game_over 并转关(重置 game_over)——必须先等通关判定断言完成
	while not _flag_test_done:
		await get_tree().physics_frame
	_report(_main.game_over and _main.state == "level_end",
		"第一关通关进入关卡间结算态 level_end (state=%s)" % _main.state)
	var end_hint: Label = _main.get_node("HUD").get("end_hint")
	_report(end_hint != null and end_hint.text.contains("下一关"),
		"结算面板提供「进入下一关」入口")
	# 命中率口径: 击发即计数(多弹丸算一次)
	var shots_before: int = _player.shots_fired
	_player._shoot()
	_report(_player.shots_fired == shots_before + 1,
		"命中率口径: 击发即计数 (霰弹一发=一次)")
	# 跨关保留基准记录后触发转关(等价结算面板 Enter)
	var tier_before: int = _player.weapon_tier
	var smg_owned: bool = bool(_player.weapon_owned[1])
	_main._advance_level()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_report(_main.map_index == 2, "转关后进入第二关 map2 (index=%d)" % _main.map_index)
	_report(_main.state == "briefing", "转关后进入第二关简报态")
	# 墙格从配置推导(dev2 B批2 口径预对齐): 围界环 + 建筑周界 - 门洞。
	# 本分支 map2 无 buildings → 退化为围界环 444; 合并 dev2 后自动适配街区布局,
	# 避免硬编码 444 在合并时变红(存量断言升级为配置驱动, 非松绑)。
	var m2cfg := {}
	for mc in GameData.level_ext_cfg.get("maps", []):
		var mcd: Dictionary = mc
		if int(mcd.get("map", -1)) == 2:
			m2cfg = mcd
	var expect_cells: int = 2 * (int(m2cfg.get("width", 140))
		+ int(m2cfg.get("height", 84))) - 4
	for bb in m2cfg.get("buildings", []):
		var bd: Dictionary = bb
		expect_cells += 2 * (int(bd.get("w", 0)) + int(bd.get("h", 0))) - 4
		expect_cells -= maxi(0, int((bd.get("door", {}) as Dictionary).get("w", 0)))
	_report(_level.wall_cells.size() == expect_cells,
		"map2 墙格: %d (期望 %d = 围界环 + 建筑周界 - 门洞, 配置推导)"
		% [_level.wall_cells.size(), expect_cells])
	_report(_level.get_node_or_null("Ceiling") == null, "map2 室外无天花板 (outdoor)")
	_report(_player.weapon_tier == tier_before and bool(_player.weapon_owned[1]) == smg_owned,
		"跨关保留: 武器持有与升级组件等级原样保留 (tier=%d)" % _player.weapon_tier)
	_report(_player.ammo_clip == int(_player.weapons[_player.weapon_index]["clipSize"]),
		"跨关保留: 弹匣自动补满 (%d/%d)"
		% [_player.ammo_clip, int(_player.weapons[_player.weapon_index]["clipSize"])])
	# 转关重建小地图必须唯一: 旧实例不释放会导致旧图在半透明底板下幽灵显现
	# (2026-08-30 用户实机发现, 守门方热修 HUD.setup_minimap 先 queue_free 旧节点)
	var mm_count := 0
	for c in _main.get_node("HUD").get_children():
		if c.name == "MiniMap":
			mm_count += 1
	_report(mm_count == 1,
		"转关后小地图唯一(旧实例已释放防幽灵叠加): %d 个" % mm_count)
	# A批6: 转关后小地图楼层化回退(map2 无 layers → 永远 1F 表现) + 合闸状态重置
	var mm2: Node = _main.get_node("HUD").get_node_or_null("MiniMap")
	_report(mm2 != null and (mm2.get("_floor_texes") as Dictionary).size() == 1
		and mm2.current_floor() == 1,
		"map2 无 layers: 小地图仅 1F 纹理, 当前楼层=1(向后兼容)")
	# A批7: 无层图不画楼层角标(向后兼容)
	_report(mm2 != null and mm2.floor_badge() == "",
		"map2 无 layers: 楼层角标不画(空串, 向后兼容)")
	_report(not _level.gate_powered and not _level.has_gate(),
		"转关后合闸状态重置: map2 无闸, gate_powered=false")
	# A批6.1: map2 无闸 → 小地图信标非闭锁态(绿色实心点, 向后兼容)
	_report(mm2 != null and not mm2.flag_locked(),
		"map2 无闸: 小地图信标非闭锁态(绿点, 向后兼容)")
	# A批8 报备勘正(原注释归因有误): weapons.json 的 upgradeComponents 标 map=1
	# 属第三关——campaign.sequence=[0,2,1], map1(地下隐匿设施)是终点关, 索引语义
	# 正确, 并非"与 map_index=2 未对齐"的缺陷; 第二关的 v 由 B批3(dev2) 走
	# level_ext.maps[map=2].pickups 配置在东北土丘顶。故本断言改配置驱动:
	# 本分支无 B批2/3 内容 → 期望无 v; 合并 dev2 后自动转为丘顶落位断言
	# (与本文件"v 归 B批3 落 map2 丘顶"既有口径一致)。
	var mk2 := {}
	if mm2 != null:
		for m2 in mm2.target_marks():
			var m2d: Dictionary = m2
			mk2[str(m2d["key"])] = m2d["cell"]
	var v_cfg := {}
	for pc in m2cfg.get("pickups", []):
		var pcd: Dictionary = pc
		if str(pcd.get("symbol", "")) == "v":
			v_cfg = pcd
	if v_cfg.is_empty():
		_report(not mk2.has("v"),
			"map2 无 v 配置: 目标标记不含三阶组件(本分支口径, B批3 后自动转丘顶断言)")
	else:
		_report(mk2.has("v") and mk2["v"] == Vector2i(int(v_cfg.get("x", -1)),
				int(v_cfg.get("y", -1))),
			"map2 三阶组件 v 标记落位: %s (期望配置 (%s,%s) 丘顶)"
			% [str(mk2.get("v")), str(v_cfg.get("x")), str(v_cfg.get("y"))])
	_report(not mk2.has("breaker"),
		"map2 无闸: 目标标记不含电闸(向后兼容)")
	_campaign_test_done = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = $Main
	_player = _main.get_node("Viewport/Player")
	_level = _main.get_node("Viewport/Level")
	_entities = _main.get_node("Viewport/Entities")


# 调度挂在物理帧而非渲染帧：headless 下渲染不受垂直同步约束，
# 渲染帧可能领先物理步，曾导致"子弹命中敌人"在弹丸飞到前被提前校验
func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		2: _main.dismiss_briefing()
		5: _check_world_built()
		7: _check_weapons_cfg()
		9: _test_p2a_terrain()
		10: _test_facade_props()
		11: _test_ae219_enemies()
		13: _test_edaa_narrative()
		14: _test_menu_identity()
		15: _test_p2b_terrain()
		16: _test_enemy_y_config()
		17: _test_campaign_config()
		18: _test_layers_static()
		19: _test_third_floor_static()
		20: _test_minimap_floors()
		21: _test_gate_static()
		8: _test_initial_noop()
		12: _setup_weapon_pickup()
		25: _check_weapon_grant()
		27: _test_cycle_switch()
		40: _setup_pickup()
		55: _check_pickup()
		56: _test_health_full()
		57: _test_components()
		58: _test_shotgun()
		85: _setup_shoot()
		130: _check_shoot()
		135: _check_death_collision()
		140: _p2b_climb_setup()
		185: _p2b_climb_check()
		190: _enemy_y_setup()
		240: _enemy_y_check()
		243: _enemy_y_high_check()
		250: _enemy_y_floor_check()
		251: _test_layer_climb()
		310: _test_campaign_flow()
		346: _finish()


func _report(ok: bool, msg: String) -> void:
	print("[SMOKE] %s | %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		_fail = true


func _check_world_built() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	_report(enemies.size() >= 10, "敌人数量: %d (期望 >= 10)" % enemies.size())
	var pickup_count := 0
	var has_weapon_pickup := false
	var has_shotgun_pickup := false
	var has_comp1 := false
	var has_comp2 := false
	var has_comp3 := false
	var has_armor := false
	var legacy_count := 0  # a/w 已实机移除，不应再生成
	for c in _entities.get_children():
		if "symbol" in c:
			pickup_count += 1
			if c.symbol == "W":
				has_weapon_pickup = true
			elif c.symbol == "T":
				has_shotgun_pickup = true
			elif c.symbol == "u":
				has_comp1 = true
			elif c.symbol == "U":
				has_comp2 = true
			elif c.symbol == "v":
				has_comp3 = true
			elif c.symbol == "e":
				has_armor = true
			elif c.symbol == "a" or c.symbol == "w":
				legacy_count += 1
	_report(pickup_count >= 20, "拾取物数量: %d (期望 >= 20)" % pickup_count)
	_report(has_weapon_pickup, "冲锋枪拾取物已按配置生成(A批6: 二层 B 房间)")
	_report(has_shotgun_pickup, "霰弹枪拾取物已按配置生成(A批6: 三层宝库)")
	# A批6 霰弹重排: 一楼推进线 4 处 + 三层宝库 2 处
	# A批8 补给重平衡: 三层新区再撒 3(二层不给 s——霰弹枪 T 在三层, 给 s 无意义)
	_report(_count_symbol("s") == 9,
		"12号霰弹补给: %d 处 (期望 9 = 一楼4 + 三层宝库2 + 三层新区3)" % _count_symbol("s"))
	# A批6: 三阶组件 v 移出第一关(归 B批3 map2 丘顶), map0 仅一/二级
	_report(has_comp1 and has_comp2 and not has_comp3,
		"升级组件: map0 仅一/二级(v 已移出第一关)")
	_report(has_armor, "防护服能量补给已生成（a 符号位改造）")
	_report(legacy_count == 0, "扩展弹匣/神经加速器已实机移除 (残留=%d)" % legacy_count)
	# A批8 补给跨楼层重平衡(用户实机反馈: 一层密度 5.26 个/百格 vs 二三层 0.32,
	# 差 16 倍): 一层抑制 H×48/C×89/A×52 共 189 格 → 净存 H46 e25 C62 A57 h5 s4
	# = 199(2.73/百格); 二三层各撒新区补给 → 2F 105(1.25) / 3F 115(1.37)。
	# e 口径: 一层 a5+w5+H折算15=25 (H 参与折算 60 个: 原109−本批48−A批5的1)
	# H 口径: 一层 45+1(A批5 place)=46
	# h(生命上限升级, +20/无次数上限): A批7 在二三层撒 11/10 → 全吃血上限 100→620,
	# 本批每层截断保留 3
	_report(_count_symbol("e") == 51,
		"防护服电池: %d (期望 51 = 1F25+2F13+3F13)" % _count_symbol("e"))
	_report(_count_symbol("H") == 76,
		"急救包: %d (期望 76 = 1F46+2F14+3F16)" % _count_symbol("H"))
	_report(_count_symbol("h") == 11,
		"生命上限升级: %d (期望 11 = 1F5+2F3+3F3, A批7 过量已截断)" % _count_symbol("h"))
	_report(_count_symbol("C") == 136,
		"金币: %d (期望 136 = 1F62+2F36+3F38)" % _count_symbol("C"))
	_report(_count_symbol("A") == 133,
		"弹药: %d (期望 133 = 1F57+2F38+3F38)" % _count_symbol("A"))
	# A批6 · 物资重排层落位核验(帧5, 必须在帧12冲锋枪拾取之前——W 被拾取后即离场):
	# 符号/坐标/楼层 y/落点为层地板格(非墙非板洞)。注意 Pickup 触发半径 2.0m
	_report(_count_symbol("v") == 0, "map0 已无三阶组件 v (移出第一关, 归 B批3 落 map2 丘顶)")
	_assert_layer_entity("W", 5, 27, 2.6, "冲锋枪 W → 二层 B 房间 (5,27)")
	_assert_layer_entity("T", 4, 27, 5.2, "霰弹枪 T → 三层 B 房间 (4,27)")
	_assert_layer_entity("U", 6, 27, 5.2, "二阶组件 U → 三层 (6,27)")
	_assert_layer_entity("s", 5, 28, 5.2, "12号霰弹 s → 三层 (5,28)")
	_assert_layer_entity("s", 7, 26, 5.2, "12号霰弹 s → 三层 (7,26)")
	var guard := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var gc := Vector2i(int(e.global_position.x / WorldConst.CELL),
			int(e.global_position.z / WorldConst.CELL))
		if gc == Vector2i(9, 25) and int(e.template_id) == 2 \
				and absf(float(e.global_position.y) - 5.2) < 0.1:
			guard = true
	_report(guard, "三层镇守敌在场: 巨型突变体宿主 id=2 @ (9,25) y=5.2")
	# A批7 · enemyOverrides 精英重分布(帧5, 清场前): 符号图 id2 40只 抑制30保留10;
	# 重布 24×3F + 6×2F(层板顶抬升 y≈5.2/2.6) → 分层计数 1F=10 / 2F=6 / 3F=25(含镇守1)
	# A批8 · 孢子囊(id0)/人类寄生体宿主(id1) 跨楼层布防(用户实机反馈: 一层敌人
	# 密度 1.46 只/百格 vs 二层 0.08/三层 0.30, 扩面 26 倍后敌人没跟上):
	#   id0 一层抑制 8(28→20), 布防 2F×14 + 3F×16
	#   id1 一层抑制 32(68→36), 布防 2F×24 + 3F×19(2F 另有层配置哨戒 1 只)
	#   id2 保持 A批7 口径不动
	var by_floor := {0: [0, 0, 0], 1: [0, 0, 0], 2: [0, 0, 0]}
	for e in get_tree().get_nodes_in_group("enemies"):
		var tid := int(e.template_id)
		if not by_floor.has(tid):
			continue
		var ey := float(e.global_position.y)
		var fi := 2 if ey > 5.0 else (1 if ey > 2.4 else 0)
		by_floor[tid][fi] += 1
	_report(by_floor[2][0] == 10 and by_floor[2][1] == 6 and by_floor[2][2] == 25,
		"enemyOverrides 精英重布: id2 分层 1F=%d(期望10, 40−30) 2F=%d(期望6) 3F=%d(期望25=重布24+镇守1)"
		% [by_floor[2][0], by_floor[2][1], by_floor[2][2]])
	_report(by_floor[0][0] == 20 and by_floor[0][1] == 14 and by_floor[0][2] == 16,
		"A批8 孢子囊布防: id0 分层 1F=%d(期望20, 28−8) 2F=%d(期望14) 3F=%d(期望16)"
		% [by_floor[0][0], by_floor[0][1], by_floor[0][2]])
	_report(by_floor[1][0] == 36 and by_floor[1][1] == 25 and by_floor[1][2] == 19,
		"A批8 人类宿主布防: id1 分层 1F=%d(期望36, 68−32) 2F=%d(期望25=布防24+哨戒1) 3F=%d(期望19)"
		% [by_floor[1][0], by_floor[1][1], by_floor[1][2]])
	_report(get_tree().get_first_node_in_group("player") != null, "玩家节点就绪")
	var mm: Node = _main.get_node("HUD").get_node_or_null("MiniMap")
	_report(mm != null and mm.get("_wall_tex") != null, "HUD 小地图已就绪")
	# A批8 · 小地图目标标记(用户实机反馈: 冲锋枪/霰弹枪/2楼电闸/1-3阶组件
	# 在图上找不到): 武器与组件画菱形每种一色, 电闸画方块+白心;
	# v 不在 map0(A批6 移出第一关) → 标记代码通用但本图无对象
	var marks: Array = mm.target_marks() if mm != null else []
	var mk := {}
	for m in marks:
		var md: Dictionary = m
		mk[str(md["key"])] = {"floor": int(md["floor"]), "cell": md["cell"]}
	var got_keys: Array = mk.keys()
	got_keys.sort()
	_report(mk.size() == 5 and not mk.has("v"),
		"小地图目标标记 5 类: %s (期望 W/T/u/U/breaker; v 不在 map0)" % str(got_keys))
	_report(mk.has("W") and mk["W"]["floor"] == 2 and mk["W"]["cell"] == Vector2i(5, 27),
		"标记落位: 冲锋枪 W → 2F (5,27) 天蓝菱形")
	_report(mk.has("T") and mk["T"]["floor"] == 3 and mk["T"]["cell"] == Vector2i(4, 27),
		"标记落位: 霰弹枪 T → 3F (4,27) 洋红菱形")
	_report(mk.has("u") and mk["u"]["floor"] == 1 and mk["u"]["cell"] == Vector2i(22, 35),
		"标记落位: 1阶组件 u → 1F (22,35) 青绿菱形")
	_report(mk.has("U") and mk["U"]["floor"] == 3 and mk["U"]["cell"] == Vector2i(6, 27),
		"标记落位: 2阶组件 U → 3F (6,27) 紫菱形")
	_report(mk.has("breaker") and mk["breaker"]["floor"] == 2
			and mk["breaker"]["cell"] == Vector2i(15, 18),
		"标记落位: 2楼电闸 → 2F 触发格 (15,18) 橙红方块+白心")


func _key_down(key: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)


func _key_up(key: int) -> void:
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)


func _wheel(button: int) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	down.position = Vector2(1, 1)
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = Vector2(1, 1)
	Input.parse_input_event(up)


## 事件驱动切换: parse_input_event → Main._unhandled_input → cycle_weapon。
## 注入后等待冲刷与物理帧，确保事件已派发
func _test_initial_noop() -> void:
	_key_down(KEY_Q)
	_key_up(KEY_Q)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_report(_player.weapon_index == 0 and not _player.weapon_owned[1],
		"仅持手枪时 Q 不切换 (index=%d)" % _player.weapon_index)
	_noop_test_done = true


func _check_weapons_cfg() -> void:
	_report(_player.weapons.size() == 3, "三武器配置: %d 把 (期望 3)" % _player.weapons.size())
	if _player.weapons.size() == 3:
		var pistol: Dictionary = _player.weapons[0]
		var smg: Dictionary = _player.weapons[1]
		var sg: Dictionary = _player.weapons[2]
		_report(pistol["auto"] == false and int(pistol["clipSize"]) == 20,
			"手枪: 半自动 弹匣 %d (期望 20)" % int(pistol["clipSize"]))
		_report(smg["auto"] == true and str(smg["displayName"]) == "冲锋枪",
			"冲锋枪: 全自动就绪")
		_report(str(sg["id"]) == "shotgun" and int(sg["clipSize"]) == 8
			and int(sg["pellets"]) == 6 and int(sg["damage"]) == 20
			and sg["auto"] == false and sg["pump"] == true,
			"霰弹枪: 泵动 8发/6弹丸/伤害%d" % int(sg["damage"]))
	_report(_player.weapon_owned.size() == 3 and _player.weapon_owned[0]
		and not _player.weapon_owned[1] and not _player.weapon_owned[2],
		"初始持有模型: 仅手枪")
	_report(_player.health_max == 100, "玩家血量上限: %d (期望 100)" % _player.health_max)
	var hud_ammo: Label = _main.get_node("HUD").ammo_label
	_report(hud_ammo.text.contains("9×19mm"),
		"HUD 弹药口径显示(手枪): %s" % hud_ammo.text)
	var hud_health: Label = _main.get_node("HUD").health_label
	var hud_armor: Label = _main.get_node("HUD").armor_label
	var hud_coin: Label = _main.get_node("HUD").coin_label
	var vp_w := float(get_viewport().get_visible_rect().size.x)
	_report(hud_ammo.offset_right <= vp_w + hud_armor.offset_left,
		"HUD 底部无重叠: 弹药行右缘 %.0f <= 右侧组左缘 %.0f"
		% [hud_ammo.offset_right, vp_w + hud_armor.offset_left])
	_report(hud_armor.offset_right <= hud_health.offset_left
		and hud_health.offset_right <= hud_coin.offset_left,
		"HUD 右侧组并排不重叠: 防护→生命→金币 槽位顺序成立")


## P2a 夜空室外区端到端（纯查询，无传送，不干扰后续串行传送测试）:
## 夜空环境生效 → 庭院外扩（围墙环四角+门洞开通+露天格计数）→
## 室内天花板保留 + 露天地面覆层 → 小地图跟随模式激活
func _test_p2a_terrain() -> void:
	var world_env: WorldEnvironment = _main.get_node("Viewport/WorldEnvironment")
	var env := world_env.environment
	_report(env.background_mode == Environment.BG_SKY and env.sky != null,
		"P2a 夜空环境已启用 (background_mode=%d)" % env.background_mode)

	var cy: Dictionary = GameData.level_ext_cfg.get("courtyard", {})
	var rect: Dictionary = cy.get("rect", {})
	if rect.is_empty():
		_report(false, "level_ext.courtyard.rect 配置缺失")
		return
	var x0 := int(rect.get("x", 0))
	var y0 := int(rect.get("y", 0))
	var w := int(rect.get("w", 0))
	var h := int(rect.get("h", 0))
	_report(_level.has_courtyard(), "庭院外扩已生成")
	var expected_open: int = maxi(w - 2, 0) * maxi(h - 2, 0)
	_report(_level.get_courtyard_cells().size() == expected_open,
		"庭院露天格: %d (期望 %d，围墙环完整)" % [_level.get_courtyard_cells().size(), expected_open])
	# 围墙环四角必须实体化（渲染 MultiMesh + 碰撞同源）
	_report(_level.is_wall(x0, y0) and _level.is_wall(x0 + w - 1, y0)
		and _level.is_wall(x0, y0 + h - 1) and _level.is_wall(x0 + w - 1, y0 + h - 1),
		"庭院围墙环四角实体化 @(%d,%d)-(%d,%d)" % [x0, y0, x0 + w - 1, y0 + h - 1])
	# 门洞开通: 门洞格非墙，且门内一格连通庭院开阔区
	var door: Dictionary = cy.get("doorway", {})
	var dx := int(door.get("x", x0))
	var dy := int(door.get("y", y0 + h / 2))
	_report(not _level.is_wall(dx, dy) and not _level.is_wall(dx + 1, dy),
		"庭院门洞已开并连通室内 (%d,%d)" % [dx, dy])
	# 门洞物理通行: 横穿门洞格的射线应无碰撞（原边界墙碰撞体随之移除）
	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(
		Vector3((dx - 0.5) * WorldConst.CELL, 0.65, (dy + 0.5) * WorldConst.CELL),
		Vector3((dx + 2.5) * WorldConst.CELL, 0.65, (dy + 0.5) * WorldConst.CELL))
	ray.exclude = [_player.get_rid()]
	_report(space.intersect_ray(ray).is_empty(),
		"门洞物理通行无阻挡（碰撞已移除）(%d,%d)" % [dx, dy])
	# 室内天花板保留 + 露天地面覆层
	_report(_level.get_node_or_null("Ceiling") != null, "室内天花板保留（屋檐结构）")
	_report(_level.get_node_or_null("CourtyardFloor") != null, "庭院露天地面覆层已生成")
	# P1.5 小地图跟随模式
	var mm: Node = _main.get_node("HUD").get_node_or_null("MiniMap")
	_report(mm != null and bool(mm.get("_follow")), "小地图跟随模式已激活")


# 混合路线阶段一: 装饰外立面 + 庭院道具(零玩法逻辑改动)
func _test_facade_props() -> void:
	var fcfg: Dictionary = GameData.level_ext_cfg.get("facade", {})
	var facade := _level.get_node_or_null("Facade")
	_report(facade != null and not fcfg.is_empty(),
		"阶段一装饰外立面已生成")
	if facade != null and facade.get_node_or_null("FacadeBand") != null:
		var band: MeshInstance3D = facade.get_node("FacadeBand")
		var qm := band.mesh as QuadMesh
		var top: float = band.position.y + qm.size.y * 0.5
		var expect_top: float = WorldConst.WALL_HEIGHT \
			+ float(fcfg.get("stories", 2)) * float(fcfg.get("storyHeight", WorldConst.WALL_HEIGHT))
		_report(absf(top - expect_top) < 0.1,
			"外立面顶高达三层体量: %.2fm (期望 %.2fm)" % [top, expect_top])

	var pcfg: Array = GameData.level_ext_cfg.get("props", [])
	var expect := 0
	for p in pcfg:
		if int((p as Dictionary).get("map", -1)) == 0:
			expect += 1
	var props := get_tree().get_nodes_in_group("props")
	_report(props.size() == expect,
		"布景道具: %d 个 (期望 %d, 与配置一致)" % [props.size(), expect])

	# 墙面贴花(出生点货运大门): 数量与本图配置一致
	var dcfg: Array = GameData.level_ext_cfg.get("wallDecals", [])
	var expect_decals := 0
	for d in dcfg:
		if int((d as Dictionary).get("map", -1)) == 0:
			expect_decals += 1
	var decals := get_tree().get_nodes_in_group("wall_decals")
	_report(decals.size() == expect_decals,
		"墙面贴花(大门): %d 个 (期望 %d, 与配置一致)" % [decals.size(), expect_decals])

	# 贴花必须挂在真实墙格上(防配置行号偏移导致悬浮):
	# 覆盖的每个格都须在墙格集中。历史坑: 大门曾误配 y=37(空地),
	# 真墙在 row 38 → 贴花悬浮空中 2 米, 仅查数量的断言漏检。
	# A批6: floor≥2 的贴花挂层墙(如二层配电箱 (15,17)), 按楼层分层校验
	for d in dcfg:
		var dd: Dictionary = d
		if int(dd.get("map", -1)) != 0:
			continue
		var x0 := int(dd.get("x", 0))
		var y0 := int(dd.get("y", 0))
		var dw := maxi(1, int(dd.get("w", 1)))
		var dface := str(dd.get("face", "N"))
		var dfloor := maxi(1, int(dd.get("floor", 1)))
		var on_wall := true
		for i in dw:
			# N/S 面贴花沿 x 覆盖 w 格; E/W 面沿 y 覆盖 w 格(与 _build_wall_decals 同口径)
			var cell := Vector2i(x0, y0 + i) if (dface == "E" or dface == "W") else Vector2i(x0 + i, y0)
			if not _level.is_wall(cell.x, cell.y, dfloor):
				on_wall = false
		_report(on_wall,
			"墙面贴花挂在真实墙格上: (%d,%d) 起 %d 格 face=%s floor=%d" % [x0, y0, dw, dface, dfloor])

	# 逻辑零侵入不变式: 布景(立面/道具)不进碰撞层 → 碰撞体数恒等于墙格数
	var col_body := _level.get_node_or_null("WallCollision")
	if col_body != null:
		_report(col_body.get_child_count() == _level.wall_cells.size(),
			"墙碰撞体数 == 墙格数(布景零逻辑侵入): %d == %d" \
			% [col_body.get_child_count(), _level.wall_cells.size()])


## AE-219 敌人素材与双模式接线: 三模板在场 → 贴图已切换 →
## 双攻击帧(近战/孢子)加载 → 巨型宿主移速最快 → 敌人弹道可孢子精灵化
func _test_ae219_enemies() -> void:
	var seen := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			seen[int(e.template_id)] = e
	_report(seen.size() == 3, "三型敌人模板均在场: %d 种" % seen.size())

	var names := {0: "孢子囊", 1: "人类宿主", 2: "巨型宿主"}
	for tid in [0, 1, 2]:
		if not seen.has(tid):
			_report(false, "%s 模板实体缺失" % names[tid])
			continue
		var e: Node = seen[tid]
		var tex: Texture2D = e.get("_idle_texture")
		_report(tex != null and tex.resource_path.contains("AE219"),
			"%s 已切换 AE-219 贴图: %s" % [names[tid], tex.resource_path.get_file() if tex else "null"])

	if seen.has(0):
		var husk: Node = seen[0]
		_report(husk.get("_attack_spore_texture") != null,
			"孢子囊发射孢子攻击帧已加载")
	if seen.has(1):
		var host: Node = seen[1]
		_report(host.get("_attack_melee_texture") != null
			and host.get("_attack_spore_texture") != null,
			"人类宿主双攻击帧(近战+孢子)已加载")
	if seen.has(2):
		var hulking: Node = seen[2]
		_report(hulking.get("_attack_melee_texture") != null
			and hulking.get("_attack_spore_texture") != null,
			"巨型宿主双攻击帧(近战+掷孢子)已加载")

	if seen.size() == 3:
		_report(float(seen[2].move_speed) > float(seen[0].move_speed)
			and float(seen[2].move_speed) > float(seen[1].move_speed),
			"巨型宿主移速最快: %.1f > %.1f/%.1f" \
			% [seen[2].move_speed, seen[0].move_speed, seen[1].move_speed])

	# 孢子弹道精灵化: 设置贴图后 SporeSprite 可见、球形 Mesh 隐藏
	var proj: Node3D = preload("res://scenes/weapons/Projectile.tscn").instantiate()
	proj.spore_texture = load("res://assets/sprites/AE219 Spore Small.png")
	_main.get_node("Viewport").add_child(proj)
	proj.global_position = Vector3(0, 200, 0)  # 高空隔离, 避免误伤测试流
	await get_tree().physics_frame
	var spore_sprite: Sprite3D = proj.get_node("SporeSprite")
	var mesh: MeshInstance3D = proj.get_node("Mesh")
	_report(spore_sprite.visible and spore_sprite.texture != null and not mesh.visible,
		"敌人弹道可孢子精灵化（贴图广告牌替代球形弹）")
	proj.queue_free()


## EDAA 世界观化: 文案切换到「提灯」前传叙事(当代 2026, 无 2057/诺亚残留) →
## 敌名三型对齐 → 仓库主墙(X)已换混凝土贴图 → 菜单徽记背景可加载
func _test_edaa_narrative() -> void:
	var cfg: Dictionary = GameData.narrative_cfg
	var full_text := ""
	for b in cfg.get("briefings", []):
		full_text += str((b as Dictionary).get("title", ""))
		for ln in (b as Dictionary).get("lines", []):
			full_text += str(ln)
	for v in cfg.get("victory", []):
		full_text += str(v)
	full_text += str((cfg.get("defeat", {}) as Dictionary).get("text", ""))
	_report(full_text.contains("提灯") and full_text.contains("2026"),
		"简报已切换提灯前传叙事(含 2026 当代时间线)")
	_report(not full_text.contains("2057") and not full_text.contains("诺亚"),
		"旧世界观文案已清除(无 2057/诺亚残留)")
	_report(full_text.contains("熄烛"),
		"胜负文案已衔接熄烛者特遣队(前传钩子)")

	var names: Array = cfg.get("enemy_names", [])
	_report(names.size() == 3 and str(names[0]) == "外星寄生孢子囊"
		and str(names[1]) == "寄生人类宿主" and str(names[2]) == "巨型突变体宿主",
		"敌名三型已对齐: %s" % str(names))

	var walls_x: MultiMeshInstance3D = _level.get_node_or_null("Walls_X") as MultiMeshInstance3D
	var wall_tex: Texture2D = walls_x.material_override.albedo_texture if walls_x else null
	_report(wall_tex != null and wall_tex.resource_path.contains("Wall Concrete"),
		"仓库主墙(X)已换混凝土贴图: %s" \
		% (wall_tex.resource_path.get_file() if wall_tex else "null"))

	var menu_bg: Texture2D = load("res://assets/images/MenuBG_EDAA.png")
	_report(menu_bg != null, "EDAA 徽记菜单背景可加载")


## 主菜单身份: 徽记背景完整容下（居中自适应不出界）+ 标题改「静默之前」
## （实例化真实场景验证 _ready 构建结果，验后即弃）
func _test_menu_identity() -> void:
	var menu: Control = preload("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(menu)
	var emblem: TextureRect = null
	for c in menu.get_children():
		var tr := c as TextureRect
		if tr != null and tr.texture != null \
				and tr.texture.resource_path.contains("MenuBG_EDAA"):
			emblem = tr
	_report(emblem != null and emblem.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"菜单徽记背景完整容下(居中自适应, 不再出界裁切)")
	var found_title := false
	var stack: Array[Node] = [menu]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var l := n as Label
		if l != null and "静 默 之 前" in l.text:
			found_title = true
		for ch in n.get_children():
			stack.append(ch)
	_report(found_title, "主菜单标题已改「静默之前」(《Snuffers》前传定位)")
	menu.queue_free()


## P2b 高度地形(第一批): 平台+斜坡按配置生成(terrain 组) → 坡度 <45° 可行走 →
## 平台顶面碰撞高度精确。地形碰撞为独立 StaticBody(不进 WallCollision)，
## 墙碰撞不变式(墙碰撞体数==墙格数)由 _test_facade_props 断言保持。
func _test_p2b_terrain() -> void:
	var tcfg: Array = GameData.level_ext_cfg.get("terrain", [])
	var expect := 0
	var plat: Dictionary = {}
	var ramp: Dictionary = {}
	for t in tcfg:
		var td: Dictionary = t
		if int(td.get("map", -1)) != 0:
			continue
		var p: Dictionary = td.get("platform", {})
		var r: Dictionary = td.get("ramp", {})
		if not p.is_empty():
			expect += 1
			if plat.is_empty():
				plat = p
		if not r.is_empty():
			expect += 1
			if ramp.is_empty():
				ramp = r
	var terrain_nodes := get_tree().get_nodes_in_group("terrain")
	_report(terrain_nodes.size() == expect,
		"P2b 高度地形体: %d 个 (期望 %d, 平台+斜坡与配置一致)" % [terrain_nodes.size(), expect])
	if plat.is_empty() or ramp.is_empty():
		_report(false, "terrain 配置缺 platform/ramp")
		return

	# 坡度可行走(≤45°): CharacterBody3D 默认可行走上限
	var dir := str(ramp.get("dir", "E"))
	var along_x := dir == "E" or dir == "W"
	var span := float(int(ramp.get("w", 1)) if along_x else int(ramp.get("h", 1))) * WorldConst.CELL
	var slope_deg := rad_to_deg(atan2(float(ramp.get("height", 0.0)), span))
	_report(slope_deg > 0.0 and slope_deg < 45.0,
		"斜坡坡度可行走: %.1f° (0°<坡度<45°)" % slope_deg)

	# 平台顶面碰撞高度: 垂直射线自上方命中平台顶(排除玩家自身)
	var px := (float(int(plat.get("x", 0))) + float(int(plat.get("w", 1))) * 0.5) * WorldConst.CELL
	var pz := (float(int(plat.get("y", 0))) + float(int(plat.get("h", 1))) * 0.5) * WorldConst.CELL
	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(px, 4.0, pz), Vector3(px, -1.0, pz))
	ray.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(ray)
	var top_y := -99.0
	if not hit.is_empty():
		top_y = float(hit["position"].y)
	var expect_top := float(plat.get("height", 0.0))
	_report(absf(top_y - expect_top) < 0.05,
		"平台顶面碰撞高度: %.2fm (期望 %.2fm)" % [top_y, expect_top])


## 取本图(map0) terrain 段首个指定键的配置
func _p2b_first_cfg(key: String) -> Dictionary:
	for t in GameData.level_ext_cfg.get("terrain", []):
		var td: Dictionary = t
		if int(td.get("map", -1)) != 0:
			continue
		var c: Dictionary = td.get(key, {})
		if not c.is_empty():
			return c
	return {}


## 爬坡实测(第一批核心): 传送至斜坡底助跑位, 面向坡顶按住前进——
## 45 物理帧(0.75s)后应立于平台顶。帧位选在死亡/旗标测试之前的大空档
## (135→346), 避免与串行传送测试抢占玩家位置
func _p2b_climb_setup() -> void:
	var ramp: Dictionary = _p2b_first_cfg("ramp")
	if ramp.is_empty():
		_report(false, "爬坡测试: 无斜坡配置")
		return
	var dir := str(ramp.get("dir", "E"))
	var rx := float(int(ramp.get("x", 0))) * WorldConst.CELL
	var rz := float(int(ramp.get("y", 0))) * WorldConst.CELL
	var rw := float(int(ramp.get("w", 1))) * WorldConst.CELL
	var rh := float(int(ramp.get("h", 1))) * WorldConst.CELL
	# A批6: 组件/霰弹测试终点已上三层(物资上移), 此处先回一层再取基准——
	# 原实现先记 base_y 再传送, 三层残留 y(≈5.2) 会把高差口径污染成负值。
	# 传送 y=0.65 后重力沉降至地面 0, 基准取 0(与爬升起点同口径)
	_p2b_climb_base_y = 0.0
	_player.velocity = Vector3.ZERO
	match dir:
		"E":
			_player.global_position = Vector3(rx - 1.0, 0.65, rz + rh * 0.5)
			_player.rotation.y = -PI / 2
		"W":
			_player.global_position = Vector3(rx + rw + 1.0, 0.65, rz + rh * 0.5)
			_player.rotation.y = PI / 2
		"S":
			_player.global_position = Vector3(rx + rw * 0.5, 0.65, rz - 1.0)
			_player.rotation.y = PI
		"N":
			_player.global_position = Vector3(rx + rw * 0.5, 0.65, rz + rh + 1.0)
			_player.rotation.y = 0.0
	_key_down(KEY_W)


func _p2b_climb_check() -> void:
	_key_up(KEY_W)
	var rise := float(_player.global_position.y) - _p2b_climb_base_y
	_report(rise > 1.0,
		"玩家经斜坡登顶平台: 高差 %.2fm (>1.0m, 坡度可行走实证)" % rise)
	var plat: Dictionary = _p2b_first_cfg("platform")
	if plat.is_empty():
		return
	# 仍在平台矩形范围内(未冲出边缘跌落)
	var x0 := float(int(plat.get("x", 0))) * WorldConst.CELL
	var z0 := float(int(plat.get("y", 0))) * WorldConst.CELL
	var x1 := x0 + float(int(plat.get("w", 1))) * WorldConst.CELL
	var z1 := z0 + float(int(plat.get("h", 1))) * WorldConst.CELL
	_report(_player.global_position.x >= x0 and _player.global_position.x <= x1
		and _player.global_position.z >= z0 and _player.global_position.z <= z1,
		"玩家立于平台范围内: (%.1f, %.1f)" % [_player.global_position.x, _player.global_position.z])


## A批2 · 敌人 y 感知(多层前置): 配置垂直差阈值 + 运行时加载验证。
## 后续三步实测(190/240/243/250帧)用庭院既有平台/坡道:
## 坡道追击上升(地面吸附=重力+move_and_slide天然成立) → 隔层不侦测 → 同层回归
func _test_enemy_y_config() -> void:
	var templates: Array = GameData.enemy_templates()
	var all_have := templates.size() > 0
	for t in templates:
		var td: Dictionary = t
		if not td.has("detectionVerticalTolerance") \
				or float(td.get("detectionVerticalTolerance", 0.0)) <= 0.0:
			all_have = false
	_report(all_have, "敌人模板均配置垂直差阈值 detectionVerticalTolerance")
	var enemies := get_tree().get_nodes_in_group("enemies")
	if all_have and not enemies.is_empty():
		var e0: Node = enemies[0]
		_report(absf(float(e0.detection_vertical_tolerance) - 1.5) < 0.01,
			"敌人运行时垂直阈值已加载: %.2fm (期望 1.5m)"
			% float(e0.detection_vertical_tolerance))


## 布置: 玩家瞬移庭院平台顶(P2b 爬坡测试同位), 新敌放坡底平地开始追击。
## 平台高差1.3m < 阈值1.5m → 侦测成立, 敌人应沿坡道爬升追击
func _enemy_y_setup() -> void:
	_player.global_position = Vector3(363.0, 1.95, 58.0)  # 平台顶(顶面1.3m+站立0.65)
	_y_enemy = preload("res://scenes/entities/Enemy.tscn").instantiate()
	_y_enemy.template_id = 1
	_y_enemy.projectile_root = _main.get_node("Viewport")
	_entities.add_child(_y_enemy)
	_y_enemy.global_position = Vector3(353.0, 0.0, 58.0)  # 坡底前平地(敌原点在脚底)
	_y_enemy.velocity = Vector3.ZERO
	# 伤害清零: 本测试只验行为, 不让玩家掉血干扰后续测试流
	_y_enemy.fire_damage = 0
	_y_enemy.melee_damage = 0
	_y_enemy_start_y = 0.0


## 检查: 敌人应已沿坡道追击上升(50帧×5m/s≈4m, 坡中段); 随后构造隔层场景
func _enemy_y_check() -> void:
	if not is_instance_valid(_y_enemy):
		_report(false, "y感知测试敌人失效")
		return
	var ey := float(_y_enemy.global_position.y)
	var ex := float(_y_enemy.global_position.x)
	_report(ey > _y_enemy_start_y + 0.4,
		"敌人沿坡道追击上升: y=%.2fm (起点%.2f, 地面吸附+爬坡实证)" % [ey, _y_enemy_start_y])
	_report(ex > 354.0, "敌人朝平台玩家方向追击前进: x=%.1f" % ex)
	# 构造隔层: 敌人瞬移至玩家正上方高差≈3.2m(模拟楼板阻隔, 下落余量充足)
	_y_enemy.global_position = Vector3(363.0, 4.5, 55.0)
	_y_enemy.velocity = Vector3.ZERO


## 隔层断言: 高差超阈值 → 不侦测不追击不攻击(水平速度归零; 下落中 vy 不计入)
func _enemy_y_high_check() -> void:
	if not is_instance_valid(_y_enemy):
		_report(false, "y感知测试敌人失效(隔层)")
		return
	_report(is_zero_approx(float(_y_enemy.velocity.x)) and is_zero_approx(float(_y_enemy.velocity.z)),
		"隔层不侦测: 垂直差超阈值1.5m, 敌人静止不追击")
	# 同层回归布置: 敌我均移到平台顶(敌原点=顶面1.3), 相距约6m(>攻击范围4m, 走追击分支)
	_player.global_position = Vector3(365.0, 1.95, 58.0)
	_y_enemy.global_position = Vector3(360.3, 1.3, 54.3)
	_y_enemy.velocity = Vector3.ZERO


## 同层回归断言: 高差消除后侦测恢复, 敌人重新追击(平地行为不变)
func _enemy_y_floor_check() -> void:
	if not is_instance_valid(_y_enemy):
		_report(false, "y感知测试敌人失效(同层)")
		return
	var vsum := absf(float(_y_enemy.velocity.x)) + absf(float(_y_enemy.velocity.z))
	_report(vsum > 0.1,
		"同层侦测回归: 平台顶敌我约6m, 敌人恢复追击 (v=%.2f)" % vsum)
	_y_enemy.queue_free()
	_y_enemy = null


func _setup_weapon_pickup() -> void:
	for c in _entities.get_children():
		if "symbol" in c and c.symbol == "W":
			_player.global_position = c.global_position
			_report(true, "已传送至冲锋枪拾取物 @ %s" % c.global_position)
			return
	_report(false, "未找到冲锋枪拾取物")


func _check_weapon_grant() -> void:
	_report(_player.weapon_owned.size() == 3 and _player.weapon_owned[1],
		"拾取后持有冲锋枪")
	_report(_player.weapon_index == 1, "拾取后自动切换到冲锋枪 (index=%d)" % _player.weapon_index)
	_report(_player.ammo_clip == 30, "冲锋枪弹匣补满: %d (期望 30)" % _player.ammo_clip)


func _test_cycle_switch() -> void:
	if _player.weapon_index != 1:  # 前置失败则跳过，避免误报
		_cycle_test_done = true
		return
	# 基线 flake 加固: parse_input_event 在 headless 下的派发时机不稳，
	# 固定等 2 帧偶发赶不上事件冲刷；改为轮询至期望值出现（上限 10 帧）。
	# 语义不变（期望仍相同），仅消除时序竞态。
	_key_down(KEY_Q)
	_key_up(KEY_Q)
	for i in 10:
		await get_tree().physics_frame
		if _player.weapon_index == 0:
			break
	_report(_player.weapon_index == 0, "Q 切换到手枪 (index=%d)" % _player.weapon_index)
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	for i in 10:
		await get_tree().physics_frame
		if _player.weapon_index == 1:
			break
	_report(_player.weapon_index == 1, "滚轮上切换到冲锋枪 (index=%d)" % _player.weapon_index)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	for i in 10:
		await get_tree().physics_frame
		if _player.weapon_index == 0:
			break
	_report(_player.weapon_index == 0, "滚轮下切回手枪 (index=%d)" % _player.weapon_index)
	_cycle_test_done = true


func _setup_pickup() -> void:
	for c in _entities.get_children():
		if "symbol" in c and c.symbol == "C":
			_player.global_position = c.global_position
			_report(true, "已传送至金币 @ %s" % c.global_position)
			return
	_report(false, "未找到金币拾取物")


func _check_pickup() -> void:
	_report(_player.coins >= 1, "金币拾取生效: coins=%d" % _player.coins)


func _teleport_to_symbol(symbol: String, label: String) -> void:
	for c in _entities.get_children():
		if "symbol" in c and c.symbol == symbol:
			_player.global_position = c.global_position
			_report(true, "已传送至%s @ %s" % [label, c.global_position])
			return
	_report(false, "未找到%s拾取物" % label)


func _count_symbol(symbol: String) -> int:
	var n := 0
	for c in _entities.get_children():
		if "symbol" in c and c.symbol == symbol:
			n += 1
	return n


## 满血时急救包拒收: 拾取物保留原地（先强制满血保证确定性）；
## 顺带验证防护服能量: 拾取 +10 充能、伤害先扣能量再扣生命
func _test_health_full() -> void:
	_player.health_cur = _player.health_max
	var before := _count_symbol("H")
	_teleport_to_symbol("H", "急救包")
	_player.health_cur = _player.health_max  # 传送后再压一次，防敌袭干扰
	for i in 3:
		await get_tree().physics_frame
	_report(_player.health_cur == _player.health_max and _count_symbol("H") == before,
		"满血拒收急救包: HP %d/%d, 场上H=%d (期望 %d)"
		% [_player.health_cur, _player.health_max, _count_symbol("H"), before])

	_player.armor_cur = 0
	_teleport_to_symbol("e", "防护服电池")
	for i in 3:
		await get_tree().physics_frame
	_report(_player.armor_cur == 10, "防护服充能: armor=%d (期望 10)" % _player.armor_cur)
	var hp_before: int = _player.health_cur
	_player.take_damage(25)  # 能量 10 吸收 10，溢出 15 扣生命
	_report(_player.armor_cur == 0 and _player.health_cur == hp_before - 15,
		"能量优先承伤: armor=0, HP %d->%d (期望 %d)"
		% [hp_before, _player.health_cur, hp_before - 15])
	_health_test_done = true


## 通用升级组件端到端: 越级拦截 → 一级 → 二级 → 三级(手枪转全自动) →
## 满级拒收 / 弹匣到顶"a"拒收。
## 物理帧驱动（与 _test_cycle_switch 同法）：headless 下渲染帧与物理帧
## 不同步，固定帧号间隔不可靠，传送后必须等 physics_frame 让 body_entered 派发
func _test_components() -> void:
	while not _health_test_done:  # 串行传送，避免抢占玩家位置
		await get_tree().physics_frame
	# A批6: U 已上移三层 (6,27), 三层镇守敌(巨型宿主, 9,25) 距落点≈7m 在侦测范围内
	# ——本测试验拾取/数值而非战斗, 先把巨宿主伤害清零防干扰(位置不动, 在场断言不受影响)
	for e in get_tree().get_nodes_in_group("enemies"):
		if int(e.template_id) == 2:
			e.fire_damage = 0
			e.melee_damage = 0
	# 1) 未持有一级时踩二级: 不生效且拾取物保留
	_teleport_to_symbol("U", "二级组件")
	for i in 4:
		await get_tree().physics_frame
	_report(_player.weapon_tier == 0, "越级拾取被拦截: tier=%d (期望 0)" % _player.weapon_tier)
	_report(_count_symbol("U") == 1, "二级组件保留在场景中 (数量=%d)" % _count_symbol("U"))

	# 2) 拾取一级组件: 手枪 25发/伤害36，冲锋枪 40发/伤害36，射速 10→20
	_teleport_to_symbol("u", "一级组件")
	for i in 4:
		await get_tree().physics_frame
	var pistol: Dictionary = _player.weapons[0]
	var smg: Dictionary = _player.weapons[1]
	var sg: Dictionary = _player.weapons[2]
	_report(_player.weapon_tier == 1
		and int(pistol["clipSize"]) == 25 and int(pistol["damage"]) == 36,
		"一级组件生效: 手枪 tier=%d %d发/伤害%d (期望 1/25/36)"
		% [_player.weapon_tier, int(pistol["clipSize"]), int(pistol["damage"])])
	_report(int(smg["clipSize"]) == 40 and int(smg["damage"]) == 36,
		"一级组件生效: 冲锋枪 %d发/伤害%d (期望 40/36)"
		% [int(smg["clipSize"]), int(smg["damage"])])
	_report(int(sg["clipSize"]) == 12 and int(sg["pellets"]) == 7 and int(sg["damage"]) == 25,
		"一级组件生效: 霰弹枪 %d发/%d弹丸/伤害%d (期望 12/7/25)"
		% [int(sg["clipSize"]), int(sg["pellets"]), int(sg["damage"])])

	# 3) 拾取二级组件: 手枪 30发/伤害45，冲锋枪 50发/伤害45，射速 →30
	_teleport_to_symbol("U", "二级组件")
	for i in 4:
		await get_tree().physics_frame
	_report(_player.weapon_tier == 2
		and int(pistol["clipSize"]) == 30 and int(pistol["damage"]) == 45,
		"二级组件生效: 手枪 tier=%d %d发/伤害%d (期望 2/30/45)"
		% [_player.weapon_tier, int(pistol["clipSize"]), int(pistol["damage"])])
	_report(int(smg["clipSize"]) == 50 and int(smg["damage"]) == 45,
		"二级组件生效: 冲锋枪 %d发/伤害%d (期望 50/45)"
		% [int(smg["clipSize"]), int(smg["damage"])])
	_report(int(sg["clipSize"]) == 16 and int(sg["pellets"]) == 8 and int(sg["damage"]) == 30
		and sg["pump"] == false and sg["auto"] == false,
		"二级组件生效: 霰弹枪 %d发/%d弹丸/伤害%d 泵动=%s (期望 16/8/30/false=转半自动)"
		% [int(sg["clipSize"]), int(sg["pellets"]), int(sg["damage"]), str(sg["pump"])])

	# 4) 拾取三级组件: 手枪 33发/伤害55+转全自动，冲锋枪 60发/伤害55，射速封顶 40
	# A批6: v 已移出 map0(map0 spawns 无残留, 归 B批3 落 map2 丘顶)——就地生成临时
	# 三级组件在三层 (7,27)(U 旁地板格)再走拾取路径, 保持端到端语义(直接调
	# apply_weapon_component 会绕过拾取拒收/信号链路)
	var vp: Node3D = preload("res://scenes/entities/Pickup.tscn").instantiate()
	vp.symbol = "v"
	vp.position = Vector3((7 + 0.5) * WorldConst.CELL, 5.2, (27 + 0.5) * WorldConst.CELL)
	_entities.add_child(vp)
	_player.global_position = vp.position
	_player.velocity = Vector3.ZERO
	for i in 4:
		await get_tree().physics_frame
	_report(_player.weapon_tier == 3
		and int(pistol["clipSize"]) == 33 and int(pistol["damage"]) == 55
		and pistol["auto"] == true,
		"三级组件生效: 手枪 tier=%d %d发/伤害%d/全自动=%s (期望 3/33/55/true)"
		% [_player.weapon_tier, int(pistol["clipSize"]), int(pistol["damage"]), str(pistol["auto"])])
	_report(int(smg["clipSize"]) == 60 and int(smg["damage"]) == 55,
		"三级组件生效: 冲锋枪 %d发/伤害%d (期望 60/55)"
		% [int(smg["clipSize"]), int(smg["damage"])])
	_report(int(sg["clipSize"]) == 24 and int(sg["pellets"]) == 10 and int(sg["damage"]) == 40
		and sg["auto"] == true,
		"三级组件生效: 霰弹枪 %d发/%d弹丸/伤害%d/全自动=%s (期望 24/10/40/true)"
		% [int(sg["clipSize"]), int(sg["pellets"]), int(sg["damage"]), str(sg["auto"])])
	var sg_rate := 1.0 / float(sg["fireInterval"])
	_report(absf(sg_rate - 3.0) < 0.01,
		"霰弹枪三阶全自动低速: 射速%.1f (期望 3.0，独立于+10叠加)" % sg_rate)
	var pistol_rate := 1.0 / float(pistol["fireInterval"])
	var smg_rate := 1.0 / float(smg["fireInterval"])
	_report(absf(pistol_rate - 40.0) < 0.01 and absf(smg_rate - 40.0) < 0.01,
		"三阶射速封顶: 手枪%.0f/冲锋枪%.0f (期望 40/40)" % [pistol_rate, smg_rate])

	# 5) 满级后再遇组件: 直接调用验证拒收（tier 不前进）
	_report(not _player.apply_weapon_component(3) and _player.weapon_tier == 3,
		"满级组件拒收: tier=%d (期望 3)" % _player.weapon_tier)
	_components_test_done = true


## 霰弹枪端到端（组件三阶之后）: 北部仓库拾取 → 自动切换/弹匣补满 →
## 单发弹丸数验证 → 12号霰弹补给 +6
func _test_shotgun() -> void:
	while not _components_test_done:  # 串行传送，避免抢占玩家位置
		await get_tree().physics_frame
	var sg: Dictionary = _player.weapons[2]

	_teleport_to_symbol("T", "霰弹枪")
	for i in 4:
		await get_tree().physics_frame
	_report(_player.weapon_owned[2], "拾取后持有霰弹枪")
	_report(_player.weapon_index == 2, "拾取后自动切换到霰弹枪 (index=%d)" % _player.weapon_index)
	_report(_main.get_node("HUD").ammo_label.text.contains("12号霰弹"),
		"HUD 弹药口径显示(霰弹枪): %s" % _main.get_node("HUD").ammo_label.text)
	_report(_player.ammo_clip == int(sg["clipSize"]),
		"霰弹枪弹匣补满: %d (期望 %d，三阶 24)" % [_player.ammo_clip, int(sg["clipSize"])])

	# 弹丸数: 直接击发一发，数玩家弹道实体增量（敌对弹道 from_player=false 不计）
	var vp: Node = _main.get_node("Viewport")
	var count_player_projs := func() -> int:
		var n := 0
		for c in vp.get_children():
			if "from_player" in c and c.from_player:
				n += 1
		return n
	var before: int = count_player_projs.call()
	var clip_before: int = _player.ammo_clip
	_player._shoot()
	_report(count_player_projs.call() - before == int(sg["pellets"]),
		"单发弹丸: %d 颗 (期望 %d，三阶 10)" % [count_player_projs.call() - before, int(sg["pellets"])])
	_report(_player.ammo_clip == clip_before - 1,
		"霰弹一发耗一壳: %d -> %d" % [clip_before, _player.ammo_clip])

	var reserve_before: int = _player.ammo_reserve
	_teleport_to_symbol("s", "12号霰弹")
	for i in 4:
		await get_tree().physics_frame
	_report(_player.ammo_reserve == reserve_before + 6,
		"12号霰弹补给: 备弹 %d -> %d (期望 +6)" % [reserve_before, _player.ammo_reserve])
	_shotgun_test_done = true


func _setup_shoot() -> void:
	while not _components_test_done or not _shotgun_test_done:  # 传送测试串行，避免抢占玩家位置
		await get_tree().physics_frame
	_player._switch_to(0)  # 切回手枪：命中断言按单发子弹伤害校验（霰弹为多弹丸）
	# A批6: 组件/霰弹测试终点在三层(物资上移)——射击隔离回到一层开阔地 (20,35)
	# (原冲锋枪落位, 现为地板), _path_clear 为一层墙格口径, 层墙会误判弹道遮挡
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3((20 + 0.5) * WorldConst.CELL, 0.65, (35 + 0.5) * WorldConst.CELL)
	var enemy: Node
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			enemy = e
			break
	if enemy == null:
		_report(false, "无可用敌人目标")
		return
	_enemy_target = enemy
	_enemy_hp_before = enemy.health
	# 隔离测试: 移除其他敌人，防止追击者拦截子弹（世界生成已由数量断言覆盖）
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != enemy:
			e.queue_free()
	var dirs := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
	for d in dirs:
		if _path_clear(_player.global_position, d, 4.0):
			enemy.global_position = _player.global_position + d * 4.0
			_player.look_at(Vector3(enemy.global_position.x, _player.global_position.y, enemy.global_position.z))
			_ammo_before = _player.ammo_clip
			_player._shoot()
			_report(true, "射击布置完成（距离 4m）")
			return
	_report(false, "找不到开阔射击方向")


func _path_clear(from: Vector3, dir: Vector3, dist: float) -> bool:
	var steps := 8
	for i in range(1, steps + 1):
		var p := from + dir * (dist * float(i) / float(steps))
		if _level.is_wall(int(p.x / WorldConst.CELL), int(p.z / WorldConst.CELL)):
			return false
	return true


func _check_shoot() -> void:
	if _enemy_target == null:
		return
	var dmg: int = int(_player.weapons[_player.weapon_index]["damage"])
	if not is_instance_valid(_enemy_target):
		_report(true, "子弹击杀敌人")
	else:
		var hp: int = _enemy_target.health
		_report(hp == _enemy_hp_before - dmg,
			"子弹命中敌人: HP %d -> %d (伤害 %d)" % [_enemy_hp_before, hp, dmg])
	_report(_player.ammo_clip == _ammo_before - 1,
		"弹药消耗: %d -> %d" % [_ammo_before, _player.ammo_clip])
	var hud: Node = _main.get_node("HUD")
	hud.play_weapon_reload(_player.weapon_id(), 0.2)
	_report(hud.is_weapon_reloading(), "当前武器独立换弹动画已启动")
	hud.finish_weapon_reload()
	if is_instance_valid(_enemy_target):
		_enemy_target.take_damage(9999)
		_report(_enemy_target.is_dying and _enemy_target.health == 0,
			"敌人死亡状态启动，尸体未立即消失")
		_verify_death_cleanup()


func _check_death_collision() -> void:
	if is_instance_valid(_enemy_target):
		var shape: CollisionShape3D = _enemy_target.get_node("CollisionShape3D")
		_report(shape.disabled, "死亡敌人碰撞已关闭，不再阻挡玩家与子弹")


func _verify_death_cleanup() -> void:
	var feedback: Dictionary = GameData.enemies_cfg.get("feedback", {})
	var total := float(feedback.get("deathFallTime", 0.34)) \
		+ float(feedback.get("corpseStayTime", 1.25)) \
		+ float(feedback.get("corpseBlinkTime", 0.55)) \
		+ float(feedback.get("deathFadeTime", 0.4)) + 0.2
	await get_tree().create_timer(total, true).timeout
	_report(not is_instance_valid(_enemy_target), "死亡尸体完成停留、闪烁并淡出清理")
	_death_test_done = true
	# A批5: 楼梯三角度实走(帧251起, 约230帧)期间玩家不可被旗标传送抢占——
	# 等登顶测试完成后才传送至终点旗(campaign_flow 的 600 帧等待余量充足)
	while not _layer_test_done:
		await get_tree().physics_frame
	# A批6 · 撤离闭锁: 未合闸触旗 → 不判通关 + toast 在场 + 旗保留
	_setup_flag()
	await get_tree().create_timer(0.2, true).timeout
	_report(not _main.game_over, "撤离闭锁: 未合闸触旗不判通关 (game_over=false)")
	var hud: Node = _main.get_node("HUD")
	var gate_cfg: Dictionary = GameData.narrative_cfg.get("gate", {})
	var toast: Label = hud.get("_toast")
	_report(toast != null and toast.visible and toast.text == str(gate_cfg.get("toastLocked", "")),
		"撤离闭锁 toast 在场: %s" % (toast.text if toast else "<missing>"))
	var flags_left := 0
	for c in _entities.get_children():
		if c.has_signal("reached"):
			flags_left += 1
	_report(flags_left == 1, "未通电触旗后终点旗保留(不消旗, 通电可再触): %d" % flags_left)
	# 合闸: 传送至配电箱触发区 (15,18) 二层(落板沉降) → 走进触发(零新按键)
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(31.0, 3.25, 37.0)
	await get_tree().create_timer(0.3, true).timeout
	_report(_level.gate_powered, "合闸触发: gate_powered=true (走进触发区, 一次性)")
	# A批6.1: 合闸后小地图闭锁解除(信标恢复绿色实心点)
	var mm_lock: Node = hud.get_node_or_null("MiniMap")
	_report(mm_lock != null and not mm_lock.flag_locked(),
		"小地图闭锁解除: 合闸后撤离信标恢复可用表现")
	var toast2: Label = hud.get("_toast")
	_report(toast2 != null and toast2.visible and toast2.text == str(gate_cfg.get("toastPowered", "")),
		"合闸 toast 在场: %s" % (toast2.text if toast2 else "<missing>"))
	var br: MeshInstance3D = _level.get_decal("breaker_2f")
	var gt: MeshInstance3D = _level.get_decal("gate_cargo")
	var br_on := br != null and ((br.mesh as QuadMesh).material as StandardMaterial3D) \
		.albedo_texture.resource_path.ends_with("Breaker On.bmp")
	var gt_open := gt != null and ((gt.mesh as QuadMesh).material as StandardMaterial3D) \
		.albedo_texture.resource_path.ends_with("Gate Cargo Open.bmp")
	_report(br_on, "合闸后配电箱换贴图: Breaker On(绿灯)")
	_report(gt_open, "合闸后大门贴花切换: Gate Cargo Open(卷帘升起)")
	var obj: Label = hud.get("_objective")
	_report(obj != null and obj.text == str(gate_cfg.get("objectivePowered", "")),
		"HUD 目标行随合闸切换: %s" % (obj.text if obj else "<missing>"))
	# 通电后再触旗 → 正常通关
	_setup_flag()
	await get_tree().create_timer(0.2, true).timeout
	_check_flag()


func _setup_flag() -> void:
	for c in _entities.get_children():
		if c.has_signal("reached"):
			_player.global_position = c.global_position
			_report(true, "已传送至终点旗")
			return
	_report(false, "未找到终点旗")


func _check_flag() -> void:
	_report(_main.game_over == true, "通关判定触发 (game_over=true)")
	_flag_test_done = true


func _finish() -> void:
	while not _noop_test_done or not _cycle_test_done or not _components_test_done \
			or not _shotgun_test_done or not _health_test_done or not _death_test_done \
			or not _flag_test_done or not _campaign_test_done or not _layer_test_done \
			or not _minimap_floor_test_done or not _gate_static_test_done:
		await get_tree().physics_frame
	print("[SMOKE] 结果: %s" % ("全部通过" if not _fail else "存在失败项"))
	get_tree().quit(1 if _fail else 0)
