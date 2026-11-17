class_name TestNewPieceVisualContract
extends SceneTreeTestCase

const PIECES: Array[String] = ["assassin", "royal_guard", "catapult", "bowman", "portal_mage", "unicorn_cavalry", "centaur", "manticore", "gryphon", "gorgon"]
const SKIN_SIZES: Dictionary = {"royal_forge": 64, "modern_parchment": 128}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for skin: String in SKIN_SIZES:
		var expected_size: int = int(SKIN_SIZES[skin])
		for color: String in ["white", "black"]:
			var baselines: Array[int] = []
			for piece_id: String in PIECES:
				var path: String = "res://assets/chess/piece_skins/%s/%s_%s.png" % [skin, color, piece_id]
				var image: Image = Image.load_from_file(path)
				expect(not image.is_empty(), "%s loads" % path)
				if image.is_empty():
					continue
				expect(image.get_width() == expected_size and image.get_height() == expected_size, "%s uses native skin resolution" % path)
				var bounds: Rect2i = _alpha_bounds(image)
				var minimum_margin: int = expected_size / 16
				expect(bounds.position.x >= minimum_margin and bounds.position.y >= minimum_margin, "%s keeps top/left breathing room" % path)
				expect(image.get_width() - bounds.end.x >= minimum_margin and image.get_height() - bounds.end.y >= minimum_margin, "%s keeps bottom/right breathing room" % path)
				expect(bounds.size.x <= expected_size * 7 / 8 and bounds.size.y <= expected_size * 7 / 8, "%s silhouette fits a 39px board cell" % path)
				baselines.append(bounds.end.y)
			expect(_range(baselines) <= 1, "%s %s pieces share one baseline" % [skin, color])
	for color: String in ["white", "black"]:
		for piece_id: String in PIECES:
			var royal: Image = Image.load_from_file("res://assets/chess/piece_skins/royal_forge/%s_%s.png" % [color, piece_id])
			var modern: Image = Image.load_from_file("res://assets/chess/piece_skins/modern_parchment/%s_%s.png" % [color, piece_id])
			modern.resize(64, 64, Image.INTERPOLATE_NEAREST)
			expect(_alpha_difference_ratio(royal, modern) >= 0.02, "%s %s has skin-specific silhouette construction" % [color, piece_id])
	finish_test("New piece visual contract")

func _alpha_bounds(image: Image) -> Rect2i:
	var minimum: Vector2i = Vector2i(image.get_width(), image.get_height())
	var maximum: Vector2i = Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a <= 0.01:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < 0:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)

func _range(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var minimum: int = values[0]
	var maximum: int = values[0]
	for value: int in values:
		minimum = mini(minimum, value)
		maximum = maxi(maximum, value)
	return maximum - minimum

func _alpha_difference_ratio(first: Image, second: Image) -> float:
	var differences: int = 0
	var total: int = first.get_width() * first.get_height()
	for y: int in first.get_height():
		for x: int in first.get_width():
			var first_alpha: bool = first.get_pixel(x, y).a > 0.01
			var second_alpha: bool = second.get_pixel(x, y).a > 0.01
			if first_alpha != second_alpha:
				differences += 1
	return float(differences) / float(total)
