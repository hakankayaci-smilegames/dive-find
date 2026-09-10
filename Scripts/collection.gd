extends CanvasLayer
## Koleksiyon Defteri: eşya listesini artık kendi taramıyor, GlobalInventory.get_all_items()
## önbelleğini kullanıyor (ilk tarama loading_screen sırasında zaten yapılmış oluyor,
## burada donma olmaz).

@export var slot_scene: PackedScene  # res://Scenes/collection_slot.tscn
@export var popup_scene: PackedScene = preload("res://Scenes/pickup.tscn")

@onready var grid_container: GridContainer = $MainPanel/ScrollContainer/GridContainer
@onready var close_button: Button = $MainPanel/CloseButton
@onready var progress_label: Label = $MainPanel/ProgressLabel
@onready var progress_bar: ProgressBar = $MainPanel/ProgressBar
@onready var progress_bar_text: Label = $MainPanel/ProgressBar/ProgressBarText

@onready var tab_all: Button = get_node_or_null("MainPanel/CategoryTabs/TabAll")
@onready var tab_trash: Button = get_node_or_null("MainPanel/CategoryTabs/TabTrash")
@onready var tab_resource: Button = get_node_or_null("MainPanel/CategoryTabs/TabResource")
@onready var tab_rare: Button = get_node_or_null("MainPanel/CategoryTabs/TabRare")
@onready var tab_valuable: Button = get_node_or_null("MainPanel/CategoryTabs/TabValuable")
@onready var tab_special: Button = get_node_or_null("MainPanel/CategoryTabs/TabSpecial")
@onready var tab_crafted: Button = get_node_or_null("MainPanel/CategoryTabs/TabCrafted")

var _current_filter: String = "All"
var _cached_sorted_items: Array[ItemData] = []

const CATEGORY_ORDER: Dictionary = {
	"Trash": 0,       # Gri (Çöp)
	"Resource": 1,    # Cyan (Hammadde)
	"Rare Found": 2,  # Mor (Nadir Buluntu)
	"Valuable": 3,    # Altın Sarısı (Değerli)
	"Special": 4,     # Kırmızı (Özel)
	"Crafted": 5      # Amber (Üretilen)
}

const CATEGORY_LABELS_TR: Dictionary = {
	"All": "Tüm Koleksiyon",
	"Trash": "Hurda / Çöp",
	"Resource": "Hammaddeler",
	"Rare Found": "Nadir Buluntular",
	"Valuable": "Değerli Eşyalar",
	"Special": "Özel Eşyalar",
	"Crafted": "Üretilenler"
}

const CATEGORY_LABELS_EN: Dictionary = {
	"All": "All Collection",
	"Trash": "Scrap / Trash",
	"Resource": "Raw Materials",
	"Rare Found": "Rare Finds",
	"Valuable": "Valuable Items",
	"Special": "Special Items",
	"Crafted": "Crafted Items"
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ofis pause'ken de çalışsın
	add_to_group("popup_ui")
	close_button.pressed.connect(queue_free)

	# Mobil dokunmatik ekran optimizasyonu (daha geniş butonlar)
	var is_touch: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if is_touch and grid_container:
		grid_container.columns = 6

	_load_sorted_items_cache()
	_setup_tabs()
	refresh_ui()

	if GlobalInventory.has_signal("collection_updated"):
		GlobalInventory.collection_updated.connect(_on_collection_updated_event)


func refresh_ui() -> void:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	var title_lbl: Label = get_node_or_null("MainPanel/TitleLabel")
	if title_lbl:
		title_lbl.text = "Collection Book" if is_en else "Koleksiyon Defteri"

	if tab_all: tab_all.text = "All" if is_en else "Hepsi"
	if tab_trash: tab_trash.text = "🗑️ Trash" if is_en else "🗑️ Çöp"
	if tab_resource: tab_resource.text = "🧪 Resource" if is_en else "🧪 Madde"
	if tab_rare: tab_rare.text = "🏛️ Rare" if is_en else "🏛️ Nadir"
	if tab_valuable: tab_valuable.text = "💎 Valuable" if is_en else "💎 Değerli"
	if tab_special: tab_special.text = "🔴 Special" if is_en else "🔴 Özel"
	if tab_crafted: tab_crafted.text = "🔨 Crafted" if is_en else "🔨 Üretilen"

	_populate_grid()


func _load_sorted_items_cache() -> void:
	_cached_sorted_items = GlobalInventory.get_all_items(false).duplicate()
	_cached_sorted_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		var order_a: int = CATEGORY_ORDER.get(a.category, 99)
		var order_b: int = CATEGORY_ORDER.get(b.category, 99)
		if order_a != order_b:
			return order_a < order_b
		if a.value != b.value:
			return a.value < b.value
		return a.item_name.naturalnocasecmp_to(b.item_name) < 0
	)


