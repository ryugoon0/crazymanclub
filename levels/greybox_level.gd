## Grey-box level root. Exposes what the swarm needs: spawn points and
## obstacles approximated as circles (boxes are tiled with circles along
## their longer axis). Nodes: children in group "obstacle" (MeshInstance3D
## with a BoxMesh, sitting on a StaticBody3D) and Marker3D in "spawn_point".
class_name GreyboxLevel
extends Node3D

## Radius padding so enemies do not clip the visual box edge.
@export var obstacle_padding: float = 0.1


func spawn_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in get_tree().get_nodes_in_group("spawn_point"):
		if n is Node3D and is_ancestor_of(n):
			out.append((n as Node3D).global_position)
	return out


func obstacle_circles() -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in get_tree().get_nodes_in_group("obstacle"):
		if not (n is MeshInstance3D) or not is_ancestor_of(n):
			continue
		var mi := n as MeshInstance3D
		var box := mi.mesh as BoxMesh
		if box == null:
			continue
		var size := box.size * mi.global_transform.basis.get_scale()
		var center := mi.global_position
		var half_x := size.x * 0.5
		var half_z := size.z * 0.5
		var r := minf(half_x, half_z) + obstacle_padding
		var along_x := half_x >= half_z
		var length := (half_x if along_x else half_z) - minf(half_x, half_z)
		var steps := maxi(1, ceili(length / r))
		for s: int in range(-steps, steps + 1):
			var off := (float(s) / float(steps)) * length if steps > 0 else 0.0
			var c := center + (Vector3(off, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, off))
			out.append(Vector3(c.x, c.z, r))
	return out
