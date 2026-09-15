extends Control
class_name MapPin

signal pin_clicked(pin: MapPin)

@export var pin_id: String = ""
@export var pin_title_tr: String = ""
@export var pin_title_en: String = ""
@export_multiline var pin_desc_tr: String = ""
@export_multiline var pin_desc_en: String = ""
@export var pin_badge_color: Color = Color(0.95, 0.75, 0.25)
@export var pin_icon_emoji: String = "📍"
@export var pin_icon_texture: Texture2D
@export var target_scene: PackedScene
@export var target_action: String = ""

# Referanslar
@onready var pin_button: Button = $PinButton
@onready var pin_badge: Panel = $PinBadge
@onready var icon_label: Label = $PinBadge/IconLabel
@onready var icon_texture: TextureRect = $PinBadge/IconTexture
@onready var tooltip_card: PanelContainer = $TooltipCard
@onready var tooltip_title: Label = %TooltipTitle
@onready var tooltip_desc: Label = %TooltipDesc
@onready var tooltip_hint: Label = %TooltipHint

var _base_y: float = 0.0
var _hover_tween: Tween = null
var _pulse_tween: Tween = null
var _is_hovered: bool = false


func _ready() -> void:
	# Merkez pivot: pin alt ucu konumlandırma noktası olsun
	pivot_offset = Vector2(size.x * 0.5, size.y)
	_base_y = position.y

	# Tooltip başlangıçta gizli
	if is_instance_valid(tooltip_card):
		tooltip_card.modulate.a = 0.0
		tooltip_card.visible = false

	# Buton sinyalleri
	pin_button.pressed.connect(_on_pin_pressed)
	pin_button.mouse_entered.connect(_on_mouse_entered)
	pin_button.mouse_exited.connect(_on_mouse_exited)

	# Görsel yapılandırma
	_apply_styling()
	refresh_ui()


func _apply_styling() -> void:
	if is_instance_valid(pin_badge):
		var style: StyleBoxFlat = pin_badge.get_theme_stylebox("panel")
		if style:
			var custom_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
			custom_style.border_color = pin_badge_color
			custom_style.shadow_color = Color(pin_badge_color.r, pin_badge_color.g, pin_badge_color.b, 0.5)
			pin_badge.add_theme_stylebox_override("panel", custom_style)

	if pin_icon_texture != null and is_instance_valid(icon_texture):
		icon_texture.texture = pin_icon_texture
		icon_texture.visible = true
		if is_instance_valid(icon_label):
			icon_label.visible = false
	elif is_instance_valid(icon_label):
		icon_label.text = pin_icon_emoji
		icon_label.visible = true
		if is_instance_valid(icon_texture):
			icon_texture.visible = false


func refresh_ui() -> void:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_instance_valid(tooltip_title):
		tooltip_title.text = get_display_title()
		tooltip_title.add_theme_color_override("font_color", pin_badge_color)
	if is_instance_valid(tooltip_desc):
		tooltip_desc.text = get_display_description()
	if is_instance_valid(tooltip_hint):
		tooltip_hint.text = "▶ ENTER [CLICK]" if is_en else "▶ GİR [TIKLA]"


func get_display_title() -> String:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_en:
		return pin_title_en if not pin_title_en.is_empty() else pin_title_tr
	return pin_title_tr if not pin_title_tr.is_empty() else pin_title_en


func get_display_description() -> String:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_en:
		return pin_desc_en if not pin_desc_en.is_empty() else pin_desc_tr
	return pin_desc_tr if not pin_desc_tr.is_empty() else pin_desc_en


func _start_idle_pulse() -> void:
	# Seçenek A: Titremeyi ve piksel kaymasını önlemek için pinler kaya gibi sabit tutulur
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if is_instance_valid(pin_badge):
		pin_badge.scale = Vector2.ONE


func _on_mouse_entered() -> void:
	_is_hovered = true
	GlobalSoundManager.play_sfx("click")

	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Yukarı sıçrama ve büyüme
	_hover_tween.tween_property(self, "position:y", _base_y - 6.0, 0.2)
	_hover_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)

	# Tooltip gösterimi
	if is_instance_valid(tooltip_card):
		tooltip_card.visible = true
		_hover_tween.tween_property(tooltip_card, "modulate:a", 1.0, 0.18)


func _on_mouse_exited() -> void:
	_is_hovered = false

	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_hover_tween.tween_property(self, "position:y", _base_y, 0.2)
	_hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

	if is_instance_valid(tooltip_card):
		var fade := _hover_tween.tween_property(tooltip_card, "modulate:a", 0.0, 0.15)
		fade.finished.connect(func() -> void:
			if not _is_hovered and is_instance_valid(tooltip_card):
				tooltip_card.visible = false
		)


func _on_pin_pressed() -> void:
	GlobalSoundManager.play_sfx("click")

	# Punch feedback
	var punch := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	punch.tween_property(self, "scale", Vector2(0.92, 0.92), 0.06)
	punch.tween_property(self, "scale", Vector2(1.15 if _is_hovered else 1.0, 1.15 if _is_hovered else 1.0), 0.12)

	emit_signal("pin_clicked", self)
