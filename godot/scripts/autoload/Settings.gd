extends Node
## Settings (autoload) — 玩家设置持久化（user://settings.json）
## 音量经 AudioServer 生效，灵敏度由 Player 实时读取，全屏即时切换

signal settings_changed

const PATH := "user://settings.json"

var master_volume := 1.0
var sfx_volume := 1.0
var sensitivity := 1.0
var fullscreen := false


func _ready() -> void:
	_load()
	apply()


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
	master_volume = clampf(float(d.get("masterVolume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfxVolume", 1.0)), 0.0, 1.0)
	sensitivity = clampf(float(d.get("sensitivity", 1.0)), 0.5, 2.0)
	fullscreen = bool(d.get("fullscreen", false))


func save() -> void:
	var d := {
		"masterVolume": master_volume,
		"sfxVolume": sfx_volume,
		"sensitivity": sensitivity,
		"fullscreen": fullscreen,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))
		f.close()


func apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
		linear_to_db(master_volume))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))
	# 只在全屏状态需要切换时动窗口模式：音量滑条拖动也会走 apply()，
	# 无条件 window_set_mode(WINDOWED) 会把用户手动最大化的窗口打回窗口态
	var cur := DisplayServer.window_get_mode()
	if fullscreen:
		if cur != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif cur == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	apply()
	save()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply()
	save()


func set_sensitivity(v: float) -> void:
	sensitivity = clampf(v, 0.5, 2.0)
	save()
	settings_changed.emit()


func set_fullscreen(v: bool) -> void:
	fullscreen = v
	apply()
	save()
