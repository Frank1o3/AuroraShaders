#version 460 core
// =====================================================================
// Aurora Shaders - composite2.fsh
// Pass 3: vertical bloom blur + additive blend back into scene color +
// eye-adapted exposure. Outputs the lit+bloom scene ready for tone map.
// colortex0/1/2/3 are declared in common.glsl — do not redeclare.
// =====================================================================

#include "../lib/common.glsl"
#include "../lib/tonemap.glsl"
// computeAdaptedExposure lives here

layout (location = 0) out vec4 outColor;    // scene + bloom, exposure applied
layout (location = 1) out vec4 outExposure; // adapted exposure feedback

in vec2 v_TexCoord;

const float weights[5] = float[5](
    0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216
);

void main() {
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    vec2 uv = v_TexCoord;

    // Vertical blur of bloom
    vec3 bloom = texture(colortex2, uv).rgb * weights[0];
    for (int i = 1; i < 5; i++) {
        bloom += texture(colortex2, uv + vec2(0.0, texel.y * float(i))).rgb * weights[i];
        bloom += texture(colortex2, uv - vec2(0.0, texel.y * float(i))).rgb * weights[i];
    }

    vec3 scene = texture(colortex0, uv).rgb;

    // Add bloom back into scene with mild luminance scaling
    scene += bloom * 0.7;

    // Eye-adapted exposure: read previous frame's exposure from colortex3
    // (we sample the centre pixel — Iris keeps colortex3 persistent between
    //  composite passes, so the value written last frame is what we read here).
    float lum = luminance(scene);
    float prevExposure = texture(colortex3, vec2(0.5)).r;
    if (prevExposure <= 0.0) prevExposure = 1.0;

    float exposure = computeAdaptedExposure(lum, prevExposure, frameTime);

    outColor    = vec4(scene * exposure, 1.0);
    outExposure = vec4(exposure, 0.0, 0.0, 1.0);
}
