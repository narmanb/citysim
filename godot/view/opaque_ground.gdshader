shader_type canvas_item;
render_mode unshaded;

varying vec4 cap_color;

void vertex() {
	cap_color = COLOR;
}

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	if (cap_color.a == 0.0) {
		// Cap-edge texels blend over the terrain color in this same draw call.
		COLOR = vec4(mix(cap_color.rgb, sample_color.rgb, sample_color.a), 1.0);
	} else {
		COLOR = sample_color * cap_color;
	}
}
