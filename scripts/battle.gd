extends RefCounted
## Grid-space simulation. The renderer and input layers only read state or send commands.

const Data = preload("res://scripts/battle_data.gd")
const SLASH: Dictionary = Data.SKILLS["slash"]
const BOLT: Dictionary = Data.SKILLS["bolt"]

var clock := 0.0
var outcome := "ready"
var selected := "slash"
var preview := true
var aim := Data.DEFAULT_AIM
var pointer: Variant = null
var hero: Dictionary = {
	"position": Data.HERO_SPAWN, "hp": 100, "max_hp": 100, "radius": Data.PLAYER_RADIUS,
	"facing": 1, "stride": 0.0, "moving": false, "hurt": 0.0
}
var enemies: Array[Dictionary] = []
var cooldowns := {"slash": 0.0, "bolt": 0.0}
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var solid_cells: Dictionary = {}

func _init() -> void:
	for prop in Data.PROPS:
		solid_cells[prop.cell] = true
	for source in Data.ENEMIES:
		var enemy: Dictionary = source.duplicate()
		enemy.merge({
			"hp": enemy.max_hp, "active": false, "delay": 0.0,
			"wind": 0.0, "hurt": 0.0, "slow": 0.0, "stride": 0.0
		})
		enemies.append(enemy)

static func has_ground(cell: Vector2i) -> bool:
	const EDGE := Data.ARENA_SIZE - 1
	return (cell.x >= 0 and cell.y >= 0 and cell.x <= EDGE and cell.y <= EDGE
		and cell.x + cell.y >= 2 and cell.x + cell.y <= 2 * EDGE - 2
		and absi(cell.x - cell.y) <= EDGE - 2)

func is_solid(point: Vector2) -> bool:
	var cell := Vector2i(point.floor())
	return not has_ground(cell) or solid_cells.has(cell)

func is_finished() -> bool:
	return outcome == "won" or outcome == "lost"

func defeated_count() -> int:
	var count := 0
	for enemy in enemies:
		if enemy.hp == 0:
			count += 1
	return count

func step(command: Dictionary, dt: float) -> void:
	if command.has("skill") and Data.SKILLS.has(command.skill):
		selected = command.skill
	if command.get("toggle_preview", false):
		preview = not preview
	if command.has("aim_point"):
		pointer = command.aim_point
	if command.get("clear_aim", false):
		pointer = null
	_update_aim()

	clock += dt
	for i in range(effects.size() - 1, -1, -1):
		var item: Dictionary = effects[i]
		item.age += dt
		if item.age >= item.duration:
			effects.remove_at(i)
	if is_finished():
		return

	var movement: Vector2 = command.get("move", Vector2.ZERO)
	var wants_cast: bool = command.get("cast", false)
	if outcome == "ready" and (not movement.is_zero_approx() or wants_cast):
		outcome = "playing"
	if outcome != "playing":
		return

	hero.hurt = maxf(0.0, hero.hurt - dt)
	hero.moving = false
	if not movement.is_zero_approx():
		var direction := movement.normalized()
		var world_move := Vector2(direction.y + direction.x, direction.y - direction.x) * sqrt(0.5)
		var before: Vector2 = hero.position
		_move_body(hero, world_move * Data.PLAYER_SPEED * dt, enemies)
		if direction.x != 0:
			hero.facing = signf(direction.x)
		var distance: float = before.distance_to(hero.position)
		hero.moving = distance > 0
		hero.stride += distance * 13.0
		_update_aim()
	if pointer != null and absf(aim.x - aim.y) > 0.06:
		hero.facing = signf(aim.x - aim.y)

	for id in cooldowns:
		cooldowns[id] = maxf(0.0, cooldowns[id] - dt)
	if wants_cast:
		_cast()
	_advance_projectiles(dt)
	if defeated_count() == enemies.size():
		outcome = "won"
		return
	for enemy in enemies:
		_advance_enemy(enemy, dt)
	if hero.hp == 0:
		outcome = "lost"

func attack_range() -> float:
	if selected == "slash":
		return SLASH.range
	var distance := 0.12
	while distance <= BOLT.range:
		if is_solid(hero.position + aim * distance):
			return distance - 0.12
		distance += 0.12
	return BOLT.range

func preview_targets(distance: float) -> Array[String]:
	var targets: Array[String] = []
	if not preview or is_finished():
		return targets
	if selected == "bolt":
		var candidates := _bolt_targets(hero.position, aim, distance)
		if not candidates.is_empty():
			targets.append(candidates[0].enemy.id)
		return targets
	for enemy in enemies:
		if _can_slash(enemy):
			targets.append(enemy.id)
	return targets

func _update_aim() -> void:
	if pointer == null:
		return
	var offset: Vector2 = pointer - hero.position
	if offset.length() >= 0.14:
		aim = offset.normalized()

func _body_open(point: Vector2, radius: float, blockers: Array) -> bool:
	for corner in [Vector2(-radius, -radius), Vector2(radius, -radius),
			Vector2(-radius, radius), Vector2(radius, radius)]:
		if is_solid(point + corner):
			return false
	for other in blockers:
		if other.hp > 0 and point.distance_to(other.position) < radius + other.radius:
			return false
	return true

