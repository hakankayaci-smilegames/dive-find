extends CanvasLayer

signal battery_charged(new_battery: float)

@onready var close_button: Button = %CloseButton
@onready var battery_title_label: Label = %BatteryTitleLabel
@onready var battery_progress: ProgressBar = %BatteryProgress
@onready var progress_text: Label = %ProgressText
@onready var charge_slider: HSlider = %ChargeSlider
@onready var max_button: Button = %MaxButton
@onready var cost_label: Label = %CostLabel
@onready var wallet_label: Label = %WalletLabel
@onready var charge_button: Button = %ChargeButton
@onready var backdrop: ColorRect = get_node_or_null("Backdrop")

var player: Node = null
var _max_battery: float = 0.0
var _cur_battery: float = 0.0
var _cur_pct: int = 0
var _target_pct: int = 100


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_tree().get_first_node_in_group("player")

	close_button.pressed.connect(_on_close_pressed)
	charge_slider.value_changed.connect(_on_slider_changed)
	max_button.pressed.connect(_on_max_pressed)
	charge_button.pressed.connect(_on_charge_pressed)

	if not GlobalEconomy.money_changed.is_connected(_on_money_changed):
		GlobalEconomy.money_changed.connect(_on_money_changed)

	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

	_setup_button_juice(charge_button)
	_setup_button_juice(max_button)
	_setup_button_juice(close_button)

	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()


func _refresh_ui() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")

	var flash_lvl: int = int(player.get("flashlight_level")) if player else 0
	if flash_lvl <= 0:
		battery_title_label.text = "Fener Yok"
		wallet_label.text = "Bakiye: %d Z" % GlobalEconomy.money
		battery_progress.value = 0.0
		progress_text.text = "%0"
		charge_slider.editable = false
		max_button.disabled = true
		charge_button.disabled = true
		charge_button.text = "FENER BULUNAMADI"
		cost_label.text = "Önce Ekipman Mağazasından fener satın alın."
		cost_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4, 1.0))
		return

	_max_battery = player.get_flashlight_max_battery() if player.has_method("get_flashlight_max_battery") else 60.0
	_cur_battery = float(player.get("current_battery"))
	if _cur_battery < 0.0:
		_cur_battery = _max_battery

	if _max_battery > 0.0:
		_cur_pct = int(clamp(round((_cur_battery / _max_battery) * 100.0), 0.0, 100.0))
	else:
		_cur_pct = 100

	battery_title_label.text = tr("Dalış Feneri (Lv. %d)") % flash_lvl
	wallet_label.text = tr("Bakiye: %d Zurna") % GlobalEconomy.money

	if _cur_pct >= 100:
		battery_progress.value = 100.0
		progress_text.text = "%ds / %ds (%%100)" % [int(_cur_battery), int(_max_battery)]
		charge_slider.editable = false
		charge_slider.min_value = 100
		charge_slider.max_value = 100
		charge_slider.value = 100
		max_button.disabled = true
		cost_label.text = "Batarya tamamen dolu!"
		cost_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45, 1.0))
		charge_button.disabled = true
		charge_button.text = "BATARYA DOLU (%100)"
		return

	charge_slider.editable = true
	charge_slider.min_value = _cur_pct
	charge_slider.max_value = 100
	max_button.disabled = false

	if _target_pct < _cur_pct:
		_target_pct = 100
	charge_slider.value = _target_pct

	_update_cost_and_actions()


func _on_slider_changed(val: float) -> void:
	_target_pct = int(val)
	_update_cost_and_actions()


func _on_max_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	_target_pct = 100
	charge_slider.value = 100
	_update_cost_and_actions()


func _on_money_changed(_new_money: int) -> void:
	if is_inside_tree():
		wallet_label.text = tr("Bakiye: %d Zurna") % GlobalEconomy.money
		_update_cost_and_actions()


func _calculate_cost(diff_pct: int) -> int:
	if diff_pct <= 0:
		return 0
	var charged_seconds: float = (float(diff_pct) / 100.0) * _max_battery
	# Dinamik Fiyatlandırma: 1 saniyelik şarj = 0.30 Zurna
	# Lvl 1 (75s): Full dolum = ~23 Zurna
	# Lvl 5 (110s): Full dolum = ~33 Zurna
	# Lvl 15 (200s): Full dolum = 60 Zurna
	var cost: int = int(ceil(charged_seconds * 0.30))
	return max(cost, 1)


func _update_cost_and_actions() -> void:
	var diff_pct: int = _target_pct - _cur_pct
	var cost: int = _calculate_cost(diff_pct)

	battery_progress.value = _target_pct
	var target_units: int = int(round((float(_target_pct) / 100.0) * _max_battery))
	var charged_seconds: int = int(round((float(max(diff_pct, 0)) / 100.0) * _max_battery))

	if diff_pct > 0:
		progress_text.text = "%%%d → %%%d (%ds / %ds)" % [_cur_pct, _target_pct, target_units, int(_max_battery)]
		cost_label.text = "Ücret: %d Zurna (+%ds / +%%%d)" % [cost, charged_seconds, diff_pct]
		cost_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1.0))
	else:
		progress_text.text = "%ds / %ds (%%%d)" % [int(_cur_battery), int(_max_battery), _cur_pct]
		cost_label.text = "Şarj miktarı seçilmedi (0 Zurna)"
		cost_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))

	if diff_pct <= 0:
		charge_button.disabled = true
		charge_button.text = "ŞARJ MİKTARI SEÇİN"
	elif GlobalEconomy.money < cost:
		charge_button.disabled = true
		charge_button.text = "YETERSİZ BAKİYE (%d Zurna)" % cost
	else:
		charge_button.disabled = false
		charge_button.text = tr("⚡ ŞARJ ET (%d Zurna)") % cost


func _on_charge_pressed() -> void:
	var diff_pct: int = _target_pct - _cur_pct
	if diff_pct <= 0:
		return

	var cost: int = _calculate_cost(diff_pct)

	if GlobalEconomy.spend_money(cost):
		var new_battery: float = (float(_target_pct) / 100.0) * _max_battery
		if player:
			player.set("current_battery", new_battery)
			if player.has_method("_broadcast_battery"):
				player.call("_broadcast_battery")
		GlobalSoundManager.play_sfx("upgrade")
		battery_charged.emit(new_battery)
		_refresh_ui()
	else:
		GlobalSoundManager.play_sfx("error")


func _on_close_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	queue_free()


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
			tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.08)
	)
	btn.mouse_exited.connect(func() -> void:
		if is_instance_valid(btn):
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)


func _exit_tree() -> void:
	if GlobalEconomy.money_changed.is_connected(_on_money_changed):
		GlobalEconomy.money_changed.disconnect(_on_money_changed)
