## Renders the character portraits (and an optional iso line-up for art review)
## offscreen. Needs a GL context, so run it under Xvfb + Mesa:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --rendering-method gl_compatibility --audio-driver Dummy res://tools/art/render_portraits.tscn
## Writes res://assets/portraits/<id>.png (256x256, three-quarter head-and-
## shoulders, key + cool rim light, dark gradient, vignette + scanlines).
## Options (after --):
##   --out-dir=res://assets/portraits   where the PNGs go
##   --lineup=user://lineup.png         also render all characters from the
##                                      gameplay camera angle (review only)
##   --lineup-move=1.0                  gait `move` value for the line-up
##   --only=drone,tank                  subset of ids
extends Node

const SIZE := 256
const PLAYER_COLOR := Color(1.0, 0.42, 0.12)
const SHADER := preload("res://fx/character.gdshader")

## id -> [mesh path, type colour (null = EnemyData.color), framed height (m),
##        focus point in mesh space (what the camera centres on), view dir]
const CHARACTERS := {
	"player": ["res://assets/models/player.res", PLAYER_COLOR, 1.35, Vector3(0.0, 1.5, -0.05), Vector3(0.6, 0.22, -1.0)],
	"drone": ["res://assets/models/drone.res", null, 1.25, Vector3(0.0, 0.72, -0.35), Vector3(0.75, 0.4, -1.0)],
	"runner": ["res://assets/models/runner.res", null, 1.15, Vector3(0.0, 0.34, -0.25), Vector3(0.8, 0.55, -1.0)],
	"tank": ["res://assets/models/tank.res", null, 1.9, Vector3(0.0, 1.55, -0.3), Vector3(0.65, 0.28, -1.0)],
	"boss_broodmother": ["res://assets/models/boss_broodmother.res", null, 3.2, Vector3(0.0, 2.25, -0.9), Vector3(0.65, 0.32, -1.0)],
}

var _out_dir := "res://assets/portraits"
var _lineup := ""
var _lineup_move := 1.0
var _only: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out-dir="):
			_out_dir = a.trim_prefix("--out-dir=")
		elif a.begins_with("--lineup="):
			_lineup = a.trim_prefix("--lineup=")
		elif a.begins_with("--lineup-move="):
			_lineup_move = float(a.trim_prefix("--lineup-move="))
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",")
	_run()


func _run() -> void:
	var failed := false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	for id: String in CHARACTERS:
		if not _only.is_empty() and not _only.has(id):
			continue
		var path := "%s/%s.png" % [_out_dir, id]
		var img := await _render_portrait(id)
		var err := img.save_png(path)
		failed = failed or err != OK
		print("PORTRAIT %-17s -> %s (%dx%d, err %d)" % [id, ProjectSettings.globalize_path(path), img.get_width(), img.get_height(), err])
	if _lineup != "":
		var img := await _render_lineup()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_lineup.get_base_dir()))
		var err := img.save_png(_lineup)
		failed = failed or err != OK
		print("LINEUP -> %s (err %d)" % [ProjectSettings.globalize_path(_lineup), err])
	get_tree().quit(1 if failed else 0)


func _type_color(id: String) -> Color:
	var c: Variant = CHARACTERS[id][1]
	if c != null:
		return c
	var e := Content.enemy(StringName(id))
	return e.color if e != null else Color.WHITE


func _material(color: Color, move: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"base_color", color)
	m.set_shader_parameter(&"move", move)
	m.set_shader_parameter(&"idle_bob", 0.0)
	return m


## The character as it appears in game: body mesh (+ rifle for the player).
func _character(id: String, move: float = 0.0) -> Node3D:
	var root := Node3D.new()
	var color := _type_color(id)
	var mi := MeshInstance3D.new()
	mi.mesh = load(CHARACTERS[id][0])
	mi.material_override = _material(color, move)
	root.add_child(mi)
	if id == "player":
		var gun := MeshInstance3D.new()
		gun.mesh = load("res://assets/models/player_rifle.res")
		gun.material_override = mi.material_override
		gun.position = Vector3(0.23, 1.1, -0.35)
		root.add_child(gun)
	return root


