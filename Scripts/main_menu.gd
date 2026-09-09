extends Control

const LOADING_SCREEN := "res://Scenes/loading_screen.tscn"
const SETTINGS_FILE := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

@export var collection_scene: PackedScene  # res://Scenes/collection.tscn

@export_group("Sürüm")
@export var game_version: String = "PreAlpha 1.6.2 (Afterjam Remaster)"  # Inspector'dan veya buradan kolayca düzenlenebilir

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
@onready var flashlight_aim_row: HBoxContainer = get_node_or_null("SettingsPanel/Content/FlashlightAimRow")
@onready var flashlight_aim_option: OptionButton = get_node_or_null("SettingsPanel/Content/FlashlightAimRow/FlashlightAimOption")
@onready var reset_collection_button: Button = $SettingsPanel/Content/CollectionRow/ResetCollectionButton
@onready var dev_code_input: LineEdit = get_node_or_null("SettingsPanel/Content/DevCodeRow/DevCodeInput")
@onready var dev_code_button: Button = get_node_or_null("SettingsPanel/Content/DevCodeRow/DevCodeButton")

const DEV_SECRET_CODE: String = "mercedesforever" # Kendi belirleyeceğin gizli kod

var _panel_tweens: Dictionary = {}
var _base_positions: Dictionary = {}
var _target_parallax: Vector2 = Vector2.ZERO
var _current_parallax: Vector2 = Vector2.ZERO
var _active_collection: Node = null
var _active_confirm_dialog: CanvasLayer = null


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
	collection_button.pressed.connect(_toggle_collection)

	_load_settings()
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	reset_collection_button.pressed.connect(_on_reset_collection_pressed)

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

	_setup_button_hover_sfx()
	_play_entrance_animation()
	call_deferred("_preload_collection_cache")


func _process(delta: float) -> void:
	_update_parallax(delta)
	_update_title_bobbing()


func _apply_game_version() -> void:
	if is_instance_valid(version_label):
		version_label.text = game_version
	_update_info_text()


func _update_info_text() -> void:
	if not is_instance_valid(info_text):
		return
	var is_en := TranslationServer.get_locale().begins_with("en")
	if is_en:
		info_text.text = _get_info_bbcode_en()
	else:
		info_text.text = _get_info_bbcode_tr()


