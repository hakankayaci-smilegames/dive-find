extends CanvasLayer
## Oyun Bitti mesaj kutusu (oyuncu boğulduğunda).
## player_controller.gd can sıfırlandığında bu sahneyi açar; oyunu duraklatır,
## mevcut envanteri siler ve TAMAM'a basınca oyuncuyu ofis menüsüne gönderir.

const DOCK_SHACK_SCENE_PATH := "res://Scenes/dock_shack.tscn"
const OFFICE_SCENE_PATH := "res://Scenes/dock_shack.tscn"

@onready var ok_button: Button = $Background/Panel/OkButton
@onready var title_label: Label = $Background/Panel/TitleLabel
@onready var message_label: Label = $Background/Panel/MessageLabel


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS  # Oyun duraklatılmışken de mesaj kutusu çalışsın
	get_tree().paused = true

	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_en:
		title_label.text = "YOU DROWNED"
		message_label.text = "You ran out of oxygen and couldn't reach the surface. A passing fisherman rescued you, but when you woke up, your bag was gone.\nPress OK to continue, you will be sent back to the dock shack."
		ok_button.text = "OK"
	else:
		title_label.text = "BOĞULDUN"
		message_label.text = "Oksijen tüpün bitti ve yüzeye ulaşamadın, yandan geçen bir balıkçı seni buldu ve kurtardı ancak uyandığında çantan yoktu.\nDevam etmek için TAMAM'a bas, iskele barakasına geri gönderileceksin."
		ok_button.text = "TAMAM"

	# Oyuncunun mevcut envanteri tamamen silinir (koleksiyon defteri keşifleri kalıcıdır).
	GlobalInventory.clear_inventory()

	ok_button.pressed.connect(_on_ok_pressed)


func _on_ok_pressed() -> void:
	GlobalSoundManager.play_sfx("door_open")

	# Can, oksijen ve durumu sıfırla/yenile
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var max_hp = player.get("max_health")
		player.set("current_health", max_hp if max_hp != null else 100.0)
		var max_ox = player.get("max_oxygen")
		player.set("current_oxygen", max_ox if max_ox != null else 100.0)
		player.set("velocity", Vector2.ZERO)
		player.set("_game_over_triggered", false)
		if player.has_method("reset_flashlight_for_office"):
			player.reset_flashlight_for_office()

	var shack_scene: PackedScene = load(DOCK_SHACK_SCENE_PATH)
	if shack_scene:
		get_tree().current_scene.add_child(shack_scene.instantiate())

	queue_free()

