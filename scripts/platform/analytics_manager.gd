extends Node

## Commercial BI & Funnel Analytics Layer for Gobble Pop!
## Tracks core casual-game retention & monetization funnels:
##   app_open -> ftue_step -> level_start -> level_win / level_fail
##   -> booster_use -> rv_offer / rv_start / rv_complete -> interstitial_show
##   -> skin_unlock / streak_chest_claim / consent_updated
## Strictly respects GDPR/privacy consent and Zero-External-Network compliance
## (only dispatches to host-provided JS hooks if present; never injects external scripts).

signal event_logged(entry: Dictionary)

const LOG_PATH := "user://gobble_pop_analytics.json"
const MAX_RING_EVENTS: int = 120

var player_id: String = ""
var session_id: int = 1
var session_elapsed_sec: float = 0.0
var event_log: Array[Dictionary] = []

# Quick session funnel counters for Beta BI Inspector
var counters: Dictionary = {
	"levels_started": 0,
	"levels_won": 0,
	"levels_failed": 0,
	"rv_offers": 0,
	"rv_completed": 0,
	"rv_failed": 0,
	"interstitials": 0,
	"boosters_inv": 0,
	"boosters_rv": 0,
}


func _ready() -> void:
	_load_analytics_state()
	call_deferred("_emit_app_open")


func _process(delta: float) -> void:
	session_elapsed_sec += delta


func _emit_app_open() -> void:
	track("app_open", {
		"platform": PlatformBridge.get_platform_name(),
		"channel": GameManager.build_channel,
		"version": GameManager.build_version,
		"max_unlocked": GameManager.max_unlocked_level,
		"win_streak": GameManager.win_streak,
		"no_ads": GameManager.no_forced_ads,
	})


func track(event_name: String, params: Dictionary = {}) -> void:
	# Update local session counters regardless of external dispatch
	_update_counters(event_name, params)

	# Respect user GDPR analytics opt-out (always allow consent_updated itself)
	if event_name != "consent_updated" and is_instance_valid(GameManager) and not GameManager.consent_analytics:
		return

	var payload := params.duplicate(true)
	payload["player_id"] = player_id
	payload["session_id"] = session_id
	payload["session_sec"] = snappedf(session_elapsed_sec, 0.1)

	var entry := {
		"ts": int(Time.get_unix_time_from_system()),
		"event": event_name,
		"params": payload,
	}

	event_log.append(entry)
	if event_log.size() > MAX_RING_EVENTS:
		event_log.remove_at(0)

	_dispatch_to_platform_bridge(event_name, payload)
	_save_analytics_state()
	event_logged.emit(entry)


func _update_counters(event_name: String, params: Dictionary) -> void:
	match event_name:
		"level_start":
			counters["levels_started"] = int(counters["levels_started"]) + 1
		"level_win":
			counters["levels_won"] = int(counters["levels_won"]) + 1
		"level_fail":
			counters["levels_failed"] = int(counters["levels_failed"]) + 1
		"rv_offer":
			counters["rv_offers"] = int(counters["rv_offers"]) + 1
		"rv_complete":
			if bool(params.get("success", false)):
				counters["rv_completed"] = int(counters["rv_completed"]) + 1
			else:
				counters["rv_failed"] = int(counters["rv_failed"]) + 1
		"interstitial_show":
			if bool(params.get("shown", false)):
				counters["interstitials"] = int(counters["interstitials"]) + 1
		"booster_use":
			if str(params.get("source", "")) == "inventory":
				counters["boosters_inv"] = int(counters["boosters_inv"]) + 1
			else:
				counters["boosters_rv"] = int(counters["boosters_rv"]) + 1


func _dispatch_to_platform_bridge(event_name: String, payload: Dictionary) -> void:
	if PlatformBridge.is_mobile:
		for s_name in ["GodotFirebase", "Firebase", "GameAnalytics"]:
			if Engine.has_singleton(s_name):
				var s := Engine.get_singleton(s_name)
				if s.has_method("log_event"):
					s.call("log_event", event_name, payload)
				elif s.has_method("addDesignEvent"):
					s.call("addDesignEvent", event_name)
				break
		return
	if not PlatformBridge.is_web:
		return
	# Forward cleanly ONLY to host-provided analytics sinks (Zero external network calls!)
	var safe_name := event_name.replace("'", "")
	var json_str := JSON.stringify(payload).replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("""
		try {
			const data = JSON.parse('%s');
			if (typeof window.gobblePopTrackEvent === 'function') {
				window.gobblePopTrackEvent('%s', data);
			}
			if (typeof window.gtag === 'function') {
				window.gtag('event', '%s', data);
			} else if (Array.isArray(window.dataLayer)) {
				window.dataLayer.push(Object.assign({ event: '%s' }, data));
			}
		} catch (e) {}
	""" % [json_str, safe_name, safe_name, safe_name], true)


func get_recent_events(limit: int = 18) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start_idx := maxi(0, event_log.size() - limit)
	for i in range(event_log.size() - 1, start_idx - 1, -1):
		out.append(event_log[i])
	return out


func clear_log() -> void:
	event_log.clear()
	for k in counters:
		counters[k] = 0
	_save_analytics_state()


func _load_analytics_state() -> void:
	if FileAccess.file_exists(LOG_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(LOG_PATH))
		if parsed is Dictionary:
			player_id = str(parsed.get("player_id", ""))
			session_id = int(parsed.get("session_id", 0)) + 1
			var saved_events = parsed.get("events", [])
			if saved_events is Array:
				for e in saved_events:
					if e is Dictionary:
						event_log.append(e)
	if player_id == "":
		player_id = "gp_%d_%d" % [int(Time.get_unix_time_from_system()), randi_range(1000, 9999)]
		session_id = 1


func _save_analytics_state() -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"player_id": player_id,
			"session_id": session_id,
			"events": event_log,
		}))
