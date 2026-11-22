extends Node2D

var crossing_open := false
const INK := Color("#18272c")
const LINE := Color("#54666a")
const GOLD := Color("#e8b975")

func _draw() -> void:
	# Flat location cues sit below all pick areas and collision bodies.
	draw_rect(Rect2(0, 0, 1280, 720), Color("#283638"))
	draw_rect(Rect2(0, 155, 1280, 490), Color("#303e3e"))
	for y in range(164, 640, 28):
		for x in range(10, 1280, 35):
			var n := absi((x * 73 + y * 13) % 87)
			draw_line(Vector2(x+n%13, y), Vector2(x+2+n%13, y), Color("#43504e"))
	# Road and its worn centre stripe.
	draw_rect(Rect2(0, 452, 1280, 97), Color("#242f32"))
	for y in [455, 545]:
		draw_line(Vector2(0, y), Vector2(1280, y), LINE, 2)
	for x in range(-12, 1280, 83):
		draw_rect(Rect2(x, 498, 35, 3), Color("#77755c"))
	# The west watch room and the central shuttered workshop.
	_roof(Rect2(76, 208, 142, 88), Color("#50605d"))
	draw_rect(Rect2(135, 285, 51, 10), Color("#dba972"))
	for x in [90, 106, 186]:
		draw_rect(Rect2(x, 253, 12, 18), Color("#a39270"))
	_roof(Rect2(590, 274, 118, 172), Color("#4e5c5b"))
	for y in range(292, 410, 13):
		draw_line(Vector2(601, y), Vector2(696, y), Color("#606c68"), 2)
	draw_rect(Rect2(617, 304, 48, 36), INK)
	for x in [624, 644]:
		draw_rect(Rect2(x, 312, 14, 18), Color("#78817a"))
	# The rusted car is a solid obstacle. Its salvage is at the rear bumper.
	for x in [449, 500]:
		draw_rect(Rect2(x, 370, 14, 45), INK)
	draw_rect(Rect2(441, 377, 80, 32), Color("#935f4b"))
	draw_rect(Rect2(455, 379, 38, 28), Color("#4a6263"))
	draw_rect(Rect2(463, 379, 18, 28), Color("#a06750"))
	draw_rect(Rect2(514, 381, 6, 6), GOLD)
	draw_rect(Rect2(514, 399, 6, 6), GOLD)
	_sign(Vector2(433, 353), "废车拆解区", GOLD)
	_sign(Vector2(78, 194), "西侧值班室", Color("#b9d0bb"))
	_sign(Vector2(603, 259), "旧维修间", Color("#95a5a0"))
	_sign(Vector2(749, 202), "北侧林带", Color("#acc19e"))
	# Store walls match the navigation obstacles.
	var yard := Rect2(1060, 510, 180, 158)
	draw_rect(yard, Color("#344341"))
	for rect in [Rect2(1060,510,180,14),Rect2(1226,510,14,158),Rect2(1060,654,180,14)]:
		draw_rect(rect, Color("#77817b"))
		draw_rect(rect.grow(-3), Color("#505d59"))
	_sign(Vector2(1090, 552), "东岸应急仓", Color("#d6c69c"))
	var gap := Rect2(1059, 524, 16, 130)
	draw_rect(gap, Color("#13292e"))
	if crossing_open:
		for x in range(1048, 1092, 6):
			draw_rect(Rect2(x, 552, 5, 70), Color("#bc986c"))
		for y in [552, 622]:
			draw_line(Vector2(1046, y), Vector2(1092, y), GOLD, 2)
	else:
		for y in range(530, 650, 15):
			draw_line(Vector2(1061, y + 8),Vector2(1073, y), Color("#707975"), 2)
		for x in [1049, 1082]:
			draw_rect(Rect2(x, 567, 8, 33), Color("#a88661"))
	# Area marking identifies the excavation from a distance.
	for i in range(4):
		var start := float(i) * PI / 2.0 + 0.2
		draw_arc(Vector2(485,406), 63, start, start+0.45, 9, Color("#948569"), 2)


func _roof(rect: Rect2, paint: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(6, 8), rect.size), Color("#223031"))
	draw_rect(rect, INK)
	draw_rect(rect.grow(-3), paint)
	draw_rect(rect.grow(-8), INK, false, 1)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("#82918b"), 3)


func _sign(at: Vector2, words: String, tint: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)