func _move_body(body: Dictionary, offset: Vector2, blockers: Array) -> void:
	var position: Vector2 = body.position
	var candidate := position + Vector2(offset.x, 0)
	if _body_open(candidate, body.radius, blockers):
		position = candidate
	candidate = position + Vector2(0, offset.y)
	if _body_open(candidate, body.radius, blockers):
		position = candidate
	body.position = position

func _line_clear(start: Vector2, finish: Vector2) -> bool:
	var samples := ceili(start.distance_to(finish) * 9.0)
	for i in range(1, samples + 1):
		if is_solid(start.lerp(finish, float(i) / samples)):
			return false
	return true

func _can_slash(enemy: Dictionary) -> bool:
	if enemy.hp <= 0:
		return false
	var offset: Vector2 = enemy.position - hero.position
	var distance := offset.length()
	return (distance <= SLASH.range and offset.dot(aim) >= cos(SLASH.half_angle) * distance
		and _line_clear(hero.position, enemy.position))

func _bolt_targets(origin: Vector2, heading: Vector2, limit: float) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		var offset: Vector2 = enemy.position - origin
		var along := offset.dot(heading)
		if along >= 0 and along <= limit and absf(offset.cross(heading)) <= BOLT.half_width:
			candidates.append({"enemy": enemy, "along": along})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.along < b.along)
	return candidates

func _effect(kind: String, position: Vector2, duration: float, parameters := {}) -> void:
	var item := {"kind": kind, "position": position, "duration": duration, "age": 0.0}
	item.merge(parameters)
	effects.append(item)

func _damage(enemy: Dictionary, damage: int, ice: bool) -> void:
	enemy.hp = maxi(0, enemy.hp - damage)
	enemy.active = true
	enemy.hurt = 0.18
	if ice:
		enemy.slow = BOLT.slow
	_effect("ice_hit" if ice else "fire_hit", enemy.position, 0.48, {"amount": damage})
	if enemy.hp == 0:
		_effect("fall", enemy.position, 0.68)

func _cast() -> void:
	if cooldowns[selected] > 0:
		return
	cooldowns[selected] = Data.SKILLS[selected].cooldown
	if selected == "bolt":
		projectiles.append({
			"origin": hero.position, "position": hero.position, "aim": aim, "traveled": 0.0
		})
		_effect("release", hero.position, 0.17)
		return
	_effect("slash", hero.position, 0.26, {"aim": aim})
	for enemy in enemies:
		if _can_slash(enemy):
			_damage(enemy, SLASH.damage, false)

func _advance_projectiles(dt: float) -> void:
	var remaining: Array[Dictionary] = []
	for projectile in projectiles:
		if _step_projectile(projectile, dt):
			remaining.append(projectile)
	projectiles = remaining

func _step_projectile(projectile: Dictionary, dt: float) -> bool:
	var distance := minf(BOLT.range, projectile.traveled + dt * BOLT.speed)
	for candidate in _bolt_targets(projectile.origin, projectile.aim, distance):
		if candidate.along + 0.26 < projectile.traveled:
			continue
		var hit: Vector2 = projectile.origin + projectile.aim * candidate.along
		if not _line_clear(projectile.position, hit):
			break
		_damage(candidate.enemy, BOLT.damage, true)
		return false
	var next: Vector2 = projectile.origin + projectile.aim * distance
	if not _line_clear(projectile.position, next):
		_effect("release", projectile.position, 0.2)
		return false
	projectile.position = next
	projectile.traveled = distance
	return distance < BOLT.range

func _advance_enemy(enemy: Dictionary, dt: float) -> void:
	if enemy.hp <= 0:
		return
	var offset: Vector2 = hero.position - enemy.position
	var distance := offset.length()
	for key in ["hurt", "slow", "delay"]:
		enemy[key] = maxf(0.0, enemy[key] - dt)
	if distance < 4.15 and _line_clear(enemy.position, hero.position):
		enemy.active = true
	if not enemy.active:
		return
	if enemy.wind > 0:
		enemy.wind = maxf(0.0, enemy.wind - dt)
		if enemy.wind == 0:
			_effect("enemy_strike", enemy.position, 0.25, {"range": enemy.reach})
			if distance <= enemy.reach and _line_clear(enemy.position, hero.position):
				hero.hp = maxi(0, hero.hp - enemy.power)
				hero.hurt = 0.3
				_effect("hero_hit", hero.position, 0.47, {"amount": enemy.power})
			enemy.delay = enemy.cooldown
		return
	if distance < enemy.reach * 0.9 and _line_clear(enemy.position, hero.position):
		if enemy.delay == 0:
			enemy.wind = enemy.windup
		return
	if enemy.hurt > 0.09:
		return
	var blockers: Array[Dictionary] = [hero]
	for other in enemies:
		if not is_same(other, enemy):
			blockers.append(other)
	var speed: float = enemy.speed * (0.54 if enemy.slow > 0 else 1.0)
	var before: Vector2 = enemy.position
	_move_body(enemy, offset.normalized() * speed * dt, blockers)
	enemy.stride += before.distance_to(enemy.position) * 10.0
