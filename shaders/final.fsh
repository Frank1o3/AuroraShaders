#version 460 core
// =====================================================================
// Aurora Shaders - final.fsh
// Final post-processing pass:
//   1. FXAA antialiasing (operates on HDR linear scene)
//   2. Tone map (ACES Filmic, Hill variant)
//   3. Color grading (saturation, contrast)
//   4. Subtle vignette
//   5. sRGB encode
// Output is the final image written to the back buffer.
// colortex0/1 are declared in common.glsl — do not redeclare.
// =====================================================================

#include "lib/common.glsl"
#include "lib/tonemap.glsl"
#include "lib/fxaa.glsl"

layout (location = 0) out vec4 outColor;

in vec2 v_TexCoord;

void main() {
    vec2 uv = v_TexCoord;
    vec2 invRes = 1.0 / vec2(viewWidth, viewHeight);

    // 1) Sample the HDR scene (post-bloom, post-god-rays from composite3).
    //    Exposure was already baked in by composite2, so we do NOT re-apply.
    vec3 scene = texture(colortex0, uv).rgb;

    // 2) FXAA on the HDR linear scene. FXAA's luma-based edge detection
    //    works correctly in linear HDR space; the algorithm is tone-map
    //    agnostic as long as we feed it consistent luma values.
    vec3 aa = fxaa(colortex0, gl_FragCoord.xy, invRes);

    // 3) Tone map the AA'd image. Doing AA before tonemap avoids the
    //    "halo along bright edges" artefact that occurs when you tonemap
    //    first and then AA — sharp HDR discontinuities get blurred in
    //    LDR space and produce visible ringing.
    vec3 tonemapped = acesTonemapHill(aa);

    // 4) Color grade (subtle — just a touch of saturation & contrast)
    tonemapped = colorGrade(tonemapped, SATURATION, CONTRAST, 1.0);
    tonemapped = clamp01(tonemapped);

    // 5) Subtle vignette
    tonemapped = applyVignette(tonemapped, uv);
    tonemapped = clamp01(tonemapped);

    // 6) Encode to sRGB for display
    vec3 srgb = linearToSRGB(tonemapped);

    outColor = vec4(srgb, 1.0);
}
