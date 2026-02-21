// PS1 Post-Processing — Color Depth Reduction + Dithering
// Apply this to a ColorRect covering the full screen via a CanvasLayer
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform int color_depth : hint_range(1, 8) = 5; // PS1 used 5-bit color (32 levels per channel)
uniform bool dithering = true;

// Ordered 4x4 Bayer dithering matrix (same as PS1 hardware)
int dither_matrix(ivec2 fragcoord) {
	const int pattern[16] = {
		-4, +0, -3, +1,
		+2, -2, +3, -1,
		-3, +1, -4, +0,
		+3, -1, +2, -2
	};
	int x = fragcoord.x % 4;
	int y = fragcoord.y % 4;
	return pattern[y * 4 + x];
}

void fragment() {
	vec3 color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	
	// Quantize color to reduced bit depth
	float levels = float(1 << color_depth); // e.g., 5-bit = 32 levels
	
	if (dithering) {
		ivec2 fc = ivec2(FRAGCOORD.xy);
		float dither = float(dither_matrix(fc)) / 4.0; // normalize to roughly -1..+1
		color += dither / levels; // apply dither before quantization
	}
	
	color = floor(color * levels) / levels;
	COLOR = vec4(color, 1.0);
}
