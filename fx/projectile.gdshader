shader_type spatial;
render_mode unshaded, cull_back;
void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 1.5;
}
