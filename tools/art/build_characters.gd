## Procedural low-poly character bodies (art draft). Deterministic, re-runnable:
##   godot --headless --path . -s res://tools/art/build_characters.gd
## Writes one single-surface ArrayMesh per character to res://assets/models/<id>.res.
## Everything is built from convex primitives (boxes, tapered "bones", prisms,
## spheres) with flat shading, so the meshes are 100% original and license-free.
##
## Vertex attribute contract (read by fx/character.gdshader; only COLOR/UV/UV2
## are used because CUSTOM0 does not reach the gl_compatibility renderer):
##   COLOR   rgb = tint multiplied with the type colour (MultiMesh instance
##           colour, or the `base_color` uniform). 1.0 = the type colour,
##           <1.0 = darker chitin/joints. Values never exceed 1.0 (RGBA8).
##           a = how much a palette colour replaces the tinted colour.
##   UV      x = emission strength, y = 0 glow in the type colour / 1 hot orange
##   UV2     x = limb swing weight, sign = gait phase group (+ = 0, - = 1)
##           y = palette index (PAL_*; bone, gunmetal, steel, white, egg)
## Origin is at the feet (y = 0), the character faces -Z.
extends SceneTree

const OUT_DIR := "res://assets/models"
## Palette indices; the colours live in fx/character.gdshader (palette()).
const PAL_BONE := 1
const PAL_GUNMETAL := 2
const PAL_GUNMETAL_DARK := 3
const PAL_STEEL := 4
const PAL_WHITE := 5
const PAL_EGG := 6

## Triangle budgets (tests/test_character_meshes.gd checks the same numbers).
const BUDGET := {
	"drone": 600, "runner": 600, "tank": 900, "boss_broodmother": 3000, "player": 2500, "player_rifle": 2500,
}


class Style:
	var col := Color(1, 1, 1)
	var pal := 0
	var pal_mix := 0.0
	var em := 0.0
	var hot_v := 0.0
	var sw := 0.0
	var sw_ph := 0.0
	var sw_top := NAN
	var sw_bot := NAN

	static func make(tint_k: float = 1.0) -> Style:
		var s := Style.new()
		s.col = Color(tint_k, tint_k, tint_k)
		return s

	## Blend toward a palette colour (amount 1 replaces the type colour).
	func absolute(index: int, amount: float = 1.0) -> Style:
		pal = index
		pal_mix = amount
		return self

	## Lighter variant of the type colour (blend toward white).
	func lighten(amount: float) -> Style:
		return absolute(PAL_WHITE, amount)

	func emissive(strength: float, hot: float = 0.0) -> Style:
		em = strength
		hot_v = hot
		return self

	## Limb swing: weight graded from `bot` (full) to `top` (none) in mesh space.
	## Without a range the part's own y extent is used. `phase` 0/1 alternates.
	func swing(weight: float, phase: float, top: float = NAN, bot: float = NAN) -> Style:
		sw = weight
		sw_ph = phase
		sw_top = top
		sw_bot = bot
		return self

	## Constant swing weight (abdomen wobble, tail wag).
	func wobble(weight: float, phase: float) -> Style:
		sw = weight
		sw_ph = phase
		sw_top = 0.0
		sw_bot = 0.0
		return self

	func dup() -> Style:
		var s := Style.new()
		s.col = col; s.pal = pal; s.pal_mix = pal_mix; s.em = em; s.hot_v = hot_v
		s.sw = sw; s.sw_ph = sw_ph; s.sw_top = sw_top; s.sw_bot = sw_bot
		return s


