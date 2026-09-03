extends Node

var collected_items: Array[ItemData] = []
signal inventory_updated

# Koleksiyon defteri: resource_path -> true. Bir eşya bir kez toplandı mı diye tutar,
# çanta dolup taşsa/eşya satılsa bile burada kalıcı kalır (kayıt dosyasına yazılır).
var discovered_items: Dictionary = {}
signal collection_updated(item: ItemData)  # HUD toast mesajı için hangi eşya keşfedildiğini de taşır

const COLLECTION_SAVE_PATH := "user://collection_save.json"
const ITEM_TRES_DIR := "res://all_items_tres"

# Koleksiyon defterindeki TÜM eşya .tres'lerinin önbelleği. İlk çağrıda diskten
# tarayıp yükler (bu, donmaya sebep olan asıl iş); sonraki her çağrı anında döner.
# loading_screen.gd oyun başında bunu tetikleyerek donmayı yükleme ekranının arkasına saklar.
var _all_items_cache: Array[ItemData] = []
var _items_cached: bool = false

# Player sahnede bulunamazsa (ör. menü/test ortamı) kullanılacak güvenli varsayılan.
# Normal oyun akışında her zaman player_controller.gd'deki gerçek formül kullanılır.
const DEFAULT_CAPACITY: int = 5


func _ready() -> void:
	_load_collection()


func get_all_items() -> Array[ItemData]:
	if _items_cached:
		return _all_items_cache

	_all_items_cache.clear()
	var dir := DirAccess.open(ITEM_TRES_DIR)
	if not dir:
		push_warning("GlobalInventory: '%s' klasörü bulunamadı!" % ITEM_TRES_DIR)
		_items_cached = true
		return _all_items_cache

	var paths: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# ÇÖZÜM: Hem Editördeki (.tres) hem de Export edilmiş oyundaki (.tres.remap) dosyaları kabul et
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				# Eğer .remap uzantısı varsa, bunu silerek orijinal .tres yolunu elde et
				var clean_name = file_name.replace(".remap", "")
				
				# Güvenli klasör yolu birleştirme (Araya / koyarak hataları önlüyoruz)
				var full_path = ITEM_TRES_DIR
				if not full_path.ends_with("/"):
					full_path += "/"
				full_path += clean_name
				
				paths.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()

	for path in paths:
		var res = load(path)
		if res is ItemData:
			_all_items_cache.append(res)

	_items_cached = true
	return _all_items_cache

func get_capacity() -> int:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_backpack_capacity"):
		return player.get_backpack_capacity()
	return DEFAULT_CAPACITY


func is_full() -> bool:
	return collected_items.size() >= get_capacity()


func has_space() -> bool:
	return not is_full()


func add_item(item: ItemData) -> bool:
	if not item:
		return false

	if is_full():
		print(item.item_name + " alınamadı, çanta dolu! (" + str(collected_items.size()) + "/" + str(get_capacity()) + ")")
		return false

	collected_items.append(item)
	_mark_discovered(item)
	emit_signal("inventory_updated")
	print(item.item_name + " çantaya eklendi! Toplam: ", collected_items.size(), "/", get_capacity())
	return true


func _mark_discovered(item: ItemData) -> void:
	if not item or item.resource_path == "":
		return
	if not discovered_items.has(item.resource_path):
		discovered_items[item.resource_path] = true
		_save_collection()
		emit_signal("collection_updated", item)


func reset_collection() -> void:
	discovered_items.clear()
	_save_collection()
	emit_signal("collection_updated", null)


