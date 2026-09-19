shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
varying float v_life;
void vertex() {
	v_life = INSTANCE_CUSTOM.x;
	VERTEX *= clamp(v_life * 2.0, 0.0, 1.0);
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
