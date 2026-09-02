class_name WorldConst
## 世界尺度常量 — 地图网格 → 3D 世界的换算基准
## C++ 版中所有数值以"格"为单位，这里 1 格 = CELL 米

const CELL := 2.0            # 1 地图格 = 2 米
const WALL_HEIGHT := 2.6     # 墙高（米）
const EYE_HEIGHT := 1.3      # 玩家视线高度（米）
const FOV_DEG := 60.0        # 与 C++ 版 FOV_RAD = PI/3 一致
const PITCH_LIMIT_DEG := 30.0  # 对应 C++ look.maxOffset=30 的俯仰限制


## A批6 · 玩家脚部 y → 楼层号(1 起, 层高 WALL_HEIGHT, 上限 3 层)。
## +0.05m 容差: 站上板面时浮点抖动(5.2±ε)不会在 2/3 层间 flicker。
## 小地图楼层化与墙贴交互点共用同一口径, 两处不得各自实现。
static func floor_at_y(y: float) -> int:
	return clampi(int((y + 0.05) / WALL_HEIGHT) + 1, 1, 3)
