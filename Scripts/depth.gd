extends Label

func _ready() -> void:
	# 1. ANCHOR AYARI (Sol Alta Sabitleme)
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	
	# Ekrana sıfır olmasın, biraz daha yukarı kalksın (-20'den -50'ye çıkardık)
	offset_left = 20
	offset_bottom = -50
	
	# 2. YAZI AYARLARI
	add_theme_font_size_override("font_size", 22) # Kutu daraldığı için fontu 24'ten 22'ye çektim, tam otursun
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 3. KAVİSLİ ARKA PLAN VE ÇERÇEVE
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.05, 0.1, 0.15, 0.85)
	style_box.set_corner_radius_all(16)
	style_box.set_border_width_all(3)
	style_box.border_color = Color(0.3, 0.6, 0.8, 0.9)
	
	# İç Boşlukları daralttık (Yanlardan küçüldü)
	style_box.content_margin_left = 12
	style_box.content_margin_right = 12
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	
	add_theme_stylebox_override("normal", style_box)
