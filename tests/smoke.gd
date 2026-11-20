extends SceneTree

const Battle = preload("res://scripts/battle.gd")
const Iso = preload("res://scripts/projection.gd")
const DT := 1.0 / 60.0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var opening := Battle.new()
	var screen := Iso.project(opening.hero.position)
	_check(screen.is_equal_approx(Vector2(253, 173)), "Original spawn projects to 253,173")
	_check(Iso.unproject(screen).is_equal_approx(opening.hero.position), "Projection round trip")
	_check(opening.preview_targets(opening.attack_range()) == ["slime"], "Opening highlights slime")
	opening.step({"cast": true}, DT)
	_check(opening.enemies[0].hp == 16, "Opening slash reduces slime HP from 52 to 16")
	opening.step({"cast": true}, DT)
	_check(opening.enemies[0].hp == 16, "Slash cooldown gates a second cast")
	var move := Battle.new()
	move.step({"move": Vector2.RIGHT}, DT)
	var next := Iso.project(move.hero.position)
	_check(next.x > screen.x and is_equal_approx(next.y, screen.y), "Right key follows screen axis")

	var ice := Battle.new()
	ice.hero.position = Vector2(8.5, 8.5)
	ice.enemies[0].position = Vector2(10.0, 8.5)
	ice.enemies[1].position = Vector2(12.0, 8.5)
	ice.enemies[2].hp = 0
	ice.step({"skill": "bolt", "aim_point": Vector2(14, 8.5), "cast": true}, DT)
	for tick in range(10):
		ice.step({}, DT)
	_check(ice.enemies[0].hp == 0 and ice.enemies[1].hp == 108, "Bolt strikes only the first target")
	_check(ice.enemies[0].slow > 0, "Bolt applies chill")
	var wall := Battle.new()
	wall.hero.position = Vector2(6.5, 4.5)
	wall.enemies[0].position = Vector2(8.5, 4.5)
	wall.step({"skill": "bolt", "aim_point": Vector2(12, 4.5), "cast": true}, DT)
	_check(wall.attack_range() < 0.6, "Bolt preview stops at arena obstacle")
	for tick in range(10):
		wall.step({}, DT)
	_check(wall.projectiles.is_empty() and wall.enemies[0].hp == 52, "Gate stops the projectile")
	var result := Battle.new()
	for enemy in result.enemies:
		enemy.hp = 0
	result.step({"move": Vector2.LEFT}, DT)
	_check(result.outcome == "won", "All enemies defeated marks victory")
	var defeat := Battle.new()
	defeat.hero.hp = 1
	defeat.enemies[0].position = defeat.hero.position + Vector2(0.7, 0.0)
	defeat.enemies[0].active = true
	defeat.enemies[0].wind = DT * 0.5
	defeat.step({"cast": true, "aim_point": defeat.hero.position + Vector2(-2, 0)}, DT)
	_check(defeat.outcome == "lost", "An enemy strike can end the encounter")

	var main = preload("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(390, 844)
	main.has_touch = true
	main._layout()
	for id in ["up", "down", "left", "right", "cast", "slash", "bolt", "preview"]:
		_check(main.buttons[id].visible and Rect2(Vector2.ZERO, main.size).encloses(
			main.buttons[id].get_global_rect()), "Portrait includes " + id)
	var right: Vector2 = main.buttons.right.get_global_rect().get_center()
	var cast: Vector2 = main.buttons.cast.get_global_rect().get_center()
	main._handle_touch(_touch_at(0, right, true))
	main._handle_touch(_touch_at(1, cast, true))
	main._physics_process(DT)
	_check(main.battle.hero.position.x > 7.75 and main.battle.cooldowns.slash > 0,
		"Separate touch fingers move and cast simultaneously")
	main._handle_touch(_touch_at(0, right, false))
	main._handle_touch(_touch_at(1, cast, false))
	var position: Vector2 = main.battle.hero.position
	main._physics_process(DT)
	_check(main.battle.hero.position.is_equal_approx(position), "Touch release stops movement")
	main._activate("help")
	_check(main.help_open and main.buttons.continue.visible, "Help opens")
	main._activate("continue")
	main._activate("restart")
	_check(main.battle.outcome == "ready" and main.battle.hero.hp == 100, "Restart creates a fresh battle")
	main.size = Vector2(844, 390)
	main._layout()
	_check(main.buttons.cast.position.x >= main.arena.position.x + main.arena.size.x,
		"Landscape puts touch controls beside the arena")
	await process_frame
	print("Emberwatch smoke checks: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _touch_at(index: int, point: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	return event
