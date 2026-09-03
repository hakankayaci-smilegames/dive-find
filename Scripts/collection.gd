extends CanvasLayer
## Koleksiyon Defteri: eşya listesini artık kendi taramıyor, GlobalInventory.get_all_items()
## önbelleğini kullanıyor (ilk tarama loading_screen sırasında zaten yapılmış oluyor,
## burada donma olmaz).

@export var slot_scene: PackedScene  # res://Scenes/collection_slot.tscn
@export var popup_scene: PackedScene = preload("res://Scenes/pickup.tscn")

@onready var grid_container: GridContainer = $MainPanel/ScrollContainer/GridContainer
@onready var close_button: Button = $MainPanel/CloseButton
@onready var progress_label: Label = $MainPanel/ProgressLabel
@onready var progress_bar: ProgressBar = $MainPanel/ProgressBar
@onready var progress_bar_text: Label = $MainPanel/ProgressBar/ProgressBarText


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ofis pause'ken de çalışsın
	close_button.pressed.connect(queue_free)
	_populate_grid()

	if GlobalInventory.has_signal("collection_updated"):
		GlobalInventory.collection_updated.connect(_populate_grid)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_E, KEY_I, KEY_TAB, KEY_C:
				queue_free()
				get_viewport().set_input_as_handled()


func _populate_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	if not slot_scene:
		push_warning("Koleksiyon: slot_scene atanmamış!")
		return

	var all_items := GlobalInventory.get_all_items()
	var discovered_count := 0
	for item in all_items:
		var slot = slot_scene.instantiate() as CollectionSlot
		grid_container.add_child(slot)
		var is_discovered: bool = GlobalInventory.discovered_items.has(item.resource_path)
		if is_discovered:
			discovered_count += 1
		slot.setup(item, is_discovered)
		slot.slot_clicked.connect(_on_slot_clicked)

	var total := all_items.size()
	if progress_label:
		progress_label.text = "Keşfedilen: %d / %d" % [discovered_count, total]
	if progress_bar:
		progress_bar.max_value = max(total, 1)
		progress_bar.value = discovered_count
	if progress_bar_text:
		progress_bar_text.text = "%d / %d" % [discovered_count, total]


func _on_slot_clicked(item: ItemData) -> void:
	if not popup_scene or not item:
		return

	GlobalSoundManager.play_sfx("click")
	var popup = popup_scene.instantiate()
	get_tree().current_scene.add_child(popup)
	popup.setup(item, null, true)
