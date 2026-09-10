extends Panel
class_name EquipmentSlot

signal upgrade_requested(slot: EquipmentSlot)

@onready var icon_rect: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var level_label: Label = $LevelLabel
@onready var stat_label: Label = get_node_or_null("StatPreviewLabel")
@onready var cost_label: Label = $CostLabel
@onready var upgrade_button: Button = $UpgradeButton

var data: EquipmentUpgradeData
var current_level: int = 0
var current_cost: int = 0
var _scale_tween: Tween = null


func _ready() -> void:
	upgrade_button.pressed.connect(_on_upgrade_pressed)


func setup(upgrade_data: EquipmentUpgradeData, level: int) -> void:
	data = upgrade_data
	icon_rect.texture = data.icon
	refresh(level)


func _get_equipment_name() -> String:
	if not data:
		return ""
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_en:
		match data.stat_key:
			"backpack_level":
				return "Backpack"
			"tube_level":
				return "Oxygen Tank"
			"fins_level":
				return "Fins"
			"goggles_level":
				return "Diving Mask"
			"flashlight_level":
				return "Dive Light"
	return tr(data.display_name)


func refresh(level: int) -> void:
	current_level = level
	current_cost = calculate_cost(level)

	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	name_label.text = _get_equipment_name()
	level_label.text = ("Level: %d" if is_en else "Seviye: %d") % level

	var maxed_out: bool = data.max_level >= 0 and level >= data.max_level

	if maxed_out:
		cost_label.text = "MAXIMUM LEVEL" if is_en else "MAKSİMUM SEVİYE"
		if stat_label:
			stat_label.text = "Maximum Efficiency" if is_en else "Maksimum Verim"
			stat_label.tooltip_text = "This equipment is at maximum level!" if is_en else "Bu ekipman en üst seviyede!"
			stat_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45, 1.0))
		upgrade_button.text = "MAX"
		upgrade_button.disabled = true
		upgrade_button.tooltip_text = "This equipment is at maximum level!" if is_en else "Bu ekipman en üst seviyede!"
	else:
		cost_label.text = "%d Zurna" % current_cost
		var preview_text := _get_stat_preview(data.stat_key, level)
		var preview_tooltip := _get_stat_tooltip(data.stat_key, level)
		if stat_label:
			stat_label.text = preview_text
			stat_label.tooltip_text = preview_tooltip
			stat_label.add_theme_color_override("font_color", Color(0.35, 0.90, 0.50, 1.0))

		var has_money: bool = GlobalEconomy.has_enough(current_cost)
		upgrade_button.disabled = not has_money
		if has_money:
			upgrade_button.text = "UPGRADE" if is_en else "GELİŞTİR"
			upgrade_button.tooltip_text = preview_tooltip
		else:
			var missing: int = current_cost - GlobalEconomy.money
			upgrade_button.text = ("INSUFFICIENT (-%d Z)" if is_en else "YETERSİZ (-%d Z)") % missing
			upgrade_button.tooltip_text = ("%d more Zurna required!\n%s" if is_en else "%d Zurna daha gerekli!\n%s") % [missing, preview_tooltip]


func _get_stat_preview(stat_key: String, lvl: int) -> String:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	match stat_key:
		"tube_level":
			var cur_eff: float = 1.0 + float(max(0, lvl - 1)) * 1.25
			var next_eff: float = 1.0 + float(lvl) * 1.25
			return ("Oxygen: x%.2f ➔ x%.2f" if is_en else "Oksijen: x%.2f ➔ x%.2f") % [cur_eff, next_eff]
		"backpack_level":
			var cur_cap: int = 5 + lvl * 5
			var next_cap: int = 5 + (lvl + 1) * 5
			return ("Capacity: %d ➔ %d Slots" if is_en else "Kapasite: %d ➔ %d Slot") % [cur_cap, next_cap]
		"fins_level":
			var cur_spd: int = int(round(lvl * 55.0))
			var next_spd: int = int(round((lvl + 1) * 55.0))
			return ("Speed: +%d ➔ +%d px/s" if is_en else "Hız: +%d ➔ +%d px/s") % [cur_spd, next_spd]
		"goggles_level":
			return ("Vision: Lvl %d ➔ %d" if is_en else "Görüş: Lvl %d ➔ %d") % [lvl, lvl + 1]
		"flashlight_level":
			if lvl <= 0:
				return "Battery: 0s ➔ 75s (95°)" if is_en else "Batarya: 0s ➔ 75s (95°)"
			var cur_bat: int = int(round(75.0 + float(lvl - 1) * 8.93))
			var next_bat: int = int(round(75.0 + float(lvl) * 8.93))
			return ("Battery: %ds ➔ %ds (+4°)" if is_en else "Batarya: %ds ➔ %ds (+4°)") % [cur_bat, next_bat]
		_:
			return "Lvl %d ➔ %d" % [lvl, lvl + 1]


