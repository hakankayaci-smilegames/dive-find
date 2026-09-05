extends Control

const LOADING_SCREEN := "res://Scenes/loading_screen.tscn"
const SETTINGS_FILE := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

@export var collection_scene: PackedScene  # res://Scenes/collection.tscn

@export_group("Sürüm")
@export var game_version: String = "Pre-Beta 0.5 (Afterjam Remaster)"  # Inspector'dan veya buradan kolayca düzenlenebilir

@onready var info_panel: Panel = $InfoPanel
@onready var info_button: Button = $Panel/VBoxContainer/Button4
@onready var info_close: Button = $InfoPanel/CloseButton
@onready var info_text: RichTextLabel = $InfoPanel/InfoText

@onready var collection_button: Button = $Panel/VBoxContainer/Button3

@onready var settings_panel: Panel = $SettingsPanel
@onready var settings_button: Button = $Panel/VBoxContainer/Button2
@onready var settings_close: Button = $SettingsPanel/CloseButton

@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $Panel/VBoxContainer/NewGameButton

@onready var title_box: Panel = $Panel/TitleBox
@onready var remastered_label: Label = get_node_or_null("Panel/TitleBox/RemasteredLabel")
@onready var subtitle_label: Label = $Panel/SubtitleLabel
@onready var menu_buttons: VBoxContainer = $Panel/VBoxContainer
@onready var changelog_panel: Panel = $Panel/ChangelogPanel
@onready var exit_button: Button = $Panel/Button
@onready var sunan_label: Label = $Panel/Label2
@onready var version_label: Label = $Panel/VersionLabel

@onready var sky_texture: TextureRect = $SkyTexture
@onready var ocean_texture: TextureRect = $OceanTexture
@onready var deep_texture: TextureRect = $DeepTexture

@onready var music_slider: HSlider = $SettingsPanel/Content/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $SettingsPanel/Content/SfxRow/SfxSlider
@onready var fullscreen_check: CheckButton = $SettingsPanel/Content/FullscreenRow/FullscreenCheck
@onready var joystick_row: HBoxContainer = get_node_or_null("SettingsPanel/Content/JoystickRow")
@onready var joystick_slider: HSlider = get_node_or_null("SettingsPanel/Content/JoystickRow/JoystickSlider")
@onready var joystick_val_label: Label = get_node_or_null("SettingsPanel/Content/JoystickRow/JoystickValueLabel")
@onready var reset_collection_button: Button = $SettingsPanel/Content/CollectionRow/ResetCollectionButton

var _panel_tweens: Dictionary = {}
var _base_positions: Dictionary = {}
var _target_parallax: Vector2 = Vector2.ZERO
var _current_parallax: Vector2 = Vector2.ZERO


func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)

	_ensure_audio_buses()
	_apply_game_version()
	_capture_positions()
	info_panel.visible = false
	info_button.pressed.connect(_toggle_info_panel)
	info_close.pressed.connect(_close_info_panel)

	settings_panel.visible = false
	settings_button.pressed.connect(_toggle_settings_panel)
	settings_close.pressed.connect(_close_settings_panel)

	_refresh_save_buttons()
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	collection_button.pressed.connect(_open_collection)

	_load_settings()
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	reset_collection_button.pressed.connect(_on_reset_collection_pressed)

	if not OS.has_feature("mobile") and is_instance_valid(joystick_row):
		joystick_row.visible = false
	elif is_instance_valid(joystick_slider):
		joystick_slider.value_changed.connect(_on_joystick_slider_changed)

	_setup_button_hover_sfx()
	_play_entrance_animation()
	call_deferred("_preload_collection_cache")


func _process(delta: float) -> void:
	_update_parallax(delta)
	_update_title_bobbing()


func _apply_game_version() -> void:
	if is_instance_valid(version_label):
		version_label.text = game_version

	if is_instance_valid(info_text):
		var bbcode := info_text.text
		var old_ver_pattern := "Smile Games — Afterjam Remaster Edition 2.0"
		if bbcode.contains(old_ver_pattern):
			info_text.text = bbcode.replace(
				"( Devbuild 0.0.2)",
				"( %s )" % game_version
			)


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) < 0:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, MUSIC_BUS)
	if AudioServer.get_bus_index(SFX_BUS) < 0:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, SFX_BUS)


