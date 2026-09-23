extends Node

var collected_items: Array[ItemData] = []
signal inventory_updated
signal equipment_updated(stat_key: String, new_level: int)

# Koleksiyon defteri: resource_path -> true. Bir eşya bir kez toplandı mı diye tutar,
# çanta dolup taşsa/eşya satılsa bile burada kalıcı kalır (kayıt dosyasına yazılır).
var discovered_items: Dictionary = {}
signal collection_updated(item: ItemData)  # HUD toast mesajı için hangi eşya keşfedildiğini de taşır
signal game_saved()

var autosave_on_transition: bool = true
const SETTINGS_FILE := "user://settings.cfg"

var _save_toast_layer: CanvasLayer = null
var _save_toast_panel: PanelContainer = null
var _save_toast_label: Label = null
var _save_toast_tween: Tween = null

const COLLECTION_SAVE_PATH := "user://collection_save.json"
const ITEM_TRES_DIR := "res://all_items_tres"

# Koleksiyon defterindeki TÜM eşya .tres'lerinin önbelleği. İlk çağrıda diskten
# tarayıp yükler (bu, donmaya sebep olan asıl iş); sonraki her çağrı anında döner.
# loading_screen.gd oyun başında bunu tetikleyerek donmayı yükleme ekranının arkasına saklar.
var _all_items_cache: Array[ItemData] = []
var _item_name_to_path: Dictionary = {}
var _items_cached: bool = false
var _collection_save_mutex: Mutex = Mutex.new()

# Kalıcı Ekipman Durumu (Bellek & Save Senkronizasyonu)
var equipment_data: Dictionary = {
	"tube_level": 1,
	"fins_level": 0,
	"goggles_level": 0,
	"backpack_level": 0,
	"flashlight_level": 0,
	"current_battery": -1.0
}

# Player sahnede bulunamazsa (ör. menü/test ortamı) kullanılacak güvenli varsayılan.
# Normal oyun akışında her zaman player_controller.gd'deki gerçek formül kullanılır.
const DEFAULT_CAPACITY: int = 5


func _ready() -> void:
	_load_collection()
	get_all_items()
	_load_equipment_data()
	_load_autosave_setting()
	_setup_save_toast_ui.call_deferred()


func _load_equipment_data() -> void:
	var data := get_save_data()
	if not data.is_empty() and data.has("equipment"):
		var eq: Dictionary = data["equipment"]
		for k in eq.keys():
			equipment_data[k] = eq[k]


func get_equipment_stat(key: String, default_val: int = 0) -> int:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get(key) != null:
		var val = int(player.get(key))
		equipment_data[key] = val
		return val
	return int(equipment_data.get(key, default_val))


func set_equipment_stat(key: String, new_val: int) -> void:
	equipment_data[key] = new_val
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get(key) != null:
		player.set(key, new_val)
	equipment_updated.emit(key, new_val)
	inventory_updated.emit()


func get_all_items(force_reload: bool = false) -> Array[ItemData]:
	if _items_cached and not force_reload:
		return _all_items_cache

	_all_items_cache.clear()
	_item_name_to_path.clear()
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
			if res.item_name != "":
				_item_name_to_path[res.item_name] = res.resource_path

	_items_cached = true
	return _all_items_cache

func get_capacity() -> int:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_backpack_capacity"):
		return player.get_backpack_capacity()
	var bag_lvl: int = int(equipment_data.get("backpack_level", 0))
	return DEFAULT_CAPACITY + bag_lvl * 5


func is_full() -> bool:
	return collected_items.size() >= get_capacity()


func has_space() -> bool:
	return not is_full()


func get_item_path(item: ItemData) -> String:
	if not item:
		return ""
	if item.source_path != "":
		return item.source_path
	if item.resource_path != "":
		return item.resource_path
	if _item_name_to_path.has(item.item_name):
		return _item_name_to_path[item.item_name]
	for cached_item in get_all_items():
		if cached_item and cached_item.item_name == item.item_name and cached_item.resource_path != "":
			return cached_item.resource_path
	return ""


