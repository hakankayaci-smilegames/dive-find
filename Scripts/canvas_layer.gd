extends CanvasLayer

@export var inventory_scene: PackedScene 
@export var invenb: Button

@export var player_node: Node2D 
@export var depth_label: Label 
@export var target_scene: PackedScene
var dock_shack_scene: PackedScene = null
var city_map_scene: PackedScene = null
@export var loading_scene: PackedScene # Ofise/Barakaya geçişten önce gösterilecek loading screen (overlay)

@export_group("Ekipman Paneli")
@export var bag_level_label: Label
@export var goggles_level_label: Label
@export var fins_level_label: Label
@export var tube_level_label: Label
@export var flashlight_level_label: Label

@export_group("Koleksiyon Bildirimi")
@export var collection_toast_label: Label  # Sağ üst köşede, 3-4sn görünüp solan bildirim
@export var warning_toast_label: Label     # Mesafe/hata uyarıları için dinamik toast

@export_group("Zaman & Gün Göstergesi")
@export var time_label: Label
@export var day_label: Label

@export_group("Ofise Dönüş Erişimi")
@export var office_button_surface_range: float = 600.0  # Yüzeyin bu kadar üstü/altında ofis butonu aktif olur
@onready var office_button: Button = $Button2

@export_group("Su Altı Efekti (Underwater Overlay)")
@export var enable_underwater_overlay: bool = false
@export var underwater_overlay: ColorRect
@export var underwater_tint_color: Color = Color(0.151, 0.62, 0.618, 1.0)
@export var underwater_max_alpha: float = 0.45
@export var underwater_fade_speed: float = 7.0

var _active_inventory: Node = null
var _active_pause_menu: Node = null
var _office_loading: Node = null
var _toast_tween: Tween = null
var _warning_tween: Tween = null
var _displayed_money: int = 0
var _money_tween: Tween = null
var _office_btn_tween: Tween = null
var _o2_danger_alerted: bool = false
var _o2_caution_alerted: bool = false
@onready var o2_return_label: Label = get_node_or_null("StatusPanel/O2ReturnLabel")
var _o2_hud_style: StyleBoxFlat = null
var _last_depth_meters: int = -999
var _o2_hud_timer: float = 0.0
var _current_hud_mode: String = ""
var _prev_sprinting: bool = false

# YENİ: Renk geçişi ve yön bulmak için hafıza değişkenleri
var _last_y: float = 0.0
var _current_color: Color = Color(0.85, 0.95, 1.0, 1.0) # Varsayılan buz mavisi

func _ready() -> void:
	add_to_group("hud")
	if o2_return_label:
		var sb := o2_return_label.get_theme_stylebox("normal")
		if sb is StyleBoxFlat:
			_o2_hud_style = sb.duplicate()
			o2_return_label.add_theme_stylebox_override("normal", _o2_hud_style)
	invenb.pressed.connect(_on_inventory_button_pressed)
	GlobalEconomy.money_changed.connect(_on_money_changed)
	_displayed_money = GlobalEconomy.money
	$zurna.text = tr("💰 %d Zurna") % _displayed_money
	_apply_hud_theme()
	_setup_button_juice(invenb)
	_setup_button_juice(office_button)
	if office_button:
		office_button.modulate.a = 0.0
		office_button.disabled = true

	var time_mgr: Node = _get_time_mgr()
	if time_mgr:
		time_mgr.time_changed.connect(_on_time_changed)
		time_mgr.day_changed.connect(_on_day_changed)
		_update_time_display(time_mgr.current_hour, time_mgr.current_minute)
		_update_day_display(time_mgr.current_day)
		time_mgr.start_clock()

	# Mobil / Dokunmatik Kontrolleri Ekle (Sadece gerçek mobil platformlarda)
	if OS.has_feature("mobile"):
		var mob_scene = load("res://Scenes/mobile_controls.tscn")
		if mob_scene:
			add_child(mob_scene.instantiate())

	if collection_toast_label:
		collection_toast_label.modulate.a = 0.0
		GlobalInventory.collection_updated.connect(_on_collection_updated)

	GlobalInventory.inventory_updated.connect(_on_inventory_or_equipment_updated)
	if GlobalInventory.has_signal("equipment_updated"):
		GlobalInventory.equipment_updated.connect(func(_k: String, _v: int) -> void: _on_inventory_or_equipment_updated())
	_on_inventory_or_equipment_updated()
	_setup_underwater_overlay()
	refresh_ui()
	call_deferred("_open_office_at_start")


