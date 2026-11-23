extends Node

## Unified 3-Platform Bridge (YouTube Playables / CrazyGames SDK v3 / Standalone Web / iOS / Android)
## Handles certification lifecycle hooks, host audio sync, cloud saves, haptics, and Notch Safe Area.

signal visibility_changed(is_visible: bool)
signal host_audio_changed(enabled: bool)
signal cloud_data_loaded(json_str: String)
signal safe_area_changed(margins: Dictionary)

enum PlatformType { DESKTOP, WEB_STANDALONE, WEB_YOUTUBE, WEB_CRAZYGAMES, MOBILE_IOS, MOBILE_ANDROID }

var current_platform: PlatformType = PlatformType.DESKTOP
var is_web: bool = false
var is_mobile: bool = false
var host_audio_enabled: bool = true

var _js_yt_audio_cb = null
var _js_yt_pause_cb = null
var _js_yt_resume_cb = null
var _js_cloud_load_cb = null


func _ready() -> void:
	is_web = OS.has_feature("web")
	is_mobile = OS.has_feature("ios") or OS.has_feature("android")

	if is_web:
		current_platform = _detect_web_platform()
		_setup_web_lifecycle()
	elif OS.has_feature("ios"):
		current_platform = PlatformType.MOBILE_IOS
	elif OS.has_feature("android"):
		current_platform = PlatformType.MOBILE_ANDROID
	else:
		current_platform = PlatformType.DESKTOP

	if get_viewport():
		get_viewport().size_changed.connect(func(): safe_area_changed.emit(get_safe_margins()))


func get_platform_name() -> String:
	match current_platform:
		PlatformType.WEB_YOUTUBE: return "youtube_playables"
		PlatformType.WEB_CRAZYGAMES: return "crazygames"
		PlatformType.WEB_STANDALONE: return "web_standalone"
		PlatformType.MOBILE_IOS: return "ios"
		PlatformType.MOBILE_ANDROID: return "android"
		_: return "desktop"


func _detect_web_platform() -> PlatformType:
	if not is_web:
		return PlatformType.DESKTOP
	var has_yt = JavaScriptBridge.eval("typeof window.ytgame !== 'undefined'", true)
	if has_yt:
		return PlatformType.WEB_YOUTUBE
	var has_cg = JavaScriptBridge.eval("typeof window.CrazyGames !== 'undefined'", true)
	if has_cg:
		return PlatformType.WEB_CRAZYGAMES
	return PlatformType.WEB_STANDALONE


func _setup_web_lifecycle() -> void:
	if not is_web:
		return
	var win = JavaScriptBridge.get_interface("window")
	if win:
		_js_yt_audio_cb = JavaScriptBridge.create_callback(_on_js_host_audio)
		_js_yt_pause_cb = JavaScriptBridge.create_callback(_on_js_host_pause)
		_js_yt_resume_cb = JavaScriptBridge.create_callback(_on_js_host_resume)
		_js_cloud_load_cb = JavaScriptBridge.create_callback(_on_js_cloud_loaded)
		win.gobblePopOnHostAudio = _js_yt_audio_cb
		win.gobblePopOnHostPause = _js_yt_pause_cb
		win.gobblePopOnHostResume = _js_yt_resume_cb
		win.gobblePopOnCloudLoaded = _js_cloud_load_cb

	# Standard Web tab-visibility listener (skipped on YouTube Playables per YT integration rule §6:
	# "Game MUST NOT use the web Page Visibility API and MUST only use Playables SDK onPause and onResume")
	if current_platform != PlatformType.WEB_YOUTUBE:
		JavaScriptBridge.eval("""
			if (!window._gpVisBound) {
				window._gpVisBound = true;
				document.addEventListener('visibilitychange', () => {
					if (document.hidden) {
						if (window.gobblePopOnHostPause) window.gobblePopOnHostPause();
					} else {
						if (window.gobblePopOnHostResume) window.gobblePopOnHostResume();
					}
				});
			}
		""", true)

	if current_platform == PlatformType.WEB_YOUTUBE:
		JavaScriptBridge.eval("""
			try {
				if (window.ytgame && ytgame.game && !window._gpYtFirstFrameSent) {
					window._gpYtFirstFrameSent = true;
					ytgame.game.firstFrameReady();
				}
				if (window.ytgame && ytgame.game && typeof ytgame.game.loadData === 'function' && !window._gpYtLoadPromise) {
					window._gpYtLoadPromise = ytgame.game.loadData().then((data) => {
						window._gpYtLoadCompleted = true;
						if (data && window.gobblePopOnCloudLoaded) window.gobblePopOnCloudLoaded(String(data));
						return data;
					}).catch(() => {
						window._gpYtLoadCompleted = true;
						return '';
					});
				} else {
					window._gpYtLoadPromise = Promise.resolve('');
					window._gpYtLoadCompleted = true;
				}
				if (window.ytgame && ytgame.system) {
					if (typeof ytgame.system.isAudioEnabled === 'function') {
						window.gobblePopOnHostAudio(!!ytgame.system.isAudioEnabled());
					}
					if (typeof ytgame.system.onAudioEnabledChange === 'function') {
						ytgame.system.onAudioEnabledChange((enabled) => {
							if (window.gobblePopOnHostAudio) window.gobblePopOnHostAudio(!!enabled);
						});
					}
					if (typeof ytgame.system.onPause === 'function') {
						ytgame.system.onPause(() => {
							if (window.gobblePopOnHostPause) window.gobblePopOnHostPause();
						});
					}
					if (typeof ytgame.system.onResume === 'function') {
						ytgame.system.onResume(() => {
							if (window.gobblePopOnHostResume) window.gobblePopOnHostResume();
						});
					}
				}
			} catch (e) {}
		""", true)
	elif current_platform == PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("""
			try {
				if (typeof window._gpCgExec !== 'function') {
					window._gpCgExec = function (cb) {
						if (!window.CrazyGames || !window.CrazyGames.SDK) return false;
						if (!window._gpCgInitPromise) {
							const initRes = (typeof window.CrazyGames.SDK.init === 'function')
								? window.CrazyGames.SDK.init()
								: Promise.resolve();
							window._gpCgInitPromise = Promise.resolve(initRes).then(() => {
								window._gpCgReady = true;
								try {
									if (window.CrazyGames.SDK.game && typeof window.CrazyGames.SDK.game.loadingStart === 'function') {
										window.CrazyGames.SDK.game.loadingStart();
									}
								} catch (e) {}
							}).catch(() => {});
						}
						if (window._gpCgReady) {
							cb(window.CrazyGames.SDK);
						} else {
							window._gpCgInitPromise.then(() => { try { cb(window.CrazyGames.SDK); } catch (e) {} });
						}
						return true;
					};
				}
				window._gpCgExec(() => {});
			} catch (e) {}
		""", true)


