#version 460 core
// =====================================================================
// Aurora Shaders - composite1.fsh
// Pass 2: cheap bloom blur (separable Gaussian, 9-tap, horizontal).
// Reads colortex2 (bloom bright pass from composite.fsh).
// Writes the horizontally-blurred bloom BACK to colortex2 so that
// colortex0 (the lit scene) is preserved for composite2.
// =====================================================================

#include "../lib/common.glsl"

layout (location = 0) out vec4 outScene;     // colortex0 - passthrough of lit scene
layout (location = 2) out vec4 outBloomBlur; // colortex2 - horizontally blurred bloom

in vec2 v_TexCoord;

// 9-tap Gaussian weights (separable)
const float weights[5] = float[5](
    0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216
);

void main() {
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    vec2 uv = v_TexCoord;

    // Horizontal blur of the bloom bright pass (from colortex2)
    vec3 sum = texture(colortex2, uv).rgb * weights[0];
    for (int i = 1; i < 5; i++) {
        sum += texture(colortex2, uv + vec2(texel.x * float(i), 0.0)).rgb * weights[i];
        sum += texture(colortex2, uv - vec2(texel.x * float(i), 0.0)).rgb * weights[i];
    }

    // Pass through the lit scene unchanged on colortex0
    outScene = texture(colortex0, uv);

    // Write the horizontally-blurred bloom to colortex2
    outBloomBlur = vec4(sum, 1.0);
}
