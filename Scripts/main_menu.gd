extends Control

const LOADING_SCREEN := "res://Scenes/loading_screen.tscn"
const SETTINGS_FILE := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

@export var collection_scene: PackedScene  # res://Scenes/collection.tscn

@export_group("Sürüm")
@export var game_version: String = "PreAlpha 1.7.0 (City Integration)"  # Inspector'dan veya buradan kolayca düzenlenebilir

@onready var info_panel: Panel = $InfoPanel
@onready var info_button: Button = $Panel/VBoxContainer/Button4
@onready var info_close: Button = $InfoPanel/CloseButton
@onready var info_text: RichTextLabel = $InfoPanel/InfoText

@onready var collection_button: Button = $Panel/VBoxContainer/Button3

@onready var settings_panel: Panel = $SettingsPanel
@onready var settings_button: Button = $Panel/VBoxContainer/Button2
@onready var settings_close: Button = $SettingsPanel/CloseButton

@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $Panel/VBoxContainer/NewGameButton

@onready var sky_texture: TextureRect = get_node_or_null("SkyTexture")
@onready var header_texture: TextureRect = get_node_or_null("TextureRect")
@onready var title_box: Control = get_node_or_null("Panel/TitleBox")
@onready var remastered_label: Label = get_node_or_null("Panel/TitleBox/RemasteredLabel")
@onready var subtitle_label: Label = get_node_or_null("Panel/SubtitleLabel")
@onready var menu_buttons: VBoxContainer = $Panel/VBoxContainer
@onready var changelog_panel: Panel = $Panel/ChangelogPanel
@onready var changelog_text: RichTextLabel = get_node_or_null("Panel/ChangelogPanel/ChangelogText")
@onready var exit_button: Button = $Panel/Button
@onready var sunan_label: Label = get_node_or_null("Panel/Label2")
@onready var version_label: Label = $Panel/VersionLabel



@onready var music_slider: HSlider = $SettingsPanel/Content/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $SettingsPanel/Content/SfxRow/SfxSlider
@onready var fullscreen_check: CheckButton = $SettingsPanel/Content/FullscreenRow/FullscreenCheck
@onready var language_row: HBoxContainer = get_node_or_null("SettingsPanel/Content/LanguageRow")
@onready var language_label: Label = get_node_or_null("SettingsPanel/Content/LanguageRow/LanguageLabel")
@onready var language_option: OptionButton = get_node_or_null("SettingsPanel/Content/LanguageRow/LanguageOption")
@onready var joystick_row: HBoxContainer = get_node_or_null("SettingsPanel/Content/JoystickRow")
@onready var joystick_slider: HSlider = get_node_or_null("SettingsPanel/Content/JoystickRow/JoystickSlider")
@onready var joystick_val_label: Label = get_node_or_null("SettingsPanel/Content/JoystickRow/JoystickValueLabel")
@onready var flashlight_aim_row: HBoxContainer = get_node_or_null("SettingsPanel/Content/FlashlightAimRow")
@onready var flashlight_aim_option: OptionButton = get_node_or_null("SettingsPanel/Content/FlashlightAimRow/FlashlightAimOption")
@onready var reset_collection_button: Button = $SettingsPanel/Content/CollectionRow/ResetCollectionButton
@onready var dev_code_input: LineEdit = get_node_or_null("SettingsPanel/Content/DevCodeRow/DevCodeInput")
@onready var dev_code_button: Button = get_node_or_null("SettingsPanel/Content/DevCodeRow/DevCodeButton")

const DEV_SECRET_CODE: String = "mercedesforever" # Kendi belirleyeceğin gizli kod

var _panel_tweens: Dictionary = {}
var _base_positions: Dictionary = {}
var _active_collection: Node = null
var _active_confirm_dialog: CanvasLayer = null
var _active_lang_modal: Control = null


func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)

	_ensure_audio_buses()
	_apply_game_version()
	_capture_positions()
	info_panel.visible = false
	info_button.pressed.connect(_toggle_info_panel)
	info_close.pressed.connect(_close_info_panel)

	settings_panel.visible = false
	settings_button.pressed.connect(_toggle_settings_panel)
	settings_close.pressed.connect(_close_settings_panel)

	_refresh_save_buttons()
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	collection_button.pressed.connect(_toggle_collection)

	_load_settings()
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	reset_collection_button.pressed.connect(_on_reset_collection_pressed)

	if is_instance_valid(language_option):
		language_option.item_selected.connect(_on_language_selected)

	if is_instance_valid(dev_code_button):
		dev_code_button.pressed.connect(_on_dev_code_submitted)
	if is_instance_valid(dev_code_input):
		dev_code_input.text_submitted.connect(func(_text: String) -> void:
			_on_dev_code_submitted()
		)

	if not OS.has_feature("mobile"):
		if is_instance_valid(joystick_row):
			joystick_row.visible = false
		if is_instance_valid(flashlight_aim_row):
			flashlight_aim_row.visible = false
	else:
		if is_instance_valid(joystick_slider):
			joystick_slider.value_changed.connect(_on_joystick_slider_changed)
		if is_instance_valid(flashlight_aim_option):
			flashlight_aim_option.item_selected.connect(_on_flashlight_aim_selected)

	_setup_button_hover_sfx()

	if _should_show_language_prompt():
		if is_instance_valid($Panel):
			$Panel.visible = false
		if is_instance_valid(header_texture):
			header_texture.visible = false
		_show_first_launch_language_modal()
	else:
		refresh_ui()
		_play_entrance_animation()

	call_deferred("_preload_collection_cache")


func _process(_delta: float) -> void:
	_update_title_bobbing()


func _apply_game_version() -> void:
	if is_instance_valid(version_label):
		version_label.text = game_version
	_update_info_text()
	_update_changelog_text()


func _update_info_text() -> void:
	if not is_instance_valid(info_text):
		return
	var is_en := TranslationServer.get_locale().begins_with("en")
	if is_en:
		info_text.text = _get_info_bbcode_en()
	else:
		info_text.text = _get_info_bbcode_tr()


