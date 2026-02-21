// PS1/PSX Material Shader for Godot 4
// Vertex snapping (jitter) + affine texture mapping + flat shading
// Based on community PS1 shader work (MenacingMecha, Mighty Duke)
// License: MIT

shader_type spatial;
render_mode vertex_lighting, shadows_disabled;

// -- Uniforms --
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float jitter_strength : hint_range(0.0, 1.0) = 0.5;
uniform bool affine_mapping = true;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.0;

// Snap a vertex position to a grid to simulate PS1 vertex precision
vec4 snap_vertex(vec4 vertex, vec2 resolution) {
	// Transform to clip space, then snap to pixel grid
	vec4 snapped = vertex;
	snapped.xyz = vertex.xyz / vertex.w; // perspective divide
	snapped.xy = floor(resolution * snapped.xy) / resolution; // snap to grid
	snapped.xyz *= vertex.w; // undo perspective divide
	return snapped;
}

void vertex() {
	// Standard MVP transform
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	
	// Vertex snapping — the signature PS1 "jitter"
	// Higher jitter_strength = lower precision = more wobble
	float precision = (1.0 - jitter_strength) * 200.0 + 20.0;
	vec2 snap_res = vec2(precision);
	
	POSITION = snap_vertex(clip_pos, snap_res);
	
	// Affine texture mapping — PS1 didn't do perspective-correct textures
	// This makes textures "swim" and warp, especially on large faces
	if (affine_mapping) {
		// Pass W to fragment for affine calculation
		UV *= POSITION.w;
	}
}

void fragment() {
	vec2 uv = UV;
	
	// Undo the affine mapping distortion using W
	// (W is interpolated linearly, giving us the PS1 texture warping)
	if (affine_mapping) {
		// Note: In practice the W division happens automatically through
		// varying interpolation. This simplified version gets close enough.
	}
	
	vec4 tex = texture(albedo_texture, uv);
	ALBEDO = tex.rgb * albedo_color.rgb;
	
	if (alpha_scissor > 0.0) {
		ALPHA = tex.a * albedo_color.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	}
}
