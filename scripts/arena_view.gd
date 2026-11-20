extends Control
## Draws the original isometric battlefield in a 576×340 logical canvas.

const Battle = preload("res://scripts/battle.gd")
const Data = preload("res://scripts/battle_data.gd")
const Iso = preload("res://scripts/projection.gd")
const BACKGROUND := preload("res://assets/terrain/background.png")
const GROUND := preload("res://assets/terrain/ground.png")
const SPRITES := {
	"hero": [preload("res://assets/sprites/hero.png"), preload("res://assets/sprites/hero_hit.png")],
	"golem": [preload("res://assets/sprites/golem.png"), preload("res://assets/sprites/golem_hit.png")],
	"slime": [preload("res://assets/sprites/slime.png"), preload("res://assets/sprites/slime_hit.png")],
	"bat": [preload("res://assets/sprites/bat.png"), preload("res://assets/sprites/bat_hit.png")]
}

var battle: Battle
var props: Array[Dictionary] = []
var targets: Array[String] = []
var range_limit := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for prop in Data.PROPS:
		var cell: Vector2i = prop.cell
		var foot := Vector2(cell) + Vector2(0.5, 0.5)
		var frames: Array[Texture2D] = []
		var prefix: String = "res://assets/props/" + prop.sprite_key
		if prop.art == "torch":
			for index in range(5):
				frames.append(load(prefix + "_%d.png" % index))
		else:
			frames.append(load(prefix + ".png"))
		props.append({"position": foot, "depth": foot.x + foot.y, "frames": frames})

func canvas_rect() -> Rect2:
	var scale_ratio := minf(size.x / Iso.SIZE.x, size.y / Iso.SIZE.y)
	var extent := Iso.SIZE * scale_ratio
	return Rect2((size - extent) * 0.5, extent)

func aim_point(local_point: Vector2) -> Vector2:
	var canvas := canvas_rect()
	var point := (local_point - canvas.position) * (Iso.SIZE / canvas.size)
	for enemy in battle.enemies:
		if enemy.hp == 0:
			continue
		var foot := Iso.project(enemy.position)
		var lift := _enemy_lift(enemy)
		var height := 18 if enemy.id == "golem" else 12
		if absf(point.x - foot.x) <= 9 and point.y >= foot.y - lift - height - 2 and point.y <= foot.y + 4:
			return enemy.position
	return Iso.unproject(point)

func update_battle(next: Battle) -> void:
	battle = next
	range_limit = battle.attack_range()
	targets = battle.preview_targets(range_limit)
	queue_redraw()

func _draw() -> void:
	if battle == null:
		return
	var canvas := canvas_rect()
	if not canvas.has_area():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101820"))
	draw_set_transform(canvas.position, 0.0, canvas.size / Iso.SIZE)
	draw_texture(BACKGROUND, Vector2.ZERO)
	draw_texture(GROUND, Vector2.ZERO)
	if battle.preview and not battle.is_finished():
		_draw_preview()
	for enemy in battle.enemies:
		if enemy.hp > 0 and enemy.wind > 0:
			_ground_ring(enemy.position, enemy.reach, Color("#dd725a32"), Color("#e77b63"))
	var entries: Array[Dictionary] = props.duplicate()
	var hero: Vector2 = battle.hero.position
	entries.append({"kind": "hero", "depth": hero.x + hero.y})
	for enemy in battle.enemies:
		if enemy.hp > 0:
			var foot: Vector2 = enemy.position
			entries.append({"kind": "enemy", "depth": foot.x + foot.y, "actor": enemy})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	for entry in entries:
		match entry.get("kind", "prop"):
			"hero": _draw_hero()
			"enemy": _draw_enemy(entry.actor)
			"prop": _draw_prop(entry)
	for projectile in battle.projectiles:
		_draw_projectile(projectile)
	for effect in battle.effects:
		_draw_effect(effect)
	for i in range(23):
		var clock := battle.clock
		var x := 42.0 + _grain(i, 22) * 500.0 + sin(clock * 0.31 + i) * 8.0
		var y := 48.0 + _grain(i, 25) * 232.0 + cos(clock * 0.53 + i) * 7.0
		var color := Color("#c1a779") if i % 3 else Color("#abc5ad")
		color.a = 0.14 + (sin(clock * 1.3 + i) + 1.0) * 0.18
		draw_rect(Rect2(Vector2(x, y).round(), Vector2(2 if i % 7 == 0 else 1, 1)), color)

