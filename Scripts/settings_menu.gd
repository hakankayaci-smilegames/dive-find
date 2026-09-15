extends CanvasLayer

signal closed

const SETTINGS_FILE := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const DEV_SECRET_CODE: String = "mercedesforever"

@onready var close_button: Button = %CloseButton
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var autosave_check: CheckButton = %AutosaveCheck
@onready var language_row: HBoxContainer = get_node_or_null("%LanguageRow")
@onready var language_label: Label = get_node_or_null("%LanguageLabel")
@onready var language_option: OptionButton = get_node_or_null("%LanguageOption")
@onready var joystick_row: HBoxContainer = %JoystickRow
@onready var joystick_slider: HSlider = %JoystickSlider
@onready var joystick_val_label: Label = %JoystickValueLabel
@onready var flashlight_aim_row: HBoxContainer = %FlashlightAimRow
@onready var flashlight_aim_option: OptionButton = %FlashlightAimOption
@onready var reset_collection_button: Button = %ResetCollectionButton
@onready var dev_code_input: LineEdit = %DevCodeInput
@onready var dev_code_button: Button = %DevCodeButton

var _active_confirm_dialog: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 129
	add_to_group("popup_ui")

	close_button.pressed.connect(_on_close_pressed)

	_ensure_audio_buses()
	_load_settings()

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if is_instance_valid(autosave_check):
		autosave_check.toggled.connect(_on_autosave_toggled)
	reset_collection_button.pressed.connect(_on_reset_collection_pressed)

	if is_instance_valid(language_option):
		language_option.item_selected.connect(_on_language_selected)

	if is_instance_valid(dev_code_button):
		dev_code_button.pressed.connect(_on_dev_code_submitted)
	if is_instance_valid(dev_code_input):
		dev_code_input.text_submitted.connect(func(_text: String) -> void:
			_on_dev_code_submitted()
		)

	if not OS.has_feature("mobile"):
		if is_instance_valid(joystick_row):
			joystick_row.visible = false
		if is_instance_valid(flashlight_aim_row):
			flashlight_aim_row.visible = false
	else:
		if is_instance_valid(joystick_slider):
			joystick_slider.value_changed.connect(_on_joystick_slider_changed)
		if is_instance_valid(flashlight_aim_option):
			flashlight_aim_option.item_selected.connect(_on_flashlight_aim_selected)

	_setup_button(close_button)
	_setup_button(reset_collection_button)
	_setup_button(dev_code_button)

	refresh_ui()


