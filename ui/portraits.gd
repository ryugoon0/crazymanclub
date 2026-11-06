## Character portraits rendered offline by tools/art/render_portraits.tscn to
## res://assets/portraits/<id>.png. A missing portrait returns null so screens
## fall back to text / a colour swatch instead of breaking.
class_name Portraits
extends RefCounted

const DIR := "res://assets/portraits"

static var _cache: Dictionary = {}


static func texture(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path := "%s/%s.png" % [DIR, String(id)]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[id] = tex
	return tex


## Square portrait control of `size` px: the texture when it exists, otherwise
## a swatch in `fallback_color` so the slot still reads as that character.
static func make_icon(id: StringName, size: int, fallback_color: Color = Color(0.3, 0.3, 0.34)) -> Control:
	var tex := texture(id)
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(size, size)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.name = "Portrait_%s" % String(id)
		return r
	var c := ColorRect.new()
	c.color = fallback_color.darkened(0.35)
	c.custom_minimum_size = Vector2(size, size)
	c.name = "Swatch_%s" % String(id)
	return c
