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
