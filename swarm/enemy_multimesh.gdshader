// Regular-enemy MultiMesh shader.
// INSTANCE_CUSTOM.x = hit flash (0..1), .y = stagger squash (0..1) — vertex only, passed via varyings.
// COLOR = per-instance colour (enemy type)
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

varying float v_flash;

void vertex() {
	float squash = INSTANCE_CUSTOM.y;
	v_flash = INSTANCE_CUSTOM.x;
	VERTEX.y *= 1.0 - squash * 0.3;
	VERTEX.xz *= 1.0 + squash * 0.25;
	// cheap idle bob so the swarm never looks frozen
	VERTEX.y += sin(TIME * 5.0 + float(INSTANCE_ID) * 1.7) * 0.03;
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, vec3(1.0), v_flash);
	EMISSION = vec3(1.0, 0.9, 0.8) * v_flash * 1.5;
	ROUGHNESS = 0.85;
}
