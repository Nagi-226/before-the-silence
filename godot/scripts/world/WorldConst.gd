class_name WorldConst
## 世界尺度常量 — 地图网格 → 3D 世界的换算基准
## C++ 版中所有数值以"格"为单位，这里 1 格 = CELL 米

const CELL := 2.0            # 1 地图格 = 2 米
const WALL_HEIGHT := 2.6     # 墙高（米）
const EYE_HEIGHT := 1.3      # 玩家视线高度（米）
const FOV_DEG := 60.0        # 与 C++ 版 FOV_RAD = PI/3 一致
const PITCH_LIMIT_DEG := 30.0  # 对应 C++ look.maxOffset=30 的俯仰限制