func add_item(item: ItemData) -> bool:
	if not item:
		return false

	if is_full():
		print(item.item_name + " alınamadı, çanta dolu! (" + str(collected_items.size()) + "/" + str(get_capacity()) + ")")
		return false

	var item_instance: ItemData = item.duplicate() as ItemData
	item_instance.source_path = item.source_path if item.source_path != "" else item.resource_path
	collected_items.append(item_instance)
	_mark_discovered(item_instance)
	emit_signal("inventory_updated")
	print(item_instance.item_name + " çantaya eklendi! Toplam: ", collected_items.size(), "/", get_capacity())
	return true


func _mark_discovered(item: ItemData) -> void:
	if not item:
		return
	var path: String = get_item_path(item)
	if path == "":
		return
	if item.source_path == "":
		item.source_path = path
	if not discovered_items.has(path):
		discovered_items[path] = true
		_save_collection()
		emit_signal("collection_updated", item)


func is_item_discovered(item: Resource) -> bool:
	if not item:
		return false
	var path: String = ""
	if item is ItemData:
		path = get_item_path(item as ItemData)
	else:
		path = item.resource_path
	if path != "" and discovered_items.has(path):
		return true
	var item_name_val = item.get("item_name")
	if item_name_val != null and str(item_name_val) != "":
		var target_name: String = str(item_name_val)
		if _item_name_to_path.has(target_name):
			var mapped_path: String = _item_name_to_path[target_name]
			if mapped_path != "" and discovered_items.has(mapped_path):
				return true
		else:
			for cached_item in get_all_items():
				if cached_item and cached_item.item_name == target_name:
					if cached_item.resource_path != "" and discovered_items.has(cached_item.resource_path):
						return true
					break
	return false


func reset_collection() -> void:
	discovered_items.clear()
	_save_collection()
	emit_signal("collection_updated", null)


func unlock_all_collection() -> int:
	var items: Array[ItemData] = get_all_items()
	var new_unlocked: int = 0
	for item in items:
		if item and item.resource_path != "":
			if not discovered_items.has(item.resource_path):
				new_unlocked += 1
			discovered_items[item.resource_path] = true
	_save_collection()
	emit_signal("collection_updated", null)
	return new_unlocked


func _save_collection() -> void:
	var json_data: String = JSON.stringify(discovered_items)
	WorkerThreadPool.add_task(func() -> void:
		_collection_save_mutex.lock()
		var file := FileAccess.open(COLLECTION_SAVE_PATH, FileAccess.WRITE)
		if not file:
			push_warning("GlobalInventory: koleksiyon kaydedilemedi (%s)" % COLLECTION_SAVE_PATH)
			_collection_save_mutex.unlock()
			return
		file.store_string(json_data)
		file.close()
		_collection_save_mutex.unlock()
	)


func _load_collection() -> void:
	if not FileAccess.file_exists(COLLECTION_SAVE_PATH):
		return
	_collection_save_mutex.lock()
	var file := FileAccess.open(COLLECTION_SAVE_PATH, FileAccess.READ)
	if not file:
		_collection_save_mutex.unlock()
		return
	var text := file.get_as_text()
	file.close()
	_collection_save_mutex.unlock()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		discovered_items = parsed


func remove_item(item: ItemData) -> bool:
	if item in collected_items:
		collected_items.erase(item)
		emit_signal("inventory_updated")
		return true
	return false


