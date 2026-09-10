extends Control

@export_file("*.tscn") var target_scene_path: String = "res://Scenes/main.tscn"
@export_file("*.json") var tips_file_path: String = "res://Data/loading_tips.json"
@export var min_display_time: float = 1.2  # İpuçlarının okunabilirliği ve akıcılık için taban süre
@export var auto_change_scene: bool = true  # false ise sahne geçişi yapmaz, finished sinyalini yayınlar (overlay mod)

var duration: float:
	get:
		return min_display_time
	set(value):
		min_display_time = value

signal finished

@onready var tip_label: Label = get_node_or_null("TipCard/TipLabel") if has_node("TipCard/TipLabel") else get_node_or_null("BottomContainer/TipLabel")
@onready var stage_label: Label = $BottomContainer/StatusRow/StageLabel
@onready var percent_label: Label = $BottomContainer/StatusRow/PercentLabel
@onready var progress_bar: ProgressBar = $BottomContainer/ProgressBar
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var continue_prompt: PanelContainer = get_node_or_null("ContinuePrompt")
@onready var prompt_label: Label = get_node_or_null("ContinuePrompt/PromptLabel") if has_node("ContinuePrompt/PromptLabel") else get_node_or_null("ContinuePrompt/Label")
@onready var header_logo: TextureRect = get_node_or_null("HeaderLogo")

var _tips: Array[String] = []
var _elapsed_time: float = 0.0
var _displayed_progress: float = 0.0
var _real_progress: float = 0.0
var _is_finishing: bool = false
var _scene_loaded: bool = false
var _loaded_packed_scene: PackedScene = null
var _waiting_for_input: bool = false
var _prompt_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not auto_change_scene:
		get_tree().paused = true

	# 1. Gerçek Arka Plan Yüklemeleri:
	# Ses dosyalarını diskten RAM'e önbellekle (audio lag'ini sıfırla)
	GlobalSoundManager.preload_all_sfx()
	# Koleksiyon ve eşya .tres'lerini RAM'e önbellekle
	GlobalInventory.get_all_items()

	# 2. İpucu yükleme ve gösterme
	_load_tips()
	_display_random_tip()

	# 3. Logo hafif giriş animasyonu
	if is_instance_valid(header_logo):
		header_logo.modulate.a = 0.0
		var logo_tw := create_tween()
		logo_tw.tween_property(header_logo, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 4. Gerçek Arka Plan Sahne Talebi (Threaded Loading)
	if auto_change_scene:
		ResourceLoader.load_threaded_request(target_scene_path)

	progress_bar.value = 0.0
	_update_progress_ui(0.0)


func _process(delta: float) -> void:
	if _is_finishing:
		return

	_elapsed_time += delta

	var target_progress: float = 0.0

	if auto_change_scene:
		if not _scene_loaded:
			var progress_arr: Array = []
			var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress_arr)
			if not progress_arr.is_empty():
				_real_progress = float(progress_arr[0]) * 100.0

			if status == ResourceLoader.THREAD_LOAD_LOADED:
				_scene_loaded = true
				_loaded_packed_scene = ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				# Hata durumunda da takılı kalmasın
				_scene_loaded = true

		var time_progress: float = clamp((_elapsed_time / min_display_time) * 100.0, 0.0, 100.0)
		if _scene_loaded and _elapsed_time >= min_display_time:
			target_progress = 100.0
		else:
			target_progress = min(_real_progress, time_progress) if _real_progress > 0.0 else time_progress

		_displayed_progress = move_toward(_displayed_progress, target_progress, 160.0 * delta)
		_update_progress_ui(_displayed_progress)

		if _displayed_progress >= 99.9 and _scene_loaded and _elapsed_time >= min_display_time:
			if not _waiting_for_input:
				_ready_for_continue()

	else:
		# Overlay mod (örn. ofisten ofise gün geçişi)
		var time_progress: float = clamp((_elapsed_time / min_display_time) * 100.0, 0.0, 100.0)
		_displayed_progress = move_toward(_displayed_progress, time_progress, 120.0 * delta)
		_update_progress_ui(_displayed_progress)

		if _displayed_progress >= 99.9:
			_is_finishing = true
			_finish()


