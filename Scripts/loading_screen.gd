extends Control

@export_file("*.tscn") var target_scene_path: String = "res://Scenes/main.tscn"
@export var duration: float = 2.0
@export var auto_change_scene: bool = true  # false ise sahne geçişi yapmaz, finished sinyalini yayınlar (overlay olarak kullanım)

signal finished

@onready var dots_label: Label = $Panel/HBoxContainer/DotsLabel
@onready var progress_bar: ProgressBar = $Panel/ProgressBar


func _ready() -> void:
	# Overlay modda oyun pause'a alınır (ofis zaten pause yapar, bu aradaki boşlukta oyuncu hareket etmesin)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not auto_change_scene:
		get_tree().paused = true

	# Koleksiyon .tres/ikon önbelleğini burada, görünür yükleme ekranının arkasında dolduruyoruz.
	# İlk çağrıda gerçek disk taraması yapılır; sonrasında koleksiyon defteri anında açılır.
	GlobalInventory.get_all_items()

	progress_bar.value = 0.0
	var dots := [".", "..", "..."]
	var loop := create_tween().set_loops()
	for d in dots:
		loop.tween_callback(func() -> void: dots_label.text = d)
		loop.tween_interval(0.3)
	var tween := create_tween()
	tween.tween_property(progress_bar, "value", 100.0, duration)
	tween.tween_callback(_finish)


func _finish() -> void:
	if auto_change_scene:
		get_tree().change_scene_to_file(target_scene_path)
	else:
		finished.emit()
		queue_free()
