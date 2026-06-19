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
#define shadowMapResolution 2048 // [512 1024 2048 4096] Shadow map resolution
#endif

#ifndef fogDensity
#define fogDensity 0.0085 // [0.0000 0.0025 0.0050 0.0085 0.0125 0.0200 0.0350] Atmospheric fog density
#endif

#ifndef sunIntensity
#define sunIntensity 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0] Sun and sky intensity
#endif

#ifndef bloomThreshold
#define bloomThreshold 1.2 // [0.5 0.8 1.0 1.2 1.5 2.0 2.5 3.0] Bloom threshold
#endif

#ifndef ambientStrength
#define ambientStrength 0.20 // [0.05 0.10 0.15 0.20 0.25 0.30 0.40 0.50] Ambient light strength
#endif

#ifndef specularStrength
#define specularStrength 0.35 // [0.0 0.1 0.2 0.35 0.5 0.75 1.0] Specular strength
#endif

#ifndef roughness
#define roughness 0.65 // [0.10 0.20 0.35 0.50 0.65 0.80 0.95] Global roughness scale
#endif

#ifndef sunSize
#define sunSize 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0] Sun disc size
#endif

#ifndef moonIntensity
#define moonIntensity 0.35 // [0.0 0.1 0.2 0.35 0.5 0.75 1.0] Moon intensity
#endif

#ifndef fogHeightFalloff
#define fogHeightFalloff 0.010 // [0.000 0.002 0.005 0.010 0.020 0.035 0.050] Height fog falloff
#endif

#ifndef shadowSoftness
#define shadowSoftness 1.5 // [0.5 1.0 1.5 2.0 2.5 3.0 4.0] Shadow softness
#endif

#ifndef cloudSpeed
#define cloudSpeed 0.35 // [0.0 0.1 0.2 0.35 0.5 0.75 1.0] Cloud movement speed
#endif

#ifndef cloudDensity
#define cloudDensity 0.45 // [0.0 0.15 0.30 0.45 0.60 0.75 0.90] Cloud coverage
#endif

#ifndef exposureMin
#define exposureMin 0.35 // [0.15 0.25 0.35 0.50 0.75 1.00] Minimum auto exposure
#endif

#ifndef exposureMax
#define exposureMax 2.25 // [1.00 1.50 2.00 2.25 2.75 3.50 4.50] Maximum auto exposure
#endif

#ifndef cloudHeight
#define cloudHeight 0.62 // [0.35 0.45 0.55 0.62 0.75 0.90] Cloud layer height
#endif

// ---------- Shadow ----------
#ifndef SHADOW_MAP_BIAS
#define SHADOW_MAP_BIAS 0.85 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0] Shadow map bias
#endif

// ---------- SSAO ----------
#ifndef SSAO_RADIUS
#define SSAO_RADIUS 0.8 // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0] SSAO radius
#endif

#ifndef SSAO_BIAS
#define SSAO_BIAS 0.025 // [0.005 0.010 0.015 0.020 0.025 0.030 0.050 0.100] SSAO bias
#endif

#ifndef AO_STRENGTH
#define AO_STRENGTH 1.0 // [0.0 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0] AO strength
#endif

// ---------- Bloom ----------
#ifndef BLOOM_STRENGTH
#define BLOOM_STRENGTH 1.0 // [0.0 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0] Bloom strength
#endif

// ---------- Exposure / tonemap ----------
#ifndef EXPOSURE_ADAPT_SPEED
#define EXPOSURE_ADAPT_SPEED 1.5 // [0.1 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0] Exposure adapt speed
#endif

#ifndef SATURATION
#define SATURATION 1.05 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0] Saturation
#endif

#ifndef CONTRAST
#define CONTRAST 1.03 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0] Contrast
#endif

// ---------- Animation toggles ----------
// These are numerical options (1 or 0) based on your original code!
#ifndef WAVING_FOLIAGE
#define WAVING_FOLIAGE 1 // [0 1] Waving foliage
#endif

#ifndef WATER_REFLECT
#define WATER_REFLECT 1 // [0 1] Water reflection
#endif

// ---------- Half-resolution toggles (perf) ----------
// These are also numerical options (1 or 0)!
#ifndef HALF_RES_SSAO
#define HALF_RES_SSAO 0 // [0 1] Half resolution SSAO
#endif

#ifndef HALF_RES_BLOOM
#define HALF_RES_BLOOM 0 // [0 1] Half resolution Bloom
#endif

#ifndef HALF_RES_GODRAYS
#define HALF_RES_GODRAYS 0 // [0 1] Half resolution Godrays
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
  #define SHADOW_SAMPLES 8
  #define SSAO_SAMPLES   8
#elif qualityLevel >= 1
  #define SHADOW_SAMPLES 4
  #define SSAO_SAMPLES   4
#else
  #define SHADOW_SAMPLES 1
  #define SSAO_SAMPLES   4
#endif

#endif // AURORA_SETTINGS_GLSL
