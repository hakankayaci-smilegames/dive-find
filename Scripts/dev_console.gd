extends CanvasLayer

## Geliştirici & Hile Konsolu (Global Dev Console)
## 'é' veya '~' tuşu ile açılıp kapanır. Modüler komut sistemine sahiptir.

@onready var console_panel: Control = %ConsolePanel
@onready var output_label: RichTextLabel = %OutputLabel
@onready var input_line: LineEdit = %InputLine
@onready var close_button: Button = get_node_or_null("%CloseButton")

const SETTINGS_FILE := "user://settings.cfg"

var _commands: Dictionary = {}
var _history: Array[String] = []
var _history_index: int = -1
var _max_history: int = 50
var is_unlocked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	console_panel.visible = false
	_load_unlock_state()

	input_line.text_submitted.connect(_on_command_submitted)
	if is_instance_valid(close_button):
		close_button.pressed.connect(func() -> void:
			set_console_visible(false)
		)

	# Temel Sistem Komutları
	register_command("help", _cmd_help, "Kullanılabilir tüm komutları listeler.")
	register_command("clear", _cmd_clear, "Konsol ekranını temizler.")

	# Hile & Geliştirici Komutları
	register_command("money", _cmd_money, "Cüzdana Zurna ekler veya eksiltir. (Kullanım: money <miktar>)")
	register_command("upgrade", _cmd_upgrade, "Belirtilen ekipmanı geliştirir. (Kullanım: upgrade <tube|fins|goggles|bag|flashlight> [seviye])")
	register_command("upgrade_all", _cmd_upgrade_all, "Tüm ekipmanları belirtilen seviyeye çeker veya +1 artırır. (Kullanım: upgrade_all [seviye])")
	register_command("flashlight", _cmd_flashlight, "Feneri açar/kapatır veya seviyesini ayarlar. (Kullanım: flashlight [seviye|on|off])")
	register_command("fener", _cmd_flashlight, "flashlight komutunun kısayolu.")
	register_command("battery", _cmd_battery, "Fener bataryasını fuller veya miktar belirler. (Kullanım: battery [miktar])")
	register_command("batarya", _cmd_battery, "battery komutunun kısayolu.")
	register_command("fill_inv", _cmd_fill_inv, "Çantayı kapasite dolana kadar rastgele eşyalarla doldurur.")
	register_command("god", _cmd_god, "Ölümsüzlük modunu açar/kapatır (Can ve oksijen asla bitmez).")
	register_command("surface", _cmd_surface, "Oyuncuyu anında su yüzeyine ışınlar.")
	register_command("tp", _cmd_tp, "Oyuncuyu istenen derinliğe ışınlar. (Kullanım: tp <metre>)")
	register_command("office", _cmd_office, "Nerede olursan ol Ofis & Dalış Karargahını açar.")
	register_command("die", _cmd_die, "Oyuncunun canını sıfırlar ve Game Over ekranını tetikler.")
	register_command("time", _cmd_time, "Saati ayarlar. (Kullanım: time <saat> [dakika] - Örn: time 18 45)")
	register_command("add_time", _cmd_add_time, "Saati ileri sarar. (Kullanım: add_time <dakika> - Örn: add_time 30)")
	register_command("time_speed", _cmd_time_speed, "Zaman akış hızını çarpar. (Kullanım: time_speed <çarpan> - Örn: time_speed 5)")
	register_command("skip_day", _cmd_skip_day, "Günü anında bitirip özet ekranını açar.")
	register_command("unlock_all", _cmd_unlock_all, "Koleksiyon defterindeki tüm eşyaları anında açar.")
	register_command("unlockall", _cmd_unlock_all, "unlock_all komutunun kısayolu.")
	register_command("reset_collection", _cmd_reset_collection, "Koleksiyon defterindeki tüm keşifleri sıfırlar.")
	register_command("darkness", _cmd_darkness, "Çevre kararmasını test eder / ayarlar. (Kullanım: darkness [0.0-1.0|reset|abis|day])")
	register_command("karartma", _cmd_darkness, "darkness komutunun kısayolu.")
	register_command("lang", _cmd_lang, "Oyun dilini değiştirir veya mevcut dili gösterir. (Kullanım: lang <tr|en>)")
	register_command("dil", _cmd_lang, "lang komutunun kısayolu. (Kullanım: dil <tr|en>)")

	_log_info("[color=#70a5ff][ Dive&Find Hile & Geliştirici Konsolu Hazır ][/color]")
	_log_info("[color=#aaaaaa]Yardım için [b]help[/b] yazabilirsiniz. Kapatmak için [b]é[/b] veya [b]ESC[/b].[/color]\n")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key_event := event as InputEventKey

	if _is_toggle_key(key_event):
		if not is_unlocked:
			return
		toggle_console()
		get_viewport().set_input_as_handled()
		return

	if console_panel.visible:
		if key_event.keycode == KEY_ESCAPE:
			set_console_visible(false)
			get_viewport().set_input_as_handled()
			return
		elif key_event.keycode == KEY_UP:
			_navigate_history(-1)
			get_viewport().set_input_as_handled()
			return
		elif key_event.keycode == KEY_DOWN:
			_navigate_history(1)
			get_viewport().set_input_as_handled()
			return


