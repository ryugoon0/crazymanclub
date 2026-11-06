// Character shader shared by the swarm MultiMeshes and the single-node
// characters (player, boss). Meshes come from tools/art/build_characters.gd,
// which documents the vertex attribute contract:
//   COLOR   rgb tint. With a MultiMesh (use_colors) Godot multiplies it by the
//           per-instance colour (the enemy type colour) before vertex();
//           single meshes get the same through `base_color`.
//           a = blend toward the palette colour (bone, gunmetal, lighter plates)
//   UV      x = emission strength, y = 0 type-colour glow / 1 hot orange
//   UV2     x = limb swing weight, sign = gait phase group; y = palette index
// (CUSTOM0 would be the natural home for the palette colour, but it does not
// reach the gl_compatibility renderer, so everything rides on COLOR/UV/UV2.)
// Per-instance state: INSTANCE_CUSTOM.x = hit flash, .y = stagger squash,
// .z = move (0 idle .. 1 full stride), .w = gait Hz. Single meshes drive the
// same four values with the uniforms below (max of both is used).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float squash : hint_range(0.0, 1.0) = 0.0;
uniform float tele : hint_range(0.0, 1.0) = 0.0;
uniform float move : hint_range(0.0, 1.5) = 0.0;
uniform float gait_hz = 2.0;
uniform float swing_amp = 0.12;
uniform float phase_seed = 0.0;
uniform float ambient = 0.16;
uniform float rim = 0.3;
uniform float idle_bob = 0.02;

varying vec3 v_albedo;
varying float v_flash;
varying vec2 v_emis;

// Absolute colours by index (tools/art/build_characters.gd PAL_*).
vec3 palette(int i) {
	if (i == 1) { return vec3(0.88, 0.84, 0.74); } // bone
	if (i == 2) { return vec3(0.30, 0.33, 0.38); } // gunmetal
	if (i == 3) { return vec3(0.15, 0.16, 0.19); } // gunmetal dark
	if (i == 4) { return vec3(0.62, 0.65, 0.70); } // steel
	if (i == 5) { return vec3(1.0); }              // white (lighten)
	if (i == 6) { return vec3(1.0, 0.86, 0.80); }  // egg sac
	return vec3(0.0);
}

void vertex() {
	vec3 tint = COLOR.rgb * base_color.rgb;
	v_albedo = mix(tint, palette(int(UV2.y + 0.5)), COLOR.a);
	v_emis = UV;
	v_flash = max(INSTANCE_CUSTOM.x, flash);
	float sq = max(INSTANCE_CUSTOM.y, squash);
	float mv = max(INSTANCE_CUSTOM.z, move);
	float hz = INSTANCE_CUSTOM.w > 0.0 ? INSTANCE_CUSTOM.w : gait_hz;
	float id = float(INSTANCE_ID) * 1.7 + phase_seed;
	float ph = TIME * hz * TAU + id;
	// procedural gait: limbs swing fore/aft by their authored weight, lift on
	// the forward swing; the body bobs once per footfall
	float w = abs(UV2.x);
	float grp = UV2.x < 0.0 ? PI : 0.0;
	float sw = w * sin(ph + grp);
	VERTEX.z += sw * swing_amp * mv;
	VERTEX.y += max(sw, 0.0) * swing_amp * 0.5 * mv;
	VERTEX.y += (0.5 - 0.5 * cos(2.0 * ph)) * 0.03 * mv * (1.0 - min(w, 1.0));
	// idle breathing (feet stay planted)
	VERTEX.y += sin(TIME * 2.5 + id) * idle_bob * (1.0 - min(mv, 1.0)) * smoothstep(0.0, 0.6, VERTEX.y);
	// stagger / telegraph squash toward the feet
	VERTEX.y *= 1.0 - sq * 0.3;
	VERTEX.xz *= 1.0 + sq * 0.25;
}

void fragment() {
	vec3 alb = mix(v_albedo, vec3(1.0), v_flash);
	alb = mix(alb, vec3(1.0, 0.85, 0.2), tele * 0.6);
	ALBEDO = alb;
	vec3 glow = mix(alb * 0.9 + 0.25, vec3(1.0, 0.6, 0.22), v_emis.y);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow * v_emis.x * 1.8 + vec3(1.0, 0.9, 0.8) * v_flash * 1.5 + alb * (ambient + fres * rim);
	ROUGHNESS = 0.8;
}