func _get_info_bbcode_tr() -> String:
	return """[center][font_size=24][color=#00e5ff][b]🤿 DIVE & FIND 🤿[/b][/color][/font_size][/center]

[color=#72b5ff][b]Hikaye & Konsept:[/b][/color]
Derin okyanusların gizemli sularına dalış yap! Dipte saklı kalan antik eserleri, değerli kalıntıları ve tuhaf objeleri topla, yüzeye çıkarıp sat ve ekipmanlarını geliştir.

[color=#72b5ff][b]Temel Kontroller (PC):[/b][/color]
• [color=#00e5ff]WASD / Yön Tuşları:[/color] Yüzme ve Hareket
• [color=#00e5ff]Shift (Basılı Tut):[/color] Hızlı Yüzme / Depar (Sprint — %50 hız artışı, 2.6x oksijen tüketimi)
• [color=#00e5ff]Sol Tık / E Tuşu:[/color] Eşyayı İncele (Detay penceresi ve alma menüsü açar)
• [color=#00e5ff]Sağ Tık:[/color] Doğrudan Çantaya Al (Pop-up açmadan hızlı alma)
• [color=#00e5ff]F Tuşu:[/color] Dalış Fenerini Aç / Kapat (Işık mouse imlecine yönelir, batarya tüketir)
• [color=#00e5ff]Fare Tekerleği / [ + ] [ - ] / P & O:[/color] Kamera Yakınlaştır / Uzaklaştır (Gözlük seviyesiyle genişler)
• [color=#00e5ff]I / Tab Tuşu:[/color] Sırt Çantasını Aç / Kapat (Envanter)
• [color=#00e5ff]C Tuşu:[/color] Koleksiyon Defterini Aç / Kapat (Keşfedilenler)
• [color=#00e5ff]Sağ Tık (Çantada):[/color] Eşyayı Kilitle / Kilidi Aç (🔒 Satış ve craft koruması)
• [color=#00e5ff]E (Su Yüzeyinde):[/color] Tekneye Çık & Ofis Karargahına Dön
• [color=#00e5ff]ESC:[/color] Açık pencereleri kapat / Ofisteyken dalışı başlat

[color=#72b5ff][b]Mobil Kontroller (Dokunmatik):[/b][/color]
• [color=#00e5ff]Sol Ekran:[/color] Dinamik Analog Joystick (360° serbest yüzüş)
• [color=#00e5ff]⚡ DEPAR:[/color] Hızlı yüzme modunu açar / kapatır
• [color=#00e5ff]⚡ DİREKT AL:[/color] Menzildeki eşyayı pop-up açmadan çantaya atar
• [color=#00e5ff]🖐️ İNCELE:[/color] Menzildeki eşyanın detay penceresini açar
• [color=#00e5ff]🥽+ / 🥽- :[/color] Kamerayı kademeli yakınlaştırıp uzaklaştırır
• [color=#00e5ff]🔦 FENER:[/color] Dalış fenerini açar / kapatır (Ayarlardan 3 yön modu seçilebilir)
• [color=#00e5ff]Uzun Basış (0.35s):[/color] Çantada eşyayı kilitler / açar 🔒

[center][font_size=13][color=#5e8ca8]Yapımcılar: Queen Of Femboyss & Hakan Bey[/color][/font_size]
[font_size=15][color=#00e5ff][i]⚓ Smile Games sunar ( " + game_version + " )[/i][/color][/font_size][/center]"""


func _get_info_bbcode_en() -> String:
	return """[center][font_size=24][color=#00e5ff][b]🤿 DIVE & FIND 🤿[/b][/color][/font_size][/center]

[color=#72b5ff][b]Story & Concept:[/b][/color]
Plunge into the mysterious depths of the ocean! Gather ancient relics, valuable salvage, and bizarre artifacts resting on the seabed, bring them to the surface to sell, and upgrade your diving gear.

[color=#72b5ff][b]Basic Controls (PC):[/b][/color]
• [color=#00e5ff]WASD / Arrow Keys:[/color] Swim and Navigate
• [color=#00e5ff]Shift (Hold):[/color] Fast Swimming / Sprint (+50% speed, 2.6x oxygen drain)
• [color=#00e5ff]Left Click / E Key:[/color] Examine Item (Opens detail popup and take options)
• [color=#00e5ff]Right Click:[/color] Quick Pick to Bag (Instantly grabs item without opening popup)
• [color=#00e5ff]F Key:[/color] Toggle Dive Light (Follows mouse cursor, drains battery)
• [color=#00e5ff]Scroll Wheel / [ + ] [ - ] / P & O:[/color] Camera Zoom In / Out (Expands with Mask level)
• [color=#00e5ff]I / Tab Key:[/color] Toggle Backpack (Inventory)
• [color=#00e5ff]C Key:[/color] Toggle Collection Log (Discovered Items)
• [color=#00e5ff]Right Click (In Bag):[/color] Lock / Unlock Item (🔒 Sell & craft protection)
• [color=#00e5ff]E (At Surface):[/color] Board Boat & Return to Office Headquarters
• [color=#00e5ff]ESC:[/color] Close open windows / Start dive when at Office

[color=#72b5ff][b]Mobile Controls (Touch):[/b][/color]
• [color=#00e5ff]Left Screen:[/color] Dynamic Analog Joystick (360° free swim)
• [color=#00e5ff]⚡ SPRINT:[/color] Toggles sprint mode on / off
• [color=#00e5ff]⚡ QUICK TAKE:[/color] Grabs nearby item directly into bag without popup
• [color=#00e5ff]🖐️ EXAMINE:[/color] Opens detailed examination window for nearby item
• [color=#00e5ff]🥽+ / 🥽- :[/color] Zoom camera in and out step by step
• [color=#00e5ff]🔦 LIGHT:[/color] Toggles dive light (3 aim modes available in Settings)
• [color=#00e5ff]Long Press (0.35s):[/color] Lock / unlock item in backpack 🔒

[center][font_size=13][color=#5e8ca8]Developers: Queen Of Femboyss & Hakan Bey[/color][/font_size]
[font_size=15][color=#00e5ff][i]⚓ Smile Games Presents ( " + game_version + " )[/i][/color][/font_size][/center]"""


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
	if is_instance_valid(_active_collection):
		_active_collection.queue_free()
		_active_collection = null
	if info_panel.visible:
		_hide_panel(info_panel)
	else:
		_update_info_text()
		_hide_panel(settings_panel)
		_show_panel(info_panel)


