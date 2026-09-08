extends Node2D
class_name ItemSpawner

## ------------------------------------------------------------------
## EXPORT DEĞİŞKENLERİ
## ------------------------------------------------------------------
@export var map_manager: NodePath
@export var spawn_check_interval: float = 1.0
@export var item_pool: Array[PackedScene] = []  # Tüm eşya sahneleri, tek düz liste (kategori/rarity sahne içindeki ItemData'dan okunur)
@export var base_spawn_chance: float = 0.5
@export var global_loot_multiplier: float = 1.0  # Son adımda tüm spawn sayısını etkileyen global çarpan
@export_range(0.001, 0.5, 0.005) var special_item_chance: float = 0.05  # Katman 7'de Özel eşya çıkma oranı (%5 = Ultra Nadir)

@export_group("Geçici Görsel (Fallback) Ayarları")
@export var fallback_item_base_size: float = 64.0
@export var fallback_item_size_increment: float = 16.0

## ------------------------------------------------------------------
## KATMAN (layer_index) -> KATEGORİ EŞLEŞTİRME TABLOSU
## ------------------------------------------------------------------
## layer_index 0 = deniz çizgisi (No Gen). 1..7 = LVL1 (Sığ Sular) .. LVL7 (Abis).
## Bu tablo dışında kalan bir layer_index gelirse (örn. ocean_textures 7'den
## fazla/az olursa) o katmanda spawn YAPILMAZ (aşağıdaki .get(..., []) fallback'i).
const LAYER_CATEGORY_TABLE: Dictionary = {
	1: ["Trash"],
	2: ["Trash", "Resource"],
	3: ["Resource", "Rare Found"],
	4: ["Resource", "Rare Found", "Valuable"],
	5: ["Valuable", "Resource"],
	6: ["Valuable", "Resource"],
	7: ["Valuable", "Resource"],
}

## ------------------------------------------------------------------
## INTERNAL STATE
## ------------------------------------------------------------------
var _check_timer: Timer
var _map_manager_node: Node2D = null

# category (String) -> Array[{"scene": PackedScene, "rarity": float}]
# item_pool bir kez taranıp burada önbelleğe alınır.
var _category_cache: Dictionary = {}

# layer_index (int) -> {"entries": Array[{"scene","rarity"}], "total_weight": float}
# LAYER_CATEGORY_TABLE sabit olduğu için, ilgili kategorilerin birleşimi de
# runtime boyunca değişmez -> her chunk'ta yeniden birleştirmek yerine bir kez hesaplanır.
var _layer_pool_cache: Dictionary = {}

# Gün içinde ziyaret edilen/spawn yapılan chunk indeksleri (aynı gün içi farm sömürüsünü önler)
var _spawned_chunk_indices_today: Dictionary = {}

# Oyuncudan uzaklaşıp silinen chunk'lardaki henüz toplanmamış eşyaların listesi (Item State Retention)
# chunk_x_index (int) -> Array[{"scene": PackedScene, "pos": Vector2}]
var _saved_chunk_items: Dictionary = {}


func _ready() -> void:
	add_to_group("item_spawner")
	_map_manager_node = get_node_or_null(map_manager)
	_connect_map_signals()

	_build_category_cache()
	_build_layer_pool_cache()

	if GlobalTime and GlobalTime.has_signal("day_changed"):
		GlobalTime.day_changed.connect(_on_day_changed)

	_check_timer = Timer.new()
	_check_timer.wait_time = spawn_check_interval
	_check_timer.one_shot = false
	_check_timer.timeout.connect(_on_check_timer_timeout)
	add_child(_check_timer)
	_check_timer.start()


func _connect_map_signals() -> void:
	if not is_instance_valid(_map_manager_node):
		_map_manager_node = get_node_or_null(map_manager)
	if is_instance_valid(_map_manager_node):
		if _map_manager_node.has_signal("chunk_created") and not _map_manager_node.chunk_created.is_connected(_on_chunk_created):
			_map_manager_node.chunk_created.connect(_on_chunk_created)
		if _map_manager_node.has_signal("chunk_destroyed") and not _map_manager_node.chunk_destroyed.is_connected(_on_chunk_destroyed):
			_map_manager_node.chunk_destroyed.connect(_on_chunk_destroyed)
		# Halihazırda sahnede oluşturulmuş chunk varsa hemen eşyalarını üret
		for key in _map_manager_node._active_chunks.keys():
			var c = _map_manager_node._active_chunks[key]
			if is_instance_valid(c) and not c.has_meta("items_spawned"):
				_on_chunk_created(c, int(key))