func _setup_underwater_overlay() -> void:
	if not is_instance_valid(underwater_overlay):
		underwater_overlay = get_node_or_null("UnderwaterOverlay") as ColorRect
	if not is_instance_valid(underwater_overlay):
		underwater_overlay = ColorRect.new()
		underwater_overlay.name = "UnderwaterOverlay"
		underwater_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		underwater_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		underwater_overlay.color = underwater_tint_color
		underwater_overlay.modulate.a = 0.0
		underwater_overlay.visible = false
		add_child(underwater_overlay)
		move_child(underwater_overlay, 0)
	else:
		underwater_overlay.color = underwater_tint_color
		underwater_overlay.modulate.a = 0.0
		underwater_overlay.visible = false
		underwater_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_inventory_or_equipment_updated() -> void:
	_update_bag_button()
	_refresh_equipment_panel()


func _open_office_at_start() -> void:
	var scene: PackedScene = city_map_scene if city_map_scene else CityMap.city_map_packed
	if not scene:
		scene = load("res://Scenes/city_map.tscn")
	if scene:
		var city_inst = scene.instantiate()
		get_tree().current_scene.add_child(city_inst)
	else:
		_open_office()


func _process(delta: float) -> void:
	if not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player") as Node2D

	# Su Altı Modulate Efekti (Dalgıcın suya batma derinliğine göre yumuşak okyanus perdesi - Aç/Kapa Bool)
	if is_instance_valid(underwater_overlay):
		if enable_underwater_overlay and is_instance_valid(player_node):
			var surface_y: float = InfiniteMapManager.water_surface_y
			var player_y: float = player_node.global_position.y
			var submersion: float = clampf((player_y - surface_y) / 40.0, 0.0, 1.0)
			var target_alpha: float = submersion * underwater_max_alpha
			underwater_overlay.modulate.a = lerpf(underwater_overlay.modulate.a, target_alpha, underwater_fade_speed * delta)
			underwater_overlay.visible = underwater_overlay.modulate.a > 0.002
		elif underwater_overlay.visible or underwater_overlay.modulate.a > 0.0:
			underwater_overlay.visible = false
			underwater_overlay.modulate.a = 0.0

	if is_instance_valid(player_node) and depth_label:
		var surface_y = InfiniteMapManager.water_surface_y
		var player_y = player_node.global_position.y
		
		var depth_pixels = max(0.0, player_y - surface_y)
		var depth_meters = int(depth_pixels / 50.0)
		
		if depth_meters != _last_depth_meters:
			_last_depth_meters = depth_meters
			if depth_meters <= 0:
				depth_label.text = tr("⚓ YÜZEYDESİN (0m)")
			else:
				depth_label.text = tr("⚓ %dm  |  ↑ Yüzey: %dm") % [depth_meters, depth_meters]
		
		# --- DİNAMİK RENK GEÇİŞİ MANTIĞI ---
		var target_color = Color(0.85, 0.95, 1.0, 1.0) # Hareketsizken sabit mavi
		var y_velocity = player_node.velocity.y
		
		if y_velocity < -15.0: 
			target_color = Color(0.2, 0.9, 0.3, 1.0)
		elif y_velocity > 15.0: 
			var depth_factor = clamp(float(depth_meters) / 500.0, 0.0, 0.8) 
			target_color = Color(1.0, 0.2, 0.2, 1.0).lerp(Color(0.3, 0.0, 0.0, 1.0), depth_factor)
			
		_current_color = _current_color.lerp(target_color, 6.0 * delta)
		depth_label.self_modulate = _current_color

		var time_mgr: Node = _get_time_mgr()
		if time_mgr:
			time_mgr.record_depth(float(depth_meters))

		# Kritik Oksijen Nabız Uyarısı (< %25)
		if has_node("StatusPanel/Oxygen"):
			var ox: float = float(player_node.get("current_oxygen")) if player_node.get("current_oxygen") != null else 100.0
			if ox < 25.0:
				var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
				$StatusPanel/Oxygen.modulate = Color(1.0, 0.2 + 0.8 * pulse, 0.2 + 0.8 * pulse, 1.0)
			elif $StatusPanel/Oxygen.modulate != Color.WHITE:
				$StatusPanel/Oxygen.modulate = Color.WHITE

		# Yüzeye Dönüş & Oksijen Yetme Analizi (Dinamik Belirgin HUD - Optimize & Yüzey Destekli)
		if is_instance_valid(o2_return_label) and player_node.has_method("get_surface_return_info"):
			_o2_hud_timer += delta

			var info: Dictionary = player_node.get_surface_return_info()
			var depth_m: float = float(info.get("depth_m", 0.0))
			var is_god: bool = bool(info.get("godmode", false))
			var ox: float = float(info.get("current_oxygen", 100.0))
			var is_sprint: bool = bool(info.get("is_sprinting", false))
			var sprint_tag: String = " ⚡" if is_sprint else ""
			var sprint_changed: bool = (is_sprint != _prev_sprinting)
			_prev_sprinting = is_sprint

			var should_update_text: bool = (_o2_hud_timer >= 0.08) or sprint_changed

			var is_en: bool = ItemTranslator.get_current_locale() == "en"

			if is_god or depth_m < 2.0:
				# Yüzeydeyken HUD açık kalır ve güvende olduğunu gösterir
				if _current_hud_mode != "SURFACE":
					_current_hud_mode = "SURFACE"
					_o2_danger_alerted = false
					_o2_caution_alerted = false
					o2_return_label.visible = true
					o2_return_label.self_modulate = Color(0.80, 1.0, 0.92, 1.0)
					if _o2_hud_style:
						_o2_hud_style.border_color = Color(0.2, 0.75, 0.75, 0.85)
						_o2_hud_style.bg_color = Color(0.03, 0.08, 0.12, 0.94)
					o2_return_label.text = ("⚓ AT SURFACE (Safe)  │  🫧 O2: %d%%%s" if is_en else "⚓ YÜZEYDESİN (Güvende)  │  🫧 O2: %d%%%s") % [int(round(ox)), sprint_tag]
				elif should_update_text:
					o2_return_label.text = ("⚓ AT SURFACE (Safe)  │  🫧 O2: %d%%%s" if is_en else "⚓ YÜZEYDESİN (Güvende)  │  🫧 O2: %d%%%s") % [int(round(ox)), sprint_tag]
			else:
				var time_to_surf: float = float(info.get("time_to_surface", 0.0))
				var o2_secs: float = float(info.get("oxygen_seconds_left", 0.0))
				var is_crit: bool = bool(info.get("is_critical", false))
				var is_warn: bool = bool(info.get("is_warning", false))

				if is_crit:
					var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
					o2_return_label.self_modulate = Color(1.0, 0.3 + 0.5 * pulse, 0.3 + 0.5 * pulse, 1.0)
					if _current_hud_mode != "CRIT":
						_current_hud_mode = "CRIT"
						if _o2_hud_style:
							_o2_hud_style.border_color = Color(1.0, 0.15, 0.15, 0.95)
							_o2_hud_style.bg_color = Color(0.18, 0.03, 0.03, 0.95)
					if not _o2_danger_alerted:
						_o2_danger_alerted = true
						show_warning_toast("🚨 ACİL DURUM: Oksijen yüzeye yetmeyebilir! HEMEN YÜZEYE ÇIK!", 3.0)
						GlobalSoundManager.play_sfx("error")
					if should_update_text:
						o2_return_label.text = ("🚨 EMERGENCY RETURN! Surface: %.1fs > O2: %.1fs%s" if is_en else "🚨 ACİL DÖNÜŞ! Yüzey: %.1fs > O2: %.1fs%s") % [time_to_surf, o2_secs, sprint_tag]
				elif is_warn:
					if _current_hud_mode != "WARN":
						_current_hud_mode = "WARN"
						o2_return_label.self_modulate = Color(1.0, 0.88, 0.25, 1.0)
						if _o2_hud_style:
							_o2_hud_style.border_color = Color(1.0, 0.75, 0.1, 0.95)
							_o2_hud_style.bg_color = Color(0.12, 0.08, 0.02, 0.95)
					if not _o2_caution_alerted:
						_o2_caution_alerted = true
						show_warning_toast("⚠️ DÖNÜŞ SINIRI: Yüzeye %.1fs kaldı, oksijen azalıyor!" % time_to_surf, 2.2)
					if should_update_text:
						o2_return_label.text = ("⚠️ CAUTION! Surface: %.1fs  │  O2: %.1fs%s" if is_en else "⚠️ DİKKAT! Yüzey: %.1fs  │  O2: %.1fs%s") % [time_to_surf, o2_secs, sprint_tag]
				else:
					if _current_hud_mode != "SAFE":
						_current_hud_mode = "SAFE"
						_o2_danger_alerted = false
						_o2_caution_alerted = false
						o2_return_label.self_modulate = Color(0.85, 0.96, 1.0, 1.0)
						if _o2_hud_style:
							_o2_hud_style.border_color = Color(0.18, 0.65, 0.9, 0.9)
							_o2_hud_style.bg_color = Color(0.04, 0.08, 0.14, 0.95)
					if should_update_text:
						o2_return_label.text = ("⏱️ SURFACE: %.1fs  │  🫧 O2: ~%ds%s" if is_en else "⏱️ YÜZEY: %.1fs  │  🫧 O2: ~%ds%s") % [time_to_surf, int(round(o2_secs)), sprint_tag]

			if should_update_text:
				_o2_hud_timer = 0.0

	_update_office_button_availability()


