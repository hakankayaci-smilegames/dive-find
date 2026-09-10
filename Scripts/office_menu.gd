extends CanvasLayer

@export var inventory_scene: PackedScene
@export var equstore_scene: PackedScene
@export var antikaci_scene: PackedScene
@export var kara_borsa_scene: PackedScene
@export var copcu_scene: PackedScene
@export var collection_scene: PackedScene
@export var lab_scene: PackedScene = preload("res://Scenes/laboratory.tscn")
@export var pazar_scene: PackedScene = preload("res://Scenes/pazar.tscn")
@export var day_summary_scene: PackedScene = preload("res://Scenes/day_summary.tscn")
@export var charge_station_scene: PackedScene = preload("res://Scenes/charge_station.tscn")

@export_group("Görsel & Ses")
@export var main_menu_scene_path: String = "res://Scenes/main_menu.tscn"

@export_group("Oyuna Dönüş")
@export var teleport_player_on_close: bool = true
@export var ocean_spawn_x: float = 16.0          # Ofisten çıkınca oyuncunun merkez x konumu (dalış noktası)
@export var ocean_spawn_x_variance: float = 3000.0 # Yatay rastgele sapma aralığı (± piksel, geniş keşif)
@export var spawn_above_surface_px: float = 60.0  # Su yüzeyinin hemen azıcık üstünden suya giriş
@export var spawn_fall_speed: float = 450.0       # Hızlı düşüş hızı

# Referanslar (UI)
@onready var zurna_label: Label = %ZurnaLabel
@onready var day_label: Label = %DayLabel
@onready var advance_day_button: Button = %AdvanceDayButton
@onready var save_exit_button: Button = %SaveExitButton
@onready var mobile_console_button: Button = get_node_or_null("%MobileConsoleButton")
@onready var settings_button: Button = get_node_or_null("%SettingsButton")

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
@onready var charge_button: Button = %ChargeButton
@onready var battery_badge_label: Label = %BatteryBadgeLabel
@onready var dive_button: Button = %DiveButton
@onready var toast_banner: PanelContainer = get_node_or_null("%ToastBanner")
@onready var toast_label: Label = %ToastLabel

var _toast_tween: Tween = null
var _current_day: int = 1

