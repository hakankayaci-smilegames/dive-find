extends CanvasLayer
## Oyun Bitti mesaj kutusu (oyuncu boğulduğunda).
## player_controller.gd can sıfırlandığında bu sahneyi açar; oyunu duraklatır,
## mevcut envanteri siler ve TAMAM'a basınca oyuncuyu ofis menüsüne gönderir.

const OFFICE_SCENE_PATH := "res://Scenes/office_menu.tscn"

@onready var ok_button: Button = $Background/Panel/OkButton
@onready var title_label: Label = $Background/Panel/TitleLabel
@onready var message_label: Label = $Background/Panel/MessageLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Oyun duraklatılmışken de mesaj kutusu çalışsın
	get_tree().paused = true

	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_en:
		title_label.text = "YOU DROWNED"
		message_label.text = "You ran out of oxygen and couldn't reach the surface. A passing fisherman rescued you, but when you woke up, your bag was gone.\nPress OK to continue, you will be sent back to the office."
		ok_button.text = "OK"

	# Oyuncunun mevcut envanteri tamamen silinir (koleksiyon defteri keşifleri kalıcıdır).
	GlobalInventory.clear_inventory()

	ok_button.pressed.connect(_on_ok_pressed)


func _on_ok_pressed() -> void:
	get_tree().paused = false
	GlobalSoundManager.play_sfx("door")

	var office_scene: PackedScene = load(OFFICE_SCENE_PATH)
	if office_scene:
		get_tree().current_scene.add_child(office_scene.instantiate())
	queue_free()