func _get_info_bbcode_tr() -> String:
	return """[center][font_size=24][color=#00e5ff][b]🤿 DIVE & FIND 🤿[/b][/color][/font_size][/center]

[color=#72b5ff][b]Hikaye & Konsept:[/b][/color]
Derin okyanusların gizemli sularına dalış yap! Dipte saklı kalan antik eserleri, değerli kalıntıları ve tuhaf objeleri topla, yüzeye çıkarıp sat ve ekipmanlarını geliştir.

[color=#72b5ff][b]Temel Kontroller (PC):[/b][/color]
• [color=#00e5ff]WASD / Yön Tuşları:[/color] Yüzme ve Hareket
• [color=#00e5ff]Shift (Basılı Tut):[/color] Hızlı Yüzme / Depar (Sprint — %50 hız artışı, 2.6x oksijen tüketimi)
• [color=#00e5ff]Sol Tık / E Tuşu:[/color] Eşyayı İncele (Detay penceresi ve alma menüsü açar)
• [color=#00e5ff]Sağ Tık:[/color] Doğrudan Çantaya Al (Pop-up açmadan hızlı alma)
• [color=#00e5ff]F Tuşu:[/color] Dalış Fenerini Aç / Kapat (Işık mouse imlecine yönelir, batarya tüketir)
• [color=#00e5ff]Fare Tekerleği / [ + ] [ - ] / P & O:[/color] Kamera Yakınlaştır / Uzaklaştır (Gözlük seviyesiyle genişler)
• [color=#00e5ff]I / Tab Tuşu:[/color] Sırt Çantasını Aç / Kapat (Envanter)
• [color=#00e5ff]C Tuşu:[/color] Koleksiyon Defterini Aç / Kapat (Keşfedilenler)
• [color=#00e5ff]Sağ Tık (Çantada):[/color] Eşyayı Kilitle / Kilidi Aç (🔒 Satış ve craft koruması)
• [color=#00e5ff]E (Su Yüzeyinde):[/color] Tekneye Çık & Ofis Karargahına Dön
• [color=#00e5ff]ESC:[/color] Açık pencereleri kapat / Ofisteyken dalışı başlat

[color=#72b5ff][b]Mobil Kontroller (Dokunmatik):[/b][/color]
• [color=#00e5ff]Sol Ekran:[/color] Dinamik Analog Joystick (360° serbest yüzüş)
• [color=#00e5ff]⚡ DEPAR:[/color] Hızlı yüzme modunu açar / kapatır
• [color=#00e5ff]⚡ DİREKT AL:[/color] Menzildeki eşyayı pop-up açmadan çantaya atar
• [color=#00e5ff]🖐️ İNCELE:[/color] Menzildeki eşyanın detay penceresini açar
• [color=#00e5ff]🥽+ / 🥽- :[/color] Kamerayı kademeli yakınlaştırıp uzaklaştırır
• [color=#00e5ff]🔦 FENER:[/color] Dalış fenerini açar / kapatır (Ayarlardan 3 yön modu seçilebilir)
• [color=#00e5ff]Uzun Basış (0.35s):[/color] Çantada eşyayı kilitler / açar 🔒

[center][font_size=13][color=#5e8ca8]Yapımcılar: Queen Of Femboyss & Hakan Bey[/color][/font_size]
[font_size=15][color=#00e5ff][i]⚓ Smile Games sunar """


func _get_info_bbcode_en() -> String:
	return """[center][font_size=24][color=#00e5ff][b]🤿 DIVE & FIND 🤿[/b][/color][/font_size][/center]

[color=#72b5ff][b]Story & Concept:[/b][/color]
Plunge into the mysterious depths of the ocean! Gather ancient relics, valuable salvage, and bizarre artifacts resting on the seabed, bring them to the surface to sell, and upgrade your diving gear.

[color=#72b5ff][b]Basic Controls (PC):[/b][/color]
• [color=#00e5ff]WASD / Arrow Keys:[/color] Swim and Navigate
• [color=#00e5ff]Shift (Hold):[/color] Fast Swimming / Sprint (+50% speed, 2.6x oxygen drain)
• [color=#00e5ff]Left Click / E Key:[/color] Examine Item (Opens detail popup and take options)
• [color=#00e5ff]Right Click:[/color] Quick Pick to Bag (Instantly grabs item without opening popup)
• [color=#00e5ff]F Key:[/color] Toggle Dive Light (Follows mouse cursor, drains battery)
• [color=#00e5ff]Scroll Wheel / [ + ] [ - ] / P & O:[/color] Camera Zoom In / Out (Expands with Mask level)
• [color=#00e5ff]I / Tab Key:[/color] Toggle Backpack (Inventory)
• [color=#00e5ff]C Key:[/color] Toggle Collection Log (Discovered Items)
• [color=#00e5ff]Right Click (In Bag):[/color] Lock / Unlock Item (🔒 Sell & craft protection)
• [color=#00e5ff]E (At Surface):[/color] Board Boat & Return to Office Headquarters
• [color=#00e5ff]ESC:[/color] Close open windows / Start dive when at Office

[color=#72b5ff][b]Mobile Controls (Touch):[/b][/color]
• [color=#00e5ff]Left Screen:[/color] Dynamic Analog Joystick (360° free swim)
• [color=#00e5ff]⚡ SPRINT:[/color] Toggles sprint mode on / off
• [color=#00e5ff]⚡ QUICK TAKE:[/color] Grabs nearby item directly into bag without popup
• [color=#00e5ff]🖐️ EXAMINE:[/color] Opens detailed examination window for nearby item
• [color=#00e5ff]🥽+ / 🥽- :[/color] Zoom camera in and out step by step
• [color=#00e5ff]🔦 LIGHT:[/color] Toggles dive light (3 aim modes available in Settings)
• [color=#00e5ff]Long Press (0.35s):[/color] Lock / unlock item in backpack 🔒

[center][font_size=13][color=#5e8ca8]Developers: Queen Of Femboyss & Hakan Bey[/color][/font_size]
[font_size=15][color=#00e5ff][i]⚓ Smile Games Presents """


func _update_changelog_text() -> void:
	if not is_instance_valid(changelog_text):
		return
	var is_en := TranslationServer.get_locale().begins_with("en")
	if is_en:
		changelog_text.text = _get_changelog_bbcode_en()
	else:
		changelog_text.text = _get_changelog_bbcode_tr()


