extends CanvasLayer
class_name DockShack

## Liman Barakası & Dalış Hazırlık İskelesi
## Dalgıcın dalış öncesi ekipman kontrolü yaptığı, fenerini şarj ettiği ve
## loading screen eşliğinde okyanusa daldığı veya şehir haritasına döndüğü kompakt denizci hub'ı.

# Sahneler
@export var inventory_scene: PackedScene = preload("res://Scenes/inventory.tscn")
@export var collection_scene: PackedScene = preload("res://Scenes/collection.tscn")
@export var settings_scene: PackedScene = preload("res://Scenes/settings_menu.tscn")
@export var loading_scene: PackedScene = preload("res://Scenes/loading_screen.tscn")
var city_map_scene: PackedScene = null

# HUD & Referanslar
@onready var location_badge: Label = %LocationBadge
@onready var zurna_label: Label = %ZurnaLabel
@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var city_button: Button = %CityButton
@onready var settings_button: Button = %SettingsButton

# Dalış & Aksiyon Düğmeleri
@onready var dive_button: Button = %DiveButton
@onready var inventory_button: Button = %InventoryButton
@onready var collection_button: Button = %CollectionButton

# Ekipman Kartları ve Rozetleri (Saf Durum HUD)
@onready var bag_card: PanelContainer = %BagCard
@onready var tank_card: PanelContainer = %TankCard
@onready var mask_card: PanelContainer = %MaskCard
@onready var fins_card: PanelContainer = %FinsCard
@onready var light_card: PanelContainer = %LightCard

@onready var bag_info_label: Label = %BagInfoLabel
@onready var tank_info_label: Label = %TankInfoLabel
@onready var mask_info_label: Label = %MaskInfoLabel
@onready var fins_info_label: Label = %FinsInfoLabel
@onready var light_info_label: Label = %LightInfoLabel
@onready var battery_progress: ProgressBar = %BatteryProgressBar
@onready var battery_percent_label: Label = %BatteryPercentLabel

# Toast & Bilgilendirme
@onready var toast_panel: PanelContainer = %ToastPanel
@onready var toast_label: Label = %ToastLabel
@onready var tip_label: Label = %TipLabel

var _displayed_money: int = 0
var _current_day: int = 1
var _money_tween: Tween = null
var _toast_tween: Tween = null
var _active_sub_menu: Node = null
var _is_transitioning: bool = false


func _ready() -> void:
	layer = 75
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	add_to_group("popup_ui")
	add_to_group("hub_menu")

	var time_mgr: Node = _get_time_mgr()
	if time_mgr:
		time_mgr.time_changed.connect(func(_h: int, _m: int) -> void: refresh_ui())
		time_mgr.day_changed.connect(_on_day_changed)
		if time_mgr.has_signal("dive_lock_changed"):
			time_mgr.dive_lock_changed.connect(_on_dive_lock_changed)
		_current_day = int(time_mgr.get("current_day"))

	_displayed_money = GlobalEconomy.money
	GlobalEconomy.money_changed.connect(_on_money_changed)
	GlobalInventory.inventory_updated.connect(refresh_ui)
	GlobalInventory.equipment_updated.connect(_on_equipment_updated)

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("battery_changed"):
		if not player.battery_changed.is_connected(_on_player_battery_changed):
			player.battery_changed.connect(_on_player_battery_changed)

	# Buton Bağlantıları
	dive_button.pressed.connect(_on_start_dive_pressed)
	city_button.pressed.connect(_on_visit_city_pressed)
	if is_instance_valid(inventory_button):
		inventory_button.pressed.connect(_on_inventory_pressed)
	if is_instance_valid(collection_button):
		collection_button.pressed.connect(_on_collection_pressed)
	if is_instance_valid(settings_button):
		settings_button.pressed.connect(_on_settings_pressed)

	# Kart Etkileşimleri
	_setup_card_interactions()

	# Mikro-Juice (Buton animasyonları)
	for b in [dive_button, inventory_button, collection_button, city_button, settings_button]:
		_setup_button_juice(b)

	if is_instance_valid(toast_panel):
		toast_panel.visible = false
		toast_panel.modulate.a = 0.0

	GlobalSoundManager.play_sfx("door_open")
	refresh_ui()


