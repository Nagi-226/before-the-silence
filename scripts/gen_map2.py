W, H = 168, 68

grid = [['S' for _ in range(W)] for _ in range(H)]

def is_wall(c):
    return c in 'XMSG'

# Border
for x in range(W):
    grid[0][x] = 'M'; grid[H-1][x] = 'M'
for y in range(1, H-1):
    grid[y][0] = 'M'; grid[y][W-1] = 'M'

# ============================================
# 1. Continuous wavy main corridor from START to FINISH
# ============================================
# Define waypoints for main path
waypoints = [
    (3, 10),     # START
    (20, 10),    # go right
    (30, 14),    # curve down
    (40, 18),
    (50, 20),
    (55, 24),    # down more
    (60, 30),
    (70, 32),
    (80, 30),
    (85, 26),    # go up
    (90, 22),
    (100, 20),
    (110, 22),   # down again
    (120, 28),
    (130, 32),
    (140, 36),   # down more
    (150, 42),
    (158, 46),   # FINISH
]

# Carve corridor along waypoints (width 5 for more open space)
for i in range(len(waypoints)-1):
    x1, y1 = waypoints[i]
    x2, y2 = waypoints[i+1]
    steps = max(abs(x2-x1), abs(y2-y1))
    if steps == 0:
        steps = 1
    for t in range(steps+1):
        frac = t / steps
        cx = int(x1 + (x2-x1)*frac + 0.5)
        cy = int(y1 + (y2-y1)*frac + 0.5)
        # Carve 5-wide corridor
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                nx, ny = cx+dx, cy+dy
                if 0 < ny < H-1 and 0 < nx < W-1:
                    grid[ny][nx] = ' '

# Place start and finish (done after re-carve below)

# ============================================
# 2. Add rooms branching off the main path
# ============================================
rooms = [
    # (center_x, center_y, width, height, wall_mat)
    # Top-left rooms
    (15, 5, 12, 10, 'M'),      # Armory
    (42, 8, 16, 12, 'S'),     # Lab 1 (wider)
    (72, 6, 14, 10, 'M'),      # Storage
    (102, 8, 14, 10, 'S'),     # Quarters
    (128, 6, 16, 12, 'M'),    # Security (wider)
    (148, 10, 10, 8, 'S'),     # Antechamber top
    # Bottom rooms
    (25, 42, 12, 10, 'S'),     # Water treatment
    (55, 50, 16, 12, 'M'),    # Deep storage (wider)
    (80, 38, 18, 14, 'M'),    # Central reactor (wider)
    (112, 42, 14, 10, 'S'),   # Data center
    (138, 50, 16, 14, 'M'),   # Boss arena (wider)
    (155, 40, 12, 10, 'S'),    # Exit prep
]

for (cx, cy, rw, rh, wm) in rooms:
    rx = cx - rw//2
    ry = cy - rh//2
    # Interior
    for x in range(rx+1, rx+rw-1):
        for y in range(ry+1, ry+rh-1):
            if 0 < y < H-1 and 0 < x < W-1:
                grid[y][x] = ' '
    # Walls
    for x in range(rx, rx+rw):
        if 0 < ry < H-1:
            grid[ry][x] = wm
        if 0 < ry+rh-1 < H-1:
            grid[ry+rh-1][x] = wm
    for y in range(ry, ry+rh):
        if 0 < rx < W-1:
            grid[y][rx] = wm
        if 0 < rx+rw-1 < W-1:
            grid[y][rx+rw-1] = wm
    # Doorway on side closest to main path
    # Bottom door
    door_y = ry+rh-1
    door_x = cx
    if 0 < door_y < H-1 and 0 < door_x < W-1:
        grid[door_y][door_x] = ' '
        grid[door_y][door_x-1] = ' '
        grid[door_y][door_x+1] = ' '

# Re-carve main corridor (width 5)
for i in range(len(waypoints)-1):
    x1, y1 = waypoints[i]
    x2, y2 = waypoints[i+1]
    steps = max(abs(x2-x1), abs(y2-y1))
    if steps == 0:
        steps = 1
    for t in range(steps+1):
        frac = t / steps
        cx = int(x1 + (x2-x1)*frac + 0.5)
        cy = int(y1 + (y2-y1)*frac + 0.5)
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                nx, ny = cx+dx, cy+dy
                if 0 < ny < H-1 and 0 < nx < W-1:
                    grid[ny][nx] = ' '

# ============================================
# 3. Columns in larger rooms
# ============================================
for (cx, cy, rw, rh, wm) in rooms:
    if rw >= 10 and rh >= 6:
        rx = cx - rw//2
        ry = cy - rh//2
        for col_y in range(ry+2, ry+rh-2, 3):
            for col_x in range(rx+2, rx+rw-2, 5):
                if grid[col_y][col_x] == ' ' and abs(col_x - cx) > 2:
                    grid[col_y][col_x] = 'M'

