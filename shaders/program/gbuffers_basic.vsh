#version 460 compatibility
// =====================================================================
// Aurora Shaders - gbuffers_basic.vsh
// Used for things like particles, simple quads, fire, etc.
// =====================================================================

#include "../lib/common.glsl"

out vec2 v_TexCoord;
out vec2 v_LightCoord;
out vec4 v_VertexColor;

void main() {
    v_TexCoord   = gl_MultiTexCoord0.st;
    v_LightCoord = gl_MultiTexCoord1.st / 240.0;
    v_VertexColor = gl_Color;
    gl_Position = ftransform();
}
