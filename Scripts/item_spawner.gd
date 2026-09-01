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
	7: ["Resource", "Special"],
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


func _ready() -> void:
	_map_manager_node = get_node_or_null(map_manager)

	_build_category_cache()
	_build_layer_pool_cache()

	_check_timer = Timer.new()
	_check_timer.wait_time = spawn_check_interval
	_check_timer.one_shot = false
	_check_timer.timeout.connect(_on_check_timer_timeout)
	add_child(_check_timer)
	_check_timer.start()


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


## ------------------------------------------------------------------
## TIMER & CHUNK TARAMA
## ------------------------------------------------------------------
func _on_check_timer_timeout() -> void:
	if not is_instance_valid(_map_manager_node):
		_map_manager_node = get_node_or_null(map_manager)
		if not is_instance_valid(_map_manager_node):
			return

	var active_keys = _map_manager_node._active_chunks.keys()
	for key in active_keys:
		if not _map_manager_node._active_chunks.has(key):
			continue

		var chunk = _map_manager_node._active_chunks[key]
		if not is_instance_valid(chunk):
			continue

		if chunk.has_meta("items_spawned"):
			continue

		_spawn_items_for_chunk(chunk)
		chunk.set_meta("items_spawned", true)


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

		# Yoğunluk hesabı hâlâ derinlik tabanlı (rarity sistemiyle ilgisi yok).
		# math_depth 0 = LVL1 (en sığ, en yoğun), arttıkça yoğunluk azalır.
		var math_depth: int = layer_index - 1
		var density_modifier: float = 1.0 / (1.0 + float(math_depth) * 0.25)

		# NOT: İlk katmanların belirgin şekilde daha yoğun olması istendiği için
		# (rapor: "base_items artırılmalı") çarpanı 40 -> 60 yükselttim; varsayılan
		# base_spawn_chance=0.5 ile LVL1'de ~30 eşya hedefine oturuyor.
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
			_spawn_item(chunk, chunk_w, min_y, max_y, pool)


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
		chunk.add_child(item_node)  # Chunk pool'a döndüğünde (_reset_pooled_chunk) bu node'lar temizlenir


## ------------------------------------------------------------------
## TEST AMAÇLI GÖRSEL (FALLBACK)
## ------------------------------------------------------------------
func _create_fallback_item(rarity: float) -> Node:
	return null
