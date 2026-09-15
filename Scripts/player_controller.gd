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

@export_group("Sprint")
@export var sprint_speed_bonus: float = 110.0         # Shift basılıyken eklenen sabit hız bonusu (px/s - bufflandı)
@export var sprint_accel_multiplier: float = 1.45     # Shift basılıyken ivmelenme çarpanı
@export var sprint_oxygen_multiplier: float = 2.6     # Shift basılıyken oksijen tüketim çarpanı (daha agresif tükenme)
var is_sprinting: bool = false

@export_group("Buoyancy & Surface")
@export var sink_speed: float = 15.0          
@export var max_sink_velocity: float = 40.0   
@export var surface_push_force: float = 500.0 # Yüzeyi geçip yukarı çıkmaya çalışınca uygulanan yaylanma/sekme kuvveti

@export_group("Depth & Oxygen")
@export var max_oxygen: float = 100.0
@export var pixels_per_meter: float = 50.0       # 50px = 1 metre (derinlik ölçeği)
@export var base_oxygen_drain_rate: float = 1.8  # derinlik 0'daki taban tüketim (oksijen/sn - bufflandı)
@export var depth_penalty_reference: float = 250.0 # Her 250m'de baskı katsayısı +1 artar (daha adil derinlik ölçeği)
@export var surface_oxygen_regen_rate: float = 30.0 # Yüzeyde oksijenin dolma hızı (oksijen/sn)
@export var tube_efficiency_gain: float = 1.25    # Her tüp seviyesinde +1.25 verimlilik

@export_group("Health")
@export var max_health: float = 100.0
@export var oxygen_critical_percent: float = 0.15  # Bu yüzdenin altında yavaş boğulma başlar
@export var health_drain_low_oxygen: float = 2.0   # Yavaş boğulma (can/sn)
@export var health_drain_no_oxygen: float = 15.0   # Oksijen sıfırken agresif boğulma (can/sn)
@export var health_regen_rate: float = 12.0        # Yüzeyde, oksijen tam dolduktan sonra can/sn

var godmode_enabled: bool = false                   # Hile konsolu ile açılıp kapatılır
var mobile_move_vector: Vector2 = Vector2.ZERO         # Sanal joystick tarafından güncellenir
var mobile_sprint_active: bool = false               # Mobil depar toggle butonu tarafından güncellenir
var mobile_aim_angle: float = 0.0                    # Mobil fener hedef açısı (radyan)
var has_mobile_aim: bool = false                     # Mobilde aktif fener hedefi var mı

@export_group("Inventory")
@export var backpack_level: int = 0                    # Lvl0 = taban kapasite
@export var base_backpack_capacity: int = 5             # Lvl0'daki taban slot sayısı
@export var backpack_capacity_per_level: int = 5        # Her seviyede eklenen slot sayısı

@export_group("Equipment")
@export var tube_level: int = 1                  # Oksijen Tüpü Seviyesi
@export var fins_level: int = 0                  # Palet Seviyesi
@export var goggles_level: int = 0               # Dalış Gözlüğü Seviyesi
@export var flashlight_level: int = 0:           # Dalış Feneri Seviyesi (0: Yok, 1-15: Seviye)
	set(val):
		var prev_lvl: int = flashlight_level
		flashlight_level = val
		_update_flashlight_specs()
		if prev_lvl == 0 and val > 0:
			current_battery = max_battery
			_broadcast_battery()
		GlobalInventory.equipment_updated.emit("flashlight_level", val)
		GlobalInventory.inventory_updated.emit()
@export var fins_speed_per_level: float = 55.0   # Her seviyede max_speed ve accel'e eklenen bonus (px/s)
@export var goggles_zoom_min_per_level: float = 0.04   # Her seviyede camera_zoom_min bu kadar azalır

@export_group("Flashlight & Battery")
@export var is_flashlight_on: bool = false:
	set(val):
		is_flashlight_on = val
		_update_flashlight_visual()
		flashlight_toggled.emit(is_flashlight_on)