func _get_changelog_bbcode_tr() -> String:
	return """[center][color=#ffd54f][font_size=16][b]⚓ PRE-ALPHA 1.7.0 SÜRÜM NOTLARI[/b][/font_size][/color][/center]

[color=#ffd54f][b]🚀 GÜNCELLEMELER & YENİLİKLER:[/b][/color]
• [color=#00e5ff]Şehir Haritası Tam Entegrasyonu:[/color] Oyun döngüsü artık doğrudan Liman Kasabası Şehir Haritası'ndan başlar. Tüm tesisler, mağazalar ve operasyonlar harita pinleri üzerinden yönetilir.
• [color=#00e5ff]İskele Barakası & Dalış Hazırlık Hub'ı:[/color] Şehir ile okyanus arasına denizci temalı Dalış Hazırlık İskelesi eklendi. Dalış öncesi ekipman durumu (çanta, oksijen tüpü, maske, palet, fener ve canlı batarya) tek ekranda incelenebilir, fener şarj edilebilir ve tek tuşla dalışa geçilebilir.
• [color=#00e5ff]Sinematik Yükleme Ekranı Geçişleri:[/color] Şehir Haritası, İskele Barakası, Okyanus Dalışı ve Ana Menü arasındaki tüm geçişler akıcı yükleme ekranı animasyonu eşliğinde pürüzsüzleştirildi.
• [color=#00e5ff]Doğrudan Ana Menüye Çıkış & Otomatik Kayıt:[/color] Şehir Haritası'ndaki çıkış butonu ile tüm ilerleme otomatik kaydedilerek doğrudan ana menüye dönülebilmesi sağlandı.

[color=#ff7043][b]⚡ PERFORMANS & HATA DÜZELTMELERİ:[/b][/color]
• [color=#81c784]Mobil Kontroller & Menü Çakışma Düzeltmesi:[/color] Şehir ve baraka menülerindeyken mobil dokunmatik kontrollerin ekranda kontrolsüzce belirme hatası giderildi; kontroller yalnızca okyanusta aktifleşir.

[center][color=#546e7a]──────────────────────────────────────[/color][/center]

[center][color=#00e5ff][font_size=16][b]⚓ PRE-ALPHA 1.6.3 SÜRÜM NOTLARI[/b][/font_size][/color][/center]

[color=#ffd54f][b]🚀 GÜNCELLEMELER & YENİLİKLER:[/b][/color]
• [color=#00e5ff]%100 İngilizce Dil Desteği:[/color] Oyunun tüm arayüzleri, menüleri, diyalogları, eşyaları, bildirimleri ve rehberleri için eksiksiz Türkçe / İngilizce çift dilli yerelleştirme (Bilingual Localization) tamamlandı. Ayarlar menüsünden anında geçiş yapılabilir.
• [color=#00e5ff]Eşya Açıklamaları & Hikaye Düzeltmeleri:[/color] Tüm deniz altı eşyalarının açıklamaları, yazım hataları ve hikaye metinleri baştan sona gözden geçirilip düzeltildi; her eşyaya derinlik katan tematik açıklamalar işlendi.
• [color=#00e5ff]Fiyatlandırma & Nadirlik (Rarity) Rework'ü:[/color] Tüm eşyaların nadirlik sınıfları ve satış fiyatları derinlik seviyelerine, craft zincirine ve oyun ekonomisine uygun şekilde yeniden yapılandırılarak dengeli ve ödüllendirici hale getirildi.
• [color=#00e5ff]Ana Menü & Yükleme Ekranı UI Rework'ü:[/color] Ana menü ve yükleme (loading) ekranı modern ve estetik bir arayüz tasarımına kavuşturuldu; akıcı geçiş animasyonları, modernize tipografi ve yeni görsel düzen entegre edildi.
• [color=#00e5ff]Yeni Oyun Simgesi & Splash Screen:[/color] Yepyeni yüksek çözünürlüklü oyun simgesi ve açılışta karşılayan özel animasyonlu Splash Screen sahnesi eklendi.

[center][color=#546e7a]──────────────────────────────────────[/color][/center]

[center][color=#00e5ff][font_size=16][b]⚓ PRE-ALPHA 1.6.2 SÜRÜM NOTLARI[/b][/font_size][/color][/center]

[color=#ffd54f][b]🚀 GÜNCELLEMELER & YENİLİKLER:[/b][/color]
• [color=#00e5ff]Ofis Şarj İstasyonu & Ücretli Batarya:[/color] Yüzeyde ve ofise girişteki ücretsiz otomatik şarj kaldırıldı. Ofis alt barına Şarj İstasyonu (HSlider ve MAX dolum) ile canlı batarya rozeti eklendi.
• [color=#00e5ff]Dinamik Batarya Fiyatlandırması:[/color] Fener şarj maliyeti sabit fiyattan saniye/kapasite bazlı adil modele geçirildi (0.30 Zurna/sn; Lv.1 ~23Z, Lv.15 ~60Z).
• [color=#00e5ff]Derinlik & Gece Kararması Buff'ı:[/color] Okyanus kararma eğrisi güçlendirildi (260m referans derinlik, daha dik abis geçişi, zifiri karanlık dip suları).
• [color=#00e5ff]Yeni Oyun Güvenlik Modalı:[/color] Kayıtlı oyun varken yanlışlıkla "Yeni Oyun" denildiğinde ilerlemenin ve ekipmanların silinmesini önleyen onay penceresi eklendi.
• [color=#00e5ff]Mobil Dalış Duraklatma (Pause) Tuşu:[/color] Mobil dokunmatik arayüzün sağ üst köşesine kompakt duraklatma butonu ([ ⏸️ ]) eklendi.
• [color=#00e5ff]Laboratuvar Craft Kar Dengelemesi:[/color] Üretilen eşyaların satış gelirleri ve kar marjları piyasa dengesini koruyacak şekilde yeniden dengelendi.
• [color=#00e5ff]Geliştirici Konsolu Karartma Komutu:[/color] Konsola dinamik test için `darkness` (ve `karartma`) komutu ile hazır önayarlar (abis, day, reset) eklendi.

[color=#ff7043][b]⚡ PERFORMANS & HATA DÜZELTMELERİ:[/b][/color]
• [color=#81c784]Toast Bildirim Ekran Esneme (Stretch) Fix'i:[/color] Uzun bildirim mesajlarında ofis menüsü ve ekran kenarlarının dışa taşması ToastLabel bağımsız yüzen panele taşınarak tamamen çözüldü.
• [color=#81c784]Anlık Ekipman Rozet Senkronizasyonu:[/color] Mağazadan fener veya ekipman satın alındığı anda alt bardaki durum rozetinin mağaza kapanmadan anında güncellenmesi sağlandı.

[center][color=#546e7a]──────────────────────────────────────[/color][/center]

[center][color=#00e5ff][font_size=16][b]⚓ PRE-ALPHA 1.6.1 SÜRÜM NOTLARI[/b][/font_size][/color][/center]

[color=#ffd54f][b]🚀 GÜNCELLEMELER & YENİLİKLER:[/b][/color]
• [color=#00e5ff]Direkt Alma Özelliği (PC Entegrasyonu):[/color] Eşyaları menü açmadan tek tuşla anında çantaya alma kabiliyeti PC'ye de getirildi (Sağ Klik).
• [color=#00e5ff]Mobil Fener Nişanlama & Hassasiyet Ayarları:[/color] Ayarlar menüsüne 3 modlu mobil fener hedefleme seçeneği eklendi (Joystick Yüzüş Yönü, Serbest Dokunmatik Aim, Akıllı Hibrit).
• [color=#00e5ff]Koleksiyon Sıfırlama Güvenlik Onayı:[/color] Koleksiyon defterini sıfırlama butonuna yanlışlıkla basılmaları önleyen denizci temalı iki aşamalı onay penceresi entegre edildi.

[color=#ff7043][b]⚡ PERFORMANS & HATA DÜZELTMELERİ:[/b][/color]
• [color=#81c784]Toplu Satış & Hızlı Yükseltme Optimizasyonu:[/color] "Hepsini Sat" yapıldığında tek karede yüzlerce slot sahnesi üretilip silinmesi engellendi; hızlı geliştirmedeki gereksiz çifte tetiklemeler ve tween çakışmaları sıfırlandı.
• [color=#81c784]Yeni Eşya Keşif Takılması (Lag Spike) Giderildi:[/color] Yeni eşyalar ilk kez keşfedildiğinde yaşanan disk yazma takılması WorkerThreadPool arka plan I/O mimarisiyle tamamen akıcı hale getirildi.
• [color=#81c784]Fener Işık & Fizik (FPS) Optimizasyonu:[/color] Fener doku üretimi ve dinamik ışık motoru optimize edilerek fener ilk açıldığında oluşan fps düşüşü ve takılmalar tamamen giderildi.
• [color=#81c784]Fener HUD (Ekipman Dock) Senkronizasyonu:[/color] Okyanustaki sağ alt ekipman dock'unda fener seviyesinin (Lv.X) güncellenmeme ve görünmeme sorunu çözüldü.
• [color=#81c784]Mobil Buton Teması Düzeltildi:[/color] Mobil fener ve depar butonlarının varsayılan gri temaya düşme ve temassız/stilsiz görünme hatası önbellek stiliyle düzeltildi."""


