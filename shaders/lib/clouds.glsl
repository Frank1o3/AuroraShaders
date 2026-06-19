// =====================================================================
// Aurora Shaders - clouds.glsl
// Lightweight procedural sky clouds. No texture fetches, fixed cost.
// =====================================================================
#ifndef AURORA_CLOUDS_GLSL
#define AURORA_CLOUDS_GLSL

#include "common.glsl"

float cloudHash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float cloudValueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = cloudHash(i);
    float b = cloudHash(i + vec2(1.0, 0.0));
    float c = cloudHash(i + vec2(0.0, 1.0));
    float d = cloudHash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float cloudFbm(vec2 p) {
    float n = cloudValueNoise(p) * 0.55;
    n += cloudValueNoise(p * 2.03 + 17.1) * 0.30;
    n += cloudValueNoise(p * 4.11 + 3.7) * 0.15;
    return n;
}

vec3 applyProceduralClouds(vec3 sky, vec3 viewDir) {
#if ENABLE_CLOUDS == 0
    return sky;
#else
    if (viewDir.y <= 0.02 || cloudDensity <= 0.001) return sky;

    float plane = 0.55 / max(viewDir.y, 0.04);
    vec2 wind = vec2(frameTimeCounter * cloudSpeed * 0.018, frameTimeCounter * cloudSpeed * 0.006);
    vec2 uv = viewDir.xz * plane * 0.85 + wind + cameraPosition.xz * 0.00025;

    float coverage = mix(0.78, 0.36, clamp01(cloudDensity));
    float shape = cloudFbm(uv * 3.2);
    float alpha = smoothstep(coverage, coverage + 0.20, shape);
    alpha *= smoothstep(0.02, 0.28, viewDir.y);
    alpha *= 1.0 - rainStrength * 0.35;

    vec3 sunDir = normalize(sunPosition);
    float sunLit = clamp01(dot(normalize(vec3(viewDir.x, 0.35, viewDir.z)), sunDir) * 0.5 + 0.5);
    vec3 cloudDay = mix(vec3(0.62, 0.66, 0.72), vec3(1.0, 0.96, 0.88), sunLit) * sunIntensity;
    vec3 cloudNight = vec3(0.055, 0.065, 0.09) * (0.6 + moonIntensity);
    vec3 cloudColor = mix(cloudNight, cloudDay, daylightFactor());

    return mix(sky, cloudColor, alpha * 0.72);
#endif
}

#endif // AURORA_CLOUDS_GLSL
