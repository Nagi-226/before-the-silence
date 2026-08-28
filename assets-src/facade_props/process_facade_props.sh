#!/usr/bin/env bash
# process_facade_props.sh — 阶段一素材处理管线（可复现）
# 源: 本目录 6 张 1024x1024 AI 原稿(右下角带 "Qoder AI 生成" 水印)
# 工具: ffmpeg (nearest 缩放保硬边像素风)
#
# 坑记录:
# - 背景是轻微渐变的品红(非纯 #FF00FF), 逐图采角点像素均值定抠像色
# - drawbox 先盖掉右下角水印再 colorkey, 否则白色水印字残留
# - colorkey similarity 0.12 留品红残边, 0.22 干净且不咬精灵本体
# - 1024->128 为整数比(8x), nearest 下像素网格对齐

set -e
cd "$(dirname "$0")"
OUT="../../godot/assets"

# --- 外立面贴图 (24bit BMP, 与现有墙贴图同规格) ---
# 面板: 裁掉水印角(纹理均匀, 裁切无碍) 16x 缩至 64x64
ffmpeg -v error -y -i facade_panel_raw_1787922164.png \
  -vf "crop=960:960:0:0,scale=64:64:flags=neighbor" -pix_fmt bgr24 \
  "$OUT/images/Facade Panel.bmp"

# 窗户带: 上 2/3 = 二/三层窗排(底层大门排裁掉, 首层保留实墙),
# 补水印后 8x 缩至 128x85
ffmpeg -v error -y -i facade_windows_raw_1787922176.png \
  -vf "drawbox=x=780:y=910:w=244:h=114:color=0x28333B:t=fill,crop=1024:680:0:0,scale=128:85:flags=neighbor" \
  -pix_fmt bgr24 "$OUT/images/Facade Windows.bmp"

# --- 庭院道具 (128x128 透明 PNG, colorkey 抠品红) ---
key() { # $1=源 $2=目标 $3=背景均值色
  ffmpeg -v error -y -i "$1" \
    -vf "drawbox=x=780:y=900:w=244:h=124:color=$3:t=fill,colorkey=$3:0.22:0,scale=128:128:flags=neighbor" \
    "$2"
}
key prop_rubble_raw_1787922192.png     "$OUT/sprites/Prop Rubble.png"     0xD40DAB
key prop_crate_raw_1787922205.png      "$OUT/sprites/Prop Crate.png"      0xED1EA3
key prop_streetlamp_raw_1787922219.png "$OUT/sprites/Prop Streetlamp.png" 0xEB48BC
key prop_deadtree_raw_1787922232.png   "$OUT/sprites/Prop Deadtree.png"   0xC53985

echo "done"
