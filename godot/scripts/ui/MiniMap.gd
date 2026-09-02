extends Control
class_name MiniMap
## MiniMap — HUD 右上角俯视小地图（数据驱动，零额外渲染开销）
## 墙体由 LevelGenerator.wall_cells 一次性预渲染为 ImageTexture；
## 每帧仅叠加玩家箭头 / 敌人红点 / 信标绿点。1 地图格 = 1 纹理像素。
## P1.5 跟随模式（level_ext.json: miniMapFollow）: 地图任一维超过跟随视窗时
## 启用窗口裁剪绘制，玩家居中、贴边钳制；实体点按视窗偏移换算，越界不绘制。
## A批6 楼层化: 按玩家脚部 y 判定当前楼层(WorldConst.floor_at_y, 与交互点同口径),
## 墙体纹理按楼层切换——1F=wall_cells(含 partitions), 2F/3F=对应层 grid 墙格;
## 无 layers 的图永远 1F 表现(向后兼容)。
## A批6.1 视觉修订(用户实机反馈): 楼梯间 footprint 整格填琥珀色块(原 1.8px
## 小圆点与敌人红点同形难辨识); 撤离信标有闸图未通电画红色空心环(闭锁态,
## 与 Main._on_victory 拒通关同口径), 通电后/无闸图恢复绿色实心点。
## A批7 楼层角标: 有多层的图左上角画当前楼层 "1F/2F/3F"(用户实机上了三层
## 而未意识到——楼层切换无存在感); 无 layers 图不画(向后兼容)。
## A批8 目标标记(用户实机反馈: 冲锋枪/霰弹枪/电闸/升级组件找不到):
## 武器与组件画菱形(与敌人/信标圆点、楼梯方块均异形), 每种目标一种颜色;
## 配电箱画方块+白心(未通电), 通电后转暗淡; 当前楼层实色大标记,
## 其他楼层半透明小标记(提示存在但不混淆); 拾取物 queue_free 后标记自然消失。

const SCALE := 1.25  # 纹理像素 → 屏幕像素
const MARGIN := 12.0  # 距屏幕右上角间距
const COLOR_BG := Color(0.01, 0.02, 0.03, 0.55)
const COLOR_BORDER := Color(0.35, 0.55, 0.6, 0.8)
const COLOR_WALL := Color(0.55, 0.7, 0.75, 0.95)
const COLOR_PLAYER := Color(1.0, 0.92, 0.25)  # 亮黄，与墙体青色区分
const COLOR_ENEMY := Color(1.0, 0.3, 0.25)
const COLOR_FLAG := Color(0.35, 1.0, 0.45)
const COLOR_FLAG_LOCKED := Color(1.0, 0.32, 0.28)  # A批6.1: 撤离闭锁态红(空心环)
const COLOR_STAIR := Color(1.0, 0.68, 0.12)  # A批6.1: 楼梯间琥珀色块(整格实心)
const COLOR_BADGE := Color(1.0, 0.92, 0.25)  # A批7: 楼层角标亮黄(与玩家箭头同系)
const COLOR_BADGE_BG := Color(0.01, 0.02, 0.03, 0.72)  # 角标底衬(墙体上也可读)
# A批8 目标标记配色: 每种目标一色, 均与既有圆点系(敌红/信标绿/玩家黄)拉开色相
const MARK_COLORS := {
	"W": Color(0.25, 0.75, 1.0),   # 冲锋枪 — 天蓝
	"T": Color(1.0, 0.35, 0.80),   # 霰弹枪 — 洋红
	"u": Color(0.30, 1.0, 0.85),   # 1阶组件 — 青绿
	"U": Color(0.78, 0.48, 1.0),   # 2阶组件 — 紫
	"v": Color(1.0, 1.0, 1.0),     # 3阶组件 — 白
}
const COLOR_BREAKER := Color(1.0, 0.45, 0.10)      # 电闸未通电 — 亮橙红
const COLOR_BREAKER_ON := Color(0.42, 0.30, 0.20)  # 已通电 — 暗淡(目标已达成)
const MARK_OTHER_ALPHA := 0.34  # 非当前楼层标记透明度
const MARK_R_CUR := 2.8         # 当前楼层菱形半径
const MARK_R_OTHER := 1.9       # 其他楼层菱形半径