func _get_changelog_bbcode_en() -> String:
	return """[center][color=#ffd54f][font_size=16][b]⚓ PRE-ALPHA 1.7.0 PATCH NOTES[/b][/font_size][/color][/center]

[color=#ffd54f][b]🚀 UPDATES & NEW FEATURES:[/b][/color]
• [color=#00e5ff]Full City Map Integration:[/color] Game loop now directly launches into the Port Town City Map. All facilities, merchant stalls, and operations are managed via map pins.
• [color=#00e5ff]Dock Shack & Dive Preparation Pier Hub:[/color] Added a nautical Dock Shack hub between town and ocean. Check all equipment stats (backpack, O2 tank, mask, fins, flashlight and live battery), recharge flashlight, and dive into the deep.
• [color=#00e5ff]Cinematic Loading Screen Transitions:[/color] Seamless loading screen transitions smoothly bridge City Map, Dock Shack, Ocean Diving, and the Main Menu.
• [color=#00e5ff]Direct Exit to Main Menu & Auto-Save:[/color] Exit Map button on the City Map automatically saves progress and returns directly to the Main Menu.

[color=#ff7043][b]⚡ PERFORMANCE & BUG FIXES:[/b][/color]
• [color=#81c784]Mobile Controls & Hub UI Conflict Fixed:[/color] Resolved the bug where mobile touch controls spawned when closing menus; controls now strictly activate only while diving in the ocean.

[center][color=#546e7a]──────────────────────────────────────[/color][/center]

[center][color=#00e5ff][font_size=16][b]⚓ PRE-ALPHA 1.6.3 PATCH NOTES[/b][/font_size][/color][/center]

[color=#ffd54f][b]🚀 UPDATES & NEW FEATURES:[/b][/color]
• [color=#00e5ff]100% English Language Support:[/color] Full bilingual localization (TR / EN) implemented across all UI screens, menus, dialogs, items, notifications, and guides. Seamless instant language switching via Settings.
• [color=#00e5ff]Item Descriptions & Lore Overhaul:[/color] All underwater items, artifacts, and lore texts have been revised, typos fixed, and enriched with flavorful maritime descriptions.
• [color=#00e5ff]Economy & Rarity Rework:[/color] Complete overhaul of item rarity tiers and base sell values tuned across depth zones and crafting recipes for a rewarding economy.
• [color=#00e5ff]Main Menu & Loading Screen UI Rework:[/color] Completely redesigned sleek and modern layouts for the Main Menu and Loading Screens with smooth responsive animations, modernized typography, and polished visuals.
• [color=#00e5ff]New Game Icon & Animated Splash Screen:[/color] Brand new high-resolution game icon and a dedicated animated Splash Screen intro sequence.

[center][color=#546e7a]──────────────────────────────────────[/color][/center]

[center][color=#00e5ff][font_size=16][b]⚓ PRE-ALPHA 1.6.2 PATCH NOTES[/b][/font_size][/color][/center]

[color=#ffd54f][b]🚀 UPDATES & NEW FEATURES:[/b][/color]
• [color=#00e5ff]Office Charging Station & Paid Battery:[/color] Free automatic charging upon surfacing and office entry removed. Added Charging Station (HSlider and MAX fill) and live battery badge to office bottom bar.
• [color=#00e5ff]Dynamic Battery Pricing:[/color] Flashlight charging cost changed from flat rate to fair second/capacity-based model (0.30 Zurna/sec; Lv.1 ~23Z, Lv.15 ~60Z).
• [color=#00e5ff]Depth & Night Darkness Buff:[/color] Ocean darkening curve intensified (260m reference depth, steeper abyss gradient, pitch-black deep waters).
• [color=#00e5ff]New Game Confirmation Modal:[/color] Added confirmation prompt when starting a "New Game" with existing save data to prevent accidental loss of progress and equipment.
• [color=#00e5ff]Mobile Dive Pause Button:[/color] Added compact pause button ([ ⏸️ ]) to upper-right corner of mobile touch interface.
• [color=#00e5ff]Laboratory Craft Profit Rebalancing:[/color] Adjusted item sell values and profit margins to maintain economic balance.
• [color=#00e5ff]Dev Console Darkness Command:[/color] Added `darkness` (and `karartma`) command to console with quick presets (abyss, day, reset) for dynamic testing.

[color=#ff7043][b]⚡ PERFORMANCE & BUG FIXES:[/b][/color]
• [color=#81c784]Toast Notification Stretch Fix:[/color] Long notification messages causing office menu stretching fixed by migrating ToastLabel to an independent floating panel.
• [color=#81c784]Instant Equipment Badge Sync:[/color] Buying flashlights or equipment updates bottom bar status badges immediately without closing shop.

[center][color=#546e7a]──────────────────────────────────────[/color][/center]

[center][color=#00e5ff][font_size=16][b]⚓ PRE-ALPHA 1.6.1 PATCH NOTES[/b][/font_size][/color][/center]

[color=#ffd54f][b]🚀 UPDATES & NEW FEATURES:[/b][/color]
• [color=#00e5ff]Direct Pickup (PC Integration):[/color] Added right-click shortcut to immediately store items into backpack without opening pop-up.
• [color=#00e5ff]Mobile Flashlight Aim & Sensitivity Settings:[/color] Added 3-mode mobile flashlight aiming options to settings (Swim Direction, Free Touch Aim, Smart Hybrid).
• [color=#00e5ff]Collection Reset Confirmation:[/color] Integrated nautical-themed two-step confirmation window to prevent accidental collection log resets.

[color=#ff7043][b]⚡ PERFORMANCE & BUG FIXES:[/b][/color]
• [color=#81c784]Bulk Sell & Fast Upgrade Optimization:[/color] Prevented instantiating and freeing hundreds of slot scenes during "Sell All"; eliminated double triggers and tween conflicts in fast upgrades.
• [color=#81c784]New Item Discovery Lag Spike Resolved:[/color] Disk write stutter upon discovering new items resolved using WorkerThreadPool background I/O architecture.
• [color=#81c784]Flashlight Lighting & Physics Optimization:[/color] Flashlight texture generation and dynamic light engine optimized, eliminating initial FPS drops and stutters.
• [color=#81c784]Flashlight HUD Sync:[/color] Resolved issue where flashlight level (Lv.X) did not update or appear in ocean equipment dock.
• [color=#81c784]Mobile Button Theme Fixed:[/color] Resolved mobile flashlight and sprint buttons reverting to default gray styling using cached styles."""


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) < 0:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, MUSIC_BUS)
	if AudioServer.get_bus_index(SFX_BUS) < 0:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, SFX_BUS)


