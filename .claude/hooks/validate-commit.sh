#!/bin/bash
# PreToolUse hook: 验证 git commit 命令
# 适配自 CCGS validate-commit.sh，针对 Windows C++ SDL2 项目
# Exit 0 = 允许, Exit 2 = 阻止

INPUT=$(cat)

# 解析命令 — 优先 jq，次选 PowerShell（Windows 更可靠），最后 sed fallback
if command -v jq >/dev/null 2>&1; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
elif command -v powershell >/dev/null 2>&1; then
    COMMAND=$(echo "$INPUT" | powershell -NoProfile -Command "
        try {
            (\$input | ConvertFrom-Json).tool_input.command
        } catch { '' }
    " 2>/dev/null)
else
    COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

if ! echo "$COMMAND" | grep -qE '^git[[:space:]]+commit'; then
    exit 0
fi

STAGED=$(git diff --cached --name-only 2>/dev/null)
if [ -z "$STAGED" ]; then
    exit 0
fi

WARNINGS=""

# 引擎层不应引用游戏层（阻断级错误）
ENGINE_FILES=$(echo "$STAGED" | grep -E '^src/engine/.*\.(h|cpp)$')
if [ -n "$ENGINE_FILES" ]; then
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if grep -nE '#include.*game/' "$file" 2>/dev/null; then
                echo "BLOCKED: $file 引擎层代码不应引用游戏层 (engine ← game 依赖方向违反)" >&2
                exit 2
            fi
        fi
    done <<< "$ENGINE_FILES"
fi

# 游戏层硬编码数值（警告级）
GAME_FILES=$(echo "$STAGED" | grep -E '^src/game/.*\.(h|cpp)$')
if [ -n "$GAME_FILES" ]; then
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            PATTERNS=$(grep -nE '(damage|health|speed|rate|chance|cost|cooldown|range|spread)[[:space:]]*=[[:space:]]*[0-9]+' "$file" 2>/dev/null)
            if [ -n "$PATTERNS" ]; then
                WARNINGS="$WARNINGS\nGAMEPLAY: $file 可能含硬编码游戏数值。应从模板/配置数据加载。\n$PATTERNS"
            fi
        fi
    done <<< "$GAME_FILES"
fi

# TODO/FIXME 无归属者
SRC_FILES=$(echo "$STAGED" | grep -E '^src/')
if [ -n "$SRC_FILES" ]; then
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            BARE_TODOS=$(grep -nE '//[[:space:]]*(TODO|FIXME|HACK)[[:space:]]*$' "$file" 2>/dev/null)
            if [ -n "$BARE_TODOS" ]; then
                WARNINGS="$WARNINGS\nSTYLE: $file 有 TODO/FIXME 无归属者。使用 // TODO(name): 格式。\n$BARE_TODOS"
            fi
        fi
    done <<< "$SRC_FILES"
fi

if [ -n "$WARNINGS" ]; then
    echo -e "=== 提交验证警告 ===$WARNINGS\n====================" >&2
fi

exit 0
