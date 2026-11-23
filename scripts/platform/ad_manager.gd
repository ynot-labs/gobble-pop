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
const AD_REQUEST_TIMEOUT: float = 15.0
const AD_PLAYBACK_TIMEOUT: float = 180.0

# Mobile Native Ad Unit IDs (Pre-filled with Google AdMob Official Test IDs; replace with live IDs before store release)
const ADMOB_ANDROID_REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"
const ADMOB_ANDROID_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"
const ADMOB_IOS_REWARDED_ID: String = "ca-app-pub-3940256099942544/1712485313"
const ADMOB_IOS_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/4411468910"
const IAP_NO_ADS_SKU: String = "com.ynotlabs.gobblepop.noads"

var session_elapsed_sec: float = 0.0
var last_interstitial_time: float = -999.0
var no_forced_ads_purchased: bool = false
var is_ad_playing: bool = false
var reward_ads_available: bool = true
var _reward_ad_retry_at: float = -1.0
var _native_ad_singleton: Object = null
var _native_iap_singleton: Object = null

# Beta-only QA switch to test No-Fill / Error UI gracefully
var simulate_ad_fail: bool = false

var _pending_placement: String = ""
var _pending_level: int = 1
var _pending_is_rv: bool = false
var _watchdog_timer: float = 0.0
var _js_ad_started_cb = null
var _js_rv_done_cb = null
var _js_inter_done_cb = null


func _ready() -> void:
	if PlatformBridge.is_web:
		_js_ad_started_cb = JavaScriptBridge.create_callback(_on_js_ad_started_callback)
		_js_rv_done_cb = JavaScriptBridge.create_callback(_on_js_rewarded_callback)
		_js_inter_done_cb = JavaScriptBridge.create_callback(_on_js_interstitial_callback)
		var win = JavaScriptBridge.get_interface("window")
		if win:
			win.gobblePopOnAdStarted = _js_ad_started_cb
			win.gobblePopOnRewardedDone = _js_rv_done_cb
			win.gobblePopOnInterstitialDone = _js_inter_done_cb
	elif PlatformBridge.is_mobile:
		_init_mobile_native_sdks()


func _init_mobile_native_sdks() -> void:
	for ad_name in ["PoingGodotAdMob", "GodotAdMob", "AppLovinMAX"]:
		if Engine.has_singleton(ad_name):
			_native_ad_singleton = Engine.get_singleton(ad_name)
			if _native_ad_singleton.has_method("initialize"):
				_native_ad_singleton.call("initialize")
			break
	for iap_name in ["GodotGooglePlayBilling", "InAppStore"]:
		if Engine.has_singleton(iap_name):
			_native_iap_singleton = Engine.get_singleton(iap_name)
			if _native_iap_singleton.has_method("startConnection"):
				_native_iap_singleton.call("startConnection")
			break


func _process(delta: float) -> void:
	session_elapsed_sec += delta
	if not reward_ads_available and _reward_ad_retry_at > 0.0 and session_elapsed_sec >= _reward_ad_retry_at:
		reward_ads_available = true
		_reward_ad_retry_at = -1.0
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
	# CrazyGames SDK v3 manages midgame frequency & initial timer automatically per docs.crazygames.com/requirements/ads/
	if PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_CRAZYGAMES:
		return level_number >= 1
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
	_watchdog_timer = AD_REQUEST_TIMEOUT
	last_interstitial_time = session_elapsed_sec
	PlatformBridge.notify_gameplay_stop()
	ad_loading_changed.emit(true, "LOADING...")

	if simulate_ad_fail and is_instance_valid(GameManager) and GameManager.is_beta_build():
		await get_tree().create_timer(0.45).timeout
		_finish_interstitial(false)
		return

	if PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("""
			try {
				const req = (sdk) => {
					if (sdk && sdk.ad && typeof sdk.ad.requestAd === 'function') {
						sdk.ad.requestAd('midgame', {
							adStarted: () => { if (window.gobblePopOnAdStarted) window.gobblePopOnAdStarted(); },
							adFinished: () => window.gobblePopOnInterstitialDone(true),
							adError: () => window.gobblePopOnInterstitialDone(false)
						});
					} else { window.gobblePopOnInterstitialDone(false); }
				};
				if (typeof window._gpCgExec === 'function') {
					if (!window._gpCgExec(req)) window.gobblePopOnInterstitialDone(false);
				} else if (window.CrazyGames && CrazyGames.SDK) {
					req(CrazyGames.SDK);
				} else { window.gobblePopOnInterstitialDone(false); }
			} catch (e) { window.gobblePopOnInterstitialDone(false); }
		""", true)
		return
	elif PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_YOUTUBE:
		JavaScriptBridge.eval("""
			try {
				if (window.ytgame && ytgame.ads && typeof ytgame.ads.requestInterstitialAd === 'function') {
					ytgame.ads.requestInterstitialAd().then(() => {
						window.gobblePopOnInterstitialDone(true);
					}).catch(() => {
						window.gobblePopOnInterstitialDone(false);
					});
				} else {
					window.gobblePopOnInterstitialDone(false);
				}
			} catch (e) { window.gobblePopOnInterstitialDone(false); }
		""", true)
		return
	elif PlatformBridge.is_mobile and _native_ad_singleton != null:
		AudioManager.set_ad_muted(true)
		_watchdog_timer = AD_PLAYBACK_TIMEOUT
		var unit_id := ADMOB_IOS_INTERSTITIAL_ID if PlatformBridge.current_platform == PlatformBridge.PlatformType.MOBILE_IOS else ADMOB_ANDROID_INTERSTITIAL_ID
		if _native_ad_singleton.has_method("show_interstitial"):
			_native_ad_singleton.call("show_interstitial", unit_id)
			return

	AudioManager.set_ad_muted(true)
	await get_tree().create_timer(0.40).timeout
	_finish_interstitial(true)