func _capture_positions() -> void:
	var nodes := [
		info_panel, settings_panel, title_box, menu_buttons,
		subtitle_label, exit_button, sunan_label, version_label,
		sky_texture, header_texture, changelog_panel
	]
	for node in nodes:
		if is_instance_valid(node):
			_base_positions[node] = node.position


func _play_entrance_animation() -> void:
	if is_instance_valid(header_texture) and _base_positions.has(header_texture):
		_animate_enter(header_texture, _base_positions[header_texture] + Vector2(0.0, -35.0), 0.55)
	elif is_instance_valid(title_box) and _base_positions.has(title_box):
		_animate_enter(title_box, _base_positions[title_box] + Vector2(-60.0, 0.0), 0.45)

	if is_instance_valid(subtitle_label):
		_fade_in(subtitle_label, 0.3)

	if is_instance_valid(menu_buttons) and _base_positions.has(menu_buttons):
		_animate_enter(menu_buttons, _base_positions[menu_buttons] + Vector2(-70.0, 0.0), 0.5)

	if is_instance_valid(menu_buttons):
		var buttons: Array[Node] = menu_buttons.get_children()
		for i in buttons.size():
			if buttons[i] is Control:
				_fade_in(buttons[i] as Control, 0.07 * i)

	if is_instance_valid(changelog_panel) and _base_positions.has(changelog_panel):
		_animate_enter(changelog_panel, _base_positions[changelog_panel] + Vector2(60.0, 0.0), 0.5)
	elif is_instance_valid(changelog_panel):
		_fade_in(changelog_panel, 0.35)

	if is_instance_valid(exit_button):
		_fade_in(exit_button, 0.45)
	if is_instance_valid(sunan_label):
		_fade_in(sunan_label, 0.6)
	if is_instance_valid(version_label):
		_fade_in(version_label, 0.5)


func _animate_enter(control: Control, from: Vector2, duration: float) -> void:
	if not is_instance_valid(control) or not _base_positions.has(control):
		return
	control.position = from
	control.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(control, "position", _base_positions[control], duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration)


func _fade_in(control: Control, delay: float) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, 0.35)


func _setup_button_hover_sfx() -> void:
	if is_instance_valid(menu_buttons):
		var buttons: Array[Node] = menu_buttons.get_children()
		for child in buttons:
			if child is Button:
				var btn := child as Button
				btn.mouse_entered.connect(func() -> void:
					if not btn.disabled:
						GlobalSoundManager.play_sfx("click")
				)
	if is_instance_valid(exit_button):
		exit_button.mouse_entered.connect(func() -> void:
			if not exit_button.disabled:
				GlobalSoundManager.play_sfx("click")
		)


func _update_title_bobbing() -> void:
	if is_instance_valid(header_texture) and _base_positions.has(header_texture):
		var float_y := sin(Time.get_ticks_msec() * 0.002) * 4.0
		header_texture.position.y = _base_positions[header_texture].y + float_y

	if is_instance_valid(title_box) and _base_positions.has(title_box):
		var float_y := sin(Time.get_ticks_msec() * 0.002) * 3.5
		title_box.position.y = _base_positions[title_box].y + float_y

	if is_instance_valid(remastered_label):
		var glow_pulse := sin(Time.get_ticks_msec() * 0.004) * 0.18 + 0.82
		remastered_label.modulate.a = glow_pulse


func _toggle_info_panel() -> void:
	if is_instance_valid(_active_collection):
		_active_collection.queue_free()
		_active_collection = null
	if info_panel.visible:
		_hide_panel(info_panel)
	else:
		_update_info_text()
		_hide_panel(settings_panel)
		_show_panel(info_panel)


func _close_info_panel() -> void:
	_hide_panel(info_panel)


func _toggle_settings_panel() -> void:
	if is_instance_valid(_active_collection):
		_active_collection.queue_free()
		_active_collection = null
	if settings_panel.visible:
		_hide_panel(settings_panel)
	else:
		_hide_panel(info_panel)
		_show_panel(settings_panel)


func _close_settings_panel() -> void:
	_hide_panel(settings_panel)


func _panel_tween(panel: Panel) -> Tween:
	var t: Tween = _panel_tweens.get(panel)
	if t and t.is_valid():
		t.kill()
	var nt := create_tween()
	_panel_tweens[panel] = nt
	return nt


func _show_panel(panel: Panel) -> void:
	var tween := _panel_tween(panel)
	var base: Vector2 = _base_positions.get(panel, panel.position)
	panel.visible = true
	panel.modulate.a = 0.0
	panel.position = base + Vector2(100.0, 0.0)
	tween.set_parallel(true)
	tween.tween_property(panel, "position", base, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)