func _capture_positions() -> void:
	var nodes := [
		info_panel, settings_panel, title_box, menu_buttons,
		subtitle_label, exit_button, sunan_label, version_label,
		sky_texture, ocean_texture, deep_texture
	]
	for node in nodes:
		if is_instance_valid(node):
			_base_positions[node] = node.position


func _play_entrance_animation() -> void:
	if _base_positions.has(title_box):
		_animate_enter(title_box, _base_positions[title_box] + Vector2(-60.0, 0.0), 0.45)
	if is_instance_valid(subtitle_label):
		_fade_in(subtitle_label, 0.3)
	if _base_positions.has(menu_buttons):
		_animate_enter(menu_buttons, _base_positions[menu_buttons] + Vector2(-80.0, 0.0), 0.5)
	if is_instance_valid(changelog_panel):
		_fade_in(changelog_panel, 0.35)

	var buttons: Array[Node] = menu_buttons.get_children()
	for i in buttons.size():
		_fade_in(buttons[i] as Control, 0.06 * i)

	if is_instance_valid(exit_button):
		_fade_in(exit_button, 0.5)
	if is_instance_valid(sunan_label):
		_fade_in(sunan_label, 0.6)
	if is_instance_valid(version_label):
		_fade_in(version_label, 0.6)


func _animate_enter(control: Control, from: Vector2, duration: float) -> void:
	if not is_instance_valid(control) or not _base_positions.has(control):
		return
	control.position = from
	control.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(control, "position", _base_positions[control], duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration)


func _fade_in(control: Control, delay: float) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, 0.35)


func _setup_button_hover_sfx() -> void:
	var buttons: Array[Node] = menu_buttons.get_children()
	for child in buttons:
		if child is Button:
			var btn := child as Button
			btn.mouse_entered.connect(func() -> void:
				if not btn.disabled:
					GlobalSoundManager.play_sfx("click")
			)


func _update_parallax(delta: float) -> void:
	var vp := get_viewport()
	if not vp:
		return
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var mouse_pos := vp.get_mouse_position()
	var center := vp_size * 0.5
	_target_parallax = (mouse_pos - center) / center
	_target_parallax.x = clampf(_target_parallax.x, -1.0, 1.0)
	_target_parallax.y = clampf(_target_parallax.y, -1.0, 1.0)

	_current_parallax = _current_parallax.lerp(_target_parallax, delta * 3.5)

	if is_instance_valid(sky_texture) and _base_positions.has(sky_texture):
		sky_texture.position = _base_positions[sky_texture] - _current_parallax * 4.0
	if is_instance_valid(ocean_texture) and _base_positions.has(ocean_texture):
		ocean_texture.position = _base_positions[ocean_texture] - _current_parallax * 12.0
	if is_instance_valid(deep_texture) and _base_positions.has(deep_texture):
		deep_texture.position = _base_positions[deep_texture] - _current_parallax * 22.0


func _update_title_bobbing() -> void:
	if is_instance_valid(title_box) and _base_positions.has(title_box):
		var float_y := sin(Time.get_ticks_msec() * 0.002) * 3.5
		title_box.position.y = _base_positions[title_box].y + float_y

	if is_instance_valid(remastered_label):
		var glow_pulse := sin(Time.get_ticks_msec() * 0.004) * 0.18 + 0.82
		remastered_label.modulate.a = glow_pulse


func _toggle_info_panel() -> void:
	if info_panel.visible:
		_hide_panel(info_panel)
	else:
		_hide_panel(settings_panel)
		_show_panel(info_panel)


func _close_info_panel() -> void:
	_hide_panel(info_panel)


func _toggle_settings_panel() -> void:
	if settings_panel.visible:
		_hide_panel(settings_panel)
	else:
		_hide_panel(info_panel)
		_show_panel(settings_panel)


func _close_settings_panel() -> void:
	_hide_panel(settings_panel)