func _close_info_panel() -> void:
	_hide_panel(info_panel)


func _toggle_settings_panel() -> void:
	if is_instance_valid(_active_collection):
		_active_collection.queue_free()
		_active_collection = null
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
		var save_data: Dictionary = GlobalInventory.get_save_data()
		var day := int(save_data.get("current_day", 1))
		var money := int(save_data.get("money", 0))
		continue_button.text = tr("DEVAM ET  (Gün %d • %d Zurna)") % [day, money]
		continue_button.tooltip_text = GlobalInventory.get_save_summary()
	else:
		continue_button.text = tr("DEVAM ET")
		continue_button.tooltip_text = tr("Kayıtlı oyun bulunamadı.")


func _on_new_game_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	if GlobalInventory.has_save():
		_show_new_game_confirmation()
	else:
		_start_new_game_direct()


func _start_new_game_direct() -> void:
	GlobalInventory.start_new_game()
	get_tree().change_scene_to_file(LOADING_SCREEN)


func _show_new_game_confirmation() -> void:
	if is_instance_valid(_active_confirm_dialog):
		_active_confirm_dialog.queue_free()
		_active_confirm_dialog = null

	var confirm_layer := CanvasLayer.new()
	confirm_layer.layer = 130
	_active_confirm_dialog = confirm_layer

	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_layer.add_child(overlay)

	# Dışarı tıklandığında iptal etme
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			GlobalSoundManager.play_sfx("click")
			if is_instance_valid(confirm_layer):
				confirm_layer.queue_free()
				_active_confirm_dialog = null
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 230)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.85, 0.75, 0.45, 1.0)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = tr("⚠️ MEVCUT KAYIT SİLİNECEK")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var save_data: Dictionary = GlobalInventory.get_save_data()
	var day := int(save_data.get("current_day", 1))
	var money := int(save_data.get("money", 0))

	var desc := Label.new()
	desc.text = tr("Mevcut kayıtlı oyunun (Gün %d • %d Zurna) ve satın aldığın tüm ekipman seviyeleri sıfırlanacak.\n(Keşfettiğin eşya koleksiyonu korunur)\n\nBu işlem geri alınamaz! Yeni bir oyuna başlamak istediğinden emin misin?") % [day, money]
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
	cancel_btn.text = tr("VAZGEÇ")
	cancel_btn.custom_minimum_size = Vector2(160, 44)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.25, 0.20, 0.18, 1.0)
	cancel_style.border_color = Color(0.50, 0.40, 0.30, 1.0)
	cancel_style.set_border_width_all(2)
	cancel_style.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.pressed.connect(func() -> void:
		GlobalSoundManager.play_sfx("click")
		if is_instance_valid(confirm_layer):
			confirm_layer.queue_free()
			_active_confirm_dialog = null
	)
	hbox.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = tr("EVET, YENİ OYUN 🚀")
	confirm_btn.custom_minimum_size = Vector2(170, 44)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.75, 0.22, 0.20, 1.0)
	confirm_style.border_color = Color(0.95, 0.40, 0.35, 1.0)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.90, 1.0))
	confirm_btn.pressed.connect(func() -> void:
		GlobalSoundManager.play_sfx("click")
		if is_instance_valid(confirm_layer):
			confirm_layer.queue_free()
			_active_confirm_dialog = null
		_start_new_game_direct()
	)
	hbox.add_child(confirm_btn)

	confirm_layer.tree_exited.connect(func() -> void:
		if _active_confirm_dialog == confirm_layer:
			_active_confirm_dialog = null
	)
	add_child(confirm_layer)



