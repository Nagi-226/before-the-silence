#include "math/MathAddon.h"
#include <cmath>

float MathAddon::angleRadToDeg(float rad) {
    return rad * RAD_TO_DEG;
}

float MathAddon::angleDegToRad(float deg) {
    return deg * DEG_TO_RAD;
}

float MathAddon::lerp(float a, float b, float t) {
    return a + (b - a) * t;
}

float MathAddon::clamp(float value, float min, float max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

bool MathAddon::decayTimer(float& timer, float dT) {
    if (timer <= 0.0f) {
        timer = 0.0f;
        return true;
    }
    timer -= dT;
    if (timer < 0.0f) timer = 0.0f;
    return timer <= 0.0f;
}

float MathAddon::wrapAngleRad(float rad) {
    rad = std::fmod(rad, PI2);
    if (rad > PI)  rad -= PI2;
    if (rad < -PI) rad += PI2;
    return rad;
}
