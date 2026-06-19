#version 460 core
// =====================================================================
// Aurora Shaders - world-1 (Nether) / composite.fsh
// Nether has no sun. Strong ambient + sky-tinted fog + emissive glow.
// NOTE: paths are relative to this file, so we use ../lib/...
// =====================================================================

#include "../lib/common.glsl"
#include "../lib/lighting.glsl"
#include "../lib/ssao.glsl"
#include "../lib/fog.glsl"

layout (location = 0) out vec4 outColor;
layout (location = 1) out vec4 outSSAO;
layout (location = 2) out vec4 outBloom;

in vec2 v_TexCoord;

vec3 reconstructViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

void main() {
    vec2 uv = v_TexCoord;
    float depth = texture(depthtex0, uv).r;

    if (depth >= 1.0) {
        // Nether sky - warm orange-red haze
        outColor = vec4(vec3(0.30, 0.08, 0.04), 1.0);
        outSSAO = vec4(1.0);
        outBloom = vec4(0.0);
        return;
    }

    vec4 albedoSample = texture(colortex0, uv);
    vec4 normalSample = texture(colortex1, uv);
    vec4 matSample    = texture(colortex2, uv);

    vec3 albedo = albedoSample.rgb;
    vec3 Nview = normalize(normalSample.rgb * 2.0 - 1.0);
    int matId = int(normalSample.a * 255.0 + 0.5);
    float torchLight = matSample.r;
    float skyLight   = matSample.g;
    float roughness  = matSample.b;
    float emissive   = matSample.a;

    vec3 viewPos = reconstructViewPos(uv, depth);
    // Strong ambient (no directional light in nether)
    float occlusion = computeSSAO(viewPos, Nview, gbufferProjection);
    float aoMult = aoToMultiplier(occlusion);
    float ao = 1.0 - occlusion * 0.5;

    vec3 ambient = vec3(0.45, 0.18, 0.10) * albedo * ao;
    vec3 blockL  = blockLightColor(torchLight) * albedo;

    vec3 lit = ambient + blockL;
    lit *= aoMult;
    if (emissive > 0.01 || matId == MAT_LAVA || matId == MAT_EMISSIVE) {
        lit += albedo * 2.5;
    }

    // Heavy warm fog
    lit = applyDistanceFog(lit, viewPos, normalize(viewPos));

    outColor = vec4(lit, 1.0);
    outSSAO = vec4(ao, 0.0, 0.0, 1.0);
    outBloom = vec4(max(lit - bloomThreshold, 0.0) * BLOOM_STRENGTH, 1.0);
}
