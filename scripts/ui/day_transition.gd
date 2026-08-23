# scripts/ui/day_transition.gd
# A dark rectangle that sweeps left-to-right across the screen on End Day,
# then sweeps back off to the right, giving a day-change feel.
extends Control

const SWEEP_DURATION: float = 0.30   # seconds for each half (in + out)
const MAX_ALPHA: float = 0.55        # how dark at peak (0-1)

var _rect: ColorRect
var _tween: Tween
var _vp_size: Vector2

func _ready() -> void:
	# Cover the full viewport, sit above everything else
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

	_rect = ColorRect.new()
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

	_reset()

func _reset() -> void:
	if get_viewport():
		_vp_size = get_viewport().get_visible_rect().size
	_rect.size = Vector2(0.0, _vp_size.y if _vp_size != Vector2.ZERO else 1080.0)
	_rect.position = Vector2.ZERO
	_rect.color = Color(0.0, 0.0, 0.0, MAX_ALPHA)

func play() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_reset()

	var vp_w: float = get_viewport().get_visible_rect().size.x
	_rect.size.y = get_viewport().get_visible_rect().size.y

	_tween = create_tween()
	# Sweep in: width grows from 0 → full width
	_tween.tween_property(_rect, "size:x", vp_w, SWEEP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Brief pause at peak
	_tween.tween_interval(0.08)
	# Sweep out: move rect's left edge rightward (position.x grows, size shrinks equally)
	# Achieved by tweening position.x to vp_w while size stays full
	_tween.tween_property(_rect, "position:x", vp_w, SWEEP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_reset)
