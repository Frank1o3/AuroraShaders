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

float cloudDetail(vec2 p) {
    return cloudValueNoise(p * 8.0 + 41.0) * 0.55 + cloudValueNoise(p * 15.0 - 9.0) * 0.45;
}

vec3 applyProceduralClouds(vec3 sky, vec3 viewDir) {
#if ENABLE_CLOUDS == 0
    return sky;
#else
    vec3 upDir = normalize(upPosition);
    float upDot = dot(normalize(viewDir), upDir);
    if (upDot <= 0.02 || cloudDensity <= 0.001) return sky;

    float plane = cloudHeight / max(upDot, 0.04);
    vec2 wind = vec2(frameTimeCounter * cloudSpeed * 0.018, frameTimeCounter * cloudSpeed * 0.006);
    vec2 uv = viewDir.xz * plane * 0.85 + wind + cameraPosition.xz * 0.00025;

    float coverage = mix(0.78, 0.36, clamp01(cloudDensity));
    float base = cloudFbm(uv * 3.2);
    float detail = cloudDetail(uv * 3.2);
    float shape = base * 0.82 + detail * 0.18;
    float alpha = smoothstep(coverage, coverage + 0.18, shape);
    alpha *= 1.0 - smoothstep(coverage + 0.18, coverage + 0.42, detail) * 0.35;
    alpha *= smoothstep(0.02, 0.28, upDot);
    alpha *= 1.0 - rainStrength * 0.35;

    vec3 sunDir = normalize(sunPosition);
    float sunLit = clamp01(dot(normalize(viewDir + upDir * 0.35), sunDir) * 0.5 + 0.5);
    float silver = fastPow01(clamp01(dot(normalize(viewDir), sunDir)), 12.0);
    vec3 cloudDay = mix(vec3(0.58, 0.62, 0.68), vec3(1.0, 0.96, 0.88), sunLit) * sunIntensity;
    cloudDay += getSunLightColor() * silver * 0.35;
    vec3 cloudNight = vec3(0.055, 0.065, 0.09) * (0.6 + moonIntensity);
    vec3 cloudColor = mix(cloudNight, cloudDay, horizonDayFactor());

    return mix(sky, cloudColor, alpha * 0.72);
#endif
}

#endif // AURORA_CLOUDS_GLSL
