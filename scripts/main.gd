extends Control
## Responsive game interface. Touch fingers own their actions independently.

const Battle = preload("res://scripts/battle.gd")
const Data = preload("res://scripts/battle_data.gd")
const Iso = preload("res://scripts/projection.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const UI_FONT = preload("res://assets/fonts/EmberwatchSans.otf")
const FIRE := Color("#f3bb83")
const ICE := Color("#a9ddd4")
const PAPER := Color("#eee3d4")
const MUTED := Color("#a9aca9")
const DARK := Color("#151a20")
const EDGE := Color("#3d4549")
const ENEMY_NAMES := {"slime": "苔地史萊姆", "golem": "石像魔", "bat": "暮翼蝙蝠"}
const DIRECTION := {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}
const STATUS := {"ready": "待命", "playing": "戰鬥中", "won": "勝利", "lost": "敗北"}

var battle: Battle
var arena: ArenaView
var buttons: Dictionary = {}
var items: Dictionary = {}
var bars: Dictionary = {}
var pending: Dictionary = {}
var fingers: Dictionary = {}
var mouse_dirs: Dictionary = {}
var tapped := Vector2.ZERO
var has_touch := false
var focused := true
var help_open := false

func _ready() -> void:
	battle = Battle.new()
	theme = Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", PAPER)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	has_touch = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		has_touch = has_touch or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0"))
	_create_interface()
	resized.connect(_layout)
	_layout()
	_refresh()

func _create_interface() -> void:
	_panel("frame", Color("#101820"), EDGE)
	arena = ArenaView.new()
	add_child(arena)
	_texture("crest", preload("res://assets/ui/logo.png"))
	_label("series", "餘燼林境", 13, FIRE)
	_label("title", "灰苔遺跡", 29, PAPER)
	_label("status", "", 14, FIRE, HORIZONTAL_ALIGNMENT_RIGHT)
	_panel("health_back", Color("#161c22e8"), Color("#716451"))
	_label("health", "", 13, PAPER)
	_panel("score_back", Color("#161c22e8"), Color("#716451"))
	_label("score", "", 13, FIRE, HORIZONTAL_ALIGNMENT_CENTER)
	_bar("hero", 100, FIRE)

	_button("slash", "餘燼斬  Q", FIRE, preload("res://assets/ui/slash.png"))
	_button("bolt", "霜星箭  E", ICE, preload("res://assets/ui/bolt.png"))
	_button("preview", "範圍  V", PAPER)
	_button("help", "操作", PAPER)
	_button("restart", "重開", PAPER)

	_panel("side", Color("#20272d"), EDGE)
	_label("objective", "戰鬥目標", 19, PAPER)
	_label("progress", "", 14, FIRE)
	_bar("kills", 3, FIRE)
	for id in ENEMY_NAMES:
		_label(id, "", 13, MUTED)
		_bar(id, _enemy_by_id(id).max_hp, Color("#c77679"))
	_label("skill_title", "", 19, FIRE)
	_label("skill_desc", "", 14, PAPER, HORIZONTAL_ALIGNMENT_LEFT, true)
	_label("skill_stats", "", 13, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
	_label("hint", "", 12, MUTED)

	for pair in [["up", "↑"], ["left", "←"], ["down", "↓"], ["right", "→"]]:
		var id: String = pair[0]
		var button := _button(id, pair[1], PAPER)
		button.add_theme_font_size_override("font_size", 25)
		button.button_down.connect(_mouse_move.bind(id, true))
		button.button_up.connect(_mouse_move.bind(id, false))
	var cast_button := _button("cast", "施放", FIRE)
	cast_button.add_theme_font_size_override("font_size", 22)

	_panel("shade", Color("#0d1218cf"), Color.TRANSPARENT)
	_panel("dialog", Color("#222a30"), Color("#a68a67"))
	_label("dialog_title", "", 24, FIRE, HORIZONTAL_ALIGNMENT_CENTER)
	_label("dialog_text", "", 14, PAPER, HORIZONTAL_ALIGNMENT_CENTER, true)
	_button("continue", "返回戰場", FIRE)

func _label(id: String, value: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	items[id] = label
	return label

func _texture(id: String, image: Texture2D) -> void:
	var rect := TextureRect.new()
	rect.texture = image
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	items[id] = rect

func _panel(id: String, color: Color, border: Color) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _surface(color, border, 8))
	add_child(panel)
	items[id] = panel

func _bar(id: String, maximum: float, tint: Color) -> void:
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _surface(Color("#34343d"), Color.TRANSPARENT, 3))
	bar.add_theme_stylebox_override("fill", _surface(tint, Color.TRANSPARENT, 3))
	add_child(bar)
	bars[id] = bar

