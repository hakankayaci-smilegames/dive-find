extends CanvasLayer

## Geliştirici & Hile Konsolu (Global Dev Console)
## 'é' veya '~' tuşu ile açılıp kapanır. Modüler komut sistemine sahiptir.

@onready var console_panel: Control = %ConsolePanel
@onready var output_label: RichTextLabel = %OutputLabel
@onready var input_line: LineEdit = %InputLine

var _commands: Dictionary = {}
var _history: Array[String] = []
var _history_index: int = -1
var _max_history: int = 50


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	console_panel.visible = false

	input_line.text_submitted.connect(_on_command_submitted)

	# Temel Sistem Komutları
	register_command("help", _cmd_help, "Kullanılabilir tüm komutları listeler.")
	register_command("clear", _cmd_clear, "Konsol ekranını temizler.")

	# Hile & Geliştirici Komutları
	register_command("money", _cmd_money, "Cüzdana Zurna ekler veya eksiltir. (Kullanım: money <miktar>)")
	register_command("upgrade", _cmd_upgrade, "Belirtilen ekipmanı geliştirir. (Kullanım: upgrade <tube|fins|goggles|bag> [seviye])")
	register_command("upgrade_all", _cmd_upgrade_all, "Tüm ekipmanları belirtilen seviyeye çeker veya +1 artırır. (Kullanım: upgrade_all [seviye])")
	register_command("fill_inv", _cmd_fill_inv, "Çantayı kapasite dolana kadar rastgele eşyalarla doldurur.")
	register_command("god", _cmd_god, "Ölümsüzlük modunu açar/kapatır (Can ve oksijen asla bitmez).")
	register_command("surface", _cmd_surface, "Oyuncuyu anında su yüzeyine ışınlar.")
	register_command("tp", _cmd_tp, "Oyuncuyu istenen derinliğe ışınlar. (Kullanım: tp <metre>)")
	register_command("office", _cmd_office, "Nerede olursan ol Ofis & Dalış Karargahını açar.")
	register_command("die", _cmd_die, "Oyuncunun canını sıfırlar ve Game Over ekranını tetikler.")

	_log_info("[color=#70a5ff][ Dive&Find Hile & Geliştirici Konsolu Hazır ][/color]")
	_log_info("[color=#aaaaaa]Yardım için [b]help[/b] yazabilirsiniz. Kapatmak için [b]é[/b] veya [b]ESC[/b].[/color]\n")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key_event := event as InputEventKey

	if _is_toggle_key(key_event):
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
		_log_error("Kullanım: upgrade <tube|fins|goggles|bag> [seviye]")
		return
	var target := str(args[0]).to_lower()
	var stat_key := ""
	match target:
		"tube", "tup", "oksijen": stat_key = "tube_level"
		"fins", "palet", "hiz": stat_key = "fins_level"
		"goggles", "gozluk", "zoom": stat_key = "goggles_level"
		"bag", "canta", "backpack", "kapasite": stat_key = "backpack_level"
		_:
			_log_error("Bilinmeyen ekipman: '%s'. Geçerli olanlar: tube, fins, goggles, bag" % target)
			return
	var cur_val: int = int(player.get(stat_key))
	var new_val: int = cur_val + 1
	if args.size() >= 2:
		new_val = int(args[1])
	player.set(stat_key, new_val)
	_log_success("%s seviyesi güncellendi: Lvl %d" % [stat_key, new_val])


func _cmd_upgrade_all(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_log_error("Oyuncu sahnede bulunamadı!")
		return
	var keys := ["tube_level", "fins_level", "goggles_level", "backpack_level"]
	var has_lvl := not args.is_empty()
	var target_lvl := int(args[0]) if has_lvl else 0
	for k in keys:
		var val := target_lvl if has_lvl else int(player.get(k)) + 1
		player.set(k, val)
	_log_success("Tüm ekipmanlar güncellendi! (Tüp: Lvl %d, Palet: Lvl %d, Gözlük: Lvl %d, Çanta: Lvl %d)" % [
		player.get("tube_level"), player.get("fins_level"), player.get("goggles_level"), player.get("backpack_level")
	])


func _cmd_fill_inv() -> void:
	var items := GlobalInventory.get_all_items()
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
