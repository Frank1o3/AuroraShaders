#version 460 core
// =====================================================================
// Aurora Shaders - world0 (Overworld) / composite.fsh
// Standard overworld lighting with sun/moon, sky ambient, procedural sky.
// =====================================================================

#include "../lib/common.glsl"
#include "../lib/lighting.glsl"
#include "../lib/ssao.glsl"
#include "../lib/fog.glsl"

layout (location = 0) out vec4 outColor;
layout (location = 1) out vec4 outSSAO;
layout (location = 2) out vec4 outBloom;

in vec2 v_TexCoord;

vec3 reconstructViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

void main() {
    vec2 uv = v_TexCoord;
    float depth = texture(depthtex0, uv).r;

    // Sky handling: procedural sky (Iris clears colortex0 before gbuffers)
    if (depth >= 1.0) {
        vec3 viewDir = normalize(reconstructViewPos(uv, 1.0));
        vec3 sky = getSkyColor(viewDir);

        // Sun glow (bright disc + halo)
        vec3 sunDir = normalize(sunPosition);
        float sunDot = clamp01(dot(viewDir, sunDir));
        sky += getSunLightColor() * pow(sunDot, 256.0);
        sky += getSunLightColor() * pow(sunDot, 8.0) * 0.15;

        // Moon glow (only at night)
        if (moonlightFactor() > 0.3) {
            vec3 moonDir = normalize(moonPosition);
            float moonDot = clamp01(dot(viewDir, moonDir));
            sky += getMoonLightColor() * pow(moonDot, 256.0) * 6.0;
            sky += getMoonLightColor() * pow(moonDot, 8.0) * 0.4;
        }

        // Stars (cheap procedural)
        if (moonlightFactor() > 0.2) {
            float starHash = fract(sin(dot(viewDir.xy * 200.0, vec2(12.9898, 78.233))) * 43758.5453);
            sky += vec3(starHash) * pow(starHash, 32.0) * 2.0 * moonlightFactor();
        }

        // Blend with vanilla clouds if present.
        // Iris renders clouds into colortex0 before this composite pass.
        // Cloud pixels have non-zero alpha; sky pixels have alpha=0.
        vec4 cloudSample = texture(colortex0, uv);
        if (cloudSample.a > 0.01) {
            sky = mix(sky, cloudSample.rgb, cloudSample.a);
        }

        outColor  = vec4(sky, 1.0);
        outSSAO   = vec4(1.0);
        outBloom  = vec4(max(sky - BLOOM_THRESHOLD, 0.0) * BLOOM_STRENGTH, 1.0);
        return;
    }

    // Sample G-buffer
    vec4 albedoSample = texture(colortex0, uv);
    vec4 normalSample = texture(colortex1, uv);
    vec4 matSample    = texture(colortex2, uv);

    vec3 albedo = albedoSample.rgb;
    vec3 N = normalSample.rgb * 2.0 - 1.0;
    int matId = int(normalSample.a * 255.0 + 0.5);
    // Lightmap coords are now normalized to 0-1 (done in vertex shader)
    float torchLight = matSample.r;  // block light (torches, glowstone)
    float skyLight   = matSample.g;  // sky light (already encodes day/night)
    float roughness  = matSample.b;
    float emissive   = matSample.a;

    vec3 viewPos = reconstructViewPos(uv, depth);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
    vec3 V = normalize(-viewPos);

    // SSAO
    float occlusion = computeSSAO(viewPos, N, gbufferProjection);
    float ao = 1.0 - occlusion * 0.5;

    // ---- Lighting ----
    // skyLight from the vanilla lightmap already encodes time-of-day:
    //   - During day, skyLight is high for blocks exposed to sky
    //   - During night, skyLight is automatically reduced by the game
    //   - Underground/caves, skyLight is 0
    // We use skyLight to drive both ambient and directional intensity.

    // 1. Sky Ambient — blue sky tint, modulated by skyLight so it's dark at night/caves
    float day = daylightFactor();
    vec3 skyAmbientColor = mix(
        vec3(0.10, 0.12, 0.20),  // night ambient (dim blue)
        vec3(0.55, 0.70, 1.00),  // day ambient (bright blue)
        day
    );
    vec3 ambient = skyAmbientColor * skyLight * albedo * ao;

    // 2. Block Light (torches, glowstone, etc.) — warm point light
    vec3 blockL = blockLightColor(torchLight) * albedo;

    // 3. Directional Sun/Moon Light
    // shadowLightPosition points to the sun during day, moon at night
    vec3 L = normalize(shadowLightPosition + vec3(0.0001));

    // Soft diffuse wrapping (half-Lambert)
    float wrap = 0.2;
    float diffuse = max(0.0, (dot(N, L) + wrap) / (1.0 + wrap));

    // Sun/moon color changes with time of day
    vec3 sunColor = mix(
        vec3(0.30, 0.40, 0.70) * 0.15,  // moonlight (dim cool blue)
        vec3(1.00, 0.95, 0.85) * 1.2,   // sunlight (warm bright)
        day
    );
    // Directional light only affects blocks that have sky exposure
    vec3 dirLight = sunColor * diffuse * skyLight * albedo;

    // Combine lighting
    vec3 lit = ambient + blockL + dirLight;

    // Emissive materials (lava, glowstone, custom emissive blocks)
    if (emissive > 0.01 || matId == MAT_LAVA || matId == MAT_EMISSIVE) {
        lit += albedo * 2.5;
    }

    // Apply distance fog
    lit = applyDistanceFog(lit, viewPos, normalize(viewPos));

    // Output
    outColor = vec4(lit, 1.0);
    outSSAO = vec4(ao, 0.0, 0.0, 1.0);
    outBloom = vec4(max(lit - BLOOM_THRESHOLD, 0.0) * BLOOM_STRENGTH, 1.0);
}
