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
var _active_popup: Node = null
var _active_popup_scene: PackedScene = null
var _badge_tweens: Array[Tween] = []
var _displayed_money: int = 0
var _money_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_to_group("office_menu")

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
	GlobalInventory.inventory_updated.connect(_update_merchant_badges)
	_refresh_wallet()
	_refresh_day()
	_update_dive_button_state()
	_update_merchant_badges()

	# Buton Juice (Mikro-punch)
	for b in [copcu_button, antikaci_button, kara_borsa_button, equstore_button, lab_button, shop_button, envanter_button, koleksiyon_button, dive_button, advance_day_button, save_exit_button]:
		_setup_button_juice(b)

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
				# 1. Öncelik: Açık bir tüccar veya alt menü varsa önce onu kapat
				if is_instance_valid(_active_popup) or is_instance_valid(_active_inventory) or is_instance_valid(_active_collection):
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
		zurna_label.text = "%d Zurna" % _displayed_money


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
			zurna_label.text = "%d Zurna" % val
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
	queue_free()


func _exit_tree() -> void:
	_close_all_submenus()
	get_tree().paused = false
	if GlobalEconomy.money_changed.is_connected(_on_money_changed):
		GlobalEconomy.money_changed.disconnect(_on_money_changed)
	if GlobalInventory.inventory_updated.is_connected(_update_merchant_badges):
		GlobalInventory.inventory_updated.disconnect(_update_merchant_badges)
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

	# 1. ÇÖPÇÜ ROZETİ
	if trash_count > 0:
		_set_badge(copcu_button, "🟢 %d Hurda (+%d Z)" % [trash_count, trash_val], true, Color(0.25, 0.85, 0.45, 1.0))
	else:
		_set_badge(copcu_button, "⚪ Eşya Yok", false, Color(0.5, 0.5, 0.5, 0.5))

	# 2. ANTİKACI ROZETİ
	if antika_count > 0:
		_set_badge(antikaci_button, "🟢 %d Antika (+%d Z)" % [antika_count, antika_val], true, Color(0.95, 0.85, 0.35, 1.0))
	else:
		_set_badge(antikaci_button, "⚪ Eşya Yok", false, Color(0.5, 0.5, 0.5, 0.5))

	# 3. KARA BORSA ROZETİ
	if special_count > 0:
		_set_badge(kara_borsa_button, "🔴 %d Özel (+%d Z)" % [special_count, special_val], true, Color(0.95, 0.35, 0.45, 1.0))
	else:
		_set_badge(kara_borsa_button, "⚪ Eşya Yok", false, Color(0.5, 0.5, 0.5, 0.5))

	# 4. EKİPMAN ATÖLYESİ ROZETİ (Geliştirme Kontrolü)
	var player = get_tree().get_first_node_in_group("player")
	var can_upgrade: bool = false
	var upgrades_info = [
		{"key": "tube_level", "base": 40, "mult": 1.75},
		{"key": "fins_level", "base": 25, "mult": 1.65},
		{"key": "goggles_level", "base": 60, "mult": 1.90},
		{"key": "backpack_level", "base": 20, "mult": 1.50}
	]
	for u in upgrades_info:
		var lvl = int(player.get(u["key"])) if player else 0
		var cost = int(round(float(u["base"]) * pow(float(u["mult"]), float(lvl))))
		if GlobalEconomy.money >= cost:
			can_upgrade = true
			break

	if can_upgrade:
		_set_badge(equstore_button, "✨ Yükseltme Hazır!", true, Color(0.35, 0.85, 1.0, 1.0))
	else:
		_set_badge(equstore_button, "", false, Color.TRANSPARENT)

	# 5. SATIŞ PAZARI ROZETİ (Üretilmiş Eşyalar)
	if crafted_count > 0:
		_set_badge(shop_button, "🟢 %d Ürün (+%d Z)" % [crafted_count, crafted_val], true, Color(1.0, 0.65, 0.2, 1.0))
	else:
		_set_badge(shop_button, "⚪ Ürün Yok", false, Color(0.5, 0.5, 0.5, 0.5))

	# 6. LABORATUVAR ROZETİ (Sentezlenebilir Tarif Kontrolü)
	var can_craft_any: bool = _check_can_craft_any_recipe()
	if can_craft_any:
		_set_badge(lab_button, "✨ Sentez Hazır!", true, Color(1.0, 0.75, 0.25, 1.0))
	else:
		_set_badge(lab_button, "", false, Color.TRANSPARENT)


func _check_can_craft_any_recipe() -> bool:
	var recipes_path := "res://Data/recipes.json"
	if not FileAccess.file_exists(recipes_path):
		return false
	var file := FileAccess.open(recipes_path, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Array):
		return false

	for r in json.data:
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