func _exit_tree() -> void:
	remove_from_group("popup_ui")
	remove_from_group("hub_menu")
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("battery_changed") and player.battery_changed.is_connected(_on_player_battery_changed):
		player.battery_changed.disconnect(_on_player_battery_changed)
	if GlobalEconomy.money_changed.is_connected(_on_money_changed):
		GlobalEconomy.money_changed.disconnect(_on_money_changed)
	if GlobalInventory.inventory_updated.is_connected(refresh_ui):
		GlobalInventory.inventory_updated.disconnect(refresh_ui)
	if GlobalInventory.equipment_updated.is_connected(_on_equipment_updated):
		GlobalInventory.equipment_updated.disconnect(_on_equipment_updated)


func refresh_ui() -> void:
	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	if is_instance_valid(location_badge):
		location_badge.text = "⚓ DOCK SHACK & PIER" if is_en else "⚓ LİMAN BARAKASI & İSKELE"

	if is_instance_valid(zurna_label):
		zurna_label.text = "💰 %d Zurna" % _displayed_money

	if is_instance_valid(day_label):
		day_label.text = ("📅 DAY %d" if is_en else "📅 GÜN %d") % _current_day

	var time_mgr: Node = _get_time_mgr()
	if time_mgr and is_instance_valid(time_label):
		time_label.text = "⏰ " + time_mgr.get_time_string()

	if is_instance_valid(city_button):
		city_button.text = "🗺️ VISIT CITY" if is_en else "🗺️ ŞEHRE ÇIK"

	if is_instance_valid(inventory_button):
		var count: int = GlobalInventory.collected_items.size()
		var cap: int = GlobalInventory.get_capacity()
		inventory_button.text = ("🎒 BAG (%d/%d)" if is_en else "🎒 ÇANTA (%d/%d)") % [count, cap]

	if is_instance_valid(collection_button):
		collection_button.text = "📖 COLLECTION" if is_en else "📖 KOLEKSİYON"

	# Dalış Butonu Durumu (Gece Kontrolü)
	var is_allowed: bool = time_mgr.is_dive_allowed() if time_mgr else true
	if is_instance_valid(dive_button):
		if is_allowed:
			dive_button.text = "🤿 START DIVE" if is_en else "🤿 DALIŞA BAŞLA"
			dive_button.disabled = false
			dive_button.modulate = Color.WHITE
		else:
			dive_button.text = "⚠️ DIVE CLOSED (NIGHT)" if is_en else "⚠️ DALIŞ KAPALI (GECE)"
			dive_button.disabled = false
			dive_button.modulate = Color(1.0, 0.6, 0.6, 1.0)

	_refresh_equipment_cards(is_en)

	# Dinamik İpucu / Durum Bilgisi
	if is_instance_valid(tip_label):
		if not is_allowed:
			tip_label.text = (
				"⚠️ Night has fallen (19:00+). Return to town and advance the day to dive!"
				if is_en else
				"⚠️ Hava karardı (19:00+). Dalış yapabilmek için şehre dönüp günü ilerletmelisin!"
			)
		else:
			var bat_info: Dictionary = _get_battery_info()
			var flash_lvl: int = int(bat_info["level"])
			var bat_pct: int = int(bat_info["pct"])
			if flash_lvl > 0 and bat_pct < 20:
				tip_label.text = (
					"⚠️ Flashlight battery is low! You can recharge it at the town's Charge Station."
					if is_en else
					"⚠️ Fener bataryası azaldı! Kasabadaki Şarj İstasyonunda doldurabilirsin."
				)
			elif flash_lvl == 0:
				tip_label.text = (
					"💡 Flashlight not equipped. You can buy one at the Town Equipment Shop."
					if is_en else
					"💡 Fenerin takılı değil. Kasabadaki Ekipman Mağazasından satın alabilirsin."
				)
			else:
				tip_label.text = (
					"💡 Check your gear and dive into the depths! Upgrades and recharge are in town."
					if is_en else
					"💡 Ekipmanlarını kontrol et ve derinliklere dal! Geliştirme ve şarj kasabadadır."
				)


func _get_stat(key: String, default_val: int = 0) -> int:
	if GlobalInventory.has_method("get_equipment_stat"):
		return GlobalInventory.get_equipment_stat(key, default_val)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get(key) != null:
		return int(player.get(key))
	var save_data: Dictionary = GlobalInventory.get_save_data()
	if not save_data.is_empty() and save_data.has("equipment"):
		var eq: Dictionary = save_data["equipment"]
		if eq.has(key):
			return int(eq[key])
	return default_val