func notify_game_ready() -> void:
	if current_platform == PlatformType.WEB_YOUTUBE:
		# Per YT Integration §2: Hide splash screen completely BEFORE calling ytgame.game.gameReady()!
		JavaScriptBridge.eval("""
			try {
				const sp = document.getElementById('splash-screen');
				if (sp) { sp.classList.add('hidden'); sp.style.display = 'none'; }
				if (window.ytgame && ytgame.game && !window._gpYtGameReadySent) {
					window._gpYtGameReadySent = true;
					ytgame.game.gameReady();
				}
			} catch(e) {}
		""", true)
	elif current_platform == PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("try { if (window._gpCgExec && !window._gpCgLoadingStopped) { window._gpCgLoadingStopped = true; window._gpCgExec((sdk) => { if (sdk.game && typeof sdk.game.loadingStop === 'function') sdk.game.loadingStop(); }); } } catch(e) {}", true)


func notify_gameplay_start() -> void:
	if current_platform == PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("try { if (window._gpCgExec) { window._gpCgExec((sdk) => { if (sdk.game && typeof sdk.game.gameplayStart === 'function') sdk.game.gameplayStart(); }); } } catch(e) {}", true)


func notify_gameplay_stop() -> void:
	if current_platform == PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("try { if (window._gpCgExec) { window._gpCgExec((sdk) => { if (sdk.game && typeof sdk.game.gameplayStop === 'function') sdk.game.gameplayStop(); }); } } catch(e) {}", true)


func notify_happytime() -> void:
	if current_platform == PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("try { if (window._gpCgExec) { window._gpCgExec((sdk) => { if (sdk.game && typeof sdk.game.happytime === 'function') sdk.game.happytime(); }); } } catch(e) {}", true)


func submit_score(score_val: int) -> void:
	if current_platform == PlatformType.WEB_YOUTUBE:
		JavaScriptBridge.eval("try { if (window.ytgame && ytgame.engagement && ytgame.engagement.sendScore) { ytgame.engagement.sendScore({ value: %d }); } } catch(e) {}" % score_val, true)


func save_cloud_data(json_str: String) -> void:
	if not is_web:
		return
	var escaped := json_str.replace("\\", "\\\\").replace("'", "\\'")
	if current_platform == PlatformType.WEB_YOUTUBE:
		# Per YT Integration §4: Game MUST await loadData before calling saveData!
		JavaScriptBridge.eval("""
			try {
				const doSave = () => {
					if (window.ytgame && ytgame.game && typeof ytgame.game.saveData === 'function') {
						ytgame.game.saveData('%s').catch(() => {});
					}
				};
				if (window._gpYtLoadCompleted) {
					doSave();
				} else if (window._gpYtLoadPromise) {
					window._gpYtLoadPromise.then(doSave).catch(doSave);
				} else {
					doSave();
				}
			} catch(e) {}
		""" % escaped, true)
	elif current_platform == PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("try { if (window._gpCgExec) { window._gpCgExec((sdk) => { if (sdk.data && typeof sdk.data.setItem === 'function') sdk.data.setItem('gobble_pop_save', '%s'); }); } } catch(e) {}" % escaped, true)


