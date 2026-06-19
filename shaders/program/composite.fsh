#version 460 core
// =====================================================================
// Aurora Shaders - composite.fsh
// Pass 1: Deferred lighting + soft shadows + SSAO + simple bounce.
// Reads the G-buffer, writes the lit HDR scene color.
// =====================================================================

#include "../lib/common.glsl"
#include "../lib/lighting.glsl"
#include "../lib/ssao.glsl"
#include "../lib/fog.glsl"
#include "../lib/clouds.glsl"

layout (location = 0) out vec4 outColor;     // colortex0 - lit scene
layout (location = 1) out vec4 outSSAO;      // colortex1 - AO buffer
layout (location = 2) out vec4 outBloom;     // colortex2 - bloom bright pass

in vec2 v_TexCoord;

// ---------------------------------------------------------------------
// Reconstruct view-space position from a depth sample + UV.
// (Local to this stage; not shared.)
// ---------------------------------------------------------------------
vec3 reconstructViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

vec3 reconstructWorldPos(vec2 uv, float depth) {
    vec3 viewPos = reconstructViewPos(uv, depth);
    vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
    return worldPos.xyz + cameraPosition;
}

void main() {
    vec2 uv = v_TexCoord;

    float depth = texture(depthtex0, uv).r;
    bool isSky = depth >= 1.0;

    if (isSky) {
        // Sky color for background
        vec3 viewDir = normalize(reconstructViewPos(uv, 1.0));
        vec3 sky = getSkyColor(viewDir);

        sky = applyProceduralClouds(sky, viewDir);
        sky += getSunSkyAdd(viewDir);
        sky += getMoonSkyAdd(viewDir);
        sky += getStarField(viewDir);

        outColor  = vec4(sky, 1.0);
        outSSAO   = vec4(1.0);
        outBloom  = vec4(max(sky - bloomThreshold, 0.0) * BLOOM_STRENGTH, 1.0);
        return;
    }

    // Sample G-buffer
    vec4 albedoSample = texture(colortex0, uv);
    vec4 normalSample = texture(colortex1, uv);
    vec4 matSample    = texture(colortex2, uv);

    vec3 albedo = albedoSample.rgb;
    vec3 Nview = normalize(normalSample.rgb * 2.0 - 1.0);
    vec3 Nworld = normalize(mat3(gbufferModelViewInverse) * Nview);
    int  matId = int(normalSample.a * 255.0 + 0.5);
    float torchLight = matSample.r;  // block light (normalized 0-1)
    float skyLight   = matSample.g;  // sky light (normalized 0-1, encodes day/night)
    float materialRoughness  = matSample.b;
    float emissive   = matSample.a;

    // Reconstruct positions
    vec3 viewPos  = reconstructViewPos(uv, depth);
    vec3 worldPos = reconstructWorldPos(uv, depth);
    vec3 V = normalize(mat3(gbufferModelViewInverse) * normalize(-viewPos));

    // SSAO
    float occlusion = computeSSAO(viewPos, Nview, gbufferProjection);
    float aoMult = aoToMultiplier(occlusion);
    float ao = 1.0 - occlusion * 0.5;

    // Lighting
    float metallic = (matId == MAT_METAL) ? 1.0 : 0.0;
    vec3 lit = shadeSurface(albedo, Nworld, V, worldPos,
                            materialRoughness, metallic, ao,
                            torchLight, skyLight, matId);

    // Apply vanilla AO baked into vertex colors (subtle)
    lit *= aoMult;

    // Emissive boost
    if (emissive > 0.01) {
        lit += albedo * emissive;
    }

    // Fog
    vec3 viewDir = normalize(viewPos);
    lit = applyDistanceFog(lit, viewPos, viewDir);
    lit = applyHorizonHaze(lit, viewDir, viewPos);
    lit = applyRainFog(lit, viewDir, viewPos);

    // Water refraction tint when eye is in water
    if (isEyeInWater == 1) {
        lit *= vec3(0.7, 0.85, 1.0);
        lit = mix(lit, lit * vec3(0.5, 0.8, 1.0), 0.3);
    }

    outColor  = vec4(lit, 1.0);
    outSSAO   = vec4(ao, 0.0, 0.0, 1.0);
    outBloom  = vec4(max(lit - bloomThreshold, 0.0) * BLOOM_STRENGTH, 1.0);
}
