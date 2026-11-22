extends Node

signal visibility_changed(is_visible: bool)

enum PlatformType { DESKTOP, WEB_STANDALONE, WEB_YOUTUBE, WEB_CRAZYGAMES, MOBILE_IOS, MOBILE_ANDROID }

var current_platform: PlatformType = PlatformType.DESKTOP
var is_web: bool = false
var is_mobile: bool = false


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
	if current_platform == PlatformType.WEB_YOUTUBE:
		JavaScriptBridge.eval("if (window.ytgame && ytgame.game) { ytgame.game.firstFrameReady(); }", true)


func notify_game_ready() -> void:
	if current_platform == PlatformType.WEB_YOUTUBE:
		JavaScriptBridge.eval("if (window.ytgame && ytgame.game) { ytgame.game.gameReady(); }", true)
	elif current_platform == PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("if (window.CrazyGames && CrazyGames.SDK && CrazyGames.SDK.game) { CrazyGames.SDK.game.loadingStop(); }", true)


func notify_gameplay_start() -> void:
	if current_platform == PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("if (window.CrazyGames && CrazyGames.SDK && CrazyGames.SDK.game) { CrazyGames.SDK.game.gameplayStart(); }", true)


func notify_gameplay_stop() -> void:
	if current_platform == PlatformType.WEB_CRAZYGAMES:
		JavaScriptBridge.eval("if (window.CrazyGames && CrazyGames.SDK && CrazyGames.SDK.game) { CrazyGames.SDK.game.gameplayStop(); }", true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		visibility_changed.emit(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		visibility_changed.emit(true)


func trigger_haptic(duration_ms: int = 25) -> void:
	if is_mobile and (not is_instance_valid(GameManager) or GameManager.haptics_enabled):
		Input.vibrate_handheld(duration_ms)
