extends CanvasLayer

@export var inventory_scene: PackedScene
@export var equstore_scene: PackedScene
@export var antikaci_scene: PackedScene
@export var kara_borsa_scene: PackedScene
@export var copcu_scene: PackedScene
@export var collection_scene: PackedScene
@export var day_summary_scene: PackedScene = preload("res://Scenes/day_summary.tscn")

@export_group("Görsel & Ses")
@export var main_menu_scene_path: String = "res://Scenes/main_menu.tscn"

@export_group("Oyuna Dönüş")
@export var teleport_player_on_close: bool = true
@export var ocean_spawn_x: float = 16.0          # Ofisten çıkınca oyuncunun x konumu (dalış noktası)
@export var spawn_above_surface_px: float = 60.0  # Su yüzeyinin hemen azıcık üstünden suya giriş
@export var spawn_fall_speed: float = 450.0       # Hızlı düşüş hızı

# Referanslar (UI)
@onready var zurna_label: Label = %ZurnaLabel
@onready var day_label: Label = %DayLabel
@onready var advance_day_button: Button = %AdvanceDayButton
@onready var save_exit_button: Button = %SaveExitButton

# Satıcı Butonları
@onready var copcu_button: Button = %CopcuButton
@onready var antikaci_button: Button = %AntikaciButton
@onready var kara_borsa_button: Button = %KaraBorsaButton

# Tesis Butonları
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

var _active_collection: Node = null
var _active_inventory: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var time_mgr: Node = _get_time_mgr()
	if time_mgr:
		time_mgr.time_changed.connect(_on_time_changed)
		time_mgr.day_changed.connect(_on_day_changed)
		time_mgr.dive_lock_changed.connect(_on_dive_lock_changed)
		_current_day = int(time_mgr.get("current_day"))
	else:
		var save_data: Dictionary = GlobalInventory.get_save_data()
		if not save_data.is_empty():
			_current_day = int(save_data.get("current_day", 1))

	# Bakiye ve Gün Göstergeleri
	GlobalEconomy.money_changed.connect(_on_money_changed)
	_refresh_wallet()
	_refresh_day()
	_update_dive_button_state()

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
	if not day_label:
		return
	var time_mgr: Node = _get_time_mgr()
	if time_mgr:
		day_label.text = "Gün: %d  |  ⏰ %s" % [int(time_mgr.get("current_day")), time_mgr.get_time_string()]
	else:
		day_label.text = "Gün: %d" % _current_day


func _on_time_changed(_h: int, _m: int) -> void:
	_refresh_day()
	_update_dive_button_state()


func _on_day_changed(_d: int) -> void:
	_refresh_day()
	_update_dive_button_state()


func _on_dive_lock_changed(_locked: bool) -> void:
	_update_dive_button_state()


func _update_dive_button_state() -> void:
	if not is_instance_valid(dive_button):
		return

	var is_allowed := true
	var time_mgr: Node = _get_time_mgr()
	if time_mgr:
		is_allowed = time_mgr.is_dive_allowed()

	dive_button.disabled = not is_allowed
	if not is_allowed:
		dive_button.text = "🤿 DALIŞ KAPALI (HAVA KARARDI)"
		if is_instance_valid(advance_day_button):
			advance_day_button.text = "GÜNÜ BİTİR & İLERLET ☀️"
	else:
		dive_button.text = "🤿 DALIŞA BAŞLA / OKYANUS [ESC]"
		if is_instance_valid(advance_day_button):
			advance_day_button.text = "GÜNÜ İLERLET ☀️"


func _on_advance_day_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	var time_mgr: Node = _get_time_mgr()
	var is_allowed: bool = time_mgr.is_dive_allowed() if time_mgr else false

	if is_allowed:
		_show_early_end_confirmation(time_mgr.get_time_string() if time_mgr else "10:00")
	else:
		_proceed_to_day_summary()


func _proceed_to_day_summary() -> void:
	if day_summary_scene:
		var summary_instance = day_summary_scene.instantiate()
		summary_instance.new_day_started.connect(_on_new_day_started)
		add_child(summary_instance)
	else:
		var time_mgr: Node = _get_time_mgr()
		if time_mgr:
			time_mgr.start_new_day()
		_on_new_day_started()