var _wall_tex: ImageTexture
var _map_size := Vector2i.ZERO  # 地图总尺寸（纹理像素 = 格）
var _follow := false            # P1.5 窗口跟随开关
var _view := Vector2i.ZERO      # 跟随视窗尺寸（格）
var _src := Vector2.ZERO        # 视窗左上角在地图上的格坐标
var _player: Node3D
var _entities: Node3D
var _level: Node
var _ready_flag := false
# A批6 楼层化: 楼层 -> 墙体纹理 / 墙格集; 当前楼层
var _floor_texes := {}
var _floor_cells := {}
var _floor := 1


## 由 Main 在 level.build 之后调用
func setup(level: Node, player: Node3D, entities: Node3D) -> void:
	_player = player
	_entities = entities
	_level = level
	var w: int = LevelData.WIDTH
	var h: int = LevelData.HEIGHT
	# 符号地图实际行数可能超出 HEIGHT 常量（自动生成数据的尾行），按实际墙格取界
	for cell: Vector2i in level.wall_cells:
		w = maxi(w, cell.x + 1)
		h = maxi(h, cell.y + 1)
	_map_size = Vector2i(w, h)
	# A批6 楼层化: 逐楼层预渲染墙体纹理(1F=wall_cells; 2F/3F=层墙格, 无层不建)
	_floor_texes.clear()
	_floor_cells.clear()
	_floor = 1
	_floor_cells[1] = level.wall_cells.keys()
	_floor_texes[1] = _render_walls(level.wall_cells)
	for f in [2, 3]:
		var cells: Dictionary = level.get_layer_cells(f)
		if cells.is_empty():
			continue
		_floor_cells[f] = cells.keys()
		_floor_texes[f] = _render_walls(cells)
	_wall_tex = _floor_texes[1]

	# P1.5 跟随模式: 配置开启且地图确实大于视窗时生效，否则回退整图模式
	_follow = bool(GameData.level_ext_cfg.get("miniMapFollow", false))
	var fv: Dictionary = GameData.level_ext_cfg.get("followView", {})
	if _follow and not fv.is_empty():
		_view = Vector2i(int(fv.get("w", w)), int(fv.get("h", h)))
	_follow = _follow and _view.x > 0 and _view.y > 0 \
		and (_map_size.x > _view.x or _map_size.y > _view.y)
	if not _follow:
		_view = _map_size

	# CanvasLayer 直接子节点的锚点不会相对视口解析，显式按视口尺寸定位
	size = Vector2(_view) * SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_reposition()
	# B线转关会重复调用 setup: 防重复连接 resize 信号
	if not get_tree().root.size_changed.is_connected(_reposition):
		get_tree().root.size_changed.connect(_reposition)
	_ready_flag = true


