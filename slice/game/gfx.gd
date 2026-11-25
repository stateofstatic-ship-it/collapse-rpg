class_name Gfx
extends RefCounted
## Shared art helpers: lit textures, the iso tile set, light textures.

const TILE := Vector2i(128, 64)
static var _cache: Dictionary = {}


static func canvas_tex(tex_name: String) -> CanvasTexture:
	if _cache.has(tex_name):
		return _cache[tex_name]
	var t := CanvasTexture.new()
	t.diffuse_texture = load("res://assets/%s.png" % tex_name)
	var n_path := "res://assets/%s_n.png" % tex_name
	if ResourceLoader.exists(n_path):
		t.normal_texture = load(n_path)
	_cache[tex_name] = t
	return t


static func make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = TILE
	var src := TileSetAtlasSource.new()
	src.texture = canvas_tex("tiles")
	src.texture_region_size = TILE
	for y in 4:
		for x in 8:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	return ts


static func light_tex() -> Texture2D:
	if _cache.has("__light"):
		return _cache["__light"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	_cache["__light"] = t
	return t


static func streak_tex() -> Texture2D:
	if _cache.has("__streak"):
		return _cache["__streak"]
	var img := Image.create(4, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		var a := float(y) / 31.0
		for x in 4:
			var edge := 1.0 if x in [1, 2] else 0.35
			img.set_pixel(x, y, Color(0.75, 0.82, 0.95, a * 0.8 * edge))
	var t := ImageTexture.create_from_image(img)
	_cache["__streak"] = t
	return t


const SKIN_SHADER := """
shader_type canvas_item;
uniform vec3 skin_dark : source_color = vec3(0.30, 0.18, 0.12);
uniform vec3 skin_light : source_color = vec3(0.86, 0.66, 0.52);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(skin_dark, skin_light, c.r) , c.a) * COLOR;
}
"""


static func skin_material(dark: Color, light: Color) -> ShaderMaterial:
	if not _cache.has("__skin_shader"):
		var sh := Shader.new()
		sh.code = SKIN_SHADER
		_cache["__skin_shader"] = sh
	var m := ShaderMaterial.new()
	m.shader = _cache["__skin_shader"]
	m.set_shader_parameter("skin_dark", dark)
	m.set_shader_parameter("skin_light", light)
	return m
