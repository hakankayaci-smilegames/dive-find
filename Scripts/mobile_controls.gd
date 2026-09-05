extends CanvasLayer
class_name MobileControls
## Mobil Dokunmatik Kontrol Katmanı
## Sol taraf: Dinamik / Analog Sanal Joystick (360 derece yüzüş)
## Sağ taraf: Akıllı İncele/Etkileşim Düğmesi (Menzildeki eşyayı açar)

@onready var interact_button: Button = $InteractButton
@onready var joystick_area: Control = $JoystickZone

# Joystick Görsel Parametreleri
var _touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_current: Vector2 = Vector2.ZERO
var _joystick_active: bool = false
const JOYSTICK_RADIUS: float = 70.0
const JOYSTICK_DEADZONE: float = 8.0

var move_vector: Vector2 = Vector2.ZERO
var _player: Node2D = null


func _ready() -> void:
	# Yalnızca gerçek mobil platformlarda (Android/iOS) çalışır, PC editörde asla açılmaz
	if not OS.has_feature("mobile"):
		queue_free()
		return

	visible = true
	interact_button.pressed.connect(_on_interact_pressed)
	joystick_area.gui_input.connect(_on_joystick_gui_input)
	joystick_area.draw.connect(_on_joystick_draw)
	
	# Oyuncuyu bağla
	_find_player()


func _on_joystick_draw() -> void:
	if not _joystick_active:
		# Pasifken sol altta rehber silik bir analog göster
		var default_pos := Vector2(130.0, joystick_area.size.y - 130.0)
		joystick_area.draw_circle(default_pos, JOYSTICK_RADIUS, Color(1, 1, 1, 0.06))
		joystick_area.draw_arc(default_pos, JOYSTICK_RADIUS, 0, TAU, 32, Color(0.85, 0.75, 0.45, 0.2), 2.0)
		joystick_area.draw_circle(default_pos, 22.0, Color(0.85, 0.75, 0.45, 0.15))
		return

	# Dış Halka
	joystick_area.draw_circle(_joystick_center, JOYSTICK_RADIUS, Color(0.05, 0.08, 0.12, 0.45))
	joystick_area.draw_arc(_joystick_center, JOYSTICK_RADIUS, 0, TAU, 32, Color(0.85, 0.75, 0.45, 0.75), 2.5)

	# Yön Çizgisi
	if move_vector.length_squared() > 0.01:
		joystick_area.draw_line(_joystick_center, _joystick_current, Color(0.95, 0.85, 0.55, 0.6), 2.0)

	# İç Topuz (Handle)
	joystick_area.draw_circle(_joystick_current, 28.0, Color(0.85, 0.75, 0.45, 0.85))
	joystick_area.draw_arc(_joystick_current, 28.0, 0, TAU, 24, Color(1.0, 1.0, 1.0, 0.9), 2.0)



func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_find_player()
		return

	# Dalgıca mobil hareket vektörünü aktar
	if _player and "mobile_move_vector" in _player:
		_player.mobile_move_vector = move_vector

	# Menzildeki en yakın eşyayı tara ve İncele butonunu güncelle
	_update_interact_button_state()


func _update_interact_button_state() -> void:
	if not is_instance_valid(_player):
		interact_button.modulate.a = 0.35
		interact_button.disabled = true
		return

	var closest_item: InteractableItem = _get_closest_interactable()
	if closest_item:
		interact_button.modulate.a = 1.0
		interact_button.disabled = false
		# Eşya adı varsa buton üzerinde göster
		if closest_item.item_data and "item_name" in closest_item.item_data:
			interact_button.text = "🖐️ " + str(closest_item.item_data.item_name)
		else:
			interact_button.text = "🖐️ İNCELE"
	else:
		interact_button.modulate.a = 0.4
		interact_button.disabled = true
		interact_button.text = "🖐️ İNCELE"


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

		if dist > JOYSTICK_RADIUS:
			_joystick_current = _joystick_center + diff.normalized() * JOYSTICK_RADIUS
		else:
			_joystick_current = event.position

		if dist > JOYSTICK_DEADZONE:
			move_vector = diff.normalized() * clampf((dist - JOYSTICK_DEADZONE) / (JOYSTICK_RADIUS - JOYSTICK_DEADZONE), 0.0, 1.0)
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
		if dist > JOYSTICK_RADIUS:
			_joystick_current = _joystick_center + diff.normalized() * JOYSTICK_RADIUS
		else:
			_joystick_current = event.position

		if dist > JOYSTICK_DEADZONE:
			move_vector = diff.normalized() * clampf((dist - JOYSTICK_DEADZONE) / (JOYSTICK_RADIUS - JOYSTICK_DEADZONE), 0.0, 1.0)
		else:
			move_vector = Vector2.ZERO

		joystick_area.queue_redraw()


func _reset_joystick() -> void:
	_touch_index = -1
	_joystick_active = false
	move_vector = Vector2.ZERO
	if is_instance_valid(_player) and "mobile_move_vector" in _player:
		_player.mobile_move_vector = Vector2.ZERO
	joystick_area.queue_redraw()
