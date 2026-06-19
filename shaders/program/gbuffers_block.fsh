#version 460 compatibility
// =====================================================================
// Aurora Shaders - gbuffers_block.fsh
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
in float v_BlockId;
in vec4  v_VertexColor;

layout(binding = 0) uniform sampler2D gtexture;

void main() {
    vec4 texColor = texture(gtexture, v_TexCoord);
    if (texColor.a < 0.05) discard;

    vec3 albedo = sRGBToLinear(texColor.rgb * v_VertexColor.rgb);
    vec3 N = normalize(v_Normal);

    outAlbedo   = vec4(albedo, texColor.a);
    outNormal   = vec4(N * 0.5 + 0.5, MAT_DEFAULT / 255.0);
    outMaterial = vec4(v_LightCoord, 0.7, 0.0);
}