func _hide_panel(panel: Panel) -> void:
	var tween := _panel_tween(panel)
	var base: Vector2 = _base_positions.get(panel, panel.position)
	tween.set_parallel(true)
	tween.tween_property(panel, "position", base + Vector2(60.0, 0.0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func() -> void:
		panel.visible = false
		panel.position = base
		panel.modulate.a = 1.0
	)


func _refresh_save_buttons() -> void:
	var has_save: bool = GlobalInventory.has_save()
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	continue_button.disabled = not has_save
	if has_save:
		var save_data: Dictionary = GlobalInventory.get_save_data()
		var day := int(save_data.get("current_day", 1))
		var money := int(save_data.get("money", 0))
		continue_button.text = ("CONTINUE  (Day %d • %d Zurna)" if is_en else "DEVAM ET  (Gün %d • %d Zurna)") % [day, money]
		continue_button.tooltip_text = GlobalInventory.get_save_summary()
	else:
		continue_button.text = "CONTINUE" if is_en else "DEVAM ET"
		continue_button.tooltip_text = "No saved game found." if is_en else "Kayıtlı oyun bulunamadı."


func _on_new_game_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	if GlobalInventory.has_save():
		_show_new_game_confirmation()
	else:
		_start_new_game_direct()


func _start_new_game_direct() -> void:
	GlobalInventory.start_new_game()
	get_tree().change_scene_to_file(LOADING_SCREEN)


func _show_new_game_confirmation() -> void:
	if is_instance_valid(_active_confirm_dialog):
		_active_confirm_dialog.queue_free()
		_active_confirm_dialog = null

	var confirm_layer := CanvasLayer.new()
	confirm_layer.layer = 130
	_active_confirm_dialog = confirm_layer

	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_layer.add_child(overlay)

	# Dışarı tıklandığında iptal etme
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			GlobalSoundManager.play_sfx("click")
			if is_instance_valid(confirm_layer):
				confirm_layer.queue_free()
				_active_confirm_dialog = null
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 230)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.85, 0.75, 0.45, 1.0)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = tr("⚠️ MEVCUT KAYIT SİLİNECEK")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var save_data: Dictionary = GlobalInventory.get_save_data()
	var day := int(save_data.get("current_day", 1))
	var money := int(save_data.get("money", 0))

	var desc := Label.new()
	desc.text = tr("Mevcut kayıtlı oyunun (Gün %d • %d Zurna) ve satın aldığın tüm ekipman seviyeleri sıfırlanacak.\n(Keşfettiğin eşya koleksiyonu korunur)\n\nBu işlem geri alınamaz! Yeni bir oyuna başlamak istediğinden emin misin?") % [day, money]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	desc.add_theme_font_size_override("font_size", 14)
	vbox.add_child(desc)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var cancel_btn := Button.new()
	cancel_btn.text = tr("VAZGEÇ")
	cancel_btn.custom_minimum_size = Vector2(160, 44)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.25, 0.20, 0.18, 1.0)
	cancel_style.border_color = Color(0.50, 0.40, 0.30, 1.0)
	cancel_style.set_border_width_all(2)
	cancel_style.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.pressed.connect(func() -> void:
		GlobalSoundManager.play_sfx("click")
		if is_instance_valid(confirm_layer):
			confirm_layer.queue_free()
			_active_confirm_dialog = null
	)
	hbox.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = tr("EVET, YENİ OYUN 🚀")
	confirm_btn.custom_minimum_size = Vector2(170, 44)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.75, 0.22, 0.20, 1.0)
	confirm_style.border_color = Color(0.95, 0.40, 0.35, 1.0)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.90, 1.0))
	confirm_btn.pressed.connect(func() -> void:
		GlobalSoundManager.play_sfx("click")
		if is_instance_valid(confirm_layer):
			confirm_layer.queue_free()
			_active_confirm_dialog = null
		_start_new_game_direct()
	)
	hbox.add_child(confirm_btn)

	confirm_layer.tree_exited.connect(func() -> void:
		if _active_confirm_dialog == confirm_layer:
			_active_confirm_dialog = null
	)
	add_child(confirm_layer)



func _on_continue_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	GlobalInventory.apply_save_to_game()
	get_tree().change_scene_to_file(LOADING_SCREEN)


func _preload_collection_cache() -> void:
	GlobalInventory.get_all_items()


func _toggle_collection() -> void:
	GlobalSoundManager.play_sfx("click")
	if is_instance_valid(_active_collection):
		_active_collection.queue_free()
		_active_collection = null
		return

	if not collection_scene:
		push_warning("MainMenu: collection_scene atanmamış!")
		return

	_hide_panel(settings_panel)
	_hide_panel(info_panel)

	_active_collection = collection_scene.instantiate()
	_active_collection.tree_exited.connect(func() -> void:
		_active_collection = null
	)
	get_tree().current_scene.add_child(_active_collection)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_active_lang_modal):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(_active_confirm_dialog):
				_active_confirm_dialog.queue_free()
				_active_confirm_dialog = null
				get_viewport().set_input_as_handled()
			elif is_instance_valid(_active_collection):
				_active_collection.queue_free()
				_active_collection = null
				get_viewport().set_input_as_handled()
			elif settings_panel.visible:
				_close_settings_panel()
				get_viewport().set_input_as_handled()
			elif info_panel.visible:
				_close_info_panel()
				get_viewport().set_input_as_handled()


func _on_reset_collection_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
	_show_reset_collection_confirmation()


func _show_reset_collection_confirmation() -> void:
	if is_instance_valid(_active_confirm_dialog):
		_active_confirm_dialog.queue_free()
		_active_confirm_dialog = null

	var confirm_layer := CanvasLayer.new()
	confirm_layer.layer = 130
	_active_confirm_dialog = confirm_layer

	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_layer.add_child(overlay)

	# Dışarı tıklandığında iptal etme
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			GlobalSoundManager.play_sfx("click")
			if is_instance_valid(confirm_layer):
				confirm_layer.queue_free()
				_active_confirm_dialog = null
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 220)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.85, 0.75, 0.45, 1.0)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = tr("⚠️ KOLEKSİYONU SIFIRLA")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = tr("Tüm keşfettiğin eşyalar koleksiyon defterinden kalıcı olarak silinecektir.\nBu işlem geri alınamaz!\n\nKoleksiyonu sıfırlamak istediğinden emin misin?")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	desc.add_theme_font_size_override("font_size", 14)
	vbox.add_child(desc)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var cancel_btn := Button.new()
	cancel_btn.text = tr("VAZGEÇ")
	cancel_btn.custom_minimum_size = Vector2(160, 44)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.25, 0.20, 0.18, 1.0)
	cancel_style.border_color = Color(0.50, 0.40, 0.30, 1.0)
	cancel_style.set_border_width_all(2)
	cancel_style.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.pressed.connect(func() -> void:
		GlobalSoundManager.play_sfx("click")
		if is_instance_valid(confirm_layer):
			confirm_layer.queue_free()
			_active_confirm_dialog = null
	)
	hbox.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = tr("EVET, SIFIRLA 🗑️")
	confirm_btn.custom_minimum_size = Vector2(160, 44)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.75, 0.22, 0.20, 1.0)
	confirm_style.border_color = Color(0.95, 0.40, 0.35, 1.0)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.90, 1.0))
	confirm_btn.pressed.connect(func() -> void:
		GlobalSoundManager.play_sfx("click")
		if is_instance_valid(confirm_layer):
			confirm_layer.queue_free()
			_active_confirm_dialog = null
		_execute_reset_collection()
	)
	hbox.add_child(confirm_btn)

	confirm_layer.tree_exited.connect(func() -> void:
		if _active_confirm_dialog == confirm_layer:
			_active_confirm_dialog = null
	)
	add_child(confirm_layer)


