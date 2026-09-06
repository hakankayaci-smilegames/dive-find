extends Button
class_name InventorySlot

signal slot_clicked(item_data: Resource)
signal slot_hovered(item_data: Resource)
signal slot_unhovered(item_data: Resource)
signal slot_lock_toggled(item_data: Resource)

var _item_data: Resource
var is_selected: bool = false

@onready var lock_badge: Label = get_node_or_null("LockBadge")
@onready var selected_border: Panel = get_node_or_null("SelectedBorder")

# Kategori renk tablosu
const CATEGORY_COLORS: Dictionary = {
	"Trash": Color(0.65, 0.65, 0.65, 0.9),       # Gri (Çöp)
	"Resource": Color(0.25, 0.75, 0.95, 0.9),    # Cyan / Mavi (Hammadde)
	"Rare Found": Color(0.75, 0.40, 0.95, 0.9),  # Mor (Nadir Buluntu)
	"Valuable": Color(0.95, 0.80, 0.20, 0.9),    # Altın Sarısı (Değerli)
	"Special": Color(0.95, 0.30, 0.45, 0.9),     # Mercan / Kırmızı (Özel)
	"Crafted": Color(1.0, 0.55, 0.15, 0.9),      # Amber / Turuncu (Üretilmiş)
}
const DEFAULT_BG_COLOR := Color(0.2, 0.2, 0.2, 0.9)


func _ready() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func setup(data: Resource) -> void:
	_item_data = data
	set_selected(false)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

	if _item_data:
		# İkonu yerleştir
		if _item_data.get("sprite"):
			$ItemIcon.texture = _item_data.get("sprite")

		# Kategoriye göre arka plan rengini ver
		var category: String = str(_item_data.get("category"))
		$RarityBackground.color = CATEGORY_COLORS.get(category, DEFAULT_BG_COLOR)

		_update_lock_display()


func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected_border:
		selected_border.visible = selected


func get_item_data() -> Resource:
	return _item_data


func _on_mouse_entered() -> void:
	if _item_data:
		slot_hovered.emit(_item_data)


func _on_mouse_exited() -> void:
	if _item_data:
		slot_unhovered.emit(_item_data)



var _press_timer: float = 0.0
var _is_pressing: bool = false
var _long_pressed_triggered: bool = false
const LONG_PRESS_DURATION: float = 0.35


func _process(delta: float) -> void:
	if _is_pressing and not _long_pressed_triggered:
		_press_timer += delta
		if _press_timer >= LONG_PRESS_DURATION:
			_long_pressed_triggered = true
			toggle_lock()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			toggle_lock()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_pressing = true
				_long_pressed_triggered = false
				_press_timer = 0.0
			else:
				_is_pressing = false
	elif event is InputEventScreenTouch:
		if event.pressed:
			_is_pressing = true
			_long_pressed_triggered = false
			_press_timer = 0.0
		else:
			_is_pressing = false


func toggle_lock() -> void:
	if not _item_data:
		return
	var current_state: bool = bool(_item_data.get("is_locked"))
	_item_data.set("is_locked", not current_state)
	_update_lock_display()
	GlobalSoundManager.play_sfx("click")
	slot_lock_toggled.emit(_item_data)


func _update_lock_display() -> void:
	if not _item_data:
		if lock_badge:
			lock_badge.visible = false
		tooltip_text = ""
		return

	var is_locked: bool = bool(_item_data.get("is_locked"))
	if lock_badge:
		lock_badge.visible = is_locked

	var item_name: String = str(_item_data.get("item_name"))
	if is_locked:
		tooltip_text = "%s [🔒 KİLİTLİ]\n(Sağ tık / Basılı tut: Kilidi aç)" % item_name
	else:
		tooltip_text = "%s\n(Sağ tık / Basılı tut: Kilitle)" % item_name


func _on_pressed() -> void:
	if _long_pressed_triggered:
		return
	emit_signal("slot_clicked", _item_data)
