#version 460 compatibility
// =====================================================================
// Aurora Shaders - gbuffers_skybasic.vsh
// Sky geometry: passes through vertices (sun/moon/stars discs).
// =====================================================================

#include "../lib/common.glsl"

out vec2 v_TexCoord;
out vec4 v_VertexColor;

void main() {
    v_TexCoord = gl_MultiTexCoord0.st;
    v_VertexColor = gl_Color;
    gl_Position = ftransform();
}
