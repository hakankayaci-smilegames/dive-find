extends CanvasLayer

@export var slot_scene: PackedScene

@onready var grid_container: GridContainer = $MainPanel/ScrollContainer/GridContainer
@onready var close_button: Button = $MainPanel/CloseButton
@onready var capacity_label: Label = $MainPanel/CapacityLabel
@onready var sort_button: Button = get_node_or_null("MainPanel/SortButton")

@onready var big_image: TextureRect = $MainPanel/DetailPanel/BigItemImage
@onready var name_label: Label = $MainPanel/DetailPanel/NameLabel
@onready var rarity_label: Label = $MainPanel/DetailPanel/RarityLabel
@onready var value_label: Label = $MainPanel/DetailPanel/ValueLabel
@onready var desc_label: Label = $MainPanel/DetailPanel/DescLabel
@onready var drop_button: Button = get_node_or_null("MainPanel/DetailPanel/DropButton")

var _selected_item: Resource = null
var _sort_mode: int = 0  # 0: Değere Göre, 1: Kategoriye Göre

const CATEGORY_COLORS: Dictionary = {
	"Trash": Color(0.70, 0.70, 0.70),
	"Resource": Color(0.35, 0.80, 1.00),
	"Rare Found": Color(0.80, 0.45, 1.00),
	"Valuable": Color(1.00, 0.85, 0.30),
	"Special": Color(1.00, 0.35, 0.50),
	"Crafted": Color(1.00, 0.55, 0.15),
}

