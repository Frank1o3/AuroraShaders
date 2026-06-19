#version 460 core
// =====================================================================
// Aurora Shaders - world1 (End) / composite.fsh
// End: dim ambient, no directional sun, deep purple sky tint.
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
        outColor = vec4(vec3(0.04, 0.02, 0.08), 1.0);
        outSSAO = vec4(1.0);
        outBloom = vec4(0.0);
        return;
    }

    vec4 albedoSample = texture(colortex0, uv);
    vec4 normalSample = texture(colortex1, uv);
    vec4 matSample    = texture(colortex2, uv);

    vec3 albedo = albedoSample.rgb;
    vec3 N = normalSample.rgb * 2.0 - 1.0;
    int matId = int(normalSample.a * 255.0 + 0.5);
    float torchLight = matSample.r;
    float skyLight   = matSample.g;
    float emissive   = matSample.a;

    vec3 viewPos = reconstructViewPos(uv, depth);
    vec3 V = normalize(-viewPos);

    float occlusion = computeSSAO(viewPos, N, gbufferProjection);
    float ao = 1.0 - occlusion * 0.5;

    // Dim cool ambient + torch light
    vec3 ambient = vec3(0.10, 0.10, 0.18) * albedo * ao;
    vec3 blockL  = blockLightColor(torchLight) * albedo;

    vec3 lit = ambient + blockL;
    if (emissive > 0.01 || matId == MAT_EMISSIVE) {
        lit += albedo * 2.0;
    }

    lit = applyDistanceFog(lit, viewPos, normalize(viewPos));

    outColor = vec4(lit, 1.0);
    outSSAO = vec4(ao, 0.0, 0.0, 1.0);
    outBloom = vec4(max(lit - BLOOM_THRESHOLD, 0.0) * BLOOM_STRENGTH, 1.0);
}
