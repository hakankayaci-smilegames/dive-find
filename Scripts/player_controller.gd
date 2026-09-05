extends CharacterBody2D
## Derin Deniz Dalgıcı - Player Controller

const GAME_OVER_SCENE := "res://Scenes/game_over.tscn"

# ------------------------------------------------------------------
# EXPORT DEĞİŞKENLERİ
# ------------------------------------------------------------------
@export var visual_scale: float = 0.5 # 1.0 orijinal boyuttur, 0.5 yarı yarıya küçültür

@export_group("Spawn")
@export var spawn_above_surface_px: float = 60.0 # Su yüzeyinin hemen azıcık üstünden başlar
@export var spawn_fall_speed: float = 450.0       # Hızlıca suya giriş

@export_group("Movement")
@export var max_speed: float = 220.0          
@export var acceleration: float = 600.0       
@export var friction: float = 500.0           

@export_group("Buoyancy & Surface")
@export var sink_speed: float = 15.0          
@export var max_sink_velocity: float = 40.0   
@export var surface_push_force: float = 500.0 # Yüzeyi geçip yukarı çıkmaya çalışınca uygulanan yaylanma/sekme kuvveti

@export_group("Depth & Oxygen")
@export var max_oxygen: float = 100.0
@export var pixels_per_meter: float = 50.0       # 50px = 1 metre (derinlik ölçeği)
@export var base_oxygen_drain_rate: float = 3.0  # derinlik 0'daki taban tüketim (oksijen/sn)
@export var depth_penalty_reference: float = 250.0 # Her 250m'de baskı katsayısı +1 artar (daha adil derinlik ölçeği)
@export var surface_oxygen_regen_rate: float = 25.0 # Yüzeyde oksijenin yavaşça dolma hızı (oksijen/sn)
@export var tube_efficiency_gain: float = 1.25    # Her tüp seviyesinde +1.25 verimlilik

@export_group("Health")
@export var max_health: float = 100.0
@export var oxygen_critical_percent: float = 0.15  # Bu yüzdenin altında yavaş boğulma başlar
@export var health_drain_low_oxygen: float = 2.0   # Yavaş boğulma (can/sn)
@export var health_drain_no_oxygen: float = 15.0   # Oksijen sıfırken agresif boğulma (can/sn)
@export var health_regen_rate: float = 12.0        # Yüzeyde, oksijen tam dolduktan sonra can/sn

var godmode_enabled: bool = false                   # Hile konsolu ile açılıp kapatılır
var mobile_move_vector: Vector2 = Vector2.ZERO         # Sanal joystick tarafından güncellenir

@export_group("Inventory")
@export var backpack_level: int = 0                    # Lvl0 = taban kapasite
@export var base_backpack_capacity: int = 5             # Lvl0'daki taban slot sayısı
@export var backpack_capacity_per_level: int = 5        # Her seviyede eklenen slot sayısı

@export_group("Equipment")
@export var tube_level: int = 1                  # Oksijen Tüpü Seviyesi
@export var fins_level: int = 0                  # Palet Seviyesi
@export var goggles_level: int = 0               # Dalış Gözlüğü Seviyesi
@export var fins_speed_per_level: float = 25.0   # Her seviyede max_speed ve accel'e eklenen bonus (px/s)
@export var goggles_zoom_min_per_level: float = 0.04   # Her seviyede camera_zoom_min bu kadar azalır

@export_group("UI Bars")
@export var health_bar: ProgressBar
@export var oxygen_bar: ProgressBar
@export var health_color_high: Color = Color(0.20, 0.80, 0.25)      # Yeşil (>60%)
@export var health_color_mid: Color = Color(0.95, 0.85, 0.15)       # Sarı (30-60%)
@export var health_color_low: Color = Color(0.95, 0.55, 0.10)       # Turuncu (15-30%)
@export var health_color_critical: Color = Color(0.85, 0.15, 0.15)  # Kırmızı (<15%)
@export var oxygen_color_full: Color = Color(0.35, 0.75, 1.00)      # Açık mavi (dolu)
@export var oxygen_color_low: Color = Color(0.05, 0.15, 0.45)       # Koyu lacivert (azalmış/kritik)
@export var oxygen_color_rising: Color = Color(0.55, 0.95, 1.00)    # Parlak camgöbeği (yenilenirken vurgu)

