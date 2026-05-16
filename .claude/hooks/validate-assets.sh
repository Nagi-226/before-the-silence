#!/bin/bash
# PostToolUse hook: 验证 assets/ 目录下的文件
# 检查命名规范和 JSON 合法性
# Exit 0 = 通过/建议, Exit 1 = 阻断

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
    FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')

if ! echo "$FILE_PATH" | grep -qE '(^|/)assets/'; then
    exit 0
fi

FILENAME=$(basename "$FILE_PATH")
WARNINGS=""
ERRORS=""

# 命名规范：小写+下划线
if echo "$FILENAME" | grep -qE '[A-Z[:space:]-]'; then
    WARNINGS="$WARNINGS\n  NAMING: $FILE_PATH should be lowercase_with_underscores (got: $FILENAME)"
fi

# JSON 合法性检查
if echo "$FILE_PATH" | grep -qE '(^|/)assets/data/.*\.json$'; then
    if [ -f "$FILE_PATH" ]; then
        PYTHON_CMD=""
        for cmd in python python3 py; do
            if command -v "$cmd" >/dev/null 2>&1; then
                PYTHON_CMD="$cmd"
                break
            fi
        done
        if [ -n "$PYTHON_CMD" ]; then
            if ! "$PYTHON_CMD" -m json.tool "$FILE_PATH" > /dev/null 2>&1; then
                ERRORS="$ERRORS\n  FORMAT: $FILE_PATH is not valid JSON"
            fi
        fi
    fi
fi

if [ -n "$WARNINGS" ]; then
    echo -e "=== Asset Validation Warnings ===$WARNINGS\n==================================" >&2
fi

if [ -n "$ERRORS" ]; then
    echo -e "=== Asset Validation ERRORS (Blocking) ===$ERRORS\n==========================================" >&2
    exit 1
fi

exit 0
