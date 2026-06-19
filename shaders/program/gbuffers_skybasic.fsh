#version 460 compatibility
// =====================================================================
// Aurora Shaders - gbuffers_skybasic.fsh
// Renders sun & moon disc with subtle glow.
// =====================================================================

#include "../lib/common.glsl"

layout (location = 0) out vec4 outAlbedo;
layout (location = 1) out vec4 outNormal;
layout (location = 2) out vec4 outMaterial;

in vec2 v_TexCoord;
in vec4 v_VertexColor;

layout(binding = 0) uniform sampler2D gtexture;

void main() {
    vec4 texColor = texture(gtexture, v_TexCoord);
    vec3 albedo = sRGBToLinear(texColor.rgb * v_VertexColor.rgb);

    // Sun = bright warm, moon = cool dim
    bool isSun = length(sunPosition) > 0.5;
    if (isSun) {
        albedo *= vec3(1.6, 1.2, 0.9) * 4.0;
    } else {
        albedo *= vec3(0.5, 0.6, 0.8) * 1.2;
    }

    outAlbedo   = vec4(albedo, texColor.a);
    outNormal   = vec4(0.5, 0.5, 1.0, MAT_EMISSIVE / 255.0);
    outMaterial = vec4(1.0, 1.0, 0.0, 1.0);
}
