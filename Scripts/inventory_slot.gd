extends Button
class_name InventorySlot

signal slot_clicked(item_data: Resource)

var _item_data: Resource

# Kategori renk tablosu
const CATEGORY_COLORS: Dictionary = {
	"Trash": Color(0.65, 0.65, 0.65, 0.9),       # Gri (Çöp)
	"Resource": Color(0.25, 0.75, 0.95, 0.9),    # Cyan / Mavi (Hammadde)
	"Rare Found": Color(0.75, 0.40, 0.95, 0.9),  # Mor (Nadir Buluntu)
	"Valuable": Color(0.95, 0.80, 0.20, 0.9),    # Altın Sarısı (Değerli)
	"Special": Color(0.95, 0.30, 0.45, 0.9),     # Mercan / Kırmızı (Özel)
}
const DEFAULT_BG_COLOR := Color(0.2, 0.2, 0.2, 0.9)

func setup(data: Resource) -> void:
	_item_data = data
	pressed.connect(_on_pressed)

	if _item_data:
		# İkonu yerleştir
		if _item_data.get("sprite"):
			$ItemIcon.texture = _item_data.get("sprite")

		# Kategoriye göre arka plan rengini ver
		var category: String = str(_item_data.get("category"))
		$RarityBackground.color = CATEGORY_COLORS.get(category, DEFAULT_BG_COLOR)

func _on_pressed() -> void:
	emit_signal("slot_clicked", _item_data)
