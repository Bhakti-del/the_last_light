extends Node
## Procedural comic-panel rasteriser. Panels are drawn into an Image at runtime
## (paper grain, ink borders, halftone shading, stains, tally marks) and used as
## the backdrop for Label3D lettering. No image files ship with the project.

const INK := Color(0.055, 0.05, 0.06)
const INK_SOFT := Color(0.14, 0.13, 0.15)

var _cache: Dictionary = {}

const PAPERS := {
	"newsprint": Color(0.90, 0.86, 0.77),
	"cheap": Color(0.94, 0.91, 0.80),
	"dark": Color(0.62, 0.60, 0.56),
	"basement": Color(0.55, 0.54, 0.52),
	"photo": Color(0.86, 0.85, 0.83),
	"card": Color(0.88, 0.82, 0.70),
}


func _paper(style: String) -> Color:
	return PAPERS.get(style, PAPERS["newsprint"])


## Cached panel backdrop. `style` picks the paper stock, `art` picks the layout.
func panel(style: String, art: String, w: int = 384, h: int = 288, seed_value: int = 0) -> ImageTexture:
	var key := "%s|%s|%dx%d|%d" % [style, art, w, h, seed_value]
	if _cache.has(key):
		return _cache[key]
	var tex := _render(style, art, w, h, seed_value)
	_cache[key] = tex
	return tex


func _render(style: String, art: String, w: int, h: int, seed_value: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value) + 1
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var paper := _paper(style)

	# 1. paper base + grain
	img.fill(paper)
	_grain(img, rng, 0.055 if style != "photo" else 0.03)

	# 2. large soft stains / foxing
	match art:
		"wall_panel":
			_stains(img, rng, 4, 0.16)
			_halftone(img, rng, w, h, 6, 0.30, _grad_dir)
		"note":
			_stains(img, rng, 2, 0.10)
			_lines_ruled(img, rng, h)
		"record":
			_stains(img, rng, 3, 0.20)
			_halftone(img, rng, w, h, 5, 0.22, _grad_up)
		"poster":
			_stains(img, rng, 5, 0.22)
			_halftone(img, rng, w, h, 7, 0.34, _grad_corner)
		"scrap":
			_stains(img, rng, 6, 0.24)
		"tally":
			_stains(img, rng, 5, 0.28)
			_halftone(img, rng, w, h, 5, 0.18, _grad_full)
			_tallies(img, rng, w, h)
		"action":
			_stains(img, rng, 2, 0.14)
			_speed_lines(img, rng, w, h)
		"memory":
			_stains(img, rng, 3, 0.18)
			_halftone(img, rng, w, h, 4, 0.40, _grad_full)
		"endcard":
			_stains(img, rng, 2, 0.10)
		_:
			_stains(img, rng, 2, 0.12)

	# 3. ink border, hand-drawn wobble
	var ink := INK if style != "photo" else INK_SOFT
	_border(img, w, h, rng, ink, 5 if art != "tally" else 4)

	return ImageTexture.create_from_image(img)


# --- Texture passes --------------------------------------------------------

func _grain(img: Image, rng: RandomNumberGenerator, amount: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var n := rng.randf_range(-amount, amount)
			img.set_pixel(x, y, Color(
				clampf(c.r + n, 0.0, 1.0),
				clampf(c.g + n, 0.0, 1.0),
				clampf(c.b + n * 0.9, 0.0, 1.0), 1.0))


func _stains(img: Image, rng: RandomNumberGenerator, count: int, strength: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for i in count:
		var cx := rng.randf_range(0.0, float(w))
		var cy := rng.randf_range(0.0, float(h))
		var r := rng.randf_range(0.10, 0.34) * float(maxi(w, h))
		var dark := rng.randf_range(0.55, 1.0)
		for y in h:
			var dy := float(y) - cy
			for x in w:
				var dx := float(x) - cx
				var d := sqrt(dx * dx + dy * dy) / r
				if d >= 1.0:
					continue
				var f: float = pow(1.0 - d, 1.7) * strength * dark
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * (1.0 - f * 0.55), c.g * (1.0 - f * 0.62), c.b * (1.0 - f * 0.75), 1.0))


func _lines_ruled(img: Image, rng: RandomNumberGenerator, h: int) -> void:
	var w := img.get_width()
	var col := INK.lerp(Color(0.45, 0.42, 0.40), 0.55)
	var y := int(h * 0.18)
	while y < h - int(h * 0.12):
		for x in range(int(w * 0.08), int(w * 0.92)):
			if rng.randf() > 0.25:
				img.set_pixel(x, y, col)
		y += maxi(10, h / 12)