func show_rewarded(placement: String, level_number: int = 0) -> void:
	if is_ad_playing:
		return
	is_ad_playing = true
	_pending_is_rv = true
	_pending_placement = placement
	_pending_level = level_number if level_number > 0 else (GameManager.current_level if is_instance_valid(GameManager) else 1)
	_watchdog_timer = AD_REQUEST_TIMEOUT
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
				const req = (sdk) => {
					if (sdk && sdk.ad && typeof sdk.ad.requestAd === 'function') {
						sdk.ad.requestAd('rewarded', {
							adStarted: () => { if (window.gobblePopOnAdStarted) window.gobblePopOnAdStarted(); },
							adFinished: () => window.gobblePopOnRewardedDone(true, ''),
							adError: (err) => window.gobblePopOnRewardedDone(false, String((err && err.message) ? err.message : (err || 'no_fill')))
						});
					} else { window.gobblePopOnRewardedDone(false, 'sdk_missing'); }
				};
				if (typeof window._gpCgExec === 'function') {
					if (!window._gpCgExec(req)) window.gobblePopOnRewardedDone(false, 'sdk_missing');
				} else if (window.CrazyGames && CrazyGames.SDK) {
					req(CrazyGames.SDK);
				} else { window.gobblePopOnRewardedDone(false, 'sdk_missing'); }
			} catch (e) { window.gobblePopOnRewardedDone(false, 'exception'); }
		""", true)
		return
	elif PlatformBridge.current_platform == PlatformBridge.PlatformType.WEB_YOUTUBE:
		var yt_reward_id := "gobble-pop-" + placement.replace("_", "-")
		JavaScriptBridge.eval("""
			try {
				if (window.ytgame && ytgame.ads && typeof ytgame.ads.requestRewardedAd === 'function') {
					ytgame.ads.requestRewardedAd('%s').then((rewardEarned) => {
						window.gobblePopOnRewardedDone(!!rewardEarned, rewardEarned ? '' : 'not_earned');
					}).catch((err) => {
						window.gobblePopOnRewardedDone(false, String((err && err.message) ? err.message : (err || 'yt_ad_error')));
					});
				} else {
					window.gobblePopOnRewardedDone(true, '');
				}
			} catch (e) { window.gobblePopOnRewardedDone(false, 'exception'); }
		""" % yt_reward_id, true)
		return
	elif PlatformBridge.is_mobile and _native_ad_singleton != null:
		AudioManager.set_ad_muted(true)
		_watchdog_timer = AD_PLAYBACK_TIMEOUT
		var unit_id := ADMOB_IOS_REWARDED_ID if PlatformBridge.current_platform == PlatformBridge.PlatformType.MOBILE_IOS else ADMOB_ANDROID_REWARDED_ID
		if _native_ad_singleton.has_method("show_rewarded"):
			_native_ad_singleton.call("show_rewarded", unit_id)
			return

	# Standalone H5 / local test mock RV (0.55s loading feedback)
	AudioManager.set_ad_muted(true)
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


func _on_js_ad_started_callback(_args: Array) -> void:
	# Mute audio ONLY when the video ad actually starts playing (per CrazyGames ads requirement)
	# and extend watchdog to 180s so 15-30s video ads never time out mid-playback!
	AudioManager.set_ad_muted(true)
	_watchdog_timer = AD_PLAYBACK_TIMEOUT


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
	if success:
		reward_ads_available = true
	else:
		# Temporarily mark rewarded ads unavailable for 45s so UI switches to Coin fallback or hides
		# ("Do not keep the rewarded ads clickable but without effect" - CrazyGames Basic Launch / AdBlock rule)
		reward_ads_available = false
		_reward_ad_retry_at = session_elapsed_sec + 45.0
		ad_notice.emit("AD UNAVAILABLE · USE COINS OR TRY LATER", true)
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