var _active_collection: Node = null
var _active_inventory: Node = null
var _active_popup: Node = null
var _active_popup_scene: PackedScene = null
var _active_settings: Node = null
var _badge_tweens: Array[Tween] = []
var _displayed_money: int = 0
var _money_tween: Tween = null
var _cached_recipes: Array = []
var _recipes_loaded: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_to_group("office_menu")
	_load_recipes_cache()

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("reset_flashlight_for_office"):
		player.reset_flashlight_for_office()

	# Hafif solma (fade-in) ile ofise pürüzsüz giriş
	if has_node("Background"):
		$Background.modulate.a = 0.0
		var fade_in := create_tween()
		fade_in.tween_property($Background, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
	_displayed_money = GlobalEconomy.money

	GlobalEconomy.money_changed.connect(_on_money_changed)
	GlobalInventory.inventory_updated.connect(_on_inventory_updated)
	GlobalInventory.equipment_updated.connect(_on_equipment_updated)
	if player and player.has_signal("battery_changed") and not player.battery_changed.is_connected(_on_player_battery_changed):
		player.battery_changed.connect(_on_player_battery_changed)
	refresh_ui()

	# Buton Juice (Mikro-punch)
	var all_juice_buttons: Array[Button] = [copcu_button, antikaci_button, kara_borsa_button, equstore_button, lab_button, shop_button, envanter_button, koleksiyon_button, charge_button, dive_button, advance_day_button, save_exit_button]
	if is_instance_valid(settings_button):
		all_juice_buttons.append(settings_button)
	for b in all_juice_buttons:
		_setup_button_juice(b)

	# Üst Bar Bağlantıları
	save_exit_button.pressed.connect(_on_save_exit_pressed)
	advance_day_button.pressed.connect(_on_advance_day_pressed)
	if is_instance_valid(settings_button):
		settings_button.pressed.connect(_open_settings)
	if is_instance_valid(mobile_console_button):
		var dev_console = get_node_or_null("/root/DevConsole")
		var is_dev_unlocked: bool = dev_console.is_dev_console_unlocked() if dev_console and dev_console.has_method("is_dev_console_unlocked") else false
		if OS.has_feature("mobile") and is_dev_unlocked:
			mobile_console_button.visible = true
			mobile_console_button.pressed.connect(func() -> void:
				if dev_console and dev_console.has_method("toggle_console"):
					dev_console.toggle_console()
			)
		else:
			mobile_console_button.visible = false

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
	charge_button.pressed.connect(_open_charge_station)
	dive_button.pressed.connect(_on_dive_pressed)

	if toast_banner:
		toast_banner.modulate.a = 0.0
		toast_banner.visible = false
	elif toast_label:
		toast_label.modulate.a = 0.0


func refresh_ui() -> void:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	var title_lbl: Label = get_node_or_null("Background/MainMargin/VBox/TopBar/TitleBox/TitleLabel")
	if title_lbl:
		title_lbl.text = "OFFICE & DIVE HEADQUARTERS" if is_en else "OFİS & DALIŞ KARARGAHI"

	var subtitle_lbl: Label = get_node_or_null("Background/MainMargin/VBox/TopBar/TitleBox/SubtitleLabel")
	if subtitle_lbl:
		subtitle_lbl.text = "Facilities, Traders & Operations Hub" if is_en else "Tesisler, Tüccarlar ve Operasyon Yönetim Merkezi"

	if is_instance_valid(save_exit_button):
		save_exit_button.text = "SAVE & QUIT" if is_en else "KAYDET & ÇIK"

	if is_instance_valid(settings_button):
		settings_button.tooltip_text = "Settings" if is_en else "Ayarlar"

	var sec1: Label = get_node_or_null("Background/MainMargin/VBox/SectionTitle1")
	if sec1:
		sec1.text = "TRADERS & ACQUISITIONS" if is_en else "TÜCCARLAR VE ALIM MERKEZLERİ"

	var sec2: Label = get_node_or_null("Background/MainMargin/VBox/SectionTitle2")
	if sec2:
		sec2.text = "FACILITIES & PRODUCTION" if is_en else "TESİSLER VE ÜRETİM ALANLARI"

	if is_instance_valid(copcu_button):
		var t: Label = copcu_button.get_node_or_null("VBox/Title")
		var d: Label = copcu_button.get_node_or_null("VBox/Desc")
		if t: t.text = "SCRAPPER" if is_en else "ÇÖPCÜ"
		if d: d.text = "Only buys trash and scrap items" if is_en else "Sadece çöp ve hurda eşyaları alır"

	if is_instance_valid(antikaci_button):
		var t: Label = antikaci_button.get_node_or_null("VBox/Title")
		var d: Label = antikaci_button.get_node_or_null("VBox/Desc")
		if t: t.text = "ANTIQUE DEALER" if is_en else "ANTİKACI"
		if d: d.text = "Buys valuable finds except trash" if is_en else "Çöp hariç değerli buluntuları alır"

	if is_instance_valid(kara_borsa_button):
		var t: Label = kara_borsa_button.get_node_or_null("VBox/Title")
		var d: Label = kara_borsa_button.get_node_or_null("VBox/Desc")
		if t: t.text = "BLACK MARKET" if is_en else "KARA BORSA"
		if d: d.text = "Only buys special & contraband loot" if is_en else "Sadece özel ve gizli ganimetleri alır"

	if is_instance_valid(equstore_button):
		var t: Label = equstore_button.get_node_or_null("VBox/Title")
		var d: Label = equstore_button.get_node_or_null("VBox/Desc")
		var s: Label = equstore_button.get_node_or_null("VBox/Status")
		if t: t.text = "EQUIPMENT SHOP" if is_en else "EKİPMAN MAĞAZASI"
		if d: d.text = "Upgrade Tank, Fins, Mask & Bag" if is_en else "Tüp, Palet, Gözlük ve Çanta Yükselt"
		if s: s.text = "[ ACTIVE ]" if is_en else "[ AKTİF ]"

	if is_instance_valid(lab_button):
		var t: Label = lab_button.get_node_or_null("VBox/Title")
		var d: Label = lab_button.get_node_or_null("VBox/Desc")
		var s: Label = lab_button.get_node_or_null("VBox/Status")
		if t: t.text = "LABORATORY" if is_en else "LABORATUVAR"
		if d: d.text = "Advanced Crafting & Synthesis" if is_en else "Hammaddeler ile İleri Craft & Sentez"
		if s: s.text = "[ ACTIVE ]" if is_en else "[ AKTİF ]"

	if is_instance_valid(shop_button):
		var t: Label = shop_button.get_node_or_null("VBox/Title")
		var d: Label = shop_button.get_node_or_null("VBox/Desc")
		var s: Label = shop_button.get_node_or_null("VBox/Status")
		if t: t.text = "MARKETPLACE" if is_en else "SATIŞ PAZARI"
		if d: d.text = "Sell Crafted & Advanced Items" if is_en else "Üretilen Gelişmiş Eşyaların Satışı"
		if s: s.text = "[ ACTIVE ]" if is_en else "[ AKTİF ]"

	if is_instance_valid(envanter_button):
		envanter_button.text = "🎒 INVENTORY [I]" if is_en else "🎒 ÇANTA [I]"
	if is_instance_valid(koleksiyon_button):
		koleksiyon_button.text = "📖 COLLECTION [C]" if is_en else "📖 KOLEKSİYON [C]"
	if is_instance_valid(charge_button):
		charge_button.text = "⚡ CHARGE" if is_en else "⚡ ŞARJ ET"

	_refresh_wallet()
	_refresh_day()
	_refresh_battery_badge()
	_update_dive_button_state()
	_update_merchant_badges()

	for sub in [_active_popup, _active_inventory, _active_collection, _active_settings]:
		if is_instance_valid(sub) and sub.has_method("refresh_ui"):
			sub.call("refresh_ui")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				# 1. Öncelik: Açık bir tüccar veya alt menü varsa önce onu kapat
				if is_instance_valid(_active_popup) or is_instance_valid(_active_inventory) or is_instance_valid(_active_collection) or is_instance_valid(_active_settings):
					_close_all_submenus()
					get_viewport().set_input_as_handled()
					return
				# Hiçbir alt pencere yoksa dalışa geç
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
		zurna_label.text = tr("%d Zurna") % _displayed_money


func _refresh_day() -> void:
	if not day_label:
		return
	var time_mgr: Node = _get_time_mgr()
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if time_mgr:
		var day_str: String = "Day: %d  |  ⏰ %s" if is_en else "Gün: %d  |  ⏰ %s"
		day_label.text = day_str % [int(time_mgr.get("current_day")), time_mgr.get_time_string()]
	else:
		var day_str: String = "Day: %d" if is_en else "Gün: %d"
		day_label.text = day_str % _current_day


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

	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	dive_button.disabled = not is_allowed
	if not is_allowed:
		dive_button.text = "🤿 DIVE CLOSED (NIGHT)" if is_en else "🤿 DALIŞ KAPALI (HAVA KARARDI)"
		if is_instance_valid(advance_day_button):
			advance_day_button.text = "END DAY & PROCEED ☀️" if is_en else "GÜNÜ BİTİR & İLERLET ☀️"
	else:
		dive_button.text = "🤿 START DIVE / OCEAN [ESC]" if is_en else "🤿 DALIŞA BAŞLA / OKYANUS [ESC]"
		if is_instance_valid(advance_day_button):
			advance_day_button.text = "PROCEED DAY ☀️" if is_en else "GÜNÜ İLERLET ☀️"


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
	cancel_btn.text = "CONTINUE DIVING" if is_en else "DALIŞA DEVAM ET"
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


func _on_new_day_started() -> void:
	_refresh_day()
	_update_dive_button_state()
	var time_mgr: Node = _get_time_mgr()
	var cur_day: int = int(time_mgr.get("current_day")) if time_mgr else _current_day
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	_show_toast(("☀️ New day started! (Day %d)" if is_en else "☀️ Yeni gün başladı! (Gün %d)") % cur_day)


func _on_money_changed(amount: int) -> void:
	var target_amount: int = amount
	var diff: int = target_amount - _displayed_money
	if diff > 0:
		_spawn_floating_cash(diff)

	if _money_tween and _money_tween.is_valid():
		_money_tween.kill()

	var start_amount: int = _displayed_money
	_money_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_money_tween.tween_method(func(val: int) -> void:
		_displayed_money = val
		if zurna_label:
			zurna_label.text = tr("%d Zurna") % val
	, start_amount, target_amount, 0.45)

	_update_merchant_badges()


func _spawn_floating_cash(diff: int) -> void:
	if not is_instance_valid(zurna_label):
		return
	var float_label := Label.new()
	float_label.text = "+%d Zurna" % diff
	float_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	float_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	float_label.add_theme_constant_override("shadow_outline_size", 2)
	float_label.add_theme_font_size_override("font_size", 15)

	var base_pos: Vector2 = zurna_label.global_position + Vector2(10.0, 36.0)
	float_label.global_position = base_pos
	add_child(float_label)

	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(float_label, "global_position:y", base_pos.y - 28.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(float_label, "modulate:a", 0.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(float_label.queue_free)


func _setup_button_juice(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func() -> void:
		if is_instance_valid(btn):
			btn.pivot_offset = btn.size / 2.0
	)
	btn.mouse_entered.connect(func() -> void:
		if is_instance_valid(btn) and not btn.disabled:
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.08)
	)
	btn.mouse_exited.connect(func() -> void:
		if is_instance_valid(btn):
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)
	btn.pressed.connect(func() -> void:
		if is_instance_valid(btn):
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.05)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)


func _on_save_exit_pressed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var equipment_dict: Dictionary = {
		"tube_level": int(player.get("tube_level")) if player else 1,
		"fins_level": int(player.get("fins_level")) if player else 0,
		"goggles_level": int(player.get("goggles_level")) if player else 0,
		"backpack_level": int(player.get("backpack_level")) if player else 0,
		"flashlight_level": int(player.get("flashlight_level")) if player else 0,
		"current_battery": float(player.get("current_battery")) if player else -1.0
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

	_close_all_submenus()
	GlobalSoundManager.play_sfx("door_close")

	if time_mgr:
		time_mgr.record_dive()
		time_mgr.start_clock()

	if teleport_player_on_close:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var spawn_y = InfiniteMapManager.water_surface_y - spawn_above_surface_px
			var spawn_x: float = ocean_spawn_x
			if ocean_spawn_x_variance > 0.0:
				spawn_x += randf_range(-ocean_spawn_x_variance, ocean_spawn_x_variance)
			player.set("global_position", Vector2(spawn_x, spawn_y))
			player.set("velocity", Vector2(0, spawn_fall_speed))
			player.set("current_oxygen", 100.0)
			player.set("current_health", 100.0)
	get_tree().paused = false
	get_tree().call_group("hud", "refresh_ui")
	queue_free()


func _exit_tree() -> void:
	_close_all_submenus()
	get_tree().paused = false
	if GlobalEconomy.money_changed.is_connected(_on_money_changed):
		GlobalEconomy.money_changed.disconnect(_on_money_changed)
	if GlobalInventory.inventory_updated.is_connected(_on_inventory_updated):
		GlobalInventory.inventory_updated.disconnect(_on_inventory_updated)
	if GlobalInventory.equipment_updated.is_connected(_on_equipment_updated):
		GlobalInventory.equipment_updated.disconnect(_on_equipment_updated)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("battery_changed") and player.battery_changed.is_connected(_on_player_battery_changed):
		player.battery_changed.disconnect(_on_player_battery_changed)
	for tw in _badge_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_badge_tweens.clear()


# ------------------------------------------------------------------
# SAHNE AÇICILAR & ALT MENÜ YÖNETİMİ (TOGGLE)
# ------------------------------------------------------------------

func _close_all_submenus() -> void:
	if is_instance_valid(_active_popup):
		_active_popup.queue_free()
		_active_popup = null
		_active_popup_scene = null
	if is_instance_valid(_active_inventory):
		_active_inventory.queue_free()
		_active_inventory = null
	if is_instance_valid(_active_collection):
		_active_collection.queue_free()
		_active_collection = null
	if is_instance_valid(_active_settings):
		_active_settings.queue_free()
		_active_settings = null


func _open_settings() -> void:
	if is_instance_valid(_active_settings):
		_active_settings.queue_free()
		_active_settings = null
		GlobalSoundManager.play_sfx("click")
		return

	_close_all_submenus()
	GlobalSoundManager.play_sfx("click")
	var settings_scn: PackedScene = preload("res://Scenes/settings_menu.tscn")
	_active_settings = settings_scn.instantiate()
	_active_settings.tree_exited.connect(func() -> void:
		_active_settings = null
	)
	get_tree().current_scene.add_child(_active_settings)


func _open_popup(scene: PackedScene) -> void:
	if not scene:
		push_warning("OfficeMenu: Açılmak istenen sahne atanmamış!")
		return

	# Eğer bu pencere zaten açıksa kapat (Toggle)
	if is_instance_valid(_active_popup) and _active_popup_scene == scene:
		_close_all_submenus()
		GlobalSoundManager.play_sfx("click")
		return

	_close_all_submenus()
	GlobalSoundManager.play_sfx("click")
	_active_popup_scene = scene
	_active_popup = scene.instantiate()
	_active_popup.tree_exited.connect(func() -> void:
		_active_popup = null
		_active_popup_scene = null
		_refresh_battery_badge()
	)
	get_tree().current_scene.add_child(_active_popup)


func _open_copcu() -> void:
	_open_popup(copcu_scene)


func _open_antikaci() -> void:
	_open_popup(antikaci_scene)


func _open_kara_borsa() -> void:
	_open_popup(kara_borsa_scene)


func _open_equstore() -> void:
	_open_popup(equstore_scene)


func _open_charge_station() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var flash_lvl: int = int(player.get("flashlight_level")) if player else 0
	if flash_lvl <= 0:
		GlobalSoundManager.play_sfx("error")
		_show_toast("⚠️ Fenerin yok! Önce Ekipman Mağazasından satın almalısın.")
		return

	if not charge_station_scene:
		push_warning("OfficeMenu: charge_station_scene atanmamış!")
		return

	if is_instance_valid(_active_popup) and _active_popup_scene == charge_station_scene:
		_close_all_submenus()
		GlobalSoundManager.play_sfx("click")
		return

	_open_popup(charge_station_scene)
	if is_instance_valid(_active_popup) and _active_popup.has_signal("battery_charged"):
		_active_popup.connect("battery_charged", func(_new_b: float) -> void:
			_refresh_battery_badge()
		)


func _refresh_battery_badge() -> void:
	if not is_instance_valid(battery_badge_label):
		return
	var player = get_tree().get_first_node_in_group("player")
	var flash_lvl: int = int(player.get("flashlight_level")) if player else 0
	if flash_lvl <= 0:
		battery_badge_label.text = tr("⚡ Fener Yok")
		battery_badge_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.7))
		return

	var max_bat: float = player.get_flashlight_max_battery() if player.has_method("get_flashlight_max_battery") else 60.0
	var cur_bat: float = float(player.get("current_battery")) if player else 0.0
	if cur_bat < 0.0:
		cur_bat = max_bat
	var pct: int = int(clamp(round((cur_bat / max(max_bat, 0.01)) * 100.0), 0.0, 100.0))

	battery_badge_label.text = tr("🔋 %%%d") % pct
	if pct > 50:
		battery_badge_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.45, 1.0))
	elif pct > 20:
		battery_badge_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3, 1.0))
	else:
		battery_badge_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35, 1.0))