var flashlight_on: bool:
	get:
		return is_flashlight_on
	set(val):
		self.is_flashlight_on = val

@export var base_battery_capacity: float = 75.0        # Lvl 1 taban batarya (sn)
@export var battery_per_level: float = 8.93            # Seviye başına eklenen batarya (sn) - Lvl 15'te 200sn (3dk 20sn)
@export var surface_battery_regen_rate: float = 30.0   # Yüzeyde şarj hızı (sn/sn)
@export var battery_bar: ProgressBar
@export var battery_color_full: Color = Color(1.0, 0.85, 0.20)     # Parlak kehribar sarısı (>50%)
@export var battery_color_mid: Color = Color(0.95, 0.60, 0.15)      # Sıcak turuncu (20%-50%)
@export var battery_color_low: Color = Color(0.90, 0.20, 0.15)      # Kritik kırmızı (<20%)

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
signal battery_changed(current: float, maximum: float)
signal flashlight_toggled(is_on: bool)

var current_oxygen: float = 100.0
var current_health: float = 100.0
var current_battery: float = 60.0
var max_battery: float = 60.0
var _camera: Camera2D = null  

var _game_over_triggered: bool = false

var _health_fill_style: StyleBoxFlat
var _oxygen_fill_style: StyleBoxFlat
var _battery_fill_style: StyleBoxFlat
var _previous_oxygen: float = 100.0

var _flashlight_light: PointLight2D = null
var _cached_flashlight_texture: Texture2D = null
var _cached_flashlight_tex_level: int = -999
var _cone_texture_cache: Dictionary = {}

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

	_setup_flashlight()
	_setup_bars()
	_broadcast_oxygen()
	_broadcast_health()
	_broadcast_battery()
	GlobalInventory.inventory_updated.emit()

	if enable_camera:
		_setup_camera()


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_surface_and_oxygen(delta)
	_handle_battery_and_flashlight(delta)
	_update_animation(delta)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			toggle_flashlight()
			get_viewport().set_input_as_handled()
			return

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

	var has_input_x: bool = absf(input_direction.x) > 0.05
	var has_input_y: bool = absf(input_direction.y) > 0.05
	var has_any_input: bool = has_input_x or has_input_y

	var wants_sprint: bool = Input.is_key_pressed(KEY_SHIFT) or mobile_sprint_active
	is_sprinting = wants_sprint and has_any_input and (current_oxygen > 0.0 or godmode_enabled)

	var effective_max_speed: float = get_effective_max_speed()
	var base_accel: float = get_effective_max_accel()

	# Normalizasyon: Çapraz yüzüşte toplam hız vektörünün max_speed'i aşmaması için
	var move_dir: Vector2 = input_direction.normalized() if has_any_input else Vector2.ZERO

	# ------------------------------------------------------------------
	# 1. YATAY EKSEN (X) HAREKET VE SÜZÜLME
	# ------------------------------------------------------------------
	if has_input_x:
		var target_vx: float = move_dir.x * effective_max_speed
		velocity.x = move_toward(velocity.x, target_vx, base_accel * delta)
	else:
		# Yatayda akışkan su süzülmesi
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# ------------------------------------------------------------------
	# 2. DİKEY EKSEN (Y) HAREKET VE AKIŞKAN BATMA / SÜZÜLME (REWORK)
	# ------------------------------------------------------------------
	if has_input_y:
		var target_vy: float = move_dir.y * effective_max_speed
		# Seçenek B: Aşağı dalış yerçekimiyle hafif daha akıcı, yukarı yüzüş su kütlesine karşı daha tok
		var accel_y: float = base_accel * (1.06 if target_vy > 0.0 else 0.92)
		velocity.y = move_toward(velocity.y, target_vy, accel_y * delta)
	else:
		if has_input_x:
			# Oyuncu sadece yatay yüzüyorsa, dikey momentum su sürtünmesiyle yumuşak bir kavis çizerek yataya oturur
			velocity.y = move_toward(velocity.y, 0.0, friction * delta)
		else:
			# Boşta süzülme ve doğal batma:
			if velocity.y > max_sink_velocity:
				# Aşağı dalış sonrası tuş bırakıldı: Hız 40'a çakılmaz, kademeli süzülür!
				velocity.y = move_toward(velocity.y, max_sink_velocity, friction * delta)
			elif velocity.y < 0.0:
				# Yukarı yüzüş sonrası tuş bırakıldı: Su direnciyle yumuşakça sönümlenir
				velocity.y = move_toward(velocity.y, 0.0, (friction + sink_speed * 3.0) * delta)
			else:
				# 0 ile max_sink_velocity arasında doğal batma hızına oturma
				velocity.y = move_toward(velocity.y, max_sink_velocity, sink_speed * delta)


