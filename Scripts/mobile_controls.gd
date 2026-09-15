extends CanvasLayer
class_name MobileControls
## Mobil Dokunmatik Kontrol Katmanı
## Sol taraf: Dinamik / Analog Sanal Joystick (360 derece yüzüş)
## Sağ taraf: Akıllı İncele/Etkileşim Düğmesi (Menzildeki eşyayı açar)

@onready var interact_button: Button = $InteractButton
@onready var sprint_toggle_button: Button = get_node_or_null("SprintToggleButton")
@onready var quick_pickup_button: Button = get_node_or_null("QuickPickupButton")
@onready var joystick_area: Control = $JoystickZone
@onready var flashlight_toggle_button: Button = get_node_or_null("FlashlightToggleButton")
@onready var zoom_in_button: Button = get_node_or_null("ZoomControls/ZoomInButton")
@onready var zoom_out_button: Button = get_node_or_null("ZoomControls/ZoomOutButton")
@onready var pause_button: Button = get_node_or_null("PauseButton")

var _sprint_toggled: bool = false
var _btn_normal_style: StyleBox = null
var _btn_pressed_style: StyleBox = null
var _btn_disabled_style: StyleBox = null
var flashlight_aim_mode: int = 2 # 0: Joystick, 1: Touch, 2: Hybrid
var _aim_touch_index: int = -1
var _aim_touch_pos: Vector2 = Vector2.ZERO
var _aim_touch_active: bool = false
var _last_aim_angle: float = 0.0

# Joystick Görsel ve Boyut Parametreleri
var _touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_current: Vector2 = Vector2.ZERO
var _joystick_active: bool = false
var joystick_scale: float = 1.0
var current_radius: float = 70.0
var current_deadzone: float = 8.0

var move_vector: Vector2 = Vector2.ZERO
var _player: Node2D = null


func _ready() -> void:
	# Yalnızca gerçek mobil platformlarda (Android/iOS) çalışır, PC editörde asla açılmaz
	if not OS.has_feature("mobile"):
		queue_free()
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_load_controls_settings()

	interact_button.pressed.connect(_on_interact_pressed)
	if sprint_toggle_button:
		_btn_normal_style = sprint_toggle_button.get_theme_stylebox("normal")
		_btn_pressed_style = sprint_toggle_button.get_theme_stylebox("pressed")
		_btn_disabled_style = sprint_toggle_button.get_theme_stylebox("disabled")
		sprint_toggle_button.pressed.connect(_on_sprint_toggle_pressed)
		_update_sprint_button_visuals()
	if flashlight_toggle_button:
		flashlight_toggle_button.pressed.connect(_on_flashlight_toggle_pressed)
		_update_flashlight_button_visuals()
	if quick_pickup_button:
		quick_pickup_button.pressed.connect(_on_quick_pickup_pressed)
	joystick_area.gui_input.connect(_on_joystick_gui_input)
	joystick_area.draw.connect(_on_joystick_draw)

	if zoom_in_button:
		zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	if zoom_out_button:
		zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
	
	# Oyuncuyu bağla
	_find_player()


func _load_controls_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		joystick_scale = float(cfg.get_value("controls", "joystick_scale", 1.0))
		flashlight_aim_mode = int(cfg.get_value("controls", "mobile_flashlight_aim", 2))
	else:
		joystick_scale = 1.0
		flashlight_aim_mode = 2
	joystick_scale = clampf(joystick_scale, 0.7, 1.5)
	current_radius = 70.0 * joystick_scale
	current_deadzone = 8.0 * joystick_scale


func _on_zoom_in_pressed() -> void:
	if is_instance_valid(_player) and _player.has_method("zoom_in"):
		_player.zoom_in()
		GlobalSoundManager.play_sfx("click")


func _on_zoom_out_pressed() -> void:
	if is_instance_valid(_player) and _player.has_method("zoom_out"):
		_player.zoom_out()
		GlobalSoundManager.play_sfx("click")


func _on_pause_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("toggle_pause_menu"):
		hud.toggle_pause_menu()


