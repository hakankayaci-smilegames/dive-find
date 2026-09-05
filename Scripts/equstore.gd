extends CanvasLayer

@export var slot_scene: PackedScene                        # equipment_slot.tscn
@export var upgrades: Array[EquipmentUpgradeData] = []      # Sırayla: Gözlük, Tüp, Çanta, Palet .tres dosyaları buraya sürüklenecek

@onready var close_button: Button = $MainPanel/CloseButton
@onready var slots_container: HBoxContainer = $MainPanel/SlotsContainer

var _player: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ofis açıp oyunu duraklattığımızda bu panel çalışmaya devam etsin
	close_button.pressed.connect(queue_free)

	_player = get_tree().get_first_node_in_group("player")

	_build_slots()

	GlobalEconomy.money_changed.connect(_on_money_changed)


func _exit_tree() -> void:
	if GlobalEconomy.money_changed.is_connected(_on_money_changed):
		GlobalEconomy.money_changed.disconnect(_on_money_changed)


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
	if not _player or stat_key == "":
		return 0
	var value = _player.get(stat_key)
	if value == null:
		return 0
	return int(value)


func _on_upgrade_requested(slot: EquipmentSlot) -> void:
	if not _player:
		return

	var current_level: int = _get_player_stat(slot.data.stat_key)

	if slot.data.max_level >= 0 and current_level >= slot.data.max_level:
		return

	var cost: int = slot.calculate_cost(current_level)

	if not GlobalEconomy.spend_money(cost):
		return  # Para yetersiz

	_player.set(slot.data.stat_key, current_level + 1)
	GlobalSoundManager.play_sfx("upgrade")
	slot.refresh(current_level + 1)
	slot.play_upgrade_feedback()


func _on_money_changed(_new_amount: int) -> void:
	for slot in slots_container.get_children():
		if slot is EquipmentSlot:
			slot.refresh(slot.current_level)
