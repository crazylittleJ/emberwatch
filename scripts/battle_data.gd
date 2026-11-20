extends RefCounted

const ARENA_SIZE := 17
const PLAYER_SPEED := 4.3
const PLAYER_RADIUS := 0.27
const HERO_SPAWN := Vector2(7.75, 10.25)
const DEFAULT_AIM := Vector2(0.46, -0.89)

const SKILLS := {
	"slash": {
		"key": "Q",
		"name": "餘燼斬",
		"short": "近距扇形",
		"category": "近距 · 扇形斬擊",
		"description": "向瞄準方向揮出火焰，擊中扇形範圍內的所有魔物。",
		"range": 3.4,
		"half_angle": PI / 4.0,
		"damage": 36,
		"cooldown": 0.7
	},
	"bolt": {
		"key": "E",
		"name": "霜星箭",
		"short": "遠距直線",
		"category": "遠距 · 直線投射",
		"description": "發射霜星，命中第一隻魔物時造成傷害並短暫緩速。",
		"range": 8,
		"half_width": 0.52,
		"damage": 52,
		"cooldown": 1.25,
		"speed": 16,
		"slow": 1.45
	}
}

const PROPS := [
	{"cell": Vector2i(1, 2), "art": "pine", "sprite_key": "1_2"},
	{"cell": Vector2i(1, 4), "art": "pine", "sprite_key": "1_4"},
	{"cell": Vector2i(0, 6), "art": "pine", "sprite_key": "0_6"},
	{"cell": Vector2i(4, 1), "art": "pine", "sprite_key": "4_1"},
	{"cell": Vector2i(5, 0), "art": "pine", "sprite_key": "5_0"},
	{"cell": Vector2i(7, 1), "art": "pine", "sprite_key": "7_1"},
	{"cell": Vector2i(10, 1), "art": "pine", "sprite_key": "10_1"},
	{"cell": Vector2i(12, 2), "art": "stone", "sprite_key": "12_2"},
	{"cell": Vector2i(14, 1), "art": "pine", "sprite_key": "14_1"},
	{"cell": Vector2i(16, 4), "art": "pine", "sprite_key": "16_4"},
	{"cell": Vector2i(15, 5), "art": "pine", "sprite_key": "15_5"},
	{"cell": Vector2i(16, 7), "art": "pine", "sprite_key": "16_7"},
	{"cell": Vector2i(16, 10), "art": "pine", "sprite_key": "16_10"},
	{"cell": Vector2i(15, 13), "art": "pine", "sprite_key": "15_13"},
	{"cell": Vector2i(14, 15), "art": "pine", "sprite_key": "14_15"},
	{"cell": Vector2i(13, 16), "art": "stone", "sprite_key": "13_16"},
	{"cell": Vector2i(10, 16), "art": "pine", "sprite_key": "10_16"},
	{"cell": Vector2i(4, 16), "art": "pine", "sprite_key": "4_16"},
	{"cell": Vector2i(2, 15), "art": "pine", "sprite_key": "2_15"},
	{"cell": Vector2i(1, 14), "art": "pine", "sprite_key": "1_14"},
	{"cell": Vector2i(1, 10), "art": "pine", "sprite_key": "1_10"},
	{"cell": Vector2i(2, 12), "art": "stone", "sprite_key": "2_12"},
	{"cell": Vector2i(2, 8), "art": "pine", "sprite_key": "2_8"},
	{"cell": Vector2i(0, 12), "art": "pine", "sprite_key": "0_12"},
	{"cell": Vector2i(6, 15), "art": "stone", "sprite_key": "6_15"},
	{"cell": Vector2i(14, 10), "art": "stone", "sprite_key": "14_10"},
	{"cell": Vector2i(13, 4), "art": "pine", "sprite_key": "13_4"},
	{"cell": Vector2i(4, 4), "art": "pillar", "sprite_key": "4_4"},
	{"cell": Vector2i(7, 4), "art": "gate", "sprite_key": "7_4"},
	{"cell": Vector2i(6, 3), "art": "torch", "sprite_key": "6_3"},
	{"cell": Vector2i(10, 4), "art": "torch", "sprite_key": "10_4"},
	{"cell": Vector2i(12, 12), "art": "torch", "sprite_key": "12_12"},
	{"cell": Vector2i(5, 12), "art": "torch", "sprite_key": "5_12"},
	{"cell": Vector2i(5, 6), "art": "wall", "sprite_key": "5_6"},
	{"cell": Vector2i(4, 7), "art": "wall", "sprite_key": "4_7"},
	{"cell": Vector2i(11, 13), "art": "pillar", "sprite_key": "11_13"},
	{"cell": Vector2i(9, 14), "art": "wall", "sprite_key": "9_14"},
	{"cell": Vector2i(8, 14), "art": "wall", "sprite_key": "8_14"}
]

const ENEMIES := [
	{"id": "slime", "position": Vector2(8.9, 8), "max_hp": 52, "speed": 1.72, "power": 11,
		"reach": 1.28, "windup": 0.46, "cooldown": 0.92, "radius": 0.33},
	{"id": "golem", "position": Vector2(12.5, 8.15), "max_hp": 108, "speed": 1.33, "power": 22,
		"reach": 1.7, "windup": 0.66, "cooldown": 1.18, "radius": 0.42},
	{"id": "bat", "position": Vector2(5.95, 8.3), "max_hp": 46, "speed": 2.48, "power": 9,
		"reach": 1.19, "windup": 0.35, "cooldown": 0.85, "radius": 0.27}
]