# ------------------------------------------------------------------
# ANİMASYON SİSTEMİ & DİNAMİK YÜZÜŞ EĞİMİ
# ------------------------------------------------------------------
func _update_animation(delta: float) -> void:
	if swim_frames.is_empty() or not is_instance_valid(sprite):
		return

	# Sağa/Sola dönme (Mirror) - Yalnızca yatay hız varsa yön değiştirir
	var prev_flip: bool = sprite.flip_h
	if velocity.x < -10.0:
		sprite.flip_h = true
	elif velocity.x > 10.0:
		sprite.flip_h = false

	var current_speed: float = velocity.length()
	var effective_max: float = maxf(get_effective_max_speed(), 1.0)
	var speed_ratio: float = clampf(current_speed / effective_max, 0.0, 1.0)

	# Dinamik Yüzüş Eğimi (Pitch / Tilt):
	# Dikey hıza göre dalgıcın burnu hareket yönüne doğru doğal bir açıyla (±12°) yatar.
	var pitch_max_deg: float = 12.0
	var vert_ratio: float = clampf(velocity.y / effective_max, -1.0, 1.0)
	var base_tilt: float = deg_to_rad(pitch_max_deg) * vert_ratio
	var target_rotation: float = -base_tilt if sprite.flip_h else base_tilt
	sprite.rotation = lerp_angle(sprite.rotation, target_rotation, 8.0 * delta)

	# Dururken yavaşça süzülür (idle), hızlandıkça abartmadan max hızına yumuşakça yaklaşır (sprintte daha dinamik)
	var target_max_anim: float = max_anim_speed * (1.25 if is_sprinting else 1.0)
	var anim_speed: float = lerpf(idle_anim_speed, target_max_anim, speed_ratio)
	_anim_timer += delta * anim_speed

	var frame_changed: bool = false
	while _anim_timer >= 1.0:
		_anim_timer -= 1.0
		_current_frame = (_current_frame + 1) % swim_frames.size()
		sprite.texture = swim_frames[_current_frame]

	sprite.offset = Vector2.ZERO


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

		if is_sprinting:
			drain_rate *= sprint_oxygen_multiplier

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

	if battery_bar:
		battery_bar.min_value = 0.0
		battery_bar.max_value = max_battery
		battery_bar.value = current_battery
		_battery_fill_style = _get_or_create_fill_style(battery_bar)


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


func _broadcast_battery() -> void:
	emit_signal("battery_changed", current_battery, max_battery)
	_refresh_battery_bar()


func _refresh_battery_bar() -> void:
	if battery_bar == null or _battery_fill_style == null:
		return

	battery_bar.max_value = max_battery
	battery_bar.value = current_battery

	var percent: float = current_battery / max(max_battery, 0.01) if max_battery > 0.0 else 0.0
	var color: Color
	if percent > 0.5:
		var t: float = (percent - 0.5) / 0.5
		color = battery_color_mid.lerp(battery_color_full, t)
	elif percent > 0.2:
		var t: float = (percent - 0.2) / 0.3
		color = battery_color_low.lerp(battery_color_mid, t)
	else:
		color = battery_color_low

	_battery_fill_style.bg_color = color


# ------------------------------------------------------------------
# DALIŞ FENERİ (FLASHLIGHT & BATARYA SİSTEMİ)
# ------------------------------------------------------------------