func is_dev_console_unlocked() -> bool:
	return is_unlocked


func set_dev_unlocked(unlocked: bool) -> void:
	is_unlocked = unlocked
	var cfg := ConfigFile.new()
	var _err := cfg.load(SETTINGS_FILE)
	cfg.set_value("dev", "dev_console_enabled", unlocked)
	cfg.save(SETTINGS_FILE)
	if not unlocked and console_panel.visible:
		set_console_visible(false)


func _load_unlock_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		is_unlocked = bool(cfg.get_value("dev", "dev_console_enabled", false))
	else:
		is_unlocked = false


func _is_toggle_key(key_event: InputEventKey) -> bool:
	if key_event.keycode == KEY_SECTION or key_event.keycode == KEY_QUOTELEFT or key_event.keycode == KEY_ASCIITILDE:
		return true
	if key_event.physical_keycode == KEY_SECTION or key_event.physical_keycode == KEY_QUOTELEFT:
		return true
	if key_event.unicode == 233 or key_event.unicode == 96 or key_event.unicode == 126:
		return true
	var label := key_event.as_text_key_label().to_lower()
	if label == "é" or label == "`" or label == "~" or label == "section":
		return true
	return false


func toggle_console() -> void:
	if not is_unlocked and not console_panel.visible:
		return
	set_console_visible(not console_panel.visible)


func set_console_visible(is_vis: bool) -> void:
	console_panel.visible = is_vis
	if is_vis:
		input_line.clear()
		input_line.grab_focus()
		_history_index = -1
	else:
		input_line.release_focus()


func register_command(command_name: String, callback: Callable, description: String = "") -> void:
	_commands[command_name.to_lower()] = {
		"callback": callback,
		"description": description
	}


func execute_command_string(full_command: String) -> void:
	var trimmed := full_command.strip_edges()
	if trimmed.is_empty():
		return

	_history.append(trimmed)
	if _history.size() > _max_history:
		_history.pop_front()
	_history_index = -1

	_log_info("[color=#ffd152]> " + trimmed + "[/color]")

	var parts := trimmed.split(" ", false)
	var cmd_name := parts[0].to_lower()
	var args: Array = []
	for i in range(1, parts.size()):
		args.append(parts[i])

	if not _commands.has(cmd_name):
		_log_error("Bilinmeyen komut: '%s'. Komut listesi için 'help' yazın." % cmd_name)
		return

	var cmd_info: Dictionary = _commands[cmd_name]
	var cb: Callable = cmd_info["callback"]

	var cb_arg_count: int = cb.get_argument_count()
	if cb_arg_count == 0:
		cb.call()
	elif cb_arg_count == 1:
		cb.call(args)
	else:
		_log_error("Komut işleyici geçersiz parametre yapısına sahip: %s" % cmd_name)


func _on_command_submitted(text: String) -> void:
	input_line.clear()
	execute_command_string(text)


func _navigate_history(direction: int) -> void:
	if _history.is_empty():
		return

	if direction < 0:
		if _history_index == -1:
			_history_index = _history.size() - 1
		elif _history_index > 0:
			_history_index -= 1
	elif direction > 0:
		if _history_index != -1:
			if _history_index < _history.size() - 1:
				_history_index += 1
			else:
				_history_index = -1
				input_line.text = ""
				return

	if _history_index >= 0 and _history_index < _history.size():
		input_line.text = _history[_history_index]
		input_line.caret_column = input_line.text.length()


