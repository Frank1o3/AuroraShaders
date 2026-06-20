// =====================================================================
// Aurora Shaders - settings.glsl
// =====================================================================
#ifndef AURORA_SETTINGS_GLSL
#define AURORA_SETTINGS_GLSL

// ---------- Required Iris-facing controls ----------
#ifndef qualityLevel
#define qualityLevel 1 // [0 1 2] Quality tier (0=low, 1=medium, 2=high)
#endif

#ifndef shadowMapResolution
#define shadowMapResolution 1024
#endif

#ifndef fogDensity
#define fogDensity 0.0085
#endif

#ifndef sunIntensity
#define sunIntensity 1.0
#endif

#ifndef bloomThreshold
#define bloomThreshold 1.2
#endif

#ifndef ambientStrength
#define ambientStrength 0.20
#endif

#ifndef specularStrength
#define specularStrength 0.35
#endif

#ifndef roughness
#define roughness 0.65
#endif

#ifndef sunSize
#define sunSize 1.0
#endif

#ifndef moonIntensity
#define moonIntensity 0.35
#endif

#ifndef fogHeightFalloff
#define fogHeightFalloff 0.010
#endif

#ifndef shadowSoftness
#define shadowSoftness 1.5
#endif

#ifndef cloudSpeed
#define cloudSpeed 0.35
#endif

#ifndef cloudDensity
#define cloudDensity 0.45
#endif

#ifndef exposureMin
#define exposureMin 0.35
#endif

#ifndef exposureMax
#define exposureMax 2.25
#endif

#ifndef cloudHeight
#define cloudHeight 0.62
#endif

// ---------- Shadow ----------
#ifndef SHADOW_MAP_BIAS
#define SHADOW_MAP_BIAS 0.85
#endif

// ---------- SSAO ----------
#ifndef SSAO_RADIUS
#define SSAO_RADIUS 0.8
#endif

#ifndef SSAO_BIAS
#define SSAO_BIAS 0.025
#endif

#ifndef AO_STRENGTH
#define AO_STRENGTH 1.0
#endif

// ---------- Bloom ----------
#ifndef BLOOM_STRENGTH
#define BLOOM_STRENGTH 1.0
#endif

// ---------- Exposure / tonemap ----------
#ifndef EXPOSURE_ADAPT_SPEED
#define EXPOSURE_ADAPT_SPEED 1.5
#endif

#ifndef SATURATION
#define SATURATION 1.05
#endif

#ifndef CONTRAST
#define CONTRAST 1.03
#endif

// ---------- Animation toggles ----------
// These are numerical options (1 or 0) based on your original code!
#ifndef WAVING_FOLIAGE
#define WAVING_FOLIAGE 1
#endif

#ifndef WATER_REFLECT
#define WATER_REFLECT 1
#endif

// ---------- Half-resolution toggles (perf) ----------
// These are also numerical options (1 or 0)!
#ifndef HALF_RES_SSAO
#define HALF_RES_SSAO 0
#endif

#ifndef HALF_RES_BLOOM
#define HALF_RES_BLOOM 0
#endif

#ifndef HALF_RES_GODRAYS
#define HALF_RES_GODRAYS 0
#endif

// ---------- Quality gates ----------
#if qualityLevel >= 1
  #define ENABLE_SHADOWS 1
#else
  #define ENABLE_SHADOWS 0
#endif

#if qualityLevel >= 2
  #define ENABLE_SSAO 1
#else
  #define ENABLE_SSAO 0
#endif

#if qualityLevel >= 1
  #define ENABLE_CLOUDS 1
#else
  #define ENABLE_CLOUDS 0
#endif

#if qualityLevel >= 1
  #define ENABLE_SPECULAR 1
#else
  #define ENABLE_SPECULAR 0
#endif

#if qualityLevel >= 2
  #define SHADOW_SAMPLES 4
  #define SSAO_SAMPLES   4
#elif qualityLevel >= 1
  #define SHADOW_SAMPLES 4
  #define SSAO_SAMPLES   4
#else
  #define SHADOW_SAMPLES 1
  #define SSAO_SAMPLES   4
#endif

#endif // AURORA_SETTINGS_GLSL
