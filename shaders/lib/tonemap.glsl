// =====================================================================
// Aurora Shaders - tonemap.glsl
// Tone mapping, color grading, exposure adaptation.
// sRGBToLinear/linearToSRGB have been MOVED to common.glsl since they
// are needed by every gbuffers stage that does not include this file.
// =====================================================================
#ifndef AURORA_TONEMAP_GLSL
#define AURORA_TONEMAP_GLSL

#include "common.glsl"

// ---------------------------------------------------------------------
// ACES Filmic tonemap (Narkowicz approximation - very cheap)
// ---------------------------------------------------------------------
vec3 acesTonemap(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp01((x * (a * x + b)) / (x * (c * x + d) + e));
}

// ---------------------------------------------------------------------
// Improved ACES (Stephen Hill) - more accurate, still cheap
// ---------------------------------------------------------------------
vec3 acesTonemapHill(vec3 x) {
    mat3 m1 = mat3(
        0.59719, 0.07600, 0.02840,
        0.35458, 0.90834, 0.13383,
        0.04823, 0.01566, 0.83777
    );
    mat3 m2 = mat3(
        1.60475, -0.10208, -0.00327,
        -0.53108,  1.10813, -0.07276,
        -0.07367, -0.00605,  1.07602
    );
    vec3 v = m1 * x;
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return clamp01(m2 * (a / b));
}

// ---------------------------------------------------------------------
// Reinhard (cheap fallback for emissive blocks)
// ---------------------------------------------------------------------
vec3 reinhardTonemap(vec3 x) {
    return x / (1.0 + x);
}

// ---------------------------------------------------------------------
// Color grading: saturation, contrast, brightness
// ---------------------------------------------------------------------
vec3 colorGrade(vec3 color, float saturation, float contrast, float brightness) {
    float l = luminance(color);
    color = mix(vec3(l), color, saturation);
    color = (color - 0.5) * contrast + 0.5;
    color *= brightness;
    return color;
}

// ---------------------------------------------------------------------
// Eye-adapted exposure.
// Reads previous frame's adapted exposure and lerps toward the target
// for the current frame. Speed is controlled by EXPOSURE_ADAPT_SPEED.
// ---------------------------------------------------------------------
float computeAdaptedExposure(float sceneLuminance, float previousExposure, float dt) {
    float targetExposure = 1.0 / (sceneLuminance + 1.0);
    targetExposure = clamp(targetExposure, 0.05, 4.0);
    float speed = EXPOSURE_ADAPT_SPEED;
    return mix(previousExposure, targetExposure, clamp01(dt * speed));
}

// ---------------------------------------------------------------------
// Vignette - subtle, only at frame corners
// ---------------------------------------------------------------------
vec3 applyVignette(vec3 color, vec2 uv) {
    vec2 p = uv - 0.5;
    float d = dot(p, p);
    return color * (1.0 - d * 0.32);
}

#endif // AURORA_TONEMAP_GLSL
