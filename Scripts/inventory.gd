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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ofis açıp oyunu duraklattığımızda bu panel çalışmaya devam etsin
	close_button.pressed.connect(queue_free)
	_clear_details()
	_populate_inventory()
	
	# GlobalInventory'den envanter güncellendiğinde ekranı yenile
	if GlobalInventory.has_signal("inventory_updated"):
		GlobalInventory.inventory_updated.connect(_populate_inventory)

func _clear_details() -> void:
	big_image.texture = null
	name_label.text = "Bir Eşya Seçin"
	rarity_label.text = ""
	value_label.text = ""
	desc_label.text = ""

func _populate_inventory() -> void:
	# Kapasite göstergesini güncelle
	if is_instance_valid(capacity_label):
		capacity_label.text = "Envanter (%d/%d)" % [GlobalInventory.collected_items.size(), GlobalInventory.get_capacity()]

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
	name_label.text = data.get("item_name")
	desc_label.text = data.get("description")
	value_label.text = "Değer: " + str(data.get("value")) + " Zurna"
	
	var rarity_text = ""
	match data.get("rarity"):
		0: rarity_text = "Enderlik: Yaygın"
		1: rarity_text = "Enderlik: Nadir"
		2: rarity_text = "Enderlik: Çok Nadir"
		3: rarity_text = "Enderlik: Destansı"
		4: rarity_text = "Enderlik: Efsanevi"
		5: rarity_text = "Enderlik: Mistik"
		_: rarity_text = "Enderlik: Bilinmeyen"
		
	rarity_label.text = rarity_text