func _draw_prop(prop: Dictionary) -> void:
	var foot := Iso.project(prop.position)
	var index := 0
	if prop.frames.size() > 1:
		index = roundi(sin(battle.clock * 17.0 + foot.x) * 2.0) + 2
	draw_texture(prop.frames[index], foot - Vector2(40, 60))

func _arc(center: Vector2, radius: float, from: float, to: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var angle := lerpf(from, to, float(i) / steps)
		points.append(Iso.project(center + Vector2.from_angle(angle) * radius))
	return points

func _polygon(points: PackedVector2Array, fill: Color, edge: Color = Color.TRANSPARENT) -> void:
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	if edge.a > 0.0:
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, edge, 1.0)

func _ground_ring(center: Vector2, radius: float, fill: Color, edge: Color) -> void:
	var points := _arc(center, radius, 0, TAU, 28)
	points.remove_at(points.size() - 1)
	_polygon(points, fill, edge)

func _draw_preview() -> void:
	var origin: Vector2 = battle.hero.position
	var aim: Vector2 = battle.aim
	if battle.selected == "slash":
		var half: float = Battle.SLASH.half_angle
		var fan := PackedVector2Array([Iso.project(origin)])
		fan.append_array(_arc(origin, range_limit, aim.angle() - half, aim.angle() + half, 18))
		_polygon(fan, Color("#e99d4d38"), Color("#f9b66ee0"))
		draw_dashed_line(Iso.project(origin), Iso.project(origin + aim * range_limit), Color("#ffe1ab83"), 1.0, 3.0)
	elif range_limit > 0:
		var sideways := aim.orthogonal() * float(Battle.BOLT.half_width)
		var finish := origin + aim * range_limit
		_polygon(PackedVector2Array([Iso.project(origin - sideways), Iso.project(finish - sideways),
			Iso.project(finish + sideways), Iso.project(origin + sideways)]), Color("#83dace38"), Color("#a8f1e2d7"))
		_diamond(Iso.project(finish), Color("#b5f3e1"), 3, 2)

func _diamond(center: Vector2, color: Color, width: float, height: float) -> void:
	_polygon(PackedVector2Array([center + Vector2(0, -height), center + Vector2(width, 0),
		center + Vector2(0, height), center + Vector2(-width, 0)]), color)

func _sprite(actor: String, foot: Vector2, flip: bool, flash: bool) -> void:
	var texture: Texture2D = SPRITES[actor][int(flash)]
	var extent := texture.get_size()
	var top := foot.round() - Vector2(floorf(extent.x / 2.0), extent.y)
	if flip:
		draw_set_transform_matrix(get_draw_flip_transform(top, extent.x))
		draw_texture(texture, Vector2.ZERO)
		var canvas := canvas_rect()
		draw_set_transform(canvas.position, 0.0, canvas.size / Iso.SIZE)
	else:
		draw_texture(texture, top)

func get_draw_flip_transform(top: Vector2, width: float) -> Transform2D:
	var canvas := canvas_rect()
	var local := Transform2D(Vector2(-1, 0), Vector2(0, 1), top + Vector2(width, 0))
	return Transform2D(0.0, canvas.size / Iso.SIZE, 0.0, canvas.position) * local

