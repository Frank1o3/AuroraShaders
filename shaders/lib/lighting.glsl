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
vec3 skyColorNight     = vec3(0.030, 0.040, 0.085);

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
    vec3 nightCol = skyColorNight * (0.75 + moonIntensity * 0.85);

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

vec3 getSkyAmbientColor(float day) {
    vec3 dayAmbient = vec3(0.58, 0.68, 0.82) * sunIntensity;
    // Boost night ambient color to increase night terrain readability
    vec3 nightAmbient = vec3(0.090, 0.115, 0.180) * (0.80 + moonIntensity * 1.5);
    return mix(nightAmbient, dayAmbient, day);
}

// ---------------------------------------------------------------------
// Atmospheric sky contribution as an ambient fill (Hemispheric)
// ---------------------------------------------------------------------
vec3 ambientHemisphere(vec3 N, float skyLight, float ao, vec3 skyAmbientColor, float day) {
    vec3 upDir = normalize(upPosition);
    float upDot = dot(N, upDir) * 0.5 + 0.5;

    // Proper Ambient Occlusion term applied smoothly to ambient light
    float aoTerm = mix(0.25, 1.0, clamp01(ao));
    
    // Sky light visibility mapping: skyLight is normalized 0-1
    float skyVis = clamp01(skyLight);
    // Non-linear mapping for natural sky light falloff
    float skyAccess = mix(0.25, 1.0, skyVis * skyVis);

    // Boost night ground base color (from 0.038... to 0.05...)
    vec3 ground = mix(vec3(0.050, 0.055, 0.070), vec3(0.24, 0.22, 0.18), day);
    vec3 hemiColor = mix(ground, skyAmbientColor, upDot);

    // Boost ambient by a healthy factor to make it the primary outdoor light source.
    // Scales ambient strength to target ~70-85% perceived outdoor brightness at default settings.
    float strength = max(ambientStrength, 0.05) * 3.5;

    return hemiColor * (skyAccess * aoTerm * strength);
}

// ---------------------------------------------------------------------
// Full direct lighting (sun/moon) with shadow + soft fill.
// ---------------------------------------------------------------------
vec3 computeDirectLighting(vec3 albedo, vec3 N, vec3 V, vec3 worldPos,
                           float materialRoughness, float metallic, float ao,
                           vec3 activeLightColor) {
    N = normalize(N);
    V = normalize(V);
    vec3 L = normalize(shadowLightPosition);
    float NdotL = clamp01(dot(N, L));
    float NdotV = clamp01(dot(N, V));
    float shadow = getShadowFactor(worldPos, N);

    float sunShape = NdotL * shadow;
    
    // Scale direct sunlight down (from 0.26 to 0.10) to keep it additive
    // on top of a strong ambient base (15-30% direct sunlight contribution).
    vec3 diffuse = albedo * activeLightColor * sunShape * 0.10;
    vec3 spec = vec3(0.0);

#if ENABLE_SPECULAR == 1
    if (NdotL > 0.0 && shadow > 0.0 && specularStrength > 0.0) {
        vec3 H = normalize(L + V);
        float NdotH = clamp01(dot(N, H));
        float fresnel = fastPow01(1.0 - NdotV, 5.0);
        float gloss = mix(32.0, 8.0, clamp01(materialRoughness));
        float specTerm = fastPow01(NdotH, gloss) * (0.04 + fresnel);
        spec = activeLightColor * specTerm * specularStrength * shadow * (1.0 - materialRoughness * 0.45) * 0.55;
    }
#endif

    return max(diffuse + spec, vec3(0.0));
}

// ---------------------------------------------------------------------
// Block-light (from lightmap, e.g. torches) - warm point light tint
// ---------------------------------------------------------------------
vec3 blockLightColor(float torchValue) {
    vec3 warm = vec3(1.00, 0.62, 0.28); // warmer cozy orange-yellow
    vec3 base = vec3(0.12, 0.08, 0.06); // lower base glow for nicer contrast
    return mix(base, warm, torchValue);
}

// ---------------------------------------------------------------------
// Final light accumulation for a shaded surface.
// ---------------------------------------------------------------------
vec3 shadeSurface(vec3 albedo, vec3 N, vec3 V, vec3 worldPos,
                  float materialRoughness, float metallic, float ao,
                  float torchLight, float skyLight,
                  int matId, float day, vec3 activeLightColor, vec3 skyAmbientColor) {
    float surfaceRoughness = clamp01(materialRoughness * roughness);
    vec3 direct = computeDirectLighting(albedo, N, V, worldPos, surfaceRoughness, metallic, ao, activeLightColor);

    float torch01 = clamp01(torchLight);
    // Smooth quadratic curve boost for torch light: spreads further and has a warm cozy glow
    float torchGlow = torch01 * (1.0 + torch01 * 2.5);
    vec3 blockLight = blockLightColor(torch01) * albedo * torchGlow * 1.5;

    float sky01 = clamp01(skyLight);
    vec3 ambient = albedo * ambientHemisphere(N, sky01, ao, skyAmbientColor, day);
    
    // Lower, soft minimum ambient to act only as a backup in pitch-black areas.
    // Increased night floor (from 0.015... to 0.04...) to prevent crushed blacks.
    vec3 minAmbient = mix(vec3(0.040, 0.050, 0.070), vec3(0.07, 0.08, 0.10), day);
    ambient = max(ambient, albedo * minAmbient * (0.20 + 0.80 * sky01));

    vec3 color = max(ambient + direct + blockLight, vec3(0.0));

    // Foliage gets a touch of SSS for that "translucent leaves" look.
    // Optimized: inlined and uses pre-calculated day factor.
    if (matId == MAT_LEAVES || matId == MAT_GRASS || matId == MAT_FOLIAGE) {
        vec3 L = normalize(shadowLightPosition);
        float backLight = clamp01(dot(-N, L));
        vec3 sss = albedo * vec3(1.0, 0.6, 0.3) * backLight * 0.20;
        color += sss * day;
    }

    // Emissive blocks (lava, sea lantern, glowstone, etc.) just pass albedo through
    if (matId == MAT_EMISSIVE || matId == MAT_LAVA) {
        color += albedo * 2.0;
    }

    return color;
}

#endif // AURORA_LIGHTING_GLSL
