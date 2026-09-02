extends Control
class_name MiniMap
## MiniMap — HUD 右上角俯视小地图（数据驱动，零额外渲染开销）
## 墙体由 LevelGenerator.wall_cells 一次性预渲染为 ImageTexture；
## 每帧仅叠加玩家箭头 / 敌人红点 / 信标绿点。1 地图格 = 1 纹理像素。
## P1.5 跟随模式（level_ext.json: miniMapFollow）: 地图任一维超过跟随视窗时
## 启用窗口裁剪绘制，玩家居中、贴边钳制；实体点按视窗偏移换算，越界不绘制。
## A批6 楼层化: 按玩家脚部 y 判定当前楼层(WorldConst.floor_at_y, 与交互点同口径),
## 墙体纹理按楼层切换——1F=wall_cells(含 partitions), 2F/3F=对应层 grid 墙格;
## 无 layers 的图永远 1F 表现(向后兼容)。楼梯位置以异色点标记。

const SCALE := 1.25  # 纹理像素 → 屏幕像素
const MARGIN := 12.0  # 距屏幕右上角间距
const COLOR_BG := Color(0.01, 0.02, 0.03, 0.55)
const COLOR_BORDER := Color(0.35, 0.55, 0.6, 0.8)
const COLOR_WALL := Color(0.55, 0.7, 0.75, 0.95)
const COLOR_PLAYER := Color(1.0, 0.92, 0.25)  # 亮黄，与墙体青色区分
const COLOR_ENEMY := Color(1.0, 0.3, 0.25)
const COLOR_FLAG := Color(0.35, 1.0, 0.45)
const COLOR_STAIR := Color(1.0, 0.62, 0.2, 0.9)  # 楼梯标记橙

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

	# A批6: 当前楼层楼梯位置标记(异色点, 中心对齐格心)
	if _level != null:
		for cell: Vector2i in _level.get_stair_marks(_floor):
			var sp := _onscreen(Vector3(
				(cell.x + 0.5) * WorldConst.CELL, 0.0, (cell.y + 0.5) * WorldConst.CELL))
			if _in_view(sp):
				draw_circle(sp, 1.8, COLOR_STAIR)

	# 敌人红点（跳过已释放/濒死无效节点与视窗外）
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			var ep := _onscreen(e.global_position)
			if _in_view(ep):
				draw_circle(ep, 1.6, COLOR_ENEMY)

	# 撤离信标绿点
	for c in _entities.get_children():
		if is_instance_valid(c) and c.has_signal("reached"):
			var cp := _onscreen(c.global_position)
			if _in_view(cp):
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