func remove_items_bulk(items: Array) -> int:
	if items.is_empty():
		return 0
	var removed_count: int = 0
	for item in items:
		if item in collected_items:
			collected_items.erase(item)
			removed_count += 1
	if removed_count > 0:
		emit_signal("inventory_updated")
	return removed_count


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
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if data.is_empty():
		return "No saved game found." if is_en else "Kayıtlı oyun bulunamadı."

	var day: int = int(data.get("current_day", 1))
	var hour: int = int(data.get("current_hour", 10))
	var minute: int = int(data.get("current_minute", 0))
	var money: int = int(data.get("money", 0))
	var save_time: String = str(data.get("save_time", "Unknown" if is_en else "Bilinmiyor"))
	var eq: Dictionary = data.get("equipment", {})
	var tube: int = int(eq.get("tube_level", 1))
	var fins: int = int(eq.get("fins_level", 0))
	var goggles: int = int(eq.get("goggles_level", 0))
	var bag: int = int(eq.get("backpack_level", 0))
	var flash: int = int(eq.get("flashlight_level", 0))
	var item_count: int = int(data.get("inventory_count", 0))

	var flash_str: String = ""
	if flash > 0:
		flash_str = (" | Light Lvl %d" if is_en else " | Fener Lvl %d") % flash

	if is_en:
		return "📅 Day: %d  |  ⏰ Time: %02d:%02d\n💰 Balance: %d Zurna\n🎒 Items: %d Qty\n⚙️ Equipment: Tank Lvl %d | Fins Lvl %d | Mask Lvl %d | Bag Lvl %d%s\n🕒 Saved: %s" % [
			day, hour, minute, money, item_count, tube, fins, goggles, bag, flash_str, save_time
		]
	else:
		return "📅 Gün: %d  |  ⏰ Saat: %02d:%02d\n💰 Bakiye: %d Zurna\n🎒 Eşya: %d Adet\n⚙️ Ekipmanlar: Tüp Lvl %d | Palet Lvl %d | Gözlük Lvl %d | Çanta Lvl %d%s\n🕒 Kayıt: %s" % [
			day, hour, minute, money, item_count, tube, fins, goggles, bag, flash_str, save_time
		]