func _on_joystick_draw() -> void:
	if not _joystick_active:
		# Pasifken sol altta rehber silik bir analog göster
		var default_pos := Vector2(130.0 * joystick_scale, joystick_area.size.y - (130.0 * joystick_scale))
		joystick_area.draw_circle(default_pos, current_radius, Color(1, 1, 1, 0.06))
		joystick_area.draw_arc(default_pos, current_radius, 0, TAU, 32, Color(0.85, 0.75, 0.45, 0.2), 2.0)
		joystick_area.draw_circle(default_pos, 22.0 * joystick_scale, Color(0.85, 0.75, 0.45, 0.15))
		return

	# Dış Halka
	joystick_area.draw_circle(_joystick_center, current_radius, Color(0.05, 0.08, 0.12, 0.45))
	joystick_area.draw_arc(_joystick_center, current_radius, 0, TAU, 32, Color(0.85, 0.75, 0.45, 0.75), 2.5)

	# Yön Çizgisi
	if move_vector.length_squared() > 0.01:
		joystick_area.draw_line(_joystick_center, _joystick_current, Color(0.95, 0.85, 0.55, 0.6), 2.0)

	# İç Topuz (Handle)
	joystick_area.draw_circle(_joystick_current, 28.0 * joystick_scale, Color(0.85, 0.75, 0.45, 0.85))
	joystick_area.draw_arc(_joystick_current, 28.0 * joystick_scale, 0, TAU, 24, Color(1.0, 1.0, 1.0, 0.9), 2.0)



func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(_player):
		if "mobile_sprint_active" in _player:
			_player.mobile_sprint_active = _sprint_toggled
		if _player.has_signal("flashlight_toggled") and not _player.flashlight_toggled.is_connected(_on_player_flashlight_toggled):
			_player.flashlight_toggled.connect(_on_player_flashlight_toggled)
		_update_flashlight_button_visuals()


func _process(_delta: float) -> void:
	# Oyun duraklatılmışsa, şehir haritası/karargah/baraka veya popup açıksa kontrolleri gizle
	var is_in_hub: bool = get_tree().paused \
		or get_tree().get_nodes_in_group("popup_ui").size() > 0 \
		or get_tree().get_nodes_in_group("hub_menu").size() > 0 \
		or get_tree().get_nodes_in_group("city_map").size() > 0

	if is_in_hub:
		if visible:
			visible = false
			_reset_joystick()
		return
	elif not visible:
		visible = true

	if not is_instance_valid(_player):
		_find_player()
		return

	# Dalgıca mobil hareket vektörünü aktar
	if _player and "mobile_move_vector" in _player:
		_player.mobile_move_vector = move_vector

	# Fener yönünü ve buton görselini güncelle
	_update_flashlight_aim()
	_update_flashlight_button_visuals()

	# Oksijen bittiğinde deparı otomatik kapat
	if is_instance_valid(_player):
		var ox: float = float(_player.get("current_oxygen")) if _player.get("current_oxygen") != null else 100.0
		if ox <= 0.0 and _sprint_toggled:
			_sprint_toggled = false
			if "mobile_sprint_active" in _player:
				_player.mobile_sprint_active = false
			_update_sprint_button_visuals()

	# Menzildeki en yakın eşyayı tara ve İncele butonunu güncelle
	_update_interact_button_state()


func _update_interact_button_state() -> void:
	if not is_instance_valid(_player):
		interact_button.modulate.a = 0.35
		interact_button.disabled = true
		if is_instance_valid(quick_pickup_button):
			quick_pickup_button.modulate.a = 0.35
			quick_pickup_button.disabled = true
		return

	var closest_item: InteractableItem = _get_closest_interactable()
	if closest_item:
		interact_button.modulate.a = 1.0
		interact_button.disabled = false
		# Eşya adı varsa buton üzerinde göster
		var is_en: bool = ItemTranslator.get_current_locale() == "en"
		if closest_item.item_data and "item_name" in closest_item.item_data:
			var item_obj: ItemData = closest_item.item_data as ItemData
			var iname: String = ItemTranslator.get_item_name(item_obj) if item_obj else str(closest_item.item_data.item_name)
			interact_button.text = "🖐️ " + iname
		else:
			interact_button.text = "🖐️ EXAMINE" if is_en else "🖐️ İNCELE"

		if is_instance_valid(quick_pickup_button):
			quick_pickup_button.modulate.a = 1.0
			if GlobalInventory.is_full():
				quick_pickup_button.disabled = true
				quick_pickup_button.text = "❌ FULL" if is_en else "❌ DOLU"
			else:
				quick_pickup_button.disabled = false
				quick_pickup_button.text = "⚡ QUICK PICKUP" if is_en else "⚡ DİREKT AL"
	else:
		var is_en: bool = ItemTranslator.get_current_locale() == "en"
		interact_button.modulate.a = 0.4
		interact_button.disabled = true
		interact_button.text = "🖐️ EXAMINE" if is_en else "🖐️ İNCELE"
		if is_instance_valid(quick_pickup_button):
			quick_pickup_button.modulate.a = 0.4
			quick_pickup_button.disabled = true
			quick_pickup_button.text = tr("⚡ DİREKT AL")


