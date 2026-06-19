#version 460 core
// =====================================================================
// Aurora Shaders - composite4.fsh
// Pass-through (reserved for future volumetric cloud pass).
// colortex0 is declared in common.glsl — do not redeclare.
// =====================================================================

#include "../lib/common.glsl"

layout (location = 0) out vec4 outColor;

in vec2 v_TexCoord;

void main() {
    outColor = texture(colortex0, v_TexCoord);
}