class Body:
	var st := SurfaceTool.new()
	var tris := 0

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## Emit a convex part: `verts` in local space, `faces` as vertex index
	## polygons. Winding is fixed against the part centroid, normals are flat.
	func part(verts: PackedVector3Array, faces: Array, xf: Transform3D, s: Style) -> void:
		var w := PackedVector3Array()
		w.resize(verts.size())
		var centroid := Vector3.ZERO
		var y_min := INF
		var y_max := -INF
		for i: int in range(verts.size()):
			var v := xf * verts[i]
			w[i] = v
			centroid += v
			y_min = minf(y_min, v.y)
			y_max = maxf(y_max, v.y)
		centroid /= float(verts.size())
		var top := s.sw_top if not is_nan(s.sw_top) else y_max
		var bot := s.sw_bot if not is_nan(s.sw_bot) else y_min
		for face: PackedInt32Array in faces:
			var poly := PackedVector3Array()
			for idx: int in face:
				poly.append(w[idx])
			_emit_polygon(poly, s, centroid, top, bot)

	func _emit_polygon(poly: PackedVector3Array, s: Style, part_center: Vector3, top: float, bot: float) -> void:
		# Drop coincident vertices (spikes have a zero-size top face).
		var clean := PackedVector3Array()
		for p: Vector3 in poly:
			if clean.is_empty() or clean[clean.size() - 1].distance_squared_to(p) > 1e-8:
				clean.append(p)
		if clean.size() > 1 and clean[0].distance_squared_to(clean[clean.size() - 1]) <= 1e-8:
			clean.remove_at(clean.size() - 1)
		if clean.size() < 3:
			return
		var n := Vector3.ZERO
		var fc := Vector3.ZERO
		for i: int in range(clean.size()):
			n += (clean[i] - clean[0]).cross(clean[(i + 1) % clean.size()] - clean[0])
			fc += clean[i]
		fc /= float(clean.size())
		if n.length_squared() < 1e-10:
			return
		n = n.normalized()
		if n.dot(fc - part_center) < 0.0:
			clean.reverse()
			n = -n
		for i: int in range(1, clean.size() - 1):
			_vertex(clean[0], n, s, top, bot)
			_vertex(clean[i], n, s, top, bot)
			_vertex(clean[i + 1], n, s, top, bot)
			tris += 1

	func _vertex(p: Vector3, n: Vector3, s: Style, top: float, bot: float) -> void:
		var w := 0.0
		if s.sw > 0.0:
			if top > bot + 1e-6:
				w = s.sw * clampf((top - p.y) / (top - bot), 0.0, 1.0)
			else:
				w = s.sw
		st.set_color(Color(s.col.r, s.col.g, s.col.b, s.pal_mix))
		st.set_uv(Vector2(s.em, s.hot_v))
		st.set_uv2(Vector2(-w if s.sw_ph >= 0.5 else w, float(s.pal)))
		st.set_normal(n)
		st.add_vertex(p)

	# --- primitives (local space, centred unless stated) -------------------

	## Tapered box: bottom face at y = 0 (size `b`), top face at y = h (size `t`,
	## shifted by `t_off` on xz). `t` = (0,0) makes a four-sided spike.
	func frustum(xf: Transform3D, b: Vector2, t: Vector2, h: float, s: Style, t_off: Vector2 = Vector2.ZERO) -> void:
		var v := PackedVector3Array([
			Vector3(-b.x * 0.5, 0.0, -b.y * 0.5), Vector3(b.x * 0.5, 0.0, -b.y * 0.5),
			Vector3(b.x * 0.5, 0.0, b.y * 0.5), Vector3(-b.x * 0.5, 0.0, b.y * 0.5),
			Vector3(-t.x * 0.5 + t_off.x, h, -t.y * 0.5 + t_off.y), Vector3(t.x * 0.5 + t_off.x, h, -t.y * 0.5 + t_off.y),
			Vector3(t.x * 0.5 + t_off.x, h, t.y * 0.5 + t_off.y), Vector3(-t.x * 0.5 + t_off.x, h, t.y * 0.5 + t_off.y),
		])
		var f: Array = [
			PackedInt32Array([0, 1, 2, 3]), PackedInt32Array([4, 5, 6, 7]),
			PackedInt32Array([0, 1, 5, 4]), PackedInt32Array([1, 2, 6, 5]),
			PackedInt32Array([2, 3, 7, 6]), PackedInt32Array([3, 0, 4, 7]),
		]
		part(v, f, xf, s)

	## Axis-aligned box centred on the transform origin.
	func box(xf: Transform3D, size: Vector3, s: Style) -> void:
		frustum(xf * Transform3D(Basis.IDENTITY, Vector3(0.0, -size.y * 0.5, 0.0)), Vector2(size.x, size.z), Vector2(size.x, size.z), size.y, s)

	## Tapered box from `a` to `b` (a limb segment). `wa`/`wb` = lateral width,
	## `da`/`db` = depth along the swing plane (default = width).
	func bone(a: Vector3, b: Vector3, wa: float, wb: float, s: Style, da: float = -1.0, db: float = -1.0) -> void:
		var axis := b - a
		var l := axis.length()
		if l < 1e-5:
			return
		var y := axis / l
		var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
		var x := ref.cross(y).normalized()
		var z := y.cross(x).normalized()
		var xf := Transform3D(Basis(x, y, z), a)
		frustum(xf, Vector2(wa, da if da > 0.0 else wa), Vector2(wb, db if db > 0.0 else wb), l, s)

	## n-gon prism/cone from y = 0 to y = h.
	func prism(xf: Transform3D, r_bot: float, r_top: float, h: float, n: int, s: Style) -> void:
		var v := PackedVector3Array()
		for i: int in range(n):
			var a := TAU * float(i) / float(n)
			v.append(Vector3(cos(a) * r_bot, 0.0, sin(a) * r_bot))
		for i: int in range(n):
			var a := TAU * float(i) / float(n)
			v.append(Vector3(cos(a) * r_top, h, sin(a) * r_top))
		var f: Array = []
		var bottom := PackedInt32Array()
		var top := PackedInt32Array()
		for i: int in range(n):
			bottom.append(i)
			top.append(n + i)
			f.append(PackedInt32Array([i, (i + 1) % n, n + (i + 1) % n, n + i]))
		f.append(bottom)
		f.append(top)
		part(v, f, xf, s)

	## Low-poly UV sphere (ellipsoid through the transform's scale), centred.
	func sphere(xf: Transform3D, r: float, lon: int, lat: int, s: Style) -> void:
		var v := PackedVector3Array()
		v.append(Vector3(0.0, r, 0.0))
		for j: int in range(1, lat):
			var t := PI * float(j) / float(lat)
			for i: int in range(lon):
				var a := TAU * float(i) / float(lon)
				v.append(Vector3(sin(t) * cos(a) * r, cos(t) * r, sin(t) * sin(a) * r))
		v.append(Vector3(0.0, -r, 0.0))
		var last := v.size() - 1
		var f: Array = []
		for i: int in range(lon):
			f.append(PackedInt32Array([0, 1 + i, 1 + (i + 1) % lon]))
		for j: int in range(0, lat - 2):
			var a0 := 1 + j * lon
			var b0 := 1 + (j + 1) * lon
			for i: int in range(lon):
				f.append(PackedInt32Array([a0 + i, b0 + i, b0 + (i + 1) % lon, a0 + (i + 1) % lon]))
		var r0 := 1 + (lat - 2) * lon
		for i: int in range(lon):
			f.append(PackedInt32Array([r0 + i, last, r0 + (i + 1) % lon]))
		part(v, f, xf, s)

	func commit(name: String) -> ArrayMesh:
		var mesh := st.commit()
		mesh.resource_name = name
		return mesh


