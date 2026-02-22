// Necromancer Hand Shader — always renders on top of the scene.
// Uses depth_test_disabled so the hand is never occluded by walls/floors.
// This sells the "reaching down onto a game board" fantasy.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_test_disabled;

uniform vec4 albedo_color : source_color = vec4(0.6, 0.2, 0.9, 1.0);
uniform float jitter_strength : hint_range(0.0, 1.0) = 0.3;
uniform float emission_strength : hint_range(0.0, 5.0) = 2.0;

vec4 snap_vertex(vec4 vertex, vec2 resolution) {
	vec4 snapped = vertex;
	snapped.xyz = vertex.xyz / vertex.w;
	snapped.xy = floor(resolution * snapped.xy) / resolution;
	snapped.xyz *= vertex.w;
	return snapped;
}

void vertex() {
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float precision = (1.0 - jitter_strength) * 200.0 + 20.0;
	POSITION = snap_vertex(clip_pos, vec2(precision));
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	EMISSION = albedo_color.rgb * emission_strength;
}
