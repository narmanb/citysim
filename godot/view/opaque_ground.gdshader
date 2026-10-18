shader_type canvas_item;
render_mode unshaded;

uniform bool grid_enabled = false;
varying vec4 cap_color;

void vertex() {
	cap_color = COLOR;
}

void fragment() {
	if (UV.x >= 63.5) {
		// Rounded land uses the same clean palette as the original flat caps.
		// Shared vertex colors retain smooth lighting without grain or tile lines.
		vec3 color=cap_color.rgb;
        if (grid_enabled) {
            vec2 ground=UV-vec2(64.0,0.0);
            vec2 cell=fract(ground);
            vec2 width=max(fwidth(ground),vec2(0.0001));
            vec2 edge=min(cell,1.0-cell)/width;
            float line=1.0-smoothstep(0.15,0.95,min(edge.x,edge.y));
            float fade=1.0-smoothstep(0.12,0.35,max(width.x,width.y));
            color*=1.0-0.14*line*fade;
        }
        COLOR=vec4(color,1.0);
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