func _setup_flashlight() -> void:
	_flashlight_light = get_node_or_null("Flashlight") as PointLight2D
	if not _flashlight_light:
		_flashlight_light = PointLight2D.new()
		_flashlight_light.name = "Flashlight"
		_flashlight_light.blend_mode = PointLight2D.BLEND_MODE_ADD
		add_child(_flashlight_light)

	_flashlight_light.range_layer_min = 0
	_flashlight_light.range_layer_max = 0

	if not _cone_texture_cache.has(flashlight_level):
		var angle_deg: float = get_flashlight_cone_angle_deg()
		_cone_texture_cache[flashlight_level] = _generate_cone_texture(angle_deg)
	_cached_flashlight_texture = _cone_texture_cache[flashlight_level]
	_cached_flashlight_tex_level = flashlight_level
	_flashlight_light.texture = _cached_flashlight_texture
	_flashlight_light.offset = Vector2.ZERO
	_flashlight_light.color = Color(0.92, 0.95, 1.0, 1.0)

	_update_flashlight_specs()
	current_battery = max_battery
	_update_flashlight_visual()


func get_flashlight_max_battery() -> float:
	if flashlight_level <= 0:
		return base_battery_capacity
	return base_battery_capacity + float(flashlight_level - 1) * battery_per_level


func get_flashlight_cone_angle_deg() -> float:
	if flashlight_level <= 0:
		return 95.0
	# Lvl 1: 95°, Lvl 15: 155° (Geniş açı projektör; yanları ve önü ferahça aydınlatır)
	return 95.0 + float(flashlight_level - 1) * 4.286


func get_flashlight_range() -> float:
	if flashlight_level <= 0:
		return 1050.0
	# Lvl 1: 1050px, Lvl 15: 2600px (Gözlükle en geniş zoom out yapıldığında dahi ekranı aşan derin menzil)
	return 1050.0 + float(flashlight_level - 1) * 110.71


func _update_flashlight_specs() -> void:
	max_battery = get_flashlight_max_battery()
	if current_battery > max_battery:
		current_battery = max_battery

	if not is_instance_valid(_flashlight_light):
		_flashlight_light = get_node_or_null("Flashlight") as PointLight2D
		if not _flashlight_light:
			return

	var target_range: float = get_flashlight_range()
	# Doku yarıçapı 125px olduğundan scale faktörü (256x256 doku)
	_flashlight_light.texture_scale = target_range / 125.0
	_flashlight_light.color = Color(0.92, 0.95, 1.0, 1.0) # Göz yormayan berrak sualtı ışığı

	if flashlight_level <= 0:
		is_flashlight_on = false
		_update_flashlight_visual()
		_broadcast_battery()
		return

	if _cached_flashlight_tex_level != flashlight_level or _cached_flashlight_texture == null:
		if not _cone_texture_cache.has(flashlight_level):
			var angle_deg: float = get_flashlight_cone_angle_deg()
			_cone_texture_cache[flashlight_level] = _generate_cone_texture(angle_deg)
		_cached_flashlight_texture = _cone_texture_cache[flashlight_level]
		_cached_flashlight_tex_level = flashlight_level
		_flashlight_light.texture = _cached_flashlight_texture
		_flashlight_light.offset = Vector2.ZERO # Dalgıç merkezine kilitli, asla sapmaz

	_update_flashlight_visual()
	_broadcast_battery()


func _update_flashlight_visual() -> void:
	if is_instance_valid(_flashlight_light):
		var active: bool = (flashlight_level > 0) and is_flashlight_on and (current_battery > 0.0)
		_flashlight_light.visible = active
		_flashlight_light.energy = 0.95 if active else 0.0


func toggle_flashlight() -> void:
	if flashlight_level <= 0:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_warning_toast"):
			hud.show_warning_toast("🔦 Fenerin yok! Ofis mağazasından satın alabilirsin.")
		return

	if not is_flashlight_on and current_battery <= 0.0:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_warning_toast"):
			hud.show_warning_toast("⚡ Fener bataryası tükendi! Yüzeyde şarj et.")
		return

	GlobalSoundManager.play_sfx("click")
	self.is_flashlight_on = not is_flashlight_on


