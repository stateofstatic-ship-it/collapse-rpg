class_name UI
extends RefCounted
## One theme and small builders for every screen: 48 dp targets, 16 sp text,
## the household-paper palette (art.md interface direction, gray-box).

static var d := 1.0
static var theme: Theme

const INK := Color(0.16, 0.13, 0.1)
const PAPER := Color(0.93, 0.89, 0.8)
const PAPER_DARK := Color(0.84, 0.79, 0.68)
const ACCENT := Color(0.55, 0.22, 0.12)
const GOOD := Color(0.18, 0.45, 0.2)
const WARN := Color(0.65, 0.4, 0.05)
const BAD := Color(0.6, 0.12, 0.1)


static func setup() -> void:
	var dpi := float(DisplayServer.screen_get_dpi())
	var scr := DisplayServer.screen_get_size()
	d = clampf(dpi / 160.0, 1.0, 4.0)
	# Desktop windows report ~96 dpi; keep text readable on tall screens.
	if d < 1.2 and scr.y >= 1400:
		d = 1.3
	theme = _make_theme()


static func dp(v: float) -> int:
	return int(round(v * d))


static func _box(bg: Color, border: Color, radius: float = 4.0, margin: float = 8.0, bw: float = 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(maxi(1, dp(bw)))
	sb.set_corner_radius_all(dp(radius))
	sb.set_content_margin_all(dp(margin))
	return sb


static func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = dp(17)
	th.set_stylebox("panel", "PanelContainer", _box(PAPER, Color(0.5, 0.42, 0.3), 3, 12, 1.5))
	th.set_stylebox("panel", "Panel", _box(PAPER, Color(0.5, 0.42, 0.3), 3, 12, 1.5))
	var states := {"normal": Color(0.98, 0.95, 0.87), "hover": Color(1.0, 0.98, 0.9), "pressed": Color(0.86, 0.78, 0.62), "focus": Color(0.98, 0.95, 0.87), "disabled": Color(0.86, 0.84, 0.8)}
	for st in states:
		var sb := _box(states[st], Color(0.42, 0.34, 0.24), 4, 8, 1.2)
		if st == "focus":
			sb.border_color = ACCENT
			sb.set_border_width_all(dp(2))
		th.set_stylebox(st, "Button", sb)
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", INK)
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_focus_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", Color(0.45, 0.43, 0.4))
	th.set_color("font_color", "Label", INK)
	th.set_color("default_color", "RichTextLabel", INK)
	th.set_color("font_color", "LineEdit", INK)
	th.set_stylebox("normal", "LineEdit", _box(Color(1, 1, 0.97), Color(0.42, 0.34, 0.24), 3, 8))
	th.set_stylebox("focus", "LineEdit", _box(Color(1, 1, 0.97), ACCENT, 3, 8, 2))
	th.set_stylebox("background", "ProgressBar", _box(Color(0.75, 0.7, 0.6), Color(0.42, 0.34, 0.24), 2, 0))
	th.set_stylebox("fill", "ProgressBar", _box(Color(0.45, 0.32, 0.2), Color(0.45, 0.32, 0.2), 2, 0))
	th.set_constant("separation", "VBoxContainer", dp(8))
	th.set_constant("separation", "HBoxContainer", dp(8))
	th.set_stylebox("panel", "TooltipPanel", _box(PAPER, INK, 2, 6))
	# Wide and dark enough to see and to grab with a finger.
	var grab := _box(Color(0.42, 0.32, 0.2), Color(0.42, 0.32, 0.2), 4, 0)
	grab.content_margin_left = dp(10)
	grab.content_margin_right = dp(10)
	th.set_stylebox("grabber", "VScrollBar", grab)
	th.set_stylebox("grabber_highlight", "VScrollBar", grab)
	th.set_stylebox("grabber_pressed", "VScrollBar", grab)
	var track := _box(Color(0.74, 0.68, 0.56), Color(0.74, 0.68, 0.56), 4, 0)
	track.content_margin_left = dp(10)
	track.content_margin_right = dp(10)
	th.set_stylebox("scroll", "VScrollBar", track)
	return th


static func button(text: String, cb: Callable, parent: Node = null, min_w: float = 48.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(dp(min_w), dp(48))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(cb)
	if parent != null:
		parent.add_child(b)
	return b


static func label(text: String, parent: Node = null, size: float = 17.0, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label in an HBox otherwise collapses to one character wide.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", dp(size))
	l.add_theme_color_override("font_color", color)
	if parent != null:
		parent.add_child(l)
	return l


static func rich(bbcode: String, parent: Node = null, size: float = 17.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_size_override("normal_font_size", dp(size))
	r.add_theme_font_size_override("bold_font_size", dp(size))
	r.add_theme_color_override("default_color", INK)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent != null:
		parent.add_child(r)
	return r


static func panel(parent: Node = null) -> PanelContainer:
	var p := PanelContainer.new()
	if parent != null:
		parent.add_child(p)
	return p


static func vbox(parent: Node = null, sep: float = 8.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", dp(sep))
	if parent != null:
		parent.add_child(v)
	return v


static func hbox(parent: Node = null, sep: float = 8.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", dp(sep))
	if parent != null:
		parent.add_child(h)
	return h


static func scroll(parent: Node = null) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent != null:
		parent.add_child(sc)
	return sc


static func title(text: String, parent: Node = null) -> Label:
	var l := label(text, parent, 26, ACCENT)
	return l


static func clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()


## A full-screen paper page with a scrolling body; returns the body VBox.
static func page(parent: Control, heading: String) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.3, 0.27, 0.22)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, dp(12))
	# Clear the status bar across the top.
	m.add_theme_constant_override("margin_top", dp(64))
	parent.add_child(m)
	var p := panel(m)
	var v := vbox(p, 10)
	if heading != "":
		title(heading, v)
	var sc := scroll(v)
	var body := vbox(sc, 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return body


static func color_for_band(band: int) -> Color:
	return [GOOD, WARN, BAD, BAD][band]
