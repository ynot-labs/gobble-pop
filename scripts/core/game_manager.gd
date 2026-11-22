extends Node

const SAVE_PATH := "user://gobble_pop_save.json"
const BUILD_CONFIG_PATH := "res://data/build_config.json"

signal economy_changed()
signal skin_equipped(skin_id: String)
signal settings_changed()

const SKIN_CATALOG: Array[Dictionary] = [
	{
		"id": "classic",
		"name": "Champagne",
		"icon": "skin_classic",
		"currency": "free",
		"cost": 0,
		"gold_dark": Color(0.46, 0.31, 0.12),
		"gold_mid": Color(0.84, 0.68, 0.34),
		"gold_shine": Color(1.00, 0.96, 0.80),
		"xp_cyan": Color(0.30, 0.96, 1.00),
		"vortex_abyss": Color(0.02, 0.16, 0.24),
		"vortex_teal": Color(0.07, 0.62, 0.72),
		"vortex_aqua": Color(0.45, 0.95, 0.98),
	},
	{
		"id": "berry",
		"name": "Berry Pop",
		"icon": "skin_berry",
		"currency": "coins",
		"cost": 200,
		"gold_dark": Color(0.55, 0.14, 0.34),
		"gold_mid": Color(0.95, 0.42, 0.68),
		"gold_shine": Color(1.00, 0.88, 0.95),
		"xp_cyan": Color(1.00, 0.92, 0.35),
		"vortex_abyss": Color(0.22, 0.03, 0.14),
		"vortex_teal": Color(0.82, 0.16, 0.48),
		"vortex_aqua": Color(1.00, 0.60, 0.82),
	},
	{
		"id": "mint",
		"name": "Mint Jade",
		"icon": "skin_mint",
		"currency": "coins",
		"cost": 350,
		"gold_dark": Color(0.08, 0.42, 0.30),
		"gold_mid": Color(0.24, 0.82, 0.58),
		"gold_shine": Color(0.84, 1.00, 0.92),
		"xp_cyan": Color(0.98, 0.96, 0.45),
		"vortex_abyss": Color(0.02, 0.18, 0.14),
		"vortex_teal": Color(0.10, 0.66, 0.48),
		"vortex_aqua": Color(0.56, 0.98, 0.78),
	},
	{
		"id": "neon",
		"name": "Cyber Neon",
		"icon": "skin_neon",
		"currency": "shards",
		"cost": 8,
		"gold_dark": Color(0.10, 0.24, 0.55),
		"gold_mid": Color(0.16, 0.86, 0.98),
		"gold_shine": Color(0.82, 0.99, 1.00),
		"xp_cyan": Color(1.00, 0.32, 0.88),
		"vortex_abyss": Color(0.08, 0.03, 0.24),
		"vortex_teal": Color(0.46, 0.18, 0.92),
		"vortex_aqua": Color(0.26, 0.94, 1.00),
	},
	{
		"id": "magma",
		"name": "Solar Gold",
		"icon": "skin_magma",
		"currency": "coins",
		"cost": 600,
		"gold_dark": Color(0.56, 0.18, 0.06),
		"gold_mid": Color(0.98, 0.52, 0.14),
		"gold_shine": Color(1.00, 0.94, 0.64),
		"xp_cyan": Color(1.00, 0.96, 0.48),
		"vortex_abyss": Color(0.24, 0.05, 0.02),
		"vortex_teal": Color(0.92, 0.30, 0.08),
		"vortex_aqua": Color(1.00, 0.76, 0.22),
	},
	{
		"id": "royal",
		"name": "Royal Star",
		"icon": "skin_royal",
		"currency": "shards",
		"cost": 16,
		"gold_dark": Color(0.32, 0.14, 0.52),
		"gold_mid": Color(0.76, 0.54, 0.98),
		"gold_shine": Color(1.00, 0.93, 0.65),
		"xp_cyan": Color(1.00, 0.86, 0.32),
		"vortex_abyss": Color(0.08, 0.04, 0.22),
		"vortex_teal": Color(0.40, 0.18, 0.78),
		"vortex_aqua": Color(0.98, 0.82, 0.42),
	},
]

const STREAK_CHEST_STEP: int = 3

var build_channel: String = "release"
var enable_level_skip: bool = false
var build_version: String = "1.0.0"

var current_level: int = 1
var max_unlocked_level: int = 1
var win_streak: int = 0
var streak_chest_progress: int = 0
var coins: int = 150
var skin_shards: int = 2
var unlocked_worlds: int = 1

# Starter free booster inventory (teaches booster value before showing RV ads!)
var inv_magnet: int = 2
var inv_ice: int = 2

# Per-level star ratings ("1" -> 1..3)
var level_stars: Dictionary = {}

# Hole skins
var owned_skins: Array = ["classic"]
var equipped_skin: String = "classic"

# FTUE / contextual tips seen flags
var seen_tutorials: Dictionary = {}