const ITEM_SCENE_MAP: Dictionary = {
	"Smooth Criminal Plak": "res://all_items_tscn/MJ_r5.tscn",
	"Şapka (?)": "res://all_items_tscn/adminhat_r3.tscn",
	"Keleşnikof": "res://all_items_tscn/ak47_r5.tscn",
	"Altın Bilezik": "res://all_items_tscn/altin_bilezik_r2.tscn",
	"Altın Kuş Heykeli": "res://all_items_tscn/altin_sandvik_heykeli_r5.tscn",
	"Ananas?": "res://all_items_tscn/ananas_r1.tscn",
	"Ananas Suyu": "res://all_items_tscn/ananas_suyu.tscn",
	"Taş Heykel": "res://all_items_tscn/balbal_r5.tscn",
	"Pet şişe": "res://all_items_tscn/bottle_r0.tscn",
	"Gizemli Şişe": "res://all_items_tscn/bottleofglass_r5.tscn",
	"BMW Anahtarı": "res://all_items_tscn/carkey_bmw_r3.tscn",
	"Mercedes anahtarı": "res://all_items_tscn/carkey_mercedes_r4.tscn",
	"Toyata Anahtarı": "res://all_items_tscn/carkey_toyota_r2.tscn",
	"Bükük Çatal": "res://all_items_tscn/catal_r0.tscn",
	"Charlie Kirk Assasin Planı": "res://all_items_tscn/charlie_r5.tscn",
	"Kanlı Bıçak?": "res://all_items_tscn/dexter_r6.tscn",
	"Isırılmış Kitap": "res://all_items_tscn/eatenbook_r0.tscn",
	"Kamera": "res://all_items_tscn/kamera_r3.tscn",
	"Anahtar": "res://all_items_tscn/key_r3.tscn",
	"Bükük kola": "res://all_items_tscn/kola_r0.tscn",
	"İnci Kolye": "res://all_items_tscn/kolye_r2.tscn",
	"Monster Kutusu": "res://all_items_tscn/monster_r0.tscn",
	"Anahtarlık": "res://all_items_tscn/nahtarlık_r0.tscn",
	"Bronz Anahtarlık": "res://all_items_tscn/nahtarlıkplus_r6.tscn",
	"Kaslı Adam ": "res://all_items_tscn/nigrce_r6.tscn",
	"Bükük pepsi": "res://all_items_tscn/pepsi_r0.tscn",
	"Poşet": "res://all_items_tscn/posey_r0.tscn",
	"Ekonomi Kitabı": "res://all_items_tscn/rte_r2.tscn",
	"Şnolkel": "res://all_items_tscn/snokel_r1.tscn",
	"Güneş Gözlüğü": "res://all_items_tscn/sunglas_r1.tscn",
	"Zoktayın Saç Renginde Boya": "res://all_items_tscn/zoktay_r2.tscn",
	"Kırık Altın Çerçeve": "res://all_items_tres/broken_painting.tscn",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ofis açıp oyunu duraklattığımızda bu panel çalışmaya devam etsin
	close_button.pressed.connect(queue_free)
	if is_instance_valid(sort_button):
		sort_button.pressed.connect(_on_sort_pressed)
	if is_instance_valid(drop_button):
		drop_button.pressed.connect(_on_drop_pressed)
	_clear_details()
	_populate_inventory()
	
	# GlobalInventory'den envanter güncellendiğinde ekranı yenile
	if GlobalInventory.has_signal("inventory_updated"):
		GlobalInventory.inventory_updated.connect(_populate_inventory)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_E, KEY_I, KEY_TAB:
				queue_free()
				get_viewport().set_input_as_handled()

func _clear_details() -> void:
	_selected_item = null
	big_image.texture = null
	name_label.text = "Bir Eşya Seçin"
	rarity_label.text = ""
	value_label.text = ""
	desc_label.text = "Detayları görmek ve bırakmak için bir eşyaya sol tıkla."
	if is_instance_valid(drop_button):
		drop_button.disabled = true
		drop_button.text = "🗑️ Bırak"
		drop_button.tooltip_text = "Önce bir eşya seçmelisin"
	_update_selection_visuals()

func _update_selection_visuals() -> void:
	for child in grid_container.get_children():
		if child is InventorySlot:
			child.set_selected(child.get_item_data() == _selected_item and _selected_item != null)

func _populate_inventory() -> void:
	# Toplam değeri ve kilitli sayısını hesapla
	var total_value: int = 0
	var locked_count: int = 0
	for item in GlobalInventory.collected_items:
		if item:
			total_value += item.value
			if bool(item.get("is_locked")):
				locked_count += 1

	# Kapasite ve toplam değer göstergesini güncelle
	if is_instance_valid(capacity_label):
		var lock_text := (" • 🔒 %d Kilitli" % locked_count) if locked_count > 0 else ""
		capacity_label.text = "Envanter (%d/%d)%s  •  Toplam: %d Zurna" % [
			GlobalInventory.collected_items.size(),
			GlobalInventory.get_capacity(),
			lock_text,
			total_value
		]

	# Önceki slotları temizle
	for child in grid_container.get_children():
		child.queue_free()
		
	# GlobalInventory.collected_items listesindeki her eşya için slot bas
	for item_data in GlobalInventory.collected_items:
		if slot_scene:
			var slot_instance = slot_scene.instantiate() as InventorySlot
			grid_container.add_child(slot_instance)
			slot_instance.setup(item_data)
			slot_instance.slot_clicked.connect(_on_item_selected)
			slot_instance.slot_hovered.connect(_on_item_hovered)
			slot_instance.slot_unhovered.connect(_on_item_unhovered)
			slot_instance.slot_lock_toggled.connect(_on_item_lock_toggled)

	# Seçili eşya hâlâ varsa detayını ve seçim çerçevesini güncelle
	if _selected_item:
		if GlobalInventory.collected_items.has(_selected_item):
			_show_item_details(_selected_item)
			_update_selection_visuals()
		else:
			_clear_details()
	else:
		_clear_details()

func _on_item_hovered(data: Resource) -> void:
	# Hover yapıldığında anında detay panelini önizle
	_show_item_details(data)

func _on_item_unhovered(_data: Resource) -> void:
	# Fare slottan ayrıldığında, seçili eşya varsa detayları ona geri döndür
	if _selected_item and GlobalInventory.collected_items.has(_selected_item):
		_show_item_details(_selected_item)
	elif not _selected_item:
		_clear_details()

func _on_item_selected(data: Resource) -> void:
	_selected_item = data
	_update_selection_visuals()
	_show_item_details(data)

func _on_item_lock_toggled(data: Resource) -> void:
	_populate_inventory()
	if _selected_item == data:
		_show_item_details(data)

func _show_item_details(data: Resource) -> void:
	if not data:
		return
		
	big_image.texture = data.get("sprite")
	var is_locked: bool = bool(data.get("is_locked"))
	var lock_tag: String = " 🔒 [KİLİTLİ]" if is_locked else ""
	name_label.text = str(data.get("item_name")) + lock_tag
	desc_label.text = str(data.get("description"))
	
	if is_locked:
		value_label.text = "Değer: %s Zurna (Korumalı)" % str(data.get("value"))
	else:
		value_label.text = "Değer: %s Zurna" % str(data.get("value"))
	
	var category_key: String = str(data.get("category"))
	var category_text := ""
	match category_key:
		"Trash": category_text = "[ ÇÖP ]"
		"Resource": category_text = "[ HAM MADDE ]"
		"Rare Found": category_text = "[ NADİR BULUNTU ]"
		"Special": category_text = "[ ÖZEL ]"
		"Valuable": category_text = "[ DEĞERLİ ]"
		"Crafted": category_text = "[ ÜRETİLMİŞ ]"
		_: category_text = "[ " + category_key.to_upper() + " ]"
		
	rarity_label.text = category_text
	var cat_color: Color = CATEGORY_COLORS.get(category_key, Color(0.95, 0.9, 0.8))
	rarity_label.add_theme_color_override("font_color", cat_color)

	if is_instance_valid(drop_button):
		var in_office: bool = get_tree().get_first_node_in_group("office_menu") != null
		drop_button.text = "🗑️ Çantadan At" if in_office else "🗑️ Denize Bırak"
		if is_locked:
			drop_button.disabled = true
			drop_button.tooltip_text = "Kilitli eşyalar atılamaz! 🔒"
		else:
			drop_button.disabled = false
			drop_button.tooltip_text = "Eşyayı çantadan sil" if in_office else "Eşyayı denize bırak"

func _on_drop_pressed() -> void:
	if not _selected_item:
		return
	if bool(_selected_item.get("is_locked")):
		GlobalSoundManager.play_sfx("error")
		return

	var item_to_drop: ItemData = _selected_item as ItemData
	if not item_to_drop:
		return

	var in_office: bool = get_tree().get_first_node_in_group("office_menu") != null

	if in_office:
		# Ofisteyken: Çantadan direkt silinir
		GlobalInventory.remove_item(item_to_drop)
		GlobalSoundManager.play_sfx("click")
	else:
		# Dalış anındayken: Oyuncunun olduğu yerde denize fiziksel olarak spawn olur
		var player = get_tree().get_first_node_in_group("player") as Node2D
		GlobalInventory.remove_item(item_to_drop)
		if is_instance_valid(player):
			_spawn_dropped_item_in_world(item_to_drop, player.global_position)
			GlobalSoundManager.play_sfx("pickup")
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_warning_toast"):
				hud.show_warning_toast("🌊 %s denize bırakıldı." % str(item_to_drop.item_name))
		else:
			GlobalSoundManager.play_sfx("click")

	_clear_details()
	_populate_inventory()

func _spawn_dropped_item_in_world(item_data: ItemData, drop_pos: Vector2) -> void:
	var item_name: String = str(item_data.item_name)
	var scene_path: String = ITEM_SCENE_MAP.get(item_name, "")
	if scene_path.is_empty():
		scene_path = ITEM_SCENE_MAP.get(item_data.resource_path, "")

	var scene: PackedScene = null
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		scene = load(scene_path) as PackedScene

	var spawned: Node2D = null
	if scene:
		spawned = scene.instantiate() as Node2D
		spawned.set("item_data", item_data)
	else:
		# Sahnesi olmayan (örn. laboratuvarda üretilmiş) eşyalar için fallback
		var fallback_scene = load("res://all_items_tscn/item_temp.tscn") as PackedScene
		if fallback_scene:
			spawned = fallback_scene.instantiate() as Node2D
			spawned.set("item_data", item_data)
			var spr = spawned.get_node_or_null("Sprite2D") as Sprite2D
			if spr and item_data.sprite:
				spr.texture = item_data.sprite
				var max_dim: float = max(item_data.sprite.get_width(), item_data.sprite.get_height())
				if max_dim > 0.0:
					var norm_scale: float = 220.0 / max_dim
					spr.scale = Vector2(norm_scale, norm_scale)

	if spawned:
		get_tree().current_scene.add_child(spawned)
		spawned.global_position = drop_pos + Vector2(randf_range(-25.0, 25.0), 15.0)

func _on_sort_pressed() -> void:
	if _sort_mode == 0:
		GlobalInventory.sort_inventory_by_value()
		if is_instance_valid(sort_button):
			sort_button.text = "💰 Fiyat"
		_sort_mode = 1
	else:
		GlobalInventory.sort_inventory_by_category()
		if is_instance_valid(sort_button):
			sort_button.text = "🏷️ Tür"
		_sort_mode = 0
	GlobalSoundManager.play_sfx("click")
