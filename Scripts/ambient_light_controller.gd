extends CanvasModulate
class_name AmbientLightController

## ------------------------------------------------------------------
## EXPORT AYARLARI
## ------------------------------------------------------------------
@export_group("Derinlik Kararması")
@export var max_depth_reference: float = 260.0   # Okyanus fiziğine uygun olarak 260 metrede tam abis karanlığına ulaşılır
@export var depth_curve_exponent: float = 0.60   # İlk 30-100m inişte suyun daha hızlı koyulaşması

@export_group("Zemin Aydınlığı (Taban)")
@export var min_ambient_floor: float = 0.006     # Genel kararma oranını artıran, fener öncesi hafif silüet tabanı
@export var color_transition_speed: float = 3.5  # Işığın yumuşak geçiş hızı (lerp)

## ------------------------------------------------------------------
## RENK SABİTLERİ (Zaman ve Derinlik Paleti)
## ------------------------------------------------------------------
const DAY_SURFACE: Color = Color(1.0, 1.0, 1.0, 1.0)              # Berrak beyaz gün ışığı (10:00 - 13:00)
const AFTERNOON_SURFACE: Color = Color(0.78, 0.60, 0.42, 1.0)     # Sıcak ikindi güneşi (13:00 - 16:30)
const DUSK_SURFACE: Color = Color(0.06, 0.07, 0.14, 1.0)          # Belirgin koyu akşam alacakaranlığı (16:30 - 19:00)

const DAY_ABYSS: Color = Color(0.010, 0.018, 0.040, 1.0)          # Gündüz 260m+ dip (koyu okyanus laciverti/abis)
const NIGHT_ABYSS: Color = Color(0.003, 0.005, 0.010, 1.0)        # Paydos saati 260m+ dip (zifiri abis)

## ------------------------------------------------------------------
## INTERNAL STATE & DEV OVERRIDE
## ------------------------------------------------------------------
var _player: Node2D = null
var override_brightness: float = -1.0  # -1.0: Devre dışı (otomatik hesaplama), >= 0.0: Konsol manuel test


func _ready() -> void:
	add_to_group("ambient_light")
	_find_player()
	color = DAY_SURFACE


func _process(delta: float) -> void:
	if override_brightness >= 0.0:
		var target_c := Color(override_brightness, override_brightness, override_brightness, 1.0)
		color = color.lerp(target_c, 10.0 * delta)
		return

	if not is_instance_valid(_player):
		_find_player()
		if not is_instance_valid(_player):
			return

	var target_color: Color = _calculate_ambient_color()
	color = color.lerp(target_color, color_transition_speed * delta)


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _calculate_ambient_color() -> Color:
	if override_brightness >= 0.0:
		return Color(override_brightness, override_brightness, override_brightness, 1.0)

	# 1. DERİNLİK HESABI (Metre cinsinden)
	var surface_y: float = InfiniteMapManager.water_surface_y
	var player_y: float = _player.global_position.y
	var depth_pixels: float = max(0.0, player_y - surface_y)
	var depth_m: float = depth_pixels / 50.0

	var depth_t: float = clamp(depth_m / max(max_depth_reference, 1.0), 0.0, 1.0)
	var depth_factor: float = pow(depth_t, depth_curve_exponent)

	# 2. SAAT / ZAMAN HESABI (10:00 - 19:00)
	var time_factor: float = 0.0
	if GlobalTime:
		var current_min: float = float(GlobalTime.current_hour * 60 + GlobalTime.current_minute)
		# 13:00 = 780. dakika, 19:00 = 1140. dakika (360 dakika)
		if current_min > 780.0:
			time_factor = clamp((current_min - 780.0) / 360.0, 0.0, 1.0)

	# 3. YÜZEY RENGİ GEÇİŞİ (Gündüz -> İkindi -> Akşam)
	var surface_color: Color
	if time_factor < 0.5:
		var sub_t: float = time_factor / 0.5
		surface_color = DAY_SURFACE.lerp(AFTERNOON_SURFACE, sub_t)
	else:
		var sub_t: float = (time_factor - 0.5) / 0.5
		surface_color = AFTERNOON_SURFACE.lerp(DUSK_SURFACE, sub_t)

	# 4. ABİS (DİP) RENGİ GEÇİŞİ
	var abyss_color: Color = DAY_ABYSS.lerp(NIGHT_ABYSS, time_factor)

	# 5. DERİNLİK İLE BİRLEŞTİRME
	var blended_color: Color = surface_color.lerp(abyss_color, depth_factor)

	# Taban aydınlık güvencesi (fener gelene kadar zifiri körlüğü önler)
	blended_color.r = max(blended_color.r, min_ambient_floor)
	blended_color.g = max(blended_color.g, min_ambient_floor)
	blended_color.b = max(blended_color.b, min_ambient_floor)

	return blended_color
