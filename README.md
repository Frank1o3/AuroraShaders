# Aurora Shaders

A modern, performance-focused shader pack for **Minecraft (Iris)**, targeting **OpenGL 4.6** for clean, realistic visuals at stable frame rates across a wide range of hardware.

> Designed for **Minecraft 26.1.2 / 1.21+** with the **Iris** shader loader.

---

## Highlights

- **Clean, realistic lighting** — Cook-Torrance specular (GGX) + half-Lambert wrap diffuse, hemispheric sky fill.
- **Soft dynamic shadows** — Rotated-disk PCF with slope-aware bias, quality-adaptive sample count (4/8/12 taps).
- **Smooth global illumination feel** — Hemisphere ambient + sky bounce + wrap-around soft fill for readable night scenes.
- **Subtle ambient occlusion** — GTAO-inspired SSAO with per-pixel dithered rotation, quality-adaptive (4/8/16 taps).
- **Natural color balance** — ACES (Hill) tone mapping, mild saturation/contrast grade, warm torch light, correct sun/moon separation.
- **Excellent day & night readability** — Adaptive exposure + daylight/moonlight curve tuned to keep detail visible in both.
- **Optimized** — Fullscreen-triangle composite passes, early-out specular, no ray marching, low sample counts.
- **OpenGL 4.6** — `#version 460 core` everywhere, `textureGather` for 4-tap shadows, modern GLSL idioms.
- **Quality tiers** — `QUALITY_LEVEL` 0–3 adjusts shadow/SSAO sample counts at compile time.
- **Dimension-aware** — Separate composite for Nether (`world-1`) and End (`world1`).
- **Animated water & foliage** — Vertex waving, procedural water normals.
- **Bloom + god rays + procedural stars + horizon haze + rain fog.**

---

## Architecture

### Include graph (DAG — no cycles)

```
lib/settings.glsl          (root — all #define constants)
    ↑
lib/common.glsl            (uniforms, math helpers, sRGB, material IDs)
    ↑    ↑    ↑    ↑    ↑
    |    |    |    |    |
  shadows  ssao  fog  tonemap  fxao   fullscreen (standalone)
    ↑
 lighting

Stage files:
  composite.fsh     → common + lighting + ssao + fog
  composite1.fsh    → common
  composite2.fsh    → common + tonemap
  composite3.fsh    → common + lighting
  composite4.fsh    → common
  final.fsh         → common + tonemap + fxaa
  final.vsh         → fullscreen
  composite*.vsh    → fullscreen
  gbuffers_*.fsh    → common (+ lighting for terrain)
  gbuffers_*.vsh    → common
  world-1/composite.fsh → ../lib/common + ../lib/lighting + ../lib/ssao + ../lib/fog
  world1/composite.fsh  → same as world-1
```

### Include guard convention

Every lib file uses `#ifndef AURORA_<NAME>_GLS / #define AURORA_<NAME>_GLSL / #endif`. `#pragma once` is NOT honored by the Iris preprocessor and must not be used.

### Include path convention

- **Stage files in `shaders/`**: `#include "lib/common.glsl"` (relative to shaders/ root)
- **Lib files in `shaders/lib/`**: `#include "common.glsl"` (bare filename, same directory)
- **Dimension files in `shaders/world-*/`**: `#include "../lib/common.glsl"` (relative to file)

---

## Installation

