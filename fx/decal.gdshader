shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
varying float v_alpha;
void vertex() {
	v_alpha = INSTANCE_CUSTOM.x;
}
void fragment() {
	// soft round splat from the quad's UV
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = smoothstep(1.0, 0.55, d) * v_alpha;
	ALBEDO = COLOR.rgb;
	ALPHA = a;
}