# Re-open doorways (may have been covered by columns)
for (cx, cy, rw, rh, wm) in rooms:
    rx = cx - rw//2
    ry = cy - rh//2
    door_y = ry+rh-1
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            ny, nx = door_y+dy, cx+dx
            if 0 < ny < H-1 and 0 < nx < W-1 and not is_wall(grid[ny][nx]):
                grid[ny][nx] = ' '

# ============================================
# 4. Place START and FINISH (after all carving is done)
# ============================================
grid[10][3] = 'P'
grid[10][2] = ' '
grid[10][4] = ' '

grid[46][158] = 'F'
grid[46][157] = ' '
grid[46][159] = ' '
grid[45][158] = ' '
grid[47][158] = ' '

# ============================================
# 5. Enemies (placed in rooms and near path)
# ============================================
enemies = [
    # Entry area
    (8, 8, '0'), (8, 14, '0'), (6, 10, '0'), (9, 18, '0'),
    # Lab 1
    (6, 36, '1'), (4, 42, '1'), (7, 46, '0'), (8, 40, '0'), (5, 50, '1'),
    # Storage
    (5, 66, '0'), (4, 72, '1'), (7, 74, '0'), (6, 68, '0'),
    # Quarters
    (6, 98, '0'), (7, 102, '1'), (9, 100, '0'), (5, 106, '0'),
    # Security
    (5, 126, '1'), (4, 130, '2'), (7, 128, '1'), (8, 132, '0'), (6, 124, '1'),
    # Antechamber top
    (8, 148, '0'), (9, 152, '0'),
    # Water treatment
    (38, 18, '0'), (40, 22, '1'), (38, 28, '0'), (40, 32, '0'),
    # Deep storage
    (48, 50, '1'), (50, 54, '2'), (52, 58, '0'), (48, 60, '1'), (52, 52, '0'),
    # Central reactor
    (34, 72, '2'), (36, 80, '1'), (38, 76, '1'), (35, 84, '1'),
    (37, 78, '1'), (39, 82, '0'), (36, 86, '0'),
    # Data center
    (38, 106, '1'), (40, 112, '2'), (42, 108, '1'), (39, 116, '0'), (41, 104, '1'),
    # Boss arena
    (48, 136, '2'), (50, 140, '2'), (52, 138, '1'), (49, 142, '1'),
    (51, 134, '1'), (47, 138, '1'), (50, 144, '1'), (53, 140, '0'),
    # Exit prep
    (38, 150, '1'), (36, 156, '0'), (40, 154, '0'), (38, 152, '1'),
    # Near finish
    (44, 148, '2'), (46, 152, '1'), (44, 154, '0'), (48, 156, '1'),
    # Corridor enemies (placed along main path)
    (10, 25, '0'), (10, 55, '0'), (10, 90, '0'), (10, 115, '0'),
    (27, 30, '1'), (27, 65, '1'), (27, 95, '1'), (27, 120, '1'),
    (30, 50, '0'), (30, 75, '0'), (30, 110, '0'), (30, 140, '0'),
    (43, 40, '1'), (43, 70, '1'), (43, 100, '1'), (43, 130, '1'),
]

for (ey, ex, typ) in enemies:
    if 0 < ey < H-1 and 0 < ex < W-1:
        if grid[ey][ex] == ' ':
            grid[ey][ex] = typ