@export_group("Camera")
@export var enable_camera: bool = true        
@export var camera_zoom: float = 0.45          
@export var camera_zoom_min: float = 0.45     
@export var camera_zoom_max: float = 2.0      
@export var camera_zoom_step: float = 0.1     
@export var camera_smoothing_speed: float = 5.0       
@export var camera_limit_left: int = -10000000        
@export var camera_limit_right: int = 10000000
@export var camera_limit_top: int = -10000000
@export var camera_limit_bottom: int = 10000000

@export_group("Animation")
@export var swim_frames: Array[Texture2D] = [] 
@export var idle_anim_speed: float = 2.5
@export var max_anim_speed: float = 8.0
@export var base_anim_speed: float = 8.0 

# ------------------------------------------------------------------
# SİNYALLER & DURUM
# ------------------------------------------------------------------
signal oxygen_changed(current: float, maximum: float)
signal health_changed(current: float, maximum: float)

var current_oxygen: float = 100.0
var current_health: float = 100.0
var _camera: Camera2D = null  

var _game_over_triggered: bool = false

var _health_fill_style: StyleBoxFlat
var _oxygen_fill_style: StyleBoxFlat
var _previous_oxygen: float = 100.0

var _anim_timer: float = 0.0
var _current_frame: int = 0
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	GlobalInventory.apply_save_to_player(self)
	if has_node("Sprite2D"):
		$Sprite2D.scale = Vector2(visual_scale, visual_scale)
	current_oxygen = max_oxygen
	current_health = max_health
	_previous_oxygen = current_oxygen

	# Oyuna başlarken oyuncu su yüzeyinin üstünden başlar ve suya düşer.
	# (MapMaker hazır olduğu için water_surface_y bu noktada hesaplanmıştır.)
	if spawn_above_surface_px > 0.0 and InfiniteMapManager.water_surface_y > 0.0:
		global_position.y = InfiniteMapManager.water_surface_y - spawn_above_surface_px
		velocity.y = spawn_fall_speed

	_setup_bars()
	_broadcast_oxygen()
	_broadcast_health()

	if enable_camera:
		_setup_camera()


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_surface_and_oxygen(delta)
	_update_animation(delta)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_camera or _camera == null:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_camera_zoom(camera_zoom + camera_zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_camera_zoom(camera_zoom - camera_zoom_step)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			_set_camera_zoom(camera_zoom + camera_zoom_step)
		elif event.keycode == KEY_O:
			_set_camera_zoom(camera_zoom - camera_zoom_step)


# ------------------------------------------------------------------
# YÜZME FİZİĞİ
# ------------------------------------------------------------------

func _handle_movement(delta: float) -> void:
	var input_direction: Vector2 = Vector2.ZERO

	if mobile_move_vector.length_squared() > 0.001:
		input_direction = mobile_move_vector
	else:
		var input_x: float = Input.get_axis("ui_left", "ui_right")
		var input_y: float = Input.get_axis("ui_up", "ui_down")

		if Input.is_key_pressed(KEY_A):
			input_x -= 1.0
		if Input.is_key_pressed(KEY_D):
			input_x += 1.0
		if Input.is_key_pressed(KEY_W):
			input_y -= 1.0
		if Input.is_key_pressed(KEY_S):
			input_y += 1.0

		input_x = clamp(input_x, -1.0, 1.0)
		input_y = clamp(input_y, -1.0, 1.0)
		input_direction = Vector2(input_x, input_y)

	if input_direction.length() > 0.0:
		input_direction = input_direction.normalized()
		var target_velocity: Vector2 = input_direction * get_effective_max_speed()
		velocity = velocity.move_toward(target_velocity, get_effective_max_accel() * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		velocity.y = min(velocity.y + sink_speed * delta, max_sink_velocity)


# ------------------------------------------------------------------
# ANİMASYON SİSTEMİ
# ------------------------------------------------------------------
func _update_animation(delta: float) -> void:
	if swim_frames.is_empty() or not is_instance_valid(sprite):
		return

	# Sağa/Sola dönme (Mirror) - Yalnızca yatay hız varsa yön değiştirir
	if velocity.x < -10.0:
		sprite.flip_h = true
	elif velocity.x > 10.0:
		sprite.flip_h = false

	var current_speed: float = velocity.length()
	var effective_max: float = maxf(get_effective_max_speed(), 1.0)
	var speed_ratio: float = clampf(current_speed / effective_max, 0.0, 1.0)

	# Dururken yavaşça süzülür (idle), hızlandıkça abartmadan max hızına yumuşakça yaklaşır
	var anim_speed: float = lerpf(idle_anim_speed, max_anim_speed, speed_ratio)
	_anim_timer += delta * anim_speed

	while _anim_timer >= 1.0:
		_anim_timer -= 1.0
		_current_frame = (_current_frame + 1) % swim_frames.size()
		sprite.texture = swim_frames[_current_frame]


# ------------------------------------------------------------------
# YÜZEY HİZASI (LVL0 SONU / LVL1 BAŞI) SEKME, NEFES ALMA VE DERİNLİK BAZLI OKSİJEN
# ------------------------------------------------------------------
func _handle_surface_and_oxygen(delta: float) -> void:
	if godmode_enabled:
		current_oxygen = max_oxygen
		current_health = max_health
		_broadcast_oxygen()
		_broadcast_health()
		return

	var surface_y = InfiniteMapManager.water_surface_y

	# Su yüzeyi eşiği (surface_y ile bu değer arasındaki dar bant yüzey bandıdır)
	var surface_band = 40.0 

	# Eğer oyuncu yüzey hizasındaysa veya üstündeyse (lvl0 bölgesindeyse)
	if global_position.y <= surface_y + surface_band:
		# Nefes al / Oksijeni yavaşça doldur (yüzeyde kaldıkça)
		current_oxygen = min(current_oxygen + surface_oxygen_regen_rate * delta, max_oxygen)
		_broadcast_oxygen()

		# Eğer oyuncu su yüzeyi çizgisini (`surface_y`) geçip yukarı (lvl0 / gökyüzüne) çıkmaya çalışırca,
		# ne kadar yukarı zorlarsa o kadar sert ama yumuşak bir yay gibi aşağı (suya) iter.
		# Hız, max_sink_velocity'in 2 katı ile sınırlanır; böylece yüksekten (spawn) düşüş
		# ani bir çarpma değil kontrollü bir suya giriş olur.
		if global_position.y < surface_y:
			var penetration = surface_y - global_position.y
			var push = surface_push_force * delta * (1.0 + penetration * 0.1)
			velocity.y = min(velocity.y + push, max_sink_velocity * 2.0)
	else:
		# Sualtındayken (lvl1 ve altındayken) derinliğe bağlı oksijen tüketimi
		var depth_m: float = _get_depth_meters(surface_y)
		var depth_penalty: float = _calculate_depth_penalty(depth_m)
		var tube_efficiency: float = _get_tube_efficiency()
		var drain_rate: float = base_oxygen_drain_rate * (depth_penalty / tube_efficiency)

		current_oxygen -= drain_rate * delta
		current_oxygen = max(current_oxygen, 0.0)
		_broadcast_oxygen()

	# Can, hem yüzeyde (regen) hem sualtında (drain) her frame güncellenmeli
	_update_health(delta)


# ------------------------------------------------------------------
# DERİNLİK / OKSİJEN / CAN HESAPLAMALARI
# ------------------------------------------------------------------

func _get_depth_meters(surface_y: float = -1.0) -> float:
	if surface_y < 0.0:
		surface_y = InfiniteMapManager.water_surface_y
	return max((global_position.y - surface_y) / pixels_per_meter, 0.0)


func _calculate_depth_penalty(depth_m: float) -> float:
	# Lineer ceza eğrisi: her `depth_penalty_reference` metrede baskı katsayısı ~1 artar
	return 1.0 + (depth_m / depth_penalty_reference)


func _get_tube_efficiency() -> float:
	return 1.0 + float(tube_level - 1) * tube_efficiency_gain


func _update_health(delta: float) -> void:
	var oxygen_percent: float = current_oxygen / max_oxygen

	if current_oxygen <= 0.0:
		# Oksijen sıfır: agresif boğulma
		current_health -= health_drain_no_oxygen * delta
	elif oxygen_percent < oxygen_critical_percent:
		# Kritik eşik altı: yavaş boğulma başlangıcı
		current_health -= health_drain_low_oxygen * delta
	elif oxygen_percent >= 1.0:
		# Can sadece oksijen tam dolduktan sonra kademeli yenilenir (anlık dolum yok)
		current_health += health_regen_rate * delta

	current_health = clamp(current_health, 0.0, max_health)
	_broadcast_health()

	if current_health <= 0.0:
		_trigger_game_over()
	else:
		_game_over_triggered = false


func _trigger_game_over() -> void:
	if _game_over_triggered:
		return
	_game_over_triggered = true

	# Oyuncu boğuldu: oyun bitti mesaj kutusunu aç. Mesaj kutusu envanteri siler,
	# oyunu duraklatır ve TAMAM'a basınca oyuncuyu ofis menüsüne gönderir.
	var scene: PackedScene = load(GAME_OVER_SCENE)
	if scene:
		get_tree().current_scene.add_child(scene.instantiate())


# ------------------------------------------------------------------
# UI BAR SİSTEMİ (Progress Bar renk/değer güncellemesi)
# ------------------------------------------------------------------

func _setup_bars() -> void:
	if health_bar:
		health_bar.min_value = 0.0
		health_bar.max_value = max_health
		health_bar.value = current_health
		_health_fill_style = _get_or_create_fill_style(health_bar)

	if oxygen_bar:
		oxygen_bar.min_value = 0.0
		oxygen_bar.max_value = max_oxygen
		oxygen_bar.value = current_oxygen
		_oxygen_fill_style = _get_or_create_fill_style(oxygen_bar)


func _get_or_create_fill_style(bar: ProgressBar) -> StyleBoxFlat:
	# Var olan tema stilini (varsa köşe yuvarlaklığı/border gibi ayarları) koruyarak
	# üzerine bg_color'ı dinamik değiştirebileceğimiz bir kopya oluşturuyoruz
	var existing := bar.get_theme_stylebox("fill")
	var style: StyleBoxFlat
	if existing is StyleBoxFlat:
		style = existing.duplicate()
	else:
		style = StyleBoxFlat.new()
	bar.add_theme_stylebox_override("fill", style)
	return style


func _broadcast_oxygen() -> void:
	emit_signal("oxygen_changed", current_oxygen, max_oxygen)
	_refresh_oxygen_bar()


func _broadcast_health() -> void:
	emit_signal("health_changed", current_health, max_health)
	_refresh_health_bar()


func _refresh_oxygen_bar() -> void:
	if oxygen_bar == null or _oxygen_fill_style == null:
		_previous_oxygen = current_oxygen
		return

	oxygen_bar.value = current_oxygen

	var percent: float = current_oxygen / max_oxygen
	var color: Color = oxygen_color_low.lerp(oxygen_color_full, percent)

	# Oksijen artıyorsa (yenileniyorsa) parlak camgöbeği tonuna doğru vurgu ekle
	if current_oxygen - _previous_oxygen > 0.01:
		color = color.lerp(oxygen_color_rising, 0.5)

	_oxygen_fill_style.bg_color = color
	_previous_oxygen = current_oxygen


func _refresh_health_bar() -> void:
	if health_bar == null or _health_fill_style == null:
		return

	health_bar.value = current_health

	var percent: float = current_health / max_health
	var color: Color

	if percent > 0.6:
		# Yeşil <-> Sarı arası (%60 - %100)
		var t: float = (percent - 0.6) / 0.4
		color = health_color_mid.lerp(health_color_high, t)
	elif percent > 0.3:
		# Sarı <-> Turuncu arası (%30 - %60)
		var t: float = (percent - 0.3) / 0.3
		color = health_color_low.lerp(health_color_mid, t)
	else:
		# Turuncu <-> Kırmızı arası (%0 - %30)
		var t: float = percent / 0.3
		color = health_color_critical.lerp(health_color_low, t)

	_health_fill_style.bg_color = color


# ------------------------------------------------------------------
# ÇANTA (INVENTORY) KAPASİTESİ
# ------------------------------------------------------------------

func get_backpack_capacity() -> int:
	return base_backpack_capacity + backpack_level * backpack_capacity_per_level


# ------------------------------------------------------------------
# EKİPMAN BONUSLARI (Palet & Dalış Gözlüğü)
# ------------------------------------------------------------------

func get_effective_max_speed() -> float:
	return max_speed + float(fins_level) * fins_speed_per_level
	

func get_effective_max_accel() -> float:
	return acceleration + float(fins_level) * fins_speed_per_level


func get_effective_zoom_min() -> float:
	return max(camera_zoom_min - float(goggles_level) * goggles_zoom_min_per_level, 0.01)


# ------------------------------------------------------------------
# KAMERA SİSTEMİ
# ------------------------------------------------------------------

func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "PlayerCamera"
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = camera_smoothing_speed
	_camera.limit_left = camera_limit_left
	_camera.limit_right = camera_limit_right
	_camera.limit_top = camera_limit_top
	_camera.limit_bottom = camera_limit_bottom
	add_child(_camera)
	_camera.make_current()


func _set_camera_zoom(new_zoom: float) -> void:
	camera_zoom = clamp(new_zoom, get_effective_zoom_min(), camera_zoom_max)
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