func _on_time_changed(hour: int, minute: int) -> void:
	_update_time_display(hour, minute)


func _on_day_changed(day: int) -> void:
	_update_day_display(day)


func _update_time_display(hour: int = -1, minute: int = -1) -> void:
	if not is_instance_valid(time_label):
		time_label = get_node_or_null("TimePanel/Margin/HBox/TimeLabel")
	if not is_instance_valid(time_label):
		return

	if hour < 0 or minute < 0:
		var time_mgr: Node = _get_time_mgr()
		if time_mgr:
			hour = int(time_mgr.get("current_hour"))
			minute = int(time_mgr.get("current_minute"))
		else:
			hour = 10
			minute = 0

	time_label.text = "⏰ %02d:%02d" % [hour, minute]
	if hour >= 19:
		time_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
	elif hour >= 18:
		time_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25, 1.0))
	else:
		time_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1.0))


func _update_day_display(day: int = -1) -> void:
	if not is_instance_valid(day_label):
		day_label = get_node_or_null("TimePanel/Margin/HBox/DayLabel")
	if not is_instance_valid(day_label):
		return

	if day <= 0:
		var time_mgr: Node = _get_time_mgr()
		if time_mgr:
			day = int(time_mgr.get("current_day"))
		else:
			var save_data: Dictionary = GlobalInventory.get_save_data()
			day = int(save_data.get("current_day", 1))

	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	day_label.text = ("📅 Day %d" if is_en else "📅 Gün %d") % max(1, day)