func _button(id: String, caption: String, tint: Color, icon: Texture2D = null) -> Button:
	var button := Button.new()
	button.text = caption
	button.icon = icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_constant_override("icon_max_width", 26)
	button.add_theme_stylebox_override("normal", _surface(Color("#262e35"), tint.darkened(0.57), 7))
	button.add_theme_stylebox_override("hover", _surface(Color("#39444a"), tint.darkened(0.23), 7))
	button.add_theme_stylebox_override("pressed", _surface(Color("#48484a"), tint, 7))
	button.pressed.connect(_activate.bind(id))
	add_child(button)
	buttons[id] = button
	return button

static func _surface(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DARK)
	draw_line(Vector2(0, 1), Vector2(size.x, 1), Color("#79614b"), 2)

func _box(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y).round()
	control.size = Vector2(maxf(1, width), maxf(1, height)).round()

func _layout() -> void:
	if not is_instance_valid(arena):
		return
	var desktop := size.x >= 900 and size.y >= 550 and not has_touch
	var horizontal := not desktop and size.x >= size.y * 1.28 and size.x >= 535
	var margin := 24.0 if desktop else 12.0
	var width := minf(size.x - margin * 2.0, 1280.0)
	var x := (size.x - width) * 0.5
	var top := 14.0 if desktop else 8.0
	var header := 74.0 if desktop else (50.0 if horizontal else 57.0)
	_box(items.crest, x, top + 10, 32, 32)
	_box(items.series, x + 39, top, 110, 19)
	_box(items.title, x + 39, top + 16, 178, 34)
	_box(buttons.restart, x + width - 53, top + 15, 53, 36)
	_box(buttons.help, x + width - 111, top + 15, 53, 36)
	_box(items.status, x + width - 177, top + 15, 59, 36)
	items.status.visible = width >= 345
	var y := top + header
	var arena_w := width
	var arena_h := width * Iso.SIZE.y / Iso.SIZE.x
	var side_x := 0.0
	var side_w := 0.0
	if desktop:
		side_w = 260.0
		arena_w = minf(width - side_w - 14.0, (size.y - y - 100.0) * Iso.SIZE.x / Iso.SIZE.y)
		arena_h = arena_w * Iso.SIZE.y / Iso.SIZE.x
		side_x = x + arena_w + 14.0
	elif horizontal:
		side_w = clampf(width * 0.30, 195.0, 300.0)
		arena_w = width - side_w - 10.0
		arena_h = minf(arena_w * Iso.SIZE.y / Iso.SIZE.x, size.y - y - 12.0)
		side_x = x + arena_w + 10.0
	else:
		arena_h = minf(arena_h, maxf(125.0, size.y - y - 224.0))
	_box(items.frame, x - 1, y - 1, arena_w + 2, arena_h + 2)
	_box(arena, x, y, arena_w, arena_h)
	_box(items.health_back, x + 9, y + 9, 119, 35)
	_box(items.health, x + 16, y + 11, 106, 19)
	_box(bars.hero, x + 16, y + 32, 105, 5)
	_box(items.score_back, x + arena_w - 79, y + 9, 70, 35)
	_box(items.score, x + arena_w - 75, y + 9, 62, 35)
	items.score.visible = not desktop
	items.score_back.visible = not desktop

	var action_x := side_x if horizontal else x
	var action_y := y if horizontal else y + arena_h + 10.0
	var action_w := side_w if horizontal else arena_w
	var preview_w := 63.0 if horizontal else 93.0
	var skill_w := (action_w - preview_w - 12.0) * 0.5
	_box(buttons.slash, action_x, action_y, skill_w, 45)
	_box(buttons.bolt, action_x + skill_w + 6.0, action_y, skill_w, 45)
	_box(buttons.preview, action_x + action_w - preview_w, action_y, preview_w, 45)
	buttons.slash.text = "斬" if horizontal else "餘燼斬  Q"
	buttons.bolt.text = "箭" if horizontal else "霜星箭  E"
	buttons.preview.text = "範圍" if horizontal else "範圍  V"
	var portrait_card_y := action_y + 192.0
	var show_portrait_card := not desktop and not horizontal and size.y - portrait_card_y >= 350.0
	if show_portrait_card:
		_layout_sidebar(true, x, portrait_card_y, width, 338.0)
	else:
		_layout_sidebar(desktop, side_x, y, side_w, arena_h)
	_layout_touch(not desktop, action_x, action_y + 54.0, action_w, horizontal)
	if desktop:
		_box(items.hint, x, action_y + 51, arena_w, 24)
	else:
		_box(items.hint, action_x, action_y + (148 if horizontal else 167), action_w, 20)
	items.hint.visible = items.hint.position.y + 20 <= size.y
	items.hint.text = "WASD 移動　滑鼠瞄準　左鍵或空白鍵施放" if desktop else "按住方向鍵移動　點戰場瞄準與施放"
	_layout_dialog()