func _on_continue_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	GlobalInventory.apply_save_to_game()
	get_tree().change_scene_to_file(LOADING_SCREEN)


func _preload_collection_cache() -> void:
	GlobalInventory.get_all_items()


func _toggle_collection() -> void:
	GlobalSoundManager.play_sfx("click")
	if is_instance_valid(_active_collection):
		_active_collection.queue_free()
		_active_collection = null
		return

	if not collection_scene:
		push_warning("MainMenu: collection_scene atanmamış!")
		return

	_hide_panel(settings_panel)
	_hide_panel(info_panel)

	_active_collection = collection_scene.instantiate()
	_active_collection.tree_exited.connect(func() -> void:
		_active_collection = null
	)
	get_tree().current_scene.add_child(_active_collection)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(_active_confirm_dialog):
				_active_confirm_dialog.queue_free()
				_active_confirm_dialog = null
				get_viewport().set_input_as_handled()
			elif is_instance_valid(_active_collection):
				_active_collection.queue_free()
				_active_collection = null
				get_viewport().set_input_as_handled()
			elif settings_panel.visible:
				_close_settings_panel()
				get_viewport().set_input_as_handled()
			elif info_panel.visible:
				_close_info_panel()
				get_viewport().set_input_as_handled()


func _on_reset_collection_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	_show_reset_collection_confirmation()


func _show_reset_collection_confirmation() -> void:
	if is_instance_valid(_active_confirm_dialog):
		_active_confirm_dialog.queue_free()
		_active_confirm_dialog = null

	var confirm_layer := CanvasLayer.new()
	confirm_layer.layer = 130
	_active_confirm_dialog = confirm_layer

	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_layer.add_child(overlay)

	# Dışarı tıklandığında iptal etme
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			GlobalSoundManager.play_sfx("click")
			if is_instance_valid(confirm_layer):
				confirm_layer.queue_free()
				_active_confirm_dialog = null
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 220)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.85, 0.75, 0.45, 1.0)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = tr("⚠️ KOLEKSİYONU SIFIRLA")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = tr("Tüm keşfettiğin eşyalar koleksiyon defterinden kalıcı olarak silinecektir.\nBu işlem geri alınamaz!\n\nKoleksiyonu sıfırlamak istediğinden emin misin?")
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
	cancel_btn.text = tr("VAZGEÇ")
	cancel_btn.custom_minimum_size = Vector2(160, 44)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.25, 0.20, 0.18, 1.0)
	cancel_style.border_color = Color(0.50, 0.40, 0.30, 1.0)
	cancel_style.set_border_width_all(2)
	cancel_style.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.pressed.connect(func() -> void:
		GlobalSoundManager.play_sfx("click")
		if is_instance_valid(confirm_layer):
			confirm_layer.queue_free()
			_active_confirm_dialog = null
	)
	hbox.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = tr("EVET, SIFIRLA 🗑️")
	confirm_btn.custom_minimum_size = Vector2(160, 44)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.75, 0.22, 0.20, 1.0)
	confirm_style.border_color = Color(0.95, 0.40, 0.35, 1.0)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.90, 1.0))
	confirm_btn.pressed.connect(func() -> void:
		GlobalSoundManager.play_sfx("click")
		if is_instance_valid(confirm_layer):
			confirm_layer.queue_free()
			_active_confirm_dialog = null
		_execute_reset_collection()
	)
	hbox.add_child(confirm_btn)

	confirm_layer.tree_exited.connect(func() -> void:
		if _active_confirm_dialog == confirm_layer:
			_active_confirm_dialog = null
	)
	add_child(confirm_layer)