func save_game(day: int, money: int, equipment: Dictionary) -> bool:
	var item_paths: Array[String] = []
	var item_locks: Array[bool] = []
	for item in collected_items:
		if item:
			var p := get_item_path(item)
			if p != "":
				item_paths.append(p)
				item_locks.append(bool(item.get("is_locked")))

	var dt := Time.get_datetime_dict_from_system()
	var time_str := "%02d.%02d.%d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]

	var time_mgr: Node = _get_time_mgr()
	var save_dict: Dictionary = {
		"version": 1,
		"save_time": time_str,
		"current_day": day,
		"current_hour": int(time_mgr.get("current_hour")) if time_mgr else 10,
		"current_minute": int(time_mgr.get("current_minute")) if time_mgr else 0,
		"money": money,
		"equipment": equipment,
		"inventory_count": item_paths.size(),
		"inventory_paths": item_paths,
		"inventory_locked": item_locks
	}

	var file := FileAccess.open(GAME_SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("GlobalInventory: Kayıt dosyası açılamadı!")
		return false

	file.store_string(JSON.stringify(save_dict, "\t"))
	file.close()
	game_saved.emit()
	_show_save_toast()
	return true


func _load_autosave_setting() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		autosave_on_transition = bool(cfg.get_value("general", "autosave_enabled", cfg.get_value("general", "autosave_on_transition", true)))


func is_autosave_enabled() -> bool:
	return autosave_on_transition


func set_autosave_enabled(enabled: bool) -> void:
	autosave_on_transition = enabled


func get_current_equipment_dict() -> Dictionary:
	var player: Node = null
	var tree := get_tree()
	if tree:
		player = tree.get_first_node_in_group("player")

	var cur_battery: float = -1.0
	if player and player.get("current_battery") != null:
		cur_battery = float(player.get("current_battery"))
	else:
		cur_battery = float(equipment_data.get("current_battery", -1.0))

	return {
		"backpack_level": get_equipment_stat("backpack_level", 0),
		"tube_level": get_equipment_stat("tube_level", 1),
		"goggles_level": get_equipment_stat("goggles_level", 0),
		"fins_level": get_equipment_stat("fins_level", 0),
		"flashlight_level": get_equipment_stat("flashlight_level", 0),
		"current_battery": cur_battery
	}


func auto_save_game() -> bool:
	if not autosave_on_transition:
		return false

	var time_mgr: Node = _get_time_mgr()
	var save_day: int = int(time_mgr.get("current_day")) if time_mgr else 1
	if save_day <= 0:
		var prev_data := get_save_data()
		save_day = int(prev_data.get("current_day", 1))

	var eco: Node = get_node_or_null("/root/GlobalEconomy")
	var money: int = int(eco.get("money")) if eco else 0

	return save_game(save_day, money, get_current_equipment_dict())


func _setup_save_toast_ui() -> void:
	if _save_toast_layer != null:
		return

	_save_toast_layer = CanvasLayer.new()
	_save_toast_layer.layer = 160
	_save_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	_save_toast_panel = PanelContainer.new()
	_save_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_toast_panel.anchors_preset = Control.PRESET_TOP_WIDE
	_save_toast_panel.anchor_left = 0.5
	_save_toast_panel.anchor_right = 0.5
	_save_toast_panel.anchor_top = 0.0
	_save_toast_panel.anchor_bottom = 0.0
	_save_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_save_toast_panel.offset_top = 24.0
	_save_toast_panel.offset_bottom = 60.0
	_save_toast_panel.offset_left = -160.0
	_save_toast_panel.offset_right = 160.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.12, 0.2, 0.92)
	style.border_color = Color(0.0, 0.85, 0.95, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.shadow_color = Color(0.0, 0.8, 1.0, 0.25)
	style.shadow_size = 8
	_save_toast_panel.add_theme_stylebox_override("panel", style)

	_save_toast_label = Label.new()
	_save_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_toast_label.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0, 1.0))
	_save_toast_label.add_theme_font_size_override("font_size", 16)

	_save_toast_panel.add_child(_save_toast_label)
	_save_toast_panel.modulate.a = 0.0
	_save_toast_panel.visible = false
	_save_toast_layer.add_child(_save_toast_panel)
	add_child(_save_toast_layer)


func _show_save_toast() -> void:
	if _save_toast_layer == null:
		_setup_save_toast_ui()
	if not is_instance_valid(_save_toast_panel) or not is_instance_valid(_save_toast_label):
		return

	var is_en: bool = TranslationServer.get_locale().begins_with("en")
	_save_toast_label.text = "💾 Game Saved" if is_en else "💾 Oyun Kaydedildi"
	_save_toast_panel.visible = true

	if _save_toast_tween and _save_toast_tween.is_valid():
		_save_toast_tween.kill()

	_save_toast_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_save_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_save_toast_tween.tween_property(_save_toast_panel, "modulate:a", 1.0, 0.2)
	_save_toast_tween.tween_interval(2.0)
	_save_toast_tween.tween_property(_save_toast_panel, "modulate:a", 0.0, 0.4)
	_save_toast_tween.tween_callback(func() -> void:
		if is_instance_valid(_save_toast_panel):
			_save_toast_panel.visible = false
	)


