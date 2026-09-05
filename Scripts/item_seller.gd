extends CanvasLayer

@export var slot_scene: PackedScene              # inventory_slot.tscn (mevcut olan tekrar kullanılıyor)
@export var shop_title: String = "Antikacı"
@export_enum("All", "TrashOnly", "NoTrash", "SpecialOnly", "CraftedOnly") var shop_filter: String = "All"
@export var isOE : bool
@export var only_special: bool = false           # Eski uyumluluk için (shop_filter = SpecialOnly ile aynı)
@export var sell_multiplier: float = 1.0         # İleride Kara Borsa'ya farklı çarpan vermek istersen buradan ayarla
@export var special_multiplier: float = 1.0      # is_special eşyalar için çarpan

@onready var title_label: Label = $MainPanel/TitleLabel
@onready var close_button: Button = $MainPanel/CloseButton
@onready var grid_container: GridContainer = $MainPanel/ScrollContainer/GridContainer

@onready var big_image: TextureRect = $MainPanel/DetailPanel/BigItemImage
@onready var name_label: Label = $MainPanel/DetailPanel/NameLabel
@onready var rarity_label: Label = $MainPanel/DetailPanel/RarityLabel
@onready var value_label: Label = $MainPanel/DetailPanel/ValueLabel
@onready var desc_label: Label = $MainPanel/DetailPanel/DescLabel
@onready var sell_button: Button = $MainPanel/DetailPanel/SellButton
@onready var sell_all_button: Button = $MainPanel/DetailPanel/SellAllButton
@onready var texture_rect: TextureRect = $MainPanel/TextureRect
@onready var title_label_2: Label = $MainPanel/TitleLabel2
var _selected_item: ItemData = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title_label.text = shop_title
	close_button.pressed.connect(queue_free)
	sell_button.pressed.connect(_on_sell_pressed)
	if is_instance_valid(sell_all_button):
		sell_all_button.pressed.connect(_on_sell_all_pressed)

	_setup_button_juice(close_button)
	_setup_button_juice(sell_button)
	if is_instance_valid(sell_all_button):
		_setup_button_juice(sell_all_button)

	# isOE değerine göre resim ve label görünürlüğünü ayarla
	texture_rect.visible = isOE
	title_label_2.visible = isOE

	_clear_details()
	_populate_list()

	GlobalInventory.inventory_updated.connect(_populate_list)


func _exit_tree() -> void:
	if GlobalInventory.inventory_updated.is_connected(_populate_list):
		GlobalInventory.inventory_updated.disconnect(_populate_list)


func _clear_details() -> void:
	_selected_item = null
	big_image.texture = null
	name_label.text = "Bir Eşya Seçin"
	rarity_label.text = ""
	value_label.text = ""
	desc_label.text = ""
	sell_button.disabled = true
	sell_button.text = "SAT"


func _get_filtered_items() -> Array:
	var mode := shop_filter
	if only_special:
		mode = "SpecialOnly"

	if mode == "All":
		return GlobalInventory.collected_items

	var filtered: Array = []
	for item in GlobalInventory.collected_items:
		if not item:
			continue
		var cat: String = str(item.get("category"))
		match mode:
			"TrashOnly":
				if cat == "Trash":
					filtered.append(item)
			"NoTrash":
				if cat != "Trash" and cat != "Special" and cat != "Resource" and cat != "Crafted":
					filtered.append(item)
			"SpecialOnly":
				if cat == "Special":
					filtered.append(item)
			"CraftedOnly":
				if cat == "Crafted":
					filtered.append(item)
			_:
				filtered.append(item)
	return filtered


func _get_sell_price(data: ItemData) -> int:
	var multiplier: float = sell_multiplier

	return int(round(data.value * multiplier))


func _populate_list() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	var items := _get_filtered_items()
	var total_sell_value: int = 0
	var unlocked_count: int = 0

	for item_data in items:
		if slot_scene:
			var slot_instance = slot_scene.instantiate() as InventorySlot
			grid_container.add_child(slot_instance)
			slot_instance.setup(item_data)
			slot_instance.slot_clicked.connect(_on_item_selected)
			slot_instance.slot_hovered.connect(_on_item_hovered)
			slot_instance.slot_lock_toggled.connect(_on_slot_lock_toggled)

		if not bool(item_data.get("is_locked")):
			total_sell_value += _get_sell_price(item_data)
			unlocked_count += 1

	if is_instance_valid(sell_all_button):
		if items.is_empty():
			sell_all_button.disabled = true
			sell_all_button.text = "HEPSİNİ SAT"
		elif unlocked_count == 0:
			sell_all_button.disabled = true
			sell_all_button.text = "TÜMÜ KİLİTLİ 🔒"
		else:
			sell_all_button.disabled = false
			sell_all_button.text = "HEPSİNİ SAT (%d Zurna)" % total_sell_value

	# Seçili eşya listeden çıktıysa (satıldıysa/filtreye artık uymuyorsa) detay panelini temizle
	if _selected_item and not items.has(_selected_item):
		_clear_details()


