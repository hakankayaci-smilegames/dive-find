extends Node
## Modüler eşya yerelleştirme (Localization) yöneticisi (Autoload).
## Translations/item_translations.json dosyasından .tres dosya yollarına göre
## eşyaların aktif dile (tr/en) uygun isim ve açıklamalarını dinamik olarak sağlar.

const TRANSLATIONS_PATH: String = "res://Translations/item_translations.json"

var _translations: Dictionary = {}
var _initialized: bool = false


func _ready() -> void:
	_load_translations()


func _load_translations() -> void:
	if _initialized:
		return
	_initialized = true

	if not FileAccess.file_exists(TRANSLATIONS_PATH):
		push_warning("ItemTranslator: Çeviri dosyası bulunamadı: " + TRANSLATIONS_PATH)
		return

	var file: FileAccess = FileAccess.open(TRANSLATIONS_PATH, FileAccess.READ)
	if not file:
		push_warning("ItemTranslator: Dosya açılamadı: " + TRANSLATIONS_PATH)
		return

	var json_str: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(json_str)
	if error == OK:
		var result: Variant = json.get_data()
		if typeof(result) == TYPE_DICTIONARY:
			_translations = result
		else:
			push_warning("ItemTranslator: JSON kök dizini Dictionary değil.")
	else:
		push_warning("ItemTranslator: JSON Parse Hatası: %s (Satır %d)" % [json.get_error_message(), json.get_error_line()])


func reload() -> void:
	_initialized = false
	_translations.clear()
	_load_translations()


func get_current_locale() -> String:
	var loc: String = TranslationServer.get_locale().to_lower().strip_edges()
	if loc.begins_with("en"):
		return "en"
	return "tr"


func _resolve_item_path(item: ItemData) -> String:
	if not item:
		return ""

	# 1. Öncelik: Doğrudan kaynak yolu (source_path)
	if item.source_path != "" and _translations.has(item.source_path):
		return item.source_path

	# 2. Öncelik: Godot resource_path (res://all_items_tres/*.tres)
	if item.resource_path != "" and _translations.has(item.resource_path):
		return item.resource_path

	# 3. Öncelik: Dosya adı normalize eşleşmesi (örn: "res://all_items_tres/" + dosya adı)
	if item.resource_path != "":
		var filename: String = item.resource_path.get_file()
		var candidate: String = "res://all_items_tres/" + filename
		if _translations.has(candidate):
			return candidate

	# 4. Öncelik: Fallback - item_name ile eşleşen Türkçe ismi ara
	var raw_name: String = item.item_name
	for path_key: String in _translations.keys():
		var entry: Dictionary = _translations[path_key]
		if entry.has("name") and typeof(entry["name"]) == TYPE_DICTIONARY:
			if entry["name"].get("tr", "") == raw_name:
				return path_key

	return ""


func get_item_name(item: ItemData, locale: String = "") -> String:
	if not item:
		return ""

	if not _initialized:
		_load_translations()

	if locale == "":
		locale = get_current_locale()

	var path_key: String = _resolve_item_path(item)
	if path_key != "" and _translations.has(path_key):
		var entry: Dictionary = _translations[path_key]
		if entry.has("name") and typeof(entry["name"]) == TYPE_DICTIONARY:
			var val: String = entry["name"].get(locale, "")
			if val != "":
				return val

	return item.item_name


func get_item_description(item: ItemData, locale: String = "") -> String:
	if not item:
		return ""

	if not _initialized:
		_load_translations()

	if locale == "":
		locale = get_current_locale()

	var path_key: String = _resolve_item_path(item)
	if path_key != "" and _translations.has(path_key):
		var entry: Dictionary = _translations[path_key]
		var desc_dict: Dictionary = {}
		if entry.has("description") and typeof(entry["description"]) == TYPE_DICTIONARY:
			desc_dict = entry["description"]
		elif entry.has("desc") and typeof(entry["desc"]) == TYPE_DICTIONARY:
			desc_dict = entry["desc"]

		if not desc_dict.is_empty():
			var val: String = desc_dict.get(locale, "")
			if val != "":
				return val

	return item.description