func _layout_sidebar(show_panel: bool, x: float, y: float, width: float, height: float) -> void:
	for id in ["side", "objective", "progress", "slime", "golem", "bat", "skill_title", "skill_desc", "skill_stats"]:
		items[id].visible = show_panel
	for id in ["kills", "slime", "golem", "bat"]:
		bars[id].visible = show_panel
	if not show_panel:
		return
	var pad := 14.0
	_box(items.side, x, y, width, maxf(height, 338.0))
	_box(items.objective, x + pad, y + 12, width - 2 * pad, 27)
	_box(items.progress, x + pad, y + 40, width - 2 * pad, 22)
	_box(bars.kills, x + pad, y + 66, width - 2 * pad, 6)
	var row := y + 81.0
	for id in ENEMY_NAMES:
		_box(items[id], x + pad, row, width - 2 * pad, 19)
		_box(bars[id], x + pad, row + 21, width - 2 * pad, 4)
		row += 32.0
	_box(items.skill_title, x + pad, row + 6, width - 2 * pad, 29)
	_box(items.skill_desc, x + pad, row + 36, width - 2 * pad, 57)
	_box(items.skill_stats, x + pad, row + 101, width - 2 * pad, 42)

func _layout_touch(show_controls: bool, x: float, y: float, width: float, horizontal: bool) -> void:
	for id in ["up", "left", "down", "right", "cast"]:
		buttons[id].visible = show_controls
	if not show_controls:
		return
	var cell := 44.0 if horizontal else 50.0
	var gap := 3.0
	var dpad := cell * 3.0 + gap * 2.0
	_box(buttons.up, x + cell + gap, y, cell, cell)
	_box(buttons.left, x, y + cell + gap, cell, cell)
	_box(buttons.down, x + cell + gap, y + cell + gap, cell, cell)
	_box(buttons.right, x + (cell + gap) * 2.0, y + cell + gap, cell, cell)
	var cast_width := minf(128.0, width - dpad - 5.0)
	buttons.cast.add_theme_font_size_override("font_size", 18 if cast_width < 60.0 else 22)
	_box(buttons.cast, x + width - cast_width, y + 14, cast_width, cell * 1.55)