func _get_stat_tooltip(stat_key: String, lvl: int) -> String:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	match stat_key:
		"tube_level":
			var cur_eff: float = 1.0 + float(max(0, lvl - 1)) * 1.25
			var next_eff: float = 1.0 + float(lvl) * 1.25
			return ("Oxygen Resistance: x%.2f ➔ x%.2f" if is_en else "Oksijen Direnci: x%.2f ➔ x%.2f") % [cur_eff, next_eff]
		"backpack_level":
			var cur_cap: int = 5 + lvl * 5
			var next_cap: int = 5 + (lvl + 1) * 5
			return ("Backpack Capacity: %d ➔ %d Slots" if is_en else "Çanta Kapasitesi: %d ➔ %d Slot") % [cur_cap, next_cap]
		"fins_level":
			var cur_spd: int = int(round(lvl * 55.0))
			var next_spd: int = int(round((lvl + 1) * 55.0))
			return ("Swim Speed: +%d ➔ +%d px/s" if is_en else "Yüzme Hızı: +%d ➔ +%d px/s") % [cur_spd, next_spd]
		"goggles_level":
			return ("Wide Angle Vision / Zoom: Lvl %d ➔ %d" if is_en else "Geniş Açı Görüş / Zoom: Lvl %d ➔ %d") % [lvl, lvl + 1]
		"flashlight_level":
			if lvl <= 0:
				if is_en:
					return "Unlocks Dive Light:\n• Battery Life: 75s\n• Light Angle: 95°\n• Light Range: 1050 px"
				else:
					return "Dalış Fenerini Açar:\n• Batarya Süresi: 75 sn\n• Işık Açısı: 95°\n• Işık Menzili: 1050 px"
			var cur_bat: int = int(round(75.0 + float(lvl - 1) * 8.93))
			var next_bat: int = int(round(75.0 + float(lvl) * 8.93))
			var cur_ang: int = int(round(95.0 + float(lvl - 1) * 4.286))
			var next_ang: int = int(round(95.0 + float(lvl) * 4.286))
			var cur_rng: int = int(round(1050.0 + float(lvl - 1) * 110.71))
			var next_rng: int = int(round(1050.0 + float(lvl) * 110.71))
			if is_en:
				return "Light Improvements:\n• Battery Life: %ds ➔ %ds\n• Light Angle: %d° ➔ %d°\n• Light Range: %d px ➔ %d px" % [
					cur_bat, next_bat, cur_ang, next_ang, cur_rng, next_rng
				]
			else:
				return "Fener İyileştirmeleri:\n• Batarya Süresi: %d sn ➔ %d sn\n• Işık Açısı: %d° ➔ %d°\n• Işık Menzili: %d px ➔ %d px" % [
					cur_bat, next_bat, cur_ang, next_ang, cur_rng, next_rng
				]
		_:
			return ""


func play_upgrade_feedback() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	scale = Vector2.ONE
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.08)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func calculate_cost(level: int) -> int:
	return int(round(data.base_cost * pow(data.cost_multiplier, level)))


func _on_upgrade_pressed() -> void:
	emit_signal("upgrade_requested", self)
