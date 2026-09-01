extends CanvasLayer

@export var inventory_scene: PackedScene
@export var equstore_scene: PackedScene
@export var antikaci_scene: PackedScene
@export var kara_borsa_scene: PackedScene
@export var collection_scene: PackedScene
@export_file("*.tscn") var main_menu_scene_path: String = "res://Scenes/main_menu.tscn"

@export_group("Oyuna Dönüş")
@export var teleport_player_on_close: bool = true
@export var ocean_spawn_x: float = 16.0          # Ofisten çıkınca oyuncunun x konumu (dalış noktası)
@export var spawn_above_surface_px: float = 450.0 # Oyuncu su yüzeyinin bu kadar yukarısına ışınlanır (suya düşerek başlar)
@export var spawn_fall_speed: float = 300.0      # Işınlanma sonrası başlangıç düşüş hızı

@onready var close_button: Button = $Background/CloseButton
@onready var antikaci_button: Button = $Background/ButtonGrid/AntikaciButton
@onready var kara_borsa_button: Button = $Background/ButtonGrid/KaraBorsaButton
@onready var koleksiyon_button: Button = $Background/ButtonGrid/KoleksiyonButton
@onready var envanter_button: Button = $Background/ButtonGrid/EnvanterButton
@onready var equstore_button: Button = $Background/ButtonGrid/EquipmentButton
@onready var main_menu_button: Button = $Background/ButtonGrid/MainMenuButton
@export var title_label_2: Label 
@export var texture_rect: TextureRect


func _ready() -> void:
	var dark_wood_bg = StyleBoxFlat.new()
	dark_wood_bg.bg_color = Color(0.15, 0.10, 0.06, 0.9) # Tok ve koyu kahverengi
	dark_wood_bg.set_corner_radius_all(8)
	dark_wood_bg.set_border_width_all(2)
	dark_wood_bg.border_color = Color(0.85, 0.75, 0.45, 1.0) # Krem / Eskitilmiş Altın çerçeve
	var info_bg = dark_wood_bg.duplicate()
	info_bg.content_margin_left = 12
	info_bg.content_margin_right = 12
	info_bg.content_margin_top = 4
	info_bg.content_margin_bottom = 4
	$zurna.add_theme_stylebox_override("normal", info_bg)
	$zurna.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
	GlobalEconomy.money_changed.connect(_on_money_changed)
	$zurna.text = str(GlobalEconomy.money) + " Zurna"
	# Bu menü ve altındaki her şey (butonlar dahil) pause'dan etkilenmesin
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Ofis açılınca oyun fiziği (batma, oksijen tüketimi, can) donsun.
	# player_controller.gd'de process_mode override edilmediği için CharacterBody2D
	# otomatik olarak pause'a girer, ekstra bir şey yapmamıza gerek yok.
	get_tree().paused = true

	close_button.pressed.connect(_on_close_pressed)
	antikaci_button.pressed.connect(_open_antikaci)
	kara_borsa_button.pressed.connect(_open_kara_borsa)
	koleksiyon_button.pressed.connect(_open_koleksiyon)
	envanter_button.pressed.connect(_open_envanter)
	equstore_button.pressed.connect(_open_equstore)
	main_menu_button.pressed.connect(_on_main_menu_pressed)


func _on_close_pressed() -> void:
	if teleport_player_on_close:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			# .set() kullanıyoruz çünkü player değişkeni generic Node tipinde;
			# bu şekilde CharacterBody2D olduğunu varsaymadan güvenle pozisyon/hız set edebiliyoruz.
			# Oyuncu, su yüzeyinin üstüne ışınlanıp suya düşerek oyuna döner (oyun başlangıcıyla aynı).
			var spawn_y = InfiniteMapManager.water_surface_y - spawn_above_surface_px
			player.set("global_position", Vector2(ocean_spawn_x, spawn_y))
			player.set("velocity", Vector2(0, spawn_fall_speed))
			player.set("current_oxygen", 100.0)
			player.set("current_health", 100.0)
	get_tree().paused = false
	queue_free()


func _exit_tree() -> void:
	# Güvenlik ağı: menü her nasılsa close butonundan geçmeden yok edilirse
	# (ör. sahne yeniden yüklenirse) oyun kalıcı olarak donmuş kalmasın.
	get_tree().paused = false


func _open_antikaci() -> void:
	_open_preconfigured(antikaci_scene)


func _open_kara_borsa() -> void:
	_open_preconfigured(kara_borsa_scene)


func _open_preconfigured(shop_scene: PackedScene) -> void:
	if not shop_scene:
		push_warning("OfficeMenu: Satıcı sahnesi atanmamış!")
		return
	get_tree().current_scene.add_child(shop_scene.instantiate())


func _open_koleksiyon() -> void:
	_open_preconfigured(collection_scene)


func _open_envanter() -> void:
	if not inventory_scene:
		push_warning("OfficeMenu: inventory_scene atanmamış!")
		return
	get_tree().current_scene.add_child(inventory_scene.instantiate())


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)
	GlobalSoundManager.play_sfx("door")

func _open_equstore() -> void:
	if not equstore_scene:
		push_warning("OfficeMenu: equstore_scene atanmamış!")
		return
	get_tree().current_scene.add_child(equstore_scene.instantiate())
func _on_money_changed(amount) -> void:
	$zurna.text = str(amount) + " Zurna"