func _layout_dialog() -> void:
	var width := minf(size.x - 32.0, 460.0)
	var height := minf(size.y - 24.0, 248.0)
	var at := (size - Vector2(width, height)) * 0.5
	_box(items.shade, 0, 0, size.x, size.y)
	_box(items.dialog, at.x, at.y, width, height)
	_box(items.dialog_title, at.x + 12, at.y + 10, width - 24, 37)
	_box(items.dialog_text, at.x + 16, at.y + 53, width - 32, height - 112)
	_box(buttons.continue, at.x + (width - 138) * 0.5, at.y + height - 51, 138, 38)

func _refresh() -> void:
	arena.update_battle(battle)
	_set_text("status", STATUS[battle.outcome])
	_set_text("health", "生命  %d / %d" % [battle.hero.hp, battle.hero.max_hp])
	bars.hero.value = battle.hero.hp
	_set_text("progress", "擊敗魔物  %d / %d" % [battle.defeated_count(), battle.enemies.size()])
	bars.kills.value = battle.defeated_count()
	_set_text("score", "%d / %d" % [battle.defeated_count(), battle.enemies.size()])
	for enemy in battle.enemies:
		var state := "待命"
		if enemy.hp == 0:
			state = "已擊敗"
		elif enemy.wind > 0:
			state = "蓄力中"
		elif arena.targets.has(enemy.id):
			state = "範圍內"
		elif enemy.active:
			state = "交戰中"
		_set_text(enemy.id, "%s    %s" % [ENEMY_NAMES[enemy.id], state])
		bars[enemy.id].value = enemy.hp
	var skill: Dictionary = Data.SKILLS[battle.selected]
	_set_text("skill_title", skill.name)
	_set_text("skill_desc", skill.description)
	_set_text("skill_stats", "傷害 %d   距離 %s 格\n冷卻 %s 秒" % [skill.damage, skill.range, skill.cooldown])
	for id in ["slash", "bolt"]:
		var current: bool = id == battle.selected
		var tint := FIRE if id == "slash" else ICE
		buttons[id].self_modulate = Color.WHITE if current else Color("#a9adaf")
		var cd: float = battle.cooldowns[id]
		var action_w: float = buttons[id].size.x
		var short_caption: String = "斬" if id == "slash" else "箭"
		# Keep the full name on desktop and the button target wide enough on small phones.
		var caption: String = short_caption if action_w < 95 else Data.SKILLS[id].name + "  " + Data.SKILLS[id].key
		if cd > 0.02 and not battle.is_finished():
			caption = "%.1f 秒" % (ceilf(cd * 10.0) / 10.0)
		if buttons[id].text != caption:
			buttons[id].text = caption
		buttons[id].add_theme_color_override("font_color", tint if current else PAPER)
	buttons.preview.self_modulate = Color.WHITE if battle.preview else Color("#999da1")
	buttons.cast.self_modulate = Color("#ffcf99") if fingers.values().has("cast") else Color.WHITE
	for id in DIRECTION:
		buttons[id].self_modulate = Color("#f2b780") if fingers.values().has(id) else Color.WHITE
	_refresh_dialog()

func _set_text(id: String, value: String) -> void:
	if items[id].text != value:
		items[id].text = value

func _refresh_dialog() -> void:
	var shown := help_open or battle.is_finished()
	for id in ["shade", "dialog", "dialog_title", "dialog_text"]:
		items[id].visible = shown
	buttons.continue.visible = shown
	if not shown:
		return
	if help_open:
		_set_text("dialog_title", "操作說明")
		_set_text("dialog_text", "鍵鼠　WASD／方向鍵移動，滑鼠瞄準，左鍵或空白鍵施放。\n觸控　按方向鍵移動，點戰場瞄準並施放，拖曳可調整瞄準。\nQ／E 切換技能，V 開關範圍預覽。")
		buttons.continue.text = "返回戰場"
	else:
		_set_text("dialog_title", "遺跡已肅清" if battle.outcome == "won" else "餘燼行者倒下了")
		_set_text("dialog_text", "已擊敗 %d／%d 隻魔物。" % [battle.defeated_count(), battle.enemies.size()])
		buttons.continue.text = "再玩一次"