func refresh_ui() -> void:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	_update_day_display()
	_update_time_display()

	if has_node("zurna"):
		$zurna.text = tr("💰 %d Zurna") % _displayed_money

	if office_button:
		office_button.text = "🚤 Board Boat [E]" if is_en else "🚤 Tekneye Çık [E]"

	_update_bag_button()
	_update_office_button_availability()
	_refresh_equipment_panel()

	var health_lbl: Label = get_node_or_null("StatusPanel/HealthLabel")
	if health_lbl:
		health_lbl.text = "❤️ HEALTH:" if is_en else "❤️ CAN:"

	var o2_lbl: Label = get_node_or_null("StatusPanel/OxygenLabel")
	if o2_lbl:
		o2_lbl.text = "🫧 OXYGEN:" if is_en else "🫧 OKSİJEN:"

	var bat_lbl: Label = get_node_or_null("StatusPanel/BatteryLabel")
	if bat_lbl:
		bat_lbl.text = "⚡ BATTERY:" if is_en else "⚡ BATARYA:"



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_TAB:
			_on_inventory_button_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			if office_button and not office_button.disabled and office_button.modulate.a > 0.5:
				_on_button_2_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			# Ofis menüsü, geçiş ekranı veya ölüm durumu varsa duraklatma menüsü açma
			if get_tree().get_first_node_in_group("office_menu") != null or is_instance_valid(_office_loading):
				return
			if is_instance_valid(_active_inventory):
				_active_inventory.queue_free()
				_active_inventory = null
				get_viewport().set_input_as_handled()
				return
			if get_tree().get_first_node_in_group("popup_ui") != null:
				return
			if is_instance_valid(_active_pause_menu):
				return
			_toggle_pause_menu()
			get_viewport().set_input_as_handled()


