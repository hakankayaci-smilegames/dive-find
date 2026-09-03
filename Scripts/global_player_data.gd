extends Node
## GlobalPlayerData (Singleton / Autoload)
## Oyuncunun ekipman seviyelerini, kalıcı istatistiklerini ve gelecekteki Save/Load
## verilerini sahneler arası kesintisiz ve güvenli şekilde saklar.

signal stat_changed(stat_key: String, new_level: int)

# Ekipman Seviyeleri (Kalıcı State)
var tube_level: int = 1        # Oksijen Tüpü (Maks Lvl 8)
var fins_level: int = 0        # Palet (Maks Lvl 6)
var goggles_level: int = 0     # Dalış Gözlüğü (Maks Lvl 5)
var backpack_level: int = 0    # Çanta Kapasitesi (Sınırsız)

# İstatistikler & Gün (Gelecekteki İlerleme & Başarım & Save)
var current_day: int = 1
var total_dives: int = 0
var max_depth_reached_m: float = 0.0


func advance_day() -> int:
	current_day += 1
	stat_changed.emit("current_day", current_day)
	return current_day


func get_stat(stat_key: String) -> int:
	match stat_key:
		"tube_level": return tube_level
		"fins_level": return fins_level
		"goggles_level": return goggles_level
		"backpack_level": return backpack_level
		_: return int(get(stat_key)) if get(stat_key) != null else 0


func set_stat(stat_key: String, new_val: int) -> void:
	match stat_key:
		"tube_level": tube_level = new_val
		"fins_level": fins_level = new_val
		"goggles_level": goggles_level = new_val
		"backpack_level": backpack_level = new_val
		_:
			if get(stat_key) != null:
				set(stat_key, new_val)
	stat_changed.emit(stat_key, new_val)


func upgrade_stat(stat_key: String, max_level: int = -1) -> bool:
	var current: int = get_stat(stat_key)
	if max_level >= 0 and current >= max_level:
		return false
	set_stat(stat_key, current + 1)
	return true


func record_dive(depth_m: float) -> void:
	total_dives += 1
	if depth_m > max_depth_reached_m:
		max_depth_reached_m = depth_m


## ------------------------------------------------------------------
## SAVE / LOAD ALTYAPISI
## ------------------------------------------------------------------
func get_save_dict() -> Dictionary:
	return {
		"tube_level": tube_level,
		"fins_level": fins_level,
		"goggles_level": goggles_level,
		"backpack_level": backpack_level,
		"total_dives": total_dives,
		"max_depth_reached_m": max_depth_reached_m,
	}


func load_from_dict(data: Dictionary) -> void:
	if data.has("tube_level"): tube_level = int(data["tube_level"])
	if data.has("fins_level"): fins_level = int(data["fins_level"])
	if data.has("goggles_level"): goggles_level = int(data["goggles_level"])
	if data.has("backpack_level"): backpack_level = int(data["backpack_level"])
	if data.has("total_dives"): total_dives = int(data["total_dives"])
	if data.has("max_depth_reached_m"): max_depth_reached_m = float(data["max_depth_reached_m"])
	
	stat_changed.emit("all", 0)


func reset_to_defaults() -> void:
	tube_level = 1
	fins_level = 0
	goggles_level = 0
	backpack_level = 0
	total_dives = 0
	max_depth_reached_m = 0.0
	stat_changed.emit("all", 0)
