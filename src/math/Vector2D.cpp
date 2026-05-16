#include "math/Vector2D.h"

Vector2D Vector2D::normalize() const {
    float m = magnitude();
    if (m > 0.0f) {
        return Vector2D(x / m, y / m);
    }
    return *this;
}