func _shadow(foot: Vector2, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(16):
		points.append(foot + Vector2.from_angle(TAU * i / 16.0) * Vector2(width, 4))
	draw_colored_polygon(points, Color("#1b2124a8"))

func _draw_hero() -> void:
	var hero := battle.hero
	var foot := Iso.project(hero.position).round()
	_shadow(foot, 9)
	_ground_ring(hero.position, 0.59, Color("#ebb67720"), Color("#f5ce9ba8"))
	var bob := roundi(sin(hero.stride * 2.0) * 1.8) if hero.moving else roundi(sin(battle.clock * 5.0) * 0.65)
	_sprite("hero", foot - Vector2(0, 2 + bob), hero.facing < 0, hero.hurt > 0.19)
	_diamond(foot - Vector2(0, 26), Color("#f4bd84"), 3, 3)

func _enemy_lift(enemy: Dictionary) -> int:
	if enemy.id == "bat":
		return 7 + roundi(sin(battle.clock * 7.0) * 2.0)
	return roundi(absf(sin(enemy.stride)) * 1.4)

func _draw_enemy(enemy: Dictionary) -> void:
	var foot := Iso.project(enemy.position).round()
	_shadow(foot, 12 if enemy.id == "golem" else 8)
	var targeted := targets.has(enemy.id)
	if targeted:
		_ground_ring(enemy.position, 0.65, Color("#ffce8b31"), Color("#ffd18fcf"))
	var height: int = {"golem": 21, "slime": 15, "bat": 14}[enemy.id]
	var lift := _enemy_lift(enemy)
	_sprite(enemy.id, foot - Vector2(0, 1 + lift), enemy.id == "bat" and sin(battle.clock * 2.0) < 0, enemy.hurt > 0.085)
	var bar := foot - Vector2(10, height + lift + 5)
	draw_rect(Rect2(bar, Vector2(20, 4)), Color("#25232c"))
	draw_rect(Rect2(bar + Vector2.ONE, Vector2(18, 2)), Color("#593d44"))
	draw_rect(Rect2(bar + Vector2.ONE, Vector2(ceilf(18.0 * enemy.hp / enemy.max_hp), 2)),
		Color("#e59265") if targeted else Color("#c77679"))
	if targeted:
		draw_rect(Rect2(bar + Vector2(9, -4), Vector2(3, 2)), Color("#ffdea3"))
	if enemy.wind > 0:
		draw_rect(Rect2(bar + Vector2(9, -9), Vector2(2, 4)), Color("#f39377"))
	if enemy.slow > 0:
		draw_rect(Rect2(foot + Vector2(-8, -7), Vector2(2, 1)), Color("#89dddb"))
		draw_rect(Rect2(foot + Vector2(9, -4), Vector2(2, 1)), Color("#a8d9d9"))

func _draw_projectile(projectile: Dictionary) -> void:
	var center := Iso.project(projectile.position).round() - Vector2(0, 8)
	var trail := Iso.project(projectile.position - projectile.aim * 0.65).round() - Vector2(0, 9)
	draw_circle(center, 9, Color("#a7f3ea23"))
	draw_line(trail, center, Color("#73c7c9"), 2.0)
	_diamond(center, Color("#b5f3e1"), 5, 3)
	draw_rect(Rect2(center + Vector2(-1, -1), Vector2(3, 2)), Color("#eaffe6"))

func _draw_effect(effect: Dictionary) -> void:
	var age: float = effect.age / effect.duration
	var fade := 1.0 - age
	var at := Iso.project(effect.position).round()
	match effect.kind:
		"slash":
			var radius: float = Battle.SLASH.range * lerpf(0.55, 1.0, age)
			var bearing: float = effect.aim.angle()
			var half: float = Battle.SLASH.half_angle
			var swing := _arc(effect.position, radius, bearing - half - 0.08, bearing + half + 0.08, 18)
			swing.append_array(_arc(effect.position, radius * 0.77, bearing + half * 0.9, bearing - half * 0.9, 18))
			for i in range(swing.size()):
				swing[i].y -= 7
			_polygon(swing, Color("#f2904c", fade), Color("#ffd69a", fade))
		"enemy_strike":
			_ground_ring(effect.position, effect.range, Color("#e87e65", fade * 0.35), Color("#d85f51", fade))
		_:
			var colors := [Color("#fff0c5"), Color("#f69e66"), Color("#ad5e45")]
			if effect.kind in ["ice_hit", "release"]:
				colors = [Color("#e6ffed"), Color("#94ded6"), Color("#518eac")]
			elif effect.kind == "fall":
				colors = [Color("#e1d3a6"), Color("#aab584"), Color("#818d72")]
			for i in range(12 if effect.kind == "fall" else 9):
				var radius := (3.0 + 16.0 * age) * (0.42 + _grain(i, roundi(at.y)) * 0.58)
				var scatter := Vector2.from_angle(i * 2.399) * Vector2(radius, radius * 0.66)
				var color: Color = colors[i % 3]
				color.a = fade
				draw_rect(Rect2((at + scatter - Vector2(0, 8 + age * 5)).round(), Vector2(i % 3 + 1, i % 2 + 1)), color)
			if effect.has("amount"):
				var number := ("-" if effect.kind == "hero_hit" else "") + str(effect.amount)
				var font := ThemeDB.fallback_font
				var extent := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
				var where := at - Vector2(extent.x * 0.5, 27 + age * 13)
				draw_string_outline(font, where, number, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 2, Color("#211f26", fade))
				draw_string(font, where, number, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(colors[0], fade))

static func _grain(index: int, salt: int) -> float:
	return fposmod(sin(index * 12.9898 + salt * 78.233) * 43758.5453, 1.0)
