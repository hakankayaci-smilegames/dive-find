extends Area2D
class_name InteractableItem

@export var item_data: Resource # item_data.gd (ItemData) sınıfından türetilen .tres dosyası
@export var interaction_distance: float = 250.0 # Tıklama mesafesi (piksel)
@export var popup_scene: PackedScene # Tıklanınca açılacak UI sahnesi

var _is_mouse_hovering: bool = false
var _hover_badge: Node2D = null
var _badge_label: Label = null
var _hover_tween: Tween = null
var _base_badge_y: float = 45.0


func _ready() -> void:
	add_to_group("interactable_items")

	# .tres dosyasındaki resmi sprite'a uygula
	if item_data and item_data.get("sprite"):
		if has_node("Sprite2D"):
			$Sprite2D.texture = item_data.sprite

	# Fare giriş/çıkış sinyallerini bağla
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Eşya üzerine kompakt hover rozetini oluştur
	_build_hover_badge()


func _build_hover_badge() -> void:
	# Yüksekliği Sprite boyutuna göre dinamik hesapla
	var spr: Sprite2D = get_node_or_null("Sprite2D")
	if spr and spr.texture:
		var spr_height: float = spr.texture.get_height() * spr.scale.y
		_base_badge_y = max((spr_height * 0.5) + 14.0, 30.0)
	else:
		_base_badge_y = 45.0

	_hover_badge = Node2D.new()
	_hover_badge.name = "HoverBadge"
	_hover_badge.position = Vector2(0, -_base_badge_y)
	_hover_badge.visible = false
	_hover_badge.modulate.a = 0.0
	_hover_badge.z_index = 10 # Diğer objelerin üstünde görünsün
	add_child(_hover_badge)

	var panel_container := PanelContainer.new()
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.04, 0.92) # Koyu ahşap zemin
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.75, 0.45, 0.9) # Altın kenarlık
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 4

	panel_container.add_theme_stylebox_override("panel", style)
	_hover_badge.add_child(panel_container)

	var label := Label.new()
	_badge_label = label
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	label.text = "[E] Examine  •  [Right Click] Quick Pickup" if is_en else "[E] İncele  •  [Sağ Tık] Direkt Al"
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel_container.add_child(label)

	# Paneli tam yatayda merkeze ortala
	panel_container.resized.connect(func():
		panel_container.position = -panel_container.size / 2.0
	)

	# Rozet tıklandığında da tıklamaları algıla
	panel_container.gui_input.connect(func(event: InputEvent) -> void:
		if get_tree().get_nodes_in_group("popup_ui").size() > 0:
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_check_interaction()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_check_quick_pickup()
				get_viewport().set_input_as_handled()
	)


func _on_mouse_entered() -> void:
	_is_mouse_hovering = true
	_show_hover_badge()


func _on_mouse_exited() -> void:
	_is_mouse_hovering = false
	_hide_hover_badge()


