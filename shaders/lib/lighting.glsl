// =====================================================================
// Aurora Shaders - lighting.glsl
// View-space PBR-lite lighting, sky model, sun/moon discs.
// All directional lighting vectors in this file are view-space vectors.
// =====================================================================
#ifndef AURORA_LIGHTING_GLSL
#define AURORA_LIGHTING_GLSL

#include "common.glsl"
#include "shadows.glsl"

// ---------------------------------------------------------------------
// Sky colors driven by sun angle.
// Uses a simple, cheap Rayleigh-ish approximation - good enough for
// performance and visually pleasing.
// ---------------------------------------------------------------------
vec3 skyColorDayTop    = vec3(0.20, 0.45, 0.95);
vec3 skyColorDayHoriz  = vec3(0.55, 0.75, 1.00);
vec3 skyColorSunset    = vec3(1.00, 0.55, 0.30);
vec3 skyColorNight     = vec3(0.012, 0.020, 0.045);

float fastPow01(float x, float p) {
    return exp2(log2(max(clamp01(x), EPSILON)) * p);
}

float horizonDayFactor() {
    vec3 sunDir = normalize(sunPosition);
    return smoothstep(-0.08, 0.18, dot(sunDir, normalize(upPosition)));
}

vec3 getSkyColor(vec3 dir) {
    vec3 upDir = normalize(upPosition);
    vec3 sunDir = normalize(sunPosition);
    float upDot = clamp01(dot(normalize(dir), upDir));
    float day = horizonDayFactor();

    vec3 dayCol = mix(skyColorDayHoriz, skyColorDayTop, fastPow01(upDot, 0.6));
    vec3 nightCol = skyColorNight;

    float sunHeight = dot(sunDir, upDir);
    float sunsetMask = smoothstep(-0.08, 0.12, sunHeight) * (1.0 - smoothstep(0.18, 0.55, sunHeight));
    float sunForward = fastPow01(clamp01(dot(normalize(dir), sunDir) * 0.5 + 0.5), 3.0);
    vec3 tint = skyColorSunset * sunsetMask * sunForward;

    vec3 col = mix(nightCol, dayCol, day) + tint;
    col *= sunIntensity;
    return col;
}

// ---------------------------------------------------------------------
// Sun & moon light intensities
// ---------------------------------------------------------------------
vec3 getSunLightColor() {
    vec3 upDir = normalize(upPosition);
    vec3 sunDir = normalize(sunPosition);
    float sunHeight = dot(sunDir, upDir);
    float day = smoothstep(-0.04, 0.16, sunHeight);
    float horizon = 1.0 - smoothstep(0.10, 0.65, sunHeight);
    vec3 noon = vec3(1.00, 0.97, 0.90) * 1.45;
    vec3 sunset = vec3(1.25, 0.62, 0.32) * 1.10;
    return mix(noon, sunset, horizon * 0.75) * day * sunIntensity;
}

vec3 getMoonLightColor() {
    vec3 upDir = normalize(upPosition);
    float moonAbove = smoothstep(-0.05, 0.16, dot(normalize(moonPosition), upDir));
    return vec3(0.36, 0.45, 0.78) * moonIntensity * moonAbove * (1.0 - horizonDayFactor());
}

vec3 getSunSkyAdd(vec3 viewDir) {
    vec3 sunDir = normalize(sunPosition);
    float sunDot = clamp01(dot(viewDir, sunDir));
    float day = horizonDayFactor();

    float discSize = max(sunSize, 0.1);
    float disc = smoothstep(1.0 - 0.00042 * discSize, 1.0 - 0.00008 * discSize, sunDot);
    float innerGlow = fastPow01(sunDot, 48.0);
    float outerGlow = fastPow01(sunDot, 8.0);

    float rayNoise = interleavedGradientNoise(gl_FragCoord.xy);
    float horizon = clamp01(1.0 - abs(dot(viewDir, normalize(upPosition))) * 1.8);
    float rays = fastPow01(sunDot, 18.0) * horizon * mix(0.75, 1.0, rayNoise);

    return getSunLightColor() * day * (disc * 5.5 + innerGlow * 0.55 + outerGlow * 0.12 + rays * 0.22);
}

vec3 getMoonSkyAdd(vec3 viewDir) {
    vec3 moonDir = normalize(moonPosition);
    float moonDot = clamp01(dot(viewDir, moonDir));
    float night = 1.0 - horizonDayFactor();

    float disc = smoothstep(0.99955, 0.99986, moonDot);
    float glow = fastPow01(moonDot, 16.0);
    return getMoonLightColor() * night * (disc * 3.8 + glow * 0.28);
}

vec3 getStarField(vec3 viewDir) {
    float night = 1.0 - horizonDayFactor();
    if (night <= 0.2) return vec3(0.0);

    float h = fract(sin(dot(viewDir.xy * 220.0 + viewDir.zz * 47.0, vec2(12.9898, 78.233))) * 43758.5453);
    float stars = smoothstep(0.992, 1.0, h) * night;
    return vec3(stars) * 1.6;
}