func _get_closest_interactable() -> InteractableItem:
	if not is_instance_valid(_player):
		return null

	var items = get_tree().get_nodes_in_group("interactable_items")
	var closest: InteractableItem = null
	var min_dist: float = 250.0 # interaction_distance

	for node in items:
		if node is InteractableItem and is_instance_valid(node):
			var dist: float = node.global_position.distance_to(_player.global_position)
			if dist <= node.interaction_distance and dist < min_dist:
				min_dist = dist
				closest = node

	return closest


func _on_interact_pressed() -> void:
	# Açık popup varsa kapat veya tüket
	if get_tree().get_nodes_in_group("popup_ui").size() > 0:
		return

	var target_item: InteractableItem = _get_closest_interactable()
	if target_item and is_instance_valid(target_item):
		target_item._check_interaction()


func _on_quick_pickup_pressed() -> void:
	# Açık popup varsa tüketme
	if get_tree().get_nodes_in_group("popup_ui").size() > 0:
		return

	var target_item: InteractableItem = _get_closest_interactable()
	if target_item and is_instance_valid(target_item):
		target_item.quick_pickup()
		_update_interact_button_state()


func _on_sprint_toggle_pressed() -> void:
	_sprint_toggled = not _sprint_toggled
	GlobalSoundManager.play_sfx("click")
	if is_instance_valid(_player) and "mobile_sprint_active" in _player:
		_player.mobile_sprint_active = _sprint_toggled
	_update_sprint_button_visuals()


func _update_sprint_button_visuals() -> void:
	if not is_instance_valid(sprint_toggle_button):
		return

	if _sprint_toggled:
		sprint_toggle_button.text = tr("⚡ AÇIK")
		sprint_toggle_button.modulate = Color(1.3, 1.15, 0.4, 1.0)
		if _btn_pressed_style:
			sprint_toggle_button.add_theme_stylebox_override("normal", _btn_pressed_style)
	else:
		sprint_toggle_button.text = tr("⚡ DEPAR")
		sprint_toggle_button.modulate = Color(1.0, 1.0, 1.0, 0.85)
		if _btn_normal_style:
			sprint_toggle_button.add_theme_stylebox_override("normal", _btn_normal_style)


func _on_flashlight_toggle_pressed() -> void:
	if is_instance_valid(_player) and _player.has_method("toggle_flashlight"):
		_player.toggle_flashlight()
		_update_flashlight_button_visuals()


func _on_player_flashlight_toggled(_is_on: bool) -> void:
	_update_flashlight_button_visuals()


func _update_flashlight_button_visuals() -> void:
	if not is_instance_valid(flashlight_toggle_button):
		return
	if not is_instance_valid(_player):
		return

	var fl_level: int = int(_player.get("flashlight_level")) if _player.get("flashlight_level") != null else 0
	if fl_level <= 0:
		flashlight_toggle_button.text = tr("🔦 YOK")
		flashlight_toggle_button.disabled = true
		flashlight_toggle_button.modulate = Color(1.0, 1.0, 1.0, 0.35)
		if _btn_disabled_style:
			flashlight_toggle_button.add_theme_stylebox_override("normal", _btn_disabled_style)
		elif _btn_normal_style:
			flashlight_toggle_button.add_theme_stylebox_override("normal", _btn_normal_style)
		return

	flashlight_toggle_button.disabled = false
	var is_on: bool = bool(_player.get("is_flashlight_on"))
	if is_on:
		flashlight_toggle_button.text = tr("🔦 AÇIK")
		flashlight_toggle_button.modulate = Color(1.4, 1.25, 0.45, 1.0)
		if _btn_pressed_style:
			flashlight_toggle_button.add_theme_stylebox_override("normal", _btn_pressed_style)
	else:
		flashlight_toggle_button.text = tr("🔦 FENER")
		flashlight_toggle_button.modulate = Color(1.0, 1.0, 1.0, 0.85)
		if _btn_normal_style:
			flashlight_toggle_button.add_theme_stylebox_override("normal", _btn_normal_style)


