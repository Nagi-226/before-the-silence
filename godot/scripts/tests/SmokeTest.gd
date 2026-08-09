extends Node
## SmokeTest — headless 端到端自检（可长期保留作回归测试）
## 覆盖: 世界生成(含a/w移除与防护服生成) / 武器持有模型 / 武器拾取 /
##       Q+滚轮循环切换 / 金币拾取 / 满血拒收急救包 / 防护服充能与优先承伤 /
##       通用升级组件(顺序拦截+一二三级数值+射速叠加+满级拒收) /
##       子弹命中敌人 / 弹药消耗 / 终点旗通关判定
## 运行: godot --path godot --headless res://scenes/tests/SmokeTest.tscn

var _frame := 0
var _fail := false

var _main: Node
var _player: Node
var _level: Node
var _entities: Node

var _enemy_target: Node
var _enemy_hp_before := 0
var _ammo_before := 0
var _noop_test_done := false
var _cycle_test_done := false
var _components_test_done := false
var _health_test_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = $Main
	_player = _main.get_node("Viewport/Player")
	_level = _main.get_node("Viewport/Level")
	_entities = _main.get_node("Viewport/Entities")


func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		2: _main.dismiss_briefing()
		5: _check_world_built()
		7: _check_weapons_cfg()
		8: _test_initial_noop()
		12: _setup_weapon_pickup()
		25: _check_weapon_grant()
		27: _test_cycle_switch()
		40: _setup_pickup()
		55: _check_pickup()
		56: _test_health_full()
		57: _test_components()
		85: _setup_shoot()
		130: _check_shoot()
		135: _setup_flag()
		175: _check_flag()
		181: _finish()


func _report(ok: bool, msg: String) -> void:
	print("[SMOKE] %s | %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		_fail = true


func _check_world_built() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	_report(enemies.size() >= 10, "敌人数量: %d (期望 >= 10)" % enemies.size())
	var pickup_count := 0
	var has_weapon_pickup := false
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
	_report(has_comp1 and has_comp2 and has_comp3, "一/二/三级升级组件已按配置生成")
	_report(has_armor, "防护服能量补给已生成（a 符号位改造）")
	_report(legacy_count == 0, "扩展弹匣/神经加速器已实机移除 (残留=%d)" % legacy_count)
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
	_report(_player.weapons.size() == 2, "双武器配置: %d 把 (期望 2)" % _player.weapons.size())
	if _player.weapons.size() == 2:
		var pistol: Dictionary = _player.weapons[0]
		var smg: Dictionary = _player.weapons[1]
		_report(pistol["auto"] == false and int(pistol["clipSize"]) == 20,
			"手枪: 半自动 弹匣 %d (期望 20)" % int(pistol["clipSize"]))
		_report(smg["auto"] == true and str(smg["displayName"]) == "冲锋枪",
			"冲锋枪: 全自动就绪")
	_report(_player.weapon_owned.size() == 2 and _player.weapon_owned[0] and not _player.weapon_owned[1],
		"初始持有模型: 仅手枪")
	_report(_player.health_max == 100, "玩家血量上限: %d (期望 100)" % _player.health_max)


func _setup_weapon_pickup() -> void:
	for c in _entities.get_children():
		if "symbol" in c and c.symbol == "W":
			_player.global_position = c.global_position
			_report(true, "已传送至冲锋枪拾取物 @ %s" % c.global_position)
			return
	_report(false, "未找到冲锋枪拾取物")


func _check_weapon_grant() -> void:
	_report(_player.weapon_owned.size() == 2 and _player.weapon_owned[1],
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
	_report(_player.weapon_tier == 1
		and int(pistol["clipSize"]) == 25 and int(pistol["damage"]) == 36,
		"一级组件生效: 手枪 tier=%d %d发/伤害%d (期望 1/25/36)"
		% [_player.weapon_tier, int(pistol["clipSize"]), int(pistol["damage"])])
	_report(int(smg["clipSize"]) == 40 and int(smg["damage"]) == 36,
		"一级组件生效: 冲锋枪 %d发/伤害%d (期望 40/36)"
		% [int(smg["clipSize"]), int(smg["damage"])])

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
	var pistol_rate := 1.0 / float(pistol["fireInterval"])
	var smg_rate := 1.0 / float(smg["fireInterval"])
	_report(absf(pistol_rate - 40.0) < 0.01 and absf(smg_rate - 40.0) < 0.01,
		"三阶射速封顶: 手枪%.0f/冲锋枪%.0f (期望 40/40)" % [pistol_rate, smg_rate])

	# 5) 满级后再遇组件: 直接调用验证拒收（tier 不前进）
	_report(not _player.apply_weapon_component(3) and _player.weapon_tier == 3,
		"满级组件拒收: tier=%d (期望 3)" % _player.weapon_tier)
	_components_test_done = true


func _setup_shoot() -> void:
	while not _components_test_done:  # 组件测试传送中，避免抢占玩家位置
		await get_tree().physics_frame
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


func _setup_flag() -> void:
	for c in _entities.get_children():
		if c.has_signal("reached"):
			_player.global_position = c.global_position
			_report(true, "已传送至终点旗")
			return
	_report(false, "未找到终点旗")


func _check_flag() -> void:
	_report(_main.game_over == true, "通关判定触发 (game_over=true)")


func _finish() -> void:
	while not _noop_test_done or not _cycle_test_done or not _components_test_done or not _health_test_done:
		await get_tree().physics_frame
	print("[SMOKE] 结果: %s" % ("全部通过" if not _fail else "存在失败项"))
	get_tree().quit(1 if _fail else 0)