// Returns the color of the active shadow light (sun during day, moon at night).
// shadowLightPosition already points to whichever is currently above the horizon.
vec3 getActiveLightColor() {
    // During the day, sun contributes; at night, moon contributes.
    // getSunLightColor already returns 0 at night; getMoonLightColor
    // already returns 0 during the day (via moonlightFactor()).
    return getSunLightColor() + getMoonLightColor();
}

// ---------------------------------------------------------------------
// Atmospheric sky contribution as an ambient fill (Hemispheric)
// ---------------------------------------------------------------------
vec3 ambientHemisphere(vec3 N, vec3 viewDir, float skyLight, float ao) {
    vec3 upDir = normalize(upPosition);
    float upDot = clamp01(dot(N, upDir) * 0.5 + 0.5);
    float skyVis = clamp01(skyLight);
    vec3 sky = getSkyColor(upDir) * (0.35 + 0.65 * skyVis);
    vec3 ground = vec3(0.16, 0.14, 0.12) * (0.65 + 0.35 * skyVis);
    vec3 ambient = mix(ground, sky, upDot);

    float facingSky = clamp01(dot(normalize(viewDir + upDir), upDir));
    ambient = mix(ambient, ambient * 0.88 + getSkyColor(upDir) * 0.12, facingSky * 0.25);
    return max(ambient * max(ambientStrength, 0.2) * ao, vec3(0.0));
}

// ---------------------------------------------------------------------
// Full direct lighting (sun/moon) with shadow + soft fill.
// ---------------------------------------------------------------------
vec3 computeDirectLighting(vec3 albedo, vec3 N, vec3 V, vec3 worldPos,
                           float materialRoughness, float metallic, float ao) {
    N = normalize(N);
    V = normalize(V);
    vec3 L = normalize(shadowLightPosition);
    float NdotL = clamp01(dot(N, L));
    float NdotV = clamp01(dot(N, V));
    float shadow = getShadowFactor(worldPos, N);
    vec3 lightColor = getActiveLightColor();

    vec3 diffuse = albedo * lightColor * NdotL * shadow;
    vec3 spec = vec3(0.0);

#if ENABLE_SPECULAR == 1
    if (NdotL > 0.0 && shadow > 0.0 && specularStrength > 0.0) {
        vec3 H = normalize(L + V);
        float NdotH = clamp01(dot(N, H));
        float fresnel = fastPow01(1.0 - NdotV, 5.0);
        float gloss = mix(32.0, 8.0, clamp01(materialRoughness));
        float specTerm = fastPow01(NdotH, gloss) * (0.04 + fresnel);
        spec = lightColor * specTerm * specularStrength * shadow * (1.0 - materialRoughness * 0.45);
    }
#endif

    return max(diffuse + spec, vec3(0.0));
}

// ---------------------------------------------------------------------
// Subsurface scattering approximation for leaves/grass/foliage.
// Cheap: backlight when sun behind surface.
// ---------------------------------------------------------------------
vec3 subsurfaceFoliage(vec3 albedo, vec3 N, vec3 V, vec3 worldPos) {
    vec3 L = normalize(shadowLightPosition);
    float backLight = clamp01(dot(-N, L));
    float thickness = 0.5; // assumed
    vec3 sss = albedo * vec3(1.0, 0.6, 0.3) * backLight * thickness * 0.4;
    return sss * horizonDayFactor();
}

// ---------------------------------------------------------------------
// Block-light (from lightmap, e.g. torches) - warm point light tint
// ---------------------------------------------------------------------
vec3 blockLightColor(float torchValue) {
    // torchValue in 0..1
    vec3 warm = vec3(1.00, 0.65, 0.30);
    vec3 base = vec3(0.18, 0.14, 0.10); // residual glow
    return mix(base, warm, torchValue) * torchValue;
}

// ---------------------------------------------------------------------
// Final light accumulation for a shaded surface.
// ---------------------------------------------------------------------
vec3 shadeSurface(vec3 albedo, vec3 N, vec3 V, vec3 worldPos,
                  float materialRoughness, float metallic, float ao,
                  float torchLight, float skyLight,
                  int matId) {
    float surfaceRoughness = clamp01(materialRoughness * roughness);
    vec3 direct = computeDirectLighting(albedo, N, V, worldPos, surfaceRoughness, metallic, ao);

    float torch01 = clamp01(torchLight);
    vec3 blockLight = blockLightColor(torch01) * albedo * (0.65 + torch01 * 2.0);

    vec3 ambient = albedo * ambientHemisphere(N, V, skyLight, ao);
    ambient = max(ambient, albedo * vec3(0.2) * ambientStrength * ao);
    vec3 skyFill = getSkyColor(normalize(upPosition)) * clamp01(skyLight) * 0.18 * albedo * ao;

    vec3 color = max(ambient + direct + blockLight + skyFill, vec3(0.0));

    // Foliage gets a touch of SSS for that "translucent leaves" look
    if (matId == MAT_LEAVES || matId == MAT_GRASS || matId == MAT_FOLIAGE) {
        color += subsurfaceFoliage(albedo, N, V, worldPos);
    }

    // Emissive blocks (lava, sea lantern, glowstone, etc.) just pass albedo through
    if (matId == MAT_EMISSIVE || matId == MAT_LAVA) {
        color += albedo * 2.0;
    }

    return color;
}

#endif // AURORA_LIGHTING_GLSL
