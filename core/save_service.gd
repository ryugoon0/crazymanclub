## JSON save/load with schema version, atomic write and one backup.
## Never loads Resources from user:// (script execution risk). Paths are
## overridable so tests can use a temp directory.
extends Node

const SCHEMA_VERSION := 1

var save_dir: String = "user://saves"
var file_name: String = "profile.json"

var last_error: String = ""


func path() -> String:
	return save_dir.path_join(file_name)


func backup_path() -> String:
	return save_dir.path_join(file_name.get_basename() + ".bak.json")


func save_dict(data: Dictionary) -> bool:
	last_error = ""
	DirAccess.make_dir_recursive_absolute(save_dir)
	var tmp := path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "open tmp failed: %d" % FileAccess.get_open_error()
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var d := DirAccess.open(save_dir)
	if d == null:
		last_error = "open dir failed"
		return false
	if d.file_exists(file_name):
		d.remove(file_name.get_basename() + ".bak.json")
		var err := d.rename(file_name, file_name.get_basename() + ".bak.json")
		if err != OK:
			last_error = "backup rename failed: %d" % err
			return false
	var err2 := d.rename(tmp.get_file(), file_name)
	if err2 != OK:
		last_error = "final rename failed: %d" % err2
		return false
	return true


## Returns {} when nothing valid exists. Tries the backup when the main file
## is missing or corrupt.
func load_dict() -> Dictionary:
	last_error = ""
	var d := _read(path())
	if d.is_empty():
		d = _read(backup_path())
		if not d.is_empty():
			last_error = "main save unreadable, backup used"
	if d.is_empty():
		return {}
	return migrate(d)


func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and (parsed as Dictionary).has("schema_version"):
		return parsed
	return {}


## Migration chain. Each step lifts version n to n+1.
func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("schema_version", 0))
	while v < SCHEMA_VERSION:
		match v:
			0:
				d["schema_version"] = 1
			_:
				break
		v = int(d.get("schema_version", 0))
	return d


func save_profile() -> bool:
	return save_dict(Profile.to_dict())


func load_profile() -> bool:
	var d := load_dict()
	if d.is_empty():
		return false
	return Profile.from_dict(d)


func wipe() -> void:
	var d := DirAccess.open(save_dir)
	if d == null:
		return
	d.remove(file_name)
	d.remove(file_name.get_basename() + ".bak.json")