func toggle_pause_menu() -> void:
	if get_tree().get_first_node_in_group("office_menu") != null or is_instance_valid(_office_loading):
		return
	if is_instance_valid(_active_inventory):
		_active_inventory.queue_free()
		_active_inventory = null
	if get_tree().get_first_node_in_group("popup_ui") != null:
		return
	_toggle_pause_menu()


func _toggle_pause_menu() -> void:
	if is_instance_valid(_active_pause_menu):
		_active_pause_menu.queue_free()
		_active_pause_menu = null
		return

	var pause_scene: PackedScene = preload("res://Scenes/pause_menu.tscn")
	_active_pause_menu = pause_scene.instantiate()
	_active_pause_menu.tree_exited.connect(func() -> void:
		_active_pause_menu = null
	)
	get_tree().current_scene.add_child(_active_pause_menu)


func _update_office_button_availability() -> void:
	if not office_button or not is_instance_valid(player_node):
		return
	var surface_y: float = InfiniteMapManager.water_surface_y
	var distance: float = abs(player_node.global_position.y - surface_y)
	var is_near_surface: bool = distance <= office_button_surface_range

	if is_near_surface:
		if office_button.disabled or office_button.modulate.a < 0.9:
			office_button.disabled = false
			if _office_btn_tween and _office_btn_tween.is_valid():
				_office_btn_tween.kill()
			_office_btn_tween = create_tween()
			_office_btn_tween.tween_property(office_button, "modulate:a", 1.0, 0.25)
	else:
		if not office_button.disabled or office_button.modulate.a > 0.05:
			office_button.disabled = true
			if _office_btn_tween and _office_btn_tween.is_valid():
				_office_btn_tween.kill()
			_office_btn_tween = create_tween()
			_office_btn_tween.tween_property(office_button, "modulate:a", 0.0, 0.25)

func _refresh_equipment_panel() -> void:
	if not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player") as Node2D
		if not is_instance_valid(player_node):
			return
	if not is_instance_valid(flashlight_level_label):
		flashlight_level_label = get_node_or_null("EquipmentDock/Margin/HBox/FlashlightSlot/Level")
	if bag_level_label:
		bag_level_label.text = "Lv." + str(player_node.get("backpack_level"))
	if goggles_level_label:
		goggles_level_label.text = "Lv." + str(player_node.get("goggles_level"))
	if fins_level_label:
		fins_level_label.text = "Lv." + str(player_node.get("fins_level"))
	if tube_level_label:
		tube_level_label.text = "Lv." + str(player_node.get("tube_level"))
	if flashlight_level_label:
		flashlight_level_label.text = "Lv." + str(player_node.get("flashlight_level"))


func _update_bag_button() -> void:
	if not invenb:
		return
	var count: int = GlobalInventory.collected_items.size()
	var cap: int = GlobalInventory.get_capacity()
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	var bag_title: String = "🎒 Bag [I] (%d/%d)" if is_en else "🎒 Çanta [I] (%d/%d)"
	invenb.text = bag_title % [count, cap]
	if count >= cap and cap > 0:
		invenb.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
	else:
		invenb.add_theme_color_override("font_color", Color(0.15, 0.10, 0.06, 1.0))


func _on_inventory_button_pressed() -> void:
	if is_instance_valid(_active_inventory):
		_active_inventory.queue_free()
		_active_inventory = null
	else:
		if inventory_scene:
			_active_inventory = inventory_scene.instantiate()
			get_tree().current_scene.add_child(_active_inventory)
			