func _on_day_changed(_new_day: int) -> void:
	# Yeni güne geçildiğinde okyanus akıntıları gelir: Tüm chunk'lar taze eşyalar için sıfırlanır
	_spawned_chunk_indices_today.clear()
	_saved_chunk_items.clear()
	if is_instance_valid(_map_manager_node):
		for key in _map_manager_node._active_chunks.keys():
			var chunk: Node2D = _map_manager_node._active_chunks[key]
			if is_instance_valid(chunk):
				chunk.remove_meta("items_spawned")
				for child in chunk.get_children():
					if child.is_in_group("interactable_items"):
						child.queue_free()
				_on_chunk_created(chunk, int(key))


## ------------------------------------------------------------------
## ÖNBELLEKLEME (bir kez, _ready'de)
## ------------------------------------------------------------------
## item_pool içindeki her PackedScene GEÇİCİ olarak instantiate edilir,
## kökündeki "item_data" (ItemData resource) okunur, category+rarity
## kaydedilir ve geçici node hemen serbest bırakılır. Sahneler spawn
## anında instantiate() EDİLMEZ burada -- sadece veri okunur.
func _build_category_cache() -> void:
	_category_cache.clear()

	for scene in item_pool:
		if scene == null:
			continue

		var temp_node: Node = scene.instantiate()
		var data = temp_node.get("item_data")

		if data == null:
			push_warning("ItemSpawner: '%s' sahnesinde item_data bulunamadı, atlanıyor." % scene.resource_path)
			temp_node.free()
			continue

		var category: String = data.get("category")
		var rarity: float = float(data.get("rarity"))

		if not _category_cache.has(category):
			_category_cache[category] = []
		_category_cache[category].append({"scene": scene, "rarity": rarity})

		temp_node.free()  # Node hiç sahne ağacına eklenmedi, doğrudan serbest bırakmak güvenli


## Her layer_index için LAYER_CATEGORY_TABLE'daki kategorileri _category_cache'ten
## çekip TEK bir birleşik ağırlıklı havuzda toplar (weight = item'ın kendi rarity'si).
func _build_layer_pool_cache() -> void:
	_layer_pool_cache.clear()

	for layer_index in LAYER_CATEGORY_TABLE.keys():
		var categories: Array = LAYER_CATEGORY_TABLE[layer_index]
		var entries: Array = []
		var total_weight: float = 0.0

		for category in categories:
			for entry in _category_cache.get(category, []):
				entries.append(entry)
				total_weight += entry["rarity"]

		_layer_pool_cache[layer_index] = {"entries": entries, "total_weight": total_weight}

	# Katman 7 için bağımsız Özel Eşya ağırlıklı havuzu
	var special_entries: Array = _category_cache.get("Special", [])
	var special_weight: float = 0.0
	for entry in special_entries:
		special_weight += float(entry.get("rarity", 1.0))
	_layer_pool_cache["special"] = {"entries": special_entries, "total_weight": special_weight}


## ------------------------------------------------------------------
## SİNYAL VE CHUNK YAŞAM DÖNGÜSÜ (Zero-Lag + State Retention)
## ------------------------------------------------------------------
func _on_chunk_created(chunk: Node2D, chunk_x_index: int) -> void:
	if not is_instance_valid(chunk):
		return

	# 1. Eğer bu chunk daha önce bugün ziyaret edilmiş ve kalan eşyaları kaydedilmişse:
	# Kalan eşyaları aynı yerlerine anında geri yükle!
	if _saved_chunk_items.has(chunk_x_index):
		var saved_list: Array = _saved_chunk_items[chunk_x_index]
		for item_data in saved_list:
			var scene: PackedScene = item_data.get("scene")
			if scene:
				var item_node: Node2D = scene.instantiate() as Node2D
				if item_node:
					item_node.position = item_data.get("pos", Vector2.ZERO)
					item_node.set_meta("item_scene", scene)
					chunk.add_child(item_node)
		chunk.set_meta("items_spawned", true)
		return

	# 2. Eğer bu chunk bugün ilk defa görülüyorsa: Taze eşyalar üret
	if not _spawned_chunk_indices_today.has(chunk_x_index):
		_spawn_items_for_chunk(chunk)
		_spawned_chunk_indices_today[chunk_x_index] = true
		chunk.set_meta("items_spawned", true)


func _on_chunk_destroyed(chunk: Node2D, chunk_x_index: int) -> void:
	if not is_instance_valid(chunk):
		return

	# Chunk silinmeden önce toplanmamış tüm eşyaları kaydet (Item State Retention)
	var remaining_items: Array[Dictionary] = []
	for child in chunk.get_children():
		if child.is_in_group("interactable_items") and is_instance_valid(child):
			var scene: PackedScene = child.get_meta("item_scene", null)
			if scene == null and child.scene_file_path != "":
				scene = load(child.scene_file_path) as PackedScene
			if scene:
				remaining_items.append({
					"scene": scene,
					"pos": child.position
				})
	_saved_chunk_items[chunk_x_index] = remaining_items