func _execute_reset_collection() -> void:
	GlobalInventory.reset_collection()
	var original_text := reset_collection_button.text
	reset_collection_button.text = tr("SIFIRLANDI!")
	reset_collection_button.disabled = true
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(func() -> void:
		if is_instance_valid(reset_collection_button):
			reset_collection_button.text = original_text
			reset_collection_button.disabled = false
	)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var music := 70.0
	var sfx := 80.0
	var fullscreen := true
	var joystick_scale := 1.0
	var flashlight_aim := 2
	var language := "tr"
	if cfg.load(SETTINGS_FILE) == OK:
		music = cfg.get_value("audio", "music", music)
		sfx = cfg.get_value("audio", "sfx", sfx)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
		joystick_scale = cfg.get_value("controls", "joystick_scale", joystick_scale)
		flashlight_aim = int(cfg.get_value("controls", "mobile_flashlight_aim", flashlight_aim))
		language = cfg.get_value("general", "language", language)

	if language == "en" or language == "tr":
		TranslationServer.set_locale(language)

	_set_bus_volume(MUSIC_BUS, music)
	_set_bus_volume(SFX_BUS, sfx)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	music_slider.value = music
	sfx_slider.value = sfx
	fullscreen_check.set_pressed_no_signal(fullscreen)
	if is_instance_valid(joystick_slider):
		joystick_slider.value = joystick_scale
	if is_instance_valid(joystick_val_label):
		joystick_val_label.text = "%%%d" % [int(round(joystick_scale * 100.0))]
	if is_instance_valid(flashlight_aim_option):
		flashlight_aim_option.select(clampi(flashlight_aim, 0, 2))
	if is_instance_valid(language_option):
		var is_en: bool = TranslationServer.get_locale().begins_with("en") or language == "en"
		language_option.select(1 if is_en else 0)
	_refresh_dev_code_ui()


func _refresh_dev_code_ui() -> void:
	if not is_instance_valid(dev_code_input) or not is_instance_valid(dev_code_button):
		return
	var dev_console = get_node_or_null("/root/DevConsole")
	var is_unlocked: bool = dev_console.is_dev_console_unlocked() if dev_console and dev_console.has_method("is_dev_console_unlocked") else false
	var is_en: bool = ItemTranslator.get_current_locale() == "en"
	if is_unlocked:
		dev_code_input.text = ""
		dev_code_input.placeholder_text = "ACTIVE ✅" if is_en else "AKTİF ✅"
		dev_code_button.text = "DISABLE" if is_en else "KAPAT"
		dev_code_button.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4, 1.0))
	else:
		dev_code_input.text = ""
		dev_code_input.placeholder_text = "Secret code..." if is_en else "Gizli kod..."
		dev_code_button.text = "ACTIVATE" if is_en else "AKTİF ET"
		dev_code_button.remove_theme_color_override("font_color")


func _on_dev_code_submitted() -> void:
	if not is_instance_valid(dev_code_input) or not is_instance_valid(dev_code_button):
		return
	var dev_console = get_node_or_null("/root/DevConsole")
	if not dev_console:
		return

	var is_unlocked: bool = dev_console.is_dev_console_unlocked() if dev_console.has_method("is_dev_console_unlocked") else false
	var entered_code: String = dev_code_input.text.strip_edges()

	# Eğer zaten aktifse ve kullanıcı KAPAT butonuna bastıysa:
	if is_unlocked and (entered_code == "" or entered_code == DEV_SECRET_CODE):
		if dev_console.has_method("set_dev_unlocked"):
			dev_console.set_dev_unlocked(false)
		GlobalSoundManager.play_sfx("click")
		_refresh_dev_code_ui()
		return

	# Kilidi açma kontrolü:
	if entered_code == DEV_SECRET_CODE:
		if dev_console.has_method("set_dev_unlocked"):
			dev_console.set_dev_unlocked(true)
		GlobalSoundManager.play_sfx("upgrade")
		_refresh_dev_code_ui()
	else:
		GlobalSoundManager.play_sfx("error")
		var is_en: bool = ItemTranslator.get_current_locale() == "en"
		dev_code_button.text = "INVALID! ❌" if is_en else "HATALI! ❌"
		dev_code_button.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3, 1.0))
		var tw := create_tween()
		tw.tween_interval(1.2)
		tw.tween_callback(func() -> void:
			if is_instance_valid(dev_code_button):
				_refresh_dev_code_ui()
		)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	var current_lang := "en" if TranslationServer.get_locale().begins_with("en") else "tr"
	cfg.set_value("general", "language", current_lang)
	cfg.set_value("general", "last_version", game_version)
	cfg.set_value("audio", "music", music_slider.value)
	cfg.set_value("audio", "sfx", sfx_slider.value)
	cfg.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	if is_instance_valid(joystick_slider):
		cfg.set_value("controls", "joystick_scale", joystick_slider.value)
	if is_instance_valid(flashlight_aim_option):
		cfg.set_value("controls", "mobile_flashlight_aim", flashlight_aim_option.selected)
	cfg.save(SETTINGS_FILE)


func _on_language_selected(index: int) -> void:
	GlobalSoundManager.play_sfx("click")
	var new_locale := "en" if index == 1 else "tr"
	TranslationServer.set_locale(new_locale)
	_save_settings()
	refresh_ui()
	var dev_console = get_node_or_null("/root/DevConsole")
	if dev_console and dev_console.has_method("refresh_active_uis"):
		dev_console.refresh_active_uis()


func refresh_ui() -> void:
	_apply_game_version()
	_refresh_save_buttons()
	_refresh_menu_labels()


