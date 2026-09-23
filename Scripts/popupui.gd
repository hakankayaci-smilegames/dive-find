extends CanvasLayer

var _item_data: Resource
var _physical_item: Node2D
var _is_preview_mode: bool = false

@onready var backdrop: ColorRect = $Backdrop
@onready var card_panel: PanelContainer = $Backdrop/CardPanel
@onready var category_badge: PanelContainer = $Backdrop/CardPanel/MarginContainer/VBoxContainer/TopBar/CategoryBadge
@onready var new_badge: PanelContainer = $Backdrop/CardPanel/MarginContainer/VBoxContainer/TopBar/NewBadge
@onready var category_label: Label = $Backdrop/CardPanel/MarginContainer/VBoxContainer/TopBar/CategoryBadge/BadgeMargin/CategoryLabel
@onready var rarity_label: Label = $Backdrop/CardPanel/MarginContainer/VBoxContainer/TopBar/RarityLabel
@onready var icon_frame: PanelContainer = $Backdrop/CardPanel/MarginContainer/VBoxContainer/ContentHBox/IconFrame
@onready var item_image: TextureRect = $Backdrop/CardPanel/MarginContainer/VBoxContainer/ContentHBox/IconFrame/ItemImage
@onready var name_label: Label = $Backdrop/CardPanel/MarginContainer/VBoxContainer/ContentHBox/DetailsVBox/NameLabel
@onready var value_label: Label = $Backdrop/CardPanel/MarginContainer/VBoxContainer/ContentHBox/DetailsVBox/ValueLabel
@onready var desc_label: Label = $Backdrop/CardPanel/MarginContainer/VBoxContainer/ContentHBox/DetailsVBox/DescLabel
@onready var pickup_button: Button = $Backdrop/CardPanel/MarginContainer/VBoxContainer/ActionsHBox/Pickup
@onready var close_button: Button = $Backdrop/CardPanel/MarginContainer/VBoxContainer/ActionsHBox/Close

const CATEGORY_NAMES := {
	"Trash": "[ ÇÖP ]",
	"Resource": "[ HAMMADDE ]",
	"Rare Found": "[ NADİR BULUNTU ]",
	"Valuable": "[ DEĞERLİ ]",
	"Special": "[ ÖZEL ]",
	"Crafted": "[ ÜRETİLMİŞ ]"
}

const CATEGORY_NAMES_EN := {
	"Trash": "[ TRASH ]",
	"Resource": "[ RESOURCE ]",
	"Rare Found": "[ RARE FIND ]",
	"Valuable": "[ VALUABLE ]",
	"Special": "[ SPECIAL ]",
	"Crafted": "[ CRAFTED ]"
}

const CATEGORY_COLORS := {
	"Trash": Color(0.70, 0.65, 0.60),
	"Resource": Color(0.30, 0.80, 1.00),
	"Rare Found": Color(0.80, 0.50, 1.00),
	"Valuable": Color(1.00, 0.85, 0.25),
	"Special": Color(1.00, 0.35, 0.50),
	"Crafted": Color(1.00, 0.55, 0.15)
}

const RARITY_NAMES := {
	0: "Yaygın",
	1: "Nadir",
	2: "Çok Nadir",
	3: "Destansı",
	4: "Efsanevi",
	5: "Mistik",
	6: "İlahi"
}

const RARITY_NAMES_EN := {
	0: "Common",
	1: "Uncommon",
	2: "Rare",
	3: "Epic",
	4: "Legendary",
	5: "Mythic",
	6: "Divine"
}