## 墙格集 → 透明底墙体纹理(1 格 = 1 像素)
func _render_walls(cells: Dictionary) -> ImageTexture:
	var img := Image.create(_map_size.x, _map_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for cell: Vector2i in cells:
		img.set_pixelv(cell, COLOR_WALL)
	return ImageTexture.create_from_image(img)


## A批6: 当前楼层(供测试断言)
func current_floor() -> int:
	return _floor


## A批6: 指定楼层墙格集(供测试断言, 与生成器口径比对)
func floor_cells(f: int) -> Array:
	return _floor_cells.get(f, [])


## A批6.1: 撤离信标闭锁态——有闸图未通电(与 Main._on_victory 拒通关同口径);
## 供 _draw 换色与测试断言
func flag_locked() -> bool:
	return _level != null and _level.has_gate() and not _level.gate_powered


func _reposition() -> void:
	var vp := get_viewport().get_visible_rect().size
	position = Vector2(vp.x - size.x - MARGIN, MARGIN)


func _process(_delta: float) -> void:
	if not _ready_flag:
		return
	if not is_instance_valid(_player):
		return
	# A批6 楼层化: 玩家脚部 y → 楼层, 变化即切换墙体纹理(同节点换 tex,
	# 不重建节点——规避转关重建路径的同名节点坑)
	var f := WorldConst.floor_at_y(_player.global_position.y)
	if f != _floor and _floor_texes.has(f):
		_floor = f
		_wall_tex = _floor_texes[f]
	if _follow:
		# 玩家居中，贴边钳制；取整对齐纹理像素避免采样半像素发糊
		var center := Vector2(
			_player.global_position.x / WorldConst.CELL,
			_player.global_position.z / WorldConst.CELL)
		var target := center - Vector2(_view) * 0.5
		target.x = clampf(target.x, 0.0, float(maxi(_map_size.x - _view.x, 0)))
		target.y = clampf(target.y, 0.0, float(maxi(_map_size.y - _view.y, 0)))
		_src = target.floor()
	queue_redraw()


func _map_px(world_pos: Vector3) -> Vector2:
	return Vector2(world_pos.x / WorldConst.CELL, world_pos.z / WorldConst.CELL) * SCALE


## 世界坐标 → 当前小地图控件上的屏幕坐标（跟随模式下叠加视窗偏移）
func _onscreen(world_pos: Vector3) -> Vector2:
	return _map_px(world_pos) - _src * SCALE


func _in_view(p: Vector2) -> bool:
	return p.x >= -4.0 and p.y >= -4.0 \
		and p.x <= size.x + 4.0 and p.y <= size.y + 4.0


func _draw() -> void:
	if not _ready_flag:
		return
	# 底板与边框
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER, false, 1.0)
	if _follow:
		# 区域裁剪绘制：源矩形为当前跟随视窗
		draw_texture_rect_region(_wall_tex, Rect2(Vector2.ZERO, size),
			Rect2(_src, Vector2(_view)))
	else:
		draw_texture_rect(_wall_tex, Rect2(Vector2.ZERO, size), false)

	# A批6.1: 楼梯间标记——footprint 整格填琥珀色块(2×2 格实心, 轮廓一眼可辨;
	# 原 1.8px 小圆点与敌人红点同形同大小, 用户实机反馈认不出)
	if _level != null:
		for cell: Vector2i in _level.get_stair_marks(_floor):
			var tl := _onscreen(Vector3(
				cell.x * WorldConst.CELL, 0.0, cell.y * WorldConst.CELL))
			if _in_view(tl):
				draw_rect(Rect2(tl, Vector2(SCALE, SCALE)), COLOR_STAIR)

	# 敌人红点（跳过已释放/濒死无效节点与视窗外）
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			var ep := _onscreen(e.global_position)
			if _in_view(ep):
				draw_circle(ep, 1.6, COLOR_ENEMY)

	# A批8: 目标标记(武器/升级组件/电闸)——盖在敌人红点之上保目标可辨
	_draw_target_marks()

	# 撤离信标: A批6.1 闭锁态可视化——有闸未通电画红色空心环(触旗不判通关),
	# 通电后/无闸图画绿色实心点(空心环与敌人实心红点亦明显区分)
	var locked := flag_locked()
	for c in _entities.get_children():
		if is_instance_valid(c) and c.has_signal("reached"):
			var cp := _onscreen(c.global_position)
			if _in_view(cp):
				if locked:
					draw_arc(cp, 2.4, 0.0, TAU, 12, COLOR_FLAG_LOCKED, 1.0)
				else:
					draw_circle(cp, 2.2, COLOR_FLAG)

	# 玩家箭头（朝向 = 相机前方 -Z 投影到地图平面）
	if is_instance_valid(_player):
		var p := _onscreen(_player.global_position)
		var rot: float = _player.rotation.y
		var fwd := Vector2(-sin(rot), -cos(rot))
		var side := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([
			p + fwd * 5.0,
			p - fwd * 3.4 + side * 3.0,
			p - fwd * 3.4 - side * 3.0,
		]), COLOR_PLAYER)

	# A批7: 楼层角标——仅多层图(建了 2F/3F 纹理)左上角画当前楼层,
	# 底衬暗块保墙体密集处可读; 字号按视口像素(窗口放大后清晰)
	if _floor_texes.size() > 1:
		var badge := "%dF" % _floor
		var font := ThemeDB.fallback_font
		var fs := 7
		var ts := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var bp := Vector2(2.0, 1.0)
		draw_rect(Rect2(bp, ts + Vector2(3.0, 2.0)), COLOR_BADGE_BG)
		draw_string(font, bp + Vector2(1.5, 1.0 + ts.y * 0.8), badge,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_BADGE)


