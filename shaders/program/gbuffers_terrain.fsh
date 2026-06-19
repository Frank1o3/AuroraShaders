#version 460 compatibility
// =====================================================================
// Aurora Shaders - gbuffers_terrain.fsh
// Fills the G-buffer with albedo, normal, material id, lightmap,
// and a roughness/metallic approximation per block.
// =====================================================================

#include "../lib/common.glsl"
#include "../lib/lighting.glsl"

layout (location = 0) out vec4 outAlbedo;     // colortex0
layout (location = 1) out vec4 outNormal;     // colortex1
layout (location = 2) out vec4 outMaterial;   // colortex2

in vec2  v_TexCoord;
in vec2  v_LightCoord;
in vec3  v_Normal;
in vec4  v_Tangent;
in vec3  v_WorldPos;
in vec3  v_ViewPos;
in float v_BlockId;
in vec4  v_VertexColor;

layout(binding = 0) uniform sampler2D gtexture;
layout(binding = 2) uniform sampler2D gnormals;
layout(binding = 3) uniform sampler2D gspecular;

// ---------------------------------------------------------------------
// Map block IDs to (roughness, metallic, emissive) without textures.
// Cheap, stable, and works for any resource pack.
// ---------------------------------------------------------------------
vec3 getMaterialForBlock(float blockId) {
    // returns vec3(roughness, metallic, emissiveStrength)
    if (blockId == MAT_WATER)     return vec3(0.02, 0.0, 0.0);
    if (blockId == MAT_LAVA)      return vec3(0.50, 0.0, 1.5);
    if (blockId == MAT_LEAVES)    return vec3(0.85, 0.0, 0.0);
    if (blockId == MAT_GRASS)     return vec3(0.90, 0.0, 0.0);
    if (blockId == MAT_FOLIAGE)   return vec3(0.90, 0.0, 0.0);
    if (blockId == MAT_SAND)      return vec3(0.85, 0.0, 0.0);
    if (blockId == MAT_METAL)     return vec3(0.30, 1.0, 0.0);
    if (blockId == MAT_EMISSIVE)  return vec3(0.50, 0.0, 1.8);
    return vec3(0.75, 0.0, 0.0);
}

void main() {
    vec4 texColor = texture(gtexture, v_TexCoord);
    if (texColor.a < 0.1) discard;

    // Apply baked vanilla AO from vertex color
    vec3 albedo = texColor.rgb * v_VertexColor.rgb;

    // Linearize albedo (assume resource packs provide sRGB textures)
    albedo = sRGBToLinear(albedo);

    // Normal: use tangent space if available, else model normal
    vec3 N = normalize(v_Normal);
    if (length(v_Tangent.xyz) > 0.5) {
        vec3 T = normalize(gl_NormalMatrix * v_Tangent.xyz);
        vec3 B = cross(N, T) * v_Tangent.w;
        mat3 TBN = mat3(T, B, N);

        // Sample tangent-space normal if available
        vec3 normalMap = texture(gnormals, v_TexCoord).xyz * 2.0 - 1.0;
        if (length(normalMap) > 0.1) {
            N = normalize(TBN * normalize(normalMap));
        }
    }

    // Material params
    vec3 matData = getMaterialForBlock(v_BlockId);
    float roughness = matData.x;
    float metallic  = matData.y;
    float emissive  = matData.z;

    // Try sampling lab-pbr specular map (R=smoothness, G=emissive, B=porosity, A=metalness)
    vec4 specSample = texture(gspecular, v_TexCoord);
    if (length(specSample) > 0.01) {
        roughness = 1.0 - specSample.r;
        metallic  = specSample.a;
        emissive  = specSample.g * 2.0;
    }

    // Encode N to 0..1
    vec3 normalEnc = N * 0.5 + 0.5;

    // Pack lightmap + roughness into colortex2
    vec2 lm = v_LightCoord;

    // Outputs
    outAlbedo   = vec4(albedo, 1.0);
    outNormal   = vec4(normalEnc, v_BlockId / 255.0);
    outMaterial = vec4(lm, roughness, emissive);

    // For water, alpha tells composite pass to skip writing depth & do refraction
    if (v_BlockId == MAT_WATER) {
        outAlbedo.a = 0.6;
    }
}
