#pragma once
#include <chrono>

/// 固定时间步长游戏主循环。
/// 与帧率解耦：逻辑以固定 dT 运行，渲染尽量多帧。
class GameLoop
{
public:
    static constexpr float FIXED_DT = 1.0f / 60.0f;  // 60 Hz 逻辑更新
    static constexpr float MAX_FRAME_TIME = 0.25f;    // 最大单帧时间（防止螺旋）

    /// 运行游戏循环
    /// @param updateFn 每固定帧调用的逻辑更新函数
    /// @param renderFn 每帧调用的渲染函数
    /// @param shouldQuitFn 是否退出的查询函数
    template<typename UpdateFn, typename RenderFn, typename QuitFn>
    static void run(UpdateFn updateFn, RenderFn renderFn, QuitFn shouldQuitFn) {
        auto previousTime = std::chrono::high_resolution_clock::now();
        float accumulator = 0.0f;

        while (!shouldQuitFn()) {
            auto currentTime = std::chrono::high_resolution_clock::now();
            float frameTime = std::chrono::duration<float>(currentTime - previousTime).count();
            previousTime = currentTime;

            // 防止螺旋
            if (frameTime > MAX_FRAME_TIME) {
                frameTime = MAX_FRAME_TIME;
            }

            accumulator += frameTime;

            // 固定步长更新
            while (accumulator >= FIXED_DT) {
                updateFn(FIXED_DT);
                accumulator -= FIXED_DT;
            }

            renderFn();
        }
    }
};
