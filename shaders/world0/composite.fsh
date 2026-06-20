#version 460 core
// =====================================================================
// Aurora Shaders - world0 (Overworld) / composite.fsh
// Standard overworld lighting with sun/moon, sky ambient, procedural sky.
// =====================================================================

#include "../lib/common.glsl"
#include "../lib/lighting.glsl"
#include "../lib/ssao.glsl"
#include "../lib/fog.glsl"
#include "../lib/clouds.glsl"

layout (location = 0) out vec4 outColor;
layout (location = 1) out vec4 outSSAO;
layout (location = 2) out vec4 outBloom;

in vec2 v_TexCoord;

vec3 reconstructViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

vec3 reconstructSkyDir(vec2 uv) {
    vec4 clip = vec4(uv * 2.0 - 1.0, 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return normalize(view.xyz);
}

void main() {
    vec2 uv = v_TexCoord;
    float depth = texture(depthtex0, uv).r;

    // Sky handling: procedural sky (Iris clears colortex0 before gbuffers)
    if (depth >= 1.0) {
        vec3 viewDir = reconstructSkyDir(uv);
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
    int matId = int(normalSample.a * 255.0 + 0.5);
    // Lightmap coords are now normalized to 0-1 (done in vertex shader)
    float torchLight = matSample.r;  // block light (torches, glowstone)
    float skyLight   = matSample.g;  // sky light (already encodes day/night)
    float materialRoughness  = matSample.b;
    float emissive   = matSample.a;

    vec3 viewPos = reconstructViewPos(uv, depth);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 V = normalize(-viewPos);

    // SSAO
    float occlusion = computeSSAO(viewPos, Nview, gbufferProjection);
    float aoMult = aoToMultiplier(occlusion);
    float ao = 1.0 - occlusion * 0.5;

    // Precalculate uniform-based lighting values once per fragment
    float day = horizonDayFactor();
    vec3 activeLight = getActiveLightColor();
    vec3 skyAmbient = getSkyAmbientColor(day);

    float metallic = (matId == MAT_METAL) ? 1.0 : 0.0;
    vec3 lit = shadeSurface(albedo, Nview, V, worldPos, materialRoughness, metallic, ao, torchLight, skyLight, matId, day, activeLight, skyAmbient);
    lit *= mix(1.0, aoMult, 0.45);

    // Emissive materials (lava, glowstone, custom emissive blocks)
    if (emissive > 0.01 || matId == MAT_LAVA || matId == MAT_EMISSIVE) {
        lit += albedo * 2.5;
    }

    // Apply distance fog
    lit = applyDistanceFog(lit, viewPos, normalize(viewPos));

    // Output
    outColor = vec4(lit, 1.0);
    outSSAO = vec4(ao, 0.0, 0.0, 1.0);
    outBloom = vec4(max(lit - bloomThreshold, 0.0) * BLOOM_STRENGTH, 1.0);
}
