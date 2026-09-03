extends Node

var soundtrack: Array[String] = [
	"res://Musics/m1.ogg",
	"res://Musics/m2.ogg",
	"res://Musics/m3.ogg",
	"res://Musics/m4.ogg",
	"res://Musics/m5.ogg"
]

var sfx_paths: Dictionary = {
	"pickup": "res://Sounds/kenney_rpg-audio/Audio/cloth2.ogg",
	"click": "res://Sounds/kenney_interface-sounds/Audio/click_003.ogg",
	"door": "res://Sounds/kenney_rpg-audio/Audio/doorClose_1.ogg",
	"door_open": "res://Sounds/kenney_rpg-audio/Audio/doorOpen_1.ogg",
	"door_close": "res://Sounds/kenney_rpg-audio/Audio/doorClose_1.ogg",
	"sell": "res://Sounds/kenney_rpg-audio/Audio/handleCoins2.ogg",
	"upgrade": "res://Sounds/kenney_rpg-audio/Audio/metalClick.ogg",
	"error": "res://Sounds/kenney_interface-sounds/Audio/error_004.ogg"
}

var music_player: AudioStreamPlayer
var _shuffled_playlist: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	music_player.finished.connect(_play_next_shuffled_music)
	_play_next_shuffled_music()


# SPOTIFY SHUFFLE MÜZİK ÇALMA SİSTEMİ
func _play_next_shuffled_music() -> void:
	if soundtrack.is_empty():
		return
		
	# Eğer karıştırılmış listemiz bittiyse (veya oyun yeni başladıysa)
	if _shuffled_playlist.is_empty():
		_shuffled_playlist = soundtrack.duplicate()
		_shuffled_playlist.shuffle()
		
	# Listeden sıradaki şarkı yolunu çekip alıyoruz
	var next_track_path: String = _shuffled_playlist.pop_back()
	
	var stream = load(next_track_path)
	if stream:
		music_player.stream = stream
		music_player.play()


func play_sfx(sound_name: String) -> void:
	if not sfx_paths.has(sound_name):
		push_warning("SFX bulunamadı: " + sound_name)
		return
	
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX" # SFX ses kanalından çıksın
	
	var stream = load(sfx_paths[sound_name])
	if stream:
		sfx_player.stream = stream
		add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)