func _show_early_end_confirmation(time_str: String) -> void:
	var confirm_layer := CanvasLayer.new()
	confirm_layer.layer = 125

	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.75)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	confirm_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 230)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.85, 0.75, 0.45, 1.0)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "⚠️ MESAYİ HENÜZ BİTMEDİ!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Hava kararmadı, dalış yapacak vaktin var! (Saat: %s)\nŞimdi günü bitirirsen mesai kapanacak ve yeni güne geçilecek.\n\nGünü erken sonlandırmak istediğinden emin misin?" % time_str
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	desc.add_theme_font_size_override("font_size", 14)
	vbox.add_child(desc)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var cancel_btn := Button.new()
	cancel_btn.text = "DALIŞA DEVAM ET"
	cancel_btn.custom_minimum_size = Vector2(170, 42)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.25, 0.2, 0.18, 1.0)
	cancel_style.border_color = Color(0.5, 0.4, 0.3, 1.0)
	cancel_style.set_border_width_all(2)
	cancel_style.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.pressed.connect(func():
		GlobalSoundManager.play_sfx("click")
		confirm_layer.queue_free()
	)
	hbox.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "EVET, GÜNÜ BİTİR ☀️"
	confirm_btn.custom_minimum_size = Vector2(170, 42)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.85, 0.75, 0.45, 1.0)
	confirm_style.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.add_theme_color_override("font_color", Color(0.15, 0.1, 0.06, 1.0))
	confirm_btn.pressed.connect(func():
		GlobalSoundManager.play_sfx("click")
		confirm_layer.queue_free()
		_proceed_to_day_summary()
	)
	hbox.add_child(confirm_btn)

	add_child(confirm_layer)


func _on_new_day_started() -> void:
	_refresh_day()
	_update_dive_button_state()
	var time_mgr: Node = _get_time_mgr()
	var cur_day: int = int(time_mgr.get("current_day")) if time_mgr else _current_day
	_show_toast("☀️ Yeni gün başladı! (Gün %d)" % cur_day)


func _on_money_changed(_amount: int) -> void:
	_refresh_wallet()


func _on_save_exit_pressed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var equipment_dict: Dictionary = {
		"tube_level": int(player.get("tube_level")) if player else 1,
		"fins_level": int(player.get("fins_level")) if player else 0,
		"goggles_level": int(player.get("goggles_level")) if player else 0,
		"backpack_level": int(player.get("backpack_level")) if player else 0
	}
	var time_mgr: Node = _get_time_mgr()
	var save_day: int = int(time_mgr.get("current_day")) if time_mgr else _current_day
	GlobalInventory.save_game(save_day, GlobalEconomy.money, equipment_dict)
	GlobalSoundManager.play_sfx("door")
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_dive_pressed() -> void:
	var time_mgr: Node = _get_time_mgr()
	if time_mgr and not time_mgr.is_dive_allowed():
		GlobalSoundManager.play_sfx("error")
		_show_toast("⚠️ Hava karardı (19:00+). Yeni dalış için günü ilerletmelisiniz!")
		return

	GlobalSoundManager.play_sfx("door_close")

	if time_mgr:
		time_mgr.record_dive()
		time_mgr.start_clock()

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
	if is_instance_valid(_active_inventory):
		_active_inventory.queue_free()
		_active_inventory = null
		GlobalSoundManager.play_sfx("click")
		return
	if not inventory_scene:
		push_warning("OfficeMenu: inventory_scene atanmamış!")
		return
	GlobalSoundManager.play_sfx("click")
	_active_inventory = inventory_scene.instantiate()
	get_tree().current_scene.add_child(_active_inventory)


func _open_koleksiyon() -> void:
	if is_instance_valid(_active_collection):
		_active_collection.queue_free()
		_active_collection = null
		GlobalSoundManager.play_sfx("click")
		return
	if not collection_scene:
		push_warning("OfficeMenu: collection_scene atanmamış!")
		return
	GlobalSoundManager.play_sfx("click")
	_active_collection = collection_scene.instantiate()
	get_tree().current_scene.add_child(_active_collection)


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


func _get_time_mgr() -> Node:
	return get_node_or_null("/root/GlobalTime")