# ------------------------------------------------------------------
# LOG ÇIKTI METOTLARI
# ------------------------------------------------------------------

func _log_info(msg: String) -> void:
	output_label.append_text(msg + "\n")


func _log_success(msg: String) -> void:
	output_label.append_text("[color=#55ff55]✔ " + msg + "[/color]\n")


func _log_error(msg: String) -> void:
	output_label.append_text("[color=#ff5555]✖ " + msg + "[/color]\n")


# ------------------------------------------------------------------
# KOMUT İŞLEYİCİLERİ (COMMAND HANDLERS)
# ------------------------------------------------------------------

func _cmd_help() -> void:
	_log_info("[color=#ffd152]--- MEVCUT KOMUTLAR ---[/color]")
	var keys := _commands.keys()
	keys.sort()
	for k in keys:
		var desc: String = _commands[k]["description"]
		_log_info("  [color=#55ffff]%s[/color]: %s" % [k, desc])
	_log_info("[color=#ffd152]-------------------------[/color]")


func _cmd_clear() -> void:
	output_label.clear()


func _cmd_money(args: Array) -> void:
	if args.is_empty():
		_log_info("Mevcut bakiye: %d Zurna. Kullanım: money <miktar>" % GlobalEconomy.money)
		return
	var amount := int(args[0])
	GlobalEconomy.add_money(amount)
	_log_success("Para güncellendi (%+d). Yeni bakiye: %d Zurna" % [amount, GlobalEconomy.money])


