extends Resource
class_name EquipmentUpgradeData

@export var display_name: String = "Ekipman"
@export var icon: Texture2D
@export var stat_key: String = ""            # player_controller.gd'deki export değişken adı (ör: "tube_level", "backpack_level", "fins_level", "goggles_level")
@export var description: String = ""         # "Camera daha geri zoom yapabilecek" gibi kısa açıklama

@export_group("Fiyatlandırma")
@export var base_cost: int = 15             # Lvl0 -> Lvl1 yükseltme maliyeti
@export var cost_multiplier: float = 1.35    # Her seviyede fiyat bu katsayıyla çarpılarak artar (üstel eğri)
@export var max_level: int = -1              # -1 = sınırsız yükseltme
