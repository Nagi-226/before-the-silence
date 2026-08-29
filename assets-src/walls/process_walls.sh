#!/usr/bin/env bash
# process_walls.sh — 室内仓库混凝土墙贴图处理管线（可复现）
# 源: 本目录 1024x1024 AI 原稿(右下角带 "Qoder AI 生成" 水印)
# 工具: ffmpeg (nearest 缩放保硬边像素风)
#
# 坑记录(沿用 ../facade_props/process_facade_props.sh):
# - 水印集中在右下角, crop=960:960:0:0 直接裁掉
# - 1024->64 为整数比(16x), nearest 下像素网格对齐
# - 输出 24bit BMP, 与现有墙贴图同规格(64x64)
#
# 接线: LevelGenerator.gd WALL_TEXTURES "X" -> Wall Concrete.bmp
#      (map0 仓库区主墙型 4140 格; map1 地下仅零星 336 格, 混凝土同样适配)

set -e
cd "$(dirname "$0")"
OUT="../../godot/assets"

ffmpeg -v error -y -i wall_concrete_raw_1787985017.png \
  -vf "crop=960:960:0:0,scale=64:64:flags=neighbor" -pix_fmt bgr24 \
  "$OUT/images/Wall Concrete.bmp"

echo "done"
