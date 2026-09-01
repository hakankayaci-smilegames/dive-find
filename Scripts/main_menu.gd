extends Control

const LOADING_SCREEN := "res://Scenes/loading_screen.tscn"
const SETTINGS_FILE := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

@export var collection_scene: PackedScene  # res://Scenes/collection.tscn

@export_group("Sürüm")
@export var game_version: String = "v0.0.2 (Devbuild)"  # Inspector'dan veya buradan kolayca düzenlenebilir

@onready var info_panel: Panel = $InfoPanel
@onready var info_button: Button = $Panel/VBoxContainer/Button4
@onready var info_close: Button = $InfoPanel/CloseButton
@onready var info_text: RichTextLabel = $InfoPanel/InfoText

@onready var collection_button: Button = $Panel/VBoxContainer/Button3

@onready var settings_panel: Panel = $SettingsPanel
@onready var settings_button: Button = $Panel/VBoxContainer/Button2
@onready var settings_close: Button = $SettingsPanel/CloseButton

@onready var play_button: Button = $Panel/VBoxContainer/Button

@onready var title_box: Panel = $Panel/TitleBox
@onready var subtitle_label: Label = $Panel/SubtitleLabel
@onready var menu_buttons: VBoxContainer = $Panel/VBoxContainer
@onready var exit_button: Button = $Panel/Button
@onready var sunan_label: Label = $Panel/Label2
@onready var version_label: Label = $Panel/VersionLabel

@onready var music_slider: HSlider = $SettingsPanel/Content/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $SettingsPanel/Content/SfxRow/SfxSlider
@onready var fullscreen_check: CheckButton = $SettingsPanel/Content/FullscreenRow/FullscreenCheck
@onready var reset_collection_button: Button = $SettingsPanel/Content/CollectionRow/ResetCollectionButton

var _panel_tweens := {}
var _base_positions := {}


func _ready() -> void:
	_ensure_audio_buses()
	_apply_game_version()
	_capture_positions()
	info_panel.visible = false
	info_button.pressed.connect(_toggle_info_panel)
	info_close.pressed.connect(_close_info_panel)

	settings_panel.visible = false
	settings_button.pressed.connect(_toggle_settings_panel)
	settings_close.pressed.connect(_close_settings_panel)

	play_button.pressed.connect(_start_game)
	collection_button.pressed.connect(_open_collection)

	_load_settings()
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	reset_collection_button.pressed.connect(_on_reset_collection_pressed)

	_play_entrance_animation()
	call_deferred("_preload_collection_cache")


func _apply_game_version() -> void:
	if is_instance_valid(version_label):
		version_label.text = game_version

	if is_instance_valid(info_text):
		# Bilgi panelindeki en alt sürüm satırını dinamik senkronize eder
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
	for node in [info_panel, settings_panel, title_box, menu_buttons, subtitle_label, exit_button, sunan_label, version_label]:
		if is_instance_valid(node):
			_base_positions[node] = node.position


func _play_entrance_animation() -> void:
	_animate_enter(title_box, _base_positions[title_box] + Vector2(0, -40), 0.45)
	_fade_in(subtitle_label, 0.5)
	_animate_enter(menu_buttons, _base_positions[menu_buttons] + Vector2(420, 0), 0.5)
	var buttons: Array[Node] = menu_buttons.get_children()
	for i in buttons.size():
		_fade_in(buttons[i], 0.08 * i)
	_fade_in(exit_button, 0.6)
	_fade_in(sunan_label, 0.7)
	if is_instance_valid(version_label):
		_fade_in(version_label, 0.7)


func _animate_enter(control: Control, from: Vector2, duration: float) -> void:
	control.position = from
	control.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(control, "position", _base_positions[control], duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration)


func _fade_in(control: Control, delay: float) -> void:
	control.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, 0.35)


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
	var base: Vector2 = _base_positions[panel]
	panel.visible = true
	panel.modulate.a = 0.0
	panel.position = base + Vector2(120, 0)
	tween.set_parallel(true)
	tween.tween_property(panel, "position", base, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)


func _hide_panel(panel: Panel) -> void:
	var tween := _panel_tween(panel)
	var base: Vector2 = _base_positions[panel]
	tween.set_parallel(true)
	tween.tween_property(panel, "position", base + Vector2(80, 0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func() -> void:
		panel.visible = false
		panel.position = base
		panel.modulate.a = 1.0
	)


func _start_game() -> void:
	get_tree().change_scene_to_file(LOADING_SCREEN)


func _preload_collection_cache() -> void:
	# "OYNA"ya hiç basmadan doğrudan ana menüden Koleksiyon'a tıklanırsa da donma yaşanmasın.
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
	if cfg.load(SETTINGS_FILE) == OK:
		music = cfg.get_value("audio", "music", music)
		sfx = cfg.get_value("audio", "sfx", sfx)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	_set_bus_volume(MUSIC_BUS, music)
	_set_bus_volume(SFX_BUS, sfx)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	music_slider.value = music
	sfx_slider.value = sfx
	fullscreen_check.set_pressed_no_signal(fullscreen)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_slider.value)
	cfg.set_value("audio", "sfx", sfx_slider.value)
	cfg.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	cfg.save(SETTINGS_FILE)


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
