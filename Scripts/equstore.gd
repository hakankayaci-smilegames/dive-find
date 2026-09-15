extends CanvasLayer

@export var slot_scene: PackedScene                        # equipment_slot.tscn
@export var upgrades: Array[EquipmentUpgradeData] = []      # Sırayla: Gözlük, Tüp, Çanta, Palet .tres dosyaları buraya sürüklenecek

@onready var close_button: Button = $MainPanel/CloseButton
@onready var slots_container: HBoxContainer = $MainPanel/SlotsContainer
@onready var title_label: Label = $MainPanel/TitleLabel
@onready var subtitle_label: Label = get_node_or_null("MainPanel/SubtitleLabel")

var _player: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ofis açıp oyunu duraklattığımızda bu panel çalışmaya devam etsin
	add_to_group("equstore")
	close_button.pressed.connect(queue_free)

	_player = get_tree().get_first_node_in_group("player")

	_build_slots()
	refresh_ui()

	GlobalEconomy.money_changed.connect(_on_money_changed)


func _exit_tree() -> void:
	if GlobalEconomy.money_changed.is_connected(_on_money_changed):
		GlobalEconomy.money_changed.disconnect(_on_money_changed)


func refresh_ui() -> void:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_instance_valid(title_label):
		title_label.text = "Equipment Shop" if is_en else "Ekipman Mağazası"
	if is_instance_valid(subtitle_label):
		subtitle_label.text = "As level increases, diving capability improves" if is_en else "Seviye arttıkça dalış gücün artar"
	for slot in slots_container.get_children():
		if slot is EquipmentSlot:
			slot.refresh(slot.current_level)


func _build_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()

	for upgrade_data in upgrades:
		if not slot_scene or not upgrade_data:
			continue

		var slot := slot_scene.instantiate() as EquipmentSlot
		slots_container.add_child(slot)

		var current_level: int = _get_player_stat(upgrade_data.stat_key)
		slot.setup(upgrade_data, current_level)
		slot.upgrade_requested.connect(_on_upgrade_requested)


func _get_player_stat(stat_key: String) -> int:
	if stat_key == "":
		return 0
	if GlobalInventory.has_method("get_equipment_stat"):
		return GlobalInventory.get_equipment_stat(stat_key, 1 if stat_key == "tube_level" else 0)
	if _player:
		var value = _player.get(stat_key)
		if value != null:
			return int(value)
	return 1 if stat_key == "tube_level" else 0


func _on_upgrade_requested(slot: EquipmentSlot) -> void:
	var current_level: int = _get_player_stat(slot.data.stat_key)

	if slot.data.max_level >= 0 and current_level >= slot.data.max_level:
		return

	var cost: int = slot.calculate_cost(current_level)

	if not GlobalEconomy.has_enough(cost):
		return  # Para yetersiz

	var new_level: int = current_level + 1

	if not GlobalEconomy.spend_money(cost):
		return

	if GlobalInventory.has_method("set_equipment_stat"):
		GlobalInventory.set_equipment_stat(slot.data.stat_key, new_level)
	elif _player:
		_player.set(slot.data.stat_key, new_level)
		GlobalInventory.equipment_updated.emit(slot.data.stat_key, new_level)
		GlobalInventory.inventory_updated.emit()

	slot.current_level = new_level
	GlobalSoundManager.play_sfx("upgrade")
	slot.refresh(new_level)
	slot.play_upgrade_feedback()


func _on_money_changed(_new_amount: int) -> void:
	for slot in slots_container.get_children():
		if slot is EquipmentSlot:
			slot.refresh(slot.current_level)
