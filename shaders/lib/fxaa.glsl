// =====================================================================
// Aurora Shaders - fxaa.glsl
// Lightweight FXAA 3.11 Quality - single pass post AA.
// Cheap, fast, runs on any GPU that hits 4.6.
// =====================================================================
#ifndef AURORA_FXAA_GLSL
#define AURORA_FXAA_GLSL

#include "common.glsl"

// FXAA 3.11 quality preset (low-medium, optimized)
#define FXAA_QUALITY_PRESET 12

#if (FXAA_QUALITY_PRESET == 12)
    #define FXAA_EDGE_THRESHOLD      (1.0/8.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/16.0)
    #define FXAA_SEARCH_STEPS        4
    #define FXAA_SEARCH_ACCELERATION 4
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_FASTER       1
    #define FXAA_SUBPIX              1
    #define FXAA_SUBPIX_TRIM         (1.0/4.0)
    #define FXAA_SUBPIX_TRIM_SCALE   (1.0/(1.0 - FXAA_SUBPIX_TRIM))
#endif

vec3 fxaa(sampler2D tex, vec2 fragCoord, vec2 invResolution) {
    vec2 pos = fragCoord;
    vec2 pp = pos * invResolution;

    vec3 rgbN = texture(tex, pp + vec2(0.0, -1.0) * invResolution).rgb;
    vec3 rgbW = texture(tex, pp + vec2(-1.0, 0.0) * invResolution).rgb;
    vec3 rgbM = texture(tex, pp).rgb;
    vec3 rgbE = texture(tex, pp + vec2(1.0, 0.0) * invResolution).rgb;
    vec3 rgbS = texture(tex, pp + vec2(0.0, 1.0) * invResolution).rgb;

    float lumaN = luma(rgbN);
    float lumaW = luma(rgbW);
    float lumaM = luma(rgbM);
    float lumaE = luma(rgbE);
    float lumaS = luma(rgbS);

    float rangeMin = min(lumaM, min(min(lumaN, lumaW), min(lumaE, lumaS)));
    float rangeMax = max(lumaM, max(max(lumaN, lumaW), max(lumaE, lumaS)));
    float range = rangeMax - rangeMin;

    if (range < max(FXAA_EDGE_THRESHOLD_MIN, rangeMax * FXAA_EDGE_THRESHOLD)) {
        return rgbM;
    }

    vec3 rgbL = (rgbN + rgbW + rgbM + rgbE + rgbS) * (1.0 / 5.0);
    float lumaL = luma(rgbL);

    float subpix1 = FXAA_SUBPIX_FASTER ? (1.0/3.0) : (0.5/3.75);
    float subpix2 = FXAA_SUBPIX_FASTER ? (2.0/3.0) : (1.0/2.5);
    float lumaAvgNw = (lumaN + lumaW) * 0.5;
    float lumaAvgNe = (lumaN + lumaE) * 0.5;
    float lumaAvgSw = (lumaS + lumaW) * 0.5;
    float lumaAvgSe = (lumaS + lumaE) * 0.5;

    float edgeHoriz = abs(-2.0 * lumaW + 2.0 * lumaAvgNw) + abs(-2.0 * lumaM + 2.0 * lumaAvgNe) + abs(-2.0 * lumaS + 2.0 * lumaAvgSe);
    float edgeVert  = abs(-2.0 * lumaN + 2.0 * lumaAvgNw) + abs(-2.0 * lumaM + 2.0 * lumaAvgNe) + abs(-2.0 * lumaE + 2.0 * lumaAvgSe);
    edgeHoriz = abs(edgeHoriz);
    edgeVert  = abs(edgeVert);

    bool horzSpan = edgeHoriz >= edgeVert;
    float lengthSign = horzSpan ? -invResolution.y : -invResolution.x;
    if (!horzSpan) {
        float t = lumaN; lumaN = lumaW; lumaW = t;
        t = lumaE; lumaE = lumaS; lumaS = t;
    }
    float lumaNS = lumaN + lumaS;
    float lumaWE = lumaW + lumaE;
    float gradient = abs(lumaNS - lumaWE);
    float lumaLocalAvg = 0.5 * (lumaNS + lumaWE);

    float subpixLuma1 = 0.5 * (lumaL + lumaM);
    float subpixLuma2 = lumaM - subpixLuma1;
    subpixLuma2 = clamp(abs(subpixLuma2) / range, 0.0, 1.0);
    float subpixScale = subpixLuma2 * FXAA_SUBPIX_TRIM_SCALE;
    subpixScale = clamp(subpixScale, 0.0, 1.0);

    if (gradient < FXAA_SEARCH_THRESHOLD) return rgbM;

    float edgeLen1 = 1.0 / gradient;
    float dirSign = sign(lumaLocalAvg - lumaM);

    float posOff = 0.5 * edgeLen1 - dirSign * lengthSign * 0.5;
    vec2 posA = pp + (horzSpan ? vec2(0.0, posOff) : vec2(posOff, 0.0));
    float posStep = (horzSpan ? invResolution.y : invResolution.x) * dirSign;

    float lumaAtA = texture(tex, posA).g;
    bool doneA = (lumaAtA - lumaLocalAvg) * dirSign < 0.0;
    bool doneB = false;
    vec2 posB = posA;
    float lumaAtB = lumaAtA;

    for (int i = 1; i < FXAA_SEARCH_STEPS; i++) {
        if (!doneA) posA += posStep * edgeLen1;
        if (!doneB) posB -= posStep * edgeLen1;
        if (!doneA) lumaAtA = texture(tex, posA).g;
        if (!doneB) lumaAtB = texture(tex, posB).g;
        doneA = doneA || ((lumaAtA - lumaLocalAvg) * dirSign < 0.0);
        doneB = doneB || ((lumaAtB - lumaLocalAvg) * dirSign < 0.0);
        if (doneA && doneB) break;
    }

    float dstA = abs(posA.x - pp.x) + abs(posA.y - pp.y);
    float dstB = abs(posB.x - pp.x) + abs(posB.y - pp.y);
    bool spanAlong = dstA < dstB;
    float spanLen = (spanAlong ? dstA : dstB) + (1.0 / 384.0);
    float pixelOffset = -spanLen * subpixScale * 0.5;

    vec2 finalPos = pp;
    if (horzSpan) {
        finalPos.y += pixelOffset;
    } else {
        finalPos.x += pixelOffset;
    }

    return texture(tex, finalPos).rgb;
}

#endif // AURORA_FXAA_GLSL