func refresh_ui() -> void:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	var title_lbl: Label = get_node_or_null("SettingsPanel/TitleLabel")
	if title_lbl:
		title_lbl.text = "SETTINGS" if is_en else "AYARLAR"

	var music_lbl: Label = get_node_or_null("SettingsPanel/Content/MusicRow/MusicLabel")
	if music_lbl:
		music_lbl.text = "Music Volume" if is_en else "Müzik Sesi"

	var sfx_lbl: Label = get_node_or_null("SettingsPanel/Content/SfxRow/SfxLabel")
	if sfx_lbl:
		sfx_lbl.text = "Sound Effects" if is_en else "Ses Efektleri"

	var fs_lbl: Label = get_node_or_null("SettingsPanel/Content/FullscreenRow/FullscreenLabel")
	if fs_lbl:
		fs_lbl.text = "Fullscreen" if is_en else "Tam Ekran"

	var autosave_lbl: Label = get_node_or_null("SettingsPanel/Content/AutosaveRow/AutosaveLabel")
	if autosave_lbl:
		autosave_lbl.text = "Auto-Save" if is_en else "Otomatik Kayıt"

	var lang_lbl: Label = get_node_or_null("SettingsPanel/Content/LanguageRow/LanguageLabel")
	if lang_lbl:
		lang_lbl.text = "Language" if is_en else "Dil"

	if is_instance_valid(language_option):
		language_option.select(1 if is_en else 0)

	var joy_lbl: Label = get_node_or_null("SettingsPanel/Content/JoystickRow/JoystickLabel")
	if joy_lbl:
		joy_lbl.text = "Touch Joystick Size" if is_en else "Joystick Boyutu"

	var aim_lbl: Label = get_node_or_null("SettingsPanel/Content/FlashlightAimRow/FlashlightAimLabel")
	if aim_lbl:
		aim_lbl.text = "Mobile Flashlight Aim" if is_en else "Mobil Fener Yönü"

	var coll_lbl: Label = get_node_or_null("SettingsPanel/Content/CollectionRow/CollectionLabel")
	if coll_lbl:
		coll_lbl.text = "Collection" if is_en else "Koleksiyon"

	if reset_collection_button:
		reset_collection_button.text = "RESET COLLECTION" if is_en else "KOLEKSİYONU SIFIRLA"

	var dev_code_lbl: Label = get_node_or_null("SettingsPanel/Content/DevCodeRow/DevCodeLabel")
	if dev_code_lbl:
		dev_code_lbl.text = "DevCode"

	if is_instance_valid(flashlight_aim_option) and flashlight_aim_option.item_count >= 3:
		flashlight_aim_option.set_item_text(0, "🕹️ Swim Direction (Joystick)" if is_en else "🕹️ Yüzüş Yönü (Joystick)")
		flashlight_aim_option.set_item_text(1, "👆 Free Touch Aim" if is_en else "👆 Dokunmatik (Serbest Aim)")
		flashlight_aim_option.set_item_text(2, "✨ Smart Hybrid (Joystick + Touch)" if is_en else "✨ Akıllı Hibrit (Joystick + Dokunma)")

	_refresh_dev_code_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(_active_confirm_dialog):
				_active_confirm_dialog.queue_free()
				_active_confirm_dialog = null
				get_viewport().set_input_as_handled()
			else:
				_on_close_pressed()
				get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	closed.emit()
	queue_free()


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) < 0:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, MUSIC_BUS)
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index(SFX_BUS) < 0:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, SFX_BUS)
		AudioServer.set_bus_send(idx, "Master")


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var music := 70.0
	var sfx := 80.0
	var fullscreen := true
	var autosave := true
	var joystick_scale := 1.0
	var flashlight_aim := 2
	var language := "tr"
	if cfg.load(SETTINGS_FILE) == OK:
		music = cfg.get_value("audio", "music", music)
		sfx = cfg.get_value("audio", "sfx", sfx)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
		autosave = bool(cfg.get_value("general", "autosave_enabled", cfg.get_value("general", "autosave_on_transition", autosave)))
		joystick_scale = cfg.get_value("controls", "joystick_scale", joystick_scale)
		flashlight_aim = int(cfg.get_value("controls", "mobile_flashlight_aim", flashlight_aim))
		language = cfg.get_value("general", "language", language)

	_set_bus_volume(MUSIC_BUS, music)
	_set_bus_volume(SFX_BUS, sfx)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

	music_slider.value = music
	sfx_slider.value = sfx
	fullscreen_check.set_pressed_no_signal(fullscreen)
	if is_instance_valid(autosave_check):
		autosave_check.set_pressed_no_signal(autosave)
	if GlobalInventory.has_method("set_autosave_enabled"):
		GlobalInventory.set_autosave_enabled(autosave)
	if is_instance_valid(joystick_slider):
		joystick_slider.value = joystick_scale
	if is_instance_valid(joystick_val_label):
		joystick_val_label.text = "%%%d" % [int(round(joystick_scale * 100.0))]
	if is_instance_valid(flashlight_aim_option):
		flashlight_aim_option.select(clampi(flashlight_aim, 0, 2))
	if is_instance_valid(language_option):
		var is_en: bool = TranslationServer.get_locale().begins_with("en") or language == "en"
		language_option.select(1 if is_en else 0)

	_refresh_dev_code_ui()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	var current_lang := "en" if TranslationServer.get_locale().begins_with("en") else "tr"
	cfg.set_value("general", "language", current_lang)
	cfg.set_value("audio", "music", music_slider.value)
	cfg.set_value("audio", "sfx", sfx_slider.value)
	cfg.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	if is_instance_valid(autosave_check):
		cfg.set_value("general", "autosave_enabled", autosave_check.button_pressed)
		if GlobalInventory.has_method("set_autosave_enabled"):
			GlobalInventory.set_autosave_enabled(autosave_check.button_pressed)
	if is_instance_valid(joystick_slider):
		cfg.set_value("controls", "joystick_scale", joystick_slider.value)
	if is_instance_valid(flashlight_aim_option):
		cfg.set_value("controls", "mobile_flashlight_aim", flashlight_aim_option.selected)
	cfg.save(SETTINGS_FILE)


func _on_autosave_toggled(on: bool) -> void:
	GlobalSoundManager.play_sfx("click")
	if GlobalInventory.has_method("set_autosave_enabled"):
		GlobalInventory.set_autosave_enabled(on)
	_save_settings()


func _on_language_selected(index: int) -> void:
	GlobalSoundManager.play_sfx("click")
	var new_locale := "en" if index == 1 else "tr"
	TranslationServer.set_locale(new_locale)
	_save_settings()
	refresh_ui()
	var dev_console = get_node_or_null("/root/DevConsole")
	if dev_console and dev_console.has_method("refresh_active_uis"):
		dev_console.refresh_active_uis()


func _on_music_changed(value: float) -> void:
	_set_bus_volume(MUSIC_BUS, value)
	_save_settings()


