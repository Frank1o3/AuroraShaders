// =====================================================================
// Aurora Shaders - fog.glsl
// Atmospheric + underwater fog, cheap exponential.
// =====================================================================
#ifndef AURORA_FOG_GLSL
#define AURORA_FOG_GLSL

#include "common.glsl"

// Forward declaration: lighting.glsl defines getSkyColor, but fog.glsl
// may be included before lighting.glsl. We declare the prototype here
// and rely on the fact that all stage files include lighting.glsl
// (which provides the full definition) before calling fog functions.
vec3 getSkyColor(vec3 dir);

// Distance fog: exponential, sky-tinted
vec3 applyDistanceFog(vec3 color, vec3 viewPos, vec3 viewDir) {
    float dist = length(viewPos);
    float density = fogDensity;
    if (qualityLevel == 0 && isEyeInWater == 0) density *= 0.35;
    if (isEyeInWater == 1) density = 0.18;
    if (isEyeInWater == 2) density = 0.55; // lava

    float fogFactor = 1.0 - exp(-dist * density);
    fogFactor = clamp01(fogFactor);

    vec3 fogColor;
    if (isEyeInWater == 1) {
        fogColor = vec3(0.10, 0.30, 0.45);
    } else if (isEyeInWater == 2) {
        fogColor = vec3(0.55, 0.10, 0.05);
    } else {
        // Sky-tinted atmospheric fog
        fogColor = getSkyColor(viewDir) * 0.85;
    }

    return mix(color, fogColor, fogFactor);
}

// Subtle volumetric haze near the horizon (cheap).
// Skipped underwater — the distance fog already handles that case.
vec3 applyHorizonHaze(vec3 color, vec3 viewDir, vec3 viewPos) {
    if (isEyeInWater != 0) return color;
    float upDot = viewDir.y;
    float h = 1.0 - clamp01(upDot);
    float h2 = h * h;
    float horizonMask = h2 * h2 * h2;
    float dist = length(viewPos);
    float falloff = clamp01((dist - 16.0) / 128.0);

    vec3 hazeColor = getSkyColor(viewDir);
    float strength = horizonMask * falloff * 0.35;

    return mix(color, hazeColor, strength);
}

// Rain fog: darkens and flattens distant surfaces
vec3 applyRainFog(vec3 color, vec3 viewDir, vec3 viewPos) {
    if (rainStrength < 0.01) return color;
    float dist = length(viewPos);
    float fogFactor = clamp01((dist - 16.0) / 160.0) * rainStrength * 0.55;
    vec3 rainColor = vec3(0.45, 0.50, 0.55);
    return mix(color, rainColor, fogFactor);
}

#endif // AURORA_FOG_GLSL