func _save_collection() -> void:
	var file := FileAccess.open(COLLECTION_SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("GlobalInventory: koleksiyon kaydedilemedi (%s)" % COLLECTION_SAVE_PATH)
		return
	file.store_string(JSON.stringify(discovered_items))
	file.close()


func _load_collection() -> void:
	if not FileAccess.file_exists(COLLECTION_SAVE_PATH):
		return
	var file := FileAccess.open(COLLECTION_SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		discovered_items = parsed


func remove_item(item: ItemData) -> bool:
	if item in collected_items:
		collected_items.erase(item)
		emit_signal("inventory_updated")
		return true
	return false


# Oyuncu boğulduğunda (game over) çanta tamamen boşaltılır.
# Koleksiyon defterindeki keşifler (discovered_items) kalıcıdır, silinmez.
func clear_inventory() -> void:
	if collected_items.is_empty():
		return
	collected_items.clear()
	emit_signal("inventory_updated")


# ------------------------------------------------------------------
# OYUN KAYDETME VE YÜKLEME (SAVE / LOAD SİSTEMİ)
# ------------------------------------------------------------------

const GAME_SAVE_PATH := "user://savegame.json"


func has_save() -> bool:
	return FileAccess.file_exists(GAME_SAVE_PATH)


func get_save_data() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(GAME_SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var json_str := file.get_as_text()
	file.close()
	var result = JSON.parse_string(json_str)
	if result is Dictionary:
		return result
	return {}


func get_save_summary() -> String:
	var data := get_save_data()
	if data.is_empty():
		return "Kayıtlı oyun bulunamadı."

	var day: int = int(data.get("current_day", 1))
	var money: int = int(data.get("money", 0))
	var save_time: String = str(data.get("save_time", "Bilinmiyor"))
	var eq: Dictionary = data.get("equipment", {})
	var tube: int = int(eq.get("tube_level", 1))
	var fins: int = int(eq.get("fins_level", 0))
	var goggles: int = int(eq.get("goggles_level", 0))
	var bag: int = int(eq.get("backpack_level", 0))
	var item_count: int = int(data.get("inventory_count", 0))

	return "📅 Gün: %d\n💰 Bakiye: %d Zurna\n🎒 Eşya: %d Adet\n⚙️ Ekipmanlar: Tüp Lvl %d | Palet Lvl %d | Gözlük Lvl %d | Çanta Lvl %d\n🕒 Kayıt: %s" % [
		day, money, item_count, tube, fins, goggles, bag, save_time
	]


func save_game(day: int, money: int, equipment: Dictionary) -> bool:
	var item_paths: Array[String] = []
	for item in collected_items:
		if item and item.resource_path != "":
			item_paths.append(item.resource_path)

	var dt := Time.get_datetime_dict_from_system()
	var time_str := "%02d.%02d.%d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]

	var save_dict: Dictionary = {
		"version": 1,
		"save_time": time_str,
		"current_day": day,
		"money": money,
		"equipment": equipment,
		"inventory_count": item_paths.size(),
		"inventory_paths": item_paths
	}

	var file := FileAccess.open(GAME_SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("GlobalInventory: Kayıt dosyası açılamadı!")
		return false

	file.store_string(JSON.stringify(save_dict, "\t"))
	file.close()
	return true


func apply_save_to_game() -> bool:
	var data := get_save_data()
	if data.is_empty():
		return false

	if data.has("money"):
		GlobalEconomy.money = int(data["money"])
		GlobalEconomy.money_changed.emit(GlobalEconomy.money)

	collected_items.clear()
	if data.has("inventory_paths"):
		var paths: Array = data["inventory_paths"]
		for p in paths:
			if ResourceLoader.exists(str(p)):
				var item_res = load(str(p))
				if item_res is ItemData:
					collected_items.append(item_res)
	emit_signal("inventory_updated")
	return true


func apply_save_to_player(player: Node) -> void:
	if not is_instance_valid(player):
		return
	var data := get_save_data()
	if data.is_empty():
		return
	var eq: Dictionary = data.get("equipment", {})
	if eq.has("tube_level"): player.set("tube_level", int(eq["tube_level"]))
	if eq.has("fins_level"): player.set("fins_level", int(eq["fins_level"]))
	if eq.has("goggles_level"): player.set("goggles_level", int(eq["goggles_level"]))
	if eq.has("backpack_level"): player.set("backpack_level", int(eq["backpack_level"]))


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(GAME_SAVE_PATH)