## Halftone dot screen. `density` is a 0..1 field function of normalised uv.
func _halftone(img: Image, rng: RandomNumberGenerator, w: int, h: int, cell: int, max_alpha: float, density: Callable) -> void:
	var col := INK
	col.a = max_alpha
	var ca := cos(0.35)
	var sa := sin(0.35)
	for y in h:
		for x in w:
			var u := float(x) / w
			var v := float(y) / h
			var rx := (u - 0.5) * w
			var ry := (v - 0.5) * h
			var gx := (rx * ca - ry * sa) / cell
			var gy := (rx * sa + ry * ca) / cell
			var cx := roundf(gx)
			var cy := roundf(gy)
			var dx := gx - cx
			var dy := gy - cy
			var d := sqrt(dx * dx + dy * dy) * cell
			var dens: float = density.call(u, v)
			var rad: float = cell * 0.72 * sqrt(clampf(dens, 0.0, 1.0))
			if d <= rad and rad > 0.35:
				# jitter the dot slightly so the screen is not mechanical
				var j := rng.randf_range(-0.22, 0.22)
				var a := col.a * (1.0 - clampf(d / maxf(rad, 0.001), 0.0, 1.0) * 0.35)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))


func _speed_lines(img: Image, rng: RandomNumberGenerator, w: int, h: int) -> void:
	var cx := w * 0.5
	var cy := h * 0.42
	var col := INK
	col.a = 0.5
	var i := 0
	while i < 150:
		var ang := rng.randf_range(0.0, TAU)
		var r0 := rng.randf_range(0.18, 0.42) * float(maxi(w, h))
		var r1 := rng.randf_range(0.75, 1.25) * float(maxi(w, h))
		var steps := int(r1 - r0)
		var th := rng.randi_range(1, 2)
		for s in steps:
			var r := r0 + float(s)
			var x := int(cx + cos(ang) * r)
			var y := int(cy + sin(ang) * r)
			for k in th:
				img.set_pixel(wrapi(x + k, 0, w), wrapi(y + k, 0, h), col)
		i += 1


## Rows of five, the universal "counted too many times" mark.
func _tallies(img: Image, rng: RandomNumberGenerator, w: int, h: int) -> void:
	var col := INK
	col.a = 0.88
	var groups := int(rng.randi_range(7, 13))
	var top := int(h * 0.14)
	var bottom := int(h * 0.84)
	var x := int(w * 0.10)
	var gap := int((w * 0.80) / float(maxi(1, groups)))
	for g in groups:
		var slant := rng.randi_range(-int(gap * 0.12), int(gap * 0.12))
		for k in 4:
			var sx := x + k * int(gap / 5.0)
			_stroke_v(img, sx, top, bottom, 2, col, float(g) + k, h)
		if g % 5 == 4:
			_stroke_d(img, x - int(gap * 0.12), bottom - 4, x + gap - int(gap * 0.12), top + 4, 3, col)
		x += gap
		if x > w * 0.92:
			break


func _stroke_v(img: Image, x: int, y0: int, y1: int, thickness: int, col: Color, phase: float, h: int) -> void:
	var w := img.get_width()
	var span := float(maxi(1, y1 - y0))
	for y in range(y0, y1):
		var f := float(y - y0) / span
		var wob := sin(f * 9.0 + phase) * 1.3 + sin(f * 23.0 + phase * 1.7) * 0.7
		var xx := int(round(x + wob))
		for k in thickness:
			var px := wrapi(xx + k, 0, w)
			img.set_pixel(px, clampi(y, 0, h - 1), col)


func _stroke_d(img: Image, x0: int, y0: int, x1: int, y1: int, thickness: int, col: Color) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	for s in steps:
		var f := float(s) / float(maxi(1, steps))
		var x := int(round(lerpf(x0, x1, f)))
		var y := int(round(lerpf(y0, y1, f)))
		var wob := int(round(sin(f * 17.0) * 1.2))
		for k in thickness:
			img.set_pixel(wrapi(x + k, 0, img.get_width()), wrapi(y + wob, 0, img.get_height()), col)


func _border(img: Image, w: int, h: int, rng: RandomNumberGenerator, col: Color, thickness: int) -> void:
	var m := int(mini(w, h) * 0.045) + 3
	var p := rng.randf_range(0.0, 6.0)
	_stroke_v(img, m, m, h - m, thickness, col, p, h)
	_stroke_v(img, w - m - thickness, m, h - m, thickness, col, p + 2.1, h)
	# horizontals
	var span := float(maxi(1, w - m * 2 - thickness))
	for x in range(m, w - m):
		var f := float(x - m) / span
		var wob := int(round(sin(f * 11.0 + p) * 1.2 + sin(f * 29.0 + p * 1.3) * 0.6))
		for k in thickness:
			img.set_pixel(x, clampi(m + k + wob, 0, h - 1), col)
			img.set_pixel(x, clampi(h - m - thickness + k + wob, 0, h - 1), col)