func turn_off_flashlight() -> void:
	if is_flashlight_on:
		self.is_flashlight_on = false


func reset_flashlight_for_office() -> void:
	if is_flashlight_on:
		self.is_flashlight_on = false
	_update_flashlight_visual()
	_broadcast_battery()


func _generate_cone_texture(angle_deg: float, size: int = 256) -> Texture2D:
	var byte_data := PackedByteArray()
	byte_data.resize(size * size * 4) # RGBA8: 4 byte / piksel, başlangıçta 0 (şeffaf)
	var center: float = float(size) * 0.5 # 128.0
	var max_reach: float = center - 3.0   # 125.0
	var max_reach_sq: float = max_reach * max_reach
	var half_angle_rad: float = deg_to_rad(angle_deg * 0.5)
	var halo_radius: float = 32.5
	var min_x: int = int(center - halo_radius) # 95

	# İçte dengesiz parlak elips olmasını engelleyen homojen aydınlatma sınırları:
	var inner_dist_ratio: float = 0.72   # Mesafenin ilk %72'sinde ışık %100 düz ve eşittir
	var inner_angle_ratio: float = 0.70  # Açının ilk %70'inde ışık %100 düz ve eşittir

	for y in range(size):
		var dy: float = float(y) - center
		if absf(dy) > max_reach:
			continue
		var row_offset: int = y * size * 4
		for x in range(min_x, size):
			var dx: float = float(x) - center
			var dist_sq: float = dx * dx + dy * dy
			if dist_sq > max_reach_sq:
				continue
			var dist: float = sqrt(dist_sq)

			var beam: float = 0.0
			if dx >= -4.0:
				var angle: float = absf(atan2(dy, maxf(dx, 0.0001)))
				if angle <= half_angle_rad:
					# Mesafe sönümü (Düz plato + yumuşak uç geçişi)
					var dist_t: float = dist / max_reach
					var radial_fade: float = 1.0
					if dist_t > inner_dist_ratio:
						radial_fade = smoothstep(1.0, inner_dist_ratio, dist_t)

					# Açısal sönüm (Düz plato + yumuşak yan geçişi)
					var angle_t: float = angle / half_angle_rad
					var angular_fade: float = 1.0
					if angle_t > inner_angle_ratio:
						angular_fade = smoothstep(1.0, inner_angle_ratio, angle_t)

					beam = radial_fade * angular_fade

			# Dalgıç gövdesi etrafındaki yumuşak aura
			var halo: float = 0.0
			if dist <= halo_radius:
				halo = smoothstep(halo_radius, 12.5, dist) * 0.85

			# maxf ile harmanlama ve yumuşak tepe yoğunluğu (göz almayan, görmeyi kolaylaştıran temiz ışık)
			var intensity: float = clampf(maxf(beam, halo) * 0.85, 0.0, 0.85)
			if intensity > 0.002:
				var b: int = int(intensity * 255.0)
				var p_idx: int = row_offset + (x * 4)
				byte_data[p_idx] = b
				byte_data[p_idx + 1] = b
				byte_data[p_idx + 2] = b
				byte_data[p_idx + 3] = b

	var img := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, byte_data)
	return ImageTexture.create_from_image(img)


