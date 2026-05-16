#pragma once

struct Mix_Chunk;

/// SDL2_mixer 音频封装。
/// 通道分配:
///   0-7   SFX（武器/敌人/拾取）
///   8-15  环境音效
///   16-23  音乐
///   24-31  UI 音效
class Audio
{
public:
    /// 初始化 SDL_mixer
    /// @return 是否初始化成功
    static bool init();
    /// 关闭 SDL_mixer 并释放所有音效
    static void shutdown();

    // —— 音效播放 ——
    /// 播放一次性音效
    /// @param chunk 音效数据
    /// @param channel 指定通道（-1 为自动分配）
    /// @param volume 音量 [0.0, 1.0]
    /// @return 分配的通道号，-1 表示失败
    static int playSFX(Mix_Chunk* chunk, int channel = -1, float volume = 1.0f);

    /// 播放循环音效（环境音等）
    /// @return 分配的通道号，-1 表示失败
    static int playLoop(Mix_Chunk* chunk, int channel, float volume = 1.0f);

    /// 停止指定通道
    static void stopChannel(int channel);

    /// 淡出指定通道
    /// @param ms 淡出时间（毫秒）
    static void fadeOutChannel(int channel, int ms = 500);

    // —— 音量控制 ——
    /// 设置指定通道音量 [0.0, 1.0]
    static void setChannelVolume(int channel, float volume);
    /// 设置全局音量 [0.0, 1.0]
    static void setMasterVolume(float volume);

    /// 获取可用通道数
    static int getMaxChannels() { return MAX_CHANNELS; }

private:
    static constexpr int MAX_CHANNELS = 32;
    static constexpr int FREQUENCY = 44100;
    static bool s_initialized;
};