## ------------------------------------------------------------------
## TIMER GÜVENLİK AĞI (Periyodik Kontrol)
## ------------------------------------------------------------------
func _on_check_timer_timeout() -> void:
	if not is_instance_valid(_map_manager_node):
		_map_manager_node = get_node_or_null(map_manager)
		if is_instance_valid(_map_manager_node):
			_connect_map_signals()

	if not is_instance_valid(_map_manager_node):
		return

	# Güvenlik Ağı: Herhangi bir chunk sinyal kaçırdıysa yakala
	var active_keys = _map_manager_node._active_chunks.keys()
	for key in active_keys:
		if not _map_manager_node._active_chunks.has(key):
			continue

		var chunk = _map_manager_node._active_chunks[key]
		if not is_instance_valid(chunk):
			continue

		if chunk.has_meta("items_spawned"):
			continue

		_on_chunk_created(chunk, int(key))


## ------------------------------------------------------------------
## CHUNK İÇİ SPAWN İŞLEMLERİ
## ------------------------------------------------------------------
func _spawn_items_for_chunk(chunk: Node2D) -> void:
	if not chunk.has_meta("layer_bounds"):
		return

	var layers: Array = chunk.get_meta("layer_bounds")
	var chunk_w: float = _map_manager_node.chunk_width

	for layer in layers:
		var layer_index: int = layer.get("layer_index", 0)

		# layer_index 0 = deniz çizgisi -> spawn yok.
		if layer_index == 0:
			continue

		var min_y: float = layer.get("min_y", 0.0)
		var max_y: float = layer.get("max_y", 0.0)

		# Yoğunluk hesabı derinlik tabanlı (rarity sistemiyle ilgisi yok).
		# math_depth 0 = LVL1 (en sığ, en yoğun), arttıkça yoğunluk azalır.
		var math_depth: int = layer_index - 1
		var density_modifier: float = 1.0 / (1.0 + float(math_depth) * 0.25)

		var base_items: float = 60.0 * base_spawn_chance
		var items_to_spawn: int = int(round(base_items * density_modifier))
		items_to_spawn = max(0, items_to_spawn + randi_range(-1, 2))

		# Global çarpan EN SON, kesin sayı bulunduktan sonra uygulanır.
		items_to_spawn = int(float(items_to_spawn) * global_loot_multiplier)

		var pool: Dictionary = _layer_pool_cache.get(layer_index, {})
		var entries: Array = pool.get("entries", [])
		if entries.is_empty():
			continue  # Bu katman için kategoriye uygun hiç eşya tanımlanmamış

		for i in range(items_to_spawn):
			# Katman 7'de (Abis) Ultra Nadir Özel Eşya kontrolü (%5 şans)
			if layer_index == 7 and randf() < special_item_chance:
				_spawn_special_item(chunk, chunk_w, min_y, max_y)
			else:
				_spawn_item(chunk, chunk_w, min_y, max_y, pool)


func _spawn_special_item(chunk: Node2D, chunk_w: float, min_y: float, max_y: float) -> void:
	var special_pool: Dictionary = _layer_pool_cache.get("special", {})
	if not special_pool.get("entries", []).is_empty():
		_spawn_item(chunk, chunk_w, min_y, max_y, special_pool)


## ------------------------------------------------------------------
## AĞIRLIKLI SEÇİM (kategori havuzu içinden, weight = rarity)
## ------------------------------------------------------------------
func _pick_weighted_entry(pool: Dictionary) -> Dictionary:
	var entries: Array = pool["entries"]
	var total_weight: float = pool["total_weight"]

	if total_weight <= 0.0:
		return entries.pick_random()  # Tüm rarity'ler 0 ise eşit şansla seç

	var roll: float = randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for entry in entries:
		cumulative += entry["rarity"]
		if roll <= cumulative:
			return entry

	return entries.back()  # Kayan nokta hassasiyeti için güvenlik ağı


## ------------------------------------------------------------------
## OBJE ÜRETİMİ VE YERLEŞTİRME
## ------------------------------------------------------------------
func _spawn_item(chunk: Node2D, chunk_w: float, min_y: float, max_y: float, pool: Dictionary) -> void:
	var rand_x: float = randf_range(0.0, chunk_w)
	var rand_y: float = randf_range(min_y, max_y)

	var chosen: Dictionary = _pick_weighted_entry(pool)
	var item_node: Node = null

	var scene: PackedScene = chosen.get("scene")
	if scene:
		item_node = scene.instantiate()
	else:
		item_node = _create_fallback_item(chosen.get("rarity", 0.0))

	if item_node:
		item_node.position = Vector2(rand_x, rand_y)
		if scene:
			item_node.set_meta("item_scene", scene)
		chunk.add_child(item_node)  # Chunk pool'a döndüğünde (_reset_pooled_chunk) bu node'lar temizlenir


## ------------------------------------------------------------------
## TEST AMAÇLI GÖRSEL (FALLBACK)
## ------------------------------------------------------------------
func _create_fallback_item(rarity: float) -> Node:
	return null