func _get_battery_info() -> Dictionary:
	var flash_lvl: int = _get_stat("flashlight_level", 0)
	var player = get_tree().get_first_node_in_group("player")
	var max_bat: float = 75.0 + float(max(0, flash_lvl - 1)) * 8.93 if flash_lvl > 0 else 60.0
	var cur_bat: float = 0.0

	if player:
		if player.has_method("get_flashlight_max_battery"):
			max_bat = player.get_flashlight_max_battery()
		if player.get("current_battery") != null:
			cur_bat = float(player.get("current_battery"))
	else:
		var save_data: Dictionary = GlobalInventory.get_save_data()
		if not save_data.is_empty() and save_data.has("equipment"):
			var eq: Dictionary = save_data["equipment"]
			if eq.has("current_battery") and float(eq["current_battery"]) >= 0.0:
				cur_bat = float(eq["current_battery"])
			else:
				cur_bat = max_bat

	if cur_bat < 0.0:
		cur_bat = max_bat

	var ratio: float = clamp(cur_bat / max(max_bat, 0.01), 0.0, 1.0) if max_bat > 0.0 else 0.0
	var pct: int = int(round(ratio * 100.0))
	return {"cur": cur_bat, "max": max_bat, "pct": pct, "level": flash_lvl}


func _refresh_equipment_cards(is_en: bool) -> void:
	var bag_lvl: int = _get_stat("backpack_level", 0)
	var tank_lvl: int = _get_stat("tube_level", 1)
	var mask_lvl: int = _get_stat("goggles_level", 0)
	var fins_lvl: int = _get_stat("fins_level", 0)
	var bat_info: Dictionary = _get_battery_info()
	var light_lvl: int = int(bat_info["level"])

	var cap: int = GlobalInventory.get_capacity()

	if is_instance_valid(bag_info_label):
		bag_info_label.text = ("Backpack Lv.%d\n%d Slots" if is_en else "Sırt Çantası Lv.%d\n%d Slot") % [bag_lvl, cap]
	if is_instance_valid(bag_card):
		bag_card.tooltip_text = (
			"🎒 Backpack Capacity: %d Slots\nClick to open backpack"
			if is_en else
			"🎒 Sırt Çantası Kapasitesi: %d Slot\nÇantayı açmak için tıkla"
		) % cap

	if is_instance_valid(tank_info_label):
		var cur_eff: float = 1.0 + float(max(0, tank_lvl - 1)) * 1.25
		tank_info_label.text = ("O2 Tank Lv.%d\nOxygen: x%.2f" if is_en else "Oksijen Tüpü Lv.%d\nOksijen: x%.2f") % [tank_lvl, cur_eff]
	if is_instance_valid(tank_card):
		var cur_eff: float = 1.0 + float(max(0, tank_lvl - 1)) * 1.25
		tank_card.tooltip_text = (
			"🤿 Oxygen Tank Lv.%d\nOxygen Resistance: x%.2f\nReduces oxygen consumption in deep water"
			if is_en else
			"🤿 Oksijen Tüpü Lv.%d\nOksijen Direnci: x%.2f\nDerin sularda oksijen tüketimini azaltır"
		) % [tank_lvl, cur_eff]

	if is_instance_valid(mask_info_label):
		var zoom_val: float = 1.0 + (mask_lvl * 0.15)
		mask_info_label.text = ("Diving Mask Lv.%d\nZoom: x%.1f" if is_en else "Dalış Maskesi Lv.%d\nZoom: x%.1f") % [mask_lvl, zoom_val]
	if is_instance_valid(mask_card):
		var zoom_val: float = 1.0 + (mask_lvl * 0.15)
		mask_card.tooltip_text = (
			"🥽 Diving Mask Lv.%d\nWide Angle Vision / Zoom: x%.1f\nImproves underwater visibility"
			if is_en else
			"🥽 Dalış Maskesi Lv.%d\nGeniş Açı Görüş / Zoom: x%.1f\nSualtı görüş alanını genişletir"
		) % [mask_lvl, zoom_val]

	if is_instance_valid(fins_info_label):
		var spd: int = int(round(fins_lvl * 55.0))
		fins_info_label.text = ("Fins Lv.%d\nSpeed: +%d px/s" if is_en else "Palet Lv.%d\nHız: +%d px/s") % [fins_lvl, spd]
	if is_instance_valid(fins_card):
		var spd: int = int(round(fins_lvl * 55.0))
		fins_card.tooltip_text = (
			"🐬 Fins Lv.%d\nSwim Speed Bonus: +%d px/s\nIncreases movement speed underwater"
			if is_en else
			"🐬 Palet Lv.%d\nYüzme Hızı Bonusu: +%d px/s\nSualtı hareket hızını artırır"
		) % [fins_lvl, spd]

	# Fener ve Canlı Batarya
	var bat_percent: int = int(bat_info["pct"])
	var cur_bat_sec: int = int(round(float(bat_info["cur"])))
	var max_bat_sec: int = int(round(float(bat_info["max"])))

	if is_instance_valid(light_info_label):
		if light_lvl > 0:
			light_info_label.text = ("Flashlight Lv.%d" if is_en else "Dalış Feneri Lv.%d") % light_lvl
		else:
			light_info_label.text = "No Flashlight" if is_en else "Fener Yok"

	if is_instance_valid(battery_progress):
		battery_progress.value = bat_percent
		battery_progress.visible = (light_lvl > 0)
	if is_instance_valid(battery_percent_label):
		battery_percent_label.text = "%%%d" % bat_percent
		battery_percent_label.visible = (light_lvl > 0)

	if is_instance_valid(light_card):
		if light_lvl > 0:
			light_card.tooltip_text = (
				"🔦 Dive Light Lv.%d\nBattery: %%%d (%ds/%ds)\nRecharge available at Town Charge Station"
				if is_en else
				"🔦 Dalış Feneri Lv.%d\nBatarya: %%%d (%ds/%ds)\nŞarj İstasyonu Liman Kasabasındadır"
			) % [light_lvl, bat_percent, cur_bat_sec, max_bat_sec]
		else:
			light_card.tooltip_text = (
				"🔦 No Flashlight\nCan be purchased at Town Equipment Shop"
				if is_en else
				"🔦 Fener Yok\nKasabadaki Ekipman Mağazasından satın alınabilir"
			)


