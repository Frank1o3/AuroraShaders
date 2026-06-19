#version 460 compatibility
// =====================================================================
// Aurora Shaders - gbuffers_terrain.vsh
// Vertex shader for terrain blocks. Writes g-buffer attributes.
// =====================================================================

#include "../lib/common.glsl"

in vec3 mc_Entity;          // block id (Iris)
in vec2 mc_midTexCoord;     // mid texcoord (used for foliage mask)
in vec4 at_tangent;         // tangent space (xyz + sign)

out vec2  v_TexCoord;
out vec2  v_LightCoord;
out vec3  v_Normal;
out vec4  v_Tangent;
out vec3  v_WorldPos;
out vec3  v_ViewPos;
out float v_BlockId;
out vec4  v_VertexColor;

void main() {
    // Pass-through texture & lightmap coords
    v_TexCoord   = gl_MultiTexCoord0.st;
    // Minecraft lightmap UVs are in 0-240 range; normalize to 0-1
    v_LightCoord = max(gl_MultiTexCoord1.xy, vec2(0.001)) / 240.0;

    // Iris standard: gl_Normal is in model space, convert to view space
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    v_ViewPos = viewPos.xyz;

    // World position
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    v_WorldPos = worldPos.xyz + cameraPosition;

    // Normal (view space)
    v_Normal = normalize(gl_NormalMatrix * gl_Normal);

    // Tangent
    v_Tangent = at_tangent;

    // Block id from mc_Entity.x
    v_BlockId = mc_Entity.x;

    // Vertex color (vanilla AO baked into gl_Color)
    v_VertexColor = gl_Color;

    gl_Position = gbufferProjection * viewPos;

    // Slight waving for foliage
    bool isFoliage = (mc_Entity.x == MAT_LEAVES || mc_Entity.x == MAT_GRASS || mc_Entity.x == MAT_FOLIAGE);
    if (WAVING_FOLIAGE == 1 && isFoliage) {
        vec3 w = worldPos.xyz;
        float t = frameTimeCounter * 1.5;
        float sway = sin(w.x * 0.6 + t) * 0.5 + cos(w.z * 0.5 + t * 1.3) * 0.5;
        float amp = (mc_Entity.x == MAT_LEAVES) ? 0.05 : 0.035;
        gl_Position.y += sway * amp;
    }
}