## A批7: 楼层角标文本(供测试断言; 无层图返回空串)
func floor_badge() -> String:
	return "%dF" % _floor if _floor_texes.size() > 1 else ""


## A批8: 目标标记绘制。拾取物走 _entities 子节点(Pickup.symbol), 电闸走
## level.get_gate_marks()。跨楼层区分: 当前层实色大标记, 其他层半透明小标记
## (单层图恒视为当前层, 见 _is_current_floor)。
func _draw_target_marks() -> void:
	if _entities != null:
		for c in _entities.get_children():
			if not is_instance_valid(c) or not ("symbol" in c):
				continue
			var sym := str(c.get("symbol"))
			if not MARK_COLORS.has(sym):
				continue
			var p := _onscreen(c.global_position)
			if not _in_view(p):
				continue
			var cur := _is_current_floor(
				WorldConst.floor_at_y(c.global_position.y))
			var col: Color = MARK_COLORS[sym]
			_draw_diamond(p, col, cur)
	if _level == null or not _level.has_gate():
		return
	var powered: bool = _level.gate_powered
	for entry in _level.get_gate_marks():
		var d: Dictionary = entry
		var pos2: Vector2 = d.get("pos", Vector2.ZERO)
		var p := _onscreen(Vector3(pos2.x, 0.0, pos2.y))
		if not _in_view(p):
			continue
		var cur := _is_current_floor(int(d.get("floor", 1)))
		_draw_breaker_mark(p, COLOR_BREAKER_ON if powered else COLOR_BREAKER,
			cur, cur and not powered)


## 菱形标记(与圆点/方块异形, 目标类别一眼可辨)
func _draw_diamond(p: Vector2, col: Color, current: bool) -> void:
	var r: float = MARK_R_CUR if current else MARK_R_OTHER
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0.0, -r), p + Vector2(r, 0.0),
		p + Vector2(0.0, r), p + Vector2(-r, 0.0),
	]), _mark_color(col, current))


## 电闸标记: 方块, 未通电且在本层时加白心(强提示"去这里合闸");
## 已通电保留实色尺寸仅换暗淡色(目标已达成但仍可辨位)
func _draw_breaker_mark(p: Vector2, col: Color, current: bool,
		white_core: bool) -> void:
	var s: float = 5.0 if current else 3.4
	draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)),
		_mark_color(col, current))
	if white_core:
		draw_circle(p, 1.1, Color(1.0, 1.0, 1.0, 0.95))


func _mark_color(col: Color, current: bool) -> Color:
	return col if current else Color(col.r, col.g, col.b, MARK_OTHER_ALPHA)


## A批8 修正: 单层图(无 layers → 仅 1F 纹理)恒视为当前层。室外土丘/坡地的高差
## (如 map2 丘顶 y_m=2.6)会被 floor_at_y 判为 2F, 而 _floor 因 146 行的
## _floor_texes.has(f) 门禁恒为 1 → 丘顶目标会被误当"其他楼层"画成半透明小图,
## 恰是最该醒目的信标旁三阶组件。口径与楼层角标一致(size()>1 才是多层图)。
func _is_current_floor(f: int) -> bool:
	return true if _floor_texes.size() <= 1 else f == _floor


## A批8: 目标标记清单(供测试断言) → [{"key", "floor", "cell"}];
## 电闸 key 为 "breaker"。仅统计当前已生成实体, 拾取后自然缺位。
func target_marks() -> Array:
	var out: Array = []
	if _entities != null:
		for c in _entities.get_children():
			if not is_instance_valid(c) or not ("symbol" in c):
				continue
			var sym := str(c.get("symbol"))
			if not MARK_COLORS.has(sym):
				continue
			var gp: Vector3 = c.global_position
			out.append({
				"key": sym,
				"floor": WorldConst.floor_at_y(gp.y),
				"cell": Vector2i(int(gp.x / WorldConst.CELL), int(gp.z / WorldConst.CELL)),
			})
	if _level != null and _level.has_gate():
		for entry in _level.get_gate_marks():
			var d: Dictionary = entry
			out.append({"key": "breaker", "floor": int(d.get("floor", 1)),
				"cell": d.get("cell", Vector2i.ZERO)})
	return out
