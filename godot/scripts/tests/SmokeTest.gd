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
##       菜单身份(徽记完整容下不出界/标题静默之前) / HUD弹药口径显示(9×19mm/12号霰弹)
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
	_report(has_weapon_pickup, "冲锋枪拾取物已按配置生成")
	_report(has_shotgun_pickup, "霰弹枪拾取物已按配置生成（北部仓库）")
	_report(_count_symbol("s") == 8, "12号霰弹补给: %d 处 (期望 8)" % _count_symbol("s"))
	_report(has_comp1 and has_comp2 and has_comp3, "一/二/三级升级组件已按配置生成")
	_report(has_armor, "防护服能量补给已生成（a 符号位改造）")
	_report(legacy_count == 0, "扩展弹匣/神经加速器已实机移除 (残留=%d)" % legacy_count)
	# 道具平衡（map0）: a(5)+w(5)+每4个H(109→27) → e=37；H 保留 82
	_report(_count_symbol("e") == 37, "防护服电池数量: %d (期望 37)" % _count_symbol("e"))
	_report(_count_symbol("H") == 82, "急救包数量: %d (期望 82)" % _count_symbol("H"))
	_report(get_tree().get_first_node_in_group("player") != null, "玩家节点就绪")
	var mm: Node = _main.get_node("HUD").get_node_or_null("MiniMap")
	_report(mm != null and mm.get("_wall_tex") != null, "HUD 小地图已就绪")


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
	# 覆盖的每个格都须在 wall_cells 中。历史坑: 大门曾误配 y=37(空地),
	# 真墙在 row 38 → 贴花悬浮空中 2 米, 仅查数量的断言漏检
	for d in dcfg:
		var dd: Dictionary = d
		if int(dd.get("map", -1)) != 0:
			continue
		var x0 := int(dd.get("x", 0))
		var y0 := int(dd.get("y", 0))
		var dw := maxi(1, int(dd.get("w", 1)))
		var on_wall := true
		for i in dw:
			if not _level.wall_cells.has(Vector2i(x0 + i, y0)):
				on_wall = false
		_report(on_wall,
			"墙面贴花挂在真实墙格上: (%d,%d) 起 %d 格" % [x0, y0, dw])

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
	_p2b_climb_base_y = _player.global_position.y
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
	_key_down(KEY_Q)
	_key_up(KEY_Q)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_report(_player.weapon_index == 0, "Q 切换到手枪 (index=%d)" % _player.weapon_index)
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_report(_player.weapon_index == 1, "滚轮上切换到冲锋枪 (index=%d)" % _player.weapon_index)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await get_tree().physics_frame
	await get_tree().physics_frame
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
	_teleport_to_symbol("v", "三级组件")
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
	while not _noop_test_done or not _cycle_test_done or not _components_test_done or not _shotgun_test_done or not _health_test_done or not _death_test_done or not _flag_test_done:
		await get_tree().physics_frame
	print("[SMOKE] 结果: %s" % ("全部通过" if not _fail else "存在失败项"))
	get_tree().quit(1 if _fail else 0)