# --- helpers ----------------------------------------------------------------

static func T(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	return Transform3D(b.scaled(scl), pos)


static func S(k: float = 1.0) -> Style:
	return Style.make(k)


static func M(side: float, v: Vector3) -> Vector3:
	return Vector3(v.x * side, v.y, v.z)


# --- characters ---------------------------------------------------------------

## Drone: hunched bipedal bug. Big digitigrade legs, scythe arms, low head with
## mandibles, three pale carapace plates on the back, glowing eyes.
static func build_drone() -> ArrayMesh:
	var b := Body.new()
	var hip_y := 0.56
	for side: float in [-1.0, 1.0]:
		var ph := 0.0 if side < 0.0 else 1.0
		var leg := S(0.72).swing(1.0, ph, hip_y, 0.0)
		var hip := M(side, Vector3(0.2, hip_y, 0.02))
		var knee := M(side, Vector3(0.27, 0.4, -0.22))
		var ankle := M(side, Vector3(0.29, 0.14, 0.1))
		var toe := M(side, Vector3(0.29, 0.02, -0.26))
		b.bone(hip, knee, 0.16, 0.11, leg, 0.2, 0.13)
		b.bone(knee, ankle, 0.1, 0.08, leg)
		b.bone(ankle, toe, 0.1, 0.06, leg, 0.1, 0.03)
		b.sphere(T(knee), 0.085, 6, 3, S(0.45).swing(1.0, ph, hip_y, 0.0))
		# scythe arms (counter-phase to the leg on the same side)
		var arm := S(0.65).swing(0.5, 1.0 - ph, 0.9, 0.3)
		var shoulder := M(side, Vector3(0.3, 0.9, -0.1))
		var elbow := M(side, Vector3(0.42, 0.7, -0.4))
		var tip := M(side, Vector3(0.22, 0.32, -0.7))
		b.bone(shoulder, elbow, 0.11, 0.08, arm)
		b.bone(elbow, tip, 0.08, 0.01, S(0.7).absolute(PAL_BONE, 0.8).swing(0.5, 1.0 - ph, 0.9, 0.3), 0.1, 0.02)
		# mandibles + eyes
		b.bone(M(side, Vector3(0.12, 0.6, -0.64)), M(side, Vector3(0.03, 0.48, -0.86)), 0.07, 0.01, S().absolute(PAL_BONE, 0.9))
		b.sphere(T(M(side, Vector3(0.1, 0.72, -0.66))), 0.055, 6, 3, S().emissive(1.0))
	# pelvis + thorax (tilted forward) + abdomen (sags behind)
	b.box(T(Vector3(0.0, hip_y + 0.02, 0.0)), Vector3(0.42, 0.22, 0.34), S(0.8))
	b.sphere(T(Vector3(0.0, 0.8, -0.06), Vector3(22.0, 0.0, 0.0), Vector3(0.52, 0.42, 0.66)), 0.5, 8, 4, S())
	b.sphere(T(Vector3(0.0, 0.7, 0.42), Vector3(-10.0, 0.0, 0.0), Vector3(0.38, 0.32, 0.46)), 0.5, 8, 4, S(0.85).wobble(0.25, 1.0))
	# carapace plates (lighter) and spines
	for i: int in range(3):
		var z := -0.22 + float(i) * 0.2
		var y := 1.0 - float(i) * 0.07
		b.frustum(T(Vector3(0.0, y, z), Vector3(-25.0 + float(i) * 6.0, 0.0, 0.0)), Vector2(0.46 - float(i) * 0.06, 0.22), Vector2(0.3 - float(i) * 0.05, 0.14), 0.08, S().lighten(0.35))
		b.frustum(T(Vector3(0.0, y + 0.06, z), Vector3(-40.0, 0.0, 0.0)), Vector2(0.07, 0.07), Vector2.ZERO, 0.16, S(0.5))
	# head
	b.frustum(T(Vector3(0.0, 0.56, -0.46), Vector3(-15.0, 0.0, 0.0)), Vector2(0.3, 0.3), Vector2(0.36, 0.28), 0.24, S(0.9), Vector2(0.0, -0.02))
	b.frustum(T(Vector3(0.0, 0.78, -0.5), Vector3(-30.0, 0.0, 0.0)), Vector2(0.3, 0.2), Vector2(0.16, 0.12), 0.07, S().lighten(0.3))
	return b.commit("drone")


## Runner: low, long, six splayed legs swept back, pointed head, whip tail.
static func build_runner() -> ArrayMesh:
	var b := Body.new()
	var body_y := 0.3
	for side: float in [-1.0, 1.0]:
		for i: int in range(3):
			# tripod gait: outer legs of one side share phase with the middle leg of the other
			var ph := 0.0 if ((i == 1) == (side > 0.0)) else 1.0
			var z := -0.24 + float(i) * 0.22
			var hip := M(side, Vector3(0.14, body_y, z))
			var knee := M(side, Vector3(0.42, 0.5, z + 0.06))
			var foot := M(side, Vector3(0.6, 0.0, z + 0.22))
			var leg := S(0.7).swing(1.0, ph, body_y, 0.0)
			b.bone(hip, knee, 0.06, 0.05, leg, 0.07, 0.05)
			b.bone(knee, foot, 0.045, 0.012, leg)
			b.sphere(T(knee), 0.05, 5, 2, S(0.4).swing(1.0, ph, body_y, 0.0))
		b.sphere(T(M(side, Vector3(0.09, 0.37, -0.52))), 0.045, 6, 3, S().emissive(1.0))
		# jaw hooks
		b.bone(M(side, Vector3(0.07, 0.25, -0.62)), M(side, Vector3(0.02, 0.22, -0.78)), 0.04, 0.01, S().absolute(PAL_BONE, 0.9))
	# body + head wedge
	b.sphere(T(Vector3(0.0, body_y + 0.02, 0.0), Vector3.ZERO, Vector3(0.24, 0.2, 0.56)), 0.5, 8, 4, S())
	b.frustum(T(Vector3(0.0, 0.3, -0.26), Vector3(-90.0, 0.0, 0.0)), Vector2(0.24, 0.2), Vector2(0.1, 0.07), 0.42, S(0.95), Vector2(0.0, -0.02))
	# pale dorsal stripe plates (speed streak) + head crest
	for i: int in range(3):
		var z := -0.2 + float(i) * 0.17
		b.frustum(T(Vector3(0.0, 0.42 - float(i) * 0.02, z), Vector3(-6.0, 0.0, 0.0)), Vector2(0.14, 0.14), Vector2(0.06, 0.08), 0.05, S().lighten(0.4))
	b.frustum(T(Vector3(0.0, 0.34, -0.42), Vector3(-55.0, 0.0, 0.0)), Vector2(0.06, 0.08), Vector2.ZERO, 0.18, S(0.5))
	# tail: two segments that wag
	b.bone(Vector3(0.0, 0.3, 0.26), Vector3(0.0, 0.4, 0.62), 0.09, 0.05, S(0.85).wobble(0.2, 1.0), 0.09, 0.05)
	b.bone(Vector3(0.0, 0.4, 0.62), Vector3(0.0, 0.58, 0.95), 0.05, 0.01, S(0.6).wobble(0.5, 1.0))
	return b.commit("runner")


## Tank: top-heavy brute. Thick legs, inverted-trapezoid torso, huge shoulder
## pads, forearm shields held in front, tiny head sunk between the shoulders,
## glowing vents on the back hump.
static func build_tank() -> ArrayMesh:
	var b := Body.new()
	var hip_y := 0.72
	for side: float in [-1.0, 1.0]:
		var ph := 0.0 if side < 0.0 else 1.0
		var leg := S(0.72).swing(1.0, ph, hip_y, 0.0)
		var hip := M(side, Vector3(0.3, hip_y, 0.0))
		var knee := M(side, Vector3(0.36, 0.38, -0.1))
		var foot := M(side, Vector3(0.38, 0.08, 0.04))
		b.bone(hip, knee, 0.32, 0.26, leg, 0.34, 0.28)
		b.bone(knee, foot, 0.28, 0.3, leg, 0.26, 0.4)
		b.box(T(M(side, Vector3(0.38, 0.05, 0.02))), Vector3(0.32, 0.1, 0.44), S(0.5).swing(1.0, ph, hip_y, 0.0))
		b.box(T(M(side, Vector3(0.36, 0.42, -0.22))), Vector3(0.2, 0.18, 0.1), S(0.45).swing(1.0, ph, hip_y, 0.0))
		# shoulder pads with spikes
		var pad := M(side, Vector3(0.82, 1.72, 0.0))
		b.sphere(T(pad, Vector3.ZERO, Vector3(0.5, 0.36, 0.56)), 0.5, 8, 4, S(0.95).lighten(0.12))
		for k: int in range(3):
			b.frustum(T(pad + Vector3(0.0, 0.1, -0.14 + float(k) * 0.14), Vector3(0.0, 0.0, -side * 25.0)), Vector2(0.09, 0.09), Vector2.ZERO, 0.26, S(0.5))
		# arms + forearm shields (counter-phase, small swing)
		var arm := S(0.7).swing(0.25, 1.0 - ph, 1.7, 0.6)
		var elbow := M(side, Vector3(0.98, 1.15, -0.18))
		var fist := M(side, Vector3(0.82, 0.62, -0.5))
		b.bone(pad + Vector3(0.0, -0.1, 0.0), elbow, 0.3, 0.26, arm)
		b.bone(elbow, fist, 0.3, 0.36, arm, 0.3, 0.3)
		b.box(T(fist + Vector3(0.0, -0.1, -0.04)), Vector3(0.34, 0.26, 0.3), S(0.5).swing(0.25, 1.0 - ph, 1.7, 0.6))
		b.box(T(M(side, Vector3(0.78, 0.95, -0.52)), Vector3(10.0, side * 20.0, 0.0)), Vector3(0.52, 0.78, 0.1), S().lighten(0.3).swing(0.25, 1.0 - ph, 1.7, 0.6))
		b.box(T(M(side, Vector3(0.78, 0.95, -0.58)), Vector3(10.0, side * 20.0, 0.0)), Vector3(0.26, 0.5, 0.04), S(0.5).swing(0.25, 1.0 - ph, 1.7, 0.6))
		# eyes
		b.sphere(T(M(side, Vector3(0.09, 1.8, -0.62))), 0.045, 6, 3, S().emissive(1.0))
	b.box(T(Vector3(0.0, hip_y + 0.08, 0.0)), Vector3(0.78, 0.4, 0.56), S(0.8))
	b.frustum(T(Vector3(0.0, 0.98, 0.0)), Vector2(0.86, 0.62), Vector2(1.3, 0.86), 0.72, S(), Vector2(0.0, 0.02))
	b.box(T(Vector3(0.0, 1.36, -0.4)), Vector3(0.7, 0.44, 0.12), S().lighten(0.22))
	b.sphere(T(Vector3(0.0, 1.78, 0.22), Vector3(-12.0, 0.0, 0.0), Vector3(0.64, 0.42, 0.6)), 0.5, 8, 4, S(0.85))
	for k: int in range(3):
		b.box(T(Vector3(-0.16 + float(k) * 0.16, 1.98, 0.26), Vector3(-20.0, 0.0, 0.0)), Vector3(0.07, 0.04, 0.2), S().emissive(0.9, 0.35))
	# head: low box between the shoulders + jaw plate
	b.frustum(T(Vector3(0.0, 1.62, -0.48), Vector3(-12.0, 0.0, 0.0)), Vector2(0.3, 0.3), Vector2(0.34, 0.26), 0.28, S(0.7))
	b.box(T(Vector3(0.0, 1.66, -0.6)), Vector3(0.36, 0.1, 0.1), S().absolute(PAL_BONE, 0.7))
	return b.commit("tank")


## Boss Broodmother: a huge egg-laden abdomen on eight arched legs, raised
## thorax, crowned head with four eyes and heavy mandibles, two scythe
## fore-claws. Pale egg sacs glow softly.
static func build_boss() -> ArrayMesh:
	var b := Body.new()
	var hip_y := 1.6
	for side: float in [-1.0, 1.0]:
		for i: int in range(4):
			var ph := 0.0 if ((i % 2 == 0) == (side > 0.0)) else 1.0
			var z := -0.7 + float(i) * 0.5
			var spread := 0.3 + absf(float(i) - 1.5) * 0.25
			var hip := M(side, Vector3(0.7, hip_y, z))
			var knee := M(side, Vector3(1.7, 2.45, z + (float(i) - 1.5) * 0.25))
			var foot := M(side, Vector3(2.2, 0.0, z + (float(i) - 1.5) * spread))
			var leg := S(0.6).swing(2.2, ph, hip_y + 0.8, 0.0)
			b.bone(hip, knee, 0.26, 0.18, leg, 0.3, 0.2)
			b.bone(knee, foot, 0.17, 0.05, leg)
			b.sphere(T(knee), 0.16, 6, 3, S(0.4).swing(2.2, ph, hip_y + 0.8, 0.0))
			b.frustum(T(knee + Vector3(0.0, 0.1, 0.0)), Vector2(0.14, 0.14), Vector2.ZERO, 0.4, S(0.45).swing(2.2, ph, hip_y + 0.8, 0.0))
		# fore-claws
		var claw := S(0.55).swing(0.8, 1.0 if side < 0.0 else 0.0, 2.6, 0.8)
		var shoulder := M(side, Vector3(0.6, 2.2, -0.8))
		var elbow := M(side, Vector3(1.25, 2.9, -1.35))
		var tip := M(side, Vector3(0.7, 0.9, -2.1))
		b.bone(shoulder, elbow, 0.26, 0.2, claw)
		b.bone(elbow, tip, 0.2, 0.02, S(0.8).absolute(PAL_BONE, 0.75).swing(0.8, 1.0 if side < 0.0 else 0.0, 2.6, 0.8), 0.24, 0.04)
		# mandibles + eyes (two big, two small)
		b.bone(M(side, Vector3(0.3, 2.1, -1.5)), M(side, Vector3(0.12, 1.7, -2.05)), 0.16, 0.02, S().absolute(PAL_BONE, 0.9), 0.2, 0.04)
		b.sphere(T(M(side, Vector3(0.24, 2.44, -1.5))), 0.12, 8, 4, S().emissive(1.0, 0.25))
		b.sphere(T(M(side, Vector3(0.42, 2.34, -1.36))), 0.07, 6, 3, S().emissive(1.0, 0.25))
	# abdomen with egg sacs
	var ab_c := Vector3(0.0, 1.5, 1.1)
	var ab_s := Vector3(1.3, 1.05, 1.55)
	b.sphere(T(ab_c, Vector3.ZERO, ab_s), 1.0, 12, 6, S())
	var egg := S().absolute(PAL_EGG, 0.55).emissive(0.35)
	for k: int in range(11):
		var a := float(k) * 2.399963 + 0.6  # golden angle, deterministic
		var t := 0.45 + 0.42 * (float(k % 4) / 3.0)  # polar band on the upper half
		var dir := Vector3(sin(t) * cos(a), cos(t) * 0.9, sin(t) * sin(a) * 0.95)
		var p := ab_c + dir * ab_s * 0.96
		if p.y < 1.0:
			continue
		var r := 0.2 + 0.1 * float((k * 7) % 3) / 2.0
		b.sphere(T(p), r, 8, 4, egg)
	# thorax, dorsal plates, neck, head, crown
	b.sphere(T(Vector3(0.0, 2.0, -0.3), Vector3(18.0, 0.0, 0.0), Vector3(0.95, 0.8, 1.05)), 1.0, 10, 5, S())
	for i: int in range(3):
		b.frustum(T(Vector3(0.0, 2.72 - float(i) * 0.12, -0.55 + float(i) * 0.4), Vector3(-25.0 + float(i) * 10.0, 0.0, 0.0)), Vector2(0.9 - float(i) * 0.12, 0.42), Vector2(0.6 - float(i) * 0.1, 0.26), 0.14, S().lighten(0.3))
	b.frustum(T(Vector3(0.0, 2.1, -1.0), Vector3(-80.0, 0.0, 0.0)), Vector2(0.7, 0.6), Vector2(0.55, 0.5), 0.5, S(0.9))
	b.frustum(T(Vector3(0.0, 2.2, -1.35), Vector3(-100.0, 0.0, 0.0)), Vector2(0.6, 0.5), Vector2(0.4, 0.3), 0.55, S(0.95), Vector2(0.0, 0.08))
	for k: int in range(7):
		var a := -PI * 0.5 + PI * (float(k) / 6.0 - 0.5) * 1.5
		var base := Vector3(cos(a) * 0.36, 2.5, -1.3 + sin(a) * 0.3)
		b.frustum(T(base, Vector3(-35.0 + absf(float(k) - 3.0) * 8.0, 0.0, -cos(a) * 45.0)), Vector2(0.14, 0.14), Vector2.ZERO, 0.55 + 0.25 * (1.0 - absf(float(k) - 3.0) / 3.0), S(0.5).lighten(0.1))
	return b.commit("boss_broodmother")


## Player: armoured RECLAIMER mercenary. Gunmetal plate with orange (type
## colour) accents, glowing visor, shoulder pads, back power pack. The rifle is
## a separate mesh (build_rifle) so the Gun/MuzzleFlash nodes stay in place.
static func build_player() -> ArrayMesh:
	var b := Body.new()
	var metal := S().absolute(PAL_GUNMETAL)
	var dark := S().absolute(PAL_GUNMETAL_DARK)
	var steel := S().absolute(PAL_STEEL)
	var hip_y := 0.96
	for side: float in [-1.0, 1.0]:
		var ph := 0.0 if side < 0.0 else 1.0
		var leg_metal := metal.dup().swing(1.0, ph, hip_y, 0.0)
		var leg_dark := dark.dup().swing(1.0, ph, hip_y, 0.0)
		var hip := M(side, Vector3(0.15, hip_y, 0.0))
		var knee := M(side, Vector3(0.16, 0.52, -0.03))
		var ankle := M(side, Vector3(0.17, 0.14, 0.0))
		b.bone(hip, knee, 0.2, 0.17, leg_dark, 0.24, 0.19)
		b.bone(knee, ankle, 0.17, 0.15, leg_metal, 0.18, 0.16)
		b.box(T(M(side, Vector3(0.17, 0.1, -0.04))), Vector3(0.22, 0.2, 0.36), leg_dark)
		b.box(T(M(side, Vector3(0.17, 0.08, -0.2))), Vector3(0.18, 0.1, 0.08), S().swing(1.0, ph, hip_y, 0.0))
		b.box(T(knee + Vector3(0.0, 0.02, -0.1)), Vector3(0.16, 0.16, 0.08), S().swing(1.0, ph, hip_y, 0.0))
		# shoulder pads (accent) + upper arms
		var pad := M(side, Vector3(0.34, 1.56, -0.02))
		b.frustum(T(pad + Vector3(0.0, -0.12, 0.0), Vector3(0.0, 0.0, -side * 18.0)), Vector2(0.24, 0.3), Vector2(0.3, 0.34), 0.22, S())
		b.box(T(pad + Vector3(0.0, 0.08, 0.0), Vector3(0.0, 0.0, -side * 18.0)), Vector3(0.26, 0.05, 0.3), steel)
		var shoulder := M(side, Vector3(0.36, 1.46, -0.02))
		var elbow := M(side, Vector3(0.4, 1.18, -0.06))
		b.bone(shoulder, elbow, 0.15, 0.13, metal)
	# right forearm to the grip, left forearm to the fore-end
	b.bone(Vector3(0.4, 1.18, -0.06), Vector3(0.24, 1.1, -0.34), 0.13, 0.11, metal)
	b.box(T(Vector3(0.23, 1.1, -0.38)), Vector3(0.12, 0.12, 0.12), steel)
	b.bone(Vector3(-0.4, 1.18, -0.06), Vector3(-0.0, 1.12, -0.58), 0.13, 0.11, metal)
	b.box(T(Vector3(0.0, 1.12, -0.62)), Vector3(0.12, 0.12, 0.12), steel)
	# pelvis, belt, torso, chest plate, accent stripe
	b.box(T(Vector3(0.0, hip_y + 0.06, 0.0)), Vector3(0.44, 0.24, 0.3), dark)
	b.box(T(Vector3(0.0, hip_y + 0.17, 0.0)), Vector3(0.46, 0.06, 0.32), S())
	b.frustum(T(Vector3(0.0, 1.12, 0.0)), Vector2(0.44, 0.3), Vector2(0.56, 0.36), 0.4, metal)
	b.box(T(Vector3(0.0, 1.36, -0.16)), Vector3(0.4, 0.3, 0.1), steel)
	b.box(T(Vector3(0.0, 1.36, -0.21)), Vector3(0.1, 0.26, 0.02), S())
	b.box(T(Vector3(0.14, 1.26, -0.21)), Vector3(0.06, 0.04, 0.02), S().emissive(1.0, 1.0))
	# neck + helmet + visor + crest + antenna
	b.prism(T(Vector3(0.0, 1.5, 0.0)), 0.08, 0.08, 0.1, 6, dark)
	b.sphere(T(Vector3(0.0, 1.7, 0.0), Vector3.ZERO, Vector3(0.2, 0.21, 0.21)), 1.0, 8, 4, metal)
	b.box(T(Vector3(0.0, 1.7, -0.18)), Vector3(0.24, 0.07, 0.07), S().emissive(1.0, 1.0))
	b.box(T(Vector3(0.0, 1.62, -0.16), Vector3(20.0, 0.0, 0.0)), Vector3(0.2, 0.08, 0.08), dark)
	b.box(T(Vector3(0.0, 1.86, 0.02)), Vector3(0.05, 0.08, 0.28), S())
	b.bone(Vector3(0.16, 1.78, 0.1), Vector3(0.22, 2.0, 0.14), 0.02, 0.01, steel)
	# back power pack with two cells and glowing bands
	b.box(T(Vector3(0.0, 1.26, 0.26)), Vector3(0.38, 0.44, 0.2), dark)
	for side: float in [-1.0, 1.0]:
		b.prism(T(M(side, Vector3(0.11, 1.06, 0.38))), 0.065, 0.065, 0.4, 6, steel)
		b.prism(T(M(side, Vector3(0.11, 1.22, 0.38))), 0.07, 0.07, 0.05, 6, S().emissive(1.0, 1.0))
	return b.commit("player")


## Rifle held in the right hand. Origin at the grip, barrel along -Z; the
## muzzle is at z = -0.7 (player.tscn places MuzzleFlash there).
static func build_rifle() -> ArrayMesh:
	var b := Body.new()
	var metal := S().absolute(PAL_GUNMETAL)
	var dark := S().absolute(PAL_GUNMETAL_DARK)
	var steel := S().absolute(PAL_STEEL)
	b.box(T(Vector3(0.0, 0.03, -0.1)), Vector3(0.08, 0.1, 0.5), metal)
	b.box(T(Vector3(0.0, 0.0, 0.26)), Vector3(0.07, 0.09, 0.26), dark)
	b.box(T(Vector3(0.0, -0.1, -0.06)), Vector3(0.05, 0.14, 0.08), dark)
	b.box(T(Vector3(0.0, -0.08, 0.1), Vector3(-15.0, 0.0, 0.0)), Vector3(0.05, 0.12, 0.05), dark)
	b.prism(T(Vector3(0.0, 0.04, -0.34), Vector3(90.0, 0.0, 0.0)), 0.028, 0.028, 0.38, 6, steel)
	b.box(T(Vector3(0.0, -0.01, -0.45)), Vector3(0.06, 0.04, 0.24), metal)
	b.box(T(Vector3(0.0, 0.11, -0.12)), Vector3(0.03, 0.05, 0.14), steel)
	b.box(T(Vector3(0.0, 0.1, -0.2)), Vector3(0.02, 0.025, 0.02), S().emissive(1.0, 1.0))
	b.box(T(Vector3(0.045, 0.03, -0.1)), Vector3(0.01, 0.04, 0.3), S())
	b.prism(T(Vector3(0.0, 0.04, -0.68), Vector3(90.0, 0.0, 0.0)), 0.036, 0.036, 0.05, 6, S().emissive(0.8, 1.0))
	return b.commit("player_rifle")


# --- driver -------------------------------------------------------------------

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var builders := {
		"drone": build_drone, "runner": build_runner, "tank": build_tank,
		"boss_broodmother": build_boss, "player": build_player, "player_rifle": build_rifle,
	}
	var failed := false
	for id: String in builders:
		var mesh: ArrayMesh = (builders[id] as Callable).call()
		var arrays := mesh.surface_get_arrays(0)
		var tris: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		var aabb := mesh.get_aabb()
		var path := "%s/%s.res" % [OUT_DIR, id]
		var err := ResourceSaver.save(mesh, path)
		var over := tris > int(BUDGET[id])
		failed = failed or over or err != OK
		print("%-17s %5d tris (budget %4d)%s  min_y %+.3f  size %s  -> %s%s" % [
			id, tris, int(BUDGET[id]), " OVER BUDGET" if over else "", aabb.position.y,
			"%.2f x %.2f x %.2f" % [aabb.size.x, aabb.size.y, aabb.size.z], path, "" if err == OK else " SAVE ERROR %d" % err])
	quit(1 if failed else 0)
