extends Button
class_name InventorySlot

signal slot_clicked(item_data: Resource)

var _item_data: Resource

# Nadirlik renk tablosu
const RARITY_COLORS = [
	Color(0.6, 0.6, 0.6, 0.9),  # 0: Common (Gri)
	Color(0.3, 0.8, 0.3, 0.9),  # 1: Uncommon (Yeşil)
	Color(0.3, 0.5, 1.0, 0.9),  # 2: Rare (Mavi)
	Color(0.8, 0.3, 0.9, 0.95), # 3: Epic (Mor)
	Color(1.0, 0.8, 0.2, 1.0),  # 4: Legendary (Sarı/Altın)
	Color(0.9, 0.1, 0.2, 1.0),  # 5: Mythic (Kırmızı)
	Color(1.0, 1.0, 1.0, 1.0)   # 6: Divine (Beyaz)
	]

func setup(data: Resource) -> void:
	_item_data = data
	pressed.connect(_on_pressed)

	if _item_data:
		# İkonu yerleştir
		if _item_data.get("sprite"):
			$ItemIcon.texture = _item_data.get("sprite")

			# Nadirliğe göre arka plan rengini ver
			var rarity: int = _item_data.get("rarity") if _item_data.get("rarity") != null else 0
			if rarity >= 0 and rarity < RARITY_COLORS.size():
				$RarityBackground.color = RARITY_COLORS[rarity]
			else:
				$RarityBackground.color = RARITY_COLORS[0]

func _on_pressed() -> void:
	emit_signal("slot_clicked", _item_data)
