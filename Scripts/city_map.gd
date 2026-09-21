class_name CityMap
extends CanvasLayer

# Sahne Ön Yüklemeleri
@export var inventory_scene: PackedScene = preload("res://Scenes/inventory.tscn")
@export var collection_scene: PackedScene = preload("res://Scenes/collection.tscn")
@export var settings_scene: PackedScene = preload("res://Scenes/settings_menu.tscn")
@export var day_summary_scene: PackedScene = preload("res://Scenes/day_summary.tscn")
@export var copcu_scene: PackedScene = preload("res://Scenes/copcu.tscn")
@export var antikaci_scene: PackedScene = preload("res://Scenes/antikaci.tscn")
@export var kara_borsa_scene: PackedScene = preload("res://Scenes/kara_borsa.tscn")
@export var equstore_scene: PackedScene = preload("res://Scenes/equstore.tscn")
@export var lab_scene: PackedScene = preload("res://Scenes/laboratory.tscn")
@export var pazar_scene: PackedScene = preload("res://Scenes/pazar.tscn")
@export var charge_station_scene: PackedScene = preload("res://Scenes/charge_station.tscn")
var dock_shack_scene: PackedScene = null
@export var loading_scene: PackedScene = preload("res://Scenes/loading_screen.tscn")

# HUD & Referanslar
@onready var map_texture: TextureRect = $MapContainer/MapContent/MapTexture
@onready var location_badge: Label = %LocationBadge
@onready var zurna_label: Label = %ZurnaLabel
@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var advance_day_button: Button = %AdvanceDayButton
@onready var inventory_button: Button = %InventoryButton
@onready var collection_button: Button = %CollectionButton
@onready var settings_button: Button = %SettingsButton
@onready var close_button: Button = %CloseButton
@onready var sub_menu_container: Control = %SubMenuContainer
@onready var toast_banner: PanelContainer = %ToastBanner
@onready var toast_label: Label = %ToastLabel
@onready var pins_holder: Control = %PinsHolder

# Zenginleştirilmiş Saat Başı / Yarım Saatlik Renk Anahtarları (Dakika -> Renk)
const TIME_PALETTE: Array[Dictionary] = [
	{"min": 360, "color": Color(0.20, 0.22, 0.38)},  # 06:00 - Gece sonu / Soğuk Alacakaranlık
	{"min": 420, "color": Color(0.40, 0.38, 0.50)},  # 07:00 - Erken Şafak (Hafif mor-gri)
	{"min": 480, "color": Color(0.70, 0.65, 0.65)},  # 08:00 - Sabah Sisi (Yumuşak pembe-altın)
	{"min": 540, "color": Color(0.90, 0.88, 0.85)},  # 09:00 - Sabah Güneşi Açılışı
	{"min": 600, "color": Color(1.00, 1.00, 1.00)},  # 10:00 - Tam Gündüz / Mesai Başlangıcı (Berrak Beyaz)
	{"min": 690, "color": Color(1.00, 0.98, 0.94)},  # 11:30 - Öğle Öncesi Sıcak Işık
	{"min": 780, "color": Color(0.98, 0.92, 0.82)},  # 13:00 - Öğle Sonrası Kehribar Isınması
	{"min": 870, "color": Color(0.92, 0.78, 0.62)},  # 14:30 - İkindiye Giriş
	{"min": 960, "color": Color(0.85, 0.65, 0.44)},  # 16:00 - Altın Saat (Belirgin Turuncu-Altın)
	{"min": 1020, "color": Color(0.72, 0.50, 0.45)}, # 17:00 - Gün Batımı (Kızıl / Sıcak Gün Batımı)
	{"min": 1080, "color": Color(0.50, 0.40, 0.55)}, # 18:00 - Alacakaranlık (Mor-Mavi, Sokak Lambaları Yanar)
	{"min": 1140, "color": Color(0.32, 0.32, 0.52)}, # 19:00 - Mesai Bitişi (Koyu Akşam / Lacivert)
	{"min": 1200, "color": Color(0.24, 0.25, 0.44)}, # 20:00 - Akşam / Gece Başlangıcı
	{"min": 1260, "color": Color(0.18, 0.20, 0.36)}, # 21:00 - Koyu Gece
	{"min": 1380, "color": Color(0.15, 0.17, 0.32)}  # 23:00 - Zifiri Ay Işığı Gecesi
]

