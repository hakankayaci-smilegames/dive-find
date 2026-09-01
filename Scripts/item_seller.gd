extends CanvasLayer

@export var slot_scene: PackedScene              # inventory_slot.tscn (mevcut olan tekrar kullanılıyor)
@export var shop_title: String = "Antikacı"
@export var isOE : bool
@export var only_special: bool = false           # Kara Borsa: true -> sadece is_special == true eşyalar listelenir
@export var sell_multiplier: float = 1.0         # İleride Kara Borsa'ya farklı çarpan vermek istersen buradan ayarla
@export var special_multiplier: float = 1.0      # is_special eşyalar için çarpan (Antikacı: 0.25, Kara Borsa: 1.5)

@onready var title_label: Label = $MainPanel/TitleLabel
@onready var close_button: Button = $MainPanel/CloseButton
@onready var grid_container: GridContainer = $MainPanel/ScrollContainer/GridContainer

@onready var big_image: TextureRect = $MainPanel/DetailPanel/BigItemImage
@onready var name_label: Label = $MainPanel/DetailPanel/NameLabel
@onready var rarity_label: Label = $MainPanel/DetailPanel/RarityLabel
@onready var value_label: Label = $MainPanel/DetailPanel/ValueLabel
@onready var desc_label: Label = $MainPanel/DetailPanel/DescLabel
@onready var sell_button: Button = $MainPanel/DetailPanel/SellButton
@onready var texture_rect: TextureRect = $MainPanel/TextureRect
@onready var title_label_2: Label = $MainPanel/TitleLabel2
var _selected_item: ItemData = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title_label.text = shop_title
	close_button.pressed.connect(queue_free)
	sell_button.pressed.connect(_on_sell_pressed)

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
	if not only_special:
		return GlobalInventory.collected_items

	var filtered: Array = []
	for item in GlobalInventory.collected_items:
		if item.is_special:
			filtered.append(item)
	return filtered


func _get_sell_price(data: ItemData) -> int:
	var multiplier: float = sell_multiplier

	return int(round(data.value * multiplier))


func _populate_list() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	var items := _get_filtered_items()

	for item_data in items:
		if slot_scene:
			var slot_instance = slot_scene.instantiate() as InventorySlot
			grid_container.add_child(slot_instance)
			slot_instance.setup(item_data)
			slot_instance.slot_clicked.connect(_on_item_selected)

	# Seçili eşya listeden çıktıysa (satıldıysa/filtreye artık uymuyorsa) detay panelini temizle
	if _selected_item and not items.has(_selected_item):
		_clear_details()


func _on_item_selected(data: ItemData) -> void:
	if not data:
		return

	_selected_item = data

	big_image.texture = data.get("sprite")
	name_label.text = data.get("item_name")
	desc_label.text = data.get("description")

	var sell_price: int = _get_sell_price(data)
	value_label.text = "Satış Fiyatı: %d Zurna" % sell_price

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

	sell_button.disabled = false
	sell_button.text = "SAT (%d Zurna)" % sell_price


func _on_sell_pressed() -> void:
	if not _selected_item:
		return

	var sell_price: int = _get_sell_price(_selected_item)

	# Not: remove_item() -> inventory_updated sinyalini tetikler -> _populate_list()
	# otomatik çalışır ve seçili eşya listede kalmadığı için detay paneli de otomatik temizlenir.
	if GlobalInventory.remove_item(_selected_item):
		GlobalEconomy.add_money(sell_price)


func _on_sell_button_pressed() -> void:
	GlobalSoundManager.play_sfx("sell")