func request_cloud_load() -> void:
	if not is_web:
		return
	if current_platform == PlatformType.WEB_YOUTUBE:
		JavaScriptBridge.eval("""
			try {
				if (window._gpYtLoadPromise) {
					window._gpYtLoadPromise.then((data) => {
						if (data && window.gobblePopOnCloudLoaded) window.gobblePopOnCloudLoaded(String(data));
					}).catch(() => {});
				} else if (window.ytgame && ytgame.game && ytgame.game.loadData) {
					window._gpYtLoadPromise = ytgame.game.loadData().then((data) => {
						window._gpYtLoadCompleted = true;
						if (data && window.gobblePopOnCloudLoaded) window.gobblePopOnCloudLoaded(String(data));
						return data;
					}).catch(() => { window._gpYtLoadCompleted = true; return ''; });
				}
			} catch(e) {}
		""", true)
	elif current_platform == PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("""
			try {
				if (window._gpCgExec) {
					window._gpCgExec((sdk) => {
						if (sdk.data && typeof sdk.data.getItem === 'function') {
							const d = sdk.data.getItem('gobble_pop_save');
							if (d && window.gobblePopOnCloudLoaded) window.gobblePopOnCloudLoaded(String(d));
						}
					});
				}
			} catch(e) {}
		""", true)


func get_safe_margins() -> Dictionary:
	# Automated QA override for testing Dynamic Island / notch & Home Indicator layout!
	if OS.get_environment("QA_SIMULATE_NOTCH") == "1":
		return {"top": 108.0, "bottom": 58.0, "left": 0.0, "right": 0.0}

	var vp_size := Vector2(1080.0, 1920.0)
	if get_viewport():
		vp_size = get_viewport().get_visible_rect().size
		if vp_size.x <= 1.0 or vp_size.y <= 1.0:
			vp_size = Vector2(1080.0, 1920.0)

	if is_web:
		var raw = JavaScriptBridge.eval("window.gobblePopGetSafeInsets ? window.gobblePopGetSafeInsets() : ''", true)
		if raw is String and raw != "":
			var parsed = JSON.parse_string(raw)
			if parsed is Dictionary:
				var vh := maxf(float(parsed.get("vh", 1.0)), 1.0)
				var vw := maxf(float(parsed.get("vw", 1.0)), 1.0)
				var scale_y := vp_size.y / vh
				var scale_x := vp_size.x / vw
				return {
					"top": clampf(float(parsed.get("top", 0.0)) * scale_y, 0.0, 180.0),
					"bottom": clampf(float(parsed.get("bottom", 0.0)) * scale_y, 0.0, 140.0),
					"left": clampf(float(parsed.get("left", 0.0)) * scale_x, 0.0, 140.0),
					"right": clampf(float(parsed.get("right", 0.0)) * scale_x, 0.0, 140.0),
				}
		return {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

	if is_mobile:
		var win_sz := DisplayServer.window_get_size()
		if win_sz.x > 0 and win_sz.y > 0:
			var safe := DisplayServer.get_display_safe_area()
			var sx := vp_size.x / float(win_sz.x)
			var sy := vp_size.y / float(win_sz.y)
			return {
				"top": clampf(float(safe.position.y) * sy, 0.0, 180.0),
				"bottom": clampf(float(maxi(0, win_sz.y - safe.end.y)) * sy, 0.0, 140.0),
				"left": clampf(float(safe.position.x) * sx, 0.0, 140.0),
				"right": clampf(float(maxi(0, win_sz.x - safe.end.x)) * sx, 0.0, 140.0),
			}

	return {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}


func _on_js_host_audio(args: Array) -> void:
	var enabled := bool(args[0]) if args.size() > 0 else true
	host_audio_enabled = enabled
	host_audio_changed.emit(enabled)


func _on_js_host_pause(_args: Array) -> void:
	if is_instance_valid(GameManager):
		GameManager.save_progress()
	visibility_changed.emit(false)


func _on_js_host_resume(_args: Array) -> void:
	visibility_changed.emit(true)


func _on_js_cloud_loaded(args: Array) -> void:
	if args.size() > 0 and args[0] is String and String(args[0]) != "":
		cloud_data_loaded.emit(String(args[0]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		visibility_changed.emit(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		visibility_changed.emit(true)


func trigger_haptic(duration_ms: int = 25) -> void:
	if is_mobile and (not is_instance_valid(GameManager) or GameManager.haptics_enabled):
		Input.vibrate_handheld(duration_ms)
