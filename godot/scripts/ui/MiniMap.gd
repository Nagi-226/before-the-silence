extends Control
class_name MiniMap
## MiniMap — HUD 右上角俯视小地图（数据驱动，零额外渲染开销）
## 墙体由 LevelGenerator.wall_cells 一次性预渲染为 ImageTexture；
## 每帧仅叠加玩家箭头 / 敌人红点 / 信标绿点。1 地图格 = 1 纹理像素。

const SCALE := 1.25  # 纹理像素 → 屏幕像素
const MARGIN := 12.0  # 距屏幕右上角间距
const COLOR_BG := Color(0.01, 0.02, 0.03, 0.55)
const COLOR_BORDER := Color(0.35, 0.55, 0.6, 0.8)
const COLOR_WALL := Color(0.55, 0.7, 0.75, 0.95)
const COLOR_PLAYER := Color(1.0, 0.92, 0.25)  # 亮黄，与墙体青色区分
const COLOR_ENEMY := Color(1.0, 0.3, 0.25)
const COLOR_FLAG := Color(0.35, 1.0, 0.45)

var _wall_tex: ImageTexture
var _map_size := Vector2.ZERO
var _player: Node3D
var _entities: Node3D
var _ready_flag := false


## 由 Main 在 level.build 之后调用
func setup(level: Node, player: Node3D, entities: Node3D) -> void:
	_player = player
	_entities = entities
	var w: int = LevelData.WIDTH
	var h: int = LevelData.HEIGHT
	# 符号地图实际行数可能超出 HEIGHT 常量（自动生成数据的尾行），按实际墙格取界
	for cell: Vector2i in level.wall_cells:
		w = maxi(w, cell.x + 1)
		h = maxi(h, cell.y + 1)
	_map_size = Vector2(w, h)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for cell: Vector2i in level.wall_cells:
		img.set_pixelv(cell, COLOR_WALL)
	_wall_tex = ImageTexture.create_from_image(img)
	# CanvasLayer 直接子节点的锚点不会相对视口解析，显式按视口尺寸定位
	size = _map_size * SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_reposition()
	get_tree().root.size_changed.connect(_reposition)
	_ready_flag = true


func _reposition() -> void:
	var vp := get_viewport().get_visible_rect().size
	position = Vector2(vp.x - _map_size.x * SCALE - MARGIN, MARGIN)


func _process(_delta: float) -> void:
	if _ready_flag:
		queue_redraw()


func _map_px(world_pos: Vector3) -> Vector2:
	return Vector2(world_pos.x / WorldConst.CELL, world_pos.z / WorldConst.CELL) * SCALE


func _draw() -> void:
	if not _ready_flag:
		return
	# 底板与边框
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER, false, 1.0)
	draw_texture_rect(_wall_tex, Rect2(Vector2.ZERO, size), false)

	# 敌人红点（跳过已释放/濒死无效节点）
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			draw_circle(_map_px(e.global_position), 1.6, COLOR_ENEMY)

	# 撤离信标绿点
	for c in _entities.get_children():
		if is_instance_valid(c) and c.has_signal("reached"):
			draw_circle(_map_px(c.global_position), 2.2, COLOR_FLAG)

	# 玩家箭头（朝向 = 相机前方 -Z 投影到地图平面）
	if is_instance_valid(_player):
		var p := _map_px(_player.global_position)
		var rot: float = _player.rotation.y
		var fwd := Vector2(-sin(rot), -cos(rot))
		var side := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([
			p + fwd * 5.0,
			p - fwd * 3.4 + side * 3.0,
			p - fwd * 3.4 - side * 3.0,
		]), COLOR_PLAYER)
