## Local JSON Lines telemetry: user://telemetry/YYYYMMDD.jsonl
## Same {ts, session_id, event, payload} shape a server would receive later.
class_name Telemetry
extends RefCounted

static var enabled := true
static var session_id := ""
static var dir := "user://telemetry"


static func log(event: StringName, payload: Dictionary = {}) -> void:
	if not enabled:
		return
	if session_id.is_empty():
		session_id = "%x" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(dir)
	var day := Time.get_date_string_from_system(true).replace("-", "")
	var f := FileAccess.open(dir.path_join(day + ".jsonl"), FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(dir.path_join(day + ".jsonl"), FileAccess.WRITE)
		if f == null:
			return
	f.seek_end()
	f.store_line(JSON.stringify({"ts": Time.get_unix_time_from_system(), "session_id": session_id, "event": String(event), "payload": payload}))
	f.close()