func _on_inventory_updated() -> void:
	_update_merchant_badges()
	_refresh_battery_badge()


func _on_equipment_updated(_stat_key: String = "", _new_level: int = 0) -> void:
	_update_merchant_badges()
	_refresh_battery_badge()


func _on_player_battery_changed(_cur: float, _max: float) -> void:
	_refresh_battery_badge()


func _open_envanter() -> void:
	if is_instance_valid(_active_inventory):
		_active_inventory.queue_free()
		_active_inventory = null
		GlobalSoundManager.play_sfx("click")
		return

	_close_all_submenus()
	if not inventory_scene:
		push_warning("OfficeMenu: inventory_scene atanmamış!")
		return
	GlobalSoundManager.play_sfx("click")
	_active_inventory = inventory_scene.instantiate()
	_active_inventory.tree_exited.connect(func() -> void:
		_active_inventory = null
	)
	get_tree().current_scene.add_child(_active_inventory)


func _open_koleksiyon() -> void:
	if is_instance_valid(_active_collection):
		_active_collection.queue_free()
		_active_collection = null
		GlobalSoundManager.play_sfx("click")
		return

	_close_all_submenus()
	if not collection_scene:
		push_warning("OfficeMenu: collection_scene atanmamış!")
		return
	GlobalSoundManager.play_sfx("click")
	_active_collection = collection_scene.instantiate()
	_active_collection.tree_exited.connect(func() -> void:
		_active_collection = null
	)
	get_tree().current_scene.add_child(_active_collection)