func _cmd_upgrade(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_log_error("Oyuncu sahnede bulunamadı!")
		return
	if args.is_empty():
		_log_error("Kullanım: upgrade <tube|fins|goggles|bag|flashlight> [seviye]")
		return
	var target := str(args[0]).to_lower()
	var stat_key := ""
	match target:
		"tube", "tup", "oksijen": stat_key = "tube_level"
		"fins", "palet", "hiz": stat_key = "fins_level"
		"goggles", "gozluk", "zoom": stat_key = "goggles_level"
		"bag", "canta", "backpack", "kapasite": stat_key = "backpack_level"
		"flashlight", "fener", "isik", "light": stat_key = "flashlight_level"
		_:
			_log_error("Bilinmeyen ekipman: '%s'. Geçerli olanlar: tube, fins, goggles, bag, flashlight" % target)
			return
	var cur_val: int = int(player.get(stat_key))
	var new_val: int = cur_val + 1
	if args.size() >= 2:
		new_val = int(args[1])
	player.set(stat_key, new_val)
	GlobalInventory.inventory_updated.emit()
	_log_success("%s seviyesi güncellendi: Lvl %d" % [stat_key, new_val])


func _cmd_upgrade_all(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_log_error("Oyuncu sahnede bulunamadı!")
		return
	var keys := ["tube_level", "fins_level", "goggles_level", "backpack_level", "flashlight_level"]
	var has_lvl := not args.is_empty()
	var target_lvl := int(args[0]) if has_lvl else 0
	for k in keys:
		var val := target_lvl if has_lvl else int(player.get(k)) + 1
		player.set(k, val)
	GlobalInventory.inventory_updated.emit()
	_log_success("Tüm ekipmanlar güncellendi! (Tüp: Lvl %d, Palet: Lvl %d, Gözlük: Lvl %d, Çanta: Lvl %d, Fener: Lvl %d)" % [
		player.get("tube_level"), player.get("fins_level"), player.get("goggles_level"), player.get("backpack_level"), player.get("flashlight_level")
	])


func _cmd_flashlight(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_log_error("Oyuncu sahnede bulunamadı!")
		return
	if args.is_empty():
		if int(player.get("flashlight_level")) <= 0:
			player.set("flashlight_level", 1)
			player.set("is_flashlight_on", true)
			GlobalInventory.inventory_updated.emit()
			_log_success("Fener Lvl 1 olarak açıldı!")
			return
		var cur_state: bool = bool(player.get("is_flashlight_on"))
		player.set("is_flashlight_on", not cur_state)
		_log_success("Fener %s" % ("AÇILDI" if player.get("is_flashlight_on") else "KAPATILDI"))
		return
	var arg0 := str(args[0]).to_lower()
	if arg0 == "on" or arg0 == "ac" or arg0 == "aç":
		if int(player.get("flashlight_level")) <= 0:
			player.set("flashlight_level", 1)
			GlobalInventory.inventory_updated.emit()
		player.set("is_flashlight_on", true)
		_log_success("Fener AÇILDI")
	elif arg0 == "off" or arg0 == "kapat":
		player.set("is_flashlight_on", false)
		_log_success("Fener KAPATILDI")
	elif arg0.is_valid_int():
		var lvl := int(arg0)
		player.set("flashlight_level", lvl)
		if lvl > 0:
			player.set("is_flashlight_on", true)
		GlobalInventory.inventory_updated.emit()
		_log_success("Fener seviyesi güncellendi: Lvl %d (Durum: %s)" % [lvl, "AÇIK" if player.get("is_flashlight_on") else "KAPALI"])
	else:
		_log_error("Geçersiz parametre. Kullanım: flashlight [seviye|on|off]")


func _cmd_battery(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_log_error("Oyuncu sahnede bulunamadı!")
		return
	var max_b: float = float(player.get("max_battery"))
	if max_b <= 0.0:
		max_b = 75.0
	if args.is_empty():
		player.set("current_battery", max_b)
		_log_success("Fener bataryası tamamen dolduruldu! (%.1f / %.1f)" % [max_b, max_b])
		return
	var amount := float(args[0])
	player.set("current_battery", clampf(amount, 0.0, max_b))
	_log_success("Batarya ayarlandı: %.1f / %.1f" % [float(player.get("current_battery")), max_b])


func _cmd_fill_inv() -> void:
	var items: Array[ItemData] = GlobalInventory.get_all_items()
	if items.is_empty():
		_log_error("all_items_tres klasöründe eşya bulunamadı!")
		return
	var added_count := 0
	while GlobalInventory.has_space():
		var random_item := items.pick_random() as ItemData
		if not GlobalInventory.add_item(random_item):
			break
		added_count += 1
	_log_success("Çanta dolduruldu! +%d adet eşya eklendi. (Toplam: %d/%d)" % [
		added_count, GlobalInventory.collected_items.size(), GlobalInventory.get_capacity()
	])


func _cmd_god() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_log_error("Oyuncu sahnede bulunamadı!")
		return
	player.set("godmode_enabled", not bool(player.get("godmode_enabled")))
	var status := "AÇIK (Can ve oksijen tükenmez)" if player.get("godmode_enabled") else "KAPALI"
	_log_success("Ölümsüzlük Modu (Godmode): %s" % status)


func _cmd_surface() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_log_error("Oyuncu sahnede bulunamadı!")
		return
	var surface_y: float = InfiniteMapManager.water_surface_y
	player.set("global_position", Vector2(player.get("global_position").x, surface_y - 30.0))
	player.set("velocity", Vector2.ZERO)
	set_console_visible(false)
	_log_success("Oyuncu su yüzeyine ışınlandı!")


func _cmd_tp(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_log_error("Oyuncu sahnede bulunamadı!")
		return
	if args.is_empty():
		_log_error("Kullanım: tp <metre> (Örn: tp 700)")
		return
	var depth_m := float(args[0])
	var surface_y: float = InfiniteMapManager.water_surface_y
	var target_y := surface_y + (depth_m * 50.0)
	player.set("global_position", Vector2(player.get("global_position").x, target_y))
	player.set("velocity", Vector2.ZERO)
	set_console_visible(false)
	_log_success("Oyuncu %d metre derinliğe ışınlandı!" % int(depth_m))


func _cmd_office() -> void:
	var office_scene = load("res://Scenes/office_menu.tscn")
	if not office_scene:
		_log_error("office_menu.tscn sahnesi bulunamadı!")
		return
	set_console_visible(false)
	get_tree().current_scene.add_child(office_scene.instantiate())
	_log_success("Ofis menüsü açıldı!")


func _cmd_die() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_log_error("Oyuncu sahnede bulunamadı!")
		return
	player.set("godmode_enabled", false)
	player.set("current_health", 0.0)
	player.set("current_oxygen", 0.0)
	if player.has_method("_broadcast_health"):
		player.call("_broadcast_health")
	if player.has_method("_trigger_game_over"):
		player.call("_trigger_game_over")
	set_console_visible(false)
	_log_success("Oyuncu öldürüldü! Game Over tetiklendi.")


func _cmd_time(args: Array) -> void:
	var time_mgr: Node = _get_time_mgr()
	if not time_mgr:
		_log_error("GlobalTime yöneticisi bulunamadı!")
		return
	if args.is_empty():
		_log_info("Mevcut zaman: %s (Gün %d)" % [time_mgr.get_time_string(), int(time_mgr.get("current_day"))])
		return
	var h := int(args[0])
	var m := int(args[1]) if args.size() >= 2 else 0
	time_mgr.set_time(h, m)
	_log_success("Saat ayarlandı: %02d:%02d (Dalış serbest mi: %s)" % [
		int(time_mgr.get("current_hour")), int(time_mgr.get("current_minute")), str(time_mgr.is_dive_allowed())
	])


func _cmd_add_time(args: Array) -> void:
	var time_mgr: Node = _get_time_mgr()
	if not time_mgr:
		_log_error("GlobalTime yöneticisi bulunamadı!")
		return
	var minutes := int(args[0]) if not args.is_empty() else 15
	time_mgr.advance_minutes(minutes)
	_log_success("Zaman ilerletildi (+%d dk). Yeni saat: %s" % [minutes, time_mgr.get_time_string()])


func _cmd_time_speed(args: Array) -> void:
	var time_mgr: Node = _get_time_mgr()
	if not time_mgr:
		_log_error("GlobalTime yöneticisi bulunamadı!")
		return
	if args.is_empty():
		_log_info("Mevcut zaman hız çarpanı: %.2fx" % float(time_mgr.get("time_speed_multiplier")))
		return
	var speed := float(args[0])
	time_mgr.set("time_speed_multiplier", speed)
	_log_success("Zaman akış hızı güncellendi: %.2fx" % speed)


func _cmd_skip_day() -> void:
	var time_mgr: Node = _get_time_mgr()
	if not time_mgr:
		_log_error("GlobalTime yöneticisi bulunamadı!")
		return
	time_mgr.set_time(19, 0)
	var summary_scene = load("res://Scenes/day_summary.tscn")
	if summary_scene:
		set_console_visible(false)
		var summary = summary_scene.instantiate()
		get_tree().current_scene.add_child(summary)
		_log_success("Saat 19:00'a sarıldı ve Gün Özeti Ekranı açıldı!")
	else:
		time_mgr.start_new_day()
		_log_success("Yeni güne geçildi! (Gün %d)" % int(time_mgr.get("current_day")))


func _cmd_unlock_all() -> void:
	var unlocked: int = GlobalInventory.unlock_all_collection()
	var total: int = GlobalInventory.get_all_items().size()
	_log_success("Koleksiyon defteri tamamen açıldı! (Toplam: %d eşya, Yeni açılan: %d)" % [total, unlocked])


func _cmd_reset_collection() -> void:
	GlobalInventory.reset_collection()
	_log_info("[color=#ffaa00]Koleksiyon defterindeki tüm keşifler sıfırlandı![/color]")


func _cmd_darkness(args: Array) -> void:
	var ambient: Node = get_tree().get_first_node_in_group("ambient_light")
	if not ambient:
		_log_error("Sahnede AmbientLight bulunamadı! (Okyanus dalış sahnesinde olmalısınız)")
		return

	if args.is_empty():
		var override_val: float = float(ambient.get("override_brightness"))
		var cur_color: Color = ambient.get("color")
		var status_str := "MANUEL (%.2f)" % override_val if override_val >= 0.0 else "OTOMATİK (Saat + Derinlik)"
		_log_info("Çevre Kararma Modu: %s | Anlık Renk: (R:%.3f, G:%.3f, B:%.3f)" % [
			status_str, cur_color.r, cur_color.g, cur_color.b
		])
		_log_info("Kullanım: darkness <0.0-1.0> (Örn: darkness 0.05) | darkness reset | darkness abis | darkness day")
		return

	var arg0: String = str(args[0]).to_lower()
	if arg0 == "reset" or arg0 == "auto" or arg0 == "otomatik" or arg0 == "normal":
		ambient.set("override_brightness", -1.0)
		_log_success("Karartma OTOMATİK moda alındı. (Derinlik ve oyun saati hesaplaması aktif)")
	elif arg0 == "abis" or arg0 == "dark" or arg0 == "karanlik" or arg0 == "gece":
		ambient.set("override_brightness", 0.005)
		_log_success("Zifiri abis karanlığı testi aktif (Aydınlık: 0.005)")
	elif arg0 == "day" or arg0 == "gunduz" or arg0 == "aydinlik" or arg0 == "light":
		ambient.set("override_brightness", 1.0)
		_log_success("Tam gün ışığı testi aktif (Aydınlık: 1.0)")
	elif arg0.is_valid_float():
		var val: float = clampf(float(arg0), 0.0, 1.0)
		ambient.set("override_brightness", val)
		_log_success("Karartma seviyesi ayarlandı: %.3f (Sıfırlamak için: darkness reset)" % val)
	else:
		_log_error("Geçersiz parametre! Kullanım: darkness <0.0-1.0 | reset | abis | day>")


func _cmd_lang(args: Array) -> void:
	if args.is_empty():
		var cur_locale := TranslationServer.get_locale()
		_log_info("Mevcut Dil: [b]%s[/b] (Kullanım: lang <tr|en>)" % cur_locale)
		return

	var target := str(args[0]).to_lower().strip_edges()
	var new_locale: String = ""
	if target == "tr" or target == "turkce" or target == "türkçe":
		new_locale = "tr"
	elif target == "en" or target == "eng" or target == "english" or target == "ingilizce":
		new_locale = "en"
	else:
		_log_error("Geçersiz dil kodu: '%s'. Desteklenenler: tr, en" % target)
		return

	TranslationServer.set_locale(new_locale)
	_refresh_active_uis()
	if new_locale == "tr":
		_log_success("Oyun dili TÜRKÇE (tr) olarak ayarlandı. (Arayüz yenilendi)")
	else:
		_log_success("Game language set to ENGLISH (en). (UI refreshed)")


func refresh_active_uis() -> void:
	_refresh_active_uis()


func _refresh_active_uis() -> void:
	var cur_scene := get_tree().current_scene
	if is_instance_valid(cur_scene):
		if cur_scene.has_method("_refresh_save_buttons"):
			cur_scene.call("_refresh_save_buttons")
		if cur_scene.has_method("_apply_game_version"):
			cur_scene.call("_apply_game_version")
		if cur_scene.has_method("refresh_ui"):
			cur_scene.call("refresh_ui")

	var office = get_tree().get_first_node_in_group("office_menu")
	if is_instance_valid(office):
		if office.has_method("refresh_ui"):
			office.call("refresh_ui")
		else:
			if office.has_method("_refresh_day"):
				office.call("_refresh_day")
			if office.has_method("_refresh_wallet"):
				office.call("_refresh_wallet")
			if office.has_method("_refresh_battery_badge"):
				office.call("_refresh_battery_badge")
			if office.has_method("_update_dive_button_state"):
				office.call("_update_dive_button_state")
			if office.has_method("_update_merchant_badges"):
				office.call("_update_merchant_badges")

	var mobile_ctrls = get_tree().get_first_node_in_group("mobile_controls")
	if is_instance_valid(mobile_ctrls):
		if mobile_ctrls.has_method("_update_sprint_button_visuals"):
			mobile_ctrls.call("_update_sprint_button_visuals")
		if mobile_ctrls.has_method("_update_flashlight_button_visuals"):
			mobile_ctrls.call("_update_flashlight_button_visuals")
		if mobile_ctrls.has_method("_update_interact_button_state"):
			mobile_ctrls.call("_update_interact_button_state")

	# Açık UI menüleri ve popupları yeni dile senkronize et
	if is_instance_valid(GlobalInventory):
		GlobalInventory.inventory_updated.emit()

	var hud = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud):
		if hud.has_method("refresh_ui"):
			hud.call("refresh_ui")
		else:
			if hud.has_method("_update_bag_button"):
				hud.call("_update_bag_button")
			if hud.has_method("_refresh_equipment_panel"):
				hud.call("_refresh_equipment_panel")

	get_tree().call_group("popup_ui", "refresh_ui")
	get_tree().call_group("item_seller", "refresh_ui")
	get_tree().call_group("laboratory_ui", "refresh_ui")
	get_tree().call_group("equstore", "refresh_ui")


func _get_time_mgr() -> Node:
	return get_node_or_null("/root/GlobalTime")
