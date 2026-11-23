extends Node

## Commercial IAA Ad & IAP Manager (Phase 2)
## Features:
## - Loading state overlay hooks + 8.0s watchdog timeout (zero soft-locks!)
## - Graceful No-Fill / Ad-Blocker / Offline error recovery + toast notice
## - CrazyGames SDK v3 midgame/rewarded + YouTube Playables bonus compliance
## - Remove Forced Ads IAP & Restore Purchases hooks + Beta No-Fill QA simulator
## - Full AnalyticsManager BI funnel instrumentation (rv_offer/rv_start/rv_complete/interstitial_show)

signal rewarded_ad_completed(placement: String, success: bool)
signal interstitial_closed(placement: String)
signal ad_loading_changed(is_loading: bool, message: String)
signal ad_notice(message: String, is_error: bool)
signal no_ads_status_changed(purchased: bool)

const FTUE_NO_INTERSTITIAL_MAX_LEVEL: int = 5
const FTUE_NO_INTERSTITIAL_SECONDS: float = 180.0
const INTERSTITIAL_COOLDOWN_SECONDS: float = 105.0
const AD_WATCHDOG_TIMEOUT: float = 8.0

var session_elapsed_sec: float = 0.0
var last_interstitial_time: float = -999.0
var no_forced_ads_purchased: bool = false
var is_ad_playing: bool = false

# Beta-only QA switch to test No-Fill / Error UI gracefully
var simulate_ad_fail: bool = false

var _pending_placement: String = ""
var _pending_level: int = 1
var _pending_is_rv: bool = false
var _watchdog_timer: float = 0.0
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
	if is_ad_playing and _watchdog_timer > 0.0:
		_watchdog_timer -= delta
		if _watchdog_timer <= 0.0:
			if _pending_is_rv:
				_finish_rewarded(false, "timeout")
			else:
				_finish_interstitial(false)


func note_rv_offer(placement: String, level_number: int) -> void:
	if is_instance_valid(AnalyticsManager):
		AnalyticsManager.track("rv_offer", {"placement": placement, "level": level_number})


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
	_pending_is_rv = false
	_pending_placement = placement
	_pending_level = level_number
	_watchdog_timer = AD_WATCHDOG_TIMEOUT
	last_interstitial_time = session_elapsed_sec
	AudioManager.set_ad_muted(true)
	PlatformBridge.notify_gameplay_stop()
	ad_loading_changed.emit(true, "LOADING...")

	if simulate_ad_fail and is_instance_valid(GameManager) and GameManager.is_beta_build():
		await get_tree().create_timer(0.45).timeout
		_finish_interstitial(false)
		return

	if PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("""
			try {
				if (window.CrazyGames && CrazyGames.SDK && CrazyGames.SDK.ad) {
					CrazyGames.SDK.ad.requestAd('midgame', {
						adFinished: () => window.gobblePopOnInterstitialDone(true),
						adError: () => window.gobblePopOnInterstitialDone(false)
					});
				} else { window.gobblePopOnInterstitialDone(false); }
			} catch (e) { window.gobblePopOnInterstitialDone(false); }
		""", true)
		return
	elif PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_YOUTUBE:
		# YouTube Playables v1 manages monetization natively; skip midgame interstitial cleanly
		_finish_interstitial(false)
		return

	await get_tree().create_timer(0.40).timeout
	_finish_interstitial(true)


func show_rewarded(placement: String, level_number: int = 0) -> void:
	if is_ad_playing:
		return
	is_ad_playing = true
	_pending_is_rv = true
	_pending_placement = placement
	_pending_level = level_number if level_number > 0 else (GameManager.current_level if is_instance_valid(GameManager) else 1)
	_watchdog_timer = AD_WATCHDOG_TIMEOUT
	AudioManager.set_ad_muted(true)
	PlatformBridge.notify_gameplay_stop()
	ad_loading_changed.emit(true, "LOADING AD...")

	if is_instance_valid(AnalyticsManager):
		AnalyticsManager.track("rv_start", {"placement": placement, "level": _pending_level})

	if simulate_ad_fail and is_instance_valid(GameManager) and GameManager.is_beta_build():
		await get_tree().create_timer(0.55).timeout
		_finish_rewarded(false, "simulated_no_fill")
		return

	if PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("""
			try {
				if (window.CrazyGames && CrazyGames.SDK && CrazyGames.SDK.ad) {
					CrazyGames.SDK.ad.requestAd('rewarded', {
						adFinished: () => window.gobblePopOnRewardedDone(true, ''),
						adError: (err) => window.gobblePopOnRewardedDone(false, String(err || 'no_fill'))
					});
				} else { window.gobblePopOnRewardedDone(false, 'sdk_missing'); }
			} catch (e) { window.gobblePopOnRewardedDone(false, 'exception'); }
		""", true)
		return
	elif PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_YOUTUBE:
		# YouTube Playables bonus grant (no third-party ad network allowed in YT Playables)
		await get_tree().create_timer(0.35).timeout
		ad_notice.emit("PLAYABLES BONUS!", false)
		_finish_rewarded(true, "")
		return

	# Standalone H5 / local test mock RV (0.55s loading feedback)
	await get_tree().create_timer(0.55).timeout
	_finish_rewarded(true, "")


func purchase_no_ads() -> void:
	if no_forced_ads_purchased:
		ad_notice.emit("NO ADS ALREADY ACTIVE!", false)
		return
	# Native StoreKit / Google Play Billing hook point (Phase 3); instant sandbox unlock on H5/Beta
	no_forced_ads_purchased = true
	if is_instance_valid(GameManager):
		GameManager.set_no_forced_ads(true)
	if is_instance_valid(AnalyticsManager):
		AnalyticsManager.track("iap_no_ads_purchase", {"platform": PlatformBridge.get_platform_name()})
	no_ads_status_changed.emit(true)
	ad_notice.emit("FORCED ADS REMOVED!", false)


func restore_purchases() -> void:
	if no_forced_ads_purchased:
		ad_notice.emit("PURCHASES RESTORED!", false)
	else:
		ad_notice.emit("NO PRIOR PURCHASES FOUND", false)


func _on_js_rewarded_callback(args: Array) -> void:
	var ok := bool(args[0]) if args.size() > 0 else false
	var reason := str(args[1]) if args.size() > 1 else ("" if ok else "no_fill")
	_finish_rewarded(ok, reason)


func _on_js_interstitial_callback(args: Array) -> void:
	var shown := bool(args[0]) if args.size() > 0 else false
	_finish_interstitial(shown)


func _finish_rewarded(success: bool, error_reason: String = "") -> void:
	if not is_ad_playing:
		return
	is_ad_playing = false
	_watchdog_timer = 0.0
	AudioManager.set_ad_muted(false)
	ad_loading_changed.emit(false, "")
	if is_instance_valid(AnalyticsManager):
		AnalyticsManager.track("rv_complete", {
			"placement": _pending_placement,
			"level": _pending_level,
			"success": success,
			"error": error_reason,
		})
	if not success:
		ad_notice.emit("AD UNAVAILABLE · TRY AGAIN", true)
	rewarded_ad_completed.emit(_pending_placement, success)


func _finish_interstitial(shown: bool = true) -> void:
	if not is_ad_playing:
		return
	is_ad_playing = false
	_watchdog_timer = 0.0
	AudioManager.set_ad_muted(false)
	ad_loading_changed.emit(false, "")
	if is_instance_valid(AnalyticsManager):
		AnalyticsManager.track("interstitial_show", {
			"placement": _pending_placement,
			"level": _pending_level,
			"shown": shown,
		})
	interstitial_closed.emit(_pending_placement)
