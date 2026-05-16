#!/bin/bash
# SessionStart hook: 会话开始时加载项目上下文
# 适配自 CCGS session-start.sh，针对 C++ SDL2 项目定制

echo "=== Retro FPS v0.2.0-dev — 会话上下文 ==="

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$BRANCH" ]; then
    echo "分支: $BRANCH"
    echo ""
    echo "最近提交:"
    git log --oneline -5 2>/dev/null | while read -r line; do
        echo "  $line"
    done
fi

# 活跃实现计划（显式路径，避免 glob 脆弱性）
if [ -f "docs/superpowers/plans/2026-05-13-retro-fps-v2-implementation.md" ]; then
    echo ""
    echo "活跃计划: 2026-05-13-retro-fps-v2-implementation"
fi

# 代码健康
if [ -d "src" ]; then
    TODO_COUNT=$(grep -r "TODO" src/ 2>/dev/null | wc -l)
    FIXME_COUNT=$(grep -r "FIXME" src/ 2>/dev/null | wc -l)
    if [ "$TODO_COUNT" -gt 0 ] || [ "$FIXME_COUNT" -gt 0 ]; then
        echo ""
        echo "代码健康: ${TODO_COUNT} TODOs, ${FIXME_COUNT} FIXMEs"
    fi
fi

echo "当前阶段: v0.2.0 → v0.2.1（Engine + Framework 层实现）"
echo "详细路线图: PROJECT.md §9"
echo "==================================="
exit 0
