extends CanvasLayer

@export var inventory_scene: PackedScene 
@export var invenb: Button

@export var player_node: Node2D 
@export var depth_label: Label 
@export var target_scene: PackedScene
@export var loading_scene: PackedScene # Ofise geçişten önce gösterilecek loading screen (overlay)

@export_group("Ekipman Paneli")
@export var bag_level_label: Label
@export var goggles_level_label: Label
@export var fins_level_label: Label
@export var tube_level_label: Label

@export_group("Koleksiyon Bildirimi")
@export var collection_toast_label: Label  # Sağ üst köşede, 3-4sn görünüp solan bildirim
@export var warning_toast_label: Label     # Mesafe/hata uyarıları için dinamik toast

@export_group("Zaman & Gün Göstergesi")
@export var time_label: Label
@export var day_label: Label

@export_group("Ofise Dönüş Erişimi")
@export var office_button_surface_range: float = 600.0  # Yüzeyin bu kadar üstü/altında ofis butonu aktif olur
@onready var office_button: Button = $Button2

var _active_inventory: Node = null
var _office_loading: Node = null
var _toast_tween: Tween = null
var _warning_tween: Tween = null
var _displayed_money: int = 0
var _money_tween: Tween = null
var _office_btn_tween: Tween = null

# YENİ: Renk geçişi ve yön bulmak için hafıza değişkenleri
var _last_y: float = 0.0
var _current_color: Color = Color(0.85, 0.95, 1.0, 1.0) # Varsayılan buz mavisi

func _ready() -> void:
	add_to_group("hud")
	invenb.pressed.connect(_on_inventory_button_pressed)
	GlobalEconomy.money_changed.connect(_on_money_changed)
	_displayed_money = GlobalEconomy.money
	$zurna.text = "💰 %d Zurna" % _displayed_money
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

	if collection_toast_label:
		collection_toast_label.modulate.a = 0.0
		GlobalInventory.collection_updated.connect(_on_collection_updated)

	GlobalInventory.inventory_updated.connect(_update_bag_button)
	_update_bag_button()
	_refresh_equipment_panel()
	call_deferred("_open_office_at_start")


func _open_office_at_start() -> void:
	_open_office()


func _process(delta: float) -> void:
	if is_instance_valid(player_node) and depth_label:
		var surface_y = InfiniteMapManager.water_surface_y
		var player_y = player_node.global_position.y
		
		var depth_pixels = max(0.0, player_y - surface_y)
		var depth_meters = int(depth_pixels / 50.0)
		
		if depth_meters <= 0:
			depth_label.text = "⚓ YÜZEYDESİN (0m)"
		else:
			depth_label.text = "⚓ %dm  |  ↑ Yüzey: %dm" % [depth_meters, depth_meters]
		
		# --- DİNAMİK RENK GEÇİŞİ MANTIĞI ---
		var target_color = Color(0.85, 0.95, 1.0, 1.0) # Hareketsizken sabit mavi
		
		# Pozisyon yerine doğrudan oyuncunun dikey hızını (velocity.y) okuyoruz.
		# Bu sayede FPS dalgalanmalarından etkilenmez, kusursuz çalışır.
		var y_velocity = player_node.velocity.y
		
		# Hız eşiğini +/- 15.0 yaptık ki animasyon veya küçük sekmelerden etkilenmesin
		if y_velocity < -15.0: 
			# Yukarı çıkıyor -> Fosforlu/Açık Yeşil
			target_color = Color(0.2, 0.9, 0.3, 1.0)
			
		elif y_velocity > 15.0: 
			# Aşağı batıyor -> Kırmızı (Derinliğe göre koyulaşır)
			var depth_factor = clamp(float(depth_meters) / 500.0, 0.0, 0.8) 
			target_color = Color(1.0, 0.2, 0.2, 1.0).lerp(Color(0.3, 0.0, 0.0, 1.0), depth_factor)
			
		# Rengi delta ile yumuşakça harmanlıyoruz
		_current_color = _current_color.lerp(target_color, 6.0 * delta)
		
		# Hesaplanan yeni rengi Label'ın yazı rengi olarak uyguluyoruz
		depth_label.add_theme_color_override("font_color", _current_color)

		var time_mgr: Node = _get_time_mgr()
		if time_mgr:
			time_mgr.record_depth(float(depth_meters))

		# Kritik Oksijen Nabız Uyarısı (< %25)
		if has_node("StatusPanel/Oxygen"):
			var ox: float = float(player_node.get("current_oxygen")) if player_node.get("current_oxygen") != null else 100.0
			if ox < 25.0:
				var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
				$StatusPanel/Oxygen.modulate = Color(1.0, 0.2 + 0.8 * pulse, 0.2 + 0.8 * pulse, 1.0)
			else:
				$StatusPanel/Oxygen.modulate = Color.WHITE

	_update_office_button_availability()
	_refresh_equipment_panel()


func _on_time_changed(hour: int, minute: int) -> void:
	_update_time_display(hour, minute)


func _on_day_changed(day: int) -> void:
	_update_day_display(day)


func _update_time_display(hour: int, minute: int) -> void:
	if not time_label:
		return
	time_label.text = "⏰ %02d:%02d" % [hour, minute]
	if hour >= 19:
		time_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
	elif hour >= 18:
		time_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25, 1.0))
	else:
		time_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1.0))


func _update_day_display(day: int) -> void:
	if not day_label:
		return
	day_label.text = "📅 Gün %d" % day


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_TAB:
			_on_inventory_button_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			if office_button and not office_button.disabled and office_button.modulate.a > 0.5:
				_on_button_2_pressed()
				get_viewport().set_input_as_handled()


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
		return
	if bag_level_label:
		bag_level_label.text = "Lv." + str(player_node.get("backpack_level"))
	if goggles_level_label:
		goggles_level_label.text = "Lv." + str(player_node.get("goggles_level"))
	if fins_level_label:
		fins_level_label.text = "Lv." + str(player_node.get("fins_level"))
	if tube_level_label:
		tube_level_label.text = "Lv." + str(player_node.get("tube_level"))


func _update_bag_button() -> void:
	if not invenb:
		return
	var count: int = GlobalInventory.collected_items.size()
	var cap: int = GlobalInventory.get_capacity()
	invenb.text = "🎒 Çanta [I] (%d/%d)" % [count, cap]
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
	if target_scene == null:
		return
	GlobalSoundManager.play_sfx("door_open")
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
			$zurna.text = "💰 %d Zurna" % val
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

	collection_toast_label.text = "[KESIF] Yeni Kesif: %s" % item.item_name
	collection_toast_label.modulate = Color(1.0, 0.95, 0.4, 1.0) # Keşif için sıcak sarı/altın

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	collection_toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(collection_toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(collection_toast_label, "modulate:a", 0.0, 1.0)


func show_warning_toast(msg: String, duration: float = 1.8) -> void:
	var target_label: Label = warning_toast_label if is_instance_valid(warning_toast_label) else collection_toast_label
	if not is_instance_valid(target_label):
		return

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