func _load_tips() -> void:
	_tips.clear()
	if FileAccess.file_exists(tips_file_path):
		var file := FileAccess.open(tips_file_path, FileAccess.READ)
		if file:
			var json_text := file.get_as_text()
			var json := JSON.new()
			if json.parse(json_text) == OK and json.data is Array:
				for item in json.data:
					_tips.append(str(item))

	if _tips.is_empty():
		var is_en: bool = ItemTranslator.get_current_locale() == "en"
		if is_en:
			_tips = [
				"💡 [E] Shortcut: When you reach the surface, press [E] to quickly board your boat.",
				"💡 Item Locking: You can Right Click valuable items in your backpack to Lock 🔒 them.",
				"💡 Safe Selling: The 'Sell All' button will never sell your locked items.",
				"💡 Depth & Pressure: The deeper you dive, the faster oxygen depletes. Don't forget to upgrade your tank at the Workshop!"
			]
		else:
			_tips = [
				"💡 [E] Kısayolu: Su yüzeyine çıktığında teknene hızlıca binmek için [E] tuşuna basabilirsin.",
				"💡 Eşya Kilitleme: Çantandaki değerli eşyaları korumak için üzerlerine Sağ Tıkla kilit 🔒 vurabilirsin.",
				"💡 Güvenli Satış: 'Hepsini Sat' butonu kilitli eşyalarını asla satmaz.",
				"💡 Derinlik & Basınç: Derinlere indikçe oksijenin çok daha hızlı tükenir, Atölye'den tüpünü geliştirmeyi unutma!"
			]


func _display_random_tip() -> void:
	if tip_label and not _tips.is_empty():
		tip_label.text = tr(_tips.pick_random())


func _update_progress_ui(val: float) -> void:
	if is_instance_valid(progress_bar):
		progress_bar.value = val

	var int_val := int(val)
	if is_instance_valid(percent_label):
		percent_label.text = "%%%d" % int_val

	if is_instance_valid(stage_label) and not _waiting_for_input:
		var is_en: bool = ItemTranslator.get_current_locale() == "en"
		if int_val < 30:
			stage_label.text = "Scanning ancient relics and treasures..." if is_en else "Eski kalıntılar ve hazineler taranıyor..."
		elif int_val < 65:
			stage_label.text = "Preparing audio files and map layers..." if is_en else "Ses dosyaları ve harita katmanları hazırlanıyor..."
		elif int_val < 95:
			stage_label.text = "Checking diving gear and equipment..." if is_en else "Dalış ekipmanları kontrol ediliyor..."
		else:
			stage_label.text = "Ready to dive!" if is_en else "Dalışa hazır!"


func _ready_for_continue() -> void:
	_waiting_for_input = true
	_displayed_progress = 100.0
	_update_progress_ui(100.0)

	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	if is_instance_valid(prompt_label):
		prompt_label.text = "▶ TAP SCREEN OR PRESS ANY KEY TO CONTINUE ◀" if is_en else "▶ DEVAM ETMEK İÇİN EKRANA DOKUNUN VEYA BİR TUŞA BASIN ◀"

	if is_instance_valid(continue_prompt):
		continue_prompt.visible = true
		continue_prompt.pivot_offset = continue_prompt.size * 0.5
		if _prompt_tween and _prompt_tween.is_valid():
			_prompt_tween.kill()
		_prompt_tween = create_tween().set_loops()
		_prompt_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_prompt_tween.tween_property(continue_prompt, "scale", Vector2(1.04, 1.04), 0.55).set_trans(Tween.TRANS_SINE)
		_prompt_tween.tween_property(continue_prompt, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_SINE)

	if is_instance_valid(stage_label):
		stage_label.text = "✦ READY TO DIVE! (Tap screen or press any key to continue) ✦" if is_en else "✦ DALIŞA HAZIR! (Devam etmek için ekrana dokunun veya bir tuşa basın) ✦"
		stage_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1.0))


func _input(event: InputEvent) -> void:
	if not _waiting_for_input or _is_finishing:
		return

	var is_trigger: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		is_trigger = true
	elif event is InputEventMouseButton and event.pressed:
		is_trigger = true
	elif event is InputEventScreenTouch and event.pressed:
		is_trigger = true
	elif event is InputEventJoypadButton and event.pressed:
		is_trigger = true

	if is_trigger:
		_waiting_for_input = false
		if _prompt_tween and _prompt_tween.is_valid():
			_prompt_tween.kill()
		if is_instance_valid(continue_prompt):
			continue_prompt.scale = Vector2.ONE
			continue_prompt.visible = false
		if is_instance_valid(stage_label):
			stage_label.modulate.a = 1.0
		get_viewport().set_input_as_handled()
		GlobalSoundManager.play_sfx("click")
		_is_finishing = true
		_finish()


func _finish() -> void:
	_update_progress_ui(100.0)
	if is_instance_valid(fade_overlay):
		var fade := create_tween()
		fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade.tween_property(fade_overlay, "color:a", 1.0, 0.25)
		fade.tween_callback(_complete_transition)
	else:
		_complete_transition()


func _complete_transition() -> void:
	if auto_change_scene:
		if _loaded_packed_scene:
			get_tree().change_scene_to_packed(_loaded_packed_scene)
		else:
			get_tree().change_scene_to_file(target_scene_path)
	else:
		finished.emit()
		queue_free()
