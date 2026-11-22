extends Node

const SAVE_PATH := "user://gobble_pop_save.json"

var current_level: int = 1
var win_streak: int = 0
var skin_shards: int = 0
var unlocked_worlds: int = 1
var item_catalog: Dictionary = {}


func _ready() -> void:
	_load_item_catalog()
	load_progress()


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


func save_progress() -> void:
	var data := {
		"current_level": current_level,
		"win_streak": win_streak,
		"skin_shards": skin_shards,
		"unlocked_worlds": unlocked_worlds,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		current_level = int(parsed.get("current_level", 1))
		win_streak = int(parsed.get("win_streak", 0))
		skin_shards = int(parsed.get("skin_shards", 0))
		unlocked_worlds = int(parsed.get("unlocked_worlds", 1))