func _setup_card_interactions() -> void:
	var cards: Array[PanelContainer] = [bag_card, tank_card, mask_card, fins_card, light_card]
	for c in cards:
		if not is_instance_valid(c):
			continue
		c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		c.pivot_offset = c.size / 2.0
		c.resized.connect(func() -> void:
			if is_instance_valid(c):
				c.pivot_offset = c.size / 2.0
		)
		c.mouse_entered.connect(func() -> void:
			if is_instance_valid(c):
				var tw := create_tween()
				tw.tween_property(c, "scale", Vector2(1.03, 1.03), 0.08)
		)
		c.mouse_exited.connect(func() -> void:
			if is_instance_valid(c):
				var tw := create_tween()
				tw.tween_property(c, "scale", Vector2(1.0, 1.0), 0.08)
		)
		c.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GlobalSoundManager.play_sfx("click")
				var tw := create_tween()
				tw.tween_property(c, "scale", Vector2(0.97, 0.97), 0.05)
				tw.tween_property(c, "scale", Vector2(1.03, 1.03), 0.08)
				if c == bag_card:
					_on_inventory_pressed()
				elif c.tooltip_text != "":
					_show_toast(c.tooltip_text.split("\n")[0])
		)


func _on_start_dive_pressed() -> void:
	if _is_transitioning:
		return

	var time_mgr: Node = _get_time_mgr()
	var is_allowed: bool = time_mgr.is_dive_allowed() if time_mgr else true
	var is_en: bool = ItemTranslator.get_current_locale() == "en"

	if not is_allowed:
		GlobalSoundManager.play_sfx("error")
		_show_toast(
			"⚠️ Night has fallen (19:00+). Return to town and advance the day to dive!"
			if is_en else
			"⚠️ Hava karardı (19:00+). Dalış yapabilmek için şehre dönüp günü ilerletmelisin!"
		)
		return

	_is_transitioning = true
	GlobalSoundManager.play_sfx("click")

	var player = get_tree().get_first_node_in_group("player")
	if player:
		if time_mgr:
			time_mgr.record_dive()
			time_mgr.start_clock()

		var surface_y: float = InfiniteMapManager.water_surface_y
		var spawn_y: float = surface_y - 60.0
		var spawn_x: float = 16.0 + randf_range(-1200.0, 1200.0)
		player.set("global_position", Vector2(spawn_x, spawn_y))
		player.set("velocity", Vector2(0.0, 450.0))
		player.set("current_oxygen", 100.0)
		player.set("current_health", 100.0)

		GlobalSoundManager.play_sfx("water_splash")
		get_tree().paused = false
		get_tree().call_group("hud", "refresh_ui")
		queue_free()
	else:
		if time_mgr:
			time_mgr.record_dive()
			time_mgr.start_clock()
		GlobalSoundManager.play_sfx("water_splash")
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_visit_city_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	GlobalSoundManager.play_sfx("door_close")

	# Ortam geçişi: İskele Barakası -> Şehir Haritası (Loading Screen ile)
	_play_transition(func() -> void:
		var scene: PackedScene = city_map_scene if city_map_scene else load("res://Scenes/city_map.tscn")
		if scene:
			var city_inst = scene.instantiate()
			get_tree().current_scene.add_child(city_inst)
		else:
			get_tree().change_scene_to_file("res://Scenes/city_map.tscn")
		queue_free()
	, 0.8)


