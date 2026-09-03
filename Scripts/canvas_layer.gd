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

@export_group("Ofise Dönüş Erişimi")
@export var office_button_surface_range: float = 600.0  # Yüzeyin bu kadar üstü/altında ofis butonu aktif olur
@onready var office_button: Button = $Button2

var _active_inventory: Node = null
var _office_loading: Node = null
var _toast_tween: Tween = null
var _warning_tween: Tween = null

# YENİ: Renk geçişi ve yön bulmak için hafıza değişkenleri
var _last_y: float = 0.0
var _current_color: Color = Color(0.85, 0.95, 1.0, 1.0) # Varsayılan buz mavisi

func _ready() -> void:
	add_to_group("hud")
	invenb.pressed.connect(_on_inventory_button_pressed)
	GlobalEconomy.money_changed.connect(_on_money_changed)
	$zurna.text = str(GlobalEconomy.money) + " Zurna"
	_apply_hud_theme()

	if collection_toast_label:
		collection_toast_label.modulate.a = 0.0
		GlobalInventory.collection_updated.connect(_on_collection_updated)

	_refresh_equipment_panel()
	call_deferred("_open_office_at_start")


func _open_office_at_start() -> void:
	_open_office()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and is_instance_valid(player_node):
		match event.keycode:
			KEY_F1:
				GlobalEconomy.add_money(500)
			KEY_KP_ADD:
				player_node.set("goggles_level", int(player_node.get("goggles_level")) + 1)
			KEY_KP_MULTIPLY:
				player_node.set("fins_level", int(player_node.get("fins_level")) + 1)
			KEY_KP_DIVIDE:
				player_node.set("backpack_level", int(player_node.get("backpack_level")) + 1)
			KEY_KP_3:
				player_node.set("tube_level", int(player_node.get("tube_level")) + 1)


func _process(delta: float) -> void:
	if is_instance_valid(player_node) and depth_label:
		var surface_y = InfiniteMapManager.water_surface_y
		var player_y = player_node.global_position.y
		
		var depth_pixels = max(0.0, player_y - surface_y)
		var depth_meters = int(depth_pixels / 50.0)
		
		depth_label.text = "Derinlik: " + str(depth_meters) + "m"
		
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

	_update_office_button_availability()
	_refresh_equipment_panel()


func _update_office_button_availability() -> void:
	if not office_button or not is_instance_valid(player_node):
		return
	var surface_y: float = InfiniteMapManager.water_surface_y
	var distance: float = abs(player_node.global_position.y - surface_y)
	office_button.disabled = distance > office_button_surface_range

func _refresh_equipment_panel() -> void:
	if not is_instance_valid(player_node):
		return
	if bag_level_label:
		bag_level_label.text = "Lvl " + str(player_node.get("backpack_level"))
	if goggles_level_label:
		goggles_level_label.text = "Lvl " + str(player_node.get("goggles_level"))
	if fins_level_label:
		fins_level_label.text = "Lvl " + str(player_node.get("fins_level"))
	if tube_level_label:
		tube_level_label.text = "Lvl " + str(player_node.get("tube_level"))

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
	$zurna.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
	
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
	# 3. EKİPMAN PANELİ (Yazıların okunması için Koyu Ahşap zemin)
	# ---------------------------------------------------------
	if has_node("EquipmentPanel"):
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.12, 0.08, 0.04, 0.95) # Barlardan bir tık daha koyu arka plan
		panel_style.set_corner_radius_all(12)
		panel_style.set_border_width_all(3)
		panel_style.border_color = Color(0.85, 0.75, 0.45, 1.0) # Altın/Krem çerçeve
		
		$EquipmentPanel.add_theme_stylebox_override("panel", panel_style)
		
		# Başlık rengini çerçevenin krem/altın sarısı rengiyle aynı yapıyoruz
		if has_node("EquipmentPanel/VBox/Title"):
			$EquipmentPanel/VBox/Title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45, 1.0))


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
		
func _on_money_changed(amount) -> void:
	$zurna.text = str(amount) + " Zurna"


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
