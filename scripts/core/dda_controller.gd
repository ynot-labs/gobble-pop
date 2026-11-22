extends Node

## Implements GDD Section 4.4 Dynamic Difficulty Adjustment (DDA)
## - 2 consecutive failures on same level without RV -> 3rd attempt gets +4s timer & sticky slow 2.5s -> 1.5s
## - 5 consecutive first-try wins without RV -> next Hard/Super Hard level -2s timer

var consecutive_fails_on_level: int = 0
var last_failed_level: int = -1
var consecutive_clean_wins: int = 0


func record_level_fail(level_number: int, used_rv: bool) -> void:
	consecutive_clean_wins = 0
	if used_rv:
		return
	if last_failed_level == level_number:
		consecutive_fails_on_level += 1
	else:
		last_failed_level = level_number
		consecutive_fails_on_level = 1


func record_level_win(level_number: int, used_rv: bool, was_first_try: bool) -> void:
	if last_failed_level == level_number:
		consecutive_fails_on_level = 0
		last_failed_level = -1
	if not used_rv and was_first_try:
		consecutive_clean_wins += 1
	else:
		consecutive_clean_wins = 0


func is_pity_active(level_number: int) -> bool:
	return last_failed_level == level_number and consecutive_fails_on_level >= 2


func get_timer_adjustment(level_number: int, difficulty_tag: String) -> float:
	if is_pity_active(level_number):
		return 4.0
	if consecutive_clean_wins >= 5 and (difficulty_tag == "HARD" or difficulty_tag == "SUPER_HARD"):
		return -2.0
	return 0.0


func get_sticky_slow_duration(level_number: int) -> float:
	if is_pity_active(level_number):
		return 1.5
	return 2.5