func _show_hover_badge() -> void:
	if not is_instance_valid(_hover_badge):
		return

	if is_instance_valid(_badge_label):
		var is_en: bool = ItemTranslator.get_current_locale() == "en"
		_badge_label.text = "[E] Examine  •  [Right Click] Quick Pickup" if is_en else "[E] İncele  •  [Sağ Tık] Direkt Al"

	_hover_badge.visible = true
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.tween_property(_hover_badge, "modulate:a", 1.0, 0.15)
	_hover_tween.tween_property(_hover_badge, "position:y", -_base_badge_y - 6.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _hide_hover_badge() -> void:
	if not is_instance_valid(_hover_badge):
		return

	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.tween_property(_hover_badge, "modulate:a", 0.0, 0.12)
	_hover_tween.tween_property(_hover_badge, "position:y", -_base_badge_y, 0.12)
	_hover_tween.chain().tween_callback(func():
		if not _is_mouse_hovering and is_instance_valid(_hover_badge):
			_hover_badge.visible = false
	)


# Klavye E tuşu etkileşimi
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			# Ekranda zaten açık bir PopupUI varsa bunu tüketme
			if get_tree().get_nodes_in_group("popup_ui").size() > 0:
				return

			# 1. Öncelik: Fare bu objenin üzerinde mi?
			if _is_mouse_hovering:
				_check_interaction()
				get_viewport().set_input_as_handled()
				return

			# 2. Öncelik: Fare hiçbir eşyada değilken dalgıca en yakın eşya bu mu?
			if _is_closest_item_to_player():
				_check_interaction()
				get_viewport().set_input_as_handled()


func _is_closest_item_to_player() -> bool:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return false

	var my_dist: float = global_position.distance_to(player.global_position)
	if my_dist > interaction_distance:
		return false

	# Eğer başka bir eşyanın üstünde fare duruyorsa o eşyaya öncelik verilir
	var all_items := get_tree().get_nodes_in_group("interactable_items")
	for node in all_items:
		if node is InteractableItem and node != self and node._is_mouse_hovering:
			return false

	# Menzildeki en yakın eşya olup olmadığımızı kontrol et
	for node in all_items:
		if node is InteractableItem and is_instance_valid(node) and node != self:
			var other_dist: float = node.global_position.distance_to(player.global_position)
			if other_dist < my_dist:
				return false

	return true


# Area2D'nin kendi input algılayıcısı (Fare tıklamalarını yakalar)
func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if get_tree().get_nodes_in_group("popup_ui").size() > 0:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_check_interaction()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_check_quick_pickup()
			get_viewport().set_input_as_handled()


func _check_quick_pickup() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var distance: float = global_position.distance_to(player.global_position)
		if distance <= interaction_distance:
			quick_pickup()
		else:
			# 1. Hata sesi çal
			GlobalSoundManager.play_sfx("error")
			
			# 2. HUD'a Toast bildirimi gönder
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_warning_toast"):
				hud.show_warning_toast("[!] Çok Uzaktasın! (Daha yakına yüz)")
			
			# 3. Eşya üzerinde anlık kırmızı parlama (flash) efekti
			_play_out_of_range_feedback()
	else:
		push_warning("Sahnede 'player' grubuna ait bir obje bulunamadı!")


func _check_interaction() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var distance: float = global_position.distance_to(player.global_position)
		if distance <= interaction_distance:
			_spawn_popup()
		else:
			# 1. Hata sesi çal
			GlobalSoundManager.play_sfx("error")
			
			# 2. HUD'a Toast bildirimi gönder
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_warning_toast"):
				hud.show_warning_toast("[!] Çok Uzaktasın! (Daha yakına yüz)")
			
			# 3. Eşya üzerinde anlık kırmızı parlama (flash) efekti
			_play_out_of_range_feedback()
	else:
		push_warning("Sahnede 'player' grubuna ait bir obje bulunamadı!")


func _play_out_of_range_feedback() -> void:
	if not has_node("Sprite2D"):
		return
	var spr: Sprite2D = $Sprite2D
	var tw = create_tween()
	spr.modulate = Color(1.8, 0.35, 0.35, 1.0)
	tw.tween_property(spr, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_popup() -> void:
	if popup_scene and item_data:
		# Tıklandığı an click efekti çalar
		GlobalSoundManager.play_sfx("click")
		
		var popup = popup_scene.instantiate()
		get_tree().current_scene.add_child(popup)
		
		# Popup'a hem eşya verisini hem de kendimizi yolluyoruz
		popup.setup(item_data, self)


func play_pickup_vfx_and_destroy() -> void:
	# 1. Alma sesini çal
	GlobalSoundManager.play_sfx("pickup")
	
	# 2. Partikül (VFX) efektini kodla oluştur
	var vfx = CPUParticles2D.new()
	vfx.emitting = false
	vfx.one_shot = true
	vfx.explosiveness = 1.0
	vfx.amount = 25
	vfx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	vfx.emission_sphere_radius = 20.0
	vfx.spread = 180.0
	vfx.gravity = Vector2(0, -30)
	vfx.initial_velocity_min = 50.0
	vfx.initial_velocity_max = 120.0
	vfx.scale_amount_min = 2.0
	vfx.scale_amount_max = 6.0
	vfx.color = Color(1.0, 0.9, 0.6, 1.0)
	
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position
	vfx.emitting = true
	
	get_tree().create_timer(1.5).timeout.connect(vfx.queue_free)
	
	# 3. Görsel efekti ve sesi ateşledikten sonra eşyayı siliyoruz
	queue_free()


## Doğrudan çantaya atma (İnceleme popup'ı açmadan hızlı alma)
func quick_pickup() -> bool:
	if not item_data:
		return false
	
	if GlobalInventory.is_full():
		GlobalSoundManager.play_sfx("error")
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_warning_toast"):
			hud.show_warning_toast("[!] Çantan Dolu! (Daha fazla eşya alamazsın)")
		return false

	var added: bool = GlobalInventory.add_item(item_data)
	if not added:
		GlobalSoundManager.play_sfx("error")
		return false

	play_pickup_vfx_and_destroy()
	return true