func _apply_hud_theme() -> void:
	# ---------------------------------------------------------
	# 1. ORTAK STİL (Barlar ve Bilgi Etiketi İçin Koyu Ahşap)
	# ---------------------------------------------------------
	var dark_wood_bg = StyleBoxFlat.new()
	dark_wood_bg.bg_color = Color(0.15, 0.10, 0.06, 0.9) # Tok ve koyu kahverengi
	dark_wood_bg.set_corner_radius_all(8)
	dark_wood_bg.set_border_width_all(2)
	dark_wood_bg.border_color = Color(0.85, 0.75, 0.45, 1.0) # Krem / Eskitilmiş Altın çerçeve
	
	
	# Eşya Sayısı Etiketine (info_ItemsInBag) uyguluyoruz
	var info_bg = dark_wood_bg.duplicate()
	info_bg.content_margin_left = 12
	info_bg.content_margin_right = 12
	info_bg.content_margin_top = 4
	info_bg.content_margin_bottom = 4
	$zurna.add_theme_stylebox_override("normal", info_bg)
	$zurna.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 1.0))
	
	# ---------------------------------------------------------
	# 2. ÇANTA BUTONU (Krem zemin, Koyu Kahve çerçeve ve yazı)
	# ---------------------------------------------------------
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.85, 0.75, 0.45, 1.0) # Krem / Altın sarısı
	btn_normal.set_corner_radius_all(8)
	btn_normal.set_border_width_all(3)
	btn_normal.border_color = Color(0.15, 0.10, 0.06, 1.0) # Koyu ahşap çerçeve
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.95, 0.85, 0.55, 1.0) # Üstüne gelince parlayan açık krem
	
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.65, 0.55, 0.30, 1.0) # Tıklayınca koyulaşan renk
	
	$Button.add_theme_stylebox_override("normal", btn_normal)
	$Button.add_theme_stylebox_override("hover", btn_hover)
	$Button.add_theme_stylebox_override("pressed", btn_pressed)
	# Buton içindeki yazı rengi krem üstünde okunsun diye koyu kahve yapıldı
	$Button.add_theme_color_override("font_color", Color(0.15, 0.10, 0.06, 1.0))
	$Button.add_theme_color_override("font_hover_color", Color(0.15, 0.10, 0.06, 1.0))
	$Button.add_theme_color_override("font_pressed_color", Color(0.95, 0.9, 0.8, 1.0))
	
	$Button2.add_theme_stylebox_override("normal", btn_normal)
	$Button2.add_theme_stylebox_override("hover", btn_hover)
	$Button2.add_theme_stylebox_override("pressed", btn_pressed)
	# Buton içindeki yazı rengi krem üstünde okunsun diye koyu kahve yapıldı
	$Button2.add_theme_color_override("font_color", Color(0.15, 0.10, 0.06, 1.0))
	$Button2.add_theme_color_override("font_hover_color", Color(0.15, 0.10, 0.06, 1.0))
	$Button2.add_theme_color_override("font_pressed_color", Color(0.95, 0.9, 0.8, 1.0))

	var btn_disabled = StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.3, 0.3, 0.3, 0.6)
	btn_disabled.set_corner_radius_all(8)
	btn_disabled.set_border_width_all(3)
	btn_disabled.border_color = Color(0.15, 0.10, 0.06, 0.6)
	$Button2.add_theme_stylebox_override("disabled", btn_disabled)
	$Button2.add_theme_color_override("font_disabled_color", Color(0.7, 0.7, 0.7, 0.8))
	# ---------------------------------------------------------
	# 3. EKİPMAN DOCK'U (Kompakt Koyu Ahşap zemin)
	# ---------------------------------------------------------
	if has_node("EquipmentDock"):
		var dock_style = StyleBoxFlat.new()
		dock_style.bg_color = Color(0.12, 0.08, 0.04, 0.90)
		dock_style.set_corner_radius_all(8)
		dock_style.set_border_width_all(2)
		dock_style.border_color = Color(0.85, 0.75, 0.45, 0.8)
		$EquipmentDock.add_theme_stylebox_override("panel", dock_style)


func _on_button_2_pressed() -> void:
	if _office_loading != null:
		return # Loading devam ederken tekrar basılırsa ikinci bir ofis açılmasın
	if target_scene == null:
		return

	if is_instance_valid(player_node) and player_node.has_method("turn_off_flashlight"):
		player_node.turn_off_flashlight()

	if loading_scene:
		# Loading screen'i overlay olarak açar; bitince ofisi açar ve kendini temizler
		_office_loading = loading_scene.instantiate()
		_office_loading.auto_change_scene = false
		_office_loading.finished.connect(_open_office_after_loading)
		var layer := CanvasLayer.new()
		layer.name = "OfficeLoadingLayer"
		layer.add_child(_office_loading)
		get_tree().current_scene.add_child(layer)
	else:
		_open_office()


func _open_office_after_loading() -> void:
	_office_loading = null
	var layer := get_tree().current_scene.get_node_or_null("OfficeLoadingLayer")
	if layer:
		layer.queue_free()
	_open_office()


func _open_office() -> void:
	GlobalSoundManager.play_sfx("door_open")
	var shack_res: PackedScene = dock_shack_scene if dock_shack_scene else load("res://Scenes/dock_shack.tscn")
	if shack_res:
		var shack_instance = shack_res.instantiate()
		get_tree().current_scene.add_child(shack_instance)
	elif target_scene:
		var office_instance = target_scene.instantiate()
		get_tree().current_scene.add_child(office_instance)
		
