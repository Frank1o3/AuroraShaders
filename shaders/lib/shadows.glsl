// =====================================================================
// Aurora Shaders - shadows.glsl
// Stable soft shadow sampling using 4-8 tap PCF.
// Tuned for stable, low-cost soft shadows at the configured shadow map
// resolution (see shadowMapResolution in settings.glsl).
// =====================================================================
#ifndef AURORA_SHADOWS_GLSL
#define AURORA_SHADOWS_GLSL

#include "common.glsl"

// ---------------------------------------------------------------------
// Transform world position to shadow clip space and pack to UV
// ---------------------------------------------------------------------
vec3 toShadowClipSpace(vec3 worldPos) {
    vec4 shadowClip = shadowProjection * shadowModelView * vec4(worldPos, 1.0);
    vec3 shadowNDC  = shadowClip.xyz / shadowClip.w;
    // Optifine/Iris shadow textures are 0..1
    return shadowNDC * 0.5 + 0.5;
}

// ---------------------------------------------------------------------
// Soft shadow: fixed-disk PCF.
// Sample count is driven by qualityLevel via SHADOW_SAMPLES.
// ---------------------------------------------------------------------

#if SHADOW_SAMPLES >= 8
  const vec2 diskSamples8[8] = vec2[8](
      vec2( 0.3063, -0.2389),
      vec2(-0.3063,  0.2389),
      vec2( 0.7071,  0.7071),
      vec2(-0.7071, -0.7071),
      vec2( 0.1768,  0.9239),
      vec2(-0.1768, -0.9239),
      vec2( 0.9239, -0.1768),
      vec2(-0.9239,  0.1768)
  );
#else
  const vec2 diskSamples4[4] = vec2[4](
      vec2( 0.5,  0.5),
      vec2(-0.5,  0.5),
      vec2( 0.5, -0.5),
      vec2(-0.5, -0.5)
  );
#endif

float sampleShadowSoft(vec3 shadowUV, float normalBias, float spread) {
    // Pull sample toward the light by normal bias (kills acne)
    float receiver = shadowUV.z - normalBias;

    if (receiver <= 0.0 || receiver >= 1.0) return 1.0;
    if (any(lessThan(shadowUV.xy, vec2(0.0))) ||
        any(greaterThan(shadowUV.xy, vec2(1.0)))) return 1.0;

    float shadow = 0.0;

#if SHADOW_SAMPLES >= 8
    for (int i = 0; i < 8; i++) {
        vec2 offset = diskSamples8[i] * spread;
        float mapDepth = texture(shadowtex0, shadowUV.xy + offset).r;
        shadow += (receiver - 0.0008 <= mapDepth) ? 1.0 : 0.0;
    }
    return shadow * (1.0 / 8.0);
#else
    for (int i = 0; i < 4; i++) {
        vec2 offset = diskSamples4[i] * spread;
        float mapDepth = texture(shadowtex0, shadowUV.xy + offset).r;
        shadow += (receiver - 0.0008 <= mapDepth) ? 1.0 : 0.0;
    }
    return shadow * (1.0 / 4.0);
#endif
}

// ---------------------------------------------------------------------
// Public entry: compute shadow factor for a world position & normal.
// ---------------------------------------------------------------------
float getShadowFactor(vec3 worldPos, vec3 worldNormal) {
#if ENABLE_SHADOWS == 0
    return 1.0;
#else
    vec3 shadowUV = toShadowClipSpace(worldPos);

    // Slope-based normal bias: steeper surfaces get more bias
    vec3 L = normalize(shadowLightPosition);
    float NdotL = clamp01(dot(worldNormal, L));
    float slope = 1.0 - NdotL;
    float normalBias = mix(0.0006, 0.0025, slope);

    // Spread scales with how far we are from the shadow map centre to
    // keep edges crisp near the player and softer at the fringes.
    float spread = shadowSoftness / shadowMapResolution;
    spread *= mix(0.7, 1.4, 1.0 - clamp01(length(shadowUV.xy - 0.5) * 2.0));

    return sampleShadowSoft(shadowUV, normalBias, spread);
#endif
}

// ---------------------------------------------------------------------
// Colored translucent shadow (water, stained glass, leaves tint).
// Reads from shadowtex1 (transparent) and shadowcolor0 for tint.
// ---------------------------------------------------------------------
vec3 getColoredShadow(vec3 worldPos) {
#if ENABLE_SHADOWS == 0
    return vec3(1.0);
#else
    vec3 shadowUV = toShadowClipSpace(worldPos);
    if (any(lessThan(shadowUV.xy, vec2(0.0))) ||
        any(greaterThan(shadowUV.xy, vec2(1.0)))) return vec3(1.0);

    float opaque      = texture(shadowtex0, shadowUV.xy).r;
    float transparent = texture(shadowtex1, shadowUV.xy).r;
    vec3  tint        = texture(shadowcolor0, shadowUV.xy).rgb;

    float receiver = shadowUV.z - 0.0008;
    bool litOpaque      = receiver <= opaque;
    bool litTransparent = receiver <= transparent;

    if (litOpaque) {
        return vec3(1.0);
    } else if (litTransparent) {
        return mix(vec3(1.0), tint, 0.6);
    } else {
        return vec3(0.0);
    }
#endif
}

#endif // AURORA_SHADOWS_GLSL
