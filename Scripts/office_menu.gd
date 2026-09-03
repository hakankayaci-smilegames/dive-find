extends CanvasLayer

@export var inventory_scene: PackedScene
@export var equstore_scene: PackedScene
@export var antikaci_scene: PackedScene
@export var kara_borsa_scene: PackedScene
@export var copcu_scene: PackedScene
@export var collection_scene: PackedScene
@export_file("*.tscn") var main_menu_scene_path: String = "res://Scenes/main_menu.tscn"

@export_group("Oyuna Dönüş")
@export var teleport_player_on_close: bool = true
@export var ocean_spawn_x: float = 16.0          # Ofisten çıkınca oyuncunun x konumu (dalış noktası)
@export var spawn_above_surface_px: float = 60.0  # Su yüzeyinin hemen azıcık üstünden suya giriş
@export var spawn_fall_speed: float = 450.0       # Hızlı düşüş hızı

# Üst Bar
@onready var zurna_label: Label = %ZurnaLabel
@onready var day_label: Label = %DayLabel
@onready var advance_day_button: Button = %AdvanceDayButton
@onready var save_exit_button: Button = %SaveExitButton

# Üst Satıcı Kartları
@onready var copcu_button: Button = %CopcuButton
@onready var antikaci_button: Button = %AntikaciButton
@onready var kara_borsa_button: Button = %KaraBorsaButton

# Alt Tesis Kartları (Soldan Sağa: Ekipman, Lab, Dükkan)
@onready var equstore_button: Button = %EquStoreButton
@onready var lab_button: Button = %LabButton
@onready var shop_button: Button = %ShopButton

# Alt Bar Butonları
@onready var envanter_button: Button = %EnvanterButton
@onready var koleksiyon_button: Button = %KoleksiyonButton
@onready var dive_button: Button = %DiveButton
@onready var toast_label: Label = %ToastLabel

var _toast_tween: Tween = null


var _current_day: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var save_data: Dictionary = GlobalInventory.get_save_data()
	if not save_data.is_empty():
		_current_day = int(save_data.get("current_day", 1))

	# Bakiye ve Gün Göstergeleri
	GlobalEconomy.money_changed.connect(_on_money_changed)
	_refresh_wallet()
	_refresh_day()

	# Üst Bar Bağlantıları
	save_exit_button.pressed.connect(_on_save_exit_pressed)
	advance_day_button.pressed.connect(_on_advance_day_pressed)

	# Satıcı Butonları
	copcu_button.pressed.connect(_open_copcu)
	antikaci_button.pressed.connect(_open_antikaci)
	kara_borsa_button.pressed.connect(_open_kara_borsa)

	# Tesis Butonları
	equstore_button.pressed.connect(_open_equstore)
	lab_button.pressed.connect(_on_lab_pressed)
	shop_button.pressed.connect(_on_shop_pressed)

	# Alt Bar Butonları
	envanter_button.pressed.connect(_open_envanter)
	koleksiyon_button.pressed.connect(_open_koleksiyon)
	dive_button.pressed.connect(_on_dive_pressed)

	if toast_label:
		toast_label.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_on_dive_pressed()
				get_viewport().set_input_as_handled()
			KEY_I:
				_open_envanter()
				get_viewport().set_input_as_handled()
			KEY_C:
				_open_koleksiyon()
				get_viewport().set_input_as_handled()


func _refresh_wallet() -> void:
	if zurna_label:
		zurna_label.text = "%d Zurna" % GlobalEconomy.money


func _refresh_day() -> void:
	if day_label:
		day_label.text = "Gün: %d" % _current_day


func _on_money_changed(_amount: int) -> void:
	_refresh_wallet()


func _on_advance_day_pressed() -> void:
	_current_day += 1
	_refresh_day()
	GlobalSoundManager.play_sfx("click")
	_show_toast("Gün ilerletildi! (Gün %d)" % _current_day)


func _on_save_exit_pressed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var equipment_dict: Dictionary = {
		"tube_level": int(player.get("tube_level")) if player else 1,
		"fins_level": int(player.get("fins_level")) if player else 0,
		"goggles_level": int(player.get("goggles_level")) if player else 0,
		"backpack_level": int(player.get("backpack_level")) if player else 0
	}
	GlobalInventory.save_game(_current_day, GlobalEconomy.money, equipment_dict)
	GlobalSoundManager.play_sfx("door")
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_dive_pressed() -> void:
	GlobalSoundManager.play_sfx("door_close")
	if teleport_player_on_close:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var spawn_y = InfiniteMapManager.water_surface_y - spawn_above_surface_px
			player.set("global_position", Vector2(ocean_spawn_x, spawn_y))
			player.set("velocity", Vector2(0, spawn_fall_speed))
			player.set("current_oxygen", 100.0)
			player.set("current_health", 100.0)
	get_tree().paused = false
	queue_free()


func _exit_tree() -> void:
	get_tree().paused = false
	if GlobalEconomy.money_changed.is_connected(_on_money_changed):
		GlobalEconomy.money_changed.disconnect(_on_money_changed)


# ------------------------------------------------------------------
# SAHNE AÇICILAR
# ------------------------------------------------------------------

func _open_popup(scene: PackedScene) -> void:
	if not scene:
		push_warning("OfficeMenu: Açılmak istenen sahne atanmamış!")
		return
	GlobalSoundManager.play_sfx("click")
	get_tree().current_scene.add_child(scene.instantiate())


func _open_copcu() -> void:
	_open_popup(copcu_scene)


func _open_antikaci() -> void:
	_open_popup(antikaci_scene)


func _open_kara_borsa() -> void:
	_open_popup(kara_borsa_scene)


func _open_equstore() -> void:
	_open_popup(equstore_scene)


func _open_envanter() -> void:
	_open_popup(inventory_scene)


func _open_koleksiyon() -> void:
	_open_popup(collection_scene)


func _on_lab_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	_show_toast("🧪 Laboratuvar (Crafting Sistemi) Çok Yakında!")


func _on_shop_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	_show_toast("📦 Satış Pazarı (Üretilen Eşyalar) Çok Yakında!")


func _show_toast(msg: String) -> void:
	if not toast_label:
		return
	toast_label.text = msg
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	toast_label.modulate.a = 0.0
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