func _on_joystick_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_joystick_center = event.position
			_joystick_current = event.position
			_joystick_active = true
			joystick_area.queue_redraw()
		elif not event.pressed and event.index == _touch_index:
			_reset_joystick()

	elif event is InputEventScreenDrag and event.index == _touch_index:
		var diff: Vector2 = event.position - _joystick_center
		var dist: float = diff.length()

		if dist > current_radius:
			_joystick_current = _joystick_center + diff.normalized() * current_radius
		else:
			_joystick_current = event.position

		if dist > current_deadzone:
			move_vector = diff.normalized() * clampf((dist - current_deadzone) / (current_radius - current_deadzone), 0.0, 1.0)
		else:
			move_vector = Vector2.ZERO

		joystick_area.queue_redraw()

	# PC'de fare ile test desteği (emulate_touch aktif değilse bile çalışır)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _touch_index == -1:
				_touch_index = 999
				_joystick_center = event.position
				_joystick_current = event.position
				_joystick_active = true
				joystick_area.queue_redraw()
			elif not event.pressed and _touch_index == 999:
				_reset_joystick()

	elif event is InputEventMouseMotion and _touch_index == 999:
		var diff: Vector2 = event.position - _joystick_center
		var dist: float = diff.length()
		if dist > current_radius:
			_joystick_current = _joystick_center + diff.normalized() * current_radius
		else:
			_joystick_current = event.position

		if dist > current_deadzone:
			move_vector = diff.normalized() * clampf((dist - current_deadzone) / (current_radius - current_deadzone), 0.0, 1.0)
		else:
			move_vector = Vector2.ZERO

		joystick_area.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_player):
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			# Joystick bölgesinin sağındaki dokunmaları fener hedefi olarak al
			if _aim_touch_index == -1 and event.position.x > 320.0:
				_aim_touch_index = event.index
				_aim_touch_pos = event.position
				_aim_touch_active = true
		elif not event.pressed and event.index == _aim_touch_index:
			_aim_touch_active = false
			_aim_touch_index = -1

	elif event is InputEventScreenDrag:
		if event.index == _aim_touch_index:
			_aim_touch_pos = event.position
			_aim_touch_active = true

	# PC/Editor test desteği
	elif event is InputEventMouseButton and _touch_index != 999:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and event.position.x > 320.0:
				_aim_touch_active = true
				_aim_touch_pos = event.position
			elif not event.pressed:
				_aim_touch_active = false

	elif event is InputEventMouseMotion and _aim_touch_active:
		_aim_touch_pos = event.position


func _update_flashlight_aim() -> void:
	if not is_instance_valid(_player):
		return

	var fl_level: int = int(_player.get("flashlight_level")) if _player.get("flashlight_level") != null else 0
	if fl_level <= 0:
		_player.has_mobile_aim = false
		return

	var touch_angle_valid: bool = false
	var touch_angle: float = 0.0

	if _aim_touch_active:
		var player_screen_pos: Vector2 = _player.get_global_transform_with_canvas().origin
		var diff: Vector2 = _aim_touch_pos - player_screen_pos
		if diff.length_squared() > 100.0:
			touch_angle = diff.angle()
			touch_angle_valid = true

	var move_active: bool = move_vector.length_squared() > 0.01
	var move_angle: float = move_vector.angle() if move_active else _last_aim_angle

	match flashlight_aim_mode:
		0: # 🕹️ Yüzüş Yönü (Joystick)
			if move_active:
				_last_aim_angle = move_angle
			_player.mobile_aim_angle = _last_aim_angle
			_player.has_mobile_aim = true

		1: # 👆 Dokunmatik (Serbest Aim)
			if touch_angle_valid:
				_last_aim_angle = touch_angle
			_player.mobile_aim_angle = _last_aim_angle
			_player.has_mobile_aim = true

		2: # ✨ Akıllı Hibrit (Joystick + Dokunma)
			if touch_angle_valid:
				_last_aim_angle = touch_angle
			elif move_active:
				_last_aim_angle = move_angle
			_player.mobile_aim_angle = _last_aim_angle
			_player.has_mobile_aim = true

		_:
			if move_active:
				_last_aim_angle = move_angle
			_player.mobile_aim_angle = _last_aim_angle
			_player.has_mobile_aim = true


func _reset_joystick() -> void:
	_touch_index = -1
	_joystick_active = false
	move_vector = Vector2.ZERO
	_aim_touch_active = false
	_aim_touch_index = -1
	if is_instance_valid(_player) and "mobile_move_vector" in _player:
		_player.mobile_move_vector = Vector2.ZERO
	joystick_area.queue_redraw()