func _execute_reset_collection() -> void:
	GlobalInventory.reset_collection()
	var original_text := reset_collection_button.text
	reset_collection_button.text = tr("SIFIRLANDI!")
	reset_collection_button.disabled = true
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(func() -> void:
		if is_instance_valid(reset_collection_button):
			reset_collection_button.text = original_text
			reset_collection_button.disabled = false
	)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var music := 70.0
	var sfx := 80.0
	var fullscreen := true
	var joystick_scale := 1.0
	var flashlight_aim := 2
	if cfg.load(SETTINGS_FILE) == OK:
		music = cfg.get_value("audio", "music", music)
		sfx = cfg.get_value("audio", "sfx", sfx)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
		joystick_scale = cfg.get_value("controls", "joystick_scale", joystick_scale)
		flashlight_aim = int(cfg.get_value("controls", "mobile_flashlight_aim", flashlight_aim))
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
	if is_instance_valid(flashlight_aim_option):
		flashlight_aim_option.select(clampi(flashlight_aim, 0, 2))
	_refresh_dev_code_ui()


func _refresh_dev_code_ui() -> void:
	if not is_instance_valid(dev_code_input) or not is_instance_valid(dev_code_button):
		return
	var dev_console = get_node_or_null("/root/DevConsole")
	var is_unlocked: bool = dev_console.is_dev_console_unlocked() if dev_console and dev_console.has_method("is_dev_console_unlocked") else false
	if is_unlocked:
		dev_code_input.text = ""
		dev_code_input.placeholder_text = "AKTİF ✅"
		dev_code_button.text = "KAPAT"
		dev_code_button.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4, 1.0))
	else:
		dev_code_input.text = ""
		dev_code_input.placeholder_text = "Gizli kod..."
		dev_code_button.text = "AKTİF ET"
		dev_code_button.remove_theme_color_override("font_color")


func _on_dev_code_submitted() -> void:
	if not is_instance_valid(dev_code_input) or not is_instance_valid(dev_code_button):
		return
	var dev_console = get_node_or_null("/root/DevConsole")
	if not dev_console:
		return

	var is_unlocked: bool = dev_console.is_dev_console_unlocked() if dev_console.has_method("is_dev_console_unlocked") else false
	var entered_code: String = dev_code_input.text.strip_edges()

	# Eğer zaten aktifse ve kullanıcı KAPAT butonuna bastıysa:
	if is_unlocked and (entered_code == "" or entered_code == DEV_SECRET_CODE):
		if dev_console.has_method("set_dev_unlocked"):
			dev_console.set_dev_unlocked(false)
		GlobalSoundManager.play_sfx("click")
		_refresh_dev_code_ui()
		return

	# Kilidi açma kontrolü:
	if entered_code == DEV_SECRET_CODE:
		if dev_console.has_method("set_dev_unlocked"):
			dev_console.set_dev_unlocked(true)
		GlobalSoundManager.play_sfx("upgrade")
		_refresh_dev_code_ui()
	else:
		GlobalSoundManager.play_sfx("error")
		dev_code_button.text = "HATALI! ❌"
		dev_code_button.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3, 1.0))
		var tw := create_tween()
		tw.tween_interval(1.2)
		tw.tween_callback(func() -> void:
			if is_instance_valid(dev_code_button):
				_refresh_dev_code_ui()
		)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_slider.value)
	cfg.set_value("audio", "sfx", sfx_slider.value)
	cfg.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	if is_instance_valid(joystick_slider):
		cfg.set_value("controls", "joystick_scale", joystick_slider.value)
	if is_instance_valid(flashlight_aim_option):
		cfg.set_value("controls", "mobile_flashlight_aim", flashlight_aim_option.selected)
	cfg.save(SETTINGS_FILE)


func _on_flashlight_aim_selected(_index: int) -> void:
	_save_settings()


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
