#version 460 compatibility
// =====================================================================
// Aurora Shaders - gbuffers_water.fsh
// Writes water/stained glass with PBR-ish attributes for the
// composite pass to refract & reflect.
// =====================================================================

#include "../lib/common.glsl"

layout (location = 0) out vec4 outAlbedo;
layout (location = 1) out vec4 outNormal;
layout (location = 2) out vec4 outMaterial;

in vec2  v_TexCoord;
in vec2  v_LightCoord;
in vec3  v_Normal;
in vec3  v_WorldPos;
in vec3  v_ViewPos;
in vec3  v_ModelPos;
in float v_BlockId;
in vec4  v_VertexColor;

layout(binding = 0) uniform sampler2D gtexture;

// Procedural water normal perturbation in tangent space (cheap)
vec2 waterPerturb(vec2 uv, float t) {
    float a = sin(uv.x * 6.0 + t * 1.4) * 0.10;
    float b = sin(uv.y * 5.5 + t * 1.7) * 0.10;
    return vec2(a, b);
}

void main() {
    vec4 texColor = texture(gtexture, v_TexCoord);
    if (texColor.a < 0.05) discard;

    vec3 albedo = sRGBToLinear(texColor.rgb * v_VertexColor.rgb);

    vec3 N = normalize(v_Normal);

    // Water gets a procedural wavy normal
    if (v_BlockId == MAT_WATER) {
        vec2 p = waterPerturb(v_TexCoord, frameTimeCounter);
        N = normalize(N + vec3(p.x, 0.0, p.y) * 0.35);

        // Slight transparency hint for composite pass
        albedo *= 0.85;
    }

    // Stained glass stays bright
    if (v_BlockId == 95.0) {
        albedo = albedo * 0.9 + vec3(0.05);
    }

    outAlbedo   = vec4(albedo, texColor.a);
    outNormal   = vec4(N * 0.5 + 0.5, v_BlockId / 255.0);
    outMaterial = vec4(v_LightCoord, 0.02, 0.0); // smooth for water
}
