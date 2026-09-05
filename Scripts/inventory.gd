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

var _selected_item: Resource = null
var _sort_mode: int = 0  # 0: Değere Göre, 1: Kategoriye Göre

const CATEGORY_COLORS: Dictionary = {
	"Trash": Color(0.70, 0.70, 0.70),
	"Resource": Color(0.35, 0.80, 1.00),
	"Rare Found": Color(0.80, 0.45, 1.00),
	"Valuable": Color(1.00, 0.85, 0.30),
	"Special": Color(1.00, 0.35, 0.50),
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ofis açıp oyunu duraklattığımızda bu panel çalışmaya devam etsin
	close_button.pressed.connect(queue_free)
	if is_instance_valid(sort_button):
		sort_button.pressed.connect(_on_sort_pressed)
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
	desc_label.text = ""

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
			slot_instance.slot_lock_toggled.connect(_on_item_lock_toggled)

	# Seçili eşya hâlâ varsa detayını güncelle
	if _selected_item:
		if GlobalInventory.collected_items.has(_selected_item):
			_show_item_details(_selected_item)
		else:
			_clear_details()

func _on_item_hovered(data: Resource) -> void:
	# Hover yapıldığında anında detay panelini önizle
	_show_item_details(data)

func _on_item_selected(data: Resource) -> void:
	_selected_item = data
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
		_: category_text = "[ " + category_key.to_upper() + " ]"
		
	rarity_label.text = category_text
	var cat_color: Color = CATEGORY_COLORS.get(category_key, Color(0.95, 0.9, 0.8))
	rarity_label.add_theme_color_override("font_color", cat_color)

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