func _panel_tween(panel: Panel) -> Tween:
	var t: Tween = _panel_tweens.get(panel)
	if t and t.is_valid():
		t.kill()
	var nt := create_tween()
	_panel_tweens[panel] = nt
	return nt


func _show_panel(panel: Panel) -> void:
	var tween := _panel_tween(panel)
	var base: Vector2 = _base_positions.get(panel, panel.position)
	panel.visible = true
	panel.modulate.a = 0.0
	panel.position = base + Vector2(100.0, 0.0)
	tween.set_parallel(true)
	tween.tween_property(panel, "position", base, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)


func _hide_panel(panel: Panel) -> void:
	var tween := _panel_tween(panel)
	var base: Vector2 = _base_positions.get(panel, panel.position)
	tween.set_parallel(true)
	tween.tween_property(panel, "position", base + Vector2(60.0, 0.0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func() -> void:
		panel.visible = false
		panel.position = base
		panel.modulate.a = 1.0
	)


func _refresh_save_buttons() -> void:
	var has_save: bool = GlobalInventory.has_save()
	continue_button.disabled = not has_save
	if has_save:
		var save_data := GlobalInventory.get_save_data()
		var day := int(save_data.get("current_day", 1))
		var money := int(save_data.get("money", 0))
		continue_button.text = "DEVAM ET  (Gün %d • %d Zurna)" % [day, money]
		continue_button.tooltip_text = GlobalInventory.get_save_summary()
	else:
		continue_button.text = "DEVAM ET"
		continue_button.tooltip_text = "Kayıtlı oyun bulunamadı."


func _on_new_game_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	GlobalInventory.start_new_game()
	get_tree().change_scene_to_file(LOADING_SCREEN)


func _on_continue_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	GlobalInventory.apply_save_to_game()
	get_tree().change_scene_to_file(LOADING_SCREEN)


func _preload_collection_cache() -> void:
	GlobalInventory.get_all_items()


func _open_collection() -> void:
	if not collection_scene:
		push_warning("MainMenu: collection_scene atanmamış!")
		return
	get_tree().current_scene.add_child(collection_scene.instantiate())


func _on_reset_collection_pressed() -> void:
	GlobalInventory.reset_collection()
	var original_text := reset_collection_button.text
	reset_collection_button.text = "SIFIRLANDI!"
	reset_collection_button.disabled = true
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void:
		reset_collection_button.text = original_text
		reset_collection_button.disabled = false
	)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var music := 70.0
	var sfx := 80.0
	var fullscreen := true
	var joystick_scale := 1.0
	if cfg.load(SETTINGS_FILE) == OK:
		music = cfg.get_value("audio", "music", music)
		sfx = cfg.get_value("audio", "sfx", sfx)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
		joystick_scale = cfg.get_value("controls", "joystick_scale", joystick_scale)
	_set_bus_volume(MUSIC_BUS, music)
	_set_bus_volume(SFX_BUS, sfx)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	music_slider.value = music
	sfx_slider.value = sfx
	fullscreen_check.set_pressed_no_signal(fullscreen)
	if is_instance_valid(joystick_slider):
		joystick_slider.value = joystick_scale
	if is_instance_valid(joystick_val_label):
		joystick_val_label.text = "%%%d" % [int(round(joystick_scale * 100.0))]


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_slider.value)
	cfg.set_value("audio", "sfx", sfx_slider.value)
	cfg.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	if is_instance_valid(joystick_slider):
		cfg.set_value("controls", "joystick_scale", joystick_slider.value)
	cfg.save(SETTINGS_FILE)


func _on_music_changed(value: float) -> void:
	_set_bus_volume(MUSIC_BUS, value)
	_save_settings()


func _on_sfx_changed(value: float) -> void:
	_set_bus_volume(SFX_BUS, value)
	_save_settings()


func _on_joystick_slider_changed(value: float) -> void:
	if is_instance_valid(joystick_val_label):
		joystick_val_label.text = "%%%d" % [int(round(value * 100.0))]
	_save_settings()


func _on_fullscreen_toggled(on: bool) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
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


func _on_button_pressed() -> void:
	get_tree().quit(0)


func _on_button_4_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
