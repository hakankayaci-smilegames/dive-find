extends Control
class_name CollectionSlot
## inventory_slot.gd ile aynı görsel iskelet (RarityBackground + ItemIcon),
## tek fark: tıklanabilir detay yerine sadece tooltip + keşif durumuna göre silüet.

@onready var rarity_bg: ColorRect = $RarityBackground
@onready var icon: TextureRect = $ItemIcon

const RARITY_COLORS := {
	0: Color(0.55, 0.55, 0.55, 0.8),  # Yaygın - gri
	1: Color(0.35, 0.75, 0.35, 0.8),  # Nadir - yeşil
	2: Color(0.30, 0.55, 0.95, 0.8),  # Çok Nadir - mavi
	3: Color(0.65, 0.35, 0.85, 0.8),  # Destansı - mor
	4: Color(0.95, 0.65, 0.15, 0.8),  # Efsanevi - turuncu/altın
	5: Color(0.90, 0.20, 0.85, 0.8),  # Mistik - pembe/magenta
}
const UNDISCOVERED_BG := Color(0.08, 0.08, 0.08, 0.85)
const SILHOUETTE_COLOR := Color(0.0, 0.0, 0.0, 1.0)


func setup(item_data: ItemData, discovered: bool) -> void:
	if not item_data:
		return

	icon.texture = item_data.sprite

	if discovered:
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		rarity_bg.color = RARITY_COLORS.get(item_data.rarity, Color(0.2, 0.2, 0.2, 0.8))
		tooltip_text = item_data.item_name
	else:
		icon.modulate = SILHOUETTE_COLOR  # Sprite'ın alfa/şeklini korur, rengini siyaha çeker
		rarity_bg.color = UNDISCOVERED_BG
		tooltip_text = "???"
