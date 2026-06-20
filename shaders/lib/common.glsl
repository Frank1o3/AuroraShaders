// =====================================================================
// Aurora Shaders - common.glsl
// Shared definitions, uniforms and helper utilities.
// Target: GLSL 460 core (OpenGL 4.6)
//
// This file is the root of the include DAG. Every other lib file and
// every stage file transitively includes this. The include guard
// (AURORA_COMMON_GLSL) guarantees it is inlined exactly once per
// translation unit regardless of how many dependency paths reach it.
// =====================================================================
#ifndef AURORA_COMMON_GLSL
#define AURORA_COMMON_GLSL

// Pull in all tunable constants + quality settings.
#include "settings.glsl"

// ---------------------------------------------------------------------
// Math constants
// ---------------------------------------------------------------------
#define PI            3.14159265358979323846
#define TAU           6.28318530717958647692
#define INV_PI        0.31830988618379067154
#define INV_TAU       0.15915494309189533577
#define EPSILON       1e-5
#define LOG2          0.6931471805599453
#define GOLDEN_RATIO  1.61803398875

// ---------------------------------------------------------------------
// Iris / OptiFine standard uniforms.
// These are injected automatically by Iris; we declare them here once
// so every stage that includes common.glsl has them available.
// Do NOT redeclare any of these in stage files.
// ---------------------------------------------------------------------
uniform int   frameCounter;
uniform int   isEyeInWater;          // 0 = air, 1 = water, 2 = lava, 3 = powder snow
uniform float frameTime;
uniform float frameTimeCounter;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform float farPlane;
uniform float rainStrength;
uniform float wetness;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float nightVision;
uniform float eyeAltitude;
uniform float sunAngle;

uniform vec3  sunPosition;
uniform vec3  moonPosition;
uniform vec3  upPosition;
uniform vec3  shadowLightPosition;   // sun OR moon depending on time
uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;

uniform mat4  gbufferModelView;
uniform mat4  gbufferModelViewInverse;
uniform mat4  gbufferProjection;
uniform mat4  gbufferProjectionInverse;
uniform mat4  gbufferPreviousModelView;
uniform mat4  gbufferPreviousProjection;

uniform mat4  shadowProjection;
uniform mat4  shadowProjectionInverse;
uniform mat4  shadowModelView;
uniform mat4  shadowModelViewInverse;

uniform sampler2D colortex0;     // albedo (gbuffers) / lit scene (composite)
uniform sampler2D colortex1;     // normals + mat id (gbuffers) / SSAO (composite)
uniform sampler2D colortex2;     // lightmap + roughness / bloom
uniform sampler2D colortex3;     // velocity / debug / exposure
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;    // opaque shadow map
uniform sampler2D shadowtex1;    // transparent shadow map
uniform sampler2D shadowcolor0;  // colored shadow (transparent)
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;

// ---------------------------------------------------------------------
// Generic math helpers
// ---------------------------------------------------------------------
float clamp01(float v) { return clamp(v, 0.0, 1.0); }
vec3  clamp01(vec3 v)  { return clamp(v, vec3(0.0), vec3(1.0)); }

float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// Convert linear RGB to/from luminance-weighted grayscale fast
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// Rebuild view-space position from a depth sample + UV
vec3 screenToView(vec2 uv, float depthSample, mat4 invProj) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depthSample * 2.0 - 1.0, 1.0);
    vec4 view = invProj * clip;
    return view.xyz / view.w;
}

// Rebuild world-space position from a view-space position
vec3 viewToWorld(vec3 viewPos, mat4 invModelView) {
    vec4 world = invModelView * vec4(viewPos, 1.0);
    return world.xyz;
}

// Cheap blue-ish 2D hash for dithering (used by SSAO, shadows, FXAA)
float interleavedGradientNoise(vec2 px) {
    return fract(52.9829189 * fract(0.06711056 * px.x + 0.00583715 * px.y));
}

// ---------------------------------------------------------------------
// Color space conversions.
// These are basic utilities used by every gbuffers stage and the final
// pass, so they live here (NOT in tonemap.glsl) to avoid forcing every
// stage to include tonemap.glsl.
// ---------------------------------------------------------------------
vec3 linearToSRGB(vec3 c) {
    c = max(c, vec3(0.0));
    return mix(c * 12.92, pow(c, vec3(1.0 / 2.4)) * 1.055 - 0.055,
               step(0.0031308, c));
}

vec3 sRGBToLinear(vec3 c) {
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)),
               step(0.04045, c));
}

// ---------------------------------------------------------------------
// Time-of-day helpers
// sunAngle: 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset
// ---------------------------------------------------------------------
float daylightFactor() {
    vec3 sunDir = normalize(sunPosition);
    vec3 upDir = normalize(upPosition);
    return smoothstep(-0.15, 0.15, dot(sunDir, upDir));
}

float moonlightFactor() {
    return clamp01(1.0 - daylightFactor());
}

// Eye adaptation factor based on day/night for stable readability
float ambientLevel() {
    float d = daylightFactor();
    return mix(0.05, 0.45, d); // night floor 0.05, day peak 0.45
}

// ---------------------------------------------------------------------
// Material IDs (stored in colortex1.a as v_BlockId/255.0)
// ---------------------------------------------------------------------
#define MAT_DEFAULT   0
#define MAT_LEAVES    100
#define MAT_GRASS     101
#define MAT_FOLIAGE   102
#define MAT_SAND      103
#define MAT_METAL     150
#define MAT_WATER     200
#define MAT_LAVA      201
#define MAT_EMISSIVE  250

#endif // AURORA_COMMON_GLSL
