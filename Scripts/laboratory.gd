extends CanvasLayer

@export_file("*.json") var recipes_file_path: String = "res://Data/recipes.json"

@onready var close_button: Button = %CloseButton
@onready var recipe_list_container: VBoxContainer = %RecipeListContainer

# Detay Paneli
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_desc_label: Label = %ItemDescLabel
@onready var item_value_label: Label = %ItemValueLabel
@onready var ingredients_container: VBoxContainer = %IngredientsContainer
@onready var craft_cost_label: Label = %CraftCostLabel
@onready var craft_button: Button = %CraftButton

var _recipes: Array[Dictionary] = []
var _selected_recipe: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(queue_free)
	craft_button.pressed.connect(_on_craft_pressed)
	_setup_button_juice(close_button)
	_setup_button_juice(craft_button)

	GlobalInventory.inventory_updated.connect(_on_inventory_updated)
	GlobalEconomy.money_changed.connect(_on_money_changed)

	_load_recipes()
	_populate_recipe_list()
	if not _recipes.is_empty():
		_select_recipe(_recipes[0])


func _exit_tree() -> void:
	if GlobalInventory.inventory_updated.is_connected(_on_inventory_updated):
		GlobalInventory.inventory_updated.disconnect(_on_inventory_updated)
	if GlobalEconomy.money_changed.is_connected(_on_money_changed):
		GlobalEconomy.money_changed.disconnect(_on_money_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			queue_free()
			get_viewport().set_input_as_handled()


func _load_recipes() -> void:
	_recipes.clear()
	if not FileAccess.file_exists(recipes_file_path):
		push_warning("Laboratory: Tarif dosyası bulunamadı: " + recipes_file_path)
		return

	var file := FileAccess.open(recipes_file_path, FileAccess.READ)
	if not file:
		return

	var json_text := file.get_as_text()
	var json := JSON.new()
	if json.parse(json_text) == OK and json.data is Array:
		for item in json.data:
			if item is Dictionary:
				_recipes.append(item)


func _count_unlocked_items(name_query: String) -> int:
	var count: int = 0
	for item in GlobalInventory.collected_items:
		if not item:
			continue
		if bool(item.get("is_locked")):
			continue # Kilitli eşyalar craft'ta harcanamaz!
		if str(item.get("item_name")) == name_query:
			count += 1
	return count


func _can_craft(recipe: Dictionary) -> bool:
	var req_money: int = int(recipe.get("required_money", 0))
	if GlobalEconomy.money < req_money:
		return false

	var ingredients: Array = recipe.get("ingredients", [])
	for ing in ingredients:
		var item_name: String = str(ing.get("item_name", ""))
		var count: int = int(ing.get("count", 1))
		if _count_unlocked_items(item_name) < count:
			return false

	return true


func _populate_recipe_list() -> void:
	for child in recipe_list_container.get_children():
		child.queue_free()

	for recipe in _recipes:
		var btn := _create_recipe_button(recipe)
		recipe_list_container.add_child(btn)


func _create_recipe_button(recipe: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 60)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var can_craft: bool = _can_craft(recipe)

	# Buton Stili
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.14, 0.10, 0.06, 0.9)
	btn_style.set_border_width_all(2)
	btn_style.border_color = Color(0.95, 0.65, 0.25, 0.8) if can_craft else Color(0.4, 0.35, 0.3, 0.5)
	btn_style.set_corner_radius_all(8)
	btn_style.content_margin_left = 10
	btn_style.content_margin_right = 10
	btn.add_theme_stylebox_override("normal", btn_style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	btn.add_child(hbox)

	# İkon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tres_path: String = str(recipe.get("output_tres_path", ""))
	if ResourceLoader.exists(tres_path):
		var res = load(tres_path)
		if res and res.get("sprite"):
			icon_rect.texture = res.get("sprite")
	hbox.add_child(icon_rect)

	# Metinler VBox
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = str(recipe.get("name", "Tarif"))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0))
	vbox.add_child(name_lbl)

	# Malzeme özet durumu
	var status_lbl := Label.new()
	var ingredients: Array = recipe.get("ingredients", [])
	var status_text: String = ""
	for ing in ingredients:
		var iname: String = str(ing.get("item_name", ""))
		var req_count: int = int(ing.get("count", 1))
		var cur_count: int = _count_unlocked_items(iname)
		var mark: String = "✅" if cur_count >= req_count else "❌"
		status_text += "%s %d/%d %s " % [iname, cur_count, req_count, mark]
	status_lbl.text = status_text
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7, 1.0) if can_craft else Color(0.8, 0.5, 0.5, 1.0))
	vbox.add_child(status_lbl)

	_setup_button_juice(btn)
	btn.pressed.connect(func() -> void:
		_select_recipe(recipe)
	)

	return btn