func _on_money_changed(amount: Variant) -> void:
	var target_amount: int = int(amount)
	var diff: int = target_amount - _displayed_money
	if diff > 0:
		_spawn_floating_cash(diff)

	if _money_tween and _money_tween.is_valid():
		_money_tween.kill()

	var start_amount: int = _displayed_money
	_money_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_money_tween.tween_method(func(val: int) -> void:
		_displayed_money = val
		if has_node("zurna"):
			$zurna.text = tr("💰 %d Zurna") % val
	, start_amount, target_amount, 0.45)


func _spawn_floating_cash(diff: int) -> void:
	if not has_node("zurna"):
		return
	var float_label := Label.new()
	float_label.text = "+%d Zurna" % diff
	float_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	float_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	float_label.add_theme_constant_override("shadow_outline_size", 2)
	float_label.add_theme_font_size_override("font_size", 14)

	var base_pos: Vector2 = $zurna.global_position + Vector2(25.0, 42.0)
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
			tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.08)
	)
	btn.mouse_exited.connect(func() -> void:
		if is_instance_valid(btn):
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)
	btn.pressed.connect(func() -> void:
		if is_instance_valid(btn):
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)


func _on_collection_updated(item: ItemData) -> void:
	if not collection_toast_label or not item:
		return

	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	collection_toast_label.text = ("[DISCOVERY] New Discovery: %s" if is_en else "[KESIF] Yeni Kesif: %s") % ItemTranslator.get_item_name(item)
	collection_toast_label.modulate = Color(1.0, 0.95, 0.4, 1.0) # Keşif için sıcak sarı/altın

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	collection_toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(collection_toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(collection_toast_label, "modulate:a", 0.0, 1.0)


const WARNING_TOAST_TRANSLATIONS_EN: Dictionary = {
	"[!] Çok Uzaktasın! (Daha yakına yüz)": "[!] Too Far! (Swim closer)",
	"[!] Çantan Dolu! (Daha fazla eşya alamazsın)": "[!] Backpack Full! (Cannot take more items)",
	"🔦 Fenerin yok! Ofis mağazasından satın alabilirsin.": "🔦 No Flashlight! You can buy one from the office shop.",
	"⚡ Fener bataryası tükendi! Yüzeyde şarj et.": "⚡ Flashlight battery depleted! Recharge at surface.",
	"⚡ Fener bataryası tükendi!": "⚡ Flashlight battery depleted!",
	"🚨 ACİL DURUM: Oksijen yüzeye yetmeyebilir! HEMEN YÜZEYE ÇIK!": "🚨 EMERGENCY: Oxygen may not reach surface! SURFACE IMMEDIATELY!",
}


func show_warning_toast(msg: String, duration: float = 1.8) -> void:
	var target_label: Label = warning_toast_label if is_instance_valid(warning_toast_label) else collection_toast_label
	if not is_instance_valid(target_label):
		return

	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_en:
		if WARNING_TOAST_TRANSLATIONS_EN.has(msg):
			msg = WARNING_TOAST_TRANSLATIONS_EN[msg]
		elif msg.begins_with("⚠️ DÖNÜŞ SINIRI:"):
			msg = msg.replace("⚠️ DÖNÜŞ SINIRI: Yüzeye ", "⚠️ RETURN LIMIT: ").replace(" kaldı, oksijen azalıyor!", " left, oxygen running low!")
		elif msg.begins_with("🌊 ") and msg.ends_with(" denize bırakıldı."):
			var iname: String = msg.trim_prefix("🌊 ").trim_suffix(" denize bırakıldı.")
			msg = "🌊 %s dropped into sea." % iname
		else:
			msg = tr(msg)

	target_label.text = msg
	target_label.modulate = Color(1.0, 0.35, 0.35, 1.0) # Uyarı için parlak kırmızı/turuncu

	if _warning_tween and _warning_tween.is_valid():
		_warning_tween.kill()

	target_label.modulate.a = 0.0
	_warning_tween = create_tween()
	_warning_tween.tween_property(target_label, "modulate:a", 1.0, 0.15)
	_warning_tween.tween_interval(duration)
	_warning_tween.tween_property(target_label, "modulate:a", 0.0, 0.6)


func _get_time_mgr() -> Node:
	return get_node_or_null("/root/GlobalTime")
