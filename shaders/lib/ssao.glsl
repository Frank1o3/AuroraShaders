// =====================================================================
// Aurora Shaders - ssao.glsl
// Scalable ambient occlusion (GTAO-inspired).
// Sample count is driven by qualityLevel via SSAO_SAMPLES.
// Designed for half-resolution rendering when HALF_RES_SSAO=1.
// =====================================================================
#ifndef AURORA_SSAO_GLSL
#define AURORA_SSAO_GLSL

#include "common.glsl"

// Reconstruct view-space normal from depth (fallback when G-buffer
// normal is unavailable, e.g. on the hand).
vec3 reconstructViewNormal(vec3 viewPos) {
    vec3 dx = dFdx(viewPos);
    vec3 dy = dFdy(viewPos);
    return normalize(cross(dx, dy));
}

// ---------------------------------------------------------------------
// Hemisphere sample sets, selected by qualityLevel.
// ---------------------------------------------------------------------
#if SSAO_SAMPLES >= 16
  const vec3 ssaoSamples16[16] = vec3[16](
      vec3( 0.71,  0.21,  0.58),
      vec3(-0.71,  0.21,  0.58),
      vec3( 0.31,  0.82,  0.36),
      vec3(-0.31, -0.82,  0.36),
      vec3( 0.12, -0.45,  0.78),
      vec3(-0.12,  0.45,  0.78),
      vec3( 0.92, -0.18,  0.12),
      vec3(-0.92,  0.18,  0.12),
      vec3( 0.55,  0.65,  0.45),
      vec3(-0.55,  0.65,  0.45),
      vec3( 0.20, -0.85,  0.40),
      vec3(-0.20, -0.85,  0.40),
      vec3( 0.78,  0.40,  0.30),
      vec3(-0.78,  0.40,  0.30),
      vec3( 0.05,  0.10,  0.95),
      vec3(-0.05, -0.10,  0.95)
  );
#elif SSAO_SAMPLES >= 8
  const vec3 ssaoSamples8[8] = vec3[8](
      vec3( 0.71,  0.21,  0.58),
      vec3(-0.71,  0.21,  0.58),
      vec3( 0.31,  0.82,  0.36),
      vec3(-0.31, -0.82,  0.36),
      vec3( 0.12, -0.45,  0.78),
      vec3(-0.12,  0.45,  0.78),
      vec3( 0.92, -0.18,  0.12),
      vec3(-0.92,  0.18,  0.12)
  );
#else
  const vec3 ssaoSamples4[4] = vec3[4](
      vec3( 0.71,  0.21,  0.58),
      vec3(-0.71,  0.21,  0.58),
      vec3( 0.31,  0.82,  0.36),
      vec3(-0.31, -0.82,  0.36)
  );
#endif

// Returns occlusion in 0..1 (1 = fully occluded)
float computeSSAO(vec3 viewPos, vec3 viewNormal, mat4 proj) {
#if ENABLE_SSAO == 0
    return 0.0;
#else
    // SSAO_RADIUS and SSAO_BIAS come from settings.glsl (guaranteed defined)
    float radius = SSAO_RADIUS;
    float bias   = SSAO_BIAS;

    // Build tangent basis from view normal
    vec3 N = viewNormal;
    vec3 T = normalize(cross(N, abs(N.y) > 0.99 ? vec3(1, 0, 0) : vec3(0, 1, 0)));
    vec3 B = cross(N, T);
    mat3 TBN = mat3(T, B, N);

    float ig = interleavedGradientNoise(gl_FragCoord.xy);
    float theta = ig * TAU;
    float s = sin(theta), c = cos(theta);
    mat2 rot = mat2(c, -s, s, c);

    float occlusion = 0.0;
    float totalWeight = 0.0;

#if SSAO_SAMPLES >= 16
    for (int i = 0; i < 16; i++) {
        vec3 sampleDir = TBN * ssaoSamples16[i];
        sampleDir.xy = rot * sampleDir.xy;
        vec3 samplePos = viewPos + sampleDir * radius;

        vec4 offset = proj * vec4(samplePos, 1.0);
        offset.xyz /= offset.w;
        vec2 sampleUV = offset.xy * 0.5 + 0.5;
        if (any(lessThan(sampleUV, vec2(0.0))) ||
            any(greaterThan(sampleUV, vec2(1.0)))) continue;

        float sampleDepth = texture(depthtex0, sampleUV).r * 2.0 - 1.0;
        vec4 sampleView4 = gbufferProjectionInverse * vec4(offset.xy, sampleDepth, 1.0);
        vec3 sampleView = sampleView4.xyz / sampleView4.w;

        float rangeCheck = smoothstep(1.0, 0.0, abs(viewPos.z - sampleView.z) / radius);
        occlusion += (sampleView.z >= samplePos.z + bias ? 1.0 : 0.0) * rangeCheck;
        totalWeight += 1.0;
    }
#elif SSAO_SAMPLES >= 8
    for (int i = 0; i < 8; i++) {
        vec3 sampleDir = TBN * ssaoSamples8[i];
        sampleDir.xy = rot * sampleDir.xy;
        vec3 samplePos = viewPos + sampleDir * radius;

        vec4 offset = proj * vec4(samplePos, 1.0);
        offset.xyz /= offset.w;
        vec2 sampleUV = offset.xy * 0.5 + 0.5;
        if (any(lessThan(sampleUV, vec2(0.0))) ||
            any(greaterThan(sampleUV, vec2(1.0)))) continue;

        float sampleDepth = texture(depthtex0, sampleUV).r * 2.0 - 1.0;
        vec4 sampleView4 = gbufferProjectionInverse * vec4(offset.xy, sampleDepth, 1.0);
        vec3 sampleView = sampleView4.xyz / sampleView4.w;

        float rangeCheck = smoothstep(1.0, 0.0, abs(viewPos.z - sampleView.z) / radius);
        occlusion += (sampleView.z >= samplePos.z + bias ? 1.0 : 0.0) * rangeCheck;
        totalWeight += 1.0;
    }
#else
    for (int i = 0; i < 4; i++) {
        vec3 sampleDir = TBN * ssaoSamples4[i];
        sampleDir.xy = rot * sampleDir.xy;
        vec3 samplePos = viewPos + sampleDir * radius;

        vec4 offset = proj * vec4(samplePos, 1.0);
        offset.xyz /= offset.w;
        vec2 sampleUV = offset.xy * 0.5 + 0.5;
        if (any(lessThan(sampleUV, vec2(0.0))) ||
            any(greaterThan(sampleUV, vec2(1.0)))) continue;

        float sampleDepth = texture(depthtex0, sampleUV).r * 2.0 - 1.0;
        vec4 sampleView4 = gbufferProjectionInverse * vec4(offset.xy, sampleDepth, 1.0);
        vec3 sampleView = sampleView4.xyz / sampleView4.w;

        float rangeCheck = smoothstep(1.0, 0.0, abs(viewPos.z - sampleView.z) / radius);
        occlusion += (sampleView.z >= samplePos.z + bias ? 1.0 : 0.0) * rangeCheck;
        totalWeight += 1.0;
    }
#endif

    if (totalWeight < 1.0) return 0.0;
    return occlusion / totalWeight;
#endif
}

// Convert raw occlusion (0..1) into a soft AO multiplier for shading
float aoToMultiplier(float occlusion) {
    return mix(1.0, 0.55, clamp01(occlusion) * AO_STRENGTH);
}

#endif // AURORA_SSAO_GLSL