func _handle_battery_and_flashlight(delta: float) -> void:
	# Fener yönü: Mobilde mobil hedef açısı, PC'de mouse cursor konumu
	if is_instance_valid(_flashlight_light) and _flashlight_light.visible:
		var is_ui_blocking: bool = get_tree().paused \
			or get_tree().get_first_node_in_group("popup_ui") != null \
			or get_tree().get_first_node_in_group("office_menu") != null \
			or get_tree().get_first_node_in_group("hub_menu") != null \
			or get_tree().get_first_node_in_group("city_map") != null
		if not is_ui_blocking:
			var target_angle: float
			if OS.has_feature("mobile") and has_mobile_aim:
				target_angle = mobile_aim_angle
			else:
				var mouse_pos: Vector2 = get_global_mouse_position()
				target_angle = (mouse_pos - global_position).angle()
			_flashlight_light.rotation = lerp_angle(_flashlight_light.rotation, target_angle, 14.0 * delta)

	if godmode_enabled:
		current_battery = max_battery
		_broadcast_battery()
		return

	if flashlight_level <= 0:
		if is_flashlight_on:
			is_flashlight_on = false
			_update_flashlight_visual()
		current_battery = 0.0
		_refresh_battery_bar()
		return

	if is_flashlight_on:
		current_battery = max(0.0, current_battery - 1.0 * delta)
		_broadcast_battery()
		if current_battery <= 0.0:
			is_flashlight_on = false
			_update_flashlight_visual()
			GlobalSoundManager.play_sfx("click")
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_warning_toast"):
				hud.show_warning_toast("⚡ Fener bataryası tükendi!")


# ------------------------------------------------------------------
# ÇANTA (INVENTORY) KAPASİTESİ
# ------------------------------------------------------------------

func get_backpack_capacity() -> int:
	return base_backpack_capacity + backpack_level * backpack_capacity_per_level


# ------------------------------------------------------------------
# EKİPMAN BONUSLARI (Palet & Dalış Gözlüğü)
# ------------------------------------------------------------------

func get_base_max_speed() -> float:
	return max_speed + float(fins_level) * fins_speed_per_level


func get_effective_max_speed() -> float:
	var spd: float = get_base_max_speed()
	if is_sprinting:
		spd += sprint_speed_bonus
	return spd


func get_effective_max_accel() -> float:
	var acc: float = acceleration + float(fins_level) * (fins_speed_per_level * 2.5)
	if is_sprinting:
		acc *= sprint_accel_multiplier
	return acc


func get_effective_zoom_min() -> float:
	return max(camera_zoom_min - float(goggles_level) * goggles_zoom_min_per_level, 0.01)


func get_surface_return_info() -> Dictionary:
	var surface_y: float = InfiniteMapManager.water_surface_y
	var dist_pixels: float = max(0.0, global_position.y - surface_y)
	var depth_m: float = dist_pixels / pixels_per_meter
	var base_swim_speed: float = max(get_base_max_speed(), 1.0)
	var time_to_surface: float = dist_pixels / base_swim_speed

	var tube_eff: float = _get_tube_efficiency()
	var current_drain: float = base_oxygen_drain_rate * (_calculate_depth_penalty(depth_m) / tube_eff)
	var surface_drain: float = base_oxygen_drain_rate * (1.0 / tube_eff)
	var avg_drain: float = (current_drain + surface_drain) * 0.5

	# Sprint durumunda anlık tüketim hızı katlanır
	var active_drain: float = avg_drain * (sprint_oxygen_multiplier if is_sprinting else 1.0)

	var oxygen_needed: float = time_to_surface * avg_drain
	var oxygen_seconds_left: float = current_oxygen / max(active_drain, 0.01) if current_oxygen > 0.0 else 0.0
	var is_critical: bool = (current_oxygen <= oxygen_needed) and (depth_m >= 2.0) and not godmode_enabled
	var is_warning: bool = (current_oxygen <= oxygen_needed * 1.25) and (depth_m >= 2.0) and not godmode_enabled

	return {
		"depth_m": depth_m,
		"time_to_surface": time_to_surface,
		"oxygen_needed": oxygen_needed,
		"oxygen_seconds_left": oxygen_seconds_left,
		"is_critical": is_critical,
		"is_warning": is_warning,
		"current_oxygen": current_oxygen,
		"godmode": godmode_enabled,
		"is_sprinting": is_sprinting
	}


# ------------------------------------------------------------------
# KAMERA SİSTEMİ
# ------------------------------------------------------------------

func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "PlayerCamera"
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
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


func zoom_in() -> void:
	_set_camera_zoom(camera_zoom + camera_zoom_step)


func zoom_out() -> void:
	_set_camera_zoom(camera_zoom - camera_zoom_step)