# --- Density fields --------------------------------------------------------

func _grad_dir(u: float, v: float) -> float:
	return clampf(0.15 + v * 0.95 + sin(u * 5.0) * 0.05, 0.0, 1.0) * 0.85


func _grad_up(u: float, v: float) -> float:
	return clampf(0.20 + (1.0 - v) * 0.55, 0.0, 1.0) * 0.6


func _grad_corner(u: float, v: float) -> float:
	var d := sqrt((1.0 - u) * (1.0 - u) + v * v)
	return clampf(1.1 - d * 1.5, 0.0, 1.0)


func _grad_full(u: float, v: float) -> float:
	return clampf(0.45 + 0.4 * sin(u * 7.0) * cos(v * 5.0), 0.0, 1.0) * 0.7


# --- Rune glyphs ------------------------------------------------------------
# The four marks on the hatch dials, drawn as ink so they read as a language
# rather than as words.

func glyph_texture(kind: String, px: int = 128) -> ImageTexture:
	var key := "glyph:" + kind
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.06, 0.05, 0.06, 0.96)
	var c := float(px) * 0.5
	match kind:
		"moon":
			_disc(img, c, c, px * 0.36, ink)
			_disc(img, c + px * 0.17, c - px * 0.09, px * 0.31, Color(0, 0, 0, 0))
		"eye":
			_ring(img, c, c, px * 0.36, px * 0.20, ink)
			_disc(img, c, c, px * 0.11, ink)
		"wave":
			for k in 2:
				var base := c + (float(k) - 0.5) * px * 0.22
				for i in px:
					var t := float(i) / px
					if t < 0.1 or t > 0.9:
						continue
					var y := base + sin((t - 0.1) / 0.8 * TAU) * px * 0.10
					img.set_pixel(i, int(clampf(y, 0.0, float(px - 1))), ink)
		"bone":
			_disc(img, c - px * 0.20, c - px * 0.11, px * 0.10, ink)
			_disc(img, c + px * 0.20, c + px * 0.11, px * 0.10, ink)
			_disc(img, c - px * 0.20, c + px * 0.11, px * 0.10, ink)
			_disc(img, c + px * 0.20, c - px * 0.11, px * 0.10, ink)
			_rect(img, int(c - px * 0.24), int(c - px * 0.06), int(c + px * 0.24), int(c + px * 0.06), ink)
		_:
			_ring(img, c, c, px * 0.30, px * 0.10, ink)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


func _disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var r2 := r * r
	for y in range(maxi(0, int(cy - r)), mini(h, int(cy + r) + 1)):
		for x in range(maxi(0, int(cx - r)), mini(w, int(cx + r) + 1)):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy <= r2:
				if col.a >= 0.999:
					img.set_pixel(x, y, col)
				elif col.a > 0.0:
					var prev := img.get_pixel(x, y)
					img.set_pixel(x, y, prev.lerp(Color(col.r, col.g, col.b, 1.0), col.a))


func _ring(img: Image, cx: float, cy: float, r: float, thickness: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var inner := maxf(0.0, r - thickness)
	for y in range(maxi(0, int(cy - r - 1)), mini(h, int(cy + r + 2))):
		for x in range(maxi(0, int(cx - r - 1)), mini(w, int(cx + r + 2))):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var d := sqrt(dx * dx + dy * dy)
			if d <= r and d >= inner:
				img.set_pixel(x, y, col)


func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var xa := maxi(0, x0)
	var xb := mini(img.get_width(), x1)
	var ya := maxi(0, y0)
	var yb := mini(img.get_height(), y1)
	for y in range(ya, yb):
		for x in range(xa, xb):
			img.set_pixel(x, y, col)


# --- Reusable material helpers --------------------------------------------

## Grimy surface texture for walls/floors (no comic ink).
static func grime_texture(base: Color, freq: float, contrast: float, seed_value: int) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 4
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var v := n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			v = clampf(0.5 + (v - 0.5) * contrast, 0.0, 1.0)
			img.set_pixel(x, y, Color(base.r * v, base.g * v, base.b * v, 1.0))
	return ImageTexture.create_from_image(img)


## Pre-warm the panel cache so the first reveal never hitches.
func prewarm(keys: Array) -> void:
	for k in keys:
		panel(k.get("style", "newsprint"), k.get("art", "wall_panel"),
			k.get("w", 384), k.get("h", 288), k.get("seed", 0))