var _active_sub_menu: Node = null
var _displayed_money: int = 0
var _money_tween: Tween = null
var _toast_tween: Tween = null
var _light_tween: Tween = null
var _current_day: int = 1
var _is_transitioning: bool = false

# Animasyonlu Arkaplan Ayarları (12 FPS - 120 Kare)
const ANIM_FRAME_COUNT: int = 120
const ANIM_FPS: float = 12.0
const ANIM_FRAME_TIME: float = 1.0 / ANIM_FPS
const ANIM_PATH_PATTERN: String = "res://Sprites/map_anim/frame_%04d.png"

static var _cached_map_frames: Array[Texture2D] = []
static var city_map_packed: PackedScene = null
var _anim_timer: float = 0.0
var _current_frame_idx: int = 0

# Şehir Ambiyans Sesi
@export var ambient_stream: AudioStream = preload("res://Sounds/map_ambient.ogg")
@export var ambient_target_volume_db: float = -4.0
var _ambient_player: AudioStreamPlayer = null
var _ambient_tween: Tween = null
var _initial_location_text: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	get_tree().paused = true

	add_to_group("city_map")
	add_to_group("popup_ui")
	add_to_group("hub_menu")

	if is_instance_valid(location_badge):
		_initial_location_text = location_badge.text

	# Bakiye ve Zaman
	_displayed_money = GlobalEconomy.money
	GlobalEconomy.money_changed.connect(_on_money_changed)
	GlobalInventory.inventory_updated.connect(_on_inventory_updated)

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

	# Buton Bağlantıları
	close_button.pressed.connect(_on_close_pressed)
	advance_day_button.pressed.connect(_on_advance_day_pressed)
	inventory_button.pressed.connect(_toggle_inventory)
	collection_button.pressed.connect(_toggle_collection)
	settings_button.pressed.connect(_open_settings)

	# Buton Suyu (Juice)
	for btn in [close_button, advance_day_button, inventory_button, collection_button, settings_button]:
		_setup_button_juice(btn)

	# Pin bağlantılarını kur
	_connect_pins()

	# Toast başlangıç
	if is_instance_valid(toast_banner):
		toast_banner.modulate.a = 0.0
		toast_banner.visible = false

	# Giriş solması (fade-in)
	if has_node("Background"):
		$Background.modulate.a = 0.0
		var fade_in := create_tween()
		fade_in.tween_property($Background, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Saat bazlı ışıklandırmayı haritaya uygula
	_update_map_lighting(false)

	# Animasyon karelerini hazırla
	_init_map_animation()

	# Şehir ambiyans sesini başlat (SFX Bus, yumuşak fade-in)
	_start_ambient_audio()

	refresh_ui()


func _exit_tree() -> void:
	remove_from_group("hub_menu")
	_stop_ambient_audio(0.0)
	if not _is_transitioning:
		get_tree().paused = false


func _process(delta: float) -> void:
	if _cached_map_frames.is_empty() or not is_instance_valid(map_texture):
		return
	_anim_timer += delta
	if _anim_timer >= ANIM_FRAME_TIME:
		var frames_to_advance: int = int(_anim_timer / ANIM_FRAME_TIME)
		_anim_timer -= frames_to_advance * ANIM_FRAME_TIME
		_current_frame_idx = (_current_frame_idx + frames_to_advance) % _cached_map_frames.size()
		map_texture.texture = _cached_map_frames[_current_frame_idx]


func _connect_pins() -> void:
	if not is_instance_valid(pins_holder):
		return

	for child in pins_holder.get_children():
		if child is MapPin:
			if not child.pin_clicked.is_connected(_on_pin_clicked):
				child.pin_clicked.connect(_on_pin_clicked)


func _on_pin_clicked(pin: MapPin) -> void:
	if _is_transitioning:
		return

	# Özel aksiyon kontrolü
	if pin.target_action == "shack_dive":
		_handle_dock_action()
		return
	elif pin.target_action == "charge_station":
		_open_charge_station()
		return

	if pin.target_scene:
		_play_micro_transition(func() -> void:
			if is_instance_valid(_active_sub_menu):
				_active_sub_menu.queue_free()
				_active_sub_menu = null
			_open_sub_scene(pin.target_scene)
		)
	else:
		_show_toast(pin.get_display_title() + " - Yakında!")


func _handle_dock_action() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	GlobalSoundManager.play_sfx("door_close")
	_stop_ambient_audio(0.6)

	# Ortam geçişi: Şehir Haritası -> Liman Barakası (Loading Screen ile)
	_play_transition(func() -> void:
		var scene: PackedScene = dock_shack_scene if dock_shack_scene else load("res://Scenes/dock_shack.tscn")
		if scene:
			var shack = scene.instantiate()
			get_tree().current_scene.add_child(shack)
		queue_free()
	, 1.0)


func _open_charge_station() -> void:
	if _is_transitioning:
		return
	var flash_lvl: int = GlobalInventory.get_equipment_stat("flashlight_level", 0) if GlobalInventory.has_method("get_equipment_stat") else 0
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if flash_lvl <= 0:
		GlobalSoundManager.play_sfx("error")
		_show_toast("⚠️ No flashlight! Buy one from Equipment Shop first." if is_en else "⚠️ Fenerin yok! Önce Ekipman Mağazasından satın al.")
		return

	if charge_station_scene:
		_play_micro_transition(func() -> void:
			if is_instance_valid(_active_sub_menu):
				_active_sub_menu.queue_free()
				_active_sub_menu = null
			_open_sub_scene(charge_station_scene)
		)


func _open_sub_scene(scene: PackedScene) -> void:
	if not scene:
		return

	var inst: Node = scene.instantiate()
	_active_sub_menu = inst

	# Tam ekran kontrolü: Alt sahne açıldığında sub_menu_container içerisine veya CanvasLayer olarak eklenir
	if inst is CanvasLayer:
		inst.layer = 90
		add_child(inst)
	else:
		sub_menu_container.add_child(inst)

	inst.tree_exited.connect(func() -> void:
		_active_sub_menu = null
		refresh_ui()
	)


func _toggle_inventory() -> void:
	GlobalSoundManager.play_sfx("click")
	if is_instance_valid(_active_sub_menu) and _active_sub_menu.is_in_group("inventory"):
		_active_sub_menu.queue_free()
		_active_sub_menu = null
		return

	if inventory_scene:
		_open_sub_scene(inventory_scene)


func _toggle_collection() -> void:
	GlobalSoundManager.play_sfx("click")
	if is_instance_valid(_active_sub_menu) and _active_sub_menu.is_in_group("collection_book"):
		_active_sub_menu.queue_free()
		_active_sub_menu = null
		return

	if collection_scene:
		_open_sub_scene(collection_scene)


func _open_settings() -> void:
	GlobalSoundManager.play_sfx("click")
	if settings_scene:
		_open_sub_scene(settings_scene)


func _on_close_pressed() -> void:
	if is_instance_valid(_active_sub_menu):
		_active_sub_menu.queue_free()
		_active_sub_menu = null
		return

	if _is_transitioning:
		return
	_is_transitioning = true
	GlobalSoundManager.play_sfx("door_close")
	_stop_ambient_audio(0.6)

	# 1. Otomatik Kaydet (Açıksa)
	if GlobalInventory.is_autosave_enabled():
		var time_mgr: Node = _get_time_mgr()
		var save_day: int = int(time_mgr.get("current_day")) if time_mgr else _current_day
		var player = get_tree().get_first_node_in_group("player")
		var equipment_dict := {
			"backpack_level": GlobalInventory.get_equipment_stat("backpack_level", 0),
			"tube_level": GlobalInventory.get_equipment_stat("tube_level", 1),
			"goggles_level": GlobalInventory.get_equipment_stat("goggles_level", 0),
			"fins_level": GlobalInventory.get_equipment_stat("fins_level", 0),
			"flashlight_level": GlobalInventory.get_equipment_stat("flashlight_level", 0),
			"current_battery": float(player.get("current_battery")) if (player and player.get("current_battery") != null) else float(GlobalInventory.equipment_data.get("current_battery", -1.0))
		}
		GlobalInventory.save_game(save_day, GlobalEconomy.money, equipment_dict)

	# 2. Ortam Geçişi: Şehir Haritası -> Ana Menü (Loading Screen ile)
	_play_transition(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	, 1.0)


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
		var summary = day_summary_scene.instantiate()
		summary.new_day_started.connect(func() -> void:
			var time_mgr: Node = _get_time_mgr()
			if time_mgr:
				_current_day = int(time_mgr.get("current_day"))
			refresh_ui()
			_update_map_lighting(true)
		)
		add_child(summary)
	else:
		var time_mgr: Node = _get_time_mgr()
		if time_mgr:
			time_mgr.start_new_day()
			_current_day = int(time_mgr.get("current_day"))
		refresh_ui()
		_update_map_lighting(true)


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

	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "⚠️ SHIFT HAS NOT ENDED YET!" if is_en else "⚠️ MESAYİ HENÜZ BİTMEDİ!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var desc := Label.new()
	if is_en:
		desc.text = "It is not dark yet, you still have time to dive! (Time: %s)\nEnding the day now will close your shift and proceed to the next day.\n\nAre you sure you want to end the day early?" % time_str
	else:
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
	cancel_btn.text = "CANCEL" if is_en else "İPTAL"
	cancel_btn.custom_minimum_size = Vector2(160, 42)
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
	confirm_btn.text = "YES, END DAY ☀️" if is_en else "EVET, GÜNÜ BİTİR ☀️"
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


func refresh_ui() -> void:
	# Üst Bar
	if is_instance_valid(location_badge):
		location_badge.text = tr(_initial_location_text)
	if is_instance_valid(zurna_label):
		zurna_label.text = tr("💰 %d Zurna") % _displayed_money
	if is_instance_valid(day_label):
		day_label.text = tr("📅 GÜN %d") % _current_day
	if is_instance_valid(advance_day_button):
		advance_day_button.text = tr("⏭️ DİNLEN / İLERLET")
	if is_instance_valid(inventory_button):
		var count: int = GlobalInventory.collected_items.size()
		var cap: int = GlobalInventory.get_capacity()
		inventory_button.text = tr("🎒 ÇANTA (%d/%d)") % [count, cap]
	if is_instance_valid(collection_button):
		collection_button.text = tr("📖 KOLEKSİYON")
	if is_instance_valid(close_button):
		close_button.text = tr("🚪 HARİTADAN ÇIK")

	# Saat
	var time_mgr: Node = _get_time_mgr()
	if time_mgr and is_instance_valid(time_label):
		time_label.text = "⏰ " + time_mgr.get_time_string()

	# Pinleri güncelle
	if is_instance_valid(pins_holder):
		for child in pins_holder.get_children():
			if child is MapPin:
				child.refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(_active_sub_menu):
				_active_sub_menu.queue_free()
				_active_sub_menu = null
				get_viewport().set_input_as_handled()
				refresh_ui()
				return
			else:
				_on_close_pressed()
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_I:
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_C:
			_toggle_collection()
			get_viewport().set_input_as_handled()
			return


func _on_money_changed(target_val: Variant) -> void:
	var target_amount: int = int(target_val)
	if _money_tween and _money_tween.is_valid():
		_money_tween.kill()

	var start_amount: int = _displayed_money
	_money_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_money_tween.tween_method(func(val: int) -> void:
		_displayed_money = val
		if is_instance_valid(zurna_label):
			zurna_label.text = "💰 %d Zurna" % val
	, start_amount, target_amount, 0.4)


func _on_inventory_updated() -> void:
	refresh_ui()


func _on_time_changed(_h: int = 0, _m: int = 0) -> void:
	var time_mgr: Node = _get_time_mgr()
	if time_mgr and is_instance_valid(time_label):
		time_label.text = "⏰ " + time_mgr.get_time_string()
	_update_map_lighting(true)


func _calculate_time_color(total_min: float) -> Color:
	if total_min <= TIME_PALETTE[0]["min"]:
		return TIME_PALETTE[0]["color"]
	if total_min >= TIME_PALETTE[-1]["min"]:
		return TIME_PALETTE[-1]["color"]

	for i in range(TIME_PALETTE.size() - 1):
		var m1: float = float(TIME_PALETTE[i]["min"])
		var m2: float = float(TIME_PALETTE[i + 1]["min"])
		if total_min >= m1 and total_min <= m2:
			var t: float = (total_min - m1) / (m2 - m1)
			var c1: Color = TIME_PALETTE[i]["color"]
			var c2: Color = TIME_PALETTE[i + 1]["color"]
			return c1.lerp(c2, t)

	return TIME_PALETTE[-1]["color"]


func _update_map_lighting(animated: bool = true) -> void:
	if not is_instance_valid(map_texture):
		return

	var time_mgr: Node = _get_time_mgr()
	var h: int = int(time_mgr.get("current_hour")) if time_mgr else 10
	var m: int = int(time_mgr.get("current_minute")) if time_mgr else 0
	var total_min: float = float(h * 60 + m)

	var target_color: Color = _calculate_time_color(total_min)

	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()

	if animated:
		_light_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_light_tween.tween_property(map_texture, "modulate", target_color, 0.8)
	else:
		map_texture.modulate = target_color


func _on_day_changed(new_day: int) -> void:
	_current_day = new_day
	refresh_ui()


func _on_dive_lock_changed(_is_locked: bool) -> void:
	refresh_ui()


func _get_time_mgr() -> Node:
	return get_node_or_null("/root/GlobalTime")


func _show_toast(msg: String) -> void:
	if not is_instance_valid(toast_banner) or not is_instance_valid(toast_label):
		return
	toast_label.text = msg
	toast_banner.visible = true
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_banner, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(toast_banner, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(func() -> void:
		toast_banner.visible = false
	)


func _setup_button_juice(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(func() -> void:
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	)
	btn.button_down.connect(func() -> void:
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.06)
	)
	btn.button_up.connect(func() -> void:
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.08)
	)


func _play_micro_transition(action: Callable) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 135
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var curtain := ColorRect.new()
	curtain.color = Color(0.01, 0.04, 0.08, 1.0)
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	curtain.modulate.a = 0.0
	overlay_layer.add_child(curtain)
	add_child(overlay_layer)

	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(curtain, "modulate:a", 1.0, 0.14)
	tw.tween_callback(func() -> void:
		action.call()
	)
	tw.tween_interval(0.04)
	tw.tween_property(curtain, "modulate:a", 0.0, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		overlay_layer.queue_free()
		_is_transitioning = false
	)


func _play_transition(on_complete: Callable, display_time: float = 1.0) -> void:
	if not loading_scene:
		on_complete.call()
		return

	var loading_inst = loading_scene.instantiate()
	loading_inst.auto_change_scene = false
	loading_inst.min_display_time = display_time
	var layer_node := CanvasLayer.new()
	layer_node.layer = 150
	layer_node.add_child(loading_inst)
	get_tree().current_scene.add_child(layer_node)

	loading_inst.finished.connect(func():
		layer_node.queue_free()
		on_complete.call()
	)


static func preload_batch(batch_size: int = 10) -> float:
	if _cached_map_frames.size() >= ANIM_FRAME_COUNT:
		return 1.0
	var start_idx: int = _cached_map_frames.size() + 1
	var end_idx: int = mini(start_idx + batch_size - 1, ANIM_FRAME_COUNT)
	for i in range(start_idx, end_idx + 1):
		var path: String = ANIM_PATH_PATTERN % i
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex:
				_cached_map_frames.append(tex)
	return float(_cached_map_frames.size()) / float(ANIM_FRAME_COUNT)


static func is_animation_loaded() -> bool:
	return _cached_map_frames.size() >= ANIM_FRAME_COUNT


static func preload_animation_frames() -> void:
	if _cached_map_frames.size() >= ANIM_FRAME_COUNT:
		return
	while _cached_map_frames.size() < ANIM_FRAME_COUNT:
		preload_batch(ANIM_FRAME_COUNT)


func _init_map_animation() -> void:
	if not is_animation_loaded():
		preload_animation_frames()
	if not _cached_map_frames.is_empty() and is_instance_valid(map_texture):
		map_texture.texture = _cached_map_frames[0]


func _start_ambient_audio() -> void:
	if not ambient_stream:
		return

	if ambient_stream is AudioStreamOggVorbis:
		(ambient_stream as AudioStreamOggVorbis).loop = true

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "MapAmbientPlayer"
	_ambient_player.bus = "SFX"
	_ambient_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_ambient_player.stream = ambient_stream
	_ambient_player.volume_db = -40.0
	add_child(_ambient_player)
	_ambient_player.play()

	_ambient_player.finished.connect(func() -> void:
		if is_instance_valid(_ambient_player) and _ambient_player.is_inside_tree():
			_ambient_player.play()
	)

	if _ambient_tween and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ambient_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_ambient_tween.tween_property(_ambient_player, "volume_db", ambient_target_volume_db, 0.6)


func _stop_ambient_audio(fade_time: float = 0.5) -> void:
	if not is_instance_valid(_ambient_player) or not _ambient_player.playing:
		return

	if _ambient_tween and _ambient_tween.is_valid():
		_ambient_tween.kill()

	if fade_time > 0.0:
		_ambient_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ambient_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_ambient_tween.tween_property(_ambient_player, "volume_db", -40.0, fade_time)
		_ambient_tween.tween_callback(func() -> void:
			if is_instance_valid(_ambient_player):
				_ambient_player.stop()
		)
	else:
		_ambient_player.stop()