func apply_save_to_game() -> bool:
	_load_equipment_data()
	var data := get_save_data()
	if data.is_empty():
		return false

	var time_mgr: Node = _get_time_mgr()
	if data.has("current_day") and time_mgr:
		if time_mgr.has_method("set_day"):
			time_mgr.set_day(int(data["current_day"]))
		else:
			time_mgr.set("current_day", int(data["current_day"]))
		var h: int = int(data.get("current_hour", 10))
		var m: int = int(data.get("current_minute", 0))
		time_mgr.set_time(h, m)

	if data.has("money"):
		GlobalEconomy.money = int(data["money"])
		GlobalEconomy.money_changed.emit(GlobalEconomy.money)

	collected_items.clear()
	if data.has("inventory_paths"):
		var paths: Array = data["inventory_paths"]
		var locked_flags: Array = data.get("inventory_locked", [])
		for i in range(paths.size()):
			var p = paths[i]
			if ResourceLoader.exists(str(p)):
				var item_res = load(str(p))
				if item_res is ItemData:
					var item_inst = item_res.duplicate() as ItemData
					item_inst.source_path = str(p)
					if i < locked_flags.size():
						item_inst.is_locked = bool(locked_flags[i])
					collected_items.append(item_inst)
					_mark_discovered(item_inst)
	emit_signal("inventory_updated")
	return true


func sort_inventory_by_value() -> void:
	collected_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.value != b.value:
			return a.value > b.value
		return a.rarity > b.rarity
	)
	emit_signal("inventory_updated")


func sort_inventory_by_category() -> void:
	const ORDER = {"Special": 0, "Valuable": 1, "Rare Found": 2, "Resource": 3, "Trash": 4}
	collected_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		var oa: int = int(ORDER.get(a.category, 99))
		var ob: int = int(ORDER.get(b.category, 99))
		if oa != ob:
			return oa < ob
		return a.value > b.value
	)
	emit_signal("inventory_updated")


func reset_equipment_data() -> void:
	equipment_data = {
		"tube_level": 1,
		"fins_level": 0,
		"goggles_level": 0,
		"backpack_level": 0,
		"flashlight_level": 0,
		"current_battery": -1.0
	}
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player:
		player.set("tube_level", 1)
		player.set("fins_level", 0)
		player.set("goggles_level", 0)
		player.set("backpack_level", 0)
		player.set("flashlight_level", 0)
		player.set("current_battery", 60.0)
		if player.has_method("_broadcast_battery"):
			player.call("_broadcast_battery")

	for k in equipment_data.keys():
		equipment_updated.emit(k, int(equipment_data[k]) if k != "current_battery" else 0)
	inventory_updated.emit()


func apply_save_to_player(player: Node) -> void:
	if not is_instance_valid(player):
		return
	_load_equipment_data()
	var data := get_save_data()
	var eq: Dictionary = data.get("equipment", equipment_data) if not data.is_empty() else equipment_data
	for k in eq.keys():
		equipment_data[k] = eq[k]

	player.set("tube_level", int(eq.get("tube_level", 1)))
	player.set("fins_level", int(eq.get("fins_level", 0)))
	player.set("goggles_level", int(eq.get("goggles_level", 0)))
	player.set("backpack_level", int(eq.get("backpack_level", 0)))
	player.set("flashlight_level", int(eq.get("flashlight_level", 0)))

	var flash_lvl: int = int(eq.get("flashlight_level", 0))
	var default_bat: float = 75.0 + float(max(0, flash_lvl - 1)) * 8.93 if flash_lvl > 0 else 60.0
	if player.has_method("get_flashlight_max_battery"):
		default_bat = player.get_flashlight_max_battery()

	if eq.has("current_battery") and float(eq["current_battery"]) >= 0.0:
		player.set("current_battery", float(eq["current_battery"]))
	else:
		player.set("current_battery", default_bat)

	if player.has_method("_broadcast_battery"):
		player.call("_broadcast_battery")


func start_new_game() -> void:
	delete_save()
	clear_inventory()
	reset_equipment_data()
	GlobalEconomy.money = 0
	GlobalEconomy.money_changed.emit(0)
	var time_mgr: Node = _get_time_mgr()
	if time_mgr and time_mgr.has_method("reset_to_new_game"):
		time_mgr.reset_to_new_game()
	save_game(1, 0, get_current_equipment_dict())


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(GAME_SAVE_PATH)


func _get_time_mgr() -> Node:
	return get_node_or_null("/root/GlobalTime")