1. Install **Iris Shaders** (https://irisshaders.dev).
2. Drop `AuroraShaders.zip` into `.minecraft/shaderpacks/`.
3. In-game: **Options → Video Settings → Shader Packs → AuroraShaders → Apply**.

---

## Quality Settings

All settings are in `shaders/lib/settings.glsl` and can be overridden via the Iris shader options UI.

| Setting | Default | Range | Effect |
|---|---|---|---|
| `QUALITY_LEVEL` | 1 | 0–3 | Master quality: 0=integrated GPU, 1=medium, 2=high, 3=ultra |
| `SHADOW_MAP_RES` | 2048 | 512–4096 | Shadow map resolution |
| `SHADOW_PCF_SIZE` | 1.5 | 0.5–4.0 | Shadow softness |
| `SSAO_RADIUS` | 0.8 | 0.2–2.0 | SSAO sampling radius |
| `AO_STRENGTH` | 1.0 | 0.0–2.0 | AO darkening strength |
| `BLOOM_THRESHOLD` | 1.2 | 0.5–3.0 | HDR threshold for bloom |
| `BLOOM_STRENGTH` | 1.0 | 0.0–2.0 | Bloom intensity |
| `EXPOSURE_ADAPT_SPEED` | 1.5 | 0.1–5.0 | Eye adaptation speed |
| `SATURATION` | 1.05 | 0.5–2.0 | Color saturation |
| `CONTRAST` | 1.03 | 0.5–2.0 | Color contrast |
| `WAVING_FOLIAGE` | 1 | 0–1 | Toggle grass/leaf/water animation |
| `HALF_RES_SSAO` | 0 | 0–1 | Run SSAO at half resolution |
| `HALF_RES_BLOOM` | 0 | 0–1 | Run bloom at half resolution |
| `HALF_RES_GODRAYS` | 0 | 0–1 | Run god rays at half resolution |

### Quality level → sample counts

| QUALITY_LEVEL | Shadow taps | SSAO taps | Target GPU |
|---|---|---|---|
| 0 | 4 (textureGather) | 4 | Integrated / mobile |
| 1 | 8 | 8 | Mid-range discrete |
| 2 | 12 | 16 | High-end discrete |
| 3 | 12 | 16 | Same as 2, higher shadow res |

---

## Render Pipeline

```
gbuffers_*  ──►  colortex0 (albedo RGBA16F)
                colortex1 (normal + mat id RGB10_A2)
                colortex2 (lightmap + roughness + emissive RGBA16F)
                depthtex0/1

composite   ──►  colortex0 (lit HDR scene)
                colortex1 (AO buffer RGBA8)
                colortex2 (bloom bright pass)

composite1  ──►  colortex0 (bloom horizontal blur)
composite2  ──►  colortex0 (scene + bloom, exposure applied)
                colortex1 (exposure feedback)
composite3  ──►  colortex0 (scene + god rays)
composite4  ──►  colortex0 (passthrough — reserved for clouds)
final       ──►  back buffer (FXAA → ACES tonemap → grade → vignette → sRGB)
```

---

## Performance Review & Optimization Opportunities

### Currently implemented

1. **Fullscreen triangle** — composite passes use a 3-vertex triangle (no overdraw vs. quad)
2. **Early-out specular** — Cook-Torrance skipped when `NdotL ≤ 0` or fully shadowed
3. **Quality-adaptive sample counts** — 4/8/12 shadow taps, 4/8/16 SSAO taps
4. **textureGather** for 4-tap shadows (GL 4.0+, 4 texels in 1 instruction)
5. **Separable Gaussian bloom** — 9-tap horizontal + 9-tap vertical (vs. 81-tap 2D)
6. **Cheap screen-space god rays** — 16 radial samples, sky-only
7. **No TAA history buffers** — lower VRAM, no ghosting
8. **Dithered rotation** — interleaved gradient noise rotates SSAO/shadow kernels per-pixel for free quality

### Opportunities for future improvement

#### A. Temporal reprojection (TAA / temporal SSAO)

**What:** Reuse previous frame's shading results, reprojected using motion vectors, to augment the current frame's sparse samples.

**Prerequisites:**
- Velocity buffer (write `colortex3` in gbuffers using `gbufferPreviousModelView/Projection`)
- Previous frame color buffer (ping-pong between two colortex0 copies)
- `frameCounter` for jitter offsets

**Impact:** 4× effective SSAO samples, 2× effective shadow samples, eliminates most dithering noise. Adds ~1ms per frame and 8–16MB VRAM.

**Recommended for:** QUALITY_LEVEL ≥ 2.

#### B. Half-resolution rendering

**What:** Run SSAO, bloom, and god rays at half resolution, then bilinearly upsample.

**Status:** Toggles exist (`HALF_RES_SSAO`, `HALF_RES_BLOOM`, `HALF_RES_GODRAYS`) but the composite passes don't yet implement half-res dispatch. Implementation requires:
- Iris `scale.` directives in `shaders.properties` (e.g. `scale.composite1=0.5`)
- Depth-aware upsampling in the consuming pass to avoid halos

**Impact:** SSAO ~4× faster, bloom ~4× faster, god rays ~4× faster. Minor quality loss (acceptable for QUALITY_LEVEL 0).

**Recommended for:** Integrated GPUs (QUALITY_LEVEL 0).

#### C. Hierarchical depth (Hi-Z) traversal

**What:** Generate a mip chain of the depth buffer; use it to accelerate screen-space ray marching for SSR/SSGI by skipping empty space.

**Prerequisites:**
- `layout(binding=N)` image2D for depth mip chain (GL 4.6)
- Compute shader or multi-pass composite to generate mips
- Iris `customUniforms` or image bindings

**Impact:** SSR ray marching goes from O(steps) to O(log steps). 10× faster SSR at equal quality.

**Recommended for:** When SSR is added (see D).

#### D. Screen-space reflections (SSR) / screen-space GI (SSGI)

**What:** Ray-march in screen space to find reflections (water, metal) or bounce lighting.

**Prerequisites:** Hi-Z (see C), velocity buffer for temporal filtering.

**Impact:** Water and metal reflections look dramatically better. Adds ~2–4ms per frame on mid-range GPUs.

**Recommended for:** QUALITY_LEVEL ≥ 2, after temporal reprojection is added.

#### E. Dynamic quality scaling

**What:** Adjust `QUALITY_LEVEL` at runtime based on measured frame time.

**Implementation:** Use Iris `customUniforms` to expose a `float frameTime` uniform; in composite.fsh, branch on `frameTime > threshold` to reduce sample counts. Requires `#extension GL_EXT_control_flow_attributes` or `layout(constant_id=)` for true compile-time branching — otherwise runtime branching still works but is less optimal.

**Impact:** Maintains stable FPS on variable hardware (laptops, thermal throttling).

**Recommended for:** All quality levels.

#### F. GL 4.6 specific features

| Feature | Current | Opportunity |
|---|---|---|
| `textureGather` | Used in 4-tap shadows | Extend to SSAO 4-tap path |
| `layout(binding=N)` | Not used | Add for explicit sampler binding (cleaner, avoids glUniform1i) |
| `imageLoad/Store` | Not used | Use for atomic exposure feedback (1×1 image) instead of sampling colortex3 |
| `subgroupOps` | Not used | `subgroupAdd` / `subgroupBroadcast` for SSAO occlusion reduction (GL_KHR_shader_subgroup) |
| `textureGatherOffsets` | Not used | Custom 2×2 offsets for sharper shadow edges |

---

## File Structure

```
AuroraShaders/
├── pack.mcmeta
├── README.md
└── shaders/
    ├── shaders.properties       # Buffer formats, shadow map, Iris options
    ├── iris.properties          # Iris-specific options
    ├── block.properties         # Block-ID → material category mapping
    ├── lib/
    │   ├── settings.glsl        # All #define constants (root of include DAG)
    │   ├── common.glsl          # Uniforms, math, sRGB, material IDs
    │   ├── fullscreen.glsl      # Fullscreen triangle vertex helper
    │   ├── lighting.glsl        # Cook-Torrance + sky + ambient + SSS
    │   ├── shadows.glsl         # Soft PCF + colored translucent shadows
    │   ├── ssao.glsl            # GTAO-inspired SSAO
    │   ├── tonemap.glsl         # ACES, color grade, exposure, vignette
    │   ├── fxaa.glsl            # FXAA 3.11 (quality preset 12)
    │   └── fog.glsl             # Distance, horizon, rain, underwater fog
    ├── gbuffers_terrain.{vsh,fsh}
    ├── gbuffers_water.{vsh,fsh}
    ├── gbuffers_entities.{vsh,fsh}
    ├── gbuffers_hand.{vsh,fsh}
    ├── gbuffers_block.{vsh,fsh}
    ├── gbuffers_basic.{vsh,fsh}
    ├── gbuffers_skybasic.{vsh,fsh}
    ├── composite.{vsh,fsh}         # Lighting + SSAO + bloom bright
    ├── composite1.{vsh,fsh}        # Bloom horizontal blur
    ├── composite2.{vsh,fsh}        # Bloom vertical + exposure
    ├── composite3.{vsh,fsh}        # God rays
    ├── composite4.{vsh,fsh}        # Passthrough (reserved for clouds)
    ├── final.{vsh,fsh}             # FXAA + ACES + grade + sRGB
    ├── world0/                     # Overworld overrides (empty = inherit)
    ├── world-1/composite.fsh       # Nether composite
    └── world1/composite.fsh        # End composite
```

---

## Compatibility

- ✅ Iris 1.7+ (recommended latest)
- ✅ Minecraft 1.21+ through 26.x
- ✅ OpenGL 4.6 capable GPUs (NVIDIA Kepler+, AMD GCN+, Intel Xe+)
- ⚠️ macOS is NOT supported (Apple deprecated OpenGL; Metal translation doesn't reach 4.6)

---

## License

Provided as-is for personal and educational use. Modify, fork, and redistribute freely with attribution.
