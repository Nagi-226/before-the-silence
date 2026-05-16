#!/bin/bash
# PreToolUse hook: 验证 git push 命令
# 对受保护分支 push 发出警告
# Exit 0 = 允许, Exit 2 = 阻止

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

if ! echo "$COMMAND" | grep -qE '^git[[:space:]]+push'; then
    exit 0
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
MATCHED_BRANCH=""

for branch in main master; do
    if [ "$CURRENT_BRANCH" = "$branch" ]; then
        MATCHED_BRANCH="$branch"
        break
    fi
    if echo "$COMMAND" | grep -qE "[[:space:]]${branch}([[:space:]]|$)"; then
        MATCHED_BRANCH="$branch"
        break
    fi
done

if [ -n "$MATCHED_BRANCH" ]; then
    echo "Push to protected branch '$MATCHED_BRANCH' detected." >&2
    echo "Reminder: Ensure build passes, unit tests pass, and no S1/S2 bugs exist." >&2
fi

exit 0