func _on_inventory_pressed() -> void:
	if inventory_scene:
		_open_sub_scene(inventory_scene)


func _on_collection_pressed() -> void:
	if collection_scene:
		_open_sub_scene(collection_scene)


func _on_settings_pressed() -> void:
	if settings_scene:
		_open_sub_scene(settings_scene)


func _open_sub_scene(packed: PackedScene) -> void:
	if not packed:
		return
	if is_instance_valid(_active_sub_menu):
		_active_sub_menu.queue_free()
		_active_sub_menu = null

	GlobalSoundManager.play_sfx("click")
	var inst: Node = packed.instantiate()
	_active_sub_menu = inst

	# Katman Düzeltmesi: Sub-menu CanvasLayer'ı DockShack (layer 75) üzerinde renderlansın
	if inst is CanvasLayer:
		inst.layer = 95

	add_child(inst)

	inst.tree_exited.connect(func() -> void:
		_active_sub_menu = null
		refresh_ui()
	)


func _play_transition(on_complete: Callable, display_time: float = 1.0) -> void:
	if not loading_scene:
		on_complete.call()
		return

	var loading_inst = loading_scene.instantiate()
	loading_inst.auto_change_scene = false
	loading_inst.min_display_time = display_time
	var layer_node := CanvasLayer.new()
	layer_node.layer = 150
	layer_node.add_child(loading_inst)
	get_tree().current_scene.add_child(layer_node)

	loading_inst.finished.connect(func() -> void:
		layer_node.queue_free()
		on_complete.call()
	)


func _show_toast(msg: String) -> void:
	if not is_instance_valid(toast_panel) or not is_instance_valid(toast_label):
		return
	toast_label.text = msg
	toast_panel.visible = true

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(func() -> void:
		if is_instance_valid(toast_panel):
			toast_panel.visible = false
	)


func _on_money_changed(amount: Variant) -> void:
	var target_amount: int = int(amount)
	if _money_tween and _money_tween.is_valid():
		_money_tween.kill()

	var start_amount: int = _displayed_money
	_money_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_money_tween.tween_method(func(val: int) -> void:
		_displayed_money = val
		if is_instance_valid(zurna_label):
			zurna_label.text = "💰 %d Zurna" % val
	, start_amount, target_amount, 0.4)


func _on_equipment_updated(_stat_key: String = "", _new_level: int = 0) -> void:
	refresh_ui()


func _on_player_battery_changed(_cur: float = 0.0, _max: float = 0.0) -> void:
	refresh_ui()


func _on_day_changed(new_day: int) -> void:
	_current_day = new_day
	refresh_ui()


func _on_dive_lock_changed(_is_locked: bool) -> void:
	refresh_ui()


func _setup_button_juice(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func() -> void:
		if is_instance_valid(btn):
			btn.pivot_offset = btn.size / 2.0
	)
	btn.mouse_entered.connect(func() -> void:
		if is_instance_valid(btn) and not btn.disabled:
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.08)
	)
	btn.mouse_exited.connect(func() -> void:
		if is_instance_valid(btn):
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)
	btn.pressed.connect(func() -> void:
		if is_instance_valid(btn):
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(_active_sub_menu):
				_active_sub_menu.queue_free()
				_active_sub_menu = null
				get_viewport().set_input_as_handled()
				refresh_ui()
			else:
				_on_visit_city_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_I:
			_on_inventory_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C:
			_on_collection_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			_on_visit_city_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if not is_instance_valid(_active_sub_menu):
				_on_start_dive_pressed()
				get_viewport().set_input_as_handled()


func _get_time_mgr() -> Node:
	return get_node_or_null("/root/GlobalTime")
