extends Panel
class_name EquipmentSlot

signal upgrade_requested(slot: EquipmentSlot)

@onready var icon_rect: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var level_label: Label = $LevelLabel
@onready var cost_label: Label = $CostLabel
@onready var upgrade_button: Button = $UpgradeButton

var data: EquipmentUpgradeData
var current_level: int = 0
var current_cost: int = 0


func _ready() -> void:
	upgrade_button.pressed.connect(_on_upgrade_pressed)


func setup(upgrade_data: EquipmentUpgradeData, level: int) -> void:
	data = upgrade_data
	icon_rect.texture = data.icon
	name_label.text = data.display_name
	refresh(level)


func refresh(level: int) -> void:
	current_level = level
	current_cost = calculate_cost(level)

	level_label.text = "Seviye: %d" % level

	var maxed_out: bool = data.max_level >= 0 and level >= data.max_level

	if maxed_out:
		cost_label.text = "MAKSİMUM SEVİYE"
		upgrade_button.text = "MAX"
		upgrade_button.disabled = true
	else:
		cost_label.text = "%d Zurna" % current_cost
		upgrade_button.text = "UPGRADE"
		# Para yetersizse buton otomatik disabled olur; GlobalEconomy.money_changed
		# her tetiklendiğinde equstore.gd tüm slotları refresh() ile bu durumu günceller.
		upgrade_button.disabled = not GlobalEconomy.has_enough(current_cost)


func calculate_cost(level: int) -> int:
	return int(round(data.base_cost * pow(data.cost_multiplier, level)))


func _on_upgrade_pressed() -> void:
	emit_signal("upgrade_requested", self)
