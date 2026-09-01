extends Node

func _ready() -> void:
	var scene: PackedScene = load("res://Scenes/main.tscn")
	if scene == null:
		print("FAIL: main not loaded")
		get_tree().quit(1)
		return
	var inst: Node = scene.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var diver: Node2D = inst.get_node("Diver")
	print("DBG water_surface_y=", InfiniteMapManager.water_surface_y)
	print("DBG diver pos=", diver.global_position)
	print("DBG diver above surface by=", InfiniteMapManager.water_surface_y - diver.global_position.y)
	get_tree().quit(0)
