// =====================================================================
// Aurora Shaders - settings.glsl
// =====================================================================
#ifndef AURORA_SETTINGS_GLSL
#define AURORA_SETTINGS_GLSL

// ---------- Quality tier ----------
#ifndef QUALITY_LEVEL
#define QUALITY_LEVEL 1 // [0 1 2 3] Quality tier (0=low, 1=medium, 2=high, 3=ultra)
#endif

// ---------- Shadow ----------
#ifndef SHADOW_MAP_BIAS
#define SHADOW_MAP_BIAS 0.85 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0] Shadow map bias
#endif

#ifndef SHADOW_PCF_SIZE
#define SHADOW_PCF_SIZE 1.5 // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0] Shadow PCF size
#endif

const int shadowMapResolution = 2048; // [512 1024 2048 4096] Shadow map resolution

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
#ifndef BLOOM_THRESHOLD
#define BLOOM_THRESHOLD 1.2 // [0.5 1.0 1.5 2.0 2.5 3.0] Bloom threshold
#endif

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

// ---------- Sample counts (driven by QUALITY_LEVEL) ----------
#if QUALITY_LEVEL >= 2
  #define SHADOW_SAMPLES 12
  #define SSAO_SAMPLES   16
#elif QUALITY_LEVEL >= 1
  #define SHADOW_SAMPLES 8
  #define SSAO_SAMPLES   8
#else
  #define SHADOW_SAMPLES 4
  #define SSAO_SAMPLES   4
#endif

#endif // AURORA_SETTINGS_GLSL