func _on_item_hovered(data: ItemData) -> void:
	if not data:
		return
	_display_item_details(data)


func _on_slot_lock_toggled(_data: Resource) -> void:
	_populate_list()
	if _selected_item:
		_display_item_details(_selected_item)


func _on_item_selected(data: ItemData) -> void:
	if not data:
		return

	_selected_item = data
	_display_item_details(data)


func _display_item_details(data: ItemData) -> void:
	if not data:
		return

	big_image.texture = data.get("sprite")
	var is_locked: bool = bool(data.get("is_locked"))
	var lock_tag: String = " 🔒 [KİLİTLİ]" if is_locked else ""
	name_label.text = str(data.get("item_name")) + lock_tag
	desc_label.text = str(data.get("description"))

	var sell_price: int = _get_sell_price(data)
	if is_locked:
		value_label.text = "Satış Fiyatı: %d Zurna (Korumalı)" % sell_price
		sell_button.disabled = true
		sell_button.text = "🔒 KİLİTLİ"
	else:
		value_label.text = "Satış Fiyatı: %d Zurna" % sell_price
		sell_button.disabled = false
		sell_button.text = "SAT (%d Zurna)" % sell_price

	var category_text := ""
	match data.get("category"):
		"Trash": category_text = "Kategori: Çöp"
		"Resource": category_text = "Kategori: Ham Madde"
		"Rare Found": category_text = "Kategori: Nadir Buluntu"
		"Special": category_text = "Kategori: Özel"
		"Valuable": category_text = "Kategori: Değerli"
		"Crafted": category_text = "Kategori: Üretilmiş Eşya"
		_: category_text = "Kategori: Bilinmeyen"
	rarity_label.text = category_text


func _on_sell_pressed() -> void:
	if not _selected_item:
		return

	if bool(_selected_item.get("is_locked")):
		GlobalSoundManager.play_sfx("error")
		return

	var sell_price: int = _get_sell_price(_selected_item)

	if GlobalInventory.remove_item(_selected_item):
		GlobalEconomy.add_money(sell_price)
		var time_mgr: Node = _get_time_mgr()
		if time_mgr:
			time_mgr.record_sale(sell_price)
		GlobalSoundManager.play_sfx("sell")
		if is_instance_valid(sell_button):
			_spawn_floating_cash(sell_price, sell_button.global_position + Vector2(sell_button.size.x * 0.5, 0.0))


func _on_sell_all_pressed() -> void:
	var items_to_sell: Array = _get_filtered_items().duplicate()
	if items_to_sell.is_empty():
		return

	var total_income: int = 0
	var sold_any: bool = false
	var time_mgr: Node = _get_time_mgr()

	for item in items_to_sell:
		if bool(item.get("is_locked")):
			continue  # Kilitli eşyayı koru, satma!
		var price: int = _get_sell_price(item)
		total_income += price
		GlobalInventory.remove_item(item)
		sold_any = true
		if time_mgr:
			time_mgr.record_sale(price)

	if sold_any:
		GlobalEconomy.add_money(total_income)
		GlobalSoundManager.play_sfx("sell")
		if is_instance_valid(sell_all_button):
			_spawn_floating_cash(total_income, sell_all_button.global_position + Vector2(sell_all_button.size.x * 0.5, 0.0))
	_clear_details()


func _spawn_floating_cash(diff: int, origin_pos: Vector2) -> void:
	var float_label := Label.new()
	float_label.text = "+%d Zurna" % diff
	float_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	float_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	float_label.add_theme_constant_override("shadow_outline_size", 2)
	float_label.add_theme_font_size_override("font_size", 16)

	float_label.global_position = origin_pos - Vector2(40.0, 20.0)
	add_child(float_label)

	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(float_label, "global_position:y", origin_pos.y - 48.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(float_label, "modulate:a", 0.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(float_label.queue_free)


func _setup_button_juice(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func() -> void:
		if is_instance_valid(btn):
			btn.pivot_offset = btn.size / 2.0
	)
	btn.mouse_entered.connect(func() -> void:
		if is_instance_valid(btn) and not btn.disabled:
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.08)
	)
	btn.mouse_exited.connect(func() -> void:
		if is_instance_valid(btn):
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)
	btn.pressed.connect(func() -> void:
		if is_instance_valid(btn):
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.05)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)


func _on_sell_button_pressed() -> void:
	GlobalSoundManager.play_sfx("sell")


func _get_time_mgr() -> Node:
	return get_node_or_null("/root/GlobalTime")