# User audio & haptic preferences
var bgm_enabled: bool = true
var sfx_enabled: bool = true
var haptics_enabled: bool = true

var item_catalog: Dictionary = {}


func _ready() -> void:
	_load_build_config()
	_load_item_catalog()
	if _check_web_reset_query():
		reset_all_progress()
	else:
		load_progress()


func _check_web_reset_query() -> bool:
	if not OS.has_feature("web"):
		return false
	var should_reset = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('reset') === '1'", true)
	if bool(should_reset):
		JavaScriptBridge.eval("try { const u = new URL(window.location.href); u.searchParams.delete('reset'); window.history.replaceState({}, '', u.toString()); } catch(e) {}", true)
		return true
	return false


func reset_all_progress() -> void:
	current_level = 1
	max_unlocked_level = 1
	win_streak = 0
	streak_chest_progress = 0
	coins = 150
	skin_shards = 2
	unlocked_worlds = 1
	inv_magnet = 2
	inv_ice = 2
	level_stars = {}
	owned_skins = ["classic"]
	equipped_skin = "classic"
	seen_tutorials = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	save_progress()
	economy_changed.emit()
	skin_equipped.emit("classic")


func _load_build_config() -> void:
	if FileAccess.file_exists(BUILD_CONFIG_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUILD_CONFIG_PATH))
		if parsed is Dictionary:
			build_channel = str(parsed.get("channel", "release"))
			enable_level_skip = bool(parsed.get("enable_level_skip", false))
			build_version = str(parsed.get("version", "1.0.0"))
	# Allow automated QA screenshot comparison of Release vs Beta builds without editing config
	if OS.get_environment("QA_FORCE_RELEASE") == "1":
		build_channel = "release"
		enable_level_skip = false


func is_beta_build() -> bool:
	return enable_level_skip and build_channel == "beta"


func _load_item_catalog() -> void:
	var path := "res://data/item_catalog.json"
	if not FileAccess.file_exists(path):
		push_warning("Missing item_catalog.json")
		return
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		item_catalog = parsed


func get_item_def(item_id: String) -> Dictionary:
	return item_catalog.get(item_id, {})


func get_skin_def(skin_id: String) -> Dictionary:
	for s in SKIN_CATALOG:
		if str(s["id"]) == skin_id:
			return s
	return SKIN_CATALOG[0]


func is_skin_owned(skin_id: String) -> bool:
	return skin_id in owned_skins


func can_afford_skin(skin_id: String) -> bool:
	if is_skin_owned(skin_id):
		return false
	var s := get_skin_def(skin_id)
	var cur := str(s.get("currency", "coins"))
	var cost := int(s.get("cost", 0))
	if cur == "coins":
		return coins >= cost
	elif cur == "shards":
		return skin_shards >= cost
	return true


func has_affordable_unowned_skin() -> bool:
	for s in SKIN_CATALOG:
		if can_afford_skin(str(s["id"])):
			return true
	return false


func buy_or_equip_skin(skin_id: String) -> bool:
	if is_skin_owned(skin_id):
		equipped_skin = skin_id
		save_progress()
		skin_equipped.emit(skin_id)
		return true
	var s := get_skin_def(skin_id)
	var cur := str(s.get("currency", "coins"))
	var cost := int(s.get("cost", 0))
	if cur == "coins":
		if coins < cost:
			return false
		coins -= cost
	elif cur == "shards":
		if skin_shards < cost:
			return false
		skin_shards -= cost
	owned_skins.append(skin_id)
	equipped_skin = skin_id
	save_progress()
	economy_changed.emit()
	skin_equipped.emit(skin_id)
	return true


func record_level_clear(lv_num: int, stars: int, is_mega: bool) -> Dictionary:
	var key := str(lv_num)
	var prev_stars := int(level_stars.get(key, 0))
	var first_clear := (prev_stars == 0)
	level_stars[key] = maxi(prev_stars, clampi(stars, 1, 3))

	win_streak += 1
	streak_chest_progress += 1

	var coin_reward := (90 if is_mega else 40) + stars * 15 + mini(win_streak * 5, 35)
	if not first_clear:
		coin_reward = int(coin_reward * 0.55)
	var shard_reward := (4 if is_mega else (2 if stars >= 3 else 1)) if first_clear else (1 if stars >= 3 else 0)

	coins += coin_reward
	skin_shards += shard_reward

	var next_lv := mini(50, lv_num + 1)
	if lv_num == 50:
		next_lv = 1
	current_level = next_lv
	max_unlocked_level = maxi(max_unlocked_level, mini(50, lv_num + 1))

	var newly_unlocked_world := 0
	if lv_num == 20 and unlocked_worlds < 2:
		unlocked_worlds = 2
		newly_unlocked_world = 2
	elif lv_num == 30 and unlocked_worlds < 3:
		unlocked_worlds = 3
		newly_unlocked_world = 3
	elif lv_num == 40 and unlocked_worlds < 4:
		unlocked_worlds = 4
		newly_unlocked_world = 4

	save_progress()
	economy_changed.emit()
	return {
		"coins": coin_reward,
		"shards": shard_reward,
		"stars": stars,
		"first_clear": first_clear,
		"new_world": newly_unlocked_world,
		"chest_ready": is_streak_chest_ready(),
	}