func _select_recipe(recipe: Dictionary) -> void:
	_selected_recipe = recipe

	item_name_label.text = str(recipe.get("name", "Bilinmeyen Ürün"))
	item_desc_label.text = str(recipe.get("description", "Açıklama bulunmuyor."))

	# Çıktı Eşyası İkon ve Değer
	var tres_path: String = str(recipe.get("output_tres_path", ""))
	var item_value: int = 0
	if ResourceLoader.exists(tres_path):
		var res = load(tres_path)
		if res:
			item_icon.texture = res.get("sprite")
			var val = res.get("value")
			item_value = int(val) if val != null else 0

	item_value_label.text = "💰 Tahmini Satış Değeri: %d Zurna" % item_value

	# Malzemeler Listesi Doldurma
	for child in ingredients_container.get_children():
		child.queue_free()

	var can_craft: bool = true
	var ingredients: Array = recipe.get("ingredients", [])
	for ing in ingredients:
		var iname: String = str(ing.get("item_name", ""))
		var req_count: int = int(ing.get("count", 1))
		var cur_count: int = _count_unlocked_items(iname)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var ing_name := Label.new()
		ing_name.text = "• " + iname
		ing_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ing_name.add_theme_font_size_override("font_size", 14)
		ing_name.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
		row.add_child(ing_name)

		var ing_count := Label.new()
		var ok: bool = cur_count >= req_count
		if not ok:
			can_craft = false
		ing_count.text = "%d / %d %s" % [cur_count, req_count, "✅" if ok else "❌"]
		ing_count.add_theme_font_size_override("font_size", 13)
		ing_count.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1.0) if ok else Color(1.0, 0.35, 0.35, 1.0))
		row.add_child(ing_count)

		ingredients_container.add_child(row)

	# Masraf Kontrolü
	var req_money: int = int(recipe.get("required_money", 0))
	if req_money > 0:
		craft_cost_label.text = "Laboratuvar Masrafı: %d Zurna" % req_money
		if GlobalEconomy.money < req_money:
			can_craft = false
			craft_cost_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
		else:
			craft_cost_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3, 1.0))
	else:
		craft_cost_label.text = "Laboratuvar Masrafı: Ücretsiz"
		craft_cost_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1.0))

	# Çanta Kapasite Kontrolü (Net slot değişimi: üretilen 1 eşya - harcanacak malzemeler)
	var total_consumed: int = 0
	for ing in ingredients:
		total_consumed += int(ing.get("count", 1))
	var net_slot_change: int = 1 - total_consumed
	var projected_count: int = GlobalInventory.collected_items.size() + net_slot_change
	var has_space: bool = projected_count <= GlobalInventory.get_capacity()

	craft_button.disabled = not can_craft or not has_space
	if not can_craft:
		craft_button.text = "YETERSİZ MALZEME"
	elif not has_space:
		craft_button.text = "ÇANTA DOLU 🎒"
	else:
		craft_button.text = "SENTEZLE / ÜRET ✨"


func _on_craft_pressed() -> void:
	if _selected_recipe.is_empty():
		return

	if not _can_craft(_selected_recipe):
		GlobalSoundManager.play_sfx("error")
		return

	var ingredients: Array = _selected_recipe.get("ingredients", [])
	var total_consumed: int = 0
	for ing in ingredients:
		total_consumed += int(ing.get("count", 1))
	var net_slot_change: int = 1 - total_consumed
	if GlobalInventory.collected_items.size() + net_slot_change > GlobalInventory.get_capacity():
		GlobalSoundManager.play_sfx("error")
		return
	for ing in ingredients:
		var iname: String = str(ing.get("item_name", ""))
		var need_count: int = int(ing.get("count", 1))
		var deleted: int = 0
		var items_snapshot: Array = GlobalInventory.collected_items.duplicate()
		for item in items_snapshot:
			if deleted >= need_count:
				break
			if item and not bool(item.get("is_locked")) and str(item.get("item_name")) == iname:
				GlobalInventory.remove_item(item)
				deleted += 1

	# 2. Zurna masrafını tahsil et
	var req_money: int = int(_selected_recipe.get("required_money", 0))
	if req_money > 0:
		GlobalEconomy.spend_money(req_money)

	# 3. Üretilen eşyayı oluştur ve çantaya ekle
	var output_tres: String = str(_selected_recipe.get("output_tres_path", ""))
	var product: ItemData = null
	if ResourceLoader.exists(output_tres):
		var res = load(output_tres)
		if res is ItemData:
			product = res.duplicate() as ItemData
			product.resource_path = output_tres
	
	if not product:
		# Fallback dinamik üretim
		product = ItemData.new()
		product.item_name = str(_selected_recipe.get("name", "Üretilmiş Eşya"))
		product.description = str(_selected_recipe.get("description", ""))
		product.category = "Crafted"
		product.value = int(_selected_recipe.get("value", 80))
		product.resource_path = output_tres

	GlobalInventory.add_item(product)

	# 4. Efektler & SFX
	GlobalSoundManager.play_sfx("upgrade")
	_spawn_floating_craft_feedback(product.item_name)

	# 5. Ekranı yenile
	_populate_recipe_list()
	_select_recipe(_selected_recipe)


func _spawn_floating_craft_feedback(p_name: String) -> void:
	var float_label := Label.new()
	float_label.text = "✨ +1 %s Üretildi!" % p_name
	float_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1.0))
	float_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	float_label.add_theme_constant_override("shadow_outline_size", 3)
	float_label.add_theme_font_size_override("font_size", 16)

	var base_pos: Vector2 = craft_button.global_position + Vector2(20.0, -10.0)
	float_label.global_position = base_pos
	add_child(float_label)

	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(float_label, "global_position:y", base_pos.y - 35.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(float_label, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(float_label.queue_free)


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
	btn.pressed.connect(func() -> void:
		if is_instance_valid(btn):
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.05)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)


func _on_inventory_updated() -> void:
	_populate_recipe_list()
	if not _selected_recipe.is_empty():
		_select_recipe(_selected_recipe)


func _on_money_changed(_amount: int) -> void:
	if not _selected_recipe.is_empty():
		_select_recipe(_selected_recipe)
