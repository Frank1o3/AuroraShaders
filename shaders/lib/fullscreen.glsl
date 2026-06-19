// =====================================================================
// Aurora Shaders - fullscreen.glsl
// Shared fullscreen-triangle vertex logic.
//
// This file is included by composite.vsh AND composite1-4.vsh AND
// final.vsh. It intentionally has NO #version directive, NO inputs,
// and NO main() — it only emits the output declaration and a helper
// function that the including .vsh calls from its own main().
//
// This avoids the "duplicate #version" error that would occur if a
// .vsh file #included another .vsh file that starts with #version.
// =====================================================================
#ifndef AURORA_FULLSCREEN_GLSL
#define AURORA_FULLSCREEN_GLSL

out vec2 v_TexCoord;

// Emits a fullscreen triangle covering the entire clip space (-1..1).
// The caller's main() should just call this function.
void emitFullscreenTriangle() {
    vec2 verts[3] = vec2[3](
        vec2(-1.0, -1.0),
        vec2( 3.0, -1.0),
        vec2(-1.0,  3.0)
    );
    gl_Position = vec4(verts[gl_VertexID], 0.0, 1.0);
    v_TexCoord = gl_Position.xy * 0.5 + 0.5;
}

#endif // AURORA_FULLSCREEN_GLSL
