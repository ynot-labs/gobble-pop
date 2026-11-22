extends Node

signal rewarded_ad_completed(placement: String, success: bool)
signal interstitial_closed(placement: String)

const FTUE_NO_INTERSTITIAL_MAX_LEVEL: int = 5
const FTUE_NO_INTERSTITIAL_SECONDS: float = 180.0
const INTERSTITIAL_COOLDOWN_SECONDS: float = 105.0

var session_elapsed_sec: float = 0.0
var last_interstitial_time: float = -999.0
var no_forced_ads_purchased: bool = false
var is_ad_playing: bool = false

var _pending_placement: String = ""
var _js_rv_done_cb = null
var _js_inter_done_cb = null


func _ready() -> void:
	if PlatformBridge.is_web:
		_js_rv_done_cb = JavaScriptBridge.create_callback(_on_js_rewarded_callback)
		_js_inter_done_cb = JavaScriptBridge.create_callback(_on_js_interstitial_callback)
		var win = JavaScriptBridge.get_interface("window")
		if win:
			win.gobblePopOnRewardedDone = _js_rv_done_cb
			win.gobblePopOnInterstitialDone = _js_inter_done_cb


func _process(delta: float) -> void:
	session_elapsed_sec += delta


func can_show_interstitial(level_number: int) -> bool:
	if no_forced_ads_purchased or is_ad_playing:
		return false
	if level_number <= FTUE_NO_INTERSTITIAL_MAX_LEVEL:
		return false
	if session_elapsed_sec < FTUE_NO_INTERSTITIAL_SECONDS:
		return false
	return (session_elapsed_sec - last_interstitial_time) >= INTERSTITIAL_COOLDOWN_SECONDS


func show_interstitial(placement: String, level_number: int) -> void:
	if not can_show_interstitial(level_number):
		interstitial_closed.emit(placement)
		return
	is_ad_playing = true
	_pending_placement = placement
	last_interstitial_time = session_elapsed_sec
	AudioManager.set_ad_muted(true)
	PlatformBridge.notify_gameplay_stop()

	if PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("""
			if (window.CrazyGames && CrazyGames.SDK && CrazyGames.SDK.ad) {
				CrazyGames.SDK.ad.requestAd('midgame', {
					adFinished: () => window.gobblePopOnInterstitialDone(true),
					adError: () => window.gobblePopOnInterstitialDone(false)
				});
			} else { window.gobblePopOnInterstitialDone(false); }
		""", true)
		return

	await get_tree().create_timer(0.35).timeout
	_finish_interstitial()


func show_rewarded(placement: String) -> void:
	if is_ad_playing:
		return
	is_ad_playing = true
	_pending_placement = placement
	AudioManager.set_ad_muted(true)
	PlatformBridge.notify_gameplay_stop()

	if PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("""
			if (window.CrazyGames && CrazyGames.SDK && CrazyGames.SDK.ad) {
				CrazyGames.SDK.ad.requestAd('rewarded', {
					adFinished: () => window.gobblePopOnRewardedDone(true),
					adError: () => window.gobblePopOnRewardedDone(false)
				});
			} else { window.gobblePopOnRewardedDone(true); }
		""", true)
		return
	elif PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_YOUTUBE:
		JavaScriptBridge.eval("""
			if (window.ytgame && ytgame.engagement && ytgame.engagement.sendScore) {
				window.gobblePopOnRewardedDone(true);
			} else { window.gobblePopOnRewardedDone(true); }
		""", true)
		return

	# Standalone H5 / local test mock RV (0.45s quick feedback)
	await get_tree().create_timer(0.45).timeout
	_finish_rewarded(true)


func _on_js_rewarded_callback(args: Array) -> void:
	var ok := bool(args[0]) if args.size() > 0 else true
	_finish_rewarded(ok)


func _on_js_interstitial_callback(_args: Array) -> void:
	_finish_interstitial()


func _finish_rewarded(success: bool) -> void:
	is_ad_playing = false
	AudioManager.set_ad_muted(false)
	rewarded_ad_completed.emit(_pending_placement, success)


func _finish_interstitial() -> void:
	is_ad_playing = false
	AudioManager.set_ad_muted(false)
	interstitial_closed.emit(_pending_placement)
