#version 460 compatibility
// =====================================================================
// Aurora Shaders - gbuffers_hand.vsh
// =====================================================================

#include "../lib/common.glsl"

out vec2 v_TexCoord;
out vec2 v_LightCoord;
out vec3 v_Normal;
out vec3 v_WorldPos;
out vec3 v_ViewPos;
out vec4 v_VertexColor;

void main() {
    v_TexCoord   = gl_MultiTexCoord0.st;
    v_LightCoord = gl_MultiTexCoord1.st / 240.0;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    v_ViewPos = viewPos.xyz;
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    v_WorldPos = worldPos.xyz + cameraPosition;
    v_Normal = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal);
    v_VertexColor = gl_Color;
    gl_Position = gbufferProjection * viewPos;
}
