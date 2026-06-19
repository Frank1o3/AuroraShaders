#version 460 compatibility
// =====================================================================
// Aurora Shaders - gbuffers_water.vsh
// Transparent geometry (water, stained glass, ice).
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
out vec3  v_ModelPos;

void main() {
    v_TexCoord   = gl_MultiTexCoord0.st;
    v_LightCoord = gl_MultiTexCoord1.st / 240.0;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    v_ViewPos = viewPos.xyz;
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    v_WorldPos = worldPos.xyz + cameraPosition;
    v_ModelPos = worldPos.xyz;

    v_Normal = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal);
    v_BlockId = mc_Entity.x;
    v_VertexColor = gl_Color;
    gl_Position = gbufferProjection * viewPos;

    // Animated water surface
    if (mc_Entity.x == MAT_WATER && WAVING_FOLIAGE == 1) {
        float t = frameTimeCounter * 0.8;
        float wave = sin(worldPos.x * 0.45 + t) * 0.5 + cos(worldPos.z * 0.55 + t * 1.2) * 0.5;
        gl_Position.y += wave * 0.025;
    }
}