# ============================================
# 6. Pickups
# ============================================
pickups = [
    # Health
    (7, 12, 'H'), (9, 22, 'H'), (5, 30, 'H'),
    (8, 44, 'H'), (6, 52, 'H'), (9, 56, 'H'),
    (6, 64, 'H'), (8, 70, 'H'), (5, 76, 'H'),
    (8, 96, 'H'), (6, 104, 'H'), (9, 108, 'H'),
    (6, 122, 'H'), (8, 134, 'H'), (7, 140, 'H'),
    (8, 150, 'H'),
    (30, 20, 'H'), (32, 26, 'H'), (34, 34, 'H'),
    (36, 44, 'H'), (40, 52, 'H'), (38, 56, 'H'),
    (48, 48, 'H'), (50, 56, 'H'), (52, 62, 'H'),
    (34, 70, 'H'), (36, 88, 'H'), (38, 90, 'H'),
    (40, 110, 'H'), (42, 120, 'H'), (38, 130, 'H'),
    (50, 132, 'H'), (52, 146, 'H'), (48, 144, 'H'),
    (38, 148, 'H'), (40, 158, 'H'),
    (44, 150, 'H'), (46, 154, 'H'),
    (12, 30, 'H'), (12, 60, 'H'), (12, 90, 'H'), (12, 120, 'H'),
    (28, 40, 'H'), (28, 80, 'H'), (28, 115, 'H'),
    (32, 60, 'H'), (32, 100, 'H'),
    (44, 50, 'H'), (44, 100, 'H'), (44, 140, 'H'),
    # Ammo
    (8, 16, 'A'), (6, 28, 'A'), (9, 34, 'A'),
    (7, 48, 'A'), (5, 54, 'A'), (10, 58, 'A'),
    (7, 78, 'A'), (5, 82, 'A'), (8, 88, 'A'),
    (7, 110, 'A'), (9, 114, 'A'), (5, 120, 'A'),
    (9, 136, 'A'), (7, 144, 'A'), (6, 154, 'A'),
    (31, 22, 'A'), (33, 28, 'A'), (35, 36, 'A'),
    (37, 46, 'A'), (41, 50, 'A'), (39, 54, 'A'),
    (49, 50, 'A'), (51, 54, 'A'), (53, 60, 'A'),
    (35, 72, 'A'), (37, 86, 'A'), (39, 88, 'A'),
    (41, 108, 'A'), (43, 118, 'A'), (39, 128, 'A'),
    (49, 130, 'A'), (51, 138, 'A'), (47, 142, 'A'),
    (37, 150, 'A'), (39, 156, 'A'),
    (43, 148, 'A'), (47, 158, 'A'),
    (10, 35, 'A'), (10, 70, 'A'), (10, 105, 'A'), (10, 130, 'A'),
    (26, 50, 'A'), (26, 85, 'A'), (26, 125, 'A'),
    (33, 50, 'A'), (33, 90, 'A'),
    (42, 55, 'A'), (42, 95, 'A'), (42, 135, 'A'),
    # Coins
    (6, 12, 'C'), (3, 26, 'C'), (8, 40, 'C'),
    (4, 60, 'C'), (7, 80, 'C'), (5, 100, 'C'),
    (9, 118, 'C'), (8, 146, 'C'), (7, 24, 'C'),
    (6, 72, 'C'), (5, 90, 'C'), (4, 112, 'C'),
    (3, 138, 'C'), (9, 160, 'C'),
    (31, 18, 'C'), (33, 30, 'C'), (36, 48, 'C'),
    (40, 58, 'C'), (37, 70, 'C'), (35, 92, 'C'),
    (41, 116, 'C'), (39, 126, 'C'), (37, 140, 'C'),
    (50, 48, 'C'), (53, 58, 'C'), (45, 70, 'C'),
    (49, 92, 'C'), (43, 118, 'C'), (51, 136, 'C'),
    (47, 148, 'C'), (43, 156, 'C'), (45, 158, 'C'),
    (11, 45, 'C'), (11, 75, 'C'), (11, 100, 'C'), (11, 140, 'C'),
    (25, 35, 'C'), (25, 70, 'C'), (25, 105, 'C'), (25, 135, 'C'),
    (34, 38, 'C'), (34, 65, 'C'), (34, 105, 'C'),
    (41, 40, 'C'), (41, 75, 'C'), (41, 120, 'C'),
    # Upgrades
    (6, 46, 'h'), (34, 62, 'a'), (49, 140, 'w'),
    (42, 124, 'h'), (37, 150, 'a'), (30, 90, 'w'),
]

for (py, px, typ) in pickups:
    if 0 < py < H-1 and 0 < px < W-1:
        if grid[py][px] == ' ':
            grid[py][px] = typ

# Fill remaining pickups by scanning open cells
import random
random.seed(42)

pickup_types = (
    ['H'] * 20 + ['A'] * 18 + ['C'] * 25 +
    ['h'] * 3 + ['a'] * 3 + ['w'] * 2
)

open_cells = [(y, x) for y in range(1, H-1) for x in range(1, W-1)
              if grid[y][x] == ' ']

random.shuffle(open_cells)
for i, (y, x) in enumerate(open_cells):
    if i >= len(pickup_types):
        break
    grid[y][x] = pickup_types[i]

# ============================================
# 7. Add grate windows (decorative solid walls)
# ============================================
for (cx, cy, rw, rh, wm) in rooms:
    rx = cx - rw//2
    ry = cy - rh//2
    if rw >= 8:
        grid[ry+1][cx] = 'G'
        grid[ry+rh-2][cx] = 'G'

# ============================================
# 8. BFS check
# ============================================
from collections import deque

sx, sy = 3, 10  # Start
fx, fy = 158, 46  # Finish

visited = [[False]*W for _ in range(H)]
q = deque([(sx, sy)])
visited[sy][sx] = True

while q:
    cx, cy = q.popleft()
    for dx, dy in [(1,0),(-1,0),(0,1),(0,-1)]:
        nx, ny = cx+dx, cy+dy
        if 0 <= nx < W and 0 <= ny < H and not visited[ny][nx] and not is_wall(grid[ny][nx]):
            visited[ny][nx] = True
            q.append((nx, ny))

enemy_count = sum(1 for y in range(H) for x in range(W) if grid[y][x] in '012')
pickup_count = sum(1 for y in range(H) for x in range(W) if grid[y][x] in 'HCAhaw')

# Output
for y in range(H):
    line = ''.join(grid[y])
    assert len(line) == W, f"Row {y}: {len(line)} != {W}"
    print(line)

if not visited[fy][fx]:
    max_reach = max(x for y in range(H) for x in range(W) if visited[y][x])
    raise SystemExit(f"ERROR: FINISH unreachable (max X={max_reach}). Enemies={enemy_count}, Pickups={pickup_count}")

print(f"# OK: {enemy_count} enemies, {pickup_count} pickups", file=__import__('sys').stderr)
