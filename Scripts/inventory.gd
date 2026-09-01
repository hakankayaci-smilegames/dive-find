extends CanvasLayer

@export var slot_scene: PackedScene

@onready var grid_container: GridContainer = $MainPanel/ScrollContainer/GridContainer
@onready var close_button: Button = $MainPanel/CloseButton
@onready var capacity_label: Label = $MainPanel/CapacityLabel

@onready var big_image: TextureRect = $MainPanel/DetailPanel/BigItemImage
@onready var name_label: Label = $MainPanel/DetailPanel/NameLabel
@onready var rarity_label: Label = $MainPanel/DetailPanel/RarityLabel
@onready var value_label: Label = $MainPanel/DetailPanel/ValueLabel
@onready var desc_label: Label = $MainPanel/DetailPanel/DescLabel

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
	big_image.texture = null
	name_label.text = "Bir Eşya Seçin"
	rarity_label.text = ""
	value_label.text = ""
	desc_label.text = ""

func _populate_inventory() -> void:
	# Toplam değeri hesapla
	var total_value: int = 0
	for item in GlobalInventory.collected_items:
		if item:
			total_value += item.value

	# Kapasite ve toplam değer göstergesini güncelle
	if is_instance_valid(capacity_label):
		capacity_label.text = "Envanter (%d/%d)  •  Toplam Değer: %d Zurna" % [
			GlobalInventory.collected_items.size(),
			GlobalInventory.get_capacity(),
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

func _on_item_selected(data: Resource) -> void:
	if not data:
		return
		
	big_image.texture = data.get("sprite")
	name_label.text = str(data.get("item_name"))
	desc_label.text = str(data.get("description"))
	value_label.text = "Değer: " + str(data.get("value")) + " Zurna"
	
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
