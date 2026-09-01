extends Button
class_name CollectionSlot
## Keşfedilen eşyaları tıklanabilir yaparak inceleme pop-up'ını açar.

signal slot_clicked(item_data: ItemData)

@onready var rarity_bg: ColorRect = $RarityBackground
@onready var item_icon: TextureRect = $ItemIcon

var _item_data: ItemData = null
var _is_discovered: bool = false

const CATEGORY_COLORS: Dictionary = {
	"Trash": Color(0.65, 0.65, 0.65, 0.85),      # Gri (Çöp)
	"Resource": Color(0.25, 0.75, 0.95, 0.85),   # Cyan / Mavi (Hammadde)
	"Rare Found": Color(0.75, 0.40, 0.95, 0.85), # Mor (Nadir Buluntu)
	"Valuable": Color(0.95, 0.80, 0.20, 0.85),   # Altın Sarısı (Değerli)
	"Special": Color(0.95, 0.30, 0.45, 0.85),    # Mercan / Kırmızı (Özel)
}
const UNDISCOVERED_BG := Color(0.08, 0.08, 0.08, 0.85)
const SILHOUETTE_COLOR := Color(0.0, 0.0, 0.0, 1.0)


func _ready() -> void:
	pressed.connect(_on_pressed)


func setup(item_data: ItemData, discovered: bool) -> void:
	if not item_data:
		return

	_item_data = item_data
	_is_discovered = discovered
	item_icon.texture = item_data.sprite

	if discovered:
		item_icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		rarity_bg.color = CATEGORY_COLORS.get(item_data.category, Color(0.2, 0.2, 0.2, 0.8))
		tooltip_text = item_data.item_name
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		item_icon.modulate = SILHOUETTE_COLOR  # Sprite'ın alfa/şeklini korur, rengini siyaha çeker
		rarity_bg.color = UNDISCOVERED_BG
		tooltip_text = "???"
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _on_pressed() -> void:
	if _is_discovered and _item_data:
		emit_signal("slot_clicked", _item_data)
