#include "engine/Audio.h"
#include "SDL2/SDL_mixer.h"
#include <iostream>
#include <cmath>

bool Audio::s_initialized = false;

bool Audio::init() {
    if (s_initialized) return true;

    if (Mix_OpenAudio(FREQUENCY, MIX_DEFAULT_FORMAT, 2, 1024) < 0) {
        std::cerr << "Audio: Mix_OpenAudio failed: " << Mix_GetError() << std::endl;
        return false;
    }

    int allocated = Mix_AllocateChannels(MAX_CHANNELS);
    if (allocated < 0) {
        std::cerr << "Audio: Mix_AllocateChannels failed: " << Mix_GetError() << std::endl;
        Mix_CloseAudio();
        return false;
    }

    std::cout << "Audio: initialized (" << FREQUENCY << "Hz, "
              << allocated << " of " << MAX_CHANNELS << " channels, driver: "
              << SDL_GetCurrentAudioDriver() << ")" << std::endl;

    s_initialized = true;
    return true;
}

void Audio::shutdown() {
    if (!s_initialized) return;
    Mix_CloseAudio();
    s_initialized = false;
}

int Audio::playSFX(Mix_Chunk* chunk, int channel, float volume) {
    if (!chunk || !s_initialized) return -1;

    int ch = Mix_PlayChannel(channel, chunk, 0);
    if (ch >= 0) {
        int vol = static_cast<int>(std::round(volume * MIX_MAX_VOLUME));
        Mix_Volume(ch, vol);
    }
    return ch;
}

int Audio::playLoop(Mix_Chunk* chunk, int channel, float volume) {
    if (!chunk || !s_initialized) return -1;

    int ch = Mix_PlayChannel(channel, chunk, -1);  // -1 = infinite loop
    if (ch >= 0) {
        int vol = static_cast<int>(std::round(volume * MIX_MAX_VOLUME));
        Mix_Volume(ch, vol);
    }
    return ch;
}

void Audio::stopChannel(int channel) {
    if (!s_initialized) return;
    Mix_HaltChannel(channel);
}

void Audio::fadeOutChannel(int channel, int ms) {
    if (!s_initialized) return;
    Mix_FadeOutChannel(channel, ms);
}

void Audio::setChannelVolume(int channel, float volume) {
    if (!s_initialized) return;
    int vol = static_cast<int>(std::round(volume * MIX_MAX_VOLUME));
    Mix_Volume(channel, vol);
}

void Audio::setMasterVolume(float volume) {
    if (!s_initialized) return;
    int vol = static_cast<int>(std::round(volume * MIX_MAX_VOLUME));
    Mix_Volume(-1, vol);  // -1 = all channels
}