func _refresh_menu_labels() -> void:
	var is_en := TranslationServer.get_locale().begins_with("en")

	if is_instance_valid(new_game_button):
		new_game_button.text = tr("YENİ OYUN")
	if is_instance_valid(collection_button):
		collection_button.text = tr("KOLEKSİYON")
	if is_instance_valid(settings_button):
		settings_button.text = tr("AYARLAR")
	if is_instance_valid(info_button):
		info_button.text = tr("BİLGİ & YARDIM")
	if is_instance_valid(exit_button):
		exit_button.text = tr("OYUNDAN ÇIK")
	if is_instance_valid(sunan_label):
		sunan_label.text = tr("⚓ Smile Games Sunar")

	var changelog_title: Label = get_node_or_null("Panel/ChangelogPanel/ChangelogTitle")
	if is_instance_valid(changelog_title):
		changelog_title.text = tr("📋 YENİLİKLER & GÜNCELLEMELER")
	_update_changelog_text()

	# Settings Panel
	var settings_title: Label = get_node_or_null("SettingsPanel/TitleLabel")
	if is_instance_valid(settings_title):
		settings_title.text = tr("AYARLAR")

	var music_label: Label = get_node_or_null("SettingsPanel/Content/MusicRow/MusicLabel")
	if is_instance_valid(music_label):
		music_label.text = tr("Müzik")

	var sfx_label: Label = get_node_or_null("SettingsPanel/Content/SfxRow/SfxLabel")
	if is_instance_valid(sfx_label):
		sfx_label.text = tr("Ses Efektleri")

	var fs_label: Label = get_node_or_null("SettingsPanel/Content/FullscreenRow/FullscreenLabel")
	if is_instance_valid(fs_label):
		fs_label.text = tr("Tam Ekran")

	if is_instance_valid(language_label):
		language_label.text = tr("Dil")

	if is_instance_valid(language_option):
		language_option.select(1 if is_en else 0)

	var joy_label: Label = get_node_or_null("SettingsPanel/Content/JoystickRow/JoystickLabel")
	if is_instance_valid(joy_label):
		joy_label.text = tr("Joystick Boyutu")

	var aim_label: Label = get_node_or_null("SettingsPanel/Content/FlashlightAimRow/FlashlightAimLabel")
	if is_instance_valid(aim_label):
		aim_label.text = tr("Mobil Fener Yönü")

	if is_instance_valid(flashlight_aim_option) and flashlight_aim_option.item_count >= 3:
		flashlight_aim_option.set_item_text(0, tr("🕹️ Yüzüş Yönü (Joystick)"))
		flashlight_aim_option.set_item_text(1, tr("👆 Dokunmatik (Serbest Aim)"))
		flashlight_aim_option.set_item_text(2, tr("✨ Akıllı Hibrit (Joystick + Dokunma)"))

	var coll_label: Label = get_node_or_null("SettingsPanel/Content/CollectionRow/CollectionLabel")
	if is_instance_valid(coll_label):
		coll_label.text = tr("Koleksiyon")

	if is_instance_valid(reset_collection_button):
		reset_collection_button.text = tr("KOLEKSİYONU SIFIRLA")

	var dev_code_label: Label = get_node_or_null("SettingsPanel/Content/DevCodeRow/DevCodeLabel")
	if is_instance_valid(dev_code_label):
		dev_code_label.text = tr("DevCode")

	_refresh_dev_code_ui()

	var info_title: Label = get_node_or_null("InfoPanel/TitleLabel")
	if is_instance_valid(info_title):
		info_title.text = tr("BİLGİ & YARDIM")


func _should_show_language_prompt() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return true
	if not cfg.has_section_key("general", "language"):
		return true
	var last_version: String = str(cfg.get_value("general", "last_version", ""))
	if last_version != game_version:
		return true
	return false


func _show_first_launch_language_modal() -> void:
	if is_instance_valid(_active_lang_modal):
		_active_lang_modal.queue_free()
		_active_lang_modal = null

	var modal_root := Control.new()
	modal_root.name = "LanguageSelectionModal"
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_active_lang_modal = modal_root
	add_child(modal_root)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.03, 0.06, 0.65)
	modal_root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 400)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.07, 0.14, 0.97)
	panel_style.border_color = Color(0.0, 0.85, 0.95, 0.9)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	panel_style.shadow_size = 24
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	panel_style.content_margin_top = 28
	panel_style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var logo_rect := TextureRect.new()
	logo_rect.texture = preload("res://Sprites/header.png")
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.custom_minimum_size = Vector2(340, 75)
	logo_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(logo_rect)

	var title := Label.new()
	title.text = "🌐 DİL SEÇİMİ / LANGUAGE SELECTION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1.0))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Lütfen oyunu oynamak istediğiniz dili seçin\nPlease select your preferred language"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.85))
	subtitle.add_theme_font_size_override("font_size", 14)
	vbox.add_child(subtitle)

	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.18, 0.55, 0.78, 0.5)
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 20)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var tr_btn := _create_lang_button("🇹🇷 Türkçe", "tr")
	btn_hbox.add_child(tr_btn)

	var en_btn := _create_lang_button("🇬🇧 English", "en")
	btn_hbox.add_child(en_btn)

	var note := Label.new()
	note.text = "* Bu ayarı daha sonra Ayarlar menüsünden değiştirebilirsiniz.\n* You can change this setting anytime in the Settings menu."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(0.5, 0.7, 0.85, 0.65))
	note.add_theme_font_size_override("font_size", 12)
	vbox.add_child(note)

	modal_root.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.custom_minimum_size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(modal_root, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _create_lang_button(label_text: String, lang_code: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(210, 56)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 19)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.06, 0.18, 0.3, 0.9)
	normal_style.border_color = Color(0.0, 0.85, 0.95, 0.9)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(10)
	normal_style.shadow_color = Color(0.0, 0.65, 0.85, 0.25)
	normal_style.shadow_size = 8

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.08, 0.22, 0.38, 0.95)
	hover_style.border_color = Color(0.0, 0.95, 1.0, 1.0)
	hover_style.set_border_width_all(3)
	hover_style.set_corner_radius_all(10)
	hover_style.shadow_color = Color(0.0, 0.85, 1.0, 0.4)
	hover_style.shadow_size = 12

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.02, 0.08, 0.16, 0.95)
	pressed_style.border_color = Color(0.0, 0.9, 1.0, 1.0)
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(10)

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.1, 0.95, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.95, 1.0, 1.0))

	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.mouse_entered.connect(func() -> void:
		GlobalSoundManager.play_sfx("click")
		var b_tw := create_tween()
		b_tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
	)
	btn.mouse_exited.connect(func() -> void:
		var b_tw := create_tween()
		b_tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)
	btn.pressed.connect(func() -> void:
		_on_initial_language_selected(lang_code)
	)
	return btn


func _on_initial_language_selected(lang_code: String) -> void:
	GlobalSoundManager.play_sfx("click")
	TranslationServer.set_locale(lang_code)

	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("general", "language", lang_code)
	cfg.set_value("general", "last_version", game_version)
	cfg.save(SETTINGS_FILE)

	if is_instance_valid(_active_lang_modal):
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_active_lang_modal, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(_active_lang_modal):
				_active_lang_modal.queue_free()
				_active_lang_modal = null
			_proceed_to_main_menu_after_lang()
		)
	else:
		_proceed_to_main_menu_after_lang()


func _proceed_to_main_menu_after_lang() -> void:
	if is_instance_valid($Panel):
		$Panel.visible = true
	if is_instance_valid(header_texture):
		header_texture.visible = true
	refresh_ui()
	_play_entrance_animation()


func _on_flashlight_aim_selected(_index: int) -> void:
	_save_settings()


func _on_music_changed(value: float) -> void:
	_set_bus_volume(MUSIC_BUS, value)
	_save_settings()


func _on_sfx_changed(value: float) -> void:
	_set_bus_volume(SFX_BUS, value)
	_save_settings()


func _on_joystick_slider_changed(value: float) -> void:
	if is_instance_valid(joystick_val_label):
		joystick_val_label.text = "%%%d" % [int(round(value * 100.0))]
	_save_settings()


func _on_fullscreen_toggled(on: bool) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _set_bus_volume(bus_name: String, percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if percent <= 0.0:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -60.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(percent / 100.0))


func _on_button_pressed() -> void:
	get_tree().quit(0)


func _on_button_4_pressed() -> void:
	GlobalSoundManager.play_sfx("click")
