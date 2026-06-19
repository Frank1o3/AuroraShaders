// =====================================================================
// Aurora Shaders - lighting.glsl
// Direct sun/moon + ambient + bounce + specular (Cook-Torrance)
// Tuned for clean realistic daylight & stable readable nights.
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

vec3 getSkyColor(vec3 dir) {
    float upDot = clamp01(dir.y);
    float day = daylightFactor();

    vec3 dayCol = mix(skyColorDayHoriz, skyColorDayTop, fastPow01(upDot, 0.6));
    vec3 nightCol = skyColorNight;

    // Sunrise / sunset tint at low sun
    float sunLow = clamp01(1.0 - abs(sunAngle - 0.5) * 3.0); // bumps near 0.25 / 0.75
    vec3 tint = mix(skyColorSunset, skyColorDayHoriz, 0.6) * sunLow * day;

    vec3 col = mix(nightCol, dayCol, day) + tint;
    col *= sunIntensity;
    return col;
}

// ---------------------------------------------------------------------
// Sun & moon light intensities
// ---------------------------------------------------------------------
vec3 getSunLightColor() {
    float day = daylightFactor();
    // Warm white at noon, slightly orange at horizon
    float horizonFactor = 1.0 - day; // higher near sunrise/sunset
    vec3 noon = vec3(1.00, 0.96, 0.88) * 1.5 * sunIntensity;
    vec3 sunset = vec3(1.20, 0.65, 0.35) * 1.1 * sunIntensity;
    vec3 night  = vec3(0.00, 0.00, 0.00);
    vec3 dayCol = mix(noon, sunset, horizonFactor * 0.7);
    return mix(vec3(0.0), dayCol, day);
}

vec3 getMoonLightColor() {
    // Cool, soft blue moonlight — only visible at night
    return vec3(0.45, 0.55, 0.85) * 0.18 * moonlightFactor();
}

vec3 getSunSkyAdd(vec3 viewDir) {
    vec3 sunDir = normalize(sunPosition);
    float sunDot = clamp01(dot(viewDir, sunDir));
    float day = daylightFactor();

    float disc = smoothstep(0.99970, 0.99992, sunDot);
    float innerGlow = fastPow01(sunDot, 48.0);
    float outerGlow = fastPow01(sunDot, 8.0);

    float rayNoise = interleavedGradientNoise(gl_FragCoord.xy + vec2(frameCounter));
    float horizon = clamp01(1.0 - abs(viewDir.y) * 1.8);
    float rays = fastPow01(sunDot, 18.0) * horizon * mix(0.65, 1.0, rayNoise);

    return getSunLightColor() * day * (disc * 5.5 + innerGlow * 0.55 + outerGlow * 0.12 + rays * 0.22);
}

vec3 getMoonSkyAdd(vec3 viewDir) {
    vec3 moonDir = normalize(moonPosition);
    float moonDot = clamp01(dot(viewDir, moonDir));
    float night = moonlightFactor();

    float disc = smoothstep(0.99955, 0.99986, moonDot);
    float glow = fastPow01(moonDot, 16.0);
    return getMoonLightColor() * night * (disc * 5.0 + glow * 0.35);
}

vec3 getStarField(vec3 viewDir) {
    float night = moonlightFactor();
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
// GGX specular (Cook-Torrance) - cheap version
// ---------------------------------------------------------------------
float distributionGGX(float NdotH, float roughness) {
    float a  = roughness * roughness;
    float a2 = a * a;
    float d  = (NdotH * a2 - NdotH) * NdotH + 1.0;
    return a2 / (PI * d * d + EPSILON);
}

float geometrySmith(float NdotV, float NdotL, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    float ggxV = NdotV / (NdotV * (1.0 - k) + k);
    float ggxL = NdotL / (NdotL * (1.0 - k) + k);
    return ggxV * ggxL;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    float f = 1.0 - cosTheta;
    float f2 = f * f;
    return F0 + (1.0 - F0) * f2 * f2 * f;
}

vec3 specularCookTorrance(vec3 N, vec3 V, vec3 L, vec3 F0, float roughness) {
    vec3 H = normalize(V + L);
    float NdotL = clamp01(dot(N, L));
    float NdotV = clamp01(dot(N, V));
    float NdotH = clamp01(dot(N, H));
    float VdotH = clamp01(dot(V, H));

    float D = distributionGGX(NdotH, roughness);
    float G = geometrySmith(NdotV, NdotL, roughness);
    vec3  F = fresnelSchlick(VdotH, F0);

    vec3 num = D * G * F;
    float den = 4.0 * NdotV * NdotL + EPSILON;
    return num / den;
}

// ---------------------------------------------------------------------
// Atmospheric sky contribution as an ambient fill (Hemispheric)
// ---------------------------------------------------------------------
vec3 ambientHemisphere(vec3 N, vec3 viewPos) {
    vec3 skyDir = upPosition;
    float upDot = clamp01(N.y * 0.5 + 0.5); // 0 = down, 1 = up
    vec3 sky = getSkyColor(skyDir) * ambientLevel();
    vec3 ground = vec3(0.18, 0.16, 0.14) * ambientLevel();
    vec3 ambient = mix(ground, sky, upDot);

    // Tiny view-distance fade so distant terrain picks up atmospheric haze
    float dist = length(viewPos);
    float haze = clamp01((dist - 32.0) / 220.0);
    ambient = mix(ambient, ambient * 0.85 + getSkyColor(normalize(viewPos + vec3(0.0, 1.0, 0.0))) * 0.15, haze * 0.5);
    return ambient;
}

// ---------------------------------------------------------------------
// Full direct lighting (sun/moon) with shadow + soft fill.
// ---------------------------------------------------------------------
vec3 computeDirectLighting(vec3 albedo, vec3 N, vec3 V, vec3 worldPos,
                           float roughness, float metallic, float ao) {
    vec3 L = normalize(shadowLightPosition);
    float NdotL = clamp01(dot(N, L));

    // Active shadow (soft)
    float shadow = getShadowFactor(worldPos, N);

    vec3 lightColor = getActiveLightColor();

    // Wrap-around soft fill for low light angles (gives the moonlit look
    // readability even when NdotL ~ 0)
    float wrap = clamp01(NdotL * 0.75 + 0.25);

    // Diffuse (half-Lambert wrap, no π normalization since wrap changes
    // the energy integral anyway — the lightColor intensity is tuned for this)
    vec3 diffuse = albedo * lightColor * wrap * shadow;

    // Specular (Cook-Torrance) — skip when surface faces away from light
    vec3 spec = vec3(0.0);
    if (NdotL > 0.0 && shadow > 0.0) {
        vec3 F0 = mix(vec3(0.04), albedo, metallic);
        spec = specularCookTorrance(N, V, L, F0, roughness) * lightColor * shadow;
    }

    // Sky bounce as ambient (cheap GI feel)
    vec3 ambient = ambientHemisphere(N, worldPos) * albedo * ao;

    return diffuse + spec + ambient;
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
    return sss * daylightFactor();
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
                  float roughness, float metallic, float ao,
                  float torchLight, float skyLight,
                  int matId) {
    vec3 direct = computeDirectLighting(albedo, N, V, worldPos, roughness, metallic, ao);

    // Block light with mild quadratic-ish falloff simulated by skyLight
    float torch01 = torchLight;
    vec3 blockLight = blockLightColor(torch01) * albedo;

    // Sky light: user-provided skyLight value drives ambient intensity
    vec3 skyFill = getSkyColor(upPosition) * skyLight * ambientLevel() * 0.6 * albedo * ao;

    vec3 color = direct + blockLight + skyFill;

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