func _viewport(w: int, h: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


func _grab(vp: SubViewport) -> Image:
	# Two frames so the scene is in the tree and lit before the read-back.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _render_portrait(id: String) -> Image:
	var vp := _viewport(SIZE, SIZE)
	var color := _type_color(id)
	var spec: Array = CHARACTERS[id]
	var frame_h: float = spec[2]
	var dir: Vector3 = (spec[4] as Vector3).normalized()

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.035, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.34, 0.42)
	e.ambient_light_energy = 0.45
	env.environment = e
	vp.add_child(env)

	var ch := _character(id)
	vp.add_child(ch)
	var focus: Vector3 = spec[3]
	var dist := frame_h / (2.0 * tan(deg_to_rad(15.0)))

	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = focus + dir * dist
	vp.add_child(cam)
	cam.look_at(focus, Vector3.UP)
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var back := cam.global_transform.basis.z  # focus -> camera

	# backdrop: dark gradient with a faint glow in the type colour
	var bg := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(frame_h * 6.0, frame_h * 6.0)
	bg.mesh = quad
	var bgm := ShaderMaterial.new()
	bgm.shader = _backdrop_shader()
	bgm.set_shader_parameter(&"glow", color)
	bg.material_override = bgm
	bg.position = focus - dir * frame_h * 2.0
	vp.add_child(bg)
	bg.look_at(cam.position, Vector3.UP)

	# key (warm, from camera-left-above), rim (cool, from behind-right so the
	# silhouette edge lights up), fill (weak, from below-left)
	_light(vp, right * 0.55 - up * 0.65 - back * 0.5, Color(1.0, 0.94, 0.86), 1.4)
	_light(vp, -right * 0.6 - up * 0.35 + back * 0.75, Color(0.45, 0.85, 1.0), 3.5)
	_light(vp, -right * 0.4 + up * 0.5 - back * 0.4, Color(0.5, 0.55, 0.75), 0.4)

	# post: vignette + scanlines + accent bar
	var layer := CanvasLayer.new()
	layer.layer = 1
	vp.add_child(layer)
	var post := ColorRect.new()
	post.size = Vector2(SIZE, SIZE)
	var pm := ShaderMaterial.new()
	pm.shader = _post_shader()
	pm.set_shader_parameter(&"accent", color)
	post.material = pm
	layer.add_child(post)
	return await _grab(vp)


func _light(parent: Node, direction: Vector3, color: Color, energy: float) -> void:
	var l := DirectionalLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.shadow_enabled = false
	parent.add_child(l)
	l.look_at_from_position(Vector3.ZERO, direction.normalized(), Vector3.UP if absf(direction.normalized().y) < 0.95 else Vector3.FORWARD)


## All characters in a row on the mission floor, from the IsoCamera angle
## (offset 10,14,10, fov 30) — the readability check at gameplay zoom.
func _render_lineup() -> Image:
	var vp := _viewport(1600, 900)
	var floor_mi := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(60, 0.2, 60)
	floor_mi.mesh = floor_mesh
	floor_mi.position.y = -0.1
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.17, 0.2)
	floor_mi.material_override = fm
	vp.add_child(floor_mi)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3(0.866025, 0.0, -0.5), Vector3(-0.353553, 0.707107, -0.612372), Vector3(0.353553, 0.707107, 0.612372)), Vector3(0, 10, 0))
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	vp.add_child(sun)
	var right := Vector3(0.707107, 0.0, -0.707107)
	var ids: PackedStringArray = ["player", "drone", "runner", "tank", "boss_broodmother"]
	var x := -5.0
	for i: int in range(ids.size()):
		var id := ids[i]
		var mesh: Mesh = load(CHARACTERS[id][0])
		var w := mesh.get_aabb().size.x
		x += w * 0.5 + 0.6
		var ch := _character(id, _lineup_move)
		ch.position = right * x
		# second row: facing the camera / away, scaled copies to judge the back
		vp.add_child(ch)
		var ch2 := _character(id, 0.0)
		ch2.position = right * x + Vector3(-3.0, 0.0, -3.0)
		ch2.rotation.y = PI * 0.75
		vp.add_child(ch2)
		x += w * 0.5 + 0.6
	# Same angle as IsoCamera (offset 10,14,10), pulled back so the row fits.
	var centre := right * (x * 0.5 - 5.0) + Vector3(-1.5, 0.0, -1.5)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = centre + Vector3(10, 14, 10) * 1.45
	vp.add_child(cam)
	cam.look_at(centre, Vector3.UP)
	return await _grab(vp)


func _backdrop_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 glow : source_color = vec4(1.0);
void fragment() {
	vec2 p = UV - vec2(0.5, 0.46);
	float r = length(p * vec2(1.0, 1.25));
	vec3 c = mix(vec3(0.09, 0.10, 0.13), vec3(0.02, 0.022, 0.03), smoothstep(0.08, 0.6, r));
	c += glow.rgb * 0.28 * exp(-r * r * 40.0);
	// faint horizon band
	c += vec3(0.03, 0.035, 0.05) * smoothstep(0.02, 0.0, abs(UV.y - 0.36));
	ALBEDO = c;
}
"""
	return s


func _post_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform vec4 accent : source_color = vec4(1.0);
void fragment() {
	vec2 uv = UV;
	float vig = smoothstep(0.42, 0.98, length((uv - 0.5) * vec2(1.0, 1.08)));
	float scan = 0.5 + 0.5 * sin(uv.y * 128.0 * 6.2831853);
	float a = vig * 0.8 + scan * 0.07;
	vec3 c = vec3(0.0);
	// accent bar + corner ticks (intel-card framing)
	if (uv.y > 0.972) { c = accent.rgb; a = 0.9; }
	float edge = 0.02;
	float tick = step(uv.x, 0.09) * step(uv.y, edge) + step(1.0 - uv.x, 0.09) * step(uv.y, edge)
		+ step(uv.x, edge) * step(uv.y, 0.09) + step(1.0 - uv.x, edge) * step(uv.y, 0.09);
	if (tick > 0.0) { c = accent.rgb * 0.8; a = 0.8; }
	COLOR = vec4(c, a);
}
"""
	return s