func _on_lab_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	if lab_scene:
		_open_popup(lab_scene)
	else:
		_show_toast("🧪 Laboratuvar sahnesi bulunamadı!")


func _on_shop_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	if pazar_scene:
		_open_popup(pazar_scene)
	else:
		_show_toast("📦 Satış Pazarı sahnesi bulunamadı!")


const OFFICE_TOAST_TRANSLATIONS_EN: Dictionary = {
	"⚠️ Fenerin yok! Önce Ekipman Mağazasından satın almalısın.": "⚠️ No flashlight! You must buy one from the Equipment Shop first.",
	"⚠️ Hava karardı (19:00+). Yeni dalış için günü ilerletmelisiniz!": "⚠️ It is dark (19:00+). Advance the day for the next dive!",
	"⚡ Fener bataryası şarj edildi!": "⚡ Flashlight battery charged!",
	"🧪 Laboratuvar sahnesi bulunamadı!": "🧪 Laboratory scene not found!",
	"📦 Satış Pazarı sahnesi bulunamadı!": "📦 Market scene not found!",
}


func _show_toast(msg: String) -> void:
	if not toast_label:
		return
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_en:
		if OFFICE_TOAST_TRANSLATIONS_EN.has(msg):
			msg = OFFICE_TOAST_TRANSLATIONS_EN[msg]
		elif msg.begins_with("⚠️ Dalış yapabilmek için fenerini şarj etmelisin!"):
			msg = msg.replace("⚠️ Dalış yapabilmek için fenerini şarj etmelisin!", "⚠️ You must charge your flashlight to dive!").replace("şarj", "charge")
		elif msg.begins_with("☀️ Yeni gün başladı! (Gün "):
			msg = msg.replace("☀️ Yeni gün başladı! (Gün ", "☀️ New day started! (Day ")
		else:
			msg = tr(msg)
	else:
		msg = tr(msg)
	toast_label.text = msg
	var target_node: CanvasItem = toast_banner if is_instance_valid(toast_banner) else toast_label

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	target_node.visible = true
	target_node.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(target_node, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(target_node, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_toast_tween.tween_callback(func() -> void:
		if is_instance_valid(target_node):
			target_node.visible = false
	)


func _get_time_mgr() -> Node:
	return get_node_or_null("/root/GlobalTime")


# ------------------------------------------------------------------
# CANLI TÜCCAR ROZETLERİ (LOOT BADGES & GLOW)
# ------------------------------------------------------------------

func _update_merchant_badges() -> void:
	# Önceki animasyonları temizle
	for tw in _badge_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_badge_tweens.clear()

	# Çantayı tara
	var trash_count: int = 0
	var trash_val: int = 0
	var antika_count: int = 0
	var antika_val: int = 0
	var special_count: int = 0
	var special_val: int = 0
	var crafted_count: int = 0
	var crafted_val: int = 0

	for item in GlobalInventory.collected_items:
		if not item or bool(item.get("is_locked")):
			continue
		var cat: String = str(item.get("category"))
		var val: int = int(item.get("value"))
		if cat == "Trash":
			trash_count += 1
			trash_val += val
		elif cat == "Special":
			special_count += 1
			special_val += val
		elif cat == "Crafted":
			crafted_count += 1
			crafted_val += val
		elif cat != "Resource": # Sadece Rare Found ve Valuable
			antika_count += 1
			antika_val += val

	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	# 1. ÇÖPÇÜ ROZETİ
	if trash_count > 0:
		_set_badge(copcu_button, ("🟢 %d Scrap (+%d Z)" if is_en else "🟢 %d Hurda (+%d Z)") % [trash_count, trash_val], true, Color(0.25, 0.85, 0.45, 1.0))
	else:
		_set_badge(copcu_button, "⚪ No Items" if is_en else "⚪ Eşya Yok", false, Color(0.5, 0.5, 0.5, 0.5))

	# 2. ANTİKACI ROZETİ
	if antika_count > 0:
		_set_badge(antikaci_button, ("🟢 %d Antique (+%d Z)" if is_en else "🟢 %d Antika (+%d Z)") % [antika_count, antika_val], true, Color(0.95, 0.85, 0.35, 1.0))
	else:
		_set_badge(antikaci_button, "⚪ No Items" if is_en else "⚪ Eşya Yok", false, Color(0.5, 0.5, 0.5, 0.5))

	# 3. KARA BORSA ROZETİ
	if special_count > 0:
		_set_badge(kara_borsa_button, ("🔴 %d Special (+%d Z)" if is_en else "🔴 %d Özel (+%d Z)") % [special_count, special_val], true, Color(0.95, 0.35, 0.45, 1.0))
	else:
		_set_badge(kara_borsa_button, "⚪ No Items" if is_en else "⚪ Eşya Yok", false, Color(0.5, 0.5, 0.5, 0.5))

	# 4. EKİPMAN ATÖLYESİ ROZETİ (Geliştirme Kontrolü)
	var player = get_tree().get_first_node_in_group("player")
	var can_upgrade: bool = false
	var upgrades_info = [
		{"key": "tube_level", "base": 35, "mult": 1.50, "max": 25},
		{"key": "fins_level", "base": 25, "mult": 1.65, "max": 20},
		{"key": "goggles_level", "base": 100, "mult": 2.10, "max": 9},
		{"key": "backpack_level", "base": 20, "mult": 1.50, "max": 20},
		{"key": "flashlight_level", "base": 50, "mult": 1.35, "max": 15}
	]
	for u in upgrades_info:
		var lvl = int(player.get(u["key"])) if player else 0
		if int(u.get("max", -1)) >= 0 and lvl >= int(u["max"]):
			continue
		var cost = int(round(float(u["base"]) * pow(float(u["mult"]), float(lvl))))
		if GlobalEconomy.money >= cost:
			can_upgrade = true
			break

	if can_upgrade:
		_set_badge(equstore_button, "✨ Upgrade Ready!" if is_en else "✨ Yükseltme Hazır!", true, Color(0.35, 0.85, 1.0, 1.0))
	else:
		_set_badge(equstore_button, "", false, Color.TRANSPARENT)

	# 5. SATIŞ PAZARI ROZETİ (Üretilmiş Eşyalar)
	if crafted_count > 0:
		_set_badge(shop_button, ("🟢 %d Products (+%d Z)" if is_en else "🟢 %d Ürün (+%d Z)") % [crafted_count, crafted_val], true, Color(1.0, 0.65, 0.2, 1.0))
	else:
		_set_badge(shop_button, "⚪ No Products" if is_en else "⚪ Ürün Yok", false, Color(0.5, 0.5, 0.5, 0.5))

	# 6. LABORATUVAR ROZETİ (Sentezlenebilir Tarif Kontrolü)
	var can_craft_any: bool = _check_can_craft_any_recipe()
	if can_craft_any:
		_set_badge(lab_button, "✨ Synthesis Ready!" if is_en else "✨ Sentez Hazır!", true, Color(1.0, 0.75, 0.25, 1.0))
	else:
		_set_badge(lab_button, "", false, Color.TRANSPARENT)


func _load_recipes_cache() -> void:
	if _recipes_loaded:
		return
	_recipes_loaded = true
	_cached_recipes.clear()
	var recipes_path := "res://Data/recipes.json"
	if not FileAccess.file_exists(recipes_path):
		return
	var file := FileAccess.open(recipes_path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		for r in json.data:
			if r is Dictionary:
				_cached_recipes.append(r)


func _check_can_craft_any_recipe() -> bool:
	if not _recipes_loaded:
		_load_recipes_cache()
	if _cached_recipes.is_empty():
		return false

	for r in _cached_recipes:
		if not (r is Dictionary):
			continue
		var req_money: int = int(r.get("required_money", 0))
		if GlobalEconomy.money < req_money:
			continue
		var ing_ok: bool = true
		for ing in r.get("ingredients", []):
			var iname: String = str(ing.get("item_name", ""))
			var needed: int = int(ing.get("count", 1))
			var cur: int = 0
			for item in GlobalInventory.collected_items:
				if item and not bool(item.get("is_locked")) and str(item.get("item_name")) == iname:
					cur += 1
			if cur < needed:
				ing_ok = false
				break
		if ing_ok:
			return true
	return false


func _set_badge(button: Button, text: String, is_active: bool, accent_color: Color) -> void:
	if not is_instance_valid(button):
		return

	var badge = button.get_node_or_null("LootBadge") as PanelContainer
	if not badge:
		badge = PanelContainer.new()
		badge.name = "LootBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.anchors_preset = Control.PRESET_TOP_RIGHT
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.offset_left = -165
		badge.offset_top = 8
		badge.offset_right = -10
		badge.offset_bottom = 32
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN

		var lbl = Label.new()
		lbl.name = "BadgeText"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		badge.add_child(lbl)
		button.add_child(badge)

	if text == "":
		badge.visible = false
		return
	badge.visible = true

	var lbl = badge.get_node("BadgeText") as Label
	lbl.text = text

	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3

	if is_active:
		style.bg_color = Color(0.10, 0.08, 0.05, 0.95)
		style.set_border_width_all(2)
		style.border_color = accent_color
		lbl.add_theme_color_override("font_color", accent_color)
		
		# Şık Parlama & Nefes Alma Efekti (Glow / Pulse Tween)
		badge.pivot_offset = Vector2(75, 12)
		badge.scale = Vector2(1.0, 1.0)
		var tw = create_tween().set_loops()
		tw.tween_property(badge, "scale", Vector2(1.05, 1.05), 0.65).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(badge, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.65)
		tw.tween_property(badge, "scale", Vector2(1.0, 1.0), 0.65).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(badge, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.65)
		_badge_tweens.append(tw)
	else:
		style.bg_color = Color(0.12, 0.12, 0.12, 0.5)
		style.set_border_width_all(1)
		style.border_color = Color(0.4, 0.4, 0.4, 0.4)
		badge.scale = Vector2(1.0, 1.0)
		badge.modulate = Color(1.0, 1.0, 1.0, 0.7)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 0.8))

	badge.add_theme_stylebox_override("panel", style)
