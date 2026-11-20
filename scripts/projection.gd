extends RefCounted

const SIZE := Vector2(576, 340)
const ORIGIN := Vector2(288, 47)
const HALF_TILE := Vector2(14, 7)

static func project(point: Vector2) -> Vector2:
	return ORIGIN + Vector2(point.x - point.y, point.x + point.y) * HALF_TILE

static func unproject(point: Vector2) -> Vector2:
	var offset := (point - ORIGIN) / HALF_TILE
	return Vector2(offset.x + offset.y, offset.y - offset.x) * 0.5
