extends Node

## GlobalTime (Zaman ve Gün Döngüsü Yöneticisi)
## Okyanustayken zaman akar (her 30 saniyede bir +15 dakika).
## 10:00'da başlar, 19:00'da mesai biter ve yeni dalışlar kilitlenir.

signal time_changed(hour: int, minute: int)
signal day_changed(new_day: int)
signal dive_lock_changed(is_locked: bool)
signal day_summary_requested(summary_dict: Dictionary)

const START_HOUR: int = 10
const START_MINUTE: int = 0
const CUTOFF_HOUR: int = 19
const CUTOFF_MINUTE: int = 0

const MINUTE_STEP: int = 15       # Her dilimde 15 dakika artar
const STEP_INTERVAL_SEC: float = 20.0 # Her 20 saniyede bir (toplam mesai ~12 dakika, 10-15 dk aralığı)

var current_day: int = 1
var current_hour: int = START_HOUR
var current_minute: int = START_MINUTE

var time_speed_multiplier: float = 1.0
var is_clock_running: bool = true
var _step_accumulator: float = 0.0

# Günlük İstatistikler (Bilanço & Özet için)
var daily_earnings: int = 0
var daily_dives: int = 0
var daily_items_sold: int = 0
var daily_max_depth_m: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_clock_running = true


func _process(delta: float) -> void:
	if not is_clock_running:
		return

	if time_speed_multiplier <= 0.0:
		return

	_step_accumulator += delta * time_speed_multiplier
	if _step_accumulator >= STEP_INTERVAL_SEC:
		_step_accumulator -= STEP_INTERVAL_SEC
		advance_minutes(MINUTE_STEP)


func start_clock() -> void:
	is_clock_running = true


func pause_clock() -> void:
	is_clock_running = false


func advance_minutes(minutes_to_add: int) -> void:
	var total_min = current_hour * 60 + current_minute + minutes_to_add
	current_hour = (total_min / 60) % 24
	current_minute = (total_min % 60) - (total_min % MINUTE_STEP)
	time_changed.emit(current_hour, current_minute)

	# 19:00 kontrolü
	var is_locked = not is_dive_allowed()
	dive_lock_changed.emit(is_locked)


func is_dive_allowed() -> bool:
	var current_total = current_hour * 60 + current_minute
	var cutoff_total = CUTOFF_HOUR * 60 + CUTOFF_MINUTE
	return current_total < cutoff_total


func get_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]


func set_time(hour: int, minute: int = 0) -> void:
	current_hour = clamp(hour, 0, 23)
	current_minute = clamp(minute - (minute % MINUTE_STEP), 0, 59)
	time_changed.emit(current_hour, current_minute)
	dive_lock_changed.emit(not is_dive_allowed())


# ------------------------------------------------------------------
# GÜNLÜK İSTATİSTİK KAYITLARI
# ------------------------------------------------------------------

func record_dive() -> void:
	daily_dives += 1


func record_depth(depth_m: float) -> void:
	if depth_m > daily_max_depth_m:
		daily_max_depth_m = depth_m


func record_sale(amount: int) -> void:
	daily_earnings += amount
	daily_items_sold += 1


func get_summary_data() -> Dictionary:
	return {
		"day": current_day,
		"earnings": daily_earnings,
		"dives": daily_dives,
		"items_sold": daily_items_sold,
		"max_depth": daily_max_depth_m,
		"closing_time": get_time_string()
	}


# ------------------------------------------------------------------
# GÜN İLERLETME & SIFIRLAMA
# ------------------------------------------------------------------

func start_new_day() -> void:
	current_day += 1
	current_hour = START_HOUR
	current_minute = START_MINUTE
	_step_accumulator = 0.0

	# Günlük istatistikleri sıfırla
	daily_earnings = 0
	daily_dives = 0
	daily_items_sold = 0
	daily_max_depth_m = 0.0

	day_changed.emit(current_day)
	time_changed.emit(current_hour, current_minute)
	dive_lock_changed.emit(false)
