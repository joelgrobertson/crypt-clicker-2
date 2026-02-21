// PS1/PSX Unlit Shader for Godot 4
// Vertex snapping without lighting — for UI, effects, glowing objects
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float jitter_strength : hint_range(0.0, 1.0) = 0.5;
uniform float emission_strength : hint_range(0.0, 5.0) = 0.0;

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
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb * albedo_color.rgb;
	if (emission_strength > 0.0) {
		EMISSION = ALBEDO * emission_strength;
	}
}