func is_streak_chest_ready() -> bool:
	return streak_chest_progress >= STREAK_CHEST_STEP


func claim_streak_chest() -> Dictionary:
	if not is_streak_chest_ready():
		return {}
	streak_chest_progress -= STREAK_CHEST_STEP
	var reward := {"coins": 120, "shards": 3, "magnet": 1, "ice": 1}
	coins += int(reward["coins"])
	skin_shards += int(reward["shards"])
	inv_magnet += int(reward["magnet"])
	inv_ice += int(reward["ice"])
	save_progress()
	economy_changed.emit()
	return reward


func consume_booster(kind: String) -> bool:
	if kind == "magnet" and inv_magnet > 0:
		inv_magnet -= 1
		save_progress()
		economy_changed.emit()
		return true
	if kind == "ice" and inv_ice > 0:
		inv_ice -= 1
		save_progress()
		economy_changed.emit()
		return true
	return false


func get_level_stars(lv_num: int) -> int:
	return int(level_stars.get(str(lv_num), 0))


func get_total_stars() -> int:
	var total := 0
	for k in level_stars:
		total += int(level_stars[k])
	return total


func get_world_stars(world_id: int) -> Vector2i:
	var start_lv := 1
	var end_lv := 20
	match world_id:
		2:
			start_lv = 21
			end_lv = 30
		3:
			start_lv = 31
			end_lv = 40
		4:
			start_lv = 41
			end_lv = 50
	var earned := 0
	for lv in range(start_lv, end_lv + 1):
		earned += get_level_stars(lv)
	return Vector2i(earned, (end_lv - start_lv + 1) * 3)


func is_world_unlocked(world_id: int) -> bool:
	if is_beta_build():
		return true
	return world_id <= unlocked_worlds


func is_level_unlocked(lv_num: int) -> bool:
	if is_beta_build():
		return true
	return lv_num <= max_unlocked_level


func mark_tutorial_seen(key: String) -> void:
	if not bool(seen_tutorials.get(key, false)):
		seen_tutorials[key] = true
		save_progress()


func has_seen_tutorial(key: String) -> bool:
	return bool(seen_tutorials.get(key, false))


func set_bgm_enabled(enabled: bool) -> void:
	bgm_enabled = enabled
	save_progress()
	settings_changed.emit()


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	save_progress()
	settings_changed.emit()


func set_haptics_enabled(enabled: bool) -> void:
	haptics_enabled = enabled
	save_progress()
	settings_changed.emit()


func save_progress() -> void:
	max_unlocked_level = maxi(max_unlocked_level, current_level)
	var data := {
		"save_version": 2,
		"current_level": current_level,
		"max_unlocked_level": max_unlocked_level,
		"win_streak": win_streak,
		"streak_chest_progress": streak_chest_progress,
		"coins": coins,
		"skin_shards": skin_shards,
		"unlocked_worlds": unlocked_worlds,
		"inv_magnet": inv_magnet,
		"inv_ice": inv_ice,
		"level_stars": level_stars,
		"owned_skins": owned_skins,
		"equipped_skin": equipped_skin,
		"seen_tutorials": seen_tutorials,
		"bgm_enabled": bgm_enabled,
		"sfx_enabled": sfx_enabled,
		"haptics_enabled": haptics_enabled,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		current_level = clampi(int(parsed.get("current_level", 1)), 1, 50)
		max_unlocked_level = clampi(int(parsed.get("max_unlocked_level", current_level)), 1, 50)
		win_streak = int(parsed.get("win_streak", 0))
		streak_chest_progress = int(parsed.get("streak_chest_progress", 0))
		coins = int(parsed.get("coins", 150))
		skin_shards = int(parsed.get("skin_shards", 2))
		unlocked_worlds = clampi(int(parsed.get("unlocked_worlds", 1)), 1, 4)
		inv_magnet = int(parsed.get("inv_magnet", 2))
		inv_ice = int(parsed.get("inv_ice", 2))
		var ls = parsed.get("level_stars", {})
		if ls is Dictionary:
			level_stars = ls
		var os = parsed.get("owned_skins", ["classic"])
		if os is Array and os.size() > 0:
			owned_skins = os
		equipped_skin = str(parsed.get("equipped_skin", "classic"))
		if not is_skin_owned(equipped_skin):
			equipped_skin = "classic"
		var st = parsed.get("seen_tutorials", {})
		if st is Dictionary:
			seen_tutorials = st
		bgm_enabled = bool(parsed.get("bgm_enabled", true))
		sfx_enabled = bool(parsed.get("sfx_enabled", true))
		haptics_enabled = bool(parsed.get("haptics_enabled", true))
