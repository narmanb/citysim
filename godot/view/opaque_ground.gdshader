shader_type canvas_item;
render_mode unshaded;

varying vec4 cap_color;

void vertex() {
	cap_color = COLOR;
}

// Small, deterministic surface variation in map coordinates. No tiled grid or
// extra textures/draw passes; derivative fade avoids sparkling when zoomed out.
float terrain_hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float terrain_noise(vec2 p) {
	vec2 cell=floor(p);
	vec2 t=fract(p);t=t*t*(3.0-2.0*t);
	return mix(mix(terrain_hash(cell),terrain_hash(cell+vec2(1.0,0.0)),t.x),
		mix(terrain_hash(cell+vec2(0.0,1.0)),terrain_hash(cell+vec2(1.0)),t.x),t.y);
}

void fragment() {
	if (UV.x >= 63.5) {
		vec2 ground=UV-vec2(64.0,0.0);
		float footprint=max(length(dFdx(ground)),length(dFdy(ground)));
		float fine_fade=1.0-smoothstep(0.035,0.13,footprint);
		float detail=(terrain_noise(ground*1.35)-0.5)*0.055;
		detail+=(terrain_noise(ground*13.0)-0.5)*0.065*fine_fade;
		COLOR=vec4(cap_color.rgb*(1.0+detail),1.0);
	} else if (UV.x < -4.0) {
		// Analytic coverage of a wire across the pixel footprint. This also
		// handles subpixel-width network lines in the full-city overview.
		float distance_to_center = UV.x + 32.0;
		float pixel_width = max(fwidth(distance_to_center), 0.0001);
		float low = distance_to_center - pixel_width * 0.5;
		float high = distance_to_center + pixel_width * 0.5;
		float coverage = clamp((min(high, UV.y) - max(low, -UV.y)) / pixel_width, 0.0, 1.0);
		COLOR = vec4(cap_color.rgb, cap_color.a * coverage);
	} else if (UV.x < 0.0) {
		COLOR = cap_color;
	} else {
		// Rounded caps encode tinting with a separate UV band. Ordinary sprites
		// and the original opaque flat-cap path retain their exact semantics.
		bool rounded = UV.x > 1.5;
		vec2 source_uv = UV - vec2(rounded ? 2.0 : 0.0, 0.0);
		vec4 sample_color = texture(TEXTURE, source_uv);
		if (rounded) {
			COLOR = vec4(mix(cap_color.rgb, sample_color.rgb * (cap_color.a * (255.0 / 128.0)), sample_color.a), 1.0);
		} else if (cap_color.a == 0.0) {
			// Fill transparent cap-edge texels in the same draw as the terrain.
			COLOR = vec4(mix(cap_color.rgb, sample_color.rgb, sample_color.a), 1.0);
		} else {
			COLOR = sample_color * cap_color;
		}
	}
}
