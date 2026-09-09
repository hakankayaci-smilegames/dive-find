extends CanvasLayer

const SETTINGS_SCENE := preload("res://Scenes/settings_menu.tscn")
const MAIN_MENU_PATH := "res://Scenes/main_menu.tscn"

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

var _active_confirm_dialog: CanvasLayer = null
var _active_settings: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	get_tree().paused = true

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	_setup_button_juice(resume_button)
	_setup_button_juice(settings_button)
	_setup_button_juice(quit_button)


func _exit_tree() -> void:
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(_active_confirm_dialog):
				_active_confirm_dialog.queue_free()
				_active_confirm_dialog = null
				get_viewport().set_input_as_handled()
				return
			elif is_instance_valid(_active_settings):
				_active_settings.queue_free()
				_active_settings = null
				get_viewport().set_input_as_handled()
				return
			else:
				_on_resume_pressed()
				get_viewport().set_input_as_handled()
				return


func _on_resume_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	get_tree().paused = false
	queue_free()


func _on_settings_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	if is_instance_valid(_active_settings):
		_active_settings.queue_free()
		_active_settings = null
		return
	_active_settings = SETTINGS_SCENE.instantiate()
	_active_settings.tree_exited.connect(func() -> void:
		_active_settings = null
	)
	add_child(_active_settings)


func _on_quit_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	_show_quit_confirmation()


func _show_quit_confirmation() -> void:
	if is_instance_valid(_active_confirm_dialog):
		_active_confirm_dialog.queue_free()
		_active_confirm_dialog = null

	var confirm_layer := CanvasLayer.new()
	confirm_layer.layer = 135
	confirm_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_active_confirm_dialog = confirm_layer

	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 220)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	panel_style.border_color = Color(0.85, 0.75, 0.45, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel_style.shadow_color = Color(0, 0, 0, 0.7)
	panel_style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "⚠️ DALIŞTAN ÇIKILSIN MI?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Bu dalışta topladığın ganimetler kaydedilmeyecektir!\nSon ofis kayıt durumuna geri dönülecektir.\n\nAna menüye dönmek istediğinden emin misin?"
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
	cancel_btn.text = "DALIŞA DÖN"
	cancel_btn.custom_minimum_size = Vector2(160, 42)
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
		_active_confirm_dialog = null
	)
	hbox.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "EVET, ÇIK 🚪"
	confirm_btn.custom_minimum_size = Vector2(160, 42)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.48, 0.12, 0.1, 0.95)
	confirm_style.border_color = Color(0.85, 0.35, 0.35, 1.0)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.pressed.connect(func():
		GlobalSoundManager.play_sfx("door_close")
		confirm_layer.queue_free()
		_active_confirm_dialog = null
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_MENU_PATH)
	)
	hbox.add_child(confirm_btn)

	add_child(confirm_layer)


func _setup_button_juice(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size / 2.0
	)
	btn.mouse_entered.connect(func() -> void:
		GlobalSoundManager.play_sfx("click")
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.08)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)
