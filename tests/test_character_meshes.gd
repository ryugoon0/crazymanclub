## Art draft contract: every character body is one generated single-surface
## mesh with vertex colours, inside its triangle budget, standing on y = 0
## (tools/art/build_characters.gd), and has a rendered portrait.
class_name TestCharacterMeshes
extends GdUnitTestSuite

const ENEMY_BUDGET := {&"drone": 600, &"runner": 600, &"tank": 900, &"boss_broodmother": 3000}
const PLAYER_BUDGET := 2500


func _check_mesh(mesh: Mesh, budget: int, label: String) -> void:
	assert_object(mesh).override_failure_message("%s has no mesh" % label).is_not_null()
	if mesh == null:
		return
	assert_int(mesh.get_surface_count()).override_failure_message("%s must be one surface" % label).is_equal(1)
	var fmt: int = mesh.surface_get_format(0)
	assert_bool(fmt & Mesh.ARRAY_FORMAT_COLOR != 0).override_failure_message("%s has no vertex colours" % label).is_true()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: Variant = arrays[Mesh.ARRAY_INDEX]  # null for the non-indexed generated meshes
	var tris := ((idx as PackedInt32Array).size() if idx != null else verts.size()) / 3
	assert_int(tris).override_failure_message("%s: %d tris over budget %d" % [label, tris, budget]).is_less_equal(budget)
	assert_int(tris).is_greater(50)
	var aabb := mesh.get_aabb()
	assert_float(aabb.position.y).override_failure_message("%s min y %.3f, expected ~0 (feet origin)" % [label, aabb.position.y]).is_equal_approx(0.0, 0.03)
	assert_float(aabb.size.y).is_greater(0.4)


func test_enemy_meshes_single_surface_vertex_coloured_within_budget() -> void:
	for id: StringName in ENEMY_BUDGET:
		var e := Content.enemy(id)
		assert_object(e).is_not_null()
		_check_mesh(e.mesh, ENEMY_BUDGET[id], String(id))


func test_enemy_mesh_footprint_matches_radius() -> void:
	# Bodies may overhang the collision circle (splayed legs, pads, the runner's
	# tail) but must stay in proportion to it.
	for id: StringName in ENEMY_BUDGET:
		var e := Content.enemy(id)
		var aabb := e.mesh.get_aabb()
		var half := maxf(aabb.size.x, aabb.size.z) * 0.5
		assert_float(half).override_failure_message("%s body half-extent %.2f vs radius %.2f" % [id, half, e.radius]).is_between(e.radius * 0.8, e.radius * 2.6)


func test_player_meshes() -> void:
	var packed: PackedScene = load("res://entities/player/player.tscn")
	var p: Node = auto_free(packed.instantiate())
	var body := p.get_node("Body/Mesh") as MeshInstance3D
	var gun := p.get_node("Body/Gun") as MeshInstance3D
	_check_mesh(body.mesh, PLAYER_BUDGET, "player")
	assert_object(gun.mesh).is_not_null()
	assert_object(body.material_override).is_instanceof(ShaderMaterial)
	# The muzzle flash sits at the rifle's barrel tip, in front of the body.
	var muzzle := p.get_node("Body/MuzzleFlash") as Node3D
	assert_float(muzzle.position.z).is_less(gun.position.z - 0.5)


func test_portraits_exist_for_every_character() -> void:
	for id: StringName in [&"player", &"drone", &"runner", &"tank", &"boss_broodmother"]:
		var tex := Portraits.texture(id)
		assert_object(tex).override_failure_message("missing portrait for %s" % id).is_not_null()
		if tex != null:
			assert_int(tex.get_width()).is_equal(256)
			assert_int(tex.get_height()).is_equal(256)
	assert_object(Portraits.texture(&"nobody")).is_null()
	assert_object(auto_free(Portraits.make_icon(&"nobody", 32))).is_instanceof(ColorRect)
