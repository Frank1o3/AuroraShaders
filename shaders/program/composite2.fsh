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
layout (location = 3) out vec4 outExposure; // adapted exposure feedback

in vec2 v_TexCoord;

const float weights[5] = float[5](
    0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216
);

float luminanceSample(vec2 uv, float weight) {
    vec3 c = texture(colortex0, uv).rgb;
    float d = texture(depthtex0, uv).r;
    float skyWeight = (d >= 1.0) ? 0.18 : 1.0;
    return luminance(c) * weight * skyWeight;
}

float stableSceneLuminance() {
    float total = 0.0;
    float weight = 0.0;

    vec2 p0 = vec2(0.50, 0.50);
    vec2 p1 = vec2(0.38, 0.42);
    vec2 p2 = vec2(0.62, 0.42);
    vec2 p3 = vec2(0.42, 0.58);
    vec2 p4 = vec2(0.58, 0.58);
    vec2 p5 = vec2(0.30, 0.50);
    vec2 p6 = vec2(0.70, 0.50);
    vec2 p7 = vec2(0.50, 0.30);
    vec2 p8 = vec2(0.50, 0.70);

    total += luminanceSample(p0, 2.0); weight += 2.0;
    total += luminanceSample(p1, 1.0); weight += 1.0;
    total += luminanceSample(p2, 1.0); weight += 1.0;
    total += luminanceSample(p3, 1.0); weight += 1.0;
    total += luminanceSample(p4, 1.0); weight += 1.0;
    total += luminanceSample(p5, 0.6); weight += 0.6;
    total += luminanceSample(p6, 0.6); weight += 0.6;
    total += luminanceSample(p7, 0.6); weight += 0.6;
    total += luminanceSample(p8, 0.6); weight += 0.6;

    float avg = max(total / max(weight, 0.001), 0.0);
    return clamp(avg, 0.02, 8.0);
}

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
    float lum = stableSceneLuminance();
    float prevExposure = texture(colortex3, vec2(0.5)).r;
    if (prevExposure <= 0.0 || prevExposure > 8.0) prevExposure = 1.0;

    float exposure = computeAdaptedExposure(lum, prevExposure, frameTime);

    outColor    = vec4(scene * exposure, 1.0);
    outExposure = vec4(exposure, 0.0, 0.0, 1.0);
}