func _on_sfx_changed(value: float) -> void:
	_set_bus_volume(SFX_BUS, value)
	_save_settings()


func _on_fullscreen_toggled(on: bool) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _on_joystick_slider_changed(value: float) -> void:
	if is_instance_valid(joystick_val_label):
		joystick_val_label.text = "%%%d" % [int(round(value * 100.0))]
	_save_settings()


func _on_flashlight_aim_selected(_index: int) -> void:
	_save_settings()


func _set_bus_volume(bus_name: String, percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if percent <= 0.0:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -60.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(percent / 100.0))


func _refresh_dev_code_ui() -> void:
	if not is_instance_valid(dev_code_input) or not is_instance_valid(dev_code_button):
		return
	var dev_console = get_node_or_null("/root/DevConsole")
	var is_unlocked: bool = dev_console.is_dev_console_unlocked() if dev_console and dev_console.has_method("is_dev_console_unlocked") else false
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_unlocked:
		dev_code_input.text = ""
		dev_code_input.placeholder_text = "ACTIVE ✅" if is_en else "AKTİF ✅"
		dev_code_button.text = "DISABLE" if is_en else "KAPAT"
		dev_code_button.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4, 1.0))
	else:
		dev_code_input.text = ""
		dev_code_input.placeholder_text = "Secret code..." if is_en else "Gizli kod..."
		dev_code_button.text = "ACTIVATE" if is_en else "AKTİF ET"
		dev_code_button.remove_theme_color_override("font_color")


func _on_dev_code_submitted() -> void:
	if not is_instance_valid(dev_code_input) or not is_instance_valid(dev_code_button):
		return
	var dev_console = get_node_or_null("/root/DevConsole")
	if not dev_console:
		return

	var is_unlocked: bool = dev_console.is_dev_console_unlocked() if dev_console.has_method("is_dev_console_unlocked") else false
	var entered_code: String = dev_code_input.text.strip_edges()

	if is_unlocked and (entered_code == "" or entered_code == DEV_SECRET_CODE):
		if dev_console.has_method("set_dev_unlocked"):
			dev_console.set_dev_unlocked(false)
		GlobalSoundManager.play_sfx("click")
		_refresh_dev_code_ui()
		return

	if entered_code == DEV_SECRET_CODE:
		if dev_console.has_method("set_dev_unlocked"):
			dev_console.set_dev_unlocked(true)
		GlobalSoundManager.play_sfx("upgrade")
		_refresh_dev_code_ui()
	else:
		GlobalSoundManager.play_sfx("error")
		var is_en: bool = ItemTranslator.get_current_locale() == "en"
		dev_code_button.text = "INVALID! ❌" if is_en else "HATALI! ❌"
		dev_code_button.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3, 1.0))
		var tw := create_tween()
		tw.tween_interval(1.2)
		tw.tween_callback(func() -> void:
			if is_instance_valid(dev_code_button):
				_refresh_dev_code_ui()
		)


func _on_reset_collection_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	_show_reset_collection_confirmation()


func _show_reset_collection_confirmation() -> void:
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
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 200)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	panel_style.border_color = Color(0.85, 0.75, 0.45, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "⚠️ RESET COLLECTION" if is_en else "⚠️ KOLEKSİYONU SIFIRLA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var desc := Label.new()
	if is_en:
		desc.text = "All discovered item records will be erased!\nThis cannot be undone.\n\nAre you sure?"
	else:
		desc.text = "Tüm keşfettiğin eşya kayıtları silinecek!\nBu işlem geri alınamaz.\n\nEmin misin?"
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
	cancel_btn.text = "CANCEL" if is_en else "VAZGEÇ"
	cancel_btn.custom_minimum_size = Vector2(150, 40)
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
	confirm_btn.text = "YES, RESET 🗑️" if is_en else "EVET, SIFIRLA 🗑️"
	confirm_btn.custom_minimum_size = Vector2(150, 40)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.48, 0.12, 0.1, 0.95)
	confirm_style.border_color = Color(0.85, 0.35, 0.35, 1.0)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.pressed.connect(func():
		GlobalSoundManager.play_sfx("error")
		confirm_layer.queue_free()
		_active_confirm_dialog = null
		_execute_reset_collection()
	)
	hbox.add_child(confirm_btn)

	add_child(confirm_layer)


func _execute_reset_collection() -> void:
	GlobalInventory.reset_collection()
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	reset_collection_button.text = "RESET COMPLETE!" if is_en else "SIFIRLANDI!"
	reset_collection_button.disabled = true
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(func() -> void:
		if is_instance_valid(reset_collection_button):
			reset_collection_button.text = "RESET COLLECTION" if is_en else "KOLEKSİYONU SIFIRLA"
			reset_collection_button.disabled = false
	)


func _setup_button(btn: Button) -> void:
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
