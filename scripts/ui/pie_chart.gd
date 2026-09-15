# scripts/ui/pie_chart.gd
# Minimal pie chart control — draws colored slices for a list of {value, color} entries.
# Callers build their own legend/key below it; this only renders the chart itself.
class_name PieChart
extends Control

var slices: Array = []  # [{value: float, color: Color}]

func set_slices(new_slices: Array) -> void:
	slices = new_slices
	queue_redraw()

func _draw() -> void:
	var radius: float = min(size.x, size.y) / 2.0 - 2
	var center: Vector2 = size / 2.0
	if radius <= 0.0:
		return

	var total: float = 0.0
	for s in slices:
		total += max(0.0, float(s.get("value", 0.0)))

	if total <= 0.0:
		draw_arc(center, radius, 0, TAU, 48, Color(0.35, 0.35, 0.35), 2.0)
		return

	# Start at 12 o'clock and sweep clockwise
	var start_angle: float = -PI / 2.0
	for s in slices:
		var value: float = max(0.0, float(s.get("value", 0.0)))
		if value <= 0.0:
			continue
		var sweep: float = TAU * (value / total)
		var segments: int = max(2, int(sweep / 0.12))
		var points := PackedVector2Array()
		points.append(center)
		for i in range(segments + 1):
			var angle: float = start_angle + sweep * (float(i) / float(segments))
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, s.get("color", Color.WHITE))
		start_angle += sweep
