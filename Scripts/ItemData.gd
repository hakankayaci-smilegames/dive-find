extends Resource
class_name ItemData

@export var item_name: String = "Bilinmeyen Eşya"
@export var sprite: Texture2D
@export_multiline var description: String = "Eşya açıklaması..."
@export var rarity: float = 0.0  # Artık sadece kalite göstergesi değil, doğrudan spawn ağırlığı (weight)
@export var value: int = 10
@export_enum("Trash", "Resource", "Rare Found", "Special", "Valuable", "Crafted") var category: String = "Trash"
var is_locked: bool = false
var source_path: String = ""