func _on_collection_updated_event(_item: ItemData) -> void:
	_populate_grid()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_E, KEY_I, KEY_TAB, KEY_C:
				queue_free()
				get_viewport().set_input_as_handled()


func _setup_tabs() -> void:
	var tabs: Dictionary = {
		tab_all: "All",
		tab_trash: "Trash",
		tab_resource: "Resource",
		tab_rare: "Rare Found",
		tab_valuable: "Valuable",
		tab_special: "Special",
		tab_crafted: "Crafted"
	}
	for btn in tabs.keys():
		if is_instance_valid(btn):
			var filter_key: String = str(tabs[btn])
			btn.pressed.connect(func() -> void:
				_set_category_filter(filter_key)
			)
	_update_tab_highlights()


func _set_category_filter(filter_key: String) -> void:
	_current_filter = filter_key
	GlobalSoundManager.play_sfx("click")
	_update_tab_highlights()
	_populate_grid()


func _update_tab_highlights() -> void:
	var tabs: Dictionary = {
		tab_all: "All",
		tab_trash: "Trash",
		tab_resource: "Resource",
		tab_rare: "Rare Found",
		tab_valuable: "Valuable",
		tab_special: "Special",
		tab_crafted: "Crafted"
	}
	for btn in tabs.keys():
		if is_instance_valid(btn):
			var is_active: bool = (str(tabs[btn]) == _current_filter)
			btn.modulate = Color(1.2, 1.1, 0.8, 1.0) if is_active else Color(0.75, 0.75, 0.75, 0.85)


func _populate_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	if not slot_scene:
		push_warning("Koleksiyon: slot_scene atanmamış!")
		return

	if _cached_sorted_items.is_empty():
		_load_sorted_items_cache()

	var all_items: Array[ItemData] = _cached_sorted_items

	# Genel toplam hesabı (ProgressBar için)
	var overall_total := all_items.size()
	var overall_discovered := 0
	for item in all_items:
		if GlobalInventory.discovered_items.has(item.resource_path):
			overall_discovered += 1

	# Filtreli liste
	var display_items: Array[ItemData] = []
	for item in all_items:
		if _current_filter == "All" or item.category == _current_filter:
			display_items.append(item)

	var filtered_discovered := 0
	for item in display_items:
		var slot = slot_scene.instantiate() as CollectionSlot
		grid_container.add_child(slot)
		var is_discovered: bool = GlobalInventory.discovered_items.has(item.resource_path)
		if is_discovered:
			filtered_discovered += 1
		slot.setup(item, is_discovered)
		slot.slot_clicked.connect(_on_slot_clicked)

	var filtered_total := display_items.size()
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	var filter_title: String = (CATEGORY_LABELS_EN if is_en else CATEGORY_LABELS_TR).get(_current_filter, "Collection" if is_en else "Koleksiyon")

	if progress_label:
		progress_label.text = ("%s: %d / %d Discovered" if is_en else "%s: %d / %d Keşfedildi") % [filter_title, filtered_discovered, filtered_total]
	if progress_bar:
		progress_bar.max_value = max(overall_total, 1)
		progress_bar.value = overall_discovered
	if progress_bar_text:
		var pct: int = int(round(float(overall_discovered) / float(max(overall_total, 1)) * 100.0))
		progress_bar_text.text = ("Total Discovered: %d / %d (%%%d)" if is_en else "Toplam Keşif: %d / %d (%%%d)") % [
			overall_discovered,
			overall_total,
			pct
		]


func _on_slot_clicked(item: ItemData) -> void:
	if not popup_scene or not item:
		return

	GlobalSoundManager.play_sfx("click")
	var popup = popup_scene.instantiate()
	get_tree().current_scene.add_child(popup)
	popup.setup(item, null, true)