func _enemy_by_id(id: String) -> Dictionary:
	for enemy in battle.enemies:
		if enemy.id == id:
			return enemy
	return {}

func _activate(id: String) -> void:
	if id == "continue":
		if help_open:
			help_open = false
			_clear_controls()
		else:
			_restart()
	elif not help_open and not battle.is_finished():
		match id:
			"slash", "bolt": pending.skill = id
			"preview": pending.toggle_preview = not pending.get("toggle_preview", false)
			"cast": pending.cast = true
			"help":
				help_open = true
				_clear_controls()
			"restart": _restart()
	_refresh()

func _restart() -> void:
	battle = Battle.new()
	_clear_controls()

func _mouse_move(id: String, pressed: bool) -> void:
	if pressed and not help_open and not battle.is_finished():
		mouse_dirs[id] = true
		tapped += DIRECTION[id]
		pending.clear_aim = true
	else:
		mouse_dirs.erase(id)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(arena):
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if fingers.get(event.index) == "aim":
			_aim(event.position, false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if help_open and event.is_action_pressed("ui_cancel"):
			_activate("continue")
			get_viewport().set_input_as_handled()
		elif not help_open and not battle.is_finished():
			for pair in [["pick_slash", "slash"], ["pick_bolt", "bolt"], ["preview", "preview"], ["cast", "cast"]]:
				if event.is_action_pressed(pair[0]):
					_activate(pair[1])
					get_viewport().set_input_as_handled()
					break

func _unhandled_input(event: InputEvent) -> void:
	if help_open or battle.is_finished():
		return
	if event is InputEventMouseMotion:
		_aim(event.position, false)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_aim(event.position, true)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if not event.pressed or event.canceled:
		fingers.erase(event.index)
		return
	if not has_touch:
		has_touch = true
		_layout()
	if help_open or battle.is_finished():
		if _over_button("continue", event.position):
			_activate("continue")
		return
	for id in ["slash", "bolt", "preview", "restart", "help", "cast", "up", "left", "down", "right"]:
		if not _over_button(id, event.position):
			continue
		if DIRECTION.has(id):
			fingers[event.index] = id
			tapped += DIRECTION[id]
			if not fingers.values().has("aim"):
				pending.clear_aim = true
		else:
			if id == "cast":
				fingers[event.index] = id
			_activate(id)
		return
	if _aim(event.position, true):
		fingers[event.index] = "aim"

func _over_button(id: String, at: Vector2) -> bool:
	var button: Button = buttons[id]
	return button.visible and button.get_global_rect().has_point(at)

func _aim(point: Vector2, cast: bool) -> bool:
	var local := arena.get_global_transform().affine_inverse() * point
	if not arena.canvas_rect().has_point(local):
		return false
	pending.aim_point = arena.aim_point(local)
	pending.erase("clear_aim")
	if cast:
		pending.cast = true
	return true

func _clear_controls() -> void:
	pending.clear()
	fingers.clear()
	mouse_dirs.clear()
	tapped = Vector2.ZERO

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		focused = false
		_clear_controls()
	if what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		focused = true

func _physics_process(delta: float) -> void:
	if not focused or help_open:
		return
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down") + tapped
	for id in DIRECTION:
		if fingers.values().has(id) or mouse_dirs.has(id):
			# A newly pressed button is already represented in the tap buffer.
			if tapped.dot(DIRECTION[id]) <= 0.0:
				movement += DIRECTION[id]
	tapped = Vector2.ZERO
	pending.move = movement.limit_length(1.0)
	battle.step(pending, delta)
	pending.clear()
	_refresh()