const RARITY_COLORS := {
	0: Color(0.60, 0.60, 0.60),
	1: Color(0.30, 0.85, 0.35),
	2: Color(0.30, 0.60, 1.00),
	3: Color(0.80, 0.35, 0.95),
	4: Color(1.00, 0.80, 0.20),
	5: Color(1.00, 0.20, 0.35),
	6: Color(1.00, 1.00, 1.00)
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	add_to_group("popup_ui")

	# Açılış Pop-in Animasyonu
	card_panel.pivot_offset = card_panel.size / 2.0
	card_panel.scale = Vector2(0.85, 0.85)
	card_panel.modulate.a = 0.0
	backdrop.modulate.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(backdrop, "modulate:a", 1.0, 0.15)
	tw.tween_property(card_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(card_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	GlobalInventory.inventory_updated.connect(_refresh_pickup_state)
	_refresh_pickup_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _is_preview_mode:
			match event.keycode:
				KEY_ESCAPE, KEY_E, KEY_SPACE, KEY_ENTER:
					_on_close_pressed()
					get_viewport().set_input_as_handled()
		else:
			match event.keycode:
				KEY_E, KEY_SPACE, KEY_ENTER:
					_on_pickup_pressed()
					get_viewport().set_input_as_handled()
				KEY_ESCAPE:
					_on_close_pressed()
					get_viewport().set_input_as_handled()


func setup(data: Resource, physical_item: Node2D = null, preview_mode: bool = false) -> void:
	_item_data = data
	_physical_item = physical_item
	_is_preview_mode = preview_mode

	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	if _is_preview_mode:
		if is_instance_valid(pickup_button):
			pickup_button.visible = false
		if is_instance_valid(close_button):
			close_button.text = "CLOSE [ESC]" if is_en else "KAPAT [ESC]"
	else:
		if is_instance_valid(close_button):
			close_button.text = "LEAVE [ESC]" if is_en else "BIRAK [ESC]"

	if not _item_data:
		return

	# Görsel ve İsim
	if _item_data.get("sprite"):
		item_image.texture = _item_data.get("sprite")

	var item_obj: ItemData = _item_data as ItemData
	name_label.text = ItemTranslator.get_item_name(item_obj) if item_obj else str(_item_data.get("item_name"))
	var desc_text: String = ItemTranslator.get_item_description(item_obj) if item_obj else str(_item_data.get("description"))
	desc_label.text = desc_text
	if desc_text.length() > 140:
		desc_label.add_theme_font_size_override("font_size", 11)
	else:
		desc_label.add_theme_font_size_override("font_size", 12)
	value_label.text = ("Value: %s Zurna" if is_en else "Değer: %s Zurna") % str(_item_data.get("value"))

	# Nadirlik Renk ve Metni
	var raw_rarity: int = int(_item_data.get("rarity")) if _item_data.get("rarity") != null else 0
	var r_name: String = RARITY_NAMES_EN.get(raw_rarity, "Unknown") if is_en else RARITY_NAMES.get(raw_rarity, "Bilinmeyen")
	var r_color: Color = RARITY_COLORS.get(raw_rarity, Color(0.7, 0.7, 0.7))
	rarity_label.text = "* " + r_name
	rarity_label.add_theme_color_override("font_color", r_color)

	# İkon yuvası kenarlığını nadirlik rengine göre tonla
	var icon_style := icon_frame.get_theme_stylebox("panel")
	if icon_style is StyleBoxFlat:
		var custom_slot_style := icon_style.duplicate() as StyleBoxFlat
		custom_slot_style.border_color = r_color
		icon_frame.add_theme_stylebox_override("panel", custom_slot_style)

	# Kategori Rozeti (Belirgin arka plan ve kenarlık)
	var category_key: String = str(_item_data.get("category"))
	var c_display: String = (CATEGORY_NAMES_EN if is_en else CATEGORY_NAMES).get(category_key, "[ %s ]" % category_key.to_upper())
	var c_color: Color = CATEGORY_COLORS.get(category_key, Color(0.85, 0.75, 0.45))

	category_label.text = c_display
	category_label.add_theme_color_override("font_color", c_color)

	var badge_style := category_badge.get_theme_stylebox("panel")
	if badge_style is StyleBoxFlat:
		var custom_badge_style := badge_style.duplicate() as StyleBoxFlat
		custom_badge_style.border_color = c_color
		custom_badge_style.bg_color = Color(c_color.r * 0.18, c_color.g * 0.18, c_color.b * 0.18, 0.95)
		category_badge.add_theme_stylebox_override("panel", custom_badge_style)

	# Yeni Keşif Rozeti (Eşya daha önce toplanıp deftere kaydedilmemişse göster)
	var is_discovered: bool = GlobalInventory.is_item_discovered(_item_data)
	if is_instance_valid(new_badge):
		new_badge.visible = (not is_discovered) and (not _is_preview_mode)
		if new_badge.visible:
			_play_new_badge_pulse()


func _play_new_badge_pulse() -> void:
	if not is_instance_valid(new_badge):
		return
	var tw := create_tween().set_loops()
	tw.tween_property(new_badge, "modulate", Color(1.35, 1.35, 1.35, 1.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(new_badge, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _refresh_pickup_state() -> void:
	if _is_preview_mode:
		return
	if not is_instance_valid(pickup_button):
		return

	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if GlobalInventory.is_full():
		pickup_button.text = ("FULL (%d/%d)" if is_en else "DOLU (%d/%d)") % [GlobalInventory.collected_items.size(), GlobalInventory.get_capacity()]
		pickup_button.tooltip_text = "Inventory full! You need to clear space." if is_en else "Çantan dolu! Boşaltman gerek."
	else:
		pickup_button.text = "PICK UP [E]" if is_en else "AL [E]"
		pickup_button.tooltip_text = ""


func _trigger_full_warning() -> void:
	GlobalSoundManager.play_sfx("error")
	if is_instance_valid(pickup_button):
		var orig_x: float = pickup_button.position.x
		var tw := create_tween()
		tw.tween_property(pickup_button, "position:x", orig_x - 6.0, 0.04)
		tw.tween_property(pickup_button, "position:x", orig_x + 6.0, 0.04)
		tw.tween_property(pickup_button, "position:x", orig_x - 4.0, 0.04)
		tw.tween_property(pickup_button, "position:x", orig_x, 0.04)

		pickup_button.modulate = Color(1.8, 0.3, 0.3, 1.0)
		var c_tw := create_tween()
		c_tw.tween_property(pickup_button, "modulate", Color.WHITE, 0.35)


func _on_close_pressed() -> void:
	# BIRAK: Arayüzü yumuşakça kapat, eşya haritada kalsın
	_animate_and_close()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	# Kart dışındaki karartılmış arka plana sol tık yapılırsa kapat
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var card_rect := card_panel.get_global_rect()
		if not card_rect.has_point(event.global_position):
			_on_close_pressed()


func _on_pickup_pressed() -> void:
	if GlobalInventory.is_full():
		_trigger_full_warning()
		_refresh_pickup_state()
		return

	var added: bool = GlobalInventory.add_item(_item_data)
	if not added:
		_trigger_full_warning()
		_refresh_pickup_state()
		return

	# Fiziksel objede VFX ve ses tetikle
	if is_instance_valid(_physical_item) and _physical_item.has_method("play_pickup_vfx_and_destroy"):
		_physical_item.play_pickup_vfx_and_destroy()
	elif is_instance_valid(_physical_item):
		GlobalSoundManager.play_sfx("pickup")
		_physical_item.queue_free()
	else:
		GlobalSoundManager.play_sfx("pickup")

	_animate_and_close()


func _animate_and_close() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(backdrop, "modulate:a", 0.0, 0.12)
	tw.tween_property(card_panel, "scale", Vector2(0.85, 0.85), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func refresh_ui() -> void:
	if _item_data:
		setup(_item_data, _physical_item, _is_preview_mode)


func _exit_tree() -> void:
	if GlobalInventory.inventory_updated.is_connected(_refresh_pickup_state):
		GlobalInventory.inventory_updated.disconnect(_refresh_pickup_state)
