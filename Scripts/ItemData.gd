extends Resource
class_name ItemData

@export var item_name: String = "Bilinmeyen Eşya"
@export var sprite: Texture2D
@export_multiline var description: String = "Eşya açıklaması..."
@export var rarity: float = 0.0  # Kalite/Aura kademesi (0: Common, 1: Uncommon, 2: Rare, 3: Epic, 4: Legendary, 5: Mythic, 6: Divine)
@export var spawn_weight: float = 1.0  # Havuz içi çıkma ağırlığı (Spawn chance weight)
@export var value: int = 10
@export_enum("Trash", "Resource", "Rare Found", "Special", "Valuable", "Crafted") var category: String = "Trash"
var is_locked: bool = false
var source_path: String = ""

func get_display_name() -> String:
	return ItemTranslator.get_item_name(self)

func get_display_description() -> String:
	return ItemTranslator.get_item_description(self)
