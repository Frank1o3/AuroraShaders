#version 460 compatibility
// =====================================================================
// Aurora Shaders - gbuffers_entities.vsh
// =====================================================================

#include "../lib/common.glsl"

in vec3 mc_Entity;

out vec2  v_TexCoord;
out vec2  v_LightCoord;
out vec3  v_Normal;
out vec3  v_WorldPos;
out vec3  v_ViewPos;
out float v_BlockId;
out vec4  v_VertexColor;

void main() {
    v_TexCoord   = gl_MultiTexCoord0.st;
    v_LightCoord = max(gl_MultiTexCoord1.xy, vec2(0.001)) / 240.0;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    v_ViewPos = viewPos.xyz;
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    v_WorldPos = worldPos.xyz + cameraPosition;
    v_Normal = normalize(gl_NormalMatrix * gl_Normal);
    v_BlockId = mc_Entity.x;
    v_VertexColor = gl_Color;
    gl_Position = gbufferProjection * viewPos;
}
