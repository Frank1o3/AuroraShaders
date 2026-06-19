#version 460 core
// =====================================================================
// Aurora Shaders - composite3.fsh
// Pass 4: volumetric light shafts (cheap screen-space god rays).
// colortex0 + depthtex0 are declared in common.glsl — do not redeclare.
// =====================================================================

#include "../lib/common.glsl"
#include "../lib/lighting.glsl"
// getSunLightColor, daylightFactor

layout (location = 0) out vec4 outColor;

in vec2 v_TexCoord;

// Cheap screen-space god rays: 16 radial samples toward the sun.
vec3 screenSpaceGodRays(vec2 uv, vec2 sunScreenPos) {
    if (any(lessThan(sunScreenPos, vec2(-0.1))) ||
        any(greaterThan(sunScreenPos, vec2(1.1)))) return vec3(0.0);

    const int SAMPLES = 16;
    vec2 deltaUV = (sunScreenPos - uv) / float(SAMPLES);
    vec2 curUV = uv;
    float illumDecay = 1.0;

    vec3 color = vec3(0.0);
    for (int i = 0; i < SAMPLES; i++) {
        curUV += deltaUV;
        float depth = texture(depthtex0, curUV).r;
        // Sample only sky pixels (depth = 1.0)
        if (depth >= 1.0) {
            vec3 c = texture(colortex0, curUV).rgb;
            color += c * illumDecay * 0.04;
        }
        illumDecay *= 0.92;
    }
    return color;
}

// Project a world-space direction to screen UV
vec2 projectDirectionToScreen(vec3 dir) {
    vec4 view = gbufferModelView * vec4(dir * 1000.0, 1.0);
    vec4 clip = gbufferProjection * view;
    vec3 ndc = clip.xyz / clip.w;
    return ndc.xy * 0.5 + 0.5;
}

void main() {
    vec2 uv = v_TexCoord;
    vec3 scene = texture(colortex0, uv).rgb;

    // Sun screen-space position
    vec3 sunDir = normalize(shadowLightPosition);
    vec2 sunUV = projectDirectionToScreen(sunDir);

    // Soft god rays - only meaningful during day with visible sky
    float day = daylightFactor();
    if (day > 0.1) {
        vec3 rays = screenSpaceGodRays(uv, sunUV);
        scene += rays * day * 0.6 * getSunLightColor();
    }

    outColor = vec4(scene, 1.0);
}
