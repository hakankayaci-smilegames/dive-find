extends CanvasLayer

signal new_day_started

@export var loading_scene: PackedScene = preload("res://Scenes/loading_screen.tscn")

@onready var day_title: Label = %DayTitle
@onready var earnings_label: Label = %EarningsLabel
@onready var dives_label: Label = %DivesLabel
@onready var items_sold_label: Label = %ItemsSoldLabel
@onready var max_depth_label: Label = %MaxDepthLabel
@onready var closing_time_label: Label = %ClosingTimeLabel
@onready var bag_status_label: Label = %BagStatusLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	continue_button.pressed.connect(_on_continue_pressed)
	_populate_summary()


func _populate_summary() -> void:
	var time_mgr: Node = _get_time_mgr()
	var data: Dictionary = time_mgr.get_summary_data() if time_mgr else {}

	day_title.text = "GÜN %d TAMAMLANDI" % int(data.get("day", 1))
	earnings_label.text = "+%d Zurna" % int(data.get("earnings", 0))
	dives_label.text = "%d Dalış" % int(data.get("dives", 0))
	items_sold_label.text = "%d Adet" % int(data.get("items_sold", 0))
	max_depth_label.text = "%d m" % int(data.get("max_depth", 0))
	closing_time_label.text = str(data.get("closing_time", "19:00"))

	var bag_count: int = GlobalInventory.collected_items.size()
	var bag_capacity: int = GlobalInventory.get_capacity()
	bag_status_label.text = "%d / %d Eşya" % [bag_count, bag_capacity]


func _on_continue_pressed() -> void:
	GlobalSoundManager.play_sfx("click")

	var time_mgr: Node = _get_time_mgr()
	if time_mgr:
		time_mgr.start_new_day()

	# 2. Otomatik Kayıt Al
	var player = get_tree().get_first_node_in_group("player")
	var equipment_dict: Dictionary = {
		"tube_level": int(player.get("tube_level")) if player else 1,
		"fins_level": int(player.get("fins_level")) if player else 0,
		"goggles_level": int(player.get("goggles_level")) if player else 0,
		"backpack_level": int(player.get("backpack_level")) if player else 0,
		"flashlight_level": int(player.get("flashlight_level")) if player else 0
	}
	var current_day_num: int = int(time_mgr.get("current_day")) if time_mgr else 1
	GlobalInventory.save_game(current_day_num, GlobalEconomy.money, equipment_dict)

	# 3. Havalı Yükleme Ekranı (Loading Screen)
	if loading_scene:
		visible = false # Gün özetini gizle
		var loading_inst = loading_scene.instantiate()
		loading_inst.auto_change_scene = false
		loading_inst.duration = 1.6 # 1.6 saniye tatlı bir geçiş
		var layer := CanvasLayer.new()
		layer.layer = 130
		layer.add_child(loading_inst)
		get_tree().current_scene.add_child(layer)

		loading_inst.finished.connect(func():
			layer.queue_free()
			new_day_started.emit()
			queue_free()
		)
	else:
		new_day_started.emit()
		queue_free()


func _get_time_mgr() -> Node:
	return get_node_or_null("/root/GlobalTime")
